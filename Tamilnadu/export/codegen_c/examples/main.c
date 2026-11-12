/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 * File: main.c
 *
 * MATLAB Coder version            : 23.2
 * C/C++ source code generated on  : 12-Nov-2026 21:56:06
 */

/*************************************************************************/
/* This automatically generated example C main file shows how to call    */
/* entry-point functions that MATLAB Coder generated. You must customize */
/* this file for your application. Do not modify this file directly.     */
/* Instead, make a copy of this file, modify it, and integrate it into   */
/* your development environment.                                         */
/*                                                                       */
/* This file initializes entry-point function arguments to a default     */
/* size and value before calling the entry-point functions. It does      */
/* not store or use any values returned from the entry-point functions.  */
/* If necessary, it does pre-allocate memory for returned values.        */
/* You can use this file as a starting point for a main function that    */
/* you can deploy in your application.                                   */
/*                                                                       */
/* After you copy the file, and before you deploy it, you must make the  */
/* following changes:                                                    */
/* * For variable-size function arguments, change the example sizes to   */
/* the sizes that your application requires.                             */
/* * Change the example values of function arguments to the values that  */
/* your application requires.                                            */
/* * If the entry-point functions return values, store these values or   */
/* otherwise use them as required by your application.                   */
/*                                                                       */
/*************************************************************************/

/* Include Files */
#include "main.h"
#include "controller_step.h"
#include "controller_step_terminate.h"

/* Function Declarations */
static void argInit_11x1_real_T(double result[11]);

static void argInit_256x11_real32_T(float result[2816]);

static void argInit_256x1_real32_T(float result[256]);

static void argInit_256x256_real32_T(float result[65536]);

static void argInit_41x1_real_T(double result[41]);

static float argInit_real32_T(void);

static double argInit_real_T(void);

/* Function Definitions */
/*
 * Arguments    : double result[11]
 * Return Type  : void
 */
static void argInit_11x1_real_T(double result[11])
{
  int idx0;
  /* Loop over the array to initialize each element. */
  for (idx0 = 0; idx0 < 11; idx0++) {
    /* Set the value of the array element.
Change this value to the value that the application requires. */
    result[idx0] = argInit_real_T();
  }
}

/*
 * Arguments    : float result[2816]
 * Return Type  : void
 */
static void argInit_256x11_real32_T(float result[2816])
{
  int i;
  /* Loop over the array to initialize each element. */
  for (i = 0; i < 2816; i++) {
    /* Set the value of the array element.
Change this value to the value that the application requires. */
    result[i] = argInit_real32_T();
  }
}

/*
 * Arguments    : float result[256]
 * Return Type  : void
 */
static void argInit_256x1_real32_T(float result[256])
{
  int idx0;
  /* Loop over the array to initialize each element. */
  for (idx0 = 0; idx0 < 256; idx0++) {
    /* Set the value of the array element.
Change this value to the value that the application requires. */
    result[idx0] = argInit_real32_T();
  }
}

/*
 * Arguments    : float result[65536]
 * Return Type  : void
 */
static void argInit_256x256_real32_T(float result[65536])
{
  int i;
  /* Loop over the array to initialize each element. */
  for (i = 0; i < 65536; i++) {
    /* Set the value of the array element.
Change this value to the value that the application requires. */
    result[i] = argInit_real32_T();
  }
}

/*
 * Arguments    : double result[41]
 * Return Type  : void
 */
static void argInit_41x1_real_T(double result[41])
{
  int idx0;
  /* Loop over the array to initialize each element. */
  for (idx0 = 0; idx0 < 41; idx0++) {
    /* Set the value of the array element.
Change this value to the value that the application requires. */
    result[idx0] = argInit_real_T();
  }
}

/*
 * Arguments    : void
 * Return Type  : float
 */
static float argInit_real32_T(void)
{
  return 0.0F;
}

/*
 * Arguments    : void
 * Return Type  : double
 */
static double argInit_real_T(void)
{
  return 0.0;
}

/*
 * Arguments    : int argc
 *                char **argv
 * Return Type  : int
 */
int main(int argc, char **argv)
{
  (void)argc;
  (void)argv;
  /* The initialize function is being called automatically from your entry-point
   * function. So, a call to initialize is not included here. */
  /* Invoke the entry-point functions.
You can call entry-point functions multiple times. */
  main_controller_step();
  /* Terminate the application.
You do not need to do this more than one time. */
  controller_step_terminate();
  return 0;
}

/*
 * Arguments    : void
 * Return Type  : void
 */
void main_controller_step(void)
{
  static float fv1[65536];
  double dv1[41];
  double dv[11];
  double Tw_m_tmp;
  double a_cont;
  double action;
  double interlock_state;
  float fv[2816];
  float b1_tmp[256];
  float fv2[256];
  /* Initialize function 'controller_step' input arguments. */
  /* Initialize function input argument 'obs'. */
  Tw_m_tmp = argInit_real_T();
  /* Initialize function input argument 'W1'. */
  /* Initialize function input argument 'b1'. */
  argInit_256x1_real32_T(b1_tmp);
  /* Initialize function input argument 'W2'. */
  /* Initialize function input argument 'b2'. */
  /* Initialize function input argument 'Wmu'. */
  /* Initialize function input argument 'P'. */
  /* Call the entry-point 'controller_step'. */
  argInit_11x1_real_T(dv);
  argInit_256x11_real32_T(fv);
  argInit_256x256_real32_T(fv1);
  argInit_256x1_real32_T(fv2);
  argInit_41x1_real_T(dv1);
  controller_step(dv, Tw_m_tmp, Tw_m_tmp, Tw_m_tmp, fv, b1_tmp, fv1, b1_tmp,
                  fv2, argInit_real32_T(), dv1, &action, &interlock_state,
                  &a_cont);
}

/*
 * File trailer for main.c
 *
 * [EOF]
 */
