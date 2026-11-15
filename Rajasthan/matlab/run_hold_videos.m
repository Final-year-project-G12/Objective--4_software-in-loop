function run_hold_videos(which)
%RUN_HOLD_VIDEOS  The 70-hour heat-retention videos (three tanks per video) for Rajasthan, DQN and SAC.
%
%   run_hold_videos            % DQN r1, SAC r1, SAC r0, SAC r2
%   run_hold_videos('SAC_r0')
%
% Writes ../video/o4_hold70h_r<k>_<DQN|SAC>_2023.mp4, stills in ../pictures/ and ../video/hold70h_summary.csv. Details: animate_hold_video.m.
here = fileparts(mfilename('fullpath')); addpath(here);
items = {1, 'DQN'; 1, 'SAC'; 0, 'SAC'; 2, 'SAC'};
if nargin > 0 && ~isempty(which)
    keep = false(size(items, 1), 1);
    for i = 1:size(items, 1), keep(i) = strcmp(sprintf('%s_r%d', items{i, 2}, items{i, 1}), which); end
    items = items(keep, :);
end
out = fullfile(here, '..', 'video');  if ~isfolder(out), mkdir(out); end
rows = {};
for i = 1:size(items, 1)
    f = fullfile(out, sprintf('o4_hold70h_r%d_%s_2023.mp4', items{i, 1}, items{i, 2}));
    R = animate_hold_video(items{i, 1}, items{i, 2}, f);
    try, video_stills(f, sprintf('hold70h_r%d_%s', items{i, 1}, items{i, 2})); catch, end
    rows(end+1, :) = {items{i, 1}, items{i, 2}, R.day, R.tau_h(1), R.tau_h(2), R.tau_h(3), R.mean_tau_ctrl}; %#ok<AGROW>
end
T = cell2table(rows, 'VariableNames', {'regime', 'controller', 'day_shown', 'hold45_plain_h', 'hold45_pcm_B0_h', 'hold45_pcm_controller_h', 'controller_12_evening_mean_h'});
if nargin == 0 || isempty(which), writetable(T, fullfile(out, 'hold70h_summary.csv')); end
disp(T);
end
