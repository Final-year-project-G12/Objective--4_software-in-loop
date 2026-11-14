%RUN_SCENARIOS  Objective 4 software-in-the-loop study for Rajasthan (no hardware needed).
%
% 1. VALIDATION: the closed loop (sensors -> observation -> DQN -> interlock -> plant)
%    is replayed on the first two weeks of 2023 and compared with the Python RL
%    environment's own trajectory.
% 2. EDGE CASES on a real April 2023 weather window (4 days spin-up, 4 days of the edge
%    case, 2 days recovery): clear, no sunlight, rain/cloud, cold, heat wave, sensor
%    fault. Each is run with the trained DQN controller and with the always-charge
%    baseline B0.
% 3. Plots, a summary table and animated schematics.
%
% Set the regime before calling (default 1, the regime of Objective 3's locked test):
%     regime = 1; doAnim = false; run_scenarios
% Outputs go to ../export_r<regime>/scenarios.
here = fileparts(mfilename('fullpath')); addpath(here);
if ~exist('regime', 'var'), regime = 1; end          % 0, 1 or 2
if ~exist('doAnim', 'var'), doAnim = true; end
% deadPyr = true adds a SEVENTH scenario (pyranometer stuck at 0 W/m2, see below) and writes everything to
% ../results_campaign/edge_cases_with_dead_pyranometer/ so the original export_r<k>/scenarios files stay untouched.
if ~exist('deadPyr', 'var'), deadPyr = false; end
YEAR = 2023;
expDir = fullfile(here, '..', sprintf('export_r%d', regime));
outDir = fullfile(expDir, 'scenarios');
sumName = 'scenario_summary.csv';
if deadPyr
    outDir = fullfile(here, '..', 'results_campaign', 'edge_cases_with_dead_pyranometer');
    sumName = 'scenario_summary_with_dead_pyranometer.csv';
end
if ~isfolder(outDir), mkdir(outDir); end
tw = load_twin_params(expDir, YEAR);
Wall = tw.wx.signals.values(:, 1:4);            % [idx GHI Tamb hod]

% ---------------- 1. validation against Python ----------------
try
    nv = 24 * 14; ref = tw.ref(1:nv, :);
    Lv = simulate_hours(tw, Wall, tw.P, 0, 0, [], nv);
    v.regime = regime;
    v.hours = nv;
    v.action_agreement_pct = 100 * mean(Lv.a_policy == ref.action);
    v.max_abs_dTw_C = max(abs(Lv.Tw - ref.T_w_C));
    v.max_abs_dTpcm_C = max(abs(Lv.Tpcm - ref.T_pcm_C));
    v.delivered_kWh_matlab = sum(Lv.E_del_Wh) / 1000;
    v.delivered_kWh_python = sum(ref.E_del_Wh) / 1000;
    v.shields_matlab = sum(Lv.n_sw + Lv.n_sp);
    v.shields_python = sum(ref.n_shield_w + ref.n_shield_p);
    v.pass = v.action_agreement_pct == 100 && v.max_abs_dTw_C < 1e-6 && v.shields_matlab == v.shields_python;
    fprintf('[VALIDATE closed loop, %d h] action agreement %.3f %%  max|dTw| %.2e  max|dTpcm| %.2e  shields %d vs %d  -> %s\n', ...
        nv, v.action_agreement_pct, v.max_abs_dTw_C, v.max_abs_dTpcm_C, v.shields_matlab, v.shields_python, tf(v.pass));
    fid = fopen(fullfile(outDir, 'validation_closed_loop.json'), 'w'); fwrite(fid, jsonencode(v, 'PrettyPrint', true)); fclose(fid);
catch err
    fprintf('[VALIDATE] FAILED: %s\n', err.message);
end

% ---------------- 2. edge-case scenarios ----------------
k0 = 90 * 24;                                    % 1 April, 00:00 of the record
nWin = 10 * 24;
base = Wall(k0 + (1:nWin + 3), :);               % + 3 real hours: forecast at the window end
iS = 4*24 + 1; iE = 8*24;                         % edge-case days 5-8
inEv = false(nWin, 1); inEv(iS:iE) = true;
ev = [inEv; false(3, 1)];                         % same mask on the padded window

sc = struct('name', {}, 'title', {}, 'W', {}, 'P', {}, 'noise', {}, 'blackout', {}, 'stuck', {});
add = @(nm, ti, W, P, nz, bo) struct('name', nm, 'title', ti, 'W', W, 'P', P, 'noise', nz, 'blackout', bo, 'stuck', NaN);
nb = false(nWin, 1);

sc(end+1) = add('clear', 'Clear sunny days (reference)', base, tw.P, 0, nb);

W = base; W(ev, 2) = 0;
sc(end+1) = add('no_sunlight', 'No sunlight for 4 days', W, tw.P, 0, nb);

W = base; W(ev, 2) = min(0.12 * base(ev, 2), 120); W(ev, 3) = base(ev, 3) - 5;
sc(end+1) = add('rain_cloud', 'Rain / heavy cloud (GHI x0.12, ambient -5 C)', W, tw.P, 0, nb);

W = base; W(ev, 3) = base(ev, 3) - 12; W(ev, 2) = 0.9 * base(ev, 2);
P = tw.P; P(3) = P(3) - 8;                        % colder mains water for the whole run
sc(end+1) = add('low_temperature', 'Low temperature (ambient -12 C, mains -8 C)', W, P, 0, nb);

W = base; W(ev, 3) = base(ev, 3) + 9; W(ev, 2) = 1.15 * base(ev, 2);
sc(end+1) = add('heat_wave', 'Heat wave (ambient +9 C, GHI x1.15)', W, tw.P, 0, nb);

bo = nb; bo(iS:iS + 11) = true;
sc(end+1) = add('sensor_fault', 'Noisy sensors + 12 h sensor blackout', base, tw.P, 1, bo);

if deadPyr
    % 7. Dead pyranometer: the controller's irradiance reading is stuck at 0 W/m2 for the whole 10-day run; the real irradiance
    %    (clear April weather, as scenario 1) still drives the plant. Forecast fields of the observation are unaffected.
    c7 = add('dead_pyranometer', 'Dead pyranometer (reads 0 W/m^2, real sun unchanged)', base, tw.P, 0, nb);
    c7.stuck = 0;
    sc(end+1) = c7;
end
rows = {}; res = struct();
for s = 1:numel(sc)
    c = sc(s);
    try
        rng(7); Ls = simulate_hours(tw, c.W, c.P, 0, c.noise, c.blackout, nWin, c.stuck);
        rng(7); Lb = simulate_hours(tw, c.W, c.P, 1, c.noise, c.blackout, nWin, c.stuck);
        res.(c.name).DQN = Ls; res.(c.name).B0 = Lb;
        for pol = {'DQN', 'B0'}
            L = res.(c.name).(pol{1});
            m = metrics(L, inEv);
            rows(end+1, :) = {c.name, pol{1}, m.deliv_event, m.unmet_event, m.shield_event, m.shield_h_event, m.viol_all, ...
                m.Tw_min_event, m.Tw_max_all, m.Tpcm_max_all, m.fmelt_end_event, m.hours_ge45_event, m.not_charge_h, m.failsafe_h}; %#ok<AGROW>
        end
        plot_scenario(c, Ls, Lb, inEv, fullfile(outDir, [c.name '.png']), regime);
        fprintf('[scenario] %-16s done  DQN delivered(event)=%.2f kWh  B0=%.2f kWh  DQN viol=%d\n', c.name, ...
            sum(Ls.E_del_Wh(inEv)) / 1000, sum(Lb.E_del_Wh(inEv)) / 1000, sum(Ls.n_viol));
    catch err
        fprintf('[scenario] %s FAILED: %s (line %d)\n', c.name, err.message, err.stack(1).line);
    end
end

Tsum = cell2table(rows, 'VariableNames', {'scenario', 'policy', 'delivered_kWh_event', 'unmet_kWh_event', 'shield_trips_event', ...
    'shield_hours_event', 'hard_violations_all', 'Tw_min_event_C', 'Tw_max_C', 'Tpcm_max_C', 'pcm_melt_end_event', ...
    'hours_water_ge45_event', 'idle_or_bypass_hours_event', 'failsafe_hours'});
writetable(Tsum, fullfile(outDir, sumName));
disp(Tsum);

% ---------------- 3. animations ----------------
if doAnim
    for nm = {'no_sunlight', 'rain_cloud', 'low_temperature', 'clear'}
        try
            c = sc(strcmp({sc.name}, nm{1}));
            tic; animate_system(res.(nm{1}).DQN, fullfile(outDir, [nm{1} '_animation.mp4']), ...
                sprintf('Rajasthan regime %d: %s', regime, c.title), 4, tw.P(39));
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
m.unmet_event = sum(L.E_unmet_Wh(inEv)) / 1000;
m.shield_event = sum(L.n_sw(inEv) + L.n_sp(inEv));
m.shield_h_event = sum(L.shield_s(inEv)) / 3600;
m.viol_all = sum(L.n_viol);
m.Tw_min_event = min(L.Tw(inEv));
m.Tw_max_all = max(L.Tw_max);
m.Tpcm_max_all = max(L.Tpcm_max);
idx = find(inEv, 1, 'last'); m.fmelt_end_event = L.f_melt(idx);
m.hours_ge45_event = sum(L.Tw(inEv) >= 45);
m.not_charge_h = sum(L.a_policy(inEv) ~= 0);
m.failsafe_h = sum(L.interlock >= 2);
end

function plot_scenario(c, Ls, Lb, inEv, file, regime)
n = numel(Ls.Tw); d = (1:n)' / 24;
fig = figure('Visible', 'off', 'Position', [50 50 1150 900], 'Color', 'w');
try, theme(fig, 'light'); catch, end      % R2025a+ follows the desktop theme; force light for reports
tl = tiledlayout(fig, 5, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Objective 4 software-in-the-loop, Rajasthan regime %d: %s', regime, c.title), 'FontWeight', 'bold');
shade = @(ax) patch(ax, [find(inEv, 1) find(inEv, 1, 'last') find(inEv, 1, 'last') find(inEv, 1)] / 24, ...
    [ax.YLim(1) ax.YLim(1) ax.YLim(2) ax.YLim(2)], [0.6 0.6 0.6], 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'HandleVisibility', 'off');

ax = nexttile(tl); hold(ax, 'on'); plot(ax, d, Ls.GHI, 'Color', [0.9 0.7 0]); ylabel(ax, 'GHI [W/m^2]');
yyaxis(ax, 'right'); plot(ax, d, Ls.T_amb, 'k-'); ylabel(ax, 'T_{amb} [\circC]'); xlim(ax, [0 n/24]); grid(ax, 'on');
yyaxis(ax, 'left'); shade(ax); title(ax, 'Weather input (grey band = edge-case period)');

ax = nexttile(tl); hold(ax, 'on');
plot(ax, d, Ls.Tw, 'b-', 'LineWidth', 1.3); plot(ax, d, Lb.Tw, 'b:', 'LineWidth', 1);
plot(ax, d, Ls.Tbot, '-', 'Color', [0.3 0.65 0.9], 'LineWidth', 0.9);
plot(ax, d, Ls.Tpcm, 'Color', [0.9 0.4 0], 'LineWidth', 1.3); plot(ax, d, Lb.Tpcm, ':', 'Color', [0.9 0.4 0], 'LineWidth', 1);
yline(ax, 45, 'g--', '45 \circC delivery'); yline(ax, 72, 'r--', '72 \circC shield'); yline(ax, 75, 'r-', '75 \circC limit');
ylabel(ax, 'T [\circC]'); xlim(ax, [0 n/24]); grid(ax, 'on'); shade(ax);
legend(ax, {'T_{top} DQN', 'T_{top} B0', 'T_{bottom} DQN', 'T_{PCM} DQN', 'T_{PCM} B0'}, 'Orientation', 'horizontal', 'Location', 'northoutside');

ax = nexttile(tl); hold(ax, 'on'); plot(ax, d, Ls.f_melt, 'Color', [0.9 0.4 0], 'LineWidth', 1.5); plot(ax, d, Lb.f_melt, ':', 'Color', [0.9 0.4 0]);
ylabel(ax, 'PCM melt fraction'); ylim(ax, [0 1.05]); xlim(ax, [0 n/24]); grid(ax, 'on'); shade(ax);

ax = nexttile(tl); hold(ax, 'on'); stairs(ax, d, Ls.a_cmd, 'b-'); stairs(ax, d, Ls.a_exec + 0.08, 'r:');
yticks(ax, [0 1 2]); yticklabels(ax, {'CHARGE', 'IDLE', 'BYPASS'}); ylim(ax, [-0.3 2.4]); xlim(ax, [0 n/24]); grid(ax, 'on'); shade(ax);
legend(ax, {'commanded (after interlock)', 'executed (after plant shield)'}, 'Orientation', 'horizontal', 'Location', 'northoutside');

ax = nexttile(tl); hold(ax, 'on');
plot(ax, d, cumsum(Ls.E_del_Wh) / 1000, 'b-', 'LineWidth', 1.3); plot(ax, d, cumsum(Lb.E_del_Wh) / 1000, 'b:');
plot(ax, d, cumsum(Ls.E_unmet_Wh) / 1000, 'm-', 'LineWidth', 1.3);
ylabel(ax, 'cumulative kWh'); xlabel(ax, 'day'); xlim(ax, [0 n/24]); grid(ax, 'on'); shade(ax);
legend(ax, {'delivered DQN', 'delivered B0', 'unmet DQN'}, 'Orientation', 'horizontal', 'Location', 'northoutside');
exportgraphics(fig, file, 'Resolution', 110); close(fig);
end

function s = tf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end
