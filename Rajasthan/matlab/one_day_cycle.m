function T = one_day_cycle(day)
%ONE_DAY_CYCLE  One full charge / idle / bypass cycle for the three arms (Tamil Nadu scope item 3).
%
%   T = one_day_cycle;        % day = the evening of the 12 hold-test starts with the most stored energy in the DQN arm
%   T = one_day_cycle(165);   % any day of 2023 (1-365)
%   writes ../export_r1/one_day_cycle_2023.csv and one_day_cycle_2023.png
%
% Hours 00:00-23:00 local of the chosen day, three arms on the same weather (plain tank, PCM + B0, PCM + DQN), each started from
% its own state in the full-year run. Panels: sun, ambient and hot-water draw; top-layer water temperature of the three arms with the
% PCM temperature (dotted) and the 45 / 72 C lines; melt fraction; collector heat; delivered energy (cumulative); shield activations per hour;
% the executed action of each arm, with the DQN arm's CHARGE / IDLE / BYPASS as background colour.
% Why each arm behaves as it does is written in reports/B_one_day_plots.md.
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = fullfile(here, '..', 'export_r1');
tw = load_twin_params(outDir, 2023);
W = tw.wx.signals.values(:, 1:4);
P = tw.P;  Pp = make_plain_tank(P);
L = {simulate_hours(tw, W, Pp, 1, 0, []), simulate_hours(tw, W, P, 1, 0, []), simulate_hours(tw, W, P, 0, 0, [])};
rows17 = find(W(:, 4) == 17);
if nargin < 1 || isempty(day)
    sd = round(linspace(15, 345, 12));
    [~, k] = max(L{3}.E_stored_kWh(rows17(sd)));
    day = sd(k);
end
r0 = rows17(day) - 17;  r = r0:r0 + 23;
assert(W(r0, 4) == 0, 'one_day_cycle: day %d does not start at local hour 0', day);
names = {'arm1_plain_B0', 'arm2_pcm_B0', 'arm3_pcm_DQN'};
T = table((0:23)', L{1}.GHI(r), L{1}.T_amb(r), L{1}.draw_kg(r), 'VariableNames', {'hour', 'GHI_Wm2', 'T_amb_C', 'draw_kg'});
for a = 1:3
    n = names{a};  La = L{a};
    T.([n '_Ttop_C']) = La.Tw(r);  T.([n '_Tpcm_C']) = La.Tpcm(r);  T.([n '_f_melt']) = La.f_melt(r);
    T.([n '_Qcoll_Wh']) = La.Q_coll_Wh(r);  T.([n '_Edel_Wh']) = La.E_del_Wh(r);  T.([n '_shield_trips']) = La.n_sw(r) + La.n_sp(r);
    T.([n '_action_exec']) = La.a_exec(r);  T.([n '_E_stored_kWh']) = La.E_stored_kWh(r);
end
writetable(T, fullfile(outDir, 'one_day_cycle_2023.csv'));

col = {[0.4 0.4 0.4], [0.85 0.33 0.1], [0 0.45 0.74]};
bg = [0.75 0.92 0.75; 1 0.95 0.7; 0.95 0.75 0.75];            % CHARGE, IDLE, BYPASS
fig = figure('Visible', 'off', 'Position', [50 50 1150 1000], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 6, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('One-day cycle, Rajasthan regime 1, day %d of 2023: plain tank, PCM + B0, PCM + DQN', day), 'FontWeight', 'bold');
h = 0:23;  act = L{3}.a_exec(r);
shade = @(ax) arrayfun(@(i) patch(ax, [h(i) h(i)+1 h(i)+1 h(i)], [ax.YLim(1) ax.YLim(1) ax.YLim(2) ax.YLim(2)], bg(act(i) + 1, :), ...
    'EdgeColor', 'none', 'FaceAlpha', 0.45, 'HandleVisibility', 'off'), 1:24);
ax = nexttile(tl); yyaxis(ax, 'left'); bar(ax, h + 0.5, T.draw_kg, 1, 'FaceColor', [0.7 0.85 1], 'EdgeColor', 'none'); ylabel(ax, 'draw [kg/h]');
yyaxis(ax, 'right'); hold(ax, 'on'); plot(ax, h + 0.5, T.GHI_Wm2, 'Color', [0.9 0.7 0], 'LineWidth', 1.4); plot(ax, h + 0.5, 10 * T.T_amb_C, 'k-');
ylabel(ax, 'GHI [W/m^2]; ambient x10 [\circC]'); xlim(ax, [0 24]); grid(ax, 'on'); title(ax, 'Sun, ambient (x10) and hot-water draw');
ax = nexttile(tl); hold(ax, 'on');
for a = 1:3, plot(ax, h + 0.5, T.([names{a} '_Ttop_C']), 'Color', col{a}, 'LineWidth', 1.5); end
plot(ax, h + 0.5, T.arm2_pcm_B0_Tpcm_C, ':', 'Color', col{2}, 'LineWidth', 1.3); plot(ax, h + 0.5, T.arm3_pcm_DQN_Tpcm_C, ':', 'Color', col{3}, 'LineWidth', 1.3);
yline(ax, 45, 'g--', '45 \circC'); yline(ax, 72, 'r--', '72 \circC shield'); ylabel(ax, 'T [\circC]'); xlim(ax, [0 24]); grid(ax, 'on'); shade(ax);
legend(ax, {'plain top', 'PCM + B0 top', 'PCM + DQN top', 'PCM T (B0)', 'PCM T (DQN)'}, 'Orientation', 'horizontal', 'Location', 'northoutside');
ax = nexttile(tl); hold(ax, 'on'); plot(ax, h + 0.5, T.arm2_pcm_B0_f_melt, 'Color', col{2}, 'LineWidth', 1.5); plot(ax, h + 0.5, T.arm3_pcm_DQN_f_melt, 'Color', col{3}, 'LineWidth', 1.5);
ylabel(ax, 'PCM melt fraction'); ylim(ax, [0 1.05]); xlim(ax, [0 24]); grid(ax, 'on'); shade(ax); title(ax, 'Plain tank has no PCM (melt fraction not defined)');
ax = nexttile(tl); hold(ax, 'on'); for a = 1:3, plot(ax, h + 0.5, T.([names{a} '_Qcoll_Wh']), 'Color', col{a}, 'LineWidth', 1.4); end
ylabel(ax, 'collector heat [Wh/h]'); xlim(ax, [0 24]); grid(ax, 'on'); shade(ax);
ax = nexttile(tl); hold(ax, 'on'); for a = 1:3, plot(ax, h + 0.5, cumsum(T.([names{a} '_Edel_Wh'])) / 1000, 'Color', col{a}, 'LineWidth', 1.4); end
ylabel(ax, 'delivered, cumulative [kWh]'); xlim(ax, [0 24]); grid(ax, 'on'); shade(ax);
ax = nexttile(tl); hold(ax, 'on'); for a = 1:3, stairs(ax, h, T.([names{a} '_action_exec']) + 0.06 * (a - 2), 'Color', col{a}, 'LineWidth', 1.3); end
yticks(ax, [0 1 2]); yticklabels(ax, {'CHARGE', 'IDLE', 'BYPASS'}); ylim(ax, [-0.3 2.4]); xlim(ax, [0 24]); xlabel(ax, 'hour of day (local)'); grid(ax, 'on'); shade(ax);
title(ax, 'executed action per arm; background = DQN arm (green CHARGE, yellow IDLE, red BYPASS)');
exportgraphics(fig, fullfile(outDir, 'one_day_cycle_2023.png'), 'Resolution', 110); close(fig);
fprintf('[one_day_cycle] day %d  delivered plain %.2f  B0 %.2f  DQN %.2f kWh  peak melt B0 %.2f DQN %.2f\n', day, sum(T.arm1_plain_B0_Edel_Wh) / 1000, ...
    sum(T.arm2_pcm_B0_Edel_Wh) / 1000, sum(T.arm3_pcm_DQN_Edel_Wh) / 1000, max(T.arm2_pcm_B0_f_melt), max(T.arm3_pcm_DQN_f_melt));
end
