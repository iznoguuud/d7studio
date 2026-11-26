{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaToolsFilter;

{ D7 Studio - the tools filters of the Open Tools API: IOTAToolsFilter60 and
  IOTAToolsFilter. Delphi 7 has the interfaces in ToolsAPI but no IDE object that implements them
  (no module of its Bin has their GUIDs but ToolsAPI's own type information); later IDEs filter
  the output of their build tools through them. D7 Studio keeps such a service - an expert would
  register a filter (an IOTAToolsFilterNotifier) and find one by its name to run it over a tool's
  output itself - but BorlandIDEServices does not offer it, as Delphi 7's does not: an expert
  written in D7 Studio sees what it will see in Delphi 7.

  * A filter keeps the index AddNotifier gave it (a removed one leaves a hole); a notifier that is
    no IOTAToolsFilterNotifier is not taken (-1). RemoveNotifier tells it Destroyed.
  * FindFilter: the first filter whose GetFilterName is Name, case-insensitive (nil: none).
  * A package that goes takes its filters out first (DropModule); when the IDE ends the filters
    still there are told Destroyed (Shutdown). }

interface

uses
  SysUtils, Classes, ToolsAPI, SdOtaCore;

type
  TSdOtaToolsFilter = class(TAggregatedObject, IOTAToolsFilter60, IOTAToolsFilter)
  private
    FFilters: TSdNotifierList;       // IOTAToolsFilterNotifier
  public
    constructor Create(const Controller: IInterface);
    destructor Destroy; override;
    procedure DropModule(Module: HMODULE);
    procedure AddModules(List: TList);
    procedure Shutdown;
    function DebugText: string;      // test mode: the filters there
    { IOTAToolsFilter60 }
    function AddNotifier(const ANotifier: IOTANotifier): Integer;
    procedure RemoveNotifier(Index: Integer);
    { IOTAToolsFilter }
    function FindFilter(const Name: string): IUnknown;
  end;

implementation

constructor TSdOtaToolsFilter.Create(const Controller: IInterface);
begin
  inherited Create(Controller);
  FFilters := TSdNotifierList.Create;
end;

destructor TSdOtaToolsFilter.Destroy;
begin
  FFilters.Free;
  inherited;
end;

function TSdOtaToolsFilter.AddNotifier(const ANotifier: IOTANotifier): Integer;
var
  F: IOTAToolsFilterNotifier;
begin
  if Supports(ANotifier, IOTAToolsFilterNotifier, F) then Result := FFilters.Add(F) else Result := -1;
end;

{ a bad index is ignored: an exception there would break the expert's unload }
procedure TSdOtaToolsFilter.RemoveNotifier(Index: Integer);
begin
  FFilters.RemoveTold(Index, IOTANotifier, 'IOTAToolsFilterNotifier');
end;

{ the filter's name is Name (case-insensitive); a filter that raises is none (logged) }
function FilterNamed(const F: IOTAToolsFilterNotifier; const Name: string): Boolean;
begin
  try
    Result := SameText(F.GetFilterName, Name);
  except
    OtaCaught('IOTAToolsFilterNotifier.GetFilterName', False);
    Result := False;
  end;
end;

function TSdOtaToolsFilter.FindFilter(const Name: string): IUnknown;
var
  S: TInterfaceList;
  I: Integer;
  F: IOTAToolsFilterNotifier;
begin
  Result := nil;
  S := TInterfaceList.Create;
  try
    FFilters.Snapshot(S);
    for I := 0 to S.Count - 1 do
      if Supports(S[I], IOTAToolsFilterNotifier, F) and FilterNamed(F, Name) then
      begin
        Result := F as IUnknown;
        Exit;
      end;
  finally
    S.Free;
  end;
end;

procedure TSdOtaToolsFilter.DropModule(Module: HMODULE);
begin
  FFilters.DropModule(Module);
end;

procedure TSdOtaToolsFilter.AddModules(List: TList);
begin
  FFilters.AddModules(List);
end;

procedure TSdOtaToolsFilter.Shutdown;
begin
  FFilters.DestroyAll('IOTAToolsFilterNotifier');
end;

function TSdOtaToolsFilter.DebugText: string;
begin
  Result := IntToStr(FFilters.Active);
end;

end.
