function run_o4_showcase(which, fpH)
%RUN_O4_SHOWCASE  Tamil Nadu Objective-4 showcase: one-day schematic videos + simple plots.
%
%   run_o4_showcase            % everything
%   run_o4_showcase('day')     % normal sunny day only
%   run_o4_showcase('heat_wave'), run_o4_showcase('rain_cloud'), run_o4_showcase('sensor_fault')
%   run_o4_showcase('plots')   % figures + tables only (no videos)
%
% One day = 24 h starting 00:00 local, day 71 of 2021 (a validation year).
% Three systems on identical weather and hot-water demand:
%   Arm 1  plain water tank (same 100 L), always-charge controller
%   Arm 2  PCM tank (O1 + O2), always-charge controller, NO AI
%   Arm 3  PCM tank (O1 + O2), trained SAC controller (O3), the system shown in the schematic
% Nothing in the physics, controller or safety layer is changed (O4 = the
% software-in-the-loop twin: sensor model, interlock, shield).
%
% Hour phases (per arm, per hour), the classification used everywhere here:
%   CHARGE     collector loop pumping heat into the tank (collector gain > 0)
%   DISCHARGE  not charging, and hot water is being drawn (PCM / tank release heat)
%   IDLE       not charging, no draw (heat is held)
% BYPASS (collector isolated by the controller or the safety shield) is counted
% separately and is not a fourth phase of the day.
here = fileparts(mfilename('fullpath')); addpath(here);
if nargin < 1, which = 'all'; end
if nargin < 2, fpH = 20; end            % video frames per simulated hour (20 = 1 s per hour at 20 fps)
exportDir = fullfile(here, '..', 'export');
vidDir = fullfile(here, '..', 'video', 'showcase');  if ~isfolder(vidDir), mkdir(vidDir); end
figDir = fullfile(here, '..', 'export', 'showcase'); if ~isfolder(figDir), mkdir(figDir); end
year = 2021; dayNo = 71;

tw = load_twin_params(exportDir, year);
W = tw.wx.signals.values;
P_pcm = tw.P; P_plain = tw.P;
P_plain(1) = tw.P(1) / (1 - plain_fraction(here));   % full 100 L of water
P_plain(23) = 0;                                      % no capsules
armP = {P_plain, P_pcm, P_pcm}; armMode = [1 1 0];

fprintf('[showcase] full-year runs (3 arms)...\n');
Lyr = cell(3,1);
for a = 1:3, Lyr{a} = simulate_hours(tw, W, armP{a}, armMode(a), 0, []); end

% first row of the day = local hour 0 on/after nominal start of day 'dayNo'
i0 = (dayNo-1)*24 + find(W((dayNo-1)*24 + (1:24), 4) == 0, 1) - 1;   % index of local 00:00 row
if isempty(i0), error('local hour 0 not found'); end
assert(W(i0+1, 4) == 0);

scn = struct('name', {'day', 'heat_wave', 'rain_cloud', 'sensor_fault'}, ...
    'title', {'Normal sunny day', 'Edge case 1: heat wave (ambient +9 C, sun +15 %)', ...
              'Edge case 2: rain / heavy cloud (sun x0.12, ambient -5 C)', ...
              'Bonus edge case: noisy sensors + 12 h sensor blackout (05:00-16:59)'});
doVideo = ~strcmp(which, 'plots');
R = struct();
for s = 1:numel(scn)
    nm = scn(s).name;
    if ~(any(strcmp(which, {'all', 'plots'})) || strcmp(which, nm)), continue; end
    D = run_day(tw, W, armP, armMode, Lyr, i0, nm);
    R.(nm) = D;
    fprintf('[showcase] %-13s ', nm); print_day(D);
    plot_day(D, scn(s).title, fullfile(figDir, sprintf('o4_day_%s.png', nm)), dayNo, year);
    if doVideo
        render_video(D, tw, scn(s).title, fullfile(vidDir, sprintf('o4_schematic_%s_day%03d_%d.mp4', nm, dayNo, year)), dayNo, year, fpH);
    end
end
if isfield(R, 'day') || strcmp(which, 'all') || strcmp(which, 'plots')
    write_tables(R, figDir);
    plot_overall(Lyr, exportDir, figDir, R);
end
fprintf('[showcase] done. videos -> %s | figures/tables -> %s\n', vidDir, figDir);
end

% ======================================================================
function fr = plain_fraction(here)
f = fullfile(here, '..', '..', '..', 'Objective---2', 'objective2-tamilnadu', 'results', 'g10_selection_r0.json');
fr = 0.29587085509033423;                       % O2 PCM volume fraction (fallback = value in g10_selection_r0.json)
if isfile(f), g = jsondecode(fileread(f)); fr = g.chosen.fraction; end
end

% ======================================================================
function D = run_day(tw, W, armP, armMode, Lyr, i0, name)
% Re-simulate ONE day for each arm from the full-year state at its start, with the
% scenario edit applied to that day only (3 extra hours kept for the forecast).
rows = i0 + (1:27);
Wd = W(rows, :); idx = 1:24;
noise = 0; blackout = false(27,1);
switch name
    case 'heat_wave',  Wd(idx,3) = Wd(idx,3) + 9;  Wd(idx,2) = 1.15 * Wd(idx,2);
    case 'rain_cloud', Wd(idx,2) = min(0.12 * Wd(idx,2), 120); Wd(idx,3) = Wd(idx,3) - 5;
    case 'sensor_fault', noise = 1; blackout(6:17) = true;      % hours 05:00-16:59
end
D.name = name; D.hod = Wd(idx,4); D.arm = cell(3,1);
for a = 1:3
    L0 = Lyr{a}; k = i0;
    init = struct('Tw0', L0.Tw(k), 'Tpcm0', L0.Tpcm(k), 'h0', L0.h_pcm(k), 'f0', L0.f_melt(k), ...
        'prev0', L0.prev_action(k), 'last_kc0', L0.last_kc(k), 'fault_latched0', L0.fault_latched(k) > 0.5);
    rng(7);
    L = simulate_hours(tw, Wd, armP{a}, armMode(a), noise, blackout, '', init);
    S = struct();
    for fn = {'Tw','Tpcm','f_melt','E_del_Wh','E_unmet_Wh','Q_coll_Wh','Q_loss_Wh','n_sw','n_sp','n_viol','a_policy','a_exec','interlock','draw_kg','GHI','T_amb','sensors_ok'}
        S.(fn{1}) = L.(fn{1})(idx);
    end
    S.init = init; S.P = armP{a};
    charge = S.Q_coll_Wh > 0;
    S.phase = 3 * ones(24,1);                       % 3 = IDLE
    S.phase(S.draw_kg >= 1) = 2;                    % 2 = DISCHARGE
    S.phase(charge) = 1;                            % 1 = CHARGE
    S.shield = (S.n_sw + S.n_sp) > 0;
    S.bypass = (S.a_exec == 2) | (S.interlock >= 2);
    S.Estored = stored_energy(S.Tw, S.Tpcm, S.f_melt, tw.params, armP{a});
    S.Estored0 = stored_energy(init.Tw0, init.Tpcm0, init.f0, tw.params, armP{a});
    D.arm{a} = S;
end
% internal consistency: normal day must equal the full-year run exactly
if strcmp(name, 'day')
    for a = 1:3
        d = max(abs(D.arm{a}.Tw - Lyr{a}.Tw(i0 + (1:24))));
        assert(d < 1e-9, 'one-day re-run differs from the full-year run (arm %d, %.3g)', a, d);
    end
end
end

function e = stored_energy(Tw, Tp, f, p, P)
% heat stored above mains water [kWh] (sensible + latent), same bookkeeping as run_c_scenarios.m
Tm = p.T_mains_C;
mw = P(1); hasPcm = P(23) > 0;
e = mw * p.cp_w_J_kgK * max(Tw - Tm, 0);
if hasPcm, e = e + p.m_pcm_kg * p.cp_s_J_kgK * max(Tp - Tm, 0) + p.m_pcm_kg * p.L_J_kg * f; end
e = e / 3.6e6;
end

function print_day(D)
for a = 1:3
    S = D.arm{a};
    fprintf('arm%d: del %.2f kWh  unmet %.2f  trips %d  C/D/I %d/%d/%d h  byp %d h | ', a, sum(S.E_del_Wh)/1e3, sum(S.E_unmet_Wh)/1e3, ...
        sum(S.n_sw + S.n_sp), sum(S.phase==1), sum(S.phase==2), sum(S.phase==3), sum(S.bypass));
end
fprintf('\n');
end

% ======================================================================
function render_video(D, tw, ttl, file, dayNo, year, fpH)
pp = tw.params; cl = colors();
fig = figure('Visible', 'off', 'Position', [40 40 1600 900], 'Color', 'w', 'Renderer', 'painters');
% ---------- header ----------
axH = axes(fig, 'Position', [0 0.925 1 0.075]); axis(axH, 'off'); xlim(axH, [0 1]); ylim(axH, [0 1]);
patch(axH, [0 1 1 0], [0 0 1 1], [0.10 0.20 0.33], 'EdgeColor', 'none');
text(axH, 0.012, 0.70, 'Solar water heater with PCM + AI controller  |  Tamil Nadu  |  Objective 4 software-in-the-loop twin', 'Color', 'w', 'FontSize', 14, 'FontWeight', 'bold', 'VerticalAlignment', 'middle');
text(axH, 0.012, 0.08, sprintf('%s  --  day %d of %d, 00:00 to 24:00', ttl, dayNo, year), 'Color', [1 0.85 0.4], 'FontSize', 12.5, 'FontWeight', 'bold', 'VerticalAlignment', 'bottom');
hClock = text(axH, 0.985, 0.5, '', 'Color', 'w', 'FontSize', 22, 'FontWeight', 'bold', 'HorizontalAlignment', 'right');

% ---------- schematic ----------
ax = axes(fig, 'Position', [0.005 0.205 0.625 0.715]); hold(ax, 'on'); axis(ax, 'off');
xlim(ax, [0 100]); ylim(ax, [0 69]); daspect(ax, [1 1 1]);
G = draw_schematic(ax, pp);

% ---------- right-hand plots ----------
t24 = 0:24; col3 = {cl.plain, cl.pcm, cl.ai};
ax1 = axes(fig, 'Position', [0.675 0.725 0.305 0.175]); hold(ax1, 'on'); box(ax1, 'on'); grid(ax1, 'on');
title(ax1, 'Water temperature in the tank', 'FontSize', 11, 'FontWeight', 'bold'); ylabel(ax1, '\circC'); xlim(ax1, [0 24]);
Tw_all = [cellfun(@(S) max(S.Tw), D.arm); cellfun(@(S) min(S.Tw), D.arm)];
ylim(ax1, [10, 85]);
yline(ax1, pp.T_deliv_C, 'k--', '45 \circC target', 'LabelHorizontalAlignment', 'left', 'FontSize', 8);
yline(ax1, pp.bypass_wC, 'r:', '72 \circC safety limit', 'LabelHorizontalAlignment', 'left', 'FontSize', 8);
h1 = gobjects(3,1); for a = 1:3, h1(a) = plot(ax1, NaN, NaN, '-', 'Color', col3{a}, 'LineWidth', 2.4); end
hP1 = plot(ax1, NaN, NaN, '-', 'Color', cl.pcmT, 'LineWidth', 1.6);
lg = legend(ax1, [h1; hP1], {'Plain tank', 'PCM only', 'AI + PCM', 'PCM temp (AI+PCM)'}, 'Location', 'southeast', 'FontSize', 8, 'Box', 'off', 'NumColumns', 2);
hC1 = xline(ax1, 0, 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');

ax2 = axes(fig, 'Position', [0.675 0.485 0.305 0.175]); hold(ax2, 'on'); box(ax2, 'on'); grid(ax2, 'on');
title(ax2, 'Hot-water energy delivered so far', 'FontSize', 11, 'FontWeight', 'bold'); ylabel(ax2, 'kWh'); xlim(ax2, [0 24]);
cumE = cell2mat(cellfun(@(S) [0; cumsum(S.E_del_Wh)/1e3], D.arm', 'UniformOutput', false));
ylim(ax2, [0 max(1, 1.12 * max(cumE(:)))]);
h2 = gobjects(3,1); for a = 1:3, h2(a) = plot(ax2, NaN, NaN, '-', 'Color', col3{a}, 'LineWidth', 2.4); end
hC2 = xline(ax2, 0, 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');

ax3 = axes(fig, 'Position', [0.675 0.245 0.305 0.175]); hold(ax3, 'on'); box(ax3, 'on');
title(ax3, 'PCM melt (AI + PCM) and what the day is doing', 'FontSize', 11, 'FontWeight', 'bold'); ylabel(ax3, 'melted %'); xlim(ax3, [0 24]); ylim(ax3, [0 100]);
S3 = D.arm{3};
for h = 1:24
    patch(ax3, [h-1 h h h-1], [0 0 100 100], cl.phase(S3.phase(h), :), 'EdgeColor', 'none', 'FaceAlpha', 0.35);
end
xlabel(ax3, 'hour of day');
h3 = plot(ax3, NaN, NaN, '-', 'Color', cl.melt, 'LineWidth', 2.6);
hC3 = xline(ax3, 0, 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
hq = gobjects(3,1); for p = 1:3, hq(p) = patch(ax3, NaN, NaN, cl.phase(p,:), 'FaceAlpha', 0.6, 'EdgeColor', 'none'); end
legend(ax3, [hq; h3], {'charging hour', 'discharging hour', 'idle hour', 'PCM melted'}, 'Location', 'northwest', 'Box', 'off', 'FontSize', 8);

% ---------- bottom strip: the four objectives ----------
axB = axes(fig, 'Position', [0.005 0.008 0.99 0.19]); axis(axB, 'off'); xlim(axB, [0 100]); ylim(axB, [0 10]);
bx = [0.5 25.5 50.5 75.5]; bw = 24; names = {'O1  PCM material', 'O2  Tank design', 'O3  AI controller (SAC)', 'O4  Software-in-the-loop check'};
subs = {sprintf('PureTemp 58 (melts at %d C, %d kJ/kg)', pp.Tm_C, pp.L_J_kg/1e3), ...
        sprintf('%d capsules, %.1f kg PCM, %.1f m^2, %.3f kg/s', pp.n_capsule, pp.m_pcm_kg, pp.A_coll_m2, pp.flow_kg_s), ...
        'trained policy: CHARGE / IDLE / BYPASS', ...
        'sensor model + safety shield + fail-safe'};
hB = gobjects(4,1);
for k = 1:4
    patch(axB, bx(k) + [0 bw bw 0], [0.4 0.4 9.6 9.6], [0.95 0.97 1.0], 'EdgeColor', cl.obj(k,:), 'LineWidth', 2);
    patch(axB, bx(k) + [0 bw bw 0], [7.2 7.2 9.6 9.6], cl.obj(k,:), 'EdgeColor', 'none');
    text(axB, bx(k) + 0.7, 8.4, names{k}, 'Color', 'w', 'FontSize', 11.5, 'FontWeight', 'bold');
    text(axB, bx(k) + 0.7, 6.1, subs{k}, 'FontSize', 9.5, 'Color', [0.25 0.25 0.25]);
    hB(k) = text(axB, bx(k) + 0.7, 3.0, '', 'FontSize', 9.5, 'FontWeight', 'bold', 'Color', [0.1 0.1 0.1], 'VerticalAlignment', 'middle');
end

% ---------- writer ----------
fps = 20;
vw = VideoWriter(file, 'MPEG-4'); vw.FrameRate = fps; vw.Quality = 95; open(vw);
cleanup = onCleanup(@() close(vw));
actName = {'CHARGE', 'IDLE', 'BYPASS'}; phName = {'CHARGING', 'DISCHARGING', 'IDLE'};
S = D.arm;
prev = @(S, fld, init) [init; S.(fld)(:)];
nFr = 0; snaps = [0.27 0.45 0.62 0.80];  snapDone = false(size(snaps));
for h = 1:24
    for q = 1:fpH
        s = (q - 1) / fpH + 1/fpH;                 % fraction through the hour (0..1]
        clk = (h - 1) + s;
        Sa = S{3};
        % interpolated state of the AI + PCM system (hour-end values, linear in the hour)
        lerp = @(v0, v1) v0 + s * (v1 - v0);
        Tw3 = lerp(prevv(Sa.Tw, h, Sa.init.Tw0), Sa.Tw(h)); Tp3 = lerp(prevv(Sa.Tpcm, h, Sa.init.Tpcm0), Sa.Tpcm(h));
        f3 = lerp(prevv(Sa.f_melt, h, Sa.init.f0), Sa.f_melt(h));
        I = lerp(prevv(Sa.GHI, h, Sa.GHI(1)), Sa.GHI(h)); Ta = lerp(prevv(Sa.T_amb, h, Sa.T_amb(1)), Sa.T_amb(h));
        pumpOn = Sa.Q_coll_Wh(h) > 0; by = Sa.bypass(h); shield = Sa.shield(h);
        draw = Sa.draw_kg(h); Qc = Sa.Q_coll_Wh(h);

        % ---- schematic state ----
        set(G.hClock, 'String', ''); set(hClock, 'String', sprintf('%02d:%02d', floor(clk), floor(mod(clk,1)*60)));
        rr = min(I / 1000, 1.2);
        set(G.sun, 'XData', 9 + (3.6 + 2.6*rr)*cos(G.th), 'YData', 59 + (3.6 + 2.6*rr)*sin(G.th));
        for k = 1:numel(G.rays)
            set(G.rays(k), 'LineWidth', 0.6 + 2.8*min(rr,1), 'Visible', onoff(I > 15), 'Color', [1 0.72 0.1 min(1, 0.25 + rr)]);
        end
        set(G.sunNight, 'Visible', onoff(I <= 15));
        set(G.cells, 'FaceColor', cl.cell * (1 - 0.0) );
        set(G.absorb, 'FaceColor', mix([0.98 0.85 0.15], [0.95 0.45 0.05], min(Qc/1500, 1)));
        set(G.byp1, 'Visible', onoff(by)); set(G.byp2, 'Visible', onoff(by));
        set(G.supply, 'Color', pcol(Tw3 + min(22, Qc/70)), 'LineStyle', ternary(pumpOn, '-', ':'));
        set(G.retn, 'Color', pcol(Tw3 - 4), 'LineStyle', ternary(pumpOn, '-', ':'));
        set(G.water, 'FaceColor', pcol(Tw3) * 0.35 + 0.65);
        set(G.caps, 'CData', repmat(cap_colour(f3, Tp3), numel(G.caps.XData), 1));
        set(G.pumpBody, 'FaceColor', ternary(pumpOn, [0.25 0.75 0.35], [0.72 0.72 0.72]));
        if pumpOn, G.s = mod(G.s + 0.035, 1); G.ang = G.ang + 0.8; end
        [px, py] = along(G.supplyPath, G.s);  set(G.pS, 'XData', px, 'YData', py, 'CData', pcol(Tw3 + min(22, Qc/70)), 'Visible', onoff(pumpOn));
        [px, py] = along(G.retnPath, G.s);    set(G.pR, 'XData', px, 'YData', py, 'CData', pcol(Tw3 - 4), 'Visible', onoff(pumpOn));
        set(G.blade, 'XData', [G.pump(1) G.pump(1) + 2.6*cos(G.ang)], 'YData', [G.pump(2) G.pump(2) + 2.6*sin(G.ang)]);
        set(G.hot, 'LineWidth', 0.5 + 5*min(draw/50, 1), 'Visible', onoff(draw >= 1));
        set(G.cold, 'LineWidth', 0.5 + 5*min(draw/50, 1), 'Visible', onoff(draw >= 1));
        % info labels
        set(G.tGHI, 'String', sprintf('%4.0f W/m^2', I)); set(G.tTa, 'String', sprintf('%4.1f \\circC', Ta));
        set(G.tFlow, 'String', sprintf('%.3f kg/s', ternary(pumpOn, pp.flow_kg_s, 0)));
        set(G.tTw, 'String', sprintf('Water %4.1f \\circC', Tw3)); set(G.tTp, 'String', sprintf('PCM %4.1f \\circC', Tp3));
        set(G.tMelt, 'String', sprintf('melted %3.0f %%', 100*f3));
        set(G.tQ, 'String', sprintf('collector gain %4.0f W', Qc));
        set(G.tDraw, 'String', sprintf('hot water out %4.1f kg/h', draw));
        % AI box / banner
        act = Sa.a_exec(h) + 1;
        set(G.aiAct, 'String', sprintf('AI action: %s', actName{Sa.a_policy(h) + 1}));
        ph = Sa.phase(h);
        set(G.banner, 'String', phName{ph}, 'BackgroundColor', cl.phase(ph,:), 'Color', cl.phaseTxt(ph,:));
        msg = '';
        if Sa.interlock(h) == 2, msg = 'SENSOR FAULT - fail-safe BYPASS';
        elseif Sa.interlock(h) == 3, msg = 'HARD-LIMIT FAULT LATCHED';
        elseif shield, msg = 'safety shield active (72 C / 62 C)';
        elseif by, msg = 'collector bypassed (AI decision)'; end
        set(G.msg, 'String', msg);
        set(G.sensor, 'String', ternary(Sa.sensors_ok(h) > 0.5, 'sensors: OK', 'sensors: STALE'), 'Color', ternary(Sa.sensors_ok(h) > 0.5, [0.55 0.95 0.55], [1 0.45 0.45]));
        set(G.hHeader, 'String', '');

        % ---- plots ----
        tt = [0:h-1, clk];
        for a = 1:3
            v = [S{a}.init.Tw0; S{a}.Tw(1:h)]; v(end) = lerp_end(v, s);
            set(h1(a), 'XData', tt, 'YData', v);
            e = [0; cumsum(S{a}.E_del_Wh(1:h))/1e3]; e(end) = lerp_end(e, s);
            set(h2(a), 'XData', tt, 'YData', e);
        end
        vp = [Sa.init.Tpcm0; Sa.Tpcm(1:h)]; vp(end) = lerp_end(vp, s); set(hP1, 'XData', tt, 'YData', vp);
        vf = 100 * [Sa.init.f0; Sa.f_melt(1:h)]; vf(end) = lerp_end(vf, s); set(h3, 'XData', tt, 'YData', vf);
        set(hC1, 'Value', clk); set(hC2, 'Value', clk); set(hC3, 'Value', clk);

        % ---- objective strip (live) ----
        Est = lerp(prevv(Sa.Estored, h, Sa.Estored0), Sa.Estored(h));
        nC = sum(Sa.phase(1:h-1) == 1) + (ph == 1)*s; nD = sum(Sa.phase(1:h-1) == 2) + (ph == 2)*s; nI = sum(Sa.phase(1:h-1) == 3) + (ph == 3)*s;
        set(hB(1), 'String', sprintf('PCM melted %3.0f %%\nPCM temperature %4.1f C', 100*f3, Tp3));
        set(hB(2), 'String', sprintf('heat stored %.2f kWh\ncharge %.1f h | discharge %.1f h | idle %.1f h', Est, nC, nD, nI));
        set(hB(3), 'String', sprintf('AI + PCM delivered %.2f kWh\nPCM only %.2f | plain tank %.2f kWh', ...
            lerp_end([0; cumsum(S{3}.E_del_Wh(1:h))/1e3], s), lerp_end([0; cumsum(S{2}.E_del_Wh(1:h))/1e3], s), lerp_end([0; cumsum(S{1}.E_del_Wh(1:h))/1e3], s)));
        trips = [sum(S{1}.n_sw(1:h) + S{1}.n_sp(1:h)), sum(S{2}.n_sw(1:h) + S{2}.n_sp(1:h)), sum(Sa.n_sw(1:h) + Sa.n_sp(1:h))];
        set(hB(4), 'String', sprintf('shield trips: AI+PCM %d | PCM only %d | plain %d\nhard-limit violations: %d', trips(3), trips(2), trips(1), sum(Sa.n_viol(1:h))));

        drawnow limitrate;
        fr = getframe(fig); writeVideo(vw, fr); nFr = nFr + 1;
        for k = 1:numel(snaps)
            if ~snapDone(k) && clk >= snaps(k) * 24
                imwrite(fr.cdata, strrep(file, '.mp4', sprintf('_%02dh.png', floor(clk)))); snapDone(k) = true;
            end
        end
    end
end
% ---------- result card held for 4 s ----------
card = result_card(fig, D, ttl);
for k = 1:4*fps, fr = getframe(fig); writeVideo(vw, fr); end
imwrite(fr.cdata, strrep(file, '.mp4', '_result.png'));
delete(card);
close(vw); clear cleanup; close(fig);
fprintf('[showcase] wrote %s (%d frames + result card)\n', file, nFr);
end

function v = prevv(vec, h, init)
if h == 1, v = init; else, v = vec(h-1); end
end
function v = lerp_end(vec, s)
% vec(end) is the hour-end value; interpolate between vec(end-1) and vec(end) by s
if numel(vec) < 2, v = vec(end); else, v = vec(end-1) + s * (vec(end) - vec(end-1)); end
end

% ----------------------------------------------------------------------
function card = result_card(fig, D, ttl)
cl = colors();
card = axes(fig, 'Position', [0.12 0.26 0.76 0.64]); axis(card, 'off'); hold(card, 'on'); xlim(card, [0 100]); ylim(card, [0 100]);
patch(card, [0 100 100 0], [0 0 100 100], [1 1 1], 'EdgeColor', [0.1 0.2 0.33], 'LineWidth', 3, 'FaceAlpha', 1);
text(card, 50, 93, 'Result of the day', 'FontSize', 20, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Color', [0.1 0.2 0.33]);
text(card, 50, 85, ttl, 'FontSize', 11.5, 'HorizontalAlignment', 'center', 'Color', [0.3 0.3 0.3]);
hdr = {'', 'Hot water delivered', 'Charge h', 'Discharge h', 'Idle h', 'Safety shield trips', 'Peak C'};
xs = [3 24 44 55 67 77 92]; ys = 74;
for k = 1:numel(hdr), text(card, xs(k), ys, hdr{k}, 'FontSize', 11, 'FontWeight', 'bold', 'Color', [0.2 0.2 0.2]); end
nm = {'Plain tank', 'PCM only (no AI)', 'AI + PCM'}; cc = {cl.plain, cl.pcm, cl.ai};
for a = 1:3
    S = D.arm{a}; y = 62 - (a-1)*13;
    patch(card, [1 99 99 1], [y-5 y-5 y+5 y+5], cc{a}, 'FaceAlpha', 0.12, 'EdgeColor', 'none');
    vals = {nm{a}, sprintf('%.2f kWh', sum(S.E_del_Wh)/1e3), sprintf('%d', sum(S.phase==1)), sprintf('%d', sum(S.phase==2)), ...
        sprintf('%d', sum(S.phase==3)), sprintf('%d', sum(S.n_sw + S.n_sp)), sprintf('%.1f', max(S.Tw))};
    for k = 1:numel(vals), text(card, xs(k), y, vals{k}, 'FontSize', 12.5, 'FontWeight', 'bold', 'Color', cc{a} * 0.75); end
end
[v1, v2, v3] = verdict(D);
text(card, 4, 27, v1, 'FontSize', 12, 'Color', [0.1 0.1 0.1]);
text(card, 4, 19, v2, 'FontSize', 12, 'Color', [0.1 0.1 0.1]);
text(card, 4, 11, v3, 'FontSize', 12, 'Color', [0.1 0.1 0.1]);
text(card, 4, 3.5, 'Phases are counted per hour from the simulation log. Software emulation only, not a hardware test.', 'FontSize', 9, 'Color', [0.45 0.45 0.45]);
drawnow;
end

function [v1, v2, v3] = verdict(D)
e = cellfun(@(S) sum(S.E_del_Wh)/1e3, D.arm); tr = cellfun(@(S) sum(S.n_sw + S.n_sp), D.arm);
v1 = sprintf('AI + PCM vs plain tank: %+.2f kWh hot water (%+.0f %%); PCM stores heat, so water stays hot after sunset.', e(3)-e(1), 100*(e(3)-e(1))/max(e(1), 1e-9));
if strcmp(D.name, 'rain_cloud')
    v2 = 'With almost no sun no system can collect much; all three arms are close on energy.';
else
    v2 = sprintf('AI + PCM vs PCM only: %+.2f kWh hot water, but %d vs %d safety-shield trips (%.0f %% fewer).', e(3)-e(2), tr(3), tr(2), 100*(tr(2)-tr(3))/max(tr(2), 1));
end
if sum(D.arm{3}.n_viol) == 0, v3 = 'No arm exceeded the hard temperature limits (0 violations).'; else, v3 = 'Hard-limit violations occurred, see log.'; end
end

% ======================================================================
function G = draw_schematic(ax, pp)
cl = colors();
G.th = linspace(0, 2*pi, 50); th = G.th;
% sun and rays
G.sun = patch(ax, 9 + 5*cos(th), 59 + 5*sin(th), [1 0.82 0.1], 'EdgeColor', [1 0.55 0], 'LineWidth', 1.5);
G.sunNight = text(ax, 9, 52.5, 'no sunlight', 'FontSize', 9, 'Color', [0.4 0.4 0.4], 'HorizontalAlignment', 'center', 'Visible', 'off');
G.rays = gobjects(3,1);
for k = 1:3
    x0 = 15 + 3*k; y0 = 56 - 7*k + 2; xx = linspace(0, 11, 30);
    G.rays(k) = plot(ax, x0 + xx, y0 - 0.55*xx + 1.6*sin(xx/2.2), '-', 'Color', [1 0.72 0.1], 'LineWidth', 2);
end
% collector (tilted) : glass frame, absorber, cells
ang = atan2(26, 36); u = [cos(ang) sin(ang)]; nrm = [-sin(ang) cos(ang)];
A0 = [10 22]; Lc = 44; Wc = 5.4;
corner = @(a, b) A0 + a*u + b*nrm;
c1 = corner(0,0); c2 = corner(Lc,0); c3 = corner(Lc,Wc); c4 = corner(0,Wc);
patch(ax, [c1(1) c2(1) c3(1) c4(1)], [c1(2) c2(2) c3(2) c4(2)], [0.86 0.92 0.97], 'EdgeColor', [0.25 0.3 0.4], 'LineWidth', 2);
a1 = corner(1.5, 1.2); a2 = corner(Lc-1.5, 1.2); a3 = corner(Lc-1.5, 3.0); a4 = corner(1.5, 3.0);
G.absorb = patch(ax, [a1(1) a2(1) a3(1) a4(1)], [a1(2) a2(2) a3(2) a4(2)], [0.98 0.85 0.15], 'EdgeColor', [0.6 0.45 0], 'LineWidth', 1);
nCell = 7; cw = (Lc - 4) / nCell; G.cells = gobjects(nCell, 1);
for k = 1:nCell
    s0 = 2 + (k-1)*cw + 0.4; s1 = 2 + k*cw - 0.4;
    p1 = corner(s0, 3.2); p2 = corner(s1, 3.2); p3 = corner(s1, 4.8); p4 = corner(s0, 4.8);
    G.cells(k) = patch(ax, [p1(1) p2(1) p3(1) p4(1)], [p1(2) p2(2) p3(2) p4(2)], cl.cell, 'EdgeColor', [0.1 0.2 0.5], 'LineWidth', 0.8);
end
m = corner(Lc/2, Wc/2);
G.byp1 = plot(ax, [m(1)-7 m(1)+7], [m(2)-5 m(2)+5], '-', 'Color', [0.85 0.1 0.1], 'LineWidth', 5, 'Visible', 'off');
G.byp2 = plot(ax, [m(1)-7 m(1)+7], [m(2)+5 m(2)-5], '-', 'Color', [0.85 0.1 0.1], 'LineWidth', 5, 'Visible', 'off');
text(ax, 1, 34.5, 'Solar collector', 'FontSize', 10.5, 'Color', [0.2 0.3 0.4], 'FontWeight', 'bold');
% pyranometer + ambient sensor
py = [30 57.5];
patch(ax, py(1) + 2.6*cos(linspace(0, pi, 20)), py(2) + 1.8*sin(linspace(0, pi, 20)), [0.92 0.92 0.92], 'EdgeColor', [0.3 0.3 0.3]);
patch(ax, py(1) + [-3.2 3.2 3.2 -3.2], py(2) + [-0.9 -0.9 0 0], [0.55 0.55 0.55], 'EdgeColor', [0.3 0.3 0.3]);
text(ax, py(1), 62.2, 'Pyranometer', 'FontSize', 10.5, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
G.tGHI = text(ax, py(1), 54.4, '', 'FontSize', 10, 'HorizontalAlignment', 'center', 'Color', [0.7 0.4 0]);
amb = [68 58];
for k = 0:3, patch(ax, amb(1) + [-2.4 2.4 2.4 -2.4], amb(2) + 4.2 - k*1.9 + [0 0 -1.2 -1.2], [0.85 0.85 0.85], 'EdgeColor', [0.4 0.4 0.4]); end
text(ax, amb(1) + 4.2, 60.5, 'Ambient temp sensor', 'FontSize', 10.5, 'FontWeight', 'bold');
G.tTa = text(ax, amb(1) + 4.2, 57.2, '', 'FontSize', 10, 'Color', [0.7 0.4 0]);
% data logger + AI
lg = [27.5 19.2 19.5 9.8];
patch(ax, lg(1) + [0 lg(3) lg(3) 0], lg(2) + [0 0 lg(4) lg(4)], [0.15 0.17 0.22], 'EdgeColor', 'k', 'LineWidth', 1.5);
text(ax, lg(1) + lg(3)/2, lg(2) + 7.4, 'Data logger + AI (SAC)', 'Color', 'w', 'FontSize', 10, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
G.aiAct = text(ax, lg(1) + lg(3)/2, lg(2) + 4.4, '', 'Color', [0.55 0.95 0.55], 'FontSize', 10, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
G.sensor = text(ax, lg(1) + lg(3)/2, lg(2) + 1.7, '', 'FontSize', 9, 'HorizontalAlignment', 'center', 'Color', [0.55 0.95 0.55], 'FontWeight', 'bold');
% dashed signal lines
sig = {[py(1)+3.4 57.5; 52 57.5; 52 29; lg(1)+lg(3) 29], [py(1)+3.4 57.5; amb(1)-2.6 57.5], [lg(1)+lg(3) 24; 61 24], [lg(1)+8 lg(2); lg(1)+8 15.5; 52 15.5; 52 13.8]};
for k = 1:numel(sig), plot(ax, sig{k}(:,1), sig{k}(:,2), 'k--', 'LineWidth', 1.1); end
% tank
tk = [62 8 22 37];   % x y w h
bodyX = tk(1) + [0 tk(3) tk(3) 0]; bodyY = tk(2) + [0 0 tk(4) tk(4)];
G.water = patch(ax, bodyX, bodyY, [0.6 0.75 0.95], 'EdgeColor', [0.2 0.2 0.2], 'LineWidth', 2.5);
% capsules 8 x 13 = 104
[cx, cy] = meshgrid(tk(1) + 2.7 + (0:7)*2.37, tk(2) + 2.7 + (0:12)*2.52);
G.caps = scatter(ax, cx(:), cy(:), 95, repmat(cap_colour(0, 30), numel(cx), 1), 'filled', 'MarkerEdgeColor', [0.2 0.2 0.2], 'LineWidth', 0.6);
% copper coil (front arcs)
xc = linspace(tk(1) + 1.0, tk(1) + tk(3) - 1.0, 40);
for k = 0:8
    yk = tk(2) + 4 + k*3.8;
    plot(ax, xc, yk - 1.6*sin(pi*(xc - xc(1))/(xc(end) - xc(1))), '-', 'Color', [0.74 0.45 0.30], 'LineWidth', 2.6);
end
patch(ax, tk(1) + [-0.6 tk(3)+0.6 tk(3)+0.6 -0.6], tk(2) + tk(4) + [0 0 1.4 1.4], [0.75 0.75 0.78], 'EdgeColor', [0.2 0.2 0.2], 'LineWidth', 1.5);
text(ax, tk(1) + tk(3)/2 + 4, tk(2) - 5.2, 'Storage tank + coil + PCM capsules', 'FontSize', 10, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
G.tTw = text(ax, tk(1) + tk(3)/2, tk(2) + tk(4) + 5.0, '', 'FontSize', 11.5, 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', [0.1 0.2 0.6]);
G.tTp = text(ax, tk(1) + tk(3)/2, tk(2) + tk(4) + 2.7, '', 'FontSize', 11.5, 'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'Color', [0.85 0.4 0]);
G.tMelt = text(ax, tk(1) + tk(3) + 1, tk(2) + 20, '', 'FontSize', 9, 'Rotation', 0, 'Color', [0.85 0.4 0]);
% tank thermometer dash from logger
plot(ax, [lg(1)+lg(3) 52 52 tk(1)+4.5], [21.5 21.5 18 18], 'k--', 'LineWidth', 1.1); plot(ax, tk(1)+4.5, 18, 'o', 'MarkerSize', 6, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'r');
% pipes
G.supplyPath = [c3(1) c3(2) - Wc/2*0 - 1.5; 56.5 c3(2) - 1.5; 56.5 tk(2) + 33; tk(1) 33 + tk(2)];
G.retnPath = [tk(1) tk(2) + 3; 12 tk(2) + 3; 12 c1(2) + 0.2];
G.supply = plot(ax, G.supplyPath(:,1), G.supplyPath(:,2), '-', 'Color', [0.85 0.2 0.2], 'LineWidth', 5);
G.retn = plot(ax, G.retnPath(:,1), G.retnPath(:,2), '-', 'Color', [0.95 0.55 0.1], 'LineWidth', 5);
np = 14; G.s = (0:np-1)'/np; G.ang = 0;
G.pS = scatter(ax, nan(np,1), nan(np,1), 30, 'r', 'filled'); G.pR = scatter(ax, nan(np,1), nan(np,1), 30, 'r', 'filled');
% flow meter, pump
fm = [30 tk(2) + 3];
patch(ax, fm(1) + [-1.5 1.5 1.5 -1.5], fm(2) + [-2.4 -2.4 2.4 2.4], [0.88 0.92 0.95], 'EdgeColor', 'k', 'LineWidth', 1.4);
text(ax, fm(1), fm(2) - 4.3, 'Flow meter', 'FontSize', 10, 'HorizontalAlignment', 'center');
G.tFlow = text(ax, fm(1), fm(2) - 6.5, '', 'FontSize', 9.5, 'HorizontalAlignment', 'center', 'Color', [0.7 0.4 0]);
G.pump = [52 tk(2) + 3];
G.pumpBody = patch(ax, G.pump(1) + 3.3*cos(th), G.pump(2) + 3.3*sin(th), [0.72 0.72 0.72], 'EdgeColor', 'k', 'LineWidth', 1.6);
G.blade = plot(ax, [G.pump(1) G.pump(1) + 2.6], [G.pump(2) G.pump(2)], 'k-', 'LineWidth', 2.2);
text(ax, G.pump(1), G.pump(2) - 5.3, 'Pump', 'FontSize', 10.5, 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
% outlet / inlet
G.hot = quiver(ax, tk(1) + tk(3), tk(2) + 33, 11, 0, 0, 'Color', [0.85 0.15 0.15], 'LineWidth', 3, 'MaxHeadSize', 1.2);
G.cold = quiver(ax, tk(1) + tk(3) + 12, tk(2) + 3, -11, 0, 0, 'Color', [0.1 0.3 0.8], 'LineWidth', 3, 'MaxHeadSize', 1.2);
text(ax, tk(1) + tk(3) + 1, tk(2) + 36, 'Hot water', 'FontSize', 10.5, 'Color', [0.85 0.15 0.15], 'FontWeight', 'bold');
text(ax, tk(1) + tk(3) + 1, tk(2) + 0.2, 'Cold water', 'FontSize', 10.5, 'Color', [0.1 0.3 0.8], 'FontWeight', 'bold');
G.tDraw = text(ax, tk(1) + tk(3) + 1, tk(2) + 30.2, '', 'FontSize', 9.5, 'Color', [0.85 0.15 0.15]);
G.tQ = text(ax, 0.8, 6.5, '', 'FontSize', 10.5, 'Color', [0.6 0.3 0], 'FontWeight', 'bold');
% banner + message
G.banner = text(ax, 50, 66, 'IDLE', 'FontSize', 17, 'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Margin', 6, 'BackgroundColor', [0.9 0.9 0.9], 'EdgeColor', [0.3 0.3 0.3]);
G.msg = text(ax, 60.5, 66, '', 'FontSize', 10.5, 'FontWeight', 'bold', 'Color', [0.85 0.1 0.1], 'HorizontalAlignment', 'left');
G.hHeader = text(ax, 0, 0, '', 'Visible', 'off'); G.hClock = text(ax, 0, 0, '', 'Visible', 'off');
end

function c = cap_colour(f, Tp)
% solid-blue -> molten-orange with melt fraction; slight warming while solid
base = [0.30 0.50 0.90];
base = mix(base, [0.55 0.35 0.65], min(max((Tp - 30) / 28, 0), 1) * (1 - f) * 0.6);
c = (1 - f) * base + f * [1.0 0.5 0.05];
end

function c = pcol(T)
% heat-map colour for pipes / water: cool blue -> orange -> hot red
t = min(max((T - 25) / 50, 0), 1);
stops = [0.15 0.40 0.85; 0.95 0.65 0.10; 0.88 0.12 0.12];
if t < 0.5, c = mix(stops(1,:), stops(2,:), t/0.5); else, c = mix(stops(2,:), stops(3,:), (t-0.5)/0.5); end
end

function c = tcol(T)
t = min(max((T - 25) / 50, 0), 1);
c = [t, 0.35 * (1 - abs(2*t - 1)) + 0.1, 1 - t];
c = min(max(c, 0), 1);
end

function [x, y] = along(path, s)
seg = sqrt(sum(diff(path).^2, 2)); cum = [0; cumsum(seg)]; d = s * cum(end);
x = interp1(cum, path(:, 1), d); y = interp1(cum, path(:, 2), d);
end

function c = mix(a, b, t), c = (1-t)*a + t*b; end
function s = onoff(b), if b, s = 'on'; else, s = 'off'; end, end
function v = ternary(c, a, b), if c, v = a; else, v = b; end, end

function cl = colors()
cl.plain = [0.45 0.45 0.45]; cl.pcm = [0.10 0.35 0.80]; cl.ai = [0.85 0.15 0.15]; cl.pcmT = [0.95 0.55 0.05]; cl.melt = [0.8 0.1 0.7];
cl.cell = [0.20 0.35 0.75];
cl.phase = [1.00 0.80 0.30; 0.45 0.72 0.95; 0.80 0.80 0.80];     % charge, discharge, idle
cl.phaseTxt = [0.45 0.25 0.0; 0.0 0.2 0.5; 0.25 0.25 0.25];
cl.obj = [0.85 0.45 0.10; 0.15 0.50 0.35; 0.80 0.15 0.20; 0.30 0.30 0.70];
end

% ======================================================================
function plot_day(D, ttl, file, dayNo, year)
cl = colors();
fig = figure('Visible', 'off', 'Position', [50 50 1500 850], 'Color', 'w');
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, sprintf('%s  (Tamil Nadu, day %d of %d)', ttl, dayNo, year), 'FontWeight', 'bold', 'FontSize', 14);
cc = {cl.plain, cl.pcm, cl.ai}; nm = {'Plain tank', 'PCM only (no AI)', 'AI + PCM'};
t = (1:24)' - 0.5; S3 = D.arm{3};
% 1 temperatures
ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
shade_phases(ax, S3.phase, cl);
for a = 1:3, plot(ax, t, D.arm{a}.Tw, '-', 'Color', cc{a}, 'LineWidth', 2.4); end
plot(ax, t, S3.Tpcm, '--', 'Color', cl.pcmT, 'LineWidth', 1.8);
yline(ax, 45, 'k--'); yline(ax, 72, 'r:');
title(ax, 'Temperatures'); ylabel(ax, '\circC'); xlim(ax, [0 24]); xlabel(ax, 'hour of day');
legend(ax, [nm, {'PCM temp (AI + PCM)'}], 'Location', 'southeast', 'Box', 'off', 'FontSize', 8, 'NumColumns', 2);
% 2 delivered energy
ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
for a = 1:3, plot(ax, 0:24, [0; cumsum(D.arm{a}.E_del_Wh)/1e3], '-', 'Color', cc{a}, 'LineWidth', 2.4); end
title(ax, 'Hot-water energy delivered (cumulative)'); ylabel(ax, 'kWh'); xlim(ax, [0 24]); xlabel(ax, 'hour of day');
% 3 melt + collector gain
ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on'); grid(ax, 'on');
yyaxis(ax, 'left'); plot(ax, t, 100*D.arm{2}.f_melt, '-', 'Color', cl.pcm, 'LineWidth', 2.2); plot(ax, t, 100*S3.f_melt, '-', 'Color', cl.ai, 'LineWidth', 2.2); ylabel(ax, 'PCM melted %'); ylim(ax, [0 105]);
yyaxis(ax, 'right'); bar(ax, t, S3.Q_coll_Wh, 0.5, 'FaceColor', [0.95 0.75 0.2], 'FaceAlpha', 0.5, 'EdgeColor', 'none'); ylabel(ax, 'collector heat, AI + PCM  [Wh/h]');
title(ax, 'PCM melting and collector heat'); xlim(ax, [0 24]); xlabel(ax, 'hour of day');
legend(ax, {'PCM only', 'AI + PCM'}, 'Location', 'northeast', 'Box', 'off', 'FontSize', 8);
% 4 phase hours
ax = nexttile(tl); hold(ax, 'on'); box(ax, 'on');
H = zeros(3, 3); for a = 1:3, for p = 1:3, H(a, p) = sum(D.arm{a}.phase == p); end, end
b = barh(ax, H, 'stacked'); for p = 1:3, b(p).FaceColor = cl.phase(p, :); b(p).EdgeColor = 'k'; end
set(ax, 'YTick', 1:3, 'YTickLabel', nm, 'YDir', 'reverse'); xlim(ax, [0 24]); xlabel(ax, 'hours in the day');
title(ax, 'Hours per day: charge / discharge / idle');
for a = 1:3, x0 = 0; for p = 1:3, if H(a,p) > 0, text(ax, x0 + H(a,p)/2, a, sprintf('%d h', H(a,p)), 'HorizontalAlignment', 'center', 'FontWeight', 'bold'); end, x0 = x0 + H(a,p); end, end
legend(ax, {'charge', 'discharge', 'idle'}, 'Location', 'southoutside', 'Orientation', 'horizontal', 'Box', 'off');
exportgraphics(fig, file, 'Resolution', 130); close(fig);
end

function shade_phases(ax, ph, cl)
for h = 1:numel(ph)
    patch(ax, [h-1 h h h-1], [0 0 100 100], cl.phase(ph(h), :), 'EdgeColor', 'none', 'FaceAlpha', 0.28, 'HandleVisibility', 'off');
end
ylim(ax, [10 85]);
end

% ======================================================================
function write_tables(R, figDir)
rows = {}; nm = {'plain_tank', 'pcm_only', 'ai_pcm'};
for f = fieldnames(R)'
    D = R.(f{1});
    for a = 1:3
        S = D.arm{a};
        rows(end+1, :) = {f{1}, nm{a}, sum(S.phase==1), sum(S.phase==2), sum(S.phase==3), sum(S.bypass), sum(S.E_del_Wh)/1e3, sum(S.E_unmet_Wh)/1e3, ...
            sum(S.n_sw + S.n_sp), max(S.Tw), max(S.Tpcm), 100*max(S.f_melt), sum(S.n_viol)}; %#ok<AGROW>
    end
end
T = cell2table(rows, 'VariableNames', {'scenario', 'system', 'charge_h', 'discharge_h', 'idle_h', 'bypass_h', 'delivered_kWh', 'unmet_kWh', ...
    'shield_trips', 'peak_water_C', 'peak_pcm_C', 'peak_melt_pct', 'hard_violations'});
writetable(T, fullfile(figDir, 'o4_showcase_day_table.csv')); disp(T);
end

function plot_overall(Lyr, exportDir, figDir, R)
% simple annual comparison: three bars per metric, all from the logs / tables already on disk
cl = colors(); cc = {cl.plain, cl.pcm, cl.ai}; nm = {'Plain tank', 'PCM only', 'AI + PCM'};
del = zeros(3,1); trips = zeros(3,1); pump = zeros(3,1); over = zeros(3,1); unmet = zeros(3,1);
for a = 1:3
    L = Lyr{a}; del(a) = sum(L.E_del_Wh)/1e3; unmet(a) = sum(L.E_unmet_Wh)/1e3; trips(a) = sum(L.n_sw + L.n_sp);
    pump(a) = sum(L.Q_coll_Wh > 0); over(a) = sum(L.Tw >= 70);
end
HT = readtable(fullfile(exportDir, 'hold_test.csv')); hold45 = zeros(3,1);
arms = {'arm1_plain_B0', 'arm2_pcm_B0', 'arm3_pcm_SAC'};
for a = 1:3, hold45(a) = mean(HT.tau_hold_h(strcmp(HT.arm, arms{a}))); end
fprintf('[showcase] annual: delivered %s | trips %s | pump-hours %s | hours Tw>=70 %s | hold45 %s\n', mat2str(del',5), mat2str(trips'), mat2str(pump'), mat2str(over'), mat2str(hold45',3));
cov = 100 * del ./ (del + unmet);
T = table(nm', del, unmet, cov, hold45, trips, pump, over, 'VariableNames', {'system', 'delivered_kWh_2021', 'unmet_kWh_2021', 'demand_coverage_pct', 'hold_at_45C_h_mean12', 'shield_trips', 'pump_run_hours', 'hours_water_ge_70C'});
writetable(T, fullfile(figDir, 'o4_showcase_annual_table.csv'));
fig = figure('Visible', 'off', 'Position', [50 50 1800 520], 'Color', 'w');
tl = tiledlayout(fig, 1, 5, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Plain tank vs PCM only vs AI + PCM  (Tamil Nadu 100 L, full year 2021, same weather and demand)', 'FontWeight', 'bold', 'FontSize', 13);
vals = {del, hold45, trips/1000, over, pump}; ttls = {{'Hot water delivered, kWh', 'higher is better'}, {'Hours the tank stays above 45 C after sunset', '(mean of 12 start days) higher is better'}, {'Safety-shield interventions, thousands', 'lower is better'}, {'Hours with water at 70 C or more', '(safety limit is 72 C) lower is better'}, {'Pump run-hours', 'lower = less pump energy and wear'}};
for k = 1:5
    ax = nexttile(tl); hold(ax, 'on'); b = bar(ax, diag(vals{k}), 'stacked');
    for a = 1:3, b(a).FaceColor = cc{a}; end
    set(ax, 'XTick', 1:3, 'XTickLabel', nm); xtickangle(ax, 20); box(ax, 'on'); grid(ax, 'on'); title(ax, ttls{k}, 'FontSize', 9);
    for a = 1:3, text(ax, a, vals{k}(a), num2str(round(vals{k}(a), 1)), 'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', 'FontWeight', 'bold'); end
    ylim(ax, [0 max(vals{k}) * 1.15]);
end
exportgraphics(fig, fullfile(figDir, 'o4_annual_comparison.png'), 'Resolution', 130); close(fig);
end
