function run_system3d_videos(which)
%RUN_SYSTEM3D_VIDEOS  The 70-hour 3-D system videos (Tamil Nadu style, three tanks, pump / collector / pipes / modes) for Rajasthan.
%
%   run_system3d_videos            % DQN r1, SAC r1, SAC r0, SAC r2
%   run_system3d_videos('SAC_r1')
% Writes ../video/o4_system3d_70h_r<k>_<DQN|SAC>_2023.mp4 and stills in ../pictures/. Details: animate_system3d.m.
here = fileparts(mfilename('fullpath')); addpath(here);
items = {1, 'DQN'; 1, 'SAC'; 0, 'SAC'; 2, 'SAC'};
if nargin > 0 && ~isempty(which)
    keep = false(size(items, 1), 1);
    for i = 1:size(items, 1), keep(i) = strcmp(sprintf('%s_r%d', items{i, 2}, items{i, 1}), which); end
    items = items(keep, :);
end
out = fullfile(here, '..', 'video');  if ~isfolder(out), mkdir(out); end
for i = 1:size(items, 1)
    f = fullfile(out, sprintf('o4_system3d_70h_r%d_%s_2023.mp4', items{i, 1}, items{i, 2}));
    animate_system3d(items{i, 1}, items{i, 2}, f);
    try, video_stills(f, sprintf('system3d_70h_r%d_%s', items{i, 1}, items{i, 2})); catch, end
end
end
