/*
 * Trial License - for use to evaluate programs for possible purchase as
 * an end-user only.
 *
 * controller_step_initialize.c
 *
 * Code generation for function 'controller_step_initialize'
 *
 */

/* Include files */
#include "controller_step_initialize.h"
#include "controller_step_data.h"
#include "safety_interlock.h"
#include "omp.h"

/* Function Definitions */
void controller_step_initialize(void)
{
  omp_init_nest_lock(&controller_step_nestLockGlobal);
  safety_interlock_init();
  isInitialized_controller_step = true;
}

/* End of code generation (controller_step_initialize.c) */
