// staffDlg.h : header file
//

#include "lingd11.h"

#if !defined(AFX_STAFFDLG_H__74D746B7_CA4D_11D6_AC89_00010240D2AE__INCLUDED_)
#define AFX_STAFFDLG_H__74D746B7_CA4D_11D6_AC89_00010240D2AE__INCLUDED_

#if _MSC_VER > 1000
#pragma once
#endif // _MSC_VER > 1000

/////////////////////////////////////////////////////////////////////////////
// CStaffDlg dialog

class CStaffDlg : public CDialog
{
// Construction
public:
	CStaffDlg(CWnd* pParent = NULL);	// standard constructor

// Dialog Data
	//{{AFX_DATA(CStaffDlg)
	enum { IDD = IDD_STAFF_DIALOG };
	CString	m_csCost;
	int		m_nNeedsFri;
	int		m_nNeedsMon;
	int		m_nNeedsSat;
	int		m_nNeedsSun;
	int		m_nNeedsThu;
	int		m_nNeedsTue;
	int		m_nNeedsWed;
	CString	m_csOnDutyFri;
	CString	m_csOnDutyMon;
	CString	m_csOnDutySat;
	CString	m_csOnDutySun;
	CString	m_csOnDutyThu;
	CString	m_csOnDutyTue;
	CString	m_csOnDutyWed;
	CString	m_csStartFri;
	CString	m_csStartMon;
	CString	m_csStartSat;
	CString	m_csStartSun;
	CString	m_csStartThu;
	CString	m_csStartTue;
	CString	m_csStartWed;
	//}}AFX_DATA

	// ClassWizard generated virtual function overrides
	//{{AFX_VIRTUAL(CStaffDlg)
	protected:
	virtual void DoDataExchange(CDataExchange* pDX);	// DDX/DDV support
	//}}AFX_VIRTUAL

// Implementation
protected:
	HICON m_hIcon;

	// Generated message map functions
	//{{AFX_MSG(CStaffDlg)
	virtual BOOL OnInitDialog();
	afx_msg void OnSysCommand(UINT nID, LPARAM lParam);
	afx_msg void OnPaint();
	afx_msg HCURSOR OnQueryDragIcon();
	afx_msg void OnSolve();
	//}}AFX_MSG
	DECLARE_MESSAGE_MAP()
};

//{{AFX_INSERT_LOCATION}}
// Microsoft Visual C++ will insert additional declarations immediately before the previous line.

#endif // !defined(AFX_STAFFDLG_H__74D746B7_CA4D_11D6_AC89_00010240D2AE__INCLUDED_)
