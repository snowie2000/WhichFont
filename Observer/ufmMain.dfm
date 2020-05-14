object WhichFontFather: TWhichFontFather
  Left = 0
  Top = 0
  Caption = 'Which fonts is it using'
  ClientHeight = 475
  ClientWidth = 328
  Color = clBtnFace
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  DesignSize = (
    328
    475)
  PixelsPerInch = 96
  TextHeight = 13
  object lvFonts: TListView
    Left = 0
    Top = 0
    Width = 328
    Height = 441
    Align = alClient
    Columns = <
      item
        AutoSize = True
        Caption = 'FontName'
      end>
    ReadOnly = True
    RowSelect = True
    ShowColumnHeaders = False
    TabOrder = 0
    ViewStyle = vsReport
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
    Font.Name = 'Stencil'
    Font.Style = []
    ParentFont = False
    TabOrder = 1
    OnClick = btn1Click
  end
  object pnl1: TPanel
    Left = 0
    Top = 441
    Width = 328
    Height = 34
    Align = alBottom
    BevelOuter = bvNone
    Caption = 'pnl1'
    TabOrder = 2
    Visible = False
    DesignSize = (
      328
      34)
    object btn2: TButton
      Left = 72
      Top = 2
      Width = 184
      Height = 30
      Anchors = []
      Caption = 'START OVER'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -20
      Font.Name = 'Stencil'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
      OnClick = btn1Click
    end
  end
end
