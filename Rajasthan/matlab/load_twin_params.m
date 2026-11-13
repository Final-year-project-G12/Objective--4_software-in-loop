function tw = load_twin_params(exportDir, year)
%LOAD_TWIN_PARAMS  Read the Python exports into the structures the Rajasthan twin needs.
%
%   tw = load_twin_params('../export_r1', 2023)
%
% Returns a struct with
%   P          [80x1] parameter vector (layout below)
%   demand24   [24x1] kg drawn in each local hour of day
%   wx         From Workspace structure, values = [hour_idx GHI T_amb local_hour GHI+1h GHI+2h GHI+3h draw_next_h]
%   N          number of weather hours
%   T0, h0     [10x1] initial node water temperature / PCM enthalpy (reset "solid")
%   s0         [7x1] derived initial state (pcm_derive_state)
%   W1..b3     DQN Q-network weights
%   ref        Python reference trajectory (table), [] if not exported
%   regime, params, qnet_info
%
% Parameter vector P -- ORDER MUST MATCH pcm_plant_hour.m / pcm_derive_state.m / build_obs.m /
% safety_interlock.m.  P(1:35) is the O2 kernel's own parameter vector (0-based 0..34):
%    1 cp_w        2 rho_w       3 T_mains     4 T_deliv     5 flow kg/s   6 dt_s       7 kcond
%    8 A_cross     9 Ts         10 Tl         11 L          12 cp_s       13 cp_l      14 wall_cp
%   15 k_pcm      16 enhancement 17 k_w       18 Pr         19 mu         20 t_wall    21 k_wall
%   22 D_cap      23 A_cap      24 m_cap      25 band_margin 26 stiffness 27 n_sub_band 28 max_sub
%   29 shield_on  30 bypass_wC  31 bypass_pC  32 max_wC     33 max_pC     34 (unused)  35 c_cond
%   36 A_coll     37 fr_tau_alpha 38 fr_ul    39 I_cutoff   40 obs_low    41 obs_high  42 T_init_water
%   43 n_nodes    44-50 spare
%   51:60 m_w per node [kg]     61:70 capsules per node     71:80 loss UA per node [W/K]
%   (node 1 = bottom, node 10 = top)
if nargin < 1 || isempty(exportDir)
    exportDir = fullfile(fileparts(mfilename('fullpath')), '..', 'export_r1');
end
if nargin < 2 || isempty(year), year = 2023; end

pp = jsondecode(fileread(fullfile(exportDir, 'plant_params.json')));
assert(pp.n_nodes == 10, 'this twin is written for the 10-node tank; export has %d nodes', pp.n_nodes);
assert(numel(pp.kernel_P) == 35, 'kernel_P must have 35 entries');

P = zeros(80, 1);
P(1:35) = pp.kernel_P(:);
P(36) = pp.A_coll_m2;  P(37) = pp.fr_tau_alpha;  P(38) = pp.fr_ul_W_m2K;  P(39) = pp.I_cutoff_Wm2;
P(40) = pp.obs_low;    P(41) = pp.obs_high;      P(42) = pp.T_init_water_C;  P(43) = pp.n_nodes;
P(51:60) = pp.m_w_node_kg(:);
P(61:70) = pp.n_caps_node(:);
P(71:80) = pp.loss_ua_node_W_K(:);

tw.P        = P;
tw.params   = pp;
tw.regime   = pp.regime_id;
tw.year     = year;
tw.demand24 = pp.demand_kg_by_hour(:);

% weather [hour_idx, GHI, T_amb, local_hour] + the forecast columns the V3 observation needs
W = readmatrix(fullfile(exportDir, sprintf('weather_%d.csv', year)));
W = W(:, 1:4);
N = size(W, 1);
tw.N = N;
tw.wx.time = (0:N-1)' * 3600;
tw.wx.signals.values = [W, forecast_columns(W, tw.demand24)];
tw.wx.signals.dimensions = 8;

% initial state = PCMEnv.reset(initial_pcm_state="solid")
tw.T0 = pp.T0_node_C(:);
tw.h0 = pp.h0_node_J_kg(:);
tw.s0 = pcm_derive_state(tw.T0, tw.h0, P);

% DQN Q-network
qfile = fullfile(exportDir, sprintf('dqn_qnet_r%d.json', pp.regime_id));
A = jsondecode(fileread(qfile));
tw.W1 = A.W1;  tw.b1 = A.b1(:);
tw.W2 = A.W2;  tw.b2 = A.b2(:);
tw.W3 = A.W3;  tw.b3 = A.b3(:);
assert(size(tw.W1, 2) == 17 && size(tw.W3, 1) == 3, 'expected a 17-input, 3-action Q-network');
tw.qnet_info = rmfield(A, {'W1', 'b1', 'W2', 'b2', 'W3', 'b3'});

% Python reference trajectory, if exported
refFile = fullfile(exportDir, sprintf('reference_%d.csv', year));
if isfile(refFile)
    tw.ref = readtable(refFile);
else
    tw.ref = [];
end
end

function F = forecast_columns(W, demand24)
% [GHI +1 h, GHI +2 h, GHI +3 h, draw of the next hour]; zero past the end of the record
% (pcm_env.py::forecast_ghi and the draw_p1 term of _get_obs).
n = size(W, 1);
F = zeros(n, 4);
for t = 1:n
    for dh = 1:3
        if t + dh <= n, F(t, dh) = W(t + dh, 2); end
    end
    if t + 1 <= n
        F(t, 4) = demand24(mod(round(W(t + 1, 4)), 24) + 1);
    end
end
end
