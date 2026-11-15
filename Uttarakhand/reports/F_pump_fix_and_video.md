# F. Pump fix and one-day video (`check_pump_drawing.m`, `animate_three_arm.m`, `animate_system.m`)

## Pump-drawing bug (`export_r1/pump_check_2023.json`)

OLD rule (Tamil Nadu's original animation): pump drawn running whenever the controller commands the loop on, the sun is
above the collector cut-in and the water shield did not fire. In O2's kernel the loop can still be off in such an hour:
the a - b T_bottom >= 0 re-solve stops it when the collector would lose heat, and the PCM shield or a part-hour water
shield acts inside the hour. NEW rule (`animate_system.m` since the first Uttarakhand version, and `animate_three_arm.m`):
pump drawn running only when the loop actually circulated in that hour (`pump_frac > 0`, counted by the plant) AND the
collector added heat.

| Arm (2023) | Old rule: hours drawn on | ... of which no circulation or no collector gain (bug) | New rule: hours on | Violations | Hours the loop ran only part of the hour |
|---|---|---|---|---|---|
| Plain + B0 | 3813 | 222 | 4125 | 0 | 892 |
| PCM + B0 | 3936 | 223 | 4124 | 0 | 787 |
| PCM + PPO | 4049 | 223 | 3835 | 0 | 387 |

The new rule also shows the pump in hours the old one hid (when the water shield fired for part of the hour while the
loop still ran the rest of it). The animations write the share of the hour the loop ran ("ENABLE, loop 33 %").

## Videos

| File | Content |
|---|---|
| `video/o4_three_arm_day105_2023.mp4` | One-day video: plain tank, PCM + B0, PCM + PPO side by side, 00:00 on 15 April 2023 to 06:00 next morning (31 h), each tank drawn as its 10 kernel nodes, capsules coloured by melt fraction, pump by the new rule, cumulative delivered energy and shield hours under each tank, trend strip of the three top-layer temperatures. Still: `o4_three_arm_day105_2023_frame.png` (12:00, PPO in bypass, both B0 arms at the shield). |
| `video/o4_3d_day105_2023.mp4` | 3-D, one day: PCM + PPO tank, 00:00 on 15 April to 06:00 next morning; the 10 layers coloured by node temperature, the 55 capsules (5 layers of 11, the O2 layout) by node melt fraction; caption shows clock, top / bottom temperature, melt and ENABLE / BYPASS. Stills `pictures/3d_day105_{1,2,3}.png`. |
| `video/o4_3d_edge_clear_2023.mp4` | 3-D, clear single cycle: event day 1 of the April edge-case window. Stills `pictures/3d_edge_clear_*.png`. |
| `video/o4_3d_edge_no_sunlight_2023.mp4` | 3-D, no-sunlight single cycle: the PCM never melts. Stills `pictures/3d_edge_no_sunlight_*.png`. |
| `video/o4_3d_hold72h_day105_2023.mp4` | 3-D, 72 h hold: cool-down from 18:00 on day 105 with sun off and no draw (the hold test). Stills `pictures/3d_hold72h_day105_*.png`. |
| `export_r1/scenarios/my_*.mp4`, `export/scenarios/my_low_temperature_{ppo,b0}.mp4` | Single-arm videos, days 4-9 of the April 2023 window, current PPO, new pump rule (regenerated 15 Nov). |

The drawing is schematic: water flow is shown as moving dots and node bands, nothing is solved in 2-D or 3-D.
**The 3-D videos are 3-D views of a 1-D result** (`matlab/run_3d_videos.m`, `animate_tank3d.m`, ported from Rajasthan):
the 10 water layers are real (they have 10 different temperatures, unlike the single-node Tamil Nadu twin) and the
capsule count per layer is the twin's own; the ring positions of the capsules are illustrative.
