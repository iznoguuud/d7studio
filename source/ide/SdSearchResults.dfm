object SearchResultsView: TSearchResultsView
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Search Results'
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
  object SearchList: TListBox
    Left = 0
    Top = 0
    Width = 590
    Height = 111
    Align = alClient
    Style = lbOwnerDrawFixed
    ItemHeight = 15
    TabOrder = 0
    OnDblClick = SearchListDblClick
    OnDrawItem = SearchListDrawItem
  end
end
