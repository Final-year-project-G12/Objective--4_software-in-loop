function T = shared_format_table()
%SHARED_FORMAT_TABLE  The Uttarakhand 2023 results in the shared cross-state format (same columns as Rajasthan's
% results_campaign/shared_format_table_rajasthan_2023.csv), for regimes 0, 1 and 2.
%
%   T = shared_format_table;   % writes ../results_campaign/shared_format_table_uttarakhand_2023.csv and campaign_regimes.csv
%
% One row per regime and arm: PCM-free (O2's water-only twin, B0), PCM + B0, PCM + PPO (O3-recommended PPO with the
% smart-persistence forecast). Tanks from export_campaign.py (O2's own setup), each regime with O2's chosen PCM.
% Metrics from twin_metrics.m; hold time from run_hold_test.m (12 evenings round(linspace(15, 345, 12)) of 2023, 18:00
% start, 72 h cap, top layer). Measurement point: TOP layer of 10. Forecast: smart persistence from the pyranometer.
% Replay year 2023, an O3 validation year used to select the controller seed: a fidelity check, not an unbiased figure.
here = fileparts(mfilename('fullpath')); addpath(here);
thr = [30 40 45 50];
rows = {};
for regime = 0:2
    tw = load_twin_params(twin_export_dir(regime), 2023);
    C = load_campaign(regime);
    W = tw.wx.signals.values;
    rows17 = find(W(:, 4) == 17); sd = round(linspace(15, 345, 12));
    arms = {'PCM-free', 'B0', 'none', C.water_only, 1, 0; ...
            'PCM+B0', 'B0', C.base.pcm, C.base.K, 1, C.base.pump_power_w; ...
            'PCM+PPO', 'PPO', C.base.pcm, C.base.K, 0, C.base.pump_power_w};
    for a = 1:3
        K = arms{a, 4};
        L = simulate_hours(tw, W, K, arms{a, 5}, 0, []);
        m = twin_metrics(L, K, 0, arms{a, 6});
        tau = zeros(numel(sd), numel(thr)); cens = false(size(tau));
        for s = 1:numel(sd)
            t = rows17(sd(s));
            R = run_hold_test(K, W, L.Tnodes(t, :)', L.hnodes(t, :)', t + 1, 72, thr);
            tau(s, :) = R.tau; cens(s, :) = R.censored;
        end
        rows(end+1, :) = {'uttarakhand', regime, arms{a, 1}, arms{a, 2}, arms{a, 3}, 50, K.coll(1), m.pcm_mass_kg, ...
            m.E_del45_kWh, m.E_del50_kWh, m.E_del45_win_kWh, m.E_del50_win_kWh, m.E_unmet45_kWh, m.guard_band_h, ...
            m.hours_over_hard_limit, m.melt_cycles_per_year, m.pump_on_hours, m.E_del45_per_kgPCM_kWh, m.E_del45_per_m2_kWh, ...
            mean(tau(:, 1)), sum(cens(:, 1)), mean(tau(:, 2)), sum(cens(:, 2)), mean(tau(:, 3)), sum(cens(:, 3)), ...
            mean(tau(:, 4)), sum(cens(:, 4)), 'top layer of 10 (delivery node)', ...
            'smart persistence (clear-sky index) from the pyranometer', 2023}; %#ok<AGROW>
        fprintf('[shared] r%d %-8s E45 %.1f  E50 %.1f  window45 %.1f  guard %.1f h  hold45 %.1f h\n', regime, arms{a, 1}, ...
            m.E_del45_kWh, m.E_del50_kWh, m.E_del45_win_kWh, m.guard_band_h, mean(tau(:, 3)));
    end
end
T = cell2table(rows, 'VariableNames', {'state', 'regime', 'arm', 'controller', 'pcm', 'tank_L', 'collector_m2', 'pcm_mass_kg', ...
    'delivered_45C_kWh', 'delivered_50C_kWh', 'window_45C_kWh', 'window_50C_kWh', 'unmet_45C_kWh', 'guard_band_hours', ...
    'hours_over_hard_limit', 'melt_cycles_per_year', 'pump_on_hours', 'kWh_per_kg_pcm', 'kWh_per_m2_collector', ...
    'hold_30C_mean_h', 'hold_30C_censored_of_12', 'hold_40C_mean_h', 'hold_40C_censored_of_12', 'hold_45C_mean_h', ...
    'hold_45C_censored_of_12', 'hold_50C_mean_h', 'hold_50C_censored_of_12', 'measurement_point', 'forecast', 'replay_year'});
R = fullfile(here, '..', 'results_campaign'); if ~isfolder(R), mkdir(R); end
writetable(T, fullfile(R, 'shared_format_table_uttarakhand_2023.csv'));
writetable(T, fullfile(R, 'campaign_regimes.csv'));
end
