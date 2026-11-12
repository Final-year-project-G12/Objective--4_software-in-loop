/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 * File: controller_step.h
 *
 * MATLAB Coder version            : 23.2
 * C/C++ source code generated on  : 12-Nov-2026 21:58:24
 */

#ifndef CONTROLLER_STEP_H
#define CONTROLLER_STEP_H

/* Include Files */
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
extern void controller_step(const double obs[15], double Tw_m, double Tpcm_m,
                            double sensors_ok, const float W1[3840],
                            const float b1[256], const float W2[65536],
                            const float b2[256], const float Wmu[256],
                            float bmu, const double P[41], double *action,
                            double *interlock_state, double *a_cont);

#ifdef __cplusplus
}
#endif

#endif
/*
 * File trailer for controller_step.h
 *
 * [EOF]
 */
