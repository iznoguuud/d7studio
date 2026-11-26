object GitHistoryView: TGitHistoryView
  Left = 340
  Top = 160
  Width = 640
  Height = 520
  Caption = 'Git History'
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
    Top = 292
    Width = 632
    Height = 3
    Cursor = crVSplit
    Align = alBottom
    MinSize = 60
  end
  object TopBar: TPanel
    Left = 0
    Top = 0
    Width = 632
    Height = 24
    Align = alTop
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 0
    OnResize = TopBarResize
    object ScopeLabel: TLabel
      Left = 124
      Top = 1
      Width = 502
      Height = 22
      Alignment = taRightJustify
      AutoSize = False
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clGrayText
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ParentShowHint = False
      ShowHint = True
      Layout = tlCenter
    end
    object HistBar: TToolBar
      Left = 0
      Top = 1
      Width = 116
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
      object RefreshButton: TToolButton
        Left = 0
        Top = 0
        Action = aRefresh
      end
      object Sep1: TToolButton
        Left = 23
        Top = 0
        Width = 8
        Style = tbsSeparator
      end
      object AllButton: TToolButton
        Left = 31
        Top = 0
        Action = aAllBranches
        Style = tbsCheck
      end
      object RepoButton: TToolButton
        Left = 54
        Top = 0
        Action = aRepository
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
        Action = aCopyId
      end
    end
  end
  object ListPanel: TPanel
    Left = 0
    Top = 24
    Width = 632
    Height = 268
    Align = alClient
    BevelOuter = bvNone
    BorderStyle = bsSingle
    Color = clWindow
    Ctl3D = False
    ParentBackground = False
    ParentCtl3D = False
    TabOrder = 1
    OnResize = ListPanelResize
    object CommitList: TListView
      Left = 0
      Top = 0
      Width = 630
      Height = 266
      Align = alClient
      BorderStyle = bsNone
      Columns = <
        item
          Caption = 'Message'
          Width = 340
        end
        item
          Caption = 'Author'
          Width = 120
        end
        item
          Caption = 'Date'
          Width = 108
        end
        item
          Caption = 'Commit'
          Width = 60
        end>
      HideSelection = False
      OwnerData = True
      ReadOnly = True
      RowSelect = True
      PopupMenu = CommitMenu
      TabOrder = 0
      ViewStyle = vsReport
      OnCustomDrawItem = CommitListCustomDrawItem
      OnData = CommitListData
      OnDblClick = CommitListDblClick
      OnKeyDown = ListKeyDown
      OnSelectItem = CommitListSelectItem
    end
  end
  object DetailPanel: TPanel
    Left = 0
    Top = 295
    Width = 632
    Height = 170
    Align = alBottom
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
    object InfoPanel: TPanel
      Left = 0
      Top = 0
      Width = 632
      Height = 72
      Align = alTop
      BevelOuter = bvNone
      BorderStyle = bsSingle
      BorderWidth = 4
      Color = clWindow
      Ctl3D = False
      ParentBackground = False
      ParentCtl3D = False
      TabOrder = 0
      object InfoMemo: TMemo
        Left = 4
        Top = 4
        Width = 622
        Height = 62
        Align = alClient
        BorderStyle = bsNone
        ReadOnly = True
        ScrollBars = ssVertical
        TabOrder = 0
      end
    end
    object Gap: TPanel
      Left = 0
      Top = 72
      Width = 632
      Height = 2
      Align = alTop
      BevelOuter = bvNone
      Color = clBtnFace
      ParentBackground = False
      TabOrder = 1
    end
    object FilesList: TListBox
      Left = 0
      Top = 74
      Width = 632
      Height = 96
      Style = lbVirtualOwnerDraw
      Align = alClient
      Ctl3D = False
      ItemHeight = 19
      ParentCtl3D = False
      PopupMenu = FilesMenu
      TabOrder = 2
      OnDblClick = FilesListDblClick
      OnDrawItem = FilesListDrawItem
      OnKeyDown = ListKeyDown
    end
  end
  object StatusPanel: TPanel
    Left = 0
    Top = 465
    Width = 632
    Height = 21
    Align = alBottom
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 3
    DesignSize = (
      632
      21)
    object StatusLabel: TLabel
      Left = 4
      Top = 3
      Width = 624
      Height = 15
      Anchors = [akLeft, akTop, akRight]
      AutoSize = False
    end
  end
  object Actions: TActionList
    Images = Icons
    Left = 32
    Top = 112
    object aRefresh: TAction
      Caption = '&Refresh'
      Hint = 'Read the history again'
      ImageIndex = 0
      OnExecute = aRefreshExecute
      OnUpdate = aRefreshUpdate
    end
    object aAllBranches: TAction
      Caption = '&All Branches'
      Hint = 'The commits of every branch and tag, not only of the current branch'
      ImageIndex = 1
      OnExecute = aAllBranchesExecute
      OnUpdate = aRefreshUpdate
    end
    object aRepository: TAction
      Caption = '&Whole Repository'
      Hint = 'The history of the whole repository, not of one file'
      ImageIndex = 2
      OnExecute = aRepositoryExecute
      OnUpdate = aRepositoryUpdate
    end
    object aCopyId: TAction
      Caption = 'Copy Commit &Id'
      Hint = 'Copy the commit'#39's id'
      ImageIndex = 3
      OnExecute = aCopyIdExecute
      OnUpdate = CommitCommandUpdate
    end
    object aShowCommit: TAction
      Caption = '&Show Changes'
      Hint = 'Show the changes of the commit (Enter)'
      ImageIndex = 4
      OnExecute = aShowCommitExecute
      OnUpdate = CommitCommandUpdate
    end
    object aCopyMessage: TAction
      Caption = 'Copy &Message'
      Hint = 'Copy the commit'#39's message'
      OnExecute = aCopyMessageExecute
      OnUpdate = CommitCommandUpdate
    end
    object aNewBranchHere: TAction
      Caption = '&New Branch Here...'
      Hint = 'Create a branch that starts at this commit'
      OnExecute = aNewBranchHereExecute
      OnUpdate = CommitCommandUpdate
    end
    object aShowFile: TAction
      Caption = '&Show Diff'
      Hint = 'Show the changes of the file in the commit (Enter)'
      ImageIndex = 4
      OnExecute = aShowFileExecute
      OnUpdate = aShowFileUpdate
    end
    object aOpenFile: TAction
      Caption = '&Open File'
      Hint = 'Open the file as it is now in the editor'
      ImageIndex = 5
      OnExecute = aOpenFileExecute
      OnUpdate = aShowFileUpdate
    end
  end
  object Icons: TImageList
    Left = 72
    Top = 112
  end
  object IconsDisabled: TImageList
    Left = 112
    Top = 112
  end
  object CommitMenu: TPopupMenu
    Images = Icons
    Left = 152
    Top = 112
    object miShowCommit: TMenuItem
      Action = aShowCommit
      Default = True
    end
    object miCopyId: TMenuItem
      Action = aCopyId
    end
    object miCopyMessage: TMenuItem
      Action = aCopyMessage
    end
    object miSep1: TMenuItem
      Caption = '-'
    end
    object miNewBranchHere: TMenuItem
      Action = aNewBranchHere
    end
  end
  object FilesMenu: TPopupMenu
    Images = Icons
    Left = 192
    Top = 112
    object miShowFile: TMenuItem
      Action = aShowFile
      Default = True
    end
    object miOpenFile: TMenuItem
      Action = aOpenFile
    end
  end
end
