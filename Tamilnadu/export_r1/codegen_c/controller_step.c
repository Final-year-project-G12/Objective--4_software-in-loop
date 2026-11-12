/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 * File: controller_step.c
 *
 * MATLAB Coder version            : 23.2
 * C/C++ source code generated on  : 12-Nov-2026 21:57:54
 */

/* Include Files */
#include "controller_step.h"
#include "controller_step_data.h"
#include "controller_step_initialize.h"
#include <math.h>

/* Function Definitions */
/*
 * CONTROLLER_STEP  The embedded controller as ONE function: trained SAC policy
 *  followed by the safety interlock. This is the unit that is compiled to C
 *  (MATLAB Coder / Embedded Coder) for the processor-in-the-loop stage.
 *
 * Arguments    : const double obs[11]
 *                double Tw_m
 *                double Tpcm_m
 *                double sensors_ok
 *                const float W1[2816]
 *                const float b1[256]
 *                const float W2[65536]
 *                const float b2[256]
 *                const float Wmu[256]
 *                float bmu
 *                const double P[41]
 *                double *action
 *                double *interlock_state
 *                double *a_cont
 * Return Type  : void
 */
void controller_step(const double obs[11], double Tw_m, double Tpcm_m,
                     double sensors_ok, const float W1[2816],
                     const float b1[256], const float W2[65536],
                     const float b2[256], const float Wmu[256], float bmu,
                     const double P[41], double *action,
                     double *interlock_state, double *a_cont)
{
  float z1[256];
  float b_Wmu;
  float x;
  int i;
  int k;
  if (!isInitialized_controller_step_lib) {
    controller_step_initialize();
  }
  /* SAC_POLICY  Trained SAC actor as a plain MLP (the "RL Agent" block). */
  /*  */
  /*  Deterministic SAC action = tanh(mu(obs)), mu =
   * Linear(ReLU(Linear(ReLU(Linear(obs))))). */
  /*  Weights come from results/sac/r0/best_model/best_model.zip via */
  /*  objective4_software_in_loop/export_from_python.py. The arithmetic is done
   * in single */
  /*  precision to mirror the float32 PyTorch policy. */
  /*  */
  /*  Binning (o3/environment/gym_wrapper.py::PCMContinuousGymEnv._to_discrete):
   */
  /*    a < -1/3        -> 0 CHARGE */
  /*    -1/3 <= a <= 1/3 -> 1 IDLE */
  /*    a >  1/3        -> 2 BYPASS */
  /*  */
  /*  policy_mode: 0 = SAC (default), 1 = B0 always-charge baseline (for A/B */
  /*  comparison of the shield counts inside the same twin). */
  for (k = 0; k < 256; k++) {
    x = 0.0F;
    for (i = 0; i < 11; i++) {
      x += W1[k + (i << 8)] * (float)obs[i];
    }
    x += b1[k];
    if (x >= 0.0F) {
      z1[k] = x;
    } else {
      z1[k] = 0.0F;
    }
  }
  b_Wmu = 0.0F;
  for (k = 0; k < 256; k++) {
    x = 0.0F;
    for (i = 0; i < 256; i++) {
      x += W2[k + (i << 8)] * z1[i];
    }
    x += b2[k];
    if (!(x >= 0.0F)) {
      x = 0.0F;
    }
    b_Wmu += Wmu[k] * x;
  }
  x = (float)tanh(b_Wmu + bmu);
  *a_cont = x;
  /* SAFETY_INTERLOCK  Hardware-level fail-safe that sits between the learned */
  /*  policy and the actuators (obj4_hardware_interface_spec_r0.json,
   * "fail_safe"). */
  /*  */
  /*  The guard-band shield itself (72 C water / 62 C PCM) is evaluated inside
   */
  /*  the plant at every 150 s solver sub-step -- the twin's analogue of the */
  /*  10 s hardware control cycle -- exactly as in the Python environment, so
   * the */
  /*  twin stays bit-for-bit comparable with the simulator. This block adds the
   */
  /*  two rules that live outside the physics: */
  /*  */
  /*    * stale / missing sensor frame        -> command BYPASS (safe default)
   */
  /*    * hard limit exceeded despite shield  -> latch fault, BYPASS until a */
  /*                                             manual reset (block re-init) */
  /*  */
  /*  interlock_state: 0 normal, 1 guard band active (shield will fire this */
  /*  hour), 2 stale-sensor fail-safe, 3 latched hard-limit fault. */
  if ((Tw_m > P[28]) || (Tpcm_m > P[29])) {
    fault_latched = true;
  }
  if (fault_latched) {
    *action = 2.0;
    *interlock_state = 3.0;
  } else if (sensors_ok < 0.5) {
    *action = 2.0;
    *interlock_state = 2.0;
  } else {
    if (x < -0.33333333333333331) {
      *action = 0.0;
    } else if (x > 0.33333333333333331) {
      *action = 2.0;
    } else {
      *action = 1.0;
    }
    if ((Tw_m >= P[31]) || (Tpcm_m >= P[32])) {
      *interlock_state = 1.0;
    } else {
      *interlock_state = 0.0;
    }
  }
}

/*
 * File trailer for controller_step.c
 *
 * [EOF]
 */
