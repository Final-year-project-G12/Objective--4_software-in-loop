function rep = check_restart(exportDir, year, H)
%CHECK_RESTART  Plan section 7.1, restart-correctness check: start
% run_hold_test.m-style mid-run restarts from an hour whose state is known,
% and confirm they reproduce the full-year run exactly from that hour on.
% This is the single most likely bug in new shared code, because the
% single-node twin carries THREE pieces of state beyond (Tw,Tpcm,h,f) that a
% naive restart forgets: the previous action (prev), the smart-forecast
% clear-sky index (last_kc), and the safety interlock's latched-fault flag.
%
%   rep = check_restart('../export', 2021, 100)
%
% H is deliberately a NIGHT hour by default (hour 100 of 2021 = 05:00 on
% 5 Jan) -- the hardest case, because last_kc is only recomputed in daylight
% (clear_now > 20 W/m2) and is otherwise just carried over, so a restart
% that forgets it is most likely to show up right after a night-time cut.
here = fileparts(mfilename('fullpath')); addpath(here);
if nargin < 1 || isempty(exportDir), exportDir = fullfile(here, '..', 'export'); end
if nargin < 2, year = 2021; end
if nargin < 3, H = 100; end

tw = load_twin_params(exportDir, year);
W = tw.wx.signals.values; n = size(W, 1);

fprintf('[check_restart] full-year reference run (arm 3, PCM+SAC) ...\n');
Lfull = simulate_hours(tw, W, tw.P, 0, 0, []);
fprintf('[check_restart] restart hour H = %d  (hour-of-day %d, GHI=%.1f W/m2 -> %s)\n', ...
    H, W(H,4), W(H,2), ternary(W(H,2) < 1, 'NIGHT', 'DAY'));

initState.Tw0 = Lfull.Tw(H); initState.Tpcm0 = Lfull.Tpcm(H); initState.h0 = Lfull.h_pcm(H);
initState.f0 = Lfull.f_melt(H); initState.prev0 = Lfull.a_cmd(H);
initState.last_kc0 = Lfull.last_kc(H); initState.fault_latched0 = Lfull.fault_latched(H);
fprintf('[check_restart] captured state at H: Tw=%.6f Tpcm=%.6f h=%.3f f=%.6f prev=%d last_kc=%.6f latched=%d\n', ...
    initState.Tw0, initState.Tpcm0, initState.h0, initState.f0, initState.prev0, initState.last_kc0, initState.fault_latched0);

Wrest = W(H+1:end, :);
fprintf('[check_restart] correct restart (full state carried over) ...\n');
Lgood = simulate_hours(tw, Wrest, tw.P, 0, 0, [], '', initState);

fprintf('[check_restart] naive restart (cold start: last_kc reset to 1.0, latch cleared, prev=0) for comparison ...\n');
Lnaive = simulate_hours(tw, Wrest, tw.P, 0, 0, []);

ref = struct('Tw', Lfull.Tw(H+1:end), 'Tpcm', Lfull.Tpcm(H+1:end), 'f_melt', Lfull.f_melt(H+1:end), 'a_cmd', Lfull.a_cmd(H+1:end));

rep.H = H;
rep.good.max_abs_dTw   = max(abs(Lgood.Tw   - ref.Tw));
rep.good.max_abs_dTpcm = max(abs(Lgood.Tpcm - ref.Tpcm));
rep.good.max_abs_df    = max(abs(Lgood.f_melt - ref.f_melt));
rep.good.action_agreement_pct = 100 * mean(Lgood.a_cmd == ref.a_cmd);
rep.good.pass = rep.good.max_abs_dTw == 0 && rep.good.max_abs_dTpcm == 0 && rep.good.action_agreement_pct == 100;

rep.naive.max_abs_dTw   = max(abs(Lnaive.Tw   - ref.Tw));
rep.naive.max_abs_dTpcm = max(abs(Lnaive.Tpcm - ref.Tpcm));
rep.naive.action_agreement_pct = 100 * mean(Lnaive.a_cmd == ref.a_cmd);
rep.naive.first_divergent_hour = find(Lnaive.a_cmd ~= ref.a_cmd, 1);

fprintf('\n[check_restart] CORRECT restart vs full run, from H+1 to end (%d h):\n', numel(ref.Tw));
fprintf('  max|dTw|   = %.3e C\n', rep.good.max_abs_dTw);
fprintf('  max|dTpcm| = %.3e C\n', rep.good.max_abs_dTpcm);
fprintf('  max|df|    = %.3e\n', rep.good.max_abs_df);
fprintf('  action agreement = %.6f %%\n', rep.good.action_agreement_pct);
fprintf('  -> %s\n', ternary(rep.good.pass, 'PASS (zero difference)', 'FAIL -- STOP, do not trust section 7.3/4.3 results until this is fixed'));

fprintf('\n[check_restart] For contrast, a NAIVE restart that forgets prev/last_kc/latch:\n');
fprintf('  max|dTw|   = %.3e C\n', rep.naive.max_abs_dTw);
fprintf('  action agreement = %.6f %%', rep.naive.action_agreement_pct);
if ~isempty(rep.naive.first_divergent_hour)
    fprintf('  (first wrong action at restart+%d h)', rep.naive.first_divergent_hour);
end
fprintf('\n  This is the failure mode the check is designed to catch.\n');

fid = fopen(fullfile(exportDir, 'restart_check.json'), 'w');
fwrite(fid, jsonencode(rep, 'PrettyPrint', true)); fclose(fid);
end

function s = ternary(c, a, b)
if c, s = a; else, s = b; end
end
