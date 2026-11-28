object MetricsView: TMetricsView
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Metrics'
  ClientHeight = 160
  ClientWidth = 640
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
  object Bar: TToolBar
    Left = 0
    Top = 0
    Width = 640
    Height = 40
    Align = alNone
    ButtonHeight = 38
    ButtonWidth = 72
    Caption = 'Metrics'
    EdgeBorders = []
    Flat = True
    ParentShowHint = False
    ShowCaptions = True
    ShowHint = True
    TabOrder = 0
    Wrapable = False
    Transparent = False
    object tbRun: TToolButton
      Left = 0
      Top = 0
      Action = aMetRun
    end
    object tbRunUnit: TToolButton
      Left = 72
      Top = 0
      Action = aMetRunUnit
    end
    object tbSep1: TToolButton
      Left = 144
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object tbExpand: TToolButton
      Left = 152
      Top = 0
      Action = aMetExpand
    end
    object tbCollapse: TToolButton
      Left = 224
      Top = 0
      Action = aMetCollapse
    end
    object tbOutside: TToolButton
      Left = 296
      Top = 0
      Action = aMetOutside
    end
    object tbSep2: TToolButton
      Left = 368
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object tbExport: TToolButton
      Left = 376
      Top = 0
      Action = aMetExport
    end
    object tbOptions: TToolButton
      Left = 448
      Top = 0
      Action = aMetOptions
    end
  end
  object MetricList: TListView
    Left = 0
    Top = 40
    Width = 640
    Height = 120
    Align = alClient
    Columns = <
      item
        Caption = 'Name'
        Width = 280
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    PopupMenu = MetricsPopup
    TabOrder = 1
    ViewStyle = vsReport
    OnColumnClick = MetricListColumnClick
    OnCustomDrawItem = MetricListCustomDrawItem
    OnCustomDrawSubItem = MetricListCustomDrawSubItem
    OnDblClick = MetricListDblClick
    OnKeyDown = MetricListKeyDown
    OnMouseDown = MetricListMouseDown
  end
  object Actions: TActionList
    OnUpdate = ActionsUpdate
    Left = 40
    Top = 80
    object aMetRun: TAction
      Category = 'Metrics'
      Caption = 'Run'
      Hint = 'Compute the metrics of the active project'
      ImageIndex = 259
      OnExecute = Command
    end
    object aMetRunUnit: TAction
      Category = 'Metrics'
      Caption = 'Unit'
      Hint = 'Compute the metrics of the unit shown'
      ImageIndex = 18
      OnExecute = Command
    end
    object aMetExpand: TAction
      Category = 'Metrics'
      Caption = 'Expand'
      Hint = 'Open every row'
      ImageIndex = 171
      OnExecute = Command
    end
    object aMetCollapse: TAction
      Category = 'Metrics'
      Caption = 'Collapse'
      Hint = 'Close every row'
      ImageIndex = 172
      OnExecute = Command
    end
    object aMetOutside: TAction
      Category = 'Metrics'
      Caption = 'Outside'
      Hint = 'Show only the rows with a value outside its limits'
      ImageIndex = 63
      OnExecute = Command
    end
    object aMetExport: TAction
      Category = 'Metrics'
      Caption = 'Export...'
      Hint = 'Write the results as an HTML or CSV file'
      ImageIndex = 258
      OnExecute = Command
    end
    object aMetOptions: TAction
      Category = 'Metrics'
      Caption = 'Options...'
      Hint = 'The metrics, their limits and aggregations'
      ImageIndex = 147
      OnExecute = Command
    end
    object aMetGoto: TAction
      Category = 'Metrics'
      Caption = '&Go to Code'
      Hint = 'Open the code of the row'
      ImageIndex = 122
      OnExecute = Command
    end
    object aMetCopy: TAction
      Category = 'Metrics'
      Caption = '&Copy'
      Hint = 'Copy the name and the values of the row'
      ImageIndex = 10
      OnExecute = Command
    end
  end
  object MetricsPopup: TPopupMenu
    OnPopup = MenuPopup
    Left = 120
    Top = 80
    object pmGoto: TMenuItem
      Action = aMetGoto
      Default = True
    end
    object pmCopy: TMenuItem
      Action = aMetCopy
    end
    object pmSep1: TMenuItem
      Caption = '-'
    end
    object pmRun: TMenuItem
      Action = aMetRun
      Caption = '&Run on Project'
    end
    object pmRunUnit: TMenuItem
      Action = aMetRunUnit
      Caption = 'Run on &Unit'
    end
    object pmSep2: TMenuItem
      Caption = '-'
    end
    object pmExpand: TMenuItem
      Action = aMetExpand
      Caption = '&Expand All'
    end
    object pmCollapse: TMenuItem
      Action = aMetCollapse
      Caption = 'Co&llapse All'
    end
    object pmOutside: TMenuItem
      Action = aMetOutside
      Caption = 'Only &Outside Limits'
    end
    object pmSep3: TMenuItem
      Caption = '-'
    end
    object pmExport: TMenuItem
      Action = aMetExport
    end
    object pmOptions: TMenuItem
      Action = aMetOptions
    end
  end
end
