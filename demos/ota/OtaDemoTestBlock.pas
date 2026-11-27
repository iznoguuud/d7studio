{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoTestBlock;

{ The self-test's block area (OtaDemoTest): Delphi 7's block of an edit buffer - IOTAEditBlock, the
  block of IOTASourceEditor, and what IOTAEditPosition and IOTAEditView.CursorPos do to it - on a
  text file of its own, BlockTest.txt: first without Persistent blocks (Delphi's default), then with
  them, Overwrite blocks on (and once off).

  The expected values are Delphi 7's (measured in its IDE), except where D7 Studio's editor
  differs on purpose: a column block's right column is its edge, outside it, as the editor's
  rectangle shows it; a column block is valid whichever way its
  corners were set, and its Starting / Ending Row and Column are its corners - Delphi 7's takes the
  right column in, set backwards it is not valid, and they read 1 (measured: the checks expect
  each IDE's). }

interface

implementation

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, ToolsAPI, OtaDemoTest;

const
  { BlockTest.txt: no line break after the last line - five lines }
  BlockText =
    'begin'#13#10 +               // 1
    '  abc def'#13#10 +           // 2
    'x'#13#10 +                   // 3
    '  ghi jkl mno'#13#10 +       // 4
    'end.';                       // 5
  { the stream block from 2,3 to 4,6 }
  T1Text = 'abc def'#13#10'x'#13#10'  ghi';
  { the column block 2,3 - 4,6: each row's part and a line break after it - Delphi 7's takes the
    right column in (measured) }
  T8Text = 'abc'#13#10#13#10'ghi'#13#10;
  T8TextD7 = 'abc '#13#10#13#10'ghi '#13#10;
  { a UTF-8 file: a with diaeresis, O with diaeresis - and each in the other case }
  Utf8Text = #$C3#$A4#$C3#$96;
  Utf8Toggled = #$C3#$84#$C3#$B6;

type
  TBlockTests = class(TOtaTestArea)
  private
    FFile: string;
    FPersistent, FOverwrite: Boolean;            // the options the steps run with
    FSavedPersistent, FSavedOverwrite, FSaved: Boolean;
    function Buffer: IOTAEditBuffer;
    function View: IOTAEditView;
    function Block: IOTAEditBlock;
    function Place: IOTAEditPosition;
    function Options: IOTABufferOptions;
    function Ready: Boolean;
    function Line(N: Integer): string;
    function ExpectText(const What, Got, Want: string): Boolean;
    function ExpectCursor(const What: string; Row, Col: Integer): Boolean;
    function ExpectChar(const What: string; const P: TOTACharPos; ALine, CharIndex: Integer): Boolean;
    function EditorWnd: HWND;
    procedure Key(Wnd: HWND; Code: Word; Shift: TShiftState);
    procedure SetOptions(Persistent, Overwrite: Boolean);
    procedure SetText(const S: string);
    procedure Raw(Row, Col: Integer);
    procedure Setup;
    procedure MakeT1;
    procedure MakeT8(Reverse: Boolean);
    procedure CheckTyped(const How: string);
    procedure AddCases(const Mode: string);
    { the steps }
    procedure Open;
    procedure PersistentOff;
    procedure OverwriteOff;
    procedure PersistentOn;
    procedure T1;
    procedure T2;
    procedure T3;
    procedure T4;
    procedure T5;
    procedure T6;
    procedure T7;
    procedure T8;
    procedure T9;
    procedure T10;
    procedure T11;
    procedure T12;
    procedure T13;
    procedure T14;
    procedure T15;
    procedure T16;
    procedure T17;
    procedure T17Char;
    procedure T18;
    procedure T19;
    procedure T20;
    procedure T21;
    procedure T22;
    procedure T23;
    procedure Positions;
    procedure Utf8Case;
    procedure CloseFile;
  public
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

function CharPos(ALine, CharIndex: Integer): TOTACharPos;
begin
  Result.Line := ALine;
  Result.CharIndex := CharIndex;
end;

function EdPos(Row, Col: Integer): TOTAEditPos;
begin
  Result.Line := Row;
  Result.Col := Col;
end;

{ a text for a message: line breaks and other control bytes, bytes beyond ASCII by their code }
function Shown(const S: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    case S[I] of
      #13: Result := Result + '\r';
      #10: Result := Result + '\n';
      #32..#126: Result := Result + S[I];
    else
      Result := Result + Format('\x%.2x', [Ord(S[I])]);
    end;
end;

procedure WriteTextFile(const FileName, Text: string);
var
  F: TFileStream;
begin
  F := TFileStream.Create(FileName, fmCreate);
  try
    if Text <> '' then F.WriteBuffer(Text[1], Length(Text));
  finally
    F.Free;
  end;
end;

function ReadTextFile(const FileName: string): string;
var
  F: TFileStream;
begin
  Result := '';
  if not FileExists(FileName) then Exit;
  F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, F.Size);
    if Result <> '' then F.ReadBuffer(Result[1], Length(Result));
  finally
    F.Free;
  end;
end;

{ --- the clipboard: the desktop's - the formats it holds are put back after the test's copies }

function OpenClip: Boolean;
var
  I: Integer;
begin
  for I := 1 to 20 do
  begin
    Result := OpenClipboard(Application.Handle);
    if Result then Exit;
    Sleep(25);
  end;
end;

{ the clipboard's formats that are memory (not GDI objects, not private handles): the data,
  Objects the format; False when the clipboard could not be opened }
function SaveClipboard(L: TStringList): Boolean;
var
  F: UINT;
  H: THandle;
  P: Pointer;
  D: string;
begin
  L.Clear;
  Result := OpenClip;
  if not Result then Exit;
  try
    F := EnumClipboardFormats(0);
    while F <> 0 do
    begin
      if not ((F = CF_BITMAP) or (F = CF_METAFILEPICT) or (F = CF_PALETTE) or (F = CF_ENHMETAFILE) or
        (F = CF_OWNERDISPLAY) or (F = CF_DSPBITMAP) or (F = CF_DSPMETAFILEPICT) or
        (F = CF_DSPENHMETAFILE) or ((F >= CF_PRIVATEFIRST) and (F <= CF_GDIOBJLAST))) then
      begin
        H := GetClipboardData(F);
        if H <> 0 then
        begin
          P := GlobalLock(H);
          if P <> nil then
          try
            SetString(D, PChar(P), GlobalSize(H));
            L.AddObject(D, TObject(F));
          finally
            GlobalUnlock(H);
          end;
        end;
      end;
      F := EnumClipboardFormats(F);
    end;
  finally
    CloseClipboard;
  end;
end;

procedure RestoreClipboard(L: TStringList);
var
  I, N: Integer;
  G: HGLOBAL;
  P: Pointer;
begin
  if not OpenClip then Exit;
  try
    EmptyClipboard;
    for I := 0 to L.Count - 1 do
    begin
      N := Length(L[I]);
      if N = 0 then N := 1;
      G := GlobalAlloc(GMEM_MOVEABLE or GMEM_ZEROINIT, N);
      if G = 0 then Continue;
      P := GlobalLock(G);
      if P = nil then
      begin
        GlobalFree(G);
        Continue;
      end;
      if L[I] <> '' then Move(PChar(L[I])^, P^, Length(L[I]));
      GlobalUnlock(G);
      if SetClipboardData(UINT(L.Objects[I]), G) = 0 then GlobalFree(G);
    end;
  finally
    CloseClipboard;
  end;
end;

function ClipText: string;
var
  H: THandle;
  P: PChar;
begin
  Result := '';
  if not OpenClip then Exit;
  try
    H := GetClipboardData(CF_TEXT);
    if H = 0 then Exit;
    P := GlobalLock(H);
    if P <> nil then
    try
      Result := P;
    finally
      GlobalUnlock(H);
    end;
  finally
    CloseClipboard;
  end;
end;

{ the first byte of a registered format's data (-1: none) }
function ClipByte(const Format: string): Integer;
var
  H: THandle;
  P: PByte;
begin
  Result := -1;
  if not OpenClip then Exit;
  try
    H := GetClipboardData(RegisterClipboardFormat(PChar(Format)));
    if (H = 0) or (GlobalSize(H) < 1) then Exit;
    P := GlobalLock(H);
    if P <> nil then
    try
      Result := P^;
    finally
      GlobalUnlock(H);
    end;
  finally
    CloseClipboard;
  end;
end;

function ClipHas(const Format: string): Boolean;
begin
  Result := IsClipboardFormatAvailable(RegisterClipboardFormat(PChar(Format)));
end;

{ ---------------------------------------------------------------- TBlockTests }

function TBlockTests.Name: string;
begin
  Result := 'Block';
end;

procedure TBlockTests.AddSteps;
begin
  Step('Open', Open);
  Step('PersistentOff', PersistentOff);
  AddCases('off');
  Step('off.Utf8', Utf8Case);
  Step('OverwriteOff', OverwriteOff);
  Step('off.overwrite-off.T17', T17);
  Step('off.overwrite-off.T17Char', T17Char);
  Step('off.overwrite-off.T18', T18);
  Step('PersistentOn', PersistentOn);
  AddCases('on');
  Step('on.T14', T14);
  Step('Close', CloseFile);
end;

{ the cases that run without Persistent blocks and with them }
procedure TBlockTests.AddCases(const Mode: string);
begin
  Step(Mode + '.T1', T1);
  Step(Mode + '.T2', T2);
  Step(Mode + '.T3', T3);
  Step(Mode + '.T4', T4);
  Step(Mode + '.T5', T5);
  Step(Mode + '.T6', T6);
  Step(Mode + '.T7', T7);
  Step(Mode + '.T8', T8);
  Step(Mode + '.T9', T9);
  Step(Mode + '.T10', T10);
  Step(Mode + '.T11', T11);
  Step(Mode + '.T12', T12);
  Step(Mode + '.T13', T13);
  Step(Mode + '.T15', T15);
  Step(Mode + '.T16', T16);
  Step(Mode + '.T17', T17);
  Step(Mode + '.T17Char', T17Char);
  Step(Mode + '.T18', T18);
  Step(Mode + '.T19', T19);
  Step(Mode + '.T20', T20);
  Step(Mode + '.T21', T21);
  Step(Mode + '.T22', T22);
  Step(Mode + '.T23', T23);
  Step(Mode + '.Positions', Positions);
end;

function TBlockTests.Buffer: IOTAEditBuffer;
var
  M: IOTAModule;
begin
  Result := nil;
  if FFile = '' then Exit;
  M := (BorlandIDEServices as IOTAModuleServices).FindModule(FFile);
  if M <> nil then Supports(SourceEditorOf(M), IOTAEditBuffer, Result);
end;

function TBlockTests.View: IOTAEditView;
var
  B: IOTAEditBuffer;
begin
  B := Buffer;
  if (B <> nil) and (B.EditViewCount > 0) then Result := B.EditViews[0] else Result := nil;
end;

function TBlockTests.Block: IOTAEditBlock;
begin
  Result := View.Block;
end;

function TBlockTests.Place: IOTAEditPosition;
begin
  Result := View.Position;
end;

{ Persistent blocks and Overwrite blocks are editor options of all files }
function TBlockTests.Options: IOTABufferOptions;
begin
  Result := (BorlandIDEServices as IOTAEditorServices).GetEditOptionsForFile('x.txt').BufferOptions;
end;

function TBlockTests.Ready: Boolean;
begin
  Result := View <> nil;
  if not Result then Check(False, 'BlockTest.txt is open with a view');
end;

{ line N (1-based) of the buffer, without its line break }
function TBlockTests.Line(N: Integer): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := EditorText(Buffer);
    if (N >= 1) and (N <= L.Count) then Result := L[N - 1] else Result := '';
  finally
    L.Free;
  end;
end;

function TBlockTests.ExpectText(const What, Got, Want: string): Boolean;
begin
  Result := Check(Got = Want, What, Format('got "%s", expected "%s"', [Shown(Got), Shown(Want)]));
end;

function TBlockTests.ExpectCursor(const What: string; Row, Col: Integer): Boolean;
var
  P: TOTAEditPos;
begin
  P := View.CursorPos;
  Result := Check((P.Line = Row) and (P.Col = Col), What,
    Format('at %d,%d, expected %d,%d', [P.Line, P.Col, Row, Col]));
end;

function TBlockTests.ExpectChar(const What: string; const P: TOTACharPos; ALine, CharIndex: Integer): Boolean;
begin
  Result := Check((P.Line = ALine) and (P.CharIndex = CharIndex), What,
    Format('line %d, char %d - expected line %d, char %d', [P.Line, P.CharIndex, ALine, CharIndex]));
end;

function TBlockTests.EditorWnd: HWND;
begin
  Result := EditorControlOf(FFile);
end;

{ a key as the keyboard gives it to the code editor: the VCL's CN_KEYDOWN (the key mapping, the
  experts' bindings), then the editor's WM_KEYDOWN when nothing took it; Shift in the thread's key
  state meanwhile }
procedure TBlockTests.Key(Wnd: HWND; Code: Word; Shift: TShiftState);
var
  Old, KS: TKeyboardState;
begin
  GetKeyboardState(Old);
  KS := Old;
  if ssShift in Shift then KS[VK_SHIFT] := $80 else KS[VK_SHIFT] := 0;
  KS[VK_CONTROL] := 0;
  KS[VK_MENU] := 0;
  SetKeyboardState(KS);
  try
    if SendMessage(Wnd, CN_KEYDOWN, Code, 1) = 0 then SendMessage(Wnd, WM_KEYDOWN, Code, 1);
  finally
    SetKeyboardState(Old);
  end;
end;

procedure TBlockTests.SetOptions(Persistent, Overwrite: Boolean);
var
  O: IOTABufferOptions;
begin
  O := Options;
  O.PersistentBlocks := Persistent;
  O.OverwriteBlocks := Overwrite;
  FPersistent := Persistent;
  FOverwrite := Overwrite;
  Check((O.PersistentBlocks = Persistent) and (O.OverwriteBlocks = Overwrite),
    'IOTABufferOptions: Persistent blocks and Overwrite blocks as set');
end;

{ the whole text replaced through an undoable writer }
procedure TBlockTests.SetText(const S: string);
var
  W: IOTAEditWriter;
begin
  W := Buffer.CreateUndoableWriter;
  W.DeleteTo(MaxInt);
  W.Insert(PChar(S));
  W := nil;
end;

{ IOTAEditView.CursorPos: a write of the cursor, no editor command }
procedure TBlockTests.Raw(Row, Col: Integer);
begin
  View.CursorPos := EdPos(Row, Col);
end;

{ the text as at the start, the cursor at 1,1, a non-inclusive block reset there - not marked: its
  ends are one place }
procedure TBlockTests.Setup;
begin
  SetText(BlockText);
  Raw(1, 1);
  Block.Style := btNonInclusive;
  Block.Reset;
end;

procedure TBlockTests.MakeT1;
begin
  Setup;
  Raw(2, 3);
  Block.BeginBlock;
  Raw(4, 6);
  Block.EndBlock;
end;

procedure TBlockTests.MakeT8(Reverse: Boolean);
begin
  Setup;
  Block.Style := btColumn;
  if Reverse then Raw(4, 6) else Raw(2, 3);
  Block.BeginBlock;
  if Reverse then Raw(2, 3) else Raw(4, 6);
  Block.EndBlock;
end;

procedure TBlockTests.Open;
begin
  FFile := Dir + 'BlockTest.txt';
  WriteTextFile(FFile, BlockText);
  Check((BorlandIDEServices as IOTAActionServices).OpenFile(FFile), 'IOTAActionServices.OpenFile');
  if not Check(Buffer <> nil, 'the file is a module with an edit buffer') then Exit;
  Check(View <> nil, 'the buffer has an edit view');
  FSavedPersistent := Options.PersistentBlocks;
  FSavedOverwrite := Options.OverwriteBlocks;
  FSaved := True;
end;

procedure TBlockTests.PersistentOff;
begin
  SetOptions(False, True);
end;

procedure TBlockTests.OverwriteOff;
begin
  SetOptions(False, False);
end;

procedure TBlockTests.PersistentOn;
begin
  SetOptions(True, True);
end;

{ BeginBlock and EndBlock with the cursor written between them: the stream block 2,3 - 4,6 }
procedure TBlockTests.T1;
var
  E, F: Integer;
begin
  if not Ready then Exit;
  MakeT1;
  ExpectText('BeginBlock at 2,3, EndBlock at 4,6: Text', Block.Text, T1Text);
  ExpectInt('Size', Block.Size, Length(T1Text));
  ExpectInt('StartingRow', Block.StartingRow, 2);
  ExpectInt('StartingColumn', Block.StartingColumn, 3);
  ExpectInt('EndingRow', Block.EndingRow, 4);
  ExpectInt('EndingColumn', Block.EndingColumn, 6);
  Check(Block.IsValid and Block.Visible, 'IsValid and Visible');
  Check(Buffer.BlockType = btNonInclusive, 'BlockType btNonInclusive');
  { Delphi 7's BlockVisible: True for a marked block with Persistent blocks only (measured) }
  Check(Buffer.BlockVisible = FPersistent, 'BlockVisible: True with Persistent blocks only');
  ExpectChar('BlockStart', Buffer.BlockStart, 2, 2);
  ExpectChar('BlockAfter', Buffer.BlockAfter, 4, 5);
  ExpectCursor('the cursor stays where EndBlock was', 4, 6);
  View.GetAttributeAtPos(EdPos(3, 1), False, E, F);
  ExpectInt('GetAttributeAtPos inside the block: the token''s - SyntaxOff in a file without highlighting, no MarkedBlock', E, SyntaxOff);
  View.GetAttributeAtPos(EdPos(1, 1), False, E, F);
  Check(E <> MarkedBlock, 'GetAttributeAtPos before the block: not MarkedBlock');
end;

{ Move is a cursor command of the editor: without Persistent blocks it hides the block and puts
  both its ends at the cursor before the move; with them the block stays }
procedure TBlockTests.T2;
begin
  if not Ready then Exit;
  MakeT1;
  Place.Move(1, 1);
  if FPersistent then
  begin
    Check(Block.IsValid, 'after Move: IsValid');
    ExpectText('after Move: the block stays', Block.Text, T1Text);
  end
  else
  begin
    Check(not Block.IsValid, 'after Move: not valid (collapsed)');
    ExpectText('after Move: Text', Block.Text, '');
    Check(not Buffer.BlockVisible, 'after Move: BlockVisible False');
    ExpectChar('BlockStart at the cursor before the move', Buffer.BlockStart, 4, 5);
    ExpectChar('BlockAfter at the cursor before the move', Buffer.BlockAfter, 4, 5);
  end;
end;

{ IOTAEditView.CursorPos is no editor command: the block keeps its ends; without Persistent blocks
  it is marked only while the cursor is at one of them }
procedure TBlockTests.T3;
begin
  if not Ready then Exit;
  MakeT1;
  Raw(1, 1);
  ExpectChar('CursorPos elsewhere: BlockStart kept', Buffer.BlockStart, 2, 2);
  ExpectChar('CursorPos elsewhere: BlockAfter kept', Buffer.BlockAfter, 4, 5);
  if FPersistent then
    ExpectText('CursorPos elsewhere: Text', Block.Text, T1Text)
  else
  begin
    Check(not Block.IsValid, 'CursorPos elsewhere: not marked');
    ExpectText('CursorPos elsewhere: Text', Block.Text, '');
  end;
  Raw(2, 3);
  Check(Block.IsValid, 'CursorPos at the block''s start: marked');
  ExpectText('CursorPos at the block''s start: Text', Block.Text, T1Text);
end;

{ BlockStart and BlockAfter set the ends as they are given: the cursor does not move }
procedure TBlockTests.T4;
begin
  if not Ready then Exit;
  Setup;
  Buffer.BlockStart := CharPos(3, 0);
  Buffer.BlockAfter := CharPos(3, 1);
  ExpectCursor('the cursor stays at 1,1', 1, 1);
  ExpectChar('BlockStart', Buffer.BlockStart, 3, 0);
  ExpectChar('BlockAfter', Buffer.BlockAfter, 3, 1);
  if FPersistent then
    ExpectText('Text', Block.Text, 'x')
  else
  begin
    Check(not Block.IsValid, 'not marked: the cursor is at neither end');
    Raw(3, 1);
    ExpectText('the cursor at its start: Text', Block.Text, 'x');
    Raw(3, 2);
    ExpectText('the cursor at its end: Text', Block.Text, 'x');
  end;
end;

{ an end before the start: not valid, the ends reported as they were set }
procedure TBlockTests.T5;
begin
  if not Ready then Exit;
  Setup;
  Buffer.BlockStart := CharPos(3, 1);
  Buffer.BlockAfter := CharPos(3, 0);
  Check(not Block.IsValid, 'an inverted block is not valid');
  ExpectChar('BlockStart', Buffer.BlockStart, 3, 1);
  ExpectChar('BlockAfter', Buffer.BlockAfter, 3, 0);
end;

{ Extend: from the cursor (a block that is not marked collapses there), then on from its anchor }
procedure TBlockTests.T6;
begin
  if not Ready then Exit;
  Setup;
  Raw(2, 3);
  Block.Reset;
  Check(Block.Extend(2, 6), 'Extend(2, 6)');
  ExpectText('Extend(2, 6): Text', Block.Text, 'abc');
  Block.Extend(4, 1);
  ExpectText('Extend(4, 1): the anchor stays', Block.Text, 'abc def'#13#10'x'#13#10);
  Block.ExtendRelative(0, 2);
  ExpectText('ExtendRelative(0, 2)', Block.Text, 'abc def'#13#10'x'#13#10'  ');
  Check(Block.Extend(99, 1), 'Extend(99, 1): True - the row within the text');
  ExpectCursor('Extend(99, 1): the cursor on the last row', 5, 1);
end;

{ Extend from the block's start: its other end is the anchor }
procedure TBlockTests.T7;
begin
  if not Ready then Exit;
  MakeT1;
  Raw(2, 3);
  Block.ExtendRelative(0, 1);
  ExpectText('the block shrinks from its start', Block.Text, 'bc def'#13#10'x'#13#10'  ghi');
  ExpectInt('StartingColumn', Block.StartingColumn, 4);
end;

{ a column block: each row's part and a line break after it, the right column its edge; its
  corners top-left and bottom-right whichever way they were set }
procedure TBlockTests.T8;
var
  Rev: Boolean;
  W, T: string;
  E, F: Integer;
begin
  if not Ready then Exit;
  for Rev := False to True do
  begin
    MakeT8(Rev);
    if Rev then W := 'set from 4,6 to 2,3: ' else W := 'set from 2,3 to 4,6: ';
    if Rev then T := IdeText('', T8Text) else T := IdeText(T8TextD7, T8Text);
    ExpectText(W + 'Text', Block.Text, T);
    ExpectInt(W + 'Size', Block.Size, Length(T));
    ExpectInt(W + 'StartingRow', Block.StartingRow, IdeValue(1, 2));
    ExpectInt(W + 'StartingColumn', Block.StartingColumn, IdeValue(1, 3));
    ExpectInt(W + 'EndingRow', Block.EndingRow, IdeValue(1, 4));
    ExpectInt(W + 'EndingColumn', Block.EndingColumn, IdeValue(1, 6));
    Check(Buffer.BlockType = btColumn, W + 'BlockType btColumn');
    if Rev then
    begin
      ExpectChar(W + 'BlockStart: the first corner as an edit position', Buffer.BlockStart, 4, 6);
      ExpectChar(W + 'BlockAfter', Buffer.BlockAfter, 2, 3);
    end
    else
    begin
      ExpectChar(W + 'BlockStart: the first corner as an edit position', Buffer.BlockStart, 2, 3);
      ExpectChar(W + 'BlockAfter', Buffer.BlockAfter, 4, 6);
    end;
  end;
  View.GetAttributeAtPos(EdPos(3, 3), False, E, F);
  ExpectInt('GetAttributeAtPos inside the rectangle: the token''s, no MarkedBlock', E, SyntaxOff);
  View.GetAttributeAtPos(EdPos(2, 6), False, E, F);
  Check(E <> MarkedBlock, 'GetAttributeAtPos on the right edge: not MarkedBlock');
end;

{ the case commands of a column block: the rectangle only }
procedure TBlockTests.T9;
begin
  if not Ready then Exit;
  MakeT8(False);
  Block.UpperCase;
  ExpectText('UpperCase: line 2', Line(2), '  ABC def');
  ExpectText('UpperCase: line 3', Line(3), 'x');
  ExpectText('UpperCase: line 4', Line(4), '  GHI jkl mno');
  Check(Buffer.BlockType = btColumn, 'still a column block');
  ExpectText('the block''s text', Block.Text, IdeText('ABC '#13#10#13#10'GHI '#13#10, 'ABC'#13#10#13#10'GHI'#13#10));
  Block.ToggleCase;
  ExpectText('ToggleCase: line 2 back', Line(2), '  abc def');
  ExpectText('ToggleCase: line 4 back', Line(4), '  ghi jkl mno');
  Block.UpperCase;
  Block.LowerCase;
  ExpectText('LowerCase: line 4', Line(4), '  ghi jkl mno');
end;

{ Delete of a column block: each row's part }
procedure TBlockTests.T10;
begin
  if not Ready then Exit;
  MakeT8(False);
  Check(Block.Delete, 'Delete');
  ExpectText('line 2', Line(2), IdeText('  def', '   def'));
  ExpectText('line 3', Line(3), 'x');
  ExpectText('line 4', Line(4), IdeText('  jkl mno', '   jkl mno'));
  Check(not Block.IsValid, 'deleted: hidden');
  Check(not Buffer.BlockVisible, 'deleted: BlockVisible False');
end;

{ Copy: the block's text and its kind ("Borland IDE Block Type"; a column block also
  "MSDEVColumnSelect"); Copy(True) appends text; Paste. The clipboard's contents are put back. }
procedure TBlockTests.T11;
var
  Saved: TStringList;
begin
  if not Ready then Exit;
  Saved := TStringList.Create;
  try
    if not SaveClipboard(Saved) then
    begin
      Note('the clipboard could not be opened: Copy not checked');
      Exit;
    end;
    try
      MakeT8(False);
      Block.Copy(False);
      ExpectText('a column block: the clipboard''s text', ClipText, IdeText(T8TextD7, T8Text));
      ExpectInt('"Borland IDE Block Type": btColumn', ClipByte('Borland IDE Block Type'), Ord(btColumn));
      if D7StudioOnly('"MSDEVColumnSelect" (Scintilla''s rectangle format)') then
        Check(ClipHas('MSDEVColumnSelect'), '"MSDEVColumnSelect": a rectangle for Scintilla and Visual Studio');
      MakeT1;
      Block.Copy(False);
      ExpectText('a stream block: the clipboard''s text', ClipText, T1Text);
      ExpectInt('"Borland IDE Block Type": btNonInclusive', ClipByte('Borland IDE Block Type'), Ord(btNonInclusive));
      Check(not ClipHas('MSDEVColumnSelect'), 'no "MSDEVColumnSelect"');
      Block.Copy(True);
      ExpectText('Copy(True): after the clipboard''s text', ClipText, T1Text + T1Text);
      Block.Copy(False);
      Raw(5, 5);
      Place.Paste;
      ExpectText('Paste at the cursor', Line(5), 'end.abc def');
      ExpectCursor('the cursor after the text pasted', 7, 6);
      if FPersistent then
        ExpectText('Paste with Persistent blocks: the text pasted is the block', Block.Text, T1Text)
      else
        Check(not Block.IsValid, 'Paste without Persistent blocks: the block collapsed');
      MakeT1;
      Block.Cut(False);
      ExpectText('Cut: the clipboard''s text', ClipText, T1Text);
      ExpectText('Cut: the block deleted', Line(2), '   jkl mno');
      Check(not Block.IsValid, 'Cut: the block is gone');
    finally
      RestoreClipboard(Saved);
    end;
  finally
    Saved.Free;
  end;
end;

{ a line block: whole lines; Indent of its lines (not the line its end is the start of); Reset
  in line mode: the cursor's line }
procedure TBlockTests.T12;
begin
  if not Ready then Exit;
  Setup;
  Block.Style := btLine;
  Raw(2, 3);
  Block.BeginBlock;
  Raw(3, 1);
  Block.EndBlock;
  Check(Buffer.BlockType = btLine, 'BlockType btLine');
  ExpectText('a line block: whole lines', Block.Text, '  abc def'#13#10'x'#13#10);
  Block.Indent(2);
  ExpectText('Indent(2): line 2', Line(2), '    abc def');
  ExpectText('Indent(2): line 3', Line(3), '  x');
  ExpectText('Indent(2): not line 4 (the block ends at its start)', Line(4), '  ghi jkl mno');
  Raw(1, 3);
  Block.Reset;
  Check(Block.IsValid, 'Reset in line mode: valid');
  ExpectText('Reset in line mode: the cursor''s line', Block.Text, 'begin'#13#10);
end;

{ an inclusive block takes the character at its end }
procedure TBlockTests.T13;
begin
  if not Ready then Exit;
  Setup;
  Block.Style := btInclusive;
  Raw(2, 3);
  Block.BeginBlock;
  Raw(2, 5);
  Block.EndBlock;
  Check(Buffer.BlockType = btInclusive, 'BlockType btInclusive');
  ExpectText('btInclusive: Text', Block.Text, 'abc');
  Block.Style := btNonInclusive;
  ExpectText('btNonInclusive: Text', Block.Text, 'ab');
end;

{ with Persistent blocks the ends follow the edits as Delphi 7's do (measured): text at the block's
  end lands after it, at its start before it. After an undoable writer's write, wherever its text
  went, Delphi 7's block is no longer valid; D7 Studio's stays, on purpose }
procedure TBlockTests.T14;
var
  W: IOTAEditWriter;
begin
  if not Ready then Exit;
  MakeT1;
  W := Buffer.CreateUndoableWriter;
  W.CopyTo(View.CharPosToPos(CharPos(4, 5)));
  W.Insert('Y');
  W := nil;
  ExpectText('a writer''s text at the block''s end: after it (Delphi 7: no longer valid)', Block.Text, IdeText('', T1Text));
  MakeT1;
  W := Buffer.CreateUndoableWriter;
  W.CopyTo(View.CharPosToPos(CharPos(5, 0)));
  W.Insert('V');
  W := nil;
  ExpectText('a writer''s text far from the block (Delphi 7: no longer valid)', Block.Text, IdeText('', T1Text));
  MakeT1;
  Place.Move(5, 1);
  Place.InsertText('U');
  ExpectText('InsertText far from the block: the block stays', Block.Text, T1Text);
  MakeT1;
  W := Buffer.CreateUndoableWriter;
  W.CopyTo(View.CharPosToPos(CharPos(2, 2)));
  W.Insert('Z');
  W := nil;
  ExpectText('a writer''s text at the start: before the block', Line(2), '  Zabc def');
  ExpectText('... the block (Delphi 7: no longer valid)', Block.Text, IdeText('', T1Text));
end;
{ Visible := False hides the block and keeps its ends; Visible := True shows it again }
procedure TBlockTests.T15;
begin
  if not Ready then Exit;
  MakeT1;
  Block.Visible := False;
  Check(not Block.IsValid, 'Visible := False: not marked');
  ExpectText('Visible := False: Text', Block.Text, '');
  ExpectChar('Visible := False: BlockStart kept', Buffer.BlockStart, 2, 2);
  ExpectChar('Visible := False: BlockAfter kept', Buffer.BlockAfter, 4, 5);
  Block.Visible := True;
  ExpectText('Visible := True: the same block', Block.Text, T1Text);
end;

{ Save and Restore of the block: values, shown again }
procedure TBlockTests.T16;
begin
  if not Ready then Exit;
  MakeT1;
  Block.Save;
  Block.Reset;
  ExpectText('Reset: an empty block', Block.Text, '');
  Block.Restore;
  ExpectText('Restore: the block saved', Block.Text, T1Text);
  Check(Block.Visible, 'Restore shows it');
  Block.Restore;
  ExpectText('Restore with nothing saved: no change', Block.Text, T1Text);
end;

{ text at the cursor on the marked block - Delphi's typing rule }
procedure TBlockTests.CheckTyped(const How: string);
begin
  if FPersistent then
  begin
    ExpectText(How + ': at the cursor', Line(4), '  ghiQ jkl mno');
    ExpectText(How + ': at the block''s end the text is after it', Block.Text, T1Text);
  end
  else if FOverwrite then
  begin
    ExpectText(How + ' on the marked block (Overwrite blocks): it is replaced', Line(2), '  Q jkl mno');
    Check(not Block.IsValid, How + ': the block is gone');
  end
  else
  begin
    ExpectText(How + ': at the cursor', Line(4), '  ghiQ jkl mno');
    Check(not Block.IsValid, How + ': the block hidden');
    { InsertText leaves an empty block at the cursor that is not hidden, a key (InsertCharacter)
      hides it: Delphi 7's BlockVisible (measured) }
    Check(Buffer.BlockVisible = (How = 'InsertText'), How + ': BlockVisible True for InsertText only');
  end;
end;

procedure TBlockTests.T17;
begin
  if not Ready then Exit;
  MakeT1;
  Place.InsertText('Q');
  CheckTyped('InsertText');
end;

{ InsertCharacter is a key press }
procedure TBlockTests.T17Char;
begin
  if not Ready then Exit;
  MakeT1;
  Place.InsertCharacter('Q');
  CheckTyped('InsertCharacter');
end;

{ Delete on the marked block: Delphi's typing rule first - a block it deletes is the character }
procedure TBlockTests.T18;
begin
  if not Ready then Exit;
  MakeT1;
  Place.Delete(1);
  if not FPersistent and FOverwrite then
  begin
    ExpectText('Delete(1) on the marked block: the block, no character more', Line(2), '   jkl mno');
    Check(not Block.IsValid, 'the block is gone');
  end
  else
  begin
    ExpectText('Delete(1): the character after the cursor', Line(4), '  ghijkl mno');
    if FPersistent then ExpectText('the block stays', Block.Text, T1Text)
    else Check(not Block.IsValid, 'the block hidden (Overwrite blocks off)');
  end;
end;

{ ToggleCase: each letter to its other case }
procedure TBlockTests.T19;
begin
  if not Ready then Exit;
  Setup;
  SetText('aBc x'#13#10'end.');
  Raw(1, 1);
  Block.BeginBlock;
  Raw(1, 4);
  Block.EndBlock;
  Block.ToggleCase;
  ExpectText('ToggleCase', Line(1), 'AbC x');
end;

{ Move: 0 is the cursor's row or column, the column at most 1024, past a line's end in virtual
  space; True when the cursor moved }
procedure TBlockTests.T20;
begin
  if not Ready then Exit;
  Setup;
  Raw(2, 3);
  Check(not Place.Move(0, 0), 'Move(0, 0): the cursor''s row and column - False, no move');
  ExpectCursor('Move(0, 0): the cursor stays', 2, 3);
  Check(Place.Move(3, 99), 'Move(3, 99): True');
  ExpectCursor('Move(3, 99): past the line''s end', 3, 99);
  Place.Move(3, 2000);
  ExpectCursor('Move(3, 2000): the column at most 1024', 3, 1024);
  Place.Move(1, 0);
  ExpectCursor('Move(1, 0): the column kept', 1, 1024);
end;

{ SaveToFile: the marked block's text (False without one); InsertFile: the file's text at the
  cursor - with Persistent blocks it is the block, without them there is none }
procedure TBlockTests.T23;
var
  F: string;
begin
  if not Ready then Exit;
  F := Dir + 'BlockSaved.txt';
  MakeT1;
  Check(Block.SaveToFile(F), 'SaveToFile');
  ExpectText('SaveToFile: the block''s text', ReadTextFile(F), T1Text);
  if not FPersistent then
  begin
    Raw(1, 1);
    Check(not Block.SaveToFile(Dir + 'BlockNone.txt'), 'SaveToFile without a marked block: False');
  end;
  Setup;
  Raw(5, 5);
  Place.InsertFile(F);
  ExpectText('InsertFile: the file''s text at the cursor', Line(5), 'end.abc def');
  ExpectCursor('InsertFile: the cursor after it', 7, 6);
  if FPersistent then
    ExpectText('InsertFile with Persistent blocks: the text read is the block', Block.Text, T1Text)
  else
    Check(not Block.IsValid, 'InsertFile without Persistent blocks: no block');
  SysUtils.DeleteFile(F);
end;

{ a selection the user made (Shift and the cursor keys) is the block - made backwards as well }
procedure TBlockTests.T21;
var
  Wnd: HWND;
  I: Integer;
begin
  if not Ready then Exit;
  Setup;
  Wnd := EditorWnd;
  if not Check(Wnd <> 0, 'the code editor''s window of BlockTest.txt') then Exit;
  Raw(2, 3);
  for I := 1 to 3 do Key(Wnd, VK_RIGHT, [ssShift]);
  ExpectText('Shift+Right three times from 2,3: the block', Block.Text, 'abc');
  ExpectInt('... StartingColumn', Block.StartingColumn, 3);
  Setup;
  Raw(2, 6);
  for I := 1 to 3 do Key(Wnd, VK_LEFT, [ssShift]);
  ExpectText('Shift+Left three times from 2,6: the block', Block.Text, 'abc');
  ExpectInt('... StartingColumn', Block.StartingColumn, 3);
  ExpectInt('... EndingColumn', Block.EndingColumn, 6);
  Check(Buffer.BlockType = btNonInclusive, '... a non-inclusive block');
end;

{ the user's cursor keys: without Persistent blocks they collapse the block (seen by the next call
  of the API); with them it stays }
procedure TBlockTests.T22;
var
  Wnd: HWND;
begin
  if not Ready then Exit;
  MakeT1;
  Wnd := EditorWnd;
  if not Check(Wnd <> 0, 'the code editor''s window of BlockTest.txt') then Exit;
  Key(Wnd, VK_RIGHT, []);
  if FPersistent then
    ExpectText('a cursor key: the block stays', Block.Text, T1Text)
  else
    Check(not Block.IsValid, 'a cursor key collapsed the block');
end;

{ Delphi 7's positions (measured): MoveRelative by the distances - into virtual space, never across a
  line's end -, MoveReal (Delphi 7's keeps the row), Save / Restore of the row and column,
  Tab as a move by tab stops }
procedure TBlockTests.Positions;
var
  D: Integer;
begin
  if not Ready then Exit;
  Setup;
  Raw(3, 2);
  Place.MoveRelative(0, 1);
  ExpectCursor('MoveRelative(0, 1) at a line''s end: on into virtual space', 3, 3);
  Place.MoveRelative(0, -1);
  ExpectCursor('MoveRelative(0, -1): back', 3, 2);
  Raw(4, 1);
  Place.MoveRelative(0, -1);
  ExpectCursor('MoveRelative(0, -1) at a line''s start: it stays', 4, 1);
  Raw(1, 1);
  Place.MoveRelative(2, 3);
  ExpectCursor('MoveRelative(2, 3)', 3, 4);
  Raw(1, 1);
  Place.MoveReal(4, 3);
  ExpectCursor('MoveReal(4, 3) (Delphi 7: the row stays)', IdeValue(1, 4), 3);
  Place.Save;
  Place.Move(1, 1);
  Place.Restore;
  ExpectCursor('Save, Move, Restore: the row and the column saved', IdeValue(1, 4), 3);
  Raw(2, 1);
  D := Place.DistanceToTab(sdForward);
  Place.Tab(1);
  ExpectCursor('Tab(1): the next tab stop', 2, 1 + D);
  ExpectText('Tab(1): nothing inserted', Line(2), '  abc def');
  Place.Tab(-1);
  ExpectCursor('Tab(-1): back', 2, 1);
end;

{ ToggleCase in a UTF-8 file: the characters' case, beyond ASCII too }
procedure TBlockTests.Utf8Case;
var
  F: string;
  M: IOTAModule;
  B: IOTAEditBuffer;
  V: IOTAEditView;
begin
  if not D7StudioOnly('a UTF-8 file (D7 Studio''s UTF-8 mode)') then Exit;
  F := Dir + 'BlockUtf8.txt';
  WriteTextFile(F, #$EF#$BB#$BF + Utf8Text);
  if not Check((BorlandIDEServices as IOTAActionServices).OpenFile(F), 'OpenFile of a UTF-8 file') then Exit;
  M := (BorlandIDEServices as IOTAModuleServices).FindModule(F);
  if not Check((M <> nil) and Supports(SourceEditorOf(M), IOTAEditBuffer, B) and (B.EditViewCount > 0),
    'the UTF-8 file has a view') then Exit;
  V := B.EditViews[0];
  V.CursorPos := EdPos(1, 1);
  V.Block.BeginBlock;
  V.CursorPos := EdPos(1, 3);
  V.Block.EndBlock;
  V.Block.ToggleCase;
  ExpectText('ToggleCase in a UTF-8 file', EditorText(B), Utf8Toggled);
  V := nil;
  B := nil;
  M.CloseModule(True);
end;

procedure TBlockTests.CloseFile;
var
  M: IOTAModule;
begin
  if FSaved then
  begin
    Options.PersistentBlocks := FSavedPersistent;
    Options.OverwriteBlocks := FSavedOverwrite;
    FSaved := False;
  end;
  M := (BorlandIDEServices as IOTAModuleServices).FindModule(FFile);
  if not Check(M <> nil, 'BlockTest.txt is open') then Exit;
  Check(M.CloseModule(True), 'CloseModule(True)');
end;

{ the options as they were, also when the test stops early }
procedure TBlockTests.Cleanup;
begin
  if FSaved then
  try
    Options.PersistentBlocks := FSavedPersistent;
    Options.OverwriteBlocks := FSavedOverwrite;
    FSaved := False;
  except
  end;
end;

initialization
  RegisterTestArea(TBlockTests, 55);
end.
