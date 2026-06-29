<%@ Page Language="VB" AutoEventWireup="false" CodeFile="Default.aspx.vb" Inherits="_Default" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" >
<head runat="server">
    <title>LINGO Staffing Example with ASP.NET</title>
</head>
<body style="background-color: #ccffff;">
    <form id="form1" runat="server">
    <div>
       &nbsp;&nbsp;
       <asp:Label ID="lblError" runat="server" Font-Bold="True" ForeColor="Red" Style="z-index: 100;
          left: 43px; position: absolute; top: 7px" Width="305px"></asp:Label>
       <br />
       <br />
       <br />
       <asp:Label ID="Label1" runat="server" Font-Bold="True" Font-Names="Arial" Height="1px"
          Style="z-index: 101; left: 42px; position: absolute; top: 33px" Text="Day" Width="35px"></asp:Label>
       <asp:Label ID="Label2" runat="server" Font-Bold="True" Font-Names="Arial" Height="1px"
          Style="z-index: 102; left: 118px; position: absolute; top: 33px" Text="Needs"
          Width="35px"></asp:Label>
       <asp:Label ID="Label3" runat="server" Font-Bold="True" Font-Names="Arial" Height="1px"
          Style="z-index: 103; left: 208px; position: absolute; top: 33px" Text="Start"
          Width="35px"></asp:Label>
       <asp:Label ID="Label4" runat="server" Font-Bold="True" Font-Names="Arial" Height="1px"
          Style="z-index: 104; left: 285px; position: absolute; top: 33px" Text="On Duty"
          Width="63px"></asp:Label>
       <asp:Label ID="Label5" runat="server" Font-Names="Arial" Style="z-index: 105; left: 42px;
          position: absolute; top: 76px" Text="Mon"></asp:Label>
       <asp:Label ID="Label6" runat="server" Font-Names="Arial" Style="z-index: 106; left: 42px;
          position: absolute; top: 119px" Text="Tue"></asp:Label>
       <asp:Label ID="Label7" runat="server" Font-Names="Arial" Height="6px" Style="z-index: 107;
          left: 42px; position: absolute; top: 162px" Text="Wed"></asp:Label>
       <asp:Label ID="Label8" runat="server" Font-Names="Arial" Style="z-index: 108; left: 42px;
          position: absolute; top: 205px" Text="Thu"></asp:Label>
       <asp:Label ID="Label9" runat="server" Font-Names="Arial" Style="z-index: 109; left: 42px;
          position: absolute; top: 248px" Text="Fri"></asp:Label>
       <asp:Label ID="Label10" runat="server" Font-Names="Arial" Style="z-index: 110; left: 42px;
          position: absolute; top: 291px" Text="Sat"></asp:Label>
       <asp:Label ID="Label11" runat="server" Font-Names="Arial" Style="z-index: 111; left: 42px;
          position: absolute; top: 334px" Text="Sun"></asp:Label>
       <asp:Label ID="Label13" runat="server" Font-Names="Arial" Style="z-index: 112; left: 125px;
          position: absolute; top: 374px" Text="Total..." Width="70px"></asp:Label>
       <asp:TextBox ID="txtNeedsMon" runat="server" Height="16px" Style="z-index: 113; left: 119px;
          position: absolute; top: 75px" Width="39px" AutoCompleteType="Disabled" BorderStyle="Inset" BorderWidth="2px" Font-Names="Courier New" Font-Size="Small">51</asp:TextBox>
       <asp:TextBox ID="txtNeedsTue" runat="server" Height="16px" Style="z-index: 114; left: 119px;
          position: absolute; top: 118px" Width="39px" AutoCompleteType="Disabled" BorderStyle="Inset" BorderWidth="2px" Font-Names="Courier New" Font-Size="Small">58</asp:TextBox>
       <asp:TextBox ID="txtNeedsWed" runat="server" Height="16px" Style="z-index: 115; left: 119px;
          position: absolute; top: 161px" Width="39px" AutoCompleteType="Disabled" BorderStyle="Inset" BorderWidth="2px" Font-Names="Courier New" Font-Size="Small">64</asp:TextBox>
       <asp:TextBox ID="txtNeedsThu" runat="server" Height="16px" Style="z-index: 116; left: 119px;
          position: absolute; top: 204px" Width="39px" AutoCompleteType="Disabled" BorderStyle="Inset" BorderWidth="2px" Font-Names="Courier New" Font-Size="Small">63</asp:TextBox>
       <asp:TextBox ID="txtNeedsFri" runat="server" Height="16px" Style="z-index: 117; left: 119px;
          position: absolute; top: 247px" Width="39px" AutoCompleteType="Disabled" BorderStyle="Inset" BorderWidth="2px" Font-Names="Courier New" Font-Size="Small">60</asp:TextBox>
       <asp:TextBox ID="txtNeedsSat" runat="server" Height="16px" Style="z-index: 118; left: 119px;
          position: absolute; top: 290px" Width="39px" AutoCompleteType="Disabled" BorderStyle="Inset" BorderWidth="2px" Font-Names="Courier New" Font-Size="Small">44</asp:TextBox>
       <asp:TextBox ID="txtNeedsSun" runat="server" Height="16px" Style="z-index: 119; left: 119px;
          position: absolute; top: 333px" Width="39px" AutoCompleteType="Disabled" BorderStyle="Inset" BorderWidth="2px" Font-Names="Courier New" Font-Size="Small">40</asp:TextBox>
       <asp:Label ID="lblStartMon" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Height="16px" Style="z-index: 120; left: 207px; position: absolute;
          top: 75px" Text=" " Width="39px" Font-Names="Courier New" Font-Size="Small"></asp:Label>
       <asp:Label ID="lblStartTue" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Height="16px" Style="z-index: 121; left: 207px; position: absolute;
          top: 118px" Text=" " Width="39px" Font-Names="Courier New" Font-Size="Small"></asp:Label>
       <asp:Label ID="lblStartWed" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Height="16px" Style="z-index: 122; left: 207px; position: absolute;
          top: 161px" Text=" " Width="39px" Font-Names="Courier New" Font-Size="Small"></asp:Label>
       <asp:Label ID="lblStartThu" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Height="16px" Style="z-index: 123; left: 207px; position: absolute;
          top: 204px" Text=" " Width="39px" Font-Names="Courier New" Font-Size="Small"></asp:Label>
       <asp:Label ID="lblStartFri" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Height="16px" Style="z-index: 124; left: 207px; position: absolute;
          top: 247px" Text=" " Width="39px" Font-Names="Courier New" Font-Size="Small"></asp:Label>
       <asp:Label ID="lblStartSat" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Height="16px" Style="z-index: 125; left: 207px; position: absolute;
          top: 290px" Text=" " Width="39px" Font-Names="Courier New" Font-Size="Small"></asp:Label>
       <asp:Label ID="lblStartSun" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Height="16px" Style="z-index: 126; left: 207px; position: absolute;
          top: 333px" Text=" " Width="39px" Font-Names="Courier New" Font-Size="Small"></asp:Label>
       <asp:Label ID="lblOnDutyMon" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Font-Names="Courier New" Font-Size="Small" Height="16px" Style="z-index: 127;
          left: 294px; position: absolute; top: 75px" Text=" " Width="39px"></asp:Label>
       <asp:Label ID="lblOnDutyTue" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Font-Names="Courier New" Font-Size="Small" Height="16px" Style="z-index: 128;
          left: 294px; position: absolute; top: 118px" Text=" " Width="39px"></asp:Label>
       <asp:Label ID="lblOnDutyWed" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Font-Names="Courier New" Font-Size="Small" Height="16px" Style="z-index: 129;
          left: 294px; position: absolute; top: 161px" Text=" " Width="39px"></asp:Label>
       <asp:Label ID="lblOnDutyThu" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Font-Names="Courier New" Font-Size="Small" Height="16px" Style="z-index: 130;
          left: 294px; position: absolute; top: 204px" Text=" " Width="39px"></asp:Label>
       <asp:Label ID="lblOnDutyFri" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Font-Names="Courier New" Font-Size="Small" Height="16px" Style="z-index: 131;
          left: 294px; position: absolute; top: 247px" Text=" " Width="39px"></asp:Label>
       <asp:Label ID="lblOnDutySat" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Font-Names="Courier New" Font-Size="Small" Height="16px" Style="z-index: 132;
          left: 294px; position: absolute; top: 290px" Text=" " Width="39px"></asp:Label>
       <asp:Label ID="lblOnDutySun" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Font-Names="Courier New" Font-Size="Small" Height="16px" Style="z-index: 133;
          left: 294px; position: absolute; top: 333px" Text=" " Width="39px"></asp:Label>
       &nbsp;<br />
       &nbsp;
       <asp:Button ID="btnSolve" runat="server" Style="z-index: 134; left: 49px; position:absolute;
          top: 420px" Text="Solve" Width="296px" />
       <asp:Label ID="lblTotal" runat="server" BorderColor="Silver" BorderStyle="Inset"
          BorderWidth="2px" Font-Names="Courier New" Font-Size="Small" Height="16px" Style="z-index: 135;
          left: 207px; position: absolute; top: 373px" Text=" " Width="39px"></asp:Label>
       <asp:Label ID="lblCallbacks" runat="server" Font-Names="Arial" Style="z-index: 136;
          left: 42px; position: absolute; top: 465px" Text=" " Width="290px"></asp:Label>
    </div>
    </form>
</body>
</html>
