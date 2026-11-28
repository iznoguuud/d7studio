object EditorPage: TEditorPage
  Left = 0
  Top = 0
  Width = 600
  Height = 400
  AutoScroll = False
  TabOrder = 0
  object DesignPanel: TPanel
    Left = 0
    Top = 0
    Width = 600
    Height = 400
    Align = alClient
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 0
    Visible = False
    ParentBackground = False
  end
  object AutoTimer: TTimer
    Enabled = False
    Interval = 200
    OnTimer = AutoTimerTick
    Left = 8
    Top = 8
  end
  object HintTimer: TTimer
    Enabled = False
    Interval = 100
    OnTimer = HintTimerTick
    Left = 40
    Top = 8
  end
  object IdentTimer: TTimer
    Enabled = False
    Interval = 250
    OnTimer = IdentTimerTick
    Left = 72
    Top = 8
  end
  object NameTimer: TTimer
    Enabled = False
    Interval = 250
    OnTimer = NameTimerTick
    Left = 104
    Top = 8
  end
  object ErrorTimer: TTimer
    Enabled = False
    OnTimer = ErrorTimerTick
    Left = 136
    Top = 8
  end
end
