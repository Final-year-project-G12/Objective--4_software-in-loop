# Objective 4 — Software-in-the-loop validation

Objective 4 checks the trained Objective 3 controller outside its training code: a MATLAB digital
twin of the PCM solar water heater (weather → sensors → observation → policy → safety interlock →
pump/valve → plant) is replayed against the Python simulator and then stressed with six edge cases
(clear, no sunlight, rain/cloud, low temperature, heat wave, sensor fault).

This is emulated validation. No physical rig was used.

| Folder | State | Plant | Controller | Start here |
|---|---|---|---|---|
| [`Tamilnadu/`](Tamilnadu/) | Tamil Nadu | single water node, 100 L / 2.5 m² | SAC | [`Tamilnadu/README.md`](Tamilnadu/README.md) |
| [`Rajasthan/`](Rajasthan/) | Rajasthan | 10-node stratified tank, 50 L / 1.5 m² | DQN | [`Rajasthan/README.md`](Rajasthan/README.md) |
| [`Uttarakhand/`](Uttarakhand/) | Uttarakhand | 10-node stratified tank, 50 L / 1.5 m², 50 °C target | PPO | [`Uttarakhand/README.md`](Uttarakhand/README.md) |

The three folders follow a similar layout (export script, `matlab/` sources, one export folder per
regime, reports) but not the same code, because the states' Objective 3 environments differ. Never mix files between them. Rajasthan also carries a SAC arm in all three regimes.

## What each state has

| Output | Tamil Nadu | Rajasthan | Uttarakhand |
|---|---|---|---|
| Twin validated against the Python simulator | yes (retrained SAC, smart forecast) | yes, full year, 3 regimes | yes, full year, regimes 0–2 |
| Three-arm study (plain tank, PCM + always-charge, PCM + learned controller) | yes | yes | yes |
| Edge cases (clear, no sunlight, rain/cloud, low temperature, heat wave, sensor fault) | yes, plus dead/stuck pyranometer | yes, plus dead pyranometer | yes (regime 1) |
| 72 h retention / hold test | yes | yes | yes |
| Showcase videos | schematic: normal day, heat wave, rain/cloud, sensor fault (`video/showcase/`) | same four schematics (`video/showcase/`), SAC variant in `video/showcase_sac/` | story videos (`video/o4_story_*.mp4`) |
| Simulink model | not for the retrained SAC | yes | yes (one week) |
| Generated C code of the controller | not for the retrained SAC | yes (DQN, 9 files) | yes (PPO, 9 files) |
| Python cross-check that needs no MATLAB | no | yes (`sil_python_mirror.py`) | no |

Shared material is in [`Common/`](Common/).

Main findings: the twin matches the Python simulator to about 1e-13 °C with 100% identical actions; no hard limit is broken in any test; the learned controllers trade a little delivery for far fewer safety-guard activations; a dead sun sensor is not caught by the fail-safe (Rajasthan: 701 against 430 guard hours); and Uttarakhand's PPO fails to bypass when mains temperature drifts from its training value.

## Requirements

- Python environment used by Objective 3 (NumPy, numba, PyTorch, Stable-Baselines3) for the export step.
- MATLAB for the twin. Base MATLAB runs the scenarios, validation and animations. Simulink and
  Stateflow are needed only for the `.slx` model, MATLAB Coder only for the C code.
- The Objective 2 and Objective 3 repositories next to this one; they are read, never modified.

## Project links

| Part | Repository |
|---|---|
| Objective 1: PCM selection | [https://github.com/Final-year-project-G12/PCM-Selection-ML-model](https://github.com/Final-year-project-G12/PCM-Selection-ML-model) |
| Objective 2: design optimisation | [https://github.com/Final-year-project-G12/Objective---2](https://github.com/Final-year-project-G12/Objective---2) |
| Objective 3: DRL controller | [https://github.com/Final-year-project-G12/solar-pcm-control--Objective3](https://github.com/Final-year-project-G12/solar-pcm-control--Objective3) |
| Objective 4: software-in-the-loop | [https://github.com/Final-year-project-G12/Objective--4_software-in-loop](https://github.com/Final-year-project-G12/Objective--4_software-in-loop) |
| Documentation portal | [https://github.com/Final-year-project-G12/Documentation-Portal](https://github.com/Final-year-project-G12/Documentation-Portal) · [live site](https://Final-year-project-G12.github.io/Documentation-Portal) |
| Objective 3 live dashboard | [Streamlit app](https://solar-pcm-control--objective3-ohrrdnt9lzp2fgngxmmjdb.streamlit.app/) |
