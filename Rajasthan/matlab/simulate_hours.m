function L = simulate_hours(tw, W, P, policy_mode, noise_on, blackout, nSim)
%SIMULATE_HOURS  Closed-loop software-in-the-loop run, one step per hour.
%
% Same signal chain as the Simulink twin and the O4 interface spec:
%   weather -> sensors (noise/dropout) -> 17-field observation -> DQN policy
%   -> safety interlock -> pump/valve command -> 10-node PCM tank plant -> outlet.
%
%   W           [m x 4] rows of [hour_idx, GHI, T_amb, local_hour], m >= nSim.
%               Rows after nSim are only used as the 1-3 h GHI forecast and the
%               next-hour draw; past the end of W the forecast is 0 (as in pcm_env.py
%               at the end of a year).
%   P           plant parameter vector (copy of tw.P, may be modified for edge cases)
%   policy_mode 0 = trained DQN, 1 = B0 always-charge baseline
%   noise_on    0 ideal sensors, 1 noisy sensors + 1 % random dropout
%   blackout    [nSim x 1] logical, true = sensor frame stale that hour
%   nSim        hours to simulate (default: all rows of W)
m = size(W, 1);
if nargin < 7 || isempty(nSim), nSim = m; end
n = nSim;
if nargin < 6 || isempty(blackout), blackout = false(n, 1); end

T = tw.T0;  h = tw.h0;
s = pcm_derive_state(T, h, P);       % T_top T_bottom T_mean T_pcm f_melt E_stored E_rec45
hours_since_draw = 24;
clear safety_interlock               % reset the latched-fault memory

names = {'Tw', 'Tbot', 'Tmean', 'Tpcm', 'f_melt', 'E_stored_kWh', 'E_rec45_kWh', ...
         'E_del_Wh', 'E_unmet_Wh', 'Q_coll_Wh', 'n_sw', 'n_sp', 'n_viol', 'shield_s', ...
         'Tw_max', 'Tpcm_max', 'a_policy', 'a_cmd', 'a_exec', 'interlock', ...
         'draw_kg', 'GHI', 'T_amb', 'hod', 'sensors_ok'};
for k = 1:numel(names), L.(names{k}) = zeros(n, 1); end
L.q = zeros(n, 3);
L.obs = zeros(n, 17);

for t = 1:n
    idx = W(t, 1);  I = W(t, 2);  Ta = W(t, 3);  hod = mod(round(W(t, 4)), 24);
    draw = tw.demand24(hod + 1);

    % forecast part of the observation (perfect forecast: the next hours of W)
    fwd = zeros(4, 1);
    for dh = 1:3
        if t + dh <= m, fwd(dh) = W(t + dh, 2); end
    end
    if t + 1 <= m
        fwd(4) = tw.demand24(mod(round(W(t + 1, 4)), 24) + 1);
    end

    [Im, Tam, sm, ok] = sensor_model(I, Ta, s, noise_on, idx);
    if blackout(t), ok = 0; end
    obs = build_obs(Im, Tam, sm, draw, hod, hours_since_draw * 60, fwd, P);
    [ap, q] = dqn_policy(obs, tw.W1, tw.b1, tw.W2, tw.b2, tw.W3, tw.b3, policy_mode);
    [acmd, ils] = safety_interlock(ap, sm(1), sm(4), ok, P);
    [T, h, y] = pcm_plant_hour(I, Ta, draw, acmd, T, h, P);
    s = y(1:7);
    if y(11) > 1e-3                  % pcm_env.py: "hours_since_draw"
        hours_since_draw = 0;
    else
        hours_since_draw = min(hours_since_draw + 1, 24);
    end

    L.Tw(t) = y(1);  L.Tbot(t) = y(2);  L.Tmean(t) = y(3);  L.Tpcm(t) = y(4);  L.f_melt(t) = y(5);
    L.E_stored_kWh(t) = y(6);  L.E_rec45_kWh(t) = y(7);
    L.E_del_Wh(t) = y(8);  L.E_unmet_Wh(t) = y(9);  L.Q_coll_Wh(t) = y(10);
    L.n_sw(t) = y(12);  L.n_sp(t) = y(13);  L.n_viol(t) = y(14);  L.a_exec(t) = y(15);
    L.Tw_max(t) = y(16);  L.Tpcm_max(t) = y(17);  L.shield_s(t) = y(18);
    L.a_policy(t) = ap;  L.a_cmd(t) = acmd;  L.interlock(t) = ils;  L.q(t, :) = q(:)';
    L.obs(t, :) = obs(:)';
    L.draw_kg(t) = draw;  L.GHI(t) = I;  L.T_amb(t) = Ta;  L.hod(t) = hod;  L.sensors_ok(t) = ok;
end
end
