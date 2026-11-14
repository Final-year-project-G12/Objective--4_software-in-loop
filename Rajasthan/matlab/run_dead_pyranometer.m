function R = run_dead_pyranometer()
%RUN_DEAD_PYRANOMETER  Dead-pyranometer case: the controller's irradiance reading is stuck at 0 W/m2.
%
%   R = run_dead_pyranometer;   % writes ../results_campaign/dead_pyranometer_year.csv and dead_pyranometer_seeds.csv
%
% Definition (agreed with the student, 14 Nov 2026; the improvement plan v2 does not define this case):
%   - the pyranometer reading is 0 W/m2 for the WHOLE run, while the real irradiance still drives the plant;
%   - B0 (always-charge) and the trained DQN are compared on the same weather, healthy sensor against dead sensor.
% Assumptions (none is in the plan):
%   - Only the pyranometer is dead. The 1-3 h GHI forecast in the observation is a weather-feed value (Objective 3 uses the
%     true future weather) and is NOT zeroed. A second dead-forecast variant is not run.
%   - B0 does not read the observation, so a dead sensor cannot change it; it is run anyway as the control.
%   - The interlock (safety_interlock.m) has no irradiance plausibility rule: it reacts only to a stale-frame flag, to the
%     measured top / PCM temperatures against the limits, and the plant shield acts at every sub-step. So "does the fallback
%     trigger" is measured, not assumed: fail-safe hours (interlock state >= 2) and guard-band hours (state 1) are counted.
%   - Year run: 2023, ideal other sensors, so no random draw and no seed applies.
%   - Seeds: 20 noisy-sensor runs (other sensors with noise and 1 % dropout) on the 10-day April window of the edge-case
%     scenarios (event days 5-8). The stuck value is applied after the noise draw, so a healthy and a dead run with the same
%     seed see the same dropouts: any difference in fail-safe hours is the dead sensor's.
%   - Window energy = 18:00-09:00 delivered at 45 C (Objective 2's window).
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = fullfile(here, '..', 'results_campaign');
tw = load_twin_params(fullfile(here, '..', 'export_r1'), 2023);
W = tw.wx.signals.values(:, 1:4);

% ---------------- full year, ideal other sensors ----------------
rows = {};  Ls = struct();
for pol = {'B0', 'DQN'}
    pm = double(strcmp(pol{1}, 'B0'));
    for st = {'healthy', 'dead'}
        stuck = NaN;  if strcmp(st{1}, 'dead'), stuck = 0; end
        L = simulate_hours(tw, W, tw.P, pm, 0, [], [], stuck);
        Ls.(pol{1}).(st{1}) = L;
        win = (L.hod >= 18) | (L.hod < 9);
        rows(end+1, :) = {pol{1}, st{1}, sum(L.E_del_Wh) / 1000, sum(L.E_del_Wh(win)) / 1000, sum(L.shield_s) / 3600, ...
            sum(L.n_viol > 0), sum(L.interlock == 1), sum(L.interlock >= 2), sum(L.a_cmd == 0), sum(L.a_cmd == 1), sum(L.a_cmd == 2)}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'controller', 'pyranometer', 'E_del45_kWh', 'E_del45_window_kWh', 'guard_band_h', ...
    'hours_over_hard_limit', 'interlock_guard_hours', 'interlock_failsafe_hours', 'charge_hours', 'idle_hours', 'bypass_hours'});
Ld = Ls.DQN.dead;  Lh = Ls.DQN.healthy;
R.dqn_action_changed_hours = sum(Ld.a_cmd ~= Lh.a_cmd);
R.dqn_dead_idle_hours = sum(Ld.a_cmd == 1);
R.dqn_healthy_idle_hours = sum(Lh.a_cmd == 1);
R.dqn_dead_failsafe_hours = sum(Ld.interlock >= 2);
R.b0_changed = max(abs(Ls.B0.dead.E_del_Wh - Ls.B0.healthy.E_del_Wh));
writetable(T, fullfile(outDir, 'dead_pyranometer_year.csv'));
disp(T);
fprintf('[dead pyranometer, year] DQN commands differ from the healthy run in %d of 8760 h; IDLE hours %d (healthy %d); interlock fail-safe hours %d; B0 max hourly difference %.3g Wh\n', ...
    R.dqn_action_changed_hours, R.dqn_dead_idle_hours, R.dqn_healthy_idle_hours, R.dqn_dead_failsafe_hours, R.b0_changed);

% ---------------- 20 seeds, 10-day April window, noisy other sensors ----------------
k0 = 90 * 24;  nWin = 240;
base = W(k0 + (1:nWin + 3), :);
iS = 4 * 24 + 1;  iE = 8 * 24;                      % event days 5-8, as in run_scenarios.m
ns = 20;  Q = zeros(ns * 4, 9);  q = 0;
for seed = 1:ns
    for pm = [0 1]
        for stuck = [NaN 0]
            rng(seed);
            L = simulate_hours(tw, base, tw.P, pm, 1, false(nWin, 1), nWin, stuck);
            win = (L.hod >= 18) | (L.hod < 9);
            q = q + 1;
            Q(q, :) = [seed, pm, ~isnan(stuck), sum(L.E_del_Wh(iS:iE)) / 1000, sum(L.E_del_Wh(win)) / 1000, ...
                sum(L.shield_s(iS:iE)) / 3600, sum(L.interlock >= 2), sum(L.interlock == 1), sum(L.n_viol > 0)];
        end
    end
end
S = array2table(Q, 'VariableNames', {'seed', 'is_B0', 'dead_pyranometer', 'E_del45_event_kWh', 'E_del45_window_kWh', ...
    'shield_h_event', 'interlock_failsafe_hours', 'interlock_guard_hours', 'hours_over_hard_limit'});
writetable(S, fullfile(outDir, 'dead_pyranometer_seeds.csv'));
tcrit = 2.093;                                       % Student t, 0.975, 19 degrees of freedom
for pm = [0 1]
    for d = [0 1]
        s = S(S.is_B0 == pm & S.dead_pyranometer == d, :);
        nm = {'DQN', 'B0'};  hs = {'healthy', 'dead'};
        ci = @(x) tcrit * std(x) / sqrt(numel(x));
        fprintf('[seeds] %-3s %-7s event delivered %.2f +/- %.2f kWh   shield %.2f +/- %.2f h   fail-safe hours %.1f   guard hours %.1f\n', ...
            nm{pm + 1}, hs{d + 1}, mean(s.E_del45_event_kWh), ci(s.E_del45_event_kWh), mean(s.shield_h_event), ci(s.shield_h_event), ...
            mean(s.interlock_failsafe_hours), mean(s.interlock_guard_hours));
    end
end
dq = S(S.is_B0 == 0, :);
R.seeds_failsafe_hours_changed_by_dead_sensor = ...
    max(abs(dq.interlock_failsafe_hours(dq.dead_pyranometer == 1) - dq.interlock_failsafe_hours(dq.dead_pyranometer == 0)));
fprintf('[seeds] largest change in DQN fail-safe hours caused by the dead sensor (same seed): %g h\n', R.seeds_failsafe_hours_changed_by_dead_sensor);
R.year = T;  R.seeds = S;
end
