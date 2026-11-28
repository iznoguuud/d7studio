object OptionsDlg: TOptionsDlg
  Left = 200
  Top = 120
  ActiveControl = PageTree
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Options'
  ClientHeight = 522
  ClientWidth = 859
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
  object pnlTree: TPanel
    Left = 0
    Top = 0
    Width = 214
    Height = 471
    Anchors = [akLeft, akTop, akBottom]
    BevelOuter = bvNone
    Color = clWindow
    ParentBackground = False
    TabOrder = 0
    object PageTree: TTreeView
      Left = 12
      Top = 12
      Width = 190
      Height = 447
      BorderStyle = bsNone
      HideSelection = False
      Indent = 19
      ReadOnly = True
      RowSelect = True
      ShowLines = False
      TabOrder = 0
      OnChange = PageTreeChange
      OnExpanding = PageTreeExpanding
    end
  end
  object lnTree: TShape
    Left = 214
    Top = 0
    Width = 1
    Height = 471
    Anchors = [akLeft, akTop, akBottom]
    Brush.Color = clBtnShadow
    Pen.Color = clBtnShadow
  end
  object pnlTitle: TPanel
    Left = 215
    Top = 0
    Width = 644
    Height = 52
    Anchors = [akLeft, akTop, akRight]
    BevelOuter = bvNone
    Color = clWindow
    ParentBackground = False
    TabOrder = 3
    object lblSection: TLabel
      Left = 12
      Top = 12
      Width = 190
      Height = 27
      Caption = 'Environment Options'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -20
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ShowAccelChar = False
    end
    object lblPage: TLabel
      Left = 216
      Top = 12
      Width = 101
      Height = 27
      Caption = 'Preferences'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -20
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ShowAccelChar = False
    end
    object lnTitle: TShape
      Left = 0
      Top = 51
      Width = 644
      Height = 1
      Align = alBottom
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
  end
  object PageArea: TPanel
    Left = 218
    Top = 54
    Width = 638
    Height = 414
    BevelOuter = bvNone
    TabOrder = 1
    ParentColor = True
    ParentBackground = False
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 471
    Width = 859
    Height = 51
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    DesignSize = (
      859
      51)
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 859
      Height = 1
      Anchors = [akLeft, akTop, akRight]
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 663
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 759
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
