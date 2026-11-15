# Showcase videos: one-day charge / discharge / idle (Rajasthan, regime 1, 50 L)

Script: `matlab/run_o4_showcase.m` (`run_o4_showcase` renders everything, about 11 min; `run_o4_showcase('plots')` plots and tables only, about 3 min; `run_o4_showcase('all', 20, 'SAC')` renders the SAC variant into separate folders). It is the Tamil Nadu generator adapted for the Rajasthan twin; nothing in the physics, controller or safety layer was changed. Weather: day 165 of 2023 (a validation year), 00:00 to 24:00 local, the same day as `video/o4_3d_day165_2023.mp4`. The normal-day re-run is asserted to equal the full-year run exactly.

Region and design: regime 1, Nagaur medoid (RJP_0192), PureTemp 60 (melts 60-62 C, 220 kJ/kg), 52 capsules, 13.4 kg PCM, 1.5 m^2 collector, 0.049 kg/s, 50 L tank. Controller: the released DQN (Objective 3).

## Videos (`video/showcase/`, 24 s each, 1 s per simulated hour, plus a 4 s result card)

| Video | Scenario |
|---|---|
| `o4_schematic_day_day165_2023.mp4` | Normal sunny day |
| `o4_schematic_heat_wave_day165_2023.mp4` | Edge case 1: ambient +9 C, sun +15 % |
| `o4_schematic_rain_cloud_day165_2023.mp4` | Edge case 2: sun x0.12, ambient -5 C |
| `o4_schematic_sensor_fault_day165_2023.mp4` | Bonus: noisy sensors + 12 h blackout (05:00 to 16:59) |

Each video draws the system (collector with cells, pyranometer, ambient sensor, data logger, flow meter, pump, tank with copper coil and 52 PCM capsules) for the AI + PCM system, with live plots of all three systems (plain tank, PCM only, AI + PCM) and a strip for the four objectives: O1 PureTemp 60, O2 design (52 capsules, 13.4 kg, 1.5 m^2, 0.049 kg/s), O3 DQN action, O4 sensor model, safety shield and fail-safe. Stills are saved beside each video (`_06h`, `_10h`, `_14h`, `_19h`, `_result`). The result card lists hot water delivered, heat collected, charge / discharge / idle hours, shield guard-band hours and peak temperature for the three systems.

**Phase definition (per hour):** CHARGE = collector gain > 0; DISCHARGE = not charging and hot water drawn (>= 1 kg); IDLE = otherwise. BYPASS hours are counted separately.

## What differs from the Tamil Nadu showcase, and why

| Item | Tamil Nadu | Rajasthan | Why |
|---|---|---|---|
| Day | 71 of 2021 | 165 of 2023 | validation year; same day as the Rajasthan 3-D day video |
| Tank model | one water node | 10 stacked water nodes | Rajasthan twin; curves show the top (delivery) layer, the schematic shows the 10 layers and per-node capsules |
| AI arm | SAC | DQN (SAC variant also run) | DQN is the released Rajasthan controller |
| Shield load | trip counts | guard-band hours | the Rajasthan kernel counts activations per node and sub-step, so hours are the comparable number |
| Plain tank | PCM volume refilled by scaling water mass | `make_plain_tank.m` (capsule volume refilled with water, PCM limits off) | existing Rajasthan rule |
| Day start | next local midnight in the nominal 24 h block | start of the 165th local day (`rows17(day) - 17`) | matches `one_day_cycle.m` |
| Plot theme | default | forced light theme | R2026b follows the OS dark theme |

Code changes outside the new file: `simulate_hours.m` got an optional start-state argument and logs hours-since-draw (existing calls behave the same). No Tamil Nadu file was touched.

## One-day results (`export_r1/showcase/o4_showcase_day_table.csv`)

| Scenario | System | Charge h | Discharge h | Idle h | Delivered kWh | Heat collected kWh | Guard-band h |
|---|---|---|---|---|---|---|---|
| Normal | Plain tank | 14 | 6 | 4 | 2.66 | 4.19 | 4.1 |
| Normal | PCM only | 14 | 6 | 4 | 3.18 | 4.65 | 5.2 |
| Normal | AI + PCM | 12 | 6 | 6 | 3.15 | 4.47 | 2.4 |
| Heat wave | Plain / PCM only / AI + PCM | 12 / 14 / 11 | 7 / 6 / 6 | 5 / 4 / 7 | 3.08 / 3.58 / 3.50 | 4.64 / 5.11 / 4.83 | 4.5 / 6.3 / 1.7 |
| Rain / cloud | Plain / PCM only / AI + PCM | 11 / 11 / 11 | 9 / 9 / 9 | 4 / 4 / 4 | 0.89 / 0.84 / 0.84 | 0.89 / 0.85 / 0.85 | 0 / 0 / 0 |
| Sensor fault | Plain / PCM only / AI + PCM | 2 / 2 / 2 | 14 / 14 / 14 | 8 / 8 / 8 | 0.45 / 0.45 / 0.44 | 0.34 / 0.34 / 0.34 | 0 / 0 / 0 |

Hard-limit violations: 0 in every row. In the sensor-fault day the stale-sensor fail-safe forces BYPASS for 13 h in every system, so almost no heat is collected. The small negative tank-loss values on that day are real: ambient air was warmer than the cold tank.

## Full year 2023 (`export_r1/showcase/o4_annual_comparison.png`, `o4_annual_energy.png`, `o4_showcase_annual_table.csv`)

| | Plain tank | PCM only | AI + PCM (DQN) |
|---|---|---|---|
| Delivered kWh | 770.4 | 912.4 | 897.3 |
| Heat collected kWh | 1270.3 | 1340.2 | 1298.3 |
| Tank heat loss kWh | 70.7 | 72.3 | 70.3 |
| Delivered per kWh collected | 60.6 % | 68.1 % | 69.1 % |
| Hold above 45 C after sunset (mean of 12 starts) | 51.9 h | 61.2 h | 61.0 h |
| Shield guard-band hours | 755 | 994 | 430 |
| Hours with water >= 70 C | 1,422 | 1,368 | 1,053 |
| Pump run-hours | 4,099 | 4,166 | 3,810 |

The hold row is read from `hold_test.csv`, which is the DQN run.

## SAC variant (`video/showcase_sac/`, `export_r1/showcase_sac/`)

| | PCM only | AI + PCM (DQN) | AI + PCM (SAC) |
|---|---|---|---|
| Delivered kWh | 912.4 | 897.3 | 873.6 |
| Shield guard-band hours | 994 | 430 | 144 |
| Hours with water >= 70 C | 1,368 | 1,053 | 990 |
| Pump run-hours | 4,166 | 3,810 | 3,619 |
| Delivered per kWh collected | 68.1 % | 69.1 % | 69.4 % |

One-day delivered kWh with SAC: normal 3.02, heat wave 3.34, rain / cloud 0.84, sensor fault 0.36 (PCM only: 3.18, 3.58, 0.84, 0.45). The DQN was kept as the main arm; SAC is shown as a safer alternative that gives up more hot water. Both were looked at.

## What it shows, honestly

- PCM gives the energy and heat-retention gain over the plain tank (+142 kWh a year, hold +9 h). AI + PCM keeps most of it (+127 kWh with the DQN).
- AI + PCM keeps about 98 % of PCM-only hot water, with 57 % less time in the shield guard band, 23 % fewer hours at 70 C or more, 9 % fewer pump hours, and slightly more delivered heat per kWh collected (69.1 % vs 68.1 %). That is the benefit of the controller: it controls the PCM safely and saves pump wear.
- AI + PCM does **not** deliver more hot water or hold heat longer than PCM only (-15 kWh, -0.2 h with the DQN). On the rain and sensor-fault days no system collects much, so all three are close.
- No pump power is defined anywhere in the project, so pump effort is shown as run-hours, not kWh.
- Limits: software emulation only, single seed, validation year only, one-day results are for one day of the year.
