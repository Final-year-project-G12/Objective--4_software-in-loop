try
  cd(fileparts(mfilename('fullpath')));
  run_c_scenarios('../export', 2011);
  fprintf('C_DONE_MARKER\n');
catch err
  fprintf('ERROR: %s\n', err.getReport());
end
exit;
