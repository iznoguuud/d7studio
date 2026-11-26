{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDebugViews;

{ D7 Studio - debug windows (View | Debug Windows): Delphi 7's FPU
  window as a view, and what fills its Thread Status and Modules lists. They show a stopped
  process; while it runs they are empty. The CPU view and the Debug Inspector are forms of their
  own (SdCpuView, SdDebugInspector), the Watch List a frame (SdWatchViewFrame). }

interface

uses
  SysUtils, StdCtrls, ComCtrls, SdDbgEngine;

{ Delphi's FPU window: ST0..ST7 with their tags, the status and the control word (the list: the main
  form's .dfm's) }
procedure FillFpu(Dbg: TDebugger; List: TListBox);
{ Thread Status: thread id, state, status, location (the current thread first column marked) }
procedure FillThreads(Dbg: TDebugger; List: TListView; const StopStatus: string);
{ Modules: name, base address, size, path, symbols }
procedure FillModules(Dbg: TDebugger; List: TListView);

implementation

{ ---------------------------------------------------------------- the FPU }

procedure FillFpu(Dbg: TDebugger; List: TListBox);
const
  TagNames: array[0..3] of string = ('Valid', 'Zero', 'Special', 'Empty');
  PCNames: array[0..3] of string = ('Single (24 bits)', 'Reserved', 'Double (53 bits)', 'Extended (64 bits)');
  RCNames: array[0..3] of string = ('Round to nearest', 'Round down', 'Round up', 'Truncate');
  ExcNames: array[0..5] of string = ('IE', 'DE', 'ZE', 'OE', 'UE', 'PE');
var
  F: TDbgFPU;
  I, Top, Tag: Integer;
  V, S: string;
begin
  List.Items.BeginUpdate;
  try
    List.Items.Clear;
    if (Dbg = nil) or not Dbg.GetFPU(F) then Exit;
    Top := (F.Status shr 11) and 7;
    for I := 0 to 7 do
    begin
      Tag := (F.Tag shr (2 * ((Top + I) and 7))) and 3;
      if Tag = 3 then V := ''
      else
        try
          V := FloatToStr(F.ST[I]);
        except
          V := '?';
        end;
      List.Items.Add(Format('ST%d  %-7s %s', [I, TagNames[Tag], V]));
    end;
    List.Items.Add('');
    S := Format('Status  %.4x  TOP=%d C3=%d C2=%d C1=%d C0=%d', [F.Status, Top, (F.Status shr 14) and 1,
      (F.Status shr 10) and 1, (F.Status shr 9) and 1, (F.Status shr 8) and 1]);
    if F.Status and $80 <> 0 then S := S + ' ES';
    if F.Status and $40 <> 0 then S := S + ' SF';
    for I := 0 to 5 do
      if F.Status and (1 shl I) <> 0 then S := S + ' ' + ExcNames[I];
    List.Items.Add(S);
    S := Format('Control %.4x  %s, %s, masked:', [F.Control, PCNames[(F.Control shr 8) and 3],
      RCNames[(F.Control shr 10) and 3]]);
    for I := 0 to 5 do
      if F.Control and (1 shl I) <> 0 then S := S + ' ' + Copy(ExcNames[I], 1, 1) + 'M';
    List.Items.Add(S);
    List.Items.Add(Format('Tag     %.4x', [F.Tag]));
    List.Items.Add(Format('Error   %.4x:%.8x  Data %.4x:%.8x', [F.ErrorSelector and $FFFF, F.ErrorOffset,
      F.DataSelector and $FFFF, F.DataOffset]));
  finally
    List.Items.EndUpdate;
  end;
end;


{ ---------------------------------------------------------------- the lists }

procedure FillThreads(Dbg: TDebugger; List: TListView; const StopStatus: string);
var
  T: TDbgThreadArray;
  I: Integer;
  It: TListItem;
begin
  List.Items.BeginUpdate;
  try
    List.Items.Clear;
    if (Dbg = nil) or not Dbg.GetThreads(T) then Exit;
    for I := 0 to High(T) do
    begin
      It := List.Items.Add;
      if T[I].IsCurrent then It.Caption := '> ' + IntToStr(T[I].ThreadId) else It.Caption := IntToStr(T[I].ThreadId);
      It.SubItems.Add('Stopped');
      if T[I].IsCurrent then It.SubItems.Add(StopStatus) else It.SubItems.Add('Runnable');
      It.SubItems.Add(T[I].Location);
      It.Data := Pointer(T[I].ThreadId);
    end;
  finally
    List.Items.EndUpdate;
  end;
end;

procedure FillModules(Dbg: TDebugger; List: TListView);
var
  M: TDbgModuleArray;
  I: Integer;
  It: TListItem;
begin
  List.Items.BeginUpdate;
  try
    List.Items.Clear;
    if (Dbg = nil) or not Dbg.GetModules(M) then Exit;
    for I := 0 to High(M) do
    begin
      It := List.Items.Add;
      It.Caption := M[I].Name;
      It.SubItems.Add(Format('$%.8X', [M[I].BaseAddr]));
      It.SubItems.Add(Format('$%.8X', [M[I].Size]));
      It.SubItems.Add(M[I].Path);
      if M[I].HasDebugInfo then It.SubItems.Add('Debug info') else It.SubItems.Add('Exports');
    end;
  finally
    List.Items.EndUpdate;
  end;
end;

end.
