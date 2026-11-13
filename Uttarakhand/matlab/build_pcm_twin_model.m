function mdl = build_pcm_twin_model(mdl, regime)
%BUILD_PCM_TWIN_MODEL  Programmatically build pcm_drl_twin.slx -- the Simulink
% software-in-the-loop twin of the Uttarakhand PCM solar water heater with the
% frozen Objective 3 PPO controller.
%
%   build_pcm_twin_model                     % regime 1 (O3 primary)
%   build_pcm_twin_model('pcm_drl_twin', 0)
%
% Signal flow (1 h discrete step, matches the RL environment):
%
%   Weather (From Workspace) -> Sensors + estimator (noise, dropout)
%        -> Observation (15 fields, frozen normalisation) -> RL policy (PPO MLP)
%        -> Safety interlock -> Collector-loop pump -> O2 multinode PCM tank
%        (10 nodes; state fed back through a unit delay) -> scopes + logging
%
% State vector carried by the unit delay (length 2N+10):
%   [T nodes (N); h nodes (N); T_top; T_bottom; T_mean; T_pcm; f_melt; draw_kg;
%    E_stored_kWh; E_rec_kWh; minutes_since_last_draw; prev_action]
%
% Each MATLAB Function block uses one input / one output port (signals packed
% with Mux, unpacked with Demux). Plant constants and PPO weights are loaded at
% compile time with coder.load('twin_consts.mat'); weather, initial state,
% noise switch and policy mode live in the MODEL WORKSPACE.
if nargin < 1 || isempty(mdl), mdl = 'pcm_drl_twin'; end
if nargin < 2 || isempty(regime), regime = 1; end
here = fileparts(mfilename('fullpath'));
slx  = fullfile(here, [mdl '.slx']);
tw   = load_twin_params(twin_export_dir(regime));
N    = tw.K.N;
NX   = 2 * N + 10;

if bdIsLoaded(mdl), close_system(mdl, 0); end
if isfile(slx), delete(slx); end
new_system(mdl);
set_param(mdl, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', ...
    'FixedStep', '3600', 'StopTime', num2str((tw.N - 1) * 3600), ...
    'ReturnWorkspaceOutputs', 'on', 'SaveFormat', 'Array');

set_workspace(mdl, tw, 0, 0);
% constants read by the MATLAB Function blocks via coder.load (compile time)
P = tw.K.P; m_w = tw.K.m_w; n_caps = tw.K.n_caps; loss_ua = tw.K.loss_ua; demand24 = tw.K.demand24; %#ok<NASGU>
coll = tw.K.coll; mu = tw.mu; sd = tw.sd; W1 = tw.W1; b1 = tw.b1; W2 = tw.W2; b2 = tw.b2; Wa = tw.Wa; ba = tw.ba; %#ok<NASGU>
draw_thr = tw.draw_thr; min_cap = tw.min_cap; regime_built = regime; %#ok<NASGU>
save(fullfile(here, 'twin_consts.mat'), 'P', 'm_w', 'n_caps', 'loss_ua', 'demand24', 'coll', 'mu', 'sd', ...
    'W1', 'b1', 'W2', 'b2', 'Wa', 'ba', 'draw_thr', 'min_cap', 'regime_built');
Kexpr = 'K = struct(''P'', C.P, ''m_w'', C.m_w, ''n_caps'', C.n_caps, ''loss_ua'', C.loss_ua, ''demand24'', C.demand24, ''coll'', C.coll, ''N'', numel(C.m_w));';

TS = '3600';
pos = @(c, r, w, h) [40 + 230 * c, 40 + 110 * r, 40 + 230 * c + w, 40 + 110 * r + h];
sizes = containers.Map( ...
    {'Sensors + estimator', 'Observation', 'RL Agent (PPO policy)', 'Safety interlock', 'Collector-loop pump', 'PCM tank (O2 multinode)'}, ...
    {[11 11], [13 15], [16 2], [10 2], [1 2], [5 + 2*N, NX + 29]});
MF = @(nm, scr, c, r) add_mf(mdl, nm, scr, pos(c, r, 170, 70), sizes(nm));

add_block('simulink/Sources/Constant', [mdl '/noise_on'],    'Value', 'noise_on',    'SampleTime', TS, 'Position', [300, 280, 360, 300]);
add_block('simulink/Sources/Constant', [mdl '/policy_mode'], 'Value', 'policy_mode', 'SampleTime', TS, 'Position', [1100, 380, 1160, 400]);

% ---------------- weather ----------------
add_block('simulink/Sources/From Workspace', [mdl '/Weather'], ...
    'VariableName', 'wx', 'SampleTime', TS, 'Interpolate', 'off', ...
    'OutputAfterFinalValue', 'Holding final value', 'Position', pos(0, 0, 120, 40));
add_block('simulink/Signal Routing/Demux', [mdl '/WxDemux'], 'Outputs', '[1 1 1 1]', 'Position', [300, 20, 305, 120]);
add_line(mdl, 'Weather/1', 'WxDemux/1');
add_block('simulink/Sinks/Terminator', [mdl '/IdxTerm'], 'Position', [340, 20, 350, 30]);
add_line(mdl, 'WxDemux/1', 'IdxTerm/1');
% WxDemux: 1 hour_idx, 2 GHI, 3 T_amb, 4 local_hour

% ---------------- state memory ----------------
add_block('simulink/Discrete/Unit Delay', [mdl '/StateMem'], 'InitialCondition', 'x0', ...
    'SampleTime', TS, 'Position', pos(0, 5, 70, 40));
add_block('simulink/Signal Routing/Demux', [mdl '/StateDemux'], 'Outputs', sprintf('[%d %d 8 1 1]', N, N), ...
    'Position', [160, 540, 165, 640]);
add_line(mdl, 'StateMem/1', 'StateDemux/1');
% StateDemux: 1 T nodes, 2 h nodes, 3 rec8, 4 minutes since draw, 5 prev action

% ---------------- sensors / estimator ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/SensorsMux'], 'Inputs', '3', 'Position', [300, 150, 305, 260]);
add_block('simulink/Signal Routing/Mux', [mdl '/WxMux'], 'Inputs', '2', 'Position', [250, 150, 255, 190]);
add_line(mdl, 'WxDemux/2', 'WxMux/1'); add_line(mdl, 'WxDemux/3', 'WxMux/2');
MF('Sensors + estimator', ['function y = f(u)' newline ...
    '[g, ta, r, ok] = sensor_model(u(1), u(2), u(3:10), u(11));' newline ...
    'y = [g; ta; r; ok];'], 2, 1);
add_line(mdl, 'WxMux/1', 'SensorsMux/1');
add_line(mdl, 'StateDemux/3', 'SensorsMux/2');
add_line(mdl, 'noise_on/1', 'SensorsMux/3');
add_line(mdl, 'SensorsMux/1', 'Sensors + estimator/1');
add_block('simulink/Signal Routing/Demux', [mdl '/SensorsDemux'], 'Outputs', '[1 1 8 1]', 'Position', [780, 150, 785, 260]);
add_line(mdl, 'Sensors + estimator/1', 'SensorsDemux/1');
% SensorsDemux: 1 GHI_m, 2 Tamb_m, 3 rec_m (8), 4 sensors_ok

% ---------------- observation ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/ObsMux'], 'Inputs', '6', 'Position', [880, 150, 885, 330]);
MF('Observation', ['function y = f(u)' newline ...
    'C = coder.load(''twin_consts.mat'');' newline ...
    'y = double(build_obs(u(1:8), u(9), u(10), round(u(11)), C.P(3), u(12), u(13), C.mu, C.sd));'], 3, 1);
add_line(mdl, 'SensorsDemux/3', 'ObsMux/1');
add_line(mdl, 'SensorsDemux/1', 'ObsMux/2');
add_line(mdl, 'SensorsDemux/2', 'ObsMux/3');
add_line(mdl, 'WxDemux/4',      'ObsMux/4');
add_line(mdl, 'StateDemux/4',   'ObsMux/5');
add_line(mdl, 'StateDemux/5',   'ObsMux/6');
add_line(mdl, 'ObsMux/1', 'Observation/1');

% ---------------- RL policy (PPO) ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/AgentMux'], 'Inputs', '2', 'Position', [1180, 150, 1185, 200]);
MF('RL Agent (PPO policy)', ['function y = f(u)' newline ...
    'C = coder.load(''twin_consts.mat'');' newline ...
    '[a, m] = ppo_policy(u(1:15), C.W1, C.b1, C.W2, C.b2, C.Wa, C.ba, u(16));' newline ...
    'y = [a; m];'], 4, 1);
add_line(mdl, 'Observation/1', 'AgentMux/1');
add_line(mdl, 'policy_mode/1', 'AgentMux/2');
add_line(mdl, 'AgentMux/1', 'RL Agent (PPO policy)/1');
add_block('simulink/Signal Routing/Demux', [mdl '/AgentDemux'], 'Outputs', '[1 1]', 'Position', [1230, 150, 1235, 200]);
add_line(mdl, 'RL Agent (PPO policy)/1', 'AgentDemux/1');
% AgentDemux: 1 a_policy, 2 logit margin

% ---------------- safety interlock ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/IlMux'], 'Inputs', '3', 'Position', [1300, 150, 1305, 250]);
MF('Safety interlock', ['function y = f(u)' newline ...
    'C = coder.load(''twin_consts.mat'');' newline ...
    '[a, s] = safety_interlock(u(1), u(2), u(5), u(10), C.P);' newline ...
    'y = [a; s];'], 5, 1);
add_line(mdl, 'AgentDemux/1',   'IlMux/1');
add_line(mdl, 'SensorsDemux/3', 'IlMux/2');      % u(2) = T_top_m, u(5) = T_pcm_m
add_line(mdl, 'SensorsDemux/4', 'IlMux/3');      % u(10) = sensors_ok
add_line(mdl, 'IlMux/1', 'Safety interlock/1');
add_block('simulink/Signal Routing/Demux', [mdl '/IlDemux'], 'Outputs', '[1 1]', 'Position', [1500, 150, 1505, 200]);
add_line(mdl, 'Safety interlock/1', 'IlDemux/1');
% IlDemux: 1 a_cmd, 2 interlock_state

% ---------------- actuator ----------------
MF('Collector-loop pump', ['function y = f(u)' newline ...
    'y = [double(u == 1); double(u == 0)];'], 6, 1);   % [pump enabled; bypass]
add_line(mdl, 'IlDemux/1', 'Collector-loop pump/1');

% ---------------- plant ----------------
add_block('simulink/Signal Routing/Mux', [mdl '/PlantMux'], 'Inputs', '7', 'Position', [1560, 300, 1565, 450]);
MF('PCM tank (O2 multinode)', ['function y = f(u)' newline ...
    'C = coder.load(''twin_consts.mat'');' newline Kexpr newline ...
    sprintf('N = %d;', N) newline ...
    '[T, h, rec, sc] = pcm_plant_hour(u(1), u(2), round(u(3)), u(4), u(6:5+N), u(6+N:5+2*N), K);' newline ...
    'ms = u(5);' newline ...
    'if rec(10) >= C.draw_thr, ms = 0; else, ms = min(ms + 60, C.min_cap); end' newline ...
    'y = [T; h; rec([1 20 2 3 4 10 18 19]); ms; u(4); rec; sc];'], 7, 3);
add_line(mdl, 'WxDemux/2',    'PlantMux/1');   % true GHI and ambient drive the physics
add_line(mdl, 'WxDemux/3',    'PlantMux/2');
add_line(mdl, 'WxDemux/4',    'PlantMux/3');
add_line(mdl, 'IlDemux/1',    'PlantMux/4');
add_line(mdl, 'StateDemux/4', 'PlantMux/5');
add_line(mdl, 'StateDemux/1', 'PlantMux/6');
add_line(mdl, 'StateDemux/2', 'PlantMux/7');
add_line(mdl, 'PlantMux/1', 'PCM tank (O2 multinode)/1');
add_block('simulink/Signal Routing/Demux', [mdl '/PlantDemux'], 'Outputs', sprintf('[%d 21 8]', NX), ...
    'Position', [1900, 300, 1905, 450]);
add_line(mdl, 'PCM tank (O2 multinode)/1', 'PlantDemux/1');
add_line(mdl, 'PlantDemux/1', 'StateMem/1');     % close the state loop
% PlantDemux: 1 next state, 2 kernel hourly record (21), 3 shield / limit counters (8)

% ---------------- logging ----------------
logs = { 'PCM tank (O2 multinode)/1', 'plant_y'; 'RL Agent (PPO policy)/1', 'agent_y'; ...
         'Safety interlock/1', 'il_y'; 'Observation/1', 'obs'; ...
         'Collector-loop pump/1', 'act_y'; 'Weather/1', 'wx_out'; 'Sensors + estimator/1', 'sens_y' };
for k = 1:size(logs, 1)
    nm = ['log_' logs{k, 2}];
    add_block('simulink/Sinks/To Workspace', [mdl '/' nm], 'VariableName', logs{k, 2}, ...
        'SaveFormat', 'Array', 'MaxDataPoints', 'inf', 'SampleTime', TS, ...
        'Position', [2100, 40 + 40 * k, 2190, 64 + 40 * k]);
    add_line(mdl, logs{k, 1}, [nm '/1']);
end

% ---------------- scopes ----------------
add_block('simulink/Signal Routing/Demux', [mdl '/RecDemux'], 'Outputs', '[1 1 1 1 17]', 'Position', [1960, 420, 1965, 520]);
add_line(mdl, 'PlantDemux/2', 'RecDemux/1');
add_block('simulink/Sinks/Terminator', [mdl '/RecTerm'], 'Position', [2000, 520, 2010, 530]);
add_line(mdl, 'RecDemux/5', 'RecTerm/1');
add_block('simulink/Signal Routing/Mux', [mdl '/TempMux'], 'Inputs', '3', 'Position', [2000, 420, 2005, 460]);
add_line(mdl, 'RecDemux/1', 'TempMux/1'); add_line(mdl, 'RecDemux/2', 'TempMux/2'); add_line(mdl, 'RecDemux/3', 'TempMux/3');
add_block('simulink/Sinks/Scope', [mdl '/Tank temperature (top, mean, PCM)'], 'Position', [2060, 420, 2110, 460]);
add_line(mdl, 'TempMux/1', 'Tank temperature (top, mean, PCM)/1');
add_block('simulink/Sinks/Scope', [mdl '/PCM melt fraction'], 'Position', [2060, 480, 2110, 520]);
add_line(mdl, 'RecDemux/4', 'PCM melt fraction/1');
add_block('simulink/Sinks/Scope', [mdl '/Controller action'], 'Position', [2060, 540, 2110, 580]);
add_line(mdl, 'IlDemux/1', 'Controller action/1');
add_block('simulink/Sinks/Terminator', [mdl '/IlTerm'], 'Position', [1560, 200, 1570, 210]);
add_line(mdl, 'IlDemux/2', 'IlTerm/1');
add_block('simulink/Sinks/Terminator', [mdl '/AgTerm'], 'Position', [1300, 260, 1310, 270]);
add_line(mdl, 'AgentDemux/2', 'AgTerm/1');
add_block('simulink/Sinks/Terminator', [mdl '/ScTerm'], 'Position', [1960, 560, 1970, 570]);
add_line(mdl, 'PlantDemux/3', 'ScTerm/1');

save_system(mdl, slx);
fprintf('[build] saved %s (Uttarakhand regime %d, %d nodes)\n', slx, regime, N);
end

% ----------------------------------------------------------------------
function set_workspace(mdl, tw, noise_on, policy_mode)
mws = get_param(mdl, 'ModelWorkspace');
x0 = [tw.T0; tw.h0; initial_record(tw.T0, tw.h0, tw.K); tw.min_cap; 1];
vars = struct('wx', tw.wx, 'x0', x0, 'noise_on', noise_on, 'policy_mode', policy_mode);
fn = fieldnames(vars);
for k = 1:numel(fn), assignin(mws, fn{k}, vars.(fn{k})); end
end

function blk = add_mf(parent, name, script, position, sz)
% MATLAB Function block with its default 1-in / 1-out ports and EXPLICIT port
% sizes (a fresh block otherwise inherits the output size from the input).
blk = add_block('simulink/User-Defined Functions/MATLAB Function', [parent '/' name], 'Position', position);
path = getfullname(blk);
rt = sfroot;
ch = rt.find('-isa', 'Stateflow.EMChart', 'Path', path);
ch.Script = script;
d = rt.find('-isa', 'Stateflow.Data', 'Path', path);
assert(~isempty(d), 'add_mf: no data found on %s', path);
for k = 1:numel(d)
    if strcmp(d(k).Scope, 'Input'),  d(k).Props.Array.Size = sprintf('%d', sz(1)); end
    if strcmp(d(k).Scope, 'Output'), d(k).Props.Array.Size = sprintf('%d', sz(2)); end
end
end
