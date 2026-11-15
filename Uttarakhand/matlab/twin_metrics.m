function m = twin_metrics(L, K, f0, pump_power_w)
%TWIN_METRICS  One definition of every per-run metric of the joint plan (section 2.8), same names as Rajasthan's.
%
%   m = twin_metrics(L, K, f0, pump_power_w)
%
%   L   log of simulate_hours (a year or any window)      K   plant struct that run used
%   f0  melt fraction at the start (default 0)            pump_power_w  O2's Ergun bed pump power at that flow (optional)
%
% Window = Objective 2's 18:00 -> 09:00 (tes_metrics.WINDOW_HOURS). Delivered energy is counted up to 45 C
% (Tamil Nadu / Rajasthan target) and up to 50 C (Uttarakhand target, O2's primary metric).
if nargin < 3 || isempty(f0), f0 = 0; end
if nargin < 4, pump_power_w = NaN; end
win = L.in_window > 0.5;
% M1 delivered energy
m.E_del45_kWh = sum(L.E_del45_Wh) / 1000;
m.E_del45_win_kWh = sum(L.E_del45_Wh(win)) / 1000;
m.E_del50_kWh = sum(L.E_del_Wh) / 1000;
m.E_del50_win_kWh = sum(L.E_del_Wh(win)) / 1000;
% M2 unmet
m.E_unmet45_kWh = sum(L.E_unmet45_Wh) / 1000;
m.E_unmet50_kWh = sum(L.E_unmet_Wh) / 1000;
m.Q_coll_kWh = sum(L.Q_coll_Wh) / 1000;
% M5 safety
m.hours_over_hard_limit = sum(L.over_limit_s > 0);
m.guard_band_h = sum(L.shield_w_s + L.shield_p_s) / 3600;
m.shield_activations = sum(L.n_sw + L.n_sp);
m.T_top_max_C = max(L.T_top_max);
pcm_mass = K.P(24) * sum(K.n_caps);
if pcm_mass > 0, m.T_pcm_max_C = max(L.T_pcm_max); else, m.T_pcm_max_C = NaN; end
% M6 PCM utilisation
if pcm_mass > 0
    f = L.f_melt;
    m.melt_cycles_per_year = sum(abs(diff([f0; f]))) / 2 * (8760 / numel(f));
    m.hours_f_0p1_to_0p9 = sum(f > 0.1 & f < 0.9);
else
    m.melt_cycles_per_year = 0; m.hours_f_0p1_to_0p9 = 0;
end
m.pcm_mass_kg = pcm_mass;
% M7 pump effort: hours the loop actually circulated (after cut-off, re-solve and shield) and the run time inside them
on = L.pump_frac > 0 & L.Q_coll_Wh > 0;
m.pump_on_hours = sum(on);
m.pump_run_h = sum(L.pump_frac);
m.pumped_volume_m3 = sum(L.pump_frac) * 3600 * K.P(5) / K.P(2);
m.pump_bed_electrical_Wh = pump_power_w * m.pump_run_h;   % Ergun capsule bed only (O2); pipes / collector not modelled
% per-size normalisation (plan 2.8)
A = K.coll(1);
m.E_del45_per_m2_kWh = m.E_del45_kWh / A;
m.E_del50_per_m2_kWh = m.E_del50_kWh / A;
if pcm_mass > 0
    m.E_del45_per_kgPCM_kWh = m.E_del45_kWh / pcm_mass;
    m.E_del50_per_kgPCM_kWh = m.E_del50_kWh / pcm_mass;
else
    m.E_del45_per_kgPCM_kWh = NaN; m.E_del50_per_kgPCM_kWh = NaN;
end
m.bypass_hours = sum(L.a_cmd == 0);
m.failsafe_hours = sum(L.interlock >= 2);
m.hours = numel(L.T_top);
end
