{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoWizard;

{ D7 Studio's Open Tools API demo: an IDE expert, as Delphi 7's experts are
  written, with a command for each service of BorlandIDEServices; Run self-test (OtaDemoTest)
  checks them all.

  Install: compile OtaDemo.dpk (it requires designide), then Component | Install Packages | Add
  OtaDemo.bpl. What it adds:
    * the menu OTA Demo before Help (INTAServices: main menu, action list, image list, tool bar),
      one command per service - their output goes to the message group "OTA Demo". Its place is
      found as experts find theirs: by the names of Delphi 7's menu items (HelpMenu), which the
      IDE's main menu keeps (OTA Demo | Main menu names lists them all, with their actions'
      names); OTA Demo | Component palette reads Delphi's palette as experts read it, past the
      Open Tools API (the main form AppBuilder, its TabControl and Palette, by RTTI), and Place a
      Button with the next click chooses a tool there;
    * View | OTA Demo Window, after Window List (ViewWindowListItem in ViewsMenu): a dockable
      tool window (OtaDemoWin: TDockableForm and the desktop of designide's DeskUtil);
    * a button with its own image on the tool bar (INTAServices.AddMasked, ToolBar);
    * Help | OTA Demo: About (IOTAMenuWizard);
    * File | New | Other, page OTA Demo: a form wizard (IOTAFormWizard, IOTAModuleCreator);
    * the keys Ctrl+Alt+D (a date comment at the cursor) and Ctrl+Alt+U (the word at the cursor
      in capitals) in the code editor (IOTAKeyboardBinding);
    * the item OTA Demo: Word at Cursor in the code editor's menu, found by its name as Delphi 7's
      experts find it (EditorLocalMenu on INTAEditWindow.Form, its OnPopup chained); OTA Demo |
      Edit window lists what experts find of Delphi's edit window past the Open Tools API (the
      form, its editor control and file tabs, a routine of coreide70.bpl called on the control);
    * notifiers that report to the message group: files opened and closed, compiles
      (IOTAIDENotifier50), the debugger's processes and breakpoints (IOTADebuggerNotifier),
      message groups (IOTAMessageNotifier), a watched module (IOTAModuleNotifier), a tracked line
      (IOTAEditLineNotifier);
    * handlers of the main window's created and shown events (DeskUtil): shown in the window;
    * OTA Demo | To-Do and OTA Demo | Code Insight: the To-Do List's and code insight's services
      with the demo's managers (OtaDemoToDo: items of kind 'OTA Demo'; OtaDemoCodeInsight: colour
      names in *.otademo files) and their call logs;
    * OTA Demo | More Services (OtaDemoServices2): a syntax highlighter of *.otaini files, a tools
      filter, the type library modules, a unit with additional files, a file system in memory,
      the keystroke records, the speed settings, a message with children.
  Removing the package takes all of it away again (the destructors). }

interface

procedure Register;

implementation

uses
  Windows, SysUtils, Classes, Variants, Graphics, Controls, Forms, Menus, ActnList, ComCtrls, Dialogs,
  ImgList, TypInfo, ToolsAPI, DeskUtil, OtaDemoCreators, OtaDemoWin, OtaDemoTest, OtaDemoToDo,
  OtaDemoCodeInsight, OtaDemoServices2;

const
  DemoCategory = 'OTA Demo';
  DemoPrefix = 'OTA Demo';

var
  DemoGroup: IOTAMessageGroup;       // the demo's tab of the Messages view

{ ---------------------------------------------------------------- messages }

function Msgs: IOTAMessageServices;
begin
  Result := BorlandIDEServices as IOTAMessageServices;
end;

{ a line of the demo's group (Parent: a line it belongs under; the result: this line) }
function Say(const Text: string; Parent: Pointer = nil): Pointer;
begin
  Msgs.AddToolMessage('', Text, DemoPrefix, 0, 0, Parent, Result, DemoGroup);
end;

{ a line that leads to a file and line (a double click opens it) }
function SayAt(const FileName: string; Line: Integer; const Text: string; Parent: Pointer = nil): Pointer;
begin
  Msgs.AddToolMessage(FileName, Text, DemoPrefix, Line, 1, Parent, Result, DemoGroup);
end;

procedure Title(const Text: string);
begin
  Msgs.AddTitleMessage('--- ' + Text + ' ---', DemoGroup);
  Msgs.ShowMessageView(DemoGroup);
end;

function TopView: IOTAEditView;
begin
  Result := (BorlandIDEServices as IOTAEditorServices).TopView;
  if Result = nil then Say('No file is open in the code editor.');
end;

function ResId(P: PChar): string;
begin
  if Cardinal(P) shr 16 = 0 then Result := '#' + IntToStr(Cardinal(P)) else Result := P;
end;

{ the main menu's item called Name, searched in every submenu: the names are Delphi 7's
  (FileMenu, ViewsMenu, ToolsOptionsItem, HelpAboutItem ...), and experts find their places by
  them, not by captions, which change with the language }
function FindMenuItem(Items: TMenuItem; const Name: string): TMenuItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Items.Count - 1 do
  begin
    if SameText(Items[I].Name, Name) then Result := Items[I]
    else Result := FindMenuItem(Items[I], Name);
    if Result <> nil then Exit;
  end;
end;

{ ---------------------------------------------------------------- the code editor's menu }

type
  { OTA Demo: Word at Cursor in the code editor's menu, put there as Delphi 7's experts do: the
    Open Tools API has no interface for it, so the menu is found by its name, EditorLocalMenu, on
    the edit window's form (INTAEditWindow.Form), and its OnPopup is chained. Delphi 7 makes the
    menu's items anew each time it opens, so the item is added there whenever it is missing. The
    hook needs an edit view: it is made once a file is open. }
  TDemoEditorMenu = class(TComponent)
  private
    FMenu: TPopupMenu;
    FIdePopup: TNotifyEvent;           // the OnPopup found on the menu
    FItem: TMenuItem;
    procedure Popup(Sender: TObject);
    procedure WordAtCursor(Sender: TObject);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    destructor Destroy; override;
    procedure Hook;
  end;

var
  EditorMenu: TDemoEditorMenu;

procedure TDemoEditorMenu.Hook;
var
  View: IOTAEditView;
  C: TComponent;
begin
  if FMenu <> nil then Exit;
  View := (BorlandIDEServices as IOTAEditorServices).TopView;
  if (View = nil) or (View.GetEditWindow = nil) or (View.GetEditWindow.Form = nil) then Exit;
  C := View.GetEditWindow.Form.FindComponent('EditorLocalMenu');
  if not (C is TPopupMenu) then Exit;
  FMenu := TPopupMenu(C);
  FMenu.FreeNotification(Self);
  FIdePopup := FMenu.OnPopup;
  FMenu.OnPopup := Popup;
end;

{ the IDE's handler first, then the item when the menu has lost it (Delphi's handler frees the
  items it makes the menu of; the item's owner is this component, which hears it) }
procedure TDemoEditorMenu.Popup(Sender: TObject);
begin
  if Assigned(FIdePopup) then FIdePopup(Sender);
  if FMenu = nil then Exit;
  if FItem = nil then
  begin
    FItem := TMenuItem.Create(Self);
    FItem.Name := 'OtaDemoWordItem';
    FItem.Caption := 'OTA Demo: &Word at Cursor';
    FItem.OnClick := WordAtCursor;
  end;
  if FMenu.Items.IndexOf(FItem) < 0 then FMenu.Items.Add(FItem);
end;

{ the identifier at the cursor, read with RipText backwards and forwards (the cursor stays) }
procedure TDemoEditorMenu.WordAtCursor(Sender: TObject);
const
  WordChars = ['A'..'Z', 'a'..'z', '0'..'9', '_'];
var
  View: IOTAEditView;
  P: IOTAEditPosition;
  Before, After: string;
begin
  Title('Word at cursor');
  View := TopView;
  if View = nil then Exit;
  P := View.Position;
  Before := P.RipText(WordChars, rfBackward);
  After := P.RipText(WordChars, 0);
  if Before + After = '' then Say('There is no word at the cursor.')
  else Say(Format('%s, line %d, column %d', [Before + After, P.Row, P.Column - Length(Before)]));
end;

procedure TDemoEditorMenu.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if Operation = opRemove then
  begin
    if AComponent = FItem then FItem := nil;
    if AComponent = FMenu then FMenu := nil;
  end;
end;

{ the handler that was found goes back; the item, owned here, leaves the menu as it is freed }
destructor TDemoEditorMenu.Destroy;
begin
  if FMenu <> nil then
  begin
    FMenu.OnPopup := FIdePopup;
    FMenu.RemoveFreeNotification(Self);
  end;
  inherited;
end;

{ ---------------------------------------------------------------- notifiers }

type
  TDemoIdeNotifier = class(TNotifierObject, IOTANotifier, IOTAIDENotifier, IOTAIDENotifier50)
  public
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string;
      var Cancel: Boolean);
    procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean); overload;
    procedure BeforeCompile(const Project: IOTAProject; IsCodeInsight: Boolean; var Cancel: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean; IsCodeInsight: Boolean); overload;
  end;

  TDemoDebugNotifier = class(TNotifierObject, IOTANotifier, IOTADebuggerNotifier)
  public
    procedure ProcessCreated(Process: IOTAProcess);
    procedure ProcessDestroyed(Process: IOTAProcess);
    procedure BreakpointAdded(Breakpoint: IOTABreakpoint);
    procedure BreakpointDeleted(Breakpoint: IOTABreakpoint);
  end;

  TDemoMessageNotifier = class(TNotifierObject, IOTANotifier, IOTAMessageNotifier)
  public
    procedure MessageGroupAdded(const Group: IOTAMessageGroup);
    procedure MessageGroupDeleted(const Group: IOTAMessageGroup);
  end;

  { the notifier of OTA Demo | Watch current module. While it is registered it is listed in the
    expert's FWatched (the module's file name, Objects: the notifier); Destroyed - the module
    closed, the IDE ends - takes it out, and the expert's destructor removes the ones still there
    from their modules }
  TDemoModuleNotifier = class(TNotifierObject, IOTANotifier, IOTAModuleNotifier)
  private
    FModule: IOTAModule;
    FIndex: Integer;                 // the index IOTAModule.AddNotifier gave it
    FList: TStringList;
    FFileName: string;
    FChanges: Integer;
    procedure Unlist;
  public
    constructor Create(const AModule: IOTAModule; AList: TStringList);
    procedure Remove;
    procedure AfterSave;
    procedure Destroyed;
    procedure Modified;
    function CheckOverwrite: Boolean;
    procedure ModuleRenamed(const NewName: string);
  end;

  { the notifier of OTA Demo | Track this line on a buffer's line tracker, listed in the expert's
    FTracked in the same way: its tracker tells it Destroyed when the file closes }
  TDemoLineNotifier = class(TNotifierObject, IOTANotifier, IOTAEditLineNotifier)
  private
    FTracker: IOTAEditLineTracker;
    FIndex: Integer;                 // the index IOTAEditLineTracker.AddNotifier gave it
    FList: TStringList;
    FFileName: string;
    procedure Unlist;
  public
    constructor Create(const ATracker: IOTAEditLineTracker; const AFileName: string; AList: TStringList);
    procedure Remove;
    procedure Destroyed;
    procedure LineChanged(OldLine, NewLine: Integer; Data: Integer);
  end;

const
  FileEvents: array[TOTAFileNotification] of string = ('file opening', 'file opened', 'file closing',
    'default desktop load', 'default desktop save', 'project desktop load', 'project desktop save',
    'package installed', 'package uninstalled', 'active project changed');

procedure TDemoIdeNotifier.FileNotification(NotifyCode: TOTAFileNotification; const FileName: string;
  var Cancel: Boolean);
begin
  Say('IDE notifier: ' + FileEvents[NotifyCode] + ': ' + FileName);
  { the code editor's menu, once there is an edit view }
  if (NotifyCode = ofnFileOpened) and (EditorMenu <> nil) then EditorMenu.Hook;
end;

procedure TDemoIdeNotifier.BeforeCompile(const Project: IOTAProject; var Cancel: Boolean);
begin
  BeforeCompile(Project, False, Cancel);
end;

procedure TDemoIdeNotifier.AfterCompile(Succeeded: Boolean);
begin
  AfterCompile(Succeeded, False);
end;

{ IsCodeInsight: a compile code insight runs for itself, not one of the project - not reported }
procedure TDemoIdeNotifier.BeforeCompile(const Project: IOTAProject; IsCodeInsight: Boolean;
  var Cancel: Boolean);
begin
  if IsCodeInsight then Exit;
  if Project <> nil then Say('IDE notifier: before compile of ' + ExtractFileName(Project.FileName))
  else Say('IDE notifier: before compile');
end;

procedure TDemoIdeNotifier.AfterCompile(Succeeded: Boolean; IsCodeInsight: Boolean);
begin
  if IsCodeInsight then Exit;
  if Succeeded then Say('IDE notifier: compile succeeded') else Say('IDE notifier: compile failed');
end;

procedure TDemoDebugNotifier.ProcessCreated(Process: IOTAProcess);
begin
  Say(Format('Debugger notifier: process %d created', [Process.ProcessId]));
end;

procedure TDemoDebugNotifier.ProcessDestroyed(Process: IOTAProcess);
begin
  Say('Debugger notifier: process destroyed');
end;

procedure TDemoDebugNotifier.BreakpointAdded(Breakpoint: IOTABreakpoint);
begin
  SayAt(Breakpoint.FileName, Breakpoint.LineNumber, 'Debugger notifier: breakpoint added');
end;

procedure TDemoDebugNotifier.BreakpointDeleted(Breakpoint: IOTABreakpoint);
begin
  Say('Debugger notifier: breakpoint deleted');
end;

{ the groups other experts add and remove, reported in the demo's own group }
procedure TDemoMessageNotifier.MessageGroupAdded(const Group: IOTAMessageGroup);
begin
  if (DemoGroup <> nil) and (Group <> DemoGroup) then Say('Message notifier: group added: ' + Group.Name);
end;

procedure TDemoMessageNotifier.MessageGroupDeleted(const Group: IOTAMessageGroup);
begin
  if (DemoGroup <> nil) and (Group <> DemoGroup) then Say('Message notifier: group deleted: ' + Group.Name);
end;

constructor TDemoModuleNotifier.Create(const AModule: IOTAModule; AList: TStringList);
begin
  inherited Create;
  FFileName := AModule.FileName;
  FIndex := AModule.AddNotifier(Self);
  FModule := AModule;
  FList := AList;
  FList.AddObject(FFileName, Self);
end;

{ no longer registered: out of the expert's list; the module is let go }
procedure TDemoModuleNotifier.Unlist;
var
  I: Integer;
begin
  if FList <> nil then
  begin
    I := FList.IndexOfObject(Self);
    if I >= 0 then FList.Delete(I);
    FList := nil;
  end;
  FModule := nil;
end;

{ the expert goes: the notifier is taken from its module (which releases it - nothing of the
  object is used after RemoveNotifier) }
procedure TDemoModuleNotifier.Remove;
var
  M: IOTAModule;
begin
  M := FModule;
  Unlist;
  if M <> nil then M.RemoveNotifier(FIndex);
end;

procedure TDemoModuleNotifier.AfterSave;
begin
  SayAt(FFileName, 1, Format('Module notifier: saved after %d changes', [FChanges]));
  FChanges := 0;
end;

procedure TDemoModuleNotifier.Destroyed;
begin
  Say('Module notifier: closed ' + FFileName);
  Unlist;
end;

procedure TDemoModuleNotifier.Modified;
begin
  Inc(FChanges);
end;

function TDemoModuleNotifier.CheckOverwrite: Boolean;
begin
  Result := True;
end;

procedure TDemoModuleNotifier.ModuleRenamed(const NewName: string);
var
  I: Integer;
begin
  Say('Module notifier: ' + FFileName + ' renamed to ' + NewName);
  FFileName := NewName;
  if FList <> nil then
  begin
    I := FList.IndexOfObject(Self);
    if I >= 0 then FList[I] := NewName;
  end;
end;

constructor TDemoLineNotifier.Create(const ATracker: IOTAEditLineTracker; const AFileName: string;
  AList: TStringList);
begin
  inherited Create;
  FFileName := AFileName;
  FIndex := ATracker.AddNotifier(Self);
  FTracker := ATracker;
  FList := AList;
  FList.AddObject(FFileName, Self);
end;

procedure TDemoLineNotifier.Unlist;
var
  I: Integer;
begin
  if FList <> nil then
  begin
    I := FList.IndexOfObject(Self);
    if I >= 0 then FList.Delete(I);
    FList := nil;
  end;
  FTracker := nil;
end;

procedure TDemoLineNotifier.Remove;
var
  T: IOTAEditLineTracker;
begin
  T := FTracker;
  Unlist;
  if T <> nil then T.RemoveNotifier(FIndex);
end;

{ the file closed: its tracker goes }
procedure TDemoLineNotifier.Destroyed;
begin
  Unlist;
end;

procedure TDemoLineNotifier.LineChanged(OldLine, NewLine: Integer; Data: Integer);
begin
  SayAt(FFileName, NewLine, Format('Line tracker: tracked line moved from %d to %d', [OldLine, NewLine]));
end;

{ ---------------------------------------------------------------- the key binding }

type
  TDemoKeyBinding = class(TNotifierObject, IOTANotifier, IOTAKeyboardBinding)
  private
    procedure InsertDate(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
    procedure UpperWord(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
  public
    function GetBindingType: TBindingType;
    function GetDisplayName: string;
    function GetName: string;
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
  end;

function TDemoKeyBinding.GetBindingType: TBindingType;
begin
  Result := btPartial;
end;

function TDemoKeyBinding.GetDisplayName: string;
begin
  Result := 'OTA Demo keys';
end;

function TDemoKeyBinding.GetName: string;
begin
  Result := 'D7Studio.OtaDemo.Keys';
end;

procedure TDemoKeyBinding.BindKeyboard(const BindingServices: IOTAKeyBindingServices);
begin
  BindingServices.AddKeyBinding([ShortCut(Ord('D'), [ssCtrl, ssAlt])], InsertDate, nil);
  BindingServices.AddKeyBinding([ShortCut(Ord('U'), [ssCtrl, ssAlt])], UpperWord, nil);
end;

procedure TDemoKeyBinding.InsertDate(const Context: IOTAKeyContext; KeyCode: TShortcut;
  var BindingResult: TKeyBindingResult);
begin
  if Context.EditBuffer <> nil then
    Context.EditBuffer.EditPosition.InsertText('// ' + DateTimeToStr(Now));
  BindingResult := krHandled;
end;

{ the word at the cursor: its start found with RipText backwards, then the block over it }
procedure TDemoKeyBinding.UpperWord(const Context: IOTAKeyContext; KeyCode: TShortcut;
  var BindingResult: TKeyBindingResult);
var
  P: IOTAEditPosition;
  V: IOTAEditView;
  Before, After: string;
  Row, Col: Integer;
begin
  BindingResult := krHandled;
  if Context.EditBuffer = nil then Exit;
  V := Context.EditBuffer.TopView;
  P := Context.EditBuffer.EditPosition;
  Before := P.RipText(['A'..'Z', 'a'..'z', '0'..'9', '_'], rfBackward);
  After := P.RipText(['A'..'Z', 'a'..'z', '0'..'9', '_'], 0);
  if Before + After = '' then Exit;
  Row := P.Row;
  Col := P.Column - Length(Before);
  P.Move(Row, Col);
  V.Block.BeginBlock;
  P.Move(Row, Col + Length(Before + After));
  V.Block.EndBlock;
  V.Block.UpperCase;
end;

{ ---------------------------------------------------------------- the expert }

type
  TDemoExpert = class(TNotifierObject, IOTANotifier, IOTAWizard)
  private
    FMenu: TMenuItem;
    FViewItem: TMenuItem;            // View | OTA Demo Window
    FButton: TToolButton;
    FActions: TList;
    FImage: Integer;
    FIdeNotifier, FDebugNotifier, FMessageNotifier, FBinding: Integer;
    FWatched: TStringList;           // modules with a notifier of the demo (Objects: its index)
    FTracked: TStringList;           // buffers with a tracker notifier
    FToDoManager: IOTAToDoManager;   // the demo's To-Do manager while it is registered ...
    FToDoIndex: Integer;             // ... its index (-1: none)
    FToDoNotifier: Integer;          // the To-Do List's notifier (-1: none)
    FCIManager: IOTACodeInsightManager;   // the demo's code insight manager while it is registered ...
    FCIIndex: Integer;               // ... its index (-1: none)
    FServices2: TDemoServices2;      // OTA Demo | More Services (OtaDemoServices2)
    function NewAction(const ACaption: string; Handler: TNotifyEvent): TAction;
    procedure AddItem(A: TAction);
    procedure IdeInfo(Sender: TObject);
    procedure ListModules(Sender: TObject);
    procedure ProjectInfo(Sender: TObject);
    procedure AddResource(Sender: TObject);
    procedure InsertHeader(Sender: TObject);
    procedure WriterInsert(Sender: TObject);
    procedure UpperSelection(Sender: TObject);
    procedure CountText(Sender: TObject);
    procedure FindTodo(Sender: TObject);
    procedure TrackLine(Sender: TObject);
    procedure FormComponents(Sender: TObject);
    procedure AddButton(Sender: TObject);
    procedure NewUnit(Sender: TObject);
    procedure WatchModule(Sender: TObject);
    procedure CompileProject(Sender: TObject);
    procedure BreakpointHere(Sender: TObject);
    procedure DebuggerState(Sender: TObject);
    procedure MenuNames(Sender: TObject);
    procedure EditWindowInfo(Sender: TObject);
    procedure PaletteInfo(Sender: TObject);
    procedure PaletteButton(Sender: TObject);
    procedure ShowWindow(Sender: TObject);
    procedure SelfTest(Sender: TObject);
    procedure ClearMessages(Sender: TObject);
    function NewSubMenu(const ACaption: string): TMenuItem;
    procedure AddSubItem(Menu: TMenuItem; A: TAction);
    procedure ToDoAddManager(Sender: TObject);
    procedure ToDoRemoveManager(Sender: TObject);
    procedure ToDoUpdateList(Sender: TObject);
    procedure ToDoListItems(Sender: TObject);
    procedure ToDoAddNotifier(Sender: TObject);
    procedure ToDoRemoveNotifier(Sender: TObject);
    procedure ToDoCallLog(Sender: TObject);
    procedure CIListManagers(Sender: TObject);
    procedure CITogglePascal(Sender: TObject);
    procedure CIRegister(Sender: TObject);
    procedure CIUnregister(Sender: TObject);
    procedure CINewFile(Sender: TObject);
    procedure CICompletion(Sender: TObject);
    procedure CIParameters(Sender: TObject);
    procedure CIQueryContext(Sender: TObject);
    procedure CICancel(Sender: TObject);
    procedure CIToggleMulti(Sender: TObject);
    procedure CICallLog(Sender: TObject);
    procedure MainFormCreated(Sender: TObject);
    procedure MainFormShown(Sender: TObject);
    function CurrentFormEditor: IOTAFormEditor;
  public
    constructor Create;
    destructor Destroy; override;
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  end;

{ the image of the tool button: a blue square with a yellow O, fuchsia is transparent }
function DemoBitmap: TBitmap;
begin
  Result := TBitmap.Create;
  Result.Width := 16;
  Result.Height := 16;
  with Result.Canvas do
  begin
    Brush.Color := clFuchsia;
    FillRect(Rect(0, 0, 16, 16));
    Brush.Color := clNavy;
    Pen.Color := clNavy;
    RoundRect(1, 1, 15, 15, 4, 4);
    Pen.Color := clYellow;
    Pen.Width := 2;
    Brush.Style := bsClear;
    Ellipse(4, 4, 12, 12);
  end;
end;

constructor TDemoExpert.Create;
var
  NTA: INTAServices;
  Bmp: TBitmap;
  Help, After, View, Sub: TMenuItem;
  Bar: TToolBar;
  Info: TAction;
begin
  inherited Create;
  FActions := TList.Create;
  FWatched := TStringList.Create;
  FTracked := TStringList.Create;
  DemoGroup := Msgs.AddMessageGroup('OTA Demo');
  EditorMenu := TDemoEditorMenu.Create(nil);
  EditorMenu.Hook;
  FMessageNotifier := Msgs.AddNotifier(TDemoMessageNotifier.Create);
  FIdeNotifier := (BorlandIDEServices as IOTAServices).AddNotifier(TDemoIdeNotifier.Create);
  FDebugNotifier := (BorlandIDEServices as IOTADebuggerServices).AddNotifier(TDemoDebugNotifier.Create);
  FBinding := (BorlandIDEServices as IOTAKeyboardServices).AddKeyboardBinding(TDemoKeyBinding.Create);
  NTA := BorlandIDEServices as INTAServices;
  Bmp := DemoBitmap;
  try
    FImage := NTA.AddMasked(Bmp, clFuchsia, 'D7Studio.OtaDemo.Image');
  finally
    Bmp.Free;
  end;
  { the menu, before Help: the item Delphi 7 names HelpMenu }
  FMenu := TMenuItem.Create(nil);
  FMenu.Name := 'OtaDemoMenu';       // a name of its own: other experts find it as it finds Delphi's
  FMenu.Caption := 'OTA &Demo';
  Help := FindMenuItem(NTA.MainMenu.Items, 'HelpMenu');
  if (Help <> nil) and (Help.Parent = NTA.MainMenu.Items) then NTA.MainMenu.Items.Insert(Help.MenuIndex, FMenu)
  else NTA.MainMenu.Items.Add(FMenu);
  { the dockable window: its class and variable told to the IDE's desktop, the window made; the
    main window's created and shown events }
  RegisterDemoWindow;
  if Assigned(AddMainFormCreatedEvent) then AddMainFormCreatedEvent(MainFormCreated);
  if Assigned(AddMainFormShownEvent) then AddMainFormShownEvent(MainFormShown);
  { View | OTA Demo Window, after Window List... (ViewWindowListItem); else at the end of View
    (ViewsMenu) }
  FViewItem := TMenuItem.Create(nil);
  FViewItem.Name := 'OtaDemoWindowItem';
  FViewItem.Action := NewAction('OTA Demo &Window', ShowWindow);
  After := FindMenuItem(NTA.MainMenu.Items, 'ViewWindowListItem');
  if After <> nil then After.Parent.Insert(After.MenuIndex + 1, FViewItem)
  else
  begin
    View := FindMenuItem(NTA.MainMenu.Items, 'ViewsMenu');
    if View <> nil then View.Add(FViewItem)
    else Say('The IDE has no menu item ViewsMenu: View | OTA Demo Window is missing.');
  end;
  Info := NewAction('&IDE information', IdeInfo);
  Info.ImageIndex := FImage;
  AddItem(Info);
  AddItem(NewAction('&Modules', ListModules));
  AddItem(NewAction('&Project', ProjectInfo));
  AddItem(NewAction('Add RCDATA resource OTADEMO to the project', AddResource));
  AddItem(nil);
  AddItem(NewAction('Insert &header comment', InsertHeader));
  AddItem(NewAction('Insert line with undoable &writer', WriterInsert));
  AddItem(NewAction('&Upper case selection', UpperSelection));
  AddItem(NewAction('&Count lines and words', CountText));
  AddItem(NewAction('&Find TODO', FindTodo));
  AddItem(NewAction('&Track this line and set bookmark 1', TrackLine));
  AddItem(nil);
  AddItem(NewAction('Form &components', FormComponents));
  AddItem(NewAction('Add a &button to the form', AddButton));
  AddItem(nil);
  AddItem(NewAction('New demo &unit', NewUnit));
  AddItem(NewAction('Watch current m&odule', WatchModule));
  AddItem(NewAction('Compile &project', CompileProject));
  AddItem(NewAction('Breakpoint at cursor', BreakpointHere));
  AddItem(NewAction('Debugger &state', DebuggerState));
  AddItem(nil);
  AddItem(NewAction('Main menu &names', MenuNames));
  AddItem(NewAction('&Edit window', EditWindowInfo));
  AddItem(NewAction('Component pa&lette', PaletteInfo));
  AddItem(NewAction('Place a &Button with the next click', PaletteButton));
  AddItem(FViewItem.Action as TAction);
  AddItem(nil);
  { the To-Do List's and code insight's services (IOTAToDoServices, IOTACodeInsightServices) }
  FToDoIndex := -1;
  FToDoNotifier := -1;
  FCIIndex := -1;
  Sub := NewSubMenu('&To-Do');
  AddSubItem(Sub, NewAction('&Add manager', ToDoAddManager));
  AddSubItem(Sub, NewAction('&Remove manager', ToDoRemoveManager));
  AddSubItem(Sub, NewAction('&Update list', ToDoUpdateList));
  AddSubItem(Sub, NewAction('&List items', ToDoListItems));
  AddSubItem(Sub, nil);
  AddSubItem(Sub, NewAction('Add &notifier', ToDoAddNotifier));
  AddSubItem(Sub, NewAction('Remove n&otifier', ToDoRemoveNotifier));
  AddSubItem(Sub, NewAction('&Call log', ToDoCallLog));
  Sub := NewSubMenu('Code &Insight');
  AddSubItem(Sub, NewAction('&List managers', CIListManagers));
  AddSubItem(Sub, NewAction('&Toggle Pascal manager', CITogglePascal));
  AddSubItem(Sub, NewAction('&Register demo manager', CIRegister));
  AddSubItem(Sub, NewAction('&Unregister demo manager', CIUnregister));
  AddSubItem(Sub, NewAction('&New demo file', CINewFile));
  AddSubItem(Sub, nil);
  AddSubItem(Sub, NewAction('Invoke &completion', CICompletion));
  AddSubItem(Sub, NewAction('Invoke &parameters', CIParameters));
  AddSubItem(Sub, NewAction('&Query context test', CIQueryContext));
  AddSubItem(Sub, NewAction('C&ancel', CICancel));
  AddSubItem(Sub, NewAction('Toggle &multi-select', CIToggleMulti));
  AddSubItem(Sub, NewAction('Call l&og', CICallLog));
  { highlighters, tools filters, type library modules, additional files, file systems, keystroke
    macros, speed settings, messages with children (OtaDemoServices2) }
  FServices2 := TDemoServices2.Create;
  Sub := NewSubMenu('More &Services');
  AddSubItem(Sub, NewAction('Register or remove the &highlighter of *.otaini', FServices2.ToggleHighlighter));
  AddSubItem(Sub, NewAction('Run the tools &filter', FServices2.RunFilter));
  AddSubItem(Sub, NewAction('&Type library modules', FServices2.TypeLibModules));
  AddSubItem(Sub, NewAction('New unit with &additional files', FServices2.NewAdditionalUnit));
  AddSubItem(Sub, nil);
  AddSubItem(Sub, NewAction('Open the &memory file system''s file', FServices2.OpenMemoryFile));
  AddSubItem(Sub, NewAction('Memory file system''s call &log', FServices2.MemoryLog));
  AddSubItem(Sub, nil);
  AddSubItem(Sub, NewAction('Show the current &keystroke record', FServices2.ShowMacro));
  AddSubItem(Sub, NewAction('&Play a copy of the current record', FServices2.PlayMacroCopy));
  AddSubItem(Sub, nil);
  AddSubItem(Sub, NewAction('&Speed settings', FServices2.SpeedSettingsList));
  AddSubItem(Sub, NewAction('Add or remove the demo''s spee&d setting', FServices2.ToggleSpeedSetting));
  AddSubItem(Sub, NewAction('Message with &children', FServices2.MessageWithChildren));
  AddItem(nil);
  AddItem(NewAction('Run &self-test', SelfTest));
  AddItem(NewAction('Clear demo messages', ClearMessages));
  { a button on the standard tool bar }
  Bar := NTA.ToolBar[sStandardToolBar];
  if Bar <> nil then
  begin
    FButton := TToolButton.Create(nil);
    FButton.Left := Bar.Width;           // at the end of the bar
    FButton.Parent := Bar;
    FButton.Action := Info;
  end;
  Say('OTA Demo is installed: see the menu OTA Demo.');
  StartSelfTestWhenReady;
end;

destructor TDemoExpert.Destroy;
var
  I: Integer;
begin
  StopSelfTest;
  FreeAndNil(EditorMenu);
  FreeAndNil(FServices2);
  if FToDoIndex >= 0 then ToDoServices.RemoveManager(FToDoIndex);
  if FToDoNotifier >= 0 then ToDoServices.RemoveNotifier(FToDoNotifier);
  if FCIIndex >= 0 then CIServices.RemoveCodeInsightManager(FCIIndex);
  FToDoManager := nil;
  FCIManager := nil;
  FButton.Free;
  FMenu.Free;
  FViewItem.Free;
  if Assigned(RemoveMainFormCreatedEvent) then RemoveMainFormCreatedEvent(MainFormCreated);
  if Assigned(RemoveMainFormShownEvent) then RemoveMainFormShownEvent(MainFormShown);
  UnregisterDemoWindow;
  for I := FActions.Count - 1 downto 0 do TObject(FActions[I]).Free;
  FActions.Free;
  (BorlandIDEServices as IOTAKeyboardServices).RemoveKeyboardBinding(FBinding);
  (BorlandIDEServices as IOTADebuggerServices).RemoveNotifier(FDebugNotifier);
  (BorlandIDEServices as IOTAServices).RemoveNotifier(FIdeNotifier);
  { the notifiers on modules and line trackers that are still registered (Remove takes each out
    of its list first) }
  while FWatched.Count > 0 do TDemoModuleNotifier(FWatched.Objects[0]).Remove;
  while FTracked.Count > 0 do TDemoLineNotifier(FTracked.Objects[0]).Remove;
  FWatched.Free;
  FTracked.Free;
  Msgs.RemoveNotifier(FMessageNotifier);
  Msgs.RemoveMessageGroup(DemoGroup);
  DemoGroup := nil;
  inherited;
end;

function TDemoExpert.NewAction(const ACaption: string; Handler: TNotifyEvent): TAction;
begin
  Result := TAction.Create(nil);
  Result.Caption := ACaption;
  Result.Category := DemoCategory;
  Result.OnExecute := Handler;
  Result.ActionList := (BorlandIDEServices as INTAServices).ActionList;
  FActions.Add(Result);
end;

{ an item of the menu for A (nil: a line) }
procedure TDemoExpert.AddItem(A: TAction);
var
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(FMenu);
  if A = nil then Item.Caption := '-' else Item.Action := A;
  FMenu.Add(Item);
end;

function TDemoExpert.GetIDString: string;
begin
  Result := 'D7Studio.OtaDemo';
end;

function TDemoExpert.GetName: string;
begin
  Result := 'OTA Demo';
end;

function TDemoExpert.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TDemoExpert.Execute;
begin
end;

{ IOTAServices, the environment options, IOTAPackageServices, INTAServices, the editor and the
  keyboard services }
procedure TDemoExpert.IdeInfo(Sender: TObject);
var
  S: IOTAServices;
  P: IOTAPackageServices;
  NTA: INTAServices;
  E: IOTAEditorServices;
  O: IOTAEditOptions;
  K: IOTAKeyboardServices;
  Parent: Pointer;
  I: Integer;
begin
  Title('IDE information');
  S := BorlandIDEServices as IOTAServices;
  Say('Product: ' + S.GetProductIdentifier + ', designer: ' + S.GetActiveDesignerType);
  Say('Registry key: HKEY_CURRENT_USER' + S.GetBaseRegistryKey);
  Say('Root: ' + S.GetRootDirectory + ', Bin: ' + S.GetBinDirectory);
  Say('Templates: ' + S.GetTemplateDirectory);
  if S.GetEnvironmentOptions <> nil then
    Say('Library path: ' + S.GetEnvironmentOptions.Values['LibraryPath']);
  P := BorlandIDEServices as IOTAPackageServices;
  Parent := Say(Format('%d packages loaded', [P.PackageCount]));
  for I := 0 to P.PackageCount - 1 do
    Say(Format('%s: %d components', [P.PackageNames[I], P.ComponentCount[I]]), Parent);
  NTA := BorlandIDEServices as INTAServices;
  Say(Format('Main menu: %d menus, action list: %d actions, image list: %d images',
    [NTA.MainMenu.Items.Count, NTA.ActionList.ActionCount, NTA.ImageList.Count]));
  E := BorlandIDEServices as IOTAEditorServices;
  O := E.EditOptions;
  if O <> nil then
    Say(Format('Editor: %s %d pt, block indent %d, tab stops "%s"',
      [O.FontName, O.FontSize, O.BlockIndent, O.BufferOptions.TabStops]));
  Parent := Say(Format('%d source file types', [E.EditOptionsCount]));
  for I := 0 to E.EditOptionsCount - 1 do
    Say(E.EditorOptions[I].IDString + ': ' + E.EditorOptions[I].Extensions, Parent);
  K := BorlandIDEServices as IOTAKeyboardServices;
  Say(Format('Keys handled by the experts'' bindings so far: %d', [K.KeysProcessed]));
end;

{ IOTAModuleServices: the open modules and their editors }
procedure TDemoExpert.ListModules(Sender: TObject);
var
  Mods: IOTAModuleServices;
  M: IOTAModule;
  E: IOTAEditor;
  I, J: Integer;
  Kind, EdKind: string;
  Parent: Pointer;
  Cur: IOTAModule;
begin
  Title('Modules');
  Mods := BorlandIDEServices as IOTAModuleServices;
  Cur := Mods.CurrentModule;
  for I := 0 to Mods.ModuleCount - 1 do
  begin
    M := Mods.Modules[I];
    if Supports(M, IOTAProjectGroup) then Kind := 'project group'
    else if Supports(M, IOTAProject) then Kind := 'project'
    else Kind := 'module';
    if (Cur <> nil) and (M.FileName = Cur.FileName) then Kind := Kind + ', current';
    Parent := SayAt(M.FileName, 1, Format('%s (%s, %d files)', [ExtractFileName(M.FileName), Kind,
      M.ModuleFileCount]));
    for J := 0 to M.ModuleFileCount - 1 do
    begin
      E := M.ModuleFileEditors[J];
      if E = nil then Continue;
      if Supports(E, IOTAFormEditor) then EdKind := 'form editor'
      else if Supports(E, IOTAProjectResource) then EdKind := 'resource file'
      else if Supports(E, IOTASourceEditor) then
        EdKind := Format('source editor, %d lines', [(E as IOTASourceEditor).GetLinesInBuffer])
      else EdKind := 'editor';
      if E.Modified then EdKind := EdKind + ', modified';
      SayAt(E.FileName, 1, ExtractFileName(E.FileName) + ': ' + EdKind, Parent);
    end;
  end;
end;

{ IOTAProject: its options, units and resource file }
procedure TDemoExpert.ProjectInfo(Sender: TObject);
var
  P: IOTAProject;
  O: IOTAProjectOptions;
  Info: IOTAModuleInfo;
  R: IOTAProjectResource;
  E: IOTAResourceEntry;
  I, J: Integer;
  Parent: Pointer;
begin
  Title('Project');
  P := GetActiveProject;
  if P = nil then
  begin
    Say('No project is open.');
    Exit;
  end;
  SayAt(P.FileName, 1, 'Active project: ' + ExtractFileName(P.FileName));
  O := P.ProjectOptions;
  Say('Output folder: ' + VarToStr(O.Values['OutputDir']) + ', units: ' + VarToStr(O.Values['UnitOutputDir']));
  Say('Search path: ' + VarToStr(O.Values['UnitDir']) + ', defines: ' + VarToStr(O.Values['Defines']));
  Say(Format('Version %s.%s.%s.%s, range checks %s, optimization %s', [VarToStr(O.Values['MajorVersion']),
    VarToStr(O.Values['MinorVersion']), VarToStr(O.Values['Release']), VarToStr(O.Values['Build']),
    VarToStr(O.Values['RangeChecks']), VarToStr(O.Values['Optimization'])]));
  Parent := Say(Format('%d modules', [P.GetModuleCount]));
  for I := 0 to P.GetModuleCount - 1 do
  begin
    Info := P.GetModule(I);
    if Info.FormName <> '' then SayAt(Info.FileName, 1, Info.Name + ' (form ' + Info.FormName + ')', Parent)
    else SayAt(Info.FileName, 1, Info.Name, Parent);
  end;
  for I := 0 to P.ModuleFileCount - 1 do
    if Supports(P.ModuleFileEditors[I], IOTAProjectResource, R) then
    begin
      Parent := Say(Format('%s: %d resources', [ExtractFileName(R.FileName), R.GetEntryCount]));
      for J := 0 to R.GetEntryCount - 1 do
      begin
        E := R.GetEntry(J);
        Say(Format('type %s, name %s, %d bytes', [ResId(E.GetResourceType), ResId(E.GetResourceName),
          E.DataSize]), Parent);
      end;
      Break;
    end;
end;

{ IOTAProjectResource.CreateEntry: an RCDATA resource the program can read (FindResource) }
procedure TDemoExpert.AddResource(Sender: TObject);
const
  Data = 'Written by the D7 Studio OTA demo';
var
  P: IOTAProject;
  R: IOTAProjectResource;
  E: IOTAResourceEntry;
  I: Integer;
begin
  Title('Project resource');
  P := GetActiveProject;
  if P = nil then
  begin
    Say('No project is open.');
    Exit;
  end;
  for I := 0 to P.ModuleFileCount - 1 do
    if Supports(P.ModuleFileEditors[I], IOTAProjectResource, R) then
    begin
      if R.FindEntry(RT_RCDATA, 'OTADEMO') <> nil then
      begin
        Say(R.FileName + ' has OTADEMO already.');
        Exit;
      end;
      E := R.CreateEntry(RT_RCDATA, 'OTADEMO', $1030, $0409, 0, 0, 0);
      E.DataSize := Length(Data);
      Move(Data[1], E.GetData^, Length(Data));
      R.MarkModified;
      Say('OTADEMO added to ' + R.FileName);
      Exit;
    end;
end;

{ IOTAEditPosition: a comment as the first line }
procedure TDemoExpert.InsertHeader(Sender: TObject);
var
  V: IOTAEditView;
  P: IOTAEditPosition;
begin
  Title('Edit position');
  V := TopView;
  if V = nil then Exit;
  P := V.Position;
  P.Move(1, 1);
  P.InsertText('{ ' + ExtractFileName(V.Buffer.FileName) + ', ' + DateTimeToStr(Now) +
    ' - inserted by the OTA demo }'#13#10);
  V.MoveViewToCursor;
  V.Paint;
  SayAt(V.Buffer.FileName, 1, 'Header comment inserted.');
end;

{ IOTAEditWriter: a line before the cursor's line, as one undo step }
procedure TDemoExpert.WriterInsert(Sender: TObject);
var
  V: IOTAEditView;
  W: IOTAEditWriter;
  C: TOTACharPos;
  Line: Integer;
begin
  Title('Edit writer');
  V := TopView;
  if V = nil then Exit;
  Line := V.CursorPos.Line;
  C.Line := Line;
  C.CharIndex := 0;
  W := V.Buffer.CreateUndoableWriter;
  W.CopyTo(V.CharPosToPos(C));
  W.Insert(PChar('// written by IOTAEditWriter'#13#10));
  W := nil;
  SayAt(V.Buffer.FileName, Line, 'Line inserted by the writer (Edit | Undo takes it back).');
end;

{ IOTAEditBlock }
procedure TDemoExpert.UpperSelection(Sender: TObject);
var
  V: IOTAEditView;
  B: IOTAEditBlock;
begin
  Title('Edit block');
  V := TopView;
  if V = nil then Exit;
  B := V.Block;
  if not B.IsValid then
  begin
    Say('Select some text first.');
    Exit;
  end;
  SayAt(V.Buffer.FileName, B.StartingRow, Format('Block %d,%d - %d,%d (%d bytes): "%s"',
    [B.StartingRow, B.StartingColumn, B.EndingRow, B.EndingColumn, B.Size, Copy(B.Text, 1, 40)]));
  B.UpperCase;
end;

{ IOTAEditReader: the whole buffer, in pieces }
procedure TDemoExpert.CountText(Sender: TObject);
var
  V: IOTAEditView;
  R: IOTAEditReader;
  Buf: array[0..4095] of Char;
  N, Pos, I, Lines, Words, Bytes: Integer;
  InWord: Boolean;
begin
  Title('Edit reader');
  V := TopView;
  if V = nil then Exit;
  R := V.Buffer.CreateReader;
  Pos := 0;
  Lines := 1;
  Words := 0;
  Bytes := 0;
  InWord := False;
  repeat
    N := R.GetText(Pos, Buf, SizeOf(Buf));
    for I := 0 to N - 1 do
    begin
      if Buf[I] = #10 then Inc(Lines);
      if Buf[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_'] then
      begin
        if not InWord then Inc(Words);
        InWord := True;
      end
      else
        InWord := False;
    end;
    Inc(Pos, N);
    Inc(Bytes, N);
  until N = 0;
  SayAt(V.Buffer.FileName, 1, Format('%s: %d lines, %d words, %d bytes',
    [ExtractFileName(V.Buffer.FileName), Lines, Words, Bytes]));
end;

{ IOTAEditPosition.Search }
procedure TDemoExpert.FindTodo(Sender: TObject);
var
  V: IOTAEditView;
  Err: Integer;
begin
  Title('Search');
  V := TopView;
  if V = nil then Exit;
  if V.Position.Search('TODO', False, False, False, sdForward, Err) then
  begin
    V.MoveViewToCursor;
    SayAt(V.Buffer.FileName, V.CursorPos.Line, 'TODO found');
  end
  else
    Say('No TODO after the cursor: ' + V.Position.GetSearchErrorString(Err));
end;

{ IOTAEditLineTracker and the bookmarks of IOTAEditView }
procedure TDemoExpert.TrackLine(Sender: TObject);
var
  V: IOTAEditView;
  T: IOTAEditLineTracker;
  F: string;
begin
  Title('Line tracker');
  V := TopView;
  if V = nil then Exit;
  F := V.Buffer.FileName;
  T := V.Buffer.GetEditLineTracker;
  T.AddLine(V.CursorPos.Line, V.CursorPos.Line);
  if FTracked.IndexOf(F) < 0 then TDemoLineNotifier.Create(T, F, FTracked);
  V.BookmarkRecord(1);
  SayAt(F, V.CursorPos.Line, Format('Line %d tracked (%d lines tracked), bookmark 1 at line %d',
    [V.CursorPos.Line, T.Count, V.BookmarkPos[1].Line]));
end;

function TDemoExpert.CurrentFormEditor: IOTAFormEditor;
var
  M: IOTAModule;
  I: Integer;
begin
  Result := nil;
  M := (BorlandIDEServices as IOTAModuleServices).CurrentModule;
  if M = nil then Exit;
  for I := 0 to M.ModuleFileCount - 1 do
    if Supports(M.ModuleFileEditors[I], IOTAFormEditor, Result) then Exit;
end;

{ IOTAFormEditor, IOTAComponent, INTAFormEditor }
procedure TDemoExpert.FormComponents(Sender: TObject);
var
  F: IOTAFormEditor;
  Root, C: IOTAComponent;
  Parent: Pointer;
  I: Integer;
  Name: string;
  L, T: Integer;
begin
  Title('Form editor');
  F := CurrentFormEditor;
  if F = nil then
  begin
    Say('The current file has no form.');
    Exit;
  end;
  Root := F.GetRootComponent;
  Root.GetPropValueByName('Name', Name);
  Parent := SayAt(F.FileName, 1, Format('%s: %s, %d components, %d selected (designer: %s)',
    [Name, Root.GetComponentType, Root.GetComponentCount, F.GetSelCount,
    (F as INTAFormEditor).FormDesigner.GetRootClassName]));
  for I := 0 to Root.GetComponentCount - 1 do
  begin
    C := Root.GetComponent(I);
    C.GetPropValueByName('Name', Name);
    if C.IsTControl and C.GetPropValueByName('Left', L) and C.GetPropValueByName('Top', T) then
      Say(Format('%s: %s at %d, %d', [Name, C.GetComponentType, L, T]), Parent)
    else
      Say(Name + ': ' + C.GetComponentType, Parent);
  end;
end;

procedure TDemoExpert.AddButton(Sender: TObject);
var
  F: IOTAFormEditor;
  C: IOTAComponent;
  S, Name: string;
begin
  Title('Create component');
  F := CurrentFormEditor;
  if F = nil then
  begin
    Say('The current file has no form.');
    Exit;
  end;
  C := F.CreateComponent(F.GetCreateParent, 'TButton', 16, 16, 120, 25);
  if C = nil then
  begin
    Say('The button could not be made.');
    Exit;
  end;
  S := 'OTA demo';
  C.SetPropByName('Caption', S);
  C.Select(False);
  C.GetPropValueByName('Name', Name);
  SayAt(F.FileName, 1, Name + ' added to the form.');
end;

{ IOTAModuleServices.CreateModule with a module creator (OtaDemoCreators) }
procedure TDemoExpert.NewUnit(Sender: TObject);
var
  M: IOTAModule;
begin
  Title('Module creator');
  M := (BorlandIDEServices as IOTAModuleServices).CreateModule(TDemoUnitCreator.Create);
  if M <> nil then Say('New module: ' + M.FileName) else Say('No module was made.');
end;

{ IOTAModuleNotifier on the current module }
procedure TDemoExpert.WatchModule(Sender: TObject);
var
  M: IOTAModule;
begin
  Title('Module notifier');
  M := (BorlandIDEServices as IOTAModuleServices).CurrentModule;
  if M = nil then
  begin
    Say('No module is open.');
    Exit;
  end;
  if FWatched.IndexOf(M.FileName) >= 0 then
  begin
    Say(M.FileName + ' is watched already.');
    Exit;
  end;
  TDemoModuleNotifier.Create(M, FWatched);
  SayAt(M.FileName, 1, 'Watching ' + ExtractFileName(M.FileName) + ': save it, change it, close it.');
end;

{ IOTAProjectBuilder }
procedure TDemoExpert.CompileProject(Sender: TObject);
var
  P: IOTAProject;
begin
  Title('Project builder');
  P := GetActiveProject;
  if P = nil then
  begin
    Say('No project is open.');
    Exit;
  end;
  if P.ProjectBuilder.BuildProject(cmOTAMake, False) then Say(ExtractFileName(P.FileName) + ' compiled.')
  else Say(ExtractFileName(P.FileName) + ' did not compile.');
end;

{ IOTADebuggerServices: a source breakpoint, the breakpoints }
procedure TDemoExpert.BreakpointHere(Sender: TObject);
var
  V: IOTAEditView;
  D: IOTADebuggerServices;
  B: IOTASourceBreakpoint;
  Parent: Pointer;
  I: Integer;
begin
  Title('Breakpoints');
  V := TopView;
  if V = nil then Exit;
  D := BorlandIDEServices as IOTADebuggerServices;
  D.NewSourceBreakpoint(V.Buffer.FileName, V.CursorPos.Line, nil);
  Parent := Say(Format('%d source breakpoints, %d address breakpoints', [D.SourceBkptCount, D.AddressBkptCount]));
  for I := 0 to D.SourceBkptCount - 1 do
  begin
    B := D.SourceBkpts[I];
    SayAt(B.FileName, B.LineNumber, Format('line %d, enabled %s', [B.LineNumber, BoolToStr(B.Enabled, True)]), Parent);
  end;
  D.LogString('OTA Demo: a breakpoint was set', litDefault);
end;

{ IOTAProcess, IOTAThread: the stopped program }
procedure TDemoExpert.DebuggerState(Sender: TObject);
var
  D: IOTADebuggerServices;
  P: IOTAProcess;
  T: IOTAThread;
  I: Integer;
  Parent: Pointer;
  F, Expr: string;
  Line: Integer;
  Res: array[0..1023] of Char;
  CanModify: Boolean;
  Addr, Size, Val: LongWord;
begin
  Title('Debugger');
  D := BorlandIDEServices as IOTADebuggerServices;
  P := D.CurrentProcess;
  if P = nil then
  begin
    Say('No program is being debugged (Run | Run starts one).');
    Exit;
  end;
  Say(Format('Process %d, %d threads', [P.ProcessId, P.ThreadCount]));
  T := P.CurrentThread;
  if (T = nil) or (T.State <> tsStopped) then
  begin
    Say('The program runs: pause it or let it stop at a breakpoint.');
    Exit;
  end;
  SayAt(T.CurrentFile, T.CurrentLine, Format('Thread %d stopped in %s at line %d',
    [T.GetOSThreadID, ExtractFileName(T.CurrentFile), T.CurrentLine]));
  Parent := Say(Format('Call stack: %d frames', [T.CallCount]));
  for I := 1 to T.CallCount do
  begin
    T.GetCallPos(I, F, Line);
    SayAt(F, Line, T.CallHeaders[I], Parent);
  end;
  Expr := 'Self';
  if InputQuery('OTA Demo', 'Evaluate:', Expr) and (Expr <> '') then
    if T.Evaluate(Expr, Res, SizeOf(Res), CanModify, False, nil, Addr, Size, Val) = erOK then
      Say(Expr + ' = ' + Res)
    else
      Say(Expr + ': ' + Res);
end;

{ INTAServices.MainMenu by its items' names and their actions' names: Delphi 7's, the names
  experts search for (ViewsMenu, FileOpenItem, FileOpenCommand ...) }
procedure TDemoExpert.MenuNames(Sender: TObject);

  procedure List(Item: TMenuItem; Parent: Pointer);
  var
    I: Integer;
    C: TMenuItem;
    S: string;
  begin
    for I := 0 to Item.Count - 1 do
    begin
      C := Item[I];
      if C.IsLine then Continue;
      S := C.Name + ' = ' + StripHotkey(C.Caption);
      if C.Action <> nil then S := S + ' (' + C.Action.Name + ')';
      List(C, Say(S, Parent));
    end;
  end;

begin
  Title('Main menu names');
  Say('Main form: ' + Application.MainForm.Name + ' (' + Application.MainForm.ClassName + ')');
  List((BorlandIDEServices as INTAServices).MainMenu.Items, nil);
end;

{ Delphi's component palette as experts read it, past the Open Tools API: the main form by its
  name, AppBuilder, then its TabControl (the pages) and its Palette (the tools of the page
  shown), driven through their published properties. D7 Studio keeps the two, hidden, for such
  experts. }
function DelphiPalette(out Tabs: TTabControl; out Palette: TControl): Boolean;
var
  AppBuilder: TComponent;
begin
  Tabs := nil;
  Palette := nil;
  AppBuilder := Application.FindComponent('AppBuilder');
  if AppBuilder <> nil then
  begin
    Tabs := AppBuilder.FindComponent('TabControl') as TTabControl;
    Palette := AppBuilder.FindComponent('Palette') as TControl;
  end;
  Result := (Tabs <> nil) and (Palette <> nil) and Assigned(Tabs.OnChange);
  if not Result then Say('The IDE has no AppBuilder with a TabControl and a Palette.');
end;

type
  TControlAccess = class(TControl);
  { Delphi's TCustomEditControl.GetTextAtLine (coreide70.bpl), as CnWizards declares and calls
    it: a line, 1-based, tabs as spaces }
  TGetTextAtLine = function(Self: TObject; LineNum: Integer): string;

{ Delphi's edit window as experts find it past the Open Tools API: the form in Screen.Forms (class
  TEditWindow, named EditWindow_N) and from INTAEditWindow.Form, its editor control (class
  TEditControl, named Editor) with its menu and the published properties experts read by RTTI,
  its file tabs (TabControl), and a routine of the editor control that experts call by its
  exported name in coreide70.bpl (CnWizards does) }
procedure TDemoExpert.EditWindowInfo(Sender: TObject);
const
  Props: array[0..6] of string = ('LineText', 'TopLine', 'LinesInWindow', 'LineCount', 'CaretX',
    'CaretY', 'CharXIndex');
var
  View: IOTAEditView;
  Form: TCustomForm;
  Ed, Tabs: TComponent;
  I: Integer;
  H: HMODULE;
  GetTextAtLine: TGetTextAtLine;

  function MenuName(C: TComponent): string;
  begin
    Result := '(none)';
    if (C is TControl) and (TControlAccess(C).PopupMenu <> nil) then
      Result := TControlAccess(C).PopupMenu.Name;
  end;

begin
  Title('Edit window');
  for I := 0 to Screen.FormCount - 1 do
    if (Pos('EditWindow_', Screen.Forms[I].Name) = 1) and Screen.Forms[I].ClassNameIs('TEditWindow') then
      Say(Format('Screen.Forms[%d]: %s: %s', [I, Screen.Forms[I].Name, Screen.Forms[I].ClassName]));
  View := TopView;
  if (View = nil) or (View.GetEditWindow = nil) then Exit;
  Form := View.GetEditWindow.Form;
  if Form = nil then
  begin
    Say('INTAEditWindow.Form is nil.');
    Exit;
  end;
  Say('INTAEditWindow.Form: ' + Form.Name + ': ' + Form.ClassName);
  Ed := Form.FindComponent('Editor');
  if Ed = nil then Say('It has no component named Editor.')
  else
  begin
    Say(Format('Editor: %s, its menu %s', [Ed.ClassName, MenuName(Ed)]));
    for I := Low(Props) to High(Props) do
      if GetPropInfo(Ed, Props[I]) <> nil then
        Say(Format('  %s = %s', [Props[I], VarToStr(GetPropValue(Ed, Props[I]))]));
  end;
  Tabs := Form.FindComponent('TabControl');
  if Tabs <> nil then Say(Format('TabControl: %s, its menu %s', [Tabs.ClassName, MenuName(Tabs)]));
  H := GetModuleHandle('coreide70.bpl');
  if H = 0 then Say('coreide70.bpl is not loaded.')
  else if (Ed <> nil) and (GetPropInfo(Ed, 'CaretY') <> nil) then
  begin
    @GetTextAtLine := GetProcAddress(H, '@Editors@TCustomEditControl@GetTextAtLine$qqri');
    if Assigned(GetTextAtLine) then
      Say('coreide70 TCustomEditControl.GetTextAtLine(CaretY): "' +
        GetTextAtLine(Ed, GetOrdProp(Ed, 'CaretY')) + '"');
  end;
end;

{ every page and tool: a page shown (TabIndex, then OnChange, as the palette's own clicks do),
  each tool chosen (SelectedIndex) and named (SelectedToolName); what was chosen comes back }
procedure TDemoExpert.PaletteInfo(Sender: TObject);
var
  Tabs: TTabControl;
  Palette: TControl;
  OldTab, OldTool, I, K, N: Integer;
  Parent: Pointer;
begin
  Title('Component palette (by name and RTTI, as experts read it)');
  if not DelphiPalette(Tabs, Palette) then Exit;
  OldTab := Tabs.TabIndex;
  OldTool := GetOrdProp(Palette, 'SelectedIndex');
  for I := 0 to Tabs.Tabs.Count - 1 do
  begin
    Tabs.TabIndex := I;
    Tabs.OnChange(Tabs);
    N := GetOrdProp(Palette, 'PalToolCount');
    Parent := Say(Format('%s: %d tools', [Tabs.Tabs[I], N]));
    for K := 0 to N - 1 do
    begin
      SetOrdProp(Palette, 'SelectedIndex', K);
      Say(GetStrProp(Palette, 'SelectedToolName'), Parent);
    end;
  end;
  Tabs.TabIndex := OldTab;
  Tabs.OnChange(Tabs);
  SetOrdProp(Palette, 'SelectedIndex', OldTool);
end;

{ TButton's tool chosen on the palette: the next click on a form places a button there, as
  CompBar has it placed when a component is dragged from its list. Its page stays shown, as
  after a click on the tool; without a TButton the page and the tool chosen before come back }
procedure TDemoExpert.PaletteButton(Sender: TObject);
var
  Tabs: TTabControl;
  Palette: TControl;
  OldTab, OldTool, I, K: Integer;
begin
  Title('Component palette: a Button with the next click');
  if not DelphiPalette(Tabs, Palette) then Exit;
  OldTab := Tabs.TabIndex;
  OldTool := GetOrdProp(Palette, 'SelectedIndex');
  for I := 0 to Tabs.Tabs.Count - 1 do
  begin
    Tabs.TabIndex := I;
    Tabs.OnChange(Tabs);
    for K := 0 to GetOrdProp(Palette, 'PalToolCount') - 1 do
    begin
      SetOrdProp(Palette, 'SelectedIndex', K);
      if GetStrProp(Palette, 'SelectedToolName') = 'TButton' then
      begin
        Say(Format('TButton chosen (page %s, tool %d): click on a form to place it.', [Tabs.Tabs[I], K]));
        Exit;
      end;
    end;
  end;
  Tabs.TabIndex := OldTab;
  Tabs.OnChange(Tabs);
  SetOrdProp(Palette, 'SelectedIndex', OldTool);
  Say('The palette has no TButton.');
end;

{ the dockable window (OtaDemoWin), shown with DeskUtil.FocusWindow }
procedure TDemoExpert.ShowWindow(Sender: TObject);
begin
  ShowDemoWindow;
end;

{ DeskUtil's main window events: sent once while the IDE starts }
procedure TDemoExpert.MainFormCreated(Sender: TObject);
begin
  DemoEvent('Main window created (DeskUtil.AddMainFormCreatedEvent): ' + Sender.ClassName);
end;

procedure TDemoExpert.MainFormShown(Sender: TObject);
begin
  DemoEvent('Main window shown (DeskUtil.AddMainFormShownEvent): ' + Sender.ClassName);
end;

{ OtaDemoTest: every service checked on a test project of its own }
procedure TDemoExpert.SelfTest(Sender: TObject);
begin
  RunSelfTest;
end;

{ ---------------------------------------------------------------- OTA Demo | To-Do, Code Insight }

function TDemoExpert.NewSubMenu(const ACaption: string): TMenuItem;
begin
  Result := TMenuItem.Create(FMenu);
  Result.Caption := ACaption;
  FMenu.Add(Result);
end;

procedure TDemoExpert.AddSubItem(Menu: TMenuItem; A: TAction);
var
  Item: TMenuItem;
begin
  Item := TMenuItem.Create(Menu);
  if A = nil then Item.Caption := '-' else Item.Action := A;
  Menu.Add(Item);
end;

{ the last lines of a call log }
procedure SayLog(L: TStrings);
var
  I, First: Integer;
begin
  First := L.Count - 60;
  if First < 0 then First := 0;
  if L.Count = 0 then Say('No calls yet.');
  for I := First to L.Count - 1 do Say(L[I]);
end;

{ the demo's manager (OtaDemoToDo): three items of kind 'OTA Demo' in the To-Do List }
procedure TDemoExpert.ToDoAddManager(Sender: TObject);
begin
  Title('To-Do List: add manager');
  if FToDoIndex >= 0 then
  begin
    Say(Format('The demo''s manager is registered already (index %d).', [FToDoIndex]));
    Exit;
  end;
  FToDoManager := TDemoToDoManager.Create('OtaDemo.ToDo', 'Demo');
  FToDoIndex := ToDoServices.AddManager(FToDoManager);
  Say(Format('AddManager: index %d. Its items come with the next collection (Update list, the list shown).',
    [FToDoIndex]));
end;

procedure TDemoExpert.ToDoRemoveManager(Sender: TObject);
begin
  Title('To-Do List: remove manager');
  if FToDoIndex < 0 then
  begin
    Say('The demo''s manager is not registered.');
    Exit;
  end;
  ToDoServices.RemoveManager(FToDoIndex);
  Say(Format('RemoveManager(%d).', [FToDoIndex]));
  FToDoIndex := -1;
  FToDoManager := nil;
end;

procedure TDemoExpert.ToDoUpdateList(Sender: TObject);
begin
  Title('To-Do List: update list');
  ToDoServices.UpdateList;
  Say(Format('UpdateList: %d items.', [ToDoServices.GetItemCount]));
end;

{ every item of the list, D7 Studio's own comments too }
procedure TDemoExpert.ToDoListItems(Sender: TObject);
const
  YesNo: array[Boolean] of string = ('no', 'yes');
var
  I: Integer;
  X: INTAToDoItem;
begin
  Title('To-Do List: items');
  Say(Format('GetItemCount: %d', [ToDoServices.GetItemCount]));
  for I := 0 to ToDoServices.GetItemCount - 1 do
  begin
    X := ToDoServices.GetItem(I);
    Say(Format('%d: %s | kind %s | module %s | priority %d | done %s | owner %s | category %s | data %d | valid %s',
      [I, Trim(X.GetText), X.GetKind, X.GetModuleName, X.GetPriority, YesNo[X.GetChecked], X.GetOwner,
      X.GetCategory, X.GetData, YesNo[X.IsValid]]));
  end;
end;

procedure TDemoExpert.ToDoAddNotifier(Sender: TObject);
begin
  Title('To-Do List: add notifier');
  if FToDoNotifier >= 0 then
  begin
    Say('The demo''s notifier is registered already.');
    Exit;
  end;
  FToDoNotifier := ToDoServices.AddNotifier(TDemoToDoNotifier.Create);
  Say(Format('AddNotifier: index %d (what it is told goes to the call log).', [FToDoNotifier]));
end;

procedure TDemoExpert.ToDoRemoveNotifier(Sender: TObject);
begin
  Title('To-Do List: remove notifier');
  if FToDoNotifier < 0 then
  begin
    Say('The demo''s notifier is not registered.');
    Exit;
  end;
  ToDoServices.RemoveNotifier(FToDoNotifier);
  Say(Format('RemoveNotifier(%d).', [FToDoNotifier]));
  FToDoNotifier := -1;
end;

procedure TDemoExpert.ToDoCallLog(Sender: TObject);
begin
  Title('To-Do List: the calls the demo''s objects got');
  SayLog(ToDoCalls);
end;

procedure TDemoExpert.CIListManagers(Sender: TObject);
var
  I: Integer;
  M: IOTACodeInsightManager;
begin
  Title('Code insight: managers');
  Say(Format('GetCodeInsightManagerCount: %d', [CIServices.GetCodeInsightManagerCount]));
  for I := 0 to CIServices.GetCodeInsightManagerCount - 1 do
  begin
    M := CIServices.GetCodeInsightManager(I);
    Say(Format('%d: %s | %s | enabled %s', [I, M.GetName, M.GetIDString, BoolToStr(M.GetEnabled, True)]));
  end;
end;

{ Delphi's Pascal manager (D7 Studio's own code insight) off or on again }
procedure TDemoExpert.CITogglePascal(Sender: TObject);
var
  I: Integer;
  M: IOTACodeInsightManager;
begin
  Title('Code insight: the Pascal manager');
  for I := 0 to CIServices.GetCodeInsightManagerCount - 1 do
  begin
    M := CIServices.GetCodeInsightManager(I);
    if M.GetIDString = 'Borland.CodeInsight.Pascal' then
    begin
      M.SetEnabled(not M.GetEnabled);
      Say(Format('Manager %d (%s) enabled: %s', [I, M.GetName, BoolToStr(M.GetEnabled, True)]));
      Exit;
    end;
  end;
  Say('There is no Pascal manager.');
end;

procedure TDemoExpert.CIRegister(Sender: TObject);
begin
  Title('Code insight: register the demo''s manager');
  if FCIIndex >= 0 then
  begin
    Say(Format('The demo''s manager is registered already (index %d).', [FCIIndex]));
    Exit;
  end;
  FCIManager := TDemoCIManager.Create;
  FCIIndex := CIServices.AddCodeInsightManager(FCIManager);
  Say(Format('AddCodeInsightManager: index %d. It handles the *%s files (New demo file): Ctrl+Space, "(" ' +
    'after Mix, a Ctrl+click, the hint of a word.', [FCIIndex, DemoCIExt]));
end;

procedure TDemoExpert.CIUnregister(Sender: TObject);
begin
  Title('Code insight: unregister the demo''s manager');
  if FCIIndex < 0 then
  begin
    Say('The demo''s manager is not registered.');
    Exit;
  end;
  CIServices.RemoveCodeInsightManager(FCIIndex);
  Say(Format('RemoveCodeInsightManager(%d).', [FCIIndex]));
  FCIIndex := -1;
  FCIManager := nil;
end;

{ a file for the demo's manager, opened }
procedure TDemoExpert.CINewFile(Sender: TObject);
var
  F: string;
  S: TStringList;
begin
  Title('Code insight: a demo file');
  F := TempFolder + 'OtaDemo' + DemoCIExt;
  S := TStringList.Create;
  try
    S.Add('Red: the colour of fire');
    S.Add('Navy: the sea at night');
    S.Add('Mix: two colours in one');
    S.Add('');
    S.Add('Type the start of a colour and press Ctrl+Space: Bl');
    S.Add('Mix(Red, Blue)');
    S.SaveToFile(F);
  finally
    S.Free;
  end;
  if (BorlandIDEServices as IOTAActionServices).OpenFile(F) then SayAt(F, 1, 'Opened ' + F)
  else Say('Cannot open ' + F);
end;

procedure TDemoExpert.CICompletion(Sender: TObject);
var
  V: IOTAEditView;
begin
  V := TopView;
  if V <> nil then (V as IOTAEditActions).CodeCompletion(csCodeList or csManual);
end;

procedure TDemoExpert.CIParameters(Sender: TObject);
var
  V: IOTAEditView;
begin
  V := TopView;
  if V <> nil then (V as IOTAEditActions).CodeCompletion(csParamList or csManual);
end;

{ SetQueryContext with the top view and Delphi's Pascal manager, and that manager's data at the view's
  cursor (D7 Studio's own code insight as Delphi's Pascal manager) }
procedure TDemoExpert.CIQueryContext(Sender: TObject);
var
  I: Integer;
  V, V2: IOTAEditView;
  M, Cur: IOTACodeInsightManager;
  Viewer: IOTACodeInsightViewer;
  SL: IOTACodeInsightSymbolList;
  S, Cn: string;
begin
  Title('Code insight: query context');
  V := TopView;
  if V = nil then Exit;
  { Delphi's Pascal manager - index 1 in Delphi 7, after its markup manager }
  M := nil;
  for I := 0 to CIServices.GetCodeInsightManagerCount - 1 do
    if CIServices.GetCodeInsightManager(I).GetIDString = 'Borland.CodeInsight.Pascal' then M := CIServices.GetCodeInsightManager(I);
  if M = nil then Exit;
  CIServices.SetQueryContext(V, M);
  try
    CIServices.GetEditView(V2);
    CIServices.GetCurrentCodeInsightManager(Cur);
    CIServices.GetViewer(Viewer);
    if Cur = nil then Cn := '(none)' else Cn := Cur.GetName;
    Say(Format('SetQueryContext(the top view, the Pascal manager): GetEditView is the view: %s, the current manager: %s, ' +
      'a viewer: %s', [BoolToStr(V2 <> nil, True), Cn, BoolToStr(Viewer <> nil, True)]));
    S := '';
    if M.InvokeCodeCompletion(itManual, S) then
    begin
      M.GetSymbolList(SL);
      if (SL <> nil) and (SL.Count > 0) then
        Say(Format('%s.InvokeCodeCompletion at the cursor: %d symbols for "%s", the first %s %s%s', [M.GetName, SL.Count,
          S, SL.SymbolClassText[0], SL.SymbolText[0], SL.SymbolTypeText[0]]));
    end
    else
      Say(M.GetName + '.InvokeCodeCompletion: nothing at the cursor.');
  finally
    CIServices.SetQueryContext(nil, nil);
  end;
end;

procedure TDemoExpert.CICancel(Sender: TObject);
begin
  CIServices.CancelCodeInsightProcessing;
end;

procedure TDemoExpert.CIToggleMulti(Sender: TObject);
begin
  Title('Code insight: multi-select');
  DemoMultiSelect := not DemoMultiSelect;
  Say('The demo''s list lets several rows be chosen (Space): ' + BoolToStr(DemoMultiSelect, True));
end;

procedure TDemoExpert.CICallLog(Sender: TObject);
begin
  Title('Code insight: the calls the demo''s manager got');
  SayLog(CICalls);
end;

procedure TDemoExpert.ClearMessages(Sender: TObject);
begin
  Msgs.ClearMessageGroup(DemoGroup);
end;

{ ---------------------------------------------------------------- Help | OTA Demo: About }

type
  TDemoMenuWizard = class(TNotifierObject, IOTANotifier, IOTAWizard, IOTAMenuWizard)
  public
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
    function GetMenuText: string;
  end;

function TDemoMenuWizard.GetIDString: string;
begin
  Result := 'D7Studio.OtaDemo.About';
end;

function TDemoMenuWizard.GetName: string;
begin
  Result := 'OTA Demo About';
end;

function TDemoMenuWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

function TDemoMenuWizard.GetMenuText: string;
begin
  Result := 'OTA Demo: &About...';
end;

procedure TDemoMenuWizard.Execute;
begin
  MessageDlg('The D7 Studio Open Tools API demo.'#13#10#13#10 +
    'Menu OTA Demo: one command per service of BorlandIDEServices; To-Do and Code Insight: the' +
    ' To-Do List''s and code insight''s services.'#13#10 +
    'View | OTA Demo Window: a dockable tool window (TDockableForm).'#13#10 +
    'File | New | Other | OTA Demo: a form wizard.'#13#10 +
    'Code editor: Ctrl+Alt+D inserts the date, Ctrl+Alt+U makes the word upper case.',
    mtInformation, [mbOK], 0);
end;

procedure Register;
begin
  RegisterPackageWizard(TDemoExpert.Create);
  RegisterPackageWizard(TDemoMenuWizard.Create);
  RegisterPackageWizard(TDemoFormWizard.Create);
end;

end.
