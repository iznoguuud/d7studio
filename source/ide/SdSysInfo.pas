{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdSysInfo;

{ D7 Studio - what the system it runs on is: Windows' release and machine (Help | About, the bug
  report), the version of a program file. }

interface

const
  { D7 Studio's public repository: its releases and its issues }
  RepositoryUrl = 'https://github.com/iznoguuud/d7studio';

{ "Windows 11 25H2 (build 26200.7171), x64": the real version (no manifest's compatibility
  answer), Windows 11 being 10.0 from build 22000 on, and the machine Windows runs on }
function WindowsDescription: string;

{ the file version of a program file's version resource, "1.0.0.0"; '' when it has none }
function FileVersionOf(const FileName: string): string;

implementation

uses
  Windows, SysUtils, WindowsEx;

{ Windows' version key, read in the 64-bit view on 64-bit Windows: its DisplayVersion ("25H2") and
  UBR (the update build revision); '' / -1 when a value is missing (Windows before 10) }
procedure ReadWindowsRelease(out DisplayVersion: string; out Revision: Integer);
var
  Key: HKEY;
  Kind, Size, Value: DWORD;
  Buf: array[0..63] of Char;
begin
  DisplayVersion := '';
  Revision := -1;
  if RegOpenKeyEx(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\Windows NT\CurrentVersion', 0,
    KEY_READ or KEY_WOW64_64KEY, Key) <> ERROR_SUCCESS then Exit;
  try
    Size := SizeOf(Buf) - 1;
    if (RegQueryValueEx(Key, 'DisplayVersion', nil, @Kind, @Buf, @Size) = ERROR_SUCCESS) and
      (Kind = REG_SZ) then
    begin
      Buf[Size] := #0;
      DisplayVersion := Trim(Buf);
    end;
    Size := SizeOf(Value);
    if (RegQueryValueEx(Key, 'UBR', nil, @Kind, @Value, @Size) = ERROR_SUCCESS) and
      (Kind = REG_DWORD) then Revision := Value;
  finally
    RegCloseKey(Key);
  end;
end;

function WindowsDescription: string;
var
  Major, Minor, Build: Cardinal;
  Release, Name: string;
  Revision: Integer;
  ProcessMachine, NativeMachine: Word;
begin
  if not GetRealWindowsVersion(Major, Minor, Build) then
  begin
    Result := 'Windows';
    Exit;
  end;
  if (Major = 10) and (Build >= 22000) then Name := 'Windows 11'
  else if Major = 10 then Name := 'Windows 10'
  else if (Major = 6) and (Minor = 3) then Name := 'Windows 8.1'
  else if (Major = 6) and (Minor = 2) then Name := 'Windows 8'
  else if (Major = 6) and (Minor = 1) then Name := 'Windows 7'
  else if (Major = 6) and (Minor = 0) then Name := 'Windows Vista'
  else Name := Format('Windows %d.%d', [Major, Minor]);
  ReadWindowsRelease(Release, Revision);
  if Release <> '' then Name := Name + ' ' + Release;
  if Revision >= 0 then
    Result := Format('%s (build %d.%d)', [Name, Build, Revision])
  else
    Result := Format('%s (build %d)', [Name, Build]);
  if IsWow64Process2(GetCurrentProcess, ProcessMachine, @NativeMachine) then
    case NativeMachine of
      IMAGE_FILE_MACHINE_AMD64: Result := Result + ', x64';
      IMAGE_FILE_MACHINE_ARM64: Result := Result + ', ARM64';
      IMAGE_FILE_MACHINE_I386: Result := Result + ', x86';
    end;
end;

function FileVersionOf(const FileName: string): string;
var
  Size, Dummy: DWORD;
  Buf: string;
  Fixed: PVSFixedFileInfo;
  Len: UINT;
begin
  Result := '';
  Size := GetFileVersionInfoSize(PChar(FileName), Dummy);
  if Size = 0 then Exit;
  SetLength(Buf, Size);
  if not GetFileVersionInfo(PChar(FileName), 0, Size, PChar(Buf)) then Exit;
  if not VerQueryValue(PChar(Buf), '\', Pointer(Fixed), Len) or (Len < SizeOf(TVSFixedFileInfo)) then Exit;
  if Fixed^.dwSignature <> $FEEF04BD then Exit;
  Result := Format('%d.%d.%d.%d', [HiWord(Fixed^.dwFileVersionMS), LoWord(Fixed^.dwFileVersionMS),
    HiWord(Fixed^.dwFileVersionLS), LoWord(Fixed^.dwFileVersionLS)]);
end;

end.
