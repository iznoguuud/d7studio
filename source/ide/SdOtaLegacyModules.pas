{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaLegacyModules;

{ D7 Studio - the module interfaces of Delphi 1-3's expert API (EditIntf, FileIntf) on the Open Tools
API's modules (SdOtaModules), as Delphi 7's IDE gives them.

  * TIModuleInterface: one object per module while the module is there. What
    ToolServices.GetModuleInterface gives is that object with one reference more (the expert frees
    it). Its notifiers (TIModuleNotifier) hear the module's events through bridges on the module's
    notifier lists: ncModuleDeleted when the module goes - from then on the object answers
    "nothing" -, ncModuleRenamed, ncEditorModified / ncFormModified, ncEditorSelected /
    ncFormSelected, ncBeforeSave / ncAfterSave and ncFormSaving; the newest notifier first.
    ComponentRenamed is never called, and GetFormInterface is nil: Delphi 7 has neither.
  * TIEditorInterface, TIEditView, TIEditReader, TIEditWriter, TIResourceFile, TIResourceEntry: made
    at each call (the expert frees them) around the module's IOTASourceEditor, IOTAEditView, reader,
    writer and IOTAProjectResource.
  * File systems both ways (Delphi 7's Filemain): an expert's TIVirtualFileSystem registered as an
    IOTAFileSystem, an IOTAFileSystem handed out as a TIVirtualFileSystem.
  * The old creators (TIModuleCreator, TIProjectCreator and their Ex) as IOTAModuleCreator /
    IOTAProjectCreator of IOTAModuleServices.CreateModule. A new module whose ancestor is a data
    module or a custom module a package registered (RegisterCustomModule: TService ...) gets the form
    file of a new instance of that class, streamed as Delphi streams it.
  * Every method guards itself: whatever the IDE's code raises - or an expert's object called from
    here, whatever its exception class - is logged (error.log), shown too while the user's command
    runs the expert's code (LegacyCommandDepth), and the method answers False / nil / '' / -1. }

{$WARN UNIT_DEPRECATED OFF}
{$WARN SYMBOL_DEPRECATED OFF}

interface

uses
  Windows, ActiveX, SysUtils, Classes, ToolsAPI, EditIntf, FileIntf, ToolIntf, SdOtaModules;

type
  { the module interface of a module of the IDE: one per module while it is there (Module nil once it
    went: every method then answers "nothing") }
  TSdModuleIntf = class(TIModuleInterface)
  private
    FModule: TSdOtaModule;
    FModuleRef: IOTAModule;            // holds the module while the object knows it
    FNotifiers: TList;                 // TIModuleNotifier, in the order added
    FBridgeObjs: array[0..2] of TObject;
    FBridges: array[0..2] of IOTANotifier;   // on the module's, its source editor's, its form editor's lists
    procedure Bridge(Kind: Integer);
    procedure Unbridge;
    procedure Notify(Code: TNotifyCode);
    procedure ModuleGone;
  public
    constructor Create(AModule: TSdOtaModule);
    destructor Destroy; override;
    property Module: TSdOtaModule read FModule;
    function NotifierCount: Integer;
    { the notifiers whose code lies in Module (a package that goes) are forgotten }
    procedure DropModule(Module: HMODULE);
    { TIModuleInterface }
    function GetEditorInterface: TIEditorInterface; override;
    function GetFormInterface: TIFormInterface; override;
    function GetAncestorModule: TIModuleInterface; override;
    function GetProjectResource: TIResourceFile; override;
    function IsProjectModule: Boolean; override;
    function Close: Boolean; override;
    function Save(ForceSave: Boolean): Boolean; override;
    function Rename(const NewName: string): Boolean; override;
    function GetFileSystem(var FileSystem: string): Boolean; override;
    function SetFileSystem(const FileSystem: string): Boolean; override;
    function ShowSource: Boolean; override;
    function ShowForm: Boolean; override;
    function AddNotifier(AModuleNotifier: TIModuleNotifier): Boolean; override;
    function RemoveNotifier(AModuleNotifier: TIModuleNotifier): Boolean; override;
    function GetAuxEditorInterface: TIEditorInterface; override;
  end;

var
  { the user's command runs an expert's code (a menu item, an item of File | New): what fails is
    shown as well as logged }
  LegacyCommandDepth: Integer;

{ an exception of an expert's code or of the IDE's, caught by a method of the old API: logged, and
  shown while the user's command runs (LegacyCommandDepth); EAbort is silent }
procedure LegacyFailed(const Where: string);
{ the exception being handled as an Exception of this module (an expert's DLL raises its own
  Exception class): raise it in an except block that runs a foreign object's method }
function LegacyOwnException: Exception;
{ the module whose code a foreign object is (its class's VMT lies there) }
function ObjectModule(Obj: TObject): HMODULE;

type
  { a call of one of Delphi 1-3's notifiers (an expert's object); Data the caller's - the
    arguments of the call }
  TLegacyCall = procedure(Obj: TObject; Data: Pointer);

{ Call for each object of List (an expert's notifiers), over a copy: one removed meanwhile is not
  called; NewestFirst from the last one added. What raises - whatever its class - is logged as
  What, and the others are called still. }
procedure LegacyEach(List: TList; Call: TLegacyCall; Data: Pointer; NewestFirst: Boolean;
  const What: string);

{ the module interface of an IDE module (the same object while the module is there; no reference
  added for the caller); nil without a module }
function LegacyModuleIntf(M: TSdOtaModule): TSdModuleIntf;
{ ToolServices.GetModuleInterface (a form file: its unit's) / GetFormModuleInterface: the module
  interface with a reference for the caller; nil when no such module is open }
function LegacyModuleInterface(const FileName: string): TIModuleInterface;
function LegacyFormModuleInterface(const FormName: string): TIModuleInterface;
{ the notifiers of all module interfaces (the state dump) }
function LegacyModuleNotifierCount: Integer;

{ ToolServices' file systems: an expert's registered (Delphi 7's adapter takes a reference to it
  and frees it when it goes), removed by its name, an IOTAFileSystem as an old one (the caller
  frees it) }
function LegacyRegisterFileSystem(FS: TIVirtualFileSystem): Boolean;
function LegacyUnregisterFileSystem(const Ident: string): Boolean;
function LegacyGetFileSystem(const Ident: string): TIVirtualFileSystem;
function LegacyFileSystemCount: Integer;

{ ToolServices.ModuleCreate(Ex) / ProjectCreate(Ex): the creator's module made by
  IOTAModuleServices.CreateModule; its module interface (a reference for the caller) }
function LegacyModuleCreate(Creator: TIModuleCreator; Flags: TCreateModuleFlags): TIModuleInterface;
function LegacyProjectCreate(Creator: TIProjectCreator; Flags: TCreateProjectFlags; IsEx: Boolean): TIModuleInterface;
{ ToolServices.CreateModule / CreateModuleEx / CreateCppModule: a new unit, form or text
  (cmNewUnit, cmNewForm, cmNewFile), a file opened (cmExisting), or a module of the source and form
  streams; its module interface (a reference for the caller) }
function LegacyCreateModule(const ModuleName, FormName, AncestorClass, FileSystem: string;
  Source, Form: IStream; Flags: TCreateModuleFlags): TIModuleInterface;
{ the form file of a new module named FormIdent whose ancestor is AncestorIdent (a class name with
  or without its T): a new instance of that class streamed, when it is a data module or a custom
  module of a package (RegisterCustomModule); '' otherwise }
function LegacyAncestorDfm(const FormIdent, AncestorIdent: string): string;
{ a package or a DLL goes: the module notifiers and file systems whose code lies there are
  forgotten }
procedure LegacyModulesDropModule(Module: HMODULE);
{ the text of a stream an expert gave (IStreams' or its own), from its start }
function LegacyStreamText(const S: IStream): string;

implementation

uses
  SdOtaCore, SdEditorPage, SdProject, SdFileNames, SdDesignHost;

type
  { what a module's notifier list tells, as the codes of the old module notifiers }
  TSdModuleBridge = class(TInterfacedObject, IOTANotifier, IOTAModuleNotifier, IOTAEditorNotifier,
    IOTAFormNotifier)
  private
    FOwner: TSdModuleIntf;
    FKind: Integer;                    // 0 the module's list, 1 its source editor's, 2 its form editor's
    procedure Tell(Code: TNotifyCode);
  public
    constructor Create(AOwner: TSdModuleIntf; AKind: Integer);
    { IOTANotifier }
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;
    { IOTAModuleNotifier }
    function CheckOverwrite: Boolean;
    procedure ModuleRenamed(const NewName: string);
    { IOTAEditorNotifier }
    procedure ViewNotification(const View: IOTAEditView; Operation: TOperation);
    procedure ViewActivated(const View: IOTAEditView);
    { IOTAFormNotifier }
    procedure FormActivated;
    procedure FormSaving;
    procedure ComponentRenamed(ComponentHandle: TOTAHandle; const OldName, NewName: string);
  end;

  TSdEditorIntf = class(TIEditorInterface)
  private
    FEditor: IOTASourceEditor;
  public
    constructor Create(const AEditor: IOTASourceEditor);
    function CreateReader: TIEditReader; override;
    function CreateWriter: TIEditWriter; override;
    function FileName: string; override;
    function LinesInBuffer: Longint; override;
    function BufferModified: Boolean; override;
    function MarkModified: Boolean; override;
    function SetSyntaxHighlighter(SyntaxHighlighter: TSyntaxHighlighter): TSyntaxHighlighter; override;
    function GetViewCount: Integer; override;
    function GetView(Index: Integer): TIEditView; override;
    function CreateUndoableWriter: TIEditWriter; override;
    function GetBlockAfter: TCharPos; override;
    function GetBlockStart: TCharPos; override;
    function GetBlockType: TBlockType; override;
    function GetBlockVisible: Boolean; override;
    procedure SetBlockAfter(Value: TCharPos); override;
    procedure SetBlockStart(Value: TCharPos); override;
    procedure SetBlockType(Value: TBlockType); override;
    procedure SetBlockVisible(Value: Boolean); override;
  end;

  TSdEditViewIntf = class(TIEditView)
  private
    FView: IOTAEditView;
  public
    constructor Create(const AView: IOTAEditView);
    function GetPos(Index: Integer): TEditPos; override;
    procedure SetPos(Index: Integer; Value: TEditPos); override;
    function GetViewSize: TSize; override;
    function PosToCharPos(Pos: Longint): TCharPos; override;
    function CharPosToPos(CharPos: TCharPos): Longint; override;
    procedure ConvertPos(EdPosToCharPos: Boolean; var EditPos: TEditPos; var CharPos: TCharPos); override;
    procedure GetAttributeAtPos(const EdPos: TEditPos; var Element, LineFlag: Integer); override;
  end;

  TSdEditReaderIntf = class(TIEditReader)
  private
    FReader: IOTAEditReader;
  public
    constructor Create(const AReader: IOTAEditReader);
    function GetText(Position: Longint; Buffer: PChar; Count: Longint): Longint; override;
  end;

  { the writer of the Open Tools API is released with this object: the editor's undo is flushed
    then, unless it is an undoable writer (TSdOtaWriter) }
  TSdEditWriterIntf = class(TIEditWriter)
  private
    FWriter: IOTAEditWriter;
  public
    constructor Create(const AWriter: IOTAEditWriter);
    function CopyTo(Pos: Longint): Boolean; override;
    function DeleteTo(Pos: Longint): Boolean; override;
    function Insert(Text: PChar): Boolean; override;
    function Position: Longint; override;
    function GetCurrentPos: TCharPos; override;
  end;

  TSdResourceEntryIntf = class(TIResourceEntry)
  private
    FEntry: IOTAResourceEntry;
  public
    constructor Create(const AEntry: IOTAResourceEntry);
    function GetResourceType: PChar; override;
    function GetResourceName: PChar; override;
    function Change(NewType, NewName: PChar): Boolean; override;
    function GetHeaderValue(HeaderValue: TResHeaderValue; var Value: Integer): Boolean; override;
    function SetHeaderValue(HeaderValue: TResHeaderValue; Value: Integer): Boolean; override;
    function GetData: Pointer; override;
    function GetDataSize: Integer; override;
    function SetDataSize(NewSize: Integer): Boolean; override;
    function GetEntryHandle: Pointer; override;
  end;

  TSdResourceFileIntf = class(TIResourceFile)
  private
    FRes: IOTAProjectResource;
  public
    constructor Create(const ARes: IOTAProjectResource);
    function FileName: string; override;
    function GetEntryCount: Integer; override;
    function GetEntry(Index: Integer): TIResourceEntry; override;
    function GetEntryFromHandle(EntryHandle: Pointer): TIResourceEntry; override;
    function FindEntry(ResType, Name: PChar): TIResourceEntry; override;
    function DeleteEntry(EntryHandle: Pointer): Boolean; override;
    function CreateEntry(ResType, Name: PChar; Flags, LanguageId: Word;
      DataVersion, Version, Characteristics: Integer): TIResourceEntry; override;
  end;

  { an expert's file system for the Open Tools API: registered with IOTAModuleServices, it holds a
    reference to the expert's object and frees it when it goes }
  TSdOldFileSystem = class(TInterfacedObject, IOTAFileSystem)
  private
    FOld: TIVirtualFileSystem;
    FModule: HMODULE;
    FIndex: Integer;                   // IOTAModuleServices.AddFileSystem's
  public
    constructor Create(AOld: TIVirtualFileSystem);
    destructor Destroy; override;
    function GetFileStream(const FileName: string; Mode: Integer): IStream;
    function FileAge(const FileName: string): Longint;
    function RenameFile(const OldName, NewName: string): Boolean;
    function IsReadonly(const FileName: string): Boolean;
    function IsFileBased: Boolean;
    function DeleteFile(const FileName: string): Boolean;
    function FileExists(const FileName: string): Boolean;
    function GetTempFileName(const FileName: string): string;
    function GetBackupFileName(const FileName: string): string;
    function GetIDString: string;
  end;

  { an IOTAFileSystem as Delphi 1-3's }
  TSdFileSystemIntf = class(TIVirtualFileSystem)
  private
    FNew: IOTAFileSystem;
  public
    constructor Create(const ANew: IOTAFileSystem);
    function GetFileStream(const FileName: TFileName; Mode: Integer): IStream; override;
    function FileAge(const FileName: TFileName): Longint; override;
    function RenameFile(const OldName, NewName: TFileName): Boolean; override;
    function IsReadonly(const FileName: TFileName): Boolean; override;
    function IsFileBased: Boolean; override;
    function DeleteFile(const FileName: TFileName): Boolean; override;
    function FileExists(const FileName: TFileName): Boolean; override;
    function GetTempFileName(const FileName: TFileName): TFileName; override;
    function GetBackupFileName(const FileName: TFileName): TFileName; override;
    function GetIDString: string; override;
  end;

  { a creator's text }
  TSdStreamFile = class(TInterfacedObject, IOTAFile)
  private
    FSource: string;
  public
    constructor Create(const ASource: string);
    function GetSource: string;
    function GetAge: TDateTime;
  end;

  { an old module creator for IOTAModuleServices.CreateModule. FormCreated is never called, as in
    Delphi 7 (its TIFormInterface does not exist). }
  TSdLegacyModuleCreator = class(TInterfacedObject, IOTACreator, IOTAModuleCreator)
  private
    FCreator: TIModuleCreator;
    FFlags: TCreateModuleFlags;
    FFormName: string;
    FAncestor: string;
  public
    constructor Create(ACreator: TIModuleCreator; AFlags: TCreateModuleFlags);
    { IOTACreator }
    function GetCreatorType: string;
    function GetExisting: Boolean;
    function GetFileSystem: string;
    function GetOwner: IOTAModule;
    function GetUnnamed: Boolean;
    { IOTAModuleCreator }
    function GetAncestorName: string;
    function GetImplFileName: string;
    function GetIntfFileName: string;
    function GetFormName: string;
    function GetMainForm: Boolean;
    function GetShowForm: Boolean;
    function GetShowSource: Boolean;
    function NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
    function NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    function NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    procedure FormCreated(const FormEditor: IOTAFormEditor);
  end;

  { an old project creator: not an IOTAProjectCreator50, so that CreateModule calls its
    NewDefaultModule }
  TSdLegacyProjectCreator = class(TInterfacedObject, IOTACreator, IOTAProjectCreator)
  private
    FCreator: TIProjectCreator;
    FFlags: TCreateProjectFlags;
    FFileName: string;
  public
    constructor Create(ACreator: TIProjectCreator; AFlags: TCreateProjectFlags);
    { IOTACreator }
    function GetCreatorType: string;
    function GetExisting: Boolean;
    function GetFileSystem: string;
    function GetOwner: IOTAModule;
    function GetUnnamed: Boolean;
    { IOTAProjectCreator }
    function GetFileName: string;
    function GetOptionFileName: string;
    function GetShowSource: Boolean;
    procedure NewDefaultModule;
    function NewOptionSource(const ProjectName: string): IOTAFile;
    procedure NewProjectResource(const Project: IOTAProject);
    function NewProjectSource(const ProjectName: string): IOTAFile;
  end;

  TDataModuleClassRef = class of TDataModule;

var
  Intfs: TList;                        // TSdModuleIntf of the modules that are there (one reference each)
  OldFileSystems: TList;               // TSdOldFileSystem registered

{ ---------------------------------------------------------------- helpers }

procedure LegacyFailed(const Where: string);
begin
  OtaCaught(Where, LegacyCommandDepth > 0);
end;

function LegacyOwnException: Exception;
begin
  Result := Exception.Create(OtaExceptionText(ExceptObject));
end;

function ObjectModule(Obj: TObject): HMODULE;
begin
  Result := 0;
  if Obj = nil then Exit;
  try
    Result := FindClassHInstance(Obj.ClassType);
  except
    Result := 0;
  end;
end;

procedure LegacyEach(List: TList; Call: TLegacyCall; Data: Pointer; NewestFirst: Boolean;
  const What: string);
var
  L: TList;
  I, K: Integer;
begin
  if List.Count = 0 then Exit;
  L := TList.Create;
  try
    L.Assign(List);
    for K := 0 to L.Count - 1 do
    begin
      if NewestFirst then I := L.Count - 1 - K else I := K;
      if List.IndexOf(L[I]) < 0 then Continue;
      try
        Call(TObject(L[I]), Data);
      except
        OtaCaught(What, False);
      end;
    end;
  finally
    L.Free;
  end;
end;

function OldCharPos(const P: TOTACharPos): TCharPos;
begin
  Result.CharIndex := P.CharIndex;
  Result.Line := P.Line;
end;

function NewCharPos(const P: TCharPos): TOTACharPos;
begin
  Result.CharIndex := P.CharIndex;
  Result.Line := P.Line;
end;

function OldEditPos(const P: TOTAEditPos): TEditPos;
begin
  Result.Col := P.Col;
  Result.Line := P.Line;
end;

function NewEditPos(const P: TEditPos): TOTAEditPos;
begin
  Result.Col := P.Col;
  Result.Line := P.Line;
end;

function LegacyStreamText(const S: IStream): string;
var
  Buf: array[0..8191] of Char;
  N: Longint;
  NewPos: Largeint;
  Part: string;
begin
  Result := '';
  if S = nil then Exit;
  S.Seek(0, STREAM_SEEK_SET, NewPos);
  repeat
    N := 0;
    if Failed(S.Read(@Buf, SizeOf(Buf), @N)) then Break;
    if N > 0 then
    begin
      SetString(Part, Buf, N);
      Result := Result + Part;
    end;
  until N < SizeOf(Buf);
end;

{ a form stream as form text: binary forms (and form resources) converted }
function FormStreamText(const S: IStream): string;
var
  Raw: string;
  Src, Dst: TStringStream;
begin
  Raw := LegacyStreamText(S);
  Result := Raw;
  if Raw = '' then Exit;
  Src := TStringStream.Create(Raw);
  Dst := TStringStream.Create('');
  try
    case TestStreamFormat(Src) of
      sofBinary:
        begin
          Src.Position := 0;
          if (Length(Raw) > 0) and (Raw[1] = #$FF) then ObjectResourceToText(Src, Dst)
          else ObjectBinaryToText(Src, Dst);
          Result := Dst.DataString;
        end;
    end;
  finally
    Dst.Free;
    Src.Free;
  end;
end;

{ ---------------------------------------------------------------- TSdModuleBridge }

constructor TSdModuleBridge.Create(AOwner: TSdModuleIntf; AKind: Integer);
begin
  inherited Create;
  FOwner := AOwner;
  FKind := AKind;
end;

procedure TSdModuleBridge.Tell(Code: TNotifyCode);
begin
  if FOwner <> nil then FOwner.Notify(Code);
end;

procedure TSdModuleBridge.AfterSave;
begin
  if FKind = 0 then Tell(ncAfterSave);
end;

procedure TSdModuleBridge.BeforeSave;
begin
  if FKind = 0 then Tell(ncBeforeSave);
end;

{ the module goes (the editors' lists hear it before the module's) }
procedure TSdModuleBridge.Destroyed;
var
  O: TSdModuleIntf;
begin
  if FKind <> 0 then Exit;
  O := FOwner;
  FOwner := nil;
  if O <> nil then O.ModuleGone;
end;

{ the module's own Modified comes with both editors': the editors tell which part changed }
procedure TSdModuleBridge.Modified;
begin
  case FKind of
    1: Tell(ncEditorModified);
    2: Tell(ncFormModified);
  end;
end;

function TSdModuleBridge.CheckOverwrite: Boolean;
begin
  Result := True;
end;

procedure TSdModuleBridge.ModuleRenamed(const NewName: string);
begin
  if FKind = 0 then Tell(ncModuleRenamed);
end;

procedure TSdModuleBridge.ViewNotification(const View: IOTAEditView; Operation: TOperation);
begin
end;

procedure TSdModuleBridge.ViewActivated(const View: IOTAEditView);
begin
  if FKind = 1 then Tell(ncEditorSelected);
end;

procedure TSdModuleBridge.FormActivated;
begin
  if FKind = 2 then Tell(ncFormSelected);
end;

procedure TSdModuleBridge.FormSaving;
begin
  if FKind = 2 then Tell(ncFormSaving);
end;

procedure TSdModuleBridge.ComponentRenamed(ComponentHandle: TOTAHandle; const OldName, NewName: string);
begin
end;

{ ---------------------------------------------------------------- TSdModuleIntf }

constructor TSdModuleIntf.Create(AModule: TSdOtaModule);
begin
  inherited Create;
  FModule := AModule;
  FModuleRef := AModule;
  FNotifiers := TList.Create;
  { the module's own list from the start: its end (Destroyed) ends this object's use }
  Bridge(0);
end;

destructor TSdModuleIntf.Destroy;
begin
  Unbridge;
  Intfs.Remove(Self);
  FNotifiers.Free;
  FModuleRef := nil;
  inherited;
end;

procedure TSdModuleIntf.Bridge(Kind: Integer);
var
  B: TSdModuleBridge;
begin
  if (FModule = nil) or (FBridges[Kind] <> nil) then Exit;
  B := TSdModuleBridge.Create(Self, Kind);
  FBridgeObjs[Kind] := B;
  FBridges[Kind] := B;
  case Kind of
    0: FModule.Notifiers.Add(FBridges[Kind]);
    1: FModule.SourceNotifiers.Add(FBridges[Kind]);
    2:
      begin
        FModule.FormNotifiers.Add(FBridges[Kind]);
        { the designers' changes reach the forms' notifiers from the first one on }
        OtaModules.NeedDesignNotes;
      end;
  end;
end;

procedure TSdModuleIntf.Unbridge;
var
  K: Integer;
begin
  for K := 0 to 2 do
    if FBridges[K] <> nil then
    begin
      TSdModuleBridge(FBridgeObjs[K]).FOwner := nil;
      if FModule <> nil then
        case K of
          0: FModule.Notifiers.RemoveItem(FBridges[K]);
          1: FModule.SourceNotifiers.RemoveItem(FBridges[K]);
          2: FModule.FormNotifiers.RemoveItem(FBridges[K]);
        end;
      FBridges[K] := nil;
      FBridgeObjs[K] := nil;
    end;
end;

procedure ModuleNotifyOne(Obj: TObject; Data: Pointer);
begin
  TIModuleNotifier(Obj).Notify(TNotifyCode(Integer(Data)));
end;

{ the old notifiers, the newest first; one that an earlier one removed is not called }
procedure TSdModuleIntf.Notify(Code: TNotifyCode);
begin
  if FNotifiers.Count = 0 then Exit;
  AddRef;
  try
    LegacyEach(FNotifiers, ModuleNotifyOne, Pointer(Ord(Code)), True, 'TIModuleNotifier.Notify');
  finally
    Release;
  end;
end;

{ the module went: its notifiers hear ncModuleDeleted, then the object lets go of the module and
  the list of module interfaces lets go of the object (an expert's reference keeps it) }
procedure TSdModuleIntf.ModuleGone;
begin
  if FModule = nil then Exit;
  AddRef;
  try
    Notify(ncModuleDeleted);
    Unbridge;
    FModule := nil;
    FModuleRef := nil;
    if Intfs.IndexOf(Self) >= 0 then
    begin
      Intfs.Remove(Self);
      Release;
    end;
  finally
    Release;
  end;
end;

function TSdModuleIntf.NotifierCount: Integer;
begin
  Result := FNotifiers.Count;
end;

procedure TSdModuleIntf.DropModule(Module: HMODULE);
var
  I: Integer;
begin
  for I := FNotifiers.Count - 1 downto 0 do
    if ObjectModule(TObject(FNotifiers[I])) = Module then FNotifiers.Delete(I);
end;

function TSdModuleIntf.GetEditorInterface: TIEditorInterface;
var
  E: IOTASourceEditor;
begin
  Result := nil;
  try
    if FModule = nil then Exit;
    E := FModule.SourceEditor;
    if E <> nil then Result := TSdEditorIntf.Create(E);
  except
    LegacyFailed('TIModuleInterface.GetEditorInterface');
  end;
end;

{ Delphi 7 has no form interface: nil }
function TSdModuleIntf.GetFormInterface: TIFormInterface;
begin
  Result := nil;
end;

function TSdModuleIntf.GetAncestorModule: TIModuleInterface;
begin
  Result := nil;
end;

function TSdModuleIntf.GetProjectResource: TIResourceFile;
var
  R: IOTAProjectResource;
begin
  Result := nil;
  try
    if not (FModule is TSdOtaProject) then Exit;
    R := OtaModules.ProjectResource(FModule.FileName);
    if R <> nil then Result := TSdResourceFileIntf.Create(R);
  except
    LegacyFailed('TIModuleInterface.GetProjectResource');
  end;
end;

function TSdModuleIntf.IsProjectModule: Boolean;
begin
  Result := FModule is TSdOtaProject;
end;

{ without asking (Delphi's Close: Save first to keep the changes) }
function TSdModuleIntf.Close: Boolean;
var
  M: IOTAModule;
begin
  Result := False;
  AddRef;
  try
    try
      M := FModuleRef;
      if M <> nil then Result := M.CloseModule(True);
    except
      LegacyFailed('TIModuleInterface.Close');
    end;
  finally
    Release;
  end;
end;

function TSdModuleIntf.Save(ForceSave: Boolean): Boolean;
var
  M: IOTAModule;
begin
  Result := False;
  AddRef;
  try
    try
      M := FModuleRef;
      if M <> nil then Result := M.Save(False, ForceSave);
    except
      LegacyFailed('TIModuleInterface.Save');
    end;
  finally
    Release;
  end;
end;

{ saved under the new name (its form file follows): ncModuleRenamed }
function TSdModuleIntf.Rename(const NewName: string): Boolean;
var
  M: IOTAModule;
begin
  Result := False;
  AddRef;
  try
    try
      M := FModuleRef;
      if (M = nil) or (NewName = '') then Exit;
      M.SetFileName(NewName);
      Result := SameText(M.FileName, NewName) or SameText(M.FileName, ExpandFileName(NewName));
    except
      LegacyFailed('TIModuleInterface.Rename');
    end;
  finally
    Release;
  end;
end;

function TSdModuleIntf.GetFileSystem(var FileSystem: string): Boolean;
begin
  Result := False;
  try
    if FModuleRef = nil then Exit;
    FileSystem := FModuleRef.GetFileSystem;
    Result := True;
  except
    LegacyFailed('TIModuleInterface.GetFileSystem');
  end;
end;

{ the default file system only: a module is read and written where it was opened }
function TSdModuleIntf.SetFileSystem(const FileSystem: string): Boolean;
var
  Cur: string;
begin
  Result := False;
  try
    if FModuleRef = nil then Exit;
    Cur := FModuleRef.GetFileSystem;
    Result := SameText(Cur, FileSystem);
  except
    LegacyFailed('TIModuleInterface.SetFileSystem');
  end;
end;

function TSdModuleIntf.ShowSource: Boolean;
var
  E: IOTASourceEditor;
begin
  Result := False;
  AddRef;
  try
    try
      if FModule = nil then Exit;
      E := FModule.SourceEditor;
      if E = nil then Exit;
      E.Show;
      Result := True;
    except
      LegacyFailed('TIModuleInterface.ShowSource');
    end;
  finally
    Release;
  end;
end;

function TSdModuleIntf.ShowForm: Boolean;
var
  E: IOTAFormEditor;
begin
  Result := False;
  AddRef;
  try
    try
      if FModule = nil then Exit;
      E := FModule.FormEditor;
      if E = nil then Exit;
      E.Show;
      Result := True;
    except
      LegacyFailed('TIModuleInterface.ShowForm');
    end;
  finally
    Release;
  end;
end;

{ appended as Delphi 7 does (no reference taken, added again when added twice); the module's
  editors' events reach the old notifiers from the first one on }
function TSdModuleIntf.AddNotifier(AModuleNotifier: TIModuleNotifier): Boolean;
begin
  Result := False;
  try
    if (AModuleNotifier = nil) or (FModule = nil) then Exit;
    FNotifiers.Add(AModuleNotifier);
    Bridge(1);
    Bridge(2);
    Result := True;
  except
    LegacyFailed('TIModuleInterface.AddNotifier');
  end;
end;

function TSdModuleIntf.RemoveNotifier(AModuleNotifier: TIModuleNotifier): Boolean;
var
  I: Integer;
begin
  I := FNotifiers.IndexOf(AModuleNotifier);
  Result := I >= 0;
  if Result then FNotifiers.Delete(I);
end;

{ C++Builder's header or the project's option file: none }
function TSdModuleIntf.GetAuxEditorInterface: TIEditorInterface;
begin
  Result := nil;
end;

function LegacyModuleIntf(M: TSdOtaModule): TSdModuleIntf;
var
  I: Integer;
begin
  Result := nil;
  if M = nil then Exit;
  for I := 0 to Intfs.Count - 1 do
    if TSdModuleIntf(Intfs[I]).FModule = M then
    begin
      Result := TSdModuleIntf(Intfs[I]);
      Exit;
    end;
  Result := TSdModuleIntf.Create(M);
  Intfs.Add(Result);
end;

function LegacyModuleInterface(const FileName: string): TIModuleInterface;
var
  Name: string;
  M: TSdOtaModule;
begin
  Result := nil;
  if (FileName = '') or (OtaModules = nil) then Exit;
  Name := FileName;
  { a form file is its unit's module }
  if SameText(ExtractFileExt(Name), '.dfm') then Name := ChangeFileExt(Name, '.pas');
  M := OtaModules.Find(Name);
  if M = nil then Exit;
  Result := LegacyModuleIntf(M);
  Result.AddRef;
end;

function LegacyFormModuleInterface(const FormName: string): TIModuleInterface;
var
  I: IOTAModule;
  M: TSdOtaModule;
begin
  Result := nil;
  if OtaModules = nil then Exit;
  I := OtaModules.FindFormModule(FormName);
  if I = nil then Exit;
  M := OtaModules.Find(I.FileName, False);
  if M = nil then Exit;
  Result := LegacyModuleIntf(M);
  Result.AddRef;
end;

function LegacyModuleNotifierCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Intfs.Count - 1 do Inc(Result, TSdModuleIntf(Intfs[I]).NotifierCount);
end;

{ ---------------------------------------------------------------- TSdEditorIntf }

constructor TSdEditorIntf.Create(const AEditor: IOTASourceEditor);
begin
  inherited Create;
  FEditor := AEditor;
end;

function TSdEditorIntf.CreateReader: TIEditReader;
var
  R: IOTAEditReader;
begin
  Result := nil;
  try
    R := FEditor.CreateReader;
    if R <> nil then Result := TSdEditReaderIntf.Create(R);
  except
    LegacyFailed('TIEditorInterface.CreateReader');
  end;
end;

function TSdEditorIntf.CreateWriter: TIEditWriter;
var
  W: IOTAEditWriter;
begin
  Result := nil;
  try
    W := FEditor.CreateWriter;
    if W <> nil then Result := TSdEditWriterIntf.Create(W);
  except
    LegacyFailed('TIEditorInterface.CreateWriter');
  end;
end;

function TSdEditorIntf.CreateUndoableWriter: TIEditWriter;
var
  W: IOTAEditWriter;
begin
  Result := nil;
  try
    W := FEditor.CreateUndoableWriter;
    if W <> nil then Result := TSdEditWriterIntf.Create(W);
  except
    LegacyFailed('TIEditorInterface.CreateUndoableWriter');
  end;
end;

function TSdEditorIntf.FileName: string;
begin
  Result := '';
  try
    Result := FEditor.FileName;
  except
    LegacyFailed('TIEditorInterface.FileName');
  end;
end;

function TSdEditorIntf.LinesInBuffer: Longint;
begin
  Result := 0;
  try
    Result := FEditor.GetLinesInBuffer;
  except
    LegacyFailed('TIEditorInterface.LinesInBuffer');
  end;
end;

function TSdEditorIntf.BufferModified: Boolean;
begin
  Result := False;
  try
    Result := FEditor.Modified;
  except
    LegacyFailed('TIEditorInterface.BufferModified');
  end;
end;

function TSdEditorIntf.MarkModified: Boolean;
begin
  Result := False;
  try
    FEditor.MarkModified;
    Result := True;
  except
    LegacyFailed('TIEditorInterface.MarkModified');
  end;
end;

{ EditIntf's highlighters are ordered otherwise than the Open Tools API's: shNone, shPascal, shC,
  shSQL, shQuery (only asks) }
function TSdEditorIntf.SetSyntaxHighlighter(SyntaxHighlighter: TSyntaxHighlighter): TSyntaxHighlighter;
const
  ToNew: array[TSyntaxHighlighter] of TOTASyntaxHighlighter = (ToolsAPI.shNone, ToolsAPI.shPascal,
    ToolsAPI.shC, ToolsAPI.shSQL, ToolsAPI.shQuery);
var
  R: TOTASyntaxHighlighter;
begin
  Result := EditIntf.shNone;
  try
    R := FEditor.SetSyntaxHighlighter(ToNew[SyntaxHighlighter]);
    case R of
      ToolsAPI.shPascal: Result := EditIntf.shPascal;
      ToolsAPI.shC: Result := EditIntf.shC;
      ToolsAPI.shSQL: Result := EditIntf.shSQL;
    else
      Result := EditIntf.shNone;
    end;
  except
    LegacyFailed('TIEditorInterface.SetSyntaxHighlighter');
  end;
end;

function TSdEditorIntf.GetViewCount: Integer;
begin
  Result := 0;
  try
    Result := FEditor.EditViewCount;
  except
    LegacyFailed('TIEditorInterface.GetViewCount');
  end;
end;

function TSdEditorIntf.GetView(Index: Integer): TIEditView;
var
  V: IOTAEditView;
begin
  Result := nil;
  try
    if (Index < 0) or (Index >= FEditor.EditViewCount) then Exit;
    V := FEditor.EditViews[Index];
    if V <> nil then Result := TSdEditViewIntf.Create(V);
  except
    LegacyFailed('TIEditorInterface.GetView');
  end;
end;

function TSdEditorIntf.GetBlockAfter: TCharPos;
begin
  Result.CharIndex := 0;
  Result.Line := 0;
  try
    Result := OldCharPos(FEditor.BlockAfter);
  except
    LegacyFailed('TIEditorInterface.GetBlockAfter');
  end;
end;

function TSdEditorIntf.GetBlockStart: TCharPos;
begin
  Result.CharIndex := 0;
  Result.Line := 0;
  try
    Result := OldCharPos(FEditor.BlockStart);
  except
    LegacyFailed('TIEditorInterface.GetBlockStart');
  end;
end;

function TSdEditorIntf.GetBlockType: TBlockType;
begin
  Result := EditIntf.btUnknown;
  try
    Result := TBlockType(Ord(FEditor.BlockType));
  except
    LegacyFailed('TIEditorInterface.GetBlockType');
  end;
end;

function TSdEditorIntf.GetBlockVisible: Boolean;
begin
  Result := False;
  try
    Result := FEditor.BlockVisible;
  except
    LegacyFailed('TIEditorInterface.GetBlockVisible');
  end;
end;

procedure TSdEditorIntf.SetBlockAfter(Value: TCharPos);
begin
  try
    FEditor.BlockAfter := NewCharPos(Value);
  except
    LegacyFailed('TIEditorInterface.SetBlockAfter');
  end;
end;

procedure TSdEditorIntf.SetBlockStart(Value: TCharPos);
begin
  try
    FEditor.BlockStart := NewCharPos(Value);
  except
    LegacyFailed('TIEditorInterface.SetBlockStart');
  end;
end;

procedure TSdEditorIntf.SetBlockType(Value: TBlockType);
begin
  try
    if Value < EditIntf.btUnknown then FEditor.BlockType := TOTABlockType(Ord(Value));
  except
    LegacyFailed('TIEditorInterface.SetBlockType');
  end;
end;

procedure TSdEditorIntf.SetBlockVisible(Value: Boolean);
begin
  try
    FEditor.BlockVisible := Value;
  except
    LegacyFailed('TIEditorInterface.SetBlockVisible');
  end;
end;

{ ---------------------------------------------------------------- TSdEditViewIntf }

constructor TSdEditViewIntf.Create(const AView: IOTAEditView);
begin
  inherited Create;
  FView := AView;
end;

function TSdEditViewIntf.GetPos(Index: Integer): TEditPos;
begin
  Result.Col := 0;
  Result.Line := 0;
  try
    case Index of
      EditIntf.cursorPos: Result := OldEditPos(FView.CursorPos);
      EditIntf.ViewTopPos: Result := OldEditPos(FView.TopPos);
    end;
  except
    LegacyFailed('TIEditView.GetPos');
  end;
end;

procedure TSdEditViewIntf.SetPos(Index: Integer; Value: TEditPos);
begin
  try
    case Index of
      EditIntf.cursorPos: FView.CursorPos := NewEditPos(Value);
      EditIntf.ViewTopPos: FView.TopPos := NewEditPos(Value);
    end;
  except
    LegacyFailed('TIEditView.SetPos');
  end;
end;

function TSdEditViewIntf.GetViewSize: TSize;
begin
  Result.cx := 0;
  Result.cy := 0;
  try
    Result := FView.ViewSize;
  except
    LegacyFailed('TIEditView.GetViewSize');
  end;
end;

function TSdEditViewIntf.PosToCharPos(Pos: Longint): TCharPos;
begin
  Result.CharIndex := 0;
  Result.Line := 0;
  try
    Result := OldCharPos(FView.PosToCharPos(Pos));
  except
    LegacyFailed('TIEditView.PosToCharPos');
  end;
end;

function TSdEditViewIntf.CharPosToPos(CharPos: TCharPos): Longint;
begin
  Result := -1;
  try
    Result := FView.CharPosToPos(NewCharPos(CharPos));
  except
    LegacyFailed('TIEditView.CharPosToPos');
  end;
end;

procedure TSdEditViewIntf.ConvertPos(EdPosToCharPos: Boolean; var EditPos: TEditPos; var CharPos: TCharPos);
var
  E: TOTAEditPos;
  C: TOTACharPos;
begin
  try
    E := NewEditPos(EditPos);
    C := NewCharPos(CharPos);
    FView.ConvertPos(EdPosToCharPos, E, C);
    EditPos := OldEditPos(E);
    CharPos := OldCharPos(C);
  except
    LegacyFailed('TIEditView.ConvertPos');
  end;
end;

procedure TSdEditViewIntf.GetAttributeAtPos(const EdPos: TEditPos; var Element, LineFlag: Integer);
begin
  try
    FView.GetAttributeAtPos(NewEditPos(EdPos), True, Element, LineFlag);
  except
    LegacyFailed('TIEditView.GetAttributeAtPos');
  end;
end;

{ ---------------------------------------------------------------- reader and writer }

constructor TSdEditReaderIntf.Create(const AReader: IOTAEditReader);
begin
  inherited Create;
  FReader := AReader;
end;

function TSdEditReaderIntf.GetText(Position: Longint; Buffer: PChar; Count: Longint): Longint;
begin
  Result := -1;
  try
    Result := FReader.GetText(Position, Buffer, Count);
  except
    LegacyFailed('TIEditReader.GetText');
  end;
end;

constructor TSdEditWriterIntf.Create(const AWriter: IOTAEditWriter);
begin
  inherited Create;
  FWriter := AWriter;
end;

function TSdEditWriterIntf.CopyTo(Pos: Longint): Boolean;
begin
  Result := False;
  try
    FWriter.CopyTo(Pos);
    Result := True;
  except
    LegacyFailed('TIEditWriter.CopyTo');
  end;
end;

function TSdEditWriterIntf.DeleteTo(Pos: Longint): Boolean;
begin
  Result := False;
  try
    FWriter.DeleteTo(Pos);
    Result := True;
  except
    LegacyFailed('TIEditWriter.DeleteTo');
  end;
end;

function TSdEditWriterIntf.Insert(Text: PChar): Boolean;
begin
  Result := False;
  try
    FWriter.Insert(Text);
    Result := True;
  except
    LegacyFailed('TIEditWriter.Insert');
  end;
end;

function TSdEditWriterIntf.Position: Longint;
begin
  Result := -1;
  try
    Result := FWriter.Position;
  except
    LegacyFailed('TIEditWriter.Position');
  end;
end;

function TSdEditWriterIntf.GetCurrentPos: TCharPos;
begin
  Result.CharIndex := 0;
  Result.Line := 0;
  try
    Result := OldCharPos(FWriter.CurrentPos);
  except
    LegacyFailed('TIEditWriter.GetCurrentPos');
  end;
end;

{ ---------------------------------------------------------------- resources }

constructor TSdResourceEntryIntf.Create(const AEntry: IOTAResourceEntry);
begin
  inherited Create;
  FEntry := AEntry;
end;

function TSdResourceEntryIntf.GetResourceType: PChar;
begin
  Result := nil;
  try
    Result := FEntry.GetResourceType;
  except
    LegacyFailed('TIResourceEntry.GetResourceType');
  end;
end;

function TSdResourceEntryIntf.GetResourceName: PChar;
begin
  Result := nil;
  try
    Result := FEntry.GetResourceName;
  except
    LegacyFailed('TIResourceEntry.GetResourceName');
  end;
end;

function TSdResourceEntryIntf.Change(NewType, NewName: PChar): Boolean;
begin
  Result := False;
  try
    Result := FEntry.Change(NewType, NewName);
  except
    LegacyFailed('TIResourceEntry.Change');
  end;
end;

function TSdResourceEntryIntf.GetHeaderValue(HeaderValue: TResHeaderValue; var Value: Integer): Boolean;
begin
  Result := False;
  try
    Result := FEntry.GetHeaderValue(TOTAResHeaderValue(Ord(HeaderValue)), Value);
  except
    LegacyFailed('TIResourceEntry.GetHeaderValue');
  end;
end;

function TSdResourceEntryIntf.SetHeaderValue(HeaderValue: TResHeaderValue; Value: Integer): Boolean;
begin
  Result := False;
  try
    Result := FEntry.SetHeaderValue(TOTAResHeaderValue(Ord(HeaderValue)), Value);
  except
    LegacyFailed('TIResourceEntry.SetHeaderValue');
  end;
end;

function TSdResourceEntryIntf.GetData: Pointer;
begin
  Result := nil;
  try
    Result := FEntry.GetData;
  except
    LegacyFailed('TIResourceEntry.GetData');
  end;
end;

function TSdResourceEntryIntf.GetDataSize: Integer;
begin
  Result := 0;
  try
    Result := FEntry.GetDataSize;
  except
    LegacyFailed('TIResourceEntry.GetDataSize');
  end;
end;

function TSdResourceEntryIntf.SetDataSize(NewSize: Integer): Boolean;
begin
  Result := False;
  try
    FEntry.SetDataSize(NewSize);
    Result := True;
  except
    LegacyFailed('TIResourceEntry.SetDataSize');
  end;
end;

function TSdResourceEntryIntf.GetEntryHandle: Pointer;
begin
  Result := nil;
  try
    Result := Pointer(FEntry.GetEntryHandle);
  except
    LegacyFailed('TIResourceEntry.GetEntryHandle');
  end;
end;

constructor TSdResourceFileIntf.Create(const ARes: IOTAProjectResource);
begin
  inherited Create;
  FRes := ARes;
end;

function TSdResourceFileIntf.FileName: string;
begin
  Result := '';
  try
    Result := FRes.FileName;
  except
    LegacyFailed('TIResourceFile.FileName');
  end;
end;

function TSdResourceFileIntf.GetEntryCount: Integer;
begin
  Result := 0;
  try
    Result := FRes.GetEntryCount;
  except
    LegacyFailed('TIResourceFile.GetEntryCount');
  end;
end;

function EntryIntf(const E: IOTAResourceEntry): TIResourceEntry;
begin
  if E = nil then Result := nil else Result := TSdResourceEntryIntf.Create(E);
end;

function TSdResourceFileIntf.GetEntry(Index: Integer): TIResourceEntry;
begin
  Result := nil;
  try
    Result := EntryIntf(FRes.GetEntry(Index));
  except
    LegacyFailed('TIResourceFile.GetEntry');
  end;
end;

function TSdResourceFileIntf.GetEntryFromHandle(EntryHandle: Pointer): TIResourceEntry;
begin
  Result := nil;
  try
    Result := EntryIntf(FRes.GetEntryFromHandle(TOTAHandle(EntryHandle)));
  except
    LegacyFailed('TIResourceFile.GetEntryFromHandle');
  end;
end;

function TSdResourceFileIntf.FindEntry(ResType, Name: PChar): TIResourceEntry;
begin
  Result := nil;
  try
    Result := EntryIntf(FRes.FindEntry(ResType, Name));
  except
    LegacyFailed('TIResourceFile.FindEntry');
  end;
end;

function TSdResourceFileIntf.DeleteEntry(EntryHandle: Pointer): Boolean;
begin
  Result := False;
  try
    FRes.DeleteEntry(TOTAHandle(EntryHandle));
    Result := True;
  except
    LegacyFailed('TIResourceFile.DeleteEntry');
  end;
end;

function TSdResourceFileIntf.CreateEntry(ResType, Name: PChar; Flags, LanguageId: Word;
  DataVersion, Version, Characteristics: Integer): TIResourceEntry;
begin
  Result := nil;
  try
    Result := EntryIntf(FRes.CreateEntry(ResType, Name, Flags, LanguageId, DataVersion, Version, Characteristics));
  except
    LegacyFailed('TIResourceFile.CreateEntry');
  end;
end;

{ ---------------------------------------------------------------- file systems }

constructor TSdOldFileSystem.Create(AOld: TIVirtualFileSystem);
begin
  inherited Create;
  FOld := AOld;
  FModule := ObjectModule(AOld);
  FIndex := -1;
  FOld.AddRef;
  OldFileSystems.Add(Self);
end;

destructor TSdOldFileSystem.Destroy;
begin
  OldFileSystems.Remove(Self);
  try
    FOld.Free;
  except
    OtaCaught('TIVirtualFileSystem released', False);
  end;
  inherited;
end;

function TSdOldFileSystem.GetFileStream(const FileName: string; Mode: Integer): IStream;
begin
  try
    Result := FOld.GetFileStream(FileName, Mode);
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdOldFileSystem.FileAge(const FileName: string): Longint;
begin
  try
    Result := FOld.FileAge(FileName);
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdOldFileSystem.RenameFile(const OldName, NewName: string): Boolean;
begin
  try
    Result := FOld.RenameFile(OldName, NewName);
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdOldFileSystem.IsReadonly(const FileName: string): Boolean;
begin
  try
    Result := FOld.IsReadonly(FileName);
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdOldFileSystem.IsFileBased: Boolean;
begin
  try
    Result := FOld.IsFileBased;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdOldFileSystem.DeleteFile(const FileName: string): Boolean;
begin
  try
    Result := FOld.DeleteFile(FileName);
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdOldFileSystem.FileExists(const FileName: string): Boolean;
begin
  try
    Result := FOld.FileExists(FileName);
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdOldFileSystem.GetTempFileName(const FileName: string): string;
begin
  try
    Result := FOld.GetTempFileName(FileName);
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdOldFileSystem.GetBackupFileName(const FileName: string): string;
begin
  try
    Result := FOld.GetBackupFileName(FileName);
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdOldFileSystem.GetIDString: string;
begin
  try
    Result := FOld.GetIDString;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

constructor TSdFileSystemIntf.Create(const ANew: IOTAFileSystem);
begin
  inherited Create;
  FNew := ANew;
end;

function TSdFileSystemIntf.GetFileStream(const FileName: TFileName; Mode: Integer): IStream;
begin
  Result := nil;
  try
    Result := FNew.GetFileStream(FileName, Mode);
  except
    LegacyFailed('TIVirtualFileSystem.GetFileStream');
  end;
end;

function TSdFileSystemIntf.FileAge(const FileName: TFileName): Longint;
begin
  Result := -1;
  try
    Result := FNew.FileAge(FileName);
  except
    LegacyFailed('TIVirtualFileSystem.FileAge');
  end;
end;

function TSdFileSystemIntf.RenameFile(const OldName, NewName: TFileName): Boolean;
begin
  Result := False;
  try
    Result := FNew.RenameFile(OldName, NewName);
  except
    LegacyFailed('TIVirtualFileSystem.RenameFile');
  end;
end;

function TSdFileSystemIntf.IsReadonly(const FileName: TFileName): Boolean;
begin
  Result := False;
  try
    Result := FNew.IsReadonly(FileName);
  except
    LegacyFailed('TIVirtualFileSystem.IsReadonly');
  end;
end;

function TSdFileSystemIntf.IsFileBased: Boolean;
begin
  Result := False;
  try
    Result := FNew.IsFileBased;
  except
    LegacyFailed('TIVirtualFileSystem.IsFileBased');
  end;
end;

function TSdFileSystemIntf.DeleteFile(const FileName: TFileName): Boolean;
begin
  Result := False;
  try
    Result := FNew.DeleteFile(FileName);
  except
    LegacyFailed('TIVirtualFileSystem.DeleteFile');
  end;
end;

function TSdFileSystemIntf.FileExists(const FileName: TFileName): Boolean;
begin
  Result := False;
  try
    Result := FNew.FileExists(FileName);
  except
    LegacyFailed('TIVirtualFileSystem.FileExists');
  end;
end;

function TSdFileSystemIntf.GetTempFileName(const FileName: TFileName): TFileName;
begin
  Result := '';
  try
    Result := FNew.GetTempFileName(FileName);
  except
    LegacyFailed('TIVirtualFileSystem.GetTempFileName');
  end;
end;

function TSdFileSystemIntf.GetBackupFileName(const FileName: TFileName): TFileName;
begin
  Result := '';
  try
    Result := FNew.GetBackupFileName(FileName);
  except
    LegacyFailed('TIVirtualFileSystem.GetBackupFileName');
  end;
end;

function TSdFileSystemIntf.GetIDString: string;
begin
  Result := '';
  try
    Result := FNew.GetIDString;
  except
    LegacyFailed('TIVirtualFileSystem.GetIDString');
  end;
end;

function ModuleServices: IOTAModuleServices;
begin
  if not Supports(BorlandIDEServices, IOTAModuleServices, Result) then Result := nil;
end;

function LegacyRegisterFileSystem(FS: TIVirtualFileSystem): Boolean;
var
  A: TSdOldFileSystem;
  Ref: IOTAFileSystem;
  MS: IOTAModuleServices;
begin
  Result := False;
  MS := ModuleServices;
  if (FS = nil) or (MS = nil) then Exit;
  A := TSdOldFileSystem.Create(FS);
  Ref := A;
  A.FIndex := MS.AddFileSystem(Ref);
  Result := A.FIndex >= 0;
end;

{ An adapter taken out keeps no index (-1): it may live on while something still holds it (the
  TSdFileSystemIntf of GetFileSystem). Its place in the services' list is looked up, not taken from
  AddFileSystem: the list moves the later file systems one index down when one goes, as Delphi 7's,
  and a kept index may be another expert's file system's by now. }
procedure RemoveOldFileSystem(A: TSdOldFileSystem; const MS: IOTAModuleServices);
var
  K: Integer;
begin
  A.FIndex := -1;
  if OtaFileSystemList = nil then Exit;
  K := OtaFileSystemList.IndexOfItem(A);
  if K >= 0 then MS.RemoveFileSystem(K);      // the last reference to A may go here
end;

function LegacyUnregisterFileSystem(const Ident: string): Boolean;
var
  I: Integer;
  A: TSdOldFileSystem;
  MS: IOTAModuleServices;
begin
  Result := True;
  MS := ModuleServices;
  if MS = nil then Exit;
  for I := OldFileSystems.Count - 1 downto 0 do
    if I < OldFileSystems.Count then
    begin
      A := TSdOldFileSystem(OldFileSystems[I]);
      if (A.FIndex >= 0) and SameText(A.GetIDString, Ident) then RemoveOldFileSystem(A, MS);
    end;
end;

function LegacyGetFileSystem(const Ident: string): TIVirtualFileSystem;
var
  F: IOTAFileSystem;
  MS: IOTAModuleServices;
begin
  Result := nil;
  MS := ModuleServices;
  if MS = nil then Exit;
  { FindFileSystem raises for an ID no file system has: none then }
  try
    F := MS.FindFileSystem(Ident);
  except
    on Exception do F := nil;
  end;
  if F <> nil then Result := TSdFileSystemIntf.Create(F);
end;

function LegacyFileSystemCount: Integer;
begin
  Result := OldFileSystems.Count;
end;

procedure LegacyModulesDropModule(Module: HMODULE);
var
  I: Integer;
  A: TSdOldFileSystem;
  MS: IOTAModuleServices;
begin
  if Module = 0 then Exit;
  for I := 0 to Intfs.Count - 1 do TSdModuleIntf(Intfs[I]).DropModule(Module);
  MS := ModuleServices;
  for I := OldFileSystems.Count - 1 downto 0 do
    if I < OldFileSystems.Count then
    begin
      A := TSdOldFileSystem(OldFileSystems[I]);
      if A.FModule <> Module then Continue;
      if (MS <> nil) and (A.FIndex >= 0) then RemoveOldFileSystem(A, MS);
    end;
end;

{ ---------------------------------------------------------------- creators }

constructor TSdStreamFile.Create(const ASource: string);
begin
  inherited Create;
  FSource := ASource;
end;

function TSdStreamFile.GetSource: string;
begin
  Result := FSource;
end;

function TSdStreamFile.GetAge: TDateTime;
begin
  Result := -1;
end;

function StreamFile(const Source: string): IOTAFile;
begin
  if Source = '' then Result := nil else Result := TSdStreamFile.Create(Source);
end;

{ the class of a new module's ancestor, named with its T (TService) or without it (Service, as the
  creators of Delphi 1-3 name it): a data module, or a custom module of a package }
function AncestorClassOf(const AncestorIdent: string): TComponentClass;

  function Named(const N: string): TComponentClass;
  begin
    if SameText(N, 'TDataModule') then Result := TDataModule
    else if DesignHost <> nil then Result := DesignHost.CustomModuleClass(N)
    else Result := nil;
  end;

begin
  Result := nil;
  if AncestorIdent = '' then Exit;
  Result := Named('T' + AncestorIdent);
  if Result = nil then Result := Named(AncestorIdent);
end;

{ an ancestor's name without the T of its class (TService -> Service): the base of a new module's
  name }
function AncestorBase(const AncestorIdent: string): string;
begin
  Result := AncestorIdent;
  if (Length(Result) > 1) and (UpCase(Result[1]) = 'T') and (Result[2] in ['A'..'Z']) then Delete(Result, 1, 1);
end;

function LegacyAncestorDfm(const FormIdent, AncestorIdent: string): string;
var
  Cls: TComponentClass;
  Inst: TDataModule;
  Bin, Txt: TMemoryStream;
  L: TStringList;
  S: string;
begin
  Result := '';
  if FormIdent = '' then Exit;
  Cls := AncestorClassOf(AncestorIdent);
  if (Cls = nil) or not Cls.InheritsFrom(TDataModule) then Exit;
  Inst := TDataModuleClassRef(Cls).CreateNew(nil, 0);
  try
    Inst.Name := FormIdent;
    { the place and size of a new module's window (Delphi's GetFormBounds(btCustomModule)): Left
      and Top, Height and Width of its form file }
    Inst.DesignInfo := MakeLong(192, 107);
    Inst.DesignSize := Point(215, 150);
    Bin := TMemoryStream.Create;
    Txt := TMemoryStream.Create;
    L := TStringList.Create;
    try
      Bin.WriteComponent(Inst);
      Bin.Position := 0;
      ObjectBinaryToText(Bin, Txt);
      SetString(S, PChar(Txt.Memory), Txt.Size);
      L.Text := S;
      { the new module's class: its own (T + the name), not the ancestor's }
      if L.Count > 0 then L[0] := 'object ' + FormIdent + ': T' + FormIdent;
      Result := L.Text;
    finally
      L.Free;
      Txt.Free;
      Bin.Free;
    end;
  finally
    Inst.Free;
  end;
end;

constructor TSdLegacyModuleCreator.Create(ACreator: TIModuleCreator; AFlags: TCreateModuleFlags);
begin
  inherited Create;
  FCreator := ACreator;
  FFlags := AFlags;
  try
    FAncestor := FCreator.GetAncestorName;
    FFormName := FCreator.GetFormName;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
  { a module with an ancestor and no form name gets one after its ancestor: Service1 (Delphi 7's
    names of new modules) }
  if (FFormName = '') and (FAncestor <> '') and (OtaHost <> nil) then
    FFormName := OtaHost.UniqueRootName(AncestorBase(FAncestor));
  if (FAncestor = '') and (FFormName <> '') then FAncestor := 'Form';
end;

function TSdLegacyModuleCreator.GetCreatorType: string;
begin
  if FFormName <> '' then Result := sForm else Result := sUnit;
end;

function TSdLegacyModuleCreator.GetExisting: Boolean;
begin
  try
    Result := (cmExisting in FFlags) or FCreator.Existing;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdLegacyModuleCreator.GetFileSystem: string;
begin
  try
    Result := FCreator.GetFileSystem;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdLegacyModuleCreator.GetOwner: IOTAModule;
begin
  Result := nil;
  if (cmAddToProject in FFlags) and (OtaHost <> nil) and (OtaHost.Project <> nil) then
    Result := OtaModules.ModuleIntf(OtaHost.Project.FileName);
end;

{ an unnamed module that joins the project is written under its new name, as D7 Studio's New
  Form writes a new form into the project's folder }
function TSdLegacyModuleCreator.GetUnnamed: Boolean;
begin
  Result := (cmUnNamed in FFlags) and (GetOwner = nil);
end;

{ without the T of its class: the IDE adds it (TService1 = class(TService)) }
function TSdLegacyModuleCreator.GetAncestorName: string;
begin
  Result := AncestorBase(FAncestor);
end;

function TSdLegacyModuleCreator.GetImplFileName: string;
begin
  try
    Result := FCreator.GetFileName;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdLegacyModuleCreator.GetIntfFileName: string;
begin
  Result := '';
end;

function TSdLegacyModuleCreator.GetFormName: string;
begin
  Result := FFormName;
end;

function TSdLegacyModuleCreator.GetMainForm: Boolean;
begin
  Result := cmMainForm in FFlags;
end;

function TSdLegacyModuleCreator.GetShowForm: Boolean;
begin
  Result := cmShowForm in FFlags;
end;

function TSdLegacyModuleCreator.GetShowSource: Boolean;
begin
  Result := cmShowSource in FFlags;
end;

function TSdLegacyModuleCreator.NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := StreamFile(LegacyAncestorDfm(FormIdent, AncestorIdent));
end;

function TSdLegacyModuleCreator.NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  try
    Result := StreamFile(FCreator.NewModuleSource(ModuleIdent, FormIdent, AncestorIdent));
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdLegacyModuleCreator.NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil;
end;

procedure TSdLegacyModuleCreator.FormCreated(const FormEditor: IOTAFormEditor);
begin
end;

constructor TSdLegacyProjectCreator.Create(ACreator: TIProjectCreator; AFlags: TCreateProjectFlags);
begin
  inherited Create;
  FCreator := ACreator;
  FFlags := AFlags;
  try
    FFileName := FCreator.GetFileName;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
  { the name of a new project is chosen here: an option file of the Ex creator goes next to it
    before the project opens }
  if (FFileName = '') and (OtaHost <> nil) then
    FFileName := OtaHost.DefaultDir + OtaHost.UniqueUnitName('Project') + '.dpr';
end;

function TSdLegacyProjectCreator.GetCreatorType: string;
begin
  if cpApplication in FFlags then Result := sApplication
  else if cpLibrary in FFlags then Result := sLibrary
  else if cpConsole in FFlags then Result := sConsole
  else Result := '';
end;

function TSdLegacyProjectCreator.GetExisting: Boolean;
begin
  try
    Result := (cpExisting in FFlags) or FCreator.Existing;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdLegacyProjectCreator.GetFileSystem: string;
begin
  try
    Result := FCreator.GetFileSystem;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

{ a project of Delphi 1-3's creators opens on its own (no project group then) }
function TSdLegacyProjectCreator.GetOwner: IOTAModule;
begin
  Result := nil;
end;

function TSdLegacyProjectCreator.GetUnnamed: Boolean;
begin
  Result := False;
end;

function TSdLegacyProjectCreator.GetFileName: string;
begin
  Result := FFileName;
end;

function TSdLegacyProjectCreator.GetOptionFileName: string;
begin
  Result := '';
end;

function TSdLegacyProjectCreator.GetShowSource: Boolean;
begin
  Result := cpCanShowSource in FFlags;
end;

procedure TSdLegacyProjectCreator.NewDefaultModule;
begin
  try
    FCreator.NewDefaultModule;
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdLegacyProjectCreator.NewOptionSource(const ProjectName: string): IOTAFile;
begin
  Result := nil;
end;

{ the creator gets the new project's module interface with a reference of its own: Delphi 7's
  creators may free it or not }
procedure TSdLegacyProjectCreator.NewProjectResource(const Project: IOTAProject);
var
  M: TSdOtaModule;
  MI: TSdModuleIntf;
begin
  if Project = nil then Exit;
  M := OtaModules.Find(Project.FileName, False);
  MI := LegacyModuleIntf(M);
  if MI = nil then Exit;
  MI.AddRef;
  try
    FCreator.NewProjectResource(MI);
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

function TSdLegacyProjectCreator.NewProjectSource(const ProjectName: string): IOTAFile;
begin
  try
    Result := StreamFile(FCreator.NewProjectSource(ProjectName));
  except
    on Exception do raise;
  else
    raise LegacyOwnException;
  end;
end;

{ the module interface of a new module (a reference for the caller) }
function NewModuleIntf(const M: IOTAModule): TIModuleInterface;
var
  O: TSdOtaModule;
begin
  Result := nil;
  if M = nil then Exit;
  O := OtaModules.Find(M.FileName, False);
  if O = nil then Exit;
  Result := LegacyModuleIntf(O);
  Result.AddRef;
end;

function LegacyModuleCreate(Creator: TIModuleCreator; Flags: TCreateModuleFlags): TIModuleInterface;
var
  C: IOTACreator;
  MS: IOTAModuleServices;
  M: IOTAModule;
begin
  Result := nil;
  MS := ModuleServices;
  if (Creator = nil) or (MS = nil) or (OtaHost = nil) then Exit;
  C := TSdLegacyModuleCreator.Create(Creator, Flags);
  M := MS.CreateModule(C);
  if M = nil then Exit;
  if cmMarkModified in Flags then M.MarkModified;
  Result := NewModuleIntf(M);
end;

function LegacyProjectCreate(Creator: TIProjectCreator; Flags: TCreateProjectFlags; IsEx: Boolean): TIModuleInterface;
var
  A: TSdLegacyProjectCreator;
  C: IOTACreator;
  MS: IOTAModuleServices;
  M: IOTAModule;
  Opt: string;
begin
  Result := nil;
  MS := ModuleServices;
  if (Creator = nil) or (MS = nil) or (OtaHost = nil) then Exit;
  A := TSdLegacyProjectCreator.Create(Creator, Flags);
  C := A;
  { the Ex creator's option file: the new project's .dof, there before the project opens }
  if IsEx and not A.GetExisting then
  begin
    try
      Opt := TIProjectCreatorEx(Creator).NewOptionSource(ChangeFileExt(ExtractFileName(A.FFileName), ''));
    except
      on Exception do raise;
    else
      raise LegacyOwnException;
    end;
    if Opt <> '' then
    begin
      ForceDirectories(ExtractFilePath(A.FFileName));
      WriteFileU(ChangeFileExt(A.FFileName, '.dof'), Opt);
    end;
  end;
  M := MS.CreateModule(C);
  Result := NewModuleIntf(M);
end;

function LegacyCreateModule(const ModuleName, FormName, AncestorClass, FileSystem: string;
  Source, Form: IStream; Flags: TCreateModuleFlags): TIModuleInterface;
var
  Page: TEditorPage;
  Name, Src, Dfm, Anc: string;
  Show, AddToProject: Boolean;
  M: TSdOtaModule;
begin
  Result := nil;
  if OtaHost = nil then Exit;
  Page := nil;
  Show := (cmShowSource in Flags) or (cmShowForm in Flags);
  AddToProject := (cmAddToProject in Flags) and (OtaHost.Project <> nil);
  if cmNewUnit in Flags then
  begin
    if OtaHost.ExecuteAction('FileNewUnitCommand') then Page := OtaHost.ActivePage;
  end
  else if cmNewForm in Flags then
  begin
    if OtaHost.ExecuteAction('FileNewVclFormCommand') then Page := OtaHost.ActivePage;
  end
  else if cmNewFile in Flags then
    Page := OtaHost.NewModule(OtaHost.DefaultDir + OtaHost.UniqueUnitName('File') + '.txt', '', '', True,
      False, False, True)
  else if cmExisting in Flags then
  begin
    if ModuleName = '' then Exit;
    if FileSystem <> '' then Page := OtaHost.OpenVirtualFile(ModuleName, FileSystem, '', False, Show)
    else Page := OtaHost.OpenFile(ModuleName, Show);
    if (Page <> nil) and AddToProject and (OtaHost.Project.FindUnit(Page.FileName) = nil) then
      OtaHost.ProjectAddFile(Page.FileName);
  end
  else
  begin
    Name := ModuleName;
    if Name = '' then Name := OtaHost.DefaultDir + OtaHost.UniqueUnitName('Unit') + '.pas';
    Src := LegacyStreamText(Source);
    Dfm := FormStreamText(Form);
    { CreateModuleEx without a form: one of the ancestor's class, or a form's }
    if (Dfm = '') and (FormName <> '') then
    begin
      Anc := AncestorClass;
      if Anc = '' then Anc := 'TForm';
      Dfm := LegacyAncestorDfm(FormName, Anc);
      if (Dfm = '') and (SameText(Anc, 'TForm') or SameText(Anc, 'Form')) then Dfm := NewFormDfm(FormName);
    end;
    if FileSystem <> '' then Page := OtaHost.OpenVirtualFile(Name, FileSystem, Src, True, Show)
    else Page := OtaHost.NewModule(Name, Src, Dfm, (cmUnNamed in Flags) and not AddToProject, AddToProject,
      cmShowForm in Flags, cmShowSource in Flags);
  end;
  if Page = nil then Exit;
  if Page.FormOwner <> nil then Page := Page.FormOwner;
  M := OtaModules.Find(Page.FileName);
  if M = nil then Exit;
  if cmMarkModified in Flags then M.MarkModified;
  Result := LegacyModuleIntf(M);
  Result.AddRef;
end;

initialization
  Intfs := TList.Create;
  OldFileSystems := TList.Create;
end.
