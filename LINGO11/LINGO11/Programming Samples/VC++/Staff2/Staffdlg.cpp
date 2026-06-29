// staffDlg.cpp : implementation file
//

#include "stdafx.h"
#include "staff.h"
#include "staffDlg.h"
#include "NewIPDlg.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CAboutDlg dialog used for App About

class CAboutDlg : public CDialog
{
public:
	CAboutDlg();

// Dialog Data
	//{{AFX_DATA(CAboutDlg)
	enum { IDD = IDD_ABOUTBOX };
	//}}AFX_DATA

	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CAboutDlg)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	//{{AFX_MSG(CAboutDlg)
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

CAboutDlg::CAboutDlg() : CDialog(CAboutDlg::IDD)
{
	//{{AFX_DATA_INIT(CAboutDlg)
	//}}AFX_DATA_INIT
}

void CAboutDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CAboutDlg)
	//}}AFX_DATA_MAP
}

BEGIN_MESSAGE_MAP(CAboutDlg, CDialog)
	//{{AFX_MSG_MAP(CAboutDlg)
		// No message handlers
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CStaffDlg dialog

CStaffDlg::CStaffDlg(CWnd* pParent /*=NULL*/)
	: CDialog(CStaffDlg::IDD, pParent)
{
	//{{AFX_DATA_INIT(CStaffDlg)
	m_csCost = _T("");
	m_nNeedsFri = 0;
	m_nNeedsMon = 0;
	m_nNeedsSat = 0;
	m_nNeedsSun = 0;
	m_nNeedsThu = 0;
	m_nNeedsTue = 0;
	m_nNeedsWed = 0;
	m_csOnDutyFri = _T("");
	m_csOnDutyMon = _T("");
	m_csOnDutySat = _T("");
	m_csOnDutySun = _T("");
	m_csOnDutyThu = _T("");
	m_csOnDutyTue = _T("");
	m_csOnDutyWed = _T("");
	m_csStartFri = _T("");
	m_csStartMon = _T("");
	m_csStartSat = _T("");
	m_csStartSun = _T("");
	m_csStartThu = _T("");
	m_csStartTue = _T("");
	m_csStartWed = _T("");
	//}}AFX_DATA_INIT
	// Note that LoadIcon does not require a subsequent DestroyIcon in Win32
	m_hIcon = AfxGetApp()->LoadIcon(IDR_MAINFRAME);
  
}

void CStaffDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CStaffDlg)
	DDX_Text(pDX, IDC_COST, m_csCost);
	DDX_Text(pDX, IDC_NEEDS_FRI, m_nNeedsFri);
	DDV_MinMaxInt(pDX, m_nNeedsFri, 0, 1000);
	DDX_Text(pDX, IDC_NEEDS_MON, m_nNeedsMon);
	DDV_MinMaxInt(pDX, m_nNeedsMon, 0, 1000);
	DDX_Text(pDX, IDC_NEEDS_SAT, m_nNeedsSat);
	DDV_MinMaxInt(pDX, m_nNeedsSat, 0, 1000);
	DDX_Text(pDX, IDC_NEEDS_SUN, m_nNeedsSun);
	DDV_MinMaxInt(pDX, m_nNeedsSun, 0, 1000);
	DDX_Text(pDX, IDC_NEEDS_THU, m_nNeedsThu);
	DDV_MinMaxInt(pDX, m_nNeedsThu, 0, 1000);
	DDX_Text(pDX, IDC_NEEDS_TUE, m_nNeedsTue);
	DDV_MinMaxInt(pDX, m_nNeedsTue, 0, 1000);
	DDX_Text(pDX, IDC_NEEDS_WED, m_nNeedsWed);
	DDV_MinMaxInt(pDX, m_nNeedsWed, 0, 1000);
	DDX_Text(pDX, IDC_ON_FRI, m_csOnDutyFri);
	DDX_Text(pDX, IDC_ON_MON, m_csOnDutyMon);
	DDX_Text(pDX, IDC_ON_SAT, m_csOnDutySat);
	DDX_Text(pDX, IDC_ON_SUN, m_csOnDutySun);
	DDX_Text(pDX, IDC_ON_THU, m_csOnDutyThu);
	DDX_Text(pDX, IDC_ON_TUE, m_csOnDutyTue);
	DDX_Text(pDX, IDC_ON_WED, m_csOnDutyWed);
	DDX_Text(pDX, IDC_START_FRI, m_csStartFri);
	DDX_Text(pDX, IDC_START_MON, m_csStartMon);
	DDX_Text(pDX, IDC_START_SAT, m_csStartSat);
	DDX_Text(pDX, IDC_START_SUN, m_csStartSun);
	DDX_Text(pDX, IDC_START_THU, m_csStartThu);
	DDX_Text(pDX, IDC_START_TUE, m_csStartTue);
	DDX_Text(pDX, IDC_START_WED, m_csStartWed);
	//}}AFX_DATA_MAP
}

BEGIN_MESSAGE_MAP(CStaffDlg, CDialog)
	//{{AFX_MSG_MAP(CStaffDlg)
	ON_WM_SYSCOMMAND()
	ON_WM_PAINT()
	ON_WM_QUERYDRAGICON()
	ON_BN_CLICKED(IDOK, OnSolve)
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CStaffDlg message handlers

BOOL CStaffDlg::OnInitDialog()
{
	CDialog::OnInitDialog();

	// Add "About..." menu item to system menu.

	// IDM_ABOUTBOX must be in the system command range.
	ASSERT((IDM_ABOUTBOX & 0xFFF0) == IDM_ABOUTBOX);
	ASSERT(IDM_ABOUTBOX < 0xF000);

	CMenu* pSysMenu = GetSystemMenu(FALSE);
	if (pSysMenu != NULL)
	{
		CString strAboutMenu;
		strAboutMenu.LoadString(IDS_ABOUTBOX);
		if (!strAboutMenu.IsEmpty())
		{
			pSysMenu->AppendMenu(MF_SEPARATOR);
			pSysMenu->AppendMenu(MF_STRING, IDM_ABOUTBOX, strAboutMenu);
		}
	}

	// Set the icon for this dialog.  The framework does this automatically
	//  when the application's main window is not a dialog
	SetIcon(m_hIcon, TRUE);			// Set big icon
	SetIcon(m_hIcon, FALSE);		// Set small icon
	
	// TODO: Add extra initialization here
	
	return TRUE;  // return TRUE  unless you set the focus to a control
}

void CStaffDlg::OnSysCommand(UINT nID, LPARAM lParam)
{
	if ((nID & 0xFFF0) == IDM_ABOUTBOX)
	{
		CAboutDlg dlgAbout;
		dlgAbout.DoModal();
	}
	else
	{
		CDialog::OnSysCommand(nID, lParam);
	}
}

// If you add a minimize button to your dialog, you will need the code below
//  to draw the icon.  For MFC applications using the document/view model,
//  this is automatically done for you by the framework.

void CStaffDlg::OnPaint() 
{
	if (IsIconic())
	{
		CPaintDC dc(this); // device context for painting

		SendMessage(WM_ICONERASEBKGND, (WPARAM) dc.GetSafeHdc(), 0);

		// Center icon in client rectangle
		int cxIcon = GetSystemMetrics(SM_CXICON);
		int cyIcon = GetSystemMetrics(SM_CYICON);
		CRect rect;
		GetClientRect(&rect);
		int x = (rect.Width() - cxIcon + 1) / 2;
		int y = (rect.Height() - cyIcon + 1) / 2;

		// Draw the icon
		dc.DrawIcon(x, y, m_hIcon);
	}
	else
	{
		CDialog::OnPaint();
	}
}

// The system calls this to obtain the cursor to display while the user drags
//  the minimized window.
HCURSOR CStaffDlg::OnQueryDragIcon()
{
	return (HCURSOR) m_hIcon;
}


/////////////////////////////////////////////////////////////////////////////

int __stdcall MyCallback( void* pModel, int nReserved, void* pUserData)
{

// Callback function called by the LINGO solver
//
// return value: >= 0 if solver is to continue, else < 0 to interrupt

   // Get current best IP
   int nErr;
   double dBestIP;
   nErr = LSgetCallbackInfoLng( pModel, LS_DINFO_MIP_BEST_OBJECTIVE_LNG, &dBestIP);
   if ( nErr) return( 0);

   // Get best IP value published in dialog box
   double* pdBestIPShown = (double*) pUserData;

   // Is current better than incumbent?
   if ( dBestIP < *pdBestIPShown && dBestIP > -1.e300)
   {

      // Yes ... save its value
      *pdBestIPShown = dBestIP; 

      // Get iteration count from LINGO

      int nIterations;
      LSgetCallbackInfoLng( pModel, LS_IINFO_ITERATIONS_LNG,
       &nIterations);

      // Get bound on solution
      double dBound;
      LSgetCallbackInfoLng( pModel, LS_DINFO_MIP_BOUND_LNG, &dBound);

      // Create a dialog to show the current solution value
      CNewIPDlg dlgNewIP;

      // Initialize the fields of the dialog
      dlgNewIP.m_csIteration.Format( "%d", nIterations);
      dlgNewIP.m_csObjective.Format( "%d", (int) dBestIP);
      dlgNewIP.m_csBound.Format( "%d", (int) dBound);

      // Post the dialog and check for a user interrupt
      if ( dlgNewIP.DoModal() == IDCANCEL) return( -1);
   }

   return( 0);

}

/////////////////////////////////////////////////////////////////////////////

void CStaffDlg::OnSolve() 
{

   int nError, nPointersNow; 
   double dNeeds[7], dStart[7], dOnDuty[7], dStatus, dTotal;
   CString csScript, cs, csDays;

   double dBestIPShown = 1.e+30;

   // Get user's staffing requirements from our dialog box
   UpdateData();
   
   // Load staffing requirements into the LINGO transfer array.
   // LINGO uses double precision for all values.
   dNeeds[ 0] = (double) m_nNeedsMon;
   dNeeds[ 1] = (double) m_nNeedsTue;
   dNeeds[ 2] = (double) m_nNeedsWed;
   dNeeds[ 3] = (double) m_nNeedsThu;
   dNeeds[ 4] = (double) m_nNeedsFri;
   dNeeds[ 5] = (double) m_nNeedsSat;
   dNeeds[ 6] = (double) m_nNeedsSun;

   // load days of week set
   csDays = "MON\n";
   csDays = csDays + "TUE\n";
   csDays = csDays + "WED\n";
   csDays = csDays + "THU\n";
   csDays = csDays + "FRI\n";
   csDays = csDays + "SAT\n";
   csDays = csDays + "SUN";

   // create the LINGO environment object
	pLSenvLINGO pLINGO;
   pLINGO = LScreateEnvLng();
   if ( !pLINGO) 
   {
      AfxMessageBox("Unable to create LINGO Environment");
      return;
   }

   // Pass LINGO a pointer to our callback function
   nError = LSsetCallbackSolverLng( pLINGO, &MyCallback, &dBestIPShown);
   if ( nError) goto ErrorExit;

   // Open LINGO's log file  
   nError = LSopenLogFileLng( pLINGO, "\\LINGO.log");
   if ( nError) goto ErrorExit;

   // Pass memory transfer pointers to LINGO
   // @POINTER(1)
   nError = LSsetPointerLng( pLINGO, (void*)(LPCTSTR) csDays,
    &nPointersNow); 
   if ( nError) goto ErrorExit;

   // Pass memory transfer pointers to LINGO
   // @POINTER(2)
   nError = LSsetPointerLng( pLINGO, dNeeds, &nPointersNow); 
   if ( nError) goto ErrorExit;

   // @POINTER(3)
   nError = LSsetPointerLng( pLINGO, dStart, &nPointersNow);
   if ( nError) goto ErrorExit;

   // @POINTER(4)
   nError = LSsetPointerLng( pLINGO, dOnDuty, &nPointersNow);
   if ( nError) goto ErrorExit;
 
   // @POINTER(5)
   nError = LSsetPointerLng( pLINGO, &dTotal, &nPointersNow);
   if ( nError) goto ErrorExit;

   // @POINTER(6)
   nError = LSsetPointerLng( pLINGO, &dStatus, &nPointersNow);
   if ( nError) goto ErrorExit;

   // Here is the script we want LINGO to run
   csScript = "SET ECHOIN 1\n";
   csScript = csScript +
    "TAKE \\LINGO11\\SAMPLES\\STAFFPTR2.LNG\n";
   csScript = csScript +
    "GO\n";
   csScript = csScript +
    "QUIT\n";

   // Run the script
   dStatus = -1.e0;
   nError = LSexecuteScriptLng( pLINGO, (LPCTSTR) csScript);

   // Close the log file
   LScloseLogFileLng( pLINGO);

   // Any problems?
   if ( nError || dStatus != LS_STATUS_GLOBAL_LNG)
   {

      // Had a problem   
      AfxMessageBox("Unable to solve!");

   } else {

      // Everything went ok ... load results into the dialog box
      m_csStartMon.Format( "%d", (int) dStart[0]);
      m_csStartTue.Format( "%d", (int) dStart[1]);
      m_csStartWed.Format( "%d", (int) dStart[2]);
      m_csStartThu.Format( "%d", (int) dStart[3]);
      m_csStartFri.Format( "%d", (int) dStart[4]);
      m_csStartSat.Format( "%d", (int) dStart[5]);
      m_csStartSun.Format( "%d", (int) dStart[6]);
   
      m_csOnDutyMon.Format( "%d", (int) dOnDuty[0]);
      m_csOnDutyTue.Format( "%d", (int) dOnDuty[1]);
      m_csOnDutyWed.Format( "%d", (int) dOnDuty[2]);
      m_csOnDutyThu.Format( "%d", (int) dOnDuty[3]);
      m_csOnDutyFri.Format( "%d", (int) dOnDuty[4]);
      m_csOnDutySat.Format( "%d", (int) dOnDuty[5]);
      m_csOnDutySun.Format( "%d", (int) dOnDuty[6]);
   
      m_csCost.Format( "%g", dTotal);
   
      UpdateData( FALSE);
      
   }

   goto Exit;

ErrorExit:
   cs.Format( "LINGO Errorcode: %d", nError);
   AfxMessageBox( cs);
   return;

Exit:
   LSdeleteEnvLng( pLINGO);

}

/////////////////////////////////////////////////////////////////////////////
