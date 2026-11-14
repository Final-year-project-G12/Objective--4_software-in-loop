function [a_cmd, interlock_state] = safety_interlock(a_policy, Tw_m, Tpcm_m, sensors_ok, P)
%SAFETY_INTERLOCK  Hardware-level fail-safe that sits between the learned
% policy and the actuators (obj4_hardware_interface_spec_r0.json, "fail_safe").
%
% The guard-band shield itself (72 C water / 62 C PCM) is evaluated inside
% the plant at every 150 s solver sub-step -- the twin's analogue of the
% 10 s hardware control cycle -- exactly as in the Python environment, so the
% twin stays bit-for-bit comparable with the simulator. This block adds the
% two rules that live outside the physics:
%
%   * stale / missing sensor frame        -> command BYPASS (safe default)
%   * hard limit exceeded despite shield  -> latch fault, BYPASS until a
%                                            manual reset (block re-init)
%
% interlock_state: 0 normal, 1 guard band active (shield will fire this
% hour), 2 stale-sensor fail-safe, 3 latched hard-limit fault.
%#codegen
persistent fault_latched
if isempty(fault_latched), fault_latched = false; end

if ischar(a_policy) && strcmp(a_policy, 'set_latch')
    fault_latched = logical(Tw_m);
    a_cmd = NaN; interlock_state = NaN;
    return;
end
if ischar(a_policy) && strcmp(a_policy, 'get_latch')
    a_cmd = double(fault_latched); interlock_state = NaN;
    return;
end

max_wC = P(29); max_pC = P(30); byp_wC = P(32); byp_pC = P(33);
BYPASS = 2;

if Tw_m > max_wC || Tpcm_m > max_pC
    fault_latched = true;
end

if fault_latched
    a_cmd = BYPASS; interlock_state = 3;
elseif sensors_ok < 0.5
    a_cmd = BYPASS; interlock_state = 2;
else
    a_cmd = a_policy;
    if Tw_m >= byp_wC || Tpcm_m >= byp_pC
        interlock_state = 1;
    else
        interlock_state = 0;
    end
end
end
