# Prompts G and H: benchmark and sensor-fault confidence intervals

## G. Amanowicz & Turski 2025 benchmark (RT44HC cool-down)

Source: `export/amanowicz_benchmark.json`, `matlab/amanowicz_case.m`. The primary paper could not be fetched (HTTP 403), so the script uses only the two headline drops (14 K and 26 K) and the geometry from the project's own plan. Assumed and flagged: 2 h duration, plastic shell properties, RT44HC melting data from the datasheet. No physics constant was recalibrated.

| Quantity | Measured | Simulated | Error |
|---|---|---|---|
| Case 1, water only, drop over 2 h | 14.0 K | 14.0 K | by construction (heat loss UA = 1.354 W/K was fitted to this case) |
| Case 2, water + capsules, drop over 2 h | 26.0 K | **16.0 K** | **38.5 %, outside the 15 % target** |
| 2-point RMSE / MAE | | 7.08 K / 5.01 K | two end points only, not a full-curve RMSE |

Equivalent sphere used: 47.9 mm diameter, 39 spheres, 1.07 mm wall.

**What it means:** the capsule model cools more slowly than the real experiment. The simulated tank loses 16 K where the measured one lost 26 K, so the model stores or retains heat more optimistically than reality. Every hold-time figure in report D should be read as an **upper bound**. This agrees with Objective 2's earlier finding that the capsule model runs on the slow side.

**Limits:** no digitised curve, so no true curve RMSE. The result is a two-endpoint check, not a validation. If you obtain the paper's Figure 7 data, a full-curve RMSE can be computed.

## H. 20-seed sensor-fault confidence intervals

Source: `export/scenarios_3arm/sensor_fault_20seed_ci.csv`. Arm 3 (SAC), 10-day window, 20 seeds.

| Sensor case | Delivered kWh (mean, SE) | Shield hours (mean, SE) | Hard violations |
|---|---|---|---|
| healthy | 62.78 (0.05) | 905 (4.2) | 0 |
| dead (reads 0) | 49.10 (0.11) | 129 (5.1) | 0 |
| stuck | 49.67 (0.25) | 183 (22.4) | 0 |

- A dead or stuck pyranometer cuts delivery by about 21 to 22 % in this window (the O3 summary quotes about 14 % over a year, so the 10-day window is harsher).
- Shield hours fall to about 130 to 180 because the controller charges less, and the safety shield still keeps hard violations at **0**. The controller degrades but stays safe.
- The SEs are small, so the difference between healthy and faulty is larger than the seed-to-seed spread. What the 20 seeds vary was not checked by me (see `matlab/run_h.m`); the SAC controller is the single seed-42 model.
