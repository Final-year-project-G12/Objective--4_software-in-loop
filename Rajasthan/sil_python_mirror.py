"""
Objective 4 (Rajasthan) -- Python mirror of the MATLAB twin.

Why this file exists: the twin in matlab/ needs MATLAB to run. This script is a statement-by-
statement Python copy of those .m files (same parameter vector, same function split, same
variable names). It reads ONLY the files in export_r<regime>/ -- it does not import the
Objective 2 simulator or the Objective 3 environment -- so it answers two questions without MATLAB:

  1. Are the exported files enough to rebuild the plant and the controller, and is the algorithm
     written in the .m files the right one?  (checks A, B, C against reference_<year>.csv)
  2. What do the six edge-case scenarios give for Rajasthan?  (scenario table + plots)

What it does NOT prove: that the .m files themselves run without a typo. Only MATLAB can show
that (matlab/run_scenarios.m repeats the same checks and writes export_r<k>/scenarios/).
Everything written here goes to export_r<k>/python_mirror/ so it cannot be mistaken for
MATLAB output.

    python sil_python_mirror.py --regime 1            # checks + scenarios + plots
    python sil_python_mirror.py --regime 1 --no-plots

Needs numpy; uses numba if it is installed (about 40x faster), matplotlib for the plots.
"""
import argparse
import csv
import json
import pathlib

import numpy as np

try:
    from numba import njit
except Exception:                                  # pragma: no cover - plain Python fallback
    def njit(*a, **k):
        if len(a) == 1 and callable(a[0]):
            return a[0]
        return lambda f: f

HERE = pathlib.Path(__file__).resolve().parent
N = 10


# ----------------------------------------------------------------------------------------
# load_twin_params.m
# ----------------------------------------------------------------------------------------
def load_twin_params(export_dir: pathlib.Path, year: int) -> dict:
    pp = json.loads((export_dir / "plant_params.json").read_text(encoding="utf-8"))
    assert pp["n_nodes"] == 10 and len(pp["kernel_P"]) == 35
    P = np.zeros(80)                               # P[k-1] here == P(k) in MATLAB
    P[0:35] = pp["kernel_P"]
    P[35], P[36], P[37], P[38] = pp["A_coll_m2"], pp["fr_tau_alpha"], pp["fr_ul_W_m2K"], pp["I_cutoff_Wm2"]
    P[39], P[40], P[41], P[42] = pp["obs_low"], pp["obs_high"], pp["T_init_water_C"], pp["n_nodes"]
    P[50:60] = pp["m_w_node_kg"]
    P[60:70] = pp["n_caps_node"]
    P[70:80] = pp["loss_ua_node_W_K"]
    W = np.loadtxt(export_dir / f"weather_{year}.csv", delimiter=",", skiprows=1)[:, :4]
    q = json.loads((export_dir / f"dqn_qnet_r{pp['regime_id']}.json").read_text(encoding="utf-8"))
    tw = {
        "P": P, "params": pp, "regime": pp["regime_id"], "demand24": np.array(pp["demand_kg_by_hour"], float),
        "W": W, "N": len(W), "T0": np.array(pp["T0_node_C"], float), "h0": np.array(pp["h0_node_J_kg"], float),
        "W1": np.array(q["W1"], np.float32), "b1": np.array(q["b1"], np.float32),
        "W2": np.array(q["W2"], np.float32), "b2": np.array(q["b2"], np.float32),
        "W3": np.array(q["W3"], np.float32), "b3": np.array(q["b3"], np.float32),
        "qnet_info": {k: v for k, v in q.items() if k not in ("W1", "b1", "W2", "b2", "W3", "b3")},
    }
    ref_file = export_dir / f"reference_{year}.csv"
    tw["ref"] = None
    if ref_file.exists():
        with open(ref_file) as f:
            names = f.readline().strip().split(",")
        data = np.loadtxt(ref_file, delimiter=",", skiprows=1)
        tw["ref"] = {n: data[:, i] for i, n in enumerate(names)}
    return tw


# ----------------------------------------------------------------------------------------
# pcm_plant_hour.m and its local functions, pcm_derive_state.m
# ----------------------------------------------------------------------------------------
@njit
def pcm_h_of_T(T, Ts, Tl, L, cps, cpl, x):
    hs = (cps + x) * Ts
    span = L + x * (Tl - Ts)
    if T < Ts:
        return (cps + x) * T
    if T <= Tl:
        return hs + span * (T - Ts) / (Tl - Ts)
    return hs + span + (cpl + x) * (T - Tl)


@njit
def pcm_T_f_of_h(hh, Ts, Tl, L, cps, cpl, x):
    hs = (cps + x) * Ts
    span = L + x * (Tl - Ts)
    hl = hs + span
    if hh < hs:
        return hh / (cps + x), 0.0
    if hh <= hl:
        f = (hh - hs) / span if span > 0 else 1.0
        f = min(max(f, 0.0), 1.0)
        return Ts + f * (Tl - Ts), f
    return Tl + (hh - hl) / (cpl + x), 1.0


@njit
def ua_node(n, d, area, v, f, rho, kw, pr, mu, wall_t, wall_k, k_pcm, enh, c_cond):
    if n <= 0:
        return 0.0
    re = max(rho * v * d / mu, 1e-6)
    nu = 2.0 + 1.1 * re ** 0.6 * pr ** (1.0 / 3.0)
    hw = nu * kw / d
    k_eff = k_pcm * enh if f >= 0.5 else k_pcm
    r_in = d / 2.0 - wall_t
    a_in = 4.0 * np.pi * r_in * r_in
    r_tot = 1.0 / (hw * area) + wall_t / (wall_k * area) + r_in / (c_cond * k_eff * a_in)
    return n / r_tot


@njit
def solve_step(T, Tp, UA, m_w, loss_ua, tamb, cp, mains, mdot_d, mdot_c, circ, k_ret, a, b, kcond, dts):
    A = np.zeros((N, N))
    r = np.zeros(N)
    ext_in = np.zeros(N)
    ext_out = np.zeros(N)
    ext_in[0] += mdot_d
    ext_out[N - 1] += mdot_d
    if circ:
        ext_out[0] += mdot_c
        ext_in[k_ret] += mdot_c
    F = np.zeros(N - 1)
    net = 0.0
    for i in range(N - 1):
        net += ext_in[i] - ext_out[i]
        F[i] = net
    for i in range(N):
        A[i, i] += m_w[i] * cp / dts + loss_ua[i] + UA[i] + ext_out[i] * cp
        r[i] += m_w[i] * cp / dts * T[i] + loss_ua[i] * tamb + UA[i] * Tp[i]
        if i == 0:
            r[0] += mdot_d * cp * mains
        if i > 0:
            Fb = F[i - 1]
            if Fb > 0:
                A[i, i - 1] -= Fb * cp
            else:
                A[i, i] -= Fb * cp
            A[i, i] += kcond
            A[i, i - 1] -= kcond
        if i < N - 1:
            Fa = F[i]
            if Fa > 0:
                A[i, i] += Fa * cp
            else:
                A[i, i + 1] += Fa * cp
            A[i, i] += kcond
            A[i, i + 1] -= kcond
    if circ:
        A[k_ret, 0] -= (mdot_c * cp - b)
        r[k_ret] += a
    return np.linalg.solve(A, r)


@njit
def mix_inversions(T, m_w):
    start = np.zeros(N, dtype=np.int64)
    mass = np.zeros(N)
    en = np.zeros(N)
    nb = 0
    for j in range(N):
        start[nb] = j
        mass[nb] = m_w[j]
        en[nb] = m_w[j] * T[j]
        nb += 1
        while nb > 1 and en[nb - 2] / mass[nb - 2] > en[nb - 1] / mass[nb - 1] + 1e-12:
            mass[nb - 2] += mass[nb - 1]
            en[nb - 2] += en[nb - 1]
            nb -= 1
    for k in range(nb):
        last = start[k + 1] if k + 1 < nb else N
        tm = en[k] / mass[k]
        for j in range(start[k], last):
            T[j] = tm


@njit
def pcm_derive_state(T, h, P):
    cp, mains, target = P[0], P[2], P[3]
    Ts, Tl, L, cps, cpl, x = P[8], P[9], P[10], P[11], P[12], P[13]
    m_cap = P[23]
    m_w, n_caps = P[50:60], P[60:70]
    n_caps_tot = 0.0
    m_w_tot = 0.0
    for i in range(N):
        n_caps_tot += n_caps[i]
        m_w_tot += m_w[i]
    has_pcm = n_caps_tot > 0
    m_pcm_tot = n_caps_tot * m_cap
    h_mains = pcm_h_of_T(mains, Ts, Tl, L, cps, cpl, x)
    h_target = pcm_h_of_T(target, Ts, Tl, L, cps, cpl, x)
    t_mean = e_rel = e_rec = tp_mean = fm = 0.0
    for i in range(N):
        t_mean += T[i] * m_w[i] / m_w_tot
        e_rel += m_w[i] * cp * (T[i] - mains)
        e_rec += m_w[i] * cp * max(T[i] - target, 0.0)
        if n_caps[i] > 0:
            m_pcm_i = n_caps[i] * m_cap
            Tp_i, f_i = pcm_T_f_of_h(h[i], Ts, Tl, L, cps, cpl, x)
            e_rel += m_pcm_i * (h[i] - h_mains)
            e_rec += m_pcm_i * max(h[i] - h_target, 0.0)
            tp_mean += Tp_i * m_pcm_i / m_pcm_tot
            fm += f_i * m_pcm_i / m_pcm_tot
    if not has_pcm:
        tp_mean = t_mean
    s = np.zeros(7)
    s[0], s[1], s[2], s[3], s[4], s[5], s[6] = T[N - 1], T[0], t_mean, tp_mean, fm, e_rel / 3.6e6, e_rec / 3.6e6
    return s


@njit
def pcm_plant_hour(I_t, T_amb, draw_kg, action, T_in, h_in, P):
    T = T_in.copy()
    h = h_in.copy()
    cp, rho_w, mains, target = P[0], P[1], P[2], P[3]
    mdot_c, dt, kcond, A_cross = P[4], P[5], P[6], P[7]
    Ts, Tl, L, cps, cpl, x = P[8], P[9], P[10], P[11], P[12], P[13]
    k_pcm, enh, kw, pr, mu = P[14], P[15], P[16], P[17], P[18]
    wall_t, wall_k, d, area_cap, m_cap = P[19], P[20], P[21], P[22], P[23]
    margin, stiff_sf, n_band, max_sub = P[24], P[25], int(round(P[26])), int(round(P[27]))
    shield, byp_w, byp_p, max_w, max_p = P[28] > 0.5, P[29], P[30], P[31], P[32]
    c_cond = P[34]
    A_coll, fr_ta, fr_ul, I_cut = P[35], P[36], P[37], P[38]
    m_w, n_caps, loss_ua = P[50:60], P[60:70], P[70:80]
    CHARGE, BYPASS = 0, 2

    if action == CHARGE and I_t > I_cut:
        a_c = A_coll * (fr_ta * I_t + fr_ul * T_amb)
        b_c = A_coll * fr_ul
        circ_allowed = True
    else:
        a_c, b_c, circ_allowed = 0.0, 0.0, False

    n_caps_tot = 0.0
    for i in range(N):
        n_caps_tot += n_caps[i]
    has_pcm = n_caps_tot > 0
    m_pcm_node = n_caps * m_cap
    cp_min_eff = min(cps, cpl) + x

    Tp = np.zeros(N)
    f = np.zeros(N)
    for i in range(N):
        if n_caps[i] > 0:
            Tp[i], f[i] = pcm_T_f_of_h(h[i], Ts, Tl, L, cps, cpl, x)
        else:
            h[i] = 0.0
            Tp[i] = T[i]

    nsteps = int(round(3600.0 / dt))
    mdot_d = draw_kg / 3600.0
    step_draw = draw_kg / nsteps
    hq_c = hq_un = h_draw = h_edel = 0.0
    t_top_max, t_p_max = -1e9, -1e9
    n_sw = n_sp = n_viol = 0
    shield_s = 0.0

    for st in range(nsteps):
        in_band = False
        if has_pcm:
            for i in range(N):
                if n_caps[i] > 0 and Ts - margin <= Tp[i] <= Tl + margin:
                    in_band = True
        n_sub = n_band if in_band else 1
        if has_pcm:
            v_max = (mdot_c + mdot_d) / (rho_w * A_cross)
            for i in range(N):
                if n_caps[i] > 0:
                    ua_p = ua_node(n_caps[i], d, area_cap, v_max, f[i], rho_w, kw, pr, mu, wall_t, wall_k, k_pcm, enh, c_cond)
                    if ua_p > 0:
                        tau = m_pcm_node[i] * cp_min_eff / ua_p
                        ns = int(np.ceil(dt / (stiff_sf * tau)))
                        if ns > n_sub:
                            n_sub = ns
            if n_sub > max_sub:
                n_sub = max_sub
        dts = dt / n_sub

        for sb in range(n_sub):
            circ = circ_allowed
            if shield and T[N - 1] >= byp_w:
                circ = False
                n_sw += 1
                shield_s += dts
            k_ret = 0
            if circ:
                t_out = T[0] + max(a_c - b_c * T[0], 0.0) / (mdot_c * cp)
                for j in range(N - 1, -1, -1):
                    if T[j] <= t_out:
                        k_ret = j
                        break
            UA = np.zeros(N)
            pcm_shield_now = False
            if has_pcm:
                for i in range(N):
                    if n_caps[i] > 0:
                        thr = mdot_d + mdot_c if circ else mdot_d
                        v = thr / (rho_w * A_cross)
                        ua = ua_node(n_caps[i], d, area_cap, v, f[i], rho_w, kw, pr, mu, wall_t, wall_k, k_pcm, enh, c_cond)
                        if shield and Tp[i] >= byp_p and T[i] > Tp[i]:
                            ua = 0.0
                            n_sp += 1
                            pcm_shield_now = True
                        UA[i] = ua
            if pcm_shield_now:
                shield_s += dts

            Tn = solve_step(T, Tp, UA, m_w, loss_ua, T_amb, cp, mains, mdot_d, mdot_c, circ, k_ret, a_c, b_c, kcond, dts)
            if circ and (a_c - b_c * Tn[0]) < 0.0:
                circ = False
                Tn = solve_step(T, Tp, UA, m_w, loss_ua, T_amb, cp, mains, mdot_d, mdot_c, False, 0, a_c, b_c, kcond, dts)
            q_coll = max(a_c - b_c * Tn[0], 0.0) if circ else 0.0
            t_top = Tn[N - 1]
            q_un = mdot_d * cp * max(target - t_top, 0.0) if mdot_d > 0 else 0.0

            if has_pcm:
                for i in range(N):
                    if n_caps[i] > 0:
                        q = UA[i] * (Tn[i] - Tp[i])
                        hn = h[i] + q * dts / m_pcm_node[i]
                        tpn, fn = pcm_T_f_of_h(hn, Ts, Tl, L, cps, cpl, x)
                        if tpn < -50.0 or tpn > 500.0:
                            tpn = min(max(tpn, -50.0), 500.0)
                            hn = pcm_h_of_T(tpn, Ts, Tl, L, cps, cpl, x)
                        h[i], Tp[i], f[i] = hn, tpn, fn
            mix_inversions(Tn, m_w)
            for i in range(N):
                T[i] = Tn[i]
                if n_caps[i] <= 0:
                    Tp[i] = T[i]

            hq_c += q_coll * dts
            hq_un += q_un * dts
            dm = step_draw / n_sub
            if dm > 0:
                h_draw += dm
                h_edel += dm * cp * max(min(t_top, target) - mains, 0.0)
            t_top_max = max(t_top_max, t_top)
            bad = False
            for i in range(N):
                if T[i] > max_w:
                    bad = True
                if n_caps[i] > 0:
                    t_p_max = max(t_p_max, Tp[i])
                    if Tp[i] > max_p:
                        bad = True
            if bad:
                n_viol += 1

    s = pcm_derive_state(T, h, P)
    if not has_pcm:
        t_p_max = s[2]
    a_exec = action
    if action == CHARGE and n_sw > 0 and hq_c <= 0:
        a_exec = BYPASS
    y = np.zeros(18)
    y[0:7] = s
    y[7], y[8], y[9], y[10] = h_edel / 3600.0, hq_un / 3600.0, hq_c / 3600.0, h_draw
    y[11], y[12], y[13], y[14] = n_sw, n_sp, n_viol, a_exec
    y[15], y[16], y[17] = t_top_max, t_p_max, shield_s
    return T, h, y


# ----------------------------------------------------------------------------------------
# build_obs.m, dqn_policy.m, sensor_model.m, safety_interlock.m
# ----------------------------------------------------------------------------------------
def build_obs(I_t, T_amb, s, draw_kg, hod, min_since_draw, fwd, P):
    T_mains, lo, hi = P[2], P[39], P[40]
    raw = np.array([
        (s[0] - 30) / 40, (s[1] - 30) / 40, (s[2] - 30) / 40, (s[3] - 30) / 40, s[4],
        I_t / 1000, (T_amb - 15) / 25, hod / 24, draw_kg / 20, (T_mains - 20) / 20,
        s[5] / 3, s[6] / 1.5, min_since_draw / 600,
        fwd[0] / 1000, fwd[1] / 1000, fwd[2] / 1000, fwd[3] / 20], dtype=np.float64)
    return np.clip(raw.astype(np.float32), np.float32(lo), np.float32(hi))


def dqn_policy(obs, tw, policy_mode):
    if policy_mode == 1:
        return 0, np.zeros(3)
    x = np.asarray(obs, np.float32)
    z1 = np.maximum(tw["W1"] @ x + tw["b1"], np.float32(0))
    z2 = np.maximum(tw["W2"] @ z1 + tw["b2"], np.float32(0))
    q = tw["W3"] @ z2 + tw["b3"]
    return int(np.argmax(q)), q.astype(float)


def sensor_model(GHI, T_amb, s, noise_on, rng):
    ok = 1
    s_m = np.array(s, float)
    if noise_on:
        GHI_m = max(GHI + (10 + 0.01 * GHI) * rng.standard_normal(), 0.0)
        Tamb_m = T_amb + 0.3 * rng.standard_normal()
        s_m[0] += 0.2 * rng.standard_normal()
        s_m[1] += 0.2 * rng.standard_normal()
        s_m[2] += 0.2 * rng.standard_normal()
        s_m[3] += 0.5 * rng.standard_normal()
        s_m[4] = min(max(s_m[4], 0.0), 1.0)
        if rng.random() < 0.01:
            ok = 0
    else:
        GHI_m, Tamb_m = GHI, T_amb
    return GHI_m, Tamb_m, s_m, ok


class SafetyInterlock:
    def __init__(self):
        self.fault_latched = False

    def __call__(self, a_policy, Tw_m, Tpcm_m, sensors_ok, P):
        max_wC, max_pC, byp_wC, byp_pC = P[31], P[32], P[29], P[30]
        if Tw_m > max_wC or Tpcm_m > max_pC:
            self.fault_latched = True
        if self.fault_latched:
            return 2, 3
        if sensors_ok < 0.5:
            return 2, 2
        return a_policy, (1 if (Tw_m >= byp_wC or Tpcm_m >= byp_pC) else 0)


# ----------------------------------------------------------------------------------------
# simulate_hours.m
# ----------------------------------------------------------------------------------------
LOG_NAMES = ["Tw", "Tbot", "Tmean", "Tpcm", "f_melt", "E_stored_kWh", "E_rec45_kWh", "E_del_Wh", "E_unmet_Wh",
             "Q_coll_Wh", "n_sw", "n_sp", "n_viol", "shield_s", "Tw_max", "Tpcm_max", "a_policy", "a_cmd", "a_exec",
             "interlock", "draw_kg", "GHI", "T_amb", "hod", "sensors_ok"]


def simulate_hours(tw, W, P, policy_mode=0, noise_on=0, blackout=None, nSim=None, rng=None, forced_actions=None):
    m = len(W)
    n = m if nSim is None else nSim
    blackout = np.zeros(n, bool) if blackout is None else blackout
    rng = rng or np.random.default_rng(7)
    T, h = tw["T0"].copy(), tw["h0"].copy()
    s = pcm_derive_state(T, h, P)
    hours_since_draw = 24.0
    interlock = SafetyInterlock()
    L = {k: np.zeros(n) for k in LOG_NAMES}
    L["q"] = np.zeros((n, 3))
    L["obs"] = np.zeros((n, 17), np.float32)
    for t in range(n):
        idx, I, Ta, hod = W[t, 0], W[t, 1], W[t, 2], int(round(W[t, 3])) % 24
        draw = tw["demand24"][hod]
        fwd = np.zeros(4)
        for dh in (1, 2, 3):
            if t + dh < m:
                fwd[dh - 1] = W[t + dh, 1]
        if t + 1 < m:
            fwd[3] = tw["demand24"][int(round(W[t + 1, 3])) % 24]
        Im, Tam, sm, ok = sensor_model(I, Ta, s, noise_on, rng)
        if blackout[t]:
            ok = 0
        obs = build_obs(Im, Tam, sm, draw, hod, hours_since_draw * 60, fwd, P)
        ap, q = dqn_policy(obs, tw, policy_mode)
        if forced_actions is not None:           # open-loop replay of the Python actions
            ap = int(forced_actions[t])
        acmd, ils = interlock(ap, sm[0], sm[3], ok, P)
        T, h, y = pcm_plant_hour(I, Ta, draw, acmd, T, h, P)
        s = y[0:7]
        hours_since_draw = 0.0 if y[10] > 1e-3 else min(hours_since_draw + 1.0, 24.0)
        vals = dict(Tw=y[0], Tbot=y[1], Tmean=y[2], Tpcm=y[3], f_melt=y[4], E_stored_kWh=y[5], E_rec45_kWh=y[6],
                    E_del_Wh=y[7], E_unmet_Wh=y[8], Q_coll_Wh=y[9], n_sw=y[11], n_sp=y[12], n_viol=y[13],
                    a_exec=y[14], Tw_max=y[15], Tpcm_max=y[16], shield_s=y[17], a_policy=ap, a_cmd=acmd,
                    interlock=ils, draw_kg=draw, GHI=I, T_amb=Ta, hod=hod, sensors_ok=ok)
        for k, v in vals.items():
            L[k][t] = v
        L["q"][t] = q
        L["obs"][t] = obs
    return L


# ----------------------------------------------------------------------------------------
# validate_against_python.m (checks A, policy, closed loop)
# ----------------------------------------------------------------------------------------
def validate(tw, hours: int) -> dict:
    ref = tw["ref"]
    n = min(hours, len(ref["action"]))
    W, P = tw["W"], tw["P"]
    rep = {"regime": tw["regime"], "hours": n, "engine": "python mirror of the .m files (not MATLAB)"}

    def compare(L):
        return {
            "max_abs_dT_top_C": float(np.max(np.abs(L["Tw"] - ref["T_w_C"][:n]))),
            "max_abs_dT_bottom_C": float(np.max(np.abs(L["Tbot"] - ref["T_bottom_C"][:n]))),
            "max_abs_dT_mean_C": float(np.max(np.abs(L["Tmean"] - ref["T_mean_C"][:n]))),
            "max_abs_dT_pcm_C": float(np.max(np.abs(L["Tpcm"] - ref["T_pcm_C"][:n]))),
            "max_abs_df_melt": float(np.max(np.abs(L["f_melt"] - ref["f_melt"][:n]))),
            "max_abs_dE_del_Wh": float(np.max(np.abs(L["E_del_Wh"] - ref["E_del_Wh"][:n]))),
            "delivered_kWh_twin": float(L["E_del_Wh"].sum() / 1000),
            "delivered_kWh_python": float(ref["E_del_Wh"][:n].sum() / 1000),
            "shields_twin": int((L["n_sw"] + L["n_sp"]).sum()),
            "shields_python": int((ref["n_shield_w"][:n] + ref["n_shield_p"][:n]).sum()),
            "violations_twin": int(L["n_viol"].sum()),
            "violations_python": int(ref["n_viol"][:n].sum()),
            "executed_action_agreement_pct": float(100 * np.mean(L["a_exec"] == ref["action_executed"][:n])),
        }

    # A. open-loop plant replay: the plant is fed the actions Python took
    La = simulate_hours(tw, W, P, 0, 0, None, n, forced_actions=ref["action"][:n])
    A = compare(La)
    A["pass"] = bool(A["max_abs_dT_top_C"] < 1e-6 and A["max_abs_dT_pcm_C"] < 1e-6
                     and A["shields_twin"] == A["shields_python"] and A["violations_twin"] == A["violations_python"])
    rep["A_open_loop_plant"] = A

    # policy only, on Python's own observations
    obs_cols = np.column_stack([ref[f"obs{k}"][:n] for k in range(17)]).astype(np.float32)
    q_ref = np.column_stack([ref["q0"][:n], ref["q1"][:n], ref["q2"][:n]])
    acts = np.zeros(n, int)
    dq = 0.0
    for k in range(n):
        acts[k], q = dqn_policy(obs_cols[k], tw, 0)
        dq = max(dq, float(np.max(np.abs(q - q_ref[k]) / np.maximum(1.0, np.abs(q_ref[k])))))
    rep["A_policy_on_python_obs"] = {"action_agreement_pct": float(100 * np.mean(acts == ref["action"][:n])),
                                     "max_rel_dQ": dq}

    # C. closed loop: sensors -> observation -> DQN -> interlock -> plant
    Lc = simulate_hours(tw, W, P, 0, 0, None, n)
    C = compare(Lc)
    C["action_agreement_pct"] = float(100 * np.mean(Lc["a_policy"] == ref["action"][:n]))
    C["max_abs_dobs"] = float(np.max(np.abs(Lc["obs"] - obs_cols)))
    C["pass"] = bool(C["action_agreement_pct"] == 100.0 and C["max_abs_dT_top_C"] < 1e-6
                     and C["shields_twin"] == C["shields_python"] and C["violations_twin"] == 0)
    rep["C_closed_loop"] = C
    rep["overall_pass"] = bool(A["pass"] and C["pass"] and rep["A_policy_on_python_obs"]["action_agreement_pct"] == 100.0)
    return rep


# ----------------------------------------------------------------------------------------
# run_scenarios.m
# ----------------------------------------------------------------------------------------
def build_scenarios(tw):
    Wall = tw["W"]
    k0, nWin = 90 * 24, 10 * 24                       # 1 April, ten days
    base = Wall[k0:k0 + nWin + 3].copy()              # + 3 real hours for the forecast at the end
    inEv = np.zeros(nWin, bool)
    inEv[4 * 24:8 * 24] = True                        # edge-case days 5-8
    ev = np.concatenate([inEv, np.zeros(3, bool)])
    nb = np.zeros(nWin, bool)
    sc = [("clear", "Clear sunny days (reference)", base, tw["P"], 0, nb)]
    W = base.copy(); W[ev, 1] = 0
    sc.append(("no_sunlight", "No sunlight for 4 days", W, tw["P"], 0, nb))
    W = base.copy(); W[ev, 1] = np.minimum(0.12 * base[ev, 1], 120); W[ev, 2] = base[ev, 2] - 5
    sc.append(("rain_cloud", "Rain / heavy cloud (GHI x0.12, ambient -5 C)", W, tw["P"], 0, nb))
    W = base.copy(); W[ev, 2] = base[ev, 2] - 12; W[ev, 1] = 0.9 * base[ev, 1]
    P = tw["P"].copy(); P[2] -= 8                      # colder mains water for the whole run
    sc.append(("low_temperature", "Low temperature (ambient -12 C, mains -8 C)", W, P, 0, nb))
    W = base.copy(); W[ev, 2] = base[ev, 2] + 9; W[ev, 1] = 1.15 * base[ev, 1]
    sc.append(("heat_wave", "Heat wave (ambient +9 C, GHI x1.15)", W, tw["P"], 0, nb))
    bo = nb.copy(); bo[4 * 24:4 * 24 + 12] = True
    sc.append(("sensor_fault", "Noisy sensors + 12 h sensor blackout", base, tw["P"], 1, bo))
    return sc, inEv, nWin


def metrics(L, inEv):
    last = np.flatnonzero(inEv)[-1]
    return {
        "delivered_kWh_event": L["E_del_Wh"][inEv].sum() / 1000,
        "unmet_kWh_event": L["E_unmet_Wh"][inEv].sum() / 1000,
        "shield_trips_event": int((L["n_sw"][inEv] + L["n_sp"][inEv]).sum()),
        "shield_hours_event": L["shield_s"][inEv].sum() / 3600,
        "hard_violations_all": int(L["n_viol"].sum()),
        "Tw_min_event_C": L["Tw"][inEv].min(),
        "Tw_max_C": L["Tw_max"].max(),
        "Tpcm_max_C": L["Tpcm_max"].max(),
        "pcm_melt_end_event": L["f_melt"][last],
        "hours_water_ge45_event": int((L["Tw"][inEv] >= 45).sum()),
        "idle_or_bypass_hours_event": int((L["a_policy"][inEv] != 0).sum()),
        "failsafe_hours": int((L["interlock"] >= 2).sum()),
    }


def plot_scenario(name, title, Ls, Lb, inEv, file, regime):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    n = len(Ls["Tw"])
    d = np.arange(1, n + 1) / 24
    e0, e1 = np.flatnonzero(inEv)[0] / 24, (np.flatnonzero(inEv)[-1] + 1) / 24
    fig, ax = plt.subplots(5, 1, figsize=(11.5, 12), sharex=True)
    fig.suptitle(f"Objective 4 software-in-the-loop, Rajasthan regime {regime}: {title}\n(Python mirror of the MATLAB twin)",
                 fontweight="bold")
    for a in ax:
        a.axvspan(e0, e1, color="0.9", zorder=0)
        a.grid(True, alpha=0.4)
    ax[0].plot(d, Ls["GHI"], color="#d9a300"); ax[0].set_ylabel("GHI [W/m²]")
    a2 = ax[0].twinx(); a2.plot(d, Ls["T_amb"], "k-", lw=0.9); a2.set_ylabel("T_amb [°C]")
    ax[0].set_title("Weather input (grey band = edge-case period)", fontsize=10)
    ax[1].plot(d, Ls["Tw"], "b-", lw=1.3, label="T_top DQN"); ax[1].plot(d, Lb["Tw"], "b:", lw=1, label="T_top B0")
    ax[1].plot(d, Ls["Tbot"], color="#4aa3df", lw=0.9, label="T_bottom DQN")
    ax[1].plot(d, Ls["Tpcm"], color="#e06000", lw=1.3, label="T_PCM DQN"); ax[1].plot(d, Lb["Tpcm"], ":", color="#e06000", lw=1, label="T_PCM B0")
    for yv, st, lb in ((45, "g--", "45 °C delivery"), (72, "r--", "72 °C shield"), (75, "r-", "75 °C limit")):
        ax[1].axhline(yv, color=st[0], ls=st[1:], lw=0.8); ax[1].text(d[-1], yv, " " + lb, va="bottom", ha="right", fontsize=7)
    ax[1].set_ylabel("T [°C]"); ax[1].legend(ncol=5, fontsize=8, loc="upper center", bbox_to_anchor=(0.5, 1.22))
    ax[2].plot(d, Ls["f_melt"], color="#e06000", lw=1.5); ax[2].plot(d, Lb["f_melt"], ":", color="#e06000")
    ax[2].set_ylabel("PCM melt fraction"); ax[2].set_ylim(0, 1.05)
    ax[3].step(d, Ls["a_cmd"], "b-", where="post", label="commanded (after interlock)")
    ax[3].step(d, Ls["a_exec"] + 0.08, "r:", where="post", label="executed (after plant shield)")
    ax[3].set_yticks([0, 1, 2]); ax[3].set_yticklabels(["CHARGE", "IDLE", "BYPASS"]); ax[3].set_ylim(-0.3, 2.4)
    ax[3].legend(ncol=2, fontsize=8, loc="upper center", bbox_to_anchor=(0.5, 1.22))
    ax[4].plot(d, np.cumsum(Ls["E_del_Wh"]) / 1000, "b-", lw=1.3, label="delivered DQN")
    ax[4].plot(d, np.cumsum(Lb["E_del_Wh"]) / 1000, "b:", label="delivered B0")
    ax[4].plot(d, np.cumsum(Ls["E_unmet_Wh"]) / 1000, "m-", lw=1.3, label="unmet DQN")
    ax[4].set_ylabel("cumulative kWh"); ax[4].set_xlabel("day"); ax[4].set_xlim(0, n / 24)
    ax[4].legend(ncol=3, fontsize=8, loc="upper center", bbox_to_anchor=(0.5, 1.22))
    fig.tight_layout(rect=(0, 0, 1, 0.97))
    fig.savefig(file, dpi=110)
    plt.close(fig)


def run_scenarios(tw, out_dir: pathlib.Path, plots: bool):
    sc, inEv, nWin = build_scenarios(tw)
    rows = []
    for name, title, W, P, noise, bo in sc:
        Ls = simulate_hours(tw, W, P, 0, noise, bo, nWin, rng=np.random.default_rng(7))
        Lb = simulate_hours(tw, W, P, 1, noise, bo, nWin, rng=np.random.default_rng(7))
        for pol, L in (("DQN", Ls), ("B0", Lb)):
            rows.append({"scenario": name, "policy": pol, **metrics(L, inEv)})
        if plots:
            plot_scenario(name, title, Ls, Lb, inEv, out_dir / f"{name}.png", tw["regime"])
        print(f"[scenario] {name:<16} DQN delivered(event)={rows[-2]['delivered_kWh_event']:.2f} kWh  "
              f"B0={rows[-1]['delivered_kWh_event']:.2f} kWh  shield trips {rows[-2]['shield_trips_event']} vs "
              f"{rows[-1]['shield_trips_event']}  DQN viol={rows[-2]['hard_violations_all']}")
    with open(out_dir / "scenario_summary.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        for r in rows:
            w.writerow({k: (f"{v:.6g}" if isinstance(v, float) else v) for k, v in r.items()})
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--regime", type=int, default=1, choices=[0, 1, 2])
    ap.add_argument("--year", type=int, default=2023)
    ap.add_argument("--hours", type=int, default=8760)
    ap.add_argument("--no-plots", action="store_true")
    ap.add_argument("--no-scenarios", action="store_true")
    args = ap.parse_args()
    exp = HERE / f"export_r{args.regime}"
    out = exp / "python_mirror"
    out.mkdir(parents=True, exist_ok=True)
    tw = load_twin_params(exp, args.year)

    rep = validate(tw, args.hours)
    (out / "validation_report.json").write_text(json.dumps(rep, indent=2))
    A, Pn, C = rep["A_open_loop_plant"], rep["A_policy_on_python_obs"], rep["C_closed_loop"]
    tf = lambda b: "PASS" if b else "FAIL"
    print(f"[A open-loop plant, {rep['hours']} h] max|dT_top| {A['max_abs_dT_top_C']:.2e}  max|dT_pcm| {A['max_abs_dT_pcm_C']:.2e}  "
          f"shields {A['shields_twin']} vs {A['shields_python']}  viol {A['violations_twin']} vs {A['violations_python']}  -> {tf(A['pass'])}")
    print(f"[A policy on Python obs]   action agreement {Pn['action_agreement_pct']:.3f} %  max rel |dQ| {Pn['max_rel_dQ']:.2e}")
    print(f"[C closed loop, {rep['hours']} h]     action agreement {C['action_agreement_pct']:.3f} %  max|dT_top| {C['max_abs_dT_top_C']:.2e}  "
          f"delivered {C['delivered_kWh_twin']:.3f} vs {C['delivered_kWh_python']:.3f} kWh  shields {C['shields_twin']} vs "
          f"{C['shields_python']}  -> {tf(C['pass'])}")
    print(f"[validate] overall: {tf(rep['overall_pass'])}  ({out / 'validation_report.json'})")

    if not args.no_scenarios:
        run_scenarios(tw, out, not args.no_plots)
        print(f"[scenarios] table and plots in {out}")


if __name__ == "__main__":
    main()
