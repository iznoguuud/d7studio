object TabOrderDlg: TTabOrderDlg
  Left = 200
  Top = 120
  AutoScroll = False
  BorderIcons = [biSystemMenu]
  Caption = 'Edit Tab Order'
  ClientHeight = 293
  ClientWidth = 307
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
  DesignSize = (
    307
    293)
  object xLabel1: TLabel
    Left = 12
    Top = 12
    Width = 143
    Height = 15
    Caption = '&Controls listed in tab order:'
    FocusControl = TabList
  end
  object TabList: TListBox
    Left = 12
    Top = 30
    Width = 251
    Height = 200
    Anchors = [akLeft, akTop, akRight, akBottom]
    ItemHeight = 13
    TabOrder = 0
  end
  object UpButton: TBitBtn
    Left = 265
    Top = 92
    Width = 30
    Height = 26
    Action = aUp
    Anchors = [akRight]
    TabOrder = 1
    Spacing = -1
  end
  object DownButton: TBitBtn
    Left = 265
    Top = 129
    Width = 30
    Height = 26
    Action = aDown
    Anchors = [akRight]
    TabOrder = 2
    Spacing = 0
  end
  object Actions: TActionList
    Left = 12
    Top = 225
    object aUp: TAction
      OnExecute = aMoveExecute
      OnUpdate = aMoveUpdate
    end
    object aDown: TAction
      OnExecute = aMoveExecute
      OnUpdate = aMoveUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 242
    Width = 307
    Height = 51
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 3
    DesignSize = (
      307
      51)
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 307
      Height = 1
      Anchors = [akLeft, akTop, akRight]
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 111
      Top = 13
      Width = 88
      Height = 26
      Anchors = [akTop, akRight]
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object CancelButton: TButton
      Left = 207
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
