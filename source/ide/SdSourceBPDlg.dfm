object SourceBPDlg: TSourceBPDlg
  Left = 200
  Top = 120
  ActiveControl = edFileName
  BorderStyle = bsDialog
  Caption = 'Add Source Breakpoint'
  ClientHeight = 472
  ClientWidth = 370
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
  DesignSize = (
    370
    472)
  object xLabel1: TLabel
    Left = 12
    Top = 15
    Width = 88
    Height = 23
    AutoSize = False
    Caption = '&Filename:'
    DragCursor = crDefault
    FocusControl = edFileName
    WordWrap = True
  end
  object lbLineNumber: TLabel
    Left = 12
    Top = 41
    Width = 88
    Height = 23
    AutoSize = False
    Caption = '&Line number:'
    DragCursor = crDefault
    FocusControl = edLineNo
    WordWrap = True
  end
  object xLabel3: TLabel
    Left = 12
    Top = 67
    Width = 88
    Height = 23
    AutoSize = False
    Caption = '&Condition:'
    DragCursor = crDefault
    FocusControl = edCondition
    WordWrap = True
  end
  object lbPassCount: TLabel
    Left = 12
    Top = 93
    Width = 88
    Height = 23
    AutoSize = False
    Caption = '&Pass count:'
    DragCursor = crDefault
    FocusControl = edPassCount
    WordWrap = True
  end
  object xLabel5: TLabel
    Left = 12
    Top = 119
    Width = 36
    Height = 15
    Caption = '&Group:'
    FocusControl = edGroupname
  end
  object edFileName: TComboBox
    Left = 106
    Top = 12
    Width = 252
    Height = 24
    DragCursor = crDefault
    ItemHeight = 0
    TabOrder = 0
  end
  object edLineNo: TComboBox
    Left = 106
    Top = 38
    Width = 252
    Height = 24
    DragCursor = crDefault
    ItemHeight = 0
    TabOrder = 1
  end
  object edCondition: TComboBox
    Left = 106
    Top = 64
    Width = 252
    Height = 24
    DragCursor = crDefault
    ItemHeight = 0
    TabOrder = 2
  end
  object edPassCount: TComboBox
    Left = 106
    Top = 90
    Width = 252
    Height = 24
    DragCursor = crDefault
    ItemHeight = 0
    TabOrder = 3
  end
  object gbActions: TGroupBox
    Left = 12
    Top = 185
    Width = 345
    Height = 224
    Caption = ' Actions: '
    TabOrder = 4
    Visible = False
    object lbLogMessage: TLabel
      Left = 9
      Top = 87
      Width = 72
      Height = 15
      Caption = 'Log &message:'
      FocusControl = edLogMessage
    end
    object lbEnableGroup: TLabel
      Left = 9
      Top = 167
      Width = 73
      Height = 15
      Caption = 'E&nable group:'
      FocusControl = edEnableGroup
    end
    object lbDisableGroup: TLabel
      Left = 9
      Top = 193
      Width = 76
      Height = 15
      Caption = '&Disable group:'
      FocusControl = edDisableGroup
    end
    object lbEvalExpression: TLabel
      Left = 9
      Top = 113
      Width = 82
      Height = 15
      Caption = 'E&val expression:'
      FocusControl = edEvalExpression
    end
    object cbBreak: TCheckBox
      Left = 9
      Top = 18
      Width = 114
      Height = 19
      Caption = '&Break'
      TabOrder = 0
    end
    object edLogMessage: TComboBox
      Left = 105
      Top = 84
      Width = 231
      Height = 24
      ItemHeight = 0
      TabOrder = 1
    end
    object edEnableGroup: TComboBox
      Left = 105
      Top = 164
      Width = 231
      Height = 24
      ItemHeight = 0
      TabOrder = 2
    end
    object edDisableGroup: TComboBox
      Left = 105
      Top = 190
      Width = 231
      Height = 24
      ItemHeight = 0
      TabOrder = 3
    end
    object edEvalExpression: TComboBox
      Left = 105
      Top = 110
      Width = 231
      Height = 24
      ItemHeight = 0
      TabOrder = 4
    end
    object cbLogResult: TCheckBox
      Left = 105
      Top = 139
      Width = 114
      Height = 19
      Caption = 'Log &result'
      TabOrder = 5
    end
    object cbIgnoreExceptions: TCheckBox
      Left = 9
      Top = 40
      Width = 253
      Height = 19
      Caption = '&Ignore subsequent exceptions'
      TabOrder = 6
    end
    object cbHandleExceptions: TCheckBox
      Left = 9
      Top = 62
      Width = 207
      Height = 19
      Caption = 'Handle subsequent e&xceptions'
      TabOrder = 7
    end
  end
  object edGroupname: TComboBox
    Left = 106
    Top = 116
    Width = 252
    Height = 24
    ItemHeight = 0
    TabOrder = 5
  end
  object AdvancedButton: TButton
    Left = 269
    Top = 150
    Width = 88
    Height = 26
    Caption = '&Advanced >>'
    TabOrder = 6
    OnClick = AdvancedButtonClick
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 421
    Width = 370
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 7
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 370
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 174
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = OKButtonClick
    end
    object CancelButton: TButton
      Left = 270
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
