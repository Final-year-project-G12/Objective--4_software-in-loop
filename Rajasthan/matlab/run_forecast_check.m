function T = run_forecast_check()
%RUN_FORECAST_CHECK  Perfect against smart-persistence forecast for the released controllers (Objective 3's "optimism check").
%
%   T = run_forecast_check;   % writes ../results_campaign/forecast_optimism_2023.csv and ../export_r<k>/validation_smart_forecast.json
%
% The Rajasthan controllers were trained with a PERFECT 3-hour irradiance forecast in the observation (the stored year's own GHI), unlike
% the Tamil Nadu SAC, which was trained with a smart-persistence forecast (Objective 3, plan v2 12.2). Here the look-ahead is replaced by
% Objective 3's smart persistence, GHI_hat(t+h) = Kc(t) * GHI_clear(t+h) (smart_kc.m, the stored clear-sky column; about 9.9 / 21.0 / 36.1 %
% rRMSE at +1 / +2 / +3 h according to Objective 3), WITHOUT retraining: perfect-trained, scored with smart. Next-hour demand stays perfect.
% Step 1 (validation): the MATLAB closed loop with the smart forecast must reproduce Objective 3's Python run with forecast_mode = smart
%   (export_from_python.py --forecast-mode smart): 100 % identical actions for the SAC; the DQN has one numerical near-tie hour (see below).
% Step 2 (result): 2023 delivery, guard-band hours, % of B0 and the 12-evening hold test, perfect against smart, for the DQN (regime 1) and the
%   SAC (regimes 0, 1, 2). B0 and the plain tank do not read the observation and are unaffected.
% Assumption: the clear-sky column is the stored one (what Objective 3's offline study uses); a live analytic clear-sky model would add error
%   (Objective 3: 17.5 % rRMSE against the stored column), so these are an optimistic reading of a deployed forecast.
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = fullfile(here, '..', 'results_campaign');
rows = {};
items = {1, 'DQN', 0; 1, 'SAC', 2; 0, 'SAC', 2; 2, 'SAC', 2};
for k = 1:size(items, 1)
    regime = items{k, 1};  name = items{k, 2};  mode = items{k, 3};
    ed = fullfile(here, '..', sprintf('export_r%d', regime));
    tw = load_twin_params(ed, 2023);
    W = tw.wx.signals.values(:, 1:4);  P = tw.P;
    cs = readmatrix(fullfile(ed, 'clearsky_2023.csv'));  clear = cs(:, 2);
    if strcmp(name, 'DQN')
        ref = readtable(fullfile(ed, 'reference_smart_2023.csv'));
    else
        ref = readtable(fullfile(ed, 'reference_sac_smart_2023.csv'));
    end
    % ---- step 1: validation against the Python smart-forecast run ----
    Ls = simulate_hours(tw, W, P, mode, 0, [], [], NaN, [], clear);
    v.regime = regime;  v.controller = name;
    v.action_agreement_pct = 100 * mean(Ls.a_policy == ref.action(1:numel(Ls.a_policy)));
    v.max_abs_dT_top_C = max(abs(Ls.Tw - ref.T_w_C(1:numel(Ls.Tw))));
    v.delivered_kWh_matlab = sum(Ls.E_del_Wh) / 1000;
    v.delivered_kWh_python = sum(ref.E_del_Wh) / 1000;
    v.shields_matlab = sum(Ls.n_sw + Ls.n_sp);
    v.shields_python = sum(ref.n_shield_w + ref.n_shield_p);
    v.max_abs_dobs = max(max(abs(Ls.obs - [ref.obs0 ref.obs1 ref.obs2 ref.obs3 ref.obs4 ref.obs5 ref.obs6 ref.obs7 ref.obs8 ref.obs9 ...
        ref.obs10 ref.obs11 ref.obs12 ref.obs13 ref.obs14 ref.obs15 ref.obs16])));
    % a mismatch is tolerated only at a numerical near-tie: the DQN's two best Q-values (about -3e4) closer than 1e-5 relative, i.e. at
    % float32 resolution (MATLAB computes the Q-network in double, PyTorch in float32); the SAC is evaluated in single precision and matches exactly
    mm = find(Ls.a_policy ~= ref.action(1:numel(Ls.a_policy)));
    v.mismatch_hours = numel(mm);
    v.mismatch_max_rel_Q_gap = 0;
    if ~isempty(mm) && strcmp(name, 'DQN')
        qs = sort([ref.q0(mm) ref.q1(mm) ref.q2(mm)], 2, 'descend');
        v.mismatch_max_rel_Q_gap = max((qs(:, 1) - qs(:, 2)) ./ abs(qs(:, 1)));
    elseif ~isempty(mm)
        v.mismatch_max_rel_Q_gap = Inf;
    end
    v.delivered_rel_diff_pct = 100 * abs(v.delivered_kWh_matlab - v.delivered_kWh_python) / v.delivered_kWh_python;
    v.pass = v.action_agreement_pct >= 99.9 && v.mismatch_max_rel_Q_gap < 1e-5 && v.delivered_rel_diff_pct < 0.05;
    fprintf('[smart forecast, validate] regime %d %s: actions %.3f %%  max|dT| %.2g  delivered %.3f vs %.3f kWh  max|d obs| %.2g -> %s\n', ...
        regime, name, v.action_agreement_pct, v.max_abs_dT_top_C, v.delivered_kWh_matlab, v.delivered_kWh_python, v.max_abs_dobs, tf(v.pass));
    fid = fopen(fullfile(ed, ['validation_smart_forecast_' lower(name) '.json']), 'w'); fwrite(fid, jsonencode(v, 'PrettyPrint', true)); fclose(fid);
    % ---- step 2: perfect against smart ----
    Lb = simulate_hours(tw, W, P, 1, 0, []);
    win = (Lb.hod >= 18) | (Lb.hod < 9);
    b0 = sum(Lb.E_del_Wh) / 1000;  b0g = sum(Lb.shield_s) / 3600;  b0w = sum(Lb.E_del_Wh(win)) / 1000;
    Lp = simulate_hours(tw, W, P, mode, 0, []);
    rows17 = find(W(:, 4) == 17);  sd = round(linspace(15, 345, 12));
    for fc = {'perfect', 'smart'}
        if strcmp(fc{1}, 'perfect'), L = Lp; else, L = Ls; end
        tau = zeros(numel(sd), 1);  cens = false(numel(sd), 1);
        for s = 1:numel(sd)
            t = rows17(sd(s));
            R = run_hold_test(P, W, L.Tn(t, :)', L.hn(t, :)', t + 1, 72, [30 40 45 50]);
            tau(s) = R.tau(3);  cens(s) = R.censored(3);
        end
        d = sum(L.E_del_Wh) / 1000;  dw = sum(L.E_del_Wh(win)) / 1000;  g = sum(L.shield_s) / 3600;
        rows(end+1, :) = {regime, name, fc{1}, d, dw, g, sum(L.n_viol), 100 * d / b0, 100 * dw / b0w, 100 * (1 - g / b0g), mean(tau), sum(cens)}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'regime', 'controller', 'forecast', 'E_del45_kWh', 'E_del45_window_kWh', 'guard_band_h', 'violations', ...
    'pct_of_B0_delivery', 'pct_of_B0_window', 'shield_cut_vs_B0_pct', 'tau_hold_45C_mean_h', 'tau_hold_45C_censored_n'});
writetable(T, fullfile(outDir, 'forecast_optimism_2023.csv'));
disp(T);
end

function s = tf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end
