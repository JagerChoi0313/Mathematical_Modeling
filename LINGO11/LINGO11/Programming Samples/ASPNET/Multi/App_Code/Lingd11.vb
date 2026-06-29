
Imports System
Imports System.Text
Imports System.Runtime.InteropServices


Public Class Lingo

    '*****************************************************************************/
    '*
    '*    LINGO Version 11.0
    '*
    '*    LINGO DLL definitions header for VB.NET
    '*
    '*    Copyright (c) 2007
    '*
    '*    LINDO Systems, Inc.            312.988.7422
    '*    1415 North Dayton St.          info@lindo.com
    '*    Chicago, IL 60622              http://www.lindo.com
    '*
    '*    Last Updated: 11 Oct 2007
    '*
    '*****************************************************************************/

    Public Enum LSerrorCodeLng
        LSERR_NO_ERROR_LNG = 0
        LSERR_OUT_OF_MEMORY_LNG = 1
        LSERR_UNABLE_TO_OPEN_LOG_FILE_LNG = 2
        LSERR_INVALID_NULL_POINTER_LNG = 3
        LSERR_INVALID_INPUT_LNG = 4
    End Enum

    Public Enum LScallbackInfoCodeLng
        LS_IINFO_VARIABLES_LNG = 0
        LS_IINFO_VARIABLES_INTEGER_LNG = 1
        LS_IINFO_VARIABLES_NONLINEAR_LNG = 2
        LS_IINFO_CONSTRAINTS_LNG = 3
        LS_IINFO_CONSTRAINTS_NONLINEAR_LNG = 4
        LS_IINFO_NONZEROS_LNG = 5
        LS_IINFO_NONZEROS_NONLINEAR_LNG = 6
        LS_IINFO_ITERATIONS_LNG = 7
        LS_IINFO_BRANCHES_LNG = 8
        LS_DINFO_SUMINF_LNG = 9
        LS_DINFO_OBJECTIVE_LNG = 10
        LS_DINFO_MIP_BOUND_LNG = 11
        LS_DINFO_MIP_BEST_OBJECTIVE_LNG = 12
    End Enum

    Public Enum LSstatusCodeLng
        LS_STATUS_GLOBAL_LNG = 0
        LS_STATUS_INFEASIBLE_LNG = 1
        LS_STATUS_UNBOUNDED_LNG = 2
        LS_STATUS_UNDETERMINED_LNG = 3
        LS_STATUS_FEASIBLE_LNG = 4
        LS_STATUS_INFORUNB_LNG = 5
        LS_STATUS_LOCAL_LNG = 6
        LS_STATUS_LOCAL_INFEASIBLE_LNG = 7
        LS_STATUS_CUTOFF_LNG = 8
        LS_STATUS_NUMERIC_ERROR_LNG = 9
    End Enum

    Public Declare Function LSclearPointersLng _
    Lib "LINGD11.DLL" (ByVal pLINGO As Integer)

    Public Declare Function LScloseLogFileLng _
    Lib "LINGD11.DLL" (ByVal pLINGO As Integer) As Integer

    Public Declare Function LScreateEnvLng _
    Lib "LINGD11.DLL" () As Integer

    Public Declare Function LSdeleteEnvLng _
    Lib "LINGD11.DLL" (ByVal pLINGO As Integer) As Integer

    Public Declare Function LSexecuteScriptLng _
    Lib "LINGD11.DLL" (ByVal pLINGO As Integer, ByVal cScript As String) As Integer

    Public Declare Function LSgetCallbackInfoDoubleLng _
    Lib "LINGD11.DLL" Alias "LSgetCallbackInfoLng" (ByVal pLINGO As Integer, _
    ByVal nObject As Integer, ByRef dResult As Double) As Integer

    Public Declare Function LSgetCallbackInfoIntegerLng _
    Lib "LINGD11.DLL" Alias "LSgetCallbackInfoLng" (ByVal pLINGO As Integer, _
    ByVal nObject As Integer, ByRef nResult As Integer) As Integer

    Public Declare Function LSopenLogFileLng _
    Lib "LINGD11.DLL" (ByVal pLINGO As Integer, ByVal cFname As String) As Integer

    Public Declare Function LSsetCallbackErrorLng _
    Lib "LINGD11.DLL" (ByVal pLINGO As Integer, ByVal pcbf As Integer, _
    ByRef pUserData As Double) As Integer

    Public Declare Function LSsetCallbackSolverLng _
    Lib "LINGD11.DLL" (ByVal pLINGO As Integer, ByVal pcbf As typCallbackSolver, _
    ByRef pUserData As Double) As Integer

    Public Declare Function LSsetPointerLng _
    Lib "LINGD11.DLL" (ByVal pLINGO As Integer, ByRef dObject As Double, _
    ByRef nPointersNow As Integer) As Integer

    Public Declare Function LSsetPointerLng2 _
    Lib "LINGD11.DLL" Alias "LSsetPointerLng" (ByVal pLINGO As Integer, ByVal pdObject As IntPtr, _
    ByRef nPointersNow As Integer) As Integer

    Public Delegate Function typCallbackError(ByVal model As Integer, _
     ByRef pData As Double, ByVal nErrorCode As Integer, _
     ByVal cErrorMessage As String) As Integer

    Public Delegate Function typCallbackSolver(ByVal model As Integer, _
     ByVal cbfAddress As Integer, ByRef pData As Double) As Integer

End Class