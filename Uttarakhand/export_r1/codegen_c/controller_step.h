/*
 * Trial License - for use to evaluate programs for possible purchase as
 * an end-user only.
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
extern void controller_step(const float obs[19], double Ttop_m, double Tpcm_m,
                            double sensors_ok, const float W1[1216],
                            const float b1[64], const float W2[4096],
                            const float b2[64], const float Wa[128],
                            const float ba[2], const double P[40],
                            double *action, double *interlock_state,
                            double *margin);

#ifdef __cplusplus
}
#endif

#endif
/* End of code generation (controller_step.h) */
