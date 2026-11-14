function export_summary_files()
%EXPORT_SUMMARY_FILES  Put existing check results into export_r1/ under the Tamil Nadu file names (no new computation).
%
%   export_summary_files;   % after check_energy_balance(1), benchmark_amanowicz, calibrate_capsule
%   writes ../export_r1/restart_check.json, energy_balance_report.json, amanowicz_benchmark.json
% These are views of results_campaign/energy_balance_report_r1.json, benchmark_amanowicz_summary.csv and capsule_calibration.json, so
% the two states can be read side by side; the originals stay where they are.
here = fileparts(mfilename('fullpath'));
R = fullfile(here, '..', 'results_campaign');  E = fullfile(here, '..', 'export_r1');
eb = jsondecode(fileread(fullfile(R, 'energy_balance_report_r1.json')));
rc = struct();
for f = {'restart_replay_max_dT_C', 'restart_replay_max_dh_Jkg', 'restart_replay_pass', 'restart_hold_max_dTtop_C', ...
         'restart_hold_max_dTnodes_C', 'restart_hold_max_dEstored_kWh', 'restart_hold_start_row', 'restart_hold_pass'}
    rc.(f{1}) = eb.(f{1});
end
rc.note = 'difference must be 0: a stored hourly state replayed with the same inputs reproduces the full-year state; run_hold_test reproduces an independent full run';
write_json(fullfile(E, 'restart_check.json'), rc);
write_json(fullfile(E, 'energy_balance_report.json'), eb);
S = readtable(fullfile(R, 'benchmark_amanowicz_summary.csv'));
ab = struct('reference', 'Amanowicz & Turski, Energies 18(2) 345 (2025); printed linear fits of the measured curves, equations 2-5', ...
    'paper_drop_water_only_K', 14, 'paper_drop_with_capsules_K', 26, 'variants', table2struct(S), ...
    'calibration', jsondecode(fileread(fullfile(R, 'capsule_calibration.json'))));
write_json(fullfile(E, 'amanowicz_benchmark.json'), ab);
fprintf('[export_summary_files] restart_check.json, energy_balance_report.json, amanowicz_benchmark.json -> %s\n', E);
end

function write_json(file, s)
fid = fopen(file, 'w'); fwrite(fid, jsonencode(s, 'PrettyPrint', true)); fclose(fid);
end
