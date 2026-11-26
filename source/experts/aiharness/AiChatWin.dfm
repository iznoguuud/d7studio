object AiChatWindow: TAiChatWindow
  Left = 300
  Top = 160
  Width = 460
  Height = 560
  Caption = 'AI Assistant'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 15
  object Splitter: TSplitter
    Left = 0
    Top = 412
    Width = 452
    Height = 3
    Cursor = crVSplit
    Align = alBottom
    MinSize = 40
  end
  object TopBar: TPanel
    Left = 0
    Top = 0
    Width = 452
    Height = 25
    Align = alTop
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 0
    OnResize = TopBarResize
    object MainBar: TToolBar
      Left = 0
      Top = 1
      Width = 131
      Height = 22
      Align = alNone
      AutoSize = True
      Color = clBtnFace
      DisabledImages = IconsDisabled
      EdgeBorders = []
      Flat = True
      Images = Icons
      ParentColor = False
      ParentShowHint = False
      ShowHint = True
      TabOrder = 0
      Wrapable = False
      object NewChatButton: TToolButton
        Left = 0
        Top = 0
        Action = aNewChat
      end
      object Sep1: TToolButton
        Left = 23
        Top = 0
        Width = 8
        Style = tbsSeparator
      end
      object StopButton: TToolButton
        Left = 31
        Top = 0
        Action = aStop
      end
      object ContinueButton: TToolButton
        Left = 54
        Top = 0
        Action = aContinue
      end
      object Sep2: TToolButton
        Left = 77
        Top = 0
        Width = 8
        Style = tbsSeparator
      end
      object CopyButton: TToolButton
        Left = 85
        Top = 0
        Action = aCopy
      end
      object SettingsButton: TToolButton
        Left = 108
        Top = 0
        Action = aSettings
      end
    end
    object ProviderCombo: TComboBox
      Left = 206
      Top = 1
      Width = 240
      Height = 23
      Hint = 'The provider and the model of the next message'
      Style = csDropDownList
      ItemHeight = 15
      ParentShowHint = False
      ShowHint = True
      TabOrder = 1
      OnChange = ProviderComboChange
    end
  end
  object InputPanel: TPanel
    Left = 0
    Top = 415
    Width = 452
    Height = 90
    Align = alBottom
    BevelOuter = bvNone
    BorderStyle = bsSingle
    BorderWidth = 6
    Color = clWindow
    Ctl3D = False
    ParentBackground = False
    ParentCtl3D = False
    TabOrder = 1
    object Input: TMemo
      Left = 6
      Top = 6
      Width = 382
      Height = 76
      Align = alClient
      BorderStyle = bsNone
      TabOrder = 0
      OnChange = InputChange
      OnKeyDown = InputKeyDown
      OnKeyPress = InputKeyPress
    end
    object SendPanel: TPanel
      Left = 370
      Top = 6
      Width = 74
      Height = 76
      Align = alRight
      BevelOuter = bvNone
      Color = clWindow
      ParentBackground = False
      TabOrder = 1
      object SendButton: TButton
        Left = 2
        Top = 0
        Width = 72
        Height = 26
        Action = aSend
        TabOrder = 0
        OnKeyDown = ChatKeyDown
      end
    end
  end
  object StatusPanel: TPanel
    Left = 0
    Top = 505
    Width = 452
    Height = 21
    Align = alBottom
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    DesignSize = (
      452
      21)
    object StatusLabel: TLabel
      Left = 4
      Top = 3
      Width = 368
      Height = 15
      Anchors = [akLeft, akTop, akRight]
      AutoSize = False
      Caption = 'Ready'
    end
    object ContextMeter: TPaintBox
      Left = 380
      Top = 8
      Width = 64
      Height = 6
      Anchors = [akTop, akRight]
      ParentShowHint = False
      ShowHint = True
      Visible = False
      OnPaint = ContextMeterPaint
    end
  end
  object Actions: TActionList
    Images = Icons
    Left = 24
    Top = 64
    object aSend: TAction
      Caption = '&Send'
      Hint = 'Send the message (Enter; Shift+Enter starts a new line)'
      ImageIndex = 4
      OnExecute = aSendExecute
      OnUpdate = aSendUpdate
    end
    object aStop: TAction
      Caption = 'Sto&p'
      Hint = 'Stop the assistant (Esc)'
      ImageIndex = 1
      OnExecute = aStopExecute
      OnUpdate = aStopUpdate
    end
    object aContinue: TAction
      Caption = '&Continue'
      Hint = 'Send the conversation again after an error, a stop or the tool-round limit'
      ImageIndex = 2
      OnExecute = aContinueExecute
      OnUpdate = aContinueUpdate
    end
    object aNewChat: TAction
      Caption = '&New Chat'
      Hint = 'Start a new conversation'
      ImageIndex = 0
      OnExecute = aNewChatExecute
      OnUpdate = aNewChatUpdate
    end
    object aSettings: TAction
      Caption = 'Se&ttings...'
      Hint = 'The provider, the model and the API key'
      ImageIndex = 3
      OnExecute = aSettingsExecute
    end
    object aCopy: TAction
      Caption = '&Copy'
      Hint = 'Copy the selected text of the conversation'
      ImageIndex = 5
      OnExecute = aCopyExecute
      OnUpdate = aCopyUpdate
    end
    object aSelectAll: TAction
      Caption = 'Select &All'
      Hint = 'Select the whole conversation'
      ImageIndex = 6
      OnExecute = aSelectAllExecute
    end
  end
  object Icons: TImageList
    Left = 64
    Top = 64
  end
  object IconsDisabled: TImageList
    Left = 104
    Top = 64
  end
  object TranscriptMenu: TPopupMenu
    Images = Icons
    Left = 144
    Top = 64
    object miCopy: TMenuItem
      Action = aCopy
    end
    object miSelectAll: TMenuItem
      Action = aSelectAll
    end
    object miSep1: TMenuItem
      Caption = '-'
    end
    object miNewChat: TMenuItem
      Action = aNewChat
    end
  end
end
