{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdHistory;

{ D7 Studio - the versions of the files, as the History tab (SdHistoryView) shows them.

  They lie in D7 Studio's own folder, never beside the file: %LOCALAPPDATA%\D7Studio\History\, a folder
  per file named after it and the hash of its full name (the test instance's under D7S_HOME). In it
  each version is the file's bytes as they were (<id>.<ext>), and history.txt (UTF-8, a line per
  version, the oldest first) says when it was taken, what took it, the lines it added and removed
  against the version before it, the Pascal routines and types it changed, its encoding, the file on
  the disk it left behind (size and time: an outside change is told by them), what wrote the file
  without its editor, and a label.

  What takes a version (the editor page and the main form call these; nothing while
  HistoryEnabled is off - Editor Options > Display > Keep file history):
  * a save: the disk's text first when it is not the newest version's (the file as it was before
    its history began, or as another program left it), then the text written (HistoryBeforeWrite,
    HistoryWritten); the IDE's write of a file without its editor (Format Project) the same way;
  * the unsaved text every few minutes - one version after the newest other one, replaced each time
    and gone when the text is saved -, the text a close without saving or a reload lets go, the text
    as it is under a label (HistoryKeep);
  * a file another program changed, when D7 Studio notices it (HistoryCheckDisk).
  The same text is never taken twice in a row. A file keeps its newest HistoryLimit versions and
  every labelled one. }

{$Q-,R-,B-,H+}

interface

uses
  Windows, SysUtils, Classes, SdEncoding, SdFileNames, SdTextDiff;

type
  { what took a version }
  THistoryKind = (hkOriginal, hkSaved, hkUnsaved, hkClosed, hkReloaded, hkOutside, hkWritten, hkLabel);

  THistoryVersion = record
    Id: Integer;
    Time: Int64;               // UTC, in a FILETIME's 100 ns
    Kind: THistoryKind;
    Added, Removed: Integer;   // lines against the version before it; -1: the first
    Routines: string;          // the Pascal routines and types it changed, ', ' between them
    Encoding: string;          // its text's encoding (EncodingToSetting)
    DiskSize: Int64;           // the file on the disk as the version left it; -1: the disk was not written
    DiskTime: Int64;           // ... its last write time (UTC, 100 ns)
    Writer: string;            // hkWritten: what wrote the file without its editor (Format Project)
    LabelText: string;         // a label: the version is kept for good
    Snippet: string;           // its first line added (else '- ' and the first removed), blanks off
  end;

  { the versions of one file, as its folder has them when made (Load reads them again) }
  TFileHistory = class
  private
    FFileName: string;
    FDir: string;
    FItems: array of THistoryVersion;
    FCount: Integer;
    function GetItem(I: Integer): THistoryVersion;
    function IdFile(Id: Integer): string;
    function UnsavedLast: Boolean;
    procedure SaveIndex;
    procedure Changed;
    procedure DeleteAt(I: Integer);
    procedure Prune;
    procedure Summarize(var V: THistoryVersion; const Bytes: string);
  public
    constructor Create(const FileName: string);
    procedure Load;
    function Count: Integer;
    function IndexOfId(Id: Integer): Integer;
    { the newest version the disk had - taken from it or written to it (-1: none) }
    function NewestOnDisk: Integer;
    function VersionFile(I: Integer): string;
    function Bytes(I: Integer): string;
    { a version's text as the editor holds it: HistoryTextOf (a form file's text), else its bytes
      decoded in its encoding - converted to E's, when E is given and another }
    function Text(I: Integer): string; overload;
    function Text(I: Integer; const E: TSdEncoding): string; overload;
    function EncodingOf(I: Integer): TSdEncoding;
    { a version of Bytes (the file's bytes, E their encoding) of Kind: the trailing Unsaved version
      goes first when Kind is the editor's text (saved, unsaved, closed, reloaded, a label); nothing
      new when the newest version has these bytes - the newest is labelled then, or takes Disk.
      Disk: the file as the version leaves it (Exists False: not written). The index of the version,
      -1 when nothing was kept }
    function Add(Kind: THistoryKind; const Bytes: string; const E: TSdEncoding; const Writer, LabelText: string;
      const Disk: TSdFileStamp): Integer;
    procedure SetLabel(I: Integer; const Text: string);
    { the disk has version I's bytes as Disk says (a file written again unchanged, touched) }
    procedure SetDisk(I: Integer; const Disk: TSdFileStamp);
    procedure Delete(I: Integer);
    property Items[I: Integer]: THistoryVersion read GetItem; default;
    property FileName: string read FFileName;
    property Folder: string read FDir;
  end;

  { the text of a version's bytes to compare and show when the IDE reads such a file in a way of its
    own (a form file, binary ones too): True and Text; False - the bytes are decoded }
  THistoryTextFunc = function(const FileName, Bytes: string; out Text: string): Boolean;
  THistoryChangedEvent = procedure(const FileName: string) of object;

const
  HistoryKindKeys: array[THistoryKind] of string = ('original', 'saved', 'unsaved', 'closed', 'reloaded',
    'outside', 'written', 'label');
  { what took it, as the History tab names it (hkWritten: the writer, hkLabel: the label) }
  HistoryKindCaptions: array[THistoryKind] of string = ('Original', 'Saved', 'Unsaved changes',
    'Closed without saving', 'Discarded by Reload', 'Changed outside', 'Written', 'Labelled');
  { between the routines of THistoryVersion.Routines }
  RoutineSeparator = ', ';

var
  HistoryEnabled: Boolean = True;      // Editor Options > Display > Keep file history
  HistoryLimit: Integer = 50;          // ... versions per file, the labelled ones besides
  HistoryTextOf: THistoryTextFunc;     // nil: the bytes decoded
  OnHistoryChanged: THistoryChangedEvent;   // a file's versions changed
  { the time a version is taken at (UTC, 100 ns); nil: now. The tests set it }
  HistoryClock: function: Int64;

{ the folder of the versions of all files, and of FileName's }
function HistoryRoot: string;
function HistoryFolder(const FileName: string): string;
{ the IDE is about to write FileName: the text the disk has is kept first when it is not the newest
  version's (the file before its history, or as another program left it) }
procedure HistoryBeforeWrite(const FileName: string; const E: TSdEncoding);
{ ... and has written Bytes (encoded in E) there: a version of Kind - hkSaved, or hkWritten with
  Writer, what wrote it }
procedure HistoryWritten(const FileName, Bytes: string; const E: TSdEncoding; Kind: THistoryKind;
  const Writer: string = '');
{ the editor's text of FileName (Bytes as a save would write them) kept as a version of Kind -
  hkUnsaved, hkClosed, hkReloaded, hkLabel with LabelText; the disk's text first, as before a write }
procedure HistoryKeep(const FileName, Bytes: string; const E: TSdEncoding; Kind: THistoryKind;
  const LabelText: string = '');
{ FileName as the disk has it now: a version Changed outside D7 Studio when it is not the newest one
  the disk had - only for a file with versions (Start: also one without, its first version) }
procedure HistoryCheckDisk(const FileName: string; const E: TSdEncoding; Start: Boolean = False);
{ the trailing Unsaved version of FileName goes (its text was saved or let go) }
procedure HistoryDropUnsaved(const FileName: string);
{ FileName has versions }
function HistoryExists(const FileName: string): Boolean;

{ a version's time on this computer's clock }
function HistoryLocalTime(T: Int64): TDateTime;
function HistoryNow: Int64;
{ the versions taken until HistoryEndMoment have one time: those of a unit and its form saved
  together (TEditorPage.Save), so that the form as it was at a unit's version is the newest form
  version of that time or before. Moments nest }
procedure HistoryBeginMoment;
procedure HistoryEndMoment;
function FileTimeToInt64(const T: TFileTime): Int64;

{ the outermost routines and types of a Pascal text that the lines of Ranges touch: Ranges holds
  pairs, a first line and a count (0: the place between the line before and that line) }
type
  TCodeSpan = record
    Name: string;                // TForm1.Button1Click, TForm1 (a type)
    First, Last: Integer;        // 0-based lines
  end;
  TCodeSpans = array of TCodeSpan;

function CodeSpans(const Text: string): TCodeSpans;
{ the names of Spans that the change of Lines (First, Count) touches - Count 0: an insertion between
  the lines First - 1 and First }
function SpansTouched(const Spans: TCodeSpans; First, Count: Integer): Boolean;
function SpanTouched(const Span: TCodeSpan; First, Count: Integer): Boolean;
{ line Line (0-based) lies in Span }
function SpanHolds(const Span: TCodeSpan; Line: Integer): Boolean;
{ the routines and types the diff's changes touch, in their order in the new text, then those only
  the old text had: RoutineSeparator between them }
function ChangedRoutines(D: TLineDiff): string;
{ a version's routines (THistoryVersion.Routines) one per string of L, and back }
procedure SplitRoutines(const Routines: string; L: TStrings);
function JoinRoutines(L: TStrings): string;
{ the outermost routine or type of a Pascal text that line Line (0-based) lies in ('' none) }
function RoutineAt(const Text: string; Line: Integer): string;
function IsPascalSourceName(const FileName: string): Boolean;

implementation

uses
  SdPasBlocks;

const
  IndexName = 'history.txt';
  IndexHead = 'D7 Studio file history 1';
  MaxRoutineText = 8 * 1024 * 1024;     // a larger text: no routines named (the block structure's limit)

function FileTimeToInt64(const T: TFileTime): Int64;
begin
  Result := Int64(T.dwHighDateTime) shl 32 or T.dwLowDateTime;
end;

var
  MomentDepth: Integer = 0;
  MomentTime: Int64 = 0;

procedure HistoryBeginMoment;
begin
  if MomentDepth = 0 then
  begin
    MomentTime := 0;
    MomentTime := HistoryNow;
  end;
  Inc(MomentDepth);
end;

procedure HistoryEndMoment;
begin
  if MomentDepth > 0 then Dec(MomentDepth);
  if MomentDepth = 0 then MomentTime := 0;
end;

function HistoryNow: Int64;
var
  T: TFileTime;
begin
  if MomentTime <> 0 then
  begin
    Result := MomentTime;
    Exit;
  end;
  if Assigned(HistoryClock) then
  begin
    Result := HistoryClock;
    Exit;
  end;
  GetSystemTimeAsFileTime(T);
  Result := FileTimeToInt64(T);
end;

function HistoryLocalTime(T: Int64): TDateTime;
var
  U, L: TFileTime;
  S: TSystemTime;
begin
  U.dwLowDateTime := DWORD(T);
  U.dwHighDateTime := DWORD(T shr 32);
  if FileTimeToLocalFileTime(U, L) and FileTimeToSystemTime(L, S) then Result := SystemTimeToDateTime(S)
  else Result := 0;
end;

function HistoryRoot: string;
var
  W: array[0..MAX_PATH] of WideChar;
  N: DWORD;
begin
  Result := GetEnvironmentVariable('D7S_HOME');
  if Result <> '' then
  begin
    Result := IncludeTrailingPathDelimiter(Result) + 'History\';
    Exit;
  end;
  N := GetEnvironmentVariableW(PWideChar(WideString('LOCALAPPDATA')), PWideChar(@W[0]), MAX_PATH);
  if (N > 0) and (N < MAX_PATH) then
    Result := IncludeTrailingPathDelimiter(UsablePath(W)) + 'D7Studio\History\'
  else
    Result := ExtractFilePath(ParamStr(0)) + 'History\';
end;

{ <file name>~<hash of the full name, any case>: the name in ASCII, a dot and any other character '_' - no
  short 8.3 name of the folder looks like a source file's (*.pas finds no Unit1_pas~...) -, the hash
  tells the files of one name apart }
function HistoryFolder(const FileName: string): string;
var
  W, N: WideString;
  Key, Name: string;
  I: Integer;
  Lost: Boolean;
begin
  W := DisplayPath(ExpandPathU(FileName));
  Key := FromWide(WideLowerCase(W), CP_UTF8, Lost);
  N := WideFileName(W);
  Name := '';
  for I := 1 to Length(N) do
    if (Ord(N[I]) >= 32) and (Ord(N[I]) < 127) and not (Char(Ord(N[I])) in ['\', '/', ':', '*', '?', '"', '<', '>', '|', '.']) then
      Name := Name + Char(Ord(N[I]))
    else
      Name := Name + '_';
  Result := HistoryRoot + Name + '~' + IntToHex(TextHash(Key), 8) + '\';
end;

function IsPascalSourceName(const FileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  Result := (Ext = '.pas') or (Ext = '.dpr') or (Ext = '.dpk') or (Ext = '.inc');
end;

{ ---------------------------------------------------------------- routines and types }

function IsIdentChar(C: Char): Boolean;
begin
  Result := C in ['A'..'Z', 'a'..'z', '0'..'9', '_'];
end;

{ a routine's name from its heading at P (1-based): [class] procedure|function|constructor|
  destructor Name[.Name ...] }
function HeadingName(const Text: string; P: Integer): string;
var
  N, S: Integer;
  W: string;

  procedure SkipBlanks;
  begin
    while (P <= N) and (Text[P] in [' ', #9, #13, #10]) do Inc(P);
  end;

  function Word: string;
  begin
    SkipBlanks;
    S := P;
    while (P <= N) and IsIdentChar(Text[P]) do Inc(P);
    Result := Copy(Text, S, P - S);
  end;

begin
  N := Length(Text);
  W := LowerCase(Word);
  if W = 'class' then W := LowerCase(Word);
  Result := '';
  repeat
    W := Word;
    if W = '' then Break;
    if Result <> '' then Result := Result + '.';
    Result := Result + W;
    SkipBlanks;
    if (P <= N) and (Text[P] = '.') then Inc(P) else Break;
  until False;
end;

{ a type's name before its opening word at P (1-based): Name = [packed] class|record|... }
function TypeName(const Text: string; P: Integer): string;
var
  E: Integer;

  procedure SkipBack;
  begin
    while (P >= 1) and (Text[P] in [' ', #9, #13, #10]) do Dec(P);
  end;

  function WordBack: string;
  begin
    SkipBack;
    E := P;
    while (P >= 1) and IsIdentChar(Text[P]) do Dec(P);
    Result := Copy(Text, P + 1, E - P);
  end;

begin
  Result := '';
  Dec(P);
  SkipBack;
  if (P >= 6) and SameText(Copy(Text, P - 5, 6), 'packed') then
  begin
    Dec(P, 6);
    SkipBack;
  end;
  if (P < 1) or (Text[P] <> '=') then Exit;
  Dec(P);
  Result := WordBack;
end;

function CodeSpans(const Text: string): TCodeSpans;
var
  B: TPasBlocks;
  L: TTextLines;
  All: TCodeSpans;
  I, J, N, K: Integer;
  S: TCodeSpan;
  Inside: Boolean;

  { a routine's or type's span, when it has a name }
  procedure Put(const Name: string; First, Last: Integer);
  begin
    if Name = '' then Exit;
    All[N].Name := Name;
    All[N].First := First;
    All[N].Last := Last;
    Inc(N);
  end;

begin
  SetLength(Result, 0);
  if Length(Text) > MaxRoutineText then Exit;
  B := TPasBlocks.Create(Text);
  L := TTextLines.Create(Text);
  try
    N := 0;
    SetLength(All, B.RoutineCount + B.WordCount);
    for I := 0 to B.RoutineCount - 1 do
      Put(HeadingName(Text, B.Routines[I].Start + 1), L.LineOf(B.Routines[I].Start), L.LineOf(B.Routines[I].Stop - 1));
    for I := 0 to B.WordCount - 1 do
      with B.Words[I] do
        if (Role = wrOpen) and (Kind in [bkClass, bkRecord, bkObject, bkInterface]) and (Closer >= 0) then
          Put(TypeName(Text, Start + 1), Line, B.Words[Closer].Line);
    { the outermost ones, in the text's order }
    K := 0;
    SetLength(Result, N);
    for I := 0 to N - 1 do
    begin
      Inside := False;
      for J := 0 to N - 1 do
        if (J <> I) and (All[J].First <= All[I].First) and (All[J].Last >= All[I].Last) and
          ((All[J].First < All[I].First) or (All[J].Last > All[I].Last) or (J < I)) then
        begin
          Inside := True;
          Break;
        end;
      if not Inside then
      begin
        Result[K] := All[I];
        Inc(K);
      end;
    end;
    SetLength(Result, K);
    { by their first line }
    for I := 1 to K - 1 do
    begin
      S := Result[I];
      J := I - 1;
      while (J >= 0) and (Result[J].First > S.First) do
      begin
        Result[J + 1] := Result[J];
        Dec(J);
      end;
      Result[J + 1] := S;
    end;
  finally
    L.Free;
    B.Free;
  end;
end;

function SpanTouched(const Span: TCodeSpan; First, Count: Integer): Boolean;
begin
  if Count > 0 then Result := (Span.First <= First + Count - 1) and (Span.Last >= First)
  else Result := (Span.First <= First - 1) and (Span.Last >= First);
end;

function SpansTouched(const Spans: TCodeSpans; First, Count: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(Spans) do
    if SpanTouched(Spans[I], First, Count) then
    begin
      Result := True;
      Exit;
    end;
end;

function SpanHolds(const Span: TCodeSpan; Line: Integer): Boolean;
begin
  Result := (Line >= Span.First) and (Line <= Span.Last);
end;

function RoutineAt(const Text: string; Line: Integer): string;
var
  Spans: TCodeSpans;
  I: Integer;
begin
  Result := '';
  Spans := CodeSpans(Text);
  for I := 0 to High(Spans) do
    if SpanHolds(Spans[I], Line) then
    begin
      Result := Spans[I].Name;
      Exit;
    end;
end;

function ChangedRoutines(D: TLineDiff): string;
var
  Names: TStringList;

  { the routines and types of Side's text that a change touches there }
  procedure Collect(Side: TDiffSide);
  var
    Spans: TCodeSpans;
    I, K: Integer;
  begin
    Spans := CodeSpans(D.Lines(Side).Text);
    for K := 0 to High(Spans) do
      for I := 0 to D.RunCount - 1 do
        if (D[I].Kind = dkChange) and SpanTouched(Spans[K], RunStart(D[I], Side), RunLength(D[I], Side)) then
        begin
          if Names.IndexOf(Spans[K].Name) < 0 then Names.Add(Spans[K].Name);
          Break;
        end;
  end;

begin
  Names := TStringList.Create;
  try
    Collect(dsNew);
    Collect(dsOld);
    Result := JoinRoutines(Names);
  finally
    Names.Free;
  end;
end;

procedure SplitRoutines(const Routines: string; L: TStrings);
begin
  L.Text := StringReplace(Routines, RoutineSeparator, #13#10, [rfReplaceAll]);
end;

function JoinRoutines(L: TStrings): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to L.Count - 1 do
  begin
    if I > 0 then Result := Result + RoutineSeparator;
    Result := Result + L[I];
  end;
end;

{ ---------------------------------------------------------------- TFileHistory }

constructor TFileHistory.Create(const FileName: string);
begin
  inherited Create;
  FFileName := ExpandPathU(FileName);
  FDir := HistoryFolder(FFileName);
  Load;
end;

function TFileHistory.Count: Integer;
begin
  Result := FCount;
end;

function TFileHistory.GetItem(I: Integer): THistoryVersion;
begin
  Result := FItems[I];
end;

{ the file of the bytes of version Id }
function TFileHistory.IdFile(Id: Integer): string;
begin
  Result := FDir + IntToStr(Id) + ExtractFileExt(FFileName);
end;

{ the newest version is an Unsaved one without a label: the one that goes when the text is saved or
  let go }
function TFileHistory.UnsavedLast: Boolean;
begin
  Result := (FCount > 0) and (FItems[FCount - 1].Kind = hkUnsaved) and (FItems[FCount - 1].LabelText = '');
end;

{ the disk as version V left it: Disk, or not written (Exists False) }
procedure StampVersion(var V: THistoryVersion; const Disk: TSdFileStamp);
begin
  if Disk.Exists then
  begin
    V.DiskSize := Disk.Size;
    V.DiskTime := FileTimeToInt64(Disk.Time);
  end
  else
  begin
    V.DiskSize := -1;
    V.DiskTime := 0;
  end;
end;

function OneLine(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  for I := 1 to Length(Result) do
    if Result[I] in [#0..#31] then Result[I] := ' ';
end;

{ the fields of a line of the index, tab between them }
procedure SplitFields(const S: string; L: TStrings);
var
  P, Q: Integer;
begin
  L.Clear;
  P := 1;
  repeat
    Q := P;
    while (Q <= Length(S)) and (S[Q] <> #9) do Inc(Q);
    L.Add(Copy(S, P, Q - P));
    P := Q + 1;
  until Q > Length(S);
end;

procedure TFileHistory.Load;
var
  L, F: TStringList;
  I: Integer;
  K: THistoryKind;
  V: THistoryVersion;
  Kind: string;
begin
  FCount := 0;
  SetLength(FItems, 0);
  if not FileExistsU(FDir + IndexName) then Exit;
  L := TStringList.Create;
  F := TStringList.Create;
  try
    try
      L.Text := ReadFileU(FDir + IndexName);
    except
      Exit;
    end;
    if (L.Count = 0) or (L[0] <> IndexHead) then Exit;
    SetLength(FItems, L.Count);
    for I := 1 to L.Count - 1 do
    begin
      SplitFields(L[I], F);
      if F.Count < 11 then Continue;              // the File line, a damaged line
      V.Id := StrToIntDef(F[0], -1);
      if V.Id < 0 then Continue;
      V.Time := StrToInt64Def(F[1], 0);
      Kind := F[2];
      V.Kind := hkSaved;
      for K := Low(THistoryKind) to High(THistoryKind) do
        if HistoryKindKeys[K] = Kind then V.Kind := K;
      V.Added := StrToIntDef(F[3], -1);
      V.Removed := StrToIntDef(F[4], -1);
      V.Encoding := F[5];
      V.DiskSize := StrToInt64Def(F[6], -1);
      V.DiskTime := StrToInt64Def(F[7], 0);
      V.Routines := F[8];
      V.Writer := F[9];
      V.LabelText := F[10];
      if F.Count > 11 then V.Snippet := F[11] else V.Snippet := '';
      { a version whose bytes are gone is no version }
      if not FileExistsU(IdFile(V.Id)) then Continue;
      FItems[FCount] := V;
      Inc(FCount);
    end;
  finally
    F.Free;
    L.Free;
  end;
end;

procedure TFileHistory.SaveIndex;
var
  L: TStringList;
  I: Integer;
  Lost: Boolean;
begin
  L := TStringList.Create;
  try
    L.Add(IndexHead);
    L.Add('File'#9 + FromWide(DisplayPath(FFileName), CP_UTF8, Lost));
    for I := 0 to FCount - 1 do
      with FItems[I] do
        L.Add(IntToStr(Id) + #9 + IntToStr(Time) + #9 + HistoryKindKeys[Kind] + #9 + IntToStr(Added) + #9 +
          IntToStr(Removed) + #9 + Encoding + #9 + IntToStr(DiskSize) + #9 + IntToStr(DiskTime) + #9 +
          OneLine(Routines) + #9 + OneLine(Writer) + #9 + OneLine(LabelText) + #9 + OneLine(Snippet));
    ForceDirectoriesU(FDir);
    WriteFileU(FDir + IndexName, L.Text);
  finally
    L.Free;
  end;
end;

{ the versions changed: the index written, the IDE told }
procedure TFileHistory.Changed;
begin
  SaveIndex;
  if Assigned(OnHistoryChanged) then OnHistoryChanged(FFileName);
end;

function TFileHistory.IndexOfId(Id: Integer): Integer;
begin
  for Result := 0 to FCount - 1 do
    if FItems[Result].Id = Id then Exit;
  Result := -1;
end;

function TFileHistory.NewestOnDisk: Integer;
begin
  for Result := FCount - 1 downto 0 do
    if FItems[Result].DiskSize >= 0 then Exit;
  Result := -1;
end;

function TFileHistory.VersionFile(I: Integer): string;
begin
  Result := IdFile(FItems[I].Id);
end;

function TFileHistory.Bytes(I: Integer): string;
begin
  Result := ReadFileU(VersionFile(I));
end;

function TFileHistory.EncodingOf(I: Integer): TSdEncoding;
begin
  if not EncodingFromSetting(FItems[I].Encoding, Result) then Result := SystemEncoding;
end;

function TextOfBytes(const FileName, Bytes: string; E: TSdEncoding): string;
begin
  if not Assigned(HistoryTextOf) or not HistoryTextOf(FileName, Bytes, Result) then
    Result := DecodeFile(Bytes, E, False);
end;

function TFileHistory.Text(I: Integer): string;
begin
  Result := TextOfBytes(FFileName, Bytes(I), EncodingOf(I));
end;

function TFileHistory.Text(I: Integer; const E: TSdEncoding): string;
var
  Own: TSdEncoding;
  Res: string;
  Lost: Boolean;
begin
  Result := Text(I);
  Own := EncodingOf(I);
  if not SameEncoding(Own, E) and ConvertText(Result, Own, E, Res, Lost) then Result := Res;
end;

{ the first line a change added - else '- ' and the first it removed -, its blanks off, at most 100
  characters, as the IDE's text: what a version changed when it names no routine }
function FirstChangedLine(D: TLineDiff; const E: TSdEncoding): string;
var
  I: Integer;

  { the first line of R's Side that is not blank, its blanks off ('' none) }
  function FirstText(const R: TDiffRun; Side: TDiffSide): string;
  var
    K: Integer;
  begin
    for K := RunStart(R, Side) to RunStart(R, Side) + RunLength(R, Side) - 1 do
    begin
      Result := Trim(D.Lines(Side).Line(K));
      if Result <> '' then Exit;
    end;
    Result := '';
  end;

begin
  Result := '';
  for I := 0 to D.RunCount - 1 do
    if D[I].Kind = dkChange then
    begin
      Result := FirstText(D[I], dsNew);
      if Result = '' then
      begin
        Result := FirstText(D[I], dsOld);
        if Result <> '' then Result := '- ' + Result;
      end;
      if Result <> '' then Break;
    end;
  Result := EditorToAnsi(Copy(Result, 1, 100), E);
end;

{ the lines added and removed against the newest version, the routines and types that changed, the
  first line changed }
procedure TFileHistory.Summarize(var V: THistoryVersion; const Bytes: string);
var
  D: TLineDiff;
  E: TSdEncoding;
begin
  V.Added := -1;
  V.Removed := -1;
  V.Routines := '';
  V.Snippet := '';
  if FCount = 0 then Exit;
  if not EncodingFromSetting(V.Encoding, E) then E := SystemEncoding;
  try
    D := TLineDiff.Create(Text(FCount - 1, E), TextOfBytes(FFileName, Bytes, E));
    try
      V.Added := D.Added;
      V.Removed := D.Removed;
      if IsPascalSourceName(FFileName) and (D.Changes > 0) then V.Routines := ChangedRoutines(D);
      V.Snippet := OneLine(FirstChangedLine(D, E));
    finally
      D.Free;
    end;
  except
    { a version that cannot be read: nothing to compare with }
  end;
end;

function TFileHistory.Add(Kind: THistoryKind; const Bytes: string; const E: TSdEncoding;
  const Writer, LabelText: string; const Disk: TSdFileStamp): Integer;
var
  V: THistoryVersion;
  I, Id: Integer;
  Same: Boolean;
begin
  Load;
  { the editor's text: the Unsaved version before it is older }
  if Kind in [hkSaved, hkUnsaved, hkClosed, hkReloaded, hkLabel] then
    while UnsavedLast do DeleteAt(FCount - 1);
  Same := False;
  if FCount > 0 then
    try
      Same := Self.Bytes(FCount - 1) = Bytes;
    except
      Same := False;
    end;
  if Same and ((LabelText = '') or (FItems[FCount - 1].LabelText = '')) then
  begin
    { the newest version has these bytes: it is labelled, it knows the disk has them; a text let go
      and then saved as it was is a saved one }
    Result := FCount - 1;
    if LabelText <> '' then FItems[Result].LabelText := OneLine(LabelText);
    if Disk.Exists then StampVersion(FItems[Result], Disk);
    if (Kind = hkSaved) and (FItems[Result].Kind in [hkClosed, hkReloaded]) then
    begin
      FItems[Result].Kind := hkSaved;
      FItems[Result].Time := HistoryNow;
    end;
    Changed;
    Exit;
  end;
  Id := 1;
  for I := 0 to FCount - 1 do
    if FItems[I].Id >= Id then Id := FItems[I].Id + 1;
  V.Id := Id;
  { the file as it was before its history: at its own time }
  if (Kind = hkOriginal) and Disk.Exists then V.Time := FileTimeToInt64(Disk.Time) else V.Time := HistoryNow;
  V.Kind := Kind;
  V.Encoding := EncodingToSetting(E);
  StampVersion(V, Disk);
  V.Writer := OneLine(Writer);
  V.LabelText := OneLine(LabelText);
  Summarize(V, Bytes);
  ForceDirectoriesU(FDir);
  WriteFileU(IdFile(Id), Bytes);
  if FCount = Length(FItems) then SetLength(FItems, FCount * 2 + 8);
  FItems[FCount] := V;
  Inc(FCount);
  Prune;
  Result := IndexOfId(Id);
  Changed;
end;

procedure TFileHistory.DeleteAt(I: Integer);
var
  K: Integer;
begin
  DeleteFileW(PWideChar(WidePath(VersionFile(I))));
  for K := I to FCount - 2 do FItems[K] := FItems[K + 1];
  Dec(FCount);
end;

{ the oldest versions without a label go while there are more than HistoryLimit }
procedure TFileHistory.Prune;
var
  I, Unlabelled: Integer;
begin
  Unlabelled := 0;
  for I := 0 to FCount - 1 do
    if FItems[I].LabelText = '' then Inc(Unlabelled);
  I := 0;
  while (Unlabelled > HistoryLimit) and (I < FCount) do
    if FItems[I].LabelText = '' then
    begin
      DeleteAt(I);
      Dec(Unlabelled);
    end
    else
      Inc(I);
end;

{ a label taken off leaves the version to the limit at the next version, not at once }
procedure TFileHistory.SetLabel(I: Integer; const Text: string);
begin
  FItems[I].LabelText := OneLine(Text);
  Changed;
end;

procedure TFileHistory.SetDisk(I: Integer; const Disk: TSdFileStamp);
begin
  StampVersion(FItems[I], Disk);
  SaveIndex;
end;

procedure TFileHistory.Delete(I: Integer);
begin
  DeleteAt(I);
  Changed;
end;

{ ---------------------------------------------------------------- what takes versions }

function HistoryExists(const FileName: string): Boolean;
begin
  Result := FileExistsU(HistoryFolder(FileName) + IndexName);
end;

procedure HistoryCheckDisk(const FileName: string; const E: TSdEncoding; Start: Boolean);
var
  S: TSdFileStamp;
  H: TFileHistory;
  D: Integer;
  Bytes: string;
  Kind: THistoryKind;
begin
  if not HistoryEnabled then Exit;
  try
    if not Start and not HistoryExists(FileName) then Exit;
    S := FileStampU(FileName);
    if not S.Exists then Exit;
    H := TFileHistory.Create(FileName);
    try
      D := H.NewestOnDisk;
      if (D >= 0) and (H[D].DiskSize = S.Size) and (H[D].DiskTime = FileTimeToInt64(S.Time)) then Exit;
      Bytes := ReadFileU(FileName);
      { the disk has the bytes of the newest version it had: only its stamp is new (touched) }
      if (D >= 0) and (H.Bytes(D) = Bytes) then
      begin
        H.SetDisk(D, S);
        Exit;
      end;
      if H.Count = 0 then Kind := hkOriginal else Kind := hkOutside;
      H.Add(Kind, Bytes, E, '', '', S);
    finally
      H.Free;
    end;
  except
    { the versions are kept as well as they can be: a failure there never stops the IDE's work }
  end;
end;

procedure HistoryBeforeWrite(const FileName: string; const E: TSdEncoding);
begin
  HistoryCheckDisk(FileName, E, True);
end;

{ a version of FileName (TFileHistory.Add) - a failure only loses it }
procedure AddVersion(const FileName: string; Kind: THistoryKind; const Bytes: string; const E: TSdEncoding;
  const Writer, LabelText: string; const Disk: TSdFileStamp);
var
  H: TFileHistory;
begin
  try
    H := TFileHistory.Create(FileName);
    try
      H.Add(Kind, Bytes, E, Writer, LabelText, Disk);
    finally
      H.Free;
    end;
  except
  end;
end;

procedure HistoryWritten(const FileName, Bytes: string; const E: TSdEncoding; Kind: THistoryKind; const Writer: string);
begin
  if HistoryEnabled then AddVersion(FileName, Kind, Bytes, E, Writer, '', FileStampU(FileName));
end;

procedure HistoryKeep(const FileName, Bytes: string; const E: TSdEncoding; Kind: THistoryKind; const LabelText: string);
var
  None: TSdFileStamp;
begin
  if not HistoryEnabled then Exit;
  HistoryCheckDisk(FileName, E, True);
  FillChar(None, SizeOf(None), 0);
  AddVersion(FileName, Kind, Bytes, E, '', LabelText, None);
end;

procedure HistoryDropUnsaved(const FileName: string);
var
  H: TFileHistory;
begin
  if not HistoryExists(FileName) then Exit;
  try
    H := TFileHistory.Create(FileName);
    try
      if H.UnsavedLast then H.Delete(H.Count - 1);
    finally
      H.Free;
    end;
  except
  end;
end;

end.
