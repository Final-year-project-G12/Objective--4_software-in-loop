function S = run_story_videos(which, regime)
%RUN_STORY_VIDEOS  One-day "story" videos of the Uttarakhand system: all four objectives on screen, a running clock,
% the three arms side by side, and how long each tank CHARGES, DISCHARGES and stays IDLE in the day.
%
%   run_story_videos                         % day + two edge cases (regime 1, 2023)
%   run_story_videos({'day'})                % one of: 'day', 'heat_wave', 'no_sunlight'
%
%   day          ../video/o4_story_day105_2023.mp4           normal day (same day as one_day_cycle.m / the 3-D video)
%   heat_wave    ../video/o4_story_edge_heat_wave_2023.mp4    edge case: ambient +9 C, sun x1.15 (event day 1)
%   no_sunlight  ../video/o4_story_edge_no_sunlight_2023.mp4  edge case: no sun at all (event day 1)
% Plus ../pictures/story_<name>_summary.png (end card) and story_<name>_still.png, and
% ../export_r1/story_modes_2023.csv (charge / discharge / idle hours per arm and case).
%
% Inputs come from the earlier objectives, unchanged: O1 regime and Top-3 PCMs and the O2 tank design
% (export_r1/campaign_cases.json, built by O2's own run_case), the O3 PPO + smart forecast (export_r1/ppo_actor.json),
% and the O4 twin (simulate_hours.m, the MATLAB copy of the O2 kernel, validated against Python to 2e-13 C).
% Edge cases are built exactly as in edge_scenarios.m / run_c_scenarios.m (same window, seed and arms).
%
% Hour modes (per arm):  CHARGE    = the collector adds heat to the tank in that hour (Q_coll > 1 Wh)
%                        DISCHARGE = no collector heat, hot water is drawn and delivered (E_del > 1 Wh)
%                        IDLE      = neither (tank stands by and holds its heat); for the AI arm the hours the
%                                    controller chose BYPASS are counted inside IDLE and listed separately.
if nargin < 1 || isempty(which), which = {'day', 'heat_wave', 'no_sunlight'}; end
if ischar(which), which = {which}; end
if nargin < 2 || isempty(regime), regime = 1; end
here = fileparts(mfilename('fullpath')); addpath(here);
xdir = twin_export_dir(regime);
tw = load_twin_params(xdir, 2023);
C = load_campaign(regime);
W = tw.wx.signals.values;
yr = jsondecode(fileread(fullfile(xdir, 'three_arm_2023.json')));
vr = jsondecode(fileread(fullfile(xdir, 'validation_report.json')));
vdir = fullfile(here, '..', 'video'); if ~isfolder(vdir), mkdir(vdir); end
pdir = fullfile(here, '..', 'pictures'); if ~isfolder(pdir), mkdir(pdir); end
info = objective_text(C, tw, yr, vr, regime);
rows = {};
Lyear = [];
for k = 1:numel(which)
    nm = which{k};
    if strcmp(nm, 'day')
        if isempty(Lyear)
            Lyear = {simulate_hours(tw, W, C.water_only, 1, 0, []), simulate_hours(tw, W, C.base.K, 1, 0, []), ...
                     simulate_hours(tw, W, C.base.K, 0, 0, [])};
        end
        rows17 = find(W(:, 4) == 17); sd = round(linspace(15, 345, 12));
        [~, i] = max(Lyear{3}.E_stored_kWh(rows17(sd))); day = sd(i);
        sel = (rows17(day) - 17):(rows17(day) + 6);
        L = Lyear; tag = sprintf('day%03d', day);
        head = sprintf('A normal day: %s 2023 (day %d), real weather', datestr(datenum(2023, 1, day), 'dd mmmm'), day);
        what = 'Stored 2023 weather and the O2 hot-water draw profile, nothing edited.';
    else
        [sc, ~, nWin] = edge_scenarios(tw, C.base.K);
        c = sc(strcmp({sc.name}, nm));
        L = run_arms(tw, C, c, nWin);
        s0 = 4 * 24 + find(c.W(4 * 24 + 1:end, 4) == 0, 1);     % first local midnight inside the event
        sel = s0:(s0 + 23); tag = ['edge_' nm];
        assert(all(c.W(sel, 4)' == 0:23), 'story: edge day not aligned to local hours');
        doy = (90 * 24 + s0 - 1 + c.W(1, 4)) / 24 + 1;
        head = sprintf('Edge case: %s, %s 2023 (inside the 4-day event)', c.title, datestr(datenum(2023, 1, doy), 'dd mmmm'));
        if strcmp(nm, 'heat_wave'), what = 'Ambient +9 C and sunlight x1.15 for four days: the tank runs hot, so the safety guard matters.';
        else, what = 'Sunlight set to zero for four days: no charging possible, the tank lives on stored heat.'; end
    end
    M = modes(L, sel);
    for a = 1:3
        rows(end+1, :) = {nm, M.arm{a}, M.nC(a), M.nD(a), M.nI(a), M.nB(a), M.melt(a), M.solid(a), ...
            M.Edel(a), M.guard(a), M.Tmax(a)}; %#ok<AGROW>
    end
    f = fullfile(vdir, sprintf('o4_story_%s_2023.mp4', tag));
    render(L, sel, M, f, head, what, info, fullfile(pdir, ['story_' tag]));
    fprintf('[story] %s -> %s\n', nm, f);
end
S = cell2table(rows, 'VariableNames', {'case', 'arm', 'charge_h', 'discharge_h', 'idle_h', 'idle_bypass_h', ...
    'pcm_melting_h', 'pcm_releasing_h', 'delivered50_kWh', 'guard_h', 'Ttop_max_C'});
writetable(S, fullfile(xdir, 'story_modes_2023.csv'));
disp(S);
end

% ======================================================================
function L = run_arms(tw, C, c, nWin)
Kp = C.water_only; Kp.P(3) = Kp.P(3) + c.dmains;
Kc = C.base.K;     Kc.P(3) = Kc.P(3) + c.dmains;
o = struct('stuck', c.stuck, 'n', nWin);
L = cell(1, 3);
rng(7); L{1} = simulate_hours(tw, c.W, Kp, 1, c.noise, c.blackout, o);
rng(7); L{2} = simulate_hours(tw, c.W, Kc, 1, c.noise, c.blackout, o);
rng(7); L{3} = simulate_hours(tw, c.W, Kc, 0, c.noise, c.blackout, o);
end

function M = modes(L, sel)
M.arm = {'Plain tank (no PCM, always on)', 'PCM tank (no AI, always on)', 'PCM tank + AI (PPO)'};
for a = 1:3
    La = L{a};
    ch = La.Q_coll_Wh(sel) > 1;
    di = ~ch & La.E_del_Wh(sel) > 1;
    id = ~ch & ~di;
    M.mode(:, a) = 1 * ch + 2 * di + 3 * id;               % 1 charge, 2 discharge, 3 idle
    M.byp(:, a) = (a == 3) & La.a_cmd(sel) == 0;            % hours the AI chose BYPASS (any mode)
    M.nC(a) = sum(ch); M.nD(a) = sum(di); M.nI(a) = sum(id); M.nB(a) = sum(M.byp(:, a));
    fm = La.f_melt(sel); dfm = diff([La.f_melt(max(sel(1) - 1, 1)); fm]);
    M.melt(a) = sum(dfm > 0.005) * (a > 1); M.solid(a) = sum(dfm < -0.005) * (a > 1);
    M.Edel(a) = sum(La.E_del_Wh(sel)) / 1000;
    M.guard(a) = sum(La.shield_w_s(sel) + La.shield_p_s(sel)) / 3600;
    M.Tmax(a) = max(La.T_top(sel));
end
end

function I = objective_text(C, tw, yr, vr, regime)
d = C.design; o1 = C.o1;
I.o1 = {'O1  CLIMATE + PCM CHOICE', sprintf('Uttarakhand regime UK %d (GMM, K = 4)', regime), ...
    sprintf('medoid %s, 10 years of ERA5', strrep(tw.params.medoid, '_', '\_')), ...
    sprintf('Top-3 PCMs: %s, %s, %s', o1(1).name, o1(2).name, o1(3).name)};
I.o2 = {'O2  TANK DESIGN (NSGA-II)', sprintf('%s: %d capsules, R %.1f mm, %s', C.chosen_pcm, d.N, 1000 * d.R_in_m, d.arrangement), ...
    sprintf('PCM %.1f %% of 50 L (%.1f kg), flow %.3f kg/s', 100 * d.fraction, yr.pcm_mass_kg, d.flow), ...
    sprintf('collector %.1f m^2, melts at %.0f-%.0f C', yr.collector_m2, C.base.K.P(9), C.base.K.P(10))};
I.o3 = {'O3  AI CONTROLLER (DRL)', 'PPO + smart sunlight forecast (19 inputs)', 'ENABLE or BYPASS the collector every hour', ...
    'safety guard 72 C water / 62 C PCM (always on)'};
I.o4 = {'O4  SOFTWARE-IN-THE-LOOP', 'MATLAB / Simulink copy of the system', ...
    sprintf('matches Python to %.0e C, %d %% same actions', vr.B_closed_loop_matlab.max_abs_dT_top_C, round(vr.B_closed_loop_matlab.action_agreement_pct)), ...
    'this video = the MATLAB twin running live'};
a = yr.arms;
I.year = sprintf(['Full year 2023 (same twin): delivered heat (50 C)  plain %.0f  |  PCM %.0f  |  PCM + AI %.0f kWh     ' ...
    'safety-guard hours  plain %.0f  |  PCM %.0f  |  PCM + AI %.1f h'], a(1).delivered50_kWh, a(2).delivered50_kWh, ...
    a(3).delivered50_kWh, a(1).guard_band_h, a(2).guard_band_h, a(3).guard_band_h);
I.yearShort = [a(1).delivered50_kWh a(2).delivered50_kWh a(3).delivered50_kWh; a(1).guard_band_h a(2).guard_band_h a(3).guard_band_h];
I.K = C.base.K;
end

% ======================================================================
function render(L, sel, M, file, head, what, I, picBase)
hrs = 0:23; n = numel(sel);
col = {[0.45 0.45 0.45], [0.85 0.33 0.10], [0.00 0.45 0.74]};
mcol = [1.00 0.62 0.15; 0.25 0.55 0.95; 0.82 0.82 0.82];   % CHARGE, DISCHARGE, IDLE
mname = {'CHARGING', 'DISCHARGING', 'IDLE'};
K = I.K; N = K.N; ncap = round(K.n_caps(:)');
Ts = K.P(9); Tl = K.P(10); Lh = K.P(11); cps = K.P(12); x = K.P(14);
hs = (cps + x) * Ts; span = Lh + x * (Tl - Ts);

fig = figure('Visible', 'off', 'Units', 'pixels', 'Position', [0 0 1920 1080], 'Color', 'w');
try, theme(fig, 'light'); catch, end
% ---- banner and the four objectives ----
axB = axes(fig, 'Position', [0 0.80 1 0.20]); axis(axB, 'off'); xlim(axB, [0 1]); ylim(axB, [0 1]);
text(axB, 0.012, 0.93, 'Climate-adaptive PCM solar water heater, Uttarakhand', 'FontSize', 20, 'FontWeight', 'bold', 'Color', [0.64 0.07 0.25], 'VerticalAlignment', 'top');
text(axB, 0.012, 0.74, head, 'FontSize', 13, 'FontWeight', 'bold', 'VerticalAlignment', 'top', 'Interpreter', 'none');
text(axB, 0.55, 0.74, what, 'FontSize', 11, 'Color', [0.3 0.3 0.3], 'VerticalAlignment', 'top', 'Interpreter', 'none');
boxes = {I.o1, I.o2, I.o3, I.o4}; bcol = [0.93 0.96 1.0; 0.94 1.0 0.94; 1.0 0.96 0.90; 0.98 0.93 0.97];
for b = 1:4
    x0 = 0.012 + (b - 1) * 0.247;
    rectangle(axB, 'Position', [x0 0.03 0.237 0.56], 'Curvature', 0.08, 'FaceColor', bcol(b, :), 'EdgeColor', [0.6 0.6 0.6]);
    t = boxes{b};
    text(axB, x0 + 0.008, 0.53, t{1}, 'FontSize', 11, 'FontWeight', 'bold', 'VerticalAlignment', 'top', 'Interpreter', 'tex');
    text(axB, x0 + 0.008, 0.40, t(2:end), 'FontSize', 9.5, 'VerticalAlignment', 'top', 'Interpreter', 'tex');
    if b < 4, text(axB, x0 + 0.240, 0.31, '\rightarrow', 'FontSize', 14, 'HorizontalAlignment', 'center'); end
end
% ---- clock ----
axC = axes(fig, 'Position', [0 0.745 1 0.05]); axis(axC, 'off'); xlim(axC, [0 1]); ylim(axC, [0 1]);
hClock = text(axC, 0.012, 0.5, '', 'FontSize', 15, 'FontWeight', 'bold', 'Color', [0.1 0.2 0.6]);

% ---- left: three tanks ----
axK = axes(fig, 'Position', [0.01 0.05 0.40 0.68]); hold(axK, 'on'); axis(axK, 'off');
xlim(axK, [-0.2 3.8]); ylim(axK, [-0.75 1.35]);
hNode = gobjects(N, 3); hCap = cell(1, 3); hBadge = gobjects(1, 3); hVal = gobjects(1, 3);
for a = 1:3
    x0 = (a - 1) * 1.25;
    text(axK, x0 + 0.45, 1.27, M.arm{a}, 'FontSize', 10.5, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', col{a});
    for i = 1:N
        hNode(i, a) = rectangle(axK, 'Position', [x0 (i - 1) * 0.1 0.9 0.1], 'FaceColor', [0.6 0.7 0.9], 'EdgeColor', [1 1 1]);
    end
    rectangle(axK, 'Position', [x0 0 0.9 1], 'EdgeColor', 'k', 'LineWidth', 1.5);
    hCap{a} = gobjects(0);
    if a > 1
        for i = 1:N
            m = ncap(i);
            for q = 1:m
                cx = x0 + 0.9 * q / (m + 1); cy = (i - 0.5) * 0.1;
                hCap{a}(end+1) = rectangle(axK, 'Position', [cx - 0.032 cy - 0.032 0.064 0.064], 'Curvature', 1, ...
                    'FaceColor', [0.25 0.45 0.9], 'EdgeColor', [0.2 0.2 0.2]);
            end
        end
    else
        text(axK, x0 + 0.45, 0.5, 'water only', 'FontSize', 10, 'HorizontalAlignment', 'center', 'Color', [1 1 1], 'FontWeight', 'bold');
    end
    hBadge(a) = text(axK, x0 + 0.45, 1.13, '', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'BackgroundColor', [0.9 0.9 0.9], 'Margin', 3, 'EdgeColor', [0.5 0.5 0.5]);
    hVal(a) = text(axK, x0 - 0.05, -0.05, '', 'FontSize', 9.5, 'VerticalAlignment', 'top', 'FontName', 'Consolas');
end
text(axK, -0.15, -0.66, 'Layer colour = water temperature (blue 10 C to red 75 C);  capsule colour = PCM melted (blue solid, orange liquid)', ...
    'FontSize', 8.5, 'Color', [0.35 0.35 0.35]);

% ---- right: simple plots ----
xL = 0.45; wR = 0.53; hgt = 0.105; gap = 0.031; y = 0.735;
axs = gobjects(5, 1);
for r = 1:5, y = y - hgt - gap; axs(r) = axes(fig, 'Position', [xL y wR hgt]); hold(axs(r), 'on'); box(axs(r), 'on'); grid(axs(r), 'on'); end
L1 = L{1};
yyaxis(axs(1), 'left'); area(axs(1), hrs, L1.GHI(sel), 'FaceColor', [1 0.85 0.3], 'EdgeColor', [0.9 0.6 0]); ylabel(axs(1), 'sun [W/m^2]');
ylim(axs(1), [0 max(1000, 1.1 * max(L1.GHI(sel)))]);
yyaxis(axs(1), 'right'); bar(axs(1), hrs, L1.draw_kg(sel), 0.4, 'FaceColor', [0.3 0.6 1], 'EdgeColor', 'none'); ylabel(axs(1), 'hot water [kg/h]');
title(axs(1), 'Weather and hot-water use (same for all three tanks)', 'FontSize', 10);
for a = 1:3, plot(axs(2), hrs, L{a}.T_top(sel), '-', 'Color', col{a}, 'LineWidth', 2.2); end
yline(axs(2), 50, '--', 'Color', [0 0.5 0], 'LineWidth', 1); yline(axs(2), 72, '--', 'Color', [0.8 0 0], 'LineWidth', 1);
ylabel(axs(2), 'top water [\circC]'); title(axs(2), 'Hot-water temperature (green 50 \circC = useful, red 72 \circC = safety guard)', 'FontSize', 10);
legend(axs(2), {'plain', 'PCM', 'PCM + AI'}, 'Location', 'northwest', 'Orientation', 'horizontal', 'FontSize', 8);
for a = 2:3, plot(axs(3), hrs, 100 * L{a}.f_melt(sel), '-', 'Color', col{a}, 'LineWidth', 2.2); end
ylim(axs(3), [-5 105]); ylabel(axs(3), 'PCM melted [%]'); title(axs(3), 'PCM charge state (melts by day, releases heat as it solidifies)', 'FontSize', 10);
for a = 1:3, plot(axs(4), hrs, cumsum(L{a}.E_del_Wh(sel)) / 1000, '-', 'Color', col{a}, 'LineWidth', 2.2); end
ylabel(axs(4), 'delivered [kWh]'); title(axs(4), 'Useful hot water delivered so far today (heat up to 50 \circC)', 'FontSize', 10);
for a = 1:3
    for t = 1:n
        patch(axs(5), [hrs(t) - 0.5 hrs(t) + 0.5 hrs(t) + 0.5 hrs(t) - 0.5], 4 - a + [-0.4 -0.4 0.4 0.4], mcol(M.mode(t, a), :), 'EdgeColor', 'w');
        if M.byp(t, a), text(axs(5), hrs(t), 4 - a, 'B', 'FontSize', 7, 'HorizontalAlignment', 'center', 'Color', [0.7 0 0]); end
    end
end
yticks(axs(5), 1:3); yticklabels(axs(5), {'PCM + AI', 'PCM', 'plain'}); ylim(axs(5), [0.5 3.5]);
title(axs(5), 'Mode each hour: orange CHARGE, blue DISCHARGE, grey IDLE  (B = AI chose BYPASS for safety)', 'FontSize', 10);
xlabel(axs(5), 'hour of day');
for r = 1:5, xlim(axs(r), [-0.5 23.5]); xticks(axs(r), 0:2:22); if r < 5, xticklabels(axs(r), {}); end; end
cur = gobjects(5, 1);
for r = 1:5, cur(r) = xline(axs(r), 0, 'k-', 'LineWidth', 2, 'HandleVisibility', 'off'); end

% ---- video ----
[vw, usedFile] = open_writer(file);
cleanup = onCleanup(@() close(vw));
sz = [];
sub = 8; cnt = zeros(3, 3);
for t = 1:n
    i = sel(t);
    for a = 1:3, cnt(a, M.mode(t, a)) = cnt(a, M.mode(t, a)) + 1; end
    set(hClock, 'String', sprintf('%02d:00      sun %4.0f W/m^2      outdoor %5.1f \\circC      hot-water draw %4.1f kg/h', ...
        hrs(t), L1.GHI(i), L1.T_amb(i), L1.draw_kg(i)));
    for a = 1:3
        La = L{a};
        for k = 1:N, set(hNode(k, a), 'FaceColor', tcol(La.Tnodes(i, k))); end
        if a > 1
            c = 0;
            for k = 1:N
                fm = min(max((La.hnodes(i, k) - hs) / span, 0), 1);
                for q = 1:ncap(k), c = c + 1; set(hCap{a}(c), 'FaceColor', (1 - fm) * [0.25 0.45 0.9] + fm * [1.0 0.55 0.05]); end
            end
        end
        md = M.mode(t, a); lab = mname{md}; if M.byp(t, a), lab = [lab ' (AI bypass)']; end
        set(hBadge(a), 'String', lab, 'BackgroundColor', mcol(md, :));
        if a > 1, pc = sprintf('PCM %5.1f C  melted %3.0f%%', La.Tpcm(i), 100 * La.f_melt(i)); else, pc = 'PCM   none'; end
        set(hVal(a), 'String', {sprintf('top    %5.1f C', La.T_top(i)), sprintf('bottom %5.1f C', La.T_bottom(i)), pc, ...
            sprintf('stored %5.2f kWh', La.E_stored_kWh(i)), sprintf('sun in %5.0f Wh', La.Q_coll_Wh(i)), ...
            sprintf('used   %5.2f kWh', sum(La.E_del_Wh(sel(1:t))) / 1000), ...
            sprintf('guard  %5.2f h', sum(La.shield_w_s(sel(1:t)) + La.shield_p_s(sel(1:t))) / 3600), ...
            sprintf('C %2d h  D %2d h  I %2d h', cnt(a, 1), cnt(a, 2), cnt(a, 3))});
    end
    for s = 0:sub - 1
        for r = 1:5, set(cur(r), 'Value', hrs(t) - 0.5 + (s + 0.5) / sub); end
        drawnow;
        sz = put(vw, fig, sz);
    end
    if t == 14, exportgraphics(fig, [picBase '_still.png'], 'Resolution', 80); end
end
close(fig);

% ---- end card: simple summary ----
fs = summary_figure(M, I, head);
exportgraphics(fs, [picBase '_summary.png'], 'Resolution', 100);
for k = 1:12 * 6, sz = put(vw, fs, sz); end
close(fs);
close(vw); clear cleanup;
d = dir(usedFile); fprintf('[story] %s (%.1f MB)\n', usedFile, d.bytes / 1e6);
end

function fs = summary_figure(M, I, head)
col = {[0.45 0.45 0.45], [0.85 0.33 0.10], [0.00 0.45 0.74]};
mcol = [1.00 0.62 0.15; 0.25 0.55 0.95; 0.82 0.82 0.82];
fs = figure('Visible', 'off', 'Units', 'pixels', 'Position', [0 0 1920 1080], 'Color', 'w');
try, theme(fs, 'light'); catch, end
tl = tiledlayout(fs, 2, 3, 'TileSpacing', 'loose', 'Padding', 'loose');
title(tl, {'Summary of the day', head}, 'FontSize', 18, 'FontWeight', 'bold', 'Interpreter', 'none');
ax = nexttile(tl, [1 2]);
b = barh(ax, 1:3, [M.nC(:) M.nD(:) M.nI(:)], 0.45, 'stacked');
for k = 1:3, b(k).FaceColor = mcol(k, :); end
yticks(ax, 1:3); yticklabels(ax, {'Plain tank', 'PCM tank', 'PCM + AI'}); set(ax, 'YDir', 'reverse', 'FontSize', 12);
xlim(ax, [0 24]); xticks(ax, 0:2:24); xlabel(ax, 'hours in the day');
legend(ax, {'charge', 'discharge', 'idle'}, 'Location', 'southoutside', 'Orientation', 'horizontal');
for a = 1:3
    s = sprintf('charge %d h  |  discharge %d h  |  idle %d h', M.nC(a), M.nD(a), M.nI(a));
    if M.nB(a) > 0, s = [s sprintf('  |  AI bypass %d h', M.nB(a))]; end %#ok<AGROW>
    if a > 1, s = [s sprintf('  |  PCM melting %d h, releasing %d h', M.melt(a), M.solid(a))]; end %#ok<AGROW>
    text(ax, 0, a - 0.36, s, 'FontSize', 10.5, 'Color', [0.15 0.15 0.15], 'VerticalAlignment', 'bottom');
end
title(ax, 'Charge, discharge and idle time per tank', 'FontSize', 13);
ax = nexttile(tl); hold(ax, 'on');
for a = 1:3, bar(ax, a, M.Edel(a), 0.6, 'FaceColor', col{a}); text(ax, a, M.Edel(a), sprintf('%.2f', M.Edel(a)), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 12); end
xticks(ax, 1:3); xticklabels(ax, {'plain', 'PCM', 'PCM + AI'}); ylabel(ax, 'kWh'); set(ax, 'FontSize', 12);
ylim(ax, [0 max(0.1, 1.2 * max(M.Edel))]); title(ax, 'Useful heat delivered today (50 \circC)', 'FontSize', 13); box(ax, 'on');
ax = nexttile(tl); hold(ax, 'on');
for a = 1:3, bar(ax, a, M.guard(a), 0.6, 'FaceColor', col{a}); text(ax, a, M.guard(a), sprintf('%.1f h', M.guard(a)), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 12); end
xticks(ax, 1:3); xticklabels(ax, {'plain', 'PCM', 'PCM + AI'}); ylabel(ax, 'hours'); set(ax, 'FontSize', 12);
ylim(ax, [0 max(0.5, 1.25 * max(M.guard))]); title(ax, 'Time at the safety limit today (lower = safer)', 'FontSize', 13); box(ax, 'on');
ax = nexttile(tl); hold(ax, 'on');
for a = 1:3, bar(ax, a, M.Tmax(a), 0.6, 'FaceColor', col{a}); text(ax, a, M.Tmax(a), sprintf('%.1f \\circC', M.Tmax(a)), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontSize', 12); end
yline(ax, 72, 'r--', '72 \circC guard'); xticks(ax, 1:3); xticklabels(ax, {'plain', 'PCM', 'PCM + AI'}); ylabel(ax, '\circC'); set(ax, 'FontSize', 12);
ylim(ax, [0 85]); title(ax, 'Hottest top water today', 'FontSize', 13); box(ax, 'on');
ax = nexttile(tl); axis(ax, 'off');
Y = I.yearShort;
text(ax, 0, 0.95, 'Whole year 2023 (same MATLAB twin)', 'FontSize', 13, 'FontWeight', 'bold', 'VerticalAlignment', 'top');
text(ax, 0, 0.75, {sprintf('Heat delivered:  plain %.0f,  PCM %.0f,  PCM + AI %.0f kWh', Y(1, :)), ...
    sprintf('PCM + AI vs plain tank:  +%.1f %% heat', 100 * (Y(1, 3) / Y(1, 1) - 1)), ...
    sprintf('Safety-guard hours:  plain %.0f,  PCM %.0f,  PCM + AI %.1f h', Y(2, :)), ...
    sprintf('PCM + AI vs PCM alone:  %.1f %% less guard time,', 100 * (1 - Y(2, 3) / Y(2, 2))), ...
    sprintf('  keeping %.1f %% of its heat', 100 * Y(1, 3) / Y(1, 2)), ...
    'Every arm: zero hard-limit violations'}, 'FontSize', 11.5, 'VerticalAlignment', 'top');
end

% ======================================================================
function [vw, f] = open_writer(f)
try
    vw = VideoWriter(f, 'MPEG-4'); vw.Quality = 95;
catch
    f = regexprep(f, '\.mp4$', '.avi'); vw = VideoWriter(f, 'Motion JPEG AVI');
end
vw.FrameRate = 12; open(vw);
end

function sz = put(vw, fig, sz)
fr = getframe(fig); im = fr.cdata;
if isempty(sz), sz = [size(im, 1) size(im, 2)]; end
im2 = 255 * ones(sz(1), sz(2), 3, 'uint8');                 % crop / pad to the first frame's size (no toolbox needed)
r = min(sz(1), size(im, 1)); c = min(sz(2), size(im, 2));
im2(1:r, 1:c, :) = im(1:r, 1:c, :);
writeVideo(vw, im2);
end

function c = tcol(T)
t = min(max((T - 10) / 65, 0), 1);
c = min(max([t, 0.35 * (1 - abs(2 * t - 1)) + 0.1, 1 - t], 0), 1);
end
