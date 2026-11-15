function R = check_energy_balance(regime)
%CHECK_ENERGY_BALANCE  Checks of the joint plan (section 2.4), same tests and thresholds as Rajasthan's.
%
%   R = check_energy_balance(1);   % writes ../results_campaign/energy_balance_report_r1.json and ../export_r1/restart_check.json
%
%   1 restart A    restart from a stored hourly state and replay the same inputs -> same state (difference must be 0)
%   2 restart B    run_hold_test from a stored state reproduces an independent full run (sun off, no draw) exactly
%   3 closure      collector heat - net draw heat - wall loss = change of stored energy, within 0.1 % (B0 and PPO)
%   4 PCM swap     swap_pcm (O2's rules re-derived in MATLAB) reproduces O2's own vectors for all three O1 PCMs; the
%                  melt band holds exactly L + wall sensible heat; enthalpy <-> melt fraction round-trips
%   5 no-PCM hold  plain tank with a uniform loss cools as the exponential (implicit-Euler solution exactly)
%   6 zero input   no sun, no draw, ambient = tank temperature -> nothing changes
%   7 sub-step     halving the 150 s step moves annual delivered energy < 0.05 % (O2's gate; reported, NOT relaxed),
%                  plus where the change comes from (melting hours vs sensible-heat hours), PCM and water-only tank
if nargin < 1 || isempty(regime), regime = 1; end
here = fileparts(mfilename('fullpath')); addpath(here);
tw = load_twin_params(twin_export_dir(regime), 2023);
C = load_campaign(regime); K = C.base.K;
W = tw.wx.signals.values;
R = struct();
fprintf('\n=== check_energy_balance, Uttarakhand regime %d, 2023 ===\n', regime);

% ---- 1. restart A ----
n1 = 600; t0 = 200;
L = simulate_hours(tw, W, K, 0, 0, [], struct('n', n1));
T = L.Tnodes(t0, :)'; h = L.hnodes(t0, :)';
for t = t0 + 1:n1
    [T, h] = pcm_plant_hour(W(t, 2), W(t, 3), round(W(t, 4)), L.a_cmd(t), T, h, K);
end
R.restart_replay_max_dT_C = max(abs(T - L.Tnodes(n1, :)'));
R.restart_replay_max_dh_Jkg = max(abs(h - L.hnodes(n1, :)'));
R.restart_replay_pass = R.restart_replay_max_dT_C == 0 && R.restart_replay_max_dh_Jkg == 0;
report('restart A (replay from stored state)', R.restart_replay_pass, sprintf('max dT %.2e C, max dh %.2e J/kg', R.restart_replay_max_dT_C, R.restart_replay_max_dh_Jkg));

% ---- 2. restart B ----
rows17 = find(W(:, 4) == 17);
t0 = rows17(find(rows17 > 150 * 24, 1)); H = 72;
K0 = K; K0.demand24 = zeros(24, 1);
W2 = W(1:t0 + H, :); W2(t0 + 1:t0 + H, 2) = 0;
L0 = simulate_hours(tw, W2, K0, 1, 0, []);
Rh = run_hold_test(K, W, L0.Tnodes(t0, :)', L0.hnodes(t0, :)', t0 + 1, H);
dTop = max(abs(Rh.Ttop(2:end) - L0.T_top(t0 + 1:t0 + H)));
dEnd = max(abs(Rh.T_end - L0.Tnodes(t0 + H, :)'));
dEs = max(abs(Rh.E_stored_kWh(2:end) - L0.E_stored_kWh(t0 + 1:t0 + H)));
R.restart_hold_max_dTtop_C = dTop; R.restart_hold_max_dTnodes_C = dEnd; R.restart_hold_max_dEstored_kWh = dEs;
R.restart_hold_start_row = t0; R.restart_hold_f_at_start = L0.f_melt(t0);
R.restart_hold_pass = dTop == 0 && dEnd == 0 && dEs == 0;
report('restart B (run_hold_test vs full run)', R.restart_hold_pass, sprintf('max dTtop %.2e, max dT nodes %.2e C, dE %.2e kWh, melt fraction at start %.2f', dTop, dEnd, dEs, L0.f_melt(t0)));
RC = struct('restart_replay_max_dT_C', R.restart_replay_max_dT_C, 'restart_replay_max_dh_Jkg', R.restart_replay_max_dh_Jkg, ...
    'restart_hold_max_dTtop_C', dTop, 'restart_hold_max_dTnodes_C', dEnd, 'restart_hold_max_dEstored_kWh', dEs, ...
    'pass', R.restart_replay_pass && R.restart_hold_pass);
fid = fopen(fullfile(twin_export_dir(regime), 'restart_check.json'), 'w'); fwrite(fid, jsonencode(RC, 'PrettyPrint', true)); fclose(fid);

% ---- 3. closure ----
nC = 4800; nmP = {'PPO', 'B0'};
for pm = [1 0]
    Lc = simulate_hours(tw, W, K, pm, 0, [], struct('n', nC));
    dE_Wh = diff([Lc.rec0(7); Lc.E_stored_kWh]) * 1000;
    flux = Lc.Q_coll_Wh - Lc.Q_load_net_Wh - Lc.Q_loss_Wh;
    nm = nmP{pm + 1};
    R.(['closure_' nm '_total_residual_pct']) = abs(sum(flux) - sum(dE_Wh)) / sum(Lc.Q_coll_Wh) * 100;
    R.(['closure_' nm '_max_hourly_residual_Wh']) = max(abs(dE_Wh - flux));
    R.(['closure_' nm '_Q_coll_kWh']) = sum(Lc.Q_coll_Wh) / 1000;
    R.(['closure_' nm '_pass']) = R.(['closure_' nm '_total_residual_pct']) < 0.1;
    report(sprintf('closure %s (%d h)', nm, nC), R.(['closure_' nm '_pass']), sprintf('residual %.2e %% of collector heat (limit 0.1 %%), worst hour %.2e Wh', ...
        R.(['closure_' nm '_total_residual_pct']), R.(['closure_' nm '_max_hourly_residual_Wh'])));
end

% ---- 4. PCM swap / latent heat ----
ok4 = true; msg4 = '';
for i = 1:numel(C.o1)
    pc = C.o1(i);
    ib = find(strcmp({C.cases.pcm}, pc.name) & abs([C.cases.flow_mult] - 1) < 1e-9, 1);
    Ko2 = C.cases(ib).K;
    [Ks, hs0] = swap_pcm(K, pc);
    idx = [9:15 24];
    dP = max(abs(Ks.P(idx) - Ko2.P(idx)) ./ max(abs(Ko2.P(idx)), 1));
    dh = max(abs(hs0 - Ko2.h0) ./ max(abs(Ko2.h0), 1));
    span = Ks.P(11) + Ks.P(14) * (Ks.P(10) - Ks.P(9));
    hS = (Ks.P(12) + Ks.P(14)) * Ks.P(9); hL = hS + span;
    f = zeros(3, 1); hv = [hS, hS + 0.5 * span, hL];
    for q = 1:3
        r = initial_record(Ks.T0, hv(q) * ones(Ks.N, 1), Ks); f(q) = r(5);
    end
    e2 = max(abs(f - [0; 0.5; 1]));
    mass = Ks.P(24) * sum(Ks.n_caps);
    e1 = abs(mass * span - mass * (pc.latent_heat_kJ_kg * 1000 + Ks.P(14) * 2)) / (mass * pc.latent_heat_kJ_kg * 1000);
    ok4 = ok4 && dP < 1e-12 && dh < 1e-12 && e1 < 1e-12 && e2 < 1e-9;
    R.latent.(sprintf('pcm%d', i)) = struct('name', pc.name, 'PCM_mass_kg', mass, 'latent_total_kJ', mass * pc.latent_heat_kJ_kg, ...
        'max_rel_dP_vs_O2', dP, 'max_rel_dh0_vs_O2', dh, 'band_err', e1, 'melt_frac_roundtrip_err', e2);
    msg4 = [msg4 sprintf('%s: %.2f kg x %.0f kJ/kg, dP vs O2 %.1e; ', pc.name, mass, pc.latent_heat_kJ_kg, dP)]; %#ok<AGROW>
end
R.latent_pass = ok4;
report('PCM swap reproduces O2 / latent heat', ok4, msg4);

% ---- 5. plain-tank hold = exponential ----
Kp = C.water_only; Ku = Kp; Ku.loss_ua(:) = mean(Kp.loss_ua); Ku.m_w(:) = mean(Kp.m_w);
Tamb = 20; Tst = 60; Wc = [(1:120)', zeros(120, 1), Tamb * ones(120, 1), mod((0:119)' + 5, 24)];
Rp = run_hold_test(Ku, Wc, Tst * ones(Ku.N, 1), zeros(Ku.N, 1), 1, 72);
Ra = run_hold_test(Kp, Wc, Tst * ones(Kp.N, 1), zeros(Kp.N, 1), 1, 72);
UA = sum(Ku.loss_ua); M = sum(Ku.m_w) * Ku.P(1); tau_c = M / UA;
t_h = (0:72)' * 3600; T_exact = Tamb + (Tst - Tamb) * exp(-t_h / tau_c);
nst = round(3600 / Ku.P(6));
T_disc = Tamb + (Tst - Tamb) * (1 + Ku.P(6) / tau_c) .^ (-nst * (0:72)');
R.exp_hold_max_dev_vs_discrete_K = max(abs(Rp.Tmean - T_disc));
R.exp_hold_max_dev_vs_exact_K = max(abs(Rp.Tmean - T_exact));
R.exp_hold_real_loss_vector_dev_K = max(abs(Ra.Tmean - T_exact));
R.exp_hold_time_constant_h = tau_c / 3600;
R.exp_hold_pass = R.exp_hold_max_dev_vs_discrete_K < 1e-6 && R.exp_hold_max_dev_vs_exact_K < 0.02;
report('plain-tank hold is an exponential', R.exp_hold_pass, sprintf('time constant %.1f h; deviation %.1e K from implicit Euler, %.1e K from exp(-t/tau); real loss vector %.2f K', ...
    tau_c / 3600, R.exp_hold_max_dev_vs_discrete_K, R.exp_hold_max_dev_vs_exact_K, R.exp_hold_real_loss_vector_dev_K));

% ---- 6. zero input ----
Ta = 25; Wz = [(1:100)', zeros(100, 1), Ta * ones(100, 1), mod((0:99)' + 5, 24)];
T = Ta * ones(K.N, 1); h = (K.P(12) + K.P(14)) * Ta * ones(K.N, 1);
Rz = run_hold_test(K, Wz, T, h, 1, 72);
capn = K.n_caps > 0;
R.zero_input_max_drift_C = max(abs([Rz.Ttop; Rz.Tbot; Rz.Tmean] - Ta));
R.zero_input_max_dh_Jkg = max(abs(Rz.h_end(capn) - h(capn)));
R.zero_input_pass = R.zero_input_max_drift_C < 1e-9 && R.zero_input_max_dh_Jkg < 1e-6;
report('zero input stays put', R.zero_input_pass, sprintf('max drift %.2e C, max dh %.2e J/kg', R.zero_input_max_drift_C, R.zero_input_max_dh_Jkg));

% ---- 7. sub-step gate + attribution (B0, PCM and water-only) ----
gate = 0.05;
for arm = {'pcm', 'plain'}
    if strcmp(arm{1}, 'pcm'), Ka = K; else, Ka = C.water_only; end
    dts = [Ka.P(6), Ka.P(6) / 2, Ka.P(6) / 4]; Ls = cell(1, 3);
    for k = 1:3
        Kk = Ka; Kk.P(6) = dts(k); Ls{k} = simulate_hours(tw, W, Kk, 1, 0, []);
    end
    for pr = [1 2; 2 3]'
        a = Ls{pr(1)}; b = Ls{pr(2)};
        d = b.E_del_Wh - a.E_del_Wh; tot = sum(a.E_del_Wh);
        f0 = [0; a.f_melt(1:end-1)];
        inband = (a.f_melt > 1e-3 & a.f_melt < 1 - 1e-3) | (f0 > 1e-3 & f0 < 1 - 1e-3) | abs(a.f_melt - f0) > 1e-6 | (b.f_melt > 1e-3 & b.f_melt < 1 - 1e-3);
        key = strrep(sprintf('%s_%gs_to_%gs', arm{1}, dts(pr(1)), dts(pr(2))), '.', 'p');
        r = struct('total_change_pct', (sum(b.E_del_Wh) - tot) / tot * 100, 'total_change_kWh', sum(d) / 1000, ...
            'melting_hours', sum(inband), 'other_hours', sum(~inband), 'diff_melting_hours_kWh', sum(d(inband)) / 1000, ...
            'diff_other_hours_kWh', sum(d(~inband)) / 1000, 'diff_pump_on_hours_kWh', sum(d(a.Q_coll_Wh > 0)) / 1000, ...
            'gate_pct', gate, 'gate_met', abs((sum(b.E_del_Wh) - tot) / tot * 100) < gate);
        R.substep.(key) = r;
        fprintf('[sub-step] %-5s %5.1f -> %5.1f s: annual change %+.4f %% (%+.3f kWh)  melting hours %d: %+.3f kWh  other hours %d: %+.3f kWh  gate %s\n', ...
            arm{1}, dts(pr(1)), dts(pr(2)), r.total_change_pct, r.total_change_kWh, r.melting_hours, r.diff_melting_hours_kWh, ...
            r.other_hours, r.diff_other_hours_kWh, ternary(r.gate_met, 'met', 'NOT met'));
    end
end
R.substep_pass = R.substep.pcm_150s_to_75s.gate_met;
report('sub-step gate (PCM tank, 150 s -> 75 s)', R.substep_pass, sprintf('change %.4f %% (gate %.2f %%, not relaxed)', R.substep.pcm_150s_to_75s.total_change_pct, gate));

R.overall_pass = R.restart_replay_pass && R.restart_hold_pass && R.closure_B0_pass && R.closure_PPO_pass && ...
    R.latent_pass && R.exp_hold_pass && R.zero_input_pass;
fprintf('[check_energy_balance] correctness checks overall: %s   (sub-step gate reported separately: %s)\n', tf(R.overall_pass), tf(R.substep_pass));
outDir = fullfile(here, '..', 'results_campaign'); if ~isfolder(outDir), mkdir(outDir); end
fid = fopen(fullfile(outDir, sprintf('energy_balance_report_r%d.json', regime)), 'w'); fwrite(fid, jsonencode(R, 'PrettyPrint', true)); fclose(fid);
end

function report(name, ok, msg)
fprintf('[%s] %-42s %s\n', tf(ok), name, msg);
end

function s = tf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
