# Objective 4 (Tamil Nadu, 100 L, SAC r0_smartfc): audit summary

Audited 14 Nov 2026 from the files on disk in `objective4_software_in_loop/export/`, `matlab/` and `results/`. Numbers are copied from those files. I did not re-run any MATLAB simulation. I extracted frames from the video to look at it.

## Your requirements against what exists

| Your requirement | Status | Where |
|---|---|---|
| 1) Plain tank without PCM and why it behaves so | Done (numbers and plots). Written explanation is thin. | B, C, D reports |
| 2) Selected PCM, no AI | Done (arm 2, PCM + B0) | A, B, C, D |
| 3) O1 + O2 + O3 combined (PCM + SAC) | Done (arm 3) | A, B, C, D |
| i) One-day cycle plot with PCM temp, water temp, all key parameters, charge/idle/bypass | Done, legend fixed | B |
| i) Video of the cycle | Done, re-rendered on day 71 | F |
| ii) Edge cases, PCM reaction, storing for all 3 arms | Done (6 scenarios + dead/stuck pyranometer) | C, H |
| iii) How long PCM stores energy | Done: measured 21.6 h / 51.6 h / 49.9 h at 45 C | D |
| Retrained O3 controller (frozen) used | Verified: SHA-256 matches `DEPLOYMENT_CONTROLLER.md`, and exported weights equal the model | A |

## Headline results (2021, regime 0, 100 L)

| Arm | Delivered kWh | Shield trips | Hold at 45 C (mean of 12) |
|---|---|---|---|
| 1 plain tank + B0 | 1853.5 | 17,020 | 21.6 h |
| 2 PCM + B0 | 2002.6 | 39,705 | 51.6 h |
| 3 PCM + SAC | 1971.4 | 18,604 | 49.9 h |

**Is arm 3 "better and more optimal" than 1 and 2?** Only partly:

- Against the plain tank: yes. +118 kWh delivered, +28 h of hold at 45 C.
- Against PCM + B0: **no on delivered energy and hold** (SAC delivers 31 kWh less and holds 1.7 h less). Yes on safety: 53 % fewer shield trips (18,604 against 39,705), at about the plain tank's level.
- So the honest claim is: PCM gives the energy and retention benefit, and SAC gives the same PCM benefit with far fewer safety interventions. Do not claim SAC improves retention.

## Problems found (fix before you present)

1. **Video (F): FIXED.** The first video showed day 313, where the PCM never melts. It is re-rendered on day 71 (`video/o4_three_arm_day071_2021.mp4`, 9.6 s, 1920x1080), with the melt, hold and release visible, "no PCM" for the plain tank, and no "data1" label. Pump check: 0 violations in all arms.
2. **One-day plot legend (B): FIXED.** The legend now names the three arms and, separately, CHARGE / IDLE / BYPASS for the background colours, and the flat plain-tank "PCM" line is removed.
3. **Energy balance (D): CHECKED, cause still open.** Arm 3's 0.263 % is inflated by dividing by the year's net stored-energy change (0.31 kWh). In absolute terms the residual is 2,973 J (0.83 Wh) against 1,971 kWh delivered (4e-5 %). The README's "action binning" explanation is not verified, so the README now says so.
4. **PCM swap (E): STATED in README and report.** The selected PCM (PureTemp 58) is not the best material in the twin; RT57HC delivers about 13 to 18 kWh more and holds about 3 to 4.5 h longer. Objective 2 chose PureTemp 58 as a tie-break, not on throughput.
5. **Benchmark (G): NOT fixable without the paper's data.** The model is 38.5 % off the 26 K measured drop (16.0 K simulated), outside the 15 % target. The curve RMSE is a two-endpoint value only. Hold times are therefore optimistic. The README already says this. It stays a stated limitation.
6. **Stuck pyranometer (C):** in the six-scenario grid, "stuck" is identical to "dropout" (the first reading is 0 at midnight). The 20-seed run (H) does separate them.
7. **Stale videos: REMOVED.** The old `.mp4` files in `export/scenarios/` (12 Nov, before the retrain) were removed from this version, along with the old Simulink model and generated C code.
8. **Replay years (A, C):** the regression validation and the six edge cases ran on 2011 (a locked test year, so exploratory); the three-arm, hold test and PCM swap ran on 2021. State both.

## What to do next

1. Write the plain-tank explanation (why it behaves that way) as text in the README. The data is there.
2. Optional: hash-check the O1 PCM database and O1 snapshot files (only the O2 design was checked, by value).
3. Use 15 observation fields (not 17) in any sensor list.
