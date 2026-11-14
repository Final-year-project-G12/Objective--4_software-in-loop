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
#include "rt_nonfinite.h"
#include "blas.h"
#include "mwmathutil.h"
#include <stddef.h>
#include <xmmintrin.h>

/* Function Definitions */
void controller_step(const emlrtStack *sp, const real_T obs[17], real_T Tw_m,
                     real_T Tpcm_m, real_T sensors_ok, const real32_T W1[1088],
                     const real32_T b1[64], const real32_T W2[4096],
                     const real32_T b2[64], const real32_T W3[192],
                     const real32_T b3[3], const real_T P[80], real_T *action,
                     real_T *interlock_state, real_T q[3])
{
  __m128 r;
  ptrdiff_t k_t;
  ptrdiff_t lda_t;
  ptrdiff_t ldb_t;
  ptrdiff_t ldc_t;
  ptrdiff_t m_t;
  ptrdiff_t n_t;
  int32_T a_policy;
  int32_T b_i;
  int32_T i;
  real32_T y[64];
  real32_T z1[64];
  real32_T x[17];
  real32_T fv[4];
  real32_T fv1[4];
  real32_T fv2[4];
  real32_T qs[3];
  real32_T alpha1;
  real32_T beta1;
  char_T TRANSA1;
  char_T TRANSB1;
  (void)sp;
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
  for (i = 0; i < 17; i++) {
    x[i] = (real32_T)obs[i];
  }
  TRANSB1 = 'N';
  TRANSA1 = 'N';
  alpha1 = 1.0F;
  beta1 = 0.0F;
  m_t = (ptrdiff_t)64;
  n_t = (ptrdiff_t)1;
  k_t = (ptrdiff_t)17;
  lda_t = (ptrdiff_t)64;
  ldb_t = (ptrdiff_t)17;
  ldc_t = (ptrdiff_t)64;
  sgemm(&TRANSA1, &TRANSB1, &m_t, &n_t, &k_t, &alpha1, (real32_T *)&W1[0],
        &lda_t, &x[0], &ldb_t, &beta1, &y[0], &ldc_t);
  for (i = 0; i <= 60; i += 4) {
    r = _mm_add_ps(_mm_loadu_ps(&y[i]), _mm_loadu_ps(&b1[i]));
    _mm_storeu_ps(&y[i], r);
    _mm_storeu_ps(&fv[0], r);
    fv1[0] = muSingleScalarMax(fv[0], 0.0F);
    fv1[1] = muSingleScalarMax(fv[1], 0.0F);
    fv1[2] = muSingleScalarMax(fv[2], 0.0F);
    fv1[3] = muSingleScalarMax(fv[3], 0.0F);
    _mm_storeu_ps(&z1[i], _mm_loadu_ps(&fv1[0]));
  }
  TRANSB1 = 'N';
  TRANSA1 = 'N';
  alpha1 = 1.0F;
  beta1 = 0.0F;
  m_t = (ptrdiff_t)64;
  n_t = (ptrdiff_t)1;
  k_t = (ptrdiff_t)64;
  lda_t = (ptrdiff_t)64;
  ldb_t = (ptrdiff_t)64;
  ldc_t = (ptrdiff_t)64;
  sgemm(&TRANSA1, &TRANSB1, &m_t, &n_t, &k_t, &alpha1, (real32_T *)&W2[0],
        &lda_t, &z1[0], &ldb_t, &beta1, &y[0], &ldc_t);
  for (i = 0; i <= 60; i += 4) {
    r = _mm_add_ps(_mm_loadu_ps(&y[i]), _mm_loadu_ps(&b2[i]));
    _mm_storeu_ps(&y[i], r);
    _mm_storeu_ps(&fv2[0], r);
    fv[0] = muSingleScalarMax(fv2[0], 0.0F);
    fv[1] = muSingleScalarMax(fv2[1], 0.0F);
    fv[2] = muSingleScalarMax(fv2[2], 0.0F);
    fv[3] = muSingleScalarMax(fv2[3], 0.0F);
    _mm_storeu_ps(&z1[i], _mm_loadu_ps(&fv[0]));
  }
  for (i = 0; i < 3; i++) {
    alpha1 = 0.0F;
    for (b_i = 0; b_i < 64; b_i++) {
      alpha1 += W3[i + 3 * b_i] * z1[b_i];
    }
    alpha1 += b3[i];
    qs[i] = alpha1;
    q[i] = alpha1;
  }
  /*  first maximum wins on a tie, as torch.argmax / numpy.argmax do */
  a_policy = 0;
  alpha1 = qs[0];
  if (qs[1] > qs[0]) {
    alpha1 = qs[1];
    a_policy = 1;
  }
  if (qs[2] > alpha1) {
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
