object ExceptRangeDlg: TExceptRangeDlg
  Left = 200
  Top = 120
  BorderStyle = bsDialog
  Caption = 'Add Exception Range'
  ClientHeight = 170
  ClientWidth = 234
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
  object xPanel1: TPanel
    Left = 0
    Top = 0
    Width = 234
    Height = 119
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 0
    ParentBackground = False
    object LowLabel: TLabel
      Left = 12
      Top = 12
      Width = 61
      Height = 15
      Caption = 'Range &Low:'
      FocusControl = LowEdit
    end
    object HighLabel: TLabel
      Left = 12
      Top = 66
      Width = 65
      Height = 15
      Caption = '&Range High:'
      FocusControl = HighEdit
    end
    object LowEdit: TEdit
      Left = 12
      Top = 30
      Width = 210
      Height = 23
      TabOrder = 0
    end
    object HighEdit: TEdit
      Left = 12
      Top = 84
      Width = 210
      Height = 23
      TabOrder = 1
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 119
    Width = 234
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 1
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 234
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 38
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = OKButtonClick
    end
    object CancelButton: TButton
      Left = 134
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
