object ProjectManagerView: TProjectManagerView
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Project Manager'
  ClientHeight = 200
  ClientWidth = 232
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
  object Bar: TToolBar
    Left = 0
    Top = 0
    Width = 232
    Height = 40
    ButtonHeight = 38
    ButtonWidth = 50
    Caption = 'Project Manager'
    EdgeBorders = []
    Flat = True
    ParentShowHint = False
    ShowCaptions = True
    ShowHint = True
    TabOrder = 0
    Wrapable = False
    Transparent = False
    object tbPMNew: TToolButton
      Left = 0
      Top = 0
      Caption = 'New'
    end
    object tbPMRemove: TToolButton
      Left = 50
      Top = 0
      Action = aRemoveProject
      Caption = 'Remove'
    end
    object tbPMActivate: TToolButton
      Left = 100
      Top = 0
      Action = aActivateProject
      Caption = 'Activate'
    end
  end
  object Tree: TTreeView
    Left = 0
    Top = 40
    Width = 232
    Height = 160
    Align = alClient
    HideSelection = False
    Indent = 19
    PopupMenu = ProjPopup
    ReadOnly = True
    TabOrder = 1
    OnChange = TreeChange
    OnCustomDrawItem = TreeCustomDrawItem
    OnDblClick = TreeDblClick
  end
  object Actions: TActionList
    Left = 24
    Top = 24
    object aSaveGroup: TAction
      Category = 'Project'
      Caption = '&Save Project Group'
      Hint = 'Save the project group'
      OnExecute = CommandExecute
    end
    object aSaveGroupAs: TAction
      Category = 'Project'
      Caption = 'Save Project Group &As...'
      Hint = 'Save the project group under another name'
      OnExecute = CommandExecute
    end
    object aActivateProject: TAction
      Category = 'Project'
      Caption = 'Ac&tivate'
      Hint = 'Make the selected project the active one'
      ImageIndex = 40
      OnExecute = CommandExecute
    end
    object aRemoveProject: TAction
      Category = 'Project'
      Caption = '&Remove Project'
      Hint = 'Take the selected project out of the group'
      ImageIndex = 12
      OnExecute = CommandExecute
    end
    object aPMSave: TAction
      Category = 'Project'
      Caption = '&Save'
      Hint = 'Save the selected project'
      ImageIndex = 2
      OnExecute = CommandExecute
    end
    object aPMOptions: TAction
      Category = 'Project'
      Caption = '&Options...'
      Hint = 'Options of the selected project'
      ImageIndex = 16
      OnExecute = CommandExecute
    end
    object aPMCompile: TAction
      Category = 'Project'
      Caption = '&Compile'
      Hint = 'Compile the selected project'
      ImageIndex = 33
      OnExecute = CommandExecute
    end
    object aPMBuild: TAction
      Category = 'Project'
      Caption = '&Build'
      Hint = 'Build the selected project'
      ImageIndex = 34
      OnExecute = CommandExecute
    end
    object aPMViewSource: TAction
      Category = 'Project'
      Caption = '&View Source'
      Hint = 'View the source of the selected project'
      ImageIndex = 122
      OnExecute = CommandExecute
    end
    object aPMStatusBar: TAction
      Category = 'Project'
      Caption = 'Stat&us Bar'
      Hint = 'Show the status bar of the Project Manager'
      OnExecute = StatusBarExecute
    end
  end
  object ProjPopup: TPopupMenu
    OnPopup = ProjPopupPopup
    Left = 72
    Top = 24
    object pmProjG1: TMenuItem
    end
    object pmProjG2: TMenuItem
    end
    object pmProjG3: TMenuItem
      Action = aSaveGroup
    end
    object pmProjG4: TMenuItem
      Action = aSaveGroupAs
    end
    object pmProjG9: TMenuItem
      Caption = '-'
    end
    object pmProjG10: TMenuItem
    end
    object pmProjG11: TMenuItem
    end
    object pmProjG5: TMenuItem
      Caption = '-'
    end
    object pmProjP1: TMenuItem
      Action = aPMSave
    end
    object pmProjP2: TMenuItem
      Action = aPMOptions
    end
    object pmProjP3: TMenuItem
      Caption = '-'
    end
    object pmProjG6: TMenuItem
      Action = aActivateProject
    end
    object pmProjP4: TMenuItem
      Action = aPMCompile
    end
    object pmProjP5: TMenuItem
      Action = aPMBuild
    end
    object pmProjP6: TMenuItem
      Action = aPMViewSource
    end
    object pmProjG7: TMenuItem
      Action = aRemoveProject
    end
    object pmProjG8: TMenuItem
      Caption = '-'
    end
    object pmProj1: TMenuItem
      Action = aPMStatusBar
    end
  end
end
