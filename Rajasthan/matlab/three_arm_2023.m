function T = three_arm_2023()
%THREE_ARM_2023  Three-arm comparison over 2023, 1-hour steps (Tamil Nadu scope item 2), in the Tamil Nadu file layout.
%
%   T = three_arm_2023;   % writes ../export_r1/three_arm_2023.csv, .json and .png
%
% Arms: 1_plain_B0 (water-only tank, same 50 L, always-charge), 2_pcm_B0 (PureTemp 60 tank, always-charge under the in-plant shield),
% 3_pcm_DQN (same tank, trained regime 1 DQN). Columns as export/three_arm_2021.csv of the Tamil Nadu twin:
%   shields               sum of shield activations (water side per sub-step + PCM side per node and sub-step; in this 10-node kernel
%                         the counts are in the hundred-thousands and are NOT comparable with the single-node twin's: use guard_band_h)
%   thermal_efficiency_pct   delivered kWh (45 C) / incident solar energy on the collector (sum of GHI x 1.5 m2)  [definition inferred from the
%                         Tamil Nadu numbers, 1853.5 kWh = 38.45 % of 4820 kWh]
%   demand_coverage_pct   delivered / (delivered + unmet)
% Extra columns: guard_band_h, window_kWh (18:00-09:00), collector_kWh.
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = fullfile(here, '..', 'export_r1');
tw = load_twin_params(outDir, 2023);
W = tw.wx.signals.values(:, 1:4);
P = tw.P;  Pp = make_plain_tank(P);
arms = {'1_plain_B0', Pp, 1; '2_pcm_B0', P, 1; '3_pcm_DQN', P, 0};
solar_kWh = sum(W(:, 2)) * P(36) / 1000;
rows = {};
for a = 1:3
    L = simulate_hours(tw, W, arms{a, 2}, arms{a, 3}, 0, []);
    win = (L.hod >= 18) | (L.hod < 9);
    d = sum(L.E_del_Wh) / 1000;  u = sum(L.E_unmet_Wh) / 1000;
    rows(end+1, :) = {arms{a, 1}, d, u, sum(L.n_sw + L.n_sp), sum(L.n_viol), 100 * d / solar_kWh, 100 * d / (d + u), ...
        sum(L.shield_s) / 3600, sum(L.E_del_Wh(win)) / 1000, sum(L.Q_coll_Wh) / 1000}; %#ok<AGROW>
end
T = cell2table(rows, 'VariableNames', {'arm', 'delivered_kWh', 'unmet_kWh', 'shields', 'hard_violations', 'thermal_efficiency_pct', ...
    'demand_coverage_pct', 'guard_band_h', 'window_kWh', 'collector_kWh'});
writetable(T, fullfile(outDir, 'three_arm_2023.csv'));
J = struct('year', 2023, 'regime', 1, 'incident_solar_kWh', solar_kWh, 'arms', table2struct(T));
fid = fopen(fullfile(outDir, 'three_arm_2023.json'), 'w'); fwrite(fid, jsonencode(J, 'PrettyPrint', true)); fclose(fid);
disp(T);

fig = figure('Visible', 'off', 'Position', [50 50 1200 420], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Three arms, 2023, Rajasthan regime 1 (50 L, 1.5 m^2): plain tank, PCM + B0, PCM + DQN', 'FontWeight', 'bold');
lab = {'plain', 'PCM + B0', 'PCM + DQN'};  cols = [0.5 0.5 0.5; 0.85 0.33 0.1; 0 0.45 0.74];
vars = {'delivered_kWh', 'unmet_kWh', 'guard_band_h', 'thermal_efficiency_pct'};
ttl = {'delivered [kWh]', 'unmet [kWh]', 'guard-band hours', 'thermal efficiency [%]'};
for k = 1:4
    ax = nexttile(tl);  b = bar(ax, categorical(lab, lab), T.(vars{k}), 'FaceColor', 'flat');  b.CData = cols;
    title(ax, ttl{k}); grid(ax, 'on');
end
exportgraphics(fig, fullfile(outDir, 'three_arm_2023.png'), 'Resolution', 120); close(fig);
end
