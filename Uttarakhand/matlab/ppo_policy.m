function [action, margin] = ppo_policy(obs, W1, b1, W2, b2, Wa, ba, policy_mode)
%PPO_POLICY  The frozen Objective 3 PPO actor as a plain MLP (the "RL Agent" block).
%
% Stable-Baselines3 MlpPolicy, net_arch [64, 64], tanh activations:
%   logits = Wa * tanh(W2 * tanh(W1 * obs + b1) + b2) + ba
% Deterministic action = argmax(logits): 0 = BYPASS, 1 = ENABLE.
% Weights come from <O3 uttarakhand>/results/o4_handoff/r<k>/policy_r<k>.zip via
% Uttarakhand/export_from_python.py. Arithmetic is single precision to mirror
% the float32 PyTorch policy.
%
% policy_mode: 0 = PPO (default), 1 = B0 always-enable baseline (O2's design as
% released, with its in-kernel shield).
%
% margin = logit(ENABLE) - logit(BYPASS) (how sure the policy is; 0 for B0).
%#codegen
if policy_mode == 1
    action = 1; margin = 0;
    return;
end
x  = single(obs(:));
z1 = tanh(single(W1) * x + single(b1(:)));
z2 = tanh(single(W2) * z1 + single(b2(:)));
lg = single(Wa) * z2 + single(ba(:));
action = double(lg(2) > lg(1));          % torch argmax returns the first index on a tie
margin = double(lg(2) - lg(1));
end
