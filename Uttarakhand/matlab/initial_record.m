function rec8 = initial_record(T0, h0, K)
%INITIAL_RECORD  Observation-side record at the reset state (o3/env.py::initial_record).
%
% rec8 = [T_top; T_bottom; T_mean; T_pcm; f_melt; draw_kg; E_stored_kWh; E_rec_kWh]
% with the kernel's definitions (mass-weighted PCM temperature and melt
% fraction, stored / recoverable energy above mains / delivery target).
%#codegen
P = K.P; m_w = K.m_w(:); n_caps = K.n_caps(:); N = numel(m_w);
cp = P(1); mains = P(3); target = P(4);
Ts = P(9); Tl = P(10); L = P(11); cps = P(12); cpl = P(13); x = P(14); m_cap = P(24);

tm = sum(T0(:) .* m_w) / sum(m_w);
e_st = sum(m_w * cp .* (T0(:) - mains));
e_rec = sum(m_w * cp .* max(T0(:) - target, 0));
tp = tm; f = 0;
if any(n_caps > 0)
    m_node = n_caps * m_cap;
    hm = hT(mains, Ts, Tl, L, cps, cpl, x);
    ht = hT(target, Ts, Tl, L, cps, cpl, x);
    wsum = 0; tp = 0; f = 0;
    for i = 1:N
        if n_caps(i) > 0, wsum = wsum + m_node(i); end
    end
    for i = 1:N
        if n_caps(i) > 0
            [ti, fi] = Tf(h0(i), Ts, Tl, L, cps, cpl, x);
            w = m_node(i) / wsum;
            tp = tp + w * ti; f = f + w * fi;
            e_st = e_st + m_node(i) * (h0(i) - hm);
            e_rec = e_rec + m_node(i) * max(h0(i) - ht, 0);
        end
    end
end
rec8 = [T0(N); T0(1); tm; tp; f; 0; e_st / 3.6e6; e_rec / 3.6e6];
end

function h = hT(T, Ts, Tl, L, cps, cpl, x)
hs = (cps + x) * Ts; span = L + x * (Tl - Ts);
if T < Ts, h = (cps + x) * T;
elseif T <= Tl, h = hs + span * (T - Ts) / (Tl - Ts);
else, h = hs + span + (cpl + x) * (T - Tl);
end
end

function [T, f] = Tf(h, Ts, Tl, L, cps, cpl, x)
hs = (cps + x) * Ts; span = L + x * (Tl - Ts); hl = hs + span;
if h < hs, T = h / (cps + x); f = 0;
elseif h <= hl, f = min(max((h - hs) / span, 0), 1); T = Ts + f * (Tl - Ts);
else, T = Tl + (h - hl) / (cpl + x); f = 1;
end
end
