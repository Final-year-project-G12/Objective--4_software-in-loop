# Prompt A: validation, parameter check, three-arm comparison

## Validation against the Python simulator

Source: `export/validation_report_v3.json` (and `export_r1/`, `export_r2/`), run 14 Nov 12:48, replay year 2011, 8760 h.

| Regime | Open-loop max dT | Delivered (MATLAB = Python) | Shields | Action agreement | Result |
|---|---|---|---|---|---|
| r0 | 2.7e-13 C | 2069.64 kWh | 21,954 | 100 % | PASS |
| r1 | 2.6e-13 C | 2059.62 kWh | 17,227 | 100 % | PASS |
| r2 | 2.1e-13 C | 2068.73 kWh | 22,763 | 100 % | PASS |

Three parts passed: open-loop plant, policy-only, closed loop.

Note: this regression ran on 2011, a locked test year, as it reproduces the Python simulator and is not a performance claim. The three-arm results below use 2021.

## Three-arm comparison (2021, 1-hour steps, regime 0)

Source: `export/three_arm_2021.csv/.json/.png`.

| Arm | Delivered kWh | Unmet kWh | Shield trips | Hard violations | Thermal efficiency | Demand coverage |
|---|---|---|---|---|---|---|
| 1 plain tank + B0 | 1853.5 | 684.3 | 17,020 | 0 | 38.5 % | 73.0 % |
| 2 PCM + B0 | 2002.6 | 488.9 | 39,705 | 0 | 41.5 % | 80.4 % |
| 3 PCM + SAC | 1971.4 | 499.9 | 18,604 | 0 | 40.9 % | 79.8 % |

Arm 3 matches the O3 nominal figures (1971.4 kWh, 18,604 shields), which confirms the twin reproduces O3.

## What the numbers say

- PCM adds +149 kWh (+8 %) delivered and cuts unmet demand by 195 kWh against the plain tank.
- SAC gives up 31 kWh against B0 but halves the shield trips (-53 %), to about the plain tank's level.
- No hard-limit violations in any arm.

## Verified by me (14 Nov, after the audit)

- **Controller hash:** SHA-256 of `results/sac/r0_smartfc/best_model/best_model.zip` is `fb13d8415f3338f5f1d6caafbf0e79d4c64bb365c8f4daa59d0d854be63aa1b2`, identical to `docs/DEPLOYMENT_CONTROLLER.md` and to `results/obj4_handoff/policy_sac_r0_smartfc.zip`.
- **Export matches the model:** `export/sac_actor_r0.json` first-layer weights are identical to the model's (max difference 0.0). `source_checkpoint` points to the r0_smartfc model, V3 observation, smart forecast.
- **Observation size is 15, not 17:** the exported actor takes `obs_dim` 15. Earlier notes (including mine) said 17 fields. Use 15 in the sensor list.
- **O2 design vs twin:** `plant_params.json` matches `objective2_design_optimization/results/g10_selection_r0.json` (PureTemp 58, 104 capsules, flow 0.03876 kg/s, PCM mass 24.8137 kg, 70.4 kg water, 2.5 m2 collector). Checked by value.

## Still not verified

- A file hash of every O1 and O2 input file (the PCM database, the O1 snapshot). No parameter-check output file exists in `export/`; the check above is by value for the O2 design only.
