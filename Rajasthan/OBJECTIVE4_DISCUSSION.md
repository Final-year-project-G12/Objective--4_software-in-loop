# Objective 4 (Rajasthan) – Points to Be Discussed

**One-line summary:** Objective 4 is done as a **software-in-the-loop (SIL) digital twin in MATLAB/Simulink**: the trained Objective 3 DQN controller is plugged into a simulated Rajasthan solar PCM water heater with noisy sensors and a safety interlock, and tested on normal and extreme weather. This is *emulated* validation, not experimental validation.

**State of the work today:** the MATLAB twin has been run in MATLAB R2026b for all three regimes: full-year validation, six scenarios, plots, and (for regime 1) animations. A Python copy of the same code (`sil_python_mirror.py`) gives the same numbers as a cross-check. The Simulink model was built and run for one week of regime 1 (identical actions, 0.78 s per simulated hour; the generated files were then deleted and are rebuilt on demand); the generated C code was not run in this pass. On 14 November 2026 the improvement plan v2 was added for regime 1: a retention (hold-time) test, a PCM swap over Objective 1's top-3, a 13-run simulation matrix, energy-balance checks, a tank-level comparison with a published experiment, figures and animations (section 1.9).

---

## 1. Objective 4 – Complete Explanation

### 1.1 What we are doing

1. **Objective 4 is the deployment check of the Objective 3 controller**, done in software.
2. **The whole control chain is replicated:** weather → sensors (with noise and dropout) → observation vector → DQN policy → safety interlock → pump/valve command → collector + stratified water tank + PCM capsules → hot-water outlet.
3. **The trained DQN is copied out of Python** as plain weight matrices, so exactly the same decision-maker runs in the twin.
4. **The plant is a line-by-line port** of the Objective 2 multi-node tank kernel that Objective 3 trains on, so the twin can be checked number-for-number against Python.
5. **It is stressed with edge cases:** no sunlight, rain/heavy cloud, very low temperature, heat wave, and a sensor failure with a 12-hour blackout. Each is compared with the always-charge baseline (B0).
6. **It is shown visually:** result plots for every case and animated schematics (sun, collector, pump, two-band tank, PCM capsules changing colour as they melt).
7. **What it proves and what it does not:** it proves the controller and its safety logic behave correctly on the modelled system outside the training code. It does not replace a physical test or a comparison with published experiments.

### 1.2 Inputs and datasets

| Input | Source |
|---|---|
| Plant parameters (50 L tank in 10 nodes, 1.5 m² collector, 52 capsules, PCM properties, safety limits 72 °C / 62 °C guard band and 75 °C / 65 °C hard) | Objective 2 Rajasthan design + Objective 3 contract v3 (`export_r*/plant_params.json`) |
| Weather: hourly irradiance (GHI), ambient temperature, hour of day, year 2023, 8760 h | Rajasthan point-year weather of each regime's medoid point (`export_r*/weather_2023.csv`) |
| Hot-water demand profile (24-hour draw pattern) | Objective 2 demand model |
| Trained DQN weights (MLP 17-64-64-3) | Objective 3 (`results/gen2/gen2_selected_dqn.json`, exported to JSON) |
| Python reference trajectory (for checking only) | Objective 3 environment run with the same policy |

| Regime | Medoid | PCM (melting point) | Water / PCM mass | Loop flow |
|---|---|---|---|---|
| 0 | Udaipur (RJP_0132) | savE OM55 (55 °C) | 35.8 kg / 12.5 kg | 0.0155 kg/s |
| 1 | Nagaur (RJP_0192) | PureTemp 60 (61 °C) | 35.2 kg / 13.4 kg | 0.0493 kg/s |
| 2 | Jaipur (RJP_0083) | PureTemp 58 (58 °C) | 35.2 kg / 12.4 kg | 0.0236 kg/s |

2023 is an Objective 3 **validation** year, not a held-out test year. The held-out years cannot be re-used: 2011–2015 belong to Objective 2's test and 2006–2010 are behind Objective 3's one-shot lock. No new data was collected for Objective 4.

### 1.3 What exactly is implemented or simulated

- **Weather source** feeding hourly sunlight and air temperature, plus the next three hours of sunlight as the forecast the policy expects.
- **Sensor model:** noise on irradiance (10 W/m² + 1 %), on air temperature (0.3 °C), on top, bottom and mean water temperature (0.2 °C) and on PCM temperature (0.5 °C); 1 % random dropout; optional blackout.
- **Observation builder:** the same 17-number state vector the controller was trained on.
- **DQN policy:** outputs CHARGE, IDLE or BYPASS each hour (the action with the largest Q-value).
- **Safety interlock:** stale sensor data forces BYPASS (fail-safe); a hard-limit breach latches a fault.
- **Plant:** linear collector with a differential controller, ten stacked water nodes (advection, conduction, stratified return, mixing), per-node PCM enthalpy model with melt fraction and wall heat capacity, per-node heat loss, and a safety shield that acts at every solver sub-step.
- **Demand and outlet:** hot water drawn from the top node at the demand profile, cold mains water entering the bottom node.

### 1.4 Algorithms and methods, and why

| Method | Why used | Alternatives considered |
|---|---|---|
| **DQN controller**, selected in Objective 3 | It is the released Rajasthan policy. On the validation years the regime 1 model keeps 98.2 % of B0's delivery with 57 % fewer shield hours (Objective 3 record) | SAC, PPO and rule-based baselines were trained in Objective 3; not re-opened here |
| **Software-in-the-loop** twin | Same code path as later processor- or hardware-in-the-loop stages | Hardware-in-the-loop (no rig) |
| **Multi-node tank + enthalpy-method PCM** | This is the model the policy was trained on; changing it would test a different system | Tamil Nadu's single-node plant (not what Rajasthan's policy saw), CFD (too slow for year-long loops) |
| **Sensor noise, dropout, stale-data interlock** | The realistic problems a deployed controller meets | Ideal sensors (too optimistic) |
| **Line-by-line port and numerical comparison with Python** | Gives a hard check that the twin equals the simulator | Visual comparison only |

### 1.5 Testing and validation (MATLAB, full year 2023)

| Check | Regime 0 | Regime 1 | Regime 2 |
|---|---|---|---|
| Plant vs Objective 3 environment, same actions: max temperature difference | 1.8e-13 °C | 3.6e-13 °C | 5.7e-13 °C |
| Shield activations (twin = Objective 3) | 115,463 | 101,899 | 227,778 |
| DQN on Objective 3's own observations | 100 % identical actions | 100 % | 100 % |
| Closed loop (sensors, observation, policy, interlock, plant) | 100 % identical actions | 100 % | 100 % |
| Delivered heat, twin = Objective 3 [kWh] | 954.983 | 897.262 | 970.320 |
| Hard-limit violations | 0 | 0 | 0 |

The remaining differences are rounding noise from the two linear solvers. The Python mirror gives the same table with differences of exactly zero.

**Added since:** the one-week Simulink check passes (100 % identical actions, 13.04 = 13.04 kWh). **Generated C:** `verify_codegen` passes for regime 1 (9 C files, 1163 lines, 100 % identical decisions over 8760 h).

### 1.6 How results were evaluated

For every scenario, the DQN and the always-charge baseline B0 run on the same weather, over an event window of 4 days (with 4 days before and 2 after). We compare:
- **heat delivered** to the user up to the 45 °C target (kWh) and unmet demand,
- **shield hours** (time spent in the guard band) and shield trip counts,
- **hard-limit violations** (must be zero),
- **lowest and highest top-node and PCM temperatures** and PCM melt fraction,
- **fail-safe hours** when sensors were lost.

### 1.7 Is Objective 4 completed for Rajasthan?

| Item | Status |
|---|---|
| Python export, regimes 0, 1, 2 | Done |
| MATLAB twin verified against Objective 3 (full year, three regimes) | Done |
| Six edge-case scenarios, three regimes: table and plots | Done, in MATLAB |
| Animations | Done for regime 1 (four 10-day videos, four shorter clips) |
| Independent Python cross-check of all of the above | Done |
| Simulink model `pcm_drl_twin_rj.slx` | Built and run for one week of regime 1: passes |
| Generated C code of the controller | Verified, regime 1: 100 % identical (MinGW64) |
| Processor-in-the-loop on a target board | Not done; future work |
| Retention test, PCM swap, simulation matrix, checks, figures, animations (plan v2) | Done for regime 1 (section 1.9) |
| Comparison with a published tank experiment | Done (Amanowicz & Turski 2025): within 1.1-1.4 K with matched capsule geometry, section 1.9 |
| Comparison with published experimental results for this design | Not possible: no rig |

### 1.8 Final output so far (with explanation)

**Output files** are in `export_r0/scenarios/`, `export_r1/scenarios/`, `export_r2/scenarios/`: one result plot per scenario, `scenario_summary.csv`, `validation_closed_loop.json`; `export_r1/scenarios/` also holds the videos. The full-year check is `export_r*/validation_report.json`.

**Regime 1 results** (event = 4 days):

| Scenario | DQN delivered [kWh] | B0 delivered [kWh] | DQN shield hours | B0 shield hours | Hard violations |
|---|---|---|---|---|---|
| Clear | 11.05 | 11.28 | 7.8 | 18.8 | 0 |
| No sunlight | 0.18 | 0.18 | 0 | 0 | 0 |
| Rain / cloud | 2.49 | 2.49 | 0 | 0 | 0 |
| Low temperature | 10.78 | 12.43 | 0 | 10.6 | 0 |
| Heat wave | 11.91 | 12.55 | 3.3 | 23.0 | 0 |
| Sensor fault | 8.42 | 8.61 | 5.6 | 14.0 | 0 |

**Regime 0 and regime 2 results** (DQN and B0 are identical because these policies always charge):

| Scenario | Regime 0 delivered [kWh] | Regime 0 shield hours | Regime 2 delivered [kWh] | Regime 2 shield hours |
|---|---|---|---|---|
| Clear | 12.11 | 15.7 | 12.29 | 20.7 |
| No sunlight | 0.24 | 0 | 0.20 | 0 |
| Rain / cloud | 2.75 | 0 | 2.61 | 0 |
| Low temperature | 12.84 | 7.8 | 13.50 | 13.1 |
| Heat wave | 13.43 | 18.9 | 13.61 | 23.8 |
| Sensor fault | 9.21 | 11.3 | 9.37 | 15.5 |

**Whole year 2023, regime 1:** DQN delivers 897.3 kWh against 912.4 kWh for B0 (98.3 %), with 430 shield hours against 994 (57 % fewer). It chooses IDLE in 356 of 8760 hours and never BYPASS.

**How to read the regime 1 table:**
- On clear and hot days the DQN delivers **95–98 % of B0's heat with 58–86 % fewer shield hours**. It reaches this by idling for 2–3 hours around solar noon.
- With **no sunlight** and in **rain** there is nothing to store, so both strategies deliver the same; the tank falls back to mains temperature with no overheating risk.
- **Low temperature is the weak case:** the DQN still idles at noon although the colder mains water removes the overheating risk, and it gives up 13 % of the delivery (10.78 vs 12.43 kWh). The mains temperature in this scenario is 8 °C below anything in training. This should be reported as a limit.
- **Heat wave:** the highest overheating risk. B0 spends 23 hours in the guard band over four days, the DQN 3.3, with zero hard violations.
- **Sensor fault:** the interlock forces BYPASS for 15 hours (12 blackout + 3 random dropouts) for both policies, then the loop recovers.

**Result plot:** each PNG has five panels: weather input (the grey band marks the edge-case period), top-node, bottom-node and PCM temperature against the 45 °C delivery line and the 72 °C / 75 °C limits, PCM melt fraction, commanded and executed action, and cumulative delivered and unmet energy.

![Clear day](export_r1/scenarios/clear.png)
![Low temperature](export_r1/scenarios/low_temperature.png)
![Heat wave](export_r1/scenarios/heat_wave.png)
![Sensor fault](export_r1/scenarios/sensor_fault.png)
![Animation frame](export_r1/scenarios/my_heat_wave_dqn_frame.png)

**Findings worth stating:**
- The PCM melts fully around midday and is fully solid again in the night, every day of 2023, in all three regimes. No latent heat carries into the next morning with the 50 L / 1.5 m² sizing.
- The top node sits at the 72 °C guard band for hundreds of hours a year under always-charge (798 h regime 0, 994 h regime 1, 1073 h regime 2). The collector is large for the tank, which is the known Objective 2 sizing limitation (33.3 L/m², below IS 12976:2023).
- Only the regime 1 controller differs from always-charge. For regimes 0 and 2 the twin confirms the released policy is B0 in practice.
- The hard limits (75 °C water / 65 °C PCM) are never reached in any scenario or in the full-year runs.

**Limits:** Simulink run for one week only; generated C verified for regime 1 only; animations for regime 1 only; emulated, not experimental; perfect 3-hour forecast; melt fraction and energy fields treated as perfect estimates; rain enters only as less sunlight and cooler air; the interlock has no debounce; 2023 is a validation year.

---

### 1.9 Improvement plan v2 (added 14 Nov 2026, regime 1, 2023)

The question added: how much heat does the tank hold, and for how long, after charging stops, with and without PCM and with and without the controller. Details, tables and file names are in `README.md` ("Improvement plan v2") and `OUTPUTS_GUIDE.md` section 8.

| Result | Number |
|---|---|
| Hold time above 45 °C, water-only / PureTemp 60 + B0 / PureTemp 60 + DQN (mean of 12 evenings, 72 h cap) | 51.9 / 61.2 / 61.0 h |
| Runs still above 45 °C at the cap | 1 / 7 / 6 of 12 |
| Window energy (18:00-09:00, 45 °C), same three arms | 452.8 / 587.2 / 572.1 kWh per year |
| Objective 2's repeatability band on this quantity | 14.4 kWh |
| Melt fraction left after 24 h / 48 h | 0.11-0.18 / 0 |
| Guard-band hours, B0 vs DQN | 994 vs 430 |
| Energy closure over 4800 h | 2.7e-12 % (limit 0.1 %) |
| Restart from a stored state | exact (0 difference) |
| Sub-step test (150 s to 75 s) | 0.080 % change: above Objective 2's 0.05 % gate; 0.041 % for 75 s to 37.5 s |
| Tank-level comparison with Amanowicz & Turski 2025, water + capsules, RMSE | 1.1-1.4 K with spheres matching the slab's surface/volume (frozen constants); 5.4-5.7 K with one sphere per capsule |
| Capsule constant c fitted on Amanowicz & Turski | 5.03 (frozen 5): null result; fitting on the one-sphere mapping gives 40 and fails Tan/Dong |
| Sub-step 0.080 % change | from the sensible-heat hours (-0.726 of -0.731 kWh), not the 2929 melting hours; water-only tank -0.66 % |

Points to say in the viva:
- **The PCM buys about 9-10 h of hold time and about 120-135 kWh a year in the evening window**, measured against a water-only tank of the same volume; both are far outside Objective 2's repeatability band. The number to quote is the difference, not the 61 h.
- **The controller does not cost retention.** DQN and always-charge hold the same (61.0 vs 61.2 h); the DQN gives up 15 kWh of window energy (about the size of the band) and cuts guard-band hours by 57 %. The plan expected a possible retention loss; it did not appear in regime 1.
- **Latent heat is spent within a day.** The capsules are 11-18 % melted after 24 h and solid after 48 h, so the hours beyond that are sensible heat. The long hold times are mostly the warm 26 °C mains water: the 30 °C criterion in Chen et al. 2025 cannot separate designs here (always at the cap).
- **Objective 1's ranking is only weakly tested.** The three PCMs differ by about 1 h in hold time. By window energy the twin agrees PureTemp 60 is best; by hold time it ranks it last. Three items, so this is a caveat, not a conclusion.
- **The earlier "capsule model too slow" finding was a geometry artefact.** The benchmark's 22 mm cuboid capsules were stood in for by one 83 mm sphere each, whose conduction path is 3.6 times too long. With spheres that keep the PCM mass and the surface/volume ratio the frozen constants (c = 5, F = 2) give RMSE 1.1-1.4 K and the printed temperature drops within 5 %. None of c, F or the film coefficient could remove the old 4.5-4.9 K bias; c fitted on the original mapping runs away to 40 and wrecks Tan 2009 and Dong 2022. Fitted on the matched mapping, c = 5.03: a null calibration. Tank loss: only that coefficient was fitted (water-only case).
- **Single-capsule experiments still show the frozen model slower** (Tan 2009: 25 % melt at 71 against 40 min; Dong 2022: half melt at 78 against about 58 min), and the two disagree on how much to change c (about 10 against about 6). A campaign at c = 7.1 (bound, not a held-out result) gives hold times 0.4-1.7 h longer and window energy -12 to +2 kWh, with more guard-band hours: so the frozen hold times are, if anything, slightly short. Both campaigns are kept next to the default.
- **Sub-step gate not met, and why.** 0.080 % for 150 to 75 s (gate 0.05 %, not relaxed): the melting hours contribute -0.005 of -0.731 kWh because melting hours already sub-step at 25 s; the sensible-heat hours carry it, and the water-only tank is worse (-0.66 %). Report it as a measured limitation of the implicit-Euler tank model at 150 s.
- **Dead pyranometer (reads 0 W/m2, real sun unchanged):** the DQN is not safer or more efficient for it: it idles 228 h instead of 356, delivers 908.85 instead of 897.3 kWh and spends 701 guard-band hours instead of 430 (B0: 994, no hard-limit hours). The interlock does not trigger on it, because it has no irradiance plausibility rule; a plausibility check (reading 0 at noon with a clear forecast) is the obvious addition for a real device. 20 seeds on the 10-day window agree (11.31 ± 0.02 shield hours against 7.72 ± 0.13).
- **Handoff and parameter check:** the export re-run is byte-identical in all three regimes; the twin's tank volume, collector area, PCM mass and flow equal the Objective 2 design (50 L, 1.5 m2, 13.3826 kg, 0.0492621 kg/s). 33.3 L/m2 stays a stated limitation against IS 12976:2023.
- **Ranking:** the three PCMs differ by about 1 h in hold time; the twin ranks PureTemp 60 last on hold time but first on window energy (25 kWh ahead); three items are too few to support a ranking claim, and the order moves with the capsule constant.
- **Retention figures from the literature are not ours.** Chen et al. 2025: 17.1 / 29.6 / 31.7 h above 30 °C on a 30 L/day RT35HC system with no controller. The "12 h without PCM" and "24-48 h with PCM plus AI" figures have no source in Chen or Singh. This folder: 51.9 h water-only and 61.0-62.4 h with PCM at 45 °C on 300 L/day, and the 30 °C column is at the cap everywhere.
- **Objective 1 numbers:** the Monte-Carlo percentages in Objective 2's config and Objective 1 copy are 99.3 / 93.6 / 56.1; the plan's table (95.6 / 93.7 / 55.8) is from the later Objective 1 repository file (28 Oct 2026). Ranks and the cluster 1 shortlist are identical. The O2 `manifest.json` entry for that file is stale (935 bytes listed, 10 322 on disk).
- **Three Rajasthan regimes** give similar gains (+129 to +140 kWh window, +8.3 to +9.8 h); this is not a three-state comparison, which needs the other twins' results.
- **Two things found on the way:** a water-only tank latched a false hard-limit fault because the interlock compared its mean water temperature with the 65 °C PCM limit (fixed for that arm only); and the pump was drawn running whenever CHARGE was commanded, even without collector gain (fixed in the animation).
- **Also done in the follow-up:** supercooling proxy (freezing point 2 K lower: hold time changes by under 1 h, 50 °C hold +0.5 to +1.0 h), pump energy from Objective 2's Ergun head (0.005 Wh per year, a lower bound). **Not done:** a cross-state F5 (needs the other two twins), option C1 (needs the Partial Differential Equation Toolbox, not installed), a pyranometer stuck at a non-zero value.

## 2. Why MATLAB?

- **Simulink reproduces the signal chain of a real installation** (weather, sensors, controller, interlock, pump, plant) as blocks with sample times.
- **It is an independent environment.** Running the controller outside the Python training code is the point of a software-in-the-loop check.
- **It is the route to embedded code.** The same controller function can be compiled to C with MATLAB Coder and later used for processor-in-the-loop.
- **One tool covers modelling, testing, plots and animation**, and the Tamil Nadu twin already uses it, so the two states are reported the same way.

**What is needed to run it:** MATLAB (run here with R2026b). Simulink and Stateflow are needed only for the `.slx` model; MATLAB Coder only for the C code. `run_scenarios`, `validate_against_python`, `make_my_video`, `run_campaign`, `check_energy_balance`, `benchmark_amanowicz` and `plot_pack` need base MATLAB only. `build_campaign_config.py` needs PyYAML (in the project environment).

---

## 3. Libraries, Implementation and Output

| Product | Purpose |
|---|---|
| **MATLAB (base)** | Plant physics, policy, sensor model, interlock, scenarios, plotting, MP4 animation |
| **Simulink + Stateflow** | The block-diagram twin (`pcm_drl_twin_rj.slx`) built from MATLAB Function blocks (built and run once) |
| **MATLAB Coder** | C code of `controller_step` (policy + interlock); not run in this pass |
| **Not installed, not needed** | Statistics and Parallel Computing toolboxes: Spearman correlation and the 95 % confidence intervals are computed by hand, the campaign runs serially |
| **Python (NumPy, numba, PyTorch, Stable-Baselines3)** | One-time export and reference run (`export_from_python.py`); the mirror check (`sil_python_mirror.py`) needs only NumPy, numba and matplotlib |

**What the work demonstrates so far:** the trained controller can be rebuilt from exported numbers alone and then makes the same decision as in Objective 3 in every hour of a year; it stays inside the safety limits under no sun, rain, cold, heat and sensor failure; the fail-safe logic works; and for regime 1 it trades about 2 % of yearly delivery for 57 % fewer hours in the guard band.

**What has not been verified:** the C code generation (not run), Simulink beyond one week, and behaviour on real hardware.

---

## How to reproduce

```bash
python export_from_python.py --regime 1        # also --regime 0, --regime 2
python sil_python_mirror.py --regime 1         # validation + scenarios without MATLAB
```
```matlab
cd Rajasthan/matlab
regime = 1; doAnim = false; run_scenarios      % six scenarios, plots, table
validate_against_python(1)                     % full-year check
regime = 1; doAnim = true;  run_scenarios      % with animations
check_energy_balance(1); benchmark_amanowicz   % plan v2 checks and benchmark
run_campaign; plot_pack                        % plan v2 matrix and figures (after python build_campaign_config.py --regime 1)
diagnose_capsule; calibrate_capsule; diagnose_substep(1)   % capsule diagnosis, calibration, sub-step attribution
```
