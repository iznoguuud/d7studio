object TransferDlg: TTransferDlg
  Left = 200
  Top = 120
  ActiveControl = ItemList
  BorderStyle = bsDialog
  Caption = 'Tool Options'
  ClientHeight = 395
  ClientWidth = 346
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
    Width = 31
    Height = 15
    Caption = '&Tools:'
    FocusControl = ItemList
  end
  object xLabel2: TLabel
    Left = 17
    Top = 317
    Width = 5
    Height = 15
    Caption = '*'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clRed
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object xLabel3: TLabel
    Left = 31
    Top = 317
    Width = 144
    Height = 15
    Caption = '= conflicting shortcut keys.'
  end
  object ItemList: TListBox
    Left = 12
    Top = 31
    Width = 221
    Height = 283
    Style = lbOwnerDrawFixed
    ItemHeight = 16
    TabOrder = 0
    OnDrawItem = ItemDraw
    OnDblClick = ItemDblClick
  end
  object DnBtn: TBitBtn
    Left = 294
    Top = 144
    Width = 26
    Height = 26
    Action = aDown
    TabOrder = 1
  end
  object UpBtn: TBitBtn
    Left = 260
    Top = 144
    Width = 30
    Height = 26
    Action = aUp
    TabOrder = 2
  end
  object AddButton: TButton
    Left = 246
    Top = 32
    Width = 88
    Height = 26
    Action = aAdd
    TabOrder = 3
  end
  object DelButton: TButton
    Left = 246
    Top = 68
    Width = 88
    Height = 26
    Action = aDelete
    TabOrder = 4
  end
  object EditButton: TButton
    Left = 246
    Top = 104
    Width = 88
    Height = 26
    Action = aEdit
    TabOrder = 5
  end
  object ExportButton: TButton
    Left = 246
    Top = 252
    Width = 88
    Height = 26
    Action = aExport
    TabOrder = 6
  end
  object ImportButton: TButton
    Left = 246
    Top = 288
    Width = 88
    Height = 26
    Action = aImport
    TabOrder = 7
  end
  object Actions: TActionList
    Left = 12
    Top = 259
    object aAdd: TAction
      Caption = '&Add...'
      OnExecute = aAddExecute
    end
    object aDelete: TAction
      Caption = '&Delete'
      OnExecute = aDeleteExecute
      OnUpdate = SelectedUpdate
    end
    object aEdit: TAction
      Caption = '&Edit'
      OnExecute = aEditExecute
      OnUpdate = SelectedUpdate
    end
    object aUp: TAction
      OnExecute = aMoveExecute
      OnUpdate = aMoveUpdate
    end
    object aDown: TAction
      OnExecute = aMoveExecute
      OnUpdate = aMoveUpdate
    end    object aExport: TAction
      Caption = 'E&xport...'
      Hint = 'Save the tools to a file'
      OnExecute = aExportExecute
      OnUpdate = aExportUpdate
    end
    object aImport: TAction
      Caption = '&Import...'
      Hint = 'Add the tools of a file to the list'
      OnExecute = aImportExecute
    end

  end
  object pnlFooter: TPanel
    Left = 0
    Top = 344
    Width = 346
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 8
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 346
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object CloseButton: TButton
      Left = 246
      Top = 13
      Width = 88
      Height = 26
      Cancel = True
      Caption = '&Close'
      ModalResult = 1
      TabOrder = 0
    end
  end
end
