object Form1: TForm1
  Left = 395
  Top = 196
  Width = 390
  Height = 356
  Caption = 'Lingo Delphi Example'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 40
    Top = 48
    Width = 56
    Height = 13
    Caption = 'Maximize:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object Label2: TLabel
    Left = 168
    Top = 48
    Width = 19
    Height = 13
    Caption = 'X  +'
  end
  object Label3: TLabel
    Left = 256
    Top = 48
    Width = 10
    Height = 13
    Caption = 'Y;'
  end
  object Label4: TLabel
    Left = 40
    Top = 88
    Width = 71
    Height = 13
    Caption = 'Subject To: '
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object Label5: TLabel
    Left = 168
    Top = 88
    Width = 25
    Height = 13
    Caption = 'X  <='
  end
  object Label6: TLabel
    Left = 168
    Top = 120
    Width = 25
    Height = 13
    Caption = 'Y  <='
  end
  object Label7: TLabel
    Left = 168
    Top = 152
    Width = 19
    Height = 13
    Caption = 'X  +'
  end
  object Label8: TLabel
    Left = 256
    Top = 152
    Width = 25
    Height = 13
    Caption = 'Y  <='
  end
  object Label9: TLabel
    Left = 40
    Top = 232
    Width = 51
    Height = 13
    Caption = 'Solution:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object Label10: TLabel
    Left = 56
    Top = 256
    Width = 48
    Height = 13
    Caption = 'Objective:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    ParentFont = False
  end
  object Label11: TLabel
    Left = 176
    Top = 256
    Width = 10
    Height = 13
    Caption = 'X:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    ParentFont = False
  end
  object Label12: TLabel
    Left = 256
    Top = 256
    Width = 10
    Height = 13
    Caption = 'Y:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    ParentFont = False
  end
  object Label13: TLabel
    Left = 136
    Top = 296
    Width = 46
    Height = 13
    Caption = 'Iterations:'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    ParentFont = False
  end
  object edtCX: TEdit
    Left = 112
    Top = 48
    Width = 49
    Height = 21
    TabOrder = 0
    Text = '20'
  end
  object edtCY: TEdit
    Left = 200
    Top = 48
    Width = 49
    Height = 21
    TabOrder = 1
    Text = '30'
  end
  object edtB1: TEdit
    Left = 200
    Top = 88
    Width = 49
    Height = 21
    TabOrder = 2
    Text = '50'
  end
  object edtB2: TEdit
    Left = 200
    Top = 120
    Width = 49
    Height = 21
    TabOrder = 3
    Text = '70'
  end
  object edtAX: TEdit
    Left = 112
    Top = 152
    Width = 49
    Height = 21
    TabOrder = 4
    Text = '1'
  end
  object edtAY: TEdit
    Left = 200
    Top = 152
    Width = 49
    Height = 21
    TabOrder = 5
    Text = '2'
  end
  object edtB3: TEdit
    Left = 288
    Top = 152
    Width = 49
    Height = 21
    TabOrder = 6
    Text = '120'
  end
  object Button1: TButton
    Left = 152
    Top = 192
    Width = 129
    Height = 25
    Caption = 'Solve'
    TabOrder = 7
    OnClick = Button1Click
  end
  object edtObj: TEdit
    Left = 112
    Top = 256
    Width = 49
    Height = 21
    TabOrder = 8
  end
  object edtX: TEdit
    Left = 192
    Top = 256
    Width = 49
    Height = 21
    TabOrder = 9
  end
  object edtY: TEdit
    Left = 272
    Top = 256
    Width = 49
    Height = 21
    TabOrder = 10
  end
  object edtIterations: TEdit
    Left = 192
    Top = 296
    Width = 49
    Height = 21
    TabOrder = 11
  end
end
