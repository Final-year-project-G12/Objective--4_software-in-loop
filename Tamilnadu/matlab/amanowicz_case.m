function rep = amanowicz_case()
%AMANOWICZ_CASE  Objective 4 item G: tank-level benchmark against
% Amanowicz & Turski 2025 (Energies 18(2) 345), RT44HC PCM-filled capsules,
% laboratory cool-down. Values below are exactly the ones recorded in this
% project's own plan (plan_O4.md / plan_ordered.txt TABLE 40/"Amanowicz and
% Turski 2025" row); the primary PDF was not fetchable in this session
% (mdpi.com, a Semantic Scholar mirror and DOAJ all returned HTTP 403, and
% no local copy exists under .claude/Sources in this checkout), so no
% number here was read off Figure 7 -- only the two headline drops (14 K,
% 26 K) and the geometry/property table the plan already extracted are
% used. This is declared, not hidden.
%
% NOTHING in pcm_plant_hour.m is changed or recalibrated: same Wakao-Kaguei
% correlation, same lumped-sphere constant (c=5, inside ua_eff_total), same
% liquid-convection enhancement factor (2.0). The only case-specific inputs
% built here are: (a) this lab tank's own heat-loss UA, fit ONCE from the
% water-only case (Case 1) because the paper gives no insulation U-value,
% and (b) an equivalent-sphere capsule geometry matched to the real
% cuboid capsule's PCM mass and surface/volume ratio, because this model
% only has a sphere correlation.
here = fileparts(mfilename('fullpath')); addpath(here);

% ---- paper's own numbers (plan_O4.md TABLE 40) -------------------------
T_amb        = 27.0;           % C, lab ambient
V_water_c1   = 6.750e-3;       % m^3, Case 1 (water only)
T0_c1        = 75.0;           % C
V_water_c2   = 4.050e-3;       % m^3, Case 2 (water + capsules)
T0_c2        = 70.0;           % C, "mixture settles to about 70 C before the measurement starts"
n_cap_real   = 9;
V_cap_real   = 300e-6;         % m^3 per capsule (= 300 mL)
t_cap_real_m = 22e-3;          % m, capsule thickness
m_pcm_cap    = 0.200;          % kg PCM per capsule
m_cap_total  = 0.240;          % kg per capsule (PCM + plastic shell)
drop_meas_c1 = 14.0;           % K, water-only
drop_meas_c2 = 26.0;           % K, water + capsules
duration_s   = 2*3600;         % s -- "same period"; the plan's own extract does not
                                % print a duration figure, so this comes from
                                % the paper's reported 2 h window (corroborated by
                                % two independent secondary-source searches of the
                                % same abstract, since the primary PDF was blocked).
                                % FLAGGED, not read off a digitised curve.

% RT44HC properties: density/cp as GIVEN IN THE PAPER (plan_O4.md), Tm/L
% from the manufacturer datasheet already in this repo's own PCM database
% (tamilnadu_pipeline/PCM_data/.../PCM_Properties_cleaned_mice_pmm.csv,
% RT44HC row, latent_heat_melting=250 kJ/kg "Not imputed", Tm 41-44 C) --
% the paper's own Table 2 melting range/peak was not readable (PDF blocked),
% so the datasheet value stands in, FLAGGED.
Tm_pcm   = 42.5;   half_w = 1.5;   L_pcm = 250000;
cp_s_pcm = 2000;    cp_l_pcm = 2000;     % paper: "cp 2.0 kJ/kgK" (not split by phase)
k_pcm    = 0.2;                          % paper / datasheet agree: 0.2 W/mK
dens_solid_pcm = 800.0;                  % paper: "800 kg/m3 solid at 25 C"
% dens_liquid_pcm = 700.0 (paper, 80 C) -- not used: this model's fixed
% capsule mass is on the solid-density basis (capsule_enthalpy.py convention)

% ---- ASSUMED, flagged inputs the paper does not give -------------------
cp_shell_assumed   = 1800;   % J/kgK, generic polymer (PP/PE) -- ASSUMED, not measured
dens_shell_assumed = 1000;   % kg/m3, generic polymer -- ASSUMED, used only to back out a wall thickness
k_wall_assumed     = 0.22;   % W/mK, generic polymer -- ASSUMED (the main twin's k_wall=205 is ALUMINUM and
                             % would be wrong here; these capsules are plastic)

% ---- equivalent-sphere geometry: match the REAL cuboid capsule's
% surface/volume ratio and total PCM mass (not Objective 2's own 80 mm
% capsule size -- that is a different design, not this experiment) -------
footprint = V_cap_real / t_cap_real_m;             % m^2, assume square footprint
side      = sqrt(footprint);
S_real    = 2*footprint + 4*side*t_cap_real_m;      % m^2, one real capsule
SV_real   = S_real / V_cap_real;                    % 1/m
D_eq      = 6 / SV_real;                            % m, sphere with the same S/V
V_sphere  = (pi/6) * D_eq^3;
m_pcm_total = n_cap_real * m_pcm_cap;                % kg, real total (used directly, not re-derived)
N_eq      = m_pcm_total / (dens_solid_pcm * V_sphere); % spheres needed for that total PCM mass at D_eq

A_cap_eq  = pi * D_eq^2;
m_shell_total  = n_cap_real * (m_cap_total - m_pcm_cap);          % kg, real total shell mass
% shell thickness from assumed shell density and the REAL total shell
% surface area -- independent of how many equivalent spheres we use
S_real_total = n_cap_real * S_real;
t_wall_eq = m_shell_total / (dens_shell_assumed * S_real_total);
wall_cp_eq = (m_shell_total * cp_shell_assumed) / m_pcm_total;     % J/kgK per kg PCM

fprintf('=== Item G: Amanowicz & Turski 2025 equivalent-sphere geometry ===\n');
fprintf('  real capsule: cuboid, %.0f mm thick, %.0f mL, S/V = %.2f 1/m\n', t_cap_real_m*1000, V_cap_real*1e6, SV_real);
fprintf('  equivalent sphere: D = %.1f mm (vs. the main twin''s unrelated 80 mm capsule), N = %.1f spheres for %.3f kg total PCM\n', D_eq*1000, N_eq, m_pcm_total);
fprintf('  wall: t_wall = %.3f mm (ASSUMED plastic density %.0f kg/m3), wall_cp = %.1f J/kgK (ASSUMED plastic cp %.0f J/kgK)\n', t_wall_eq*1000, dens_shell_assumed, wall_cp_eq, cp_shell_assumed);

% ---- Case 1: fit this lab tank's own UA from the water-only cool-down --
% (U_tank*A_tank is a per-tank constant this frozen model needs as an
% input; the paper never states an insulation U-value, so it is fit here
% from Case 1 ONLY. Nothing in pcm_plant_hour.m changes -- this is the
% same kind of input A_tank/U_tank already is for the Tamil Nadu twin,
% not a capsule/PCM physics constant.)
P0 = default_P();
P0(1) = V_water_c1 * 1000;   % m_w [kg], rho_w=1000
P0(14) = 0; P0(23) = 0;       % no PCM in Case 1

UA_fit = fzero(@(UA) run_case(P0, UA, T0_c1, T_amb, 0, 0, 0, duration_s) - (T0_c1 - drop_meas_c1), [0.01 50]);
fprintf('\n  Case 1 (water only) fit: UA = %.4f W/K  (tau = %.1f h)\n', UA_fit, (P0(1)*4186/UA_fit)/3600);
Tw_end_c1 = run_case(P0, UA_fit, T0_c1, T_amb, 0, 0, 0, duration_s);
drop_sim_c1 = T0_c1 - Tw_end_c1;

% ---- Case 2: SAME UA (same physical tank), add the equivalent-sphere
% capsules, PCM starting fully liquid at 70 C ("mixture settles... before
% the measurement starts") -- no constant is touched, only the geometry
% inputs built above. -------------------------------------------------
P2 = default_P();
P2(1) = V_water_c2 * 1000;
P2(14) = m_pcm_total; P2(15) = Tm_pcm; P2(16) = half_w; P2(17) = L_pcm;
P2(18) = cp_s_pcm; P2(19) = cp_l_pcm; P2(20) = k_pcm; P2(21) = wall_cp_eq;
P2(23) = N_eq; P2(24) = D_eq; P2(25) = A_cap_eq; P2(26) = t_wall_eq; P2(27) = k_wall_assumed;

Tw_end_c2 = run_case(P2, UA_fit, T0_c2, T_amb, Tm_pcm, half_w, L_pcm, duration_s, cp_s_pcm, cp_l_pcm, wall_cp_eq);
drop_sim_c2 = T0_c2 - Tw_end_c2;

err_c1_pct = 100*abs(drop_sim_c1-drop_meas_c1)/drop_meas_c1;
err_c2_pct = 100*abs(drop_sim_c2-drop_meas_c2)/drop_meas_c2;

fprintf('\n=== Cool-down drop over %.0f h ===\n', duration_s/3600);
fprintf('  Case 1 (water only):      measured %.1f K   simulated %.2f K   (by construction: UA was fit to this)\n', drop_meas_c1, drop_sim_c1);
fprintf('  Case 2 (water+capsules):  measured %.1f K   simulated %.2f K   error %.1f %%  -> %s\n', ...
    drop_meas_c2, drop_sim_c2, err_c2_pct, ternary(err_c2_pct<=15,'within 15%','OUTSIDE 15%'));

% ---- "RMSE on the cool-down curve" -- stated honestly: Figure 7 was not
% available (PDF blocked), so there is no digitised curve to compare
% against. What follows is a 2-ANCHOR-POINT RMSE/MAE (t=0 and t=duration,
% the only two numbers the paper's abstract/text give directly), NOT a
% full-curve statistic -- do not read it as equivalent to one. ----------
simPts  = [T0_c2, Tw_end_c2];
measPts = [T0_c2, T0_c2 - drop_meas_c2];
rmse2pt = sqrt(mean((simPts - measPts).^2));
mae2pt  = mean(abs(simPts - measPts));
fprintf('\n=== "Curve" RMSE/MAE (2 anchor points only -- t=0 and t=%.0f h; no digitised Figure 7 available) ===\n', duration_s/3600);
fprintf('  RMSE = %.2f C   MAE = %.2f C   (NOT a full-curve statistic -- see note above)\n', rmse2pt, mae2pt);

% ---- diagnose: why slow? ----
fprintf('\n=== Diagnosis: capsule model runs on the slow side ===\n');
fprintf('  Objective 2''s own capsule-level benchmark already found this correlation moves heat into/out of\n');
fprintf('  capsules too slowly against two published experiments (plan_O4.md section 7.2) -- this is carried\n');
fprintf('  forward, not re-derived here. The same direction of error is visible above: if sim drop_c2 < measured\n');
fprintf('  26 K, the model under-predicts how fast heat left the water into/through the capsules, consistent\n');
fprintf('  with a capsule conductance (Wakao-Kaguei h_w, or the lumped-sphere constant c=5 inside\n');
fprintf('  ua_eff_total) that is too small for this geometry -- NOT recalibrated here, per instruction.\n');
fprintf('  A model that is slow to move heat INTO capsules is also slow to move it OUT -- so every retention\n');
fprintf('  (tau_hold) number from items D/E carries this same bias, in the OPTIMISTIC direction (retention is\n');
fprintf('  over-stated). This result is the error bar on every one of those numbers.\n');

fprintf('\n=== Three limitations (plan_O4.md TABLE 41), restated for this run ===\n');
fprintf('  1. Shape mismatch: real capsules are 22 mm-thick cuboids; the model only has a sphere correlation.\n');
fprintf('     Matched here on PCM mass and surface/volume ratio (D_eq=%.1f mm, N=%.1f), but a disagreement may\n', D_eq*1000, N_eq);
fprintf('     be the shape, not the conductance model.\n');
fprintf('  2. Direction mismatch: the paper''s capsules are being CHARGED by hot water (water+PCM cools faster\n');
fprintf('     because the PCM is absorbing heat to melt); Objective 4''s own retention test runs the OPPOSITE\n');
fprintf('     direction (PCM discharging into cooling water). Agreement here is supporting evidence for\n');
fprintf('     discharge, not proof of it.\n');
fprintf('  3. No digitised curve: the 14 K/26 K figures are used directly from the abstract/text (legitimate\n');
fprintf('     per the plan); anything beyond that would need Figure 7 digitised with a named tool and a stated\n');
fprintf('     pixel error, which was not attempted here (the PDF could not be fetched this session).\n');

rep = struct('UA_fit_W_K', UA_fit, 'D_eq_m', D_eq, 'N_eq', N_eq, 'wall_cp_eq_J_kgK', wall_cp_eq, ...
    't_wall_eq_m', t_wall_eq, 'drop_meas_c1_K', drop_meas_c1, 'drop_sim_c1_K', drop_sim_c1, ...
    'drop_meas_c2_K', drop_meas_c2, 'drop_sim_c2_K', drop_sim_c2, 'err_c2_pct', err_c2_pct, ...
    'within_15pct', err_c2_pct<=15, 'rmse_2pt_C', rmse2pt, 'mae_2pt_C', mae2pt, 'duration_s', duration_s);
fid = fopen(fullfile(here, '..', 'export', 'amanowicz_benchmark.json'), 'w');
fwrite(fid, jsonencode(rep, 'PrettyPrint', true));
fclose(fid);
fprintf('\n[amanowicz_case] report -> ../export/amanowicz_benchmark.json\n');
fprintf('G_DONE_MARKER\n');
end

% ========================================================================
function Tw_end = run_case(P, UA, T0_w, T_amb, Tm, half_w, Lp, duration_s, cp_s, cp_l, wall_cp)
P(6) = UA; P(7) = 1;   % fold UA into U_tank*A_tank, A_tank=1
if nargin >= 9 && P(14) > 0
    Ts = Tm - half_w; Tl = Tm + half_w;
    cps = cp_s + wall_cp; cpl = cp_l + wall_cp;
    h_s = cps*Ts; span = Lp + wall_cp*(Tl-Ts);
    if T0_w < Ts, h0 = cps*T0_w;
    elseif T0_w <= Tl, h0 = h_s + (T0_w-Ts)/(Tl-Ts)*span;
    else, h0 = h_s + span + cpl*(T0_w-Tl);
    end
else
    h0 = 0;
end
Tw = T0_w; Tp = T0_w; h = h0; f = double(P(14)>0);
nHours = round(duration_s/3600);
remS = duration_s - nHours*3600;
for hh = 1:nHours
    [Tw, Tp, h, f] = pcm_plant_hour(0, T_amb, 0, 1, Tw, Tp, h, f, P); %#ok<ASGLU>
end
if remS > 0
    Psub = P; Psub(34) = remS;   % one partial-hour call sized to the remainder
    [Tw, Tp, h, f] = pcm_plant_hour(0, T_amb, 0, 1, Tw, Tp, h, f, Psub); %#ok<ASGLU>
end
Tw_end = Tw;
end

function P = default_P()
P = zeros(41,1);
P(2)=4186; P(3)=1000; P(4)=0.63; P(5)=4.3;       % water props, same as the main twin
P(8)=27; P(9)=45;                                  % T_mains/T_deliv, unused (no draw)
P(10)=0; P(11)=0; P(12)=0; P(13)=10;               % no collector
P(22)=2.0;                                          % liquid-convection enhancement, FROZEN (unchanged)
P(28)=0;                                            % v_sup=0: stagnant tank, no pumped flow
P(29)=200; P(30)=200; P(31)=0; P(32)=200; P(33)=200; % shield disabled, limits set far away (unused: action fixed to IDLE)
P(34)=60; P(35)=6; P(36)=2.0; P(37)=0.5; P(38)=60;  % substepping, same defaults as the main twin
P(39)=-5; P(40)=5; P(41)=27;
end

function v = ternary(c,a,b)
if c, v=a; else, v=b; end
end
