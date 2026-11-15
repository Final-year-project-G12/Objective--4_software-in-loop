function T = run_c_scenarios(regime)
%RUN_C_SCENARIOS  Edge cases for ALL THREE arms (joint plan section 2.5): how the PCM stores and releases heat.
%
%   T = run_c_scenarios;   % regime 1; writes ../export_r1/scenarios_3arm/ (the 2010 export_r1/scenarios/ stays)
%
% Arms: arm1_plain_B0 (O2 water-only twin), arm2_pcm_B0 (O2 tank, always-enable), arm3_pcm_PPO (recommended PPO +
% smart forecast). Nine scenarios (edge_scenarios.m). Replay year 2023 = an O3 validation year.
% Outputs: scenario_summary_3arm.csv, <scenario>.png, edge_cases_grid.png, pyranometer_faults.png
if nargin < 1 || isempty(regime), regime = 1; end
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = fullfile(twin_export_dir(regime), 'scenarios_3arm');
if ~isfolder(outDir), mkdir(outDir); end
tw = load_twin_params(twin_export_dir(regime), 2023);
C = load_campaign(regime);
[sc, inEv, nWin] = edge_scenarios(tw, C.base.K);
armNames = {'arm1_plain_B0', 'arm2_pcm_B0', 'arm3_pcm_PPO'};
rows = {};
for s = 1:numel(sc)
    c = sc(s);
    L = run_arms(tw, C, c, nWin);
    for a = 1:3
        La = L{a}; idx = find(inEv, 1, 'last'); pcmArm = a > 1;
        rows(end+1, :) = {c.name, armNames{a}, sum(La.E_del_Wh(inEv)) / 1000, sum(La.E_del45_Wh(inEv)) / 1000, ...
            sum(La.E_del_Wh(inEv & La.in_window > 0.5)) / 1000, sum(La.E_unmet_Wh(inEv)) / 1000, ...
            sum(La.shield_w_s(inEv) + La.shield_p_s(inEv)) / 3600, sum(La.over_limit_s) / 3600, ...
            ifelse(pcmArm, max(La.T_pcm_max), NaN), ifelse(pcmArm, La.f_melt(idx), 0), La.E_stored_kWh(idx), ...
            ifelse(pcmArm, max(La.f_melt(inEv)), 0), max(La.E_stored_kWh(inEv)), sum(La.T_top(inEv) >= 50), ...
            sum(La.a_cmd(inEv) == 0), sum(La.interlock >= 2)}; %#ok<AGROW>
    end
    plot3arm(c, L, inEv, regime, fullfile(outDir, [c.name '.png']));
    fprintf('[c_scenarios] %-24s delivered50(event) plain %.2f  B0 %.2f  PPO %.2f kWh  PPO bypass h %d\n', c.name, ...
        rows{end-2, 3}, rows{end-1, 3}, rows{end, 3}, rows{end, 15});
end
T = cell2table(rows, 'VariableNames', {'scenario', 'arm', 'delivered50_kWh', 'delivered45_kWh', 'window50_kWh', 'unmet50_kWh', ...
    'shield_hours_event', 'hours_over_limit_all', 'Tpcm_max_C', 'f_melt_end', 'E_stored_end_kWh', 'f_melt_max_event', ...
    'E_stored_max_event_kWh', 'hours_top_ge50_event', 'bypass_hours_event', 'failsafe_hours'});
writetable(T, fullfile(outDir, 'scenario_summary_3arm.csv'));
grid_plot(T, {sc.name}, regime, fullfile(outDir, 'edge_cases_grid.png'));
fault_plot(T, fullfile(outDir, 'pyranometer_faults.png'));
end

% ----------------------------------------------------------------------
function L = run_arms(tw, C, c, nWin)
Kp = C.water_only; Kp.P(3) = Kp.P(3) + c.dmains;
Kc = C.base.K;     Kc.P(3) = Kc.P(3) + c.dmains;
o = struct('stuck', c.stuck, 'n', nWin);
L = cell(1, 3);
rng(7); L{1} = simulate_hours(tw, c.W, Kp, 1, c.noise, c.blackout, o);
rng(7); L{2} = simulate_hours(tw, c.W, Kc, 1, c.noise, c.blackout, o);
rng(7); L{3} = simulate_hours(tw, c.W, Kc, 0, c.noise, c.blackout, o);
end

function plot3arm(c, L, inEv, regime, file)
n = numel(L{1}.T_top); d = (1:n)' / 24;
col = {[0.4 0.4 0.4], [0.85 0.33 0.1], [0 0.45 0.74]};
fig = figure('Visible', 'off', 'Position', [50 50 1150 900], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 5, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Uttarakhand regime %d, three arms: %s', regime, c.title), 'FontWeight', 'bold');
sh = @(ax) patch(ax, [find(inEv, 1) find(inEv, 1, 'last') find(inEv, 1, 'last') find(inEv, 1)] / 24, ...
    [ax.YLim(1) ax.YLim(1) ax.YLim(2) ax.YLim(2)], [0.6 0.6 0.6], 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
ax = nexttile(tl); hold(ax, 'on'); plot(ax, d, L{1}.GHI, 'Color', [0.9 0.7 0]); plot(ax, d, L{3}.GHI_meas, ':', 'Color', [0.6 0.4 0]);
ylabel(ax, 'GHI [W/m^2]'); yyaxis(ax, 'right'); plot(ax, d, L{1}.T_amb, 'k-'); ylabel(ax, 'T_{amb} [\circC]'); xlim(ax, [0 n/24]); grid(ax, 'on');
yyaxis(ax, 'left'); sh(ax); title(ax, 'Real weather (solid) and what the controller''s pyranometer reads (dotted); grey band = event days');
ax = nexttile(tl); hold(ax, 'on');
for a = 1:3, plot(ax, d, L{a}.T_top, 'Color', col{a}, 'LineWidth', 1.2); end
plot(ax, d, L{2}.Tpcm, ':', 'Color', col{2}); plot(ax, d, L{3}.Tpcm, ':', 'Color', col{3});
yline(ax, 50, 'g--', '50 \circC', 'LabelHorizontalAlignment', 'left'); yline(ax, 72, 'r--', '72 \circC shield', 'LabelVerticalAlignment', 'bottom'); yline(ax, 75, 'r-', '75 \circC limit');
ylabel(ax, 'top-layer T [\circC]'); xlim(ax, [0 n/24]); grid(ax, 'on'); sh(ax);
legend(ax, {'plain tank', 'PCM + B0', 'PCM + PPO', 'PCM T (B0)', 'PCM T (PPO)'}, 'Orientation', 'horizontal', 'Location', 'northoutside');
ax = nexttile(tl); hold(ax, 'on'); plot(ax, d, L{2}.f_melt, 'Color', col{2}, 'LineWidth', 1.4); plot(ax, d, L{3}.f_melt, 'Color', col{3}, 'LineWidth', 1.4);
yyaxis(ax, 'right'); for a = 1:3, plot(ax, d, L{a}.E_stored_kWh, ':', 'Color', col{a}); end
ylabel(ax, 'stored energy [kWh] (dotted)'); yyaxis(ax, 'left'); ylabel(ax, 'PCM melt fraction'); ylim(ax, [0 1.05]); xlim(ax, [0 n/24]); grid(ax, 'on'); sh(ax);
ax = nexttile(tl); hold(ax, 'on');
for a = 1:3, stairs(ax, d, L{a}.a_cmd + 0.04 * (a - 2), 'Color', col{a}); end
stairs(ax, d, L{3}.pump_frac * 0.8 + 0.1, ':', 'Color', col{3});
yticks(ax, [0 1]); yticklabels(ax, {'BYPASS', 'ENABLE'}); ylim(ax, [-0.2 1.25]); xlim(ax, [0 n/24]); grid(ax, 'on'); sh(ax);
title(ax, 'commanded action per arm (after interlock); dotted = fraction of the hour the PPO arm''s loop ran');
ax = nexttile(tl); hold(ax, 'on');
for a = 1:3, plot(ax, d, cumsum(L{a}.E_del_Wh) / 1000, 'Color', col{a}, 'LineWidth', 1.3); end
ylabel(ax, 'cum. delivered (50 \circC) [kWh]'); xlabel(ax, 'day'); xlim(ax, [0 n/24]); grid(ax, 'on'); sh(ax);
exportgraphics(fig, file, 'Resolution', 110); close(fig);
end

function grid_plot(T, names, regime, file)
arms = {'arm1_plain_B0', 'arm2_pcm_B0', 'arm3_pcm_PPO'};
D = zeros(numel(names), 3); H = D;
for i = 1:numel(names)
    for a = 1:3
        r = T(strcmp(T.scenario, names{i}) & strcmp(T.arm, arms{a}), :);
        D(i, a) = r.delivered50_kWh; H(i, a) = r.shield_hours_event;
    end
end
fig = figure('Visible', 'off', 'Position', [50 50 1300 440], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Edge cases, Uttarakhand regime %d (event = 4 days of April 2023): plain tank, PCM + B0, PCM + PPO', regime), 'FontWeight', 'bold');
ax = nexttile(tl); bar(ax, D); xticks(ax, 1:numel(names)); xticklabels(ax, strrep(names, '_', ' ')); xtickangle(ax, 35);
ylabel(ax, 'delivered to 50 \circC in the event [kWh]'); legend(ax, {'plain', 'PCM + B0', 'PCM + PPO'}, 'Location', 'northeast'); grid(ax, 'on');
ax = nexttile(tl); bar(ax, H); xticks(ax, 1:numel(names)); xticklabels(ax, strrep(names, '_', ' ')); xtickangle(ax, 35);
ylabel(ax, 'guard-band (shield) hours in the event'); grid(ax, 'on');
exportgraphics(fig, file, 'Resolution', 120); close(fig);
end

function fault_plot(T, file)
names = {'clear', 'dead_pyranometer', 'stuck_mid_pyranometer', 'stuck_high_pyranometer'};
arms = {'arm1_plain_B0', 'arm2_pcm_B0', 'arm3_pcm_PPO'};
D = zeros(4, 3); H = D;
for i = 1:4
    for a = 1:3
        r = T(strcmp(T.scenario, names{i}) & strcmp(T.arm, arms{a}), :);
        D(i, a) = r.delivered50_kWh; H(i, a) = r.shield_hours_event;
    end
end
fig = figure('Visible', 'off', 'Position', [50 50 1100 420], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Pyranometer faults (clear April weather): healthy, dead (0), stuck at 500, stuck at 1000 W/m^2', 'FontWeight', 'bold');
lab = {'healthy', 'dead (0)', 'stuck 500', 'stuck 1000'};
ax = nexttile(tl); bar(ax, D); xticklabels(ax, lab); ylabel(ax, 'delivered to 50 \circC in the event [kWh]'); legend(ax, {'plain', 'PCM + B0', 'PCM + PPO'}, 'Location', 'southeast'); grid(ax, 'on');
ax = nexttile(tl); bar(ax, H); xticklabels(ax, lab); ylabel(ax, 'shield hours in the event'); grid(ax, 'on');
exportgraphics(fig, file, 'Resolution', 120); close(fig);
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
