object DesktopsDlg: TDesktopsDlg
  Left = 200
  Top = 120
  BorderStyle = bsDialog
  Caption = 'Desktops'
  ClientHeight = 361
  ClientWidth = 360
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
    Top = 12
    Width = 86
    Height = 15
    Caption = 'Saved &desktops:'
    FocusControl = DesktopList
  end
  object xLabel2: TLabel
    Left = 12
    Top = 208
    Width = 134
    Height = 15
    Caption = 'Save current desktop &as:'
    FocusControl = edName
  end
  object xLabel3: TLabel
    Left = 12
    Top = 257
    Width = 84
    Height = 15
    Caption = 'Debu&g desktop:'
    FocusControl = cbDebug
  end
  object DesktopList: TListBox
    Left = 12
    Top = 30
    Width = 240
    Height = 170
    ItemHeight = 15
    TabOrder = 0
    OnClick = DesktopListClick
    OnDblClick = DesktopListDblClick
  end
  object btnLoad: TButton
    Left = 260
    Top = 30
    Width = 88
    Height = 26
    Action = aLoad
    Default = True
    TabOrder = 1
  end
  object btnDelete: TButton
    Left = 260
    Top = 64
    Width = 88
    Height = 26
    Action = aDelete
    TabOrder = 2
  end
  object edName: TEdit
    Left = 12
    Top = 226
    Width = 240
    Height = 23
    TabOrder = 3
    OnEnter = edNameEnter
    OnExit = edNameExit
  end
  object btnSave: TButton
    Left = 260
    Top = 225
    Width = 88
    Height = 26
    Action = aSave
    TabOrder = 4
  end
  object cbDebug: TComboBox
    Left = 12
    Top = 275
    Width = 240
    Height = 23
    Style = csDropDownList
    ItemHeight = 15
    TabOrder = 5
    OnChange = cbDebugChange
  end
  object Actions: TActionList
    Left = 300
    Top = 120
    object aLoad: TAction
      Caption = '&Load'
      Hint = 'Show the chosen desktop'
      OnExecute = aLoadExecute
      OnUpdate = aLoadUpdate
    end
    object aDelete: TAction
      Caption = 'D&elete...'
      Hint = 'Delete the chosen desktop'
      OnExecute = aDeleteExecute
      OnUpdate = aLoadUpdate
    end
    object aSave: TAction
      Caption = '&Save'
      Hint = 'Save the current desktop under the name'
      OnExecute = aSaveExecute
      OnUpdate = aSaveUpdate
    end
    object aDebug: TAction
      Caption = 'Debug desktop'
      Hint = 'The desktop shown while the debugger runs'
      OnExecute = aDebugExecute
    end
    object aClose: TAction
      Caption = 'Close'
      OnExecute = aCloseExecute
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 310
    Width = 360
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 6
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 360
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnClose: TButton
      Left = 260
      Top = 13
      Width = 88
      Height = 26
      Action = aClose
      Cancel = True
      TabOrder = 0
    end
  end
end
