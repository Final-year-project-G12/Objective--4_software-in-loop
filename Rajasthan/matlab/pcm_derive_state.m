function s = pcm_derive_state(T, h, P)
%PCM_DERIVE_STATE  The seven tank quantities the controller observes, from the node state.
%
% Same formulas as the end-of-hour block of the O2 kernel
% (tank_model_multinode.py::_kernel, "---- end of hour") and o2_adapter.OneHourKernel.derived.
%
%   s = [T_top; T_bottom; T_mean; T_pcm; f_melt; E_stored_kWh; E_rec45_kWh]
%     T_top / T_bottom   top (delivery) and bottom (collector inlet) water node [C]
%     T_mean             mass-weighted mean water temperature [C]
%     T_pcm, f_melt      PCM-mass-weighted mean PCM temperature and melt fraction
%     E_stored_kWh       energy in the store above the mains temperature
%     E_rec45_kWh        energy recoverable above the 45 C delivery target
%#codegen
N = 10;
T = T(:); h = h(:);
cp = P(1);  mains = P(3);  target = P(4);
Ts = P(9);  Tl = P(10);  L = P(11);  cps = P(12);  cpl = P(13);  x = P(14);
m_cap = P(24);
m_w = P(51:60);  n_caps = P(61:70);
m_w = m_w(:);  n_caps = n_caps(:);

n_caps_tot = 0;  m_w_tot = 0;
for i = 1:N
    n_caps_tot = n_caps_tot + n_caps(i);
    m_w_tot = m_w_tot + m_w(i);
end
has_pcm = n_caps_tot > 0;
m_pcm_tot = n_caps_tot * m_cap;

h_mains = h_of_T(mains, Ts, Tl, L, cps, cpl, x);
h_target = h_of_T(target, Ts, Tl, L, cps, cpl, x);

t_mean = 0;  e_rel = 0;  e_rec = 0;  tp_mean = 0;  fm = 0;
for i = 1:N
    t_mean = t_mean + T(i) * m_w(i) / m_w_tot;
    e_rel = e_rel + m_w(i) * cp * (T(i) - mains);
    e_rec = e_rec + m_w(i) * cp * max(T(i) - target, 0);
    if n_caps(i) > 0
        m_pcm_i = n_caps(i) * m_cap;
        [Tp_i, f_i] = T_f_of_h(h(i), Ts, Tl, L, cps, cpl, x);
        e_rel = e_rel + m_pcm_i * (h(i) - h_mains);
        e_rec = e_rec + m_pcm_i * max(h(i) - h_target, 0);
        tp_mean = tp_mean + Tp_i * m_pcm_i / m_pcm_tot;
        fm = fm + f_i * m_pcm_i / m_pcm_tot;
    end
end
if ~has_pcm
    tp_mean = t_mean;
end
s = [T(N); T(1); t_mean; tp_mean; fm; e_rel / 3.6e6; e_rec / 3.6e6];
end

function hh = h_of_T(T, Ts, Tl, L, cps, cpl, x)
%#codegen
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

function [T, f] = T_f_of_h(hh, Ts, Tl, L, cps, cpl, x)
%#codegen
hs = (cps + x) * Ts;
span = L + x * (Tl - Ts);
hl = hs + span;
if hh < hs
    T = hh / (cps + x);  f = 0;
elseif hh <= hl
    if span > 0, f = (hh - hs) / span; else, f = 1; end
    f = min(max(f, 0), 1);
    T = Ts + f * (Tl - Ts);
else
    T = Tl + (hh - hl) / (cpl + x);  f = 1;
end
end
