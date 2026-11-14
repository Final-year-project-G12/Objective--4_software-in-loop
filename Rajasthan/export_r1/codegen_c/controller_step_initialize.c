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
