object ObjectInspector: TObjectInspector
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Object Inspector'
  ClientHeight = 428
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
  object InstanceBox: TComboBox
    Left = 0
    Top = 0
    Width = 232
    Height = 23
    Style = csOwnerDrawFixed
    DropDownCount = 16
    ItemHeight = 17
    Sorted = True
    TabOrder = 0
    TabStop = False
    OnCloseUp = InstanceCloseUp
    OnDrawItem = InstanceDrawItem
    OnDropDown = InstanceDropDown
    OnSelect = InstanceSelect
  end
  object MenuActions: TActionList
    Left = 24
    Top = 32
    object aOIViewAll: TAction
      Category = 'Inspector'
      Caption = 'All'
      Hint = 'Show the properties of every category'
    end
    object aOIViewToggle: TAction
      Category = 'Inspector'
      Caption = 'Toggle'
      Hint = 'Show the categories that are hidden and hide the others'
    end
    object aOIViewNone: TAction
      Category = 'Inspector'
      Caption = 'None'
      Hint = 'Hide the properties of every category'
    end
    object aOIArrangeCategory: TAction
      Category = 'Inspector'
      Caption = 'by &Category'
      Hint = 'Arrange the properties by category'
    end
    object aOIArrangeName: TAction
      Category = 'Inspector'
      Caption = 'by &Name'
      Checked = True
      Hint = 'Arrange the properties by name'
    end
    object aOIRevert: TAction
      Category = 'Inspector'
      Caption = '&Revert to inherited'
      Hint = 'Give the property the value of the ancestor form'
    end
    object aOIExpand: TAction
      Category = 'Inspector'
      Caption = 'E&xpand'
      Hint = 'Expand the selected property'
    end
    object aOICollapse: TAction
      Category = 'Inspector'
      Caption = '&Collapse'
      Hint = 'Collapse the selected property'
    end
    object aOIProperties: TAction
      Category = 'Inspector'
      Caption = 'Properties'
      Hint = 'The options of the Object Inspector'
    end
  end
  object InspPopup: TPopupMenu
    Left = 72
    Top = 32
    object pmInsp1: TMenuItem
      Caption = '&View'
      object pmInspViewBar: TMenuItem
        Caption = '-'
      end
      object pmInsp2: TMenuItem
        Action = aOIViewAll
      end
      object pmInsp3: TMenuItem
        Action = aOIViewToggle
      end
      object pmInsp4: TMenuItem
        Action = aOIViewNone
      end
    end
    object pmInsp5: TMenuItem
      Caption = '&Arrange'
      object pmInsp6: TMenuItem
        Action = aOIArrangeCategory
        RadioItem = True
      end
      object pmInsp7: TMenuItem
        Action = aOIArrangeName
        RadioItem = True
      end
    end
    object pmInsp8: TMenuItem
      Caption = '-'
    end
    object pmInsp9: TMenuItem
      Action = aOIRevert
    end
    object pmInsp10: TMenuItem
      Action = aOIExpand
    end
    object pmInsp11: TMenuItem
      Action = aOICollapse
    end
    object pmInsp13: TMenuItem
    end
    object pmInsp14: TMenuItem
    end
    object pmInsp15: TMenuItem
      Caption = '-'
    end
    object pmInsp16: TMenuItem
      Action = aOIProperties
    end
  end
end
