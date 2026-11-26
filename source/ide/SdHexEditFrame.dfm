object HexEditFrame: THexEditFrame
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
  object TopBar: TToolBar
    Left = 0
    Top = 0
    Width = 700
    Height = 22
    AutoSize = True
    Caption = 'TopBar'
    EdgeBorders = []
    Flat = True
    ParentShowHint = False
    ShowHint = True
    TabOrder = 0
    Wrapable = False
    object tbLoad: TToolButton
      Left = 0
      Top = 0
      Action = aLoad
    end
    object tbSave: TToolButton
      Left = 23
      Top = 0
      Action = aSave
    end
    object tbSep1: TToolButton
      Left = 46
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object tbUndo: TToolButton
      Left = 54
      Top = 0
      Action = EditUndoCommand
    end
    object tbRedo: TToolButton
      Left = 77
      Top = 0
      Action = EditRedoCommand
    end
  end
  object ViewHost: TPanel
    Left = 0
    Top = 22
    Width = 700
    Height = 426
    Align = alClient
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 1
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
    DesignSize = (
      700
      22)
    object lblStatus: TLabel
      Left = 8
      Top = 3
      Width = 684
      Height = 15
      Anchors = [akLeft, akTop, akRight]
      AutoSize = False
      ShowAccelChar = False
    end
  end
  object Actions: TActionList
    Left = 220
    Top = 60
    object aLoad: TAction
      Caption = '&Load...'
      Hint = 'Load the bytes of a file'
      ImageIndex = 1
      OnExecute = aLoadExecute
    end
    object aSave: TAction
      Caption = '&Save As...'
      Hint = 'Save the bytes into a file'
      ImageIndex = 82
      OnExecute = aSaveExecute
    end
    object EditUndoCommand: TAction
      Caption = '&Undo'
      Hint = 'Undo (Ctrl+Z)'
      ImageIndex = 7
      ShortCut = 16474
      OnExecute = aUndoExecute
      OnUpdate = aUndoUpdate
    end
    object EditRedoCommand: TAction
      Caption = '&Redo'
      Hint = 'Redo (Ctrl+Y)'
      ImageIndex = 8
      ShortCut = 16473
      OnExecute = aRedoExecute
      OnUpdate = aRedoUpdate
    end
  end
end
