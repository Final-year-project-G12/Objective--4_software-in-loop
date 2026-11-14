function video_stills(mp4, prefix, fractions)
%VIDEO_STILLS  Save a few frames of a video into ../pictures/ as <prefix>_<seconds>s.png (the Tamil Nadu naming, e.g. edge_clear_03.3s.png).
%
%   video_stills('../video/o4_three_arm_day165_2023.mp4', 'three_arm_day')
%   video_stills(file, prefix, [0.2 0.4 0.6 0.8 0.95])     % positions as fractions of the video length
here = fileparts(mfilename('fullpath'));
outDir = fullfile(here, '..', 'pictures');
if ~isfolder(outDir), mkdir(outDir); end
if nargin < 3 || isempty(fractions), fractions = [0.15 0.3 0.5 0.7 0.9]; end
r = VideoReader(mp4);
for f = fractions
    r.CurrentTime = min(f * r.Duration, r.Duration - 1 / r.FrameRate);
    img = readFrame(r);
    imwrite(img, fullfile(outDir, sprintf('%s_%04.1fs.png', prefix, r.CurrentTime)));
end
end
