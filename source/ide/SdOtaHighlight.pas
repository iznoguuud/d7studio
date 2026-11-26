{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaHighlight;

{ D7 Studio - the syntax highlighters of the Open Tools API: IOTAHighlightServices,
  as Delphi 7 has them.

  * Two lists, as Delphi's: the active highlighters - the indexes the service takes and gives are
    positions in it - and the dormant ones, removed but kept with their ID. AddHighlighter of an
    ID that is dormant revives its entry (at the end of the active list); RemoveHighlighter tells
    the highlighter Destroyed and makes its entry dormant - the later positions move down, as in
    Delphi (an expert that removes by an index it was given long ago may remove another's).
  * Ten built-in entries with Delphi 7's IDs in its order - None, Pascal, C/C++, IDL, HTML/XML,
    C#, SQL, PHP, JavaScript, INI File (the names D7 Studio's Source Options show where it has
    them) -: objects whose Tokenize makes every byte plain text (SyntaxOff) and whose line class is
    0, as Delphi's own are (its editor kernel colours those languages). They change no lexer of
    D7 Studio: a file's lexer follows its extension.
  * An expert's highlighter colours the files of the source file types (Source Options,
    IOTAEditOptions.SyntaxHighlighter) whose highlighter it is: the code editor styles their lines
    through it (SdSciEdit's TSciTokenizer, SciTokenizerFor) - line by line, the class the line
    before ended in, at most 1024 bytes of a line, the codes the Color page's elements. A
    highlighter that raises gives plain text and class 0 for that line (logged once), and so does
    a removed one - the files keep its ID until it comes back.
  * A package that goes takes its highlighters out first (DropModule, Destroyed told, as Delphi's
    package group callback removes them); when the IDE ends the experts' highlighters still there
    are told Destroyed (Shutdown). }

interface

uses
  SysUtils, Classes, Contnrs, ToolsAPI, SdOtaCore, SdSciEdit;

type
  TSdOtaHighlightServices = class(TAggregatedObject, IOTAHighlightServices)
  private
    FActive: TObjectList;            // TSdHighlightEntry, owned: the active list
    FDormant: TObjectList;           // ... removed, kept with their ID
    procedure Remove(Index: Integer; Tell: Boolean);
  public
    constructor Create(const Controller: IInterface);
    destructor Destroy; override;
    { the tokenizer of the first entry of an ID that is no built-in (active or dormant); nil:
      none - the editor's lexer follows the file's extension }
    function TokenizerFor(const ID: string): TSciTokenizer;
    { the active highlighter of an ID (the built-ins too); nil: none }
    function HighlighterOfID(const ID: string): IOTAHighlighter;
    procedure DropModule(Module: HMODULE);
    procedure AddModules(List: TList);
    procedure Shutdown;
    function DebugText: string;
    { IOTAHighlightServices }
    function GetHighlighterCount: Integer;
    function GetHighlighter(Index: Integer): IOTAHighlighter;
    function AddHighlighter(const AHighlighter: IOTAHighlighter): Integer;
    procedure RemoveHighlighter(Index: Integer);
  end;

{ the highlighter of a source file type's ID (IOTAEditOptions.GetSyntaxHighlighter); nil: none }
function OtaHighlighterOfID(const ID: string): IOTAHighlighter;
{ test mode: 'active/dormant' }
function OtaHighlightDebugText: string;

implementation

uses
  SdEditorPage;

type
  TSdHighlightEntry = class;

  { the editor's side of an entry: the entry asked at every line (a removed highlighter answers
    plain text, as Delphi's stub does) }
  TSdOtaTokenizer = class(TSciTokenizer)
  private
    FEntry: TSdHighlightEntry;
    FLogged: Boolean;               // an exception of the expert's was logged (once)
    procedure Failed(const What: string);
  public
    constructor Create(AEntry: TSdHighlightEntry);
    procedure Tokenize(StartClass: Byte; Line: PChar; Len: Word; Codes: PByte); override;
    function LineClass(StartClass: Byte; Line: PChar; Len: Word): Byte; override;
  end;

  TSdHighlightEntry = class
  public
    ID: string;
    Highlighter: IOTAHighlighter;   // nil: dormant
    Builtin: Boolean;
    Tokenizer: TSdOtaTokenizer;
    constructor Create(const AID: string; const AHighlighter: IOTAHighlighter; ABuiltin: Boolean);
    destructor Destroy; override;
  end;

  { one of Delphi 7's own highlighters: its editor kernel colours the language, the object
    itself tokenizes nothing }
  TSdBuiltinHighlighter = class(TNotifierObject, IOTANotifier, IOTAHighlighter)
  private
    FID, FName: string;
  public
    constructor Create(const AID, AName: string);
    function GetIDString: string;
    function GetName: string;
    procedure Tokenize(StartClass: TOTALineClass; LineBuf: POTAEdChar; LineBufLen: TOTALineSize;
      HighlightCodes: POTASyntaxCode);
    function TokenizeLineClass(StartClass: TOTALineClass; LineBuf: POTAEdChar;
      LineBufLen: TOTALineSize): TOTALineClass;
  end;

  TBuiltin = record
    ID, Name: string;
  end;

const
  { Delphi 7's (Edprocs.InitEdGlobalData, then PHP, JavaScript and INI through AddHighlighter);
    the names of the ones D7 Studio's Source Options list are its own (C++, HTML) }
  Builtins: array[0..9] of TBuiltin = (
    (ID: 'Borland.Highlighter.None'; Name: 'None'),
    (ID: 'Borland.Highlighter.Pascal'; Name: 'Pascal'),
    (ID: 'Borland.Highlighter.Cpp'; Name: 'C++'),
    (ID: 'Borland.Highlighter.IDL'; Name: 'IDL'),
    (ID: 'Borland.Highlighter.HTML'; Name: 'HTML'),
    (ID: 'Borland.Highlighter.C#'; Name: 'C#'),
    (ID: 'Borland.Highlighter.SQL'; Name: 'SQL'),
    (ID: 'Borland.Highlighter.PHP'; Name: 'PHP'),
    (ID: 'Borland.Highlighter.JavaScript'; Name: 'JavaScript'),
    (ID: 'Borland.Highlighter.INI'; Name: 'INI File'));
  MaxCode = 31;                      // the styles Scintilla leaves to a lexer: 0 .. 31

var
  HighlightServices: TSdOtaHighlightServices;

{ ---------------------------------------------------------------- TSdBuiltinHighlighter }

constructor TSdBuiltinHighlighter.Create(const AID, AName: string);
begin
  inherited Create;
  FID := AID;
  FName := AName;
end;

function TSdBuiltinHighlighter.GetIDString: string;
begin
  Result := FID;
end;

function TSdBuiltinHighlighter.GetName: string;
begin
  Result := FName;
end;

procedure TSdBuiltinHighlighter.Tokenize(StartClass: TOTALineClass; LineBuf: POTAEdChar;
  LineBufLen: TOTALineSize; HighlightCodes: POTASyntaxCode);
begin
  FillChar(HighlightCodes^, LineBufLen, SyntaxOff);
end;

function TSdBuiltinHighlighter.TokenizeLineClass(StartClass: TOTALineClass; LineBuf: POTAEdChar;
  LineBufLen: TOTALineSize): TOTALineClass;
begin
  Result := 0;
end;

{ ---------------------------------------------------------------- TSdHighlightEntry }

constructor TSdHighlightEntry.Create(const AID: string; const AHighlighter: IOTAHighlighter;
  ABuiltin: Boolean);
begin
  inherited Create;
  ID := AID;
  Highlighter := AHighlighter;
  Builtin := ABuiltin;
  Tokenizer := TSdOtaTokenizer.Create(Self);
end;

destructor TSdHighlightEntry.Destroy;
begin
  Tokenizer.Free;
  Highlighter := nil;
  inherited;
end;

{ ---------------------------------------------------------------- TSdOtaTokenizer }

constructor TSdOtaTokenizer.Create(AEntry: TSdHighlightEntry);
begin
  inherited Create;
  FEntry := AEntry;
end;

{ in an except block: the exception of the expert's code logged once, whatever its class (EAbort,
  which OtaCaught keeps silent, does not use up the one entry) }
procedure TSdOtaTokenizer.Failed(const What: string);
begin
  if FLogged or (ExceptObject is EAbort) then Exit;
  FLogged := True;
  OtaCaught('IOTAHighlighter.' + What + ' (' + FEntry.ID + ')', False);
end;

procedure TSdOtaTokenizer.Tokenize(StartClass: Byte; Line: PChar; Len: Word; Codes: PByte);
var
  H: IOTAHighlighter;
  I: Integer;
begin
  FillChar(Codes^, Len, SyntaxOff);
  H := FEntry.Highlighter;
  if (H = nil) or (Len = 0) then Exit;
  try
    H.Tokenize(StartClass, Line, Len, POTASyntaxCode(Codes));
  except
    FillChar(Codes^, Len, SyntaxOff);
    Failed('Tokenize');
  end;
  { a code no style can show: plain text }
  for I := 0 to Len - 1 do
    if PByteArray(Codes)^[I] > MaxCode then PByteArray(Codes)^[I] := SyntaxOff;
end;

function TSdOtaTokenizer.LineClass(StartClass: Byte; Line: PChar; Len: Word): Byte;
var
  H: IOTAHighlighter;
begin
  Result := 0;
  H := FEntry.Highlighter;
  if H = nil then Exit;
  try
    Result := H.TokenizeLineClass(StartClass, Line, Len);
  except
    Result := 0;
    Failed('TokenizeLineClass');
  end;
end;

{ ---------------------------------------------------------------- TSdOtaHighlightServices }

constructor TSdOtaHighlightServices.Create(const Controller: IInterface);
var
  I: Integer;
begin
  inherited Create(Controller);
  FActive := TObjectList.Create(True);
  FDormant := TObjectList.Create(True);
  for I := Low(Builtins) to High(Builtins) do
    FActive.Add(TSdHighlightEntry.Create(Builtins[I].ID,
      TSdBuiltinHighlighter.Create(Builtins[I].ID, Builtins[I].Name), True));
  HighlightServices := Self;
end;

destructor TSdOtaHighlightServices.Destroy;
begin
  if HighlightServices = Self then HighlightServices := nil;
  FDormant.Free;
  FActive.Free;
  inherited;
end;

{ the code editors of the files whose type has the ID: their language and styles again (the
  language follows the highlighter - SdSciEdit's ApplyOptions) }
procedure Restyle(const ID: string);
var
  I: Integer;
  P: TEditorPage;
begin
  if (OtaHost = nil) or (ID = '') then Exit;
  for I := 0 to OtaHost.PageCount - 1 do
  begin
    P := OtaHost.Pages(I);
    if SameText(P.Editor.FileType.Highlighter, ID) then P.Editor.ApplyOptions;
  end;
end;

function TSdOtaHighlightServices.TokenizerFor(const ID: string): TSciTokenizer;
var
  I: Integer;
  E: TSdHighlightEntry;
begin
  Result := nil;
  if ID = '' then Exit;
  for I := 0 to FActive.Count + FDormant.Count - 1 do
  begin
    if I < FActive.Count then E := TSdHighlightEntry(FActive[I])
    else E := TSdHighlightEntry(FDormant[I - FActive.Count]);
    if SameText(E.ID, ID) then
    begin
      { Delphi's language of an ID is its first entry's: a built-in stays the built-in }
      if not E.Builtin then Result := E.Tokenizer;
      Exit;
    end;
  end;
end;

function TSdOtaHighlightServices.HighlighterOfID(const ID: string): IOTAHighlighter;
var
  I: Integer;
begin
  Result := nil;
  if ID = '' then Exit;
  for I := 0 to FActive.Count - 1 do
    if SameText(TSdHighlightEntry(FActive[I]).ID, ID) then
    begin
      Result := TSdHighlightEntry(FActive[I]).Highlighter;
      Exit;
    end;
end;

function TSdOtaHighlightServices.GetHighlighterCount: Integer;
begin
  Result := FActive.Count;
end;

function TSdOtaHighlightServices.GetHighlighter(Index: Integer): IOTAHighlighter;
begin
  if (Index >= 0) and (Index < FActive.Count) then Result := TSdHighlightEntry(FActive[Index]).Highlighter
  else Result := nil;
end;

{ Delphi's: a dormant entry of the ID comes back with the new interface, else a new entry; the
  result is the position in the active list }
function TSdOtaHighlightServices.AddHighlighter(const AHighlighter: IOTAHighlighter): Integer;
var
  ID: string;
  I: Integer;
  E: TSdHighlightEntry;
begin
  Result := -1;
  if AHighlighter = nil then Exit;
  ID := AHighlighter.GetIDString;
  E := nil;
  for I := 0 to FDormant.Count - 1 do
    if SameText(TSdHighlightEntry(FDormant[I]).ID, ID) then
    begin
      E := TSdHighlightEntry(FDormant.Extract(FDormant[I]));
      Break;
    end;
  if E = nil then E := TSdHighlightEntry.Create(ID, nil, False);
  E.Highlighter := AHighlighter;
  E.Tokenizer.FLogged := False;
  Result := FActive.Add(E);
  Restyle(ID);
end;

procedure TSdOtaHighlightServices.Remove(Index: Integer; Tell: Boolean);
var
  E: TSdHighlightEntry;
  H: IOTAHighlighter;
begin
  E := TSdHighlightEntry(FActive.Extract(FActive[Index]));
  H := E.Highlighter;
  E.Highlighter := nil;
  FDormant.Add(E);
  if Tell and (H <> nil) then
    try
      H.Destroyed;
    except
      OtaCaught('IOTAHighlighter.Destroyed', False);
    end;
  H := nil;
  Restyle(E.ID);
end;

{ a bad index is ignored: an exception there would break the expert's unload }
procedure TSdOtaHighlightServices.RemoveHighlighter(Index: Integer);
begin
  if (Index >= 0) and (Index < FActive.Count) then Remove(Index, True);
end;

procedure TSdOtaHighlightServices.DropModule(Module: HMODULE);
var
  I: Integer;
  E: TSdHighlightEntry;
begin
  if Module = 0 then Exit;
  I := 0;
  while I < FActive.Count do
  begin
    E := TSdHighlightEntry(FActive[I]);
    if not E.Builtin and (InterfaceModule(E.Highlighter) = Module) then Remove(I, True)
    else Inc(I);
  end;
end;

procedure TSdOtaHighlightServices.AddModules(List: TList);
var
  I: Integer;
  E: TSdHighlightEntry;
begin
  for I := 0 to FActive.Count - 1 do
  begin
    E := TSdHighlightEntry(FActive[I]);
    if not E.Builtin then AddModuleOnce(List, InterfaceModule(E.Highlighter));
  end;
end;

{ the experts' highlighters still there: told Destroyed and released, while their packages are
  there }
procedure TSdOtaHighlightServices.Shutdown;
var
  I: Integer;
begin
  I := 0;
  while I < FActive.Count do
    if TSdHighlightEntry(FActive[I]).Builtin then Inc(I) else Remove(I, True);
end;

function TSdOtaHighlightServices.DebugText: string;
begin
  Result := Format('%d/%d', [FActive.Count, FDormant.Count]);
end;

{ ---------------------------------------------------------------- the hooks }

function OtaHighlighterOfID(const ID: string): IOTAHighlighter;
begin
  if HighlightServices = nil then Result := nil else Result := HighlightServices.HighlighterOfID(ID);
end;

function OtaHighlightDebugText: string;
begin
  if HighlightServices = nil then Result := '' else Result := HighlightServices.DebugText;
end;

{ SdSciEdit's hook }
function EditorTokenizerFor(const HighlighterID: string): TSciTokenizer;
begin
  if HighlightServices = nil then Result := nil else Result := HighlightServices.TokenizerFor(HighlighterID);
end;

initialization
  SciTokenizerFor := EditorTokenizerFor;
finalization
  SciTokenizerFor := nil;
end.
