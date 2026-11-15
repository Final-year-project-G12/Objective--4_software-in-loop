function T = pcm_swap_study(regime)
%PCM_SWAP_STUDY  PCM swap with flow axis (joint plan section 2.6), Rajasthan / Tamil Nadu table layout.
%
%   T = pcm_swap_study;   % regime 1; writes ../export_r1/pcm_swap_study.csv/.json, ../results_campaign/ranking_check.csv,
%                         %   ../results_campaign/pcm_swap_study.png
%
% Objective 1's top-3 PCMs of the cluster (geometry held at the Objective 2 design: capsule count, size, wall,
% arrangement), each at flow x0.7, x1.0, x1.3, with B0 and the PPO, full year 2023 + the 12-start hold test. Every
% tank is built by Objective 2's own setup (export_campaign.py), so nothing about the swap is re-derived here.
% The water-only twin (x1.0) is the reference for the PCM gain. The PPO was trained on the O2 PCM only; on the other
% two PCMs it runs outside the plant it was trained on (its PCM temperature / melt inputs change meaning).
if nargin < 1 || isempty(regime), regime = 1; end
here = fileparts(mfilename('fullpath')); addpath(here);
tw = load_twin_params(twin_export_dir(regime), 2023);
C = load_campaign(regime);
W = tw.wx.signals.values;
rows17 = find(W(:, 4) == 17); startDays = round(linspace(15, 345, 12)); thr = [30 40 45 50];
runs = [struct('key', 'water_only', 'pcm', 'water only', 'flow_mult', 1, 'rank', 0, 'chosen', false, 'K', C.water_only, ...
    'pcm_mass_kg', 0, 'pump_power_w', 0), C.cases];
rows = {};
for i = 1:numel(runs)
    c = runs(i);
    pms = [1 0]; if c.rank == 0, pms = 1; end
    for pm = pms
        L = simulate_hours(tw, W, c.K, pm, 0, []);
        m = twin_metrics(L, c.K, 0, c.pump_power_w);
        tau = zeros(numel(startDays), numel(thr)); cens = false(size(tau));
        for s = 1:numel(startDays)
            t = rows17(startDays(s));
            R = run_hold_test(c.K, W, L.Tnodes(t, :)', L.hnodes(t, :)', t + 1, 72, thr);
            tau(s, :) = R.tau; cens(s, :) = R.censored;
        end
        rows(end+1, :) = {c.pcm, c.rank, c.chosen, c.flow_mult, pm, m.E_del50_kWh, m.E_del45_kWh, m.E_del50_win_kWh, m.E_del45_win_kWh, ...
            m.E_unmet50_kWh, m.guard_band_h, m.hours_over_hard_limit, m.pcm_mass_kg, m.E_del50_per_kgPCM_kWh, m.E_del50_per_m2_kWh, ...
            m.melt_cycles_per_year, m.pump_run_h, m.pump_bed_electrical_Wh, mean(tau(:, 3)), sum(cens(:, 3)), mean(tau(:, 4)), ...
            sum(cens(:, 4)), mean(tau(:, 2)), mean(tau(:, 1))}; %#ok<AGROW>
        fprintf('[swap] %-22s flow x%.1f %-3s  E50 %.1f  window %.1f kWh  guard %.1f h  tau45 %.1f h  tau50 %.1f h\n', c.pcm, c.flow_mult, ...
            ternary(pm == 1, 'B0', 'PPO'), m.E_del50_kWh, m.E_del50_win_kWh, m.guard_band_h, mean(tau(:, 3)), mean(tau(:, 4)));
    end
end
T = cell2table(rows, 'VariableNames', {'pcm', 'o1_rank', 'chosen_by_O2', 'flow_mult', 'policy_mode', 'delivered50_kWh', 'delivered45_kWh', ...
    'window50_kWh', 'window45_kWh', 'unmet50_kWh', 'guard_band_h', 'hours_over_hard_limit', 'm_pcm_kg', 'kWh50_per_kg_pcm', 'kWh50_per_m2_coll', ...
    'melt_cycles', 'pump_run_h', 'pump_bed_Wh', 'tau_hold45_mean_h', 'tau_hold45_n_censored', 'tau_hold50_mean_h', 'tau_hold50_n_censored', ...
    'tau_hold40_mean_h', 'tau_hold30_mean_h'});
T = sortrows(T, {'o1_rank', 'flow_mult', 'policy_mode'});
outDir = twin_export_dir(regime);
writetable(T, fullfile(outDir, 'pcm_swap_study.csv'));
J = struct('year', 2023, 'regime', regime, 'collector_m2', C.base.K.coll(1), 'note', ...
    'policy_mode 0 = PPO (smart forecast), 1 = B0; o1_rank 0 = water-only twin; guard_band_h = shield hours', 'rows', table2struct(T));
fid = fopen(fullfile(outDir, 'pcm_swap_study.json'), 'w'); fwrite(fid, jsonencode(J, 'PrettyPrint', true)); fclose(fid);

% ranking check (plan limitation: three items cannot support a ranking claim), flow x1.0
rk = {}; o1r = [C.o1.consensus_rank];
for pm = [1 0]
    s = T(T.flow_mult == 1 & T.policy_mode == pm & T.o1_rank > 0, :); s = sortrows(s, 'o1_rank');
    for metric = {'tau_hold45_mean_h', 'tau_hold50_mean_h', 'window50_kWh', 'delivered50_kWh'}
        v = s.(metric{1});
        [~, ord] = sort(-v); twinRank = zeros(size(v)); twinRank(ord) = 1:numel(v);
        nn = numel(v); rho = 1 - 6 * sum((o1r(:) - twinRank(:)).^2) / (nn * (nn^2 - 1));   % Spearman, no ties
        rk(end+1, :) = {ternary(pm == 1, 'B0', 'PPO'), metric{1}, strjoin(s.pcm', ' > '), mat2str(twinRank'), rho, max(v) - min(v)}; %#ok<AGROW>
    end
end
RK = cell2table(rk, 'VariableNames', {'controller', 'metric', 'o1_order', 'twin_rank_of_o1_order', 'spearman_vs_o1', 'spread'});
rdir = fullfile(here, '..', 'results_campaign'); if ~isfolder(rdir), mkdir(rdir); end
writetable(RK, fullfile(rdir, 'ranking_check.csv'));
disp(RK);

fig = figure('Visible', 'off', 'Position', [50 50 1300 440], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 1, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('PCM swap (O1 top-3, O2 geometry) x flow, Uttarakhand regime %d, 2023; dashed = water-only twin', regime), 'FontWeight', 'bold');
vars = {'window50_kWh', 'tau_hold45_mean_h', 'guard_band_h'}; ttl = {'window 18-09 h, 50 \circC [kWh]', 'hold at 45 \circC, mean of 12 [h]', 'guard-band hours'};
names = {C.o1.name}; mk = {'o-', 's-', '^-'};
for v = 1:3
    ax = nexttile(tl); hold(ax, 'on');
    for p = 1:numel(names)
        for pm = [1 0]
            s = T(strcmp(T.pcm, names{p}) & T.policy_mode == pm, :);
            plot(ax, s.flow_mult, s.(vars{v}), mk{p}, 'LineStyle', ternary(pm == 1, '-', ':'), 'LineWidth', 1.3, ...
                'DisplayName', sprintf('%s %s', names{p}, ternary(pm == 1, 'B0', 'PPO')));
        end
    end
    wo = T(T.o1_rank == 0, :); yline(ax, wo.(vars{v}), 'k--', 'HandleVisibility', 'off');
    xlabel(ax, 'flow multiplier'); title(ax, ttl{v}); grid(ax, 'on'); xticks(ax, [0.7 1 1.3]);
    if v == 1, legend(ax, 'Location', 'southoutside', 'NumColumns', 2, 'FontSize', 7); end
end
exportgraphics(fig, fullfile(rdir, 'pcm_swap_study.png'), 'Resolution', 120); close(fig);
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
