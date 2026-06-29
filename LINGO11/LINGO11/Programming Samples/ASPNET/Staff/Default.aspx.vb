' *** Calls Lingo to optimize a simple staff scheduling model ***

Imports System.Runtime.InteropServices

Partial Class _Default
   Inherits System.Web.UI.Page

   Protected Sub btnSolve_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles btnSolve.Click
      Solve()
   End Sub

   Protected Sub Solve()

      Dim dNeeds(7), dStart(7), dOnDuty(7), dObj(1), dStatus(1) As Double
      Dim env, nErr, nPointers, nStatus As Integer

      ' Create the lingo object
      Dim lng As New Lingo

      ' Clear label error
      lblError.Text = ""

      ' Load staffing needs from text boxes
      Try
         dNeeds(0) = txtNeedsMon.Text
         dNeeds(1) = txtNeedsTue.Text
         dNeeds(2) = txtNeedsWed.Text
         dNeeds(3) = txtNeedsThu.Text
         dNeeds(4) = txtNeedsFri.Text
         dNeeds(5) = txtNeedsSat.Text
         dNeeds(6) = txtNeedsSun.Text
      Catch
         lblError.Text = "Input a positive, integer value for each day."
         Exit Sub
      End Try

      ' Create a lingo environment
      env = lng.LScreateEnvLng()
      If (env = 0) Then
         lblError.Text = "Unable to create Lingo environment."
         Exit Sub
      End If

      ' Create a log file (useful for debugging)
      nErr = Lingo.LSopenLogFileLng(env, "lingo.log")
      If (nErr <> 0) Then
         lblError.Text = "Unable to open log file."
         Exit Sub
      End If

      ' .NET garbage collection may move arrays around.  We must
      ' pin them in memory until lingo is through with them.

      ' Pass lingo a pointer to the staffing needs
      Dim Need As New clsArray
      Dim pdNeed As New IntPtr
      pdNeed = Marshal.AllocHGlobal(Marshal.SizeOf(Need))
      Marshal.StructureToPtr(Need, pdNeed, False)
      Need.dArray = dNeeds
      nErr = Lingo.LSsetPointerLng(env, dNeeds(0), nPointers)
      If (nErr <> 0) Then
         lblError.Text = "Unable to pass Needs array."
         Exit Sub
      End If

      ' Pass lingo a pointer to the array for storing the staffing starts
      Dim Start As New clsArray
      Dim pdStart As New IntPtr
      pdStart = Marshal.AllocHGlobal(Marshal.SizeOf(Start))
      Marshal.StructureToPtr(Start, pdStart, False)
      nErr = Lingo.LSsetPointerLng2(env, pdStart, nPointers)
      If (nErr <> 0) Then
         lblError.Text = "Unable to pass Start array."
         Exit Sub
      End If

      ' A pointer for storing the on duty count for each day
      Dim OnDuty As New clsArray
      Dim pdOnDuty As New IntPtr
      pdOnDuty = Marshal.AllocHGlobal(Marshal.SizeOf(OnDuty))
      Marshal.StructureToPtr(OnDuty, pdOnDuty, False)
      nErr = Lingo.LSsetPointerLng2(env, pdOnDuty, nPointers)
      If (nErr <> 0) Then
         lblError.Text = "Unable to pass OnDuty address."
         Exit Sub
      End If

      ' A pointer to the where the objective value will be stored
      Dim Obj As New clsScalar
      Dim pdObj As New IntPtr
      pdObj = Marshal.AllocHGlobal(Marshal.SizeOf(Obj))
      Marshal.StructureToPtr(Obj, pdObj, False)
      nErr = Lingo.LSsetPointerLng2(env, pdObj, nPointers)
      If (nErr <> 0) Then
         lblError.Text = "Unable to pass objective address."
         Exit Sub
      End If

      ' A pointer to where the solution status will be stored
      Dim Status As New clsScalar
      Dim pdStatus As New IntPtr()
      pdStatus = Marshal.AllocHGlobal(Marshal.SizeOf(Status))
      Marshal.StructureToPtr(Status, pdStatus, False)
      dStatus(0) = -1
      Status.dScalar = dStatus
      nErr = Lingo.LSsetPointerLng2(env, pdStatus, nPointers)
      If (nErr <> 0) Then
         lblError.Text = "Unable to pass status address."
         Exit Sub
      End If

      ' Let Lingo know we have a callback function 
      ' (note: this step is optional)
      Dim cb As Lingo.typCallbackSolver
      Dim clscb As New clsCallback
      cb = AddressOf clscb.MySolverCallback
      Dim dCount As Double = 0
      nErr = Lingo.LSsetCallbackSolverLng(env, cb, dCount)
      If (nErr <> 0) Then
         lblError.Text = "Unable to register callback."
         Exit Sub
      End If

      ' Here is the script we want LINGO to run. 
      Dim cScript As String
      cScript = "take \lingo11\samples\staffptr.lng" & Chr(10)
      cScript = cScript & "gen" & Chr(10) & "go" & Chr(10) & "quit" & Chr(10) & Chr(0)

      ' Run the script
      nErr = Lingo.LSexecuteScriptLng(env, cScript)

      Lingo.LScloseLogFileLng(env)
      If (nErr <> 0) Then
         lblError.Text = "Unable to close log."
         Exit Sub
      End If

      ' Marshal the staff starting array back to the managed structure
      Marshal.PtrToStructure(pdStart, Start)
      dStart = Start.dArray
      Marshal.PtrToStructure(pdOnDuty, OnDuty)
      dOnDuty = OnDuty.dArray
      Marshal.PtrToStructure(pdObj, Obj)
      dObj = Obj.dScalar
      Marshal.PtrToStructure(pdStatus, Status)
      dStatus = Status.dScalar
      nStatus = dStatus(0)

      ' Place results on the page
      lblStartMon.Text = dStart(0)
      lblStartTue.Text = dStart(1)
      lblStartWed.Text = dStart(2)
      lblStartThu.Text = dStart(3)
      lblStartFri.Text = dStart(4)
      lblStartSat.Text = dStart(5)
      lblStartSun.Text = dStart(6)

      lblOnDutyMon.Text = dOnDuty(0)
      lblOnDutyTue.Text = dOnDuty(1)
      lblOnDutyWed.Text = dOnDuty(2)
      lblOnDutyThu.Text = dOnDuty(3)
      lblOnDutyFri.Text = dOnDuty(4)
      lblOnDutySat.Text = dOnDuty(5)
      lblOnDutySun.Text = dOnDuty(6)

      lblTotal.Text = dObj(0)

      lblCallbacks.Text = "Callbacks: " + dCount.ToString

      If (nErr <> 0 Or nStatus <> 0) Then
         lblError.Text = "Unable to solve."
         Exit Sub
      End If

      ' Free memory in global heap
      Marshal.FreeHGlobal(pdNeed)
      Marshal.FreeHGlobal(pdStart)
      Marshal.FreeHGlobal(pdOnDuty)
      Marshal.FreeHGlobal(pdObj)
      Marshal.FreeHGlobal(pdStatus)

      ' Release the lingo object
      lng.LSdeleteEnvLng(env)

   End Sub

End Class

<StructLayout(LayoutKind.Sequential)> _
Public Class clsArray
   <MarshalAs(UnmanagedType.ByValArray, SizeConst:=7)> _
   Public dArray As Double()
End Class

<StructLayout(LayoutKind.Sequential)> _
Public Class clsScalar
   <MarshalAs(UnmanagedType.ByValArray, SizeConst:=1)> _
   Public dScalar As Double()
End Class

Public Class clsCallback
   Public Function MySolverCallback(ByVal pModel As Integer, _
    ByVal nReserved As Integer, ByRef dCallCount As Double) As Integer
      dCallCount = dCallCount + 1
   End Function
End Class

