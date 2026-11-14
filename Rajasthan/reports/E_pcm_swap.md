# Prompt E: PCM swap with the flow axis

Source: `export_r1/pcm_swap_study.csv` / `.json` (made by `matlab/pcm_swap_study.m` from `results_campaign/campaign_results_flowall.csv`, which `run_campaign({'flow_all'}, '_flowall')` writes). Year 2023, 12 hold-test starts (18:00 local), 72 h cap. **Geometry held fixed:** capsule count (52), size, wall, node layout and the Objective 2 flow stay as in the Objective 2 design; only the material changes (`swap_pcm.m`: melting band Tm ± 1 K, latent heat, specific heats, conductivity, PCM mass of a capsule from the density, wall heat capacity per kg of PCM). Objective 1's top-3 for Rajasthan cluster 1 (Nagaur, 83 points): PureTemp 60 (rank 1, the PCM Objective 2 chose), CrodaTherm 60, n-Heptacosane (C27). `policy_mode` 0 = DQN, 1 = B0; `shield_events` is guard-band hours here.

| PCM (O1 rank) | Flow | B0 delivered [kWh] | DQN delivered [kWh] | Window B0 / DQN [kWh] | Hold at 45 °C B0 / DQN [h] | Guard-band h B0 / DQN |
|---|---|---|---|---|---|---|
| PureTemp 60 (1) | x0.7 | 908.86 | 893.61 | 581.65 / 566.40 | 60.5 / 60.2 | 939 / 417 |
| PureTemp 60 (1) | x1.0 | 912.36 | 897.26 | 587.16 / 572.07 | 61.2 / 61.0 | 994 / 430 |
| PureTemp 60 (1) | x1.3 | 911.82 | 898.81 | 587.71 / 574.71 | 61.4 / 61.3 | 1032 / 437 |
| CrodaTherm 60 (2) | x0.7 | 895.13 | 889.57 | 566.61 / 561.06 | 62.2 / 61.9 | 1324 / 738 |
| CrodaTherm 60 (2) | x1.0 | 889.29 | 885.62 | 562.71 / 559.04 | 62.4 / 62.3 | 1406 / 724 |
| CrodaTherm 60 (2) | x1.3 | 885.98 | 882.98 | 560.43 / 557.44 | 62.6 / 62.5 | 1447 / 720 |
| n-Heptacosane C27 (3) | x0.7 | 894.49 | 894.22 | 566.90 / 566.62 | 62.1 / 62.1 | 1574 / 909 |
| n-Heptacosane C27 (3) | x1.0 | 888.33 | 887.86 | 562.73 / 562.25 | 62.2 / 62.0 | 1647 / 860 |
| n-Heptacosane C27 (3) | x1.3 | 884.14 | 884.35 | 559.61 / 559.82 | 62.2 / 62.0 | 1693 / 836 |

The water-only tank at each flow (for the gains) is in `campaign_results_flowall.csv`; the PCM + B0 gain in window energy over it is +109 to +138 kWh (B0) and +104 to +125 kWh (DQN) for all nine rows, far outside Objective 2's 14.4 kWh repeatability band.

## What it shows

- **Delivered energy:** PureTemp 60 is the best of the three with B0 at nominal flow (912.4 kWh), 23 kWh ahead of CrodaTherm 60 (889.3) and 24 ahead of C27 (888.3). That gap is larger than the 14.4 kWh band; the other two are within 1 kWh of each other. With the DQN the gap is 9-12 kWh (897.3 against 885.6 and 887.9), inside the band.
- **Hold time:** the three PCMs differ by about 1 h (61.0-62.6 h at 45 °C); the PCM Objective 2 chose, PureTemp 60, has the **shortest** hold. The spread is far smaller than the 12-start variation (SD about 13 h, 6-7 of 12 runs at the 72 h cap), so it cannot be ranked.
- **Energy per kg of PCM:** C27 delivers 82 kWh/kg against 68-69 for the others, because its density (773 kg/m³) gives only 10.8 kg of PCM in the same capsules (13.4 kg for PureTemp 60, 12.9 kg for CrodaTherm 60).
- **Flow (x0.7, x1.0, x1.3):** delivered energy moves by at most about 10 kWh (inside the repeatability band) and hold time by at most 1.1 h. The collector's F_R is flow-independent in this model (a known Objective 2 limit), so a flow effect on collector efficiency is not captured.
- **Safety:** the DQN cuts guard-band hours by 56-58 % for PureTemp 60, 44-50 % for CrodaTherm 60 and 42-51 % for C27, at any flow.

## Does Objective 1's ranking survive?

Objective 1 ranks PureTemp 60 > CrodaTherm 60 > n-Heptacosane. By window energy the twin agrees on first place; by hold time it puts PureTemp 60 last; and the CrodaTherm / C27 order flips between flows. **Three items per cluster are too few to support a ranking claim:** a Spearman value can only be ±0.5 or ±1, and the twin's order moves with the flow and with the capsule constant (`results_campaign/ranking_check*.csv`). The Monte-Carlo top-3 inclusion for the cluster is 99.3 / 93.6 / 56.1 % (the Objective 2 copy of Objective 1's file; Objective 1's own later file gives 95.58 / 93.72 / 55.84 %; ranks identical).

## Limits

- The geometry is held fixed: a different PCM would get a different optimal design from Objective 2. This answers the narrower question "given this design, which of the three performs best under control".
- The capsule constants c = 5, F = 2 are the frozen Objective 2 values (a calibration on a tank-level benchmark gives c = 5.03; see report G_H). Densities, specific heats and conductivities come from Objective 1's database (`pcm_database_rajasthan.csv`), with solid specific heat where the database has one.
- Supercooling (-0.5 to -1.7 K for these PCMs) is not modelled; a proxy shows under 1 h effect on the hold.
