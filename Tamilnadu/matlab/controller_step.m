function [action, interlock_state, a_cont] = controller_step(obs, Tw_m, Tpcm_m, sensors_ok, W1, b1, W2, b2, Wmu, bmu, P)
%CONTROLLER_STEP  The embedded controller as ONE function: trained SAC policy
% followed by the safety interlock. This is the unit that is compiled to C
% (MATLAB Coder / Embedded Coder) for the processor-in-the-loop stage.
%#codegen
[a_policy, a_cont] = sac_policy(obs, W1, b1, W2, b2, Wmu, bmu, 0);
[action, interlock_state] = safety_interlock(a_policy, Tw_m, Tpcm_m, sensors_ok, P);
end
