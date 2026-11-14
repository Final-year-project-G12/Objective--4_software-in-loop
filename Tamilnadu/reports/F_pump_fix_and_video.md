# Prompt F: pump fix and video

## Pump fix

`matlab/animate_system.m` keys the pump indicator off the real collector heat (`Q_coll_Wh`) instead of "CHARGE commanded and irradiance above cut-in". `run_f.m` re-checked this on 14 Nov 15:50 for all three arms over the full year 2021: **pump-on-with-zero-gain violations = 0 in every arm (PASS)**.

## Video (re-rendered)

File: `video/o4_three_arm_day071_2021.mp4` (`run_f` writes it to `../../results/`). Read back with MATLAB: 115 frames, 9.58 s, 12 fps, 1920 x 1080, 1.57 MB. Re-render with `run_f(71)` from `matlab/`.

It shows day 71 of 2021, the same day as `export/one_day_cycle_2021.png`. Three columns (plain tank + B0, PCM + B0, PCM + SAC), four rows (water and PCM temperature, melt %, collector heat Q_coll, pump on/off), a moving time marker, and CHARGE / IDLE / BYPASS shading and labels per arm. I viewed a frame from mid-video.

What the video shows (day 71):
- **Plain tank:** water heats to about 72 C by hour 6, stays at the limit, then cools to about 34 C overnight. No PCM panel ("no PCM").
- **PCM + B0:** the PCM melts from 0 to 100 % between hours 5 and 8, holds at 100 % to hour 12, then re-solidifies by hour 15 while releasing heat, so the water stays about 4 C warmer overnight than the plain tank.
- **PCM + SAC:** same melt and release, but the pump switches on and off during the hot hours (6 to 11) and the arm shows BYPASS and IDLE phases, which is how it avoids shield trips.

## Changes made in this fix

- Day 71 instead of day 313 (on day 313 the PCM never melted).
- 5 frames per hour at 12 fps (9.6 s) instead of 24 frames at 10 fps (2.4 s).
- Plain tank PCM line removed and labelled "no PCM"; leftover "data1" legend entry removed.

## Remaining notes

- In arms 1 and 2 the shaded BYPASS phase (hours 7 to 11) still shows small collector gains (50 to 130 Wh), so the pump is drawn on. This is consistent with the rule (pump on if real gain is above zero), because the controller's executed action is partly blended within the hour.
- The older single-arm scenario videos (12 Nov, pre-retrain) and the day-313 video were removed from this version.
