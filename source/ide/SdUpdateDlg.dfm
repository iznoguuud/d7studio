object UpdateDlg: TUpdateDlg
  Left = 200
  Top = 120
  ActiveControl = btnUpdate
  BorderIcons = [biSystemMenu]
  BorderStyle = bsDialog
  Caption = 'Update D7 Studio'
  ClientHeight = 401
  ClientWidth = 520
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
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  object lblTitle: TLabel
    Left = 12
    Top = 12
    Width = 496
    Height = 15
    AutoSize = False
    Caption = 'D7 Studio is available.'
  end
  object lblInfo: TLabel
    Left = 12
    Top = 35
    Width = 496
    Height = 30
    AutoSize = False
    Caption = 'You have version.'
    WordWrap = True
  end
  object lblNotes: TLabel
    Left = 12
    Top = 73
    Width = 80
    Height = 15
    Caption = 'Release &notes:'
    FocusControl = mmNotes
  end
  object lblStatus: TLabel
    Left = 12
    Top = 302
    Width = 496
    Height = 15
    AutoSize = False
    Visible = False
  end
  object mmNotes: TMemo
    Left = 12
    Top = 93
    Width = 496
    Height = 197
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object pbDownload: TProgressBar
    Left = 12
    Top = 322
    Width = 496
    Height = 16
    TabOrder = 1
    Visible = False
  end
  object pnlFooter: TPanel
    Left = 0
    Top = 350
    Width = 520
    Height = 51
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    object lnFooter: TShape
      Left = 0
      Top = 0
      Width = 520
      Height = 1
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object btnReleasePage: TButton
      Left = 12
      Top = 13
      Width = 112
      Height = 26
      Hint = 'Open the release'#39's page on GitHub in the browser'
      Caption = '&Release Page'
      TabOrder = 0
      OnClick = btnReleasePageClick
    end
    object btnUpdate: TButton
      Left = 324
      Top = 13
      Width = 88
      Height = 26
      Caption = '&Update'
      Default = True
      TabOrder = 1
      OnClick = btnUpdateClick
    end
    object btnClose: TButton
      Left = 420
      Top = 13
      Width = 88
      Height = 26
      Cancel = True
      Caption = 'Close'
      TabOrder = 2
      OnClick = btnCloseClick
    end
  end
  object tmProgress: TTimer
    Enabled = False
    Interval = 100
    OnTimer = tmProgressTimer
    Left = 456
    Top = 296
  end
end
