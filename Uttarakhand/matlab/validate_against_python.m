function report = validate_against_python(regime, hours, simHours)
%VALIDATE_AGAINST_PYTHON  O4 test-plan step 5 (software-in-the-loop replay):
% prove the MATLAB/Simulink twin reproduces the Uttarakhand Python RL environment.
%
%   validate_against_python            % regime 1, full year, 1 week of Simulink
%   validate_against_python(0, 8760, 0)  % regime 0, skip the (slow) Simulink part
%
% All checks are against <export>/reference_<year>.csv (UKPCMEnv under the
% deterministic PPO policy, fully solid reset, deterministic demand):
%
%  A. Open-loop plant replay: feed pcm_plant_hour.m the SAME actions Python
%     took and compare the thermal state hour by hour. Isolates the physics
%     port (O2 multinode kernel) from the policy port.
%     Pass: max |dT| < 1e-6 C, identical shield and over-limit seconds.
%  A'. Policy only: ppo_policy.m on Python's own normalised observations.
%  B. Closed loop in plain MATLAB (simulate_hours): sensors -> observation ->
%     PPO -> interlock -> plant, ideal sensors. Pass: 100 % identical actions.
%  C. Closed-loop Simulink twin (pcm_drl_twin.slx) for simHours hours.
%     Pass: >= 99.9 % action agreement, delivery within 0.1 %, no hard-limit time.
%
% Writes <export>/validation_report.json.
if nargin < 1 || isempty(regime), regime = 1; end
if nargin < 2 || isempty(hours), hours = 8760; end
if nargin < 3 || isempty(simHours), simHours = 168; end
here = fileparts(mfilename('fullpath')); addpath(here);
exportDir = twin_export_dir(regime);
tw = load_twin_params(exportDir);
assert(~isempty(tw.ref), 'reference_%d.csv missing -- run Uttarakhand/export_from_python.py', tw.year);
ref = tw.ref(1:min(hours, height(tw.ref)), :);
N = height(ref);
W = tw.wx.signals.values;

% ---------------- A. open-loop plant replay ----------------
T = tw.T0; h = tw.h0;
A = zeros(N, 8);   % T_top Tpcm f E_del50 shield_s over_s T_bottom T_mean
for k = 1:N
    [T, h, rec, sc] = pcm_plant_hour(W(k, 2), W(k, 3), round(W(k, 4)), ref.action(k), T, h, tw.K);
    A(k, :) = [rec(1), rec(3), rec(4), rec(12), sc(1) + sc(2), sc(3), rec(20), rec(2)];
end
a.max_abs_dT_top_C = max(abs(A(:, 1) - ref.T_top_C));
a.max_abs_dT_bottom_C = max(abs(A(:, 7) - ref.T_bottom_C));
a.max_abs_dT_mean_C = max(abs(A(:, 8) - ref.T_mean_C));
a.max_abs_dT_pcm_C = max(abs(A(:, 2) - ref.T_pcm_C));
a.max_abs_df_melt = max(abs(A(:, 3) - ref.f_melt));
a.max_abs_dE_del50_Wh = max(abs(A(:, 4) - ref.E_del50_Wh));
a.delivered50_kWh_matlab = sum(A(:, 4)) / 1000;
a.delivered50_kWh_python = sum(ref.E_del50_Wh) / 1000;
a.shield_h_matlab = sum(A(:, 5)) / 3600;
a.shield_h_python = sum(ref.shield_water_s + ref.shield_pcm_s) / 3600;
a.over_limit_h_matlab = sum(A(:, 6)) / 3600;
a.over_limit_h_python = sum(ref.over_limit_s) / 3600;
a.pass = a.max_abs_dT_top_C < 1e-6 && a.max_abs_dT_pcm_C < 1e-6 && abs(a.shield_h_matlab - a.shield_h_python) < 1e-9 ...
    && abs(a.over_limit_h_matlab - a.over_limit_h_python) < 1e-9;
rep.A_open_loop = a;
fprintf('[A open-loop %d h] max|dT_top| %.3g C  max|dT_pcm| %.3g C  max|df| %.3g  E_del50 %.2f vs %.2f kWh  shield %.3f vs %.3f h  -> %s\n', ...
    N, a.max_abs_dT_top_C, a.max_abs_dT_pcm_C, a.max_abs_df_melt, a.delivered50_kWh_matlab, a.delivered50_kWh_python, ...
    a.shield_h_matlab, a.shield_h_python, tf(a.pass));

% ---------------- A'. policy on Python's own observations ----------------
no = tw.n_obs;
O = zeros(no, N);
for k = 1:no, O(k, :) = ref.(sprintf('obs%d', k - 1))'; end
act = zeros(N, 1); mg = zeros(N, 1);
for k = 1:N, [act(k), mg(k)] = ppo_policy(O(:, k), tw.W1, tw.b1, tw.W2, tw.b2, tw.Wa, tw.ba, 0); end
rep.A_policy_on_python_obs.action_agreement_pct = 100 * mean(act == ref.action);
rep.A_policy_on_python_obs.max_abs_dmargin = max(abs(mg - (ref.logit1 - ref.logit0)));
fprintf('[A policy]  action agreement on Python obs = %.3f %%  max|d logit margin| = %.2e\n', ...
    rep.A_policy_on_python_obs.action_agreement_pct, rep.A_policy_on_python_obs.max_abs_dmargin);

% ---------------- A''. smart-persistence forecast (V2 policy only) ----------------
rep.A_forecast = struct('skipped', no ~= 19);
if no == 19
    kc = 1.0; F = zeros(N, 4);
    for k = 1:N
        [fc, kc] = smart_forecast(W(k, 2), W(k, 5), W(k, 6:8)', kc);
        dn = 0; if W(k, 9) >= 0, dn = tw.K.demand24(round(W(k, 9)) + 1); end
        F(k, :) = [fc', dn];
    end
    Rf = [ref.raw15, ref.raw16, ref.raw17, ref.raw18];
    Fs = double(single(F));                       % Python stores the raw vector as float32
    f.max_abs_dGHI_ahead_Wm2 = max(max(abs(Fs(:, 1:3) - Rf(:, 1:3))));
    f.max_abs_ddraw_next_kg = max(abs(Fs(:, 4) - Rf(:, 4)));
    day = W(1:N, 5) > 20;
    f.daytime_hours = sum(day);
    for hh = 1:3                                   % forecast skill vs the true GHI h hours later (daytime)
        tr = [W(1 + hh:N, 2); zeros(hh, 1)];
        e = F(day, hh) - tr(day);
        f.(sprintf('rRMSE_pct_h%d', hh)) = 100 * sqrt(mean(e .^ 2)) / mean(tr(day));
        f.(sprintf('MAE_Wm2_h%d', hh)) = mean(abs(e));
    end
    f.pass = f.max_abs_dGHI_ahead_Wm2 < 1e-3 && f.max_abs_ddraw_next_kg < 1e-6;
    rep.A_forecast = f;
    fprintf('[A forecast] max|dGHI_ahead| %.2e W/m2  max|d draw_next| %.2e kg  rRMSE +1/+2/+3 h = %.1f / %.1f / %.1f %%  -> %s\n', ...
        f.max_abs_dGHI_ahead_Wm2, f.max_abs_ddraw_next_kg, f.rRMSE_pct_h1, f.rRMSE_pct_h2, f.rRMSE_pct_h3, tf(f.pass));
end

% ---------------- B. closed loop, plain MATLAB ----------------
Lc = simulate_hours(tw, W(1:N, :), tw.K, 0, 0, []);
b.action_agreement_pct = 100 * mean(Lc.a_policy == ref.action);
b.max_abs_dT_top_C = max(abs(Lc.T_top - ref.T_top_C));
b.max_abs_dT_pcm_C = max(abs(Lc.Tpcm - ref.T_pcm_C));
b.delivered50_kWh_matlab = sum(Lc.E_del_Wh) / 1000;
b.window_delivered50_kWh_matlab = sum(Lc.E_del_Wh(Lc.in_window > 0.5)) / 1000;
b.window_delivered50_kWh_python = sum(ref.E_del50_Wh(ref.in_window > 0)) / 1000;
b.shield_h_matlab = sum(Lc.shield_w_s + Lc.shield_p_s) / 3600;
b.over_limit_h_matlab = sum(Lc.over_limit_s) / 3600;
b.pass = b.action_agreement_pct == 100 && b.max_abs_dT_top_C < 1e-6;
rep.B_closed_loop_matlab = b;
fprintf('[B closed loop %d h] action agreement %.3f %%  max|dT_top| %.2e  window E_del50 %.2f vs %.2f kWh  -> %s\n', ...
    N, b.action_agreement_pct, b.max_abs_dT_top_C, b.window_delivered50_kWh_matlab, b.window_delivered50_kWh_python, tf(b.pass));

% ---------------- C. closed-loop Simulink twin ----------------
rep.C_simulink = struct('skipped', simHours <= 0);
if simHours > 0
    try
        nS = min(simHours, N);
        out = run_twin(tw, nS, 0, 0);
        c.hours = nS;
        c.action_agreement_pct = 100 * mean(out.a_policy == ref.action(1:nS));
        c.max_abs_dT_top_C = max(abs(out.T_top - ref.T_top_C(1:nS)));
        c.max_abs_dT_pcm_C = max(abs(out.Tpcm - ref.T_pcm_C(1:nS)));
        c.delivered50_kWh_simulink = sum(out.E_del_Wh) / 1000;
        c.delivered50_kWh_python = sum(ref.E_del50_Wh(1:nS)) / 1000;
        c.delivered_rel_err_pct = 100 * abs(c.delivered50_kWh_simulink - c.delivered50_kWh_python) / max(c.delivered50_kWh_python, eps);
        c.over_limit_h = sum(out.over_limit_s) / 3600;
        c.sim_wall_s = out.sim_wall_s;
        c.pass = c.action_agreement_pct >= 99.9 && c.delivered_rel_err_pct < 0.1 && c.over_limit_h == 0;
        rep.C_simulink = c;
        fprintf('[C Simulink %d h] action agreement %.3f %%  max|dT_top| %.2e  E_del50 %.2f vs %.2f kWh  -> %s\n', ...
            nS, c.action_agreement_pct, c.max_abs_dT_top_C, c.delivered50_kWh_simulink, c.delivered50_kWh_python, tf(c.pass));
    catch err
        rep.C_simulink = struct('error', err.message);
        fprintf('[C Simulink] FAILED: %s\n', err.message);
    end
end

rep.regime = regime; rep.year = tw.year; rep.hours = N; rep.label = tw.params.label;
rep.matlab = version; rep.generated = datestr(now, 'yyyy-mm-ddTHH:MM:SS');
rep.agent = tw.agent; rep.n_obs = no;
rep.overall_pass = a.pass && b.pass && rep.A_policy_on_python_obs.action_agreement_pct == 100 && ...
    (no ~= 19 || rep.A_forecast.pass) && ...
    (simHours <= 0 || (isfield(rep.C_simulink, 'pass') && rep.C_simulink.pass));
fid = fopen(fullfile(exportDir, 'validation_report.json'), 'w');
fwrite(fid, jsonencode(rep, 'PrettyPrint', true)); fclose(fid);
fprintf('[validate] overall: %s  (report: %s)\n', tf(rep.overall_pass), fullfile(exportDir, 'validation_report.json'));
report = rep;
end

function s = tf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end
