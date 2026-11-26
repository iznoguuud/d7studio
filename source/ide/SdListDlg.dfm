object ListDlg: TListDlg
  Left = 200
  Top = 120
  ActiveControl = lbItems
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'List'
  ClientHeight = 338
  ClientWidth = 322
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
  object lbItems: TListBox
    Left = 12
    Top = 12
    Width = 298
    Height = 263
    ItemHeight = 15
    TabOrder = 0
    OnDblClick = lbItemsDblClick
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
    Top = 287
    Width = 322
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 1
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 322
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 126
      Top = 13
      Width = 88
      Height = 26
      Action = aOK
      Default = True
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 222
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
