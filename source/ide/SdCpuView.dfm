object CpuView: TSdCpuView
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'CPU'
  ClientHeight = 150
  ClientWidth = 880
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
  object DisasmList: TListBox
    Left = 1
    Top = 1
    Width = 676
    Height = 91
    Style = lbOwnerDrawFixed
    BorderStyle = bsNone
    IntegralHeight = False
    ItemHeight = 15
    MultiSelect = True
    PopupMenu = CpuPopup
    TabOrder = 0
    OnDrawItem = DrawItem
    OnContextPopup = ListContextPopup
    OnKeyDown = ListKeyDown
  end
  object RegsList: TListBox
    Left = 681
    Top = 1
    Width = 128
    Height = 91
    Style = lbOwnerDrawFixed
    BorderStyle = bsNone
    IntegralHeight = False
    ItemHeight = 15
    MultiSelect = True
    PopupMenu = CpuPopup
    TabOrder = 1
    OnDrawItem = DrawItem
    OnContextPopup = ListContextPopup
    OnKeyDown = ListKeyDown
  end
  object FlagsList: TListBox
    Left = 813
    Top = 1
    Width = 66
    Height = 91
    Style = lbOwnerDrawFixed
    BorderStyle = bsNone
    IntegralHeight = False
    ItemHeight = 15
    MultiSelect = True
    PopupMenu = CpuPopup
    TabOrder = 2
    OnDrawItem = DrawItem
    OnContextPopup = ListContextPopup
    OnKeyDown = ListKeyDown
  end
  object DumpList: TListBox
    Left = 1
    Top = 96
    Width = 698
    Height = 53
    Style = lbOwnerDrawFixed
    BorderStyle = bsNone
    IntegralHeight = False
    ItemHeight = 15
    MultiSelect = True
    PopupMenu = CpuPopup
    TabOrder = 3
    OnDrawItem = DrawItem
    OnContextPopup = ListContextPopup
    OnKeyDown = ListKeyDown
  end
  object StackList: TListBox
    Left = 703
    Top = 96
    Width = 176
    Height = 53
    Style = lbOwnerDrawFixed
    BorderStyle = bsNone
    IntegralHeight = False
    ItemHeight = 15
    MultiSelect = True
    PopupMenu = CpuPopup
    TabOrder = 4
    OnDrawItem = DrawItem
    OnContextPopup = ListContextPopup
    OnKeyDown = ListKeyDown
  end
  object MenuActions: TActionList
    OnUpdate = MenuActionsUpdate
    Left = 120
    Top = 32
    object aCpuCopy: TAction
      Caption = '&Copy'
      Hint = 'Copy the selected lines'
      ImageIndex = 10
      ShortCut = 16451
    end
    object aCpuCopyLines: TAction
      Caption = 'Copy &Lines...'
      Hint = 'Copy a number of lines from the selected one'
    end
    object aCpuCopyAll: TAction
      Caption = 'Copy &All'
      Hint = 'Copy every line of the pane'
    end
    object aCpuOpenText: TAction
      Caption = 'Open in &Editor'
      Hint = 'The selected lines, else every line of the pane, in a new editor page'
      ImageIndex = 231
    end
    object aCpuGotoAddress: TAction
      Caption = '&Go to Address...'
      Hint = 'Go to Address'
      ImageIndex = 98
      ShortCut = 16455
    end
  end
  object CpuPopup: TPopupMenu
    Left = 216
    Top = 32
    object pmCpuCopy: TMenuItem
      Action = aCpuCopy
    end
    object pmCpuCopyLines: TMenuItem
      Action = aCpuCopyLines
    end
    object pmCpuCopyAll: TMenuItem
      Action = aCpuCopyAll
    end
    object pmCpuOpenText: TMenuItem
      Action = aCpuOpenText
    end
    object pmCpuSep: TMenuItem
      Caption = '-'
    end
    object pmCpuGotoAddress: TMenuItem
      Action = aCpuGotoAddress
    end
  end
end