function B = benchmark_amanowicz(regime)
%BENCHMARK_AMANOWICZ  Tank-level comparison with Amanowicz & Turski (2025) (joint plan section 2.7).
%
%   B = benchmark_amanowicz;   % writes ../results_campaign/benchmark_amanowicz_{curves,summary}.csv, .png,
%                              %   ../export_r1/amanowicz_benchmark.json
%
% Reference: Amanowicz & Turski, Energies 18(2) 345 (2025). A 9.6 dm3 Styrofoam-insulated tank cools in 27 C air:
%   case 1: 6750 mL water (water only)        case 2: 4050 mL water + 9 capsules of ~300 mL, 200 g RT44HC each
% Compared with the paper's PRINTED linear fits of its measured curves (eqs. 2-5), every 300 s over 7200 s:
%   case 1: T = -0.0018 t + 66.704;   case 2: -0.0170 t + 66.989 (0-750 s), -0.0059 t + 58.193 (750-2100 s),
%           -0.0008 t + 47.288 (2100-7200 s); printed drops 14 K (water) and 26 K (capsules).
% Same structure, assumptions and capsule mappings as the Rajasthan benchmark (its header lists them): plastic wall
% assumed, RT44HC latent heat 250 kJ/kg from the O1 database, capsules start at 27 C, tank body heat capacity ignored,
% cuboid capsules mapped to spheres ('volume', 'area', and 'sv' = same PCM mass and surface/volume, the mapping to use).
% Loss coefficient: a-priori from the paper's insulation (0.822 W/K) and fitted to the water-only case only.
% No capsule constant is fitted (plan: diagnose the error, do not recalibrate the frozen constants).
if nargin < 1 || isempty(regime), regime = 1; end
here = fileparts(mfilename('fullpath')); addpath(here);
C = load_campaign(regime); K = C.base.K;
outDir = fullfile(here, '..', 'results_campaign'); if ~isfolder(outDir), mkdir(outDir); end
t = (0:300:7200)';
ref1 = -0.0018 * t + 66.704; ref2 = piecewise(t);
A_out = 2 * (0.325 * 0.385 + 0.325 * 0.185 + 0.385 * 0.185);
UA_ap = A_out / (0.02 / 0.032);
UA_fit = fzero(@(UA) interp1(t, amanowicz_case(K, 1, 'volume', UA, ref1(1), t), 7200) - ref1(end), [0.2 5]);
variants = {'volume', UA_ap, 'apriori'; 'volume', UA_fit, 'fitted'; 'area', UA_ap, 'apriori'; 'area', UA_fit, 'fitted'; 'sv', UA_ap, 'apriori'; 'sv', UA_fit, 'fitted'};
S = table(); Cv = table(t, ref1, ref2, 'VariableNames', {'t_s', 'paper_fit_case1_C', 'paper_fit_case2_C'});
for v = 1:size(variants, 1)
    shape = variants{v, 1}; UA = variants{v, 2}; lt = variants{v, 3};
    T1 = amanowicz_case(K, 1, shape, UA, ref1(1), t);
    T2 = amanowicz_case(K, 2, shape, UA, ref2(1), t);
    nm = sprintf('%s_%s', shape, lt);
    Cv.(['model_case1_' nm]) = T1; Cv.(['model_case2_' nm]) = T2;
    e1 = T1 - ref1; e2 = T2 - ref2;
    S = [S; table({shape}, {lt}, UA, sqrt(mean(e1.^2)), mean(e1), ref1(1) - T1(end), sqrt(mean(e2.^2)), mean(abs(e2)), mean(e2), ref2(1) - T2(end), ...
        'VariableNames', {'capsule_shape', 'loss_coefficient', 'UA_W_K', 'case1_RMSE_K', 'case1_bias_K', 'case1_drop_7200s_K', ...
        'case2_RMSE_K', 'case2_MAE_K', 'case2_bias_K', 'case2_drop_7200s_K'})]; %#ok<AGROW>
end
writetable(Cv, fullfile(outDir, 'benchmark_amanowicz_curves.csv'));
writetable(S, fullfile(outDir, 'benchmark_amanowicz_summary.csv'));
fprintf('\n=== Amanowicz & Turski 2025 benchmark, Uttarakhand kernel (%d points over 7200 s) ===\n', numel(t));
fprintf('paper drops over 7200 s: water only 14 K, with capsules 26 K (fits: %.1f K and %.1f K)\n', ref1(1) - ref1(end), ref2(1) - ref2(end));
disp(S);
B.summary = S; B.UA_apriori = UA_ap; B.UA_fitted = UA_fit;
J = struct('reference', 'Amanowicz & Turski, Energies 18(2) 345 (2025), printed linear fits eqs. 2-5', ...
    'UA_apriori_W_K', UA_ap, 'UA_fitted_W_K', UA_fit, 'rows', table2struct(S), ...
    'note', 'frozen Objective 2 capsule constants; only the tank loss coefficient is fitted (water-only case); sv = mapping to use');
fid = fopen(fullfile(twin_export_dir(regime), 'amanowicz_benchmark.json'), 'w'); fwrite(fid, jsonencode(J, 'PrettyPrint', true)); fclose(fid);

fig = figure('Visible', 'off', 'Position', [50 50 1200 440], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Benchmark: Amanowicz & Turski (2025) RT44HC tank cool-down vs the Uttarakhand kernel (frozen constants)', 'FontWeight', 'bold');
ax = nexttile(tl); hold(ax, 'on'); plot(ax, t / 60, ref1, 'k-', 'LineWidth', 2); plot(ax, t / 60, ref2, 'k--', 'LineWidth', 2);
plot(ax, t / 60, Cv.model_case1_sv_fitted, 'b-'); plot(ax, t / 60, Cv.model_case2_sv_fitted, 'r-'); plot(ax, t / 60, Cv.model_case2_volume_fitted, 'r:');
xlabel(ax, 'time [min]'); ylabel(ax, 'water temperature [\circC]'); grid(ax, 'on');
legend(ax, {'paper fit, water only', 'paper fit, 9 capsules', 'twin, water only', 'twin, capsules (sv mapping)', 'twin, capsules (one 300 mL sphere)'}, 'Location', 'northeast');
ax = nexttile(tl); b = bar(ax, categorical(strcat(S.capsule_shape, '_', S.loss_coefficient)), [S.case2_RMSE_K, S.case2_bias_K]);
ylabel(ax, 'K'); legend(ax, b, {'case 2 RMSE', 'case 2 bias'}); grid(ax, 'on'); title(ax, 'Error with capsules, per mapping / loss coefficient');
exportgraphics(fig, fullfile(outDir, 'benchmark_amanowicz.png'), 'Resolution', 120); close(fig);
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
