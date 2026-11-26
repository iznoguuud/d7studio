object CompTemplateDlg: TCompTemplateDlg
  Left = 200
  Top = 120
  BorderStyle = bsDialog
  Caption = 'Component Template Information'
  ClientHeight = 164
  ClientWidth = 335
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
    Width = 100
    Height = 15
    Caption = '&Component name:'
    FocusControl = ComponentName
  end
  object xLabel2: TLabel
    Left = 12
    Top = 41
    Width = 68
    Height = 15
    Caption = '&Palette page:'
    FocusControl = PageList
  end
  object xLabel3: TLabel
    Left = 12
    Top = 81
    Width = 65
    Height = 15
    Caption = 'Palette Icon:'
  end
  object Preview: TPaintBox
    Left = 118
    Top = 69
    Width = 33
    Height = 32
    OnPaint = PreviewPaint
  end
  object ComponentName: TEdit
    Left = 118
    Top = 12
    Width = 205
    Height = 23
    TabOrder = 0
  end
  object PageList: TComboBox
    Left = 118
    Top = 38
    Width = 205
    Height = 23
    ItemHeight = 0
    TabOrder = 1
  end
  object ChangeButton: TButton
    Left = 161
    Top = 72
    Width = 88
    Height = 26
    Caption = 'Ch&ange...'
    TabOrder = 2
    OnClick = ChangeButtonClick
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 113
    Width = 335
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 3
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 335
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 139
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = OKButtonClick
    end
    object CancelButton: TButton
      Left = 235
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
