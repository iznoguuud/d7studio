object ImageTextDlg: TImageTextDlg
  Left = 200
  Top = 120
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Text'
  ClientHeight = 250
  ClientWidth = 380
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15
  object lblText: TLabel
    Left = 12
    Top = 12
    Width = 25
    Height = 15
    Caption = '&Text:'
    FocusControl = mmText
  end
  object mmText: TMemo
    Left = 12
    Top = 30
    Width = 356
    Height = 98
    ScrollBars = ssVertical
    TabOrder = 0
    WantReturns = True
  end
  object lblFontName: TLabel
    Left = 12
    Top = 142
    Width = 250
    Height = 15
    AutoSize = False
    Caption = 'Segoe UI, 9 pt'
    ShowAccelChar = False
  end
  object btnFont: TButton
    Left = 280
    Top = 137
    Width = 88
    Height = 26
    Caption = '&Font...'
    TabOrder = 1
    OnClick = btnFontClick
  end
  object cbSmooth: TCheckBox
    Left = 12
    Top = 168
    Width = 356
    Height = 19
    Caption = '&Smooth edges (an image of 32 bits)'
    TabOrder = 2
  end
  object FontDialog: TFontDialog
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -11
    Font.Name = 'MS Sans Serif'
    Font.Style = []
    Left = 60
    Top = 192
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 199
    Width = 380
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 3
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 380
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 184
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 280
      Top = 13
      Width = 88
      Height = 26
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
end
