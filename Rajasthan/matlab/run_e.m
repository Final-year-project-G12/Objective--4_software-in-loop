function run_e()
%RUN_E  Item E: Objective 3 cross-check (twin against O3 tables, 5 deterministic faults) and the O3 sensor-fault table.
here = fileparts(mfilename('fullpath')); addpath(here);
compare_with_o3;
run_o3_sensor_faults;
end
