# Objective 4 (Uttarakhand, 50 L, PPO + smart forecast, regime 1): audit summary

Compiled 15 Nov 2026 from the files in `export_r1/`, `results_campaign/`, `video/` and `matlab/`. Every number is copied
from those files; every run was done in MATLAB R2026b on this machine. Method: the joint plan `docs/plan_O4.md`
(Tamil Nadu and Rajasthan), applied to Uttarakhand with the Rajasthan scripts as the reference (same 10-node Objective 2
kernel family).

## Requirements against what exists

| Plan item | Status | Where |
|---|---|---|
| Replay year 2023 (O3 validation year) | Done for all three regimes | `export*/reference_2023.csv`, `weather_2023.csv` |
| 1 Validation pass | **PASS, regimes 0, 1, 2** (open loop, policy only, forecast, closed loop, 8760 h) | A |
| 2 Three-arm table, same metrics | Done | A |
| 3 One-day cycle plot with explanation | Done | B |
| 4 Edge-case table (6 + dead / stuck pyranometer), all three arms | Done (9 scenarios) | C |
| 5 Hold-time table at 30/40/45/50 C, read at 24/36/48 h | Done | D |
| Checks: restart 0, closure, PCM swap, zero input, exponential cool-down, sub-step gate | All PASS except the sub-step gate (reported, not relaxed) | D |
| 6 PCM swap (O1 top-3) x flow 0.7/1.0/1.3, B0 and PPO | Done, all three PCMs at all three flows | E |
| 7 Benchmark (Amanowicz & Turski 2025) | Done, diagnosed, no recalibration | G_H |
| 20-seed sensor-fault confidence intervals | Done | G_H |
| 8 Cross-state table and figure | Done with the files on disk (Tamil Nadu's three-arm table is still its 2021 run) | I |
| 9 One-day video with the pump fix | Done | F |
| 10 README, limitations | Done | `../README.md`, I |
| Simulink week, generated C (plan: "not needed") | Not re-run for the smart-forecast agent; the earlier runs were for the frozen V1 policy | I |

## Headline (2023, regime 1, 50 L / 1.5 m2, PureTemp 58, 12.45 kg PCM)

| Arm | Delivered to 50 C [kWh] | Window 18-09 h [kWh] | Shield hours | Hold at 45 C, mean of 12 | Hold at 50 C |
|---|---|---|---|---|---|
| 1 plain tank + B0 | 1102.3 | 538.4 | 286.6 | 23.3 h | 14.5 h |
| 2 PCM + B0 (no AI) | 1184.4 | 607.3 | 571.1 | 32.6 h | 23.9 h |
| 3 PCM + PPO | 1142.4 | 565.3 | 1.1 | 26.0 h | 17.2 h |

Zero hours over a hard limit (75 C water / 65 C PCM) in every arm, scenario and check.

**Is arm 3 better than arms 1 and 2?**
- Against the plain tank: yes, +40.1 kWh/yr delivered to 50 C (+26.9 kWh in the evening window) and +2.7 h hold at 45 C.
- Against PCM + B0: **no on energy and hold**. The PPO delivers 42.0 kWh/yr (3.5 %) less and holds 6.6 h less at
  45 C, because it bypasses the collector before the tank reaches the shield and so stores less at 18:00. **Yes on
  shield operation**: 1.1 shield hours instead of 571 (-99.8 %).
- Honest claim: the PCM gives the energy and retention gain; the PPO keeps most of the energy gain (about half of the
  PCM's delivery gain over the plain tank) while almost never running into the shield. It does not improve retention.

## Problems found and what was done

1. **Mains temperature is out of distribution for the policy (C).** The normalisation has std(T_mains) about 0.001 C.
   With mains 8 C colder the regime 1 PPO commands ENABLE every hour (acts as B0: 0 bypass hours); the regime 0 and 2
   PPOs bypass for the whole run (0.07 / 0.02 kWh against 16.45 / 16.94 kWh for B0, `export*/scenarios/`). The
   `low_temp_mains_masked` diagnostic shows that feeding the training mains value restores normal behaviour in all
   three regimes. Recommendation unchanged: freeze the mains input at its training value or retrain with varying mains.
2. **Pyranometer faults (C, G_H).** The interlock has no irradiance plausibility rule, so none of the three faults
   triggers the fail-safe. Because the smart forecast is built from the same pyranometer, a fault corrupts the forecast
   too. Full year: dead sensor -> the PPO behaves almost like B0 (+36.6 kWh, 535.7 shield hours instead of 1.1); stuck
   at 1000 W/m2 -> 3391 bypass hours, -63.5 kWh/yr (-5.6 %). No hard-limit hours in any case.
3. **Sub-step gate (D): NOT MET, stated.** Halving the 150 s step changes annual delivery by -0.059 % (gate 0.05 %);
   77 % of the change comes from the sensible-heat hours, not the melting hours. Same finding as Rajasthan (0.080 %).
4. **Pump drawing (F): FIXED.** The old drawing rule shows the pump running in 222-223 h a year per arm in which the loop
   did not circulate or the collector added no heat; the new rule has 0 violations.
5. **Water-only arm false fault: avoided.** The interlock's PCM-side limits are switched off for the water-only tank only
   (`load_campaign.m`), the fault Rajasthan found; the kernel applies those limits to capsule nodes only.
6. **PCM ranking (E): STATED.** Three PCMs cannot support a ranking claim (Spearman can only be +-0.5 or +-1).
   PureTemp 58 (O2's choice, O1 rank 1) is first with B0 on every metric; n-Octacosane (C28) is clearly last
   (-54 kWh window energy, -4.7 h hold at 45 C).
7. **Benchmark (G):** one-sphere capsule mappings are 4.5-7.9 K too warm; the surface/volume-matched mapping gives
   1.1-1.4 K RMSE with the frozen constants (Rajasthan: 1.1-1.4 K). Not recalibrated.
8. **Replay year:** 2023 is an O3 validation year, and the PPO seed was chosen on the validation rows: these are
   fidelity numbers, not an unbiased performance figure.

## Not done

- Simulink week and generated C for the smart-forecast agent (the plan says not needed; earlier runs exist for the
  frozen V1 policy, 2010).
- Supercooling sensitivity (O1 lists supercooling -0.1 to -0.7 K for the three PCMs, i.e. none to model).
- A 2023 three-arm table for Tamil Nadu (the cross-state table uses its 2021 run and says so).
