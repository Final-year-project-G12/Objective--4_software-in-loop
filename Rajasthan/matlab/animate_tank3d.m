function animate_tank3d(Lh, P, file)
%ANIMATE_TANK3D  A 3-D cutaway of the tank, animated from the twin's 1-D results (plan option C2).
%
% Water layers are coloured by node temperature, capsules by node melt fraction. THIS IS A 3-D VIEW OF A
% 1-D RESULT: nothing is solved in 3-D, and the capsule positions are an illustrative ring layout.
%   Lh   struct with Tn, hn  [(H+1) x 10] node water temperature and PCM enthalpy per hour
%   P    plant parameter vector (node masses, capsules per node, PCM properties)
%   file output MP4
N = 10;
n = size(Lh.Tn, 1);
Rt = 1;  Hn = 1;                                          % unit radius, unit height per layer
ncap = round(P(61:70));
Ts = P(9);  Tl = P(10);  L = P(11);  cps = P(12);  x = P(14);
hs = (cps + x) * Ts;  span = L + x * (Tl - Ts);

fig = figure('Visible', 'off', 'Position', [50 50 900 720], 'Color', 'w');
try, theme(fig, 'light'); catch, end
ax = axes(fig); hold(ax, 'on'); axis(ax, 'equal', 'off');
xlim(ax, [-1.3 1.3]); ylim(ax, [-1.3 1.3]); zlim(ax, [0 N * Hn]);
[cx, cy, cz] = cylinder(Rt, 40);
hL = gobjects(N, 1);
for i = 1:N
    hL(i) = surf(ax, cx, cy, cz * Hn + (i - 1) * Hn, 'EdgeColor', 'none', 'FaceAlpha', 0.30, 'FaceColor', [0.4 0.6 0.9]);
end
th = linspace(0, 2 * pi, 40);
for i = 1:N                                               % thin ring lines between layers
    plot3(ax, Rt * cos(th), Rt * sin(th), (i - 1) * Hn * ones(size(th)), '-', 'Color', [0.6 0.6 0.6]);
end
plot3(ax, Rt * cos(th), Rt * sin(th), N * Hn * ones(size(th)), 'k-');
[sx, sy, sz] = sphere(12);
rc = 0.17;
hC = {};  nodeOf = [];
for i = 1:N
    m = ncap(i);
    for q = 1:m
        ang = 2 * pi * (q - 1) / max(m, 1);
        rad = 0.55 * Rt;
        if m > 6, rad = 0.58 * Rt; end
        cxy = [rad * cos(ang), rad * sin(ang)];
        z0 = (i - 0.5) * Hn;
        hC{end+1} = surf(ax, cxy(1) + rc * sx, cxy(2) + rc * sy, z0 + rc * sz, 'EdgeColor', 'none', 'FaceColor', [0.3 0.5 0.9]); %#ok<AGROW>
        nodeOf(end+1) = i; %#ok<AGROW>
    end
end
lighting(ax, 'gouraud'); camlight(ax, 'headlight');
hT = text(ax, 0, 0, N * Hn + 1.2, '', 'HorizontalAlignment', 'center', 'FontSize', 13, 'FontWeight', 'bold');
text(ax, 0, 0, -0.9, '3-D view of a 1-D result: layer temperatures and capsule melt fractions from the twin; capsule layout illustrative', ...
    'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);
cb = colorbar(ax, 'Location', 'eastoutside'); colormap(ax, tmap()); clim(ax, [25 75]); cb.Label.String = 'water temperature [\circC]';

vw = VideoWriter(file, 'MPEG-4'); vw.FrameRate = 20; open(vw);
cleanup = onCleanup(@() close(vw));
nsub = 6;
for k = 1:n
    for i = 1:N
        set(hL(i), 'FaceColor', tcol(Lh.Tn(k, i)));
        fm = min(max((Lh.hn(k, i) - hs) / span, 0), 1);
        for c = find(nodeOf == i)
            set(hC{c}, 'FaceColor', (1 - fm) * [0.25 0.45 0.9] + fm * [1.0 0.55 0.05]);
        end
    end
    set(hT, 'String', sprintf('+%d h after 18:00   top %.1f \\circC   bottom %.1f \\circC', k - 1, Lh.Tn(k, N), Lh.Tn(k, 1)));
    for s = 1:nsub
        view(ax, 30 + 360 * ((k - 1) * nsub + s) / (n * nsub), 22);
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

function m = tmap()
t = linspace(0, 1, 64)';
m = [t, 0.35 * (1 - abs(2 * t - 1)) + 0.1, 1 - t];
m = min(max(m, 0), 1);
end
