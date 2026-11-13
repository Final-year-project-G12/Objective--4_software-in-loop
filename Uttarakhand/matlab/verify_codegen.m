%VERIFY_CODEGEN  Compile the embedded controller (PPO + interlock) to C and check it against MATLAB.
%
% 1. generates standalone C code for controller_step (folder <export>/codegen_c)
% 2. builds a MEX of the same C code and replays the policy's own observations
%    from the Python reference run through it, comparing every action with
%    the MATLAB function and with Python. This shows the generated C makes the
%    same decisions.
%
% It is NOT a run on a real microcontroller: that needs a target board or an
% instruction-set simulator (processor-in-the-loop proper) and is the next
% stage. Needs MATLAB Coder. Set regime = 0/1/2 before running (default 1).
here = fileparts(mfilename('fullpath')); addpath(here);
if ~exist('regime', 'var'), regime = 1; end
expDir = twin_export_dir(regime);
tw = load_twin_params(expDir);

W1 = single(tw.W1); b1 = single(tw.b1); W2 = single(tw.W2); b2 = single(tw.b2);
Wa = single(tw.Wa); ba = single(tw.ba); P = tw.K.P(:);
ex = {zeros(15, 1, 'single'), 0, 0, 1, W1, b1, W2, b2, Wa, ba, P};

outC = fullfile(expDir, 'codegen_c');
cfg = coder.config('lib'); cfg.GenerateReport = false; cfg.TargetLang = 'C';
codegen('-config', cfg, 'controller_step', '-args', ex, '-d', outC, '-c', '-o', 'controller_step_lib');
files = dir(fullfile(outC, '**', '*.c'));
nlines = 0; for i = 1:numel(files), nlines = nlines + numel(readlines(fullfile(files(i).folder, files(i).name))); end
fprintf('[codegen] C code generated: %d .c files, %d lines in %s\n', numel(files), nlines, outC);

mcfg = coder.config('mex'); mcfg.GenerateReport = false;
outM = fullfile(expDir, 'codegen_mex');
codegen('-config', mcfg, 'controller_step', '-args', ex, '-o', 'controller_step_mex', '-d', outM);
addpath(outM);

ref = tw.ref; n = min(height(ref), 8760);
O = zeros(15, n, 'single');
for k = 1:15, O(k, :) = single(ref.(sprintf('obs%d', k - 1))(1:n)'); end
Ttop = ref.raw0(1:n); Tpcm = ref.raw3(1:n);          % measured top-of-tank / estimated PCM temperature
clear safety_interlock controller_step_mex
a_m = zeros(n, 1); a_c = zeros(n, 1); s_m = zeros(n, 1); s_c = zeros(n, 1);
for t = 1:n
    [a_m(t), s_m(t)] = controller_step(O(:, t), Ttop(t), Tpcm(t), 1, W1, b1, W2, b2, Wa, ba, P);
    [a_c(t), s_c(t)] = controller_step_mex(O(:, t), Ttop(t), Tpcm(t), 1, W1, b1, W2, b2, Wa, ba, P);
end
agree = 100 * mean(a_m == a_c & s_m == s_c);
pyagree = 100 * mean(a_c == ref.action(1:n));
fprintf('[codegen] generated-C vs MATLAB over %d hours: %.3f %% identical (action + interlock state)\n', n, agree);
fprintf('[codegen] generated-C action vs Python reference action: %.3f %% identical\n', pyagree);
cg = struct(); cg.regime = regime; cg.year = tw.year; cg.hours = n; cg.c_files = numel(files); cg.c_lines = nlines;
cg.pct_identical_vs_matlab = agree; cg.pct_identical_vs_python = pyagree;
fid = fopen(fullfile(expDir, 'codegen_verification.json'), 'w'); fwrite(fid, jsonencode(cg, 'PrettyPrint', true)); fclose(fid);
disp('CODEGEN_DONE_MARKER');
