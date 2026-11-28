object ProjOptionsFrame: TProjOptionsFrame
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
    ActivePage = tsForms
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 0
    TabStop = False
    object tsForms: TTabSheet
      Caption = 'Forms'
      TabVisible = False
      object fmLabel11: TLabel
        Left = 9
        Top = 12
        Width = 59
        Height = 15
        Caption = '&Main form:'
        FocusControl = cbMainForm
      end
      object fmLabel6: TLabel
        Left = 9
        Top = 45
        Width = 100
        Height = 15
        Caption = '&Auto-create forms:'
        FocusControl = AutoCreateForms
      end
      object fmLabel12: TLabel
        Left = 357
        Top = 45
        Width = 85
        Height = 15
        Caption = 'Available &forms:'
        FocusControl = AvailableForms
      end
      object AddSelected: TSpeedButton
        Left = 304
        Top = 63
        Width = 30
        Height = 27
        Action = aToAuto
      end
      object AddAll: TSpeedButton
        Left = 304
        Top = 129
        Width = 30
        Height = 27
        Action = aAllToAuto
      end
      object RemoveSelected: TSpeedButton
        Left = 304
        Top = 96
        Width = 30
        Height = 27
        Action = aToAvail
      end
      object RemoveAll: TSpeedButton
        Left = 304
        Top = 162
        Width = 30
        Height = 27
        Action = aAllToAvail
      end
      object AvailableForms: TListBox
        Left = 357
        Top = 63
        Width = 272
        Height = 293
        DragMode = dmAutomatic
        ItemHeight = 13
        MultiSelect = True
        TabOrder = 2
        OnDblClick = FormListDblClick
      end
      object AutoCreateForms: TListBox
        Left = 9
        Top = 63
        Width = 272
        Height = 293
        DragMode = dmAutomatic
        ItemHeight = 13
        MultiSelect = True
        TabOrder = 1
        OnDblClick = FormListDblClick
      end
      object cbMainForm: TComboBox
        Left = 90
        Top = 9
        Width = 539
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 0
        OnChange = MainFormChange
      end
    end
    object tsApplication: TTabSheet
      Caption = 'Application'
      TabVisible = False
      object apGroupBox13: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 171
        Caption = ' Application settings '
        TabOrder = 0
        object AppHelpFileLbl: TLabel
          Left = 9
          Top = 52
          Width = 47
          Height = 15
          Caption = 'Help &file:'
          FocusControl = AppHelpFile
        end
        object AppTitleLbl: TLabel
          Left = 29
          Top = 23
          Width = 26
          Height = 15
          Caption = '&Title:'
          FocusControl = AppTitle
        end
        object AppIconLbl: TLabel
          Left = 29
          Top = 79
          Width = 26
          Height = 15
          Caption = '&Icon:'
          FocusControl = LoadIconBtn
        end
        object IconPanel: TPanel
          Left = 66
          Top = 79
          Width = 61
          Height = 57
          BevelOuter = bvNone
          ParentColor = True
          TabOrder = 3
          ParentBackground = False
          object shpIcon: TShape
            Left = 0
            Top = 0
            Width = 61
            Height = 57
            Align = alClient
            Brush.Style = bsClear
            Pen.Color = clBtnShadow
          end
          object IconImage: TImage
            Left = 1
            Top = 1
            Width = 59
            Height = 55
            Align = alClient
            Center = True
          end
        end
        object LoadIconBtn: TButton
          Left = 139
          Top = 79
          Width = 102
          Height = 26
          Action = aLoadIcon
          TabOrder = 4
        end
        object bpBrowseHelp: TButton
          Left = 522
          Top = 48
          Width = 89
          Height = 26
          Action = aBrowseHelp
          TabOrder = 2
        end
        object AppHelpFile: TEdit
          Left = 66
          Top = 49
          Width = 448
          Height = 23
          TabOrder = 1
        end
        object AppTitle: TEdit
          Left = 66
          Top = 20
          Width = 545
          Height = 23
          TabOrder = 0
        end
        object chkThemes: TCheckBox
          Left = 66
          Top = 144
          Width = 516
          Height = 19
          Caption = 'Enable runtime t&hemes (manifest for the Windows visual styles)'
          TabOrder = 5
        end
      end
      object apGroupBox15: TGroupBox
        Left = 9
        Top = 186
        Width = 620
        Height = 169
        Caption = ' Output settings '
        TabOrder = 1
        object apLabel19: TLabel
          Left = 9
          Top = 23
          Width = 108
          Height = 15
          Caption = 'Target file &extension:'
          FocusControl = AppFileExt
        end
        object lblPlatform: TLabel
          Left = 9
          Top = 52
          Width = 85
          Height = 15
          Caption = 'Target &platform:'
          FocusControl = cbPlatform
        end
        object lblTargetWindows: TLabel
          Left = 9
          Top = 81
          Width = 89
          Height = 15
          Caption = 'Target &Windows:'
          FocusControl = cbTargetWindows
        end
        object lblDpiAwareness: TLabel
          Left = 9
          Top = 110
          Width = 81
          Height = 15
          Caption = 'DPI &awareness:'
          FocusControl = cbDpiAwareness
        end
        object lblExecLevel: TLabel
          Left = 9
          Top = 139
          Width = 88
          Height = 15
          Caption = 'E&xecution level:'
          FocusControl = cbExecLevel
        end
        object AppFileExt: TEdit
          Left = 138
          Top = 20
          Width = 142
          Height = 23
          TabOrder = 0
        end
        object cbPlatform: TComboBox
          Left = 138
          Top = 49
          Width = 473
          Height = 23
          Style = csDropDownList
          ItemHeight = 15
          TabOrder = 1
          OnChange = cbPlatformChange
          Items.Strings = (
            '32-bit Windows (Win32) - Delphi 7 dcc32'
            '64-bit Windows (Win64) - RAD Studio dcc64')
        end
        object cbTargetWindows: TComboBox
          Left = 138
          Top = 78
          Width = 473
          Height = 23
          Style = csDropDownList
          ItemHeight = 15
          TabOrder = 2
          Items.Strings = (
            'Windows 10 1903 or later (UTF-8 code page)'
            'Windows Vista or later (system code page)'
            'Windows XP or later (system code page, program header 5.1)')
        end
        object cbDpiAwareness: TComboBox
          Left = 138
          Top = 107
          Width = 473
          Height = 23
          Style = csDropDownList
          ItemHeight = 15
          TabOrder = 3
          Items.Strings = (
            'Unaware (Windows stretches the windows at other scales)'
            'System aware (the scale of the main monitor at start)'
            'Per monitor (Windows 8.1 or later)'
            'Per monitor V2 (Windows 10 1703 or later)')
        end
        object cbExecLevel: TComboBox
          Left = 138
          Top = 136
          Width = 473
          Height = 23
          Style = csDropDownList
          ItemHeight = 15
          TabOrder = 4
          Items.Strings = (
            'As invoker (the rights of the user who starts it)'
            'Highest available (an administrator''s when the user is one)'
            'Require administrator (asks for elevation at start)')
        end
      end
    end
    object tsCompiler: TTabSheet
      Caption = 'Compiler'
      TabVisible = False
      object cpGroupBox4: TGroupBox
        Left = 326
        Top = 98
        Width = 303
        Height = 145
        Caption = ' Debugging '
        TabOrder = 3
        object cbDebugInfo: TCheckBox
          Left = 9
          Top = 18
          Width = 262
          Height = 19
          Caption = '&Debug information'
          TabOrder = 0
        end
        object cbLocalSymbols: TCheckBox
          Left = 9
          Top = 38
          Width = 262
          Height = 19
          TabStop = False
          Caption = '&Local symbols'
          TabOrder = 1
        end
        object cbSymbolInfo: TCheckBox
          Left = 9
          Top = 58
          Width = 261
          Height = 19
          TabStop = False
          Caption = 'Re&ference info'
          TabOrder = 2
        end
        object cbAssertions: TCheckBox
          Left = 9
          Top = 98
          Width = 247
          Height = 19
          TabStop = False
          Caption = 'Ass&ertions'
          TabOrder = 4
        end
        object cbDefinitionsOnly: TCheckBox
          Left = 28
          Top = 78
          Width = 265
          Height = 19
          TabStop = False
          Caption = 'Definitions onl&y'
          TabOrder = 3
        end
        object cbDebugDCU: TCheckBox
          Left = 9
          Top = 118
          Width = 241
          Height = 19
          TabStop = False
          Caption = '&Use Debug DCUs'
          TabOrder = 5
        end
      end
      object cpGroupBox3: TGroupBox
        Left = 9
        Top = 135
        Width = 303
        Height = 165
        Caption = ' Syntax options '
        TabOrder = 1
        object cbVarStrCheck: TCheckBox
          Left = 9
          Top = 18
          Width = 262
          Height = 19
          Caption = 'Strict &var-strings'
          TabOrder = 0
        end
        object cbFullBoolEval: TCheckBox
          Left = 9
          Top = 38
          Width = 262
          Height = 19
          TabStop = False
          Caption = '&Complete boolean eval'
          TabOrder = 1
        end
        object cbExtSyntax: TCheckBox
          Left = 9
          Top = 58
          Width = 262
          Height = 19
          TabStop = False
          Caption = 'E&xtended syntax'
          TabOrder = 2
        end
        object cbTypedPointers: TCheckBox
          Left = 9
          Top = 78
          Width = 262
          Height = 19
          TabStop = False
          Caption = '&Typed @ operator'
          TabOrder = 3
        end
        object cbOpenParameters: TCheckBox
          Left = 9
          Top = 98
          Width = 262
          Height = 19
          TabStop = False
          Caption = 'Open &parameters'
          TabOrder = 4
        end
        object cbHugeStrings: TCheckBox
          Left = 9
          Top = 118
          Width = 200
          Height = 19
          TabStop = False
          Caption = 'Huge &strings'
          TabOrder = 5
        end
        object cbAssignConst: TCheckBox
          Left = 9
          Top = 138
          Width = 281
          Height = 19
          TabStop = False
          Caption = 'Assigna&ble typed constants'
          TabOrder = 6
        end
      end
      object cpGroupBox2: TGroupBox
        Left = 326
        Top = 9
        Width = 303
        Height = 85
        Caption = ' Runtime errors '
        TabOrder = 2
        object cbRangeCheck: TCheckBox
          Left = 9
          Top = 18
          Width = 262
          Height = 19
          Caption = '&Range checking'
          TabOrder = 0
        end
        object cbInOutCheck: TCheckBox
          Left = 9
          Top = 38
          Width = 262
          Height = 19
          TabStop = False
          Caption = '&I/O checking'
          TabOrder = 1
        end
        object cbOverflowCheck: TCheckBox
          Left = 9
          Top = 58
          Width = 262
          Height = 19
          TabStop = False
          Caption = '&Overflow checking'
          TabOrder = 2
        end
      end
      object cpGroupBox1: TGroupBox
        Left = 9
        Top = 9
        Width = 303
        Height = 111
        Caption = ' Code generation '
        TabOrder = 0
        object cpLabel1: TLabel
          Left = 63
          Top = 78
          Width = 120
          Height = 15
          Caption = 'Record field &alignment'
          FocusControl = cbRecordAlign
        end
        object cbOptimization: TCheckBox
          Left = 9
          Top = 18
          Width = 262
          Height = 19
          Caption = 'Optimi&zation'
          TabOrder = 0
        end
        object cbStackFrames: TCheckBox
          Left = 9
          Top = 38
          Width = 262
          Height = 19
          TabStop = False
          Caption = 'Stac&k frames'
          TabOrder = 1
        end
        object cbPentiumSafe: TCheckBox
          Left = 9
          Top = 58
          Width = 262
          Height = 19
          TabStop = False
          Caption = 'Pentiu&m-safe FDIV'
          TabOrder = 2
        end
        object cbRecordAlign: TComboBox
          Left = 9
          Top = 78
          Width = 47
          Height = 23
          Style = csDropDownList
          ItemHeight = 15
          TabOrder = 3
          Items.Strings = (
            '1'
            '2'
            '4'
            '8')
        end
      end
    end
    object tsMessages: TTabSheet
      Caption = 'Compiler Messages'
      TabVisible = False
      object gbGeneral: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 45
        Caption = ' General '
        TabOrder = 0
        object cbShowHints: TCheckBox
          Left = 9
          Top = 18
          Width = 175
          Height = 19
          Caption = 'Sh&ow hints'
          TabOrder = 0
        end
        object cbShowWarnings: TCheckBox
          Left = 326
          Top = 18
          Width = 173
          Height = 19
          TabStop = False
          Caption = '&Show warnings'
          TabOrder = 1
        end
      end
      object gbWarnings: TGroupBox
        Left = 9
        Top = 60
        Width = 620
        Height = 315
        Caption = ' &Warnings '
        TabOrder = 1
        object WarningsList: TCheckListBox
          Left = 9
          Top = 20
          Width = 602
          Height = 285
          ItemHeight = 13
          TabOrder = 0
        end
      end
    end
    object tsLinker: TTabSheet
      Caption = 'Linker'
      TabVisible = False
      object lkGroupBox9: TGroupBox
        Left = 326
        Top = 145
        Width = 303
        Height = 111
        Caption = ' Memory sizes '
        TabOrder = 3
        object lkLabel1: TLabel
          Left = 9
          Top = 23
          Width = 76
          Height = 15
          Caption = 'Mi&n stack size:'
          FocusControl = ecStackSize
        end
        object lkLabel2: TLabel
          Left = 23
          Top = 79
          Width = 63
          Height = 15
          Caption = '&Image base:'
          FocusControl = ecImageBase
        end
        object lkLabel13: TLabel
          Left = 9
          Top = 51
          Width = 74
          Height = 15
          Caption = 'Ma&x stacksize:'
          FocusControl = ecMaxStackSize
        end
        object ecStackSize: TEdit
          Left = 100
          Top = 20
          Width = 95
          Height = 23
          TabOrder = 0
        end
        object ecImageBase: TEdit
          Left = 100
          Top = 76
          Width = 95
          Height = 23
          TabOrder = 2
        end
        object ecMaxStackSize: TEdit
          Left = 100
          Top = 48
          Width = 95
          Height = 23
          TabOrder = 1
        end
      end
      object lkGroupBox8: TGroupBox
        Left = 9
        Top = 145
        Width = 303
        Height = 111
        Caption = ' EXE and DLL options '
        TabOrder = 1
        object cbExtDebug: TCheckBox
          Left = 9
          Top = 40
          Width = 287
          Height = 19
          TabStop = False
          Caption = 'Include &TD32 debug info'
          TabOrder = 1
        end
        object cbConsoleApp: TCheckBox
          Left = 9
          Top = 18
          Width = 287
          Height = 19
          Caption = 'Generate &console application'
          TabOrder = 0
        end
        object cbRemoteDebug: TCheckBox
          Left = 9
          Top = 62
          Width = 287
          Height = 19
          TabStop = False
          Caption = 'Include &remote debug symbols'
          TabOrder = 2
        end
        object chkModernHeader: TCheckBox
          Left = 9
          Top = 84
          Width = 287
          Height = 19
          Caption = 'Modern program &header (DEP, ASLR)'
          TabOrder = 3
        end
      end
      object lkGroupBox7: TGroupBox
        Left = 326
        Top = 9
        Width = 303
        Height = 129
        Caption = ' Linker output '
        TabOrder = 2
        object rbGenerateBPUs: TRadioButton
          Left = 9
          Top = 18
          Width = 261
          Height = 19
          Caption = 'Generate DC&Us'
          TabOrder = 0
        end
        object rbGenerateCObjs: TRadioButton
          Left = 9
          Top = 39
          Width = 261
          Height = 19
          Caption = 'Generate C &object files'
          TabOrder = 1
        end
        object rbGenerateCPPObjs: TRadioButton
          Left = 9
          Top = 60
          Width = 283
          Height = 19
          Caption = '&Generate C++ object files'
          TabOrder = 2
        end
        object cbIncludeNamespaces: TCheckBox
          Left = 28
          Top = 81
          Width = 264
          Height = 19
          Caption = 'Include na&mespaces'
          TabOrder = 3
        end
        object cbExportAllSymbols: TCheckBox
          Left = 28
          Top = 102
          Width = 264
          Height = 19
          Caption = 'Export &all symbols'
          TabOrder = 4
        end
      end
      object lkGroupBox6: TGroupBox
        Left = 9
        Top = 9
        Width = 303
        Height = 129
        Caption = ' Map file '
        TabOrder = 0
        object rbMapFileOff: TRadioButton
          Left = 9
          Top = 18
          Width = 261
          Height = 19
          Caption = 'O&ff'
          TabOrder = 0
        end
        object rbMapSegOnly: TRadioButton
          Left = 9
          Top = 40
          Width = 261
          Height = 19
          Caption = '&Segments'
          TabOrder = 1
        end
        object rbMapSegPubs: TRadioButton
          Left = 9
          Top = 62
          Width = 261
          Height = 19
          Caption = '&Publics'
          TabOrder = 2
        end
        object rbMapDetailed: TRadioButton
          Left = 9
          Top = 84
          Width = 261
          Height = 19
          Caption = '&Detailed'
          TabOrder = 3
        end
      end
      object lkGroupBox14: TGroupBox
        Left = 9
        Top = 262
        Width = 620
        Height = 53
        Caption = ' Description '
        TabOrder = 4
        object lkLabel14: TLabel
          Left = 9
          Top = 23
          Width = 85
          Height = 15
          Caption = '&EXE Description:'
          FocusControl = ecExeDescription
        end
        object ecExeDescription: TEdit
          Left = 128
          Top = 20
          Width = 483
          Height = 23
          TabOrder = 0
        end
      end
    end
    object tsDirectories: TTabSheet
      Caption = 'Directories/Conditionals'
      TabVisible = False
      object drGroupBox11: TGroupBox
        Left = 9
        Top = 228
        Width = 620
        Height = 53
        Caption = ' Conditionals '
        TabOrder = 1
        object drLabel8: TLabel
          Left = 9
          Top = 23
          Width = 106
          Height = 15
          Caption = '&Conditional defines:'
          FocusControl = ddConditionals
        end
        object ddConditionals: TComboBox
          Left = 134
          Top = 20
          Width = 448
          Height = 23
          ItemHeight = 0
          TabOrder = 0
        end
        object bConditionals: TButton
          Left = 587
          Top = 20
          Width = 24
          Height = 23
          Action = aListConditionals
          TabOrder = 1
        end
      end
      object drGroupBox10: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 213
        Caption = ' Directories '
        TabOrder = 0
        object drLabel3: TLabel
          Left = 34
          Top = 23
          Width = 91
          Height = 15
          Caption = '&Output directory:'
          FocusControl = ddOutputDir
        end
        object drLabel4: TLabel
          Left = 54
          Top = 87
          Width = 65
          Height = 15
          Caption = '&Search path:'
          FocusControl = ddSearchPath
        end
        object drLabel16: TLabel
          Left = 9
          Top = 55
          Width = 114
          Height = 15
          Caption = '&Unit output directory:'
          FocusControl = ddUnitOutput
        end
        object drLabel15: TLabel
          Left = 15
          Top = 119
          Width = 103
          Height = 15
          Caption = '&Debug source path:'
          FocusControl = ddDebugSourcePath
        end
        object drLabel1: TLabel
          Left = 9
          Top = 151
          Width = 112
          Height = 15
          Caption = '&BPL output directory:'
          FocusControl = ddDPLOutputDir
        end
        object drLabel2: TLabel
          Left = 9
          Top = 183
          Width = 115
          Height = 15
          Caption = 'DC&P output directory:'
          FocusControl = ddDCPOutputDir
        end
        object ddOutputDir: TComboBox
          Left = 142
          Top = 20
          Width = 440
          Height = 23
          ItemHeight = 0
          TabOrder = 0
        end
        object ddSearchPath: TComboBox
          Left = 142
          Top = 84
          Width = 440
          Height = 23
          ItemHeight = 0
          TabOrder = 4
        end
        object ddUnitOutput: TComboBox
          Left = 142
          Top = 52
          Width = 440
          Height = 23
          ItemHeight = 0
          TabOrder = 2
        end
        object ddDebugSourcePath: TComboBox
          Left = 142
          Top = 116
          Width = 440
          Height = 23
          ItemHeight = 0
          TabOrder = 6
        end
        object ddDPLOutputDir: TComboBox
          Left = 142
          Top = 148
          Width = 440
          Height = 23
          ItemHeight = 0
          TabOrder = 8
        end
        object ddDCPOutputDir: TComboBox
          Left = 142
          Top = 180
          Width = 440
          Height = 23
          ItemHeight = 0
          TabOrder = 10
        end
        object bDirSearch: TButton
          Left = 587
          Top = 84
          Width = 24
          Height = 23
          Action = aListSearch
          TabOrder = 5
        end
        object bDirDebugSource: TButton
          Left = 587
          Top = 116
          Width = 24
          Height = 23
          Action = aListDebugSource
          TabOrder = 7
        end
        object bUnitOutputDir: TButton
          Left = 587
          Top = 52
          Width = 24
          Height = 23
          Action = aDirUnitOutput
          TabOrder = 3
        end
        object bOutputDir: TButton
          Left = 587
          Top = 20
          Width = 24
          Height = 23
          Action = aDirOutput
          TabOrder = 1
        end
        object bDPLOutputDir: TButton
          Left = 587
          Top = 148
          Width = 24
          Height = 23
          Action = aDirBpl
          TabOrder = 9
        end
        object bDCPOutputDir: TButton
          Left = 587
          Top = 180
          Width = 24
          Height = 23
          Action = aDirDcp
          TabOrder = 11
        end
      end
      object drGroupBox12: TGroupBox
        Left = 9
        Top = 287
        Width = 620
        Height = 53
        Caption = ' Aliases '
        TabOrder = 2
        object drLabel10: TLabel
          Left = 9
          Top = 23
          Width = 62
          Height = 15
          Caption = 'Unit &aliases:'
          FocusControl = ddUnitAliases
        end
        object ddUnitAliases: TComboBox
          Left = 93
          Top = 20
          Width = 489
          Height = 23
          ItemHeight = 0
          TabOrder = 0
        end
        object bUnitAliases: TButton
          Left = 587
          Top = 20
          Width = 24
          Height = 23
          Action = aListAliases
          TabOrder = 1
        end
      end
    end
    object tsVersionInfo: TTabSheet
      Caption = 'Version Info'
      TabVisible = False
      object viPanel1: TPanel
        Left = 9
        Top = 18
        Width = 620
        Height = 359
        BevelInner = bvRaised
        BevelOuter = bvLowered
        ParentColor = True
        TabOrder = 1
        ParentBackground = False
        object ModVerGroup: TGroupBox
          Left = 9
          Top = 12
          Width = 600
          Height = 93
          Caption = ' Module version number '
          TabOrder = 0
          object viLabel1: TLabel
            Left = 9
            Top = 20
            Width = 72
            Height = 15
            Caption = '&Major version'
            FocusControl = MVN1
          end
          object viLabel2: TLabel
            Left = 118
            Top = 20
            Width = 73
            Height = 15
            Caption = 'Mi&nor version'
            FocusControl = MVN2
          end
          object viLabel3: TLabel
            Left = 228
            Top = 20
            Width = 39
            Height = 15
            Caption = '&Release'
            FocusControl = MVN3
          end
          object viLabel4: TLabel
            Left = 338
            Top = 20
            Width = 27
            Height = 15
            Caption = '&Build'
            FocusControl = MVN4
          end
          object MVN1: TMaskEdit
            Left = 9
            Top = 39
            Width = 70
            Height = 23
            TabOrder = 0
            Text = '1'
            OnChange = VersionChange
          end
          object MVN2: TMaskEdit
            Left = 118
            Top = 39
            Width = 70
            Height = 23
            TabOrder = 1
            Text = '0'
            OnChange = VersionChange
          end
          object MVN3: TMaskEdit
            Left = 228
            Top = 39
            Width = 70
            Height = 23
            TabOrder = 2
            Text = '0'
            OnChange = VersionChange
          end
          object MVN4: TMaskEdit
            Left = 338
            Top = 39
            Width = 70
            Height = 23
            TabOrder = 3
            Text = '0'
            OnChange = VersionChange
          end
          object UD4: TUpDown
            Left = 407
            Top = 39
            Width = 18
            Height = 23
            Associate = MVN4
            Max = 32767
            TabOrder = 4
            Thousands = False
          end
          object UD3: TUpDown
            Left = 298
            Top = 39
            Width = 19
            Height = 23
            Associate = MVN3
            Max = 32767
            TabOrder = 5
            Thousands = False
          end
          object UD2: TUpDown
            Left = 188
            Top = 39
            Width = 19
            Height = 23
            Associate = MVN2
            Max = 32767
            TabOrder = 6
            Thousands = False
          end
          object UD1: TUpDown
            Left = 79
            Top = 39
            Width = 19
            Height = 23
            Associate = MVN1
            Max = 32767
            Position = 1
            TabOrder = 7
            Thousands = False
          end
          object cbIncBuildNum: TCheckBox
            Left = 9
            Top = 70
            Width = 187
            Height = 15
            Caption = '&Auto-increment build number'
            TabOrder = 8
          end
        end
        object ModAttrGroup: TGroupBox
          Left = 9
          Top = 105
          Width = 292
          Height = 79
          Caption = ' Module attributes '
          TabOrder = 1
          object DebugBuild: TCheckBox
            Left = 9
            Top = 18
            Width = 103
            Height = 18
            Caption = '&Debug build'
            TabOrder = 0
          end
          object PreRelease: TCheckBox
            Left = 9
            Top = 36
            Width = 103
            Height = 18
            TabStop = False
            Caption = 'Pre-r&elease '
            TabOrder = 2
          end
          object PrivateBuild: TCheckBox
            Left = 149
            Top = 36
            Width = 93
            Height = 18
            TabStop = False
            Caption = '&Private build'
            TabOrder = 3
          end
          object SpecialBuild: TCheckBox
            Left = 149
            Top = 18
            Width = 95
            Height = 18
            TabStop = False
            Caption = '&Special build'
            TabOrder = 1
          end
          object DLL: TCheckBox
            Left = 9
            Top = 54
            Width = 54
            Height = 17
            TabStop = False
            Caption = 'D&LL'
            TabOrder = 4
          end
        end
        object ValueGrid: TStringGrid
          Left = 9
          Top = 189
          Width = 600
          Height = 160
          ColCount = 2
          DefaultColWidth = 150
          DefaultRowHeight = 18
          Enabled = False
          FixedCols = 0
          RowCount = 2
          Options = [goVertLine, goHorzLine, goColSizing, goEditing, goAlwaysShowEditor, goThumbTracking]
          PopupMenu = KeyPopup
          TabOrder = 3
          OnDrawCell = ValueGridDrawCell
          ColWidths = (
            160
            410)
        end
        object LangGroup: TGroupBox
          Left = 319
          Top = 105
          Width = 292
          Height = 79
          Caption = ' Language '
          TabOrder = 2
          object LangIDLbl: TLabel
            Left = 9
            Top = 20
            Width = 51
            Height = 15
            Caption = 'Locale &ID:'
            FocusControl = LangID
          end
          object LocaleLabel: TLabel
            Left = 75
            Top = 20
            Width = 3
            Height = 15
          end
          object LangID: TComboBox
            Left = 9
            Top = 38
            Width = 274
            Height = 23
            ItemHeight = 0
            TabOrder = 0
            Style = csDropDownList
          end
        end
      end
      object cbIncludeVerInfo: TCheckBox
        Left = 21
        Top = 9
        Width = 226
        Height = 20
        Caption = 'Include &version information in project'
        TabOrder = 0
        OnClick = IncludeVerInfoClick
      end
    end
    object tsPackages: TTabSheet
      Caption = 'Packages'
      TabVisible = False
      object pkGroupBox1: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 269
        Caption = ' Design &packages '
        TabOrder = 0
        object DesignPackageList: TCheckListBox
          Left = 9
          Top = 20
          Width = 602
          Height = 182
          ItemHeight = 16
          Sorted = True
          Style = lbOwnerDrawFixed
          TabOrder = 0
          OnClick = PackageClick
          OnClickCheck = PackageClickCheck
          OnDblClick = PackageDblClick
        end
        object pkPanel1: TPanel
          Left = 9
          Top = 205
          Width = 602
          Height = 21
          BevelOuter = bvNone
          ParentColor = True
          TabOrder = 1
          ParentBackground = False
          object shpPackageFile: TShape
            Left = 0
            Top = 0
            Width = 603
            Height = 21
            Align = alClient
            Brush.Style = bsClear
            Pen.Color = clBtnShadow
          end
          object LabelPackageFile: TLabel
            Left = 5
            Top = 3
            Width = 591
            Height = 16
            AutoSize = False
          end
        end
        object AddButton: TButton
          Left = 235
          Top = 234
          Width = 88
          Height = 26
          Action = aPkgAdd
          TabOrder = 2
        end
        object RemoveButton: TButton
          Left = 331
          Top = 234
          Width = 88
          Height = 26
          Action = aPkgRemove
          TabOrder = 3
        end
        object ButtonComponents: TButton
          Left = 523
          Top = 234
          Width = 88
          Height = 26
          Action = aPkgComponents
          TabOrder = 5
        end
        object ButtonShowFolder: TButton
          Left = 8
          Top = 234
          Width = 110
          Height = 26
          Action = aPkgFolder
          TabOrder = 6
        end
        object EditButton: TButton
          Left = 427
          Top = 234
          Width = 88
          Height = 26
          Action = aPkgEdit
          TabOrder = 4
        end
      end
      object pkGroupBox2: TGroupBox
        Left = 9
        Top = 284
        Width = 620
        Height = 77
        Caption = ' R&untime packages '
        TabOrder = 1
        object EditPackages: TEdit
          Left = 9
          Top = 44
          Width = 508
          Height = 23
          TabOrder = 1
        end
        object ModifyRuntimeButton: TButton
          Left = 523
          Top = 42
          Width = 88
          Height = 26
          Action = aRuntimeAdd
          TabOrder = 2
        end
        object RuntimePackages: TCheckBox
          Left = 9
          Top = 18
          Width = 215
          Height = 19
          Caption = '&Build with runtime packages'
          TabOrder = 0
        end
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
    ParentBackground = False
    object chkDefault: TCheckBox
      Left = 9
      Top = 0
      Width = 72
      Height = 19
      Caption = 'Default'
      TabOrder = 0
    end
  end
  object Actions: TActionList
    Left = 12
    Top = 355
    object aToAuto: TAction
      Caption = '<'
      OnExecute = FormsMoveExecute
      OnUpdate = FormsMoveUpdate
    end
    object aToAvail: TAction
      Caption = '>'
      OnExecute = FormsMoveExecute
      OnUpdate = FormsMoveUpdate
    end
    object aAllToAuto: TAction
      Caption = '<<'
      OnExecute = FormsMoveExecute
      OnUpdate = FormsMoveUpdate
    end
    object aAllToAvail: TAction
      Caption = '>>'
      OnExecute = FormsMoveExecute
      OnUpdate = FormsMoveUpdate
    end
    object aLoadIcon: TAction
      Caption = '&Load Icon...'
      OnExecute = aLoadIconExecute
    end
    object aBrowseHelp: TAction
      Caption = '&Browse...'
      OnExecute = aBrowseHelpExecute
    end
    object aDirOutput: TAction
      Caption = '...'
      OnExecute = BrowseDirExecute
    end
    object aDirUnitOutput: TAction
      Caption = '...'
      OnExecute = BrowseDirExecute
    end
    object aDirBpl: TAction
      Caption = '...'
      OnExecute = BrowseDirExecute
    end
    object aDirDcp: TAction
      Caption = '...'
      OnExecute = BrowseDirExecute
    end
    object aListSearch: TAction
      Caption = '...'
      OnExecute = EditListExecute
    end
    object aListDebugSource: TAction
      Caption = '...'
      OnExecute = EditListExecute
    end
    object aListConditionals: TAction
      Caption = '...'
      OnExecute = EditListExecute
    end
    object aListAliases: TAction
      Caption = '...'
      OnExecute = EditListExecute
    end
    object aPkgAdd: TAction
      Caption = '&Add...'
      OnExecute = aPkgAddExecute
    end
    object aPkgRemove: TAction
      Caption = '&Remove'
      OnExecute = aPkgRemoveExecute
      OnUpdate = PkgSelectedUpdate
    end
    object aPkgEdit: TAction
      Caption = '&Edit'
      OnExecute = aPkgEditExecute
      OnUpdate = PkgSelectedUpdate
    end
    object aPkgComponents: TAction
      Caption = '&Components'
      OnExecute = aPkgComponentsExecute
      OnUpdate = PkgSelectedUpdate
    end
    object aPkgFolder: TAction
      Caption = 'Show in &Folder'
      Hint = 'The package''s folder in Explorer, the package selected'
      OnExecute = aPkgFolderExecute
      OnUpdate = PkgSelectedUpdate
    end
    object aRuntimeAdd: TAction
      Caption = 'A&dd...'
      OnExecute = aRuntimeAddExecute
      OnUpdate = RuntimeUpdate
    end
    object aKeyAdd: TAction
      Caption = '&Add Key...'
      OnExecute = aKeyAddExecute
    end
    object aKeyDelete: TAction
      Caption = '&Delete Key'
      OnExecute = aKeyDeleteExecute
      OnUpdate = KeyDeleteUpdate
    end
    object aKeyRename: TAction
      Caption = '&Rename Key...'
      OnExecute = aKeyRenameExecute
      OnUpdate = KeyDeleteUpdate
    end
  end
  object KeyPopup: TPopupMenu
    Left = 44
    Top = 355
    object miKeyAdd: TMenuItem
      Action = aKeyAdd
    end
    object miKeyRename: TMenuItem
      Action = aKeyRename
    end
    object miKeyDelete: TMenuItem
      Action = aKeyDelete
    end
  end
end
