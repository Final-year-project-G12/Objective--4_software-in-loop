# plan_O4.md: Objective 4 joint plan (Tamil Nadu and Rajasthan)

Purpose: one method both states follow, so their results can go in one table. Tamil Nadu is SAC on a single-node twin; Rajasthan is DQN on a 10-node twin. Software-in-the-loop only. No retraining and no change to physics, controller or contract.

## 1. Decisions (made)

| Decision | Choice | Reason |
|---|---|---|
| Replay year | **2023 for both states** (primary) | An O3 validation year for both (Tamil Nadu `VAL_YEARS` = 2021-2023, Rajasthan already uses 2023). Locked test years (2011-2015) stay untouched. |
| Regression year | Tamil Nadu also runs **2021** once | Only to match the O3 nominal figures (1971.4 kWh, 18,604 shields). Not used in the cross-state table. |
| Normalisation | **Adopt Rajasthan's `twin_metrics.m`**: delivered at 45 and 50 C, per kg PCM, per m2 collector | The tanks differ in size (100 L / 2.5 m2 against 50 L / 1.5 m2). |
| Extras | 20-seed sensor-fault confidence intervals: **yes** (cheap, removes the single-seed limitation). Simulink week and generated C: **no** (not needed for the objective). | |

State in both reports that 2023 was a checkpoint-selection year for the controllers, so runs are a fidelity check, not an unbiased performance figure.

## 2. Common protocol (identical in both states)

1. **Three arms:** (1) water-only tank of the same volume with B0 (always-charge), (2) PCM with B0, no AI, (3) PCM with the learnt controller.
2. **Hold test:** start days `round(linspace(15, 345, 12))`, taken at the end of the 17:00 local hour (18:00 start), node state from the full-year run, 72 h cap, thresholds 30/40/45/50 C, censored runs counted, tau_hold by linear interpolation. Read at 24/36/48 h.
3. **Measurement point:** Rajasthan reads the top layer; Tamil Nadu reads the water node (single node). State this in the table.
4. **Checks:** restart difference must be 0; energy closure, PCM-swap check, zero input, exponential plain-tank cool-down, sub-step gate (0.05 %, not relaxed; report and document if it fails).
5. **Edge cases:** clear, no sunlight, rain/cloud, low temperature, heat wave, sensor fault with 12 h blackout, plus dead pyranometer and stuck pyranometer.
6. **PCM swap:** O1 top-3, geometry held fixed, B0 and the learnt controller. Flow x0.7, x1.0, x1.3 for the O2 PCM; the other two PCMs optional.
7. **Benchmark:** Amanowicz & Turski 2025 (RT44HC cool-down, 14 K and 26 K drops), using spheres matched to the slab's PCM mass and surface/volume ratio (`amanowicz_case.m`). Diagnose the error; do not recalibrate the frozen constants.
8. **Metrics:** delivered, window (18:00-09:00), unmet, shield hours, hard-limit hours, melt cycles, pump hours, kWh per kg PCM, kWh per m2.
9. **Report measured values only,** not the literature figures (12 h, 24-36 h, 24-48 h).

## 3. Tamil Nadu specifics

- Controller: `results/sac/r0_smartfc/best_model/best_model.zip` (frozen in commit `6ccae9d`); verify SHA-256 against `docs/DEPLOYMENT_CONTROLLER.md`. Do not use `results/sac/r0`.
- Re-run `scripts/phase8_o4_handoff.py` (the old handoff is stale) and the re-export, then validate (open-loop, policy-only, closed-loop).
- Observation: 17-field V3. Mark forecast fields as supplied, not sensed. Live-mode analytic clear-sky error is about 17.6 % at +1 h (9.9 % with the stored column). Replicate the smart forecast in MATLAB (`build_obs`, `load_twin_params`, `simulate_hours`).
- Native Tamil Nadu scripts (`one_day_cycle.m`, `run_c_scenarios.m`, `run_hold_test.m`, `check_energy_balance.m`), not the 10-node Common scripts; same method as section 2.
- Extra checks: stuck pyranometer, and the regime 1 smart-forecast sensor-fault behaviour.

## 4. Rajasthan specifics (already largely done)

- Controller: DQN `dqn_r1_w1.7_s42_V3_60min_dr`, regime 1, with a **perfect** 3 h forecast. Regimes 0 and 2 always charge.
- Remaining: stuck pyranometer, and the 2023 results table in the shared format.

## 5. Joint deliverables

| # | Deliverable | Owner |
|---|---|---|
| 1 | Validation pass for each state | Both |
| 2 | Three-arm table, same metrics | Both |
| 3 | One-day cycle plot with explanation | Both |
| 4 | Edge-case table (8 cases) | Both |
| 5 | Hold-time table at 30/40/45/50 C | Both |
| 6 | PCM-swap table | Both |
| 7 | Benchmark error bar | Both |
| 8 | **Cross-state table and figure** (delivered, hold time, per kg PCM, per m2) | Joint, after both finish |
| 9 | One-day video with the pump fix | Both |
| 10 | README, limitations | Both |

## 6. Time to complete

**Tamil Nadu, from scratch**

| Step | Time |
|---|---|
| Controller check, handoff, export, validation, parameter check, three arms | 2.75 h |
| One-day plots | 1 h |
| Edge cases (8) | 1 h |
| Restart, energy balance, hold test | 3 h |
| PCM swap and flow | 2 h |
| Pump fix and video | 0.75 h |
| Benchmark | 1.5 h |
| 20-seed sensor-fault CIs | 0.5 h |
| README | 0.5 h |
| **Total** | **13 h** |

If the first three steps are already done and verified, the remaining time is **8.25 h**.

**Rajasthan, remaining:** stuck pyranometer plus 2023 table alignment, about **1 h**.

**Joint (cross-state table and figure):** about **1 h**.

To fit about 10 hours on the Tamil Nadu side, drop the benchmark first (1.5 h), then the other two PCMs' flow axis. State any cut in the report.

## 7. Limitations (both reports)

Software only; single seed 42; 2023 was a selection year; forecast fields are supplied (Tamil Nadu smart forecast, Rajasthan perfect, so the controllers are not directly comparable on forecast quality); next-hour demand perfect; the pyranometer dependence; three PCMs and one regime per state is too few for a ranking claim; hold times are model values; literature retention figures are not this project's measurements.
