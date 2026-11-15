function J = check_pump_drawing(regime, day)
%CHECK_PUMP_DRAWING  Pump-bug check behind the animation fix (joint plan deliverable 9), plus the one-day video.
%
%   J = check_pump_drawing;   % regime 1; writes ../export_r1/pump_check_2023.json and ../video/o4_three_arm_day<d>_2023.mp4
%
% OLD rule (first Uttarakhand animation and the original Tamil Nadu one): pump drawn on whenever ENABLE is commanded,
% the sun is above the collector cut-in and the water shield did not fire. NEW rule (animate_system.m since its first
% Uttarakhand version, animate_three_arm.m): pump drawn on only when the loop actually circulated (after cut-off,
% a - b T >= 0 re-solve and shield) AND the collector added heat. Counted per arm over 2023: hours the old rule draws the
% pump on without any circulation / collector gain (the bug), and violations of the new rule (must be 0).
if nargin < 1 || isempty(regime), regime = 1; end
here = fileparts(mfilename('fullpath')); addpath(here);
tw = load_twin_params(twin_export_dir(regime), 2023);
C = load_campaign(regime);
W = tw.wx.signals.values;
arms = {'arm1_plain_B0', C.water_only, 1; 'arm2_pcm_B0', C.base.K, 1; 'arm3_pcm_PPO', C.base.K, 0};
J = struct(); Ls = cell(1, 3);
for a = 1:3
    L = simulate_hours(tw, W, arms{a, 2}, arms{a, 3}, 0, []); Ls{a} = L;
    old_on = (L.a_cmd == 1) & (L.n_sw == 0) & (L.GHI > arms{a, 2}.coll(4));
    new_on = (L.pump_frac > 0) & (L.Q_coll_Wh > 0);
    s.hours_old_rule_pump_on = sum(old_on);
    s.hours_old_rule_pump_on_without_circulation_or_gain = sum(old_on & ~new_on);
    s.hours_new_rule_pump_on = sum(new_on);
    s.violations_new_rule = sum(new_on & (L.Q_coll_Wh <= 0 | L.pump_frac <= 0));
    s.hours_loop_ran_part_of_hour = sum(L.pump_frac > 0 & L.pump_frac < 1);
    J.(arms{a, 1}) = s;
    fprintf('[pump check] %-14s old rule: %d h drawn on, %d of them without circulation / gain; new rule: %d h on, %d violations\n', ...
        arms{a, 1}, s.hours_old_rule_pump_on, s.hours_old_rule_pump_on_without_circulation_or_gain, s.hours_new_rule_pump_on, s.violations_new_rule);
end
fid = fopen(fullfile(twin_export_dir(regime), 'pump_check_2023.json'), 'w'); fwrite(fid, jsonencode(J, 'PrettyPrint', true)); fclose(fid);

% one-day three-arm video (same day as one_day_cycle.m by default)
rows17 = find(W(:, 4) == 17);
if nargin < 2 || isempty(day)
    sd = round(linspace(15, 345, 12)); [~, k] = max(Ls{3}.E_stored_kWh(rows17(sd))); day = sd(k);
end
r = (rows17(day) - 17):(rows17(day) + 13);         % 00:00 of the day to 06:00 next morning (31 h: charge and night)
F = fieldnames(Ls{1}); Lc = cell(1, 3);
for a = 1:3
    for i = 1:numel(F)
        v = Ls{a}.(F{i});
        if size(v, 1) == size(W, 1), Lc{a}.(F{i}) = v(r, :); end    % hourly series only (skip the start record)
    end
end
vdir = fullfile(here, '..', 'video'); if ~isfolder(vdir), mkdir(vdir); end
file = fullfile(vdir, sprintf('o4_three_arm_day%03d_2023.mp4', day));
animate_three_arm(Lc, file, sprintf('Uttarakhand regime %d, day %d of 2023: plain tank vs PCM + B0 vs PCM + PPO', regime, day), 3);
fprintf('[video] %s (%d h)\n', file, numel(r));
J.video = file; J.video_day = day;
end
