function [obs, raw] = build_obs(rec8, GHI, T_amb, hod, T_mains, min_since_draw, prev_action, mu, sd)
%BUILD_OBS  The 15-field observation of o3/env.py::_raw_obs, standardised with
% the FROZEN train-year normalisation (never live statistics).
%
%   rec8  [T_top; T_bottom; T_mean; T_pcm; f_melt; draw_kg; E_stored_kWh; E_rec_kWh]
%         from the previous hour (sensors / estimator)
%   GHI, T_amb, hod   the hour about to be decided (hour mean, as in training)
%
% Field order (OBS_FIELDS): T_water_top, T_water_bottom, T_water_mean, T_pcm,
% f_melt, GHI, T_amb, hour_sin, hour_cos, draw_mass_kg_now, T_mains,
% store_energy_above_mains_kWh, recoverable_energy_above_target_kWh,
% minutes_since_last_draw, prev_action.
% Python builds the vector in float64, stores it as float32 and normalises in
% float32; the same is done here.
%#codegen
ang = 2.0 * pi * hod / 24.0;
rawd = [rec8(1); rec8(2); rec8(3); rec8(4); rec8(5); GHI; T_amb; sin(ang); cos(ang); ...
        rec8(6); T_mains; rec8(7); rec8(8); min_since_draw; prev_action];
raw = single(rawd);
obs = (raw - single(mu(:))) ./ single(sd(:));
end
