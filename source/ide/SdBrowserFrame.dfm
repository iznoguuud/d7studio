inherited SdBrowser: TSdBrowser
  object SymList: TListView
    Left = 1
    Top = 22
    Width = 350
    Height = 100
    BorderStyle = bsNone
    Columns = <
      item
      end>
    HideSelection = False
    OwnerData = True
    ReadOnly = True
    RowSelect = True
    ShowColumnHeaders = False
    TabOrder = 0
    ViewStyle = vsReport
    Visible = False
    OnData = ListData
    OnDataFind = ListDataFind
    OnDblClick = ViewDblClick
    OnEnter = ViewEnter
    OnKeyDown = ViewKeyDown
    OnMouseDown = ViewMouseDown
    OnSelectItem = ListSelectItem
  end
  object ClassTree: TTreeView
    Left = 1
    Top = 22
    Width = 350
    Height = 100
    BorderStyle = bsNone
    HideSelection = False
    ReadOnly = True
    RightClickSelect = True
    TabOrder = 1
    OnChange = TreeChange
    OnDblClick = ViewDblClick
    OnEnter = ViewEnter
    OnKeyDown = ViewKeyDown
    OnMouseDown = ViewMouseDown
  end
  object DetailTree: TTreeView
    Left = 530
    Top = 44
    Width = 350
    Height = 100
    BorderStyle = bsNone
    HideSelection = False
    ReadOnly = True
    RightClickSelect = True
    TabOrder = 2
    OnDblClick = ViewDblClick
    OnEnter = ViewEnter
    OnKeyDown = ViewKeyDown
    OnMouseDown = ViewMouseDown
  end
  object DetailList: TListView
    Left = 1
    Top = 44
    Width = 350
    Height = 100
    BorderStyle = bsNone
    Columns = <
      item
      end>
    HideSelection = False
    OwnerData = True
    ReadOnly = True
    RowSelect = True
    ShowColumnHeaders = False
    TabOrder = 3
    ViewStyle = vsReport
    Visible = False
    OnData = ListData
    OnDataFind = ListDataFind
    OnDblClick = ViewDblClick
    OnEnter = ViewEnter
    OnKeyDown = ViewKeyDown
    OnMouseDown = ViewMouseDown
  end
  object MenuActions: TActionList
    Left = 24
    Top = 32
    object aBrGoto: TAction
      Category = 'Browser'
      Caption = '&Go to Declaration'
      Hint = 'Show the declaration (or the place) in the editor'
    end
    object aBrBrowse: TAction
      Category = 'Browser'
      Caption = '&Browse'
      Hint = 'Show the scope, inheritance and references of the chosen symbol'
    end
    object aBrBack: TAction
      Category = 'Browser'
      Caption = 'B&ack'
      Hint = 'Back to the symbol shown before'
    end
    object aBrRefresh: TAction
      Category = 'Browser'
      Caption = '&Refresh'
      Hint = 'Browse the project again'
    end
    object aBrDetails: TAction
      Category = 'Browser'
      Caption = 'De&tails'
      Hint = 'Show the scope, inheritance and references of the symbol'
    end
    object aBrProperties: TAction
      Category = 'Browser'
      Caption = '&Properties'
      Hint = 'Environment Options | Explorer'
    end
  end
  object BrowserPopup: TPopupMenu
    Left = 72
    Top = 32
    object pmBr1: TMenuItem
      Action = aBrGoto
    end
    object pmBrBrowse: TMenuItem
      Action = aBrBrowse
    end
    object pmBrBack: TMenuItem
      Action = aBrBack
    end
    object pmBr2: TMenuItem
      Action = aBrRefresh
    end
    object pmBr3: TMenuItem
      Caption = '-'
    end
    object pmBr4: TMenuItem
      Action = aBrDetails
    end
    object pmBr5: TMenuItem
      Action = aBrProperties
    end
  end
end
