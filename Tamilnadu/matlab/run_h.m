function T = run_h(exportDir, year)
%RUN_H  Objective 4 item H: 20-seed confidence intervals on the
% dead-pyranometer case (arm 3, SAC, 10-day window), plus the
% stuck-pyranometer case and a healthy-sensor baseline for comparison.
% Same 10-day window and arm-3 config as run_c_scenarios.m's ghi_dropout/
% ghi_stuck rows (single seed=7 there); this adds seed variability on top
% of that same setup rather than redefining it.
here = fileparts(mfilename('fullpath')); addpath(here);
if nargin < 1 || isempty(exportDir), exportDir = fullfile(here, '..', 'export'); end
if nargin < 2, year = 2011; end   % same replay year run_c_scenarios.m uses for this window

tw = load_twin_params(exportDir, year);
Wall = tw.wx.signals.values;
k0 = 90 * 24; nWin = 10 * 24;
W = Wall(k0 + (1:nWin), :);
P = tw.P;   % arm3_pcm_SAC config, policy_mode = 0

nSeeds = 20;
cases = {'healthy', ''; 'dead', 'dropout'; 'stuck', 'stuck'};
rows = {};
rawDeliv = struct(); rawShield = struct(); rawViol = struct();

for c = 1:size(cases,1)
    nm = cases{c,1}; gf = cases{c,2};
    deliv = zeros(nSeeds,1); shield = zeros(nSeeds,1); viol = zeros(nSeeds,1);
    for s = 1:nSeeds
        rng(s);
        L = simulate_hours(tw, W, P, 0, 1, [], gf);   % noise_on=1 for all three (healthy/dead/stuck differ only in gf)
        deliv(s)  = sum(L.E_del_Wh) / 1000;
        shield(s) = sum(L.n_sw + L.n_sp);
        viol(s)   = sum(L.n_viol);
    end
    rawDeliv.(nm) = deliv; rawShield.(nm) = shield; rawViol.(nm) = viol;
    mD = mean(deliv); seD = std(deliv)/sqrt(nSeeds);
    mS = mean(shield); seS = std(shield)/sqrt(nSeeds);
    totViol = sum(viol);
    rows(end+1,:) = {nm, nSeeds, mD, seD, mS, seS, totViol}; %#ok<AGROW>
    fprintf('[run_h] %-8s  delivered = %7.2f +/- %5.2f kWh   shield hours = %7.1f +/- %4.1f   hard violations (sum over %d seeds) = %d\n', ...
        nm, mD, seD, mS, seS, nSeeds, totViol);
end

T = cell2table(rows, 'VariableNames', {'case','n_seeds','delivered_kWh_mean','delivered_kWh_SE', ...
    'shield_hours_mean','shield_hours_SE','hard_violations_total'});
fprintf('\n=== Item H: 20-seed confidence intervals, arm 3 (SAC), 10-day window, year %d ===\n', year);
disp(T);
fprintf('TOTAL hard-limit violations across all 3 cases x %d seeds = %d\n', nSeeds, sum(T.hard_violations_total));

outDir = fullfile(exportDir, 'scenarios_3arm'); if ~isfolder(outDir), mkdir(outDir); end
writetable(T, fullfile(outDir, 'sensor_fault_20seed_ci.csv'));
save(fullfile(outDir, 'sensor_fault_20seed_raw.mat'), 'rawDeliv', 'rawShield', 'rawViol');
fprintf('\n[run_h] table -> %s/sensor_fault_20seed_ci.csv\n', outDir);
fprintf('H_DONE_MARKER\n');
end
