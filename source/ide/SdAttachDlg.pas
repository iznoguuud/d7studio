{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdAttachDlg;

{ D7 Studio - Run | Attach to Process: Delphi 7's dialog.
  The running processes the debugger can attach to - 32-bit
  ones (it is a 32-bit debugger), not D7 Studio itself - with image name, process id and path,
  sorted by the column clicked. Show System Processes adds the ones of other sessions, of the
  Windows folder and the ones whose path cannot be read. There is no remote debugging: the
  machine's name stays empty and disabled. }

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls, ActnList;

type
  TAttachDlg = class(TForm)
    xLabel1: TLabel;
    xLabel2: TLabel;
    MachineName: TEdit;
    ProcessList: TListView;
    cbShowSystemProcs: TCheckBox;
    Actions: TActionList;
    aRefresh: TAction;
    aAttach: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    RefreshButton: TButton;
    AttachButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aRefreshExecute(Sender: TObject);
    procedure aAttachExecute(Sender: TObject);
    procedure aAttachUpdate(Sender: TObject);
    procedure ProcessListDblClick(Sender: TObject);
    procedure ProcessListColumnClick(Sender: TObject; Column: TListColumn);
    procedure ProcessListCompare(Sender: TObject; Item1, Item2: TListItem; Data: Integer; var Compare: Integer);
    procedure cbShowSystemProcsClick(Sender: TObject);
  private
    FSortColumn: Integer;
    procedure FillProcesses;
  public
    class function Execute(AOwner: TComponent; out Pid: Cardinal): Boolean;
  end;

var
  AttachDlg: TAttachDlg;

implementation

uses
  TlHelp32, WindowsEx, SdUI;

{$R *.dfm}

{ the functions of Windows XP and later come from WindowsEx (bound at run time there) }

function IsWow64(H: THandle): Boolean;
var
  W: BOOL;
begin
  W := False;
  Result := IsWow64Process(H, W) and W;
end;

function SessionOf(Pid: DWORD): DWORD;
begin
  if not ProcessIdToSessionId(Pid, Result) then Result := DWORD(-1);
end;

procedure TAttachDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ the processes: 32-bit ones (on a 64-bit Windows the ones under WOW64, as D7 Studio is), and
  without Show System Processes only the user's own (this session, outside the Windows folder,
  a path that can be read) }
procedure TAttachDlg.FillProcesses;
var
  Snap, H: THandle;
  PE: TProcessEntry32;
  Path, WinDir: string;
  Buf: array[0..MAX_PATH] of Char;
  Size: DWORD;
  OS64, Sys: Boolean;
  Own, Sel: DWORD;
  It: TListItem;
begin
  OS64 := IsWow64(GetCurrentProcess);
  Own := SessionOf(GetCurrentProcessId);
  GetWindowsDirectory(Buf, SizeOf(Buf));
  WinDir := IncludeTrailingPathDelimiter(Buf);
  Sel := 0;
  if ProcessList.Selected <> nil then Sel := DWORD(ProcessList.Selected.Data);
  ProcessList.Items.BeginUpdate;
  try
    ProcessList.Items.Clear;
    Snap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if Snap = INVALID_HANDLE_VALUE then Exit;
    try
      PE.dwSize := SizeOf(PE);
      if Process32First(Snap, PE) then
      repeat
        if (PE.th32ProcessID = 0) or (PE.th32ProcessID = GetCurrentProcessId) then Continue;
        Path := '';
        H := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, PE.th32ProcessID);
        if H <> 0 then
        try
          if OS64 and not IsWow64(H) then Continue;      // a 64-bit process
          Size := SizeOf(Buf);
          if QueryFullProcessImageNameA(H, 0, Buf, Size) then SetString(Path, Buf, Size);
        finally
          CloseHandle(H);
        end;
        Sys := (Path = '') or (SessionOf(PE.th32ProcessID) <> Own) or
          SameText(Copy(Path, 1, Length(WinDir)), WinDir);
        if Sys and not cbShowSystemProcs.Checked then Continue;
        It := ProcessList.Items.Add;
        It.Caption := PE.szExeFile;
        It.SubItems.Add(IntToStr(PE.th32ProcessID));
        It.SubItems.Add(Path);
        It.Data := Pointer(PE.th32ProcessID);
        if PE.th32ProcessID = Sel then It.Selected := True;
      until not Process32Next(Snap, PE);
    finally
      CloseHandle(Snap);
    end;
    ProcessList.AlphaSort;
  finally
    ProcessList.Items.EndUpdate;
  end;
  if ProcessList.Selected <> nil then ProcessList.Selected.MakeVisible(False);
end;

procedure TAttachDlg.aRefreshExecute(Sender: TObject);
begin
  FillProcesses;
end;

procedure TAttachDlg.aAttachExecute(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TAttachDlg.aAttachUpdate(Sender: TObject);
begin
  aAttach.Enabled := ProcessList.Selected <> nil;
end;

procedure TAttachDlg.ProcessListDblClick(Sender: TObject);
begin
  if aAttach.Enabled then aAttach.Execute;
end;

procedure TAttachDlg.ProcessListColumnClick(Sender: TObject; Column: TListColumn);
begin
  FSortColumn := Column.Index;
  ProcessList.AlphaSort;
end;

procedure TAttachDlg.ProcessListCompare(Sender: TObject; Item1, Item2: TListItem; Data: Integer;
  var Compare: Integer);
begin
  case FSortColumn of
    1: Compare := Integer(Item1.Data) - Integer(Item2.Data);
    2: Compare := CompareText(Item1.SubItems[1], Item2.SubItems[1]);
  else
    Compare := CompareText(Item1.Caption, Item2.Caption);
  end;
end;

procedure TAttachDlg.cbShowSystemProcsClick(Sender: TObject);
begin
  FillProcesses;
end;

class function TAttachDlg.Execute(AOwner: TComponent; out Pid: Cardinal): Boolean;
var
  D: TAttachDlg;
begin
  Pid := 0;
  D := TAttachDlg.Create(AOwner);
  try
    D.FillProcesses;
    Result := (D.ShowModal = mrOk) and (D.ProcessList.Selected <> nil);
    if Result then Pid := Cardinal(D.ProcessList.Selected.Data);
  finally
    D.Free;
  end;
end;

end.
