// NewIPDlg.cpp : implementation file
//

#include "stdafx.h"
#include "staff.h"
#include "NewIPDlg.h"

#ifdef _DEBUG
#define new DEBUG_NEW
#undef THIS_FILE
static char THIS_FILE[] = __FILE__;
#endif

/////////////////////////////////////////////////////////////////////////////
// CNewIPDlg dialog


CNewIPDlg::CNewIPDlg(CWnd* pParent /*=NULL*/)
	: CDialog(CNewIPDlg::IDD, pParent)
{
	//{{AFX_DATA_INIT(CNewIPDlg)
	m_csBound = _T("");
	m_csIteration = _T("");
	m_csObjective = _T("");
	//}}AFX_DATA_INIT
}


void CNewIPDlg::DoDataExchange(CDataExchange* pDX)
{
	CDialog::DoDataExchange(pDX);
	//{{AFX_DATA_MAP(CNewIPDlg)
	DDX_Text(pDX, IDC_NEWIP_BOUND, m_csBound);
	DDX_Text(pDX, IDC_NEWIP_ITERATION, m_csIteration);
	DDX_Text(pDX, IDC_NEWIP_OBJECTIVE, m_csObjective);
	//}}AFX_DATA_MAP
}


BEGIN_MESSAGE_MAP(CNewIPDlg, CDialog)
	//{{AFX_MSG_MAP(CNewIPDlg)
		// NOTE: the ClassWizard will add message map macros here
	//}}AFX_MSG_MAP
END_MESSAGE_MAP()

/////////////////////////////////////////////////////////////////////////////
// CNewIPDlg message handlers
