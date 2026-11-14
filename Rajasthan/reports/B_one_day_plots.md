# Prompt B: one-day cycle plots

Source: `export_r1/one_day_cycle_2023.png` and `.csv` (made by `matlab/one_day_cycle.m`). **Day 165 of 2023**, the evening (of the 12 hold-test starts) with the most stored energy in the DQN arm; 00:00-23:00 local; the three arms on the same weather, each from its own state in the full-year run.

The plot has six panels: sun, ambient and hot-water draw; top-layer water temperature of the three arms with the PCM temperature (dotted) and the 45 / 72 °C lines; PCM melt fraction; collector heat; cumulative delivered energy; and the executed action of each arm. The background colour (green CHARGE, yellow IDLE, red BYPASS) is the DQN arm's action. The legend names the three arms and, separately, the action colours. The plain tank has no PCM, so it has no PCM line and no melt fraction.

## What happens, hour by hour (from the CSV)

| Time | Event |
|---|---|
| 00-05 | No sun. All three tanks sit at mains-water temperature (about 26-27 °C). Nothing is stored. |
| 06-09 | Sun rises (118 to 688 W/m²). Water warms. The PCM tank warms a little faster than the plain tank (46.9 against 45.1 °C at 09:00) because it holds less water (35.2 kg plus 13.4 kg of PCM against 50 kg). |
| 10 | The PCM tank's top reaches 62 °C; the plain tank 58.4 °C. |
| 11-16 | The top layers reach the 72 °C guard band. In the PCM tank the capsules melt (melt fraction 0 to 1 between 11:00 and 16:00) and absorb the surplus heat as latent heat while the water stays at 72 °C. The DQN idles at 11:00 and 13:00 (the executed action turns yellow) to stay out of the guard band. |
| 17-18 | Sun fades; the evening draw (19 kg at 17:00, 37 kg at 18:00, 46 kg at 19:00) starts. At 18:00 the top is 46.4 °C (PCM + B0), 45.9 °C (PCM + DQN) and 42.6 °C (plain). The capsules are 20 % melted, and are releasing heat. |
| 19-23 | The PCM tanks stay warmer for one more hour (32 against 27.8 °C at 19:00) and are solid again by 20:00. By 21:00 all three are back at mains temperature: the evening draw empties the small tank. |

Day totals: delivered 2.66 kWh (plain), 3.18 kWh (PCM + B0), 3.15 kWh (PCM + DQN); shield activations 98, 1709 and 628.

## Why each arm behaves as it does

- **Plain tank (arm 1):** all storage is sensible heat in 50 kg of water. It reaches the 72 °C guard band at the same hour as the PCM tank (11:00) but has no latent buffer, so the surplus heat is lost when the shield cuts the collector, and it cools fastest in the evening (27.8 °C at 19:00 against 32 °C). It delivers the least: 0.5 kWh less than the PCM tank on this day.
- **PCM + B0 (arm 2):** always charges. The capsules take surplus heat as latent heat at 60-62 °C, so the top layer stays at the shield value and the evening draw is served from the released heat. The price is more time in the guard band: 1709 shield activations (994 h over the year).
- **PCM + DQN (arm 3):** same tank, but the policy idles for one hour around the noon peak, so the water spends less time at the guard band: 628 activations instead of 1709 on this day, for 0.03 kWh less delivered (3.15 against 3.18 kWh). The idling has a cost only when the evening store is smaller; here it is about 1 %.

The 3-arm schematic video of this day is `video/o4_three_arm_day165_2023.mp4` and the 3-D one `video/o4_3d_day165_2023.mp4` (report F).
