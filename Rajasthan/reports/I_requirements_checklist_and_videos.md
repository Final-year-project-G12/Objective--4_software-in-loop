# Requirements checklist and video index (Rajasthan)

## Checklist against the Objective 4 requirements (same list as the Tamil Nadu twin)

| Item | Done? | Where |
|---|---|---|
| 1) Plain tank without PCM and why it behaves so | Yes: arm 1 numbers, plots, hold time, and the explanation in report B and the README | `A_validation_and_three_arm.md`, `B_one_day_plots.md`, `D_checks_and_hold_test.md` |
| 2) Selected PCM, no AI | Yes: arm 2 (PCM + B0, PureTemp 60) | same |
| 3) O1 + O2 + O3 combined | Yes: arm 3 (PCM + DQN, regime 1 released policy) | same |
| i) One-cycle charge / idle / bypass graph with PCM temperature, water temperature and other parameters | Yes: `export_r1/one_day_cycle_2023.png` and `.csv` (day 165) | `B_one_day_plots.md` |
| i) Slow single-cycle videos | Yes: three-arm 2-D day, 7 three-arm 2-D edge videos, 4 3-D videos (see below) | this file, `F_pump_fix_and_video.md` |
| ii) Edge cases and how the PCM stores heat, arms 1, 2, 3 | Yes: three-arm table and plots, plus dead and stuck pyranometer | `C_edge_cases.md` |
| iii) How long the PCM stores energy | Yes: hold test at 30, 40, 45, 50 °C: plain 51.9 h, PCM + B0 61.2 h, PCM + DQN 61.0 h at 45 °C | `D_checks_and_hold_test.md` |
| 3-D videos | Yes: day, clear single cycle, no-sunlight single cycle, 72 h hold | this file |
| PCM swap, top-3, flow x0.7 / x1.0 / x1.3 | Yes, all nine PCM-flow cells, B0 and DQN | `E_pcm_swap.md` |
| Benchmark | Yes: diagnosed, and a calibration run (null: c = 5.03) | `G_H_benchmark_and_sensor_faults.md` |
| Objective 3 SAC controllers (added 15 Nov 2026) | Yes: exported, validated (100 % identical actions), four-arm tables, edge cases, hold test, swap, sensor faults, cross-check with Objective 3 to about 1e-12 kWh. No SAC videos yet | `J_objective3_update_sac_and_rerun.md` |
| Controller used is the released one | Verified: SHA-256 of the exported weights matches `gen2_selected_dqn.json`; the export re-run is byte-identical | `A_validation_and_three_arm.md` |

## Is arm 3 better and more optimal than arms 1 and 2?

Against the plain tank: yes (+126.8 kWh delivered, +9 h of hold at 45 °C). Against PCM + B0: no on delivered energy (-15.1 kWh) or hold time (-0.2 h); yes on safety (57 % fewer guard-band hours). See `00_AUDIT_SUMMARY.md`.

## Video index

All 2-D videos are 1280x720 MP4 (8 frames per second, 3 frames per hour: 9 s for 24 h); the 3-D ones are 20 frames per second, 6 frames per hour (7 s for 24 h, 22 s for the 72 h hold).

| Video | File | Weather replayed |
|---|---|---|
| Three-arm day, 2-D | `video/o4_three_arm_day165_2023.mp4` | 2023, day 165 (00:00 to 06:00 next day) |
| Edge: clear day, 2-D | `export_r1/scenarios_3arm/video/edge_clear.mp4` | April 2023, event day 1 (day 95) |
| Edge: no sunlight, 2-D | `export_r1/scenarios_3arm/video/edge_no_sunlight.mp4` | same window |
| Edge: rain / cloud, 2-D | `export_r1/scenarios_3arm/video/edge_rain_cloud.mp4` | same window |
| Edge: low temperature, 2-D | `export_r1/scenarios_3arm/video/edge_low_temperature.mp4` | same window |
| Edge: heat wave, 2-D | `export_r1/scenarios_3arm/video/edge_heat_wave.mp4` | same window |
| Edge: sensor noise + 12 h blackout, 2-D | `export_r1/scenarios_3arm/video/edge_sensor_fault.mp4` | same window |
| Edge: dead pyranometer, 2-D | `export_r1/scenarios_3arm/video/edge_dead_pyranometer.mp4` | same window |
| 3-D one day | `video/o4_3d_day165_2023.mp4` | 2023, day 165 |
| 3-D clear single cycle | `video/o4_3d_edge_clear_2023.mp4` | April 2023, event day 1 |
| 3-D no-sunlight single cycle | `video/o4_3d_edge_no_sunlight_2023.mp4` | same window |
| 3-D 72 h hold | `video/o4_3d_hold72h_day165_2023.mp4` | 18:00 on day 165, sun off, real ambient |

Earlier single-arm videos remain in `results_campaign/figures/` (`A1_schematic_clear_days.mp4`, `A2_retention_72h.mp4`, `A3_tank_3D_retention.mp4`) and in `export_r1/scenarios/`. Stills taken from the made videos are in `pictures/`, named `<video>_<seconds>s.png` (for example `edge_no_sunlight_04.6s.png`).

## What every video shows on screen (parameters and values)

- **Design values, from `export_r1/plant_params.json`:** tank water 50 L (35.2 kg of water and 13.4 kg of PureTemp 60 in 52 capsules of 81.6 mm, in 10 nodes; the plain tank holds all 50 kg of water), collector area 1.5 m² with F_R(τα) 0.75 and F_R U_L 4.5 W/m²K, PCM PureTemp 60 (Tm 61 °C, L 220 kJ/kg), flow 0.0493 kg/s, shield limits (water 72 °C, PCM 62 °C), delivery target 45 °C, mains 26 °C, collector cut-in 10 W/m².
- **Live values per arm:** top and bottom layer temperature, PCM temperature and melt fraction, collector heat, executed action (CHARGE / IDLE / BYPASS), pump state, cumulative delivered energy and shield trips, plus the sun (GHI), ambient temperature and hot-water draw, and the clock.
- **Data source:** the weather file `weather_2023.csv`, `plant_params.json`, `dqn_qnet_r1.json` (the released DQN) and `simulate_hours.m` at 150 s sub-steps.

## Notes on specific videos

- **Sensor fault:** during the 12 h blackout every arm goes to BYPASS and collects almost nothing, even in strong sun: the interlock's fail-safe, which is why that scenario delivers least.
- **No sunlight:** the PCM never melts and the tank cools to mains temperature; no arm can help without sun.
- **3-D videos** are a 3-D view of a 1-D result (see report F); the 10 layers are real.

## Re-render commands (MATLAB, from `matlab/`)

```matlab
run_edge_videos('three_arm_day')   % three-arm day video (2-D)
run_edge_videos                    % all seven edge-case videos (2-D)
run_3d_videos                      % 3-D day, clear, no-sunlight, 72 h hold
```
