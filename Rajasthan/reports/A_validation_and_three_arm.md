# Prompt A: controller check, handoff re-run, export, validation, parameter check, three-arm comparison

Sources: `export_r*/validation_report.json`, `export_r1/three_arm_2023.csv` / `.json` / `.png`, `results_campaign/campaign_config.json`, `build_campaign_config.py` output. Replay year **2023** (an Objective 3 validation year).

## Controller check

The exported DQN is the one recorded in `results/gen2/gen2_selected_dqn.json` for each regime: `export_from_python.py` checks the SHA-256 ("sha256 matches gen2_selected: True") and the weights are exported as plain matrices (`export_r<k>/dqn_qnet_r<k>.json`). On Python's own observations the MATLAB policy gives 100 % identical actions in all three regimes (max relative Q difference 4.9e-07).

## Handoff re-run and export

`export_from_python.py --regime 0/1/2` was re-run on 14 Nov 2026 into a scratch folder with the current Objective 2 and 3 outputs. `plant_params.json`, `weather_2023.csv`, `dqn_qnet_r<k>.json` and `reference_2023.csv` are byte-identical to the existing `export_r*/` files, so nothing was replaced.

## Validation against the Python simulator (full year 2023, 8760 h)

| Check | Regime 0 | Regime 1 | Regime 2 |
|---|---|---|---|
| Open-loop plant, max top-node temperature difference | 1.8e-13 °C | 2.1e-13 °C | 3.0e-13 °C |
| Shield activations, twin = Objective 3 | 115,463 | 101,899 | 227,778 |
| Policy on Python's observations | 100 % identical | 100 % | 100 % |
| Closed loop (sensors, observation, policy, interlock, plant) | 100 % identical | 100 % | 100 % |
| Delivered heat, twin = Objective 3 [kWh] | 954.983 | 897.262 | 970.320 |
| Hard-limit violations | 0 | 0 | 0 |

## Parameter check

`build_campaign_config.py` asserts the twin's plant against Objective 2: tank volume 50 L, tank volume rebuilt from node water + displaced capsule volume 50 L, collector area 1.5 m², PCM mass 13.3826 kg, flow 0.0492621 kg/s: five lines, all PASS. Inputs are recorded with SHA-256 in `campaign_config.json` (the Objective 1 database and shortlist, the Objective 2 selection and config, the exported DQN) and the cluster count (3) and shortlist are asserted. Limitation kept: 50 L / 1.5 m² = 33.3 L/m², below the 40-100 L/m² band of IS 12976:2023.

## Three-arm comparison, 2023, 1-hour steps (`three_arm_2023.csv`)

| Arm | Delivered [kWh] | Unmet [kWh] | Shield activations | Guard-band hours | Efficiency | Demand coverage |
|---|---|---|---|---|---|---|
| 1 plain tank + B0 | 770.45 | 1658.8 | 18,123 | 755 | 26.5 % | 31.7 % |
| 2 PCM + B0 | 912.36 | 1516.3 | 314,610 | 994 | 31.3 % | 37.6 % |
| 3 PCM + DQN | 897.26 | 1531.4 | 101,900 | 430 | 30.8 % | 36.9 % |

Efficiency = delivered / incident solar energy on the collector (GHI × 1.5 m²); coverage = delivered / (delivered + unmet). Coverage is low because a 50 L tank serves a 300 L/day draw (the sizing limit above). **Shield activations are not comparable with the single-node Tamil Nadu twin's**: this kernel counts PCM trips per node and sub-step; use guard-band hours.

**Is arm 3 better than arms 1 and 2?** Only partly:
- Against the plain tank: yes. +126.8 kWh delivered, +9 to +10 h of hold at 45 °C (report D).
- Against PCM + B0: **no on delivered energy** (the DQN delivers 15.1 kWh less in the year) and **no on hold time** (61.0 against 61.2 h). **Yes on safety:** 57 % fewer guard-band hours (430 against 994), 68 % fewer shield activations.
- So the honest claim is: the PCM gives the energy and retention benefit, and the DQN gives nearly the same benefit with far fewer safety interventions. Do not claim the DQN improves retention.
- Only regime 1's DQN differs from always-charge; the released regime 0 and 2 DQN policies always charge, so their arms 2 and 3 are identical. The Objective 3 SAC (15 Nov 2026) differs in all three regimes: see `J_objective3_update_sac_and_rerun.md` and `export_r<k>/four_arm_2023.csv` (regime 1: SAC delivers 873.6 kWh, 143.6 guard-band hours, hold 56.1 h).
