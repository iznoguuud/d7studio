object DesktopDeleteDlg: TDesktopDeleteDlg
  Left = 200
  Top = 120
  BorderStyle = bsDialog
  Caption = 'Delete Saved Desktop'
  ClientHeight = 225
  ClientWidth = 343
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
  object xListBox1: TListBox
    Left = 12
    Top = 12
    Width = 319
    Height = 150
    ItemHeight = 13
    MultiSelect = True
    Sorted = True
    TabOrder = 0
  end
  object Actions: TActionList
    Left = 12
    Top = 171
    object aDelete: TAction
      Caption = '&Delete'
      OnExecute = aDeleteExecute
      OnUpdate = aDeleteUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 174
    Width = 343
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 1
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 343
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnDelete: TButton
      Left = 147
      Top = 13
      Width = 88
      Height = 26
      Action = aDelete
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 243
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
