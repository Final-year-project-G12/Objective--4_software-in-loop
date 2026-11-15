# A. Controller check, export, validation, three-arm comparison (Uttarakhand, 2023)

## Controller

Objective 3 (Uttarakhand) now recommends PPO with the smart-persistence forecast (O3 FINDINGS 9.6): 19 inputs
(15 contract fields + GHI 1/2/3 h ahead + next-hour draw), forecast = clear-sky index of the current hour times the
clear-sky GHI of the next hours, trained with domain randomisation. O3 trained three seeds and named none; the twin takes
the primary seed by O3's own M4 rule (`o3/evaluate.py::lexicographic_best` on the validation rows of
`results/m13_forecast_algo_r<k>.csv`). Selected: r0 seed 2, **r1 seed 0**, r2 seed 2. The policy file, its SHA-256,
the selection rows and the checkpoint are in `export*/plant_params.json` (`agent`) and `export*/ppo_actor.json`.
The forecast is **computed from the pyranometer reading**, not supplied perfect (Rajasthan: perfect 3 h forecast;
Tamil Nadu: smart forecast).

## Export and validation (`export_from_python.py --year 2023`, `validate_against_python(k, 8760, 0)`)

| Check, 8760 h of 2023 | r0 | r1 | r2 |
|---|---|---|---|
| Numpy actor vs Stable-Baselines3 `predict` | 100 % | 100 % | 100 % |
| A open-loop plant replay: max \|dT_top\| | 2.3e-13 C | 1.6e-13 C | 2.3e-13 C |
| A delivered to 50 C, MATLAB = Python | 1077.70 kWh | 1142.39 kWh | 1171.13 kWh |
| A shield hours, MATLAB = Python | 0.472 h | 1.090 h | 0.590 h |
| A' PPO on Python's observations: identical actions | 100 % | 100 % | 100 % |
| A forecast inputs (GHI ahead, next draw), max difference | 0 | 0 | 0 |
| Smart forecast error, rRMSE +1/+2/+3 h | 8.4 / 13.1 / 17.3 % | 8.5 / 13.6 / 18.2 % | 7.9 / 12.1 / 16.3 % |
| B closed loop (sensors, forecast, observation, PPO, interlock, plant): identical actions | 100 % | 100 % | 100 % |
| B window energy, MATLAB = Python | 543.18 kWh | 565.31 kWh | 574.05 kWh |
| Overall | **PASS** | **PASS** | **PASS** |

Files: `export*/validation_report.json`. Differences are rounding (LAPACK in MATLAB vs numba).

## Arms and parameters (`export_campaign.py`, `load_campaign.m`)

Every tank is built by **Objective 2's own setup** (`run_case` on a one-hour frame, kernel arguments captured as O3's
`o2_bridge.build_kernel_case` does), so nothing is re-derived:

| Arm | Tank |
|---|---|
| 1 plain + B0 | O2's water-only twin of the chosen design: 50.0 kg water, same flow 0.0314 kg/s, always-enable |
| 2 PCM + B0 | O2 design: 55 PureTemp 58 capsules (12.45 kg PCM, 35.13 kg water), always-enable under the in-plant shield |
| 3 PCM + PPO | same tank, recommended PPO + smart forecast |

## Three-arm table (`three_arm_2023.m` -> `export_r1/three_arm_2023.csv/.json/.png`)

| Metric (2023) | 1 plain + B0 | 2 PCM + B0 | 3 PCM + PPO |
|---|---|---|---|
| Delivered to 50 C [kWh] | 1102.3 | 1184.4 | 1142.4 |
| Delivered to 45 C [kWh] | 1012.5 | 1101.9 | 1063.2 |
| Window 18-09 h, 50 C [kWh] | 538.4 | 607.3 | 565.3 |
| Unmet at 50 C [kWh] | 2901.5 | 2819.0 | 2861.1 |
| Collector heat [kWh] | 1377.7 | 1402.5 | 1321.8 |
| Thermal efficiency (delivered 50 C / 2594.7 kWh incident) | 42.5 % | 45.6 % | 44.0 % |
| Demand coverage at 50 C | 27.5 % | 29.6 % | 28.5 % |
| Shield (guard-band) hours | 286.6 | 571.1 | 1.1 |
| Hours over a hard limit | 0 | 0 | 0 |
| Max top / PCM temperature [C] | 72.8 / - | 72.4 / 63.4 | 72.1 / 62.0 |
| Melt cycles per year / hours with 0.1 < f < 0.9 | - | 230 / 1089 | 185 / 1432 |
| Bypass hours | 0 | 0 | 918 |
| Hours the loop ran (any part) / run time | 4125 / 3714 h | 4124 / 3868 h | 3835 / 3723 h |
| Delivered 50 C per m2 collector [kWh/m2] | 734.9 | 789.6 | 761.6 |
| Delivered 50 C per kg PCM [kWh/kg] | - | 95.1 | 91.7 |

Pump: O2's Ergun pressure drop over the capsule bed is 0.008 Pa at the design flow (4e-7 W), so the bed's share of pump
energy is negligible; pipes and collector losses are not in the O2 model. Pump effort is therefore reported as hours and
pumped volume (420-437 m3/yr).

**Why each arm behaves so.** The plain tank has the most water (50 kg) and the lowest heat capacity per degree around
58 C; it reaches the 72 C shield fewer times than the PCM tank but delivers least, because it has no latent store to
carry midday heat into the evening. The PCM tank stores 12.45 kg x 225 kJ/kg of latent heat at 57-59 C, collects
24.8 kWh more and delivers 82.1 kWh more (68.9 kWh more in the window). Its top layer reaches the 72 C shield more often
(571 h) because the PCM sits in the middle nodes and the top node keeps heating. The PPO was trained with a heavy
penalty on reaching the shield band; it bypasses the collector in 918 hours (mostly late morning and early afternoon of
sunny days, see B), so it collects 80.7 kWh less than B0 and delivers 42.0 kWh less, with shield hours down from 571
to 1.1. This is the trade-off O3 reported (B0 best on delivery, PPO best on shield hours).

**2023 is an O3 validation year** (seed chosen on it): fidelity check, not an unbiased performance figure.
