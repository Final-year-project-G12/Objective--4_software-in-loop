"""
Phase O3-10 -- Export everything the MATLAB/Simulink digital twin needs.

Objective 4 cannot get hardware this term, so the embedded deployment is
demonstrated as a Simulink software-/processor-in-the-loop twin of the same
plant the policy was trained on. This script freezes, from the Python side:

  1. plant_params.json    -- every number _run_one_hour() in pcm_env.py uses
                             (tank, PCM, collector, shield, solver, demand curve)
  2. weather_<year>.csv   -- the held-out test-year weather (hour index, GHI,
                             T_amb, local hour) that the Simulink From Workspace
                             block replays
  3. sac_actor_r0.json    -- the SAC actor weights (15-256-256-1 MLP, tanh; V3 observation, smart forecast) so
                             the policy runs in a plain MATLAB Function block
                             with no ONNX support package needed
  4. reference_<year>.csv -- the Python environment's own trajectory under the
                             deterministic SAC policy, used by
                             matlab/validate_v3_full.m to prove the
                             Simulink twin reproduces the simulator
                             (O4 test-plan step 4: SIL replay).

Usage:
    python objective4_software_in_loop/export_from_python.py --regime 0 --year 2011 --hours 8760
"""
import argparse
import json
import pathlib
import sys

import numpy as np

O4_ROOT = pathlib.Path(__file__).resolve().parent
REPO_ROOT = O4_ROOT.parent                      # objective3 repo (policy, contract)
_O2_ROOT = REPO_ROOT.parent / "objective2_design_optimization"
for _p in (str(_O2_ROOT), str(REPO_ROOT)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from o3.environment.pcm_env import PCMEnv                          # noqa: E402
from o3.environment.gym_wrapper import PCMContinuousGymEnv, OBS_LOW, OBS_HIGH  # noqa: E402

CONTRACT = REPO_ROOT / "contracts" / "obj3_environment_contract_tamilnadu_v3.json"
OUT_DIR = O4_ROOT / "export"


def export_plant_params(env: PCMEnv, regime_id: int) -> dict:
    cfg = env.system_config
    p = env.pcm_props
    d = env.design
    solver = cfg["solver"]
    shield = cfg.get("safety_shield", {})
    demand_24 = [env._demand_model.draw_mass_kg_for_hour(h) for h in range(24)]

    return {
        "source": "o3/environment/pcm_env.py::_run_one_hour (frozen O2 physics)",
        "contract": env.contract.get("contract_version"),
        "regime_id": regime_id,
        "selected_pcm": env.contract["static_design_per_regime"][regime_id]["selected_pcm"],
        # water node
        "m_w_kg": env._m_w,
        "cp_w_J_kgK": cfg["water"]["cp_J_kgK"],
        "rho_w_kg_m3": cfg["water"]["density_kg_m3"],
        "k_w_W_mK": cfg["water"]["conductivity_W_mK"],
        "pr_w": cfg["water"]["prandtl"],
        "U_tank_W_m2K": cfg["tank"]["U_tank_W_m2K"],
        "A_tank_m2": d.tank_surface_area_m2,
        "T_mains_C": env.mains_temp_C,
        "T_deliv_C": cfg["delivery"]["target_temp_C"],
        "T_init_water_C": solver["initial_water_temp_C"],
        # collector
        "A_coll_m2": cfg["collector"]["area_m2"],
        "fr_tau_alpha": cfg["collector"]["fr_tau_alpha"],
        "fr_ul_W_m2K": cfg["collector"]["fr_ul_W_m2K"],
        "I_cutoff_Wm2": cfg["collector"]["min_irradiance_cutoff_Wm2"],
        # PCM node (enthalpy method, wall lumped in)
        "m_pcm_kg": env._m_pcm,
        "Tm_C": p.Tm_C,
        "half_width_K": p.melting_half_width_K,
        "L_J_kg": p.latent_heat_J_kg,
        "cp_s_J_kgK": p.cp_solid_J_kgK,
        "cp_l_J_kgK": p.cp_liquid_J_kgK,
        "k_pcm_W_mK": p.conductivity_W_mK,
        "wall_cp_J_kgK": p.wall_cp_J_kgK,
        "enhancement": cfg["pcm_integration"]["liquid_convection_enhancement"],
        # capsules / UA
        "n_capsule": d.n_capsule,
        "D_cap_m": d.capsule_diameter_m,
        "A_cap_m2": d.capsule_area_m2,
        "t_wall_m": d.capsule_wall_thickness_m,
        "k_wall_W_mK": cfg["pcm_integration"]["capsule_wall_conductivity_W_mK"],
        "v_sup_m_s": env._superficial_v,
        "flow_kg_s": d.flow_rate_kg_s,
        # safety
        "max_wC": cfg["safety"]["max_water_temp_C"],
        "max_pC": cfg["safety"]["max_pcm_temp_C"],
        "shield_enabled": int(bool(shield.get("enabled", True))),
        "bypass_wC": shield.get("bypass_water_C", cfg["safety"]["max_water_temp_C"] - 3.0),
        "bypass_pC": shield.get("bypass_pcm_C", cfg["safety"]["max_pcm_temp_C"] - 3.0),
        # solver
        "dt_s": solver["timestep_s"],
        "n_sub_in_band": solver["substeps_in_melt_band"],
        "band_margin_K": solver["melt_band_margin_K"],
        "stiffness_factor": 0.5,
        "max_substeps": 60,
        # observation clip used by the gym wrapper
        "obs_low": float(np.min(OBS_LOW)),
        "obs_high": float(np.max(OBS_HIGH)),
        # demand
        "demand_kg_by_hour": demand_24,
    }


def export_sac_actor(model_path: pathlib.Path, obs_version: str, forecast_mode: str):
    from stable_baselines3 import SAC
    m = SAC.load(str(model_path), device="cpu")
    actor = m.policy.actor
    lin = [mod for mod in actor.latent_pi if mod.__class__.__name__ == "Linear"]
    W1, b1 = lin[0].weight.detach().numpy(), lin[0].bias.detach().numpy()
    W2, b2 = lin[1].weight.detach().numpy(), lin[1].bias.detach().numpy()
    Wm, bm = actor.mu.weight.detach().numpy(), actor.mu.bias.detach().numpy()
    return {
        "algo": "sac",
        "source_checkpoint": str(model_path),
        "obs_version": obs_version,
        "forecast_mode": forecast_mode,
        "obs_dim": int(W1.shape[1]),
        "arch": f"obs({W1.shape[1]}) -> Linear256 -> ReLU -> Linear256 -> ReLU -> Linear1 -> tanh -> bin",
        "bins": "a < -1/3 -> CHARGE(0); -1/3 <= a <= 1/3 -> IDLE(1); a > 1/3 -> BYPASS(2)",
        "W1": W1.tolist(), "b1": b1.tolist(),
        "W2": W2.tolist(), "b2": b2.tolist(),
        "Wmu": Wm.tolist(), "bmu": bm.tolist(),
    }, m


def run_reference(env: PCMEnv, model, hours: int) -> list[dict]:
    """Deterministic SAC rollout on the Python environment, logged per hour.
    Mirrors PCMContinuousGymEnv exactly: clip obs to [OBS_LOW, OBS_HIGH],
    float32, deterministic tanh(mu) action, binned to CHARGE/IDLE/BYPASS."""
    obs = env.reset(year=env.year, initial_pcm_state="solid")
    if isinstance(obs, tuple):
        obs = obs[0]
    obs = np.clip(obs, OBS_LOW, OBS_HIGH).astype(np.float32)
    rows = []
    for h in range(hours):
        a_cont, _ = model.predict(obs, deterministic=True)
        a_cont = float(np.asarray(a_cont).reshape(-1)[0])
        action = PCMContinuousGymEnv._to_discrete(a_cont)
        obs_in = obs.copy()
        obs, reward, term, trunc, info = env.step(action)
        obs = np.clip(obs, OBS_LOW, OBS_HIGH).astype(np.float32)
        rows.append({
            "hour_idx": h,
            "a_cont": a_cont,
            "action": action,
            "action_executed": info["action_executed"],
            "T_w_C": info["T_w_C"],
            "T_pcm_C": info["T_pcm_C"],
            "f_melt": info["f_melt"],
            "E_del_Wh": info["E_delivered_Wh"],
            "E_unmet_Wh": info["E_unmet_Wh"],
            "n_shield_w": info["n_shield_water"],
            "n_shield_p": info["n_shield_pcm"],
            "n_viol": info["n_safety_violations"],
            "reward": float(reward),
            **{f"obs{k}": float(obs_in[k]) for k in range(len(obs_in))},
        })
        if term or trunc:
            break
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--regime", type=int, default=0)
    ap.add_argument("--year", type=int, default=2011)
    ap.add_argument("--hours", type=int, default=8760)
    ap.add_argument("--model", default=str(REPO_ROOT / "results" / "sac" / "r0_smartfc" / "best_model" / "best_model.zip"))
    ap.add_argument("--forecast-mode", default="smart", choices=["perfect", "smart", "none"],
                     help="must match the forecast_mode the --model checkpoint was TRAINED with (default: smart, the deployed variant per CORRECTIONS_OBJECTIVE3.md O3-5/O3-6)")
    ap.add_argument("--out", default=str(OUT_DIR), help="output folder (export_r1 / export_r2 for other regimes)")
    args = ap.parse_args()
    out_dir = pathlib.Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    from stable_baselines3 import SAC
    obs_dim = int(SAC.load(args.model, device="cpu").observation_space.shape[0])
    # obs_dim==15 is the V2/V3 15-dim shape (V1 + 3h GHI forecast + next-hour
    # demand); V3 is that same shape run with forecast_mode="smart" (the
    # realistic, deployable forecast) rather than V2's "perfect" look-ahead.
    # The export MUST pass the same forecast_mode the checkpoint was trained
    # with, or the reference rollout silently measures the wrong policy.
    obs_version = "V3" if obs_dim == 15 else "V1"
    fmode = args.forecast_mode if obs_dim == 15 else "none"
    env = PCMEnv(CONTRACT, regime_id=args.regime, year=args.year,
                 obs_version=obs_version, forecast_mode=fmode)
    print(f"[export] policy observation size = {obs_dim} ({obs_version}, forecast_mode={fmode})")

    params = export_plant_params(env, args.regime)
    (out_dir / "plant_params.json").write_text(json.dumps(params, indent=1))
    print(f"[export] plant_params.json  m_w={params['m_w_kg']:.3f} kg  m_pcm={params['m_pcm_kg']:.3f} kg  "
          f"n={params['n_capsule']} D={params['D_cap_m']*1e3:.1f} mm")

    w = env._weather
    has_clearsky = "GHI_clearsky_Wm2" in w.columns
    cols = [
        np.arange(len(w)),
        w["GHI_Wm2"].to_numpy(float),
        w["T_amb_C"].to_numpy(float),
        w["local_hour"].to_numpy(float) if "local_hour" in w.columns else np.arange(len(w)) % 24,
    ]
    header = "hour_idx,GHI_Wm2,T_amb_C,local_hour"
    if has_clearsky:
        cols.append(w["GHI_clearsky_Wm2"].to_numpy(float))
        header += ",GHI_clearsky_Wm2"
    wx = np.column_stack(cols)
    np.savetxt(out_dir / f"weather_{args.year}.csv", wx, delimiter=",",
               header=header, comments="", fmt="%.10g")
    print(f"[export] weather_{args.year}.csv  {len(w)} hours  clearsky={'yes' if has_clearsky else 'NO -- V3 forecast cannot be replicated in MATLAB'}")

    actor, model = export_sac_actor(pathlib.Path(args.model), obs_version, fmode)
    (out_dir / "sac_actor_r0.json").write_text(json.dumps(actor))
    print(f"[export] sac_actor_r0.json  layers {obs_dim}->256->256->1")

    rows = run_reference(env, model, args.hours)
    keys = list(rows[0].keys())
    with open(out_dir / f"reference_{args.year}.csv", "w") as f:
        f.write(",".join(keys) + "\n")
        for r in rows:
            f.write(",".join(repr(r[k]) if isinstance(r[k], float) else str(r[k]) for k in keys) + "\n")
    tot_del = sum(r["E_del_Wh"] for r in rows) / 1000
    tot_sh = sum(r["n_shield_w"] + r["n_shield_p"] for r in rows)
    acts = np.bincount([r["action"] for r in rows], minlength=3)
    print(f"[export] reference_{args.year}.csv  {len(rows)} h  delivered={tot_del:.1f} kWh  "
          f"shields={tot_sh}  actions CHARGE/IDLE/BYPASS={acts.tolist()}")


if __name__ == "__main__":
    main()
