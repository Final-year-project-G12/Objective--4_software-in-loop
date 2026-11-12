function report = validate_against_python(year, hours)
%VALIDATE_AGAINST_PYTHON  O4 test-plan step 4 (software-in-the-loop replay):
% prove the MATLAB/Simulink twin reproduces the Python RL environment.
%
% Two checks, both against export/reference_<year>.csv
% (the Python environment under the deterministic SAC policy):
%
%  A. Open-loop plant replay: feed pcm_plant_hour.m the SAME actions Python
%     took and compare the thermal state hour by hour. Isolates the physics
%     port from the policy port. Pass: max |dT| < 1e-6 C, identical shield
%     and violation counts.
%
%  B. Closed-loop Simulink twin: run pcm_drl_twin.slx with the SAC block
%     choosing actions. Pass: action agreement >= 99.9 %, delivered energy
%     within 0.1 %, same number of hard-limit violations (zero).
%
% Writes export/validation_report.json.
if nargin < 1, year = 2011; end
if nargin < 2, hours = 8760; end
here = fileparts(mfilename('fullpath'));
addpath(here);
exportDir = fullfile(here, '..', 'export');
tw = load_twin_params(exportDir, year);
assert(~isempty(tw.ref), 'reference_%d.csv missing -- run objective4_software_in_loop/export_from_python.py', year);
ref = tw.ref(1:min(hours, height(tw.ref)), :);
N = height(ref);

% ---------------- A. open-loop plant replay ----------------
Tw = tw.Tw0; Tp = tw.Tpcm0; h = tw.h0; f = tw.f0;
A = zeros(N, 8);   % Tw Tpcm f E_del E_unmet n_sw n_sp n_viol
W = tw.wx.signals.values;
for k = 1:N
    hod = W(k, 4);
    draw = tw.demand24(mod(round(hod), 24) + 1);
    [Tw, Tp, h, f, Ed, Eu, nsw, nsp, nv] = pcm_plant_hour(W(k, 2), W(k, 3), draw, ref.action(k), Tw, Tp, h, f, tw.P);
    A(k, :) = [Tw, Tp, f, Ed, Eu, nsw, nsp, nv];
end
rep.A_open_loop.max_abs_dT_w_C    = max(abs(A(:, 1) - ref.T_w_C));
rep.A_open_loop.max_abs_dT_pcm_C  = max(abs(A(:, 2) - ref.T_pcm_C));
rep.A_open_loop.max_abs_df_melt   = max(abs(A(:, 3) - ref.f_melt));
rep.A_open_loop.max_abs_dE_del_Wh = max(abs(A(:, 4) - ref.E_del_Wh));
rep.A_open_loop.delivered_kWh_matlab = sum(A(:, 4)) / 1000;
rep.A_open_loop.delivered_kWh_python = sum(ref.E_del_Wh) / 1000;
rep.A_open_loop.shields_matlab = sum(A(:, 6) + A(:, 7));
rep.A_open_loop.shields_python = sum(ref.n_shield_w + ref.n_shield_p);
rep.A_open_loop.violations_matlab = sum(A(:, 8));
rep.A_open_loop.violations_python = sum(ref.n_viol);
rep.A_open_loop.pass = rep.A_open_loop.max_abs_dT_w_C < 1e-6 && rep.A_open_loop.max_abs_dT_pcm_C < 1e-6 ...
    && rep.A_open_loop.shields_matlab == rep.A_open_loop.shields_python ...
    && rep.A_open_loop.violations_matlab == rep.A_open_loop.violations_python;
fprintf('[A open-loop] max|dT_w| = %.3g C  max|dT_pcm| = %.3g C  max|df| = %.3g  shields %d vs %d  viol %d vs %d  -> %s\n', ...
    rep.A_open_loop.max_abs_dT_w_C, rep.A_open_loop.max_abs_dT_pcm_C, rep.A_open_loop.max_abs_df_melt, ...
    rep.A_open_loop.shields_matlab, rep.A_open_loop.shields_python, ...
    rep.A_open_loop.violations_matlab, rep.A_open_loop.violations_python, tf(rep.A_open_loop.pass));

% policy-only check on Python's own observations (isolates the MLP port)
act_m = zeros(N, 1); ac_m = zeros(N, 1);
obsCols = ref{:, startsWith(ref.Properties.VariableNames, 'obs')};
for k = 1:N
    [act_m(k), ac_m(k)] = sac_policy(obsCols(k, :)', tw.W1, tw.b1, tw.W2, tw.b2, tw.Wmu, tw.bmu, 0);
end
rep.A_policy_on_python_obs.action_agreement_pct = 100 * mean(act_m == ref.action);
rep.A_policy_on_python_obs.max_abs_da_cont = max(abs(ac_m - ref.a_cont));
fprintf('[A policy]    action agreement on Python obs = %.3f %%  max|da_cont| = %.2e\n', ...
    rep.A_policy_on_python_obs.action_agreement_pct, rep.A_policy_on_python_obs.max_abs_da_cont);

% ---------------- B. closed-loop Simulink twin ----------------
mdl = 'pcm_drl_twin';
if ~isfile(fullfile(here, [mdl '.slx'])), build_pcm_twin_model(mdl); end
out = run_twin(tw, N, 0, 0);
rep.B_closed_loop.action_agreement_pct = 100 * mean(out.a_policy == ref.action);
rep.B_closed_loop.max_abs_dT_w_C   = max(abs(out.Tw - ref.T_w_C));
rep.B_closed_loop.max_abs_dT_pcm_C = max(abs(out.Tpcm - ref.T_pcm_C));
rep.B_closed_loop.delivered_kWh_matlab = sum(out.E_del_Wh) / 1000;
rep.B_closed_loop.delivered_kWh_python = sum(ref.E_del_Wh) / 1000;
rep.B_closed_loop.delivered_rel_err_pct = 100 * abs(rep.B_closed_loop.delivered_kWh_matlab - rep.B_closed_loop.delivered_kWh_python) / rep.B_closed_loop.delivered_kWh_python;
rep.B_closed_loop.shields_matlab = sum(out.n_sw + out.n_sp);
rep.B_closed_loop.shields_python = sum(ref.n_shield_w + ref.n_shield_p);
rep.B_closed_loop.violations_matlab = sum(out.n_viol);
rep.B_closed_loop.violations_python = sum(ref.n_viol);
rep.B_closed_loop.pass = rep.B_closed_loop.action_agreement_pct >= 99.9 ...
    && rep.B_closed_loop.delivered_rel_err_pct < 0.1 ...
    && rep.B_closed_loop.violations_matlab == 0;
fprintf('[B Simulink]  action agreement = %.3f %%  delivered %.1f vs %.1f kWh (%.4f %%)  shields %d vs %d  viol %d  -> %s\n', ...
    rep.B_closed_loop.action_agreement_pct, rep.B_closed_loop.delivered_kWh_matlab, rep.B_closed_loop.delivered_kWh_python, ...
    rep.B_closed_loop.delivered_rel_err_pct, rep.B_closed_loop.shields_matlab, rep.B_closed_loop.shields_python, ...
    rep.B_closed_loop.violations_matlab, tf(rep.B_closed_loop.pass));

rep.year = year; rep.hours = N; rep.matlab = version; rep.generated = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
rep.overall_pass = rep.A_open_loop.pass && rep.B_closed_loop.pass;
fid = fopen(fullfile(exportDir, 'validation_report.json'), 'w');
fwrite(fid, jsonencode(rep, 'PrettyPrint', true)); fclose(fid);
fprintf('[validate] overall: %s  (report: export/validation_report.json)\n', tf(rep.overall_pass));
report = rep;
end

function s = tf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end
