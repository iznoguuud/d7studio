object OtaDemoWindow: TOtaDemoWindow
  Left = 320
  Top = 180
  Width = 320
  Height = 440
  Caption = 'OTA Demo'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Splitter: TSplitter
    Left = 0
    Top = 283
    Width = 304
    Height = 3
    Cursor = crVSplit
    Align = alBottom
  end
  object MenuTree: TTreeView
    Left = 0
    Top = 0
    Width = 304
    Height = 283
    Align = alClient
    HideSelection = False
    Indent = 19
    ReadOnly = True
    TabOrder = 0
  end
  object EventList: TListBox
    Left = 0
    Top = 286
    Width = 304
    Height = 82
    Align = alBottom
    ItemHeight = 13
    TabOrder = 1
  end
  object BottomPanel: TPanel
    Left = 0
    Top = 368
    Width = 304
    Height = 33
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 2
    ParentBackground = False
    object RefreshButton: TButton
      Left = 4
      Top = 4
      Width = 75
      Height = 25
      Caption = '&Refresh'
      TabOrder = 0
      OnClick = RefreshButtonClick
    end
  end
end
