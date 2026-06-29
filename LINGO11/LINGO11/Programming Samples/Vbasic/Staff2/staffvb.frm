VERSION 5.00
Begin VB.Form Form1 
   BorderStyle     =   3  'Fixed Dialog
   Caption         =   "Staff Scheduling Example Using VB and the LINGO DLL"
   ClientHeight    =   4050
   ClientLeft      =   45
   ClientTop       =   330
   ClientWidth     =   7035
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   4050
   ScaleWidth      =   7035
   ShowInTaskbar   =   0   'False
   StartUpPosition =   3  'Windows Default
   Begin VB.CommandButton Exit 
      Cancel          =   -1  'True
      Caption         =   "E&xit"
      Height          =   495
      Left            =   5280
      TabIndex        =   35
      Top             =   1080
      Width           =   1335
   End
   Begin VB.CommandButton Solve 
      Caption         =   "Solve"
      Height          =   495
      Left            =   5280
      TabIndex        =   0
      Top             =   360
      Width           =   1335
   End
   Begin VB.TextBox Needs 
      Height          =   285
      Index           =   6
      Left            =   1680
      TabIndex        =   7
      Text            =   "0"
      Top             =   2880
      Width           =   735
   End
   Begin VB.TextBox Needs 
      Height          =   285
      Index           =   5
      Left            =   1680
      TabIndex        =   6
      Text            =   "0"
      Top             =   2520
      Width           =   735
   End
   Begin VB.TextBox Needs 
      Height          =   285
      Index           =   4
      Left            =   1680
      TabIndex        =   5
      Text            =   "0"
      Top             =   2160
      Width           =   735
   End
   Begin VB.TextBox Needs 
      Height          =   285
      Index           =   3
      Left            =   1680
      TabIndex        =   4
      Text            =   "0"
      Top             =   1800
      Width           =   735
   End
   Begin VB.TextBox Needs 
      Height          =   285
      Index           =   2
      Left            =   1680
      TabIndex        =   3
      Text            =   "0"
      Top             =   1440
      Width           =   735
   End
   Begin VB.TextBox Needs 
      Height          =   285
      Index           =   1
      Left            =   1680
      TabIndex        =   2
      Text            =   "0"
      Top             =   1080
      Width           =   735
   End
   Begin VB.TextBox Needs 
      Height          =   285
      Index           =   0
      Left            =   1680
      TabIndex        =   1
      Text            =   "0"
      Top             =   720
      Width           =   735
   End
   Begin VB.Label Total 
      Alignment       =   2  'Center
      Caption         =   "0"
      Height          =   255
      Left            =   2760
      TabIndex        =   34
      Top             =   3480
      Width           =   735
   End
   Begin VB.Label Label6 
      Caption         =   "Total . . . . . . . . . . . . . . . . ."
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   8.25
         Charset         =   0
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   255
      Left            =   720
      TabIndex        =   33
      Top             =   3480
      Width           =   1935
   End
   Begin VB.Label Label5 
      Caption         =   "On Duty"
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   8.25
         Charset         =   0
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   255
      Left            =   3840
      TabIndex        =   32
      Top             =   240
      Width           =   735
   End
   Begin VB.Label Label4 
      Caption         =   "Start"
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   8.25
         Charset         =   0
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   255
      Left            =   2880
      TabIndex        =   31
      Top             =   240
      Width           =   495
   End
   Begin VB.Line Line1 
      Index           =   1
      X1              =   480
      X2              =   4920
      Y1              =   3360
      Y2              =   3360
   End
   Begin VB.Label Label3 
      Caption         =   "Needs"
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   8.25
         Charset         =   0
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   255
      Left            =   1680
      TabIndex        =   30
      Top             =   240
      Width           =   615
   End
   Begin VB.Label Label2 
      Caption         =   "Day"
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   8.25
         Charset         =   0
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   255
      Left            =   840
      TabIndex        =   29
      Top             =   240
      Width           =   495
   End
   Begin VB.Line Line1 
      Index           =   0
      X1              =   480
      X2              =   4920
      Y1              =   600
      Y2              =   600
   End
   Begin VB.Label OnDuty 
      Alignment       =   2  'Center
      BorderStyle     =   1  'Fixed Single
      Caption         =   "0"
      Height          =   255
      Index           =   6
      Left            =   3840
      TabIndex        =   28
      Top             =   2880
      Width           =   735
   End
   Begin VB.Label Label1 
      Caption         =   "Sun"
      Height          =   255
      Index           =   6
      Left            =   840
      TabIndex        =   27
      Top             =   2880
      Width           =   495
   End
   Begin VB.Label Label1 
      Caption         =   "Sat"
      Height          =   255
      Index           =   5
      Left            =   840
      TabIndex        =   26
      Top             =   2520
      Width           =   495
   End
   Begin VB.Label Label1 
      Caption         =   "Fri"
      Height          =   255
      Index           =   4
      Left            =   840
      TabIndex        =   25
      Top             =   2160
      Width           =   495
   End
   Begin VB.Label Label1 
      Caption         =   "Thu"
      Height          =   255
      Index           =   3
      Left            =   840
      TabIndex        =   24
      Top             =   1800
      Width           =   495
   End
   Begin VB.Label Label1 
      Caption         =   "Wed"
      Height          =   255
      Index           =   2
      Left            =   840
      TabIndex        =   23
      Top             =   1440
      Width           =   495
   End
   Begin VB.Label Label1 
      Caption         =   "Tue"
      Height          =   255
      Index           =   1
      Left            =   840
      TabIndex        =   22
      Top             =   1080
      Width           =   495
   End
   Begin VB.Label Label1 
      Caption         =   "Mon"
      Height          =   255
      Index           =   0
      Left            =   840
      TabIndex        =   21
      Top             =   720
      Width           =   495
   End
   Begin VB.Label OnDuty 
      Alignment       =   2  'Center
      BorderStyle     =   1  'Fixed Single
      Caption         =   "0"
      Height          =   255
      Index           =   5
      Left            =   3840
      TabIndex        =   20
      Top             =   2520
      Width           =   735
   End
   Begin VB.Label OnDuty 
      Alignment       =   2  'Center
      BorderStyle     =   1  'Fixed Single
      Caption         =   "0"
      Height          =   255
      Index           =   4
      Left            =   3840
      TabIndex        =   19
      Top             =   2160
      Width           =   735
   End
   Begin VB.Label OnDuty 
      Alignment       =   2  'Center
      BorderStyle     =   1  'Fixed Single
      Caption         =   "0"
      Height          =   255
      Index           =   3
      Left            =   3840
      TabIndex        =   18
      Top             =   1800
      Width           =   735
   End
   Begin VB.Label OnDuty 
      Alignment       =   2  'Center
      BorderStyle     =   1  'Fixed Single
      Caption         =   "0"
      Height          =   255
      Index           =   2
      Left            =   3840
      TabIndex        =   17
      Top             =   1440
      Width           =   735
   End
   Begin VB.Label OnDuty 
      Alignment       =   2  'Center
      BorderStyle     =   1  'Fixed Single
      Caption         =   "0"
      Height          =   255
      Index           =   1
      Left            =   3840
      TabIndex        =   16
      Top             =   1080
      Width           =   735
   End
   Begin VB.Label OnDuty 
      Alignment       =   2  'Center
      BorderStyle     =   1  'Fixed Single
      Caption         =   "0"
      Height          =   255
      Index           =   0
      Left            =   3840
      TabIndex        =   15
      Top             =   720
      Width           =   735
   End
   Begin VB.Label Start 
      Alignment       =   2  'Center
      BorderStyle     =   1  'Fixed Single
      Caption         =   "0"
      Height          =   255
      Index           =   6
      Left            =   2760
      TabIndex        =   14
      Top             =   2880
      Width           =   735
   End
   Begin VB.Label Start 
      Alignment       =   2  'Center
      BorderStyle     =   1  'Fixed Single
      Caption         =   "0"
      Height          =   255
      Index           =   5
      Left            =   2760
      TabIndex        =   13
      Top             =   2520
      Width           =   735
   End
   Begin VB.Label Start 
      Alignment       =   2  'Center
      BorderStyle     =   1  'Fixed Single
      Caption         =   "0"
      Height          =   255
      Index           =   4
      Left            =   2760
      TabIndex        =   12
      Top             =   2160
      Width           =   735
   End
   Begin VB.Label Start 
      Alignment       =   2  'Center
      BorderStyle     =   1  'Fixed Single
      Caption         =   "0"
      Height          =   255
      Index           =   3
      Left            =   2760
      TabIndex        =   11
      Top             =   1800
      Width           =   735
   End
   Begin VB.Label Start 
      Alignment       =   2  'Center
      BorderStyle     =   1  'Fixed Single
      Caption         =   "0"
      Height          =   255
      Index           =   2
      Left            =   2760
      TabIndex        =   10
      Top             =   1440
      Width           =   735
   End
   Begin VB.Label Start 
      Alignment       =   2  'Center
      BorderStyle     =   1  'Fixed Single
      Caption         =   "0"
      Height          =   255
      Index           =   1
      Left            =   2760
      TabIndex        =   9
      Top             =   1080
      Width           =   735
   End
   Begin VB.Label Start 
      Alignment       =   2  'Center
      BorderStyle     =   1  'Fixed Single
      Caption         =   "0"
      Height          =   255
      Index           =   0
      Left            =   2760
      TabIndex        =   8
      Top             =   720
      Width           =   735
   End
End
Attribute VB_Name = "Form1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Private Sub Exit_Click()
   End
End Sub

Private Sub Solve_Click()

' Calls the LINGO DLL to solve the staffing
' model in STAFFPTR.LNG.  Staffing
' requirements are taken from the dialog
' box.

' Get the staffing needs from the dialog box
   Dim dNeeds(7) As Double
   For i = 1 To 7
      dNeeds(i) = Needs(i - 1).Text
   Next i
   
' Create the LINGO environment object
   Dim pLINGO As Long
   pLINGO = LScreateEnvLng()
   If pLINGO = 0 Then
     MsgBox ("Unable to create LINGO Environment.")
     GoTo FinalExit
   End If
   
' Pass LINGO a pointer to the callback routine
   Dim nError As Long
   Dim dBestObj As Double
   dBestObj = 1E+30
   nError = LSsetCallbackSolverLng(pLINGO, _
     AddressOf MySolverCallback, dBestObj)
 
' Open LINGO's log file
   nError = LSopenLogFileLng(pLINGO, "\lingo.log")
   If nError <> 0 Then GoTo ErrorExit
   
' Pass memory transfer pointers to LINGO
   Dim dStart(7) As Double, dOnDuty(7) As Double
   Dim dTotal As Double, dStatus As Double
   
' @POINTER(1)
   nError = LSsetPointerLng(pLINGO, dNeeds(1), nPointersNow)
   If nError <> 0 Then GoTo ErrorExit
   
' @POINTER(2)
   nError = LSsetPointerLng(pLINGO, dStart(1), nPointersNow)
   If nError <> 0 Then GoTo ErrorExit

' @POINTER(3)
   nError = LSsetPointerLng(pLINGO, dOnDuty(1), nPointersNow)
   If nError <> 0 Then GoTo ErrorExit

' @POINTER(4)
   nError = LSsetPointerLng(pLINGO, dTotal, nPointersNow)
   If nError <> 0 Then GoTo ErrorExit

' @POINTER(5)
   nError = LSsetPointerLng(pLINGO, dStatus, nPointersNow)
   If nError <> 0 Then GoTo ErrorExit

' Build LINGO's command script (commands
' are terminated with an ASCII 10
   Dim cScript As String

' Causes LINGO to echo input
   cScript = "SET ECHOIN 1" & Chr(10)

' Read in the model file
   cScript = cScript & _
    "TAKE \lingo11\samples\staffptr.lng" & Chr(10)

' Solve the model
   cScript = cScript & "GO" & Chr(10)

' Quit LINGO DLL
   cScript = cScript & "QUIT" & Chr(10)

' Mark end of script with a null byte
   cScript = cScript & Chr(0)
      
' Run the script
   dStatus = -1#
   nError = LSexecuteScriptLng(pLINGO, cScript)
   
' Close the log file
   LScloseLogFileLng (pLINGO)
   
' Problems?
   If nError <> 0 Or _
    dStatus <> LS_STATUS_GLOBAL_LNG Then
     MsgBox ("Unable to solve!")
     GoTo ErrorExit
   End If
   
' Place Start values in dialog box
   For i = 1 To 7
      Start(i - 1).Caption = dStart(i)
   Next i

' Place On Duty values in dialog box
   For i = 1 To 7
      OnDuty(i - 1).Caption = dOnDuty(i)
   Next i

' Put Total staffing in dialog box
   Total.Caption = dTotal
   
   LSdeleteEnvLng (pLINGO)
   GoTo FinalExit:
   
ErrorExit:

   MsgBox ("LINGO Error Code: " & nError&)
   LSdeleteEnvLng (pLINGO)
   
FinalExit:
   
End Sub
