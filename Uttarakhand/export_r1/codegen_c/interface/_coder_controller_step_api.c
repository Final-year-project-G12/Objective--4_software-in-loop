/*
 * Trial License - for use to evaluate programs for possible purchase as
 * an end-user only.
 *
 * _coder_controller_step_api.c
 *
 * Code generation for function 'controller_step'
 *
 */

/* Include files */
#include "_coder_controller_step_api.h"
#include "_coder_controller_step_mex.h"

/* Variable Definitions */
emlrtCTX emlrtRootTLSGlobal = NULL;

emlrtContext emlrtContextGlobal = {
    true,                                                 /* bFirstTime */
    false,                                                /* bInitialized */
    131691U,                                              /* fVersionInfo */
    NULL,                                                 /* fErrorFunction */
    "controller_step",                                    /* fFunctionName */
    NULL,                                                 /* fRTCallStack */
    false,                                                /* bDebugMode */
    {2045744189U, 2170104910U, 2743257031U, 4284093946U}, /* fSigWrd */
    NULL                                                  /* fSigMem */
};

/* Function Declarations */
static real32_T (*b_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[19];

static real_T c_emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                                 const char_T *identifier);

static real_T d_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                 const emlrtMsgIdentifier *parentId);

static real32_T (*e_emlrt_marshallIn(const emlrtStack *sp,
                                     const mxArray *nullptr,
                                     const char_T *identifier))[1216];

static void emlrtExitTimeCleanupDtorFcn(void *r);

static real32_T (*emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                                   const char_T *identifier))[19];

static const mxArray *emlrt_marshallOut(const real_T u);

static real32_T (*f_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[1216];

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
                                     const char_T *identifier))[128];

static real32_T (*l_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[128];

static real32_T (*m_emlrt_marshallIn(const emlrtStack *sp,
                                     const mxArray *nullptr,
                                     const char_T *identifier))[2];

static real32_T (*n_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[2];

static real_T (*o_emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                                   const char_T *identifier))[40];

static real_T (*p_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                   const emlrtMsgIdentifier *parentId))[40];

static real32_T (*q_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[19];

static real_T r_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                 const emlrtMsgIdentifier *msgId);

static real32_T (*s_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[1216];

static real32_T (*t_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[64];

static real32_T (*u_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[4096];

static real32_T (*v_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[128];

static real32_T (*w_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[2];

static real_T (*x_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                   const emlrtMsgIdentifier *msgId))[40];

/* Function Definitions */
static real32_T (*b_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[19]
{
  real32_T(*y)[19];
  y = q_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
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
                                     const char_T *identifier))[1216]
{
  emlrtMsgIdentifier thisId;
  real32_T(*y)[1216];
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  y = f_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId);
  emlrtDestroyArray(&nullptr);
  return y;
}

static void emlrtExitTimeCleanupDtorFcn(void *r)
{
  emlrtExitTimeCleanup(&emlrtContextGlobal);
}

static real32_T (*emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                                   const char_T *identifier))[19]
{
  emlrtMsgIdentifier thisId;
  real32_T(*y)[19];
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
                                     const emlrtMsgIdentifier *parentId))[1216]
{
  real32_T(*y)[1216];
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
                                     const char_T *identifier))[128]
{
  emlrtMsgIdentifier thisId;
  real32_T(*y)[128];
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  y = l_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId);
  emlrtDestroyArray(&nullptr);
  return y;
}

static real32_T (*l_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[128]
{
  real32_T(*y)[128];
  y = v_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static real32_T (*m_emlrt_marshallIn(const emlrtStack *sp,
                                     const mxArray *nullptr,
                                     const char_T *identifier))[2]
{
  emlrtMsgIdentifier thisId;
  real32_T(*y)[2];
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  y = n_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId);
  emlrtDestroyArray(&nullptr);
  return y;
}

static real32_T (*n_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                     const emlrtMsgIdentifier *parentId))[2]
{
  real32_T(*y)[2];
  y = w_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static real_T (*o_emlrt_marshallIn(const emlrtStack *sp, const mxArray *nullptr,
                                   const char_T *identifier))[40]
{
  emlrtMsgIdentifier thisId;
  real_T(*y)[40];
  thisId.fIdentifier = (const char_T *)identifier;
  thisId.fParent = NULL;
  thisId.bParentIsCell = false;
  y = p_emlrt_marshallIn(sp, emlrtAlias(nullptr), &thisId);
  emlrtDestroyArray(&nullptr);
  return y;
}

static real_T (*p_emlrt_marshallIn(const emlrtStack *sp, const mxArray *u,
                                   const emlrtMsgIdentifier *parentId))[40]
{
  real_T(*y)[40];
  y = x_emlrt_marshallIn(sp, emlrtAlias(u), parentId);
  emlrtDestroyArray(&u);
  return y;
}

static real32_T (*q_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[19]
{
  static const int32_T dims = 19;
  int32_T i;
  real32_T(*ret)[19];
  boolean_T b = false;
  emlrtCheckVsBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "single", false, 1U,
                            (const void *)&dims, &b, &i);
  ret = (real32_T(*)[19])emlrtMxGetData(src);
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
                                     const emlrtMsgIdentifier *msgId))[1216]
{
  static const int32_T dims[2] = {64, 19};
  int32_T iv[2];
  real32_T(*ret)[1216];
  boolean_T bv[2] = {false, false};
  emlrtCheckVsBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "single", false, 2U,
                            (const void *)&dims[0], &bv[0], &iv[0]);
  ret = (real32_T(*)[1216])emlrtMxGetData(src);
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
                                     const emlrtMsgIdentifier *msgId))[128]
{
  static const int32_T dims[2] = {2, 64};
  int32_T iv[2];
  real32_T(*ret)[128];
  boolean_T bv[2] = {false, false};
  emlrtCheckVsBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "single", false, 2U,
                            (const void *)&dims[0], &bv[0], &iv[0]);
  ret = (real32_T(*)[128])emlrtMxGetData(src);
  emlrtDestroyArray(&src);
  return ret;
}

static real32_T (*w_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                     const emlrtMsgIdentifier *msgId))[2]
{
  static const int32_T dims = 2;
  int32_T i;
  real32_T(*ret)[2];
  boolean_T b = false;
  emlrtCheckVsBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "single", false, 1U,
                            (const void *)&dims, &b, &i);
  ret = (real32_T(*)[2])emlrtMxGetData(src);
  emlrtDestroyArray(&src);
  return ret;
}

static real_T (*x_emlrt_marshallIn(const emlrtStack *sp, const mxArray *src,
                                   const emlrtMsgIdentifier *msgId))[40]
{
  static const int32_T dims = 40;
  real_T(*ret)[40];
  int32_T i;
  boolean_T b = false;
  emlrtCheckVsBuiltInR2012b((emlrtConstCTX)sp, msgId, src, "double", false, 1U,
                            (const void *)&dims, &b, &i);
  ret = (real_T(*)[40])emlrtMxGetData(src);
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
  real_T(*P)[40];
  real_T Tpcm_m;
  real_T Ttop_m;
  real_T action;
  real_T interlock_state;
  real_T margin;
  real_T sensors_ok;
  real32_T(*W2)[4096];
  real32_T(*W1)[1216];
  real32_T(*Wa)[128];
  real32_T(*b1)[64];
  real32_T(*b2)[64];
  real32_T(*obs)[19];
  real32_T(*ba)[2];
  st.tls = emlrtRootTLSGlobal;
  /* Marshall function inputs */
  obs = emlrt_marshallIn(&st, emlrtAlias(prhs[0]), "obs");
  Ttop_m = c_emlrt_marshallIn(&st, emlrtAliasP(prhs[1]), "Ttop_m");
  Tpcm_m = c_emlrt_marshallIn(&st, emlrtAliasP(prhs[2]), "Tpcm_m");
  sensors_ok = c_emlrt_marshallIn(&st, emlrtAliasP(prhs[3]), "sensors_ok");
  W1 = e_emlrt_marshallIn(&st, emlrtAlias(prhs[4]), "W1");
  b1 = g_emlrt_marshallIn(&st, emlrtAlias(prhs[5]), "b1");
  W2 = i_emlrt_marshallIn(&st, emlrtAlias(prhs[6]), "W2");
  b2 = g_emlrt_marshallIn(&st, emlrtAlias(prhs[7]), "b2");
  Wa = k_emlrt_marshallIn(&st, emlrtAlias(prhs[8]), "Wa");
  ba = m_emlrt_marshallIn(&st, emlrtAlias(prhs[9]), "ba");
  P = o_emlrt_marshallIn(&st, emlrtAlias(prhs[10]), "P");
  /* Invoke the target function */
  controller_step(*obs, Ttop_m, Tpcm_m, sensors_ok, *W1, *b1, *W2, *b2, *Wa,
                  *ba, *P, &action, &interlock_state, &margin);
  /* Marshall function outputs */
  plhs[0] = emlrt_marshallOut(action);
  if (nlhs > 1) {
    plhs[1] = emlrt_marshallOut(interlock_state);
  }
  if (nlhs > 2) {
    plhs[2] = emlrt_marshallOut(margin);
  }
}

void controller_step_atexit(void)
{
  emlrtStack st = {
      NULL, /* site */
      NULL, /* tls */
      NULL  /* prev */
  };
  mexFunctionCreateRootTLS();
  st.tls = emlrtRootTLSGlobal;
  emlrtPushHeapReferenceStackR2021a(
      &st, false, NULL, (void *)&emlrtExitTimeCleanupDtorFcn, NULL, NULL, NULL);
  emlrtEnterRtStackR2012b(&st);
  emlrtDestroyRootTLS(&emlrtRootTLSGlobal);
  controller_step_xil_terminate();
  controller_step_xil_shutdown();
  emlrtExitTimeCleanup(&emlrtContextGlobal);
}

void controller_step_initialize(void)
{
  emlrtStack st = {
      NULL, /* site */
      NULL, /* tls */
      NULL  /* prev */
  };
  mexFunctionCreateRootTLS();
  st.tls = emlrtRootTLSGlobal;
  emlrtClearAllocCountR2012b(&st, false, 0U, NULL);
  emlrtEnterRtStackR2012b(&st);
  emlrtFirstTimeR2012b(emlrtRootTLSGlobal);
}

void controller_step_terminate(void)
{
  emlrtDestroyRootTLS(&emlrtRootTLSGlobal);
}

/* End of code generation (_coder_controller_step_api.c) */
