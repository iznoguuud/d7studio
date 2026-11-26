object EnvOptionsFrame: TEnvOptionsFrame
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
    Height = 414
    ActivePage = tsPreferences
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 0
    TabStop = False
    object tsPreferences: TTabSheet
      Caption = 'Preferences'
      TabVisible = False
      object AutoSave: TGroupBox
        Left = 9
        Top = 9
        Width = 220
        Height = 70
        Caption = ' Autosave options '
        TabOrder = 0
        object cbASEditor: TCheckBox
          Left = 9
          Top = 18
          Width = 199
          Height = 22
          Caption = 'Editor &files'
          TabOrder = 0
        end
        object cbASDesktop: TCheckBox
          Left = 9
          Top = 40
          Width = 194
          Height = 22
          TabStop = False
          Caption = 'Project des&ktop'
          TabOrder = 1
        end
      end
      object Repository: TGroupBox
        Left = 9
        Top = 285
        Width = 620
        Height = 54
        Caption = ' Shared repository '
        TabOrder = 5
        object lbReposDir: TLabel
          Left = 9
          Top = 23
          Width = 51
          Height = 15
          Caption = 'Di&rectory:'
          FocusControl = ecRepositoryDir
          Transparent = True
        end
        object ecRepositoryDir: TEdit
          Left = 70
          Top = 20
          Width = 442
          Height = 23
          TabOrder = 0
        end
        object RepositoryBtn: TButton
          Left = 522
          Top = 19
          Width = 89
          Height = 26
          Action = aBrowseRepository
          TabOrder = 1
        end
      end
      object gbUpdates: TGroupBox
        Left = 9
        Top = 345
        Width = 620
        Height = 48
        Caption = ' Updates '
        TabOrder = 6
        object cbCheckUpdates: TCheckBox
          Left = 9
          Top = 18
          Width = 600
          Height = 22
          Hint = 'Once a day at start-up, look for a newer release of D7 Studio on GitHub (Help | Check for Updates looks at any time)'
          Caption = 'C&heck for updates at start-up'
          TabOrder = 0
        end
      end
      object DockingBox: TGroupBox
        Left = 9
        Top = 169
        Width = 220
        Height = 81
        Caption = ' Docking '
        TabOrder = 2
        object DockHint: TLabel
          Left = 9
          Top = 40
          Width = 202
          Height = 31
          AutoSize = False
          Transparent = True
          WordWrap = True
        end
        object cbAutoDragDocking: TCheckBox
          Left = 9
          Top = 18
          Width = 202
          Height = 22
          Caption = 'A&uto drag docking'
          TabOrder = 0
        end
      end
      object DesktopContents: TRadioGroup
        Left = 9
        Top = 89
        Width = 220
        Height = 72
        Caption = ' Desktop contents '
        Items.Strings = (
          '&Desktop only'
          'Desktop and &symbols')
        TabOrder = 1
      end
      object CompilingRunning: TGroupBox
        Left = 243
        Top = 9
        Width = 386
        Height = 114
        Caption = ' Compiling and running '
        TabOrder = 3
        object cbShowProgress: TCheckBox
          Left = 9
          Top = 18
          Width = 253
          Height = 22
          Caption = 'Show &compiler progress'
          TabOrder = 0
          OnClick = ShowProgressClick
        end
        object cbAutoCloseProgress: TCheckBox
          Left = 28
          Top = 40
          Width = 266
          Height = 22
          TabStop = False
          Caption = 'Auto c&lose on successful compile'
          TabOrder = 1
        end
        object cbWarnPackageRebuild: TCheckBox
          Left = 9
          Top = 62
          Width = 253
          Height = 22
          TabStop = False
          Caption = 'W&arn on package rebuild'
          TabOrder = 2
        end
        object cbMinimizeOnRun: TCheckBox
          Left = 9
          Top = 84
          Width = 274
          Height = 22
          TabStop = False
          Caption = '&Minimize on run'
          TabOrder = 3
        end
      end
      object gbUserInterface: TGroupBox
        Left = 243
        Top = 133
        Width = 386
        Height = 146
        Caption = ' User interface '
        TabOrder = 4
        object lblUIFont: TLabel
          Left = 9
          Top = 23
          Width = 28
          Height = 15
          Caption = 'Fo&nt:'
          FocusControl = cbUIFont
        end
        object lblFixedFont: TLabel
          Left = 9
          Top = 54
          Width = 75
          Height = 15
          Caption = 'Fi&xed-size font:'
          FocusControl = cbFixedFont
        end
        object lblZoomKey: TLabel
          Left = 9
          Top = 85
          Width = 55
          Height = 15
          Caption = 'Zoom ke&y:'
          FocusControl = cbZoomKey
        end
        object lblDialogBackground: TLabel
          Left = 9
          Top = 116
          Width = 45
          Height = 15
          Caption = 'Dialo&gs:'
          FocusControl = cbDialogBackground
        end
        object cbUIFont: TComboBox
          Left = 92
          Top = 20
          Width = 205
          Height = 23
          Hint = 'The font of the user interface; it takes effect when D7 Studio starts again'
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 0
          OnDropDown = WideListDropDown
        end
        object cbUIFontSize: TComboBox
          Left = 305
          Top = 20
          Width = 72
          Height = 23
          Hint = 'The size of the user interface font; it takes effect when D7 Studio starts again'
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 1
        end
        object cbFixedFont: TComboBox
          Left = 92
          Top = 51
          Width = 205
          Height = 23
          Hint = 'The fixed-size font of the debugger'#39's views (Watch List, Call Stack, Event Log, CPU ...) and of the update notes'
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 2
          OnDropDown = WideListDropDown
        end
        object cbFixedFontSize: TComboBox
          Left = 305
          Top = 51
          Width = 72
          Height = 23
          Hint = 'The size of the fixed-size font'
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 3
        end
        object cbZoomKey: TComboBox
          Left = 92
          Top = 82
          Width = 285
          Height = 23
          Hint = 'The key held with the mouse wheel to zoom the editors, the designer, the diagram and the resources'
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 4
        end
        object cbDialogBackground: TComboBox
          Left = 92
          Top = 113
          Width = 285
          Height = 23
          Hint = 'The background of the dialogs; the band of their buttons stays gray'
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 5
          OnDropDown = WideListDropDown
          Items.Strings = (
            'White (the system'#39's window color)'
            'Gray (the system'#39's button face)')
        end
      end
    end
    object tsDesigner: TTabSheet
      Caption = 'Designer'
      TabVisible = False
      object FormDesigner: TGroupBox
        Left = 326
        Top = 9
        Width = 303
        Height = 158
        Caption = ' Options '
        TabOrder = 2
        object cbShowComponentCaptions: TCheckBox
          Left = 9
          Top = 18
          Width = 261
          Height = 22
          Caption = 'Sho&w component captions'
          TabOrder = 0
        end
        object cbShowDesignerHints: TCheckBox
          Left = 9
          Top = 40
          Width = 250
          Height = 22
          TabStop = False
          Caption = 'Show designer h&ints'
          TabOrder = 1
        end
        object cbShowExtendedControlHints: TCheckBox
          Left = 28
          Top = 62
          Width = 262
          Height = 22
          TabStop = False
          Caption = 'Show &extended control hints'
          TabOrder = 2
        end
        object cbShowFormPositioner: TCheckBox
          Left = 9
          Top = 84
          Width = 261
          Height = 22
          TabStop = False
          Caption = 'Show form p&ositioner'
          TabOrder = 3
        end
        object cbPositionerSnap: TCheckBox
          Left = 28
          Top = 106
          Width = 262
          Height = 22
          TabStop = False
          Caption = 'Posi&tioner snap lines'
          TabOrder = 4
        end
        object cbShowNonVisualComponents: TCheckBox
          Left = 9
          Top = 128
          Width = 290
          Height = 22
          TabStop = False
          Caption = 'Show non-&visual components'
          TabOrder = 5
          Visible = False
        end
      end
      object GridOptions: TGroupBox
        Left = 9
        Top = 9
        Width = 303
        Height = 122
        Caption = ' Grid options '
        TabOrder = 0
        object lbGridSizeX: TLabel
          Left = 48
          Top = 92
          Width = 7
          Height = 15
          Alignment = taRightJustify
          Caption = '&X'
          FocusControl = ecGridSizeX
        end
        object lbGridSizeY: TLabel
          Left = 136
          Top = 92
          Width = 7
          Height = 15
          Caption = '&Y'
          FocusControl = ecGridSizeY
        end
        object lbGridSize: TLabel
          Left = 30
          Top = 65
          Width = 44
          Height = 15
          Caption = 'Grid size'
          Transparent = True
        end
        object cbDisplayGrid: TCheckBox
          Left = 9
          Top = 18
          Width = 250
          Height = 22
          Caption = 'Display &grid'
          TabOrder = 0
        end
        object cbSnapToGrid: TCheckBox
          Left = 9
          Top = 40
          Width = 250
          Height = 22
          TabStop = False
          Caption = 'Sna&p to grid'
          TabOrder = 1
        end
        object ecGridSizeX: TEdit
          Left = 60
          Top = 89
          Width = 47
          Height = 23
          TabOrder = 2
          Text = '8'
        end
        object ecGridSizeY: TEdit
          Left = 148
          Top = 89
          Width = 47
          Height = 23
          TabOrder = 3
          Text = '8'
        end
        object udGridSizeX: TUpDown
          Left = 106
          Top = 89
          Width = 14
          Height = 23
          Associate = ecGridSizeX
          Min = 2
          Max = 128
          Position = 8
          TabOrder = 4
        end
        object udGridSizeY: TUpDown
          Left = 195
          Top = 89
          Width = 14
          Height = 23
          Associate = ecGridSizeY
          Min = 2
          Max = 128
          Position = 8
          TabOrder = 5
        end
      end
      object ModuleCreationOptions: TGroupBox
        Left = 9
        Top = 144
        Width = 303
        Height = 70
        Caption = ' Module creation options '
        TabOrder = 1
        object cbDFMsAsText: TCheckBox
          Left = 9
          Top = 18
          Width = 272
          Height = 22
          Caption = '&New forms as text'
          TabOrder = 0
        end
        object cbAutoCreateForms: TCheckBox
          Left = 9
          Top = 40
          Width = 285
          Height = 22
          TabStop = False
          Caption = 'A&uto create forms && data modules'
          TabOrder = 1
        end
      end
      object SnapLineOptions: TGroupBox
        Left = 9
        Top = 220
        Width = 620
        Height = 77
        Caption = ' Snap lines '
        TabOrder = 3
        object lbSnapDistance: TLabel
          Left = 9
          Top = 47
          Width = 73
          Height = 15
          Caption = 'Snap &distance'
          FocusControl = ecSnapDistance
        end
        object lbSnapSpacing: TLabel
          Left = 172
          Top = 47
          Width = 42
          Height = 15
          Caption = 'Spa&cing'
          FocusControl = ecSnapSpacing
        end
        object lbSnapMargin: TLabel
          Left = 305
          Top = 47
          Width = 38
          Height = 15
          Caption = 'M&argin'
          FocusControl = ecSnapMargin
        end
        object cbSnapLines: TCheckBox
          Left = 9
          Top = 18
          Width = 177
          Height = 22
          Caption = 'Use snap &lines'
          TabOrder = 0
        end
        object ecSnapDistance: TEdit
          Left = 92
          Top = 44
          Width = 47
          Height = 23
          TabOrder = 1
          Text = '5'
        end
        object udSnapDistance: TUpDown
          Left = 138
          Top = 44
          Width = 14
          Height = 23
          Associate = ecSnapDistance
          Min = 1
          Max = 32
          Position = 5
          TabOrder = 2
        end
        object ecSnapSpacing: TEdit
          Left = 224
          Top = 44
          Width = 47
          Height = 23
          TabOrder = 3
          Text = '8'
        end
        object udSnapSpacing: TUpDown
          Left = 271
          Top = 44
          Width = 14
          Height = 23
          Associate = ecSnapSpacing
          Max = 64
          Position = 8
          TabOrder = 4
        end
        object ecSnapMargin: TEdit
          Left = 353
          Top = 44
          Width = 47
          Height = 23
          TabOrder = 5
          Text = '8'
        end
        object udSnapMargin: TUpDown
          Left = 400
          Top = 44
          Width = 14
          Height = 23
          Associate = ecSnapMargin
          Max = 64
          Position = 8
          TabOrder = 6
        end
      end
    end
    object tsObjInsp: TTabSheet
      Caption = 'Object Inspector'
      TabVisible = False
      object oiLabel1: TLabel
        Left = 23
        Top = 9
        Width = 77
        Height = 15
        Caption = '&SpeedSettings:'
        FocusControl = cbSpeedSettings
        Transparent = True
      end
      object gbOptions: TGroupBox
        Left = 327
        Top = 9
        Width = 302
        Height = 177
        Caption = ' Options '
        TabOrder = 2
        object cbShowInstanceList: TCheckBox
          Left = 9
          Top = 18
          Width = 281
          Height = 19
          Caption = 'Show &instance list'
          TabOrder = 0
        end
        object cbShowClassnames: TCheckBox
          Left = 9
          Top = 40
          Width = 281
          Height = 19
          TabStop = False
          Caption = 'Show &classname in instance list'
          TabOrder = 1
        end
        object cbShowStatusBar: TCheckBox
          Left = 9
          Top = 62
          Width = 281
          Height = 19
          TabStop = False
          Caption = 'Show status &bar'
          TabOrder = 2
        end
        object cbRenderBackgroundGrid: TCheckBox
          Left = 9
          Top = 84
          Width = 281
          Height = 19
          TabStop = False
          Caption = 'Render background &grid'
          TabOrder = 3
        end
        object cbIntegralHeight: TCheckBox
          Left = 9
          Top = 106
          Width = 290
          Height = 19
          TabStop = False
          Caption = 'I&ntegral height (when not docked)'
          TabOrder = 4
        end
        object cbShowReadOnlyProps: TCheckBox
          Left = 9
          Top = 128
          Width = 281
          Height = 19
          TabStop = False
          Caption = 'Show &read only properties'
          TabOrder = 5
        end
        object cbBoldNonDefault: TCheckBox
          Left = 9
          Top = 150
          Width = 281
          Height = 19
          TabStop = False
          Caption = 'B&old non default values'
          TabOrder = 6
        end
      end
      object gbCompRefs: TGroupBox
        Left = 327
        Top = 235
        Width = 302
        Height = 67
        Caption = ' References '
        TabOrder = 3
        object cbReferenceExpandable: TCheckBox
          Left = 9
          Top = 18
          Width = 281
          Height = 19
          Caption = 'E&xpand inline'
          TabOrder = 0
        end
        object cbReferenceOnEventsPage: TCheckBox
          Left = 9
          Top = 40
          Width = 281
          Height = 19
          TabStop = False
          Caption = 'Show on events &page'
          TabOrder = 1
        end
      end
      object gbColors: TGroupBox
        Left = 9
        Top = 63
        Width = 303
        Height = 284
        Caption = ' Colors '
        TabOrder = 1
        object lbColors: TListBox
          Left = 9
          Top = 20
          Width = 285
          Height = 225
          Style = lbOwnerDrawFixed
          ItemHeight = 16
          TabOrder = 0
          OnClick = ColorListClick
        end
        object cbColorPicker: TColorBox
          Left = 9
          Top = 252
          Width = 285
          Height = 22
          Style = [cbStandardColors, cbExtendedColors, cbSystemColors, cbCustomColor, cbPrettyNames]
          ItemHeight = 16
          TabOrder = 1
          OnChange = ColorPickerChange
        end
      end
      object cbSpeedSettings: TComboBox
        Left = 23
        Top = 27
        Width = 205
        Height = 23
        Style = csDropDownList
        ItemHeight = 15
        TabOrder = 0
        Items.Strings = (
          'Custom colors and settings'
          'Default colors and settings'
          'Delphi 5 emulation'
          'Visual Studio (TM) emulation')
        OnChange = SpeedSettingsChange
      end
    end
    object tsPalette: TTabSheet
      Caption = 'Palette'
      TabVisible = False
      object PageLabel: TLabel
        Left = 9
        Top = 9
        Width = 58
        Height = 19
        AutoSize = False
        Caption = '&Pages:'
        FocusControl = PageListBox
      end
      object ToolLabel: TLabel
        Left = 160
        Top = 9
        Width = 123
        Height = 19
        AutoSize = False
        Caption = '&Components:'
        FocusControl = ToolListBox
      end
      object PageListBox: TListBox
        Left = 9
        Top = 27
        Width = 131
        Height = 338
        Style = lbOwnerDrawFixed
        ItemHeight = 13
        TabOrder = 0
        OnClick = PageListClick
        OnEnter = PaletteListEnter
        OnDragOver = PageDragOver
        OnDragDrop = PageDragDrop
      end
      object AddButton: TButton
        Left = 9
        Top = 379
        Width = 118
        Height = 26
        Action = aPageAdd
        TabOrder = 2
      end
      object DeleteButton: TButton
        Left = 134
        Top = 379
        Width = 118
        Height = 26
        Action = aPageDelete
        TabOrder = 3
      end
      object RenameButton: TButton
        Left = 260
        Top = 379
        Width = 118
        Height = 26
        Action = aPageRename
        TabOrder = 4
      end
      object ResetPaletteBtn: TButton
        Left = 445
        Top = 379
        Width = 184
        Height = 26
        Action = aDefaultPages
        TabOrder = 5
      end
      object ToolListPanel: TPanel
        Left = 160
        Top = 27
        Width = 469
        Height = 338
        BevelOuter = bvNone
        BorderStyle = bsSingle
        Caption = 'ToolListPanel'
        ParentColor = True
        TabOrder = 1
        object ToolListHeader: THeaderControl
          Left = 0
          Top = 0
          Width = 465
          Height = 20
          Sections = <
            item
              ImageIndex = -1
              MinWidth = 32
              Text = 'Name'
              Width = 120
            end
            item
              ImageIndex = -1
              Text = 'Package'
              Width = 75
            end
            item
              ImageIndex = -1
              Text = 'Page'
              Width = 75
            end>
        end
        object ToolListBox: TListBox
          Left = 0
          Top = 20
          Width = 465
          Height = 314
          Style = lbOwnerDrawFixed
          Align = alClient
          BorderStyle = bsNone
          ItemHeight = 28
          TabOrder = 0
          DragMode = dmAutomatic
          OnEnter = PaletteListEnter
          OnDrawItem = ToolDrawItem
        end
      end
      object MoveUp: TButton
        Left = 385
        Top = 379
        Width = 118
        Height = 26
        Action = aMoveUp
        TabOrder = 6
      end
      object MoveDn: TButton
        Left = 511
        Top = 379
        Width = 118
        Height = 26
        Action = aMoveDown
        TabOrder = 7
      end
    end
    object tsLibrary: TTabSheet
      Caption = 'Library'
      TabVisible = False
      object lbLabel3: TLabel
        Left = 9
        Top = 42
        Width = 115
        Height = 15
        Alignment = taRightJustify
        AutoSize = False
        Caption = 'BP&L output directory:'
        FocusControl = ecDLLOutput
        Transparent = True
      end
      object lbLabel16: TLabel
        Left = 9
        Top = 72
        Width = 115
        Height = 15
        Alignment = taRightJustify
        AutoSize = False
        Caption = 'DCP output di&rectory:'
        FocusControl = ecDCPOutput
        Transparent = True
      end
      object lbLabel17: TLabel
        Left = 9
        Top = 12
        Width = 115
        Height = 15
        Alignment = taRightJustify
        AutoSize = False
        Caption = 'Li&brary path:'
        FocusControl = ecLibraryPath
        Transparent = True
      end
      object lbLabel2: TLabel
        Left = 9
        Top = 102
        Width = 115
        Height = 18
        Alignment = taRightJustify
        AutoSize = False
        Caption = 'Bro&wsing path:'
        FocusControl = ecBrowsing
        Transparent = True
      end
      object ecDLLOutput: TComboBox
        Left = 131
        Top = 39
        Width = 471
        Height = 24
        ItemHeight = 0
        TabOrder = 2
      end
      object ecDCPOutput: TComboBox
        Left = 131
        Top = 69
        Width = 471
        Height = 24
        ItemHeight = 0
        TabOrder = 4
      end
      object ecLibraryPath: TComboBox
        Left = 131
        Top = 9
        Width = 471
        Height = 24
        ItemHeight = 0
        TabOrder = 0
      end
      object bDirSearch: TButton
        Left = 605
        Top = 9
        Width = 24
        Height = 24
        Action = aListLibrary
        TabOrder = 1
      end
      object ecBrowsing: TComboBox
        Left = 131
        Top = 99
        Width = 471
        Height = 24
        ItemHeight = 0
        TabOrder = 6
      end
      object bBrowsing: TButton
        Left = 605
        Top = 99
        Width = 24
        Height = 24
        Action = aListBrowsing
        TabOrder = 7
      end
      object bDPLOutput: TButton
        Left = 605
        Top = 39
        Width = 24
        Height = 24
        Action = aDirBpl
        TabOrder = 3
      end
      object bDCPOutput: TButton
        Left = 605
        Top = 69
        Width = 24
        Height = 24
        Action = aDirDcp
        TabOrder = 5
      end
    end
    object tsExplorer: TTabSheet
      Caption = 'Explorer'
      TabVisible = False
      object exLabel2: TLabel
        Left = 326
        Top = 9
        Width = 140
        Height = 15
        AutoSize = False
        Caption = 'Explorer ca&tegories:'
        FocusControl = CategoryList
      end
      object Sorting: TRadioGroup
        Left = 9
        Top = 127
        Width = 303
        Height = 60
        Caption = ' Explorer sorting '
        Items.Strings = (
          'Alpha&betical'
          '&Source')
        TabOrder = 1
      end
      object OptionsBox: TGroupBox
        Left = 9
        Top = 9
        Width = 303
        Height = 111
        Caption = ' Explorer options '
        TabOrder = 0
        object ShowInEditor: TCheckBox
          Left = 9
          Top = 18
          Width = 203
          Height = 19
          Caption = '&Automatically show Explorer'
          TabOrder = 0
        end
        object HighlightIncomplete: TCheckBox
          Left = 9
          Top = 40
          Width = 203
          Height = 19
          Caption = 'Highlight &incomplete class items'
          TabOrder = 1
        end
        object exPropCheckBox1: TCheckBox
          Left = 9
          Top = 62
          Width = 203
          Height = 19
          Caption = 'Show &declaration syntax'
          TabOrder = 2
        end
        object SyncEditor: TCheckBox
          Left = 9
          Top = 84
          Width = 203
          Height = 19
          Caption = 'Synchronize with the &editor'
          TabOrder = 3
        end
      end
      object CompletionOptions: TGroupBox
        Left = 9
        Top = 193
        Width = 303
        Height = 48
        Caption = ' Class completion option '
        TabOrder = 2
        object CompleteProperties: TCheckBox
          Left = 9
          Top = 18
          Width = 217
          Height = 22
          Caption = '&Finish incomplete properties'
          TabOrder = 0
        end
      end
      object CategoryList: TCheckListBox
        Left = 326
        Top = 27
        Width = 303
        Height = 338
        Color = clWindow
        ItemHeight = 16
        ParentShowHint = False
        ShowHint = True
        Style = lbOwnerDrawFixed
        TabOrder = 5
        OnDragDrop = CategoryListDragDrop
        OnDragOver = CategoryListDragOver
        OnDrawItem = CategoryListDrawItem
        OnEndDrag = CategoryListEndDrag
        OnKeyDown = CategoryListKeyDown
        OnMouseDown = CategoryListMouseDown
      end
      object exPropRadioGroup1: TRadioGroup
        Left = 9
        Top = 247
        Width = 303
        Height = 46
        Caption = ' Initial browser view '
        Columns = 3
        Items.Strings = (
          '&Classes'
          '&Units'
          '&Globals')
        TabOrder = 3
      end
      object exPropRadioGroup2: TRadioGroup
        Left = 9
        Top = 301
        Width = 303
        Height = 64
        Caption = ' Browser scope '
        Items.Strings = (
          '&Project symbols only'
          'A&ll symbols')
        TabOrder = 4
      end
    end
    object tsTypeLibrary: TTabSheet
      Caption = 'Type Library'
      TabVisible = False
      object OverridePanel: TGroupBox
        Left = 9
        Top = 115
        Width = 620
        Height = 104
        TabOrder = 2
        object PreDeclIDOverride: TCheckBox
          Left = 27
          Top = 11
          Width = 114
          Height = 19
          Caption = 'Prede&fined'
          Enabled = False
          TabOrder = 0
        end
        object ReservedOverride: TCheckBox
          Left = 27
          Top = 33
          Width = 114
          Height = 19
          Caption = '&Restricted'
          Enabled = False
          TabOrder = 1
        end
        object HiddenOverride: TCheckBox
          Left = 27
          Top = 55
          Width = 114
          Height = 19
          Caption = 'Hidde&n'
          Enabled = False
          TabOrder = 2
        end
        object CanCreateOverride: TCheckBox
          Left = 27
          Top = 77
          Width = 114
          Height = 19
          Caption = '&Can Create'
          Enabled = False
          TabOrder = 3
        end
      end
      object OverrideCheck: TCheckBox
        Left = 19
        Top = 106
        Width = 257
        Height = 19
        Caption = 'I&gnore special CoClass Flags when importing'
        TabOrder = 1
        OnClick = OverrideClick
      end
      object tlPropRadioGroup2: TRadioGroup
        Left = 9
        Top = 9
        Width = 620
        Height = 93
        Caption = ' SafeCall function mapping '
        Items.Strings = (
          '&All v-table interfaces'
          '&Only dual interfaces'
          '&Do not map')
        TabOrder = 0
      end
    end
    object tsEnvVars: TTabSheet
      Caption = 'Environment Variables'
      TabVisible = False
      object VariableOptionsFrame: TPanel
        Left = 0
        Top = 0
        Width = 638
        Height = 414
        BevelOuter = bvNone
        ParentColor = True
        TabOrder = 0
        object frGroupBox1: TGroupBox
          Left = 9
          Top = 9
          Width = 620
          Height = 196
          Caption = ' &System variables '
          TabOrder = 0
          object bAddOverride: TButton
            Left = 511
            Top = 161
            Width = 100
            Height = 26
            Action = aVarOverride
            TabOrder = 1
          end
          object frPanel1: TPanel
            Left = 9
            Top = 20
            Width = 602
            Height = 131
            BevelOuter = bvNone
            ParentColor = True
            TabOrder = 0
            object lvSystemVars: TListView
              Left = 0
              Top = 0
              Width = 603
              Height = 131
              Align = alClient
              Columns = <
                item
                  Caption = 'Variable'
                  Width = 120
                end
                item
                  Caption = 'Value'
                  Width = 240
                end>
              ColumnClick = False
              HideSelection = False
              ReadOnly = True
              RowSelect = True
              SortType = stText
              TabOrder = 0
              ViewStyle = vsReport
            end
          end
        end
        object frGroupBox2: TGroupBox
          Left = 9
          Top = 205
          Width = 620
          Height = 196
          Caption = ' &User overrides '
          TabOrder = 1
          object bNew: TButton
            Left = 335
            Top = 161
            Width = 88
            Height = 26
            Action = aVarNew
            TabOrder = 1
          end
          object bEdit: TButton
            Left = 429
            Top = 161
            Width = 88
            Height = 26
            Action = aVarEdit
            TabOrder = 2
          end
          object bDelete: TButton
            Left = 523
            Top = 161
            Width = 88
            Height = 26
            Action = aVarDelete
            TabOrder = 3
          end
          object lvUserVars: TListView
            Left = 9
            Top = 20
            Width = 602
            Height = 131
            Columns = <
              item
                Caption = 'Variable'
                Width = 120
              end
              item
                Caption = 'Value'
                Width = 240
              end>
            ColumnClick = False
            HideSelection = False
            ReadOnly = True
            RowSelect = True
            SortType = stText
            TabOrder = 0
            ViewStyle = vsReport
            OnDblClick = lvUserVarsDblClick
          end
        end
      end
    end
    object tsComponents: TTabSheet
      Caption = 'Components'
      TabVisible = False
      object lblCompNote: TLabel
        Left = 9
        Top = 237
        Width = 620
        Height = 30
        AutoSize = False
        Caption = 
          'D7 Studio'#39's own settings (Delphi 7 has no Components view). Its ' +
          'categories and their components are arranged on the Palette page' +
          '.'
        WordWrap = True
      end
      object gbCompView: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 65
        Caption = ' Components view '
        TabOrder = 0
        object chkCompClassic: TCheckBox
          Left = 9
          Top = 18
          Width = 593
          Height = 19
          Caption = '&Classic look (Component Bar'#39's)'
          TabOrder = 0
        end
        object chkCompCategories: TCheckBox
          Left = 9
          Top = 38
          Width = 593
          Height = 19
          Caption = 'Show the c&ategory under each name'
          TabOrder = 1
        end
      end
      object gbCompBar: TGroupBox
        Left = 9
        Top = 80
        Width = 620
        Height = 148
        Caption = ' Component Bar '
        TabOrder = 1
        object lblCompSort: TLabel
          Left = 9
          Top = 23
          Width = 62
          Height = 15
          Caption = 'S&ort the list:'
          FocusControl = cbCompSort
        end
        object lblCompReset: TLabel
          Left = 9
          Top = 55
          Width = 157
          Height = 15
          Caption = '&New filter after typing pauses:'
          FocusControl = edCompReset
        end
        object lblCompSeconds: TLabel
          Left = 279
          Top = 55
          Width = 95
          Height = 15
          Caption = 'seconds (0: never)'
        end
        object lblCompColor: TLabel
          Left = 9
          Top = 86
          Width = 58
          Height = 15
          Caption = 'List &colour:'
          FocusControl = cbCompColor
        end
        object lblCompHotkey: TLabel
          Left = 9
          Top = 118
          Width = 168
          Height = 15
          Caption = '&Shortcut of View | Components:'
          FocusControl = hkComp
        end
        object cbCompSort: TComboBox
          Left = 195
          Top = 20
          Width = 416
          Height = 23
          Style = csDropDownList
          ItemHeight = 15
          TabOrder = 0
          Items.Strings = (
            'By name'
            'The last used first'
            'The most used first'
            'In the palette'#39's order')
        end
        object edCompReset: TEdit
          Left = 195
          Top = 52
          Width = 60
          Height = 23
          TabOrder = 1
          Text = '0'
        end
        object udCompReset: TUpDown
          Left = 255
          Top = 52
          Width = 16
          Height = 23
          Associate = edCompReset
          Max = 60
          TabOrder = 2
        end
        object cbCompColor: TColorBox
          Left = 195
          Top = 84
          Width = 416
          Height = 22
          Style = [cbStandardColors, cbExtendedColors, cbSystemColors, cbIncludeDefault, cbCustomColor, cbPrettyNames]
          ItemHeight = 16
          TabOrder = 3
        end
        object hkComp: THotKey
          Left = 195
          Top = 115
          Width = 159
          Height = 23
          HotKey = 0
          InvalidKeys = [hcNone]
          Modifiers = []
          TabOrder = 4
        end
      end
    end
  end
  object Actions: TActionList
    Left = 12
    Top = 394
    object aBrowseRepository: TAction
      Caption = 'Br&owse...'
      OnExecute = BrowseDirExecute
    end
    object aPageAdd: TAction
      Caption = '&Add...'
      OnExecute = aPageAddExecute
    end
    object aPageDelete: TAction
      Caption = '&Delete'
      OnExecute = aPageDeleteExecute
      OnUpdate = PaletteUpdate
    end
    object aPageRename: TAction
      Caption = '&Rename...'
      OnExecute = aPageRenameExecute
      OnUpdate = PaletteUpdate
    end
    object aMoveUp: TAction
      Caption = 'Move &Up'
      OnExecute = PaletteMoveExecute
      OnUpdate = PaletteUpdate
    end
    object aMoveDown: TAction
      Caption = 'Move D&own'
      OnExecute = PaletteMoveExecute
      OnUpdate = PaletteUpdate
    end
    object aDefaultPages: TAction
      Caption = 'De&fault Pages'
      OnExecute = aDefaultPagesExecute
    end
    object aListLibrary: TAction
      Caption = '...'
      OnExecute = EditListExecute
    end
    object aListBrowsing: TAction
      Caption = '...'
      OnExecute = EditListExecute
    end
    object aDirBpl: TAction
      Caption = '...'
      OnExecute = BrowseDirExecute
    end
    object aDirDcp: TAction
      Caption = '...'
      OnExecute = BrowseDirExecute
    end
    object aVarOverride: TAction
      Caption = 'Add &Override...'
    end
    object aVarNew: TAction
      Caption = '&New...'
    end
    object aVarEdit: TAction
      Caption = '&Edit...'
    end
    object aVarDelete: TAction
      Caption = '&Delete'
    end
  end
end
