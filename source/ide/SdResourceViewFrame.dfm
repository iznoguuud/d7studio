inherited SdResourceView: TSdResourceView
  Width = 260
  Height = 156
  inherited Header: THeaderControl
    Top = 41
    Width = 258
    Sections = <
      item
        ImageIndex = -1
        MinWidth = 30
        Text = 'Resource'
        Width = 140
      end
      item
        ImageIndex = -1
        MinWidth = 30
        Text = 'Details'
        Width = 118
      end>
  end
  inherited Tree: TTreeView
    Top = 58
    Width = 258
    Height = 97
    HideSelection = False
  end
  object Bar: TToolBar
    Left = 0
    Top = 0
    Width = 260
    Height = 40
    Align = alNone
    ButtonHeight = 38
    ButtonWidth = 50
    Caption = 'Resources'
    EdgeBorders = []
    Flat = True
    ParentShowHint = False
    ShowCaptions = True
    ShowHint = True
    TabOrder = 2
    Wrapable = False
    Transparent = False
    object tbResAdd: TToolButton
      Left = 0
      Top = 0
    end
    object tbResEdit: TToolButton
      Left = 50
      Top = 0
    end
    object tbResDelete: TToolButton
      Left = 100
      Top = 0
    end
    object tbResSep1: TToolButton
      Left = 150
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object tbResExport: TToolButton
      Left = 158
      Top = 0
    end
  end
  object MenuActions: TActionList
    Left = 24
    Top = 32
    object aResEdit: TAction
      Category = 'Resources'
      Caption = 'Edit'
      Hint = 'Edit the resource'
      ImageIndex = 189
    end
    object aResEditHex: TAction
      Category = 'Resources'
      Caption = 'Edit as &Hex...'
      Hint = 'Edit the bytes of the resource'
      ImageIndex = 182
    end
    object aResNewBitmap: TAction
      Category = 'Resources'
      Caption = 'New &Bitmap...'
      Hint = 'A new bitmap'
      ImageIndex = 176
    end
    object aResNewIcon: TAction
      Category = 'Resources'
      Caption = 'New &Icon...'
      Hint = 'A new icon'
      ImageIndex = 177
    end
    object aResNewCursor: TAction
      Category = 'Resources'
      Caption = 'New &Cursor...'
      Hint = 'A new cursor'
      ImageIndex = 178
    end
    object aResNewStrings: TAction
      Category = 'Resources'
      Caption = 'New &String Table...'
      Hint = 'A new string table'
      ImageIndex = 179
    end
    object aResNewManifest: TAction
      Category = 'Resources'
      Caption = 'New &Manifest...'
      Hint = 'A manifest of the projects own'
      ImageIndex = 181
    end
    object aResImport: TAction
      Category = 'Resources'
      Caption = '&Import File...'
      Hint = 'A file as a resource: a bitmap, an icon, a cursor, a manifest, else data'
      ImageIndex = 1
    end
    object aResRename: TAction
      Category = 'Resources'
      Caption = '&Properties...'
      Hint = 'The name, the type and the language of the resource'
      ImageIndex = 16
    end
    object aResDelete: TAction
      Category = 'Resources'
      Caption = 'Delete'
      Hint = 'Delete the resource'
      ImageIndex = 12
    end
    object aResExport: TAction
      Category = 'Resources'
      Caption = 'Export'
      Hint = 'Save the resource as a file'
      ImageIndex = 82
    end
    object aResStatusBar: TAction
      Category = 'Resources'
      Caption = 'Stat&us Bar'
      Hint = 'Show the status bar of the Resources view'
    end
  end
  object ResPopup: TPopupMenu
    Left = 72
    Top = 32
    object pmResEdit: TMenuItem
      Action = aResEdit
      Default = True
    end
    object pmResEditHex: TMenuItem
      Action = aResEditHex
    end
    object pmResAdd: TMenuItem
      Caption = '&Add'
      ImageIndex = 5
      object pmResAddBitmap: TMenuItem
        Action = aResNewBitmap
      end
      object pmResAddIcon: TMenuItem
        Action = aResNewIcon
      end
      object pmResAddCursor: TMenuItem
        Action = aResNewCursor
      end
      object pmResAddStrings: TMenuItem
        Action = aResNewStrings
      end
      object pmResAddManifest: TMenuItem
        Action = aResNewManifest
      end
      object pmResAddN1: TMenuItem
        Caption = '-'
      end
      object pmResAddImport: TMenuItem
        Action = aResImport
      end
    end
    object pmResRename: TMenuItem
      Action = aResRename
    end
    object pmResDelete: TMenuItem
      Action = aResDelete
    end
    object pmResExport: TMenuItem
      Action = aResExport
    end
    object pmResN1: TMenuItem
      Caption = '-'
    end
    object pmResStatusBar: TMenuItem
      Action = aResStatusBar
    end
  end
  object ResAddMenu: TPopupMenu
    Left = 120
    Top = 32
    object raBitmap: TMenuItem
      Action = aResNewBitmap
    end
    object raIcon: TMenuItem
      Action = aResNewIcon
    end
    object raCursor: TMenuItem
      Action = aResNewCursor
    end
    object raStrings: TMenuItem
      Action = aResNewStrings
    end
    object raManifest: TMenuItem
      Action = aResNewManifest
    end
    object raN1: TMenuItem
      Caption = '-'
    end
    object raImport: TMenuItem
      Action = aResImport
    end
  end
end
