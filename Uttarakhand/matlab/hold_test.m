function [T, TH] = hold_test(regime)
%HOLD_TEST  Hold (retention) test for the three arms (joint plan section 2.2), Rajasthan file layout.
%
%   [T, TH] = hold_test;   % regime 1; writes ../export_r1/hold_test.csv, hold_test_thresholds.csv, hold_test.png
%
% Start at the END of the 17:00 local hour (18:00 start) on days round(linspace(15, 345, 12)) of 2023, from each arm's
% own node state in its full-year run; then sun off, no draw, real ambient, 72 h cap (run_hold_test.m). Thresholds
% 30 / 40 / 45 / 50 C at the TOP layer; censored runs (still above at 72 h) are counted and enter the mean at 72 h;
% tau_hold by linear interpolation inside the hour. Read at 24 / 36 / 48 h. Measured values only.
if nargin < 1 || isempty(regime), regime = 1; end
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = twin_export_dir(regime);
tw = load_twin_params(outDir, 2023);
C = load_campaign(regime);
W = tw.wx.signals.values;
arms = {'arm1_plain_B0', C.water_only, 1; 'arm2_pcm_B0', C.base.K, 1; 'arm3_pcm_PPO', C.base.K, 0};
thr = [30 40 45 50]; H = 72;
rows17 = find(W(:, 4) == 17);
startDays = round(linspace(15, 345, 12));
rows = {}; hrows = {}; curves = cell(3, 1);
for a = 1:3
    L = simulate_hours(tw, W, arms{a, 2}, arms{a, 3}, 0, []);
    curves{a} = zeros(H + 1, numel(startDays));
    for i = 1:numel(startDays)
        d = startDays(i); t = rows17(d);
        R = run_hold_test(arms{a, 2}, W, L.Tnodes(t, :)', L.hnodes(t, :)', t + 1, H, thr);
        curves{a}(:, i) = R.Ttop;
        rows(end+1, :) = {arms{a, 1}, d, R.Ttop(1), R.fmelt(1), R.E_rec_kWh(1), R.tau(3), R.censored(3), R.tau(4), R.censored(4), ...
            R.Ttop(25), R.fmelt(25), R.E_rec_kWh(25), R.Ttop(37), R.fmelt(37), R.E_rec_kWh(37), ...
            R.Ttop(49), R.fmelt(49), R.E_rec_kWh(49)}; %#ok<AGROW>
        for j = 1:numel(thr)
            hrows(end+1, :) = {arms{a, 1}, d, thr(j), R.tau(j), R.censored(j)}; %#ok<AGROW>
        end
    end
end
T = cell2table(rows, 'VariableNames', {'arm', 'start_day', 'T_top_start_C', 'f_start', 'Erec_start_kWh', 'tau_hold45_h', 'censored45', ...
    'tau_hold50_h', 'censored50', 'T24_C', 'f24', 'Erec24_kWh', 'T36_C', 'f36', 'Erec36_kWh', 'T48_C', 'f48', 'Erec48_kWh'});
TH = cell2table(hrows, 'VariableNames', {'arm', 'start_day', 'threshold_C', 'tau_hold_h', 'censored'});
writetable(T, fullfile(outDir, 'hold_test.csv'));
writetable(TH, fullfile(outDir, 'hold_test_thresholds.csv'));
S = {};
for a = 1:3
    for j = 1:numel(thr)
        s = strcmp(TH.arm, arms{a, 1}) & TH.threshold_C == thr(j);
        S(end+1, :) = {arms{a, 1}, thr(j), mean(TH.tau_hold_h(s)), median(TH.tau_hold_h(s)), min(TH.tau_hold_h(s)), max(TH.tau_hold_h(s)), sum(TH.censored(s))}; %#ok<AGROW>
    end
end
S = cell2table(S, 'VariableNames', {'arm', 'threshold_C', 'tau_mean_h', 'tau_median_h', 'tau_min_h', 'tau_max_h', 'n_censored'});
writetable(S, fullfile(outDir, 'hold_test_summary.csv'));
disp(S);

fig = figure('Visible', 'off', 'Position', [50 50 1300 420], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Hold test, Uttarakhand regime %d, 2023: top-layer temperature after 18:00, sun off, no draw (12 start days)', regime), 'FontWeight', 'bold');
nm = {'plain tank + B0', 'PCM + B0', 'PCM + PPO'};
for a = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    plot(ax, 0:H, curves{a}, 'Color', [0.6 0.6 0.6]); plot(ax, 0:H, mean(curves{a}, 2), 'k-', 'LineWidth', 2);
    for j = 1:numel(thr), yline(ax, thr(j), ':'); end
    xline(ax, [24 36 48], '--'); title(ax, nm{a}); xlabel(ax, 'hours after 18:00'); ylabel(ax, 'T_{top} [\circC]');
    xlim(ax, [0 H]); ylim(ax, [10 75]); grid(ax, 'on');
end
exportgraphics(fig, fullfile(outDir, 'hold_test.png'), 'Resolution', 120); close(fig);
end
