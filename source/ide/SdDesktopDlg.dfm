object DesktopDlg: TDesktopDlg
  Left = 200
  Top = 120
  BorderStyle = bsDialog
  Caption = 'Save Desktop'
  ClientHeight = 118
  ClientWidth = 305
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
    Width = 127
    Height = 15
    Caption = '&Save current desktop as:'
    FocusControl = cbDesktopName
  end
  object cbDesktopName: TComboBox
    Left = 12
    Top = 32
    Width = 281
    Height = 23
    ItemHeight = 0
    Sorted = True
    TabOrder = 0
  end
  object Actions: TActionList
    Left = 8
    Top = 68
    object aOK: TAction
      Caption = 'OK'
      OnExecute = aOKExecute
      OnUpdate = aOKUpdate
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 67
    Width = 305
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 1
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 305
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 109
      Top = 13
      Width = 88
      Height = 26
      Action = aOK
      Default = True
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 205
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
