/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 * File: _coder_controller_step_api.h
 *
 * MATLAB Coder version            : 23.2
 * C/C++ source code generated on  : 12-Nov-2026 21:57:54
 */

#ifndef _CODER_CONTROLLER_STEP_API_H
#define _CODER_CONTROLLER_STEP_API_H

/* Include Files */
#include "emlrt.h"
#include "mex.h"
#include "tmwtypes.h"
#include <string.h>

/* Variable Declarations */
extern emlrtCTX emlrtRootTLSGlobal;
extern emlrtContext emlrtContextGlobal;

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
void controller_step(real_T obs[11], real_T Tw_m, real_T Tpcm_m,
                     real_T sensors_ok, real32_T W1[2816], real32_T b1[256],
                     real32_T W2[65536], real32_T b2[256], real32_T Wmu[256],
                     real32_T bmu, real_T P[41], real_T *action,
                     real_T *interlock_state, real_T *a_cont);

void controller_step_api(const mxArray *const prhs[11], int32_T nlhs,
                         const mxArray *plhs[3]);

void controller_step_atexit(void);

void controller_step_initialize(void);

void controller_step_terminate(void);

void controller_step_xil_shutdown(void);

void controller_step_xil_terminate(void);

#ifdef __cplusplus
}
#endif

#endif
/*
 * File trailer for _coder_controller_step_api.h
 *
 * [EOF]
 */
