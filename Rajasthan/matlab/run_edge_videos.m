function run_edge_videos(names)
%RUN_EDGE_VIDEOS  Three-arm 2-D videos of one edge-case day, and the three-arm day video (Tamil Nadu scope items 3, 4 and 9).
%
%   run_edge_videos                      % clear, no_sunlight, rain_cloud, low_temperature, heat_wave, sensor_fault, dead_pyranometer
%   run_edge_videos('heat_wave')         % one scenario (any name of edge_scenarios.m)
%   run_edge_videos('three_arm_day')     % the one-day cycle of one_day_cycle.m, 24 h, three arms
%
% Edge videos: the first event day (hours 97-120 of the 10-day April window), three arms on the same weather, written to
% ../export_r1/scenarios_3arm/video/edge_<name>.mp4 (a new folder). The day video goes to ../video/o4_three_arm_day<DDD>_2023.mp4
% with the day chosen as in one_day_cycle.m. A few stills of each are saved to ../pictures/ (video_stills.m).
% The sensor_fault clip shows the first 24 h of its 12 h blackout: every arm falls back to BYPASS (the interlock), which is why it delivers least.
here = fileparts(mfilename('fullpath')); addpath(here);
tw = load_twin_params(fullfile(here, '..', 'export_r1'), 2023);
if nargin < 1 || isempty(names)
    names = {'clear', 'no_sunlight', 'rain_cloud', 'low_temperature', 'heat_wave', 'sensor_fault', 'dead_pyranometer'};
end
if ischar(names), names = {names}; end
for k = 1:numel(names)
    if strcmp(names{k}, 'three_arm_day')
        three_arm_day(tw, here);
        continue
    end
    [sc, ~, nWin] = edge_scenarios(tw);
    c = sc(strcmp({sc.name}, names{k}));
    assert(~isempty(c), 'unknown scenario %s', names{k});
    Pp = make_plain_tank(c.P);
    rng(7); L1 = simulate_hours(tw, c.W, Pp, 1, c.noise, c.blackout, nWin, c.stuck);
    rng(7); L2 = simulate_hours(tw, c.W, c.P, 1, c.noise, c.blackout, nWin, c.stuck);
    rng(7); L3 = simulate_hours(tw, c.W, c.P, 0, c.noise, c.blackout, nWin, c.stuck);
    sel = (4 * 24 + 1):(5 * 24);
    out = fullfile(here, '..', 'export_r1', 'scenarios_3arm', 'video');
    if ~isfolder(out), mkdir(out); end
    f = fullfile(out, ['edge_' c.name '.mp4']);
    tic; animate_three_arm({cut(L1, sel), cut(L2, sel), cut(L3, sel)}, f, sprintf('Rajasthan r1, %s (April 2023, event day 1)', strrep(c.name, '_', ' ')), 3, tw.P(39));
    fprintf('[edge video] %s (%.0f s)\n', f, toc);
    video_stills(f, ['edge_' c.name]);
end
end

function three_arm_day(tw, here)
W = tw.wx.signals.values(:, 1:4);
P = tw.P;  Pp = make_plain_tank(P);
L = {simulate_hours(tw, W, Pp, 1, 0, []), simulate_hours(tw, W, P, 1, 0, []), simulate_hours(tw, W, P, 0, 0, [])};
rows17 = find(W(:, 4) == 17);
sd = round(linspace(15, 345, 12));
[~, k] = max(L{3}.E_stored_kWh(rows17(sd)));
day = sd(k);
r = (rows17(day) - 17):(rows17(day) + 6);
out = fullfile(here, '..', 'video');
if ~isfolder(out), out = fullfile(here, '..', 'video'); mkdir(out); end
f = fullfile(out, sprintf('o4_three_arm_day%03d_2023.mp4', day));
tic; animate_three_arm({cut(L{1}, r), cut(L{2}, r), cut(L{3}, r)}, f, sprintf('Rajasthan r1, day %d of 2023 (00:00 to 06:00 next day)', day), 3, P(39));
fprintf('[three-arm day video] %s (%.0f s)\n', f, toc);
video_stills(f, 'three_arm_day');
end

function Lt = cut(L, sel)
F = fieldnames(L);  Lt = struct();
for i = 1:numel(F), Lt.(F{i}) = L.(F{i})(sel, :); end
end
