# Prompt F: pump-bug fix, one-day video

## The bug and the fix

`matlab/animate_system.m` drew the pump as running whenever CHARGE was executed above the cut-in irradiance, even in hours when the collector added no heat and the plant did not circulate (`pcm_plant_hour.m` turns the loop off when the gain is zero). The pump is now drawn on only when the collector heat of that hour is above zero (`Q_coll_Wh > 0`); `animate_three_arm.m` uses the same rule.

## Pump check (`matlab/check_pump_drawing.m`, `export_r1/pump_check_2023.json`, full year 2023)

| Arm | Hours the old rule drew the pump on | of which with no collector gain (the bug) | Hours the new rule draws it on | Violations (new rule) |
|---|---|---|---|---|
| 1 plain tank + B0 | 3180 | 174 | 3006 | **0** |
| 2 PCM + B0 | 3345 | 169 | 3176 | **0** |
| 3 PCM + DQN | 3348 | 169 | 3179 | **0** |

So the old drawing was wrong in about 170 h a year per arm; the new rule has 0 violations in all arms.

## Videos (all MATLAB graphics objects joined into an MP4; the tank bands are a summary of 10 nodes, nothing is solved in 2-D or 3-D)

| Video | File | What it shows |
|---|---|---|
| Three-arm day, 2-D | `video/o4_three_arm_day165_2023.mp4` | Day 165 of 2023 (the day of report B), 00:00 to 06:00 next day: the three tanks side by side with top and bottom temperature bands, PCM capsules changing colour with melt fraction ("no PCM" for the plain tank), pump on only with collector gain, action, cumulative delivered energy and shield trips, trend strip with a cursor |
| Edge cases, 2-D, three arms | `export_r1/scenarios_3arm/video/edge_<scenario>.mp4` | clear, no_sunlight, rain_cloud, low_temperature, heat_wave, sensor_fault, dead_pyranometer: the first event day (24 h) of the 10-day April window |
| 3-D, one day | `video/o4_3d_day165_2023.mp4` | PCM + DQN tank, 10 layers coloured by temperature, capsules by melt fraction, same day |
| 3-D, clear single cycle | `video/o4_3d_edge_clear_2023.mp4` | clear April event day |
| 3-D, no-sunlight single cycle | `video/o4_3d_edge_no_sunlight_2023.mp4` | the PCM never melts |
| 3-D, 72 h hold | `video/o4_3d_hold72h_day165_2023.mp4` | the cool-down after charging stops, from 18:00 |
| Earlier Rajasthan videos | `results_campaign/figures/A1_schematic_clear_days.mp4`, `A2_retention_72h.mp4`, `A3_tank_3D_retention.mp4`; `export_r1/scenarios/*_animation.mp4`, `my_*.mp4` | single-arm schematics, 72 h retention, 3-D hold |

Stills taken from the videos are in `pictures/`, named `<video>_<seconds>s.png` (for example `edge_no_sunlight_05.0s.png`).

**The 3-D videos are 3-D views of a 1-D result.** The water layers are real (the 10-node tank has 10 different temperatures, unlike the single-node Tamil Nadu twin); the capsule ring layout, collector and pipes are an illustrative layout. Code: `matlab/run_3d_videos.m` and `animate_tank3d.m`.

## Known cosmetic limits

- In the schematic the state text reads CHARGE at night because that is the policy's command; the pump is drawn stopped when there is no sun or no collector gain.
- The sensor-fault clip shows the first 24 h of the 12 h blackout: every arm goes to BYPASS even in strong sun (the interlock), which is why it delivers least.
- The edge videos replay the April 2023 window; they do not show the 4 days of spin-up.

## Re-render commands (MATLAB, from `matlab/`)

```matlab
run_edge_videos('three_arm_day')   % three-arm day video (2-D)
run_edge_videos                    % the seven edge-case videos (2-D, three arms)
run_3d_videos                      % 3-D day, clear, no-sunlight, 72 h hold
```
