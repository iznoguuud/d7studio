object AddModuleDlg: TAddModuleDlg
  Left = 200
  Top = 120
  ActiveControl = ModuleNameCombo
  BorderStyle = bsDialog
  Caption = 'Add Module'
  ClientHeight = 119
  ClientWidth = 408
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
  object InputLabel: TLabel
    Left = 12
    Top = 12
    Width = 79
    Height = 15
    Caption = '&Module Name:'
    FocusControl = ModuleNameCombo
  end
  object ModuleNameCombo: TComboBox
    Left = 12
    Top = 30
    Width = 288
    Height = 23
    ItemHeight = 0
    TabOrder = 0
  end
  object BrowseButton: TButton
    Left = 308
    Top = 30
    Width = 88
    Height = 26
    Caption = '&Browse...'
    TabOrder = 1
    OnClick = BrowseButtonClick
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 68
    Width = 408
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 408
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 212
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object CancelButton: TButton
      Left = 308
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
