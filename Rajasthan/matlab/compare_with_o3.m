function T = compare_with_o3()
%COMPARE_WITH_O3  The O4 twin against Objective 3's own year-2023 results, controller by controller (read-only use of Objective 3's files).
%
%   T = compare_with_o3;   % writes ../results_campaign/o3_crosscheck_2023.csv
%
% Objective 3 scores every policy in its Python environment (PCMEnv); the O4 twin re-implements that environment in MATLAB. For the same
% weather year (2023, a validation year) the two must agree. Rows compared, all initial PCM state "solid", no domain randomisation:
%   water-only twin, B0 (always-charge) and B1 (reactive rule, untuned)   <- results/phase4_comparison_r<k>.csv, all three regimes
%   DQN regime 1 (dqn_r1_w1.7_s42, the released DQN)                      <- results/gen2/gen2_results_dqn.csv
%   SAC regimes 0, 1, 2 (the runs export_from_python.py --algo sac exports) <- results/rerun_2026-11-13/gen2/ (0, 2) and results/gen2/ (1)
% Columns: delivered energy to 45 C [kWh], delivered in the 18:00-09:00 window [kWh], guard-band hours (Objective 3: shield_water_h +
% shield_pcm_h; O4: shield_s / 3600), and the largest difference. "diff" should be ~0 (rounding in the 10x10 solve).
here = fileparts(mfilename('fullpath')); addpath(here);
o3 = fullfile(here, '..', '..', '..', 'solar-pcm-control--Objective3', 'rajasthan', 'results');
assert(isfolder(o3), 'Objective 3 results folder not found: %s', o3);
outDir = fullfile(here, '..', 'results_campaign');
rows = {};
for regime = 0:2
    tw = load_twin_params(fullfile(here, '..', sprintf('export_r%d', regime)), 2023);
    W = tw.wx.signals.values(:, 1:4);  P = tw.P;
    C = readtable(fullfile(o3, sprintf('phase4_comparison_r%d.csv', regime)));
    C = C(C.year == 2023 & strcmp(C.pcm_init, 'solid'), :);
    items = {'TWIN_water_only', 'water-only B0', make_plain_tank(P), 1; 'B0_fixed_charge', 'B0', P, 1; 'B1_reactive_rule', 'B1', P, 3};
    for k = 1:size(items, 1)
        o = C(strcmp(C.policy, items{k, 1}), :);
        L = simulate_hours(tw, W, items{k, 3}, items{k, 4}, 0, []);
        rows(end+1, :) = make_row(regime, items{k, 2}, o, L); %#ok<AGROW>
    end
    % trained controllers
    if regime == 1
        D = readtable(fullfile(o3, 'gen2', 'gen2_results_dqn.csv'));
        o = D(strcmp(D.tag, 'dqn_r1_w1.7_s42_V3_60min_dr') & D.year == 2023 & strcmp(D.pcm_init, 'solid'), :);
        rows(end+1, :) = make_row(regime, 'DQN (released)', o, simulate_hours(tw, W, P, 0, 0, [])); %#ok<AGROW>
    end
    if isfield(tw, 'sac')
        if regime == 1, f = fullfile(o3, 'gen2', 'gen2_results_sac.csv'); else, f = fullfile(o3, 'rerun_2026-11-13', 'gen2', 'gen2_results_sac.csv'); end
        S = readtable(f);
        o = S(strcmp(S.tag, tw.sac.tag) & S.year == 2023 & strcmp(S.pcm_init, 'solid'), :);
        rows(end+1, :) = make_row(regime, ['SAC (' tw.sac.tag ')'], o, simulate_hours(tw, W, P, 2, 0, [])); %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'regime', 'policy', 'O3_E45_kWh', 'O4_E45_kWh', 'diff_E45_kWh', 'O3_window_kWh', 'O4_window_kWh', ...
    'diff_window_kWh', 'O3_guard_h', 'O4_guard_h', 'diff_guard_h', 'O3_switches', 'O4_switches_to_non_charge'});
writetable(T, fullfile(outDir, 'o3_crosscheck_2023.csv'));
disp(T(:, {'regime', 'policy', 'O3_E45_kWh', 'O4_E45_kWh', 'diff_E45_kWh', 'diff_window_kWh', 'diff_guard_h'}));
fprintf('[compare_with_o3] largest |difference|: E45 %.3g kWh, window %.3g kWh, guard-band hours %.3g h\n', ...
    max(abs(T.diff_E45_kWh)), max(abs(T.diff_window_kWh)), max(abs(T.diff_guard_h)));
end

function r = make_row(regime, name, o, L)
win = (L.hod >= 18) | (L.hod < 9);
e45 = sum(L.E_del_Wh) / 1000;  ew = sum(L.E_del_Wh(win)) / 1000;  g = sum(L.shield_s) / 3600;
gO3 = o.shield_water_h + o.shield_pcm_h;
% Objective 3's "bypass_switches" counts hours the policy changed to or from non-charge; the O4 count here is changes away from CHARGE
sw4 = sum(diff([0; L.a_policy]) > 0);
r = {regime, name, o.total_delivered_kWh, e45, e45 - o.total_delivered_kWh, o.E_del45_window_kWh, ew, ew - o.E_del45_window_kWh, ...
    gO3, g, g - gO3, o.bypass_switches, sw4};
end
