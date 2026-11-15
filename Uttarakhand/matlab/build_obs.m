function [obs, raw] = build_obs(rec8, GHI, T_amb, hod, T_mains, min_since_draw, prev_action, mu, sd, ext4)
%BUILD_OBS  The observation of o3/env.py::_raw_obs (V1, 15 fields) or of
% o3/env_ext.py (V2, 19 fields), standardised with the FROZEN train-year
% normalisation (never live statistics).
%
%   rec8  [T_top; T_bottom; T_mean; T_pcm; f_melt; draw_kg; E_stored_kWh; E_rec_kWh]
%         from the previous hour (sensors / estimator)
%   GHI, T_amb, hod   the hour about to be decided (hour mean, as in training)
%   ext4  (V2 only) [GHI_ahead_1h; GHI_ahead_2h; GHI_ahead_3h; draw_next_hour_kg]
%         from smart_forecast.m and the draw schedule. Ignored when numel(mu) == 15.
%
% V1 field order (OBS_FIELDS): T_water_top, T_water_bottom, T_water_mean, T_pcm,
% f_melt, GHI, T_amb, hour_sin, hour_cos, draw_mass_kg_now, T_mains,
% store_energy_above_mains_kWh, recoverable_energy_above_target_kWh,
% minutes_since_last_draw, prev_action. V2 appends GHI_ahead_1h_Wm2,
% GHI_ahead_2h_Wm2, GHI_ahead_3h_Wm2, draw_next_hour_kg (normalised with the
% GHI / draw statistics, already inside mu / sd).
% Python builds the vector in float64, stores it as float32 and normalises in
% float32; the same is done here.
%#codegen
ang = 2.0 * pi * hod / 24.0;
n = numel(mu);                         % fixed at compile time (15 or 19)
rawd = zeros(n, 1);
rawd(1:15) = [rec8(1); rec8(2); rec8(3); rec8(4); rec8(5); GHI; T_amb; sin(ang); cos(ang); ...
              rec8(6); T_mains; rec8(7); rec8(8); min_since_draw; prev_action];
if n == 19
    rawd(16:19) = ext4(1:4);
end
raw = single(rawd);
obs = (raw - single(mu(:))) ./ single(sd(:));
end
