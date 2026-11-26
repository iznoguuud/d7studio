object ReplaceDlg: TReplaceDlg
  Left = 200
  Top = 120
  ActiveControl = cbFind
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Replace Text'
  ClientHeight = 319
  ClientWidth = 413
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Position = poOwnerFormCenter
  PixelsPerInch = 96
  TextHeight = 15
  OnCreate = FormCreate
  object lblFind: TLabel
    Left = 12
    Top = 15
    Width = 62
    Height = 15
    Caption = '&Text to find:'
    FocusControl = cbFind
  end
  object lblReplace: TLabel
    Left = 12
    Top = 46
    Width = 70
    Height = 15
    Caption = '&Replace with:'
    FocusControl = cbReplace
  end
  object cbFind: TComboBox
    Left = 103
    Top = 12
    Width = 298
    Height = 23
    ItemHeight = 15
    TabOrder = 0
  end
  object cbReplace: TComboBox
    Left = 103
    Top = 43
    Width = 298
    Height = 23
    ItemHeight = 15
    TabOrder = 1
  end
  object gbOptions: TGroupBox
    Left = 12
    Top = 74
    Width = 191
    Height = 108
    Caption = 'Options'
    TabOrder = 2
    object chkCase: TCheckBox
      Left = 9
      Top = 18
      Width = 173
      Height = 19
      Caption = '&Case sensitive'
      TabOrder = 0
    end
    object chkWholeWord: TCheckBox
      Left = 9
      Top = 39
      Width = 173
      Height = 19
      Caption = '&Whole words only'
      TabOrder = 1
    end
    object chkRegExp: TCheckBox
      Left = 9
      Top = 60
      Width = 173
      Height = 19
      Caption = 'Regular e&xpressions'
      TabOrder = 2
    end
    object chkPrompt: TCheckBox
      Left = 9
      Top = 81
      Width = 173
      Height = 19
      Caption = '&Prompt on replace'
      TabOrder = 3
    end
  end
  object gbDirection: TGroupBox
    Left = 210
    Top = 74
    Width = 191
    Height = 108
    Caption = 'Direction'
    TabOrder = 3
    object rbForward: TRadioButton
      Left = 9
      Top = 18
      Width = 173
      Height = 19
      Caption = 'Forwar&d'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object rbBackward: TRadioButton
      Left = 9
      Top = 39
      Width = 173
      Height = 19
      Caption = '&Backward'
      TabOrder = 1
    end
  end
  object gbScope: TGroupBox
    Left = 12
    Top = 190
    Width = 191
    Height = 66
    Caption = 'Scope'
    TabOrder = 4
    object rbGlobal: TRadioButton
      Left = 9
      Top = 18
      Width = 173
      Height = 19
      Caption = '&Global'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object rbSelected: TRadioButton
      Left = 9
      Top = 39
      Width = 173
      Height = 19
      Caption = '&Selected text'
      TabOrder = 1
    end
  end
  object gbOrigin: TGroupBox
    Left = 210
    Top = 190
    Width = 191
    Height = 66
    Caption = 'Origin'
    TabOrder = 5
    object rbFromCursor: TRadioButton
      Left = 9
      Top = 18
      Width = 173
      Height = 19
      Caption = '&From cursor'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object rbEntireScope: TRadioButton
      Left = 9
      Top = 39
      Width = 173
      Height = 19
      Caption = '&Entire scope'
      TabOrder = 1
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 268
    Width = 413
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 6
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 413
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnReplaceAll: TButton
      Left = 121
      Top = 13
      Width = 88
      Height = 26
      Caption = 'Replace &All'
      ModalResult = 8
      TabOrder = 0
    end
    object btnOK: TButton
      Left = 217
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 1
    end
    object btnCancel: TButton
      Left = 313
      Top = 13
      Width = 88
      Height = 26
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 2
    end
  end
end
