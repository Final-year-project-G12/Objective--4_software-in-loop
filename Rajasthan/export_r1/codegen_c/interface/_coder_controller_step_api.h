/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * _coder_controller_step_api.h
 *
 * Code generation for function 'controller_step'
 *
 */

#ifndef _CODER_CONTROLLER_STEP_API_H
#define _CODER_CONTROLLER_STEP_API_H

/* Include files */
#include "emlrt.h"
#include "mex.h"
#include "tmwtypes.h"
#include <string.h>

/* Variable Declarations */

#ifdef __cplusplus
extern "C" {
#endif

extern emlrtCTX emlrtRootTLSGlobal;
extern emlrtContext emlrtContextGlobal;

#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
void controller_step(const real_T obs[17], real_T Tw_m, real_T Tpcm_m,
                     real_T sensors_ok, const real32_T W1[1088],
                     const real32_T b1[64], const real32_T W2[4096],
                     const real32_T b2[64], const real32_T W3[192],
                     const real32_T b3[3], const real_T P[80], real_T *action,
                     real_T *interlock_state, real_T q[3]);

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
/* End of code generation (_coder_controller_step_api.h) */
