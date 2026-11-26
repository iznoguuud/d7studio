object WatchEditDlg: TWatchEditDlg
  Left = 200
  Top = 120
  ActiveControl = edExpression
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Watch Properties'
  ClientHeight = 276
  ClientWidth = 469
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
  object xBevel1: TBevel
    Left = 12
    Top = 132
    Width = 445
    Height = 81
    Shape = bsFrame
  end
  object xLabel1: TLabel
    Left = 12
    Top = 15
    Width = 63
    Height = 15
    AutoSize = False
    Caption = '&Expression:'
    DragCursor = crDefault
    FocusControl = edExpression
  end
  object xLabel2: TLabel
    Left = 12
    Top = 73
    Width = 79
    Height = 15
    AutoSize = False
    Caption = 'Repeat co&unt:'
    DragCursor = crDefault
    FocusControl = edRepeatCount
  end
  object xLabel3: TLabel
    Left = 264
    Top = 73
    Width = 33
    Height = 15
    AutoSize = False
    Caption = 'Di&gits:'
    DragCursor = crDefault
    FocusControl = edDigits
  end
  object xLabel4: TLabel
    Left = 12
    Top = 44
    Width = 69
    Height = 15
    Caption = 'Gr&oup name:'
    FocusControl = edTabName
  end
  object edExpression: TComboBox
    Left = 115
    Top = 12
    Width = 342
    Height = 24
    DragCursor = crDefault
    ItemHeight = 0
    TabOrder = 0
  end
  object rbCharacter: TRadioButton
    Left = 21
    Top = 139
    Width = 140
    Height = 22
    Caption = '&Character'
    DragCursor = crDefault
    TabOrder = 1
  end
  object rbString: TRadioButton
    Left = 21
    Top = 161
    Width = 140
    Height = 22
    Caption = '&String'
    DragCursor = crDefault
    TabOrder = 2
  end
  object rbDecimal: TRadioButton
    Left = 21
    Top = 183
    Width = 140
    Height = 22
    Caption = '&Decimal'
    DragCursor = crDefault
    TabOrder = 3
  end
  object rbMemoryDump: TRadioButton
    Left = 314
    Top = 183
    Width = 141
    Height = 22
    Caption = '&Memory Dump'
    DragCursor = crDefault
    TabOrder = 4
  end
  object rbPointer: TRadioButton
    Left = 168
    Top = 183
    Width = 140
    Height = 22
    Caption = '&Pointer'
    DragCursor = crDefault
    TabOrder = 5
  end
  object rbHex: TRadioButton
    Left = 168
    Top = 139
    Width = 140
    Height = 22
    Caption = 'He&xadecimal'
    DragCursor = crDefault
    TabOrder = 6
  end
  object rbFloatingPoint: TRadioButton
    Left = 168
    Top = 161
    Width = 140
    Height = 22
    Caption = '&Floating point'
    DragCursor = crDefault
    TabOrder = 7
  end
  object rbRecordStructureUnion: TRadioButton
    Left = 314
    Top = 139
    Width = 141
    Height = 22
    Caption = '&Record/Structure'
    DragCursor = crDefault
    TabOrder = 8
  end
  object rbDefault: TRadioButton
    Left = 314
    Top = 161
    Width = 141
    Height = 22
    Caption = 'Defau&lt'
    DragCursor = crDefault
    TabOrder = 9
  end
  object edRepeatCount: TEdit
    Left = 115
    Top = 70
    Width = 135
    Height = 23
    DragCursor = crDefault
    TabOrder = 10
  end
  object edDigits: TEdit
    Left = 319
    Top = 70
    Width = 138
    Height = 23
    DragCursor = crDefault
    TabOrder = 11
  end
  object cbEnabled: TCheckBox
    Left = 12
    Top = 103
    Width = 86
    Height = 22
    Caption = 'E&nabled'
    DragCursor = crDefault
    TabOrder = 12
  end
  object cbAllowSideEffects: TCheckBox
    Left = 115
    Top = 103
    Width = 142
    Height = 19
    Caption = '&Allow Function Calls'
    TabOrder = 13
  end
  object edTabName: TComboBox
    Left = 115
    Top = 41
    Width = 342
    Height = 24
    DragCursor = crDefault
    ItemHeight = 0
    TabOrder = 14
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 225
    Width = 469
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 15
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 469
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 273
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = OKButtonClick
    end
    object CancelButton: TButton
      Left = 369
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
