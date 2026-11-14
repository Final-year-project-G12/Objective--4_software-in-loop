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

The two folders have the same layout (export script, `matlab/` sources, one export folder per
regime, three documents) but not the same code, because the two states' Objective 3 environments
differ. Never mix files between them.

## What each state has

| Output | Tamil Nadu | Rajasthan |
|---|---|---|
| Twin validated against the Python simulator | yes | yes (full year, 3 regimes) |
| Six scenarios: plots and summary table | yes (regime 0, 3 arms, plus dead/stuck pyranometer) | yes (3 regimes) |
| Animation video | yes (`Tamilnadu/video/`) | yes (regime 1) |
| Simulink block-diagram model | no (removed: it was built for the pre-retrain controller) | no (Simulink not installed where Rajasthan was run) |
| Generated C code of the controller | no (removed: it was for the pre-retrain controller) | no (MATLAB Coder not installed where Rajasthan was run) |
| Python cross-check that needs no MATLAB | no | yes (`sil_python_mirror.py`) |

## Requirements

- Python environment used by Objective 3 (NumPy, numba, PyTorch, Stable-Baselines3) for the export step.
- MATLAB for the twin. Base MATLAB runs the scenarios, validation and animations. Simulink and
  Stateflow are needed only for the `.slx` model, MATLAB Coder only for the C code.
- The Objective 2 and Objective 3 repositories next to this one; they are read, never modified.
