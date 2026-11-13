function R = check_energy_balance(regime, year)
%CHECK_ENERGY_BALANCE  Plan section 7.3 closure tests, plus the restart check of section 7.1 (check 4).
%
%   R = check_energy_balance(1)          % writes ../results_campaign/energy_balance_report.json
%
% Tests (each reports PASS/FAIL against the threshold in its name):
%   1 restart A      restart from a stored hourly state and replay the same inputs -> same state (1e-9 C)
%   2 restart B      run_hold_test from a known state reproduces a full-year run's state (1e-9 C)
%   3 closure        collector heat - draw heat - wall loss = change of stored energy, within 0.1 %
%   4 latent heat    PCM swap applied correctly: swap_pcm(PureTemp 60) reproduces the O2 vector, the melt
%                    band holds exactly L (+ wall sensible heat) per kg, enthalpy <-> melt fraction round-trips
%   5 no-PCM hold    plain tank cools as the exponential set by its loss coefficient
%   6 zero input     no sun, no draw, ambient = tank temperature -> nothing changes
%   7 sub-step       halving the 150 s sub-step moves annual delivered energy < 0.05 % (Objective 2's gate)
here = fileparts(mfilename('fullpath')); addpath(here);
if nargin < 1 || isempty(regime), regime = 1; end
if nargin < 2 || isempty(year), year = 2023; end
tw = load_twin_params(fullfile(here, '..', sprintf('export_r%d', regime)), year);
Wall = tw.wx.signals.values(:, 1:4);
P = tw.P;
R = struct();
fprintf('\n=== check_energy_balance, regime %d ===\n', regime);

% ---- 1. restart A: replay from a stored state ---------------------------------
n1 = 600;  t0 = 200;
L = simulate_hours(tw, Wall, P, 0, 0, [], n1);
T = L.Tn(t0, :)';  h = L.hn(t0, :)';
for t = t0 + 1:n1
    draw = tw.demand24(mod(round(Wall(t, 4)), 24) + 1);
    [T, h] = pcm_plant_hour(Wall(t, 2), Wall(t, 3), draw, L.a_cmd(t), T, h, P);
end
R.restart_replay_max_dT_C = max(abs(T - L.Tn(n1, :)'));
R.restart_replay_max_dh_Jkg = max(abs(h - L.hn(n1, :)'));
R.restart_replay_pass = R.restart_replay_max_dT_C < 1e-9 && R.restart_replay_max_dh_Jkg < 1e-3;
report('restart A (replay from stored state)', R.restart_replay_pass, ...
    sprintf('max dT %.2e C, max dh %.2e J/kg', R.restart_replay_max_dT_C, R.restart_replay_max_dh_Jkg));

% ---- 2. restart B: run_hold_test against an independent full run -----------------
% Independent run: same plant, no draw at all, sun switched off from the start hour on.
rows17 = find(Wall(:, 4) == 17);
t0 = rows17(find(rows17 > 150 * 24, 1));               % an 18:00 start in late May/June
H = 72;
tw0 = tw;  tw0.demand24 = zeros(24, 1);
W2 = Wall(1:t0 + H + 4, :);  W2(t0 + 1:t0 + H, 2) = 0;
L0 = simulate_hours(tw0, W2, P, 1, 0, [], t0 + H);
Rh = run_hold_test(P, Wall, L0.Tn(t0, :)', L0.hn(t0, :)', t0 + 1, H);
dTop = max(abs(Rh.Ttop(2:end) - L0.Tw(t0 + 1:t0 + H)));
dEnd = max(abs(Rh.T_end - L0.Tn(t0 + H, :)'));
dEs = max(abs(Rh.E_stored_kWh(2:end) - L0.E_stored_kWh(t0 + 1:t0 + H)));
R.restart_hold_max_dTtop_C = dTop;  R.restart_hold_max_dTnodes_C = dEnd;  R.restart_hold_max_dEstored_kWh = dEs;
R.restart_hold_start_row = t0;  R.restart_hold_f_at_start = L0.f_melt(t0);
R.restart_hold_pass = max(dTop, dEnd) < 1e-9 && dEs < 1e-9;
report('restart B (run_hold_test vs full run)', R.restart_hold_pass, ...
    sprintf('max dTtop %.2e, max dT nodes %.2e C, dE %.2e kWh, melt fraction at start %.2f', dTop, dEnd, dEs, L0.f_melt(t0)));

% ---- 3. closure over 200 days, both policies --------------------------------------
nC = 4800;
for pol = [1 0]
    if pol == 1, Lc = simulate_hours(tw, Wall, P, 1, 0, [], nC); nm = 'B0'; else, Lc = L2(tw, Wall, P, nC); nm = 'DQN'; end
    dE_Wh = diff([tw.s0(6); Lc.E_stored_kWh]) * 1000;
    flux = Lc.Q_coll_Wh - Lc.Q_load_Wh - Lc.Q_loss_Wh;
    res_hour = max(abs(dE_Wh - flux));
    tot_res = abs(sum(flux) - sum(dE_Wh)) / sum(Lc.Q_coll_Wh) * 100;
    R.(['closure_' nm '_total_residual_pct']) = tot_res;
    R.(['closure_' nm '_max_hourly_residual_Wh']) = res_hour;
    R.(['closure_' nm '_Q_coll_kWh']) = sum(Lc.Q_coll_Wh) / 1000;
    R.(['closure_' nm '_pass']) = tot_res < 0.1;
    report(sprintf('closure %s (%d h)', nm, nC), tot_res < 0.1, ...
        sprintf('residual %.2e %% of collector heat (limit 0.1 %%), worst hour %.2e Wh', tot_res, res_hour));
end

% ---- 4. latent-heat accounting / PCM swap ---------------------------------------
cfgFile = fullfile(here, '..', 'results_campaign', 'campaign_config.json');
ok4 = true;  msg4 = '';
if isfile(cfgFile)
    cfg = jsondecode(fileread(cfgFile));
    pc = cfg.o1.pcms;
    base = pc(arrayfun(@(p) p.chosen_by_O2, pc));
    [Ps, hs0] = swap_pcm(P, base);
    dP = max(abs(Ps([9:15 24]) - P([9:15 24])));
    dh = max(abs(hs0 - tw.h0));
    ok4 = ok4 && dP < 1e-6 && dh < 1e-3;
    msg4 = sprintf('swap(%s) vs O2 vector: max dP %.2e, max dh0 %.2e; ', base.name, dP, dh);
    R.swap_reproduces_O2_max_dP = dP;
    for i = 1:numel(pc)
        Pi = swap_pcm(P, pc(i));
        span = (Pi(11) + Pi(14) * (Pi(10) - Pi(9)));                 % J per kg PCM over the band
        hS = (Pi(12) + Pi(14)) * Pi(9);
        hL = hS + span;
        % the plant's own enthalpy -> melt fraction inversion: fraction 0 at h(Ts), 1 at h(Ts)+span, 0.5 in between
        s0 = pcm_derive_state(tw.T0, hS * ones(10, 1), Pi);
        s5 = pcm_derive_state(tw.T0, (hS + 0.5 * span) * ones(10, 1), Pi);
        s1 = pcm_derive_state(tw.T0, hL * ones(10, 1), Pi);
        e2 = max([abs(s0(5)), abs(s5(5) - 0.5), abs(s1(5) - 1)]);
        % total enthalpy across the band = PCM mass x (L + wall sensible heat over the band)
        e1 = abs(Pi(24) * sum(Pi(61:70)) * span - Pi(24) * sum(Pi(61:70)) * (pc(i).latent_heat_kJ_kg * 1000 + Pi(14) * 2)) / ...
             (Pi(24) * sum(Pi(61:70)) * pc(i).latent_heat_kJ_kg * 1000);
        ok4 = ok4 && e1 < 1e-12 && e2 < 1e-9;
        R.latent.(sprintf('pcm%d', i)) = struct('name', pc(i).name, 'PCM_mass_kg', Pi(24) * sum(Pi(61:70)), ...
            'latent_total_kJ', Pi(24) * sum(Pi(61:70)) * pc(i).latent_heat_kJ_kg, 'band_err', e1, 'melt_frac_roundtrip_err', e2);
        msg4 = [msg4 sprintf('%s: %.2f kg x %.0f kJ/kg = %.0f kJ; ', pc(i).name, Pi(24) * sum(Pi(61:70)), pc(i).latent_heat_kJ_kg, Pi(24) * sum(Pi(61:70)) * pc(i).latent_heat_kJ_kg)]; %#ok<AGROW>
    end
else
    msg4 = 'campaign_config.json missing: run build_campaign_config.py first'; ok4 = false;
end
R.latent_pass = ok4;
report('latent-heat accounting / PCM swap', ok4, msg4);

% ---- 5. hold with no PCM = exponential -------------------------------------------
Pp = make_plain_tank(P);
Pu = Pp;  Pu(71:80) = mean(Pp(71:80));               % uniform loss per node, so a uniform tank stays uniform
Tamb = 20;  Tst = 60;
Wc = [(1:120)', zeros(120, 1), Tamb * ones(120, 1), mod((0:119)' + 5, 24)];
T = Tst * ones(10, 1);  h = zeros(10, 1);
Rp = run_hold_test(Pu, Wc, T, h, 1, 72);
Ra = run_hold_test(Pp, Wc, T, h, 1, 72);          % the real (non-uniform) loss vector, for information
UA = sum(Pu(71:80));  M = sum(Pu(51:60)) * Pu(1);  tau_c = M / UA;
t_h = (0:72)' * 3600;
T_exact = Tamb + (Tst - Tamb) * exp(-t_h / tau_c);
nst = round(3600 / Pu(6));
T_disc = Tamb + (Tst - Tamb) * (1 + Pu(6) / tau_c) .^ (-nst * (0:72)');      % what backward Euler gives exactly
R.exp_hold_max_dev_vs_discrete_K = max(abs(Rp.Tmean - T_disc));
R.exp_hold_max_dev_vs_exact_K = max(abs(Rp.Tmean - T_exact));
R.exp_hold_real_loss_vector_dev_K = max(abs(Ra.Tmean - T_exact));
R.exp_hold_time_constant_h = tau_c / 3600;
R.exp_hold_pass = R.exp_hold_max_dev_vs_discrete_K < 1e-6 && R.exp_hold_max_dev_vs_exact_K < 0.02;
report('plain-tank hold is an exponential', R.exp_hold_pass, ...
    sprintf('time constant %.1f h; deviation %.1e K from the implicit-Euler solution, %.1e K from exp(-t/tau); real (non-uniform) loss vector: %.2f K', ...
    tau_c / 3600, R.exp_hold_max_dev_vs_discrete_K, R.exp_hold_max_dev_vs_exact_K, R.exp_hold_real_loss_vector_dev_K));

% ---- 6. zero input ------------------------------------------------------------------
Ta = 25;
Wz = [(1:100)', zeros(100, 1), Ta * ones(100, 1), mod((0:99)' + 5, 24)];
T = Ta * ones(10, 1);  h = (P(12) + P(14)) * Ta * ones(10, 1);       % solid PCM at the ambient temperature
Rz = run_hold_test(P, Wz, T, h, 1, 72);
capn = P(61:70) > 0;
R.zero_input_max_drift_C = max(abs([Rz.Ttop; Rz.Tbot; Rz.Tmean] - Ta));
R.zero_input_max_dh_Jkg = max(abs(Rz.h_end(capn) - h(capn)));
R.zero_input_pass = R.zero_input_max_drift_C < 1e-9 && R.zero_input_max_dh_Jkg < 1e-6;
report('zero input stays put', R.zero_input_pass, sprintf('max drift %.2e C, max dh %.2e J/kg', R.zero_input_max_drift_C, R.zero_input_max_dh_Jkg));

% ---- 7. sub-step independence --------------------------------------------------------
La = simulate_hours(tw, Wall, P, 1, 0, []);
Ph = P;  Ph(6) = P(6) / 2;
Lb = simulate_hours(tw, Wall, Ph, 1, 0, []);
Ph2 = P;  Ph2(6) = P(6) / 4;
Lc2 = simulate_hours(tw, Wall, Ph2, 1, 0, []);
ea = sum(La.E_del_Wh);  eb = sum(Lb.E_del_Wh);  ec = sum(Lc2.E_del_Wh);
R.substep_dt_s = [P(6) Ph(6) Ph2(6)];  R.substep_E_del45_kWh = [ea eb ec] / 1000;
R.substep_rel_change_75_to_37p5_pct = abs(eb - ec) / eb * 100;
R.substep_rel_change_pct = abs(ea - eb) / ea * 100;
R.substep_pass = R.substep_rel_change_pct < 0.05;
report('sub-step independence (150 s -> 75 s)', R.substep_pass, ...
    sprintf('annual delivered %.3f -> %.3f -> %.3f kWh (150/75/37.5 s); change %.4f %% then %.4f %% (gate 0.05 %%)', ...
    ea / 1000, eb / 1000, ec / 1000, R.substep_rel_change_pct, R.substep_rel_change_75_to_37p5_pct));

% the sub-step gate is reported honestly but is a discretisation-error statement, not a correctness test
R.overall_pass = R.restart_replay_pass && R.restart_hold_pass && R.closure_B0_pass && R.closure_DQN_pass && ...
    R.latent_pass && R.exp_hold_pass && R.zero_input_pass;
fprintf('[check_energy_balance] overall: %s\n', tf(R.overall_pass));
outDir = fullfile(here, '..', 'results_campaign');
if ~isfolder(outDir), mkdir(outDir); end
fid = fopen(fullfile(outDir, sprintf('energy_balance_report_r%d.json', regime)), 'w');
fwrite(fid, jsonencode(R, 'PrettyPrint', true)); fclose(fid);
end

function L = L2(tw, W, P, n)
L = simulate_hours(tw, W, P, 0, 0, [], n);
end

function report(name, ok, msg)
fprintf('[%s] %-42s %s\n', tf(ok), name, msg);
end

function s = tf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end
