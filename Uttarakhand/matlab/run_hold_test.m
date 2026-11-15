function R = run_hold_test(K, W, T0, h0, iStart, H, thresholds)
%RUN_HOLD_TEST  Retention test of the joint plan (section 2.2), same definition as Rajasthan's run_hold_test.m.
%
%   R = run_hold_test(K, W, Tn, hn, iStart, 72, [30 40 45 50])
%
% From the node state (Tn, hn) the tank has at the END of weather row iStart-1, follow the next H hours with the
% sun off (GHI = 0), no draw, and the real ambient temperature of rows iStart..iStart+H-1. The restart carries the
% whole node temperature and enthalpy vectors. Read at the TOP layer (delivery node, where the shield looks).
%
% R fields (hourly traces have H+1 rows, row 1 = the start state, row k+1 = after k hours)
%   Ttop Tbot Tmean Tpcm fmelt E_stored_kWh E_rec_kWh Q_loss_cum_Wh
%   tau        hours above each threshold (first hour below, linear inside the hour; 0 if below at the start)
%   censored   true where the top layer was still above that threshold after H hours
if nargin < 6 || isempty(H), H = 72; end
if nargin < 7 || isempty(thresholds), thresholds = [30 40 45 50]; end
assert(iStart + H - 1 <= size(W, 1), 'run_hold_test: not enough weather rows after the start hour');
Kh = K; Kh.demand24 = zeros(24, 1);              % no draw
BYPASS = 0;                                      % no sun, so ENABLE and BYPASS are the same
T = T0(:); h = h0(:);
r0 = initial_record(T, h, Kh);                   % [Ttop Tbot Tmean Tpcm f draw Est Erec] of the start state
tr = zeros(H + 1, 8);
tr(1, :) = [r0(1) r0(2) r0(3) r0(4) r0(5) r0(7) r0(8) 0];
qcum = 0;
for k = 1:H
    row = iStart + k - 1;
    [T, h, rec] = pcm_plant_hour(0, W(row, 3), round(W(row, 4)), BYPASS, T, h, Kh);
    qcum = qcum + rec(8);
    tr(k + 1, :) = [rec(1) rec(20) rec(2) rec(3) rec(4) rec(18) rec(19) qcum];
end
R.Ttop = tr(:, 1); R.Tbot = tr(:, 2); R.Tmean = tr(:, 3); R.Tpcm = tr(:, 4);
R.fmelt = tr(:, 5); R.E_stored_kWh = tr(:, 6); R.E_rec_kWh = tr(:, 7); R.Q_loss_cum_Wh = tr(:, 8);
R.thresholds = thresholds(:)';
R.tau = zeros(1, numel(thresholds)); R.censored = false(1, numel(thresholds));
for j = 1:numel(thresholds)
    [R.tau(j), R.censored(j)] = crossing(R.Ttop, thresholds(j));
end
R.T_end = T; R.h_end = h;
end

function [tau, cens] = crossing(Ttop, thr)
% crossing_hours() of Objective 2's tes_metrics.py: first hour the outlet is below thr, linear inside the hour
if Ttop(1) < thr
    tau = 0; cens = false; return
end
for k = 2:numel(Ttop)
    if Ttop(k) < thr
        prev = Ttop(k - 1);
        tau = (k - 2) + (prev - thr) / (prev - Ttop(k));
        cens = false;
        return
    end
end
tau = numel(Ttop) - 1; cens = true;
end
