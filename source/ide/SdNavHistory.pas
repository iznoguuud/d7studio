{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdNavHistory;

{ D7 Studio - the browse history behind Back and Forward before the file tabs: Delphi 7's hotlinks as
  its editor window keeps them. A list of
  places and the one shown (Index). A jump drops the places after the one shown and that one too,
  adds where it came from - unless the list ends with that place - and where it went, which is
  then the one shown. Back and Forward show the place before and after it; their drop-down menus
  list the places before it (the nearest first) and after it. D7 Studio records more jumps than
  Delphi's code browsing (TMainForm.NavMark) and keeps the last MaxPlaces places. }

interface

const
  MaxPlaces = 50;

type
  TSdNavPlace = record
    FileName: string;
    Line, Col: Integer;          // 1-based; Col the editor's column (tabs expanded)
    Design: Boolean;             // the page showed its form
  end;

  TSdNavHistory = class
  private
    FPlaces: array of TSdNavPlace;
    FCount: Integer;
    FIndex: Integer;             // the place shown; -1: none
    function GetPlace(I: Integer): TSdNavPlace;
    procedure Add(const P: TSdNavPlace);
  public
    constructor Create;
    procedure Jumped(const From, Dest: TSdNavPlace);
    procedure Delete(I: Integer);                          // a place that cannot be shown any more
    procedure Renamed(const OldName, NewName: string);     // a file saved under another name
    procedure Clear;
    function CanBack: Boolean;
    function CanForward: Boolean;
    function Caption(I: Integer): string;                  // Delphi's menu entry: the file and the line
    function DebugText: string;                            // test mode: 'index|name:line:col[:d];...'
    property Count: Integer read FCount;
    property Places[I: Integer]: TSdNavPlace read GetPlace; default;
    property Index: Integer read FIndex write FIndex;      // set when a place was shown
  end;

{ Delphi compares the file and the line; the view counts as well }
function SamePlace(const A, B: TSdNavPlace): Boolean;

implementation

uses
  SysUtils;

function SamePlace(const A, B: TSdNavPlace): Boolean;
begin
  Result := SameText(A.FileName, B.FileName) and (A.Line = B.Line) and (A.Design = B.Design);
end;

constructor TSdNavHistory.Create;
begin
  inherited Create;
  SetLength(FPlaces, MaxPlaces);
  FIndex := -1;
end;

function TSdNavHistory.GetPlace(I: Integer): TSdNavPlace;
begin
  Result := FPlaces[I];
end;

{ at the end; the oldest place makes room }
procedure TSdNavHistory.Add(const P: TSdNavPlace);
begin
  if FCount = MaxPlaces then Delete(0);
  FPlaces[FCount] := P;
  Inc(FCount);
end;

procedure TSdNavHistory.Jumped(const From, Dest: TSdNavPlace);
begin
  if SamePlace(From, Dest) then Exit;                      // nothing moved
  if FIndex >= 0 then FCount := FIndex;
  if (FCount = 0) or not SamePlace(FPlaces[FCount - 1], From) then Add(From);
  Add(Dest);
  FIndex := FCount - 1;
end;

procedure TSdNavHistory.Delete(I: Integer);
var
  J: Integer;
begin
  if (I < 0) or (I >= FCount) then Exit;
  for J := I to FCount - 2 do FPlaces[J] := FPlaces[J + 1];
  Dec(FCount);
  FPlaces[FCount].FileName := '';
  if FIndex > I then Dec(FIndex);
  if FIndex >= FCount then FIndex := FCount - 1;
end;

procedure TSdNavHistory.Renamed(const OldName, NewName: string);
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if SameText(FPlaces[I].FileName, OldName) then FPlaces[I].FileName := NewName;
end;

procedure TSdNavHistory.Clear;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do FPlaces[I].FileName := '';
  FCount := 0;
  FIndex := -1;
end;

function TSdNavHistory.CanBack: Boolean;
begin
  Result := FIndex > 0;
end;

function TSdNavHistory.CanForward: Boolean;
begin
  Result := FIndex < FCount - 1;
end;

function TSdNavHistory.Caption(I: Integer): string;
begin
  Result := FPlaces[I].FileName + ' ' + IntToStr(FPlaces[I].Line);
end;

function TSdNavHistory.DebugText: string;
var
  I: Integer;
begin
  Result := IntToStr(FIndex) + '|';
  for I := 0 to FCount - 1 do
    with FPlaces[I] do
    begin
      Result := Result + Format('%s:%d:%d', [ExtractFileName(FileName), Line, Col]);
      if Design then Result := Result + ':d';
      Result := Result + ';';
    end;
end;

end.
