function T = pcm_swap_study()
%PCM_SWAP_STUDY  PCM swap table in the Tamil Nadu file layout (scope item 7): O1 top-3 PCMs, geometry fixed, flow x0.7, x1.0, x1.3.
%
%   T = pcm_swap_study;   % writes ../export_r1/pcm_swap_study.csv and .json
%
% Reads results_campaign/campaign_results_flowall.csv, written by  run_campaign({'flow_all'}, '_flowall')  (all three PCMs at all three
% flows, B0 and DQN, 2023, 12 hold-test starts). Capsule count, size and wall stay at the Objective 2 values; only the material changes
% (swap_pcm.m). Columns as export/pcm_swap_study.csv of the Tamil Nadu twin:
%   policy_mode 0 = trained DQN, 1 = B0 (always-charge)      shield_events = guard-band hours here (the 10-node kernel's trip counts are
%   not comparable with the single-node twin's)             kWh_per_kg_pcm, kWh_per_m2_coll = delivered energy per kg PCM / per m2 collector
% o1_cluster1_rank is Objective 1's consensus rank in Rajasthan cluster 1. The PCM Objective 2 chose is PureTemp 60 (rank 1).
here = fileparts(mfilename('fullpath'));
R = fullfile(here, '..', 'results_campaign');
A = readtable(fullfile(R, 'campaign_results_flowall.csv'));
A = A(A.pcm_rank > 0, :);
tw = load_twin_params(fullfile(here, '..', 'export_r1'), 2023);
T = table(A.pcm, A.pcm_rank, A.flow_mult, double(strcmp(A.controller, 'B0')), A.E_del45_kWh, A.E_unmet45_kWh, A.guard_band_h, ...
    A.hours_over_hard_limit, A.pcm_mass_kg, A.E_del45_per_kgPCM_kWh, A.E_del45_per_m2_kWh, A.tau_hold_45C_mean_h, A.tau_hold_45C_censored_n, ...
    A.E_del45_win_kWh, A.tau_hold_50C_mean_h, ...
    'VariableNames', {'pcm', 'o1_cluster1_rank', 'flow_mult', 'policy_mode', 'delivered_kWh', 'unmet_kWh', 'shield_events', 'n_viol', ...
    'm_pcm_kg', 'kWh_per_kg_pcm', 'kWh_per_m2_coll', 'tau_hold45_mean_h', 'tau_hold45_n_censored', 'window_kWh', 'tau_hold50_mean_h'});
T.Properties.VariableDescriptions{'shield_events'} = 'guard-band hours (10-node kernel)';
T = sortrows(T, {'o1_cluster1_rank', 'flow_mult', 'policy_mode'});
writetable(T, fullfile(here, '..', 'export_r1', 'pcm_swap_study.csv'));
J = struct('year', 2023, 'regime', 1, 'collector_m2', tw.P(36), 'note', 'policy_mode 0 = DQN, 1 = B0; shield_events = guard-band hours', 'rows', table2struct(T));
fid = fopen(fullfile(here, '..', 'export_r1', 'pcm_swap_study.json'), 'w'); fwrite(fid, jsonencode(J, 'PrettyPrint', true)); fclose(fid);
disp(T(:, {'pcm', 'flow_mult', 'policy_mode', 'delivered_kWh', 'window_kWh', 'tau_hold45_mean_h', 'shield_events'}));
end
