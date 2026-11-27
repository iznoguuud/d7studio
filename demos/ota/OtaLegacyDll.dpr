{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

library OtaLegacyDll;

{ D7 Studio's demo of Delphi 1-3's expert API in a DLL, built as such experts were for Delphi 2 and 3:
  without run-time packages, with ShareMem as its first unit. The IDE allocates from borlndmm.dll
  as well (D7 Studio as Delphi 7), so strings go both ways - GetName, GetMenuText, the module's
  name and the project's name below.

  The IDE calls its entry point INITEXPERT0017 (ExptIntf.ExpertEntryPoint) with ToolServices; the
  expert (esStandard) is the item Help | OTA Legacy DLL: New unit, which makes a unit through
  ToolServices.CreateModule from a stream (into OTALEGACY_SELFTEST_DIR when the environment names
  one, else under GetNewModuleName's name).

  Build it with dcc32 alone, the ToolsAPI sources on the search path (ExptIntf, ToolIntf, EditIntf
  are compiled into the DLL): dcc32 -U<Delphi>\Source\ToolsAPI OtaLegacyDll.dpr - borlndmm.dll must
  be next to the IDE. Name it in D7 Studio's settings, [Experts] OtaLegacyDll=<its path>, or as
  Delphi 7 does in the registry: a string value under HKEY_CURRENT_USER\Software\D7Studio\Experts. }

{$WARN UNIT_DEPRECATED OFF}
{$WARN SYMBOL_DEPRECATED OFF}

uses
  ShareMem, Windows, SysUtils, Classes, VirtIntf, ExptIntf, ToolIntf, EditIntf;

type
  TLegacyDllExpert = class(TIExpert)
  public
    function GetName: string; override;
    function GetAuthor: string; override;
    function GetComment: string; override;
    function GetPage: string; override;
    function GetGlyph: HICON; override;
    function GetStyle: TExpertStyle; override;
    function GetState: TExpertState; override;
    function GetIDString: string; override;
    function GetMenuText: string; override;
    procedure Execute; override;
  end;

function TLegacyDllExpert.GetName: string;
begin
  Result := 'OTA Legacy DLL';
end;

function TLegacyDllExpert.GetAuthor: string;
begin
  Result := 'D7 Studio';
end;

function TLegacyDllExpert.GetComment: string;
begin
  Result := 'An expert of Delphi 1-3 in a DLL built with ShareMem';
end;

function TLegacyDllExpert.GetPage: string;
begin
  Result := '';
end;

function TLegacyDllExpert.GetGlyph: HICON;
begin
  Result := 0;
end;

function TLegacyDllExpert.GetStyle: TExpertStyle;
begin
  Result := esStandard;
end;

function TLegacyDllExpert.GetState: TExpertState;
begin
  Result := [esEnabled];
end;

function TLegacyDllExpert.GetIDString: string;
begin
  Result := 'D7Studio.OtaLegacyDll';
end;

function TLegacyDllExpert.GetMenuText: string;
begin
  Result := 'OTA Legacy DLL: New unit';
end;

{ a unit from a stream; its text names the project ToolServices gives (a string of the IDE's,
  freed here) }
procedure TLegacyDllExpert.Execute;
var
  Dir, UnitIdent, Name, Src: string;
begin
  Dir := GetEnvironmentVariable('OTALEGACY_SELFTEST_DIR');
  if Dir <> '' then Name := IncludeTrailingPathDelimiter(Dir) + 'LegacyDllUnit.pas'
  else if not ToolServices.GetNewModuleName(UnitIdent, Name) then Exit;
  Src :=
    'unit ' + ChangeFileExt(ExtractFileName(Name), '') + ';'#13#10#13#10 +
    '{ made by OtaLegacyDll.dll; the project: ' + ExtractFileName(ToolServices.GetProjectName) + ' }'#13#10#13#10 +
    'interface'#13#10#13#10 +
    'implementation'#13#10#13#10 +
    'end.'#13#10;
  ToolServices.CreateModule(Name, TStreamAdapter.Create(TStringStream.Create(Src), soOwned), nil, [cmShowSource]);
end;

procedure DoneExpert;
begin
  { the IDE frees the expert it was given }
end;

function InitExpert(Services: TIToolServices; RegisterProc: TExpertRegisterProc;
  var Terminate: TExpertTerminateProc): Boolean; stdcall;
begin
  ToolServices := Services;
  Terminate := DoneExpert;
  Result := RegisterProc(TLegacyDllExpert.Create);
end;

exports
  InitExpert name ExpertEntryPoint;

begin
end.
