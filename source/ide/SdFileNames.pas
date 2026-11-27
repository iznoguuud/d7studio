{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdFileNames;

{ D7 Studio - file names outside the system code page.

  Delphi 7's RTL and VCL take file names in the process's code page - D7 Studio's is UTF-8 (UTF-8
  mode, its manifest): every name is usable as it is. Outside UTF-8 mode, a file whose name has
  characters the code page lacks (Greek on a Western system, Chinese, ...) gets a "usable" name:

    * its short 8.3 name, plain ASCII, where the drive has short names - every part of the IDE
      and the compiler can use it;
    * otherwise a marked name, '?U:' + the name in UTF-8 ('?' cannot be part of a Windows path).
      The editor reads and writes such a file (ReadFileU, WriteFileU ...), the compiler cannot:
      a project with such a name is opened as a plain file.

  dcc32 and the other programs of the system code page get CompilerPath's names.

  TSdFileDialog, the dropped files and the command line hand out usable names. Wherever the IDE
  shows a name it shows the real one (DisplayPath, UTF-16) - in the title bar, the file tabs and
  File | Reopen. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Forms, Dialogs, CommDlg, ShellAPI,
  SdEncoding;

const
  UnicodePathMark = '?U:';

type
  { Open and Save dialogs with Unicode names (GetOpenFileNameW / GetSaveFileNameW); the
    properties work like those of TOpenDialog, the names in Files and FileName are usable }
  TSdFileDialog = class(TComponent)
  private
    FTitle, FFilter, FDefaultExt, FFileName, FInitialDir: string;
    FOptions: TOpenOptions;
    FFiles: TStringList;
    function Run(Save: Boolean): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Execute: Boolean;            // open
    function ExecuteSave: Boolean;        // save as
    property Title: string read FTitle write FTitle;
    property Filter: string read FFilter write FFilter;
    property DefaultExt: string read FDefaultExt write FDefaultExt;
    property FileName: string read FFileName write FFileName;
    property InitialDir: string read FInitialDir write FInitialDir;
    property Options: TOpenOptions read FOptions write FOptions;
    property Files: TStringList read FFiles;
  end;

  TSdFileStamp = record
    Exists: Boolean;
    Time: TFileTime;                      // last write, UTC
    Size: Int64;
  end;

{ the usable name of a Unicode name: itself, its short name, or the marked name }
function UsablePath(const W: WideString): string;
{ a file or folder name as dcc32 and the other programs of the system code page take it, in the
  IDE's text: the name itself when that code page has its characters (in UTF-8 mode D7 Studio's
  names may have any), else its short 8.3 name; CompilerPaths: each name of a ';' list }
function CompilerPath(const Path: string): string;
function CompilerPaths(const Paths: string): string;
function IsUnicodePath(const Path: string): Boolean;        // a marked name
function WidePath(const Path: string): WideString;          // a usable name in UTF-16
{ the real name of a usable one (the long name, UTF-16) }
function DisplayPath(const Path: string): WideString;
{ the real name has characters the system code page does not have }
function NeedsUnicode(const Path: string): Boolean;
function WideFileName(const W: WideString): WideString;          // the part after the last '\'
function WideChangeFileExt(const W: WideString; const Ext: WideString): WideString;
{ file access for usable names (marked ones too) }
function ExpandPathU(const Path: string): string;                // ExpandFileName
function FileExistsU(const Path: string): Boolean;
function FileAgeU(const Path: string): Integer;                  // as FileAge, -1 when missing
{ what tells that a file changed: its last write time (UTC, 100 ns - FileAgeU has DOS's 2
  seconds and misses a rewrite within them) and its size; Exists False when it is not there }
function FileStampU(const Path: string): TSdFileStamp;
function SameFileStamp(const A, B: TSdFileStamp): Boolean;
function ReadFileU(const Path: string): string;                  // the bytes of the file
procedure WriteFileU(const Path, Data: string);
{ a file under another name (not over a file there), a file gone: False - Windows' error in
  GetLastError }
function RenameFileU(const Path, NewPath: string): Boolean;
function DeleteFileU(const Path: string): Boolean;
{ the file as it is becomes <name>.~<ext>: Delphi 7's backup of a file before it is saved }
procedure BackupFileU(const Path: string);
{ the folder Path and those above it made where they are missing; False when one cannot be made }
function ForceDirectoriesU(const Path: string): Boolean;
{ Windows' folder for temporary files, with its backslash }
function TempFolder: string;
{ the folder Dir (with its backslash) and everything in it deleted, as far as it can be }
procedure RemoveTree(const Dir: string);
{ an Explorer window on the folder of FileName with the file selected (a folder: the folder itself) }
procedure ShowInExplorer(const FileName: string);
{ the files of a drop (WM_DROPFILES) and of the command line, as usable names }
procedure DroppedFiles(Drop: HDROP; L: TStrings);
{ the names an Open/Save dialog returned in its buffer (one; with MultiSelect the folder, #0, the
  names, #0#0), as usable names added to Files (TSdFileDialog) }
procedure DialogFileNames(Buf: PWideChar; MultiSelect: Boolean; Files: TStrings);
procedure CommandLineFiles(L: TStrings);
{ Unicode text where the VCL has ANSI: a window's caption, a tab of a tab control, a canvas }
procedure SetWindowTextUnicode(Wnd: HWND; const W: WideString);
procedure DrawTextUnicode(Canvas: TCanvas; const W: WideString; var R: TRect; Flags: Cardinal);
function TextWidthUnicode(Canvas: TCanvas; const W: WideString): Integer;

implementation

function GetLongPathNameW(lpszShortPath, lpszLongPath: PWideChar; cchBuffer: DWORD): DWORD; stdcall;
  external kernel32 name 'GetLongPathNameW';
function ReplaceFileW(lpReplacedFileName, lpReplacementFileName, lpBackupFileName: PWideChar;
  dwReplaceFlags: DWORD; lpExclude, lpReserved: Pointer): BOOL; stdcall; external kernel32 name 'ReplaceFileW';
function CommandLineToArgvW(lpCmdLine: PWideChar; var pNumArgs: Integer): PPWideChar; stdcall;
  external shell32 name 'CommandLineToArgvW';

function SystemString(const W: WideString; out Lost: Boolean): string;
begin
  Result := FromWide(W, CP_ACP, Lost);
end;

function IsUnicodePath(const Path: string): Boolean;
begin
  Result := Copy(Path, 1, Length(UnicodePathMark)) = UnicodePathMark;
end;

function WidePath(const Path: string): WideString;
begin
  if IsUnicodePath(Path) then
    Result := ToWide(Copy(Path, Length(UnicodePathMark) + 1, MaxInt), CP_UTF8)
  else
    Result := ToWide(Path, CP_ACP);
end;

function UsablePath(const W: WideString): string;
var
  Lost: Boolean;
  Buf: array[0..MAX_PATH] of WideChar;
  N: DWORD;
begin
  Result := SystemString(W, Lost);
  if not Lost then Exit;
  N := GetShortPathNameW(PWideChar(W), Buf, MAX_PATH);
  if (N > 0) and (N < MAX_PATH) then
  begin
    Result := SystemString(Buf, Lost);
    if not Lost then Exit;
  end;
  Result := UnicodePathMark + FromWide(W, CP_UTF8, Lost);
end;

function CompilerPath(const Path: string): string;
var
  W: WideString;
  Lost: Boolean;
  Buf: array[0..MAX_PATH] of WideChar;
  N: DWORD;
begin
  Result := Path;
  if not HasHighBytes(Path) or IsUnicodePath(Path) then Exit;
  IdeToSystem(Path, Lost);
  if not Lost then Exit;
  W := ToWide(Path, CP_ACP);
  N := GetShortPathNameW(PWideChar(W), Buf, MAX_PATH);
  if (N > 0) and (N < MAX_PATH) then Result := FromWide(WideString(Buf), CP_ACP, Lost);
end;

function CompilerPaths(const Paths: string): string;
var
  S: string;
  P: Integer;
begin
  Result := '';
  S := Paths;
  repeat
    P := Pos(';', S);
    if P = 0 then P := Length(S) + 1;
    if Result <> '' then Result := Result + ';';
    Result := Result + CompilerPath(Copy(S, 1, P - 1));
    Delete(S, 1, P);
  until S = '';
end;

function DisplayPath(const Path: string): WideString;
var
  Buf: array[0..1023] of WideChar;
  N: DWORD;
begin
  Result := WidePath(Path);
  if IsUnicodePath(Path) then Exit;
  N := GetLongPathNameW(PWideChar(Result), Buf, Length(Buf));
  if (N > 0) and (N < DWORD(Length(Buf))) then Result := Buf;
end;

function NeedsUnicode(const Path: string): Boolean;
begin
  SystemString(DisplayPath(Path), Result);
end;

function WideFileName(const W: WideString): WideString;
var
  I: Integer;
begin
  I := Length(W);
  while (I > 0) and (W[I] <> '\') and (W[I] <> ':') do Dec(I);
  Result := Copy(W, I + 1, MaxInt);
end;

function WideChangeFileExt(const W: WideString; const Ext: WideString): WideString;
var
  I: Integer;
begin
  I := Length(W);
  while (I > 0) and (W[I] <> '.') and (W[I] <> '\') do Dec(I);
  if (I > 0) and (W[I] = '.') then Result := Copy(W, 1, I - 1) + Ext else Result := W + Ext;
end;

{ --- file access --- }

function ExpandPathU(const Path: string): string;
begin
  if IsUnicodePath(Path) then Result := Path else Result := ExpandFileName(Path);
end;

function FileExistsU(const Path: string): Boolean;
var
  A: DWORD;
begin
  A := GetFileAttributesW(PWideChar(WidePath(Path)));
  Result := (A <> $FFFFFFFF) and (A and FILE_ATTRIBUTE_DIRECTORY = 0);
end;

function FileAgeU(const Path: string): Integer;
var
  Data: TWin32FileAttributeData;
  Local: TFileTime;
begin
  Result := -1;
  if GetFileAttributesExW(PWideChar(WidePath(Path)), GetFileExInfoStandard, @Data) and
    FileTimeToLocalFileTime(Data.ftLastWriteTime, Local) and
    not FileTimeToDosDateTime(Local, LongRec(Result).Hi, LongRec(Result).Lo) then
    Result := -1;
end;

function FileStampU(const Path: string): TSdFileStamp;
var
  Data: TWin32FileAttributeData;
begin
  FillChar(Result, SizeOf(Result), 0);
  if not GetFileAttributesExW(PWideChar(WidePath(Path)), GetFileExInfoStandard, @Data) or
    (Data.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY <> 0) then Exit;
  Result.Exists := True;
  Result.Time := Data.ftLastWriteTime;
  Int64Rec(Result.Size).Lo := Data.nFileSizeLow;
  Int64Rec(Result.Size).Hi := Data.nFileSizeHigh;
end;

function SameFileStamp(const A, B: TSdFileStamp): Boolean;
begin
  Result := (A.Exists = B.Exists) and (not A.Exists or ((A.Size = B.Size) and
    (A.Time.dwLowDateTime = B.Time.dwLowDateTime) and (A.Time.dwHighDateTime = B.Time.dwHighDateTime)));
end;

function OpenU(const Path: string; Access, Disposition: DWORD): THandle;
begin
  Result := CreateFileW(PWideChar(WidePath(Path)), Access, FILE_SHARE_READ or FILE_SHARE_WRITE,
    nil, Disposition, FILE_ATTRIBUTE_NORMAL, 0);
  if Result = INVALID_HANDLE_VALUE then
    raise EInOutError.CreateFmt('Cannot open file "%s". %s', [Path, SysErrorMessage(GetLastError)]);
end;

function ReadFileU(const Path: string): string;
var
  H: THandle;
  Size, Done: DWORD;
begin
  H := OpenU(Path, GENERIC_READ, OPEN_EXISTING);
  try
    Size := GetFileSize(H, nil);
    SetLength(Result, Size);
    if (Size > 0) and not (ReadFile(H, Result[1], Size, Done, nil) and (Done = Size)) then
      RaiseLastOSError;
  finally
    CloseHandle(H);
  end;
end;

{ Safe save: the bytes go into a temporary file next to the target, which then takes the
  target's place (ReplaceFileW keeps its attributes, ACL and creation time). A failure on the
  way (disk full, a network drop) leaves the old file as it was, and the temporary file goes -
  but for a replace that took the target away and could not rename the new file: then it is
  moved into the target's place, or kept and named in the error. }
function RenameFileU(const Path, NewPath: string): Boolean;
begin
  Result := MoveFileW(PWideChar(WidePath(Path)), PWideChar(WidePath(NewPath)));
end;

function DeleteFileU(const Path: string): Boolean;
begin
  Result := DeleteFileW(PWideChar(WidePath(Path)));
end;

procedure WriteFileU(const Path, Data: string);
const
  REPLACEFILE_IGNORE_MERGE_ERRORS = 2;
  ERROR_UNABLE_TO_MOVE_REPLACEMENT = 1176;
  ERROR_UNABLE_TO_MOVE_REPLACEMENT_2 = 1177;
var
  H: THandle;
  Done: DWORD;
  Target, Temp: WideString;
  Ok, Written: Boolean;
  Err: DWORD;
begin
  Target := WidePath(Path);
  Temp := Target + '.~sd';
  H := CreateFileW(PWideChar(Temp), GENERIC_WRITE, 0, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if H = INVALID_HANDLE_VALUE then
    raise EInOutError.CreateFmt('Cannot write file "%s". %s', [Path, SysErrorMessage(GetLastError)]);
  Ok := False;
  Written := False;
  try
    try
      Ok := (Data = '') or (WriteFile(H, Data[1], Length(Data), Done, nil) and (Done = DWORD(Length(Data))));
      if Ok then Ok := FlushFileBuffers(H);
      Err := GetLastError;
    finally
      CloseHandle(H);
    end;
    Written := Ok;
    if Ok then
      if GetFileAttributesW(PWideChar(Target)) <> $FFFFFFFF then
      begin
        Ok := ReplaceFileW(PWideChar(Target), PWideChar(Temp), nil, REPLACEFILE_IGNORE_MERGE_ERRORS, nil, nil);
        Err := GetLastError;
        { the new file could not take the target's name: the target is gone (1176) or has another
          name (1177), the new bytes are still in the temporary file - it is moved again }
        if not Ok and ((Err = ERROR_UNABLE_TO_MOVE_REPLACEMENT) or (Err = ERROR_UNABLE_TO_MOVE_REPLACEMENT_2)) then
        begin
          Ok := MoveFileExW(PWideChar(Temp), PWideChar(Target), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH);
          if not Ok then Err := GetLastError;
        end;
      end
      else
      begin
        Ok := MoveFileExW(PWideChar(Temp), PWideChar(Target), MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH);
        Err := GetLastError;
      end;
    if not Ok then
      if Written and (GetFileAttributesW(PWideChar(Target)) = $FFFFFFFF) then
        raise EInOutError.CreateFmt('Cannot write file "%s". %s The new contents are in "%s".',
          [Path, SysErrorMessage(Err), Path + '.~sd'])
      else
        raise EInOutError.CreateFmt('Cannot write file "%s". %s', [Path, SysErrorMessage(Err)]);
  finally
    { after a replace there is nothing left to delete; the temporary file stays only when it holds
      the only copy of the contents - the target is not there any more }
    if Ok or not Written or (GetFileAttributesW(PWideChar(Target)) <> $FFFFFFFF) then
      DeleteFileW(PWideChar(Temp));
  end;
end;

procedure BackupFileU(const Path: string);
var
  Ext: string;
begin
  if not FileExistsU(Path) then Exit;
  Ext := ExtractFileExt(Path);
  if Ext = '' then Exit;
  CopyFileW(PWideChar(WidePath(Path)), PWideChar(WidePath(ChangeFileExt(Path, '.~' + Copy(Ext, 2, MaxInt)))), False);
end;

function ForceFoldersW(const W: WideString): Boolean;
var
  A: DWORD;
  I: Integer;
begin
  A := GetFileAttributesW(PWideChar(W));
  if A <> $FFFFFFFF then
  begin
    Result := A and FILE_ATTRIBUTE_DIRECTORY <> 0;
    Exit;
  end;
  I := Length(W);
  while (I > 0) and (W[I] <> '\') do Dec(I);
  if (I > 1) and not ForceFoldersW(Copy(W, 1, I - 1)) then
  begin
    Result := False;
    Exit;
  end;
  Result := CreateDirectoryW(PWideChar(W), nil) or (GetLastError = ERROR_ALREADY_EXISTS);
end;

function ForceDirectoriesU(const Path: string): Boolean;
var
  W: WideString;
begin
  W := WidePath(Path);
  while (Length(W) > 3) and (W[Length(W)] = '\') do SetLength(W, Length(W) - 1);
  Result := (W <> '') and ForceFoldersW(W);
end;

{ --- names from the shell --- }

procedure DroppedFiles(Drop: HDROP; L: TStrings);
var
  I, N: Integer;
  Buf: array[0..MAX_PATH] of WideChar;
begin
  N := DragQueryFileW(Drop, $FFFFFFFF, nil, 0);
  for I := 0 to N - 1 do
    if DragQueryFileW(Drop, I, Buf, MAX_PATH) > 0 then L.Add(UsablePath(Buf));
end;

procedure CommandLineFiles(L: TStrings);
type
  TArgs = array[0..1023] of PWideChar;
var
  Args: ^TArgs;
  I, N: Integer;
begin
  Args := Pointer(CommandLineToArgvW(GetCommandLineW, N));
  if Args = nil then Exit;
  try
    for I := 1 to N - 1 do L.Add(UsablePath(Args^[I]));   // 0 is the program
  finally
    LocalFree(HLOCAL(Args));
  end;
end;

{ --- Unicode text in ANSI windows --- }

procedure SetWindowTextUnicode(Wnd: HWND; const W: WideString);
begin
  { the window is an ANSI window: SetWindowTextW would be converted back to the code page }
  DefWindowProcW(Wnd, WM_SETTEXT, 0, LPARAM(PWideChar(W)));
end;

procedure DrawTextUnicode(Canvas: TCanvas; const W: WideString; var R: TRect; Flags: Cardinal);
begin
  DrawTextW(Canvas.Handle, PWideChar(W), Length(W), R, Flags);
end;

function TextWidthUnicode(Canvas: TCanvas; const W: WideString): Integer;
var
  Size: TSize;
begin
  GetTextExtentPoint32W(Canvas.Handle, PWideChar(W), Length(W), Size);
  Result := Size.cx;
end;

{ ---------------------------------------------------------------- TSdFileDialog }

constructor TSdFileDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFiles := TStringList.Create;
  FOptions := [ofHideReadOnly, ofEnableSizing];
end;

destructor TSdFileDialog.Destroy;
begin
  FFiles.Free;
  inherited;
end;

function TSdFileDialog.Execute: Boolean;
begin
  Result := Run(False);
end;

function TSdFileDialog.ExecuteSave: Boolean;
begin
  Result := Run(True);
end;

function TSdFileDialog.Run(Save: Boolean): Boolean;
const
  BufLen = 32768;
  Flags: array[TOpenOption] of DWORD = (OFN_READONLY, OFN_OVERWRITEPROMPT, OFN_HIDEREADONLY,
    OFN_NOCHANGEDIR, OFN_SHOWHELP, OFN_NOVALIDATE, OFN_ALLOWMULTISELECT, OFN_EXTENSIONDIFFERENT,
    OFN_PATHMUSTEXIST, OFN_FILEMUSTEXIST, OFN_CREATEPROMPT, OFN_SHAREAWARE, OFN_NOREADONLYRETURN,
    OFN_NOTESTFILECREATE, OFN_NONETWORKBUTTON, OFN_NOLONGNAMES, 0 {ofOldStyleDialog},
    OFN_NODEREFERENCELINKS, OFN_ENABLEINCLUDENOTIFY, OFN_ENABLESIZING, OFN_DONTADDTORECENT,
    OFN_FORCESHOWHIDDEN);
var
  OFN: TOpenFilenameW;
  Buf, WFilter, WTitle, WExt, WDir, Name: WideString;
  O: TOpenOption;
  ActiveWnd: HWND;
  WindowList: Pointer;
  CW: Word;
begin
  FFiles.Clear;
  { 'Text|*.txt|All|*.*' -> 'Text'#0'*.txt'#0'All'#0'*.*'#0#0 }
  WFilter := ToWide(StringReplace(FFilter, '|', #0, [rfReplaceAll]), CP_ACP) + #0#0;
  WTitle := ToWide(FTitle, CP_ACP);
  WExt := ToWide(FDefaultExt, CP_ACP);
  WDir := DisplayPath(FInitialDir);
  SetLength(Buf, BufLen);
  FillChar(Buf[1], BufLen * 2, 0);
  Name := DisplayPath(FFileName);
  if Name <> '' then Move(Name[1], Buf[1], Length(Name) * 2);
  FillChar(OFN, SizeOf(OFN), 0);
  OFN.lStructSize := SizeOf(OFN);
  if Screen.ActiveCustomForm <> nil then OFN.hWndOwner := Screen.ActiveCustomForm.Handle
  else OFN.hWndOwner := Application.Handle;
  OFN.lpstrFilter := PWideChar(WFilter);
  OFN.nFilterIndex := 1;
  OFN.lpstrFile := PWideChar(Buf);
  OFN.nMaxFile := BufLen;
  if WTitle <> '' then OFN.lpstrTitle := PWideChar(WTitle);
  if WExt <> '' then OFN.lpstrDefExt := PWideChar(WExt);
  if WDir <> '' then OFN.lpstrInitialDir := PWideChar(WDir);
  OFN.Flags := OFN_EXPLORER or OFN_NOCHANGEDIR;
  for O := Low(TOpenOption) to High(TOpenOption) do
    if O in FOptions then OFN.Flags := OFN.Flags or Flags[O];
  { as the VCL's dialogs (TCommonDialog.TaskModalDialog): the IDE's other windows - floating views
    too, which the owner's disabling would not reach - wait while the dialog is open, and the FPU
    control word a shell extension may change comes back }
  ActiveWnd := GetActiveWindow;
  WindowList := DisableTaskWindows(0);
  CW := Get8087CW;
  try
    if Save then Result := GetSaveFileNameW(OFN) else Result := GetOpenFileNameW(OFN);
  finally
    Set8087CW(CW);
    EnableTaskWindows(WindowList);
    SetActiveWindow(ActiveWnd);
  end;
  if not Result then Exit;
  DialogFileNames(PWideChar(Buf), ofAllowMultiSelect in FOptions, FFiles);
  FFileName := FFiles[0];
end;

procedure DialogFileNames(Buf: PWideChar; MultiSelect: Boolean; Files: TStrings);
var
  Dir, Name: WideString;
  P: PWideChar;
begin
  Dir := Buf;
  P := Buf;
  Inc(P, Length(Dir) + 1);
  if MultiSelect and (P^ <> #0) then
  begin
    { the folder, #0, the names, #0#0 - a drive's root comes with its backslash ("C:\") }
    if (Dir <> '') and (Dir[Length(Dir)] <> '\') then Dir := Dir + '\';
    while P^ <> #0 do
    begin
      Name := P;
      Files.Add(UsablePath(Dir + Name));
      Inc(P, Length(Name) + 1);
    end;
  end
  else
    Files.Add(UsablePath(Dir));
end;

{ ---------------------------------------------------------------- temporary folders }

function TempFolder: string;
var
  Buf: array[0..MAX_PATH] of Char;
begin
  SetString(Result, Buf, GetTempPath(MAX_PATH, Buf));
  Result := IncludeTrailingPathDelimiter(Result);
end;

procedure ShowInExplorer(const FileName: string);
var
  Args: string;
begin
  if DirectoryExists(FileName) then Args := '"' + FileName + '"'
  else Args := '/select,"' + FileName + '"';
  ShellExecute(0, 'open', 'explorer.exe', PChar(Args), nil, SW_SHOWNORMAL);
end;

procedure RemoveTree(const Dir: string);
var
  SR: TSearchRec;
begin
  if FindFirst(Dir + '*', faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if SR.Attr and faDirectory <> 0 then RemoveTree(Dir + SR.Name + '\')
        else DeleteFile(Dir + SR.Name);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  RemoveDir(Dir);
end;

end.
