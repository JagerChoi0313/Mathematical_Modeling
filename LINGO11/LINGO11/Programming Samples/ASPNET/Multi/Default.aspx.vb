' Illustrates calling Lingo from multiple threads.  One log for each thread
' will be written to the \lingo11 folder.

Imports System.Threading

Partial Class _Default

   Inherits System.Web.UI.Page

   <MTAThread()> _
   Public Sub Button1_Click(ByVal sender As Object, ByVal e As System.EventArgs) Handles Button1.Click
      Dim i, j, nPasses As Integer
      nPasses = TextBox1.Text
      For j = 1 To 1
         For i = 1 To nPasses
            ThreadPool.QueueUserWorkItem(AddressOf Go, i)
         Next
      Next
   End Sub

   Shared Sub Go(ByVal stateInfo As Object)

      Dim env As Integer
      Dim lng As New Lingo
      env = lng.LScreateEnvLng()
      If (env = 0) Then
         MsgBox("Unable to create Lingo environment.")
         Exit Sub
      End If

      Dim cLog As String
      cLog = "\lingo11\lingo" & stateInfo.ToString & ".log"
      lng.LSopenLogFileLng(env, cLog)

      Dim cScript As String

      cScript = "take \lingo11\tran.ltf" & Chr(10)
      cScript = cScript + "quit" + Chr(10)

      Dim nErr As Integer
      nErr = Lingo.LSexecuteScriptLng(env, cScript)
      If (nErr <> 0) Then
         MsgBox("Error running script.")
         Exit Sub
      End If

      lng.LScloseLogFileLng(env)

      lng.LSdeleteEnvLng(env)

   End Sub

End Class
