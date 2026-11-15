# Objective 4 — Software-in-the-loop validation, Uttarakhand (no hardware)

A MATLAB/Simulink digital twin of the Uttarakhand PCM solar water heater, driven by the Objective 3
**PPO** controller. It is the Uttarakhand counterpart of `../Tamilnadu/` and `../Rajasthan/` and follows the
joint O4 plan (`docs/plan_O4.md`): validation, three arms (plain tank / PCM + always-on / PCM + AI),
one-day cycle, edge cases, hold test, checks, PCM swap, benchmark, sensor-fault intervals, video, cross-state table.

**Status: emulated validation only, all run in MATLAB R2026b.** It shows the controller behaves as in
Objective 3 on the same physics it was trained on. It is not experimental validation; the hardware steps in
`<O3 uttarakhand>/results/o4_handoff/r<k>/deployment_test_plan.md` (bench interlock, shadow mode,
hardware-in-the-loop) remain.

**Start here:** `reports/00_AUDIT_SUMMARY.md` (requirements, headline numbers, problems found), then
reports A to I.

## Headline (joint plan, 2023, regime 1, 50 L / 1.5 m², PureTemp 58, 12.45 kg PCM)

| Arm | Delivered to 50 °C [kWh] | Window 18–09 h [kWh] | Shield hours | Hold at 45 °C (mean of 12) | Hours over a hard limit |
|---|---|---|---|---|---|
| 1 plain tank + B0 | 1102.3 | 538.4 | 286.6 | 23.3 h | 0 |
| 2 PCM + B0 (no AI) | 1184.4 | 607.3 | 571.1 | 32.6 h | 0 |
| 3 PCM + PPO | 1142.4 | 565.3 | 1.1 | 26.0 h | 0 |

The PCM gives the energy and retention gain (+82 kWh, +9.3 h at 45 °C over the plain tank). The PPO keeps about half of
the delivery gain (−42 kWh, −3.5 % against B0) and almost never runs into the shield (1.1 h against 571 h); it does not
improve retention. 2023 is an Objective 3 validation year on which the PPO seed was chosen: a fidelity check, not an
unbiased performance figure.

## Controller

Default (`export_from_python.py --agent smart`): the agent Objective 3 now recommends (FINDINGS 9.6) — PPO with the
**smart-persistence forecast**, 19 inputs (15 contract fields + GHI 1/2/3 h ahead + next-hour draw), trained with domain
randomisation; primary seed by O3's own M4 rule (r0 seed 2, r1 seed 0, r2 seed 2). The forecast is computed in the twin
from the measured GHI and the clear-sky GHI (`smart_forecast.m`), exactly as `o3/env_ext.py` does.
`--agent frozen` exports the original hand-off policy (frozen M4 PPO, 15 inputs, no forecast).

## What is different from Tamil Nadu

| | Tamil Nadu (`../Tamilnadu`) | Uttarakhand (this folder) |
|---|---|---|
| Plant | single water node + PCM node | O2's **10-node stratified** tank with PCM per node (`tank_model_multinode._kernel`), stepped hourly as `o3/stepper.py` |
| Controller | SAC | **PPO** (+ smart forecast), 19 → 64 → 64 → 2, tanh, argmax |
| Actions | CHARGE / IDLE / BYPASS | **ENABLE / BYPASS** (collector-loop pump); IDLE = BYPASS in O2's kernel |
| Delivery target | 45 °C | **50 °C** (O2's primary metric); 45 °C also reported for the joint table |
| Measurement point | the one water node | the **top** node |
| Shield metric | shield events | shield **hours** (O2's definition), plus sub-step counts |
| Sensor-fault fail-safe | BYPASS | **B0 = always enable** under the in-plant shield (Uttarakhand hand-off spec) |
| Regimes | 0, 1, 2 | 0, 1 (primary), 2; regime 3 has no PCM controller (O2: PCM gives no gain) |

## Folder layout

| Path | Purpose |
|---|---|
| `export_from_python.py` | Freezes kernel arguments, weather (with clear-sky GHI), PPO weights + normalisation and a Python reference run into `export*/`. Reads the Uttarakhand Objective 3 (`solar-pcm-control--Objective3/uttarakhand`) and the frozen O2 snapshot inside it; modifies neither. |
| `export_campaign.py` | Builds every tank of the joint plan through **Objective 2's own setup**: the water-only twin and O1's top-3 PCMs × flow 0.7 / 1.0 / 1.3 → `export_r1/campaign_cases.json`. |
| `cross_state_table.py` | Cross-state table from the three states' files → `results_campaign/cross_state_table.csv/.png`. |
| `export/`, `export_r1/`, `export_r2/` | Regimes 0 / 1 / 2: inputs (2023; plus 2010 inputs re-exported for the smart-forecast agent), validation reports, joint-plan tables (r1). |
| `export_r1/scenarios_3arm/` | Nine edge cases × three arms (2023). `export*/scenarios/` = PPO vs B0 per regime, seven cases incl. `low_temp_mains_masked`, plus the `my_*.mp4` videos (2023). |
| `results_campaign/` | Checks, sensor-fault seeds, pyranometer faults, PCM-swap figure, ranking check, benchmark, cross-state table. |
| `video/` | One-day three-arm video with the pump fix. |
| `reports/` | 00 audit summary, A validation + three arms, B one-day, C edge cases, D checks + hold test, E PCM swap, F pump fix + video, G_H benchmark + sensor faults, I checklist + cross-state + limitations. |
| `docs/plan_O4.md` | The joint plan and where each item lives for Uttarakhand. |
| `matlab/pcm_plant_hour.m` | One hour of the O2 multinode kernel, line-for-line port (optional 45 °C delivery output and "hour length" for the benchmark; physics unchanged). |
| `matlab/ppo_policy.m`, `build_obs.m`, `smart_forecast.m`, `initial_record.m`, `sensor_model.m`, `safety_interlock.m` | Policy, observation, forecast, reset record, sensors, fail-safe. |
| `matlab/simulate_hours.m` | Closed loop; options for pyranometer faults and campaign start states. |
| `matlab/load_campaign.m`, `swap_pcm.m`, `twin_metrics.m`, `run_hold_test.m` | Campaign tanks, swap rule (check only), metric definitions, retention test. |
| `matlab/shared_format_table.m`, `three_arm_2023.m`, `one_day_cycle.m`, `hold_test.m`, `edge_scenarios.m`, `run_c_scenarios.m`, `run_sensor_faults.m`, `check_energy_balance.m`, `pcm_swap_study.m`, `benchmark_amanowicz.m`, `amanowicz_case.m`, `check_pump_drawing.m`, `animate_three_arm.m` | The joint-plan studies (one script per deliverable). |
| `matlab/validate_against_python.m`, `run_scenarios.m`, `animate_system.m`, `make_my_video.m`, `build_pcm_twin_model.m`, `run_twin.m`, `controller_step.m`, `verify_codegen.m` | Validation, earlier scenario study, animations, Simulink, C code. |

## How to run

```powershell
$py = "D:\solar-pcm-control--Objective3\uttarakhand\.venv\Scripts\python.exe"
& $py Uttarakhand\export_from_python.py --regime 1 --year 2023     # also --regime 0 / 2
& $py Uttarakhand\export_campaign.py --regime 1                    # tanks of the joint plan
```
```matlab
cd Uttarakhand/matlab
validate_against_python(1, 8760, 0)   % full year 2023, PASS/FAIL -> export_r1/validation_report.json
three_arm_2023; one_day_cycle; hold_test          % deliverables 2, 3, 5        (about 1 min)
run_c_scenarios; run_sensor_faults                % deliverable 4 + 20-seed CIs (about 3 min)
check_energy_balance(1)                           % restart, closure, swap, exponential, zero input, sub-step (about 2 min)
pcm_swap_study(1)                                 % deliverable 6 (about 3 min)
benchmark_amanowicz(1)                            % deliverable 7 (seconds)
check_pump_drawing(1)                             % deliverable 9: pump check + one-day video
```
```powershell
python Uttarakhand\cross_state_table.py          # deliverable 8
```

## What has been verified (MATLAB R2026b, 2023, 8760 h, smart-forecast PPO)

| Check | r0 | r1 | r2 |
|---|---|---|---|
| Open-loop plant replay: max \|ΔT_top\| | 2.3e-13 °C | 1.6e-13 °C | 2.3e-13 °C |
| Delivered to 50 °C, MATLAB = Python | 1077.70 kWh | 1142.39 kWh | 1171.13 kWh |
| PPO on Python's observations / closed loop: identical actions | 100 % / 100 % | 100 % / 100 % | 100 % / 100 % |
| Forecast inputs, max difference | 0 | 0 | 0 |
| Overall | PASS | PASS | PASS |

Checks (regime 1): restart differences exactly 0; energy closure 1.3e-12 % (B0) / 1.6e-12 % (PPO); `swap_pcm.m`
reproduces O2's vectors for all three PCMs (3e-17); plain-tank cool-down = implicit-Euler exponential (1.4e-11 K); zero
input drift 1.9e-12 °C — all PASS. **Sub-step gate not met**: −0.059 % against 0.05 % (from the sensible-heat hours;
reported, not relaxed). Details: `reports/D_checks_and_hold_test.md`.

## Findings worth stating (details in `reports/`)

- PCM + PPO vs PCM + B0: −3.5 % delivery, −99.8 % shield hours, −6.6 h hold at 45 °C; PCM vs plain tank: +82 kWh, +9.3 h.
- **Mains temperature is a deployment risk.** The policy's T_mains input has a training std of about 0.001 °C. With
  mains 8 °C colder the regime 1 PPO acts as always-on, and the regime 0 and 2 PPOs bypass for the whole run and
  deliver almost nothing (r0: 0.07 vs 16.45 kWh for B0; r2: 0.02 vs 16.94 kWh; 2023, `export*/scenarios/`). Feeding the
  training mains value (`low_temp_mains_masked`) restores normal behaviour in all three regimes (90-96 % of B0, 0 shield
  hours). Freeze that input or retrain.
- **Pyranometer faults are not detected** (no irradiance plausibility rule) and also corrupt the smart forecast: dead →
  the PPO behaves like B0; stuck at 1000 W/m² → 3391 bypass hours, −5.6 % delivery. No hard-limit hour in any case.
- Sensor fault, 20 seeds: PPO 15.61 ± 0.07 kWh, 5.24 ± 0.03 shield hours; B0 16.72 kWh, 20.09 h.
- PCM swap: PureTemp 58 (O2's choice) first with B0; n-Octacosane (C28) last (−54 kWh window, −4.7 h hold). Three PCMs
  cannot support a ranking claim. Flow ×0.7–1.3 changes delivery by 1–2 %.
- Benchmark (Amanowicz & Turski 2025): 1.1–1.4 K RMSE with the surface/volume-matched capsule mapping and the frozen
  constants (one-sphere mappings 4.5–7.9 K too warm).
- In this 50 L tank with a 300 L/day draw the PCM is solid again by late evening; retention is 23–33 h at 45 °C, much
  shorter than Rajasthan's (61 h) because of the colder climate.

## Single-arm scenario study and videos (2023, PPO vs B0, every regime)

`run_scenarios` (regimes 0, 1, 2) -> `export*/scenarios/`: the six edge cases plus `low_temp_mains_masked`, PPO vs B0, with
a 14-day closed-loop check against Python (PASS, 100 % identical actions, every regime). `make_my_video` -> `my_*.mp4`
(regime 1: clear, no sunlight, rain/cloud, heat wave, sensor fault; regime 0: low temperature, PPO and B0). Regenerated
15 Nov 2026 with the current controller and year. Event delivery to 50 C, PPO / B0 [kWh]:

| Scenario | r0 | r1 | r2 |
|---|---|---|---|
| Clear | 14.35 / 15.70 | 15.09 / 16.72 | 15.33 / 16.80 |
| Low temperature (mains -8 C) | **0.07** / 16.45 | 17.34 / 17.34 | **0.02** / 16.94 |
| Low temperature, policy sees training mains | 14.88 / 16.45 | 16.34 / 17.34 | 16.27 / 16.94 |
| Heat wave | 15.93 / 17.42 | 17.60 / 18.51 | 17.72 / 18.74 |
| Sensor fault | 14.70 / 15.70 | 15.79 / 16.72 | 15.73 / 16.80 |

The first study (13 Nov, year 2010 read post-lock from O3's test years, frozen V1 PPO) is in git history (commit
`2d9b48f`; the `*_2010.csv` files now in `export*/` were re-exported for the smart-forecast agent).

## Simulink twin and generated C (current controller, 2023)

| Check (regime 1) | Result |
|---|---|
| Simulink twin `pcm_drl_twin.slx` (19-input smart PPO), one week, closed loop | 100 % identical actions, max \|dT_top\| 9e-14 C, delivered 16.48 = 16.48 kWh, PASS, 0.31 s per simulated hour (`export_r1/validation_simulink_168h.json`) |
| Generated C of PPO + interlock (`export_r1/codegen_c`, 9 files, 1127 lines), 8760 h | 100 % identical to MATLAB (action + interlock state) and to Python's actions (`export_r1/codegen_verification.json`) |

## Shared cross-state format (all three regimes)

`shared_format_table.m` -> `results_campaign/shared_format_table_uttarakhand_2023.csv` (same columns as Rajasthan's
`shared_format_table_rajasthan_2023.csv`): water-only B0, PCM + B0, PCM + PPO for regimes 0, 1, 2, year metrics and the
12-start hold test.

| Regime (PCM) | Arm | Delivered 45 C | Window 45 C | Shield h | Hold 45 C |
|---|---|---|---|---|---|
| r0 (PureTemp 58) | PCM-free / PCM + B0 / PCM + PPO | 955.5 / 1049.4 / 990.5 | 496.7 / 582.8 / 523.9 | 435.3 / 645.2 / 0.5 | 32.1 / 39.8 / 27.2 h |
| r1 (PureTemp 58) | PCM-free / PCM + B0 / PCM + PPO | 1012.5 / 1101.9 / 1063.2 | 511.0 / 589.0 / 550.3 | 286.6 / 571.1 / 1.1 | 23.3 / 32.6 / 26.0 h |
| r2 (savE OM55) | PCM-free / PCM + B0 / PCM + PPO | 1059.6 / 1141.4 / 1103.7 | 534.2 / 605.1 / 567.4 | 218.0 / 411.2 / 0.6 | 21.3 / 26.9 / 19.8 h |

Same pattern in every regime: the PCM tank beats the plain tank on delivery and hold; the PPO almost removes shield
operation but delivers 3.3-5.6 % less than B0 and holds less. In regimes 0 and 2 the PPO's hold at 45 C is below the
plain tank's (27.2 vs 32.1 h, 19.8 vs 21.3 h).

## Limits

- Software only; 2023 is a selection year; one PPO seed; the PCM swap, edge cases, checks and benchmark are for
  regime 1 (the three-arm table and hold test cover regimes 0, 1, 2).
- PCM temperature, melt fraction and stored / recoverable energy are simulator states (estimator needed on a device).
- The forecast comes from the pyranometer; next-hour demand is O2's fixed profile (perfect).
- `T_mains` is out of distribution for any real mains change; no irradiance plausibility rule in the interlock.
- Rain is reduced irradiance and lower ambient only; no frost model. Hold times are model values.
- Pump energy: only the Ergun capsule bed is in O2's model (0.008 Pa, negligible).
- Full list: `reports/I_requirements_checklist_and_videos.md`.
