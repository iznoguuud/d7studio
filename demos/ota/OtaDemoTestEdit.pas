{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoTestEdit;

{ The self-test's editor area (OtaDemoTest): a text file of its own, EditTest.txt, opened with
  IOTAActionServices.OpenFile, and IOTAEditPosition, IOTAEditReader / IOTAEditWriter, undo, the
  line tracker and the bookmarks of IOTAEditView checked on it, the popup menus experts find by
  name on its edit window and the main window, and Delphi's edit window as experts find it past
  the Open Tools API (its editor control, coreide70.bpl's routines called on it); then View as
  Text on TestUnit's form (IOTAEditActions.SwapSourceFormView).

  MoveCursor is checked against Delphi 7's own behaviour (it moves OVER the characters of the
  mask's class, as the Open Tools API help says; ToolsAPI's comment says "to the next"): the
  expected positions below are Delphi's. }

interface

implementation

uses
  Windows, SysUtils, Classes, Controls, Forms, Menus, TypInfo, ToolsAPI, OtaDemoTest;

const
  { EditTest.txt: no line break after the last line - LastRow is 4 }
  EditText =
    'alpha_1  beta(gamma);'#13#10 +    // 1: 21 characters
    '    delta'#13#10 +                // 2: 9
    ''#13#10 +                         // 3: empty
    '  epsilon';                       // 4: 9

type
  TCountingLineNotifier = class(TNotifierObject, IOTANotifier, IOTAEditLineNotifier)
  public
    Changes, Destroys: Integer;
    LastOld, LastNew, LastData: Integer;
    procedure Destroyed;
    procedure LineChanged(OldLine, NewLine: Integer; Data: Integer);
  end;

  { what the experts are told as a form is shown as text and back: the IDE's file notifications and
    the module's Destroyed }
  TSwapNotifier = class(TOtaEventNotifier, IOTANotifier, IOTAIDENotifier, IOTAModuleNotifier)
  public
    procedure Destroyed;
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string;
      var Cancel: Boolean); override;
    function CheckOverwrite: Boolean;
    procedure ModuleRenamed(const NewName: string);
    function Said: string;                 // the events, separated by commas
  end;

  TEditorTests = class(TOtaTestArea)
  private
    FFile: string;
    FLines: TCountingLineNotifier;
    FLinesIntf: IOTAEditLineNotifier;
    FMenu: TPopupMenu;
    FIdePopup: TNotifyEvent;
    FSwap: TSwapNotifier;
    FSwapIntf: IOTAIDENotifier;
    FSwapIndex: Integer;
    procedure MenuPopup(Sender: TObject);
    function Buffer: IOTAEditBuffer;
    function View: IOTAEditView;
    function Line(N: Integer): string;
    function ExpectPos(const What: string; Row, Col: Integer): Boolean;
    function SwapTopView: Boolean;
    function TextShown: Boolean;
    function FormShown: Boolean;
    procedure Open;
    procedure MoveCursor;
    procedure CharClasses;
    procedure Positions;
    procedure InsertDelete;
    procedure Search;
    procedure Replace;
    procedure Offsets;
    procedure Undo;
    procedure LineTracker;
    procedure Bookmarks;
    procedure PopupMenus;
    procedure EditWindow;
    procedure CloseFile;
    procedure ViewAsText;
    procedure ShownAsText;
    procedure ShownAsForm;
  public
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

procedure TSwapNotifier.Destroyed;
begin
  Events.Add('Destroyed');
end;

procedure TSwapNotifier.FileNotification(NotifyCode: TOTAFileNotification; const FileName: string;
  var Cancel: Boolean);
const
  Codes: array[ofnFileOpening..ofnFileClosing] of string = ('opening', 'opened', 'closing');
begin
  if NotifyCode in [ofnFileOpening..ofnFileClosing] then
    Events.Add(Codes[NotifyCode] + ' ' + ExtractFileName(FileName));
end;

function TSwapNotifier.CheckOverwrite: Boolean;
begin
  Result := True;
end;

procedure TSwapNotifier.ModuleRenamed(const NewName: string);
begin
end;

function TSwapNotifier.Said: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Events.Count - 1 do
  begin
    if I > 0 then Result := Result + ',';
    Result := Result + Events[I];
  end;
end;
procedure TCountingLineNotifier.Destroyed;
begin
  Inc(Destroys);
end;

procedure TCountingLineNotifier.LineChanged(OldLine, NewLine: Integer; Data: Integer);
begin
  Inc(Changes);
  LastOld := OldLine;
  LastNew := NewLine;
  LastData := Data;
end;

function TEditorTests.Name: string;
begin
  Result := 'Editor';
end;

procedure TEditorTests.AddSteps;
begin
  Step('Open', Open);
  Step('MoveCursor', MoveCursor);
  Step('Classes', CharClasses);
  Step('Positions', Positions);
  Step('InsertDelete', InsertDelete);
  Step('Undo', Undo);
  Step('Search', Search);
  Step('Replace', Replace);
  Step('Offsets', Offsets);
  Step('LineTracker', LineTracker);
  Step('Bookmarks', Bookmarks);
  Step('PopupMenus', PopupMenus);
  Step('EditWindow', EditWindow);
  Step('Close', CloseFile);
  Step('ViewAsText', ViewAsText);
  Step('ShownAsText', ShownAsText);
  Step('ShownAsForm', ShownAsForm);
end;

function TEditorTests.Buffer: IOTAEditBuffer;
var
  M: IOTAModule;
begin
  Result := nil;
  M := (BorlandIDEServices as IOTAModuleServices).FindModule(FFile);
  if M <> nil then Supports(SourceEditorOf(M), IOTAEditBuffer, Result);
end;

function TEditorTests.View: IOTAEditView;
var
  B: IOTAEditBuffer;
begin
  B := Buffer;
  if (B <> nil) and (B.EditViewCount > 0) then Result := B.EditViews[0] else Result := nil;
end;

{ line N (1-based) of the buffer, without its line break }
function TEditorTests.Line(N: Integer): string;
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

function TEditorTests.ExpectPos(const What: string; Row, Col: Integer): Boolean;
var
  P: IOTAEditPosition;
begin
  P := View.Position;
  Result := Check((P.Row = Row) and (P.Column = Col), What,
    Format('at %d,%d, expected %d,%d', [P.Row, P.Column, Row, Col]));
end;

procedure TEditorTests.Open;
var
  F: TFileStream;
  S: string;
begin
  FFile := Dir + 'EditTest.txt';
  F := TFileStream.Create(FFile, fmCreate);
  try
    S := EditText;
    F.WriteBuffer(S[1], Length(S));
  finally
    F.Free;
  end;
  Check((BorlandIDEServices as IOTAActionServices).OpenFile(FFile), 'IOTAActionServices.OpenFile');
  if not Check(Buffer <> nil, 'the file is a module with an edit buffer') then Exit;
  Check(View <> nil, 'the buffer has an edit view');
  ExpectInt('GetLinesInBuffer', Buffer.GetLinesInBuffer, 4);
  Expect('the reader gives the file''s text', EditorText(Buffer), EditText);
end;

{ the positions Delphi 7's IOTAEditPosition.MoveCursor gives (measured) }
procedure TEditorTests.MoveCursor;
var
  P: IOTAEditPosition;
begin
  P := View.Position;
  P.Move(1, 1);
  P.MoveCursor(mmSkipWord or mmSkipRight);
  ExpectPos('word, right: over "alpha_1"', 1, 8);
  P.MoveCursor(mmSkipWhite or mmSkipRight);
  ExpectPos('white, right: over the two spaces', 1, 10);
  P.MoveCursor(mmSkipWord or mmSkipRight);
  ExpectPos('word, right: over "beta"', 1, 14);
  P.MoveCursor(mmSkipSpecial or mmSkipRight);
  ExpectPos('special, right: over "("', 1, 15);
  P.MoveCursor(mmSkipNonSpecial or mmSkipRight);
  ExpectPos('non-special, right: over "gamma"', 1, 20);
  P.MoveCursor(mmSkipNonWhite or mmSkipRight);
  ExpectPos('non-white, right: over ");" to the line''s end', 1, 22);
  P.MoveCursor(mmSkipWord or mmSkipRight);
  ExpectPos('word, right at the line''s end: no move', 1, 22);
  P.MoveCursor(mmSkipWhite or mmSkipRight or mmSkipStream);
  ExpectPos('white, right, stream at the line''s end: the next line and its indent', 2, 5);
  P.MoveCursor(mmSkipWord or mmSkipLeft);
  ExpectPos('word, left with a space before: no move', 2, 5);
  P.MoveCursor(mmSkipWhite or mmSkipLeft);
  ExpectPos('white, left: over the indent', 2, 1);
  P.MoveCursor(mmSkipWord or mmSkipLeft);
  ExpectPos('word, left at the line''s start: no move (without mmSkipStream a skip stays in its line)', 2, 1);
  P.MoveCursor(mmSkipWord or mmSkipLeft or mmSkipStream);
  ExpectPos('word, left, stream at the line''s start: the end of the line above', 1, 22);
  P.Move(1, 12);
  P.MoveCursor(mmSkipWord or mmSkipLeft);
  ExpectPos('word, left inside "beta": its start', 1, 10);
  P.Move(4, 1);
  P.MoveCursor(mmSkipWhite or mmSkipLeft or mmSkipStream);
  ExpectPos('white, left, stream at a line''s start: over the empty line to the end of "delta"', 2, 10);
end;

{ Delphi's classes: white is a tab or a space only; the line's end is #13 and special }
procedure TEditorTests.CharClasses;
var
  P: IOTAEditPosition;
begin
  P := View.Position;
  P.Move(1, 1);
  Check(P.IsWordCharacter, 'IsWordCharacter on "a"');
  P.Move(1, 8);
  Check(P.IsWhitespace, 'IsWhitespace on a space');
  P.Move(1, 14);
  Check(P.IsSpecialCharacter, 'IsSpecialCharacter on "("');
  P.Move(1, 22);
  ExpectInt('Character at the line''s end is #13', Ord(P.Character), 13);
  Check(not P.IsWhitespace, 'the line''s end is no white space');
  Check(P.IsSpecialCharacter, 'the line''s end is special');
end;

procedure TEditorTests.Positions;
var
  P: IOTAEditPosition;
begin
  P := View.Position;
  P.Move(2, 5);
  ExpectPos('Move', 2, 5);
  P.MoveRelative(1, 0);
  ExpectInt('MoveRelative: one row down', P.Row, 3);
  P.Move(2, 7);
  P.MoveBOL;
  ExpectPos('MoveBOL', 2, 1);
  P.MoveEOL;
  ExpectPos('MoveEOL', 2, 10);
  P.MoveEOF;
  ExpectPos('MoveEOF', 4, 10);
  ExpectInt('LastRow', P.LastRow, 4);
  P.GotoLine(2);
  ExpectInt('GotoLine', P.Row, 2);
  P.Move(1, 1);
  Expect('Read(5)', P.Read(5), 'alpha');
  ExpectPos('Read does not move the cursor', 1, 1);
end;

procedure TEditorTests.InsertDelete;
var
  P: IOTAEditPosition;
begin
  P := View.Position;
  P.Move(3, 1);
  P.InsertText('xyz');
  Expect('InsertText into the empty line', Line(3), 'xyz');
  ExpectPos('the cursor after the inserted text', 3, 4);
  P.Move(3, 1);
  P.Delete(1);
  Expect('Delete(1)', Line(3), 'yz');
  P.Move(3, 3);
  P.BackspaceDelete(1);
  Expect('BackspaceDelete(1)', Line(3), 'y');
  P.Move(3, 1);
  P.Delete(1);
  Expect('the line is empty again', Line(3), '');
end;

{ IOTAEditPosition.Search as Delphi 7's (measured): WholeFile False searches the marked block -
  none: error 2 -, True the whole file from its start; the cursor after the match, no block left; a
  pattern not found is no error; SearchAgain goes on from the cursor. Delphi 7's finds nothing
  backward, D7 Studio's does, on purpose }
procedure TEditorTests.Search;
var
  V: IOTAEditView;
  P: IOTAEditPosition;
  Err: Integer;
begin
  V := View;
  P := V.Position;
  P.Move(1, 1);
  Err := -1;
  Check(not P.Search('delta', True, False, False, sdForward, Err), 'Search in the block, none marked: not found');
  ExpectInt('... error 2', Err, 2);
  Expect('... its text', P.GetSearchErrorString(Err), 'Tried to search selected text but no text is selected');
  P.Move(3, 1);
  Check(P.Search('alpha', True, False, True, sdForward, Err), 'Search in the whole file finds "alpha" before the cursor');
  ExpectInt('... error 0', Err, 0);
  ExpectPos('... the cursor after the match', 1, 6);
  Check(not V.Block.IsValid, '... no block left');
  P.Move(1, 1);
  Check(P.Search('a', True, False, True, sdForward, Err), 'Search finds "a"');
  ExpectPos('... the first', 1, 2);
  Check(P.SearchAgain, 'SearchAgain finds the next');
  ExpectPos('... after the cursor', 1, 6);
  Check(P.SearchAgain, 'SearchAgain again');
  ExpectPos('... the next one', 1, 14);
  P.Move(3, 1);
  Check(not P.SearchAgain, 'SearchAgain from line 3: none after the cursor');
  ExpectPos('... the cursor stays', 3, 1);
  P.Move(1, 1);
  Err := -1;
  Check(not P.Search('nowhere', True, False, True, sdForward, Err), 'Search does not find "nowhere"');
  ExpectInt('... no error (0)', Err, 0);
  Expect('GetSearchErrorString(0) is empty', P.GetSearchErrorString(0), '');
  Expect('GetSearchErrorString(1)', P.GetSearchErrorString(1),
    'Tried to search selected text from cursor but cursor is outside selected text');
  Expect('GetSearchErrorString(4)', P.GetSearchErrorString(4), 'The search string cannot be blank.');
  Expect('GetSearchErrorString(12)', P.GetSearchErrorString(12), 'Unmatched []s');
  Expect('GetSearchErrorString(-1)', P.GetSearchErrorString(-1), 'Internal error');
  Expect('GetSearchErrorString(14)', P.GetSearchErrorString(14), 'Trailing ''\''');
  Expect('GetSearchErrorString(15)', P.GetSearchErrorString(15), 'Internal error');
  Err := -1;
  Check(not P.Search('', True, False, True, sdForward, Err), 'Search of a blank pattern: not found');
  ExpectInt('... error 4', Err, 4);
  P.Move(1, 1);
  V.Block.BeginBlock;
  V.Block.Extend(2, 10);
  V.Block.EndBlock;
  Check(V.Block.IsValid and (V.Block.StartingRow = 1) and (V.Block.EndingRow = 2),
    'a block marked: BeginBlock, Extend(2, 10), EndBlock');
  ExpectPos('... the cursor at its end', 2, 10);
  Check(P.Search('delta', True, False, False, sdForward, Err), 'Search in the block finds "delta" - the whole block');
  ExpectPos('... the cursor after the match', 2, 10);
  V.Block.Reset;
  P.Move(4, 10);
  if D7StudioOnly('Search backward (Delphi 7''s finds nothing backward)') then
  begin
    Check(P.Search('alpha', True, False, True, sdBackward, Err), 'Search backward in the whole file finds "alpha"');
    ExpectPos('... the cursor at the match''s start', 1, 1);
  end;
end;

{ IOTAEditPosition.Replace as Delphi 7's (measured): one match replaced, as Search finds it, the
  cursor after the replacement; ReplaceAgain the next one from the cursor }
procedure TEditorTests.Replace;
var
  P: IOTAEditPosition;
  Err: Integer;
begin
  P := View.Position;
  P.Move(3, 1);
  ExpectInt('Replace in the whole file: one replaced', P.Replace('a', 'A', True, False, True, sdForward, Err), 1);
  ExpectInt('... error 0', Err, 0);
  Expect('... the first match', Line(1), 'Alpha_1  beta(gamma);');
  ExpectPos('... the cursor after it', 1, 2);
  ExpectInt('ReplaceAgain: one more', P.ReplaceAgain, 1);
  Expect('... the next match', Line(1), 'AlphA_1  beta(gamma);');
  P.Move(1, 1);
  Err := -1;
  ExpectInt('Replace in the block, none marked: none replaced', P.Replace('A', 'a', True, False, False, sdForward, Err), 0);
  ExpectInt('... error 2', Err, 2);
  P.Move(1, 1);
  P.Replace('A', 'a', True, False, True, sdForward, Err);
  P.ReplaceAgain;
  Expect('the line as it was', Line(1), 'alpha_1  beta(gamma);');
end;

procedure TEditorTests.Offsets;
var
  V: IOTAEditView;
  C: TOTACharPos;
  Off: Integer;
begin
  V := View;
  C.Line := 2;
  C.CharIndex := 4;
  Off := V.CharPosToPos(C);
  ExpectInt('CharPosToPos(2, 4): the byte offset', Off, 21 + 2 + 4);
  C := V.PosToCharPos(Off);
  Check((C.Line = 2) and (C.CharIndex = 4), 'PosToCharPos gives the char position back',
    Format('%d, %d', [C.Line, C.CharIndex]));
end;

{ an undoable writer's write is one undo step, and Delphi 7's editor has one after it that takes back
  no text (measured: every time) - two Undo calls take a write back; writes in a row (nothing else
  between them) go back together }
procedure TEditorTests.Undo;
var
  Before: string;

  procedure Write(Pos: Integer; const Text: string);
  var
    W: IOTAEditWriter;
  begin
    W := Buffer.CreateUndoableWriter;
    W.CopyTo(Pos);
    W.Insert(PChar(Text));
  end;

begin
  Before := EditorText(Buffer);
  Write(0, 'UNDO ');
  Expect('the undoable writer inserted', Copy(EditorText(Buffer), 1, 5), 'UNDO ');
  Check(Buffer.Undo, 'IOTAEditBuffer.Undo');
  Expect('the first Undo takes back no text', Copy(EditorText(Buffer), 1, 5), 'UNDO ');
  Check(Buffer.Undo, 'IOTAEditBuffer.Undo again');
  Check(EditorText(Buffer) = Before, 'the second takes the whole write back');
  Write(0, 'ONE ');
  Write(23, 'TWO ');
  Buffer.Undo;
  Buffer.Undo;
  Check(EditorText(Buffer) = Before, 'two writes in a row: two Undo calls take both back');
end;
{ the tracked line follows edits: lines inserted at its start push it down (its text moves).
  Delphi 7 tells the line's way in three steps - for one line break 2 > 3, 3 > 4, 4 > 3
  (measured) -, D7 Studio tells the move once, on purpose }
procedure TEditorTests.LineTracker;
var
  T: IOTAEditLineTracker;
  W: IOTAEditWriter;
  C: TOTACharPos;
  I: Integer;
begin
  T := Buffer.GetEditLineTracker;
  if not Check(T <> nil, 'GetEditLineTracker') then Exit;
  FLines := TCountingLineNotifier.Create;
  FLinesIntf := FLines;
  T.AddNotifier(FLinesIntf);
  T.AddLine(2, 42);
  I := T.IndexOfData(42);
  Check(I >= 0, 'IndexOfData');
  ExpectInt('LineNum of the tracked line', T.LineNum[I], 2);
  C.Line := 2;
  C.CharIndex := 0;
  W := Buffer.CreateUndoableWriter;
  W.CopyTo(View.CharPosToPos(C));
  W.Insert('inserted line'#13#10);
  W := nil;
  ExpectInt('a line inserted at its start moves the tracked line down', T.LineNum[I], 3);
  ExpectInt('LineChanged calls (Delphi 7: three steps)', FLines.Changes, IdeValue(3, 1));
  Check((FLines.LastNew = 3) and (FLines.LastData = 42), 'the last LineChanged: to line 3, its data 42',
    Format('LineChanged(%d, %d, %d)', [FLines.LastOld, FLines.LastNew, FLines.LastData]));
  C.Line := 3;
  C.CharIndex := 6;
  W := Buffer.CreateUndoableWriter;
  W.CopyTo(View.CharPosToPos(C));
  W.Insert('x'#13#10);
  W := nil;
  ExpectInt('a line break inside the tracked line leaves it', T.LineNum[I], 3);
  Buffer.Undo;
  Buffer.Undo;
  ExpectInt('undone: the tracked line is back at line 2', T.LineNum[I], 2);
end;
procedure TEditorTests.Bookmarks;
var
  V: IOTAEditView;
  C: TOTACharPos;
begin
  V := View;
  V.Position.Move(4, 3);
  Check(V.BookmarkRecord(2), 'BookmarkRecord(2)');
  C := V.BookmarkPos[2];
  Check((C.Line = 4) and (C.CharIndex = 2), 'BookmarkPos[2] is line 4, char 2',
    Format('%d, %d', [C.Line, C.CharIndex]));
  V.Position.Move(1, 1);
  Check(V.BookmarkGoto(2), 'BookmarkGoto(2)');
  ExpectPos('the cursor is at the bookmark, its column too', 4, 3);
end;

const
  SelfTestItemName = 'OtaDemoSelfTestItem';

{ an expert's OnPopup for the editor's menu, as experts chain it: the IDE's own handler first
  (Delphi 7's makes the menu's items anew), then the expert's item when it is not there }
procedure TEditorTests.MenuPopup(Sender: TObject);
var
  Item: TMenuItem;
begin
  if Assigned(FIdePopup) then FIdePopup(Sender);
  if FMenu.FindComponent(SelfTestItemName) = nil then
  begin
    Item := TMenuItem.Create(FMenu);
    Item.Name := SelfTestItemName;
    Item.Caption := 'OtaDemo self-test item';
    FMenu.Items.Add(Item);
  end;
end;

{ The popup menus experts find by name - Delphi 7 has no interface for them: the edit window's
  (INTAEditWindow.Form) EditorLocalMenu, BackMenu and ForwardMenu, and the main window's
  ClosedFilesPopup, ProcessMenu and ToolbarsPopup. An item an expert adds from an OnPopup of its
  own is in the editor's menu and visible after the IDE's handler ran again. }
procedure TEditorTests.PopupMenus;
const
  EditNames: array[0..2] of string = ('EditorLocalMenu', 'BackMenu', 'ForwardMenu');
  MainNames: array[0..2] of string = ('ClosedFilesPopup', 'ProcessMenu', 'ToolbarsPopup');
var
  W: INTAEditWindow;
  Form: TCustomForm;
  I: Integer;
  Item: TComponent;
begin
  if not Check(View <> nil, 'the edit view') then Exit;
  W := View.GetEditWindow;
  if not Check(W <> nil, 'GetEditWindow') then Exit;
  Form := W.Form;
  if not Check(Form <> nil, 'INTAEditWindow.Form') then Exit;
  Check(W.StatusBar <> nil, 'INTAEditWindow.StatusBar');
  for I := Low(EditNames) to High(EditNames) do
    Check(Form.FindComponent(EditNames[I]) is TPopupMenu, 'the edit window has the popup menu ' + EditNames[I]);
  for I := Low(MainNames) to High(MainNames) do
    Check(Application.MainForm.FindComponent(MainNames[I]) is TPopupMenu,
      'the main window has the popup menu ' + MainNames[I]);
  if not (Form.FindComponent('EditorLocalMenu') is TPopupMenu) then Exit;
  FMenu := TPopupMenu(Form.FindComponent('EditorLocalMenu'));
  FIdePopup := FMenu.OnPopup;
  Check(Assigned(FIdePopup), 'EditorLocalMenu has the IDE''s OnPopup');
  FMenu.OnPopup := MenuPopup;
  try
    { what TPopupMenu.Popup does before the menu shows, twice }
    FMenu.OnPopup(FMenu);
    Item := FMenu.FindComponent(SelfTestItemName);
    Check((Item is TMenuItem) and (FMenu.Items.IndexOf(TMenuItem(Item)) >= 0),
      'the expert''s item is in EditorLocalMenu');
    FMenu.OnPopup(FMenu);
    Item := FMenu.FindComponent(SelfTestItemName);
    Check((Item is TMenuItem) and TMenuItem(Item).Visible and (FMenu.Items.IndexOf(TMenuItem(Item)) >= 0),
      'the IDE''s OnPopup leaves the expert''s item in the menu, visible');
    { the demo's own item (OtaDemoWizard: hooked when a file was opened) }
    Item := nil;
    for I := 0 to FMenu.Items.Count - 1 do
      if SameText(FMenu.Items[I].Name, 'OtaDemoWordItem') then Item := FMenu.Items[I];
    Check((Item <> nil) and TMenuItem(Item).Visible, 'the demo''s item OTA Demo: Word at Cursor is in EditorLocalMenu');
  finally
    FMenu.OnPopup := FIdePopup;
    FMenu.FindComponent(SelfTestItemName).Free;
    FMenu := nil;
  end;
end;

{ a window's class name, as Windows has it (experts' focus hooks compare it) }
function WindowClassOf(Wnd: HWND): string;
var
  Buf: array[0..63] of Char;
begin
  GetClassName(Wnd, Buf, SizeOf(Buf));
  Result := Buf;
end;

{ the start of a window's text (the editor's: its text) }
function WindowTextOf(Wnd: HWND): string;
var
  Buf: array[0..255] of Char;
begin
  FillChar(Buf, SizeOf(Buf), 0);
  GetWindowText(Wnd, Buf, SizeOf(Buf));
  Result := Buf;
end;

type
  TControlAccess = class(TControl);
  { Delphi's TCustomEditControl.GetTextAtLine and GetAttributeAtPos (coreide70.bpl), as CnWizards
    declares and calls them }
  TGetTextAtLine = function(Self: TObject; LineNum: Integer): string;
  TGetAttributeAtPos = procedure(Self: TObject; const EdPos: TOTAEditPos; var Element, LineFlag: Integer;
    IncludeMargin, Unused: Boolean);

{ Delphi's edit window as experts find it past the Open Tools API: the form in Screen.Forms (class
  TEditWindow, named EditWindow_N) is INTAEditWindow.Form; its editor control (class TEditControl,
  named Editor) has the editor's menu and the published properties experts read by RTTI; the file
  tabs (TabControl, class TXTabControl) have a menu; the editor control's routines exported by
  coreide70.bpl, called on it, answer for the file shown }
procedure TEditorTests.EditWindow;
var
  V: IOTAEditView;
  Form, Found: TCustomForm;
  Ed, Tabs: TComponent;
  I, E1, L1, E2, L2: Integer;
  H: HMODULE;
  GetTextAtLine: TGetTextAtLine;
  GetAttributeAtPos: TGetAttributeAtPos;
  P: TOTAEditPos;
begin
  V := View;
  if not Check(V <> nil, 'the edit view') then Exit;
  Found := nil;
  for I := 0 to Screen.FormCount - 1 do
    if (Pos('EditWindow_', Screen.Forms[I].Name) = 1) and Screen.Forms[I].ClassNameIs('TEditWindow') then
      Found := Screen.Forms[I];
  Check(Found <> nil, 'Screen.Forms has a form of class TEditWindow named EditWindow_N');
  Form := V.GetEditWindow.Form;
  Check((Form <> nil) and (Form = Found), 'INTAEditWindow.Form is that form');
  if Form = nil then Exit;
  Ed := Form.FindComponent('Editor');
  if not Check(Ed is TWinControl, 'the edit window has a windowed control named Editor') then Exit;
  Expect('Editor''s class', Ed.ClassName, 'TEditControl');
  Check(Ed is TCustomControl, 'Editor is a TCustomControl (experts take its Canvas)');
  Expect('Editor''s window class', WindowClassOf(TWinControl(Ed).Handle), 'TEditControl');
  Check(TControlAccess(Ed).PopupMenu = Form.FindComponent('EditorLocalMenu'), 'Editor''s menu is EditorLocalMenu');
  { Editor is the code editor itself (one window for every file): an expert that gives it the
    keyboard (GExperts after a jump) finds it as the active control, showing the file }
  if Check(TWinControl(Ed).CanFocus, 'Editor.CanFocus') then
  begin
    TWinControl(Ed).SetFocus;
    Check((GetFocus = TWinControl(Ed).Handle) and IsWindowVisible(GetFocus), 'Editor.SetFocus: the keyboard is in Editor');
    Check(Screen.ActiveControl = Ed, 'Screen.ActiveControl is Editor');
    if D7StudioOnly('Editor''s window text (Scintilla''s)') then
      Expect('Editor''s window text: the file''s', Copy(WindowTextOf(TWinControl(Ed).Handle), 1, 21), 'alpha_1  beta(gamma);');
  end;
  V.Position.Move(1, 3);
  Expect('LineText (RTTI): the caret''s line', GetStrProp(Ed, 'LineText'), 'alpha_1  beta(gamma);');
  ExpectInt('CaretY (RTTI)', GetOrdProp(Ed, 'CaretY'), 1);
  ExpectInt('CaretX (RTTI)', GetOrdProp(Ed, 'CaretX'), 3);
  ExpectInt('LineCount (RTTI)', GetOrdProp(Ed, 'LineCount'), Buffer.GetLinesInBuffer);
  Check(GetOrdProp(Ed, 'TopLine') >= 1, 'TopLine (RTTI)');
  Tabs := Form.FindComponent('TabControl');
  Check((Tabs <> nil) and Tabs.ClassNameIs('TXTabControl'), 'the edit window has TabControl of class TXTabControl');
  Check((Tabs is TControl) and (TControlAccess(Tabs).PopupMenu <> nil), 'TabControl has a menu');
  H := GetModuleHandle('coreide70.bpl');
  if not Check(H <> 0, 'coreide70.bpl is loaded') then Exit;
  @GetTextAtLine := GetProcAddress(H, '@Editors@TCustomEditControl@GetTextAtLine$qqri');
  if Check(Assigned(GetTextAtLine), 'coreide70 exports TCustomEditControl.GetTextAtLine') then
  begin
    Expect('GetTextAtLine(Editor, 1)', GetTextAtLine(Ed, 1), 'alpha_1  beta(gamma);');
    Expect('GetTextAtLine(Editor, 2)', GetTextAtLine(Ed, 2), '    delta');
  end;
  @GetAttributeAtPos := GetProcAddress(H, '@Editors@TCustomEditControl@GetAttributeAtPos$qqrrx9Ek@TEdPosrit2oo');
  if Check(Assigned(GetAttributeAtPos), 'coreide70 exports TCustomEditControl.GetAttributeAtPos') then
  begin
    P.Line := 1;
    P.Col := 3;
    E1 := -1;
    L1 := -1;
    GetAttributeAtPos(Ed, P, E1, L1, False, True);
    V.GetAttributeAtPos(P, False, E2, L2);
    Check((E1 = E2) and (L1 = L2), 'GetAttributeAtPos(Editor) answers as IOTAEditView.GetAttributeAtPos',
      Format('%d/%d, the view %d/%d', [E1, L1, E2, L2]));
  end;
end;

procedure TEditorTests.CloseFile;
var
  M: IOTAModule;
begin
  M := (BorlandIDEServices as IOTAModuleServices).FindModule(FFile);
  if not Check(M <> nil, 'EditTest.txt is open') then Exit;
  Check(M.CloseModule(True), 'CloseModule(True)');
  M := nil;
  if FLines <> nil then
    { Delphi 7 tells a line tracker's notifiers nothing as the file closes (measured); D7 Studio
      tells them Destroyed once, as every notifier }
    ExpectInt('the line tracker''s notifier was told Destroyed (Delphi 7: not)', FLines.Destroys, IdeValue(0, 1));
  FLinesIntf := nil;
end;

procedure TEditorTests.Cleanup;
begin
  if FSwapIntf <> nil then (BorlandIDEServices as IOTAServices).RemoveNotifier(FSwapIndex);
  FSwapIntf := nil;
  inherited Cleanup;
end;

{ IOTAEditActions.SwapSourceFormView on the top view; False: no view }
function TEditorTests.SwapTopView: Boolean;
var
  B: IOTAEditBuffer;
  A: IOTAEditActions;
begin
  B := (BorlandIDEServices as IOTAEditorServices).TopBuffer;
  Result := (B <> nil) and (B.EditViewCount > 0) and Supports(B.EditViews[0], IOTAEditActions, A);
  if Result then A.SwapSourceFormView;
end;

function TEditorTests.TextShown: Boolean;
var
  B: IOTAEditBuffer;
begin
  B := (BorlandIDEServices as IOTAEditorServices).TopBuffer;
  Result := (B <> nil) and SameText(ExtractFileExt(B.FileName), '.dfm');
end;

function TEditorTests.FormShown: Boolean;
begin
  Result := FormEditorOf((BorlandIDEServices as IOTAModuleServices).FindModule(Test.Values['Unit'])) <> nil;
end;

{ View as Text (Alt+F12) as Delphi 7 does it (measured): IOTAEditActions.SwapSourceFormView is
  posted - nothing changes before the IDE reads its messages, and no reference to the editors it
  replaces may be held then (Delphi 7 raises an exception for one) -; the form's text opens as a
  module of its own and the unit's module closes }
procedure TEditorTests.ViewAsText;
var
  M: IOTAModule;
  FE: IOTAFormEditor;
begin
  M := (BorlandIDEServices as IOTAModuleServices).FindModule(Test.Values['Unit']);
  FE := FormEditorOf(M);
  if not Check(FE <> nil, 'TestUnit has a form editor') then Exit;
  FE.Show;
  FE := nil;
  Check(Supports(M.CurrentEditor, IOTAFormEditor), 'the form editor is the current editor');
  FSwap := TSwapNotifier.Create;
  FSwapIntf := FSwap;
  FSwapIndex := (BorlandIDEServices as IOTAServices).AddNotifier(FSwapIntf);
  M.AddNotifier(FSwap as IOTAModuleNotifier);
  if not Check(SwapTopView, 'the top view has IOTAEditActions') then Exit;
  Check(Supports(M.CurrentEditor, IOTAFormEditor) and not TextShown,
    'SwapSourceFormView is posted: right after the call the form is shown still');
  WaitFor(TextShown, 'the form''s text shown', 10);
end;

{ the form shown as text: the unit's name finds the text's module, which has one file; then View
  as Form on the text's view }
procedure TEditorTests.ShownAsText;
var
  MS: IOTAModuleServices;
  M: IOTAModule;
  E: IOTAEditor;
  B: IOTAEditBuffer;
  Dfm, Listed: string;
  I: Integer;
begin
  MS := BorlandIDEServices as IOTAModuleServices;
  Dfm := ChangeFileExt(Test.Values['Unit'], '.dfm');
  Expect('the experts are told: the text opens, the unit closes', FSwap.Said,
    'opening TestUnit.dfm,opened TestUnit.dfm,closing TestUnit.pas,Destroyed');
  M := MS.FindModule(Test.Values['Unit']);
  if not Check(M <> nil, 'FindModule of the unit finds a module') then Exit;
  Expect('... the text''s', ExtractFileName(M.FileName), ExtractFileName(Dfm));
  Check(SameModule(M, MS.FindModule(Dfm)), 'FindModule of the form''s text finds the same module');
  ExpectInt('the text''s module has one file', M.ModuleFileCount, 1);
  E := M.ModuleFileEditors[0];
  Check(Supports(E, IOTASourceEditor) and SameText(E.FileName, Dfm),
    'ModuleFileEditors[0] is the source editor of the form''s text');
  E := M.CurrentEditor;
  Check((E <> nil) and SameText(E.FileName, Dfm), 'the current editor is the form''s text');
  B := (BorlandIDEServices as IOTAEditorServices).TopBuffer;
  Check((B <> nil) and (Pos('object ' + 'TestForm', EditorText(B)) > 0), 'the top buffer holds the form''s text');
  Check((B <> nil) and SameModule(B.Module, M), 'the top buffer is the text''s module''s');
  Listed := '';
  for I := 0 to MS.ModuleCount - 1 do
    if SameText(ChangeFileExt(ExtractFileName(MS.Modules[I].FileName), ''), 'TestUnit') then
      Listed := Listed + ' ' + ExtractFileName(MS.Modules[I].FileName);
  Expect('the modules list the text, not the unit', Trim(Listed), ExtractFileName(Dfm));
  FSwap.Events.Clear;
  M.AddNotifier(FSwap as IOTAModuleNotifier);
  if not Check(SwapTopView, 'the text''s view has IOTAEditActions') then Exit;
  WaitFor(FormShown, 'the form shown again', 10);
end;

{ View as Form: the unit's module opens again with its form editor, the text's module closes }
procedure TEditorTests.ShownAsForm;
var
  MS: IOTAModuleServices;
  M: IOTAModule;
  Want: string;
begin
  MS := BorlandIDEServices as IOTAModuleServices;
  { Delphi 7 tells the text's module's notifiers Destroyed twice (measured); D7 Studio tells every
    notifier once }
  if IdeIsDelphi7 then Want := ',Destroyed' else Want := '';
  Expect('the experts are told: the unit opens, the text closes', FSwap.Said,
    'opening TestUnit.pas,opened TestUnit.pas,closing TestUnit.dfm,Destroyed' + Want);
  (BorlandIDEServices as IOTAServices).RemoveNotifier(FSwapIndex);
  FSwapIntf := nil;
  M := MS.FindModule(Test.Values['Unit']);
  Check((M <> nil) and SameText(M.FileName, Test.Values['Unit']), 'FindModule of the unit finds the unit''s module again');
  Check((M <> nil) and Supports(M.ModuleFileEditors[1], IOTAFormEditor), 'ModuleFileEditors[1] is the form editor again');
  Check(MS.FindModule(ChangeFileExt(Test.Values['Unit'], '.dfm')) = nil, 'FindModule of the form''s text finds none');
end;
initialization
  RegisterTestArea(TEditorTests, 50);
end.
