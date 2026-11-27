object FactsFrame: TFactsFrame
  Left = 0
  Top = 0
  Width = 680
  Height = 180
  TabOrder = 0
  object Facts: TListView
    Left = 0
    Top = 0
    Width = 680
    Height = 180
    Align = alClient
    BorderStyle = bsNone
    Columns = <
      item
        Caption = 'What'
        WidthType = (
          -1)
      end
      item
        Caption = 'Value'
        WidthType = (
          -1)
      end>
    ReadOnly = True
    RowSelect = True
    ShowColumnHeaders = False
    TabOrder = 0
    ViewStyle = vsReport
  end
end
