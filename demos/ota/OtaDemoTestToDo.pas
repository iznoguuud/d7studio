{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoTestToDo;

{ The self-test's To-Do List area (OtaDemoTest): IOTAToDoServices with the demo's managers
  (OtaDemoToDo), whose items log every call they get.

  * AddManager collects nothing at once, nor does UpdateList before the To-Do List was first
    shown (Delphi 7's list collects once its window was made); then UpdateList asks each
    manager's GetItemCount once and GetItem for every index; GetItemCount / GetItem are the items
    the view shows - the IDE's own comments included (a TODO comment of an open unit as
    INTAToDoItem, in Delphi 7 a moment later: its parser runs in a thread of its own) - and an
    expert's item comes back as the expert's own object.
  * The view (D7 Studio's To-Do List, the main form's TodoList, its local menu's actions): the
    experts' rows with their module, their image (DrawImage), Open / Edit / Delete enabled as the
    item says (CanShow, CanEdit, CanDelete, IsValid), the check box (SetChecked), Edit, a double
    click, Enter (Show), Delete - each followed by the list collected again; a pause in typing
    while the view shows reads the files again.
  * The managers and notifiers are lists as Delphi 7's: a manager removed takes the later ones
    one index down, an index out of range raises EListError (RemoveManager, RemoveNotifier,
    GetItem).
  * ProjectChanged is never called when another project of the group becomes the active one and
    back (Delphi 7 calls it on no expert's manager); the items are collected again.
  * The notifier is never sent Modified (Delphi 7's list sends it nowhere). }

interface

implementation

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, Menus, ActnList, ComCtrls, ToolsAPI,
  OtaDemoTest, OtaDemoToDo;

type
  TToDoTests = class(TOtaTestArea)
  private
    FManager: TDemoToDoManager;
    FManagerIntf: IOTAToDoManager;
    FIndex: Integer;
    FNotifierIntf: IOTANotifier;
    FNotifier: Integer;
    FOwnFile, FOtherFile: string;
    FMark: Integer;
    FBase: Integer;
    FDemoCount: Integer;             // the demo manager's items (the view's Delete takes one)
    FWaitCount: Integer;
    FWaitText: string;
    function Svc: IOTAToDoServices;
    function MainComponent(const Name: string): TComponent;
    function View: TListView;
    function Row(const Caption: string): TListItem;
    function Choose(const Caption: string): Boolean;
    function Act(const Name: string): TAction;
    procedure MenuStates;
    function DemoItems: Integer;
    function OwnBuffer: IOTAEditBuffer;
    function Logged: Boolean;
    function RowGone: Boolean;
    function RowThere: Boolean;
    function ItemsGrew: Boolean;
    function ToDoWindowMade: Boolean;
    function OwnFound: INTAToDoItem;
    function OwnListed: Boolean;
    procedure Register;
    function OpenToDoView: Boolean;
    procedure Collect;
    procedure OwnItem;
    procedure OwnData;
    procedure Rows;
    procedure States;
    procedure CheckBox;
    procedure Checked;
    procedure EditItem;
    procedure Edited;
    procedure DoubleClick;
    procedure ShowItem;
    procedure DeleteItem;
    procedure Deleted;
    procedure TypingPause;
    procedure TypedItem;
    procedure Indexes;
    procedure OtherProject;
    procedure BackAgain;
    procedure ProjectBack;
    procedure Finish;
  public
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

const
  ManagerName = 'OtaDemo.ToDo';

function TToDoTests.Name: string;
begin
  Result := 'ToDo';
end;

procedure TToDoTests.AddSteps;
begin
  Step('Register', Register);
  Step('Collect', Collect);
  Step('OwnItem', OwnItem);
  Step('OwnData', OwnData);
  Step('Rows', Rows);
  Step('States', States);
  Step('CheckBox', CheckBox);
  Step('Checked', Checked);
  Step('Edit', EditItem);
  Step('Edited', Edited);
  Step('DoubleClick', DoubleClick);
  Step('Show', ShowItem);
  Step('Delete', DeleteItem);
  Step('Deleted', Deleted);
  Step('TypingPause', TypingPause);
  Step('TypedItem', TypedItem);
  Step('Indexes', Indexes);
  Step('OtherProject', OtherProject);
  Step('BackAgain', BackAgain);
  Step('ProjectBack', ProjectBack);
  Step('Finish', Finish);
end;

{ an index that is stale after a failed step raises EListError (Delphi 7's lists): nothing more to do }
procedure TToDoTests.Cleanup;
begin
  if FManagerIntf <> nil then
  begin
    try
      Svc.RemoveManager(FIndex);
    except
      on EListError do ;
    end;
    FManagerIntf := nil;
  end;
  if FNotifierIntf <> nil then
  begin
    try
      Svc.RemoveNotifier(FNotifier);
    except
      on EListError do ;
    end;
    FNotifierIntf := nil;
  end;
  DemoShowFile := '';
end;

function TToDoTests.Svc: IOTAToDoServices;
begin
  Result := BorlandIDEServices as IOTAToDoServices;
end;

{ D7 Studio's own parts: its main form's components, else those of the view forms it owns (the
  To-Do List's list, menu and actions are its form's, TodoListView) }
function TToDoTests.MainComponent(const Name: string): TComponent;
var
  I: Integer;
  M: TComponent;
begin
  M := Application.MainForm;
  Result := M.FindComponent(Name);
  for I := 0 to M.ComponentCount - 1 do
    if (Result = nil) and (M.Components[I] is TCustomForm) then
      Result := M.Components[I].FindComponent(Name);
end;

function TToDoTests.View: TListView;
var
  C: TComponent;
begin
  C := MainComponent('TodoList');
  if C is TListView then Result := TListView(C) else Result := nil;
end;

function TToDoTests.Row(const Caption: string): TListItem;
var
  I: Integer;
begin
  Result := nil;
  if View = nil then Exit;
  for I := 0 to View.Items.Count - 1 do
    if View.Items[I].Caption = Caption then
    begin
      Result := View.Items[I];
      Exit;
    end;
end;

function TToDoTests.Choose(const Caption: string): Boolean;
var
  It: TListItem;
begin
  It := Row(Caption);
  Result := Check(It <> nil, 'the row "' + Caption + '" is there');
  if not Result then Exit;
  View.Selected := It;
  View.ItemFocused := It;
end;

function TToDoTests.Act(const Name: string): TAction;
var
  C: TComponent;
begin
  C := MainComponent(Name);
  if C is TAction then Result := TAction(C) else Result := nil;
end;

{ the list's local menu opens: the states of its actions are set, as Delphi 7's are }
procedure TToDoTests.MenuStates;
var
  C: TComponent;
begin
  C := MainComponent('TodoPopup');
  if (C is TPopupMenu) and Assigned(TPopupMenu(C).OnPopup) then TPopupMenu(C).OnPopup(C);
end;

{ the items of GetItem that are the demo's (their kind) }
function TToDoTests.DemoItems: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Svc.GetItemCount - 1 do
    if Svc.GetItem(I).GetKind = DemoToDoKind then Inc(Result);
end;

function TToDoTests.OwnBuffer: IOTAEditBuffer;
var
  M: IOTAModule;
begin
  Result := nil;
  M := (BorlandIDEServices as IOTAModuleServices).FindModule(FOwnFile);
  if M <> nil then Supports(SourceEditorOf(M), IOTAEditBuffer, Result);
end;

function TToDoTests.Logged: Boolean;
begin
  Result := ToDoCallCount(FWaitText, FMark) >= FWaitCount;
end;

function TToDoTests.RowGone: Boolean;
begin
  Result := Row(FWaitText) = nil;
end;

function TToDoTests.RowThere: Boolean;
begin
  Result := Row(FWaitText) <> nil;
end;

function TToDoTests.ItemsGrew: Boolean;
begin
  Result := Svc.GetItemCount > FBase;
end;

{ Delphi 7's To-Do List window was made before (View | To-Do List makes it once); D7 Studio's view
  was not shown before the test (D7 Studio's profile of the test keeps it in a hidden tab) }
function TToDoTests.ToDoWindowMade: Boolean;
var
  I: Integer;
begin
  Result := False;
  if IdeIsDelphi7 then
    for I := 0 to Screen.FormCount - 1 do
      if Screen.Forms[I].ClassName = 'TToDoListWindow' then Result := True;
end;

{ the open unit's TODO comment, as the list has it: kind $Source, the file as its module }
function TToDoTests.OwnFound: INTAToDoItem;
var
  I: Integer;
  X: INTAToDoItem;
begin
  Result := nil;
  for I := 0 to Svc.GetItemCount - 1 do
  begin
    X := Svc.GetItem(I);
    if (X.GetKind = '$Source') and SameText(X.GetModuleName, FOwnFile) then Result := X;
  end;
end;

function TToDoTests.OwnListed: Boolean;
begin
  Result := OwnFound <> nil;
end;

{ View | To-Do List; False: no such action }
function TToDoTests.OpenToDoView: Boolean;
var
  A: TContainedAction;
begin
  A := IdeAction('ViewToDoListCommand');
  Result := A <> nil;
  if Result then A.Execute;
end;

{ T1, T2: a manager and a notifier registered; Delphi collects nothing then, nor at an UpdateList
  before its list's window was made; then the view is shown }
procedure TToDoTests.Register;
begin
  FMark := ToDoCalls.Count;
  FDemoCount := 3;
  FManager := TDemoToDoManager.Create(ManagerName, 'Demo');
  FManagerIntf := FManager;
  FIndex := Svc.AddManager(FManagerIntf);
  Check(FIndex >= 0, 'AddManager gives an index', IntToStr(FIndex));
  FNotifierIntf := TDemoToDoNotifier.Create;
  FNotifier := Svc.AddNotifier(FNotifierIntf);
  Check(FNotifier >= 0, 'AddNotifier gives an index', IntToStr(FNotifier));
  ExpectInt('AddManager asked the manager nothing (Delphi: its items come with the next collection)',
    ToDoCallCount(ManagerName + '.', FMark), 0);
  if ToDoWindowMade then
    Note('the To-Do List''s window was made before the test: its items are collected already')
  else
  begin
    Svc.UpdateList;
    ExpectInt('UpdateList before the To-Do List was first shown asked no manager (Delphi 7''s list ' +
      'collects once its window was made)', ToDoCallCount(ManagerName + '.', FMark), 0);
    ExpectInt('... GetItemCount: none', Svc.GetItemCount, 0);
  end;
  OpenToDoView;
end;

{ T3, T4: the view shown has the demo's items; UpdateList - GetItemCount once, GetItem for each
  index; the experts' items are theirs }
procedure TToDoTests.Collect;
var
  I, K, Same: Integer;
  X: INTAToDoItem;
begin
  ExpectInt('the view shown: the demo''s three items are listed', DemoItems, 3);
  FBase := Svc.GetItemCount;
  FMark := ToDoCalls.Count;
  Svc.UpdateList;
  ExpectInt('UpdateList asked GetItemCount once', ToDoCallCount(ManagerName + '.GetItemCount', FMark), 1);
  ExpectInt('... and GetItem for each of the three', ToDoCallCount(ManagerName + '.GetItem(', FMark), 3);
  ExpectInt('GetItemCount: the same items, collected again', Svc.GetItemCount, FBase);
  Same := 0;
  for I := 0 to Svc.GetItemCount - 1 do
  begin
    X := Svc.GetItem(I);
    for K := 0 to FManager.Count - 1 do
      if SameModule(X, FManager.Item(K) as INTAToDoItem) then Inc(Same);
  end;
  ExpectInt('GetItem gives the expert''s own item objects', Same, 3);
  ExpectInt('Modified is never sent to the notifiers (Delphi 7''s list sends it nowhere)',
    ToDoCallCount('Notifier.Modified'), 0);
end;

{ T5: a TODO comment of an open unit, listed once the view shows (View | To-Do List) - in Delphi 7
  by its parser's thread, a moment later }
procedure TToDoTests.OwnItem;
var
  S: TStringList;
begin
  FOwnFile := Dir + 'TodoTest.pas';
  S := TStringList.Create;
  try
    S.Add('unit TodoTest;');
    S.Add('');
    S.Add('interface');
    S.Add('');
    S.Add('implementation');
    S.Add('');
    S.Add('{ TODO 2 -oTester -cTests : check the list }');
    S.Add('');
    S.Add('end.');
    S.SaveToFile(FOwnFile);
  finally
    S.Free;
  end;
  if not Check((BorlandIDEServices as IOTAActionServices).OpenFile(FOwnFile), 'OpenFile of a unit with a TODO') then Exit;
  DemoShowFile := FOwnFile;
  if not Check(OpenToDoView, 'the action ViewToDoListCommand (View | To-Do List)') then Exit;
  if D7StudioOnly('D7 Studio''s To-Do List view') then Check(View <> nil, 'D7 Studio''s To-Do List (TodoList) is there');
  WaitFor(OwnListed, 'the open unit''s TODO is an item of kind $Source with the file as its module', 15);
end;

procedure TToDoTests.OwnData;
var
  X: INTAToDoItem;
begin
  X := OwnFound;
  if X <> nil then
  begin
    Expect('the comment''s GetText', Trim(X.GetText), 'check the list');
    ExpectInt('its GetPriority', X.GetPriority, 2);
    Expect('its GetOwner', X.GetOwner, 'Tester');
    Expect('its GetCategory', X.GetCategory, 'Tests');
    Check(not X.GetChecked, 'it is not done');
    Check(X.CanEdit and X.CanDelete and X.CanShow and X.IsValid, 'an open file''s comment: it can be shown, edited, deleted');
    Check(X.GetData > 0, 'GetData: the comment''s place', IntToStr(X.GetData));
  end;
  ExpectInt('the demo''s items are still there', DemoItems, FDemoCount);
end;

{ the view's rows: the demo's module as given, the checked one checked, their images drawn }
procedure TToDoTests.Rows;
var
  It: TListItem;
begin
  if not D7StudioOnly('D7 Studio''s To-Do List view') then Exit;
  It := Row('Demo one');
  if not Check(It <> nil, 'the view has the row "Demo one"') then Exit;
  if It.SubItems.Count >= 2 then Expect('its Module column: GetModuleName as given', It.SubItems[1], DemoToDoModule);
  if It.SubItems.Count >= 4 then
  begin
    Expect('its owner', It.SubItems[2], 'Demo');
    Expect('its category', It.SubItems[3], 'Expert');
  end;
  It := Row('Demo two');
  Check((It <> nil) and It.Checked, 'the checked item''s box is checked');
  View.Invalidate;
  FMark := 0;
  FWaitText := 'Demo one.DrawImage';
  FWaitCount := 1;
  WaitFor(Logged, 'DrawImage draws the image of an expert''s row', 10);
end;

{ Delphi 7's To-Do List: Open = CanShow and IsValid, Edit = CanEdit and IsValid, Delete =
  CanDelete }
procedure TToDoTests.States;
begin
  if not D7StudioOnly('D7 Studio''s To-Do List view') then Exit;
  if Choose('Demo three') then
  begin
    MenuStates;
    Check(not Act('aTodoOpen').Enabled, 'an item not valid yet: Open disabled');
    Check(not Act('aTodoEdit').Enabled, '... Edit disabled');
    Check(Act('aTodoDelete').Enabled, '... Delete enabled (CanDelete)');
  end;
  if Choose('Demo two') then
  begin
    MenuStates;
    Check(Act('aTodoOpen').Enabled, 'a valid item: Open enabled');
    Check(Act('aTodoEdit').Enabled, '... Edit enabled');
    Check(not Act('aTodoDelete').Enabled, '... Delete disabled (CanDelete False)');
  end;
end;

{ the box clicked: CanEdit and IsValid asked, then SetChecked(not GetChecked) }
procedure TToDoTests.CheckBox;
var
  It: TListItem;
begin
  if not D7StudioOnly('D7 Studio''s To-Do List view') then Exit;
  It := Row('Demo one');
  if not Check(It <> nil, 'the row "Demo one"') then Exit;
  FMark := ToDoCalls.Count;
  It.Checked := True;
  FWaitText := 'Demo one.SetChecked(True)';
  FWaitCount := 1;
  WaitFor(Logged, 'the check box: SetChecked(True)', 10);
end;

procedure TToDoTests.Checked;
var
  It: TListItem;
begin
  if not D7StudioOnly('D7 Studio''s To-Do List view') then Exit;
  FWaitText := 'Demo one';
  WaitFor(RowThere, 'the list collected again', 10);
  It := Row('Demo one');
  Check((It <> nil) and It.Checked, 'the row is checked as the item says now');
  Check(ToDoCallCount('Demo one.CanEdit', FMark) > 0, 'CanEdit was asked before');
end;

procedure TToDoTests.EditItem;
var
  A: TAction;
begin
  if not D7StudioOnly('D7 Studio''s To-Do List view') then Exit;
  if not Choose('Demo one') then Exit;
  MenuStates;
  A := Act('aTodoEdit');
  if not Check((A <> nil) and A.Enabled, 'Edit is enabled') then Exit;
  FMark := ToDoCalls.Count;
  A.Execute;
  ExpectInt('Edit: the item''s Edit', ToDoCallCount('Demo one.Edit', FMark), 1);
  FWaitText := 'Demo one (edited)';
  WaitFor(RowThere, 'the list collected again (the edited text)', 10);
end;

procedure TToDoTests.Edited;
begin
  if not D7StudioOnly('D7 Studio''s To-Do List view') then Exit;
  Check(Row('Demo one (edited)') <> nil, 'the row shows the item''s new text');
  Check(Row('Demo one') = nil, 'the old text is gone');
end;

procedure TToDoTests.DoubleClick;
begin
  if not D7StudioOnly('D7 Studio''s To-Do List view') then Exit;
  if not Choose('Demo one (edited)') then Exit;
  FMark := ToDoCalls.Count;
  if Assigned(View.OnDblClick) then View.OnDblClick(View);
  ExpectInt('a double click: the item''s DoubleClicked', ToDoCallCount('Demo one (edited).DoubleClicked', FMark), 1);
end;

{ Enter in the list: Open - the item's Show, as in Delphi 7 }
procedure TToDoTests.ShowItem;
var
  Key: Word;
begin
  if not D7StudioOnly('D7 Studio''s To-Do List view') then Exit;
  if not Choose('Demo two') then Exit;
  FMark := ToDoCalls.Count;
  Key := VK_RETURN;
  if Assigned(View.OnKeyDown) then View.OnKeyDown(View, Key, []);
  ExpectInt('Enter: the item''s Show', ToDoCallCount('Demo two.Show', FMark), 1);
  Check(ToDoCallCount('Demo two.CanShow', FMark) > 0, '... after CanShow');
end;

procedure TToDoTests.DeleteItem;
var
  A: TAction;
begin
  if not D7StudioOnly('D7 Studio''s To-Do List view') then Exit;
  if not Choose('Demo three') then Exit;
  MenuStates;
  A := Act('aTodoDelete');
  if not Check((A <> nil) and A.Enabled, 'Delete is enabled') then Exit;
  FBase := Svc.GetItemCount;
  FMark := ToDoCalls.Count;
  A.Execute;
  ExpectInt('Delete: the item''s Delete (no question)', ToDoCallCount('Demo three.Delete', FMark), 1);
  Dec(FDemoCount);
  FWaitText := 'Demo three';
  WaitFor(RowGone, 'the row goes with the list collected again', 10);
end;

procedure TToDoTests.Deleted;
begin
  if not D7StudioOnly('D7 Studio''s To-Do List view') then Exit;
  ExpectInt('GetItemCount: one item less', Svc.GetItemCount, FBase - 1);
  ExpectInt('the demo has two items', DemoItems, FDemoCount);
end;

{ a new TODO typed into the open unit: the list reads the files again after the pause }
procedure TToDoTests.TypingPause;
var
  B: IOTAEditBuffer;
  W: IOTAEditWriter;
  Text: string;
  P: Integer;
begin
  B := OwnBuffer;
  if not Check(B <> nil, 'the unit''s buffer') then Exit;
  Text := EditorText(B);
  P := Pos('end.', Text);
  if not Check(P > 0, 'the unit''s end') then Exit;
  FBase := Svc.GetItemCount;
  W := B.CreateUndoableWriter;
  W.CopyTo(P - 1);
  W.Insert('{ TODO : typed later }'#13#10);
  W := nil;
  WaitFor(ItemsGrew, 'a pause in typing while the list shows: the new TODO is listed', 10);
end;

procedure TToDoTests.TypedItem;
var
  I, Found: Integer;
begin
  Found := 0;
  for I := 0 to Svc.GetItemCount - 1 do
    if Trim(Svc.GetItem(I).GetText) = 'typed later' then Inc(Found);
  ExpectInt('the typed TODO is an item', Found, 1);
  ExpectInt('the demo''s items stay', DemoItems, FDemoCount);
end;

{ T6, T7: Delphi 7's lists - a manager removed takes the later ones one index down, an index out of
  range raises EListError (RemoveManager, RemoveNotifier, GetItem) }
procedure TToDoTests.Indexes;
var
  B: IOTAToDoManager;
  IB, N: Integer;

  function Raises(Kind: Integer; Index: Integer): Boolean;
  begin
    Result := False;
    try
      case Kind of
        0: Svc.RemoveManager(Index);
        1: Svc.RemoveNotifier(Index);
      else
        Svc.GetItem(Index);
      end;
    except
      on E: EListError do Result := True;
    end;
  end;

begin
  B := TDemoToDoManager.Create(ManagerName + '.B', 'Bee');
  IB := Svc.AddManager(B);
  Check(IB > FIndex, 'a second manager: a later index', IntToStr(IB));
  Svc.UpdateList;
  ExpectInt('both managers'' items', DemoItems, FDemoCount + 3);
  Svc.RemoveManager(FIndex);
  FManagerIntf := nil;
  { the second one is one index down now }
  Svc.RemoveManager(IB - 1);
  B := nil;
  Svc.UpdateList;
  ExpectInt('the first removed, then the second by its index one down: no demo item left', DemoItems, 0);
  Check(Raises(0, 1000), 'RemoveManager of an index out of range raises EListError');
  Check(Raises(0, -1), '... of -1 too');
  Check(Raises(1, 1000), 'RemoveNotifier of an index out of range raises EListError');
  N := Svc.GetItemCount;
  Check(Raises(2, N), 'GetItem(GetItemCount) raises EListError');
end;

{ T8: another project of the group active - Delphi 7 tells no expert's manager ProjectChanged }
procedure TToDoTests.OtherProject;
var
  S: TStringList;
begin
  FManager := TDemoToDoManager.Create(ManagerName, 'Demo');
  FManagerIntf := FManager;
  FIndex := Svc.AddManager(FManagerIntf);
  FOtherFile := Dir + 'OtherTodo.dpr';
  S := TStringList.Create;
  try
    S.Add('program OtherTodo;');
    S.Add('');
    S.Add('{$APPTYPE CONSOLE}');
    S.Add('');
    S.Add('begin');
    S.Add('end.');
    S.SaveToFile(FOtherFile);
  finally
    S.Free;
  end;
  { nothing unsaved: the project closes without a question }
  (BorlandIDEServices as IOTAModuleServices).SaveAll;
  FMark := ToDoCalls.Count;
  Check((BorlandIDEServices as IOTAActionServices).OpenProject(FOtherFile, False), 'OpenProject of another project into the group');
  Pause(2000);
end;
function GroupProject(const FileName: string; out G: IOTAProjectGroup): IOTAProject;
var
  M: IOTAModuleServices;
  I: Integer;
begin
  Result := nil;
  G := nil;
  M := BorlandIDEServices as IOTAModuleServices;
  for I := 0 to M.ModuleCount - 1 do
    if Supports(M.Modules[I], IOTAProjectGroup, G) then Break;
  if G = nil then Exit;
  for I := 0 to G.ProjectCount - 1 do
    if SameText(G.Projects[I].FileName, FileName) then Result := G.Projects[I];
end;

procedure TToDoTests.BackAgain;
var
  G: IOTAProjectGroup;
  P: IOTAProject;
begin
  P := GroupProject(FOtherFile, G);
  Check((P <> nil) and (G.ActiveProject <> nil) and SameText(G.ActiveProject.FileName, FOtherFile),
    'the project opened is the active one');
  ExpectInt('no ProjectChanged for the change (Delphi 7 calls it on no expert''s manager)',
    ToDoCallCount(ManagerName + '.ProjectChanged', FMark), 0);
  P := GroupProject(Test.Values['Project'], G);
  if not Check(P <> nil, 'the self-test''s project is in the group') then Exit;
  FMark := ToDoCalls.Count;
  G.SetActiveProject(P);
  Pause(2000);
end;

procedure TToDoTests.ProjectBack;
var
  G: IOTAProjectGroup;
  P: IOTAProject;
begin
  P := GroupProject(Test.Values['Project'], G);
  Check((G <> nil) and (G.ActiveProject <> nil) and SameText(G.ActiveProject.FileName, Test.Values['Project']),
    'the self-test''s project is the active one');
  ExpectInt('... no ProjectChanged either', ToDoCallCount(ManagerName + '.ProjectChanged', FMark), 0);
  P := GroupProject(FOtherFile, G);
  if P <> nil then G.RemoveProject(P);
  Check(GroupProject(FOtherFile, G) = nil, 'the other project left the group');
  ExpectInt('the demo''s items were collected again for the project', DemoItems, 3);
end;

procedure TToDoTests.Finish;
var
  M: IOTAModule;
begin
  Svc.RemoveManager(FIndex);
  FManagerIntf := nil;
  Svc.UpdateList;
  ExpectInt('no demo item after RemoveManager', DemoItems, 0);
  Svc.RemoveNotifier(FNotifier);
  FNotifierIntf := nil;
  ExpectInt('Modified was never sent', ToDoCallCount('Notifier.Modified'), 0);
  DemoShowFile := '';
  M := (BorlandIDEServices as IOTAModuleServices).FindModule(FOwnFile);
  if M <> nil then Check(M.CloseModule(True), 'the unit closed');
end;
initialization
  RegisterTestArea(TToDoTests, 85);
end.
