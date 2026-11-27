object MacroPlayDlg: TMacroPlayDlg
  Left = 200
  Top = 120
  ActiveControl = edTimes
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Play Macro Repeatedly'
  ClientHeight = 127
  ClientWidth = 258
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
  object lblTimes: TLabel
    Left = 12
    Top = 15
    Width = 97
    Height = 15
    Caption = '&Number of times:'
    FocusControl = edTimes
  end
  object edTimes: TEdit
    Left = 145
    Top = 12
    Width = 83
    Height = 23
    TabOrder = 0
    Text = '1'
  end
  object udTimes: TUpDown
    Left = 228
    Top = 12
    Width = 18
    Height = 23
    Associate = edTimes
    Min = 1
    Max = 9999
    Position = 1
    TabOrder = 1
    Thousands = False
  end
  object cbToEnd: TCheckBox
    Left = 12
    Top = 47
    Width = 234
    Height = 17
    Caption = 'Play &until the end of the file'
    TabOrder = 2
    OnClick = cbToEndClick
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 76
    Width = 258
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 3
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 258
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 62
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 158
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
