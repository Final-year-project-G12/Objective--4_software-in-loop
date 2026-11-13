function [a_cmd, interlock_state] = safety_interlock(a_policy, Tw_m, Tpcm_m, sensors_ok, P)
%SAFETY_INTERLOCK  Hardware-level fail-safe that sits between the learned policy and the
% actuators ("fail_safe" rules of Objective 3's scripts/phase8_o4_handoff.py).
%
% The guard-band shield itself (72 C top water node / 62 C PCM) is evaluated inside the
% plant at every solver sub-step, exactly as in the Python environment, so the twin stays
% comparable with the simulator. This block adds the two rules that live outside the
% physics:
%
%   * stale / missing sensor frame        -> command BYPASS (safe default)
%   * hard limit exceeded despite shield  -> latch fault, BYPASS until a manual reset
%                                            (block re-init: "clear safety_interlock")
%
%   Tw_m    measured TOP-node water temperature [C]
%   Tpcm_m  measured (mean) PCM temperature [C]
%
% interlock_state: 0 normal, 1 guard band active (shield will fire this hour),
% 2 stale-sensor fail-safe, 3 latched hard-limit fault.
%#codegen
persistent fault_latched
if isempty(fault_latched), fault_latched = false; end

max_wC = P(32);  max_pC = P(33);  byp_wC = P(30);  byp_pC = P(31);
BYPASS = 2;

if Tw_m > max_wC || Tpcm_m > max_pC
    fault_latched = true;
end

if fault_latched
    a_cmd = BYPASS;  interlock_state = 3;
elseif sensors_ok < 0.5
    a_cmd = BYPASS;  interlock_state = 2;
else
    a_cmd = a_policy;
    if Tw_m >= byp_wC || Tpcm_m >= byp_pC
        interlock_state = 1;
    else
        interlock_state = 0;
    end
end
end
