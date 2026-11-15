function [sc, inEv, nWin] = edge_scenarios(tw, K)
%EDGE_SCENARIOS  Edge cases of the joint plan (section 2.5), same definitions as Rajasthan's edge_scenarios.m.
%
%   [sc, inEv, nWin] = edge_scenarios(tw, K)     K = the PCM tank (C.base.K)
%
% Window: 1 April 2023, 4 days spin-up, event days 5-8, 2 days recovery.
%   clear, no_sunlight, rain_cloud, low_temperature, heat_wave, sensor_fault   (six cases of run_scenarios.m)
%   dead_pyranometer         the CONTROLLER's irradiance reads 0 W/m2 for the whole run (real sun unchanged)
%   stuck_mid_pyranometer    reads 500 W/m2 for the whole run
%   stuck_high_pyranometer   reads 1000 W/m2 for the whole run
% In Uttarakhand the smart forecast is computed from the pyranometer reading, so a faulty pyranometer also corrupts
% the forecast (Rajasthan's forecast is a weather feed and is not affected). Clear-sky columns are solar geometry and
% are never edited. Fields of sc: name, title, W, dK (mains offset), noise, blackout, stuck.
Wall = tw.wx.signals.values;
k0 = 90 * 24; nWin = 10 * 24;
base = Wall(k0 + (1:nWin), :);
iS = 4 * 24 + 1; iE = 8 * 24;
inEv = false(nWin, 1); inEv(iS:iE) = true;
nb = false(nWin, 1);
add = @(nm, ti, W, dm, nz, bo, st) struct('name', nm, 'title', ti, 'W', W, 'dmains', dm, 'noise', nz, 'blackout', bo, 'stuck', st);
sc = add('clear', 'Clear days (reference)', base, 0, 0, nb, NaN);
W = base; W(inEv, 2) = 0;
sc(end+1) = add('no_sunlight', 'No sunlight for 4 days', W, 0, 0, nb, NaN);
W = base; W(inEv, 2) = min(0.12 * base(inEv, 2), 120); W(inEv, 3) = base(inEv, 3) - 5;
sc(end+1) = add('rain_cloud', 'Rain / heavy cloud (GHI x0.12, ambient -5 C)', W, 0, 0, nb, NaN);
W = base; W(inEv, 3) = base(inEv, 3) - 12; W(inEv, 2) = 0.9 * base(inEv, 2);
sc(end+1) = add('low_temperature', 'Low temperature (ambient -12 C, mains -8 C)', W, -8, 0, nb, NaN);
W = base; W(inEv, 3) = base(inEv, 3) + 9; W(inEv, 2) = 1.15 * base(inEv, 2);
sc(end+1) = add('heat_wave', 'Heat wave (ambient +9 C, GHI x1.15)', W, 0, 0, nb, NaN);
bo = nb; bo(iS:iS + 11) = true;
sc(end+1) = add('sensor_fault', 'Noisy sensors + 12 h sensor blackout', base, 0, 1, bo, NaN);
sc(end+1) = add('dead_pyranometer', 'Dead pyranometer (reads 0 W/m^2, real sun unchanged)', base, 0, 0, nb, 0);
sc(end+1) = add('stuck_mid_pyranometer', 'Pyranometer stuck at 500 W/m^2 (real sun unchanged)', base, 0, 0, nb, 500);
sc(end+1) = add('stuck_high_pyranometer', 'Pyranometer stuck at 1000 W/m^2 (real sun unchanged)', base, 0, 0, nb, 1000);
[~] = K;
end
