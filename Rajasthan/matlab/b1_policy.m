function action = b1_policy(obs)
%B1_POLICY  Objective 3's reactive rule baseline B1 (untuned defaults), from the 17-field observation.
%
% Port of solar-pcm-control--Objective3/rajasthan/o3/baselines/b1_reactive.py::ReactiveRulePolicy.act (rules in priority order):
%   R1  top node >= 70 C                          -> BYPASS
%   R2  PCM >= 60 C and GHI >= 500 W/m2           -> BYPASS
%   R3  17 <= hour < 21 and f_melt >= 0.15        -> IDLE
%   R4  GHI >= 200 W/m2 and f_melt < 0.9          -> CHARGE
%   R5  f_melt < 0.05 and GHI > 50 W/m2           -> CHARGE
%   R6  otherwise                                 -> IDLE
% Fields are decoded with the fixed scales of o3/environment/obs.py (T = 40 o + 30, GHI = 1000 o, hour = 24 o). Used as simulate_hours
% policy_mode 3, to compare the SAC and DQN with Objective 3's rule on the twin and to exercise the Objective 3 test plan's fail-safe
% ("if the f_melt estimator diverges: fall back to the reactive rule B1").
%#codegen
T_w = obs(1) * 40 + 30;  T_pcm = obs(4) * 40 + 30;  f = obs(5);  ghi = obs(6) * 1000;
hour = mod(round(obs(8) * 24), 24);
if T_w >= 70
    action = 2;
elseif T_pcm >= 60 && ghi >= 500
    action = 2;
elseif hour >= 17 && hour < 21 && f >= 0.15
    action = 1;
elseif ghi >= 200 && f < 0.9
    action = 0;
elseif f < 0.05 && ghi > 50
    action = 0;
else
    action = 1;
end
end
