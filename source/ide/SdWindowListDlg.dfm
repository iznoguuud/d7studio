object WindowListDlg: TWindowListDlg
  Left = 200
  Top = 120
  HorzScrollBar.Visible = False
  VertScrollBar.Visible = False
  ActiveControl = WindowListBox
  AutoScroll = False
  BorderIcons = [biSystemMenu]
  Caption = 'Window List'
  ClientHeight = 216
  ClientWidth = 300
  Color = clWindow
  Constraints.MinHeight = 100
  Constraints.MinWidth = 260
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
  DesignSize = (
    300
    216)
  object WindowListBox: TListBox
    Left = 12
    Top = 12
    Width = 276
    Height = 141
    Anchors = [akLeft, akTop, akRight, akBottom]
    ItemHeight = 13
    TabOrder = 0
    OnDblClick = ListDblClick
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
    Top = 165
    Width = 300
    Height = 51
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 1
    DesignSize = (
      300
      51)
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 300
      Height = 1
      Anchors = [akLeft, akTop, akRight]
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 104
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Action = aOK
      Default = True
      TabOrder = 0
    end
    object CancelButton: TButton
      Left = 200
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
