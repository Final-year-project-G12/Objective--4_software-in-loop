# Prompt D: restart check, energy balance, hold test

Sources: `export_r1/restart_check.json`, `energy_balance_report.json`, `hold_test.csv`, `hold_test_thresholds.csv` (written by `matlab/check_energy_balance.m`, `export_summary_files.m` and `hold_test.m`; the same results are in `results_campaign/`). Replay year 2023.

## Checks (`check_energy_balance(1)`)

| Check | Result | Threshold |
|---|---|---|
| Restart A: replay from a stored hourly state, same inputs | difference 0 (exact) | 1e-9 °C |
| Restart B: `run_hold_test` against an independent full run (whole node temperature and enthalpy vectors) | difference 0 (exact) | 1e-9 °C |
| Energy closure, 4800 h, always-charge and DQN | 2.7e-12 % and 2.5e-12 % of collector heat; worst hour 5.7e-11 Wh | 0.1 % |
| PCM swap and latent-heat accounting | swap of PureTemp 60 reproduces the Objective 2 vector to 2.8e-14; melt-fraction round trip exact for all three PCMs | 1e-9 |
| Plain-tank cool-down is the exponential | 1.4e-11 K from the implicit-Euler solution, 3.2e-3 K from exp(-t/tau), tau 92.1 h | 0.02 K |
| Zero input (no sun, no draw, ambient = tank) | drift 4.7e-13 °C | 1e-9 °C |
| **Sub-step independence (150 s to 75 s)** | **0.0801 % change: NOT met** (75 s to 37.5 s: 0.0408 %) | 0.05 % |

**The sub-step gate is not met and is not relaxed.** `diagnose_substep.m` (`results_campaign/substep_attribution_r1.json`) shows where it comes from: the 2929 melting hours contribute -0.005 kWh of the -0.731 kWh; the other 5831 hours (sensible heat only) contribute -0.726 kWh, because inside the melt band the plant already sub-steps at 25 s. The water-only tank has no phase change and changes by 0.66 %, so the error belongs to the implicit-Euler / upwind treatment of the tank water at 150 s across the year. 0.73 kWh is about 5 % of Objective 2's 14.4 kWh repeatability band. Energy closure itself is exact (1e-12 %), so the open item is a discretisation error, not a missing term (unlike the single-node Tamil Nadu twin's 0.263 % closure, which is inflated by dividing by a small net change).

## Hold test (72 h cap, 12 start days, 18:00 local start)

After charging stops at 18:00: no sun, no draw, real ambient. Start days `round(linspace(15, 345, 12))`, state taken from each arm's own full-year run. Hours until the top layer falls below each threshold, mean of 12 (`*` = at least one run still above it at the 72 h cap):

| Arm | 30 °C | 40 °C | 45 °C | 50 °C | Censored at 45 °C |
|---|---|---|---|---|---|
| 1 plain tank + B0 | 72.0* | 64.2* | 51.9* | 35.2 | 1 of 12 |
| 2 PCM + B0 | 72.0* | 67.0* | 61.2* | 53.4* | 7 of 12 |
| 3 PCM + DQN | 72.0* | 67.0* | 61.0* | 50.9 | 6 of 12 |

Measured values, **not the literature figures** (12 h, 24-36 h, 24-48 h). Chen et al. 2025 report 31.7 h above 30 °C on a 30 L/day RT35HC system with no controller; at 30 °C this twin is capped at 72 h in every run, because the mains water is 26 °C and the tank can never fall below it, so that criterion cannot separate designs here.

- **PCM gain over the plain tank:** +9.3 h (B0) and +9.1 h (DQN) at 45 °C, +18 and +16 h at 50 °C. Quote the difference, not the absolute number; a mean near 72 h means the test ran out.
- **The DQN does not cost retention:** 61.0 against 61.2 h at 45 °C. (It costs 15 kWh of delivered energy over the year; see report A.)
- **The latent heat is spent within a day:** melt fraction 0.11-0.14 after 24 h and 0 after 48 h in every arm. The long holds are mostly warm mains water (26 °C) and a small tank.
- **Capsules without latent heat make things worse** (Objective 2's `pcm_L0` control: 33.6 h against 50.4 h plain and 59.4 h with PCM, regime 1, mean 2021-2023): the capsules displace about 15 L of water, so latent heat has to pay for the water it displaces.
- Hold times are model values. The capsule model matches a tank-level benchmark to 1.1-1.4 K once the capsule geometry is mapped correctly (report G_H); a faster-capsule bound lengthens the 45 °C hold by 0.4-1.7 h, so the frozen values are slightly short, not optimistic.
