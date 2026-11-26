{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaToDo;

{ D7 Studio - the To-Do List of the Open Tools API: IOTAToDoServices as Delphi 7
  has them, over D7 Studio's To-Do List (SdTodo; the view is the main window's).

  * The experts' managers (IOTAToDoManager) and notifiers are lists as Delphi 7's: a removed one
    takes the later ones one index down, and an index out of range raises EListError.
  * The managers' items are collected - each manager's GetItemCount once, then GetItem for every
    index - when the list is refreshed (the view shown, UpdateList, RemoveManager, a pause in
    typing while the view shows, the active project changed, an action on an expert's item), as
    Delphi 7's only once its window was made: before the view was first shown nothing is asked:
    what an item says (GetText, GetPriority, GetChecked, GetKind ...) is read then into an item of
    D7 Studio's list (TSdTodoItem.Ext), and the view, its sort, filters, hints and Copy As use
    that. Only the actions (Open, Edit, Delete, the check box, a double click), their enabled
    states and DrawImage call the expert again (OtaTodoAction, OtaTodoDrawImage). Experts are
    called in the main thread only (Delphi also calls them from its parser thread).
  * GetItemCount / GetItem are the items the view shows, D7 Studio's own comments included: an
    own item is an INTAToDoItem over a copy of it (TSdOtaOwnTodoItem: Delphi's TSourceToDoItem /
    TProjectToDoItem). Out of range GetItem raises EListError, as Delphi's.
  * The active project changed: the items collected again. IOTAToDoManager.ProjectChanged is not
    called, as Delphi 7 calls it on no expert's manager (it asks for a private interface): the
    method ProjectChanged below, which would call it, is not used. The notifiers are told Destroyed when the IDE ends;
    Modified is never sent (Delphi 7 sends it nowhere either).
  * An UpdateList while the managers are asked (from a GetItem, a ProjectChanged) asks them once
    more after the round, three rounds at most. }

interface

uses
  Windows, SysUtils, Classes, Graphics, ToolsAPI, SdOtaCore, SdTodo;

type
  TSdOtaToDoServices = class(TAggregatedObject, IOTAToDoServices)
  private
    FManagers: TSdNotifierList;      // IOTAToDoManager, by the index AddManager gave
    FNotifiers: TSdNotifierList;     // IOTANotifier
    FCollecting: Boolean;            // the managers are asked: an UpdateList asks them again after the round
    FAgain: Boolean;
    procedure CollectRound(Items: TList);
  public
    constructor Create(const Controller: IInterface);
    destructor Destroy; override;
    { the experts' items as they are now: a new TSdTodoItem (Ext set) per item into Items - the
      caller owns them }
    procedure Collect(Items: TList);
    { the managers told IOTAToDoManager.ProjectChanged, their items collected again (not called:
      Delphi 7 tells no expert's manager) }
    procedure ProjectChanged;
    { a package goes: its managers, notifiers and items }
    procedure DropModule(Module: HMODULE);
    procedure AddModules(List: TList);
    { the IDE ends: the managers and the experts' items released, the notifiers told Destroyed }
    procedure Shutdown;
    function DebugText: string;
    { IOTAToDoServices }
    function AddManager(AManager: IOTAToDoManager): Integer;
    function AddNotifier(const ANotifier: IOTANotifier): Integer;
    function GetItem(Index: Integer): INTAToDoItem;
    function GetItemCount: Integer;
    procedure RemoveManager(Index: Integer);
    procedure RemoveNotifier(Index: Integer);
    procedure UpdateList;
  end;

  { what the To-Do List does with an expert's item: the enabled states of Open, Edit and Delete
    (Delphi's ToDoItemsUpdate: CanShow and IsValid, CanEdit and IsValid, CanDelete), the actions
    (each asks its state again, as Delphi's Delete does), a double click, the check box (CanEdit
    and IsValid, then SetChecked(not GetChecked) - Delphi's GridMouseUp) }
  TSdTodoAction = (taCanShow, taCanEdit, taCanDelete, taShow, taEdit, taDelete, taDoubleClicked,
    taToggleChecked);

{ the services' collection for the main window (nothing collected without the services) }
procedure OtaTodoCollect(Items: TList);
procedure OtaTodoProjectChanged;
{ an action on an expert's item (Item.Ext): an exception of the expert's is logged (error.log) -
  False then, as for a state that is off or an action that was not done }
function OtaTodoAction(Item: TSdTodoItem; Action: TSdTodoAction): Boolean;
{ the item's DrawImage on Canvas in Rect; False: it raised (logged) }
function OtaTodoDrawImage(Item: TSdTodoItem; Canvas: TCanvas; const Rect: TRect): Boolean;
{ test mode: 'managers|experts'' items|notifiers' }
function OtaTodoDebugText: string;

implementation

uses
  RTLConsts, SdIcons;

type
  { an item of D7 Studio's own as INTAToDoItem: a copy of the list's item (those are made anew at
    every refresh) - Delphi's TSourceToDoItem (a comment of a source file) and TProjectToDoItem
    (an item of the project's To-Do file) }
  TSdOtaOwnTodoItem = class(TInterfacedObject, INTAToDoItem)
  private
    FItem: TSdTodoItem;
  public
    constructor Create(AItem: TSdTodoItem);
    destructor Destroy; override;
    function CanDelete: Boolean;
    function CanEdit: Boolean;
    function CanShow: Boolean;
    procedure Delete;
    procedure DrawImage(const Canvas: TCanvas; const Rect: TRect);
    procedure DoubleClicked;
    procedure Edit;
    function GetText: string;
    function GetPriority: TOTAToDoPriority;
    function GetCategory: string;
    function GetChecked: Boolean;
    function GetModuleName: string;
    function GetKind: string;
    function GetData: Integer;
    function GetOwner: string;
    function IsValid: Boolean;
    procedure SetChecked(const Value: Boolean);
    procedure Show;
  end;

var
  TodoServices: TSdOtaToDoServices;

{ ---------------------------------------------------------------- TSdOtaToDoServices }

constructor TSdOtaToDoServices.Create(const Controller: IInterface);
begin
  inherited Create(Controller);
  FManagers := TSdNotifierList.Create;
  FNotifiers := TSdNotifierList.Create;
  TodoServices := Self;
end;

destructor TSdOtaToDoServices.Destroy;
begin
  if TodoServices = Self then TodoServices := nil;
  FNotifiers.Free;
  FManagers.Free;
  inherited;
end;

{ one round over the managers: a manager that raises is left out of it (what it gave in the
  round goes too) }
procedure TSdOtaToDoServices.CollectRound(Items: TList);
var
  S: TInterfaceList;
  Mine: TList;
  I, K, N: Integer;
  M: IOTAToDoManager;
  X: INTAToDoItem;
  It: TSdTodoItem;
begin
  S := TInterfaceList.Create;
  Mine := TList.Create;
  try
    FManagers.Snapshot(S);
    for I := 0 to S.Count - 1 do
    begin
      if not Supports(S[I], IOTAToDoManager, M) then Continue;
      Mine.Clear;
      try
        N := M.GetItemCount;
        for K := 0 to N - 1 do
        begin
          X := M.GetItem(K);
          if X = nil then Continue;
          It := TSdTodoItem.Create;
          Mine.Add(It);
          It.Ext := X as IInterface;
          It.Comment := X.GetText;
          It.TextStart := 1;
          It.TextEnd := Length(It.Comment) + 1;
          It.Text := TodoTrimText(It.Comment);
          It.Priority := X.GetPriority;
          It.Category := X.GetCategory;
          It.Owner := X.GetOwner;
          It.Done := X.GetChecked;
          It.ExtModule := X.GetModuleName;
          It.ExtKind := X.GetKind;
          It.ExtData := X.GetData;
          It.ExtValid := X.IsValid;
          It.ExtEditable := X.CanEdit;
        end;
        for K := 0 to Mine.Count - 1 do Items.Add(Mine[K]);
      except
        OtaCaught('IOTAToDoManager.GetItem', False);
        for K := 0 to Mine.Count - 1 do TObject(Mine[K]).Free;
      end;
      Mine.Clear;
      X := nil;
      M := nil;
    end;
  finally
    Mine.Free;
    S.Free;
  end;
end;

procedure TSdOtaToDoServices.Collect(Items: TList);
var
  Round, I: Integer;
begin
  if FCollecting or (FManagers.Active = 0) then Exit;
  FCollecting := True;
  try
    Round := 0;
    repeat
      FAgain := False;
      if Round > 0 then
      begin
        for I := 0 to Items.Count - 1 do TObject(Items[I]).Free;
        Items.Clear;
      end;
      CollectRound(Items);
      Inc(Round);
    until not FAgain or (Round >= 3);
  finally
    FCollecting := False;
    FAgain := False;
  end;
end;

procedure ProjectChangedOne(const N: IInterface; Data: Pointer);
begin
  IOTAToDoManager(N).ProjectChanged;
end;

procedure TSdOtaToDoServices.ProjectChanged;
begin
  if FManagers.Active = 0 then Exit;
  { an UpdateList of a manager's ProjectChanged: the collection after it has the items }
  FCollecting := True;
  try
    FManagers.Each(IOTAToDoManager, ProjectChangedOne, nil, 'IOTAToDoManager.ProjectChanged');
  finally
    FCollecting := False;
    FAgain := False;
  end;
  if OtaHost <> nil then OtaHost.TodoExpertsChanged;
end;

{ the module's items go at once, while its code is still there; the other experts are not asked }
procedure TSdOtaToDoServices.DropModule(Module: HMODULE);
begin
  if Module = 0 then Exit;
  FManagers.DropModule(Module);
  FNotifiers.DropModule(Module);
  if OtaHost <> nil then OtaHost.TodoDropModule(Module);
end;

procedure TSdOtaToDoServices.AddModules(List: TList);
begin
  FManagers.AddModules(List);
  FNotifiers.AddModules(List);
end;

{ Delphi's TToDoList.BeforeDestruction: the managers released without a word, then every
  notifier told Destroyed }
procedure TSdOtaToDoServices.Shutdown;
begin
  FManagers.Clear;
  if OtaHost <> nil then OtaHost.TodoDropModule(0);
  FNotifiers.DestroyAll('IOTAToDoServices notifier');
end;

function TSdOtaToDoServices.DebugText: string;
var
  N: Integer;
begin
  N := 0;
  if (OtaHost <> nil) and (OtaHost.TodoList <> nil) then N := OtaHost.TodoList.ExternalCount;
  Result := Format('%d|%d|%d', [FManagers.Active, N, FNotifiers.Active]);
end;

{ Delphi's: the manager joins the list; its items come with the next collection }
function TSdOtaToDoServices.AddManager(AManager: IOTAToDoManager): Integer;
begin
  Result := FManagers.Add(AManager);
end;

function TSdOtaToDoServices.AddNotifier(const ANotifier: IOTANotifier): Integer;
begin
  Result := FNotifiers.Add(ANotifier);
end;

function TSdOtaToDoServices.GetItem(Index: Integer): INTAToDoItem;
var
  L: TSdTodoList;
  It: TSdTodoItem;
begin
  Result := nil;
  if OtaHost <> nil then L := OtaHost.TodoList else L := nil;
  if (L = nil) or (Index < 0) or (Index >= L.Count) then
    raise EListError.CreateFmt(SListIndexError, [Index]);
  It := L[Index];
  if It.Ext <> nil then Supports(It.Ext, INTAToDoItem, Result)
  else Result := TSdOtaOwnTodoItem.Create(It.Clone);
end;

function TSdOtaToDoServices.GetItemCount: Integer;
begin
  if (OtaHost = nil) or (OtaHost.TodoList = nil) then Result := 0
  else Result := OtaHost.TodoList.Count;
end;

{ Delphi 7's: taken out of the list, the later managers one index down, a bad index raises
  EListError; its items go with the collection that follows }
procedure TSdOtaToDoServices.RemoveManager(Index: Integer);
begin
  FManagers.DeleteChecked(Index);
  if OtaHost <> nil then OtaHost.TodoExpertsChanged;
end;

procedure TSdOtaToDoServices.RemoveNotifier(Index: Integer);
begin
  FNotifiers.DeleteChecked(Index);
end;

procedure TSdOtaToDoServices.UpdateList;
begin
  if FCollecting then
  begin
    FAgain := True;
    Exit;
  end;
  if OtaHost <> nil then OtaHost.TodoExpertsChanged;
end;

{ ---------------------------------------------------------------- the main window's calls }

procedure OtaTodoCollect(Items: TList);
begin
  if TodoServices <> nil then TodoServices.Collect(Items);
end;

procedure OtaTodoProjectChanged;
begin
  if TodoServices <> nil then TodoServices.ProjectChanged;
end;

function OtaTodoAction(Item: TSdTodoItem; Action: TSdTodoAction): Boolean;
const
  Names: array[TSdTodoAction] of string = ('CanShow', 'CanEdit', 'CanDelete', 'Show', 'Edit', 'Delete',
    'DoubleClicked', 'SetChecked');
var
  X: INTAToDoItem;
begin
  Result := False;
  if (Item = nil) or (Item.Ext = nil) then Exit;
  try
    if not Supports(Item.Ext, INTAToDoItem, X) then Exit;
    case Action of
      taCanShow: Result := X.CanShow and X.IsValid;
      taCanEdit: Result := X.CanEdit and X.IsValid;
      taCanDelete: Result := X.CanDelete;
      taShow:
        if X.CanShow and X.IsValid then
        begin
          X.Show;
          Result := True;
        end;
      taEdit:
        if X.CanEdit and X.IsValid then
        begin
          X.Edit;
          Result := True;
        end;
      taDelete:
        if X.CanDelete then
        begin
          X.Delete;
          Result := True;
        end;
      taDoubleClicked:
        begin
          X.DoubleClicked;
          Result := True;
        end;
      taToggleChecked:
        if X.CanEdit and X.IsValid then
        begin
          X.SetChecked(not X.GetChecked);
          Result := True;
        end;
    end;
  except
    OtaCaught('INTAToDoItem.' + Names[Action], False);
    Result := False;
  end;
end;

function OtaTodoDrawImage(Item: TSdTodoItem; Canvas: TCanvas; const Rect: TRect): Boolean;
var
  X: INTAToDoItem;
begin
  Result := True;
  if (Item = nil) or (Item.Ext = nil) then Exit;
  try
    if Supports(Item.Ext, INTAToDoItem, X) then X.DrawImage(Canvas, Rect);
  except
    OtaCaught('INTAToDoItem.DrawImage', False);
    Result := False;
  end;
end;

function OtaTodoDebugText: string;
begin
  if TodoServices = nil then Result := '' else Result := TodoServices.DebugText;
end;

{ ---------------------------------------------------------------- TSdOtaOwnTodoItem }

constructor TSdOtaOwnTodoItem.Create(AItem: TSdTodoItem);
begin
  inherited Create;
  FItem := AItem;
end;

destructor TSdOtaOwnTodoItem.Destroy;
begin
  FItem.Free;
  inherited;
end;

{ Delphi's CanEdit / CanDelete: a file open in the editor (not read-only), or the To-Do file }
function TSdOtaOwnTodoItem.CanDelete: Boolean;
begin
  Result := (OtaHost <> nil) and OtaHost.TodoCanEdit(FItem);
end;

function TSdOtaOwnTodoItem.CanEdit: Boolean;
begin
  Result := CanDelete;
end;

function TSdOtaOwnTodoItem.CanShow: Boolean;
begin
  Result := not FItem.InTodoFile;
end;

procedure TSdOtaOwnTodoItem.Delete;
begin
  if CanDelete then OtaHost.TodoChange(FItem, '');
end;

procedure TSdOtaOwnTodoItem.DrawImage(const Canvas: TCanvas; const Rect: TRect);
var
  I: Integer;
begin
  I := TodoImageIndex(FItem);
  if (I >= 0) and (IconList <> nil) and (Canvas <> nil) then IconList.Draw(Canvas, Rect.Left, Rect.Top, I);
end;

{ as the list's double click: the source shown, an item of the To-Do file edited }
procedure TSdOtaOwnTodoItem.DoubleClicked;
begin
  if FItem.InTodoFile then
  begin
    if CanEdit then Edit;
  end
  else if CanShow then
    Show;
end;

procedure TSdOtaOwnTodoItem.Edit;
begin
  if CanEdit then OtaHost.TodoEdit(FItem);
end;

function TSdOtaOwnTodoItem.GetText: string;
begin
  Result := FItem.RawText;
end;

function TSdOtaOwnTodoItem.GetPriority: TOTAToDoPriority;
begin
  Result := FItem.Priority;
end;

function TSdOtaOwnTodoItem.GetCategory: string;
begin
  Result := FItem.Category;
end;

function TSdOtaOwnTodoItem.GetChecked: Boolean;
begin
  Result := FItem.Done;
end;

function TSdOtaOwnTodoItem.GetModuleName: string;
begin
  Result := FItem.Module;
end;

function TSdOtaOwnTodoItem.GetKind: string;
begin
  Result := FItem.Kind;
end;

function TSdOtaOwnTodoItem.GetData: Integer;
begin
  Result := FItem.Pos;
end;

function TSdOtaOwnTodoItem.GetOwner: string;
begin
  Result := FItem.Owner;
end;

function TSdOtaOwnTodoItem.IsValid: Boolean;
begin
  Result := True;
end;

{ DONE or TODO written into the comment, as the list's check box does }
procedure TSdOtaOwnTodoItem.SetChecked(const Value: Boolean);
var
  S: string;
begin
  if (Value = FItem.Done) or not CanEdit then Exit;
  S := TodoEditComment(FItem, Value, FItem.Priority, FItem.Owner, FItem.Category, FItem.RawText);
  if S = FItem.Comment then Exit;
  OtaHost.TodoChange(FItem, S);
  FItem.Done := Value;
end;

procedure TSdOtaOwnTodoItem.Show;
begin
  if (OtaHost <> nil) and CanShow and (FItem.FileName <> '') then OtaHost.ShowFileLine(FItem.FileName, FItem.Line, 1);
end;

end.
