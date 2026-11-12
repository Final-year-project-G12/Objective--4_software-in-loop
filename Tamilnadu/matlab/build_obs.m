function obs = build_obs(I_t, T_amb, T_w, T_pcm, f_melt, demand_kg, hod, hour_idx, prev_action, P)
%BUILD_OBS  Assemble the 11-dim V1 observation (pcm_env.py::_get_obs) and
% apply the gym wrapper's clip to [-5, 5]. Normalisation constants are the
% fixed training-time ones, never live statistics (O4 spec).
%#codegen
T_mains = P(8);  max_wC = P(29);  lo = P(39);  hi = P(40);
N_ACTIONS = 3;
raw = [ I_t / 1000;
        (T_amb - 15) / 25;
        (T_w - 30) / 40;
        (T_pcm - 30) / 40;
        f_melt;
        demand_kg / 20;
        (T_mains - 20) / 20;
        hod / 24;
        mod(hour_idx, 8760) / 8760;
        prev_action / (N_ACTIONS - 1);
        (max_wC - T_w) / 10 ];
% Python builds the vector in float64 then stores it as float32, then clips.
obs = double(min(max(single(raw), single(lo)), single(hi)));
end
