"""
build_campaign_config.py  --  Objective 4 improvement plan, section 5.1.

Reads (never writes) the Objective 1 / 2 / 3 files the digital-twin campaign depends on and writes ONE
JSON file, results_campaign/campaign_config.json, which is all the MATLAB campaign reads:

  o1          the Objective 1 top-3 PCMs of the regime's cluster, with every property the twin needs
              (taken from Objective 2's copy of the Objective 1 files, NOT from the Objective 1 repository)
  o2          the chosen design and the repeatability band
  o3          which controller / weights file the twin uses
  provenance  SHA-256 of every input file and the date

It stops with an error if the Objective 1 cluster count is not the expected 3 (plan section 2.3) or if the
CSV shortlist disagrees with the state config's pcm_shortlist.

Run with the project environment:
    D:\\Final Year Project\\.venv\\Scripts\\python.exe build_campaign_config.py --regime 1
"""
import argparse
import csv
import datetime
import hashlib
import json
import pathlib
import sys

import yaml

HERE = pathlib.Path(__file__).resolve().parent
O2 = HERE.parents[1] / "OBJECTIVE2" / "Objective---2" / "objective2-rajasthan"
EXPECTED_CLUSTERS = 3          # Rajasthan: 3 regimes (plan section 2.3)


def sha256(p: pathlib.Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for blk in iter(lambda: f.read(1 << 20), b""):
            h.update(blk)
    return h.hexdigest()


def read_csv(p: pathlib.Path):
    with open(p, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--regime", type=int, default=1)
    a = ap.parse_args()
    k = a.regime

    o1dir = O2 / "data" / "objective1"
    f_topk = o1dir / "mcdm_topk_by_cluster.csv"
    f_db = o1dir / "pcm_database_rajasthan.csv"
    f_cfg = O2 / "configs" / "states" / "rajasthan.yaml"
    f_sel = O2 / "results" / f"g10_selection_r{k}.json"
    f_plant = HERE / f"export_r{k}" / "plant_params.json"
    f_dqn = HERE / f"export_r{k}" / f"dqn_qnet_r{k}.json"
    f_man = o1dir / "manifest.json"
    inputs = [f_topk, f_db, f_cfg, f_sel, f_plant, f_dqn, f_man]
    for p in inputs:
        if not p.is_file():
            sys.exit(f"missing input: {p}")

    topk = read_csv(f_topk)
    clusters = sorted({int(r["cluster_id"]) for r in topk})
    if len(clusters) != EXPECTED_CLUSTERS:
        sys.exit(f"Objective 1 file has {len(clusters)} clusters, expected {EXPECTED_CLUSTERS}: superseded clustering?")

    cfg = yaml.safe_load(open(f_cfg, encoding="utf-8"))
    reg = next(r for r in cfg["regimes"] if int(r["cluster_id"]) == k)
    shortlist = reg["pcm_shortlist"]
    rows = sorted((r for r in topk if int(r["cluster_id"]) == k), key=lambda r: int(r["consensus_rank"]))
    csv_names = [r["name"] for r in rows]
    if csv_names != shortlist:
        sys.exit(f"CSV top-3 {csv_names} != state config shortlist {shortlist}")

    db = {r["name"]: r for r in read_csv(f_db)}
    sel = json.load(open(f_sel))
    chosen = sel["chosen"]

    pcms = []
    for r in rows:
        d = db[r["name"]]
        cp_s = d["Cp_solid_kJ_kgK"] or d["Cp_avg_kJ_kgK"]
        cp_l = d["Cp_liquid_kJ_kgK"] or d["Cp_avg_kJ_kgK"]
        rho = d["density_solid_kg_m3"] or d["density_liquid_kg_m3"]
        pcms.append({
            "name": r["name"],
            "consensus_rank": int(r["consensus_rank"]),
            "chosen_by_O2": r["name"] == chosen["pcm"],
            "Tm_C": float(d["Tm_C"]),
            "latent_heat_kJ_kg": float(d["latent_heat_kJ_kg"]),
            "density_solid_kg_m3": float(rho),
            "cp_solid_kJ_kgK": float(cp_s),
            "cp_liquid_kJ_kgK": float(cp_l),
            "k_W_mK": float(d["TC_W_mK"]),
            "supercooling_K": float(r["supercooling_K"]),
            "cycles_tested": float(r["cycles_tested"]),
            "mc_top3_inclusion_pct": float(r["mc_top3_inclusion_pct"]),
        })

    plant = json.load(open(f_plant))

    # Pump hydraulics (metric M7): Objective 2's own Ergun pressure drop across the capsule bed, evaluated at two flows and
    # fitted as dP = a*mdot + b*mdot^2 (viscous + inertial term). Read-only use of Objective 2's geometry code.
    sys.path.insert(0, str(O2))
    from src.design.geometry import compute_geometry          # noqa: E402
    from src.design.schema import DesignVector                 # noqa: E402
    d_cap, n_cap, m_nom, arr = plant["kernel_P"][21], plant["n_capsule"], plant["flow_kg_s"], plant["arrangement"]
    g1 = compute_geometry(DesignVector(d_cap, n_cap, m_nom, arr))
    g2 = compute_geometry(DesignVector(d_cap, n_cap, 0.5 * m_nom, arr))
    if not (g1["valid"] and g2["valid"]):
        sys.exit(f"O2 geometry rejects the design: {g1.get('reason')} / {g2.get('reason')}")
    dp1, dp2 = g1["pressure_drop_pa"], g2["pressure_drop_pa"]
    # dp1 = a m + b m^2 ; dp2 = a m/2 + b m^2/4
    b_coef = (dp1 - 2.0 * dp2) / (m_nom ** 2 * (1.0 - 0.5))
    a_coef = (dp1 - b_coef * m_nom ** 2) / m_nom
    hyd = {"source": "objective2-rajasthan/src/design/geometry.py::compute_geometry (Ergun, packed bed of spheres)",
           "dp_nominal_Pa": dp1, "pump_power_nominal_W": g1["pump_power_w"], "void_fraction": g1["void_fraction"],
           "ergun_a_Pa_per_kg_s": a_coef, "ergun_b_Pa_per_kg_s2": b_coef, "pump_efficiency": 0.6,
           "note": "pump_efficiency 0.6 = system_config_shared.yaml pump.efficiency = contract pump_efficiency"}

    out = {
        "state": "rajasthan",
        "regime": k,
        "o1": {
            "source": "objective2-rajasthan/data/objective1 (Objective 2's copy of the Objective 1 outputs)",
            "n_clusters": len(clusters),
            "cluster_id": k,
            "cluster_label": reg["label"],
            "n_points": reg["n_points"],
            "population_covered": reg["population_covered"],
            "T_mains_C": reg["T_mains_est_C"],
            "kendalls_w_cluster": reg["kendalls_w_cluster"],
            "pcms": pcms,
        },
        "o2": {
            "chosen": chosen,
            "repeatability_band": sel["band"],
            "tank_volume_L": plant["tank_volume_L"],
            "collector_m2": plant["A_coll_m2"],
            "n_capsule": plant["n_capsule"],
            "flow_kg_s": plant["flow_kg_s"],
            "arrangement": plant["arrangement"],
            "hydraulics": hyd,
        },
        "o3": {
            "controller": "DQN 17-64-64-3",
            "weights_file": f"export_r{k}/dqn_qnet_r{k}.json",
            "contract": plant["contract"],
        },
        "provenance": {
            "date": datetime.date.today().isoformat(),
            "python": sys.version.split()[0],
            "sha256": {str(p.relative_to(HERE.parents[1])): sha256(p) for p in inputs},
        },
    }
    outdir = HERE / "results_campaign"
    outdir.mkdir(exist_ok=True)
    (outdir / "campaign_config.json").write_text(json.dumps(out, indent=1), encoding="utf-8")
    print("wrote", outdir / "campaign_config.json")
    for p in pcms:
        print(f"  rank {p['consensus_rank']}  {p['name']:<22} Tm {p['Tm_C']}  L {p['latent_heat_kJ_kg']}  "
              f"MC {p['mc_top3_inclusion_pct']}  {'<- chosen by O2' if p['chosen_by_O2'] else ''}")


if __name__ == "__main__":
    main()
