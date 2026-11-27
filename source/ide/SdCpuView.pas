{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCpuView;

{ D7 Studio - Delphi 7's CPU window as a view (View | Debug Windows | CPU): the disassembly (each source
  line above its code, the execution point marked), the
  registers (changed ones in red), the flags, a memory dump and the machine stack of a stopped
  process; empty while it runs. Its menu: Copy (Ctrl+C) the selected lines, Copy Lines from the
  selected one - the code decoded and the memory read on beyond what a pane holds -, Copy All, Open in
  Editor; Go to Address (Ctrl+G) in the disassembly, or the dump while it has the keyboard. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, Menus, ActnList, SdUI,
  SdDbgEngine;

type
  { the text of a source line (the IDE's: an open page, else the file) }
  TSourceTextFunc = function(const FileName: string; Line: Integer): string of object;
  { an address breakpoint at Addr: 0 none, 1 enabled, 2 disabled }
  TBreakpointAtFunc = function(Addr: Cardinal): Integer of object;

  { Delphi's CPU window as a view: a form made once (its five panes and their events in the .dfm),
    docked by the IDE - a child window then, without a border }
  TSdCpuView = class(TForm)
    DisasmList: TListBox;
    RegsList: TListBox;
    FlagsList: TListBox;
    DumpList: TListBox;
    StackList: TListBox;
    MenuActions: TActionList;
    aCpuCopy: TAction;
    aCpuCopyLines: TAction;
    aCpuCopyAll: TAction;
    aCpuOpenText: TAction;
    aCpuGotoAddress: TAction;
    CpuPopup: TPopupMenu;
    pmCpuCopy: TMenuItem;
    pmCpuCopyLines: TMenuItem;
    pmCpuCopyAll: TMenuItem;
    pmCpuOpenText: TMenuItem;
    pmCpuSep: TMenuItem;
    pmCpuGotoAddress: TMenuItem;
    procedure DrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ListContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure MenuActionsUpdate(Action: TBasicAction; var Handled: Boolean);
  private
    FDbg: TDebugger;
    FFrames: array[0..4] of TRect;  // the flat borders around the panes
    FStart: Cardinal;               // the first address of the disassembly
    FEIP: Cardinal;
    FDumpAddr: Cardinal;
    FOld, FCur: TDbgRegisters;
    FHasOld: Boolean;
    FOnSourceText: TSourceTextFunc;
    FOnBreakpointAt: TBreakpointAtFunc;
    FLineCounts: array[0..4] of Integer;   // Copy Lines' count of each pane, the last one asked
    function Pane(Index: Integer): TListBox;     // 0 the disassembly, the registers, the flags, the dump, 4 the stack
    function PaneIndex(Pane: TListBox): Integer;
    { the lines of the panes as they show them: the instructions, each source line above its first one
      (Objects SourceMark; an instruction's its address); Count lines of 8 bytes of memory from Addr;
      Count dwords of the stack from Addr (Objects 1 at ESP) }
    procedure AddDisasmLines(Lines: TStrings; const Instrs: TDbgInstrArray);
    procedure AddDumpLines(Lines: TStrings; Addr: Cardinal; Count: Integer);
    procedure AddStackLines(Lines: TStrings; Addr: Cardinal; Count: Integer);
    procedure FillDisasm(Addr: Cardinal);
    procedure FillRegs;
    procedure FillDump;
    procedure FillStack;
    function PaneFont: TFont;
  protected
    procedure Resize; override;
    procedure Paint; override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Refresh(Dbg: TDebugger);      // after a stop: everything at the execution point
    procedure Clear;
    procedure GotoAddress(Addr: Cardinal);  // the disassembly (or, with the dump focused, the dump) there
    function DumpFocused: Boolean;
    function DisasmFocused: Boolean;
    procedure FocusDisasm;
    function SelectedAddress: Cardinal;     // the disassembly line's (0: none)
    procedure FontChanged(F: TFont);
    procedure BreakpointsChanged;           // the disassembly shows them again
    { the menu's commands: the pane they are about - the one with the keyboard (a right click gives it
      the keyboard), else the disassembly -; its lines as text, the selected ones or all; Count lines
      from its selected one (the disassembly: instructions decoded from it, its source lines too; the
      dump and the stack: the memory read from its address on); Copy Lines' count of the pane; the
      commands' enabled states }
    function CommandPane: TListBox;
    function PaneText(Pane: TListBox; SelectedOnly: Boolean): string;
    function LinesText(Pane: TListBox; Count: Integer): string;
    function LineCount(Pane: TListBox): Integer;
    procedure SetLineCount(Pane: TListBox; Count: Integer);
    procedure UpdateCommands;
    property OnSourceText: TSourceTextFunc read FOnSourceText write FOnSourceText;
    property OnBreakpointAt: TBreakpointAtFunc read FOnBreakpointAt write FOnBreakpointAt;
  end;

implementation

{$R *.dfm}

const
  RegNames: array[0..9] of string = ('EAX', 'EBX', 'ECX', 'EDX', 'ESI', 'EDI', 'EBP', 'ESP', 'EIP', 'EFL');
  FlagNames: array[0..8] of string = ('CF', 'PF', 'AF', 'ZF', 'SF', 'TF', 'IF', 'DF', 'OF');
  FlagBits: array[0..8] of Integer = (0, 2, 4, 6, 7, 8, 9, 10, 11);
  { a line of the disassembly: Objects = its address, or this for a source line above it (not -1:
    a list box reads item data -1 as LB_ERR, an index error) }
  SourceMark = 1;

function RegValue(const R: TDbgRegisters; I: Integer): Cardinal;
begin
  case I of
    0: Result := R.EAX;
    1: Result := R.EBX;
    2: Result := R.ECX;
    3: Result := R.EDX;
    4: Result := R.ESI;
    5: Result := R.EDI;
    6: Result := R.EBP;
    7: Result := R.ESP;
    8: Result := R.EIP;
  else
    Result := R.EFlags;
  end;
end;

{ ---------------------------------------------------------------- TSdCpuView }

function Inset(const R: TRect): TRect;
begin
  Result := Rect(R.Left + 1, R.Top + 1, R.Right - 1, R.Bottom - 1);
end;


constructor TSdCpuView.Create(AOwner: TComponent);

  procedure Prepare(L: TListBox);
  begin
    L.DoubleBuffered := True;         // refilled at every step: painted in memory
    UINoListPadding(L);               // machine rows stay dense, as Delphi's
  end;

begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form docked as a child keeps its own font }
  UIApplyFont(Self);
  Prepare(DisasmList);
  Prepare(RegsList);
  Prepare(FlagsList);
  Prepare(DumpList);
  Prepare(StackList);
  { Copy Lines' first counts: 30 instructions, 5 lines of memory, 30 dwords of the stack, every register
    and flag }
  FLineCounts[0] := 30;
  FLineCounts[1] := 16;
  FLineCounts[2] := 9;
  FLineCounts[3] := 5;
  FLineCounts[4] := 30;
end;

{ Paint fills the whole view: nothing to erase first }
procedure TSdCpuView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

function TSdCpuView.PaneFont: TFont;
begin
  Result := DisasmList.Font;
end;

procedure TSdCpuView.FontChanged(F: TFont);
var
  H: Integer;
begin
  DisasmList.Font := F;
  RegsList.Font := F;
  FlagsList.Font := F;
  DumpList.Font := F;
  StackList.Font := F;
  { the row height from the font itself (the panes may have no window yet) }
  H := UIFontHeight(F) + 2;
  DisasmList.ItemHeight := H;
  RegsList.ItemHeight := H;
  FlagsList.ItemHeight := H;
  DumpList.ItemHeight := H;
  StackList.ItemHeight := H;
  if HandleAllocated then Resize;   // the widths of the side panes follow the font
end;

{ Delphi's arrangement: the disassembly with the registers and the flags at its right, under it
  the dump with the stack at its right; 2 px between them }
procedure TSdCpuView.Resize;
const
  Gap = 2;
var
  W, H, SB, RegW, FlagW, StackW, Top: Integer;
begin
  inherited;
  W := ClientWidth;
  H := ClientHeight;
  if (W <= 0) or (H <= 0) then Exit;
  Canvas.Font := PaneFont;
  { the text after the 12 px margin, and room for a vertical scroll bar (a low view scrolls them) }
  SB := GetSystemMetrics(SM_CXVSCROLL);
  RegW := Canvas.TextWidth('EAX 00000000') + 18 + SB;
  FlagW := Canvas.TextWidth('CF 0') + 18 + SB;
  StackW := Canvas.TextWidth('00000000 00000000') + 18 + SB;
  Top := H * 62 div 100;
  FFrames[0] := Rect(0, 0, W - RegW - FlagW - 2 * Gap, Top);
  FFrames[1] := Rect(W - RegW - FlagW - Gap, 0, W - FlagW - Gap, Top);
  FFrames[2] := Rect(W - FlagW, 0, W, Top);
  FFrames[3] := Rect(0, Top + Gap, W - StackW - Gap, H);
  FFrames[4] := Rect(W - StackW, Top + Gap, W, H);
  { inside a flat 1 px border each (no 3-D edge) }
  UIMoveControls([DisasmList, RegsList, FlagsList, DumpList, StackList],
    [Inset(FFrames[0]), Inset(FFrames[1]), Inset(FFrames[2]), Inset(FFrames[3]), Inset(FFrames[4])]);
  Invalidate;
end;

procedure TSdCpuView.Paint;
var
  I: Integer;
begin
  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(ClientRect);
  for I := 0 to High(FFrames) do UIDrawBorder(Canvas.Handle, FFrames[I]);
end;

procedure TSdCpuView.Clear;
begin
  FDbg := nil;
  DisasmList.Items.Clear;
  RegsList.Items.Clear;
  FlagsList.Items.Clear;
  DumpList.Items.Clear;
  StackList.Items.Clear;
end;

procedure TSdCpuView.Refresh(Dbg: TDebugger);
var
  R: TDbgRegisters;
begin
  FDbg := Dbg;
  if (Dbg = nil) or not Dbg.GetRegisters(R) then
  begin
    Clear;
    Exit;
  end;
  if FCur.EIP <> 0 then
  begin
    FOld := FCur;
    FHasOld := True;
  end;
  FCur := R;
  FEIP := R.EIP;
  FillDisasm(R.EIP);
  FillRegs;
  if FDumpAddr = 0 then FDumpAddr := R.EBP and not 7;
  FillDump;
  FillStack;
end;

procedure TSdCpuView.GotoAddress(Addr: Cardinal);
begin
  if FDbg = nil then Exit;
  if DumpFocused then
  begin
    FDumpAddr := Addr;
    FillDump;
  end
  else
    FillDisasm(Addr);
end;

function TSdCpuView.DumpFocused: Boolean;
begin
  Result := DumpList.Focused;
end;

function TSdCpuView.DisasmFocused: Boolean;
begin
  Result := DisasmList.Focused;
end;

procedure TSdCpuView.BreakpointsChanged;
begin
  DisasmList.Invalidate;
end;

procedure TSdCpuView.FocusDisasm;
begin
  if DisasmList.CanFocus then DisasmList.SetFocus;
end;

function TSdCpuView.SelectedAddress: Cardinal;
begin
  Result := 0;
  if (DisasmList.ItemIndex >= 0) and (Cardinal(DisasmList.Items.Objects[DisasmList.ItemIndex]) <> SourceMark) then
    Result := Cardinal(DisasmList.Items.Objects[DisasmList.ItemIndex]);
end;

{ The code around Addr: it begins some bytes before, where decoding lands on Addr again (x86
  code cannot be read backwards), each source line above its first instruction. The engine
  decodes (DecodeAt): never from bytes that could not be read. }
procedure TSdCpuView.FillDisasm(Addr: Cardinal);
const
  Before = 48;
  Count = 160;
var
  Instrs: TDbgInstrArray;
  Start: Cardinal;
  Try_, K, Line, Sel: Integer;
  FileName: string;
  Exact: Boolean;
begin
  DisasmList.Items.BeginUpdate;
  try
    DisasmList.Items.Clear;
    if FDbg = nil then Exit;
    { a start before Addr from which the instructions meet it: the first instruction of a source
      line, else an address the decoding from which lands on Addr }
    Start := Addr;
    for Try_ := 2 * Before downto 1 do
      if FDbg.SourceLineAt(Addr - Cardinal(Try_), FileName, Line, Exact) and Exact then
      begin
        Start := Addr - Cardinal(Try_);
        Break;
      end;
    if Start = Addr then Start := FDbg.DecodeStart(Addr, Before);
    FStart := Start;
    if not FDbg.DecodeAt(Start, Count, Instrs) then Exit;
    AddDisasmLines(DisasmList.Items, Instrs);
    Sel := DisasmList.Items.IndexOfObject(TObject(Addr));
    DisasmList.ItemIndex := Sel;
    if Sel >= 0 then DisasmList.Selected[Sel] := True;
    { the execution point in the upper third of the pane }
    K := DisasmList.ClientHeight div DisasmList.ItemHeight div 3;
    if Sel > K then DisasmList.TopIndex := Sel - K;
  finally
    DisasmList.Items.EndUpdate;
  end;
end;

procedure TSdCpuView.AddDisasmLines(Lines: TStrings; const Instrs: TDbgInstrArray);
var
  I, K, Line: Integer;
  A: Cardinal;
  Bytes, FileName, Src: string;
  Exact: Boolean;
begin
  for I := 0 to High(Instrs) do
  begin
    A := Instrs[I].Addr;
    if FDbg.SourceLineAt(A, FileName, Line, Exact) and Exact then
    begin
      Src := '';
      if Assigned(FOnSourceText) then Src := FOnSourceText(FileName, Line);
      Lines.AddObject(Format('%s.%d: %s', [ExtractFileName(FileName), Line, Trim(Src)]), TObject(SourceMark));
    end;
    Bytes := '';
    for K := 0 to Instrs[I].Len - 1 do
      if K < 7 then Bytes := Bytes + IntToHex(Instrs[I].Bytes[K], 2);
    if Instrs[I].Len > 7 then Bytes := Bytes + '..';
    Lines.AddObject(Format('%.8X %-16s %s', [A, Bytes, Instrs[I].Text]), TObject(A));
  end;
end;

procedure TSdCpuView.FillRegs;var
  I, Bit: Integer;
begin
  RegsList.Items.BeginUpdate;
  try
    RegsList.Items.Clear;
    for I := 0 to High(RegNames) do
      RegsList.Items.AddObject(Format('%s %.8X', [RegNames[I], RegValue(FCur, I)]),
        TObject(Ord(FHasOld and (RegValue(FCur, I) <> RegValue(FOld, I)))));
    RegsList.Items.AddObject(Format('CS %.4X', [FCur.CS]), nil);
    RegsList.Items.AddObject(Format('DS %.4X', [FCur.DS]), nil);
    RegsList.Items.AddObject(Format('ES %.4X', [FCur.ES]), nil);
    RegsList.Items.AddObject(Format('SS %.4X', [FCur.SS]), nil);
    RegsList.Items.AddObject(Format('FS %.4X', [FCur.FS]), nil);
    RegsList.Items.AddObject(Format('GS %.4X', [FCur.GS]), nil);
  finally
    RegsList.Items.EndUpdate;
  end;
  FlagsList.Items.BeginUpdate;
  try
    FlagsList.Items.Clear;
    for I := 0 to High(FlagNames) do
    begin
      Bit := FlagBits[I];
      FlagsList.Items.AddObject(Format('%s %d', [FlagNames[I], (FCur.EFlags shr Bit) and 1]),
        TObject(Ord(FHasOld and (((FCur.EFlags xor FOld.EFlags) shr Bit) and 1 <> 0))));
    end;
  finally
    FlagsList.Items.EndUpdate;
  end;
end;

{ 8 bytes a line, hexadecimal and as characters; a byte of a page that cannot be read is ?? (a
  read that ran into such a page left the whole dump at one line of ????????) }
procedure TSdCpuView.FillDump;
begin
  DumpList.Items.BeginUpdate;
  try
    DumpList.Items.Clear;
    if FDbg <> nil then AddDumpLines(DumpList.Items, FDumpAddr, 32);
  finally
    DumpList.Items.EndUpdate;
  end;
end;

procedure TSdCpuView.AddDumpLines(Lines: TStrings; Addr: Cardinal; Count: Integer);
var
  Buf: array of Byte;
  Readable: array of Boolean;
  I, K, B: Integer;
  Hex, Chars: string;
begin
  if (FDbg = nil) or (Count <= 0) then Exit;
  SetLength(Buf, Count * 8);
  SetLength(Readable, Count * 8);
  FDbg.ReadMemoryPaged(Addr, Buf[0], Length(Buf), Readable);
  for I := 0 to Count - 1 do
  begin
    Hex := '';
    Chars := '';
    for K := 0 to 7 do
    begin
      B := I * 8 + K;
      if not Readable[B] then
      begin
        Hex := Hex + '?? ';
        Chars := Chars + '?';
      end
      else
      begin
        Hex := Hex + IntToHex(Buf[B], 2) + ' ';
        if Buf[B] in [32..126] then Chars := Chars + Chr(Buf[B]) else Chars := Chars + '.';
      end;
    end;
    Lines.Add(Format('%.8X %s %s', [Addr + Cardinal(I * 8), Hex, Chars]));
  end;
end;

{ the machine stack from ESP on, a dword a line; ESP's line marked. Read page by page: near the
  stack's base the dwords beyond it are ???????? (the pane stayed empty there) }
procedure TSdCpuView.FillStack;
begin
  StackList.Items.BeginUpdate;
  try
    StackList.Items.Clear;
    if FDbg <> nil then AddStackLines(StackList.Items, FCur.ESP, 64);
  finally
    StackList.Items.EndUpdate;
  end;
end;

procedure TSdCpuView.AddStackLines(Lines: TStrings; Addr: Cardinal; Count: Integer);
var
  Buf: array of Cardinal;
  Readable: array of Boolean;
  I: Integer;
  A: Cardinal;
  S: string;
begin
  if (FDbg = nil) or (Count <= 0) then Exit;
  SetLength(Buf, Count);
  SetLength(Readable, Count * 4);
  FDbg.ReadMemoryPaged(Addr, Buf[0], Count * 4, Readable);
  for I := 0 to Count - 1 do
  begin
    A := Addr + Cardinal(I * 4);
    if Readable[I * 4] and Readable[I * 4 + 3] then S := Format('%.8X', [Buf[I]]) else S := '????????';
    Lines.AddObject(Format('%.8X %s', [A, S]), TObject(Ord(A = FCur.ESP)));
  end;
end;

{ the execution point with Delphi's green arrow, source lines bold, changed registers and flags
  red; an address breakpoint's instruction in the editor's breakpoint colours (a disabled one grey) }
procedure TSdCpuView.DrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  L: TListBox;
  C: TCanvas;
  S: string;
  Mark: Boolean;
  P: array[0..2] of TPoint;
  Y, BPState: Integer;
begin
  L := TListBox(Control);
  C := L.Canvas;
  S := L.Items[Index];
  Mark := False;
  BPState := 0;
  C.Font := L.Font;
  if L = DisasmList then
  begin
    Mark := Cardinal(L.Items.Objects[Index]) = FEIP;
    if Cardinal(L.Items.Objects[Index]) = SourceMark then C.Font.Style := [fsBold]
    else if Assigned(FOnBreakpointAt) then BPState := FOnBreakpointAt(Cardinal(L.Items.Objects[Index]));
  end
  else if L = StackList then
    Mark := L.Items.Objects[Index] <> nil
  else if ((L = RegsList) or (L = FlagsList)) and (L.Items.Objects[Index] <> nil) and not (odSelected in State) then
    C.Font.Color := clRed;
  if odSelected in State then
  begin
    if L.Focused then
    begin
      C.Brush.Color := clHighlight;
      C.Font.Color := clHighlightText;
    end
    else
      C.Brush.Color := UISelectionTint(clWindow);
  end
  else if BPState = 1 then
  begin
    C.Brush.Color := clRed;
    C.Font.Color := clWhite;
  end
  else if BPState = 2 then
  begin
    C.Brush.Color := clSilver;
    C.Font.Color := clGray;
  end
  else
    C.Brush.Color := clWindow;
  C.FillRect(Rect);
  if Mark then
  begin
    { Delphi's execution point: a green arrow in the margin }
    Y := (Rect.Top + Rect.Bottom) div 2;
    C.Pen.Color := clBlack;
    C.Brush.Color := clLime;
    P[0] := Point(Rect.Left + 2, Y - 4);
    P[1] := Point(Rect.Left + 9, Y);
    P[2] := Point(Rect.Left + 2, Y + 4);
    C.Polygon(P);
    if odSelected in State then
    begin
      if L.Focused then C.Brush.Color := clHighlight else C.Brush.Color := UISelectionTint(clWindow);
    end
    else
      C.Brush.Color := clWindow;
  end;
  C.Brush.Style := bsClear;
  C.TextOut(Rect.Left + 12, Rect.Top + 1, S);
  C.Brush.Style := bsSolid;
  UIListRowWidth(L, Rect.Left + 12 + C.TextWidth(S));
end;

{ Ctrl+C and Ctrl+G: the menu's commands - the keys of its items, which the main form's shortcuts
  may take first }
procedure TSdCpuView.ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Shift <> [ssCtrl] then Exit;
  if Key = Ord('C') then aCpuCopy.Execute
  else if Key = Ord('G') then aCpuGotoAddress.Execute
  else Exit;
  Key := 0;
end;

{ a right click gives the pane the keyboard (the commands are about it) and selects the line under
  the pointer unless it is among the selected ones }
procedure TSdCpuView.ListContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var
  L: TListBox;
  I: Integer;
begin
  L := Sender as TListBox;
  if L.CanFocus then L.SetFocus;
  if MousePos.X < 0 then Exit;            // the menu key: the selection as it is
  I := L.ItemAtPos(MousePos, True);
  if (I < 0) or L.Selected[I] then Exit;
  L.ClearSelection;
  L.Selected[I] := True;
  L.ItemIndex := I;
end;

function TSdCpuView.Pane(Index: Integer): TListBox;
begin
  case Index of
    0: Result := DisasmList;
    1: Result := RegsList;
    2: Result := FlagsList;
    3: Result := DumpList;
  else
    Result := StackList;
  end;
end;

function TSdCpuView.PaneIndex(Pane: TListBox): Integer;
begin
  Result := High(FLineCounts);
  while (Result > 0) and (Self.Pane(Result) <> Pane) do Dec(Result);
end;

function TSdCpuView.CommandPane: TListBox;
var
  I: Integer;
begin
  for I := 0 to High(FLineCounts) do
  begin
    Result := Pane(I);
    if Result.Focused then Exit;
  end;
  Result := DisasmList;
end;

function TSdCpuView.PaneText(Pane: TListBox; SelectedOnly: Boolean): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Pane.Items.Count - 1 do
    if not SelectedOnly or Pane.Selected[I] then Result := Result + Pane.Items[I] + #13#10;
end;

{ the address a line of the dump or the stack begins with }
function LineAddress(const S: string): Cardinal;
begin
  Result := Cardinal(StrToIntDef('$' + Copy(S, 1, 8), 0));
end;

function TSdCpuView.LinesText(Pane: TListBox; Count: Integer): string;
var
  Lines: TStringList;
  Instrs: TDbgInstrArray;
  I: Integer;
begin
  Result := '';
  if (Count <= 0) or (Pane.Items.Count = 0) then Exit;
  I := Pane.ItemIndex;
  if I < 0 then I := 0;
  Lines := TStringList.Create;
  try
    if (Pane = DisasmList) and (FDbg <> nil) then
    begin
      { from the instruction of the line, the one under a source line }
      while (I < Pane.Items.Count - 1) and (Cardinal(Pane.Items.Objects[I]) = SourceMark) do Inc(I);
      if FDbg.DecodeAt(Cardinal(Pane.Items.Objects[I]), Count, Instrs) then AddDisasmLines(Lines, Instrs);
    end
    else if Pane = DumpList then AddDumpLines(Lines, LineAddress(Pane.Items[I]), Count)
    else if Pane = StackList then AddStackLines(Lines, LineAddress(Pane.Items[I]), Count)
    else
      while (I < Pane.Items.Count) and (Lines.Count < Count) do
      begin
        Lines.Add(Pane.Items[I]);
        Inc(I);
      end;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function TSdCpuView.LineCount(Pane: TListBox): Integer;
begin
  Result := FLineCounts[PaneIndex(Pane)];
end;

procedure TSdCpuView.SetLineCount(Pane: TListBox; Count: Integer);
begin
  FLineCounts[PaneIndex(Pane)] := Count;
end;

procedure TSdCpuView.MenuActionsUpdate(Action: TBasicAction; var Handled: Boolean);
var
  L: TListBox;
begin
  L := CommandPane;
  if Action = aCpuCopy then aCpuCopy.Enabled := L.SelCount > 0
  else if Action = aCpuGotoAddress then aCpuGotoAddress.Enabled := FDbg <> nil
  else if Action is TCustomAction then TCustomAction(Action).Enabled := L.Items.Count > 0;
  Handled := True;
end;

procedure TSdCpuView.UpdateCommands;
var
  I: Integer;
begin
  for I := 0 to MenuActions.ActionCount - 1 do MenuActions.Actions[I].Update;
end;

end.
