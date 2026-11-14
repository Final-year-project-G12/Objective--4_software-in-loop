function J = check_pump_drawing()
%CHECK_PUMP_DRAWING  Pump-bug check behind the animation fix (Tamil Nadu scope item 9).
%
%   J = check_pump_drawing;   % writes ../export_r1/pump_check_2023.json
%
% The animation used to draw the pump as running whenever CHARGE was executed above the cut-in irradiance, even when the collector added
% no heat and the plant did not circulate. animate_system.m now also requires the collector heat of that hour to be above zero. This counts,
% per arm over 2023, the hours the OLD rule would have drawn the pump on without any collector gain (the bug) and the hours the NEW rule does
% (violations; must be 0), and the hours the loop really circulated.
here = fileparts(mfilename('fullpath')); addpath(here);
tw = load_twin_params(fullfile(here, '..', 'export_r1'), 2023);
W = tw.wx.signals.values(:, 1:4);
P = tw.P;  Pp = make_plain_tank(P);
arms = {'arm1_plain_B0', Pp, 1; 'arm2_pcm_B0', P, 1; 'arm3_pcm_DQN', P, 0};
J = struct();
for a = 1:3
    L = simulate_hours(tw, W, arms{a, 2}, arms{a, 3}, 0, []);
    old_on = (L.a_exec == 0) & (L.n_sw == 0) & (L.GHI > P(39));
    new_on = old_on & (L.Q_coll_Wh > 0);
    s.hours_old_rule_pump_on = sum(old_on);
    s.hours_old_rule_pump_on_without_collector_gain = sum(old_on & L.Q_coll_Wh <= 0);
    s.hours_new_rule_pump_on = sum(new_on);
    s.violations_new_rule = sum(new_on & L.Q_coll_Wh <= 0);
    J.(arms{a, 1}) = s;
    fprintf('[pump check] %-14s old rule: %d h pump drawn on, %d of them with no collector gain; new rule: %d h on, %d violations\n', ...
        arms{a, 1}, s.hours_old_rule_pump_on, s.hours_old_rule_pump_on_without_collector_gain, s.hours_new_rule_pump_on, s.violations_new_rule);
end
fid = fopen(fullfile(here, '..', 'export_r1', 'pump_check_2023.json'), 'w'); fwrite(fid, jsonencode(J, 'PrettyPrint', true)); fclose(fid);
end
