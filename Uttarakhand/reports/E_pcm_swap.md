# E. PCM swap with flow axis (`export_campaign.py`, `pcm_swap_study.m` -> `export_r1/pcm_swap_study.csv/.json`, `results_campaign/ranking_check.csv`, `results_campaign/pcm_swap_study.png`)

Objective 1's top-3 for Uttarakhand cluster 1 (consensus-rank order, O2's copy of the O1 file, checked against the O2
state config's shortlist): **PureTemp 58** (rank 1, O2's choice), **n-Octacosane (C28)** (rank 2), **PlusICE A58**
(rank 3). Geometry held at the O2 design (55 capsules, same diameter, wall, single-layer arrangement); each PCM at flow
x0.7, x1.0, x1.3 (0.022 / 0.031 / 0.041 kg/s, all inside O2's 0.01-0.05 envelope); B0 and the PPO; full year 2023 and
the 12-start hold test. Every tank is built by O2's own setup (no MATLAB re-derivation; `swap_pcm.m` reproduces O2's
vectors to 3e-17, see D). PCM mass: 12.45 kg (PureTemp 58), 12.73 kg (the other two, density 910 kg/m3).

| PCM | Flow | Controller | Delivered 50 C [kWh] | Window [kWh] | Shield h | Hold 45 C [h] | Hold 50 C [h] |
|---|---|---|---|---|---|---|---|
| water-only twin | x1.0 | B0 | 1102.3 | 538.4 | 286.6 | 23.3 | 14.5 |
| PureTemp 58 | x0.7 | B0 / PPO | 1195.3 / 1155.3 | 612.6 / 572.6 | 536.9 / 9.9 | 32.0 / 25.7 | 23.3 / 17.0 |
| PureTemp 58 | x1.0 | B0 / PPO | 1184.4 / 1142.4 | 607.3 / 565.3 | 571.1 / 1.1 | 32.6 / 26.0 | 23.9 / 17.2 |
| PureTemp 58 | x1.3 | B0 / PPO | 1178.1 / 1135.5 | 604.0 / 561.4 | 587.7 / 0.5 | 32.7 / 26.0 | 24.0 / 17.1 |
| n-Octacosane (C28) | x0.7 | B0 / PPO | 1141.3 / 1119.9 | 557.1 / 535.7 | 619.8 / 153.0 | 27.1 / 24.1 | 18.5 / 16.3 |
| n-Octacosane (C28) | x1.0 | B0 / PPO | 1131.7 / 1106.8 | 553.1 / 528.1 | 647.7 / 119.4 | 27.9 / 24.5 | 19.4 / 16.3 |
| n-Octacosane (C28) | x1.3 | B0 / PPO | 1125.5 / 1100.5 | 549.7 / 524.8 | 664.4 / 105.3 | 28.1 / 24.8 | 19.5 / 16.4 |
| PlusICE A58 | x0.7 | B0 / PPO | 1188.9 / 1149.4 | 605.4 / 565.9 | 616.1 / 19.9 | 32.0 / 26.4 | 23.4 / 17.8 |
| PlusICE A58 | x1.0 | B0 / PPO | 1176.9 / 1136.0 | 598.9 / 558.1 | 651.2 / 8.5 | 32.4 / 26.5 | 23.7 / 17.8 |
| PlusICE A58 | x1.3 | B0 / PPO | 1169.8 / 1128.8 | 594.8 / 553.8 | 674.0 / 1.0 | 32.3 / 25.4 | 23.7 / 17.0 |

Per kg PCM and per m2, kWh per kg / per m2 collector at 50 C, all columns in the CSV. No hour over a hard limit in any run.

Findings:
- **PureTemp 58 (O2's choice) is first with B0** on delivery, window energy and hold at 45 C; PlusICE A58 (melts at the
  same 58 C) is 7.5 kWh and 0.2 h behind; **n-Octacosane (C28) is clearly last**: it melts at 61.6 C, closer to the
  62 C PCM guard and higher than the tank reaches on many days, so it melts less often (157 melt cycles a year against
  230 for PureTemp 58 and 237 for PlusICE A58, B0) and delivers less (-54.2 kWh window energy and -4.7 h hold at 45 C
  against PureTemp 58, B0).
- **Flow x0.7 to x1.3** moves delivery by 1-2 % and hold time by under 1 h. Lower flow is slightly better for delivery
  (better stratification); the collector's F_R does not depend on flow in O2's model (known limit, O2's
  `flow_dependent_fr` is off).
- **The PPO on other PCMs.** The PPO was trained only on the PureTemp 58 tank. On n-Octacosane it runs into the shield
  band 105-153 h a year (against 0.5-10 h on PureTemp 58), because its PCM-temperature and melt inputs mean something
  different; on PlusICE A58 it stays near its trained behaviour (1-20 h). On n-Octacosane the PPO's window energy
  (524.8-535.7 kWh) is **below the plain water-only tank's 538.4 kWh**: a controller trained for one PCM can remove
  the PCM's benefit on another. A PCM change on a real system would need the controller retrained or re-checked.
- **Ranking (`ranking_check.csv`): three items cannot support a ranking claim.** Twin ranks of the O1 order
  (PureTemp 58, C28, PlusICE A58) at flow x1.0: B0 [1 3 2] on every metric (Spearman +0.5); PPO [1 3 2] on energy (+0.5)
  but [2 3 1] on hold time (-0.5). With n = 3 Spearman can only be -1, -0.5, 0.5 or 1, so no confidence statement is
  possible. The twin agrees with O1 and O2 that PureTemp 58 is a good choice and puts C28 last, where O1 put it second.
