object FindInFilesDlg: TFindInFilesDlg
  Left = 200
  Top = 120
  ActiveControl = edFind
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Find in Files'
  ClientHeight = 255
  ClientWidth = 413
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Position = poOwnerFormCenter
  PixelsPerInch = 96
  TextHeight = 15
  OnCreate = FormCreate
  object lblFind: TLabel
    Left = 12
    Top = 15
    Width = 62
    Height = 15
    Caption = '&Text to find:'
    FocusControl = edFind
  end
  object lblDirectory: TLabel
    Left = 12
    Top = 141
    Width = 51
    Height = 15
    Caption = 'D&irectory:'
    FocusControl = edDirectory
  end
  object lblMask: TLabel
    Left = 12
    Top = 172
    Width = 52
    Height = 15
    Caption = 'File &mask:'
    FocusControl = edMask
  end
  object edFind: TEdit
    Left = 103
    Top = 12
    Width = 298
    Height = 23
    TabOrder = 0
  end
  object gbOptions: TGroupBox
    Left = 12
    Top = 43
    Width = 191
    Height = 87
    Caption = 'Options'
    TabOrder = 1
    object chkCase: TCheckBox
      Left = 9
      Top = 18
      Width = 173
      Height = 19
      Caption = '&Case sensitive'
      TabOrder = 0
    end
    object chkWholeWord: TCheckBox
      Left = 9
      Top = 39
      Width = 173
      Height = 19
      Caption = '&Whole words only'
      TabOrder = 1
    end
    object chkRecurse: TCheckBox
      Left = 9
      Top = 60
      Width = 173
      Height = 19
      Caption = 'Include &subdirectories'
      TabOrder = 2
    end
  end
  object gbWhere: TGroupBox
    Left = 210
    Top = 43
    Width = 191
    Height = 87
    Caption = 'Where'
    TabOrder = 2
    object rbProject: TRadioButton
      Left = 9
      Top = 18
      Width = 173
      Height = 19
      Caption = 'Search all files in &project'
      Checked = True
      TabOrder = 0
      TabStop = True
    end
    object rbOpenFiles: TRadioButton
      Left = 9
      Top = 39
      Width = 173
      Height = 19
      Caption = 'Search all &open files'
      TabOrder = 1
    end
    object rbDirectories: TRadioButton
      Left = 9
      Top = 60
      Width = 173
      Height = 19
      Caption = 'Search in &directories'
      TabOrder = 2
    end
  end
  object edDirectory: TEdit
    Left = 103
    Top = 138
    Width = 298
    Height = 23
    TabOrder = 3
  end
  object edMask: TEdit
    Left = 103
    Top = 169
    Width = 140
    Height = 23
    TabOrder = 4
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 204
    Width = 413
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 5
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 413
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnOK: TButton
      Left = 217
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      ModalResult = 1
      TabOrder = 0
    end
    object btnCancel: TButton
      Left = 313
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
