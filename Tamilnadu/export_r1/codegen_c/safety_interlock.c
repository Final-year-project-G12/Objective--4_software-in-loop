/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 * File: safety_interlock.c
 *
 * MATLAB Coder version            : 23.2
 * C/C++ source code generated on  : 12-Nov-2026 21:57:54
 */

/* Include Files */
#include "safety_interlock.h"
#include "controller_step_data.h"

/* Function Definitions */
/*
 * SAFETY_INTERLOCK  Hardware-level fail-safe that sits between the learned
 *  policy and the actuators (obj4_hardware_interface_spec_r0.json,
 * "fail_safe").
 *
 *  The guard-band shield itself (72 C water / 62 C PCM) is evaluated inside
 *  the plant at every 150 s solver sub-step -- the twin's analogue of the
 *  10 s hardware control cycle -- exactly as in the Python environment, so the
 *  twin stays bit-for-bit comparable with the simulator. This block adds the
 *  two rules that live outside the physics:
 *
 *    * stale / missing sensor frame        -> command BYPASS (safe default)
 *    * hard limit exceeded despite shield  -> latch fault, BYPASS until a
 *                                             manual reset (block re-init)
 *
 *  interlock_state: 0 normal, 1 guard band active (shield will fire this
 *  hour), 2 stale-sensor fail-safe, 3 latched hard-limit fault.
 *
 * Arguments    : void
 * Return Type  : void
 */
void safety_interlock_init(void)
{
  fault_latched = false;
}

/*
 * File trailer for safety_interlock.c
 *
 * [EOF]
 */
