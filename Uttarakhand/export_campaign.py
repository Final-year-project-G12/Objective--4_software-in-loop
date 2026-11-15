"""
Objective 4 (Uttarakhand) -- export the tanks of the joint O4 plan (plan_O4.md sections 2.1 and 2.6) for one regime.

Every tank is built by OBJECTIVE 2's OWN setup path (run_case on a one-hour frame, kernel arguments captured exactly
as o3/o2_bridge.py::build_kernel_case does), so nothing about capsule mass, wall heat capacity, node layout, displaced
water or flow is re-derived here:

  water_only            O2's water-only twin of the chosen design at the same flow (capsules removed, the volume they
                        took is water) -- arm 1 of the three-arm study
  <pcm>_f<mult>         the chosen geometry (capsule count, size, arrangement, fraction) with each of Objective 1's
                        top-3 PCMs of this cluster, at flow x0.7, x1.0, x1.3 -- the PCM-swap / flow study
                        (<O2 pcm>_f1.0 is exactly the twin's own plant)

Also written per tank: O2's Ergun pressure drop and pump power at that flow (metric M7), the PCM mass, and the
Objective 1 record of each PCM (for matlab/swap_pcm.m, which re-derives the swap and is checked against these).

Output: <export dir>/campaign_cases.json

Usage (Uttarakhand O3 venv):
    <o3>/.venv/Scripts/python.exe Uttarakhand/export_campaign.py --regime 1
"""
import argparse
import csv
import json
import os
import pathlib
import sys

O4_ROOT = pathlib.Path(__file__).resolve().parent
DEFAULT_O3 = pathlib.Path(os.environ.get(
    "O3_UK_ROOT", O4_ROOT.parents[1] / "solar-pcm-control--Objective3" / "uttarakhand"))
FLOWS = (0.7, 1.0, 1.3)


def capture_case(ob, regime, pcm, flow_mult, water_only, weather_one_hour):
    """Same as o3/o2_bridge.py::build_kernel_case, with the PCM name and flow as arguments."""
    d = ob.chosen_design(regime)
    flow = d["flow"] * flow_mult
    dv = ob.to_design(d["R_in_m"], d["fraction"], flow, d["arrangement"])
    cap = {}
    orig_k, orig_c = ob._tmm._kernel, ob._tmm._collector_arrays

    def k(*args):
        cap["args"] = args
        return orig_k(*args)

    def c(weather, cfg):
        cap["cfg"] = cfg
        return orig_c(weather, cfg)

    ob._tmm._kernel, ob._tmm._collector_arrays = k, c
    try:
        out = ob.run_case(ob.STATE, regime, None if water_only else pcm, dv, design_bounds=ob.geometry_bounds(),
                          weather=weather_one_hour, record_hourly=False,
                          system_config_overrides={"solver": {"initial_pcm_state": "solid"}}, compute_tes_metrics=False,
                          night_day_stride=0, **ob._model_kwargs())
    finally:
        ob._tmm._kernel, ob._tmm._collector_arrays = orig_k, orig_c
    if not out["valid"]:
        return {"valid": False, "reason": out["reason"], "flow_kg_s": flow}
    (_g, _tamb, _hod, _a, _b, _circ, demand24, m_w, n_caps, loss_ua, P, T0, h0, _use) = cap["args"]
    col = cap["cfg"]["collector"]
    g = out["geometry"]
    return {
        "valid": True, "pcm": None if water_only else pcm, "water_only": water_only, "flow_mult": flow_mult,
        "flow_kg_s": float(flow), "P": [float(v) for v in P], "m_w_kg": [float(v) for v in m_w],
        "n_caps": [float(v) for v in n_caps], "loss_ua_W_K": [float(v) for v in loss_ua],
        "T0_C": [float(v) for v in T0], "h0_J_kg": [float(v) for v in h0],
        "demand_kg_by_hour": [float(v) for v in demand24],
        "collector": {"area_m2": float(col["area_m2"]), "fr_tau_alpha": float(col["fr_tau_alpha"]),
                      "fr_ul_W_m2K": float(col["fr_ul_W_m2K"]), "I_cutoff_Wm2": float(col["min_irradiance_cutoff_Wm2"])},
        "pcm_mass_kg": float(sum(n_caps) * P[23]),
        "water_mass_kg": float(sum(m_w)),
        # O2 geometry.compute_hydraulics (Ergun over the capsule bed); for the water-only twin there is no bed
        "pressure_drop_pa": 0.0 if water_only else float(g["pressure_drop_pa"]),
        "pump_power_w": 0.0 if water_only else float(g["pump_power_w"]),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--regime", type=int, default=1)
    ap.add_argument("--year", type=int, default=2023, help="only used to take a one-hour weather frame (validation year)")
    ap.add_argument("--o3-root", default=str(DEFAULT_O3))
    ap.add_argument("--out", default=None)
    a = ap.parse_args()
    o3_root = pathlib.Path(a.o3_root).resolve()
    sys.path.insert(0, str(o3_root))
    from o3 import o2_bridge as ob
    from o3 import roles_o3

    k = a.regime
    out_dir = pathlib.Path(a.out) if a.out else O4_ROOT / ("export" if k == 0 else f"export_r{k}")
    ob.verify_contract()
    w1 = roles_o3.load_weather(k, a.year, roles_o3.role_of(a.year)).iloc[:1]

    # Objective 1 top-3 of this cluster, in consensus-rank order (O2's copy of the O1 files, as O2 itself uses)
    o1dir = ob.O2_ROOT / "data" / "objective1"
    rows = [r for r in csv.DictReader(open(o1dir / "mcdm_topk_by_cluster.csv", newline="", encoding="utf-8"))
            if int(r["cluster_id"]) == k]
    rows.sort(key=lambda r: int(r["consensus_rank"]))
    shortlist = ob.get_regime(ob.STATE, k)["pcm_shortlist"]
    names = [r["name"] for r in rows]
    if names != list(shortlist):
        sys.exit(f"O1 top-3 {names} != O2 state config shortlist {shortlist}")
    chosen = ob.chosen_design(k)["pcm"]
    pcms = []
    for r in rows:
        f = lambda key: float(r[key]) if r[key] not in ("", None) else None   # noqa: E731
        pcms.append({"name": r["name"], "consensus_rank": int(r["consensus_rank"]), "chosen_by_O2": r["name"] == chosen,
                     "Tm_C": f("Tm_C"), "latent_heat_kJ_kg": f("latent_heat_kJ_kg"),
                     "density_solid_kg_m3": f("density_solid_kg_m3"), "density_liquid_kg_m3": f("density_liquid_kg_m3"),
                     "cp_solid_kJ_kgK": f("Cp_solid_kJ_kgK"), "cp_liquid_kJ_kgK": f("Cp_liquid_kJ_kgK"),
                     "k_W_mK": f("TC_W_mK"), "supercooling_K": f("supercooling_K"),
                     "any_property_imputed": r["any_property_imputed"]})

    cases = {"water_only": capture_case(ob, k, None, 1.0, True, w1)}
    for p in pcms:
        for fm in FLOWS:
            key = f"{p['name']}_f{fm:.1f}"
            cases[key] = capture_case(ob, k, p["name"], fm, False, w1)
            c = cases[key]
            print(f"[campaign] {key:28s} " + (f"PCM {c['pcm_mass_kg']:.2f} kg  water {c['water_mass_kg']:.2f} kg  "
                                             f"dp {c['pressure_drop_pa']:.1f} Pa  pump {c['pump_power_w']:.3f} W"
                                             if c["valid"] else f"INVALID ({c['reason']})"))
    wo = cases["water_only"]
    print(f"[campaign] water_only                   water {wo['water_mass_kg']:.2f} kg")

    out = {"regime": k, "medoid": roles_o3.MEDOIDS[k], "state": "uttarakhand", "chosen_pcm": chosen,
           "design": {x: ob.chosen_design(k)[x] for x in ("R_in_m", "fraction", "flow", "arrangement", "N")},
           "flow_multipliers": list(FLOWS), "o1_top3": pcms,
           "source": "o2_frozen run_case (O2's own setup), kernel arguments captured as o3/o2_bridge.build_kernel_case",
           "cases": cases}
    (out_dir / "campaign_cases.json").write_text(json.dumps(out, indent=1))
    print(f"[campaign] wrote {out_dir / 'campaign_cases.json'}")


if __name__ == "__main__":
    main()
