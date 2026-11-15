function animate_three_arm(L, file, titleStr, framesPerHour)
%ANIMATE_THREE_ARM  Side-by-side animated schematic of the three arms (plain tank, PCM + B0, PCM + PPO) on the same
% weather; the Uttarakhand counterpart of Rajasthan's / Tamil Nadu's three-arm day video.
%
%   animate_three_arm({L1, L2, L3}, file, titleStr, framesPerHour)
%
% Each tank is drawn as its 10 kernel nodes (colour = node temperature, so stratification shows); PCM capsules change
% colour with melt fraction. PUMP FIX: the pump is drawn running only when the loop actually circulated in that hour
% AND the collector added heat (pump_frac > 0 and Q_coll > 0), never merely because ENABLE was commanded
% (check_pump_drawing.m counts the hours the old rule got wrong). Schematic only: nothing is solved in 2-D or 3-D.
% MPEG-4 on Windows / macOS; Motion JPEG AVI elsewhere.
if nargin < 3, titleStr = ''; end
if nargin < 4, framesPerHour = 3; end
n = numel(L{1}.T_top); N = size(L{1}.Tnodes, 2);
armName = {'Plain tank + B0', 'PCM + B0 (no AI)', 'PCM + PPO'};
x0 = [4 54 104];
fig = figure('Visible', 'off', 'Position', [50 50 1280 720], 'Color', 'w');
try, theme(fig, 'light'); catch, end
ax = axes(fig, 'Position', [0.01 0.30 0.98 0.68]); hold(ax, 'on'); axis(ax, 'equal'); axis(ax, 'off'); xlim(ax, [0 150]); ylim(ax, [-14 70]);
th = linspace(0, 2 * pi, 30);
hNode = cell(3, 1); hPump = gobjects(3, 1); hInfo = gobjects(3, 1); hAct = gobjects(3, 1); hCap = cell(3, 1);
[cx, cy] = meshgrid(4:8:32, 16:8:44); nc = numel(cx);
dz = 34 / N;
for a = 1:3
    xs = x0(a);
    hNode{a} = gobjects(N, 1);
    for i = 1:N
        yb = 12 + (i - 1) * dz;
        hNode{a}(i) = patch(ax, xs + [0 36 36 0], [yb yb yb + dz yb + dz], [0.4 0.6 0.9], 'EdgeColor', 'none');
    end
    plot(ax, xs + [0 36 36 0 0], [12 12 46 46 12], 'k-', 'LineWidth', 2);
    if a > 1
        hCap{a} = gobjects(nc, 1);
        for k = 1:nc
            hCap{a}(k) = patch(ax, xs + cx(k) + 2.2 * cos(th), cy(k) + 2.2 * sin(th), [0.3 0.5 0.9], 'EdgeColor', [0.15 0.15 0.15]);
        end
    else
        text(ax, xs + 18, 29, 'no PCM', 'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', [0.95 0.95 0.95], 'FontWeight', 'bold');
    end
    text(ax, xs + 18, 52, armName{a}, 'HorizontalAlignment', 'center', 'FontSize', 13, 'FontWeight', 'bold');
    plot(ax, xs + [18 18], [12 6], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 3);
    hPump(a) = patch(ax, xs + 18 + 3 * cos(th), 4 + 3 * sin(th), [0.7 0.7 0.7], 'EdgeColor', 'k', 'LineWidth', 1.2);
    text(ax, xs + 23, 4, 'pump', 'FontSize', 9);
    hAct(a) = text(ax, xs + 18, -1.5, '', 'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold');
    hInfo(a) = text(ax, xs, -4, '', 'VerticalAlignment', 'top', 'FontSize', 9, 'BackgroundColor', [1 1 1 0.7], 'EdgeColor', [0.7 0.7 0.7]);
end
text(ax, 75, 68, titleStr, 'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Interpreter', 'none');
hSun = patch(ax, 8 + 5 * cos(th), 62 + 5 * sin(th), [1 0.85 0.1], 'EdgeColor', [1 0.6 0]);
hSky = text(ax, 16, 62, '', 'FontSize', 11, 'VerticalAlignment', 'middle');
hClock = text(ax, 140, 62, '', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');

ax2 = axes(fig, 'Position', [0.07 0.07 0.88 0.17]); hold(ax2, 'on'); box(ax2, 'on');
tt = (1:n)'; cc = {[0.4 0.4 0.4], [0.85 0.33 0.1], [0 0.45 0.74]};
for a = 1:3, plot(ax2, tt, L{a}.T_top, 'Color', cc{a}, 'LineWidth', 1.3); end
yline(ax2, 50, 'g--'); yline(ax2, 72, 'r--'); ylabel(ax2, 'top-layer T [\circC]'); xlabel(ax2, 'hour of the clip'); xlim(ax2, [1 n]); grid(ax2, 'on');
hCur = xline(ax2, 1, 'k-', 'LineWidth', 1.5);
legend(ax2, {'plain', 'PCM + B0', 'PCM + PPO'}, 'Location', 'northoutside', 'Orientation', 'horizontal');

[fdir, fname] = fileparts(file);
try
    vw = VideoWriter(file, 'MPEG-4');
catch
    file = fullfile(fdir, [fname '.avi']); vw = VideoWriter(file, 'Motion JPEG AVI');
end
vw.FrameRate = 8; open(vw);
cleanup = onCleanup(@() close(vw));
cumE = zeros(3, 1); cumS = zeros(3, 1);
for t = 1:n
    I = L{1}.GHI(t);
    rs = 3 + 4 * min(I / 1000, 1.2);
    set(hSun, 'XData', 8 + rs * cos(th), 'YData', 62 + rs * sin(th));
    set(hSky, 'String', sprintf('GHI %4.0f W/m^2   ambient %4.1f \\circC   draw %4.1f kg/h', I, L{1}.T_amb(t), L{1}.draw_kg(t)));
    set(hClock, 'String', sprintf('%02d:00', mod(round(L{1}.hod(t)), 24)));
    for a = 1:3
        La = L{a};
        cumE(a) = cumE(a) + La.E_del_Wh(t); cumS(a) = cumS(a) + (La.shield_w_s(t) + La.shield_p_s(t)) / 3600;
        for i = 1:N, set(hNode{a}(i), 'FaceColor', tcol(La.Tnodes(t, i))); end
        if a > 1
            capc = (1 - La.f_melt(t)) * [0.25 0.45 0.9] + La.f_melt(t) * [1 0.55 0.05];
            for k = 1:nc, set(hCap{a}(k), 'FaceColor', capc); end
        end
        pumpOn = La.pump_frac(t) > 0 && La.Q_coll_Wh(t) > 0;          % the fixed rule
        set(hPump(a), 'FaceColor', ternary(pumpOn, [0.25 0.75 0.35], [0.7 0.7 0.7]));
        if La.a_cmd(t) == 0, st = 'BYPASS'; elseif pumpOn, st = sprintf('ENABLE, loop %3.0f %%', 100 * La.pump_frac(t)); else, st = 'ENABLE, loop idle'; end
        if La.interlock(t) == 2, st = 'SENSOR FAULT: B0'; end
        if (La.shield_w_s(t) + La.shield_p_s(t)) > 0, st = [st ' (shield)']; end %#ok<AGROW>
        set(hAct(a), 'String', st, 'Color', ternary(La.a_cmd(t) == 1, [0.1 0.45 0.1], [0.75 0.15 0.15]));
        if a == 1, pc = 'PCM: none'; else, pc = sprintf('T_{PCM} %5.1f \\circC   melted %3.0f %%', La.Tpcm(t), 100 * La.f_melt(t)); end
        set(hInfo(a), 'String', sprintf(' T_{top} %5.1f \\circC   T_{bottom} %5.1f \\circC\n %s\n collector %4.0f Wh   delivered(50) %5.0f Wh\n shield hours (cum.) %.2f', ...
            La.T_top(t), La.T_bottom(t), pc, La.Q_coll_Wh(t), cumE(a), cumS(a)));
    end
    set(hCur, 'Value', t);
    for sub = 1:framesPerHour
        drawnow limitrate;
        writeVideo(vw, getframe(fig));
    end
end
close(vw); clear cleanup; close(fig);
end

function c = tcol(T)
t = min(max((T - 10) / 65, 0), 1);
c = [t, 0.35 * (1 - abs(2 * t - 1)) + 0.1, 1 - t];
c = min(max(c, 0), 1);
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
