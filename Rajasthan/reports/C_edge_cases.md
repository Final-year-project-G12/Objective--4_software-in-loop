# Prompt C: edge cases for the three arms, plus dead and stuck pyranometer

Source: `export_r1/scenarios_3arm/scenario_summary_3arm.csv`, `edge_cases_grid.png`, `pyranometer_faults.png` and one 5-panel PNG per scenario (made by `matlab/run_c_scenarios.m`; scenario definitions in `matlab/edge_scenarios.m`). Each scenario is the 10-day April 2023 window of `run_scenarios.m` (4 days spin-up, 4 days event, 2 days recovery). **Replay year 2023**, an Objective 3 validation year (not a locked test year). The six original scenarios, DQN and B0 columns, equal the original `export_r1/scenarios/scenario_summary.csv` (unchanged); the plain-tank arm is new.

| Scenario | Arm | Delivered kWh | Unmet kWh | Shield trips | Shield h | Peak PCM °C | Max melt |
|---|---|---|---|---|---|---|---|
| clear | 1 plain | 9.20 | 17.36 | 337 | 14.0 | n/a | n/a |
| clear | 2 PCM + B0 | 11.28 | 15.27 | 6121 | 18.8 | 62.3 | 1.00 |
| clear | 3 PCM + DQN | 11.05 | 15.51 | 2020 | 7.8 | 62.1 | 0.97 |
| no sunlight (4 days) | 1 / 2 / 3 | 0.18 / 0.18 / 0.18 | 26.43 | 0 | 0 | | 0 |
| rain / cloud | 1 plain | 2.65 | 24.04 | 0 | 0 | n/a | n/a |
| rain / cloud | 2 / 3 | 2.49 / 2.49 | 24.21 | 0 | 0 | 62.2 / 62.1 | 0 |
| low temperature | 1 plain | 10.88 | 26.89 | 175 | 7.3 | n/a | n/a |
| low temperature | 2 PCM + B0 | 12.43 | 25.34 | 2772 | 10.6 | 62.3 | 0.97 |
| low temperature | 3 PCM + DQN | 10.78 | 27.00 | 0 | 0 | 61.0 | 0.40 |
| heat wave | 1 plain | 10.41 | 16.13 | 412 | 17.2 | n/a | n/a |
| heat wave | 2 PCM + B0 | 12.55 | 13.98 | 6647 | 23.0 | 62.3 | 1.00 |
| heat wave | 3 PCM + DQN | 11.91 | 14.62 | 481 | 3.3 | 62.1 | 0.86 |
| sensor fault (12 h blackout) | 1 plain | 7.06 | 19.51 | 251 | 10.5 | n/a | n/a |
| sensor fault | 2 PCM + B0 | 8.61 | 17.95 | 4537 | 14.0 | 62.3 | 0.97 |
| sensor fault | 3 PCM + DQN | 8.42 | 18.14 | 1374 | 5.6 | 62.2 | 0.97 |
| dead pyranometer (reads 0) | 1 / 2 | 9.20 / 11.28 | 17.36 / 15.27 | 337 / 6121 | 14.0 / 18.8 | | |
| dead pyranometer | 3 PCM + DQN | 11.18 | 15.37 | 3679 | 11.3 | 62.2 | 1.00 |
| stuck at 500 and at 1000 W/m² | 1 / 2 / 3 | 9.20 / 11.28 / 11.05 | 17.36 / 15.27 / 15.51 | 337 / 6121 / 2020 | 14.0 / 18.8 / 7.8 | | |

"Shield trips" count per sub-step (and per node on the PCM side) in this 10-node kernel; use shield hours to compare arms. The plain tank has no PCM: its peak-PCM and melt cells are n/a. Hard-limit violations: **0 in every row.** Fail-safe (interlock) hours: 15 in all three arms of the sensor-fault scenario (12 blackout + 3 random dropouts), 0 elsewhere.

## How the PCM reacts

- **Clear, heat wave:** the PCM melts fully every day (melt 0 to 1) and stores up to 2.8-2.95 kWh above mains (plain tank 2.65 kWh), released in the evening. The DQN keeps the guard-band hours low: 7.8 h (clear) and 3.3 h (heat wave) against 18.8 and 23.0 for B0, for 2 % and 5 % less delivered energy.
- **No sunlight:** the PCM never melts (melt 0 for four days), the tanks cool to mains temperature and stored energy falls to about 0.03 kWh. All three arms deliver 0.18 kWh: no arm can help without sun.
- **Rain / cloud:** only partial charging, no melt. The plain tank delivers 0.16 kWh *more* than the PCM tanks, because the capsules displace water and the PCM tank has less sensible capacity when nothing melts. The latent heat has to pay for the water it displaces before it shows any profit.
- **Low temperature (mains water -8 °C, a weak case for the DQN):** the PCM melts on sunny days in arm 2 (melt 0.97) but only to 0.40 in arm 3. The DQN idles at noon although the colder mains water removes the overheating risk, so it delivers 12.9 % less than B0 (10.78 against 12.43 kWh), with zero shield trips, and even a little less than the plain tank (10.88). This condition is outside its training range.
- **Sensor fault (12 h blackout):** every arm goes to fail-safe BYPASS during the blackout and collects almost nothing even in strong sun; this is the interlock's behaviour and is why this scenario delivers least. The DQN keeps the lowest shield hours (5.6 against 14.0 for B0).

## Dead and stuck pyranometer

Definition (not in the plan; header of `edge_scenarios.m`): the controller's irradiance reading is 0 (dead), 500 or 1000 W/m² (stuck) for the whole run while the real sun drives the plant, on the clear April window. The 1-3 h forecast fields are weather-feed values and are unaffected. B0 and the plain tank ignore the observation, so they are unchanged.

- **Dead (reads 0):** the DQN delivers 11.18 kWh against 11.05 healthy and spends 11.3 shield hours against 7.8: it behaves a little more like B0. The interlock never triggers.
- **Stuck at 500 or 1000 W/m²:** no measurable effect on the DQN in this window (11.05 kWh, 2020 trips, identical to the healthy run): the policy does not rely on the irradiance field when the real sun is high and the forecast is intact.
- **Year-long dead sensor and 20 seeds** (`results_campaign/dead_pyranometer_year.csv`, `dead_pyranometer_seeds.csv`): DQN 908.85 against 897.3 kWh and 701 against 430 guard-band hours; 20 seeds give 11.16 ± 0.02 kWh and 11.31 ± 0.02 shield hours against 11.03 and 7.72 healthy. The fail-safe never triggers: `safety_interlock.m` has no irradiance plausibility rule.
- Unlike the Tamil Nadu twin (where "stuck" froze at the first reading, 0 at midnight, and equalled the dropout case), stuck here is a constant non-zero value, so it differs from the dead case.

## Observations

- Arms 2 and 3 are close on energy in most edge cases; the DQN's clear advantage is fewer shield hours, consistent with the annual result. Low temperature is the exception (the DQN loses 1.65 kWh).
- PCM + B0 beats the plain tank on clear, low-temperature, heat-wave and sensor-fault days by 1.5 to 2.1 kWh; PCM + DQN does too, except at low temperature (-0.1 kWh). Neither helps on no-sun and rain days.
