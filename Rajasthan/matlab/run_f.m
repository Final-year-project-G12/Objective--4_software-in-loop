function run_f()
%RUN_F  Item F: forecast optimism check (perfect against smart-persistence forecast, validated against O3's Python smart run).
here = fileparts(mfilename('fullpath')); addpath(here);
run_forecast_check;
end
