function C = calibrate_capsule()
%CALIBRATE_CAPSULE  Fit the capsule conduction constant c on Amanowicz & Turski, test it on Tan 2009 and Dong 2022.
%
%   C = calibrate_capsule;     % writes ../results_campaign/capsule_calibration.csv / .json
%
% Procedure (diagnose_capsule.m shows why c is the constant to fit: F has no effect before 50 % melt and the benchmark never
% gets there, and the film coefficient h made the fit worse):
%   fit      c, with the frozen F = 2 and h = 1, minimising the case-2 RMSE of the Amanowicz & Turski benchmark (tank loss
%            coefficient fitted to the water-only case first, as in benchmark_amanowicz.m)
%   held out the single-capsule experiments, never used in the fit:
%              Tan 2009   experimental melt fractions 0.25 / 0.5 / 0.75 / 0.9 at 40 / 60 / 90 / 120 min
%                         (Objective 2's of_v0_benchmark.csv; read by eye from the paper's Fig. 4 by Objective 2)
%              Dong 2022  8 points of the sphere curve (Objective 2's dong2022_fig7_sphere_digitised.csv, read by eye, +/-0.03)
% Four values of c are scored on all three: the frozen 5; c fitted on the original benchmark mapping (one 300 mL sphere per
% cuboid capsule); c fitted on the surface/volume-matched mapping ('sv', the proposed calibration); and c fitted on Tan + Dong
% (NOT held out: reported only as the "fast melt" bound).
here = fileparts(mfilename('fullpath')); addpath(here);
outDir = fullfile(here, '..', 'results_campaign');
tw = load_twin_params(fullfile(here, '..', 'export_r1'), 2023);
P0 = tw.P;
t = (0:300:7200)';
ref1 = -0.0018 * t + 66.704;
ref2 = piecewise(t);
UA = fzero(@(u) interp1(t, amanowicz_case(P0, 1, 'volume', u, ref1(1), t), 7200) - ref1(end), [0.2 5]);

% experimental data
tan.t = [40 60 90 120]';  tan.f = [0.25 0.5 0.75 0.9]';
dfile = fullfile(here, '..', '..', '..', 'OBJECTIVE2', 'Objective---2', 'objective2-rajasthan', 'rj_openfoam', 'results', 'dong2022_fig7_sphere_digitised.csv');
assert(isfile(dfile), 'Objective 2 digitised Dong curve not found: %s', dfile);
Dg = readtable(dfile, 'CommentStyle', '#');
dong.t = Dg.time_min;  dong.f = Dg.liquid_fraction;
dong.tq = [28.9 58 105 125];                              % quantile times read off that curve (linear interpolation)
dong.tq = interp1(dong.f, dong.t, [0.25 0.5 0.75 0.9]);
tan.tq = [40 60 90 120];

% ---- fits ------------------------------------------------------------------------------------------------------------------------
fitAT  = @(shape) exp(fminbnd(@(lc) at_rmse(P0, shape, UA, t, ref2, exp(lc)), log(1), log(40), optimset('TolX', 1e-4)));
c_sv  = fitAT('sv');
c_old = fitAT('volume');
c_exp = exp(fminbnd(@(lc) heldout_rmse(P0, exp(lc), tan, dong), log(1), log(40), optimset('TolX', 1e-4)));
fprintf('[fit] c on Amanowicz & Turski, surface/volume-matched mapping: %.3f   original one-sphere mapping: %.3f (search bound 40)   on Tan+Dong (not held out): %.3f\n', ...
    c_sv, c_old, c_exp);

% ---- score every candidate on all three ---------------------------------------------------------------------------------------
cand = {'frozen (O2)', 5; 'fit on A&T, original mapping', c_old; 'fit on A&T, matched mapping (proposed)', c_sv; 'fit on Tan+Dong (not held out)', c_exp};
rows = {};
for k = 1:size(cand, 1)
    c = cand{k, 2};  over = struct('c', c);
    e_sv  = rms(amanowicz_case(P0, 2, 'sv', UA, ref2(1), t, over) - ref2);
    e_vol = rms(amanowicz_case(P0, 2, 'volume', UA, ref2(1), t, over) - ref2);
    Rt = capsule_single(P0, 'tan2009', over);   Rd = capsule_single(P0, 'dong2022', over);
    ft = interp1(Rt.t_min, Rt.f, tan.t);        fd = interp1(Rd.t_min, Rd.f, dong.t);
    rows(end+1, :) = {cand{k, 1}, c, e_sv, e_vol, rms(ft - tan.f), rms(fd - dong.f), Rt.tq, Rd.tq}; %#ok<AGROW>
end
qs = [25 50 75 90];
T = cell2table(rows(:, 1:6), 'VariableNames', {'candidate', 'c', 'AT_RMSE_matched_K', 'AT_RMSE_original_K', 'Tan_RMSE_f', 'Dong_RMSE_f'});
for q = 1:4
    T.(sprintf('Tan_t%d_min', qs(q)))  = cellfun(@(x) x(q), rows(:, 7));
end
for q = 1:4
    T.(sprintf('Dong_t%d_min', qs(q))) = cellfun(@(x) x(q), rows(:, 8));
end
T.Properties.Description = 'experiment: Tan t25..t90 = 40 60 90 120 min; Dong (digitised curve) see json';
writetable(T, fullfile(outDir, 'capsule_calibration.csv'));
disp(T);
C.c_AT_matched = c_sv;  C.c_AT_original = c_old;  C.c_TanDong = c_exp;  C.UA = UA;
C.tan_experiment_min = tan.tq;  C.dong_experiment_min = dong.tq;  C.table = T;
fid = fopen(fullfile(outDir, 'capsule_calibration.json'), 'w'); fwrite(fid, jsonencode(rmfield(C, 'table'), 'PrettyPrint', true)); fclose(fid);
fprintf('experiment quantile times (min): Tan %s   Dong %s\n', mat2str(tan.tq), mat2str(round(dong.tq, 1)));
end

function r = at_rmse(P0, shape, UA, t, ref2, c)
r = rms(amanowicz_case(P0, 2, shape, UA, ref2(1), t, struct('c', c)) - ref2);
end

function r = heldout_rmse(P0, c, tan, dong)
Rt = capsule_single(P0, 'tan2009', struct('c', c));   Rd = capsule_single(P0, 'dong2022', struct('c', c));
e = [interp1(Rt.t_min, Rt.f, tan.t) - tan.f; interp1(Rd.t_min, Rd.f, dong.t) - dong.f];
r = rms(e);
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
