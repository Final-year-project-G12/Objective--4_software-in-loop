# Hold-time results computed for the documentation portal (15 Nov 2026)

The repository had hold-time outputs only for Tamil Nadu regime 0 and Rajasthan (all regimes). These fill the gap:

| Files | State and regimes | Replay year | Script |
|---|---|---|---|
| `three_arm_hold_r{0,1,2}.csv`, `three_arm_hold_thresholds_r{0,1,2}.csv` | Uttarakhand, regimes 0-2 | 2010 | `three_arm_hold_fix.m` |
| `hold_test_r{1,2}.csv`, `hold_test_thresholds_r{1,2}.csv` | Tamil Nadu, regimes 1-2 | 2011 | `tn_hold_fix.m` |

Both scripts are copies of the repository's own (`Common/three_arm_hold.m`, `Tamilnadu/matlab/run_hold_test.m`) with these changes only:

* `three_arm_hold_fix.m`: the 18:00 start index is found from the `local_hour` column instead of the fixed `+19`. The exported weather starts at local hour 5, so `+19` starts the hold at 23:00 and gives negative hold times (the same bug the Tamil Nadu script documents). `Common/three_arm_hold.m` itself is unchanged and still has it.
* `tn_hold_fix.m`: the plain-tank water mass is computed from the capsule volume (capsules x pi/6 x D^3 / 100 L) instead of reading `objective2_design_optimization/results/g10_selection_r0.json`, which is not in this repository and is regime 0 only; output goes next to these files.

Method otherwise as in the repository: 18:00 start from each arm's own state, sun off, no draw, up to 72 h, 12 start days (day 10 to 350), hold read at 30 / 40 / 45 / 50 C.
