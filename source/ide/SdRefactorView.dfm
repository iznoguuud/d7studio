object RefactoringsView: TRefactoringsView
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Refactorings'
  ClientHeight = 180
  ClientWidth = 640
  Color = clBtnFace
  DefaultMonitor = dmDesktop
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 15
  object Splitter: TSplitter
    Left = 320
    Top = 40
    Height = 140
  end
  object Bar: TToolBar
    Left = 0
    Top = 0
    Width = 640
    Height = 40
    ButtonHeight = 38
    ButtonWidth = 50
    Caption = 'Refactorings'
    EdgeBorders = []
    Flat = True
    ParentShowHint = False
    ShowCaptions = True
    ShowHint = True
    TabOrder = 0
    Wrapable = False
    Transparent = False
    object tbApply: TToolButton
      Left = 0
      Top = 0
      Action = aApply
    end
    object tbDiscard: TToolButton
      Left = 50
      Top = 0
      Action = aDiscard
    end
  end
  object Tree: TTreeView
    Left = 0
    Top = 40
    Width = 320
    Height = 140
    Align = alLeft
    HideSelection = False
    Indent = 19
    PopupMenu = RefPopup
    ReadOnly = True
    ShowRoot = False
    TabOrder = 1
    OnChange = TreeChange
    OnDblClick = TreeDblClick
  end
  object DiffHost: TPanel
    Left = 323
    Top = 40
    Width = 317
    Height = 140
    Align = alClient
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 2
  end
  object Actions: TActionList
    OnUpdate = ActionsUpdate
    Left = 40
    Top = 80
    object aApply: TAction
      Caption = 'Apply'
      Hint = 'Apply the refactoring'
      ImageIndex = 35
      OnExecute = aApplyExecute
    end
    object aDiscard: TAction
      Caption = 'Discard'
      Hint = 'Discard the refactoring'
      ImageIndex = 84
      OnExecute = aDiscardExecute
    end
  end
  object RefPopup: TPopupMenu
    OnPopup = RefPopupPopup
    Left = 104
    Top = 80
    object pmApply: TMenuItem
      Action = aApply
    end
    object pmDiscard: TMenuItem
      Action = aDiscard
    end
  end
end
