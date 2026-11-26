object ScaleDlg: TScaleDlg
  Left = 200
  Top = 120
  BorderStyle = bsDialog
  Caption = 'Scale'
  ClientHeight = 98
  ClientWidth = 258
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
    Top = 15
    Width = 75
    Height = 15
    Caption = '&Scaling factor:'
    FocusControl = Edit
  end
  object xLabel2: TLabel
    Left = 236
    Top = 18
    Width = 10
    Height = 15
    Caption = '%'
  end
  object Edit: TEdit
    Left = 145
    Top = 12
    Width = 86
    Height = 23
    TabOrder = 0
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 47
    Width = 258
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 1
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 258
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 62
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = OKButtonClick
    end
    object CancelButton: TButton
      Left = 158
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
