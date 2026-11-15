# C. Edge cases, three arms (`edge_scenarios.m`, `run_c_scenarios.m` -> `export_r1/scenarios_3arm/`)

Window 1-10 April 2023: 4 days spin-up, event days 5-8, 2 days recovery; numbers are for the 4 event days, delivered to
50 C. Nine scenarios: the six of the original study plus a dead pyranometer (reads 0) and a pyranometer stuck at 500 and
at 1000 W/m2 (the real sun still drives the plant). A stuck sensor is a constant for the whole run (as Rajasthan; the
Tamil Nadu twin froze its first reading, which equals the dead case at midnight). Because the smart forecast is computed
from the same pyranometer, a pyranometer fault also corrupts the forecast.

| Scenario | Plain + B0 | PCM + B0 | PCM + PPO | Shield h (plain / B0 / PPO) | PPO bypass h | Fail-safe h |
|---|---|---|---|---|---|---|
| Clear | 14.71 | 16.72 | 15.09 | 11.9 / 20.1 / 0.0 | 20 | 0 |
| No sunlight | 0.15 | 0.15 | 0.15 | 0 / 0 / 0 | 8 | 0 |
| Rain / cloud | 2.91 | 2.76 | 2.76 | 0 / 0 / 0 | 10 | 0 |
| Low temperature (ambient -12 C, mains -8 C) | 15.85 | 17.34 | 17.34 | 3.8 / 10.4 / 10.4 | **0** | 0 |
| Heat wave | 16.44 | 18.51 | 17.60 | 16.0 / 25.2 / 0.9 | 17 | 0 |
| Sensor fault (noise + 12 h blackout) | 14.71 | 16.72 | 15.79 | 11.9 / 20.1 / 5.3 | 16 | 15 |
| Dead pyranometer | 14.71 | 16.72 | 16.46 | 11.9 / 20.1 / 18.0 | 12 | 0 |
| Stuck at 500 W/m2 | 14.71 | 16.72 | 15.85 | 11.9 / 20.1 / 1.7 | 40 | 0 |
| Stuck at 1000 W/m2 | 14.71 | 16.72 | 14.82 | 11.9 / 20.1 / 0.0 | 44 | 0 |

Hours over a hard limit: 0 in every scenario and arm.

How the PCM stores and releases heat:
- **Clear / heat wave.** PCM + B0 melts fully every day (f = 1.00) and freezes again by the end of each evening (melt
  fraction 0.00 at the end of the event). The PPO melts it to 0.61 (clear) / 0.89 (heat wave) at most, bypassing
  before the shield; it delivers 1.6 / 0.9 kWh less over the 4 days with 20 / 24 fewer shield hours.
- **No sunlight / rain.** Nothing is stored: the PCM never melts (f max 0.00) and the tank sits near mains temperature.
  With no stored heat to carry over, the three arms deliver the same 0.15 kWh. In rain the plain tank delivers 0.15 kWh
  more than the PCM tank: with weak sun its extra water warms past 50 C sooner than the PCM tank's top layer.
- **Low temperature.** The PCM still melts fully (f max 1.00); the PCM arms deliver 1.5 kWh more than the plain tank.
  **The PPO behaves exactly as B0 (0 bypass hours).** Its T_mains input is 8 C below the training value, thousands of
  standard deviations out of range (std 0.0015 C); see the `low_temp_mains_masked` diagnostic in
  `export_r1/scenarios/` and `../README.md`.
- **Sensor fault.** The 12 h blackout plus random dropouts trigger the fail-safe for 15 h (B0 = always enable under the
  shield); delivery stays between B0 and the healthy PPO. 20-seed intervals in G_H.
- **Pyranometer faults.** No fail-safe hour in any case: the interlock has no irradiance plausibility rule. Dead (reads 0):
  the forecast is 0 too, the PPO mostly enables and behaves almost like B0 (16.46 kWh, 18.0 shield hours). Stuck at
  500 / 1000: the PPO thinks it is always sunny and bypasses 40 / 44 hours, delivering 0.9 / 1.9 kWh less than B0.

Files: `scenario_summary_3arm.csv` (one row per scenario and arm, with stored energy and melt-fraction columns),
`<scenario>.png` (5 panels, three arms; the top panel also shows what the pyranometer reads), `edge_cases_grid.png`,
`pyranometer_faults.png`. The single-arm study per regime (`export*/scenarios/`, PPO vs B0, 2023, with the mains-masked diagnostic) was
regenerated with the same controller and year.
