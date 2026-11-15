# Showcase videos: one-day charge / discharge / idle (Tamil Nadu, 100 L)

Script: `matlab/run_o4_showcase.m` (`run_o4_showcase` renders everything, about 25 min; `run_o4_showcase('plots')` plots and tables only). Nothing in the physics, controller or safety layer was changed. Weather: day 71 of 2021 (a validation year), 00:00 to 24:00 local. The normal-day re-run is asserted to equal the full-year run exactly.

## Videos (`video/showcase/`, 24 s each, 1 s per simulated hour)

| Video | Scenario |
|---|---|
| `o4_schematic_day_day071_2021.mp4` | Normal sunny day |
| `o4_schematic_heat_wave_day071_2021.mp4` | Edge case 1: ambient +9 C, sun +15 % |
| `o4_schematic_rain_cloud_day071_2021.mp4` | Edge case 2: sun x0.12, ambient -5 C |
| `o4_schematic_sensor_fault_day071_2021.mp4` | Bonus: noisy sensors + 12 h blackout (05:00 to 16:59) |

Each video draws the system of the reference figure (collector with cells, pyranometer, ambient sensor, data logger, flow meter, pump, tank with copper coil and 104 PCM capsules) for the AI + PCM system, with live plots of all three systems (plain tank, PCM only, AI + PCM) and a strip for the four objectives: O1 PureTemp 58, O2 design (104 capsules, 24.8 kg, 2.5 m2, 0.039 kg/s), O3 SAC action, O4 sensor model, safety shield and fail-safe. The last 4 s is a result card. Stills are saved beside each video (`_06h`, `_10h`, ... `_result`).

**Phase definition (per hour):** CHARGE = collector gain > 0; DISCHARGE = not charging and hot water drawn (>= 1 kg); IDLE = otherwise. BYPASS hours are counted separately.

## One-day results (`export/showcase/o4_showcase_day_table.csv`)

| Scenario | System | Charge h | Discharge h | Idle h | Delivered kWh | Shield trips |
|---|---|---|---|---|---|---|
| Normal | Plain tank | 11 | 9 | 4 | 5.48 | 82 |
| Normal | PCM only | 10 | 10 | 4 | 6.11 | 210 |
| Normal | AI + PCM | 7 | 12 | 5 | 6.05 | 64 |
| Heat wave | Plain / PCM only / AI + PCM | 10 / 10 / 8 | 9 / 9 / 11 | 5 / 5 / 5 | 5.96 / 6.59 / 6.42 | 103 / 284 / 141 |
| Rain / cloud | Plain / PCM only / AI + PCM | 8 / 8 / 8 | 12 / 12 / 12 | 4 / 4 / 4 | 1.13 / 1.37 / 1.35 | 0 / 0 / 0 |
| Sensor fault | Plain / PCM only / AI + PCM | 1 / 1 / 0 | 16 / 16 / 17 | 7 / 7 / 7 | 0.61 / 0.90 / 0.83 | 0 / 0 / 0 |

Hard-limit violations: 0 in every row.

## Full year 2021 (`export/showcase/o4_annual_comparison.png`, `o4_showcase_annual_table.csv`)

| | Plain tank | PCM only | AI + PCM |
|---|---|---|---|
| Delivered kWh | 1853.5 | 2002.6 | 1971.4 |
| Hold above 45 C after sunset (mean of 12 starts) | 21.6 h | 51.6 h | 49.9 h |
| Shield trips | 17,020 | 39,705 | 18,604 |
| Pump run-hours | 3,514 | 3,570 | 3,145 |
| Hours with water >= 70 C | 1,116 | 1,029 | 456 |

## What it shows, honestly

- PCM gives the energy and heat-retention gain over the plain tank (+149 kWh with B0, +118 kWh with AI).
- AI + PCM keeps about 98 % of PCM-only hot water, with 53 % fewer shield interventions, 12 % fewer pump hours and less than half the time near the 72 C limit. That is the benefit of the controller: it controls the PCM safely and saves pump energy.
- AI + PCM does **not** deliver more hot water or hold heat longer than PCM only (-31 kWh, -1.7 h). In the rain and sensor-fault days no system collects much.
- Limits: software emulation only, single seed, one-node water and PCM model, benchmark error vs the published cool-down is 38 % (see `G_H_benchmark_and_sensor_faults.md`).
