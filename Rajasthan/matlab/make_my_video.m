function L = make_my_video(varargin)
%MAKE_MY_VIDEO  Run the trained Rajasthan controller on a scenario of your choice and
% write the animated schematic to an MP4.
%
%   make_my_video                                   % defaults: regime 1, rain_cloud
%   make_my_video('scenario','no_sunlight')
%   make_my_video('regime',0,'scenario','heat_wave','days',[4 9])
%   make_my_video('scenario','custom','ghi_mult',0.3,'tamb_offset',-6, ...
%                 'event_days',[5 8],'policy','b0')
%
% Options (name, value):
%   regime        0 | 1 | 2                     which exported plant + policy (default 1)
%   scenario      clear | no_sunlight | rain_cloud | low_temperature |
%                 heat_wave | sensor_fault | custom      (default rain_cloud)
%   policy        'dqn' (trained) | 'b0' (always charge)  (default 'dqn')
%   days          [first last] days of the 10-day window to film (default [4 9];
%                 the event is days 5-8, so this shows the day before and after)
%   event_days    [first last] days the weather is modified (default [5 8])
%   ghi_mult, ghi_cap, tamb_offset, mains_offset   only for scenario 'custom'
%   frames_per_hour  smoother = bigger = slower to render (default 2)
%   out           output file (default <export>/scenarios/my_<scenario>_<policy>.mp4)
%
% Weather is real April 2023 data for the regime's medoid point (Objective 2/3 files).
% Returns the simulation log L for your own plots.
here = fileparts(mfilename('fullpath')); addpath(here);
o = struct('regime', 1, 'scenario', 'rain_cloud', 'policy', 'dqn', 'days', [4 9], ...
    'event_days', [5 8], 'ghi_mult', 1, 'ghi_cap', inf, 'tamb_offset', 0, 'mains_offset', 0, ...
    'frames_per_hour', 2, 'out', '');
for k = 1:2:numel(varargin), o.(varargin{k}) = varargin{k+1}; end

expDir = fullfile(here, '..', sprintf('export_r%d', o.regime));
outDir = fullfile(expDir, 'scenarios'); if ~isfolder(outDir), mkdir(outDir); end
tw = load_twin_params(expDir, 2023);

% ---- presets: [ghi_mult ghi_cap tamb_offset mains_offset] ----
switch o.scenario
    case 'clear',           q = [1    inf  0   0];
    case 'no_sunlight',     q = [0    inf  0   0];
    case 'rain_cloud',      q = [0.12 120 -5   0];
    case 'low_temperature', q = [0.9  inf -12 -8];
    case 'heat_wave',       q = [1.15 inf  9   0];
    case 'sensor_fault',    q = [1    inf  0   0];
    case 'custom',          q = [o.ghi_mult o.ghi_cap o.tamb_offset o.mains_offset];
    otherwise, error('Unknown scenario "%s"', o.scenario);
end

Wall = tw.wx.signals.values(:, 1:4);
k0 = 90 * 24; nWin = 10 * 24;                      % 1 April, ten days
W = Wall(k0 + (1:nWin + 3), :);                    % + 3 real hours for the forecast at the end
ev = false(nWin + 3, 1); ev((o.event_days(1) - 1) * 24 + 1 : o.event_days(2) * 24) = true;
W(ev, 2) = min(q(1) * W(ev, 2), q(2));
W(ev, 3) = W(ev, 3) + q(3);
P = tw.P; P(3) = P(3) + q(4);                      % P(3) = mains temperature
noise = 0; bo = false(nWin, 1);
if strcmp(o.scenario, 'sensor_fault')
    noise = 1; bo((o.event_days(1) - 1) * 24 + (1:12)) = true; rng(7);
end

pm = double(strcmpi(o.policy, 'b0'));
L = simulate_hours(tw, W, P, pm, noise, bo, nWin);

% keep only the requested days
sel = (o.days(1) - 1) * 24 + 1 : o.days(2) * 24;
F = fieldnames(L); Lt = struct();
for i = 1:numel(F), Lt.(F{i}) = L.(F{i})(sel, :); end

if isempty(o.out)
    o.out = fullfile(outDir, sprintf('my_%s_%s.mp4', o.scenario, lower(o.policy)));
end
ttl = sprintf('Rajasthan regime %d - %s - %s', o.regime, strrep(o.scenario, '_', ' '), upper(o.policy));
fprintf('Rendering %d hours to %s ...\n', numel(sel), o.out);
tic; animate_system(Lt, o.out, ttl, o.frames_per_hour, P(39));
fprintf('Done in %.0f s. Delivered %.1f kWh, shield trips %d, hard violations %d.\n', toc, ...
    sum(Lt.E_del_Wh) / 1000, sum(Lt.n_sw + Lt.n_sp), sum(Lt.n_viol));
end
