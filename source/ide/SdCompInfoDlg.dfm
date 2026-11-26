object CompInfoDlg: TCompInfoDlg
  Left = 200
  Top = 120
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Information'
  ClientHeight = 272
  ClientWidth = 436
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
  object CompilerGroup: TGroupBox
    Left = 12
    Top = 12
    Width = 252
    Height = 143
    Caption = 'Program'
    TabOrder = 0
    object xLabel1: TLabel
      Left = 9
      Top = 20
      Width = 140
      Height = 18
      AutoSize = False
      Caption = 'Source compiled:'
    end
    object xLabel2: TLabel
      Left = 9
      Top = 44
      Width = 140
      Height = 18
      AutoSize = False
      Caption = 'Code size:'
    end
    object xLabel3: TLabel
      Left = 9
      Top = 68
      Width = 140
      Height = 18
      AutoSize = False
      Caption = 'Data size:'
    end
    object xLabel4: TLabel
      Left = 9
      Top = 91
      Width = 140
      Height = 18
      AutoSize = False
      Caption = 'Initial stack size:'
    end
    object CompiledLabel: TLabel
      Left = 128
      Top = 20
      Width = 116
      Height = 18
      AutoSize = False
    end
    object CodeSizeLabel: TLabel
      Left = 128
      Top = 44
      Width = 116
      Height = 18
      AutoSize = False
    end
    object DataSizeLabel: TLabel
      Left = 128
      Top = 68
      Width = 116
      Height = 18
      AutoSize = False
    end
    object StackSizeLabel: TLabel
      Left = 128
      Top = 91
      Width = 116
      Height = 18
      AutoSize = False
    end
    object xLabel5: TLabel
      Left = 9
      Top = 115
      Width = 140
      Height = 18
      AutoSize = False
      Caption = 'File size:'
    end
    object FileSizeLabel: TLabel
      Left = 128
      Top = 115
      Width = 116
      Height = 18
      AutoSize = False
    end
  end
  object xGroupBox1: TGroupBox
    Left = 12
    Top = 161
    Width = 412
    Height = 48
    Caption = 'Status'
    TabOrder = 1
    object StatusLabel: TLabel
      Left = 9
      Top = 20
      Width = 310
      Height = 18
      AutoSize = False
      WordWrap = True
    end
  end
  object PkgGroup: TGroupBox
    Left = 272
    Top = 12
    Width = 152
    Height = 143
    Caption = 'Packages Used'
    TabOrder = 2
    object PkgListBox: TListBox
      Left = 9
      Top = 20
      Width = 134
      Height = 112
      BorderStyle = bsNone
      ItemHeight = 13
      ParentColor = True
      TabOrder = 0
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 221
    Width = 436
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 3
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 436
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 336
      Top = 13
      Width = 88
      Height = 26
      Cancel = True
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
  end
end
