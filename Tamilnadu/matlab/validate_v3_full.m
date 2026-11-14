function rep = validate_v3_full(exportDir, year)
%VALIDATE_V3_FULL  Re-run the three regression checks for the V3
% smart-forecast twin (open-loop plant, policy-only, full closed loop),
% WITHOUT the Simulink model (that is rebuilt separately -- see README).
%
%   rep = validate_v3_full('../export', 2011)
here = fileparts(mfilename('fullpath')); addpath(here);
if nargin < 1 || isempty(exportDir), exportDir = fullfile(here, '..', 'export'); end
if nargin < 2, year = 2011; end
tw = load_twin_params(exportDir, year);
assert(~isempty(tw.ref), 'reference_%d.csv missing', year);
ref = tw.ref;
N = height(ref);
fprintf('[validate_v3_full] %s  year=%d  N=%d  obs_dim=%d\n', exportDir, year, N, size(tw.W1, 2));

% ---- A. open-loop plant replay (feed Python''s own actions) ----
Tw = tw.Tw0; Tp = tw.Tpcm0; h = tw.h0; f = tw.f0;
A = zeros(N, 8);
W = tw.wx.signals.values;
for k = 1:N
    hod = W(k, 4);
    draw = tw.demand24(mod(round(hod), 24) + 1);
    [Tw, Tp, h, f, Ed, Eu, nsw, nsp, nv] = pcm_plant_hour(W(k, 2), W(k, 3), draw, ref.action(k), Tw, Tp, h, f, tw.P);
    A(k, :) = [Tw, Tp, f, Ed, Eu, nsw, nsp, nv];
end
rep.A.max_abs_dT_w_C   = max(abs(A(:, 1) - ref.T_w_C));
rep.A.max_abs_dT_pcm_C = max(abs(A(:, 2) - ref.T_pcm_C));
rep.A.delivered_kWh_matlab = sum(A(:, 4)) / 1000;
rep.A.delivered_kWh_python = sum(ref.E_del_Wh) / 1000;
rep.A.shields_matlab = sum(A(:, 6) + A(:, 7));
rep.A.shields_python = sum(ref.n_shield_w + ref.n_shield_p);
rep.A.violations_matlab = sum(A(:, 8));
rep.A.pass = rep.A.max_abs_dT_w_C < 1e-6 && rep.A.shields_matlab == rep.A.shields_python;
fprintf('[A open-loop plant]   max|dTw|=%.3g C  delivered %.2f vs %.2f kWh  shields %d vs %d  -> %s\n', ...
    rep.A.max_abs_dT_w_C, rep.A.delivered_kWh_matlab, rep.A.delivered_kWh_python, ...
    rep.A.shields_matlab, rep.A.shields_python, tf(rep.A.pass));

% ---- B. policy-only, fed Python''s own (15-dim) observations ----
obsCols = ref{:, startsWith(ref.Properties.VariableNames, 'obs')};
act_m = zeros(N, 1);
for k = 1:N
    act_m(k) = sac_policy(obsCols(k, :)', tw.W1, tw.b1, tw.W2, tw.b2, tw.Wmu, tw.bmu, 0);
end
rep.B.action_agreement_pct = 100 * mean(act_m == ref.action);
rep.B.pass = rep.B.action_agreement_pct == 100;
fprintf('[B policy-only]        action agreement = %.3f %%  -> %s\n', rep.B.action_agreement_pct, tf(rep.B.pass));

% ---- C. full closed loop: sensors(ideal) -> obs -> SAC -> interlock -> plant ----
Lc = simulate_hours(tw, W, tw.P, 0, 0, []);
rep.C.action_agreement_pct = 100 * mean(Lc.a_policy == ref.action);
rep.C.max_abs_dT_w_C = max(abs(Lc.Tw - ref.T_w_C));
rep.C.delivered_kWh_matlab = sum(Lc.E_del_Wh) / 1000;
rep.C.delivered_kWh_python = sum(ref.E_del_Wh) / 1000;
rep.C.shields_matlab = sum(Lc.n_sw + Lc.n_sp);
rep.C.shields_python = sum(ref.n_shield_w + ref.n_shield_p);
rep.C.pass = rep.C.action_agreement_pct == 100 && rep.C.max_abs_dT_w_C < 1e-6;
fprintf('[C closed loop, %dh]  action agreement = %.3f %%  max|dTw|=%.3g C  delivered %.2f vs %.2f kWh  shields %d vs %d  -> %s\n', ...
    N, rep.C.action_agreement_pct, rep.C.max_abs_dT_w_C, rep.C.delivered_kWh_matlab, rep.C.delivered_kWh_python, ...
    rep.C.shields_matlab, rep.C.shields_python, tf(rep.C.pass));

rep.overall_pass = rep.A.pass && rep.B.pass && rep.C.pass;
rep.year = year; rep.N = N; rep.generated = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
fid = fopen(fullfile(exportDir, 'validation_report_v3.json'), 'w');
fwrite(fid, jsonencode(rep, 'PrettyPrint', true)); fclose(fid);
fprintf('[validate_v3_full] OVERALL: %s\n', tf(rep.overall_pass));
end

function s = tf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end
