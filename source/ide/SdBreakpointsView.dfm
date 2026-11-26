object BreakpointsView: TBreakpointsView
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Breakpoints'
  ClientHeight = 111
  ClientWidth = 590
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
  object BreakList: TListView
    Left = 0
    Top = 0
    Width = 590
    Height = 111
    Align = alClient
    Checkboxes = True
    Columns = <
      item
        Caption = 'Filename/Address'
        Width = 160
      end
      item
        Caption = 'Line/Length'
        Width = 90
      end
      item
        Caption = 'Condition'
        Width = 150
      end
      item
        Caption = 'Action'
        Width = 150
      end
      item
        Caption = 'Pass Count'
        Width = 90
      end
      item
        Caption = 'Group'
        Width = 80
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    PopupMenu = BreakPopup
    TabOrder = 0
    ViewStyle = vsReport
    OnContextPopup = BreakListContextPopup
    OnDblClick = BreakListDblClick
  end
  object Actions: TActionList
    Left = 24
    Top = 24
    object aBPDeleteAll: TAction
      Category = 'Breakpoints'
      Caption = '&Delete All'
      Hint = 'Delete all breakpoints'
      OnExecute = Command
    end
    object aBPDisableAll: TAction
      Category = 'Breakpoints'
      Caption = 'D&isable All'
      Hint = 'Disable all breakpoints'
      OnExecute = Command
    end
    object aBPEnableAll: TAction
      Category = 'Breakpoints'
      Caption = '&Enable All'
      Hint = 'Enable all breakpoints'
      OnExecute = Command
    end
    object aBPDisableGroup: TAction
      Category = 'Breakpoints'
      Caption = 'Disable &Group'
      Hint = 'Disable a group of breakpoints'
      OnExecute = Command
    end
    object aBPEnableGroup: TAction
      Category = 'Breakpoints'
      Caption = 'E&nable Group'
      Hint = 'Enable a group of breakpoints'
      OnExecute = Command
    end
    object aBPEnabled: TAction
      Category = 'Breakpoints'
      Caption = '&Enabled'
      Hint = 'Enable or disable the breakpoint'
      OnExecute = Command
    end
    object aBPDelete: TAction
      Category = 'Breakpoints'
      Caption = '&Delete'
      Hint = 'Delete the breakpoint'
      OnExecute = Command
    end
    object aBPViewSource: TAction
      Category = 'Breakpoints'
      Caption = '&View Source'
      Hint = 'Show the line of the breakpoint in the editor'
      OnExecute = Command
    end
    object aBPEditSource: TAction
      Category = 'Breakpoints'
      Caption = 'Edit &Source'
      Hint = 'Go to the line of the breakpoint in the editor'
      OnExecute = Command
    end
    object aBPProperties: TAction
      Category = 'Breakpoints'
      Caption = 'P&roperties'
      Hint = 'The condition of the breakpoint'
      OnExecute = Command
    end
  end
  object BreakPopup: TPopupMenu
    OnPopup = MenuPopup
    Left = 72
    Top = 24
    object pmBreak1: TMenuItem
      Caption = '&Add'
      object pmBreak2: TMenuItem
      end
      object pmBreak3: TMenuItem
      end
      object pmBreak4: TMenuItem
      end
    end
    object pmBreak5: TMenuItem
      Action = aBPDeleteAll
    end
    object pmBreak6: TMenuItem
      Action = aBPDisableAll
    end
    object pmBreak7: TMenuItem
      Action = aBPEnableAll
    end
    object pmBreak8: TMenuItem
      Caption = '-'
    end
    object pmBreak9: TMenuItem
      Action = aBPDisableGroup
    end
    object pmBreak10: TMenuItem
      Action = aBPEnableGroup
    end
  end
  object BreakItemPopup: TPopupMenu
    OnPopup = MenuPopup
    Left = 120
    Top = 24
    object pmBreakItem1: TMenuItem
      Action = aBPEnabled
    end
    object pmBreakItem2: TMenuItem
      Action = aBPDelete
    end
    object pmBreakItem3: TMenuItem
      Caption = '-'
    end
    object pmBreakItem4: TMenuItem
      Action = aBPViewSource
    end
    object pmBreakItem5: TMenuItem
      Action = aBPEditSource
    end
    object pmBreakItem6: TMenuItem
      Caption = '-'
    end
    object pmBreakItem7: TMenuItem
      Action = aBPProperties
    end
    object pmBreakItem8: TMenuItem
      Caption = '-'
    end
    object pmBreakItem9: TMenuItem
      Caption = 'Breakpoints'
      object pmBreakItem10: TMenuItem
        Caption = '&Add'
        object pmBreakItem11: TMenuItem
        end
        object pmBreakItem12: TMenuItem
        end
        object pmBreakItem13: TMenuItem
        end
      end
      object pmBreakItem14: TMenuItem
        Action = aBPDeleteAll
      end
      object pmBreakItem15: TMenuItem
        Action = aBPDisableAll
      end
      object pmBreakItem16: TMenuItem
        Action = aBPEnableAll
      end
      object pmBreakItem17: TMenuItem
        Caption = '-'
      end
      object pmBreakItem18: TMenuItem
        Action = aBPDisableGroup
      end
      object pmBreakItem19: TMenuItem
        Action = aBPEnableGroup
      end
    end
  end
end
