# Prompt C: edge cases

Source: `export/scenarios_3arm/scenario_summary_3arm.csv`, `edge_cases_grid.png`, `pyranometer_faults.png`. Each scenario is a 10-day window, all three arms. **Replay year 2011**, a locked Objective 3 test year, so treat these as exploratory (`run_c_scenarios` default).

| Scenario | Arm | Delivered kWh | Unmet kWh | Shield trips | Peak PCM C |
|---|---|---|---|---|---|
| clear | 1 plain | 22.9 | 6.1 | 363 | n/a |
| clear | 2 PCM+B0 | 25.5 | 3.3 | 956 | 63.5 |
| clear | 3 PCM+SAC | 25.4 | 3.3 | 403 | 62.7 |
| no sunlight (4 days) | 1 | 0.8 | 22.3 | 0 | n/a |
| no sunlight | 2 | 1.1 | 22.0 | 0 | 63.1 |
| no sunlight | 3 | 1.1 | 22.0 | 0 | 62.7 |
| rain / cloud | 1 | 4.7 | 18.4 | 0 | n/a |
| rain / cloud | 2 | 4.7 | 18.3 | 0 | 63.1 |
| rain / cloud | 3 | 4.7 | 18.3 | 0 | 62.7 |
| low temperature | 1 | 25.4 | 13.1 | 204 | n/a |
| low temperature | 2 | 27.6 | 10.4 | 445 | 63.4 |
| low temperature | 3 | 26.7 | 10.8 | 215 | 63.3 |
| heat wave | 1 | 25.0 | 5.1 | 436 | n/a |
| heat wave | 2 | 27.5 | 2.4 | 1217 | 63.4 |
| heat wave | 3 | 27.2 | 2.4 | 629 | 62.9 |
| sensor fault (12 h blackout) | 1 | 17.7 | 9.9 | 273 | n/a |
| sensor fault | 2 | 19.1 | 8.0 | 669 | 63.4 |
| sensor fault | 3 | 19.4 | 7.8 | 282 | 62.9 |

Hard-limit violations: **0 in every row.**

## How the PCM reacts

- **Clear, heat wave:** the PCM melts fully every day (melt 0 to 1) and stores up to about 5.7 kWh, which is released in the evening. Arm 3 trips the shield about half as often as arm 2.
- **No sunlight:** the PCM never melts for four days, the tank cools to about 29 C and stored energy falls to about 0. All arms deliver about 1 kWh, so no arm can help when there is no sun, and the PCM only recovers when the sun returns.
- **Rain / cloud:** only small partial charging (PCM peaks about 40 C, no melt), stored energy stays near 1 kWh.
- **Low temperature:** PCM still melts on sunny days. Arm 2 (B0) delivers a little more than arm 3 (+0.8 kWh).
- **Sensor fault (blackout):** arm 3 delivers the most here (19.4 against 19.1) with a third of arm 2's shield trips.

## Observations

- Arms 2 and 3 are almost identical on energy in edge cases. SAC's clear advantage is fewer shield trips, consistent with the annual result.
- In the "plain tank" rows, the PCM peak of 52 C is a placeholder, not a real PCM temperature.
- **Stuck pyranometer:** in `scenario_summary_3arm.csv` the `ghi_stuck` row is identical to `ghi_dropout` (49.0 kWh, 116 shields), because the sensor froze at its first reading, which is 0 at midnight. The 20-seed run (report H) separates them. Do not present the single-run "stuck" as a different test.

## Dead pyranometer (arm 3, 10 days)

49.0 kWh delivered against 62.9 kWh with a healthy sensor (-22 %), shields 116 against 915, zero hard violations. The controller stays safe because the shield acts on the true tank state.
