function L = simulate_hours(tw, W, K, policy_mode, noise_on, blackout, opts)
%SIMULATE_HOURS  Closed-loop software-in-the-loop run, one decision per hour.
%
% Same signal chain as the Simulink twin and the hand-off spec:
%   weather -> sensors / estimator (noise, dropout) -> [smart-persistence GHI
%   forecast] -> 15- or 19-field normalised observation -> PPO policy ->
%   safety interlock -> collector-loop pump -> O2 multinode PCM tank (in-plant
%   shield) -> outlet.
%
%   W           [n x 9] rows of tw.wx.signals.values: [hour_idx, GHI, T_amb,
%               local_hour, GHI_cs, GHI_cs(+1), GHI_cs(+2), GHI_cs(+3), hod(+1)]
%               (columns 5-9 only used by the V2 smart-forecast policy)
%   K           plant struct (copy of tw.K, may be modified for edge cases).
%               Optional field K.obs_mains: the mains temperature fed to the
%               POLICY (default K.P(3), the one the physics uses). Used by the
%               "mains masked" diagnostic: the frozen normalisation has
%               std(T_mains) ~ 0.001 C, so any real mains change is far out of
%               the training distribution.
%   policy_mode 0 = exported PPO (smart-forecast V2 or frozen V1), 1 = B0 always-enable baseline
%   noise_on    0 ideal sensors, 1 noisy sensors + 1 % random dropout
%   blackout    [n x 1] logical, true = sensor frame stale that hour
%   opts        optional struct:
%                 .stuck  pyranometer fault: the CONTROLLER's GHI reading is this value
%                         every hour (0 = dead, 500 / 1000 = stuck); NaN (default) = healthy.
%                         Applied after the noise draw. The smart forecast is built from the
%                         same reading, so it is corrupted too (on a device it would be).
%                         The plant always sees the real GHI.
%                 .n      hours to run (default size(W, 1))
%               Start state: K.T0 / K.h0 when K has them (campaign tanks), else tw.T0 / tw.h0.
%
% Log L: one row per hour (end-of-hour state) plus Tnodes [n x N].
if nargin < 7 || isempty(opts), opts = struct(); end
stuck = NaN; if isfield(opts, 'stuck'), stuck = opts.stuck; end
n = size(W, 1); if isfield(opts, 'n') && ~isempty(opts.n), n = opts.n; end
if nargin < 6 || isempty(blackout), blackout = false(n, 1); end
N = K.N;
if isfield(K, 'T0'), T = K.T0(:); h = K.h0(:); else, T = tw.T0; h = tw.h0; end
rec8 = initial_record(T, h, K);
min_since = tw.min_cap;
prev = 1;                               % env.reset: prev_action = ENABLE
kc = 1.0;                               % clear-sky index before the first daytime hour (o3/env_ext.py)
clear safety_interlock                   % reset the latched-fault memory

names = {'T_top','T_bottom','T_mean','Tpcm','f_melt','E_del_Wh','Q_load_Wh','E_unmet_Wh','Q_coll_Wh', ...
         'E_stored_kWh','T_top_max','T_pcm_max','shield_w_s','shield_p_s','over_limit_s','n_sw','n_sp','n_viol', ...
         'pump_frac','a_policy','a_cmd','margin','interlock','draw_kg','GHI','T_amb','hod','sensors_ok','in_window','GHI_fc1', ...
         'E_del45_Wh','E_unmet45_Wh','Q_loss_Wh','Q_load_net_Wh','E_rec_kWh','GHI_meas'};
for k = 1:numel(names), L.(names{k}) = zeros(n, 1); end
L.Tnodes = zeros(n, N); L.hnodes = zeros(n, N);
L.rec0 = rec8;                          % reset record (row 7 = stored energy at the start)
win = ismember((0:23)', tw.window_hours);
if isfield(K, 'obs_mains'), Tm_obs = K.obs_mains; else, Tm_obs = K.P(3); end

for t = 1:n
    I = W(t, 2); Ta = W(t, 3); hod = round(W(t, 4));

    [Im, Tam, recm, ok] = sensor_model(I, Ta, rec8, noise_on);
    if blackout(t), ok = 0; end
    if ~isnan(stuck), Im = stuck; end
    ext4 = zeros(4, 1);
    if tw.n_obs == 19                    % V2: smart-persistence forecast from the MEASURED GHI + draw schedule
        [fc, kc] = smart_forecast(Im, W(t, 5), W(t, 6:8)', kc);
        hn = W(t, 9);
        dn = 0; if hn >= 0, dn = K.demand24(round(hn) + 1); end
        ext4 = [fc; dn];
    end
    obs = build_obs(recm, Im, Tam, hod, Tm_obs, min_since, prev, tw.mu, tw.sd, ext4);
    [ap, mg] = ppo_policy(obs, tw.W1, tw.b1, tw.W2, tw.b2, tw.Wa, tw.ba, policy_mode);
    [acmd, ils] = safety_interlock(ap, recm(1), recm(4), ok, K.P);
    [T, h, rec, sc, ex] = pcm_plant_hour(I, Ta, hod, acmd, T, h, K);

    rec8 = rec([1 20 2 3 4 10 18 19]);   % T_top T_bottom T_mean T_pcm f draw E_stored E_rec
    if rec(10) >= tw.draw_thr
        min_since = 0;
    else
        min_since = min(min_since + 60, tw.min_cap);
    end
    prev = acmd;

    L.T_top(t) = rec(1); L.T_bottom(t) = rec(20); L.T_mean(t) = rec(2); L.Tpcm(t) = rec(3); L.f_melt(t) = rec(4);
    L.E_del_Wh(t) = rec(12); L.Q_load_Wh(t) = rec(6); L.E_unmet_Wh(t) = rec(9); L.Q_coll_Wh(t) = rec(5);
    L.E_stored_kWh(t) = rec(18); L.T_top_max(t) = rec(14); L.T_pcm_max(t) = rec(15);
    L.shield_w_s(t) = sc(1); L.shield_p_s(t) = sc(2); L.over_limit_s(t) = sc(3);
    L.n_sw(t) = sc(4); L.n_sp(t) = sc(5); L.n_viol(t) = sc(6); L.pump_frac(t) = sc(7) / 3600;
    L.a_policy(t) = ap; L.a_cmd(t) = acmd; L.margin(t) = mg; L.interlock(t) = ils;
    L.draw_kg(t) = rec(10); L.GHI(t) = I; L.T_amb(t) = Ta; L.hod(t) = hod; L.sensors_ok(t) = ok;
    L.in_window(t) = win(hod + 1);
    L.GHI_fc1(t) = ext4(1);              % 1-h-ahead forecast the policy saw (0 for V1)
    L.Tnodes(t, :) = T(:)'; L.hnodes(t, :) = h(:)';
    L.E_del45_Wh(t) = ex(1); L.E_unmet45_Wh(t) = ex(2); L.Q_loss_Wh(t) = rec(8); L.Q_load_net_Wh(t) = rec(21);
    L.E_rec_kWh(t) = rec(19); L.GHI_meas(t) = Im;
end
end
