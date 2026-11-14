function T = run_c_scenarios_sac(regime)
%RUN_C_SCENARIOS_SAC  Edge cases for four arms: plain tank, PCM + B0, PCM + DQN, PCM + SAC.
%
%   T = run_c_scenarios_sac(1);   % writes ../export_r<regime>/scenarios_4arm/  (new folder; scenarios_3arm/ is untouched)
%
% The nine scenarios of edge_scenarios.m (the six original ones, dead pyranometer, stuck at 500 and at 1000 W/m2) on the 10-day April 2023
% window of the chosen regime's own weather, each with the four arms of four_arm_2023.m. The first three arms are run exactly as in
% run_c_scenarios.m (for regime 1 the numbers equal scenarios_3arm/scenario_summary_3arm.csv); the SAC is arm 4. Event days 5-8; the
% metrics are the event-window ones of run_scenarios.m. rng(7) before every run, as in run_scenarios.m. Regimes 0 and 2: the released DQN
% always charges, so arms 2 and 3 are identical there.
% The last two columns score the FULL 10-day window (as Tamil Nadu does for its pyranometer faults, which are a standing equipment condition).
% Output: scenario_summary_4arm.csv, one plot per scenario, edge_cases_grid_4arm.png.
if nargin < 1 || isempty(regime), regime = 1; end
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = fullfile(here, '..', sprintf('export_r%d', regime), 'scenarios_4arm');
if ~isfolder(outDir), mkdir(outDir); end
tw = load_twin_params(fullfile(here, '..', sprintf('export_r%d', regime)), 2023);
assert(isfield(tw, 'sac'), 'sac_actor_r%d.json missing', regime);
[sc, inEv, nWin] = edge_scenarios(tw);
armNames = {'arm1_plain_B0', 'arm2_pcm_B0', 'arm3_pcm_DQN', 'arm4_pcm_SAC'};
rows = {};
for s = 1:numel(sc)
    c = sc(s);
    Pp = make_plain_tank(c.P);
    L = cell(1, 4);
    rng(7); L{1} = simulate_hours(tw, c.W, Pp, 1, c.noise, c.blackout, nWin, c.stuck);
    rng(7); L{2} = simulate_hours(tw, c.W, c.P, 1, c.noise, c.blackout, nWin, c.stuck);
    rng(7); L{3} = simulate_hours(tw, c.W, c.P, 0, c.noise, c.blackout, nWin, c.stuck);
    rng(7); L{4} = simulate_hours(tw, c.W, c.P, 2, c.noise, c.blackout, nWin, c.stuck);
    idx = find(inEv, 1, 'last');
    for a = 1:4
        La = L{a};  pcmArm = a > 1;
        rows(end+1, :) = {c.name, armNames{a}, sum(La.E_del_Wh(inEv)) / 1000, sum(La.E_unmet_Wh(inEv)) / 1000, sum(La.n_sw(inEv) + La.n_sp(inEv)), ...
            sum(La.n_viol), ifelse(pcmArm, max(La.Tpcm_max), NaN), ifelse(pcmArm, La.f_melt(idx), 0), La.E_stored_kWh(idx), ...
            sum(La.shield_s(inEv)) / 3600, ifelse(pcmArm, max(La.f_melt(inEv)), 0), max(La.E_stored_kWh(inEv)), sum(La.Tw(inEv) >= 45), ...
            sum(La.interlock >= 2), sum(La.a_cmd(inEv) ~= 0), sum(La.E_del_Wh) / 1000, sum(La.shield_s) / 3600}; %#ok<AGROW>
    end
    plot4(c, L, inEv, fullfile(outDir, [c.name '.png']), regime);
    fprintf('[c_scenarios_sac] r%d %-24s delivered(event) plain %.2f  B0 %.2f  DQN %.2f  SAC %.2f kWh\n', regime, c.name, rows{end-3, 3}, rows{end-2, 3}, rows{end-1, 3}, rows{end, 3});
end
T = cell2table(rows, 'VariableNames', {'scenario', 'arm', 'delivered_kWh', 'unmet_kWh', 'shield_trips', 'hard_violations', 'Tpcm_max_C', ...
    'f_melt_end', 'E_stored_end_kWh', 'shield_hours_event', 'f_melt_max_event', 'E_stored_max_event_kWh', 'hours_water_ge45_event', ...
    'failsafe_hours', 'not_charge_hours_event', 'delivered_kWh_10day', 'shield_hours_10day'});
writetable(T, fullfile(outDir, 'scenario_summary_4arm.csv'));
names = {sc.name};  arms = armNames;
D = zeros(numel(names), 4);  H = D;
for i = 1:numel(names)
    for a = 1:4
        r = T(strcmp(T.scenario, names{i}) & strcmp(T.arm, arms{a}), :);
        D(i, a) = r.delivered_kWh;  H(i, a) = r.shield_hours_event;
    end
end
fig = figure('Visible', 'off', 'Position', [50 50 1350 440], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Edge cases, Rajasthan regime %d (event = 4 days of April 2023): plain, PCM + B0, PCM + DQN, PCM + SAC', regime), 'FontWeight', 'bold');
ax = nexttile(tl); bar(ax, D); xticks(ax, 1:numel(names)); xticklabels(ax, strrep(names, '_', ' ')); xtickangle(ax, 35);
ylabel(ax, 'delivered in the event [kWh]'); legend(ax, {'plain', 'PCM + B0', 'PCM + DQN', 'PCM + SAC'}, 'Location', 'northeast'); grid(ax, 'on');
ax = nexttile(tl); bar(ax, H); xticks(ax, 1:numel(names)); xticklabels(ax, strrep(names, '_', ' ')); xtickangle(ax, 35);
ylabel(ax, 'guard-band (shield) hours in the event'); grid(ax, 'on');
exportgraphics(fig, fullfile(outDir, 'edge_cases_grid_4arm.png'), 'Resolution', 120); close(fig);
end

function plot4(c, L, inEv, file, regime)
n = numel(L{1}.Tw);  d = (1:n)' / 24;
col = {[0.4 0.4 0.4], [0.85 0.33 0.1], [0 0.45 0.74], [0.47 0.67 0.19]};
fig = figure('Visible', 'off', 'Position', [50 50 1150 900], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 5, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Rajasthan regime %d, four arms: %s', regime, c.title), 'FontWeight', 'bold');
sh = @(ax) patch(ax, [find(inEv, 1) find(inEv, 1, 'last') find(inEv, 1, 'last') find(inEv, 1)] / 24, ...
    [ax.YLim(1) ax.YLim(1) ax.YLim(2) ax.YLim(2)], [0.6 0.6 0.6], 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');
ax = nexttile(tl); hold(ax, 'on'); plot(ax, d, L{1}.GHI, 'Color', [0.9 0.7 0]); ylabel(ax, 'GHI [W/m^2]');
yyaxis(ax, 'right'); plot(ax, d, L{1}.T_amb, 'k-'); ylabel(ax, 'T_{amb} [\circC]'); xlim(ax, [0 n/24]); grid(ax, 'on');
yyaxis(ax, 'left'); sh(ax); title(ax, 'Real weather driving the plant (grey band = event days)');
ax = nexttile(tl); hold(ax, 'on');
for a = 1:4, plot(ax, d, L{a}.Tw, 'Color', col{a}, 'LineWidth', 1.2); end
yline(ax, 45, 'g--', '45 \circC'); yline(ax, 72, 'r--', '72 \circC shield'); yline(ax, 75, 'r-', '75 \circC limit');
ylabel(ax, 'top-layer T [\circC]'); xlim(ax, [0 n/24]); grid(ax, 'on'); sh(ax);
legend(ax, {'plain', 'PCM + B0', 'PCM + DQN', 'PCM + SAC'}, 'Orientation', 'horizontal', 'Location', 'northoutside');
ax = nexttile(tl); hold(ax, 'on'); for a = 2:4, plot(ax, d, L{a}.f_melt, 'Color', col{a}, 'LineWidth', 1.3); end
ylabel(ax, 'PCM melt fraction'); ylim(ax, [0 1.05]); xlim(ax, [0 n/24]); grid(ax, 'on'); sh(ax);
ax = nexttile(tl); hold(ax, 'on');
for a = 1:4, stairs(ax, d, L{a}.a_exec + 0.05 * (a - 2.5), 'Color', col{a}); end
yticks(ax, [0 1 2]); yticklabels(ax, {'CHARGE', 'IDLE', 'BYPASS'}); ylim(ax, [-0.3 2.4]); xlim(ax, [0 n/24]); grid(ax, 'on'); sh(ax);
title(ax, 'executed action (after interlock and plant shield)');
ax = nexttile(tl); hold(ax, 'on'); for a = 1:4, plot(ax, d, cumsum(L{a}.E_del_Wh) / 1000, 'Color', col{a}, 'LineWidth', 1.3); end
ylabel(ax, 'cumulative delivered [kWh]'); xlabel(ax, 'day'); xlim(ax, [0 n/24]); grid(ax, 'on'); sh(ax);
exportgraphics(fig, file, 'Resolution', 110); close(fig);
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
