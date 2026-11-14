function run_3d_videos(which)
%RUN_3D_VIDEOS  3-D cutaway videos of the PCM + DQN tank (Tamil Nadu scope item 9), in the Tamil Nadu video naming.
%
%   run_3d_videos                       % day, edge, edge_no_sunlight, hold
%   run_3d_videos('hold')
%
%   day               ../video/o4_3d_day<DDD>_2023.mp4           the one-day cycle of one_day_cycle.m (24 h, clock caption)
%   edge              ../video/o4_3d_edge_clear_2023.mp4         clear April day, event day 1 of the edge-case window
%   edge_no_sunlight  ../video/o4_3d_edge_no_sunlight_2023.mp4   no-sunlight event day 1
%   hold              ../video/o4_3d_hold72h_day<DDD>_2023.mp4   72 h of cooling from 18:00 of the same day as 'day'
% Layer colours = the 10 node temperatures, capsule colours = node melt fraction. A 3-D view of a 1-D result (animate_tank3d.m): nothing
% is solved in 3-D and the capsule ring layout is illustrative. Unlike the single-node Tamil Nadu twin, the 10 layers are real (they differ).
here = fileparts(mfilename('fullpath')); addpath(here);
tw = load_twin_params(fullfile(here, '..', 'export_r1'), 2023);
W = tw.wx.signals.values(:, 1:4);  P = tw.P;
if nargin < 1 || isempty(which), which = {'day', 'edge', 'edge_no_sunlight', 'hold'}; end
if ischar(which), which = {which}; end
out = fullfile(here, '..', 'video');  if ~isfolder(out), mkdir(out); end
clock = @(L) @(k) sprintf('%02d:00   top %.1f \\circC   bottom %.1f \\circC   melted %3.0f %%', mod(round(L.hod(k)), 24), L.Tn(k, 10), L.Tn(k, 1), 100 * L.f_melt(k));
L3 = [];
for k = 1:numel(which)
    switch which{k}
        case {'day', 'hold'}
            if isempty(L3), L3 = simulate_hours(tw, W, P, 0, 0, []); end
            rows17 = find(W(:, 4) == 17);  sd = round(linspace(15, 345, 12));
            [~, i] = max(L3.E_stored_kWh(rows17(sd)));  day = sd(i);
            if strcmp(which{k}, 'day')
                r = (rows17(day) - 17):(rows17(day) + 6);
                Lc = cut(L3, r);
                f = fullfile(out, sprintf('o4_3d_day%03d_2023.mp4', day));
                animate_tank3d(Lc, P, f, clock(Lc));  stills(f, '3d_day');
            else
                t = rows17(day);  H = 72;
                T = L3.Tn(t, :)';  h = L3.hn(t, :)';  Tn = zeros(H + 1, 10);  hn = zeros(H + 1, 10);  Tn(1, :) = T';  hn(1, :) = h';
                for j = 1:H
                    [T, h] = pcm_plant_hour(0, W(t + j, 3), 0, 2, T, h, P);  Tn(j + 1, :) = T';  hn(j + 1, :) = h';
                end
                f = fullfile(out, sprintf('o4_3d_hold72h_day%03d_2023.mp4', day));
                animate_tank3d(struct('Tn', Tn, 'hn', hn), P, f);  stills(f, '3d_hold72h');
            end
        case {'edge', 'edge_no_sunlight'}
            [sc, ~, nWin] = edge_scenarios(tw);
            nm = 'clear';  if strcmp(which{k}, 'edge_no_sunlight'), nm = 'no_sunlight'; end
            c = sc(strcmp({sc.name}, nm));
            Le = simulate_hours(tw, c.W, c.P, 0, c.noise, c.blackout, nWin, c.stuck);
            Lc = cut(Le, (4 * 24 + 1):(5 * 24));
            f = fullfile(out, sprintf('o4_3d_edge_%s_2023.mp4', nm));
            animate_tank3d(Lc, P, f, clock(Lc));  stills(f, ['3d_edge_' nm]);
    end
    fprintf('[3d video] %s -> %s\n', which{k}, f);
end
end

function stills(f, prefix)
video_stills(f, prefix);
end

function Lt = cut(L, sel)
F = fieldnames(L);  Lt = struct();
for i = 1:numel(F), Lt.(F{i}) = L.(F{i})(sel, :); end
end
