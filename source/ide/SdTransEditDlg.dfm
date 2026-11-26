object TransEditDlg: TTransEditDlg
  Left = 200
  Top = 120
  ActiveControl = edTitle
  BorderStyle = bsDialog
  Caption = 'Tool Properties'
  ClientHeight = 378
  ClientWidth = 508
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
    Width = 26
    Height = 15
    Caption = '&Title:'
    FocusControl = edTitle
  end
  object xLabel2: TLabel
    Left = 12
    Top = 46
    Width = 49
    Height = 15
    Caption = '&Program:'
    FocusControl = edProgram
  end
  object xLabel3: TLabel
    Left = 12
    Top = 108
    Width = 62
    Height = 15
    Caption = 'P&arameters:'
    FocusControl = edParameters
  end
  object MacroLabel: TLabel
    Left = 12
    Top = 180
    Width = 42
    Height = 15
    Caption = 'Ma&cros:'
    FocusControl = MacroList
  end
  object xLabel4: TLabel
    Left = 12
    Top = 77
    Width = 65
    Height = 15
    Caption = '&Working dir:'
    FocusControl = edWorkingDir
  end
  object edTitle: TEdit
    Left = 96
    Top = 12
    Width = 400
    Height = 23
    MaxLength = 80
    TabOrder = 0
  end
  object edProgram: TEdit
    Left = 96
    Top = 43
    Width = 400
    Height = 23
    MaxLength = 255
    TabOrder = 1
  end
  object edParameters: TEdit
    Left = 96
    Top = 105
    Width = 400
    Height = 23
    MaxLength = 255
    TabOrder = 2
  end
  object MacroButton: TBitBtn
    Left = 12
    Top = 136
    Width = 88
    Height = 26
    Action = aMacros
    Caption = '&Macros'
    TabOrder = 3
  end
  object MacroList: TListBox
    Left = 12
    Top = 203
    Width = 389
    Height = 112
    Style = lbOwnerDrawFixed
    ItemHeight = 16
    TabOrder = 4
    OnDrawItem = MacroDrawItem
  end
  object edWorkingDir: TEdit
    Left = 96
    Top = 74
    Width = 400
    Height = 23
    TabOrder = 5
  end
  object InsertButton: TButton
    Left = 408
    Top = 204
    Width = 88
    Height = 26
    Action = aInsertMacro
    TabOrder = 6
  end
  object BrowseButton: TButton
    Left = 408
    Top = 136
    Width = 88
    Height = 26
    Action = aBrowse
    TabOrder = 7
  end
  object Actions: TActionList
    Left = 12
    Top = 253
    object aMacros: TAction
      Caption = '&Macros'
      OnExecute = aMacrosExecute
    end
    object aInsertMacro: TAction
      Caption = '&Insert'
      OnExecute = aInsertMacroExecute
      OnUpdate = aInsertMacroUpdate
    end
    object aBrowse: TAction
      Caption = '&Browse...'
      OnExecute = aBrowseExecute
    end
    object aOK: TAction
      Caption = 'OK'
      OnExecute = aOKExecute
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 327
    Width = 508
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 8
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 508
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 312
      Top = 13
      Width = 88
      Height = 26
      Action = aOK
      Default = True
      TabOrder = 0
    end
    object CancelButton: TButton
      Left = 408
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
