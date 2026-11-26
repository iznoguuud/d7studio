{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaCore;

{ D7 Studio - the base of the Open Tools API: what the IDE's services stand on.

  * TSdOtaHost: what the main window does for the Open Tools objects - its menu, actions, images
    and tool bar, its file pages, the project and the project group, compiling, the debugger. The
    main form implements it (SdMain, TOtaMainHost); without a host (a test program) every service
    answers "nothing" - no module, no menu.
  * TSdNotifierList: the notifiers and other interfaces the experts register. Their index is the
    one the expert gets back (Delphi's AddNotifier / RemoveNotifier): a removed entry leaves a hole,
    so the other indexes stay valid. Entries whose code lies in a package that is unloaded are
    dropped first (DropModule): nothing calls into an unloaded package.
  * Positions of the Open Tools API on a Scintilla editor: TOTACharPos (line 1-based, the bytes of
    the line before the place 0-based), TOTAEditPos (line and column 1-based, tabs expanded to
    their stops - the column the user sees) and linear buffer offsets (bytes from the start).
    The buffer is the editor's text as Scintilla holds it: a code-page file's bytes, UTF-8 for a
    Unicode file (Delphi 2005 and later read UTF-8 too).
  * OtaCaught: an expert's code that raised is logged (error.log) and the IDE goes on - whatever
    the class of the exception: a DLL expert built without run-time packages raises an Exception
    class of its own, which "on E: Exception" does not catch.
  * What the services share: the file page of an editor (OtaPageOfEditor), the loaded packages in
    Delphi's order (OtaPackageEntry). }

interface

uses
  SysUtils, Classes, Forms, Menus, ActnList, ImgList, ComCtrls, Dialogs, ToolsAPI,
  SdSciEdit, SdEditorPage, SdProject, SdProjectGroup, SdDebugUI, SdTodo, SdDesignHost;

type
  { what the main window does for the Open Tools objects }
  TSdOtaHost = class
  public
    { the main window and its parts (INTAServices, INTAEditWindow) }
    function MainForm: TCustomForm; virtual; abstract;
    function MainMenu: TMainMenu; virtual; abstract;
    function ActionList: TCustomActionList; virtual; abstract;
    function ImageList: TCustomImageList; virtual; abstract;
    function ToolBar(const Name: string): TToolBar; virtual; abstract;
    function StatusBar: TStatusBar; virtual; abstract;
    { the menu wizards' place (Delphi's: the Help menu) and the action list of their commands }
    function WizardMenu: TMenuItem; virtual; abstract;
    function WizardActions: TActionList; virtual; abstract;
    { a command of the main window by its action's name (FileSaveAllCommand ...); False: none, or disabled }
    function ExecuteAction(const Name: string): Boolean; virtual; abstract;
    { View as Text / View as Form of Page, as Delphi 7's IOTAEditActions.SwapSourceFormView does it:
      posted, it runs when the IDE next reads its messages }
    procedure SwapSourceFormLater(Page: TEditorPage); virtual; abstract;
    { a shortcut an enabled command of the main window's menus or actions has: Delphi's menus take such
      a key before an expert's binding of it in the code editor }
    function MenuShortCut(SC: TShortCut): Boolean; virtual; abstract;
    { the file pages }
    function PageCount: Integer; virtual; abstract;
    function Pages(Index: Integer): TEditorPage; virtual; abstract;
    function ActivePage: TEditorPage; virtual; abstract;
    function FindPage(const FileName: string): TEditorPage; virtual; abstract;
    function OpenFile(const FileName: string; Activate: Boolean): TEditorPage; virtual; abstract;
    { IOTAActionServices.OpenFile (Delphi's default open procedure): a project, a package or a
      project group in a group of its own (the open group closed first; File | Open alone opens a
      package beside the group), a type library in its view, any other file as a page; True: it is
      open then }
    function OpenAny(const FileName: string): Boolean; virtual; abstract;
    procedure ShowPage(Page: TEditorPage); virtual; abstract;
    procedure ShowFileLine(const FileName: string; Line, Col: Integer); virtual; abstract;
    function ClosePage(Page: TEditorPage; Prompt: Boolean): Boolean; virtual; abstract;
    { AskName: Save As (its dialog), else Save (an untitled page asks for its name anyway) }
    function SavePage(Page: TEditorPage; AskName: Boolean): Boolean; virtual; abstract;
    { Page under another name, nothing written (Delphi 7's IOTAModule.FileName): the page modified,
      the uses clauses of its projects follow unsaved }
    function RenamePage(Page: TEditorPage; const FileName: string): Boolean; virtual; abstract;
    { ... a project of the group or beside it: its entry, its source's page and its module follow }
    function RenameProject(P: TSdProject; const FileName: string): Boolean; virtual; abstract;
    { P, a project of the group, under another name: FileName, or asked for (''); its source
      renamed, its options and resources copied, the group's entry and P's module follow, the
      files stay open (False: P is no project of the group, or the user cancelled) }
    function SaveProjectAs(P: TSdProject; const FileName: string): Boolean; virtual; abstract;
    function SaveAll: Boolean; virtual; abstract;
    function CloseAll: Boolean; virtual; abstract;
    function ReloadPage(Page: TEditorPage): Boolean; virtual; abstract;
    { File | New | Other }
    function NewItemsDialog: Boolean; virtual; abstract;
    { a new module: FileName's source and form (Dfm '' none) - a page in memory under the name,
      written when it is saved, or an untitled page (Unnamed) -, added to the project (AddToProject)
      and shown }
    function NewModule(const FileName, Source, Dfm: string; Unnamed, AddToProject, ShowForm,
      ShowSource: Boolean): TEditorPage; virtual; abstract;
    { the same, added to Owner - a project of the group, active or not (nil: to none); NewModule's
      AddToProject is the active project }
    function NewModuleOf(Owner: TSdProject; const FileName, Source, Dfm: string; Unnamed, ShowForm,
      ShowSource: Boolean): TEditorPage; virtual; abstract;
    { a unit name and a root (form) name not used yet; Dir: the folder of the files }
    function UniqueUnitName(const Prefix: string): string; virtual; abstract;
    function UniqueRootName(const Prefix: string): string; virtual; abstract;
    function DefaultDir: string; virtual; abstract;
    { the active project and the project group - every project of it is loaded }
    function Project: TSdProject; virtual; abstract;
    function ProjectGroup: TSdProjectGroup; virtual; abstract;
    { a loaded project: of the group, or a package open beside it (nil: none, or a closed one) }
    function GroupProject(const FileName: string): TSdProject; virtual; abstract;
    { NewGroup: in a group of its own (the group before closed), else into the open group, whose
      files stay open }
    function OpenProject(const FileName: string; NewGroup: Boolean): Boolean; virtual; abstract;
    { another project of the group active (a closed one loaded again): every file stays open }
    procedure ActivateProject(const FileName: string); virtual; abstract;
    procedure AddNewProject; virtual; abstract;
    procedure AddExistingProject; virtual; abstract;
    { IOTAProjectGroup.RemoveProject: no question; as Delphi 7's (measured) the project stays a
      module beside the group, owned by no module, its units closed }
    procedure RemoveGroupProject(const FileName: string); virtual; abstract;
    { a project closed (IOTAModule.CloseModule): its own files closed - Force: unsaved ones without
      a question (Delphi 7's ForceClosed); one of the group stays in it, Activate loads it again; a
      package open beside the group goes }
    function CloseGroupProject(const FileName: string; Force: Boolean): Boolean; virtual; abstract;
    { the project group with every project and file }
    function CloseProject(Force: Boolean): Boolean; virtual; abstract;
    function CompileProject(P: TSdProject; Mode: TOTACompileMode; ClearMessages: Boolean): Boolean; virtual; abstract;
    { Project | Options of P, a project of the group }
    procedure EditProjectOptions(P: TSdProject); virtual; abstract;
    { the project's options were changed through the Open Tools API: written, applied }
    procedure ProjectOptionsChanged(P: TSdProject); virtual; abstract;
    { a unit into / out of the active project }
    function ProjectAddFile(const FileName: string): Boolean; virtual; abstract;
    function ProjectRemoveFile(const FileName: string): Boolean; virtual; abstract;
    { ... into / out of P, a project of the group }
    function ProjectAddFileTo(P: TSdProject; const FileName: string): Boolean; virtual; abstract;
    function ProjectRemoveFileFrom(P: TSdProject; const FileName: string): Boolean; virtual; abstract;
    { the text of a file as the IDE has it (an open page's, else the file's): editor text }
    function SourceOf(const FileName: string): string; virtual; abstract;
    { the Messages view shown (in its group's tab); Search Results emptied }
    procedure ShowMessages; virtual; abstract;
    procedure ClearSearchResults; virtual; abstract;
    { the debugger }
    function Debug: TDebugController; virtual; abstract;
    procedure DebugSourceDirs(Dirs: TStrings); virtual; abstract;
    { Exe debugged, stopped at its main block's begin (IOTADebuggerServices.CreateProcess) }
    procedure DebugRun(const Exe, Params: string); virtual; abstract;
    procedure DebugAttach(Pid: Cardinal); virtual; abstract;
    { the breakpoints changed (an expert set one): the editors' markers and the view follow }
    procedure BreakpointsChanged; virtual; abstract;
    { an expert's change of a project's resources was written into ResFile: the views of the
      file follow }
    procedure ResourcesWritten(const ResFile: string); virtual; abstract;
    { Tools | Editor Options were changed through the Open Tools API: the editors take them }
    procedure EditorOptionsChanged; virtual; abstract;
    { Tools | Environment Options were changed through the Open Tools API: written at the next idle }
    procedure EnvironmentOptionsChanged; virtual; abstract;
    { the compiler's next (Delta 1) or previous (-1) message with a place, shown in its file }
    function StepMessage(Delta: Integer): Boolean; virtual; abstract;
    { the To-Do List (SdOtaToDo): its items as the view shows them (filtered, sorted), the
      experts' items collected again and shown (IOTAToDoServices.UpdateList - later when the view
      is inside a call to an expert), the experts' items whose code lies in Module taken out at
      once (0: all of them; a package goes, the IDE ends) }
    function TodoList: TSdTodoList; virtual; abstract;
    procedure TodoExpertsChanged; virtual; abstract;
    procedure TodoDropModule(Module: HMODULE); virtual; abstract;
    { an item of D7 Studio's own (a copy of the list's): Edit and Delete may change it, its comment
      changed into NewComment ('' taken out), Edit To-Do Item for it }
    function TodoCanEdit(Item: TSdTodoItem): Boolean; virtual; abstract;
    procedure TodoChange(Item: TSdTodoItem; const NewComment: string); virtual; abstract;
    procedure TodoEdit(Item: TSdTodoItem); virtual; abstract;
    { the Type Library view (View | Type Library), a module of its own (IOTATypeLibModule): the
      library it shows ('' none) and the unit its importer writes for it (Library_TLB, '' none);
      a library shown there (False: the file holds none, the user was told); the view emptied
      and hidden }
    function TypeLibraryFile: string; virtual; abstract;
    function TypeLibraryUnit: string; virtual; abstract;
    { the text of the unit of the Type Library view's library as its import makes it, IDE text ('':
      none) }
    function TypeLibraryUnitText: string; virtual; abstract;
    function OpenTypeLibrary(const FileName: string): Boolean; virtual; abstract;
    function CloseTypeLibrary: Boolean; virtual; abstract;
    { a page of a file of an expert's file system (IOTAFileSystem, the name as the expert gives
      it): read through it, or (New) a new file of Source written through it when the page is
      saved; nil when it cannot be read (logged) }
    function OpenVirtualFile(const FileName, FileSystem, Source: string; New, Activate: Boolean): TEditorPage; virtual; abstract;
    { an existing file - of the disk (FileSystem '') or of an expert's file system - shown with Text,
      not read from it and not modified (a creator's text, Delphi 7's); an open page as it is }
    function OpenWithText(const FileName, FileSystem, Text: string; Activate: Boolean): TEditorPage; virtual; abstract;
  end;

  { a call of one notifier: N is the interface Each asked for (cast it: IOTAFormNotifier(N)),
    Data the caller's - the arguments of the call }
  TSdNotifierCall = procedure(const N: IInterface; Data: Pointer);

  { the interfaces registered by experts: index = what AddNotifier returned }
  TSdNotifierList = class
  private
    FItems: TInterfaceList;
    function GetItem(Index: Integer): IInterface;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const Item: IInterface): Integer;
    { Item in the first hole, else at the end (Delphi's AddToList: the index of a removed entry is
      taken again); -1 for nil }
    function AddInHole(const Item: IInterface): Integer;
    procedure Remove(Index: Integer);
    { the entry at Index taken out, the later ones one index down (Delphi's TInterfaceList.Delete);
      a bad index: nothing }
    procedure Delete(Index: Integer);
    { Delete, a bad index raising EListError as Delphi's TInterfaceList.Delete does }
    procedure DeleteChecked(Index: Integer);
    { the entry at Index, when it supports IID (an interface derived from IOTANotifier), taken out,
      then told IOTANotifier.Destroyed and released - both guarded, What names the entry in
      error.log; False: no such entry }
    function RemoveTold(Index: Integer; const IID: TGUID; const What: string): Boolean;
    procedure RemoveItem(const Item: IInterface);
    function IndexOfItem(const Item: IInterface): Integer;
    { a copy of the entries (nil holes left out): a notifier may remove itself while it is called }
    procedure Snapshot(List: TInterfaceList);
    { Call for each notifier that supports IID, over a copy of the entries; one that raises -
      whatever the class of its exception - goes to error.log (What names the call) and the others
      are called still }
    procedure Each(const IID: TGUID; Call: TSdNotifierCall; Data: Pointer; const What: string);
    { entries whose code lies in Module (a package that goes): released }
    procedure DropModule(Module: HMODULE);
    { what they were registered with goes (the IDE ends): every entry told IOTANotifier.Destroyed
      (What names the list in error.log), then released }
    procedure DestroyAll(const What: string);
    { every entry released, nothing told }
    procedure Clear;
    { the modules whose code the entries are (HMODULE in List, each once) }
    procedure AddModules(List: TList);
    function Count: Integer;              // with the holes
    function Active: Integer;             // without them
    property Items[Index: Integer]: IInterface read GetItem; default;
  end;

var
  OtaHost: TSdOtaHost;             // set by the main window; nil: no IDE around the services
  OtaFileSystemList: TSdNotifierList;  // the experts' file systems (IOTAModuleServices.AddFileSystem); nil: no services

{ the module (EXE, package, DLL) whose code implements an interface: where its vtable lies }
function InterfaceModule(const I: IInterface): HMODULE;
{ an exception of an expert's code: logged with Where, the IDE goes on }
procedure OtaError(E: Exception; const Where: string);
{ the text of an exception object of any module: class name and message - a DLL built without
  packages raises its own Exception class, whose message is read where Exception keeps it }
function OtaExceptionText(Obj: TObject): string;
{ the exception being handled, whatever its class (an expert's DLL has its own), logged with Where
  and shown too when Show (the user's command ran the expert's code); EAbort is silent }
procedure OtaCaught(const Where: string; Show: Boolean);
{ Text logged as the message of an exception of Where (error.log), shown too when Show }
procedure OtaLog(const Where, Text: string; Show: Boolean = False);
{ the strings of the Open Tools API are the IDE's (CP_ACP); the buffer is editor text (SdEncoding) }
function OtaToEditor(Page: TEditorPage; const S: string): string;
function OtaFromEditor(Page: TEditorPage; const S: string): string;
{ the file page whose editor Ed is - not a dialog's, a resource's or the Formatter's preview (nil:
  none) }
function OtaPageOfEditor(Ed: TObject): TEditorPage;
{ the loaded design packages in Delphi's order (IOTAPackageServices' list, the designer's own one
  included): the Index-th (nil: none) }
function OtaPackageEntry(Index: Integer): TPackageEntry;
{ M into List (the modules whose code is to be kept), unless it is 0 or there already }
procedure AddModuleOnce(List: TList; M: HMODULE);
{ the code a routine's address leads to: an import thunk (jmp dword ptr [address]) followed - an
  export of a package, or a package routine's address taken in the EXE }
function CodeEntry(P: Pointer): Pointer;
{ A and B are references to one object (False when either is nil) }
function SameInterface(const A, B: IInterface): Boolean;
{ a question or a message as Delphi 7 shows it - its MessageDlg's box, Delphi's TMessageForm (the
  modernized MessageDlg is a task dialog): where D7 Studio answers an expert's call or opens a
  project as Delphi 7 does }
function DelphiMessageDlg(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons): Integer;

{ positions on an editor (see the unit's head) }
function OtaCharPos(Line, CharIndex: Integer): TOTACharPos;
function OtaEditPos(Line, Col: Integer): TOTAEditPos;
function CharPosToOffset(Ed: TSciEdit; const P: TOTACharPos): Integer;
function OffsetToCharPos(Ed: TSciEdit; Offset: Integer): TOTACharPos;
function EditPosToOffset(Ed: TSciEdit; const P: TOTAEditPos): Integer;
function OffsetToEditPos(Ed: TSciEdit; Offset: Integer): TOTAEditPos;
{ the display column of an offset, 1-based (tabs to their stops) }
function OffsetColumn(Ed: TSciEdit; Offset: Integer): Integer;

implementation

uses
  SdSciDefs, SdSettings, SdCrashLog, SdEncoding;

{ ---------------------------------------------------------------- TSdNotifierList }

constructor TSdNotifierList.Create;
begin
  inherited Create;
  FItems := TInterfaceList.Create;
end;

destructor TSdNotifierList.Destroy;
begin
  FItems.Free;
  inherited;
end;

function TSdNotifierList.GetItem(Index: Integer): IInterface;
begin
  if (Index >= 0) and (Index < FItems.Count) then Result := FItems[Index] else Result := nil;
end;

function TSdNotifierList.Add(const Item: IInterface): Integer;
begin
  Result := -1;
  if Item = nil then Exit;
  Result := FItems.Add(Item);
end;

function TSdNotifierList.AddInHole(const Item: IInterface): Integer;
var
  I: Integer;
begin
  Result := -1;
  if Item = nil then Exit;
  for I := 0 to FItems.Count - 1 do
    if FItems[I] = nil then
    begin
      FItems[I] := Item;
      Result := I;
      Exit;
    end;
  Result := FItems.Add(Item);
end;

procedure TSdNotifierList.Remove(Index: Integer);
begin
  if (Index < 0) or (Index >= FItems.Count) then Exit;
  FItems[Index] := nil;
  { trailing holes go: the list does not grow for ever with notifiers that come and go }
  while (FItems.Count > 0) and (FItems[FItems.Count - 1] = nil) do FItems.Delete(FItems.Count - 1);
end;

procedure TSdNotifierList.Delete(Index: Integer);
begin
  if (Index >= 0) and (Index < FItems.Count) then FItems.Delete(Index);
end;

procedure TSdNotifierList.DeleteChecked(Index: Integer);
begin
  FItems.Delete(Index);
end;

{ The entry is read into a variable, not passed on as GetItem's result: a function's result in an
  expression is a hidden temporary that holds its reference until the routine returns, and N
  would not be the last one. }
function TSdNotifierList.RemoveTold(Index: Integer; const IID: TGUID; const What: string): Boolean;
var
  X, N: IInterface;
begin
  X := GetItem(Index);
  Result := Supports(X, IID, N);
  X := nil;
  if not Result then Exit;
  Remove(Index);
  try
    IOTANotifier(N).Destroyed;
  except
    OtaCaught(What + '.Destroyed', False);
  end;
  { the last reference: the entry is freed here, its destructor guarded as well }
  try
    N := nil;
  except
    OtaCaught(What + ' released', False);
  end;
end;

function TSdNotifierList.IndexOfItem(const Item: IInterface): Integer;
var
  I: Integer;
  U: IInterface;
begin
  Result := -1;
  if Item = nil then Exit;
  U := Item as IInterface;
  for I := 0 to FItems.Count - 1 do
    if (FItems[I] <> nil) and ((FItems[I] as IInterface) = U) then
    begin
      Result := I;
      Exit;
    end;
end;

procedure TSdNotifierList.RemoveItem(const Item: IInterface);
begin
  Remove(IndexOfItem(Item));
end;

procedure TSdNotifierList.Snapshot(List: TInterfaceList);
var
  I: Integer;
begin
  List.Clear;
  for I := 0 to FItems.Count - 1 do
    if FItems[I] <> nil then List.Add(FItems[I]);
end;

{ The list never ends in a hole (Add takes no nil, Remove and DropModule drop the trailing ones):
  empty is Count = 0. The copy is an array of the entries, not a TInterfaceList (a TThreadList with
  a critical section of its own): Each runs at every change of a file's text. }
procedure TSdNotifierList.Each(const IID: TGUID; Call: TSdNotifierCall; Data: Pointer; const What: string);
var
  S: array of IInterface;
  I, K: Integer;
  N: IInterface;
begin
  if FItems.Count = 0 then Exit;
  SetLength(S, FItems.Count);
  K := 0;
  for I := 0 to FItems.Count - 1 do
  begin
    S[K] := FItems[I];
    if S[K] <> nil then Inc(K);
  end;
  for I := 0 to K - 1 do
    if Supports(S[I], IID, N) then
      try
        Call(N, Data);
      except
        OtaCaught(What, False);
      end;
end;

procedure TSdNotifierList.DropModule(Module: HMODULE);
var
  I: Integer;
begin
  if Module = 0 then Exit;
  { a notifier released here may take another of its registrations out of this list (its
    destructor): the count is read again at each step }
  I := 0;
  while I < FItems.Count do
  begin
    if (FItems[I] <> nil) and (InterfaceModule(FItems[I]) = Module) then FItems[I] := nil;
    Inc(I);
  end;
  while (FItems.Count > 0) and (FItems[FItems.Count - 1] = nil) do FItems.Delete(FItems.Count - 1);
end;

procedure DestroyedOne(const N: IInterface; Data: Pointer);
begin
  IOTANotifier(N).Destroyed;
end;

procedure TSdNotifierList.DestroyAll(const What: string);
begin
  Each(IOTANotifier, DestroyedOne, nil, What + '.Destroyed');
  Clear;
end;

{ the entries are released once the list is empty: a destructor that removes its own entry finds
  nothing to change }
procedure TSdNotifierList.Clear;
var
  Old: TInterfaceList;
begin
  Old := FItems;
  FItems := TInterfaceList.Create;
  Old.Free;
end;

procedure TSdNotifierList.AddModules(List: TList);
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
    if FItems[I] <> nil then AddModuleOnce(List, InterfaceModule(FItems[I]));
end;

function TSdNotifierList.Count: Integer;
begin
  Result := FItems.Count;
end;

function TSdNotifierList.Active: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FItems.Count - 1 do
    if FItems[I] <> nil then Inc(Result);
end;

{ ---------------------------------------------------------------- helpers }

function InterfaceModule(const I: IInterface): HMODULE;
begin
  Result := 0;
  if I = nil then Exit;
  try
    Result := FindHInstance(PPointer(Pointer(I))^);
  except
    Result := 0;
  end;
end;

procedure OtaError(E: Exception; const Where: string);
begin
  try
    LogException(E, 'Open Tools API: ' + Where, SettingsDir + 'error.log');
  except
  end;
end;

function OtaExceptionText(Obj: TObject): string;
var
  C: TClass;
begin
  if Obj = nil then
  begin
    Result := 'unknown exception';
    Exit;
  end;
  if Obj is Exception then
  begin
    Result := Obj.ClassName + ': ' + Exception(Obj).Message;
    Exit;
  end;
  Result := Obj.ClassName;
  try
    { another module's Exception: its message is its first field, as in SysUtils.Exception }
    C := Obj.ClassType;
    while C <> nil do
    begin
      if C.ClassName = 'Exception' then
      begin
        Result := Result + ': ' + PString(Integer(Obj) + 4)^;
        Exit;
      end;
      C := C.ClassParent;
    end;
  except
  end;
end;

procedure OtaCaught(const Where: string; Show: Boolean);
var
  Obj: TObject;
begin
  Obj := ExceptObject;
  if Obj is EAbort then Exit;
  if Obj is Exception then
  begin
    OtaError(Exception(Obj), Where);
    if Show then Application.ShowException(Exception(Obj));
    Exit;
  end;
  OtaLog(Where, OtaExceptionText(Obj), Show);
end;

procedure OtaLog(const Where, Text: string; Show: Boolean);
var
  E: Exception;
begin
  E := Exception.Create(Text);
  try
    OtaError(E, Where);
    if Show then Application.ShowException(E);
  finally
    E.Free;
  end;
end;

function OtaToEditor(Page: TEditorPage; const S: string): string;
begin
  if Page = nil then Result := S else Result := AnsiToEditor(S, Page.Encoding);
end;

function OtaFromEditor(Page: TEditorPage; const S: string): string;
begin
  if Page = nil then Result := S else Result := EditorToAnsi(S, Page.Encoding);
end;

function OtaPageOfEditor(Ed: TObject): TEditorPage;
var
  I: Integer;
begin
  Result := nil;
  if (Ed = nil) or (OtaHost = nil) then Exit;
  for I := 0 to OtaHost.PageCount - 1 do
    if OtaHost.Pages(I).Editor = Ed then
    begin
      Result := OtaHost.Pages(I);
      Exit;
    end;
end;

function OtaPackageEntry(Index: Integer): TPackageEntry;
var
  I, N: Integer;
begin
  Result := nil;
  if DesignHost = nil then Exit;
  N := 0;
  for I := 0 to DesignHost.PackageCount - 1 do
    if DesignHost.Packages[I].Loaded then
    begin
      if N = Index then
      begin
        Result := DesignHost.Packages[I];
        Exit;
      end;
      Inc(N);
    end;
end;

procedure AddModuleOnce(List: TList; M: HMODULE);
begin
  if (M <> 0) and (List.IndexOf(Pointer(M)) < 0) then List.Add(Pointer(M));
end;

function CodeEntry(P: Pointer): Pointer;
begin
  Result := P;
  if (Result <> nil) and (PWord(Result)^ = $25FF) then
    Result := PPointer(PPointer(Cardinal(Result) + 2)^)^;
end;

function SameInterface(const A, B: IInterface): Boolean;
var
  UA, UB: IInterface;
begin
  Result := False;
  if (A = nil) or (B = nil) then Exit;
  A.QueryInterface(IInterface, UA);
  B.QueryInterface(IInterface, UB);
  Result := Pointer(UA) = Pointer(UB);
end;

function DelphiMessageDlg(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons): Integer;
begin
  with CreateMessageDialog(Msg, DlgType, Buttons) do
  try
    Result := ShowModal;
  finally
    Free;
  end;
end;

function OtaCharPos(Line, CharIndex: Integer): TOTACharPos;
begin
  Result.Line := Line;
  Result.CharIndex := CharIndex;
end;

function OtaEditPos(Line, Col: Integer): TOTAEditPos;
begin
  Result.Line := Line;
  Result.Col := Col;
end;

{ a line number of the API (1-based) as a valid 0-based line of the editor }
function EdLine(Ed: TSciEdit; Line: Integer): Integer;
begin
  Result := Line - 1;
  if Result < 0 then Result := 0;
  if Result > Ed.LineCount - 1 then Result := Ed.LineCount - 1;
  if Result < 0 then Result := 0;
end;

function CharPosToOffset(Ed: TSciEdit; const P: TOTACharPos): Integer;
var
  L, E: Integer;
begin
  Result := 0;
  if not Ed.Ready then Exit;
  if P.Line > Ed.LineCount then
  begin
    Result := Ed.TextLength;
    Exit;
  end;
  L := EdLine(Ed, P.Line);
  Result := Ed.PosFromLine(L);
  E := Ed.LineEndPos(L);
  if P.CharIndex > 0 then Inc(Result, P.CharIndex);
  if Result > E then Result := E;
end;

function OffsetToCharPos(Ed: TSciEdit; Offset: Integer): TOTACharPos;
var
  L: Integer;
begin
  Result := OtaCharPos(1, 0);
  if not Ed.Ready then Exit;
  if Offset < 0 then Offset := 0;
  if Offset > Ed.TextLength then Offset := Ed.TextLength;
  L := Ed.LineFromPos(Offset);
  Result := OtaCharPos(L + 1, Offset - Ed.PosFromLine(L));
end;

function EditPosToOffset(Ed: TSciEdit; const P: TOTAEditPos): Integer;
var
  L, C: Integer;
begin
  Result := 0;
  if not Ed.Ready then Exit;
  L := EdLine(Ed, P.Line);
  C := P.Col - 1;
  if C < 0 then C := 0;
  Result := Ed.Sci(SCI_FINDCOLUMN, L, C);
end;

function OffsetColumn(Ed: TSciEdit; Offset: Integer): Integer;
begin
  Result := Ed.Sci(SCI_GETCOLUMN, Offset) + 1;
end;

function OffsetToEditPos(Ed: TSciEdit; Offset: Integer): TOTAEditPos;
begin
  Result := OtaEditPos(1, 1);
  if not Ed.Ready then Exit;
  if Offset < 0 then Offset := 0;
  if Offset > Ed.TextLength then Offset := Ed.TextLength;
  Result := OtaEditPos(Ed.LineFromPos(Offset) + 1, OffsetColumn(Ed, Offset));
end;

end.
