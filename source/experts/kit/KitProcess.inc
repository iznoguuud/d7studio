{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

{ Running a console program with its output captured, for the IDE experts (source\experts\kit: the AI
  harness's unit AiProcess, the Git expert's GitProcess). The program runs without a window and
  without stdin; it inherits nothing of the IDE but its pipes (Windows Vista and later: a handle
  list), so a program it starts in turn cannot hold the IDE's handles. Its output is read while it
  runs, from pipes large enough that it rarely waits for them. The command line goes to Windows as
  UTF-16: names outside the IDE's code page reach the program as they are. The program runs in a
  job object of its own: a cancel or a timeout ends it with every program it started (Git for
  Windows' cmd\git.exe is a launcher that starts the real git, which starts its helpers).
  The unit (interface: uses Windows, SysUtils, Classes; implementation: uses the expert's text
  unit of KitText.inc) includes this file in its interface with KIT_INTERFACE defined and again in
  its implementation. }

{$IFDEF KIT_INTERFACE}

type
  { asked while a program runs: True ends it }
  TKitCancelQuery = function: Boolean of object;

{ runs CommandLine in Dir (UTF-16; Dir '': the current folder) and returns its exit code. Output gets
  what it wrote to stdout and Errors what it wrote to stderr - with MergeErrors both go into Output,
  in the order written, and Errors stays empty. Env: lines 'NAME=value' (IDE strings) set for the
  program over the IDE's environment; nil: the IDE's as it is. Ends the program after TimeoutMs, or
  when Cancelled answers True: then the result is -1. Raises EOSError when it cannot be started. }
function RunProcess(const CommandLine, Dir: WideString; Env: TStrings; MergeErrors: Boolean;
  out Output, Errors: string; TimeoutMs: Cardinal; Cancelled: TKitCancelQuery): Integer;

{ RunProcess with CommandLine and Dir as IDE strings, stdout and stderr into Output }
function RunConsole(const CommandLine, Dir: string; out Output: string; TimeoutMs: Cardinal;
  Cancelled: TKitCancelQuery): Integer;

{$ELSE}

type
  TStartupInfoEx = record
    StartupInfo: TStartupInfo;
    lpAttributeList: Pointer;
  end;
  TInitAttrList = function(lpAttributeList: Pointer; dwAttributeCount, dwFlags: DWORD; var lpSize: DWORD): BOOL; stdcall;
  TUpdateAttr = function(lpAttributeList: Pointer; dwFlags, Attribute: DWORD; lpValue: Pointer; cbSize: DWORD;
    lpPreviousValue, lpReturnSize: Pointer): BOOL; stdcall;
  TDeleteAttrList = procedure(lpAttributeList: Pointer); stdcall;

const
  EXTENDED_STARTUPINFO_PRESENT = $00080000;
  PROC_THREAD_ATTRIBUTE_HANDLE_LIST = $00020002;
  CREATE_UNICODE_ENVIRONMENT = $00000400;
  PipeSize = 1024 * 1024;

{ job objects (Windows 2000 and later; Delphi 7's Windows unit has none) }
function CreateJobObjectW(lpJobAttributes: PSecurityAttributes; lpName: PWideChar): THandle; stdcall;
  external kernel32 name 'CreateJobObjectW';
function AssignProcessToJobObject(hJob, hProcess: THandle): BOOL; stdcall;
  external kernel32 name 'AssignProcessToJobObject';
function TerminateJobObject(hJob: THandle; uExitCode: UINT): BOOL; stdcall;
  external kernel32 name 'TerminateJobObject';

{ the name of an entry 'NAME=value' in capitals (an entry may begin with '=': '=C:=C:\...') }
function EnvName(const S: WideString): WideString;
var
  I: Integer;
begin
  I := 2;
  while (I <= Length(S)) and (S[I] <> '=') do Inc(I);
  Result := WideUpperCase(Copy(S, 1, I - 1));
end;

{ the order of Windows' environment blocks: by the names in capitals, code unit by code unit }
function CompareEnvNames(const A, B: WideString): Integer;
var
  I: Integer;
begin
  for I := 1 to Length(A) do
  begin
    if I > Length(B) then
    begin
      Result := 1;
      Exit;
    end;
    Result := Ord(A[I]) - Ord(B[I]);
    if Result <> 0 then Exit;
  end;
  Result := Length(A) - Length(B);
end;

{ the IDE's environment with the variables of Env set, as a block of CreateProcessW }
function EnvironmentBlock(Env: TStrings): WideString;
var
  Items, Names: array of WideString;    // the entries, and their names in capitals
  N, I, J: Integer;
  Block, P: PWideChar;
  S, Name: WideString;
  Found: Boolean;
  B: TKitStringBuilder;

  procedure Put(const Entry, EntryName: WideString);
  begin
    if N = Length(Items) then
    begin
      SetLength(Items, N * 2 + 16);
      SetLength(Names, N * 2 + 16);
    end;
    Items[N] := Entry;
    Names[N] := EntryName;
    Inc(N);
  end;

begin
  N := 0;
  Block := GetEnvironmentStringsW;
  try
    P := Block;
    while P^ <> #0 do
    begin
      S := P;
      Inc(P, Length(S) + 1);
      Put(S, EnvName(S));
    end;
  finally
    FreeEnvironmentStringsW(Block);
  end;
  for I := 0 to Env.Count - 1 do
  begin
    S := CodePageToWide(Env[I], CP_ACP);
    Name := EnvName(S);
    Found := False;
    for J := 0 to N - 1 do
      if Names[J] = Name then
      begin
        Items[J] := S;
        Found := True;
        Break;
      end;
    if not Found then Put(S, Name);
  end;
  { insertion sort: the block is almost in order already }
  for I := 1 to N - 1 do
  begin
    S := Items[I];
    Name := Names[I];
    J := I - 1;
    while (J >= 0) and (CompareEnvNames(Names[J], Name) > 0) do
    begin
      Items[J + 1] := Items[J];
      Names[J + 1] := Names[J];
      Dec(J);
    end;
    Items[J + 1] := S;
    Names[J + 1] := Name;
  end;
  { built as bytes: Delphi 7 copies a WideString at every concatenation }
  B := TKitStringBuilder.Create;
  try
    for I := 0 to N - 1 do
    begin
      B.Append(PChar(PWideChar(Items[I])), Length(Items[I]) * 2);
      B.Append(#0#0);
    end;
    B.Append(#0#0);
    S := '';
    SetLength(S, B.Length div 2);
    Move(PChar(B.Text)^, PWideChar(S)^, B.Length);
    Result := S;
  finally
    B.Free;
  end;
end;

function RunProcess(const CommandLine, Dir: WideString; Env: TStrings; MergeErrors: Boolean;
  out Output, Errors: string; TimeoutMs: Cardinal; Cancelled: TKitCancelQuery): Integer;
var
  SA: TSecurityAttributes;
  OutRead, OutWrite, ErrRead, ErrWrite: THandle;
  SI: TStartupInfoEx;
  PI: TProcessInformation;
  Buf: array[0..65535] of Char;
  Avail, Read, Code, Size, Flags: DWORD;
  Started: Cardinal;
  OutB, ErrB: TKitStringBuilder;
  Cmd, EnvBlock: WideString;
  EnvPtr: Pointer;
  DirPtr: PWideChar;
  Done, Inited: Boolean;
  Kernel: HMODULE;
  InitList: TInitAttrList;
  UpdateAttr: TUpdateAttr;
  DeleteList: TDeleteAttrList;
  List: Pointer;
  Handles: array[0..1] of THandle;
  HandleCount: Integer;
  Job: THandle;

  { what is in the pipe now; never waits for more }
  procedure Drain(Pipe: THandle; B: TKitStringBuilder);
  begin
    if Pipe = 0 then Exit;
    while PeekNamedPipe(Pipe, nil, 0, nil, @Avail, nil) and (Avail > 0) do
    begin
      if not ReadFile(Pipe, Buf, SizeOf(Buf), Read, nil) or (Read = 0) then Break;
      B.Append(Buf, Read);
    end;
  end;

begin
  Result := -1;
  Output := '';
  Errors := '';
  OutRead := 0;
  OutWrite := 0;
  ErrRead := 0;
  ErrWrite := 0;
  FillChar(SA, SizeOf(SA), 0);
  SA.nLength := SizeOf(SA);
  SA.bInheritHandle := True;
  OutB := TKitStringBuilder.Create;
  ErrB := TKitStringBuilder.Create;
  List := nil;
  Inited := False;
  DeleteList := nil;
  Job := 0;
  try
    if not CreatePipe(OutRead, OutWrite, @SA, PipeSize) then RaiseLastOSError;
    SetHandleInformation(OutRead, HANDLE_FLAG_INHERIT, 0);
    Handles[0] := OutWrite;
    HandleCount := 1;
    if not MergeErrors then
    begin
      if not CreatePipe(ErrRead, ErrWrite, @SA, PipeSize) then RaiseLastOSError;
      SetHandleInformation(ErrRead, HANDLE_FLAG_INHERIT, 0);
      Handles[1] := ErrWrite;
      HandleCount := 2;
    end;
    FillChar(SI, SizeOf(SI), 0);
    SI.StartupInfo.cb := SizeOf(TStartupInfo);
    SI.StartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    SI.StartupInfo.wShowWindow := SW_HIDE;
    SI.StartupInfo.hStdInput := 0;
    SI.StartupInfo.hStdOutput := OutWrite;
    if MergeErrors then SI.StartupInfo.hStdError := OutWrite else SI.StartupInfo.hStdError := ErrWrite;
    Flags := CREATE_NO_WINDOW;
    { Windows Vista and later: the process inherits the pipes only, not every inheritable handle
      of the IDE }
    Kernel := GetModuleHandle(kernel32);
    InitList := GetProcAddress(Kernel, 'InitializeProcThreadAttributeList');
    UpdateAttr := GetProcAddress(Kernel, 'UpdateProcThreadAttribute');
    DeleteList := GetProcAddress(Kernel, 'DeleteProcThreadAttributeList');
    if Assigned(InitList) and Assigned(UpdateAttr) and Assigned(DeleteList) then
    begin
      Size := 0;
      InitList(nil, 1, 0, Size);
      GetMem(List, Size);
      Inited := InitList(List, 1, 0, Size);
      if Inited and UpdateAttr(List, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST, @Handles[0],
        HandleCount * SizeOf(THandle), nil, nil) then
      begin
        SI.StartupInfo.cb := SizeOf(TStartupInfoEx);
        SI.lpAttributeList := List;
        Flags := Flags or EXTENDED_STARTUPINFO_PRESENT;
      end;
    end;
    EnvPtr := nil;
    if Env <> nil then
    begin
      EnvBlock := EnvironmentBlock(Env);
      EnvPtr := PWideChar(EnvBlock);
      Flags := Flags or CREATE_UNICODE_ENVIRONMENT;
    end;
    if Dir <> '' then DirPtr := PWideChar(Dir) else DirPtr := nil;
    { started suspended, put into its job, then let go: what it starts comes into the job too }
    Job := CreateJobObjectW(nil, nil);
    if Job <> 0 then Flags := Flags or CREATE_SUSPENDED;
    { CreateProcessW may write into the command line: a copy of its own (WideStrings are never
      shared in Delphi 7) }
    Cmd := CommandLine;
    if not CreateProcessW(nil, PWideChar(Cmd), nil, nil, True, Flags, EnvPtr, DirPtr, SI.StartupInfo, PI) then
      RaiseLastOSError;
    { a job the IDE runs in itself may refuse it (Windows 7): then the program alone is ended }
    if (Job <> 0) and not AssignProcessToJobObject(Job, PI.hProcess) then
    begin
      CloseHandle(Job);
      Job := 0;
    end;
    if Flags and CREATE_SUSPENDED <> 0 then ResumeThread(PI.hThread);
    CloseHandle(OutWrite);
    OutWrite := 0;
    if ErrWrite <> 0 then
    begin
      CloseHandle(ErrWrite);
      ErrWrite := 0;
    end;
    try
      Started := GetTickCount;
      repeat
        Drain(OutRead, OutB);
        Drain(ErrRead, ErrB);
        Done := WaitForSingleObject(PI.hProcess, 15) = WAIT_OBJECT_0;
        if not Done and ((Assigned(Cancelled) and Cancelled) or (GetTickCount - Started > TimeoutMs)) then
        begin
          if Job <> 0 then TerminateJobObject(Job, 1) else TerminateProcess(PI.hProcess, 1);
          WaitForSingleObject(PI.hProcess, 5000);
          Drain(OutRead, OutB);
          Drain(ErrRead, ErrB);
          Output := OutB.Text;
          Errors := ErrB.Text;
          Exit;
        end;
      until Done;
      { what it wrote before it ended is in the pipes: read without waiting (a process that
        inherited a pipe from it could keep it open) }
      Drain(OutRead, OutB);
      Drain(ErrRead, ErrB);
      Code := 0;
      GetExitCodeProcess(PI.hProcess, Code);
      Result := Integer(Code);
      Output := OutB.Text;
      Errors := ErrB.Text;
    finally
      CloseHandle(PI.hThread);
      CloseHandle(PI.hProcess);
    end;
  finally
    { closing the job ends nothing: a program that is left (a background gc) goes on }
    if Job <> 0 then CloseHandle(Job);
    if Inited then DeleteList(List);
    if List <> nil then FreeMem(List);
    if OutWrite <> 0 then CloseHandle(OutWrite);
    if ErrWrite <> 0 then CloseHandle(ErrWrite);
    if OutRead <> 0 then CloseHandle(OutRead);
    if ErrRead <> 0 then CloseHandle(ErrRead);
    OutB.Free;
    ErrB.Free;
  end;
end;

function RunConsole(const CommandLine, Dir: string; out Output: string; TimeoutMs: Cardinal;
  Cancelled: TKitCancelQuery): Integer;
var
  Errors: string;
begin
  Result := RunProcess(CodePageToWide(CommandLine, CP_ACP), CodePageToWide(Dir, CP_ACP), nil, True,
    Output, Errors, TimeoutMs, Cancelled);
end;

{$ENDIF}
