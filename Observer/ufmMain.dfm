object WhichFontFather: TWhichFontFather
  Left = 0
  Top = 0
  Caption = 'Which Font is it using'
  ClientHeight = 475
  ClientWidth = 328
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  DesignSize = (
    328
    475)
  PixelsPerInch = 96
  TextHeight = 13
  object lstFonts: TListBox
    Left = 8
    Top = 8
    Width = 312
    Height = 459
    Anchors = [akLeft, akTop, akRight, akBottom]
    ItemHeight = 13
    TabOrder = 0
    ExplicitWidth = 273
    ExplicitHeight = 334
  end
  object btn1: TButton
    Left = 72
    Top = 188
    Width = 184
    Height = 88
    Anchors = []
    Caption = 'START'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -40
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
    TabOrder = 1
    ExplicitLeft = 5
    ExplicitTop = 3
  end
end
