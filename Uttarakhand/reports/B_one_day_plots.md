# B. One-day cycle (`one_day_cycle.m` -> `export_r1/one_day_cycle_2023.csv/.png`)

Day 105 of 2023 (15 April): the hold-test start day with the most stored energy at 18:00 in the PPO arm. Three arms on
the same weather, each from its own full-year state. Delivered to 50 C over the day: plain 3.76 kWh, PCM + B0 4.27 kWh,
PCM + PPO 4.12 kWh. Peak melt fraction: B0 1.00, PPO 0.89. PPO bypass hours: 3.

What the plot shows, hour by hour:

- **00:00-06:00.** No sun; the tanks sit near the mains temperature (about 19-20 C) after the previous evening's draw.
  All PCM is solid. Commanded ENABLE but the loop does not run (irradiance below the collector cut-off): the dotted
  "loop ran" line is 0.
- **06:00-11:00, charge.** The loop runs every hour in all three arms. The top layer passes 50 C at about 10:30. The
  morning draw (07:00-09:00) takes water out at 25-45 C, so about 1 kWh is delivered (counted up to 50 C) before 10:00.
- **11:00-13:00, the PPO bypasses.** The top layer is near 60 C and rising fast; the PPO, trained to stay away from the
  72 C guard band, switches the collector loop off (red background). B0 keeps charging and both B0 arms reach the 72 C
  shield; the in-plant shield then cuts the loop for part of each hour (dotted line drops to 25-50 %).
- **13:00-17:00.** The PPO re-enables (collector heat jumps to about 750 Wh because the bottom water is cooler); the PCM
  melts from 0 to 0.89 (PPO) against 1.00 for B0 (which melted earlier, from 11:00). The plain tank has no latent store;
  its collector heat falls to about 100 Wh/h because it is already at the shield.
- **17:00-22:00, evening draw.** The large draw (up to 52 kg/h at 19:00) empties the 50 L tank about twice over. The PCM
  arms keep the top layer above 50 C slightly longer and deliver 0.36-0.51 kWh more than the plain tank over the day; the PCM is solid
  again by about 20:00. The PPO bypasses one evening hour (21:00), when there is no sun, so it changes nothing.

Same physics finding as Tamil Nadu and Rajasthan: in this 50 L tank with a 300 L/day draw the PCM is fully solid again
by late evening, so the stored latent heat is used within the same day.
