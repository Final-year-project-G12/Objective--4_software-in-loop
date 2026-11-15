function animate_tank3d(Lh, K, file, labelFcn, titleStr)
%ANIMATE_TANK3D  3-D cutaway of the Uttarakhand tank, animated from the twin's 1-D results (Rajasthan's animate_tank3d.m,
% adapted to the plant struct K).
%
%   animate_tank3d(Lh, K, file, labelFcn, titleStr)
%     Lh        struct with Tnodes, hnodes [(H+1 or H) x N]: node water temperature [C] and PCM enthalpy [J/kg] per hour
%     K         plant struct (capsules per node, PCM properties)
%     file      output video (MPEG-4; Motion JPEG AVI where MPEG-4 is not available)
%     labelFcn  @(k) caption for frame k (default: hold caption '+k h after 18:00 ...')
%
% Water layers are coloured by node temperature, capsules by node melt fraction. THIS IS A 3-D VIEW OF A 1-D RESULT:
% nothing is solved in 3-D, and the capsule positions are an illustrative ring layout (capsule count per layer is the
% twin's own). Unlike the single-node Tamil Nadu twin, the 10 layers are real (they differ).
N = K.N; n = size(Lh.Tnodes, 1);
if nargin < 4 || isempty(labelFcn)
    labelFcn = @(k) sprintf('+%d h after 18:00   top %.1f \\circC   bottom %.1f \\circC', k - 1, Lh.Tnodes(k, N), Lh.Tnodes(k, 1));
end
if nargin < 5, titleStr = ''; end
Rt = 1; Hn = 1;
ncap = round(K.n_caps(:)');
Ts = K.P(9); Tl = K.P(10); L = K.P(11); cps = K.P(12); x = K.P(14);
hs = (cps + x) * Ts; span = L + x * (Tl - Ts);

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
for i = 1:N
    plot3(ax, Rt * cos(th), Rt * sin(th), (i - 1) * Hn * ones(size(th)), '-', 'Color', [0.6 0.6 0.6]);
end
plot3(ax, Rt * cos(th), Rt * sin(th), N * Hn * ones(size(th)), 'k-');
[sx, sy, sz] = sphere(12);
rc = 0.17;
hC = {}; nodeOf = [];
for i = 1:N
    m = ncap(i);
    for q = 1:m
        ring = 1 + (q > 9);                                    % up to 9 capsules on the outer ring, the rest inside
        nr = ternary(ring == 1, min(m, 9), m - 9); qi = ternary(ring == 1, q, q - 9);
        ang = 2 * pi * (qi - 1) / max(nr, 1) + (ring - 1) * 0.35;
        rad = ternary(ring == 1, 0.62, 0.28) * Rt;
        z0 = (i - 0.5) * Hn;
        hC{end+1} = surf(ax, rad * cos(ang) + rc * sx, rad * sin(ang) + rc * sy, z0 + rc * sz, 'EdgeColor', 'none', 'FaceColor', [0.3 0.5 0.9]); %#ok<AGROW>
        nodeOf(end+1) = i; %#ok<AGROW>
    end
end
lighting(ax, 'gouraud'); camlight(ax, 'headlight');
hT = text(ax, 0, 0, N * Hn + 1.2, '', 'HorizontalAlignment', 'center', 'FontSize', 13, 'FontWeight', 'bold');
if ~isempty(titleStr)
    text(ax, 0, 0, N * Hn + 2.2, titleStr, 'HorizontalAlignment', 'center', 'FontSize', 12, 'Interpreter', 'none');
end
text(ax, 0, 0, -0.9, '3-D view of a 1-D result: layer temperatures and capsule melt fractions from the twin; capsule layout illustrative', ...
    'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);
cb = colorbar(ax, 'Location', 'eastoutside'); colormap(ax, tmap()); clim(ax, [10 75]); cb.Label.String = 'water temperature [\circC]';

[fdir, fname] = fileparts(file);
try
    vw = VideoWriter(file, 'MPEG-4');
catch
    file = fullfile(fdir, [fname '.avi']); vw = VideoWriter(file, 'Motion JPEG AVI');
end
vw.FrameRate = 20; open(vw);
cleanup = onCleanup(@() close(vw));
nsub = 6;
for k = 1:n
    for i = 1:N
        set(hL(i), 'FaceColor', tcol(Lh.Tnodes(k, i)));
        fm = min(max((Lh.hnodes(k, i) - hs) / span, 0), 1);
        for c = find(nodeOf == i)
            set(hC{c}, 'FaceColor', (1 - fm) * [0.25 0.45 0.9] + fm * [1.0 0.55 0.05]);
        end
    end
    set(hT, 'String', labelFcn(k));
    for s = 1:nsub
        view(ax, 30 + 360 * ((k - 1) * nsub + s) / (n * nsub), 22);
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

function m = tmap()
t = linspace(0, 1, 64)';
m = [t, 0.35 * (1 - abs(2 * t - 1)) + 0.1, 1 - t];
m = min(max(m, 0), 1);
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
