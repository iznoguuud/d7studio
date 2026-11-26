object DebuggerOptionsFrame: TDebuggerOptionsFrame
  Left = 0
  Top = 0
  Width = 638
  Height = 414
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  ParentFont = False
  TabOrder = 0
  DesignSize = (
    638
    414)
  object PageControl: TPageControl
    Left = 0
    Top = 0
    Width = 638
    Height = 386
    ActivePage = tsGeneral
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 0
    TabStop = False
    object tsGeneral: TTabSheet
      Caption = 'General'
      TabVisible = False
      object gbDebugging: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 111
        Caption = ' General '
        TabOrder = 0
        object cbTD32Commands: TCheckBox
          Left = 9
          Top = 18
          Width = 229
          Height = 19
          Caption = 'Map &TD32 keystrokes on run'
          TabOrder = 0
        end
        object cbRearrangeMenu: TCheckBox
          Left = 394
          Top = 40
          Width = 222
          Height = 19
          TabStop = False
          Caption = 'Rearrange &editor local menu on run'
          TabOrder = 4
        end
        object cbDisableEdit: TCheckBox
          Left = 9
          Top = 40
          Width = 229
          Height = 19
          TabStop = False
          Caption = '&Mark buffers read-only on run'
          TabOrder = 1
        end
        object cbAllowSideEffectsInWatches: TCheckBox
          Left = 394
          Top = 18
          Width = 219
          Height = 19
          TabStop = False
          Caption = '&Allow side effects in new watches'
          TabOrder = 3
        end
        object cbDisableMultipleEvaluators: TCheckBox
          Left = 9
          Top = 62
          Width = 187
          Height = 19
          TabStop = False
          Caption = 'Disable multiple e&valuators'
          TabOrder = 2
        end
        object cbDebugSpawnedProcesses: TCheckBox
          Left = 394
          Top = 62
          Width = 179
          Height = 19
          TabStop = False
          Caption = '&Debug spawned processes'
          TabOrder = 5
        end
        object cbCOMCrossProcess: TCheckBox
          Left = 394
          Top = 84
          Width = 222
          Height = 19
          TabStop = False
          Caption = 'Enable C&OM cross-process support'
          TabOrder = 6
        end
      end
      object gbPath: TGroupBox
        Left = 9
        Top = 199
        Width = 620
        Height = 119
        Caption = ' Paths '
        TabOrder = 2
        object dgLabel1: TLabel
          Left = 9
          Top = 20
          Width = 151
          Height = 15
          Caption = 'Debug S&ymbols Search Path:'
          FocusControl = ddDebugSymbolSearchPath
        end
        object lbDebugDcu: TLabel
          Left = 9
          Top = 68
          Width = 92
          Height = 15
          Caption = 'Debug D&CU Path:'
          FocusControl = ddDebugDCUPath
        end
        object ddDebugSymbolSearchPath: TComboBox
          Left = 9
          Top = 38
          Width = 571
          Height = 23
          ItemHeight = 0
          TabOrder = 0
        end
        object bDirDebugSource: TButton
          Left = 587
          Top = 38
          Width = 24
          Height = 23
          Action = aListDebugSource
          TabOrder = 1
        end
        object ddDebugDCUPath: TComboBox
          Left = 9
          Top = 86
          Width = 571
          Height = 23
          ItemHeight = 0
          TabOrder = 2
        end
        object bDirDebugDCU: TButton
          Left = 587
          Top = 86
          Width = 24
          Height = 23
          Action = aListDebugDcu
          TabOrder = 3
        end
      end
      object gbInspectorDefaults: TGroupBox
        Left = 9
        Top = 126
        Width = 620
        Height = 67
        Caption = ' Inspector Defaults '
        TabOrder = 1
        object cbShowInherited: TCheckBox
          Left = 9
          Top = 18
          Width = 207
          Height = 19
          Caption = 'Sho&w inherited'
          TabOrder = 0
        end
        object cbShowQualNames: TCheckBox
          Left = 396
          Top = 18
          Width = 215
          Height = 19
          TabStop = False
          Caption = 'Show f&ully qualified names'
          TabOrder = 1
        end
        object cbSortByName: TCheckBox
          Left = 9
          Top = 40
          Width = 114
          Height = 19
          TabStop = False
          Caption = 'Sort by &name'
          TabOrder = 2
        end
      end
    end
    object tsEventLog: TTabSheet
      Caption = 'Event Log'
      TabVisible = False
      object LogGroupBox: TGroupBox
        Left = 326
        Top = 9
        Width = 303
        Height = 155
        Caption = ' Messages '
        TabOrder = 1
        object cbProcessMessages: TCheckBox
          Left = 9
          Top = 40
          Width = 209
          Height = 19
          TabStop = False
          Caption = '&Process messages'
          Checked = True
          State = cbChecked
          TabOrder = 1
        end
        object cbBreakpointMessages: TCheckBox
          Left = 9
          Top = 18
          Width = 219
          Height = 19
          Caption = '&Breakpoint messages'
          Checked = True
          State = cbChecked
          TabOrder = 0
        end
        object cbOutputMessages: TCheckBox
          Left = 9
          Top = 106
          Width = 202
          Height = 19
          TabStop = False
          Caption = '&Output messages'
          Checked = True
          State = cbChecked
          TabOrder = 4
        end
        object cbWindowMessages: TCheckBox
          Left = 9
          Top = 128
          Width = 207
          Height = 19
          TabStop = False
          Caption = '&Window messages'
          TabOrder = 5
        end
        object cbThreadMessages: TCheckBox
          Left = 9
          Top = 62
          Width = 209
          Height = 19
          TabStop = False
          Caption = '&Thread messages'
          TabOrder = 2
        end
        object cbModuleMessages: TCheckBox
          Left = 9
          Top = 84
          Width = 209
          Height = 19
          TabStop = False
          Caption = '&Module messages'
          TabOrder = 3
        end
      end
      object GeneralGroupBox: TGroupBox
        Left = 9
        Top = 9
        Width = 303
        Height = 155
        Caption = ' General '
        TabOrder = 0
        object lbLogLength: TLabel
          Left = 30
          Top = 67
          Width = 40
          Height = 15
          Caption = '&Length:'
          FocusControl = ecLogLength
        end
        object ecLogLength: TEdit
          Left = 82
          Top = 64
          Width = 60
          Height = 23
          TabOrder = 2
          Text = '100'
        end
        object cbUnlimited: TCheckBox
          Left = 9
          Top = 40
          Width = 211
          Height = 19
          TabStop = False
          Caption = '&Unlimited length'
          TabOrder = 1
          OnClick = UnlimitedClick
        end
        object cbClearOnStartup: TCheckBox
          Left = 9
          Top = 18
          Width = 202
          Height = 20
          Caption = '&Clear log on run'
          TabOrder = 0
        end
        object cbIncludeProcessInfo: TCheckBox
          Left = 9
          Top = 96
          Width = 283
          Height = 19
          TabStop = False
          Caption = '&Display process info with event'
          Checked = True
          State = cbChecked
          TabOrder = 3
        end
      end
      object LogColorGroupBox: TGroupBox
        Left = 9
        Top = 170
        Width = 620
        Height = 207
        TabOrder = 2
        object lblForeground: TLabel
          Left = 9
          Top = 177
          Width = 65
          Height = 15
          Caption = 'Foreground:'
          FocusControl = clrbxForegroundColor
        end
        object lblBackground: TLabel
          Left = 353
          Top = 177
          Width = 67
          Height = 15
          Caption = 'Background:'
          FocusControl = clrbxBackgroundColor
        end
        object lstbxColors: TListBox
          Left = 9
          Top = 34
          Width = 602
          Height = 133
          Style = lbOwnerDrawFixed
          ItemHeight = 16
          TabOrder = 1
          OnClick = ColorsClick
          OnDrawItem = ColorsDrawItem
        end
        object clrbxForegroundColor: TColorBox
          Left = 85
          Top = 175
          Width = 180
          Height = 22
          Style = [cbStandardColors, cbExtendedColors, cbSystemColors, cbCustomColor, cbPrettyNames]
          ItemHeight = 16
          TabOrder = 2
          OnSelect = ColorSelect
        end
        object clrbxBackgroundColor: TColorBox
          Left = 431
          Top = 175
          Width = 180
          Height = 22
          Style = [cbStandardColors, cbExtendedColors, cbSystemColors, cbCustomColor, cbPrettyNames]
          ItemHeight = 16
          TabOrder = 3
          OnSelect = ColorSelect
        end
        object chkbxUseLogColors: TCheckBox
          Left = 9
          Top = 7
          Width = 151
          Height = 19
          Caption = 'Use &Event Log Colors'
          TabOrder = 0
        end
      end
    end
    object tsLangExceptions: TTabSheet
      Caption = 'Language Exceptions'
      TabVisible = False
      object cbDelphiExcept: TCheckBox
        Left = 9
        Top = 350
        Width = 193
        Height = 19
        Caption = '&Stop on Delphi Exceptions'
        TabOrder = 1
      end
      object cbCPPExcept: TCheckBox
        Left = 319
        Top = 350
        Width = 180
        Height = 19
        Caption = 'Stop on &C++ Exceptions'
        TabOrder = 2
      end
      object gbIgnoreExcept: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 328
        Caption = ' &Exception Types to Ignore '
        TabOrder = 0
        object AddButton: TButton
          Left = 423
          Top = 293
          Width = 88
          Height = 26
          Action = aLangAdd
          TabOrder = 1
        end
        object RemoveButton: TButton
          Left = 523
          Top = 293
          Width = 88
          Height = 26
          Action = aLangRemove
          TabOrder = 2
        end
        object ExceptListBox: TCheckListBox
          Left = 9
          Top = 20
          Width = 602
          Height = 263
          ItemHeight = 13
          TabOrder = 0
        end
      end
    end
    object tsOSExceptions: TTabSheet
      Caption = 'OS Exceptions'
      TabVisible = False
      object oeLabel1: TLabel
        Left = 9
        Top = 9
        Width = 59
        Height = 15
        Caption = '&Exceptions:'
        FocusControl = ExceptionList
      end
      object ExceptionList: TListBox
        Left = 9
        Top = 30
        Width = 620
        Height = 270
        Style = lbOwnerDrawFixed
        ItemHeight = 16
        MultiSelect = True
        TabOrder = 0
        OnClick = OSListClick
        OnDrawItem = OSDrawItem
      end
      object rgHandledBy: TRadioGroup
        Left = 9
        Top = 308
        Width = 250
        Height = 69
        Caption = ' Handled by '
        Items.Strings = (
          '&Debugger'
          'User pro&gram')
        TabOrder = 1
        OnClick = OSRuleClick
      end
      object rgResumeOptions: TRadioGroup
        Left = 271
        Top = 308
        Width = 250
        Height = 69
        Caption = ' On resume '
        Items.Strings = (
          '&Run handled'
          'Run u&nhandled')
        TabOrder = 2
        OnClick = OSRuleClick
      end
      object AddExButton: TButton
        Left = 534
        Top = 315
        Width = 95
        Height = 26
        Action = aOSAdd
        TabOrder = 3
      end
      object RemoveExButton: TButton
        Left = 534
        Top = 351
        Width = 95
        Height = 26
        Action = aOSRemove
        TabOrder = 4
      end
    end
  end
  object Footer: TPanel
    Left = 0
    Top = 386
    Width = 638
    Height = 28
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 1
    object cbIntegratedDebugging: TCheckBox
      Left = 9
      Top = 0
      Width = 175
      Height = 19
      Caption = '&Integrated debugging'
      TabOrder = 0
    end
  end
  object Actions: TActionList
    Left = 12
    Top = 359
    object aListDebugSource: TAction
      Caption = '...'
      OnExecute = EditListExecute
    end
    object aListDebugDcu: TAction
      Caption = '...'
      OnExecute = EditListExecute
    end
    object aLangAdd: TAction
      Caption = '&Add...'
      OnExecute = aLangAddExecute
    end
    object aLangRemove: TAction
      Caption = '&Remove'
      OnExecute = aLangRemoveExecute
      OnUpdate = LangSelectedUpdate
    end
    object aOSAdd: TAction
      Caption = '&Add...'
      OnExecute = aOSAddExecute
    end
    object aOSRemove: TAction
      Caption = 'Re&move'
      OnExecute = aOSRemoveExecute
      OnUpdate = OSSelectedUpdate
    end
  end
end
