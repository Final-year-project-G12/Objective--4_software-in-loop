function [T, TH] = three_arm_hold_fix(regime, startDays, holdHours, exportRoot, thresholds)
%THREE_ARM_HOLD  Deliverable (iii): how long the store actually stays usable
% after charging stops, for the three arms.
%
% Method (the same one Objective 2 defines in src/metrics/tes_metrics.py):
%   1. Run the arm normally up to 18:00 on the chosen day, so the tank is in
%      the state that arm's own operation left it in.
%   2. From there: sun off (GHI = 0), no draw, real ambient temperature.
%   3. Record how long the delivery node stays at or above the target, and the
%      stored / recoverable energy and melt fraction at 24, 36, 48 and 72 h.
%
% tau_hold is censored at holdHours: a value equal to holdHours means "still
% above target when we stopped looking", not "exactly that long".
%
% Usage, from the state's matlab/ folder:
%   addpath('../../Common');
%   T = three_arm_hold(1, [20 110 200 290], 72);
%
% startDays  vector of day-of-year start points. Use several spread through
%            the year - one day tells you nothing about a climate.
% holdHours  how far to follow the cool-down (72 matches Objective 2's cap).
% thresholds temperatures at which to report the hold time. The default
%            [30 40 45 50] exists so the result can be compared with papers
%            that use a different criterion: Chen et al. (2025) report 31.7 h
%            at a 30 C threshold, Objective 2 uses 45 C, and the Uttarakhand
%            contract delivers at 50 C. One cool-down trace, read at several
%            levels, costs nothing extra and makes those comparisons honest.
%            Note the tank can never fall below its mains temperature
%            (7.4-28.5 C depending on state), so a 30 C threshold will be
%            censored almost always in the warm states - that is expected.
%
% Returns T  (the 24/36/48 h table, threshold = the contract target) and
%         TH (hold time at every threshold, for the cross-paper comparison).

if nargin < 1 || isempty(regime),     regime = 1; end
if nargin < 2 || isempty(startDays),  startDays = [20 110 200 290]; end
if nargin < 3 || isempty(holdHours),  holdHours = 72; end
if nargin < 4 || isempty(exportRoot), exportRoot = ''; end
if nargin < 5 || isempty(thresholds), thresholds = [30 40 45 50]; end

if isempty(exportRoot)
    if exist('twin_export_dir', 'file') == 2
        expDir = twin_export_dir(regime);
    else
        expDir = fullfile(pwd, '..', sprintf('export_r%d', regime));
    end
else
    expDir = exportRoot;
end

tw  = load_twin_params(expDir, []);
W   = tw.wx.signals.values;
tgt = tw.K.P(4);
BYPASS = 0;                    % Uttarakhand: 0 = BYPASS. Rajasthan: use 2.
if isfield(tw, 'params') && isfield(tw.params, 'state') && strcmpi(tw.params.state, 'rajasthan')
    BYPASS = 2;
end

off18 = find(round(W(1:24,4)) == 18, 1);
K_pcm   = tw.K;
K_plain = make_plain(tw.K);
arms = { struct('name','ARM1 plain + B0','K',K_plain,'mode',1), ...
         struct('name','ARM2 PCM + B0',  'K',K_pcm,  'mode',1), ...
         struct('name','ARM3 PCM + O3',  'K',K_pcm,  'mode',0) };

rows = {}; hrows = {};
for a = 1:3
    K = arms{a}.K;
    % --- spin up from 1 January so the store is in a realistic state, and
    %     capture (T, h) every hour by replaying the arm's own actions.
    lastDay = max(startDays);
    nSpin   = lastDay * 24;
    Wspin   = W(1:nSpin, :);
    L       = simulate_hours(tw, Wspin, K, arms{a}.mode, 0, []);

    Tst = tw.T0; hst = tw.h0;
    Tsnap = cell(nSpin, 1); hsnap = cell(nSpin, 1);
    for t = 1:nSpin
        [Tst, hst] = pcm_plant_hour(Wspin(t,2), Wspin(t,3), Wspin(t,4), L.a_cmd(t), Tst, hst, K);
        Tsnap{t} = Tst; hsnap{t} = hst;
    end

    for d = startDays
        % 18:00 on day d -> index (d-1)*24 + 19
        iStart = (d - 1) * 24 + off18;
        if iStart > nSpin || iStart + holdHours > size(W, 1), continue; end

        Th = Tsnap{iStart}; hh = hsnap{iStart};
        Kh = K; Kh.demand24 = zeros(size(K.demand24));     % no draw during a hold

        Ttop0 = Th(end);
        tr  = nan(holdHours, 4);                             % Ttop, f, Estor, Erec
        tau = NaN; censored = true; prev = Ttop0;
        for k = 1:holdHours
            iw = iStart + k;
            [Th, hh, rec] = pcm_plant_hour(0, W(iw,3), W(iw,4), BYPASS, Th, hh, Kh);
            tr(k,:) = [rec(1), rec(4), rec(18), rec(19)];
            if isnan(tau) && rec(1) < tgt
                frac = 1; if prev > rec(1), frac = (prev - tgt) / (prev - rec(1)); end
                tau = (k - 1) + frac; censored = false;
            end
            prev = rec(1);
        end
        if isnan(tau), tau = holdHours; end

        i24 = min(24, holdHours); i36 = min(36, holdHours); i48 = min(48, holdHours);
        rows{end+1} = { arms{a}.name, d, Ttop0, tau, censored, ...
            tr(i24,1), tr(i24,2), tr(i24,4), ...
            tr(i36,1), tr(i36,2), tr(i36,4), ...
            tr(i48,1), tr(i48,2), tr(i48,4) };  %#ok<AGROW>

        % --- the same cool-down trace read at every threshold -----------
        for th = thresholds(:)'
            if Ttop0 < th
                hrows{end+1} = { arms{a}.name, d, th, 0, false };  %#ok<AGROW>
                continue
            end
            tt = NaN; pv = Ttop0;
            for k = 1:holdHours
                if isnan(tt) && tr(k,1) < th
                    fr = 1; if pv > tr(k,1), fr = (pv - th) / (pv - tr(k,1)); end
                    tt = (k - 1) + fr;
                end
                pv = tr(k,1);
            end
            cz = isnan(tt);  if cz, tt = holdHours; end
            hrows{end+1} = { arms{a}.name, d, th, tt, cz };  %#ok<AGROW>
        end
    end
end

T = cell2table(vertcat(rows{:}), 'VariableNames', { ...
    'arm','start_day','T_top_start_C','tau_hold_h','censored', ...
    'T24_C','f24','Erec24_kWh','T36_C','f36','Erec36_kWh','T48_C','f48','Erec48_kWh'});

fprintf('\n=== Retention, regime %d, target %.0f C, cap %d h ===\n', regime, tgt, holdHours);
disp(T);
fprintf('\nMean tau_hold by arm:\n');
for a = 1:3
    m = T.tau_hold_h(strcmp(T.arm, arms{a}.name));
    nc = sum(T.censored(strcmp(T.arm, arms{a}.name)));
    fprintf('  %-18s %6.1f h   (%d of %d runs still above target at the %d h cap)\n', ...
            arms{a}.name, mean(m), nc, numel(m), holdHours);
end
fprintf('\nREAD THIS: tau_hold is dominated by the climate and the tank size, not\n');
fprintf('by the PCM. Compare arms within one regime only, and always quote the\n');
fprintf('censored count - a mean near %d h means the test ran out, not that the\n', holdHours);
fprintf('store is infinite.\n');

% ---- hold time at every threshold (for comparing with published work) ----
TH = cell2table(vertcat(hrows{:}), 'VariableNames', ...
      {'arm','start_day','threshold_C','tau_hold_h','censored'});
fprintf('\n=== Hold time by threshold (mean over %d start days) ===\n', numel(startDays));
fprintf('%-18s', 'arm');
for th = thresholds(:)', fprintf('%12s', sprintf('%.0f C', th)); end
fprintf('\n');
for a = 1:3
    fprintf('%-18s', arms{a}.name);
    for th = thresholds(:)'
        sel = strcmp(TH.arm, arms{a}.name) & TH.threshold_C == th;
        nc  = sum(TH.censored(sel));
        s   = sprintf('%.1f%s', mean(TH.tau_hold_h(sel)), repmat('*', 1, nc > 0));
        fprintf('%12s', s);
    end
    fprintf('\n');
end
fprintf('  * = at least one run was still above that threshold at the %d h cap.\n', holdHours);
fprintf('  Published figures use different criteria: Chen et al. (2025) report 31.7 h\n');
fprintf('  at 30 C for an RT35HC/CuO system on a 30 L/day demand. Quote the threshold\n');
fprintf('  and the demand whenever comparing.\n');

outDir = 'C:/Users/MANVIT~1/AppData/Local/Temp/claude/4dbe2732d992f3cf/859881a9-2e5b-4447-9c1e-06ce09319058/scratchpad/uk_hold_out';
if ~isfolder(outDir), mkdir(outDir); end
writetable(T,  fullfile(outDir, sprintf('three_arm_hold_r%d.csv', regime)));
writetable(TH, fullfile(outDir, sprintf('three_arm_hold_thresholds_r%d.csv', regime)));
fprintf('[three_arm_hold] tables -> %s\n', outDir);
end
