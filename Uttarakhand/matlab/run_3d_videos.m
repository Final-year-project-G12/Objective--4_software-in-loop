function run_3d_videos(which, regime)
%RUN_3D_VIDEOS  3-D cutaway videos of the PCM + PPO tank, Tamil Nadu / Rajasthan naming (Rajasthan's run_3d_videos.m,
% adapted to the Uttarakhand twin).
%
%   run_3d_videos                       % day, edge, edge_no_sunlight, hold (regime 1)
%   run_3d_videos('hold')
%
%   day               ../video/o4_3d_day<DDD>_2023.mp4           the one-day cycle of one_day_cycle.m (00:00-06:00 next day, clock caption)
%   edge              ../video/o4_3d_edge_clear_2023.mp4         clear April day, event day 1 of the edge-case window
%   edge_no_sunlight  ../video/o4_3d_edge_no_sunlight_2023.mp4   no-sunlight event day 1 (the PCM never melts)
%   hold              ../video/o4_3d_hold72h_day<DDD>_2023.mp4   72 h of cooling from 18:00 of the same day (sun off, no draw)
% Plus one still per video (../pictures/<prefix>_<n>.png at 1/4, 1/2, 3/4 of the clip).
% Layer colours = the 10 node temperatures, capsule colours = node melt fraction; nothing is solved in 3-D.
if nargin < 1 || isempty(which), which = {'day', 'edge', 'edge_no_sunlight', 'hold'}; end
if nargin < 2 || isempty(regime), regime = 1; end
if ischar(which), which = {which}; end
here = fileparts(mfilename('fullpath')); addpath(here);
tw = load_twin_params(twin_export_dir(regime), 2023);
C = load_campaign(regime); K = C.base.K;
W = tw.wx.signals.values;
out = fullfile(here, '..', 'video'); if ~isfolder(out), mkdir(out); end
clk = @(Lc) @(k) sprintf('%02d:00   top %.1f \\circC   bottom %.1f \\circC   melted %3.0f %%   %s', mod(round(Lc.hod(k)), 24), ...
    Lc.Tnodes(k, K.N), Lc.Tnodes(k, 1), 100 * Lc.f_melt(k), ternary(Lc.a_cmd(k) == 1, 'ENABLE', 'BYPASS'));
L3 = [];
rows17 = find(W(:, 4) == 17); sd = round(linspace(15, 345, 12));
for k = 1:numel(which)
    switch which{k}
        case {'day', 'hold'}
            if isempty(L3), L3 = simulate_hours(tw, W, K, 0, 0, []); end
            [~, i] = max(L3.E_stored_kWh(rows17(sd))); day = sd(i);
            if strcmp(which{k}, 'day')
                Lc = cut(L3, (rows17(day) - 17):(rows17(day) + 13), size(W, 1));
                f = fullfile(out, sprintf('o4_3d_day%03d_2023.mp4', day));
                animate_tank3d(Lc, K, f, clk(Lc), sprintf('Uttarakhand r%d, PCM + PPO, day %d of 2023', regime, day));
                stills(f, sprintf('3d_day%03d', day));
            else
                t = rows17(day); H = 72; Kh = K; Kh.demand24 = zeros(24, 1);
                T = L3.Tnodes(t, :)'; h = L3.hnodes(t, :)';
                Tn = zeros(H + 1, K.N); hn = Tn; Tn(1, :) = T'; hn(1, :) = h';
                for j = 1:H
                    [T, h] = pcm_plant_hour(0, W(t + j, 3), round(W(t + j, 4)), 0, T, h, Kh);
                    Tn(j + 1, :) = T'; hn(j + 1, :) = h';
                end
                f = fullfile(out, sprintf('o4_3d_hold72h_day%03d_2023.mp4', day));
                animate_tank3d(struct('Tnodes', Tn, 'hnodes', hn), K, f, [], ...
                    sprintf('Uttarakhand r%d, PCM + PPO: 72 h hold from 18:00 on day %d (sun off, no draw, real ambient)', regime, day));
                stills(f, sprintf('3d_hold72h_day%03d', day));
            end
        case {'edge', 'edge_no_sunlight'}
            [sc, ~, nWin] = edge_scenarios(tw, K);
            nm = 'clear'; if strcmp(which{k}, 'edge_no_sunlight'), nm = 'no_sunlight'; end
            c = sc(strcmp({sc.name}, nm));
            Kc = K; Kc.P(3) = Kc.P(3) + c.dmains;
            rng(7); Le = simulate_hours(tw, c.W, Kc, 0, c.noise, c.blackout, struct('n', nWin, 'stuck', c.stuck));
            Lc = cut(Le, (4 * 24 + 1):(5 * 24), nWin);
            f = fullfile(out, sprintf('o4_3d_edge_%s_2023.mp4', nm));
            animate_tank3d(Lc, K, f, clk(Lc), sprintf('Uttarakhand r%d, PCM + PPO, %s, event day 1 (5 April 2023)', regime, strrep(nm, '_', ' ')));
            stills(f, ['3d_edge_' nm]);
    end
    fprintf('[3d video] %s -> %s\n', which{k}, f);
end
end

function stills(f, prefix)
here = fileparts(mfilename('fullpath'));
pdir = fullfile(here, '..', 'pictures'); if ~isfolder(pdir), mkdir(pdir); end
if ~isfile(f), [d, n] = fileparts(f); f = fullfile(d, [n '.avi']); end
v = VideoReader(f);
for q = 1:3
    v.CurrentTime = min(q / 4 * v.Duration, v.Duration - 1 / v.FrameRate);
    imwrite(readFrame(v), fullfile(pdir, sprintf('%s_%d.png', prefix, q)));
end
end

function Lt = cut(L, sel, nrows)
F = fieldnames(L); Lt = struct();
for i = 1:numel(F)
    v = L.(F{i});
    if size(v, 1) == nrows, Lt.(F{i}) = v(sel, :); end
end
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
