object EditorOptionsFrame: TEditorOptionsFrame
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
    ActivePage = tsGeneral
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 0
    TabStop = False
    object tsGeneral: TTabSheet
      Caption = 'General'
      TabVisible = False
      object egLabel21: TLabel
        Left = 6
        Top = 185
        Width = 144
        Height = 15
        Alignment = taRightJustify
        AutoSize = False
        Caption = 'Editor SpeedSetting:'
        Transparent = True
      end
      object lbUndo: TLabel
        Left = 89
        Top = 217
        Width = 59
        Height = 15
        Alignment = taRightJustify
        Caption = 'Undo &limit:'
        FocusControl = eoUndoLimit
        Transparent = True
      end
      object egGroupBox5: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 165
        Caption = ' Editor options '
        TabOrder = 0
        object eoInsert: TCheckBox
          Left = 9
          Top = 18
          Width = 175
          Height = 19
          TabStop = False
          Caption = '&Insert mode'
          TabOrder = 0
        end
        object eoCursorInTabs: TCheckBox
          Left = 9
          Top = 38
          Width = 175
          Height = 19
          TabStop = False
          Caption = '&Cursor through tabs'
          TabOrder = 1
        end
        object eoGroupUndo: TCheckBox
          Left = 9
          Top = 58
          Width = 175
          Height = 19
          TabStop = False
          Caption = '&Group undo'
          TabOrder = 2
        end
        object eoCursorBeyondEOF: TCheckBox
          Left = 9
          Top = 78
          Width = 175
          Height = 19
          TabStop = False
          Caption = 'Cursor beyond &EOF'
          TabOrder = 3
        end
        object eoUndoAfterSave: TCheckBox
          Left = 383
          Top = 18
          Width = 175
          Height = 19
          TabStop = False
          Caption = 'Undo after sa&ve'
          TabOrder = 7
        end
        object eoBriefRegExp: TCheckBox
          Left = 383
          Top = 38
          Width = 203
          Height = 19
          TabStop = False
          Caption = '&BRIEF regular expressions'
          TabOrder = 8
        end
        object eoPersistentBlocks: TCheckBox
          Left = 383
          Top = 58
          Width = 175
          Height = 19
          TabStop = False
          Caption = '&Persistent blocks'
          TabOrder = 9
        end
        object eoOverwriteBlocks: TCheckBox
          Left = 383
          Top = 78
          Width = 175
          Height = 19
          TabStop = False
          Caption = 'Over&write blocks'
          TabOrder = 10
        end
        object eoDoubleClickLine: TCheckBox
          Left = 9
          Top = 98
          Width = 175
          Height = 19
          TabStop = False
          Caption = '&Double click line'
          TabOrder = 4
        end
        object eoFindTextAtCursor: TCheckBox
          Left = 383
          Top = 98
          Width = 175
          Height = 19
          TabStop = False
          Caption = 'Find te&xt at cursor'
          TabOrder = 11
        end
        object eoForceCutCopyEnabled: TCheckBox
          Left = 9
          Top = 118
          Width = 212
          Height = 19
          TabStop = False
          Caption = '&Force cut and copy enabled'
          TabOrder = 5
        end
        object eoPreserveLineEnds: TCheckBox
          Left = 383
          Top = 118
          Width = 151
          Height = 19
          Caption = 'P&reserve line ends'
          TabOrder = 12
        end
        object egPropCheckBox1: TCheckBox
          Left = 9
          Top = 138
          Width = 212
          Height = 19
          TabStop = False
          Caption = '&Auto-complete text to find'
          TabOrder = 6
        end
      end
      object eoUndoLimit: TComboBox
        Left = 158
        Top = 214
        Width = 124
        Height = 23
        ItemHeight = 0
        TabOrder = 2
      end
      object SpeedSetting: TComboBox
        Left = 158
        Top = 182
        Width = 471
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 1
        Items.Strings = (
          'Default keymapping'
          'IDE classic'
          'BRIEF emulation'
          'Epsilon emulation'
          'Visual Studio emulation'
          'Visual Basic emulation'
          'New IDE Emacs')
        OnSelect = SpeedSettingSelect
      end
    end
    object tsSourceOptions: TTabSheet
      Caption = 'Source Options'
      TabVisible = False
      object soLabel4: TLabel
        Left = 9
        Top = 13
        Width = 84
        Height = 15
        Caption = 'Source &file type:'
        FocusControl = cmbxSourceFileType
      end
      object cmbxSourceFileType: TComboBox
        Left = 107
        Top = 10
        Width = 170
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 0
        OnSelect = SourceFileTypeSelect
      end
      object grbxOptions: TGroupBox
        Left = 9
        Top = 37
        Width = 620
        Height = 277
        Caption = 'Options'
        TabOrder = 3
        object soLabel1: TLabel
          Left = 41
          Top = 185
          Width = 69
          Height = 15
          Caption = 'Block &indent:'
          FocusControl = eoBlockIndent
          Transparent = True
        end
        object soLabel2: TLabel
          Left = 27
          Top = 23
          Width = 58
          Height = 15
          Caption = '&Extensions:'
          FocusControl = eoHighlightExts
          Transparent = True
        end
        object soLabel3: TLabel
          Left = 55
          Top = 215
          Width = 53
          Height = 15
          Caption = '&Tab stops:'
          FocusControl = eoTabRack
          Transparent = True
        end
        object lblSyntaxHigh: TLabel
          Left = 9
          Top = 156
          Width = 100
          Height = 15
          Caption = 'S&yntax Highlighter:'
          FocusControl = cmbxSyntaxHighlighter
        end
        object eoAutoIndentMode: TCheckBox
          Left = 9
          Top = 50
          Width = 159
          Height = 19
          Caption = '&Auto indent mode'
          TabOrder = 1
        end
        object eoBackspaceUnindents: TCheckBox
          Left = 9
          Top = 126
          Width = 159
          Height = 19
          Caption = 'Backspace &unindents'
          TabOrder = 5
        end
        object eoKeepTrailingBlanks: TCheckBox
          Left = 383
          Top = 50
          Width = 151
          Height = 19
          Caption = '&Keep trailing blanks'
          TabOrder = 6
        end
        object eoOptimalFill: TCheckBox
          Left = 9
          Top = 107
          Width = 114
          Height = 19
          Caption = '&Optimal fill'
          TabOrder = 4
        end
        object eoSmartTab: TCheckBox
          Left = 9
          Top = 88
          Width = 114
          Height = 19
          Caption = 'S&mart tab'
          TabOrder = 3
        end
        object eoUseTabChar: TCheckBox
          Left = 9
          Top = 69
          Width = 142
          Height = 19
          Caption = 'Use tab cha&racter'
          TabOrder = 2
        end
        object eoUseSyntaxHighlight: TCheckBox
          Left = 383
          Top = 107
          Width = 170
          Height = 19
          Caption = 'Use &syntax highlight'
          TabOrder = 9
        end
        object eoBlockIndent: TComboBox
          Left = 120
          Top = 182
          Width = 95
          Height = 24
          ItemHeight = 0
          TabOrder = 11
        end
        object eoTabRack: TComboBox
          Left = 120
          Top = 212
          Width = 491
          Height = 24
          ItemHeight = 0
          TabOrder = 12
        end
        object eoHighlightExts: TComboBox
          Left = 99
          Top = 20
          Width = 512
          Height = 24
          ItemHeight = 0
          TabOrder = 0
        end
        object eoShowTabChar: TCheckBox
          Left = 383
          Top = 69
          Width = 175
          Height = 19
          Caption = 'Show ta&b character'
          TabOrder = 7
        end
        object eoShowSpaceChar: TCheckBox
          Left = 383
          Top = 88
          Width = 175
          Height = 19
          Caption = 'Show s&pace character'
          TabOrder = 8
        end
        object cmbxSyntaxHighlighter: TComboBox
          Left = 120
          Top = 153
          Width = 170
          Height = 23
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 10
        end
        object btnCodeTemplates: TButton
          Left = 120
          Top = 242
          Width = 163
          Height = 26
          Action = aCodeTemplates
          TabOrder = 13
        end
      end
      object btnNew: TButton
        Left = 446
        Top = 9
        Width = 88
        Height = 26
        Action = aFileTypeNew
        TabOrder = 1
      end
      object btnDelete: TButton
        Left = 541
        Top = 9
        Width = 88
        Height = 26
        Action = aFileTypeDelete
        TabOrder = 2
      end
    end
    object tsDisplay: TTabSheet
      Caption = 'Display'
      TabVisible = False
      object dpLabel4: TLabel
        Left = 81
        Top = 237
        Width = 59
        Height = 15
        Caption = 'Editor &font:'
        FocusControl = FontName
        Transparent = True
      end
      object dpLabel7: TLabel
        Left = 314
        Top = 237
        Width = 23
        Height = 15
        Caption = '&Size:'
        FocusControl = FontSize
      end
      object dpLabel16: TLabel
        Left = 9
        Top = 281
        Width = 42
        Height = 15
        Caption = 'Sample:'
        Transparent = True
      end
      object dpGroupBox11: TGroupBox
        Left = 9
        Top = 86
        Width = 620
        Height = 89
        Caption = ' Margin and gutter '
        TabOrder = 1
        object lbRightMargin: TLabel
          Left = 214
          Top = 15
          Width = 72
          Height = 15
          Caption = 'Right &margin:'
          FocusControl = eoRightMargin
          Transparent = True
        end
        object lbGutterWidth: TLabel
          Left = 354
          Top = 15
          Width = 69
          Height = 15
          Caption = 'Gutter &width:'
          FocusControl = eoGutterWidth
          Transparent = True
        end
        object eoLineOnMargin: TCheckBox
          Left = 9
          Top = 18
          Width = 161
          Height = 19
          Caption = '&Visible right margin'
          TabOrder = 0
        end
        object eoRightMargin: TComboBox
          Left = 214
          Top = 33
          Width = 75
          Height = 24
          ItemHeight = 0
          TabOrder = 3
        end
        object eoGutterWidth: TComboBox
          Left = 354
          Top = 33
          Width = 75
          Height = 24
          ItemHeight = 0
          TabOrder = 4
        end
        object eoVisibleGutter: TCheckBox
          Left = 9
          Top = 40
          Width = 114
          Height = 19
          TabStop = False
          Caption = 'Visible &gutter'
          TabOrder = 1
        end
        object chkLineNumbers: TCheckBox
          Left = 455
          Top = 18
          Width = 161
          Height = 19
          Caption = '&Line numbers'
          TabOrder = 5
        end
        object chkFolding: TCheckBox
          Left = 455
          Top = 40
          Width = 161
          Height = 19
          Caption = 'Code fol&ding'
          TabOrder = 6
          OnClick = chkFoldingClick
        end
        object chkFoldPreview: TCheckBox
          Left = 455
          Top = 62
          Width = 161
          Height = 19
          Caption = 'Fold pr&eview'
          TabOrder = 7
        end
        object chkChangeBars: TCheckBox
          Left = 9
          Top = 62
          Width = 161
          Height = 19
          Caption = 'Modified l&ine indicators'
          TabOrder = 2
        end
      end
      object dpGroupBox10: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 71
        Caption = ' Display and file options '
        TabOrder = 0
        object eoBriefCursors: TCheckBox
          Left = 9
          Top = 18
          Width = 175
          Height = 19
          Caption = 'BRIEF &cursor shapes'
          TabOrder = 0
        end
        object lbHistoryLimit: TLabel
          Left = 214
          Top = 41
          Width = 84
          Height = 15
          Caption = 'Versions ke&pt:'
          FocusControl = cbHistoryLimit
          Transparent = True
        end
        object chkKeepHistory: TCheckBox
          Left = 9
          Top = 40
          Width = 175
          Height = 19
          TabStop = False
          Caption = 'Keep file &history'
          TabOrder = 1
          OnClick = chkKeepHistoryClick
        end
        object cbSortPagesMenu: TCheckBox
          Left = 383
          Top = 18
          Width = 187
          Height = 19
          TabStop = False
          Caption = 'S&ort popup pages menu'
          TabOrder = 4
        end
        object chkWordWrap: TCheckBox
          Left = 383
          Top = 40
          Width = 187
          Height = 19
          Caption = 'Word w&rap'
          TabOrder = 5
        end
        object chkNavigationBar: TCheckBox
          Left = 214
          Top = 18
          Width = 161
          Height = 19
          Caption = '&Navigation bar'
          TabOrder = 2
        end
        object cbHistoryLimit: TComboBox
          Left = 302
          Top = 38
          Width = 66
          Height = 23
          ItemHeight = 15
          TabOrder = 3
          Items.Strings = (
            '10'
            '25'
            '50'
            '100'
            '200'
            '500')
        end
      end
      object gbScrollBars: TGroupBox
        Left = 9
        Top = 181
        Width = 620
        Height = 49
        Caption = ' Scroll bars '
        TabOrder = 2
        object lbMinimap: TLabel
          Left = 383
          Top = 19
          Width = 58
          Height = 15
          Caption = 'Minim&ap:'
          FocusControl = cbMinimap
          Transparent = True
        end
        object chkScrollMarkers: TCheckBox
          Left = 9
          Top = 18
          Width = 365
          Height = 19
          Caption = 'Mar&kers: changes, matches, breakpoints, bookmarks, the caret'
          TabOrder = 0
        end
        object cbMinimap: TComboBox
          Left = 455
          Top = 16
          Width = 155
          Height = 23
          Style = csDropDownList
          ItemHeight = 15
          TabOrder = 1
          Items.Strings = (
            'Enabled'
            'Enabled + preview'
            'Disabled')
        end
      end
      object FontName: TComboBox
        Left = 81
        Top = 257
        Width = 217
        Height = 24
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 3
        OnChange = FontChanged
      end
      object FontSize: TComboBox
        Left = 314
        Top = 257
        Width = 74
        Height = 24
        ItemHeight = 0
        TabOrder = 4
        Items.Strings = (
          '6'
          '7'
          '8'
          '9'
          '10'
          '11'
          '12'
          '13'
          '14'
          '16'
          '18'
          '20'
          '24')
        OnChange = FontChanged
      end
      object FontSample: TPanel
        Left = 9
        Top = 304
        Width = 620
        Height = 94
        BevelOuter = bvNone
        Caption = 'AaBbYyZz'
        ParentColor = True
        TabOrder = 5
        object shpFontSample: TShape
          Left = 0
          Top = 0
          Width = 620
          Height = 94
          Align = alClient
          Brush.Style = bsClear
          Pen.Color = clBtnShadow
        end
      end
    end
    object tsKeyMappings: TTabSheet
      Caption = 'Key Mappings'
      TabVisible = False
      object kmLabel1: TLabel
        Left = 9
        Top = 9
        Width = 122
        Height = 15
        Caption = '&Key mapping modules:'
        FocusControl = Emulations
        Transparent = True
      end
      object kmLabel2: TLabel
        Left = 317
        Top = 9
        Width = 125
        Height = 15
        Caption = '&Enhancement modules:'
        FocusControl = Enhancements
        Transparent = True
      end
      object Emulations: TListBox
        Left = 9
        Top = 27
        Width = 294
        Height = 149
        ItemHeight = 13
        TabOrder = 0
      end
      object Enhancements: TCheckListBox
        Left = 317
        Top = 27
        Width = 312
        Height = 115
        ItemHeight = 13
        TabOrder = 1
      end
      object MoveUp: TButton
        Left = 446
        Top = 148
        Width = 88
        Height = 26
        Action = aModuleUp
        TabOrder = 2
      end
      object MoveDn: TButton
        Left = 541
        Top = 148
        Width = 88
        Height = 26
        Action = aModuleDown
        TabOrder = 3
      end
    end
    object tsColor: TTabSheet
      Caption = 'Color'
      TabVisible = False
      object lblTheme: TLabel
        Left = 9
        Top = 14
        Width = 41
        Height = 15
        Caption = 'T&heme:'
        FocusControl = cbTheme
        Transparent = True
      end
      object lblElements: TLabel
        Left = 9
        Top = 42
        Width = 52
        Height = 15
        Caption = '&Elements:'
        FocusControl = tvElements
        Transparent = True
      end
      object EditControlHere: TLabel
        Left = 217
        Top = 62
        Width = 415
        Height = 253
        AutoSize = False
        Caption = 'EditControlHere'
        Visible = False
      end
      object lblForeground: TLabel
        Left = 217
        Top = 325
        Width = 67
        Height = 15
        Caption = 'F&oreground:'
        FocusControl = cbForeground
        Transparent = True
      end
      object lblBackground: TLabel
        Left = 217
        Top = 354
        Width = 67
        Height = 15
        Caption = 'B&ackground:'
        FocusControl = cbBackground
        Transparent = True
      end
      object cbTheme: TComboBox
        Left = 55
        Top = 11
        Width = 187
        Height = 23
        Style = csDropDownList
        ItemHeight = 15
        TabOrder = 0
        OnSelect = ThemeSelect
      end
      object btnThemeDuplicate: TButton
        Left = 250
        Top = 9
        Width = 76
        Height = 26
        Action = aThemeDuplicate
        TabOrder = 1
      end
      object btnThemeRename: TButton
        Left = 330
        Top = 9
        Width = 72
        Height = 26
        Action = aThemeRename
        TabOrder = 2
      end
      object btnThemeDelete: TButton
        Left = 406
        Top = 9
        Width = 68
        Height = 26
        Action = aThemeDelete
        TabOrder = 3
      end
      object btnThemeImport: TButton
        Left = 478
        Top = 9
        Width = 74
        Height = 26
        Action = aThemeImport
        TabOrder = 4
      end
      object btnThemeExport: TButton
        Left = 556
        Top = 9
        Width = 73
        Height = 26
        Action = aThemeExport
        TabOrder = 5
      end
      object tvElements: TTreeView
        Left = 9
        Top = 62
        Width = 200
        Height = 343
        HideSelection = False
        ReadOnly = True
        ShowLines = False
        TabOrder = 6
        OnChange = ElementTreeChange
      end
      object cbForeground: TColorBox
        Left = 295
        Top = 323
        Width = 180
        Height = 22
        Style = [cbStandardColors, cbExtendedColors, cbSystemColors, cbIncludeDefault, cbCustomColor, cbPrettyNames]
        ItemHeight = 16
        TabOrder = 7
        OnSelect = ElementColorSelect
      end
      object edForeground: TEdit
        Left = 481
        Top = 323
        Width = 72
        Height = 23
        TabOrder = 8
        OnChange = ElementHexChange
      end
      object cbBackground: TColorBox
        Left = 295
        Top = 352
        Width = 180
        Height = 22
        Style = [cbStandardColors, cbExtendedColors, cbSystemColors, cbIncludeDefault, cbCustomColor, cbPrettyNames]
        ItemHeight = 16
        TabOrder = 9
        OnSelect = ElementColorSelect
      end
      object edBackground: TEdit
        Left = 481
        Top = 352
        Width = 72
        Height = 23
        TabOrder = 10
        OnChange = ElementHexChange
      end
      object chkBold: TCheckBox
        Left = 295
        Top = 386
        Width = 66
        Height = 19
        Caption = '&Bold'
        TabOrder = 11
        OnClick = ElementStyleClick
      end
      object chkItalic: TCheckBox
        Left = 367
        Top = 386
        Width = 66
        Height = 19
        Caption = '&Italic'
        TabOrder = 12
        OnClick = ElementStyleClick
      end
      object chkUnderline: TCheckBox
        Left = 439
        Top = 386
        Width = 90
        Height = 19
        Caption = '&Underline'
        TabOrder = 13
        OnClick = ElementStyleClick
      end
      object lbCompletionSample: TListBox
        Left = 303
        Top = 146
        Width = 320
        Height = 164
        Style = lbOwnerDrawFixed
        ItemHeight = 18
        TabOrder = 14
        TabStop = False
        Visible = False
        OnClick = CompletionSampleClick
        OnDrawItem = CompletionSampleDrawItem
      end
    end
    object tsCodeInsight: TTabSheet
      Caption = 'Code Insight'
      TabVisible = False
      object ciGroupBox14: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 125
        Caption = ' Automatic features '
        TabOrder = 0
        object ciLabel13: TLabel
          Left = 404
          Top = 18
          Width = 32
          Height = 15
          Caption = '&Delay:'
          FocusControl = DelayAmount
          Transparent = True
        end
        object ciLabel14: TLabel
          Left = 404
          Top = 76
          Width = 35
          Height = 15
          Caption = '0.1 sec'
          Transparent = True
        end
        object ciLabel15: TLabel
          Left = 553
          Top = 76
          Width = 35
          Height = 15
          Caption = '1.5 sec'
          Transparent = True
        end
        object cbCodeCompletion: TCheckBox
          Left = 9
          Top = 18
          Width = 203
          Height = 19
          Caption = 'Code &completion'
          TabOrder = 0
        end
        object DelayAmount: TTrackBar
          Left = 399
          Top = 42
          Width = 177
          Height = 26
          Max = 15
          Min = 1
          PageSize = 1
          Position = 1
          TabOrder = 3
        end
        object cbCodeParameters: TCheckBox
          Left = 9
          Top = 38
          Width = 203
          Height = 19
          TabStop = False
          Caption = 'Code &parameters'
          TabOrder = 1
        end
        object cbEvalHints: TCheckBox
          Left = 9
          Top = 58
          Width = 226
          Height = 19
          TabStop = False
          Caption = 'Tooltip e&xpression evaluation'
          TabOrder = 2
        end
        object cbDeclInfo: TCheckBox
          Left = 9
          Top = 78
          Width = 385
          Height = 19
          TabStop = False
          Caption = 'Tooltip symbol &insight'
          TabOrder = 4
        end
        object cbErrorInsight: TCheckBox
          Left = 9
          Top = 98
          Width = 385
          Height = 19
          Caption = '&Error Insight'
          TabOrder = 5
        end
      end
      object lblInsightNote: TLabel
        Left = 9
        Top = 142
        Width = 620
        Height = 30
        AutoSize = False
        Caption = 
          'The colours of the completion list are part of the editor'#39's colou' +
          'r theme: Color page, Code Insight.'
        WordWrap = True
      end
    end
    object tsHighlighting: TTabSheet
      Caption = 'Highlighting'
      TabVisible = False
      object lblHighlightNote: TLabel
        Left = 9
        Top = 234
        Width = 620
        Height = 45
        AutoSize = False
        Caption = 
          'The highlights take their colours from the colour theme of the ' +
          'Color page. In a Pascal unit the identifier'#39's places are found ' +
          'by code insight (a local name of one routine is not another rout' +
          'ine'#39's); elsewhere the word'#39's places are.'
        WordWrap = True
      end
      object gbMatching: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 145
        Caption = ' Matching '
        TabOrder = 0
        object chkBrackets: TCheckBox
          Left = 9
          Top = 18
          Width = 592
          Height = 19
          Caption = 'Matching brac&kets: the bracket at the caret and its partner (red: none)'
          TabOrder = 0
        end
        object chkRainbow: TCheckBox
          Left = 9
          Top = 38
          Width = 592
          Height = 19
          Caption = '&Rainbow brackets: nested pairs in alternating colours'
          TabOrder = 1
        end
        object chkBlocks: TCheckBox
          Left = 9
          Top = 58
          Width = 592
          Height = 19
          Caption = 
            'Matching &words: begin ... end, try ... except ... end, repeat .' +
            '.. until'
          TabOrder = 2
        end
        object chkIdentifiers: TCheckBox
          Left = 9
          Top = 78
          Width = 592
          Height = 19
          Caption = '&Identifiers: the other places of the symbol at the caret'
          TabOrder = 3
        end
        object chkOccurrences: TCheckBox
          Left = 9
          Top = 98
          Width = 592
          Height = 19
          Caption = '&Occurrences of the selected word'
          TabOrder = 4
        end
        object chkFindMatches: TCheckBox
          Left = 9
          Top = 118
          Width = 592
          Height = 19
          Caption = '&Find matches: every match of the last search, until Esc'
          TabOrder = 5
        end
      end
      object gbHighlightDisplay: TGroupBox
        Left = 9
        Top = 160
        Width = 620
        Height = 65
        Caption = ' Display '
        TabOrder = 1
        object chkCurrentLine: TCheckBox
          Left = 9
          Top = 18
          Width = 592
          Height = 19
          Caption = '&Current line'
          TabOrder = 0
        end
        object chkIndentGuides: TCheckBox
          Left = 9
          Top = 38
          Width = 592
          Height = 19
          Caption = 'Indentation &guides, the one of the block at the caret highlighted'
          TabOrder = 1
        end
      end
    end
    object tsTyping: TTabSheet
      Caption = 'Typing'
      TabVisible = False
      object lblTypingNote: TLabel
        Left = 9
        Top = 123
        Width = 620
        Height = 45
        AutoSize = False
        Caption = 
          'Smart indent and Block completion work in Pascal files with Auto' +
          ' indent (Source Options). The commands - Line, Multiple Carets, E' +
          'xpand Selection, Folding - are in the Edit menu, Zoom in the View' +
          ' menu.'
        WordWrap = True
      end
      object gbTyping: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 105
        Caption = ' Typing aids '
        TabOrder = 0
        object chkAutoClose: TCheckBox
          Left = 9
          Top = 18
          Width = 592
          Height = 19
          Caption = 
            '&Auto-close pairs: ( [ and quotes get their partner, a selection' +
            ' is wrapped'
          TabOrder = 0
        end
        object chkBlockCompletion: TCheckBox
          Left = 9
          Top = 38
          Width = 592
          Height = 19
          Caption = 
            '&Block completion: end, until or finally ... end after Enter on ' +
            'a new block'
          TabOrder = 1
        end
        object chkSmartIndent: TCheckBox
          Left = 9
          Top = 58
          Width = 592
          Height = 19
          Caption = 
            '&Smart indent: a level in after begin, then, do ...; end back un' +
            'der its block'
          TabOrder = 2
        end
        object chkCaretClick: TCheckBox
          Left = 9
          Top = 78
          Width = 592
          Height = 19
          Caption = 'Ctrl+Alt+c&lick adds a caret'
          TabOrder = 3
        end
      end
    end
  end
  object Actions: TActionList
    Left = 12
    Top = 386
    object aFileTypeNew: TAction
      Caption = '&New'
      OnExecute = aFileTypeNewExecute
    end
    object aFileTypeDelete: TAction
      Caption = '&Delete'
      OnExecute = aFileTypeDeleteExecute
      OnUpdate = FileTypeDeleteUpdate
    end
    object aCodeTemplates: TAction
      Caption = 'Edit &Code Templates...'
      OnExecute = aCodeTemplatesExecute
    end
    object aModuleUp: TAction
      Caption = 'Move &Up'
      OnExecute = ModuleMoveExecute
      OnUpdate = ModuleMoveUpdate
    end
    object aModuleDown: TAction
      Caption = 'Move D&own'
      OnExecute = ModuleMoveExecute
      OnUpdate = ModuleMoveUpdate
    end
    object aThemeDuplicate: TAction
      Caption = '&Duplicate...'
      OnExecute = aThemeDuplicateExecute
    end
    object aThemeRename: TAction
      Caption = '&Rename...'
      OnExecute = aThemeRenameExecute
      OnUpdate = ThemeUserUpdate
    end
    object aThemeDelete: TAction
      Caption = 'De&lete'
      OnExecute = aThemeDeleteExecute
      OnUpdate = ThemeUserUpdate
    end
    object aThemeImport: TAction
      Caption = 'I&mport...'
      OnExecute = aThemeImportExecute
    end
    object aThemeExport: TAction
      Caption = 'E&xport...'
      OnExecute = aThemeExportExecute
    end
  end
end
