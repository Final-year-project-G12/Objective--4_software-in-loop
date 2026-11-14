try
  cd(fileparts(mfilename('fullpath')));
  one_day_cycle('../export', 2021);
  fprintf('DAY_DONE_MARKER\n');
catch err
  fprintf('ERROR: %s\n', err.getReport());
end
exit;
