object TodoListView: TTodoListView
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'To-Do List'
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
  object TodoList: TListView
    Left = 0
    Top = 0
    Width = 590
    Height = 111
    Align = alClient
    Checkboxes = True
    Columns = <
      item
        Caption = 'Action Item'
        Width = 320
      end
      item
        Caption = '!'
        Width = 30
      end
      item
        Caption = 'Module'
        Width = 140
      end
      item
        Caption = 'Owner'
        Width = 90
      end
      item
        Caption = 'Category'
        Width = 100
      end>
    HideSelection = False
    ReadOnly = True
    RowSelect = True
    ParentShowHint = False
    PopupMenu = TodoPopup
    ShowHint = True
    TabOrder = 0
    ViewStyle = vsReport
    OnColumnClick = TodoListColumnClick
    OnDblClick = TodoListDblClick
    OnChange = TodoListChange
    OnKeyDown = TodoListKeyDown
  end
  object Actions: TActionList
    Left = 24
    Top = 24
    object aTodoOpen: TAction
      Category = 'ToDo'
      Caption = '&Open'
      Hint = 'Go to the comment of the item'
      OnExecute = ItemCommand
    end
    object aTodoAdd: TAction
      Category = 'ToDo'
      Caption = 'Add...'
      Hint = 'Add a to-do item'
      OnExecute = ItemCommand
    end
    object aTodoEdit: TAction
      Category = 'ToDo'
      Caption = '&Edit...'
      Hint = 'Change the to-do item'
      OnExecute = ItemCommand
    end
    object aTodoDelete: TAction
      Category = 'ToDo'
      Caption = 'De&lete'
      Hint = 'Delete the to-do item'
      OnExecute = ItemCommand
    end
    object aTodoSortItem: TAction
      Category = 'ToDo'
      Caption = '&Action Item'
      Hint = 'Sort by the text'
      OnExecute = SortCommand
    end
    object aTodoSortStatus: TAction
      Tag = 1
      Category = 'ToDo'
      Caption = '&Status'
      Hint = 'Sort by status'
      OnExecute = SortCommand
    end
    object aTodoSortType: TAction
      Tag = 2
      Category = 'ToDo'
      Caption = '&Type'
      Hint = 'Sort by type'
      OnExecute = SortCommand
    end
    object aTodoSortPriority: TAction
      Tag = 3
      Category = 'ToDo'
      Caption = '&Priority'
      Hint = 'Sort by priority'
      OnExecute = SortCommand
    end
    object aTodoSortModule: TAction
      Tag = 4
      Category = 'ToDo'
      Caption = '&Module'
      Hint = 'Sort by module'
      OnExecute = SortCommand
    end
    object aTodoSortOwner: TAction
      Tag = 5
      Category = 'ToDo'
      Caption = '&Owner'
      Hint = 'Sort by owner'
      OnExecute = SortCommand
    end
    object aTodoSortCategory: TAction
      Tag = 6
      Category = 'ToDo'
      Caption = '&Category'
      Hint = 'Sort by category'
      OnExecute = SortCommand
    end
    object aTodoFilterCategories: TAction
      Category = 'ToDo'
      Caption = '&Categories...'
      Hint = 'Show the items of some categories'
      OnExecute = FilterCommand
    end
    object aTodoFilterOwners: TAction
      Tag = 1
      Category = 'ToDo'
      Caption = '&Owners...'
      Hint = 'Show the items of some owners'
      OnExecute = FilterCommand
    end
    object aTodoFilterTypes: TAction
      Tag = 2
      Category = 'ToDo'
      Caption = 'Item &Types...'
      Hint = 'Show some types of items'
      OnExecute = FilterCommand
    end
    object aTodoShowCompleted: TAction
      Category = 'ToDo'
      Caption = 'Show Com&pleted Items'
      Checked = True
      Hint = 'Show the items that are done'
      OnExecute = ViewCommand
    end
    object aTodoTooltips: TAction
      Category = 'ToDo'
      Caption = 'Show &ToolTips when Clipped'
      Checked = True
      Hint = 'Show the whole text of a cut item'
      OnExecute = ViewCommand
    end
    object aTodoCopyText: TAction
      Category = 'ToDo'
      Caption = 'Te&xt'
      Hint = 'Copy the list as text'
      OnExecute = ViewCommand
    end
    object aTodoCopyHtml: TAction
      Category = 'ToDo'
      Caption = '&HTML Table'
      Hint = 'Copy the list as an HTML table'
      OnExecute = ViewCommand
    end
    object aTodoTableProps: TAction
      Category = 'ToDo'
      Caption = 'Table &Properties...'
      Hint = 'The columns of the list'
      OnExecute = ViewCommand
    end
  end
  object TodoPopup: TPopupMenu
    OnPopup = TodoPopupPopup
    Left = 72
    Top = 24
    object pmTodo1: TMenuItem
      Action = aTodoOpen
    end
    object pmTodo2: TMenuItem
      Action = aTodoAdd
    end
    object pmTodo3: TMenuItem
      Action = aTodoEdit
    end
    object pmTodo4: TMenuItem
      Action = aTodoDelete
    end
    object pmTodo5: TMenuItem
      Caption = '-'
    end
    object pmTodo6: TMenuItem
      Caption = '&Sort'
      object pmTodo7: TMenuItem
        Action = aTodoSortItem
        GroupIndex = 1
        RadioItem = True
      end
      object pmTodo8: TMenuItem
        Action = aTodoSortStatus
        GroupIndex = 1
        RadioItem = True
      end
      object pmTodo9: TMenuItem
        Action = aTodoSortType
        GroupIndex = 1
        RadioItem = True
      end
      object pmTodo10: TMenuItem
        Action = aTodoSortPriority
        GroupIndex = 1
        RadioItem = True
      end
      object pmTodo11: TMenuItem
        Action = aTodoSortModule
        GroupIndex = 1
        RadioItem = True
      end
      object pmTodo12: TMenuItem
        Action = aTodoSortOwner
        GroupIndex = 1
        RadioItem = True
      end
      object pmTodo13: TMenuItem
        Action = aTodoSortCategory
        GroupIndex = 1
        RadioItem = True
      end
    end
    object pmTodo14: TMenuItem
      Caption = '&Filter'
      object pmTodo15: TMenuItem
        Action = aTodoFilterCategories
      end
      object pmTodo16: TMenuItem
        Action = aTodoFilterOwners
      end
      object pmTodo17: TMenuItem
        Action = aTodoFilterTypes
      end
    end
    object pmTodo18: TMenuItem
      Action = aTodoShowCompleted
    end
    object pmTodo19: TMenuItem
      Action = aTodoTooltips
    end
    object pmTodo20: TMenuItem
      Caption = '-'
    end
    object pmTodo21: TMenuItem
      Caption = '&Copy As'
      object pmTodo22: TMenuItem
        Action = aTodoCopyText
      end
      object pmTodo23: TMenuItem
        Action = aTodoCopyHtml
      end
    end
    object pmTodo24: TMenuItem
      Action = aTodoTableProps
    end
  end
end
