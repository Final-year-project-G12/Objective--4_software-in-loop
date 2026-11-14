function T = run_o3_sensor_faults()
%RUN_O3_SENSOR_FAULTS  Objective 3's seven observation faults (phase 9) run on the O4 twin, for B0, the DQN and the SAC.
%
%   T = run_o3_sensor_faults;   % writes ../results_campaign/o3_sensor_faults.csv and o3_sensor_faults_vs_o3_dqn_r1.csv
%
% The fault set is the one in solar-pcm-control--Objective3/rajasthan/scripts/phase9_deployment_metrics.py (observation only; the
% physics and the in-plant shield see the true state):
%   nominal            no fault
%   pyranometer_dead   GHI field = 0
%   pyranometer_stuck  GHI field = 0.5 (reads 500 W/m2 day and night)
%   water_sensor_bias_p2C   top-water temperature +2 C
%   sensor_noise_2pct  the 13 contract fields multiplied by (1 + N(0, 0.02))
%   pcm_sensor_dropout T_pcm and f_melt frozen at their first values (estimator frozen)
%   combined           dead pyranometer + bias +2 C + 2 % noise
% Year 2023 only (an Objective 3 validation year; the twin replays 2023). Regime 1 is run with B0, DQN and SAC; regimes 0 and 2 with B0 and
% SAC (their released DQN always charges, so it equals B0). For the DQN in regime 1 the result is compared with Objective 3's own
% results/phase9_sensor_faults_r1.csv (2023 rows): the deterministic faults (nominal, dead, stuck, bias, PCM dropout) should agree to
% the digit; the two noisy ones (2 % noise, combined) cannot, because NumPy and MATLAB draw different random numbers (this file uses
% rng(2023 + fault index); Objective 3 used numpy default_rng([year, fault index])).
% Interlock note: the O4 interlock reads the true measured temperatures, as the plant shield does in Objective 3.
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = fullfile(here, '..', 'results_campaign');
faults = {'nominal', 'pyranometer_dead', 'pyranometer_stuck', 'water_sensor_bias_p2C', 'sensor_noise_2pct', 'pcm_sensor_dropout', 'combined'};
rows = {};
for regime = [1 0 2]
    tw = load_twin_params(fullfile(here, '..', sprintf('export_r%d', regime)), 2023);
    W = tw.wx.signals.values(:, 1:4);
    if regime == 1, ctrls = {'B0', 'DQN', 'SAC'}; else, ctrls = {'B0', 'SAC'}; end
    for c = ctrls
        mode = find(strcmp(c{1}, {'DQN', 'B0', 'SAC'})) - 1;
        for f = 1:numel(faults)
            rng(2023 + f);
            L = simulate_hours(tw, W, tw.P, mode, 0, [], [], NaN, fault_fcn(faults{f}));
            win = (L.hod >= 18) | (L.hod < 9);
            rows(end+1, :) = {regime, c{1}, faults{f}, sum(L.E_del_Wh) / 1000, sum(L.E_del_Wh(win)) / 1000, sum(L.shield_s) / 3600, ...
                sum(L.n_viol), sum(L.n_viol > 0), max(L.Tw_max), sum(L.a_cmd ~= 0), sum(L.interlock >= 2)}; %#ok<AGROW>
        end
        fprintf('[o3 faults] regime %d %-3s done\n', regime, c{1});
    end
end
T = cell2table(rows, 'VariableNames', {'regime', 'controller', 'fault', 'E_del45_kWh', 'E_del45_window_kWh', 'guard_band_h', ...
    'violations', 'hours_over_hard_limit', 'T_top_max_C', 'not_charge_hours', 'interlock_failsafe_hours'});
% change against the same controller's nominal run
T.d_E_del45_pct = nan(height(T), 1);  T.d_guard_band_h = nan(height(T), 1);
for i = 1:height(T)
    j = find(T.regime == T.regime(i) & strcmp(T.controller, T.controller{i}) & strcmp(T.fault, 'nominal'), 1);
    T.d_E_del45_pct(i) = 100 * (T.E_del45_kWh(i) / T.E_del45_kWh(j) - 1);
    T.d_guard_band_h(i) = T.guard_band_h(i) - T.guard_band_h(j);
end
writetable(T, fullfile(outDir, 'o3_sensor_faults.csv'));

% comparison with Objective 3's own phase 9 table (DQN, regime 1, 2023)
o3f = fullfile(here, '..', '..', '..', 'solar-pcm-control--Objective3', 'rajasthan', 'results', 'phase9_sensor_faults_r1.csv');
if isfile(o3f)
    O = readtable(o3f);
    O = O(strcmp(O.policy, 'DQN') & O.year == 2023, :);
    C = table();
    for f = 1:numel(faults)
        a = T(T.regime == 1 & strcmp(T.controller, 'DQN') & strcmp(T.fault, faults{f}), :);
        o = O(strcmp(O.fault, faults{f}), :);
        C = [C; table(faults(f), a.E_del45_kWh, o.E45_kWh, a.E_del45_kWh - o.E45_kWh, a.guard_band_h, o.shield_h, a.guard_band_h - o.shield_h, ...
            a.T_top_max_C, o.t_top_max_C, 'VariableNames', {'fault', 'O4_E45_kWh', 'O3_E45_kWh', 'diff_E45_kWh', 'O4_shield_h', 'O3_shield_h', ...
            'diff_shield_h', 'O4_Ttop_max_C', 'O3_Ttop_max_C'})]; %#ok<AGROW>
    end
    writetable(C, fullfile(outDir, 'o3_sensor_faults_vs_o3_dqn_r1.csv'));
    disp(C);
end
end

% ----------------------------------------------------------------------
function f = fault_fcn(name)
% obs = f(obs, t), observation index (MATLAB, 1-based): 1 T_top, 4 T_pcm, 5 f_melt, 6 GHI (O3 0-based 0, 3, 4, 5)
first = [];
f = @apply;
    function o = apply(o, t)
        if any(strcmp(name, {'pyranometer_dead', 'combined'})), o(6) = 0; end
        if strcmp(name, 'pyranometer_stuck'), o(6) = 0.5; end
        if any(strcmp(name, {'water_sensor_bias_p2C', 'combined'})), o(1) = o(1) + 2 / 40; end
        if any(strcmp(name, {'sensor_noise_2pct', 'combined'})), o(1:13) = o(1:13) .* (1 + 0.02 * randn(13, 1)); end
        if strcmp(name, 'pcm_sensor_dropout')
            if t == 1 || isempty(first), first = [o(4) o(5)]; end
            o(4) = first(1);  o(5) = first(2);
        end
    end
end
