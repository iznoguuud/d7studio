inherited SdTypeLibView: TSdTypeLibView
  object LibTree: TTreeView
    Left = 1
    Top = 22
    Width = 350
    Height = 100
    BorderStyle = bsNone
    HideSelection = False
    ReadOnly = True
    RightClickSelect = True
    TabOrder = 0
    OnChange = TreeChange
    OnExpanding = TreeExpanding
  end
  object AttrList: TListView
    Left = 530
    Top = 44
    Width = 350
    Height = 100
    BorderStyle = bsNone
    Columns = <
      item
        Width = 130
      end
      item
        Width = 400
      end>
    ReadOnly = True
    RowSelect = True
    ShowColumnHeaders = False
    TabOrder = 1
    ViewStyle = vsReport
  end
  object MenuActions: TActionList
    Left = 24
    Top = 32
    object aTlOpen: TAction
      Category = 'Type Library'
      Caption = '&Open...'
      Hint = 'Show another type library'
    end
    object aTlExport: TAction
      Category = 'Type Library'
      Caption = '&Save as Unit...'
      Hint = 'Write the Pascal unit of the type library'
    end
    object aTlRefresh: TAction
      Category = 'Type Library'
      Caption = '&Refresh'
      Hint = 'Read the type library again'
    end
  end
  object TypeLibPopup: TPopupMenu
    Left = 72
    Top = 32
    object pmTl1: TMenuItem
      Action = aTlOpen
    end
    object pmTl2: TMenuItem
      Action = aTlExport
    end
    object pmTl3: TMenuItem
      Action = aTlRefresh
    end
  end
end
