function [T, TH] = tn_hold_fix(exportDir, year, startDays, holdHours, thresholds)
%RUN_HOLD_TEST  Plan section 4.3 retention test, native to the Tamil Nadu
% single-node twin (pcm_plant_hour's state is scalar Tw/Tpcm/h/f, not a
% 10-node vector -- Rajasthan/Uttarakhand's Common/three_arm_hold.m does not
% fit this signature, per the Common/README's own warning). The METHOD is
% deliberately copied so results stay comparable across the team's states:
%   - start each hold at 18:00 local, from that arm's OWN state at that hour
%     (not a cold reset -- the tank must be in the state its own operation
%     left it in);
%   - sun off (I=0), no draw, real ambient, command BYPASS, hold up to
%     holdHours (72, matching Objective 2's cap);
%   - tau_hold = hours until the outlet first falls below the threshold,
%     LINEARLY INTERPOLATED within the hour it crosses, censored (= capped
%     at holdHours) if it never crosses;
%   - read at 24/36/48 h at the contract's own delivery target, AND at
%     [30 40 45 50] C for comparison with published work at other criteria.
%
%   [T, TH] = run_hold_test('../export', 2021, [], 72, [30 40 45 50])
here = fileparts(mfilename('fullpath')); addpath(here);
if nargin < 1 || isempty(exportDir), exportDir = fullfile(here, '..', 'export'); end
if nargin < 2, year = 2021; end
if nargin < 4 || isempty(holdHours), holdHours = 72; end
if nargin < 5 || isempty(thresholds), thresholds = [30 40 45 50]; end
OUT = 'C:/Users/MANVIT~1/AppData/Local/Temp/claude/4dbe2732d992f3cf/859881a9-2e5b-4447-9c1e-06ce09319058/scratchpad/tn_hold_out'; tw = load_twin_params(exportDir, year);
W = tw.wx.signals.values; n = size(W, 1);
tgt = tw.params.T_deliv_C;

if nargin < 3 || isempty(startDays)
    startDays = round(linspace(10, 350, 12));
end
fprintf('[run_hold_test] start days (day-of-year): %s\n', mat2str(startDays));
% 18:00 RULE: the exported weather's array position is NOT aligned to local
% midnight -- row 1 of day 1 is local_hour 5, not 0 (the LST<->UTC offset
% documented in Objective 2/3). A fixed "+19" (or Rajasthan's "+19")
% assumes midnight-aligned rows and silently picks the WRONG hour here --
% caught exactly by printing this check, as asked. Search for local_hour==18
% within each day's own 24-row block instead of assuming a fixed offset.
dayBlock1 = W(1:24, 4);
off18 = find(round(dayBlock1) == 18, 1);
fprintf('[run_hold_test] 18:00 RULE: local_hour==18 found at position %d within day 1''s 24-row block (NOT position 19 -- the data is UTC-offset, confirmed: row 1 = local_hour %d).\n', off18, W(1,4));
fprintf('[run_hold_test] CENSORING RULE: if T never falls below the threshold within %d h, tau_hold is reported\n', holdHours);
fprintf('                as exactly %d h with censored=true -- "ran out of hold time", not "holds forever".\n', holdHours);

fraction = tw.params.n_capsule*pi/6*tw.params.D_cap_m^3/0.100;
P_pcm = tw.P; P_plain = tw.P; P_plain(1) = tw.P(1) / (1 - fraction); P_plain(23) = 0;
BYPASS = 2;  % Tamil Nadu: 0=CHARGE,1=IDLE,2=BYPASS (see Common/README's per-state action-code warning)

arms = {'arm1_plain_B0', P_plain, 1; 'arm2_pcm_B0', P_pcm, 1; 'arm3_pcm_SAC', P_pcm, 0};
lastDay = max(startDays);
Wspin = W(1:lastDay*24, :);

rows = {}; hrows = {};
printedWorkedExample = false;
printedThreshExample = false;
for a = 1:size(arms,1)
    nm = arms{a,1}; P = arms{a,2}; mode = arms{a,3};
    Lspin = simulate_hours(tw, Wspin, P, mode, 0, []);

    for d = startDays
        iStart = (d-1)*24 + off18;
        if iStart + holdHours > n, continue; end
        Tw0 = Lspin.Tw(iStart); Tp0 = Lspin.Tpcm(iStart); h0 = Lspin.h_pcm(iStart); f0 = Lspin.f_melt(iStart);

        trT = zeros(holdHours,1); trF = zeros(holdHours,1); trRec = zeros(holdHours,1);
        Tw_ = Tw0; Tp_ = Tp0; h_ = h0; f_ = f0;
        tau = NaN; censored = true; prev = Tw0;
        if Tw0 < tgt, tau = 0; censored = false; end  % already below target at 18:00 -- not a mid-hold crossing
        worked = {};
        for k = 1:holdHours
            iw = iStart + k;
            [Tw_, Tp_, h_, f_] = pcm_plant_hour(0, W(iw,3), 0, BYPASS, Tw_, Tp_, h_, f_, P);
            trT(k) = Tw_; trF(k) = f_;
            trRec(k) = max(P(1)*P(2)*(Tw_-tgt), 0)/3.6e6 + P(14)*P(17)*f_*double(Tw_>tgt)/3.6e6;
            if isnan(tau) && Tw_ < tgt
                frac = 1; if prev > Tw_, frac = (prev - tgt) / (prev - Tw_); end
                tau = (k-1) + frac; censored = false;
                if strcmp(nm, 'arm3_pcm_SAC') && ~printedWorkedExample
                    worked = {k, prev, Tw_, frac, tau};
                end
            end
            prev = Tw_;
        end
        if isnan(tau), tau = holdHours; end

        if ~isempty(worked) && ~printedWorkedExample
            fprintf('\n[run_hold_test] WORKED EXAMPLE, arm3, start day %d (hour %d, 18:00):\n', d, iStart);
            fprintf('  T_top at start (18:00) = %.4f C\n', Tw0);
            fprintf('  crosses target %.1f C during hold-hour k=%d: T(k-1)=%.4f C -> T(k)=%.4f C\n', tgt, worked{1}, worked{2}, worked{3});
            fprintf('  frac = (T(k-1) - target) / (T(k-1) - T(k)) = (%.4f - %.1f) / (%.4f - %.4f) = %.4f\n', ...
                worked{2}, tgt, worked{2}, worked{3}, worked{4});
            fprintf('  tau_hold = (k-1) + frac = %d + %.4f = %.4f h\n', worked{1}-1, worked{4}, worked{5});
            printedWorkedExample = true;
        end

        i24=min(24,holdHours); i36=min(36,holdHours); i48=min(48,holdHours);
        rows(end+1,:) = {nm, d, Tw0, tau, censored, trT(i24), trF(i24), trRec(i24), trT(i36), trF(i36), trRec(i36), trT(i48), trF(i48), trRec(i48)}; %#ok<AGROW>

        for th = thresholds
            if Tw0 < th
                hrows(end+1,:) = {nm, d, th, 0, false}; %#ok<AGROW>
                continue;
            end
            tt = NaN; pv = Tw0;
            for k = 1:holdHours
                if isnan(tt) && trT(k) < th
                    fr = 1; if pv > trT(k), fr = (pv-th)/(pv-trT(k)); end
                    tt = (k-1)+fr;
                    if strcmp(nm, 'arm3_pcm_SAC') && th == 30 && ~printedThreshExample
                        fprintf('\n[run_hold_test] WORKED EXAMPLE (threshold table), arm3, start day %d, threshold %.0f C (hour %d, 18:00):\n', d, th, iStart);
                        fprintf('  T_top at start (18:00) = %.4f C\n', Tw0);
                        fprintf('  crosses %.0f C during hold-hour k=%d: T(k-1)=%.4f C -> T(k)=%.4f C\n', th, k, pv, trT(k));
                        fprintf('  frac = (T(k-1) - threshold) / (T(k-1) - T(k)) = (%.4f - %.0f) / (%.4f - %.4f) = %.4f\n', pv, th, pv, trT(k), fr);
                        fprintf('  tau_hold = (k-1) + frac = %d + %.4f = %.4f h\n', k-1, fr, tt);
                        printedThreshExample = true;
                    end
                end
                pv = trT(k);
            end
            cz = isnan(tt); if cz, tt = holdHours; end
            hrows(end+1,:) = {nm, d, th, tt, cz}; %#ok<AGROW>
        end
    end
end

T = cell2table(rows, 'VariableNames', {'arm','start_day','T_top_start_C','tau_hold_h','censored', ...
    'T24_C','f24','Erec24_kWh','T36_C','f36','Erec36_kWh','T48_C','f48','Erec48_kWh'});
TH = cell2table(hrows, 'VariableNames', {'arm','start_day','threshold_C','tau_hold_h','censored'});

fprintf('\n=== Retention, regime 0, target %.1f C, cap %d h, %d start days ===\n', tgt, holdHours, numel(startDays));
armNames = unique(T.arm, 'stable');
for a = 1:numel(armNames)
    sel = strcmp(T.arm, armNames{a});
    fprintf('  %-14s mean tau_hold = %5.1f h  (%d of %d runs censored at %d h)\n', ...
        armNames{a}, mean(T.tau_hold_h(sel)), sum(T.censored(sel)), sum(sel), holdHours);
end

fprintf('\n=== Hold time by threshold (mean over %d start days) ===\n', numel(startDays));
fprintf('%-14s', 'arm'); for th=thresholds, fprintf('%12s', sprintf('%.0fC',th)); end; fprintf('\n');
for a = 1:numel(armNames)
    fprintf('%-14s', armNames{a});
    for th = thresholds
        sel = strcmp(TH.arm, armNames{a}) & TH.threshold_C == th;
        nc = sum(TH.censored(sel));
        fprintf('%12s', sprintf('%.1f%s', mean(TH.tau_hold_h(sel)), repmat('*',1,nc>0)));
    end
    fprintf('\n');
end
fprintf('  * = at least one run still above that threshold at the %d h cap.\n', holdHours);

writetable(T,  fullfile(OUT, sprintf('hold_test_r%d.csv', tw.params.regime_id)));
writetable(TH, fullfile(OUT, sprintf('hold_test_thresholds_r%d.csv', tw.params.regime_id)));
fprintf('\n[run_hold_test] tables -> %s/hold_test*.csv\n', exportDir);
end
