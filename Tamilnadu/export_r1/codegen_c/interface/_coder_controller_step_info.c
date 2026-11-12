/*
 * Academic License - for use in teaching, academic research, and meeting
 * course requirements at degree granting institutions only.  Not for
 * government, commercial, or other organizational use.
 * File: _coder_controller_step_info.c
 *
 * MATLAB Coder version            : 23.2
 * C/C++ source code generated on  : 12-Nov-2026 21:57:54
 */

/* Include Files */
#include "_coder_controller_step_info.h"
#include "emlrt.h"
#include "tmwtypes.h"

/* Function Declarations */
static const mxArray *c_emlrtMexFcnResolvedFunctionsI(void);

/* Function Definitions */
/*
 * Arguments    : void
 * Return Type  : const mxArray *
 */
static const mxArray *c_emlrtMexFcnResolvedFunctionsI(void)
{
  const mxArray *nameCaptureInfo;
  const char_T *data[5] = {
      "789ced54cb4e1b311475102d08f5916ef80a54814a13d15d9a091228292d81b608578333"
      "b9094efc18d99e847c001bbae8f7f463ba67d9fe0193e73c242b9146"
      "4dd40a4ba33b57c7f6b9f75ceba0dc512d87107a81c6ebfed9383e9fe4f9495c43c995c6"
      "73a97db9e476f404ad27ce4df11f93e84961e0c68c134138cc4e3625",
      "a782087336f00129d092f5a039425a94c119e5508f271f86193f8c41b364080dffcbd7e0"
      "75eb0147ea5a4715b27832d3e3b7a5dff505f5b8b3e8914fe197956f"
      "e577f85c83d2b843749fe213018ea23dc00ee8ae913e2e55abb85ea9b945ec2bd901cf84"
      "1b39278c70d20cda0116d07765a383c32f04c3936fa2df7d57cb96e9",
      "13052e152e93e1759c18461a7828bc928c8172b501ff354ff6ef67ec7f6b4eff535c13cf"
      "f525a3de20c97f9591ffa9957f8c682ada0c62ef3f23dfad952f89af"
      "6cde91d0a351cfd3f9e5827da763b47f7314b7d4af11b42cbe9d9f1b7f96c9375dabe2bb"
      "b1dcb7e8bbddb6f0e55378c10f4cbf7670fc49bc2f9e97c207b9177c",
      "b92847757c9cc333af0e64c99775ffa3df67ebdfa6773e153569811984c519504c7add65"
      "f97d53068db8df679df7772b5f125fa1df27859e0cfc7ff57dc77bf5"
      "e8fbe82ff8be53326fbf9e7c2e7485d76aabddd3dd3dda71fe7ddf7f0037ce3939",
      ""};
  nameCaptureInfo = NULL;
  emlrtNameCaptureMxArrayR2016a(&data[0], 3328U, &nameCaptureInfo);
  return nameCaptureInfo;
}

/*
 * Arguments    : void
 * Return Type  : mxArray *
 */
mxArray *emlrtMexFcnProperties(void)
{
  mxArray *xEntryPoints;
  mxArray *xInputs;
  mxArray *xResult;
  const char_T *propFieldName[9] = {"Version",
                                    "ResolvedFunctions",
                                    "Checksum",
                                    "EntryPoints",
                                    "CoverageInfo",
                                    "IsPolymorphic",
                                    "PropertyList",
                                    "UUID",
                                    "ClassEntryPointIsHandle"};
  const char_T *epFieldName[8] = {
      "Name",     "NumberOfInputs", "NumberOfOutputs", "ConstantInputs",
      "FullPath", "TimeStamp",      "Constructor",     "Visible"};
  xEntryPoints =
      emlrtCreateStructMatrix(1, 1, 8, (const char_T **)&epFieldName[0]);
  xInputs = emlrtCreateLogicalMatrix(1, 11);
  emlrtSetField(xEntryPoints, 0, "Name",
                emlrtMxCreateString("controller_step"));
  emlrtSetField(xEntryPoints, 0, "NumberOfInputs",
                emlrtMxCreateDoubleScalar(11.0));
  emlrtSetField(xEntryPoints, 0, "NumberOfOutputs",
                emlrtMxCreateDoubleScalar(3.0));
  emlrtSetField(xEntryPoints, 0, "ConstantInputs", xInputs);
  emlrtSetField(
      xEntryPoints, 0, "FullPath",
      emlrtMxCreateString("C:\\Users\\jaswi\\OneDrive\\Desktop\\ALL\\SEM_"
                          "7\\project\\jammalamadugu\\new_"
                          "obj\\objective3\\objective4_software_in_loop\\matla"
                          "b\\controller_step.m"));
  emlrtSetField(xEntryPoints, 0, "TimeStamp",
                emlrtMxCreateDoubleScalar(740298.89151620376));
  emlrtSetField(xEntryPoints, 0, "Constructor",
                emlrtMxCreateLogicalScalar(false));
  emlrtSetField(xEntryPoints, 0, "Visible", emlrtMxCreateLogicalScalar(true));
  xResult =
      emlrtCreateStructMatrix(1, 1, 9, (const char_T **)&propFieldName[0]);
  emlrtSetField(xResult, 0, "Version",
                emlrtMxCreateString("23.2.0.3097123 (R2023b) Update 11"));
  emlrtSetField(xResult, 0, "ResolvedFunctions",
                (mxArray *)c_emlrtMexFcnResolvedFunctionsI());
  emlrtSetField(xResult, 0, "Checksum",
                emlrtMxCreateString("0jCWc36ApNX7Nycdsm1Fc"));
  emlrtSetField(xResult, 0, "EntryPoints", xEntryPoints);
  return xResult;
}

/*
 * File trailer for _coder_controller_step_info.c
 *
 * [EOF]
 */
