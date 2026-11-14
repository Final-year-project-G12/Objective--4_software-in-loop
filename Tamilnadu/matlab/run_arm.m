try
  cd(fileparts(mfilename('fullpath')));
  three_arm_2021('../export', 2021);
  fprintf('ARM_DONE_MARKER\n');
catch err
  fprintf('ERROR: %s\n', err.getReport());
end
exit;
