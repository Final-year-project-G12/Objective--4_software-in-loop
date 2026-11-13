function [a_cmd, interlock_state] = safety_interlock(a_policy, Ttop_m, Tpcm_m, sensors_ok, P)
%SAFETY_INTERLOCK  Fail-safe between the learned policy and the collector-loop pump
% (Uttarakhand hardware_interface_spec.json, "fail_safe" and
% "independent_hardware_interlock").
%
% The guard-band shield itself (pump off at top node >= 72 C, PCM exchange cut
% at 62 C) is evaluated inside the plant at every solver sub-step, exactly as
% in O2's kernel, so the twin stays comparable with the simulator. This block
% adds the rules that live outside the physics:
%
%   * stale / missing sensor frame       -> fall back to B0 = ENABLE (hand-off
%                                           spec: "sensor_or_policy_fault: fall
%                                           back to B0 (always enable) under the
%                                           interlock"; the in-plant shield still
%                                           protects the tank)
%   * hard limit exceeded despite shield -> latch a fault, BYPASS (pump off)
%                                           until a manual reset (block re-init)
%
% NOTE: this differs from the Tamil Nadu twin, whose spec fails to BYPASS.
%
% interlock_state: 0 normal, 1 guard band reached (shield will act this hour),
%                  2 stale-sensor fail-safe (B0), 3 latched hard-limit fault.
% P is the kernel parameter vector (30 bypass_water, 31 bypass_pcm,
% 32 max_water, 33 max_pcm).
%#codegen
persistent fault_latched
if isempty(fault_latched), fault_latched = false; end

byp_w = P(30); byp_p = P(31); max_w = P(32); max_p = P(33);
BYPASS = 0; ENABLE = 1;

if Ttop_m > max_w || Tpcm_m > max_p
    fault_latched = true;
end

if fault_latched
    a_cmd = BYPASS; interlock_state = 3;
elseif sensors_ok < 0.5
    a_cmd = ENABLE; interlock_state = 2;
else
    a_cmd = a_policy;
    if Ttop_m >= byp_w || Tpcm_m >= byp_p
        interlock_state = 1;
    else
        interlock_state = 0;
    end
end
end
