function T = three_arm_2023(regime)
%THREE_ARM_2023  Three-arm comparison over 2023 (joint plan section 2.1), Rajasthan / Tamil Nadu file layout.
%
%   T = three_arm_2023;      % regime 1; writes ../export_r1/three_arm_2023.csv, .json, .png
%
% Arms: arm1_plain_B0 (O2's water-only twin, same 50 L and flow, always-enable), arm2_pcm_B0 (O2's PureTemp 58 tank,
% always-enable under the in-plant shield = O2's operating point), arm3_pcm_PPO (same tank, Objective 3's recommended
% PPO + smart-persistence forecast). Replay year 2023 is an O3 VALIDATION year, on which the controller's seed was
% selected: this is a fidelity check, not an unbiased performance figure.
%   thermal_efficiency_pct = delivered (50 C) / incident solar on the collector (sum GHI x area)
%   demand_coverage_pct    = delivered / (delivered + unmet), at 50 C
if nargin < 1 || isempty(regime), regime = 1; end
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = twin_export_dir(regime);
tw = load_twin_params(outDir, 2023);
C = load_campaign(regime);
W = tw.wx.signals.values;
arms = arm_list(C);
solar_kWh = sum(W(:, 2)) * C.base.K.coll(1) / 1000;
rows = {}; Ms = cell(1, 3);
for a = 1:3
    L = simulate_hours(tw, W, arms{a, 2}, arms{a, 3}, 0, []);
    m = twin_metrics(L, arms{a, 2}, 0, arms{a, 4});  Ms{a} = m;
    rows(end+1, :) = {arms{a, 1}, m.E_del50_kWh, m.E_del45_kWh, m.E_unmet50_kWh, m.E_del50_win_kWh, m.E_del45_win_kWh, ...
        m.guard_band_h, m.shield_activations, m.hours_over_hard_limit, 100 * m.E_del50_kWh / solar_kWh, ...
        100 * m.E_del50_kWh / (m.E_del50_kWh + m.E_unmet50_kWh), m.Q_coll_kWh, m.melt_cycles_per_year, m.pump_run_h, ...
        m.E_del50_per_m2_kWh, m.E_del50_per_kgPCM_kWh, m.bypass_hours}; %#ok<AGROW>
end
T = cell2table(rows, 'VariableNames', {'arm', 'delivered50_kWh', 'delivered45_kWh', 'unmet50_kWh', 'window50_kWh', 'window45_kWh', ...
    'guard_band_h', 'shield_activations', 'hours_over_hard_limit', 'thermal_efficiency_pct', 'demand_coverage_pct', ...
    'collector_kWh', 'melt_cycles', 'pump_run_h', 'kWh50_per_m2', 'kWh50_per_kg_pcm', 'bypass_hours'});
writetable(T, fullfile(outDir, 'three_arm_2023.csv'));
J = struct('year', 2023, 'regime', regime, 'year_role', 'O3 validation year (controller seed selected on it)', ...
    'incident_solar_kWh', solar_kWh, 'collector_m2', C.base.K.coll(1), 'pcm_mass_kg', C.base.pcm_mass_kg, ...
    'arms', table2struct(T), 'metrics', struct('arm1', Ms{1}, 'arm2', Ms{2}, 'arm3', Ms{3}));
fid = fopen(fullfile(outDir, 'three_arm_2023.json'), 'w'); fwrite(fid, jsonencode(J, 'PrettyPrint', true)); fclose(fid);
disp(T(:, 1:11));

fig = figure('Visible', 'off', 'Position', [50 50 1300 420], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 1, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Three arms, 2023, Uttarakhand regime %d (50 L, %.1f m^2): plain tank, PCM + B0, PCM + PPO', regime, C.base.K.coll(1)), 'FontWeight', 'bold');
lab = {'plain', 'PCM + B0', 'PCM + PPO'}; cols = [0.5 0.5 0.5; 0.85 0.33 0.1; 0 0.45 0.74];
vars = {'delivered50_kWh', 'window50_kWh', 'guard_band_h', 'thermal_efficiency_pct'};
ttl = {'delivered to 50 \circC [kWh]', 'window 18-09 h, 50 \circC [kWh]', 'guard-band (shield) hours', 'thermal efficiency [%]'};
for k = 1:4
    ax = nexttile(tl); b = bar(ax, categorical(lab, lab), T.(vars{k}), 'FaceColor', 'flat'); b.CData = cols;
    title(ax, ttl{k}); grid(ax, 'on');
    text(ax, 1:3, T.(vars{k}), compose('%.1f', T.(vars{k})), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom');
end
exportgraphics(fig, fullfile(outDir, 'three_arm_2023.png'), 'Resolution', 120); close(fig);
end

function arms = arm_list(C)
arms = {'arm1_plain_B0', C.water_only, 1, 0; 'arm2_pcm_B0', C.base.K, 1, C.base.pump_power_w; ...
        'arm3_pcm_PPO', C.base.K, 0, C.base.pump_power_w};
end
