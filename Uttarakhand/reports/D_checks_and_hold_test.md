# D. Checks and hold test

## Checks (`check_energy_balance(1)` -> `results_campaign/energy_balance_report_r1.json`, `export_r1/restart_check.json`)

| Check (plan 2.4) | Result | Status |
|---|---|---|
| Restart A: replay 400 h from a stored hourly state | max dT 0, max dh 0 | PASS (difference exactly 0) |
| Restart B: `run_hold_test` from a stored state vs an independent full run (sun off, no draw, 72 h) | dT_top 0, dT nodes 0, dE 0 | PASS (exactly 0) |
| Energy closure, 4800 h, B0 | 1.3e-12 % of collector heat (limit 0.1 %) | PASS |
| Energy closure, 4800 h, PPO | 1.6e-12 % | PASS |
| PCM swap: `swap_pcm.m` (O2's rules re-derived) vs O2's own vectors, three PCMs | max relative difference 2.8e-17; band holds L + wall heat exactly; melt fraction round-trips | PASS |
| Plain-tank cool-down (uniform loss, 60 C in 20 C air) | time constant 92.1 h; 1.4e-11 K from the implicit-Euler solution, 3.2e-3 K from exp(-t/tau); real loss vector 0.09 K | PASS |
| Zero input (no sun, no draw, ambient = tank) | max drift 1.9e-12 C | PASS |
| Sub-step gate: 150 s -> 75 s, annual delivery | **-0.059 % (-0.699 kWh); gate 0.05 %** | **NOT MET, not relaxed** |

Sub-step attribution (B0, full year):

| Tank, step | Annual change | From melting hours | From sensible-heat hours |
|---|---|---|---|
| PCM, 150 -> 75 s | -0.059 % (-0.699 kWh) | 2235 h: -0.159 kWh | 6525 h: -0.540 kWh |
| PCM, 75 -> 37.5 s | -0.027 % (-0.324 kWh) | -0.057 kWh | -0.267 kWh |
| Water only, 150 -> 75 s | -0.409 % (-4.51 kWh) | none | -4.51 kWh |
| Water only, 75 -> 37.5 s | -0.219 % (-2.41 kWh) | none | -2.41 kWh |

First-order convergence (halving the step halves the change). 77 % of the PCM tank's change comes from hours without
phase change, and the water-only tank, which has no PCM, shows a larger change: the error belongs to the implicit-Euler /
upwind treatment of the tank water at 150 s, not to the melting model (inside the melt band the kernel already
sub-steps). 0.7 kWh is 1.7 % of the PPO-B0 difference and 0.9 % of the PCM gain, so no conclusion changes; the gate is
reported as not met for this tank and year. Same finding as Rajasthan (0.080 %).

## Hold test (`hold_test.m` -> `export_r1/hold_test.csv`, `hold_test_thresholds.csv`, `hold_test_summary.csv`, `hold_test.png`)

Start at the end of the 17:00 local hour (18:00) on days round(linspace(15, 345, 12)) of 2023 from each arm's own
node state in its full-year run; then sun off, no draw, real ambient, 72 h cap. Read at the **top layer**.
Censored = still above the threshold at 72 h (counted at 72 h in the mean).

| Arm | 30 C | 40 C | 45 C | 50 C |
|---|---|---|---|---|
| Plain + B0 | 60.1 h (8 cens.) | 36.3 h | 23.3 h | 14.5 h |
| PCM + B0 | 57.0 h (8 cens.) | 42.2 h (3) | 32.6 h | 23.9 h |
| PCM + PPO | 57.0 h (7 cens.) | 38.3 h (1) | 26.0 h | 17.2 h |

Means at 24 / 36 / 48 h (top-layer temperature) and the state at the start:

| Arm | T_top at 18:00 | Melt fraction at 18:00 | T at 24 h | T at 36 h | T at 48 h | Melt at 24 h |
|---|---|---|---|---|---|---|
| Plain + B0 | 59.0 C | - | 43.9 C | 39.0 C | 36.2 C | - |
| PCM + B0 | 52.9 C | 0.38 | 46.1 C | 42.0 C | 38.7 C | 0.04 |
| PCM + PPO | 50.9 C | 0.25 | 44.5 C | 39.5 C | 36.5 C | 0.00 |

- The PCM gain over the plain tank is **+9.3 h at 45 C and +9.4 h at 50 C** (B0); +2.7 / +2.6 h with the PPO.
- The PPO holds 6.6 h less than B0 at 45 C: it starts the night with less melted PCM (0.25 against 0.38) and a cooler
  top layer, because it bypassed at midday. **The controller does not improve retention.**
- At 30 C the PCM tanks hold slightly less than the plain tank (57.0 against 60.1 h): the plain tank starts hotter
  (59.0 against 52.9 C) and has 15 kg more water. The 30 C criterion is mostly censored and cannot rank designs.
- The latent heat is spent within the first day (melt fraction 0.04 or less after 24 h, 0 after 48 h); the later hours
  are sensible heat of the water.
- Retention in Uttarakhand is much shorter than in Rajasthan (61 h at 45 C) because the nights and winter are colder
  (real ambient) and the start temperature is lower. Measured values only; the literature figures (12 h, 24-36 h, 24-48 h)
  are not this project's measurements.
