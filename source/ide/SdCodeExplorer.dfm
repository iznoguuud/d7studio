object CodeExplorerView: TCodeExplorerView
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Code Explorer'
  ClientHeight = 200
  ClientWidth = 232
  Color = clBtnFace
  DefaultMonitor = dmDesktop
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 15
  object Tree: TTreeView
    Left = 0
    Top = 0
    Width = 232
    Height = 200
    Align = alClient
    HideSelection = False
    Indent = 19
    PopupMenu = ExpPopup
    TabOrder = 0
    OnChange = TreeChange
    OnCustomDrawItem = TreeCustomDrawItem
    OnDblClick = TreeDblClick
    OnEdited = TreeEdited
    OnEditing = TreeEditing
    OnExit = TreeExit
    OnKeyDown = TreeKeyDown
    OnKeyPress = TreeKeyPress
  end
  object Actions: TActionList
    Left = 16
    Top = 16
    object aExpNew: TAction
      Caption = '&New'
      Hint = 'Add an item'
      ShortCut = 45
      OnExecute = aExpNewExecute
      OnUpdate = aExpNewUpdate
    end
    object aExpRename: TAction
      Caption = '&Rename'
      Hint = 'Rename the item'
      ShortCut = 16466
      OnExecute = aExpRenameExecute
      OnUpdate = aExpRenameUpdate
    end
    object aExpViewEditor: TAction
      Caption = 'View &Editor'
      Hint = 'Show the code editor'
      OnExecute = aExpViewEditorExecute
    end
    object aExpProperties: TAction
      Caption = 'Properties'
      Hint = 'Explorer options'
      OnExecute = aExpPropertiesExecute
    end
  end
  object ExpPopup: TPopupMenu
    Left = 64
    Top = 16
    object pmExpNew: TMenuItem
      Action = aExpNew
    end
    object pmExpRename: TMenuItem
      Action = aExpRename
    end
    object pmExpLine1: TMenuItem
      Caption = '-'
    end
    object pmExpViewEditor: TMenuItem
      Action = aExpViewEditor
    end
    object pmExpLine2: TMenuItem
      Caption = '-'
    end
    object pmExpProperties: TMenuItem
      Action = aExpProperties
    end
  end
  object SearchTimer: TTimer
    Enabled = False
    OnTimer = SearchTimerTimer
    Left = 112
    Top = 16
  end
  object ParseTimer: TTimer
    Enabled = False
    Interval = 500
    OnTimer = ParseTimerTimer
    Left = 160
    Top = 16
  end
  object FollowTimer: TTimer
    Enabled = False
    Interval = 300
    OnTimer = FollowTimerTimer
    Left = 208
    Top = 16
  end
end