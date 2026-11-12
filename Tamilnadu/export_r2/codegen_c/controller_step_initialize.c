/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 * File: controller_step_initialize.c
 *
 * MATLAB Coder version            : 23.2
 * C/C++ source code generated on  : 12-Nov-2026 21:58:24
 */

/* Include Files */
#include "controller_step_initialize.h"
#include "controller_step_data.h"
#include "safety_interlock.h"

/* Function Definitions */
/*
 * Arguments    : void
 * Return Type  : void
 */
void controller_step_initialize(void)
{
  safety_interlock_init();
  isInitialized_controller_step_lib = true;
}

/*
 * File trailer for controller_step_initialize.c
 *
 * [EOF]
 */
