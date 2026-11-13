function [action, interlock_state, q] = controller_step(obs, Tw_m, Tpcm_m, sensors_ok, W1, b1, W2, b2, W3, b3, P)
%CONTROLLER_STEP  The embedded controller as ONE function: trained DQN policy followed by
% the safety interlock. This is the unit that is compiled to C (MATLAB Coder) for the
% processor-in-the-loop stage.
%#codegen
[a_policy, q] = dqn_policy(obs, W1, b1, W2, b2, W3, b3, 0);
[action, interlock_state] = safety_interlock(a_policy, Tw_m, Tpcm_m, sensors_ok, P);
end
