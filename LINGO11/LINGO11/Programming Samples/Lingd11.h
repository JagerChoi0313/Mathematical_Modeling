/*****************************************************************************/
/*   
/*    LINGO Version 11.0
/*
/*    LINGO DLL definitions header
/*
/*    Copyright (c) 2007
/*
/*    LINDO Systems, Inc.            312.988.7422
/*    1415 North Dayton St.          info@lindo.com
/*    Chicago, IL 60622              http://www.lindo.com
/*
/*    Last Updated: 10 Oct 2007
/*   
/*****************************************************************************/

#ifdef __cplusplus
extern "C" {
#endif

/*****************************************************************************/

#include <windows.h>  

/*****************************************************************************/

#define CALLTYPE __stdcall
#ifndef LINDO_INTERNAL
#define pLSenvLINGO void*
#endif
   
/*****************************************************************************/

typedef enum
{
   LSERR_NO_ERROR_LNG=0,
   LSERR_OUT_OF_MEMORY_LNG=1,
   LSERR_UNABLE_TO_OPEN_LOG_FILE_LNG=2,
   LSERR_INVALID_NULL_POINTER_LNG=3,
   LSERR_INVALID_INPUT_LNG=4,
   LSERR_INFO_NOT_AVAILABLE_LNG=5,
   LSERR_UNABLE_TO_COMPLETE_TASK_LNG=6,
   LSERR_JNI_CALLBACK_NOT_FOUND=1000
} LSlngErrorCode;

typedef enum
{
   LS_IINFO_VARIABLES_LNG=0,
   LS_IINFO_VARIABLES_INTEGER_LNG=1,
   LS_IINFO_VARIABLES_NONLINEAR_LNG=2,
   LS_IINFO_CONSTRAINTS_LNG=3,
   LS_IINFO_CONSTRAINTS_NONLINEAR_LNG=4,
   LS_IINFO_NONZEROS_LNG=5,
   LS_IINFO_NONZEROS_NONLINEAR_LNG=6,
   LS_IINFO_ITERATIONS_LNG=7,
   LS_IINFO_BRANCHES_LNG=8,
   LS_DINFO_SUMINF_LNG=9,
   LS_DINFO_OBJECTIVE_LNG=10,
   LS_DINFO_MIP_BOUND_LNG=11,
   LS_DINFO_MIP_BEST_OBJECTIVE_LNG=12
} LSlngCallbackInfoCode;

typedef enum
{
   LS_STATUS_GLOBAL_LNG=0,
   LS_STATUS_INFEASIBLE_LNG=1,
   LS_STATUS_UNBOUNDED_LNG=2,
   LS_STATUS_UNDETERMINED_LNG=3,
   LS_STATUS_FEASIBLE_LNG=4,
   LS_STATUS_INFORUNB_LNG=5,
   LS_STATUS_LOCAL_LNG=6,
   LS_STATUS_LOCAL_INFEASIBLE_LNG=7,
   LS_STATUS_CUTOFF_LNG=8,
   LS_STATUS_NUMERIC_ERROR_LNG=9
} LSlngStatusCode;

typedef int (CALLTYPE *lngCBFunc_t)( pLSenvLINGO pL, int nReserved, 
 void* pUserData);

typedef void (CALLTYPE *lngCBFuncError_t)( pLSenvLINGO pL, void* pUserData, 
 int nErrorCode, char* pcErrorText);

/*****************************************************************************/

int CALLTYPE LSclearPointersLng( pLSenvLINGO pEnv);

int CALLTYPE LScloseLogFileLng( pLSenvLINGO pL);

pLSenvLINGO CALLTYPE LScreateEnvLng();

int CALLTYPE LSdeleteEnvLng( pLSenvLINGO pL);

int CALLTYPE LSexecuteScriptLng( pLSenvLINGO pL, const char* pcScript);

int CALLTYPE LSgetCallbackInfoLng( pLSenvLINGO pL, int nObject, 
 void* pResult);

int CALLTYPE LSopenLogFileLng( pLSenvLINGO pL, const char* pcLogFile);

int CALLTYPE LSsetCallbackErrorLng( pLSenvLINGO pL, lngCBFuncError_t pcbf, 
 void* pvMyData);

int CALLTYPE LSsetCallbackSolverLng( pLSenvLINGO pL, 
 lngCBFunc_t pcbf, void* pvMyData);

int CALLTYPE LSsetPointerLng( pLSenvLINGO pEnv, void* pdPointer, 
 int* pnPointersNow);

/*****************************************************************************/

// These old routines are NOT thread safe and are now obsolete:

void __stdcall LGVBSCRIPT( char* pcScript, char* pcLogFile, 
 long* plNumberOfTransferAreas, double* dTransferAreas,
  long* plTransferPtrs, long* plErrorCode);

void __cdecl LGCSCRIPT( void* pArguments, long* pnArguments, 
 long* pnErrorCode);

typedef int (__stdcall *CALLBACKUSER) ( void* pModel, int nReserved, 
 void* pUserData);

void LSsetCallback( void* pReserved, CALLBACKUSER pCallback, void* pUserData);

void LSgetCallbackInfo( void* pModel, int nQuery, void* pResult);

/*****************************************************************************/

#ifdef __cplusplus
}
#endif

/*****************************************************************************/
