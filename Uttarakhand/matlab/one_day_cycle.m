function T = one_day_cycle(day, regime)
%ONE_DAY_CYCLE  One full charge / bypass cycle for the three arms (joint plan deliverable 3).
%
%   T = one_day_cycle;          % the hold-test start day with the most stored energy in the PPO arm
%   T = one_day_cycle(165);     % any day of 2023
%   writes ../export_r1/one_day_cycle_2023.csv and .png
%
% Hours 00:00-23:00 local of the chosen day, three arms on the same weather, each from its own full-year state.
% Panels: sun, ambient, draw; top-layer water temperature of each arm with PCM temperature (dotted), 50 / 72 C lines;
% melt fraction; collector heat; cumulative delivered energy (50 C); commanded action and the fraction of each hour the
% loop actually ran (after cut-off and shield), with the PPO arm's ENABLE / BYPASS as background colour.
if nargin < 2 || isempty(regime), regime = 1; end
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = twin_export_dir(regime);
tw = load_twin_params(outDir, 2023);
C = load_campaign(regime);
W = tw.wx.signals.values;
L = {simulate_hours(tw, W, C.water_only, 1, 0, []), simulate_hours(tw, W, C.base.K, 1, 0, []), simulate_hours(tw, W, C.base.K, 0, 0, [])};
rows17 = find(W(:, 4) == 17);
if nargin < 1 || isempty(day)
    sd = round(linspace(15, 345, 12));
    [~, k] = max(L{3}.E_stored_kWh(rows17(sd)));
    day = sd(k);
end
r0 = rows17(day) - 17; r = r0:r0 + 23;
assert(W(r0, 4) == 0, 'one_day_cycle: day %d does not start at local hour 0', day);
names = {'arm1_plain_B0', 'arm2_pcm_B0', 'arm3_pcm_PPO'};
T = table((0:23)', L{1}.GHI(r), L{1}.T_amb(r), L{1}.draw_kg(r), 'VariableNames', {'hour', 'GHI_Wm2', 'T_amb_C', 'draw_kg'});
for a = 1:3
    n = names{a}; La = L{a};
    T.([n '_Ttop_C']) = La.T_top(r); T.([n '_Tbottom_C']) = La.T_bottom(r); T.([n '_Tpcm_C']) = La.Tpcm(r);
    T.([n '_f_melt']) = La.f_melt(r); T.([n '_Qcoll_Wh']) = La.Q_coll_Wh(r); T.([n '_Edel50_Wh']) = La.E_del_Wh(r);
    T.([n '_shield_s']) = La.shield_w_s(r) + La.shield_p_s(r); T.([n '_action_cmd']) = La.a_cmd(r);
    T.([n '_pump_frac']) = La.pump_frac(r); T.([n '_E_stored_kWh']) = La.E_stored_kWh(r);
end
writetable(T, fullfile(outDir, 'one_day_cycle_2023.csv'));

col = {[0.4 0.4 0.4], [0.85 0.33 0.1], [0 0.45 0.74]};
bg = [0.95 0.75 0.75; 0.75 0.92 0.75];          % BYPASS, ENABLE
fig = figure('Visible', 'off', 'Position', [50 50 1150 1000], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 6, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('One-day cycle, Uttarakhand regime %d, day %d of 2023: plain tank, PCM + B0, PCM + PPO', regime, day), 'FontWeight', 'bold');
h = 0:23; act = L{3}.a_cmd(r);
shade = @(ax) arrayfun(@(i) patch(ax, [h(i) h(i)+1 h(i)+1 h(i)], [ax.YLim(1) ax.YLim(1) ax.YLim(2) ax.YLim(2)], bg(act(i) + 1, :), ...
    'EdgeColor', 'none', 'FaceAlpha', 0.35, 'HandleVisibility', 'off'), 1:24);
ax = nexttile(tl); yyaxis(ax, 'left'); bar(ax, h + 0.5, T.draw_kg, 1, 'FaceColor', [0.7 0.85 1], 'EdgeColor', 'none'); ylabel(ax, 'draw [kg/h]');
yyaxis(ax, 'right'); hold(ax, 'on'); plot(ax, h + 0.5, T.GHI_Wm2, 'Color', [0.9 0.7 0], 'LineWidth', 1.4); plot(ax, h + 0.5, 10 * T.T_amb_C, 'k-');
ylabel(ax, 'GHI [W/m^2]; ambient x10 [\circC]'); xlim(ax, [0 24]); grid(ax, 'on'); title(ax, 'Sun, ambient (x10) and hot-water draw');
ax = nexttile(tl); hold(ax, 'on');
for a = 1:3, plot(ax, h + 0.5, T.([names{a} '_Ttop_C']), 'Color', col{a}, 'LineWidth', 1.5); end
plot(ax, h + 0.5, T.arm2_pcm_B0_Tpcm_C, ':', 'Color', col{2}, 'LineWidth', 1.3); plot(ax, h + 0.5, T.arm3_pcm_PPO_Tpcm_C, ':', 'Color', col{3}, 'LineWidth', 1.3);
yline(ax, 50, 'g--', '50 \circC', 'LabelHorizontalAlignment', 'left'); yline(ax, 72, 'r--', '72 \circC shield');
ylabel(ax, 'T [\circC]'); xlim(ax, [0 24]); grid(ax, 'on'); shade(ax);
legend(ax, {'plain top', 'PCM + B0 top', 'PCM + PPO top', 'PCM T (B0)', 'PCM T (PPO)'}, 'Orientation', 'horizontal', 'Location', 'northoutside');
ax = nexttile(tl); hold(ax, 'on'); plot(ax, h + 0.5, T.arm2_pcm_B0_f_melt, 'Color', col{2}, 'LineWidth', 1.5); plot(ax, h + 0.5, T.arm3_pcm_PPO_f_melt, 'Color', col{3}, 'LineWidth', 1.5);
ylabel(ax, 'PCM melt fraction'); ylim(ax, [0 1.05]); xlim(ax, [0 24]); grid(ax, 'on'); shade(ax); title(ax, 'Plain tank has no PCM');
ax = nexttile(tl); hold(ax, 'on'); for a = 1:3, plot(ax, h + 0.5, T.([names{a} '_Qcoll_Wh']), 'Color', col{a}, 'LineWidth', 1.4); end
ylabel(ax, 'collector heat [Wh/h]'); xlim(ax, [0 24]); grid(ax, 'on'); shade(ax);
ax = nexttile(tl); hold(ax, 'on'); for a = 1:3, plot(ax, h + 0.5, cumsum(T.([names{a} '_Edel50_Wh'])) / 1000, 'Color', col{a}, 'LineWidth', 1.4); end
ylabel(ax, 'delivered (50 \circC), cum. [kWh]'); xlim(ax, [0 24]); grid(ax, 'on'); shade(ax);
ax = nexttile(tl); hold(ax, 'on');
for a = 1:3, stairs(ax, h, T.([names{a} '_action_cmd']) + 0.04 * (a - 2), 'Color', col{a}, 'LineWidth', 1.3); end
for a = 1:3, stairs(ax, h, T.([names{a} '_pump_frac']) * 0.8 + 0.1, ':', 'Color', col{a}, 'LineWidth', 1.1); end
yticks(ax, [0 1]); yticklabels(ax, {'BYPASS', 'ENABLE'}); ylim(ax, [-0.2 1.25]); xlim(ax, [0 24]); xlabel(ax, 'hour of day (local)'); grid(ax, 'on'); shade(ax);
title(ax, 'commanded action (solid) and fraction of the hour the loop ran (dotted); background = PPO arm (green ENABLE, red BYPASS)');
exportgraphics(fig, fullfile(outDir, 'one_day_cycle_2023.png'), 'Resolution', 110); close(fig);
fprintf('[one_day_cycle] day %d  delivered(50 C) plain %.2f  B0 %.2f  PPO %.2f kWh  peak melt B0 %.2f PPO %.2f  PPO bypass hours %d\n', day, ...
    sum(T.arm1_plain_B0_Edel50_Wh) / 1000, sum(T.arm2_pcm_B0_Edel50_Wh) / 1000, sum(T.arm3_pcm_PPO_Edel50_Wh) / 1000, ...
    max(T.arm2_pcm_B0_f_melt), max(T.arm3_pcm_PPO_f_melt), sum(T.arm3_pcm_PPO_action_cmd == 0));
end
