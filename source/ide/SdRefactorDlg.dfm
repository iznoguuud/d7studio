object RefactorDlg: TRefactorDlg
  Left = 200
  Top = 120
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Refactor'
  ClientHeight = 355
  ClientWidth = 380
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Position = poOwnerFormCenter
  PixelsPerInch = 96
  TextHeight = 15
  OnCreate = FormCreate
  object lblName: TLabel
    Left = 12
    Top = 12
    Width = 35
    Height = 15
    Caption = '&Name:'
    FocusControl = edName
  end
  object lblType: TLabel
    Left = 12
    Top = 67
    Width = 28
    Height = 15
    Caption = '&Type:'
    FocusControl = edType
  end
  object lblAccess: TLabel
    Left = 12
    Top = 122
    Width = 52
    Height = 15
    Caption = '&Visibility:'
    FocusControl = cbAccess
  end
  object lblChoice: TLabel
    Left = 12
    Top = 177
    Width = 45
    Height = 15
    Caption = '&Choice:'
    FocusControl = cbChoice
  end
  object lblValue: TLabel
    Left = 12
    Top = 232
    Width = 31
    Height = 15
    Caption = 'Value:'
    FocusControl = edValue
  end
  object edName: TEdit
    Left = 12
    Top = 32
    Width = 356
    Height = 23
    TabOrder = 0
  end
  object edType: TEdit
    Left = 12
    Top = 87
    Width = 356
    Height = 23
    TabOrder = 1
  end
  object cbAccess: TComboBox
    Left = 12
    Top = 142
    Width = 356
    Height = 23
    Style = csDropDownList
    ItemHeight = 15
    TabOrder = 2
    Items.Strings = (
      'published'
      'private'
      'protected'
      'public')
  end
  object cbChoice: TComboBox
    Left = 12
    Top = 197
    Width = 356
    Height = 23
    Style = csDropDownList
    ItemHeight = 15
    TabOrder = 3
  end
  object edValue: TEdit
    Left = 12
    Top = 252
    Width = 356
    Height = 23
    ReadOnly = True
    TabOrder = 4
  end
  object cbCheck: TCheckBox
    Left = 12
    Top = 287
    Width = 356
    Height = 17
    Caption = 'Replace every occurrence in the routine'
    TabOrder = 5
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 304
    Width = 380
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 6
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 380
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 184
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 280
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
