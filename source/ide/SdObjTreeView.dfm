object ObjTreeView: TObjTreeView
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Object TreeView'
  ClientHeight = 200
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
  object Tree: TTreeView
    Left = 0
    Top = 0
    Width = 232
    Height = 200
    Align = alClient
    HideSelection = False
    Indent = 19
    PopupMenu = ObjTreePopup
    ReadOnly = True
    TabOrder = 0
    OnChange = TreeChange
    OnDblClick = TreeDblClick
    OnKeyDown = TreeKeyDown
  end
  object Actions: TActionList
    Left = 16
    Top = 16
    object aObjTreeAdd: TAction
      Category = 'Design'
      Caption = '&Add Item'
      Hint = 'Add an item to the selected collection or menu'
      ImageIndex = 0
      OnExecute = CommandExecute
    end
    object aObjTreeDelete: TAction
      Category = 'Design'
      Caption = '&Delete'
      Hint = 'Delete the selected item'
      ImageIndex = 12
      OnExecute = CommandExecute
    end
  end
  object ObjTreePopup: TPopupMenu
    OnPopup = ObjTreePopupPopup
    Left = 64
    Top = 16
    object pmObjTreeHide: TMenuItem
      Caption = '&Hide'
    end
    object pmObjTreeHelp: TMenuItem
      Caption = '&Help'
    end
    object pmObjTreeLine: TMenuItem
      Caption = '-'
    end
    object pmObjTreeAdd: TMenuItem
      Action = aObjTreeAdd
    end
    object pmObjTreeDelete: TMenuItem
      Action = aObjTreeDelete
    end
  end
end