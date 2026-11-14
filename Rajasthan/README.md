# Objective 4 (Rajasthan) — Software-in-the-loop validation

A MATLAB/Simulink digital twin of the Rajasthan PCM solar water heater, driven by the trained
Objective 3 DQN controller. It is the Rajasthan counterpart of `../Tamilnadu/`: same signal chain
(weather → sensors → observation → policy → safety interlock → pump/valve → plant), same six edge
cases, same outputs.

**Status: emulated validation only.** It shows the controller behaves correctly on the same physics
it was trained on. It is not experimental validation.

**What has and has not been run (read this first):**

| Part | State |
|---|---|
| Python export for regimes 0, 1, 2 (`export_r0/`, `export_r1/`, `export_r2/`) | Done |
| MATLAB twin (`matlab/*.m`): plant, policy, sensors, interlock, closed loop | **Run in MATLAB R2026b, all three regimes.** Full-year validation passes (`export_r*/validation_report.json`). |
| Six edge-case scenarios: plots and summary table | Done in MATLAB, all three regimes (`export_r*/scenarios/`). |
| Animations | Done in MATLAB for regime 1: four 10-day videos and four `my_*.mp4` clips (`export_r1/scenarios/`). |
| Same checks and scenarios in Python (`sil_python_mirror.py`) | Done (`export_r*/python_mirror/`). An independent cross-check; gives the same numbers. |
| Simulink model `pcm_drl_twin_rj.slx` (`build_pcm_twin_model.m`, `run_twin.m`) | **Built and run once (regime 1, one week, 14 Nov 2026):** 100 % identical actions, delivered 13.04 = 13.04 kWh, 0.78 s per simulated hour (`export_r1/validation_simulink_168h.json`). The generated files (`.slx`, `.slxc`, `slprj/`, `twin_consts.mat`) were then deleted: `run_twin.m` and `validate_against_python(1, 2023, 168, true)` rebuild them. Block-diagram picture: `results_campaign/figures/B_simulink_block_diagram.png`. |
| Generated C code of the controller (`verify_codegen.m`) | **Run 14 Nov 2026, regime 1: PASS.** 9 C files, 1163 lines, 100 % identical decisions against MATLAB and against Python over 8760 h (`export_r1/codegen_verification.json`, C in `export_r1/codegen_c/`). Used the installed MinGW64 compiler. |
| Improvement plan v2: retention test, PCM swap, simulation matrix, tank-level benchmark, figures | **Done for regime 1** (section "Improvement plan v2" below). Files in `matlab/` and `results_campaign/`. |

## What is different from the Tamil Nadu twin

The folder is not a copy with the state name changed, because Rajasthan's Objective 3 is built differently.

| | Tamil Nadu | Rajasthan |
|---|---|---|
| Plant | single water node (100 L, 2.5 m²) | **10-node stratified tank** (50 L, 1.5 m²), Objective 2's `tank_model_multinode.py` kernel |
| Controller | SAC actor 11-256-256-1, tanh output binned at ±1/3 | **DQN** Q-network 17-64-64-3, action = largest Q-value |
| Observation | 11 fields | **17 fields** (13 contract fields + GHI of the next 1/2/3 h + next-hour draw) |
| "Water temperature" | the one node | the **top** node (delivery node, where the shield looks) |
| Replay year | 2011 | **2023** (a validation year; see below) |
| Export folders | `export/`, `export_r1/`, `export_r2/` | `export_r0/`, `export_r1/`, `export_r2/` |
| Default regime | 0 | **1** (the regime of Objective 3's locked test; the regime 0 and 2 policies always charge) |

**Why 2023 and not 2011.** For Rajasthan, 2011–2015 are Objective 2's held-out test years and
2006–2010 are Objective 3's test years behind a one-shot lock that has already been used. Neither may
be re-used. 2023 is an Objective 3 validation year. This twin checks fidelity (does it reproduce the
simulator); it makes no new performance claim.

## Folder layout

| Path | Purpose |
|---|---|
| `export_from_python.py` | Freezes plant parameters, weather, DQN weights and a Python reference run into `export_r<k>/`. Reads Objective 3 (policy, contract) and Objective 2 (physics, weather). Modifies neither. |
| `sil_python_mirror.py` | Python copy of the MATLAB twin. Reads only `export_r<k>/`. Runs the validation and the six scenarios without MATLAB. |
| `export_r<k>/` | Inputs for MATLAB: `plant_params.json`, `weather_2023.csv`, `dqn_qnet_r<k>.json`, `reference_2023.csv`. |
| `export_r<k>/python_mirror/` | Mirror results: `validation_report.json`, `scenario_summary.csv`, one PNG per scenario. |
| `matlab/pcm_plant_hour.m` | One hour of the 10-node tank + PCM + collector + shield. Line-for-line port of the Objective 2 kernel. |
| `matlab/pcm_derive_state.m` | Top/bottom/mean water temperature, PCM temperature, melt fraction, stored and recoverable energy from the node state. |
| `matlab/dqn_policy.m` | The trained DQN (17-64-64-3) as a plain function. |
| `matlab/build_obs.m`, `sensor_model.m`, `safety_interlock.m` | 17-field observation, sensor noise/dropout, stale-sensor and fault-latch fail-safe. |
| `matlab/controller_step.m` | Policy + interlock as one function (the unit compiled to C). |
| `matlab/simulate_hours.m` | Closed loop: sensors, observation, policy, interlock, plant. |
| `matlab/run_scenarios.m` | Validation, six edge cases, plots, summary table, animations. |
| `matlab/validate_against_python.m` | Full-year open-loop, policy-only and closed-loop checks against the Python reference. |
| `matlab/animate_system.m`, `make_my_video.m` | Animated schematic (tank drawn in two bands: top and bottom node temperature). |
| `matlab/build_pcm_twin_model.m`, `run_twin.m` | Build and run the Simulink model `pcm_drl_twin_rj.slx`. |
| `matlab/verify_codegen.m` | Generate C for the controller and compare it with MATLAB. |
| `build_campaign_config.py` | Reads the Objective 1/2/3 files (read-only), checks the cluster count and shortlist, writes `results_campaign/campaign_config.json` with the SHA-256 of every input. |
| `matlab/swap_pcm.m`, `make_plain_tank.m` | Rebuild the plant vector for another PCM; build the water-only tank (capsule volume refilled with water). |
| `matlab/run_hold_test.m` | The retention test: sun off, no draw, from a stored node state, 72 h, hold time at 30/40/45/50 °C. |
| `matlab/twin_metrics.m` | One definition of the per-run metrics M1, M2, M5, M6, M7. |
| `matlab/check_energy_balance.m` | Restart checks, energy closure, latent-heat/swap check, exponential hold, zero input, sub-step test. |
| `matlab/run_campaign.m` | The simulation matrix; writes `results_campaign/campaign_results.csv` and the other tables. |
| `matlab/benchmark_amanowicz.m` | Tank-level comparison with Amanowicz & Turski (2025). |
| `matlab/plot_pack.m`, `animate_tank3d.m` | Figures F1-F8 and animations A1-A3. |
| `results_campaign/` | All outputs of the improvement plan (see `OUTPUTS_GUIDE.md` section 8). |

## How to run

```bash
# 1. export from Python (already done; repeat only if the policy or contract changes)
python export_from_python.py --regime 1
python export_from_python.py --regime 0
python export_from_python.py --regime 2

# 2. check the port and run the scenarios without MATLAB (about 1 minute per regime)
python sil_python_mirror.py --regime 1
```

Use the project environment (`D:\Final Year Project\.venv`): it has NumPy, numba, PyTorch and
Stable-Baselines3. The system Python does not have Stable-Baselines3.

```matlab
% 3. in MATLAB (run with R2026b; Simulink + Stateflow only for the .slx; MATLAB Coder only for C)
cd Rajasthan/matlab
regime = 1; doAnim = false; run_scenarios      % validation + six edge cases + plots
validate_against_python(1)                     % full-year check
regime = 1; doAnim = true;  run_scenarios      % same, with the four animations
make_my_video('regime', 1, 'scenario', 'heat_wave')
validate_against_python(1, 2023, 168, true)    % one week through the Simulink model
regime = 1; verify_codegen                     % C code of the controller

% improvement plan v2 (regime 1); python first, with the project environment:
%   python build_campaign_config.py --regime 1
check_energy_balance(1)                        % restart + closure checks, about 3 min
benchmark_amanowicz                            % tank-level comparison, seconds
run_campaign                                   % about 8 min (run_campaign({'core'}) runs one pass)
plot_pack                                      % figures; animations are plot_pack({'A1','A2','A3'})
```

## What has been verified (MATLAB R2026b, full year 2023, 8760 h)

| Check | Regime 0 | Regime 1 | Regime 2 |
|---|---|---|---|
| Open-loop plant vs Objective 3 environment: max temperature difference | 1.8e-13 °C | 3.6e-13 °C | 5.7e-13 °C |
| Shield activations, twin vs Objective 3 | 115,463 = 115,463 | 101,899 = 101,899 | 227,778 = 227,778 |
| DQN on Objective 3's own observations: identical actions | 100 % | 100 % | 100 % |
| Closed loop (sensors, observation, policy, interlock, plant): identical actions | 100 % | 100 % | 100 % |
| Delivered heat (E_del45), twin vs Objective 3 [kWh] | 954.983 = 954.983 | 897.262 = 897.262 | 970.320 = 970.320 |
| Hard-limit violations | 0 | 0 | 0 |
| Policy file hash equals the one recorded in `gen2_selected_dqn.json` | yes | yes | yes |

Source: `export_r*/validation_report.json`, written by `validate_against_python`. The temperature
differences are rounding noise (MATLAB and NumPy solve the 10×10 system of each sub-step with
different routines). The Python mirror gives the same table with differences of exactly zero
(`export_r*/python_mirror/validation_report.json`).

**What this does and does not prove.** It proves the MATLAB twin reproduces the Objective 3
simulator. It says nothing about agreement with a real tank.

## Improvement plan v2: retention, PCM swap, matrix, benchmark (regime 1, 2023)

Implemented from `.claude/Objective4_Improvement_Plan_v2.docx`, only for Rajasthan regime 1 (Nagaur). The plant
physics and the controller are unchanged. Two small additions to existing files: `pcm_plant_hour.m` has an
optional 4th output (heat carried out by the draw, heat lost through the wall, delivery counted at 50 °C) and
an optional "hour length" `P(44)` (0 = 3600 s, as before); `simulate_hours.m` also logs the node temperatures
and enthalpies. Every existing check gives the same numbers as before (see "What was re-checked").

**Arms.** 1 = water-only tank of the same 50 L, always-charge. 2 = PCM tank, always-charge (the Objective 2
operating point). 3 = same PCM tank with the trained DQN. The PCM axis is the Objective 1 top-3 (PureTemp 60,
CrodaTherm 60, n-Heptacosane C27) with capsule count, size and flow held at the Objective 2 values.

**Retention test.** From 18:00 on 12 evenings spread through 2023: sun off, no draw, real ambient, 72 h.
Mean hours the top layer stays at or above each threshold (all 12 starts; "cens." = runs still above the
threshold at the 72 h cap):

| Arm | 30 °C | 40 °C | 45 °C (cens.) | 50 °C |
|---|---|---|---|---|
| Water only + B0 | 72 (12 cens.) | 64.2 | 51.9 (1) | 35.2 |
| PureTemp 60 + B0 | 72 (12) | 67.0 | 61.2 (7) | 53.4 |
| PureTemp 60 + DQN | 72 (12) | 67.0 | 61.0 (6) | 50.9 |
| CrodaTherm 60 + B0 / DQN | 72 (12) | 67.7 | 62.4 (7) / 62.3 (7) | 54.6 / 52.9 |
| n-Heptacosane + B0 / DQN | 72 (12) | 67.9 | 62.2 (6) / 62.0 (6) | 52.2 / 51.2 |

The 30 °C column is always censored (mains water is 26 °C, so a 30 °C criterion cannot tell designs apart here);
it is only there for comparison with Chen et al. 2025, whose 31.7 h is at 30 °C on a 30 L/day RT35HC system.
The PCM gain over the water-only tank is +9 to +10.5 h at 45 °C (that is the plain-tank-relative number to quote).
The DQN arm retains about as much as the always-charge arm (61.0 vs 61.2 h, 6 of 12 vs 7 of 12 censored): the
controller does not cost retention here. Melt fraction is 0.11-0.18 after 24 h and 0 after 48 h in every arm:
the latent heat is spent within a day, and the later hours are sensible heat of the water.
Cross-check against Objective 2: for 2023 the twin's PCM and water-only window energy (587.2 / 452.8 kWh) equal
Objective 2's `g16_serve_r1.csv` values (587.16 / 452.82 kWh).

**Evening-window delivery (18:00-09:00, 45 °C, kWh per year).** Water only 452.8; PCM + B0 587.2; PCM + DQN 572.1.
Gain over water only 134.3 (B0) and 119.2 (DQN) kWh, well outside Objective 2's repeatability band of 14.4 kWh.
The DQN delivers 15.1 kWh less than B0 in the window (about the size of the band) with 57 % fewer guard-band hours
(430 vs 994). Differences between the three PCMs in tau_hold are 1-1.3 h; PureTemp 60 delivers 25 kWh more window
energy than the other two, which differ from each other by less than 1 kWh.

**Ranking check (M8): three items are too few to support a ranking claim.** Objective 1 ranks PureTemp 60 > CrodaTherm 60 >
n-Heptacosane (C27). The three PCMs differ by about 1 h in hold time at 45 °C (61.0-62.4 h, spread 1.2-1.3 h). The twin ranks
PureTemp 60 **last** on hold time (Spearman -0.5 against Objective 1) but **first** on window energy (+0.5, and 25 kWh ahead of
the other two, which differ from each other by under 1 kWh). The order also moves with the capsule constant: at the fast-melt
bound (c = 7.1, below) PureTemp 60 is second on hold time. With n = 3 a Spearman value can only be -1, -0.5, 0.5 or 1, so no
confidence statement is possible and none is made: this check neither supports nor contradicts Objective 1's ranking
(`results_campaign/ranking_check*.csv`, figure F6).

**Flow (0.7x, 1.0x, 1.3x).** Window energy 581.6 / 587.2 / 587.7 kWh (PCM + B0) and 566.4 / 572.1 / 574.7 (DQN);
hold time moves by under 1 h. The collector's F_R does not depend on flow in this model (known limit).

**Three regimes (figure F5, `campaign_regimes.csv`).** Rajasthan has only three regimes here, not three states.
PCM gain over water-only in window energy: +129 kWh (r0), +134 (r1), +140 (r2); in hold time +8.3, +9.3, +9.8 h.
Regimes 0 and 2 run the always-charge policy, so DQN = B0. A cross-state table needs the other two twins.

**Sensor-fault case, 20 seeds** (mean ± 95 % CI): DQN 8.40 ± 0.02 kWh and 5.49 ± 0.13 shield hours; B0 8.60 ± 0.02 kWh
and 13.86 ± 0.19 h.

**Checks (`check_energy_balance`, all in `results_campaign/energy_balance_report_r1.json`).**
Restart from a stored state reproduces the full-year state exactly (difference 0); `run_hold_test` reproduces an
independent full run (0); energy closure over 4800 h: 2.7e-12 % of collector heat (limit 0.1 %); PCM swap with
PureTemp 60 reproduces the Objective 2 vector (2.8e-14); plain-tank cool-down is the exponential (3e-3 K); zero input
does not drift (5e-13 °C).

**Sub-step gate: not met, measured limitation (`diagnose_substep.m`, `results_campaign/substep_attribution_r1.json`).**
Halving the 150 s step changes annual delivered energy by 0.080 % (-0.731 kWh); 75 s to 37.5 s changes it by 0.041 %
(first-order convergence: halving the step halves the change). Objective 2's gate is 0.05 % and it is not relaxed here.
Where it comes from, from the hour-by-hour difference of the two runs: **not from the phase-change hours.** The 2929 hours in
which a capsule is melting or freezing contribute -0.005 kWh of the -0.731 kWh; the other 5831 hours (PCM entirely solid or
liquid) contribute -0.726 kWh. This is expected: inside the melt band the plant already sub-steps (6 sub-steps, 25 s), so the 150 s
step only acts on the sensible-heat hours. The water-only tank has no phase change and shows a larger change (150 to 75 s:
-0.664 %, -5.1 kWh; 75 to 37.5 s: -0.367 %), so the error belongs to the implicit-Euler / upwind treatment of the tank water
(draw advection, collector return, losses) at 150 s across the whole year, and the PCM tank is better only because it holds
less water. 0.73 kWh is about 5 % of Objective 2's 14.4 kWh repeatability band, so no conclusion in this README changes, but the
gate is not passed for this tank and year and should be reported as such.

**Tank-level comparison with Amanowicz & Turski (2025)** (`benchmark_amanowicz.m`, `amanowicz_case.m`, figure F8). The twin cools
a 6.75 L tank (water only, and 4.05 L water + 9 RT44HC capsules, 40 % of the volume) in 27 °C air for 7200 s and is compared
with the paper's own printed linear fits of its measured curves (equations 2-5), every 300 s; no figure was digitised. The
paper's capsules are 22 mm cuboids; the plant has spheres, so the mapping matters (header of `benchmark_amanowicz.m`).

| Capsule mapping | Loss coefficient | Water-only RMSE / drop | With capsules RMSE / bias / drop |
|---|---|---|---|
| Paper | | drop 14 K printed (fit 13.0 K) | drop 26 K printed (fit 25.5 K) |
| one 300 mL sphere per capsule | from the paper's insulation data (UA 0.82 W/K) | 3.09 K / 7.5 K | 8.42 K / +7.9 K / 20.3 K |
| one 300 mL sphere per capsule | fitted to water-only case (1.55 W/K) | 0.46 K / 13.0 K | 5.72 K / +4.9 K / 24.6 K |
| **same PCM mass and same surface/volume as the slab** (13.2 spheres of 16.5 mm radius per capsule) | from the paper (0.82 W/K), nothing fitted | 3.09 K / 7.5 K | **1.06 K / +0.2 K / 25.2 K** |
| same surface/volume | fitted (1.55 W/K) | 0.46 K / 13.0 K | **1.41 K / -0.9 K / 26.6 K** |

**The 4.5-4.9 K warm bias reported earlier was a geometry-mapping artefact, not a capsule-constant error.** A 22 mm slab has a
11 mm conduction half-thickness; one 83 mm sphere per capsule gives a 40 mm path, 3.6 times too long, and conduction time scales
with its square. With spheres that keep the PCM mass and the slab's surface/volume ratio the frozen Objective 2 constants
(c = 5, F = 2) reproduce the benchmark to 1.1-1.4 K RMSE (below the 2 K target), the printed drops within 5 %, with no capsule
constant fitted (only the tank loss coefficient in the second row, and nothing in the first). All other assumptions (plastic wall,
latent heat 250 kJ/kg from the Objective 1 database, capsules starting at 27 °C) are listed in the file header.

**Which capsule constant? Diagnosis and calibration (`diagnose_capsule.m`, `calibrate_capsule.m`, `capsule_*.csv/json`).** Run before
anything was changed. Resistance budget of one benchmark capsule at zero through-flow (film Nu = 2): film 3.04 K/W (59 %), wall
0.12, PCM solid 1.96, PCM liquid 0.98. One constant varied at a time on the one-sphere mapping: the liquid-convection factor F has no
effect at all (the capsules never pass 50 % melt in the benchmark); the conduction constant c saturates (RMSE 5.7 K at c = 5, 4.5 K
even at c = 50); the film coefficient helps most (RMSE 3.2 K at 20 times) but cannot close the gap. No constant removes the bias
because the length scale is wrong. On the matched mapping the same sweeps show the frozen values are at the minimum: c = 5 gives
1.41 K, c = 2.5 gives 1.77 K, c = 10 gives 1.56 K; film multipliers 0.5 or 2 or more make it worse; F is still irrelevant.

Calibration as asked, fit on Amanowicz & Turski and checked on Tan 2009 and Dong 2022 (single-capsule experiments, not used in the fit):

| c | A&T RMSE, matched | A&T RMSE, one-sphere | Tan 2009 melt-fraction RMSE | Dong 2022 melt-fraction RMSE |
|---|---|---|---|---|
| 5 (frozen) | 1.41 K | 5.72 K | 0.361 | 0.078 |
| 5.03, **fit on A&T, matched mapping (the proposed calibration)** | 1.41 K | 5.71 K | 0.360 | 0.079 |
| 39.99, fit on A&T, one-sphere mapping (hits the search bound 40) | 1.89 K | 4.52 K | 0.470 | 0.447 |
| 7.10, fit on Tan + Dong (**not** held out; bound only) | 1.45 K | 5.38 K | 0.222 | 0.152 |

Reading: **the calibration is a null result, c = 5.03 against the frozen 5.** The tank-level benchmark supports the frozen
value once the geometry is equivalent. Fitting on the one-sphere mapping would have given c = 40 and destroyed the held-out
fits (Dong 0.078 to 0.447), so that route is rejected. The held-out single-capsule cases still show the frozen model slower than
experiment: Tan 2009 reaches 25 % melt at 71 min against 40 min measured (and does not reach 90 % in 200 min against 120 min),
Dong 2022 at 38 / 78 / 99 / 112 min against about 30 / 58 / 104 / 126 min. The two experiments disagree on the direction
of any change in c (Tan wants about 10, Dong about 6); a joint fit gives c = 7.1 and trades one for the other. The
regression of the single-capsule set-up on Objective 2's frozen-lumped numbers passes (Tan t25 71.4 against 71.5 min, Dong within
0.1 min; `capsule_regression.json`). Rocha 2023 and Jia 2024 (in `.claude/Sources/`) both argue that such constants do not transfer
between cases; nothing here contradicts them. No code constant was changed in the plant: both campaigns below only override `P(35)`.

**Hold-test campaign with the calibrated value, next to the uncalibrated one** (`campaign_results.csv` = frozen c = 5,
`campaign_results_cal.csv` = c = 5.03, `campaign_results_fast.csv` = c = 7.10, `calibration_effect.csv`; all kept). Mean of 12
evenings, 45 °C, 72 h cap; window energy 18:00-09:00 in kWh per year:

| Arm | tau_hold frozen / calibrated / fast-melt | Window energy frozen / calibrated / fast-melt |
|---|---|---|
| Water only + B0 | 51.9 / 51.9 / 51.9 | 452.8 / 452.8 / 452.8 |
| PureTemp 60 + B0 | 61.2 / 61.2 / 62.9 | 587.2 / 587.2 / 580.1 |
| PureTemp 60 + DQN | 61.0 / 61.1 / 62.6 | 572.1 / 572.3 / 574.2 |
| CrodaTherm 60 + B0 | 62.4 / 62.5 / 63.2 | 562.7 / 562.5 / 550.3 |
| CrodaTherm 60 + DQN | 62.3 / 62.4 / 63.1 | 559.0 / 559.0 / 547.4 |
| n-Heptacosane + B0 | 62.2 / 62.0 / 62.6 | 562.7 / 562.5 / 550.6 |
| n-Heptacosane + DQN | 62.0 / 62.0 / 62.4 | 562.3 / 562.0 / 550.6 |

The calibrated run differs from the frozen one by at most 0.05 h in hold time (0.24 h for one run) and 0.3 kWh in window energy:
nothing changes. At the fast-melt bound (PCM conduction constant 42 % larger, outside the held-out procedure) hold
time goes **up** by 0.4-1.7 h, window energy changes by -12 to +2 kWh (a decrease of 7-12 kWh for B0, inside Objective 2's
14.4 kWh band only for none of them), and guard-band hours rise (B0 PureTemp 60: 994 to 1295 h; DQN: 430 to 662 h). The PCM gain over the
water-only tank stays +9 to +11 h and +95 to +127 kWh. **So the earlier statement that the frozen capsule model makes hold times
optimistic is withdrawn:** at the tank level it is supported, and faster capsules would, if anything, lengthen the hold by
about 1-2 h. The remaining open item is the single-sphere Tan 2009 result, which a design capsule does not reproduce either way.

**Supercooling proxy (`run_hold_test` `dFreeze`, `supercooling_sensitivity.csv`).** The kernel has one melt band for melting and
freezing, so supercooling is a sensitivity proxy: at the start of the hold the band is moved 2 K down with each capsule's melt
fraction kept. PureTemp 60, 12 evenings: hold time at 45 °C 61.19 to 61.22 h (B0) and 61.01 to 61.12 h (DQN); at 50 °C 53.4 to 53.9 h
and 50.9 to 51.9 h; melt fraction after 24 h 0.14 to 0.18 and 0.11 to 0.15. The effect is under 1 h: latent heat released 2 K lower
does not shorten the hold in this model. It is not a hysteresis model and a real, kinetically delayed release is not covered.

**Pump electrical energy (M7, `campaign_config.json` `o2.hydraulics`).** Objective 2's own Ergun pressure drop across the capsule
bed (`geometry.py::compute_geometry`, void fraction 0.556) at the design flow 0.0493 kg/s is 0.0136 Pa, so the pump at efficiency
0.6 uses about 1.1 microwatt. Over 4166 pump-on hours that is 0.0047 Wh per year (`pump_electrical_Wh` in `campaign_results.csv`).
This is the capsule bed only: pipes, collector and valves are not in the Objective 2 model (Objective 3's contract removed the pump
term for the same reason), so it is a lower bound, not a pump energy. Pump-on hours (3742-4167) are taken as full hours whenever the
collector adds heat. Regimes 0 and 2 carry no hydraulics (NaN).

**Where the quoted retention figures come from (provenance, do not mix with this folder's numbers).** The 12 h / 24-36 h / 24-48 h
figures used as project motivation are not measured here. The only literature source is Chen et al. 2025 (Chen2025; Energy Convers.
Manag.: X 26, 100910): 17.1 h (non-optimised), 29.6 h and 31.7 h (optimised) at a **30 °C** threshold, RT35HC (Tm about 35 °C), about 30 L/day,
CuO nanofluid, 20-30 % PCM, static design optimisation with no controller; Singh 2025 reports a related paraffin entry (at least 30 °C
above ambient for 24 h). The "12 h without PCM" value is not printed in Chen; "24-48 h with PCM plus AI" has no source. This
folder's own numbers are at 45 °C on 300 L/day with 59-61 °C PCMs: 51.9 h water-only and 61.0-62.4 h with PCM at 45 °C, and the 30 °C column
is at the 72 h cap in every run (mains water is 26 °C). Quote Chen as "31.7 h above 30 °C on a 30 L/day RT35HC system" and this
folder's gain over the water-only tank (+9 to +11 h), never the two as one comparison.

**Objective 1 numbers, and a discrepancy in the plan's table.** The Monte-Carlo top-3 inclusion for Rajasthan cluster 1 is 99.3 /
93.6 / 56.1 % in Objective 2's state config (`configs/states/rajasthan.yaml`) and in its copy of the Objective 1 file
(`data/objective1/mcdm_topk_by_cluster.csv`, dated 14 Sep 2026): the numbers `build_campaign_config.py` uses. The plan's table (95.6 / 93.7 /
55.8) is from the Objective 1 repository's own file (`PCM-Selection-ML-model/era5-rajasthan/data/processed/mcdm_topk_by_cluster.csv`,
dated 28 Oct 2026: 95.58 / 93.72 / 55.84), a later Objective 1 run. Ranks and the cluster 1 shortlist are identical; cluster 2's
candidate list also differs between the two files (not used here). Separately, `objective2-rajasthan/data/objective1/manifest.json`
lists `mcdm_topk_by_cluster.csv` as 935 bytes (sha 276c5a42...) but the file on disk is 10 322 bytes (sha 6fd249b0...): the manifest was not
refreshed after the file was replaced. Not reconciled here (Objective 1 and 2 files are not edited).

**What was re-checked after the edits.** `validate_against_python` passes for regimes 0, 1, 2 with the same
numbers as in the table above (delivered 954.983, 897.262, 970.320 kWh; top-node temperature difference 1.8e-13, 2.1e-13,
3.0e-13 °C; the older table reports the largest difference over all quantities). `export_r1/scenarios/scenario_summary.csv`
is identical to the file before the edits. The base campaign was re-run after the pump metric was added: every shared numeric column is identical to the first run.

## Follow-up items (14 Nov 2026): dead pyranometer, handoff export, parameter check, generated C, C1

**Dead pyranometer (`run_dead_pyranometer.m`, `run_scenarios.m` with `deadPyr = true`, figure F9).** Definition (agreed, not in the plan): the controller's
irradiance reading is 0 W/m2 for the whole run while the real sun drives the plant; the 1-3 h forecast in the observation is a weather-feed value and is not zeroed;
B0 does not read the observation, so it is the control. Full year 2023, ideal other sensors (no seed): B0 912.36 kWh, window 587.16 kWh, 993.6 guard-band h (identical with a
dead sensor); DQN healthy 897.3 / 572.1 kWh, 430.0 h; **DQN dead 908.85 kWh, window 583.65 kWh, 701.1 guard-band h**. The dead sensor changes the DQN's command in 246 of 8760 h
and its IDLE hours drop from 356 to 228: it behaves more like B0. 20 seeds on the 10-day April window with noisy other sensors (mean ± 95 % CI): DQN event delivery 11.16 ± 0.02 kWh and
11.31 ± 0.02 shield hours against 11.03 ± 0.02 and 7.72 ± 0.13 with a healthy sensor; B0 11.26 ± 0.02 kWh and 18.66 ± 0.18 h in both. **The interlock and fallback never trigger on
the dead sensor:** fail-safe hours are 0 in the year runs and unchanged in all 20 seeds (largest difference 0 h), because `safety_interlock.m` has no irradiance plausibility rule;
only the plant's own shield limits overheating, with zero hard-limit hours. Event-window row (clear April weather, sensor dead): DQN 11.18 kWh and 11.3 shield hours, B0 11.28 kWh and 18.8 h.
The original `export_r1/scenarios/scenario_summary.csv` is unchanged (still six scenarios, identical to the committed file); the seven-scenario table is
`results_campaign/edge_cases_with_dead_pyranometer/scenario_summary_with_dead_pyranometer.csv`, the year and seed tables are `results_campaign/dead_pyranometer_year.csv` and
`dead_pyranometer_seeds.csv`. A pyranometer stuck at a non-zero value was not run.

**Handoff export re-run.** `export_from_python.py --regime 0/1/2` was re-run into a scratch folder (`--out`) with the current Objective 2 and 3 files. `plant_params.json`,
`weather_2023.csv`, `dqn_qnet_r<k>.json` and `reference_2023.csv` are byte-identical to the existing `export_r0/`, `export_r1/`, `export_r2/` files in all three regimes, and the DQN SHA-256
matches `gen2_selected_dqn.json`. Nothing was replaced. Because the files are identical, `validate_against_python` on `export_r*` is the validation of the fresh export: delivered
954.983, 897.262 and 970.320 kWh, all pass.

**Parameter check (`build_campaign_config.py`).** The twin's values against Objective 2: tank volume 50 L = 50 L, tank volume rebuilt from node water + displaced capsule volume 50 L = 50 L,
collector area 1.5 m2 = 1.5 m2, PCM mass 13.3826 kg = 13.3826 kg, flow 0.0492621 kg/s = 0.0492621 kg/s: five lines, all PASS. Tank volume and collector area come from
`system_config_shared.yaml`; PCM mass and flow come from `results/g10_selection_r1.json` (the state config holds the shortlist, not the design). The script stops if any line fails and prints
the standing limitation: 50 L / 1.5 m2 = 33.3 L/m2 is below the 40-100 L/m2 band of IS 12976:2023 (O2 decision D8).

**Generated C.** `regime = 1; verify_codegen`: PASS (see the status table).

**C1, the 3-D single-capsule check: not done.** It needs the Partial Differential Equation Toolbox; `ver` shows it is not installed, and nothing was installed. The held-out Tan 2009 /
Dong 2022 check (above) is the capsule-level evidence.

## Edge cases (April 2023 weather, 4 days spin-up, 4 days event, 2 days recovery)

Clear, no sunlight, rain/heavy cloud, low temperature, heat wave, and noisy sensors with a 12-hour
blackout. Each is run with the DQN and with the always-charge baseline B0.

### Results, regime 1 (Nagaur medoid, PureTemp 60; event = 4 days; MATLAB)

| Scenario | DQN delivered [kWh] | B0 delivered [kWh] | DQN shield hours | B0 shield hours | Hard violations |
|---|---|---|---|---|---|
| Clear | 11.05 | 11.28 | 7.8 | 18.8 | 0 |
| No sunlight | 0.18 | 0.18 | 0 | 0 | 0 |
| Rain / cloud | 2.49 | 2.49 | 0 | 0 | 0 |
| Low temperature | 10.78 | 12.43 | 0 | 10.6 | 0 |
| Heat wave | 11.91 | 12.55 | 3.3 | 23.0 | 0 |
| Sensor fault | 8.42 | 8.61 | 5.6 | 14.0 | 0 |

Full table: `export_r1/scenarios/scenario_summary.csv`. Plots: `export_r1/scenarios/*.png`.
Videos: `export_r1/scenarios/*_animation.mp4` and `my_*.mp4`. The Python mirror gives the same five
deterministic rows; its sensor-fault row differs slightly (8.38 / 8.54 kWh) because NumPy and MATLAB
draw different random noise.

"Shield hours" is the time the guard band (72 °C top node / 62 °C PCM) was active. The CSV also has
"shield trips": in the 10-node kernel a PCM trip is counted per node per sub-step, so those counts
are in the thousands and are not comparable with Tamil Nadu's trip counts.

Findings worth stating in the report:
- On clear and hot days the DQN delivers 95–98 % of B0's heat with 58–86 % fewer shield hours. It does
  this by going IDLE for 2–3 hours around solar noon (8 to 12 hours over the 4-day event).
- **Low temperature is a weak case.** With mains water 8 °C colder, the DQN still idles at noon although
  there is no overheating risk, and delivers 13 % less than B0 (10.78 vs 12.43 kWh). This condition is
  outside its training range.
- No sunlight and rain: nothing to store, both policies deliver the same.
- In every case the PCM is fully solid again in the night (over the whole of 2023 the melt fraction at
  01:00 is 0 on every day), so no latent heat carries into the next morning with this 50 L sizing.
- Zero hard-limit violations in every case. The 12-hour blackout puts the interlock in fail-safe
  BYPASS for 15 hours (12 blackout + 3 random dropouts), and the loop recovers afterwards.
- **Regimes 0 and 2: the released DQN always charges** (0 IDLE hours in 8760), so it equals B0 in every
  scenario. This matches Objective 3's own record (`gen2_selected_dqn.json`: 0 switches, 100 % of B0).
  The twin runs for these regimes, but there is no controller benefit to show.

## Limits

- The Simulink model was run for one week of regime 1 only. (Generated C: verified, see the status table.) Earlier text: not run
  in this pass. The builder's block layout is untidy (lines cross): a picture of the signal chain, not a polished figure.
- Animations exist for regime 1 only. Regimes 0 and 2 would show the always-charge policy.
- In the animation the state text reads CHARGE at night because that is the policy's command. The pump is now drawn
  running only when the collector adds heat (fixed in this pass; it used to run whenever CHARGE was commanded).
- Retention and campaign results: one regime, one year, 12 start evenings, three PCMs. The capsule model matches the Amanowicz & Turski tank
  test at 1.1-1.4 K once the capsules' surface/volume is matched, but a single sphere in a bath (Tan 2009) still melts about 1.8 times
  faster in the experiment (Dong 2022: about 1.3 times at half melt); a fast-melt run (c = 7.1) lengthens hold times by 0.4-1.7 h and
  changes window energy by -12 to +2 kWh, so the frozen constants give slightly short, not long, holds. Hold times are quoted with that range.
- Supercooling is a proxy only (freezing point 2 K lower; effect under 1 h); a kinetic delay of the latent release is not modelled.
- Pump electrical energy is the capsule bed's Ergun share only (0.005 Wh/yr): a lower bound.
- The sub-step gate (0.05 %) is not met for this tank and year: 0.080 % for 150 to 75 s, from the sensible-heat hours, not the melting hours.
- Three PCMs per cluster is too few for a ranking claim (see the ranking paragraph).
- Not done: a cross-state version of figure F5 (needs the other two twins' campaign outputs and was out of scope), and option C1 (3-D single capsule: needs the
  Partial Differential Equation Toolbox, not installed; the held-out Tan/Dong check above covers the same question at capsule level).
- The water-only tank has its PCM-side limits switched off in the interlock (otherwise its mean water temperature is compared with the 65 °C PCM limit and latches a false fault).
- Retention is read at the contract target (45 °C); Rajasthan has no 50 °C contract, so the 50 °C column is for comparison only.
- The plant is the model the policy was trained on. Agreement with it is not agreement with a real tank.
  A comparison with a published tank experiment is in the improvement-plan section; there is no measurement on this design.
- The 3-hour GHI forecast in the observation is the true future weather (a perfect forecast).
- Sensor noise is applied to GHI, ambient, top, bottom, mean and PCM temperature. Melt fraction and the
  two energy fields are estimator outputs and are passed through without error.
- The interlock latches on a single over-limit reading and has no debounce (same as Tamil Nadu).
- Rain has no physics of its own; it enters only as lower irradiance and ambient temperature.
- The 50 L / 1.5 m² system is below the 40–100 L/m² band of IS 12976:2023 (a standing Objective 2 limitation).
- The policy decides hourly; the shield inside the plant acts at every solver sub-step (150 s or shorter).
