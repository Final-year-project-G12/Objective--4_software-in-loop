# Objective 4: software-in-the-loop digital twin (Rajasthan)

## Goal

Test, in simulation, what Objectives 1 to 3 produced. O1 picked the PCM, O2 optimised the tank design, and O3 trained the DQN controller. We check how much each one contributes, and how long the PCM tank actually holds heat.

**Scope for Rajasthan:** regime 1 (Nagaur medoid RJP_0192) is the primary regime; the O2 PCM is PureTemp 60 and the O1 top-3 is PureTemp 60, CrodaTherm 60 and n-Heptacosane (C27). The controller is the released DQN `dqn_r1_w1.7_s42_V3_60min_dr` (`results/gen2/gen2_selected_dqn.json`, SHA-256 checked against the export). The replay year is 2023, an O3 validation year (the locked test years 2006-2010 and 2011-2015 are not reused). Regimes 0 and 2 are validated and run, but their released policies always charge, so they carry no controller benefit. No retraining, and no change to the physics, controller or contract.

Everything below is in `Rajasthan/` (code in `matlab/`, outputs in `results_campaign/`). Tamil Nadu, Uttarakhand and Objectives 1 to 3 were not touched.

## What we do

1. **Re-export and validate the twin.** The O3 handoff export was re-run for regimes 0, 1 and 2 on 14 Nov 2026 into a scratch folder: every file is byte-identical to the existing `export_r*/` files, so the old files were kept. Open-loop, policy-only and closed-loop validation against the Python simulator pass for all three regimes (delivered 954.983, 897.262 and 970.320 kWh; 100 % identical actions). O1, O2 and O3 inputs are checked by path and SHA-256 in `results_campaign/campaign_config.json`, and `build_campaign_config.py` asserts the cluster count (3), the shortlist, and the twin's tank volume, collector area, PCM mass and flow against the O2 values (all pass).
2. **Three-arm comparison** over 2023 at 1-hour steps: (1) plain water-only tank of the same 50 L, (2) PCM with a fixed controller (B0, always-charge) and no AI, (3) PCM with the DQN. Delivered kWh at 45 °C, unmet kWh, guard-band (shield) hours, hard-limit hours, melt cycles and pump hours are reported; efficiency is reported as kWh per kg PCM and per m² of collector.

   | Arm | Delivered | Window 18:00-09:00 | Unmet | Guard-band hours |
   |---|---|---|---|---|
   | Water only + B0 | 770.4 kWh | 452.8 kWh | 1658.8 kWh | 755 h |
   | PureTemp 60 + B0 | 912.4 kWh | 587.2 kWh | 1516.3 kWh | 994 h |
   | PureTemp 60 + DQN | 897.3 kWh | 572.1 kWh | 1531.4 kWh | 430 h |

3. **One-day cycle plots:** figure F2 (about two days around the best evening) shows irradiance, the 10 layer temperatures against 45 / 72 / 75 °C, melt fraction, commanded against executed action, and cumulative delivered and unmet energy; F1 is the layer-by-time temperature map. The per-scenario plots from `run_scenarios` show the same panels for the edge cases.
4. **Edge cases:** the six scenarios (clear, no sunlight, rain/cloud, low temperature, heat wave, sensor fault with a 12 h blackout) plus a **dead pyranometer** (reads 0 W/m² for the whole run while the real sun drives the plant). Figure F9 shows all seven, DQN against B0. A pyranometer **stuck at a non-zero value** was not run. Dead-pyranometer results: the DQN delivers about 11.5 kWh more per year than with a healthy sensor and spends 701 guard-band hours instead of 430 (B0: 994); the interlock never triggers on it (no irradiance plausibility rule); 20 seeds on the 10-day window give 11.16 ± 0.02 kWh and 11.31 ± 0.02 shield hours for the DQN against 11.03 and 7.72 with a healthy sensor.
5. **Checks** (`check_energy_balance`): restart correctness, difference 0 (exact); energy closure 2.7e-12 % over 4800 h (limit 0.1 %); PCM swap reproduces the O2 vector; plain-tank cool-down is the exponential; zero input does not drift. **Sub-step gate not met:** halving 150 s changes annual delivered energy by 0.080 % (gate 0.05 %, not relaxed); it comes from the sensible-heat hours (-0.726 of -0.731 kWh), not the 2929 melting hours, and the water-only tank changes by 0.66 %.
6. **Hold test.** After charging stops at 18:00, hours until the top layer falls below 30, 40, 45 and 50 °C, over 12 start evenings, 72 h cap, for all three arms. Measured values (mean of 12), not the literature figures (12 h, 24-36 h, 24-48 h):

   | Arm | 30 °C | 40 °C | 45 °C (runs at the cap) | 50 °C |
   |---|---|---|---|---|
   | Water only + B0 | 72 (capped) | 64.2 | 51.9 (1 of 12) | 35.2 |
   | PureTemp 60 + B0 | 72 (capped) | 67.0 | 61.2 (7 of 12) | 53.4 |
   | PureTemp 60 + DQN | 72 (capped) | 67.0 | 61.0 (6 of 12) | 50.9 |

   The PCM adds about 9 to 10 h at 45 °C; the DQN does not cost retention. The 30 °C column is at the cap everywhere (mains water is 26 °C).
7. **PCM swap.** Top-3 PCMs from O1 (PureTemp 60, CrodaTherm 60, n-Heptacosane) with the geometry held fixed, each with B0 and the DQN at the O2 flow; the flow axis (x0.7, x1.0, x1.3) is run for the O2 PCM only, not for the other two. The three PCMs differ by about 1 h in hold time; three items are too few for a ranking claim.
8. **Benchmark** against Amanowicz & Turski 2025 (RT44HC cool-down, the 14 K and 26 K drops), compared with the paper's own printed fits. The first mapping (one sphere per cuboid capsule) gave a 4.5-4.9 K warm bias; the diagnosis showed that was a geometry-mapping artefact, not a constant. With spheres matching the slab's PCM mass and surface/volume ratio the frozen constants give RMSE 1.06 K (loss from the paper's insulation data) and 1.41 K (loss fitted to the water-only case). **We also calibrated:** `c` fitted on this benchmark is 5.03 against the frozen 5 (null), checked on Tan 2009 and Dong 2022 as held-out cases; campaigns with c = 5.03 and with a c = 7.1 bound are kept next to the default.
9. **Pump-bug fix, one-day video, figures and README.** The pump is drawn running only when the collector adds heat (it used to run whenever CHARGE was commanded). Animations: A1 (schematic, 5 clear days), A2 (72 h retention), A3 (3-D cutaway of that hold). Figures F1 to F9, and the three Rajasthan documents (`README.md`, `OUTPUTS_GUIDE.md`, `OBJECTIVE4_DISCUSSION.md`) are updated to match the code.

Also done, beyond the Tamil Nadu list: generated C of the controller verified for regime 1 (9 files, 1163 lines, 100 % identical decisions over 8760 h, MinGW64), a one-week Simulink run (100 % identical actions; the generated files were then deleted), the supercooling proxy (freezing point 2 K lower, effect under 1 h), pump electrical energy from O2's Ergun head (0.005 Wh per year, a lower bound), 20-seed confidence intervals on the sensor-fault case, and a three-regime side-by-side (F5).

## Where we differ from Tamil Nadu

| | Tamil Nadu | Rajasthan |
|---|---|---|
| Controller | SAC | DQN |
| Tank model | One water node plus one PCM node | 10-node stratified tank, PCM in 5 of the nodes |
| Sizing | 100 L / 2.5 m² | 50 L / 1.5 m² (33.3 L/m², below IS 12976:2023) |
| Replay year | 2011 (locked test year) | 2023 (O3 validation year; clean, but the policy was selected on it) |
| Exports | Must be re-run (old exports are stale) | Re-run and byte-identical; existing exports kept |
| Controller benefit | Smart-forecast SAC | Only regime 1 differs from always-charge; regimes 0 and 2 always charge |
| Capsule calibration | Not done | Done: diagnosed, c = 5.03 (null), held-out on Tan 2009 / Dong 2022 |
| Pyranometer cases | Dead and stuck | Dead (0 W/m²) only; stuck at a non-zero value not run |
| Extras | | Simulink week run, 3-D animation, 20-seed sensor-fault confidence intervals, supercooling proxy, pump energy, three-regime figure |

## Where we can work together

- **Shared code.** These are written in `Rajasthan/matlab/` and call only the Rajasthan plant, so the single-node twin needs an adapter, not a copy: `run_hold_test.m` (restart from a stored state, 72 h, thresholds), `twin_metrics.m` (one definition of every metric), `check_energy_balance.m`, `run_campaign.m` and `build_campaign_config.py`. The DQN controller, the 10-node tank and the capsule calibration should not be copied.
- **Compare results.** The 12 hold-test start days are `round(linspace(15, 345, 12))`, taken at the end of the 17:00 local hour (18:00 start), with the node state from the full-year run. The three-arm layout (water-only B0, PCM + B0, PCM + controller) and the metric definitions in `twin_metrics.m` are the ones to match, so the two states can be put in one table. Report delivery and retention at both 45 and 50 °C and normalise per kg PCM and per m² collector, because the tanks differ in size.
- **Check the same thing both ways.** Restart difference (Rajasthan: 0), energy-balance gates including the failing sub-step gate (Rajasthan: 0.080 %, from the sensible-heat hours), and the benchmark error bar (Rajasthan: RMSE 1.06-1.41 K with the matched capsule mapping; the single-node plant should use the same mapping, the surface/volume-matched spheres in `amanowicz_case.m`).
- **Agree the thresholds.** Same as Tamil Nadu: hold time read at 30, 40, 45 and 50 °C, capped at 72 h, censored runs counted. Rajasthan's contract target is 45 °C.

## Known limitations (state in the report)

- Software only, no hardware validation; the capsule model is not experimentally validated for this design.
- One trained controller (DQN seed 42); no retraining. 2023 is a validation year the policy was selected on, so runs are a fidelity check, not an unbiased performance figure.
- Forecast fields are supplied, not sensed: a perfect 3-hour GHI forecast and perfect next-hour demand. Melt fraction and the two energy fields are treated as perfect estimates.
- The controller depends on the pyranometer, and the interlock has no irradiance plausibility rule, so a dead sensor is not detected: about 11.5 kWh more delivered per year than healthy but 270 more guard-band hours (safe: no hard-limit hours).
- Hold times are model values. The frozen capsule model matches the tank benchmark (1.1-1.4 K) but a single sphere in a bath (Tan 2009) still melts faster in experiment; a faster-capsule run (c = 7.1) lengthens the 45 °C hold by 0.4-1.7 h, so the frozen values are slightly short, not optimistic.
- Sub-step gate (0.05 %) not met: 0.080 % for 150 to 75 s.
- Three PCMs per cluster, one regime, one year, 12 start evenings: too few for a PCM ranking claim.
- Supercooling is a proxy only; pump energy is the capsule bed's share only (lower bound).
- Literature retention figures (Chen 2025: 31.7 h above 30 °C on 30 L/day, no controller) are not this project's measurements.
- O2 sizing 50 L / 1.5 m² is below IS 12976:2023 (O2 decision D8); stated, not changed.
- Not done: a pyranometer stuck at a non-zero value; option C1 (3-D single capsule, needs the Partial Differential Equation Toolbox, not installed); a cross-state comparison figure (needs the other twins' outputs); Simulink beyond one week.
