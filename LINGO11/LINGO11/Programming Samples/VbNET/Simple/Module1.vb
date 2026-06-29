' Illustrates calling the Lingo DLL from VB.NET to
' solve the simple product mix model:
'    Max 100 Standard + 150 Turbo;
'    S.T.
'       Standard <= 100
'       Turbo <= 120
'       Standard + 2 * Turbo < 160;
'      
'  Note: The model template file, samples\simple.lng,
'  must be present in order to run this example.
'       

Option Explicit On 

Imports System.Runtime.InteropServices

<StructLayout(LayoutKind.Sequential)> _
Public Class clsProduce
    <MarshalAs(UnmanagedType.ByValArray, SizeConst:=2)> _
    Public dProduce As Double()
End Class

<StructLayout(LayoutKind.Sequential)> _
Public Class clsProfit
    <MarshalAs(UnmanagedType.ByValArray, SizeConst:=2)> _
    Public dProfit As Double()
End Class

<StructLayout(LayoutKind.Sequential)> _
Public Class clsLimit
    <MarshalAs(UnmanagedType.ByValArray, SizeConst:=2)> _
    Public dLimit As Double()
End Class

<StructLayout(LayoutKind.Sequential)> _
Public Class clsLabor
    <MarshalAs(UnmanagedType.ByValArray, SizeConst:=2)> _
    Public dLabor As Double()
End Class

<StructLayout(LayoutKind.Sequential)> _
Public Class clsObjective
    <MarshalAs(UnmanagedType.ByValArray, SizeConst:=1)> _
    Public dObjective As Double()
End Class

<StructLayout(LayoutKind.Sequential)> _
Public Class clsStatus
    <MarshalAs(UnmanagedType.ByValArray, SizeConst:=1)> _
    Public dStatus As Double()
End Class

<StructLayout(LayoutKind.Sequential)> _
Public Class clsComputers
    <MarshalAs(UnmanagedType.ByValArray, SizeConst:=64)> _
    Public cComputers As Byte()
End Class

Public Class clsCallback
    Public Function MySolverCallback(ByVal pModel As Integer, _
     ByVal nReserved As Integer, ByRef dBestIP As Double) As Integer
        'Console.WriteLine("In callback")
    End Function
End Class

Public Class Form1
    Public Function RunLingo()

        Dim lingo As Lingo
        Dim pLingoEnv As Integer
        Dim nIterations As Integer = -1
        Dim nError As Integer
        Dim nPointersNow As Integer = -1
        Dim dObjective(1) As Double
        Dim dStatus(1) As Double
        dStatus(0) = -1

        'Model data that gets referenced by the
        'template model, simple.lng
        Dim dProfit(1) As Double
        dProfit(0) = 100
        dProfit(1) = 150

        Dim dLimit(1) As Double
        dLimit(0) = 100
        dLimit(1) = 120

        Dim dLabor(1) As Double
        dLabor(0) = 1
        dLabor(1) = 2

        Dim dProduce(1) As Double
        dProduce(0) = -1
        dProduce(1) = -1

        Dim strComputers As String
        Dim cComputers(64) As Byte
        strComputers = "STANDARD" & Chr(10) & "TURBO" & Chr(10) & Chr(0)
        Dim i As Integer
        i = strComputers.Length
        For i = 0 To strComputers.Length - 1
           cComputers(i) = Asc(strComputers(i))
        Next i

        ' Get a pointer to a Lingo environment
        pLingoEnv = lingo.LScreateEnvLng()
        If (pLingoEnv = 0) Then
            Console.WriteLine("Unable to create Lingo environment.")
            GoTo FinalExit
        End If

        ' Open LINGO's log file  
        nError = lingo.LSopenLogFileLng(pLingoEnv, "lingo.log")
        If (nError <> 0) Then
            GoTo ErrorExit
        End If

        ' Pass Lingo the pointer to the objective coefficients (refer
        ' to the template model, simple.lng)
        Dim pdProfit As New IntPtr()
        Dim Profit As New clsProfit()
        Profit.dProfit = dProfit
        ' Allocate space for production array on the unmanaged heap
        pdProfit = Marshal.AllocHGlobal(Marshal.SizeOf(Profit))
        ' Marshal production array to the unmanaged address
        Marshal.StructureToPtr(Profit, pdProfit, False)
        ' Pass Lingo the unmanaged pointer to the production array
        nError = lingo.LSsetPointerLng2(pLingoEnv, pdProfit, nPointersNow)
        If (nError <> 0) Then
            GoTo ErrorExit
        End If

        ' Pass a pointer to the production limits
        Dim pdLimit As New IntPtr()
        Dim Limit As New clsLimit
        Limit.dLimit = dLimit
        pdLimit = Marshal.AllocHGlobal(Marshal.SizeOf(Limit))
        Marshal.StructureToPtr(Limit, pdLimit, False)
        nError = lingo.LSsetPointerLng2(pLingoEnv, pdLimit, nPointersNow)
        If (nError <> 0) Then
            GoTo ErrorExit
        End If

        ' Pass a pointer to the labor utilization coefficients
        Dim pdLabor As New IntPtr()
        Dim Labor As New clsLabor
        Labor.dLabor = dLabor
        pdLabor = Marshal.AllocHGlobal(Marshal.SizeOf(Labor))
        Marshal.StructureToPtr(Labor, pdLabor, False)
        nError = lingo.LSsetPointerLng2(pLingoEnv, pdLabor, nPointersNow)
        If (nError <> 0) Then
            GoTo ErrorExit
        End If

        ' Point to dObjective, where Lingo will return the objective value
        Dim pdObjective As New IntPtr()
        Dim Objective As New clsObjective
        Objective.dObjective = dObjective
        pdObjective = Marshal.AllocHGlobal(Marshal.SizeOf(Objective))
        Marshal.StructureToPtr(Objective, pdObjective, False)
        nError = lingo.LSsetPointerLng2(pLingoEnv, pdObjective, nPointersNow)
        If (nError <> 0) Then
            GoTo ErrorExit
        End If

        ' Pointer to the solution status code
        Dim pdStatus As New IntPtr()
        Dim Status As New clsStatus
        Status.dStatus = dStatus
        pdStatus = Marshal.AllocHGlobal(Marshal.SizeOf(Status))
        Marshal.StructureToPtr(Status, pdStatus, False)
        nError = lingo.LSsetPointerLng2(pLingoEnv, pdStatus, nPointersNow)
        If (nError <> 0) Then
            GoTo ErrorExit
        End If

        ' Pass a pointer to the variable value array
        Dim pdProduce As New IntPtr()
        Dim Produce As New clsProduce()
        Produce.dProduce = dProduce
        pdProduce = Marshal.AllocHGlobal(Marshal.SizeOf(Produce))
        Marshal.StructureToPtr(Produce, pdProduce, False)
        nError = lingo.LSsetPointerLng2(pLingoEnv, pdProduce, nPointersNow)
        If (nError <> 0) Then
            GoTo ErrorExit
        End If

        ' Pass a pointer to the computer models set
        Dim pcComputers As New IntPtr()
        Dim Computers As New clsComputers()
        Computers.cComputers = cComputers
        pcComputers = Marshal.AllocHGlobal(Marshal.SizeOf(Computers))
        Marshal.StructureToPtr(Computers, pcComputers, False)
        nError = lingo.LSsetPointerLng2(pLingoEnv, pcComputers, nPointersNow)
        If (nError <> 0) Then
            GoTo ErrorExit
        End If

        ' Let Lingo know we have a callback function (note: this step 
        ' is optional)
        Dim cb As Lingo.typCallbackSolver
        Dim clscb As New clsCallback()
        cb = AddressOf clscb.MySolverCallback
        Dim dData As Double
        nError = lingo.LSsetCallbackSolverLng(pLingoEnv, cb, dData)

        ' Here is the script we want LINGO to run. 
        Dim cScript As String
        cScript = "set echoin 1" & Chr(10)
        cScript = cScript & "take \lingo11\programming samples\vbnet\simple\simple.lng" & Chr(10)
        cScript = cScript & "go" & Chr(10) & "quit" & Chr(10) & Chr(0)

        ' Run the script
        nError = lingo.LSexecuteScriptLng(pLingoEnv, cScript)

        ' Marshal the production quantities back to the managed structure
        Marshal.PtrToStructure(pdProduce, Produce)
        ' Copy to original array
        dProduce(0) = Produce.dProduce(0)
        dProduce(1) = Produce.dProduce(1)

        ' Marshal the status code back to the managed structure
        Marshal.PtrToStructure(pdStatus, Status)
        dStatus(0) = Status.dStatus(0)

        ' Marshal the objective value back to the managed structure
        Marshal.PtrToStructure(pdObjective, Objective)
        dObjective(0) = Objective.dObjective(0)

        ' Free memory in global heap
        Marshal.FreeHGlobal(pdProduce)
        Marshal.FreeHGlobal(pdProfit)
        Marshal.FreeHGlobal(pdLimit)
        Marshal.FreeHGlobal(pdLabor)
        Marshal.FreeHGlobal(pdObjective)
        Marshal.FreeHGlobal(pdStatus)

        ' Close the log file
        lingo.LScloseLogFileLng(pLingoEnv)
        '
        ' Any problems?
        If (nError <> 0 Or _
         dStatus(0) <> lingo.LSstatusCodeLng.LS_STATUS_GLOBAL_LNG) Then

            ' Had a problem   
            Console.WriteLine("Unable to solve!")

        Else

            ' Everything went OK ... print results
            Console.WriteLine("Standards: " & dProduce(0))
            Console.WriteLine("   Turbos: " & dProduce(1))
            Console.WriteLine("   Profit: " & dObjective(0))

        End If

        GoTo NormalExit

ErrorExit:
        Console.WriteLine("LINGO Error Code: " & nError)

NormalExit:
        ' Free Lingo's environment to avoid a memory leak
        lingo.LSdeleteEnvLng(pLingoEnv)

FinalExit:
        Console.WriteLine("press enter...")
        Dim sTemp As String
        sTemp = Console.ReadLine()

    End Function
End Class

Module Module1
    Sub Main()

        Dim f1 As New Form1()
        Call f1.RunLingo()

    End Sub
End Module

