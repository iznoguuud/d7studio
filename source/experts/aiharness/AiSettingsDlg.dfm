object AiSettingsDialog: TAiSettingsDialog
  Left = 380
  Top = 220
  BorderStyle = bsDialog
  Caption = 'AI Assistant Settings'
  ClientHeight = 516
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
  object ModelHeading: TLabel
    Left = 12
    Top = 12
    Width = 36
    Height = 15
    Caption = 'Model'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 10040064
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object ModelRule: TShape
    Left = 57
    Top = 20
    Width = 403
    Height = 1
    Brush.Color = clBtnShadow
    Pen.Color = clBtnShadow
  end
  object BackendLabel: TLabel
    Left = 24
    Top = 39
    Width = 47
    Height = 15
    Caption = '&Provider:'
    FocusControl = BackendCombo
  end
  object ModelLabel: TLabel
    Left = 24
    Top = 70
    Width = 37
    Height = 15
    Caption = '&Model:'
    FocusControl = ModelCombo
  end
  object EffortLabel: TLabel
    Left = 24
    Top = 101
    Width = 34
    Height = 15
    Caption = '&Effort:'
    FocusControl = EffortCombo
  end
  object ReasoningLabel: TLabel
    Left = 24
    Top = 132
    Width = 94
    Height = 15
    Caption = '&Show reasoning:'
    FocusControl = ReasoningCombo
  end
  object LimitsHeading: TLabel
    Left = 12
    Top = 166
    Width = 37
    Height = 15
    Caption = 'Limits'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 10040064
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object LimitsRule: TShape
    Left = 57
    Top = 174
    Width = 403
    Height = 1
    Brush.Color = clBtnShadow
    Pen.Color = clBtnShadow
  end
  object MaxTokensLabel: TLabel
    Left = 24
    Top = 193
    Width = 120
    Height = 15
    Caption = '&Output limit (tokens):'
    FocusControl = MaxTokensEdit
  end
  object RoundsLabel: TLabel
    Left = 24
    Top = 224
    Width = 138
    Height = 15
    Caption = '&Tool rounds per message:'
    FocusControl = RoundsEdit
  end
  object CompactLabel: TLabel
    Left = 24
    Top = 255
    Width = 128
    Height = 15
    Caption = 'Summarize &at (tokens):'
    FocusControl = CompactEdit
  end
  object CompactNote: TLabel
    Left = 320
    Top = 255
    Width = 140
    Height = 15
    AutoSize = False
    Caption = '0: never'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
  end
  object KeyHeading: TLabel
    Left = 12
    Top = 289
    Width = 64
    Height = 15
    Caption = 'Connection'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = 10040064
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = [fsBold]
    ParentFont = False
  end
  object KeyRule: TShape
    Left = 84
    Top = 297
    Width = 376
    Height = 1
    Brush.Color = clBtnShadow
    Pen.Color = clBtnShadow
  end
  object UrlLabel: TLabel
    Left = 24
    Top = 316
    Width = 54
    Height = 15
    Caption = '&Base URL:'
    FocusControl = UrlEdit
  end
  object ProtocolLabel: TLabel
    Left = 24
    Top = 347
    Width = 49
    Height = 15
    Caption = 'P&rotocol:'
    FocusControl = ProtocolCombo
  end
  object KeyLabel: TLabel
    Left = 24
    Top = 378
    Width = 23
    Height = 15
    Caption = '&Key:'
    FocusControl = KeyEdit
  end
  object KeyNote: TLabel
    Left = 172
    Top = 401
    Width = 288
    Height = 30
    AutoSize = False
    Caption = 'No key is saved.'
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clGrayText
    Font.Height = -12
    Font.Name = 'Segoe UI'
    Font.Style = []
    ParentFont = False
    WordWrap = True
  end
  object BackendCombo: TComboBox
    Left = 172
    Top = 36
    Width = 288
    Height = 23
    Style = csDropDownList
    ItemHeight = 15
    TabOrder = 0
    OnChange = BackendComboChange
  end
  object ModelCombo: TComboBox
    Left = 172
    Top = 67
    Width = 288
    Height = 23
    ItemHeight = 15
    TabOrder = 1
  end
  object EffortCombo: TComboBox
    Left = 172
    Top = 98
    Width = 140
    Height = 23
    Style = csDropDownList
    ItemHeight = 15
    TabOrder = 2
  end
  object ReasoningCombo: TComboBox
    Left = 172
    Top = 129
    Width = 140
    Height = 23
    Style = csDropDownList
    ItemHeight = 15
    TabOrder = 3
  end
  object MaxTokensEdit: TEdit
    Left = 172
    Top = 190
    Width = 140
    Height = 23
    TabOrder = 4
  end
  object RoundsEdit: TEdit
    Left = 172
    Top = 221
    Width = 140
    Height = 23
    TabOrder = 5
  end
  object CompactEdit: TEdit
    Left = 172
    Top = 252
    Width = 140
    Height = 23
    TabOrder = 6
  end
  object UrlEdit: TEdit
    Left = 172
    Top = 313
    Width = 288
    Height = 23
    TabOrder = 7
  end
  object ProtocolCombo: TComboBox
    Left = 172
    Top = 344
    Width = 140
    Height = 23
    Style = csDropDownList
    ItemHeight = 15
    TabOrder = 8
  end
  object KeyEdit: TEdit
    Left = 172
    Top = 375
    Width = 288
    Height = 23
    PasswordChar = '*'
    TabOrder = 9
  end
  object ForgetKeyCheck: TCheckBox
    Left = 172
    Top = 434
    Width = 288
    Height = 19
    Caption = '&Forget the saved key'
    TabOrder = 10
  end
  object Footer: TPanel
    Left = 0
    Top = 462
    Width = 472
    Height = 51
    Align = alBottom
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 11
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
end
