(*********************************************************************
 **
 **    LINGO Version 11.0 Delphi Header
 **    Copyright (c) 2007
 **
 **    LINDO Systems, Inc.            312.988.7422
 **    1415 North Dayton St.          info@lindo.com
 **    Chicago, IL 60622              http://www.lindo.com
 **
 **    last updated: 11 Oct 2007
 **
 *********************************************************************)

unit Lingd11;

interface
uses
  SysUtils, Dialogs,Windows,Forms;

const
(*********************************************************************
 *                        Constant Definitions                       *
 *********************************************************************)


   LSERR_NO_ERROR_LNG=0;
   LSERR_OUT_OF_MEMORY_LNG=1;
   LSERR_UNABLE_TO_OPEN_LOG_FILE_LNG=2;
   LSERR_INVALID_NULL_POINTER_LNG=3;
   LSERR_INVALID_INPUT_LNG=4;
   LSERR_INFO_NOT_AVAILABLE_LNG=5;

   LS_IINFO_VARIABLES_LNG=0;
   LS_IINFO_VARIABLES_INTEGER_LNG=1;
   LS_IINFO_VARIABLES_NONLINEAR_LNG=2;
   LS_IINFO_CONSTRAINTS_LNG=3;
   LS_IINFO_CONSTRAINTS_NONLINEAR_LNG=4;
   LS_IINFO_NONZEROS_LNG=5;
   LS_IINFO_NONZEROS_NONLINEAR_LNG=6;
   LS_IINFO_ITERATIONS_LNG=7;
   LS_IINFO_BRANCHES_LNG=8;
   LS_DINFO_SUMINF_LNG=9;
   LS_DINFO_OBJECTIVE_LNG=10;
   LS_DINFO_MIP_BOUND_LNG=11;
   LS_DINFO_MIP_BEST_OBJECTIVE_LNG=12;

   LS_STATUS_GLOBAL_LNG=0;
   LS_STATUS_INFEAS_LNG=1;
   LS_STATUS_UNBOUND_LNG=2;
   LS_STATUS_UNDETERMINED_LNG=3;
   LS_STATUS_FEASIBLE_LNG=4;
   LS_STATUS_INFORUNB_LNG=5;
   LS_STATUS_LOCAL_LNG=6;
   LS_STATUS_LOCINF_LNG=7;
   LS_STATUS_CUTOFF_LNG=8;
   LS_STATUS_NUMERR_LNG=9;

(*********************************************************************
 *                                                                   *
 *                        Function Prototypes                        *
 *                                                                   *
 *********************************************************************)

type

  cbFunc_t = function  ( nLingo: Integer; nReserved: Integer;
   nUserData : Integer):Integer; stdcall;

function LScreateEnvLng () : Integer; stdCall; external 'Lingd11.dll';

function LSclearPointersLng( pnEnv: Integer): Integer; stdCall;
 external 'Lingd11.dll';

function LScloseLogFileLng( pnEnv: Integer): Integer; stdCall;
 external 'Lingd11.dll';

function LSdeleteEnvLng( pnEnv: Integer): Integer; stdCall;
 external 'Lingd11.dll';

function LSexecuteScriptLng( pnEnv: Integer; cScript: pChar): Integer;
 stdCall; external 'Lingd11.dll';

function LSgetCallbackInfoLng( pnEnv: Integer; nObject: Integer;
 var nResult: Integer): Integer; stdCall; overload; external 'Lingd11.dll';

function LSgetCallbackInfoLng( pnEnv: Integer; nObject: Integer; var dResult:
 Double): Integer; stdCall; overload; external 'Lingd11.dll';

function LSopenLogFileLng( pnEnv: Integer; cLogFile: pChar): Integer;
 stdCall; external 'Lingd11.dll';

function LSsetCallbackErrorLng( pnEnv: Integer; pcbf: pointer;
 pMyData: integer): Integer; stdCall; overload; external 'Lingd11.dll';

function LSsetCallbackSolverLng( pnEnv: Integer; pcbf: Pointer;
 pMyData: Integer): Integer; stdCall; external 'Lingd11.dll';

function LSsetPointerLng( pnEnv: Integer; var pdPointer: Double;
 var nPointersNow: Integer): Integer; stdCall; external 'Lingd11.dll';

implementation


end.

