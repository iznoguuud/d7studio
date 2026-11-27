object PanelForm: TPanelForm
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Embedded form'
  ClientHeight = 156
  ClientWidth = 268
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15
  object DpiLabel: TLabel
    Left = 0
    Top = 0
    Width = 236
    Height = 15
    Anchors = [akLeft, akTop, akRight]
    Caption = 'This form is at 96 DPI (its PixelsPerInch).'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object NameEdit: TEdit
    Left = 0
    Top = 24
    Width = 268
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
    Text = 'A form inside a panel follows its host'
  end
  object Kind: TComboBox
    Left = 0
    Top = 56
    Width = 128
    Height = 23
    Anchors = [akLeft, akTop]
    Style = csDropDownList
    ItemHeight = 15
    TabOrder = 1
    Items.Strings = (
      'A combo box'
      'its list rows'
      'follow the DPI')
  end
  object Level: TTrackBar
    Left = 136
    Top = 52
    Width = 132
    Height = 30
    Anchors = [akTop, akRight]
    Max = 10
    Position = 4
    TabOrder = 2
    ThumbLength = 18
  end
  object Options: TCheckListBox
    Left = 0
    Top = 88
    Width = 268
    Height = 68
    Anchors = [akLeft, akTop, akRight, akBottom]
    BorderStyle = bsNone
    ItemHeight = 15
    Items.Strings = (
      'Check boxes follow the DPI'
      'of the form they are on')
    TabOrder = 3
  end
end
