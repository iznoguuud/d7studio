object ResPropsDlg: TResPropsDlg
  Left = 200
  Top = 120
  ActiveControl = edName
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Resource Properties'
  ClientHeight = 156
  ClientWidth = 340
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poOwnerFormCenter
  PixelsPerInch = 96
  TextHeight = 15
  OnCreate = FormCreate
  object lblType: TLabel
    Left = 12
    Top = 15
    Width = 29
    Height = 15
    Caption = '&Type:'
    FocusControl = cbType
  end
  object lblName: TLabel
    Left = 12
    Top = 44
    Width = 35
    Height = 15
    Caption = '&Name:'
    FocusControl = edName
  end
  object lblLanguage: TLabel
    Left = 12
    Top = 73
    Width = 55
    Height = 15
    Caption = '&Language:'
    FocusControl = cbLanguage
  end
  object cbType: TComboBox
    Left = 84
    Top = 12
    Width = 244
    Height = 23
    ItemHeight = 15
    TabOrder = 0
    Items.Strings = (
      'RCDATA'
      'HTML'
      'Font'
      'Message Table'
      'Animated Cursor'
      'Animated Icon')
  end
  object edName: TEdit
    Left = 84
    Top = 41
    Width = 244
    Height = 23
    CharCase = ecUpperCase
    TabOrder = 1
  end
  object cbLanguage: TComboBox
    Left = 84
    Top = 70
    Width = 244
    Height = 23
    Style = csDropDownList
    DropDownCount = 16
    ItemHeight = 15
    TabOrder = 2
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 105
    Width = 340
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 3
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 340
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 144
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 240
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
