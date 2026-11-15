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
% Columns 5-9 serve the V2 (smart forecast) observation and are computed over the
% FULL year, so a scenario window cut from it still sees the real look-ahead at
% its last hours: [GHI_cs(t), GHI_cs(t+1), GHI_cs(t+2), GHI_cs(t+3), hod(t+1)],
% NaN / -1 past the end of the year (Python: forecast 0, draw_next 0).
n = tw.N;
if size(W, 2) >= 5, cs = W(:, 5); else, cs = zeros(n, 1); end
LA = nan(n, 4);
for k = 1:3, LA(1:n - k, k) = cs(1 + k:n); end
LA(1:n - 1, 4) = W(2:n, 4); LA(n, 4) = -1;
tw.wx.signals.values = [W(:, 1:4), cs, LA];
tw.wx.signals.dimensions = 9;
tw.has_clearsky = size(W, 2) >= 5;

% PPO actor + frozen normalisation
A = jsondecode(fileread(fullfile(exportDir, 'ppo_actor.json')));
tw.mu = A.obs_mean(:);  tw.sd = A.obs_std(:);
tw.W1 = A.W1;  tw.b1 = A.b1(:);
tw.W2 = A.W2;  tw.b2 = A.b2(:);
tw.Wa = A.Wa;  tw.ba = A.ba(:);
if isvector(tw.Wa), tw.Wa = reshape(tw.Wa, 2, []); end
tw.n_obs = numel(tw.mu);                       % 15 = frozen V1 PPO, 19 = PPO + smart forecast (V2)
if isfield(A, 'agent'), tw.agent = A.agent; else, tw.agent = 'frozen'; end
if tw.n_obs == 19 && ~tw.has_clearsky
    error('twin:noClearSky', 'V2 policy needs GHI_clearsky_Wm2 in weather_%d.csv - re-run export_from_python.py', year);
end

refFile = fullfile(exportDir, sprintf('reference_%d.csv', year));
if isfile(refFile)
    tw.ref = readtable(refFile);
else
    tw.ref = [];
end
end
