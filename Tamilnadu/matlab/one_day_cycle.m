function dayInfo = one_day_cycle(exportDir, year, dayOfYear)
%ONE_DAY_CYCLE  Objective 4 plan item B: one charge/idle/bypass cycle, one
% day, 1-hour resolution, all three arms (plain B0 / PCM B0 / PCM SAC) on
% shared axes. Re-runs the full year (fast in plain MATLAB) so each arm
% starts the day from its OWN correct state, then slices one day for the
% figure. If dayOfYear is omitted, picks the sunniest day on which arm 3
% visits all three actions (CHARGE, IDLE, BYPASS) -- i.e. a genuine cycle,
% not just an always-on or always-off day.
%
%   d = one_day_cycle('../export', 2021)
here = fileparts(mfilename('fullpath')); addpath(here);
if nargin < 1 || isempty(exportDir), exportDir = fullfile(here, '..', 'export'); end
if nargin < 2, year = 2021; end
tw = load_twin_params(exportDir, year);
W = tw.wx.signals.values; n = size(W, 1);

g10 = jsondecode(fileread(fullfile(here, '..', '..', '..', 'objective2_design_optimization', 'results', 'g10_selection_r0.json')));
fraction = g10.chosen.fraction;
P_pcm = tw.P;
P_plain = tw.P; P_plain(1) = tw.P(1) / (1 - fraction); P_plain(23) = 0;

fprintf('[one_day] running full-year arms (2021) to get correct per-day state...\n');
L1 = simulate_hours(tw, W, P_plain, 1, 0, []);   % arm 1: plain, B0
L2 = simulate_hours(tw, W, P_pcm,   1, 0, []);   % arm 2: PCM, B0
L3 = simulate_hours(tw, W, P_pcm,   0, 0, []);   % arm 3: PCM, SAC

if nargin < 3 || isempty(dayOfYear)
    nDays = floor(n / 24);
    score = -ones(nDays, 1);
    for d = 1:nDays
        idx = (d-1)*24 + (1:24);
        acts = unique(L3.a_exec(idx));
        if numel(acts) >= 3 && sum(L3.n_sw(idx) + L3.n_sp(idx)) > 0
            score(d) = max(L3.GHI(idx));   % prefer the sunniest qualifying day
        end
    end
    [~, dayOfYear] = max(score);
    if score(dayOfYear) < 0
        [~, dayOfYear] = max(arrayfun(@(d) max(L3.GHI((d-1)*24+(1:24))), 1:nDays));
    end
end
idx = (dayOfYear-1)*24 + (1:24);
fprintf('[one_day] day of year = %d\n', dayOfYear);

% reconstruct collector gain for the figure (Hottel-Whillier, same formula
% pcm_plant_hour.m uses; visualisation only -- NOT re-exported as a state):
%   Q_use = A_coll*(fr_ta*I - fr_ul*(T_w - T_amb)) when circulating, else 0
A_coll = tw.params.A_coll_m2; fr_ta = tw.params.fr_tau_alpha; fr_ul = tw.params.fr_ul_W_m2K; Icut = tw.params.I_cutoff_Wm2;
collgain = @(L) max(0, (L.GHI(idx) > Icut) .* (L.a_exec(idx) == 0) .* ...
    (A_coll * (fr_ta * L.GHI(idx) - fr_ul * (L.Tw(idx) - L.T_amb(idx)))));
Q1 = collgain(L1); Q2 = collgain(L2); Q3 = collgain(L3);

dayInfo.day = dayOfYear;
dayInfo.L1 = slice(L1, idx); dayInfo.L2 = slice(L2, idx); dayInfo.L3 = slice(L3, idx);
dayInfo.Q1_W = Q1; dayInfo.Q2_W = Q2; dayInfo.Q3_W = Q3;
plot_day(L1, L2, L3, Q1, Q2, Q3, idx, dayOfYear, fullfile(exportDir, sprintf('one_day_cycle_%d.png', year)));

T = table((1:24)', L1.GHI(idx), L1.Tw(idx), L2.Tw(idx), L3.Tw(idx), L1.Tpcm(idx), L2.Tpcm(idx), L3.Tpcm(idx), ...
    L1.f_melt(idx), L2.f_melt(idx), L3.f_melt(idx), Q1, Q2, Q3, L1.E_del_Wh(idx), L2.E_del_Wh(idx), L3.E_del_Wh(idx), ...
    L1.a_exec(idx), L2.a_exec(idx), L3.a_exec(idx), L1.n_sw(idx)+L1.n_sp(idx), L2.n_sw(idx)+L2.n_sp(idx), L3.n_sw(idx)+L3.n_sp(idx), ...
    'VariableNames', {'hod','GHI','Tw1','Tw2','Tw3','Tpcm1','Tpcm2','Tpcm3','f1','f2','f3','Qc1_W','Qc2_W','Qc3_W', ...
    'Edel1_Wh','Edel2_Wh','Edel3_Wh','act1','act2','act3','shield1','shield2','shield3'});
writetable(T, fullfile(exportDir, sprintf('one_day_cycle_%d.csv', year)));
fprintf('[one_day] written -> one_day_cycle_%d.{png,csv}\n', year);
disp(T);
end

function s = slice(L, idx)
f = fieldnames(L);
for i = 1:numel(f), s.(f{i}) = L.(f{i})(idx); end
end

function plot_day(L1, L2, L3, Q1, Q2, Q3, idx, dayOfYear, file)
h = 1:24;
fig = figure('Visible', 'off', 'Position', [50 50 1200 1300], 'Color', 'w');
tl = tiledlayout(fig, 6, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('One-day cycle, day %d of year -- arm 1 plain/B0, arm 2 PCM/B0, arm 3 PCM/SAC', dayOfYear), 'FontWeight', 'bold');

col = {[0.5 0.5 0.5], [0.1 0.3 0.8], [0.85 0.2 0.1]};
nm  = {'arm1 plain B0', 'arm2 PCM B0', 'arm3 PCM SAC'};

shadeActions = @(ax, a) shade_phases(ax, h, a);

ax = nexttile(tl); hold(ax, 'on');
pl1 = plot(ax, h, L1.Tw(idx), 'Color', col{1}, 'LineWidth', 1.3);
pl2 = plot(ax, h, L2.Tw(idx), 'Color', col{2}, 'LineWidth', 1.3);
pl3 = plot(ax, h, L3.Tw(idx), 'Color', col{3}, 'LineWidth', 1.6);
yline(ax, 45, 'g--'); yline(ax, 72, 'r--'); ylabel(ax, 'T_w [\circC]'); grid(ax, 'on'); xlim(ax, [1 24]);
shadeActions(ax, L3.a_exec(idx));
% legend: lines = the three arms; coloured backgrounds = arm 3's executed action
phC = patch(ax, NaN, NaN, [0.85 0.95 0.80], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
phI = patch(ax, NaN, NaN, [0.93 0.93 0.93], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
phB = patch(ax, NaN, NaN, [0.97 0.85 0.80], 'EdgeColor', 'none', 'FaceAlpha', 0.5);
lg = legend(ax, [pl1 pl2 pl3 phC phI phB], [nm, {'CHARGE (arm 3)', 'IDLE (arm 3)', 'BYPASS (arm 3)'}], ...
    'NumColumns', 6, 'Location', 'northoutside');
title(ax, 'Water temperature (background colour = arm 3''s executed action)');

ax = nexttile(tl); hold(ax, 'on');
plot(ax, h, L2.Tpcm(idx), 'Color', col{2}, 'LineWidth', 1.3);
plot(ax, h, L3.Tpcm(idx), 'Color', col{3}, 'LineWidth', 1.6);
yline(ax, 62, 'r--'); ylabel(ax, 'T_{PCM} [\circC]'); grid(ax, 'on'); xlim(ax, [1 24]);
shadeActions(ax, L3.a_exec(idx));
title(ax, 'PCM temperature (arm 1 is a plain tank with no PCM -- not plotted)');

ax = nexttile(tl); hold(ax, 'on');
plot(ax, h, L2.f_melt(idx), 'Color', col{2}, 'LineWidth', 1.3);
plot(ax, h, L3.f_melt(idx), 'Color', col{3}, 'LineWidth', 1.6);
ylabel(ax, 'melt fraction'); ylim(ax, [0 1.05]); grid(ax, 'on'); xlim(ax, [1 24]);
shadeActions(ax, L3.a_exec(idx));
title(ax, 'PCM melt fraction (arm 1 omitted -- no PCM)');

ax = nexttile(tl); hold(ax, 'on');
plot(ax, h, Q1/1000, 'Color', col{1}, 'LineWidth', 1.3);
plot(ax, h, Q2/1000, 'Color', col{2}, 'LineWidth', 1.3);
plot(ax, h, Q3/1000, 'Color', col{3}, 'LineWidth', 1.6);
ylabel(ax, 'collector gain [kW]'); grid(ax, 'on'); xlim(ax, [1 24]);
shadeActions(ax, L3.a_exec(idx));
title(ax, 'Collector useful heat gain (0 when IDLE/BYPASS or shield-blocked)');

ax = nexttile(tl); hold(ax, 'on');
bar(ax, h - 0.25, L1.E_del_Wh(idx)/1000, 0.25, 'FaceColor', col{1});
bar(ax, h, L2.E_del_Wh(idx)/1000, 0.25, 'FaceColor', col{2});
bar(ax, h + 0.25, L3.E_del_Wh(idx)/1000, 0.25, 'FaceColor', col{3});
ylabel(ax, 'delivered [kWh]'); grid(ax, 'on'); xlim(ax, [0.5 24.5]);
shadeActions(ax, L3.a_exec(idx));
title(ax, 'Hourly delivered energy');

ax = nexttile(tl); hold(ax, 'on');
stem(ax, h - 0.2, L1.n_sw(idx) + L1.n_sp(idx), 'Color', col{1}, 'LineWidth', 1.3, 'Marker', 'o');
stem(ax, h,       L2.n_sw(idx) + L2.n_sp(idx), 'Color', col{2}, 'LineWidth', 1.3, 'Marker', 's');
stem(ax, h + 0.2, L3.n_sw(idx) + L3.n_sp(idx), 'Color', col{3}, 'LineWidth', 1.6, 'Marker', '^');
ylabel(ax, 'shield trips / h'); xlabel(ax, 'hour of day'); grid(ax, 'on'); xlim(ax, [1 24]);
shadeActions(ax, L3.a_exec(idx));
title(ax, 'Safety-shield activations that hour (sub-step count)');

exportgraphics(fig, file, 'Resolution', 120); close(fig);
end

function shade_phases(ax, h, a_exec)
% Call AFTER the data is plotted and axes are auto-scaled: uses the
% current ylim, then sends the shading behind the data lines.
cols = containers.Map({0, 1, 2}, {[0.85 0.95 0.80], [0.93 0.93 0.93], [0.97 0.85 0.80]});
yl = ylim(ax);
run_start = 1;
patches = gobjects(0);
for k = 2:numel(h)+1
    if k > numel(h) || a_exec(k) ~= a_exec(run_start)
        p = patch(ax, [h(run_start)-0.5 h(min(k-1,numel(h)))+0.5 h(min(k-1,numel(h)))+0.5 h(run_start)-0.5], ...
            [yl(1) yl(1) yl(2) yl(2)], cols(a_exec(run_start)), 'EdgeColor', 'none', 'FaceAlpha', 0.5);
        patches(end+1) = p; %#ok<AGROW>
        run_start = k;
    end
end
ylim(ax, yl);
for p = patches, uistack(p, 'bottom'); end
end
