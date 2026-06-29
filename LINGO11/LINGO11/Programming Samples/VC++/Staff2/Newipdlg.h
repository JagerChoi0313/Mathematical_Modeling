#if !defined(AFX_NEWIPDLG_H__B48BE333_D0C2_11D6_AC92_00010240D2AE__INCLUDED_)
#define AFX_NEWIPDLG_H__B48BE333_D0C2_11D6_AC92_00010240D2AE__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000
// NewIPDlg.h : header file
//

/////////////////////////////////////////////////////////////////////////////
// CNewIPDlg dialog

class CNewIPDlg : public CDialog
{
// Construction
public:
	CNewIPDlg(CWnd* pParent = NULL);   // standard constructor

// Dialog Data
	//{{AFX_DATA(CNewIPDlg)
	enum { IDD = IDD_NEW_IP_SOLUTION };
	CString	m_csBound;
	CString	m_csIteration;
	CString	m_csObjective;
	//}}AFX_DATA


// Overrides
	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CNewIPDlg)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:

	// Generated message map functions
	//{{AFX_MSG(CNewIPDlg)
		// NOTE: the ClassWizard will add member functions here
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_NEWIPDLG_H__B48BE333_D0C2_11D6_AC92_00010240D2AE__INCLUDED_)
