function B = benchmark_amanowicz(over, tag)
%BENCHMARK_AMANOWICZ  Tank-level comparison with a published experiment (plan section 7.2).
%
%   B = benchmark_amanowicz;                          % frozen Objective 2 constants -> benchmark_amanowicz_*.csv
%   B = benchmark_amanowicz(struct('c', 12), '_calibrated');   % overridden constants, files get the suffix
%
% Reference: Amanowicz & Turski, Energies 18(2) 345 (2025), PDF in .claude/Sources/
% (Amanowicz2025_RT44HC_PCM_Capsules_PilotStudy.pdf). A 9.6 dm3 Styrofoam-insulated tank cools in 27 C air
%   case 1: 6750 mL of water                                      (water only)
%   case 2: 4050 mL of water + 9 capsules of ~300 mL, 200 g RT44HC each  (40 % of the volume)
% The twin is run with no collector and no draw: the same structure as the retention test.
%
% WHAT IS COMPARED (no curve is digitised from a figure): the paper prints a linear fit of each measured
% cooling curve (its equations 2-5, R2 = 0.93-0.99):
%   case 1:  T = -0.0018 t + 66.704
%   case 2:  T = -0.0170 t + 66.989   (0 - 750 s)
%            T = -0.0059 t + 58.193   (750 - 2100 s)
%            T = -0.0008 t + 47.288   (2100 - 7200 s)           [t in seconds, T in C]
% The twin's water temperature is compared with these lines every 300 s over the paper's 7200 s test
% (RMSE, MAE, bias), and with the printed totals (14 K water only, 26 K with capsules).
%
% HOW THE 10-NODE PLANT IS USED AS A SINGLE-NODE TANK: all 10 nodes get the same water, capsules and loss,
% so they stay identical; axial conduction and mixing then do nothing. The plant's "hour" is set to 300 s
% (P(44)) so the curve is read every 5 minutes.
%
% ASSUMED / NOT IN THE PAPER (each one is a limitation, none is fitted to the capsule behaviour):
%   - capsule wall: 1 mm plastic, k = 0.4 W/mK, cp = 1900 J/kgK, 40 g per capsule (paper: 240 g capsule,
%     200 g PCM; wall thickness and plastic not stated)
%   - PCM latent heat 250 kJ/kg: RT44HC value in Objective 1's database (the paper's Table 2 gives the
%     melting range 41-44 C, cp 2.0, density 800/700, k 0.2 but no latent heat in the text I could read)
%   - capsules start at the lab temperature (27 C), water at the fitted start of each curve
%   - heat capacity of the tank body is ignored (the paper started both cases from the same tank temperature)
%   - SHAPE: the capsules are 22 mm cuboids, the twin has spheres. Two sphere substitutes bracket it:
%       'volume'  sphere of the same 300 mL volume (D = 83.0 mm)          surface 0.0216 m2
%       'area'    sphere with the cuboid's surface 2V/t (D = 93.2 mm)       surface 0.0273 m2
%       'sv'      13.2 small spheres of 16.5 mm radius per capsule: the same PCM mass AND the same surface/volume
%                 ratio as the 22 mm slab (S/V = 2 / half-thickness = 3 / r). Added after diagnose_capsule.m showed
%                 the one-sphere mappings overstate the conduction length 3.6 times; this is the mapping to use.
%   - tank heat loss: UA_apriori = (outer area 0.514 m2) / (R = 0.02 m / 0.032 W/mK = 0.625 m2K/W) = 0.822 W/K,
%     straight from the paper's insulation data; and UA_fitted, chosen so the water-only case matches its
%     fit at 7200 s. Only the loss coefficient is fitted, never a capsule constant.
if nargin < 1 || isempty(over), over = struct(); end
if nargin < 2, tag = ''; end
here = fileparts(mfilename('fullpath')); addpath(here);
tw = load_twin_params(fullfile(here, '..', 'export_r1'), 2023);
outDir = fullfile(here, '..', 'results_campaign');
if ~isfolder(outDir), mkdir(outDir); end

t = (0:300:7200)';
ref1 = -0.0018 * t + 66.704;
ref2 = piecewise(t);
A_out = 2 * (0.325 * 0.385 + 0.325 * 0.185 + 0.385 * 0.185);
UA_ap = A_out / (0.02 / 0.032);

% fit the loss coefficient to case 1 only (one scalar, water-only case)
fit1 = @(UA) amanowicz_case(tw.P, 1, 'volume', UA, ref1(1), t, over);
UA_fit = fzero(@(UA) interp1(t, fit1(UA), 7200) - ref1(end), [0.2 5]);

variants = {'volume', UA_ap, 'apriori'; 'volume', UA_fit, 'fitted'; 'area', UA_ap, 'apriori'; 'area', UA_fit, 'fitted'; 'sv', UA_ap, 'apriori'; 'sv', UA_fit, 'fitted'};
S = table();  C = table(t, ref1, ref2, 'VariableNames', {'t_s', 'paper_fit_case1_C', 'paper_fit_case2_C'});
for v = 1:size(variants, 1)
    shape = variants{v, 1};  UA = variants{v, 2};  lt = variants{v, 3};
    T1 = amanowicz_case(tw.P, 1, shape, UA, ref1(1), t, over);
    T2 = amanowicz_case(tw.P, 2, shape, UA, ref2(1), t, over);
    nm = sprintf('%s_%s', shape, lt);
    C.(['model_case1_' nm]) = T1;  C.(['model_case2_' nm]) = T2;
    e1 = T1 - ref1;  e2 = T2 - ref2;
    S = [S; table({shape}, {lt}, UA, sqrt(mean(e1.^2)), mean(abs(e1)), mean(e1), ref1(1) - T1(end), ...
        sqrt(mean(e2.^2)), mean(abs(e2)), mean(e2), ref2(1) - T2(end), ...
        'VariableNames', {'capsule_shape', 'loss_coefficient', 'UA_W_K', 'case1_RMSE_K', 'case1_MAE_K', 'case1_bias_K', 'case1_drop_7200s_K', ...
        'case2_RMSE_K', 'case2_MAE_K', 'case2_bias_K', 'case2_drop_7200s_K'})]; %#ok<AGROW>
end
writetable(C, fullfile(outDir, ['benchmark_amanowicz_curves' tag '.csv']));
writetable(S, fullfile(outDir, ['benchmark_amanowicz_summary' tag '.csv']));
fprintf('\n=== Amanowicz & Turski 2025 benchmark (%d points over 7200 s) ===\n', numel(t));
fprintf('paper printed drops over 7200 s: water only 14 K, with capsules 26 K (fits: %.1f K and %.1f K)\n', ref1(1) - ref1(end), ref2(1) - ref2(end));
disp(S);
B.summary = S;  B.curves = C;  B.UA_apriori = UA_ap;  B.UA_fitted = UA_fit;
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
