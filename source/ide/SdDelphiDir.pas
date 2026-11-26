{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDelphiDir;

{ D7 Studio - where Delphi 7's files are: one lookup for every part of the IDE that reads them
  (the compiler, the packages, the library and its sources, the repository, the images of
  Delphi's commands, the default project icon ...).

  D7 Studio runs with an installed Delphi 7 (its Lib and Bin may hold the modernized RTL/VCL):
  Delphi's files are that installation's - its folder is RootDir of Delphi's registry key, its
  Bin a folder of its own. Where D7Studio.exe lies does not matter (bin\, or copied into
  Delphi's Bin). }

interface

{ the folder of Delphi's files with a trailing backslash: the installed Delphi 7's folder,
  RootDir of Software\Borland\Delphi\7.0 - the user's key first, then the machine's -, else its
  default folder; the environment variable D7S_DELPHI names another one. $(DELPHI) of Delphi's
  paths is this folder. Looked up once. }
function DelphiRoot: string;

{ the folder of the files Delphi 7 keeps in its Bin, with a trailing backslash: DelphiRoot + 'Bin\' }
function DelphiBin: string;

{ S with $(DELPHI) and $(BDS) (any case) replaced by DelphiRoot without its trailing backslash }
function ExpandDelphiMacros(const S: string): string;

{ a file or folder under DelphiRoot as $(DELPHI)\..., any other as it is: the lists D7 Studio
  writes (the installed packages, its repository) stay right when its folder is moved }
function CollapseDelphiMacros(const FileName: string): string;

{ a folder list (Path: folders separated by ';') names Dir, with or without its trailing backslash,
  in any case }
function PathHasDir(const Path, Dir: string): Boolean;

implementation

uses
  Windows, Registry, SysUtils;

var
  Root: string;

{ RootDir of Delphi 7's registry key, '' when there is none }
function InstalledDelphi: string;
var
  Reg: TRegistry;
begin
  Result := '';
  Reg := TRegistry.Create(KEY_READ);
  try
    try
      Reg.RootKey := HKEY_CURRENT_USER;
      if Reg.OpenKeyReadOnly('Software\Borland\Delphi\7.0') then
      begin
        Result := Reg.ReadString('RootDir');
        Reg.CloseKey;
      end;
      if Result = '' then
      begin
        Reg.RootKey := HKEY_LOCAL_MACHINE;
        if Reg.OpenKeyReadOnly('SOFTWARE\Borland\Delphi\7.0') then
        begin
          Result := Reg.ReadString('RootDir');
          Reg.CloseKey;
        end;
      end;
    except
      Result := '';
    end;
  finally
    Reg.Free;
  end;
end;

function DelphiRoot: string;
begin
  if Root = '' then
  begin
    Root := GetEnvironmentVariable('D7S_DELPHI');
    if Root <> '' then Root := ExpandFileName(Root)
    else
    begin
      Root := InstalledDelphi;
      if Root = '' then Root := 'C:\Program Files (x86)\Borland\Delphi7';
    end;
    Root := IncludeTrailingPathDelimiter(Root);
  end;
  Result := Root;
end;

function DelphiBin: string;
begin
  Result := DelphiRoot + 'Bin\';
end;

function ExpandDelphiMacros(const S: string): string;
var
  R: string;
begin
  R := ExcludeTrailingPathDelimiter(DelphiRoot);
  Result := StringReplace(S, '$(DELPHI)', R, [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '$(BDS)', R, [rfReplaceAll, rfIgnoreCase]);
end;

function CollapseDelphiMacros(const FileName: string): string;
var
  R: string;
begin
  R := DelphiRoot;
  if SameText(Copy(FileName, 1, Length(R)), R) then
    Result := '$(DELPHI)\' + Copy(FileName, Length(R) + 1, MaxInt)
  else
    Result := FileName;
end;

function PathHasDir(const Path, Dir: string): Boolean;
var
  P, D: string;
begin
  P := ';' + AnsiLowerCase(Path) + ';';
  D := ';' + AnsiLowerCase(ExcludeTrailingPathDelimiter(Dir));
  Result := (Pos(D + ';', P) > 0) or (Pos(D + '\;', P) > 0);
end;

end.
