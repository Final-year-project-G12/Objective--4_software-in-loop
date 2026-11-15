function [K, h0] = swap_pcm(K, pcm)
%SWAP_PCM  Rebuild the plant struct for a different PCM (plan section 2.6), MATLAB side.
%
%   [K2, h0] = swap_pcm(K, pcm)      pcm = one entry of load_campaign(...).o1
%
% Only the MATERIAL changes; capsule count, size, wall, node layout and flow stay at the Objective 2 values.
% Objective 2's own rules (capsule_enthalpy.pcm_props_from_record, capsule_mass.py, tank_model_multinode):
%   melt band          Ts = Tm - 1 K, Tl = Tm + 1 K       (pcm_integration.melting_half_width_K = 1)
%   PCM per capsule    density_solid * (pi/6) (D - 2 t_wall)^3
%   wall cp per kg PCM x = m_wall * 900 / m_pcm,  m_wall = 2700 (pi/6) (D^3 - D_in^3)   (aluminium handbook values)
%   reset "solid"      PCM at Ts - 5 K in every node (water 30 C)
% The campaign itself does NOT use this function: it uses the tanks O2 builds (export_campaign.py). This file
% exists so check_energy_balance.m can show the swap is understood: swap_pcm(K, pcm) must reproduce O2's vector.
D = K.P(22); t_w = K.P(20);
D_in = D - 2 * t_w;
V_out = pi / 6 * D^3; V_in = pi / 6 * D_in^3;
m_pcm = pcm.density_solid_kg_m3 * V_in;
m_wall = 2700 * (V_out - V_in);
K.P(9)  = pcm.Tm_C - 1;
K.P(10) = pcm.Tm_C + 1;
K.P(11) = pcm.latent_heat_kJ_kg * 1000;
K.P(12) = pcm.cp_solid_kJ_kgK * 1000;
K.P(13) = pcm.cp_liquid_kJ_kgK * 1000;
K.P(14) = m_wall * 900 / m_pcm;
K.P(15) = pcm.k_W_mK;
K.P(24) = m_pcm;
Ts = K.P(9); Tl = K.P(10); L = K.P(11); cps = K.P(12); x = K.P(14);
T0 = Ts - 5;
h0 = (cps + x) * T0 * ones(K.N, 1);              % T0 < Ts: solid branch of h(T)
if T0 >= Ts, error('swap_pcm: reset temperature inside the band'); end %#ok<UNRCH>
K.h0 = h0;
[~] = L; [~] = Tl;
end
