function run_campaign(passes, tag, over)
%RUN_CAMPAIGN  The simulation matrix of plan section 6, for Rajasthan regime 1, year 2023.
%
%   run_campaign                    % everything: 'core' 'flow' 'regimes' 'seeds' 'scen'
%   run_campaign({'core'})          % just the PCM x controller pass
%   run_campaign({'core','flow'}, '_cal', struct('c', 5.03))   % same matrix with a capsule constant overridden;
%                                   % every output file name gets the suffix, the default run's files are kept
%
% Needs results_campaign/campaign_config.json (python build_campaign_config.py --regime 1).
%
%   core   3 PCMs (Objective 1 top-3) x {B0, DQN} at the Objective 2 flow, + the water-only tank
%          (arm 1), each with the full replay year and 12 retention tests started at 18:00.
%   flow_all every O1 PCM at flow x0.7, x1.0, x1.3 (use a tag, e.g. run_campaign({'flow_all'}, '_flowall'))
%   flow   Objective 2's PCM only, flow x0.7 and x1.3 (x1.0 comes from 'core'), B0 and DQN, + water-only.
%   seeds  the sensor-fault edge case with 20 noise seeds -> mean and 95 % confidence interval.
%   supercool freezing point 2 K below the melting point during the hold (supercooling proxy), PureTemp 60, B0 and DQN
%   sac     the three Rajasthan regimes with the Objective 3 SAC as a fourth arm (water-only B0, PCM + B0, PCM + DQN, PCM + SAC)
%           -> campaign_regimes<tag>.csv  (use run_campaign({'sac'}, '_sac'))
%   swap_sac regime 1: the three O1 PCMs x flow x0.7/1.0/1.3 with the SAC (trained for PureTemp 60 at the O2 flow, so a
%           robustness test of the policy as well as a PCM swap)  -> campaign_results<tag>.csv  (run_campaign({'swap_sac'}, '_swapsac'))
%   regimes the three Rajasthan regimes (own PCM and DQN each) -> campaign_regimes.csv, input of figure F5
%   scen   the six edge cases (run_scenarios.m, unchanged) copied into the campaign tables.
%
% Outputs (../results_campaign/): campaign_results.csv (one row per run, every metric),
% hold_curves/<run_id>.csv, year_trace/<run_id>.csv (the three arms at nominal flow),
% ranking_check.csv (M8), sensor_fault_seeds.csv, scenario_summary_r1.csv, provenance.json.
here = fileparts(mfilename('fullpath')); addpath(here);
if nargin < 1 || isempty(passes), passes = {'core', 'flow', 'regimes', 'supercool', 'seeds', 'scen'}; end
if nargin < 2, tag = ''; end
if nargin < 3, over = struct(); end      % .c (P(35)) and/or .F (P(16)) for the capsule model
regime = 1;  YEAR = 2023;  HOLD_H = 72;  THR = [30 40 45 50];
outDir = fullfile(here, '..', 'results_campaign');
for d = {'hold_curves', 'year_trace', 'figures'}
    if ~isfolder(fullfile(outDir, d{1})), mkdir(fullfile(outDir, d{1})); end
end
cfgFile = fullfile(outDir, 'campaign_config.json');
assert(isfile(cfgFile), 'run build_campaign_config.py first');
cfg = jsondecode(fileread(cfgFile));
assert(cfg.o1.n_clusters == 3, 'Objective 1 cluster count must be 3 for Rajasthan');
pcms = cfg.o1.pcms;
band = cfg.o2.repeatability_band.g_window;
tw = load_twin_params(fullfile(here, '..', sprintf('export_r%d', regime)), YEAR);
Wall = tw.wx.signals.values(:, 1:4);
rows17 = find(Wall(:, 4) == 17);                   % the row that ENDS at 18:00 local
startDays = round(linspace(15, 345, 12));          % 12 start days spread through the year
iO2 = find(arrayfun(@(p) p.chosen_by_O2, pcms));

ctx = struct('tw', tw, 'Wall', Wall, 'pcms', {pcms}, 'rows17', rows17, 'startDays', startDays, ...
    'hyd', cfg.o2.hydraulics, 'HOLD_H', HOLD_H, 'THR', THR, 'outDir', outDir, 'regime', regime, 'year', YEAR, 'band', band, 'tag', tag, 'over', over);

tab = {};                                           % one struct per run
if any(strcmp(passes, 'core'))
    tab{end+1} = do_run(ctx, 'PCM-free', 0, 'B0', 1.0, true);               % arm 1
    for i = 1:numel(pcms)
        tab{end+1} = do_run(ctx, 'PCM+B0', i, 'B0', 1.0, i == iO2);         %#ok<AGROW>  arm 2
        tab{end+1} = do_run(ctx, 'PCM+DQN', i, 'DQN', 1.0, i == iO2);       %#ok<AGROW>  arm 3
    end
end
if any(strcmp(passes, 'flow_all'))
    % full PCM x flow grid for pcm_swap_study.m: all three O1 PCMs at flow x0.7, x1.0, x1.3, B0 and DQN, + water-only tank per flow
    tabA = {};
    for fm = [0.7 1.0 1.3]
        tabA{end+1} = do_run(ctx, 'PCM-free', 0, 'B0', fm, false);               %#ok<AGROW>
        for i = 1:numel(pcms)
            tabA{end+1} = do_run(ctx, 'PCM+B0', i, 'B0', fm, false);             %#ok<AGROW>
            tabA{end+1} = do_run(ctx, 'PCM+DQN', i, 'DQN', fm, false);           %#ok<AGROW>
        end
    end
    writetable(add_gains(struct2table([tabA{:}]), band), fullfile(outDir, ['campaign_results' tag '.csv']));
    fprintf('[campaign] %d runs (full PCM x flow grid) -> campaign_results%s.csv\n', numel(tabA), tag);
end
if any(strcmp(passes, 'flow'))
    for fm = [0.7 1.3]
        tab{end+1} = do_run(ctx, 'PCM-free', 0, 'B0', fm, false);           %#ok<AGROW>
        tab{end+1} = do_run(ctx, 'PCM+B0', iO2, 'B0', fm, false);           %#ok<AGROW>
        tab{end+1} = do_run(ctx, 'PCM+DQN', iO2, 'DQN', fm, false);         %#ok<AGROW>
    end
end

if ~isempty(tab)
    T = struct2table([tab{:}]);
    T = add_gains(T, band);
    writetable(T, fullfile(outDir, ['campaign_results' tag '.csv']));
    fprintf('[campaign] %d runs -> campaign_results.csv\n', height(T));
    if any(strcmp(passes, 'core')), ranking_check(T, pcms, outDir, tag); end
end

if any(strcmp(passes, 'regimes')), regimes_pass(ctx); end
if any(strcmp(passes, 'sac')), regimes_sac_pass(ctx); end
if any(strcmp(passes, 'swap_sac')), swap_sac_pass(ctx, pcms, band); end
if any(strcmp(passes, 'supercool')), supercool_pass(ctx, iO2); end
if any(strcmp(passes, 'seeds')), seeds_pass(ctx); end
if any(strcmp(passes, 'scen')), scen_pass(here, outDir); end
write_provenance(outDir, cfg, tag, over);
disp('CAMPAIGN_DONE_MARKER');
end

% ======================================================================
function r = do_run(c, arm, ip, ctrl, fm, saveTrace)
tw = c.tw;
if ip == 0
    P = make_plain_tank(tw.P);  h0 = tw.h0;  pname = 'none';  prank = 0;
elseif ip < 0                                      % the PCM exported with this regime (used by the 'regimes' pass)
    P = tw.P;  h0 = tw.h0;  pname = tw.params.selected_pcm;  prank = -1;
else
    [P, h0] = swap_pcm(tw.P, c.pcms(ip));  pname = c.pcms(ip).name;  prank = c.pcms(ip).consensus_rank;
end
P(5) = P(5) * fm;
if isfield(c.over, 'c'), P(35) = c.over.c; end      % capsule-model overrides (calibration sensitivity runs)
if isfield(c.over, 'F'), P(16) = c.over.F; end
twr = tw;  twr.h0 = h0;
mode = find(strcmp(ctrl, {'DQN', 'B0', 'SAC'})) - 1;  % simulate_hours: 0 = trained DQN, 1 = B0, 2 = trained SAC
runId = sprintf('%s_%s_%s_f%.1f', strrep(arm, '+', '_'), regexprep(pname, '[^A-Za-z0-9]', ''), ctrl, fm);
runId = strrep(runId, '-', '');
if c.regime ~= 1, runId = sprintf('r%d_%s', c.regime, runId); end
runId = [runId c.tag];
tic;
L = simulate_hours(twr, c.Wall, P, mode, 0, []);
hyd = [];  if c.regime == 1, hyd = c.hyd; end
m = twin_metrics(L, P, 0, hyd);
tYear = toc;

% ---- retention tests (M3) from 12 evenings --------------------------------------
nS = numel(c.startDays);  H = c.HOLD_H;
tau = zeros(nS, numel(c.THR));  cens = false(nS, numel(c.THR));
at = zeros(nS, 4, 4);                               % start x {24,36,48,72} x {Ttop,f,E_rec,E_stored}
qloss = zeros(nS, 3);  Ttop0 = zeros(nS, 1);
curves = cell(nS, 1);
ks = [24 36 48 72];
for s = 1:nS
    t = c.rows17(c.startDays(s));
    R = run_hold_test(P, c.Wall, L.Tn(t, :)', L.hn(t, :)', t + 1, H, c.THR);
    tau(s, :) = R.tau;  cens(s, :) = R.censored;  Ttop0(s) = R.Ttop(1);
    for j = 1:4
        k = ks(j) + 1;
        at(s, j, :) = [R.Ttop(k) R.fmelt(k) R.E_rec_kWh(k) R.E_stored_kWh(k)];
    end
    qloss(s, :) = [R.Q_loss_cum_Wh(25) R.Q_loss_cum_Wh(49) R.Q_loss_cum_Wh(73)];
    curves{s} = [repmat(c.startDays(s), H + 1, 1), (0:H)', R.Ttop, R.Tbot, R.Tmean, R.Tpcm, R.fmelt, ...
                 R.E_stored_kWh, R.E_rec_kWh, R.Q_loss_cum_Wh];
end
cv = array2table(vertcat(curves{:}), 'VariableNames', {'start_day', 'hour', 'T_top_C', 'T_bottom_C', ...
    'T_mean_C', 'T_pcm_C', 'f_melt', 'E_stored_kWh', 'E_rec45_kWh', 'Q_loss_cum_Wh'});
writetable(cv, fullfile(c.outDir, 'hold_curves', [runId '.csv']));
if saveTrace && fm == 1
    writetable(year_trace(L), fullfile(c.outDir, 'year_trace', [runId '.csv']));
end

% ---- one row ----------------------------------------------------------------------
r = struct('run_id', runId, 'state', 'rajasthan', 'regime', c.regime, 'arm', arm, 'pcm', pname, ...
    'pcm_rank', prank, 'controller', ctrl, 'scenario', 'full_year', 'flow_mult', fm, 'seed', 0, 'year', c.year);
fn = fieldnames(m);
for i = 1:numel(fn), r.(fn{i}) = m.(fn{i}); end
r.n_hold_starts = nS;
r.T_top_at_18h_mean_C = mean(Ttop0);
for j = 1:numel(c.THR)
    r.(sprintf('tau_hold_%dC_mean_h', c.THR(j))) = mean(tau(:, j));
    r.(sprintf('tau_hold_%dC_censored_n', c.THR(j))) = sum(cens(:, j));
end
for j = 1:4
    r.(sprintf('T_top_%dh_C', ks(j))) = mean(at(:, j, 1));
    r.(sprintf('f_melt_%dh', ks(j))) = mean(at(:, j, 2));
    r.(sprintf('E_rec45_%dh_kWh', ks(j))) = mean(at(:, j, 3));
    r.(sprintf('E_stored_%dh_kWh', ks(j))) = mean(at(:, j, 4));
end
r.standby_loss_24h_Wh = mean(qloss(:, 1));  r.standby_loss_48h_Wh = mean(qloss(:, 2));  r.standby_loss_72h_Wh = mean(qloss(:, 3));
fprintf('[run] %-40s year %.0f s | E_del45 %.1f kWh (win %.1f) | tau45 %.1f h (%d/%d censored) | guard %.1f h | viol %d\n', ...
    runId, tYear, m.E_del45_kWh, m.E_del45_win_kWh, r.tau_hold_45C_mean_h, r.tau_hold_45C_censored_n, nS, m.guard_band_h, m.hours_over_hard_limit);
end

function Tt = year_trace(L)
n = numel(L.Tw);
Tt = table((1:n)', L.hod, L.GHI, L.T_amb, L.draw_kg, L.a_policy, L.a_cmd, L.a_exec, L.Tw, L.Tbot, L.Tmean, L.Tpcm, ...
    L.f_melt, L.E_stored_kWh, L.E_rec45_kWh, L.E_del_Wh, L.E_unmet_Wh, L.Q_coll_Wh, L.Q_load_Wh, L.Q_loss_Wh, ...
    L.n_sw + L.n_sp, L.shield_s, ...
    'VariableNames', {'hour_idx', 'hod', 'GHI', 'T_amb', 'draw_kg', 'a_policy', 'a_cmd', 'a_exec', 'T_top_C', 'T_bottom_C', ...
    'T_mean_C', 'T_pcm_C', 'f_melt', 'E_stored_kWh', 'E_rec45_kWh', 'E_del_Wh', 'E_unmet_Wh', 'Q_coll_Wh', 'Q_load_Wh', ...
    'Q_loss_Wh', 'shield_trips', 'shield_s'});
for k = 1:10
    Tt.(sprintf('Tnode%d', k)) = L.Tn(:, k);
end
end

function T = add_gains(T, band)
% M4: gain over the water-only tank at the same flow (Objective 2's own yardstick, g_window).
gains = {'E_del45_kWh', 'E_del45_win_kWh', 'E_del50_win_kWh', 'tau_hold_45C_mean_h', 'tau_hold_50C_mean_h', ...
    'E_rec45_24h_kWh', 'E_rec45_48h_kWh'};
for g = gains, T.(['gain_' g{1}]) = nan(height(T), 1); end
T.gain_within_O2_band = false(height(T), 1);
for i = 1:height(T)
    if strcmp(T.arm{i}, 'PCM-free'), continue; end
    j = find(strcmp(T.arm, 'PCM-free') & T.flow_mult == T.flow_mult(i) & T.regime == T.regime(i), 1);
    if isempty(j), continue; end
    for g = gains, T.(['gain_' g{1}])(i) = T.(g{1})(i) - T.(g{1})(j); end
    T.gain_within_O2_band(i) = abs(T.gain_E_del45_win_kWh(i)) < band;
end
end

function ranking_check(T, pcms, outDir, tag)
% M8: twin ordering of the three PCMs (by tau_hold, ties by window energy) vs Objective 1's consensus rank.
out = {};
for ctrl = {'B0', 'DQN'}
    sel = find(strcmp(T.controller, ctrl{1}) & T.flow_mult == 1 & T.pcm_rank > 0);
    [~, ord] = sortrows([-T.tau_hold_45C_mean_h(sel), -T.E_del45_win_kWh(sel)]);
    rk_tau = zeros(numel(sel), 1);  rk_tau(ord) = 1:numel(sel);
    [~, ord2] = sort(-T.E_del45_win_kWh(sel));
    rk_e = zeros(numel(sel), 1);  rk_e(ord2) = 1:numel(sel);
    o1 = T.pcm_rank(sel);
    rs_tau = pearson(o1, rk_tau);  rs_e = pearson(o1, rk_e);
    for q = 1:numel(sel)
        out(end+1, :) = {ctrl{1}, T.pcm{sel(q)}, o1(q), pcms(o1(q)).mc_top3_inclusion_pct, T.tau_hold_45C_mean_h(sel(q)), ...
            T.E_del45_win_kWh(sel(q)), rk_tau(q), rk_e(q), rs_tau, rs_e}; %#ok<AGROW>
    end
end
Tr = cell2table(out, 'VariableNames', {'controller', 'pcm', 'o1_consensus_rank', 'o1_mc_top3_pct', 'tau_hold_45C_mean_h', ...
    'E_del45_win_kWh', 'twin_rank_by_tau_hold', 'twin_rank_by_E_del_win', 'spearman_tau_vs_o1', 'spearman_Edel_vs_o1'});
writetable(Tr, fullfile(outDir, ['ranking_check' tag '.csv']));
disp(Tr);
fprintf('  (three items per cluster: report the correlation with that caveat, not as a conclusion)\n');
end

function r = pearson(a, b)
% Spearman rho = Pearson correlation of the ranks (inputs are already ranks, no ties here)
a = a(:) - mean(a);  b = b(:) - mean(b);
if norm(a) == 0 || norm(b) == 0, r = NaN; else, r = (a' * b) / (norm(a) * norm(b)); end
end

function supercool_pass(c, iO2)
% Plan section 10.1: one sensitivity case with the freezing point shifted down by 2 K (run_hold_test dFreeze).
tw = c.tw;  [P, h0] = swap_pcm(tw.P, c.pcms(iO2));  twr = tw;  twr.h0 = h0;
rows = {};
for ctrl = {'B0', 'DQN'}
    L = simulate_hours(twr, c.Wall, P, double(strcmp(ctrl{1}, 'B0')), 0, []);
    for dF = [0 2]
        tau = zeros(numel(c.startDays), 2);  rec = zeros(numel(c.startDays), 2);  fm = zeros(numel(c.startDays), 2);
        for s = 1:numel(c.startDays)
            t = c.rows17(c.startDays(s));
            R = run_hold_test(P, c.Wall, L.Tn(t, :)', L.hn(t, :)', t + 1, c.HOLD_H, c.THR, dF);
            tau(s, :) = R.tau([3 4]);  rec(s, :) = [R.E_rec_kWh(25) R.E_rec_kWh(49)];  fm(s, :) = [R.fmelt(25) R.fmelt(37)];
        end
        rows(end+1, :) = {c.pcms(iO2).name, ctrl{1}, dF, mean(tau(:, 1)), mean(tau(:, 2)), mean(rec(:, 1)), mean(rec(:, 2)), mean(fm(:, 1)), mean(fm(:, 2))}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'pcm', 'controller', 'freezing_shift_K', 'tau_hold_45C_mean_h', 'tau_hold_50C_mean_h', ...
    'E_rec45_24h_kWh', 'E_rec45_48h_kWh', 'f_melt_24h', 'f_melt_36h'});
writetable(T, fullfile(c.outDir, ['supercooling_sensitivity' c.tag '.csv']));
disp(T);
end

function regimes_sac_pass(c0)
% The three Rajasthan regimes with the SAC as a fourth arm. Regimes 0 and 2: the released DQN always charges (it equals B0), so the SAC
% is the first controller that differs from always-charge there. Needs export_r<k>/sac_actor_r<k>.json (export_from_python.py --algo sac).
tab = {};
for r = 0:2
    c = c0;  c.regime = r;
    c.tw = load_twin_params(fullfile(fileparts(mfilename('fullpath')), '..', sprintf('export_r%d', r)), c0.year);
    assert(isfield(c.tw, 'sac'), 'regime %d: sac_actor_r%d.json missing', r, r);
    c.Wall = c.tw.wx.signals.values(:, 1:4);
    c.rows17 = find(c.Wall(:, 4) == 17);
    tab{end+1} = do_run(c, 'PCM-free', 0, 'B0', 1.0, false);   %#ok<AGROW>
    tab{end+1} = do_run(c, 'PCM+B0', -1, 'B0', 1.0, false);    %#ok<AGROW>
    tab{end+1} = do_run(c, 'PCM+DQN', -1, 'DQN', 1.0, false);  %#ok<AGROW>
    tab{end+1} = do_run(c, 'PCM+SAC', -1, 'SAC', 1.0, false);  %#ok<AGROW>
end
T = add_gains(struct2table([tab{:}]), c0.band);
writetable(T, fullfile(c0.outDir, ['campaign_regimes' c0.tag '.csv']));
fprintf('[campaign] 3 regimes x 4 arms -> campaign_regimes%s.csv\n', c0.tag);
end

function swap_sac_pass(c, pcms, band)
% Regime 1: all three O1 PCMs at flow x0.7, x1.0, x1.3 with the SAC (and the water-only tank at each flow for the gains).
tab = {};
for fm = [0.7 1.0 1.3]
    tab{end+1} = do_run(c, 'PCM-free', 0, 'B0', fm, false);                 %#ok<AGROW>
    for i = 1:numel(pcms)
        tab{end+1} = do_run(c, 'PCM+SAC', i, 'SAC', fm, false);             %#ok<AGROW>
    end
end
writetable(add_gains(struct2table([tab{:}]), band), fullfile(c.outDir, ['campaign_results' c.tag '.csv']));
fprintf('[campaign] %d runs (SAC, PCM x flow) -> campaign_results%s.csv\n', numel(tab), c.tag);
end

function regimes_pass(c0)
% Figure F5 input: the three Rajasthan regimes (3 climates inside one state), each with its own exported
% PCM and DQN: water-only B0, PCM + B0, PCM + DQN. Cross-STATE comparison needs the other twins' outputs.
tab = {};
for r = 0:2
    c = c0;  c.regime = r;
    c.tw = load_twin_params(fullfile(fileparts(mfilename('fullpath')), '..', sprintf('export_r%d', r)), c0.year);
    c.Wall = c.tw.wx.signals.values(:, 1:4);
    c.rows17 = find(c.Wall(:, 4) == 17);
    tab{end+1} = do_run(c, 'PCM-free', 0, 'B0', 1.0, false);   %#ok<AGROW>
    tab{end+1} = do_run(c, 'PCM+B0', -1, 'B0', 1.0, false);    %#ok<AGROW>
    tab{end+1} = do_run(c, 'PCM+DQN', -1, 'DQN', 1.0, false);  %#ok<AGROW>
end
T = add_gains(struct2table([tab{:}]), c0.band);
writetable(T, fullfile(c0.outDir, ['campaign_regimes' c0.tag '.csv']));
fprintf('[campaign] 3 regimes -> campaign_regimes.csv\n');
end

function seeds_pass(c)
% Sensor-fault edge case with 20 noise seeds (plan section 6.3, optional pass).
tw = c.tw;  W = c.Wall;
k0 = 90 * 24;  nWin = 240;
base = W(k0 + (1:nWin + 3), :);
iS = 4 * 24 + 1;  iE = 8 * 24;
bo = false(nWin, 1);  bo(iS:iS + 11) = true;
ns = 20;  rowsS = zeros(2 * ns, 5);  q = 0;
for seed = 1:ns
    for ctrlMode = [0 1]
        rng(seed);
        L = simulate_hours(tw, base, tw.P, ctrlMode, 1, bo, nWin);
        q = q + 1;
        rowsS(q, :) = [seed, ctrlMode, sum(L.E_del_Wh(iS:iE)) / 1000, sum(L.shield_s(iS:iE)) / 3600, sum(L.interlock >= 2)];
    end
end
Ts = array2table(rowsS, 'VariableNames', {'seed', 'is_B0', 'E_del45_event_kWh', 'shield_h_event', 'failsafe_h'});
writetable(Ts, fullfile(c.outDir, 'sensor_fault_seeds.csv'));
tcrit = 2.093;                                       % Student t, 0.975, 19 degrees of freedom
for mode = [0 1]
    s = Ts(Ts.is_B0 == mode, :);
    nm = {'DQN', 'B0'}; nm = nm{mode + 1};
    ci = @(x) tcrit * std(x) / sqrt(numel(x));
    fprintf('[seeds] %-3s  delivered %.2f +/- %.2f kWh   shield %.2f +/- %.2f h   (mean +/- 95%% CI, %d seeds)\n', nm, ...
        mean(s.E_del45_event_kWh), ci(s.E_del45_event_kWh), mean(s.shield_h_event), ci(s.shield_h_event), ns);
end
end

function scen_pass(here, outDir)
% The six existing edge cases, run by the unchanged run_scenarios.m (in its own workspace).
runScen(here);
src = fullfile(here, '..', 'export_r1', 'scenarios', 'scenario_summary.csv');
copyfile(src, fullfile(outDir, 'scenario_summary_r1.csv'));
fprintf('[campaign] six edge cases -> scenario_summary_r1.csv\n');
end

function runScen(here) %#ok<INUSD>
regime = 1; doAnim = false; %#ok<NASGU>
run_scenarios
end

function write_provenance(outDir, cfg, tag, over)
p = cfg.provenance;
p.capsule_overrides = over;
p.matlab_version = version;
v = ver;  p.toolboxes = {v.Name}';
p.run_date = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'));
fid = fopen(fullfile(outDir, ['provenance' tag '.json']), 'w'); fwrite(fid, jsonencode(p, 'PrettyPrint', true)); fclose(fid);
end
