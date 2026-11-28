object FormatterFrame: TFormatterFrame
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
    Height = 379
    ActivePage = tsIndentation
    Anchors = [akLeft, akTop, akRight, akBottom]
    TabOrder = 0
    TabStop = False
    object tsIndentation: TTabSheet
      Caption = 'Indentation'
      TabVisible = False
      object gbIndentation: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 137
        Caption = ' Indentation '
        TabOrder = 0
        object lbTabSize: TLabel
          Left = 9
          Top = 23
          Width = 41
          Height = 15
          Caption = 'Tab size'
          FocusControl = edTabSize
        end
        object lbIndentSize: TLabel
          Left = 295
          Top = 23
          Width = 56
          Height = 15
          Caption = 'Indent size'
          FocusControl = edIndentSize
        end
        object lbContinuationIndent: TLabel
          Left = 9
          Top = 51
          Width = 107
          Height = 15
          Caption = 'Continuation indent'
          FocusControl = edContinuationIndent
        end
        object lbDoNotIndentAfterPos: TLabel
          Left = 295
          Top = 51
          Width = 146
          Height = 15
          Caption = 'Do not indent after position'
          FocusControl = edDoNotIndentAfterPos
        end
        object lbIndentComments: TLabel
          Left = 9
          Top = 79
          Width = 94
          Height = 15
          Caption = 'Indent comments'
          FocusControl = cxIndentComments
        end
        object lbDecreaseLabelsIndent: TLabel
          Left = 9
          Top = 107
          Width = 67
          Height = 15
          Caption = 'Indent labels'
          FocusControl = cxDecreaseLabelsIndent
        end
        object edTabSize: TEdit
          Left = 139
          Top = 20
          Width = 47
          Height = 23
          TabOrder = 0
          Text = '2'
          OnChange = OptionChanged
        end
        object udTabSize: TUpDown
          Left = 186
          Top = 20
          Width = 16
          Height = 21
          Associate = edTabSize
          Min = 1
          Max = 16
          Position = 2
          TabOrder = 1
        end
        object edIndentSize: TEdit
          Left = 465
          Top = 20
          Width = 47
          Height = 23
          TabOrder = 2
          Text = '2'
          OnChange = OptionChanged
        end
        object udIndentSize: TUpDown
          Left = 512
          Top = 20
          Width = 16
          Height = 21
          Associate = edIndentSize
          Min = 1
          Max = 16
          Position = 2
          TabOrder = 3
        end
        object edContinuationIndent: TEdit
          Left = 139
          Top = 48
          Width = 47
          Height = 23
          TabOrder = 4
          Text = '2'
          OnChange = OptionChanged
        end
        object udContinuationIndent: TUpDown
          Left = 186
          Top = 48
          Width = 16
          Height = 21
          Associate = edContinuationIndent
          Max = 16
          Position = 2
          TabOrder = 5
        end
        object edDoNotIndentAfterPos: TEdit
          Left = 465
          Top = 48
          Width = 47
          Height = 23
          TabOrder = 6
          Text = '40'
          OnChange = OptionChanged
        end
        object udDoNotIndentAfterPos: TUpDown
          Left = 512
          Top = 48
          Width = 16
          Height = 21
          Associate = edDoNotIndentAfterPos
          Max = 250
          Position = 40
          TabOrder = 7
        end
        object cxIndentComments: TComboBox
          Left = 139
          Top = 76
          Width = 221
          Height = 23
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 8
          OnChange = OptionChanged
        end
        object cxDecreaseLabelsIndent: TComboBox
          Left = 139
          Top = 104
          Width = 221
          Height = 23
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 9
          OnChange = OptionChanged
        end
      end
      object gbIndent: TGroupBox
        Left = 9
        Top = 152
        Width = 620
        Height = 185
        Caption = ' Indent '
        TabOrder = 1
        object cbUseTabs: TCheckBox
          Left = 9
          Top = 18
          Width = 278
          Height = 19
          Caption = 'Use tab characters to indent'
          TabOrder = 0
          OnClick = OptionChanged
        end
        object cbIndentAsm: TCheckBox
          Left = 295
          Top = 18
          Width = 306
          Height = 19
          Caption = 'Indent assembly sections'
          TabOrder = 1
          OnClick = OptionChanged
        end
        object cbIndentCompilerDirectives: TCheckBox
          Left = 9
          Top = 38
          Width = 278
          Height = 19
          Caption = 'Indent compiler directives'
          TabOrder = 2
          OnClick = OptionChanged
        end
        object cbIndentBlockContents: TCheckBox
          Left = 295
          Top = 38
          Width = 306
          Height = 19
          Caption = 'Indent blocks between Begin and End'
          TabOrder = 3
          OnClick = OptionChanged
        end
        object cbIndentBeginAndEnd: TCheckBox
          Left = 9
          Top = 58
          Width = 278
          Height = 19
          Caption = 'Indent Begin and End keywords'
          TabOrder = 4
          OnClick = OptionChanged
        end
        object cbIndentFunctionImplementationBody: TCheckBox
          Left = 295
          Top = 58
          Width = 306
          Height = 19
          Caption = 'Indent function bodies'
          TabOrder = 5
          OnClick = OptionChanged
        end
        object cbIndentInnerFunctionImplementation: TCheckBox
          Left = 9
          Top = 78
          Width = 278
          Height = 19
          Caption = 'Indent inner functions'
          TabOrder = 6
          OnClick = OptionChanged
        end
        object cbIndentAfterSections: TCheckBox
          Left = 9
          Top = 158
          Width = 592
          Height = 19
          Caption = 'Indent interface, implementation, and other sections'
          TabOrder = 12
          OnClick = OptionChanged
        end
        object cbIndentClassDefinitionBody: TCheckBox
          Left = 9
          Top = 98
          Width = 278
          Height = 19
          Caption = 'Indent class definition bodies'
          TabOrder = 8
          OnClick = OptionChanged
        end
        object cbIndentBrackets: TCheckBox
          Left = 295
          Top = 78
          Width = 306
          Height = 19
          Caption = 'Indent nested brackets and parentheses'
          TabOrder = 7
          OnClick = OptionChanged
        end
        object cbIndentCaseContents: TCheckBox
          Left = 9
          Top = 118
          Width = 278
          Height = 19
          Caption = 'Indent case contents'
          TabOrder = 10
          OnClick = OptionChanged
        end
        object cbIndentCaseLabels: TCheckBox
          Left = 295
          Top = 98
          Width = 306
          Height = 19
          Caption = 'Indent case labels'
          TabOrder = 9
          OnClick = OptionChanged
        end
        object cbExtraIndentAfterElseInCase: TCheckBox
          Left = 9
          Top = 138
          Width = 278
          Height = 19
          Caption = 'Indent Else in case statements'
          TabOrder = 11
          OnClick = OptionChanged
        end
      end
    end
    object tsSpaces: TTabSheet
      Caption = 'Spaces'
      TabVisible = False
      object lbAssignSpaces: TLabel
        Left = 9
        Top = 12
        Width = 218
        Height = 15
        Caption = 'Set spacing around assignment operators'
        FocusControl = cxAssignSpaces
      end
      object lbMathOperatorSpaces: TLabel
        Left = 9
        Top = 40
        Width = 190
        Height = 15
        Caption = 'Set spacing around binary operators'
        FocusControl = cxMathOperatorSpaces
      end
      object lbUnaryPreOperatorSpaces: TLabel
        Left = 9
        Top = 68
        Width = 219
        Height = 15
        Caption = 'Set spacing around unary prefix operators'
        FocusControl = cxUnaryPreOperatorSpaces
      end
      object lbColonSpaces: TLabel
        Left = 9
        Top = 96
        Width = 139
        Height = 15
        Caption = 'Set spacing around colons'
        FocusControl = cxColonSpaces
      end
      object lbColonInFormatSpaces: TLabel
        Left = 9
        Top = 124
        Width = 191
        Height = 15
        Caption = 'Set spacing around colons in format'
        FocusControl = cxColonInFormatSpaces
      end
      object lbCommaSpaces: TLabel
        Left = 9
        Top = 152
        Width = 150
        Height = 15
        Caption = 'Set spacing around commas'
        FocusControl = cxCommaSpaces
      end
      object lbSemicolonSpaces: TLabel
        Left = 9
        Top = 180
        Width = 164
        Height = 15
        Caption = 'Set spacing around semicolons'
        FocusControl = cxSemicolonSpaces
      end
      object lbCommentStartInlineSpaces: TLabel
        Left = 9
        Top = 208
        Width = 151
        Height = 15
        Caption = 'Set spacing for // comments'
        FocusControl = cxCommentStartInlineSpaces
      end
      object lbCommentBracesSpaces: TLabel
        Left = 9
        Top = 236
        Width = 180
        Height = 15
        Caption = 'Set spacing for { and (* comments'
        FocusControl = cxCommentBracesSpaces
      end
      object lbSpaceAfterFunction: TLabel
        Left = 9
        Top = 264
        Width = 202
        Height = 15
        Caption = 'Spaces before parenthesis in functions'
        FocusControl = cxSpaceAfterFunction
      end
      object lbResolveSpaceConflictAs: TLabel
        Left = 9
        Top = 292
        Width = 135
        Height = 15
        Caption = 'Resolve space conflicts as'
        FocusControl = cxResolveSpaceConflictAs
      end
      object cxAssignSpaces: TComboBox
        Left = 250
        Top = 9
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 0
        OnChange = OptionChanged
      end
      object cxMathOperatorSpaces: TComboBox
        Left = 250
        Top = 37
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 1
        OnChange = OptionChanged
      end
      object cxUnaryPreOperatorSpaces: TComboBox
        Left = 250
        Top = 65
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 2
        OnChange = OptionChanged
      end
      object cxColonSpaces: TComboBox
        Left = 250
        Top = 93
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 3
        OnChange = OptionChanged
      end
      object cxColonInFormatSpaces: TComboBox
        Left = 250
        Top = 121
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 4
        OnChange = OptionChanged
      end
      object cxCommaSpaces: TComboBox
        Left = 250
        Top = 149
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 5
        OnChange = OptionChanged
      end
      object cxSemicolonSpaces: TComboBox
        Left = 250
        Top = 177
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 6
        OnChange = OptionChanged
      end
      object cxCommentStartInlineSpaces: TComboBox
        Left = 250
        Top = 205
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 7
        OnChange = OptionChanged
      end
      object cxCommentBracesSpaces: TComboBox
        Left = 250
        Top = 233
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 8
        OnChange = OptionChanged
      end
      object cxSpaceAfterFunction: TComboBox
        Left = 250
        Top = 261
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 9
        OnChange = OptionChanged
      end
      object cxResolveSpaceConflictAs: TComboBox
        Left = 250
        Top = 289
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 10
        OnChange = OptionChanged
      end
      object cbBracketSpaces: TCheckBox
        Left = 9
        Top = 317
        Width = 278
        Height = 19
        Caption = 'Set spacing for parentheses'
        TabOrder = 11
        OnClick = OptionChanged
      end
      object cbSquareBracketSpaces: TCheckBox
        Left = 295
        Top = 317
        Width = 306
        Height = 19
        Caption = 'Set spacing for square brackets'
        TabOrder = 12
        OnClick = OptionChanged
      end
    end
    object tsLineBreaks: TTabSheet
      Caption = 'Line Breaks'
      TabVisible = False
      object gbLineBreaks: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 105
        Caption = ' Line breaks '
        TabOrder = 0
        object cbKeepUserLinebreaks: TCheckBox
          Left = 9
          Top = 18
          Width = 278
          Height = 19
          Caption = 'Keep user line breaks'
          TabOrder = 0
          OnClick = OptionChanged
        end
        object cbTrimSource: TCheckBox
          Left = 295
          Top = 18
          Width = 306
          Height = 19
          Caption = 'Trim source'
          TabOrder = 1
          OnClick = OptionChanged
        end
        object cbNewLineAfterSemicolon: TCheckBox
          Left = 9
          Top = 38
          Width = 278
          Height = 19
          Caption = 'Line breaks after semicolons'
          TabOrder = 2
          OnClick = OptionChanged
        end
        object cbNewLineBeforeThen: TCheckBox
          Left = 295
          Top = 38
          Width = 306
          Height = 19
          Caption = 'Line breaks before Then'
          TabOrder = 3
          OnClick = OptionChanged
        end
        object cbNewLineBetweenElseAndIf: TCheckBox
          Left = 9
          Top = 58
          Width = 278
          Height = 19
          Caption = 'Line break inside '#39'Else If'#39
          TabOrder = 4
          OnClick = OptionChanged
        end
        object cbNewLineInPropertyDeclaration: TCheckBox
          Left = 295
          Top = 58
          Width = 306
          Height = 19
          Caption = 'Line breaks in Property declarations'
          TabOrder = 5
          OnClick = OptionChanged
        end
        object cbRemoveNewLinesInEndElseBegin: TCheckBox
          Left = 9
          Top = 78
          Width = 278
          Height = 19
          Caption = 'Remove line breaks inside '#39'End Else Begin'#39
          TabOrder = 6
          OnClick = OptionChanged
        end
        object cbRemoveNewLinesInEndElseIf: TCheckBox
          Left = 295
          Top = 78
          Width = 306
          Height = 19
          Caption = 'Remove line breaks inside '#39'End Else If'#39
          TabOrder = 7
          OnClick = OptionChanged
        end
      end
      object gbLineBreakLists: TGroupBox
        Left = 9
        Top = 120
        Width = 620
        Height = 221
        Caption = ' Declarations and lists '
        TabOrder = 1
        object lbNewLineAfterLabel: TLabel
          Left = 9
          Top = 23
          Width = 109
          Height = 15
          Caption = 'Line break after label'
          FocusControl = cxNewLineAfterLabel
        end
        object lbNewLineForEachVarAndConstElement: TLabel
          Left = 9
          Top = 51
          Width = 194
          Height = 15
          Caption = 'Line breaks in Var and Const sections'
          FocusControl = cxNewLineForEachVarAndConstElement
        end
        object lbNewLineAfterUses: TLabel
          Left = 9
          Top = 79
          Width = 166
          Height = 15
          Caption = 'Line breaks after Uses keywords'
          FocusControl = cxNewLineAfterUses
        end
        object lbNewLineForEachUseElement: TLabel
          Left = 9
          Top = 107
          Width = 140
          Height = 15
          Caption = 'Line breaks in Uses clauses'
          FocusControl = cxNewLineForEachUseElement
        end
        object lbNewLineForEachLabelElement: TLabel
          Left = 9
          Top = 135
          Width = 287
          Height = 15
          Caption = 'Line breaks in Label, Export, Requires, Contains clauses'
          FocusControl = cxNewLineForEachLabelElement
        end
        object lbNewLineInClassInheritances: TLabel
          Left = 9
          Top = 163
          Width = 157
          Height = 15
          Caption = 'Line breaks in Inheritance lists'
          FocusControl = cxNewLineInClassInheritances
        end
        object lbFormatArrayInitialization: TLabel
          Left = 9
          Top = 191
          Width = 173
          Height = 15
          Caption = 'Line breaks in array initializations'
          FocusControl = cxFormatArrayInitialization
        end
        object cxNewLineAfterLabel: TComboBox
          Left = 318
          Top = 20
          Width = 221
          Height = 23
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 0
          OnChange = OptionChanged
        end
        object cxNewLineForEachVarAndConstElement: TComboBox
          Left = 318
          Top = 48
          Width = 221
          Height = 23
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 1
          OnChange = OptionChanged
        end
        object cxNewLineAfterUses: TComboBox
          Left = 318
          Top = 76
          Width = 221
          Height = 23
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 2
          OnChange = OptionChanged
        end
        object cxNewLineForEachUseElement: TComboBox
          Left = 318
          Top = 104
          Width = 221
          Height = 23
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 3
          OnChange = OptionChanged
        end
        object cxNewLineForEachLabelElement: TComboBox
          Left = 318
          Top = 132
          Width = 221
          Height = 23
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 4
          OnChange = OptionChanged
        end
        object cxNewLineInClassInheritances: TComboBox
          Left = 318
          Top = 160
          Width = 221
          Height = 23
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 5
          OnChange = OptionChanged
        end
        object cxFormatArrayInitialization: TComboBox
          Left = 318
          Top = 188
          Width = 221
          Height = 23
          Style = csDropDownList
          ItemHeight = 0
          TabOrder = 6
          OnChange = OptionChanged
        end
      end
    end
    object tsStatements: TTabSheet
      Caption = 'Statements'
      TabVisible = False
      object lbNewLineBeforeBeginInControlBlock: TLabel
        Left = 9
        Top = 12
        Width = 244
        Height = 15
        Caption = 'Line breaks before Begin in control statements'
        FocusControl = cxNewLineBeforeBeginInControlBlock
      end
      object lbNewLineAfterBeginInControlBlock: TLabel
        Left = 9
        Top = 40
        Width = 234
        Height = 15
        Caption = 'Line breaks after Begin in control statements'
        FocusControl = cxNewLineAfterBeginInControlBlock
      end
      object lbNewLineAfterBeginInMethodDefinition: TLabel
        Left = 9
        Top = 68
        Width = 236
        Height = 15
        Caption = 'Line breaks after Begin in method definitions'
        FocusControl = cxNewLineAfterBeginInMethodDefinition
      end
      object lbNewLineAfterOtherBegin: TLabel
        Left = 9
        Top = 96
        Width = 114
        Height = 15
        Caption = 'Line break after Begin'
        FocusControl = cxNewLineAfterOtherBegin
      end
      object lbNewLineBeforeSimpleInstructionInControlBlock: TLabel
        Left = 9
        Top = 124
        Width = 310
        Height = 15
        Caption = 'Line breaks before single instructions in control statements'
        FocusControl = cxNewLineBeforeSimpleInstructionInControlBlock
      end
      object lbNewLineBeforeSimpleInstructionInTryCatchBlock: TLabel
        Left = 9
        Top = 152
        Width = 301
        Height = 15
        Caption = 'Line breaks before single instructions in try-except blocks'
        FocusControl = cxNewLineBeforeSimpleInstructionInTryCatchBlock
      end
      object lbNewLineParamTypesInFunction: TLabel
        Left = 9
        Top = 180
        Width = 241
        Height = 15
        Caption = 'One parameter per line in function definitions'
        FocusControl = cxNewLineParamTypesInFunction
      end
      object lbNewLineParamValuesInFunction: TLabel
        Left = 9
        Top = 208
        Width = 208
        Height = 15
        Caption = 'One parameter per line in function calls'
        FocusControl = cxNewLineParamValuesInFunction
      end
      object lbNewLineFunctionType: TLabel
        Left = 9
        Top = 236
        Width = 182
        Height = 15
        Caption = 'New line for a function return type'
        FocusControl = cxNewLineFunctionType
      end
      object cxNewLineBeforeBeginInControlBlock: TComboBox
        Left = 341
        Top = 9
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 0
        OnChange = OptionChanged
      end
      object cxNewLineAfterBeginInControlBlock: TComboBox
        Left = 341
        Top = 37
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 1
        OnChange = OptionChanged
      end
      object cxNewLineAfterBeginInMethodDefinition: TComboBox
        Left = 341
        Top = 65
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 2
        OnChange = OptionChanged
      end
      object cxNewLineAfterOtherBegin: TComboBox
        Left = 341
        Top = 93
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 3
        OnChange = OptionChanged
      end
      object cxNewLineBeforeSimpleInstructionInControlBlock: TComboBox
        Left = 341
        Top = 121
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 4
        OnChange = OptionChanged
      end
      object cxNewLineBeforeSimpleInstructionInTryCatchBlock: TComboBox
        Left = 341
        Top = 149
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 5
        OnChange = OptionChanged
      end
      object cxNewLineParamTypesInFunction: TComboBox
        Left = 341
        Top = 177
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 6
        OnChange = OptionChanged
      end
      object cxNewLineParamValuesInFunction: TComboBox
        Left = 341
        Top = 205
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 7
        OnChange = OptionChanged
      end
      object cxNewLineFunctionType: TComboBox
        Left = 341
        Top = 233
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 8
        OnChange = OptionChanged
      end
    end
    object tsEmptyLines: TTabSheet
      Caption = 'Empty Lines'
      TabVisible = False
      object lbMaxNumOfEmptyLines: TLabel
        Left = 9
        Top = 12
        Width = 193
        Height = 15
        Caption = 'Max number of adjacent empty lines'
        FocusControl = edMaxNumOfEmptyLines
      end
      object lbNumOfEmptyLinesAsSeparatorInInterfaceSection: TLabel
        Left = 9
        Top = 40
        Width = 291
        Height = 15
        Caption = 'Number of empty lines as separator in interface section'
        FocusControl = edNumOfEmptyLinesAsSeparatorInInterfaceSection
      end
      object lbNumOfEmptyLinesAsSeparatorInImplementationSection: TLabel
        Left = 9
        Top = 68
        Width = 330
        Height = 15
        Caption = 'Number of empty lines as separator in implementation section'
        FocusControl = edNumOfEmptyLinesAsSeparatorInImplementationSection
      end
      object lbNumOfEmptyLinesBeforeSubsection: TLabel
        Left = 9
        Top = 96
        Width = 224
        Height = 15
        Caption = 'Number of empty lines before subsections'
        FocusControl = edNumOfEmptyLinesBeforeSubsection
      end
      object lbNumOfEmptyLinesBeforeTypeKeyword: TLabel
        Left = 9
        Top = 124
        Width = 235
        Height = 15
        Caption = 'Number of empty lines before Type keyword'
        FocusControl = edNumOfEmptyLinesBeforeTypeKeyword
      end
      object lbNumOfEmptyLinesBeforeVisibility: TLabel
        Left = 9
        Top = 152
        Width = 258
        Height = 15
        Caption = 'Number of empty lines before visibility modifiers'
        FocusControl = edNumOfEmptyLinesBeforeVisibility
      end
      object lbNumOfEmptyLinesAroundSectionKeyword: TLabel
        Left = 9
        Top = 180
        Width = 257
        Height = 15
        Caption = 'Number of empty lines around section keywords'
        FocusControl = edNumOfEmptyLinesAroundSectionKeyword
      end
      object lbNumOfEmptyLinesAroundCompilerDirectives: TLabel
        Left = 9
        Top = 208
        Width = 266
        Height = 15
        Caption = 'Number of empty lines around compiler directives'
        FocusControl = edNumOfEmptyLinesAroundCompilerDirectives
      end
      object edMaxNumOfEmptyLines: TEdit
        Left = 363
        Top = 9
        Width = 47
        Height = 23
        TabOrder = 0
        Text = '1'
        OnChange = OptionChanged
      end
      object udMaxNumOfEmptyLines: TUpDown
        Left = 410
        Top = 9
        Width = 16
        Height = 23
        Associate = edMaxNumOfEmptyLines
        Max = 99
        Position = 1
        TabOrder = 1
      end
      object edNumOfEmptyLinesAsSeparatorInInterfaceSection: TEdit
        Left = 363
        Top = 37
        Width = 47
        Height = 23
        TabOrder = 2
        Text = '1'
        OnChange = OptionChanged
      end
      object udNumOfEmptyLinesAsSeparatorInInterfaceSection: TUpDown
        Left = 410
        Top = 37
        Width = 16
        Height = 23
        Associate = edNumOfEmptyLinesAsSeparatorInInterfaceSection
        Max = 10
        Position = 1
        TabOrder = 3
      end
      object edNumOfEmptyLinesAsSeparatorInImplementationSection: TEdit
        Left = 363
        Top = 65
        Width = 47
        Height = 23
        TabOrder = 4
        Text = '1'
        OnChange = OptionChanged
      end
      object udNumOfEmptyLinesAsSeparatorInImplementationSection: TUpDown
        Left = 410
        Top = 65
        Width = 16
        Height = 23
        Associate = edNumOfEmptyLinesAsSeparatorInImplementationSection
        Max = 10
        Position = 1
        TabOrder = 5
      end
      object edNumOfEmptyLinesBeforeSubsection: TEdit
        Left = 363
        Top = 93
        Width = 47
        Height = 23
        TabOrder = 6
        Text = '1'
        OnChange = OptionChanged
      end
      object udNumOfEmptyLinesBeforeSubsection: TUpDown
        Left = 410
        Top = 93
        Width = 16
        Height = 23
        Associate = edNumOfEmptyLinesBeforeSubsection
        Max = 10
        Position = 1
        TabOrder = 7
      end
      object edNumOfEmptyLinesBeforeTypeKeyword: TEdit
        Left = 363
        Top = 121
        Width = 47
        Height = 23
        TabOrder = 8
        Text = '1'
        OnChange = OptionChanged
      end
      object udNumOfEmptyLinesBeforeTypeKeyword: TUpDown
        Left = 410
        Top = 121
        Width = 16
        Height = 23
        Associate = edNumOfEmptyLinesBeforeTypeKeyword
        Max = 10
        Position = 1
        TabOrder = 9
      end
      object edNumOfEmptyLinesBeforeVisibility: TEdit
        Left = 363
        Top = 149
        Width = 47
        Height = 23
        TabOrder = 10
        Text = '0'
        OnChange = OptionChanged
      end
      object udNumOfEmptyLinesBeforeVisibility: TUpDown
        Left = 410
        Top = 149
        Width = 16
        Height = 23
        Associate = edNumOfEmptyLinesBeforeVisibility
        Max = 10
        TabOrder = 11
      end
      object edNumOfEmptyLinesAroundSectionKeyword: TEdit
        Left = 363
        Top = 177
        Width = 47
        Height = 23
        TabOrder = 12
        Text = '1'
        OnChange = OptionChanged
      end
      object udNumOfEmptyLinesAroundSectionKeyword: TUpDown
        Left = 410
        Top = 177
        Width = 16
        Height = 23
        Associate = edNumOfEmptyLinesAroundSectionKeyword
        Max = 10
        Position = 1
        TabOrder = 13
      end
      object edNumOfEmptyLinesAroundCompilerDirectives: TEdit
        Left = 363
        Top = 205
        Width = 47
        Height = 23
        TabOrder = 14
        Text = '0'
        OnChange = OptionChanged
      end
      object udNumOfEmptyLinesAroundCompilerDirectives: TUpDown
        Left = 410
        Top = 205
        Width = 16
        Height = 23
        Associate = edNumOfEmptyLinesAroundCompilerDirectives
        Max = 10
        TabOrder = 15
      end
    end
    object tsCapitalization: TTabSheet
      Caption = 'Capitalization'
      TabVisible = False
      object lbKeywordsCapitalization: TLabel
        Left = 9
        Top = 12
        Width = 244
        Height = 15
        Caption = 'Capitalization of reserved words and directives'
        FocusControl = cxKeywordsCapitalization
      end
      object lbCompilerDirectivesCapitalization: TLabel
        Left = 9
        Top = 40
        Width = 189
        Height = 15
        Caption = 'Capitalization of compiler directives'
        FocusControl = cxCompilerDirectivesCapitalization
      end
      object lbNumbersCapitalization: TLabel
        Left = 9
        Top = 68
        Width = 136
        Height = 15
        Caption = 'Capitalization of numbers'
        FocusControl = cxNumbersCapitalization
      end
      object lbOtherWordsCapitalization: TLabel
        Left = 9
        Top = 96
        Width = 152
        Height = 15
        Caption = 'Capitalization of other words'
        FocusControl = cxOtherWordsCapitalization
      end
      object cxKeywordsCapitalization: TComboBox
        Left = 275
        Top = 9
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 0
        OnChange = OptionChanged
      end
      object cxCompilerDirectivesCapitalization: TComboBox
        Left = 275
        Top = 37
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 1
        OnChange = OptionChanged
      end
      object cxNumbersCapitalization: TComboBox
        Left = 275
        Top = 65
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 2
        OnChange = OptionChanged
      end
      object cxOtherWordsCapitalization: TComboBox
        Left = 275
        Top = 93
        Width = 221
        Height = 23
        Style = csDropDownList
        ItemHeight = 0
        TabOrder = 3
        OnChange = OptionChanged
      end
    end
    object tsAlign: TTabSheet
      Caption = 'Align'
      TabVisible = False
      object gbAlign: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 125
        Caption = ' Alignment '
        TabOrder = 0
        object cbAlignAssignments: TCheckBox
          Left = 9
          Top = 18
          Width = 278
          Height = 19
          Caption = 'Align assignment operators'
          TabOrder = 0
          OnClick = OptionChanged
        end
        object cbAlignConst: TCheckBox
          Left = 295
          Top = 18
          Width = 306
          Height = 19
          Caption = 'Align '#39'='#39' in constants'
          TabOrder = 1
          OnClick = OptionChanged
        end
        object cbAlignTypeDefs: TCheckBox
          Left = 9
          Top = 38
          Width = 278
          Height = 19
          Caption = 'Align '#39'='#39' in type declarations'
          TabOrder = 2
          OnClick = OptionChanged
        end
        object cbAlignInitializations: TCheckBox
          Left = 295
          Top = 38
          Width = 306
          Height = 19
          Caption = 'Align '#39'='#39' in initializations'
          TabOrder = 3
          OnClick = OptionChanged
        end
        object cbAlignTypeNames: TCheckBox
          Left = 9
          Top = 58
          Width = 278
          Height = 19
          Caption = 'Align type names'
          TabOrder = 4
          OnClick = OptionChanged
        end
        object cbAlignTypeColon: TCheckBox
          Left = 295
          Top = 58
          Width = 306
          Height = 19
          Caption = 'Align '#39':'#39' before type names'
          TabOrder = 5
          OnClick = OptionChanged
        end
        object cbAlignParameterTypes: TCheckBox
          Left = 9
          Top = 78
          Width = 278
          Height = 19
          Caption = 'Align types of parameters'
          TabOrder = 6
          OnClick = OptionChanged
        end
        object cbAlignProperties: TCheckBox
          Left = 295
          Top = 78
          Width = 306
          Height = 19
          Caption = 'Align fields in properties'
          TabOrder = 7
          OnClick = OptionChanged
        end
        object cbAlignEndOfLineComments: TCheckBox
          Left = 9
          Top = 98
          Width = 278
          Height = 19
          Caption = 'Align end-of-line comments'
          TabOrder = 8
          OnClick = OptionChanged
        end
      end
      object gbAlignLimits: TGroupBox
        Left = 9
        Top = 140
        Width = 620
        Height = 81
        Caption = ' Limits '
        TabOrder = 1
        object lbAlignMaxColumn: TLabel
          Left = 9
          Top = 23
          Width = 157
          Height = 15
          Caption = 'Alignment maximum column'
          FocusControl = edAlignMaxColumn
        end
        object lbAlignMaxUnalignedLines: TLabel
          Left = 9
          Top = 51
          Width = 137
          Height = 15
          Caption = 'Maximum unaligned lines'
          FocusControl = edAlignMaxUnalignedLines
        end
        object edAlignMaxColumn: TEdit
          Left = 189
          Top = 20
          Width = 47
          Height = 23
          TabOrder = 0
          Text = '60'
          OnChange = OptionChanged
        end
        object udAlignMaxColumn: TUpDown
          Left = 237
          Top = 20
          Width = 16
          Height = 23
          Associate = edAlignMaxColumn
          Max = 250
          Position = 60
          TabOrder = 1
        end
        object edAlignMaxUnalignedLines: TEdit
          Left = 189
          Top = 48
          Width = 47
          Height = 23
          TabOrder = 2
          Text = '0'
          OnChange = OptionChanged
        end
        object udAlignMaxUnalignedLines: TUpDown
          Left = 237
          Top = 48
          Width = 16
          Height = 23
          Associate = edAlignMaxUnalignedLines
          Max = 10
          TabOrder = 3
        end
      end
    end
    object tsGeneral: TTabSheet
      Caption = 'General'
      TabVisible = False
      object gbGeneral: TGroupBox
        Left = 9
        Top = 9
        Width = 620
        Height = 85
        Caption = ' Formatting '
        TabOrder = 0
        object cbFormatOnSave: TCheckBox
          Left = 9
          Top = 18
          Width = 592
          Height = 19
          Caption = 'Format a Pascal source &each time it is saved'
          TabOrder = 0
        end
        object cbConfirm: TCheckBox
          Left = 9
          Top = 38
          Width = 592
          Height = 19
          Caption = '&Confirm before formatting the project sources'
          TabOrder = 1
        end
        object cbFormFiles: TCheckBox
          Left = 9
          Top = 58
          Width = 592
          Height = 19
          Caption = 
            'Format Project Sources also writes the &form files (.dfm) in Del' +
            'phi'#39's layout'
          TabOrder = 2
        end
      end
      object gbRadProfile: TGroupBox
        Left = 9
        Top = 100
        Width = 620
        Height = 78
        Caption = ' RAD Studio profiles '
        TabOrder = 1
        object lbRadProfile: TLabel
          Left = 9
          Top = 20
          Width = 420
          Height = 15
          Caption = 
            'RAD Studio'#39's formatter profiles (Formatter.config): the values s' +
            'hown, in and out'
        end
        object btnImport: TButton
          Left = 9
          Top = 43
          Width = 88
          Height = 26
          Action = aImport
          TabOrder = 0
        end
        object btnExport: TButton
          Left = 104
          Top = 43
          Width = 88
          Height = 26
          Action = aExport
          TabOrder = 1
        end
      end
    end
  end
  object Footer: TPanel
    Left = 0
    Top = 379
    Width = 638
    Height = 35
    Anchors = [akLeft, akRight, akBottom]
    BevelOuter = bvNone
    ParentColor = True
    TabOrder = 1
    DesignSize = (
      638
      35)
    ParentBackground = False
    object lbPreset: TLabel
      Left = 9
      Top = 5
      Width = 35
      Height = 15
      Caption = '&Preset:'
      FocusControl = cxPreset
    end
    object cxPreset: TComboBox
      Left = 56
      Top = 2
      Width = 180
      Height = 23
      Style = csDropDownList
      ItemHeight = 0
      TabOrder = 0
      OnSelect = PresetSelect
    end
    object btnPreset: TButton
      Left = 244
      Top = 0
      Width = 88
      Height = 26
      Action = aPreset
      TabOrder = 1
    end
    object btnSaveAs: TButton
      Left = 339
      Top = 0
      Width = 88
      Height = 26
      Action = aSaveAs
      TabOrder = 2
    end
    object btnDeletePreset: TButton
      Left = 434
      Top = 0
      Width = 88
      Height = 26
      Action = aDeletePreset
      TabOrder = 3
    end
    object btnPreview: TButton
      Left = 539
      Top = 0
      Width = 88
      Height = 26
      Action = aPreview
      Anchors = [akTop, akRight]
      TabOrder = 4
    end
  end
  object Actions: TActionList
    Left = 600
    Top = 8
    object aPreset: TAction
      Caption = '&Load'
      Hint = 'Load the preset'
      OnExecute = aPresetExecute
      OnUpdate = aPresetUpdate
    end
    object aSaveAs: TAction
      Caption = '&Save As...'
      Hint = 'Save the values shown as a preset of your own'
      OnExecute = aSaveAsExecute
    end
    object aDeletePreset: TAction
      Caption = '&Delete'
      Hint = 'Delete the preset (only your own)'
      OnExecute = aDeletePresetExecute
      OnUpdate = aDeletePresetUpdate
    end
    object aImport: TAction
      Caption = '&Import...'
      Hint = 'Read the values of a RAD Studio formatter profile'
      OnExecute = aImportExecute
    end
    object aExport: TAction
      Caption = 'E&xport...'
      Hint = 'Write the values shown as a RAD Studio formatter profile'
      OnExecute = aExportExecute
    end
    object aPreview: TAction
      Caption = 'Pre&view...'
      Hint = 
        'Show the sample formatted with the values of the pages, in a win' +
        'dow of its own'
      OnExecute = aPreviewExecute
    end
  end
end
