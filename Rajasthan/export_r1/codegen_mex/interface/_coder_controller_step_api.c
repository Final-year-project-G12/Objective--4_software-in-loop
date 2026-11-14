/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * _coder_controller_step_api.c
 *
 * Code generation for function '_coder_controller_step_api'
 *
 */

/* Include files */
#include "_coder_controller_step_api.h"
#include "controller_step.h"
#include "controller_step_data.h"
#include "rt_nonfinite.h"

/* Function Declarations */
static real_T (*b_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                   const emlrtMsgIdentifier *parentId))[17];

static const mxArray *b_emlrt_marshallOut(real_T u[3]);

static real_T c_emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                                 const char_T *identifier);

static real_T d_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                 const emlrtMsgIdentifier *parentId);

static real32_T (*e_emlrt_marshallIn(const emlrtStack *sp,
                                     const mxArray *nullptr,
                                     const char_T *identifier))[1088];

static real_T (*emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                                 const char_T *identifier))[17];

static const mxArray *emlrt_marshallOut(const real_T u);

static real32_T (*f_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[1088];

static real32_T (*g_emlrt_marshallIn(const emlrtStack *sp,
                                     const mxArray *nullptr,
                                     const char_T *identifier))[64];

static real32_T (*h_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[64];

static real32_T (*i_emlrt_marshallIn(const emlrtStack *sp,
                                     const mxArray *nullptr,
                                     const char_T *identifier))[4096];

static real32_T (*j_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[4096];

static real32_T (*k_emlrt_marshallIn(const emlrtStack *sp,
                                     const mxArray *nullptr,
                                     const char_T *identifier))[192];

static real32_T (*l_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[192];

static real32_T (*m_emlrt_marshallIn(const emlrtStack *sp,
                                     const mxArray *nullptr,
                                     const char_T *identifier))[3];

static real32_T (*n_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[3];

static real_T (*o_emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                                   const char_T *identifier))[80];

static real_T (*p_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                   const emlrtMsgIdentifier *parentId))[80];

static real_T (*q_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                   const emlrtMsgIdentifier *msgId))[17];

static real_T r_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                 const emlrtMsgIdentifier *msgId);

static real32_T (*s_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[1088];

static real32_T (*t_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[64];

static real32_T (*u_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[4096];

static real32_T (*v_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[192];

static real32_T (*w_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[3];

static real_T (*x_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                   const emlrtMsgIdentifier *msgId))[80];

/* Function Definitions */
static real_T (*b_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                   const emlrtMsgIdentifier *parentId))[17]
{
  real_T(*y)[17];
  y = q_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static const mxArray *b_emlrt_marshallOut(real_T u[3])
{
  static const int32_T i = 0;
  static const int32_T i1 = 3;
  const mxArray *m;
  const mxArray *y;
  void *existingData;
  y = NULL;
  m = emlrtCreateNumericArray(1, (const void *)&i, mxDOUBLE_CLASS, mxREAL);
  existingData = emlrtMxGetData((mxArray *)m);
  if (existingData != (void *)&u[0]) {
    emlrtFreeMex(existingData);
  }
  emlrtMxSetData((mxArray *)m, &u[0]);
  emlrtSetDimensions((mxArray *)m, &i1, 1);
  emlrtAssign(&y, m);
  return y;
}

static real_T c_emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                                 const char_T *identifier)
{
  emlrtMsgIdentifier thisId;
  real_T y;
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  y = d_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId);
  emlrtDestroyArray(&nullptr);
  return y;
}

static real_T d_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                 const emlrtMsgIdentifier *parentId)
{
  real_T y;
  y = r_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static real32_T (*e_emlrt_marshallIn(const emlrtStack *sp,
                                     const mxArray *nullptr,
                                     const char_T *identifier))[1088]
{
  emlrtMsgIdentifier thisId;
  real32_T(*y)[1088];
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  y = f_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId);
  emlrtDestroyArray(&nullptr);
  return y;
}

static real_T (*emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                                 const char_T *identifier))[17]
{
  emlrtMsgIdentifier thisId;
  real_T(*y)[17];
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  y = b_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId);
  emlrtDestroyArray(&nullptr);
  return y;
}

static const mxArray *emlrt_marshallOut(const real_T u)
{
  const mxArray *m;
  const mxArray *y;
  y = NULL;
  m = emlrtCreateDoubleScalar(u);
  emlrtAssign(&y, m);
  return y;
}

static real32_T (*f_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[1088]
{
  real32_T(*y)[1088];
  y = s_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static real32_T (*g_emlrt_marshallIn(const emlrtStack *sp,
                                     const mxArray *nullptr,
                                     const char_T *identifier))[64]
{
  emlrtMsgIdentifier thisId;
  real32_T(*y)[64];
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  y = h_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId);
  emlrtDestroyArray(&nullptr);
  return y;
}

static real32_T (*h_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[64]
{
  real32_T(*y)[64];
  y = t_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static real32_T (*i_emlrt_marshallIn(const emlrtStack *sp,
                                     const mxArray *nullptr,
                                     const char_T *identifier))[4096]
{
  emlrtMsgIdentifier thisId;
  real32_T(*y)[4096];
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  y = j_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId);
  emlrtDestroyArray(&nullptr);
  return y;
}

static real32_T (*j_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[4096]
{
  real32_T(*y)[4096];
  y = u_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static real32_T (*k_emlrt_marshallIn(const emlrtStack *sp,
                                     const mxArray *nullptr,
                                     const char_T *identifier))[192]
{
  emlrtMsgIdentifier thisId;
  real32_T(*y)[192];
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  y = l_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId);
  emlrtDestroyArray(&nullptr);
  return y;
}

static real32_T (*l_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[192]
{
  real32_T(*y)[192];
  y = v_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static real32_T (*m_emlrt_marshallIn(const emlrtStack *sp,
                                     const mxArray *nullptr,
                                     const char_T *identifier))[3]
{
  emlrtMsgIdentifier thisId;
  real32_T(*y)[3];
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  y = n_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId);
  emlrtDestroyArray(&nullptr);
  return y;
}

static real32_T (*n_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[3]
{
  real32_T(*y)[3];
  y = w_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static real_T (*o_emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                                   const char_T *identifier))[80]
{
  emlrtMsgIdentifier thisId;
  real_T(*y)[80];
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  y = p_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId);
  emlrtDestroyArray(&nullptr);
  return y;
}

static real_T (*p_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                   const emlrtMsgIdentifier *parentId))[80]
{
  real_T(*y)[80];
  y = x_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static real_T (*q_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                   const emlrtMsgIdentifier *msgId))[17]
{
  static const int32_T dims = 17;
  real_T(*ret)[17];
  int32_T i;
  boolean_T b = false;
  emlrtCheckVsBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 1U,
                            (const void *)&dims, &b, &i);
  ret = (real_T(*)[17])emlrtMxGetData(src);
  emlrtDestroyArray(&src);
  return ret;
}

static real_T r_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                 const emlrtMsgIdentifier *msgId)
{
  static const int32_T dims = 0;
  real_T ret;
  emlrtCheckBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 0U,
                          (const void *)&dims);
  ret = *(real_T *)emlrtMxGetData(src);
  emlrtDestroyArray(&src);
  return ret;
}

static real32_T (*s_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[1088]
{
  static const int32_T dims[2] = {64, 17};
  int32_T iv[2];
  real32_T(*ret)[1088];
  boolean_T bv[2] = {false, false};
  emlrtCheckVsBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "single", false, 2U,
                            (const void *)&dims[0], &bv[0], &iv[0]);
  ret = (real32_T(*)[1088])emlrtMxGetData(src);
  emlrtDestroyArray(&src);
  return ret;
}

static real32_T (*t_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[64]
{
  static const int32_T dims = 64;
  int32_T i;
  real32_T(*ret)[64];
  boolean_T b = false;
  emlrtCheckVsBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "single", false, 1U,
                            (const void *)&dims, &b, &i);
  ret = (real32_T(*)[64])emlrtMxGetData(src);
  emlrtDestroyArray(&src);
  return ret;
}

static real32_T (*u_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[4096]
{
  static const int32_T dims[2] = {64, 64};
  int32_T iv[2];
  real32_T(*ret)[4096];
  boolean_T bv[2] = {false, false};
  emlrtCheckVsBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "single", false, 2U,
                            (const void *)&dims[0], &bv[0], &iv[0]);
  ret = (real32_T(*)[4096])emlrtMxGetData(src);
  emlrtDestroyArray(&src);
  return ret;
}

static real32_T (*v_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[192]
{
  static const int32_T dims[2] = {3, 64};
  int32_T iv[2];
  real32_T(*ret)[192];
  boolean_T bv[2] = {false, false};
  emlrtCheckVsBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "single", false, 2U,
                            (const void *)&dims[0], &bv[0], &iv[0]);
  ret = (real32_T(*)[192])emlrtMxGetData(src);
  emlrtDestroyArray(&src);
  return ret;
}

static real32_T (*w_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[3]
{
  static const int32_T dims = 3;
  int32_T i;
  real32_T(*ret)[3];
  boolean_T b = false;
  emlrtCheckVsBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "single", false, 1U,
                            (const void *)&dims, &b, &i);
  ret = (real32_T(*)[3])emlrtMxGetData(src);
  emlrtDestroyArray(&src);
  return ret;
}

static real_T (*x_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                   const emlrtMsgIdentifier *msgId))[80]
{
  static const int32_T dims = 80;
  real_T(*ret)[80];
  int32_T i;
  boolean_T b = false;
  emlrtCheckVsBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 1U,
                            (const void *)&dims, &b, &i);
  ret = (real_T(*)[80])emlrtMxGetData(src);
  emlrtDestroyArray(&src);
  return ret;
}

void controller_step_api(const mxArray *const prhs[11], int32_T nlhs,
                         const mxArray *plhs[3])
{
  emlrtStack st = {
      NULL, /* site */
      NULL, /* tls */
      NULL  /* prev */
  };
  real_T(*P)[80];
  real_T(*obs)[17];
  real_T(*q)[3];
  real_T Tpcm_m;
  real_T Tw_m;
  real_T action;
  real_T interlock_state;
  real_T sensors_ok;
  real32_T(*W2)[4096];
  real32_T(*W1)[1088];
  real32_T(*W3)[192];
  real32_T(*b1)[64];
  real32_T(*b2)[64];
  real32_T(*b3)[3];
  st.tls = emlrtRootTLSGlobal;
  q = (real_T(*)[3])mxMalloc(sizeof(real_T[3]));
  /* Marshall function inputs */
  obs = emlrt_marshallIn(&st, emlrtAlias(prhs[0]), "obs");
  Tw_m = c_emlrt_marshallIn(&st, emlrtAliasP(prhs[1]), "Tw_m");
  Tpcm_m = c_emlrt_marshallIn(&st, emlrtAliasP(prhs[2]), "Tpcm_m");
  sensors_ok = c_emlrt_marshallIn(&st, emlrtAliasP(prhs[3]), "sensors_ok");
  W1 = e_emlrt_marshallIn(&st, emlrtAlias(prhs[4]), "W1");
  b1 = g_emlrt_marshallIn(&st, emlrtAlias(prhs[5]), "b1");
  W2 = i_emlrt_marshallIn(&st, emlrtAlias(prhs[6]), "W2");
  b2 = g_emlrt_marshallIn(&st, emlrtAlias(prhs[7]), "b2");
  W3 = k_emlrt_marshallIn(&st, emlrtAlias(prhs[8]), "W3");
  b3 = m_emlrt_marshallIn(&st, emlrtAlias(prhs[9]), "b3");
  P = o_emlrt_marshallIn(&st, emlrtAlias(prhs[10]), "P");
  /* Invoke the target function */
  controller_step(&st, *obs, Tw_m, Tpcm_m, sensors_ok, *W1, *b1, *W2, *b2, *W3,
                  *b3, *P, &action, &interlock_state, *q);
  /* Marshall function outputs */
  plhs[0] = emlrt_marshallOut(action);
  if (nlhs > 1) {
    plhs[1] = emlrt_marshallOut(interlock_state);
  }
  if (nlhs > 2) {
    plhs[2] = b_emlrt_marshallOut(*q);
  }
}

/* End of code generation (_coder_controller_step_api.c) */
