program WFObserver;

uses
  Forms,
  ufmMain in 'ufmMain.pas' {WhichFontFather};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TWhichFontFather, WhichFontFather);
  Application.Run;
end.
