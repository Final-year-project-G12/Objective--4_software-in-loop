function [action, a_cont] = sac_policy(obs, W1, b1, W2, b2, Wmu, bmu, policy_mode)
%SAC_POLICY  Trained SAC actor as a plain MLP (the "RL Agent" block).
%
% Deterministic SAC action = tanh(mu(obs)), mu = Linear(ReLU(Linear(ReLU(Linear(obs))))).
% Weights come from results/sac/r0/best_model/best_model.zip via
% objective4_software_in_loop/export_from_python.py. The arithmetic is done in single
% precision to mirror the float32 PyTorch policy.
%
% Binning (o3/environment/gym_wrapper.py::PCMContinuousGymEnv._to_discrete):
%   a < -1/3        -> 0 CHARGE
%   -1/3 <= a <= 1/3 -> 1 IDLE
%   a >  1/3        -> 2 BYPASS
%
% policy_mode: 0 = SAC (default), 1 = B0 always-charge baseline (for A/B
% comparison of the shield counts inside the same twin).
%#codegen
if policy_mode == 1
    action = 0; a_cont = -1;
    return;
end
x  = single(obs(:));
z1 = max(single(W1) * x + single(b1(:)), single(0));
z2 = max(single(W2) * z1 + single(b2(:)), single(0));
mu = single(Wmu) * z2 + single(bmu(:));
a_cont = double(tanh(mu(1)));
if a_cont < -1/3
    action = 0;
elseif a_cont > 1/3
    action = 2;
else
    action = 1;
end
end
