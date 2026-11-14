function run_e()
%RUN_E  Objective 4, item E: PCM swap study, Tamil Nadu only, geometry fixed.
% Geometry (capsule count, capsule diameter, wall thickness, collector area,
% tank mass/area) comes from Objective 2's own g10_selection_r0.json /
% plant_params.json for this regime and is NOT re-optimised per PCM -- only
% the PCM material properties (and, for the sensitivity sweep, the tank-side
% flow velocity v_sup) are changed. The PCM shortlist and its O1 cluster-0
% rank come from objective2_design_optimization/data/objective1's own
% recommendation_cards.md / pcm_database_tamilnadu.csv (NOT recomputed here).
%
% SAC caveat: the frozen sac_actor_r0.json was trained on PureTemp 58 only
% (plant_params.json: "selected_pcm": "PureTemp 58"). Running that same
% frozen policy against RT57HC or n-Hexacosane is an OUT-OF-DISTRIBUTION
% test of the policy, not a retrain -- flagged explicitly in the report.
here = fileparts(mfilename('fullpath')); addpath(here);
exportDir = fullfile(here, '..', 'export');
year = 2021;
tgt = 45.0;      % C, hold-time threshold requested for item E (delivery target)
holdHours = 72;
startDays = round(linspace(10, 350, 12));

tw = load_twin_params(exportDir, year);
W = tw.wx.signals.values; n = size(W,1);
dayBlock1 = W(1:24,4);
off18 = find(round(dayBlock1) == 18, 1);
A_coll = tw.P(10);

% ---- fixed PCM cavity volume and fixed capsule-wall heat capacity, from
% the DEPLOYED PureTemp58 geometry (Objective 2's own numbers; not re-derived) --
dens_PureTemp58 = 890.0;   % data/objective1/pcm_database_tamilnadu.csv, density_solid_kg_m3
m_pcm0  = tw.P(14);        % 24.8137... kg, Objective 2's deployed PCM mass
V_pcm   = m_pcm0 / dens_PureTemp58;         % fixed PCM cavity volume (m^3), same capsules, same N
wallC_const = tw.P(21) * m_pcm0;            % m_wall*c_wall (J/K), fixed by capsule geometry/material

% ---- PCM material properties, from the O1 PCM database (not recomputed) --
% name, Tm_C, L_J_kg, cp_s_J_kgK, cp_l_J_kgK, k_pcm_W_mK, density_solid_kg_m3, O1_rank(cluster0)
mats = {
  'RT57HC',               56.5, 240000, 2000, 2000, 0.239, 900.0, 1;
  'n-Hexacosane (C26)',    56.5, 256000, 2200, 2380, 0.238, 770.0, 2;
  'PureTemp 58',           58.0, 225000, 2470, 2710, 0.200, 890.0, 3;
};

runs = {}; % {pcm, pcm_o1_rank, flow_mult, policy, delivered_kWh, unmet_kWh, shield_events, n_viol, m_pcm, kWh_per_kg, kWh_per_m2, tau45_mean_h, n_censored45}

for mi = 1:size(mats,1)
    nm = mats{mi,1}; Tm = mats{mi,2}; Lj = mats{mi,3}; cps = mats{mi,4}; cpl = mats{mi,5};
    kpcm = mats{mi,6}; dens = mats{mi,7}; o1rank = mats{mi,8};

    P_mat = tw.P;
    m_pcm_new = V_pcm * dens;
    P_mat(14) = m_pcm_new;
    P_mat(15) = Tm;
    % P_mat(16) half_width_K left at 1.0 -- O2's own documented convention
    % (system_config_shared.yaml pcm_integration.melting_half_width_K),
    % applied uniformly across PCMs, not re-derived per material.
    P_mat(17) = Lj;
    P_mat(18) = cps;
    P_mat(19) = cpl;
    P_mat(20) = kpcm;
    P_mat(21) = wallC_const / m_pcm_new;   % wall_cp_J_kgK rescales with 1/m_pcm (fixed wall mass*cp)

    if strcmp(nm, 'PureTemp 58')
        flows = [0.7 1.0 1.3];
    else
        flows = [1.0];
    end

    for fl = flows
        P_run = P_mat;
        P_run(28) = P_mat(28) * fl;   % v_sup_m_s, the only flow DOF in this twin

        for policy_mode = [0 1]   % 0 = SAC (frozen, PureTemp58-trained), 1 = B0 baseline
            L = simulate_hours(tw, W, P_run, policy_mode, 0, []);
            delivered_kWh = sum(L.E_del_Wh) / 1000;
            unmet_kWh     = sum(L.E_unmet_Wh) / 1000;
            shield_events = sum(L.n_sw) + sum(L.n_sp);
            viol          = sum(L.n_viol);

            % ---- hold time at 45 C, same method as run_hold_test.m (18:00
            % local, BYPASS, 72 h cap, linear interpolation, censored at cap,
            % already-below-target guard) ----
            tauAll = zeros(numel(startDays),1); censAll = false(numel(startDays),1);
            for di = 1:numel(startDays)
                d = startDays(di);
                iStart = (d-1)*24 + off18;
                if iStart + holdHours > n, tauAll(di) = NaN; continue; end
                Tw0 = L.Tw(iStart); Tp0 = L.Tpcm(iStart); h0 = L.h_pcm(iStart); f0 = L.f_melt(iStart);
                Tw_ = Tw0; Tp_ = Tp0; h_ = h0; f_ = f0;
                tau = NaN; cens = true; prev = Tw0;
                if Tw0 < tgt, tau = 0; cens = false; end
                for k = 1:holdHours
                    iw = iStart + k;
                    [Tw_, Tp_, h_, f_] = pcm_plant_hour(0, W(iw,3), 0, 2, Tw_, Tp_, h_, f_, P_run); %#ok<ASGLU>
                    if isnan(tau) && Tw_ < tgt
                        frac = 1; if prev > Tw_, frac = (prev - tgt) / (prev - Tw_); end
                        tau = (k-1) + frac; cens = false;
                    end
                    prev = Tw_;
                end
                if isnan(tau), tau = holdHours; end
                tauAll(di) = tau; censAll(di) = cens;
            end
            tau_mean = mean(tauAll(~isnan(tauAll)));
            n_censored = sum(censAll);

            runs(end+1,:) = {nm, o1rank, fl, policy_mode, delivered_kWh, unmet_kWh, shield_events, viol, ...
                              m_pcm_new, delivered_kWh/m_pcm_new, delivered_kWh/A_coll, tau_mean, n_censored}; %#ok<AGROW>
        end
    end
end

T = cell2table(runs, 'VariableNames', {'pcm','o1_cluster0_rank','flow_mult','policy_mode', ...
    'delivered_kWh','unmet_kWh','shield_events','n_viol','m_pcm_kg','kWh_per_kg_pcm','kWh_per_m2_coll', ...
    'tau_hold45_mean_h','tau_hold45_n_censored'});

fprintf('\n=== Objective 4 item E: PCM swap, geometry fixed (A_coll=%.1f m2, N=%d capsules, V_pcm fixed=%.5f m^3) ===\n', A_coll, tw.P(23), V_pcm);
fprintf('policy_mode: 0=SAC (frozen, trained on PureTemp 58 only -- OUT-OF-DISTRIBUTION for RT57HC/Hexacosane), 1=B0 baseline\n\n');
disp(T);

writetable(T, fullfile(exportDir, 'pcm_swap_study.csv'));
fid = fopen(fullfile(exportDir, 'pcm_swap_study.json'), 'w');
fwrite(fid, jsonencode(struct('runs', runs, 'columns', {T.Properties.VariableNames}, ...
    'V_pcm_m3_fixed', V_pcm, 'wallC_const_J_K', wallC_const, 'off18_row', off18), 'PrettyPrint', true));
fclose(fid);
fprintf('\n[run_e] table -> %s/pcm_swap_study.csv\n', exportDir);
fprintf('E_DONE_MARKER\n');
end
