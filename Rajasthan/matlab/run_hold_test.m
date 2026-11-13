function R = run_hold_test(P, W, T0, h0, iStart, H, thresholds, dFreeze)
%RUN_HOLD_TEST  The retention test of plan section 4.3 (Objective 2's tau_hold, on the 10-node twin).
%
%   R = run_hold_test(P, W, Tn, hn, iStart, 72, [30 40 45 50])
%
% From the node state (Tn, hn) the tank has at the END of weather row iStart-1, follow the next H hours
% with the sun off (GHI = 0), no draw, and the real ambient temperature of rows iStart..iStart+H-1.
% (Objective 2: "hours from 18:00 local that the tank alone keeps the outlet at or above the target".)
% The restart carries the whole node temperature and enthalpy vectors, not two scalars.
%
%   P           parameter vector (any PCM, plain or PCM tank)
%   W           [m x 4] weather rows [hour_idx GHI T_amb local_hour]
%   T0, h0      [10x1] node water temperature [C] / PCM enthalpy [J/kg] at the start
%   iStart      first weather row of the hold
%   H           hours to follow (default 72, Objective 2's cap)
%   thresholds  temperatures at which tau_hold is read (default [30 40 45 50])
%   dFreeze     supercooling proxy [K], default 0: the PCM freezes dFreeze K below where it melts. At the start of the
%               hold the melt band is moved down by dFreeze (Ts, Tl -> Ts - dFreeze, Tl - dFreeze) and every capsule node's
%               enthalpy is re-expressed so that its melt fraction (inside the band) or its temperature (fully solid or
%               fully liquid) is unchanged. Valid for the discharge that a hold test is; the kernel has one band for both
%               directions, so this is a sensitivity proxy, not a hysteresis model.
%
% R fields (hourly traces have H+1 rows, row 1 = the start state, row k+1 = after k hours)
%   Ttop Tbot Tmean Tpcm fmelt E_stored_kWh E_rec_kWh Q_loss_cum_Wh   hourly traces
%   tau       hours above each threshold (linear inside the hour, 0 if already below at the start)
%   censored  true where the tank was still above that threshold after H hours
%   thresholds
if nargin < 6 || isempty(H), H = 72; end
if nargin < 7 || isempty(thresholds), thresholds = [30 40 45 50]; end
if nargin < 8 || isempty(dFreeze), dFreeze = 0; end
assert(iStart + H - 1 <= size(W, 1), 'run_hold_test: not enough weather rows after the start hour');

BYPASS = 2;                                   % no sun, so CHARGE/IDLE/BYPASS are all equivalent
T = T0(:);  h = h0(:);
if dFreeze ~= 0
    Pn = P;  Pn(9) = P(9) - dFreeze;  Pn(10) = P(10) - dFreeze;
    for i = 1:10
        if P(60 + i) > 0, h(i) = reband(h(i), P, Pn); end
    end
    P = Pn;
end
s = pcm_derive_state(T, h, P);
tr = zeros(H + 1, 8);
tr(1, :) = [s(1) s(2) s(3) s(4) s(5) s(6) s(7) 0];
qcum = 0;
for k = 1:H
    row = iStart + k - 1;
    [T, h, ~, xo] = pcm_plant_hour(0, W(row, 3), 0, BYPASS, T, h, P);
    s = pcm_derive_state(T, h, P);
    qcum = qcum + xo(2);
    tr(k + 1, :) = [s(1) s(2) s(3) s(4) s(5) s(6) s(7) qcum];
end
R.Ttop = tr(:, 1);  R.Tbot = tr(:, 2);  R.Tmean = tr(:, 3);  R.Tpcm = tr(:, 4);
R.fmelt = tr(:, 5);  R.E_stored_kWh = tr(:, 6);  R.E_rec_kWh = tr(:, 7);  R.Q_loss_cum_Wh = tr(:, 8);
R.thresholds = thresholds(:)';
R.tau = zeros(1, numel(thresholds));
R.censored = false(1, numel(thresholds));
for j = 1:numel(thresholds)
    [R.tau(j), R.censored(j)] = crossing(R.Ttop, thresholds(j));
end
R.T_end = T;  R.h_end = h;
end

function [tau, cens] = crossing(Ttop, thr)
% crossing_hours() of Objective 2's tes_metrics.py: first hour the outlet falls below thr,
% linear inside the hour; censored if it never does.
if Ttop(1) < thr
    tau = 0;  cens = false;  return
end
for k = 2:numel(Ttop)
    if Ttop(k) < thr
        prev = Ttop(k - 1);
        tau = (k - 2) + (prev - thr) / (prev - Ttop(k));
        cens = false;
        return
    end
end
tau = numel(Ttop) - 1;  cens = true;
end

function hn = reband(h, P, Pn)
% enthalpy in the moved band with the same melt fraction (inside the band) or the same temperature (outside it)
[T, f] = T_f(h, P);
if f > 0 && f < 1
    Tn = Pn(9) + f * (Pn(10) - Pn(9));
else
    Tn = T;
end
hn = h_of_T(Tn, Pn);
end

function [T, f] = T_f(hh, P)
Ts = P(9);  Tl = P(10);  L = P(11);  cps = P(12);  cpl = P(13);  x = P(14);
hs = (cps + x) * Ts;  span = L + x * (Tl - Ts);  hl = hs + span;
if hh < hs, T = hh / (cps + x);  f = 0;
elseif hh <= hl, f = (hh - hs) / span;  T = Ts + f * (Tl - Ts);
else, T = Tl + (hh - hl) / (cpl + x);  f = 1;
end
end

function hh = h_of_T(T, P)
Ts = P(9);  Tl = P(10);  L = P(11);  cps = P(12);  cpl = P(13);  x = P(14);
hs = (cps + x) * Ts;  span = L + x * (Tl - Ts);
if T < Ts, hh = (cps + x) * T;
elseif T <= Tl, hh = hs + span * (T - Ts) / (Tl - Ts);
else, hh = hs + span + (cpl + x) * (T - Tl);
end
end
