# Common/ — shared three-arm study

Scripts that all three state twins can call. They contain **no state-specific
physics**: each one takes the state's own plant struct `K` and calls that
state's own `pcm_plant_hour` and `simulate_hours`, so the rule in the top-level
README ("never mix files between the state folders") still holds.

## The three arms

| Arm | Tank | Controller | Contributes |
|---|---|---|---|
| 1 | plain water, same total volume | always-enable (B0) | nobody — the conventional-heater floor |
| 2 | PCM: O1's material in O2's geometry and flow | always-enable (B0) under the in-plant shield | O1 + O2 (the Objective 2 operating point) |
| 3 | the same PCM tank | the trained O3 policy under the same shield | O1 + O2 + O3 |

## Files

| File | Deliverable |
|---|---|
| `make_plain.m` | Builds arm 1: removes the capsules and refills the volume they occupied with water, so the tank still holds its full volume. |
| `three_arm_day.m` | **(i)** One full charge / idle / bypass cycle over 2–4 days, six stacked panels, all three arms on the same weather. |
| `three_arm_edges.m` | **(ii)** The six edge cases (clear, no sunlight, rain, cold, heat wave, sensor fault) run for all three arms, not just two. |
| `three_arm_hold.m` | **(iii)** Retention: sun off, no draw, from each arm's own 18:00 state; `tau_hold` plus temperature, melt fraction and recoverable energy at 24, 36 and 48 h. |

## How to run

From the state's `matlab/` folder, with that state's export already generated:

```matlab
addpath('../../Common');

three_arm_day(1, 110, 3);                        % regime 1, from day 110, 3 days
three_arm_edges(1);
[T, TH] = three_arm_hold(1, [20 110 200 290], 72);
```

`TH` is the hold time at 30, 40, 45 and 50 °C. The extra thresholds exist so the
result can be compared with published work: Chen et al. (2025) report **31.7 h**
retention, but at a **30 °C** threshold on a 30 L/day RT35HC system, where this
project uses 45 °C (50 °C in Uttarakhand) on 300 L/day. Never compare the two
numbers without stating both criteria.

Outputs land in `export_r<k>/scenarios/` beside the existing results:
`three_arm_day_r<k>_d<day>.png`, `three_arm_edges_r<k>.csv`,
`three_arm_hold_r<k>.csv`.

## Before you trust the numbers

- **Run the state's own `validate_against_python(regime)` first.** If the twin
  no longer reproduces the Python simulator, nothing below means anything.
- **Action codes differ by state.** Uttarakhand uses 0 = BYPASS, 1 = ENABLE.
  Tamil Nadu and Rajasthan use 0 = CHARGE, 1 = IDLE, 2 = BYPASS.
  `three_arm_hold.m` picks the right bypass code from `plant_params.json`;
  check the action panel of `three_arm_day.m` against your state's README
  before reading it.
- **Tamil Nadu is single-node.** Its `pcm_plant_hour` has a different
  signature and its `K` is a plain parameter vector, not a struct, so these
  scripts need a small adapter for it. They work as written for Uttarakhand and
  Rajasthan (both 10-node).
- **`tau_hold` is censored** at the cap you pass. A mean near the cap means the
  test ran out, not that the store is unlimited.
- **Hold time is set by the climate first.** Compare arms within one regime,
  never across states: the same PCM holds ~68 h in Tamil Nadu and ~15 h in
  Uttarakhand because their mains and ambient temperatures differ.
- **Arm 3 may retain slightly less than arm 2.** The O3 reward has no term for
  overnight retention; it trades a little stored energy for far less
  guard-band time. Report it, do not hide it.
