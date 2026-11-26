object VarEntryDlg: TVarEntryDlg
  Left = 200
  Top = 120
  BorderStyle = bsDialog
  Caption = 'VariableEntry'
  ClientHeight = 127
  ClientWidth = 379
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
    Width = 79
    Height = 15
    Caption = 'Variable &Name:'
    FocusControl = VarName
  end
  object xLabel2: TLabel
    Left = 12
    Top = 44
    Width = 75
    Height = 15
    Caption = '&Variable Value:'
    FocusControl = VarValue
  end
  object VarName: TEdit
    Left = 114
    Top = 12
    Width = 253
    Height = 23
    TabOrder = 0
  end
  object VarValue: TEdit
    Left = 114
    Top = 41
    Width = 253
    Height = 23
    TabOrder = 1
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 76
    Width = 379
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 379
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object bOk: TButton
      Left = 183
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object bCancel: TButton
      Left = 279
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
