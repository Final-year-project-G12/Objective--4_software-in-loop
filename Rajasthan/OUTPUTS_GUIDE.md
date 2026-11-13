# Objective 4 (Rajasthan) – Outputs Guide (what every output is, where inputs come from, how to run it yourself)

## 1. The short version

- **Inputs** come from Objectives 2 and 3 (plant design, weather, demand, the trained DQN controller). Nothing is typed in by hand.
- **Algorithms:** the trained **DQN** neural-network controller (from Objective 3), plus physics models (collector, 10-node stratified water tank, PCM melting) and a rule-based safety interlock. No new learning happens in Objective 4.
- **Outputs from MATLAB (R2026b):** per regime, a full-year validation report, a scenario summary table (CSV) and one result plot per scenario in `export_r*/scenarios/`; for regime 1 also the animation videos.
- **The same checks from the Python mirror** in `export_r*/python_mirror/` (an independent cross-check with the same numbers).
- **Not produced:** the Simulink model and the generated C code. The installed MATLAB has no Simulink and no MATLAB Coder.
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
| `matlab/pcm_drl_twin_rj.slx`, `matlab/twin_consts.mat` | Simulink model and its compiled-in constants | No: needs Simulink + Stateflow |
| `export_r*/codegen_c/`, `codegen_verification.json` | C code of the controller and the check that it decides like MATLAB | No: needs MATLAB Coder |

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

**The Simulink block diagram (needs Simulink, not installed; never run):** `build_pcm_twin_model(1)`, then `open_system('pcm_drl_twin_rj')`. The model is regime-specific (its constants are compiled in), so rebuild it to change regime.

**Generated C code (controller only; needs MATLAB Coder, not installed; never run):**

```matlab
regime = 1; verify_codegen
```

**Timing on this laptop:** six scenarios with plots about 1 minute per regime; full-year validation about 6 seconds per regime.

**Plots look dark?** MATLAB R2025a and later draw figures in the desktop's theme. `run_scenarios.m` and `animate_system.m` force the light theme so the outputs suit a report.

---

## 7. Honest limits

- This is **emulated validation** (software-in-the-loop). No physical rig was used, and no comparison with published experiments is made here.
- The Simulink model and generated C code are missing (toolboxes not installed); those three scripts are unexecuted.
- The forecast fields of the observation are the true future weather (a perfect forecast). A real device would use a forecast with errors.
- Melt fraction, stored energy and recoverable energy are treated as perfect estimator outputs.
- Rain only reduces sunlight and air temperature; there is no frost or wet-surface model.
- Regime 0 and 2 policies are always-charge, so their DQN and B0 results are identical.
- 2023 is a validation year: the policy was selected using it, so these runs are a fidelity check, not an unbiased performance figure.
