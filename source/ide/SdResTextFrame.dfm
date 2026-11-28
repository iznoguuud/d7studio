object ResTextFrame: TResTextFrame
  Left = 0
  Top = 0
  Width = 700
  Height = 470
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  ParentFont = False
  TabOrder = 0
  object TopPanel: TPanel
    Left = 0
    Top = 0
    Width = 700
    Height = 30
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    ParentBackground = False
    object lblFind: TLabel
      Left = 6
      Top = 8
      Width = 26
      Height = 15
      Caption = '&Find:'
      FocusControl = edFind
    end
    object edFind: TEdit
      Left = 40
      Top = 4
      Width = 220
      Height = 23
      TabOrder = 0
      OnKeyPress = edFindKeyPress
    end
    object TopBar: TToolBar
      Left = 264
      Top = 4
      Width = 23
      Height = 22
      Align = alNone
      AutoSize = True
      Caption = 'TopBar'
      EdgeBorders = []
      Flat = True
      ParentShowHint = False
      ShowHint = True
      TabOrder = 1
      Wrapable = False
      object tbFindNext: TToolButton
        Left = 0
        Top = 0
        Action = aFindNext
      end
    end
  end
  object EditorHost: TPanel
    Left = 0
    Top = 30
    Width = 700
    Height = 418
    Align = alClient
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 1
    ParentBackground = False
  end
  object StatusPanel: TPanel
    Left = 0
    Top = 448
    Width = 700
    Height = 22
    Align = alBottom
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 2
    ParentBackground = False
    object lblPos: TLabel
      Left = 8
      Top = 3
      Width = 120
      Height = 15
      AutoSize = False
      ShowAccelChar = False
    end
  end
  object Actions: TActionList
    Left = 220
    Top = 60
    object aFind: TAction
      Caption = '&Find'
      ShortCut = 16454
      OnExecute = aFindExecute
    end
    object aFindNext: TAction
      Caption = 'Find &Next'
      Hint = 'Find the next one (F3)'
      ImageIndex = 96
      ShortCut = 114
      OnExecute = aFindNextExecute
      OnUpdate = aFindNextUpdate
    end
    object EditUndoCommand: TAction
      Caption = '&Undo'
      OnExecute = EditExecute
      OnUpdate = EditUpdate
    end
    object EditRedoCommand: TAction
      Caption = '&Redo'
      OnExecute = EditExecute
      OnUpdate = EditUpdate
    end
    object EditCutCommand: TAction
      Caption = 'Cu&t'
      OnExecute = EditExecute
      OnUpdate = EditUpdate
    end
    object EditCopyCommand: TAction
      Caption = '&Copy'
      OnExecute = EditExecute
      OnUpdate = EditUpdate
    end
    object EditPasteCommand: TAction
      Caption = '&Paste'
      OnExecute = EditExecute
      OnUpdate = EditUpdate
    end
    object EditDeleteCommand: TAction
      Caption = '&Delete'
      OnExecute = EditExecute
      OnUpdate = EditUpdate
    end
    object EditSelectAllCommand: TAction
      Caption = 'Select &All'
      OnExecute = EditExecute
      OnUpdate = EditUpdate
    end
  end
end
