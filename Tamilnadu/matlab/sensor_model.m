function [GHI_m, Tamb_m, Tw_m, Tpcm_m, f_m, sensors_ok] = ...
    sensor_model(GHI, T_amb, T_w, T_pcm, f_melt, noise_on, hour_idx)
%SENSOR_MODEL  Measurement chain of the O4 hardware spec (sensor_list in
% results/obj4_handoff/obj4_hardware_interface_spec_r0.json).
%
%   pyranometer   GHI    +/- 2 %  (sigma = 10 W/m2 + 1 % of reading)
%   ambient RTD   T_amb  sigma 0.3 C
%   tank-top RTD  T_w    sigma 0.2 C
%   capsule TC    T_pcm  sigma 0.5 C
%   f_melt        estimator output (not a sensor) -- pass-through
%   dropout       1 % of hours a sensor frame is stale -> sensors_ok = 0
%                 and the safety interlock fails to BYPASS.
%
% noise_on = 0 gives an ideal measurement chain (used for the
% bit-for-bit validation against the Python simulator).
%#codegen
sensors_ok = 1;
if noise_on > 0.5
    GHI_m  = max(GHI + (10 + 0.01 * GHI) * randn(), 0);
    Tamb_m = T_amb + 0.3 * randn();
    Tw_m   = T_w   + 0.2 * randn();
    Tpcm_m = T_pcm + 0.5 * randn();
    f_m    = min(max(f_melt, 0), 1);
    if rand() < 0.01
        sensors_ok = 0;
    end
else
    GHI_m = GHI; Tamb_m = T_amb; Tw_m = T_w; Tpcm_m = T_pcm; f_m = f_melt;
end
% hour_idx is accepted so the block can be extended with time-correlated faults
end
