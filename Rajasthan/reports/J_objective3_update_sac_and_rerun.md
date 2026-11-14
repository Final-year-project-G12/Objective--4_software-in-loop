# Report J: Objective 3 update (15 Nov 2026): SAC controllers, the DQN re-run, and what it changes in Objective 4

Source: everything in `solar-pcm-control--Objective3/rajasthan/` read on 15 Nov 2026 (docs `CORRECTIONS.md`, `METHODOLOGY_AND_FINDINGS.md`, `README_DOCS.md`, `V2_PLAN_VS_CODE.md`, `ALGORITHMS.md`; `results/gen2/`, `results/rerun_2026-11-13/`, `results/phase*`, `results/obj4_handoff/`, `results/deployment_metrics_r1.json`, the selection files, the SAC and DQN summary tables, `git log` up to commit `2f18a2e` "add rajasthan SAC"). Replay year 2023, as before. Nothing in Objective 1-3 was changed.

## 1. What Objective 3 changed (and what it did not)

| Objective 3 change | Effect on Objective 4 |
|---|---|
| DQN retrained for all regimes (45 runs, annual-only rule) | **None on the twin.** The released DQN files are unchanged: `export_r0/1/2` re-exported on 15 Nov 2026 are byte-identical (plant, weather, DQN weights, reference). The re-run does **not** reproduce the regime 1 headline run (seed 42, weight 1.7: 98.2 % of B0 / 57 % shield cut before; 100 % / 0 % when retrained). The original model is still on disk with its hash and is the one used in the spent locked test (98.0 % of B0, shield -61 %). Regimes 0 and 2: every DQN run that passes is B0-equivalent, in the original study and in the re-run, so the released DQN there still equals always-charge. |
| SAC trained: regime 1 sweep (15 runs, original), regimes 0 and 2 (reduced grid, 18 runs, re-run) | **New controllers.** SAC passes the annual rule with a large shield cut in all three regimes. These are exported, validated and run in the twin (below). |
| Delivery rule changed to annual-only (13 Nov, after the first locked test) | O3 says it is a post-hoc relaxation, with the locked test spent: **the SAC numbers have no held-out confirmation.** All three selected SAC runs pass the annual rule and fail the older annual-AND-window rule (window 92.6 / 93.4 / 94.3 % of B0). Both are reported. |
| Imperfect forecast (`forecast_mode`), plan v2 12.2 | None on the twin: the default `perfect` is bit-for-bit the old behaviour (the exports are identical). The SAC runs used here were trained with the perfect forecast (checked in `run_meta.json`; the export refuses another mode). The O4 twin supplies the perfect 3-hour forecast, a known limit. The O3 study (regime 1 DQN, 3 seeds) is inconclusive: 2 of 3 seeds sit at B0 in every case. |
| Checkpoint-resume code, plots, tests (138 pass), hand-off script (`phase8_o4_handoff.py`) | None on the numbers. The hand-off spec in `results/obj4_handoff/` (17-field V3 sensor list, fail-safe rules, test plan) still lists the DQN `dqn_r1_w1.7_s42`; it has no SAC export. |

## 2. Which SAC run, per regime

`export_from_python.py --algo sac` applies Objective 3's current rule (zero hard violations, annual delivery >= 95 % of B0, then the largest shield-hour cut) to the SAC runs of the regime and records the choice, SHA-256 and pool in `export_r<k>/sac_actor_r<k>.json`.

| Regime | SAC run | Annual % of B0 (validation 2021-23) | Window % of B0 | Shield cut | In O3's selection file? |
|---|---|---|---|---|---|
| 0 | `sac_r0_w5.85_s123` (re-run) | 95.2 | 92.6 | 96.4 % | yes (hash matches) |
| 1 | `sac_r1_w2.55_s42` (original sweep) | 95.7 | 93.4 | 86.2 % | **no: computed here.** O3's `gen2_selected_sac.json` for regime 1 was written under the old rule and not refreshed, so it still lists the always-charge run `sac_r1_w0_s42`. 6 of the 15 regime 1 SAC runs pass the annual rule. |
| 2 | `sac_r2_w0.85_s0` (re-run) | 96.4 | 94.3 | 71.1 % | yes (hash matches) |

## 3. The twin reproduces Objective 3 to rounding

- **SAC validation** (`validate_sac_against_python.m`, `export_r<k>/validation_sac_report.json`): open loop, policy on Python's observations, and closed loop all pass in the three regimes: **100 % identical actions**, identical shield counts (4112 / 23,377 / 58,550), delivered 912.523 / 873.573 / 935.093 kWh, temperature differences 1.6e-13 / 2.3e-13 / 2.7e-13 °C. No hour is within 1e-5 of a binning edge.
- **Cross-check against O3's own 2023 results** (`compare_with_o3.m`, `results_campaign/o3_crosscheck_2023.csv`): the water-only twin, B0 and B1 (all regimes), the released DQN (regime 1) and the three SAC runs agree with Objective 3's tables to **6e-12 kWh** in delivered energy, **8e-13 kWh** in window energy and **6e-14 h** in guard-band hours. The O4 plain-tank arm is Objective 3's "twin"; B1 (`b1_policy.m`) is a new port of Objective 3's reactive rule.
- **Objective 3's sensor faults** (`run_o3_sensor_faults.m`, `o3_sensor_faults_vs_o3_dqn_r1.csv`): the five deterministic faults for the DQN (nominal, dead pyranometer, stuck at 500 W/m², +2 °C water bias, PCM-sensor dropout) agree with O3's `phase9_sensor_faults_r1.csv` (2023) to 3e-12 kWh. The two noisy ones differ (<= 0.38 kWh, 3.9 guard-band hours) because NumPy and MATLAB draw different random numbers. This also confirms the dead-pyranometer numbers of report C (908.85 kWh, 701 guard-band hours) against an independent Objective 3 result.

## 4. Four arms, 2023 (`export_r<k>/four_arm_2023.csv`, `results_campaign/campaign_regimes_sac.csv`)

| Regime | Arm | Delivered [kWh] | Window [kWh] | Guard-band h | % of B0 delivery | Shield cut | Hold at 45 °C [h] (censored of 12) | Hold at 50 °C [h] |
|---|---|---|---|---|---|---|---|---|
| 0 | water-only | 819.9 | 480.8 | 605 | 85.9 | 24 % | 43.7 (0) | 28.9 |
| 0 | PCM + B0 (= DQN) | 955.0 | 610.1 | 798 | 100 | 0 | 52.1 (3) | 39.0 |
| 0 | **PCM + SAC** | **912.5** | 567.9 | **28.6** | 95.6 | **96.4 %** | 47.5 (0) | 31.3 |
| 1 | water-only | 770.5 | 452.8 | 755 | 84.4 | 24 % | 51.9 (1) | 35.2 |
| 1 | PCM + B0 | 912.4 | 587.2 | 994 | 100 | 0 | 61.2 (7) | 53.4 |
| 1 | PCM + DQN | 897.3 | 572.1 | 430 | 98.3 | 56.7 % | 61.0 (6) | 50.9 |
| 1 | **PCM + SAC** | **873.6** | 548.4 | **143.6** | 95.7 | **85.5 %** | 56.1 (4) | 42.8 |
| 2 | water-only | 823.9 | 479.9 | 626 | 84.9 | 42 % | 46.7 (1) | 31.0 |
| 2 | PCM + B0 (= DQN) | 970.3 | 619.6 | 1073 | 100 | 0 | 56.4 (3) | 46.1 |
| 2 | **PCM + SAC** | **935.1** | 584.4 | **307** | 96.4 | **71.4 %** | 55.0 (3) | 41.5 |

- **The SAC is the first controller that differs from always-charge in regimes 0 and 2**, and in regime 1 it cuts guard-band hours much further than the DQN (86 % against 57 %).
- **What it costs:** 3.6-4.5 % of annual delivery (35-42 kWh a year) and 5.7-6.9 % of window energy against B0, and **retention**: the 45 °C hold is 4.6 h shorter than B0 in regime 0, 5.0 h in regime 1 (4.8 h against the DQN), 1.4 h in regime 2. Objective 3's reward has no retention term, so this trade-off was never optimised; the PCM gain over the water-only tank shrinks from +8.3 / +9.3 / +9.8 h (B0) to +3.8 / +4.3 / +8.3 h (SAC). The DQN in regime 1 holds as long as B0; the SAC does not.
- **The SAC reaches 0 hard-limit hours** in all runs; the shield acts on the true state.
- The SAC switches about 3,400-3,800 times a year (Objective 3's count for the selected runs), idling 1501 / 1693 / 1731 h and bypassing 1811 / 1105 / 1652 h.

## 5. PCM swap and flow with the SAC (regime 1; `campaign_results_swapsac.csv`)

The SAC was trained for PureTemp 60 at the Objective 2 flow, so swapping PCM or flow is also a robustness test of the policy. Delivered [kWh] / hold at 45 °C [h] / guard-band hours at flow x1.0: PureTemp 60 873.6 / 56.2 / 144; CrodaTherm 60 853.0 / 59.4 / 202; n-Heptacosane 854.5 / 57.2 / 201. At x0.7 and x1.3 the delivered energy moves by under 8 kWh and the hold by under 2.5 h. The window-energy gain over the water-only tank is +71 to +98 kWh (against +109 to +138 kWh with B0). PureTemp 60 delivers the most and has the shortest hold of the three, as with B0 and the DQN; three PCMs remain too few for a ranking claim.

## 6. Edge cases with the SAC (`export_r<k>/scenarios_4arm/`)

Delivered in the 4-day event [kWh] / guard-band hours, regime 1 (plain, B0, DQN, SAC): clear 9.2 / 11.3 / 11.0 / 10.2 and 14.0 / 18.8 / 7.8 / **0.9** h; heat wave 10.4 / 12.6 / 11.9 / 12.1 and 17.2 / 23.0 / 3.3 / 6.1 h; low temperature 10.9 / 12.4 / 10.8 / 11.2 and 7.3 / 10.6 / 0 / 0.7 h (the SAC beats the DQN there); sensor fault 7.1 / 8.6 / 8.4 / 7.6 and 10.5 / 14.0 / 5.6 / 0.7 h; no sunlight and rain: no arm helps (0.2 and 2.5 kWh). Regimes 0 and 2 are similar (SAC about 6 % below B0 in energy, almost no guard-band time in clear and heat-wave cases). On clear days in regime 1 the SAC gives up 0.8 kWh against the DQN (10.2 against 11.0).

## 7. The SAC depends on its sensors (`o3_sensor_faults.csv`, Objective 3's fault set, 2023)

Regime 1, delivered [kWh] / guard-band hours: SAC nominal 873.6 / 144; dead pyranometer 876.6 / **535**; stuck at 500 W/m² 876.5 / 226; +2 °C water bias 873.9 / 146; 2 % noise 872.7 / 139; PCM-sensor dropout 905.7 / **660**; combined 876.8 / 536. DQN: 897.3 / 430 nominal, 908.9 / 701 dead, 905.1 / 646 dropout. **A dead pyranometer or a frozen PCM estimator removes most of the SAC's safety benefit** (regime 2: 1069 guard-band hours against 307 nominal, and 1073 for B0) while raising delivery by 0.3-3.7 %. There are no hard-limit hours and no interlock fail-safe hours in any case: the in-plant shield protects the tank, but the interlock has no plausibility rule, so the loss of benefit is silent. Mitigation to carry to the report: an irradiance plausibility check, and Objective 3's own fail-safe rule (fall back to B1 when the f_melt estimator diverges). B1 (Objective 3's reactive rule, now in the twin as policy mode 3) delivers 765.8 / 844.9 / 866.7 kWh in regimes 1 / 0 / 2 with 34 h of guard band in regime 1: lower delivery than the SAC (-107 kWh in regime 1) but a valid fallback.

## 8. What this does and does not establish

- The twin's agreement with Objective 3 is to rounding for every controller and baseline compared: the twin is a faithful replay of Objective 3's environment, now including the SAC.
- The SAC results are validation-year (2023) only, on a year Objective 3 used to select the run; the locked test years (2006-2010) are spent and were not re-run. No SAC number has held-out confirmation. The annual-only rule is a post-hoc change.
- Regime 1's SAC is selected here by Objective 3's rule, not by Objective 3's selection file (stale for that regime).
- The retrained DQN is not reproducible (regime 1), so the released DQN's model file and hash, not the training recipe, are the deliverable.
- Software only; the forecast is perfect and next-hour demand is perfect.


## Addendum (15 Nov 2026): smart-persistence forecast check

Scoring the released controllers with Objective 3's smart-persistence forecast, without retraining: delivery changes by 0.1-0.4 % (DQN r1 897.26 to 894.79 kWh; SAC 873.57 to 870.52, 912.52 to 909.10, 935.09 to 934.06 kWh in regimes 1 / 0 / 2), guard-band hours fall (430 to 392, 144 to 125, 28.6 to 24.4, 307 to 301), 45 C hold unchanged to 0.1 h. Validation against Objective 3's Python smart run: SAC 100 % identical; DQN 99.989 % (one float32 near-tie hour, 3346, relative Q gap below 1e-5; delivered difference 0.007 %). Source: `results_campaign/forecast_optimism_2023.csv`. 20-seed sensor-fault intervals are in `export_r<k>/scenarios_4arm/sensor_fault_20seed_ci.csv`.
