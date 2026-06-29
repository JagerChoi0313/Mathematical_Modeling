unit LingoMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TForm1 = class(TForm)
    Label1: TLabel;
    edtCX: TEdit;
    Label2: TLabel;
    edtCY: TEdit;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    edtB1: TEdit;
    Label6: TLabel;
    edtB2: TEdit;
    Label7: TLabel;
    Label8: TLabel;
    edtAX: TEdit;
    edtAY: TEdit;
    edtB3: TEdit;
    Button1: TButton;
    Label9: TLabel;
    Label10: TLabel;
    edtObj: TEdit;
    Label11: TLabel;
    edtX: TEdit;
    Label12: TLabel;
    edtY: TEdit;
    Label13: TLabel;
    edtIterations: TEdit;

procedure Button1Click(Sender: TObject);

  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses lingd11;

{$R *.dfm}
//////////////////////////////////////////////////////////////////////////////
//  A simple callback implementation
function  MyCallback ( pLingo: Integer; nReserved: Integer;
 nUserData : Integer): Integer; stdcall;

var
   nIterations : integer;
   pedt : ^TEdit;

begin

   // get the current interation count
   LSgetCallbackInfoLng( pLingo, LS_IINFO_ITERATIONS_LNG, nIterations);

   // display interation count
   pedt := pointer( nUserData);
   pedt.Text := intToStr( nIterations);

   // return a nonzero value to halt optimization
   MyCallback := 0;

end;

//////////////////////////////////////////////////////////////////////////////
procedure TForm1.Button1Click(Sender: TObject);

label FinalExit, NormalExit, ErrorExit;

var
   nErr, pLingo, nPointersNow: integer;
   dCX, dCY, dB1, dB2, dB3, dAX, dAY: double;
   dX, dY, dObj, dStatus: double;
   cMsg: string;
   cScript: pchar;
   cbf: cbfunc_t;

 begin

   // load data from dialog box
   dCX := strToFloat( edtCX.Text);
   dCY := strToFloat( edtCY.Text);

   dB1 := strToFloat( edtB1.Text);
   dB2 := strToFloat( edtB2.Text);
   dB3 := strToFloat( edtB3.Text);

   dAX := strToFloat( edtAX.Text);
   dAY := strToFloat( edtAY.Text);

   // create the LINGO environment object
   pLingo := LScreateEnvLng();
   if ( pLingo = 0) then
   begin
      ShowMessage( 'Can''t create LINGO environment');
      goto FinalExit;
   end;

   // Open LINGO's log file
   nErr := LSopenLogFileLng( pLINGO, 'LINGO.log');
   if ( nErr <> 0) then goto ErrorExit;

   // set the callback function
   cbf := MyCallback;
   nErr := LSsetCallbackSolverLng( pLINGO, @cbf, integer( @edtIterations));
   if ( nErr <> 0) then goto ErrorExit;

   // Pass memory transfer pointers to LINGO
   nErr := LSsetPointerLng( pLINGO, dCX, nPointersNow);
   if ( nErr <> 0) then goto ErrorExit;
   nErr := LSsetPointerLng( pLINGO, dCY, nPointersNow);
   if ( nErr <> 0) then goto ErrorExit;
   nErr := LSsetPointerLng( pLINGO, dB1, nPointersNow);
   if ( nErr <> 0) then goto ErrorExit;
   nErr := LSsetPointerLng( pLINGO, dB2, nPointersNow);
   if ( nErr <> 0) then goto ErrorExit;
   nErr := LSsetPointerLng( pLINGO, dB3, nPointersNow);
   if ( nErr <> 0) then goto ErrorExit;
   nErr := LSsetPointerLng( pLINGO, dAX, nPointersNow);
   if ( nErr <> 0) then goto ErrorExit;
   nErr := LSsetPointerLng( pLINGO, dAY, nPointersNow);
   if ( nErr <> 0) then goto ErrorExit;
   nErr := LSsetPointerLng( pLINGO, dX, nPointersNow);
   if ( nErr <> 0) then goto ErrorExit;
   nErr := LSsetPointerLng( pLINGO, dY, nPointersNow);
   if ( nErr <> 0) then goto ErrorExit;
   nErr := LSsetPointerLng( pLINGO, dObj, nPointersNow);
   if ( nErr <> 0) then goto ErrorExit;
   nErr := LSsetPointerLng( pLINGO, dStatus, nPointersNow);
   if ( nErr <> 0) then goto ErrorExit;

   // Here is the script we want LINGO to run
   cScript := 'SET ECHOIN 1' + Char( 10) +
    'TAKE XY.LNG' + Char(10) +
    'GO' + Char( 10) +
    'QUIT' + Char( 10) +
    Char( 0);

   // Run the script
   nErr := LSexecuteScriptLng( pLINGO, cScript);
   if ( nErr <> 0) then goto ErrorExit;

   // Close the log file
   LScloseLogFileLng( pLINGO);

   // Any problems?
   if ( ( nErr <> 0) or
    ( dStatus <> LS_STATUS_GLOBAL_LNG)) then

      ShowMessage( 'Unable to solve to optimality.')

   else

      begin
         // Everything went OK ... display results
         edtObj.Text := floatToStr( dObj);
         edtX.Text := floatToStr( dX);
         edtY.Text := floatToStr( dY);
      end;

   goto NormalExit;

ErrorExit:
   cMsg := Format('LINGO Errorcode: %d', [nErr]);
   ShowMessage( cMsg);
   goto FinalExit;

NormalExit:

   // delete Lingo's environment to avoid memory leaks
   LSdeleteEnvLng( pLINGO);

FinalExit:

end;

end.
