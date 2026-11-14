# Prompt B: one-day charge / idle / bypass cycle

Source: `export/one_day_cycle_2021.png` and `.csv` (day 71 of 2021, 1-hour steps, all three arms).

## What the plot shows (six panels)

1. Water temperature, all arms, with the 72 C shield line and 45 C delivery target.
2. PCM temperature (arm 1 has no PCM, shown as a flat line at 52 C, which is a placeholder).
3. PCM melt fraction (arms 2 and 3).
4. Collector useful heat gain.
5. Hourly delivered energy.
6. Safety-shield activations per hour.

## Reading the cycle (day 71)

- **Charge (about 03:00 to 07:00):** collector gain rises to about 1.4 kW, water climbs from about 35 to 72 C in all arms.
- **Melting (about 07:00 to 10:00):** PCM melt fraction goes from 0 to 1. Arm 2 (B0) melts earlier (full by about 09:00), arm 3 (SAC) melts more slowly (full by about 10:00) because SAC interrupts charging.
- **Hot plateau (about 10:00 to 13:00):** water is held near the 72 C limit, melt fraction is 1, shield trips occur (arm 2 up to about 50 per hour, arm 3 far fewer).
- **Discharge (about 13:00 to 17:00):** hot water is drawn, the PCM re-solidifies (melt back to 0 by about 16:00) and releases heat. Delivered energy peaks at about 1.2 kWh per hour.
- **Night:** the tank settles near 38 C. The plain tank (arm 1) is about 4 C colder than the PCM arms after 15:00, which is the stored latent heat.

## Why arm 3 behaves differently

SAC pauses charging (bypass or idle) near the shield limit, around hours 7 to 12, instead of pushing into it as B0 does. That is why its shield trips are far fewer and its collector gain drops to zero then.

## Fixed on 14 Nov (after the audit)

1. The legend now shows the three arms (grey, blue, red lines) and, separately, CHARGE / IDLE / BYPASS for arm 3's background shading. The plot was re-saved and I viewed it.
2. Arm 1's flat 52 C "PCM" line is removed; the panel title says arm 1 has no PCM.
3. No numbers changed (still day 71).

## Still open

The explanation above is my reading of the plot. A written explanation of why the plain tank behaves this way is not in the README.
