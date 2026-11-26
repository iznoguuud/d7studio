{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaDesktop;

{ D7 Studio - the IDE's side of designide's desktop units, DeskUtil and DeskForm. Their forms call the
  IDE through procedure variables that Delphi 7's IDE sets
  (coreide70's unit Desktop). An expert's window derived from TDockableForm reads its Dockable
  setting through DeskUtil.IDEIniFile in its FormCreate and clears its instance variable through
  DeskUtil.GetFieldAddress in its FormDestroy, both called without a check: left nil, the window
  failed while it was made, and the expert with it.
  * IDEIniFile: D7 Studio's registry key as an ini file (Delphi's: AppIniFile, its own key) - the
    key IOTAServices.GetBaseRegistryKey names.
  * Register / Unregister / GetFieldAddress: the global variable that holds a desktop form, by the
    form's instance name (the third argument of RegisterDesktopFormClass).
  * The main window's created and shown events (DeskUtil's Add / RemoveMainForm*Event, DeskForm's
    Register / UnregisterMainFormShown - Delphi has one list for both of the latter): sent once
    each, as Delphi sends them while it starts - after the experts have loaded
    (DeskMainFormCreated) and once the main window is shown (DeskMainFormShown). A handler added
    later is kept and never called, as in Delphi.
  * A package that is unloaded loses its field addresses and handlers first (DeskDropModule).
  * DeskForm.InitializeForm, called by TDesktopForm.FormCreate for every desktop form that is
    made: the main window makes the dockable ones views of its dock (ExpertFormHook,
    SdOtaViews); a package that goes gives its forms back first (ExpertDropHook).
  * DeskMakeForm: a window that an arrangement of the dock shows and its expert has not made, made
    as Delphi's desktop makes the windows a desktop names (DeskUtil.LoadDesktopFormClasses) - from
    the class the expert gave RegisterDesktopFormClass, into the variable it gave
    RegisterFieldAddress.
  Not set, as Delphi's Desktop unit does not set them either: DeskForm.GetDockable, RegisterMenu,
  UnregisterMenu (designide checks them). }

interface

uses
  Forms;

var
  { set by the main window: a desktop form was made (InitializeForm), a package goes }
  ExpertFormHook: procedure(Form: TCustomForm) of object;
  ExpertDropHook: procedure(Module: HMODULE) of object;

{ the main window was made and the experts have loaded / it is shown: each event sent once }
procedure DeskMainFormCreated(MainForm: TObject);
procedure DeskMainFormShown(MainForm: TObject);
{ a package goes: its field addresses and handlers first }
procedure DeskDropModule(Module: HMODULE);
{ the form named FormName (by its form file) of the desktop form class registered last, made as
  Delphi's desktop makes it: Application its owner, put into the variable registered for its
  instance name. The form there already when the variable holds one; nil: no such class, or its
  expert failed to make it }
function DeskMakeForm(const FormName: string): TCustomForm;
{ test mode: 'fields=name,... created=n shown=n sent=created,shown' }
function DeskDebugText: string;

implementation

uses
  Windows, SysUtils, Classes, IniFiles, Registry, DeskUtil, DeskForm, SdSettings, SdOtaCore;

type
  PDeskHandler = ^TMethod;

  { an entry of designide's list of the RegisterDesktopFormClass calls: a TObject of DeskUtil's
    implementation }
  PDeskFormClassEntry = ^TDeskFormClassEntry;
  TDeskFormClassEntry = record
    VMT: Pointer;
    Section: string;
    InstanceName: string;
    FormClass: TClass;
  end;

  { the handlers of an event, in the order they came (Delphi's Events.TEvent: a handler once;
    with an unloaded module's handlers dropped and an expert's exception logged) }
  TDeskEvent = class
  private
    FList: TList;
    FName: string;
    FSent: Boolean;
    function IndexOf(const Handler: TNotifyEvent): Integer;
  public
    constructor Create(const AName: string);
    destructor Destroy; override;
    procedure Add(Handler: TNotifyEvent);
    procedure Remove(Handler: TNotifyEvent);
    procedure SendOnce(Sender: TObject);
    procedure DropModule(Module: HMODULE);
    function Count: Integer;
  end;

var
  IdeIni: TRegistryIniFile;
  Fields: TStringList;            // instance name -> the address of its variable (Objects)
  CreatedEvent, ShownEvent: TDeskEvent;

{ ---------------------------------------------------------------- TDeskEvent }

constructor TDeskEvent.Create(const AName: string);
begin
  inherited Create;
  FList := TList.Create;
  FName := AName;
end;

destructor TDeskEvent.Destroy;
var
  I: Integer;
begin
  for I := 0 to FList.Count - 1 do Dispose(PDeskHandler(FList[I]));
  FList.Free;
  inherited;
end;

function TDeskEvent.IndexOf(const Handler: TNotifyEvent): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FList.Count - 1 do
    if (PDeskHandler(FList[I])^.Code = TMethod(Handler).Code) and
      (PDeskHandler(FList[I])^.Data = TMethod(Handler).Data) then
    begin
      Result := I;
      Exit;
    end;
end;

procedure TDeskEvent.Add(Handler: TNotifyEvent);
var
  P: PDeskHandler;
begin
  if not Assigned(Handler) or (IndexOf(Handler) >= 0) then Exit;
  New(P);
  P^ := TMethod(Handler);
  FList.Add(P);
end;

procedure TDeskEvent.Remove(Handler: TNotifyEvent);
var
  I: Integer;
begin
  I := IndexOf(Handler);
  if I < 0 then Exit;
  Dispose(PDeskHandler(FList[I]));
  FList.Delete(I);
end;

procedure TDeskEvent.SendOnce(Sender: TObject);
var
  I: Integer;
  H: TNotifyEvent;
begin
  if FSent then Exit;
  FSent := True;
  { from the last, as Delphi's TEvent.Send: a handler may remove itself, or others }
  I := FList.Count - 1;
  while I >= 0 do
  begin
    if I < FList.Count then
    begin
      TMethod(H) := PDeskHandler(FList[I])^;
      try
        H(Sender);
      except
        OtaCaught(FName, False);
      end;
    end;
    Dec(I);
  end;
end;

procedure TDeskEvent.DropModule(Module: HMODULE);
var
  I: Integer;
begin
  for I := FList.Count - 1 downto 0 do
    if FindHInstance(PDeskHandler(FList[I])^.Code) = Module then
    begin
      Dispose(PDeskHandler(FList[I]));
      FList.Delete(I);
    end;
end;

function TDeskEvent.Count: Integer;
begin
  Result := FList.Count;
end;

{ ---------------------------------------------------------------- the hooks }

function DeskIniFile: TCustomIniFile;
begin
  { one object for the whole session: designide's forms read and write through it and do not
    free it }
  if IdeIni = nil then IdeIni := TRegistryIniFile.Create(SettingsRegKey);
  Result := IdeIni;
end;

function DeskGetFieldAddress(const Name: string): Pointer;
var
  I: Integer;
begin
  Result := nil;
  I := Fields.IndexOf(Name);
  if I >= 0 then Result := Pointer(Fields.Objects[I]);
end;

procedure DeskRegisterFieldAddress(const Name: string; Address: Pointer);
var
  I: Integer;
begin
  if (Name = '') or (Address = nil) then Exit;
  I := Fields.IndexOf(Name);
  if I >= 0 then Fields.Objects[I] := TObject(Address)
  else Fields.AddObject(Name, TObject(Address));
end;

procedure DeskUnregisterFieldAddress(Address: Pointer);
var
  I: Integer;
begin
  for I := Fields.Count - 1 downto 0 do
    if Pointer(Fields.Objects[I]) = Address then Fields.Delete(I);
end;

procedure DeskAddCreated(Event: TNotifyEvent);
begin
  CreatedEvent.Add(Event);
end;

procedure DeskRemoveCreated(Event: TNotifyEvent);
begin
  CreatedEvent.Remove(Event);
end;

procedure DeskAddShown(Event: TNotifyEvent);
begin
  ShownEvent.Add(Event);
end;

procedure DeskRemoveShown(Event: TNotifyEvent);
begin
  ShownEvent.Remove(Event);
end;

{ TDesktopForm.FormCreate: every desktop form that is made }
procedure DeskInitializeForm(Form: TComponent);
begin
  if Assigned(ExpertFormHook) and (Form is TCustomForm) then
    try
      ExpertFormHook(TCustomForm(Form));
    except
      OtaCaught('expert window ' + Form.Name, False);
    end;
end;

{ ---------------------------------------------------------------- the IDE's calls }

procedure DeskMainFormCreated(MainForm: TObject);
begin
  CreatedEvent.SendOnce(MainForm);
end;

procedure DeskMainFormShown(MainForm: TObject);
begin
  ShownEvent.SendOnce(MainForm);
end;

procedure DeskDropModule(Module: HMODULE);
var
  I: Integer;
begin
  if Module = 0 then Exit;
  if Assigned(ExpertDropHook) then
    try
      ExpertDropHook(Module);
    except
      OtaCaught('expert windows', False);
    end;
  for I := Fields.Count - 1 downto 0 do
    if FindHInstance(Pointer(Fields.Objects[I])) = Module then Fields.Delete(I);
  CreatedEvent.DropModule(Module);
  ShownEvent.DropModule(Module);
end;

{ designide's list of the RegisterDesktopFormClass calls (entries TDeskFormClassEntry; nil: none
  yet). DeskUtil keeps it in a variable of its implementation, which LoadDesktopFormClasses reads
  first: push ebx; push esi; push edi; mov edi, eax; mov eax, [the variable] }
function DeskFormClasses: TList;
const
  Head: array[0..5] of Byte = ($53, $56, $57, $8B, $F8, $A1);
var
  P: PChar;
begin
  Result := nil;
  P := CodeEntry(@LoadDesktopFormClasses);
  if (P = nil) or not CompareMem(P, @Head, SizeOf(Head)) then Exit;
  Result := TList(PPointer(PPointer(P + SizeOf(Head))^)^);
  if (Result <> nil) and (Result.ClassType <> TList) then Result := nil;
end;

{ the name a form of class Cls gets from its form file, the class name when it has none (the name
  of an expert's view: SdOtaViews) }
function DeskFormName(Cls: TClass): string;
var
  H: HMODULE;
  S: TResourceStream;
  R: TReader;
  Flags: TFilerFlags;
  ChildPos: Integer;
  N: string;
begin
  Result := '';
  N := Cls.ClassName;
  try
    H := FindResourceHInstance(FindClassHInstance(Cls));
    if FindResource(H, PChar(N), RT_RCDATA) <> 0 then
    begin
      S := TResourceStream.Create(H, N, RT_RCDATA);
      try
        R := TReader.Create(S, 256);
        try
          R.ReadSignature;
          R.ReadPrefix(Flags, ChildPos);
          R.ReadStr;                           // the class name
          Result := R.ReadStr;
        finally
          R.Free;
        end;
      finally
        S.Free;
      end;
    end;
  except
    Result := '';
  end;
  if Result = '' then Result := N;
end;

{ designide keeps the entries of unloaded packages (Delphi 7 has no UnregisterDesktopFormClass), and
  a package loaded again adds its classes once more: the entries are read from the last, and an
  entry's class only when the variable of its instance name is known (DeskDropModule forgets those
  of a package that goes) and lies in the class's module }
function DeskMakeForm(const FormName: string): TCustomForm;
var
  L: TList;
  I: Integer;
  E: PDeskFormClassEntry;
  Field: PPointer;
  M: HMODULE;
begin
  Result := nil;
  L := DeskFormClasses;
  if (L = nil) or (FormName = '') then Exit;
  for I := L.Count - 1 downto 0 do
  begin
    E := L[I];
    if E = nil then Continue;
    Field := DeskGetFieldAddress(E^.InstanceName);
    if Field = nil then Continue;
    M := FindHInstance(Field);
    if (M = 0) or (FindHInstance(Pointer(E^.FormClass)) <> M) or
      not E^.FormClass.InheritsFrom(TCustomForm) or not SameText(DeskFormName(E^.FormClass), FormName) then
      Continue;
    if Field^ <> nil then
    begin
      Result := TCustomForm(Field^);
      Exit;
    end;
    try
      Result := TCustomFormClass(E^.FormClass).Create(Application);
      Field^ := Result;
    except
      Result := nil;
      OtaCaught('expert window ' + FormName, False);
    end;
    Exit;
  end;
end;

function DeskDebugText: string;
var
  I: Integer;
  S: string;
begin
  S := '';
  for I := 0 to Fields.Count - 1 do
  begin
    if S <> '' then S := S + ',';
    S := S + Fields[I];
  end;
  Result := Format('fields=%s created=%d shown=%d sent=', [S, CreatedEvent.Count, ShownEvent.Count]);
  if CreatedEvent.FSent then Result := Result + 'created';
  if ShownEvent.FSent then
  begin
    if CreatedEvent.FSent then Result := Result + ',';
    Result := Result + 'shown';
  end;
end;

procedure InstallDeskHooks;
begin
  DeskUtil.IDEIniFile := DeskIniFile;
  DeskUtil.GetFieldAddress := DeskGetFieldAddress;
  DeskUtil.RegisterFieldAddress := DeskRegisterFieldAddress;
  DeskUtil.UnregisterFieldAddress := DeskUnregisterFieldAddress;
  DeskUtil.AddMainFormCreatedEvent := DeskAddCreated;
  DeskUtil.RemoveMainFormCreatedEvent := DeskRemoveCreated;
  DeskUtil.AddMainFormShownEvent := DeskAddShown;
  DeskUtil.RemoveMainFormShownEvent := DeskRemoveShown;
  DeskForm.RegisterMainFormShown := DeskAddShown;
  DeskForm.UnregisterMainFormShown := DeskRemoveShown;
  DeskForm.InitializeForm := DeskInitializeForm;
end;

{ No finalization: D7 Studio leaves without running the packages' finalization, and a desktop
  form freed by one would call these hooks again. }
initialization
  Fields := TStringList.Create;
  CreatedEvent := TDeskEvent.Create('main window created');
  ShownEvent := TDeskEvent.Create('main window shown');
  InstallDeskHooks;
end.
