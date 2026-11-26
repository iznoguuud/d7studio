{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdFormatterFrame;

{ D7 Studio - Tools | Formatter Options: RAD Studio's Delphi formatter
  options on its pages - Indentation, Spaces, Line Breaks, Statements, Empty Lines,
  Capitalization, Align, with its captions, in group boxes as Delphi's own option pages -, D7
  Studio's own (General); below them (Footer) the presets and Preview: a window with a sample
  formatted with the values shown, again at each change (SdFormatterPreview). The controls are
  named after the options (cb / cx / ed + RAD Studio's name: a check box, a list, a number with
  its up-down ud...), so that one loop over SdFormatter's table fills and reads them. The section
  edits a copy; OK gives it back. A frame: the section Formatter Options of the Options dialog
  (SdOptionsDlg), its pages without tabs. }

interface

uses
  Windows, SysUtils, Classes, Forms, StdCtrls, ComCtrls, ExtCtrls,
  ActnList, SdFormatter, SdFormatterPreview;

type
  TFormatterFrame = class(TFrame)
    PageControl: TPageControl;
    tsIndentation: TTabSheet;
    gbIndentation: TGroupBox;
    gbIndent: TGroupBox;
    lbTabSize: TLabel;
    edTabSize: TEdit;
    udTabSize: TUpDown;
    lbIndentSize: TLabel;
    edIndentSize: TEdit;
    udIndentSize: TUpDown;
    lbContinuationIndent: TLabel;
    edContinuationIndent: TEdit;
    udContinuationIndent: TUpDown;
    lbDoNotIndentAfterPos: TLabel;
    edDoNotIndentAfterPos: TEdit;
    udDoNotIndentAfterPos: TUpDown;
    lbIndentComments: TLabel;
    cxIndentComments: TComboBox;
    lbDecreaseLabelsIndent: TLabel;
    cxDecreaseLabelsIndent: TComboBox;
    cbUseTabs: TCheckBox;
    cbIndentAsm: TCheckBox;
    cbIndentCompilerDirectives: TCheckBox;
    cbIndentBlockContents: TCheckBox;
    cbIndentBeginAndEnd: TCheckBox;
    cbIndentFunctionImplementationBody: TCheckBox;
    cbIndentInnerFunctionImplementation: TCheckBox;
    cbIndentAfterSections: TCheckBox;
    cbIndentClassDefinitionBody: TCheckBox;
    cbIndentBrackets: TCheckBox;
    cbIndentCaseContents: TCheckBox;
    cbIndentCaseLabels: TCheckBox;
    cbExtraIndentAfterElseInCase: TCheckBox;
    tsSpaces: TTabSheet;
    lbAssignSpaces: TLabel;
    cxAssignSpaces: TComboBox;
    lbMathOperatorSpaces: TLabel;
    cxMathOperatorSpaces: TComboBox;
    lbUnaryPreOperatorSpaces: TLabel;
    cxUnaryPreOperatorSpaces: TComboBox;
    lbColonSpaces: TLabel;
    cxColonSpaces: TComboBox;
    lbColonInFormatSpaces: TLabel;
    cxColonInFormatSpaces: TComboBox;
    lbCommaSpaces: TLabel;
    cxCommaSpaces: TComboBox;
    lbSemicolonSpaces: TLabel;
    cxSemicolonSpaces: TComboBox;
    lbCommentStartInlineSpaces: TLabel;
    cxCommentStartInlineSpaces: TComboBox;
    lbCommentBracesSpaces: TLabel;
    cxCommentBracesSpaces: TComboBox;
    lbSpaceAfterFunction: TLabel;
    cxSpaceAfterFunction: TComboBox;
    lbResolveSpaceConflictAs: TLabel;
    cxResolveSpaceConflictAs: TComboBox;
    cbBracketSpaces: TCheckBox;
    cbSquareBracketSpaces: TCheckBox;
    tsLineBreaks: TTabSheet;
    gbLineBreaks: TGroupBox;
    gbLineBreakLists: TGroupBox;
    cbKeepUserLinebreaks: TCheckBox;
    cbTrimSource: TCheckBox;
    cbNewLineAfterSemicolon: TCheckBox;
    cbNewLineBeforeThen: TCheckBox;
    cbNewLineBetweenElseAndIf: TCheckBox;
    cbNewLineInPropertyDeclaration: TCheckBox;
    cbRemoveNewLinesInEndElseBegin: TCheckBox;
    cbRemoveNewLinesInEndElseIf: TCheckBox;
    lbNewLineAfterLabel: TLabel;
    cxNewLineAfterLabel: TComboBox;
    lbNewLineForEachVarAndConstElement: TLabel;
    cxNewLineForEachVarAndConstElement: TComboBox;
    lbNewLineAfterUses: TLabel;
    cxNewLineAfterUses: TComboBox;
    lbNewLineForEachUseElement: TLabel;
    cxNewLineForEachUseElement: TComboBox;
    lbNewLineForEachLabelElement: TLabel;
    cxNewLineForEachLabelElement: TComboBox;
    lbNewLineInClassInheritances: TLabel;
    cxNewLineInClassInheritances: TComboBox;
    lbFormatArrayInitialization: TLabel;
    cxFormatArrayInitialization: TComboBox;
    tsStatements: TTabSheet;
    lbNewLineBeforeBeginInControlBlock: TLabel;
    cxNewLineBeforeBeginInControlBlock: TComboBox;
    lbNewLineAfterBeginInControlBlock: TLabel;
    cxNewLineAfterBeginInControlBlock: TComboBox;
    lbNewLineAfterBeginInMethodDefinition: TLabel;
    cxNewLineAfterBeginInMethodDefinition: TComboBox;
    lbNewLineAfterOtherBegin: TLabel;
    cxNewLineAfterOtherBegin: TComboBox;
    lbNewLineBeforeSimpleInstructionInControlBlock: TLabel;
    cxNewLineBeforeSimpleInstructionInControlBlock: TComboBox;
    lbNewLineBeforeSimpleInstructionInTryCatchBlock: TLabel;
    cxNewLineBeforeSimpleInstructionInTryCatchBlock: TComboBox;
    lbNewLineParamTypesInFunction: TLabel;
    cxNewLineParamTypesInFunction: TComboBox;
    lbNewLineParamValuesInFunction: TLabel;
    cxNewLineParamValuesInFunction: TComboBox;
    lbNewLineFunctionType: TLabel;
    cxNewLineFunctionType: TComboBox;
    tsEmptyLines: TTabSheet;
    lbMaxNumOfEmptyLines: TLabel;
    edMaxNumOfEmptyLines: TEdit;
    udMaxNumOfEmptyLines: TUpDown;
    lbNumOfEmptyLinesAsSeparatorInInterfaceSection: TLabel;
    edNumOfEmptyLinesAsSeparatorInInterfaceSection: TEdit;
    udNumOfEmptyLinesAsSeparatorInInterfaceSection: TUpDown;
    lbNumOfEmptyLinesAsSeparatorInImplementationSection: TLabel;
    edNumOfEmptyLinesAsSeparatorInImplementationSection: TEdit;
    udNumOfEmptyLinesAsSeparatorInImplementationSection: TUpDown;
    lbNumOfEmptyLinesBeforeSubsection: TLabel;
    edNumOfEmptyLinesBeforeSubsection: TEdit;
    udNumOfEmptyLinesBeforeSubsection: TUpDown;
    lbNumOfEmptyLinesBeforeTypeKeyword: TLabel;
    edNumOfEmptyLinesBeforeTypeKeyword: TEdit;
    udNumOfEmptyLinesBeforeTypeKeyword: TUpDown;
    lbNumOfEmptyLinesBeforeVisibility: TLabel;
    edNumOfEmptyLinesBeforeVisibility: TEdit;
    udNumOfEmptyLinesBeforeVisibility: TUpDown;
    lbNumOfEmptyLinesAroundSectionKeyword: TLabel;
    edNumOfEmptyLinesAroundSectionKeyword: TEdit;
    udNumOfEmptyLinesAroundSectionKeyword: TUpDown;
    lbNumOfEmptyLinesAroundCompilerDirectives: TLabel;
    edNumOfEmptyLinesAroundCompilerDirectives: TEdit;
    udNumOfEmptyLinesAroundCompilerDirectives: TUpDown;
    tsCapitalization: TTabSheet;
    lbKeywordsCapitalization: TLabel;
    cxKeywordsCapitalization: TComboBox;
    lbCompilerDirectivesCapitalization: TLabel;
    cxCompilerDirectivesCapitalization: TComboBox;
    lbNumbersCapitalization: TLabel;
    cxNumbersCapitalization: TComboBox;
    lbOtherWordsCapitalization: TLabel;
    cxOtherWordsCapitalization: TComboBox;
    tsAlign: TTabSheet;
    gbAlign: TGroupBox;
    gbAlignLimits: TGroupBox;
    cbAlignAssignments: TCheckBox;
    cbAlignConst: TCheckBox;
    cbAlignTypeDefs: TCheckBox;
    cbAlignInitializations: TCheckBox;
    cbAlignTypeNames: TCheckBox;
    cbAlignTypeColon: TCheckBox;
    cbAlignParameterTypes: TCheckBox;
    cbAlignProperties: TCheckBox;
    cbAlignEndOfLineComments: TCheckBox;
    lbAlignMaxColumn: TLabel;
    edAlignMaxColumn: TEdit;
    udAlignMaxColumn: TUpDown;
    lbAlignMaxUnalignedLines: TLabel;
    edAlignMaxUnalignedLines: TEdit;
    udAlignMaxUnalignedLines: TUpDown;
    tsGeneral: TTabSheet;
    gbGeneral: TGroupBox;
    gbRadProfile: TGroupBox;
    cbFormatOnSave: TCheckBox;
    cbConfirm: TCheckBox;
    cbFormFiles: TCheckBox;
    Footer: TPanel;
    lbPreset: TLabel;
    cxPreset: TComboBox;
    btnPreset: TButton;
    Actions: TActionList;
    aPreset: TAction;
    lbRadProfile: TLabel;
    btnImport: TButton;
    btnExport: TButton;
    btnSaveAs: TButton;
    btnDeletePreset: TButton;
    aSaveAs: TAction;
    aDeletePreset: TAction;
    aImport: TAction;
    aExport: TAction;
    btnPreview: TButton;
    aPreview: TAction;
    procedure OptionChanged(Sender: TObject);
    procedure PresetSelect(Sender: TObject);
    procedure aPresetExecute(Sender: TObject);
    procedure aPresetUpdate(Sender: TObject);
    procedure aSaveAsExecute(Sender: TObject);
    procedure aDeletePresetExecute(Sender: TObject);
    procedure aDeletePresetUpdate(Sender: TObject);
    procedure aImportExecute(Sender: TObject);
    procedure aExportExecute(Sender: TObject);
    procedure aPreviewExecute(Sender: TObject);
  private
    FPreview: TFormatterPreview;      // made when Preview is first pressed
    FLoading: Boolean;
    { the presets into the list; Select: the one chosen, '' the one the values shown match }
    procedure FillPresets(const Select: string);
    procedure MatchPreset;
    procedure MatchValues(const V: TFmtValues);
    function ChosenPreset: string;
    procedure LoadValues(const V: TFmtValues);
    procedure SaveValues(var V: TFmtValues);
    function ValuesShown: TFmtValues;
    procedure UpdatePreview;
    procedure ValuesChanged;
  public
    constructor Create(AOwner: TComponent); override;
    { the lists filled and the values shown, once, when the section is first shown; the values
      given back after OK }
    procedure LoadOptions;
    procedure SaveOptions;
  end;

implementation

{$R *.dfm}

uses
  SdUI, SdFormatterOptions, SdDialogs;

const
  ProfileFilter = 'RAD Studio formatter profiles (*.config)|*.config|All files (*.*)|*.*';

{ laid out for the UI font only: LoadOptions fills it when the section is first shown }
constructor TFormatterFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  UIPrepareFrame(Self);
end;

procedure TFormatterFrame.LoadOptions;
var
  F: TFmtOption;
  C: TComponent;
begin
  for F := Low(F) to High(F) do
    case FmtOptionInfo[F].Kind of
      vkBool: ;
      vkInt:
        begin
          { an up-down writes its position into its edit when it gets its window: give it one first }
          C := FindComponent('ud' + FmtOptionInfo[F].Key);
          (C as TUpDown).HandleNeeded;
        end;
    else
      C := FindComponent('cx' + FmtOptionInfo[F].Key);
      FmtValueCaptions(FmtOptionInfo[F].Kind, (C as TComboBox).Items);
    end;
  FillPresets('');
  LoadValues(FormatterOptions.Values);
  cbFormatOnSave.Checked := FormatterOptions.FormatOnSave;
  cbConfirm.Checked := FormatterOptions.Confirm;
  cbFormFiles.Checked := FormatterOptions.FormFiles;
end;

procedure TFormatterFrame.SaveOptions;
begin
  SaveValues(FormatterOptions.Values);
  FormatterOptions.FormatOnSave := cbFormatOnSave.Checked;
  FormatterOptions.Confirm := cbConfirm.Checked;
  FormatterOptions.FormFiles := cbFormFiles.Checked;
end;

procedure TFormatterFrame.FillPresets(const Select: string);
begin
  FmtPresetNames(cxPreset.Items);
  if Select <> '' then cxPreset.ItemIndex := cxPreset.Items.IndexOf(Select)
  else MatchPreset;
end;

{ the list shows the preset the values shown are (none when they are no preset's) }
procedure TFormatterFrame.MatchPreset;
begin
  MatchValues(ValuesShown);
end;

{ ... the preset that V, the values shown, are }
procedure TFormatterFrame.MatchValues(const V: TFmtValues);
var
  P: TFmtValues;
  I: Integer;
  F: TFmtOption;
  Same: Boolean;
begin
  for I := 0 to cxPreset.Items.Count - 1 do
    if FmtPresetByName(cxPreset.Items[I], P) then
    begin
      Same := True;
      for F := Low(F) to High(F) do
        if P[F] <> V[F] then
        begin
          Same := False;
          Break;
        end;
      if Same then
      begin
        cxPreset.ItemIndex := I;
        Exit;
      end;
    end;
  cxPreset.ItemIndex := -1;
end;

function TFormatterFrame.ChosenPreset: string;
begin
  if cxPreset.ItemIndex >= 0 then Result := cxPreset.Items[cxPreset.ItemIndex] else Result := '';
end;

procedure TFormatterFrame.LoadValues(const V: TFmtValues);
var
  F: TFmtOption;
  Key: string;
begin
  FLoading := True;
  try
    for F := Low(F) to High(F) do
    begin
      Key := FmtOptionInfo[F].Key;
      case FmtOptionInfo[F].Kind of
        vkBool: (FindComponent('cb' + Key) as TCheckBox).Checked := V[F] <> 0;
        vkInt: (FindComponent('ud' + Key) as TUpDown).Position := V[F];
      else
        (FindComponent('cx' + Key) as TComboBox).ItemIndex := V[F];
      end;
    end;
  finally
    FLoading := False;
  end;
  ValuesChanged;
end;

procedure TFormatterFrame.SaveValues(var V: TFmtValues);
var
  F: TFmtOption;
  Key: string;
  N: Integer;
begin
  for F := Low(F) to High(F) do
  begin
    Key := FmtOptionInfo[F].Key;
    case FmtOptionInfo[F].Kind of
      vkBool: V[F] := Ord((FindComponent('cb' + Key) as TCheckBox).Checked);
      vkInt:
        begin
          N := StrToIntDef(Trim((FindComponent('ed' + Key) as TEdit).Text), V[F]);
          if N < FmtOptionInfo[F].Min then N := FmtOptionInfo[F].Min;
          if N > FmtOptionInfo[F].Max then N := FmtOptionInfo[F].Max;
          V[F] := N;
        end;
    else
      N := (FindComponent('cx' + Key) as TComboBox).ItemIndex;
      if N >= 0 then V[F] := N;
    end;
  end;
end;

{ the values the pages show: the formatter options with the controls' values }
function TFormatterFrame.ValuesShown: TFmtValues;
begin
  Result := FormatterOptions.Values;
  SaveValues(Result);
end;

{ the preview window, while it is open, with the values shown }
procedure TFormatterFrame.UpdatePreview;
begin
  if FLoading or (FPreview = nil) or not FPreview.Visible then Exit;
  FPreview.ShowValues(ValuesShown);
end;

{ a value shown changed: the preview and the preset - the values read from the controls once }
procedure TFormatterFrame.ValuesChanged;
var
  V: TFmtValues;
begin
  V := ValuesShown;
  if not FLoading and (FPreview <> nil) and FPreview.Visible then FPreview.ShowValues(V);
  MatchValues(V);
end;

{ Preview...: the window beside the dialog (made the first time), brought up to date }
procedure TFormatterFrame.aPreviewExecute(Sender: TObject);
begin
  if FPreview = nil then FPreview := TFormatterPreview.CreateFor(Self, GetParentForm(Self));
  FPreview.ShowBeside;
  UpdatePreview;
end;

procedure TFormatterFrame.OptionChanged(Sender: TObject);
begin
  if FLoading then Exit;
  ValuesChanged;
end;

{ choosing a preset loads it, as Load does }
procedure TFormatterFrame.PresetSelect(Sender: TObject);
begin
  aPreset.Execute;
end;

procedure TFormatterFrame.aPresetExecute(Sender: TObject);
var
  V: TFmtValues;
  Name: string;
begin
  Name := ChosenPreset;
  if not FmtPresetByName(Name, V) then Exit;
  LoadValues(V);
  cxPreset.ItemIndex := cxPreset.Items.IndexOf(Name);
end;

procedure TFormatterFrame.aPresetUpdate(Sender: TObject);
begin
  aPreset.Enabled := cxPreset.ItemIndex >= 0;
end;

{ the values shown as a preset of the user's: a new one or over one of the user's (asked); the
  built-in ones stay as they are }
procedure TFormatterFrame.aSaveAsExecute(Sender: TObject);
var
  Name: string;
begin
  if FmtIsUserPreset(ChosenPreset) then Name := ChosenPreset else Name := '';
  if not InputDialog(Self, 'Save Preset', '&Name of the preset:', Name) then Exit;
  Name := Trim(Name);
  if Name = '' then Exit;
  if FmtIsBuiltinPreset(Name) then
  begin
    MessageBox(GetParentForm(Self).Handle, PChar(Format('%s is a preset of D7 Studio and cannot be overwritten. Choose ' +
      'another name.', [Name])), 'Formatter Options', MB_OK or MB_ICONWARNING);
    Exit;
  end;
  if FmtIsUserPreset(Name) and (MessageBox(GetParentForm(Self).Handle, PChar(Format('The preset %s exists. Overwrite it?',
    [Name])), 'Formatter Options', MB_YESNO or MB_ICONQUESTION) <> IDYES) then Exit;
  SaveUserPreset(Name, ValuesShown);
  FillPresets(Name);
end;

procedure TFormatterFrame.aDeletePresetExecute(Sender: TObject);
var
  Name: string;
begin
  Name := ChosenPreset;
  if not FmtIsUserPreset(Name) then Exit;
  if MessageBox(GetParentForm(Self).Handle, PChar(Format('Delete the preset %s?', [Name])), 'Formatter Options',
    MB_YESNO or MB_ICONQUESTION) <> IDYES then Exit;
  DeleteUserPreset(Name);
  FillPresets('');
end;

procedure TFormatterFrame.aDeletePresetUpdate(Sender: TObject);
begin
  aDeletePreset.Enabled := FmtIsUserPreset(ChosenPreset);
end;

{ RAD Studio's profiles: the values shown read from one (what it does not have stays) or written }
procedure TFormatterFrame.aImportExecute(Sender: TObject);
var
  F, Err: string;
  V: TFmtValues;
begin
  F := '';
  if not BrowseFile('Import Formatter Profile', ProfileFilter, F, bfOpen, 'config') then Exit;
  V := ValuesShown;
  if ImportRadProfile(F, V, Err) then LoadValues(V)
  else MessageBox(GetParentForm(Self).Handle, PChar(Err), 'Formatter Options', MB_OK or MB_ICONWARNING);
end;

procedure TFormatterFrame.aExportExecute(Sender: TObject);
var
  F: string;
begin
  F := 'Formatter.config';
  if not BrowseFile('Export Formatter Profile', ProfileFilter, F, bfSave, 'config') then Exit;
  ExportRadProfile(F, ValuesShown);
end;

end.
