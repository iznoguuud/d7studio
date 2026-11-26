object AlignDlg: TAlignDlg
  Left = 200
  Top = 120
  ActiveControl = hNoChange
  BorderStyle = bsDialog
  Caption = 'Alignment'
  ClientHeight = 231
  ClientWidth = 379
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
  object xGroupBox1: TGroupBox
    Left = 12
    Top = 12
    Width = 173
    Height = 156
    Caption = 'Horizontal'
    TabOrder = 0
    object hNoChange: TRadioButton
      Left = 9
      Top = 18
      Width = 155
      Height = 20
      Caption = '&No change'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object hLeftSides: TRadioButton
      Left = 9
      Top = 40
      Width = 155
      Height = 20
      Caption = '&Left sides'
      TabOrder = 1
    end
    object hCenters: TRadioButton
      Left = 9
      Top = 62
      Width = 155
      Height = 20
      Caption = '&Centers'
      TabOrder = 2
    end
    object hRightSides: TRadioButton
      Left = 9
      Top = 84
      Width = 155
      Height = 20
      Caption = '&Right sides'
      TabOrder = 3
    end
    object hSpaceEqual: TRadioButton
      Left = 9
      Top = 106
      Width = 155
      Height = 20
      Caption = '&Space equally'
      TabOrder = 4
    end
    object hCenterInWindow: TRadioButton
      Left = 9
      Top = 128
      Width = 155
      Height = 20
      Caption = 'Center in &window'
      TabOrder = 5
    end
  end
  object xGroupBox2: TGroupBox
    Left = 194
    Top = 12
    Width = 173
    Height = 156
    Caption = 'Vertical'
    TabOrder = 1
    object vNoChange: TRadioButton
      Left = 9
      Top = 18
      Width = 105
      Height = 20
      Caption = 'No chan&ge'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object vTops: TRadioButton
      Left = 9
      Top = 40
      Width = 105
      Height = 20
      Caption = '&Tops'
      TabOrder = 1
    end
    object vCenters: TRadioButton
      Left = 9
      Top = 62
      Width = 105
      Height = 20
      Caption = 'C&enters'
      TabOrder = 2
    end
    object vBottoms: TRadioButton
      Left = 9
      Top = 84
      Width = 105
      Height = 20
      Caption = '&Bottoms'
      TabOrder = 3
    end
    object vSpaceEqual: TRadioButton
      Left = 9
      Top = 106
      Width = 147
      Height = 20
      Caption = 'Space e&qually'
      TabOrder = 4
    end
    object vCenterInWindow: TRadioButton
      Left = 9
      Top = 128
      Width = 144
      Height = 20
      Caption = 'Center &in window'
      TabOrder = 5
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 180
    Width = 379
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 379
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 183
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object CancelButton: TButton
      Left = 279
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
