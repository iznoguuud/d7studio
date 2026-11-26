object SizeDlg: TSizeDlg
  Left = 200
  Top = 120
  ActiveControl = hNoChange
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Size'
  ClientHeight = 193
  ClientWidth = 386
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
  object xGroupBox1: TGroupBox
    Left = 12
    Top = 12
    Width = 175
    Height = 118
    Caption = 'Width:'
    TabOrder = 0
    object hNoChange: TRadioButton
      Left = 9
      Top = 18
      Width = 105
      Height = 22
      Caption = '&No change'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object hShrink: TRadioButton
      Left = 9
      Top = 40
      Width = 152
      Height = 22
      Caption = '&Shrink to smallest'
      TabOrder = 1
    end
    object hGrow: TRadioButton
      Left = 9
      Top = 62
      Width = 152
      Height = 22
      Caption = '&Grow to largest'
      TabOrder = 2
    end
    object hAbsolute: TRadioButton
      Left = 9
      Top = 84
      Width = 72
      Height = 22
      Caption = '&Width:'
      TabOrder = 3
    end
    object hWidth: TEdit
      Left = 84
      Top = 85
      Width = 82
      Height = 23
      Enabled = False
      TabOrder = 4
      OnChange = ValueChange
    end
  end
  object xGroupBox2: TGroupBox
    Left = 199
    Top = 12
    Width = 175
    Height = 118
    Caption = 'Height:'
    TabOrder = 1
    object vNoChange: TRadioButton
      Left = 9
      Top = 18
      Width = 105
      Height = 22
      Caption = 'No &change'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object vShrink: TRadioButton
      Left = 9
      Top = 40
      Width = 152
      Height = 22
      Caption = 'Shrin&k to smallest'
      TabOrder = 1
    end
    object vGrow: TRadioButton
      Left = 9
      Top = 62
      Width = 138
      Height = 22
      Caption = 'Grow to &largest'
      TabOrder = 2
    end
    object vAbsolute: TRadioButton
      Left = 9
      Top = 84
      Width = 72
      Height = 22
      Caption = 'Heigh&t:'
      TabOrder = 3
    end
    object vHeight: TEdit
      Left = 84
      Top = 85
      Width = 82
      Height = 23
      Enabled = False
      TabOrder = 4
      OnChange = ValueChange
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 142
    Width = 386
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 386
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 190
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = OKButtonClick
    end
    object CancelButton: TButton
      Left = 286
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
