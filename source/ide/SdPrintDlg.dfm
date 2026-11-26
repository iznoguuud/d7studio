object PrintDlg: TPrintDlg
  Left = 200
  Top = 120
  ActiveControl = cbHeader
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Print Selection'
  ClientHeight = 250
  ClientWidth = 409
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
    Top = 90
    Width = 385
    Height = 97
    Caption = 'Options:'
    TabOrder = 0
    object xLabel2: TLabel
      Left = 210
      Top = 67
      Width = 64
      Height = 15
      Caption = 'Left &margin:'
      FocusControl = ebMargin
    end
    object cbHeader: TCheckBox
      Left = 9
      Top = 18
      Width = 170
      Height = 22
      Caption = 'Header/page &number'
      TabOrder = 0
    end
    object cbLineNumbers: TCheckBox
      Left = 9
      Top = 40
      Width = 170
      Height = 22
      Caption = '&Line numbers'
      TabOrder = 1
    end
    object cbSyntaxPrint: TCheckBox
      Left = 9
      Top = 62
      Width = 142
      Height = 22
      Caption = '&Syntax print'
      TabOrder = 2
    end
    object cbColor: TCheckBox
      Left = 210
      Top = 18
      Width = 142
      Height = 22
      Caption = 'Use &color'
      TabOrder = 3
    end
    object cbWrapLines: TCheckBox
      Left = 210
      Top = 40
      Width = 142
      Height = 22
      Caption = '&Wrap lines'
      TabOrder = 4
    end
    object ebMargin: TEdit
      Left = 294
      Top = 64
      Width = 82
      Height = 23
      TabOrder = 5
    end
  end
  object xGroupBox2: TGroupBox
    Left = 12
    Top = 12
    Width = 385
    Height = 72
    Caption = 'File to print:'
    TabOrder = 1
    object lbFileName: TLabel
      Left = 9
      Top = 20
      Width = 362
      Height = 19
      AutoSize = False
      Caption = 'File Name'
    end
    object cbSelectedText: TCheckBox
      Left = 9
      Top = 42
      Width = 202
      Height = 22
      Caption = '&Print selected block'
      TabOrder = 0
    end
  end
  object PrinterSetupDialog1: TPrinterSetupDialog
    Left = 312
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 199
    Width = 409
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 409
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object SetupBtn: TButton
      Left = 12
      Top = 13
      Width = 88
      Height = 26
      Caption = 'Se&tup...'
      TabOrder = 0
      OnClick = SetupBtnClick
    end
    object OKButton: TButton
      Left = 213
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 1
    end
    object CancelButton: TButton
      Left = 309
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
