object SplashForm: TSplashForm
  Left = 300
  Top = 200
  BorderStyle = bsNone
  Caption = 'D7 Studio'
  ClientHeight = 300
  ClientWidth = 480
  Color = clWhite
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 15
  OnCreate = FormCreate
  object imgSplash: TImage
    Left = 0
    Top = 0
    Width = 480
    Height = 300
  end
  object lblLine: TLabel
    Left = 202
    Top = 147
    Width = 140
    Height = 21
    Caption = 'for Delphi 7'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 6381921
    Font.Height = -16
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    Transparent = True
  end
  object lblStatus: TLabel
    Left = 24
    Top = 271
    Width = 3
    Height = 15
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 7237230
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    Transparent = True
  end
end
