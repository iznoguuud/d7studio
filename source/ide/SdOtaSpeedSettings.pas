{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaSpeedSettings;

{ D7 Studio - the editor's speed settings of the Open Tools API: IOTASpeedSetting
  and IOTAEditOptions' AddSpeedSetting, GetSpeedSetting(Count), RemoveSpeedSetting and
  SetSpeedSetting - Delphi 7's one list of the editor services, which every
  IOTAEditOptions reaches.

  * Six built-ins with Delphi 7's names and display names (Borland.Default "Default keymapping"
    ... Borland.VisualBasic "Visual Basic (TM) emulation"). Their ExecuteSetting puts Delphi's
    record of the setting into the editor options, whatever
    IOTAEditOptions it is given: for every source file type the tab stops, auto indent, optimal
    fill and keep trailing blanks; insert mode, cursor through tabs, group undo, cursor beyond
    EOF, persistent and overwrite blocks, BRIEF regular expressions and cursor shapes, force cut
    and copy and the key mapping (Visual Basic's is Delphi's Visual Studio one).
  * A speed setting keeps the index AddSpeedSetting gave it; a removed one leaves a hole, which
    the next AddSpeedSetting takes (Delphi's AddToList). Count and GetSpeedSetting see the settings
    that are there, in that order; GetSpeedSetting out of range raises EListError, as Delphi's.
  * SetSpeedSetting(Name) finds the setting by its name (case-insensitive; none: Delphi's
    exception), remembers its name and runs it with the IOTAEditOptions it was called on. A speed
    setting runs only when an expert asks: Editor Options' Editor SpeedSetting stays D7 Studio's.
  * A package that goes takes its settings out first (DropModule); when the IDE ends the experts'
    settings still there are told Destroyed (Shutdown). }

interface

uses
  SysUtils, Classes, ToolsAPI, SdOtaCore;

type
  TSdSpeedSettings = class
  private
    FList: TSdNotifierList;          // IOTASpeedSetting, the built-ins first; nil: a hole
    FCurrent: string;                // the name SetSpeedSetting ran last
  public
    constructor Create;
    destructor Destroy; override;
    function Add(const Setting: IOTASpeedSetting): Integer;
    procedure Remove(Index: Integer);
    function Count: Integer;
    function Get(Index: Integer): IOTASpeedSetting;
    function Find(const Name: string): IOTASpeedSetting;
    { SetSpeedSetting: the setting of Name run with EditOptions (none: Delphi's exception) }
    procedure Execute(const Name: string; const EditOptions: IOTAEditOptions);
    procedure DropModule(Module: HMODULE);
    procedure AddModules(List: TList);
    procedure Shutdown;
    function DebugText: string;      // test mode: 'settings:the name run last'
  end;

{ the editor services' list (made at the first use) }
function SpeedSettings: TSdSpeedSettings;

const
  SInvalidSpeedSetting = 'SpeedSetting, %s, is invalid';

implementation

uses
  RTLConsts, SdEditorOptions;

type
  { Delphi 7's record of a built-in speed setting }
  TSpeedRecord = record
    Name, DisplayName, Keymapping, TabStops: string;
    KeepTrailingBlanks, GroupUndo, PersistentBlocks, OverwriteBlocks, CursorBeyondEOF, Brief: Boolean;
  end;

const
  { Delphi 7's records of the settings: insert mode, auto indent and
    cursor through tabs are on in all of them, optimal fill off; Brief: BRIEF regular
    expressions, BRIEF cursor shapes and force cut and copy }
  SpeedRecords: array[0..5] of TSpeedRecord = (
    (Name: 'Borland.Default'; DisplayName: 'Default keymapping'; Keymapping: 'Default'; TabStops: '8';
     KeepTrailingBlanks: False; GroupUndo: True; PersistentBlocks: False; OverwriteBlocks: True;
     CursorBeyondEOF: False; Brief: False),
    (Name: 'Borland.Classic'; DisplayName: 'IDE classic'; Keymapping: 'IDE Classic'; TabStops: '8';
     KeepTrailingBlanks: False; GroupUndo: True; PersistentBlocks: True; OverwriteBlocks: False;
     CursorBeyondEOF: False; Brief: False),
    (Name: 'Borland.Brief'; DisplayName: 'BRIEF emulation'; Keymapping: 'BRIEF Emulation'; TabStops: '3';
     KeepTrailingBlanks: True; GroupUndo: False; PersistentBlocks: False; OverwriteBlocks: False;
     CursorBeyondEOF: True; Brief: True),
    (Name: 'Borland.Epsilon'; DisplayName: 'Epsilon emulation'; Keymapping: 'Epsilon'; TabStops: '8';
     KeepTrailingBlanks: False; GroupUndo: True; PersistentBlocks: False; OverwriteBlocks: True;
     CursorBeyondEOF: False; Brief: False),
    (Name: 'Borland.VisualStudio'; DisplayName: 'Visual Studio (TM) emulation';
     Keymapping: 'Visual Studio Emulation'; TabStops: '8';
     KeepTrailingBlanks: False; GroupUndo: True; PersistentBlocks: False; OverwriteBlocks: True;
     CursorBeyondEOF: False; Brief: False),
    (Name: 'Borland.VisualBasic'; DisplayName: 'Visual Basic (TM) emulation';
     Keymapping: 'Visual Studio Emulation'; TabStops: '8';
     KeepTrailingBlanks: False; GroupUndo: True; PersistentBlocks: False; OverwriteBlocks: True;
     CursorBeyondEOF: False; Brief: False));

type
  TSdBuiltinSpeed = class(TNotifierObject, IOTANotifier, IOTASpeedSetting)
  private
    FIndex: Integer;
  public
    constructor Create(AIndex: Integer);
    function GetDisplayName: string;
    function GetName: string;
    procedure ExecuteSetting(const EditOptions: IOTAEditOptions);
  end;

var
  TheList: TSdSpeedSettings;

function SpeedSettings: TSdSpeedSettings;
begin
  if TheList = nil then TheList := TSdSpeedSettings.Create;
  Result := TheList;
end;

{ ---------------------------------------------------------------- TSdBuiltinSpeed }

constructor TSdBuiltinSpeed.Create(AIndex: Integer);
begin
  inherited Create;
  FIndex := AIndex;
end;

function TSdBuiltinSpeed.GetDisplayName: string;
begin
  Result := SpeedRecords[FIndex].DisplayName;
end;

function TSdBuiltinSpeed.GetName: string;
begin
  Result := SpeedRecords[FIndex].Name;
end;

{ Delphi's TEnvironmentOptions.SetEditorSpeedSetting: the options passed are not looked at }
procedure TSdBuiltinSpeed.ExecuteSetting(const EditOptions: IOTAEditOptions);
var
  I: Integer;
begin
  with SpeedRecords[FIndex] do
  begin
    for I := 0 to High(EditorOptions.FileTypes) do
    begin
      EditorOptions.FileTypes[I].TabStops := TabStops;
      EditorOptions.FileTypes[I].AutoIndent := True;
      EditorOptions.FileTypes[I].OptimalFill := False;
      EditorOptions.FileTypes[I].KeepTrailingBlanks := KeepTrailingBlanks;
    end;
    EditorOptions.InsertMode := True;
    EditorOptions.CursorThroughTabs := True;
    EditorOptions.GroupUndo := GroupUndo;
    EditorOptions.CursorBeyondEOF := CursorBeyondEOF;
    EditorOptions.PersistentBlocks := PersistentBlocks;
    EditorOptions.OverwriteBlocks := OverwriteBlocks;
    EditorOptions.BriefRegExp := Brief;
    EditorOptions.BriefCursors := Brief;
    EditorOptions.ForceCutCopy := Brief;
    EditorOptions.Keymapping := Keymapping;
  end;
  if OtaHost <> nil then OtaHost.EditorOptionsChanged;
end;

{ ---------------------------------------------------------------- TSdSpeedSettings }

constructor TSdSpeedSettings.Create;
var
  I: Integer;
begin
  inherited Create;
  FList := TSdNotifierList.Create;
  for I := Low(SpeedRecords) to High(SpeedRecords) do FList.Add(IOTASpeedSetting(TSdBuiltinSpeed.Create(I)));
end;

destructor TSdSpeedSettings.Destroy;
begin
  FList.Free;
  inherited;
end;

{ Delphi's AddToList: the first hole, else the end }
function TSdSpeedSettings.Add(const Setting: IOTASpeedSetting): Integer;
begin
  Result := FList.AddInHole(Setting);
end;

{ a bad index is ignored: an exception there would break the expert's unload }
procedure TSdSpeedSettings.Remove(Index: Integer);
begin
  FList.Remove(Index);
end;

function TSdSpeedSettings.Count: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FList.Count - 1 do
    if Supports(FList[I], IOTASpeedSetting) then Inc(Result);
end;

function TSdSpeedSettings.Get(Index: Integer): IOTASpeedSetting;
var
  I, N: Integer;
begin
  N := 0;
  for I := 0 to FList.Count - 1 do
    if Supports(FList[I], IOTASpeedSetting, Result) then
    begin
      if N = Index then Exit;
      Inc(N);
    end;
  raise EListError.CreateFmt(SListIndexError, [Index]);
end;

function TSdSpeedSettings.Find(const Name: string): IOTASpeedSetting;
var
  I: Integer;
begin
  for I := 0 to FList.Count - 1 do
    if Supports(FList[I], IOTASpeedSetting, Result) and (AnsiCompareText(Result.GetName, Name) = 0) then Exit;
  Result := nil;
end;

procedure TSdSpeedSettings.Execute(const Name: string; const EditOptions: IOTAEditOptions);
var
  S: IOTASpeedSetting;
begin
  S := Find(Name);
  if S = nil then raise Exception.CreateFmt(SInvalidSpeedSetting, [Name]);
  FCurrent := Name;
  try
    S.ExecuteSetting(EditOptions);
  except
    OtaCaught('IOTASpeedSetting.ExecuteSetting', False);
  end;
end;

procedure TSdSpeedSettings.DropModule(Module: HMODULE);
begin
  FList.DropModule(Module);
end;

procedure TSdSpeedSettings.AddModules(List: TList);
var
  I: Integer;
  M: HMODULE;
begin
  for I := 0 to FList.Count - 1 do
    if FList[I] <> nil then
    begin
      M := InterfaceModule(FList[I]);
      if M <> HInstance then AddModuleOnce(List, M);
    end;
end;

{ the experts' settings told Destroyed and released (the built-ins are D7 Studio's own). An entry
  is the IOTASpeedSetting AddSpeedSetting was given: told through it, without asking the object
  for the interface again. }
procedure TSdSpeedSettings.Shutdown;
var
  I: Integer;
  S: IOTASpeedSetting;
begin
  for I := 0 to FList.Count - 1 do
    if (FList[I] <> nil) and (InterfaceModule(FList[I]) <> HInstance) then
    begin
      S := IOTASpeedSetting(FList[I]);
      FList.Remove(I);
      try
        S.Destroyed;
      except
        OtaCaught('IOTASpeedSetting.Destroyed', False);
      end;
      S := nil;
    end;
end;

function TSdSpeedSettings.DebugText: string;
begin
  Result := Format('%d:%s', [Count, FCurrent]);
end;

initialization
finalization
  FreeAndNil(TheList);
end.
