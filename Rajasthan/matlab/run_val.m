function run_val()
%RUN_VAL  Item A: validate the MATLAB twin against Objective 3's Python run for regimes 0, 1, 2 (DQN full year) and the SAC arm.
% Expected delivered energy: 954.983 / 897.262 / 970.320 kWh (DQN/B0 tables). About 1 min per regime.
here = fileparts(mfilename('fullpath')); addpath(here);
for r = 0:2
    validate_against_python(r, 2023, [], false);
    validate_sac_against_python(r, 2023);
end
end
