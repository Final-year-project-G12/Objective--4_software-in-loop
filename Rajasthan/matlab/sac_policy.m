function [action, a_cont] = sac_policy(obs, W1, b1, W2, b2, Wmu, bmu)
%SAC_POLICY  The trained Objective 3 SAC actor as a plain MLP (17-256-256-1, tanh), deterministic action.
%
% Deterministic SAC action = tanh(mu(obs)), mu = Linear(ReLU(Linear(ReLU(Linear(obs))))).
% Weights come from export_from_python.py --algo sac (export_r<k>/sac_actor_r<k>.json). Arithmetic in single precision, to mirror
% the float32 PyTorch policy (same convention as the Tamil Nadu twin's sac_policy.m, which has a 15-field observation).
%
% Binning (o3/environment/gym_wrapper.py::PCMContinuousGymEnv._to_discrete):
%   a < -1/3          -> 0 CHARGE
%   -1/3 <= a <= 1/3  -> 1 IDLE
%   a >  1/3          -> 2 BYPASS
%#codegen
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
