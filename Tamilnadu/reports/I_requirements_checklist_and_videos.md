# Requirements checklist and video index

## Checklist against your requirements

| Your item | Done? | Where |
|---|---|---|
| 1) Plain tank without PCM and why it behaves so | Yes: arm 1 numbers, plots, hold time | `A_validation_and_three_arm.md`, `B_one_day_plots.md`, `D_checks_and_hold_test.md` |
| 2) Selected PCM, no AI | Yes: arm 2 (PCM + B0) | same |
| 3) O1 + O2 + O3 combined (SAC) | Yes: arm 3 (PCM + SAC, frozen r0_smartfc) | same |
| i) One-cycle charge / idle / bypass graph with PCM temperature, water temperature and other parameters | Yes: `export/one_day_cycle_2021.png` and `.csv` (day 71) | `B_one_day_plots.md` |
| i) Slow single-cycle videos | Yes, 7 videos made (see below); 5 more left to capture | this file |
| ii) Edge cases and how the PCM stores heat for arms 1, 2, 3 | Yes: plots and tables, plus 3 edge-case videos | `C_edge_cases.md` |
| iii) How long the PCM stores energy | Yes: hold test at 45 C, plain 21.6 h, PCM 51.6 h, PCM + SAC 49.9 h | `D_checks_and_hold_test.md` |
| 3-D videos (as in the Rajasthan twin) | Yes: 2 made (3-D day, 3-D clear single cycle); 3-D hold and 3-D no-sunlight left to capture | this file |

## Is arm 3 better and more optimal than arms 1 and 2?

Against the plain tank: yes (+118 kWh delivered, +28 h of hold at 45 C). Against PCM + B0: no on delivered energy or hold time, yes on safety (53 % fewer shield trips). See `00_AUDIT_SUMMARY.md`.

## Video index

**Made (7 videos):**

| Video | File | Length | Weather replayed |
|---|---|---|---|
| Three-arm day, 2-D | `video/o4_three_arm_day071_2021.mp4` | 9.6 s | 2021, day 71 |
| Edge: clear day, 2-D (good reference) | `export/scenarios_3arm/video/edge_clear.mp4` | 9.6 s | 2011, window day 5 (day 95) |
| Edge: no sunlight, 2-D | `export/scenarios_3arm/video/edge_no_sunlight.mp4` | 9.6 s | 2011, window day 5 |
| Edge: heat wave, 2-D | `export/scenarios_3arm/video/edge_heat_wave.mp4` | 9.6 s | 2011, window day 5 |
| Edge: sensor noise + 12 h blackout, 2-D | `export/scenarios_3arm/video/edge_sensor_fault.mp4` | 9.6 s | 2011, window day 5 |
| 3-D one day (clear) | `video/o4_3d_day071_2021.mp4` | 11.5 s | 2021, day 71 |
| 3-D clear single cycle | `video/o4_3d_edge_clear_2021.mp4` | 11.5 s | 2021, window day 5 (day 95) |

**Left to capture later** (commands in `matlab/`, one at a time):

| Video | Command | Output | Approx. render time |
|---|---|---|---|
| Edge: rain / cloud | `run_edge_videos('rain_cloud')` | `export/scenarios_3arm/video/edge_rain_cloud.mp4` | 7 min |
| Edge: low temperature | `run_edge_videos('low_temperature')` | `.../edge_low_temperature.mp4` | 7 min |
| Edge: dead / stuck pyranometer | `run_edge_videos('pyranometer_faults')` | `.../edge_pyranometer_faults.mp4` | 7 min |
| 3-D 72 h hold | `run_3d_videos('hold')` | `video/o4_3d_hold72h_day072_2021.mp4` | 15 min |
| 3-D no-sunlight single cycle | `run_3d_videos('edge_no_sunlight')` | `video/o4_3d_edge_no_sunlight_2021.mp4` | 10 min |

Pictures taken from the made videos are in `pictures/`, named `<video>_<seconds>s.png` (for example `edge_no_sunlight_05.0s.png`).

## What every video shows on screen (parameters and values)

- **Design values, read from `export/plant_params.json`:** tank water mass (70.4 kg, and 100.0 kg for the plain tank), collector area 2.5 m2 with FR(ta) 0.75 and FRUL 4.5 W/m2K, PCM PureTemp 58 with Tm 58 C and L 225 kJ/kg, 24.8 kg PCM in 104 capsules of 82 mm, flow 0.0388 kg/s, shield limits (water 72 C, PCM 62 C), delivery target 45 C, mains water 28.5 C, collector cut-in 10 W/m2.
- **Live values per arm:** water temperature, PCM temperature, melt fraction, collector heat, executed action (CHARGE / IDLE / BYPASS), pump state, delivered energy, shield trips, plus sun (GHI), ambient temperature and hot-water draw.
- **Time:** day of year and clock time.
- **Data source:** the weather file and hours used, `plant_params.json`, `sac_actor_r0.json` (the frozen r0 smartfc controller), and `simulate_hours.m` at 150 s sub-steps.

## Notes on specific videos

- **Sensor fault:** during the 12 h blackout (first half of the day) every arm goes to BYPASS and collects almost nothing, even at about 900 W/m2 of sun. This is the fail-safe behaviour of the safety interlock, and it explains why that scenario delivers least.
- **No sunlight:** the PCM never melts (melt stays 0 %) and the tank cools to about 29 C, so no arm can help when there is no sun.
- **Replay years:** the 2-D edge videos use 2011 (a locked test year) so they match the edge-case tables, and are exploratory. The 3-D clear single cycle uses 2021 weather instead.

## About the 3-D videos

They are a 3-D view of a lumped result. The twin has one water node and one PCM node per tank, so all 104 capsules in a tank show the same melt fraction and the water has one temperature. Capsule positions, collector and pipes are an illustrative layout, and nothing is solved in 3-D. Rajasthan's 3-D video draws 10 stacked water layers because its twin is a 10-node tank, so its code was not reused. The code is `matlab/run_3d_videos.m`.

## Re-render commands (MATLAB, from `matlab/`)

```matlab
run_f(71)                  % three-arm day video (2-D)
run_edge_videos            % all seven edge-case videos (2-D)
run_3d_videos              % 3-D day and 3-D hold
run_3d_videos('edge')      % 3-D clear and no-sunlight single cycles
```
