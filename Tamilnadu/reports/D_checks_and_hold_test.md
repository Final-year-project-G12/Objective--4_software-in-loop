# Prompt D: restart check, energy balance, hold test

Sources: `export/restart_check.json`, `energy_balance_report.json`, `hold_test.csv`, `hold_test_thresholds.csv`.

## 1. Restart correctness

Difference in water temperature, PCM temperature and melt fraction: **0** (exact). Action agreement 100 %. PASS. The naive restart (without the stored state) drifts by up to 0.33 C in water and 0.60 C in PCM, so the check is meaningful.

## 2. Energy balance

| Check | Result |
|---|---|
| Closure, arm 1 plain | 3.6e-8 % (pass) |
| Closure, arm 2 PCM+B0 | 0.043 % (pass, gate 0.1 %) |
| Closure, arm 3 PCM+SAC | **0.263 % (fails the 0.1 % gate)** |
| PCM-swap check | pass |
| Exponential plain-tank cool-down | tau 116 h, residual 0.005 % (pass) |
| Zero input | drift under 4e-14 C (pass) |
| Sub-step (150 s against 75 s, gate 0.05 %) | arm 1 0.029 %, arm 2 0.016 %, arm 3 0.022 % (all pass) |

**Arm 3 residual (checked 14 Nov from the saved numbers):** the script divides the residual by the year's *net* stored-energy change, which is only about 0.31 kWh, so the percentage is inflated. In absolute terms:

| Arm | Residual (J) | Residual (Wh) | Delivered (kWh) | Residual / delivered |
|---|---|---|---|---|
| 1 plain | 0 | 0 | 1853.5 | 3e-12 % |
| 2 PCM+B0 | 480 | 0.13 | 2002.6 | 7e-6 % |
| 3 PCM+SAC | 2,973 | 0.83 | 1971.4 | 4e-5 % |

So the 0.263 % "fail" is mostly a normalisation artefact: the gate was compared with Objective 2's 0.1 % figure, which may not use the same denominator. The earlier "action binning" explanation is **not verified**; arm 2 and arm 3 end the year in the same stored state, and the cause of arm 3's extra 2.5 kJ is not identified. Report it as: "above the 0.1 % gate as normalised, but under 1 Wh in absolute terms; cause not identified".

## 3. Hold test (after charging stops at 18:00, 72 h cap, 12 start days)

Start days: 10, 41, 72, 103, 134, 165, 195, 226, 257, 288, 319, 350 (round(linspace(15,345,12)) is the rule in `plan_O4.md`; these are the days the code uses, so confirm they match). Censored runs (still above threshold at 72 h) count as 72 h.

| Arm | 30 C | 40 C | **45 C** | 50 C |
|---|---|---|---|---|
| 1 plain tank | 72 (12/12 censored) | 55.9 (2/12) | **21.6** (0/12) | 0.0 |
| 2 PCM + B0 | 72 (12/12) | 63.7 (9/12) | **51.6** (1/12) | 0.0 |
| 3 PCM + SAC | 72 (12/12) | 63.7 (9/12) | **49.9** (0/12) | 0.0 |

- **Why 50 C reads 0:** the top of the tank at 18:00 is already 40 to 50 C (mean about 48 C, maximum 49.7 C), so it never starts above 50 C.
- **Why 30 C is always censored:** mains water is about 28.5 C, so the tank never falls below 30 C within 72 h.
- **The headline number is 45 C** (the delivery target): plain 21.6 h, PCM 51.6 h, PCM + SAC 49.9 h. The PCM adds about 28 to 30 h of hold.
- **SAC does not extend the hold** (49.9 h against 51.6 h for B0). Hold is a passive cool-down once charging stops, so the controller only affects how full the tank is at 18:00.

## 4. Comparison with the figures you read (12 h, 24-36 h, 24-48 h)

| | You read | Measured here (45 C) |
|---|---|---|
| Without PCM | about 12 h | 21.6 h |
| PCM, no AI | 24-36 h | 51.6 h |
| PCM + AI | 24-48 h | 49.9 h |

The pattern (PCM about 2 to 2.5 times the plain tank) agrees. The absolute values are higher because: (a) the literature figures are for a different tank and a 30 C threshold in some cases; (b) the model is optimistic (see report G: it loses less heat than the real experiment); (c) Tamil Nadu's warm climate slows cooling. Report the measured values, not the literature ones.

## 5. Note on an earlier bug

`matlab/d_run.log` shows a first run with negative hold times (an indexing bug at the cap). The README documents the fix. The CSVs dated 14:51 are the corrected run.
