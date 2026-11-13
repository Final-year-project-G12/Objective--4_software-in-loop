function R = three_arm_day(regime, startDay, nDays, exportRoot)
%THREE_ARM_DAY  Deliverable (i): the three arms over one full charge / idle /
% bypass cycle, with every parameter that matters, on the same weather.
%
%   ARM 1  plain water tank, same volume, always-enable pump (B0)
%   ARM 2  PCM tank from O1 (material) + O2 (geometry, flow), always-enable (B0)
%          -> this is exactly the Objective 2 operating point: PCM, no AI
%   ARM 3  the same PCM tank driven by the trained Objective 3 policy
%
% Why a day and not an hour: the controller takes ONE decision per hour, so a
% 1-hour window is a single point and shows no cycle. A full charge -> idle /
% bypass -> discharge cycle takes a day. The plant still solves 150 s
% sub-steps internally; this script logs the hourly state, which is the level
% the controller acts at. (To see inside the hour you would have to make
% pcm_plant_hour return its sub-step trace, which it does not do today.)
%
% Usage, from the state's matlab/ folder (Uttarakhand or Rajasthan):
%   addpath('../../Common');
%   R = three_arm_day(1, 110, 3);          % regime 1, from day 110, 3 days
%
% startDay  day-of-year to start (1-365). Pick a clear spell; April is ~day 100.
% nDays     how many days to plot (2-4 is readable; 3 is a good default).
%
% Returns R with one struct per arm and prints the comparison table.

if nargin < 1 || isempty(regime),     regime = 1;   end
if nargin < 2 || isempty(startDay),   startDay = 110; end
if nargin < 3 || isempty(nDays),      nDays = 3;    end
if nargin < 4 || isempty(exportRoot), exportRoot = ''; end

% ---- locate the export folder for this regime -------------------------
if isempty(exportRoot)
    if exist('twin_export_dir', 'file') == 2
        expDir = twin_export_dir(regime);                 % Uttarakhand helper
    else
        expDir = fullfile(pwd, '..', sprintf('export_r%d', regime));
    end
else
    expDir = exportRoot;
end
fprintf('[three_arm_day] export folder: %s\n', expDir);

tw = load_twin_params(expDir, []);
W  = tw.wx.signals.values;                 % [hour_idx GHI T_amb local_hour]

i0 = (startDay - 1) * 24 + 1;
i1 = min(i0 + nDays * 24 - 1, size(W, 1));
Wd = W(i0:i1, :);
n  = size(Wd, 1);
fprintf('[three_arm_day] regime %d, hours %d..%d (%d h, %.1f days)\n', regime, i0, i1, n, n/24);

% ---- the three arms ---------------------------------------------------
K_pcm   = tw.K;
K_plain = make_plain(tw.K);

arms = { ...
  struct('name','ARM1 plain + B0',  'K',K_plain, 'mode',1), ...
  struct('name','ARM2 PCM + B0',    'K',K_pcm,   'mode',1), ...
  struct('name','ARM3 PCM + O3 AI', 'K',K_pcm,   'mode',0)  };

% All three arms start from the same reset state (water 30 C, PCM solid). The
% plain arm still carries an enthalpy vector of the right size; it is unused
% because n_caps = 0.
R = struct();
for a = 1:3
    L = simulate_hours(tw, Wd, arms{a}.K, arms{a}.mode, 0, []);
    L.label = arms{a}.name;
    R.(sprintf('arm%d', a)) = L;
end

% ---- comparison table -------------------------------------------------
tgt = tw.K.P(4);
fprintf('\n%-18s %9s %9s %9s %9s %8s %8s %8s %8s\n', 'arm', ...
        'Edel_kWh', 'unmet_kWh', 'Estor_end', 'Tmax_top', 'shld_h', 'over_h', 'pump_h', 'cycles');
for a = 1:3
    L = R.(sprintf('arm%d', a));
    shld = sum(L.shield_w_s + L.shield_p_s) / 3600;
    over = sum(L.over_limit_s) / 3600;
    fprintf('%-18s %9.2f %9.2f %9.3f %9.2f %8.2f %8.2f %8.1f %8s\n', ...
        L.label, sum(L.E_del_Wh)/1000, sum(L.E_unmet_Wh)/1000, L.E_stored_kWh(end), ...
        max(L.T_top), shld, over, sum(L.pump_frac), ...
        ternary(any(L.f_melt > 0), sprintf('%.2f', sum(abs(diff(L.f_melt)))/2), 'no PCM'));
end
fprintf('\nDelivery target %.0f C. "shld_h" = guard-band hours, "over_h" = hours over a hard limit (must be 0).\n', tgt);

% ---- the figure -------------------------------------------------------
t = (0:n-1) / 24;                                  % days since start
co = [0.45 0.45 0.45; 0.85 0.33 0.10; 0.00 0.45 0.74];   % grey, orange, blue
fig = figure('Position', [60 40 1250 980], 'Color', 'w');
try, theme(fig, 'light'); catch, end
tl = tiledlayout(6, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('Three arms on the same weather  |  regime %d, day %d, %d days', ...
      regime, startDay, nDays), 'FontWeight', 'bold');

% 1 weather
nexttile; yyaxis left
area(t, R.arm1.GHI, 'FaceColor', [1 0.85 0.4], 'EdgeColor', 'none'); ylabel('GHI W/m^2');
yyaxis right; plot(t, R.arm1.T_amb, 'k-', 'LineWidth', 1.1); ylabel('T_{amb} \circC');
title('Weather driving all three arms (identical)'); grid on; xlim([0 t(end)]);

% 2 delivery-node water temperature
nexttile; hold on
for a = 1:3
    L = R.(sprintf('arm%d', a));
    plot(t, L.T_top, '-', 'Color', co(a,:), 'LineWidth', 1.5, 'DisplayName', L.label);
end
yline(tgt, 'k--', sprintf('%.0f C target', tgt), 'LabelHorizontalAlignment', 'left');
yline(tw.K.P(30), '--', 'guard 72 C', 'Color', [0.8 0.4 0], 'LabelHorizontalAlignment', 'left');
yline(tw.K.P(32), 'r--', 'hard 75 C', 'LabelHorizontalAlignment', 'left');
ylabel('T_{top} \circC'); title('Delivery-node water temperature'); legend('Location','southeast'); grid on; xlim([0 t(end)]);

% 3 PCM temperature and melt fraction
nexttile; yyaxis left; hold on
for a = 2:3
    L = R.(sprintf('arm%d', a));
    plot(t, L.Tpcm, '-', 'Color', co(a,:), 'LineWidth', 1.4);
end
yline(tw.K.P(9), ':', 'solidus'); yline(tw.K.P(10), ':', 'liquidus');
ylabel('T_{PCM} \circC');
yyaxis right; hold on
for a = 2:3
    L = R.(sprintf('arm%d', a));
    plot(t, L.f_melt, '--', 'Color', co(a,:), 'LineWidth', 1.2);
end
ylabel('melt fraction'); ylim([-0.02 1.02]);
title('PCM temperature (solid) and melt fraction (dashed) - arms 2 and 3 only'); grid on; xlim([0 t(end)]);

% 4 action and interlock
nexttile; hold on
stairs(t, R.arm2.a_cmd + 0.02, '-', 'Color', co(2,:), 'LineWidth', 1.4, 'DisplayName', 'ARM2 commanded');
stairs(t, R.arm3.a_policy - 0.02, ':', 'Color', co(3,:), 'LineWidth', 1.6, 'DisplayName', 'ARM3 policy asked');
stairs(t, R.arm3.a_cmd, '-', 'Color', co(3,:), 'LineWidth', 1.4, 'DisplayName', 'ARM3 after interlock');
ylim([-0.3 max(2.3, max(R.arm3.a_cmd)+0.3)]);
ylabel('action'); title('Charge / idle / bypass decisions (0 and 1 meaning is per state - see the README)');
legend('Location','east'); grid on; xlim([0 t(end)]);

% 5 stored and recoverable energy
nexttile; hold on
for a = 1:3
    L = R.(sprintf('arm%d', a));
    plot(t, L.E_stored_kWh, '-', 'Color', co(a,:), 'LineWidth', 1.5, 'DisplayName', L.label);
end
ylabel('E_{stored} kWh'); title('Energy in the store above mains temperature'); legend('Location','northwest'); grid on; xlim([0 t(end)]);

% 6 draw and cumulative delivered
nexttile; yyaxis left
bar(t, R.arm1.draw_kg, 'FaceColor', [0.7 0.8 0.9], 'EdgeColor', 'none'); ylabel('draw kg/h');
yyaxis right; hold on
for a = 1:3
    L = R.(sprintf('arm%d', a));
    plot(t, cumsum(L.E_del_Wh)/1000, '-', 'Color', co(a,:), 'LineWidth', 1.5);
end
ylabel('cumulative kWh'); xlabel('days since start');
title('Hot-water draw (bars) and cumulative delivered energy (lines)'); grid on; xlim([0 t(end)]);

outDir = fullfile(expDir, 'scenarios'); if ~isfolder(outDir), mkdir(outDir); end
png = fullfile(outDir, sprintf('three_arm_day_r%d_d%d.png', regime, startDay));
exportgraphics(fig, png, 'Resolution', 150);
fprintf('[three_arm_day] figure -> %s\n', png);
end

function out = ternary(c, a, b)
if c, out = a; else, out = b; end
end
