{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCodeTemplates;

{ D7 Studio - code templates: Delphi 7's Ctrl+J. A template is a
  shortcut name, a description, the source file type it belongs to and its code, in which "|"
  marks where the caret goes. The file has Delphi's format (delphi32.dci):

      [arrayd | array declaration (var) | Borland.EditOptions.Pascal]
      array[0..|] of ;

  D7 Studio keeps its own (D7Studio.dci in the settings folder); the first time it starts from
  Delphi 7's (delphi32.dci of D7 Studio's folder, SdDelphiDir.DelphiBin). Edited with Tools |
  Editor Options | Source Options | Edit Code Templates. }

interface

uses
  SysUtils, Classes;

type
  TCodeTemplate = record
    Name: string;
    Description: string;
    FileTypeID: string;              // Borland.EditOptions.Pascal ('' : every file type)
    Code: string;                    // CRLF lines; '|' marks the caret
  end;
  TCodeTemplates = array of TCodeTemplate;

var
  CodeTemplates: TCodeTemplates;

function ParseCodeTemplates(const Text: string): TCodeTemplates;
function CodeTemplatesText(const T: TCodeTemplates): string;
procedure LoadCodeTemplates;
procedure SaveCodeTemplates;
function CodeTemplatesFile: string;

implementation

uses
  SdSettings, SdFileNames, SdDelphiDir, SdEncoding;

function CodeTemplatesFile: string;
begin
  Result := IncludeTrailingPathDelimiter(SettingsDir) + 'D7Studio.dci';
end;

{ "[name | description | file type]" }
function ParseHeader(const S: string; var T: TCodeTemplate): Boolean;
var
  Body: string;
  P: Integer;
begin
  Result := (Length(S) > 2) and (S[1] = '[') and (S[Length(S)] = ']');
  if not Result then Exit;
  Body := Copy(S, 2, Length(S) - 2);
  P := Pos('|', Body);
  if P = 0 then
  begin
    T.Name := Trim(Body);
    T.Description := '';
    T.FileTypeID := '';
    Exit;
  end;
  T.Name := Trim(Copy(Body, 1, P - 1));
  Body := Copy(Body, P + 1, MaxInt);
  P := Pos('|', Body);
  if P = 0 then
  begin
    T.Description := Trim(Body);
    T.FileTypeID := '';
  end
  else
  begin
    T.Description := Trim(Copy(Body, 1, P - 1));
    T.FileTypeID := Trim(Copy(Body, P + 1, MaxInt));
  end;
  Result := T.Name <> '';
end;

{ the blank lines between the entries belong to none of them }
function TrimBlankLines(const S: string): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := S;
    while (L.Count > 0) and (Trim(L[L.Count - 1]) = '') do L.Delete(L.Count - 1);
    while (L.Count > 0) and (Trim(L[0]) = '') do L.Delete(0);
    Result := L.Text;
    if (Result <> '') and (Copy(Result, Length(Result) - 1, 2) = #13#10) then
      SetLength(Result, Length(Result) - 2);
  finally
    L.Free;
  end;
end;

function ParseCodeTemplates(const Text: string): TCodeTemplates;
var
  L: TStringList;
  I, N: Integer;
  T, H: TCodeTemplate;
  Code: string;
  Open: Boolean;

  procedure Flush;
  begin
    if not Open then Exit;
    T.Code := TrimBlankLines(Code);
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N] := T;
    Open := False;
  end;

begin
  SetLength(Result, 0);
  Open := False;
  Code := '';
  L := TStringList.Create;
  try
    L.Text := Text;
    for I := 0 to L.Count - 1 do
      if ParseHeader(TrimRight(L[I]), H) then
      begin
        Flush;                     // the template before this header
        T := H;
        Open := True;
        Code := '';
      end
      else if Open then
        Code := Code + L[I] + #13#10;
    Flush;
  finally
    L.Free;
  end;
end;

function CodeTemplatesText(const T: TCodeTemplates): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(T) do
  begin
    Result := Result + '[' + T[I].Name + ' | ' + T[I].Description;
    if T[I].FileTypeID <> '' then Result := Result + ' | ' + T[I].FileTypeID;
    Result := Result + ']'#13#10 + T[I].Code + #13#10#13#10;
  end;
end;

procedure LoadCodeTemplates;
var
  F: string;
begin
  F := CodeTemplatesFile;
  if not FileExistsU(F) then
  begin
    F := DelphiBin + 'delphi32.dci';
  end;
  { Delphi's file is in the system code page; D7 Studio's own one UTF-8 beyond ASCII }
  if FileExistsU(F) then CodeTemplates := ParseCodeTemplates(SystemFileToIde(ReadFileU(F)))
  else SetLength(CodeTemplates, 0);
end;

procedure SaveCodeTemplates;
begin
  WriteFileU(CodeTemplatesFile, CodeTemplatesText(CodeTemplates));
end;

end.
