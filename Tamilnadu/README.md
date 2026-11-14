# Objective 4 — Software-in-the-loop validation (Tamil Nadu, 100 L twin)

A MATLAB digital twin of the Tamil Nadu PCM solar water heater (100 L tank, 2.5 m²
collector, single water node + single PCM node, 104 capsules, SAC controller),
driven by the trained Objective 3 policy. It stands in for the hardware tests of
the Objective 4 plan (sensor model, interlock, software-in-the-loop replay, edge
cases, retention, PCM comparison, published-experiment benchmark) until a physical
rig exists.

**Status: emulated validation only.** It shows the controller behaves correctly on
the same physics it was trained on. It is not experimental validation; the field
trial in `results/obj4_handoff/obj4_deployment_test_plan_r0.md` (step 6) remains.
This document covers the Tamil Nadu 100 L twin only. The shared method with the other
states is in `docs/plan_O4.md`; the Rajasthan twin (10-node stratified tank, DQN) is in
`../Rajasthan/`.

**Replay years differ by result:** the validation against the Python simulator and the
six edge cases (`run_val`, `run_c`) replay 2011, a locked Objective 3 test year, so they are
exploratory; the three-arm comparison, one-day plots, energy checks, hold test, PCM swap and
video replay 2021 (an Objective 3 validation year).

## Folder layout

| Path | Purpose |
|---|---|
| `export_from_python.py` | Freezes plant parameters, weather, SAC weights and a Python reference run into `export/`. Run from `objective3/`. |
| `export/` | Generated inputs for MATLAB, plus every result table/figure this README cites. |
| `matlab/pcm_plant_hour.m` | One hour of tank + PCM + collector + shield physics. Line-for-line port of the Python environment. Frozen — nothing in it is recalibrated by any check below. |
| `matlab/sac_policy.m`, `build_obs.m`, `sensor_model.m`, `safety_interlock.m` | SAC actor, observation vector, sensor noise/dropout, stale-sensor and fault-latch fail-safe. |
| `matlab/simulate_hours.m` | Closed loop: sensors → observation → policy → interlock → plant. `policy_mode`: 0 = SAC, 1 = B0 (always-charge baseline). |
| `matlab/load_twin_params.m` | Reads `export/plant_params.json` + weather into the parameter vector `P` every script below shares. |
| `matlab/check_restart.m`, `check_energy_balance.m`, `run_hold_test.m` | Restart correctness, the 5-point energy-balance gate, and the 72 h retention/hold test. Run together via `run_d.m`. |
| `matlab/run_e.m` | PCM swap (RT57HC / n-Hexacosane / PureTemp 58) at 3 flow multipliers, geometry held fixed. |
| `matlab/animate_system.m`, `run_f.m` | 2-D animated schematic (pump-gain bug fixed, see below) and the 3-arm side-by-side day video. |
| `matlab/amanowicz_case.m` | Tank-level benchmark against Amanowicz & Turski 2025 (RT44HC cool-down). |
| `matlab/run_c_scenarios.m`, `run_h.m` | 6 environmental edge cases (3 arms) + dead/stuck-pyranometer (arm 3), and the 20-seed confidence intervals on top of them. |
| `matlab/validate_v3_full.m`, `three_arm_2021.m`, `one_day_cycle.m` | Validation against the Python simulator (open-loop, policy-only, closed-loop), the three-arm comparison, and the one-day charge/idle/bypass plot. |
| `matlab/run_val.m`, `run_arm.m`, `run_c.m`, `run_day.m` | Batch launchers for the four items above (they set the replay year; `run_c` and `run_val` use 2011). |
| `export_r1/`, `export_r2/` | Regime 1 and 2 exports with their validation reports (all pass). Regime 0 is the primary regime. |
| `reports/` | One markdown report per work item (validation, three arms, plots, edge cases, hold test, PCM swap, video, benchmark, sensor faults) and an audit summary. |
| `docs/` | `plan_O4.md` (joint plan with the Rajasthan twin) and `OBJECTIVE4_TAMILNADU_SCOPE.md`. |
| `video/` | `o4_three_arm_day071_2021.mp4`, the three-arm day video. |

Removed from this version because they were built for the pre-retrain controller or were
caches: the Simulink model (`pcm_drl_twin.slx`) and its builder, the generated C code and MEX of the
old controller, the old single-arm scenario videos, and the previous output guide/discussion documents.

## What is in `export/` (no overlap, one file per purpose)

| File(s) | What it is | Replay year |
|---|---|---|
| `plant_params.json`, `sac_actor_r0.json` | Frozen plant and the exported SAC actor (r0_smartfc, 15 inputs) | n/a |
| `weather_2011.csv`, `reference_2011.csv` | Weather and Python reference run used by `validate_v3_full` and the edge cases | 2011 (locked test year) |
| `weather_2021.csv`, `reference_2021.csv` | Weather and Python reference run used by the three-arm, hold test, PCM swap, plots and video | 2021 (validation year) |
| `validation_report_v3.json` | Open-loop / policy-only / closed-loop check vs Python | 2011 |
| `three_arm_2021.*` | Three-arm comparison table and figure | 2021 |
| `one_day_cycle_2021.*` | One-day plot (day 71) and its data | 2021 |
| `restart_check.json`, `energy_balance_report.json` | Restart and energy-balance checks | 2021 |
| `hold_test.csv`, `hold_test_thresholds.csv` | 72 h hold test, per start day | 2021 |
| `pcm_swap_study.*` | PCM swap and flow study | 2021 |
| `amanowicz_benchmark.json` | Tank-level benchmark (two-endpoint check) | n/a |
| `scenarios_3arm/` | Edge-case table and figures, dead/stuck pyranometer, 20-seed CIs | 2011 |
| `../export_r1/`, `../export_r2/` | Regime 1 and 2 exports (r1_smartfc, r2_smartfc) and validation reports | 2011 |

All figures in this folder come from the frozen `r0_smartfc` SAC; there are no older-controller plots left.

## How to run

```bash
# 1. export from Python (from the objective3 folder)
python objective4_software_in_loop/export_from_python.py --regime 0 --year 2021
```
```matlab
% 2. in MATLAB (R2023b), from objective4_software_in_loop/matlab:
run_val            % validate_v3_full for regimes 0/1/2 (year 2011)         (~1 min)
run_arm            % three-arm comparison, 2021                             (~1 min)
run_day            % one-day charge/idle/bypass plot, 2021                  (~1 min)
run_d              % restart check, energy balance, 72h hold test            (~1 min)
run_e              % PCM swap, 3 materials x flow multipliers                (~3 min)
run_f              % pump-fix verification + 3-arm day video                 (~2 min)
amanowicz_case     % Amanowicz & Turski tank-level benchmark                 (~5 s)
run_c_scenarios    % 6 edge cases + dead/stuck pyranometer, 3 arms           (~1 min)
run_h              % 20-seed sensor-fault confidence intervals               (~1 min)
```

## What has been verified

| Check | Result |
|---|---|
| Plant physics vs Python (frozen O2 physics) | reproduces to about 1e-13 °C; 100 % identical control decisions |
| Restart correctness (`check_restart`, item 7.1) | **max\|ΔTw\|=0, max\|ΔTpcm\|=0, action agreement 100%** — exact, not approximate |
| Energy closure, 5-point gate (`check_energy_balance`) | arm1/arm2 pass the 0.1% closure gate (0.00%, 0.043%); **arm3 (SAC) reads 0.263%, above the 0.1% gate.** The script normalises the residual by the year's *net* stored-energy change (only 0.31 kWh), so the percentage is inflated. In absolute terms arm 3's residual is 2,973 J (0.83 Wh) against 1,971 kWh delivered, i.e. 4e-5 % of throughput (arm 2: 480 J, 7e-6 %; arm 1: 0). The earlier "action binning" explanation was **not verified**; the cause of the small arm 2 / arm 3 difference is not identified. Treat the gate result as a normalisation artefact plus an unexplained sub-Wh residual, not a demonstrated physics error. |
| Controller identity | `results/sac/r0_smartfc/best_model/best_model.zip` SHA-256 `fb13d841…63aa1b2` matches `docs/DEPLOYMENT_CONTROLLER.md` (and `results/obj4_handoff/policy_sac_r0_smartfc.zip`). The exported actor `export/sac_actor_r0.json` has first-layer weights identical to that model (max difference 0.0); `obs_version` V3, `forecast_mode` smart, **`obs_dim` 15**. |
| O2 design vs twin | `export/plant_params.json` matches `objective2_design_optimization/results/g10_selection_r0.json`: PureTemp 58, 104 capsules, flow 0.03876 kg/s, PCM mass 24.8137 kg, 70.4 kg water, 2.5 m² collector. Checked by value, not by file hash. |
| Sub-step independence (0.05% gate) | all 3 arms pass (0.029% / 0.016% / 0.022%) |
| Exponential plain-tank cool-down | matches analytically to 0.005% |
| Zero-input drift | ≤3.6e-14 °C over 24 h, all arms |

## Three-arm comparison (2021, full year, regime 0)

| Arm | Delivered kWh | Unmet kWh | Shield trips | Hard violations | Thermal efficiency | Demand coverage |
|---|---|---|---|---|---|---|
| 1 — plain tank, B0 | 1853.5 | 684.3 | 17,020 | 0 | 38.5% | 73.0% |
| 2 — PCM tank, B0 | 2002.6 | 488.9 | 39,705 | 0 | 41.5% | 80.4% |
| 3 — PCM tank, SAC | 1971.4 | 499.9 | 18,604 | 0 | 40.9% | 79.8% |

(`export/three_arm_2021.json/.png`.) SAC trades some delivered energy against B0
for far fewer shield interventions (18,604 vs 39,705) — it learns to avoid tripping
the safety limits, B0 does not.

## One-day cycle plots

`export/one_day_cycle_2021.csv/.png`: one full charge → idle → bypass cycle for all
three arms side by side — water temperature, PCM temperature, melt fraction,
collector gain, delivered energy and shield events per hour.

## Edge cases (regime 0, replay year 2011, 10-day window, 4-day spin-up/event/recovery)

Clear, no sunlight, rain/heavy cloud, low temperature, heat wave, noisy sensors
with a 12 h blackout — each run for all 3 arms — plus a dead and a stuck
pyranometer (arm 3 only, scored over the full 10-day window since these are a
standing equipment condition, not a 4-day transient). Single-seed results:
`export/scenarios_3arm/scenario_summary_3arm.csv`, `edge_cases_grid.png`,
`pyranometer_faults.png`.

### 20-seed confidence intervals (item H) — arm 3 (SAC), same 10-day window

| Case | Delivered kWh (mean ± SE) | Shield hours (mean ± SE) | Hard violations (20 seeds) |
|---|---|---|---|
| Healthy (no GHI fault) | 62.78 ± 0.05 | 905.3 ± 4.2 | **0** |
| Dead pyranometer (GHI forced to 0) | 49.10 ± 0.11 | 128.7 ± 5.1 | **0** |
| Stuck pyranometer (frozen at hour 0) | 49.67 ± 0.25 | 183.1 ± 22.4 | **0** |

(`export/scenarios_3arm/sensor_fault_20seed_ci.csv`.) Zero hard-limit violations
across all 60 runs. Both faults cut delivered energy by ~22% (SAC can't see real
sunlight, so it under-charges) and cut shield-trip hours sharply, since a policy
blind to GHI rarely tries hard enough to trip the water-side shield. The stuck case
has much wider seed-to-seed spread than dead (±22.4 vs ±5.1 shield hours) because
what GHI the sensor freezes at depends on exactly when hour 0 falls relative to
sunrise/noise — a single fixed-value fault, but not a fixed-outcome one.

## Hold test / retention (72 h cap, 12 start days, 18:00 local start)

`export/hold_test.csv`, `hold_test_thresholds.csv`. Mean τ_hold to the 45 °C
delivery target: arm1 (plain) 21.6 h, arm2 (PCM+B0) 51.6 h (1/12 censored at 72 h),
arm3 (PCM+SAC) 49.9 h (0/12 censored). By threshold (mean hours, * = still above
at the 72 h cap for at least one start day): 30 °C ≈ 63–65 h* for all arms; 40 °C
≈ 56–64 h* ; 50 °C = 0 h for all arms and all start days (the tank never reaches
50 °C at 18:00 in this design). **Note:** an indexing bug in the original hold-test
script (it printed the correct 18:00 row offset but then used a hardcoded `+19`
regardless) was found and fixed during this work; the numbers above are from the
corrected script.

## PCM swap (item E) — geometry fixed, O1 top-3

`export/pcm_swap_study.csv`. RT57HC (O1 rank 1) delivers the most energy (1989.9–
2015.6 kWh) and holds longest (54.4–54.9 h at 45 °C) of the three materials;
PureTemp 58 (the deployed material, O1 rank 3) and n-Hexacosane (O1 rank 2) are
close behind on delivered energy but n-Hexacosane holds measurably longer.
Objective 2's own selection of PureTemp 58 over the O1-top-ranked RT57HC is a
statistical tie-break (lowest overheating, then τ_serve gain, among designs
statistically indistinguishable on the primary metric) — **not** a throughput
disagreement with Objective 1. Flow sensitivity (0.7×/1.0×/1.3×, PureTemp 58 only)
moved delivered energy and τ_hold by under 0.4% across the full range.
Two caveats stated for this result: geometry is **not** re-optimised per PCM (a
real RT57HC/Hexacosane tank would likely use a different capsule count/fraction),
and the frozen SAC actor was trained on PureTemp 58 only — the RT57HC/Hexacosane
SAC rows are an out-of-distribution evaluation of that same network, not a
retrained or validated policy for those materials.

## Benchmark against Amanowicz & Turski 2025 (item G)

`export/amanowicz_benchmark.json`. Tank-level cool-down comparison (RT44HC
capsules, 9.6 L lab tank), using a sphere matched to the real cuboid capsule's
PCM mass and surface/volume ratio (D=47.9 mm, N=39.0 equivalent spheres for the
real 1.8 kg total PCM). The tank's own heat-loss UA was fit once from the
water-only case (reproduces its 14 K drop exactly by construction) and then
carried unchanged into the water+capsule case — nothing in `pcm_plant_hour.m`
was recalibrated. Result: simulated drop 15.99 K vs. measured 26 K — **38.5%
error, outside the requested 15% band.** This is the same direction of error
Objective 2's own capsule-level benchmark already found (the Wakao-Kaguei/
lumped-sphere capsule conductance moves heat too slowly, in both directions) —
carried forward here, not re-derived. **A model that is slow to move heat into
capsules is also slow to move it out, so this result is the error bar on every
retention (τ_hold) number above: they are biased optimistic (over-stated).**
Three further limitations: shape mismatch (real capsules are cuboid, the model
only has a sphere correlation), direction mismatch (the paper charges PCM with
hot water; this project's retention test discharges PCM into cooling water —
agreement on one is supporting evidence for the other, not proof), and no
digitised curve (only the paper's two headline drop numbers were used directly;
the primary PDF could not be fetched this session to digitise Figure 7).

## Pump-bug fix and 3-arm day video (item F)

`animate_system.m`'s pump indicator used to key off `a_exec==CHARGE && GHI>cutoff`,
which missed the case where `pcm_plant_hour.m` itself forces zero circulation
mid-hour (computed collector gain would be negative) while still reporting
`a_exec` as CHARGE — the animation showed the pump running at zero real
collector gain. Fixed to key off the real `Q_coll_Wh` output; verified against
all 3 arms over the full year 2021 (0 invariant violations under the new rule;
the old rule would have shown the pump running at zero gain for 1,520 hours
across the three arms). Video: `video/o4_three_arm_day071_2021.mp4` (`run_f` writes it to `../../results/`; a copy is kept in `video/`) — day 71 of
2021 (the day in `one_day_cycle_2021.png`, where the PCM melts fully), all 3
arms side by side (water temp, PCM temp, melt %, collector gain, pump state),
1-hour steps, CHARGE/IDLE/BYPASS shaded and labelled per arm, MP4, 1920×1080,
12 fps, 115 frames (9.6 s). The earlier day-313 video (PCM never melts) was
replaced. Re-render with `run_f(71)`.

## Known cosmetic limits of the animation

- Text labels for the tank and collector are partly covered by pipes, and the
  sun rays are decorative, not aimed at the collector.

## Risks and limitations

- **Software only.** This is emulated validation against the same physics the
  controller was trained on, not a hardware or field trial.
- **Single training seed (42).** The SAC policy is one trained network from one
  seed, matching this project's convention elsewhere (`..._s42_...` result
  files); there is no multi-seed training ensemble. The 20-seed result above
  (item H) is robustness to *sensor noise*, not to training variance.
- **2021 was a checkpoint-selection year**, so every result in this document is
  a fidelity check (does the twin reproduce the trained policy's own behaviour?),
  not an unbiased out-of-sample performance figure.
- **Forecast fields are supplied, not sensed.** The smart-forecast observation
  inputs are built from the stored clear-sky column; a live analytic clear-sky
  model has about 17.6% error at +1 h (9.9% with the stored column used here) —
  deployment on a live forecast would see more forecast error than any result
  above reflects.
- **Next-hour demand was perfect in training.** The policy's demand input is the
  true next-hour draw during training; no demand-forecast error is modelled
  anywhere in this twin.
- **Pyranometer dependence.** Item H shows delivered energy drops ~22% under a
  dead or stuck pyranometer — the controller is materially dependent on a
  working irradiance sensor, even though the safety shield itself never fails
  (0 hard violations in any of the 60 runs).
- **Hold times are model values**, not measurements. The Amanowicz & Turski
  benchmark (item G) shows this capsule model runs slow in both directions, so
  every τ_hold figure in this document should be read as an upper bound, not a
  prediction of real retention time.
- **DQN and PPO are excluded.** Only the SAC controller is evaluated for Tamil
  Nadu (Rajasthan uses DQN); no cross-algorithm comparison is attempted here.
- **Regime 1's smart-forecast sensor-fault behaviour is not checked.** All
  sensor-fault and edge-case results in this document are regime 0 only.
