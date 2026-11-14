# Prompts G and H: benchmark against Amanowicz & Turski 2025, and sensor faults

## G: benchmark (`export_r1/amanowicz_benchmark.json`; `results_campaign/benchmark_amanowicz_*.csv`, `capsule_*.csv`)

Amanowicz and Turski (Energies 18(2) 345, 2025): a 9.6 dm³ Styrofoam tank cooling in 27 °C air for 7200 s, water only and with 9 RT44HC capsules (40 % of the volume); measured drops 14 K and 26 K. The twin is compared with the paper's own printed linear fits of its measured curves (equations 2-5) every 300 s; no figure was digitised. Assumed values (plastic wall, latent heat 250 kJ/kg from the Objective 1 database, capsules starting at 27 °C) are listed in the header of `benchmark_amanowicz.m`.

| Capsule mapping | Tank loss | Water-only RMSE | With capsules: RMSE / bias / drop |
|---|---|---|---|
| one 300 mL sphere per cuboid capsule | paper's insulation data (0.82 W/K) | 3.09 K | 8.42 K / +7.9 K / 20.3 K |
| one sphere per capsule | fitted to the water-only case (1.55 W/K) | 0.46 K | 5.72 K / +4.9 K / 24.6 K |
| **same PCM mass and surface/volume as the slab** | paper's data, nothing fitted | 3.09 K | **1.06 K / +0.2 K / 25.2 K** |
| same surface/volume | fitted | 0.46 K | **1.41 K / -0.9 K / 26.6 K** |

**Diagnose, and also calibrate.** Unlike the Tamil Nadu scope ("diagnose the error, but don't recalibrate"), a calibration was run here (`diagnose_capsule.m`, `calibrate_capsule.m`) after the diagnosis.

- **The 4.5-4.9 K warm bias was a geometry-mapping artefact, not a capsule constant.** The paper's 22 mm slab has an 11 mm conduction half-thickness; one 83 mm sphere has 40 mm, 3.6 times too long. Spheres that keep the PCM mass and the surface/volume ratio reproduce the benchmark with the frozen constants (c = 5, F = 2), RMSE 1.1-1.4 K, drops within 5 %. The model is 5 % off the 26 K measured drop (in the Tamil Nadu twin: 38.5 % off).
- **No constant removes the bias on the one-sphere mapping:** F has no effect (the capsules never pass 50 % melt in the test), c saturates at RMSE 4.5 K even at c = 50, and the film coefficient helps but cannot close the gap. The film is 59 % of the series resistance at zero flow.
- **Calibration:** c fitted on the matched mapping is 5.03 against 5 (null). Held out on Tan 2009 and Dong 2022 (single capsules, not used in the fit): melt-fraction RMSE 0.360 and 0.079 (frozen: 0.361 and 0.078). Fitting on the one-sphere mapping gives c = 40 and breaks the held-out fits (Dong 0.447), so it was rejected.
- **Single capsules are still faster in experiment** (Tan 2009: 25 % melt at 71 min against 40 min measured; Dong 2022: half melt at 78 against about 58 min); the two disagree on the direction of any change in c.
- **Effect on the campaign** (`calibration_effect.csv`): c = 5.03 changes the 45 °C hold by at most 0.05 h (0.24 h for one run) and window energy by at most 0.3 kWh; a c = 7.1 bound lengthens the hold by 0.4-1.7 h and changes window energy by -12 to +2 kWh. The frozen hold times are slightly short, not optimistic.
- Rocha 2023 and Jia 2024 argue that such constants do not transfer between cases; nothing here contradicts them.

## H: sensor faults (`export_r1/scenarios_3arm/`, `results_campaign/sensor_fault_seeds.csv`, `dead_pyranometer_*.csv`)

**Six scenarios plus dead and stuck pyranometer:** report C.

**Sensor fault with 20 seeds** (10-day April window, noisy sensors, 1 % dropout and a 12 h blackout; mean ± 95 % CI): DQN 8.40 ± 0.02 kWh and 5.49 ± 0.13 shield hours; B0 8.60 ± 0.02 kWh and 13.86 ± 0.19 h. In all seeds the interlock goes to fail-safe BYPASS for the blackout and the dropouts, then recovers.

**Dead pyranometer with 20 seeds** (same window, noisy other sensors; the stuck value is applied after the noise draw so a healthy and a dead run with the same seed see the same dropouts): DQN 11.16 ± 0.02 kWh and 11.31 ± 0.02 shield hours against 11.03 ± 0.02 and 7.72 ± 0.13 healthy; B0 11.26 ± 0.02 kWh and 18.66 ± 0.18 h either way. The largest change in the DQN's fail-safe hours caused by the dead sensor is 0 h: the interlock does not react, because it has no irradiance plausibility rule.

**Over the full year** (ideal other sensors, no seed): DQN with a dead pyranometer 908.85 kWh and 701 guard-band hours, against 897.3 kWh and 430 healthy (B0: 912.36 kWh, 994 h); it commands a different action in 246 of 8760 h and idles 228 h instead of 356. With the sensor dead, the DQN is no safer than healthy; a plausibility check on the irradiance reading (0 at noon with a clear forecast) would be the obvious addition for a real device.

**Not run:** a pyranometer that freezes at its last reading during the day (stuck is a constant here); regimes 0 and 2 with sensor faults (their policies always charge, so they equal B0).
