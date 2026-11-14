function [T, TH] = hold_test()
%HOLD_TEST  Hold test for the three arms in the Tamil Nadu file layout (scope item 6).
%
%   [T, TH] = hold_test;   % writes ../export_r1/hold_test.csv and hold_test_thresholds.csv
%
% After charging stops at 18:00 local: sun off, no draw, real ambient, 72 h cap (run_hold_test.m), 12 start days
% round(linspace(15, 345, 12)), from each arm's own state in the full-year 2023 run (whole node temperature and enthalpy vectors).
%   hold_test.csv             per arm and start day: top temperature at the start, hours above 45 C (tau_hold_h, censored at 72 h),
%                             and top temperature / melt fraction / recoverable energy at 24, 36 and 48 h
%   hold_test_thresholds.csv  per arm, start day and threshold (30, 40, 45, 50 C): hours above it and whether it was still above at 72 h
% Arm names as in run_c_scenarios.m. Measured values only, not the literature figures (12 h, 24-36 h, 24-48 h; Chen 2025 is 31.7 h
% above 30 C on 30 L/day, a different criterion). The same numbers, averaged, are in results_campaign/campaign_results.csv.
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = fullfile(here, '..', 'export_r1');
tw = load_twin_params(outDir, 2023);
W = tw.wx.signals.values(:, 1:4);
P = tw.P;  Pp = make_plain_tank(P);
arms = {'arm1_plain_B0', Pp, 1; 'arm2_pcm_B0', P, 1; 'arm3_pcm_DQN', P, 0};
thr = [30 40 45 50];  H = 72;
rows17 = find(W(:, 4) == 17);
startDays = round(linspace(15, 345, 12));
rows = {};  hrows = {};
for a = 1:3
    L = simulate_hours(tw, W, arms{a, 2}, arms{a, 3}, 0, []);
    for d = startDays
        t = rows17(d);
        R = run_hold_test(arms{a, 2}, W, L.Tn(t, :)', L.hn(t, :)', t + 1, H, thr);
        rows(end+1, :) = {arms{a, 1}, d, R.Ttop(1), R.tau(3), R.censored(3), R.Ttop(25), R.fmelt(25), R.E_rec_kWh(25), ...
            R.Ttop(37), R.fmelt(37), R.E_rec_kWh(37), R.Ttop(49), R.fmelt(49), R.E_rec_kWh(49)}; %#ok<AGROW>
        for j = 1:numel(thr)
            hrows(end+1, :) = {arms{a, 1}, d, thr(j), R.tau(j), R.censored(j)}; %#ok<AGROW>
        end
    end
end
T = cell2table(rows, 'VariableNames', {'arm', 'start_day', 'T_top_start_C', 'tau_hold_h', 'censored', 'T24_C', 'f24', 'Erec24_kWh', ...
    'T36_C', 'f36', 'Erec36_kWh', 'T48_C', 'f48', 'Erec48_kWh'});
TH = cell2table(hrows, 'VariableNames', {'arm', 'start_day', 'threshold_C', 'tau_hold_h', 'censored'});
writetable(T, fullfile(outDir, 'hold_test.csv'));
writetable(TH, fullfile(outDir, 'hold_test_thresholds.csv'));
fprintf('Hold time above each threshold, mean of %d starts (* = at least one run still above at the %d h cap):\n', numel(startDays), H);
for a = 1:3
    fprintf('  %-14s', arms{a, 1});
    for j = 1:numel(thr)
        s = strcmp(TH.arm, arms{a, 1}) & TH.threshold_C == thr(j);
        fprintf('  %2d C: %5.1f%s', thr(j), mean(TH.tau_hold_h(s)), repmat('*', 1, any(TH.censored(s))));
    end
    fprintf('\n');
end
end
