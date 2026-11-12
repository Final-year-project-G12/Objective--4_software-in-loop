function mdl = build_pcm_twin_model(mdl, year)
%BUILD_PCM_TWIN_MODEL  Programmatically build pcm_drl_twin.slx -- the
% Simulink software-in-the-loop twin of the Tamil Nadu PCM solar water
% heater with the trained SAC controller.
%
% Signal flow (1 h discrete step, matches the RL environment):
%
%   Weather (From Workspace) -> Hot-water demand -> Sensors (noise, dropout)
%        -> Observation (11-dim) -> RL policy (SAC MLP) -> Safety interlock
%        -> Pump + bypass valve -> PCM tank plant (state fed back through a
%        unit delay) -> Outlet scopes + logging
%
% Each MATLAB Function block uses the default single input / single output
% port: signals are packed with a Mux and unpacked with a Demux. All
% parameters (plant vector P, SAC weights, demand curve, initial state,
% weather) live in the MODEL WORKSPACE, so the .slx is self-contained.
if nargin < 1 || isempty(mdl), mdl = 'pcm_drl_twin'; end
if nargin < 2, year = 2011; end
here = fileparts(mfilename('fullpath'));
slx  = fullfile(here, [mdl '.slx']);
tw   = load_twin_params([], year);

if bdIsLoaded(mdl), close_system(mdl, 0); end
if isfile(slx), delete(slx); end
new_system(mdl);
set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', ...
    'FixedStep', '3600', 'StopTime', num2str((tw.N - 1) * 3600), ...
    'ReturnWorkspaceOutputs', 'on', 'SaveFormat', 'Array');

set_workspace(mdl, tw, 0, 0);
% constants read by the MATLAB Function blocks via coder.load (compile-time)
P = tw.P; demand24 = tw.demand24; W1 = tw.W1; b1 = tw.b1; W2 = tw.W2; b2 = tw.b2; Wmu = tw.Wmu; bmu = tw.bmu; %#ok<NASGU>
save(fullfile(here, 'twin_consts.mat'), 'P', 'demand24', 'W1', 'b1', 'W2', 'b2', 'Wmu', 'bmu');
add_block('simulink/Sources/Constant', [mdl '/noise_on'],    'Value', 'noise_on',    'SampleTime', '3600', 'Position', [300, 280, 360, 300]);
add_block('simulink/Sources/Constant', [mdl '/policy_mode'], 'Value', 'policy_mode', 'SampleTime', '3600', 'Position', [1100, 380, 1160, 400]);

TS = '3600';
pos = @(c, r, w, h) [40 + 230 * c, 40 + 110 * r, 40 + 230 * c + w, 40 + 110 * r + h];
MF  = @(nm, scr, c, r) add_mf(mdl, nm, scr, pos(c, r, 170, 70));

% ---------------- weather ----------------
add_block('simulink/Sources/From Workspace', [mdl '/Weather'], ...
    'VariableName', 'wx', 'SampleTime', TS, 'Interpolate', 'off', ...
    'OutputAfterFinalValue', 'Holding final value', 'Position', pos(0, 0, 120, 40));
add_block('simulink/Signal Routing/Demux', [mdl '/WxDemux'], 'Outputs', '[1 1 1 1]', ...
    'Position', [300, 20, 305, 120]);
add_line(mdl, 'Weather/1', 'WxDemux/1');
% WxDemux: 1 hour_idx, 2 GHI, 3 T_amb, 4 local_hour

% ---------------- demand ----------------
MF('Demand', ['function y = f(u)' newline ...
    'C = coder.load(''twin_consts.mat'');' newline ...
    'y = C.demand24(mod(round(u), 24) + 1);'], 1, 2);
add_line(mdl, 'WxDemux/4', 'Demand/1');

% ---------------- state memory: [Tw Tpcm h f prev_action] ----------------
add_block('simulink/Discrete/Unit Delay', [mdl '/StateMem'], 'InitialCondition', 'x0', ...
    'SampleTime', TS, 'Position', pos(0, 5, 70, 40));
add_block('simulink/Signal Routing/Demux', [mdl '/StateDemux'], 'Outputs', '[1 1 1 1 1]', ...
    'Position', [160, 540, 165, 640]);
add_line(mdl, 'StateMem/1', 'StateDemux/1');
% StateDemux: 1 Tw, 2 Tpcm, 3 h, 4 f, 5 prev_action

% ---------------- sensors ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/SensorsMux'], 'Inputs', '7', 'Position', [300, 150, 305, 260]);
MF('Sensors', ['function y = f(u)' newline ...
    '[a, b, c, d, e, ok] = sensor_model(u(1), u(2), u(3), u(4), u(5), u(7), u(6));' newline ...
    'y = [a; b; c; d; e; ok];'], 2, 1);
add_block('simulink/Signal Routing/Demux', [mdl '/SensorsDemux'], 'Outputs', '[1 1 1 1 1 1]', 'Position', [780, 150, 785, 260]);
add_line(mdl, 'WxDemux/2', 'SensorsMux/1');
add_line(mdl, 'WxDemux/3', 'SensorsMux/2');
add_line(mdl, 'StateDemux/1', 'SensorsMux/3');
add_line(mdl, 'StateDemux/2', 'SensorsMux/4');
add_line(mdl, 'StateDemux/4', 'SensorsMux/5');
add_line(mdl, 'WxDemux/1', 'SensorsMux/6');
add_line(mdl, 'noise_on/1', 'SensorsMux/7');
add_line(mdl, 'SensorsMux/1', 'Sensors/1');
add_line(mdl, 'Sensors/1', 'SensorsDemux/1');
% SensorsDemux: 1 GHI_m, 2 Tamb_m, 3 Tw_m, 4 Tpcm_m, 5 f_m, 6 sensors_ok

% ---------------- observation (11-dim V1) ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/ObsMux'], 'Inputs', '9', 'Position', [880, 150, 885, 330]);
MF('Observation', ['function y = f(u)' newline ...
    'C = coder.load(''twin_consts.mat'');' newline ...
    'y = build_obs(u(1), u(2), u(3), u(4), u(5), u(6), u(7), u(8), u(9), C.P);'], 3, 1);
add_line(mdl, 'SensorsDemux/1', 'ObsMux/1');
add_line(mdl, 'SensorsDemux/2', 'ObsMux/2');
add_line(mdl, 'SensorsDemux/3', 'ObsMux/3');
add_line(mdl, 'SensorsDemux/4', 'ObsMux/4');
add_line(mdl, 'SensorsDemux/5', 'ObsMux/5');
add_line(mdl, 'Demand/1',       'ObsMux/6');
add_line(mdl, 'WxDemux/4',      'ObsMux/7');
add_line(mdl, 'WxDemux/1',      'ObsMux/8');
add_line(mdl, 'StateDemux/5',   'ObsMux/9');
add_line(mdl, 'ObsMux/1', 'Observation/1');

% ---------------- RL policy (SAC) ----------------
MF('RL Agent (SAC policy)', ['function y = f(u)' newline ...
    'C = coder.load(''twin_consts.mat'');' newline ...
    '[a, ac] = sac_policy(u(1:11), C.W1, C.b1, C.W2, C.b2, C.Wmu, C.bmu, u(12));' newline ...
    'y = [a; ac];'], 4, 1);
add_block('simulink/Signal Routing/Demux', [mdl '/AgentDemux'], 'Outputs', '[1 1]', 'Position', [1230, 150, 1235, 200]);
add_block('simulink/Signal Routing/Mux', [mdl '/AgentMux'], 'Inputs', '2', 'Position', [1180, 150, 1185, 200]);
add_line(mdl, 'Observation/1', 'AgentMux/1');
add_line(mdl, 'policy_mode/1', 'AgentMux/2');
add_line(mdl, 'AgentMux/1', 'RL Agent (SAC policy)/1');
add_line(mdl, 'RL Agent (SAC policy)/1', 'AgentDemux/1');
% AgentDemux: 1 a_policy, 2 a_cont

% ---------------- safety interlock ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/IlMux'], 'Inputs', '4', 'Position', [1300, 150, 1305, 250]);
MF('Safety interlock', ['function y = f(u)' newline ...
    'C = coder.load(''twin_consts.mat'');' newline ...
    '[a, s] = safety_interlock(u(1), u(2), u(3), u(4), C.P);' newline ...
    'y = [a; s];'], 5, 1);
add_block('simulink/Signal Routing/Demux', [mdl '/IlDemux'], 'Outputs', '[1 1]', 'Position', [1500, 150, 1505, 200]);
add_line(mdl, 'AgentDemux/1',   'IlMux/1');
add_line(mdl, 'SensorsDemux/3', 'IlMux/2');
add_line(mdl, 'SensorsDemux/4', 'IlMux/3');
add_line(mdl, 'SensorsDemux/6', 'IlMux/4');
add_line(mdl, 'IlMux/1', 'Safety interlock/1');
add_line(mdl, 'Safety interlock/1', 'IlDemux/1');
% IlDemux: 1 a_cmd, 2 interlock_state

% ---------------- actuators ----------------
MF('Pump + bypass valve', ['function y = f(u)' newline ...
    'y = [double(u == 0); double(u == 2)];'], 6, 1);
add_line(mdl, 'IlDemux/1', 'Pump + bypass valve/1');

% ---------------- plant ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/PlantMux'], 'Inputs', '8', 'Position', [1560, 300, 1565, 450]);
MF('PCM tank + capsules', ['function y = f(u)' newline ...
    'C = coder.load(''twin_consts.mat'');' newline ...
    '[Tw, Tp, h, f, Ed, Eu, nsw, nsp, nv, ae] = pcm_plant_hour(u(1), u(2), u(3), u(4), u(5), u(6), u(7), u(8), C.P);' newline ...
    'y = [Tw; Tp; h; f; Ed; Eu; nsw; nsp; nv; ae];'], 7, 3);
add_block('simulink/Signal Routing/Demux', [mdl '/PlantDemux'], 'Outputs', '[1 1 1 1 1 1 1 1 1 1]', 'Position', [1900, 300, 1905, 450]);
add_line(mdl, 'WxDemux/2',    'PlantMux/1');   % raw (true) GHI and ambient drive the physics
add_line(mdl, 'WxDemux/3',    'PlantMux/2');
add_line(mdl, 'Demand/1',     'PlantMux/3');
add_line(mdl, 'IlDemux/1',    'PlantMux/4');
add_line(mdl, 'StateDemux/1', 'PlantMux/5');
add_line(mdl, 'StateDemux/2', 'PlantMux/6');
add_line(mdl, 'StateDemux/3', 'PlantMux/7');
add_line(mdl, 'StateDemux/4', 'PlantMux/8');
add_line(mdl, 'PlantMux/1', 'PCM tank + capsules/1');
add_line(mdl, 'PCM tank + capsules/1', 'PlantDemux/1');
% PlantDemux: 1 Tw 2 Tpcm 3 h 4 f 5 E_del 6 E_unmet 7 n_sw 8 n_sp 9 n_viol 10 a_exec

% close the state loop
add_block('simulink/Signal Routing/Mux', [mdl '/StateMux'], 'Inputs', '5', 'Position', [1960, 540, 1965, 640]);
add_line(mdl, 'PlantDemux/1', 'StateMux/1');
add_line(mdl, 'PlantDemux/2', 'StateMux/2');
add_line(mdl, 'PlantDemux/3', 'StateMux/3');
add_line(mdl, 'PlantDemux/4', 'StateMux/4');
add_line(mdl, 'IlDemux/1',    'StateMux/5');
add_line(mdl, 'StateMux/1', 'StateMem/1');

% ---------------- logging ----------------
logs = { 'PCM tank + capsules/1', 'plant_y'; 'RL Agent (SAC policy)/1', 'agent_y'; ...
         'Safety interlock/1', 'il_y'; 'Observation/1', 'obs'; ...
         'Pump + bypass valve/1', 'act_y'; 'Demand/1', 'draw_kg'; ...
         'Weather/1', 'wx_out'; 'Sensors/1', 'sens_y' };
for k = 1:size(logs, 1)
    nm = ['log_' logs{k, 2}];
    add_block('simulink/Sinks/To Workspace', [mdl '/' nm], 'VariableName', logs{k, 2}, ...
        'SaveFormat', 'Array', 'MaxDataPoints', 'inf', 'SampleTime', TS, ...
        'Position', [2100, 40 + 40 * k, 2190, 64 + 40 * k]);
    add_line(mdl, logs{k, 1}, [nm '/1']);
end

% ---------------- outlet scopes ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/TempMux'], 'Inputs', '2', 'Position', [2000, 420, 2005, 460]);
add_line(mdl, 'PlantDemux/1', 'TempMux/1'); add_line(mdl, 'PlantDemux/2', 'TempMux/2');
add_block('simulink/Sinks/Scope', [mdl '/Outlet temperature (water, PCM)'], 'Position', [2060, 420, 2110, 460]);
add_line(mdl, 'TempMux/1', 'Outlet temperature (water, PCM)/1');
add_block('simulink/Sinks/Scope', [mdl '/Delivered energy'], 'Position', [2060, 480, 2110, 520]);
add_line(mdl, 'PlantDemux/5', 'Delivered energy/1');
add_block('simulink/Sinks/Scope', [mdl '/Controller action'], 'Position', [2060, 540, 2110, 580]);
add_line(mdl, 'IlDemux/1', 'Controller action/1');

save_system(mdl, slx);
fprintf('[build] saved %s\n', slx);
end

% ----------------------------------------------------------------------
function set_workspace(mdl, tw, noise_on, policy_mode)
mws = get_param(mdl, 'ModelWorkspace');
vars = struct('P', tw.P, 'wx', tw.wx, 'demand24', tw.demand24, ...
    'W1', tw.W1, 'b1', tw.b1, 'W2', tw.W2, 'b2', tw.b2, 'Wmu', tw.Wmu, 'bmu', tw.bmu, ...
    'x0', [tw.Tw0; tw.Tpcm0; tw.h0; tw.f0; 0], ...
    'noise_on', noise_on, 'policy_mode', policy_mode);
fn = fieldnames(vars);
for k = 1:numel(fn), assignin(mws, fn{k}, vars.(fn{k})); end
end

function blk = add_mf(parent, name, script, position)
% MATLAB Function block with its default 1-in / 1-out ports and EXPLICIT
% port sizes (a fresh block otherwise inherits the output size from the input).
sizes = containers.Map( ...
    {'Demand', 'Sensors', 'Observation', 'RL Agent (SAC policy)', 'Safety interlock', ...
     'Pump + bypass valve', 'PCM tank + capsules'}, ...
    {[1 1], [7 6], [9 11], [12 2], [4 2], [1 2], [8 10]});
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
    if strcmp(d(k).Scope, 'Output'), d(k).Props.Array.Size = sprintf('%d', sz(2)); end
end
end
