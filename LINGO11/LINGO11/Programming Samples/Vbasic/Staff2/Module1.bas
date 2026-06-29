Attribute VB_Name = "Mod_Callback"
Public Function MySolverCallback(ByVal pModel As Long, _
 ByVal nReserved As Long, ByRef dBestIP As Double) As Long
 
' Callback function called by the LINGO DLL
' during model solution.
'
' Return value: >= 0 if solver is to continue,
'  else < 0 to interrupt the solver
   Dim nReturnVal As Long
   nReturnVal = 0
 
' Get current best IP
   Dim dObj As Double
   Dim nError As Long
   nError = LSgetCallbackInfoDoubleLng(pModel, _
    LS_DINFO_MIP_BEST_OBJECTIVE_LNG, dObj)
    
' Check for any error
   If (nError = LSERR_NO_ERROR_LNG) Then

' Is it better than the best one displayed so far?
      If (dObj < dBestIP And Abs(dObj) < 1E+300) Then

' Yes...display this solution

' Save the new best objective value
         dBestIP = dObj

' Get the iteration count from LINGO
         Dim nIterations As Long
         nResult = LSgetCallbackInfoLongLng(pModel, _
          LS_IINFO_ITERATIONS_LNG, nIterations)

' Get the objective bound from LINGO
         Dim dBound As Double
         nResult = LSgetCallbackInfoDoubleLng(pModel, _
          LS_DINFO_MIP_BOUND_LNG, dBound)

' Display the information in a dialog box
         Dim nButtonPressed
         Dim cMessage As String
         cMessage = "Objective:" + Str(dBestIP) _
          + Chr(10) + "Bound:" + Str(dBound) _
          + Chr(10) + "Iterations:" + Str(nIterations)
         nButtonPressed = MsgBox(cMessage, vbOKCancel)
         If (nButtonPressed = vbCancel) Then
            nReturnVal = -1
         End If
         
      End If
   End If
   
   MySolverCallback = nReturnVal

End Function


