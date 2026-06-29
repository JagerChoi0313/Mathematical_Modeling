<%@ Page Language="VB" AutoEventWireup="false" CodeFile="Default.aspx.vb" Inherits="_Default" %>

<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" >
<head runat="server">
    <title>Untitled Page</title>
</head>
<body>
    <form id="form1" runat="server">
       &nbsp; &nbsp;&nbsp;
       <asp:Label ID="Label1" runat="server" Height="21px" Style="left: 215px; position: absolute;
          top: 67px" Text="Threads to run:" Width="95px"></asp:Label>
       <asp:Button ID="Button1" runat="server" Height="22px" Text="Run" Width="137px" style="left: 196px; position: absolute; top: 159px" />&nbsp; &nbsp;&nbsp;
       <asp:TextBox ID="TextBox1" runat="server" Height="17px" Width="83px" style="left: 218px; position: absolute; top: 95px">20</asp:TextBox>
       <br />
    </form>
</body>
</html>
