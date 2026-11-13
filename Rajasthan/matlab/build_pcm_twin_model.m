function mdl = build_pcm_twin_model(regime, mdl, year)
%BUILD_PCM_TWIN_MODEL  Programmatically build pcm_drl_twin_rj.slx -- the Simulink
% software-in-the-loop twin of the Rajasthan PCM solar water heater with the trained
% DQN controller.
%
%   build_pcm_twin_model          % regime 1
%   build_pcm_twin_model(0)       % rebuild for regime 0 (the model is regime-specific)
%
% Signal flow (1 h discrete step, matches the RL environment):
%
%   Weather + forecast (From Workspace) -> Hot-water demand -> Sensors (noise, dropout)
%        -> Observation (17 fields) -> RL policy (DQN MLP, argmax) -> Safety interlock
%        -> Pump + bypass valve -> 10-node PCM tank plant (state fed back through a
%        unit delay) -> Outlet scopes + logging
%
% State carried by the unit delay (28 values):
%   1:10 node water temperature (bottom -> top)   11:20 node PCM enthalpy
%   21:27 derived tank state (T_top T_bottom T_mean T_pcm f_melt E_stored E_rec45)
%   28 hours since the last draw
%
% Each MATLAB Function block uses the default single input / single output port:
% signals are packed with a Mux and unpacked with a Demux. The plant vector P, the
% Q-network weights and the demand curve are compiled into the blocks from
% twin_consts.mat (coder.load), so the model must be rebuilt when the regime changes.
% NOT YET RUN: written without access to MATLAB, by following the Tamil Nadu builder.
if nargin < 1 || isempty(regime), regime = 1; end
if nargin < 2 || isempty(mdl), mdl = 'pcm_drl_twin_rj'; end
if nargin < 3 || isempty(year), year = 2023; end
here = fileparts(mfilename('fullpath'));
slx  = fullfile(here, [mdl '.slx']);
tw   = load_twin_params(fullfile(here, '..', sprintf('export_r%d', regime)), year);

if bdIsLoaded(mdl), close_system(mdl, 0); end
if isfile(slx), delete(slx); end
new_system(mdl);
set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', ...
    'FixedStep', '3600', 'StopTime', num2str((tw.N - 1) * 3600), ...
    'ReturnWorkspaceOutputs', 'on', 'SaveFormat', 'Array');

set_workspace(mdl, tw, 0, 0);
% constants read by the MATLAB Function blocks via coder.load (compile-time)
P = tw.P; demand24 = tw.demand24; W1 = tw.W1; b1 = tw.b1; W2 = tw.W2; b2 = tw.b2; W3 = tw.W3; b3 = tw.b3; %#ok<NASGU>
regime_id = regime; %#ok<NASGU>
save(fullfile(here, 'twin_consts.mat'), 'P', 'demand24', 'W1', 'b1', 'W2', 'b2', 'W3', 'b3', 'regime_id');
add_block('simulink/Sources/Constant', [mdl '/noise_on'],    'Value', 'noise_on',    'SampleTime', '3600', 'Position', [300, 280, 360, 300]);
add_block('simulink/Sources/Constant', [mdl '/policy_mode'], 'Value', 'policy_mode', 'SampleTime', '3600', 'Position', [1100, 380, 1160, 400]);

TS = '3600';
pos = @(c, r, w, h) [40 + 230 * c, 40 + 110 * r, 40 + 230 * c + w, 40 + 110 * r + h];
MF  = @(nm, scr, c, r) add_mf(mdl, nm, scr, pos(c, r, 170, 70));

% ---------------- weather + forecast ----------------
add_block('simulink/Sources/From Workspace', [mdl '/Weather'], ...
    'VariableName', 'wx', 'SampleTime', TS, 'Interpolate', 'off', ...
    'OutputAfterFinalValue', 'Holding final value', 'Position', pos(0, 0, 120, 40));
add_block('simulink/Signal Routing/Demux', [mdl '/WxDemux'], 'Outputs', '[1 1 1 1 4]', ...
    'Position', [300, 20, 305, 130]);
add_line(mdl, 'Weather/1', 'WxDemux/1');
% WxDemux: 1 hour_idx, 2 GHI, 3 T_amb, 4 local_hour, 5 [GHI+1h GHI+2h GHI+3h draw_next_h]

% ---------------- demand ----------------
MF('Demand', ['function y = f(u)' newline ...
    'C = coder.load(''twin_consts.mat'');' newline ...
    'y = C.demand24(mod(round(u), 24) + 1);'], 1, 2);
add_line(mdl, 'WxDemux/4', 'Demand/1');

% ---------------- state memory ----------------
add_block('simulink/Discrete/Unit Delay', [mdl '/StateMem'], 'InitialCondition', 'x0', ...
    'SampleTime', TS, 'Position', pos(0, 5, 70, 40));
add_block('simulink/Signal Routing/Demux', [mdl '/StateDemux'], 'Outputs', '[10 10 7 1]', ...
    'Position', [160, 540, 165, 640]);
add_line(mdl, 'StateMem/1', 'StateDemux/1');
% StateDemux: 1 T nodes (10), 2 h nodes (10), 3 derived state (7), 4 hours_since_draw

% ---------------- sensors ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/SensorsMux'], 'Inputs', '5', 'Position', [300, 150, 305, 260]);
MF('Sensors', ['function y = f(u)' newline ...
    '[a, b, sm, ok] = sensor_model(u(1), u(2), u(3:9), u(11), u(10));' newline ...
    'y = [a; b; sm; ok];'], 2, 1);
add_block('simulink/Signal Routing/Demux', [mdl '/SensorsDemux'], 'Outputs', '[1 1 7 1]', 'Position', [780, 150, 785, 260]);
add_line(mdl, 'WxDemux/2',    'SensorsMux/1');
add_line(mdl, 'WxDemux/3',    'SensorsMux/2');
add_line(mdl, 'StateDemux/3', 'SensorsMux/3');
add_line(mdl, 'WxDemux/1',    'SensorsMux/4');
add_line(mdl, 'noise_on/1',   'SensorsMux/5');
add_line(mdl, 'SensorsMux/1', 'Sensors/1');
add_line(mdl, 'Sensors/1', 'SensorsDemux/1');
% SensorsDemux: 1 GHI_m, 2 Tamb_m, 3 measured tank state (7), 4 sensors_ok

% ---------------- observation (17 fields, V3) ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/ObsMux'], 'Inputs', '7', 'Position', [880, 150, 885, 330]);
MF('Observation', ['function y = f(u)' newline ...
    'C = coder.load(''twin_consts.mat'');' newline ...
    'y = build_obs(u(1), u(2), u(3:9), u(10), mod(round(u(11)), 24), u(12) * 60, u(13:16), C.P);'], 3, 1);
add_line(mdl, 'SensorsDemux/1', 'ObsMux/1');
add_line(mdl, 'SensorsDemux/2', 'ObsMux/2');
add_line(mdl, 'SensorsDemux/3', 'ObsMux/3');
add_line(mdl, 'Demand/1',       'ObsMux/4');
add_line(mdl, 'WxDemux/4',      'ObsMux/5');
add_line(mdl, 'StateDemux/4',   'ObsMux/6');
add_line(mdl, 'WxDemux/5',      'ObsMux/7');
add_line(mdl, 'ObsMux/1', 'Observation/1');

% ---------------- RL policy (DQN) ----------------
MF('RL Agent (DQN policy)', ['function y = f(u)' newline ...
    'C = coder.load(''twin_consts.mat'');' newline ...
    '[a, q] = dqn_policy(u(1:17), C.W1, C.b1, C.W2, C.b2, C.W3, C.b3, u(18));' newline ...
    'y = [a; q];'], 4, 1);
add_block('simulink/Signal Routing/Mux', [mdl '/AgentMux'], 'Inputs', '2', 'Position', [1180, 150, 1185, 200]);
add_block('simulink/Signal Routing/Demux', [mdl '/AgentDemux'], 'Outputs', '[1 3]', 'Position', [1230, 150, 1235, 200]);
add_line(mdl, 'Observation/1', 'AgentMux/1');
add_line(mdl, 'policy_mode/1', 'AgentMux/2');
add_line(mdl, 'AgentMux/1', 'RL Agent (DQN policy)/1');
add_line(mdl, 'RL Agent (DQN policy)/1', 'AgentDemux/1');
% AgentDemux: 1 a_policy, 2 Q-values (3)
add_block('simulink/Sinks/Terminator', [mdl '/QTerm'], 'Position', [1260, 185, 1280, 205]);
add_line(mdl, 'AgentDemux/2', 'QTerm/1');

% ---------------- safety interlock ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/IlMux'], 'Inputs', '3', 'Position', [1300, 150, 1305, 250]);
MF('Safety interlock', ['function y = f(u)' newline ...
    'C = coder.load(''twin_consts.mat'');' newline ...
    '[a, s] = safety_interlock(u(1), u(2), u(5), u(9), C.P);' newline ...
    'y = [a; s];'], 5, 1);
add_block('simulink/Signal Routing/Demux', [mdl '/IlDemux'], 'Outputs', '[1 1]', 'Position', [1500, 150, 1505, 200]);
add_line(mdl, 'AgentDemux/1',   'IlMux/1');
add_line(mdl, 'SensorsDemux/3', 'IlMux/2');      % u(2) = T_top measured, u(5) = T_pcm measured
add_line(mdl, 'SensorsDemux/4', 'IlMux/3');
add_line(mdl, 'IlMux/1', 'Safety interlock/1');
add_line(mdl, 'Safety interlock/1', 'IlDemux/1');
% IlDemux: 1 a_cmd, 2 interlock_state
add_block('simulink/Sinks/Terminator', [mdl '/IlTerm'], 'Position', [1530, 185, 1550, 205]);
add_line(mdl, 'IlDemux/2', 'IlTerm/1');

% ---------------- actuators ----------------
MF('Pump + bypass valve', ['function y = f(u)' newline ...
    'y = [double(u == 0); double(u == 2)];'], 6, 1);
add_line(mdl, 'IlDemux/1', 'Pump + bypass valve/1');

% ---------------- plant ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/PlantMux'], 'Inputs', '6', 'Position', [1560, 300, 1565, 450]);
MF('PCM tank (10 nodes) + capsules', ['function y = f(u)' newline ...
    'C = coder.load(''twin_consts.mat'');' newline ...
    '[T, h, o] = pcm_plant_hour(u(1), u(2), u(3), u(4), u(5:14), u(15:24), C.P);' newline ...
    'y = [T; h; o];'], 7, 3);
add_line(mdl, 'WxDemux/2',    'PlantMux/1');   % raw (true) GHI and ambient drive the physics
add_line(mdl, 'WxDemux/3',    'PlantMux/2');
add_line(mdl, 'Demand/1',     'PlantMux/3');
add_line(mdl, 'IlDemux/1',    'PlantMux/4');
add_line(mdl, 'StateDemux/1', 'PlantMux/5');
add_line(mdl, 'StateDemux/2', 'PlantMux/6');
add_line(mdl, 'PlantMux/1', 'PCM tank (10 nodes) + capsules/1');
% plant output (38): 1:10 T, 11:20 h, 21:38 = y(1:18) of pcm_plant_hour

% ---------------- next state (closes the loop) ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/NextMux'], 'Inputs', '2', 'Position', [1900, 540, 1905, 640]);
MF('Next state', ['function y = f(u)' newline ...
    '% u(1:38) plant output, u(39) hours since the last draw' newline ...
    'if u(31) > 1e-3' newline ...
    '    hsd = 0;' newline ...
    'else' newline ...
    '    hsd = min(u(39) + 1, 24);' newline ...
    'end' newline ...
    'y = [u(1:27); hsd];'], 8, 5);
add_line(mdl, 'PCM tank (10 nodes) + capsules/1', 'NextMux/1');
add_line(mdl, 'StateDemux/4', 'NextMux/2');
add_line(mdl, 'NextMux/1', 'Next state/1');
add_line(mdl, 'Next state/1', 'StateMem/1');

% ---------------- logging ----------------
logs = { 'PCM tank (10 nodes) + capsules/1', 'plant_y'; 'RL Agent (DQN policy)/1', 'agent_y'; ...
         'Safety interlock/1', 'il_y'; 'Observation/1', 'obs'; ...
         'Pump + bypass valve/1', 'act_y'; 'Demand/1', 'draw_kg'; ...
         'Weather/1', 'wx_out'; 'Sensors/1', 'sens_y' };
for k = 1:size(logs, 1)
    nm = ['log_' logs{k, 2}];
    add_block('simulink/Sinks/To Workspace', [mdl '/' nm], 'VariableName', logs{k, 2}, ...
        'SaveFormat', 'Array', 'MaxDataPoints', 'inf', 'SampleTime', TS, ...
        'Position', [2300, 40 + 40 * k, 2390, 64 + 40 * k]);
    add_line(mdl, logs{k, 1}, [nm '/1']);
end

% ---------------- outlet scopes ----------------
add_block('simulink/Signal Routing/Selector', [mdl '/TempSel'], 'InputPortWidth', '38', 'IndexOptionArray', {'Index vector (dialog)'}, ...
    'IndexParamArray', {'[21 22 24]'}, 'Position', [2160, 420, 2200, 460]);
add_line(mdl, 'PCM tank (10 nodes) + capsules/1', 'TempSel/1');
add_block('simulink/Sinks/Scope', [mdl '/Outlet temperature (top, bottom, PCM)'], 'Position', [2230, 420, 2280, 460]);
add_line(mdl, 'TempSel/1', 'Outlet temperature (top, bottom, PCM)/1');
add_block('simulink/Signal Routing/Selector', [mdl '/EdelSel'], 'InputPortWidth', '38', 'IndexOptionArray', {'Index vector (dialog)'}, ...
    'IndexParamArray', {'28'}, 'Position', [2160, 480, 2200, 520]);
add_line(mdl, 'PCM tank (10 nodes) + capsules/1', 'EdelSel/1');
add_block('simulink/Sinks/Scope', [mdl '/Delivered energy'], 'Position', [2230, 480, 2280, 520]);
add_line(mdl, 'EdelSel/1', 'Delivered energy/1');
add_block('simulink/Sinks/Scope', [mdl '/Controller action'], 'Position', [2230, 540, 2280, 580]);
add_line(mdl, 'IlDemux/1', 'Controller action/1');

save_system(mdl, slx);
fprintf('[build] saved %s (regime %d)\n', slx, regime);
end

% ----------------------------------------------------------------------
function set_workspace(mdl, tw, noise_on, policy_mode)
mws = get_param(mdl, 'ModelWorkspace');
vars = struct('wx', tw.wx, 'x0', [tw.T0; tw.h0; tw.s0; 24], ...
    'noise_on', noise_on, 'policy_mode', policy_mode);
fn = fieldnames(vars);
for k = 1:numel(fn), assignin(mws, fn{k}, vars.(fn{k})); end
end

function blk = add_mf(parent, name, script, position)
% MATLAB Function block with its default 1-in / 1-out ports and EXPLICIT output
% size (a fresh block otherwise inherits the output size from the input).
sizes = containers.Map( ...
    {'Demand', 'Sensors', 'Observation', 'RL Agent (DQN policy)', 'Safety interlock', ...
     'Pump + bypass valve', 'PCM tank (10 nodes) + capsules', 'Next state'}, ...
    {1, 10, 17, 4, 2, 2, 38, 28});
sz = sizes(name);
blk = add_block('simulink/User-Defined Functions/MATLAB Function', [parent '/' name], ...
    'Position', position);
path = getfullname(blk);
rt = sfroot;
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', path);
ch.Script = script;
d = rt.find('-isa', 'Stateflow.Data', 'Path', path);
assert(~isempty(d), 'add_mf: no data found on %s', path);
for k = 1:numel(d)
    if strcmp(d(k).Scope, 'Output'), d(k).Props.Array.Size = sprintf('%d', sz); end
end
end
