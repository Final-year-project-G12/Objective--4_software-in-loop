# I. Requirements checklist, cross-state table, limitations

## Joint plan deliverables (docs/plan_O4.md section 5) for Uttarakhand

| # | Deliverable | Status | File(s) |
|---|---|---|---|
| 1 | Validation pass | PASS, r0 / r1 / r2, 2023 | `export*/validation_report.json`, report A |
| 2 | Three-arm table, same metrics | Done | `export_r1/three_arm_2023.csv/.json/.png` |
| 3 | One-day cycle plot with explanation | Done | `export_r1/one_day_cycle_2023.csv/.png`, report B |
| 4 | Edge-case table | Done, 9 scenarios x 3 arms | `export_r1/scenarios_3arm/`, report C |
| 5 | Hold-time table at 30/40/45/50 C | Done | `export_r1/hold_test*.csv`, `hold_test.png`, report D |
| 6 | PCM-swap table | Done, 3 PCMs x 3 flows x B0/PPO | `export_r1/pcm_swap_study.csv`, report E |
| 7 | Benchmark error bar | Done | `results_campaign/benchmark_amanowicz*`, report G_H |
| 8 | Cross-state table and figure | Done with the files on disk | `results_campaign/cross_state_table.csv/.png` (`cross_state_table.py`) |
| 9 | One-day video with the pump fix | Done | `video/o4_three_arm_day105_2023.mp4`, report F |
| 10 | README, limitations | Done | `../README.md`, this file |
| - | Checks (restart 0, closure, swap, zero input, exponential, sub-step) | All PASS except the sub-step gate (reported) | `results_campaign/energy_balance_report_r1.json`, report D |
| - | 20-seed sensor-fault CIs | Done | `results_campaign/sensor_fault_seeds.csv`, report G_H |
| - | Shared cross-state format, regimes 0, 1, 2 | Done | `results_campaign/shared_format_table_uttarakhand_2023.csv` |
| - | Simulink week, generated C (current controller) | PASS | `export_r1/validation_simulink_168h.json`, `codegen_verification.json` |

## Cross-state table (`cross_state_table.py`; delivered to 45 C so all three states use one target)

| State, year | Controller | Arm | Delivered 45 C [kWh] | per m2 [kWh/m2] | per kg PCM [kWh/kg] | Hold 45 C, mean [h] (censored) |
|---|---|---|---|---|---|---|
| Tamil Nadu, **2021** | SAC | plain + B0 | 1853.5 | 741.4 | - | 21.6 (0) |
| | | PCM + B0 | 2002.6 | 801.0 | 80.7 | 51.6 (1) |
| | | PCM + SAC | 1971.4 | 788.6 | 79.4 | 49.9 (0) |
| Rajasthan, 2023 | DQN | plain + B0 | 770.4 | 513.6 | - | 51.9 (1) |
| | | PCM + B0 | 912.4 | 608.2 | 68.2 | 61.2 (7) |
| | | PCM + DQN | 897.3 | 598.2 | 67.0 | 61.0 (6) |
| Uttarakhand, 2023 | PPO + smart forecast | plain + B0 | 1012.5 | 675.0 | - | 23.3 (0) |
| | | PCM + B0 | 1101.9 | 734.6 | 88.5 | 32.6 (0) |
| | | PCM + PPO | 1063.2 | 708.8 | 85.4 | 26.0 (0) |

Read with care: Tamil Nadu's row is its **2021** run (its 2023 three-arm table is not in the repository yet; re-run
`cross_state_table.py` when it is); Tamil Nadu is a 100 L / 2.5 m2 single-node tank read at its one node, the other two
are 50 L / 1.5 m2 ten-node tanks read at the top layer; the forecasts differ (Tamil Nadu smart, Rajasthan perfect,
Uttarakhand smart from the pyranometer), so the controllers are not directly comparable. Common pattern: in every state
the PCM tank beats the plain tank on delivery and hold, the learnt controller delivers slightly less than always-on
(-1.6 % / -1.7 % / -3.5 %) and cuts shield activity, and no controller improves retention.

## Limitations (Uttarakhand)

- Software only: the twin reproduces the Objective 3 simulator (to 1e-13 C), not a real tank.
- 2023 is an O3 validation year on which the PPO seed was selected: fidelity check, not an unbiased performance figure.
- One seed of the PPO (the primary seed by O3's rule); the PCM swap, edge cases and checks are for regime 1 (three
  arms and hold test for regimes 0, 1, 2 in `shared_format_table_uttarakhand_2023.csv`); the 20-seed intervals cover
  sensor noise only.
- The forecast is the smart-persistence forecast from the pyranometer; next-hour demand is O2's fixed profile (perfect).
- Pyranometer dependence: a faulty pyranometer corrupts both the GHI input and the forecast, and the interlock does not
  detect it. The policy's T_mains input is out of distribution for any real mains change (std 0.001 C in training).
- Three PCMs and one regime are too few for a ranking claim.
- Hold times are model values with real ambient, no draw and no sun; the literature retention figures (12 h,
  24-36 h, 24-48 h) are not this project's measurements.
- Sub-step gate not met (-0.059 % against 0.05 %), from the sensible-heat hours; reported, not relaxed.
- The benchmark compares with a printed linear fit of a single experiment with a different PCM and capsule shape.
- Pump energy: O2 models only the Ergun capsule bed (0.008 Pa, negligible); pipes and collector losses are not modelled.
- Simulink was checked for one week only (0.31 s per simulated hour); the generated C was compared with MATLAB and
  Python, not run on a microcontroller (processor-in-the-loop is the next stage).
