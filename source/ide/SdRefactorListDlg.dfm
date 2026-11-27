object RefactorListDlg: TRefactorListDlg
  Left = 200
  Top = 120
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Refactor'
  ClientHeight = 487
  ClientWidth = 560
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
  object lblItems: TLabel
    Left = 12
    Top = 12
    Width = 34
    Height = 15
    Caption = '&Items:'
    FocusControl = tvItems
  end
  object lblChoice: TLabel
    Left = 12
    Top = 364
    Width = 45
    Height = 15
    Caption = '&Choice:'
    FocusControl = cbChoice
  end
  object tvItems: TTreeView
    Left = 12
    Top = 32
    Width = 536
    Height = 320
    HideSelection = False
    ReadOnly = True
    StateImages = Checks
    TabOrder = 0
    OnKeyDown = tvItemsKeyDown
    OnKeyPress = tvItemsKeyPress
    OnMouseDown = tvItemsMouseDown
  end
  object cbChoice: TComboBox
    Left = 12
    Top = 384
    Width = 260
    Height = 23
    Style = csDropDownList
    ItemHeight = 15
    TabOrder = 1
  end
  object cbCheck: TCheckBox
    Left = 12
    Top = 419
    Width = 536
    Height = 17
    TabOrder = 2
  end
  object Checks: TImageList
    Width = 20
    Left = 40
    Top = 448
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 436
    Width = 560
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 3
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 560
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 364
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = btnOKClick
    end
    object btnCancel: TButton
      Left = 460
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
