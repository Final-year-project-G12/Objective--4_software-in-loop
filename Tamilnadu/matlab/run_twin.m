function out = run_twin(tw, hours, noise_on, policy_mode, mdl)
%RUN_TWIN  Simulate the Simulink twin and return logged arrays.
%
%   out = run_twin(tw, hours, noise_on, policy_mode)
%     tw          struct from load_twin_params (or [] to load defaults)
%     hours       number of hours to simulate (default: all exported)
%     noise_on    0 ideal sensors (validation) | 1 noisy + 1 % dropout
%     policy_mode 0 SAC (trained) | 1 B0 always-charge baseline
%
% Returns Nx1 arrays: Tw, Tpcm, f_melt, E_del_Wh, E_unmet_Wh, n_sw, n_sp,
% n_viol, a_exec, a_policy, a_cont, a_cmd, interlock_state, GHI, T_amb,
% draw_kg, pump_on, valve_bypass, and Nx11 obs.
here = fileparts(mfilename('fullpath'));
addpath(here);
if nargin < 1 || isempty(tw), tw = load_twin_params(); end
if nargin < 2 || isempty(hours), hours = tw.N; end
if nargin < 3, noise_on = 0; end
if nargin < 4, policy_mode = 0; end
if nargin < 5, mdl = 'pcm_drl_twin'; end
if ~isfile(fullfile(here, [mdl '.slx'])), build_pcm_twin_model(mdl); end
load_system(mdl);

mws = get_param(mdl, 'ModelWorkspace');
assignin(mws, 'noise_on', noise_on);
assignin(mws, 'policy_mode', policy_mode);
assignin(mws, 'wx', tw.wx);
assignin(mws, 'P', tw.P);
set_param(mdl, 'StopTime', num2str((hours - 1) * 3600));

t0 = tic;
so = sim(mdl);
out.sim_wall_s = toc(t0);

py = so.get('plant_y');  ay = so.get('agent_y');  iy = so.get('il_y');
ac = so.get('act_y');    wx = so.get('wx_out');
out.Tw = py(1:hours, 1);  out.Tpcm = py(1:hours, 2);  out.f_melt = py(1:hours, 4);
out.E_del_Wh = py(1:hours, 5);  out.E_unmet_Wh = py(1:hours, 6);
out.n_sw = py(1:hours, 7);  out.n_sp = py(1:hours, 8);  out.n_viol = py(1:hours, 9);
out.a_exec = py(1:hours, 10);
out.a_policy = ay(1:hours, 1);  out.a_cont = ay(1:hours, 2);
out.a_cmd = iy(1:hours, 1);     out.interlock_state = iy(1:hours, 2);
out.pump_on = ac(1:hours, 1);   out.valve_bypass = ac(1:hours, 2);
out.GHI = wx(1:hours, 2);       out.T_amb = wx(1:hours, 3);
out.draw_kg = so.get('draw_kg'); out.draw_kg = out.draw_kg(1:hours);
ob = so.get('obs');             out.obs = ob(1:hours, :);
out.hours = hours;
out.delivered_kWh = sum(out.E_del_Wh) / 1000;
out.unmet_kWh = sum(out.E_unmet_Wh) / 1000;
out.shields = sum(out.n_sw + out.n_sp);
out.violations = sum(out.n_viol);
out.ms_per_decision = 1000 * out.sim_wall_s / hours;
fprintf('[twin] %d h  policy_mode=%d noise=%d : delivered %.1f kWh, unmet %.1f kWh, shields %d, violations %d, %.1f s wall (%.2f ms/h)\n', ...
    hours, policy_mode, noise_on, out.delivered_kWh, out.unmet_kWh, out.shields, out.violations, out.sim_wall_s, out.ms_per_decision);
end
