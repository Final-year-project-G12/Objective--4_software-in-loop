function S = diagnose_substep(regime)
%DIAGNOSE_SUBSTEP  Where does the 0.080 % sub-step difference of check_energy_balance come from?
%
%   S = diagnose_substep(1);    % writes ../results_campaign/substep_attribution_r1.json
%
% Same runs as the sub-step test (always-charge, ideal sensors, year 2023, PureTemp 60 tank): 150 s against 75 s, and
% 75 s against 37.5 s. The hourly delivered energy of the two runs is subtracted and the difference is split by what the
% tank was doing that hour:
%   melting hours   the melt fraction changed during the hour or sits inside the melt band at either end
%   other hours     PCM entirely solid or entirely liquid all hour (sensible heat only)
% and by whether the collector loop ran. The same test is repeated for the water-only tank (no PCM at all), which has no
% phase change, so a difference there cannot come from melting. Nothing is relaxed: the 0.05 % gate is only reported against.
here = fileparts(mfilename('fullpath')); addpath(here);
if nargin < 1 || isempty(regime), regime = 1; end
tw = load_twin_params(fullfile(here, '..', sprintf('export_r%d', regime)), 2023);
W = tw.wx.signals.values(:, 1:4);
P = tw.P;  Pp = make_plain_tank(P);
gate = 0.05;

S = struct();
for arm = {'pcm', 'plain'}
    if strcmp(arm{1}, 'pcm'), Pa = P; else, Pa = Pp; end
    L = cell(1, 3);  dts = [Pa(6), Pa(6) / 2, Pa(6) / 4];
    for k = 1:3
        Pk = Pa;  Pk(6) = dts(k);
        L{k} = simulate_hours(tw, W, Pk, 1, 0, []);
    end
    for pair = [1 2; 2 3]'
        a = L{pair(1)};  b = L{pair(2)};
        d = b.E_del_Wh - a.E_del_Wh;                          % Wh, per hour (finer minus coarser)
        tot = sum(a.E_del_Wh);
        key = sprintf('%s_%gs_to_%gs', arm{1}, dts(pair(1)), dts(pair(2)));  key = strrep(key, '.', 'p');
        r.total_change_pct = (sum(b.E_del_Wh) - tot) / tot * 100;
        r.total_change_kWh = sum(d) / 1000;
        f0 = [0; a.f_melt(1:end-1)];
        inband = (a.f_melt > 1e-3 & a.f_melt < 1 - 1e-3) | (f0 > 1e-3 & f0 < 1 - 1e-3) | abs(a.f_melt - f0) > 1e-6 | ...
                 (b.f_melt > 1e-3 & b.f_melt < 1 - 1e-3);
        pump = a.Q_coll_Wh > 0;
        r.melting_hours = sum(inband);  r.other_hours = sum(~inband);
        r.diff_melting_hours_kWh = sum(d(inband)) / 1000;  r.diff_other_hours_kWh = sum(d(~inband)) / 1000;
        r.abs_diff_melting_hours_kWh = sum(abs(d(inband))) / 1000;  r.abs_diff_other_hours_kWh = sum(abs(d(~inband))) / 1000;
        r.diff_pump_on_hours_kWh = sum(d(pump)) / 1000;  r.diff_pump_off_hours_kWh = sum(d(~pump)) / 1000;
        r.share_of_total_from_melting_hours_pct = 100 * sum(d(inband)) / sum(d);
        r.gate_pct = gate;  r.gate_met = abs(r.total_change_pct) < gate;
        S.(key) = r;
        fprintf('[%s] %5.1f -> %5.1f s: annual change %+.4f %% (%+.3f kWh)  melting hours %d: %+.3f kWh   other hours %d: %+.3f kWh   pump-on %+.3f / off %+.3f kWh  gate %s\n', ...
            arm{1}, dts(pair(1)), dts(pair(2)), r.total_change_pct, r.total_change_kWh, r.melting_hours, r.diff_melting_hours_kWh, ...
            r.other_hours, r.diff_other_hours_kWh, r.diff_pump_on_hours_kWh, r.diff_pump_off_hours_kWh, ternary(r.gate_met, 'met', 'NOT met'));
    end
end
outDir = fullfile(here, '..', 'results_campaign');
fid = fopen(fullfile(outDir, sprintf('substep_attribution_r%d.json', regime)), 'w'); fwrite(fid, jsonencode(S, 'PrettyPrint', true)); fclose(fid);
end

function v = ternary(c, a, b)
if c, v = a; else, v = b; end
end
