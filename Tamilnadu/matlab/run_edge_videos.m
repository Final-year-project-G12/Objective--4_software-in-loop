function run_edge_videos(only, quick)
%RUN_EDGE_VIDEOS  Slow single-cycle videos of the edge cases (one video per
% scenario) with every key parameter, a running clock, and where the data
% comes from printed on screen.
%
% The scenarios are built EXACTLY as in run_c_scenarios.m (same 10-day
% window of 2011 weather starting at hour 2160, same event days 5-8, same
% random seed and call order), so the videos show the same simulations as
% export/scenarios_3arm/scenario_summary_3arm.csv. Each video shows day 5 of
% the window (the first event day; the 12 h sensor blackout falls on it).
%
%   run_edge_videos             % all 7 videos
%   run_edge_videos('clear')    % one scenario by name (or a cell array of names)
%
% Output: export/scenarios_3arm/video/edge_<scenario>.mp4  (12 fps, 5 frames per
% simulated hour -> about 9.6 s per day, 1920x1080).
if nargin < 2, quick = false; end
here = fileparts(mfilename('fullpath')); addpath(here);
exportDir = fullfile(here, '..', 'export');
year = 2011;
outDir = fullfile(exportDir, 'scenarios_3arm', 'video'); if ~isfolder(outDir), mkdir(outDir); end
tw = load_twin_params(exportDir, year);
Wall = tw.wx.signals.values;

g10 = jsondecode(fileread(fullfile(here, '..', '..', '..', 'objective2_design_optimization', 'results', 'g10_selection_r0.json')));
fraction = g10.chosen.fraction;

% ---- scenario definitions: identical to run_c_scenarios.m ----------------
k0 = 90 * 24; nWin = 10 * 24;
base = Wall(k0 + (1:nWin), :);
iS = 4*24 + 1; iE = 8*24;
inEv = false(nWin, 1); inEv(iS:iE) = true;
nb = false(nWin, 1);
sc = struct('name', {}, 'title', {}, 'what', {}, 'W', {}, 'P', {}, 'noise', {}, 'blackout', {}, 'gf', {});
add = @(nm, ti, wh, W, P, nz, bo, gf) struct('name', nm, 'title', ti, 'what', wh, 'W', W, 'P', P, 'noise', nz, 'blackout', bo, 'gf', gf);
sc(end+1) = add('clear', 'Clear sunny days (reference)', 'No change to the stored 2011 weather.', base, tw.P, 0, nb, '');
W = base; W(inEv, 2) = 0;
sc(end+1) = add('no_sunlight', 'No sunlight for 4 days', 'GHI set to 0 on window days 5-8.', W, tw.P, 0, nb, '');
W = base; W(inEv, 2) = min(0.12 * base(inEv, 2), 120); W(inEv, 3) = base(inEv, 3) - 5;
sc(end+1) = add('rain_cloud', 'Rain / heavy cloud', 'GHI x0.12 (capped at 120 W/m2) and ambient -5 C on window days 5-8.', W, tw.P, 0, nb, '');
W = base; W(inEv, 3) = base(inEv, 3) - 12; W(inEv, 2) = 0.9 * base(inEv, 2);
P = tw.P; P(8) = P(8) - 8;
sc(end+1) = add('low_temperature', 'Low temperature', 'Ambient -12 C, GHI x0.9, mains water -8 C on window days 5-8.', W, P, 0, nb, '');
W = base; W(inEv, 3) = base(inEv, 3) + 9; W(inEv, 2) = 1.15 * base(inEv, 2);
sc(end+1) = add('heat_wave', 'Heat wave', 'Ambient +9 C and GHI x1.15 on window days 5-8.', W, tw.P, 0, nb, '');
bo = nb; bo(iS:iS + 11) = true;
sc(end+1) = add('sensor_fault', 'Noisy sensors + 12 h blackout', 'Sensor noise and 1% dropout; sensor frame stale for the first 12 h of window day 5.', base, tw.P, 1, bo, '');
sc(end+1) = add('ghi_dropout', 'Dead pyranometer', 'Observed GHI forced to 0 for the whole window (true weather still drives the plant).', base, tw.P, 0, nb, 'dropout');
sc(end+1) = add('ghi_stuck', 'Stuck pyranometer', 'Observed GHI frozen at its first (00:00) reading, which is 0.', base, tw.P, 0, nb, 'stuck');

% ---- simulate in the same order as run_c_scenarios.m -----------------------
rng(7);
res = struct();
for s = 1:numel(sc)
    c = sc(s);
    P_plain = c.P; P_plain(1) = c.P(1) / (1 - fraction); P_plain(23) = 0;
    isFault = ismember(c.name, {'ghi_dropout', 'ghi_stuck'});
    res.(c.name).arm3 = simulate_hours(tw, c.W, c.P, 0, c.noise, c.blackout, c.gf);
    if ~isFault
        res.(c.name).arm1 = simulate_hours(tw, c.W, P_plain, 1, c.noise, c.blackout);
        res.(c.name).arm2 = simulate_hours(tw, c.W, c.P,     1, c.noise, c.blackout);
    else
        res.(c.name).arm3_nofault = simulate_hours(tw, c.W, c.P, 0, c.noise, c.blackout, '');
    end
    fprintf('[edge_videos] simulated %s\n', c.name);
end

% ---- render ----------------------------------------------------------------
if nargin < 1 || isempty(only)
    names = {'clear','no_sunlight','rain_cloud','low_temperature','heat_wave','sensor_fault','pyranometer_faults'};
else
    names = cellstr(only);
end
sel = 4*24 + (1:24);                       % window day 5
gIdx = k0 + sel;                           % global hour index into weather_2011.csv
doy = floor((gIdx(1) - 1) / 24) + 1;       % day of year of that day
for i = 1:numel(names)
    nm = names{i};
    if strcmp(nm, 'pyranometer_faults')
        Ls = {res.ghi_dropout.arm3_nofault, res.ghi_dropout.arm3, res.ghi_stuck.arm3};
        titles = {'Arm 3 SAC: healthy pyranometer', 'Arm 3 SAC: DEAD pyranometer (obs GHI = 0)', 'Arm 3 SAC: STUCK pyranometer (frozen at 00:00 = 0)'};
        hasPcm = [true true true];
        head = 'Dead / stuck pyranometer, arm 3 (SAC) vs healthy';
        what = 'Only the controller''s observed GHI is corrupted; the true weather, the plant and the safety shield are untouched. A sensor frozen at the 00:00 reading (0 W/m2) behaves like a dead one.';
    else
        k = find(strcmp({sc.name}, nm), 1);
        c = sc(k);
        r = res.(nm);
        Ls = {r.arm1, r.arm2, r.arm3};
        titles = {'Arm 1: plain tank (B0, no PCM)', 'Arm 2: PCM tank (B0, no AI)', 'Arm 3: PCM tank (SAC)'};
        hasPcm = [false true true];
        head = c.title; what = c.what;
    end
    outFile = fullfile(outDir, ['edge_' nm '.mp4']); if quick, outFile = fullfile(outDir, ['quick_' nm '.mp4']); end
    info = struct('head', head, 'what', what, 'doy', doy, 'gIdx', gIdx, 'year', year, 'design', {design_line(tw.params, tw.P(1)/(1-fraction))}, 'quick', quick);
    render_cycle(Ls, sel, titles, hasPcm, outFile, info);
end
fprintf('EDGE_VIDEOS_DONE\n');
end

% ========================================================================
function render_cycle(Ls, sel, titles, hasPcm, outFile, info)
hours = 0:23;
actColors = [1.0 0.95 0.55; 0.85 0.85 0.85; 1.0 0.70 0.70];  % CHARGE, IDLE, BYPASS
actNames  = {'CHARGE','IDLE','BYPASS'};
fig = figure('Visible','off','Units','pixels','Position',[0 0 1920 1080],'Color','w');
tl = tiledlayout(fig, 6, 3, 'TileSpacing','compact', 'Padding','compact'); tl.OuterPosition = [0 0 1 0.76];

% ---- info strip (rows 1-2) ----
axI = axes(fig, 'Position', [0.005 0.77 0.99 0.23]); axis(axI, 'off'); xlim(axI,[0 1]); ylim(axI,[0 1]);
text(axI, 0.0, 0.97, sprintf('Edge case: %s', info.head), 'FontSize', 15, 'FontWeight', 'bold', 'Interpreter', 'none', 'VerticalAlignment', 'top');
text(axI, 0.0, 0.86, ['What changed: ' info.what], 'FontSize', 10, 'Interpreter', 'none', 'VerticalAlignment', 'top');
text(axI, 0.0, 0.76, {sprintf('Data: export/weather_%d.csv, weather hours %d-%d (day %d of %d), edited as above', info.year, info.gIdx(1), info.gIdx(end), info.doy, info.year), ...
    'Plant: export/plant_params.json | controller: export/sac_actor_r0.json (r0 smartfc, V3 observation) | simulated hourly by matlab/simulate_hours.m, 150 s sub-steps'}, ...
    'FontSize', 9, 'Color', [0.25 0.25 0.25], 'Interpreter', 'none', 'VerticalAlignment', 'top');
text(axI, 0.0, 0.60, info.design, 'FontSize', 9, 'Color', [0.15 0.35 0.15], 'Interpreter', 'none', 'VerticalAlignment', 'top');
hClock = text(axI, 0.0, 0.43, '', 'FontSize', 13, 'FontWeight', 'bold', 'Color', [0.1 0.2 0.6], 'Interpreter', 'none', 'VerticalAlignment', 'top');
hArm = gobjects(3,1);
for a = 1:3
    hArm(a) = text(axI, 0.0, 0.30 - (a-1)*0.115, '', 'FontSize', 10, 'FontName', 'Consolas', 'Interpreter', 'none', 'VerticalAlignment', 'top');
end

axT = gobjects(1,3); axF = gobjects(1,3); axS = gobjects(1,3); axG = gobjects(1,3); axP = gobjects(1,3);
cursors = gobjects(5,3);
for a = 1:3
    L = Ls{a};
    Tw = L.Tw(sel); Tp = L.Tpcm(sel); fm = 100*L.f_melt(sel);
    gain = L.Q_coll_Wh(sel); pumpOn = double(gain > 0); act = L.a_exec(sel);
    ghi = L.GHI(sel); tam = L.T_amb(sel);

    axT(a) = nexttile(tl, a, [2 1]); hold(axT(a),'on'); box(axT(a),'on');
    if hasPcm(a), Tall = [Tw;Tp]; else, Tall = Tw; end
    shade_actions(axT(a), hours, act, actColors, [min(Tall)-2, max(Tall)+4]);
    hW = plot(axT(a), hours, Tw, 'b-', 'LineWidth', 2, 'Marker','.', 'MarkerSize', 10);
    if hasPcm(a)
        hP = plot(axT(a), hours, Tp, '-', 'Color', [0.9 0.4 0], 'LineWidth', 2, 'Marker','.', 'MarkerSize', 10);
    end
    ylabel(axT(a), 'T [\circC]'); title(axT(a), titles{a}, 'FontSize', 11, 'FontWeight','bold'); xlim(axT(a), [0 23]);
    if a == 2 && hasPcm(a), legend(axT(a), [hW hP], {'T_{water}','T_{PCM}'}, 'Location','southoutside','Orientation','horizontal'); end
    label_actions(axT(a), hours, act, actNames, max(Tall)+2.5);

    axF(a) = nexttile(tl, 6 + a); hold(axF(a),'on'); box(axF(a),'on');
    shade_actions(axF(a), hours, act, actColors, [-5 105]);
    if hasPcm(a), plot(axF(a), hours, fm, 'm-', 'LineWidth', 2, 'Marker','.', 'MarkerSize', 10);
    else, text(axF(a), 11.5, 50, 'no PCM', 'HorizontalAlignment','center', 'FontSize', 12, 'Color', [0.4 0.4 0.4]); end
    ylabel(axF(a), 'melt %'); ylim(axF(a), [-5 105]); xlim(axF(a), [0 23]);

    axS(a) = nexttile(tl, 9 + a); hold(axS(a),'on'); box(axS(a),'on');
    yyaxis(axS(a), 'left'); area(axS(a), hours, ghi, 'FaceColor', [1 0.85 0.3], 'EdgeColor', [0.9 0.6 0]); ylabel(axS(a), 'sun GHI [W/m^2]');
    ylim(axS(a), [0 max(1000, max(ghi)*1.1)]);
    yyaxis(axS(a), 'right'); plot(axS(a), hours, tam, 'k-', 'LineWidth', 1.5); ylabel(axS(a), 'T_{amb} [\circC]');
    xlim(axS(a), [0 23]);

    axG(a) = nexttile(tl, 12 + a); hold(axG(a),'on'); box(axG(a),'on');
    gmax = max(max(gain), 1);
    shade_actions(axG(a), hours, act, actColors, [-0.05*gmax, 1.15*gmax]);
    bar(axG(a), hours, gain, 'FaceColor', [0.95 0.6 0.1], 'EdgeColor','none');
    ylabel(axG(a), 'Q_{coll} [Wh]'); xlim(axG(a), [0 23]); ylim(axG(a), [-0.05*gmax, 1.15*gmax]);

    axP(a) = nexttile(tl, 15 + a); hold(axP(a),'on'); box(axP(a),'on');
    shade_actions(axP(a), hours, act, actColors, [-0.3 1.3]);
    stairs(axP(a), hours, pumpOn, 'g-', 'LineWidth', 2.5);
    ylim(axP(a), [-0.3 1.3]); yticks(axP(a), [0 1]); yticklabels(axP(a), {'OFF','ON'});
    ylabel(axP(a), 'pump'); xlabel(axP(a), 'hour of day'); xlim(axP(a), [0 23]);

    axs = [axT(a) axF(a) axS(a) axG(a) axP(a)];
    for r = 1:5
        cursors(r,a) = xline(axs(r), hours(1), 'k-', 'LineWidth', 2, 'HandleVisibility', 'off');
    end
end

try
    vw = VideoWriter(outFile, 'MPEG-4'); vw.FrameRate = 12; vw.Quality = 95; open(vw); usedFile = outFile;
catch
    usedFile = regexprep(outFile, '\.mp4$', '.avi');
    vw = VideoWriter(usedFile, 'Motion JPEG AVI'); vw.FrameRate = 12; open(vw);
end
cleanupObj = onCleanup(@() close(vw));
subFrames = 5; if info.quick, subFrames = 1; end; nFrames = 0;
for t = 1:23
    for s = 0:subFrames-1
        xc = hours(t) + s/subFrames;
        for a = 1:3
            for r = 1:5, set(cursors(r,a), 'Value', xc); end
        end
        i = sel(t);
        L1 = Ls{1};
        set(hClock, 'String', sprintf('TIME  day %d of %d, %02d:%02d   |   sun %.0f W/m2   ambient %.1f C   hot-water draw %.1f kg/h', ...
            info.doy, info.year, hours(t), round(60*s/subFrames), L1.GHI(i), L1.T_amb(i), L1.draw_kg(i)));
        for a = 1:3
            L = Ls{a};
            if hasPcm(a)
                pcmTxt = sprintf('T_pcm %5.1f C  melt %3.0f%%', L.Tpcm(i), 100*L.f_melt(i));
            else
                pcmTxt = 'T_pcm  --      melt  -- ';
            end
            set(hArm(a), 'String', sprintf('Arm %d  T_water %5.1f C  %s  Q_coll %5.0f Wh  action %-6s  pump %-3s  delivered %4.0f Wh  shield trips %d', ...
                a, L.Tw(i), pcmTxt, L.Q_coll_Wh(i), actNames{L.a_exec(i)+1}, ternary(L.Q_coll_Wh(i) > 0, 'ON', 'OFF'), L.E_del_Wh(i), L.n_sw(i)+L.n_sp(i)));
        end
        drawnow;
        fr = getframe(fig);
        if size(fr.cdata,1) ~= 1080 || size(fr.cdata,2) ~= 1920, fr.cdata = imresize(fr.cdata, [1080 1920]); end
        writeVideo(vw, fr.cdata); nFrames = nFrames + 1;
    end
end
close(vw); clear cleanupObj; close(fig);
d = dir(usedFile);
fprintf('[edge_videos] %s  (%.2f MB, %d frames = %.1f s)\n', usedFile, d.bytes/1e6, nFrames, nFrames/12);
end

function shade_actions(ax, hours, act, colors, ylims)
h = hours(2)-hours(1); start = 1;
for k = 2:numel(act)+1
    if k > numel(act) || act(k) ~= act(start)
        x0 = hours(start) - h/2; x1 = hours(min(k,numel(act))) - h/2;
        if k > numel(act), x1 = hours(end) + h/2; end
        patch(ax, [x0 x1 x1 x0], [ylims(1) ylims(1) ylims(2) ylims(2)], colors(act(start)+1, :), 'EdgeColor', 'none', 'FaceAlpha', 0.6);
        start = k;
    end
end
ylim(ax, ylims);
end

function label_actions(ax, hours, act, names, yPos)
h = hours(2)-hours(1); start = 1;
for k = 2:numel(act)+1
    if k > numel(act) || act(k) ~= act(start)
        x0 = hours(start) - h/2; x1 = hours(min(k,numel(act))) - h/2;
        if k > numel(act), x1 = hours(end) + h/2; end
        if (x1-x0) >= 1.5
            text(ax, (x0+x1)/2, yPos, names{act(start)+1}, 'FontSize', 7, 'HorizontalAlignment','center', 'Color', [0.3 0.3 0.3]);
        end
        start = k;
    end
end
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end

function s = design_line(p, mPlain)
% two-line summary of the design values the twin uses (read from export/plant_params.json)
s = {sprintf(['DESIGN (O1 PCM, O2 tank, O3 controller): tank %.1f kg water (arm 1 plain tank: %.1f kg, no PCM) | collector %.1f m2, FR(ta) %.2f, FRUL %.1f W/m2K | ' ...
    'PCM %s: Tm %.0f C, L %.0f kJ/kg, %.1f kg in %d capsules (D %.0f mm)'], ...
    p.m_w_kg, mPlain, p.A_coll_m2, p.fr_tau_alpha, p.fr_ul_W_m2K, p.selected_pcm, p.Tm_C, p.L_J_kg/1000, p.m_pcm_kg, p.n_capsule, 1000*p.D_cap_m), ...
    sprintf(['flow %.4f kg/s | shield trips: water > %.0f C, PCM > %.0f C | delivery target %.0f C | mains water %.1f C | sun cut-in %.0f W/m2'], ...
    p.flow_kg_s, p.bypass_wC, p.bypass_pC, p.T_deliv_C, p.T_mains_C, p.I_cutoff_Wm2)};
end
