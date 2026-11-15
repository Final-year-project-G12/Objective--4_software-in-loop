function R = animate_system3d(regime, ctrl, file)
%ANIMATE_SYSTEM3D  70-hour 3-D system video, three tanks side by side, in the style of the Tamil Nadu 3-D videos (run_3d_videos.m /
%   render3d) with the components of the 2-D system animation (animate_system.m): sun and rays, tilted solar collector, hot and return
%   pipes with moving water particles, a spinning pump, CHARGE / IDLE / BYPASS mode with the red cross on the collector, hot-water draw,
%   cold make-up, and a trend strip with T_top, T_bottom, T_PCM, the 72 C shield, the 45 C delivery line and GHI.
%
%   R = animate_system3d(1, 'SAC', '../video/o4_system3d_70h_r1_SAC_2023.mp4')     regime 0, 1, 2; ctrl 'DQN' (regime 1) or 'SAC'
%
% Arms (same weather): 1 plain tank + B0, 2 PCM tank + B0 (no AI), 3 PCM tank + the Objective 3 controller (the DQN or SAC network exported
% by export_from_python.py is evaluated INSIDE the simulation every hour; its CHARGE / IDLE / BYPASS command, after the in-plant shield and
% interlock, is what the pump and the collector cross show). Clip = 8 h of the real controlled afternoon (10:00-18:00, each arm from its own
% state in the full-year 2023 run), then 62 h with the sun off and no hot-water draw (the hold test of run_hold_test.m): 70 h in all.
% The tank is drawn as its 10 real layers (colour = node temperature); capsules are coloured by their node's melt fraction.
% Evening: of the 12 hold-test evenings, the one whose controller hold time is closest to the 12-evening mean among those that end inside
% the 62 h window. Assumptions: a 3-D view of a 1-D, 10-node result (nothing is solved in 3-D; collector, pipes and capsule ring layout are
% illustrative); pump is drawn running when the collector adds heat (Q_coll > 0), as in animate_system.m; delivery line 45 C (Rajasthan
% O2 target); model values. Nothing here changes any stored result.
here = fileparts(mfilename('fullpath')); addpath(here);
mode = 0;  if strcmp(ctrl, 'SAC'), mode = 2; end
ed = fullfile(here, '..', sprintf('export_r%d', regime));
tw = load_twin_params(ed, 2023);
W = tw.wx.signals.values(:, 1:4);  P = tw.P;  Pp = make_plain_tank(P);
if mode == 2, cj = jsondecode(fileread(fullfile(ed, sprintf('sac_actor_r%d.json', regime)))); cf = sprintf('sac_actor_r%d.json', regime);
else, cj = jsondecode(fileread(fullfile(ed, sprintf('dqn_qnet_r%d.json', regime)))); cf = sprintf('dqn_qnet_r%d.json', regime); end
Ps = {Pp, P, P};  modes = {1, 1, mode};
titles = {'Arm 1: plain tank (B0, no PCM)', 'Arm 2: PCM tank (B0, no AI)', ['Arm 3: PCM tank (' ctrl ', Objective 3 model)']};
hasPcm = [false true true];
L = cell(1, 3);
for a = 1:3, L{a} = simulate_hours(tw, W, Ps{a}, modes{a}, 0, []); end
rows17 = find(W(:, 4) == 17);  sd = round(linspace(15, 345, 12));
NDAY = 8;  H = 62;  th = 45;  n = NDAY + H + 1;  t0 = 18 - NDAY;      % clip starts at 10:00
tau3 = zeros(12, 1);
for s = 1:12
    t = rows17(sd(s));
    Rh = run_hold_test(P, W, L{3}.Tn(t, :)', L{3}.hn(t, :)', t + 1, 72, th);
    tau3(s) = Rh.tau;
end
ok = find(tau3 <= H - 0.5);  if isempty(ok), ok = (1:12)'; end
[~, j] = min(abs(tau3(ok) - mean(tau3)));  day = sd(ok(j));  t17 = rows17(day);
% ---- per-arm states and hourly flows (index k = state after k-1 hours; flows at k belong to the hour that ends in state k) ----
Tn = zeros(n, 10, 3);  hn = zeros(n, 10, 3);
Q = zeros(n, 3);  act = zeros(n, 3);  ghi = zeros(n, 3);  drw = zeros(n, 3);  Ta = zeros(n, 3);  Ed = zeros(n, 3);  sh = zeros(n, 3);  il = zeros(n, 3);
r0 = t17 - NDAY;
for a = 1:3
    Tn(1:NDAY + 1, :, a) = L{a}.Tn(r0:t17, :);  hn(1:NDAY + 1, :, a) = L{a}.hn(r0:t17, :);
    rr = r0 + 1:t17;  ii = 2:NDAY + 1;
    Q(ii, a) = L{a}.Q_coll_Wh(rr);  act(ii, a) = L{a}.a_exec(rr);  ghi(ii, a) = L{a}.GHI(rr);  drw(ii, a) = L{a}.draw_kg(rr);
    Ta(ii, a) = L{a}.T_amb(rr);  Ed(ii, a) = L{a}.E_del_Wh(rr);  sh(ii, a) = L{a}.n_sw(rr) + L{a}.n_sp(rr);  il(ii, a) = L{a}.interlock(rr);
    Ta(1, a) = L{a}.T_amb(r0);
    T = Tn(NDAY + 1, :, a)';  h = hn(NDAY + 1, :, a)';
    for k = 1:H
        [T, h] = pcm_plant_hour(0, W(t17 + k, 3), 0, 2, T, h, Ps{a});
        Tn(NDAY + 1 + k, :, a) = T';  hn(NDAY + 1 + k, :, a) = h';
        act(NDAY + 1 + k, a) = 3;  Ta(NDAY + 1 + k, a) = W(t17 + k, 3);
    end
end
Ttop = zeros(n, 3);  Tbot = zeros(n, 3);  Tpcm = zeros(n, 3);  fm = zeros(n, 3);
for a = 1:3
    for k = 1:n
        s = pcm_derive_state(Tn(k, :, a)', hn(k, :, a)', Ps{a});
        Ttop(k, a) = s(1);  Tbot(k, a) = s(2);  Tpcm(k, a) = s(4);  fm(k, a) = s(5);
    end
end
tau = zeros(1, 3);  cens = false(1, 3);
for a = 1:3
    v = Ttop(NDAY + 1:end, a);  tau(a) = H;  cens(a) = true;
    for k = 2:numel(v)
        if v(k) < th, tau(a) = (k - 2) + (v(k - 1) - th) / (v(k - 1) - v(k)); cens(a) = false; break; end
    end
    Rh = run_hold_test(Ps{a}, W, L{a}.Tn(t17, :)', L{a}.hn(t17, :)', t17 + 1, H, th);
    assert(abs(Rh.tau - tau(a)) < 1e-9, 'animate_system3d: hold time differs from run_hold_test');
end
R = struct('regime', regime, 'controller', ctrl, 'day', day, 'tau_h', tau, 'censored', cens, 'mean_tau_ctrl', mean(tau3));
cumE = cumsum(Ed);

% ---- figure ----
fig = figure('Visible', 'off', 'Units', 'pixels', 'Position', [0 0 1920 1080], 'Color', 'w');
try, theme(fig, 'light'); catch, end
pp = tw.params;
axH = axes(fig, 'Position', [0 0.865 1 0.135]); axis(axH, 'off'); xlim(axH, [0 1]); ylim(axH, [0 1]);
text(axH, 0.01, 0.98, sprintf('3-D system view, Rajasthan regime %d: how long does the tank keep the heat? (%s, 70 h)', regime, ctrl), 'FontSize', 17, 'FontWeight', 'bold', 'VerticalAlignment', 'top', 'Interpreter', 'none');
text(axH, 0.01, 0.76, {sprintf(['Data: export_r%d/weather_2023.csv, day %d of 2023 from 10:00 (8 h with sun, controlled), then 62 h with sun off and no draw (hold test) | plant: export_r%d/plant_params.json'], regime, day, regime), ...
    sprintf('Controller: %s (%s), evaluated in the loop every hour; its command goes through the in-plant shield (water > %.0f C, PCM > %.0f C) and interlock | simulated by matlab/simulate_hours.m, 150 s sub-steps', cf, cj.tag, pp.bypass_wC, pp.bypass_pC), ...
    sprintf('DESIGN (O1 PCM, O2 tank): %.0f L tank, %.1f kg water + %.1f kg %s (Tm %.0f C, L %.0f kJ/kg) in %d capsules (D %.0f mm), 10 layers | collector %.1f m2, FR(ta) %.2f, FRUL %.1f W/m2K | flow %.4f kg/s | delivery %.0f C | mains %.1f C | sun cut-in %.0f W/m2', ...
        pp.tank_volume_L, pp.m_water_kg, pp.m_pcm_kg, pp.selected_pcm, pp.Tm_C, pp.L_J_kg / 1000, pp.n_capsule, 1000 * pp.D_cap_m, pp.A_coll_m2, pp.fr_tau_alpha, pp.fr_ul_W_m2K, pp.flow_kg_s, pp.T_deliv_C, pp.T_mains_C, pp.I_cutoff_Wm2)}, ...
    'FontSize', 9, 'Color', [0.2 0.3 0.2], 'VerticalAlignment', 'top', 'Interpreter', 'none');
hClock = text(axH, 0.01, 0.0, '', 'FontSize', 15, 'FontWeight', 'bold', 'Color', [0.1 0.2 0.6], 'Interpreter', 'none', 'VerticalAlignment', 'bottom');
ax = gobjects(1, 3);  sc = cell(1, 3);  hRead = gobjects(1, 3);  hMode = gobjects(1, 3);
ncap = round(P(61:70));
for a = 1:3
    ax(a) = axes(fig, 'Position', [0.01 + (a - 1) * 0.322, 0.34, 0.31, 0.49]);
    sc{a} = build_scene(ax(a), hasPcm(a), ncap);
    title(ax(a), titles{a}, 'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
    hMode(a) = text(ax(a), -2.4, 0, 4.9, ' ', 'Clipping', 'off', 'HorizontalAlignment', 'center', 'FontSize', 13, 'FontWeight', 'bold', 'Interpreter', 'none');
    axr = axes(fig, 'Position', [0.01 + (a - 1) * 0.322, 0.215, 0.31, 0.125]); axis(axr, 'off'); xlim(axr, [0 1]); ylim(axr, [0 1]);
    hRead(a) = text(axr, 0.5, 0.98, '', 'HorizontalAlignment', 'center', 'FontSize', 10, 'FontName', 'Consolas', 'VerticalAlignment', 'top', 'Interpreter', 'none', ...
        'BackgroundColor', [0.97 0.97 0.97], 'EdgeColor', [0.75 0.75 0.75]);
end
axC = axes(fig, 'Position', [0.972 0.40, 0.010, 0.40]);
imagesc(axC, [0 1], [25 75], reshape(tmap(), [], 1, 3)); axC.YDir = 'normal'; axC.XTick = []; axC.YAxisLocation = 'left';
ylabel(axC, 'water temperature [C]', 'Interpreter', 'none'); axC.YAxis.FontSize = 9;
% trend strip (controller arm, plus the other two top-layer traces)
ax2 = axes(fig, 'Position', [0.05 0.055 0.90 0.12]); hold(ax2, 'on'); box(ax2, 'on');
tt = (0:n - 1)';
yyaxis(ax2, 'left');
plot(ax2, tt, Ttop(:, 3), '-', 'Color', [0 0.3 0.9], 'LineWidth', 1.5); plot(ax2, tt, Tbot(:, 3), '-', 'Color', [0.2 0.7 0.9], 'LineWidth', 1.2);
plot(ax2, tt, Tpcm(:, 3), '-', 'Color', [0.85 0.45 0.1], 'LineWidth', 1.5);
plot(ax2, tt, Ttop(:, 1), ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2); plot(ax2, tt, Ttop(:, 2), ':', 'Color', [0.85 0.2 0.2], 'LineWidth', 1.2);
yline(ax2, pp.bypass_wC, 'r--'); yline(ax2, th, 'g--'); ylim(ax2, [20 80]); ylabel(ax2, 'T [\circC]');
yyaxis(ax2, 'right'); plot(ax2, tt, ghi(:, 3), '-', 'Color', [0.9 0.75 0.1], 'LineWidth', 1.3); ylabel(ax2, 'GHI [W/m^2]'); ylim(ax2, [0 1100]);
xline(ax2, NDAY, 'k:'); xlim(ax2, [0 n - 1]); xlabel(ax2, 'clip hour (0 = 10:00 of the shown day; 18:00 = hour 8, sun off and no draw after it)');
hCur = xline(ax2, 0, 'k-', 'LineWidth', 1.5);
legend(ax2, {'T_{top}', 'T_{bottom}', 'T_{PCM}', 'plain tank top', 'PCM+B0 top', '72 \circC shield', '45 \circC delivery', 'GHI'}, 'Location', 'northoutside', 'Orientation', 'horizontal', 'FontSize', 8);
axB = axes(fig, 'Position', [0 0 0.96 0.03]); axis(axB, 'off'); xlim(axB, [0 1]); ylim(axB, [0 1]);
text(axB, 0.01, 0.5, 'Capsule colour: blue = solid, orange = fully melted.  Collector: yellow = idle, orange = heat gain, red cross = BYPASS.  Pump: green = running (water particles move), grey = off.  Dotted trend lines = the other two arms.', 'FontSize', 9, 'Color', [0.3 0.3 0.3], 'Interpreter', 'none');

vw = VideoWriter(file, 'MPEG-4'); vw.FrameRate = 10; vw.Quality = 95; open(vw);
cleanupObj = onCleanup(@() close(vw));
actNames = {'CHARGE', 'IDLE', 'BYPASS'};
nsub = 4;
for k = 1:n
    last = (k == n);
    ns = nsub;  if last, ns = 12; end
    kk = min(k + 1, n);                                           % flows of the hour that follows state k
    for s = 0:ns - 1
        u = s / nsub;  if last, u = 0; end
        for a = 1:3
            Tl = (1 - u) * Tn(k, :, a) + u * Tn(kk, :, a);  hl = (1 - u) * hn(k, :, a) + u * hn(kk, :, a);
            Qa = Q(kk, a);  pumpOn = Qa > 0 && ~last;
            if kk <= NDAY + 1 && ~last
                a_ex = act(kk, a);  bypass = (a_ex == 2) || il(kk, a) >= 2;  sunOn = ghi(kk, a) > 10;
                if a_ex <= 2, mname = actNames{a_ex + 1}; else, mname = 'IDLE'; end
                if il(kk, a) == 2, mname = 'SENSOR FAULT: BYPASS'; end
                if sh(kk, a) > 0, mname = [mname ' (shield)']; end %#ok<AGROW>
                mcol = ternary(bypass, [0.75 0.15 0.15], ternary(pumpOn, [0.1 0.5 0.15], [0.45 0.45 0.45]));
                gh = ghi(kk, a);  dr = drw(kk, a);  tam = Ta(kk, a);
                ptxt = ternary(pumpOn, 'pump ON', 'pump OFF');
                if ~pumpOn && ~bypass && a_ex == 0, ptxt = 'pump OFF (no gain)'; end
                head = sprintf('%s  |  %s', mname, ptxt);
            else
                bypass = false;  sunOn = false;  gh = 0;  dr = 0;  tam = Ta(kk, a);  mcol = [0.2 0.35 0.7];
                head = 'SUN OFF: hold (no draw, pump off)';
            end
            update_scene(sc{a}, Tl, hl, Ps{a}, hasPcm(a), Qa, gh, bypass, sunOn, dr, pumpOn, s);
            set(hMode(a), 'String', head, 'Color', mcol);
            sTop = Ttop(k, a) + u * (Ttop(kk, a) - Ttop(k, a));  sBot = Tbot(k, a) + u * (Tbot(kk, a) - Tbot(k, a));
            sPc = Tpcm(k, a) + u * (Tpcm(kk, a) - Tpcm(k, a));  sF = fm(k, a) + u * (fm(kk, a) - fm(k, a));
            if hasPcm(a), pc = sprintf('T_PCM %5.1f C  melted %3.0f %%', sPc, 100 * sF); else, pc = 'T_PCM  --   melted  -- '; end
            el = (k - 1) - NDAY;
            if el < 0, hold_txt = 'hold: starts at 18:00';
            elseif ~cens(a) && el + u >= tau(a), hold_txt = sprintf('BELOW 45 C after %.1f h of hold', tau(a));
            else, hold_txt = sprintf('above 45 C for %d h since 18:00%s', el, ternary(cens(a) && el >= H, ' (still above at 62 h)', '')); end
            set(hRead(a), 'String', sprintf(['day %d  %02d:00   GHI %4.0f W/m2   T_amb %4.1f C\n' ...
                'T_top %5.1f C   T_bottom %5.1f C\n%s\ncollector %4.0f Wh   draw %4.1f kg/h   delivered(45 C) %5.0f Wh (cum.)\n%s'], ...
                day + floor((t0 + k - 1) / 24), mod(8 + k - 1, 24), gh, tam, sTop, sBot, pc, Qa * pumpOn, dr, cumE(kk, a), hold_txt));
        end
        set(hClock, 'String', sprintf('TIME  day %d of 2023 + %d d, %02d:00   (clip hour %d of %d)', day, floor((t0 + k - 1) / 24), mod(8 + k - 1, 24), k - 1, n - 1));
        set(hCur, 'Value', k - 1 + u);
        for a = 1:3, view(ax(a), 25 + 40 * ((k - 1) + u) / (n - 1), 18); end
        drawnow;
        fr = getframe(fig);
        if size(fr.cdata, 1) ~= 1080 || size(fr.cdata, 2) ~= 1920, fr.cdata = imresize(fr.cdata, [1080 1920]); end
        writeVideo(vw, fr.cdata);
    end
    if mod(k, 10) == 0, fprintf('[system3d] r%d %s hour %d/%d\n', regime, ctrl, k - 1, n - 1); end
end
close(vw); clear cleanupObj; close(fig);
fprintf('[system3d] regime %d %s day %d: hold 45 C  plain %.1f h  PCM+B0 %.1f h  PCM+%s %.1f h (12-evening mean %.1f h) -> %s\n', ...
    regime, ctrl, day, tau(1), tau(2), ctrl, tau(3), mean(tau3), file);
end

% ------------------------------------------------------------------------
function sc = build_scene(ax, hasPcm, ncap)
hold(ax, 'on'); axis(ax, 'equal', 'off');
xlim(ax, [-6.5 1.6]); ylim(ax, [-1.6 1.6]); zlim(ax, [-0.4 5.2]);
H = 2.4; Rt = 1; N = 10; dz = H / N;
[cx, cy, cz] = cylinder(Rt, 48);
sc.lay = gobjects(N, 1);
for i = 1:N
    sc.lay(i) = surf(ax, cx, cy, cz * dz + (i - 1) * dz, 'EdgeColor', 'none', 'FaceAlpha', 0.30, 'FaceColor', [0.4 0.6 0.9]);
end
th = linspace(0, 2 * pi, 48);
for i = 0:N, plot3(ax, Rt * cos(th), Rt * sin(th), i * dz * ones(size(th)), '-', 'Color', [0.65 0.65 0.65], 'LineWidth', 0.5); end
sc.lid = fill3(ax, Rt * cos(th), Rt * sin(th), H * ones(size(th)), [0.4 0.6 0.9], 'FaceAlpha', 0.30, 'EdgeColor', 'k');
sc.base = fill3(ax, Rt * cos(th), Rt * sin(th), zeros(size(th)), [0.4 0.6 0.9], 'FaceAlpha', 0.30, 'EdgeColor', 'k');
text(ax, 1.15, 0, H - 0.1, 'top', 'FontSize', 8, 'Color', [0.4 0.4 0.4]);  text(ax, 1.15, 0, 0.1, 'bottom', 'FontSize', 8, 'Color', [0.4 0.4 0.4]);
sc.caps = gobjects(0);  sc.capNode = [];
if hasPcm
    [sx, sy, sz] = sphere(8); rc = 0.10;
    for i = 1:N
        m = min(ncap(i), 6);
        for q = 1:m
            ang = 2 * pi * (q - 1) / max(m, 1);
            sc.caps(end+1) = surf(ax, 0.55 * cos(ang) + rc * sx, 0.55 * sin(ang) + rc * sy, (i - 0.5) * dz + rc * sz, 'EdgeColor', 'none', 'FaceColor', [0.25 0.45 0.9]); %#ok<AGROW>
            sc.capNode(end+1) = i; %#ok<AGROW>
        end
    end
end
ca = deg2rad(30);  zt = 0.4 + 2.3 * sin(ca);
sc.coll = patch(ax, 'XData', [-5.0 -2.7 -2.7 -5.0]', 'YData', [-1 -1 1 1]', 'ZData', [0.4 zt zt 0.4]', 'FaceColor', [0.95 0.9 0.5], 'EdgeColor', [0.3 0.3 0.3], 'LineWidth', 1.5, 'FaceLighting', 'none');
sc.X1 = plot3(ax, [-5.0 -2.7], [-1 1], [0.4 zt], 'r-', 'LineWidth', 5, 'Visible', 'off');
sc.X2 = plot3(ax, [-5.0 -2.7], [1 -1], [0.4 zt], 'r-', 'LineWidth', 5, 'Visible', 'off');
sc.hotPath = [-2.7 0 zt; -1.4 0 2.2; -1.0 0 2.1];
sc.coldPath = [-1.0 0 0.35; -1.5 0 0.15; -4.2 0 0.15; -5.0 0 0.4];
sc.pipeHot = plot3(ax, sc.hotPath(:, 1), sc.hotPath(:, 2), sc.hotPath(:, 3), '-', 'LineWidth', 3, 'Color', [0.6 0.6 0.6]);
sc.pipeCold = plot3(ax, sc.coldPath(:, 1), sc.coldPath(:, 2), sc.coldPath(:, 3), '-', 'LineWidth', 3, 'Color', [0.6 0.6 0.6]);
[px, py, pz] = sphere(10);
sc.pump = surf(ax, -2.6 + 0.2 * px, 0.2 * py, 0.15 + 0.2 * pz, 'EdgeColor', 'none', 'FaceColor', [0.6 0.6 0.6]);
sc.blade = plot3(ax, [-2.6 -2.6], [0 0.3], [0.15 0.15], 'k-', 'LineWidth', 2.5);
text(ax, -2.9, 0, -0.3, 'pump', 'FontSize', 9);  text(ax, -4.4, 0, zt + 0.5, 'collector', 'FontSize', 9, 'Color', [0.3 0.3 0.3]);
sc.pH = plot3(ax, nan(8, 1), nan(8, 1), nan(8, 1), 'o', 'MarkerSize', 5, 'MarkerFaceColor', [0.9 0.2 0.1], 'MarkerEdgeColor', 'none');
sc.pC = plot3(ax, nan(8, 1), nan(8, 1), nan(8, 1), 'o', 'MarkerSize', 5, 'MarkerFaceColor', [0.2 0.4 0.9], 'MarkerEdgeColor', 'none');
sc.rays = gobjects(5, 1);
for r = 1:5, sc.rays(r) = plot3(ax, [-6.2 -4.2 + (r - 3) * 0.35], [0 (r - 3) * 0.35], [4.6 1.9 + (r - 3) * 0.12], '-', 'Color', [1 0.8 0.1], 'LineWidth', 1); end
sc.sun = surf(ax, -6.2 + 0.35 * px, 0.35 * py, 4.6 + 0.35 * pz, 'EdgeColor', 'none', 'FaceColor', [1 0.85 0.1]);
sc.draw = plot3(ax, [0.6 1.5], [0 0], [2.1 2.4], '-', 'LineWidth', 5, 'Color', [0.8 0.8 0.8]);
text(ax, 1.0, 0, 2.7, 'hot water', 'FontSize', 8, 'Color', [0.7 0.15 0.15]);
sc.cold = plot3(ax, [1.5 0.9], [0 0], [0.3 0.3], '-', 'LineWidth', 4, 'Color', [0.3 0.6 0.9]);
text(ax, 1.0, 0, 0.0, 'cold water', 'FontSize', 8, 'Color', [0.1 0.3 0.8]);
lighting(ax, 'gouraud'); camlight(ax, 'headlight'); view(ax, 25, 18);
set(sc.coll, 'FaceLighting', 'none');
sc.phase = 0;
end

function update_scene(sc, Tl, hl, P, hasPcm, Qc, ghi, bypass, sunOn, draw, pumpOn, s)
for i = 1:10, set(sc.lay(i), 'FaceColor', tcol(Tl(i))); end
set(sc.lid, 'FaceColor', tcol(Tl(10)));  set(sc.base, 'FaceColor', tcol(Tl(1)));
if hasPcm && ~isempty(sc.caps)
    Ts = P(9);  Tlq = P(10);  Lh = P(11);  cps = P(12);  x = P(14);
    hs = (cps + x) * Ts;  span = Lh + x * (Tlq - Ts);
    for c = 1:numel(sc.caps)
        f = min(max((hl(sc.capNode(c)) - hs) / span, 0), 1);
        set(sc.caps(c), 'FaceColor', (1 - f) * [0.25 0.45 0.9] + f * [1 0.55 0.05]);
    end
end
g = min(max(Qc / 1500, 0), 1);
set(sc.coll, 'FaceColor', ternary(bypass, [0.75 0.75 0.75], (1 - g) * [0.95 0.9 0.5] + g * [1 0.5 0.05]));
set(sc.X1, 'Visible', ternary(bypass, 'on', 'off'));  set(sc.X2, 'Visible', ternary(bypass, 'on', 'off'));
set(sc.pump, 'FaceColor', ternary(pumpOn, [0.1 0.8 0.2], [0.6 0.6 0.6]));
set(sc.pipeHot, 'Color', ternary(pumpOn, [0.9 0.3 0.1], [0.6 0.6 0.6]));
set(sc.pipeCold, 'Color', ternary(pumpOn, [0.2 0.4 0.9], [0.6 0.6 0.6]));
vis = ternary(sunOn, 'on', 'off');
for r = 1:numel(sc.rays), set(sc.rays(r), 'Visible', vis, 'LineWidth', 0.5 + 3 * min(ghi / 1000, 1)); end
set(sc.sun, 'FaceColor', ternary(sunOn, [1 0.85 0.1], [0.5 0.5 0.5]));
set(sc.draw, 'Color', ternary(draw > 0.05, [0.2 0.7 0.9], [0.8 0.8 0.8]), 'LineWidth', 1 + 5 * min(draw / 20, 1));
% moving water particles and the spinning pump blade (animation phase advances with the sub-frame)
if pumpOn
    ph = mod(sc.phase + 0.0, 1);                                  %#ok<NASGU>
    q = (0:7)' / 8;
    sH = mod(q + 0.12 * s + 0.03 * rem(round(Qc), 7), 1);  sC = mod(q + 0.12 * s + 0.03 * rem(round(Qc), 7), 1);
    [x, y, z] = along3(sc.hotPath, sH);  set(sc.pH, 'XData', x, 'YData', y, 'ZData', z, 'Visible', 'on');
    [x, y, z] = along3(sc.coldPath, sC); set(sc.pC, 'XData', x, 'YData', y, 'ZData', z, 'Visible', 'on');
    ang = 0.9 * s + 1.7 * rem(round(Qc), 5);
else
    set(sc.pH, 'Visible', 'off');  set(sc.pC, 'Visible', 'off');  ang = 0;
end
set(sc.blade, 'XData', [-2.6 -2.6 + 0.3 * sin(ang)], 'YData', [0 0.3 * cos(ang)], 'ZData', [0.15 0.15]);
end

function [x, y, z] = along3(path, s)
seg = sqrt(sum(diff(path).^2, 2));  cum = [0; cumsum(seg)];  d = s * cum(end);
x = interp1(cum, path(:, 1), d);  y = interp1(cum, path(:, 2), d);  z = interp1(cum, path(:, 3), d);
end

function c = tcol(T)
t = min(max((T - 25) / 50, 0), 1);
c = [t, 0.35 * (1 - abs(2 * t - 1)) + 0.1, 1 - t];
c = min(max(c, 0), 1);
end

function m = tmap()
t = linspace(0, 1, 64)';
m = [t, 0.35 * (1 - abs(2 * t - 1)) + 0.1, 1 - t];
m = min(max(m, 0), 1);
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
