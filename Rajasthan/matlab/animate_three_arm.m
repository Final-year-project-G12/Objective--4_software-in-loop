function animate_three_arm(L, file, titleStr, framesPerHour, Icut)
%ANIMATE_THREE_ARM  Side-by-side animated schematic of the three arms (plain tank, PCM + B0, PCM + DQN) on the same weather.
%
%   animate_three_arm({L1, L2, L3}, file, titleStr, framesPerHour, Icut)
%
% L1..L3 are logs from simulate_hours.m for the same hours (plain tank + B0, PCM tank + B0, PCM tank + DQN). Each tank is drawn in two
% bands (top-layer and bottom-layer temperature, so stratification shows), PCM capsules change colour with melt fraction (the plain tank
% is labelled "no PCM"), the pump is drawn running only when the collector adds heat (the fixed rule of animate_system.m), and the
% executed action and the cumulative delivered energy and shield trips are written under each tank. A trend strip shows the three
% top-layer temperatures with a time cursor. This is the Rajasthan counterpart of the Tamil Nadu three-arm day video; the drawing is
% schematic: nothing is solved in 2-D or 3-D, and the tank bands are a summary of 10 nodes.
if nargin < 3, titleStr = ''; end
if nargin < 4, framesPerHour = 3; end
if nargin < 5, Icut = 10; end
n = numel(L{1}.Tw);
armName = {'Plain tank + B0', 'PCM + B0 (no AI)', 'PCM + DQN'};
x0 = [4 54 104];
fig = figure('Visible', 'off', 'Position', [50 50 1280 720], 'Color', 'w');
try, theme(fig, 'light'); catch, end
ax = axes(fig, 'Position', [0.01 0.30 0.98 0.68]); hold(ax, 'on'); axis(ax, 'equal'); axis(ax, 'off'); xlim(ax, [0 150]); ylim(ax, [-14 70]);
th = linspace(0, 2 * pi, 30);
hUp = gobjects(3, 1);  hLo = gobjects(3, 1);  hPump = gobjects(3, 1);  hInfo = gobjects(3, 1);  hAct = gobjects(3, 1);
[cx, cy] = meshgrid(x0(1) + (4:8:32), 16:8:44);  nc = numel(cx);
hCap = cell(3, 1);
for a = 1:3
    xs = x0(a);
    hLo(a) = patch(ax, xs + [0 36 36 0], [12 12 29 29], [0.4 0.6 0.9], 'EdgeColor', 'none');
    hUp(a) = patch(ax, xs + [0 36 36 0], [29 29 46 46], [0.4 0.6 0.9], 'EdgeColor', 'none');
    plot(ax, xs + [0 36 36 0 0], [12 12 46 46 12], 'k-', 'LineWidth', 2);
    if a > 1
        hCap{a} = gobjects(nc, 1);
        for k = 1:nc
            hCap{a}(k) = patch(ax, xs + (cx(k) - x0(1)) + 2.4 * cos(th), cy(k) + 2.4 * sin(th), [0.3 0.5 0.9], 'EdgeColor', [0.15 0.15 0.15]);
        end
    else
        text(ax, xs + 18, 29, 'no PCM', 'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', [0.2 0.2 0.2], 'FontWeight', 'bold');
    end
    text(ax, xs + 18, 52, armName{a}, 'HorizontalAlignment', 'center', 'FontSize', 13, 'FontWeight', 'bold');
    plot(ax, xs + [18 18], [12 6], '-', 'Color', [0.6 0.6 0.6], 'LineWidth', 3);
    hPump(a) = patch(ax, xs + 18 + 3 * cos(th), 4 + 3 * sin(th), [0.7 0.7 0.7], 'EdgeColor', 'k', 'LineWidth', 1.2);
    text(ax, xs + 23, 4, 'pump', 'FontSize', 9);
    hAct(a) = text(ax, xs + 18, -1.5, '', 'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold');
    hInfo(a) = text(ax, xs, -4, '', 'VerticalAlignment', 'top', 'FontSize', 9, 'BackgroundColor', [1 1 1 0.7], 'EdgeColor', [0.7 0.7 0.7]);
end
hTitle = text(ax, 75, 68, titleStr, 'FontSize', 14, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
hSun = patch(ax, 8 + 5 * cos(th), 62 + 5 * sin(th), [1 0.85 0.1], 'EdgeColor', [1 0.6 0]);
hSky = text(ax, 16, 62, '', 'FontSize', 11, 'VerticalAlignment', 'middle');
hClock = text(ax, 140, 62, '', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');

ax2 = axes(fig, 'Position', [0.07 0.07 0.88 0.17]); hold(ax2, 'on'); box(ax2, 'on');
tt = (1:n)';  cc = {[0.4 0.4 0.4], [0.85 0.33 0.1], [0 0.45 0.74]};
for a = 1:3, plot(ax2, tt, L{a}.Tw, 'Color', cc{a}, 'LineWidth', 1.3); end
yline(ax2, 45, 'g--'); yline(ax2, 72, 'r--'); ylabel(ax2, 'top-layer T [\circC]'); xlabel(ax2, 'hour of the clip'); xlim(ax2, [1 n]); grid(ax2, 'on');
hCur = xline(ax2, 1, 'k-', 'LineWidth', 1.5);
legend(ax2, {'plain', 'PCM + B0', 'PCM + DQN'}, 'Location', 'northoutside', 'Orientation', 'horizontal');

vw = VideoWriter(file, 'MPEG-4'); vw.FrameRate = 8; open(vw);
cleanup = onCleanup(@() close(vw));
actName = {'CHARGE', 'IDLE', 'BYPASS'};
cumE = zeros(3, 1);  cumS = zeros(3, 1);
for t = 1:n
    I = L{1}.GHI(t);
    set(hSun, 'XData', 8 + (3 + 4 * min(I / 1000, 1.2)) * cos(th), 'YData', 62 + (3 + 4 * min(I / 1000, 1.2)) * sin(th));
    set(hSky, 'String', sprintf('GHI %4.0f W/m^2   ambient %4.1f \\circC   draw %4.1f kg/h', I, L{1}.T_amb(t), L{1}.draw_kg(t)));
    set(hClock, 'String', sprintf('%02d:00', mod(round(L{1}.hod(t)), 24)));
    for a = 1:3
        La = L{a};
        cumE(a) = cumE(a) + La.E_del_Wh(t);  cumS(a) = cumS(a) + La.n_sw(t) + La.n_sp(t);
        set(hUp(a), 'FaceColor', tcol(La.Tw(t)));  set(hLo(a), 'FaceColor', tcol(La.Tbot(t)));
        if a > 1
            capc = (1 - La.f_melt(t)) * [0.25 0.45 0.9] + La.f_melt(t) * [1 0.55 0.05];
            for k = 1:nc, set(hCap{a}(k), 'FaceColor', capc); end
        end
        pumpOn = (La.a_exec(t) == 0) && (La.n_sw(t) == 0) && (I > Icut) && (La.Q_coll_Wh(t) > 0);
        set(hPump(a), 'FaceColor', ternary(pumpOn, [0.25 0.75 0.35], [0.7 0.7 0.7]));
        st = actName{La.a_exec(t) + 1};
        if La.interlock(t) == 2, st = 'SENSOR FAULT: BYPASS'; end
        if (La.n_sw(t) + La.n_sp(t)) > 0, st = [st ' (shield)']; end %#ok<AGROW>
        set(hAct(a), 'String', st, 'Color', ternary(La.a_exec(t) == 0, [0.1 0.45 0.1], [0.75 0.15 0.15]));
        if a == 1
            pc = sprintf('PCM: none');
        else
            pc = sprintf('T_{PCM} %5.1f \\circC   melted %3.0f %%', La.Tpcm(t), 100 * La.f_melt(t));
        end
        set(hInfo(a), 'String', sprintf(' T_{top} %5.1f \\circC   T_{bottom} %5.1f \\circC\n %s\n collector %4.0f Wh   delivered %5.0f Wh\n shield trips (cum.) %d', ...
            La.Tw(t), La.Tbot(t), pc, La.Q_coll_Wh(t), cumE(a), cumS(a)));
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
t = min(max((T - 25) / 50, 0), 1);
c = [t, 0.35 * (1 - abs(2 * t - 1)) + 0.1, 1 - t];
c = min(max(c, 0), 1);
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
