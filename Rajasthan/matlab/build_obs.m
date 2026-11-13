function obs = build_obs(I_t, T_amb, s, draw_kg, hod, min_since_draw, fwd, P)
%BUILD_OBS  Assemble the 17-field "V3" observation (o3/environment/obs.py::build) and
% apply the gym wrapper's clip to [-5, 5].
%
%   I_t, T_amb        measured GHI [W/m2] and ambient temperature [C]
%   s                 [7x1] measured/estimated tank state:
%                     T_top, T_bottom, T_mean, T_pcm, f_melt, E_stored_kWh, E_rec45_kWh
%   draw_kg           hot-water draw of the current hour [kg]
%   hod               local hour of day (0..23)
%   min_since_draw    minutes since the last draw (capped at 1440 by the caller)
%   fwd               [4x1] GHI of the next 1, 2, 3 hours [W/m2] and the next-hour draw [kg]
%
% Normalisation constants are the FIXED ones of obs.py, never live statistics.
% Tamil Nadu's twin used an 11-field observation; this is the Rajasthan contract layout.
%#codegen
T_mains = P(3);  lo = P(40);  hi = P(41);
raw = [ (s(1) - 30) / 40;            %  0 T_water_top
        (s(2) - 30) / 40;            %  1 T_water_bottom
        (s(3) - 30) / 40;            %  2 T_water_mean
        (s(4) - 30) / 40;            %  3 T_pcm
        s(5);                        %  4 f_melt
        I_t / 1000;                  %  5 GHI
        (T_amb - 15) / 25;           %  6 T_amb
        hod / 24;                    %  7 hour of day
        draw_kg / 20;                %  8 draw now
        (T_mains - 20) / 20;         %  9 T_mains
        s(6) / 3;                    % 10 store energy above mains
        s(7) / 1.5;                  % 11 recoverable energy above 45 C
        min_since_draw / 600;        % 12 minutes since last draw
        fwd(1) / 1000;               % 13 GHI + 1 h
        fwd(2) / 1000;               % 14 GHI + 2 h
        fwd(3) / 1000;               % 15 GHI + 3 h
        fwd(4) / 20 ];               % 16 draw of the next hour
% Python builds the vector in float64, stores it as float32, then clips.
obs = double(min(max(single(raw), single(lo)), single(hi)));
end
