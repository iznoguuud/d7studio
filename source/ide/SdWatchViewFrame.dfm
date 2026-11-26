inherited SdWatchView: TSdWatchView
  inherited Header: THeaderControl
    Sections = <
      item
        ImageIndex = -1
        MinWidth = 30
        Text = 'Watch Name'
        Width = 100
      end
      item
        ImageIndex = -1
        MinWidth = 30
        Text = 'Value'
        Width = 130
      end>
  end
  inherited Tree: TTreeView
    MultiSelect = True
    MultiSelectStyle = [msControlSelect, msShiftSelect]
    StateImages = Checks
  end
  object Checks: TImageList
    Left = 8
    Top = 32
  end
  object MenuActions: TActionList
    Left = 24
    Top = 32
    object aWatchEdit: TAction
      Category = 'Debug'
      Caption = '&Edit Watch...'
      Hint = 'Change the watch'
    end
    object aWatchNew: TAction
      Category = 'Debug'
      Caption = '&Add Watch...'
      Hint = 'Add a watch expression'
      ImageIndex = 38
    end
    object aWatchEnable: TAction
      Category = 'Debug'
      Caption = 'E&nable Watch'
      Hint = 'Enable the watch'
    end
    object aWatchDisable: TAction
      Category = 'Debug'
      Caption = 'D&isable Watch'
      Hint = 'Disable the watch'
    end
    object aWatchDelete: TAction
      Category = 'Debug'
      Caption = '&Delete Watch'
      Hint = 'Delete the selected watch'
      ImageIndex = 12
    end
    object aWatchCopyValue: TAction
      Category = 'Debug'
      Caption = 'Copy Watch &Value'
      Hint = 'Copy the value of the watch'
    end
    object aWatchCopyName: TAction
      Category = 'Debug'
      Caption = 'Cop&y Watch Name'
      Hint = 'Copy the name of the watch'
    end
    object aWatchEnableAll: TAction
      Category = 'Debug'
      Caption = 'Enab&le All Watches'
      Hint = 'Enable all watches'
    end
    object aWatchDisableAll: TAction
      Category = 'Debug'
      Caption = 'Disa&ble All Watches'
      Hint = 'Disable all watches'
    end
    object aWatchDeleteAll: TAction
      Category = 'Debug'
      Caption = 'Dele&te All Watches'
      Hint = 'Delete all watches'
    end
    object aWatchAddGroup: TAction
      Category = 'Debug'
      Caption = 'Add Group...'
      Hint = 'Add a group of watches'
    end
    object aWatchDeleteGroup: TAction
      Category = 'Debug'
      Caption = 'Delete Group'
      Hint = 'Delete a group of watches'
    end
    object aWatchMoveGroup: TAction
      Category = 'Debug'
      Caption = 'Move Watch To Group'
      Hint = 'Move the watch to another group'
    end
    object aWatchBreakChanged: TAction
      Category = 'Debug'
      Caption = 'Break When &Changed'
      Hint = 'Stop when the value changes'
    end
    object aWatchHeaders: TAction
      Category = 'Debug'
      Caption = 'Show Column &Headers'
      Hint = 'Show the column headers'
    end
  end
  object WatchPopup: TPopupMenu
    Left = 72
    Top = 32
    object pmWatch1: TMenuItem
      Action = aWatchEdit
    end
    object pmWatch2: TMenuItem
      Action = aWatchNew
    end
    object pmWatch3: TMenuItem
      Caption = '-'
    end
    object pmWatch4: TMenuItem
      Action = aWatchEnable
    end
    object pmWatch5: TMenuItem
      Action = aWatchDisable
    end
    object pmWatch6: TMenuItem
      Action = aWatchDelete
    end
    object pmWatch7: TMenuItem
      Action = aWatchCopyValue
    end
    object pmWatch8: TMenuItem
      Action = aWatchCopyName
    end
    object pmWatch9: TMenuItem
      Caption = '-'
    end
    object pmWatch10: TMenuItem
      Action = aWatchEnableAll
    end
    object pmWatch11: TMenuItem
      Action = aWatchDisableAll
    end
    object pmWatch12: TMenuItem
      Action = aWatchDeleteAll
    end
    object pmWatch13: TMenuItem
      Caption = '-'
    end
    object pmWatch14: TMenuItem
      Action = aWatchAddGroup
    end
    object pmWatch15: TMenuItem
      Action = aWatchDeleteGroup
    end
    object pmWatch16: TMenuItem
      Action = aWatchMoveGroup
    end
    object pmWatch17: TMenuItem
      Caption = '-'
    end
    object pmWatch19: TMenuItem
      Action = aWatchBreakChanged
    end
    object pmWatch20: TMenuItem
      Caption = '-'
    end
    object pmWatch21: TMenuItem
      Action = aWatchHeaders
    end
  end
end
