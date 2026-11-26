object GitSettingsDialog: TGitSettingsDialog
  Left = 380
  Top = 240
  BorderStyle = bsDialog
  Caption = 'Git Settings'
  ClientHeight = 214
  ClientWidth = 472
  Color = clWindow
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 15
  object GitHeading: TLabel
    Left = 12
    Top = 12
    Width = 16
    Height = 15
    Caption = 'Git'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 10040064
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object GitRule: TShape
    Left = 36
    Top = 20
    Width = 424
    Height = 1
    Brush.Color = clBtnShadow
    Pen.Color = clBtnShadow
  end
  object PathLabel: TLabel
    Left = 24
    Top = 39
    Width = 41
    Height = 15
    Caption = '&git.exe:'
    FocusControl = PathEdit
  end
  object FoundLabel: TLabel
    Left = 108
    Top = 64
    Width = 352
    Height = 30
    AutoSize = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    WordWrap = True
  end
  object RefreshHeading: TLabel
    Left = 12
    Top = 108
    Width = 47
    Height = 15
    Caption = 'Refresh'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 10040064
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object RefreshRule: TShape
    Left = 67
    Top = 116
    Width = 393
    Height = 1
    Brush.Color = clBtnShadow
    Pen.Color = clBtnShadow
  end
  object PathEdit: TEdit
    Left = 108
    Top = 36
    Width = 257
    Height = 23
    TabOrder = 0
    OnExit = PathEditExit
  end
  object BrowseButton: TButton
    Left = 372
    Top = 35
    Width = 88
    Height = 26
    Caption = '&Browse...'
    TabOrder = 1
    OnClick = BrowseButtonClick
  end
  object AutoRefreshBox: TCheckBox
    Left = 24
    Top = 132
    Width = 436
    Height = 19
    Caption = '&Read the status again when files of the work tree change'
    TabOrder = 2
  end
  object Footer: TPanel
    Left = 0
    Top = 166
    Width = 472
    Height = 51
    Align = alBottom
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 3
    object FooterLine: TShape
      Left = 0
      Top = 0
      Width = 472
      Height = 1
      Align = alTop
      Brush.Color = clBtnShadow
      Pen.Color = clBtnShadow
    end
    object OKButton: TButton
      Left = 276
      Top = 13
      Width = 88
      Height = 26
      Caption = 'OK'
      Default = True
      TabOrder = 0
      OnClick = OKButtonClick
    end
    object CancelButton: TButton
      Left = 372
      Top = 13
      Width = 88
      Height = 26
      Cancel = True
      Caption = 'Cancel'
      ModalResult = 2
      TabOrder = 1
    end
  end
  object OpenDialog: TOpenDialog
    DefaultExt = 'exe'
    Filter = 'git.exe|git.exe|Programs (*.exe)|*.exe'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Title = 'git.exe'
    Left = 24
    Top = 168
  end
end
