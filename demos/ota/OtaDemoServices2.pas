{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoServices2;

(* The OTA demo's experts of the second batch of services, and the commands of OTA Demo | More
  Services that show them:
    * TDemoHighlighter (IOTAHighlighter): INI files - [sections] as reserved words, ; comments,
      key = value as identifier, symbol and string - and /* */ comments over several lines (the
      line class is 1 inside one). Registered with IOTAHighlightServices and set as the
      highlighter of a source file type of its own (IOTAEditOptions.SyntaxHighlighter), it
      colours the files of that type in the code editor.
    * TDemoToolsFilter (IOTAToolsFilterNotifier): writes what a tool gave it - "[filter] <file>
      code=<n> out=<lines> err=<lines>" - into the message group OTA Demo.
    * TDemoSpeed (IOTASpeedSetting): block indent 7, tab stops 3.
    * TDemoMemFS (IOTAFileSystem): files in memory; every call is written into its Log, as
      "Method(arguments)".
    * TDemoAddCreator (IOTAAdditionalFilesModuleCreator): a unit with a form (TForm's, made by the IDE)
      whose text names a file of the extension .xyz ({$R *.dfm} followed by the comment {*.xyz})
      and a second file by its name. A unit without a form must not have the directive: Delphi 7 then
      makes a form the creator did not give and fails (an access violation).
    * TDemoMessage / TDemoDrawMessage (IOTACustomMessage50, INTACustomDrawMessage): a message
      with children; one of them draws itself (a coloured bar before its text). The counters
      DemoMessagesAlive, DemoMessageDraws and DemoMessageHelp count objects, Draw calls and F1.
    * TDemoOwnRecord: an IOTARecord of the expert's own, which the keyboard services ignore. *)

interface

uses
  Windows, SysUtils, Classes, Graphics, ActiveX, ToolsAPI;

type
  TDemoHighlighter = class(TNotifierObject, IOTANotifier, IOTAHighlighter)
  private
    FID, FName: string;
  public
    DestroyedCalls: Integer;
    constructor Create(const AID, AName: string);
    procedure Destroyed;
    function GetIDString: string;
    function GetName: string;
    procedure Tokenize(StartClass: TOTALineClass; LineBuf: POTAEdChar; LineBufLen: TOTALineSize;
      HighlightCodes: POTASyntaxCode);
    function TokenizeLineClass(StartClass: TOTALineClass; LineBuf: POTAEdChar;
      LineBufLen: TOTALineSize): TOTALineClass;
  end;

  TDemoToolsFilter = class(TNotifierObject, IOTANotifier, IOTAToolsFilterNotifier)
  private
    FName: string;
  public
    DestroyedCalls: Integer;
    LastText: string;
    constructor Create(const AName: string);
    procedure Destroyed;
    procedure Filter(FileName: string; ErrorCode: Integer; StdOut, StdError: TStrings);
    function GetFilterName: string;
  end;

  TDemoSpeed = class(TNotifierObject, IOTANotifier, IOTASpeedSetting)
  private
    FName: string;
  public
    Calls: Integer;
    constructor Create(const AName: string);
    function GetDisplayName: string;
    function GetName: string;
    procedure ExecuteSetting(const EditOptions: IOTAEditOptions);
  end;

  TDemoMemFS = class(TInterfacedObject, IOTAFileSystem)
  private
    FID: string;
    FFiles: TStringList;             // the names; Objects: TDemoMemFile
    function Find(const Name: string): Integer;
  public
    Log: TStringList;
    constructor Create(const AID: string);
    destructor Destroy; override;
    procedure SetFile(const Name, Content: string);
    function Content(const Name: string): string;
    procedure TouchFile(const Name: string);       // a new age, as another program's write
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

  { an existing file of a file system (IOTACreator.GetFileSystem) or a new one }
  TDemoFSCreator = class(TInterfacedObject, IOTACreator, IOTAModuleCreator)
  private
    FFileName, FFileSystem: string;
    FExisting: Boolean;
  public
    NoSource: Boolean;               // NewImplSource gives none
    Source: string;                  // the text it gives ('': a text of the demo's)
    Kind: string;                    // the creator's type: sText unless set
    constructor Create(const AFileName, AFileSystem: string; AExisting: Boolean);
    function GetCreatorType: string;
    function GetExisting: Boolean;
    function GetFileSystem: string;
    function GetOwner: IOTAModule;
    function GetUnnamed: Boolean;
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

  TDemoAddCreator = class(TInterfacedObject, IOTACreator, IOTAModuleCreator, IOTAAdditionalFilesModuleCreator)
  private
    FFileName: string;
    FOwner: IOTAModule;
  public
    constructor Create(const AFileName: string; const AOwner: IOTAModule);
    function GetCreatorType: string;
    function GetExisting: Boolean;
    function GetFileSystem: string;
    function GetOwner: IOTAModule;
    function GetUnnamed: Boolean;
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
    function GetAdditionalFilesCount: Integer;
    function NewAdditionalFileSource(I: Integer; const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    function GetAdditionalFileName(I: Integer): string;
    function GetAdditionalFileExt(I: Integer): string;
  end;

  TDemoMessage = class(TInterfacedObject, IOTACustomMessage, IOTACustomMessage50)
  private
    FText: string;
    FChildren: TInterfaceList;
  public
    constructor Create(const AText: string);
    destructor Destroy; override;
    procedure AddChild(const Child: IOTACustomMessage50);
    function GetColumnNumber: Integer;
    function GetFileName: string;
    function GetLineNumber: Integer;
    function GetLineText: string;
    procedure ShowHelp;
    function GetChildCount: Integer;
    function GetChild(Index: Integer): IOTACustomMessage50;
  end;

  TDemoDrawMessage = class(TDemoMessage, INTACustomDrawMessage)
  public
    procedure Draw(Canvas: TCanvas; const Rect: TRect; Wrap: Boolean);
    function CalcRect(Canvas: TCanvas; MaxWidth: Integer; Wrap: Boolean): TRect;
  end;

  TDemoOwnRecord = class(TInterfacedObject, IOTARecord)
  public
    procedure Append(const Keys: array of TShortCut); overload;
    procedure Append(const CmdName: string; IsKeys: Boolean = True); overload;
    procedure Append(const ARecord: IOTARecord); overload;
    procedure Clear;
    function GetIsPaused: Boolean;
    function GetIsPlaying: Boolean;
    function GetIsRecording: Boolean;
    function GetName: string;
    procedure ReadFromStream(const Stream: IStream);
    procedure SetName(const Value: string);
    procedure WriteToStream(const Stream: IStream);
  end;

  { OTA Demo | More Services: the commands }
  TDemoServices2 = class
  private
    FHighlighter: IOTAHighlighter;
    FFilter: IOTAToolsFilterNotifier;
    FFilterIndex: Integer;
    FSpeed: IOTASpeedSetting;
    FSpeedIndex: Integer;
    FMemFS: TDemoMemFS;
    FMemFSIntf: IOTAFileSystem;
    FMemFSIndex: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ToggleHighlighter(Sender: TObject);
    procedure RunFilter(Sender: TObject);
    procedure TypeLibModules(Sender: TObject);
    procedure NewAdditionalUnit(Sender: TObject);
    procedure OpenMemoryFile(Sender: TObject);
    procedure MemoryLog(Sender: TObject);
    procedure ShowMacro(Sender: TObject);
    procedure PlayMacroCopy(Sender: TObject);
    procedure SpeedSettingsList(Sender: TObject);
    procedure ToggleSpeedSetting(Sender: TObject);
    procedure MessageWithChildren(Sender: TObject);
  end;

const
  DemoHighlighterID = 'D7Studio.OtaDemo.Highlighter';
  DemoEditOptionsID = 'D7Studio.OtaDemo.EditOptions';
  DemoHighlightExt = 'otaini';
  DemoMemFSID = 'D7Studio.OtaDemo.MemFS';
  DemoMemFile = 'OtaDemo.Memory.txt';

var
  DemoMessagesAlive: Integer;        // TDemoMessage objects there
  DemoMessageDraws: Integer;         // Draw calls of TDemoDrawMessage
  DemoMessageHelp: Integer;          // ShowHelp calls

{ the items of a record as Delphi's stream has them: 'k<code>' a key, 'c<name>' a command; False:
  the stream could not be read }
function RecordItems(const R: IOTARecord; Items: TStrings): Boolean;

implementation

uses
  IStreams;

const
  GroupName = 'OTA Demo';

{ a line of the demo's message group (made when it is not there) }
procedure Say(const Text: string);
var
  M: IOTAMessageServices;
  G: IOTAMessageGroup;
  Ref: Pointer;
begin
  M := BorlandIDEServices as IOTAMessageServices;
  G := M.GetGroup(GroupName);
  if G = nil then G := M.AddMessageGroup(GroupName);
  M.AddToolMessage('', Text, 'OTA Demo', 0, 0, nil, Ref, G);
  M.ShowMessageView(G);
end;

{ ---------------------------------------------------------------- TDemoHighlighter }

constructor TDemoHighlighter.Create(const AID, AName: string);
begin
  inherited Create;
  FID := AID;
  FName := AName;
end;

procedure TDemoHighlighter.Destroyed;
begin
  Inc(DestroyedCalls);
end;

function TDemoHighlighter.GetIDString: string;
begin
  Result := FID;
end;

function TDemoHighlighter.GetName: string;
begin
  Result := FName;
end;

{ the codes of a line (Codes nil: only its end class) }
procedure ScanLine(StartClass: Byte; P: PChar; Len: Integer; Codes: PByteArray; out EndClass: Byte);
type
  TState = (sStart, sKey, sValue);
var
  I: Integer;
  InComment: Boolean;
  State: TState;

  procedure Put(Code: Byte);
  begin
    if Codes <> nil then Codes^[I] := Code;
  end;

begin
  InComment := StartClass = 1;
  State := sStart;
  I := 0;
  while I < Len do
  begin
    if InComment then
    begin
      Put(atComment);
      if (P[I] = '*') and (I + 1 < Len) and (P[I + 1] = '/') then
      begin
        Inc(I);
        Put(atComment);
        InComment := False;
        State := sStart;
      end;
      Inc(I);
      Continue;
    end;
    if (P[I] = '/') and (I + 1 < Len) and (P[I + 1] = '*') then
    begin
      Put(atComment);
      Inc(I);
      Put(atComment);
      Inc(I);
      InComment := True;
      Continue;
    end;
    case State of
      sValue: Put(atString);
      sStart:
        case P[I] of
          ' ', #9: Put(atWhiteSpace);
          ';':
            begin
              while I < Len do
              begin
                Put(atComment);
                Inc(I);
              end;
              Break;
            end;
          '[':
            begin
              while I < Len do
              begin
                Put(atReservedWord);
                if P[I] = ']' then Break;
                Inc(I);
              end;
            end;
          '=':
            begin
              Put(atSymbol);
              State := sValue;
            end;
          'A'..'Z', 'a'..'z', '0'..'9', '_', '.':
            begin
              Put(atIdentifier);
              State := sKey;
            end;
        else
          Put(atSymbol);
        end;
      sKey:
        case P[I] of
          ' ', #9: Put(atWhiteSpace);
          '=':
            begin
              Put(atSymbol);
              State := sValue;
            end;
          'A'..'Z', 'a'..'z', '0'..'9', '_', '.': Put(atIdentifier);
        else
          Put(atSymbol);
        end;
    end;
    Inc(I);
  end;
  if InComment then EndClass := 1 else EndClass := 0;
end;

procedure TDemoHighlighter.Tokenize(StartClass: TOTALineClass; LineBuf: POTAEdChar;
  LineBufLen: TOTALineSize; HighlightCodes: POTASyntaxCode);
var
  E: Byte;
begin
  ScanLine(StartClass, LineBuf, LineBufLen, PByteArray(HighlightCodes), E);
end;

function TDemoHighlighter.TokenizeLineClass(StartClass: TOTALineClass; LineBuf: POTAEdChar;
  LineBufLen: TOTALineSize): TOTALineClass;
var
  E: Byte;
begin
  ScanLine(StartClass, LineBuf, LineBufLen, nil, E);
  Result := E;
end;

{ ---------------------------------------------------------------- TDemoToolsFilter }

constructor TDemoToolsFilter.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

procedure TDemoToolsFilter.Destroyed;
begin
  Inc(DestroyedCalls);
end;

function Joined(L: TStrings): string;
var
  I: Integer;
begin
  Result := '';
  if L = nil then Exit;
  for I := 0 to L.Count - 1 do
  begin
    if I > 0 then Result := Result + '|';
    Result := Result + L[I];
  end;
end;

procedure TDemoToolsFilter.Filter(FileName: string; ErrorCode: Integer; StdOut, StdError: TStrings);
begin
  LastText := Format('[filter] %s code=%d out=%s err=%s', [ExtractFileName(FileName), ErrorCode,
    Joined(StdOut), Joined(StdError)]);
  Say(LastText);
end;

function TDemoToolsFilter.GetFilterName: string;
begin
  Result := FName;
end;

{ ---------------------------------------------------------------- TDemoSpeed }

constructor TDemoSpeed.Create(const AName: string);
begin
  inherited Create;
  FName := AName;
end;

function TDemoSpeed.GetDisplayName: string;
begin
  Result := 'OTA Demo speed setting';
end;

function TDemoSpeed.GetName: string;
begin
  Result := FName;
end;

procedure TDemoSpeed.ExecuteSetting(const EditOptions: IOTAEditOptions);
begin
  Inc(Calls);
  if EditOptions = nil then Exit;
  EditOptions.BlockIndent := 7;
  EditOptions.BufferOptions.TabStops := '3';
end;

{ ---------------------------------------------------------------- TDemoMemFS }

type
  TDemoMemFile = class
  public
    Content: string;
    Age: Integer;
  end;

  { the bytes written into a file of the file system: they are its content when the stream goes }
  TDemoWriteStream = class(TMemoryStream)
  private
    FFS: TDemoMemFS;
    FFSRef: IOTAFileSystem;
    FName: string;
  public
    constructor Create(AFS: TDemoMemFS; const AName: string);
    destructor Destroy; override;
  end;

var
  NextAge: Integer = 1000;

constructor TDemoWriteStream.Create(AFS: TDemoMemFS; const AName: string);
begin
  inherited Create;
  FFS := AFS;
  FFSRef := AFS;
  FName := AName;
end;

destructor TDemoWriteStream.Destroy;
var
  S: string;
begin
  SetString(S, PChar(Memory), Size);
  FFS.SetFile(FName, S);
  FFSRef := nil;
  inherited;
end;

constructor TDemoMemFS.Create(const AID: string);
begin
  inherited Create;
  FID := AID;
  FFiles := TStringList.Create;
  Log := TStringList.Create;
end;

destructor TDemoMemFS.Destroy;
var
  I: Integer;
begin
  for I := 0 to FFiles.Count - 1 do FFiles.Objects[I].Free;
  FFiles.Free;
  Log.Free;
  inherited;
end;

function TDemoMemFS.Find(const Name: string): Integer;
var
  I: Integer;
begin
  for I := 0 to FFiles.Count - 1 do
    if SameText(FFiles[I], Name) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

procedure TDemoMemFS.SetFile(const Name, Content: string);
var
  I: Integer;
  F: TDemoMemFile;
begin
  I := Find(Name);
  if I < 0 then
  begin
    F := TDemoMemFile.Create;
    FFiles.AddObject(Name, F);
  end
  else
    F := TDemoMemFile(FFiles.Objects[I]);
  F.Content := Content;
  Inc(NextAge);
  F.Age := NextAge;
end;

function TDemoMemFS.Content(const Name: string): string;
var
  I: Integer;
begin
  I := Find(Name);
  if I < 0 then Result := '' else Result := TDemoMemFile(FFiles.Objects[I]).Content;
end;

procedure TDemoMemFS.TouchFile(const Name: string);
var
  I: Integer;
begin
  I := Find(Name);
  if I < 0 then Exit;
  Inc(NextAge);
  TDemoMemFile(FFiles.Objects[I]).Age := NextAge;
end;

function TDemoMemFS.GetFileStream(const FileName: string; Mode: Integer): IStream;
var
  I: Integer;
  A: TIStreamAdapter;
begin
  if Mode = fmCreate then
  begin
    Log.Add(Format('GetFileStream(%s,create)', [FileName]));
    Result := TStreamAdapter.Create(TDemoWriteStream.Create(Self, FileName), soOwned);
    Exit;
  end;
  Log.Add(Format('GetFileStream(%s,read)', [FileName]));
  I := Find(FileName);
  if I < 0 then raise Exception.CreateFmt('%s: no file %s', [FID, FileName]);
  A := TIStreamAdapter.Create(TStringStream.Create(TDemoMemFile(FFiles.Objects[I]).Content), soOwned);
  A.SetModifyTime(TDemoMemFile(FFiles.Objects[I]).Age);
  Result := A;
end;

function TDemoMemFS.FileAge(const FileName: string): Longint;
var
  I: Integer;
begin
  Log.Add(Format('FileAge(%s)', [FileName]));
  I := Find(FileName);
  if I < 0 then Result := -1 else Result := TDemoMemFile(FFiles.Objects[I]).Age;
end;

function TDemoMemFS.RenameFile(const OldName, NewName: string): Boolean;
var
  I, K: Integer;
begin
  Log.Add(Format('RenameFile(%s,%s)', [OldName, NewName]));
  I := Find(OldName);
  Result := I >= 0;
  if not Result or SameText(OldName, NewName) then Exit;
  K := Find(NewName);
  if K >= 0 then
  begin
    FFiles.Objects[K].Free;
    FFiles.Delete(K);
    I := Find(OldName);
  end;
  FFiles[I] := NewName;
end;

function TDemoMemFS.IsReadonly(const FileName: string): Boolean;
begin
  Log.Add(Format('IsReadonly(%s)', [FileName]));
  Result := False;
end;

function TDemoMemFS.IsFileBased: Boolean;
begin
  Result := False;
end;

function TDemoMemFS.DeleteFile(const FileName: string): Boolean;
var
  I: Integer;
begin
  Log.Add(Format('DeleteFile(%s)', [FileName]));
  I := Find(FileName);
  Result := I >= 0;
  if Result then
  begin
    FFiles.Objects[I].Free;
    FFiles.Delete(I);
  end;
end;

function TDemoMemFS.FileExists(const FileName: string): Boolean;
begin
  Log.Add(Format('FileExists(%s)', [FileName]));
  Result := Find(FileName) >= 0;
end;

function TDemoMemFS.GetTempFileName(const FileName: string): string;
begin
  Log.Add(Format('GetTempFileName(%s)', [FileName]));
  Result := FileName + '.$$$';
end;

function TDemoMemFS.GetBackupFileName(const FileName: string): string;
begin
  Log.Add(Format('GetBackupFileName(%s)', [FileName]));
  Result := FileName + '.~bak';
end;

function TDemoMemFS.GetIDString: string;
begin
  Result := FID;
end;

{ ---------------------------------------------------------------- TDemoFSCreator }

constructor TDemoFSCreator.Create(const AFileName, AFileSystem: string; AExisting: Boolean);
begin
  inherited Create;
  FFileName := AFileName;
  FFileSystem := AFileSystem;
  FExisting := AExisting;
end;

function TDemoFSCreator.GetCreatorType: string; begin if Kind <> '' then Result := Kind else Result := sText; end;
function TDemoFSCreator.GetExisting: Boolean; begin Result := FExisting; end;
function TDemoFSCreator.GetFileSystem: string; begin Result := FFileSystem; end;
function TDemoFSCreator.GetOwner: IOTAModule; begin Result := nil; end;
function TDemoFSCreator.GetUnnamed: Boolean; begin Result := False; end;
function TDemoFSCreator.GetAncestorName: string; begin Result := ''; end;
function TDemoFSCreator.GetImplFileName: string; begin Result := FFileName; end;
function TDemoFSCreator.GetIntfFileName: string; begin Result := ''; end;
function TDemoFSCreator.GetFormName: string; begin Result := ''; end;
function TDemoFSCreator.GetMainForm: Boolean; begin Result := False; end;
function TDemoFSCreator.GetShowForm: Boolean; begin Result := False; end;
function TDemoFSCreator.GetShowSource: Boolean; begin Result := True; end;
function TDemoFSCreator.NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile; begin Result := nil; end;
function TDemoFSCreator.NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile; begin Result := nil; end;
procedure TDemoFSCreator.FormCreated(const FormEditor: IOTAFormEditor); begin end;

function TDemoFSCreator.NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  if NoSource then Result := nil
  else if Source <> '' then Result := StringToIOTAFile(Source)
  else Result := StringToIOTAFile('a new file of the demo''s file system');
end;

{ ---------------------------------------------------------------- TDemoAddCreator }

constructor TDemoAddCreator.Create(const AFileName: string; const AOwner: IOTAModule);
begin
  inherited Create;
  FFileName := AFileName;
  FOwner := AOwner;
end;

function TDemoAddCreator.GetCreatorType: string; begin Result := sForm; end;
function TDemoAddCreator.GetExisting: Boolean; begin Result := False; end;
function TDemoAddCreator.GetFileSystem: string; begin Result := ''; end;
function TDemoAddCreator.GetOwner: IOTAModule; begin Result := FOwner; end;
function TDemoAddCreator.GetUnnamed: Boolean; begin Result := False; end;
function TDemoAddCreator.GetAncestorName: string; begin Result := 'Form'; end;
function TDemoAddCreator.GetImplFileName: string; begin Result := FFileName; end;
function TDemoAddCreator.GetIntfFileName: string; begin Result := ''; end;
function TDemoAddCreator.GetFormName: string; begin Result := ChangeFileExt(ExtractFileName(FFileName), '') + 'Form'; end;
function TDemoAddCreator.GetMainForm: Boolean; begin Result := False; end;
function TDemoAddCreator.GetShowForm: Boolean; begin Result := False; end;
function TDemoAddCreator.GetShowSource: Boolean; begin Result := True; end;
function TDemoAddCreator.NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile; begin Result := nil; end;
function TDemoAddCreator.NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile; begin Result := nil; end;
procedure TDemoAddCreator.FormCreated(const FormEditor: IOTAFormEditor); begin end;

(* the form's unit; it names its extra file as Delphi 7 reads it: {$R *.dfm} and then
   {*.xyz} *)
function TDemoAddCreator.NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := StringToIOTAFile('unit ' + ModuleIdent + ';'#13#10#13#10'interface'#13#10#13#10 +
    'uses'#13#10'  Forms;'#13#10#13#10'type'#13#10'  T' + FormIdent + ' = class(T' + AncestorIdent + ')'#13#10 +
    '  end;'#13#10#13#10'var'#13#10'  ' + FormIdent + ': T' + FormIdent + ';'#13#10#13#10 +
    'implementation'#13#10#13#10'{$R *.dfm} {*.xyz}'#13#10#13#10'end.'#13#10);
end;

function TDemoAddCreator.GetAdditionalFilesCount: Integer;
begin
  Result := 2;
end;

function TDemoAddCreator.NewAdditionalFileSource(I: Integer; const ModuleIdent, FormIdent,
  AncestorIdent: string): IOTAFile;
begin
  if I = 0 then Result := StringToIOTAFile('the xyz file of ' + ModuleIdent)
  else Result := StringToIOTAFile('the notes of ' + ModuleIdent);
end;

{ 0: by its extension (the unit's name), 1: by its own name }
function TDemoAddCreator.GetAdditionalFileName(I: Integer): string;
begin
  if I = 0 then Result := '' else Result := ChangeFileExt(FFileName, '.notes.txt');
end;

function TDemoAddCreator.GetAdditionalFileExt(I: Integer): string;
begin
  if I = 0 then Result := '.xyz' else Result := '.txt';
end;

{ ---------------------------------------------------------------- TDemoMessage }

constructor TDemoMessage.Create(const AText: string);
begin
  inherited Create;
  FText := AText;
  FChildren := TInterfaceList.Create;
  Inc(DemoMessagesAlive);
end;

destructor TDemoMessage.Destroy;
begin
  FChildren.Free;
  Dec(DemoMessagesAlive);
  inherited;
end;

procedure TDemoMessage.AddChild(const Child: IOTACustomMessage50);
begin
  FChildren.Add(Child);
end;

function TDemoMessage.GetColumnNumber: Integer; begin Result := 0; end;
function TDemoMessage.GetFileName: string; begin Result := ''; end;
function TDemoMessage.GetLineNumber: Integer; begin Result := 0; end;

function TDemoMessage.GetLineText: string;
begin
  Result := FText;
end;

procedure TDemoMessage.ShowHelp;
begin
  Inc(DemoMessageHelp);
end;

function TDemoMessage.GetChildCount: Integer;
begin
  Result := FChildren.Count;
end;

function TDemoMessage.GetChild(Index: Integer): IOTACustomMessage50;
begin
  if (Index >= 0) and (Index < FChildren.Count) then Result := IOTACustomMessage50(FChildren[Index])
  else Result := nil;
end;

{ a bar in the colour of the selection's text or navy, then the text }
procedure TDemoDrawMessage.Draw(Canvas: TCanvas; const Rect: TRect; Wrap: Boolean);
var
  R: TRect;
  H: Integer;
begin
  Inc(DemoMessageDraws);
  H := Canvas.TextHeight('Ag');
  R := Classes.Rect(Rect.Left, Rect.Top + (Rect.Bottom - Rect.Top - H) div 2 + 2, Rect.Left + 10,
    Rect.Top + (Rect.Bottom - Rect.Top + H) div 2 - 2);
  Canvas.Brush.Style := bsSolid;
  if Canvas.Font.Color = clHighlightText then Canvas.Brush.Color := clHighlightText
  else Canvas.Brush.Color := clNavy;
  Canvas.FillRect(R);
  Canvas.Brush.Style := bsClear;
  Canvas.TextOut(Rect.Left + 14, Rect.Top + (Rect.Bottom - Rect.Top - H) div 2, FText);
end;

function TDemoDrawMessage.CalcRect(Canvas: TCanvas; MaxWidth: Integer; Wrap: Boolean): TRect;
begin
  Result := Classes.Rect(0, 0, 14 + Canvas.TextWidth(FText), Canvas.TextHeight('Ag'));
end;

{ ---------------------------------------------------------------- TDemoOwnRecord }

procedure TDemoOwnRecord.Append(const Keys: array of TShortCut); begin end;
procedure TDemoOwnRecord.Append(const CmdName: string; IsKeys: Boolean); begin end;
procedure TDemoOwnRecord.Append(const ARecord: IOTARecord); begin end;
procedure TDemoOwnRecord.Clear; begin end;
function TDemoOwnRecord.GetIsPaused: Boolean; begin Result := False; end;
function TDemoOwnRecord.GetIsPlaying: Boolean; begin Result := False; end;
function TDemoOwnRecord.GetIsRecording: Boolean; begin Result := False; end;
function TDemoOwnRecord.GetName: string; begin Result := 'the expert''s own record'; end;
procedure TDemoOwnRecord.ReadFromStream(const Stream: IStream); begin end;
procedure TDemoOwnRecord.SetName(const Value: string); begin end;
procedure TDemoOwnRecord.WriteToStream(const Stream: IStream); begin end;

{ ---------------------------------------------------------------- RecordItems }

function RecordItems(const R: IOTARecord; Items: TStrings): Boolean;
var
  M: TMemoryStream;
  S: IStream;
  P: PChar;
  I, N, Code, Len: Integer;
  Name: string;
begin
  Result := False;
  Items.Clear;
  if R = nil then Exit;
  M := TMemoryStream.Create;
  try
    S := TStreamAdapter.Create(M, soReference);
    R.WriteToStream(S);
    S := nil;
    P := M.Memory;
    N := M.Size;
    if (N < 5) or (StrLComp(P, 'TPOR', 4) <> 0) then Exit;
    I := 4;
    while I < N do
    begin
      case Ord(P[I]) of
        0:
          begin
            Result := True;
            Exit;
          end;
        1:
          begin
            if I + 5 > N then Exit;
            Move(P[I + 1], Code, 4);
            Items.Add('k' + IntToHex(Code, 8));
            Inc(I, 5);
          end;
        2:
          begin
            if I + 5 > N then Exit;
            Move(P[I + 1], Len, 4);
            if I + 5 + Len > N then Exit;
            SetString(Name, P + I + 5, Len);
            Items.Add('c' + Name);
            Inc(I, 5 + Len);
          end;
      else
        Exit;
      end;
    end;
  finally
    M.Free;
  end;
end;

{ ---------------------------------------------------------------- TDemoServices2 }

constructor TDemoServices2.Create;
begin
  inherited Create;
  FFilterIndex := -1;
  FSpeedIndex := -1;
  FMemFSIndex := -1;
end;

destructor TDemoServices2.Destroy;
var
  HS: IOTAHighlightServices;
  I: Integer;
  TF: IOTAToolsFilter;
  E: IOTAEditorServices;
begin
  if FHighlighter <> nil then
  begin
    HS := BorlandIDEServices as IOTAHighlightServices;
    for I := HS.HighlighterCount - 1 downto 0 do
      if HS.Highlighter[I] = FHighlighter then HS.RemoveHighlighter(I);
    E := BorlandIDEServices as IOTAEditorServices;
    if E.GetEditOptions(DemoEditOptionsID) <> nil then E.DeleteEditOptions(DemoEditOptionsID);
    FHighlighter := nil;
  end;
  if (FFilterIndex >= 0) and Supports(BorlandIDEServices, IOTAToolsFilter, TF) then TF.RemoveNotifier(FFilterIndex);
  FFilter := nil;
  if FSpeedIndex >= 0 then (BorlandIDEServices as IOTAEditorServices).EditOptions.RemoveSpeedSetting(FSpeedIndex);
  FSpeed := nil;
  if FMemFSIndex >= 0 then (BorlandIDEServices as IOTAModuleServices).RemoveFileSystem(FMemFSIndex);
  FMemFSIntf := nil;
  inherited;
end;

{ the demo's highlighter for *.otaini files: registered, or taken away again }
procedure TDemoServices2.ToggleHighlighter(Sender: TObject);
var
  HS: IOTAHighlightServices;
  E: IOTAEditorServices;
  O: IOTAEditOptions;
  I: Integer;
begin
  HS := BorlandIDEServices as IOTAHighlightServices;
  E := BorlandIDEServices as IOTAEditorServices;
  if FHighlighter = nil then
  begin
    FHighlighter := TDemoHighlighter.Create(DemoHighlighterID, 'OTA Demo INI');
    I := HS.AddHighlighter(FHighlighter);
    O := E.AddEditOptions(DemoEditOptionsID);
    O.Extensions := DemoHighlightExt;
    O.SyntaxHighlighter := FHighlighter;
    O.BufferOptions.SyntaxHighlight := True;   // a new type has the Default type's: off
    Say(Format('Highlighter "%s" at %d of %d: the files *.%s are coloured by it', [FHighlighter.Name, I,
      HS.HighlighterCount, DemoHighlightExt]));
  end
  else
  begin
    for I := HS.HighlighterCount - 1 downto 0 do
      if HS.Highlighter[I] = FHighlighter then HS.RemoveHighlighter(I);
    if E.GetEditOptions(DemoEditOptionsID) <> nil then E.DeleteEditOptions(DemoEditOptionsID);
    FHighlighter := nil;
    Say('Highlighter removed');
  end;
  for I := 0 to HS.HighlighterCount - 1 do Say(Format('  %d: %s (%s)', [I, HS.Highlighter[I].IDString, HS.Highlighter[I].Name]));
end;

{ IOTAToolsFilter: the demo's filter registered (once), found by its name and run on a tool's
  output }
procedure TDemoServices2.RunFilter(Sender: TObject);
var
  TF: IOTAToolsFilter;
  F: IOTAToolsFilterNotifier;
  O, E: TStringList;
begin
  if not Supports(BorlandIDEServices, IOTAToolsFilter, TF) then
  begin
    Say('The IDE has no IOTAToolsFilter');
    Exit;
  end;
  if FFilter = nil then
  begin
    FFilter := TDemoToolsFilter.Create('OTA Demo filter');
    FFilterIndex := TF.AddNotifier(FFilter);
  end;
  if not Supports(TF.FindFilter('ota demo filter'), IOTAToolsFilterNotifier, F) then
  begin
    Say('FindFilter found no filter "OTA Demo filter"');
    Exit;
  end;
  O := TStringList.Create;
  E := TStringList.Create;
  try
    O.Add('hello');
    E.Add('oops');
    F.Filter('Sample.pas', 3, O, E);
  finally
    E.Free;
    O.Free;
  end;
end;

{ the modules that are type libraries (IOTATypeLibModule: View | Type Library) and their editors }
procedure TDemoServices2.TypeLibModules(Sender: TObject);
var
  Mods: IOTAModuleServices;
  M: IOTAModule;
  I, J, N: Integer;
begin
  Mods := BorlandIDEServices as IOTAModuleServices;
  N := 0;
  for I := 0 to Mods.ModuleCount - 1 do
  begin
    M := Mods.Modules[I];
    if not Supports(M, IOTATypeLibModule) then Continue;
    Inc(N);
    Say(Format('%s: %d editors', [M.FileName, M.ModuleFileCount]));
    for J := 0 to M.ModuleFileCount - 1 do Say('  ' + M.ModuleFileEditors[J].FileName);
  end;
  if N = 0 then Say('No type library is open (View | Type Library)');
end;

{ IOTAAdditionalFilesModuleCreator: a unit with two files of its own in a folder of %TEMP% }
procedure TDemoServices2.NewAdditionalUnit(Sender: TObject);
var
  Buf: array[0..MAX_PATH] of Char;
  Dir: string;
  M: IOTAModule;
  AF: IOTAAdditionalModuleFiles;
  I: Integer;
begin
  SetString(Dir, Buf, GetTempPath(SizeOf(Buf), Buf));
  Dir := IncludeTrailingPathDelimiter(Dir) + 'OtaDemoAF\';
  ForceDirectories(Dir);
  M := (BorlandIDEServices as IOTAModuleServices).CreateModule(TDemoAddCreator.Create(Dir + 'DemoUnitAF.pas', nil));
  if not Supports(M, IOTAAdditionalModuleFiles, AF) then
  begin
    Say('No module, or no IOTAAdditionalModuleFiles');
    Exit;
  end;
  Say(Format('%s: %d additional files', [M.FileName, AF.AdditionalModuleFileCount]));
  for I := 0 to AF.AdditionalModuleFileCount - 1 do Say('  ' + AF.AdditionalModuleFileEditors[I].FileName);
end;

{ IOTAFileSystem: a file of the demo's file system in memory, opened as a module. The creator gives
  the file's text: Delphi 7 shows an existing file of a text creator with the text it gives and does
  not read the file }
procedure TDemoServices2.OpenMemoryFile(Sender: TObject);
var
  Mods: IOTAModuleServices;
  C: TDemoFSCreator;
begin
  Mods := BorlandIDEServices as IOTAModuleServices;
  if FMemFS = nil then
  begin
    FMemFS := TDemoMemFS.Create(DemoMemFSID);
    FMemFSIntf := FMemFS;
    FMemFS.SetFile(DemoMemFile, 'A file of the OTA demo''s file system in memory: change it and save it.');
    FMemFSIndex := Mods.AddFileSystem(FMemFSIntf);
  end;
  if Mods.FindModule(DemoMemFile) = nil then
  begin
    C := TDemoFSCreator.Create(DemoMemFile, DemoMemFSID, True);
    C.Source := FMemFS.Content(DemoMemFile);
    Mods.CreateModule(C);
  end;
  Say(DemoMemFile + ' of the file system ' + DemoMemFSID + ': "' + FMemFS.Content(DemoMemFile) + '"');
end;

procedure TDemoServices2.MemoryLog(Sender: TObject);
var
  I: Integer;
begin
  if FMemFS = nil then
  begin
    Say('The memory file system is not there yet: open its file first');
    Exit;
  end;
  for I := 0 to FMemFS.Log.Count - 1 do Say(FMemFS.Log[I]);
  Say(DemoMemFile + ' now: "' + FMemFS.Content(DemoMemFile) + '"');
end;

{ the current record of the keyboard services (after Edit | Record Macro: the IDE's macro) }
procedure TDemoServices2.ShowMacro(Sender: TObject);
var
  K: IOTAKeyboardServices;
  L: TStringList;
  I: Integer;
begin
  K := BorlandIDEServices as IOTAKeyboardServices;
  if K.CurrentRecord = nil then
  begin
    Say('No record yet: Edit | Record Macro (Shift+Ctrl+R) records one');
    Exit;
  end;
  L := TStringList.Create;
  try
    if not RecordItems(K.CurrentRecord, L) then Say('The record could not be written');
    Say(Format('The current record: %d items', [L.Count]));
    for I := 0 to L.Count - 1 do Say('  ' + L[I]);
  finally
    L.Free;
  end;
end;

{ a copy of the current record played in the code editor: NewRecordObject, Append, the playback
  object, ResumePlayback - as experts replay a saved macro }
procedure TDemoServices2.PlayMacroCopy(Sender: TObject);
var
  K: IOTAKeyboardServices;
  R: IOTARecord;
begin
  K := BorlandIDEServices as IOTAKeyboardServices;
  if (K.CurrentRecord = nil) or not K.NewRecordObject(R) then
  begin
    Say('No record to copy');
    Exit;
  end;
  R.Append(K.CurrentRecord);
  K.SetPlaybackObject(R);
  K.ResumePlayback;
  Say('The copy was played');
end;

procedure TDemoServices2.SpeedSettingsList(Sender: TObject);
var
  O: IOTAEditOptions;
  I: Integer;
begin
  O := (BorlandIDEServices as IOTAEditorServices).EditOptions;
  for I := 0 to O.SpeedSettingCount - 1 do
    Say(Format('%d: %s - %s', [I, O.SpeedSettings[I].Name, O.SpeedSettings[I].DisplayName]));
end;

{ the demo's speed setting added (it is run by SetSpeedSetting) or removed }
procedure TDemoServices2.ToggleSpeedSetting(Sender: TObject);
var
  O: IOTAEditOptions;
begin
  O := (BorlandIDEServices as IOTAEditorServices).EditOptions;
  if FSpeed = nil then
  begin
    FSpeed := TDemoSpeed.Create('D7Studio.OtaDemo.Speed');
    FSpeedIndex := O.AddSpeedSetting(FSpeed);
    Say(Format('The demo''s speed setting is %d of %d (SetSpeedSetting(''D7Studio.OtaDemo.Speed'') runs it)',
      [FSpeedIndex, O.SpeedSettingCount]));
  end
  else
  begin
    O.RemoveSpeedSetting(FSpeedIndex);
    FSpeed := nil;
    FSpeedIndex := -1;
    Say('The demo''s speed setting was removed');
  end;
end;

{ IOTACustomMessage50: a message with two children (closed in the view: + opens them), one of
  them drawn by itself (INTACustomDrawMessage); F1 on them is their ShowHelp }
procedure TDemoServices2.MessageWithChildren(Sender: TObject);
var
  M: IOTAMessageServices;
  G: IOTAMessageGroup;
  P: TDemoMessage;
begin
  M := BorlandIDEServices as IOTAMessageServices;
  G := M.GetGroup(GroupName);
  if G = nil then G := M.AddMessageGroup(GroupName);
  P := TDemoMessage.Create('A message with two children (+ shows them)');
  P.AddChild(TDemoMessage.Create('a plain child'));
  P.AddChild(TDemoDrawMessage.Create('a child that draws itself'));
  M.AddCustomMessage(P, G);
  M.ShowMessageView(G);
end;

end.
