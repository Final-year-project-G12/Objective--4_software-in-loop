function report = validate_sac_against_python(regime, year, hours)
%VALIDATE_SAC_AGAINST_PYTHON  The O4 software-in-the-loop check (test-plan step 4) for the Objective 3 SAC controller.
%
%   validate_sac_against_python(1)       % regime 1, 2023, full year
%
% Same three checks as validate_against_python.m, against export_r<regime>/reference_sac_<year>.csv (the Python environment under
% the deterministic SAC actor selected by Objective 3's annual-only rule; export_from_python.py --algo sac):
%  A.  Open-loop plant replay with Python's SAC actions (physics only).            Pass: max |dT| < 1e-6 C, identical shield counts
%  A2. sac_policy.m on Python's own observations.                                  Pass: the same binned action every hour
%  C.  Closed loop (sensors -> observation -> SAC -> interlock -> plant), policy_mode 2.   Pass: 100 % action agreement, same shields
% Tolerance note: the actor is evaluated in single precision (as PyTorch does); a_cont is compared with Python's tanh(mu) and any
% hour whose |a| sits within 1e-5 of a binning edge (+-1/3) is reported, because only there could rounding flip an action.
% Writes export_r<regime>/validation_sac_report.json (the DQN validation_report.json is not touched).
if nargin < 1 || isempty(regime), regime = 1; end
if nargin < 2 || isempty(year), year = 2023; end
if nargin < 3 || isempty(hours), hours = 8760; end
here = fileparts(mfilename('fullpath'));
addpath(here);
exportDir = fullfile(here, '..', sprintf('export_r%d', regime));
tw = load_twin_params(exportDir, year);
assert(isfield(tw, 'sac') && isfield(tw, 'ref_sac'), 'sac_actor_r%d.json / reference_sac_%d.csv missing: python export_from_python.py --regime %d --algo sac', regime, year, regime);
ref = tw.ref_sac(1:min(hours, height(tw.ref_sac)), :);
N = height(ref);
W = tw.wx.signals.values(:, 1:4);

% ---------------- A. open-loop plant replay ----------------
T = tw.T0;  h = tw.h0;
A = zeros(N, 18);
for k = 1:N
    draw = tw.demand24(mod(round(W(k, 4)), 24) + 1);
    [T, h, y] = pcm_plant_hour(W(k, 2), W(k, 3), draw, ref.action(k), T, h, tw.P);
    A(k, :) = y';
end
a.max_abs_dT_top_C = max(abs(A(:, 1) - ref.T_w_C));
a.max_abs_dT_pcm_C = max(abs(A(:, 4) - ref.T_pcm_C));
a.max_abs_df_melt = max(abs(A(:, 5) - ref.f_melt));
a.delivered_kWh_matlab = sum(A(:, 8)) / 1000;
a.delivered_kWh_python = sum(ref.E_del_Wh) / 1000;
a.shields_matlab = sum(A(:, 12) + A(:, 13));
a.shields_python = sum(ref.n_shield_w + ref.n_shield_p);
a.violations_matlab = sum(A(:, 14));
a.violations_python = sum(ref.n_viol);
a.pass = a.max_abs_dT_top_C < 1e-6 && a.max_abs_dT_pcm_C < 1e-6 && a.shields_matlab == a.shields_python ...
    && a.violations_matlab == a.violations_python;
rep.A_open_loop = a;
fprintf('[A open-loop] max|dT_top| = %.3g C  max|dT_pcm| = %.3g C  shields %d vs %d  viol %d vs %d  -> %s\n', ...
    a.max_abs_dT_top_C, a.max_abs_dT_pcm_C, a.shields_matlab, a.shields_python, a.violations_matlab, a.violations_python, tf(a.pass));

% ---------------- A2. policy on Python's own observations ----------------
obsCols = zeros(N, 17);
for k = 1:17, obsCols(:, k) = ref.(sprintf('obs%d', k - 1)); end
act_m = zeros(N, 1);  a_m = zeros(N, 1);
for k = 1:N
    [act_m(k), a_m(k)] = sac_policy(obsCols(k, :)', tw.sac.W1, tw.sac.b1, tw.sac.W2, tw.sac.b2, tw.sac.Wmu, tw.sac.bmu);
end
rep.A_policy_on_python_obs.action_agreement_pct = 100 * mean(act_m == ref.action);
rep.A_policy_on_python_obs.max_abs_da_cont = max(abs(a_m - ref.a_cont));
rep.A_policy_on_python_obs.hours_within_1e5_of_a_bin_edge = sum(abs(abs(ref.a_cont) - 1/3) < 1e-5);
fprintf('[A policy]    action agreement on Python obs = %.3f %%  max |da| = %.2e  hours within 1e-5 of a bin edge: %d\n', ...
    rep.A_policy_on_python_obs.action_agreement_pct, rep.A_policy_on_python_obs.max_abs_da_cont, ...
    rep.A_policy_on_python_obs.hours_within_1e5_of_a_bin_edge);

% ---------------- C. closed loop ----------------
Lc = simulate_hours(tw, W, tw.P, 2, 0, [], N);
c.action_agreement_pct = 100 * mean(Lc.a_policy == ref.action);
c.max_abs_dT_top_C = max(abs(Lc.Tw - ref.T_w_C));
c.max_abs_dT_pcm_C = max(abs(Lc.Tpcm - ref.T_pcm_C));
c.max_abs_dobs = max(max(abs(Lc.obs - obsCols)));
c.delivered_kWh_matlab = sum(Lc.E_del_Wh) / 1000;
c.delivered_kWh_python = sum(ref.E_del_Wh) / 1000;
c.shields_matlab = sum(Lc.n_sw + Lc.n_sp);
c.shields_python = sum(ref.n_shield_w + ref.n_shield_p);
c.violations_matlab = sum(Lc.n_viol);
c.actions_charge_idle_bypass = [sum(Lc.a_policy == 0), sum(Lc.a_policy == 1), sum(Lc.a_policy == 2)];
c.pass = c.action_agreement_pct == 100 && c.max_abs_dT_top_C < 1e-6 && c.shields_matlab == c.shields_python && c.violations_matlab == 0;
rep.C_closed_loop = c;
fprintf('[C closed loop] action agreement = %.3f %%  max|dT_top| = %.3g C  delivered %.3f vs %.3f kWh  shields %d vs %d  -> %s\n', ...
    c.action_agreement_pct, c.max_abs_dT_top_C, c.delivered_kWh_matlab, c.delivered_kWh_python, c.shields_matlab, c.shields_python, tf(c.pass));

rep.overall_pass = a.pass && c.pass && rep.A_policy_on_python_obs.action_agreement_pct == 100;
rep.controller = struct('algo', 'sac', 'tag', tw.sac.tag, 'sha256', tw.sac.sha256, 'selection', tw.sac.selection);
rep.regime = regime;  rep.year = year;  rep.hours = N;  rep.matlab = version;
rep.generated = char(datetime('now', 'Format', 'yyyy-MM-dd''T''HH:mm:ss'));
fid = fopen(fullfile(exportDir, 'validation_sac_report.json'), 'w');
fwrite(fid, jsonencode(rep, 'PrettyPrint', true));  fclose(fid);
fprintf('[validate SAC] regime %d overall: %s  (report: export_r%d/validation_sac_report.json)\n', regime, tf(rep.overall_pass), regime);
report = rep;
end

function s = tf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end
