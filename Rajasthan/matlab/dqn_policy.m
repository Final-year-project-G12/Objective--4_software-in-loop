function [action, q] = dqn_policy(obs, W1, b1, W2, b2, W3, b3, policy_mode)
%DQN_POLICY  Trained DQN controller as a plain MLP (the "RL Agent" block).
%
% Q(obs) = Linear(ReLU(Linear(ReLU(Linear(obs)))))  with layers 17 -> 64 -> 64 -> 3.
% Deterministic action = the action with the largest Q-value:
%   0 CHARGE, 1 IDLE, 2 BYPASS
% Weights come from Objective 3's released checkpoint for the regime
% (results/gen2/gen2_selected_dqn.json) through export_from_python.py. The arithmetic
% is done in single precision to mirror the float32 PyTorch network.
%
% Tamil Nadu's twin used a SAC actor (tanh output binned at +/- 1/3); Rajasthan's
% released controller is a DQN, so the output stage here is an argmax.
%
% policy_mode: 0 = DQN (default), 1 = B0 always-charge baseline (for A/B comparison
% of delivery and shield counts inside the same twin).
%#codegen
if policy_mode == 1
    action = 0;
    q = [0; 0; 0];
    return;
end
x  = single(obs(:));
z1 = max(single(W1) * x  + single(b1(:)), single(0));
z2 = max(single(W2) * z1 + single(b2(:)), single(0));
qs = single(W3) * z2 + single(b3(:));
q = double(qs(:));
% first maximum wins on a tie, as torch.argmax / numpy.argmax do
action = 0;
best = qs(1);
for k = 2:3
    if qs(k) > best
        best = qs(k);
        action = k - 1;
    end
end
end
