function T = run_h(regimes)
%RUN_H  20-seed sensor-fault confidence intervals for every arm (Tamil Nadu scope item H), on the 10-day April window.
%
%   T = run_h;          % regimes 1, 0, 2
%   T = run_h(1);       % writes ../export_r<k>/scenarios_4arm/sensor_fault_20seed_ci.csv and sensor_fault_20seed_raw.mat
%
% Same window as run_c_scenarios.m (1 April 2023, 4 days spin-up, event days 5-8, 2 days recovery) and the Tamil Nadu layout of the table:
% delivered kWh and shield hours over the FULL 10-day window (the pyranometer faults are a standing equipment condition, not a 4-day
% transient), mean +- standard error over 20 seeds, hard-limit violations summed over the seeds.
% Cases (the other sensors are noisy with 1 % dropout in every case, so a seed changes the dropouts and the noise):
%   healthy            pyranometer reads the real irradiance
%   dead_pyranometer   reads 0 W/m2          stuck_pyranometer  reads 500 W/m2 (constant, so it differs from the dead case)
%   sensor_blackout    healthy pyranometer + a 12 h blackout of the whole sensor frame at the start of the event
% Arms: plain tank (B0), PCM + B0, PCM + DQN (regime 1; in regimes 0 and 2 the DQN is B0), PCM + SAC. The plain tank and B0 do not read the
% observation, so for them a seed only changes the 1 % dropouts (which force BYPASS).
if nargin < 1 || isempty(regimes), regimes = [1 0 2]; end
here = fileparts(mfilename('fullpath')); addpath(here);
ns = 20;
cases = {'healthy', NaN, false; 'dead_pyranometer', 0, false; 'stuck_pyranometer', 500, false; 'sensor_blackout', NaN, true};
for regime = regimes
    tw = load_twin_params(fullfile(here, '..', sprintf('export_r%d', regime)), 2023);
    W = tw.wx.signals.values(:, 1:4);
    k0 = 90 * 24;  nWin = 240;
    base = W(k0 + (1:nWin + 3), :);
    arms = {'plain_B0', make_plain_tank(tw.P), 1};  arms(end+1, :) = {'pcm_B0', tw.P, 1};
    if regime == 1, arms(end+1, :) = {'pcm_DQN', tw.P, 0}; end
    arms(end+1, :) = {'pcm_SAC', tw.P, 2};
    rows = {};  raw = struct();
    for a = 1:size(arms, 1)
        for c = 1:size(cases, 1)
            bo = false(nWin, 1);  if cases{c, 3}, bo(4 * 24 + (1:12)) = true; end
            del = zeros(ns, 1);  sh = zeros(ns, 1);  vi = zeros(ns, 1);
            for seed = 1:ns
                rng(seed);
                L = simulate_hours(tw, base, arms{a, 2}, arms{a, 3}, 1, bo, nWin, cases{c, 2});
                del(seed) = sum(L.E_del_Wh) / 1000;  sh(seed) = sum(L.shield_s) / 3600;  vi(seed) = sum(L.n_viol);
            end
            raw.(sprintf('%s__%s', arms{a, 1}, cases{c, 1})) = [del sh vi];
            se = @(x) std(x) / sqrt(ns);
            rows(end+1, :) = {arms{a, 1}, cases{c, 1}, mean(del), se(del), mean(sh), se(sh), sum(vi), ns}; %#ok<AGROW>
        end
        fprintf('[run_h] regime %d %-9s done\n', regime, arms{a, 1});
    end
    T = cell2table(rows, 'VariableNames', {'arm', 'case', 'delivered_kWh_mean', 'delivered_kWh_SE', 'shield_hours_mean', 'shield_hours_SE', ...
        'hard_violations_all_seeds', 'n_seeds'});
    outDir = fullfile(here, '..', sprintf('export_r%d', regime), 'scenarios_4arm');
    if ~isfolder(outDir), mkdir(outDir); end
    writetable(T, fullfile(outDir, 'sensor_fault_20seed_ci.csv'));
    save(fullfile(outDir, 'sensor_fault_20seed_raw.mat'), 'raw');
    disp(T);
end
end
