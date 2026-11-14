/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 *
 * _coder_controller_step_info.c
 *
 * Code generation for function 'controller_step'
 *
 */

/* Include files */
#include "_coder_controller_step_info.h"
#include "emlrt.h"
#include "tmwtypes.h"

/* Function Declarations */
static const mxArray *c_emlrtMexFcnResolvedFunctionsI(void);

/* Function Definitions */
static const mxArray *c_emlrtMexFcnResolvedFunctionsI(void)
{
  const mxArray *nameCaptureInfo;
  const char_T *data[8] = {
      "789ced58cd53d34014df868f2928183c381cfb0fd411acc878e4a38cd54a8716b058a784"
      "74a1817c91848ffe07ce7890a3278f0e772f1e397af00fe0c2ddf1e4"
      "d1a309cda6e99b3e37d808dae99bd9d97d79bbeff7f27b9b7d4948e2693e410819274df9"
      "72b7d98ff9bae8f7026917684ff8fd00d0990c91c1b675ccfeceef65",
      "4377e8b1d3547449a3c14a45370f9c52c3a4b6ab58d436d4435abbb46c2b2a2d291a2d86"
      "95179ea66543a640f14cde78be4ee5bde28146acbadd8a500d2b011f"
      "9bc8fd0e72f88002f980f3189ef98778ccff1d0e1eb37b7c5b86aa52ab6a3bd40cf0cf11"
      "ff13c01ff49ff023cccf2f179bfaf0a56e3b96a2efb4eeef18f1cf74",
      "82d887012ec467f6c9d6a50bc19f176e2c8e3304272acf65240e11d85f2dbe5e7852c92a"
      "baa4a6ca54b25205cbd8a5b25359def23ae590a6d399aa6d6c3b4792"
      "45d38a9e560dc3acac48bb92edd425bda2498e2a6d5540beee6bbe7fde3e65f9e6dd0fc6"
      "eb18495ef6dfad8bc475e27df8fae9ed75e231b9293cecb988ba1fef",
      "217822b09773d3cbd9a3fceab4a9178ae5526eaa5cdb95975a71143838bc3808a25f97ff"
      "3364fdfffa5c775b0f4639f7c3ecb57dbd6a1aaa2237daf17bb51eb0"
      "318be333821395e712128708ec71ed9b56be9a5ba657ebc0526db35f0748fc756076e6e1"
      "71ee485bd137ac6c616a3df3684f9dc92df4eb40afd6018c3f11f4b6",
      "b44d9d465571bfc62cd590f77abd0e0c9078bf0b36903844608f6bdfc07cb18dd3abf5e0"
      "f1c7f7fd7a40e2af07995a7e7fe3d983fafaa2b1969fa3ceea9afc3c"
      "33d73bf560f656e7f52311fd9f8f76f62f003b01ffd34e473afb8dfa3f0ddb2fec7fda08"
      "b0339d9db74c583c93483c573fc7dbfd78ffd5d62dc934dd02560de1",
      "9d263be3f1f29a04f3b0bc9a89ceeb79791513bff72f807983feb559b7bd74db89db7eb8"
      "ed67a8794e24bd11d4364c60ee193e6b5087add3fab01fde5840ae0f"
      "105cbc79c9d0e471600fce47241f51cfc75487b8c2f309c89bd07e99f88f7950f7e3ee6b"
      "c42007648ba884461adb44213ad9e97a1cf6e909e33bd525df934087",
      "f3cf801df2cd9ed33879fd1b9c31bebe217c44e56b02e870fe1b60877c0d75c1cb55c79e"
      "04f515d927bc7318c68f9ec39cf5987f5efd6675ee5fc7df44fcdfe6"
      "e0f3f81d42de0bfbf9fcbbf84984dfa8ef8ba7887f01d8e1fbe209e2f7a6de1799fc020d"
      "a091fa",
      ""};
  nameCaptureInfo = NULL;
  emlrtNameCaptureMxArrayR2016a(&data[0], 7720U, &nameCaptureInfo);
  return nameCaptureInfo;
}

mxArray *emlrtMexFcnProperties(void)
{
  mxArray *xEntryPoints;
  mxArray *xInputs;
  mxArray *xResult;
  const char_T *epFieldName[7] = {
      "QualifiedName",    "NumberOfInputs", "NumberOfOutputs", "ConstantInputs",
      "ResolvedFilePath", "TimeStamp",      "Visible"};
  const char_T *propFieldName[7] = {
      "Version",      "ResolvedFunctions", "Checksum", "EntryPoints",
      "CoverageInfo", "IsPolymorphic",     "AuxData"};
  uint8_T v[216] = {
      0U,   1U,   73U,  77U,  0U,   0U,   0U,   0U,   14U,  0U,   0U,   0U,
      200U, 0U,   0U,   0U,   6U,   0U,   0U,   0U,   8U,   0U,   0U,   0U,
      2U,   0U,   0U,   0U,   0U,   0U,   0U,   0U,   5U,   0U,   0U,   0U,
      8U,   0U,   0U,   0U,   1U,   0U,   0U,   0U,   1U,   0U,   0U,   0U,
      1U,   0U,   0U,   0U,   0U,   0U,   0U,   0U,   5U,   0U,   4U,   0U,
      17U,  0U,   0U,   0U,   1U,   0U,   0U,   0U,   17U,  0U,   0U,   0U,
      67U,  108U, 97U,  115U, 115U, 69U,  110U, 116U, 114U, 121U, 80U,  111U,
      105U, 110U, 116U, 115U, 0U,   0U,   0U,   0U,   0U,   0U,   0U,   0U,
      14U,  0U,   0U,   0U,   112U, 0U,   0U,   0U,   6U,   0U,   0U,   0U,
      8U,   0U,   0U,   0U,   2U,   0U,   0U,   0U,   0U,   0U,   0U,   0U,
      5U,   0U,   0U,   0U,   8U,   0U,   0U,   0U,   1U,   0U,   0U,   0U,
      0U,   0U,   0U,   0U,   1U,   0U,   0U,   0U,   0U,   0U,   0U,   0U,
      5U,   0U,   4U,   0U,   14U,  0U,   0U,   0U,   1U,   0U,   0U,   0U,
      56U,  0U,   0U,   0U,   81U,  117U, 97U,  108U, 105U, 102U, 105U, 101U,
      100U, 78U,  97U,  109U, 101U, 0U,   77U,  101U, 116U, 104U, 111U, 100U,
      115U, 0U,   0U,   0U,   0U,   0U,   0U,   0U,   80U,  114U, 111U, 112U,
      101U, 114U, 116U, 105U, 101U, 115U, 0U,   0U,   0U,   0U,   72U,  97U,
      110U, 100U, 108U, 101U, 0U,   0U,   0U,   0U,   0U,   0U,   0U,   0U};
  xEntryPoints =
      emlrtCreateStructMatrix(1, 1, 7, (const char_T **)&epFieldName[0]);
  xInputs = emlrtCreateLogicalMatrix(1, 11);
  emlrtSetField(xEntryPoints, 0, "QualifiedName",
                emlrtMxCreateString("controller_step"));
  emlrtSetField(xEntryPoints, 0, "NumberOfInputs",
                emlrtMxCreateDoubleScalar(11.0));
  emlrtSetField(xEntryPoints, 0, "NumberOfOutputs",
                emlrtMxCreateDoubleScalar(3.0));
  emlrtSetField(xEntryPoints, 0, "ConstantInputs", xInputs);
  emlrtSetField(
      xEntryPoints, 0, "ResolvedFilePath",
      emlrtMxCreateString("D:\\Final Year "
                          "Project\\Objective--4_software-in-"
                          "loop\\Rajasthan\\matlab\\controller_step.m"));
  emlrtSetField(xEntryPoints, 0, "TimeStamp",
                emlrtMxCreateDoubleScalar(740299.1129398148));
  emlrtSetField(xEntryPoints, 0, "Visible", emlrtMxCreateLogicalScalar(true));
  xResult =
      emlrtCreateStructMatrix(1, 1, 7, (const char_T **)&propFieldName[0]);
  emlrtSetField(xResult, 0, "Version",
                emlrtMxCreateString("26.2.0.3433840 (R2026b) Update 1"));
  emlrtSetField(xResult, 0, "ResolvedFunctions",
                (mxArray *)c_emlrtMexFcnResolvedFunctionsI());
  emlrtSetField(xResult, 0, "Checksum",
                emlrtMxCreateString("jNY0LYWwWyBC6GGW1YMNb"));
  emlrtSetField(xResult, 0, "EntryPoints", xEntryPoints);
  emlrtSetField(xResult, 0, "AuxData",
                emlrtMxCreateRowVectorUINT8((const uint8_T *)&v, 216U));
  return xResult;
}

/* End of code generation (_coder_controller_step_info.c) */
