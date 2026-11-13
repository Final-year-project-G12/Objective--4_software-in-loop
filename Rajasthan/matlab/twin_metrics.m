function m = twin_metrics(L, P, f0, hyd)
%TWIN_METRICS  One definition of every per-run metric of plan section 6.4 (M1, M2, M5, M6, M7).
%
%   m = twin_metrics(L, P, f0)
%
%   L   closed-loop log from simulate_hours.m (a year, or any window)
%   P   the parameter vector that run used (for flow, collector area, PCM mass)
%   f0  melt fraction at the start of the run (default 0)
%   hyd optional struct with .ergun_a_Pa_per_kg_s, .ergun_b_Pa_per_kg_s2, .pump_efficiency (campaign_config.json o2.hydraulics:
%       Objective 2's Ergun pressure drop across the capsule bed) -> pump electrical energy; NaN when not given
%
% Retention (M3), the gain over water-only (M4) and the ranking agreement (M8) need several runs or
% a hold test, so they are computed in run_campaign.m from run_hold_test.m / these metrics.
%
% The "window" is Objective 2's 18:00 -> 09:00 evening/night window (tes_metrics.WINDOW_HOURS).
if nargin < 3 || isempty(f0), f0 = 0; end
if nargin < 4, hyd = []; end
win = (L.hod >= 18) | (L.hod < 9);

% M1 delivered energy, at 45 C (the contract target) and at 50 C
m.E_del45_kWh = sum(L.E_del_Wh) / 1000;
m.E_del45_win_kWh = sum(L.E_del_Wh(win)) / 1000;
m.E_del50_kWh = sum(L.E_del50_Wh) / 1000;
m.E_del50_win_kWh = sum(L.E_del50_Wh(win)) / 1000;
% M2 unmet demand (energy the draw asked for above what the tank supplied at target temperature)
m.E_unmet45_kWh = sum(L.E_unmet_Wh) / 1000;
m.E_unmet50_kWh = sum(L.E_unmet50_Wh) / 1000;
% collector heat (context for M1, and used in the closure check)
m.Q_coll_kWh = sum(L.Q_coll_Wh) / 1000;
% M5 safety
m.hours_over_hard_limit = sum(L.n_viol > 0);
m.guard_band_h = sum(L.shield_s) / 3600;
m.shield_activations = sum(L.n_sw + L.n_sp);
m.T_top_max_C = max(L.Tw_max);
m.T_pcm_max_C = max(L.Tpcm_max);
% M6 PCM utilisation
if P(24) * sum(P(61:70)) > 0
    f = L.f_melt;
    m.melt_cycles_per_year = sum(abs(diff([f0; f]))) / 2 * (8760 / numel(f));
    m.hours_f_0p1_to_0p9 = sum(f > 0.1 & f < 0.9);
    m.pcm_mass_kg = P(24) * sum(P(61:70));
else
    m.melt_cycles_per_year = 0;  m.hours_f_0p1_to_0p9 = 0;  m.pcm_mass_kg = 0;
end
% M7 pump effort: hours the loop actually circulated (executed CHARGE with collector gain)
on = (L.a_exec == 0) & (L.Q_coll_Wh > 0);
m.pump_on_hours = sum(on);
m.pumped_volume_m3 = sum(on) * 3600 * P(5) / P(2);
% electrical energy = sum over pump-on hours of  dP(mdot) * mdot / rho / eta,  dP = a mdot + b mdot^2 (Ergun, capsule bed only).
% The pump is taken as running the whole hour whenever the collector adds heat (an upper bound on running time); pipe, collector
% and valve losses are not in the Objective 2 model, so this is the bed's share only, not a measured pump energy.
if ~isempty(hyd)
    mdot = P(5);
    dp = hyd.ergun_a_Pa_per_kg_s * mdot + hyd.ergun_b_Pa_per_kg_s2 * mdot^2;
    m.pump_head_Pa = dp;
    m.pump_electrical_Wh = sum(on) * dp * mdot / P(2) / hyd.pump_efficiency;      % W x 1 h
else
    m.pump_head_Pa = NaN;  m.pump_electrical_Wh = NaN;
end
% per-size normalisation (plan 6.3): kWh per kg of PCM and per m2 of collector
m.E_del45_per_m2_kWh = m.E_del45_kWh / P(36);
if m.pcm_mass_kg > 0, m.E_del45_per_kgPCM_kWh = m.E_del45_kWh / m.pcm_mass_kg; else, m.E_del45_per_kgPCM_kWh = NaN; end
m.hours = numel(L.Tw);
end
