%VERIFY_CODEGEN  Compile the embedded controller to C and check it against MATLAB.
%
% 1. generates standalone C code for controller_step (folder ../export/codegen_c)
% 2. builds a MEX of the same C code and replays the policy's own observations
%    from the 2011 reference run through it, comparing every action with the
%    MATLAB function. This shows the generated C makes the same decisions.
%
% It is NOT a run on a real microcontroller: that needs a target board or an
% instruction-set simulator (processor-in-the-loop proper) and is left as the
% next stage. Set regime = 0/1/2 before running (default 0).
here = fileparts(mfilename('fullpath')); addpath(here);
if ~exist('regime', 'var'), regime = 0; end
if regime == 0, expDir = fullfile(here, '..', 'export'); else, expDir = fullfile(here, '..', sprintf('export_r%d', regime)); end
tw = load_twin_params(expDir, 2011);
nobs = size(tw.W1, 2);

W1 = single(tw.W1); b1 = single(tw.b1(:)); W2 = single(tw.W2); b2 = single(tw.b2(:));
Wmu = single(tw.Wmu); bmu = single(tw.bmu(:)); P = tw.P(:);
ex = {zeros(nobs, 1), 0, 0, 1, W1, b1, W2, b2, Wmu, bmu, P};

outC = fullfile(expDir, 'codegen_c');
cfg = coder.config('lib'); cfg.GenerateReport = false; cfg.TargetLang = 'C';
codegen('-config', cfg, 'controller_step', '-args', ex, '-d', outC, '-c', '-o', 'controller_step_lib');
files = dir(fullfile(outC, '**', '*.c'));
nlines = 0; for i = 1:numel(files), nlines = nlines + numel(readlines(fullfile(files(i).folder, files(i).name))); end
fprintf('[codegen] C code generated: %d .c files, %d lines in %s\n', numel(files), nlines, outC);

mcfg = coder.config('mex'); mcfg.GenerateReport = false;
outM = fullfile(expDir, 'codegen_mex');
codegen('-config', mcfg, 'controller_step', '-args', ex, '-o', 'controller_step_mex', '-d', outM);

ref = tw.ref; n = min(height(ref), 8760);
O = zeros(nobs, n);
for k = 1:nobs, O(k, :) = ref.(sprintf('obs%d', k - 1))(1:n)'; end
Tw_m = O(3, :) * 40 + 30; Tp_m = O(4, :) * 40 + 30;
clear safety_interlock controller_step_mex
a_m = zeros(n, 1); a_c = zeros(n, 1); s_m = zeros(n, 1); s_c = zeros(n, 1);
for t = 1:n
    [a_m(t), s_m(t)] = controller_step(O(:, t), Tw_m(t), Tp_m(t), 1, W1, b1, W2, b2, Wmu, bmu, P);
    [a_c(t), s_c(t)] = controller_step_mex(O(:, t), Tw_m(t), Tp_m(t), 1, W1, b1, W2, b2, Wmu, bmu, P);
end
agree = 100 * mean(a_m == a_c & s_m == s_c);
pyagree = 100 * mean(a_c == ref.action(1:n));
fprintf('[codegen] generated-C vs MATLAB over %d hours: %.3f %% identical (action + interlock state)\n', n, agree);
fprintf('[codegen] generated-C action vs Python reference action: %.3f %% identical\n', pyagree);
r.regime = regime; r.hours = n; r.c_files = numel(files); r.c_lines = nlines;
r.pct_identical_vs_matlab = agree; r.pct_identical_vs_python = pyagree;
fid = fopen(fullfile(expDir, 'codegen_verification.json'), 'w'); fwrite(fid, jsonencode(r, 'PrettyPrint', true)); fclose(fid);
disp('CODEGEN_DONE_MARKER');
