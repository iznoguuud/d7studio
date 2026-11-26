{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdFormatter;

{ D7 Studio - the source formatter.

  Pascal (.pas, .dpr, .dpk, .inc) by the options of RAD Studio's Delphi formatter - their names,
  values and the presets Default, Compact and Wide - without its right-margin wrapping; form
  files (.dfm text) in Delphi's own layout (the VCL's streaming: text -> binary -> text).

  Pascal: the source is cut into tokens (SdPasLex, comments kept); one pass over them with a
  stack of frames (sections, declarations, classes, routine headings, routines, blocks,
  statements, brackets) decides for every token whether a line break goes before it, the indent
  of a line it starts, and whether a space goes before it; then the lines are written, aligned,
  and the result is lexed again: it must hold the same tokens (words and numbers compared without
  case, comments without blanks), else nothing is changed. The result is also given as edits of
  the source between lines that start with the same token, so that an editor keeps the markers
  of the lines that only changed inside, and a selection formats only the lines it touches.
  Conditional branches ($IFDEF ... $ELSE ... $ENDIF): each $ELSE starts again from the state at its
  $IF..., and the state after the first branch goes on after $ENDIF. }

{$Q-,R-,B-,H+}

interface

uses
  SysUtils, Classes, StrUtils, SdPasLex;

type
  { the kinds of values, RAD Studio's types (their values in the order of its enumerations) }
  TFmtKind = (vkBool, vkInt, vkUseSpace, vkSpaceAfter, vkSpaceConflict, vkLfCase, vkLfCaseEx,
    vkArrayCase, vkUnindent, vkIndentComments, vkInnerOuter, vkCapitalization);

  TFmtOption = (
    { Indentation }
    foTabSize, foIndentSize, foUseTabs, foContinuationIndent, foDoNotIndentAfterPos,
    foIndentAsm, foIndentCompilerDirectives, foIndentComments, foIndentBlockContents,
    foIndentBrackets, foIndentBeginAndEnd, foIndentFunctionImplementationBody,
    foIndentInnerFunctionImplementation, foIndentAfterSections, foIndentClassDefinitionBody,
    foIndentCaseContents, foIndentCaseLabels, foExtraIndentAfterElseInCase, foDecreaseLabelsIndent,
    { Spaces }
    foAssignSpaces, foMathOperatorSpaces, foUnaryPreOperatorSpaces, foColonSpaces,
    foColonInFormatSpaces, foCommaSpaces, foSemicolonSpaces, foBracketSpaces,
    foSquareBracketSpaces, foCommentStartInlineSpaces, foCommentBracesSpaces,
    foResolveSpaceConflictAs, foSpaceAfterFunction,
    { Line breaks }
    foKeepUserLinebreaks, foTrimSource, foNewLineAfterSemicolon, foNewLineBetweenElseAndIf,
    foRemoveNewLinesInEndElseBegin, foRemoveNewLinesInEndElseIf, foNewLineBeforeThen,
    foNewLineInPropertyDeclaration, foNewLineAfterLabel, foNewLineForEachVarAndConstElement,
    foNewLineAfterUses, foNewLineForEachUseElement, foNewLineForEachLabelElement,
    foNewLineInClassInheritances, foFormatArrayInitialization,
    foNewLineBeforeBeginInControlBlock, foNewLineBeforeSimpleInstructionInControlBlock,
    foNewLineBeforeSimpleInstructionInTryCatchBlock, foNewLineAfterBeginInMethodDefinition,
    foNewLineAfterBeginInControlBlock, foNewLineAfterOtherBegin,
    foNewLineParamTypesInFunction, foNewLineParamValuesInFunction, foNewLineFunctionType,
    { Empty lines }
    foMaxNumOfEmptyLines, foNumOfEmptyLinesAsSeparatorInInterfaceSection,
    foNumOfEmptyLinesAsSeparatorInImplementationSection, foNumOfEmptyLinesBeforeVisibility,
    foNumOfEmptyLinesBeforeSubsection, foNumOfEmptyLinesBeforeTypeKeyword,
    foNumOfEmptyLinesAroundSectionKeyword, foNumOfEmptyLinesAroundCompilerDirectives,
    { Capitalization }
    foKeywordsCapitalization, foCompilerDirectivesCapitalization, foNumbersCapitalization,
    foOtherWordsCapitalization,
    { Align }
    foAlignAssignments, foAlignConst, foAlignTypeDefs, foAlignInitializations, foAlignTypeNames,
    foAlignTypeColon, foAlignParameterTypes, foAlignProperties, foAlignEndOfLineComments,
    foAlignMaxColumn, foAlignMaxUnalignedLines);

  TFmtValues = array[TFmtOption] of Integer;

  TFmtPreset = (fpDefault, fpCompact, fpWide);

  TFmtOptionInfo = record
    Key: string;                           // RAD Studio's name without "DelphiFormatter."
    Kind: TFmtKind;
    Values: array[TFmtPreset] of Integer;  // the presets
    Min, Max: Integer;                     // vkInt
  end;

  { a replacement in the source: Len bytes at Start (0-based) become Text; OutStart is where Text
    starts in the whole formatted text }
  TFmtEdit = record
    Start, Len: Integer;
    Text: string;
    OutStart: Integer;
  end;
  TFmtEdits = array of TFmtEdit;

  TFmtResult = record
    Output: string;                 // the whole text formatted
    Edits: TFmtEdits;               // the changes to make (ascending; only those of the selection)
    SrcPos, OutPos, TokLen: array of Integer;   // where each token was and is (FmtMapPos)
  end;

const
  { USE_SPACE }
  usNone = 0; usBefore = 1; usAfter = 2; usBoth = 3; usAsIs = 4;
  { SPACE_AFTER }
  saNo = 0; saYes = 1; saAsIs = 2;
  { SPACE_CONFLICT }
  scNoSpace = 0; scSpace = 1; scAsIs = 2;
  { LF_CASE }
  lfNo = 0; lfYes = 1; lfAsIs = 2;
  { LF_CASE_EX_DELPHI }
  leNo = 0; leFirstSame = 1; leFirstNext = 2; leAsIs = 3;
  { LF_ARRAY_CASE }
  laNo = 0; laYes = 1; laAsIs = 2; laMainElems = 3;
  { UNINDENT }
  unLeftMargin = 0; unOneIndent = 1; unNone = 2;
  { INDENT_COMMENTS }
  icNo = 0; icYes = 1; icAdditional = 2;
  { INNER_OUTER_SPACE }
  ioNone = 0; ioInner = 1; ioOuter = 2; ioBoth = 3; ioAsIs = 4;
  { CAPITALIZATION }
  caAsIs = 0; caLower = 1; caUpper = 2; caFirstUpper = 3; caFirstOccurrence = 4;

  { RAD Studio's presets (bin\config\Formatter_Default / _Compact / _Wide.config). D7 Studio does
    not wrap at a right margin, so what RAD Studio joins only because its wrapping breaks it again
    is kept as it is: Keep user line breaks, and "As is" for the parameter lists, the function
    result, the inheritance lists and the uses / label lists where RAD Studio says No. }
  FmtOptionInfo: array[TFmtOption] of TFmtOptionInfo = (
    (Key: 'TabSize'; Kind: vkInt; Values: (2, 2, 2); Min: 1; Max: 16),
    (Key: 'IndentSize'; Kind: vkInt; Values: (2, 2, 2); Min: 1; Max: 16),
    (Key: 'UseTabs'; Kind: vkBool; Values: (0, 0, 0)),
    (Key: 'ContinuationIndent'; Kind: vkInt; Values: (2, 2, 2); Min: 0; Max: 16),
    (Key: 'DoNotIndentAfterPos'; Kind: vkInt; Values: (40, 40, 40); Min: 0; Max: 250),
    (Key: 'IndentAsm'; Kind: vkBool; Values: (1, 1, 1)),
    (Key: 'IndentCompilerDirectives'; Kind: vkBool; Values: (0, 0, 0)),
    (Key: 'IndentComments'; Kind: vkIndentComments; Values: (icYes, icYes, icYes)),
    (Key: 'IndentBlockContents'; Kind: vkBool; Values: (1, 1, 1)),
    (Key: 'IndentBrackets'; Kind: vkBool; Values: (0, 0, 0)),
    (Key: 'IndentBeginAndEnd'; Kind: vkBool; Values: (0, 0, 0)),
    (Key: 'IndentFunctionImplementationBody'; Kind: vkBool; Values: (0, 0, 1)),
    (Key: 'IndentInnerFunctionImplementation'; Kind: vkBool; Values: (1, 1, 1)),
    (Key: 'IndentAfterSections'; Kind: vkBool; Values: (0, 0, 0)),
    (Key: 'IndentClassDefinitionBody'; Kind: vkBool; Values: (0, 0, 1)),
    (Key: 'IndentCaseContents'; Kind: vkBool; Values: (1, 1, 1)),
    (Key: 'IndentCaseLabels'; Kind: vkBool; Values: (1, 0, 1)),
    (Key: 'ExtraIndentAfterElseInCase'; Kind: vkBool; Values: (0, 0, 1)),
    (Key: 'DecreaseLabelsIndent'; Kind: vkUnindent; Values: (unOneIndent, unOneIndent, unOneIndent)),

    (Key: 'AssignSpaces'; Kind: vkUseSpace; Values: (usBoth, usBoth, usBoth)),
    (Key: 'MathOperatorSpaces'; Kind: vkUseSpace; Values: (usBoth, usBoth, usBoth)),
    (Key: 'UnaryPreOperatorSpaces'; Kind: vkUseSpace; Values: (usNone, usNone, usBoth)),
    (Key: 'ColonSpaces'; Kind: vkUseSpace; Values: (usAfter, usAfter, usBoth)),
    (Key: 'ColonInFormatSpaces'; Kind: vkUseSpace; Values: (usNone, usNone, usNone)),
    (Key: 'CommaSpaces'; Kind: vkUseSpace; Values: (usAfter, usAfter, usAfter)),
    (Key: 'SemicolonSpaces'; Kind: vkUseSpace; Values: (usAfter, usAfter, usAfter)),
    (Key: 'BracketSpaces'; Kind: vkBool; Values: (0, 0, 1)),
    (Key: 'SquareBracketSpaces'; Kind: vkBool; Values: (0, 0, 1)),
    (Key: 'CommentStartInlineSpaces'; Kind: vkUseSpace; Values: (usBoth, usBoth, usBoth)),
    (Key: 'CommentBracesSpaces'; Kind: vkInnerOuter; Values: (ioBoth, ioBoth, ioBoth)),
    (Key: 'ResolveSpaceConflictAs'; Kind: vkSpaceConflict; Values: (scSpace, scSpace, scSpace)),
    (Key: 'SpaceAfterFunction'; Kind: vkSpaceAfter; Values: (saNo, saNo, saNo)),

    (Key: 'KeepUserLinebreaks'; Kind: vkBool; Values: (1, 1, 1)),
    (Key: 'TrimSource'; Kind: vkBool; Values: (1, 1, 1)),
    (Key: 'NewLineAfterSemicolon'; Kind: vkBool; Values: (1, 1, 1)),
    (Key: 'NewLineBetweenElseAndIf'; Kind: vkBool; Values: (0, 0, 0)),
    (Key: 'RemoveNewLinesInEndElseBegin'; Kind: vkBool; Values: (0, 1, 0)),
    (Key: 'RemoveNewLinesInEndElseIf'; Kind: vkBool; Values: (0, 1, 0)),
    (Key: 'NewLineBeforeThen'; Kind: vkBool; Values: (0, 0, 1)),
    (Key: 'NewLineInPropertyDeclaration'; Kind: vkBool; Values: (0, 0, 1)),
    (Key: 'NewLineAfterLabel'; Kind: vkLfCase; Values: (lfYes, lfNo, lfYes)),
    (Key: 'NewLineForEachVarAndConstElement'; Kind: vkLfCase; Values: (lfYes, lfNo, lfYes)),
    (Key: 'NewLineAfterUses'; Kind: vkLfCase; Values: (lfAsIs, lfAsIs, lfYes)),
    (Key: 'NewLineForEachUseElement'; Kind: vkLfCase; Values: (lfAsIs, lfAsIs, lfYes)),
    (Key: 'NewLineForEachLabelElement'; Kind: vkLfCase; Values: (lfAsIs, lfAsIs, lfYes)),
    (Key: 'NewLineInClassInheritances'; Kind: vkLfCaseEx; Values: (leAsIs, leAsIs, leAsIs)),
    (Key: 'FormatArrayInitialization'; Kind: vkArrayCase; Values: (laYes, laYes, laYes)),
    (Key: 'NewLineBeforeBeginInControlBlock'; Kind: vkLfCase; Values: (lfYes, lfNo, lfYes)),
    (Key: 'NewLineBeforeSimpleInstructionInControlBlock'; Kind: vkLfCase; Values: (lfYes, lfNo, lfYes)),
    (Key: 'NewLineBeforeSimpleInstructionInTryCatchBlock'; Kind: vkLfCase; Values: (lfYes, lfNo, lfYes)),
    (Key: 'NewLineAfterBeginInMethodDefinition'; Kind: vkLfCase; Values: (lfYes, lfYes, lfYes)),
    (Key: 'NewLineAfterBeginInControlBlock'; Kind: vkLfCase; Values: (lfYes, lfYes, lfYes)),
    (Key: 'NewLineAfterOtherBegin'; Kind: vkLfCase; Values: (lfYes, lfYes, lfYes)),
    (Key: 'NewLineParamTypesInFunction'; Kind: vkLfCase; Values: (lfAsIs, lfAsIs, lfYes)),
    (Key: 'NewLineParamValuesInFunction'; Kind: vkLfCase; Values: (lfAsIs, lfAsIs, lfAsIs)),
    (Key: 'NewLineFunctionType'; Kind: vkLfCase; Values: (lfAsIs, lfAsIs, lfAsIs)),

    (Key: 'MaxNumOfEmptyLines'; Kind: vkInt; Values: (1, 1, 1); Min: 0; Max: 99),
    (Key: 'NumOfEmptyLinesAsSeparatorInInterfaceSection'; Kind: vkInt; Values: (1, 1, 1); Min: 0; Max: 10),
    (Key: 'NumOfEmptyLinesAsSeparatorInImplementationSection'; Kind: vkInt; Values: (1, 1, 1); Min: 0; Max: 10),
    (Key: 'NumOfEmptyLinesBeforeVisibility'; Kind: vkInt; Values: (0, 0, 0); Min: 0; Max: 10),
    (Key: 'NumOfEmptyLinesBeforeSubsection'; Kind: vkInt; Values: (1, 1, 1); Min: 0; Max: 10),
    (Key: 'NumOfEmptyLinesBeforeTypeKeyword'; Kind: vkInt; Values: (1, 0, 1); Min: 0; Max: 10),
    (Key: 'NumOfEmptyLinesAroundSectionKeyword'; Kind: vkInt; Values: (1, 1, 1); Min: 0; Max: 10),
    (Key: 'NumOfEmptyLinesAroundCompilerDirectives'; Kind: vkInt; Values: (0, 0, 0); Min: 0; Max: 10),

    (Key: 'KeywordsCapitalization'; Kind: vkCapitalization; Values: (caAsIs, caAsIs, caAsIs)),
    (Key: 'CompilerDirectivesCapitalization'; Kind: vkCapitalization; Values: (caUpper, caUpper, caUpper)),
    (Key: 'NumbersCapitalization'; Kind: vkCapitalization; Values: (caUpper, caUpper, caUpper)),
    (Key: 'OtherWordsCapitalization'; Kind: vkCapitalization; Values: (caFirstOccurrence, caFirstOccurrence, caFirstOccurrence)),

    (Key: 'AlignAssignments'; Kind: vkBool; Values: (0, 0, 0)),
    (Key: 'AlignConst'; Kind: vkBool; Values: (0, 0, 0)),
    (Key: 'AlignTypeDefs'; Kind: vkBool; Values: (0, 0, 0)),
    (Key: 'AlignInitializations'; Kind: vkBool; Values: (0, 0, 0)),
    (Key: 'AlignTypeNames'; Kind: vkBool; Values: (0, 0, 0)),
    (Key: 'AlignTypeColon'; Kind: vkBool; Values: (0, 0, 1)),
    (Key: 'AlignParameterTypes'; Kind: vkBool; Values: (0, 0, 1)),
    (Key: 'AlignProperties'; Kind: vkBool; Values: (0, 0, 0)),
    (Key: 'AlignEndOfLineComments'; Kind: vkBool; Values: (0, 0, 0)),
    (Key: 'AlignMaxColumn'; Kind: vkInt; Values: (60, 60, 60); Min: 0; Max: 250),
    (Key: 'AlignMaxUnalignedLines'; Kind: vkInt; Values: (0, 0, 0); Min: 0; Max: 10));

type
  { a preset that comes with D7 Studio: a base (another one, or RAD Studio's of Preset) and the
    options it changes, "Key=Value;..." with RAD Studio's names and values }
  TFmtBuiltinPreset = record
    Name: string;
    Base: Integer;                 // the index of the preset it starts from, -1: RAD Studio's Preset
    Preset: TFmtPreset;
    Changes: string;
  end;

const
  { RAD Studio's three presets; DelForExp's two (Delfor1.pas: TPascalParser.SetDefault, SetBorland -
    what it leaves untouched is "As is" here); the Object Pascal Style Guide (Delphi's own standard:
    RAD Studio's Default with lowercase reserved words); JEDI Code Format's defaults (Borland's style,
    the = of constants and the type names aligned, identifiers in their own case); the Free Pascal
    compiler and RTL's (wiki.freepascal.org/Coding_style: lowercase, no blanks in p:=p+i, begin
    indented under its if, the body of a routine indented, two empty lines between routines) }
  FmtBuiltinPresets: array[0..7] of TFmtBuiltinPreset = (
    (Name: 'RAD Studio Default'; Base: -1; Preset: fpDefault; Changes: ''),
    (Name: 'RAD Studio Compact'; Base: -1; Preset: fpCompact; Changes: ''),
    (Name: 'RAD Studio Wide'; Base: -1; Preset: fpWide; Changes: ''),
    (Name: 'DelForExp Default'; Base: -1; Preset: fpDefault; Changes:
      'IndentComments=No;IndentCompilerDirectives=False;IndentBeginAndEnd=False;ExtraIndentAfterElseInCase=False;' +
      'KeywordsCapitalization=lowercase;CompilerDirectivesCapitalization=UPPERCASE;NumbersCapitalization=UPPERCASE;' +
      'OtherWordsCapitalization=AsIs;AssignSpaces=BeforeAndAfter;MathOperatorSpaces=BeforeAndAfter;' +
      'ColonSpaces=AfterOnly;CommaSpaces=AfterOnly;SemicolonSpaces=AfterOnly;BracketSpaces=False;' +
      'SquareBracketSpaces=False;CommentStartInlineSpaces=AsIs;CommentBracesSpaces=AsIs;' +
      'NewLineBeforeSimpleInstructionInControlBlock=AsIs;NewLineBeforeSimpleInstructionInTryCatchBlock=AsIs;' +
      'NewLineBetweenElseAndIf=False;NewLineForEachUseElement=AsIs;NewLineAfterUses=AsIs;' +
      'NewLineForEachVarAndConstElement=AsIs;NewLineBeforeBeginInControlBlock=AsIs;' +
      'NewLineAfterBeginInControlBlock=AsIs;NewLineAfterBeginInMethodDefinition=AsIs;NewLineAfterOtherBegin=AsIs;' +
      'NewLineAfterSemicolon=False;NewLineAfterLabel=AsIs;FormatArrayInitialization=AsIs;' +
      'MaxNumOfEmptyLines=99;NumOfEmptyLinesAsSeparatorInImplementationSection=1;' +
      'NumOfEmptyLinesAsSeparatorInInterfaceSection=0;NumOfEmptyLinesBeforeSubsection=0;' +
      'NumOfEmptyLinesBeforeTypeKeyword=0;NumOfEmptyLinesAroundSectionKeyword=0'),
    (Name: 'DelForExp Borland'; Base: 3; Preset: fpDefault; Changes:
      'IndentComments=Yes;NewLineBeforeSimpleInstructionInControlBlock=Yes;NewLineForEachVarAndConstElement=Yes;' +
      'NewLineBeforeBeginInControlBlock=Yes;NewLineAfterBeginInControlBlock=Yes;' +
      'NewLineAfterBeginInMethodDefinition=Yes;NewLineAfterOtherBegin=Yes;NewLineAfterSemicolon=True;' +
      'MaxNumOfEmptyLines=1'),
    (Name: 'Borland Style Guide'; Base: -1; Preset: fpDefault; Changes: 'KeywordsCapitalization=lowercase'),
    (Name: 'JEDI Code Format'; Base: 5; Preset: fpDefault; Changes:
      'AlignConst=True;AlignTypeNames=True;AlignMaxColumn=60;OtherWordsCapitalization=AsIs'),
    (Name: 'Free Pascal (compiler, RTL)'; Base: -1; Preset: fpDefault; Changes:
      'KeywordsCapitalization=lowercase;OtherWordsCapitalization=AsIs;AssignSpaces=None;MathOperatorSpaces=None;' +
      'IndentBeginAndEnd=True;IndentFunctionImplementationBody=True;IndentInnerFunctionImplementation=True;' +
      'IndentClassDefinitionBody=False;NewLineBetweenElseAndIf=False;CommentBracesSpaces=InnerAndOuter;' +
      'NumOfEmptyLinesAsSeparatorInImplementationSection=2;MaxNumOfEmptyLines=2'));

procedure FmtPresetValues(Preset: TFmtPreset; var O: TFmtValues);
{ a built-in preset's values (FmtBuiltinPresets) }
procedure FmtBuiltinValues(Index: Integer; var O: TFmtValues);
{ "Key=Value;..." (RAD Studio's names and values) into O; False: an unknown key or value }
function FmtApplyChanges(var O: TFmtValues; const Changes: string): Boolean;
{ the option of a key (RAD Studio's name, with or without "DelphiFormatter."); False: none }
function FmtOptionByKey(const Key: string; var Opt: TFmtOption): Boolean;
{ RAD Studio's name of a value (a number for vkInt) and back (False: not a value of F) }
function FmtValueToText(F: TFmtOption; V: Integer): string;
function FmtValueFromText(F: TFmtOption; const S: string; var V: Integer): Boolean;
{ RAD Studio's formatter profile (Formatter.config, XML): the Delphi options of Text into O (the
  others stay) - Count: how many were read; and O as a whole profile (with RAD Studio's defaults
  for what D7 Studio does not offer: right margin, line break characters, generics, anonymous
  methods) }
procedure FmtFromRadConfig(const Text: string; var O: TFmtValues; var Count: Integer);
function FmtToRadConfig(const O: TFmtValues): string;

{ Formats Source (a Pascal file). SelStart..SelEnd (0-based offsets; SelStart < 0: the whole
  text) - the edits are those of the lines touched. False: Error says why (nothing to change is
  True with no edits). }
function FormatPascal(const Source: string; const O: TFmtValues; SelStart, SelEnd: Integer;
  var R: TFmtResult; var Error: string): Boolean;
{ a form file's text in Delphi's layout (False: it cannot be read - Error) }
function FormatDfm(const Source: string; var R: TFmtResult; var Error: string): Boolean;
{ a position of the source in the text after R.Edits }
function FmtMapPos(const R: TFmtResult; Pos: Integer): Integer;
{ the same tokens (words without case, comments without blanks); False: Line (1-based) of the
  first difference in A }
function FmtSameTokens(const A, B: string; var Line: Integer): Boolean;

implementation

const
  bkDefault = 0; bkYes = 1; bkNo = 2; bkAsIs = 3;

  tfUnary = $0001; tfFmtColon = $0002; tfDirKw = $0004; tfNoCase = $0008; tfFuncParen = $0010;
  tfPrefixCaret = $0020; tfKeepCol = $0040; tfAsm = $0080; tfLabelColon = $0100;
  tfStmtStart = $0200; tfItemStart = $0400;

  akNone = 0; akTypeName = 1; akParamType = 2; akInit = 3; akConst = 4; akTypeDef = 5;
  akAssign = 6; akProperty = 7; akComment = 8;

  { frCtrl kinds and states }
  ckIf = 1; ckLoop = 2; ckLabel = 3; ckOn = 4; ckStmtLabel = 5;
  csCond = 0; csThen = 1; csElse = 2;
  { frCase states }
  cqSelector = 0; cqLabels = 1; cqElse = 2;
  { frTry states }
  tsTry = 0; tsExcept = 1; tsFinally = 2;
  { frClass states and flags }
  clHead = 0; clBody = 1;
  { frHeader states and flags }
  hsKeyword = 0; hsName = 1; hsResult = 2; hsDirectives = 3; hsDirArgs = 4;
  hfNoBody = 1;
  { frBlock / frAsm flags }
  fbMethod = 1; fbMain = 2; fbPseudo = 4;
  { frParen kinds }
  pkExpr = 0; pkCall = 1; pkParams = 2; pkArray = 3; pkHeritage = 4; pkIndex = 5; pkFormat = 6;
  { declaration item states }
  isStart = 0; isColon = 1; isEquals = 2; isTail = 3;
  { class member states; the flag of a record's variant part }
  ikField = 0; ikFieldTyped = 1; ikProperty = 2; ikCaseHead = 3; ikTail = 4; ikGuid = 5;
  cfVariant = 1;
  { statement state bits }
  sbAssign = 1; sbIdent = 2; sbParen = 4;
  { frDecl kinds that are not keywords }
  dsRequires = 1000; dsContains = 1001;

  WordOps = [kwAnd, kwOr, kwXor, kwDiv, kwMod, kwShl, kwShr, kwIn, kwIs, kwAs];
  TypeTailDirectives = [dvCdecl, dvStdcall, dvSafecall, dvPascal, dvRegister, dvVarargs,
    dvDeprecated, dvPlatform, dvFar, dvNear, dvExport];
  PropSpecifiers = [dvRead, dvWrite, dvStored, dvDefault, dvNodefault, dvImplements, dvIndex,
    dvReadonly, dvWriteonly, dvDispid];

type
  PFmtTok = ^TFmtTok;
  TFmtTok = record
    Kind: TTokenKind;
    Kw: TKeyword;
    Dv: TDirective;
    Sym: TSymbolId;
    S, L: Integer;           // 0-based offset and length in the source
    NL: Integer;             // line breaks between the token before and this one
    Sp: Boolean;             // blanks before it on its line
    SrcCol: Integer;         // its column in the source (tabs expanded)
    IsDir, IsLineCmt, InAsm: Boolean;
    Text: string;            // what is written
    Brk: Integer;            // bk*: a line break before it
    Ind: Integer;            // the column of a line it starts
    Blank: Integer;          // at least that many empty lines before a line it starts
    Flags: Integer;
    Align: Integer;          // ak*
  end;

  TFrameKind = (frFile, frSection, frDecl, frClass, frHeader, frRoutine, frBlock, frTry, frCase,
    frRepeat, frCtrl, frParen, frAsm);

  PFrame = ^TFrame;
  TFrame = record
    Kind: TFrameKind;
    Sub: Integer;            // the keyword (Ord), control kind or bracket kind that made it
    Col: Integer;            // the column of its first line
    Inner: Integer;          // the column of its contents
    BeginCol: Integer;       // frCtrl: the column of a begin as its statement
    State: Integer;
    InItem: Boolean;         // a declaration / statement has begun (else the next token starts one)
    Item: Integer;           // ... its column
    ItemState: Integer;
    NextBrk: Integer;        // the break before the next item / statement
    Done: Boolean;           // frCtrl: its statement is complete (an else may follow an if)
    Flag: Integer;
    Tok: Integer;            // the token that opened it
    Count: Integer;
    CloseCol: Integer;       // frParen: the column of the closing bracket on a line of its own
    FirstBrk, ElemBrk, CloseBrk, InnerBrk: Integer;   // frParen: breaks inside
    LastSep: Integer;        // frParen: the last separator of its level
  end;

  TFrames = array of TFrame;

  TCondEntry = record
    Start, FirstEnd: TFrames;
    StartTop, FirstEndTop: Integer;
    HasElse: Boolean;
  end;

  TPasFormatter = class
  private
    FSrc: string;
    O: TFmtValues;
    FIS, FCI: Integer;
    FEol: string;
    FT: array of TFmtTok;
    FCount: Integer;
    FMatch: array of Integer;
    FFr: TFrames;
    FTop: Integer;
    FCond: array of TCondEntry;
    FCondTop: Integer;
    FAltStart: TFrames;            // the start of the conditional block that ended last (no else)
    FAltStartTop, FAltEnd: Integer;
    FPending: array of Integer;
    FPendCount: Integer;
    FPrev: Integer;                // the previous significant token
    FFileEnd: Boolean;             // the final "end" was read: a "." ends the source
    FDone: Boolean;
    FLast: Integer;                // the last token written (the rest of the source is kept)
    FBlankAfter: Integer;          // empty lines before the next line
    FSepNext: Integer;             // ... before the next declaration (separators)
    FCommentInd: Integer;          // the indent of comment lines before the current token
    FNoCase: Boolean;              // in the heading of the unit / program
    FElseJoin: Boolean;            // the next statement joins its else
    FAsmBase: Integer;             // the source column of the first line of the asm block
    { output }
    FLines: array of string;
    FLineCount: Integer;
    FTail: string;                 // the text after the last line
    FLineFirst: array of Integer;  // the first token of a line (-1: none)
    FTokLine, FTokCol: array of Integer;
    function Top: PFrame;
    procedure Push(Kind: TFrameKind; Sub, Col, Inner, Tok: Integer);
    procedure Pop;
    function IsSym(I: Integer; S: TSymbolId): Boolean;
    function IsKw(I: Integer; K: TKeyword): Boolean;
    function IsDv(I: Integer; D: TDirective): Boolean;
    function NextSig(I: Integer): Integer;

    function ContCol: Integer;
    function LfBrk(V: Integer): Integer;
    function CountSeps(I: Integer; S: TSymbolId): Integer;
    function AsmBase(I: Integer): Integer;
    procedure Tokenize;
    procedure MatchBrackets;
    { the structure pass }
    procedure Analyze;
    procedure CommentTok(I: Integer);
    procedure Directive(I: Integer);
    procedure ResolvePending(I: Integer);
    procedure SigTok(I: Integer);
    procedure Route(I: Integer);
    procedure PopDone(I: Integer);
    procedure AsmTok(I: Integer);
    procedure SectionTok(I: Integer);
    procedure TakeSeparator(T: PFmtTok; Blank: Integer);
    procedure DeclTok(I: Integer);
    procedure StartDeclSection(I: Integer);
    procedure DeclItemTok(I: Integer);
    procedure PushClass(I, Col: Integer);
    procedure ListBreaks(V, AsIs: Integer);
    procedure StartHeader(I: Integer);
    procedure HeaderTok(I: Integer);
    procedure EndHeader(I: Integer);
    procedure StartBody(I: Integer);
    procedure FileEndTok(I: Integer);
    procedure ClassTok(I: Integer);
    procedure ClassEnd(I: Integer);
    function StartsBody(I: Integer): Boolean;
    procedure StmtTok(I: Integer);
    procedure StatementStart(I: Integer);
    procedure PushCtrl(Kind, Col, I: Integer);
    procedure EndStatement;
    procedure CloseEnd(I: Integer);
    procedure CloseUntil(I: Integer);
    function CloseTryPart(I: Integer): Boolean;
    function HandleElse(I: Integer): Boolean;
    procedure CaseLabelTok(I: Integer);
    procedure Expr(I: Integer);
    procedure OpenParen(I, Kind: Integer);
    procedure ParenTok(I: Integer);
    function IsUnaryPos(P: Integer): Boolean;
    function IsOperandEnd(P: Integer): Boolean;
    { capitalization and comments }
    procedure ApplyCase;
    { output }
    function Breaks(I: Integer): Boolean;
    function SpaceBefore(I: Integer): string;
    function IndentStr(Col: Integer): string;
    procedure AddLine(const S: string; First: Integer);
    procedure Emit;
    function VisCol(L, Pos: Integer): Integer;
    procedure AlignKind(K: Integer);
    procedure AlignAll;
    procedure BuildResult(SelStart, SelEnd: Integer; var R: TFmtResult);
  public
    constructor Create(const Source: string; const AO: TFmtValues);
    function Run(SelStart, SelEnd: Integer; var R: TFmtResult; var Error: string): Boolean;
  end;

const
  { the frames whose items are statements (an assignment there is aligned, a call is one) }
  StmtFrames = [frBlock, frTry, frRepeat, frCase, frCtrl, frSection];

function IfInt(B: Boolean; A, C: Integer): Integer;
begin
  if B then Result := A else Result := C;
end;

function MaxInt2(A, B: Integer): Integer;
begin
  if A > B then Result := A else Result := B;
end;

procedure FmtPresetValues(Preset: TFmtPreset; var O: TFmtValues);
var
  F: TFmtOption;
begin
  for F := Low(F) to High(F) do O[F] := FmtOptionInfo[F].Values[Preset];
end;

procedure FmtBuiltinValues(Index: Integer; var O: TFmtValues);
begin
  if (Index < Low(FmtBuiltinPresets)) or (Index > High(FmtBuiltinPresets)) then Index := 0;
  with FmtBuiltinPresets[Index] do
  begin
    if Base >= 0 then FmtBuiltinValues(Base, O) else FmtPresetValues(Preset, O);
    FmtApplyChanges(O, Changes);
  end;
end;

function FmtApplyChanges(var O: TFmtValues; const Changes: string): Boolean;
var
  L: TStringList;
  I, V: Integer;
  F: TFmtOption;
begin
  Result := True;
  L := TStringList.Create;
  try
    L.Text := StringReplace(Changes, ';', #13#10, [rfReplaceAll]);
    for I := 0 to L.Count - 1 do
      if Trim(L[I]) <> '' then
        if FmtOptionByKey(Trim(L.Names[I]), F) and FmtValueFromText(F, L.ValueFromIndex[I], V) then O[F] := V
        else Result := False;
  finally
    L.Free;
  end;
end;

{ RAD Studio's names of the values (Embarcadero.Modeling.OpenAPI3: Borland.Together.OpenAPI3.Config) }
function ValueNames(Kind: TFmtKind): string;
begin
  case Kind of
    vkBool: Result := 'False,True';
    vkUseSpace: Result := 'None,BeforeOnly,AfterOnly,BeforeAndAfter,AsIs';
    vkSpaceAfter: Result := 'No,Yes,AsIs';
    vkSpaceConflict: Result := 'NoSpace,Space,AsIs';
    vkLfCase: Result := 'No,Yes,AsIs';
    vkLfCaseEx: Result := 'No,YesFirstOnSame,YesFirstOnNext,AsIs';
    vkArrayCase: Result := 'No,Yes,AsIs,OnlyMainElems';
    vkUnindent: Result := 'ToLeftMargin,ToOneIndent,None';
    vkIndentComments: Result := 'No,Yes,WithAdditionalIndent';
    vkInnerOuter: Result := 'None,InnerOnly,OuterOnly,InnerAndOuter,AsIs';
    vkCapitalization: Result := 'AsIs,lowercase,UPPERCASE,FirstUpperCase,AsFirstOccurence';
  else
    Result := '';
  end;
end;

{ ... and the type names of RAD Studio's profiles }
function TypeName(Kind: TFmtKind): string;
begin
  case Kind of
    vkBool: Result := 'System.Boolean';
    vkInt: Result := 'System.Int32';
    vkUseSpace: Result := 'USE_SPACE';
    vkSpaceAfter: Result := 'SPACE_AFTER';
    vkSpaceConflict: Result := 'SPACE_CONFLICT';
    vkLfCase: Result := 'LF_CASE';
    vkLfCaseEx: Result := 'LF_CASE_EX_DELPHI';
    vkArrayCase: Result := 'LF_ARRAY_CASE';
    vkUnindent: Result := 'UNINDENT';
    vkIndentComments: Result := 'INDENT_COMMENTS';
    vkInnerOuter: Result := 'INNER_OUTER_SPACE';
  else
    Result := 'CAPITALIZATION';
  end;
  if Kind > vkInt then Result := 'Borland.Together.OpenAPI3.Config.' + Result;
end;

function FmtValueToText(F: TFmtOption; V: Integer): string;
var
  L: TStringList;
begin
  if FmtOptionInfo[F].Kind = vkInt then
  begin
    Result := IntToStr(V);
    Exit;
  end;
  L := TStringList.Create;
  try
    L.CommaText := ValueNames(FmtOptionInfo[F].Kind);
    if (V >= 0) and (V < L.Count) then Result := L[V] else Result := IntToStr(V);
  finally
    L.Free;
  end;
end;

function FmtValueFromText(F: TFmtOption; const S: string; var V: Integer): Boolean;
var
  L: TStringList;
  I, N: Integer;
begin
  Result := False;
  if FmtOptionInfo[F].Kind = vkInt then
  begin
    N := StrToIntDef(Trim(S), MaxInt);
    Result := N <> MaxInt;
    if not Result then Exit;
    if N < FmtOptionInfo[F].Min then N := FmtOptionInfo[F].Min;
    if N > FmtOptionInfo[F].Max then N := FmtOptionInfo[F].Max;
    V := N;
    Exit;
  end;
  L := TStringList.Create;
  try
    L.CommaText := ValueNames(FmtOptionInfo[F].Kind);
    for I := 0 to L.Count - 1 do
      if SameText(L[I], Trim(S)) then
      begin
        V := I;
        Result := True;
        Exit;
      end;
  finally
    L.Free;
  end;
end;

{ the value of attribute Name in an XML tag (Tag: the text between < and >) }
function TagAttr(const Tag, Name: string): string;
var
  P, Q: Integer;
begin
  Result := '';
  P := Pos(' ' + Name + '="', Tag);
  if P = 0 then Exit;
  Inc(P, Length(Name) + 3);
  Q := P;
  while (Q <= Length(Tag)) and (Tag[Q] <> '"') do Inc(Q);
  Result := Copy(Tag, P, Q - P);
end;

procedure FmtFromRadConfig(const Text: string; var O: TFmtValues; var Count: Integer);
var
  P, Q, V: Integer;
  Tag, Name: string;
  F: TFmtOption;
begin
  Count := 0;
  P := 1;
  repeat
    P := PosEx('<Option', Text, P);
    if P = 0 then Break;
    Q := P;
    while (Q <= Length(Text)) and (Text[Q] <> '>') do Inc(Q);
    Tag := StringReplace(StringReplace(Copy(Text, P, Q - P), #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
    P := Q + 1;
    Name := TagAttr(Tag, 'Name');
    if SameText(Copy(Name, 1, 16), 'DelphiFormatter.') and FmtOptionByKey(Name, F) and
      FmtValueFromText(F, TagAttr(Tag, 'Value'), V) then
    begin
      O[F] := V;
      Inc(Count);
    end;
  until False;
end;

function FmtToRadConfig(const O: TFmtValues): string;
var
  F: TFmtOption;
  Cat: string;

  procedure Line(const Name, Typ, Category, Value: string);
  begin
    Result := Result + '  <Option Name="DelphiFormatter.' + Name + '" Type="' + Typ + '" Category="' +
      Category + '" Value="' + Value + '" Levels="Formatter" />' + #13#10;
  end;

begin
  Result := '<?xml version="1.0"?>' + #13#10 +
    '<TgConfig Version="3" SubLevelDisabled="False">' + #13#10 +
    '  <Assemblies>' + #13#10 +
    '    <Assembly Name="Embarcadero.Modeling.OpenAPI3" Culture="neutral" />' + #13#10 +
    '  </Assemblies>' + #13#10;
  for F := Low(F) to High(F) do
  begin
    if F <= foUseTabs then Cat := 'DelphiEditor'
    else if F <= foDecreaseLabelsIndent then Cat := 'DelphiIndentation'
    else if F <= foSpaceAfterFunction then Cat := 'DelphiSpaces'
    else if F <= foNumOfEmptyLinesAroundCompilerDirectives then Cat := 'DelphiLinebreaks'
    else if F <= foOtherWordsCapitalization then Cat := 'DelphiCapitalization'
    else Cat := 'DelphiAlign';
    Line(FmtOptionInfo[F].Key, TypeName(FmtOptionInfo[F].Kind), Cat, FmtValueToText(F, O[F]));
  end;
  { RAD Studio's options that D7 Studio does not offer, at RAD Studio's defaults }
  Line('RightMargin', 'System.Int32', 'DelphiLinebreaks', '80');
  Line('LineBreak', 'Borland.Together.OpenAPI3.Config.LF_TYPE', 'DelphiLinebreaks', 'SystemDefault');
  Line('TemplateBracketSpaces', 'System.Boolean', 'DelphiSpaces', 'False');
  Line('NewLineFunctionAnonym1', 'System.Boolean', 'DelphiLinebreaks', 'False');
  Line('NewLineFunctionAnonym2', 'System.Boolean', 'DelphiLinebreaks', 'True');
  Result := Result + '</TgConfig>' + #13#10;
end;

function FmtOptionByKey(const Key: string; var Opt: TFmtOption): Boolean;
var
  F: TFmtOption;
  K: string;
begin
  K := Key;
  if SameText(Copy(K, 1, 16), 'DelphiFormatter.') then Delete(K, 1, 16);
  for F := Low(F) to High(F) do
    if SameText(FmtOptionInfo[F].Key, K) then
    begin
      Opt := F;
      Result := True;
      Exit;
    end;
  Result := False;
end;

{ ------------------------------------------------------------------------------ the lexer side }

{ the tokens of a text as the formatter sees them (SdPasLex's TRawToks): comments kept,
  directives not processed, an asm block lexed as assembler }

function NoBlanks(const S: string): string;
var
  I, N: Integer;
begin
  SetLength(Result, Length(S));
  N := 0;
  for I := 1 to Length(S) do
    if not (S[I] in [' ', #9, #10, #13]) then
    begin
      Inc(N);
      Result[N] := S[I];
    end;
  SetLength(Result, N);
end;

{ the texts of two tokens are the same (IgnoreCase: as SameText) }
function SameTokText(const A, B: TToken; IgnoreCase: Boolean): Boolean;
var
  I: Integer;
begin
  Result := False;
  if A.PLen <> B.PLen then Exit;
  if IgnoreCase then
  begin
    for I := 0 to A.PLen - 1 do
      if UpTab[A.Ptr[I]] <> UpTab[B.Ptr[I]] then Exit;
  end
  else
    for I := 0 to A.PLen - 1 do
      if A.Ptr[I] <> B.Ptr[I] then Exit;
  Result := True;
end;

function FmtSameTokens(const A, B: string; var Line: Integer): Boolean;
var
  LA, LB: TRawToks;
  I: Integer;
  Same: Boolean;
begin
  LA := TRawToks.Create(A);
  LB := TRawToks.Create(B);
  try
    Result := True;
    Line := 0;
    for I := 0 to LA.N - 1 do
    begin
      if I >= LB.N then
      begin
        Line := LA.T[I].Line;
        Result := False;
        Exit;
      end;
      Same := LA.T[I].Kind = LB.T[I].Kind;
      if Same then
        case LA.T[I].Kind of
          tkString: Same := SameTokText(LA.T[I], LB.T[I], False);
          tkComment: Same := SameText(NoBlanks(LA.Txt(I)), NoBlanks(LB.Txt(I)));
        else
          Same := SameTokText(LA.T[I], LB.T[I], True);
        end;
      if not Same then
      begin
        Line := LA.T[I].Line;
        Result := False;
        Exit;
      end;
    end;
    if LB.N > LA.N then
    begin
      if LA.N > 0 then Line := LA.T[LA.N - 1].Line else Line := 1;
      Result := False;
    end;
  finally
    LB.Free;
    LA.Free;
  end;
end;

{ ------------------------------------------------------------------------------ TPasFormatter }

constructor TPasFormatter.Create(const Source: string; const AO: TFmtValues);
begin
  inherited Create;
  FSrc := Source;
  O := AO;
  FIS := O[foIndentSize];
  if FIS < 1 then FIS := 1;
  FCI := O[foContinuationIndent];
  if O[foTabSize] < 1 then O[foTabSize] := 1;
  FEol := DetectEOL(FSrc);
end;

function TPasFormatter.Top: PFrame;
begin
  Result := @FFr[FTop];
end;

procedure TPasFormatter.Push(Kind: TFrameKind; Sub, Col, Inner, Tok: Integer);
var
  F: PFrame;
begin
  Inc(FTop);
  if FTop >= Length(FFr) then SetLength(FFr, FTop * 2 + 8);
  F := @FFr[FTop];
  F.Kind := Kind;
  F.Sub := Sub;
  F.Col := Col;
  F.Inner := Inner;
  F.BeginCol := Col;
  F.State := 0;
  F.InItem := False;
  F.Item := Inner;
  F.ItemState := 0;
  F.NextBrk := bkYes;
  F.Done := False;
  F.Flag := 0;
  F.Tok := Tok;
  F.Count := 0;
  F.CloseCol := Col;
  F.FirstBrk := bkDefault;
  F.ElemBrk := bkDefault;
  F.CloseBrk := bkDefault;
  F.InnerBrk := bkDefault;
  F.LastSep := -1;
end;

procedure TPasFormatter.Pop;
begin
  if FTop > 0 then Dec(FTop);
end;

function TPasFormatter.IsSym(I: Integer; S: TSymbolId): Boolean;
begin
  Result := (I >= 0) and (I < FCount) and (FT[I].Kind = tkSymbol) and (FT[I].Sym = S);
end;

function TPasFormatter.IsKw(I: Integer; K: TKeyword): Boolean;
begin
  Result := (I >= 0) and (I < FCount) and (FT[I].Kind = tkKeyword) and (FT[I].Kw = K);
end;

function TPasFormatter.IsDv(I: Integer; D: TDirective): Boolean;
begin
  Result := (I >= 0) and (I < FCount) and (FT[I].Kind = tkIdent) and (FT[I].Dv = D);
end;

function TPasFormatter.NextSig(I: Integer): Integer;
begin
  Result := I + 1;
  while (Result < FCount) and (FT[Result].Kind = tkComment) do Inc(Result);
  if Result >= FCount then Result := -1;
end;


{ the column of a token that continues the current item / statement }
function TPasFormatter.ContCol: Integer;
var
  F: PFrame;
begin
  F := Top;
  if F.Kind = frParen then Result := F.Inner
  else if F.InItem then Result := F.Item + FCI
  else Result := F.Inner;
end;

function TPasFormatter.LfBrk(V: Integer): Integer;
begin
  case V of
    lfNo: Result := bkNo;
    lfYes: Result := bkYes;
  else
    Result := bkAsIs;
  end;
end;

{ the separators S directly inside the bracket at I }
function TPasFormatter.CountSeps(I: Integer; S: TSymbolId): Integer;
var
  J, D, M: Integer;
begin
  Result := 0;
  M := FMatch[I];
  if M < 0 then Exit;
  D := 0;
  for J := I + 1 to M - 1 do
    if FT[J].Kind = tkSymbol then
      case FT[J].Sym of
        syLParen, syLBracket: Inc(D);
        syRParen, syRBracket: Dec(D);
      else
        if (D = 0) and (FT[J].Sym = S) then Inc(Result);
      end;
end;

{ the leftmost source column of the lines of the asm block after token I (they move together) }
function TPasFormatter.AsmBase(I: Integer): Integer;
var
  J: Integer;
begin
  Result := -1;
  J := I + 1;
  while (J < FCount) and FT[J].InAsm do
  begin
    if (FT[J].NL > 0) and ((Result < 0) or (FT[J].SrcCol < Result)) then Result := FT[J].SrcCol;
    Inc(J);
  end;
end;

{ the tokens with what lies before each: line breaks, blanks, the source column (tabs expanded;
  counted on from token to token) }
procedure TPasFormatter.Tokenize;
var
  RT: TRawToks;
  K, N, P, Last, NL, Col, Tab: Integer;
  T: PFmtTok;
  Tk: PToken;
  Sp: Boolean;

  procedure Advance(C: Char);
  begin
    case C of
      #10, #13: Col := 0;
      #9: Col := (Col div Tab + 1) * Tab;
    else
      Inc(Col);
    end;
  end;

begin
  RT := TRawToks.Create(FSrc);
  try
    Tab := O[foTabSize];
    SetLength(FT, RT.N + 1);         // a zeroed record after the last token, as before
    N := 0;
    Last := 0;
    Col := 0;
    for K := 0 to RT.N - 1 do
    begin
      Tk := @RT.T[K];
      T := @FT[N];
      T.Kind := Tk.Kind;
      T.Kw := Tk.Keyword;
      T.Dv := Tk.Directive;
      T.Sym := Tk.Symbol;
      T.S := Tk.Start;
      T.L := Tk.Len;
      NL := 0;
      Sp := False;
      P := Last + 1;
      while P <= T.S do
      begin
        case FSrc[P] of
          #13:
            begin
              Inc(NL);
              if (P < T.S) and (FSrc[P + 1] = #10) then Inc(P);
              Sp := False;
            end;
          #10:
            begin
              Inc(NL);
              Sp := False;
            end;
        else
          Sp := True;
        end;
        Advance(FSrc[P]);
        Inc(P);
      end;
      T.NL := NL;
      T.Sp := Sp;
      T.SrcCol := Col;
      { the column after it: a comment or a string can hold tabs, a comment line breaks }
      if T.Kind in [tkComment, tkString] then
        for P := T.S + 1 to T.S + T.L do Advance(FSrc[P])
      else
        Inc(Col, T.L);
      T.Text := Copy(FSrc, T.S + 1, T.L);
      T.IsDir := False;
      T.IsLineCmt := False;
      if T.Kind = tkComment then
      begin
        T.IsLineCmt := (T.L >= 2) and (FSrc[T.S + 1] = '/');
        T.IsDir := ((T.L >= 2) and (FSrc[T.S + 1] = '{') and (FSrc[T.S + 2] = '$')) or
          ((T.L >= 3) and (FSrc[T.S + 1] = '(') and (FSrc[T.S + 3] = '$'));
      end;
      T.InAsm := Tk.InAsm;
      T.Brk := bkDefault;
      T.Ind := 0;
      T.Blank := 0;
      T.Flags := 0;
      T.Align := akNone;
      Last := T.S + T.L;
      Inc(N);
    end;
    FCount := N;
  finally
    RT.Free;
  end;
end;

procedure TPasFormatter.MatchBrackets;
var
  St: array of Integer;
  N, I: Integer;
begin
  SetLength(FMatch, FCount);
  SetLength(St, FCount + 1);
  N := 0;
  for I := 0 to FCount - 1 do
  begin
    FMatch[I] := -1;
    if FT[I].Kind <> tkSymbol then Continue;
    case FT[I].Sym of
      syLParen, syLBracket:
        begin
          St[N] := I;
          Inc(N);
        end;
      syRParen, syRBracket:
        if (N > 0) and ((FT[St[N - 1]].Sym = syLParen) = (FT[I].Sym = syRParen)) then
        begin
          Dec(N);
          FMatch[St[N]] := I;
          FMatch[I] := St[N];
        end;
    end;
  end;
end;

{ ------------------------------------------------------------------------------ structure }

procedure TPasFormatter.Analyze;
var
  I: Integer;
begin
  FTop := -1;
  SetLength(FFr, 16);
  Push(frFile, 0, 0, 0, -1);
  FPrev := -1;
  FLast := FCount - 1;
  FCondTop := -1;
  FAltEnd := -1;
  for I := 0 to FCount - 1 do
  begin
    if FDone then
    begin
      FLast := I - 1;
      Break;
    end;
    if FT[I].Kind = tkComment then CommentTok(I)
    else
    begin
      SigTok(I);
      FPrev := I;
    end;
  end;
  { comments at the end }
  FCommentInd := 0;
  for I := 0 to FPendCount - 1 do FT[FPending[I]].Ind := 0;
  FPendCount := 0;
end;

{ a compiler directive: the branches of a conditional ($IF... $ELSE) start from the same state }
procedure TPasFormatter.Directive(I: Integer);
var
  S: string;
  P, Q: Integer;
begin
  S := FT[I].Text;
  if S[1] = '{' then P := 3 else P := 4;
  Q := P;
  while (Q <= Length(S)) and (S[Q] in ['A'..'Z', 'a'..'z', '_']) do Inc(Q);
  S := UpperCase(Copy(S, P, Q - P));
  if (S = 'IF') or (S = 'IFDEF') or (S = 'IFNDEF') or (S = 'IFOPT') then
  begin
    { right after the end of a block without an else: an alternative to it ( LINUX ...
        MSWINDOWS ... ) - it starts where that block started }
    if (FAltEnd >= 0) and (FAltEnd = I - 1) then
    begin
      FFr := Copy(FAltStart, 0, FAltStartTop + 1);
      FTop := FAltStartTop;
    end;
    FAltEnd := -1;
    Inc(FCondTop);
    if FCondTop >= Length(FCond) then SetLength(FCond, FCondTop + 8);
    FCond[FCondTop].Start := Copy(FFr, 0, FTop + 1);
    FCond[FCondTop].StartTop := FTop;
    FCond[FCondTop].HasElse := False;
  end
  else if (S = 'ELSE') or (S = 'ELSEIF') then
  begin
    if FCondTop < 0 then Exit;
    with FCond[FCondTop] do
    begin
      if not HasElse then
      begin
        FirstEnd := Copy(FFr, 0, FTop + 1);
        FirstEndTop := FTop;
        HasElse := True;
      end;
      FFr := Copy(Start, 0, StartTop + 1);
      FTop := StartTop;
    end;
  end
  else if (S = 'ENDIF') or (S = 'IFEND') then
  begin
    if FCondTop < 0 then Exit;
    with FCond[FCondTop] do
      if HasElse then
      begin
        FFr := Copy(FirstEnd, 0, FirstEndTop + 1);
        FTop := FirstEndTop;
        FAltEnd := -1;
      end
      else
      begin
        FAltStart := Copy(Start, 0, StartTop + 1);
        FAltStartTop := StartTop;
        FAltEnd := I;
      end;
    FCond[FCondTop].Start := nil;
    FCond[FCondTop].FirstEnd := nil;
    Dec(FCondTop);
  end;
end;

procedure TPasFormatter.CommentTok(I: Integer);
var
  T: PFmtTok;
begin
  T := @FT[I];
  if T.InAsm then
  begin
    AsmTok(I);
    Exit;
  end;
  if FBlankAfter > 0 then
  begin
    T.Blank := MaxInt2(T.Blank, FBlankAfter);
    FBlankAfter := 0;
  end;
  if T.IsDir then Directive(I);
  // the comments of a uses clause are kept as they are: in a project file the comment after a
  // unit names its form for Delphi (and for D7 Studio)
  if (Top.Kind = frDecl) and (Top.Sub = Ord(kwUses)) then T.Flags := T.Flags or tfNoCase;
  if (I > 0) and (T.NL = 0) then Exit;             // at the end of a line: no indent
  { (a directive that stands alone on its line in the output goes to the left margin and has the
    empty lines around it: Emit) }
  if not T.IsDir and (O[foIndentComments] = icNo) then
  begin
    T.Ind := T.SrcCol;
    T.Flags := T.Flags or tfKeepCol;
    Exit;
  end;
  if FPendCount >= Length(FPending) then SetLength(FPending, FPendCount * 2 + 8);
  FPending[FPendCount] := I;
  Inc(FPendCount);
end;

{ the comment lines before token I take the indent of what they stand before }
procedure TPasFormatter.ResolvePending(I: Integer);
var
  K, J: Integer;
begin
  if FPendCount = 0 then Exit;
  for K := 0 to FPendCount - 1 do
  begin
    J := FPending[K];
    FT[J].Ind := FCommentInd;
    if not FT[J].IsDir and (O[foIndentComments] = icAdditional) then Inc(FT[J].Ind, FIS);
  end;
  { the empty lines before a declaration go before the comments that belong to it }
  J := FPending[0];
  if FT[I].Blank > 0 then
  begin
    FT[J].Blank := MaxInt2(FT[J].Blank, FT[I].Blank);
    FT[I].Blank := 0;
  end;
  FPendCount := 0;
end;

procedure TPasFormatter.SigTok(I: Integer);
var
  T: PFmtTok;
begin
  T := @FT[I];
  if T.InAsm then
  begin
    AsmTok(I);
    Exit;
  end;
  if FBlankAfter > 0 then
  begin
    T.Blank := MaxInt2(T.Blank, FBlankAfter);
    FBlankAfter := 0;
  end;
  if FFileEnd then
  begin
    FFileEnd := False;
    if IsSym(I, syDot) then
    begin
      T.Brk := bkNo;
      FDone := True;
      FCommentInd := 0;
      ResolvePending(I);
      Exit;
    end;
  end;
  FCommentInd := -1;
  T.Ind := ContCol;
  Route(I);
  T := @FT[I];
  if FCommentInd < 0 then FCommentInd := T.Ind;
  ResolvePending(I);
  if FNoCase then
  begin
    if T.Kind = tkIdent then T.Flags := T.Flags or tfNoCase;
    if IsSym(I, sySemicolon) then FNoCase := False;
  end;
end;

procedure TPasFormatter.Route(I: Integer);
var
  K: TFrameKind;
begin
  PopDone(I);
  K := Top.Kind;
  if K = frParen then ParenTok(I)
  else if K = frHeader then HeaderTok(I)
  else if (FT[I].Kind = tkKeyword) and (FT[I].Kw in [kwInterface, kwImplementation, kwInitialization,
    kwFinalization]) and not IsSym(FPrev, syEqual) then SectionTok(I)
  else if (K in [frBlock, frTry, frRepeat, frCase, frCtrl, frAsm]) or
    ((K = frSection) and (Top.State = 1)) then StmtTok(I)
  else if K = frClass then ClassTok(I)
  else DeclTok(I);
end;

{ control statements whose statement is complete go, unless an else continues an if }
procedure TPasFormatter.PopDone(I: Integer);
begin
  while (Top.Kind = frCtrl) and Top.Done do
  begin
    if (Top.Sub = ckIf) and (Top.State = csThen) and IsKw(I, kwElse) then Exit;
    Pop;
    if Top.Kind = frCtrl then Top.Done := True;
  end;
end;

{ a token of an asm block: its lines keep their place relative to the first one }
procedure TPasFormatter.AsmTok(I: Integer);
var
  T: PFmtTok;
  J: Integer;
begin
  T := @FT[I];
  T.Flags := T.Flags or tfAsm;
  if not ((I = 0) or (T.NL > 0)) then Exit;
  if FAsmBase < 0 then FAsmBase := T.SrcCol;
  J := FTop;
  while (J > 0) and (FFr[J].Kind <> frAsm) do Dec(J);
  if O[foIndentAsm] = 0 then T.Ind := T.SrcCol
  else T.Ind := FFr[J].Inner + MaxInt2(0, T.SrcCol - FAsmBase);
end;

procedure TPasFormatter.SectionTok(I: Integer);
var
  T: PFmtTok;
  Kw: TKeyword;
begin
  T := @FT[I];
  Kw := T.Kw;
  FTop := 0;
  T.Ind := 0;
  T.Brk := bkYes;
  TakeSeparator(T, O[foNumOfEmptyLinesAroundSectionKeyword]);
  FBlankAfter := O[foNumOfEmptyLinesAroundSectionKeyword];
  FCommentInd := 0;
  if Kw in [kwInitialization, kwFinalization] then
  begin
    Push(frSection, Ord(Kw), 0, FIS + IfInt(O[foIndentAfterSections] <> 0, FIS, 0), I);
    Top.State := 1;
    Top.NextBrk := bkYes;
  end
  else
    Push(frSection, Ord(Kw), 0, IfInt(O[foIndentAfterSections] <> 0, FIS, 0), I);
end;

{ the empty lines before a token that starts a section or declaration: at least Blank, and those
  the declaration before asked for to separate it (FSepNext, used up) }
procedure TPasFormatter.TakeSeparator(T: PFmtTok; Blank: Integer);
begin
  T.Blank := MaxInt2(T.Blank, MaxInt2(Blank, FSepNext));
  FSepNext := 0;
end;

function DeclColOf(const F: TFrame): Integer;
begin
  case F.Kind of
    frFile: Result := 0;
    frDecl: Result := F.Col;
  else
    Result := F.Inner;
  end;
end;

procedure TPasFormatter.DeclTok(I: Integer);
var
  T: PFmtTok;
  N: Integer;
begin
  T := @FT[I];
  if T.Kind = tkKeyword then
    case T.Kw of
      kwUnit, kwProgram, kwLibrary:
        if (Top.Kind = frFile) and (FPrev < 0) then
        begin
          T.Ind := 0;
          T.Brk := bkYes;
          FNoCase := True;
          Exit;
        end;
      kwUses, kwVar, kwThreadvar, kwConst, kwResourcestring, kwLabel, kwExports:
        begin
          StartDeclSection(I);
          Exit;
        end;
      kwType:
        if not IsSym(FPrev, syEqual) then
        begin
          StartDeclSection(I);
          Exit;
        end;
      kwProcedure, kwFunction, kwConstructor, kwDestructor:
        if not (IsSym(FPrev, syEqual) or IsSym(FPrev, syColon) or IsKw(FPrev, kwOf)) then
        begin
          StartHeader(I);
          Exit;
        end;
      kwClass:
        begin
          N := NextSig(I);
          if (N >= 0) and (FT[N].Kind = tkKeyword) and (FT[N].Kw in [kwProcedure, kwFunction,
            kwConstructor, kwDestructor]) and not IsSym(FPrev, syEqual) then
          begin
            StartHeader(I);
            Exit;
          end;
        end;
      kwBegin, kwAsm:
        begin
          StartBody(I);
          Exit;
        end;
      kwEnd:
        begin
          { a declaration level "end" can only be the end of the file (records and classes
            have frames of their own) }
          FileEndTok(I);
          Exit;
        end;
    end;
  if (T.Kind = tkIdent) and (T.Dv = dvPackage) and (Top.Kind = frFile) and (FPrev < 0) then
  begin
    T.Ind := 0;
    T.Brk := bkYes;
    T.Flags := T.Flags or tfDirKw;
    FNoCase := True;
    Exit;
  end;
  if (T.Kind = tkIdent) and (T.Dv in [dvRequires, dvContains]) and (Top.Kind in [frFile, frDecl]) and
    not ((Top.Kind = frDecl) and Top.InItem) then
  begin
    StartDeclSection(I);
    Exit;
  end;
  if Top.Kind = frDecl then
  begin
    DeclItemTok(I);
    Exit;
  end;
  { the heading of the file and what else stands at this level }
  if IsSym(I, sySemicolon) then T.Brk := bkNo
  else if Top.Kind = frFile then
  begin
    Top.InItem := True;
    Top.Item := 0;
    T.Ind := FCI;
  end;
  Expr(I);
end;

{ a declaration section whose items are a comma separated list }
function IsListSection(Sub: Integer): Boolean;
begin
  Result := (Sub = Ord(kwUses)) or (Sub = Ord(kwLabel)) or (Sub = Ord(kwExports)) or
    (Sub = dsRequires) or (Sub = dsContains);
end;

procedure TPasFormatter.StartDeclSection(I: Integer);
var
  T: PFmtTok;
  Col, Sub, Blank: Integer;
  P: TFrame;
begin
  T := @FT[I];
  if Top.Kind = frDecl then Pop;
  P := Top^;
  Col := DeclColOf(P);
  if T.Kind = tkIdent then
  begin
    if T.Dv = dvRequires then Sub := dsRequires else Sub := dsContains;
    T.Flags := T.Flags or tfDirKw;
  end
  else
    Sub := Ord(T.Kw);
  T.Ind := Col;
  T.Brk := bkYes;
  Blank := 0;
  if P.Kind in [frFile, frSection] then
  begin
    if T.Kw = kwType then Blank := O[foNumOfEmptyLinesBeforeTypeKeyword]
    else if T.Kw in [kwVar, kwThreadvar, kwConst, kwResourcestring, kwLabel, kwExports] then
      Blank := O[foNumOfEmptyLinesBeforeSubsection];
    Inc(Top.Count);
    Top.ItemState := 0;
  end;
  TakeSeparator(T, Blank);
  Push(frDecl, Sub, Col, Col + FIS, I);
  if IsListSection(Sub) then
    Top.NextBrk := LfBrk(O[foNewLineAfterUses])
  else if (Sub = Ord(kwType)) or (O[foNewLineForEachVarAndConstElement] <> lfAsIs) then
    Top.NextBrk := bkYes
  else
    Top.NextBrk := bkAsIs;
end;

{ the frame of a class, object, interface or record whose body starts at token I (its "class",
  "record" ...), at column Col }
procedure TPasFormatter.PushClass(I, Col: Integer);
begin
  Push(frClass, Ord(FT[I].Kw), Col, Col + FIS, I);
  if FT[I].Kw = kwRecord then Top.State := clBody else Top.State := clHead;
end;

procedure TPasFormatter.DeclItemTok(I: Integer);
var
  T: PFmtTok;
  F: PFrame;
  List, VarLike: Boolean;
begin
  T := @FT[I];
  F := Top;
  List := IsListSection(F.Sub);
  VarLike := (F.Sub = Ord(kwVar)) or (F.Sub = Ord(kwThreadvar)) or (F.Sub = Ord(kwConst)) or
    (F.Sub = Ord(kwResourcestring));
  if not F.InItem then
  begin
    { a calling convention after a procedural type: TProc = procedure; stdcall; }
    if not List and (T.Kind = tkIdent) and (T.Dv in TypeTailDirectives) and
      IsSym(NextSig(I), sySemicolon) and IsSym(FPrev, sySemicolon) then
    begin
      T.Flags := T.Flags or tfDirKw;
      T.Ind := F.Item + FCI;
      F.InItem := True;
      F.ItemState := isTail;
      Exit;
    end;
    F.InItem := True;
    F.Item := F.Inner;
    F.ItemState := isStart;
    T.Ind := F.Inner;
    T.Brk := F.NextBrk;
    T.Flags := T.Flags or tfItemStart;
    if List then
    begin
      if F.Sub = Ord(kwUses) then F.NextBrk := LfBrk(O[foNewLineForEachUseElement])
      else F.NextBrk := LfBrk(O[foNewLineForEachLabelElement]);
    end
    else if VarLike then
    begin
      if O[foNewLineForEachVarAndConstElement] = lfAsIs then F.NextBrk := bkAsIs
      else F.NextBrk := LfBrk(O[foNewLineForEachVarAndConstElement]);
    end
    else
      F.NextBrk := bkYes;
  end
  else if List and IsSym(FPrev, syComma) then
  begin
    T.Ind := F.Inner;
    T.Brk := F.NextBrk;
  end
  else
    T.Ind := F.Item + FCI;
  if T.Kind = tkSymbol then
    case T.Sym of
      sySemicolon:
        begin
          T.Brk := bkNo;
          F.InItem := False;
          if List then Pop;
          Exit;
        end;
      syColon:
        if (F.ItemState = isStart) and not List then
        begin
          if VarLike then T.Align := akTypeName;
          F.ItemState := isColon;
        end;
      syEqual:
        if F.ItemState in [isStart, isColon] then
        begin
          if F.Sub = Ord(kwType) then T.Align := akTypeDef
          else if (F.Sub = Ord(kwConst)) and (F.ItemState = isStart) then T.Align := akConst
          else if VarLike then T.Align := akInit;
          F.ItemState := isEquals;
        end;
      syLParen:
        if VarLike and IsSym(FPrev, syEqual) and (F.ItemState = isEquals) and
          (CountSeps(I, syComma) > 0) and (CountSeps(I, sySemicolon) = 0) then
        begin
          OpenParen(I, pkArray);
          Exit;
        end;
    end
  else if T.Kind = tkKeyword then
    case T.Kw of
      kwClass, kwObject, kwInterface, kwDispinterface, kwRecord:
        if StartsBody(I) then
        begin
          PushClass(I, F.Item);
          Exit;
        end;
    end;
  Expr(I);
end;

{ a class, object, interface or record with a body (not "class of", "class;", "class(TBase);") }
function TPasFormatter.StartsBody(I: Integer): Boolean;
var
  N, M: Integer;
begin
  Result := True;
  N := NextSig(I);
  case FT[I].Kw of
    kwRecord: Exit;
    kwObject: Result := not IsKw(FPrev, kwOf);
    kwClass, kwInterface, kwDispinterface:
      begin
        if IsKw(N, kwOf) or IsSym(N, sySemicolon) then Result := False
        else if IsSym(N, syLParen) then
        begin
          M := FMatch[N];
          if (M >= 0) and IsSym(NextSig(M), sySemicolon) then Result := False;
        end
        else if (FT[I].Kw = kwClass) and (N >= 0) and (FT[N].Kind = tkKeyword) and
          (FT[N].Kw in [kwProcedure, kwFunction]) then Result := False;
      end;
  end;
end;

procedure TPasFormatter.StartHeader(I: Integer);
var
  T: PFmtTok;
  Col, Blank: Integer;
  P: PFrame;
begin
  T := @FT[I];
  if Top.Kind = frDecl then Pop;
  P := Top;
  if P.Kind = frClass then Col := P.Inner
  else if P.Kind = frRoutine then Col := P.Inner + IfInt(O[foIndentInnerFunctionImplementation] <> 0, FIS, 0)
  else Col := DeclColOf(P^);
  T.Ind := Col;
  T.Brk := bkYes;
  T.Flags := T.Flags or tfItemStart;
  Blank := 0;
  if P.Kind in [frFile, frSection] then
  begin
    if (P.Kind = frSection) and (P.Sub = Ord(kwInterface)) then
    begin
      if (P.Count > 0) and (P.ItemState <> 1) then Blank := O[foNumOfEmptyLinesAsSeparatorInInterfaceSection];
    end
    else if P.Count > 0 then
      Blank := O[foNumOfEmptyLinesAsSeparatorInImplementationSection];
    Inc(P.Count);
    P.ItemState := 1;
  end;
  TakeSeparator(T, Blank);
  Push(frHeader, 0, Col, Col, I);
  Top.InItem := True;
  Top.Item := Col;
  if T.Kw = kwClass then Top.State := hsKeyword else Top.State := hsName;
  if FFr[FTop - 1].Kind = frClass then Top.Flag := hfNoBody;
end;

procedure TPasFormatter.HeaderTok(I: Integer);
var
  T: PFmtTok;
  H: PFrame;
  N, Cnt: Integer;
begin
  T := @FT[I];
  H := Top;
  T.Ind := H.Col + FCI;
  case H.State of
    hsKeyword:
      begin
        if T.Kind = tkKeyword then T.Brk := bkNo;
        H.State := hsName;
        Exit;
      end;
    hsName, hsResult:
      begin
        if IsSym(I, sySemicolon) then
        begin
          T.Brk := bkNo;
          H.State := hsDirectives;
          Exit;
        end;
        if (H.State = hsName) and IsSym(I, syLParen) then
        begin
          T.Flags := T.Flags or tfFuncParen;
          Cnt := CountSeps(I, sySemicolon) + 1;
          OpenParen(I, pkParams);
          if Cnt > 1 then
            ListBreaks(O[foNewLineParamTypesInFunction], bkAsIs)
          else if O[foNewLineParamTypesInFunction] = lfNo then
            Top.InnerBrk := bkNo;
          Exit;
        end;
        if (H.State = hsName) and IsSym(I, syColon) then
        begin
          T.Brk := LfBrk(O[foNewLineFunctionType]);
          H.State := hsResult;
          Exit;
        end;
        Expr(I);
      end;
    hsDirectives:
      begin
        N := NextSig(I);
        if (((T.Kind = tkIdent) and (T.Dv in RoutineDirs)) or IsKw(I, kwInline)) and
          not (IsSym(N, syColon) or IsSym(N, syComma) or IsSym(N, syEqual) or IsSym(N, syAssign) or
          IsSym(N, syDot)) then
        begin
          T.Flags := T.Flags or tfDirKw;
          if T.Dv in [dvForward, dvExternal] then H.Flag := H.Flag or hfNoBody;
          H.State := hsDirArgs;
          Exit;
        end;
        EndHeader(I);
        Route(I);
      end;
    hsDirArgs:
      begin
        if IsSym(I, sySemicolon) then
        begin
          T.Brk := bkNo;
          H.State := hsDirectives;
          Exit;
        end;
        if (T.Kind = tkIdent) and (T.Dv in [dvName, dvIndex, dvResident]) then T.Flags := T.Flags or tfDirKw;
        Expr(I);
      end;
  end;
end;

procedure TPasFormatter.EndHeader(I: Integer);
var
  H: TFrame;
  NoBody: Boolean;
begin
  H := Top^;
  Pop;
  NoBody := (H.Flag and hfNoBody) <> 0;
  if (Top.Kind = frClass) or ((Top.Kind = frSection) and (Top.Sub = Ord(kwInterface))) then NoBody := True;
  if Top.Kind = frClass then Top.InItem := False;
  if not NoBody then
    Push(frRoutine, 0, H.Col, H.Col + IfInt(O[foIndentFunctionImplementationBody] <> 0, FIS, 0), H.Tok);
  FT[I].Ind := ContCol;
end;

procedure TPasFormatter.StartBody(I: Integer);
var
  T: PFmtTok;
  Col: Integer;
  Method: Boolean;
begin
  T := @FT[I];
  if Top.Kind = frDecl then Pop;
  Method := Top.Kind = frRoutine;
  if Method then Col := Top.Inner else Col := 0;
  T.Ind := Col;
  T.Brk := bkYes;
  if not Method then TakeSeparator(T, 0);
  if T.Kw = kwAsm then
  begin
    Push(frAsm, 0, Col, Col + FIS, I);
    FAsmBase := AsmBase(I);
    if O[foIndentAsm] = 0 then T.Ind := T.SrcCol;
  end
  else
  begin
    Push(frBlock, 0, Col, Col + IfInt(O[foIndentBlockContents] <> 0, FIS, 0), I);
    if Method then Top.NextBrk := LfBrk(O[foNewLineAfterBeginInMethodDefinition])
    else Top.NextBrk := LfBrk(O[foNewLineAfterOtherBegin]);
  end;
  if Method then Top.Flag := fbMethod else Top.Flag := fbMain;
end;

{ the "end" of a program, unit or package }
procedure TPasFormatter.FileEndTok(I: Integer);
begin
  FTop := 0;
  FT[I].Ind := 0;
  FT[I].Brk := bkYes;
  TakeSeparator(@FT[I], 0);
  FCommentInd := 0;
  FFileEnd := True;
end;

procedure TPasFormatter.ClassTok(I: Integer);
var
  T: PFmtTok;
  C: PFrame;
  Cnt, N, VisCol: Integer;
begin
  T := @FT[I];
  C := Top;
  if C.State = clHead then
  begin
    if IsSym(I, syLParen) then
    begin
      Cnt := CountSeps(I, syComma) + 1;
      OpenParen(I, pkHeritage);
      case O[foNewLineInClassInheritances] of
        leNo: Top.InnerBrk := bkNo;
        leFirstSame:
          if Cnt > 1 then
          begin
            Top.FirstBrk := bkNo;
            Top.ElemBrk := bkYes;
          end;
        leFirstNext:
          if Cnt > 1 then
          begin
            Top.FirstBrk := bkYes;
            Top.ElemBrk := bkYes;
          end;
      end;
      Exit;
    end;
    C.State := clBody;
  end;
  if not C.InItem then
  begin
    if IsKw(I, kwEnd) then
    begin
      ClassEnd(I);
      Exit;
    end;
    { visibility }
    if (T.Kind = tkIdent) and (T.Dv in VisibilityDirs) and not IsSym(NextSig(I), syColon) and
      not IsSym(NextSig(I), syComma) then
    begin
      VisCol := C.Col + IfInt(O[foIndentClassDefinitionBody] <> 0, FIS, 0);
      T.Ind := VisCol;
      T.Brk := bkYes;
      T.Flags := T.Flags or tfDirKw;
      if C.Count > 0 then T.Blank := MaxInt2(T.Blank, O[foNumOfEmptyLinesBeforeVisibility]);
      C.Inner := VisCol + FIS;
      Inc(C.Count);
      Exit;
    end;
    { methods }
    N := NextSig(I);
    if (T.Kind = tkKeyword) and ((T.Kw in [kwProcedure, kwFunction, kwConstructor, kwDestructor]) or
      ((T.Kw = kwClass) and (N >= 0) and (FT[N].Kind = tkKeyword) and (FT[N].Kw in [kwProcedure,
      kwFunction]))) then
    begin
      Inc(C.Count);
      StartHeader(I);
      Exit;
    end;
    { "default;" after an array property }
    if IsDv(I, dvDefault) and IsSym(N, sySemicolon) and IsSym(FPrev, sySemicolon) then
    begin
      T.Flags := T.Flags or tfDirKw;
      T.Ind := C.Item + FCI;
      C.InItem := True;
      C.ItemState := ikTail;
      Exit;
    end;
    Inc(C.Count);
    C.InItem := True;
    C.Item := C.Inner;
    T.Ind := C.Inner;
    T.Brk := bkYes;
    T.Flags := T.Flags or tfItemStart;
    if IsKw(I, kwProperty) then C.ItemState := ikProperty
    else if IsKw(I, kwCase) then C.ItemState := ikCaseHead
    else if IsSym(I, syLBracket) then C.ItemState := ikGuid
    else if C.Flag = cfVariant then C.ItemState := ikTail
    else C.ItemState := ikField;
    if not (T.Kind = tkSymbol) then Exit;
    Expr(I);
    Exit;
  end;
  { an interface's GUID has no ";": what follows it is the next member }
  if (C.ItemState = ikGuid) and not IsSym(I, sySemicolon) then
  begin
    C.InItem := False;
    ClassTok(I);
    Exit;
  end;
  T.Ind := C.Item + FCI;
  if IsKw(I, kwEnd) then
  begin
    ClassEnd(I);
    Exit;
  end;
  if IsSym(I, sySemicolon) then
  begin
    T.Brk := bkNo;
    C.InItem := False;
    Exit;
  end;
  case C.ItemState of
    ikField:
      if IsSym(I, syColon) then
      begin
        T.Align := akTypeName;
        C.ItemState := ikFieldTyped;
        Exit;
      end;
    ikCaseHead:
      if IsKw(I, kwOf) then
      begin
        { the variant part of a record: its labels one level in }
        C.InItem := False;
        C.Inner := C.Inner + FIS;
        C.Flag := cfVariant;
        Exit;
      end;
    ikProperty:
      if (T.Kind = tkIdent) and (T.Dv in PropSpecifiers) and not IsKw(FPrev, kwProperty) and
        not IsSym(FPrev, syColon) and not IsSym(FPrev, syDot) then
      begin
        T.Flags := T.Flags or tfDirKw;
        if O[foNewLineInPropertyDeclaration] <> 0 then
        begin
          T.Brk := bkYes;
          N := NextSig(I);
          if N >= 0 then FT[N].Align := akProperty;
        end;
        Exit;
      end;
  end;
  if (T.Kind = tkKeyword) and (T.Kw in [kwRecord, kwClass, kwObject]) and StartsBody(I) then
  begin
    PushClass(I, C.Item);
    Exit;
  end;
  Expr(I);
end;

procedure TPasFormatter.ClassEnd(I: Integer);
var
  C: TFrame;
begin
  C := Top^;
  FT[I].Ind := C.Col;
  if C.Count = 0 then FT[I].Brk := bkAsIs else FT[I].Brk := bkYes;
  FCommentInd := C.Inner;
  Pop;
end;

{ ------------------------------------------------------------------------------ statements }

procedure TPasFormatter.StmtTok(I: Integer);
var
  T: PFmtTok;
  F: PFrame;
begin
  T := @FT[I];
  if T.Kind = tkKeyword then
    case T.Kw of
      kwEnd:
        begin
          CloseEnd(I);
          Exit;
        end;
      kwUntil:
        begin
          CloseUntil(I);
          Exit;
        end;
      kwExcept, kwFinally:
        if CloseTryPart(I) then Exit;
      kwElse:
        if HandleElse(I) then Exit;
    end;
  if IsSym(I, sySemicolon) then
  begin
    T.Brk := bkNo;
    EndStatement;
    Exit;
  end;
  F := Top;
  if (F.Kind = frCtrl) and (F.State = csCond) then
  begin
    if ((F.Sub = ckIf) and IsKw(I, kwThen)) or ((F.Sub in [ckLoop, ckOn]) and IsKw(I, kwDo)) then
    begin
      T.Ind := F.Col;
      if F.Sub = ckIf then
      begin
        if O[foNewLineBeforeThen] <> 0 then T.Brk := bkYes else T.Brk := bkNo;
      end;
      F.State := csThen;
      F.InItem := False;
      Exit;
    end;
    Expr(I);
    Exit;
  end;
  if F.Kind = frCase then
    case F.State of
      cqSelector:
        begin
          if IsKw(I, kwOf) then
          begin
            F.State := cqLabels;
            F.InItem := False;
          end
          else
            Expr(I);
          Exit;
        end;
      cqLabels:
        begin
          CaseLabelTok(I);
          Exit;
        end;
    end;
  if not F.InItem then StatementStart(I) else Expr(I);
end;

procedure TPasFormatter.PushCtrl(Kind, Col, I: Integer);
begin
  Push(frCtrl, Kind, Col, Col + FIS, I);
  Top.BeginCol := Col + IfInt(O[foIndentBeginAndEnd] <> 0, FIS, 0);
  Top.State := csCond;
  Top.InItem := True;
  Top.Item := Col;
  Top.ItemState := sbAssign;          // "for I := ...": not an assignment to align
end;

procedure TPasFormatter.StatementStart(I: Integer);
var
  T: PFmtTok;
  F: PFrame;
  Col, Brk, N: Integer;
  IsBegin: Boolean;
begin
  T := @FT[I];
  F := Top;
  IsBegin := IsKw(I, kwBegin);
  if F.Kind = frCtrl then
  begin
    if IsBegin then
    begin
      Col := F.BeginCol;
      Brk := LfBrk(O[foNewLineBeforeBeginInControlBlock]);
    end
    else if (F.Sub = ckIf) and (F.State = csElse) and IsKw(I, kwIf) then
    begin
      Col := F.Col;
      if (O[foNewLineBetweenElseAndIf] <> 0) and not FElseJoin then Brk := bkYes else Brk := bkNo;
    end
    else if F.Sub = ckStmtLabel then
    begin
      Col := F.Inner;
      Brk := LfBrk(O[foNewLineAfterLabel]);
    end
    else
    begin
      Col := F.Inner;
      Brk := LfBrk(O[foNewLineBeforeSimpleInstructionInControlBlock]);
    end;
    if FElseJoin then Brk := bkNo;
  end
  else
  begin
    Col := F.Inner;
    Brk := F.NextBrk;
  end;
  FElseJoin := False;
  T.Ind := Col;
  T.Brk := Brk;
  T.Flags := T.Flags or tfStmtStart;
  F.InItem := True;
  F.Item := Col;
  F.ItemState := 0;
  if T.Kind = tkKeyword then
    case T.Kw of
      kwBegin:
        begin
          Push(frBlock, 0, Col, Col + IfInt(O[foIndentBlockContents] <> 0, FIS, 0), I);
          if FFr[FTop - 1].Kind = frCtrl then Top.NextBrk := LfBrk(O[foNewLineAfterBeginInControlBlock])
          else Top.NextBrk := LfBrk(O[foNewLineAfterOtherBegin]);
          Exit;
        end;
      kwIf:
        begin
          PushCtrl(ckIf, Col, I);
          Exit;
        end;
      kwWhile, kwFor, kwWith:
        begin
          PushCtrl(ckLoop, Col, I);
          Exit;
        end;
      kwCase:
        begin
          Push(frCase, 0, Col, Col + IfInt(O[foIndentCaseLabels] <> 0, FIS, 0), I);
          Top.InItem := True;
          Top.Item := Col;
          Exit;
        end;
      kwRepeat:
        begin
          Push(frRepeat, 0, Col, Col + FIS, I);
          Top.NextBrk := LfBrk(O[foNewLineBeforeSimpleInstructionInControlBlock]);
          Exit;
        end;
      kwTry:
        begin
          Push(frTry, 0, Col, Col + FIS, I);
          Top.NextBrk := LfBrk(O[foNewLineBeforeSimpleInstructionInTryCatchBlock]);
          Exit;
        end;
      kwAsm:
        begin
          Push(frAsm, 0, Col, Col + FIS, I);
          FAsmBase := AsmBase(I);
          if O[foIndentAsm] = 0 then T.Ind := T.SrcCol;
          Exit;
        end;
    end;
  if (T.Kind = tkIdent) and (T.Dv = dvOn) and (F.Kind = frTry) and (F.State = tsExcept) then
  begin
    T.Flags := T.Flags or tfDirKw;
    PushCtrl(ckOn, Col, I);
    Exit;
  end;
  N := NextSig(I);
  if (T.Kind in [tkIdent, tkNumber]) and IsSym(N, syColon) and (F.Kind <> frCase) then
  begin
    { a label of goto }
    case O[foDecreaseLabelsIndent] of
      unLeftMargin: T.Ind := 0;
      unOneIndent: T.Ind := MaxInt2(0, Col - FIS);
    end;
    FT[N].Flags := FT[N].Flags or tfLabelColon;
    Exit;
  end;
  if T.Kind = tkIdent then F.ItemState := sbIdent;
  Expr(I);
end;

{ a ";": the statement and the control statements around it end }
procedure TPasFormatter.EndStatement;
begin
  while (FTop > 0) and (Top.Kind in [frCtrl, frParen]) do Pop;
  Top.InItem := False;
  if Top.Kind = frCase then Exit;
  if O[foNewLineAfterSemicolon] <> 0 then Top.NextBrk := bkYes else Top.NextBrk := bkDefault;
end;

procedure TPasFormatter.CloseEnd(I: Integer);
var
  T: PFmtTok;
  J: Integer;
  F: TFrame;
begin
  T := @FT[I];
  J := FTop;
  while J > 0 do
  begin
    case FFr[J].Kind of
      frBlock:
        if (FFr[J].Flag and fbPseudo) = 0 then Break;
      frTry, frCase, frAsm, frClass:
        Break;
      frSection, frFile, frRoutine, frDecl:
        begin
          J := 0;
          Break;
        end;
    end;
    Dec(J);
  end;
  if J <= 0 then
  begin
    FileEndTok(I);
    Exit;
  end;
  F := FFr[J];
  T.Ind := F.Col;
  if (F.Kind = frAsm) and (O[foIndentAsm] = 0) then T.Ind := T.SrcCol;
  if FPrev = F.Tok then T.Brk := bkAsIs else T.Brk := bkYes;
  FCommentInd := F.Inner;
  FTop := J - 1;
  if (F.Flag and fbMain) <> 0 then
  begin
    FTop := 0;
    FFileEnd := True;
    Exit;
  end;
  if (F.Flag and fbMethod) <> 0 then
  begin
    while (FTop > 0) and (Top.Kind <> frRoutine) do Pop;
    if Top.Kind = frRoutine then
    begin
      Pop;
      if (Top.Kind = frFile) or ((Top.Kind = frSection) and (Top.Sub = Ord(kwImplementation))) then
        FSepNext := O[foNumOfEmptyLinesAsSeparatorInImplementationSection];
      Top.InItem := False;
    end;
    Exit;
  end;
  if F.Kind = frClass then Exit;
  if Top.Kind = frCtrl then Top.Done := True;
end;

procedure TPasFormatter.CloseUntil(I: Integer);
var
  J: Integer;
begin
  J := FTop;
  while (J > 0) and (FFr[J].Kind <> frRepeat) do Dec(J);
  if J <= 0 then
  begin
    Expr(I);
    Exit;
  end;
  FT[I].Ind := FFr[J].Col;
  FT[I].Brk := bkYes;
  FCommentInd := FFr[J].Inner;
  FTop := J - 1;
end;

function TPasFormatter.CloseTryPart(I: Integer): Boolean;
var
  J: Integer;
  F: PFrame;
begin
  J := FTop;
  while (J > 0) and (FFr[J].Kind <> frTry) do Dec(J);
  Result := J > 0;
  if not Result then Exit;
  FTop := J;
  F := Top;
  FT[I].Ind := F.Col;
  FT[I].Brk := bkYes;
  FCommentInd := F.Inner;
  if IsKw(I, kwExcept) then F.State := tsExcept else F.State := tsFinally;
  F.InItem := False;
  F.NextBrk := LfBrk(O[foNewLineBeforeSimpleInstructionInTryCatchBlock]);
end;

function TPasFormatter.HandleElse(I: Integer): Boolean;
var
  T: PFmtTok;
  J, N: Integer;
  F: PFrame;
begin
  T := @FT[I];
  J := FTop;
  while J > 0 do
  begin
    F := @FFr[J];
    if F.Kind = frCtrl then
    begin
      if (F.Sub = ckIf) and (F.State = csThen) then Break;
      Dec(J);
      Continue;
    end;
    if ((F.Kind = frCase) and (F.State = cqLabels)) or ((F.Kind = frTry) and (F.State = tsExcept)) then Break;
    J := 0;
  end;
  Result := J > 0;
  if not Result then Exit;
  FTop := J;
  F := Top;
  case F.Kind of
    frCtrl:
      begin
        T.Ind := F.Col;
        if IsKw(FPrev, kwEnd) then
        begin
          N := NextSig(I);
          if ((O[foRemoveNewLinesInEndElseBegin] <> 0) and IsKw(N, kwBegin)) or
            ((O[foRemoveNewLinesInEndElseIf] <> 0) and IsKw(N, kwIf)) then
          begin
            T.Brk := bkNo;
            FElseJoin := True;
          end
          else
            T.Brk := bkYes;
        end
        else
          T.Brk := LfBrk(O[foNewLineBeforeSimpleInstructionInControlBlock]);
        FCommentInd := F.Inner;
        F.State := csElse;
        F.InItem := False;
        F.Done := False;
      end;
    frCase:
      begin
        if O[foExtraIndentAfterElseInCase] <> 0 then T.Ind := F.Inner else T.Ind := F.Col;
        T.Brk := bkYes;
        FCommentInd := F.Inner;
        F.State := cqElse;
        F.Inner := T.Ind + FIS;
        F.InItem := False;
        F.NextBrk := LfBrk(O[foNewLineBeforeSimpleInstructionInControlBlock]);
      end;
    frTry:
      begin
        T.Ind := F.Inner;
        T.Brk := bkYes;
        N := F.Inner;
        Push(frBlock, 0, N, N + FIS, I);
        Top.Flag := fbPseudo;
        Top.NextBrk := LfBrk(O[foNewLineBeforeSimpleInstructionInControlBlock]);
      end;
  end;
end;

procedure TPasFormatter.CaseLabelTok(I: Integer);
var
  T: PFmtTok;
  F: PFrame;
  Lab, Inner: Integer;
begin
  T := @FT[I];
  F := Top;
  if not F.InItem then
  begin
    T.Ind := F.Inner;
    T.Brk := bkYes;
    F.InItem := True;
    F.Item := F.Inner;
  end
  else
    T.Ind := F.Item + FCI;
  if IsSym(I, syColon) then
  begin
    F.InItem := False;
    Lab := F.Inner;
    Inner := Lab + IfInt(O[foIndentCaseContents] <> 0, FIS, 0);
    Push(frCtrl, ckLabel, Lab, Inner, I);
    Top.BeginCol := Inner + IfInt(O[foIndentBeginAndEnd] <> 0, FIS, 0);
    Top.State := csThen;
    Exit;
  end;
  Expr(I);
end;

function TPasFormatter.IsUnaryPos(P: Integer): Boolean;
begin
  if P < 0 then
    Result := True
  else
    case FT[P].Kind of
      tkSymbol: Result := not (FT[P].Sym in [syRParen, syRBracket, syCaret]);
      tkKeyword: Result := not (FT[P].Kw in [kwEnd, kwNil, kwString]);
    else
      Result := False;
    end;
end;

function TPasFormatter.IsOperandEnd(P: Integer): Boolean;
begin
  if P < 0 then
    Result := False
  else
    case FT[P].Kind of
      tkIdent, tkNumber, tkString: Result := True;
      tkSymbol: Result := FT[P].Sym in [syRParen, syRBracket, syCaret];
      tkKeyword: Result := FT[P].Kw in [kwNil, kwInherited];
    else
      Result := False;
    end;
end;

{ a token inside an item: brackets, operators, the colon of a label }
procedure TPasFormatter.Expr(I: Integer);
var
  T: PFmtTok;
  F: PFrame;
  Col: Integer;
begin
  T := @FT[I];
  if T.Kind <> tkSymbol then Exit;
  case T.Sym of
    syLParen, syLBracket:
      OpenParen(I, -1);
    syPlus, syMinus:
      if IsUnaryPos(FPrev) then T.Flags := T.Flags or tfUnary;
    syAt:
      T.Flags := T.Flags or tfUnary;
    syCaret:
      if not IsOperandEnd(FPrev) then T.Flags := T.Flags or tfPrefixCaret;
    syAssign:
      begin
        F := Top;
        if (F.Kind in StmtFrames) and ((F.ItemState and sbAssign) = 0) then
        begin
          T.Align := akAssign;
          F.ItemState := F.ItemState or sbAssign;
        end;
      end;
    syColon:
      if (T.Flags and tfLabelColon) <> 0 then
      begin
        Col := Top.Item;
        Push(frCtrl, ckStmtLabel, Col, Col, I);
        Top.BeginCol := Col;
        Top.State := csThen;
      end;
  end;
end;

{ the line breaks inside the bracket just opened (Top) by a list option V (LF_CASE): Yes - each
  element on a line of its own, No - no break inside; else AsIs (the breaks the elements get
  without the option) }
procedure TPasFormatter.ListBreaks(V, AsIs: Integer);
begin
  case V of
    lfYes:
      begin
        Top.FirstBrk := bkYes;
        Top.ElemBrk := bkYes;
      end;
    lfNo: Top.InnerBrk := bkNo;
  else
    Top.FirstBrk := AsIs;
    Top.ElemBrk := AsIs;
  end;
end;

{ an opening bracket (Kind < 0: decided here) }
procedure TPasFormatter.OpenParen(I, Kind: Integer);
var
  F: TFrame;
  T: PFmtTok;
  Base, Cnt: Integer;
  S: string;
  Inherit: Integer;
begin
  T := @FT[I];
  F := Top^;
  Inherit := bkDefault;
  if F.Kind = frParen then
  begin
    Base := F.Inner + IfInt(O[foIndentBrackets] <> 0, FCI, 0);
    if F.InnerBrk = bkNo then Inherit := bkNo;
  end
  else if F.InItem then Base := F.Item + FCI
  else Base := F.Inner + FCI;
  if Kind < 0 then
  begin
    Kind := pkExpr;
    if T.Sym = syLBracket then Kind := pkIndex
    else if (F.Kind = frParen) and (F.Sub = pkArray) and (O[foFormatArrayInitialization] = laYes) and
      (CountSeps(I, syComma) > 0) and (CountSeps(I, sySemicolon) = 0) then
      Kind := pkArray
    else if (FPrev >= 0) and (FT[FPrev].Kind = tkIdent) and (F.Kind <> frParen) then
    begin
      T.Flags := T.Flags or tfFuncParen;
      S := LowerCase(FT[FPrev].Text);
      if (S = 'write') or (S = 'writeln') or (S = 'str') then Kind := pkFormat
      else if (F.Kind in StmtFrames) and ((F.ItemState and sbIdent) <> 0) and
        ((F.ItemState and sbParen) = 0) then Kind := pkCall;
    end;
    if F.Kind in StmtFrames then Top.ItemState := Top.ItemState or sbParen;
  end;
  Push(frParen, Kind, Base, Base, I);
  Top.InnerBrk := Inherit;
  case Kind of
    pkCall, pkFormat:
      begin
        Cnt := CountSeps(I, syComma) + 1;
        if (Kind = pkCall) and (Cnt > 1) and (Inherit = bkDefault) then
          ListBreaks(O[foNewLineParamValuesInFunction], bkDefault);
      end;
    pkArray:
      if Inherit = bkDefault then
      begin
        if F.Kind = frParen then Base := F.Inner else Base := F.Item;
        case O[foFormatArrayInitialization] of
          laYes, laMainElems:
            begin
              Top.Inner := Base + FIS;
              Top.CloseCol := Base;
              Top.FirstBrk := bkYes;
              Top.ElemBrk := bkYes;
              Top.CloseBrk := bkYes;
            end;
          laNo: Top.InnerBrk := bkNo;
          laAsIs:
            begin
              Top.FirstBrk := bkAsIs;
              Top.ElemBrk := bkAsIs;
              Top.CloseBrk := bkAsIs;
            end;
        end;
      end;
  end;
end;

procedure TPasFormatter.ParenTok(I: Integer);
var
  T: PFmtTok;
  F: PFrame;
  First: Boolean;
begin
  T := @FT[I];
  F := Top;
  First := FPrev = F.Tok;
  T.Ind := F.Inner;
  if F.InnerBrk <> bkDefault then T.Brk := F.InnerBrk;
  if (I = FMatch[F.Tok]) or ((FMatch[F.Tok] < 0) and (T.Kind = tkSymbol) and (T.Sym in [syRParen, syRBracket])) then
  begin
    T.Ind := F.CloseCol;
    if (F.CloseBrk <> bkDefault) and not First then T.Brk := F.CloseBrk;
    Pop;
    Exit;
  end;
  if First and (F.FirstBrk <> bkDefault) then T.Brk := F.FirstBrk;
  if (F.LastSep >= 0) and (FPrev = F.LastSep) and (F.ElemBrk <> bkDefault) then T.Brk := F.ElemBrk;
  if (F.Sub = pkParams) and (First or (FPrev = F.LastSep)) then T.Flags := T.Flags or tfItemStart;
  if T.Kind = tkSymbol then
    case T.Sym of
      syComma:
        begin
          if F.Sub <> pkParams then F.LastSep := I;
          Exit;
        end;
      sySemicolon:
        begin
          T.Brk := bkNo;
          if F.Sub = pkParams then
          begin
            F.LastSep := I;
            F.ItemState := 0;
          end;
          Exit;
        end;
      syColon:
        begin
          if F.Sub = pkFormat then T.Flags := T.Flags or tfFmtColon
          else if (F.Sub = pkParams) and (F.ItemState = 0) then
          begin
            T.Align := akParamType;
            F.ItemState := 1;
          end;
          Exit;
        end;
    end;
  if (F.Sub = pkParams) and IsDv(I, dvOut) and (First or (FPrev = F.LastSep)) then T.Flags := T.Flags or tfDirKw;
  Expr(I);
end;

{ ------------------------------------------------------------------------------ case of words }

type
  TStringArray = array of string;

  { the first spelling of each word met, found by the word in any letter case (the words of
    tokens: ASCII) - an open addressing hash of SdPasLex's HashUpper }
  TCaseMap = class
  private
    FWords: TStringArray;        // '' = a free slot
    FMask, FCount: Integer;
    function Slot(const S: string): Integer;
  public
    constructor Create;
    { the spelling of S met first - S itself when it is the first }
    function First(const S: string): string;
  end;

constructor TCaseMap.Create;
begin
  inherited Create;
  SetLength(FWords, 256);
  FMask := 255;
end;

{ the slot of S's word, else the free one where it goes }
function TCaseMap.Slot(const S: string): Integer;
begin
  Result := Integer(HashUpper(PChar(S), Length(S))) and FMask;
  while (FWords[Result] <> '') and not SameTextP(PChar(S), Length(S), FWords[Result]) do
    Result := (Result + 1) and FMask;
end;

function TCaseMap.First(const S: string): string;
var
  I: Integer;
  Old: TStringArray;
begin
  Result := S;
  if S = '' then Exit;
  I := Slot(S);
  if FWords[I] <> '' then
  begin
    Result := FWords[I];
    Exit;
  end;
  FWords[I] := S;
  Inc(FCount);
  if FCount * 2 > Length(FWords) then
  begin
    Old := FWords;
    FWords := nil;
    SetLength(FWords, Length(Old) * 2);
    FMask := Length(FWords) - 1;
    for I := 0 to High(Old) do
      if Old[I] <> '' then FWords[Slot(Old[I])] := Old[I];
  end;
end;

function Capitalize(const S: string; Mode: Integer; Map: TCaseMap): string;
begin
  case Mode of
    caLower: Result := LowerCase(S);
    caUpper: Result := UpperCase(S);
    caFirstUpper:
      begin
        Result := S;
        if Result <> '' then Result[1] := UpCase(Result[1]);
      end;
    caFirstOccurrence:
      Result := Map.First(S);
  else
    Result := S;
  end;
end;

procedure TPasFormatter.ApplyCase;
var
  Kws, Ids, Nums, Dirs: TCaseMap;
  I, P, Q, N: Integer;
  T: PFmtTok;
  S, C: string;
begin
  Kws := TCaseMap.Create;
  Ids := TCaseMap.Create;
  Nums := TCaseMap.Create;
  Dirs := TCaseMap.Create;
  try
    for I := 0 to FLast do
    begin
      T := @FT[I];
      if (T.Flags and (tfAsm or tfNoCase)) <> 0 then Continue;
      case T.Kind of
        tkKeyword:
          T.Text := Capitalize(T.Text, O[foKeywordsCapitalization], Kws);
        tkIdent:
          if (T.Flags and tfDirKw) <> 0 then T.Text := Capitalize(T.Text, O[foKeywordsCapitalization], Kws)
          else T.Text := Capitalize(T.Text, O[foOtherWordsCapitalization], Ids);
        tkNumber:
          begin
            S := T.Text;
            P := 1;
            while (P <= Length(S)) and not (S[P] in ['A'..'Z', 'a'..'z']) do Inc(P);
            if P <= Length(S) then
            begin
              if S[1] = '$' then T.Text := '$' + Capitalize(Copy(S, 2, MaxInt), O[foNumbersCapitalization], Nums)
              else T.Text := Capitalize(S, O[foNumbersCapitalization], Nums);
            end;
          end;
        tkComment:
          begin
            S := T.Text;
            if T.IsDir then
            begin
              if S[1] = '{' then P := 3 else P := 4;
              Q := P;
              while (Q <= Length(S)) and (S[Q] in ['A'..'Z', 'a'..'z', '_']) do Inc(Q);
              if Q > P then
              begin
                C := Capitalize(Copy(S, P, Q - P), O[foCompilerDirectivesCapitalization], Dirs);
                T.Text := Copy(S, 1, P - 1) + C + Copy(S, Q, MaxInt);
              end;
            end
            else if T.IsLineCmt then
            begin
              if (O[foCommentStartInlineSpaces] in [usAfter, usBoth]) and (Length(S) > 2) and
                not (S[3] in [' ', #9, '/']) then
                T.Text := '// ' + Copy(S, 3, MaxInt);
            end
            else if O[foCommentBracesSpaces] in [ioInner, ioBoth] then
            begin
              if S[1] = '{' then N := 1 else N := 2;
              { the text between the braces; a comment that is not closed keeps its end }
              if ((N = 1) and (S[Length(S)] = '}')) or ((N = 2) and (Length(S) >= 4) and
                (Copy(S, Length(S) - 1, 2) = '*)')) then
              begin
                C := Copy(S, N + 1, Length(S) - 2 * N);
                if (C <> '') and (Trim(C) <> '') and (C[1] <> '$') then
                begin
                  if not (C[1] in [' ', #9, #10, #13]) then C := ' ' + C;
                  if not (C[Length(C)] in [' ', #9, #10, #13]) then C := C + ' ';
                  T.Text := Copy(S, 1, N) + C + Copy(S, Length(S) - N + 1, N);
                end;
              end;
            end;
          end;
      end;
    end;
  finally
    Dirs.Free;
    Nums.Free;
    Ids.Free;
    Kws.Free;
  end;
end;

{ ------------------------------------------------------------------------------ output }

function TPasFormatter.Breaks(I: Integer): Boolean;
var
  T, P: PFmtTok;
  Src: Boolean;
begin
  T := @FT[I];
  P := @FT[I - 1];
  Src := T.NL > 0;
  if P.IsLineCmt then
  begin
    Result := True;
    Exit;
  end;
  if T.InAsm or ((T.Flags and tfAsm) <> 0) then
  begin
    Result := Src;
    Exit;
  end;
  if T.Kind = tkComment then
  begin
    Result := Src;
    Exit;
  end;
  if P.Kind = tkComment then
  begin
    Result := Src or (T.Brk = bkYes);
    Exit;
  end;
  case T.Brk of
    bkYes: Result := True;
    bkNo: Result := False;
    bkAsIs: Result := Src;
  else
    Result := Src and (O[foKeepUserLinebreaks] <> 0);
  end;
end;

{ USE_SPACE before / after a token: 0 none, 1 one, 2 as is }
function UseBefore(V: Integer): Integer;
begin
  case V of
    usBefore, usBoth: Result := 1;
    usAsIs: Result := 2;
  else
    Result := 0;
  end;
end;

function UseAfter(V: Integer): Integer;
begin
  case V of
    usAfter, usBoth: Result := 1;
    usAsIs: Result := 2;
  else
    Result := 0;
  end;
end;

function TPasFormatter.SpaceBefore(I: Integer): string;
var
  P, T: PFmtTok;
  AV, BV, V: Integer;
  AS_, BS: Boolean;
  PC, TC: Char;
  Two: string;

  function Merges: Boolean;
  begin
    Result := True;
    if (P.Kind in [tkIdent, tkKeyword, tkNumber]) and (T.Kind in [tkIdent, tkKeyword, tkNumber]) then Exit;
    if (P.Kind = tkString) and (TC in ['''', '#']) then Exit;
    if (P.Kind = tkString) and (PC <> '''') and (TC in ['0'..'9', 'A'..'F', 'a'..'f']) then Exit;
    Two := PC + TC;
    if (Two = '<>') or (Two = '<=') or (Two = '>=') or (Two = ':=') or (Two = '..') or (Two = '(*') or
      (Two = '*)') or (Two = '//') or (Two = '(.') or (Two = '.)') or (Two = '@@') then Exit;
    Result := False;
  end;

begin
  T := @FT[I];
  P := @FT[I - 1];
  Result := '';
  { asm: the source's own spacing }
  if T.InAsm and (P.InAsm or ((P.Kind = tkKeyword) and (P.Kw = kwAsm))) then
  begin
    if T.Sp then Result := Copy(FSrc, P.S + P.L + 1, T.S - P.S - P.L);
    Exit;
  end;
  PC := P.Text[Length(P.Text)];
  TC := T.Text[1];
  if T.Kind = tkComment then
  begin
    if T.IsDir then V := Ord(T.Sp)
    else if T.IsLineCmt then V := UseBefore(O[foCommentStartInlineSpaces])
    else if O[foCommentBracesSpaces] in [ioOuter, ioBoth] then V := 1
    else if O[foCommentBracesSpaces] = ioAsIs then V := 2
    else V := 0;
    if (V = 1) or ((V = 2) and T.Sp) or Merges then Result := ' ';
    Exit;
  end;
  if P.Kind = tkComment then
  begin
    if P.IsDir or ((T.Kind = tkSymbol) and (T.Sym in [syComma, sySemicolon, syRParen, syRBracket, syDot])) then
      V := Ord(T.Sp)
    else if O[foCommentBracesSpaces] in [ioOuter, ioBoth] then V := 1
    else if O[foCommentBracesSpaces] = ioAsIs then V := 2
    else V := 0;
    if (V = 1) or ((V = 2) and T.Sp) then Result := ' ';
    Exit;
  end;
  { what the token before wants after it }
  AS_ := True;
  case P.Kind of
    tkSymbol:
      case P.Sym of
        syComma: AV := UseAfter(O[foCommaSpaces]);
        sySemicolon: AV := UseAfter(O[foSemicolonSpaces]);
        syColon:
          if (P.Flags and tfFmtColon) <> 0 then AV := UseAfter(O[foColonInFormatSpaces])
          else AV := UseAfter(O[foColonSpaces]);
        syAssign: AV := UseAfter(O[foAssignSpaces]);
        syLParen:
          if (T.Kind = tkSymbol) and (T.Sym = syRParen) then AV := 0 else AV := O[foBracketSpaces];
        syLBracket:
          if (T.Kind = tkSymbol) and (T.Sym = syRBracket) then AV := 0 else AV := O[foSquareBracketSpaces];
        syDot, syAt: AV := 0;
        syCaret:
          if (P.Flags and tfPrefixCaret) <> 0 then AV := 0
          else
          begin
            AV := 1;
            AS_ := False;
          end;
        syPlus, syMinus:
          if (P.Flags and tfUnary) <> 0 then AV := UseAfter(O[foUnaryPreOperatorSpaces])
          else AV := UseAfter(O[foMathOperatorSpaces]);
        syEqual, syNotEqual, syLess, syLessEq, syGreater, syGreaterEq, syStar, sySlash, syDotDot:
          AV := UseAfter(O[foMathOperatorSpaces]);
        syOther:
          begin
            AV := 2;
            AS_ := False;
          end;
      else
        AV := 1;
        AS_ := False;
      end;
    tkKeyword:
      if P.Kw in WordOps then AV := UseAfter(O[foMathOperatorSpaces])
      else if P.Kw = kwNot then AV := UseAfter(O[foUnaryPreOperatorSpaces])
      else
      begin
        AV := 1;
        AS_ := False;
      end;
  else
    AV := 1;
    AS_ := False;
  end;
  { what the token wants before it }
  BS := True;
  case T.Kind of
    tkSymbol:
      case T.Sym of
        syComma: BV := UseBefore(O[foCommaSpaces]);
        sySemicolon: BV := UseBefore(O[foSemicolonSpaces]);
        syColon:
          if (T.Flags and tfFmtColon) <> 0 then BV := UseBefore(O[foColonInFormatSpaces])
          else BV := UseBefore(O[foColonSpaces]);
        syAssign: BV := UseBefore(O[foAssignSpaces]);
        syRParen:
          if (P.Kind = tkSymbol) and (P.Sym = syLParen) then BV := 0 else BV := O[foBracketSpaces];
        syRBracket:
          if (P.Kind = tkSymbol) and (P.Sym = syLBracket) then BV := 0 else BV := O[foSquareBracketSpaces];
        syDot: BV := 0;
        syLParen:
          if (T.Flags and tfFuncParen) <> 0 then
          begin
            case O[foSpaceAfterFunction] of
              saYes: BV := 1;
              saAsIs: BV := 2;
            else
              BV := 0;
            end;
          end
          else if (P.Kind = tkIdent) or ((P.Kind = tkSymbol) and (P.Sym in [syRParen, syRBracket, syCaret])) or
            ((P.Kind = tkKeyword) and (P.Kw in [kwClass, kwObject, kwInterface, kwDispinterface, kwProcedure,
            kwFunction])) then
            BV := 0
          else
          begin
            BV := 1;
            BS := False;
          end;
        syLBracket:
          if (P.Kind in [tkIdent, tkString]) or ((P.Kind = tkSymbol) and (P.Sym in [syRParen, syRBracket, syCaret])) then
            BV := 0
          else
          begin
            BV := 2;
            BS := False;
          end;
        syCaret:
          if (T.Flags and tfPrefixCaret) <> 0 then
          begin
            BV := 1;
            BS := False;
          end
          else
            BV := 0;
        syAt:
          begin
            BV := 1;
            BS := False;
          end;
        syPlus, syMinus:
          if (T.Flags and tfUnary) <> 0 then
          begin
            if P.Kind in [tkKeyword, tkIdent] then
            begin
              BV := 1;
              BS := False;
            end
            else
              BV := UseBefore(O[foUnaryPreOperatorSpaces]);
          end
          else
            BV := UseBefore(O[foMathOperatorSpaces]);
        syEqual, syNotEqual, syLess, syLessEq, syGreater, syGreaterEq, syStar, sySlash, syDotDot:
          BV := UseBefore(O[foMathOperatorSpaces]);
      else
        BV := 2;
        BS := False;
      end;
    tkKeyword:
      if T.Kw in WordOps then BV := UseBefore(O[foMathOperatorSpaces])
      else if (T.Kw = kwNot) and not (P.Kind in [tkKeyword, tkIdent]) then BV := UseBefore(O[foUnaryPreOperatorSpaces])
      else
      begin
        BV := 1;
        BS := False;
      end;
  else
    BV := 1;
    BS := False;
  end;
  if AV = 2 then AV := Ord(T.Sp);
  if BV = 2 then BV := Ord(T.Sp);
  if AS_ and BS then
  begin
    if AV = BV then V := AV
    else
      case O[foResolveSpaceConflictAs] of
        scNoSpace: V := 0;
        scSpace: V := 1;
      else
        V := Ord(T.Sp);
      end;
  end
  else if AS_ then V := AV
  else if BS then V := BV
  else if (AV = 0) or (BV = 0) then V := 0
  else V := 1;
  if (V = 1) or Merges then Result := ' ';
end;

function TPasFormatter.IndentStr(Col: Integer): string;
begin
  if Col < 0 then Col := 0;
  if O[foUseTabs] <> 0 then
    Result := StringOfChar(#9, Col div O[foTabSize]) + StringOfChar(' ', Col mod O[foTabSize])
  else
    Result := StringOfChar(' ', Col);
end;

procedure TPasFormatter.AddLine(const S: string; First: Integer);
begin
  if FLineCount >= Length(FLines) then
  begin
    SetLength(FLines, FLineCount * 2 + 64);
    SetLength(FLineFirst, FLineCount * 2 + 64);
  end;
  FLines[FLineCount] := S;
  FLineFirst[FLineCount] := First;
  Inc(FLineCount);
end;

function RightTrim(const S: string): string;
var
  N: Integer;
begin
  N := Length(S);
  while (N > 0) and (S[N] in [' ', #9]) do Dec(N);
  Result := Copy(S, 1, N);
end;

procedure TPasFormatter.Emit;
var
  I, K, Blanks, Delta, W, P, First: Integer;
  T: PFmtTok;
  Line, S, Part, Tail: string;
  Parts: TStringList;
  Starts, DirLine, PrevDirLine: Boolean;

  { Indent compiler directives off: a directive with no code after it on its line (in the output:
    a line break may have moved the code) goes to the left margin, an inline one stays }
  function DirectiveAlone(J: Integer): Boolean;
  var
    K: Integer;
  begin
    Result := False;
    K := J + 1;
    while (K <= FLast) and not Breaks(K) do
    begin
      if FT[K].Kind <> tkComment then Exit;
      Inc(K);
    end;
    Result := True;
  end;

  function IndentOf(J: Integer): Integer;
  begin
    if FT[J].IsDir and ((FT[J].Flags and tfAsm) = 0) and (O[foIndentCompilerDirectives] = 0) and DirectiveAlone(J) then
    begin
      Result := 0;
      Exit;
    end;
    Result := FT[J].Ind;
    if ((FT[J].Flags and (tfKeepCol or tfAsm)) = 0) and (O[foDoNotIndentAfterPos] > 0) and
      (Result > O[foDoNotIndentAfterPos]) then Result := O[foDoNotIndentAfterPos];
  end;

begin
  FLineCount := 0;
  SetLength(FTokLine, FCount);
  SetLength(FTokCol, FCount);
  if FCount = 0 then Exit;
  if O[foTrimSource] = 0 then
    for K := 1 to FT[0].NL do AddLine('', -1);
  Line := IndentStr(IndentOf(0));
  First := 0;
  PrevDirLine := FT[0].IsDir and DirectiveAlone(0);
  Parts := TStringList.Create;
  try
    for I := 0 to FLast do
    begin
      T := @FT[I];
      Starts := I = 0;
      if I > 0 then
        if Breaks(I) then
        begin
          AddLine(RightTrim(Line), First);
          Blanks := T.NL - 1;
          if Blanks < 0 then Blanks := 0;
          if Blanks > O[foMaxNumOfEmptyLines] then Blanks := O[foMaxNumOfEmptyLines];
          if Blanks < T.Blank then Blanks := T.Blank;
          { Number of empty lines around compiler directives: between a line of directives and code }
          DirLine := T.IsDir and ((T.Flags and tfAsm) = 0) and DirectiveAlone(I);
          if (DirLine <> PrevDirLine) and (Blanks < O[foNumOfEmptyLinesAroundCompilerDirectives]) then
            Blanks := O[foNumOfEmptyLinesAroundCompilerDirectives];
          PrevDirLine := DirLine;
          for K := 1 to Blanks do AddLine('', -1);
          Line := IndentStr(IndentOf(I));
          First := I;
          Starts := True;
        end
        else
          Line := Line + SpaceBefore(I);
      FTokLine[I] := FLineCount;
      FTokCol[I] := Length(Line);
      S := T.Text;
      if (T.Kind = tkComment) and ((Pos(#10, S) > 0) or (Pos(#13, S) > 0)) then
      begin
        { a comment over several lines: the lines after the first move with it }
        Parts.Text := S;
        if (S[Length(S)] in [#10, #13]) then Parts.Add('');
        if Starts and ((T.Flags and (tfKeepCol or tfAsm)) = 0) and ((I = 0) or (T.NL > 0)) then
          Delta := IndentOf(I) - T.SrcCol
        else
          Delta := 0;
        Line := Line + Parts[0];
        for K := 1 to Parts.Count - 1 do
        begin
          AddLine(RightTrim(Line), First);
          First := -1;
          Part := Parts[K];
          if Delta <> 0 then
          begin
            W := 0;
            P := 1;
            while (P <= Length(Part)) and (Part[P] in [' ', #9]) do
            begin
              if Part[P] = #9 then W := (W div O[foTabSize] + 1) * O[foTabSize] else Inc(W);
              Inc(P);
            end;
            if P <= Length(Part) then Part := IndentStr(MaxInt2(0, W + Delta)) + Copy(Part, P, MaxInt)
            else Part := '';
          end;
          Line := Part;
        end;
      end
      else
        Line := Line + S;
    end;
    AddLine(RightTrim(Line), First);
  finally
    Parts.Free;
  end;
  { what follows the last token written: blanks, or the text after "end." (kept as it is);
    Trim source: no blanks at the end, one line end }
  T := @FT[FLast];
  Tail := Copy(FSrc, T.S + T.L + 1, MaxInt);
  if O[foTrimSource] <> 0 then FTail := TrimRight(Tail) + FEol else FTail := Tail;
end;

{ the visual column of byte Pos (0-based) of line L (tabs expanded) }
function TPasFormatter.VisCol(L, Pos: Integer): Integer;
var
  K: Integer;
  S: string;
begin
  Result := 0;
  if L < 0 then Exit;
  S := FLines[L];
  for K := 1 to Pos do
    if (K <= Length(S)) and (S[K] = #9) then Result := (Result div O[foTabSize] + 1) * O[foTabSize]
    else Inc(Result);
end;

{ the token where the spaces of alignment K go on line L (-1: none) }
procedure TPasFormatter.AlignKind(K: Integer);
var
  L, M, G, N, NG, Target, C, Unaligned, Ind, J, Add, P: Integer;
  Group: array of Integer;
  Pads: array of Integer;

  function LineIndent(Line: Integer): Integer;
  begin
    Result := 0;
    while (Result < Length(FLines[Line])) and (FLines[Line][Result + 1] in [' ', #9]) do Inc(Result);
  end;

  { the token before which the spaces go, -1: the line has none }
  function PadTok(Line: Integer): Integer;
  var
    F, J2, Last: Integer;
  begin
    Result := -1;
    F := FLineFirst[Line];
    if F < 0 then Exit;
    Last := F;
    while (Last + 1 <= FLast) and (FTokLine[Last + 1] = Line) do Inc(Last);
    if K = akComment then
    begin
      if (Last > F) and (FT[Last].Kind = tkComment) and not FT[Last].IsDir and
        (FT[Last].Flags and tfAsm = 0) and (Pos(#10, FT[Last].Text) = 0) and (Pos(#13, FT[Last].Text) = 0) then
        Result := Last;
      Exit;
    end;
    if (FT[F].Flags and (tfItemStart or tfStmtStart)) = 0 then
    begin
      if K <> akProperty then Exit;
    end;
    for J2 := F to Last do
      if FT[J2].Align = K then
      begin
        case K of
          akTypeName, akParamType:
            if O[foAlignTypeColon] <> 0 then Result := J2
            else if (J2 + 1 <= Last) and (FT[J2 + 1].Kind <> tkComment) then Result := J2 + 1;
          akProperty:
            if J2 = F + 1 then Result := J2;
        else
          Result := J2;
        end;
        Exit;
      end;
  end;

begin
  L := 0;
  SetLength(Pads, FLineCount);
  SetLength(Group, FLineCount);
  while L < FLineCount do
  begin
    Pads[L] := PadTok(L);
    if Pads[L] < 0 then
    begin
      Inc(L);
      Continue;
    end;
    NG := 1;
    Group[0] := L;
    Ind := LineIndent(L);
    Unaligned := 0;
    M := L + 1;
    while M < FLineCount do
    begin
      Pads[M] := PadTok(M);
      if (Pads[M] >= 0) and ((K = akComment) or (LineIndent(M) = Ind)) then
      begin
        Group[NG] := M;
        Inc(NG);
        Unaligned := 0;
      end
      else
      begin
        Inc(Unaligned);
        if Unaligned > O[foAlignMaxUnalignedLines] then Break;
      end;
      Inc(M);
    end;
    if NG >= 2 then
    begin
      Target := -1;
      for G := 0 to NG - 1 do
      begin
        N := Group[G];
        C := VisCol(N, FTokCol[Pads[N]]);
        if ((O[foAlignMaxColumn] = 0) or (C <= O[foAlignMaxColumn])) and (C > Target) then Target := C;
      end;
      if Target >= 0 then
        for G := 0 to NG - 1 do
        begin
          N := Group[G];
          J := Pads[N];
          C := VisCol(N, FTokCol[J]);
          if C >= Target then Continue;
          Add := Target - C;
          P := FTokCol[J];
          Insert(StringOfChar(' ', Add), FLines[N], P + 1);
          while (J <= FLast) and (FTokLine[J] = N) do
          begin
            Inc(FTokCol[J], Add);
            Inc(J);
          end;
        end;
    end;
    L := Group[NG - 1] + 1;
  end;
end;

procedure TPasFormatter.AlignAll;
begin
  if O[foAlignTypeNames] <> 0 then AlignKind(akTypeName);
  if O[foAlignParameterTypes] <> 0 then AlignKind(akParamType);
  if O[foAlignInitializations] <> 0 then AlignKind(akInit);
  if O[foAlignConst] <> 0 then AlignKind(akConst);
  if O[foAlignTypeDefs] <> 0 then AlignKind(akTypeDef);
  if O[foAlignAssignments] <> 0 then AlignKind(akAssign);
  if O[foAlignProperties] <> 0 then AlignKind(akProperty);
  if O[foAlignEndOfLineComments] <> 0 then AlignKind(akComment);
end;

{ the output, and the edits between lines that start with the same token }
procedure TPasFormatter.BuildResult(SelStart, SelEnd: Integer; var R: TFmtResult);
var
  LineStart: array of Integer;
  I, K, N, NB, Len, SA, SB, OA, OB: Integer;
  SrcB, OutB: array of Integer;
  OutText: string;
  P: Integer;
  Take: Boolean;
begin
  { the text: the lines, a line end between them, then the tail }
  SetLength(LineStart, FLineCount + 1);
  Len := 0;
  for K := 0 to FLineCount - 1 do
  begin
    LineStart[K] := Len;
    Inc(Len, Length(FLines[K]));
    if K < FLineCount - 1 then Inc(Len, Length(FEol));
  end;
  LineStart[FLineCount] := Len;
  SetLength(OutText, Len);
  P := 1;
  for K := 0 to FLineCount - 1 do
  begin
    N := Length(FLines[K]);
    if N > 0 then Move(FLines[K][1], OutText[P], N);
    Inc(P, N);
    if K < FLineCount - 1 then
    begin
      Move(FEol[1], OutText[P], Length(FEol));
      Inc(P, Length(FEol));
    end;
  end;
  if FCount = 0 then OutText := FSrc else OutText := OutText + FTail;
  R.Output := OutText;
  { where the tokens are }
  SetLength(R.SrcPos, FLast + 1);
  SetLength(R.OutPos, FLast + 1);
  SetLength(R.TokLen, FLast + 1);
  for I := 0 to FLast do
  begin
    R.SrcPos[I] := FT[I].S;
    R.OutPos[I] := LineStart[FTokLine[I]] + FTokCol[I];
    R.TokLen[I] := FT[I].L;
  end;
  { the boundaries: lines that start with the same token in both texts }
  SetLength(SrcB, FLast + 3);
  SetLength(OutB, FLast + 3);
  SrcB[0] := 0;
  OutB[0] := 0;
  NB := 1;
  if FCount > 0 then
    for I := 0 to FLast do
      if ((I = 0) or (FT[I].NL > 0)) and (FLineFirst[FTokLine[I]] = I) then
      begin
        SA := LineStartOf(FSrc, FT[I].S);
        OA := LineStart[FTokLine[I]];
        if (SA <= SrcB[NB - 1]) or (OA < OutB[NB - 1]) then Continue;
        SrcB[NB] := SA;
        OutB[NB] := OA;
        Inc(NB);
      end;
  SrcB[NB] := Length(FSrc);
  OutB[NB] := Length(R.Output);
  Inc(NB);
  SetLength(R.Edits, NB);
  N := 0;
  for K := 0 to NB - 2 do
  begin
    SA := SrcB[K];
    SB := SrcB[K + 1];
    OA := OutB[K];
    OB := OutB[K + 1];
    { a selection takes the parts that share a line with it (a caret: the part it is in) }
    if SelStart >= 0 then
    begin
      if SelEnd > SelStart then Take := (SA < SelEnd) and (SB > SelStart)
      else Take := (SA <= SelStart) and ((SelStart < SB) or (SB = Length(FSrc)));
      if not Take then Continue;
    end;
    if (SB - SA = OB - OA) and CompareMem(PChar(FSrc) + SA, PChar(R.Output) + OA, SB - SA) then Continue;
    R.Edits[N].Start := SA;
    R.Edits[N].Len := SB - SA;
    R.Edits[N].Text := Copy(R.Output, OA + 1, OB - OA);
    R.Edits[N].OutStart := OA;
    Inc(N);
  end;
  SetLength(R.Edits, N);
end;

function TPasFormatter.Run(SelStart, SelEnd: Integer; var R: TFmtResult; var Error: string): Boolean;
var
  Line: Integer;
begin
  Error := '';
  Tokenize;
  MatchBrackets;
  Analyze;
  ApplyCase;
  Emit;
  AlignAll;
  BuildResult(SelStart, SelEnd, R);
  Result := FmtSameTokens(FSrc, R.Output, Line);
  if not Result then
  begin
    Error := Format('The formatter would change the code at line %d; the source is left as it is.', [Line]);
    SetLength(R.Edits, 0);
    R.Output := FSrc;
  end;
end;

function FormatPascal(const Source: string; const O: TFmtValues; SelStart, SelEnd: Integer;
  var R: TFmtResult; var Error: string): Boolean;
var
  F: TPasFormatter;
begin
  F := TPasFormatter.Create(Source, O);
  try
    Result := F.Run(SelStart, SelEnd, R, Error);
  finally
    F.Free;
  end;
end;

{ ------------------------------------------------------------------------------ form files }

function FormatDfm(const Source: string; var R: TFmtResult; var Error: string): Boolean;
var
  InS, OutS: TStringStream;
  Bin: TMemoryStream;
  S, Eol: string;
  A, B, OL, NL: Integer;
begin
  Result := False;
  Error := '';
  InS := TStringStream.Create(Source);
  Bin := TMemoryStream.Create;
  OutS := TStringStream.Create('');
  try
    try
      ObjectTextToBinary(InS, Bin);
      Bin.Position := 0;
      ObjectBinaryToText(Bin, OutS);
    except
      on E: Exception do
      begin
        Error := E.Message;
        Exit;
      end;
    end;
    S := OutS.DataString;
  finally
    OutS.Free;
    Bin.Free;
    InS.Free;
  end;
  { the line ends of the source }
  Eol := DetectEOL(Source);
  if Eol <> #13#10 then S := StringReplace(S, #13#10, Eol, [rfReplaceAll]);
  R.Output := S;
  { one edit: the changed middle }
  OL := Length(Source);
  NL := Length(S);
  A := 0;
  while (A < OL) and (A < NL) and (Source[A + 1] = S[A + 1]) do Inc(A);
  B := 0;
  while (B < OL - A) and (B < NL - A) and (Source[OL - B] = S[NL - B]) do Inc(B);
  SetLength(R.Edits, 0);
  SetLength(R.SrcPos, 0);
  SetLength(R.OutPos, 0);
  SetLength(R.TokLen, 0);
  if (A < OL - B) or (A < NL - B) then
  begin
    SetLength(R.Edits, 1);
    R.Edits[0].Start := A;
    R.Edits[0].Len := OL - B - A;
    R.Edits[0].Text := Copy(S, A + 1, NL - B - A);
    R.Edits[0].OutStart := A;
  end;
  Result := True;
end;

function FmtMapPos(const R: TFmtResult; Pos: Integer): Integer;
var
  K, Delta, T, Lo, Hi, Mid, Off: Integer;
  E: TFmtEdit;
begin
  Delta := 0;
  for K := 0 to High(R.Edits) do
  begin
    E := R.Edits[K];
    if Pos >= E.Start + E.Len then
    begin
      Inc(Delta, Length(E.Text) - E.Len);
      Continue;
    end;
    if Pos < E.Start then Break;
    { inside a changed part: by the token at or before the position }
    T := -1;
    Lo := 0;
    Hi := High(R.SrcPos);
    while Lo <= Hi do
    begin
      Mid := (Lo + Hi) div 2;
      if R.SrcPos[Mid] <= Pos then
      begin
        T := Mid;
        Lo := Mid + 1;
      end
      else
        Hi := Mid - 1;
    end;
    if (T < 0) or (R.SrcPos[T] < E.Start) then
      Off := 0
    else
    begin
      if Pos - R.SrcPos[T] <= R.TokLen[T] then Off := R.OutPos[T] - E.OutStart + Pos - R.SrcPos[T]
      else Off := R.OutPos[T] - E.OutStart + R.TokLen[T];
      if Off > Length(E.Text) then Off := Length(E.Text);
      if Off < 0 then Off := 0;
    end;
    Result := E.Start + Delta + Off;
    Exit;
  end;
  Result := Pos + Delta;
end;

end.
