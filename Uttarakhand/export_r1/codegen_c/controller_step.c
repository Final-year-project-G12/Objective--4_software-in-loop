/*
 * Trial License - for use to evaluate programs for possible purchase as
 * an end-user only.
 *
 * controller_step.c
 *
 * Code generation for function 'controller_step'
 *
 */

/* Include files */
#include "controller_step.h"
#include "controller_step_data.h"
#include "controller_step_initialize.h"
#include "omp.h"
#include <math.h>

/* Function Definitions */
void controller_step(const float obs[15], double Ttop_m, double Tpcm_m,
                     double sensors_ok, const float W1[960], const float b1[64],
                     const float W2[4096], const float b2[64],
                     const float Wa[128], const float ba[2], const double P[40],
                     double *action, double *interlock_state, double *margin)
{
  float z1[64];
  float z2[64];
  float lg[2];
  float f;
  float f1;
  int b_k;
  int i;
  int i1;
  int k;
  if (!isInitialized_controller_step) {
    controller_step_initialize();
  }
  /* CONTROLLER_STEP  The embedded controller as ONE function: frozen PPO policy
   */
  /*  followed by the safety interlock. This is the unit compiled to C (MATLAB
   */
  /*  Coder / Embedded Coder) for the processor-in-the-loop stage. */
  /* PPO_POLICY  The frozen Objective 3 PPO actor as a plain MLP (the "RL Agent"
   * block). */
  /*  */
  /*  Stable-Baselines3 MlpPolicy, net_arch [64, 64], tanh activations: */
  /*    logits = Wa * tanh(W2 * tanh(W1 * obs + b1) + b2) + ba */
  /*  Deterministic action = argmax(logits): 0 = BYPASS, 1 = ENABLE. */
  /*  Weights come from <O3 uttarakhand>/results/o4_handoff/r<k>/policy_r<k>.zip
   * via */
  /*  Uttarakhand/export_from_python.py. Arithmetic is single precision to
   * mirror */
  /*  the float32 PyTorch policy. */
  /*  */
  /*  policy_mode: 0 = PPO (default), 1 = B0 always-enable baseline (O2's design
   * as */
  /*  released, with its in-kernel shield). */
  /*  */
  /*  margin = logit(ENABLE) - logit(BYPASS) (how sure the policy is; 0 for B0).
   */
  for (k = 0; k < 64; k++) {
    f = 0.0F;
    for (i = 0; i < 15; i++) {
      f += W1[k + (i << 6)] * obs[i];
    }
    z1[k] = tanhf(f + b1[k]);
  }
#pragma omp parallel for num_threads(omp_get_max_threads()) private(f1, i1)

  for (b_k = 0; b_k < 64; b_k++) {
    f1 = 0.0F;
    for (i1 = 0; i1 < 64; i1++) {
      f1 += W2[b_k + (i1 << 6)] * z1[i1];
    }
    f1 = tanhf(f1 + b2[b_k]);
    z2[b_k] = f1;
  }
  for (k = 0; k < 2; k++) {
    f = 0.0F;
    for (i = 0; i < 64; i++) {
      f += Wa[k + (i << 1)] * z2[i];
    }
    lg[k] = f + ba[k];
  }
  /*  torch argmax returns the first index on a tie */
  *margin = lg[1] - lg[0];
  /* SAFETY_INTERLOCK  Fail-safe between the learned policy and the
   * collector-loop pump */
  /*  (Uttarakhand hardware_interface_spec.json, "fail_safe" and */
  /*  "independent_hardware_interlock"). */
  /*  */
  /*  The guard-band shield itself (pump off at top node >= 72 C, PCM exchange
   * cut */
  /*  at 62 C) is evaluated inside the plant at every solver sub-step, exactly
   * as */
  /*  in O2's kernel, so the twin stays comparable with the simulator. This
   * block */
  /*  adds the rules that live outside the physics: */
  /*  */
  /*    * stale / missing sensor frame       -> fall back to B0 = ENABLE
   * (hand-off */
  /*                                            spec: "sensor_or_policy_fault:
   * fall */
  /*                                            back to B0 (always enable) under
   * the */
  /*                                            interlock"; the in-plant shield
   * still */
  /*                                            protects the tank) */
  /*    * hard limit exceeded despite shield -> latch a fault, BYPASS (pump off)
   */
  /*                                            until a manual reset (block
   * re-init) */
  /*  */
  /*  NOTE: this differs from the Tamil Nadu twin, whose spec fails to BYPASS.
   */
  /*  */
  /*  interlock_state: 0 normal, 1 guard band reached (shield will act this
   * hour), */
  /*                   2 stale-sensor fail-safe (B0), 3 latched hard-limit
   * fault. */
  /*  P is the kernel parameter vector (30 bypass_water, 31 bypass_pcm, */
  /*  32 max_water, 33 max_pcm). */
  if ((Ttop_m > P[31]) || (Tpcm_m > P[32])) {
    fault_latched = true;
  }
  if (fault_latched) {
    *action = 0.0;
    *interlock_state = 3.0;
  } else if (sensors_ok < 0.5) {
    *action = 1.0;
    *interlock_state = 2.0;
  } else {
    *action = (lg[1] > lg[0]);
    if ((Ttop_m >= P[29]) || (Tpcm_m >= P[30])) {
      *interlock_state = 1.0;
    } else {
      *interlock_state = 0.0;
    }
  }
}

/* End of code generation (controller_step.c) */
