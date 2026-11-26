object NewThreadDlg: TNewThreadDlg
  Left = 200
  Top = 120
  BorderStyle = bsDialog
  Caption = 'New Thread Object'
  ClientHeight = 176
  ClientWidth = 334
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
  object xBevel1: TGroupBox
    Left = 12
    Top = 12
    Width = 310
    Height = 42
    TabOrder = 0
    object xLabel1: TLabel
      Left = 9
      Top = 12
      Width = 65
      Height = 15
      Caption = '&Class Name:'
      FocusControl = NewClassName
    end
    object NewClassName: TEdit
      Left = 89
      Top = 9
      Width = 212
      Height = 23
      TabOrder = 0
    end
  end
  object xBevel2: TGroupBox
    Left = 12
    Top = 67
    Width = 310
    Height = 46
    TabOrder = 2
    object leThreadName: TLabeledEdit
      Left = 90
      Top = 13
      Width = 211
      Height = 23
      EditLabel.Width = 78
      EditLabel.Height = 15
      EditLabel.Caption = '&Thread Name: '
      LabelPosition = lpLeft
      TabOrder = 0
    end
  end
  object cbNamedThread: TCheckBox
    Left = 21
    Top = 58
    Width = 100
    Height = 19
    Caption = '&Named Thread'
    TabOrder = 1
    OnClick = NamedClick
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 125
    Width = 334
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 3
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 334
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 138
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = OKButtonClick
    end
    object CancelButton: TButton
      Left = 234
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
