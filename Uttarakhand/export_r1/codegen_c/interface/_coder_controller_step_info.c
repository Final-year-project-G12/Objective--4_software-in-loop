/*
 * Trial License - for use to evaluate programs for possible purchase as
 * an end-user only.
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
      "789ced58bd6fd340143fa71f4a0b2d2e1255c70e5d83f892e84c49508b425bd216248252"
      "c7b9244e2eb6653ba5616660a313336307864a2c8cfc13485dba7764"
      "64c44e7c8ef3e4d773499b82d5279dee9edfddfb3dffdef99d6d22ade62542c82ce9c997"
      "dbbd7ec6d765bf4f91418176c9efc780ce65828c0face3f64f7eaf1a",
      "ba43f79d9ea22b2d1aacd474b3ed6c754c6abb8a456d83edd14ad752d518ddd25ab41056"
      "5e785a2b1732058a67f2c62b75aa360bed16b1ea763f421656023e76"
      "91fb1d17f00105f201e7713cf32ff1b8ff5b023c6ef7f8b60cc6a855b21d6a06f8c788ff"
      "39e00ffa97fc08f32beb859e3ed9d56dc7d2f45afffef611ff5c2788",
      "7d12e0427c6e5fe85f3a49f9f3c28dc7f11dc189cbf34b240e19d8df64df2eb514872965"
      "cb309ca5e27ab9415547dba399cca3926d549d778a45339a9e618661"
      "16b71d47b194665dd12bc5deaa2248d4dd56cfaf687ff23c8bee03e37386a4bbfda27d22"
      "8d12eff3fc726594785cae0a0f7b1ee2eec379044f06f68d9da7d9a6",
      "f3b0d1dca858565d7dbf5368d4da2bfd38360438a23808a28fca7f529ee761ebffb4e03e"
      "b8dd348d9269304ded0ce227b5fef3318fe308c189cb731e894306f6"
      "a1f74b3f51ddad92d4ba7ff4f36b7994785c925ef7efd5f5fb8d55d6d8acb21cdbcfef31"
      "dbac66b3d7753f69751fe34d06bdad54a9d32969eed796c50cb599f4",
      "ba3f462ef6bdbf80c42103fbd0fb0526cadf3049adff1f4ebfa9a3c4e3f2bfd6ff3b089e"
      "0cecab9bacd6a86d3f5853cce7cf72e693fcda76ee31494efd5fbe11"
      "bd7e2aa6ffe3e968ff296027e03fd9e154b4dfb8ffc9b0fdc2ff934d013bd7799de5c2e3"
      "5940e2397ffd1ef4e3fd2f7b6529a6e99e5ba510de613a1a4f94d734",
      "9887e5d594a2d78bf22a4b67fb4f8179e3feb565b7bd76db81db7eb9ed77a8794e14bd13"
      "9c6998c0dc737cdea00e5bd4fab01fd138855c1f23b878f3d2a1c9b3"
      "c01ed447241f71ebe362445ce1f904e42d357899f88f7970de5f746f138de8a44618a1a4"
      "420cd226e533c7e1f9c38cc33e3de17c2f0ec9f702d0e1fc1fc00ef9",
      "e6cfe945f27a199c71be4e113ee2f235077438ff23b043be26cec94b9c3d868d3d09ce57"
      "649f88ea308c1fadc382f5987fd1f9cdcfb97f1d7f17f17f53802fe2"
      "7702792fbccee7e5e2a7117ee3be2f1e22fe53c00edf170f10bf57f5bec8e50fbbb9869"
      "f",
      ""};
  nameCaptureInfo = NULL;
  emlrtNameCaptureMxArrayR2016a(&data[0], 7680U, &nameCaptureInfo);
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
      emlrtMxCreateString("D:\\Objective--4_software-in-"
                          "loop\\Uttarakhand\\matlab\\controller_step.m"));
  emlrtSetField(xEntryPoints, 0, "TimeStamp",
                emlrtMxCreateDoubleScalar(740299.3806018519));
  emlrtSetField(xEntryPoints, 0, "Visible", emlrtMxCreateLogicalScalar(true));
  xResult =
      emlrtCreateStructMatrix(1, 1, 7, (const char_T **)&propFieldName[0]);
  emlrtSetField(xResult, 0, "Version",
                emlrtMxCreateString("26.2.0.3433840 (R2026b) Update 1"));
  emlrtSetField(xResult, 0, "ResolvedFunctions",
                (mxArray *)c_emlrtMexFcnResolvedFunctionsI());
  emlrtSetField(xResult, 0, "Checksum",
                emlrtMxCreateString("MPda7PLZx0NKDodwo3RIED"));
  emlrtSetField(xResult, 0, "EntryPoints", xEntryPoints);
  emlrtSetField(xResult, 0, "AuxData",
                emlrtMxCreateRowVectorUINT8((const uint8_T *)&v, 216U));
  return xResult;
}

/* End of code generation (_coder_controller_step_info.c) */
