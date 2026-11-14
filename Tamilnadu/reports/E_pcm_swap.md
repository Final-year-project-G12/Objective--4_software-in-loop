# Prompt E: PCM swap and flow

Source: `export/pcm_swap_study.csv/.json`. 2021 replay, geometry (100 L, 2.5 m2) held fixed. `policy_mode` 0 = SAC and 1 = B0 (inferred: the PureTemp 58 rows at flow 1.0 match the 1971.4 kWh SAC and 2002.6 kWh B0 figures from the three-arm run).

| PCM (O1 rank) | Flow x | Controller | Delivered kWh | Shield trips | Hold at 45 C (h) | kWh per kg PCM |
|---|---|---|---|---|---|---|
| RT57HC (1) | 1.0 | SAC | 1989.9 | 21,172 | 54.4 | 79.3 |
| RT57HC (1) | 1.0 | B0 | 2015.6 | 36,894 | 54.9 | 80.3 |
| n-Hexacosane (2) | 1.0 | SAC | 1966.2 | 23,638 | 50.8 | 91.6 |
| n-Hexacosane (2) | 1.0 | B0 | 1988.9 | 39,131 | 51.3 | 92.6 |
| PureTemp 58 (3, selected) | 0.7 | SAC | 1968.3 | 18,141 | 50.0 | 79.3 |
| PureTemp 58 | 1.0 | SAC | 1971.4 | 18,604 | 49.9 | 79.4 |
| PureTemp 58 | 1.3 | SAC | 1973.1 | 18,792 | 49.8 | 79.5 |
| PureTemp 58 | 0.7 / 1.0 / 1.3 | B0 | 2000.5 / 2002.6 / 2004.0 | about 40k | 51.6 / 51.6 / 51.5 | about 80.7 |

## What it says

- **Why PureTemp 58 was selected anyway:** Objective 2 picked it as a tie-break (lowest overheating, then service-time gain) among designs statistically indistinguishable on its primary metric, not because it delivers the most. So the twin's ranking differing from O2's choice is not a contradiction, but it should be stated.
- **The selected PCM is not the best in this twin.** RT57HC (O1 rank 1) delivers about 18 kWh more with SAC (and 13 kWh with B0) and holds about 4.5 h longer than PureTemp 58. Your earlier check, "the selected PCM ranks as O1/O2 expect", **does not hold here**. Say this in the report. Likely reasons: the O2 optimisation used its own metric and the twin's single-node capsule model scores differently, and RT57HC has more PCM mass (25.1 kg against 24.8 kg).
- **n-Hexacosane** has the highest kWh per kg PCM (91.6) because it uses less PCM (21.5 kg), but delivers less in total.
- **Flow has almost no effect:** delivered energy and hold time change by under 0.4 % across x0.7 to x1.3.
- **SAC was trained on the selected PCM (PureTemp 58) only,** so its results on RT57HC and n-Hexacosane are out-of-distribution. B0 is the fairer cross-PCM comparison, and it gives the same ranking.
- Three PCMs and one climate are too few for a firm ranking claim.
- The geometry was not re-optimised per PCM.
