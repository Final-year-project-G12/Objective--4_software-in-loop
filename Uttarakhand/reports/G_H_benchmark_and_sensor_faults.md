# G. Benchmark (Amanowicz & Turski 2025) and H. sensor faults

## G. Tank-level benchmark (`benchmark_amanowicz.m`, `amanowicz_case.m` -> `results_campaign/benchmark_amanowicz_*`, `export_r1/amanowicz_benchmark.json`)

Reference: Amanowicz & Turski, Energies 18(2) 345 (2025): a 9.6 dm3 insulated tank cooling in 27 C air, case 1 water
only (6750 mL), case 2 water + 9 RT44HC capsules (4050 mL water, 200 g PCM each). Compared with the paper's printed linear
fits of the measured curves (eqs. 2-5), every 300 s over 7200 s; printed drops 14 K and 26 K. The Uttarakhand kernel is run
with no collector and no draw, ten identical nodes; the plant "hour" is set to 300 s. Assumptions identical to the Rajasthan
benchmark (plastic wall 1 mm, k 0.4, latent heat 250 kJ/kg from the O1 database, capsules start at 27 C, tank body heat
capacity ignored). Only the tank loss coefficient is fitted (to the water-only case: 1.552 W/K; a-priori from the
insulation 0.821 W/K). **No capsule constant is changed** (plan: diagnose, do not recalibrate).

| Capsule mapping | Loss coefficient | Case 1 RMSE | Case 2 RMSE | Case 2 bias | Case 2 drop over 7200 s (paper 26 K) |
|---|---|---|---|---|---|
| one sphere, same volume | a priori / fitted | 3.09 / 0.46 K | 8.42 / 5.72 K | +7.9 / +4.9 K | 20.3 / 24.6 K |
| one sphere, same surface | a priori / fitted | 3.09 / 0.46 K | 7.94 / 5.39 K | +7.4 / +4.5 K | 20.9 / 25.0 K |
| **many spheres, same PCM mass and surface/volume** | a priori / fitted | 3.09 / 0.46 K | **1.06 / 1.41 K** | +0.24 / -0.89 K | 25.2 / 26.6 K |

Diagnosis: the one-sphere mappings make the PCM conduction path much longer than the 22 mm slab's (Rajasthan's
`diagnose_capsule.m` measured 3.6 times; not re-run here), so the capsules
release their heat too slowly and the water stays 4.5-7.9 K too warm. Mapped with the slab's surface/volume ratio, the frozen
Objective 2 constants reproduce the measured cool-down within 1.1-1.4 K RMSE and the printed 26 K drop within 0.6-0.8 K.
Same result as Rajasthan's benchmark (1.1-1.4 K). Limits: a printed fit, not the raw curve; a different PCM (RT44HC) and
capsule shape; one test.

## H. Sensor faults (`run_sensor_faults.m` -> `results_campaign/sensor_fault_seeds.csv`, `pyranometer_year.csv`, `pyranometer_seeds.csv`, `sensor_faults_summary.json`)

**Sensor-fault case, 20 seeds** (April window, noise + 1 % dropout + 12 h blackout; mean +- 95 % CI, t with 19 dof),
event days, delivered to 50 C:

| Controller | Delivered [kWh] | Shield hours | Fail-safe hours (min-max) |
|---|---|---|---|
| PPO | 15.61 +- 0.07 | 5.24 +- 0.03 | 14.2 (12-19) |
| B0 | 16.72 +- 0.00 | 20.09 +- 0.00 | 14.2 (12-19) |

B0 does not read the sensors, so its delivery does not change with the seed. The single-seed value in C (15.79 kWh,
5.33 h) lies just outside the PPO interval's upper end, which is what the 20 seeds are for.

**Pyranometer faults, full year 2023** (other sensors ideal):

| Controller | Pyranometer | Delivered 50 C [kWh] | Window [kWh] | Shield h | Bypass h | Fail-safe h | Hours over limit |
|---|---|---|---|---|---|---|---|
| B0 | any | 1184.4 | 607.3 | 571.1 | 0 | 0 | 0 |
| PPO | healthy | 1142.4 | 565.3 | 1.1 | 918 | 0 | 0 |
| PPO | dead (0) | 1179.0 | 602.0 | 535.7 | 737 | 0 | 0 |
| PPO | stuck 500 | 1142.8 | 565.7 | 29.0 | 2793 | 0 | 0 |
| PPO | stuck 1000 | 1078.9 | 501.8 | 0 | 3391 | 0 | 0 |

The PPO's command changes in 397 (dead), 2203 (stuck 500) and 2645 (stuck 1000) of 8760 hours. **The interlock never
reacts** (0 fail-safe hours): it has no irradiance plausibility rule. A dead pyranometer makes the PPO behave much like
B0 (and gives it more energy, with the shield doing the work); a pyranometer stuck high makes it bypass in daylight and
loses 63.5 kWh a year (-5.6 %). On a device, add a plausibility rule (e.g. compare with clear-sky GHI, or check that the
collector heats the water when the reading says sun).

Pyranometer faults on the April window with noisy other sensors, 20 seeds, PPO (event delivered, shield hours):
healthy 15.21 +- 0.07 kWh / 0.06 h; dead 16.46 +- 0.00 / 17.95 h; stuck 500 15.86 +- 0.01 / 1.74 h; stuck 1000
14.83 +- 0.02 / 0.00 h. Fail-safe hours 2.2 in every case (random dropouts only).
