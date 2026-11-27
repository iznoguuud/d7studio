{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoTestCodeInsight;

{ The self-test's code insight area (OtaDemoTest): IOTACodeInsightServices with the demo's manager
  for *.otademo files (OtaDemoCodeInsight), which logs every call it gets, driven as a user drives
  it - IOTAEditActions.CodeCompletion, keys and characters given to the code editor (CN_KEYDOWN,
  WM_KEYDOWN, WM_CHAR, as the VCL hands them on; Ctrl in the thread's key state), a Ctrl+click,
  the editor's dwell notification.

  * The managers: Delphi 7's markup manager first, then the Pascal one ('Borland.CodeInsight.Pascal':
    D7 Studio's own code insight); AddCodeInsightManager of a known IDString gives its index and adds
    nothing; a removed manager goes, the later ones one index down.
  * SetQueryContext: the edit view and the manager it sets, no viewer, no InsertText.
  * The list: Delphi's sequence of calls, the viewer (rows - kept after the list closes -, a row
    chosen only where the expert's FindSymIndex finds the typed text, no string of rows the expert
    draws, the close key), the manager's drawing, a key that accepts (Enter, ';'), Esc, a filter
    that follows typing, CancelCodeInsightProcessing (no Done), multi-select rows (Space).
  * The parameters: Delphi's sequence, the anchor, ParameterCodeInsightParamIndex as the caret
    moves (D7 Studio's: Delphi 7 did not ask for them on a desktop of its own).
  * The delay of a '.': EditorTokenValidChars(True), PreValidateCodeInsight, InvokeCodeCompletion
    with itAuto.
  * Browse (Ctrl+click): GotoDefinition at the identifier clicked - the line shown; one it cannot
    find: "Unable to locate file" in the status bar. The hint of a word (GetHintText): shown in D7
    Studio's code tip (its window of the class TSdCodeTip), gone when the dwell ends.
  * The Pascal manager switched off: no list in a Pascal unit; on again: the list.
  * D7 Studio's own list is Delphi's code completion window as experts find it: FindWindow of the
    class TCodeCompleteListView named KibitzWindow, visible while the list is open. }

interface

implementation

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, ComCtrls, ToolsAPI, OtaDemoTest,
  OtaDemoCodeInsight;

const
  FirstLine = 'Red: the colour of fire';
  SCI_POSITIONFROMLINE = 2167;
  SCI_POINTXFROMPOSITION = 2164;
  SCI_POINTYFROMPOSITION = 2165;
  SCI_TEXTHEIGHT = 2279;
  SCN_DWELLSTART = 2016;
  SCN_DWELLEND = 2017;

type
  TCITests = class(TOtaTestArea)
  private
    FDemo: TDemoCIManager;
    FDemoIntf: IOTACodeInsightManager;
    FIndex, FIndexB, FCount: Integer;
    FDemoB: IOTACodeInsightManager;
    FFile, FUnit: string;
    FMark: Integer;
    FWaitText: string;
    function Svc: IOTACodeInsightServices;
    function Buffer(const FileName: string): IOTAEditBuffer;
    function View: IOTAEditView;
    function Line(N: Integer): string;
    function EditorWindow: HWND;            // the window of the test file's code editor
    procedure Key(Code: Word; Shift: TShiftState; Ch: Char);
    procedure Chars(const S: string);
    procedure MoveTo(L, C: Integer);
    procedure Invoke(Style: TCodeCompleteStyle);
    function ViewerCount: Integer;
    function ListOpen: Boolean;
    function Drawn: Boolean;
    function Logged: Boolean;
    function InOrder(const Calls: array of string): Boolean;
    function Current: IOTACodeInsightManager;
    function PascalIndex: Integer;
    procedure Managers;
    procedure Add;
    procedure OpenFile;
    procedure QueryContext;
    procedure List;
    procedure ListChecks;
    procedure TypeFilter;
    procedure Accept;
    procedure CloseKeyStart;
    procedure CloseKey;
    procedure EscapeStart;
    procedure Escape;
    procedure CancelStart;
    procedure Cancel;
    procedure Params;
    procedure ParamIndex;
    procedure ParamsClose;
    procedure Delay;
    procedure DelayChecks;
    procedure Browse;
    procedure BrowseFail;
    procedure Hint;
    procedure MultiStart;
    procedure Multi;
    procedure PascalStart;
    procedure PascalOff;
    procedure PascalOn;
    procedure PascalData;
    procedure PascalBack;
    procedure RemoveStart;
    procedure Remove;
    procedure Finish;
  public
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

function TCITests.Name: string;
begin
  Result := 'CodeInsight';
end;

procedure TCITests.AddSteps;
begin
  Step('Managers', Managers);
  Step('Add', Add);
  Step('File', OpenFile);
  Step('QueryContext', QueryContext);
  Step('List', List);
  Step('ListChecks', ListChecks);
  Step('TypeFilter', TypeFilter);
  Step('Accept', Accept);
  Step('CloseKeyStart', CloseKeyStart);
  Step('CloseKey', CloseKey);
  Step('EscapeStart', EscapeStart);
  Step('Escape', Escape);
  Step('CancelStart', CancelStart);
  Step('Cancel', Cancel);
  Step('Params', Params);
  Step('ParamIndex', ParamIndex);
  Step('ParamsClose', ParamsClose);
  Step('Delay', Delay);
  Step('DelayChecks', DelayChecks);
  Step('Browse', Browse);
  Step('BrowseFail', BrowseFail);
  Step('Hint', Hint);
  Step('MultiStart', MultiStart);
  Step('Multi', Multi);
  Step('PascalStart', PascalStart);
  Step('PascalOff', PascalOff);
  Step('PascalOn', PascalOn);
  Step('PascalData', PascalData);
  Step('PascalBack', PascalBack);
  Step('RemoveStart', RemoveStart);
  Step('Remove', Remove);
  Step('Finish', Finish);
end;

procedure TCITests.Cleanup;
var
  I: Integer;
  M: IOTACodeInsightManager;
begin
  DemoMultiSelect := False;
  Svc.SetQueryContext(nil, nil);
  Svc.CancelCodeInsightProcessing;
  { the managers the area added, whatever index they have now }
  for I := Svc.CodeInsightManagerCount - 1 downto 1 do
  begin
    M := Svc.CodeInsightManager[I];
    if (M.GetIDString = DemoCIID) or (M.GetIDString = DemoCIID + '.B') then Svc.RemoveCodeInsightManager(I);
  end;
  if PascalIndex >= 0 then Svc.CodeInsightManager[PascalIndex].Enabled := True;
  FDemoIntf := nil;
  FDemoB := nil;
end;

function TCITests.Svc: IOTACodeInsightServices;
begin
  Result := BorlandIDEServices as IOTACodeInsightServices;
end;

function TCITests.Buffer(const FileName: string): IOTAEditBuffer;
var
  M: IOTAModule;
begin
  Result := nil;
  M := (BorlandIDEServices as IOTAModuleServices).FindModule(FileName);
  if M <> nil then Supports(SourceEditorOf(M), IOTAEditBuffer, Result);
end;

function TCITests.View: IOTAEditView;
var
  B: IOTAEditBuffer;
begin
  B := Buffer(FFile);
  if B = nil then Result := nil else Result := B.TopView;
end;

function TCITests.Line(N: Integer): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := EditorText(Buffer(FFile));
    if (N >= 1) and (N <= L.Count) then Result := L[N - 1] else Result := '';
  finally
    L.Free;
  end;
end;

function TCITests.EditorWindow: HWND;
begin
  Result := EditorControlOf(FFile);
end;


{ a key as the keyboard gives it, to the code editor (PostKey; Ch: unused, the character comes from
  TranslateMessage) }
procedure TCITests.Key(Code: Word; Shift: TShiftState; Ch: Char);
begin
  PostKey(EditorWindow, Code, Shift - [ssAlt]);
end;

{ characters typed (WM_CHAR, as TranslateMessage makes them), through the IDE's message loop }
procedure TCITests.Chars(const S: string);
var
  I: Integer;
  Wnd: HWND;
begin
  Wnd := EditorWindow;
  for I := 1 to Length(S) do
  begin
    PostMessage(Wnd, WM_CHAR, Ord(S[I]), 1);
    Pump;
  end;
end;

{ the index of Delphi's Pascal manager (-1: none) }
function TCITests.PascalIndex: Integer;
begin
  for Result := 0 to Svc.GetCodeInsightManagerCount - 1 do
    if Svc.GetCodeInsightManager(Result).GetIDString = 'Borland.CodeInsight.Pascal' then Exit;
  Result := -1;
end;
procedure TCITests.MoveTo(L, C: Integer);
var
  P: TOTAEditPos;
begin
  P.Line := L;
  P.Col := C;
  View.CursorPos := P;
end;

procedure TCITests.Invoke(Style: TCodeCompleteStyle);
var
  V: IOTAEditView;
  A: IOTAEditActions;
begin
  V := View;
  if Supports(V, IOTAEditActions, A) then A.CodeCompletion(Style);
end;

function TCITests.ViewerCount: Integer;
var
  V: IOTACodeInsightViewer;
begin
  Svc.GetViewer(V);
  if V = nil then Result := 0 else Result := V.ItemCount;
end;

{ a top-level window of the class (and the title; nil: any) the IDE's own process shows - another
  IDE on the desktop may have one too }
function OwnShownWindow(Cls, Title: PChar): HWND;
var
  Pid: DWORD;
begin
  Result := FindWindowEx(0, 0, Cls, Title);
  while Result <> 0 do
  begin
    Pid := 0;
    GetWindowThreadProcessId(Result, Pid);
    if (Pid = GetCurrentProcessId) and IsWindowVisible(Result) then Exit;
    Result := FindWindowEx(0, Result, Cls, Title);
  end;
end;

{ the code completion window of the IDE (Delphi's TCodeCompleteListView, KibitzWindow) shown - the
  viewer keeps its rows after the list closes in Delphi 7 (measured) }
function KibitzWindow: HWND;
begin
  Result := OwnShownWindow('TCodeCompleteListView', 'KibitzWindow');
end;

function KibitzShown: Boolean;
begin
  Result := KibitzWindow <> 0;
end;

function TCITests.ListOpen: Boolean;
begin
  Result := KibitzShown;
end;

function TCITests.Drawn: Boolean;
begin
  Result := DrawLineCalls > 0;
end;

function TCITests.Logged: Boolean;
begin
  Result := CICallIndex(FWaitText, FMark) >= 0;
end;

{ the calls in this order in the log from FMark on (others between them) }
function TCITests.InOrder(const Calls: array of string): Boolean;
var
  I, P: Integer;
begin
  Result := True;
  P := FMark;
  for I := Low(Calls) to High(Calls) do
  begin
    P := CICallIndex(Calls[I], P);
    if P < 0 then
    begin
      Check(False, 'in Delphi''s order: ' + Calls[I], 'not found after the calls before it');
      Result := False;
      Exit;
    end;
    Inc(P);
  end;
end;

function TCITests.Current: IOTACodeInsightManager;
begin
  Svc.GetCurrentCodeInsightManager(Result);
end;

{ C1: D7 Studio's own code insight is Delphi's Pascal manager, index 0 }
procedure TCITests.Managers;
var
  M: IOTACodeInsightManager;
  I: Integer;
begin
  FCount := Svc.GetCodeInsightManagerCount;
  if not Check(FCount >= 1, 'GetCodeInsightManagerCount: one manager at least', IntToStr(FCount)) then Exit;
  for I := 0 to FCount - 1 do
    Note('manager ' + IntToStr(I) + ': ' + Svc.GetCodeInsightManager(I).GetIDString + ' | ' + Svc.GetCodeInsightManager(I).GetName);
  if not Check(PascalIndex >= 0, 'Delphi''s Pascal manager (Borland.CodeInsight.Pascal)') then Exit;
  M := Svc.GetCodeInsightManager(PascalIndex);
  Expect('... GetName', M.GetName, 'Pascal');
  Check(M.GetEnabled, '... enabled');
  Check(M.HandlesFile(Test.Values['Unit']), '... it handles the test''s unit (.pas)');
  Check(not M.HandlesFile(Dir + 'x.otademo'), '... not a .otademo file');
end;

{ C2..C4: added at the end; the same IDString again gives that index, nothing added }
procedure TCITests.Add;
var
  Second: TDemoCIManager;
  Raised: Boolean;
begin
  FDemo := TDemoCIManager.Create;
  FDemoIntf := FDemo;
  FIndex := Svc.AddCodeInsightManager(FDemoIntf);
  ExpectInt('AddCodeInsightManager: the next index', FIndex, FCount);
  Second := TDemoCIManager.Create;
  ExpectInt('a manager of the same IDString: that index', Svc.AddCodeInsightManager(Second), FIndex);
  ExpectInt('... and nothing added', Svc.GetCodeInsightManagerCount, FCount + 1);
  Check(SameModule(Svc.GetCodeInsightManager(FIndex), FDemoIntf), 'GetCodeInsightManager gives the expert''s object');
  ExpectInt('AddCodeInsightManager(nil): -1', Svc.AddCodeInsightManager(nil), -1);
  Raised := False;
  try
    Svc.GetCodeInsightManager(Svc.GetCodeInsightManagerCount);
  except
    on E: EListError do Raised := True;
  end;
  Check(Raised, 'GetCodeInsightManager past the end raises EListError');
end;

procedure TCITests.OpenFile;
var
  S: TStringList;
begin
  FFile := Dir + 'CITest' + DemoCIExt;
  S := TStringList.Create;
  try
    S.Add(FirstLine);
    S.Add('Mix: two colours in one');
    S.Add('Re');
    S.Add('Mix(Red, Blue)');
    S.Add('Blu');
    S.Add('Gre');
    S.Add('B');
    S.Add('Navy');
    S.SaveToFile(FFile);
  finally
    S.Free;
  end;
  Check((BorlandIDEServices as IOTAActionServices).OpenFile(FFile), 'OpenFile of a .otademo file');
  Check(View <> nil, 'its edit view');
  Check(EditorWindow <> 0, 'its code editor');
end;

{ C5 }
procedure TCITests.QueryContext;
var
  V, V2: IOTAEditView;
  Viewer: IOTACodeInsightViewer;
  Before: string;
begin
  V := View;
  Before := EditorText(Buffer(FFile));
  Svc.SetQueryContext(V, FDemoIntf);
  Svc.GetEditView(V2);
  Check(SameModule(V2, V), 'a query context: GetEditView is its view');
  Check(SameModule(Current, FDemoIntf), '... GetCurrentCodeInsightManager its manager');
  Svc.GetViewer(Viewer);
  Check(Viewer = nil, '... no viewer');
  Svc.InsertText('x', False);
  Expect('... InsertText does nothing', EditorText(Buffer(FFile)), Before);
  Svc.SetQueryContext(nil, nil);
  Check(Current = nil, 'SetQueryContext(nil, nil): no current manager');
  Svc.GetViewer(Viewer);
  Check(Viewer = nil, '... no viewer before a list has been shown (Delphi 7''s)');
end;

{ C6: Ctrl+Space as an expert asks for it (csCodeList or csManual), the caret after "Re" }
procedure TCITests.List;
begin
  MoveTo(3, 3);
  FMark := CICalls.Count;
  DrawLineCalls := 0;
  Invoke(csCodeList or csManual);
  WaitFor(ListOpen, 'the list of the demo''s manager shows', 10);
end;

procedure TCITests.ListChecks;
var
  V: IOTACodeInsightViewer;
begin
  InOrder(['HandlesFile(CITest.otademo) -> True', 'GetEnabled -> True', 'AllowCodeInsight(#0)', 'GetCodeInsightType(#0, ' +
    IntToStr(SyntaxOff) + ')', 'EditorTokenValidChars(False)', 'InvokeCodeCompletion(itManual, Re)', 'GetSymbolList',
    'GetLongestItem', 'GetMultiSelect', 'SymbolList.SetFilter(Re)',
    'SymbolList.FindSymIndex(Re)']);
  Svc.GetViewer(V);
  if not Check(V <> nil, 'the viewer') then Exit;
  ExpectInt('the viewer''s rows: Red', V.ItemCount, 1);
  { a row is chosen only when the expert's FindSymIndex finds the typed text (Delphi 7's, measured) }
  ExpectInt('GetSelectedIndex: no row - FindSymIndex finds no "Re"', V.SelectedIndex, -1);
  Check(not V.Selected[0], 'GetSelected(0): not chosen');
  ExpectInt('the list window has no row chosen either (LB_GETCURSEL)', SendMessage(KibitzWindow, LB_GETCURSEL, 0, 0), -1);
  Check(not V.IsValidSelection, 'GetIsValidSelection: "Re" is no symbol (Delphi: typed text needs an exact match)');
  Check(SameModule(Current, FDemoIntf), 'GetCurrentCodeInsightManager: the demo''s while its list shows');
  WaitFor(Drawn, 'the rows are drawn by the manager (INTACustomDrawCodeInsightViewer.DrawLine)', 10);
end;

{ typing filters: "d" - "Red" now an exact match }
procedure TCITests.TypeFilter;
var
  V: IOTACodeInsightViewer;
begin
  FMark := CICalls.Count;
  Chars('d');
  InOrder(['EditorTokenValidChars(False)', 'SymbolList.SetFilter(Red)', 'SymbolList.FindSymIndex(Red) -> True']);
  Svc.GetViewer(V);
  if not Check(V <> nil, 'the viewer') then Exit;
  ExpectInt('the typed text found: its row chosen', V.SelectedIndex, 0);
  { a list whose rows the expert draws has no text of them: no string, no valid selection (Delphi 7's,
    measured) }
  Expect('GetSelectedString of a list the expert draws: none', V.SelectedString, '');
  Check(not V.IsValidSelection, 'GetIsValidSelection: False');
  Expect('Line 3 as typed', Line(3), 'Red');
end;

{ Enter: OnEditorKey(#13) accepts - the key eaten, Done(True) inserts the symbol (CloseKey #0) }
procedure TCITests.Accept;
begin
  FMark := CICalls.Count;
  Key(VK_RETURN, [], #13);
  InOrder(['OnEditorKey(#13) -> Close False, Accept True', 'Done(True)', 'SymbolList.Clear']);
  Expect('Enter accepted: no new line, the symbol in place of the word', Line(3), 'Red');
  Check(not ListOpen, 'the list is closed');
  ExpectInt('the viewer keeps its rows (Delphi 7''s)', ViewerCount, 1);
  Check(Current = nil, 'no current manager after Done');
end;

procedure TCITests.CloseKeyStart;
begin
  MoveTo(5, 4);
  FMark := CICalls.Count;
  Invoke(csCodeList or csManual);
  WaitFor(ListOpen, 'the list for "Blu"', 10);
end;

{ ';' accepts: it is the close key - with no row chosen Done puts nothing, the key is taken }
procedure TCITests.CloseKey;
var
  V: IOTACodeInsightViewer;
begin
  Svc.GetViewer(V);
  if V <> nil then ExpectInt('no row chosen: FindSymIndex finds no "Blu"', V.SelectedIndex, -1);
  FMark := CICalls.Count;
  Chars(';');
  InOrder(['OnEditorKey(;) -> Close False, Accept True', 'Done(True)']);
  Expect('no row: nothing put, the close key taken', Line(5), 'Blu');
end;

procedure TCITests.EscapeStart;
begin
  MoveTo(6, 4);
  FMark := CICalls.Count;
  Invoke(csCodeList or csManual);
  WaitFor(ListOpen, 'the list for "Gre"', 10);
end;

{ Esc: OnEditorKey(#27) closes - Done(False), nothing inserted }
procedure TCITests.Escape;
begin
  FMark := CICalls.Count;
  Key(VK_ESCAPE, [], #27);
  InOrder(['OnEditorKey(#27) -> Close True, Accept False', 'Done(False)']);
  Expect('Esc: the text as it was', Line(6), 'Gre');
  Check(not ListOpen, 'the list is closed');
end;

procedure TCITests.CancelStart;
begin
  MoveTo(6, 4);
  Invoke(csCodeList or csManual);
  WaitFor(ListOpen, 'the list for "Gre" again', 10);
end;

{ C7: CancelCodeInsightProcessing - the symbol list cleared, no Done }
procedure TCITests.Cancel;
begin
  FMark := CICalls.Count;
  Svc.CancelCodeInsightProcessing;
  Check(CICallIndex('SymbolList.Clear', FMark) >= 0, 'CancelCodeInsightProcessing: the symbol list cleared');
  Check(CICallIndex('Done(', FMark) < 0, '... no Done (Delphi''s)');
  Check(Current = nil, '... no current manager');
  Check(not ListOpen, '... the list is closed');
end;

{ C8: parameters inside "Mix(" (csParamList or csManual) }
procedure TCITests.Params;
begin
  MoveTo(4, 5);
  FMark := CICalls.Count;
  Invoke(csParamList or csManual);
  FWaitText := 'ParameterCodeInsightAnchorPos';
  WaitFor(Logged, 'the parameter hint of the demo''s manager', 10);
end;

procedure TCITests.ParamIndex;
begin
  { Delphi 7 asked for neither in its runs on a desktop of their own: D7 Studio's order }
  if not D7StudioOnly('the parameter hint''s anchor and index (not measured in Delphi 7)') then Exit;
  InOrder(['HandlesFile', 'AllowCodeInsight(#1)', 'GetCodeInsightType(#1', 'InvokeParameterCodeInsight(itManual) -> True',
    'GetParameterList', 'ParamList.GetParamDelimiter', 'ParamList.GetProcedureCount', 'ParamList.GetProcedureParamsText(0)',
    'ParamList.GetProcedureParamsText(1)', 'ParameterCodeInsightAnchorPos(4:5)']);
  Check(SameModule(Current, FDemoIntf), 'GetCurrentCodeInsightManager: the demo''s while its hint shows');
  FMark := CICalls.Count;
  MoveTo(4, 9);
  FWaitText := 'ParameterCodeInsightParamIndex(4:9) -> 1';
  WaitFor(Logged, 'the caret after the first comma: ParameterCodeInsightParamIndex gives 1', 10);
end;

procedure TCITests.ParamsClose;
begin
  Key(VK_ESCAPE, [], #27);
  if not D7StudioOnly('Esc and the parameter hint (not measured in Delphi 7)') then
  begin
    Svc.CancelCodeInsightProcessing;
    Exit;
  end;
  Check(Current = nil, 'Esc closes the parameter hint');
end;

{ C9: a '.' (csCodeList without csManual): itTimer - the Code Insight delay, then PreValidate }
procedure TCITests.Delay;
begin
  MoveTo(6, 4);
  FMark := CICalls.Count;
  Invoke(csCodeList);
  FWaitText := 'InvokeCodeCompletion(itAuto';
  WaitFor(Logged, 'after the Code Insight delay: InvokeCodeCompletion(itAuto)', 10);
end;

procedure TCITests.DelayChecks;
begin
  InOrder(['AllowCodeInsight(.)', 'GetCodeInsightType(.', 'EditorTokenValidChars(True)',
    'PreValidateCodeInsight(Gre) -> True', 'InvokeCodeCompletion(itAuto, Gre)']);
  Svc.CancelCodeInsightProcessing;
end;

{ a Ctrl+click on a word: the caret there, GotoDefinition, its line shown }
procedure ClickAt(Wnd: HWND; Line, Col: Integer);
var
  Pos, X, Y: Integer;
  Old, KS: TKeyboardState;
begin
  Pos := SendMessage(Wnd, SCI_POSITIONFROMLINE, Line - 1, 0) + Col - 1;
  X := SendMessage(Wnd, SCI_POINTXFROMPOSITION, 0, Pos) + 2;
  Y := SendMessage(Wnd, SCI_POINTYFROMPOSITION, 0, Pos) + SendMessage(Wnd, SCI_TEXTHEIGHT, 0, 0) div 2;
  GetKeyboardState(Old);
  KS := Old;
  KS[VK_CONTROL] := $80;
  KS[VK_MENU] := 0;
  KS[VK_SHIFT] := 0;
  SetKeyboardState(KS);
  try
    SendMessage(Wnd, WM_LBUTTONDOWN, MK_LBUTTON or MK_CONTROL, MakeLParam(X, Y));
    SendMessage(Wnd, WM_LBUTTONUP, MK_CONTROL, MakeLParam(X, Y));
  finally
    SetKeyboardState(Old);
  end;
end;

procedure TCITests.Browse;
begin
  if not D7StudioOnly('the mouse and the tips of D7 Studio''s editor (Scintilla''s positions)') then Exit;
  FMark := CICalls.Count;
  ClickAt(EditorWindow, 4, 2);
  InOrder(['AllowCodeInsight(#2)', 'GetCodeInsightType(#2', 'GotoDefinition(-1) Mix -> True 2']);
  ExpectInt('Ctrl+click on "Mix": the line of "Mix:" shown', View.CursorPos.Line, 2);
end;

function StatusText: string;
var
  V: IOTAEditView;
  W: INTAEditWindow;
  B: TStatusBar;
  I: Integer;
begin
  Result := '';
  V := (BorlandIDEServices as IOTAEditorServices).TopView;
  if V = nil then Exit;
  W := V.GetEditWindow;
  if W = nil then Exit;
  B := W.StatusBar;
  if B = nil then Exit;
  for I := 0 to B.Panels.Count - 1 do Result := Result + B.Panels[I].Text + '|';
end;

{ E14: a word without a definition - "Unable to locate file" in the status bar }
procedure TCITests.BrowseFail;
begin
  if not D7StudioOnly('the mouse and the tips of D7 Studio''s editor (Scintilla''s positions)') then Exit;
  FMark := CICalls.Count;
  ClickAt(EditorWindow, 4, 11);
  Check(CICallIndex('GotoDefinition(-1) Blue -> False', FMark) >= 0, 'Ctrl+click on "Blue": GotoDefinition fails');
  Check(Pos('Unable to locate file', StatusText) > 0, '... "Unable to locate file" in the status bar', StatusText);
end;

{ D7 Studio's code tip of the IDE's process (a window of the class TSdCodeTip, owned by the
  program's window): 0 when it is not shown }
function ShownCodeTip: HWND;
begin
  Result := OwnShownWindow('TSdCodeTip', nil);
end;

{ #3: the editor's dwell on a word - GetHintText of its line and column, in the code tip; the
  dwell's end takes it away }
procedure TCITests.Hint;
var
  Wnd: HWND;
  N: array[0..63] of Integer;
begin
  if not D7StudioOnly('the mouse and the tips of D7 Studio''s editor (Scintilla''s positions)') then Exit;
  Wnd := EditorWindow;
  if not Check(Wnd <> 0, 'the editor') then Exit;
  FMark := CICalls.Count;
  FillChar(N, SizeOf(N), 0);
  N[0] := Wnd;
  N[2] := SCN_DWELLSTART;
  N[3] := SendMessage(Wnd, SCI_POSITIONFROMLINE, 0, 0) + 1;     // "Red", its second character
  SendMessage(Wnd, CN_NOTIFY, 0, Integer(@N));
  Check(CICallIndex('GetHintText(1, 2) -> OTA demo hint: Red at 1:2', FMark) >= 0, 'the hint of "Red": GetHintText(1, 2)');
  Check(ShownCodeTip <> 0, '... shown in the code tip');
  N[2] := SCN_DWELLEND;
  SendMessage(Wnd, CN_NOTIFY, 0, Integer(@N));
  Check(ShownCodeTip = 0, '... gone when the dwell ends');
end;

{ a multi-select list (GetMultiSelect True): Delphi 7's list box of extended selection - Space and the
  arrows choose one row, Ctrl+Space toggles one }
procedure TCITests.MultiStart;
begin
  DemoMultiSelect := True;
  MoveTo(7, 2);
  FMark := CICalls.Count;
  Invoke(csCodeList or csManual);
  WaitFor(ListOpen, 'the list for "B" (multi-select)', 10);
end;

procedure TCITests.Multi;
begin
  ExpectInt('"B": Black, Blue', ViewerCount, 2);
  FMark := CICalls.Count;
  Key(VK_SPACE, [], ' ');
  Key(VK_DOWN, [], #0);
  Key(VK_SPACE, [], ' ');
  Key(VK_RETURN, [], #13);
  { a list box of extended selection (Delphi 7's, measured): Space chose the first row, Down the
    second alone, Space kept it }
  Check(CICallIndex('Done(True) selected 1', FMark) >= 0, 'Space, Down, Space: Done sees the second row alone chosen');
  Check(CICallIndex('OnEditorKey( )', FMark) < 0, 'Space chose rows, it was no key of the list');
  DemoMultiSelect := False;
end;

{ C10: D7 Studio's own list in a Pascal unit - none while the Pascal manager is off }
procedure TCITests.PascalStart;
var
  S: TStringList;
  P: TOTAEditPos;
begin
  FUnit := Dir + 'CIUnit.pas';
  S := TStringList.Create;
  try
    S.Add('unit CIUnit;');
    S.Add('');
    S.Add('interface');
    S.Add('');
    S.Add('implementation');
    S.Add('');
    S.Add('procedure WriteDemo;');
    S.Add('begin');
    S.Add('end;');
    S.Add('');
    S.Add('procedure Test;');
    S.Add('begin');
    S.Add('  WriteD');
    S.Add('  WriteDemo;');
    S.Add('end;');
    S.Add('');
    S.Add('end.');
    S.SaveToFile(FUnit);
  finally
    S.Free;
  end;
  if not Check((BorlandIDEServices as IOTAActionServices).OpenFile(FUnit), 'OpenFile of a Pascal unit') then Exit;
  P.Line := 13;
  P.Col := 9;
  Buffer(FUnit).TopView.CursorPos := P;
  (Buffer(FUnit).TopView as IOTAEditActions).CodeCompletion(csCodeList or csManual);
  WaitFor(ListOpen, 'D7 Studio''s own list (the Pascal manager)', 10);
end;

procedure TCITests.PascalOff;
var
  V: IOTACodeInsightViewer;
begin
  Svc.GetViewer(V);
  { its first row chosen; the viewer's string only for the typed text's row (Delphi 7's, measured) }
  if V <> nil then ExpectInt('its first row chosen', V.SelectedIndex, 0);
  if V <> nil then Expect('... no string: "WriteD" is a part of the name', V.SelectedString, '');
  { the window an expert looks for to know that the IDE's list is open (CnWizards' input helper:
    FindWindow, IsWindowVisible) }
  Check(KibitzShown, 'the open list: a window TCodeCompleteListView named KibitzWindow, visible, of the IDE''s process');
  Check(SameModule(Current, Svc.GetCodeInsightManager(PascalIndex)), 'GetCurrentCodeInsightManager: the Pascal manager');
  Svc.CancelCodeInsightProcessing;
  Check(not ListOpen, 'CancelCodeInsightProcessing closes D7 Studio''s own list too: the window experts find is hidden');
  Svc.GetCodeInsightManager(PascalIndex).SetEnabled(False);
  (Buffer(FUnit).TopView as IOTAEditActions).CodeCompletion(csCodeList or csManual);
end;
procedure TCITests.PascalOn;
begin
  Check(not ListOpen, 'the Pascal manager off: no list');
  Svc.GetCodeInsightManager(PascalIndex).SetEnabled(True);
  (Buffer(FUnit).TopView as IOTAEditActions).CodeCompletion(csCodeList or csManual);
  WaitFor(ListOpen, 'on again: the list', 10);
end;

{ E9: the Pascal manager's data for an expert - its list, a symbol's declaration, a hint -
  through a query context with the unit's view }
procedure TCITests.PascalData;
var
  M: IOTACodeInsightManager;
  SL: IOTACodeInsightSymbolList;
  S, F, H: string;
  Idx, L: Integer;
begin
  Svc.CancelCodeInsightProcessing;
  M := Svc.GetCodeInsightManager(PascalIndex);
  Svc.SetQueryContext(Buffer(FUnit).TopView, M);
  try
    S := '';
    if not Check(M.InvokeCodeCompletion(itManual, S), 'the Pascal manager''s InvokeCodeCompletion at the view''s cursor') then
      Exit;
    Expect('... the text before the cursor', S, 'WriteD');
    M.GetSymbolList(SL);
    if not Check(SL <> nil, '... its symbol list') then Exit;
    SL.SetFilter(S);
    ExpectInt('... filtered by that text', SL.Count, 1);
    Expect('... the symbol', SL.SymbolText[0], 'WriteDemo');
    Expect('... its class text', SL.SymbolClassText[0], 'procedure');
    Check(SL.SymbolFlags[0] = vsfProcedure, '... its flags: vsfProcedure');
    Idx := -1;
    Check(SL.FindSymIndex('writedemo', Idx) and (Idx = 0), 'FindSymIndex in any case');
    Check(M.GotoDefinition(F, L, 0) and SameText(F, FUnit) and (L = 7), 'GotoDefinition of the row: the unit''s line 7',
      Format('%s %d', [F, L]));
    { Delphi 7's Pascal manager gave no hint and kept its rows after Clear in its runs }
    H := M.GetHintText(14, 5);
    if D7StudioOnly('GetHintText of the Pascal manager (Delphi 7''s gave none in its runs)') then
      Check(Pos('WriteDemo', H) > 0, 'GetHintText of a call of it', H);
    SL.Clear;
    if D7StudioOnly('Clear of the Pascal manager''s list (Delphi 7''s kept its rows in its runs)') then
      ExpectInt('Clear', SL.Count, 0);
  finally
    Svc.SetQueryContext(nil, nil);
  end;
end;

procedure TCITests.PascalBack;
var
  M: IOTAModule;
begin
  Svc.CancelCodeInsightProcessing;
  M := (BorlandIDEServices as IOTAModuleServices).FindModule(FUnit);
  if M <> nil then Check(M.CloseModule(True), 'the unit closed');
  (BorlandIDEServices as IOTAActionServices).OpenFile(FFile);
end;

{ C11: a removed manager goes from the list - the later ones one index down (Delphi 7's,
  measured); the list of one shown stays while another goes, closes when it goes }
procedure TCITests.RemoveStart;
var
  B: TDemoCIManager;
begin
  B := TDemoCIManager.Create;
  B.ID := DemoCIID + '.B';
  FDemoB := B;
  FIndexB := Svc.AddCodeInsightManager(FDemoB);
  ExpectInt('a second manager after the demo''s', FIndexB, FIndex + 1);
  MoveTo(8, 5);
  Invoke(csCodeList or csManual);
  WaitFor(ListOpen, 'a list of the demo''s manager', 10);
end;

procedure TCITests.Remove;
begin
  FMark := CICalls.Count;
  { the second one is newer and handles .otademo too: the list is its (Delphi's choice) }
  Check(SameModule(Current, FDemoB), 'the newest manager for the file has the list');
  Svc.RemoveCodeInsightManager(FIndex);
  FDemoIntf := nil;
  ExpectInt('a removed manager goes: the count one less', Svc.GetCodeInsightManagerCount, FIndexB);
  Check(SameModule(Svc.GetCodeInsightManager(FIndex), FDemoB), 'the later manager one index down');
  Check(ListOpen, 'the later manager''s list stays');
  Svc.RemoveCodeInsightManager(FIndex);
  FDemoB := nil;
  { D7 Studio closes the list of a removed manager, on purpose; Delphi 7's stays open }
  if D7StudioOnly('the list of a removed manager closes (Delphi 7''s stays open)') then
    Check(not ListOpen, 'the manager of the list removed: the list closed')
  else
    Svc.CancelCodeInsightProcessing;
  Check(CICallIndex('Done(', FMark) < 0, '... without Done');
  ExpectInt('the last ones removed: the count goes back', Svc.GetCodeInsightManagerCount, FCount);
  Svc.RemoveCodeInsightManager(FCount);
  Svc.RemoveCodeInsightManager(-1);
  Check(True, 'RemoveCodeInsightManager past the end, of -1: nothing (no exception)');
end;
procedure TCITests.Finish;
var
  M: IOTAModule;
begin
  M := (BorlandIDEServices as IOTAModuleServices).FindModule(FFile);
  if M <> nil then Check(M.CloseModule(True), 'the .otademo file closed');
end;

initialization
  RegisterTestArea(TCITests, 87);
end.
