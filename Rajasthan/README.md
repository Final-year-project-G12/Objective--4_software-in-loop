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
| Simulink model `pcm_drl_twin_rj.slx` (`build_pcm_twin_model.m`, `run_twin.m`) | **Not built.** The installed MATLAB has no Simulink. The builder script is written but has never run. |
| Generated C code of the controller (`verify_codegen.m`) | **Not done.** Needs MATLAB Coder, which is not installed. |

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

- The Simulink model and the generated C code do not exist yet (no Simulink or MATLAB Coder in the
  installed MATLAB). `build_pcm_twin_model.m`, `run_twin.m` and `verify_codegen.m` are unexecuted.
- Animations exist for regime 1 only. Regimes 0 and 2 would show the always-charge policy.
- In the animation the state text reads CHARGE at night because that is the policy's command; the
  pump is drawn stopped when there is no sun (same cosmetic limit as Tamil Nadu).
- The plant is the model the policy was trained on. Agreement with it is not agreement with a real tank.
  Comparison with published experimental results is not part of this folder.
- The 3-hour GHI forecast in the observation is the true future weather (a perfect forecast).
- Sensor noise is applied to GHI, ambient, top, bottom, mean and PCM temperature. Melt fraction and the
  two energy fields are estimator outputs and are passed through without error.
- The interlock latches on a single over-limit reading and has no debounce (same as Tamil Nadu).
- Rain has no physics of its own; it enters only as lower irradiance and ambient temperature.
- The 50 L / 1.5 m² system is below the 40–100 L/m² band of IS 12976:2023 (a standing Objective 2 limitation).
- The policy decides hourly; the shield inside the plant acts at every solver sub-step (150 s or shorter).
