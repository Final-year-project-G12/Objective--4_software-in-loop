function L = simulate_hours(tw, W, P, policy_mode, noise_on, blackout)
%SIMULATE_HOURS  Closed-loop software-in-the-loop run, one step per hour.
%
% Same signal chain as the Simulink twin and the hardware spec:
%   weather -> sensors (noise/dropout) -> 11-dim observation -> SAC policy
%   -> safety interlock -> pump/valve command -> PCM tank plant -> outlet.
%
%   W           [n x 4] rows of [hour_idx, GHI, T_amb, local_hour]
%   P           plant parameter vector (copy of tw.P, may be modified for edge cases)
%   policy_mode 0 = trained SAC, 1 = B0 always-charge baseline
%   noise_on    0 ideal sensors, 1 noisy sensors + 1 % random dropout
%   blackout    [n x 1] logical, true = sensor frame stale that hour
n = size(W, 1);
if nargin < 6 || isempty(blackout), blackout = false(n, 1); end
Tw = tw.Tw0; Tp = tw.Tpcm0; h = tw.h0; f = tw.f0; prev = 0;
clear safety_interlock            % reset the latched-fault memory

names = {'Tw','Tpcm','f_melt','E_del_Wh','E_unmet_Wh','n_sw','n_sp','n_viol', ...
         'a_policy','a_cmd','a_exec','a_cont','interlock','draw_kg','GHI','T_amb','hod','sensors_ok'};
for k = 1:numel(names), L.(names{k}) = zeros(n, 1); end

for t = 1:n
    idx = W(t, 1); I = W(t, 2); Ta = W(t, 3); hod = W(t, 4);
    draw = tw.demand24(mod(round(hod), 24) + 1);

    [Im, Tam, Twm, Tpm, fm, ok] = sensor_model(I, Ta, Tw, Tp, f, noise_on, idx);
    if blackout(t), ok = 0; end
    obs = build_obs(Im, Tam, Twm, Tpm, fm, draw, hod, idx, prev, P);
    if size(tw.W1, 2) == 15          % V2 policy: + 3 h GHI forecast + next-hour demand
        fwd = zeros(4, 1);
        for dh = 1:3
            if t + dh <= n, fwd(dh) = W(t + dh, 2) / 1000; end
        end
        hod_next = W(min(t + 1, n), 4);
        fwd(4) = tw.demand24(mod(round(hod_next), 24) + 1) / 20;
        obs = [obs; double(min(max(single(fwd), single(P(39))), single(P(40))))];
    end
    [ap, ac] = sac_policy(obs, tw.W1, tw.b1, tw.W2, tw.b2, tw.Wmu, tw.bmu, policy_mode);
    [acmd, ils] = safety_interlock(ap, Twm, Tpm, ok, P);
    [Tw, Tp, h, f, Ed, Eu, nsw, nsp, nv, ae] = pcm_plant_hour(I, Ta, draw, acmd, Tw, Tp, h, f, P);
    prev = acmd;

    L.Tw(t) = Tw; L.Tpcm(t) = Tp; L.f_melt(t) = f;
    L.E_del_Wh(t) = Ed; L.E_unmet_Wh(t) = Eu;
    L.n_sw(t) = nsw; L.n_sp(t) = nsp; L.n_viol(t) = nv;
    L.a_policy(t) = ap; L.a_cmd(t) = acmd; L.a_exec(t) = ae; L.a_cont(t) = ac;
    L.interlock(t) = ils; L.draw_kg(t) = draw; L.GHI(t) = I; L.T_amb(t) = Ta;
    L.hod(t) = hod; L.sensors_ok(t) = ok;
end
end
