inherited SdHistoryView: TSdHistoryView
  Width = 800
  Height = 400
  object Timeline: TListBox
    Left = 0
    Top = 0
    Width = 240
    Height = 400
    Style = lbOwnerDrawVariable
    BorderStyle = bsNone
    ItemHeight = 15
    MultiSelect = True
    TabOrder = 0
    OnClick = TimelineClick
    OnDblClick = TimelineDblClick
    OnDrawItem = TimelineDrawItem
    OnKeyDown = TimelineKeyDown
    OnMeasureItem = TimelineMeasureItem
    OnMouseDown = TimelineMouseDown
  end
  object DiffHost: TPanel
    Left = 244
    Top = 0
    Width = 556
    Height = 400
    BevelOuter = bvNone
    Color = clWindow
    TabOrder = 1
    OnResize = DiffHostResize
    object StatusPanel: TPanel
      Left = 0
      Top = 378
      Width = 556
      Height = 22
      Align = alBottom
      BevelOuter = bvNone
      ParentColor = True
      TabOrder = 0
      object StatusLabel: TLabel
        Left = 6
        Top = 3
        Width = 544
        Height = 15
        AutoSize = False
        ShowAccelChar = False
      end
    end
  end
  object FilterPanel: TPanel
    Left = 380
    Top = 120
    Width = 360
    Height = 24
    BevelOuter = bvNone
    TabOrder = 2
    Visible = False
    OnResize = FilterPanelResize
    object RoutineBox: TComboBox
      Left = 0
      Top = 0
      Width = 190
      Height = 23
      Style = csDropDownList
      DropDownCount = 24
      ItemHeight = 15
      TabOrder = 0
      OnChange = RoutineBoxChange
    end
    object FindBox: TEdit
      Left = 196
      Top = 0
      Width = 164
      Height = 23
      TabOrder = 1
      OnChange = FindBoxChange
      OnKeyDown = FindBoxKeyDown
    end
  end
  object FindTimer: TTimer
    Enabled = False
    Interval = 300
    OnTimer = FindTimerTimer
    Left = 400
    Top = 200
  end
end
