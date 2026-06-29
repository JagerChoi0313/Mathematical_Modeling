' Solves the Pluto staffing model three times for
' three sets of input: pluto1.ldt, pluto2.ldt, and
' pluto3.ldt.  Results are sent to the three files:
' pluto_out1.txt, pluto_out2.txt and pluto_out3.txt.
'
' Assuming you have VBScript installed, you should
' be able to run this example by typing:
'    cscript lingo.vbs
' in a Windows command window.

option explicit

const iForWriting = 2

dim i, cFile, fso, f, shell

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

for i = 1 to 3

' copy next input file
  cFile = "pluto" & i & ".ldt"
  Wscript.echo cFile
  Set f = fso.GetFile( cFile)
  f.Copy( "pluto.ldt")

' run lingo to solve current model
  shell.Run "runlingo.exe pluto.ltf", , True

' copy results
  Set f = fso.GetFile( "pluto_out.txt")
  cFile = "pluto_out" & i & ".txt"
  f.Copy( cFile)
next
