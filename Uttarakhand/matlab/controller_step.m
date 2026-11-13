function [action, interlock_state, margin] = controller_step(obs, Ttop_m, Tpcm_m, sensors_ok, W1, b1, W2, b2, Wa, ba, P)
%CONTROLLER_STEP  The embedded controller as ONE function: frozen PPO policy
% followed by the safety interlock. This is the unit compiled to C (MATLAB
% Coder / Embedded Coder) for the processor-in-the-loop stage.
%#codegen
[a_policy, margin] = ppo_policy(obs, W1, b1, W2, b2, Wa, ba, 0);
[action, interlock_state] = safety_interlock(a_policy, Ttop_m, Tpcm_m, sensors_ok, P);
end
