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

#ifndef CONTROLLER_STEP_H
#define CONTROLLER_STEP_H

/* Include files */
#include "rtwtypes.h"
#include <stddef.h>
#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Function Declarations */
extern void controller_step(const double obs[17], double Tw_m, double Tpcm_m,
                            double sensors_ok, const float W1[1088],
                            const float b1[64], const float W2[4096],
                            const float b2[64], const float W3[192],
                            const float b3[3], const double P[80],
                            double *action, double *interlock_state,
                            double q[3]);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (controller_step.h) */
