function [T, info] = run_c_scenarios(exportDir, year)
%RUN_C_SCENARIOS  Objective 4 plan item C: the 6 edge-case scenarios run for
% all THREE arms (plain/B0, PCM/B0, PCM/SAC), plus a dead and a stuck
% pyranometer case for arm 3 only (matching phase9_deployment_metrics.py's
% FAULTS: "ghi_dropout" sets the observed GHI to 0, "ghi_stuck" freezes it
% at the first hour's reading -- both leave the TRUE weather driving the
% physics, and the safety shield, untouched).
%
%   [T, info] = run_c_scenarios('../export', 2011)
here = fileparts(mfilename('fullpath')); addpath(here);
if nargin < 1 || isempty(exportDir), exportDir = fullfile(here, '..', 'export'); end
if nargin < 2, year = 2011; end
outDir = fullfile(exportDir, 'scenarios_3arm'); if ~isfolder(outDir), mkdir(outDir); end
tw = load_twin_params(exportDir, year);
Wall = tw.wx.signals.values;

g10 = jsondecode(fileread(fullfile(here, '..', '..', '..', 'objective2_design_optimization', 'results', 'g10_selection_r0.json')));
fraction = g10.chosen.fraction;

k0 = 90 * 24; nWin = 10 * 24;
base = Wall(k0 + (1:nWin), :);
iS = 4*24 + 1; iE = 8*24;
inEv = false(nWin, 1); inEv(iS:iE) = true;

sc = struct('name', {}, 'title', {}, 'W', {}, 'P', {}, 'noise', {}, 'blackout', {}, 'fullWindow', {});
add = @(nm, ti, W, P, nz, bo, fw) struct('name', nm, 'title', ti, 'W', W, 'P', P, 'noise', nz, 'blackout', bo, 'fullWindow', fw);
nb = false(nWin, 1);

sc(end+1) = add('clear', 'Clear sunny days (reference)', base, tw.P, 0, nb, false);
W = base; W(inEv, 2) = 0;
sc(end+1) = add('no_sunlight', 'No sunlight for 4 days', W, tw.P, 0, nb, false);
W = base; W(inEv, 2) = min(0.12 * base(inEv, 2), 120); W(inEv, 3) = base(inEv, 3) - 5;
sc(end+1) = add('rain_cloud', 'Rain / heavy cloud (GHI x0.12, ambient -5 C)', W, tw.P, 0, nb, false);
W = base; W(inEv, 3) = base(inEv, 3) - 12; W(inEv, 2) = 0.9 * base(inEv, 2);
P = tw.P; P(8) = P(8) - 8;
sc(end+1) = add('low_temperature', 'Low temperature (ambient -12 C, mains -8 C)', W, P, 0, nb, false);
W = base; W(inEv, 3) = base(inEv, 3) + 9; W(inEv, 2) = 1.15 * base(inEv, 2);
sc(end+1) = add('heat_wave', 'Heat wave (ambient +9 C, GHI x1.15)', W, tw.P, 0, nb, false);
bo = nb; bo(iS:iS + 11) = true;
sc(end+1) = add('sensor_fault', 'Noisy sensors + 12 h blackout', base, tw.P, 1, bo, false);
% the two pyranometer faults are a continuous equipment condition, not a
% 4-day transient -- scored over the WHOLE 10-day window, arm 3 only.
sc(end+1) = add('ghi_dropout', 'Dead pyranometer (obs GHI forced to 0, arm 3 only)', base, tw.P, 0, nb, true);
sc(end+1) = add('ghi_stuck', 'Stuck pyranometer (obs GHI frozen at hour 0, arm 3 only)', base, tw.P, 0, nb, true);

rng(7);
res = struct(); rows = {};
for s = 1:numel(sc)
    c = sc(s);
    P_plain = c.P; P_plain(1) = c.P(1) / (1 - fraction); P_plain(23) = 0;
    isFault = ismember(c.name, {'ghi_dropout', 'ghi_stuck'});
    gf = ''; if strcmp(c.name, 'ghi_dropout'), gf = 'dropout'; elseif strcmp(c.name, 'ghi_stuck'), gf = 'stuck'; end

    L3 = simulate_hours(tw, c.W, c.P, 0, c.noise, c.blackout, gf);
    res.(c.name).arm3 = L3;
    evMask = inEv; if c.fullWindow, evMask = true(nWin, 1); end

    if ~isFault
        L1 = simulate_hours(tw, c.W, P_plain, 1, c.noise, c.blackout);
        L2 = simulate_hours(tw, c.W, c.P,     1, c.noise, c.blackout);
        res.(c.name).arm1 = L1; res.(c.name).arm2 = L2;
        arms = {'arm1_plain_B0', L1; 'arm2_pcm_B0', L2; 'arm3_pcm_SAC', L3};
    else
        % reference: arm 3 with NO fault, same window, for comparison
        L3ref = simulate_hours(tw, c.W, c.P, 0, c.noise, c.blackout, '');
        res.(c.name).arm3_nofault = L3ref;
        arms = {'arm3_pcm_SAC', L3; 'arm3_pcm_SAC_nofault', L3ref};
    end

    paramsPlain = tw.params; paramsPlain.m_w_kg = P_plain(1);
    for i = 1:size(arms, 1)
        nm = arms{i, 1}; L = arms{i, 2};
        pp = tw.params; if strcmp(nm, 'arm1_plain_B0'), pp = paramsPlain; end
        m = metrics(L, evMask, pp);
        rows(end+1, :) = {c.name, nm, m.deliv, m.unmet, m.shield, m.viol, m.Tpcm_max, m.f_end, m.Estored_end_kWh}; %#ok<AGROW>
    end
    fprintf('[scenario] %-12s done\n', c.name);
end

T = cell2table(rows, 'VariableNames', {'scenario', 'arm', 'delivered_kWh', 'unmet_kWh', 'shield_trips', ...
    'hard_violations', 'Tpcm_max_C', 'f_melt_end', 'E_stored_end_kWh'});
writetable(T, fullfile(outDir, 'scenario_summary_3arm.csv'));
disp(T);
fprintf('\n[run_c_scenarios] TOTAL hard violations across every scenario/arm: %d\n', sum(T.hard_violations));

info.fraction = fraction;
arm1P = tw.params; arm1P.m_w_kg = tw.params.m_w_kg / (1 - fraction);
plot_env_scenarios(res, sc(1:6), inEv, tw.params, arm1P, fullfile(outDir, 'edge_cases_grid.png'));
plot_fault_scenarios(res, fullfile(outDir, 'pyranometer_faults.png'));
fprintf('[run_c_scenarios] figures -> %s\n', outDir);
end

% ======================================================================
function m = metrics(L, mask, params)
m.deliv = sum(L.E_del_Wh(mask)) / 1000;
m.unmet = sum(L.E_unmet_Wh(mask)) / 1000;
m.shield = sum(L.n_sw(mask) + L.n_sp(mask));
m.viol = sum(L.n_viol);
m.Tpcm_max = max(L.Tpcm);
idxEnd = find(mask, 1, 'last'); m.f_end = L.f_melt(idxEnd);
m.Estored_end_kWh = stored_energy(L.Tw(idxEnd), L.Tpcm(idxEnd), L.f_melt(idxEnd), params);
end

function e = stored_energy(Tw, Tpcm, f, p)
% Approximate sensible+latent energy stored above mains, for comparing
% scenarios -- NOT re-derived physics, a post-hoc reconstruction from the
% logged state for visualisation/ranking purposes only.
Tmains = p.T_mains_C;
e_w = p.m_w_kg * p.cp_w_J_kgK * max(Tw - Tmains, 0);
e_pcm_sens = p.m_pcm_kg * p.cp_s_J_kgK * max(Tpcm - Tmains, 0);
e_latent = p.m_pcm_kg * p.L_J_kg * f;
e = (e_w + e_pcm_sens + e_latent) / 3.6e6;
end

function plot_env_scenarios(res, sc6, inEv, pcmParams, plainParams, file)
n = numel(res.(sc6(1).name).arm1.Tw); d = (1:n)'/24;
fig = figure('Visible', 'off', 'Position', [50 50 1700 950], 'Color', 'w');
tl = tiledlayout(fig, 3, 6, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Edge cases: T_{PCM}, melt fraction, stored energy -- arm1 plain(grey) / arm2 PCM+B0(blue) / arm3 PCM+SAC(red)', 'FontWeight', 'bold');
col = {[0.5 0.5 0.5], [0.1 0.3 0.8], [0.85 0.2 0.1]};

for s = 1:6
    nm = sc6(s).name; r = res.(nm);
    ax = nexttile(tl, s); hold(ax, 'on');
    plot(ax, d, r.arm2.Tpcm, 'Color', col{2}); plot(ax, d, r.arm3.Tpcm, 'Color', col{3});
    yline(ax, 62, 'r--'); title(ax, strrep(nm, '_', ' ')); if s==1, ylabel(ax, 'T_{PCM} [\circC]'); end
    grid(ax, 'on'); xlim(ax, [0 n/24]); shade(ax, inEv, n);
end
for s = 1:6
    nm = sc6(s).name; r = res.(nm);
    ax = nexttile(tl, 6+s); hold(ax, 'on');
    plot(ax, d, r.arm2.f_melt, 'Color', col{2}); plot(ax, d, r.arm3.f_melt, 'Color', col{3});
    ylim(ax, [0 1.05]); if s==1, ylabel(ax, 'melt fraction'); end
    grid(ax, 'on'); xlim(ax, [0 n/24]); shade(ax, inEv, n);
end
for s = 1:6
    nm = sc6(s).name; r = res.(nm);
    e1 = arrayfun(@(k) stored_energy(r.arm1.Tw(k), 0, 0, plainParams), 1:n);
    e2 = arrayfun(@(k) stored_energy(r.arm2.Tw(k), r.arm2.Tpcm(k), r.arm2.f_melt(k), pcmParams), 1:n);
    e3 = arrayfun(@(k) stored_energy(r.arm3.Tw(k), r.arm3.Tpcm(k), r.arm3.f_melt(k), pcmParams), 1:n);
    ax = nexttile(tl, 12+s); hold(ax, 'on');
    plot(ax, d, e1, 'Color', col{1}); plot(ax, d, e2, 'Color', col{2}); plot(ax, d, e3, 'Color', col{3});
    xlabel(ax, 'day'); if s==1, ylabel(ax, 'E_{stored} [kWh]'); end
    grid(ax, 'on'); xlim(ax, [0 n/24]); shade(ax, inEv, n);
end
exportgraphics(fig, file, 'Resolution', 110); close(fig);
end

function shade(ax, inEv, n)
yl = ylim(ax);
i1 = find(inEv, 1); i2 = find(inEv, 1, 'last');
p = patch(ax, [i1 i2 i2 i1]/24, [yl(1) yl(1) yl(2) yl(2)], [0.9 0.9 0.9], 'FaceAlpha', 0.4, 'EdgeColor', 'none');
ylim(ax, yl); uistack(p, 'bottom');
end

function plot_fault_scenarios(res, file)
r1 = res.ghi_dropout; r2 = res.ghi_stuck;
n = numel(r1.arm3.Tw); d = (1:n)'/24;
fig = figure('Visible', 'off', 'Position', [50 50 1200 900], 'Color', 'w');
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Dead / stuck pyranometer, arm 3 (SAC) -- obs GHI corrupted, true weather + shield unaffected', 'FontWeight', 'bold');

ax = nexttile(tl); hold(ax, 'on');
plot(ax, d, r1.arm3_nofault.Tpcm, 'k-', 'LineWidth', 1.3);
plot(ax, d, r1.arm3.Tpcm, 'r-'); plot(ax, d, r2.arm3.Tpcm, 'm--');
yline(ax, 62, 'r--'); ylabel(ax, 'T_{PCM} [\circC]'); grid(ax, 'on'); xlim(ax, [0 n/24]);
legend(ax, {'nominal (no fault)', 'ghi dropout', 'ghi stuck'}, 'Orientation', 'horizontal', 'Location', 'northoutside');

ax = nexttile(tl); hold(ax, 'on');
plot(ax, d, r1.arm3_nofault.f_melt, 'k-', 'LineWidth', 1.3);
plot(ax, d, r1.arm3.f_melt, 'r-'); plot(ax, d, r2.arm3.f_melt, 'm--');
ylabel(ax, 'melt fraction'); ylim(ax, [0 1.05]); grid(ax, 'on'); xlim(ax, [0 n/24]);

ax = nexttile(tl); hold(ax, 'on');
plot(ax, d, cumsum(r1.arm3_nofault.E_del_Wh)/1000, 'k-', 'LineWidth', 1.3);
plot(ax, d, cumsum(r1.arm3.E_del_Wh)/1000, 'r-'); plot(ax, d, cumsum(r2.arm3.E_del_Wh)/1000, 'm--');
ylabel(ax, 'cum. delivered [kWh]'); xlabel(ax, 'day'); grid(ax, 'on'); xlim(ax, [0 n/24]);
exportgraphics(fig, file, 'Resolution', 110); close(fig);
end
