{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdEnvOptions;

{ D7 Studio - the values of Tools | Environment Options (Delphi 7's pages) and
  where they are kept ([Environment] ... in D7Studio.ini). The parts of the IDE read them here.
  The grid of the form designer stays in DesignEnv (SdFormDesigner), "Show compiler progress"
  in SdSettings. The library folders start as Delphi 7's defaults in Delphi's folder
  (SdDelphiDir); migrate.exe copies Delphi 7's own into the settings when D7 Studio is installed. }

interface

uses
  Windows, SysUtils, Classes, Graphics, SdMetrics;

type
  { a program of Tools | Configure Tools (Delphi's "Transfer" items) }
  TTransferTool = record
    Title, Path, WorkingDir, Params: string;
  end;
  TTransferTools = array of TTransferTool;

  { the colours of the Object Inspector (Environment Options | Object Inspector | Colors) }
  TOIColor = (ocBackground, ocGutter, ocCategory, ocName, ocValue, ocNonDefault, ocReference,
    ocReadOnly);

  { the categories of Environment Options | Explorer, Delphi 7's (its key Code Explorer: <Key>Visible
    - a folder -, <Key>Expand - the folder starts open -, CategorySort - their order). The last four
    are the Browser's }
  TExpCategory = (ecPrivate, ecProtected, ecPublic, ecPublished, ecFields, ecProperties, ecMethods,
    ecClasses, ecInterfaces, ecProcedures, ecTypes, ecVariables, ecUses, ecVirtuals, ecStatics,
    ecInherited, ecIntroduced);
  TExpCategories = array of TExpCategory;

  TSdEnvOptions = class
  public
    { Preferences }
    AutosaveEditor, AutosaveDesktop, DesktopSymbols, AutoDragDocking: Boolean;
    WarnPackageRebuild, MinimizeOnRun: Boolean;
    ShowCompilerProgress: Boolean;    // the modal "Compiling" dialog
    AutoCloseCompilerProgress: Boolean;   // ... closes by itself after every successful compile
    RepositoryDir: string;
    CheckForUpdates: Boolean;         // a check for a newer release once a day at start-up (SdUpdate)
    { Designer (grid, snap and component captions: DesignEnv) }
    ShowDesignerHints, ShowExtendedHints, NewFormsAsText, AutoCreateForms: Boolean;
    { Object Inspector }
    OIShowInstanceList, OIShowClassNames, OIShowStatusBar, OIRenderGrid, OIIntegralHeight,
    OIShowReadOnly, OIBoldNonDefault, OIRefExpand, OIRefOnEvents: Boolean;
    OIColors: array[TOIColor] of TColor;
    OISpeedSetting: Integer;
    { Library }
    LibraryPath, BplOutputDir, DcpOutputDir, BrowsingPath: string;
    { Explorer (the Code Explorer; the Browser's view and scope) }
    ExAutoShow, ExHighlightIncomplete, ExShowSyntax, ExSortAlpha, ExFinishProperties: Boolean;
    ExSyncEditor: Boolean;              // the Code Explorer and the editor follow each other (D7 Studio's)
    ExBrowserView, ExBrowserScope: Integer;
    ExCategorySort: string;             // every category's key in their order, ';' separated
    ExVisible, ExExpand: array[TExpCategory] of Boolean;
    { Type Library }
    TLSafeCall: Integer;
    TLIgnoreFlags: Boolean;
    TLFlags: array[0..3] of Boolean;    // Predefined, Restricted, Hidden, Can Create
    { Environment Variables: the user's overrides (Name=Value) }
    VarOverrides: TStringList;
    { Components (D7 Studio's view of the palette; kept in [Components] as before) }
    CompClassic, CompHideCategory: Boolean;
    CompSort: Integer;                  // SdCompBar.TSdCompSort (Component Bar's sort modes)
    CompResetDelay: Integer;            // seconds after which typing in the list starts a new filter
    CompColor: TColor;                  // the list's colour (clDefault: the look's)
    CompHotkey: Word;                   // the shortcut of View | Components (0: none)
    { Metrics (D7 Studio's: Project | Metrics; [Metrics], a key per metric - on, aggregation, limits) }
    Metrics: TMetricSettings;
    MetricOpts: TMetricOptions;
    constructor Create;
    destructor Destroy; override;
    procedure Load;
    { into the settings and the settings file; False: the file could not be written - the
      reason is SdSettings.SettingsSaveError (the values are kept and written again later) }
    function Save: Boolean;
    { sets the overridden variables in the environment of D7 Studio - the programs it starts and
      the compiler inherit them; the original values are restored for variables no longer
      overridden }
    procedure ApplyVariables;
  end;

const
  OIColorNames: array[TOIColor] of string = ('Background', 'Gutter', 'Category', 'Property name',
    'Value', 'Non-default value', 'Reference', 'Read-only property');
  { the Object Inspector colours of Delphi 7 (Default colors and settings) }
  DefaultOIColors: array[TOIColor] of TColor = (clBtnFace, clBtnFace, clMaroon, clBtnText,
    clNavy, clNavy, clMaroon, clGrayText);
  { the categories' keys (Delphi's: CategorySort, <Key>Visible, <Key>Expand) }
  ExpCategoryKeys: array[TExpCategory] of string = ('Private', 'Protected', 'Public', 'Published',
    'Fields', 'Properties', 'Methods', 'Classes', 'Interfaces', 'Procedures', 'Types', 'Variables',
    'Uses', 'Virtuals', 'Statics', 'Inherited', 'Introduced');
  { their rows in Environment Options | Explorer (Delphi's labels: "Field" in the singular) }
  ExpCategoryLabels: array[TExpCategory] of string = ('Private', 'Protected', 'Public', 'Published',
    'Field', 'Properties', 'Methods', 'Classes', 'Interfaces', 'Procedures', 'Types',
    'Variables/Constants', 'Uses', 'Virtuals', 'Statics', 'Inherited', 'Introduced');
  { their folders in the Code Explorer }
  ExpCategoryCaptions: array[TExpCategory] of string = ('Private', 'Protected', 'Public', 'Published',
    'Fields', 'Properties', 'Methods', 'Classes', 'Interfaces', 'Procedures', 'Types',
    'Variables/Constants', 'Uses', 'Virtuals', 'Statics', 'Inherited', 'Introduced');
  { the rows in bold: their folders come first where an item could go into two }
  ExpBoldCategories = [ecPrivate, ecProtected, ecPublic, ecPublished];
  { Delphi 7's defaults: every category a folder but Classes (and three of the Browser's), every
    folder closed (but three of the Browser's) }
  DefaultExpVisible: array[TExpCategory] of Boolean = (True, True, True, True, True, True, True,
    False, True, True, True, True, True, False, False, True, False);
  DefaultExpExpand: array[TExpCategory] of Boolean = (False, False, False, False, False, False, False,
    False, False, False, False, False, False, True, True, False, True);
  DefaultExpCategorySort = 'Private;Protected;Public;Published;Fields;Properties;Methods;Classes;' +
    'Interfaces;Procedures;Types;Variables;Uses;Virtuals;Statics;Inherited;Introduced';

var
  EnvOptions: TSdEnvOptions;

{ the categories in the order of a CategorySort text: its keys (case-insensitive; an unknown one
  and a repeated one skipped), then those it does not name in their declared order }
function ExpSortedCategories(const Sort: string): TExpCategories;
{ ... and back: their keys, ';' separated }
function ExpSortText(const Order: TExpCategories): string;

{ a path of the options as Windows knows it: $(DELPHI), $(BDS) and $(NAME) of any environment
  variable expanded }
function ExpandPathMacros(const S: string): string;
{ the environment of the system (Name=Value), as it was before D7 Studio's overrides }
procedure GetSystemVariables(List: TStrings);
{ the folders of a ';' separated path list, macros expanded, added to List once each; with a
  BaseDir the relative ones become full paths from it }
procedure AddPathList(List: TStrings; const Paths: string; const BaseDir: string = '');

{ Tools | Configure Tools: the programs of the Tools menu ([Transfer] of D7Studio.ini).
  GetTransferTools: Title=index. }
procedure GetTransferTools(List: TStrings);
function ReadTransferTool(Index: Integer; var Tool: TTransferTool): Boolean;
procedure WriteTransferTools(const Tools: array of TTransferTool);
{ Tool Options' Export and Import: tools in a file of their own, in the settings' [Transfer] format.
  ImportTransferTools adds the file's tools to Tools, each one Tools does not hold already, and returns
  how many it added (-1: the file holds no tools) }
procedure ExportTransferTools(const FileName: string; const Tools: array of TTransferTool);
function ImportTransferTools(const FileName: string; var Tools: TTransferTools): Integer;

implementation

uses
  IniFiles, SdSettings, SdDelphiDir, SdProject;

const
  Sec = 'Environment';
  CompSec = 'Components';
  MetricSec = 'Metrics';

function ExpSortedCategories(const Sort: string): TExpCategories;
var
  Taken: array[TExpCategory] of Boolean;
  C: TExpCategory;
  N: Integer;
  Rest, Key: string;

  procedure Take(Cat: TExpCategory);
  begin
    Taken[Cat] := True;
    Result[N] := Cat;
    Inc(N);
  end;

begin
  SetLength(Result, Ord(High(TExpCategory)) + 1);
  for C := Low(TExpCategory) to High(TExpCategory) do Taken[C] := False;
  N := 0;
  Rest := Sort;
  while Rest <> '' do
  begin
    Key := Trim(Copy(Rest, 1, Pos(';', Rest + ';') - 1));
    Delete(Rest, 1, Pos(';', Rest + ';'));
    for C := Low(TExpCategory) to High(TExpCategory) do
      if not Taken[C] and SameText(Key, ExpCategoryKeys[C]) then
      begin
        Take(C);
        Break;
      end;
  end;
  for C := Low(TExpCategory) to High(TExpCategory) do
    if not Taken[C] then Take(C);
end;

function ExpSortText(const Order: TExpCategories): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Order) do
  begin
    if I > 0 then Result := Result + ';';
    Result := Result + ExpCategoryKeys[Order[I]];
  end;
end;

function ExpandPathMacros(const S: string): string;
var
  I, Q: Integer;
  Src: string;
begin
  Src := ExpandDelphiMacros(S);
  Result := '';
  I := 1;
  while I <= Length(Src) do
  begin
    if (Src[I] = '$') and (I < Length(Src)) and (Src[I + 1] = '(') then
    begin
      Q := I + 2;
      while (Q <= Length(Src)) and (Src[Q] <> ')') do Inc(Q);
      if Q <= Length(Src) then
      begin
        Result := Result + GetEnvironmentVariable(Copy(Src, I + 2, Q - I - 2));
        I := Q + 1;
        Continue;
      end;
    end;
    Result := Result + Src[I];
    Inc(I);
  end;
end;

procedure AddPathList(List: TStrings; const Paths: string; const BaseDir: string = '');
var
  L: TStringList;
  I: Integer;
  D: string;
begin
  L := TStringList.Create;
  try
    { split at ';' only (DelimitedText of Delphi 7 also splits at blanks: "Program Files") }
    L.Text := StringReplace(ExpandPathMacros(Paths), ';', #13#10, [rfReplaceAll]);
    for I := 0 to L.Count - 1 do
    begin
      D := ExcludeTrailingPathDelimiter(Trim(L[I]));
      if (D <> '') and (BaseDir <> '') and not IsAbsolutePath(D) then
        D := ExcludeTrailingPathDelimiter(ExpandFileName(IncludeTrailingPathDelimiter(BaseDir) + D));
      if (D <> '') and (List.IndexOf(D) < 0) then List.Add(D);
    end;
  finally
    L.Free;
  end;
end;

{ --- Tools | Configure Tools --- }

const
  TransferSec = 'Transfer';

function ReadToolFrom(Ini: TCustomIniFile; Index: Integer; var Tool: TTransferTool): Boolean;
var
  S: string;
begin
  Result := (Index >= 0) and (Index < Ini.ReadInteger(TransferSec, 'Count', 0));
  if not Result then Exit;
  S := IntToStr(Index);
  Tool.Title := Ini.ReadString(TransferSec, 'Title' + S, '');
  Tool.Path := Ini.ReadString(TransferSec, 'Path' + S, '');
  Tool.WorkingDir := Ini.ReadString(TransferSec, 'WorkingDir' + S, '');
  Tool.Params := Ini.ReadString(TransferSec, 'Params' + S, '');
end;

procedure WriteToolsTo(Ini: TCustomIniFile; const Tools: array of TTransferTool);
var
  I: Integer;
  S: string;
begin
  Ini.EraseSection(TransferSec);
  Ini.WriteInteger(TransferSec, 'Count', Length(Tools));
  for I := 0 to High(Tools) do
  begin
    S := IntToStr(I);
    Ini.WriteString(TransferSec, 'Title' + S, Tools[I].Title);
    Ini.WriteString(TransferSec, 'Path' + S, Tools[I].Path);
    Ini.WriteString(TransferSec, 'WorkingDir' + S, Tools[I].WorkingDir);
    Ini.WriteString(TransferSec, 'Params' + S, Tools[I].Params);
  end;
end;

function ReadTransferTool(Index: Integer; var Tool: TTransferTool): Boolean;
begin
  Result := ReadToolFrom(Settings, Index, Tool);
end;

procedure GetTransferTools(List: TStrings);
var
  I: Integer;
  T: TTransferTool;
begin
  List.Clear;
  I := 0;
  while ReadTransferTool(I, T) do
  begin
    List.Add(T.Title + '=' + IntToStr(I));
    Inc(I);
  end;
end;

procedure WriteTransferTools(const Tools: array of TTransferTool);
begin
  WriteToolsTo(Settings, Tools);
end;

procedure ExportTransferTools(const FileName: string; const Tools: array of TTransferTool);
var
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(FileName);
  try
    Ini.Clear;
    WriteToolsTo(Ini, Tools);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

function SameTool(const A, B: TTransferTool): Boolean;
begin
  Result := (A.Title = B.Title) and SameText(A.Path, B.Path) and SameText(A.WorkingDir, B.WorkingDir) and
    (A.Params = B.Params);
end;

function ImportTransferTools(const FileName: string; var Tools: TTransferTools): Integer;
var
  Ini: TMemIniFile;
  T: TTransferTool;
  I, J: Integer;
  Held: Boolean;
begin
  Result := -1;
  Ini := TMemIniFile.Create(FileName);
  try
    I := 0;
    while ReadToolFrom(Ini, I, T) do
    begin
      if Result < 0 then Result := 0;
      Inc(I);
      if (T.Title = '') or (T.Path = '') then Continue;
      Held := False;
      for J := 0 to High(Tools) do
        if SameTool(Tools[J], T) then Held := True;
      if Held then Continue;
      SetLength(Tools, Length(Tools) + 1);
      Tools[High(Tools)] := T;
      Inc(Result);
    end;
  finally
    Ini.Free;
  end;
end;

constructor TSdEnvOptions.Create;
begin
  inherited Create;
  VarOverrides := TStringList.Create;
end;

destructor TSdEnvOptions.Destroy;
begin
  VarOverrides.Free;
  inherited;
end;

{ the values of [Environment] and of [Components]: each key once, for reading and writing (in
  this order); Load sets their defaults first }
function EnvTable(E: TSdEnvOptions): TSdOptions;
var
  C: TOIColor;
  I: Integer;
  X: TExpCategory;
begin
  Result := nil;
  with E do
  begin
    AddOptions(Result, [
      OptFlag('AutosaveEditor', AutosaveEditor),
      OptFlag('AutosaveDesktop', AutosaveDesktop),
      OptFlag('DesktopSymbols', DesktopSymbols),
      OptFlag('AutoDragDocking', AutoDragDocking),
      OptFlag('WarnPackageRebuild', WarnPackageRebuild),
      OptFlag('MinimizeOnRun', MinimizeOnRun),
      OptFlag('ShowCompilerProgress', ShowCompilerProgress),
      OptFlag('AutoCloseCompilerProgress', AutoCloseCompilerProgress),
      OptStr('RepositoryDir', RepositoryDir),
      OptFlag('CheckForUpdates', CheckForUpdates),
      OptFlag('ShowDesignerHints', ShowDesignerHints),
      OptFlag('ShowExtendedHints', ShowExtendedHints),
      OptFlag('NewFormsAsText', NewFormsAsText),
      OptFlag('AutoCreateForms', AutoCreateForms),
      OptFlag('OIShowInstanceList', OIShowInstanceList),
      OptFlag('OIShowClassNames', OIShowClassNames),
      OptFlag('OIShowStatusBar', OIShowStatusBar),
      OptFlag('OIRenderGrid', OIRenderGrid),
      OptFlag('OIIntegralHeight', OIIntegralHeight),
      OptFlag('OIShowReadOnly', OIShowReadOnly),
      OptFlag('OIBoldNonDefault', OIBoldNonDefault),
      OptFlag('OIRefExpand', OIRefExpand),
      OptFlag('OIRefOnEvents', OIRefOnEvents)]);
    for C := Low(TOIColor) to High(TOIColor) do
      AddOptions(Result, [OptColor('OIColor' + IntToStr(Ord(C)), OIColors[C])]);
    AddOptions(Result, [
      OptInt('OISpeedSetting', OISpeedSetting),
      OptStr('LibraryPath', LibraryPath),
      OptStr('BplOutputDir', BplOutputDir),
      OptStr('DcpOutputDir', DcpOutputDir),
      OptStr('BrowsingPath', BrowsingPath),
      OptFlag('ExAutoShow', ExAutoShow),
      OptFlag('ExHighlightIncomplete', ExHighlightIncomplete),
      OptFlag('ExShowSyntax', ExShowSyntax),
      OptFlag('ExSortAlpha', ExSortAlpha),
      OptFlag('ExFinishProperties', ExFinishProperties),
      OptFlag('ExSyncEditor', ExSyncEditor),
      OptInt('ExBrowserView', ExBrowserView),
      OptInt('ExBrowserScope', ExBrowserScope),
      OptStr('ExCategorySort', ExCategorySort)]);
    for X := Low(TExpCategory) to High(TExpCategory) do
      AddOptions(Result, [OptFlag('Ex' + ExpCategoryKeys[X] + 'Visible', ExVisible[X]),
        OptFlag('Ex' + ExpCategoryKeys[X] + 'Expand', ExExpand[X])]);
    AddOptions(Result, [
      OptInt('TLSafeCall', TLSafeCall),
      OptFlag('TLIgnoreFlags', TLIgnoreFlags)]);
    for I := 0 to 3 do AddOptions(Result, [OptFlag('TLFlag' + IntToStr(I), TLFlags[I])]);
  end;
end;

function MetricTable(E: TSdEnvOptions): TSdOptions;
begin
  Result := nil;
  with E do
    AddOptions(Result, [
      OptFlag('FormFields', MetricOpts.FormFields),
      OptFlag('OutsideAncestors', MetricOpts.OutsideAncestors)]);
end;

function CompTable(E: TSdEnvOptions): TSdOptions;
begin
  Result := nil;
  with E do
    AddOptions(Result, [
      OptFlag('Classic', CompClassic),
      OptFlag('HideCategory', CompHideCategory),
      OptInt('Sort', CompSort),
      OptInt('ResetDelay', CompResetDelay),
      OptColor('Color', CompColor)]);
end;

procedure TSdEnvOptions.Load;
var
  C: TOIColor;
  I: Integer;
  L: TStringList;
  X: TExpCategory;
  M: TMetricId;
begin
  if Settings = nil then Exit;
  { the defaults: what a value missing from the settings is (EnvTable) }
  AutosaveEditor := False;
  AutosaveDesktop := False;
  DesktopSymbols := False;
  AutoDragDocking := True;
  WarnPackageRebuild := False;
  MinimizeOnRun := False;
  ShowCompilerProgress := True;
  { Delphi 7's dialog waits for OK after Compile, Build and Syntax Check }
  AutoCloseCompilerProgress := False;
  RepositoryDir := '';
  CheckForUpdates := True;
  ShowDesignerHints := True;
  ShowExtendedHints := True;
  NewFormsAsText := True;
  AutoCreateForms := True;
  OIShowInstanceList := True;
  OIShowClassNames := True;
  OIShowStatusBar := False;
  OIRenderGrid := True;
  OIIntegralHeight := False;
  OIShowReadOnly := True;
  OIBoldNonDefault := True;
  OIRefExpand := True;
  OIRefOnEvents := True;
  for C := Low(TOIColor) to High(TOIColor) do OIColors[C] := DefaultOIColors[C];
  OISpeedSetting := 1;
  { the library: Delphi 7's defaults, until it is changed here }
  LibraryPath := '$(DELPHI)\Lib;$(DELPHI)\Bin;$(DELPHI)\Imports;$(DELPHI)\Projects\Bpl';
  BplOutputDir := '$(DELPHI)\Projects\Bpl';
  DcpOutputDir := '$(DELPHI)\Projects\Bpl';
  BrowsingPath := '$(DELPHI)\Source\Vcl;$(DELPHI)\Source\Rtl\Common;$(DELPHI)\Source\Rtl\Sys;' +
    '$(DELPHI)\Source\Rtl\Win;$(DELPHI)\Source\ToolsAPI;$(DELPHI)\Source\Internet';
  { Explorer: Delphi 7's defaults }
  ExAutoShow := True;
  ExHighlightIncomplete := True;
  ExShowSyntax := False;
  ExSortAlpha := True;
  ExFinishProperties := False;
  ExSyncEditor := False;              // Delphi 7's explorer follows nothing
  ExBrowserView := 0;
  ExBrowserScope := 0;
  ExCategorySort := DefaultExpCategorySort;
  for X := Low(TExpCategory) to High(TExpCategory) do
  begin
    ExVisible[X] := DefaultExpVisible[X];
    ExExpand[X] := DefaultExpExpand[X];
  end;
  TLSafeCall := 1;
  TLIgnoreFlags := False;
  for I := 0 to 3 do TLFlags[I] := False;
  CompClassic := True;
  CompHideCategory := False;
  CompSort := 0;
  CompResetDelay := 2;
  CompColor := clDefault;
  ReadOptions(EnvTable(Self), Settings, Sec, []);
  { every category named once, whatever the text held }
  ExCategorySort := ExpSortText(ExpSortedCategories(ExCategorySort));
  ReadOptions(CompTable(Self), Settings, CompSec, []);
  CompHotkey := Settings.ReadInteger(CompSec, 'Hotkey', 0);
  Metrics := MetricDefaults;
  MetricOpts := MetricDefaultOptions;
  ReadOptions(MetricTable(Self), Settings, MetricSec, []);
  for M := Low(TMetricId) to High(TMetricId) do
    ReadMetricSetting(Settings.ReadString(MetricSec, MetricDefs[M].Id, ''), Metrics[M]);
  L := TStringList.Create;
  try
    Settings.ReadSectionValues('Environment Variables', L);
    VarOverrides.Assign(L);
  finally
    L.Free;
  end;
end;

function TSdEnvOptions.Save: Boolean;
var
  I: Integer;
  M: TMetricId;
begin
  Result := True;
  if Settings = nil then Exit;
  WriteOptions(EnvTable(Self), Settings, Sec);
  { the folders of the Structure view of before (ExCategorySort and the categories' flags now) }
  Settings.DeleteKey(Sec, 'ExFolders');
  WriteOptions(CompTable(Self), Settings, CompSec);
  Settings.WriteInteger(CompSec, 'Hotkey', CompHotkey);
  WriteOptions(MetricTable(Self), Settings, MetricSec);
  for M := Low(TMetricId) to High(TMetricId) do
    Settings.WriteString(MetricSec, MetricDefs[M].Id, MetricSettingText(Metrics[M]));
  Settings.EraseSection('Environment Variables');
  for I := 0 to VarOverrides.Count - 1 do
    Settings.WriteString('Environment Variables', VarOverrides.Names[I], VarOverrides.ValueFromIndex[I]);
  Result := SaveSettings;
end;

var
  OriginalVars: TStringList;          // Name=Value before D7 Studio overrode it ('' = not set)

procedure GetSystemVariables(List: TStrings);
var
  P, Block: PChar;
  S: string;
  I, K: Integer;
begin
  List.Clear;
  Block := GetEnvironmentStrings;
  try
    P := Block;
    while P^ <> #0 do
    begin
      S := P;
      Inc(P, StrLen(P) + 1);
      if (S <> '') and (S[1] <> '=') then List.Add(S);     // "=C:=C:\..." are the drives' folders
    end;
  finally
    FreeEnvironmentStrings(Block);
  end;
  { overridden variables show their own value }
  if OriginalVars <> nil then
    for I := 0 to OriginalVars.Count - 1 do
    begin
      K := List.IndexOfName(OriginalVars.Names[I]);
      if K >= 0 then
      begin
        if OriginalVars.ValueFromIndex[I] = '' then List.Delete(K)
        else List[K] := OriginalVars[I];
      end;
    end;
end;

procedure TSdEnvOptions.ApplyVariables;
var
  I: Integer;
  Name: string;
begin
  if OriginalVars = nil then OriginalVars := TStringList.Create;
  { variables overridden before and no longer: back to what they were }
  for I := OriginalVars.Count - 1 downto 0 do
  begin
    Name := OriginalVars.Names[I];
    if VarOverrides.IndexOfName(Name) < 0 then
    begin
      if OriginalVars.ValueFromIndex[I] = '' then SetEnvironmentVariable(PChar(Name), nil)
      else SetEnvironmentVariable(PChar(Name), PChar(OriginalVars.ValueFromIndex[I]));
      OriginalVars.Delete(I);
    end;
  end;
  for I := 0 to VarOverrides.Count - 1 do
  begin
    Name := VarOverrides.Names[I];
    if Name = '' then Continue;
    if OriginalVars.IndexOfName(Name) < 0 then
      OriginalVars.Add(Name + '=' + GetEnvironmentVariable(Name));
    SetEnvironmentVariable(PChar(Name), PChar(VarOverrides.ValueFromIndex[I]));
  end;
end;

initialization
  EnvOptions := TSdEnvOptions.Create;

finalization
  FreeAndNil(EnvOptions);
  FreeAndNil(OriginalVars);

end.
