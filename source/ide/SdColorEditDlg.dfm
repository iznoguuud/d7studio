object ColorEditDlg: TColorEditDlg
  Left = 200
  Top = 120
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Edit Colour'
  ClientHeight = 214
  ClientWidth = 330
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
  object lblRed: TLabel
    Left = 12
    Top = 15
    Width = 40
    Height = 15
    Caption = '&Red:'
    FocusControl = edRed
  end
  object edRed: TEdit
    Left = 70
    Top = 12
    Width = 44
    Height = 23
    Text = '0'
    OnChange = ChannelChange
    TabOrder = 0
  end
  object udRed: TUpDown
    Left = 114
    Top = 12
    Width = 16
    Height = 23
    Associate = edRed
    Min = 0
    Max = 255
    Position = 0
    TabOrder = 1
    Thousands = False
  end
  object lblGreen: TLabel
    Left = 12
    Top = 44
    Width = 40
    Height = 15
    Caption = '&Green:'
    FocusControl = edGreen
  end
  object edGreen: TEdit
    Left = 70
    Top = 41
    Width = 44
    Height = 23
    Text = '0'
    OnChange = ChannelChange
    TabOrder = 2
  end
  object udGreen: TUpDown
    Left = 114
    Top = 41
    Width = 16
    Height = 23
    Associate = edGreen
    Min = 0
    Max = 255
    Position = 0
    TabOrder = 3
    Thousands = False
  end
  object lblBlue: TLabel
    Left = 12
    Top = 73
    Width = 40
    Height = 15
    Caption = '&Blue:'
    FocusControl = edBlue
  end
  object edBlue: TEdit
    Left = 70
    Top = 70
    Width = 44
    Height = 23
    Text = '0'
    OnChange = ChannelChange
    TabOrder = 4
  end
  object udBlue: TUpDown
    Left = 114
    Top = 70
    Width = 16
    Height = 23
    Associate = edBlue
    Min = 0
    Max = 255
    Position = 0
    TabOrder = 5
    Thousands = False
  end
  object lblAlpha: TLabel
    Left = 12
    Top = 102
    Width = 40
    Height = 15
    Caption = '&Alpha:'
    FocusControl = edAlpha
  end
  object edAlpha: TEdit
    Left = 70
    Top = 99
    Width = 44
    Height = 23
    Text = '0'
    OnChange = ChannelChange
    TabOrder = 6
  end
  object udAlpha: TUpDown
    Left = 114
    Top = 99
    Width = 16
    Height = 23
    Associate = edAlpha
    Min = 0
    Max = 255
    Position = 0
    TabOrder = 7
    Thousands = False
  end
  object lblHex: TLabel
    Left = 12
    Top = 131
    Width = 26
    Height = 15
    Caption = '&Hex:'
    FocusControl = edHex
  end
  object edHex: TEdit
    Left = 70
    Top = 128
    Width = 82
    Height = 23
    CharCase = ecUpperCase
    MaxLength = 9
    OnChange = edHexChange
    TabOrder = 8
  end
  object pbSample: TPaintBox
    Left = 170
    Top = 12
    Width = 148
    Height = 76
    OnPaint = pbSamplePaint
  end
  object btnMore: TButton
    Left = 170
    Top = 98
    Width = 148
    Height = 26
    Caption = '&Windows Colours...'
    TabOrder = 9
    OnClick = btnMoreClick
  end
  object ColorDialog: TColorDialog
    Ctl3D = True
    Options = [cdFullOpen]
    Left = 60
    Top = 168
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 163
    Width = 330
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 10
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 330
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 134
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 230
      Top = 13
      Width = 88
      Height = 26
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
end
