try
  cd(fileparts(mfilename('fullpath')));
  fprintf('=== REGIME 0 ===\n'); validate_v3_full('../export', 2011);
  fprintf('=== REGIME 1 ===\n'); validate_v3_full('../export_r1', 2011);
  fprintf('=== REGIME 2 ===\n'); validate_v3_full('../export_r2', 2011);
  fprintf('ALL_VALIDATION_DONE\n');
catch err
  fprintf('ERROR: %s\n', err.getReport());
end
exit;
