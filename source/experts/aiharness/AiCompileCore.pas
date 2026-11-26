{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiCompileCore;

{ The parts of the harness's compile tool that do not need the IDE: reading dcc32's messages,
  rewriting the "in" paths of a project file so that its units come from a scratch copy, the
  scratch folder of a project and Delphi 7's folder. dcc32 itself runs through AiProcess.

  The compile tool compiles what the editor holds without saving it: the files with unsaved
  changes are written into the scratch folder, and the project file's copy names them with
  absolute paths (RewriteUnitPaths keeps every line where it was, so the compiler's line numbers
  stay right). }

interface

uses
  Windows, SysUtils, Classes, Contnrs;

type
  TAiCompilerMessage = class
  public
    FileName: string;
    Line: Integer;
    Kind: string;       // Error, Warning, Hint, Fatal
    Text: string;
  end;

  TAiCompilerMessages = class
  private
    FItems: TObjectList;
    function GetItem(Index: Integer): TAiCompilerMessage;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const AFileName: string; ALine: Integer; const AKind, AText: string): TAiCompilerMessage;
    function Count: Integer;
    function CountOf(const AKind: string): Integer;
    procedure Clear;
    property Items[Index: Integer]: TAiCompilerMessage read GetItem; default;
  end;

{ dcc32's messages from its output: 'File(Line) Kind: text', 'File(Line): Kind: text' and
  'Kind: text' }
procedure ParseCompilerOutput(const Output: string; Messages: TAiCompilerMessages);

{ the project file's text with every "in '<path>'" made absolute (relative paths against
  ProjectDir) and the paths of Map ('original=replacement' lines) replaced; comments and other
  text stay as they are, and so does every line break. Found (when given) gets the absolute
  paths of the project file's units. }
function RewriteUnitPaths(const Source, ProjectDir, Map: string; Found: TStrings = nil): string;

{ a folder of its own for the scratch builds of a project file (in %TEMP%) }
function ScratchFolder(const ProjectFile: string): string;

{ Delphi 7's folder from the registry (RootDir of Software\Borland\Delphi\7.0, the user's, else
  the machine's); '' when it is not installed }
function DelphiRootFromRegistry: string;

implementation

uses
  Registry, AiText;

{ ---------------------------------------------------------------- messages }

constructor TAiCompilerMessages.Create;
begin
  inherited Create;
  FItems := TObjectList.Create(True);
end;

destructor TAiCompilerMessages.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TAiCompilerMessages.Add(const AFileName: string; ALine: Integer; const AKind, AText: string): TAiCompilerMessage;
begin
  Result := TAiCompilerMessage.Create;
  Result.FileName := AFileName;
  Result.Line := ALine;
  Result.Kind := AKind;
  Result.Text := AText;
  FItems.Add(Result);
end;

function TAiCompilerMessages.Count: Integer;
begin
  Result := FItems.Count;
end;

function TAiCompilerMessages.CountOf(const AKind: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    if SameText(Items[I].Kind, AKind) then Inc(Result);
end;

procedure TAiCompilerMessages.Clear;
begin
  FItems.Clear;
end;

function TAiCompilerMessages.GetItem(Index: Integer): TAiCompilerMessage;
begin
  Result := TAiCompilerMessage(FItems[Index]);
end;

{ 'Error: text' at the start of S: the kind and the text }
function SplitKind(const S: string; out Kind, Text: string): Boolean;
const
  Kinds: array[0..3] of string = ('Error', 'Warning', 'Hint', 'Fatal');
var
  I: Integer;
  T: string;
begin
  Result := False;
  T := TrimLeft(S);
  if (T <> '') and (T[1] = ':') then T := TrimLeft(Copy(T, 2, MaxInt));
  for I := Low(Kinds) to High(Kinds) do
    if SameText(Copy(T, 1, Length(Kinds[I]) + 1), Kinds[I] + ':') then
    begin
      Kind := Kinds[I];
      Text := Trim(Copy(T, Length(Kinds[I]) + 2, MaxInt));
      Result := True;
      Exit;
    end;
end;

procedure ParseCompilerOutput(const Output: string; Messages: TAiCompilerMessages);
var
  L: TStringList;
  I, P, Q: Integer;
  S, Kind, Text: string;
begin
  L := TStringList.Create;
  try
    L.Text := Output;
    for I := 0 to L.Count - 1 do
    begin
      S := Trim(L[I]);
      if S = '' then Continue;
      if SplitKind(S, Kind, Text) then
      begin
        Messages.Add('', 0, Kind, Text);
        Continue;
      end;
      { File(Line) Kind: the first "(digits)" that a kind follows (a file name may hold brackets) }
      for P := 1 to Length(S) do
        if S[P] = '(' then
        begin
          Q := P + 1;
          while (Q <= Length(S)) and (S[Q] in ['0'..'9']) do Inc(Q);
          if (Q > P + 1) and (Q <= Length(S)) and (S[Q] = ')') and
            SplitKind(Copy(S, Q + 1, MaxInt), Kind, Text) then
          begin
            Messages.Add(Trim(Copy(S, 1, P - 1)), StrToIntDef(Copy(S, P + 1, Q - P - 1), 0), Kind, Text);
            Break;
          end;
        end;
    end;
  finally
    L.Free;
  end;
end;

{ ---------------------------------------------------------------- in-paths }

function RewriteUnitPaths(const Source, ProjectDir, Map: string; Found: TStrings): string;
var
  Maps: TStringList;
  I, L, Start, Run, Q: Integer;
  B: TKitStringBuilder;
  Path, Full, Repl: string;
  AfterIn: Boolean;

  function MapIndex(const F: string): Integer;
  var
    K: Integer;
  begin
    Result := -1;
    for K := 0 to Maps.Count - 1 do
      if SameText(Maps.Names[K], F) then
      begin
        Result := K;
        Exit;
      end;
  end;

  function Quote(const S: string): string;
  begin
    Result := '''' + StringReplace(S, '''', '''''', [rfReplaceAll]) + '''';
  end;

begin
  Maps := TStringList.Create;
  B := TKitStringBuilder.Create;
  try
    Maps.Text := Map;
    I := 1;
    L := Length(Source);
    AfterIn := False;
    while I <= L do
    begin
      Start := I;
      case Source[I] of
        '{':
          begin
            while (I <= L) and (Source[I] <> '}') do Inc(I);
            Inc(I);
          end;
        '(':
          if (I < L) and (Source[I + 1] = '*') then
          begin
            Inc(I, 2);
            while (I < L) and not ((Source[I] = '*') and (Source[I + 1] = ')')) do Inc(I);
            Inc(I, 2);
          end
          else
          begin
            Inc(I);
            AfterIn := False;
          end;
        '/':
          if (I < L) and (Source[I + 1] = '/') then
            while (I <= L) and not (Source[I] in [#13, #10]) do Inc(I)
          else
          begin
            Inc(I);
            AfterIn := False;
          end;
        '''':
          begin
            { a string literal: 'it''s' - its text taken in runs }
            Path := '';
            Inc(I);
            Run := I;
            while I <= L do
            begin
              if Source[I] = '''' then
              begin
                Path := Path + Copy(Source, Run, I - Run);
                if (I < L) and (Source[I + 1] = '''') then
                begin
                  Path := Path + '''';
                  Inc(I, 2);
                  Run := I;
                  Continue;
                end;
                Inc(I);
                Run := I;
                Break;
              end;
              Inc(I);
            end;
            if Run < I then Path := Path + Copy(Source, Run, I - Run);   // unterminated
            if AfterIn and (Path <> '') then
            begin
              if (Length(Path) > 1) and ((Path[2] = ':') or (Copy(Path, 1, 2) = '\\')) then Full := Path
              else Full := ExpandFileName(IncludeTrailingPathDelimiter(ProjectDir) + Path);
              if (Found <> nil) and (Found.IndexOf(Full) < 0) then Found.Add(Full);
              Q := MapIndex(Full);
              if Q >= 0 then Repl := Copy(Maps[Q], Length(Maps.Names[Q]) + 2, MaxInt) else Repl := Full;
              B.Append(Quote(Repl));
              Start := I;    // the literal is written already
            end;
            AfterIn := False;
          end;
        'A'..'Z', 'a'..'z', '_':
          begin
            while (I <= L) and (Source[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(I);
            AfterIn := (I - Start = 2) and SameText(Copy(Source, Start, 2), 'in');
          end;
        ' ', #9, #13, #10:
          Inc(I);
      else
        Inc(I);
        AfterIn := False;
      end;
      { the text from Start up to I as it is (comments, words, white space ...) }
      if I > L + 1 then I := L + 1;
      if I > Start then B.Append(@Source[Start], I - Start);
    end;
    Result := B.Text;
  finally
    B.Free;
    Maps.Free;
  end;
end;

{ ---------------------------------------------------------------- scratch folder, Delphi's folder }

function ScratchFolder(const ProjectFile: string): string;
var
  Temp: array[0..MAX_PATH] of Char;
  H: Cardinal;
  I: Integer;
  S: string;
begin
  GetTempPath(MAX_PATH, Temp);
  S := LowerCase(ProjectFile);
  H := 5381;
  for I := 1 to Length(S) do H := (H * 33) xor Ord(S[I]);
  Result := IncludeTrailingPathDelimiter(Temp) + 'D7AiHarness\' +
    ChangeFileExt(ExtractFileName(ProjectFile), '') + '-' + IntToHex(H, 8) + '\';
end;

function DelphiRootFromRegistry: string;
const
  Roots: array[0..1] of HKEY = (HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE);
var
  R: TRegistry;
  I: Integer;
begin
  Result := '';
  for I := Low(Roots) to High(Roots) do
  begin
    R := TRegistry.Create(KEY_READ);
    try
      R.RootKey := Roots[I];
      if R.OpenKeyReadOnly('Software\Borland\Delphi\7.0') then
      begin
        Result := R.ReadString('RootDir');
        R.CloseKey;
      end;
    finally
      R.Free;
    end;
    if Result <> '' then
    begin
      Result := IncludeTrailingPathDelimiter(Result);
      Exit;
    end;
  end;
end;

end.
