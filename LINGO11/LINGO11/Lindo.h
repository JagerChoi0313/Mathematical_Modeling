/*********************************************************************
 **
 **    LINDO API Version 5.0
 **    Copyright (c) 2000-2007
 **
 **    LINDO Systems, Inc.            312.988.7422
 **    1415 North Dayton St.          info@lindo.com
 **    Chicago, IL 60622              http://www.lindo.com
 **
 **    @file     lindo.h  (C/C++ header)
 **    @modified on 02-18-2007
 **
 *********************************************************************/


#ifndef __LINDO_H__
#define __LINDO_H__

#ifdef __cplusplus
extern "C" {
#endif

#include <stdlib.h>
#include <stdio.h>
#include <float.h>


#ifdef _LINDO_DLL_

#define CALLTYPE       __stdcall
#define CALLBACKTYPE   __stdcall
#ifndef CDECL
#define CDECL          __cdecl
#endif

#else

#define CALLTYPE
#define CALLBACKTYPE
#ifndef CDECL
#define CDECL
#endif

#endif


struct LSenv;
typedef struct LSenv *pLSenv;

struct LSmodel;
typedef struct LSmodel *pLSmodel;

struct LSerr;
typedef struct LSerr *pLSerr;




/*********************************************************************
 *                        Constant Definitions                       *
 *********************************************************************/

#define LS_MIN                              +1
#define LS_MAX                              -1

#define LS_CONTYPE_GE                       'G'
#define LS_CONTYPE_LE                       'L'
#define LS_CONTYPE_EQ                       'E'
#define LS_CONTYPE_FR                       'N'

#define LS_CONETYPE_QUAD                    'Q'
#define LS_CONETYPE_RQUAD                   'R'

#define LS_VARTYPE_CONT                     'C'
#define LS_VARTYPE_BIN                      'B'
#define LS_VARTYPE_INT                      'I'

#define LS_INFINITY                         1.0E+30

#define LS_BASTYPE_BAS                      0
#define LS_BASTYPE_ATLO                    -1
#define LS_BASTYPE_ATUP                    -2
#define LS_BASTYPE_FNUL                    -3
#define LS_BASTYPE_SBAS                    -4

#define LS_UNFORMATTED_MPS                  0
#define LS_FORMATTED_MPS                    1
#define LS_UNFORMATTED_MPS_COMP             2
#define LS_FORMATTED_MPS_COMP               3

#define LS_SOLUTION_OPT                     0
#define LS_SOLUTION_MIP                     1
#define LS_SOLUTION_OPT_IPM                 2
#define LS_SOLUTION_OPT_OLD                 3
#define LS_SOLUTION_MIP_OLD                 4

#define LS_BASFILE_BIN                      1
#define LS_BASFILE_MPS                      2
#define LS_BASFILE_TXT                      3

#define LS_INT_PARAMETER_TYPE               4
#define LS_DOUBLE_PARAMETER_TYPE            8

#define LS_MAX_ERROR_MESSAGE_LENGTH         256


/*********************************************************************
 *                      Macro Type Definitions                       *
 *********************************************************************/

/* Solution or model status (1-20) */
typedef enum
{
   LS_STATUS_OPTIMAL                        = 1,
   LS_STATUS_BASIC_OPTIMAL                  = 2,
   LS_STATUS_INFEASIBLE                     = 3,
   LS_STATUS_UNBOUNDED                      = 4,
   LS_STATUS_FEASIBLE                       = 5,
   LS_STATUS_INFORUNB                       = 6,
   LS_STATUS_NEAR_OPTIMAL                   = 7,
   LS_STATUS_LOCAL_OPTIMAL                  = 8,
   LS_STATUS_LOCAL_INFEASIBLE               = 9,
   LS_STATUS_CUTOFF                         = 10,
   LS_STATUS_NUMERICAL_ERROR                = 11,
   LS_STATUS_UNKNOWN                        = 12,
   LS_STATUS_UNLOADED                       = 13,
   LS_STATUS_LOADED                         = 14
} LSstatus;


/* Parameter codes (21-999) */
typedef enum
{

/* General solver parameters (21-199) */
   LS_IPARAM_OBJSENSE                       = 22,
   LS_DPARAM_CALLBACKFREQ                   = 23,
   LS_DPARAM_OBJPRINTMUL                    = 24,
   LS_IPARAM_CHECK_FOR_ERRORS               = 25,
   LS_IPARAM_ALLOW_CNTRLBREAK               = 26,
   LS_IPARAM_DECOMPOSITION_TYPE             = 27,
   LS_IPARAM_SPLEX_PREP                     = 28,
   LS_IPARAM_SPLEX_SCALE                    = 29,
   LS_IPARAM_SPLEX_ITRLMT                   = 30,
   LS_IPARAM_SPLEX_PPRICING                 = 31,
   LS_IPARAM_SPLEX_REFACFRQ                 = 32,
   LS_IPARAM_BARRIER_SOLVER                 = 33,
   LS_IPARAM_PROB_TO_SOLVE                  = 34,
   LS_IPARAM_LP_PRINTLEVEL                  = 35,
   LS_IPARAM_MPS_OBJ_WRITESTYLE             = 36,
   LS_IPARAM_SPLEX_DPRICING                 = 37,
   LS_IPARAM_SOL_REPORT_STYLE               = 38,
   LS_IPARAM_INSTRUCT_LOADTYPE              = 39,
   LS_IPARAM_SPLEX_DUAL_PHASE               = 40,
   LS_IPARAM_LP_PRELEVEL                    = 41,
   LS_IPARAM_STRING_LENLMT                  = 42,
   LS_IPARAM_USE_NAMEDATA                   = 43,

   LS_IPARAM_SOLVER_IUSOL                   = 51,
   LS_IPARAM_SOLVER_TIMLMT                  = 52,
   LS_DPARAM_SOLVER_CUTOFFVAL               = 53,
   LS_DPARAM_SOLVER_FEASTOL                 = 54,
   LS_IPARAM_SOLVER_RESTART                 = 55,
   LS_IPARAM_SOLVER_IPMSOL                  = 56,
   LS_DPARAM_SOLVER_OPTTOL                  = 57,
   LS_IPARAM_SOLVER_USECUTOFFVAL            = 58,
   LS_IPARAM_SOLVER_PRE_ELIM_FILL           = 59,
   LS_DPARAM_SOLVER_TIMLMT                  = 60,
   LS_IPARAM_SOLVER_USE_CONCURRENT_OPT      = 61,

/* Internal parameters for the simplex method */
   LS_DPARAM_LP_MIN_FEASTOL                 = 4060,
   LS_DPARAM_LP_MAX_FEASTOL                 = 4061,
   LS_DPARAM_LP_MIN_OPTTOL                  = 4062,
   LS_DPARAM_LP_MAX_OPTTOL                  = 4063,
   LS_DPARAM_LP_MIN_PIVTOL                  = 4064,
   LS_DPARAM_LP_MAX_PIVTOL                  = 4065,
   LS_DPARAM_LP_AIJ_ZEROTOL                 = 4066,
   LS_DPARAM_LP_PIV_ZEROTOL                 = 4067,
   LS_DPARAM_LP_PIV_BIGTOL                  = 4068,
   LS_DPARAM_LP_BIGM                        = 4069,
   LS_DPARAM_LP_BNDINF                      = 4070,
   LS_DPARAM_LP_INFINITY                    = 4071,
   LS_IPARAM_LP_PPARTIAL                    = 4072,
   LS_IPARAM_LP_DPARTIAL                    = 4073,
   LS_IPARAM_LP_DRATIO                      = 4074,
   LS_IPARAM_LP_PRATIO                      = 4075,
   LS_IPARAM_LP_RATRANGE                    = 4076,
   LS_IPARAM_LP_DPSWITCH                    = 4077,
   LS_IPARAM_LP_PALLOC                      = 4078,
   LS_IPARAM_LP_PRTFG                       = 4079,
   LS_IPARAM_LP_OPRFREE                     = 4080,

/* Parameters for the IPM method*/

   LS_DPARAM_IPM_TOL_INFEAS                 = 150,
   LS_DPARAM_IPM_TOL_PATH                   = 151,
   LS_DPARAM_IPM_TOL_PFEAS                  = 152,
   LS_DPARAM_IPM_TOL_REL_STEP               = 153,
   LS_DPARAM_IPM_TOL_PSAFE                  = 154,
   LS_DPARAM_IPM_TOL_DFEAS                  = 155,
   LS_DPARAM_IPM_TOL_DSAFE                  = 156,
   LS_DPARAM_IPM_TOL_MU_RED                 = 157,
   LS_DPARAM_IPM_BASIS_REL_TOL_S            = 158,
   LS_DPARAM_IPM_BASIS_TOL_S                = 159,
   LS_DPARAM_IPM_BASIS_TOL_X                = 160,
   LS_DPARAM_IPM_BI_LU_TOL_REL_PIV          = 161,
   LS_IPARAM_IPM_MAX_ITERATIONS             = 162,
   LS_IPARAM_IPM_OFF_COL_TRH                = 163,
   LS_IPARAM_IPM_NUM_THREADS                = 164,

/* Nonlinear programming (NLP) parameters (200-299) */
   LS_IPARAM_NLP_SOLVE_AS_LP                = 200,
   LS_IPARAM_NLP_SOLVER                     = 201,
   LS_IPARAM_NLP_SUBSOLVER                  = 202,
   LS_IPARAM_NLP_PRINTLEVEL                 = 203,
   LS_DPARAM_NLP_PSTEP_FINITEDIFF           = 204,
   LS_IPARAM_NLP_DERIV_DIFFTYPE             = 205,
   LS_DPARAM_NLP_FEASTOL                    = 206,
   LS_DPARAM_NLP_REDGTOL                    = 207,
   LS_IPARAM_NLP_USE_CRASH                  = 208,
   LS_IPARAM_NLP_USE_STEEPEDGE              = 209,
   LS_IPARAM_NLP_USE_SLP                    = 210,
   LS_IPARAM_NLP_USE_SELCONEVAL             = 211,
   LS_IPARAM_NLP_PRELEVEL                   = 212,
   LS_IPARAM_NLP_ITRLMT                     = 213,
   LS_IPARAM_NLP_LINEARZ                    = 214,
   LS_IPARAM_NLP_LINEARITY                  = 215,
   LS_IPARAM_NLP_STARTPOINT                 = 216,
   LS_IPARAM_NLP_CONVEXRELAX                = 217,
   LS_IPARAM_NLP_CR_ALG_REFORM              = 218,
   LS_IPARAM_NLP_QUADCHK                    = 219,
   LS_IPARAM_NLP_AUTODERIV                  = 220,
   LS_IPARAM_NLP_MAXLOCALSEARCH             = 221,
   LS_IPARAM_NLP_CONVEX                     = 222,
   LS_IPARAM_NLP_CONOPT_VER                 = 223,
   LS_IPARAM_NLP_USE_LINDO_CRASH            = 224,
   LS_IPARAM_NLP_STALL_ITRLMT               = 225,
   LS_IPARAM_NLP_AUTOHESS                   = 226,

/* Mixed integer programming (MIP) parameters (300-399) */
   LS_IPARAM_MIP_TIMLIM                     = 300,
   LS_IPARAM_MIP_AOPTTIMLIM                 = 301,
   LS_IPARAM_MIP_LSOLTIMLIM                 = 302,
   LS_IPARAM_MIP_PRELEVEL                   = 303,
   LS_IPARAM_MIP_NODESELRULE                = 304,
   LS_DPARAM_MIP_INTTOL                     = 305,
   LS_DPARAM_MIP_RELINTTOL                  = 306,
   LS_DPARAM_MIP_RELOPTTOL                  = 307,
   LS_DPARAM_MIP_PEROPTTOL                  = 308,
   LS_IPARAM_MIP_MAXCUTPASS_TOP             = 309,
   LS_IPARAM_MIP_MAXCUTPASS_TREE            = 310,
   LS_DPARAM_MIP_ADDCUTPER                  = 311,
   LS_DPARAM_MIP_ADDCUTPER_TREE             = 312,
   LS_IPARAM_MIP_MAXNONIMP_CUTPASS          = 313,
   LS_IPARAM_MIP_CUTLEVEL_TOP               = 314,
   LS_IPARAM_MIP_CUTLEVEL_TREE              = 315,
   LS_IPARAM_MIP_CUTTIMLIM                  = 316,
   LS_IPARAM_MIP_CUTDEPTH                   = 317,
   LS_IPARAM_MIP_CUTFREQ                    = 318,
   LS_IPARAM_MIP_HEULEVEL                   = 319,
   LS_IPARAM_MIP_PRINTLEVEL                 = 320,
   LS_IPARAM_MIP_PREPRINTLEVEL              = 321,
   LS_DPARAM_MIP_CUTOFFOBJ                  = 322,
   LS_IPARAM_MIP_USECUTOFFOBJ               = 323,
   LS_IPARAM_MIP_STRONGBRANCHLEVEL          = 324,
   LS_IPARAM_MIP_TREEREORDERLEVEL           = 325,
   LS_IPARAM_MIP_BRANCHDIR                  = 326,
   LS_IPARAM_MIP_TOPOPT                     = 327,
   LS_IPARAM_MIP_REOPT                      = 328,
   LS_IPARAM_MIP_SOLVERTYPE                 = 329,
   LS_IPARAM_MIP_KEEPINMEM                  = 330,
   LS_IPARAM_MIP_BRANCHRULE                 = 331,
   LS_DPARAM_MIP_REDCOSTFIX_CUTOFF          = 332,
   LS_DPARAM_MIP_ADDCUTOBJTOL               = 333,
   LS_IPARAM_MIP_HEUMINTIMLIM               = 334,
   LS_IPARAM_MIP_BRANCH_PRIO                = 335,
   LS_IPARAM_MIP_SCALING_BOUND              = 336,
   LS_DPARAM_MIP_PSEUDOCOST_WEIGT           = 337,
   LS_DPARAM_MIP_LBIGM                      = 338,
   LS_DPARAM_MIP_DELTA                      = 339,
   LS_IPARAM_MIP_DUAL_SOLUTION              = 340,
   LS_IPARAM_MIP_BRANCH_LIMIT               = 341,
   LS_IPARAM_MIP_ITRLIM                     = 342,
   LS_IPARAM_MIP_AGGCUTLIM_TOP              = 343,
   LS_IPARAM_MIP_AGGCUTLIM_TREE             = 344,
   LS_IPARAM_MIP_SWITCHFAC_SIM_IPM          = 345,
   LS_IPARAM_MIP_ANODES_SWITCH_DF           = 346,
   LS_DPARAM_MIP_ABSOPTTOL                  = 347,
   LS_DPARAM_MIP_MINABSOBJSTEP              = 348,
   LS_IPARAM_MIP_PSEUDOCOST_RULE            = 349,
   LS_IPARAM_MIP_USE_ENUM_HEU               = 350,
   LS_IPARAM_MIP_PRELEVEL_TREE              = 351,
   LS_DPARAM_MIP_REDCOSTFIX_CUTOFF_TREE     = 352,
   LS_IPARAM_MIP_USE_INT_ZERO_TOL           = 353,
   LS_IPARAM_MIP_USE_CUTS_HEU               = 354,
   LS_DPARAM_MIP_BIGM_FOR_INTTOL            = 355,
   LS_IPARAM_MIP_STRONGBRANCHDONUM          = 366,
   LS_IPARAM_MIP_MAKECUT_INACTIVE_COUNT     = 367,
   LS_IPARAM_MIP_PRE_ELIM_FILL              = 368,
   LS_IPARAM_MIP_HEU_MODE                   = 369,
   LS_DPARAM_MIP_TIMLIM                     = 370,
   LS_DPARAM_MIP_AOPTTIMLIM                 = 371,
   LS_DPARAM_MIP_LSOLTIMLIM                 = 372,
   LS_DPARAM_MIP_CUTTIMLIM                  = 373,
   LS_DPARAM_MIP_HEUMINTIMLIM               = 374,
   LS_IPARAM_MIP_FP_MODE                    = 375,
   LS_DPARAM_MIP_FP_WEIGTH                  = 376,
   LS_IPARAM_MIP_FP_OPT_METHOD              = 377,
   LS_DPARAM_MIP_FP_TIMLIM                  = 378,
   LS_IPARAM_MIP_FP_ITRLIM                  = 379,
   LS_DPARAM_MIP_OBJ_THRESHOLD              = 380,

/* Global optimization (GOP) parameters (400-499) */
   LS_DPARAM_GOP_OPTTOL                     = 400,
   LS_DPARAM_GOP_FLTTOL                     = 401,
   LS_DPARAM_GOP_BOXTOL                     = 402,
   LS_DPARAM_GOP_WIDTOL                     = 403,
   LS_DPARAM_GOP_DELTATOL                   = 404,
   LS_DPARAM_GOP_BNDLIM                     = 405,
   LS_IPARAM_GOP_TIMLIM                     = 406,
   LS_IPARAM_GOP_OPTCHKMD                   = 407,
   LS_IPARAM_GOP_BRANCHMD                   = 408,
   LS_IPARAM_GOP_MAXWIDMD                   = 409,
   LS_IPARAM_GOP_PRELEVEL                   = 410,
   LS_IPARAM_GOP_POSTLEVEL                  = 411,
   LS_IPARAM_GOP_BBSRCHMD                   = 412,
   LS_IPARAM_GOP_DECOMPPTMD                 = 413,
   LS_IPARAM_GOP_ALGREFORMMD                = 414,
   LS_IPARAM_GOP_RELBRNDMD                  = 415,
   LS_IPARAM_GOP_PRINTLEVEL                 = 416,
   LS_IPARAM_GOP_USEBNDLIM                  = 417,
   LS_IPARAM_GOP_BRANCH_LIMIT               = 418,
   LS_IPARAM_GOP_CORELEVEL                  = 419,
   LS_IPARAM_GOP_OPT_MODE                   = 420,
   LS_IPARAM_GOP_HEU_MODE                   = 421,
   LS_IPARAM_GOP_SUBOUT_MODE                = 422,
   LS_IPARAM_GOP_USE_NLPSOLVE               = 423,
   LS_IPARAM_GOP_LSOLBRANLIM                = 424,
   LS_IPARAM_GOP_LPSOPT                     = 425,

/* License information parameters (500-549) */
   LS_IPARAM_LIC_CONSTRAINTS                = 500,
   LS_IPARAM_LIC_VARIABLES                  = 501,
   LS_IPARAM_LIC_INTEGERS                   = 502,
   LS_IPARAM_LIC_NONLINEARVARS              = 503,
   LS_IPARAM_LIC_GOP_INTEGERS               = 504,
   LS_IPARAM_LIC_GOP_NONLINEARVARS          = 505,
   LS_IPARAM_LIC_DAYSTOEXP                  = 506,
   LS_IPARAM_LIC_DAYSTOTRIALEXP             = 507,
   LS_IPARAM_LIC_NONLINEAR                  = 508,
   LS_IPARAM_LIC_EDUCATIONAL                = 509,
   LS_IPARAM_LIC_RUNTIME                    = 510,
   LS_IPARAM_LIC_NUMUSERS                   = 511,
   LS_IPARAM_LIC_BARRIER                    = 512,
   LS_IPARAM_LIC_GLOBAL                     = 513,
   LS_IPARAM_LIC_PLATFORM                   = 514,
   LS_IPARAM_LIC_MIP                        = 515,

/* Model analysis parameters (550-600) */
   LS_IPARAM_IIS_ANALYZE_LEVEL              = 550,
   LS_IPARAM_IUS_ANALYZE_LEVEL              = 551,
   LS_IPARAM_IIS_TOPOPT                     = 552,
   LS_IPARAM_IIS_REOPT                      = 553,
   LS_IPARAM_IIS_USE_SFILTER                = 554,
   LS_IPARAM_IIS_PRINT_LEVEL                = 555,
   LS_IPARAM_IIS_INFEAS_NORM                = 556,
   LS_IPARAM_IIS_ITER_LIMIT                 = 557,
   LS_IPARAM_IIS_TIME_LIMIT                 = 558,
   LS_IPARAM_IIS_METHOD                     = 559,
   LS_IPARAM_IIS_USE_EFILTER                = 560,
   LS_IPARAM_IIS_USE_GOP                    = 561,

/* Version info */
   LS_IPARAM_VER_MAJOR                      = 990,
   LS_IPARAM_VER_MINOR                      = 991,
   LS_IPARAM_VER_BUILD                      = 992,
   LS_IPARAM_VER_REVISION                   = 993,

/* Last card for parameters */
   LS_IPARAM_VER_NUMBER                     = 999
} LSparameter;

/* Math operator codes (1000-1500) */
typedef enum
{
   EP_NO_OP                                 = 0000,
   EP_PLUS                                  = 1001,
   EP_MINUS                                 = 1002,
   EP_MULTIPLY                              = 1003,
   EP_DIVIDE                                = 1004,
   EP_POWER                                 = 1005,
   EP_EQUAL                                 = 1006,
   EP_NOT_EQUAL                             = 1007,
   EP_LTOREQ                                = 1008,
   EP_GTOREQ                                = 1009,
   EP_LTHAN                                 = 1010,
   EP_GTHAN                                 = 1011,
   EP_AND                                   = 1012,
   EP_OR                                    = 1013,
   EP_NOT                                   = 1014,
   EP_PERCENT                               = 1015,
   EP_POSATE                                = 1016,
   EP_NEGATE                                = 1017,
   EP_ABS                                   = 1018,
   EP_SQRT                                  = 1019,
   EP_LOG                                   = 1020,
   EP_LN                                    = 1021,
   EP_PI                                    = 1022,
   EP_SIN                                   = 1023,
   EP_COS                                   = 1024,
   EP_TAN                                   = 1025,
   EP_ATAN2                                 = 1026,
   EP_ATAN                                  = 1027,
   EP_ASIN                                  = 1028,
   EP_ACOS                                  = 1029,
   EP_EXP                                   = 1030,
   EP_MOD                                   = 1031,
   EP_FALSE                                 = 1032,
   EP_TRUE                                  = 1033,
   EP_IF                                    = 1034,
   EP_PSN                                   = 1035,
   EP_PSL                                   = 1036,
   EP_LGM                                   = 1037,
   EP_SIGN                                  = 1038,
   EP_FLOOR                                 = 1039,
   EP_FPA                                   = 1040,
   EP_FPL                                   = 1041,
   EP_PEL                                   = 1042,
   EP_PEB                                   = 1043,
   EP_PPS                                   = 1044,
   EP_PPL                                   = 1045,
   EP_PTD                                   = 1046,
   EP_PCX                                   = 1047,
   EP_WRAP                                  = 1048,
   EP_PBN                                   = 1049,
   EP_PFS                                   = 1050,
   EP_PFD                                   = 1051,
   EP_PHG                                   = 1052,
   EP_RAND                                  = 1053,
   EP_USER                                  = 1054,
   EP_SUM                                   = 1055,
   EP_AVG                                   = 1056,
   EP_MIN                                   = 1057,
   EP_MAX                                   = 1058,
   EP_NPV                                   = 1059,
   EP_VAND                                  = 1060,
   EP_VOR                                   = 1061,
   EP_PUSH_NUM                              = 1062,
   EP_PUSH_VAR                              = 1063,
   EP_NORMDENS                              = 1064,
   EP_NORMINV                               = 1065,
   EP_TRIAINV                               = 1066,
   EP_EXPOINV                               = 1067,
   EP_UNIFINV                               = 1068,
   EP_MULTINV                               = 1069,
   EP_USRCOD                                = 1070,
   EP_SUMPROD                               = 1071,
   EP_SUMIF                                 = 1072,
   EP_VLOOKUP                               = 1073,
   EP_VPUSH_NUM                             = 1074,
   EP_VPUSH_VAR                             = 1075,
   EP_VMULT                                 = 1076,
   EP_SQR                                   = 1077,
   EP_SINH                                  = 1078,
   EP_COSH                                  = 1079,
   EP_TANH                                  = 1080,
   EP_ASINH                                 = 1081,
   EP_ACOSH                                 = 1082,
   EP_ATANH                                 = 1083,
   EP_LOGB                                  = 1084,
   EP_LOGX                                  = 1085,
   EP_LNX                                   = 1086,
   EP_TRUNC                                 = 1087,
   EP_NORMSINV                              = 1088,
   EP_INT                                   = 1089,
   EP_PUSH_STR                              = 1090,
   EP_VPUSH_STR                             = 1091,
   EP_PUSH_SVAR                             = 1092
} LSoperator;


/* Model and solution information codes ( 1200-1399) */
typedef enum
{
/* Model statistics (1200-1249)*/
   LS_IINFO_NUM_QCP_CONS                    = 1195,
   LS_IINFO_NUM_CONT_CONS                   = 1196,
   LS_IINFO_NUM_INT_CONS                    = 1197,
   LS_IINFO_NUM_BIN_CONS                    = 1198,
   LS_IINFO_NUM_QCP_VARS                    = 1199,
   LS_IINFO_NUM_CONS                        = 1200,
   LS_IINFO_NUM_VARS                        = 1201,
   LS_IINFO_NUM_NONZ                        = 1202,
   LS_IINFO_NUM_BIN                         = 1203,
   LS_IINFO_NUM_INT                         = 1204,
   LS_IINFO_NUM_CONT                        = 1205,
   LS_IINFO_NUM_QC_NONZ                     = 1206,
   LS_IINFO_NUM_NLP_NONZ                    = 1207,
   LS_IINFO_NUM_NLPOBJ_NONZ                 = 1208,
   LS_IINFO_NUM_RDCONS                      = 1209,
   LS_IINFO_NUM_RDVARS                      = 1210,
   LS_IINFO_NUM_RDNONZ                      = 1211,
   LS_IINFO_NUM_RDINT                       = 1212,
   LS_IINFO_LEN_VARNAMES                    = 1213,
   LS_IINFO_LEN_CONNAMES                    = 1214,
   LS_IINFO_NUM_NLP_CONS                    = 1215,
   LS_IINFO_NUM_NLP_VARS                    = 1216,
   LS_IINFO_NUM_SUF_ROWS                    = 1217,
   LS_IINFO_NUM_IIS_ROWS                    = 1218,
   LS_IINFO_NUM_SUF_BNDS                    = 1219,
   LS_IINFO_NUM_IIS_BNDS                    = 1220,
   LS_IINFO_NUM_SUF_COLS                    = 1221,
   LS_IINFO_NUM_IUS_COLS                    = 1222,
   LS_IINFO_NUM_CONES                       = 1223,
   LS_IINFO_NUM_CONE_NONZ                   = 1224,
   LS_IINFO_LEN_CONENAMES                   = 1225,
   LS_DINFO_INST_VAL_MIN_COEF               = 1226,
   LS_IINFO_INST_VARNDX_MIN_COEF            = 1227,
   LS_IINFO_INST_CONNDX_MIN_COEF            = 1228,
   LS_DINFO_INST_VAL_MAX_COEF               = 1229,
   LS_IINFO_INST_VARNDX_MAX_COEF            = 1230,
   LS_IINFO_INST_CONNDX_MAX_COEF            = 1231,
   LS_IINFO_NUM_VARS_CARD                   = 1232,
   LS_IINFO_NUM_VARS_SOS1                   = 1233,
   LS_IINFO_NUM_VARS_SOS2                   = 1234,
   LS_IINFO_NUM_VARS_SOS3                   = 1235,
   LS_IINFO_NUM_VARS_SCONT                  = 1236,
   LS_IINFO_NUM_CONS_L                      = 1237,
   LS_IINFO_NUM_CONS_E                      = 1238,
   LS_IINFO_NUM_CONS_G                      = 1239,
   LS_IINFO_NUM_CONS_R                      = 1240,
   LS_IINFO_NUM_CONS_N                      = 1241,
   LS_IINFO_NUM_VARS_LB                     = 1242,
   LS_IINFO_NUM_VARS_UB                     = 1243,
   LS_IINFO_NUM_VARS_LUB                    = 1244,
   LS_IINFO_NUM_VARS_FR                     = 1245,
   LS_IINFO_NUM_VARS_FX                     = 1246,
   LS_IINFO_NUM_INST_CODES                  = 1247,
   LS_IINFO_NUM_INST_REAL_NUM               = 1248,
   LS_IINFO_NUM_NUM_SVAR                    = 1249,

/* LP and NLP related info (1250-1299)*/
   LS_IINFO_METHOD                          = 1250,
   LS_DINFO_POBJ                            = 1251,
   LS_DINFO_DOBJ                            = 1252,
   LS_DINFO_PINFEAS                         = 1253,
   LS_DINFO_DINFEAS                         = 1254,
   LS_IINFO_MODEL_STATUS                    = 1255,
   LS_IINFO_PRIMAL_STATUS                   = 1256,
   LS_IINFO_DUAL_STATUS                     = 1257,
   LS_IINFO_BASIC_STATUS                    = 1258,
   LS_IINFO_BAR_ITER                        = 1259,
   LS_IINFO_SIM_ITER                        = 1260,
   LS_IINFO_NLP_ITER                        = 1261,
   LS_IINFO_ELAPSED_TIME                    = 1262,
   LS_DINFO_MSW_POBJ                        = 1263,
   LS_IINFO_MSW_PASS                        = 1264,
   LS_IINFO_MSW_NSOL                        = 1265,
   LS_IINFO_IPM_STATUS                      = 1266,
   LS_DINFO_IPM_POBJ                        = 1267,
   LS_DINFO_IPM_DOBJ                        = 1268,
   LS_DINFO_IPM_PINFEAS                     = 1269,
   LS_DINFO_IPM_DINFEAS                     = 1270,
   LS_IINFO_NLP_CALL_FUN                    = 1271,
   LS_IINFO_NLP_CALL_DEV                    = 1272,
   LS_IINFO_NLP_CALL_HES                    = 1273,

/* MIP and MINLP related info (1300-1349) */
   LS_IINFO_MIP_STATUS                      = 1300,
   LS_DINFO_MIP_OBJ                         = 1301,
   LS_DINFO_MIP_BESTBOUND                   = 1302,
   LS_IINFO_MIP_SIM_ITER                    = 1303,
   LS_IINFO_MIP_BAR_ITER                    = 1304,
   LS_IINFO_MIP_NLP_ITER                    = 1305,
   LS_IINFO_MIP_BRANCHCOUNT                 = 1306,
   LS_IINFO_MIP_NEWIPSOL                    = 1307,
   LS_IINFO_MIP_LPCOUNT                     = 1308,
   LS_IINFO_MIP_ACTIVENODES                 = 1309,
   LS_IINFO_MIP_LTYPE                       = 1310,
   LS_IINFO_MIP_AOPTTIMETOSTOP              = 1311,
   LS_IINFO_MIP_NUM_TOTAL_CUTS              = 1312,
   LS_IINFO_MIP_GUB_COVER_CUTS              = 1313,
   LS_IINFO_MIP_FLOW_COVER_CUTS             = 1314,
   LS_IINFO_MIP_LIFT_CUTS                   = 1315,
   LS_IINFO_MIP_PLAN_LOC_CUTS               = 1316,
   LS_IINFO_MIP_DISAGG_CUTS                 = 1317,
   LS_IINFO_MIP_KNAPSUR_COVER_CUTS          = 1318,
   LS_IINFO_MIP_LATTICE_CUTS                = 1319,
   LS_IINFO_MIP_GOMORY_CUTS                 = 1320,
   LS_IINFO_MIP_COEF_REDC_CUTS              = 1321,
   LS_IINFO_MIP_GCD_CUTS                    = 1322,
   LS_IINFO_MIP_OBJ_CUT                     = 1323,
   LS_IINFO_MIP_BASIS_CUTS                  = 1324,
   LS_IINFO_MIP_CARDGUB_CUTS                = 1325,
   LS_IINFO_MIP_CLIQUE_CUTS                 = 1326,
   LS_IINFO_MIP_CONTRA_CUTS                 = 1327,
   LS_IINFO_MIP_GUB_CONS                    = 1328,
   LS_IINFO_MIP_GLB_CONS                    = 1329,
   LS_IINFO_MIP_PLANTLOC_CONS               = 1330,
   LS_IINFO_MIP_DISAGG_CONS                 = 1331,
   LS_IINFO_MIP_SB_CONS                     = 1332,
   LS_IINFO_MIP_IKNAP_CONS                  = 1333,
   LS_IINFO_MIP_KNAP_CONS                   = 1334,
   LS_IINFO_MIP_NLP_CONS                    = 1335,
   LS_IINFO_MIP_CONT_CONS                   = 1336,
   LS_DINFO_MIP_TOT_TIME                    = 1347,
   LS_DINFO_MIP_OPT_TIME                    = 1348,
   LS_DINFO_MIP_HEU_TIME                    = 1349,
   LS_IINFO_MIP_SOLSTATUS_LAST_BRANCH       = 1350,
   LS_DINFO_MIP_SOLOBJVAL_LAST_BRANCH       = 1351,
   LS_IINFO_MIP_HEU_LEVEL                   = 1352,
   LS_DINFO_MIP_PFEAS                       = 1353,
   LS_DINFO_MIP_INTPFEAS                    = 1354,

/* GOP related info (1650-1799) */
   LS_DINFO_GOP_OBJ                         = 1650,
   LS_IINFO_GOP_SIM_ITER                    = 1651,
   LS_IINFO_GOP_BAR_ITER                    = 1652,
   LS_IINFO_GOP_NLP_ITER                    = 1653,
   LS_DINFO_GOP_BESTBOUND                   = 1654,
   LS_IINFO_GOP_STATUS                      = 1655,
   LS_IINFO_GOP_LPCOUNT                     = 1656,
   LS_IINFO_GOP_NLPCOUNT                    = 1657,
   LS_IINFO_GOP_MIPCOUNT                    = 1658,
   LS_IINFO_GOP_NEWSOL                      = 1659,
   LS_IINFO_GOP_BOX                         = 1660,
   LS_IINFO_GOP_BBITER                      = 1661,
   LS_IINFO_GOP_SUBITER                     = 1662,
   LS_IINFO_GOP_MIPBRANCH                   = 1663,
   LS_IINFO_GOP_ACTIVEBOXES                 = 1664,
   LS_IINFO_GOP_TOT_TIME                    = 1665,
   LS_IINFO_GOP_MAXDEPTH                    = 1666,
   LS_DINFO_GOP_PFEAS                       = 1667,
   LS_DINFO_GOP_INTPFEAS                    = 1668,

/* Progress info during callbacks */
   LS_DINFO_SUB_OBJ                         = 1700,
   LS_DINFO_SUB_PINF                        = 1701,
   LS_DINFO_CUR_OBJ                         = 1702,
   LS_IINFO_CUR_ITER                        = 1703,
   LS_DINFO_CUR_BEST_BOUND                  = 1704,
   LS_IINFO_CUR_STATUS                      = 1705,
   LS_IINFO_CUR_LP_COUNT                    = 1706,
   LS_IINFO_CUR_BRANCH_COUNT                = 1707,
   LS_IINFO_CUR_ACTIVE_COUNT                = 1708,
   LS_IINFO_CUR_NLP_COUNT                   = 1709,
   LS_IINFO_CUR_MIP_COUNT                   = 1710,
   LS_IINFO_CUR_CUT_COUNT                   = 1711,


/* Model generation progress info (1800+)*/
   LS_DINFO_GEN_PERCENT                     = 1800,
   LS_IINFO_GEN_NONZ_TTL                    = 1801,
   LS_IINFO_GEN_NONZ_NL                     = 1802,
   LS_IINFO_GEN_ROW_NL                      = 1803,
   LS_IINFO_GEN_VAR_NL                      = 1804,


/* IIS-IUS info */
   LS_IINFO_IIS_BAR_ITER                    = 1850,
   LS_IINFO_IIS_SIM_ITER                    = 1851,
   LS_IINFO_IIS_NLP_ITER                    = 1852,
   LS_IINFO_IIS_TOT_TIME                    = 1853,
   LS_IINFO_IIS_ACT_NODE                    = 1854,
   LS_IINFO_IIS_LPCOUNT                     = 1855,
   LS_IINFO_IIS_NLPCOUNT                    = 1856,
   LS_IINFO_IIS_MIPCOUNT                    = 1857,

   LS_IINFO_IUS_BAR_ITER                    = 1860,
   LS_IINFO_IUS_SIM_ITER                    = 1861,
   LS_IINFO_IUS_NLP_ITER                    = 1862,
   LS_IINFO_IUS_TOT_TIME                    = 1863,
   LS_IINFO_IUS_ACT_NODE                    = 1864,
   LS_IINFO_IUS_LPCOUNT                     = 1865,
   LS_IINFO_IUS_NLPCOUNT                    = 1866,
   LS_IINFO_IUS_MIPCOUNT                    = 1867,


/* Presolve info    */
   LS_IINFO_PRE_NUM_RED                     = 1900,
   LS_IINFO_PRE_TYPE_RED                    = 1901,
   LS_IINFO_PRE_NUM_RDCONS                  = 1902,
   LS_IINFO_PRE_NUM_RDVARS                  = 1903,
   LS_IINFO_PRE_NUM_RDNONZ                  = 1904,
   LS_IINFO_PRE_NUM_RDINT                   = 1905,

/* Error info */
   LS_IINFO_ERR_OPTIM                       = 1999,


/* Misc info */
   LS_SINFO_MODEL_FILENAME                  = 2000,
   LS_SINFO_MODEL_SOURCE                    = 2001,
   LS_IINFO_MODEL_TYPE                      = 2002,
   LS_SINFO_CORE_FILENAME                   = 2003,
   LS_SINFO_STOC_FILENAME                   = 2004,
   LS_SINFO_TIME_FILENAME                   = 2005

} LSinformation;



/* Error codes (2001-2299) */
typedef enum
{
   LSERR_NO_ERROR                           = 0000,
   LSERR_OUT_OF_MEMORY                      = 2001,
   LSERR_CANNOT_OPEN_FILE                   = 2002,
   LSERR_BAD_MPS_FILE                       = 2003,
   LSERR_BAD_CONSTRAINT_TYPE                = 2004,
   LSERR_BAD_MODEL                          = 2005,
   LSERR_BAD_SOLVER_TYPE                    = 2006,
   LSERR_BAD_OBJECTIVE_SENSE                = 2007,
   LSERR_BAD_MPI_FILE                       = 2008,
   LSERR_INFO_NOT_AVAILABLE                 = 2009,
   LSERR_ILLEGAL_NULL_POINTER               = 2010,
   LSERR_UNABLE_TO_SET_PARAM                = 2011,
   LSERR_INDEX_OUT_OF_RANGE                 = 2012,
   LSERR_ERRMSG_FILE_NOT_FOUND              = 2013,
   LSERR_VARIABLE_NOT_FOUND                 = 2014,
   LSERR_INTERNAL_ERROR                     = 2015,
   LSERR_ITER_LIMIT                         = 2016,
   LSERR_TIME_LIMIT                         = 2017,
   LSERR_NOT_CONVEX                         = 2018,
   LSERR_NUMERIC_INSTABILITY                = 2019,
   LSERR_STEP_TOO_SMALL                     = 2021,
   LSERR_USER_INTERRUPT                     = 2023,
   LSERR_PARAMETER_OUT_OF_RANGE             = 2024,
   LSERR_ERROR_IN_INPUT                     = 2025,
   LSERR_TOO_SMALL_LICENSE                  = 2026,
   LSERR_NO_VALID_LICENSE                   = 2027,
   LSERR_NO_METHOD_LICENSE                  = 2028,
   LSERR_NOT_SUPPORTED                      = 2029,
   LSERR_MODEL_ALREADY_LOADED               = 2030,
   LSERR_MODEL_NOT_LOADED                   = 2031,
   LSERR_INDEX_DUPLICATE                    = 2032,
   LSERR_INSTRUCT_NOT_LOADED                = 2033,
   LSERR_OLD_LICENSE                        = 2034,
   LSERR_NO_LICENSE_FILE                    = 2035,
   LSERR_BAD_LICENSE_FILE                   = 2036,
   LSERR_MIP_BRANCH_LIMIT                   = 2037,
   LSERR_GOP_FUNC_NOT_SUPPORTED             = 2038,
   LSERR_GOP_BRANCH_LIMIT                   = 2039,
   LSERR_BAD_DECOMPOSITION_TYPE             = 2040,
   LSERR_BAD_VARIABLE_TYPE                  = 2041,
   LSERR_BASIS_BOUND_MISMATCH               = 2042,
   LSERR_BASIS_COL_STATUS                   = 2043,
   LSERR_BASIS_INVALID                      = 2044,
   LSERR_BASIS_ROW_STATUS                   = 2045,
   LSERR_BLOCK_OF_BLOCK                     = 2046,
   LSERR_BOUND_OUT_OF_RANGE                 = 2047,
   LSERR_COL_BEGIN_INDEX                    = 2048,
   LSERR_COL_INDEX_OUT_OF_RANGE             = 2049,
   LSERR_COL_NONZCOUNT                      = 2050,
   LSERR_INVALID_ERRORCODE                  = 2051,
   LSERR_ROW_INDEX_OUT_OF_RANGE             = 2052,
   LSERR_TOTAL_NONZCOUNT                    = 2053,
   LSERR_MODEL_NOT_LINEAR                   = 2054,
   LSERR_CHECKSUM                           = 2055,
   LSERR_USER_FUNCTION_NOT_FOUND            = 2056,
   LSERR_TRUNCATED_NAME_DATA                = 2057,
   LSERR_ILLEGAL_STRING_OPERATION           = 2058,
   LSERR_STRING_ALREADY_LOADED              = 2059,
   LSERR_STRING_NOT_LOADED                  = 2060,
   LSERR_STRING_LENGTH_LIMIT                = 2061,
   LSERR_DATA_TERM_EXIST                    = 2062,
   LSERR_NOT_SORTED_ORDER                   = 2063,
   LSERR_INST_MISS_ELEMENTS                 = 2064,
   LSERR_INST_TOO_SHORT                     = 2065,
   LSERR_INST_INVALID_BOUND                 = 2066,
   LSERR_INST_SYNTAX_ERROR                  = 2067,
   LSERR_COL_TOKEN_NOT_FOUND                = 2068,
   LSERR_ROW_TOKEN_NOT_FOUND                = 2069,
   LSERR_NAME_TOKEN_NOT_FOUND               = 2070,
   LSERR_LAST_ERROR                         = 2071
} LSerrorCode;


/* Callback locations */
typedef enum
{
   LSLOC_PRIMAL                             = 0,
   LSLOC_DUAL                               = 1,
   LSLOC_BARRIER                            = 2,
   LSLOC_CROSSOVER                          = 3,
   LSLOC_CONOPT                             = 4,
   LSLOC_MIP                                = 5,
   LSLOC_LOCAL_OPT                          = 6,
   LSLOC_GEN_START                          = 7,
   LSLOC_GEN_PROCESSING                     = 8,
   LSLOC_GEN_END                            = 9,
   LSLOC_GOP                                = 10,
   LSLOC_EXIT_SOLVER                        = 11,
   LSLOC_PRESOLVE                           = 12,
   LSLOC_MSW                                = 13,
   LSLOC_FUNC_CALC                          = 14,
   LSLOC_IISIUS                             = 15
} LSlocation;


typedef enum
{
   LS_METHOD_FREE                           = 0,
   LS_METHOD_PSIMPLEX                       = 1,
   LS_METHOD_DSIMPLEX                       = 2,
   LS_METHOD_BARRIER                        = 3,
   LS_METHOD_NLP                            = 4,
   LS_METHOD_MIP                            = 5,
   LS_METHOD_MULTIS                         = 6,
   LS_METHOD_GOP                            = 7,
   LS_METHOD_IIS                            = 8,
   LS_METHOD_IUS                            = 9
} LSOptMethod;


typedef enum
{
  LS_NMETHOD_FREE                           = 4,
  LS_NMETHOD_CONOPT                         = 7,
  LS_NMETHOD_MSW_GRG                        = 9
} LSNLPOptMethod;


typedef enum
{
  LS_PROB_SOLVE_FREE                        = 0,
  LS_PROB_SOLVE_PRIMAL                      = 1,
  LS_PROB_SOLVE_DUAL                        = 2,
  LS_BAR_METHOD_FREE                        = 4,
  LS_BAR_METHOD_INTPNT                      = 5,
  LS_BAR_METHOD_CONIC                       = 6,
  LS_BAR_METHOD_QCONE                       = 7,

  LSSOL_BASIC_PRIMAL                        = 11,
  LSSOL_BASIC_DUAL                          = 12,
  LSSOL_BASIC_SLACK                         = 13,
  LSSOL_BASIC_REDCOST                       = 14,
  LSSOL_INTERIOR_PRIMAL                     = 15,
  LSSOL_INTERIOR_DUAL                       = 16,
  LSSOL_INTERIOR_SLACK                      = 17,
  LSSOL_INTERIOR_REDCOST                    = 18

} LSsolverOptions;



/* Model types */
typedef enum
{
   /* linear programs                          */
   LS_LP                                    = 10,

   /* quadratic programs                       */
   LS_QP                                    = 11,

   /* second-order-cone programs               */
   LS_SOCP                                  = 12,

   /* semidefinite programs                    */
   LS_SDP                                   = 13,

   /* nonlinear programs                       */
   LS_NLP                                   = 14,

   /* mixed-integer linear programs            */
   LS_MILP                                  = 15,

   /* mixed-integer quadratic programs         */
   LS_MIQP                                  = 16,

   /* mixed-integer second-order-cone programs */
   LS_MISOCP                                = 17,

   /* mixed-integer semidefinite programs      */
   LS_MISDP                                 = 18,

   /* mixed-integer nonlinear programs         */
   LS_MINLP                                 = 19
} LSmodelTypes;



typedef enum
{
  LS_LINK_BLOCKS_FREE                       = 0,
  LS_LINK_BLOCKS_SELF                       = 1,
  LS_LINK_BLOCKS_NONE                       = 2,
  LS_LINK_BLOCKS_COLS                       = 3,
  LS_LINK_BLOCKS_ROWS                       = 4,
  LS_LINK_BLOCKS_BOTH                       = 5
} LSdecompostionOptions;


/* Controls the way objective function and
 * objective sense are printed when writing
 * LS_MAX type problems in MPS format.
 */
typedef enum
{
  LS_MPS_USE_MAX_NOTE                       = 0,
  LS_MPS_USE_MAX_CARD                       = 1,
  LS_MPS_USE_MAX_FLIP                       = 2
} LSwriteOptions;


/* Finite differences methods */
typedef enum
{
  LS_DERIV_FREE                             = 0,
  LS_DERIV_FORWARD_DIFFERENCE               = 1,
  LS_DERIV_BACKWARD_DIFFERENCE              = 2,
  LS_DERIV_CENTER_DIFFERENCE                = 3
} LSderivMethod;

/* MIP Sets
 *  SOS1: S={x_1,...,x_p}  only one x_j can be different from zero
 *  SOS2: S={x_1,...,x_p}  at most two x_j can be different from zero
 *                         and  when they are they have to be adjacent
 *  SOS3: S={x_1,...,x_p}  @sum(j: x_j      )  = 1;  x_j >=0,
 *  CARD: S={x_1,...,x_p}  @sum(j: sign(x_j)) <= k;  x_j >=0
 */
typedef enum
{
  LS_MIP_SET_CARD                           = 4,
  LS_MIP_SET_SOS1                           = 1,
  LS_MIP_SET_SOS2                           = 2,
  LS_MIP_SET_SOS3                           = 3

} LSsetType;




/* Bit mask for cut generation levels. Use sums to
 * enable a collection of available cuts.
 */
typedef enum
{
   LS_MIP_GUB_COVER_CUTS                    = 2,
   LS_MIP_FLOW_COVER_CUTS                   = 4,
   LS_MIP_LIFT_CUTS                         = 8,
   LS_MIP_PLAN_LOC_CUTS                     = 16,
   LS_MIP_DISAGG_CUTS                       = 32,
   LS_MIP_KNAPSUR_COVER_CUTS                = 64,
   LS_MIP_LATTICE_CUTS                      = 128,
   LS_MIP_GOMORY_CUTS                       = 256,
   LS_MIP_COEF_REDC_CUTS                    = 512,
   LS_MIP_GCD_CUTS                          = 1024,
   LS_MIP_OBJ_CUT                           = 2048,
   LS_MIP_BASIS_CUTS                        = 4096,
   LS_MIP_CARDGUB_CUTS                      = 8192,
   LS_MIP_DISJUN_CUTS                       = 16384
} LSmipCutLevel;


/* Bit masks for MIP preprocessing levels. Use sums
 * to enable a collection of available levels.
 */
typedef enum
{
  LS_MIP_PREP_SPRE                          = 2,
  LS_MIP_PREP_PROB                          = 4,
  LS_MIP_PREP_COEF                          = 8,
  LS_MIP_PREP_ELIM                          = 16,
  LS_MIP_PREP_DUAL                          = 32,
  LS_MIP_PREP_DBACK                         = 64,
  LS_MIP_PREP_BINROWS                       = 128,
  LS_MIP_PREP_AGGROWS                       = 256,
  LS_MIP_PREP_COEF_LIFTING                  = 512,
  LS_MIP_PREP_MAXPASS                       = 1024
} LSmipPrepLevel;

/* Bit masks for solver preprocessing levels. Use sums
 * to enable a collection of available levels.
 */
typedef enum
{
  LS_SOLVER_PREP_SPRE                          = 2,
  LS_SOLVER_PREP_PFOR                          = 4,
  LS_SOLVER_PREP_DFOR                          = 8,
  LS_SOLVER_PREP_ELIM                          = 16,
  LS_SOLVER_PREP_DCOL                          = 32,
  LS_SOLVER_PREP_DROW                          = 64,
  LS_SOLVER_PREP_MAXPASS                       = 1024
} LSsolverPrepLevel;


/* Bit masks for IIS & IUS analysis levels. Use sums to
 * enable a collection of available levels.
 */
typedef enum
{
  LS_NECESSARY_ROWS                         = 1,
  LS_NECESSARY_COLS                         = 2,
  LS_SUFFICIENT_ROWS                        = 4,
  LS_SUFFICIENT_COLS                        = 8
} LSanalyzeLevel;

/* Infeasibility norms for IIS finder */
typedef enum
{
  LS_IIS_NORM_FREE                              =  0,
  LS_IIS_NORM_ONE                               =  1,
  LS_IIS_NORM_INFINITY                          =  2
} LSnormOptions;

/* IIS methods */
typedef enum
{
  LS_IIS_DEFAULT                                =  0,
  LS_IIS_DEL_FILTER                             =  1,
  LS_IIS_ADD_FILTER                             =  2,
  LS_IIS_GBS_FILTER                             =  3,
  LS_IIS_DFBS_FILTER                            =  4,
  LS_IIS_FSC_FILTER                             =  5,
  LS_IIS_ELS_FILTER                             =  6
} LSiisMethods;



/* Equivalences */
#define LS_IINFO_OBJSENSE                   LS_IPARAM_OBJSENSE
#define LS_IINFO_VER_MAJOR                  LS_IPARAM_VER_MAJOR
#define LS_IINFO_VER_MINOR                  LS_IPARAM_VER_MINOR
#define LS_IINFO_VER_BUILD                  LS_IPARAM_VER_BUILD
#define LS_IINFO_VER_REVISION               LS_IPARAM_VER_REVISION

/*********************************************************************
 *                   Conversion to version 1.x                       *
 *********************************************************************/
#define LSgetMIPData                        LSgetVarType
#define LSloadMIPData                       LSloadVarType
#define LSsetLogfunc                        LSsetModelLogfunc
#define printLOG_t                          printModelLOG_t
#define LSsetParameter                      LSsetModelParameter
#define LSgetParameter                      LSgetModelParameter
#define LSsetModIntParameter                LSsetModelIntParameter
#define LSgetModDouParameter                LSgetModelDouParameter
#define LSmodifyConstrainttype              LSmodifyConstraintType
#define LSmodifyVariabletype                LSmodifyVariableType
#define LSgetLibVersionBuildDate            LSgetVersionInfo
#define LSgetRowIndexNumericError           LSgetErrorRowIndex

/* old parameter names */
#define LSLOC_BANDB                         LSLOC_MIP
#define LS_IPARAM_PREP                      LS_IPARAM_SPLEX_PREP
#define LS_IPARAM_ITRLMT                    LS_IPARAM_SPLEX_ITRLMT
#define LS_IPARAM_PRICING                   LS_IPARAM_SPLEX_PPRICING
#define LS_IPARAM_SCALE                     LS_IPARAM_SPLEX_SCALE
#define LS_IPARAM_TIMLMT                    LS_IPARAM_SOLVER_TIMLMT
#define LS_DPARAM_CUTOFFVAL                 LS_DPARAM_SOLVER_CUTOFFVAL
#define LS_IPARAM_RESTART                   LS_IPARAM_SOLVER_RESTART
#define LS_DPARAM_FEASTOL                   LS_DPARAM_SOLVER_FEASTOL
#define LS_IPARAM_IUSOL                     LS_IPARAM_SOLVER_IUSOL
#define LS_IPARAM_MIPTIMLIM                 LS_IPARAM_MIP_TIMLIM
#define LS_IPARAM_MIPAOPTTIMLIM             LS_IPARAM_MIP_AOPTTIMLIM
#define LS_IPARAM_MIPPRELEVEL               LS_IPARAM_MIP_PRELEVEL
#define LS_IPARAM_MIPNODESELRULE            LS_IPARAM_MIP_NODESELRULE
#define LS_DPARAM_MIPINTTOL                 LS_DPARAM_MIP_INTTOL
#define LS_DPARAM_MIPRELINTTOL              LS_DPARAM_MIP_RELINTTOL
#define LS_DPARAM_MIP_OPTTOL                LS_DPARAM_MIP_RELOPTTOL
#define LS_DPARAM_MIPOPTTOL                 LS_DPARAM_MIP_OPTTOL
#define LS_DPARAM_MIPPEROPTTOL              LS_DPARAM_MIP_PEROPTTOL
#define LS_IPARAM_MIPMAXCUTPASS             LS_IPARAM_MIP_MAXCUTPASS_TOP
#define LS_DPARAM_MIPADDCUTPER              LS_DPARAM_MIP_ADDCUTPER
#define LS_IPARAM_MIPCUTLEVEL               LS_IPARAM_MIP_CUTLEVEL_TOP
#define LS_IPARAM_MIPHEULEVEL               LS_IPARAM_MIP_HEULEVEL
#define LS_IPARAM_MIPPRINTLEVEL             LS_IPARAM_MIP_PRINTLEVEL
#define LS_IPARAM_MIPPREPRINTLEVEL          LS_IPARAM_MIP_PREPRINTLEVEL
#define LS_DPARAM_MIPCUTOFFOBJ              LS_DPARAM_MIP_CUTOFFOBJ
#define LS_IPARAM_MIPSTRONGBRANCHLEVEL      LS_IPARAM_MIP_STRONGBRANCHLEVEL
#define LS_IPARAM_MIPBRANCHDIR              LS_IPARAM_MIP_BRANCHDIR
#define LS_IPARAM_MIPTOPOPT                 LS_IPARAM_MIP_TOPOPT
#define LS_IPARAM_MIPREOPT                  LS_IPARAM_MIP_REOPT
#define LS_IPARAM_MIPSOLVERTYPE             LS_IPARAM_MIP_SOLVERTYPE
#define LS_IPARAM_MIPKEEPINMEM              LS_IPARAM_MIP_KEEPINMEM
#define LS_DPARAM_MIP_REDCOSTFIXING_CUTOFF  LS_DPARAM_MIP_REDCOSTFIX_CUTOFF
#define LS_IPARAM_NLPPRINTLEVEL             LS_IPARAM_NLP_PRINTLEVEL
#define LS_IPARAM_LPPRINTLEVEL              LS_IPARAM_LP_PRINTLEVEL
#define LS_IPARAM_NLPSOLVER                 LS_IPARAM_NLP_SOLVER
#define LS_IPARAM_MODEL_CONVEX_FLAG         LS_IPARAM_NLP_CONVEX
#define LS_IPARAM_NLP_SOLVEASLP             LS_IPARAM_NLP_SOLVE_AS_LP
#define LS_DINFO_MIPBESTBOUND               LS_DINFO_MIP_BESTBOUND
#define LS_IINFO_MIPBRANCHCOUNT             LS_IINFO_MIP_BRANCHCOUNT
#define LS_IINFO_MIPSTATUS                  LS_IINFO_MIP_STATUS
#define LS_IINFO_MIPNEWIPSOL                LS_IINFO_MIP_NEWIPSOL
#define LS_IINFO_MIPLPCOUNT                 LS_IINFO_MIP_LPCOUNT
#define LS_IINFO_MIPACTIVENODES             LS_IINFO_MIP_ACTIVENODES
#define LS_IINFO_MIPLTYPE                   LS_IINFO_MIP_LTYPE
#define LS_IINFO_MIPAOPTTIMETOSTOP          LS_IINFO_MIP_AOPTTIMETOSTOP
#define LS_DINFO_MIPOBJ                     LS_DINFO_MIP_OBJ
#define LS_IPARAM_BARRIER_PROB_TO_SOLVE     LS_IPARAM_PROB_TO_SOLVE
#define LS_IINFO_STATUS                     LS_IINFO_PRIMAL_STATUS
#define LS_GOPSOLSTAT_GLOBAL_OPTIMAL        LS_STATUS_OPTIMAL
#define LS_GOPSOLSTAT_LOCAL_OPTIMAL         LS_STATUS_LOCAL_OPTIMAL
#define LS_GOPSOLSTAT_INFEASIBLE            LS_STATUS_INFEASIBLE
#define LS_GOPSOLSTAT_TOPUNBOUNDED          LS_STATUS_UNBOUNDED
#define LS_GOPSOLSTAT_FEASIBLE              LS_STATUS_FEASIBLE
#define LS_GOPSOLSTAT_UNKNOWN               LS_STATUS_UNKNOWN
#define LS_GOPSOLSTAT_NUMERICAL_ERROR       LS_STATUS_NUMERICAL_ERROR
#define LS_IIS_NORM_NONE                    LS_IIS_NORM_FREE

/* old operator names */
#define EP_EXT_AND                          EP_VAND
#define EP_EXT_OR                           EP_VOR
#define EP_MULTMULT                         EP_VMULT


/*********************************************************************
 *               Callback Function Definitions                       *
 *********************************************************************/

/* Callback Function Definitions  */

typedef int  (CALLBACKTYPE *MIP_callback_t)(pLSmodel pModel,
                                      void        *pvUserData,
                                      double      dObjval,
                                      double      *padPrimal);


typedef int  (CALLBACKTYPE *cbFunc_t)(pLSmodel    pModel,
                                      int         nLocation,
                                      void        *pvUserData);


typedef int  (CALLBACKTYPE *Funcalc_type)(pLSmodel   pModel,
                                      void           *pvUserData,
                                      int            nRow,
                                      double         *padX,
                                      int            nJDiff,
                                      double         dXJBase,
                                      double         *padFunc,
                                      void           *pReserved);


typedef int  (CALLBACKTYPE *Gradcalc_type)(pLSmodel  pModel,
                                      void           *pvUserData,
                                      int            nRow,
                                      double         *padX,
                                      double         *padLB,
                                      double         *padUB,
                                      int            nNewPnt,
                                      int            nNPar,
                                      int            *paiPartial,
                                      double         *padPartial);

typedef void (CALLTYPE *printEnvLOG_t)(pLSenv        pEnv,
                                       char          *pachStr,
                                       void          *pvPrnData);

typedef void (CALLTYPE *printModelLOG_t)(pLSmodel    pModel,
                                       char          *pachStr,
                                       void          *pvPrnData);

typedef int  (CALLBACKTYPE *user_callback_t)(pLSmodel pModel,
                                       int           nArgs,
                                       double        *pdValues,
                                       void          *pvUserData,
                                       double        *pdReturnVal);


/*********************************************************************
 *                                                                   *
 *                        Function Prototypes                        *
 *                                                                   *
 *********************************************************************/


/*********************************************************************
 * Structure Creation and Deletion Routines (4)                      *
 *********************************************************************/

 pLSenv CALLTYPE LScreateEnv(int     *pnErrorcode,
                             char    *pszPassword);

 pLSmodel CALLTYPE LScreateModel(pLSenv pEnv,
                             int     *pnErrorcode);

 int CALLTYPE LSdeleteEnv(pLSenv *pEnv);


 int CALLTYPE LSdeleteModel(pLSmodel *pModel);


 int CALLTYPE LSloadLicenseString(char *pszFname,
                             char    *pachLicense);

 void CALLTYPE LSgetVersionInfo(char *pachVernum,
                             char    *pachBuildDate);


/**********************************************************************
 * Model I-O Routines (13)                                            *
 **********************************************************************/

 int CALLTYPE LSreadMPSFile(pLSmodel pModel,
                             char    *pszFname,
                             int     nFormat);

 int CALLTYPE LSwriteMPSFile(pLSmodel pModel,
                             char    *pszFname,
                             int     nFormat);

 int CALLTYPE LSreadLINDOFile(pLSmodel pModel,
                             char    *pszFname);

 int CALLTYPE LSwriteLINDOFile(pLSmodel pModel,
                             char    *pszFname);

 int CALLTYPE LSwriteLINGOFile(pLSmodel pModel,
                             char    *pszFname);

 int CALLTYPE LSwriteDualMPSFile(pLSmodel pModel,
                             char    *pszFname,
                             int     nFormat,
                             int     nObjSense);

 int CALLTYPE LSwriteDualLINDOFile(pLSmodel pModel,
                             char    *pszFname,
                             int     nObjSense);

 int CALLTYPE LSwriteSolution(pLSmodel pModel,
                             char    *pszFname);

int CALLTYPE LSwriteSolutionOfType(pLSmodel  pModel,
                             char    *pszFname,
                             int     nFormat);

 int CALLTYPE LSwriteIIS(pLSmodel  pModel,
                             char    *pszFname);

 int CALLTYPE LSwriteIUS(pLSmodel  pModel,
                             char    *pszFname);

 int CALLTYPE LSreadMPIFile(pLSmodel pModel,
                             char    *pszFname);

 int CALLTYPE LSwriteMPIFile(pLSmodel pModel,
                             char    *pszFname);

 int CALLTYPE  LSwriteWithSetsAndSC(pLSmodel  pModel,
                             char    *pszFname,
                             int     nFormat);

 int CALLTYPE LSreadBasis(pLSmodel  pModel,
                             char    *pszFname,
                             int     nFormat);

 int CALLTYPE LSwriteBasis(pLSmodel  pModel,
                             char    *pszFname,
                             int     nFormat);

/**********************************************************************
 * Error Handling Routines (3)                                        *
 **********************************************************************/

 int CALLTYPE LSgetErrorMessage(pLSenv pEnv,
                             int     nErrorcode,
                             char    *pachMessage);

 int CALLTYPE LSgetFileError(pLSmodel pModel,
                             int     *pnLinenum,
                             char    *pachLinetxt);

 int CALLTYPE LSgetErrorRowIndex(pLSmodel  pModel,
                             int     *piRow);


/**********************************************************************
 * Routines for Setting and Retrieving Parameter Values (14)          *
 **********************************************************************/

 int CALLTYPE LSsetModelParameter(pLSmodel pModel,
                             int     nParameter,
                             void    *pvValue);

 int CALLTYPE LSgetModelParameter(pLSmodel pModel,
                             int     nParameter,
                             void    *pvValue);

 int CALLTYPE LSsetEnvParameter(pLSenv pEnv,
                             int     nParameter,
                             void    *pvValue);

 int CALLTYPE LSgetEnvParameter(pLSenv pEnv,
                             int     nParameter,
                             void    *pvValue);

 int CALLTYPE LSsetModelDouParameter(pLSmodel pModel,
                             int     nParameter,
                             double  dVal);

 int CALLTYPE LSgetModelDouParameter(pLSmodel pModel,
                             int     nParameter,
                             double  *pdVal);

 int CALLTYPE LSsetModelIntParameter(pLSmodel pModel,
                             int     nParameter,
                             int     nVal);

 int CALLTYPE LSgetModelIntParameter(pLSmodel pModel,
                             int     nParameter,
                             int     *pnVal);

 int CALLTYPE LSsetEnvDouParameter(pLSenv pEnv,
                             int     nParameter,
                             double  dVal);

 int CALLTYPE LSgetEnvDouParameter(pLSenv pEnv,
                             int     nParameter,
                             double  *pdVal);

 int CALLTYPE LSsetEnvIntParameter(pLSenv pEnv,
                             int     nParameter,
                             int     nVal);

 int CALLTYPE LSgetEnvIntParameter(pLSenv pEnv,
                             int     nParameter,
                             int     *pnVal);

 int CALLTYPE LSreadModelParameter(pLSmodel pModel,
                             char    *pszFname);

 int CALLTYPE LSreadEnvParameter(pLSenv pEnv,
                             char    *pszFname);

 int CALLTYPE LSwriteModelParameter(pLSmodel pModel,
                             char    *pszFname);

 /*********************************************************************
  * Model Loading Routines (9)                                        *
  *********************************************************************/

 int CALLTYPE LSloadLPData(pLSmodel pModel,
                             int     nCons,
                             int     nVars,
                             int     dObjSense,
                             double  dObjConst,
                             double  *padC,
                             double  *padB,
                             char    *pszConTypes,
                             int     nAnnz,
                             int     *paiAcols,
                             int     *panAcols,
                             double  *padAcoef,
                             int     *paiArows,
                             double  *padL,
                             double  *padU);

 int CALLTYPE LSloadQCData(pLSmodel pModel,
                             int     nQCnnz,
                             int     *paiQCrows,
                             int     *paiQCcols1,
                             int     *paiQCcols2,
                             double  *padQCcoef);

 int CALLTYPE LSloadConeData(pLSmodel pModel,
                             int      nCone,
                             char     *pszConeTypes,
                             int      *paiConebegcone,
                             int      *paiConecols);

 int CALLTYPE LSloadSETSData(pLSmodel pModel,
                             int      nSETS,
                             char     *pszSETStype,
                             int      *paiCARDnum,
                             int      *paiSETSbegcol,
                             int      *paiSETScols);

 int CALLTYPE LSloadSemiContData(pLSmodel pModel,
                             int      nSCVars,
                             int      *paiVars,
                             double   *padL,
                             double   *padU);

 int CALLTYPE LSloadVarType(pLSmodel pModel,
                             char    *pszVarTypes);

 int CALLTYPE LSloadNameData(pLSmodel pModel,
                             char    *pszTitle,
                             char    *pszObjName,
                             char    *pszRhsName,
                             char    *pszRngName,
                             char    *pszBndname,
                             char    **paszConNames,
                             char    **paszVarNames,
                             char    **paszConeNames);

int CALLTYPE LSloadStocVarNames(pLSmodel  pModel,
                            int       nSvars,
                            char      **paszSVarNames);

 int CALLTYPE LSloadNLPData(pLSmodel  pModel,
                             int      *paiNLPcols,
                             int      *panNLPcols,
                             double   *padNLPcoef,
                             int      *paiNLProws,
                             int      nNLPobj,
                             int      *paiNLPobj,
                             double   *padNLPobj);

 int CALLTYPE LSloadInstruct(pLSmodel pModel,
                             int    nCons,
                             int    nObjs,
                             int    nVars,
                             int    nNumbers,
                             int    *panObjSense,
                             char   *pszConType,
                             char   *pszVarType,
                             int    *panInstruct,
                             int    nInstruct,
                             int    *paiVars,
                             double *padNumVal,
                             double *padVarVal,
                             int    *paiObjBeg,
                             int    *panObjLen,
                             int    *paiConBeg,
                             int    *panConLen,
                             double *padLB,
                             double *padUB);

 int CALLTYPE LSaddInstruct(pLSmodel pModel,
                             int    nCons,
                             int    nObjs,
                             int    nVars,
                             int    nNumbers,
                             int    *panObjSense,
                             char   *pszConType,
                             char   *pszVarType,
                             int    *panInstruct,
                             int    nInstruct,
                             int    *paiCons,
                             double *padNumVal,
                             double *padVarVal,
                             int    *paiObjBeg,
                             int    *panObjLen,
                             int    *paiConBeg,
                             int    *panConLen,
                             double *padLB,
                             double *padUB);

 int CALLTYPE LSloadStringData(pLSmodel pModel,
                             int    nStrings,
                             char   **szStringData);

 int CALLTYPE LSloadString(pLSmodel pModel,
                             char   *szString);

 int CALLTYPE LSbuildStringData(pLSmodel pModel);

 int CALLTYPE LSdeleteStringData(pLSmodel pModel);

 int CALLTYPE LSdeleteString(pLSmodel pModel);

 int CALLTYPE LSgetStringValue(pLSmodel pModel,
                             int      iString,
                             double   *pdValue);

/**********************************************************************
 * Solver Initialization Routines (6)                                 *
 **********************************************************************/

 int CALLTYPE LSloadBasis(pLSmodel pModel,
                             int     *panCstatus,
                             int     *panRstatus);

 int CALLTYPE LSloadVarPriorities(pLSmodel  pModel,
                             int     *panCprior);

 int CALLTYPE LSreadVarPriorities(pLSmodel  pModel,
                             char    *pszFname);

 int CALLTYPE LSloadVarStartPoint(pLSmodel pModel,
                             double  *padPrimal);

 int CALLTYPE LSreadVarStartPoint(pLSmodel pModel,
                             char    *pszFname);

 int CALLTYPE LSloadBlockStructure(pLSmodel pModel,
                             int      nBlock,
                             int      *anRblock,
                             int      *anCblock,
                             int      nType);


/**********************************************************************
 * Optimization Routines (3)                                          *
 **********************************************************************/

 int CALLTYPE LSoptimize(pLSmodel pModel,
                             int    nMethod,
                             int    *pnSolStatus);

 int CALLTYPE LSsolveMIP(pLSmodel  pModel,
                             int    *pnMIPSolStatus);

 int  CALLTYPE  LSsolveNextBestMIPsols(pLSmodel pModel,
                            char            *pszFname,
                            MIP_callback_t  pfMIPCallback,
                            void            *pvCbData,
                            int             nMaxSols);

 int CALLTYPE LSsolveGOP(pLSmodel pModel,
                             int    *pnGOPSolStatus);

/**********************************************************************
 * Solution Query Routines (13)                                       *
 **********************************************************************/

 /* query general model and solver information */
 int CALLTYPE LSgetInfo(pLSmodel  pModel,
                             int     nQuery,
                             void    *pvResult);

 /* query continous models */
 int CALLTYPE LSgetPrimalSolution(pLSmodel pModel,
                             double  *padPrimal);

 int CALLTYPE LSgetDualSolution(pLSmodel pModel,
                             double  *padDual);

 int CALLTYPE LSgetReducedCosts(pLSmodel pModel,
                             double  *padRedcosts);

 int CALLTYPE LSgetReducedCostsCone(pLSmodel pModel,
                             double  *padRedcosts);

 int CALLTYPE LSgetSlacks(pLSmodel pModel,
                             double  *padSlacks);

 int CALLTYPE LSgetBasis(pLSmodel pModel,
                             int     *panCstatus,
                             int     *panRstatus);

 int CALLTYPE LSgetSolution(pLSmodel  pModel,
                             int      nWhich,
                             double   *padVal);

 /* query integer models */
 int CALLTYPE LSgetMIPPrimalSolution(pLSmodel  pModel,
                             double  *padPrimal);

 int CALLTYPE LSgetMIPDualSolution(pLSmodel pModel,
                             double  *padDual);

 int CALLTYPE LSgetMIPReducedCosts(pLSmodel pModel,
                             double  *padRedcosts);

 int CALLTYPE LSgetMIPSlacks(pLSmodel pModel,
                             double  *padSlacks);

 int CALLTYPE LSgetMIPBasis(pLSmodel pModel,
                             int     *panCstatus,
                             int     *panRstatus);

 /*********************************************************************
  * Model Query Routines (13)                                         *
  *********************************************************************/

 int CALLTYPE LSgetLPData(pLSmodel   pModel,
                             int     *pdObjSense,
                             double  *pdObjConst,
                             double  *padC,
                             double  *padB,
                             char    *pachConTypes,
                             int     *paiAcols,
                             int     *panAcols,
                             double  *padAcoef,
                             int     *paiArows,
                             double  *padL,
                             double  *padU);

 int CALLTYPE LSgetQCData(pLSmodel   pModel,
                             int     *paiQCrows,
                             int     *paiQCcols1,
                             int     *paiQCcols2,
                             double  *padQCcoef);

 int CALLTYPE LSgetQCDatai(pLSmodel  pModel,
                             int     iCon,
                             int     *pnQCnnz,
                             int     *paiQCcols1,
                             int     *paiQCcols2,
                             double  *padQCcoef);

 int CALLTYPE LSgetVarType(pLSmodel pModel,
                             char    *pachVarTypes);

 int CALLTYPE LSgetVarStartPoint(pLSmodel  pModel,
                             double  *padPrimal);


int CALLTYPE  LSgetSETSData(pLSmodel pModel,
                             int     *piNsets,
                             int     *piNtnz,
                             char    *pachSETtype,
                             int     *piCardnum,
                             int     *piNnz,
                             int     *piBegset,
                             int     *piVarndx);

int CALLTYPE  LSgetSETSDatai(pLSmodel pModel,
                             int      iSet,
                             char     *pachSETType,
                             int      *piCardnum,
                             int      *piNnz,
                             int      *piVarndx);


int CALLTYPE  LSgetSemiContData(pLSmodel  pModel,
                             int      *piNvars,
                             int      *piVarndx,
                             double   *padl,
                             double   *padu);



 int CALLTYPE LSgetNameData(pLSmodel pModel,
                             char    *pachTitle,
                             char    *pachObjName,
                             char    *pachRhsName,
                             char    *pachRngName,
                             char    *pachBndname,
                             char    **pachConNames,
                             char    *pachConNameData,
                             char    **pachVarNames,
                             char    *pachVarNameData);

 int CALLTYPE LSgetLPVariableDataj(pLSmodel  pModel,
                             int     iVar,
                             char    *pachVartype,
                             double  *pdC,
                             double  *pdL,
                             double  *pdU,
                             int     *pnAnnz,
                             int     *paiArows,
                             double  *padAcoef);

 int CALLTYPE LSgetVariableNamej(pLSmodel pModel,
                             int     iVar,
                             char    *pachVarName);

 int CALLTYPE LSgetVariableIndex(pLSmodel pModel,
                             char    *pszVarName,
                             int     *piVar);

 int CALLTYPE LSgetConstraintNamei(pLSmodel pModel,
                             int     iCon,
                             char    *pachConName);

 int CALLTYPE LSgetConstraintIndex(pLSmodel pModel,
                             char    *pszConName,
                             int     *piCon );

 int CALLTYPE LSgetConstraintDatai(pLSmodel  pModel,
                             int     iCon,
                             char    *pachConType,
                             char    *pachIsNlp,
                             double  *pdB);

 int CALLTYPE LSgetLPConstraintDatai(pLSmodel Model,
                             int     iCon,
                             char    *pachConType,
                             double  *pdB,
                             int     *pnNnz,
                             int     *piVar,
                             double  *pdAcoef);


 int CALLTYPE LSgetConeNamei(pLSmodel pModel,
                             int     iCone,
                             char    *pachConeName);

 int CALLTYPE LSgetConeIndex(pLSmodel pModel,
                             char    *pszConeName,
                             int     *piCone );

 int CALLTYPE LSgetConeDatai(pLSmodel  pModel,
                             int      iCone,
                             char     *pachConeType,
                             int      *piNnz,
                             int      *paiCols);

 int CALLTYPE LSgetNLPData(pLSmodel  pModel,
                            int      *paiNLPcols,
                            int      *panNLPcols,
                            double   *padNLPcoef,
                            int      *paiNLProws,
                            int      *pnNLPobj,
                            int      *paiNLPobj,
                            double   *padNLPobj,
                            char     *pachNLPConTypes);

 int CALLTYPE LSgetNLPConstraintDatai(pLSmodel  pModel,
                             int     iCon,
                             int     *pnNnz,
                             int     *paiNLPcols,
                             double  *padNLPcoef);

 int CALLTYPE LSgetNLPVariableDataj(pLSmodel  pModel,
                             int     iVar,
                             int     *pnNnz,
                             int     *panNLProws,
                             double  *padNLPcoef);

 int CALLTYPE LSgetNLPObjectiveData(pLSmodel  pModel,
                             int     *pnNLPobjnnz,
                             int     *paiNLPobj,
                             double  *padNLPobj);

 int CALLTYPE LSgetDualModel(pLSmodel pModel,
                             pLSmodel pDualModel);

 int CALLTYPE LSgetInstruct(pLSmodel  pModel,
                            int      *pnObjSense,
                            char     *pachConType,
                            char     *pachVarType,
                            int      *panCode,
                            double   *padNumVal,
                            double   *padVarVal,
                            int      *panObjBeg,
                            int      *panObjLength,
                            int      *panConBeg,
                            int      *panConLength,
                            double   *padLwrBnd,
                            double   *padUprBnd);

int CALLTYPE LScalinfeasMIPsolution(pLSmodel model,
                            double   *pdIntPfeas,
                            double   *pbConsPfeas,
                            double   *pdPrimalMipsol);

int CALLTYPE LSgetRoundMIPsolution(pLSmodel pModel,
                            double   *padPrimal,
                            double   *padPrimalRound,
                            double   *padObjRound,
                            double   *padPfeasRound,
                            int      *pnstatus,
                            int      iUseOpti);

int CALLTYPE LSgetDuplicateColumns(pLSmodel pModel,
                            int     nCheckVals,
                            int     *pnSets,
                            int     *paiSetsBeg,
                            int     *paiCols);


/**********************************************************************
 *  Model Modification Routines (22)                                  *
 **********************************************************************/

 int CALLTYPE LSaddConstraints(pLSmodel pModel,
                             int     nNumaddcons,
                             char    *pszConTypes,
                             char    **paszConNames,
                             int     *paiArows,
                             double  *padAcoef,
                             int     *paiAcols,
                             double  *padB);

 int CALLTYPE LSaddVariables(pLSmodel pModel,
                             int     nNumaddvars,
                             char    *pszVarTypes,
                             char    **paszVarNames,
                             int     *paiAcols,
                             int     *panAcols,
                             double  *padAcoef,
                             int     *paiArows,
                             double  *padC,
                             double  *padL,
                             double  *padU);

 int CALLTYPE LSaddCones(pLSmodel    pModel,
                             int      nCone,
                             char     *pszConeTypes,
                             char     **paszConenames,
                             int      *paiConebegcol,
                             int      *paiConecols);

int CALLTYPE LSaddSETS(pLSmodel    pModel,
                             int      nSETS,
                             char     *pszSETStype,
                             int      *paiCARDnum,
                             int      *paiSETSbegcol,
                             int      *paiSETScols);

int CALLTYPE LSaddQCterms(pLSmodel  pModel,
                           int       nQCnonzeros,
                           int       *paiQCconndx,
                           int       *paiQCvarndx1,
                           int       *paiQCvarndx2,
        double    *padQCcoef);

 int CALLTYPE LSdeleteConstraints(pLSmodel pModel,
                             int      nCons,
                             int      *paiCons);

 int CALLTYPE LSdeleteCones(pLSmodel  pModel,
                             int      nCones,
                             int      *paiCones);

int CALLTYPE LSdeleteSETS(pLSmodel    pModel,
                             int      nSETS,
                             int      *paiSETS);

int CALLTYPE LSdeleteSemiContVars(pLSmodel pModel,
                             int      nSCVars,
                             int      *paiSCVars);

 int CALLTYPE LSdeleteVariables(pLSmodel pModel,
                             int     nVars,
                             int     *paiVars);

 int CALLTYPE LSdeleteQCterms(pLSmodel pModel,
                             int     nCons,
                             int     *paiCons);

int CALLTYPE LSdeleteAj(pLSmodel  pModel,
                        int       iVar1,
                        int       nRows,
                        int       *paiRows);

 int CALLTYPE LSmodifyLowerBounds(pLSmodel pModel,
                             int     nVars,
                             int     *paiVars,
                             double  *padL);

 int CALLTYPE LSmodifyUpperBounds(pLSmodel pModel,
                             int     nVars,
                             int     *paiVars,
                             double  *padU);

 int CALLTYPE LSmodifyRHS(pLSmodel pModel,
                             int     nCons,
                             int     *paiCons,
                             double  *padB);

 int CALLTYPE LSmodifyObjective(pLSmodel pModel,
                             int     nVars,
                             int     *paiVars,
                             double  *padC);

 int CALLTYPE LSmodifyObjConstant(pLSmodel  pModel,
                             double  dObjConst);


int CALLTYPE LSmodifyAj(pLSmodel  pModel,
                        int     iVar1,
                        int     nRows,
                        int     *paiRows,
                        double  *padAj);

 int CALLTYPE LSmodifyCone(pLSmodel pModel,
                             char   cConeType,
                             int    iConeNum,
                             int    iConeNnz,
                             int    *paiConeCols);

 int CALLTYPE LSmodifySET(pLSmodel    pModel,
                             char     cSETtype,
                             int      iSETnum,
                             int      iSETnnz,
                             int      *paiSETcols);

 int CALLTYPE LSmodifySemiContVars(pLSmodel pModel,
                             int      nSCVars,
                             int      *paiSCVars,
                             double   *padL,
                             double   *padU);

 int CALLTYPE LSmodifyConstraintType(pLSmodel pModel,
                             int     nCons,
                             int     *paiCons,
                             char    *pszConTypes);

 int CALLTYPE LSmodifyVariableType(pLSmodel pModel,
                             int     nVars,
                             int     *paiVars,
                             char    *pszVarTypes);


int CALLTYPE LSaddNLPAj(pLSmodel pModel,
                        int      iVar1,
                        int       nRows,
                        int       *paiRows,
                        double    *padAj);

int CALLTYPE LSaddNLPobj(pLSmodel pModel,
                            int       nCols,
                            int       *paiCols,
                            double    *padColj);

int CALLTYPE LSdeleteNLPobj(pLSmodel pModel,
                            int      nCols,
                            int      *paiCols);

/*********************************************************************
 *   Model & Solution Analysis Routines (10)                         *
 *********************************************************************/

 int CALLTYPE LSgetConstraintRanges(pLSmodel  pModel,
                             double  *padDec,
                             double  *padInc);

 int CALLTYPE LSgetObjectiveRanges(pLSmodel  pModel,
                             double  *padDec,
                             double  *padInc);

 int CALLTYPE LSgetBoundRanges(pLSmodel  pModel,
                             double  *padDec,
                             double  *padInc);

 int CALLTYPE LSgetBestBounds(pLSmodel  pModel,
                             double  *padBestL,
                             double  *padBestU);

 int CALLTYPE LSfindIIS(pLSmodel     pModel,
                             int     nLevel);

 int CALLTYPE LSfindIUS(pLSmodel     pModel,
                             int     nLevel);

 int CALLTYPE LSfindBlockStructure(pLSmodel pModel,
                             int     nBlock,
                             int     nType);

 int CALLTYPE LSgetIIS(pLSmodel  pModel,
                             int     *pnSuf_r,
                             int     *pnIIS_r,
                             int     *paiCons,
                             int     *pnSuf_c,
                             int     *pnIIS_c,
                             int     *paiVars,
                             int     *panBnds);

 int CALLTYPE LSgetIUS(pLSmodel  pModel,
                             int     *pnSuf,
                             int     *pnIUS,
                             int     *paiVars);

 int CALLTYPE LSgetBlockStructure(pLSmodel pModel,
                             int     *pnBlock,
                             int     *panRblock,
                             int     *panCblock,
                             int     *pnType);

/**********************************************************************
 * Advanced Routines (6)                                              *
 **********************************************************************/

 int CALLTYPE LSdoBTRAN(pLSmodel pModel,
                             int     *pcYnz,
                             int     *paiY,
                             double  *padY,
                             int     *pcXnz,
                             int     *paiX,
                             double  *padX);

 int CALLTYPE LSdoFTRAN(pLSmodel pModel,
                             int     *pcYnz,
                             int     *paiY,
                             double  *padY,
                             int     *pcXnz,
                             int     *paiX,
                             double  *padX);

 /* function and gradient evaluations */
 int CALLTYPE LScalcObjFunc(pLSmodel pModel,
                             double  *padPrimal,
                             double  *pdObjval);

 int CALLTYPE LScalcConFunc(pLSmodel pModel,
                             int      iRow,
                             double   *padPrimal,
                             double   *padSlacks);

 int CALLTYPE LScalcObjGrad(pLSmodel pModel,
                             double  *padPrimal,
                             int     nParList,
                             int     *paiParList,
                             double  *padParGrad);

 int CALLTYPE LScalcConGrad(pLSmodel pModel,
                             int     irow,
                             double  *padPrimal,
                             int     nParList,
                             int     *paiParList,
                             double  *padParGrad);

/**********************************************************************
 * Callback Management Routines (9)                                   *
 **********************************************************************/

 int CALLTYPE LSsetCallback(pLSmodel pModel,
                           cbFunc_t  pfCallback,
                             void    *pvCbData);


 int CALLTYPE LSsetMIPCallback(pLSmodel pModel,
                     MIP_callback_t  pfMIPCallback,
                             void    *pvCbData);


 int CALLTYPE LSgetCallbackInfo(pLSmodel pModel,
                             int     nLocation,
                             int     nQuery,
                             void    *pvValue);

 int CALLTYPE LSgetMIPCallbackInfo(pLSmodel pModel,
                             int     nQuery,
                             void    *pvValue);

 /* function evaluation routines for NLP solvers */
 int CALLTYPE LSsetGradcalc(pLSmodel        pModel,
                              Gradcalc_type pfGrad_func,
                              void          *pvUserData,
                              int           nLenUseGrad,
                              int           *pnUseGrad);

 int CALLTYPE LSsetFuncalc(pLSmodel        pModel,
                              Funcalc_type pfFunc,
                              void         *pvFData);


 int CALLTYPE LSsetEnvLogfunc(pLSenv pEnv,
                              printEnvLOG_t  locFunc,
                              void    *pvPrData);


 int CALLTYPE LSsetModelLogfunc(pLSmodel  pModel,
                              printLOG_t  locFunc,
                              void    *pvPrData);

 int CALLTYPE LSsetUsercalc(pLSmodel      pModel,
                              user_callback_t pfUser_func,
                              void          *pvUserData);

/**********************************************************************
 *  Memory Related Routines (7)                                       *
 **********************************************************************/

 void CALLTYPE LSfreeSolverMemory(pLSmodel pModel);

 void CALLTYPE LSfreeHashMemory(pLSmodel pModel);

 void CALLTYPE LSfreeSolutionMemory(pLSmodel pModel);

 void CALLTYPE LSfreeMIPSolutionMemory(pLSmodel pModel);

 void CALLTYPE LSfreeGOPSolutionMemory(pLSmodel pModel);

int CALLTYPE LSsetProbAllocSizes(pLSmodel pModel,
                                 int      n_vars_alloc,
                                 int      n_cons_alloc,
                                 int      n_QC_alloc,
                                 int      n_Annz_alloc,
                                 int      n_Qnnz_alloc,
                                 int      n_NLPnnz_alloc);

int CALLTYPE LSaddEmptySpacesAcolumns(pLSmodel pModel,
                                      int      *colnnz);

int CALLTYPE LSaddEmptySpacesNLPAcolumns(pLSmodel pModel,
                                         int      *colnnz);


/**********************************************************************
 * Deprecated functions from version 1.x                              *
 **********************************************************************/

 /* Deprecated,  use LSgetInfo() */
 int CALLTYPE LSgetLicenseInfo(pLSmodel pModel,
                             int     *pnMaxcons,
                             int     *pnMaxvars,
                             int     *pnMaxintvars,
                             int     *pnReserved1,
                             int     *pnDaystoexp,
                             int     *pnDaystotrialexp,
                             int     *pnNlpAllowed,
                             int     *pnUsers,
                             int     *pnBarAllowed,
                             int     *pnRuntime,
                             int     *pnEdulicense,
                             char    *pachText);


 /* Deprecated,  use LSgetInfo() */
 int CALLTYPE LSgetDimensions(pLSmodel pModel,
                             int     *pnVars,
                             int     *pnCons,
                             int     *pnCones,
                             int     *pnAnnz,
                             int     *pnQCnnz,
                             int     *pnConennz,
                             int     *pnNLPnnz,
                             int     *pnNLPobjnnz,
                             int     *pnVarNamelen,
                             int     *pnConNamelen,
                             int     *pnConeNamelen);

 /* Deprecated, use LSsolveMIP() */
 int CALLTYPE LSbnbSolve(pLSmodel  pModel,
                             char    *pszFname);

 /* Deprecated,  use LSgetInfo() */
 int CALLTYPE LSgetDualMIPsolution(pLSmodel pModel,
                             double  *padPrimal,
                             double  *padDual,
                             double  *padRedcosts,
                             int     *panCstatus,
                             int     *panRstatus);


/* Deprecated,  use LSgetInfo() */
 int CALLTYPE LSgetMIPSolutionStatus(pLSmodel  pModel,
                             int     *pnStatus);

/* Deprecated,  use LSgetInfo() */
 int CALLTYPE LSgetSolutionStatus(pLSmodel  pModel,
                                 int     *nStatus);

/* Deprecated,  use LSgetInfo() */
 int CALLTYPE LSgetObjective(pLSmodel pModel,
                             double  *pdObjval);

/* Deprecated,  use LSgetInfo() */
 int CALLTYPE LSgetSolutionInfo(pLSmodel pModel,
                             int     *pnMethod,
                             int     *pnElapsed,
                             int     *pnSpxiter,
                             int     *pnBariter,
                             int     *pnNlpiter,
                             int     *pnPrimStatus,
                             int     *pnDualStatus,
                             int     *pnBasStatus,
                             double  *pdPobjval,
                             double  *pdDobjval,
                             double  *pdPinfeas,
                             double  *pdDinfeas);

/* Deprecated,  use LSgetInfo() */
 int CALLTYPE LSgetMIPSolution(pLSmodel  pModel,
                             double  *pdPobjval,
                             double  *padPrimal);

/* Deprecated,  use LSgetInfo() */
 int CALLTYPE LSgetCurrentMIPSolutionInfo(pLSmodel pModel,
                             int     *pnMIPstatus,
                             double  *pdMIPobjval,
                             double  *pdBestbound,
                             int     *pnSpxiter,
                             int     *pnBariter,
                             int     *pnNlpiter,
                             int     *pnLPcnt,
                             int     *pnBranchcnt,
                             int     *pnActivecnt,
                             int     *pnCons_prep,
                             int     *pnVars_prep,
                             int     *pnAnnz_prep,
                             int     *pnInt_prep,
                             int     *pnCut_contra,
                             int     *pnCut_obj,
                             int     *pnCut_gub,
                             int     *pnCut_lift,
                             int     *pnCut_flow,
                             int     *pnCut_gomory,
                             int     *pnCut_gcd,
                             int     *pnCut_clique,
                             int     *pnCut_disagg,
                             int     *pnCut_planloc,
                             int     *pnCut_latice,
                             int     *pnCut_coef);


#ifdef __cplusplus
}
#endif


#endif   /* ifndef __LINDO_H__   */


