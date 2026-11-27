object MacrosView: TMacrosView
  Left = 0
  Top = 0
  BorderStyle = bsNone
  Caption = 'Macro Library'
  ClientHeight = 160
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
  object Bar: TToolBar
    Left = 0
    Top = 0
    Width = 640
    Height = 40
    Align = alNone
    ButtonHeight = 38
    ButtonWidth = 64
    Caption = 'Macro Library'
    EdgeBorders = []
    Flat = True
    ParentShowHint = False
    ShowCaptions = True
    ShowHint = True
    TabOrder = 0
    Wrapable = False
    Transparent = False
    object tbRecord: TToolButton
      Left = 0
      Top = 0
      Action = aMacRecord
    end
    object tbPlay: TToolButton
      Left = 64
      Top = 0
      Action = aMacPlay
    end
    object tbRepeat: TToolButton
      Left = 128
      Top = 0
      Action = aMacRepeat
    end
    object tbSep1: TToolButton
      Left = 192
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object tbRename: TToolButton
      Left = 200
      Top = 0
      Action = aMacRename
    end
    object tbDelete: TToolButton
      Left = 264
      Top = 0
      Action = aMacDelete
    end
    object tbUp: TToolButton
      Left = 328
      Top = 0
      Action = aMacUp
    end
    object tbDown: TToolButton
      Left = 392
      Top = 0
      Action = aMacDown
    end
    object tbSep2: TToolButton
      Left = 456
      Top = 0
      Width = 8
      Style = tbsSeparator
    end
    object tbImport: TToolButton
      Left = 464
      Top = 0
      Action = aMacImport
    end
    object tbExport: TToolButton
      Left = 528
      Top = 0
      Action = aMacExport
    end
  end
  object MacroList: TListView
    Left = 0
    Top = 40
    Width = 640
    Height = 120
    Align = alClient
    Columns = <
      item
        Caption = 'Name'
        Width = 160
      end
      item
        Alignment = taRightJustify
        Caption = 'Keys'
        Width = 50
      end
      item
        Caption = 'Content'
        Width = 400
      end>
    HideSelection = False
    MultiSelect = True
    RowSelect = True
    PopupMenu = MacroPopup
    TabOrder = 1
    ViewStyle = vsReport
    OnDblClick = MacroListDblClick
    OnEdited = MacroListEdited
    OnKeyDown = MacroListKeyDown
    OnSelectItem = MacroListSelectItem
  end
  object Actions: TActionList
    OnUpdate = ActionsUpdate
    Left = 40
    Top = 80
    object aMacRecord: TAction
      Category = 'Macros'
      Caption = 'Record'
      Hint = 'Record a macro'
      ImageIndex = 253
      OnExecute = Command
    end
    object aMacPlay: TAction
      Category = 'Macros'
      Caption = 'Play'
      Hint = 'Play the macro in the code editor'
      ImageIndex = 254
      OnExecute = Command
    end
    object aMacRepeat: TAction
      Category = 'Macros'
      Caption = 'Repeat...'
      Hint = 'Play the macro several times, or until the end of the file'
      ImageIndex = 255
      OnExecute = Command
    end
    object aMacRename: TAction
      Category = 'Macros'
      Caption = 'Rename'
      Hint = 'Rename the macro'
      ImageIndex = 189
      OnExecute = Command
    end
    object aMacDelete: TAction
      Category = 'Macros'
      Caption = 'Delete'
      Hint = 'Delete the macros chosen'
      ImageIndex = 12
      OnExecute = Command
    end
    object aMacUp: TAction
      Category = 'Macros'
      Caption = 'Move Up'
      Hint = 'Move the macro up'
      ImageIndex = 224
      OnExecute = Command
    end
    object aMacDown: TAction
      Category = 'Macros'
      Caption = 'Move Down'
      Hint = 'Move the macro down'
      ImageIndex = 225
      OnExecute = Command
    end
    object aMacImport: TAction
      Category = 'Macros'
      Caption = 'Import...'
      Hint = 'Add the macros of macro files'
      ImageIndex = 257
      OnExecute = Command
    end
    object aMacExport: TAction
      Category = 'Macros'
      Caption = 'Export...'
      Hint = 'Write the macros chosen to a macro file'
      ImageIndex = 258
      OnExecute = Command
    end
  end
  object MacroPopup: TPopupMenu
    OnPopup = MenuPopup
    Left = 120
    Top = 80
    object pmRecord: TMenuItem
      Action = aMacRecord
    end
    object pmSep1: TMenuItem
      Caption = '-'
    end
    object pmPlay: TMenuItem
      Action = aMacPlay
      Default = True
    end
    object pmRepeat: TMenuItem
      Action = aMacRepeat
    end
    object pmSep2: TMenuItem
      Caption = '-'
    end
    object pmRename: TMenuItem
      Action = aMacRename
    end
    object pmDelete: TMenuItem
      Action = aMacDelete
    end
    object pmSep3: TMenuItem
      Caption = '-'
    end
    object pmUp: TMenuItem
      Action = aMacUp
    end
    object pmDown: TMenuItem
      Action = aMacDown
    end
    object pmSep4: TMenuItem
      Caption = '-'
    end
    object pmImport: TMenuItem
      Action = aMacImport
    end
    object pmExport: TMenuItem
      Action = aMacExport
    end
  end
end
