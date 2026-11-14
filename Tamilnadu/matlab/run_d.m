try
  cd(fileparts(mfilename('fullpath')));
  fprintf('############ ITEM 1: RESTART CHECK ############\n');
  r1 = check_restart('../export', 2021, 100);
  if ~r1.good.pass
    fprintf('RESTART CHECK FAILED -- STOPPING, not running items 2/3.\n');
    fprintf('D_STOPPED_MARKER\n');
    exit;
  end
  fprintf('\n############ ITEM 2: ENERGY BALANCE ############\n');
  r2 = check_energy_balance('../export', 2021);
  fprintf('\n############ ITEM 3: HOLD TEST ############\n');
  [T3, TH3] = run_hold_test('../export', 2021, [], 72, [30 40 45 50]);
  fprintf('D_DONE_MARKER\n');
catch err
  fprintf('ERROR: %s\n', err.getReport());
end
exit;
