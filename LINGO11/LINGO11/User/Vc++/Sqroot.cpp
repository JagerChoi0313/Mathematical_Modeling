// sqroot.cpp

#include "stdafx.h"
#include "sqroot.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

BEGIN_MESSAGE_MAP(CSqrootApp, CWinApp)
	//{{AFX_MSG_MAP(CSqrootApp)
		// NOTE - the ClassWizard will add and remove mapping macros here.
		//    DO NOT EDIT what you see in these blocks of generated code!
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

CSqrootApp::CSqrootApp()
{

// The constructor

   // Remove next line for a "quiet" version of MyUser.DLL
   AfxMessageBox("@USER DLL installed!");
}

CSqrootApp theApp;

#include <math.h>

extern "C" __declspec( dllexport) void MYUSER( int* pnNumberOfArgs,
 double* pdArgs, double* dResult)
{

// This is the routine called by LINGO.  Here we simply take the 
// square root of the first argument to the @USER function.

   *dResult = sqrt( *pdArgs);
}
