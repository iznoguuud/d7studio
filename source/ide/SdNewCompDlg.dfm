object NewCompDlg: TNewCompDlg
  Left = 200
  Top = 120
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'New Component'
  ClientHeight = 238
  ClientWidth = 414
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15
  object ncLabel2: TLabel
    Left = 12
    Top = 15
    Width = 76
    Height = 15
    Caption = '&Ancestor type:'
    FocusControl = ClassList
  end
  object ncLabel1: TLabel
    Left = 12
    Top = 50
    Width = 65
    Height = 15
    Caption = '&Class Name:'
    FocusControl = NewClassName
  end
  object ncLabel3: TLabel
    Left = 12
    Top = 85
    Width = 68
    Height = 15
    Caption = '&Palette Page:'
    FocusControl = PageNames
  end
  object ncLabel5: TLabel
    Left = 12
    Top = 120
    Width = 77
    Height = 15
    Caption = '&Unit file name:'
    FocusControl = EditFileName
  end
  object ncLabel4: TLabel
    Left = 12
    Top = 155
    Width = 65
    Height = 15
    Caption = '&Search path:'
    FocusControl = EditSearchPath
  end
  object ClassList: TComboBox
    Left = 96
    Top = 12
    Width = 245
    Height = 23
    ItemHeight = 0
    Sorted = True
    TabOrder = 0
    OnChange = AncestorChange
  end
  object NewClassName: TEdit
    Left = 96
    Top = 47
    Width = 245
    Height = 23
    TabOrder = 1
    OnChange = ClassNameChange
  end
  object PageNames: TComboBox
    Left = 96
    Top = 82
    Width = 175
    Height = 23
    ItemHeight = 0
    TabOrder = 2
    Text = 'Samples'
  end
  object EditFileName: TEdit
    Left = 96
    Top = 117
    Width = 277
    Height = 23
    TabOrder = 3
    OnChange = FileNameChange
  end
  object EditSearchPath: TEdit
    Left = 96
    Top = 152
    Width = 277
    Height = 23
    TabOrder = 4
  end
  object BrowseButton: TButton
    Left = 378
    Top = 117
    Width = 24
    Height = 23
    Action = aBrowseUnit
    TabOrder = 5
  end
  object SearchPathBtn: TButton
    Left = 378
    Top = 152
    Width = 24
    Height = 23
    Action = aSearchPath
    TabOrder = 6
  end
  object Actions: TActionList
    Left = 12
    Top = 244
    object aBrowseUnit: TAction
      Caption = '...'
      OnExecute = aBrowseUnitExecute
    end
    object aSearchPath: TAction
      Caption = '...'
      OnExecute = aSearchPathExecute
    end
    object aInstall: TAction
      Caption = '&Install...'
      OnExecute = aInstallExecute
      OnUpdate = aOKUpdate
    end
    object aOK: TAction
      Caption = 'OK'
      OnExecute = aOKExecute
      OnUpdate = aOKUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 187
    Width = 414
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 7
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 414
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnInstall: TButton
      Left = 122
      Top = 13
      Width = 88
      Height = 26
      Action = aInstall
      TabOrder = 0
    end
    object btnOK: TButton
      Left = 218
      Top = 13
      Width = 88
      Height = 26
      Action = aOK
      Default = True
      TabOrder = 1
    end
    object btnCancel: TButton
      Left = 314
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
