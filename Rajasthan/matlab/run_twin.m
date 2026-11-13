function out = run_twin(tw, hours, noise_on, policy_mode, mdl)
%RUN_TWIN  Simulate the Rajasthan Simulink twin and return logged arrays.
%
%   out = run_twin(tw, hours, noise_on, policy_mode)
%     tw          struct from load_twin_params (or [] to load regime 1)
%     hours       number of hours to simulate (default: all exported)
%     noise_on    0 ideal sensors (validation) | 1 noisy + 1 % dropout
%     policy_mode 0 DQN (trained) | 1 B0 always-charge baseline
%
% Returns Nx1 arrays: Tw (top node), Tbot, Tmean, Tpcm, f_melt, E_del_Wh, E_unmet_Wh,
% n_sw, n_sp, n_viol, a_exec, a_policy, a_cmd, interlock_state, GHI, T_amb, draw_kg,
% pump_on, valve_bypass, Nx3 q and Nx17 obs.
%
% The plant vector and network weights are compiled into the model from
% twin_consts.mat, so the model is rebuilt whenever tw.regime differs from the regime
% it was built for.
here = fileparts(mfilename('fullpath'));
addpath(here);
if nargin < 1 || isempty(tw), tw = load_twin_params(); end
if nargin < 2 || isempty(hours), hours = tw.N; end
if nargin < 3, noise_on = 0; end
if nargin < 4, policy_mode = 0; end
if nargin < 5, mdl = 'pcm_drl_twin_rj'; end

rebuild = ~isfile(fullfile(here, [mdl '.slx'])) || ~isfile(fullfile(here, 'twin_consts.mat'));
if ~rebuild
    C = load(fullfile(here, 'twin_consts.mat'), 'regime_id');
    rebuild = ~isfield(C, 'regime_id') || C.regime_id ~= tw.regime;
end
if rebuild, build_pcm_twin_model(tw.regime, mdl, tw.year); end
load_system(mdl);

mws = get_param(mdl, 'ModelWorkspace');
assignin(mws, 'noise_on', noise_on);
assignin(mws, 'policy_mode', policy_mode);
assignin(mws, 'wx', tw.wx);
assignin(mws, 'x0', [tw.T0; tw.h0; tw.s0; 24]);
set_param(mdl, 'StopTime', num2str((hours - 1) * 3600));

t0 = tic;
so = sim(mdl);
out.sim_wall_s = toc(t0);

py = so.get('plant_y');  ay = so.get('agent_y');  iy = so.get('il_y');
ac = so.get('act_y');    wx = so.get('wx_out');
r = 1:hours;
out.Tw = py(r, 21);  out.Tbot = py(r, 22);  out.Tmean = py(r, 23);  out.Tpcm = py(r, 24);  out.f_melt = py(r, 25);
out.E_del_Wh = py(r, 28);  out.E_unmet_Wh = py(r, 29);
out.n_sw = py(r, 32);  out.n_sp = py(r, 33);  out.n_viol = py(r, 34);
out.a_exec = py(r, 35);
out.a_policy = ay(r, 1);  out.q = ay(r, 2:4);
out.a_cmd = iy(r, 1);     out.interlock_state = iy(r, 2);
out.pump_on = ac(r, 1);   out.valve_bypass = ac(r, 2);
out.GHI = wx(r, 2);       out.T_amb = wx(r, 3);
dk = so.get('draw_kg');   out.draw_kg = dk(r);
ob = so.get('obs');       out.obs = ob(r, :);
out.hours = hours;
out.delivered_kWh = sum(out.E_del_Wh) / 1000;
out.unmet_kWh = sum(out.E_unmet_Wh) / 1000;
out.shields = sum(out.n_sw + out.n_sp);
out.violations = sum(out.n_viol);
out.ms_per_decision = 1000 * out.sim_wall_s / hours;
fprintf('[twin] regime %d  %d h  policy_mode=%d noise=%d : delivered %.1f kWh, unmet %.1f kWh, shields %d, violations %d, %.1f s wall (%.2f ms/h)\n', ...
    tw.regime, hours, policy_mode, noise_on, out.delivered_kWh, out.unmet_kWh, out.shields, out.violations, out.sim_wall_s, out.ms_per_decision);
end
