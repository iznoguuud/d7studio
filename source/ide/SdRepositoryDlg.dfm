object RepositoryDlg: TRepositoryDlg
  Left = 200
  Top = 120
  BorderStyle = bsDialog
  Caption = 'Object Repository'
  ClientHeight = 384
  ClientWidth = 477
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
  object PageLabel: TLabel
    Left = 12
    Top = 12
    Width = 58
    Height = 19
    AutoSize = False
    Caption = '&Pages:'
    FocusControl = PageListBox
  end
  object ObjectLabel: TLabel
    Left = 274
    Top = 12
    Width = 54
    Height = 19
    AutoSize = False
    Caption = '&Objects:'
  end
  object PlaceHolder: TBevel
    Left = 274
    Top = 31
    Width = 191
    Height = 255
  end
  object cbNewProject: TCheckBox
    Left = 274
    Top = 295
    Width = 93
    Height = 19
    Caption = 'Ne&w Project'
    TabOrder = 0
    Visible = False
    OnClick = FlagClick
  end
  object PageListBox: TListBox
    Left = 12
    Top = 31
    Width = 131
    Height = 255
    DragMode = dmAutomatic
    ItemHeight = 13
    TabOrder = 1
    OnClick = PageClick
  end
  object cbMainForm: TCheckBox
    Left = 373
    Top = 295
    Width = 82
    Height = 19
    Caption = '&Main Form'
    Enabled = False
    TabOrder = 2
    OnClick = FlagClick
  end
  object MoveUp: TBitBtn
    Left = 41
    Top = 295
    Width = 26
    Height = 26
    Action = aMoveUp
    TabOrder = 3
  end
  object MoveDn: TBitBtn
    Left = 88
    Top = 295
    Width = 26
    Height = 26
    Action = aMoveDown
    TabOrder = 4
  end
  object cbNewForm: TCheckBox
    Left = 278
    Top = 295
    Width = 82
    Height = 19
    Caption = '&New Form'
    Enabled = False
    TabOrder = 5
    OnClick = FlagClick
  end
  object AddButton: TButton
    Left = 158
    Top = 61
    Width = 102
    Height = 26
    Action = aAddPage
    TabOrder = 6
  end
  object DeletePage: TButton
    Left = 158
    Top = 96
    Width = 102
    Height = 26
    Action = aDeletePage
    TabOrder = 7
  end
  object RenameButton: TButton
    Left = 158
    Top = 131
    Width = 102
    Height = 26
    Action = aRenamePage
    TabOrder = 8
  end
  object EditButton: TButton
    Left = 158
    Top = 192
    Width = 102
    Height = 26
    Action = aEditObject
    TabOrder = 9
  end
  object DeleteObject: TButton
    Left = 158
    Top = 226
    Width = 102
    Height = 26
    Action = aDeleteObject
    TabOrder = 10
  end
  object ObjectList: TListView
    Left = 274
    Top = 31
    Width = 191
    Height = 255
    Columns = <>
    HideSelection = False
    ReadOnly = True
    SortType = stText
    TabOrder = 11
    ViewStyle = vsList
    OnSelectItem = ObjectSelect
    OnDblClick = ObjectDblClick
  end
  object Actions: TActionList
    Left = 12
    Top = 310
    object aAddPage: TAction
      Caption = '&Add Page...'
      OnExecute = aAddPageExecute
    end
    object aDeletePage: TAction
      Caption = '&Delete Page'
      OnExecute = aDeletePageExecute
      OnUpdate = aDeletePageUpdate
    end
    object aRenamePage: TAction
      Caption = '&Rename Page...'
      OnExecute = aRenamePageExecute
      OnUpdate = aPageUpdate
    end
    object aEditObject: TAction
      Caption = '&Edit Object...'
      OnExecute = aEditObjectExecute
      OnUpdate = aObjectUpdate
    end
    object aDeleteObject: TAction
      Caption = 'De&lete Object'
      OnExecute = aDeleteObjectExecute
      OnUpdate = aObjectUpdate
    end
    object aMoveUp: TAction
      OnExecute = PageMoveExecute
      OnUpdate = PageMoveUpdate
    end
    object aMoveDown: TAction
      OnExecute = PageMoveExecute
      OnUpdate = PageMoveUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 333
    Width = 477
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 12
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 477
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 281
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object CancelBtn: TButton
      Left = 377
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
