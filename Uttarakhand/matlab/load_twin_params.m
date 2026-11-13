function tw = load_twin_params(exportDir, year)
%LOAD_TWIN_PARAMS  Read the Python exports into the structures the Uttarakhand twin needs.
%
%   tw = load_twin_params('../export_r1', 2010)
%
% Returns a struct with
%   K        plant struct passed to pcm_plant_hour (P, m_w, n_caps, loss_ua, demand24, coll, N)
%   T0, h0   reset state (fully solid PCM, water 30 C), node vectors bottom -> top
%   wx       From Workspace structure, columns [hour_idx, GHI, T_amb, local_hour]
%   mu, sd   frozen observation normalisation (15 x 1)
%   W1..ba   PPO actor weights
%   draw_thr, min_cap   observation constants (minutes-since-draw logic)
%   ref      Python reference trajectory table (if exported)
%   params   the raw plant_params.json
here = fileparts(mfilename('fullpath'));
if nargin < 1 || isempty(exportDir), exportDir = fullfile(here, '..', 'export_r1'); end
if nargin < 2 || isempty(year)
    pp0 = jsondecode(fileread(fullfile(exportDir, 'plant_params.json')));
    year = pp0.year;
end

pp = jsondecode(fileread(fullfile(exportDir, 'plant_params.json')));
tw.params = pp;
tw.year = year;
tw.regime = pp.regime_id;

K.P        = pp.P(:);
K.m_w      = pp.m_w_kg(:);
K.n_caps   = pp.n_caps(:);
K.loss_ua  = pp.loss_ua_W_K(:);
K.demand24 = pp.demand_kg_by_hour(:);
K.coll     = [pp.collector.area_m2; pp.collector.fr_tau_alpha; pp.collector.fr_ul_W_m2K; pp.collector.I_cutoff_Wm2];
K.N        = numel(K.m_w);
tw.K = K;
tw.T0 = pp.T0_C(:);
tw.h0 = pp.h0_J_kg(:);
tw.draw_thr = pp.draw_threshold_kg;
tw.min_cap  = pp.minutes_since_draw_cap;
tw.window_hours = pp.window_hours(:);

% weather -> From Workspace structure [hour_idx, GHI, T_amb, local_hour]
W = readmatrix(fullfile(exportDir, sprintf('weather_%d.csv', year)));
tw.N = size(W, 1);
tw.wx.time = (0:tw.N - 1)' * 3600;
tw.wx.signals.values = W(:, 1:4);
tw.wx.signals.dimensions = 4;

% PPO actor + frozen normalisation
A = jsondecode(fileread(fullfile(exportDir, 'ppo_actor.json')));
tw.mu = A.obs_mean(:);  tw.sd = A.obs_std(:);
tw.W1 = A.W1;  tw.b1 = A.b1(:);
tw.W2 = A.W2;  tw.b2 = A.b2(:);
tw.Wa = A.Wa;  tw.ba = A.ba(:);
if isvector(tw.Wa), tw.Wa = reshape(tw.Wa, 2, []); end

refFile = fullfile(exportDir, sprintf('reference_%d.csv', year));
if isfile(refFile)
    tw.ref = readtable(refFile);
else
    tw.ref = [];
end
end
