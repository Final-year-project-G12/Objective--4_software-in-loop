function make_system_diagram(regime)
%MAKE_SYSTEM_DIAGRAM  Flow diagram of the Uttarakhand PCM solar water heater as it is modelled in O2-O4, with the AI
% controller and sensors. All numbers are read from the twin's own files (plant_params.json, campaign_cases.json).
%
%   make_system_diagram        % -> ../pictures/system_diagram_uttarakhand.png and .pdf
if nargin < 1 || isempty(regime), regime = 1; end
here = fileparts(mfilename('fullpath')); addpath(here);
xdir = twin_export_dir(regime);
pp = jsondecode(fileread(fullfile(xdir, 'plant_params.json')));
yr = jsondecode(fileread(fullfile(xdir, 'three_arm_2023.json')));
C = load_campaign(regime); K = C.base.K; d = C.design;
ncap = round(K.n_caps(:)'); N = K.N;

fig = figure('Visible', 'off', 'Units', 'pixels', 'Position', [0 0 1500 950], 'Color', 'w');
try, theme(fig, 'light'); catch, end
ax = axes(fig, 'Position', [0 0 1 1]); hold(ax, 'on'); axis(ax, 'off', 'equal'); xlim(ax, [0 15.6]); ylim(ax, [0 9.5]);
red = [0.85 0.1 0.1]; blue = [0.1 0.3 0.85]; org = [0.95 0.5 0.1]; dash = [0.25 0.25 0.25];
arrow = @(x, y, c, w) quiver(ax, x(1), y(1), x(2) - x(1), y(2) - y(1), 0, 'Color', c, 'LineWidth', w, 'MaxHeadSize', 0.6 / max(norm([x(2)-x(1) y(2)-y(1)]), 0.1));
lbl = @(x, y, s, varargin) text(ax, x, y, s, 'FontSize', 12, varargin{:});

% ---- sun and radiation ----
th = linspace(0, 2 * pi, 60);
fill(ax, 1.3 + 0.55 * cos(th), 8.3 + 0.55 * sin(th), [1 0.8 0.1], 'EdgeColor', [0.95 0.6 0]);
for k = 0:11, a = k * pi / 6; plot(ax, 1.3 + [0.7 0.95] * cos(a), 8.3 + [0.7 0.95] * sin(a), '-', 'Color', [0.95 0.65 0], 'LineWidth', 2); end
for k = 0:2, arrow([2.0 + 0.4 * k, 3.0 + 0.4 * k], [7.6 - 0.5 * k, 6.7 - 0.5 * k], [0.95 0.7 0.1], 2); end
lbl(0.3, 6.6, {'Solar radiation', sprintf('(ERA5, %d)', pp.year)}, 'Color', [0.55 0.4 0]);

% ---- collector (tilted) ----
cx = [2.6 5.6 6.1 3.1]; cy = [3.8 7.0 6.6 3.4];
fill(ax, cx, cy, [0.85 0.9 0.95], 'EdgeColor', [0.3 0.3 0.4], 'LineWidth', 2);
for k = 1:7, t = k / 8; plot(ax, [2.85 + 3 * t, 3.35 + 3 * t] - 0.25, [3.6 + 3.2 * t, 3.2 + 3.2 * t] + 0.2, '-', 'Color', [0.15 0.2 0.5], 'LineWidth', 4); end
lbl(3.2, 7.25, {'Flat-plate collector', sprintf('%.1f m^2,  F_R(\\tau\\alpha) %.2f,  F_RU_L %.1f W/m^2K', pp.collector.area_m2, pp.collector.fr_tau_alpha, pp.collector.fr_ul_W_m2K)}, 'FontSize', 10.5);

% ---- tank: 10 layers, capsules in the PCM layers ----
tx = 8.2; ty = 1.3; tw = 2.2; th_ = 4.6; hL = th_ / N;
for i = 1:N
    t = (i - 1) / (N - 1);
    rectangle(ax, 'Position', [tx ty + (i - 1) * hL tw hL], 'FaceColor', (1 - t) * [0.75 0.85 1] + t * [1 0.75 0.7], 'EdgeColor', [1 1 1]);
    for q = 1:ncap(i)
        r = 0.075; xc = tx + tw * q / (ncap(i) + 1); yc = ty + (i - 0.5) * hL;
        rectangle(ax, 'Position', [xc - r yc - r 2 * r 2 * r], 'Curvature', 1, 'FaceColor', [0.95 0.6 0.15], 'EdgeColor', [0.4 0.25 0]);
    end
end
rectangle(ax, 'Position', [tx ty tw th_], 'EdgeColor', 'k', 'LineWidth', 2.5, 'Curvature', 0.05);
lbl(tx - 0.1, ty - 0.45, {sprintf('Storage tank %.0f L, %d stratified layers', 50, N)}, 'FontWeight', 'bold');
lbl(tx + tw + 1.9, 3.55, {sprintf('PCM capsules: %s', C.chosen_pcm), sprintf('%d spheres, R %.1f mm, %s', d.N, 1000 * d.R_in_m, d.arrangement), ...
    sprintf('%.1f %% of volume, %.1f kg, melts %.0f-%.0f \\circC', 100 * d.fraction, yr.pcm_mass_kg, K.P(9), K.P(10))}, 'FontSize', 10.5);
arrow([tx + tw + 1.85, tx + tw - 0.25], [3.6, 3.0], [0.4 0.25 0], 1.5);

% ---- piping: collector out (hot) -> tank top, tank bottom -> pump -> flow meter -> collector in ----
plot(ax, [5.85 7.2 7.2], [6.8 6.8 ty + th_ - 0.4], '-', 'Color', red, 'LineWidth', 3);
arrow([7.2 tx], [ty + th_ - 0.4, ty + th_ - 0.4], red, 3);
plot(ax, [tx 6.6], [ty + 0.35 ty + 0.35], '-', 'Color', org, 'LineWidth', 3);
arrow([6.6 5.2], [ty + 0.35 ty + 0.35], org, 3);
fill(ax, 4.75 + 0.42 * cos(th), ty + 0.35 + 0.42 * sin(th), [0.2 0.65 0.35], 'EdgeColor', 'k', 'LineWidth', 1.5);
lbl(4.25, ty - 0.35, {'Pump', sprintf('%.3f kg/s', d.flow)}, 'FontWeight', 'bold');
plot(ax, [4.33 2.85 2.85], [ty + 0.35 ty + 0.35 3.55], '-', 'Color', org, 'LineWidth', 3);
rectangle(ax, 'Position', [2.7 1.95 0.3 0.75], 'FaceColor', [0.9 0.9 0.9], 'EdgeColor', 'k', 'LineWidth', 1.2);
lbl(1.0, 2.3, 'Flow meter');
% bypass valve on the collector return
fill(ax, 7.2 + 0.25 * [-1 1 1 -1], 6.15 + 0.25 * [-1 1 -1 1], 'w', 'EdgeColor', 'k', 'LineWidth', 1.5);
lbl(6.88, 5.85, {'Valve', '(ENABLE / BYPASS)'}, 'FontSize', 9.5, 'HorizontalAlignment', 'right');

% ---- hot out / cold in ----
arrow([tx + tw, tx + tw + 1.6], [ty + th_ - 0.2, ty + th_ - 0.2], red, 3);
lbl(tx + tw + 1.7, ty + th_ - 0.2, {'Hot water to household', sprintf('target %.0f \\circC, O2 daily draw profile', pp.T_target_C)}, 'Color', red);
arrow([tx + tw + 1.6, tx + tw], [ty + 0.2, ty + 0.2], blue, 3);
lbl(tx + tw + 1.7, ty + 0.2, sprintf('Cold mains water %.1f \\circC', pp.T_mains_C), 'Color', blue);

% ---- sensors ----
rectangle(ax, 'Position', [6.4 8.15 0.6 0.3], 'Curvature', 0.6, 'FaceColor', [0.95 0.95 0.95], 'EdgeColor', 'k');
lbl(6.0, 8.85, 'Pyranometer (GHI)', 'FontWeight', 'bold');
rectangle(ax, 'Position', [9.6 8.0 0.45 0.6], 'FaceColor', [0.85 0.85 0.85], 'EdgeColor', 'k');
lbl(10.2, 8.3, 'Ambient temperature sensor', 'FontWeight', 'bold');
plot(ax, [7.0 9.6], [8.3 8.3], ':', 'Color', dash, 'LineWidth', 1.5);
for yy = [ty + th_ - 0.25, ty + th_ / 2, ty + 0.25]
    plot(ax, tx - 0.05, yy, 'o', 'MarkerSize', 7, 'MarkerFaceColor', [1 0.2 0.2], 'MarkerEdgeColor', 'k');
end
lbl(7.45, ty + th_ / 2 - 0.05, {'Temperature sensors', '(top, PCM, bottom)'}, 'FontSize', 9.5, 'HorizontalAlignment', 'right');
for yy = [ty + th_ - 0.25, ty + th_ / 2, ty + 0.25], plot(ax, [7.95 tx - 0.05], [yy yy], ':', 'Color', dash, 'LineWidth', 1.5); end
plot(ax, [7.95 7.95 11.4], [ty + 0.25 6.55 6.55], ':', 'Color', dash, 'LineWidth', 1.5);                     % tank sensors -> controller

% ---- controller ----
bx = 11.4; by = 6.3;
rectangle(ax, 'Position', [bx by 3.4 1.6], 'Curvature', 0.1, 'FaceColor', [1 0.96 0.88], 'EdgeColor', [0.64 0.07 0.25], 'LineWidth', 2);
text(ax, bx + 0.15, by + 1.5, 'AI controller (O3, runs every hour)', 'FontSize', 11.5, 'FontWeight', 'bold', 'Color', [0.64 0.07 0.25], 'VerticalAlignment', 'top');
text(ax, bx + 0.15, by + 1.12, {sprintf('PPO + smart sunlight forecast, %d inputs', pp.n_obs), 'microcontroller-ready C code, 0.24 ms / decision', ...
    sprintf('safety interlock: guard %.0f \\circC water / %.0f \\circC PCM', pp.guard_water_C, pp.guard_pcm_C), 'fail-safe on sensor loss'}, 'FontSize', 9.5, 'VerticalAlignment', 'top');
plot(ax, [9.83 9.83 bx + 1.7 bx + 1.7], [8.0 7.97 7.97 by + 1.6], ':', 'Color', dash, 'LineWidth', 1.5);  % sensors -> controller
plot(ax, [bx 7.6 7.6], [7.05 7.05 6.15], '-', 'Color', [0.64 0.07 0.25], 'LineWidth', 1.8);                 % command line
arrow([7.6 7.47], [6.15 6.15], [0.64 0.07 0.25], 1.8);                                                       % -> valve
plot(ax, [7.6 7.6 4.75], [6.15 2.65 2.65], '-', 'Color', [0.64 0.07 0.25], 'LineWidth', 1.4);
arrow([4.75 4.75], [2.65 ty + 0.8], [0.64 0.07 0.25], 1.4);                                                  % -> pump
text(ax, 8.2, 7.25, 'command: ENABLE / BYPASS (valve + pump)', 'FontSize', 9.5, 'Color', [0.64 0.07 0.25], 'FontWeight', 'bold');
lbl(0.25, 0.35, sprintf(['Uttarakhand regime UK %d (medoid %s). Same system in O2 (design), O3 (training) and O4 (MATLAB/Simulink twin). ' ...
    'Schematic, not to scale.'], regime, strrep(pp.medoid, '_', '\_')), 'FontSize', 9.5, 'Color', [0.35 0.35 0.35]);
title(ax, '');
out = fullfile(here, '..', 'pictures');
exportgraphics(fig, fullfile(out, 'system_diagram_uttarakhand.png'), 'Resolution', 150);
exportgraphics(fig, fullfile(out, 'system_diagram_uttarakhand.pdf'), 'ContentType', 'vector');
close(fig);
fprintf('[diagram] written to %s\n', out);
end
