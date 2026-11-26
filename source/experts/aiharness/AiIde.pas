{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiIde;

{ The AI harness's access to the IDE: the Open Tools API helpers shared with the other experts
  (..\kit\KitIde.inc: projects, open modules, editor buffers, the state of the code editor), and
  the paths of the model's tools - relative paths against the active project's folder - and of
  the compiler. Call it in the IDE's main thread. }

interface

uses
  Windows, SysUtils, Classes, Forms, ExtCtrls, ToolsAPI, AiText, AiJson;

{$DEFINE KIT_INTERFACE}
{$I ..\kit\KitIde.inc}
{$UNDEF KIT_INTERFACE}

{ the project called NameOrFile (its file, its file name or its name without extension); the
  active project when NameOrFile is empty; nil when there is none }
function FindProject(const NameOrFile: string): IOTAProject;

{ a path the model gave (IDE string): relative paths against the active project's folder }
function ResolvePath(const Path: string): string;
{ a tool's input member Name as an IDE string, and as a path resolved }
function ArgIde(Input: TJson; const Name: string): string;
function ArgPath(Input: TJson; const Name: string): string;
{ FileName relative to the active project's folder when it lies inside it }
function DisplayPath(const FileName: string): string;

{ Delphi's Bin folder (dcc32) }
function DelphiBinFolder: string;
{ the IDE's library path (Environment Options), $(DELPHI) and $(variables) expanded }
function IdeLibraryPath: string;

implementation

uses
  Variants, AiCompileCore;

{$I ..\kit\KitIde.inc}

function FindProject(const NameOrFile: string): IOTAProject;
var
  G: IOTAProjectGroup;
  I: Integer;
  P: IOTAProject;
  N: string;
begin
  Result := nil;
  N := Trim(NameOrFile);
  if N = '' then
  begin
    Result := ActiveProject;
    Exit;
  end;
  G := ProjectGroup;
  if G <> nil then
    for I := 0 to G.ProjectCount - 1 do
    begin
      P := G.Projects[I];
      if SameText(P.FileName, N) or SameText(ExtractFileName(P.FileName), N) or
        SameText(ChangeFileExt(ExtractFileName(P.FileName), ''), N) or SameText(P.FileName, ResolvePath(N)) then
      begin
        Result := P;
        Exit;
      end;
    end;
  P := ActiveProject;
  if (P <> nil) and (SameText(ChangeFileExt(ExtractFileName(P.FileName), ''), ChangeFileExt(ExtractFileName(N), '')) or
    SameText(P.FileName, ResolvePath(N))) then Result := P;
end;

function ResolvePath(const Path: string): string;
var
  P, Base: string;
begin
  P := Trim(StringReplace(Path, '/', '\', [rfReplaceAll]));
  if (Length(P) >= 2) and (P[1] = '"') and (P[Length(P)] = '"') then P := Copy(P, 2, Length(P) - 2);
  if P = '' then
  begin
    Result := '';
    Exit;
  end;
  if (Length(P) > 1) and ((P[2] = ':') or (Copy(P, 1, 2) = '\\')) then Result := ExpandFileName(P)
  else
  begin
    Base := ProjectFolder(ActiveProject);
    if Base = '' then Base := GetCurrentDir;
    Result := ExpandFileName(IncludeTrailingPathDelimiter(Base) + P);
  end;
end;

function ArgIde(Input: TJson; const Name: string): string;
begin
  Result := Utf8ToIde(Input.Str(Name));
end;

function ArgPath(Input: TJson; const Name: string): string;
begin
  Result := ResolvePath(ArgIde(Input, Name));
end;

function DisplayPath(const FileName: string): string;
var
  Base: string;
begin
  Base := ProjectFolder(ActiveProject);
  if (Base <> '') and SameText(Copy(FileName, 1, Length(Base)), Base) then
    Result := Copy(FileName, Length(Base) + 1, MaxInt)
  else
    Result := FileName;
end;

function IdeLibraryPath: string;
var
  V: Variant;
  S, Name, Value, Root: string;
  P, Q: Integer;
begin
  Result := '';
  try
    V := (BorlandIDEServices as IOTAServices).GetEnvironmentOptions.Values['LibraryPath'];
    S := V;
  except
    Exit;
  end;
  Root := ExcludeTrailingPathDelimiter((BorlandIDEServices as IOTAServices).GetRootDirectory);
  { $(DELPHI) is Delphi's folder; any other $(NAME) an environment variable }
  P := Pos('$(', S);
  while P > 0 do
  begin
    Q := P + 2;
    while (Q <= Length(S)) and (S[Q] <> ')') do Inc(Q);
    if Q > Length(S) then Break;
    Name := Copy(S, P + 2, Q - P - 2);
    if SameText(Name, 'DELPHI') then Value := Root else Value := GetEnvironmentVariable(Name);
    S := Copy(S, 1, P - 1) + Value + Copy(S, Q + 1, MaxInt);
    P := PosFrom('$(', S, P + Length(Value));
  end;
  Result := S;
end;

function DelphiBinFolder: string;
begin
  Result := (BorlandIDEServices as IOTAServices).GetBinDirectory;
  if (Result = '') or not FileExists(IncludeTrailingPathDelimiter(Result) + 'dcc32.exe') then
  begin
    Result := DelphiRootFromRegistry;
    if Result <> '' then Result := Result + 'Bin';
  end;
  if Result <> '' then Result := IncludeTrailingPathDelimiter(Result);
end;

end.
