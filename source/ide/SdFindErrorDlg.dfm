object FindErrorDlg: TFindErrorDlg
  Left = 200
  Top = 120
  ActiveControl = ErrorAddress
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Find Error'
  ClientHeight = 98
  ClientWidth = 292
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
    Width = 114
    Height = 19
    AutoSize = False
    Caption = '&Error Address:'
    FocusControl = ErrorAddress
  end
  object ErrorAddress: TComboBox
    Left = 124
    Top = 12
    Width = 156
    Height = 23
    ItemHeight = 0
    TabOrder = 0
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 47
    Width = 292
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 1
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 292
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 96
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object CancelButton: TButton
      Left = 192
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
