function T = three_arm_2021(exportDir, year)
%THREE_ARM_2021  Objective 4 improvement-plan section 6.5: isolate what each
% objective contributes. Three arms, identical weather/demand/tank volume:
%   Arm 1  plain water, same TOTAL tank volume, pump always on (B0)      -- nobody
%   Arm 2  PCM tank (O1 material in O2 geometry/flow), always on (B0)    -- O1+O2
%   Arm 3  the same PCM tank, trained SAC policy                        -- O1+O2+O3
%
% Arm 1's water mass is m_w / (1 - fraction), where "fraction" is O2's own
% PCM-volume-fraction-of-tank (g10_selection_r<regime>.json, "fraction"
% field) -- i.e. the capsule volume is refilled with water so the tank
% still holds its full 100 L, not a partly-empty one. Decoupling is done by
% zeroing n_capsule (P(23)) so no water<->PCM heat path exists; the PCM
% state (m_pcm, etc.) is left in P but is thermally inert and ignored.
%
%   T = three_arm_2021('../export', 2021)
here = fileparts(mfilename('fullpath')); addpath(here);
if nargin < 1 || isempty(exportDir), exportDir = fullfile(here, '..', 'export'); end
if nargin < 2, year = 2021; end
tw = load_twin_params(exportDir, year);
W = tw.wx.signals.values;
n = size(W, 1);

g10 = jsondecode(fileread(fullfile(here, '..', '..', '..', 'objective2_design_optimization', 'results', 'g10_selection_r0.json')));
fraction = g10.chosen.fraction;
fprintf('[three_arm] O2 fraction (PCM volume / tank volume) = %.6f  (source: g10_selection_r0.json)\n', fraction);

P_pcm = tw.P;
P_plain = tw.P;
P_plain(1)  = tw.P(1) / (1 - fraction);   % m_w_kg -> full-tank water mass
P_plain(23) = 0;                           % n_capsule = 0 -> no water<->PCM heat path
fprintf('[three_arm] arm1 water mass %.3f kg (was %.3f kg, tank refilled to the same total volume)\n', P_plain(1), tw.P(1));

rng(11);
fprintf('[three_arm] running arm 1 (plain, B0) ...\n');
L1 = simulate_hours(tw, W, P_plain, 1, 0, []);
fprintf('[three_arm] running arm 2 (PCM, B0) ...\n');
L2 = simulate_hours(tw, W, P_pcm, 1, 0, []);
fprintf('[three_arm] running arm 3 (PCM, SAC) ...\n');
L3 = simulate_hours(tw, W, P_pcm, 0, 0, []);

A_coll = tw.params.A_coll_m2;
solar_kWh = sum(W(:, 2)) * A_coll / 1000;   % GHI [W/m2] summed over 1h steps -> Wh/m2 -> *A -> Wh -> kWh
fprintf('[three_arm] annual GHI on collector = %.1f kWh (A_coll = %.2f m^2)\n', solar_kWh, A_coll);

rows = {};
arms = {'1_plain_B0', L1; '2_pcm_B0', L2; '3_pcm_SAC', L3};
for i = 1:3
    nm = arms{i, 1}; L = arms{i, 2};
    deliv = sum(L.E_del_Wh) / 1000; unmet = sum(L.E_unmet_Wh) / 1000;
    shields = sum(L.n_sw + L.n_sp); viol = sum(L.n_viol);
    eff = 100 * deliv / solar_kWh; cov = 100 * deliv / (deliv + unmet);
    rows(end+1, :) = {nm, deliv, unmet, shields, viol, eff, cov}; %#ok<AGROW>
    fprintf('  %-12s delivered=%8.1f kWh  unmet=%7.1f kWh  shields=%6d  viol=%d  eff=%5.2f%%  coverage=%5.2f%%\n', ...
        nm, deliv, unmet, shields, viol, eff, cov);
end
T = cell2table(rows, 'VariableNames', {'arm', 'delivered_kWh', 'unmet_kWh', 'shields', 'hard_violations', 'thermal_efficiency_pct', 'demand_coverage_pct'});

fprintf('\n[three_arm] cross-check arm 3 against O3 nominal 2021 (docs/DEPLOYMENT_CONTROLLER.md): 1971.4 kWh, 18604 shields, 40.9%%\n');
fprintf('[three_arm] arm 3 measured:                                                           %.1f kWh, %d shields, %.2f%%\n', ...
    T.delivered_kWh(3), T.shields(3), T.thermal_efficiency_pct(3));

out.year = year; out.fraction = fraction; out.arms = table2struct(T);
out.solar_kWh_on_collector = solar_kWh;
fid = fopen(fullfile(exportDir, sprintf('three_arm_%d.json', year)), 'w');
fwrite(fid, jsonencode(out, 'PrettyPrint', true)); fclose(fid);
writetable(T, fullfile(exportDir, sprintf('three_arm_%d.csv', year)));
fprintf('[three_arm] written -> %s / three_arm_%d.{json,csv}\n', exportDir, year);

plot_three_arm(L1, L2, L3, fullfile(exportDir, sprintf('three_arm_%d.png', year)), year);
end

function plot_three_arm(L1, L2, L3, file, year)
n = numel(L1.Tw); d = (1:n)' / 24;
fig = figure('Visible', 'off', 'Position', [50 50 1150 700], 'Color', 'w');
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Three-arm comparison, %d (plain / PCM+B0 / PCM+SAC)', year), 'FontWeight', 'bold');

ax = nexttile(tl); hold(ax, 'on');
plot(ax, d, cumsum(L1.E_del_Wh)/1000, 'Color', [0.5 0.5 0.5], 'LineWidth', 1.2);
plot(ax, d, cumsum(L2.E_del_Wh)/1000, 'b:', 'LineWidth', 1.3);
plot(ax, d, cumsum(L3.E_del_Wh)/1000, 'b-', 'LineWidth', 1.5);
ylabel(ax, 'cumulative delivered [kWh]'); grid(ax, 'on'); xlim(ax, [0 n/24]);
legend(ax, {'arm1 plain B0', 'arm2 PCM B0', 'arm3 PCM SAC'}, 'Location', 'northwest');

ax = nexttile(tl); hold(ax, 'on');
plot(ax, d, cumsum(L1.n_sw + L1.n_sp), 'Color', [0.5 0.5 0.5], 'LineWidth', 1.2);
plot(ax, d, cumsum(L2.n_sw + L2.n_sp), 'r:', 'LineWidth', 1.3);
plot(ax, d, cumsum(L3.n_sw + L3.n_sp), 'r-', 'LineWidth', 1.5);
ylabel(ax, 'cumulative shield trips'); grid(ax, 'on'); xlim(ax, [0 n/24]);

ax = nexttile(tl); hold(ax, 'on');
plot(ax, d, L1.Tw, 'Color', [0.5 0.5 0.5]); plot(ax, d, L2.Tw, 'b:'); plot(ax, d, L3.Tw, 'b-');
ylabel(ax, 'T_w [\circC]'); xlabel(ax, 'day of year'); grid(ax, 'on'); xlim(ax, [0 n/24]);
exportgraphics(fig, file, 'Resolution', 110); close(fig);
end
