function [sc, inEv, nWin] = edge_scenarios(tw)
%EDGE_SCENARIOS  The edge-case definitions of run_scenarios.m as a function, plus three pyranometer faults.
%
%   [sc, inEv, nWin] = edge_scenarios(tw)
%
% Same weather window and edits as run_scenarios.m (1 April 2023, 4 days spin-up, event days 5-8, 2 days recovery; this file
% repeats them so run_scenarios.m, whose outputs must not change, stays untouched):
%   clear, no_sunlight, rain_cloud, low_temperature, heat_wave, sensor_fault   (the six original scenarios)
%   dead_pyranometer          the controller's irradiance reads 0 W/m2 for the whole run (real sun unchanged)
%   stuck_high_pyranometer    reads 1000 W/m2 for the whole run
%   stuck_mid_pyranometer     reads 500 W/m2 for the whole run
% Assumptions (listed because the plan does not define them): a "stuck" sensor holds a constant value for the whole run (the
% Tamil Nadu twin froze it at its first reading, which is 0 at midnight and so equals the dead case); the observation's 1-3 h
% forecast is a weather-feed value and is not affected; the three faults use the clear April weather.
% Fields of sc: name, title, W, P, noise, blackout, stuck (NaN = healthy sensor).
Wall = tw.wx.signals.values(:, 1:4);
k0 = 90 * 24;  nWin = 10 * 24;
base = Wall(k0 + (1:nWin + 3), :);
iS = 4 * 24 + 1;  iE = 8 * 24;
inEv = false(nWin, 1);  inEv(iS:iE) = true;
ev = [inEv; false(3, 1)];
nb = false(nWin, 1);
add = @(nm, ti, W, P, nz, bo, st) struct('name', nm, 'title', ti, 'W', W, 'P', P, 'noise', nz, 'blackout', bo, 'stuck', st);

sc = add('clear', 'Clear sunny days (reference)', base, tw.P, 0, nb, NaN);
W = base; W(ev, 2) = 0;
sc(end+1) = add('no_sunlight', 'No sunlight for 4 days', W, tw.P, 0, nb, NaN);
W = base; W(ev, 2) = min(0.12 * base(ev, 2), 120); W(ev, 3) = base(ev, 3) - 5;
sc(end+1) = add('rain_cloud', 'Rain / heavy cloud (GHI x0.12, ambient -5 C)', W, tw.P, 0, nb, NaN);
W = base; W(ev, 3) = base(ev, 3) - 12; W(ev, 2) = 0.9 * base(ev, 2);
P = tw.P; P(3) = P(3) - 8;
sc(end+1) = add('low_temperature', 'Low temperature (ambient -12 C, mains -8 C)', W, P, 0, nb, NaN);
W = base; W(ev, 3) = base(ev, 3) + 9; W(ev, 2) = 1.15 * base(ev, 2);
sc(end+1) = add('heat_wave', 'Heat wave (ambient +9 C, GHI x1.15)', W, tw.P, 0, nb, NaN);
bo = nb; bo(iS:iS + 11) = true;
sc(end+1) = add('sensor_fault', 'Noisy sensors + 12 h sensor blackout', base, tw.P, 1, bo, NaN);
sc(end+1) = add('dead_pyranometer', 'Dead pyranometer (reads 0 W/m^2, real sun unchanged)', base, tw.P, 0, nb, 0);
sc(end+1) = add('stuck_high_pyranometer', 'Pyranometer stuck at 1000 W/m^2 (real sun unchanged)', base, tw.P, 0, nb, 1000);
sc(end+1) = add('stuck_mid_pyranometer', 'Pyranometer stuck at 500 W/m^2 (real sun unchanged)', base, tw.P, 0, nb, 500);
end
