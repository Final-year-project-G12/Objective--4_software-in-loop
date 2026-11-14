# Objective 4: software-in-the-loop digital twin (Tamil Nadu)

## Goal

Test, in simulation, what Objectives 1 to 3 produced. O1 picked the PCM, O2 optimised the tank design, and O3 trained the SAC controller. We check how much each one contributes, and how long the PCM tank actually holds heat.

**Scope for Tamil Nadu:** regime 0, a single PCM, SAC only. The controller is `results/sac/r0_smartfc` (realistic smart forecast), frozen in commit `6ccae9d`. No retraining, and no change to the physics, controller or contract.

## What we do

1. **Re-export and validate the twin.** Re-run the O3 handoff and export for the frozen controller, then run open-loop, policy-only and closed-loop validation against the Python simulator. Check every O1, O2 and O3 input by path and hash.
2. **Three-arm comparison** over 2021 at 1-hour steps: (1) plain tank without PCM, (2) PCM with a fixed controller (B0) and no AI, (3) PCM with SAC. Report delivered kWh, unmet kWh, shield events and efficiency.
3. **One-day cycle plots:** one full charge, idle and bypass cycle with water temperature, PCM temperature, melt fraction, collector gain, delivered energy and shield events, plus an explanation of why each arm behaves as it does.
4. **Edge cases:** six scenarios plus a dead and a stuck pyranometer. Show how the PCM stores and releases heat in each arm.
5. **Checks:** restart-correctness (difference must be 0) and energy-balance (closure, PCM-swap, zero input, sub-step).
6. **Hold test.** After charging stops, measure hours until the outlet falls below 30, 40, 45 and 50 °C, over 12 start days, with a 72 h cap, for all three arms. We report measured values, not the literature figures (12 h, 24-36 h, 24-48 h).
7. **PCM swap.** Top-3 PCMs from O1 (RT57HC, n-Hexacosane, PureTemp 58) at flow x0.7, x1.0 and x1.3, with the geometry held fixed.
8. **Benchmark** against Amanowicz & Turski 2025 (RT44HC cool-down, the 14 K and 26 K drops). Diagnose the error, but don't recalibrate.
9. **Pump-bug fix, one-day video, figures and README.**

## Where we differ from Rajasthan

| | Tamil Nadu | Rajasthan |
|---|---|---|
| Controller | SAC | DQN |
| Tank model | One water node plus one PCM node | 10-node stratified tank |
| Exports | Must be re-run (old exports are stale) | Existing exports reused |
| Capsule calibration | Not done | Done |
| Extras | | Simulink week run, 3-D animation, 20-seed sensor-fault confidence intervals |

## Where we can work together

- **Shared method, not shared code.** The Common/ scripts (`three_arm_hold.m` and others) are written for the 10-node stratified tank and need an adapter for Tamil Nadu's single-node plant, so we build native Tamil Nadu scripts and keep the *method* identical: 18:00 start, hold to 72 h, read at 24/36/48 h, thresholds 30/40/45/50 °C, the same censored flag and tau_hold interpolation. We build `check_energy_balance.m` from the plan's section 7.3. We won't copy the DQN controller, tank model or calibration.
- **Compare results.** Do the 12 hold-test start days, the three-arm layout and the metric definitions match, so the two states can be put in one table?
- **Check the same thing both ways.** Restart difference, energy-balance gates (including the failing sub-step gate), and the benchmark error bar.
- **Agree the thresholds.** We read hold time at 30, 40, 45 and 50 °C and cap at 72 h. Is that the same on the Rajasthan side?

## Known limitations (state in the report)

- Software only, no hardware validation.
- Single seed 42.
- Locked test years were reused for the forecast variants.
- Forecast fields are supplied, not sensed (about 17.6 % error at +1 h with an analytic clear-sky model against 9.9 % with the stored column).
- Next-hour demand is perfect in training.
- The controller depends on the pyranometer (about 14 % less delivery without it, but safe).
- DQN and PPO are excluded.
- Regime 1 smart-forecast sensor-fault behaviour is not checked.
