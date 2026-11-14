/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
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
void controller_step(const double obs[17], double Tw_m, double Tpcm_m,
                     double sensors_ok, const float W1[1088],
                     const float b1[64], const float W2[4096],
                     const float b2[64], const float W3[192], const float b3[3],
                     const double P[80], double *action,
                     double *interlock_state, double q[3])
{
  float varargin_1[64];
  float z1[64];
  float qs[3];
  float best;
  float f;
  int a_policy;
  int i;
  int i1;
  int i2;
  int k;
  if (!isInitialized_controller_step) {
    controller_step_initialize();
  }
  /* CONTROLLER_STEP  The embedded controller as ONE function: trained DQN
   * policy followed by */
  /*  the safety interlock. This is the unit that is compiled to C (MATLAB
   * Coder) for the */
  /*  processor-in-the-loop stage. */
  /* DQN_POLICY  Trained DQN controller as a plain MLP (the "RL Agent" block).
   */
  /*  */
  /*  Q(obs) = Linear(ReLU(Linear(ReLU(Linear(obs)))))  with layers 17 -> 64 ->
   * 64 -> 3. */
  /*  Deterministic action = the action with the largest Q-value: */
  /*    0 CHARGE, 1 IDLE, 2 BYPASS */
  /*  Weights come from Objective 3's released checkpoint for the regime */
  /*  (results/gen2/gen2_selected_dqn.json) through export_from_python.py. The
   * arithmetic */
  /*  is done in single precision to mirror the float32 PyTorch network. */
  /*  */
  /*  Tamil Nadu's twin used a SAC actor (tanh output binned at +/- 1/3);
   * Rajasthan's */
  /*  released controller is a DQN, so the output stage here is an argmax. */
  /*  */
  /*  policy_mode: 0 = DQN (default), 1 = B0 always-charge baseline (for A/B
   * comparison */
  /*  of delivery and shield counts inside the same twin). */
  for (k = 0; k < 64; k++) {
    best = 0.0F;
    for (i1 = 0; i1 < 17; i1++) {
      best += W1[k + (i1 << 6)] * (float)obs[i1];
    }
    z1[k] = fmaxf(best + b1[k], 0.0F);
  }
#pragma omp parallel for num_threads(omp_get_max_threads()) private(f, i2)

  for (i = 0; i < 64; i++) {
    f = 0.0F;
    for (i2 = 0; i2 < 64; i2++) {
      f += W2[i + (i2 << 6)] * z1[i2];
    }
    varargin_1[i] = f + b2[i];
  }
  for (k = 0; k < 64; k++) {
    z1[k] = fmaxf(varargin_1[k], 0.0F);
  }
  for (k = 0; k < 3; k++) {
    best = 0.0F;
    for (i1 = 0; i1 < 64; i1++) {
      best += W3[k + 3 * i1] * z1[i1];
    }
    best += b3[k];
    qs[k] = best;
    q[k] = best;
  }
  /*  first maximum wins on a tie, as torch.argmax / numpy.argmax do */
  a_policy = 0;
  best = qs[0];
  if (qs[1] > qs[0]) {
    best = qs[1];
    a_policy = 1;
  }
  if (qs[2] > best) {
    a_policy = 2;
  }
  /* SAFETY_INTERLOCK  Hardware-level fail-safe that sits between the learned
   * policy and the */
  /*  actuators ("fail_safe" rules of Objective 3's
   * scripts/phase8_o4_handoff.py). */
  /*  */
  /*  The guard-band shield itself (72 C top water node / 62 C PCM) is evaluated
   * inside the */
  /*  plant at every solver sub-step, exactly as in the Python environment, so
   * the twin stays */
  /*  comparable with the simulator. This block adds the two rules that live
   * outside the */
  /*  physics: */
  /*  */
  /*    * stale / missing sensor frame        -> command BYPASS (safe default)
   */
  /*    * hard limit exceeded despite shield  -> latch fault, BYPASS until a
   * manual reset */
  /*                                             (block re-init: "clear
   * safety_interlock") */
  /*  */
  /*    Tw_m    measured TOP-node water temperature [C] */
  /*    Tpcm_m  measured (mean) PCM temperature [C] */
  /*  */
  /*  interlock_state: 0 normal, 1 guard band active (shield will fire this
   * hour), */
  /*  2 stale-sensor fail-safe, 3 latched hard-limit fault. */
  if ((Tw_m > P[31]) || (Tpcm_m > P[32])) {
    fault_latched = true;
  }
  if (fault_latched) {
    *action = 2.0;
    *interlock_state = 3.0;
  } else if (sensors_ok < 0.5) {
    *action = 2.0;
    *interlock_state = 2.0;
  } else {
    *action = a_policy;
    if ((Tw_m >= P[29]) || (Tpcm_m >= P[30])) {
      *interlock_state = 1.0;
    } else {
      *interlock_state = 0.0;
    }
  }
}

/* End of code generation (controller_step.c) */
