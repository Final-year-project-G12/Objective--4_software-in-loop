function T = compare_calibration()
%COMPARE_CALIBRATION  Hold times and window energy with the capsule constant as frozen, as calibrated, and at the fast-melt bound.
%
%   T = compare_calibration;     % reads campaign_results.csv, campaign_results_cal.csv, campaign_results_fast.csv
%                                % writes ../results_campaign/calibration_effect.csv
% One row per run (arm, PCM, controller, flow); for each metric the three values and the changes against the frozen run.
here = fileparts(mfilename('fullpath'));
R = fullfile(here, '..', 'results_campaign');
A = readtable(fullfile(R, 'campaign_results.csv'));
B = readtable(fullfile(R, 'campaign_results_cal.csv'));
C = readtable(fullfile(R, 'campaign_results_fast.csv'));
keep = {'arm', 'pcm', 'controller', 'flow_mult'};
mets = {'E_del45_kWh', 'E_del45_win_kWh', 'tau_hold_45C_mean_h', 'tau_hold_50C_mean_h', 'E_rec45_24h_kWh', 'E_rec45_48h_kWh', ...
        'f_melt_24h', 'guard_band_h', 'gain_E_del45_win_kWh', 'gain_tau_hold_45C_mean_h'};
T = A(:, keep);
for m = mets
    T.([m{1} '_frozen']) = A.(m{1});
    T.([m{1} '_cal'])    = B.(m{1});
    T.([m{1} '_fast'])   = C.(m{1});
    T.([m{1} '_d_cal'])  = B.(m{1}) - A.(m{1});
    T.([m{1} '_d_fast']) = C.(m{1}) - A.(m{1});
end
writetable(T, fullfile(R, 'calibration_effect.csv'));
sel = T.flow_mult == 1;
disp(T(sel, {'arm', 'pcm', 'controller', 'tau_hold_45C_mean_h_frozen', 'tau_hold_45C_mean_h_cal', 'tau_hold_45C_mean_h_fast', ...
    'E_del45_win_kWh_frozen', 'E_del45_win_kWh_cal', 'E_del45_win_kWh_fast'}));
end
