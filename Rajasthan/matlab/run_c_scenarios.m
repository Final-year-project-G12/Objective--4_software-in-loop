function T = run_c_scenarios()
%RUN_C_SCENARIOS  Edge cases for ALL THREE arms (Tamil Nadu scope, item 4): how the PCM stores and releases heat in each arm.
%
%   T = run_c_scenarios;     % writes ../export_r1/scenarios_3arm/ (new folder; the original export_r1/scenarios/ is untouched)
%
% Arms (names as in the Tamil Nadu twin, SAC replaced by the DQN):
%   arm1_plain_B0   water-only tank of the same 50 L (capsules removed, volume refilled), always-charge
%   arm2_pcm_B0     PureTemp 60 tank, always-charge under the in-plant shield (the Objective 2 operating point)
%   arm3_pcm_DQN    the same PCM tank with the trained regime 1 DQN
% Scenarios: the six of run_scenarios.m plus dead / stuck-high / stuck-mid pyranometer (edge_scenarios.m, definitions and
% assumptions in its header). Replay year 2023 (an Objective 3 validation year, so these are not locked-test-year numbers).
% Outputs in ../export_r1/scenarios_3arm/:
%   scenario_summary_3arm.csv   one row per scenario and arm (columns as the Tamil Nadu file, plus PCM store / release columns)
%   <scenario>.png              5-panel plot of the three arms
%   edge_cases_grid.png         delivered energy and shield hours, all scenarios, three arms
%   pyranometer_faults.png      the three pyranometer faults, three arms
% Plain-tank rows: Tpcm_max_C and f_melt_* are NaN / 0 (there are no capsules); the "PCM temperature" of the plain tank is its
% mean water temperature and is not reported.
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = fullfile(here, '..', 'export_r1', 'scenarios_3arm');
if ~isfolder(outDir), mkdir(outDir); end
tw = load_twin_params(fullfile(here, '..', 'export_r1'), 2023);
[sc, inEv, nWin] = edge_scenarios(tw);
armNames = {'arm1_plain_B0', 'arm2_pcm_B0', 'arm3_pcm_DQN'};
rows = {};
for s = 1:numel(sc)
    c = sc(s);
    L = run_arms(tw, c, nWin);
    for a = 1:3
        La = L{a};
        idx = find(inEv, 1, 'last');
        pcmArm = a > 1;
        rows(end+1, :) = {c.name, armNames{a}, sum(La.E_del_Wh(inEv)) / 1000, sum(La.E_unmet_Wh(inEv)) / 1000, ...
            sum(La.n_sw(inEv) + La.n_sp(inEv)), sum(La.n_viol), ifelse(pcmArm, max(La.Tpcm_max), NaN), ...
            ifelse(pcmArm, La.f_melt(idx), 0), La.E_stored_kWh(idx), sum(La.shield_s(inEv)) / 3600, ...
            ifelse(pcmArm, max(La.f_melt(inEv)), 0), max(La.E_stored_kWh(inEv)), sum(La.Tw(inEv) >= 45), sum(La.interlock >= 2)}; %#ok<AGROW>
    end
    plot3arm(c, L, inEv, fullfile(outDir, [c.name '.png']));
    fprintf('[c_scenarios] %-24s delivered(event) plain %.2f  B0 %.2f  DQN %.2f kWh\n', c.name, rows{end-2, 3}, rows{end-1, 3}, rows{end, 3});
end
T = cell2table(rows, 'VariableNames', {'scenario', 'arm', 'delivered_kWh', 'unmet_kWh', 'shield_trips', 'hard_violations', ...
    'Tpcm_max_C', 'f_melt_end', 'E_stored_end_kWh', 'shield_hours_event', 'f_melt_max_event', 'E_stored_max_event_kWh', ...
    'hours_water_ge45_event', 'failsafe_hours'});
writetable(T, fullfile(outDir, 'scenario_summary_3arm.csv'));
grid_plot(T, {sc.name}, fullfile(outDir, 'edge_cases_grid.png'));
fault_plot(T, fullfile(outDir, 'pyranometer_faults.png'));
end

% ----------------------------------------------------------------------
function L = run_arms(tw, c, nWin)
Pp = make_plain_tank(c.P);
L = cell(1, 3);
rng(7); L{1} = simulate_hours(tw, c.W, Pp, 1, c.noise, c.blackout, nWin, c.stuck);
rng(7); L{2} = simulate_hours(tw, c.W, c.P, 1, c.noise, c.blackout, nWin, c.stuck);
rng(7); L{3} = simulate_hours(tw, c.W, c.P, 0, c.noise, c.blackout, nWin, c.stuck);
end

function plot3arm(c, L, inEv, file)
n = numel(L{1}.Tw);  d = (1:n)' / 24;
col = {[0.4 0.4 0.4], [0.85 0.33 0.1], [0 0.45 0.74]};
fig = figure('Visible', 'off', 'Position', [50 50 1150 900], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 5, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Rajasthan regime 1, three arms: %s', c.title), 'FontWeight', 'bold');
sh = @(ax) patch(ax, [find(inEv, 1) find(inEv, 1, 'last') find(inEv, 1, 'last') find(inEv, 1)] / 24, ...
    [ax.YLim(1) ax.YLim(1) ax.YLim(2) ax.YLim(2)], [0.6 0.6 0.6], 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
ax = nexttile(tl); hold(ax, 'on'); plot(ax, d, L{1}.GHI, 'Color', [0.9 0.7 0]); ylabel(ax, 'GHI [W/m^2]');
yyaxis(ax, 'right'); plot(ax, d, L{1}.T_amb, 'k-'); ylabel(ax, 'T_{amb} [\circC]'); xlim(ax, [0 n/24]); grid(ax, 'on');
yyaxis(ax, 'left'); sh(ax); title(ax, 'Real weather driving the plant (grey band = event days)');
ax = nexttile(tl); hold(ax, 'on');
for a = 1:3, plot(ax, d, L{a}.Tw, 'Color', col{a}, 'LineWidth', 1.2); end
plot(ax, d, L{2}.Tpcm, ':', 'Color', col{2}); plot(ax, d, L{3}.Tpcm, ':', 'Color', col{3});
yline(ax, 45, 'g--', '45 \circC'); yline(ax, 72, 'r--', '72 \circC shield'); yline(ax, 75, 'r-', '75 \circC limit');
ylabel(ax, 'top-layer T [\circC]'); xlim(ax, [0 n/24]); grid(ax, 'on'); sh(ax);
legend(ax, {'plain tank', 'PCM + B0', 'PCM + DQN', 'PCM T (B0)', 'PCM T (DQN)'}, 'Orientation', 'horizontal', 'Location', 'northoutside');
ax = nexttile(tl); hold(ax, 'on'); plot(ax, d, L{2}.f_melt, 'Color', col{2}, 'LineWidth', 1.4); plot(ax, d, L{3}.f_melt, 'Color', col{3}, 'LineWidth', 1.4);
yyaxis(ax, 'right'); plot(ax, d, L{1}.E_stored_kWh, ':', 'Color', col{1}); plot(ax, d, L{2}.E_stored_kWh, ':', 'Color', col{2}); plot(ax, d, L{3}.E_stored_kWh, ':', 'Color', col{3});
ylabel(ax, 'stored energy [kWh] (dotted)'); yyaxis(ax, 'left'); ylabel(ax, 'PCM melt fraction'); ylim(ax, [0 1.05]); xlim(ax, [0 n/24]); grid(ax, 'on'); sh(ax);
ax = nexttile(tl); hold(ax, 'on');
for a = 1:3, stairs(ax, d, L{a}.a_exec + 0.06 * (a - 2), 'Color', col{a}); end
yticks(ax, [0 1 2]); yticklabels(ax, {'CHARGE', 'IDLE', 'BYPASS'}); ylim(ax, [-0.3 2.4]); xlim(ax, [0 n/24]); grid(ax, 'on'); sh(ax);
title(ax, 'executed action (after interlock and plant shield)');
ax = nexttile(tl); hold(ax, 'on');
for a = 1:3, plot(ax, d, cumsum(L{a}.E_del_Wh) / 1000, 'Color', col{a}, 'LineWidth', 1.3); end
ylabel(ax, 'cumulative delivered [kWh]'); xlabel(ax, 'day'); xlim(ax, [0 n/24]); grid(ax, 'on'); sh(ax);
exportgraphics(fig, file, 'Resolution', 110); close(fig);
end

function grid_plot(T, names, file)
arms = {'arm1_plain_B0', 'arm2_pcm_B0', 'arm3_pcm_DQN'};
D = zeros(numel(names), 3);  H = D;
for i = 1:numel(names)
    for a = 1:3
        r = T(strcmp(T.scenario, names{i}) & strcmp(T.arm, arms{a}), :);
        D(i, a) = r.delivered_kWh;  H(i, a) = r.shield_hours_event;
    end
end
fig = figure('Visible', 'off', 'Position', [50 50 1300 440], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Edge cases, Rajasthan regime 1 (event = 4 days of April 2023): plain tank, PCM + B0, PCM + DQN', 'FontWeight', 'bold');
ax = nexttile(tl); bar(ax, D); xticks(ax, 1:numel(names)); xticklabels(ax, strrep(names, '_', ' ')); xtickangle(ax, 35);
ylabel(ax, 'delivered in the event [kWh]'); legend(ax, {'plain', 'PCM + B0', 'PCM + DQN'}, 'Location', 'northeast'); grid(ax, 'on');
ax = nexttile(tl); bar(ax, H); xticks(ax, 1:numel(names)); xticklabels(ax, strrep(names, '_', ' ')); xtickangle(ax, 35);
ylabel(ax, 'guard-band (shield) hours in the event'); grid(ax, 'on');
exportgraphics(fig, file, 'Resolution', 120); close(fig);
end

function fault_plot(T, file)
names = {'clear', 'dead_pyranometer', 'stuck_mid_pyranometer', 'stuck_high_pyranometer'};
arms = {'arm1_plain_B0', 'arm2_pcm_B0', 'arm3_pcm_DQN'};
D = zeros(4, 3);  H = D;
for i = 1:4
    for a = 1:3
        r = T(strcmp(T.scenario, names{i}) & strcmp(T.arm, arms{a}), :);
        D(i, a) = r.delivered_kWh;  H(i, a) = r.shield_hours_event;
    end
end
fig = figure('Visible', 'off', 'Position', [50 50 1100 420], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Pyranometer faults (clear April weather): healthy reference, dead (0), stuck at 500, stuck at 1000 W/m^2', 'FontWeight', 'bold');
lab = {'healthy', 'dead (0)', 'stuck 500', 'stuck 1000'};
ax = nexttile(tl); bar(ax, D); xticklabels(ax, lab); ylabel(ax, 'delivered in the event [kWh]'); legend(ax, {'plain', 'PCM + B0', 'PCM + DQN'}, 'Location', 'southeast'); grid(ax, 'on');
ax = nexttile(tl); bar(ax, H); xticklabels(ax, lab); ylabel(ax, 'shield hours in the event'); grid(ax, 'on');
exportgraphics(fig, file, 'Resolution', 120); close(fig);
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
