"""
Objective 4 (Uttarakhand) -- export everything the MATLAB/Simulink digital twin needs.

Same role as Tamilnadu/export_from_python.py, adapted to the Uttarakhand Objective 3, which differs from Tamil Nadu in
three ways that matter here:

  * physics   O2's compiled MULTINODE kernel (tank_model_multinode._kernel, 10 stratified nodes, PCM per node),
              stepped hour by hour by o3/stepper.py -- not a single-node loop
  * policy    PPO (Stable-Baselines3 MlpPolicy, 15 -> 64 -> 64 -> 2, tanh, deterministic argmax), observation
              standardised with the frozen train-year normalisation -- not SAC
  * actions   Discrete(2): 0 = BYPASS (collector loop off), 1 = ENABLE (the kernel's own shield still applies)

This script freezes, from the Python side (one folder per regime):

  1. plant_params.json      -- the exact arguments O3's stepper passes to O2's kernel: parameter vector P (40),
                               node water masses, capsules per node, node loss UA, reset state (T0, h0), 24-h demand
                               curve, collector coefficients, plus the observation settings
  2. weather_<year>.csv     -- hour index, GHI, T_amb, local clock hour of the replayed year at the regime medoid
  3. ppo_actor.json         -- the PPO actor weights + the normalisation (obs_mean / obs_std) so the policy runs in a
                               plain MATLAB Function block (no ONNX / Deep Learning Toolbox needed)
  4. reference_<year>.csv   -- the Python environment's own trajectory under the deterministic PPO policy, used by
                               matlab/validate_against_python.m (O4 test-plan step 5: software-in-the-loop replay)

Year: by default 2010, an O3 TEST year. O3's one-shot locked test (M6) has already been run, so the test years are read
here post-lock through roles_o3.attach_existing_lock() with the frozen-policy fingerprint, exactly as
scripts/m6b_postlock_checks.py does. Everything produced from a test year is therefore EXPLORATORY (it does not change
the locked M6 numbers). Use --year 2021..2023 for a validation year instead (no lock needed).

Usage (with the Uttarakhand O3 venv, from anywhere):
    <o3>/.venv/Scripts/python.exe Uttarakhand/export_from_python.py --regime 1
    <o3>/.venv/Scripts/python.exe Uttarakhand/export_from_python.py --regime 0 --out Uttarakhand/export
    <o3>/.venv/Scripts/python.exe Uttarakhand/export_from_python.py --regime 2 --out Uttarakhand/export_r2
"""
import argparse
import hashlib
import json
import os
import pathlib
import sys

import numpy as np

O4_ROOT = pathlib.Path(__file__).resolve().parent
DEFAULT_O3 = pathlib.Path(os.environ.get(
    "O3_UK_ROOT", O4_ROOT.parents[1] / "solar-pcm-control--Objective3" / "uttarakhand"))


def setup_o3(o3_root: pathlib.Path):
    if not (o3_root / "o3" / "env.py").exists():
        sys.exit(f"Uttarakhand Objective 3 not found at {o3_root} (set --o3-root or O3_UK_ROOT)")
    if str(o3_root) not in sys.path:
        sys.path.insert(0, str(o3_root))


def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def attach_lock_if_test(year: int):
    """Post-lock, read-only attach to results/o3_test.lock (never creates it), as m6b_postlock_checks.py."""
    from o3 import config as o3c, frozen, roles_o3
    from o3 import o2_bridge as ob
    if roles_o3.role_of(year) != "test":
        return None
    cfg = o3c.load()
    fz = {k: frozen.load_frozen(k) for k in cfg["regimes"]["pcm"]}
    fp = ob.hashlib.sha256(json.dumps({str(k): v["fingerprint"] for k, v in fz.items()},
                                      sort_keys=True).encode()).hexdigest()
    return roles_o3.attach_existing_lock(fp)


def export_plant_params(env, regime, year, purpose, spec, lock):
    from o3.env import OBS_FIELDS, WINDOW_HOURS, GUARD_WATER_C, GUARD_PCM_C, initial_record
    from o3 import roles_o3
    c = env.case
    col = c.system_config["collector"]
    rec0 = initial_record(c)
    P = c.P
    return {
        "label": "SIMULATION-DERIVED - software-in-the-loop export" + (" - EXPLORATORY (O3 test year, post-lock)"
                                                                       if lock else ""),
        "source": "o3/stepper.py -> O2 tank_model_multinode._kernel (unchanged), arguments captured by o3/o2_bridge.py",
        "state": "uttarakhand",
        "regime_id": regime,
        "medoid": roles_o3.MEDOIDS[regime],
        "year": year,
        "year_role": purpose,
        "lock_run_id": lock["run_id"] if lock else None,
        "design": spec.get("design"),
        "selected_pcm": c.pcm,
        "reset_scenario": c.scenario,
        "n_nodes": int(len(c.m_w)),
        # --- the kernel's own argument vectors (bottom node first) ---
        "P": [float(v) for v in P],
        "P_layout": ["cp_w", "rho_w", "T_mains_C", "T_target_C", "flow_kg_s", "dt_s", "kcond_W_K", "A_cross_m2",
                     "Ts_C", "Tl_C", "L_J_kg", "cp_s", "cp_l", "wall_cp", "k_pcm", "enhancement", "k_w", "pr_w",
                     "mu_w", "t_wall_m", "k_wall", "D_cap_m", "A_cap_m2", "m_cap_kg", "band_margin_K",
                     "stiffness_factor", "n_sub_in_band", "max_substeps", "shield_enabled", "bypass_water_C",
                     "bypass_pcm_C", "max_water_C", "max_pcm_C", "stop_threshold", "c_cond"],
        "m_w_kg": [float(v) for v in c.m_w],
        "n_caps": [float(v) for v in c.n_caps],
        "loss_ua_W_K": [float(v) for v in c.loss_ua],
        "T0_C": [float(v) for v in c.T0],
        "h0_J_kg": [float(v) for v in c.h0],
        "demand_kg_by_hour": [float(v) for v in c.demand24],
        "T_mains_C": float(c.mains_C),
        "T_target_C": float(c.target_C),
        "collector": {"area_m2": float(col["area_m2"]), "fr_tau_alpha": float(col["fr_tau_alpha"]),
                      "fr_ul_W_m2K": float(col["fr_ul_W_m2K"]),
                      "I_cutoff_Wm2": float(col["min_irradiance_cutoff_Wm2"])},
        # --- observation / reward-side constants used by the twin ---
        "obs_fields": OBS_FIELDS,
        "initial_record": rec0,
        "draw_threshold_kg": float(env.cfg["observation"]["draw_threshold_kg"]),
        "minutes_since_draw_cap": float(env.cfg["observation"]["minutes_since_draw_cap"]),
        "guard_water_C": GUARD_WATER_C,
        "guard_pcm_C": GUARD_PCM_C,
        "window_hours": sorted(WINDOW_HOURS),
        "hard_limit_water_C": float(P[31]),
        "hard_limit_pcm_C": float(P[32]),
    }


def export_ppo_actor(model_path, norm):
    from stable_baselines3 import PPO
    m = PPO.load(str(model_path), device="cpu")
    pol = m.policy
    lin = [mod for mod in pol.mlp_extractor.policy_net if mod.__class__.__name__ == "Linear"]
    acts = {mod.__class__.__name__ for mod in pol.mlp_extractor.policy_net if mod.__class__.__name__ != "Linear"}
    assert len(lin) == 2 and acts == {"Tanh"}, f"unexpected PPO actor layout: {pol.mlp_extractor.policy_net}"
    W1, b1 = lin[0].weight.detach().numpy(), lin[0].bias.detach().numpy()
    W2, b2 = lin[1].weight.detach().numpy(), lin[1].bias.detach().numpy()
    Wa, ba = pol.action_net.weight.detach().numpy(), pol.action_net.bias.detach().numpy()
    return {
        "algo": "ppo",
        "source_checkpoint": str(model_path),
        "sha256": sha256_file(model_path),
        "arch": f"norm_obs({W1.shape[1]}) -> Linear{W1.shape[0]} -> tanh -> Linear{W2.shape[0]} -> tanh "
                f"-> Linear{Wa.shape[0]} (logits) -> argmax",
        "actions": "0 = BYPASS (collector loop off), 1 = ENABLE (kernel shield still applies)",
        "normalisation": "(float32(raw) - obs_mean) / obs_std, float32",
        "obs_mean": [float(v) for v in norm["obs_mean"]],
        "obs_std": [float(v) for v in norm["obs_std"]],
        "W1": W1.tolist(), "b1": b1.tolist(), "W2": W2.tolist(), "b2": b2.tolist(),
        "Wa": Wa.tolist(), "ba": ba.tolist(),
    }, m


def numpy_actor(A, x):
    """float32 replica of the exported actor (checked against model.predict for every hour)."""
    f = np.float32
    z1 = np.tanh(np.asarray(A["W1"], f) @ x + np.asarray(A["b1"], f))
    z2 = np.tanh(np.asarray(A["W2"], f) @ z1 + np.asarray(A["b2"], f))
    lg = np.asarray(A["Wa"], f) @ z2 + np.asarray(A["ba"], f)
    return int(np.argmax(lg)), lg


def run_reference(env, model, actor, year, hours):
    """Deterministic PPO rollout on UKPCMEnv (fully solid reset, deterministic demand), logged per hour."""
    obs, _ = env.reset(seed=0, options={"year": year, "scenario": "fully_solid"})
    rows, n_mismatch = [], 0
    for h in range(hours):
        raw = env._raw_obs().copy()
        a, _ = model.predict(obs, deterministic=True)
        a = int(np.asarray(a).reshape(-1)[0])
        a_np, lg = numpy_actor(actor, obs)
        n_mismatch += int(a_np != a)
        obs_in = obs.copy()
        obs, reward, term, trunc, info = env.step(a)
        rows.append({
            "hour_idx": h, "hour_of_day": info["hour_of_day"], "action": a,
            "logit0": float(lg[0]), "logit1": float(lg[1]),
            "T_top_C": info["T_top"], "T_bottom_C": info["T_bottom"], "T_mean_C": info["T_mean"],
            "T_pcm_C": info["T_pcm"], "f_melt": info["f_melt"],
            "E_del50_Wh": info["Edel_Wh"], "Q_load_Wh": info["Q_load_Wh"], "Q_unmet_Wh": info["Q_unmet_Wh"],
            "Q_coll_Wh": info["Q_coll_Wh"], "Q_loss_Wh": info["Q_loss_Wh"], "Q_pcm_Wh": info["Q_pcm_Wh"],
            "draw_kg": info["draw_kg"], "E_stored_kWh": info["E_stored_kWh"], "E_rec_kWh": info["E_rec_kWh"],
            "T_top_max_C": info["T_top_max"], "T_pcm_max_C": info["T_pcm_max"],
            "shield_water_s": info["shield_water_s"], "shield_pcm_s": info["shield_pcm_s"],
            "over_limit_s": info["over_limit_s"], "n_shield_w": info["n_shield_water"],
            "n_shield_p": info["n_shield_pcm"], "in_window": int(info["in_window"]), "reward": float(reward),
            **{f"raw{k}": float(raw[k]) for k in range(len(raw))},
            **{f"obs{k}": float(obs_in[k]) for k in range(len(obs_in))},
        })
        if term or trunc:
            break
    return rows, n_mismatch, env.stepper.residual_pct()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--regime", type=int, default=1, help="0, 1 (primary) or 2; regime 3 has no PCM controller")
    ap.add_argument("--year", type=int, default=2010)
    ap.add_argument("--hours", type=int, default=8760)
    ap.add_argument("--o3-root", default=str(DEFAULT_O3))
    ap.add_argument("--out", default=None, help="default: export (r0) / export_r1 / export_r2 next to this script")
    args = ap.parse_args()
    o3_root = pathlib.Path(args.o3_root).resolve()
    setup_o3(o3_root)
    if args.regime not in (0, 1, 2):
        sys.exit("regime must be 0, 1 or 2 (regime 3 is water-only: O2 found no PCM gain, no PPO exists)")
    out_dir = pathlib.Path(args.out) if args.out else O4_ROOT / ("export" if args.regime == 0 else f"export_r{args.regime}")
    out_dir.mkdir(parents=True, exist_ok=True)

    from o3 import roles_o3
    from o3.env import UKPCMEnv

    hand = o3_root / "results" / "o4_handoff" / f"r{args.regime}"
    spec = json.loads((hand / "hardware_interface_spec.json").read_text())
    pol_file = hand / spec["policy"]["file"]
    if sha256_file(pol_file) != spec["policy"]["sha256"]:
        sys.exit(f"{pol_file} does not match the hand-off spec hash")
    norm_file = hand / "normalisation.json"
    if sha256_file(norm_file) != spec["policy"]["normalisation_sha256"]:
        sys.exit("hand-off normalisation.json does not match the spec hash")
    if sha256_file(o3_root / "results" / f"normalisation_r{args.regime}.json") != spec["policy"]["normalisation_sha256"]:
        sys.exit("results/normalisation file differs from the hand-off copy (the env would normalise differently)")
    norm = json.loads(norm_file.read_text())

    purpose = roles_o3.role_of(args.year)
    lock = attach_lock_if_test(args.year)
    if lock:
        print(f"[export] attached read-only to O3 test lock {lock['run_id']} -> outputs are EXPLORATORY")
    env = UKPCMEnv(regime=args.regime, purpose=purpose, years=[args.year], scenarios=["fully_solid"],
                   demand_mode="deterministic")
    env.reset(seed=0, options={"year": args.year, "scenario": "fully_solid"})

    params = export_plant_params(env, args.regime, args.year, purpose, spec, lock)
    (out_dir / "plant_params.json").write_text(json.dumps(params, indent=1))
    print(f"[export] plant_params.json  regime {args.regime} ({params['medoid']})  PCM {params['selected_pcm']}  "
          f"N={params['n_nodes']} nodes  capsules={sum(params['n_caps']):.0f}  mains={params['T_mains_C']:.2f} C")

    st = env.stepper
    wx = np.column_stack([np.arange(st.n_hours), st.ghi, st.tamb, st.hod.astype(float)])
    np.savetxt(out_dir / f"weather_{args.year}.csv", wx, delimiter=",",
               header="hour_idx,GHI_Wm2,T_amb_C,local_hour", comments="", fmt="%.17g")
    print(f"[export] weather_{args.year}.csv  {st.n_hours} hours ({purpose} year)")

    actor, model = export_ppo_actor(pol_file, norm)
    (out_dir / "ppo_actor.json").write_text(json.dumps(actor))
    print(f"[export] ppo_actor.json  {actor['arch']}")

    rows, n_mis, resid = run_reference(env, model, actor, args.year, args.hours)
    keys = list(rows[0].keys())
    with open(out_dir / f"reference_{args.year}.csv", "w") as f:
        f.write(",".join(keys) + "\n")
        for r in rows:
            f.write(",".join(repr(r[k]) if isinstance(r[k], float) else str(r[k]) for k in keys) + "\n")
    E = sum(r["E_del50_Wh"] for r in rows) / 1000
    Ew = sum(r["E_del50_Wh"] for r in rows if r["in_window"]) / 1000
    sh = sum(r["shield_water_s"] + r["shield_pcm_s"] for r in rows) / 3600
    acts = np.bincount([r["action"] for r in rows], minlength=2)
    print(f"[export] reference_{args.year}.csv  {len(rows)} h  E_del50={E:.1f} kWh (window {Ew:.1f})  "
          f"shield={sh:.1f} h  actions BYPASS/ENABLE={acts.tolist()}  energy residual={resid:.2e} %")
    print(f"[export] numpy actor vs SB3 predict: {len(rows) - n_mis}/{len(rows)} identical")
    if n_mis:
        sys.exit("exported actor does not reproduce model.predict -- do not use this export")


if __name__ == "__main__":
    main()
