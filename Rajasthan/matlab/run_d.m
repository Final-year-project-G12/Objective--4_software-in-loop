function run_d()
%RUN_D  Item D: hold-time tests (hold_test: 12 evenings x thresholds 30/40/45/50 C) and the PCM swap study.
here = fileparts(mfilename('fullpath')); addpath(here);
hold_test;
pcm_swap_study;
end
