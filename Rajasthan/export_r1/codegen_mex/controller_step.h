/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * controller_step.h
 *
 * Code generation for function 'controller_step'
 *
 */

#pragma once

/* Include files */
#include "rtwtypes.h"
#include "emlrt.h"
#include "mex.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Function Declarations */
void controller_step(const emlrtStack *sp, const real_T obs[17], real_T Tw_m,
                     real_T Tpcm_m, real_T sensors_ok, const real32_T W1[1088],
                     const real32_T b1[64], const real32_T W2[4096],
                     const real32_T b2[64], const real32_T W3[192],
                     const real32_T b3[3], const real_T P[80], real_T *action,
                     real_T *interlock_state, real_T q[3]);

/* End of code generation (controller_step.h) */
