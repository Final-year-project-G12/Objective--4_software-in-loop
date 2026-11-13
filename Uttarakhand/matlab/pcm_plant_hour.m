function [T, h, rec, sc] = pcm_plant_hour(GHI, T_amb, hod, action, T, h, K)
%PCM_PLANT_HOUR  One hour of the Uttarakhand PCM solar water heater (frozen O2 physics).
%
% Line-for-line port of O2's compiled multinode kernel
% (o2_frozen/src/simulation/tank_model_multinode.py::_kernel) called on a
% ONE-hour slice, exactly as Objective 3's o3/stepper.py::HourlyStepper.step
% does. The kernel's only state between hours is the node water temperature
% vector T and the node PCM enthalpy vector h, so stepping this function 8760
% times is the same as one O2 full-year run.
%
% Physics (node 1 = bottom, node N = top): 1-D stratified tank, implicit
% upwind advection of the draw (mains in at the bottom, hot water out at the
% top) and of the collector loop (out of the bottom node, back in at the
% neutral-buoyancy node), axial conduction, per-node ambient loss, PCM
% capsules per node (enthalpy method, Wakao-Kaguei + wall + r/(c k) UA),
% buoyancy mixing, guard-band shield at 72 C top node / 62 C PCM evaluated at
% every sub-step, melt-band and stiffness sub-stepping.
%
% Inputs
%   GHI, T_amb   hour-mean irradiance [W/m2] and ambient temperature [C]
%   hod          local clock hour 0..23 (indexes the demand curve)
%   action       0 = BYPASS (collector loop off for the hour), 1 = ENABLE
%                (the kernel's cut-off, re-solve and shield still decide
%                whether the loop actually runs; the policy cannot override
%                the shield)
%   T, h         [N x 1] node water temperature [C] / PCM enthalpy [J/kg]
%   K            plant struct from load_twin_params (P, m_w, n_caps, loss_ua,
%                demand24, coll, N)
%
% Outputs
%   T, h   state at the end of the hour
%   rec    [21 x 1] the kernel's hourly record, same order as o3/stepper.py HR:
%          1 T_top 2 T_mean 3 T_pcm 4 f_melt 5 Q_coll_Wh 6 Q_load_Wh 7 Q_pcm_Wh
%          8 Q_loss_Wh 9 Q_unmet_Wh 10 draw_kg 11 vol_ge_target_kg 12 Edel_Wh
%          13 T_top_min 14 T_top_max 15 T_pcm_max 16 f_min 17 f_max
%          18 E_stored_kWh 19 E_rec_kWh 20 T_bottom 21 Q_load_net_Wh
%   sc     [8 x 1] 1 shield-water s, 2 shield-PCM s, 3 s over a hard limit,
%          4 water-shield sub-step count, 5 PCM-shield count, 6 over-limit
%          sub-step count, 7 s the collector loop actually ran (twin extra,
%          not a kernel output), 8 collector heat [J]
%#codegen

P = K.P; m_w = K.m_w(:); n_caps = K.n_caps(:); loss_ua = K.loss_ua(:);
N = numel(m_w);

% ---- unpack P (kernel order, 0-based index in Python = MATLAB index - 1) ----
cp = P(1); rho_w = P(2); mains = P(3); target = P(4);
mdot_c = P(5); dt = P(6); kcond = P(7); A_cross = P(8);
Ts = P(9); Tl = P(10); L = P(11); cps = P(12); cpl = P(13); x = P(14);
k_pcm = P(15); enh = P(16); kw = P(17); pr = P(18); mu = P(19);
wall_t = P(20); wall_k = P(21); d = P(22); area_cap = P(23); m_cap = P(24);
margin = P(25); stiff_sf = P(26); n_band = fix(P(27)); max_sub = fix(P(28));
shield = P(29); byp_w = P(30); byp_p = P(31); max_w = P(32); max_p = P(33);
c_cond = P(35);

% ---- collector coefficients for this hour (_collector_arrays, then x action) ----
area = K.coll(1); fr_ta = K.coll(2); fr_ul = K.coll(3); I_cut = K.coll(4);
circ0 = double(GHI > I_cut);
on = double(action == 1);
a_c  = circ0 * area * (fr_ta * GHI + fr_ul * T_amb) * on;
b_c  = circ0 * area * fr_ul * on;
circ_in = circ0 * on;

% ---- kernel set-up ----
n_caps_tot = 0;
for i = 1:N, n_caps_tot = n_caps_tot + n_caps(i); end
has_pcm = n_caps_tot > 0;
m_pcm_node = n_caps * m_cap;
m_pcm_tot = n_caps_tot * m_cap;
cp_min_eff = min(cps, cpl) + x;

T = T(:);
hin = h(:);
h = zeros(N, 1); Tp = zeros(N, 1); f = zeros(N, 1);
for i = 1:N
    if n_caps(i) > 0
        h(i) = hin(i);
        [Tp(i), f(i)] = T_f_of_h(h(i), Ts, Tl, L, cps, cpl, x);
    else
        Tp(i) = T(i);
    end
end
h_mains = h_of_T(mains, Ts, Tl, L, cps, cpl, x);
h_target = h_of_T(target, Ts, Tl, L, cps, cpl, x);
m_w_tot = 0;
for i = 1:N, m_w_tot = m_w_tot + m_w(i); end

sc = zeros(8, 1);
nsteps = round(3600 / dt);

% ---- the hour ----
tam = T_amb;
circ_allowed = circ_in > 0.5;
hour_mass = K.demand24(hod + 1);
mdot_d = hour_mass / 3600.0;
step_draw = hour_mass / nsteps;
hq_c = 0; hq_l = 0; hq_p = 0; hq_loss = 0; hq_un = 0; hq_ln = 0;
h_draw = 0; h_vol = 0; h_edel = 0;
t_top_min = 1e9; t_top_max = -1e9; t_p_max = -1e9;
f_min = 1e9; f_max = -1e9;

for st = 1:nsteps
    in_band = false;
    if has_pcm
        for i = 1:N
            if n_caps(i) > 0 && Ts - margin <= Tp(i) && Tp(i) <= Tl + margin
                in_band = true;
            end
        end
    end
    if in_band, n_sub = n_band; else, n_sub = 1; end
    if has_pcm
        v_max = (mdot_c + mdot_d) / (rho_w * A_cross);
        for i = 1:N
            if n_caps(i) > 0
                ua_p = ua_node(n_caps(i), d, area_cap, v_max, f(i), rho_w, kw, pr, mu, ...
                               wall_t, wall_k, k_pcm, enh, c_cond);
                if ua_p > 0
                    tau = m_pcm_node(i) * cp_min_eff / ua_p;
                    ns = ceil(dt / (stiff_sf * tau));
                    if ns > n_sub, n_sub = ns; end
                end
            end
        end
        if n_sub > max_sub, n_sub = max_sub; end
    end
    dts = dt / n_sub;

    for sb = 1:n_sub
        circ = circ_allowed;
        if shield > 0.5 && T(N) >= byp_w
            circ = false;
            sc(4) = sc(4) + 1;
            sc(1) = sc(1) + dts;
        end
        k_ret = 1;
        if circ
            t_out = T(1) + max(a_c - b_c * T(1), 0.0) / (mdot_c * cp);
            k_ret = 1;
            for j = N:-1:1
                if T(j) <= t_out
                    k_ret = j;
                    break;
                end
            end
        end
        UA = zeros(N, 1);
        pcm_shield_now = false;
        if has_pcm
            for i = 1:N
                if n_caps(i) > 0
                    if circ, thr = mdot_d + mdot_c; else, thr = mdot_d + 0.0; end
                    v = thr / (rho_w * A_cross);
                    ua = ua_node(n_caps(i), d, area_cap, v, f(i), rho_w, kw, pr, mu, ...
                                 wall_t, wall_k, k_pcm, enh, c_cond);
                    if shield > 0.5 && Tp(i) >= byp_p && T(i) > Tp(i)
                        ua = 0.0;
                        sc(5) = sc(5) + 1;
                        pcm_shield_now = true;
                    end
                    UA(i) = ua;
                end
            end
        end
        if pcm_shield_now, sc(2) = sc(2) + dts; end
        Tn = solve_step(T, Tp, UA, m_w, loss_ua, tam, N, cp, mains, mdot_d, mdot_c, circ, ...
                        k_ret, a_c, b_c, kcond, dts);
        if circ && (a_c - b_c * Tn(1)) < 0.0
            circ = false;
            Tn = solve_step(T, Tp, UA, m_w, loss_ua, tam, N, cp, mains, mdot_d, mdot_c, false, ...
                            1, a_c, b_c, kcond, dts);
        end
        if circ, q_coll = max(a_c - b_c * Tn(1), 0.0); else, q_coll = 0.0; end
        t_top = Tn(N);
        q_load_net = mdot_d * cp * (t_top - mains);
        q_load = max(q_load_net, 0.0);
        if mdot_d > 0, q_un = mdot_d * cp * max(target - t_top, 0.0); else, q_un = 0.0; end
        q_loss = 0.0;
        for i = 1:N, q_loss = q_loss + loss_ua(i) * (Tn(i) - tam); end
        q_pcm_sum = 0.0;
        if has_pcm
            for i = 1:N
                if n_caps(i) > 0
                    q = UA(i) * (Tn(i) - Tp(i));
                    q_pcm_sum = q_pcm_sum + q;
                    hn = h(i) + q * dts / m_pcm_node(i);
                    [tpn, fn] = T_f_of_h(hn, Ts, Tl, L, cps, cpl, x);
                    if tpn < -50.0 || tpn > 500.0
                        tpn = min(max(tpn, -50.0), 500.0);
                        hn = h_of_T(tpn, Ts, Tl, L, cps, cpl, x);
                    end
                    h(i) = hn; Tp(i) = tpn; f(i) = fn;
                end
            end
        end
        Tn = mix_inversions(Tn, m_w, N);
        for i = 1:N
            T(i) = Tn(i);
            if n_caps(i) <= 0, Tp(i) = T(i); end
        end
        % accounting
        sc(8) = sc(8) + q_coll * dts;
        if circ, sc(7) = sc(7) + dts; end
        hq_c = hq_c + q_coll * dts;
        hq_l = hq_l + q_load * dts;
        hq_ln = hq_ln + q_load_net * dts;
        hq_p = hq_p + q_pcm_sum * dts;
        hq_loss = hq_loss + q_loss * dts;
        hq_un = hq_un + q_un * dts;
        dm = step_draw / n_sub;
        if dm > 0
            h_draw = h_draw + dm;
            if t_top >= target, h_vol = h_vol + dm; end
            h_edel = h_edel + dm * cp * max(min(t_top, target) - mains, 0.0);
        end
        t_top_min = min(t_top_min, t_top);
        t_top_max = max(t_top_max, t_top);
        bad = false;
        for i = 1:N
            if T(i) > max_w, bad = true; end
            if n_caps(i) > 0
                t_p_max = max(t_p_max, Tp(i));
                if Tp(i) > max_p, bad = true; end
            end
        end
        if bad
            sc(6) = sc(6) + 1;
            sc(3) = sc(3) + dts;
        end
        if has_pcm
            fm = 0.0;
            for i = 1:N, fm = fm + f(i) * m_pcm_node(i) / m_pcm_tot; end
            f_min = min(f_min, fm);
            f_max = max(f_max, fm);
        end
    end
end

% ---- end of hour record ----
t_mean = 0.0; e_rel = 0.0; e_rec = 0.0; tp_mean = 0.0; fm = 0.0;
for i = 1:N
    t_mean = t_mean + T(i) * m_w(i) / m_w_tot;
    e_rel = e_rel + m_w(i) * cp * (T(i) - mains);
    e_rec = e_rec + m_w(i) * cp * max(T(i) - target, 0.0);
    if n_caps(i) > 0
        e_rel = e_rel + m_pcm_node(i) * (h(i) - h_mains);
        e_rec = e_rec + m_pcm_node(i) * max(h(i) - h_target, 0.0);
        tp_mean = tp_mean + Tp(i) * m_pcm_node(i) / m_pcm_tot;
        fm = fm + f(i) * m_pcm_node(i) / m_pcm_tot;
    end
end
if ~has_pcm
    tp_mean = t_mean; f_min = 0.0; f_max = 0.0;
end
if has_pcm, tpm = t_p_max; else, tpm = t_mean; end
rec = [T(N); t_mean; tp_mean; fm; hq_c / 3600.0; hq_l / 3600.0; hq_p / 3600.0; hq_loss / 3600.0; ...
       hq_un / 3600.0; h_draw; h_vol; h_edel / 3600.0; t_top_min; t_top_max; tpm; f_min; f_max; ...
       e_rel / 3.6e6; e_rec / 3.6e6; T(1); hq_ln / 3600.0];
end

% ======================================================================
function h = h_of_T(T, Ts, Tl, L, cps, cpl, x)
%#codegen
hs = (cps + x) * Ts;
span = L + x * (Tl - Ts);
if T < Ts
    h = (cps + x) * T;
elseif T <= Tl
    h = hs + span * (T - Ts) / (Tl - Ts);
else
    h = hs + span + (cpl + x) * (T - Tl);
end
end

function [T, f] = T_f_of_h(h, Ts, Tl, L, cps, cpl, x)
%#codegen
hs = (cps + x) * Ts;
span = L + x * (Tl - Ts);
hl = hs + span;
if h < hs
    T = h / (cps + x); f = 0.0;
elseif h <= hl
    if span > 0, f = (h - hs) / span; else, f = 1.0; end
    f = min(max(f, 0.0), 1.0);
    T = Ts + f * (Tl - Ts);
else
    T = Tl + (h - hl) / (cpl + x); f = 1.0;
end
end

function ua = ua_node(n, d, area, v, f, rho, kw, pr, mu, wall_t, wall_k, k_pcm, enh, c_cond)
%#codegen
if n <= 0, ua = 0.0; return; end
re = max(rho * v * d / mu, 1e-6);
nu = 2.0 + 1.1 * re ^ 0.6 * pr ^ (1.0 / 3.0);
hw = nu * kw / d;
if f >= 0.5, k_eff = k_pcm * enh; else, k_eff = k_pcm * 1.0; end
r_in = d / 2.0 - wall_t;                       % PCM conduction path = inner radius (O2 decision D3)
a_in = 4.0 * pi * r_in * r_in;
r_tot = 1.0 / (hw * area) + wall_t / (wall_k * area) + r_in / (c_cond * k_eff * a_in);
ua = n / r_tot;
end

function Tn = solve_step(T, Tp, UA, m_w, loss_ua, tamb, N, cp, mains, mdot_d, mdot_c, circ, k_ret, a, b, kcond, dts)
%#codegen
A = zeros(N, N);
r = zeros(N, 1);
ext_in = zeros(N, 1);
ext_out = zeros(N, 1);
ext_in(1) = ext_in(1) + mdot_d;
ext_out(N) = ext_out(N) + mdot_d;
if circ
    ext_out(1) = ext_out(1) + mdot_c;
    ext_in(k_ret) = ext_in(k_ret) + mdot_c;
end
F = zeros(max(N - 1, 1), 1);
runf = 0.0;
for i = 1:N - 1
    runf = runf + (ext_in(i) - ext_out(i));
    F(i) = runf;
end
for i = 1:N
    A(i, i) = A(i, i) + (m_w(i) * cp / dts + loss_ua(i) + UA(i) + ext_out(i) * cp);
    r(i) = r(i) + (m_w(i) * cp / dts * T(i) + loss_ua(i) * tamb + UA(i) * Tp(i));
    if i == 1
        r(1) = r(1) + mdot_d * cp * mains;
    end
    if i > 1
        Fb = F(i - 1);
        if Fb > 0
            A(i, i - 1) = A(i, i - 1) - Fb * cp;
        else
            A(i, i) = A(i, i) - Fb * cp;
        end
        A(i, i) = A(i, i) + kcond;
        A(i, i - 1) = A(i, i - 1) - kcond;
    end
    if i < N
        Fa = F(i);
        if Fa > 0
            A(i, i) = A(i, i) + Fa * cp;
        else
            A(i, i + 1) = A(i, i + 1) + Fa * cp;
        end
        A(i, i) = A(i, i) + kcond;
        A(i, i + 1) = A(i, i + 1) - kcond;
    end
end
if circ
    A(k_ret, 1) = A(k_ret, 1) - (mdot_c * cp - b);
    r(k_ret) = r(k_ret) + a;
end
% LU with partial pivoting (LAPACK getrf/getrs, as numpy.linalg.solve); linsolve
% skips mldivide's symmetric/Cholesky shortcut so both sides factor the same way.
Tn = linsolve(A, r);
end

function T = mix_inversions(T, m_w, N)
%#codegen
% Pool-adjacent-violators: remove every inversion (lower node hotter than the
% one above) by mass-weighted mixing; exactly energy conserving.
start = zeros(N, 1);
mass = zeros(N, 1);
en = zeros(N, 1);
nb = 0;
for j = 1:N
    nb = nb + 1;
    start(nb) = j;
    mass(nb) = m_w(j);
    en(nb) = m_w(j) * T(j);
    while nb > 1 && en(nb - 1) / mass(nb - 1) > en(nb) / mass(nb) + 1e-12
        mass(nb - 1) = mass(nb - 1) + mass(nb);
        en(nb - 1) = en(nb - 1) + en(nb);
        nb = nb - 1;
    end
end
for k = 1:nb
    if k + 1 <= nb, stop = start(k + 1) - 1; else, stop = N; end
    tm = en(k) / mass(k);
    for j = start(k):stop
        T(j) = tm;
    end
end
end
