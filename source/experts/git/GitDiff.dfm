object GitDiffView: TGitDiffView
  Left = 360
  Top = 180
  Width = 640
  Height = 480
  Caption = 'Git Diff'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 15
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
    object InfoLabel: TLabel
      Left = 116
      Top = 1
      Width = 510
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
    object DiffBar: TToolBar
      Left = 0
      Top = 1
      Width = 108
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
      object PrevButton: TToolButton
        Left = 0
        Top = 0
        Action = aPrev
      end
      object NextButton: TToolButton
        Left = 23
        Top = 0
        Action = aNext
      end
      object Sep1: TToolButton
        Left = 46
        Top = 0
        Width = 8
        Style = tbsSeparator
      end
      object OpenButton: TToolButton
        Left = 54
        Top = 0
        Action = aOpen
      end
      object Sep2: TToolButton
        Left = 77
        Top = 0
        Width = 8
        Style = tbsSeparator
      end
      object RefreshButton: TToolButton
        Left = 85
        Top = 0
        Action = aRefresh
      end
    end
  end
  object DiffList: TListBox
    Left = 0
    Top = 24
    Width = 632
    Height = 401
    Style = lbVirtualOwnerDraw
    Align = alClient
    Ctl3D = False
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Consolas'
    Font.Style = []
    ItemHeight = 18
    ParentCtl3D = False
    ParentFont = False
    PopupMenu = DiffMenu
    TabOrder = 1
    OnDblClick = DiffListDblClick
    OnDrawItem = DiffListDrawItem
    OnKeyDown = DiffListKeyDown
  end
  object StatusPanel: TPanel
    Left = 0
    Top = 425
    Width = 632
    Height = 21
    Align = alBottom
    BevelOuter = bvNone
    Color = clBtnFace
    ParentBackground = False
    TabOrder = 2
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
    Top = 96
    object aPrev: TAction
      Caption = '&Previous Change'
      Hint = 'Go to the previous change'
      ImageIndex = 0
      OnExecute = aPrevExecute
      OnUpdate = aMoveUpdate
    end
    object aNext: TAction
      Caption = '&Next Change'
      Hint = 'Go to the next change'
      ImageIndex = 1
      OnExecute = aNextExecute
      OnUpdate = aMoveUpdate
    end
    object aOpen: TAction
      Caption = '&Open in Editor'
      Hint = 'Open the file in the editor at this line (Enter)'
      ImageIndex = 2
      OnExecute = aOpenExecute
      OnUpdate = aOpenUpdate
    end
    object aRefresh: TAction
      Caption = '&Refresh'
      Hint = 'Read the changes again'
      ImageIndex = 3
      OnExecute = aRefreshExecute
      OnUpdate = aRefreshUpdate
    end
    object aCopy: TAction
      Caption = '&Copy'
      Hint = 'Copy the line'
      ImageIndex = 4
      OnExecute = aCopyExecute
      OnUpdate = aMoveUpdate
    end
  end
  object Icons: TImageList
    Left = 72
    Top = 96
  end
  object IconsDisabled: TImageList
    Left = 112
    Top = 96
  end
  object DiffMenu: TPopupMenu
    Images = Icons
    Left = 152
    Top = 96
    object miOpen: TMenuItem
      Action = aOpen
      Default = True
    end
    object miCopy: TMenuItem
      Action = aCopy
    end
    object miSep1: TMenuItem
      Caption = '-'
    end
    object miPrev: TMenuItem
      Action = aPrev
    end
    object miNext: TMenuItem
      Action = aNext
    end
  end
end
