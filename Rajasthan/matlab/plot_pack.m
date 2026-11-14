function plot_pack(which)
%PLOT_PACK  Figures F1-F8 and animations A1-A3 of plan section 8, from results_campaign/ files.
%
%   plot_pack                      % everything
%   plot_pack({'F3','F4'})         % some figures
%   plot_pack({'A1','A2','A3'})    % animations (a few minutes each)
%
% Reads campaign_results.csv, campaign_regimes.csv, hold_curves/, year_trace/, ranking_check.csv and
% benchmark_amanowicz_curves.csv (written by run_campaign.m and benchmark_amanowicz.m).
% Writes PNG / MP4 into results_campaign/figures/. Nothing is drawn by hand.
here = fileparts(mfilename('fullpath')); addpath(here);
if nargin < 1 || isempty(which), which = {'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'A1', 'A2', 'A3'}; end
R = fullfile(here, '..', 'results_campaign');
Fd = fullfile(R, 'figures');
if ~isfolder(Fd), mkdir(Fd); end
cfg = jsondecode(fileread(fullfile(R, 'campaign_config.json')));
pcms = cfg.o1.pcms;
iO2 = find(arrayfun(@(p) p.chosen_by_O2, pcms));
band = cfg.o2.repeatability_band.g_window;
startDays = round(linspace(15, 345, 12));
col = [0.85 0.33 0.10; 0.00 0.45 0.74; 0.47 0.67 0.19];          % one colour per PCM (rank 1, 2, 3)

has = @(k) any(strcmp(which, k));
if has('F1') || has('F2') || has('F3') || has('A2') || has('A3'), best = pick_evening(R, pcms, iO2, startDays); end
if has('F1'), F1(R, Fd, pcms, iO2, best); end
if has('F2'), F2(R, Fd, pcms, iO2, best); end
if has('F3'), F3(R, Fd, pcms, iO2, best, col); end
if has('F4'), F4(R, Fd, pcms, iO2, band, col); end
if has('F5'), F5(R, Fd); end
if has('F6'), F6(R, Fd); end
if has('F7'), F7(R, Fd, band); end
if has('F8'), F8(R, Fd); end
if has('F9'), F9(R, Fd); end
if has('F10'), F10(R, Fd); end
if has('F11'), F11(R, Fd); end
if has('A1'), A1(here, Fd); end
if has('A2') || has('A3'), A23(here, R, Fd, best, which); end
end

% ----------------------------------------------------------------------
function fig = nf(pos)
fig = figure('Visible', 'off', 'Position', pos, 'Color', 'w');
try, theme(fig, 'light'); catch, end      % R2025a+ follows the desktop theme; force light for reports
end

function rid = runid(arm, pcm, ctrl, fm)
rid = sprintf('%s_%s_%s_f%.1f', strrep(arm, '+', '_'), regexprep(pcm, '[^A-Za-z0-9]', ''), ctrl, fm);
rid = strrep(rid, '-', '');
end

function best = pick_evening(R, pcms, iO2, startDays)
% the retention start (of the 12) with the most stored energy at 18:00 in the PCM + DQN run
Y = readtable(fullfile(R, 'year_trace', [runid('PCM+DQN', pcms(iO2).name, 'DQN', 1.0) '.csv']));
rows17 = find(Y.hod == 17);
e = Y.E_stored_kWh(rows17(startDays));
[~, k] = max(e);
best.day = startDays(k);  best.t = rows17(best.day);  best.Y = Y;
end

function F1(R, Fd, pcms, iO2, b)
Y = b.Y;  i0 = b.t - 47;  i1 = b.t + 72;
Tm = Y{i0:i1, strcat('Tnode', string(1:10))}';
fig = nf([50 50 1100 480]);
t = ((i0:i1) - b.t) / 24;
imagesc(t, 1:10, Tm); axis xy; colormap(turbo); cb = colorbar; cb.Label.String = 'water temperature [\circC]';
hold on; contour(t, 1:10, Tm, [45 45], 'k', 'LineWidth', 1.2);
xline(0, 'w--', '18:00 start of hold', 'LabelVerticalAlignment', 'bottom');
xlabel('days from the 18:00 of the hold start'); ylabel('tank layer (1 bottom, 10 top)');
title(sprintf('F1  Tank temperature map, Rajasthan r1, %s + DQN, day %d of 2023 (black line = 45 \\circC)', pcms(iO2).name, b.day));
exportgraphics(fig, fullfile(Fd, 'F1_tank_temperature_map.png'), 'Resolution', 130); close(fig);
end

function F2(R, Fd, pcms, iO2, b)
Y = b.Y;  i0 = b.t - 23;  i1 = b.t + 30;  r = i0:i1;  d = (r - i0)' / 24;
fig = nf([50 50 1100 950]);
tl = tiledlayout(fig, 5, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('F2  Operating trace, Rajasthan r1, %s + DQN (the 10 layers, controller action, energy)', pcms(iO2).name), 'FontWeight', 'bold');
ax = nexttile(tl); yyaxis left; plot(d, Y.GHI(r), 'Color', [0.9 0.7 0]); ylabel('GHI [W/m^2]'); yyaxis right; plot(d, Y.T_amb(r), 'k'); ylabel('T_{amb} [\circC]'); grid on; xlim(ax, [0 d(end)]);
ax = nexttile(tl); hold on;
cm = turbo(10);
for k = 1:10, plot(d, Y.(sprintf('Tnode%d', k))(r), 'Color', cm(k, :)); end
yline(45, 'g--', '45 \circC target'); yline(72, 'r--', '72 \circC'); yline(75, 'r-', '75 \circC limit');
plot(d, Y.T_pcm_C(r), 'k:', 'LineWidth', 1.5); ylabel('T [\circC]'); grid on; xlim(ax, [0 d(end)]);
legend(ax, {'layer 1 ... 10 (blue to red)'}, 'Location', 'northeast', 'Box', 'off');
ax = nexttile(tl); plot(d, Y.f_melt(r), 'Color', [0.9 0.4 0], 'LineWidth', 1.5); ylim([0 1.05]); ylabel('melt fraction'); grid on; xlim(ax, [0 d(end)]);
ax = nexttile(tl); hold on; stairs(d, Y.a_cmd(r), 'b-'); stairs(d, Y.a_exec(r) + 0.08, 'r:');
yticks([0 1 2]); yticklabels({'CHARGE', 'IDLE', 'BYPASS'}); ylim([-0.3 2.4]); grid on; xlim(ax, [0 d(end)]);
legend(ax, {'commanded (after interlock)', 'executed (after plant shield)'}, 'Orientation', 'horizontal', 'Location', 'northoutside');
ax = nexttile(tl); hold on; plot(d, cumsum(Y.E_del_Wh(r)) / 1000, 'b'); plot(d, cumsum(Y.E_unmet_Wh(r)) / 1000, 'm');
ylabel('cumulative kWh'); xlabel('days from 18:00 the evening before'); grid on; xlim(ax, [0 d(end)]); legend({'delivered (45 \circC)', 'unmet'}, 'Location', 'northwest');
exportgraphics(fig, fullfile(Fd, 'F2_operating_trace.png'), 'Resolution', 110); close(fig);
end

function F3(R, Fd, pcms, iO2, b, col)
fig = nf([50 50 1100 700]);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('F3  Retention after charging stops, Rajasthan r1, evening of day %d (sun off, no draw)', b.day), 'FontWeight', 'bold');
ax1 = nexttile(tl); hold on; ax2 = nexttile(tl); hold on;
lab = {};
for i = 1:numel(pcms)
    C = readtable(fullfile(R, 'hold_curves', [runid('PCM+DQN', pcms(i).name, 'DQN', 1.0) '.csv']));
    C = C(C.start_day == b.day, :);
    plot(ax1, C.hour, C.T_top_C, 'Color', col(i, :), 'LineWidth', 1.6);
    plot(ax2, C.hour, C.E_rec45_kWh, 'Color', col(i, :), 'LineWidth', 1.6);
    lab{end+1} = sprintf('%s (O1 rank %d)', pcms(i).name, pcms(i).consensus_rank); %#ok<AGROW>
end
C = readtable(fullfile(R, 'hold_curves', [runid('PCM-free', 'none', 'B0', 1.0) '.csv']));
C = C(C.start_day == b.day, :);
plot(ax1, C.hour, C.T_top_C, 'k--', 'LineWidth', 1.4);  plot(ax2, C.hour, C.E_rec45_kWh, 'k--', 'LineWidth', 1.4);
lab{end+1} = 'water-only tank (same volume)';
for ax = [ax1 ax2]
    for x = [24 36 48], xline(ax, x, ':', sprintf('%d h', x), 'Color', [0.5 0.5 0.5]); end
    grid(ax, 'on'); xlim(ax, [0 72]);
end
yline(ax1, 45, 'g--', '45 \circC target'); ylabel(ax1, 'top-layer temperature [\circC]');
ylabel(ax2, 'recoverable energy above 45 \circC [kWh]'); xlabel(ax2, 'hours after 18:00');
legend(ax1, lab, 'Location', 'northeast');
exportgraphics(fig, fullfile(Fd, 'F3_retention_curves.png'), 'Resolution', 120); close(fig);
end

function F4(R, Fd, pcms, iO2, band, col)
T = readtable(fullfile(R, 'campaign_results.csv'));
arms = {'PCM-free', 'PCM+B0', 'PCM+DQN'};
fig = nf([50 50 1250 460]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'F4  Retention and evening-window delivery, Rajasthan r1, 12 evenings, 2023', 'FontWeight', 'bold');
groups = {'water-only', pcms(1).name, pcms(2).name, pcms(3).name};
% (a) tau_hold 45 C with spread over the 12 starts, from the hold curves
ax = nexttile(tl); hold on; xs = 0;
for a = 1:3
    for g = 1:4
        if (a == 1) ~= (g == 1), continue; end
        if a == 1, rid = runid('PCM-free', 'none', 'B0', 1.0); else, rid = runid(arms{a}, pcms(g - 1).name, ifelse(a == 2, 'B0', 'DQN'), 1.0); end
        C = readtable(fullfile(R, 'hold_curves', [rid '.csv']));
        tau = arrayfun(@(d) tau_of(C(C.start_day == d, :), 45), unique(C.start_day));
        xs = xs + 1;
        bar(ax, xs, mean(tau), 'FaceColor', colfor(a, g, col));
        errorbar(ax, xs, mean(tau), std(tau), 'k', 'LineStyle', 'none');
        lbl{xs} = sprintf('%s\n%s', strrep(arms{a}, 'PCM-free', 'water'), shortname(groups{g})); %#ok<AGROW>
    end
end
xticks(ax, 1:xs); xticklabels(ax, lbl); xtickangle(ax, 45); ylabel(ax, 'hours above 45 \circC'); yline(ax, 72, 'k:', '72 h cap'); grid(ax, 'on');
title(ax, '(a) \tau_{hold}, mean \pm SD of 12 starts');
% (b) recoverable energy at 24/36/48 h, PCM + DQN and water
ax = nexttile(tl); hold on;
M = zeros(4, 3); ks = [24 36 48];
for g = 1:4
    if g == 1, row = T(strcmp(T.arm, 'PCM-free') & T.flow_mult == 1, :); else, row = T(strcmp(T.arm, 'PCM+DQN') & T.flow_mult == 1 & T.pcm_rank == pcms(g - 1).consensus_rank, :); end
    M(g, :) = [row.E_rec45_24h_kWh row.E_rec45_36h_kWh row.E_rec45_48h_kWh];
end
bar(ax, M); xticklabels(ax, cellfun(@shortname, groups, 'UniformOutput', false)); xtickangle(ax, 45);
legend(ax, {'24 h', '36 h', '48 h'}, 'Location', 'northoutside', 'Orientation', 'horizontal'); ylabel(ax, 'recoverable energy above 45 \circC [kWh]'); grid(ax, 'on');
title(ax, '(b) E_{rec} after 24/36/48 h (DQN arm, mean of 12)');
% (c) window delivered energy with the Objective 2 repeatability band as error bar
ax = nexttile(tl); hold on; xs = 0; lbl = {};
for a = 1:3
    for g = 1:4
        if (a == 1) ~= (g == 1), continue; end
        if a == 1, row = T(strcmp(T.arm, 'PCM-free') & T.flow_mult == 1, :); else, row = T(strcmp(T.arm, arms{a}) & T.flow_mult == 1 & T.pcm_rank == pcms(g - 1).consensus_rank, :); end
        xs = xs + 1;
        bar(ax, xs, row.E_del45_win_kWh, 'FaceColor', colfor(a, g, col));
        errorbar(ax, xs, row.E_del45_win_kWh, band, 'k', 'LineStyle', 'none');
        lbl{xs} = sprintf('%s\n%s', strrep(arms{a}, 'PCM-free', 'water'), shortname(groups{g})); %#ok<AGROW>
    end
end
xticks(ax, 1:xs); xticklabels(ax, lbl); xtickangle(ax, 45); ylabel(ax, 'delivered 18:00-09:00, 45 \circC [kWh/yr]'); grid(ax, 'on');
title(ax, sprintf('(c) window energy, bar = O2 repeatability band \\pm%.1f kWh', band));
exportgraphics(fig, fullfile(Fd, 'F4_retention_bars.png'), 'Resolution', 120); close(fig);
end

function F5(R, Fd)
f = fullfile(R, 'campaign_regimes.csv');
if ~isfile(f), fprintf('[plot_pack] F5 skipped: campaign_regimes.csv missing (run_campaign({''regimes''}))\n'); return; end
T = readtable(f);
fig = nf([50 50 1200 430]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'F5  Three Rajasthan regimes side by side (own exported PCM and DQN each), 2023', 'FontWeight', 'bold');
reg = (0:2)';  names = arrayfun(@(r) sprintf('regime %d', r), reg, 'UniformOutput', false);
get = @(arm, v) arrayfun(@(r) T.(v)(strcmp(T.arm, arm) & T.regime == r), reg);
ax = nexttile(tl); bar(ax, [get('PCM+B0', 'E_del45_per_kgPCM_kWh') get('PCM+DQN', 'E_del45_per_kgPCM_kWh')]);
xticklabels(ax, names); ylabel(ax, 'delivered energy per kg PCM [kWh/kg/yr]'); legend(ax, {'B0', 'DQN'}); grid(ax, 'on'); title(ax, '(a) per kg of PCM');
ax = nexttile(tl); bar(ax, [get('PCM-free', 'E_del45_per_m2_kWh') get('PCM+B0', 'E_del45_per_m2_kWh') get('PCM+DQN', 'E_del45_per_m2_kWh')]);
xticklabels(ax, names); ylabel(ax, 'delivered energy per m^2 collector [kWh/m^2/yr]'); legend(ax, {'water-only B0', 'PCM B0', 'PCM DQN'}); grid(ax, 'on'); title(ax, '(b) per m^2 of collector');
ax = nexttile(tl); bar(ax, [get('PCM-free', 'tau_hold_45C_mean_h') get('PCM+B0', 'tau_hold_45C_mean_h') get('PCM+DQN', 'tau_hold_45C_mean_h')]);
xticklabels(ax, names); ylabel(ax, 'mean hours above 45 \circC'); yline(ax, 72, 'k:', '72 h cap'); legend(ax, {'water-only B0', 'PCM B0', 'PCM DQN'}, 'Location', 'southeast'); grid(ax, 'on'); title(ax, '(c) retention \tau_{hold}');
exportgraphics(fig, fullfile(Fd, 'F5_three_regimes.png'), 'Resolution', 120); close(fig);
end

function F6(R, Fd)
T = readtable(fullfile(R, 'ranking_check.csv'));
fig = nf([50 50 900 400]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'F6  Does Objective 1''s PCM ranking survive with a controller in the loop? (3 PCMs, Rajasthan r1)', 'FontWeight', 'bold');
for c = {'B0', 'DQN'}
    s = T(strcmp(T.controller, c{1}), :);
    ax = nexttile(tl); hold on;
    plot(ax, [0.5 3.5], [0.5 3.5], 'k:');
    scatter(ax, s.o1_consensus_rank, s.twin_rank_by_tau_hold, 120, 'filled');
    for k = 1:height(s), text(ax, s.o1_consensus_rank(k) + 0.08, s.twin_rank_by_tau_hold(k) + 0.12, s.pcm{k}, 'FontSize', 8); end
    xlim(ax, [0.5 3.5]); ylim(ax, [0.5 3.5]); xticks(ax, 1:3); yticks(ax, 1:3); grid(ax, 'on');
    xlabel(ax, 'Objective 1 consensus rank'); ylabel(ax, 'twin rank (by \tau_{hold}, then window energy)');
    title(ax, sprintf('%s: Spearman \\rho = %.2f (n = 3)', c{1}, s.spearman_tau_vs_o1(1)));
end
exportgraphics(fig, fullfile(Fd, 'F6_ranking_check.png'), 'Resolution', 120); close(fig);
end

function F7(R, Fd, band)
T = readtable(fullfile(R, 'campaign_results.csv'));
fig = nf([50 50 1000 420]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'F7  Flow sensitivity, Rajasthan r1 (collector F_R held flow-independent: a known limitation)', 'FontWeight', 'bold');
fm = [0.7 1.0 1.3];
sets = {'PCM-free', 'PCM+B0', 'PCM+DQN'};  sty = {'k--o', 'b-o', 'r-o'};
ax1 = nexttile(tl); hold on; ax2 = nexttile(tl); hold on;
for s = 1:3
    e = zeros(1, 3); t = e;
    for j = 1:3
        sel = strcmp(T.arm, sets{s}) & abs(T.flow_mult - fm(j)) < 1e-9 & (T.pcm_rank == 0 | T.pcm_rank == 1);
        e(j) = T.E_del45_win_kWh(sel);  t(j) = T.tau_hold_45C_mean_h(sel);
    end
    plot(ax1, fm, e, sty{s}, 'LineWidth', 1.4);  plot(ax2, fm, t, sty{s}, 'LineWidth', 1.4);
end
xlabel(ax1, 'flow multiplier (x O2 nominal)'); ylabel(ax1, 'delivered 18:00-09:00, 45 \circC [kWh/yr]'); grid(ax1, 'on');
title(ax1, sprintf('(a) window energy (O2 band \\pm%.1f kWh)', band)); legend(ax1, {'water-only B0', 'PCM B0', 'PCM DQN'}, 'Location', 'best');
xlabel(ax2, 'flow multiplier (x O2 nominal)'); ylabel(ax2, 'mean hours above 45 \circC'); grid(ax2, 'on'); title(ax2, '(b) retention \tau_{hold}');
exportgraphics(fig, fullfile(Fd, 'F7_flow_sensitivity.png'), 'Resolution', 120); close(fig);
end

function F8(R, Fd)
C = readtable(fullfile(R, 'benchmark_amanowicz_curves.csv'));
S = readtable(fullfile(R, 'benchmark_amanowicz_summary.csv'));
fig = nf([50 50 1050 430]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'F8  Twin vs Amanowicz & Turski (2025): water only and water + 9 RT44HC capsules', 'FontWeight', 'bold');
vars = {'volume_fitted', 'sv_apriori', 'sv_fitted'};  sty = {'-', '-', '-'};  cc = [0.55 0.55 0.55; 0.47 0.67 0.19; 0.85 0.33 0.1];
for cs = 1:2
    ax = nexttile(tl); hold on;
    plot(ax, C.t_s / 60, C.(sprintf('paper_fit_case%d_C', cs)), 'k-', 'LineWidth', 2.2);
    for v = 1:3, plot(ax, C.t_s / 60, C.(sprintf('model_case%d_%s', cs, vars{v})), sty{v}, 'Color', cc(v, :), 'LineWidth', 1.4); end
    xlabel(ax, 'time [min]'); ylabel(ax, 'water temperature [\circC]'); grid(ax, 'on');
    r = S{strcmp(S.capsule_shape, 'sv') & strcmp(S.loss_coefficient, 'fitted'), sprintf('case%d_RMSE_K', cs)};
    m = S{strcmp(S.capsule_shape, 'sv') & strcmp(S.loss_coefficient, 'fitted'), sprintf('case%d_MAE_K', cs)};
    title(ax, sprintf('case %d: RMSE %.2f K, MAE %.2f K (matched surface/volume, fitted loss)', cs, r, m));
    if cs == 1, legend(ax, {'paper (printed linear fit)', 'one sphere per capsule, UA fitted', 'matched surface/volume, UA a priori', 'matched surface/volume, UA fitted'}, 'Location', 'northeast'); end
end
exportgraphics(fig, fullfile(Fd, 'F8_experiment_comparison.png'), 'Resolution', 120); close(fig);
end

function F9(R, Fd)
% the seven edge cases (six original + dead pyranometer), DQN against B0, from run_scenarios with deadPyr = true
f = fullfile(R, 'edge_cases_with_dead_pyranometer', 'scenario_summary_with_dead_pyranometer.csv');
if ~isfile(f), fprintf('[plot_pack] F9 skipped: %s missing\n', f); return; end
T = readtable(f);
sc = unique(T.scenario, 'stable');
D = zeros(numel(sc), 2);  H = D;
for i = 1:numel(sc)
    a = T(strcmp(T.scenario, sc{i}) & strcmp(T.policy, 'DQN'), :);  b = T(strcmp(T.scenario, sc{i}) & strcmp(T.policy, 'B0'), :);
    D(i, :) = [a.delivered_kWh_event b.delivered_kWh_event];  H(i, :) = [a.shield_hours_event b.shield_hours_event];
end
fig = nf([50 50 1150 420]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'F9  Edge cases, Rajasthan r1 (event = 4 days of April 2023), DQN against always-charge B0', 'FontWeight', 'bold');
lab = strrep(sc, '_', ' ');
ax = nexttile(tl); bar(ax, D); xticks(ax, 1:numel(sc)); xticklabels(ax, lab); xtickangle(ax, 30); ylabel(ax, 'delivered heat in the event [kWh]');
legend(ax, {'DQN', 'B0'}, 'Location', 'northeast'); grid(ax, 'on'); title(ax, '(a) delivered energy');
ax = nexttile(tl); bar(ax, H); xticks(ax, 1:numel(sc)); xticklabels(ax, lab); xtickangle(ax, 30); ylabel(ax, 'guard-band (shield) hours in the event');
grid(ax, 'on'); title(ax, '(b) shield hours; dead pyranometer = last group');
exportgraphics(fig, fullfile(Fd, 'F9_edge_cases_with_dead_pyranometer.png'), 'Resolution', 120); close(fig);
end

function F10(R, Fd)
% the three Rajasthan regimes with the Objective 3 SAC as a fourth arm (run_campaign({'sac'}, '_sac'))
f = fullfile(R, 'campaign_regimes_sac.csv');
if ~isfile(f), fprintf('[plot_pack] F10 skipped: campaign_regimes_sac.csv missing\n'); return; end
T = readtable(f);
arms = {'PCM-free', 'PCM+B0', 'PCM+DQN', 'PCM+SAC'};  lab = {'water-only', 'PCM + B0', 'PCM + DQN', 'PCM + SAC'};
cols = [0.5 0.5 0.5; 0.85 0.33 0.1; 0 0.45 0.74; 0.47 0.67 0.19];
vars = {'E_del45_kWh', 'tau_hold_45C_mean_h', 'guard_band_h'};
ttl = {'delivered 2023 [kWh]', 'hold above 45 \circC, mean of 12 evenings [h]', 'guard-band hours'};
fig = nf([50 50 1250 430]);
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'F10  Three Rajasthan regimes, four arms: water-only, PCM + B0, PCM + DQN, PCM + SAC (2023)', 'FontWeight', 'bold');
for k = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    M = zeros(3, 4);
    for r = 0:2
        for a = 1:4, M(r + 1, a) = T.(vars{k})(strcmp(T.arm, arms{a}) & T.regime == r); end
    end
    b = bar(ax, M);
    for a = 1:4, b(a).FaceColor = cols(a, :); end
    xticklabels(ax, {'regime 0', 'regime 1', 'regime 2'}); ylabel(ax, ttl{k}); grid(ax, 'on');
    if k == 1, legend(ax, lab, 'Location', 'southeast'); end
    if k == 2, yline(ax, 72, 'k:', '72 h cap'); end
end
exportgraphics(fig, fullfile(Fd, 'F10_four_arms_three_regimes.png'), 'Resolution', 120); close(fig);
end

function F11(R, Fd)
% Objective 3's observation faults on the twin, regime 1: B0, DQN, SAC (o3_sensor_faults.csv from run_o3_sensor_faults.m)
f = fullfile(R, 'o3_sensor_faults.csv');
if ~isfile(f), fprintf('[plot_pack] F11 skipped: o3_sensor_faults.csv missing\n'); return; end
T = readtable(f);  T = T(T.regime == 1, :);
faults = unique(T.fault, 'stable');  ctrls = {'B0', 'DQN', 'SAC'};
cols = [0.85 0.33 0.1; 0 0.45 0.74; 0.47 0.67 0.19];
fig = nf([50 50 1200 430]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'F11  Objective 3 observation faults on the twin, regime 1, 2023 (physics and shield see the true state)', 'FontWeight', 'bold');
vars = {'E_del45_kWh', 'guard_band_h'};  ttl = {'delivered [kWh]', 'guard-band hours'};
for k = 1:2
    ax = nexttile(tl); M = zeros(numel(faults), 3);
    for c = 1:3, for i = 1:numel(faults), M(i, c) = T.(vars{k})(strcmp(T.controller, ctrls{c}) & strcmp(T.fault, faults{i})); end, end
    b = bar(ax, M);  for c = 1:3, b(c).FaceColor = cols(c, :); end
    xticklabels(ax, strrep(faults, '_', ' ')); xtickangle(ax, 35); ylabel(ax, ttl{k}); grid(ax, 'on');
    if k == 1, legend(ax, {'B0', 'DQN', 'SAC'}, 'Location', 'southeast'); ylim(ax, [min(M(:)) * 0.97, max(M(:)) * 1.02]); end
end
exportgraphics(fig, fullfile(Fd, 'F11_o3_sensor_faults.png'), 'Resolution', 120); close(fig);
end

function A1(here, Fd)
% schematic with the fixed pump drawing: April 2023 clear days, regime 1, DQN
make_my_video('scenario', 'clear', 'days', [4 8], 'out', fullfile(Fd, 'A1_schematic_clear_days.mp4'), 'frames_per_hour', 2);
end

function A23(here, R, Fd, b, which)
% re-run the PCM + DQN year (we need the node states), then follow the 72 h hold from the best evening
cfg = jsondecode(fileread(fullfile(R, 'campaign_config.json')));
pcms = cfg.o1.pcms;  iO2 = find(arrayfun(@(p) p.chosen_by_O2, pcms));
tw = load_twin_params(fullfile(here, '..', 'export_r1'), 2023);
W = tw.wx.signals.values(:, 1:4);
L = simulate_hours(tw, W, tw.P, 0, 0, [], b.t);
P = tw.P;  H = 72;
T = L.Tn(b.t, :)';  h = L.hn(b.t, :)';
Tn = zeros(H + 1, 10);  hn = zeros(H + 1, 10);  Tn(1, :) = T';  hn(1, :) = h';
for k = 1:H
    [T, h] = pcm_plant_hour(0, W(b.t + k, 3), 0, 2, T, h, P);
    Tn(k + 1, :) = T';  hn(k + 1, :) = h';
end
rows = b.t + (1:H + 1) - 1;                                    % row 1 = start state
Lh = struct();
Lh.Tw = Tn(:, 10);  Lh.Tbot = Tn(:, 1);  Lh.Tmean = mean(Tn, 2);
fm = zeros(H + 1, 1);  tp = zeros(H + 1, 1);
for k = 1:H + 1, s = pcm_derive_state(Tn(k, :)', hn(k, :)', P); fm(k) = s(5); tp(k) = s(4); end
Lh.Tpcm = tp;  Lh.f_melt = fm;
Lh.GHI = zeros(H + 1, 1);  Lh.a_exec = 2 * ones(H + 1, 1);  Lh.n_sw = zeros(H + 1, 1);  Lh.n_sp = zeros(H + 1, 1);
Lh.interlock = zeros(H + 1, 1);  Lh.draw_kg = zeros(H + 1, 1);  Lh.E_del_Wh = zeros(H + 1, 1);  Lh.Q_coll_Wh = zeros(H + 1, 1);
Lh.T_amb = [W(b.t, 3); W(b.t + (1:H), 3)];  Lh.hod = mod(18 + (0:H)', 24);  Lh.Tw_max = Lh.Tw;  Lh.Tn = Tn;  Lh.hn = hn;
if any(strcmp(which, 'A2'))
    animate_system(Lh, fullfile(Fd, 'A2_retention_72h.mp4'), ...
        sprintf('Retention: sun off, no draw, 72 h from 18:00 (Rajasthan r1, %s)', pcms(iO2).name), 3, tw.P(39), ...
        'SUN OFF - heat released from water and capsules');
end
if any(strcmp(which, 'A3'))
    animate_tank3d(Lh, P, fullfile(Fd, 'A3_tank_3D_retention.mp4'));
end
end

% ----------------------------------------------------------------------
function tau = tau_of(C, thr)
T = C.T_top_C;
if T(1) < thr, tau = 0; return; end
k = find(T < thr, 1);
if isempty(k), tau = numel(T) - 1; return; end
tau = (k - 2) + (T(k - 1) - thr) / (T(k - 1) - T(k));
end

function c = colfor(a, g, col)
if a == 1, c = [0.6 0.6 0.6]; else, c = col(g - 1, :) * (0.6 + 0.4 * (a == 3)); end
end

function s = shortname(n)
s = strrep(strrep(n, 'n-Heptacosane (C27)', 'C27'), 'CrodaTherm', 'Croda');
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
