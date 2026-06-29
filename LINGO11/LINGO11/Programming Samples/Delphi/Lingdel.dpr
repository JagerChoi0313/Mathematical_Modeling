program Lingdel;

uses
  Forms,
  LingoMain in 'LingoMain.pas' {Form1},
  Lingd11 in '..\Lingd11.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
