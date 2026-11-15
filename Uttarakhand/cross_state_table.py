"""
Cross-state table of the joint O4 plan (deliverable 8): delivered energy, hold time, per kg PCM, per m2 collector,
for the three arms of each state, read from the files each state's twin wrote (nothing re-computed).

    python Uttarakhand/cross_state_table.py      ->  Uttarakhand/results_campaign/cross_state_table.csv + .png

Delivered energy is given at 45 C for every state (the Tamil Nadu / Rajasthan target; Uttarakhand's own target is 50 C,
also given). Hold = mean of the 12 starts, top layer (Rajasthan, Uttarakhand) or the single water node (Tamil Nadu).
Each row carries its replay year: the plan asks for 2023 in every state; a state whose 2023 run is not on disk is shown
with the year it has, and the table says so.
"""
import csv
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "Uttarakhand" / "results_campaign"


def rcsv(p):
    with open(p, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def hold_mean(path, arm, thr):
    v = [float(r["tau_hold_h"]) for r in rcsv(path) if r["arm"] == arm and abs(float(r["threshold_C"]) - thr) < 1e-9]
    c = [r for r in rcsv(path) if r["arm"] == arm and abs(float(r["threshold_C"]) - thr) < 1e-9 and r["censored"] in ("1", "true", "True")]
    return (sum(v) / len(v), len(c)) if v else (float("nan"), 0)


rows = []
# ---- Tamil Nadu ----
tn = ROOT / "Tamilnadu" / "export"
f = tn / "three_arm_2023.csv"
yr = 2023 if f.exists() else 2021
f = f if f.exists() else tn / "three_arm_2021.csv"
pp = json.loads((tn / "plant_params.json").read_text())
for r in rcsv(f):
    arm = r["arm"]; harm = "arm" + arm
    h45, c45 = hold_mean(tn / "hold_test_thresholds.csv", harm, 45)
    h50, c50 = hold_mean(tn / "hold_test_thresholds.csv", harm, 50)
    pcm = 0.0 if "plain" in arm else pp["m_pcm_kg"]
    d45 = float(r["delivered_kWh"])
    rows.append({"state": "Tamil Nadu", "regime": pp["regime_id"], "year": yr, "controller": "SAC", "arm": arm,
                 "tank_L": 100, "collector_m2": pp["A_coll_m2"], "pcm_kg": pcm, "measure_point": "single water node",
                 "delivered45_kWh": d45, "delivered50_kWh": "", "window45_kWh": r.get("window_kWh", ""),
                 "hold45_mean_h": h45, "hold45_censored": c45, "hold50_mean_h": h50, "hold50_censored": c50,
                 "kWh45_per_m2": d45 / pp["A_coll_m2"], "kWh45_per_kg_pcm": d45 / pcm if pcm else "",
                 "guard_band_h": r.get("guard_band_h", ""), "hard_violations": r["hard_violations"]})
# ---- Rajasthan ----
rj = ROOT / "Rajasthan" / "export_r1"
sw = rcsv(rj / "pcm_swap_study.csv")
m_rj = next(float(s["m_pcm_kg"]) for s in sw if s["o1_cluster1_rank"] == "1")
for r in rcsv(rj / "three_arm_2023.csv"):
    arm = r["arm"]; harm = "arm" + arm
    h45, c45 = hold_mean(rj / "hold_test_thresholds.csv", harm, 45)
    h50, c50 = hold_mean(rj / "hold_test_thresholds.csv", harm, 50)
    pcm = 0.0 if "plain" in arm else m_rj
    d45 = float(r["delivered_kWh"])
    rows.append({"state": "Rajasthan", "regime": 1, "year": 2023, "controller": "DQN", "arm": arm, "tank_L": 50, "collector_m2": 1.5,
                 "pcm_kg": pcm, "measure_point": "top layer", "delivered45_kWh": d45, "delivered50_kWh": "",
                 "window45_kWh": r["window_kWh"], "hold45_mean_h": h45, "hold45_censored": c45, "hold50_mean_h": h50,
                 "hold50_censored": c50, "kWh45_per_m2": d45 / 1.5, "kWh45_per_kg_pcm": d45 / pcm if pcm else "",
                 "guard_band_h": r["guard_band_h"], "hard_violations": r["hard_violations"]})
# ---- Uttarakhand ----
uk = ROOT / "Uttarakhand" / "export_r1"
J = json.loads((uk / "three_arm_2023.json").read_text())
for r in rcsv(uk / "three_arm_2023.csv"):
    arm = r["arm"]
    h45, c45 = hold_mean(uk / "hold_test_thresholds.csv", arm, 45)
    h50, c50 = hold_mean(uk / "hold_test_thresholds.csv", arm, 50)
    pcm = 0.0 if "plain" in arm else J["pcm_mass_kg"]
    d45 = float(r["delivered45_kWh"])
    rows.append({"state": "Uttarakhand", "regime": 1, "year": 2023, "controller": "PPO + smart forecast", "arm": arm, "tank_L": 50,
                 "collector_m2": J["collector_m2"], "pcm_kg": pcm, "measure_point": "top layer", "delivered45_kWh": d45,
                 "delivered50_kWh": float(r["delivered50_kWh"]), "window45_kWh": r["window45_kWh"], "hold45_mean_h": h45,
                 "hold45_censored": c45, "hold50_mean_h": h50, "hold50_censored": c50, "kWh45_per_m2": d45 / J["collector_m2"],
                 "kWh45_per_kg_pcm": d45 / pcm if pcm else "", "guard_band_h": r["guard_band_h"],
                 "hard_violations": r["hours_over_hard_limit"]})

OUT.mkdir(parents=True, exist_ok=True)
with open(OUT / "cross_state_table.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
    w.writeheader()
    w.writerows(rows)
for r in rows:
    print(f"{r['state']:12s} {r['year']} {r['arm']:16s} del45 {r['delivered45_kWh']:8.1f}  /m2 {r['kWh45_per_m2']:7.1f}  "
          f"/kgPCM {r['kWh45_per_kg_pcm'] if r['kWh45_per_kg_pcm'] == '' else round(r['kWh45_per_kg_pcm'], 1)!s:>6}  "
          f"hold45 {r['hold45_mean_h']:5.1f} h ({r['hold45_censored']} cens.)")

try:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    states = ["Tamil Nadu", "Rajasthan", "Uttarakhand"]
    arms = ["plain", "pcm_B0", "pcm_"]
    lab = ["plain + B0", "PCM + B0", "PCM + AI"]
    fig, axs = plt.subplots(1, 3, figsize=(14, 4.2))
    for k, (key, ttl) in enumerate([("kWh45_per_m2", "delivered (45 C) per m2 collector [kWh/m2]"),
                                     ("hold45_mean_h", "hold at 45 C, mean of 12 starts [h]"),
                                     ("delivered45_kWh", "delivered (45 C) [kWh/yr]")]):
        ax = axs[k]
        for j, a in enumerate(arms):
            vals = []
            for s in states:
                rr = [r for r in rows if r["state"] == s and (a in r["arm"] if a != "pcm_" else ("pcm_" in r["arm"] and "B0" not in r["arm"]))]
                vals.append(float(rr[0][key]) if rr else float("nan"))
            ax.bar([i + 0.27 * (j - 1) for i in range(3)], vals, 0.27, label=lab[j])
        ax.set_xticks(range(3))
        ax.set_xticklabels([f"{s}\n({next(r['year'] for r in rows if r['state'] == s)})" for s in states])
        ax.set_title(ttl, fontsize=10)
        ax.grid(alpha=0.3)
    axs[0].legend()
    fig.suptitle("Cross-state comparison, three arms (Tamil Nadu 100 L / 2.5 m2; Rajasthan and Uttarakhand 50 L / 1.5 m2)")
    fig.tight_layout()
    fig.savefig(OUT / "cross_state_table.png", dpi=120)
except ImportError:
    pass
print(f"wrote {OUT / 'cross_state_table.csv'}")
