object NewItemsDlg: TNewItemsDlg
  Left = 200
  Top = 120
  AutoScroll = False
  BorderIcons = [biSystemMenu]
  Caption = 'New Items'
  ClientHeight = 415
  ClientWidth = 521
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Position = poOwnerFormCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15
  DesignSize = (
    521
    415)
  object TabControl: TTabControl
    Left = 12
    Top = 12
    Width = 497
    Height = 340
    Anchors = [akLeft, akTop, akRight, akBottom]
    HotTrack = True
    MultiLine = True
    TabOrder = 0
    Tabs.Strings = (
      'New')
    TabIndex = 0
    OnChange = TabControlChange
    object xPanel1: TPanel
      Left = 4
      Top = 311
      Width = 489
      Height = 25
      Align = alBottom
      BevelOuter = bvNone
      ParentColor = True
      TabOrder = 0
      object RReference: TRadioButton
        Left = 151
        Top = 6
        Width = 82
        Height = 19
        Hint = 'Add Object to Project'
        Caption = '&Use'
        Enabled = False
        ParentShowHint = False
        ShowHint = True
        TabOrder = 0
      end
      object RInherit: TRadioButton
        Left = 81
        Top = 6
        Width = 68
        Height = 19
        Hint = 'Make an Inherited Form from Object'
        Caption = '&Inherit'
        Enabled = False
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
      end
      object RCopy: TRadioButton
        Left = 11
        Top = 6
        Width = 63
        Height = 19
        Hint = 'Make a copy of Object'
        Caption = '&Copy'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 2
        Checked = True
      end
    end
    object ItemList: TListView
      Left = 4
      Top = 26
      Width = 489
      Height = 285
      Align = alClient
      BorderStyle = bsNone
      Columns = <>
      HideSelection = False
      IconOptions.AutoArrange = True
      ReadOnly = True
      SortType = stText
      TabOrder = 1
      OnDblClick = ItemDblClick
      OnSelectItem = ItemSelect
    end
  end
  object Actions: TActionList
    Left = 8
    Top = 8
    object aOK: TAction
      Caption = 'OK'
      OnExecute = aOKExecute
      OnUpdate = aOKUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 364
    Width = 521
    Height = 51
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 1
    DesignSize = (
      521
      51)
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 521
      Height = 1
      Anchors = [akLeft, akTop, akRight]
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 325
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Action = aOK
      Default = True
      TabOrder = 0
    end
    object CancelButton: TButton
      Left = 421
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
