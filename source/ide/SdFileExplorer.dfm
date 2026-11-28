object FileExplorerView: TFileExplorerView
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'File Explorer'
  ClientHeight = 300
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
    Align = alNone
    ButtonHeight = 38
    ButtonWidth = 50
    Caption = 'File Explorer'
    EdgeBorders = []
    Flat = True
    ParentShowHint = False
    ShowCaptions = True
    ShowHint = True
    TabOrder = 0
    Wrapable = False
    Transparent = False
    object tbRefresh: TToolButton
      Left = 0
      Top = 0
      Action = aFxRefresh
      Caption = 'Refresh'
    end
    object tbLocate: TToolButton
      Left = 50
      Top = 0
      Action = aFxLocate
      Caption = 'Locate'
    end
    object tbPin: TToolButton
      Left = 100
      Top = 0
      Action = aFxPinFolder
      Caption = 'Pin'
    end
    object tbShow: TToolButton
      Left = 150
      Top = 0
      Action = aFxShowMenu
      DropdownMenu = ShowPopup
      Style = tbsDropDown
    end
  end
  object FilterEdit: TEdit
    Left = 0
    Top = 40
    Width = 232
    Height = 23
    TabOrder = 1
    OnChange = FilterEditChange
    OnKeyDown = FilterEditKeyDown
  end
  object Tree: TTreeView
    Left = 0
    Top = 65
    Width = 232
    Height = 235
    HideSelection = False
    Indent = 19
    PopupMenu = FxPopup
    TabOrder = 2
    OnChange = TreeChange
    OnDblClick = TreeDblClick
    OnEdited = TreeEdited
    OnEditing = TreeEditing
    OnExpanding = TreeExpanding
    OnKeyDown = TreeKeyDown
  end
  object Watch: TTimer
    Interval = 500
    OnTimer = WatchTimer
    Left = 168
    Top = 104
  end
  object Actions: TActionList
    OnUpdate = ActionsUpdate
    Left = 24
    Top = 104
    object aFxOpen: TAction
      Category = 'File Explorer'
      Caption = '&Open'
      Hint = 'Open the file'
      ImageIndex = 1
      OnExecute = Command
    end
    object aFxOpenShell: TAction
      Category = 'File Explorer'
      Caption = 'Open with &Windows'
      Hint = 'Open the file or folder with the program Windows has for it'
      OnExecute = Command
    end
    object aFxAddToProject: TAction
      Category = 'File Explorer'
      Caption = '&Add to Project'
      Hint = 'Add the unit or resource script to the active project'
      ImageIndex = 5
      OnExecute = Command
    end
    object aFxNewFile: TAction
      Category = 'File Explorer'
      Caption = 'New &File...'
      Hint = 'Make a file in the folder'
      ImageIndex = 0
      OnExecute = Command
    end
    object aFxNewFolder: TAction
      Category = 'File Explorer'
      Caption = 'New Fol&der...'
      Hint = 'Make a folder in the folder'
      ImageIndex = 266
      OnExecute = Command
    end
    object aFxRename: TAction
      Category = 'File Explorer'
      Caption = '&Rename'
      Hint = 'Rename the file or folder (a unit with Rename Unit)'
      ImageIndex = 189
      OnExecute = Command
    end
    object aFxDelete: TAction
      Category = 'File Explorer'
      Caption = 'D&elete'
      Hint = 'Move the file or folder to the Recycle Bin'
      ImageIndex = 12
      OnExecute = Command
    end
    object aFxCopyPath: TAction
      Category = 'File Explorer'
      Caption = '&Copy Path'
      Hint = 'Copy the full name to the clipboard'
      ImageIndex = 10
      OnExecute = Command
    end
    object aFxShowInExplorer: TAction
      Category = 'File Explorer'
      Caption = 'Show in E&xplorer'
      Hint = 'Show the file or folder in Windows Explorer'
      ImageIndex = 44
      OnExecute = Command
    end
    object aFxCommandPrompt: TAction
      Category = 'File Explorer'
      Caption = 'Command &Prompt Here'
      Hint = 'Open a command prompt in the folder'
      ImageIndex = 229
      OnExecute = Command
    end
    object aFxFindInFiles: TAction
      Category = 'File Explorer'
      Caption = 'F&ind in Files Here...'
      Hint = 'Search the files of the folder and the folders below it'
      ImageIndex = 156
      OnExecute = Command
    end
    object aFxPinFolder: TAction
      Category = 'File Explorer'
      Caption = 'Pi&n Folder...'
      Hint = 'Show another folder in the tree'
      ImageIndex = 263
      OnExecute = Command
    end
    object aFxPinSelected: TAction
      Category = 'File Explorer'
      Caption = 'Pin &This Folder'
      Hint = 'Show the folder at the top of the tree'
      ImageIndex = 263
      OnExecute = Command
    end
    object aFxUnpin: TAction
      Category = 'File Explorer'
      Caption = '&Unpin Folder'
      Hint = 'Take the pinned folder out of the tree'
      ImageIndex = 264
      OnExecute = Command
    end
    object aFxLocate: TAction
      Category = 'File Explorer'
      Caption = '&Locate Active File'
      Hint = 'Choose the file shown in the file area'
      ImageIndex = 262
      OnExecute = Command
    end
    object aFxFollow: TAction
      Category = 'File Explorer'
      Caption = 'F&ollow the Editor'
      Hint = 'Choose the file shown in the file area whenever it changes'
      ImageIndex = 268
      OnExecute = Command
    end
    object aFxCollapseAll: TAction
      Category = 'File Explorer'
      Caption = 'Colla&pse All'
      Hint = 'Close every folder'
      ImageIndex = 172
      OnExecute = Command
    end
    object aFxRefresh: TAction
      Category = 'File Explorer'
      Caption = 'Re&fresh'
      Hint = 'Read the folders again'
      ImageIndex = 261
      OnExecute = Command
    end
    object aFxShowMenu: TAction
      Category = 'File Explorer'
      Caption = 'Show'
      Hint = 'What the tree shows'
      ImageIndex = 267
      OnExecute = Command
    end
    object aFxDelphiOnly: TAction
      Category = 'File Explorer'
      Caption = '&Delphi Files Only'
      Hint = 'Show only Delphi'#39's files (units, forms, projects, resources)'
      OnExecute = Command
    end
    object aFxShowOutput: TAction
      Category = 'File Explorer'
      Caption = '&Build Output'
      Hint = 'Show compiled units, programs, packages, maps and backups'
      OnExecute = Command
    end
    object aFxShowHidden: TAction
      Category = 'File Explorer'
      Caption = '&Hidden Files'
      Hint = 'Show hidden files and those whose names begin with a dot'
      OnExecute = Command
    end
  end
  object FxPopup: TPopupMenu
    OnPopup = MenuPopup
    Left = 80
    Top = 104
    object pmOpen: TMenuItem
      Action = aFxOpen
      Default = True
    end
    object pmOpenShell: TMenuItem
      Action = aFxOpenShell
    end
    object pmAddToProject: TMenuItem
      Action = aFxAddToProject
    end
    object pmSep1: TMenuItem
      Caption = '-'
    end
    object pmNewFile: TMenuItem
      Action = aFxNewFile
    end
    object pmNewFolder: TMenuItem
      Action = aFxNewFolder
    end
    object pmRename: TMenuItem
      Action = aFxRename
    end
    object pmDelete: TMenuItem
      Action = aFxDelete
    end
    object pmSep2: TMenuItem
      Caption = '-'
    end
    object pmCopyPath: TMenuItem
      Action = aFxCopyPath
    end
    object pmShowInExplorer: TMenuItem
      Action = aFxShowInExplorer
    end
    object pmCommandPrompt: TMenuItem
      Action = aFxCommandPrompt
    end
    object pmFindInFiles: TMenuItem
      Action = aFxFindInFiles
    end
    object pmSep3: TMenuItem
      Caption = '-'
    end
    object pmPinSelected: TMenuItem
      Action = aFxPinSelected
    end
    object pmPinFolder: TMenuItem
      Action = aFxPinFolder
    end
    object pmUnpin: TMenuItem
      Action = aFxUnpin
    end
    object pmSep4: TMenuItem
      Caption = '-'
    end
    object pmLocate: TMenuItem
      Action = aFxLocate
    end
    object pmFollow: TMenuItem
      Action = aFxFollow
    end
    object pmCollapseAll: TMenuItem
      Action = aFxCollapseAll
    end
    object pmRefresh: TMenuItem
      Action = aFxRefresh
    end
    object pmShow: TMenuItem
      Caption = '&Show'
      ImageIndex = 267
      object pmShowDelphiOnly: TMenuItem
        Action = aFxDelphiOnly
      end
      object pmShowOutput: TMenuItem
        Action = aFxShowOutput
      end
      object pmShowHidden: TMenuItem
        Action = aFxShowHidden
      end
    end
  end
  object ShowPopup: TPopupMenu
    Left = 128
    Top = 104
    object spDelphiOnly: TMenuItem
      Action = aFxDelphiOnly
    end
    object spShowOutput: TMenuItem
      Action = aFxShowOutput
    end
    object spShowHidden: TMenuItem
      Action = aFxShowHidden
    end
  end
end
