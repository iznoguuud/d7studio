{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

library OtaVcsDemo;

{ D7 Studio's demo of Delphi 1-3's version control interface (VcsIntf): a VCS manager DLL. The IDE
  loads the DLL named in its settings, [Version Control] VCSManager=<its path> - or as Delphi 7
  reads it, the value VCSManager under HKEY_CURRENT_USER\Software\D7Studio\Version Control -, calls
  its entry point INITVCS0014 with a TIToolServices of its own, and makes the menu the client names
  (OTA VCS, before Tools) with one item per verb; an empty verb is a line.

    * Project changes: n - the count of ProjectChange calls (a project opened, made active, closed);
      the IDE asks the verbs' captions and states again whenever the menu drops down;
    * Log project files - writes the project's name and its files (GetVcsList) into the file the
      environment variable OTALEGACY_VCS_LOG names; checked from then on (GetVerbState).

  Built as such DLLs were for Delphi 2 and 3: without run-time packages, ShareMem first, the
  ToolsAPI sources on the search path (VcsIntf is a unit of Delphi's IDE, compiled into the DLL):
  dcc32 -U<Delphi>\Source\ToolsAPI OtaVcsDemo.dpr. }

{$WARN UNIT_DEPRECATED OFF}
{$WARN SYMBOL_DEPRECATED OFF}

uses
  ShareMem, Windows, SysUtils, Classes, VirtIntf, ToolIntf, VcsIntf;

type
  TDemoVcsClient = class(TIVCSClient)
  private
    FServices: TIToolServices;
    FChanges: Integer;
    FLogged: Boolean;
  public
    constructor Create(AServices: TIToolServices);
    function GetIDString: string; override;
    procedure ExecuteVerb(Index: Integer); override;
    function GetMenuName: string; override;
    function GetVerb(Index: Integer): string; override;
    function GetVerbCount: Integer; override;
    function GetVerbState(Index: Integer): Word; override;
    procedure ProjectChange; override;
  end;

constructor TDemoVcsClient.Create(AServices: TIToolServices);
begin
  inherited Create;
  FServices := AServices;
end;

function TDemoVcsClient.GetIDString: string;
begin
  Result := 'D7Studio.OtaVcsDemo';
end;

function TDemoVcsClient.GetMenuName: string;
begin
  Result := 'OTA VCS';
end;

function TDemoVcsClient.GetVerbCount: Integer;
begin
  Result := 3;
end;

function TDemoVcsClient.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := Format('Project changes: %d', [FChanges]);
    2: Result := 'Log project files';
  else
    Result := '';
  end;
end;

function TDemoVcsClient.GetVerbState(Index: Integer): Word;
begin
  Result := vsEnabled;
  if (Index = 2) and FLogged then Result := Result or vsChecked;
end;

procedure TDemoVcsClient.ExecuteVerb(Index: Integer);
var
  L: TStringList;
  Log: string;
begin
  if Index <> 2 then Exit;
  Log := GetEnvironmentVariable('OTALEGACY_VCS_LOG');
  L := TStringList.Create;
  try
    FServices.GetVcsList(L);
    L.Insert(0, Format('project=%s changes=%d files=%d', [FServices.GetProjectName, FChanges, FServices.GetVcsCount]));
    if Log <> '' then L.SaveToFile(Log);
  finally
    L.Free;
  end;
  FLogged := True;
end;

procedure TDemoVcsClient.ProjectChange;
begin
  Inc(FChanges);
end;

function InitVcs(VCSInterface: TIToolServices): TIVCSClient; stdcall;
begin
  Result := TDemoVcsClient.Create(VCSInterface);
end;

exports
  InitVcs name VCSManagerEntryPoint;

begin
end.
