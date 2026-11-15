function R = run_sensor_faults(regime)
%RUN_SENSOR_FAULTS  20-seed confidence intervals of the sensor-fault case + full-year pyranometer faults
% (joint plan section 1 "Extras" and section 2.5).
%
%   R = run_sensor_faults;   % regime 1; writes ../results_campaign/sensor_fault_seeds.csv, pyranometer_year.csv,
%                            %   pyranometer_seeds.csv, sensor_faults_summary.json
%
% A. sensor_fault scenario (April 2023 window, noise + 1 % dropout + 12 h blackout at the start of the event),
%    seeds 1..20, PCM + B0 and PCM + PPO: mean and 95 % CI (Student t, 19 dof) of event delivery and shield hours.
% B. full year 2023, ideal other sensors: healthy, dead (0), stuck 500, stuck 1000 W/m2, B0 and PPO. Does the
%    interlock react? (It has no irradiance plausibility rule; fail-safe = interlock state >= 2.)
% C. dead / stuck pyranometer on the April window with noisy other sensors, 20 seeds, PPO.
if nargin < 1 || isempty(regime), regime = 1; end
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = fullfile(here, '..', 'results_campaign'); if ~isfolder(outDir), mkdir(outDir); end
tw = load_twin_params(twin_export_dir(regime), 2023);
C = load_campaign(regime); K = C.base.K;
[sc, inEv, nWin] = edge_scenarios(tw, K);
sf = sc(strcmp({sc.name}, 'sensor_fault'));
tcrit = 2.093; ci = @(x) tcrit * std(x) / sqrt(numel(x));

% ---- A. 20 seeds, sensor fault ----
Q = zeros(40, 7); q = 0;
for seed = 1:20
    for pm = [0 1]
        rng(seed);
        L = simulate_hours(tw, sf.W, K, pm, 1, sf.blackout, struct('n', nWin));
        q = q + 1;
        Q(q, :) = [seed, pm, sum(L.E_del_Wh(inEv)) / 1000, sum(L.E_del_Wh(inEv & L.in_window > 0.5)) / 1000, ...
            sum(L.shield_w_s(inEv) + L.shield_p_s(inEv)) / 3600, sum(L.interlock >= 2), sum(L.over_limit_s) / 3600];
    end
end
S = array2table(Q, 'VariableNames', {'seed', 'is_B0', 'E_del50_event_kWh', 'E_del50_window_event_kWh', 'shield_h_event', ...
    'failsafe_hours', 'hours_over_limit'});
writetable(S, fullfile(outDir, 'sensor_fault_seeds.csv'));
nm = {'PPO', 'B0'};
for pm = [0 1]
    s = S(S.is_B0 == pm, :);
    A.(nm{pm + 1}) = struct('E_del50_event_mean', mean(s.E_del50_event_kWh), 'E_del50_event_ci95', ci(s.E_del50_event_kWh), ...
        'shield_h_mean', mean(s.shield_h_event), 'shield_h_ci95', ci(s.shield_h_event), ...
        'failsafe_h_mean', mean(s.failsafe_hours), 'failsafe_h_min', min(s.failsafe_hours), 'failsafe_h_max', max(s.failsafe_hours), ...
        'hours_over_limit_max', max(s.hours_over_limit));
    fprintf('[sensor fault, 20 seeds] %-3s delivered(event) %.2f +/- %.2f kWh   shield %.2f +/- %.2f h   fail-safe %.1f h (%d-%d)\n', nm{pm + 1}, ...
        mean(s.E_del50_event_kWh), ci(s.E_del50_event_kWh), mean(s.shield_h_event), ci(s.shield_h_event), ...
        mean(s.failsafe_hours), min(s.failsafe_hours), max(s.failsafe_hours));
end
R.sensor_fault_20_seeds = A;

% ---- B. full year, pyranometer faults ----
W = tw.wx.signals.values;
rows = {}; Ls = struct();
faults = {'healthy', NaN; 'dead_0', 0; 'stuck_500', 500; 'stuck_1000', 1000};
for pm = [1 0]
    for f = 1:size(faults, 1)
        L = simulate_hours(tw, W, K, pm, 0, [], struct('stuck', faults{f, 2}));
        m = twin_metrics(L, K);
        Ls.(nm{pm + 1}).(faults{f, 1}) = L;
        rows(end+1, :) = {nm{pm + 1}, faults{f, 1}, m.E_del50_kWh, m.E_del50_win_kWh, m.E_del45_kWh, m.guard_band_h, ...
            m.hours_over_hard_limit, sum(L.interlock == 1), m.failsafe_hours, m.bypass_hours}; %#ok<AGROW>
    end
end
Y = cell2table(rows, 'VariableNames', {'controller', 'pyranometer', 'E_del50_kWh', 'E_del50_window_kWh', 'E_del45_kWh', ...
    'guard_band_h', 'hours_over_hard_limit', 'interlock_guard_hours', 'interlock_failsafe_hours', 'bypass_hours'});
writetable(Y, fullfile(outDir, 'pyranometer_year.csv'));
disp(Y);
for f = 2:size(faults, 1)
    R.year_PPO_action_changed_hours.(faults{f, 1}) = sum(Ls.PPO.(faults{f, 1}).a_cmd ~= Ls.PPO.healthy.a_cmd);
end
R.year_B0_max_hourly_change_Wh = max(abs(Ls.B0.dead_0.E_del_Wh - Ls.B0.healthy.E_del_Wh));

% ---- C. pyranometer faults on the April window, noisy other sensors, 20 seeds, PPO ----
Q = zeros(80, 6); q = 0;
for seed = 1:20
    for f = 1:size(faults, 1)
        rng(seed);
        L = simulate_hours(tw, sc(1).W, K, 0, 1, false(nWin, 1), struct('n', nWin, 'stuck', faults{f, 2}));
        q = q + 1;
        Q(q, :) = [seed, f, sum(L.E_del_Wh(inEv)) / 1000, sum(L.shield_w_s(inEv) + L.shield_p_s(inEv)) / 3600, ...
            sum(L.interlock >= 2), sum(L.over_limit_s) / 3600];
    end
end
P = array2table(Q, 'VariableNames', {'seed', 'fault_id', 'E_del50_event_kWh', 'shield_h_event', 'failsafe_hours', 'hours_over_limit'});
P.fault = faults(P.fault_id, 1);
writetable(P, fullfile(outDir, 'pyranometer_seeds.csv'));
for f = 1:size(faults, 1)
    s = P(P.fault_id == f, :);
    R.pyranometer_20_seeds_PPO.(faults{f, 1}) = struct('E_del50_event_mean', mean(s.E_del50_event_kWh), 'ci95', ci(s.E_del50_event_kWh), ...
        'shield_h_mean', mean(s.shield_h_event), 'shield_ci95', ci(s.shield_h_event), 'failsafe_h_mean', mean(s.failsafe_hours));
    fprintf('[pyranometer, 20 seeds, PPO] %-10s delivered(event) %.2f +/- %.2f kWh  shield %.2f +/- %.2f h  fail-safe %.1f h\n', faults{f, 1}, ...
        mean(s.E_del50_event_kWh), ci(s.E_del50_event_kWh), mean(s.shield_h_event), ci(s.shield_h_event), mean(s.failsafe_hours));
end
R.year = table2struct(Y);
fid = fopen(fullfile(outDir, 'sensor_faults_summary.json'), 'w'); fwrite(fid, jsonencode(R, 'PrettyPrint', true)); fclose(fid);
end
