# Objective 4 – Outputs Guide (what every output is, where inputs come from, how to run it yourself)

## 1. The short version

- **Inputs** come from Objectives 2 and 3 (plant design, weather, demand, the trained SAC controller). Nothing is typed in by hand.
- **Algorithms:** the trained **SAC** neural-network controller (from Objective 3), plus physics models (collector, water tank, PCM melting) and a rule-based safety interlock. No new learning happens in Objective 4.
- **Outputs:** result plots, a summary table (CSV), and animation videos for each scenario. The numbers come from one simulator; the videos are drawn from the same numbers.
- **Videos are not recordings of a real device and not screen captures.** MATLAB runs the simulation, then draws one picture per simulated time step and joins them into an MP4.

---

## 2. Where the inputs are taken from

| Input | Origin | File used by MATLAB |
|---|---|---|
| Tank, collector, PCM, capsule and safety-limit numbers | Objective 2 design, Objective 3 contract (`contracts/obj3_environment_contract_tamilnadu_v3.json`) | `export*/plant_params.json` |
| Hourly sunlight (GHI), air temperature, hour of day, 2011 (8760 h) | Tamil Nadu weather data from Objective 2/3 | `export*/weather_2011.csv` |
| Hot-water demand per hour of day | Objective 2/3 demand model | inside `plant_params.json` |
| Controller weights (neural network 256 x 256) | Objective 3 trained SAC models in `results/sac/` | `export*/sac_actor_r0.json` |
| Python reference run (only for checking MATLAB) | Objective 3 environment | `export*/reference_2011.csv` |

`export/` = regime 0, `export_r1/` = regime 1, `export_r2/` = regime 2. They are produced by one Python script, `export_from_python.py`, and can be regenerated at any time:

```bash
python objective4_software_in_loop/export_from_python.py --regime 1 --year 2011 --hours 8760 --out objective4_software_in_loop/export_r1 --model results/sac/<your_model_folder>/best_model/best_model.zip
```

| Regime | Controller model used | Policy input size |
|---|---|---|
| 0 | `results/sac/r0/best_model` (the selected SAC) | 11 |
| 1 | `results/sac/r1/best_model` (the newer 15-input regime-1 model had collapsed to always-CHARGE, so it is not used) | 11 |
| 2 | committed `r2_gen2_sac_r2_w10_s42` (only regime-2 SAC available) | 15 (adds 3-hour sunlight forecast and next-hour demand) |

The weather data are real hourly values; the **edge cases are made by editing the real April 2011 weather** (see section 4), not by inventing weather.

---

## 3. Algorithms and methods used (and where)

| Step in the chain | Method | Where | Learned or fixed |
|---|---|---|---|
| Decision: CHARGE / IDLE / BYPASS each hour | **Soft Actor-Critic (SAC)** neural network, 3 layers, deterministic output binned at ±1/3 | `sac_policy.m` | Trained in Objective 3; only evaluated here |
| Sensors | Gaussian noise + 1 % dropout + blackout flag | `sensor_model.m` | Fixed model |
| Safety | Interlock: stale sensors force BYPASS; hard-limit fault latches | `safety_interlock.m` | Fixed rules |
| Solar collector | Hottel–Whillier efficiency model | `pcm_plant_hour.m` | Physics |
| Water tank | One-node energy balance with heat loss and hot-water draw | `pcm_plant_hour.m` | Physics |
| PCM capsules | Enthalpy method (melt fraction), Wakao–Kaguei heat transfer, aluminium wall heat capacity | `pcm_plant_hour.m` | Physics |
| In-plant safety shield | Cuts charging at 72 °C water / 62 °C PCM, checked every 150 s | `pcm_plant_hour.m` | Fixed rule |
| Baseline B0 | Always CHARGE | `sac_policy.m` (mode 1) | Fixed |
| Animation | MATLAB graphics objects updated per frame, `VideoWriter` MPEG-4 | `animate_system.m` | Drawing only |

No training, optimisation or machine learning runs in Objective 4. The MATLAB twin was verified to reproduce the Python simulator (same actions in 100 % of hours; temperatures equal to about 1e-13 °C).

---

## 4. How the outputs vary between scenarios

All scenarios use the same real 10 days of April 2011 weather. **Days 1–4 and 9–10 are identical in every scenario.** Only days 5–8 (the "event") are changed. That is why the videos look alike at the start; they split apart at day 5.

| Scenario | What is changed on days 5–8 | What you should see change |
|---|---|---|
| Clear | nothing | Sun big, rays strong, tank warms to about 60–72 °C, PCM capsules turn orange (melted) around midday and back to blue by night; safety shield fires on hot afternoons |
| No sunlight | sunlight = 0 | **Sun rays disappear**, pump stops, tank stays near mains temperature, PCM capsules stay blue (solid), delivered heat about 1 kWh (what was left over) |
| Rain / cloud | sunlight x 0.12 (max 120 W/m²), air −5 °C | Small weak sun, pump mostly idle, tank barely warms, PCM stays solid |
| Low temperature | air −12 °C, mains water −8 °C, sunlight x 0.9 | Sun normal but air colder, higher losses, tank still reaches about 60 °C in daylight |
| Heat wave | air +9 °C, sunlight x 1.15 | Tank and PCM reach the 72 °C shield sooner; the red "safety shield active" text and BYPASS appear more often |
| Sensor fault | noise + 12-hour sensor blackout | Banner **"SENSOR FAULT -> fail-safe BYPASS"** during the blackout, then normal operation resumes |

What stays the same in every video: the drawing layout, the 10-day trend strip at the bottom (it shows the full event pattern, with the moving black line showing the current time), and days 1–4.
What changes: sun size and rays, pipe and tank colour (water temperature), capsule colour (melt fraction), action text (CHARGE / IDLE / BYPASS), info box numbers, and the trend curves.

**Note on regime 1 and 2:** the controller there is close to always-charge, so SAC and B0 give nearly the same videos and numbers except for shield counts and the cold case. In the regime 2 sensor-fault case B0 delivers almost nothing because the interlock latches a fault after one over-limit reading and stays in BYPASS (a debounce and manual reset are recommended; not implemented).

**Tip:** the standard videos show all ten days, so the first 4 days look identical. The new script below can film only days 4–9 so the differences start almost immediately.

### What each output file is

| File | Content |
|---|---|
| `export*/scenarios/<scenario>.png` | 5-panel plot: weather, water/PCM temperature against limits, PCM melt fraction, commanded vs executed action, cumulative energy. SAC solid, B0 dotted |
| `export*/scenarios/scenario_summary.csv` | One row per scenario and policy: delivered kWh, unmet kWh, shield trips, hard violations, min/max temperatures, PCM melt at the end, fail-safe hours |
| `export*/scenarios/validation_closed_loop.json` | The proof that MATLAB matches Python (14 days) |
| `export/scenarios/*_animation.mp4` | Animated schematic videos (regime 0) |
| `export/scenarios/*_frame.png` | One still frame from a video |
| `export*/scenarios/my_*.mp4` | Videos made with `make_my_video` (days 4-9 only, pump and label fixes). Ready-made: regime 0 `no_sunlight`, `rain_cloud`, `heat_wave`, `clear`, `low_temperature`; regime 1 `heat_wave`, `low_temperature`; regime 2 `rain_cloud`, `heat_wave` |
| `export*/codegen_verification.json`, `export*/codegen_c/` | C code generated from the controller and the check that it decides like MATLAB |

---

## 5. How the videos are made

1. `simulate_hours` runs the closed loop hour by hour and keeps a log: temperatures, melt fraction, action, shield trips, sunlight, demand.
2. `animate_system` takes that log. For each hour it sets: sun size and rays from sunlight; tank colour from water temperature; capsule colour from melt fraction; pump icon and moving water dots from the action (dots only move when the pump runs); and text from the numbers.
3. Each hour is drawn as several frames (water dots move between frames); every frame is captured with `getframe` and written to an MP4 with `VideoWriter`.

The water movement is schematic (dots along the pipes), not a computed flow field. Colours and temperatures are real simulation values.

---

## 6. Run it yourself in MATLAB (and make your own videos)

**Open MATLAB** (R2023b, with Simulink installed), then in the Command Window:

```matlab
cd 'C:\Users\jaswi\OneDrive\Desktop\ALL\SEM_7\project\jammalamadugu\new_obj\objective3\objective4_software_in_loop\matlab'

% one video, one scenario (about 5-10 min to render)
make_my_video('regime', 0, 'scenario', 'no_sunlight')

% other regimes / scenarios / controller
make_my_video('regime', 1, 'scenario', 'heat_wave')
make_my_video('regime', 2, 'scenario', 'rain_cloud', 'policy', 'b0')   % b0 = always-charge baseline

% your own weather: 30% sunlight, 6 degC colder, on days 5-8, film days 4-9
make_my_video('scenario', 'custom', 'ghi_mult', 0.3, 'tamb_offset', -6, 'days', [4 9])

% all six scenarios, plots, summary table (no videos unless you want them)
regime = 0; doAnim = false; run_scenarios
```

The video appears in `export*/scenarios/my_<scenario>_<policy>.mp4`. Rendering is slow because every frame is drawn and captured; use `'frames_per_hour', 1` for a faster, rougher video. `make_my_video` returns the full log `L`, so you can plot anything yourself, for example `plot(L.Tw)`.

**Running the controller only (no video):**

```matlab
tw = load_twin_params('../export', 2011);
W  = tw.wx.signals.values(90*24 + (1:240), :);     % 10 days of April
L  = simulate_hours(tw, W, tw.P, 0, 0, []);        % 0 = trained SAC, 0 = ideal sensors
plot(L.Tw); hold on; plot(L.Tpcm)
```

**The Simulink block diagram:** run `build_pcm_twin_model` once, then `open_system('pcm_drl_twin')`. It is slow (about 11 s per simulated hour), so use it for short checks; the plain MATLAB loop gives identical numbers.

**Generated C code (controller only):**

```matlab
regime = 0; verify_codegen      % writes C code to export/codegen_c and checks it against MATLAB
```

**Screen-recording yourself:** simply run `make_my_video`; there is no need for a screen recorder. If you want a live window instead of a video, tell me and I will add a live-view option.

---

## 7. Honest limits

- This is **emulated validation** (software-in-the-loop). No physical rig was used.
- Water flow and heater motion in the videos are schematic.
- Rain only reduces sunlight and air temperature; there is no frost or wet-surface model.
- The policy decides hourly; the hardware spec says a 10-second cycle (the shield inside the plant still checks every 150 s).
- The regime 1 and 2 policies use a forecast of the next 3 hours. In the twin this forecast is the true future weather (a perfect forecast), whereas a real device would use a weather-service forecast with errors.
- The animations are not frame-for-frame identical, but they share the same drawing and the same first four days, so they look similar at a glance.
