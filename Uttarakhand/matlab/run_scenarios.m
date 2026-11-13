%RUN_SCENARIOS  Objective 4 software-in-the-loop study, Uttarakhand (no hardware needed).
%
% 1. VALIDATION: the closed loop (sensors -> observation -> PPO -> interlock
%    -> O2 multinode plant) is replayed on the first two weeks of the export
%    year and compared with the Python RL environment's own trajectory.
% 2. EDGE CASES on a real April weather window (4 days spin-up, 4 days of the
%    edge case, 2 days recovery): clear, no sunlight, rain/cloud, cold, heat
%    wave, sensor fault. Each is run with the frozen PPO controller and with
%    the always-enable baseline B0 (O2's design as released).
% 3. Plots, a summary table and animated schematics.
%
% Set `regime` (0, 1 or 2; default 1 = O3's primary regime) and `doAnim`
% before calling. Outputs go to <export>/scenarios.
here = fileparts(mfilename('fullpath')); addpath(here);
if ~exist('regime', 'var'), regime = 1; end
if ~exist('doAnim', 'var'), doAnim = true; end
expDir = twin_export_dir(regime);
outDir = fullfile(expDir, 'scenarios'); if ~isfolder(outDir), mkdir(outDir); end
tw = load_twin_params(expDir);
Wall = tw.wx.signals.values;                    % [idx GHI Tamb hod]
fprintf('Uttarakhand regime %d (%s), year %d (%s)\n', regime, tw.params.medoid, tw.year, tw.params.label);

% ---------------- 1. validation against Python ----------------
try
    nv = 24 * 14; ref = tw.ref(1:nv, :);
    Lv = simulate_hours(tw, Wall(1:nv, :), tw.K, 0, 0, []);
    v.regime = regime; v.year = tw.year; v.hours = nv;
    v.action_agreement_pct = 100 * mean(Lv.a_policy == ref.action);
    v.max_abs_dTtop_C = max(abs(Lv.T_top - ref.T_top_C));
    v.max_abs_dTpcm_C = max(abs(Lv.Tpcm - ref.T_pcm_C));
    v.max_abs_df_melt = max(abs(Lv.f_melt - ref.f_melt));
    v.delivered50_kWh_matlab = sum(Lv.E_del_Wh) / 1000;
    v.delivered50_kWh_python = sum(ref.E_del50_Wh) / 1000;
    v.shield_s_matlab = sum(Lv.shield_w_s + Lv.shield_p_s);
    v.shield_s_python = sum(ref.shield_water_s + ref.shield_pcm_s);
    v.pass = v.action_agreement_pct == 100 && v.max_abs_dTtop_C < 1e-6 && v.shield_s_matlab == v.shield_s_python;
    fprintf('[VALIDATE closed loop, %d h] action agreement %.3f %%  max|dTtop| %.2e  max|dTpcm| %.2e  shield %g s vs %g s  -> %s\n', ...
        nv, v.action_agreement_pct, v.max_abs_dTtop_C, v.max_abs_dTpcm_C, v.shield_s_matlab, v.shield_s_python, tf(v.pass));
    fid = fopen(fullfile(outDir, 'validation_closed_loop.json'), 'w'); fwrite(fid, jsonencode(v, 'PrettyPrint', true)); fclose(fid);
catch err
    fprintf('[VALIDATE] FAILED: %s\n', err.message);
end

% ---------------- 2. edge-case scenarios ----------------
k0 = 90 * 24;                                    % 1 April, 00:00 (row index of the export year)
nWin = 10 * 24;
base = Wall(k0 + (1:nWin), :);
iS = 4*24 + 1; iE = 8*24;                         % edge-case days 5-8
inEv = false(nWin, 1); inEv(iS:iE) = true;

sc = struct('name', {}, 'title', {}, 'W', {}, 'K', {}, 'noise', {}, 'blackout', {});
add = @(nm, ti, W, K, nz, bo) struct('name', nm, 'title', ti, 'W', W, 'K', K, 'noise', nz, 'blackout', bo);
nb = false(nWin, 1);

sc(end+1) = add('clear', 'Clear days (reference)', base, tw.K, 0, nb);

W = base; W(inEv, 2) = 0;
sc(end+1) = add('no_sunlight', 'No sunlight for 4 days', W, tw.K, 0, nb);

W = base; W(inEv, 2) = min(0.12 * base(inEv, 2), 120); W(inEv, 3) = base(inEv, 3) - 5;
sc(end+1) = add('rain_cloud', 'Rain / heavy cloud (GHI x0.12, ambient -5 C)', W, tw.K, 0, nb);

W = base; W(inEv, 3) = base(inEv, 3) - 12; W(inEv, 2) = 0.9 * base(inEv, 2);
K = tw.K; K.P(3) = K.P(3) - 8;                    % colder mains water for the whole run
sc(end+1) = add('low_temperature', 'Low temperature (ambient -12 C, mains -8 C)', W, K, 0, nb);

W = base; W(inEv, 3) = base(inEv, 3) + 9; W(inEv, 2) = 1.15 * base(inEv, 2);
sc(end+1) = add('heat_wave', 'Heat wave (ambient +9 C, GHI x1.15)', W, tw.K, 0, nb);

bo = nb; bo(iS:iS + 11) = true;
sc(end+1) = add('sensor_fault', 'Noisy sensors + 12 h sensor blackout', base, tw.K, 1, bo);

% Uttarakhand-only diagnostic: same physics as low_temperature, but the policy is
% fed the TRAINING mains temperature (std(T_mains) in the frozen normalisation is
% ~0.001 C, so the real -8 C is thousands of std out of distribution).
W = sc(strcmp({sc.name}, 'low_temperature')).W;
K = tw.K; K.P(3) = K.P(3) - 8; K.obs_mains = tw.K.P(3);
sc(end+1) = add('low_temp_mains_masked', 'Low temperature, policy sees training mains (diagnostic)', W, K, 0, nb);

rng(7);
rows = {}; res = struct();
for s = 1:numel(sc)
    c = sc(s);
    try
        Lp = simulate_hours(tw, c.W, c.K, 0, c.noise, c.blackout);
        Lb = simulate_hours(tw, c.W, c.K, 1, c.noise, c.blackout);
        res.(c.name).PPO = Lp; res.(c.name).B0 = Lb;
        for pol = {'PPO', 'B0'}
            L = res.(c.name).(pol{1});
            m = metrics(L, inEv);
            rows(end+1, :) = {c.name, pol{1}, m.deliv_event, m.deliv_window_event, m.load_event, m.unmet_event, ...
                m.shield_h_event, m.shield_trips_event, m.over_limit_h_all, m.Ttop_min_event, m.Ttop_max_all, ...
                m.Tpcm_max_all, m.fmelt_end_event, m.hours_top_ge50_event, m.bypass_h_event, m.failsafe_h}; %#ok<AGROW>
        end
        plot_scenario(c, Lp, Lb, inEv, fullfile(outDir, [c.name '.png']));
        fprintf('[scenario] %-16s done  PPO E_del50(event)=%.2f kWh  B0=%.2f kWh  PPO shield %.2f h  over-limit %.2f h\n', c.name, ...
            sum(Lp.E_del_Wh(inEv)) / 1000, sum(Lb.E_del_Wh(inEv)) / 1000, sum(Lp.shield_w_s(inEv) + Lp.shield_p_s(inEv)) / 3600, ...
            sum(Lp.over_limit_s) / 3600);
    catch err
        fprintf('[scenario] %s FAILED: %s (line %d)\n', c.name, err.message, err.stack(1).line);
    end
end

T = cell2table(rows, 'VariableNames', {'scenario', 'policy', 'delivered50_kWh_event', 'window_delivered50_kWh_event', ...
    'load_above_mains_kWh_event', 'unmet_kWh_event', 'shield_hours_event', 'shield_substeps_event', 'hours_over_limit_all', ...
    'Ttop_min_event_C', 'Ttop_max_C', 'Tpcm_max_C', 'pcm_melt_end_event', 'hours_top_ge50_event', 'bypass_hours_event', ...
    'failsafe_hours'});
writetable(T, fullfile(outDir, 'scenario_summary.csv'));
disp(T);

% ---------------- 3. animations ----------------
if doAnim
    for nm = {'no_sunlight', 'rain_cloud', 'low_temperature', 'clear'}
        try
            c = sc(strcmp({sc.name}, nm{1}));
            tic; animate_system(res.(nm{1}).PPO, fullfile(outDir, [nm{1} '_animation.mp4']), ...
                sprintf('Uttarakhand r%d - %s - PPO', regime, c.title), 4);
            fprintf('[animation] %s written (%.0f s)\n', nm{1}, toc);
        catch err
            fprintf('[animation] %s FAILED: %s (line %d)\n', nm{1}, err.message, err.stack(1).line);
        end
    end
end
disp('ALL_DONE_MARKER');

% ======================================================================
function m = metrics(L, inEv)
m.deliv_event = sum(L.E_del_Wh(inEv)) / 1000;
m.deliv_window_event = sum(L.E_del_Wh(inEv & L.in_window > 0.5)) / 1000;
m.load_event = sum(L.Q_load_Wh(inEv)) / 1000;
m.unmet_event = sum(L.E_unmet_Wh(inEv)) / 1000;
m.shield_h_event = sum(L.shield_w_s(inEv) + L.shield_p_s(inEv)) / 3600;
m.shield_trips_event = sum(L.n_sw(inEv) + L.n_sp(inEv));
m.over_limit_h_all = sum(L.over_limit_s) / 3600;
m.Ttop_min_event = min(L.T_top(inEv));
m.Ttop_max_all = max(L.T_top_max);
m.Tpcm_max_all = max(L.T_pcm_max);
idx = find(inEv, 1, 'last'); m.fmelt_end_event = L.f_melt(idx);
m.hours_top_ge50_event = sum(L.T_top(inEv) >= 50);
m.bypass_h_event = sum(L.a_cmd(inEv) == 0);
m.failsafe_h = sum(L.interlock >= 2);
end

function plot_scenario(c, Lp, Lb, inEv, file)
n = numel(Lp.T_top); d = (1:n)' / 24;
fig = figure('Visible', 'off', 'Position', [50 50 1150 1050], 'Color', 'w');
try, fig.Theme = 'light'; catch, end   % R2025a+ default dark theme
tl = tiledlayout(fig, 6, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, ['Objective 4 software-in-the-loop (Uttarakhand): ' c.title], 'FontWeight', 'bold');
shade = @(ax) patch(ax, [find(inEv, 1) find(inEv, 1, 'last') find(inEv, 1, 'last') find(inEv, 1)] / 24, ...
    [ax.YLim(1) ax.YLim(1) ax.YLim(2) ax.YLim(2)], [0.9 0.9 0.9], 'FaceAlpha', 0.5, 'EdgeColor', 'none');

ax = nexttile(tl); hold(ax, 'on'); plot(ax, d, Lp.GHI, 'Color', [0.9 0.7 0]); ylabel(ax, 'GHI [W/m^2]');
yyaxis(ax, 'right'); plot(ax, d, Lp.T_amb, 'k-'); ylabel(ax, 'T_{amb} [\circC]'); xlim(ax, [0 n/24]); grid(ax, 'on');
yyaxis(ax, 'left'); shade(ax); title(ax, 'Weather input (grey band = edge-case period)');

ax = nexttile(tl); hold(ax, 'on');
plot(ax, d, Lp.T_top, 'b-', 'LineWidth', 1.3); plot(ax, d, Lb.T_top, 'b:', 'LineWidth', 1);
plot(ax, d, Lp.T_bottom, 'Color', [0.3 0.7 0.9], 'LineWidth', 1);
plot(ax, d, Lp.Tpcm, 'Color', [0.9 0.4 0], 'LineWidth', 1.3); plot(ax, d, Lb.Tpcm, ':', 'Color', [0.9 0.4 0], 'LineWidth', 1);
yline(ax, 50, 'g--', '50 \circC delivery', 'LabelHorizontalAlignment', 'left'); yline(ax, 72, 'r--', '72 \circC shield', 'LabelVerticalAlignment', 'bottom'); yline(ax, 75, 'r-', '75 \circC limit');
ylabel(ax, 'T [\circC]'); xlim(ax, [0 n/24]); grid(ax, 'on'); shade(ax);
legend(ax, {'T_{top} PPO', 'T_{top} B0', 'T_{bottom} PPO', 'T_{PCM} PPO', 'T_{PCM} B0'}, 'Orientation', 'horizontal', 'Location', 'northoutside');

ax = nexttile(tl);
imagesc(ax, d, 1:size(Lp.Tnodes, 2), Lp.Tnodes'); set(ax, 'YDir', 'normal'); colormap(ax, turbo); cb = colorbar(ax);
cb.Label.String = '\circC'; ylabel(ax, 'node (1 = bottom)'); xlim(ax, [0 n/24]); title(ax, 'Tank stratification, PPO (10 nodes)');

ax = nexttile(tl); hold(ax, 'on'); plot(ax, d, Lp.f_melt, 'Color', [0.9 0.4 0], 'LineWidth', 1.5); plot(ax, d, Lb.f_melt, ':', 'Color', [0.9 0.4 0]);
ylabel(ax, 'PCM melt fraction'); ylim(ax, [0 1.05]); xlim(ax, [0 n/24]); grid(ax, 'on'); shade(ax);
legend(ax, {'PPO', 'B0'}, 'Orientation', 'horizontal', 'Location', 'northoutside');

ax = nexttile(tl); hold(ax, 'on'); stairs(ax, d, Lp.a_cmd, 'b-'); stairs(ax, d, Lp.pump_frac, 'r:');
yticks(ax, [0 1]); yticklabels(ax, {'BYPASS', 'ENABLE'}); ylim(ax, [-0.2 1.3]); xlim(ax, [0 n/24]); grid(ax, 'on'); shade(ax);
legend(ax, {'commanded (after interlock)', 'fraction of hour the loop ran (after plant shield)'}, 'Orientation', 'horizontal', 'Location', 'northoutside');

ax = nexttile(tl); hold(ax, 'on');
plot(ax, d, cumsum(Lp.E_del_Wh) / 1000, 'b-', 'LineWidth', 1.3); plot(ax, d, cumsum(Lb.E_del_Wh) / 1000, 'b:');
plot(ax, d, cumsum(Lp.E_unmet_Wh) / 1000, 'm-', 'LineWidth', 1.3);
ylabel(ax, 'cumulative kWh'); xlabel(ax, 'day'); xlim(ax, [0 n/24]); grid(ax, 'on'); shade(ax);
legend(ax, {'delivered to 50 \circC, PPO', 'delivered, B0', 'unmet, PPO'}, 'Orientation', 'horizontal', 'Location', 'northoutside');
exportgraphics(fig, file, 'Resolution', 110); close(fig);
end

function s = tf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end
