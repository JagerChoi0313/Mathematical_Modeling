/*********************************************************************
 **
 **    LINGO Version 11.0
 **
 **    LINGO DLL definitions header
 **
 **    Copyright (c) 2007
 **
 **    LINDO Systems, Inc.            312.988.7422
 **    1415 North Dayton St.          info@lindo.com
 **    Chicago, IL 60622              http://www.lindo.com
 **
 **    Lingd11.cs (LINGO DLL header for C# .NET)
 **
 **    Last Updated: 29 Feb 08
 **
 *********************************************************************/


using System;
using System.Text;
using System.Runtime.InteropServices;

public class lingo 
{

/*********************************************************************
 *                        Macro Definitions                       *
 *********************************************************************/

   public static int   LSERR_NO_ERROR_LNG                       = 0;
   public static int   LSERR_OUT_OF_MEMORY_LNG                  = 1;
   public static int   LSERR_UNABLE_TO_OPEN_LOG_FILE_LNG        = 2;
   public static int   LSERR_INVALID_NULL_POINTER_LNG           = 3;
   public static int   LSERR_INVALID_INPUT_LNG                  = 4;
   public static int   LSERR_INFO_NOT_AVAILABLE_LNG             = 5;

   public static int   LS_IINFO_VARIABLES_LNG                   = 0;
   public static int   LS_IINFO_VARIABLES_INTEGER_LNG           = 1;
   public static int   LS_IINFO_VARIABLES_NONLINEAR_LNG         = 2;
   public static int   LS_IINFO_CONSTRAINTS_LNG                 = 3;
   public static int   LS_IINFO_CONSTRAINTS_NONLINEAR_LNG       = 4;
   public static int   LS_IINFO_NONZEROS_LNG                    = 5;
   public static int   LS_IINFO_NONZEROS_NONLINEAR_LNG          = 6;
   public static int   LS_IINFO_ITERATIONS_LNG                  = 7;
   public static int   LS_IINFO_BRANCHES_LNG                    = 8;
   public static int   LS_DINFO_SUMINF_LNG                      = 9;
   public static int   LS_DINFO_OBJECTIVE_LNG                   =10;
   public static int   LS_DINFO_MIP_BOUND_LNG                   =11;
   public static int   LS_DINFO_MIP_BEST_OBJECTIVE_LNG          =12;

   public static int   LS_STATUS_GLOBAL_LNG                     = 0;
   public static int   LS_STATUS_INFEASIBLE_LNG                 = 1;
   public static int   LS_STATUS_UNBOUNDED_LNG                  = 2;
   public static int   LS_STATUS_UNDETERMINED_LNG               = 3;
   public static int   LS_STATUS_FEASIBLE_LNG                   = 4;
   public static int   LS_STATUS_INFORUNB_LNG                   = 5;
   public static int   LS_STATUS_LOCAL_LNG                      = 6;
   public static int   LS_STATUS_LOCAL_INFEASIBLE_LNG           = 7;
   public static int   LS_STATUS_CUTOFF_LNG                     = 8;
   public static int   LS_STATUS_NUMERIC_ERROR_LNG              = 9;

/*********************************************************************
 *                                                                   *
 *                        Function Prototypes                        *
 *                                                                   *
 *********************************************************************/

   [ DllImport( "lingd11.dll", EntryPoint = "LSclearPointersLng")]
      public static extern int LSclearPointersLng( IntPtr pLingoEnv);

   [ DllImport( "lingd11.dll", EntryPoint = "LScloseLogFileLng")]
      public static extern int LScloseLogFileLng( IntPtr pLingoEnv);

   [ DllImport( "lingd11.dll", EntryPoint = "LScreateEnvLng")]
      public static extern IntPtr LScreateEnvLng( );

   [ DllImport( "lingd11.dll", EntryPoint = "LSdeleteEnvLng")]
      public static extern int LSdeleteEnvLng( IntPtr pLingoEnv);

   [ DllImport( "lingd11.dll", EntryPoint = "LSexecuteScriptLng")]
      public static extern int LSexecuteScriptLng( IntPtr pLingoEnv,
         string pcScript);

   [ DllImport( "lingd11.dll", EntryPoint = "LSgetCallbackInfoLng")]
      public static extern int LSgetCallbackInfoLng( IntPtr pLingoEnv,
         int nObject, ref int pnResult);

   [ DllImport( "lingd11.dll", EntryPoint = "LSopenLogFileLng")]
      public static extern int LSopenLogFileLng( IntPtr pLingoEnv,
         string pcLogFile);

   [ DllImport( "lingd11.dll", EntryPoint = "LSsetCallbackSolverLng")]
      public static extern int LSsetCallbackSolverLng( IntPtr pLingoEnv,
         lingo.typCallback pSolverCallbackFunction, 
            [MarshalAs(UnmanagedType.AsAny)] object pMyData);

   [ DllImport( "lingd11.dll", EntryPoint = "LSsetPointerLng")]
      public static unsafe extern int LSsetPointerLng( IntPtr pLingoEnv,
         double* pdPointer, ref int pnPointersNow);

   [ DllImport("lingd11.dll", EntryPoint = "LSsetPointerLng")]
   public static unsafe extern int LSsetPointerCharLng( IntPtr pLingoEnv,
      byte* pcData, ref int pnPointersNow);

   public delegate int typCallback( IntPtr pLingoEnv, int nReserved,
      IntPtr pUserData);                                 

}

