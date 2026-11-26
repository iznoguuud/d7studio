object MigrateDlg: TMigrateDlg
  Left = 200
  Top = 120
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Migrate from Delphi 7'
  ClientHeight = 561
  ClientWidth = 560
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
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  object lblNote: TLabel
    Left = 12
    Top = 468
    Width = 536
    Height = 30
    AutoSize = False
    Caption =
      'Delphi 7'#39's values replace D7 Studio'#39's; library folders, packages, ' +
      'experts, tools and history lists are merged.'
    WordWrap = True
  end
  object gbParts: TGroupBox
    Left = 12
    Top = 12
    Width = 536
    Height = 414
    Caption = 'Migrate'
    TabOrder = 0
    object tvParts: TTreeView
      Left = 9
      Top = 20
      Width = 518
      Height = 384
      Anchors = [akLeft, akTop, akRight, akBottom]
      HideSelection = False
      ReadOnly = True
      StateImages = Checks
      TabOrder = 0
      OnKeyDown = tvPartsKeyDown
      OnKeyPress = tvPartsKeyPress
      OnMouseDown = tvPartsMouseDown
    end
  end
  object mmReport: TMemo
    Left = 12
    Top = 274
    Width = 536
    Height = 158
    ReadOnly = True
    ScrollBars = ssBoth
    TabOrder = 1
    Visible = False
    WordWrap = False
  end
  object cbOverwrite: TCheckBox
    Left = 12
    Top = 442
    Width = 536
    Height = 19
    Caption = '&Replace D7 Studio'#39's menu templates with Delphi 7'#39's'
    TabOrder = 2
  end
  object Checks: TImageList
    Width = 20
    Left = 12
    Top = 506
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 510
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
    object btnMigrate: TButton
      Left = 364
      Top = 13
      Width = 88
      Height = 26
      Caption = '&Migrate'
      Default = True
      TabOrder = 0
      OnClick = btnMigrateClick
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
