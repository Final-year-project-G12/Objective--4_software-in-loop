function T = four_arm_2023(regime)
%FOUR_ARM_2023  Three-arm comparison plus the Objective 3 SAC as a fourth arm, 2023, 1-hour steps.
%
%   T = four_arm_2023(1);   % writes ../export_r<regime>/four_arm_2023.csv, .json and .png (three_arm_2023.* is not touched)
%
% Arms: 1_plain_B0 (water-only tank of the same 50 L, always-charge), 2_pcm_B0 (always-charge under the in-plant shield),
% 3_pcm_DQN (the released DQN; in regimes 0 and 2 it always charges, so it equals arm 2), 4_pcm_SAC (the SAC actor Objective 3's annual-only
% rule selects for the regime, export_r<k>/sac_actor_r<k>.json). Columns as three_arm_2023.csv; guard-band hours are the comparable safety
% number (shield activations are counted per node and sub-step in this kernel). Also the percent of B0 delivery (annual and window) and the
% shield-hour cut against B0, the two numbers Objective 3's selection rule uses, so the O4 table can be read against Objective 3's.
if nargin < 1 || isempty(regime), regime = 1; end
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = fullfile(here, '..', sprintf('export_r%d', regime));
tw = load_twin_params(outDir, 2023);
assert(isfield(tw, 'sac'), 'export_r%d/sac_actor_r%d.json missing', regime, regime);
W = tw.wx.signals.values(:, 1:4);
P = tw.P;  Pp = make_plain_tank(P);
arms = {'1_plain_B0', Pp, 1; '2_pcm_B0', P, 1; '3_pcm_DQN', P, 0; '4_pcm_SAC', P, 2};
solar_kWh = sum(W(:, 2)) * P(36) / 1000;
rows = {};  L = cell(4, 1);
for a = 1:4
    L{a} = simulate_hours(tw, W, arms{a, 2}, arms{a, 3}, 0, []);
end
win = (L{2}.hod >= 18) | (L{2}.hod < 9);
b0 = sum(L{2}.E_del_Wh) / 1000;  b0w = sum(L{2}.E_del_Wh(win)) / 1000;  b0g = sum(L{2}.shield_s) / 3600;
for a = 1:4
    d = sum(L{a}.E_del_Wh) / 1000;  u = sum(L{a}.E_unmet_Wh) / 1000;  dw = sum(L{a}.E_del_Wh(win)) / 1000;  g = sum(L{a}.shield_s) / 3600;
    rows(end+1, :) = {arms{a, 1}, d, u, sum(L{a}.n_sw + L{a}.n_sp), sum(L{a}.n_viol), 100 * d / solar_kWh, 100 * d / (d + u), g, dw, ...
        sum(L{a}.Q_coll_Wh) / 1000, 100 * d / b0, 100 * dw / b0w, 100 * (1 - g / b0g), sum(abs(diff([0; L{a}.a_cmd]) > 0)), ...
        sum(L{a}.a_cmd == 0), sum(L{a}.a_cmd == 1), sum(L{a}.a_cmd == 2)}; %#ok<AGROW>
end
T = cell2table(rows, 'VariableNames', {'arm', 'delivered_kWh', 'unmet_kWh', 'shields', 'hard_violations', 'thermal_efficiency_pct', ...
    'demand_coverage_pct', 'guard_band_h', 'window_kWh', 'collector_kWh', 'pct_of_B0_delivery', 'pct_of_B0_window', ...
    'shield_cut_vs_B0_pct', 'switches_to_non_charge', 'charge_hours', 'idle_hours', 'bypass_hours'});
writetable(T, fullfile(outDir, 'four_arm_2023.csv'));
J = struct('year', 2023, 'regime', regime, 'incident_solar_kWh', solar_kWh, 'sac_run', tw.sac.tag, 'sac_selection', tw.sac.selection, 'arms', table2struct(T));
fid = fopen(fullfile(outDir, 'four_arm_2023.json'), 'w'); fwrite(fid, jsonencode(J, 'PrettyPrint', true)); fclose(fid);
disp(T(:, {'arm', 'delivered_kWh', 'window_kWh', 'guard_band_h', 'pct_of_B0_delivery', 'shield_cut_vs_B0_pct', 'idle_hours', 'bypass_hours'}));

fig = figure('Visible', 'off', 'Position', [50 50 1250 420], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Four arms, 2023, Rajasthan regime %d: plain tank, PCM + B0, PCM + DQN, PCM + SAC', regime), 'FontWeight', 'bold');
lab = {'plain', 'PCM + B0', 'PCM + DQN', 'PCM + SAC'};  cols = [0.5 0.5 0.5; 0.85 0.33 0.1; 0 0.45 0.74; 0.47 0.67 0.19];
vars = {'delivered_kWh', 'window_kWh', 'guard_band_h', 'thermal_efficiency_pct'};
ttl = {'delivered [kWh]', 'window 18:00-09:00 [kWh]', 'guard-band hours', 'thermal efficiency [%]'};
for k = 1:4
    ax = nexttile(tl);  b = bar(ax, categorical(lab, lab), T.(vars{k}), 'FaceColor', 'flat');  b.CData = cols;
    title(ax, ttl{k}); grid(ax, 'on');
end
exportgraphics(fig, fullfile(outDir, 'four_arm_2023.png'), 'Resolution', 120); close(fig);
end
