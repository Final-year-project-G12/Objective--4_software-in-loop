function D = diagnose_capsule()
%DIAGNOSE_CAPSULE  Which capsule constant explains the warm bias of the Amanowicz & Turski benchmark? (no model change)
%
%   D = diagnose_capsule;      % writes ../results_campaign/capsule_sensitivity.csv and capsule_regression.json
%
% Changes nothing in the plant. Each constant is varied ALONE, everything else at the frozen Objective 2 value:
%   c      conduction constant in R_pcm = r / (c k_eff)                 (kernel parameter P(35), default 5)
%   F      liquid-convection factor on k_eff above 50 % melt            (P(16), default 2)
%   h      capsule-to-water film coefficient, multiplier on h_w         (done here by scaling the water conductivity
%          P(17), which only enters h_w = Nu k_w / d; Nu itself, 2 at zero through-flow, is untouched)
% Run for two ways of standing spheres in for the paper's 22 mm cuboid capsules: 'volume' (one 300 mL sphere per capsule,
% the original benchmark) and 'sv' (spheres with the same PCM mass and the same surface/volume ratio as the slab).
% For the benchmark (case 2, same-volume sphere, loss coefficient fitted to the water-only case as before) it reports
% RMSE and bias against the paper's printed fit, split into the paper's three stages (0-750 s, 750-2100 s, 2100-7200 s;
% the charging phase is stage 1-2), plus the resistance budget at the start. The same constants are then varied on the
% two single-capsule experiments (Tan 2009, Dong 2022), where the film is absent by construction.
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = fullfile(here, '..', 'results_campaign');
tw = load_twin_params(fullfile(here, '..', 'export_r1'), 2023);
P0 = tw.P;
t = (0:300:7200)';
ref1 = -0.0018 * t + 66.704;
ref2 = piecewise(t);

% ---- regression: reproduce Objective 2's frozen-lumped numbers with this set-up ------------------------------------
Rt = capsule_single(P0, 'tan2009');
Rd = capsule_single(P0, 'dong2022');
o2 = struct('tan_t25', 71.5, 'dong', [38.1 78.1 99.1 112.2]);
reg.tan_twin_t25_min = Rt.tq(1);  reg.tan_O2_t25_min = o2.tan_t25;  reg.tan_twin_tq = Rt.tq;
reg.dong_twin_tq = Rd.tq;  reg.dong_O2_tq = o2.dong;
reg.max_abs_diff_min = max(abs([Rt.tq(1) - o2.tan_t25, Rd.tq - o2.dong]));
reg.pass = reg.max_abs_diff_min < 1.0;
fprintf('[regression] Tan t25 %.1f (O2 %.1f)  Dong %s (O2 %s)  max diff %.2f min -> %s\n', Rt.tq(1), o2.tan_t25, ...
    mat2str(round(Rd.tq, 1)), mat2str(o2.dong), reg.max_abs_diff_min, tf(reg.pass));
fid = fopen(fullfile(outDir, 'capsule_regression.json'), 'w'); fwrite(fid, jsonencode(reg, 'PrettyPrint', true)); fclose(fid);

% ---- loss coefficient of the tank, fitted to the water-only case (same as benchmark_amanowicz.m) -----------------------
fit1 = @(UA) interp1(t, amanowicz_case(P0, 1, 'volume', UA, ref1(1), t), 7200) - ref1(end);
UA = fzero(fit1, [0.2 5]);

% ---- resistance budget of one benchmark capsule at the start (zero through-flow, solid PCM) ---------------------------
Dc = (6 * 300e-6 / pi)^(1/3);  A = pi * Dc^2;
hw = (2 + 1.1 * (1e-6)^0.6 * P0(18)^(1/3)) * P0(17) / Dc;
r_in = Dc / 2 - 0.001;  a_in = 4 * pi * r_in^2;
Rb.film_K_W = 1 / (hw * A);  Rb.wall_K_W = 0.001 / (0.4 * A);
Rb.pcm_solid_K_W = r_in / (P0(35) * 0.2 * a_in);  Rb.pcm_liquid_K_W = r_in / (P0(35) * 0.2 * P0(16) * a_in);
Rb.film_share_solid_pct = 100 * Rb.film_K_W / (Rb.film_K_W + Rb.wall_K_W + Rb.pcm_solid_K_W);
Rb.hw_W_m2K = hw;
fprintf('[resistances, A&T capsule, K/W] film %.2f (h_w %.1f W/m2K, Nu = 2)  wall %.2f  PCM solid %.2f  PCM liquid %.2f  -> film = %.0f %% of the series total\n', ...
    Rb.film_K_W, hw, Rb.wall_K_W, Rb.pcm_solid_K_W, Rb.pcm_liquid_K_W, Rb.film_share_solid_pct);

% ---- sweeps ---------------------------------------------------------------------------------------------------------------------
rows = {};
sweeps = {'c', [2.5 5 7.5 10 15 20 30 50]; 'F', [1 2 4 8 16]; 'h', [0.5 1 2 3 5 8 12 20]};
for shp = {'volume', 'sv'}
  for s = 1:size(sweeps, 1)
    for v = sweeps{s, 2}
        P = P0;  over = struct();
        switch sweeps{s, 1}
            case 'c', over.c = v;
            case 'F', over.F = v;
            case 'h', P(17) = P0(17) * v;
        end
        T2 = amanowicz_case(P, 2, shp{1}, UA, ref2(1), t, over);
        e = T2 - ref2;  st1 = t <= 750;  st2 = t > 750 & t <= 2100;  st3 = t > 2100;
        rows(end+1, :) = {['amanowicz_case2_' shp{1}], sweeps{s, 1}, v, rms(e), mean(e), rms(e(st1)), rms(e(st2)), rms(e(st3)), ref2(1) - T2(end), nan, nan, nan, nan}; %#ok<AGROW>
        if ~strcmp(sweeps{s, 1}, 'h') && strcmp(shp{1}, 'volume')
            for cs = {'tan2009', 'dong2022'}
                R = capsule_single(P0, cs{1}, over);
                rows(end+1, :) = {cs{1}, sweeps{s, 1}, v, nan, nan, nan, nan, nan, nan, R.tq(1), R.tq(2), R.tq(3), R.tq(4)}; %#ok<AGROW>
            end
        end
    end
  end
end
% two-constant grid for the benchmark only (does c and h compensate each other?)
for cv = [5 10 20 40]
    for hv = [1 3 10 30]
        P = P0;  P(17) = P0(17) * hv;
        T2 = amanowicz_case(P, 2, 'volume', UA, ref2(1), t, struct('c', cv));
        e = T2 - ref2;
        rows(end+1, :) = {'amanowicz_case2_volume', sprintf('c=%g,h', cv), hv, rms(e), mean(e), nan, nan, nan, ref2(1) - T2(end), nan, nan, nan, nan}; %#ok<AGROW>
    end
end
S = cell2table(rows, 'VariableNames', {'case_name', 'constant', 'value', 'RMSE_K', 'bias_K', 'RMSE_stage1_K', 'RMSE_stage2_K', 'RMSE_stage3_K', ...
    'drop_7200s_K', 't25_min', 't50_min', 't75_min', 't90_min'});
writetable(S, fullfile(outDir, 'capsule_sensitivity.csv'));

fprintf('\n=== Sensitivity of the Amanowicz & Turski case-2 RMSE (loss UA = %.3f W/K, bias = model - paper) ===\n', UA);
for shp = {'volume', 'sv'}
    fprintf('--- capsule mapping: %s ---\n', shp{1});
    for k = {'c', 'F', 'h'}
        s = S(strcmp(S.case_name, ['amanowicz_case2_' shp{1}]) & strcmp(S.constant, k{1}), :);
        fprintf('constant %s:\n', k{1}); disp(s(:, {'value', 'RMSE_K', 'bias_K', 'RMSE_stage1_K', 'RMSE_stage2_K', 'RMSE_stage3_K', 'drop_7200s_K'}));
    end
end
fprintf('Single-capsule experiments, model times in minutes (Tan experiment 40/60/90/120; Dong about 25/58/100/125):\n');
for k = {'c', 'F'}
    s = S(startsWith(S.case_name, {'tan', 'dong'}) & strcmp(S.constant, k{1}), :);
    disp(s(:, {'case_name', 'value', 't25_min', 't50_min', 't75_min', 't90_min'}));
end
D.UA = UA;  D.resistances = Rb;  D.regression = reg;  D.table = S;
end

function y = piecewise(t)
y = zeros(size(t));
for i = 1:numel(t)
    if t(i) <= 750, y(i) = -0.0170 * t(i) + 66.989;
    elseif t(i) <= 2100, y(i) = -0.0059 * t(i) + 58.193;
    else, y(i) = -0.0008 * t(i) + 47.288;
    end
end
end

function s = tf(b)
if b, s = 'PASS'; else, s = 'FAIL'; end
end
