function L = simulate_hours(tw, W, P, policy_mode, noise_on, blackout, ghiFault, initState)
%SIMULATE_HOURS  Closed-loop software-in-the-loop run, one step per hour.
%
% Same signal chain as the Simulink twin and the hardware spec:
%   weather -> sensors (noise/dropout) -> 15-dim observation -> SAC policy
%   -> safety interlock -> pump/valve command -> PCM tank plant -> outlet.
%
%   W           [n x 5] rows of [hour_idx, GHI, T_amb, local_hour, GHI_clearsky]
%   P           plant parameter vector (copy of tw.P, may be modified for edge cases)
%   policy_mode 0 = trained SAC, 1 = B0 always-charge baseline
%   noise_on    0 ideal sensors, 1 noisy sensors + 1 % random dropout
%   blackout    [n x 1] logical, true = sensor frame stale that hour
%   ghiFault    '' (none, default) | 'dropout' | 'stuck' -- pyranometer fault,
%               matching phase9_deployment_metrics.py's FAULTS dict exactly:
%               corrupts ONLY the current-GHI slot of the OBSERVATION fed to
%               the policy (obs(1)). The true GHI driving the physics
%               (pcm_plant_hour's I_t) and the smart-forecast fields
%               (built from the true weather, never from this obs slot) are
%               both left untouched -- the shield still sees reality.
%   initState   optional struct to START from mid-run state instead of the
%               cold-start reset (restart-correctness check, plan S7.1):
%               fields Tw0, Tpcm0, h0, f0, prev0, last_kc0, fault_latched0.
%               Any field left out keeps the normal cold-start value.
n = size(W, 1);
if nargin < 6 || isempty(blackout), blackout = false(n, 1); end
if nargin < 7 || isempty(ghiFault), ghiFault = ''; end
if nargin < 8, initState = struct(); end
Tw = tw.Tw0; Tp = tw.Tpcm0; h = tw.h0; f = tw.f0; prev = 0;
last_kc = 1.0;                    % smart-forecast clear-sky-index state (pcm_env.py forecast_ghi, "smart" mode)
stuck_val = [];                   % ghi_stuck: frozen at the FIRST hour's sensor reading
clear safety_interlock            % reset the latched-fault memory
if isfield(initState, 'Tw0'),    Tw   = initState.Tw0;    end
if isfield(initState, 'Tpcm0'),  Tp   = initState.Tpcm0;  end
if isfield(initState, 'h0'),     h    = initState.h0;     end
if isfield(initState, 'f0'),     f    = initState.f0;     end
if isfield(initState, 'prev0'),  prev = initState.prev0;  end
if isfield(initState, 'last_kc0'), last_kc = initState.last_kc0; end
if isfield(initState, 'fault_latched0')
    safety_interlock('set_latch', initState.fault_latched0, 0, 0, P);
end

names = {'Tw','Tpcm','h_pcm','f_melt','E_del_Wh','E_unmet_Wh','Q_coll_Wh','Q_loss_Wh','n_sw','n_sp','n_viol', ...
         'a_policy','a_cmd','a_exec','a_cont','interlock','draw_kg','GHI','T_amb','hod','sensors_ok', ...
         'last_kc','fault_latched','prev_action'};
for k = 1:numel(names), L.(names{k}) = zeros(n, 1); end

for t = 1:n
    idx = W(t, 1); I = W(t, 2); Ta = W(t, 3); hod = W(t, 4);
    draw = tw.demand24(mod(round(hod), 24) + 1);

    [Im, Tam, Twm, Tpm, fm, ok] = sensor_model(I, Ta, Tw, Tp, f, noise_on, idx);
    if blackout(t), ok = 0; end
    switch ghiFault
        case 'dropout', Im = 0;
        case 'stuck'
            if isempty(stuck_val), stuck_val = Im; end
            Im = stuck_val;
    end
    obs = build_obs(Im, Tam, Twm, Tpm, fm, draw, hod, idx, prev, P);
    if size(tw.W1, 2) == 15          % V3 policy: + smart 3h GHI forecast + next-hour demand
        % pcm_env.py::forecast_ghi, forecast_mode="smart": clear-sky-index
        % persistence, read from the TRUE weather (never the noisy sensor
        % reading -- the forecast lives inside the Python env, upstream of
        % any O4 sensor-fault model).
        clear_now = W(t, 5); ghi_now = W(t, 2);
        if clear_now > 20
            last_kc = min(max(ghi_now / clear_now, 0), 1.2);
        end
        fwd = zeros(4, 1);
        for dh = 1:3
            if t + dh <= n, fwd(dh) = last_kc * W(t + dh, 5) / 1000; end
        end
        hod_next = W(min(t + 1, n), 4);
        fwd(4) = tw.demand24(mod(round(hod_next), 24) + 1) / 20;
        obs = [obs; double(min(max(single(fwd), single(P(39))), single(P(40))))];
    end
    [ap, ac] = sac_policy(obs, tw.W1, tw.b1, tw.W2, tw.b2, tw.Wmu, tw.bmu, policy_mode);
    [acmd, ils] = safety_interlock(ap, Twm, Tpm, ok, P);
    [Tw, Tp, h, f, Ed, Eu, nsw, nsp, nv, ae, Qc, Ql] = pcm_plant_hour(I, Ta, draw, acmd, Tw, Tp, h, f, P);
    prev = acmd;

    L.Tw(t) = Tw; L.Tpcm(t) = Tp; L.h_pcm(t) = h; L.f_melt(t) = f;
    L.E_del_Wh(t) = Ed; L.E_unmet_Wh(t) = Eu; L.Q_coll_Wh(t) = Qc; L.Q_loss_Wh(t) = Ql;
    L.n_sw(t) = nsw; L.n_sp(t) = nsp; L.n_viol(t) = nv;
    L.a_policy(t) = ap; L.a_cmd(t) = acmd; L.a_exec(t) = ae; L.a_cont(t) = ac;
    L.interlock(t) = ils; L.draw_kg(t) = draw; L.GHI(t) = I; L.T_amb(t) = Ta;
    L.hod(t) = hod; L.sensors_ok(t) = ok;
    L.last_kc(t) = last_kc; L.fault_latched(t) = safety_interlock('get_latch', 0, 0, 0, P);
    L.prev_action(t) = prev;
end
end
