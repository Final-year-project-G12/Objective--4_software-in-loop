# Objective 4 (Rajasthan) – Outputs Guide (what every output is, where inputs come from, how to run it yourself)

## 1. The short version

- **Inputs** come from Objectives 2 and 3 (plant design, weather, demand, the trained DQN controller). Nothing is typed in by hand.
- **Algorithms:** the trained **DQN** neural-network controller (from Objective 3), plus physics models (collector, 10-node stratified water tank, PCM melting) and a rule-based safety interlock. No new learning happens in Objective 4.
- **Outputs from MATLAB (R2026b):** per regime, a full-year validation report, a scenario summary table (CSV) and one result plot per scenario in `export_r*/scenarios/`; for regime 1 also the animation videos.
- **The same checks from the Python mirror** in `export_r*/python_mirror/` (an independent cross-check with the same numbers).
- **Improvement plan v2 outputs** (retention test, PCM swap, simulation matrix, tank-level benchmark, figures F1-F8, animations A1-A3) are in `results_campaign/`, described in section 8.
- **Simulink:** the model was built and run for one week of regime 1 (passes). Generated C code of the controller: verified for regime 1 (100 % identical decisions).
- **Videos are not recordings of a real device.** MATLAB runs the simulation, then draws one picture per simulated time step and joins them into an MP4.

---

## 2. Where the inputs are taken from

| Input | Origin | File used by the twin |
|---|---|---|
| Tank, collector, PCM, capsule and safety-limit numbers | Objective 2 Rajasthan design, Objective 3 contract (`contracts/obj3_environment_contract_rajasthan_v3.json`) | `export_r*/plant_params.json` |
| Hourly sunlight (GHI), air temperature, hour of day, 2023 (8760 h) | Rajasthan point-year weather of the regime's medoid point (Objective 2 files) | `export_r*/weather_2023.csv` |
| Hot-water demand per hour of day | Objective 2 demand model | inside `plant_params.json` |
| Controller weights (neural network 17-64-64-3) | Objective 3 released DQN models (`results/gen2/gen2_selected_dqn.json`) | `export_r*/dqn_qnet_r<k>.json` |
| Python reference run (only for checking the twin) | Objective 3 environment | `export_r*/reference_2023.csv` |

They are produced by one script, `export_from_python.py`, and can be regenerated at any time:

```bash
python export_from_python.py --regime 1
```

| Regime | Medoid point | PCM | Controller model used | What the policy does |
|---|---|---|---|---|
| 0 | RJP_0132 (Udaipur) | savE OM55 | `dqn_r0_w0.975_s0_V3_60min_dr` | always CHARGE (same as B0) |
| 1 | RJP_0192 (Nagaur) | PureTemp 60 | `dqn_r1_w1.7_s42_V3_60min_dr` | CHARGE, with IDLE around noon on hot days (356 IDLE hours in 2023) |
| 2 | RJP_0083 (Jaipur) | PureTemp 58 | `dqn_r2_w0.425_s0_V3_60min_dr` | always CHARGE (same as B0) |

Each exported JSON records the model's SHA-256; all three equal the hashes Objective 3 recorded.

The weather data are real hourly values; the **edge cases are made by editing the real April 2023 weather** (section 4), not by inventing weather.

**Why 2023:** 2011–2015 (Objective 2's held-out test) and 2006–2010 (Objective 3's one-shot locked test) may not be re-used, so the replay uses a validation year. The export script refuses any other kind of year.

---

## 3. Algorithms and methods used (and where)

| Step in the chain | Method | Where | Learned or fixed |
|---|---|---|---|
| Decision: CHARGE / IDLE / BYPASS each hour | **Deep Q-Network (DQN)**, 3 layers, action = largest Q-value | `dqn_policy.m` | Trained in Objective 3; only evaluated here |
| Observation | 17 fixed-scale fields, clipped to [−5, 5] | `build_obs.m` | Fixed |
| Sensors | Gaussian noise + 1 % dropout + blackout flag | `sensor_model.m` | Fixed model |
| Safety | Interlock: stale sensors force BYPASS; hard-limit fault latches | `safety_interlock.m` | Fixed rules |
| Solar collector | Linear (Hottel–Whillier) collector, differential controller | `pcm_plant_hour.m` | Physics |
| Water tank | **10 stacked nodes**: implicit upwind advection, axial conduction, stratified collector return, mixing of inversions, heat loss per node | `pcm_plant_hour.m` | Physics |
| PCM capsules | Enthalpy method per node (melt fraction), Wakao–Kaguei heat transfer, aluminium wall heat capacity | `pcm_plant_hour.m` | Physics |
| In-plant safety shield | Cuts the collector loop at 72 °C (top node) and PCM charging at 62 °C, checked every sub-step | `pcm_plant_hour.m` | Fixed rule |
| Baseline B0 | Always CHARGE | `dqn_policy.m` (mode 1) | Fixed |
| Animation | MATLAB graphics objects updated per frame, `VideoWriter` MPEG-4 | `animate_system.m` | Drawing only |

No training, optimisation or machine learning runs in Objective 4.

---

## 4. How the outputs vary between scenarios

All scenarios use the same real 10 days of April 2023 weather. **Days 1–4 and 9–10 are identical in every scenario.** Only days 5–8 (the "event") are changed.

| Scenario | What is changed on days 5–8 | What changes in the result (regime 1) |
|---|---|---|
| Clear | nothing | Top node reaches the 72 °C guard band every afternoon; PCM melts fully around midday and is solid again in the evening; DQN goes IDLE for about 2 h at noon |
| No sunlight | sunlight = 0 | Pump stays off, tank sits at mains temperature, PCM stays solid, about 0.2 kWh delivered (heat left from day 4) |
| Rain / cloud | sunlight × 0.12 (max 120 W/m²), air −5 °C | Tank barely warms, PCM stays solid, 2.5 kWh delivered |
| Low temperature | air −12 °C, mains water −8 °C (mains for the whole run), sunlight × 0.9 | Tank still reaches about 71 °C; the DQN idles at noon and loses 13 % of delivery against B0 |
| Heat wave | air +9 °C, sunlight × 1.15 | Guard band reached sooner; B0 has 23 shield hours, DQN 3.3 |
| Sensor fault | noise + 12-hour sensor blackout | Fail-safe BYPASS during the blackout, then normal operation resumes |

### What each output file is

| File | Content | Exists now? |
|---|---|---|
| `export_r*/python_mirror/validation_report.json` | Full-year proof that the twin algorithm matches Objective 3 (open loop, policy only, closed loop) | Yes |
| `export_r*/python_mirror/scenario_summary.csv` | One row per scenario and policy: delivered kWh, unmet kWh, shield trips, shield hours, hard violations, min/max temperatures, melt fraction at the event end, hours with top node ≥ 45 °C, hours the policy did not charge, fail-safe hours | Yes |
| `export_r*/python_mirror/<scenario>.png` | 5-panel plot: weather, top/bottom/PCM temperature against limits, melt fraction, commanded vs executed action, cumulative energy. DQN solid, B0 dotted | Yes |
| `export_r*/scenarios/<scenario>.png`, `scenario_summary.csv`, `validation_closed_loop.json` | The same three things produced by MATLAB (`run_scenarios`); these are the ones to use in the report | Yes |
| `export_r*/validation_report.json` | MATLAB full-year check (`validate_against_python`) | Yes |
| `export_r1/scenarios/*_animation.mp4`, `*_frame.png`, `my_*.mp4` | Animated schematic videos and stills. Ten-day videos: clear, no_sunlight, rain_cloud, low_temperature. Days 4-9 clips: heat_wave (DQN and B0), low_temperature, sensor_fault | Yes, regime 1 only |
| `matlab/pcm_drl_twin_rj.slx`, `matlab/twin_consts.mat` (+ cache `.slxc`, `slprj/`) | Simulink model and its compiled-in constants (regime 1) | Built and run once on 14 Nov 2026, then deleted; rebuilt automatically by `run_twin.m` or `validate_against_python(1, 2023, 168, true)` |
| `export_r1/validation_simulink_168h.json` | One week through the Simulink model: 100 % identical actions, 13.04 = 13.04 kWh. The only place a 168 h report is kept; `export_r*/validation_report.json` are the full-year (8760 h) reports | Yes |
| `export_r1/codegen_c/`, `codegen_mex/`, `codegen_verification.json` | C code of the controller and the check that it decides like MATLAB and Python over 8760 h (9 files, 1163 lines, 100 % identical) | Yes, regime 1 (14 Nov 2026) |

Columns to read with care:
- **shield_trips_event** counts guard-band activations per sub-step, and on the PCM side per node. Values are in the thousands. Use **shield_hours_event** to compare policies.
- **Tw_...** columns refer to the top node.
- **idle_or_bypass_hours_event** is how many event hours the policy chose not to charge. It is 0 for B0 and for the regime 0 and 2 policies.

---

## 5. How the videos are made (MATLAB)

1. `simulate_hours` runs the closed loop hour by hour and keeps a log: node-derived temperatures, melt fraction, action, shield trips, sunlight, demand.
2. `animate_system` takes that log. For each hour it sets: sun size and rays from sunlight; the upper half of the tank from the top-node temperature and the lower half from the bottom-node temperature; capsule colour from melt fraction; pump icon and moving water dots from the action; and text from the numbers.
3. Each hour is drawn as several frames; every frame is captured with `getframe` and written to an MP4 with `VideoWriter`.

The water movement is schematic (dots along the pipes), not a computed flow field. The two-band tank is a simplification of the ten nodes.

---

## 6. Run it yourself

**Without MATLAB:**

```bash
python sil_python_mirror.py --regime 1
```

Use the project environment at `D:\Final Year Project\.venv`. It takes about a minute and rewrites `export_r1/python_mirror/`.

**In MATLAB** (tested with R2026b; base MATLAB is enough for everything in this block), in the Command Window:

```matlab
cd 'D:\Final Year Project\Objective--4_software-in-loop\Rajasthan\matlab'

% all six scenarios, plots, summary table (no videos)
regime = 1; doAnim = false; run_scenarios

% full-year check against Python
validate_against_python(1)

% one video, one scenario (about half a minute to render; a ten-day video takes about 2 min)
make_my_video('regime', 1, 'scenario', 'heat_wave')
make_my_video('regime', 1, 'scenario', 'low_temperature', 'policy', 'b0')   % b0 = always-charge baseline

% your own weather: 30% sunlight, 6 degC colder, on days 5-8, film days 4-9
make_my_video('scenario', 'custom', 'ghi_mult', 0.3, 'tamb_offset', -6, 'days', [4 9])
```

**Running the controller only (no video):**

```matlab
tw = load_twin_params('../export_r1', 2023);
W  = tw.wx.signals.values(90*24 + (1:243), 1:4);   % 10 days of April + 3 h for the forecast
L  = simulate_hours(tw, W, tw.P, 0, 0, [], 240);   % 0 = trained DQN, 0 = ideal sensors
plot(L.Tw); hold on; plot(L.Tbot); plot(L.Tpcm)
```

**The Simulink block diagram:** `validate_against_python(1, 2023, 168, true)` builds `pcm_drl_twin_rj.slx` and runs one week through it (about 2 minutes; note this call overwrites `export_r1/validation_report.json` with the one-week report, so run `validate_against_python(1)` again afterwards). The model is regime-specific (its constants are compiled in), so rebuild it to change regime.

**Generated C code (controller only; needs MATLAB Coder and a C compiler, MinGW64 here; verified for regime 1):**

```matlab
regime = 1; verify_codegen
```

**Timing on this laptop:** six scenarios with plots about 1 minute per regime; full-year validation about 1 minute per regime (a closed-loop year takes 12-20 s); Simulink 0.78 s per simulated hour.

**Improvement plan v2 (regime 1):**

```bash
D:\Final Year Project\.venv\Scripts\python.exe build_campaign_config.py --regime 1
```
```matlab
check_energy_balance(1)          % about 3 min
benchmark_amanowicz              % seconds
run_campaign                     % about 10 min; run_campaign({'core'}) / {'flow'} / {'regimes'} / {'supercool'} / {'seeds'} / {'scen'} for one pass
run_campaign({'core','flow'}, '_cal', struct('c', 5.0296))    % capsule constant overridden; files get the suffix
diagnose_capsule; calibrate_capsule; compare_calibration; diagnose_substep(1)
plot_pack                        % F1-F8 (about 2 min); plot_pack({'A1','A2','A3'}) for the three animations (about 6 min)
```

**Plots look dark?** MATLAB R2025a and later draw figures in the desktop's theme. `run_scenarios.m` and `animate_system.m` force the light theme so the outputs suit a report.

---

## 7. Honest limits

- This is **emulated validation** (software-in-the-loop). No physical rig was used. One tank-level comparison with a published experiment is in section 8: the capsule model matches it to 1.1-1.4 K when the capsule geometry is mapped correctly, and the single-sphere Tan 2009 case is still faster in the experiment. A faster-capsule run lengthens hold times by 0.4-1.7 h, so the frozen hold times are not optimistic.
- The Simulink model was run for one week only. The generated C was verified for regime 1 only.
- The forecast fields of the observation are the true future weather (a perfect forecast). A real device would use a forecast with errors.
- Melt fraction, stored energy and recoverable energy are treated as perfect estimator outputs.
- Rain only reduces sunlight and air temperature; there is no frost or wet-surface model.
- Regime 0 and 2 policies are always-charge, so their DQN and B0 results are identical.
- 2023 is a validation year: the policy was selected using it, so these runs are a fidelity check, not an unbiased performance figure.

---

## 8. Improvement plan v2 outputs (`results_campaign/`, regime 1, year 2023)

Inputs: `build_campaign_config.py` reads Objective 2's copy of the Objective 1 files (`objective2-rajasthan/data/objective1/`, never the Objective 1 repository), the state config, `g10_selection_r1.json` and the exported DQN, stops if the cluster count is not 3 or the shortlist disagrees with the state config, and writes `campaign_config.json` with the SHA-256 of every input. Everything below is produced by MATLAB from that file and `export_r1/`.

| File | Content |
|---|---|
| `campaign_config.json` | Top-3 PCMs with properties, Objective 2 design and repeatability band, controller reference, input hashes |
| `campaign_results.csv` | One row per run (13 rows: water-only, 3 PCMs x {B0, DQN}, flow 0.7x and 1.3x). Columns: identifiers, delivered energy at 45 and 50 °C (year and 18:00-09:00 window), unmet energy, guard-band hours, hard-limit hours, shield activations, melt cycles per year, hours with melt fraction 0.1-0.9, pump-on hours and pumped volume, energy per kg PCM and per m² collector, hold time at 30/40/45/50 °C with censored counts, top temperature / melt fraction / recoverable and stored energy at 24/36/48/72 h, standby loss, and the gain over the water-only tank at the same flow with a flag for gains inside Objective 2's repeatability band |
| `campaign_regimes.csv` | Same columns for the three Rajasthan regimes (own PCM, B0 and DQN, water-only) |
| `ranking_check.csv` | Objective 1 rank against the twin's rank and Spearman correlation (three items) |
| `sensor_fault_seeds.csv` | 20 noise seeds of the sensor-fault case |
| `scenario_summary_r1.csv` | Copy of the six edge cases (`run_scenarios.m`, unchanged) |
| `hold_curves/<run_id>.csv` | Hourly retention traces of the 12 start evenings of one run (top, bottom, mean water, PCM, melt fraction, stored and recoverable energy, cumulative loss) |
| `year_trace/<run_id>.csv` | Hourly trace of a full-year run with the 10 node temperatures (water-only, PCM + B0, PCM + DQN of PureTemp 60 at nominal flow) |
| `energy_balance_report_r1.json` | The restart, closure, swap, exponential, zero-input and sub-step results |
| `benchmark_amanowicz_curves.csv`, `benchmark_amanowicz_summary.csv` | The twin against the paper's printed fits, six variants (one sphere per capsule, same-area sphere, and the surface/volume-matched spheres, each with the loss coefficient from the paper or fitted) |
| `capsule_sensitivity.csv`, `capsule_regression.json`, `_diag_log.txt` | Diagnosis (`diagnose_capsule.m`): RMSE and bias of the benchmark against c, F and the film coefficient for two capsule mappings, the same constants on Tan 2009 and Dong 2022, and the regression of the single-capsule set-up on Objective 2's numbers |
| `capsule_calibration.csv`, `capsule_calibration.json` | Calibration (`calibrate_capsule.m`): c fitted on Amanowicz & Turski and scored on Tan 2009 and Dong 2022 (held out) for four candidate values |
| `campaign_results_cal.csv`, `campaign_results_fast.csv`, `ranking_check_cal.csv`, `ranking_check_fast.csv`, `provenance_cal.json`, `provenance_fast.json`, `hold_curves/*_cal.csv`, `*_fast.csv` | The core and flow campaigns re-run with c = 5.03 (calibrated) and c = 7.10 (fast-melt bound); the default files (c = 5) are kept |
| `calibration_effect.csv` | Per run: tau_hold, window energy and other metrics frozen / calibrated / fast, with the changes |
| `supercooling_sensitivity.csv` | Hold test with the melt band moved 2 K down (supercooling proxy), PureTemp 60, B0 and DQN |
| `dead_pyranometer_year.csv`, `dead_pyranometer_seeds.csv`, `edge_cases_with_dead_pyranometer/` (seven-scenario `scenario_summary_with_dead_pyranometer.csv` + plots), `figures/F9_edge_cases_with_dead_pyranometer.png` | Dead-pyranometer case: the controller's irradiance reads 0 for the whole run, real sun unchanged. Year (B0 and DQN, healthy against dead), 20 seeds on the 10-day window, and the seven-scenario table. The six-scenario `export_r1/scenarios/scenario_summary.csv` is unchanged. The interlock never triggers on this fault |
| `substep_attribution_r1.json` | Where the sub-step difference comes from (melting hours against other hours, pump on against off, PCM tank against water-only tank); `diagnose_substep.m` |
| `provenance.json` | Input hashes, MATLAB version and toolboxes, run date |
| `figures/F1..F8_*.png` | Tank temperature map; operating trace with the 10 layers; retention curves; retention bars (error bars: SD over 12 starts, and Objective 2's band on window energy); three regimes side by side; ranking check; flow sensitivity; experiment comparison |
| `figures/A1_schematic_clear_days.mp4` | Schematic animation, pump drawn only when the collector adds heat |
| `figures/A2_retention_72h.mp4` | Same schematic with the sun off: 72 h of cooling from the best of the 12 evenings |
| `figures/A3_tank_3D_retention.mp4`, `A3_tank_3D_frame.png` | 3-D cutaway of the same hold: layer colours = temperature, capsule colours = melt fraction. A 3-D view of a 1-D result; the capsule ring layout is illustrative |
| `figures/B_simulink_block_diagram.png` | The Simulink model as built by `build_pcm_twin_model.m` |
| `_*_log.txt` | MATLAB console logs of the runs |

Definitions used: **tau_hold** = hours from 18:00 that the top layer stays at or above the threshold, linear inside the hour, capped at 72 h (Objective 2's definition; a run still above at 72 h is "censored"); **window** = 18:00-09:00; **gain** = the same quantity minus the water-only tank at the same flow, weather and demand (Objective 2's own yardstick). The retention start is the end of the 17:00 hour, state taken from the full-year run (the whole node temperature and enthalpy vectors, not two scalars). The twin's initial PCM state is Objective 3's "solid" reset (Ts - 5 K), also used for swapped PCMs.

Things that could be mistaken for results of something else:
- In the water-only tank "PCM temperature" means mean water temperature; its PCM limits are switched off in the interlock.
- `E_rec45` is recoverable energy above 45 °C, which is the Rajasthan contract target.
- The 30 °C column of the hold time is censored in every run; it exists only for comparison with Chen et al. 2025.
- `pump_electrical_Wh` (in `campaign_results*.csv`) is the capsule bed's Ergun share only (head 0.0136 Pa, about 0.005 Wh per year): a lower bound, not a pump energy. It is empty for regimes 0 and 2.
- Not done: a cross-state version of figure F5 (needs the other twins' campaign outputs; F5 shows the three Rajasthan regimes), and option C1, the 3-D single-capsule check (needs the Partial Differential Equation Toolbox; the Tan 2009 / Dong 2022 held-out check covers the capsule question).
- The sub-step gate (0.05 %) is not met: `energy_balance_report_r1.json` has `substep_pass: false` and `substep_attribution_r1.json` says why (sensible-heat hours, not melting hours).
- The capsule constant c is not changed anywhere: `run_campaign` only overrides it for the `_cal` and `_fast` sensitivity files.
- Retention figures from the literature (Chen et al. 2025: 31.7 h above 30 °C, 30 L/day, RT35HC) are not this folder's measurements; this folder's are at 45 °C on 300 L/day. See README.
- Handoff export re-run (14 Nov 2026, scratch folder): byte-identical to `export_r0/`, `export_r1/`, `export_r2/`; nothing replaced. `build_campaign_config.py` prints a five-line parameter check (tank volume, collector area, PCM mass, flow) against Objective 2: all PASS, with the 33.3 L/m2 limitation against IS 12976:2023.
- Not done: option C1 (3-D single capsule): the Partial Differential Equation Toolbox is not installed. 

## 9. Tamil Nadu-layout files (added 14 Nov 2026; new files only)

| File / folder | Content |
|---|---|
| `export_r1/three_arm_2023.csv/.json/.png` | Three arms over 2023: delivered, unmet, shield activations, hard violations, thermal efficiency, demand coverage (+ guard-band hours, window and collector energy) |
| `export_r1/one_day_cycle_2023.csv/.png` | One day (165) hour by hour for the three arms, six-panel plot |
| `export_r1/scenarios_3arm/` | Edge cases for plain tank, PCM + B0, PCM + DQN: `scenario_summary_3arm.csv` (9 scenarios x 3 arms), one plot per scenario, `edge_cases_grid.png`, `pyranometer_faults.png`, `video/edge_<scenario>.mp4` |
| `export_r1/hold_test.csv`, `hold_test_thresholds.csv` | Hold test per arm and start day (45 C table and 30/40/45/50 C thresholds), 72 h cap |
| `export_r1/pcm_swap_study.csv/.json` | O1 top-3 PCMs x flow x0.7/1.0/1.3 x B0/DQN (from `results_campaign/campaign_results_flowall.csv`) |
| `export_r1/restart_check.json`, `energy_balance_report.json`, `amanowicz_benchmark.json` | Views of the check results in `results_campaign/` under the Tamil Nadu file names |
| `export_r1/pump_check_2023.json` | Hours the old animation rule drew the pump on without collector gain (169-174 per arm), and 0 violations with the new rule |
| `video/` | `o4_three_arm_day165_2023.mp4`, `o4_3d_day165_2023.mp4`, `o4_3d_edge_clear_2023.mp4`, `o4_3d_edge_no_sunlight_2023.mp4`, `o4_3d_hold72h_day165_2023.mp4` |
| `pictures/` | Stills from the videos, `<video>_<seconds>s.png` |
| `reports/` | `00_AUDIT_SUMMARY.md`, A (validation and three-arm), B (one-day plots), C (edge cases), D (checks and hold test), E (PCM swap), F (pump fix and video), G_H (benchmark and sensor faults), I (requirements checklist and video index) |
| `docs/` | `OBJECTIVE4_RAJASTHAN_SCOPE.md`, `plan_O4.md` |

Pyranometer faults in the three-arm table: dead (reads 0), stuck at 500 and stuck at 1000 W/m2 (constant for the whole run), real sun unchanged; definitions in the header of `matlab/edge_scenarios.m`. Not done: option C1 (3-D single capsule: the Partial Differential Equation Toolbox is not installed).
