function P = make_plain_tank(P)
%MAKE_PLAIN_TANK  The water-only reference tank (arm 1, plan section 6.5).
%
% Removes the capsules and refills the volume they occupied with water, so the tank still holds its
% full 50 L. (Setting the capsule count to zero without refilling would simulate a part-empty tank.)
%   per node:  m_w_new = m_w + n_caps * (pi/6) * D_outer^3 * rho_w ;  n_caps = 0
% Same rule as Objective 2's displaced-water term (tank_model_multinode.py: "displaced water uses
% the OUTER capsule volume").
D = P(22);  rho_w = P(2);
V_out = pi / 6 * D^3;
P(51:60) = P(51:60) + P(61:70) * V_out * rho_w;
P(61:70) = 0;
% A tank without PCM has no PCM limit. The interlock compares the "PCM temperature" (= mean water
% temperature when there are no capsules) with P(33) = 65 C, which would latch a false hard-limit fault
% as soon as the plain tank's mean water passes 65 C. Switch the PCM-side limits off; the 72 C guard band
% and 75 C hard limit on the water stay.
P(31) = 1e6;  P(33) = 1e6;
end
