unit ufmMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TWhichFontFather = class(TForm)
    btn1: TButton;
    lstFonts: TListBox;
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  WhichFontFather: TWhichFontFather;

implementation

{$R *.dfm}

end.
