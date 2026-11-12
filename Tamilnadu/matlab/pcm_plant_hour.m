function [T_w, T_pcm, h_pcm, f_melt, E_del_Wh, E_unmet_Wh, n_sw, n_sp, n_viol, a_exec] = ...
    pcm_plant_hour(I_t, T_amb, draw_kg, action, T_w, T_pcm, h_pcm, f_melt, P)
%PCM_PLANT_HOUR  One hour of the PCM solar water heater (frozen O2 physics).
%
% Line-for-line port of o3/environment/pcm_env.py::_run_one_hour, which is
% itself the inner loop of Objective 2's tank_model.run_year. Nothing here
% is re-derived: same implicit water node, same lagged enthalpy-method PCM
% node, same Hottel-Whillier collector, same guard-band shield at every
% sub-step, same stiffness-based sub-stepping.
%
% Inputs
%   I_t      GHI on the collector [W/m2]
%   T_amb    ambient temperature  [C]
%   draw_kg  hot-water draw this hour [kg]
%   action   0 = CHARGE, 1 = IDLE, 2 = BYPASS (the policy's request)
%   T_w, T_pcm, h_pcm, f_melt   state at the start of the hour
%   P        parameter vector built by load_twin_params.m (see twin_param_layout)
%
% Outputs: state at the end of the hour, energies, shield / violation counts
% and the action actually executed after the shield.
%#codegen

% ---- unpack parameters (order fixed by load_twin_params.m) -------------
m_w      = P(1);  cp_w   = P(2);  rho_w  = P(3);  k_w    = P(4);  pr_w   = P(5);
U_tank   = P(6);  A_tank = P(7);  T_mains= P(8);  T_del  = P(9);
A_coll   = P(10); fr_ta  = P(11); fr_ul  = P(12); I_cut  = P(13);
m_pcm    = P(14); Tm     = P(15); half_w = P(16); L      = P(17);
cp_s     = P(18); cp_l   = P(19); k_pcm  = P(20); wall_cp= P(21); enh = P(22);
n_cap    = P(23); D_cap  = P(24); A_cap  = P(25); t_wall = P(26); k_wall = P(27);
v_sup    = P(28);
max_wC   = P(29); max_pC = P(30); shield_on = P(31) > 0.5;
byp_wC   = P(32); byp_pC = P(33);
dt_total = P(34); n_sub_band = P(35); band_margin = P(36);
stiff    = P(37); max_sub = P(38);

Ts = Tm - half_w;  Tl = Tm + half_w;
CHARGE = 0; BYPASS = 2;

n_substeps_per_hr = round(3600 / dt_total);
draw_per_substep  = draw_kg / n_substeps_per_hr;

policy_circulate = (action == CHARGE);

E_del_Wh = 0; E_unmet_Wh = 0;
n_sw = 0; n_sp = 0; n_viol = 0;
a_exec = action;

cp_min = min(cp_s, cp_l) + wall_cp;

for outer = 1:n_substeps_per_hr
    in_band = (Ts - band_margin <= T_pcm) && (T_pcm <= Tl + band_margin);
    if in_band, n_sub = n_sub_band; else, n_sub = 1; end

    ua_probe = ua_eff_total(n_cap, D_cap, A_cap, v_sup, f_melt, ...
                            rho_w, k_w, pr_w, t_wall, k_wall, k_pcm, enh);
    if ua_probe > 0
        tau = m_pcm * cp_min / ua_probe;
        n_sub_stiff = max(1, ceil(dt_total / (stiff * tau)));
        n_sub = min(max(n_sub, n_sub_stiff), max_sub);
    end

    dt_sub = dt_total / n_sub;
    draw_this_sub = draw_per_substep;

    for inner = 1:n_sub
        draw = draw_this_sub / n_sub;          % (as in the Python source)
        if dt_sub > 0, m_draw_rate = draw / dt_sub; else, m_draw_rate = 0; end

        % collector, linearised: Q_u = a - b*T_w_new
        if I_t <= I_cut
            a_coll = 0; b_coll = 0; circulating = false;
        else
            a_coll = A_coll * (fr_ta * I_t + fr_ul * T_amb);
            b_coll = A_coll * fr_ul;
            circulating = true;
        end

        % policy decision (shield may still override below)
        if ~policy_circulate
            circulating = false;
            if action == BYPASS, a_exec = BYPASS; end
        end

        % safety shield -- water side (guard band below the 75 C hard limit)
        if shield_on && T_w >= byp_wC
            circulating = false;
            n_sw = n_sw + 1;
            a_exec = BYPASS;
        end

        % safety shield -- PCM charge side
        ua_eff = ua_eff_total(n_cap, D_cap, A_cap, v_sup, f_melt, ...
                              rho_w, k_w, pr_w, t_wall, k_wall, k_pcm, enh);
        if shield_on && T_pcm >= byp_pC && T_w > T_pcm
            ua_eff = 0;
            n_sp = n_sp + 1;
        end

        base_coeff = (m_w * cp_w / dt_sub) + m_draw_rate * cp_w + ua_eff + U_tank * A_tank;
        base_rhs   = (m_w * cp_w * T_w / dt_sub) + m_draw_rate * cp_w * T_mains ...
                     + ua_eff * T_pcm + U_tank * A_tank * T_amb;

        T_w_new = T_w;
        if circulating
            coeff = base_coeff + b_coll;
            rhs   = base_rhs + a_coll;
            if coeff > 0, T_w_trial = rhs / coeff; else, T_w_trial = T_w; end
            if a_coll - b_coll * T_w_trial < 0
                circulating = false;
            else
                T_w_new = T_w_trial;
            end
        end
        if ~circulating
            if base_coeff > 0, T_w_new = base_rhs / base_coeff; else, T_w_new = T_w; end
        end

        if m_draw_rate > 0
            q_unmet = m_draw_rate * cp_w * max(T_del - T_w_new, 0);
        else
            q_unmet = 0;
        end
        q_load = max(m_draw_rate * cp_w * (T_w_new - T_mains), 0);
        q_pcm  = ua_eff * (T_w_new - T_pcm);

        if m_pcm > 0, dh = q_pcm * dt_sub / m_pcm; else, dh = 0; end
        h_n = h_pcm + dh;
        [T_pcm_n, f_n] = pcm_T_of_h(h_n, Ts, Tl, L, cp_s, cp_l, wall_cp);
        if ~(T_pcm_n >= -50 && T_pcm_n <= 500)
            T_pcm_n = min(max(T_pcm_n, -50), 500);
            h_n = pcm_h_of_T(T_pcm_n, Ts, Tl, L, cp_s, cp_l, wall_cp);
        end

        if T_w_new > max_wC || T_pcm_n > max_pC
            n_viol = n_viol + 1;
        end

        E_del_Wh   = E_del_Wh   + q_load  * dt_sub / 3600;
        E_unmet_Wh = E_unmet_Wh + q_unmet * dt_sub / 3600;

        T_w = T_w_new; T_pcm = T_pcm_n; h_pcm = h_n; f_melt = f_n;
    end
end
end

% ======================================================================
function ua = ua_eff_total(n_cap, D, A_cap, v_sup, f_melt, rho_w, k_w, pr, t_wall, k_wall, k_pcm, enh)
% src/simulation/heat_transfer.py::ua_eff_total_w_k  (Wakao-Kaguei + wall + lumped sphere)
%#codegen
if n_cap <= 0, ua = 0; return; end
t_k = 40 + 273.15;                                  % viscosity evaluated at 40 C, as in O2
mu  = 2.414e-5 * 10 ^ (247.8 / (t_k - 140));
if mu > 0, re = rho_w * v_sup * D / mu; else, re = 0; end
re  = max(re, 1e-6);
nu  = 2 + 1.1 * re ^ 0.6 * pr ^ (1/3);
h_w = nu * k_w / D;
if h_w > 0, r_conv = 1 / (h_w * A_cap); else, r_conv = 1e300; end
r_wall = t_wall / (k_wall * A_cap);
if f_melt >= 0.5, k_eff = k_pcm * enh; else, k_eff = k_pcm; end
r_in = D / 2 - t_wall;
a_in = 4 * pi * r_in ^ 2;
if k_eff > 0, r_pcm = r_in / (5 * k_eff * a_in); else, r_pcm = 1e300; end
r_tot = r_conv + r_wall + r_pcm;
if r_tot > 0, ua = n_cap / r_tot; else, ua = 0; end
end

function h = pcm_h_of_T(T, Ts, Tl, L, cp_s, cp_l, wall_cp)
% capsule_enthalpy.enthalpy_of_temperature (Tref = 0 C, wall lumped in)
%#codegen
h_s  = (cp_s + wall_cp) * Ts;
span = L + wall_cp * (Tl - Ts);
if T < Ts
    h = (cp_s + wall_cp) * T;
elseif T <= Tl
    f = (T - Ts) / (Tl - Ts);
    h = h_s + f * span;
else
    h = h_s + span + (cp_l + wall_cp) * (T - Tl);
end
end

function [T, f] = pcm_T_of_h(h, Ts, Tl, L, cp_s, cp_l, wall_cp)
% capsule_enthalpy.temperature_and_liquid_fraction_of_enthalpy
%#codegen
h_s  = (cp_s + wall_cp) * Ts;
span = L + wall_cp * (Tl - Ts);
h_l  = h_s + span;
if h < h_s
    T = h / (cp_s + wall_cp);  f = 0;
elseif h <= h_l
    if span > 0, f_raw = (h - h_s) / span; else, f_raw = 1; end
    f = min(max(f_raw, 0), 1);
    T = Ts + f * (Tl - Ts);
else
    T = Tl + (h - h_l) / (cp_l + wall_cp);  f = 1;
end
end
