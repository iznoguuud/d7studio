object GitChangesView: TGitChangesView
  Left = 320
  Top = 140
  Width = 360
  Height = 560
  Caption = 'Git'
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
    Top = 94
    Width = 352
    Height = 3
    Cursor = crVSplit
    Align = alTop
    MinSize = 40
  end
  object TopBar: TPanel
    Left = 0
    Top = 0
    Width = 352
    Height = 24
    Align = alTop
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 0
    OnResize = TopBarResize
    object BranchLabel: TLabel
      Left = 262
      Top = 1
      Width = 84
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
    object MainBar: TToolBar
      Left = 0
      Top = 1
      Width = 254
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
      object CommitBarButton: TToolButton
        Left = 31
        Top = 0
        Action = aCommit
      end
      object Sep2: TToolButton
        Left = 54
        Top = 0
        Width = 8
        Style = tbsSeparator
      end
      object FetchButton: TToolButton
        Left = 62
        Top = 0
        Action = aFetch
      end
      object PullButton: TToolButton
        Left = 85
        Top = 0
        Action = aPull
      end
      object PushButton: TToolButton
        Left = 108
        Top = 0
        Action = aPush
      end
      object Sep3: TToolButton
        Left = 131
        Top = 0
        Width = 8
        Style = tbsSeparator
      end
      object BranchButton: TToolButton
        Left = 139
        Top = 0
        Action = aBranch
        DropdownMenu = BranchMenu
        Style = tbsDropDown
      end
      object StashButton: TToolButton
        Left = 175
        Top = 0
        Action = aStash
        DropdownMenu = StashMenu
        Style = tbsDropDown
      end
      object Sep4: TToolButton
        Left = 211
        Top = 0
        Width = 8
        Style = tbsSeparator
      end
      object HistoryButton: TToolButton
        Left = 219
        Top = 0
        Action = aHistory
      end
    end
  end
  object MessagePanel: TPanel
    Left = 0
    Top = 24
    Width = 352
    Height = 70
    Align = alTop
    BevelOuter = bvNone
    BorderStyle = bsSingle
    BorderWidth = 6
    Color = clWindow
    Ctl3D = False
    ParentBackground = False
    ParentCtl3D = False
    TabOrder = 1
    object MessageMemo: TMemo
      Left = 6
      Top = 6
      Width = 264
      Height = 56
      Align = alClient
      BorderStyle = bsNone
      TabOrder = 0
      OnChange = MessageMemoChange
      OnKeyDown = MessageMemoKeyDown
    end
    object CommitSide: TPanel
      Left = 270
      Top = 6
      Width = 74
      Height = 56
      Align = alRight
      BevelOuter = bvNone
      Color = clWindow
      ParentBackground = False
      TabOrder = 1
      object CommitButton: TButton
        Left = 2
        Top = 0
        Width = 72
        Height = 26
        Action = aCommit
        TabOrder = 0
      end
      object AmendBox: TCheckBox
        Left = 4
        Top = 32
        Width = 70
        Height = 19
        Caption = '&Amend'
        TabOrder = 1
        OnClick = AmendBoxClick
      end
    end
  end
  object ChangesList: TListBox
    Left = 0
    Top = 97
    Width = 352
    Height = 408
    Style = lbVirtualOwnerDraw
    Align = alClient
    Ctl3D = False
    ItemHeight = 19
    MultiSelect = True
    ParentCtl3D = False
    PopupMenu = ChangesMenu
    TabOrder = 2
    OnDblClick = ChangesListDblClick
    OnDrawItem = ChangesListDrawItem
    OnKeyDown = ChangesListKeyDown
    OnMouseDown = ChangesListMouseDown
  end
  object EmptyPanel: TPanel
    Left = 0
    Top = 97
    Width = 352
    Height = 408
    Align = alClient
    BevelOuter = bvNone
    BorderStyle = bsSingle
    Color = clWindow
    Ctl3D = False
    ParentBackground = False
    ParentCtl3D = False
    TabOrder = 3
    Visible = False
    OnResize = EmptyPanelResize
    DesignSize = (
      350
      406)
    object EmptyLabel: TLabel
      Left = 12
      Top = 12
      Width = 326
      Height = 45
      Anchors = [akLeft, akTop, akRight]
      AutoSize = False
      WordWrap = True
    end
    object EmptyButton: TButton
      Left = 12
      Top = 64
      Width = 140
      Height = 26
      Action = aInit
      TabOrder = 0
    end
  end
  object StatusPanel: TPanel
    Left = 0
    Top = 505
    Width = 352
    Height = 21
    Align = alBottom
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 4
    DesignSize = (
      352
      21)
    object StatusLabel: TLabel
      Left = 4
      Top = 3
      Width = 344
      Height = 15
      Anchors = [akLeft, akTop, akRight]
      AutoSize = False
    end
  end
  object Actions: TActionList
    Images = Icons
    Left = 32
    Top = 160
    object aRefresh: TAction
      Caption = '&Refresh'
      Hint = 'Read the status of the repository again'
      ImageIndex = 0
      OnExecute = aRefreshExecute
    end
    object aCommit: TAction
      Caption = '&Commit'
      Hint = 'Commit the staged changes with the message (Ctrl+Enter)'
      ImageIndex = 1
      OnExecute = aCommitExecute
      OnUpdate = aCommitUpdate
    end
    object aFetch: TAction
      Caption = '&Fetch'
      Hint = 'Fetch the branches of the remotes'
      ImageIndex = 2
      OnExecute = aFetchExecute
      OnUpdate = RepoCommandUpdate
    end
    object aPull: TAction
      Caption = '&Pull'
      Hint = 'Pull the upstream branch into the current one'
      ImageIndex = 3
      OnExecute = aPullExecute
      OnUpdate = RepoCommandUpdate
    end
    object aPush: TAction
      Caption = 'P&ush'
      Hint = 'Push the current branch to its upstream'
      ImageIndex = 4
      OnExecute = aPushExecute
      OnUpdate = RepoCommandUpdate
    end
    object aBranch: TAction
      Caption = '&Branch'
      Hint = 'Switch to, create or delete a branch'
      ImageIndex = 5
      OnExecute = aBranchExecute
      OnUpdate = RepoCommandUpdate
    end
    object aStash: TAction
      Caption = '&Stash'
      Hint = 'Stash the changes, or bring a stash back'
      ImageIndex = 6
      OnExecute = aStashExecute
      OnUpdate = RepoCommandUpdate
    end
    object aHistory: TAction
      Caption = '&History'
      Hint = 'The history of the repository'
      ImageIndex = 7
      OnExecute = aHistoryExecute
      OnUpdate = aHistoryUpdate
    end
    object aOpen: TAction
      Caption = '&Open'
      Hint = 'Open the file in the editor'
      ImageIndex = 8
      OnExecute = aOpenExecute
      OnUpdate = aOpenUpdate
    end
    object aDiff: TAction
      Caption = 'Show &Diff'
      Hint = 'Show the changes of the file (Enter)'
      ImageIndex = 9
      OnExecute = aDiffExecute
      OnUpdate = aDiffUpdate
    end
    object aStage: TAction
      Caption = '&Stage'
      Hint = 'Stage the changes (Space)'
      ImageIndex = 10
      OnExecute = aStageExecute
      OnUpdate = aStageUpdate
    end
    object aUnstage: TAction
      Caption = '&Unstage'
      Hint = 'Take the changes out of the index (Space)'
      ImageIndex = 11
      OnExecute = aUnstageExecute
      OnUpdate = aUnstageUpdate
    end
    object aDiscard: TAction
      Caption = 'Disca&rd Changes...'
      Hint = 'Undo the changes of the files (Delete)'
      ImageIndex = 12
      OnExecute = aDiscardExecute
      OnUpdate = aDiscardUpdate
    end
    object aFileHistory: TAction
      Caption = 'File &History'
      Hint = 'The history of the file'
      ImageIndex = 7
      OnExecute = aFileHistoryExecute
      OnUpdate = aDiffUpdate
    end
    object aBlame: TAction
      Caption = '&Blame'
      Hint = 'Who changed each line of the file, and when'
      ImageIndex = 13
      OnExecute = aBlameExecute
      OnUpdate = aDiffUpdate
    end
    object aCopyPath: TAction
      Caption = 'Copy &Path'
      Hint = 'Copy the full paths of the files'
      ImageIndex = 14
      OnExecute = aCopyPathExecute
      OnUpdate = aOpenUpdate
    end
    object aAbort: TAction
      Caption = '&Abort'
      Hint = 'Abandon the merge, rebase, cherry-pick or revert that is going on'
      OnExecute = aAbortExecute
      OnUpdate = aAbortUpdate
    end
    object aStop: TAction
      Caption = 'Sto&p'
      Hint = 'Stop the fetch or push'
      ImageIndex = 16
      OnExecute = aStopExecute
      OnUpdate = aStopUpdate
    end
    object aSettings: TAction
      Caption = 'Se&ttings...'
      Hint = 'Where git.exe is, and when the view reads the status again'
      ImageIndex = 15
      OnExecute = aSettingsExecute
    end
    object aInit: TAction
      Caption = 'Create &Repository'
      Hint = 'Create a Git repository in the project'#39's folder'
      OnExecute = aInitExecute
    end
    object aNewBranch: TAction
      Caption = '&New Branch...'
      Hint = 'Create a branch'
      OnExecute = aNewBranchExecute
      OnUpdate = RepoCommandUpdate
    end
    object aStashSave: TAction
      Caption = '&Stash Changes...'
      Hint = 'Take the changes out of the work tree into a stash'
      OnExecute = aStashSaveExecute
      OnUpdate = RepoCommandUpdate
    end
    object aStashPop: TAction
      Caption = '&Pop Latest Stash'
      Hint = 'Bring the latest stash back into the work tree and drop it'
      OnExecute = aStashPopExecute
      OnUpdate = aStashPopUpdate
    end
  end
  object Icons: TImageList
    Left = 72
    Top = 160
  end
  object IconsDisabled: TImageList
    Left = 112
    Top = 160
  end
  object ChangesMenu: TPopupMenu
    Images = Icons
    Left = 152
    Top = 160
    object miDiff: TMenuItem
      Action = aDiff
      Default = True
    end
    object miOpen: TMenuItem
      Action = aOpen
    end
    object miSep1: TMenuItem
      Caption = '-'
    end
    object miStage: TMenuItem
      Action = aStage
    end
    object miUnstage: TMenuItem
      Action = aUnstage
    end
    object miDiscard: TMenuItem
      Action = aDiscard
    end
    object miSep2: TMenuItem
      Caption = '-'
    end
    object miFileHistory: TMenuItem
      Action = aFileHistory
    end
    object miBlame: TMenuItem
      Action = aBlame
    end
    object miSep3: TMenuItem
      Caption = '-'
    end
    object miCopyPath: TMenuItem
      Action = aCopyPath
    end
    object miSep4: TMenuItem
      Caption = '-'
    end
    object miAbort: TMenuItem
      Action = aAbort
    end
    object miStop: TMenuItem
      Action = aStop
    end
    object miSettings: TMenuItem
      Action = aSettings
    end
  end
  object BranchMenu: TPopupMenu
    OnPopup = BranchMenuPopup
    Left = 192
    Top = 160
  end
  object StashMenu: TPopupMenu
    OnPopup = StashMenuPopup
    Left = 232
    Top = 160
  end
end
