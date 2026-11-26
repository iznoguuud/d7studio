object NavigationBar: TNavigationBar
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Navigation Bar'
  ClientHeight = 23
  ClientWidth = 480
  Color = clBtnFace
  DefaultMonitor = dmDesktop
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  ShowHint = True
  OnResize = FormResize
  PixelsPerInch = 96
  TextHeight = 15
  object ClassBox: TComboBox
    Left = 0
    Top = 0
    Width = 158
    Height = 23
    Hint = 'Classes'
    Style = csOwnerDrawFixed
    DropDownCount = 24
    ItemHeight = 17
    TabOrder = 0
    TabStop = False
    OnCloseUp = BoxCloseUp
    OnDrawItem = BoxDrawItem
    OnDropDown = BoxDropDown
    OnSelect = ClassBoxSelect
  end
  object MethodBox: TComboBox
    Left = 162
    Top = 0
    Width = 318
    Height = 23
    Hint = 'Methods and functions'
    Style = csOwnerDrawFixed
    DropDownCount = 24
    ItemHeight = 17
    TabOrder = 1
    TabStop = False
    OnCloseUp = BoxCloseUp
    OnDrawItem = BoxDrawItem
    OnDropDown = BoxDropDown
    OnSelect = MethodBoxSelect
  end
end
