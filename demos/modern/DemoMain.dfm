object MainForm: TMainForm
  Left = 192
  Top = 100
  ClientHeight = 571
  ClientWidth = 984
  Caption = 'ModernDemo - the modernized Delphi 7 RTL/VCL'
  Constraints.MinWidth = 1000
  Constraints.MinHeight = 610
  Color = 15987699
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 15
  object ToolBar: TToolBar
    Left = 0
    Top = 0
    Width = 984
    Height = 30
    AutoSize = True
    ButtonHeight = 30
    Caption = 'ToolBar'
    EdgeBorders = []
    Flat = True
    Images = SetImages
    Indent = 8
    List = True
    ShowCaptions = True
    TabOrder = 0
    object btnRefresh: TToolButton
      Left = 8
      Top = 0
      AutoSize = True
      Caption = 'Refresh'
      ImageIndex = 0
      OnClick = btnRefreshClick
    end
    object btnFloat: TToolButton
      Left = 74
      Top = 0
      AutoSize = True
      Caption = 'Float'
      ImageIndex = 1
      OnClick = btnFloatClick
    end
    object btnClear: TToolButton
      Left = 126
      Top = 0
      AutoSize = True
      Caption = 'Clear activity'
      ImageIndex = 2
      OnClick = btnClearClick
    end
    object btnSettings: TToolButton
      Left = 220
      Top = 0
      AutoSize = True
      Caption = 'Display settings'
      ImageIndex = 3
      OnClick = btnSettingsClick
    end
  end
  object Nav: TListBox
    Left = 0
    Top = 30
    Width = 200
    Height = 541
    Style = lbOwnerDrawFixed
    Align = alLeft
    BorderStyle = bsNone
    Color = 15987699
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -14
    Font.Name = 'Segoe UI'
    Font.Style = []
    ItemHeight = 36
    ParentFont = False
    TabOrder = 1
    OnClick = NavClick
    OnDrawItem = NavDrawItem
  end
  object Body: TPanel
    Left = 200
    Top = 30
    Width = 784
    Height = 541
    Align = alClient
    BevelOuter = bvNone
    BorderWidth = 16
    ParentColor = True
    TabOrder = 2
    ParentBackground = False
    object Header: TPanel
      Left = 16
      Top = 16
      Width = 752
      Height = 64
      Align = alTop
      BevelOuter = bvNone
      ParentColor = True
      TabOrder = 0
      ParentBackground = False
      object TitleLabel: TLabel
        Left = 0
        Top = 0
        Width = 75
        Height = 32
        Caption = 'Display'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -24
        Font.Name = 'Segoe UI Semibold'
        Font.Style = []
        ParentFont = False
      end
      object IntroLabel: TLabel
        Left = 0
        Top = 38
        Width = 752
        Height = 15
        Anchors = [akLeft, akTop, akRight]
        Caption = 'Intro'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
      object InfoLabel: TLabel
        Left = 352
        Top = 10
        Width = 400
        Height = 15
        Alignment = taRightJustify
        Anchors = [akTop, akRight]
        AutoSize = False
        Caption = 'Info'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
      end
    end
    object LogCard: TPanel
      Tag = 1
      Left = 16
      Top = 434
      Width = 752
      Height = 96
      Align = alBottom
      BevelOuter = bvNone
      Color = clWindow
      TabOrder = 1
      ParentBackground = False
      object LogTitle: TLabel
        Left = 16
        Top = 10
        Width = 48
        Height = 17
        Anchors = [akLeft, akTop]
        Caption = 'Activity'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -13
        Font.Name = 'Segoe UI Semibold'
        Font.Style = []
        ParentFont = False
      end
      object LogMemo: TMemo
        Left = 16
        Top = 32
        Width = 720
        Height = 56
        Anchors = [akLeft, akTop, akRight, akBottom]
        BorderStyle = bsNone
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clGrayText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = []
        ParentFont = False
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
      end
    end
    object Gap: TPanel
      Left = 16
      Top = 422
      Width = 752
      Height = 12
      Align = alBottom
      BevelOuter = bvNone
      ParentColor = True
      TabOrder = 2
      ParentBackground = False
    end
    object DisplayPage: TPanel
      Tag = 10
      Left = 16
      Top = 80
      Width = 752
      Height = 337
      Align = alClient
      BevelOuter = bvNone
      ParentColor = True
      TabOrder = 3
      ParentBackground = False
      object FactsCard: TPanel
        Tag = 1
        Left = 0
        Top = 0
        Width = 440
        Height = 206
        Anchors = [akLeft, akTop, akRight, akBottom]
        BevelOuter = bvNone
        Color = clWindow
        TabOrder = 0
        ParentBackground = False
        object FactsTitle: TLabel
          Left = 16
          Top = 12
          Width = 70
          Height = 17
          Caption = 'This window'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI Semibold'
          Font.Style = []
          ParentFont = False
        end
        object FactsHost: TPanel
          Left = 16
          Top = 36
          Width = 408
          Height = 160
          Anchors = [akLeft, akTop, akRight, akBottom]
          BevelOuter = bvNone
          ParentColor = True
          TabOrder = 0
          ParentBackground = False
        end
      end
      object PanelCard: TPanel
        Tag = 1
        Left = 452
        Top = 0
        Width = 300
        Height = 206
        Anchors = [akTop, akRight, akBottom]
        BevelOuter = bvNone
        Color = clWindow
        TabOrder = 1
        ParentBackground = False
        object PanelTitle: TLabel
          Left = 16
          Top = 12
          Width = 92
          Height = 17
          Caption = 'Embedded form'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI Semibold'
          Font.Style = []
          ParentFont = False
        end
        object HostPanel: TPanel
          Left = 16
          Top = 36
          Width = 268
          Height = 156
          BevelOuter = bvNone
          ParentColor = True
          TabOrder = 0
          ParentBackground = False
        end
      end
      object IconsCard: TPanel
        Tag = 1
        Left = 0
        Top = 218
        Width = 440
        Height = 116
        Anchors = [akLeft, akRight, akBottom]
        BevelOuter = bvNone
        Color = clWindow
        TabOrder = 2
        ParentBackground = False
        object IconsTitle: TLabel
          Left = 16
          Top = 12
          Width = 107
          Height = 17
          Caption = 'Icons at this scale'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI Semibold'
          Font.Style = []
          ParentFont = False
        end
        object IconsBox: TPaintBox
          Left = 16
          Top = 38
          Width = 408
          Height = 70
          Anchors = [akLeft, akTop, akRight]
          OnPaint = IconsBoxPaint
        end
      end
      object RulerCard: TPanel
        Tag = 1
        Left = 452
        Top = 218
        Width = 300
        Height = 116
        Anchors = [akRight, akBottom]
        BevelOuter = bvNone
        Color = clWindow
        TabOrder = 3
        ParentBackground = False
        object RulerTitle: TLabel
          Left = 16
          Top = 12
          Width = 56
          Height = 17
          Caption = 'One inch'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI Semibold'
          Font.Style = []
          ParentFont = False
        end
        object RulerHost: TPanel
          Left = 8
          Top = 32
          Width = 284
          Height = 78
          BevelOuter = bvNone
          ParentColor = True
          TabOrder = 0
          ParentBackground = False
        end
      end
    end
    object UnicodePage: TPanel
      Tag = 11
      Left = 16
      Top = 80
      Width = 752
      Height = 337
      Align = alClient
      BevelOuter = bvNone
      ParentColor = True
      TabOrder = 4
      Visible = False
      ParentBackground = False
      object TextCard: TPanel
        Tag = 1
        Left = 0
        Top = 0
        Width = 752
        Height = 116
        Anchors = [akLeft, akTop, akRight]
        BevelOuter = bvNone
        Color = clWindow
        TabOrder = 0
        ParentBackground = False
        object TextTitle: TLabel
          Left = 16
          Top = 12
          Width = 64
          Height = 17
          Caption = 'Any script'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI Semibold'
          Font.Style = []
          ParentFont = False
        end
        object SampleEdit: TEdit
          Left = 16
          Top = 38
          Width = 720
          Height = 29
          Anchors = [akLeft, akTop, akRight]
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -16
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
          TabOrder = 0
          Text =
            'Hello, '#922#945#955#951#956#941#961#945', '#1055#1088#1080#1074#1077#1090', '#20320#22909' '#55356#57101
        end
        object CopyButton: TButton
          Left = 16
          Top = 76
          Width = 88
          Height = 28
          Caption = 'Copy'
          TabOrder = 1
          OnClick = CopyButtonClick
        end
        object PasteButton: TButton
          Left = 112
          Top = 76
          Width = 88
          Height = 28
          Caption = 'Paste'
          TabOrder = 2
          OnClick = PasteButtonClick
        end
        object CountButton: TButton
          Left = 208
          Top = 76
          Width = 88
          Height = 28
          Caption = 'Count'
          TabOrder = 3
          OnClick = CountButtonClick
        end
        object FileButton: TButton
          Left = 304
          Top = 76
          Width = 140
          Height = 28
          Caption = 'Use as a file name'
          TabOrder = 4
          OnClick = FileButtonClick
        end
      end
      object SortCard: TPanel
        Tag = 1
        Left = 0
        Top = 128
        Width = 752
        Height = 206
        Anchors = [akLeft, akTop, akRight, akBottom]
        BevelOuter = bvNone
        Color = clWindow
        TabOrder = 1
        ParentBackground = False
        object SortTitle: TLabel
          Left = 16
          Top = 12
          Width = 181
          Height = 17
          Caption = 'Sorted as Windows sorts text'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI Semibold'
          Font.Style = []
          ParentFont = False
        end
        object Words: TListBox
          Left = 16
          Top = 38
          Width = 300
          Height = 160
          Anchors = [akLeft, akTop, akBottom]
          BorderStyle = bsNone
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -15
          Font.Name = 'Segoe UI'
          Font.Style = []
          ItemHeight = 20
          Items.Strings = (
            'Zebra'
            #937#956#941#947#945
            'apple'
            #1055#1088#1080#1074#1077#1090
            #196'pfel'
            #20320#22909
            #233'migr'#233
            'Banana'
            #12371#12435#12395#12385#12399
            #1072#1088#1073#1091#1079)
          ParentFont = False
          TabOrder = 0
        end
        object SortButton: TButton
          Left = 332
          Top = 38
          Width = 88
          Height = 28
          Caption = 'Sort'
          TabOrder = 1
          OnClick = SortButtonClick
        end
      end
    end
    object DialogsPage: TPanel
      Tag = 12
      Left = 16
      Top = 80
      Width = 752
      Height = 337
      Align = alClient
      BevelOuter = bvNone
      ParentColor = True
      TabOrder = 5
      Visible = False
      ParentBackground = False
      object DialogsCard: TPanel
        Tag = 1
        Left = 0
        Top = 0
        Width = 752
        Height = 230
        Anchors = [akLeft, akTop, akRight]
        BevelOuter = bvNone
        Color = clWindow
        TabOrder = 0
        ParentBackground = False
        object DialogsTitle: TLabel
          Left = 16
          Top = 12
          Width = 129
          Height = 17
          Caption = 'Windows'#39' own dialogs'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI Semibold'
          Font.Style = []
          ParentFont = False
        end
        object MessageNote: TLabel
          Left = 196
          Top = 44
          Width = 241
          Height = 15
          Anchors = [akLeft, akTop, akRight]
          Caption = 'MessageDlg and ShowMessage: a task dialog'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGrayText
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
        end
        object QuestionNote: TLabel
          Left = 196
          Top = 80
          Width = 220
          Height = 15
          Anchors = [akLeft, akTop, akRight]
          Caption = 'TaskMessageDlg: a task dialog with a title'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGrayText
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
        end
        object OpenNote: TLabel
          Left = 196
          Top = 116
          Width = 224
          Height = 15
          Anchors = [akLeft, akTop, akRight]
          Caption = 'TOpenDialog: Windows'#39' current Open dialog'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGrayText
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
        end
        object SaveNote: TLabel
          Left = 196
          Top = 152
          Width = 220
          Height = 15
          Anchors = [akLeft, akTop, akRight]
          Caption = 'TSaveDialog: Windows'#39' current Save dialog'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGrayText
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
        end
        object FolderNote: TLabel
          Left = 196
          Top = 188
          Width = 280
          Height = 15
          Anchors = [akLeft, akTop, akRight]
          Caption = 'ExecuteFolderDialog, SelectDirectory: the folder picker'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clGrayText
          Font.Height = -12
          Font.Name = 'Segoe UI'
          Font.Style = []
          ParentFont = False
        end
        object MessageButton: TButton
          Left = 16
          Top = 38
          Width = 164
          Height = 28
          Caption = 'Message...'
          TabOrder = 0
          OnClick = MessageButtonClick
        end
        object QuestionButton: TButton
          Left = 16
          Top = 74
          Width = 164
          Height = 28
          Caption = 'Question...'
          TabOrder = 1
          OnClick = QuestionButtonClick
        end
        object OpenButton: TButton
          Left = 16
          Top = 110
          Width = 164
          Height = 28
          Caption = 'Open a file...'
          TabOrder = 2
          OnClick = OpenButtonClick
        end
        object SaveButton: TButton
          Left = 16
          Top = 146
          Width = 164
          Height = 28
          Caption = 'Save a file...'
          TabOrder = 3
          OnClick = SaveButtonClick
        end
        object FolderButton: TButton
          Left = 16
          Top = 182
          Width = 164
          Height = 28
          Caption = 'Choose a folder...'
          TabOrder = 4
          OnClick = FolderButtonClick
        end
      end
    end
    object LookPage: TPanel
      Tag = 13
      Left = 16
      Top = 80
      Width = 752
      Height = 337
      Align = alClient
      BevelOuter = bvNone
      ParentColor = True
      TabOrder = 6
      Visible = False
      ParentBackground = False
      object ViewsCard: TPanel
        Tag = 1
        Left = 0
        Top = 0
        Width = 752
        Height = 240
        Anchors = [akLeft, akTop, akRight, akBottom]
        BevelOuter = bvNone
        Color = clWindow
        TabOrder = 0
        ParentBackground = False
        object ViewsTitle: TLabel
          Left = 16
          Top = 12
          Width = 174
          Height = 17
          Caption = 'Explorer-style list and tree'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI Semibold'
          Font.Style = []
          ParentFont = False
        end
        object AreaList: TListView
          Left = 16
          Top = 38
          Width = 452
          Height = 190
          Anchors = [akLeft, akTop, akRight, akBottom]
          BorderStyle = bsNone
          Columns = <
            item
              Caption = 'Area'
              Width = 120
            end
            item
              Caption = 'Units'
              Width = 310
            end>
          ReadOnly = True
          RowSelect = True
          SmallImages = SetImages
          TabOrder = 0
          ViewStyle = vsReport
        end
        object AreaTree: TTreeView
          Left = 484
          Top = 38
          Width = 252
          Height = 190
          Anchors = [akTop, akRight, akBottom]
          BorderStyle = bsNone
          Indent = 19
          ReadOnly = True
          TabOrder = 1
        end
      end
      object TitleCard: TPanel
        Tag = 1
        Left = 0
        Top = 252
        Width = 752
        Height = 56
        Anchors = [akLeft, akRight, akBottom]
        BevelOuter = bvNone
        Color = clWindow
        TabOrder = 1
        ParentBackground = False
        object DarkTitle: TCheckBox
          Left = 16
          Top = 18
          Width = 400
          Height = 19
          Caption = 'Dark title bar'
          TabOrder = 0
          OnClick = DarkTitleClick
        end
      end
    end
    object SystemPage: TPanel
      Tag = 14
      Left = 16
      Top = 80
      Width = 752
      Height = 337
      Align = alClient
      BevelOuter = bvNone
      ParentColor = True
      TabOrder = 7
      Visible = False
      ParentBackground = False
      object SystemCard: TPanel
        Tag = 1
        Left = 0
        Top = 0
        Width = 752
        Height = 329
        Anchors = [akLeft, akTop, akRight, akBottom]
        BevelOuter = bvNone
        Color = clWindow
        TabOrder = 0
        ParentBackground = False
        object SystemTitle: TLabel
          Left = 16
          Top = 12
          Width = 85
          Height = 17
          Caption = 'This computer'
          Font.Charset = DEFAULT_CHARSET
          Font.Color = clWindowText
          Font.Height = -13
          Font.Name = 'Segoe UI Semibold'
          Font.Style = []
          ParentFont = False
        end
        object SystemHost: TPanel
          Left = 16
          Top = 36
          Width = 720
          Height = 283
          Anchors = [akLeft, akTop, akRight, akBottom]
          BevelOuter = bvNone
          ParentColor = True
          TabOrder = 0
          ParentBackground = False
        end
      end
    end
  end
  object SetImages: TImageList
    Left = 920
    Top = 8
  end
  object Images: TImageList
    Left = 888
    Top = 8
  end
  object OpenDialog: TOpenDialog
    Filter = 'All files (*.*)|*.*'
    Left = 856
    Top = 8
  end
  object SaveDialog: TSaveDialog
    Filter = 'All files (*.*)|*.*'
    Left = 824
    Top = 8
  end
end
