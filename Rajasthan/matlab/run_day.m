function run_day(day)
%RUN_DAY  Item D1: one full charge / idle / bypass cycle for the three arms -> export_r1/one_day_cycle_2023.* (default: the best of the 12 hold-test evenings; or pass a day 1-365).
here = fileparts(mfilename('fullpath')); addpath(here);
if nargin < 1, one_day_cycle; else, one_day_cycle(day); end
end
