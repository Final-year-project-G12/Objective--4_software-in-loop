function T = shared_format_table()
%SHARED_FORMAT_TABLE  The Rajasthan 2023 results in the shared cross-state format of docs/plan_O4.md (joint plan with the Tamil Nadu twin).
%
%   T = shared_format_table;   % writes ../results_campaign/shared_format_table_rajasthan_2023.csv
%
% One row per regime and arm (water-only B0, PCM + B0, PCM + DQN, PCM + SAC), taken from results_campaign/campaign_regimes_sac.csv
% (run_campaign({'sac'}, '_sac')). Columns follow the joint plan's metric list: delivered energy at 45 and 50 C (year and the 18:00-09:00 window),
% unmet energy, guard-band (shield) hours, hours over a hard limit, melt cycles per year, pump hours, kWh per kg PCM and per m2 of collector,
% hold time at 30 / 40 / 45 / 50 C (mean of 12 evenings, 72 h cap, number of runs still above at the cap).
% Measurement point: the TOP layer of the 10-layer tank (the delivery node); the single-node Tamil Nadu twin reads its one water node.
% Forecast: perfect 3-hour irradiance look-ahead (the Tamil Nadu SAC was trained with a smart-persistence forecast: not directly comparable on
% forecast quality; forecast_optimism_2023.csv scores these controllers with the smart forecast). Replay year 2023, an Objective 3 validation year
% that was also used to select the controllers: a fidelity check, not an unbiased out-of-sample figure.
here = fileparts(mfilename('fullpath'));
R = fullfile(here, '..', 'results_campaign');
A = readtable(fullfile(R, 'campaign_regimes_sac.csv'));
T = table();
T.state = repmat({'rajasthan'}, height(A), 1);
T.regime = A.regime;
T.arm = A.arm;
T.controller = A.controller;
T.pcm = A.pcm;
T.tank_L = repmat(50, height(A), 1);
T.collector_m2 = repmat(1.5, height(A), 1);
T.pcm_mass_kg = A.pcm_mass_kg;
T.delivered_45C_kWh = A.E_del45_kWh;       T.delivered_50C_kWh = A.E_del50_kWh;
T.window_45C_kWh = A.E_del45_win_kWh;      T.window_50C_kWh = A.E_del50_win_kWh;
T.unmet_45C_kWh = A.E_unmet45_kWh;
T.guard_band_hours = A.guard_band_h;
T.hours_over_hard_limit = A.hours_over_hard_limit;
T.melt_cycles_per_year = A.melt_cycles_per_year;
T.pump_on_hours = A.pump_on_hours;
T.kWh_per_kg_pcm = A.E_del45_per_kgPCM_kWh;
T.kWh_per_m2_collector = A.E_del45_per_m2_kWh;
for th = [30 40 45 50]
    T.(sprintf('hold_%dC_mean_h', th)) = A.(sprintf('tau_hold_%dC_mean_h', th));
    T.(sprintf('hold_%dC_censored_of_12', th)) = A.(sprintf('tau_hold_%dC_censored_n', th));
end
T.measurement_point = repmat({'top layer of 10 (delivery node)'}, height(A), 1);
T.forecast = repmat({'perfect 3 h look-ahead'}, height(A), 1);
T.replay_year = repmat(2023, height(A), 1);
writetable(T, fullfile(R, 'shared_format_table_rajasthan_2023.csv'));
disp(T(:, {'regime', 'arm', 'delivered_45C_kWh', 'window_45C_kWh', 'guard_band_hours', 'kWh_per_kg_pcm', 'kWh_per_m2_collector', 'hold_45C_mean_h'}));
end
