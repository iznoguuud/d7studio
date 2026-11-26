object AddCodeTemplateDlg: TAddCodeTemplateDlg
  Left = 200
  Top = 120
  ActiveControl = ShortName
  BorderStyle = bsDialog
  Caption = 'Add Code Template'
  ClientHeight = 128
  ClientWidth = 353
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
  object xLabel1: TLabel
    Left = 12
    Top = 15
    Width = 83
    Height = 15
    Caption = '&Shortcut Name:'
    FocusControl = ShortName
  end
  object xLabel2: TLabel
    Left = 12
    Top = 45
    Width = 63
    Height = 15
    Caption = '&Description:'
    FocusControl = Desc
  end
  object ShortName: TEdit
    Left = 106
    Top = 12
    Width = 235
    Height = 23
    TabOrder = 0
  end
  object Desc: TEdit
    Left = 106
    Top = 42
    Width = 235
    Height = 23
    TabOrder = 1
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 77
    Width = 353
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 353
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKBtn: TButton
      Left = 157
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = OKBtnClick
    end
    object CancelBtn: TButton
      Left = 253
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
