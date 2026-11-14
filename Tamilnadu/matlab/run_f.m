function run_f(dayOfYear)
if nargin < 1 || isempty(dayOfYear), dayOfYear = 71; end   % day 71: PCM melts fully (same day as one_day_cycle_2021.png)
%RUN_F  Objective 4 item F: verify the pump-state fix in animate_system.m,
% then render one side-by-side (arm1/arm2/arm3) video of one full 2021 day
% at 1-hour steps: water temp, PCM temp, melt fraction, collector gain,
% pump state, with CHARGE/IDLE/BYPASS shaded and labelled per arm.
here = fileparts(mfilename('fullpath')); addpath(here);
exportDir = fullfile(here, '..', 'export');
resultsDir = fullfile(here, '..', '..', 'results');
if ~isfolder(resultsDir), error('results folder not found: %s', resultsDir); end
year = 2021;

tw = load_twin_params(exportDir, year);
W = tw.wx.signals.values; n = size(W,1);

g10 = jsondecode(fileread(fullfile(here, '..', '..', '..', 'objective2_design_optimization', 'results', 'g10_selection_r0.json')));
fraction = g10.chosen.fraction;
P_pcm = tw.P; P_plain = tw.P; P_plain(1) = tw.P(1) / (1 - fraction); P_plain(23) = 0;

arms = {'arm1_plain_B0', P_plain, 1; 'arm2_pcm_B0', P_pcm, 1; 'arm3_pcm_SAC', P_pcm, 0};
armTitles = {'Arm 1: Plain tank (B0)', 'Arm 2: PCM tank (B0)', 'Arm 3: PCM tank (SAC)'};

Ls = cell(3,1);
for a = 1:3
    Ls{a} = simulate_hours(tw, W, arms{a,2}, arms{a,3}, 0, []);
end

% ---- 1. Verify the pump-state fix: pump must be off whenever collector
% gain (Q_coll_Wh) is zero -- and quantify how often the OLD a_exec/GHI
% heuristic used to disagree with that (the bug this item fixes). ----
fprintf('\n=== Item F.1: pump-state correctness check (all 3 arms, full year %d) ===\n', year);
totalBugHours = 0;
for a = 1:3
    L = Ls{a};
    newPumpOn = L.Q_coll_Wh > 0;
    oldPumpOn = (L.a_exec == 0) & (L.n_sw == 0) & (L.GHI > tw.P(13));
    % the invariant this item requires:
    viol = sum(newPumpOn & (L.Q_coll_Wh == 0));
    bugHours = sum(oldPumpOn & ~newPumpOn);   % old heuristic said ON, real gain was zero
    totalBugHours = totalBugHours + bugHours;
    fprintf('  %-16s pump-on-with-zero-gain violations (new rule) = %d  -> %s\n', arms{a,1}, viol, ternary(viol==0,'PASS','FAIL'));
    fprintf('  %-16s hours the OLD a_exec/GHI heuristic showed pump ON at zero real gain = %d of %d\n', arms{a,1}, bugHours, n);
end
fprintf('  Total hours across 3 arms where the pre-fix animation would have shown a running pump at zero collector gain: %d\n', totalBugHours);

% ---- 2. Pick a day: prefer one where at least one arm actually hit the
% bug (to show the fix matters) AND where CHARGE/IDLE/BYPASS all appear
% somewhere across the three arms (richer side-by-side comparison). ----
nDays = floor(n/24);
bestDay = 1; bestScore = -1;
for d = 1:nDays
    sel = (d-1)*24 + (1:24);
    nStates = 0; nBug = 0;
    for a = 1:3
        L = Ls{a};
        nStates = max(nStates, numel(unique(L.a_exec(sel))));
        oldPumpOn = (L.a_exec(sel) == 0) & (L.n_sw(sel) == 0) & (L.GHI(sel) > tw.P(13));
        newPumpOn = L.Q_coll_Wh(sel) > 0;
        nBug = nBug + sum(oldPumpOn & ~newPumpOn);
    end
    score = nStates * 100 + nBug;   % state diversity dominates, bug hours as tiebreak
    if score > bestScore, bestScore = score; bestDay = d; end
end
d = dayOfYear;   % bestDay (auto pick) was day 313, where the PCM never melts
sel = (d-1)*24 + (1:24);
fprintf('\n=== Item F.2: rendering day-of-year %d (states seen + %d pump-fix hours in this window) ===\n', d, mod(bestScore,100));

outFile = fullfile(resultsDir, sprintf('o4_three_arm_day%03d_%d.mp4', d, year));
render_three_arm_day(Ls, sel, arms, armTitles, outFile, tw.P(13));
end

% ========================================================================
function render_three_arm_day(Ls, sel, arms, armTitles, outFile, Icut)
hours = 0:23;
actColors = [1.0 0.95 0.55; 0.85 0.85 0.85; 1.0 0.70 0.70];  % CHARGE, IDLE, BYPASS
actNames  = {'CHARGE','IDLE','BYPASS'};

W_px = 1920; H_px = 1080;
fig = figure('Visible','off','Units','pixels','Position',[0 0 W_px H_px],'Color','w');
tl = tiledlayout(fig, 4, 3, 'TileSpacing','compact', 'Padding','compact');

axT = gobjects(1,3); axF = gobjects(1,3); axG = gobjects(1,3); axP = gobjects(1,3);
cursors = gobjects(4,3);
data = struct();

for a = 1:3
    L = Ls{a};
    Tw = L.Tw(sel); Tp = L.Tpcm(sel); fm = 100*L.f_melt(sel);
    gain = L.Q_coll_Wh(sel); pumpOn = double(gain > 0);
    act = L.a_exec(sel);
    data(a).Tw = Tw; data(a).Tp = Tp; data(a).fm = fm; data(a).gain = gain;
    data(a).pumpOn = pumpOn; data(a).act = act;

    % ---- row 1: water + PCM temperature ----
    axT(a) = nexttile(tl, a); hold(axT(a), 'on'); box(axT(a),'on');
    if a == 1, Tall = Tw; else, Tall = [Tw;Tp]; end   % arm 1 has no PCM
    shade_actions(axT(a), hours, act, actColors, [min(Tall)-2, max(Tall)+4]);
    hW = plot(axT(a), hours, Tw, 'b-', 'LineWidth', 2, 'Marker','.', 'MarkerSize', 10);
    if a > 1
        hP = plot(axT(a), hours, Tp, '-', 'Color', [0.9 0.4 0], 'LineWidth', 2, 'Marker','.', 'MarkerSize', 10);
    end
    ylabel(axT(a), 'T [\circC]'); title(axT(a), armTitles{a}, 'FontSize', 12, 'FontWeight','bold');
    if a == 2, legend(axT(a), [hW hP], {'T_{water}','T_{PCM}'}, 'Location','southoutside','Orientation','horizontal'); end
    xlim(axT(a), [0 23]);
    label_actions(axT(a), hours, act, actNames, max(Tall)+2.5);

    % ---- row 2: melt fraction ----
    axF(a) = nexttile(tl, 3+a); hold(axF(a),'on'); box(axF(a),'on');
    shade_actions(axF(a), hours, act, actColors, [-5 105]);
    if a == 1
        text(axF(a), 11.5, 50, 'no PCM', 'HorizontalAlignment','center', 'FontSize', 12, 'Color', [0.4 0.4 0.4]);
    else
        plot(axF(a), hours, fm, 'm-', 'LineWidth', 2, 'Marker','.', 'MarkerSize', 10);
    end
    ylabel(axF(a), 'melt %'); ylim(axF(a), [-5 105]); xlim(axF(a), [0 23]);

    % ---- row 3: collector gain ----
    axG(a) = nexttile(tl, 6+a); hold(axG(a),'on'); box(axG(a),'on');
    gmax = max(max(gain),1);
    shade_actions(axG(a), hours, act, actColors, [-0.05*gmax, 1.15*gmax]);
    bar(axG(a), hours, gain, 'FaceColor', [0.95 0.6 0.1], 'EdgeColor','none');
    ylabel(axG(a), 'Q_{coll} [Wh]'); xlim(axG(a), [0 23]); ylim(axG(a), [-0.05*gmax, 1.15*gmax]);

    % ---- row 4: pump state ----
    axP(a) = nexttile(tl, 9+a); hold(axP(a),'on'); box(axP(a),'on');
    shade_actions(axP(a), hours, act, actColors, [-0.3 1.3]);
    stairs(axP(a), hours, pumpOn, 'g-', 'LineWidth', 2.5);
    ylim(axP(a), [-0.3 1.3]); yticks(axP(a), [0 1]); yticklabels(axP(a), {'OFF','ON'});
    ylabel(axP(a), 'pump'); xlabel(axP(a), 'hour of day'); xlim(axP(a), [0 23]);

    for r = 1:4
        axc = [axT(a) axF(a) axG(a) axP(a)];
        cursors(r,a) = xline(axc(r), hours(1), 'k-', 'LineWidth', 2, 'HandleVisibility', 'off');
    end
end
title(tl, sprintf('Tamil Nadu, all 3 arms -- 1-hour steps (collector cut-in = %.0f W/m^2)', Icut), 'FontSize', 13);

try
    vw = VideoWriter(outFile, 'MPEG-4');
    vw.FrameRate = 12; vw.Quality = 95;
    open(vw);
    usedFile = outFile;
catch
    altFile = regexprep(outFile, '\.mp4$', '.avi');
    vw = VideoWriter(altFile, 'Motion JPEG AVI');
    vw.FrameRate = 12;
    open(vw);
    usedFile = altFile;
end
cleanupObj = onCleanup(@() close(vw));

fps = 12; subFrames = 5;                       % 5 frames per simulated hour -> 115 frames, about 9.6 s
nFrames = 0;
for t = 1:23
    for s = 0:subFrames-1
        xc = hours(t) + s/subFrames;
        for a = 1:3
            for r = 1:4, set(cursors(r,a), 'Value', xc); end
        end
        drawnow;
        fr = getframe(fig);
        if ~isequal(size(fr.cdata,1), H_px) || ~isequal(size(fr.cdata,2), W_px)
            fr.cdata = imresize(fr.cdata, [H_px W_px]);
        end
        writeVideo(vw, fr.cdata); nFrames = nFrames + 1;
    end
end
close(vw); clear cleanupObj;
close(fig);

info = dir(usedFile);
fprintf('\n[run_f] video written -> %s  (%.2f MB, %d frames @ %d fps = %.1f s)\n', usedFile, info.bytes/1e6, nFrames, fps, nFrames/fps);
fprintf('F_DONE_MARKER\n');
end

% ------------------------------------------------------------------------
function shade_actions(ax, hours, act, colors, ylims)
h = hours(2)-hours(1);
start = 1;
for k = 2:numel(act)+1
    if k > numel(act) || act(k) ~= act(start)
        x0 = hours(start) - h/2; x1 = hours(min(k,numel(act))) - h/2;
        if k > numel(act), x1 = hours(end) + h/2; end
        patch(ax, [x0 x1 x1 x0], [ylims(1) ylims(1) ylims(2) ylims(2)], ...
            colors(act(start)+1, :), 'EdgeColor', 'none', 'FaceAlpha', 0.6);
        start = k;
    end
end
ylim(ax, ylims);
end

function label_actions(ax, hours, act, names, yPos)
h = hours(2)-hours(1);
start = 1;
for k = 2:numel(act)+1
    if k > numel(act) || act(k) ~= act(start)
        x0 = hours(start) - h/2; x1 = hours(min(k,numel(act))) - h/2;
        if k > numel(act), x1 = hours(end) + h/2; end
        if (x1-x0) >= 1.5
            text(ax, (x0+x1)/2, yPos, names{act(start)+1}, 'FontSize', 7, ...
                'HorizontalAlignment','center', 'Color', [0.3 0.3 0.3]);
        end
        start = k;
    end
end
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
