function [GHI_m, Tamb_m, rec_m, sensors_ok] = sensor_model(GHI, T_amb, rec8, noise_on)
%SENSOR_MODEL  Measurement chain of the Uttarakhand O4 hand-off
% (results/o4_handoff/r<k>/hardware_interface_spec.json, "sensors").
%
%   pyranometer          GHI       sigma = 10 W/m2 + 1 % of reading
%   ambient sensor       T_amb     sigma 0.3 C
%   tank-top sensor      T_top     sigma 0.2 C   (outlet)
%   tank-bottom sensor   T_bottom  sigma 0.2 C   (collector return)
%   tank mean            T_mean    sigma 0.2 C   (average of the tank sensors)
%   PCM estimator        T_pcm     sigma 0.5 C   (measurable = false: estimator error)
%   f_melt, stored / recoverable energy   estimator outputs, pass-through
%   flow meter           draw_kg   pass-through
%   dropout              1 % of hours the frame is stale -> sensors_ok = 0
%
% rec8 = [T_top; T_bottom; T_mean; T_pcm; f_melt; draw_kg; E_stored_kWh; E_rec_kWh]
% noise_on = 0 gives an ideal chain (used for the validation against Python).
%#codegen
sensors_ok = 1;
rec_m = rec8(:);
if noise_on > 0.5
    GHI_m  = max(GHI + (10 + 0.01 * GHI) * randn(), 0);
    Tamb_m = T_amb + 0.3 * randn();
    rec_m(1) = rec8(1) + 0.2 * randn();
    rec_m(2) = rec8(2) + 0.2 * randn();
    rec_m(3) = rec8(3) + 0.2 * randn();
    rec_m(4) = rec8(4) + 0.5 * randn();
    rec_m(5) = min(max(rec8(5), 0), 1);
    if rand() < 0.01
        sensors_ok = 0;
    end
else
    GHI_m = GHI; Tamb_m = T_amb;
end
end
