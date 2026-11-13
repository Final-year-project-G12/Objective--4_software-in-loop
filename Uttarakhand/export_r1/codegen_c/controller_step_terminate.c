/*
 * Trial License - for use to evaluate programs for possible purchase as
 * an end-user only.
 *
 * controller_step_terminate.c
 *
 * Code generation for function 'controller_step_terminate'
 *
 */

/* Include files */
#include "controller_step_terminate.h"
#include "controller_step_data.h"
#include "omp.h"

/* Function Definitions */
void controller_step_terminate(void)
{
  omp_destroy_nest_lock(&controller_step_nestLockGlobal);
  isInitialized_controller_step = false;
}

/* End of code generation (controller_step_terminate.c) */
