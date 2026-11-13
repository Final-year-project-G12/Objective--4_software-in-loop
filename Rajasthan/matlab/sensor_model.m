function [GHI_m, Tamb_m, s_m, sensors_ok] = sensor_model(GHI, T_amb, s, noise_on, hour_idx)
%SENSOR_MODEL  Measurement chain of the O4 interface spec (sensor_list in Objective 3's
% scripts/phase8_o4_handoff.py).
%
%   pyranometer      GHI       sigma = 10 W/m2 + 1 % of reading
%   ambient RTD      T_amb     sigma 0.3 C
%   tank-top RTD     T_top     sigma 0.2 C
%   tank-bottom RTD  T_bottom  sigma 0.2 C
%   mean of probes   T_mean    sigma 0.2 C
%   capsule TC       T_pcm     sigma 0.5 C
%   f_melt, E_stored, E_rec45  estimator outputs (not sensors) -- pass-through
%   dropout          1 % of hours a sensor frame is stale -> sensors_ok = 0
%                    and the safety interlock fails to BYPASS.
%
%   s = [T_top; T_bottom; T_mean; T_pcm; f_melt; E_stored_kWh; E_rec45_kWh]
%
% noise_on = 0 gives an ideal measurement chain (used for the validation against the
% Python simulator).
%#codegen
sensors_ok = 1;
s_m = s(:);
if noise_on > 0.5
    GHI_m  = max(GHI + (10 + 0.01 * GHI) * randn(), 0);
    Tamb_m = T_amb + 0.3 * randn();
    s_m(1) = s(1) + 0.2 * randn();
    s_m(2) = s(2) + 0.2 * randn();
    s_m(3) = s(3) + 0.2 * randn();
    s_m(4) = s(4) + 0.5 * randn();
    s_m(5) = min(max(s(5), 0), 1);
    if rand() < 0.01
        sensors_ok = 0;
    end
else
    GHI_m = GHI;  Tamb_m = T_amb;
end
% hour_idx is accepted so the block can be extended with time-correlated faults
end
