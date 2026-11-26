object InspectorView: TSdInspectorView
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Debug Inspector'
  ClientHeight = 600
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
  object ExprBox: TComboBox
    Left = 0
    Top = 0
    Width = 232
    Height = 23
    ItemHeight = 15
    TabOrder = 0
    OnKeyDown = ExprKeyDown
    OnSelect = ExprSelect
  end
  object RowList: TListBox
    Left = 1
    Top = 67
    Width = 230
    Height = 509
    Style = lbOwnerDrawFixed
    BorderStyle = bsNone
    IntegralHeight = False
    ItemHeight = 17
    TabOrder = 1
    OnClick = ListClick
    OnDblClick = ListDblClick
    OnDrawItem = ListDrawItem
  end
  object MenuActions: TActionList
    Left = 24
    Top = 32
    object aDiChange: TAction
      Category = 'Debug Inspector'
      Caption = '&Change...'
      Hint = 'Change the value of the selected item'
    end
    object aDiSortDecl: TAction
      Category = 'Debug Inspector'
      Caption = '&Declaration Order'
      Hint = 'Show the items in the order of their declaration'
    end
    object aDiSortName: TAction
      Category = 'Debug Inspector'
      Caption = '&Name'
      Hint = 'Show the items sorted by name'
    end
    object aDiDynamic: TAction
      Category = 'Debug Inspector'
      Caption = '&Show Dynamic Properties'
      Hint = 'Show the properties that are read by a method'
    end
    object aDiInspect: TAction
      Category = 'Debug Inspector'
      Caption = '&Inspect'
      Hint = 'Inspect the selected item'
    end
    object aDiDescend: TAction
      Category = 'Debug Inspector'
      Caption = '&Descend'
      Hint = 'Inspect the selected item in place of the expression'
    end
    object aDiNewExpr: TAction
      Category = 'Debug Inspector'
      Caption = '&New Expression...'
      Hint = 'Inspect another expression'
    end
    object aDiTypeCast: TAction
      Category = 'Debug Inspector'
      Caption = '&Type Cast...'
      Hint = 'Inspect the expression as another type'
    end
  end
  object DebugInspPopup: TPopupMenu
    Left = 72
    Top = 32
    object pmDi1: TMenuItem
      Action = aDiChange
    end
    object pmDi2: TMenuItem
      Caption = 'Sort &By'
      object pmDi2Decl: TMenuItem
        Action = aDiSortDecl
        GroupIndex = 1
        RadioItem = True
      end
      object pmDi2Name: TMenuItem
        Action = aDiSortName
        GroupIndex = 1
        RadioItem = True
      end
    end
    object pmDi3: TMenuItem
      Action = aDiDynamic
    end
    object pmDi4: TMenuItem
      Caption = '-'
    end
    object pmDi5: TMenuItem
      Action = aDiInspect
    end
    object pmDi6: TMenuItem
      Action = aDiDescend
    end
    object pmDi7: TMenuItem
      Caption = '-'
    end
    object pmDi8: TMenuItem
      Action = aDiNewExpr
    end
    object pmDi9: TMenuItem
      Action = aDiTypeCast
    end
  end
end
