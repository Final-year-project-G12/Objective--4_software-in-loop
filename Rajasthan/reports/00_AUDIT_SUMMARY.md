# Objective 4 (Rajasthan, 50 L, DQN regime 1): audit summary

Compiled 14 Nov 2026 from the files on disk in `export_r1/`, `results_campaign/`, `matlab/` and the Objective 2 / 3 outputs they read. Numbers are copied from those files and every run was done in MATLAB R2026b.

## Requirements against what exists

| Requirement | Status | Where |
|---|---|---|
| 1) Plain tank without PCM and why it behaves so | Done (numbers, plots, explanation) | A, B, D |
| 2) Selected PCM, no AI (arm 2) | Done | A, B, C, D |
| 3) O1 + O2 + O3 combined (arm 3, released DQN) | Done | A, B, C, D |
| i) One-day cycle plot, PCM and water temperature, charge/idle/bypass | Done | B |
| i) Video of the cycle | Done: three-arm 2-D day video, seven edge videos, four 3-D videos | F, I |
| ii) Edge cases, PCM reaction, all three arms | Done: six scenarios + dead / stuck pyranometer | C |
| iii) How long the PCM stores energy | Done: measured 51.9 h / 61.2 h / 61.0 h at 45 °C | D |
| PCM swap, flow axis | Done: three PCMs x three flows x two controllers | E |
| Benchmark | Done: diagnosed, calibration null | G_H |
| Retrained / released controller used | Verified: SHA-256 matches `gen2_selected_dqn.json` | A |

## Headline results (2023, regime 1, 50 L / 1.5 m²)

| Arm | Delivered kWh | Guard-band hours | Hold at 45 °C (mean of 12) |
|---|---|---|---|
| 1 plain tank + B0 | 770.5 | 755 | 51.9 h |
| 2 PCM + B0 | 912.4 | 994 | 61.2 h |
| 3 PCM + DQN | 897.3 | 430 | 61.0 h |

**Is arm 3 "better and more optimal" than 1 and 2?** Only partly:
- Against the plain tank: yes. +126.8 kWh delivered, +9 h of hold at 45 °C.
- Against PCM + B0: **no on delivered energy and hold** (the DQN delivers 15.1 kWh less and holds 0.2 h less). Yes on safety: 57 % fewer guard-band hours (430 against 994).
- So the honest claim is: the PCM gives the energy and retention benefit, and the DQN gives nearly the same benefit with far fewer safety interventions. Do not claim the DQN improves retention.

## Problems found and what was done

1. **Capsule benchmark bias (G): FOUND, RESOLVED.** The first benchmark was 4.5-4.9 K too warm. Diagnosis showed a geometry-mapping artefact (one sphere per cuboid capsule); with a surface/volume-matched mapping the frozen constants give 1.1-1.4 K. A calibration gave c = 5.03 (null). Hold times are not optimistic (a faster-capsule bound lengthens them by 0.4-1.7 h).
2. **Water-only tank false fault: FOUND, FIXED.** The interlock compared the plain tank's mean water temperature with the 65 °C PCM limit and latched a false hard-limit fault. The PCM-side limits are off for that arm only (`make_plain_tank.m`).
3. **Pump drawing (F): FIXED.** The old rule drew the pump on in 169-174 h a year per arm with no collector gain; the new rule has 0 violations.
4. **Sub-step gate (D): NOT MET, stated.** 0.080 % (gate 0.05 %); it comes from the sensible-heat hours, not the melting hours; not relaxed.
5. **Dead pyranometer (C, G_H): FINDING.** The interlock does not react (no irradiance plausibility rule); the DQN then delivers 11.5 kWh more a year but spends 701 guard-band hours instead of 430.
6. **PCM ranking (E): STATED.** The three PCMs differ by about 1 h in hold time; three items cannot support a ranking claim; PureTemp 60 (the Objective 2 choice) has the shortest hold and the highest delivered energy.
7. **Objective 1 numbers: STATED.** The Monte-Carlo percentages in Objective 2's config (99.3 / 93.6 / 56.1) differ from the Objective 1 repository's later file (95.58 / 93.72 / 55.84); Objective 2's `manifest.json` entry for that file is stale.
8. **Replay year (A, C):** every Rajasthan result, including the edge cases, uses 2023, an Objective 3 validation year (the policy was selected on it): a fidelity check, not an unbiased performance figure. The Tamil Nadu twin's edge cases use a locked test year; this one does not.
9. **Sizing:** 50 L / 1.5 m² = 33.3 L/m², below the 40-100 L/m² band of IS 12976:2023; stated, not changed. It also explains the low demand coverage (37 % of a 300 L/day draw).

## Not done

- Option C1 (3-D single capsule): needs the Partial Differential Equation Toolbox, which is not installed.
- A cross-state comparison figure (needs the other twins' outputs).
- A pyranometer that freezes at its last reading during the day (stuck is a constant here).
- Simulink beyond one week.

## What to do next

1. Add an irradiance plausibility rule to the interlock if the design goes further (the dead pyranometer case shows the gap).
2. If both states are reported in one table, use the thresholds, start days and metrics of `twin_metrics.m` and the hold test as in the scope file.
