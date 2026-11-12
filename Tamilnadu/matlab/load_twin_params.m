function tw = load_twin_params(exportDir, year)
%LOAD_TWIN_PARAMS  Read the Python exports into the structures the Simulink
% twin needs. Returns a struct with fields P, wx, demand24, W1..bmu, Tw0,
% Tpcm0, h0, f0, N, ref (reference table if present).
%
%   tw = load_twin_params('../export', 2011)
if nargin < 1 || isempty(exportDir)
    exportDir = fullfile(fileparts(mfilename('fullpath')), '..', 'export');
end
if nargin < 2, year = 2011; end

pp = jsondecode(fileread(fullfile(exportDir, 'plant_params.json')));

% parameter vector -- ORDER MUST MATCH pcm_plant_hour.m / build_obs.m / safety_interlock.m
P = [ pp.m_w_kg; pp.cp_w_J_kgK; pp.rho_w_kg_m3; pp.k_w_W_mK; pp.pr_w;        %  1-5
      pp.U_tank_W_m2K; pp.A_tank_m2; pp.T_mains_C; pp.T_deliv_C;              %  6-9
      pp.A_coll_m2; pp.fr_tau_alpha; pp.fr_ul_W_m2K; pp.I_cutoff_Wm2;         % 10-13
      pp.m_pcm_kg; pp.Tm_C; pp.half_width_K; pp.L_J_kg;                       % 14-17
      pp.cp_s_J_kgK; pp.cp_l_J_kgK; pp.k_pcm_W_mK; pp.wall_cp_J_kgK; pp.enhancement; % 18-22
      pp.n_capsule; pp.D_cap_m; pp.A_cap_m2; pp.t_wall_m; pp.k_wall_W_mK;    % 23-27
      pp.v_sup_m_s;                                                           % 28
      pp.max_wC; pp.max_pC; pp.shield_enabled; pp.bypass_wC; pp.bypass_pC;    % 29-33
      pp.dt_s; pp.n_sub_in_band; pp.band_margin_K; pp.stiffness_factor; pp.max_substeps; % 34-38
      pp.obs_low; pp.obs_high; pp.T_init_water_C ];                           % 39-41

tw.P        = P;
tw.params   = pp;
tw.demand24 = pp.demand_kg_by_hour(:);

% weather -> From Workspace structure [hour_idx, GHI, T_amb, local_hour]
W = readmatrix(fullfile(exportDir, sprintf('weather_%d.csv', year)));
N = size(W, 1);
tw.N = N;
tw.wx.time = (0:N-1)' * 3600;
tw.wx.signals.values = W(:, 1:4);
tw.wx.signals.dimensions = 4;

% initial state = PCMEnv.reset(initial_pcm_state="solid")
Ts = pp.Tm_C - pp.half_width_K;  Tl = pp.Tm_C + pp.half_width_K;
cps = pp.cp_s_J_kgK + pp.wall_cp_J_kgK;  cpl = pp.cp_l_J_kgK + pp.wall_cp_J_kgK;
h_s = cps * Ts;  span = pp.L_J_kg + pp.wall_cp_J_kgK * (Tl - Ts);
T0 = Ts - 5;
if T0 < Ts,     h0 = cps * T0;
elseif T0 <= Tl, h0 = h_s + (T0 - Ts) / (Tl - Ts) * span;
else,            h0 = h_s + span + cpl * (T0 - Tl);
end
if h0 < h_s,          Tp0 = h0 / cps; f0 = 0;
elseif h0 <= h_s+span, f0 = min(max((h0 - h_s) / span, 0), 1); Tp0 = Ts + f0 * (Tl - Ts);
else,                  Tp0 = Tl + (h0 - h_s - span) / cpl; f0 = 1;
end
tw.Tw0 = pp.T_init_water_C;  tw.Tpcm0 = Tp0;  tw.h0 = h0;  tw.f0 = f0;

% SAC actor
A = jsondecode(fileread(fullfile(exportDir, 'sac_actor_r0.json')));
tw.W1 = A.W1;  tw.b1 = A.b1(:);  tw.W2 = A.W2;  tw.b2 = A.b2(:);
tw.Wmu = reshape(A.Wmu, 1, []);  tw.bmu = A.bmu(:);

% Python reference trajectory, if exported
refFile = fullfile(exportDir, sprintf('reference_%d.csv', year));
if isfile(refFile)
    tw.ref = readtable(refFile);
else
    tw.ref = [];
end
end
