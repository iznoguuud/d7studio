object ComponentBar: TSdComponentBar
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Components'
  ClientHeight = 400
  ClientWidth = 232
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
  object Category: TComboBox
    Left = 0
    Top = 0
    Width = 232
    Height = 23
    Style = csDropDownList
    DropDownCount = 24
    ItemHeight = 15
    TabOrder = 0
    OnChange = CategoryChange
  end
  object Filter: TEdit
    Left = 0
    Top = 25
    Width = 232
    Height = 23
    TabOrder = 1
    OnChange = FilterChange
    OnKeyDown = FilterKeyDown
    OnKeyPress = SwallowKeyPress
  end
  object List: TListBox
    Left = 1
    Top = 51
    Width = 230
    Height = 348
    Style = lbOwnerDrawFixed
    BorderStyle = bsNone
    ItemHeight = 32
    TabOrder = 2
    OnClick = ListClick
    OnDblClick = ListDblClick
    OnDrawItem = ListDrawItem
    OnKeyDown = ListKeyDown
    OnKeyPress = ListKeyPress
    OnMouseDown = ListMouseDown
    OnMouseMove = ListMouseMove
    OnMouseUp = ListMouseUp
  end
  object MenuActions: TActionList
    Left = 24
    Top = 32
    object aCompAdd: TAction
      Category = 'Components'
      Caption = '&Add to Form'
      Hint = 'Add the component to the form being designed'
    end
    object aCompShowCategory: TAction
      Category = 'Components'
      Caption = '&Jump to Category'
      Hint = 'Show the components of the category of this one'
    end
    object aCompAll: TAction
      Category = 'Components'
      Caption = 'All C&omponents'
      Hint = 'Show the components of every category'
    end
    object aCompSortName: TAction
      Category = 'Components'
      Caption = 'By &Name'
      GroupIndex = 1
      Hint = 'Sort the list: By Name'
    end
    object aCompSortRecent: TAction
      Tag = 1
      Category = 'Components'
      Caption = 'Last &Used First'
      GroupIndex = 1
      Hint = 'Sort the list: Last Used First'
    end
    object aCompSortMost: TAction
      Tag = 2
      Category = 'Components'
      Caption = '&Most Used First'
      GroupIndex = 1
      Hint = 'Sort the list: Most Used First'
    end
    object aCompSortPalette: TAction
      Tag = 3
      Category = 'Components'
      Caption = 'In &Palette Order'
      GroupIndex = 1
      Hint = 'Sort the list: In Palette Order'
    end
    object aCompProperties: TAction
      Category = 'Components'
      Caption = 'Properties'
      Hint = 'The options of the Components view'
    end
  end
  object CompPopup: TPopupMenu
    Left = 72
    Top = 32
    object pmComp1: TMenuItem
      Action = aCompAdd
    end
    object pmComp2: TMenuItem
      Action = aCompShowCategory
    end
    object pmComp3: TMenuItem
      Action = aCompAll
    end
    object pmComp4: TMenuItem
      Caption = '-'
    end
    object pmCompSort: TMenuItem
      Caption = '&Sort'
      object pmCompSort0: TMenuItem
        Action = aCompSortName
        GroupIndex = 1
        RadioItem = True
      end
      object pmCompSort1: TMenuItem
        Action = aCompSortRecent
        GroupIndex = 1
        RadioItem = True
      end
      object pmCompSort2: TMenuItem
        Action = aCompSortMost
        GroupIndex = 1
        RadioItem = True
      end
      object pmCompSort3: TMenuItem
        Action = aCompSortPalette
        GroupIndex = 1
        RadioItem = True
      end
    end
    object pmComp5: TMenuItem
    end
    object pmComp11: TMenuItem
      Action = aCompProperties
    end
  end
end
