{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

program bugreport;

{ Makes a bug report of D7 Studio from its crash log: error.log read, its call stacks resolved
  again from the modules' map files (D7Studio.map beside D7Studio.exe), with the system, the
  packages and experts, the errors grouped and the source lines of their frames, written as
  bugreport.txt (BugCore).

    bugreport [<error.log>] [options]

    <error.log>          the log (default: error.log of D7 Studio's settings, beside
                         bugreport.exe - D7S_HOME names another folder)
    -Out <file>          the report (default: bugreport.txt beside the log)
    -Last <n>            only the newest n entries of the log
    -Source <folder>     another folder of sources for the frames' lines, with its subfolders
                         (more than one: repeat it); D7 Studio's source\ beside bin\ and Delphi
                         7's Source are always searched
    -Context <n>         source lines shown before and after a frame's line (default 3; -1: none)
    -Open                open the report when it is written
    -NoOpen              do not open it, also with a console of its own

  With a console of its own - started from Explorer - it opens the report too. A program that
  starts it without a window (CREATE_NO_WINDOW) gives it a console of its own as well: D7 Studio's
  Help | Create Bug Report passes -NoOpen and opens the report in its editor. Exit code 0: written;
  1: an error; 2: wrong arguments. }

{$APPTYPE CONSOLE}

uses
  ModernManUtf8,
  Windows,
  SysUtils,
  Classes,
  ShellAPI,
  SdDbgTD32 in 'debugger\SdDbgTD32.pas',
  SdDelphiDir in 'ide\SdDelphiDir.pas',
  SdSettings in 'ide\SdSettings.pas',
  SdSysInfo in 'ide\SdSysInfo.pas',
  BugCore in 'bugreport\BugCore.pas';

function GetConsoleProcessList(List: PDWORD; Count: DWORD): DWORD; stdcall;
  external kernel32 name 'GetConsoleProcessList';

procedure Usage;
begin
  Writeln('bugreport [<error.log>] [-Out <file>] [-Last <n>] [-Source <folder>] [-Context <n>] [-Open | -NoOpen]');
  Writeln('  Makes a bug report (bugreport.txt) of D7 Studio''s crash log (error.log).');
end;

{ the console is this program's alone: it was started from Explorer, and the window closes with it -
  or without a window by another program, which says so with -NoOpen }
function OwnConsole: Boolean;
var
  Ids: array[0..1] of DWORD;
begin
  Result := GetConsoleProcessList(@Ids[0], 2) = 1;
end;

var
  Options: TBugReportOptions;
  Sources: TStringList;
  I: Integer;
  A, Summary: string;
  Open, NoOpen: Boolean;
begin
  Sources := TStringList.Create;
  try
    FillChar(Options, SizeOf(Options), 0);
    Options.Context := 3;
    Options.SourceDirs := Sources;
    Open := False;
    NoOpen := False;
    I := 1;
    while I <= ParamCount do
    begin
      A := ParamStr(I);
      if (A <> '') and (A[1] in ['-', '/']) then
      begin
        Delete(A, 1, 1);
        if SameText(A, 'Open') then
          Open := True
        else if SameText(A, 'NoOpen') then
          NoOpen := True
        else if SameText(A, '?') or SameText(A, 'Help') or SameText(A, 'h') then
        begin
          Usage;
          Exit;
        end
        else if I = ParamCount then
        begin
          Writeln('bugreport: -', A, ' needs a value');
          ExitCode := 2;
          Exit;
        end
        else
        begin
          Inc(I);
          if SameText(A, 'Out') then
            Options.OutFile := ParamStr(I)
          else if SameText(A, 'Source') then
            Sources.Add(ParamStr(I))
          else if SameText(A, 'Last') then
            Options.Last := StrToIntDef(ParamStr(I), -1)
          else if SameText(A, 'Context') then
            Options.Context := StrToIntDef(ParamStr(I), -2)
          else
          begin
            Writeln('bugreport: unknown option -', A);
            Usage;
            ExitCode := 2;
            Exit;
          end;
          if (Options.Last < 0) or (Options.Context < -1) then
          begin
            Writeln('bugreport: -', A, ' needs a number');
            ExitCode := 2;
            Exit;
          end;
        end;
      end
      else if Options.LogFile = '' then
        Options.LogFile := A
      else
      begin
        Writeln('bugreport: one log only (', A, ')');
        ExitCode := 2;
        Exit;
      end;
      Inc(I);
    end;
    if Options.LogFile = '' then Options.LogFile := SettingsDir + 'error.log';
    Options.LogFile := ExpandFileName(Options.LogFile);
    if Options.OutFile = '' then Options.OutFile := ExtractFilePath(Options.LogFile) + 'bugreport.txt';
    Options.OutFile := ExpandFileName(Options.OutFile);
    try
      WriteBugReport(Options, Summary);
    except
      on E: Exception do
      begin
        Writeln('bugreport: ', E.Message);
        ExitCode := 1;
        Exit;
      end;
    end;
    Writeln(Options.OutFile, ': ', Summary);
    if Open or (OwnConsole and not NoOpen) then
      ShellExecute(0, 'open', PChar(Options.OutFile), nil, nil, SW_SHOWNORMAL);
  finally
    Sources.Free;
  end;
end.
