function K = make_plain(K)
%MAKE_PLAIN  Turn a PCM tank into the equivalent plain water tank (ARM 1).
%
% The capsules are removed and the volume they occupied is refilled with
% water, so the tank holds the same total volume. This is the only fair
% water-only reference: if you just set n_caps = 0 you would be simulating a
% partly empty tank and the comparison would be meaningless.
%
% Per node:  m_w_new = m_w_old + n_caps * V_capsule_outer * rho_w
%            n_caps  = 0
%
% V_capsule_outer uses the OUTER capsule diameter P(22) = D_cap_m, which is
% the diameter the packing model used to claim the volume.
%
% Usage (Uttarakhand / Rajasthan, 10-node plants):
%   tw = load_twin_params('../export_r1', 2010);
%   K_pcm   = tw.K;                 % arm 2 and arm 3
%   K_plain = make_plain(tw.K);     % arm 1
%
% Check it worked: sum(K_plain.m_w) should equal
%   sum(K.m_w) + sum(K.n_caps) * V_cap * 1000   and all(K_plain.n_caps == 0).

D_cap  = K.P(22);                       % outer capsule diameter [m]
rho_w  = K.P(2);                        % water density [kg/m3]
V_cap  = (4/3) * pi * (D_cap/2)^3;      % outer volume of one capsule [m3]

m_w_before = sum(K.m_w);
n_caps_tot = sum(K.n_caps);
K.m_w    = K.m_w(:) + K.n_caps(:) * V_cap * rho_w;
K.n_caps = zeros(size(K.n_caps));

fprintf('[make_plain] water %.2f -> %.2f kg (+%.2f kg replacing %d capsules of %.1f mm outer dia)\n', ...
        m_w_before, sum(K.m_w), sum(K.m_w) - m_w_before, n_caps_tot, D_cap*1000);
end
