{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

program migrate;

{ Migrates a Delphi 7 configuration into D7 Studio: the settings Delphi 7 keeps in its registry
  key (HKEY_CURRENT_USER\Software\Borland\Delphi\7.0) and in the files of its Bin become D7
  Studio's - its D7Studio.ini and the files beside it, its registry key
  (HKEY_CURRENT_USER\Software\D7Studio). D7 Studio runs on that Delphi 7 ($(DELPHI) is its
  folder): its packages, experts, Imports and ObjRepos stay where they are.

    migrate <D7 Studio folder> [options]
    migrate -List <file> [-Delphi <folder>] [-Key <key>]

    -WhatIf              print what would change, change nothing
    -Only <parts>        migrate only these parts (comma separated)
    -Skip <parts>        ... all but these
    -Exclude <names>     items left out, comma separated: <part>:<name> as -List names them (a
                         package's file name, an expert's name, a key of experts' settings, a
                         tool's title, an environment variable), or a name alone (any part's
                         item; Delphi 7's files defproj.dof, delphi32.dci, Delphi32.dro,
                         msginfo70.ini, delphi32.dmt too)
    -ExcludeFile <file>  ... one on each line of a text file (UTF-8 or the system code page)
    -Overwrite           Delphi 7's menu templates replace a different D7Studio.dmt
    -Delphi <folder>     Delphi 7's folder (default: RootDir of its registry key)
    -Key <key>           Delphi 7's key under HKEY_CURRENT_USER (Software\Borland\Delphi\7.0)
    -Settings <folder>   the folder of D7Studio.ini (default: the D7 Studio folder)
    -RegKey <key>        D7 Studio's key under HKEY_CURRENT_USER (Software\D7Studio)
    -List <file>         write the items of Delphi 7's configuration that can be left out, one
                         per line: <part> TAB <name> TAB <text> (UTF-8 with a BOM; "-": the
                         console), and migrate nothing

  The parts, <group>.<part> in the order they run, are MigCore.MigGroups and MigParts (-Help
  lists them); a group's name stands for its parts, "options" for environment, editor and
  debugger. The items of packages, experts.dll, experts.settings, tools and variables can be left
  out one by one. A value of Delphi 7 replaces D7 Studio's; lists (library folders, packages, experts,
  tools, history lists) are merged. Exit code 0: done; 1: an error; 2: wrong arguments; 3: no
  Delphi 7 configuration found.

  Started without arguments - from Explorer, Setup's last page, D7 Studio's Tools menu (the tool
  Setup adds) - it shows its dialog Migrate from Delphi 7 (MigDlg) for the D7 Studio of its own
  folder, without the console; the run is the console's (MigCore.RunMigration). The dialog
  migrates while that D7 Studio runs too, which the console refuses.

  Its units (migrate\Mig*) are migrate.exe's alone: D7 Studio does not link them. SdEditorThemes
  and SdCheckImages are D7 Studio's, shared. }

{$APPTYPE CONSOLE}

uses
  ModernManUtf8,
  Windows,
  SysUtils,
  Classes,
  Forms,
  MigCore in 'migrate\MigCore.pas',
  SdEditorThemes in 'editor\SdEditorThemes.pas',
  MigOptions in 'migrate\MigOptions.pas',
  MigItems in 'migrate\MigItems.pas',
  SdCheckImages in 'ide\SdCheckImages.pas',
  MigDlg in 'migrate\MigDlg.pas' {MigrateDlg};

type
  { wrong arguments: exit code 2 }
  EUsage = class(Exception);

var
  Parts: TStringList;
  ListFile: string;   // -List: where the items go ('-': the console)

procedure Usage;
var
  G, I: Integer;
  S: string;
begin
  Writeln('migrate - migrates a Delphi 7 configuration into D7 Studio');
  Writeln;
  Writeln('  migrate <D7 Studio folder> [options]');
  Writeln('  migrate -List <file> [-Delphi <folder>] [-Key <key>]');
  Writeln;
  Writeln('  -WhatIf              print what would change, change nothing');
  Writeln('  -Only <parts>        migrate only these parts or groups (comma separated)');
  Writeln('  -Skip <parts>        ... all but these');
  Writeln('  -Exclude <names>     items left out (comma separated): <part>:<name> as -List names them,');
  Writeln('                       or a name alone (any part''s item; also Delphi 7''s files defproj.dof,');
  Writeln('                       delphi32.dci, Delphi32.dro, msginfo70.ini, delphi32.dmt)');
  Writeln('  -ExcludeFile <file>  ... one on each line of a text file');
  Writeln('  -Overwrite           Delphi 7''s menu templates replace a different D7Studio.dmt');
  Writeln('  -Delphi <folder>     Delphi 7''s folder (default: RootDir of its registry key)');
  Writeln('  -Key <key>           Delphi 7''s key under HKEY_CURRENT_USER');
  Writeln('                       (default Software\Borland\Delphi\7.0)');
  Writeln('  -Settings <folder>   the folder of D7Studio.ini (default: the D7 Studio folder)');
  Writeln('  -RegKey <key>        D7 Studio''s key under HKEY_CURRENT_USER (default Software\D7Studio)');
  Writeln('  -List <file>         the items that can be left out, "<part> TAB <name> TAB <text>" lines');
  Writeln('                       (UTF-8; "-": the console); migrates nothing');
  Writeln;
  Writeln('  groups and their parts ("options": environment, editor and debugger):');
  for G := 0 to GroupCount - 1 do
  begin
    S := '';
    for I := 0 to PartCount - 1 do
      if (PartGroup(MigParts[I].Name) = MigGroups[G].Name) and (MigParts[I].Name <> MigGroups[G].Name) then
      begin
        if S <> '' then S := S + ', ';
        S := S + MigParts[I].Name;
      end;
    if S = '' then Writeln('    ', MigGroups[G].Name) else Writeln('    ', MigGroups[G].Name, ': ', S);
  end;
  Writeln('  items one by one: ', StringReplace(ItemParts, ',', ', ', [rfReplaceAll]));
end;

{ the names of Lines, one on each, trimmed and in lower case, added to List (empty lines skipped) }
procedure AddNames(Lines, List: TStrings);
var
  I: Integer;
begin
  for I := 0 to Lines.Count - 1 do
    if Trim(Lines[I]) <> '' then List.Add(LowerCase(Trim(Lines[I])));
end;

{ the names of a comma-separated list added to List }
procedure SplitNames(const S: string; List: TStrings);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := StringReplace(S, ',', #13#10, [rfReplaceAll]);
    AddNames(L, List);
  finally
    L.Free;
  end;
end;

{ the names of -ExcludeFile: one on each line }
procedure ReadExcludeFile(const FileName: string);
var
  L: TStringList;
begin
  if not FileExists(FileName) then raise EUsage.CreateFmt('%s was not found', [FileName]);
  L := TStringList.Create;
  try
    L.LoadFromFile(FileName);
    AddNames(L, Excluded);
  finally
    L.Free;
  end;
end;

{ the parts of a list of -Only or -Skip added to List }
procedure AddPartList(const Names: string; List: TStrings);
var
  L: TStringList;
  K: Integer;
begin
  L := TStringList.Create;
  try
    SplitNames(Names, L);
    for K := 0 to L.Count - 1 do
      if not AddParts(L[K], List) then raise EUsage.CreateFmt('unknown part %s', [L[K]]);
  finally
    L.Free;
  end;
end;

{ the arguments; False: wrong ones (said why) }
function ParseArgs: Boolean;
var
  I, K: Integer;
  A, Only, Skip: string;
  L: TStringList;

  function Next: string;
  begin
    Inc(I);
    if I > ParamCount then raise EUsage.CreateFmt('%s needs a value', [A]);
    Result := ParamStr(I);
  end;

begin
  Result := False;
  Only := '';
  Skip := '';
  DelphiKey := 'Software\Borland\Delphi\7.0';
  StudioKey := 'Software\D7Studio';
  I := 1;
  while I <= ParamCount do
  begin
    A := ParamStr(I);
    if SameText(A, '-WhatIf') then WhatIf := True
    else if SameText(A, '-Overwrite') then Overwrite := True
    else if SameText(A, '-Only') then Only := Next
    else if SameText(A, '-Skip') then Skip := Next
    else if SameText(A, '-Exclude') then SplitNames(Next, Excluded)
    else if SameText(A, '-ExcludeFile') then ReadExcludeFile(ExpandFileName(Next))
    else if SameText(A, '-List') then
    begin
      ListFile := Next;
      if ListFile <> '-' then ListFile := ExpandFileName(ListFile);
    end
    else if SameText(A, '-Delphi') then DelphiRoot := ExcludeTrailingPathDelimiter(ExpandFileName(Next))
    else if SameText(A, '-Key') then DelphiKey := Next
    else if SameText(A, '-Settings') then SettingsDir := ExcludeTrailingPathDelimiter(ExpandFileName(Next))
    else if SameText(A, '-RegKey') then StudioKey := Next
    else if (A = '-?') or (A = '/?') or SameText(A, '-Help') then Exit
    else if (A <> '') and (A[1] = '-') then raise EUsage.CreateFmt('unknown option %s', [A])
    else if StudioRoot = '' then StudioRoot := ExcludeTrailingPathDelimiter(ExpandFileName(A))
    else raise EUsage.CreateFmt('one D7 Studio folder only (%s)', [A]);
    Inc(I);
  end;
  if (StudioRoot = '') and (ListFile = '') then raise EUsage.Create('the D7 Studio folder is missing');
  DelphiKey := ExcludeTrailingPathDelimiter(DelphiKey);
  StudioKey := ExcludeTrailingPathDelimiter(StudioKey);
  if SettingsDir = '' then SettingsDir := StudioRoot;
  if Only <> '' then AddPartList(Only, Parts)
  else
    for K := 0 to PartCount - 1 do Parts.Add(MigParts[K].Name);
  L := TStringList.Create;
  try
    AddPartList(Skip, L);
    for K := 0 to L.Count - 1 do
      if Parts.IndexOf(L[K]) >= 0 then Parts.Delete(Parts.IndexOf(L[K]));
  finally
    L.Free;
  end;
  Result := True;
end;

{ -List: the items of Delphi 7's configuration (MigCore.ListItems) into ListFile }
procedure WriteItems;
const
  Bom = #$EF#$BB#$BF;
var
  L: TStringList;
  I: Integer;
  S: string;
  F: TFileStream;
begin
  L := TStringList.Create;
  try
    if DelphiKeyExists('') then
      ListItems(L)
    else
    begin
      Writeln(ErrOutput, Format('migrate: no Delphi 7 configuration found (HKEY_CURRENT_USER\%s is missing)', [DelphiKey]));
      ExitCode := 3;
    end;
    if ListFile = '-' then
      for I := 0 to L.Count - 1 do Writeln(L[I])
    else
    begin
      S := Bom + L.Text;
      F := TFileStream.Create(ListFile, fmCreate);
      try
        F.WriteBuffer(S[1], Length(S));
      finally
        F.Free;
      end;
    end;
  finally
    L.Free;
  end;
end;

procedure Run;
begin
  if ListFile <> '' then
  begin
    WriteItems;
    Exit;
  end;
  if not IsStudioFolder(StudioRoot) then
    raise EUsage.CreateFmt('%s is not a D7 Studio folder (it has no D7Studio.exe)', [StudioRoot]);
  if not RunMigration(Parts, False) then ExitCode := 3;
end;

var
  OldCP: UINT;

begin
  if ParamCount = 0 then
  begin
    { the dialog for the D7 Studio of this folder; the console window it was started with goes }
    FreeConsole;
    Application.Initialize;
    TMigrateDlg.Execute(nil, '', 'Software\Borland\Delphi\7.0', ExtractFilePath(ParamStr(0)),
      ExtractFilePath(ParamStr(0)), 'Software\D7Studio');
    Exit;
  end;
  OldCP := GetConsoleOutputCP;
  SetConsoleOutputCP(CP_UTF8);
  Parts := TStringList.Create;
  try
    try
      if not ParseArgs then Usage else Run;
    except
      on E: EUsage do
      begin
        Writeln(ErrOutput, 'migrate: ', E.Message);
        ExitCode := 2;
      end;
      on E: EMigrate do
      begin
        Writeln(ErrOutput, 'migrate: ', E.Message);
        ExitCode := 1;
      end;
      on E: Exception do
      begin
        Writeln(ErrOutput, 'migrate: ', E.ClassName, ': ', E.Message);
        ExitCode := 1;
      end;
    end;
  finally
    Parts.Free;
    SetConsoleOutputCP(OldCP);
  end;
end.
