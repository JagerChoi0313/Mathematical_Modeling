/*********************************************************************
 **
 **    LINGO Version 11.0 Java JNI Interface Definitions:
 **    Copyright (c) 2007
 **    Last update: 11 Oct 07
 **
 **    LINDO Systems, Inc.            312.988.7422
 **    1415 North Dayton St.          info@lindo.com
 **    Chicago, IL 60622              http://www.lindo.com
 **
 *********************************************************************/

package com.lindo;

public class Lingd11
{

/*********************************************************************
 *                        Function Definitions                       *
 *********************************************************************/

   public static native int LScloseLogFileLng( Object nLngEnv);

   public static native int LSclearPointersLng( Object nLngEnv);

   public static native Object LScreateEnvLng();

   public static native int LSdeleteEnvLng( Object nLngEnv);

   public static native int LSexecuteScriptLng( Object nLngEnv, String pcScript);

   public static native int LSgetCallbackInfoDoubleLng( Object nLngEnv, int nObject, double dCBInfo[]);

   public static native int LSgetCallbackInfoIntLng( Object nLngEnv, int nObject, int nCBInfo[]);

   public static native int LSopenLogFileLng( Object nLngEnv, String pcLogFile);

   public static native int LSsetCallbackErrorLng( Object nLngEnv, String fnCallback, Object objCBData);

   public static native int LSsetCallbackSolverLng( Object nLngEnv, String fnCallback, Object objCBData);

   public static native int LSsetPointerLng( Object nLngEnv, double dArray[], int nPointersNow[]);


/*********************************************************************
 *                        Constant Definitions                       *
 *********************************************************************/

   public static final int    LSERR_NO_ERROR_LNG                =    0;
   public static final int    LSERR_OUT_OF_MEMORY_LNG           =    1;
   public static final int    LSERR_UNABLE_TO_OPEN_LOG_FILE_LNG =    2;
   public static final int    LSERR_INVALID_NULL_POINTER_LNG    =    3;
   public static final int    LSERR_INVALID_INPUT_LNG           =    4;
   public static final int    LSERR_INFO_NOT_AVAILABLE_LNG      =    5;

   public static final int    LSERR_JNI_CALLBACK_NOT_FOUND      =  1000;

   public static final int    LS_IINFO_VARIABLES_LNG            =    0;
   public static final int    LS_IINFO_VARIABLES_INTEGER_LNG    =    1;
   public static final int    LS_IINFO_VARIABLES_NONLINEAR_LNG  =    2;
   public static final int    LS_IINFO_CONSTRAINTS_LNG          =    3;
   public static final int    LS_IINFO_CONSTRAINTS_NONLINEAR_LNG=    4;
   public static final int    LS_IINFO_NONZEROS_LNG             =    5;
   public static final int    LS_IINFO_NONZEROS_NONLINEAR_LNG   =    6;
   public static final int    LS_IINFO_ITERATIONS_LNG           =    7;
   public static final int    LS_IINFO_BRANCHES_LNG             =    8;
   public static final int    LS_DINFO_SUMINF_LNG               =    9;
   public static final int    LS_DINFO_OBJECTIVE_LNG            =   10;
   public static final int    LS_DINFO_MIP_BOUND_LNG            =   11;
   public static final int    LS_DINFO_MIP_BEST_OBJECTIVE_LNG   =   12;

   public static final int    LS_STATUS_GLOBAL_LNG              =    0;
   public static final int    LS_STATUS_INFEASIBLE_LNG          =    1;
   public static final int    LS_STATUS_UNBOUNDED_LNG           =    2;
   public static final int    LS_STATUS_UNDETERMINED_LNG        =    3;
   public static final int    LS_STATUS_FEASIBLE                =    4;
   public static final int    LS_STATUS_INFORUNB_LNG            =    5;
   public static final int    LS_STATUS_LOCAL_LNG               =    6;
   public static final int    LS_STATUS_LOCAL_INFEASIBLE_LNG    =    7;
   public static final int    LS_STATUS_CUTOFF_LNG              =    8;
   public static final int    LS_STATUS_NUMERIC_ERROR_LNG       =    9;

/*********************************************************************/

}
