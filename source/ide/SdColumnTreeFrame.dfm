inherited SdColumnTree: TSdColumnTree
  Width = 232
  Height = 200
  object Header: THeaderControl
    Left = 1
    Top = 1
    Width = 230
    Height = 17
    Align = alNone
    Sections = <
      item
        ImageIndex = -1
        MinWidth = 30
        Width = 100
      end
      item
        ImageIndex = -1
        MinWidth = 30
        Width = 130
      end>
    OnSectionResize = HeaderResize
    OnSectionTrack = HeaderTrack
  end
  object Tree: TTreeView
    Left = 1
    Top = 18
    Width = 230
    Height = 181
    BorderStyle = bsNone
    Indent = 19
    ReadOnly = True
    TabOrder = 1
  end
end
