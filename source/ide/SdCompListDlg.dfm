object CompListDlg: TCompListDlg
  Left = 200
  Top = 120
  ActiveControl = SearchText
  AutoScroll = False
  BorderStyle = bsSizeToolWin
  Caption = 'Components'
  ClientHeight = 262
  ClientWidth = 212
  Color = clWindow
  Constraints.MinHeight = 125
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
    212
    262)
  object xLabel1: TLabel
    Left = 12
    Top = 12
    Width = 87
    Height = 15
    Caption = '&Search by name:'
    FocusControl = SearchText
    Transparent = False
  end
  object ComponentList: TListBox
    Left = 12
    Top = 56
    Width = 188
    Height = 143
    Style = lbOwnerDrawFixed
    Anchors = [akLeft, akTop, akRight]
    IntegralHeight = True
    ItemHeight = 20
    MultiSelect = False
    Sorted = True
    TabOrder = 0
    OnDrawItem = ListDraw
    OnDblClick = ListDblClick
  end
  object SearchText: TEdit
    Left = 12
    Top = 30
    Width = 188
    Height = 23
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 1
    OnChange = SearchChange
    OnKeyDown = SearchKeyDown
  end
  object Actions: TActionList
    Left = 8
    Top = 8
    object aOK: TAction
      Caption = '&Add to form'
      OnExecute = aOKExecute
      OnUpdate = aOKUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 211
    Width = 212
    Height = 51
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    DesignSize = (
      212
      51)
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 212
      Height = 1
      Anchors = [akLeft, akTop, akRight]
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object AddButton: TButton
      Left = 112
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Action = aOK
      Default = True
      TabOrder = 0
    end
  end
end
