; CLW file contains information for the MFC ClassWizard

[General Info]
Version=1
LastClass=CNewIPDlg
LastTemplate=CDialog
NewFileInclude1=#include "stdafx.h"
NewFileInclude2=#include "staff.h"

ClassCount=4
Class1=CStaffApp
Class2=CStaffDlg
Class3=CAboutDlg

ResourceCount=3
Resource1=IDD_STAFF_DIALOG
Resource2=IDR_MAINFRAME
Class4=CNewIPDlg
Resource3=IDD_NEW_IP_SOLUTION

[CLS:CStaffApp]
Type=0
HeaderFile=staff.h
ImplementationFile=staff.cpp
Filter=N

[CLS:CStaffDlg]
Type=0
HeaderFile=staffDlg.h
ImplementationFile=staffDlg.cpp
Filter=D
LastObject=CStaffDlg
BaseClass=CDialog
VirtualFilter=dWC

[CLS:CAboutDlg]
Type=0
HeaderFile=staffDlg.h
ImplementationFile=staffDlg.cpp
Filter=D

[DLG:IDD_STAFF_DIALOG]
Type=1
Class=CStaffDlg
ControlCount=38
Control1=IDOK,button,1342242817
Control2=IDCANCEL,button,1342242816
Control3=IDC_NEEDS_MON,edit,1350631552
Control4=IDC_NEEDS_TUE,edit,1350631552
Control5=IDC_NEEDS_WED,edit,1350631552
Control6=IDC_NEEDS_THU,edit,1350631552
Control7=IDC_NEEDS_FRI,edit,1350631552
Control8=IDC_NEEDS_SAT,edit,1350631552
Control9=IDC_NEEDS_SUN,edit,1350631552
Control10=IDC_STATIC,static,1342308352
Control11=IDC_STATIC,static,1342308352
Control12=IDC_STATIC,static,1342308352
Control13=IDC_STATIC,static,1342308352
Control14=IDC_STATIC,static,1342308352
Control15=IDC_STATIC,static,1342308352
Control16=IDC_STATIC,static,1342308352
Control17=IDC_STATIC,static,1342308352
Control18=IDC_STATIC,static,1342308352
Control19=IDC_STATIC,button,1342177287
Control20=IDC_STATIC,static,1342308352
Control21=IDC_STATIC,static,1342308352
Control22=IDC_STATIC,button,1342177287
Control23=IDC_STATIC,static,1342308352
Control24=IDC_START_MON,static,1342312449
Control25=IDC_START_TUE,static,1342312449
Control26=IDC_START_WED,static,1342312449
Control27=IDC_START_THU,static,1342312449
Control28=IDC_START_FRI,static,1342312449
Control29=IDC_START_SAT,static,1342312449
Control30=IDC_START_SUN,static,1342312449
Control31=IDC_ON_MON,static,1342312449
Control32=IDC_ON_TUE,static,1342312449
Control33=IDC_ON_WED,static,1342312449
Control34=IDC_ON_THU,static,1342312449
Control35=IDC_ON_FRI,static,1342312449
Control36=IDC_ON_SAT,static,1342312449
Control37=IDC_ON_SUN,static,1342312449
Control38=IDC_COST,static,1342312449

[DLG:IDD_NEW_IP_SOLUTION]
Type=1
Class=CNewIPDlg
ControlCount=8
Control1=IDOK,button,1342242817
Control2=IDCANCEL,button,1342242816
Control3=IDC_STATIC,static,1342308352
Control4=IDC_NEWIP_ITERATION,edit,1342242816
Control5=IDC_STATIC,static,1342308352
Control6=IDC_STATIC,static,1342308352
Control7=IDC_NEWIP_OBJECTIVE,edit,1342242816
Control8=IDC_NEWIP_BOUND,edit,1342242816

[CLS:CNewIPDlg]
Type=0
HeaderFile=NewIPDlg.h
ImplementationFile=NewIPDlg.cpp
BaseClass=CDialog
Filter=D
VirtualFilter=dWC
LastObject=CNewIPDlg

