object GitBranchDialog: TGitBranchDialog
  Left = 400
  Top = 260
  BorderStyle = bsDialog
  Caption = 'New Branch'
  ClientHeight = 159
  ClientWidth = 400
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 15
  object NameLabel: TLabel
    Left = 12
    Top = 15
    Width = 36
    Height = 15
    Caption = '&Name:'
    FocusControl = NameEdit
  end
  object StartLabel: TLabel
    Left = 12
    Top = 46
    Width = 54
    Height = 15
    Caption = '&Based on:'
    FocusControl = StartCombo
  end
  object NameEdit: TEdit
    Left = 108
    Top = 12
    Width = 280
    Height = 23
    TabOrder = 0
  end
  object StartCombo: TComboBox
    Left = 108
    Top = 43
    Width = 280
    Height = 23
    Style = csDropDownList
    ItemHeight = 15
    TabOrder = 1
  end
  object SwitchBox: TCheckBox
    Left = 108
    Top = 77
    Width = 280
    Height = 19
    Caption = '&Switch to the new branch'
    Checked = True
    State = cbChecked
    TabOrder = 2
  end
  object Footer: TPanel
    Left = 0
    Top = 114
    Width = 400
    Height = 51
    Align = alBottom
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 3
    object FooterLine: TShape
      Left = 0
      Top = 0
      Width = 400
      Height = 1
      Align = alTop
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 204
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = OKButtonClick
    end
    object CancelButton: TButton
      Left = 300
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
