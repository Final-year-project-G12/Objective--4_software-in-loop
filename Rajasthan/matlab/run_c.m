function run_c()
%RUN_C  Item C: pyranometer / sensor / pump / blackout scenarios, 3-arm (run_c_scenarios) and 4-arm with the SAC (regimes 0, 1, 2).
here = fileparts(mfilename('fullpath')); addpath(here);
run_c_scenarios;
for r = 0:2, run_c_scenarios_sac(r); end
run_dead_pyranometer;
end
