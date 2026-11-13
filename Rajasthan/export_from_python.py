"""
Objective 4 (Rajasthan) -- export everything the MATLAB/Simulink digital twin needs.

Rajasthan counterpart of Tamilnadu/export_from_python.py. What is different, and why:

  * PLANT.  Rajasthan's Objective 3 environment steps Objective 2's 10-node stratified tank
    kernel (src/simulation/tank_model_multinode.py::_kernel), not Tamil Nadu's single-node tank.
    So this script exports the kernel's own parameter vector plus the per-node arrays
    (water mass, capsules, loss UA) instead of one lumped tank.
  * POLICY. The released Rajasthan controller is a DQN (Q-network 17-64-64-3, action = argmax),
    one per regime, chosen in results/gen2/gen2_selected_dqn.json. Tamil Nadu used a SAC actor.
  * OBSERVATION. 17 fields ("V3" in o3/environment/obs.py): the 13 contract fields plus the GHI of
    the next 1/2/3 hours and the next-hour draw.
  * YEAR. Tamil Nadu replayed 2011. For Rajasthan 2011-2015 belong to Objective 2's held-out test
    and 2006-2010 are Objective 3's one-shot locked test years, so neither may be re-used here.
    The replay year is a VALIDATION year (default 2023). This is a fidelity check (does the twin
    reproduce the simulator), not a new performance claim.

Files written to export_r<regime>/ :
  plant_params.json     kernel parameters, node arrays, collector, demand curve, initial state
  weather_<year>.csv    hour_idx, GHI_Wm2, T_amb_C, local_hour  (8760 rows)
  dqn_qnet_r<k>.json    Q-network weights and where they came from (path + SHA-256)
  reference_<year>.csv  the Python environment's own hourly trajectory under the deterministic DQN

Usage (any working directory; needs the Python environment Objective 3 uses):
    python export_from_python.py --regime 1
    python export_from_python.py --regime 0
    python export_from_python.py --regime 2

The Objective 3 Rajasthan tree is found at ../../solar-pcm-control--Objective3/rajasthan
(override with the environment variable O3_RAJASTHAN_ROOT). Nothing in Objective 2 or 3 is modified.
"""
import argparse
import hashlib
import json
import os
import pathlib
import sys

import numpy as np

O4_ROOT = pathlib.Path(__file__).resolve().parent
_DEFAULT_O3 = O4_ROOT.parents[1] / "solar-pcm-control--Objective3" / "rajasthan"
O3_ROOT = pathlib.Path(os.environ.get("O3_RAJASTHAN_ROOT", _DEFAULT_O3)).resolve()
if not O3_ROOT.exists():
    raise FileNotFoundError(f"Objective 3 Rajasthan tree not found at {O3_ROOT}; set O3_RAJASTHAN_ROOT")
sys.path.insert(0, str(O3_ROOT))
import config_O2  # noqa: E402  (Objective 3's path file)

config_O2.setup_paths()

from o3.environment.pcm_env import PCMEnv                        # noqa: E402
from o3.environment.gym_wrapper import OBS_LOW, OBS_HIGH          # noqa: E402
from o3.utils import weather_roles                                # noqa: E402

CONTRACT = config_O2.CONTRACT_FILE
SELECTED = O3_ROOT / "results" / "gen2" / "gen2_selected_dqn.json"

# Order of the first 35 entries of the kernel parameter vector (o2_adapter.build_runtime).
KERNEL_P_NAMES = [
    "cp_w_J_kgK", "rho_w_kg_m3", "T_mains_C", "T_deliv_C", "flow_kg_s", "dt_s", "kcond_W_K", "A_cross_m2",
    "Ts_C", "Tl_C", "L_J_kg", "cp_s_J_kgK", "cp_l_J_kgK", "wall_cp_J_kgK", "k_pcm_W_mK", "enhancement",
    "k_w_W_mK", "pr_w", "mu_w_Pa_s", "t_wall_m", "k_wall_W_mK", "D_cap_m", "A_cap_m2", "m_cap_kg",
    "band_margin_K", "stiffness_factor", "n_sub_in_band", "max_substeps", "shield_enabled",
    "bypass_wC", "bypass_pC", "max_wC", "max_pC", "stop_threshold_unused", "conduction_coefficient_c",
]


def sha256_of_file(path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def selected_model(regime_id: int) -> tuple[pathlib.Path, dict]:
    """The DQN checkpoint Objective 3 released for this regime (hourly control), with its recorded hash."""
    sel = json.loads(SELECTED.read_text())[f"r{regime_id}_60min"]
    path = O3_ROOT / "results" / "gen2" / sel["tag"] / "best_model" / "best_model.zip"
    return path, sel


def export_plant_params(env: PCMEnv, regime_id: int, T0, h0) -> dict:
    rt = env._rt
    cfg = rt.cfg
    c = cfg["collector"]
    out = {
        "source": "o3/environment/o2_adapter.py::build_runtime -> O2 src/simulation/tank_model_multinode.py::_kernel",
        "state": "rajasthan",
        "contract": env.contract.get("contract_version"),
        "regime_id": regime_id,
        "regime_label": rt.sel.get("label"),
        "selected_pcm": rt.sel["selected_pcm"],
        "n_capsule": int(rt.sel["n_capsules"]),
        "arrangement": rt.sel.get("arrangement"),
        "tank_volume_L": env.contract["fixed_system"]["tank_volume_L"],
        "m_pcm_kg": float(rt.m_pcm_node.sum()),
        "m_water_kg": float(rt.m_w.sum()),
        "Tm_C": rt.pcm_props.Tm_C,
        # kernel parameter vector, entries 0..34, and the same numbers by name
        "kernel_P": [float(v) for v in rt.P[:35]],
        "kernel_P_names": KERNEL_P_NAMES,
        # per-node arrays, node 0 = bottom, node N-1 = top
        "n_nodes": int(rt.n_nodes),
        "m_w_node_kg": rt.m_w.tolist(),
        "n_caps_node": rt.n_caps.tolist(),
        "loss_ua_node_W_K": rt.loss_ua.tolist(),
        # collector (o2_adapter.OneHourKernel.hour)
        "A_coll_m2": c["area_m2"],
        "fr_tau_alpha": c["fr_tau_alpha"],
        "fr_ul_W_m2K": c["fr_ul_W_m2K"],
        "I_cutoff_Wm2": c["min_irradiance_cutoff_Wm2"],
        # observation clip used by the gym wrapper
        "obs_low": float(OBS_LOW),
        "obs_high": float(OBS_HIGH),
        "obs_version": env.obs_version,
        # initial state = PCMEnv.reset(initial_pcm_state="solid")
        "T_init_water_C": cfg["solver"]["initial_water_temp_C"],
        "T0_node_C": [float(v) for v in T0],
        "h0_node_J_kg": [float(v) for v in h0],
        # demand (kg drawn in each local hour of day)
        "demand_kg_by_hour": rt.demand24.tolist(),
    }
    for name, v in zip(KERNEL_P_NAMES, rt.P[:35]):
        out.setdefault(name, float(v))
    return out


def export_qnet(model, model_path: pathlib.Path, sel: dict, regime_id: int) -> dict:
    lin = [m for m in model.q_net.q_net if m.__class__.__name__ == "Linear"]
    if len(lin) != 3:
        raise RuntimeError(f"expected a 3-layer Q-network, found {len(lin)} Linear layers")
    W = [l.weight.detach().numpy() for l in lin]
    b = [l.bias.detach().numpy() for l in lin]
    sha = sha256_of_file(model_path)
    return {
        "algo": "dqn",
        "regime_id": regime_id,
        "tag": sel["tag"],
        "source_checkpoint": str(model_path.relative_to(O3_ROOT)).replace("\\", "/"),
        "sha256": sha,
        "sha256_matches_gen2_selected": bool(sha == sel.get("sha256")),
        "arch": f"obs({W[0].shape[1]}) -> Linear{W[0].shape[0]} -> ReLU -> Linear{W[1].shape[0]} -> ReLU -> "
                f"Linear{W[2].shape[0]} (Q-values) -> argmax",
        "actions": "0 = CHARGE, 1 = IDLE, 2 = BYPASS",
        "W1": W[0].tolist(), "b1": b[0].tolist(),
        "W2": W[1].tolist(), "b2": b[1].tolist(),
        "W3": W[2].tolist(), "b3": b[2].tolist(),
    }


def run_reference(env: PCMEnv, model, hours: int) -> list[dict]:
    """Deterministic DQN rollout on the Python environment, logged per hour.
    Mirrors PCMGymEnv: clip the observation to [OBS_LOW, OBS_HIGH], float32, action = argmax Q."""
    import torch

    obs, _ = env.reset(year=env.year, initial_pcm_state="solid")
    obs = np.clip(obs, OBS_LOW, OBS_HIGH).astype(np.float32)
    rows = []
    for h in range(hours):
        with torch.no_grad():
            q = model.q_net(torch.as_tensor(obs[None, :])).numpy().reshape(-1)
        action = int(model.predict(obs, deterministic=True)[0])
        if action != int(np.argmax(q)):
            raise RuntimeError(f"hour {h}: model.predict gives {action} but argmax Q is {int(np.argmax(q))}")
        obs_in = obs.copy()
        obs, reward, term, trunc, info = env.step(action)
        obs = np.clip(obs, OBS_LOW, OBS_HIGH).astype(np.float32)
        rows.append({
            "hour_idx": h,
            "action": action,
            "action_executed": int(info["action_executed"]),
            "T_w_C": float(info["T_w_C"]),                  # top node (delivery node)
            "T_bottom_C": float(info["T_bottom_C"]),
            "T_mean_C": float(info["T_w_mean_C"]),
            "T_pcm_C": float(info["T_pcm_C"]),
            "f_melt": float(info["f_melt"]),
            "E_stored_kWh": float(info["E_stored_kWh"]),
            "E_rec45_kWh": float(info["E_rec45_kWh"]),
            "E_del_Wh": float(info["E_delivered_Wh"]),
            "E_unmet_Wh": float(info["E_unmet_Wh"]),
            "Q_coll_Wh": float(info["Q_collector_Wh"]),
            "n_shield_w": int(info["n_shield_water"]),
            "n_shield_p": int(info["n_shield_pcm"]),
            "n_viol": int(info["n_safety_violations"]),
            "reward": float(reward),
            "q0": float(q[0]), "q1": float(q[1]), "q2": float(q[2]),
            **{f"obs{k}": float(obs_in[k]) for k in range(len(obs_in))},
        })
        if term or trunc:
            break
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--regime", type=int, default=1, choices=[0, 1, 2])
    ap.add_argument("--year", type=int, default=2023, help="a validation year (2021-2023)")
    ap.add_argument("--hours", type=int, default=8760)
    ap.add_argument("--model", default=None, help="DQN .zip (default: the one in results/gen2/gen2_selected_dqn.json)")
    ap.add_argument("--out", default=None, help="output folder (default: export_r<regime>)")
    args = ap.parse_args()

    role = weather_roles.role_of(args.year)
    if role != "validate":
        raise SystemExit(f"year {args.year} has role '{role}'. Use a validation year (2021-2023): the test years "
                         f"are behind Objective 3's one-shot lock and 2011-2015 belong to Objective 2's held-out test.")

    out_dir = pathlib.Path(args.out) if args.out else O4_ROOT / f"export_r{args.regime}"
    out_dir.mkdir(parents=True, exist_ok=True)

    from stable_baselines3 import DQN
    model_path, sel = selected_model(args.regime)
    if args.model:
        model_path = pathlib.Path(args.model).resolve()
        sel = {**sel, "tag": model_path.parent.parent.name, "sha256": None}
    # the schedules are only needed for training; replacing them keeps older/newer SB3 versions loading quietly
    model = DQN.load(str(model_path), device="cpu",
                     custom_objects={"lr_schedule": lambda _: 0.0, "exploration_schedule": lambda _: 0.0})
    obs_dim = int(model.observation_space.shape[0])
    if obs_dim != 17:
        raise SystemExit(f"this twin is written for the 17-field V3 observation; the model has {obs_dim} inputs")

    env = PCMEnv(CONTRACT, regime_id=args.regime, year=args.year, obs_version="V3")
    T0, h0 = env._k.initial_state("solid")

    params = export_plant_params(env, args.regime, T0, h0)
    (out_dir / "plant_params.json").write_text(json.dumps(params, indent=1), encoding="utf-8")
    print(f"[export] plant_params.json  regime {args.regime}  PCM={params['selected_pcm']}  "
          f"m_w={params['m_water_kg']:.3f} kg  m_pcm={params['m_pcm_kg']:.3f} kg  N={params['n_capsule']} capsules  "
          f"{params['n_nodes']} nodes")

    wx = np.column_stack([np.arange(env._n_hours), env._ghi.astype(float), env._tamb.astype(float),
                          env._hod.astype(float)])
    np.savetxt(out_dir / f"weather_{args.year}.csv", wx, delimiter=",",
               header="hour_idx,GHI_Wm2,T_amb_C,local_hour", comments="", fmt="%.17g")
    print(f"[export] weather_{args.year}.csv  {env._n_hours} hours")

    qnet = export_qnet(model, model_path, sel, args.regime)
    (out_dir / f"dqn_qnet_r{args.regime}.json").write_text(json.dumps(qnet), encoding="utf-8")
    print(f"[export] dqn_qnet_r{args.regime}.json  {qnet['arch']}  sha256 matches gen2_selected: "
          f"{qnet['sha256_matches_gen2_selected']}")

    rows = run_reference(env, model, args.hours)
    keys = list(rows[0].keys())
    with open(out_dir / f"reference_{args.year}.csv", "w") as f:
        f.write(",".join(keys) + "\n")
        for r in rows:
            f.write(",".join(repr(r[k]) if isinstance(r[k], float) else str(r[k]) for k in keys) + "\n")
    tot_del = sum(r["E_del_Wh"] for r in rows) / 1000
    tot_sh = sum(r["n_shield_w"] + r["n_shield_p"] for r in rows)
    acts = np.bincount([r["action"] for r in rows], minlength=3)
    print(f"[export] reference_{args.year}.csv  {len(rows)} h  delivered(E_del45)={tot_del:.1f} kWh  "
          f"shield activations={tot_sh}  violations={sum(r['n_viol'] for r in rows)}  "
          f"actions CHARGE/IDLE/BYPASS={acts.tolist()}")


if __name__ == "__main__":
    main()
