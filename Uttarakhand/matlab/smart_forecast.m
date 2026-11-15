function [ghi_fc, kc] = smart_forecast(GHI_now, cs_now, cs_ahead, kc_prev)
%SMART_FORECAST  Smart-persistence GHI forecast on the clear-sky index, the
% forecast the recommended Objective 3 agent was trained with
% (o3/env_ext.py, forecast_mode = "smart"; O3 FINDINGS 9.6, Inman et al. 2013):
%
%   Kc(t)          = clip(GHI(t) / GHI_cs(t), 0, 1.2)   while GHI_cs(t) > 20 W/m2
%                  = Kc of the last daytime hour         otherwise (1.0 before the first one)
%   GHI_hat(t + h) = Kc(t) * GHI_cs(t + h),   h = 1, 2, 3
%
%   GHI_now    GHI of the decision hour (on a device: the measured hourly mean)
%   cs_now     clear-sky GHI of the decision hour
%   cs_ahead   [3 x 1] clear-sky GHI of the next 3 hours; NaN past the end of
%              the year -> forecast 0 (as Python)
%   kc_prev    Kc carried from the previous hour (1.0 at reset)
%
% Clear-sky GHI is solar geometry and known in advance. The twin reads it from
% the weather export (NASA POWER GHI_clearsky_Wm2, the column O3 used); a real
% controller computes the same envelope on the device.
%#codegen
KC_LO = 0.0; KC_HI = 1.2; CS_DAY = 20.0;
kc = kc_prev;
if cs_now > CS_DAY
    kc = min(max(GHI_now / cs_now, KC_LO), KC_HI);
end
ghi_fc = zeros(3, 1);
for k = 1:3
    if ~isnan(cs_ahead(k))
        ghi_fc(k) = kc * cs_ahead(k);
    end
end
end
