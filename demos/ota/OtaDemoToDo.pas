{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoToDo;

{ The OTA demo's To-Do List expert (IOTAToDoServices): a manager (IOTAToDoManager) with three items
  of its own (INTAToDoItem), and a notifier. Every call they get is written into ToDoCalls as
  "<who>.<method>(arguments) -> result" - the self-test (OtaDemoTestToDo) reads it, OTA Demo |
  To-Do | Call log shows it.

  The items: "<prefix> one" (priority 1; it can be deleted, edited and shown), "<prefix> two"
  (checked; it cannot be deleted), "<prefix> three" (not valid yet: Open and Edit stay disabled);
  owner Demo, category Expert, kind 'OTA Demo', module 'Bug tracker', data their number.
  DrawImage paints a square of the item's colour; Delete takes the item out and Edit appends
  " (edited)" - both then ask the IDE to collect the list again (UpdateList). Show opens
  DemoShowFile (none: the active project's source) at its first line. }

interface

uses
  Windows, SysUtils, Classes, Graphics, ToolsAPI;

const
  DemoToDoKind = 'OTA Demo';
  DemoToDoModule = 'Bug tracker';

type
  TDemoToDoManager = class;

  TDemoToDoItem = class(TInterfacedObject, INTAToDoItem)
  private
    FManager: TDemoToDoManager;
    FNumber: Integer;
    FText: string;
    FPriority: Integer;
    FChecked: Boolean;
    FCanDelete, FValid: Boolean;
    FColor: TColor;
    function Who: string;
  public
    constructor Create(AManager: TDemoToDoManager; ANumber: Integer; const AText: string; APriority: Integer;
      AChecked, ACanDelete, AValid: Boolean; AColor: TColor);
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
    property Text: string read FText;
    property Number: Integer read FNumber;
  end;

  TDemoToDoManager = class(TInterfacedObject, IOTAToDoManager)
  private
    FName: string;
    FItems: TInterfaceList;          // INTAToDoItem: the references
    FObjects: TList;                 // ... the TDemoToDoItem objects, in the same order
  public
    constructor Create(const AName, APrefix: string);
    destructor Destroy; override;
    procedure Add(Item: TDemoToDoItem);
    procedure Remove(Item: TDemoToDoItem);
    function Count: Integer;
    function Item(Index: Integer): TDemoToDoItem;
    { IOTAToDoManager }
    function GetName: string;
    procedure SetName(const AName: string);
    function GetItem(Index: Integer): INTAToDoItem;
    function GetItemCount: Integer;
    procedure ProjectChanged;
  end;

  { the list's notifier: Modified and Destroyed into the log }
  TDemoToDoNotifier = class(TNotifierObject, IOTANotifier)
  public
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;
  end;

var
  ToDoCalls: TStringList;            // the calls the demo's objects got
  DemoShowFile: string;              // what Show opens ('': the active project's source)

procedure ToDoCall(const S: string);
{ the number of lines of the log that start with Text, from line From on }
function ToDoCallCount(const Text: string; From: Integer = 0): Integer;
function ToDoServices: IOTAToDoServices;

implementation

const
  BoolText: array[Boolean] of string = ('False', 'True');

procedure ToDoCall(const S: string);
begin
  if ToDoCalls = nil then Exit;
  ToDoCalls.Add(S);
  { the log of a long session stays small: DrawImage comes with every paint }
  if ToDoCalls.Count > 5000 then ToDoCalls.Delete(0);
end;

function ToDoCallCount(const Text: string; From: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  if ToDoCalls = nil then Exit;
  if From < 0 then From := 0;
  for I := From to ToDoCalls.Count - 1 do
    if Copy(ToDoCalls[I], 1, Length(Text)) = Text then Inc(Result);
end;

function ToDoServices: IOTAToDoServices;
begin
  Result := BorlandIDEServices as IOTAToDoServices;
end;

{ ---------------------------------------------------------------- TDemoToDoItem }

constructor TDemoToDoItem.Create(AManager: TDemoToDoManager; ANumber: Integer; const AText: string;
  APriority: Integer; AChecked, ACanDelete, AValid: Boolean; AColor: TColor);
begin
  inherited Create;
  FManager := AManager;
  FNumber := ANumber;
  FText := AText;
  FPriority := APriority;
  FChecked := AChecked;
  FCanDelete := ACanDelete;
  FValid := AValid;
  FColor := AColor;
end;

function TDemoToDoItem.Who: string;
begin
  Result := FText;
end;

function TDemoToDoItem.CanDelete: Boolean;
begin
  Result := FCanDelete;
  ToDoCall(Who + '.CanDelete -> ' + BoolText[Result]);
end;

function TDemoToDoItem.CanEdit: Boolean;
begin
  Result := True;
  ToDoCall(Who + '.CanEdit -> ' + BoolText[Result]);
end;

function TDemoToDoItem.CanShow: Boolean;
begin
  Result := True;
  ToDoCall(Who + '.CanShow -> ' + BoolText[Result]);
end;

{ out of the manager's list; the IDE collects the list again }
procedure TDemoToDoItem.Delete;
begin
  ToDoCall(Who + '.Delete');
  if FManager <> nil then FManager.Remove(Self);
  ToDoServices.UpdateList;
end;

procedure TDemoToDoItem.DrawImage(const Canvas: TCanvas; const Rect: TRect);
begin
  ToDoCall(Who + Format('.DrawImage(%d,%d,%d,%d)', [Rect.Left, Rect.Top, Rect.Right, Rect.Bottom]));
  Canvas.Brush.Color := FColor;
  Canvas.FillRect(Classes.Rect(Rect.Left + 3, Rect.Top + 3, Rect.Left + 13, Rect.Top + 13));
end;

procedure TDemoToDoItem.DoubleClicked;
begin
  ToDoCall(Who + '.DoubleClicked');
end;

procedure TDemoToDoItem.Edit;
begin
  ToDoCall(Who + '.Edit');
  FText := FText + ' (edited)';
  ToDoServices.UpdateList;
end;

function TDemoToDoItem.GetText: string;
begin
  Result := FText;
  ToDoCall(Who + '.GetText');
end;

function TDemoToDoItem.GetPriority: TOTAToDoPriority;
begin
  Result := FPriority;
  ToDoCall(Who + '.GetPriority -> ' + IntToStr(Result));
end;

function TDemoToDoItem.GetCategory: string;
begin
  Result := 'Expert';
  ToDoCall(Who + '.GetCategory');
end;

function TDemoToDoItem.GetChecked: Boolean;
begin
  Result := FChecked;
  ToDoCall(Who + '.GetChecked -> ' + BoolText[Result]);
end;

function TDemoToDoItem.GetModuleName: string;
begin
  Result := DemoToDoModule;
  ToDoCall(Who + '.GetModuleName');
end;

function TDemoToDoItem.GetKind: string;
begin
  Result := DemoToDoKind;
  ToDoCall(Who + '.GetKind');
end;

function TDemoToDoItem.GetData: Integer;
begin
  Result := FNumber;
  ToDoCall(Who + '.GetData -> ' + IntToStr(Result));
end;

function TDemoToDoItem.GetOwner: string;
begin
  Result := 'Demo';
  ToDoCall(Who + '.GetOwner');
end;

function TDemoToDoItem.IsValid: Boolean;
begin
  Result := FValid;
  ToDoCall(Who + '.IsValid -> ' + BoolText[Result]);
end;

procedure TDemoToDoItem.SetChecked(const Value: Boolean);
begin
  ToDoCall(Who + '.SetChecked(' + BoolText[Value] + ')');
  FChecked := Value;
end;

{ the file in the editor, the cursor at its first line }
procedure TDemoToDoItem.Show;
var
  F: string;
  P: IOTAProject;
  G: IOTAProjectGroup;
  V: IOTAEditView;
  E: TOTAEditPos;
  M: IOTAModuleServices;
  S: IOTASourceEditor;
  I: Integer;
begin
  ToDoCall(Who + '.Show');
  F := DemoShowFile;
  if F = '' then
  begin
    { the active project's source: its own source editor shown - IOTAActionServices.OpenFile would
      open the project again (the group closed first), as Delphi's does }
    P := nil;
    M := BorlandIDEServices as IOTAModuleServices;
    for I := 0 to M.ModuleCount - 1 do
      if Supports(M.Modules[I], IOTAProjectGroup, G) then P := G.ActiveProject;
    if P = nil then Exit;
    for I := 0 to P.GetModuleFileCount - 1 do
      if Supports(P.GetModuleFileEditor(I), IOTASourceEditor, S) then
      begin
        S.Show;
        Break;
      end;
  end
  else if not (BorlandIDEServices as IOTAActionServices).OpenFile(F) then Exit;
  V := (BorlandIDEServices as IOTAEditorServices).TopView;
  if V = nil then Exit;
  E.Line := 1;
  E.Col := 1;
  V.CursorPos := E;
  V.MoveViewToCursor;
end;

{ ---------------------------------------------------------------- TDemoToDoManager }

constructor TDemoToDoManager.Create(const AName, APrefix: string);
begin
  inherited Create;
  FName := AName;
  FItems := TInterfaceList.Create;
  FObjects := TList.Create;
  Add(TDemoToDoItem.Create(Self, 1, APrefix + ' one', 1, False, True, True, clRed));
  Add(TDemoToDoItem.Create(Self, 2, APrefix + ' two', 0, True, False, True, clGreen));
  Add(TDemoToDoItem.Create(Self, 3, APrefix + ' three', 3, False, True, False, clBlue));
end;

destructor TDemoToDoManager.Destroy;
var
  I: Integer;
begin
  for I := 0 to FObjects.Count - 1 do TDemoToDoItem(FObjects[I]).FManager := nil;
  FObjects.Free;
  FItems.Free;
  inherited;
end;

procedure TDemoToDoManager.Add(Item: TDemoToDoItem);
begin
  FObjects.Add(Item);
  FItems.Add(Item as INTAToDoItem);
end;

procedure TDemoToDoManager.Remove(Item: TDemoToDoItem);
var
  I: Integer;
begin
  I := FObjects.IndexOf(Item);
  if I < 0 then Exit;
  Item.FManager := nil;
  FObjects.Delete(I);
  FItems.Delete(I);
end;

function TDemoToDoManager.Count: Integer;
begin
  Result := FObjects.Count;
end;

function TDemoToDoManager.Item(Index: Integer): TDemoToDoItem;
begin
  if (Index < 0) or (Index >= FObjects.Count) then Result := nil
  else Result := TDemoToDoItem(FObjects[Index]);
end;

function TDemoToDoManager.GetName: string;
begin
  Result := FName;
  ToDoCall(FName + '.GetName');
end;

procedure TDemoToDoManager.SetName(const AName: string);
begin
  ToDoCall(FName + '.SetName(' + AName + ')');
  FName := AName;
end;

function TDemoToDoManager.GetItem(Index: Integer): INTAToDoItem;
begin
  ToDoCall(FName + '.GetItem(' + IntToStr(Index) + ')');
  Result := FItems[Index] as INTAToDoItem;
end;

function TDemoToDoManager.GetItemCount: Integer;
begin
  Result := FItems.Count;
  ToDoCall(FName + '.GetItemCount -> ' + IntToStr(Result));
end;

procedure TDemoToDoManager.ProjectChanged;
begin
  ToDoCall(FName + '.ProjectChanged');
end;

{ ---------------------------------------------------------------- TDemoToDoNotifier }

procedure TDemoToDoNotifier.AfterSave;
begin
  ToDoCall('Notifier.AfterSave');
end;

procedure TDemoToDoNotifier.BeforeSave;
begin
  ToDoCall('Notifier.BeforeSave');
end;

procedure TDemoToDoNotifier.Destroyed;
begin
  ToDoCall('Notifier.Destroyed');
end;

procedure TDemoToDoNotifier.Modified;
begin
  ToDoCall('Notifier.Modified');
end;

initialization
  ToDoCalls := TStringList.Create;

finalization
  FreeAndNil(ToDoCalls);
end.
