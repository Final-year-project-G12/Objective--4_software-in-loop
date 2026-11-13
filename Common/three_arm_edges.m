function T = three_arm_edges(regime, exportRoot)
%THREE_ARM_EDGES  Deliverable (ii): the six edge cases, run for all three arms
% instead of only for the controller and B0.
%
% The state's own run_scenarios.m already does clear / no sunlight / rain /
% cold / heat wave / sensor fault for the PCM tank with the policy and with
% B0. That is arms 2 and 3. This adds arm 1, the plain tank, on the same
% weather, so each scenario answers three questions at once:
%   does the PCM help here, and does the AI help on top of the PCM?
%
% Window: 4 days spin-up, 4 days event, 2 days recovery, from 1 April, which
% is what run_scenarios uses, so the numbers line up with the existing tables.
%
% Usage, from the state's matlab/ folder:
%   addpath('../../Common');
%   T = three_arm_edges(1);

if nargin < 1 || isempty(regime),     regime = 1; end
if nargin < 2 || isempty(exportRoot), exportRoot = ''; end

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
Wall = tw.wx.signals.values;
tgt  = tw.K.P(4);

k0 = 90 * 24;  nWin = 10 * 24;              % 1 April, 10 days
base = Wall(k0 + (1:nWin), :);
iS = 4*24 + 1; iE = 8*24;
inEv = false(nWin, 1); inEv(iS:iE) = true;

K_pcm = tw.K; K_plain = make_plain(tw.K);

% --- the six scenarios, built by editing the real April weather ---------
sc = {};
sc{end+1} = struct('name','clear',           'W',base,            'dT_mains',0, 'noise',0, 'bo',false(nWin,1));
W = base; W(inEv,2) = 0;
sc{end+1} = struct('name','no_sunlight',     'W',W,               'dT_mains',0, 'noise',0, 'bo',false(nWin,1));
W = base; W(inEv,2) = min(0.12*base(inEv,2),120); W(inEv,3) = base(inEv,3) - 5;
sc{end+1} = struct('name','rain_cloud',      'W',W,               'dT_mains',0, 'noise',0, 'bo',false(nWin,1));
W = base; W(inEv,3) = base(inEv,3) - 12; W(inEv,2) = 0.9*base(inEv,2);
sc{end+1} = struct('name','low_temperature', 'W',W,               'dT_mains',-8,'noise',0, 'bo',false(nWin,1));
W = base; W(inEv,3) = base(inEv,3) + 9;  W(inEv,2) = 1.15*base(inEv,2);
sc{end+1} = struct('name','heat_wave',       'W',W,               'dT_mains',0, 'noise',0, 'bo',false(nWin,1));
bo = false(nWin,1); bo(iS:iS+11) = true;
sc{end+1} = struct('name','sensor_fault',    'W',base,            'dT_mains',0, 'noise',1, 'bo',bo);

arms = { struct('name','ARM1 plain + B0','K',K_plain,'mode',1), ...
         struct('name','ARM2 PCM + B0',  'K',K_pcm,  'mode',1), ...
         struct('name','ARM3 PCM + O3',  'K',K_pcm,  'mode',0) };

rng(7);                                      % same seed as run_scenarios
rows = {};
for s = 1:numel(sc)
    for a = 1:3
        K = arms{a}.K;
        K.P(3) = K.P(3) + sc{s}.dT_mains;    % colder mains for the cold case
        L = simulate_hours(tw, sc{s}.W, K, arms{a}.mode, sc{s}.noise, sc{s}.bo);
        ev = inEv;
        rows{end+1} = { sc{s}.name, arms{a}.name, ...
            sum(L.E_del_Wh(ev))/1000, sum(L.E_unmet_Wh(ev))/1000, ...
            sum(L.shield_w_s(ev)+L.shield_p_s(ev))/3600, sum(L.over_limit_s)/3600, ...
            min(L.T_top(ev)), max(L.T_top), max(L.T_pcm_max), ...
            max(L.f_melt(ev)), L.f_melt(iE), ...
            sum(L.in_window(ev) & L.T_top(ev) >= tgt), sum(L.interlock(ev) >= 2) };  %#ok<AGROW>
    end
end

T = cell2table(vertcat(rows{:}), 'VariableNames', { ...
    'scenario','arm','Edel_kWh','unmet_kWh','shield_h','over_limit_h', ...
    'Ttop_min_C','Ttop_max_C','Tpcm_max_C','f_melt_max','f_melt_end', ...
    'window_h_at_target','failsafe_h'});

fprintf('\n=== Six edge cases x three arms, regime %d, target %.0f C ===\n', regime, tgt);
disp(T);
fprintf('\nover_limit_h must be 0 in every row. f_melt_max shows whether the PCM\n');
fprintf('got anything stored at all - if it is 0 in a scenario, the PCM cannot\n');
fprintf('help there and arms 2 and 3 should match arm 1 apart from thermal mass.\n');

outCsv = fullfile(expDir, 'scenarios', sprintf('three_arm_edges_r%d.csv', regime));
if ~isfolder(fileparts(outCsv)), mkdir(fileparts(outCsv)); end
writetable(T, outCsv);
fprintf('[three_arm_edges] table -> %s\n', outCsv);
end
