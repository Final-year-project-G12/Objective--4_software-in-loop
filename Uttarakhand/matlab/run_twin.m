function out = run_twin(tw, hours, noise_on, policy_mode, mdl)
%RUN_TWIN  Simulate the Simulink twin and return logged arrays.
%
%   out = run_twin(tw, hours, noise_on, policy_mode)
%     tw          struct from load_twin_params (or [] for regime 1)
%     hours       number of hours to simulate (default: all exported)
%     noise_on    0 ideal sensors (validation) | 1 noisy + 1 % dropout
%     policy_mode 0 PPO (frozen) | 1 B0 always-enable baseline
%
% The .slx is (re)built for tw's regime if it is missing or was built for
% another regime (the plant constants are compiled into it).
here = fileparts(mfilename('fullpath')); addpath(here);
if nargin < 1 || isempty(tw), tw = load_twin_params(twin_export_dir(1)); end
if nargin < 2 || isempty(hours), hours = tw.N; end
if nargin < 3, noise_on = 0; end
if nargin < 4, policy_mode = 0; end
if nargin < 5, mdl = 'pcm_drl_twin'; end
consts = fullfile(here, 'twin_consts.mat');
rebuild = ~isfile(fullfile(here, [mdl '.slx'])) || ~isfile(consts);
if ~rebuild
    c = load(consts, 'regime_built', 'mu', 'W1');
    rebuild = ~isfield(c, 'regime_built') || c.regime_built ~= tw.regime || ...
        numel(c.mu) ~= tw.n_obs || ~isequal(single(c.W1), single(tw.W1));   % other policy exported since
end
if rebuild
    if bdIsLoaded(mdl), close_system(mdl, 0); end
    build_pcm_twin_model(mdl, tw.regime);
end
load_system(mdl);
N = tw.K.N; NX = 2 * N + 10;

mws = get_param(mdl, 'ModelWorkspace');
assignin(mws, 'noise_on', noise_on);
assignin(mws, 'policy_mode', policy_mode);
assignin(mws, 'wx', tw.wx);
assignin(mws, 'x0', [tw.T0; tw.h0; initial_record(tw.T0, tw.h0, tw.K); tw.min_cap; 1]);
set_param(mdl, 'StopTime', num2str((hours - 1) * 3600));

clear safety_interlock
t0 = tic;
so = sim(mdl);
out.sim_wall_s = toc(t0);

py = so.get('plant_y'); ay = so.get('agent_y'); iy = so.get('il_y');
ac = so.get('act_y');   wx = so.get('wx_out'); ob = so.get('obs');
py = py(1:hours, :);
rec = py(:, NX + (1:21)); scv = py(:, NX + 21 + (1:8));
out.Tnodes = py(:, 1:N);
out.T_top = rec(:, 1); out.T_mean = rec(:, 2); out.Tpcm = rec(:, 3); out.f_melt = rec(:, 4);
out.T_bottom = rec(:, 20); out.E_del_Wh = rec(:, 12); out.Q_load_Wh = rec(:, 6); out.E_unmet_Wh = rec(:, 9);
out.draw_kg = rec(:, 10);
out.shield_w_s = scv(:, 1); out.shield_p_s = scv(:, 2); out.over_limit_s = scv(:, 3);
out.n_sw = scv(:, 4); out.n_sp = scv(:, 5); out.n_viol = scv(:, 6); out.pump_frac = scv(:, 7) / 3600;
out.a_policy = ay(1:hours, 1); out.margin = ay(1:hours, 2);
out.a_cmd = iy(1:hours, 1);    out.interlock = iy(1:hours, 2);
out.pump_on = ac(1:hours, 1);  out.bypass = ac(1:hours, 2);
out.GHI = wx(1:hours, 2);      out.T_amb = wx(1:hours, 3); out.hod = wx(1:hours, 4);
out.obs = ob(1:hours, :);
out.hours = hours;
out.delivered50_kWh = sum(out.E_del_Wh) / 1000;
out.shield_h = sum(out.shield_w_s + out.shield_p_s) / 3600;
out.over_limit_h = sum(out.over_limit_s) / 3600;
out.ms_per_decision = 1000 * out.sim_wall_s / hours;
fprintf('[twin] %d h  policy_mode=%d noise=%d : delivered(50 C) %.1f kWh, shield %.2f h, over-limit %.2f h, %.1f s wall (%.1f ms/h)\n', ...
    hours, policy_mode, noise_on, out.delivered50_kWh, out.shield_h, out.over_limit_h, out.sim_wall_s, out.ms_per_decision);
end
