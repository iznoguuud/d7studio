object NewImageDlg: TNewImageDlg
  Left = 200
  Top = 120
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'New Image'
  ClientHeight = 297
  ClientWidth = 346
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15
  object lblSizes: TLabel
    Left = 12
    Top = 12
    Width = 29
    Height = 15
    Caption = '&Sizes:'
    FocusControl = clbSizes
  end
  object clbSizes: TCheckListBox
    Left = 12
    Top = 30
    Width = 134
    Height = 172
    ItemHeight = 15
    TabOrder = 0
  end
  object cbOther: TCheckBox
    Left = 12
    Top = 213
    Width = 62
    Height = 19
    Caption = '&Other:'
    TabOrder = 1
  end
  object edOtherW: TEdit
    Left = 76
    Top = 211
    Width = 44
    Height = 23
    Text = '64'
    TabOrder = 2
  end
  object udOtherW: TUpDown
    Left = 120
    Top = 211
    Width = 16
    Height = 23
    Associate = edOtherW
    Min = 1
    Max = 256
    Position = 64
    TabOrder = 3
    Thousands = False
  end
  object lblBy: TLabel
    Left = 141
    Top = 215
    Width = 6
    Height = 15
    Caption = 'x'
  end
  object edOtherH: TEdit
    Left = 152
    Top = 211
    Width = 44
    Height = 23
    Text = '64'
    TabOrder = 4
  end
  object udOtherH: TUpDown
    Left = 196
    Top = 211
    Width = 16
    Height = 23
    Associate = edOtherH
    Min = 1
    Max = 256
    Position = 64
    TabOrder = 5
    Thousands = False
  end
  object lblWidth: TLabel
    Left = 12
    Top = 16
    Width = 38
    Height = 15
    Caption = '&Width:'
    FocusControl = edWidth
  end
  object edWidth: TEdit
    Left = 84
    Top = 12
    Width = 61
    Height = 23
    Text = '32'
    TabOrder = 6
  end
  object udWidth: TUpDown
    Left = 145
    Top = 12
    Width = 16
    Height = 23
    Associate = edWidth
    Min = 1
    Max = 4096
    Position = 32
    TabOrder = 7
    Thousands = False
  end
  object lblHeight: TLabel
    Left = 12
    Top = 45
    Width = 42
    Height = 15
    Caption = '&Height:'
    FocusControl = edHeight
  end
  object edHeight: TEdit
    Left = 84
    Top = 41
    Width = 61
    Height = 23
    Text = '32'
    TabOrder = 8
  end
  object udHeight: TUpDown
    Left = 145
    Top = 41
    Width = 16
    Height = 23
    Associate = edHeight
    Min = 1
    Max = 4096
    Position = 32
    TabOrder = 9
    Thousands = False
  end
  object lblColors: TLabel
    Left = 164
    Top = 12
    Width = 44
    Height = 15
    Caption = '&Colours:'
    FocusControl = cbColors
  end
  object cbColors: TComboBox
    Left = 164
    Top = 30
    Width = 170
    Height = 23
    Style = csDropDownList
    ItemHeight = 15
    TabOrder = 10
  end
  object rbEmpty: TRadioButton
    Left = 164
    Top = 68
    Width = 170
    Height = 19
    Caption = '&Empty'
    TabOrder = 11
  end
  object rbScaled: TRadioButton
    Left = 164
    Top = 90
    Width = 170
    Height = 19
    Caption = 'The image shown, &scaled'
    TabOrder = 12
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 246
    Width = 346
    Height = 51
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 13
    DesignSize = (
      346
      51)
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 346
      Height = 1
      Anchors = [akLeft, akTop, akRight]
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 150
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 246
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
end
