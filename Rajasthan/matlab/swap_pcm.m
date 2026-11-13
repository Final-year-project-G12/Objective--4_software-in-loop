function [P, h0] = swap_pcm(P, pcm)
%SWAP_PCM  Re-build the plant parameter vector for a different PCM (plan section 6.1, axis 2).
%
%   [P2, h0] = swap_pcm(P, pcm)
%
%   P     the twin's 80-element parameter vector (load_twin_params.m)
%   pcm   one entry of results_campaign/campaign_config.json -> o1.pcms, with fields
%         Tm_C, latent_heat_kJ_kg, density_solid_kg_m3, cp_solid_kJ_kgK, cp_liquid_kJ_kgK, k_W_mK
%
% Only the MATERIAL changes: capsule count, capsule size, wall, node layout and flow stay at the
% Objective 2 values. Exactly what Objective 2 does when it builds the kernel
% (pcm_props_from_record + capsule_mass.py):
%   melting band  Ts = Tm - 1 K, Tl = Tm + 1 K         (melting_half_width_K = 1)
%   PCM mass of one capsule = density_solid * (pi/6) * (D - 2 t_wall)^3
%   wall heat capacity per kg PCM  x = m_wall * 900 / m_pcm,  m_wall = 2700 * (pi/6)(D^3 - D_in^3)
% (aluminium 2700 kg/m3, 900 J/kgK: the handbook values in capsule_mass.py).
D = P(22);  t_w = P(20);
D_in = D - 2 * t_w;
V_out = pi / 6 * D^3;  V_in = pi / 6 * D_in^3;
m_pcm = pcm.density_solid_kg_m3 * V_in;           % kg PCM per capsule
m_wall = 2700 * (V_out - V_in);                   % kg aluminium per capsule
P(9)  = pcm.Tm_C - 1;                             % Ts
P(10) = pcm.Tm_C + 1;                             % Tl
P(11) = pcm.latent_heat_kJ_kg * 1000;             % L   [J/kg]
P(12) = pcm.cp_solid_kJ_kgK * 1000;               % cp solid
P(13) = pcm.cp_liquid_kJ_kgK * 1000;              % cp liquid
P(14) = m_wall * 900 / m_pcm;                     % wall heat capacity per kg PCM
P(15) = pcm.k_W_mK;                               % PCM conductivity
P(24) = m_pcm;                                    % PCM mass per capsule
% capsule surface P(23) = pi D^2 and everything else is geometry: unchanged.

% initial enthalpy: the Objective 3 reset "solid" puts the PCM at Ts - 5 K
% (o3/environment/o2_adapter.py::initial_state), water at 30 C. Same value in every node (nodes without
% capsules ignore it).
h0 = h_of_T(P(9) - 5, P(9), P(10), P(11), P(12), P(13), P(14)) * ones(10, 1);
end

function hh = h_of_T(T, Ts, Tl, L, cps, cpl, x)
% same piecewise relation as pcm_plant_hour.m / capsule_enthalpy.py (Tref = 0 C)
hs = (cps + x) * Ts;
span = L + x * (Tl - Ts);
if T < Ts
    hh = (cps + x) * T;
elseif T <= Tl
    hh = hs + span * (T - Ts) / (Tl - Ts);
else
    hh = hs + span + (cpl + x) * (T - Tl);
end
end
