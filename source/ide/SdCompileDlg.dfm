object CompileDlg: TCompileDlg
  Left = 200
  Top = 120
  ActiveControl = btnAction
  BorderIcons = []
  BorderStyle = bsDialog
  Caption = 'Compiling'
  ClientHeight = 167
  ClientWidth = 392
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 15
  OnCreate = FormCreate
  OnShow = FormShow
  object lblProjectCap: TLabel
    Left = 12
    Top = 12
    Width = 40
    Height = 15
    Caption = 'Project:'
  end
  object lblProject: TLabel
    Left = 82
    Top = 12
    Width = 298
    Height = 15
    AutoSize = False
    ShowAccelChar = False
    Caption = 'Project1.dpr'
  end
  object lblAction: TLabel
    Left = 12
    Top = 32
    Width = 59
    Height = 15
    Caption = 'Compiling:'
  end
  object lblFile: TLabel
    Left = 82
    Top = 32
    Width = 298
    Height = 15
    AutoSize = False
    ShowAccelChar = False
  end
  object pnlLine: TPanel
    Left = 12
    Top = 54
    Width = 182
    Height = 23
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 0
    ParentBackground = False
    object shpLine: TShape
      Left = 0
      Top = 0
      Width = 182
      Height = 23
      Align = alClient
      Brush.Style = bsClear
      Pen.Color = clBtnShadow
    end
    object lblLineCap: TLabel
      Left = 5
      Top = 4
      Width = 65
      Height = 15
      Caption = 'Current line:'
    end
    object lblLine: TLabel
      Left = 74
      Top = 4
      Width = 103
      Height = 15
      Alignment = taRightJustify
      AutoSize = False
      Caption = '0'
    end
  end
  object pnlTotal: TPanel
    Left = 198
    Top = 54
    Width = 182
    Height = 23
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 1
    ParentBackground = False
    object shpTotal: TShape
      Left = 0
      Top = 0
      Width = 182
      Height = 23
      Align = alClient
      Brush.Style = bsClear
      Pen.Color = clBtnShadow
    end
    object lblTotalCap: TLabel
      Left = 5
      Top = 4
      Width = 56
      Height = 15
      Caption = 'Total lines:'
    end
    object lblTotal: TLabel
      Left = 65
      Top = 4
      Width = 112
      Height = 15
      Alignment = taRightJustify
      AutoSize = False
      Caption = '0'
    end
  end
  object pnlHints: TPanel
    Left = 12
    Top = 81
    Width = 120
    Height = 23
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 2
    ParentBackground = False
    object shpHints: TShape
      Left = 0
      Top = 0
      Width = 120
      Height = 23
      Align = alClient
      Brush.Style = bsClear
      Pen.Color = clBtnShadow
    end
    object lblHintsCap: TLabel
      Left = 5
      Top = 4
      Width = 31
      Height = 15
      Caption = 'Hints:'
    end
    object lblHints: TLabel
      Left = 40
      Top = 4
      Width = 75
      Height = 15
      Alignment = taRightJustify
      AutoSize = False
      Caption = '0'
    end
  end
  object pnlWarnings: TPanel
    Left = 136
    Top = 81
    Width = 120
    Height = 23
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 3
    ParentBackground = False
    object shpWarnings: TShape
      Left = 0
      Top = 0
      Width = 120
      Height = 23
      Align = alClient
      Brush.Style = bsClear
      Pen.Color = clBtnShadow
    end
    object lblWarningsCap: TLabel
      Left = 5
      Top = 4
      Width = 53
      Height = 15
      Caption = 'Warnings:'
    end
    object lblWarnings: TLabel
      Left = 62
      Top = 4
      Width = 53
      Height = 15
      Alignment = taRightJustify
      AutoSize = False
      Caption = '0'
    end
  end
  object pnlErrors: TPanel
    Left = 260
    Top = 81
    Width = 120
    Height = 23
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 4
    ParentBackground = False
    object shpErrors: TShape
      Left = 0
      Top = 0
      Width = 120
      Height = 23
      Align = alClient
      Brush.Style = bsClear
      Pen.Color = clBtnShadow
    end
    object lblErrorsCap: TLabel
      Left = 5
      Top = 4
      Width = 33
      Height = 15
      Caption = 'Errors:'
    end
    object lblErrors: TLabel
      Left = 42
      Top = 4
      Width = 73
      Height = 15
      Alignment = taRightJustify
      AutoSize = False
      Caption = '0'
    end
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 116
    Width = 392
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 5
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 392
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnAction: TButton
      Left = 292
      Top = 13
      Width = 88
      Height = 26
      Hint = 'Stop the compiler; when it has finished, close'
      Cancel = True
      Caption = 'Cancel'
      Default = True
      TabOrder = 0
      OnClick = btnActionClick
    end
  end
end
