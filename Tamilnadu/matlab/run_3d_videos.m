function run_3d_videos(which, quick)
%RUN_3D_VIDEOS  3-D cutaway videos of the three arms side by side (Tamil Nadu, 100 L).
%
%   run_3d_videos          % both videos
%   run_3d_videos('day')   % one day (day 71 of 2021), 1-hour steps, slow
%   run_3d_videos('hold')  % 72 h hold after charging stops at 18:00 (start day 72)
%   run_3d_videos('edge')  % one-cycle 3-D videos for two edge cases: clear day and no sunlight (2021 weather, window day 5)
%
% THIS IS A 3-D VIEW OF A LUMPED RESULT: the twin has ONE water node and ONE PCM
% node, so every capsule in a tank shows the same melt fraction and the water has
% one temperature. Nothing is solved in 3-D; the capsule positions, collector and
% pipes are an illustrative layout (104 capsules, as in the design).
%
% Output (video/ folder next to export/):
%   o4_3d_day071_2021.mp4, o4_3d_hold72h_day072_2021.mp4, o4_3d_edge_clear_2021.mp4, o4_3d_edge_no_sunlight_2021.mp4
here = fileparts(mfilename('fullpath')); addpath(here);
exportDir = fullfile(here, '..', 'export');
outDir = fullfile(here, '..', 'video'); if ~isfolder(outDir), mkdir(outDir); end
if nargin < 1, which = 'both'; end
if nargin < 2, quick = false; end
year = 2021;
tw = load_twin_params(exportDir, year);
W = tw.wx.signals.values; n = size(W, 1);
g10 = jsondecode(fileread(fullfile(here, '..', '..', '..', 'objective2_design_optimization', 'results', 'g10_selection_r0.json')));
fraction = g10.chosen.fraction;
P_pcm = tw.P; P_plain = tw.P; P_plain(1) = tw.P(1) / (1 - fraction); P_plain(23) = 0;
arms = {P_plain, 1; P_pcm, 1; P_pcm, 0};
titles = {'Arm 1: plain tank (B0, no PCM)', 'Arm 2: PCM tank (B0, no AI)', 'Arm 3: PCM tank (SAC)'};
hasPcm = [false true true];
nCap = tw.params.n_capsule;
dsg = design_line(tw.params, P_plain(1));

Ls = cell(3,1);
for a = 1:3, Ls{a} = simulate_hours(tw, W, arms{a,1}, arms{a,2}, 0, []); end

if any(strcmp(which, {'both','day'}))
    d = 71; sel = (d-1)*24 + (1:24);
    S = cell(3,1);
    for a = 1:3
        L = Ls{a};
        S{a} = struct('Tw', L.Tw(sel), 'Tp', L.Tpcm(sel), 'f', L.f_melt(sel), 'Q', L.Q_coll_Wh(sel), ...
            'GHI', L.GHI(sel), 'Ta', L.T_amb(sel), 'act', L.a_exec(sel), 'draw', L.draw_kg(sel), 'E', L.E_del_Wh(sel));
    end
    clk = arrayfun(@(h) sprintf('day %d of %d, %02d:00', d, year, h-1), 1:24, 'UniformOutput', false);
    head = 'One day, 1-hour steps (slow)';
    src = {sprintf('Data: export/weather_%d.csv, day %d (weather hours %d-%d)', year, d, sel(1), sel(end)), ...
        'Plant: export/plant_params.json | controller: export/sac_actor_r0.json (r0 smartfc, V3) | simulated hourly by matlab/simulate_hours.m, 150 s sub-steps'};
    render3d(S, titles, hasPcm, nCap, clk, head, src, fullfile(outDir, 'o4_3d_day071_2021.mp4'), ternary(quick,1,6), 12, true, dsg);
end

if any(strcmp(which, {'both','hold'}))
    d = 72; holdH = 72;
    off18 = find(W(1:24,4) == 18, 1);
    iStart = (d-1)*24 + off18;
    S = cell(3,1);
    for a = 1:3
        L = Ls{a}; P = arms{a,1};
        Tw_ = L.Tw(iStart); Tp_ = L.Tpcm(iStart); h_ = L.h_pcm(iStart); f_ = L.f_melt(iStart);
        s = struct('Tw', zeros(holdH+1,1), 'Tp', zeros(holdH+1,1), 'f', zeros(holdH+1,1), 'Q', zeros(holdH+1,1), ...
            'GHI', zeros(holdH+1,1), 'Ta', zeros(holdH+1,1), 'act', 2*ones(holdH+1,1), 'draw', zeros(holdH+1,1), 'E', zeros(holdH+1,1));
        s.Tw(1) = Tw_; s.Tp(1) = Tp_; s.f(1) = f_; s.Ta(1) = W(iStart,3);
        for k = 1:holdH
            [Tw_, Tp_, h_, f_] = pcm_plant_hour(0, W(iStart+k,3), 0, 2, Tw_, Tp_, h_, f_, P);
            s.Tw(k+1) = Tw_; s.Tp(k+1) = Tp_; s.f(k+1) = f_; s.Ta(k+1) = W(iStart+k,3);
        end
        S{a} = s;
    end
    clk = arrayfun(@(k) sprintf('+%d h after charging stopped (day %d of %d, 18:00 start)', k-1, d, year), 1:holdH+1, 'UniformOutput', false);
    head = '72 h hold: charging stops at 18:00, no sun, no draw';
    src = {sprintf('Data: export/weather_%d.csv ambient temperature from hour %d | each arm starts from its OWN state at 18:00 (full-year run)', year, iStart), ...
        'Same method as run_hold_test.m: BYPASS command, sun off (I = 0), no hot-water draw, real ambient | plant: export/plant_params.json | controller: export/sac_actor_r0.json'};
    render3d(S, titles, hasPcm, nCap, clk, head, src, fullfile(outDir, 'o4_3d_hold72h_day072_2021.mp4'), ternary(quick,1,3), 15, false, dsg);
end
if any(strcmp(which, {'edge','edge_clear','edge_no_sunlight'}))
    % single-cycle (one day) 3-D videos for two edge conditions: a normal clear day and the first day of
    % a 4-day no-sunlight event. Same window position (hours 2161-2400) and edits as run_c_scenarios.m, but on 2021 weather (a validation year).
    tw11 = load_twin_params(exportDir, 2021); W11 = tw11.wx.signals.values;
    k0 = 90 * 24; nWin = 10 * 24;
    base = W11(k0 + (1:nWin), :); iS = 4*24 + 1; iE = 8*24;
    names = {'clear', 'no_sunlight'};
    if strcmp(which, 'edge_clear'), names = {'clear'}; elseif strcmp(which, 'edge_no_sunlight'), names = {'no_sunlight'}; end
    selE = 4*24 + (1:24);                         % window day 5 (first event day)
    doyE = floor((k0 + selE(1) - 1) / 24) + 1;
    for q = 1:numel(names)
        nm = names{q}; Wc = base;
        if strcmp(nm, 'no_sunlight')
            Wc(iS:iE, 2) = 0;
            headE = 'EDGE CASE, one cycle: NO SUNLIGHT (day 1 of a 4-day event)';
            whatE = 'GHI set to 0 on window days 5-8';
        else
            headE = 'EDGE CASE, one cycle: CLEAR SUNNY DAY (reference)';
            whatE = 'no change to the stored 2021 weather';
        end
        S = cell(3,1);
        for a = 1:3
            L = simulate_hours(tw11, Wc, arms{a,1}, arms{a,2}, 0, false(nWin,1));
            S{a} = struct('Tw', L.Tw(selE), 'Tp', L.Tpcm(selE), 'f', L.f_melt(selE), 'Q', L.Q_coll_Wh(selE), ...
                'GHI', L.GHI(selE), 'Ta', L.T_amb(selE), 'act', L.a_exec(selE), 'draw', L.draw_kg(selE), 'E', L.E_del_Wh(selE));
        end
        clkE = arrayfun(@(h) sprintf('day %d of 2021, %02d:00', doyE, h-1), 1:24, 'UniformOutput', false);
        srcE = {sprintf('Data: export/weather_2021.csv, weather hours %d-%d (day %d of 2021); what changed: %s', k0+selE(1), k0+selE(end), doyE, whatE), ...
            'Plant: export/plant_params.json | controller: export/sac_actor_r0.json (r0 smartfc, V3) | simulated hourly by matlab/simulate_hours.m, 150 s sub-steps'};
        render3d(S, titles, hasPcm, nCap, clkE, headE, srcE, fullfile(outDir, ['o4_3d_edge_' nm '_2021.mp4']), ternary(quick,1,6), 12, true, dsg);
    end
end
fprintf('THREE_D_DONE\n');
end

% ========================================================================
function render3d(S, titles, hasPcm, nCap, clk, head, src, outFile, nsub, fps, showSun, dsg)
N = numel(S{1}.Tw);
actNames = {'CHARGE','IDLE','BYPASS'};
fig = figure('Visible','off','Units','pixels','Position',[0 0 1920 1080],'Color','w');

axH = axes(fig, 'Position', [0 0.80 1 0.20]); axis(axH, 'off'); xlim(axH,[0 1]); ylim(axH,[0 1]);
text(axH, 0.01, 0.98, ['3-D cutaway: ' head], 'FontSize', 17, 'FontWeight', 'bold', 'Interpreter', 'none', 'VerticalAlignment', 'top');
text(axH, 0.01, 0.80, src, 'FontSize', 9, 'Color', [0.25 0.25 0.25], 'Interpreter', 'none', 'VerticalAlignment', 'top');
text(axH, 0.01, 0.62, dsg, 'FontSize', 9, 'Color', [0.15 0.35 0.15], 'Interpreter', 'none', 'VerticalAlignment', 'top');
text(axH, 0.01, 0.34, 'The twin has ONE water node and ONE PCM node per tank, so all capsules in a tank show the same melt fraction. Layout is illustrative; nothing is solved in 3-D.', ...
    'FontSize', 9, 'Color', [0.5 0.2 0.2], 'Interpreter', 'none', 'VerticalAlignment', 'top');
hClock = text(axH, 0.01, 0.18, '', 'FontSize', 14, 'FontWeight', 'bold', 'Color', [0.1 0.2 0.6], 'Interpreter', 'none', 'VerticalAlignment', 'top');

ax = gobjects(1,3); sc = cell(1,3); hRead = gobjects(1,3);
for a = 1:3
    ax(a) = axes(fig, 'Position', [0.01 + (a-1)*0.322, 0.10, 0.31, 0.69]);
    sc{a} = build_scene(ax(a), hasPcm(a), nCap);
    title(ax(a), titles{a}, 'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
    hRead(a) = text(ax(a), 0.5, -0.03, '', 'Units', 'normalized', 'HorizontalAlignment', 'center', 'FontSize', 10, 'FontName', 'Consolas', 'VerticalAlignment', 'top', 'Interpreter', 'none');
end
% temperature colour legend
axC = axes(fig, 'Position', [0.972 0.25, 0.010, 0.45]);
imagesc(axC, [0 1], [25 75], reshape(tmap(), [], 1, 3)); axC.YDir = 'normal'; axC.XTick = []; axC.YAxisLocation = 'left';
ylabel(axC, 'water temperature [C]', 'Interpreter', 'none'); axC.YAxis.FontSize = 9;
axB = axes(fig, 'Position', [0 0 0.96 0.04]); axis(axB, 'off'); xlim(axB,[0 1]); ylim(axB,[0 1]);
text(axB, 0.01, 0.5, 'Capsule colour: blue = solid, orange = fully melted.   Collector: yellow = idle, orange = heat gain.   Pump: green = running, grey = off.', 'FontSize', 10, 'Color', [0.3 0.3 0.3], 'Interpreter', 'none');

try
    vw = VideoWriter(outFile, 'MPEG-4'); vw.FrameRate = fps; vw.Quality = 95; open(vw); used = outFile;
catch
    used = regexprep(outFile, '\.mp4$', '.avi'); vw = VideoWriter(used, 'Motion JPEG AVI'); vw.FrameRate = fps; open(vw);
end
cleanupObj = onCleanup(@() close(vw));
nF = 0; total = (N-1)*nsub;
for k = 1:N-1
    for s = 0:nsub-1
        u = s/nsub;
        for a = 1:3
            Sa = S{a};
            Tw = Sa.Tw(k) + u*(Sa.Tw(k+1)-Sa.Tw(k));
            Tp = Sa.Tp(k) + u*(Sa.Tp(k+1)-Sa.Tp(k));
            f  = Sa.f(k)  + u*(Sa.f(k+1)-Sa.f(k));
            update_scene(sc{a}, Tw, f, Sa.Q(k), Sa.GHI(k), Sa.act(k), Sa.draw(k), hasPcm(a), showSun);
            pump = Sa.Q(k) > 0;
            if hasPcm(a), pc = sprintf('T_pcm %5.1f C  melt %3.0f%%', Tp, 100*f); else, pc = 'T_pcm  --   melt  -- '; end
            set(hRead(a), 'String', sprintf(['T_water %5.1f C   %s\nQ_coll %5.0f Wh   action %-6s   pump %-3s\n' ...
                'sun %4.0f W/m2   ambient %4.1f C   draw %3.1f kg/h'], Tw, pc, Sa.Q(k), actNames{Sa.act(k)+1}, ternary(pump,'ON','OFF'), Sa.GHI(k), Sa.Ta(k), Sa.draw(k)));
            view(ax(a), 25 + 55*((k-1)*nsub+s)/total, 18);
        end
        set(hClock, 'String', ['TIME  ' clk{k}]);
        drawnow;
        fr = getframe(fig);
        if size(fr.cdata,1) ~= 1080 || size(fr.cdata,2) ~= 1920, fr.cdata = imresize(fr.cdata, [1080 1920]); end
        writeVideo(vw, fr.cdata); nF = nF + 1;
    end
    if mod(k, 12) == 0, fprintf('[3d] %s  hour %d/%d\n', outFile(end-25:end), k, N-1); end
end
close(vw); clear cleanupObj; close(fig);
d = dir(used);
fprintf('[3d] %s  (%.2f MB, %d frames = %.1f s)\n', used, d.bytes/1e6, nF, nF/fps);
end

% ------------------------------------------------------------------------
function sc = build_scene(ax, hasPcm, nCap)
hold(ax, 'on'); axis(ax, 'equal', 'off');
xlim(ax, [-6.5 1.6]); ylim(ax, [-1.6 1.6]); zlim(ax, [-0.4 5.2]);
H = 2.4; Rt = 1;
[cx, cy, cz] = cylinder(Rt, 48);
sc.water = surf(ax, cx, cy, cz*H, 'EdgeColor', 'none', 'FaceAlpha', 0.30, 'FaceColor', [0.4 0.6 0.9]);
th = linspace(0, 2*pi, 48);
sc.lid = fill3(ax, Rt*cos(th), Rt*sin(th), H*ones(size(th)), [0.4 0.6 0.9], 'FaceAlpha', 0.30, 'EdgeColor', 'k');
sc.base = fill3(ax, Rt*cos(th), Rt*sin(th), zeros(size(th)), [0.4 0.6 0.9], 'FaceAlpha', 0.30, 'EdgeColor', 'k');
sc.caps = gobjects(0);
if hasPcm
    [sx, sy, sz] = sphere(8); rc = 0.15;
    pos = zeros(0,2);
    pos(end+1,:) = [0 0];
    for q = 1:6, pos(end+1,:) = 0.32*[cos(2*pi*(q-1)/6), sin(2*pi*(q-1)/6)]; end %#ok<AGROW>
    for q = 1:12, pos(end+1,:) = 0.64*[cos(2*pi*(q-1)/12 + 0.2), sin(2*pi*(q-1)/12 + 0.2)]; end %#ok<AGROW>
    zl = linspace(0.32, H-0.32, 6);
    cnt = 0;
    for li = 1:numel(zl)
        for p = 1:size(pos,1)
            if cnt >= nCap, break; end
            cnt = cnt + 1;
            sc.caps(end+1) = surf(ax, pos(p,1)+rc*sx, pos(p,2)+rc*sy, zl(li)+rc*sz, 'EdgeColor', 'none', 'FaceColor', [0.25 0.45 0.9]); %#ok<AGROW>
        end
    end
end
% collector (tilted plate) with sun
ca = deg2rad(30);
sc.coll = patch(ax, 'XData', [-5.0 -2.7 -2.7 -5.0]', 'YData', [-1 -1 1 1]', ...
    'ZData', [0.4 0.4+2.3*sin(ca) 0.4+2.3*sin(ca) 0.4]', 'FaceColor', [0.95 0.9 0.5], 'EdgeColor', [0.3 0.3 0.3], 'LineWidth', 1.5, 'FaceLighting', 'none');
% pipes and pump
sc.pipeHot  = plot3(ax, [-2.7 -1.4 -1.0], [0 0 0], [0.4+2.3*sin(ca) 2.2 2.1], '-', 'LineWidth', 3, 'Color', [0.6 0.6 0.6]);
sc.pipeCold = plot3(ax, [-1.0 -1.5 -4.2 -5.0], [0 0 0 0], [0.35 0.15 0.15 0.4], '-', 'LineWidth', 3, 'Color', [0.6 0.6 0.6]);
[px, py, pz] = sphere(10);
sc.pump = surf(ax, -2.6+0.2*px, 0.2*py, 0.15+0.2*pz, 'EdgeColor', 'none', 'FaceColor', [0.6 0.6 0.6]);
% sun and rays
sc.rays = gobjects(5,1);
for r = 1:5
    sc.rays(r) = plot3(ax, [-6.2 -4.2+(r-3)*0.35], [0 (r-3)*0.35], [4.6 1.9+(r-3)*0.12], '-', 'Color', [1 0.8 0.1], 'LineWidth', 1);
end
sc.sun = surf(ax, -6.2+0.35*px, 0.35*py, 4.6+0.35*pz, 'EdgeColor', 'none', 'FaceColor', [1 0.85 0.1]);
% hot-water draw arrow and mains inlet
sc.draw = plot3(ax, [0.6 1.5], [0 0], [2.1 2.4], '-', 'LineWidth', 5, 'Color', [0.8 0.8 0.8]);
plot3(ax, [0.9 0.9], [0 0], [0.3 0.3], 'o', 'Color', [0.3 0.6 0.9], 'MarkerSize', 3);
lighting(ax, 'gouraud'); camlight(ax, 'headlight'); view(ax, 25, 18);
set(sc.coll, 'FaceLighting', 'none');
end

function update_scene(sc, Tw, f, Qc, ghi, act, draw, hasPcm, showSun)
c = tcol(Tw);
set(sc.water, 'FaceColor', c); set(sc.lid, 'FaceColor', c); set(sc.base, 'FaceColor', c);
if hasPcm && ~isempty(sc.caps)
    set(sc.caps, 'FaceColor', (1-f)*[0.25 0.45 0.9] + f*[1.0 0.55 0.05]);
end
g = min(max(Qc/1500, 0), 1);
set(sc.coll, 'FaceColor', (1-g)*[0.95 0.9 0.5] + g*[1.0 0.5 0.05]);
on = Qc > 0;
set(sc.pump, 'FaceColor', ternary(on, [0.1 0.8 0.2], [0.6 0.6 0.6]));
pc = ternary(on, [0.9 0.3 0.1], [0.6 0.6 0.6]);
set(sc.pipeHot, 'Color', pc); set(sc.pipeCold, 'Color', ternary(on, [0.2 0.4 0.9], [0.6 0.6 0.6]));
vis = ternary(ghi > 10, 'on', 'off');
for r = 1:numel(sc.rays), set(sc.rays(r), 'Visible', vis, 'LineWidth', 0.5 + 3*min(ghi/1000, 1)); end
set(sc.sun, 'FaceColor', ternary(ghi > 10, [1 0.85 0.1], [0.5 0.5 0.5]));
set(sc.draw, 'Color', ternary(draw > 0, [0.2 0.7 0.9], [0.8 0.8 0.8]));
end

function c = tcol(T)
t = min(max((T - 25) / 50, 0), 1);
c = [t, 0.35*(1-abs(2*t-1))+0.1, 1-t];
c = min(max(c, 0), 1);
end

function m = tmap()
t = linspace(0, 1, 64)';
m = [t, 0.35*(1-abs(2*t-1))+0.1, 1-t];
m = min(max(m, 0), 1);
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
