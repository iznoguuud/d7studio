object ListEditDlg: TListEditDlg
  Left = 200
  Top = 120
  AutoScroll = False
  BorderIcons = [biSystemMenu]
  Caption = 'OrderedListEditDlg'
  ClientHeight = 344
  ClientWidth = 448
  Color = clWindow
  Constraints.MinHeight = 307
  Constraints.MinWidth = 405
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
    448
    344)
  object InvalidPathLbl: TLabel
    Left = 12
    Top = 197
    Width = 177
    Height = 15
    Anchors = [akLeft, akBottom]
    Caption = 'Greyed items denote invalid path.'
  end
  object CreationList: TListBox
    Left = 12
    Top = 12
    Width = 374
    Height = 176
    Anchors = [akLeft, akTop, akRight, akBottom]
    ItemHeight = 13
    TabOrder = 0
    Style = lbOwnerDrawFixed
    OnDrawItem = ListDrawItem
    OnClick = ListClick
  end
  object UpButton: TBitBtn
    Left = 398
    Top = 95
    Width = 30
    Height = 26
    Action = aUp
    Anchors = [akRight]
    TabOrder = 1
    Spacing = -1
  end
  object DownButton: TBitBtn
    Left = 398
    Top = 135
    Width = 30
    Height = 26
    Action = aDown
    Anchors = [akRight]
    TabOrder = 2
    Spacing = 0
  end
  object ElementEdit: TEdit
    Left = 12
    Top = 218
    Width = 343
    Height = 23
    Anchors = [akLeft, akRight, akBottom]
    TabOrder = 3
  end
  object ReplaceButton: TButton
    Left = 14
    Top = 255
    Width = 88
    Height = 26
    Action = aReplace
    Anchors = [akRight, akBottom]
    TabOrder = 4
  end
  object AddButton: TButton
    Left = 111
    Top = 255
    Width = 88
    Height = 26
    Action = aAdd
    Anchors = [akRight, akBottom]
    TabOrder = 5
  end
  object DeleteButton: TButton
    Left = 208
    Top = 255
    Width = 88
    Height = 26
    Action = aDelete
    Anchors = [akRight, akBottom]
    TabOrder = 6
  end
  object BrowseButton: TButton
    Left = 366
    Top = 218
    Width = 24
    Height = 23
    Action = aBrowse
    Anchors = [akRight, akBottom]
    TabOrder = 7
  end
  object DeleteInvalidBtn: TButton
    Left = 299
    Top = 255
    Width = 137
    Height = 26
    Action = aDeleteInvalid
    Anchors = [akRight, akBottom]
    TabOrder = 8
  end
  object Actions: TActionList
    Left = 12
    Top = 253
    object aReplace: TAction
      Caption = '&Replace'
      OnExecute = aReplaceExecute
      OnUpdate = aReplaceUpdate
    end
    object aAdd: TAction
      Caption = '&Add'
      OnExecute = aAddExecute
      OnUpdate = aAddUpdate
    end
    object aDelete: TAction
      Caption = '&Delete'
      OnExecute = aDeleteExecute
      OnUpdate = aDeleteUpdate
    end
    object aBrowse: TAction
      Caption = '...'
      OnExecute = aBrowseExecute
    end
    object aDeleteInvalid: TAction
      Caption = 'Delete Invalid &Paths'
      OnExecute = aDeleteInvalidExecute
      OnUpdate = aDeleteInvalidUpdate
    end
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
    Top = 293
    Width = 448
    Height = 51
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 9
    DesignSize = (
      448
      51)
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 448
      Height = 1
      Anchors = [akLeft, akTop, akRight]
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 252
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
      Left = 348
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
