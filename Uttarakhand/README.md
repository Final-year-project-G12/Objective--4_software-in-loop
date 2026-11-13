# Objective 4 — Software-in-the-loop validation, Uttarakhand (no hardware)

A MATLAB/Simulink digital twin of the Uttarakhand PCM solar water heater, driven by the frozen
Objective 3 **PPO** controller. It is the Uttarakhand counterpart of `../Tamilnadu/` and follows the same
steps (export from Python → MATLAB plant/policy port → validation against Python → edge cases →
plots, summary table, animations → Simulink model → C code of the controller).

**Status: emulated validation only.** It shows the controller behaves as in Objective 3 on the same
physics it was trained on. It is not experimental validation; the hardware steps in
`<O3 uttarakhand>/results/o4_handoff/r<k>/deployment_test_plan.md` (bench interlock, shadow mode,
hardware-in-the-loop) remain.

## What is different from Tamil Nadu

| | Tamil Nadu (`../Tamilnadu`) | Uttarakhand (this folder) |
|---|---|---|
| Plant | single water node + PCM node (`_run_one_hour`) | O2's **10-node stratified** tank with PCM per node (`tank_model_multinode._kernel`), stepped hourly as `o3/stepper.py` |
| Controller | SAC, 11 → 256 → 256 → 1, tanh, binned into 3 actions | **PPO**, 15 → 64 → 64 → 2, tanh, argmax |
| Actions | CHARGE / IDLE / BYPASS | **ENABLE / BYPASS** (collector-loop pump); IDLE = BYPASS in O2's kernel |
| Observation | 11 fields, fixed affine scaling, clip ±5 | 15 fields (top/bottom/mean water T, PCM T, melt, GHI, T_amb, hour sin/cos, draw, mains, stored & recoverable energy, minutes since draw, previous action), standardised with the frozen train-year mean/std |
| Delivery target | 45 °C | **50 °C** (`E_del50`, O2's primary metric; 18:00–09:00 window reported too) |
| Shield metric | shield events per sub-step | shield **hours** (O2's definition), plus sub-step counts |
| Sensor-fault fail-safe | BYPASS | **B0 = always enable** under the in-plant shield (Uttarakhand hand-off spec) |
| Year replayed | 2011 | **2010** (an O3 test year, read post-lock → **EXPLORATORY**) |
| Regimes | 0, 1, 2 | 0, 1 (primary), 2; regime 3 has no PCM controller (O2: PCM gives no gain) |

## Folder layout

| Path | Purpose |
|---|---|
| `export_from_python.py` | Freezes the kernel arguments (P vector, node masses, capsules per node, loss UA, reset state, demand), weather, PPO weights + normalisation and a Python reference run into `export*/`. Reads the Uttarakhand Objective 3 (`solar-pcm-control--Objective3/uttarakhand`, its `o4_handoff` policies and the frozen O2 snapshot inside it). |
| `export/`, `export_r1/`, `export_r2/` | Generated inputs for MATLAB, regimes 0 / 1 / 2. Results go to `export*/scenarios/`. |
| `matlab/pcm_plant_hour.m` | One hour of the O2 multinode kernel. Line-for-line port. |
| `matlab/ppo_policy.m` | The frozen PPO actor (15-64-64-2) as a plain function. |
| `matlab/build_obs.m`, `initial_record.m`, `sensor_model.m`, `safety_interlock.m` | Observation vector, reset record, sensor noise/dropout, stale-sensor and fault-latch fail-safe. |
| `matlab/simulate_hours.m` | Closed loop: sensors, observation, policy, interlock, plant. |
| `matlab/run_scenarios.m` | Validation, six edge cases, plots, summary table, animations. |
| `matlab/validate_against_python.m` | Full-year open-loop plant replay, policy check, closed loop, Simulink check. |
| `matlab/animate_system.m`, `make_my_video.m` | Animated schematic (stratified tank, capsules, pump, flow). |
| `matlab/build_pcm_twin_model.m`, `run_twin.m` | Builds and runs the Simulink model `pcm_drl_twin.slx`. |
| `matlab/controller_step.m`, `verify_codegen.m` | Controller as one function, compiled to C and checked against MATLAB and Python. |

## How to run

```powershell
# 1. export from Python (Uttarakhand O3 venv; already done for regimes 0, 1, 2, year 2010)
$py = "D:\solar-pcm-control--Objective3\uttarakhand\.venv\Scripts\python.exe"
& $py Uttarakhand\export_from_python.py --regime 1             # -> export_r1
& $py Uttarakhand\export_from_python.py --regime 0             # -> export
& $py Uttarakhand\export_from_python.py --regime 2             # -> export_r2
# a validation year instead of the test year (no lock involved):
& $py Uttarakhand\export_from_python.py --regime 1 --year 2022
```
```matlab
% 2. in MATLAB (R2023b or later; Simulink only for the .slx twin, MATLAB Coder only for verify_codegen)
cd Uttarakhand/matlab
validate_against_python(1)            % full year, PASS/FAIL report -> export_r1/validation_report.json
regime = 1; run_scenarios             % validation + edge cases + plots + animations
regime = 0; doAnim = false; run_scenarios
make_my_video('regime', 1, 'scenario', 'no_sunlight')
regime = 1; verify_codegen            % C code of PPO + interlock, checked against MATLAB and Python
```

## What has been verified (MATLAB R2026b, year 2010, fully solid start, deterministic demand)

`validate_against_python(k)` -> `export*/validation_report.json`, all **PASS**:

| Check | r0 | r1 | r2 |
|---|---|---|---|
| A. Open-loop plant replay, 8760 h: max \|ΔT_top\| | 1.6e-13 °C | 2.1e-13 °C | 1.9e-13 °C |
| A. E_del50 year, MATLAB vs Python | 1100.89 = 1100.89 kWh | 1169.5 = 1169.5 kWh | 1212.30 = 1212.30 kWh |
| A. Shield hours, MATLAB vs Python | 2.632 = 2.632 h | 0.847 = 0.847 h | 0.181 = 0.181 h |
| A'. PPO on Python's own observations: identical actions | 100 % | 100 % | 100 % |
| B. Closed loop (sensors, observation, PPO, interlock, plant), 8760 h: identical actions | 100 % | 100 % | 100 % |
| B. Window (18–09 h) E_del50 | 558.87 = 558.87 kWh | 584.6 = 584.6 kWh | 601.32 = 601.32 kWh |
| Exported actor (numpy) vs Stable-Baselines3 `predict` (in the export) | 100 % | 100 % | 100 % |

| Check (regime 1) | Result |
|---|---|
| C. Simulink twin `pcm_drl_twin.slx`, 1 week, closed loop | 100 % identical actions, max \|ΔT_top\| 6e-14 °C, E_del50 15.04 = 15.04 kWh, PASS (0.46 s wall per simulated hour) |
| Generated C code of PPO + interlock (`export_r1/codegen_c`, 9 .c files, 1126 lines), 8760 h | 100 % identical to MATLAB (action + interlock state) and 100 % identical to Python's actions |

Reports: `export_r1/validation_report.json`, `export_r1/codegen_verification.json`.

## Edge cases (April 2010 weather, 4 days spin-up, 4 days event, 2 days recovery)

Same six cases as Tamil Nadu (clear, no sunlight, rain/heavy cloud, low temperature, heat wave, noisy
sensors with a 12-hour blackout), each with PPO and with B0, plus one Uttarakhand-only diagnostic,
`low_temp_mains_masked` (cold case, but the policy is fed the training mains temperature).
`run_scenarios` writes `export*/scenarios/scenario_summary.csv` and one PNG per case.

Results (MATLAB, regime 1, event days only, kWh delivered up to 50 °C; full tables for r0 / r1 / r2 in
`export*/scenarios/scenario_summary.csv`):

| Scenario | PPO E_del50 | B0 E_del50 | PPO shield h | B0 shield h | PPO bypass h | Hours over hard limit |
|---|---|---|---|---|---|---|
| Clear | 15.4 | 16.9 | 0.0 | 20.4 | 11 | 0 |
| No sunlight | 0.3 | 0.3 | 0 | 0 | 0 | 0 |
| Rain / cloud | 3.8 | 3.8 | 0 | 0 | 0 | 0 |
| Low temperature (mains −8 °C) | 17.6 | 17.6 | 11.1 | 11.1 | **0** (acts as B0) | 0 |
| Low temp., policy sees training mains | 16.5 | 17.6 | 0.0 | 11.1 | 6 | 0 |
| Heat wave | 17.1 | 18.6 | 0.1 | 25.8 | 15 | 0 |
| Sensor fault (15 h fail-safe) | 15.65 | 16.89 | 5.0 | 20.4 | 9 | 0 |

Findings worth stating in the report:
- PPO repeats its Objective 3 trade-off in every sunny case: about 8–9 % less energy delivered to 50 °C
  than B0, and almost no shield time (0–0.3 h against 17–26 h for B0). Zero hours over a hard limit for
  every controller and case.
- **Mains temperature is a deployment risk.** With mains water 8 °C colder, the frozen policy's
  T_mains input is thousands of standard deviations out of its training range. In regimes 0 and 2 PPO then
  **bypasses for the whole run and delivers almost nothing** (r0: 0.3 vs 16.7 kWh for B0; r2: 0.2 vs
  18.3 kWh). In regime 1 it falls back to always-enable. Feeding the policy the training mains value
  (`low_temp_mains_masked`) restores normal behaviour in all three regimes (94–95 % of B0, about 0 shield
  hours). Recommendation for the hand-off: freeze the mains input at its training value (or retrain with
  varying mains) and range-check every input against the normalisation file (test-plan step 2).
- No sunlight and rain: the PCM is fully solid again by the start of the event, so there is no stored heat to
  carry over; PPO and B0 are identical, as in Tamil Nadu.
- The 12-hour sensor blackout triggers the fail-safe (B0 = always enable, under the shield) for 15 hours
  (16 for B0), including the random 1 % dropouts; no hard-limit time.

## Limits

- The year is an O3 **test** year read after O3's one-shot locked test; every number from it is
  exploratory and does not replace `results/m6_test_results.csv` of Objective 3.
- PCM temperature, melt fraction and stored / recoverable energy are simulator states. On a real tank
  they need an estimator (contract: `measurable = false`); the sensor model adds 0.5 °C error to the PCM
  temperature only.
- `T_mains` was constant during training, so its normalisation std is about 0.001 °C. Any change of the
  mains temperature (the low-temperature case lowers it by 8 °C, a real mains sensor would drift) puts
  that input thousands of standard deviations out of distribution. This is a property of the frozen policy;
  the twin reports what the policy does, it does not fix it.
- Rain has no physics of its own (reduced irradiance and lower ambient only); no frost model.
- The policy decides hourly; the in-plant shield still acts at every solver sub-step (150 s or finer).
