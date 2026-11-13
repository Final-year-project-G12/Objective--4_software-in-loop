function report = validate_against_python(regime, year, hours, useSimulink)
%VALIDATE_AGAINST_PYTHON  O4 test-plan step 4 (software-in-the-loop replay): show that
% the MATLAB/Simulink twin reproduces the Python RL environment.
%
%   validate_against_python            % regime 1, 2023, full year, plain-MATLAB checks only
%   validate_against_python(1, 2023, 168, true)   % one week, also run the Simulink model
%
% Checks, all against export_r<regime>/reference_<year>.csv (the Python environment under
% the deterministic DQN policy):
%
%  A. Open-loop plant replay: feed pcm_plant_hour.m the SAME actions Python took and
%     compare the tank state hour by hour. Isolates the physics port from the policy
%     port. Pass: max |dT| < 1e-6 C, identical shield and violation counts.
%  A2. Policy only: dqn_policy.m on Python's own observations. Pass: same action every hour.
%  C. Closed loop in plain MATLAB (sensors -> observation -> DQN -> interlock -> plant).
%     Pass: 100 % action agreement, max |dT_top| < 1e-6 C, same shield count.
%  B. (optional) Closed-loop Simulink twin pcm_drl_twin_rj.slx. Pass: action agreement
%     >= 99.9 %, delivered energy within 0.1 %, zero hard-limit violations.
%
% Note on tolerances: the plant solves a 10x10 linear system every sub-step. MATLAB's
% backslash and NumPy's solver may differ in the last bits, so agreement near 1e-10 C is
% expected rather than bit-for-bit equality.
%
% Writes export_r<regime>/validation_report.json.
if nargin < 1 || isempty(regime), regime = 1; end
if nargin < 2 || isempty(year), year = 2023; end
if nargin < 3 || isempty(hours), hours = 8760; end
if nargin < 4, useSimulink = false; end
here = fileparts(mfilename('fullpath'));
addpath(here);
exportDir = fullfile(here, '..', sprintf('export_r%d', regime));
tw = load_twin_params(exportDir, year);
assert(~isempty(tw.ref), 'reference_%d.csv missing -- run export_from_python.py --regime %d', year, regime);
ref = tw.ref(1:min(hours, height(tw.ref)), :);
N = height(ref);
W = tw.wx.signals.values(:, 1:4);

% ---------------- A. open-loop plant replay ----------------
T = tw.T0;  h = tw.h0;
A = zeros(N, 18);
for k = 1:N
    hod = mod(round(W(k, 4)), 24);
    draw = tw.demand24(hod + 1);
    [T, h, y] = pcm_plant_hour(W(k, 2), W(k, 3), draw, ref.action(k), T, h, tw.P);
    A(k, :) = y';
end
a.max_abs_dT_top_C    = max(abs(A(:, 1) - ref.T_w_C));
a.max_abs_dT_bottom_C = max(abs(A(:, 2) - ref.T_bottom_C));
a.max_abs_dT_mean_C   = max(abs(A(:, 3) - ref.T_mean_C));
a.max_abs_dT_pcm_C    = max(abs(A(:, 4) - ref.T_pcm_C));
a.max_abs_df_melt     = max(abs(A(:, 5) - ref.f_melt));
a.max_abs_dE_del_Wh   = max(abs(A(:, 8) - ref.E_del_Wh));
a.delivered_kWh_matlab = sum(A(:, 8)) / 1000;
a.delivered_kWh_python = sum(ref.E_del_Wh) / 1000;
a.shields_matlab = sum(A(:, 12) + A(:, 13));
a.shields_python = sum(ref.n_shield_w + ref.n_shield_p);
a.violations_matlab = sum(A(:, 14));
a.violations_python = sum(ref.n_viol);
a.pass = a.max_abs_dT_top_C < 1e-6 && a.max_abs_dT_pcm_C < 1e-6 ...
    && a.shields_matlab == a.shields_python && a.violations_matlab == a.violations_python;
rep.A_open_loop = a;
fprintf('[A open-loop] max|dT_top| = %.3g C  max|dT_pcm| = %.3g C  max|df| = %.3g  shields %d vs %d  viol %d vs %d  -> %s\n', ...
    a.max_abs_dT_top_C, a.max_abs_dT_pcm_C, a.max_abs_df_melt, a.shields_matlab, a.shields_python, ...
    a.violations_matlab, a.violations_python, tf(a.pass));

% ---------------- A2. policy on Python's own observations ----------------
act_m = zeros(N, 1);  dq = 0;
obsCols = zeros(N, 17);
for k = 1:17, obsCols(:, k) = ref.(sprintf('obs%d', k - 1)); end
qRef = [ref.q0, ref.q1, ref.q2];
for k = 1:N
    [act_m(k), q] = dqn_policy(obsCols(k, :)', tw.W1, tw.b1, tw.W2, tw.b2, tw.W3, tw.b3, 0);
    dq = max(dq, max(abs(q(:)' - qRef(k, :)) ./ max(1, abs(qRef(k, :)))));
end
rep.A_policy_on_python_obs.action_agreement_pct = 100 * mean(act_m == ref.action);
rep.A_policy_on_python_obs.max_rel_dQ = dq;
fprintf('[A policy]    action agreement on Python obs = %.3f %%  max rel |dQ| = %.2e\n', ...
    rep.A_policy_on_python_obs.action_agreement_pct, dq);

% ---------------- C. closed loop, plain MATLAB ----------------
Lc = simulate_hours(tw, W, tw.P, 0, 0, [], N);
c.action_agreement_pct = 100 * mean(Lc.a_policy == ref.action);
c.max_abs_dT_top_C = max(abs(Lc.Tw - ref.T_w_C));
c.max_abs_dT_pcm_C = max(abs(Lc.Tpcm - ref.T_pcm_C));
c.max_abs_dobs = max(max(abs(Lc.obs - obsCols)));
c.delivered_kWh_matlab = sum(Lc.E_del_Wh) / 1000;
c.delivered_kWh_python = sum(ref.E_del_Wh) / 1000;
c.shields_matlab = sum(Lc.n_sw + Lc.n_sp);
c.shields_python = sum(ref.n_shield_w + ref.n_shield_p);
c.violations_matlab = sum(Lc.n_viol);
c.pass = c.action_agreement_pct == 100 && c.max_abs_dT_top_C < 1e-6 ...
    && c.shields_matlab == c.shields_python && c.violations_matlab == 0;
rep.C_closed_loop = c;
fprintf('[C closed loop] action agreement = %.3f %%  max|dT_top| = %.3g C  delivered %.2f vs %.2f kWh  shields %d vs %d  -> %s\n', ...
    c.action_agreement_pct, c.max_abs_dT_top_C, c.delivered_kWh_matlab, c.delivered_kWh_python, ...
    c.shields_matlab, c.shields_python, tf(c.pass));

rep.overall_pass = a.pass && c.pass && rep.A_policy_on_python_obs.action_agreement_pct == 100;

% ---------------- B. closed-loop Simulink twin (optional, slow) ----------------
if useSimulink
    out = run_twin(tw, N, 0, 0);
    b.action_agreement_pct = 100 * mean(out.a_policy == ref.action);
    b.max_abs_dT_top_C = max(abs(out.Tw - ref.T_w_C));
    b.max_abs_dT_pcm_C = max(abs(out.Tpcm - ref.T_pcm_C));
    b.delivered_kWh_matlab = sum(out.E_del_Wh) / 1000;
    b.delivered_kWh_python = sum(ref.E_del_Wh) / 1000;
    b.delivered_rel_err_pct = 100 * abs(b.delivered_kWh_matlab - b.delivered_kWh_python) / b.delivered_kWh_python;
    b.shields_matlab = sum(out.n_sw + out.n_sp);
    b.shields_python = sum(ref.n_shield_w + ref.n_shield_p);
    b.violations_matlab = sum(out.n_viol);
    b.pass = b.action_agreement_pct >= 99.9 && b.delivered_rel_err_pct < 0.1 && b.violations_matlab == 0;
    rep.B_simulink = b;
    fprintf('[B Simulink]  action agreement = %.3f %%  delivered %.2f vs %.2f kWh (%.4f %%)  shields %d vs %d  viol %d  -> %s\n', ...
        b.action_agreement_pct, b.delivered_kWh_matlab, b.delivered_kWh_python, b.delivered_rel_err_pct, ...
        b.shields_matlab, b.shields_python, b.violations_matlab, tf(b.pass));
    rep.overall_pass = rep.overall_pass && b.pass;
end

rep.regime = regime;  rep.year = year;  rep.hours = N;  rep.matlab = version;
rep.generated = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
fid = fopen(fullfile(exportDir, 'validation_report.json'), 'w');
fwrite(fid, jsonencode(rep, 'PrettyPrint', true));  fclose(fid);
fprintf('[validate] overall: %s  (report: export_r%d/validation_report.json)\n', tf(rep.overall_pass), regime);
report = rep;
end

function s = tf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end
