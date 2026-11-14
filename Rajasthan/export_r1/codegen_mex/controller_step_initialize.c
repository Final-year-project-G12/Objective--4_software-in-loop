/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * controller_step_initialize.c
 *
 * Code generation for function 'controller_step_initialize'
 *
 */

/* Include files */
#include "controller_step_initialize.h"
#include "_coder_controller_step_mex.h"
#include "controller_step_data.h"
#include "rt_nonfinite.h"
#include "safety_interlock.h"

/* Function Declarations */
static void controller_step_once(void);

/* Function Definitions */
static void controller_step_once(void)
{
  mex_InitInfAndNan();
  safety_interlock_init();
}

void controller_step_initialize(void)
{
  static const volatile char_T *emlrtBreakCheckR2012bFlagVar = NULL;
  emlrtStack st = {
      NULL, /* site */
      NULL, /* tls */
      NULL  /* prev */
  };
  mexFunctionCreateRootTLS();
  st.tls = emlrtRootTLSGlobal;
  emlrtBreakCheckR2012bFlagVar = emlrtGetBreakCheckFlagAddressR2022b(&st);
  emlrtClearAllocCountR2012b(&st, false, 0U, NULL);
  emlrtEnterRtStackR2012b(&st);
  if (emlrtFirstTimeR2012b(emlrtRootTLSGlobal)) {
    controller_step_once();
  }
}

/* End of code generation (controller_step_initialize.c) */
