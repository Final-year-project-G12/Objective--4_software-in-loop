/*
 * Trial License - for use to evaluate programs for possible purchase as
 * an end-user only.
 *
 * main.c
 *
 * Code generation for function 'main'
 *
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

/* Include files */
#include "main.h"
#include "controller_step.h"
#include "controller_step_initialize.h"
#include "controller_step_terminate.h"

/* Function Declarations */
static void argInit_19x1_real32_T(float result[19]);

static void argInit_2x1_real32_T(float result[2]);

static void argInit_2x64_real32_T(float result[128]);

static void argInit_40x1_real_T(double result[40]);

static void argInit_64x19_real32_T(float result[1216]);

static void argInit_64x1_real32_T(float result[64]);

static void argInit_64x64_real32_T(float result[4096]);

static float argInit_real32_T(void);

static double argInit_real_T(void);

/* Function Definitions */
static void argInit_19x1_real32_T(float result[19])
{
  int idx0;
  /* Loop over the array to initialize each element. */
  for (idx0 = 0; idx0 < 19; idx0++) {
    /* Set the value of the array element.
Change this value to the value that the application requires. */
    result[idx0] = argInit_real32_T();
  }
}

static void argInit_2x1_real32_T(float result[2])
{
  int idx0;
  /* Loop over the array to initialize each element. */
  for (idx0 = 0; idx0 < 2; idx0++) {
    /* Set the value of the array element.
Change this value to the value that the application requires. */
    result[idx0] = argInit_real32_T();
  }
}

static void argInit_2x64_real32_T(float result[128])
{
  int i;
  /* Loop over the array to initialize each element. */
  for (i = 0; i < 128; i++) {
    /* Set the value of the array element.
Change this value to the value that the application requires. */
    result[i] = argInit_real32_T();
  }
}

static void argInit_40x1_real_T(double result[40])
{
  int idx0;
  /* Loop over the array to initialize each element. */
  for (idx0 = 0; idx0 < 40; idx0++) {
    /* Set the value of the array element.
Change this value to the value that the application requires. */
    result[idx0] = argInit_real_T();
  }
}

static void argInit_64x19_real32_T(float result[1216])
{
  int i;
  /* Loop over the array to initialize each element. */
  for (i = 0; i < 1216; i++) {
    /* Set the value of the array element.
Change this value to the value that the application requires. */
    result[i] = argInit_real32_T();
  }
}

static void argInit_64x1_real32_T(float result[64])
{
  int idx0;
  /* Loop over the array to initialize each element. */
  for (idx0 = 0; idx0 < 64; idx0++) {
    /* Set the value of the array element.
Change this value to the value that the application requires. */
    result[idx0] = argInit_real32_T();
  }
}

static void argInit_64x64_real32_T(float result[4096])
{
  int i;
  /* Loop over the array to initialize each element. */
  for (i = 0; i < 4096; i++) {
    /* Set the value of the array element.
Change this value to the value that the application requires. */
    result[i] = argInit_real32_T();
  }
}

static float argInit_real32_T(void)
{
  return 0.0F;
}

static double argInit_real_T(void)
{
  return 0.0;
}

int main(int argc, char **argv)
{
  (void)argc;
  (void)argv;
  /* Initialize the application.
You do not need to do this more than one time. */
  controller_step_initialize();
  /* Invoke the entry-point functions.
You can call entry-point functions multiple times. */
  main_controller_step();
  /* Terminate the application.
You do not need to do this more than one time. */
  controller_step_terminate();
  return 0;
}

void main_controller_step(void)
{
  double dv[40];
  double Ttop_m_tmp;
  double action;
  double interlock_state;
  double margin;
  float fv2[4096];
  float fv1[1216];
  float fv3[128];
  float b1_tmp[64];
  float fv[19];
  float fv4[2];
  /* Initialize function 'controller_step' input arguments. */
  /* Initialize function input argument 'obs'. */
  Ttop_m_tmp = argInit_real_T();
  /* Initialize function input argument 'W1'. */
  /* Initialize function input argument 'b1'. */
  argInit_64x1_real32_T(b1_tmp);
  /* Initialize function input argument 'W2'. */
  /* Initialize function input argument 'b2'. */
  /* Initialize function input argument 'Wa'. */
  /* Initialize function input argument 'ba'. */
  /* Initialize function input argument 'P'. */
  /* Call the entry-point 'controller_step'. */
  argInit_19x1_real32_T(fv);
  argInit_64x19_real32_T(fv1);
  argInit_64x64_real32_T(fv2);
  argInit_2x64_real32_T(fv3);
  argInit_2x1_real32_T(fv4);
  argInit_40x1_real_T(dv);
  controller_step(fv, Ttop_m_tmp, Ttop_m_tmp, Ttop_m_tmp, fv1, b1_tmp, fv2,
                  b1_tmp, fv3, fv4, dv, &action, &interlock_state, &margin);
}

/* End of code generation (main.c) */
