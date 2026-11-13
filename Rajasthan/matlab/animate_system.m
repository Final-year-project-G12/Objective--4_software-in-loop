function animate_system(L, file, titleStr, framesPerHour, Icut, stateText)
%ANIMATE_SYSTEM  Animated schematic of the Rajasthan solar PCM water heater driven by a
% simulation log L (from simulate_hours): sun and irradiance, collector, pump with
% moving water particles, bypass state, storage tank drawn as two bands (upper band
% coloured by the top-node temperature, lower band by the bottom-node temperature, so
% stratification is visible), PCM capsules that change colour with melt fraction,
% hot-water draw and cold make-up, plus a live trend strip. Written to an MP4.
%
% Same drawing as the Tamil Nadu twin; only the two-band tank and the labels differ.
if nargin < 3, titleStr = ''; end
if nargin < 4, framesPerHour = 4; end
if nargin < 5, Icut = 0; end      % collector cut-in irradiance [W/m^2]; pump idles below it
if nargin < 6, stateText = ''; end  % fixed caption instead of the controller action (retention animation)
n = numel(L.Tw);

fig = figure('Visible', 'off', 'Position', [50 50 1100 720], 'Color', 'w');
try, theme(fig, 'light'); catch, end      % R2025a+ follows the desktop theme; force light
ax = axes(fig, 'Position', [0.02 0.30 0.96 0.68]); hold(ax, 'on');
axis(ax, 'equal'); axis(ax, 'off'); xlim(ax, [0 100]); ylim(ax, [0 70]);

% ---- collector (tilted plate) ----
hCol = patch(ax, [6 40 44 10], [18 46 42 14], [0.80 0.88 0.95], 'EdgeColor', [0.2 0.3 0.4], 'LineWidth', 2);
patch(ax, [8 40 42 10], [18.5 44 42 16.5], [0.95 0.80 0.15], 'EdgeColor', 'none', 'FaceAlpha', 0.9);
hX = plot(ax, [10 40], [16 44], 'r-', 'LineWidth', 4, 'Visible', 'off');
hX2 = plot(ax, [10 40], [44 16], 'r-', 'LineWidth', 4, 'Visible', 'off');
text(ax, 15, 9.5, 'Solar collector', 'FontSize', 10, 'Color', [0.2 0.3 0.4]);

% ---- sun and rays ----
th = linspace(0, 2*pi, 40);
hSun = patch(ax, 12 + 5*cos(th), 61 + 5*sin(th), [1 0.85 0.1], 'EdgeColor', [1 0.6 0]);
hRays = gobjects(5, 1);
for k = 1:5
    hRays(k) = plot(ax, [18 18], [58 58], '-', 'Color', [1 0.75 0], 'LineWidth', 2);
end

% ---- storage tank + PCM capsules ----
hWaterB = patch(ax, [60 84 84 60], [10 10 29 29], [0.4 0.6 0.9], 'EdgeColor', 'none');   % lower half: bottom node
hWater  = patch(ax, [60 84 84 60], [29 29 48 48], [0.4 0.6 0.9], 'EdgeColor', 'none');   % upper half: top node
plot(ax, [60 84 84 60 60], [10 10 48 48 10], '-', 'Color', [0.2 0.2 0.2], 'LineWidth', 2);
[cx, cy] = meshgrid(64:5.2:82, 14:4.4:44);
nc = numel(cx); hCap = gobjects(nc, 1);
for k = 1:nc
    hCap(k) = patch(ax, cx(k) + 1.8*cos(th), cy(k) + 1.8*sin(th), [0.3 0.5 0.9], 'EdgeColor', [0.15 0.15 0.15]);
end
text(ax, 60, 50.5, 'Tank + PCM capsules', 'FontSize', 9);

% ---- pipes (supply = hot from collector, return = from tank via pump) ----
supply = [42 44; 42 52; 80 52; 80 48];
retn   = [72 10; 72 5; 12 5; 12 16];
hSup = plot(ax, supply(:, 1), supply(:, 2), '-', 'Color', [0.8 0.2 0.2], 'LineWidth', 5);
hRet = plot(ax, retn(:, 1), retn(:, 2), '-', 'Color', [0.95 0.55 0.1], 'LineWidth', 5);
hPump = patch(ax, 46 + 3.2*cos(th), 5 + 3.2*sin(th), [0.3 0.6 0.4], 'EdgeColor', 'k', 'LineWidth', 1.5);
hBlade = plot(ax, [46 49], [5 5], 'k-', 'LineWidth', 2);
text(ax, 43, 0.8, 'Pump', 'FontSize', 10);
np = 12; sup_s = (0:np-1)'/np; ret_s = (0:np-1)'/np;
hPS = scatter(ax, nan(np, 1), nan(np, 1), 36, 'r', 'filled');
hPR = scatter(ax, nan(np, 1), nan(np, 1), 36, 'r', 'filled');

% ---- outlet / inlet ----
hHot = quiver(ax, 84, 44, 12, 0, 0, 'Color', [0.85 0.15 0.15], 'LineWidth', 3, 'MaxHeadSize', 1.2);
quiver(ax, 98, 14, -14, 0, 0, 'Color', [0.1 0.3 0.8], 'LineWidth', 3, 'MaxHeadSize', 1.2);
text(ax, 86, 47, 'Hot water', 'FontSize', 10, 'Color', [0.85 0.15 0.15]);
text(ax, 86, 10.5, 'Cold water', 'FontSize', 10, 'Color', [0.1 0.3 0.8]);

hTitle = text(ax, 50, 68.5, titleStr, 'FontSize', 13, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
hInfo  = text(ax, 29, 26, '', 'FontSize', 9, 'VerticalAlignment', 'top', 'BackgroundColor', [1 1 1 0.75], 'EdgeColor', [0.7 0.7 0.7]);
hState = text(ax, 50, 57, '', 'FontSize', 12, 'FontWeight', 'bold', 'HorizontalAlignment', 'center');

% ---- trend strip ----
ax2 = axes(fig, 'Position', [0.07 0.07 0.88 0.18]); hold(ax2, 'on'); box(ax2, 'on');
tt = (1:n)' / 24;
yyaxis(ax2, 'left');
plot(ax2, tt, L.Tw, 'b-', 'LineWidth', 1.2); plot(ax2, tt, L.Tpcm, 'Color', [0.9 0.4 0], 'LineWidth', 1.2);
yline(ax2, 72, 'r--'); ylabel(ax2, 'T [\circC]');
yyaxis(ax2, 'right');
plot(ax2, tt, L.GHI, 'Color', [0.9 0.8 0.1]); ylabel(ax2, 'GHI [W/m^2]');
xlabel(ax2, 'day'); xlim(ax2, [0 n/24]);
hCur = xline(ax2, 0, 'k-', 'LineWidth', 1.5);
legend(ax2, {'T_{top}', 'T_{PCM}', '72 \circC shield', 'GHI'}, 'Location', 'northoutside', 'Orientation', 'horizontal');

vw = VideoWriter(file, 'MPEG-4'); vw.FrameRate = 20; open(vw);
cleanup = onCleanup(@() close(vw));
actName = {'CHARGE', 'IDLE', 'BYPASS'};
snapT = round(0.45 * n);      % a mid-event hour saved as a still image
for t = 1:n
    Tw = L.Tw(t); Tb = L.Tbot(t); Tp = L.Tpcm(t); fm = L.f_melt(t); I = L.GHI(t);
    % the pump is drawn as running only when the loop really circulates: CHARGE executed, above the cut-in
    % irradiance, and the collector actually adds heat (fix: it used to run whenever CHARGE was commanded)
    pumpOn = (L.a_exec(t) == 0) && ((L.n_sw(t) + 0) == 0) && (I > Icut) && (L.Q_coll_Wh(t) > 0);
    bypass = (L.a_exec(t) == 2) || L.interlock(t) >= 2;
    shield = (L.n_sw(t) + L.n_sp(t)) > 0;

    set(hWater, 'FaceColor', tcol(Tw)); set(hWaterB, 'FaceColor', tcol(Tb));
    capc = (1 - fm) * [0.25 0.45 0.9] + fm * [1.0 0.55 0.05];
    for k = 1:nc, set(hCap(k), 'FaceColor', capc); end
    set(hSun, 'XData', 12 + (3 + 4*min(I/1000, 1.2))*cos(th), 'YData', 61 + (3 + 4*min(I/1000, 1.2))*sin(th));
    for k = 1:5
        y0 = 54 - 4*k; len = 0.5 + 8*min(I/1000, 1.2);
        set(hRays(k), 'XData', [20 20 + len], 'YData', [y0 + 3 y0 - 1], 'LineWidth', 0.5 + 2.5*min(I/1000, 1), ...
            'Visible', onoff(I > 10));
    end
    set(hX, 'Visible', onoff(bypass)); set(hX2, 'Visible', onoff(bypass));
    set(hCol, 'FaceColor', ternary(bypass, [0.75 0.75 0.75], [0.80 0.88 0.95]));
    set(hSup, 'Color', tcol(Tw + min(20, I/45)), 'LineStyle', ternary(pumpOn, '-', ':'));
    set(hRet, 'Color', tcol(Tb), 'LineStyle', ternary(pumpOn, '-', ':'));
    set(hPump, 'FaceColor', ternary(pumpOn, [0.25 0.75 0.35], [0.7 0.7 0.7]));
    set(hHot, 'LineWidth', 0.5 + 4 * min(L.draw_kg(t) / 50, 1), 'Visible', onoff(L.draw_kg(t) > 0.5));
    st = sprintf('%s%s', actName{L.a_exec(t) + 1}, ternary(shield, '  (safety shield active)', ''));
    if L.interlock(t) == 2, st = 'SENSOR FAULT -> fail-safe BYPASS'; end
    if L.interlock(t) == 3, st = 'HARD-LIMIT FAULT LATCHED'; end
    if ~isempty(stateText), st = stateText; end
    set(hState, 'String', st, 'Color', ternary(shield || L.interlock(t) >= 2, [0.8 0.1 0.1], [0.1 0.4 0.1]));
    set(hInfo, 'String', sprintf(' day %d  %02d:00\n GHI %4.0f W/m^2   T_{amb} %4.1f \\circC\n T_{top} %4.1f \\circC   T_{bottom} %4.1f \\circC\n T_{PCM} %4.1f \\circC   PCM melted %3.0f %%\n draw %4.1f kg/h   delivered %4.0f Wh', ...
        floor((t-1)/24) + 1, mod(round(L.hod(t)), 24), I, L.T_amb(t), Tw, Tb, Tp, 100*fm, L.draw_kg(t), L.E_del_Wh(t)));
    set(hCur, 'Value', t/24);

    for sub = 1:framesPerHour
        if pumpOn
            sup_s = mod(sup_s + 0.05, 1); ret_s = mod(ret_s + 0.05, 1);
            ang = 0.9 * sub;
        else
            ang = 0;
        end
        [px, py] = along(supply, sup_s); set(hPS, 'XData', px, 'YData', py, 'CData', tcol(Tw + min(20, I/45)), 'Visible', onoff(pumpOn));
        [px, py] = along(retn, ret_s);   set(hPR, 'XData', px, 'YData', py, 'CData', tcol(Tb), 'Visible', onoff(pumpOn));
        set(hBlade, 'XData', [46 46 + 3*cos(ang)], 'YData', [5 5 + 3*sin(ang)]);
        drawnow limitrate;
        fr = getframe(fig);
        writeVideo(vw, fr);
        if t == snapT && sub == framesPerHour, imwrite(fr.cdata, strrep(file, '.mp4', '_frame.png')); end
    end
end
close(vw); clear cleanup;
close(fig);
end

% ----------------------------------------------------------------------
function c = tcol(T)
t = min(max((T - 25) / 50, 0), 1);
c = [t, 0.35 * (1 - abs(2*t - 1)) + 0.1, 1 - t];
c = min(max(c, 0), 1);
end

function [x, y] = along(path, s)
seg = sqrt(sum(diff(path).^2, 2)); cum = [0; cumsum(seg)]; d = s * cum(end);
x = interp1(cum, path(:, 1), d); y = interp1(cum, path(:, 2), d);
end

function s = onoff(b)
if b, s = 'on'; else, s = 'off'; end
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
