# Objective 4 — Software-in-the-loop validation (no hardware)

A MATLAB/Simulink digital twin of the Tamil Nadu PCM solar water heater, driven by
the trained Objective 3 SAC controller. It stands in for the hardware tests of the
Objective 4 plan (sensor model, interlock, software-in-the-loop replay, edge cases)
until a physical rig exists.

**Status: emulated validation only.** It shows the controller behaves correctly on
the same physics it was trained on. It is not experimental validation; the field
trial in `results/obj4_handoff/obj4_deployment_test_plan_r0.md` (step 6) remains.

## Folder layout

| Path | Purpose |
|---|---|
| `export_from_python.py` | Freezes plant parameters, weather, SAC weights and a Python reference run into `export/`. Reads Objective 3 (policy, contract) and Objective 2 (physics, weather). Run from `objective3/`. |
| `export/` | Generated inputs for MATLAB. Re-generate when the policy or regime changes. |
| `matlab/pcm_plant_hour.m` | One hour of tank + PCM + collector + shield physics. Line-for-line port of the Python environment. |
| `matlab/sac_policy.m` | The trained SAC actor (11-256-256-1) as a plain function. |
| `matlab/build_obs.m`, `sensor_model.m`, `safety_interlock.m` | Observation vector, sensor noise/dropout, stale-sensor and fault-latch fail-safe. |
| `matlab/simulate_hours.m` | Closed loop: sensors, observation, policy, interlock, plant. |
| `matlab/run_scenarios.m` | Validation, six edge cases, plots, summary table, animations. |
| `matlab/animate_system.m` | Animated schematic (sun, collector, pump, water flow, tank, PCM capsules). |
| `matlab/build_pcm_twin_model.m`, `run_twin.m` | Builds and runs the Simulink model `pcm_drl_twin.slx`. |
| `export/scenarios/` | Results: plots, `scenario_summary.csv`, MP4 animations. |

## How to run

```bash
# 1. export from Python (from the objective3 folder)
python objective4_software_in_loop/export_from_python.py --regime 0 --year 2011 --hours 8760
```
```matlab
% 2. in MATLAB (R2023b): Simulink, Stateflow needed only for the .slx twin
cd objective4_software_in_loop/matlab
run_scenarios            % validation + edge cases + plots + animations (~15 min)
```

## What has been verified

| Check | Result |
|---|---|
| Plant physics vs Python, full year 2011 | max temperature difference about 1e-12 °C, shield trips equal (23,117), zero violations |
| SAC policy vs Python on Python's own observations | 100 % identical actions |
| Closed loop (sensors, observation, policy, interlock, plant), 14 days | 100 % identical actions, temperature difference about 1e-13 °C |
| Simulink twin, 1 week | 100 % identical actions, temperature difference about 1e-13 °C |

The Simulink twin is slow (about 11 s per simulated hour, mostly interpreted
MATLAB Function blocks), so long runs use the plain-MATLAB closed loop, which gives
identical numbers.

## Edge cases (April 2011 weather, 4 days spin-up, 4 days event, 2 days recovery)

Clear, no sunlight, rain/heavy cloud, low temperature, heat wave, and noisy
sensors with a 12-hour blackout. Each is run with SAC and with the always-charge
baseline B0. See `export/scenarios/scenario_summary.csv` and the PNG per case.

## Results (April 2011, regime 0; event = 4 days; kWh delivered during the event)

| Scenario | SAC delivered | B0 delivered | SAC shield trips | B0 shield trips | Hard violations |
|---|---|---|---|---|---|
| Clear | 25.3 | 25.8 | 321 | 920 | 0 |
| No sunlight | 1.3 | 1.3 | 0 | 0 | 0 |
| Rain / cloud | 4.6 | 5.2 | 0 | 0 | 0 |
| Low temperature | 26.2 | 27.9 | 142 | 380 | 0 |
| Heat wave | 27.3 | 27.9 | 340 | 1193 | 0 |
| Sensor fault | 19.6 | 19.8 | 280 | 664 | 0 |

Full table: `export/scenarios/scenario_summary.csv`. Per-scenario plots: `export/scenarios/*.png`.
Animations: `export/scenarios/{no_sunlight,rain_cloud,low_temperature,clear}_animation.mp4`
(with a `_frame.png` still of each).

Findings worth stating in the report:
- In this design the PCM is fully solid again by about midnight every day, so on the no-sunlight and
  rain days there is no stored heat to carry over; the tank sits at mains temperature and delivery
  is about 1 kWh.
- SAC keeps zero hard-limit violations in every case. The sensor blackout triggered the fail-safe
  for 14 hours (17 for B0), which confirms the interlock works.
- The two-week closed-loop run agreed with Python on every action, so these edge-case numbers use
  the same physics and policy as Objective 3.

## Known cosmetic limits of the animation

- The pump is drawn as running whenever the controller commands CHARGE, even in very low sun
  when the collector gain is zero and the plant itself does not circulate.
- Text labels for the tank and collector are partly covered by pipes, and the sun rays are
  decorative, not aimed at the collector.

## Limits

- Regime 0 (Tamil Nadu coastal/interior lowland) only. Regimes 1 and 2 follow once
  Objective 3 finishes; re-run the export and `run_scenarios`.
- The plant is the same single-node-water model the policy was trained on. Water
  flow in the animation is schematic, not a resolved flow field.
- Rain has no physics of its own. It enters only as reduced irradiance and lower
  ambient temperature. There is no frost or freezing model.
- The policy decides hourly while the hardware spec says a 10 s cycle. The shield
  inside the plant still acts at 150 s sub-steps.
