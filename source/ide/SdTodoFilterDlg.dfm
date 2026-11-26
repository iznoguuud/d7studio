object TodoFilterDlg: TTodoFilterDlg
  Left = 200
  Top = 120
  BorderStyle = bsDialog
  Caption = 'Filter To-Do List'
  ClientHeight = 361
  ClientWidth = 320
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
  object xLabel1: TLabel
    Left = 12
    Top = 12
    Width = 34
    Height = 15
    Caption = 'Label1'
    FocusControl = CheckList
  end
  object CheckList: TCheckListBox
    Left = 12
    Top = 30
    Width = 296
    Height = 268
    ItemHeight = 13
    Sorted = True
    TabOrder = 0
  end
  object Actions: TActionList
    Left = 12
    Top = 245
    object aShowAll: TAction
      Caption = 'Show &All'
      OnExecute = aShowAllExecute
      OnUpdate = aShowAllUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 310
    Width = 320
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 1
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 320
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnShowAll: TButton
      Left = 12
      Top = 13
      Width = 88
      Height = 26
      Action = aShowAll
      TabOrder = 0
    end
    object btnOK: TButton
      Left = 124
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 1
    end
    object btnCancel: TButton
      Left = 220
      Top = 13
      Width = 88
      Height = 26
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 2
    end
  end
end
