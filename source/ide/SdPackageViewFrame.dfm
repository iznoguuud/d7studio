inherited SdPackageView: TSdPackageView
  Width = 260
  Height = 156
  inherited Header: THeaderControl
    Top = 41
    Width = 258
    Sections = <
      item
        ImageIndex = -1
        MinWidth = 30
        Text = 'Files'
        Width = 150
      end
      item
        ImageIndex = -1
        MinWidth = 30
        Text = 'Path'
        Width = 108
      end>
  end
  inherited Tree: TTreeView
    Top = 58
    Width = 258
    Height = 97
    HideSelection = False
  end
  object Bar: TToolBar
    Left = 0
    Top = 0
    Width = 260
    Height = 40
    Align = alNone
    ButtonHeight = 38
    ButtonWidth = 50
    Caption = 'Package'
    EdgeBorders = []
    Flat = True
    ParentShowHint = False
    ShowCaptions = True
    ShowHint = True
    TabOrder = 2
    Wrapable = False
    Transparent = False
    object tbPkgCompile: TToolButton
      Left = 0
      Top = 0
    end
    object tbPkgSep1: TToolButton
      Left = 50
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object tbPkgAdd: TToolButton
      Left = 58
      Top = 0
    end
    object tbPkgRemove: TToolButton
      Left = 108
      Top = 0
    end
    object tbPkgSep2: TToolButton
      Left = 158
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object tbPkgInstall: TToolButton
      Left = 166
      Top = 0
    end
    object tbPkgOptions: TToolButton
      Left = 216
      Top = 0
    end
  end
  object MenuActions: TActionList
    Left = 24
    Top = 32
    object aPkgOpen: TAction
      Category = 'Package'
      Caption = '&Open'
      Hint = 'Open the unit'
    end
    object aPkgAdd: TAction
      Category = 'Package'
      Caption = 'Add'
      Hint = 'Add to package'
      ImageIndex = 5
    end
    object aPkgRemove: TAction
      Category = 'Package'
      Caption = 'Remove'
      Hint = 'Remove file from package'
      ImageIndex = 6
    end
    object aPkgCompile: TAction
      Category = 'Package'
      Caption = 'Compile'
      Hint = 'Compile package'
      ImageIndex = 33
    end
    object aPkgBuild: TAction
      Category = 'Package'
      Caption = '&Build'
      Hint = 'Build package'
      ImageIndex = 34
    end
    object aPkgInstall: TAction
      Category = 'Package'
      Caption = 'Install'
      Hint = 'Install package'
      ImageIndex = 146
    end
    object aPkgViewSource: TAction
      Category = 'Package'
      Caption = '&View Source'
      Hint = 'View the package source'
      ImageIndex = 122
    end
    object aPkgOptions: TAction
      Category = 'Package'
      Caption = 'Options'
      Hint = 'Configure package options'
      ImageIndex = 16
    end
    object aPkgStatusBar: TAction
      Category = 'Package'
      Caption = 'Stat&us Bar'
      Hint = 'Show the status bar of the package editor'
    end
  end
  object PkgPopup: TPopupMenu
    Left = 72
    Top = 32
    object pmPkgOpen: TMenuItem
      Action = aPkgOpen
      Default = True
    end
    object pmPkgN1: TMenuItem
      Caption = '-'
    end
    object pmPkgAdd: TMenuItem
      Action = aPkgAdd
    end
    object pmPkgRemove: TMenuItem
      Action = aPkgRemove
    end
    object pmPkgN2: TMenuItem
      Caption = '-'
    end
    object pmPkgCompile: TMenuItem
      Action = aPkgCompile
    end
    object pmPkgBuild: TMenuItem
      Action = aPkgBuild
    end
    object pmPkgInstall: TMenuItem
      Action = aPkgInstall
    end
    object pmPkgViewSource: TMenuItem
      Action = aPkgViewSource
    end
    object pmPkgOptions: TMenuItem
      Action = aPkgOptions
    end
    object pmPkgN3: TMenuItem
      Caption = '-'
    end
    object pmPkgStatusBar: TMenuItem
      Action = aPkgStatusBar
    end
  end
end
