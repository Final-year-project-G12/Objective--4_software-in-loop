function [T, h, y, x] = pcm_plant_hour(I_t, T_amb, draw_kg, action, T, h, P)
%PCM_PLANT_HOUR  One hour of the Rajasthan PCM solar water heater (frozen O2 physics).
%
% Line-for-line port of Objective 2's stratified-tank kernel
%   src/simulation/tank_model_multinode.py::_kernel   (one hour, n_hours = 1)
% called the way Objective 3 calls it (o3/environment/o2_adapter.py::OneHourKernel.hour).
% Nothing is re-derived: 10 water nodes (node 1 = bottom, node 10 = top), implicit
% upwind advection + axial conduction, stratified collector return, pairwise mixing
% of inversions, per-node enthalpy-method PCM, the guard-band shield at every
% sub-step, and the same melt-band / stiffness sub-stepping.
%
% This is NOT the Tamil Nadu plant: Tamil Nadu's twin is a single water node.
%
% Inputs
%   I_t      GHI on the collector [W/m2]
%   T_amb    ambient temperature  [C]
%   draw_kg  hot-water draw this hour [kg]
%   action   0 = CHARGE, 1 = IDLE, 2 = BYPASS (command after the interlock)
%   T, h     [10x1] node water temperature [C] and PCM+wall enthalpy [J/kg]
%            at the start of the hour (h is 0 in nodes without capsules)
%   P        parameter vector built by load_twin_params.m (layout documented there)
%
% Outputs
%   T, h     node state at the end of the hour
%   y        [18x1] hourly outputs:
%             1 T_top   2 T_bottom  3 T_mean  4 T_pcm (mass mean)  5 f_melt (mass mean)
%             6 E_stored_kWh (above mains)    7 E_rec45_kWh (above 45 C)
%             8 E_del_Wh (delivered up to 45 C)  9 E_unmet_Wh  10 Q_coll_Wh  11 draw_kg
%            12 n_shield_water  13 n_shield_pcm  14 n_viol (sub-steps over a hard limit)
%            15 a_exec  16 T_top_max  17 T_pcm_max  18 shield_seconds (water + PCM)
%   x        [4x1] OPTIONAL extra accounting added for the Objective 4 improvement plan
%            (does not change y or the physics; Simulink/codegen callers may ignore it):
%             1 Q_load_Wh  heat carried out by the draw (relative to the mains temperature)
%             2 Q_loss_Wh  heat lost to ambient through the tank wall
%             3 E_del50_Wh delivered heat counted up to 50 C   4 E_unmet50_Wh unmet vs 50 C
%            Closure: Q_coll_Wh - Q_load_Wh - Q_loss_Wh = change of stored energy (check_energy_balance.m)
%#codegen

N = 10;
T = T(:); h = h(:);

% ---- unpack parameters (order fixed by load_twin_params.m) -------------
cp = P(1);  rho_w = P(2);  mains = P(3);  target = P(4);
mdot_c = P(5);  dt = P(6);  kcond = P(7);  A_cross = P(8);
Ts = P(9);  Tl = P(10);  L = P(11);  cps = P(12);  cpl = P(13);  x = P(14);
k_pcm = P(15);  enh = P(16);  kw = P(17);  pr = P(18);  mu = P(19);
wall_t = P(20);  wall_k = P(21);  d = P(22);  area_cap = P(23);  m_cap = P(24);
margin = P(25);  stiff_sf = P(26);  n_band = round(P(27));  max_sub = round(P(28));
shield = P(29) > 0.5;  byp_w = P(30);  byp_p = P(31);  max_w = P(32);  max_p = P(33);
c_cond = P(35);
A_coll = P(36);  fr_ta = P(37);  fr_ul = P(38);  I_cut = P(39);
m_w = P(51:60);  n_caps = P(61:70);  loss_ua = P(71:80);
m_w = m_w(:);  n_caps = n_caps(:);  loss_ua = loss_ua(:);

CHARGE = 0;  BYPASS = 2;

% ---- collector for this hour (OneHourKernel.hour) ----------------------
% "circulate = false" zeroes the collector arrays, exactly what GHI = 0 does.
if action == CHARGE && I_t > I_cut
    a_c = A_coll * (fr_ta * I_t + fr_ul * T_amb);
    b_c = A_coll * fr_ul;
    circ_allowed = true;
else
    a_c = 0;  b_c = 0;  circ_allowed = false;
end

% ---- kernel set-up ------------------------------------------------------
n_caps_tot = 0;
for i = 1:N, n_caps_tot = n_caps_tot + n_caps(i); end
has_pcm = n_caps_tot > 0;
m_pcm_node = n_caps * m_cap;
m_pcm_tot = n_caps_tot * m_cap;
cp_min_eff = min(cps, cpl) + x;

Tp = zeros(N, 1);  f = zeros(N, 1);
for i = 1:N
    if n_caps(i) > 0
        [Tp(i), f(i)] = pcm_T_f_of_h(h(i), Ts, Tl, L, cps, cpl, x);
    else
        h(i) = 0;
        Tp(i) = T(i);
    end
end

% "hour" length: 3600 s unless P(44) > 0 (spare slot, 0 in every exported twin). Only the tank-level
% benchmark (benchmark_amanowicz.m) sets it, to step a 2-hour cool-down in 300 s pieces.
H_s = 3600;
if P(44) > 0, H_s = P(44); end
nsteps = round(H_s / dt);
mdot_d = draw_kg / H_s;                  % constant draw rate over the hour
step_draw = draw_kg / nsteps;

hq_c = 0;  hq_un = 0;  h_draw = 0;  h_edel = 0;
hq_load = 0;  hq_loss = 0;  h_edel50 = 0;  hq_un50 = 0;
t_top_max = -1e9;  t_p_max = -1e9;
n_sw = 0;  n_sp = 0;  n_viol = 0;  shield_s = 0;

for st = 1:nsteps
    in_band = false;
    if has_pcm
        for i = 1:N
            if n_caps(i) > 0 && (Ts - margin <= Tp(i)) && (Tp(i) <= Tl + margin)
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
        % safety shield -- water side, on the TOP node (guard band below 75 C)
        if shield && T(N) >= byp_w
            circ = false;
            n_sw = n_sw + 1;
            shield_s = shield_s + dts;
        end
        % stratified collector return: highest node not hotter than the loop outlet
        k_ret = 1;
        if circ
            t_out = T(1) + max(a_c - b_c * T(1), 0) / (mdot_c * cp);
            for j = N:-1:1
                if T(j) <= t_out
                    k_ret = j;
                    break;
                end
            end
        end
        % per-node through-flow -> velocity -> UA ; PCM-side shield
        UA = zeros(N, 1);
        pcm_shield_now = false;
        if has_pcm
            for i = 1:N
                if n_caps(i) > 0
                    if circ, thr = mdot_d + mdot_c; else, thr = mdot_d; end
                    v = thr / (rho_w * A_cross);
                    ua = ua_node(n_caps(i), d, area_cap, v, f(i), rho_w, kw, pr, mu, ...
                                 wall_t, wall_k, k_pcm, enh, c_cond);
                    if shield && Tp(i) >= byp_p && T(i) > Tp(i)
                        ua = 0;
                        n_sp = n_sp + 1;
                        pcm_shield_now = true;
                    end
                    UA(i) = ua;
                end
            end
        end
        if pcm_shield_now, shield_s = shield_s + dts; end

        Tn = solve_step(T, Tp, UA, m_w, loss_ua, T_amb, N, cp, mains, mdot_d, mdot_c, circ, ...
                        k_ret, a_c, b_c, kcond, dts);
        if circ && (a_c - b_c * Tn(1)) < 0          % differential controller: no useful gain
            circ = false;
            Tn = solve_step(T, Tp, UA, m_w, loss_ua, T_amb, N, cp, mains, mdot_d, mdot_c, false, ...
                            1, a_c, b_c, kcond, dts);
        end
        if circ, q_coll = max(a_c - b_c * Tn(1), 0); else, q_coll = 0; end
        t_top = Tn(N);
        if mdot_d > 0
            q_un = mdot_d * cp * max(target - t_top, 0);
        else
            q_un = 0;
        end

        if has_pcm
            for i = 1:N
                if n_caps(i) > 0
                    q = UA(i) * (Tn(i) - Tp(i));
                    hn = h(i) + q * dts / m_pcm_node(i);
                    [tpn, fn] = pcm_T_f_of_h(hn, Ts, Tl, L, cps, cpl, x);
                    if tpn < -50 || tpn > 500
                        tpn = min(max(tpn, -50), 500);
                        hn = pcm_h_of_T(tpn, Ts, Tl, L, cps, cpl, x);
                    end
                    h(i) = hn;  Tp(i) = tpn;  f(i) = fn;
                end
            end
        end
        % extra accounting (uses the same Tn the implicit step solved for)
        q_loss_now = 0;
        for i = 1:N
            q_loss_now = q_loss_now + loss_ua(i) * (Tn(i) - T_amb);
        end
        hq_loss = hq_loss + q_loss_now * dts;
        hq_load = hq_load + mdot_d * cp * (t_top - mains) * dts;
        if mdot_d > 0
            hq_un50 = hq_un50 + mdot_d * cp * max(50 - t_top, 0) * dts;
        end
        Tn = mix_inversions(Tn, m_w, N);
        for i = 1:N
            T(i) = Tn(i);
            if n_caps(i) <= 0, Tp(i) = T(i); end
        end

        % accounting
        hq_c = hq_c + q_coll * dts;
        hq_un = hq_un + q_un * dts;
        dm = step_draw / n_sub;
        if dm > 0
            h_draw = h_draw + dm;
            h_edel = h_edel + dm * cp * max(min(t_top, target) - mains, 0);
            h_edel50 = h_edel50 + dm * cp * max(min(t_top, 50) - mains, 0);
        end
        t_top_max = max(t_top_max, t_top);
        bad = false;
        for i = 1:N
            if T(i) > max_w, bad = true; end
            if n_caps(i) > 0
                t_p_max = max(t_p_max, Tp(i));
                if Tp(i) > max_p, bad = true; end
            end
        end
        if bad, n_viol = n_viol + 1; end
    end
end

% ---- end of hour ---------------------------------------------------------
s = pcm_derive_state(T, h, P);
if ~has_pcm, t_p_max = s(3); end

% what the plant actually did (pcm_env.py: shield fired on the water side and nothing was collected)
a_exec = action;
if action == CHARGE && n_sw > 0 && hq_c <= 0
    a_exec = BYPASS;
end

y = [s(1); s(2); s(3); s(4); s(5); s(6); s(7); ...
     h_edel / 3600; hq_un / 3600; hq_c / 3600; h_draw; ...
     n_sw; n_sp; n_viol; a_exec; t_top_max; t_p_max; shield_s];
x = [hq_load / 3600; hq_loss / 3600; h_edel50 / 3600; hq_un50 / 3600];
end

% ======================================================================
function ua = ua_node(n, d, area, v, f, rho, kw, pr, mu, wall_t, wall_k, k_pcm, enh, c_cond)
% tank_model_multinode._ua_node  (Wakao-Kaguei h_w + wall + r/(c k) PCM resistance)
%#codegen
if n <= 0
    ua = 0;
    return;
end
re = max(rho * v * d / mu, 1e-6);
nu = 2 + 1.1 * re ^ 0.6 * pr ^ (1 / 3);
hw = nu * kw / d;
if f >= 0.5, k_eff = k_pcm * enh; else, k_eff = k_pcm; end
r_in = d / 2 - wall_t;                       % PCM conduction path = inner radius
a_in = 4 * pi * r_in * r_in;
r_tot = 1 / (hw * area) + wall_t / (wall_k * area) + r_in / (c_cond * k_eff * a_in);
ua = n / r_tot;
end

function Tn = solve_step(T, Tp, UA, m_w, loss_ua, tamb, N, cp, mains, mdot_d, mdot_c, circ, k_ret, a, b, kcond, dts)
% tank_model_multinode._solve_step : one implicit step of the N water nodes.
%#codegen
A = zeros(N, N);
r = zeros(N, 1);
ext_in = zeros(N, 1);
ext_out = zeros(N, 1);
ext_in(1) = ext_in(1) + mdot_d;              % mains enter the bottom node
ext_out(N) = ext_out(N) + mdot_d;            % hot water leaves the top node
if circ
    ext_out(1) = ext_out(1) + mdot_c;        % collector loop leaves the bottom node
    ext_in(k_ret) = ext_in(k_ret) + mdot_c;  % and returns at node k_ret
end
F = zeros(N - 1, 1);                         % upward flow through each interface
net = 0;
for i = 1:N - 1
    net = net + ext_in(i) - ext_out(i);
    F(i) = net;
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
Tn = A \ r;
end

function T = mix_inversions(T, m_w, N)
% tank_model_multinode._mix_inversions : pool adjacent nodes until the profile is
% non-decreasing bottom -> top (mass-weighted, energy conserving).
%#codegen
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
    if k < nb, last = start(k + 1) - 1; else, last = N; end
    tm = en(k) / mass(k);
    for j = start(k):last
        T(j) = tm;
    end
end
end

function hh = pcm_h_of_T(T, Ts, Tl, L, cps, cpl, x)
% tank_model_multinode._h_of_T  (Tref = 0 C, capsule wall lumped in through x)
%#codegen
hs = (cps + x) * Ts;
span = L + x * (Tl - Ts);
if T < Ts
    hh = (cps + x) * T;
elseif T <= Tl
    hh = hs + span * (T - Ts) / (Tl - Ts);
else
    hh = hs + span + (cpl + x) * (T - Tl);
end
end

function [T, f] = pcm_T_f_of_h(hh, Ts, Tl, L, cps, cpl, x)
% tank_model_multinode._T_f_of_h
%#codegen
hs = (cps + x) * Ts;
span = L + x * (Tl - Ts);
hl = hs + span;
if hh < hs
    T = hh / (cps + x);  f = 0;
elseif hh <= hl
    if span > 0, f = (hh - hs) / span; else, f = 1; end
    f = min(max(f, 0), 1);
    T = Ts + f * (Tl - Ts);
else
    T = Tl + (hh - hl) / (cpl + x);  f = 1;
end
end
