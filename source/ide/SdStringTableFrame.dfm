object StringTableFrame: TStringTableFrame
  Left = 0
  Top = 0
  Width = 520
  Height = 380
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
    Width = 520
    Height = 30
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    DesignSize = (
      520
      30)
    object lblFind: TLabel
      Left = 64
      Top = 8
      Width = 26
      Height = 15
      Caption = '&Find:'
      FocusControl = edFind
    end
    object TopBar: TToolBar
      Left = 0
      Top = 4
      Width = 52
      Height = 22
      Align = alNone
      AutoSize = True
      Caption = 'TopBar'
      EdgeBorders = []
      Flat = True
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      Wrapable = False
      object tbAdd: TToolButton
        Left = 0
        Top = 0
        Action = aAdd
      end
      object tbDelete: TToolButton
        Left = 23
        Top = 0
        Action = EditDeleteCommand
      end
    end
    object edFind: TEdit
      Left = 100
      Top = 4
      Width = 412
      Height = 23
      Anchors = [akLeft, akTop, akRight]
      TabOrder = 1
      OnChange = edFindChange
    end
  end
  object List: TListView
    Left = 0
    Top = 30
    Width = 520
    Height = 350
    Align = alClient
    BorderStyle = bsNone
    Columns = <
      item
        Caption = 'ID'
        Width = 70
      end
      item
        AutoSize = True
        Caption = 'String'
      end>
    HideSelection = False
    Hint = 'F2 or a double click edits a cell. \n is a line break, \t a tab.'
    MultiSelect = True
    ParentShowHint = False
    ReadOnly = True
    RowSelect = True
    ShowHint = True
    TabOrder = 1
    ViewStyle = vsReport
    OnColumnClick = ListColumnClick
    OnCompare = ListCompare
    OnDblClick = ListDblClick
    OnKeyDown = ListKeyDown
    OnMouseDown = ListMouseDown
  end
  object CellEdit: TEdit
    Left = 0
    Top = 0
    Width = 100
    Height = 23
    TabOrder = 2
    Visible = False
    OnExit = EditExit
    OnKeyDown = EditKeyDown
  end
  object Actions: TActionList
    Left = 12
    Top = 336
    object aAdd: TAction
      Caption = '&Add'
      Hint = 'Add a string'
      ImageIndex = 5
      OnExecute = aAddExecute
    end
    object EditDeleteCommand: TAction
      Caption = '&Delete'
      Hint = 'Delete the chosen strings (Del)'
      ImageIndex = 12
      OnExecute = aDeleteExecute
      OnUpdate = aDeleteUpdate
    end
    object aEdit: TAction
      Caption = '&Edit'
      ShortCut = 113
      OnExecute = aEditExecute
      OnUpdate = aEditUpdate
    end
  end
end
