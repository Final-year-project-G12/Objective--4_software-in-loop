function R = animate_hold_video(regime, ctrl, file)
%ANIMATE_HOLD_VIDEO  70-hour "how long is the heat retained" video, three tanks side by side, Tamil Nadu panel style.
%
%   R = animate_hold_video(1, 'DQN', '../video/o4_hold70h_r1_DQN_2023.mp4')
%   R = animate_hold_video(1, 'SAC', ...);  regime 0 and 2 are SAC only (their DQN is always-charge = B0)
%
% Three arms on the same weather: (1) plain tank + B0, (2) PCM tank + B0 (no AI), (3) PCM tank + DQN or SAC.
% Clip = 8 h of the real controlled afternoon (10:00-18:00, each arm from its own state in the full-year 2023 run), then 62 h with the
% sun off and no hot-water draw (the hold test of run_hold_test.m / Objective 2's tau_hold: 18:00 until the TOP layer falls below the
% threshold), 70 h in all. Each tank is drawn as its 10 real layers (colour = node temperature) with capsules coloured by node melt
% fraction; under it the running count "hours above 45 C since 18:00" stops when the top layer drops below 45 C.
% Which evening: of the 12 hold-test evenings (the same ones as the tau_hold table), the one whose controller-arm hold time is closest to the
% 12-evening mean among those that fall inside the 62 h window, so the video shows a representative hold, not the best or worst one.
% Assumptions: the hold is the model's (sun off, no draw, real ambient, shield and sub-steps as in the kernel); the clip is a 3-D-free
% schematic of a 1-D, 10-node result; the 45 C threshold is read at the top layer. Nothing here changes any stored result.
here = fileparts(mfilename('fullpath')); addpath(here);
mode = 0;  if strcmp(ctrl, 'SAC'), mode = 2; end
tw = load_twin_params(fullfile(here, '..', sprintf('export_r%d', regime)), 2023);
W = tw.wx.signals.values(:, 1:4);  P = tw.P;  Pp = make_plain_tank(P);
Ps = {Pp, P, P};  modes = {1, 1, mode};
armName = {'Arm 1: Plain tank (B0)', 'Arm 2: PCM tank (B0, no AI)', ['Arm 3: PCM tank (' ctrl ')']};
L = cell(1, 3);
for a = 1:3, L{a} = simulate_hours(tw, W, Ps{a}, modes{a}, 0, []); end
rows17 = find(W(:, 4) == 17);  sd = round(linspace(15, 345, 12));
NDAY = 8;  H = 62;  th = 45;
% ---- pick the evening ----
tau3 = zeros(12, 1);
for s = 1:12
    t = rows17(sd(s));
    Rh = run_hold_test(P, W, L{3}.Tn(t, :)', L{3}.hn(t, :)', t + 1, 72, th);
    tau3(s) = Rh.tau;
end
ok = find(tau3 <= H - 1);
[~, j] = min(abs(tau3(ok) - mean(tau3)));  pick = ok(j);  day = sd(pick);  t17 = rows17(day);
% ---- states: row 1 = 10:00, rows 1..NDAY+1 = the afternoon, then H hold hours ----
n = NDAY + H + 1;
Tn = zeros(n, 10, 3);  hn = zeros(n, 10, 3);  Q = zeros(n, 3);  act = zeros(n, 3);  ghi = zeros(n, 1);
for a = 1:3
    r0 = t17 - NDAY;
    Tn(1:NDAY + 1, :, a) = L{a}.Tn(r0:t17, :);  hn(1:NDAY + 1, :, a) = L{a}.hn(r0:t17, :);
    Q(2:NDAY + 1, a) = L{a}.Q_coll_Wh(r0 + 1:t17);  act(2:NDAY + 1, a) = L{a}.a_exec(r0 + 1:t17);
    T = Tn(NDAY + 1, :, a)';  h = hn(NDAY + 1, :, a)';
    for k = 1:H
        [T, h] = pcm_plant_hour(0, W(t17 + k, 3), 0, 2, T, h, Ps{a});
        Tn(NDAY + 1 + k, :, a) = T';  hn(NDAY + 1 + k, :, a) = h';
        act(NDAY + 1 + k, a) = 3;                                   % 3 = sun off (hold)
    end
end
ghi(2:NDAY + 1) = L{1}.GHI(t17 - NDAY + 1:t17);
Ttop = zeros(n, 3);  Tpcm = zeros(n, 3);  fm = zeros(n, 3);
for a = 1:3
    for k = 1:n
        s = pcm_derive_state(Tn(k, :, a)', hn(k, :, a)', Ps{a});
        Ttop(k, a) = s(1);  Tpcm(k, a) = s(4);  fm(k, a) = s(5);
    end
end
% ---- hold time per arm (linear inside the hour), and the check against run_hold_test ----
tau = zeros(1, 3);  cens = false(1, 3);
for a = 1:3
    v = Ttop(NDAY + 1:end, a);  tau(a) = H;  cens(a) = true;
    for k = 2:numel(v)
        if v(k) < th, tau(a) = (k - 2) + (v(k - 1) - th) / (v(k - 1) - v(k)); cens(a) = false; break; end
    end
    Rh = run_hold_test(Ps{a}, W, L{a}.Tn(t17, :)', L{a}.hn(t17, :)', t17 + 1, H, th);
    assert(abs(Rh.tau - tau(a)) < 1e-9, 'animate_hold_video: hold time differs from run_hold_test');
end
R = struct('regime', regime, 'controller', ctrl, 'day', day, 'tau_h', tau, 'censored', cens, 'evening_tau_ctrl_all', tau3', 'mean_tau_ctrl', mean(tau3));

% ---- figure ----
bgc = [1 0.95 0.7; 0.9 0.9 0.9; 1 0.8 0.8; 0.88 0.93 1];        % CHARGE, IDLE, BYPASS, sun off
fig = figure('Visible', 'off', 'Position', [30 30 1440 810], 'Color', 'w');
try, theme(fig, 'light'); catch, end
xt = 0:n - 1;  X0 = NDAY;                                        % x = hours since 10:00, 18:00 at x = 8
hTit = annotation(fig, 'textbox', [0 0.945 1 0.05], 'String', '', 'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 15, 'FontWeight', 'bold');
hClk = annotation(fig, 'textbox', [0 0.905 1 0.04], 'String', '', 'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 12);
cw = 0.285;  cx = [0.045 0.36 0.675];
axT = gobjects(3, 1);  axM = gobjects(3, 1);  axQ = gobjects(3, 1);  axK = gobjects(3, 1);
hLay = cell(3, 1);  hCap = cell(3, 1);  hCnt = gobjects(3, 1);  hLT = gobjects(3, 2);  hLM = gobjects(3, 1);  hCurs = gobjects(3, 3);  hQ = gobjects(3, 1);
ncap = round(P(61:70));  Ts = P(9);  Tl = P(10);  Lh_ = P(11);  cps = P(12);  xx = P(14);
hs = (cps + xx) * Ts;  span = Lh_ + xx * (Tl - Ts);
for a = 1:3
    axK(a) = axes(fig, 'Position', [cx(a) 0.55 cw 0.34]); hold(axK(a), 'on'); axis(axK(a), 'off'); xlim(axK(a), [-0.3 1.3]); ylim(axK(a), [-1.2 10.8]);
    hLay{a} = gobjects(10, 1);  hCap{a} = gobjects(10, 3);
    for i = 1:10
        hLay{a}(i) = patch(axK(a), [0 1 1 0], [i - 1 i - 1 i i], [0.4 0.6 0.9], 'EdgeColor', [0.5 0.5 0.5]);
        if a > 1 && ncap(i) > 0
            for q = 1:3
                tq = linspace(0, 2 * pi, 20);
                hCap{a}(i, q) = patch(axK(a), 0.2 + 0.3 * (q - 1) + 0.075 * cos(tq), i - 0.5 + 0.28 * sin(tq), [0.3 0.5 0.9], 'EdgeColor', [0.2 0.2 0.2]);
            end
        end
    end
    plot(axK(a), [0 1 1 0 0], [0 0 10 10 0], 'k-', 'LineWidth', 2);
    if a == 1, text(axK(a), 0.5, 5, 'no PCM', 'HorizontalAlignment', 'center', 'FontSize', 12, 'FontWeight', 'bold', 'Color', [0.2 0.2 0.2]); end
    text(axK(a), 0.5, 10.55, armName{a}, 'HorizontalAlignment', 'center', 'FontSize', 13, 'FontWeight', 'bold');
    hCnt(a) = text(axK(a), 0.5, -0.65, '', 'HorizontalAlignment', 'center', 'FontSize', 13, 'FontWeight', 'bold');
    text(axK(a), 1.08, 9.5, 'top', 'FontSize', 8, 'Color', [0.4 0.4 0.4]);  text(axK(a), 1.08, 0.5, 'bottom', 'FontSize', 8, 'Color', [0.4 0.4 0.4]);
    % temperature
    axT(a) = axes(fig, 'Position', [cx(a) 0.335 cw 0.17]); hold(axT(a), 'on'); box(axT(a), 'on'); xlim(axT(a), [0 n - 1]); ylim(axT(a), [25 80]);
    shadeBg(axT(a), act(:, a), bgc, [25 80]);
    hLT(a, 1) = plot(axT(a), xt(1), Ttop(1, a), 'b-', 'LineWidth', 1.8);
    hLT(a, 2) = plot(axT(a), xt(1), Tpcm(1, a), '-', 'Color', [0.93 0.45 0.05], 'LineWidth', 1.8);
    yline(axT(a), th, 'g-', '45 \circC', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left'); yline(axT(a), 72, 'r--');
    xline(axT(a), X0, 'k:', '18:00', 'LabelVerticalAlignment', 'bottom');
    hCurs(a, 1) = xline(axT(a), 0, 'k-', 'LineWidth', 1.4);
    ylabel(axT(a), 'T [\circC]'); grid(axT(a), 'on'); set(axT(a), 'XTickLabel', []);
    if a == 2, legend(axT(a), [hLT(a, 1) hLT(a, 2)], {'T_{top water}', 'T_{PCM}'}, 'Location', 'northeast', 'Orientation', 'horizontal', 'FontSize', 8); end
    % melt
    axM(a) = axes(fig, 'Position', [cx(a) 0.205 cw 0.10]); hold(axM(a), 'on'); box(axM(a), 'on'); xlim(axM(a), [0 n - 1]); ylim(axM(a), [-5 105]);
    shadeBg(axM(a), act(:, a), bgc, [-5 105]);
    if a == 1, text(axM(a), n / 2, 50, 'no PCM', 'HorizontalAlignment', 'center', 'FontSize', 12, 'Color', [0.4 0.4 0.4]); end
    hLM(a) = plot(axM(a), xt(1), 100 * fm(1, a), '-', 'Color', [1 0 1], 'LineWidth', 1.8);
    xline(axM(a), X0, 'k:'); hCurs(a, 2) = xline(axM(a), 0, 'k-', 'LineWidth', 1.4);
    ylabel(axM(a), 'melt %'); grid(axM(a), 'on'); set(axM(a), 'XTickLabel', []);
    % collector heat
    axQ(a) = axes(fig, 'Position', [cx(a) 0.06 cw 0.10]); hold(axQ(a), 'on'); box(axQ(a), 'on'); xlim(axQ(a), [0 n - 1]); ylim(axQ(a), [0 1800]);
    shadeBg(axQ(a), act(:, a), bgc, [0 1800]);
    bar(axQ(a), xt, Q(:, a), 0.8, 'FaceColor', [1 0.6 0.1], 'EdgeColor', 'none');
    xline(axQ(a), X0, 'k:'); hCurs(a, 3) = xline(axQ(a), 0, 'k-', 'LineWidth', 1.4);
    ylabel(axQ(a), 'Q_{coll} [Wh]'); xlabel(axQ(a), 'hours since 10:00 (18:00 = hour 8; sun off, no draw after it)'); grid(axQ(a), 'on');
end
annotation(fig, 'textbox', [0 0.0 1 0.035], 'String', sprintf(['Background: yellow = CHARGE, grey = IDLE, pink = BYPASS (controller commands), blue = sun off. Hold = hours from 18:00 until the top layer is below 45 %cC. ' ...
    'Model values; evening %d of 2023, closest to the 12-evening mean.'], char(176), day), 'EdgeColor', 'none', 'HorizontalAlignment', 'center', 'FontSize', 9, 'Color', [0.3 0.3 0.3]);

vw = VideoWriter(file, 'MPEG-4'); vw.FrameRate = 12; open(vw);
cleanup = onCleanup(@() close(vw));
fph = 3;
for k = 1:n
    hh = mod(10 + (k - 1), 24);  dd = floor((10 + (k - 1)) / 24);
    set(hTit, 'String', sprintf('Rajasthan, regime %d (%s): where does the heat go after 18:00? Same weather, three tanks', regime, ctrl));
    set(hClk, 'String', sprintf('day %d of 2023 + %d d   %02d:00   (clip hour %d of %d)', day, dd, hh, k - 1, n - 1));
    for a = 1:3
        for i = 1:10
            set(hLay{a}(i), 'FaceColor', tcol(Tn(k, i, a)));
            if a > 1 && ncap(i) > 0
                f = min(max((hn(k, i, a) - hs) / span, 0), 1);
                for q = 1:3, set(hCap{a}(i, q), 'FaceColor', (1 - f) * [0.25 0.45 0.9] + f * [1 0.55 0.05]); end
            end
        end
        set(hLT(a, 1), 'XData', xt(1:k), 'YData', Ttop(1:k, a));  set(hLT(a, 2), 'XData', xt(1:k), 'YData', Tpcm(1:k, a));
        if a > 1, set(hLM(a), 'XData', xt(1:k), 'YData', 100 * fm(1:k, a)); end
        for c = 1:3, set(hCurs(a, c), 'Value', k - 1); end
        el = (k - 1) - X0;                                         % hours since 18:00
        if el < 0
            set(hCnt(a), 'String', sprintf('top %.1f \\circC  (sun still on)', Ttop(k, a)), 'Color', [0.3 0.3 0.3]);
        elseif ~cens(a) && el >= tau(a)
            set(hCnt(a), 'String', sprintf('below 45 \\circC after %.1f h', tau(a)), 'Color', [0.8 0.1 0.1]);
        else
            set(hCnt(a), 'String', sprintf('above 45 \\circC for %d h  (top %.1f \\circC)', el, Ttop(k, a)), 'Color', [0.05 0.5 0.15]);
        end
    end
    for s = 1:fph, drawnow limitrate; writeVideo(vw, getframe(fig)); end
end
% hold the last frame for 2 s
for s = 1:24, writeVideo(vw, getframe(fig)); end
close(vw); clear cleanup; close(fig);
fprintf('[hold video] regime %d %s day %d: hold 45 C  plain %.1f h  PCM+B0 %.1f h  PCM+%s %.1f h (12-evening mean %.1f h) -> %s\n', ...
    regime, ctrl, day, tau(1), tau(2), ctrl, tau(3), mean(tau3), file);
end

function shadeBg(ax, act, bgc, yl)
n = numel(act);
for k = 2:n
    c = act(k) + 1;
    if act(k) == 3, c = 4; end
    patch(ax, [k - 2 k - 1 k - 1 k - 2], [yl(1) yl(1) yl(2) yl(2)], bgc(c, :), 'EdgeColor', 'none', 'HandleVisibility', 'off');
end
end

function c = tcol(T)
t = min(max((T - 25) / 50, 0), 1);
c = [t, 0.35 * (1 - abs(2 * t - 1)) + 0.1, 1 - t];
c = min(max(c, 0), 1);
end
