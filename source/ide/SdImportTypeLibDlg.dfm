object ImportTypeLibDlg: TImportTypeLibDlg
  Left = 243
  Top = 176
  ActiveControl = ControlList
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Import Type Library'
  ClientHeight = 475
  ClientWidth = 400
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 15
  object Location: TLabel
    Left = 12
    Top = 172
    Width = 376
    Height = 15
    AutoSize = False
    ShowAccelChar = False
  end
  object Label2: TLabel
    Left = 12
    Top = 232
    Width = 66
    Height = 15
    Caption = 'Class &names:'
    FocusControl = ClassNames
  end
  object Label3: TLabel
    Left = 12
    Top = 300
    Width = 70
    Height = 15
    Caption = '&Palette page:'
    FocusControl = PageNames
  end
  object Label4: TLabel
    Left = 12
    Top = 331
    Width = 79
    Height = 15
    Caption = '&Unit dir name:'
    FocusControl = UnitDirName
  end
  object Label5: TLabel
    Left = 12
    Top = 362
    Width = 67
    Height = 15
    Caption = '&Search path:'
    FocusControl = SearchPath
  end
  object ControlList: TListBox
    Left = 12
    Top = 12
    Width = 376
    Height = 154
    ItemHeight = 15
    TabOrder = 0
    OnClick = ListClick
  end
  object AddButton: TButton
    Left = 205
    Top = 193
    Width = 88
    Height = 26
    Action = aAdd
    TabOrder = 1
  end
  object RemoveButton: TButton
    Left = 300
    Top = 193
    Width = 88
    Height = 26
    Action = aRemove
    TabOrder = 2
  end
  object ClassNames: TMemo
    Left = 108
    Top = 229
    Width = 280
    Height = 58
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 3
    WordWrap = False
  end
  object PageNames: TComboBox
    Left = 108
    Top = 297
    Width = 280
    Height = 23
    ItemHeight = 15
    TabOrder = 4
  end
  object UnitDirName: TEdit
    Left = 108
    Top = 328
    Width = 249
    Height = 23
    TabOrder = 5
  end
  object BrowseButton: TButton
    Left = 363
    Top = 328
    Width = 25
    Height = 23
    Action = aBrowse
    TabOrder = 6
  end
  object SearchPath: TEdit
    Left = 108
    Top = 359
    Width = 280
    Height = 23
    TabOrder = 7
  end
  object MakeComponentBox: TCheckBox
    Left = 12
    Top = 393
    Width = 260
    Height = 19
    Caption = '&Generate Component Wrapper'
    Checked = True
    State = cbChecked
    TabOrder = 8
    OnClick = WrapperClick
  end
  object Actions: TActionList
    Left = 24
    Top = 40
    object aAdd: TAction
      Caption = '&Add...'
      OnExecute = aAddExecute
    end
    object aRemove: TAction
      Caption = '&Remove'
      OnExecute = aRemoveExecute
      OnUpdate = aRemoveUpdate
    end
    object aBrowse: TAction
      Caption = '...'
      OnExecute = aBrowseExecute
    end
    object aInstall: TAction
      Caption = '&Install...'
      OnExecute = aInstallExecute
      OnUpdate = aChosenUpdate
    end
    object aCreateUnit: TAction
      Caption = 'Create &Unit'
      OnExecute = aCreateUnitExecute
      OnUpdate = aChosenUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 424
    Width = 400
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 9
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 400
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object InstallButton: TButton
      Left = 108
      Top = 13
      Width = 88
      Height = 26
      Action = aInstall
      TabOrder = 0
    end
    object OkButton: TButton
      Left = 204
      Top = 13
      Width = 88
      Height = 26
      Action = aCreateUnit
      Default = True
      TabOrder = 1
    end
    object CancelBtn: TButton
      Left = 300
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
