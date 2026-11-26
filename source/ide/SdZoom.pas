{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdZoom;

{ D7 Studio - the views that zoom: the code editor, the form designer, the Diagram tab, the image,
  text and hex editors of the resources. One interface for all of them (ISdZoomView): View | Zoom
  and the zoom bar on the page bar (ZoomBar of SdMain.dfm: its commands), the wheel and the status
  bar use it. The wheel zooms with the key of Environment Options | Preferences | Zoom key held
  ([UI] ZoomKey): Ctrl, Ctrl+Shift, Alt or none; without it the wheel scrolls. The editors' zoom is
  one for every editor (EditorZoom). }

interface

uses
  Windows, Classes, Controls;

type
  TSdZoomLevels = array of Integer;

  { a view that zooms; percentages: 100 the view's own size }
  ISdZoomView = interface
    ['{5B0D7A3C-9E21-4F6B-8C47-2A1D6E9F3B58}']
    function ZoomPercent: Integer;                 // the zoom shown
    function CanZoom(Delta: Integer): Boolean;     // a step in (1) or out (-1) can be taken
    { Delta steps in (> 0) or out; AtPoint: the place at At (screen) stays where it is - the wheel -,
      else the middle of the view }
    procedure ZoomStep(Delta: Integer; AtPoint: Boolean; const At: TPoint);
    procedure ZoomTo(Percent: Integer);            // the nearest zoom the view has; the middle stays
    function CanZoomFit: Boolean;                  // the view can show the whole of itself
    procedure ZoomFit;
  end;

  TSdWheelZoomKey = (wzCtrl, wzCtrlShift, wzAlt, wzNone);

const
  WheelZoomKeyNames: array[TSdWheelZoomKey] of string = ('Ctrl + wheel', 'Ctrl+Shift + wheel',
    'Alt + wheel', 'None (the wheel scrolls)');
  WheelZoomKeyKeys: array[TSdWheelZoomKey] of string = ('Ctrl', 'CtrlShift', 'Alt', 'None');
  { the zoom levels of the form designer, the Diagram tab and the hex editor: the multiples of this,
    per cent (ZoomPercentStep) }
  ZoomStepPercent = 5;

var
  { the key that makes the wheel zoom (LoadWheelZoomKey) }
  WheelZoomKey: TSdWheelZoomKey = wzCtrl;
  { a view's zoom changed by itself (the wheel, a command of its own): the zoom bar and the status
    bar follow (the main form) }
  OnZoomChanged: TNotifyEvent = nil;
  { the editors' zoom changed: every editor takes it (the main form: TSciEdit.ApplyZoom) }
  OnEditorZoom: TNotifyEvent = nil;

{ the wheel zooms with the keys of Shift (a mouse message's; Alt from the keyboard): the zoom key
  held and no other of Ctrl, Shift and Alt - and no mouse button: a turn of the wheel while a
  button is down (a selection dragged) never zooms }
function WheelZooms(Shift: TShiftState): Boolean;
{ ... with the keys of a WM_MOUSEWHEEL (MK_CONTROL, MK_SHIFT, the buttons; Alt from the keyboard) }
function WheelZoomsKeys(Keys: Integer): Boolean;
{ a view zoomed by the wheel: with Alt as the zoom key, the Alt released afterwards must not open
  the menu bar - TakeZoomAlt says so once }
procedure WheelZoomed;
function TakeZoomAlt: Boolean;
{ the wheel with the zoom key held (Zooms: WheelZooms / WheelZoomsKeys said so): View a step per
  whole notch, the place at the screen point At staying where it is - parts of notches add up in
  Acc (UIWheelSteps). True when the wheel zooms, also while a turn is short of a notch }
function ZoomByWheel(const View: ISdZoomView; var Acc: Integer; Zooms: Boolean; WheelDelta: Integer;
  const At: TPoint): Boolean;
{ a step in (Delta > 0) or out from Current stays within Lowest .. Highest }
function CanStepZoom(Current, Delta, Lowest, Highest: Integer): Boolean;
{ Sender's zoom changed (OnZoomChanged) }
procedure ZoomChanged(Sender: TObject);
{ the key of [UI] ZoomKey ('' and unknown names: Ctrl) }
function WheelZoomKeyOf(const Key: string): TSdWheelZoomKey;
procedure LoadWheelZoomKey;
{ the level Delta steps in or out from Current among Levels: a zoom between two levels steps to the
  next one in that direction; the first and the last level are the ends }
function ZoomLevelStep(const Levels: TSdZoomLevels; Current, Delta: Integer): Integer;
{ the zoom Delta steps in (> 0) or out from Current among the multiples of ZoomStepPercent - a
  zoom between two of them (a fitted one) steps to the next one in that direction -, kept within
  Lowest .. Highest }
function ZoomPercentStep(Current, Delta, Lowest, Highest: Integer): Integer;
function ZoomText(Percent: Integer): string;      // '100 %'
{ the code editors' zoom: one for every editor - the files' pages, a text resource's -, kept in the
  settings (Editor Options' Zoom: Scintilla's points added to the font size, -10 .. 20) }
function EditorZoom: ISdZoomView;

implementation

uses
  SysUtils, SdUI, SdSettings, SdEditorOptions;

const
  EditorZoomMin = -10;            // Scintilla's range of points
  EditorZoomMax = 20;

var
  AltZoomed: Boolean;

function WheelZooms(Shift: TShiftState): Boolean;
var
  Keys: TShiftState;
begin
  Result := False;
  if Shift * [ssLeft, ssRight, ssMiddle] <> [] then Exit;
  Keys := Shift * [ssCtrl, ssShift, ssAlt];
  case WheelZoomKey of
    wzCtrl: Result := Keys = [ssCtrl];
    wzCtrlShift: Result := Keys = [ssCtrl, ssShift];
    wzAlt: Result := Keys = [ssAlt];
  else
    Result := False;
  end;
end;

function WheelZoomsKeys(Keys: Integer): Boolean;
const
  MK_XBUTTON1 = $20;
  MK_XBUTTON2 = $40;
var
  Shift: TShiftState;
begin
  Result := False;
  if Keys and (MK_LBUTTON or MK_RBUTTON or MK_MBUTTON or MK_XBUTTON1 or MK_XBUTTON2) <> 0 then Exit;
  Shift := [];
  if Keys and MK_CONTROL <> 0 then Include(Shift, ssCtrl);
  if Keys and MK_SHIFT <> 0 then Include(Shift, ssShift);
  if GetKeyState(VK_MENU) < 0 then Include(Shift, ssAlt);
  Result := WheelZooms(Shift);
end;

procedure WheelZoomed;
begin
  if WheelZoomKey = wzAlt then AltZoomed := True;
end;

function TakeZoomAlt: Boolean;
begin
  Result := AltZoomed;
  AltZoomed := False;
end;

function ZoomByWheel(const View: ISdZoomView; var Acc: Integer; Zooms: Boolean; WheelDelta: Integer;
  const At: TPoint): Boolean;
var
  N: Integer;
begin
  Result := Zooms;
  if not Zooms or (View = nil) then Exit;
  N := UIWheelSteps(Acc, WheelDelta, 1);
  if N = 0 then Exit;
  View.ZoomStep(N, True, At);
  WheelZoomed;
end;

function CanStepZoom(Current, Delta, Lowest, Highest: Integer): Boolean;
begin
  if Delta > 0 then Result := Current < Highest else Result := Current > Lowest;
end;

procedure ZoomChanged(Sender: TObject);
begin
  if Assigned(OnZoomChanged) then OnZoomChanged(Sender);
end;

function WheelZoomKeyOf(const Key: string): TSdWheelZoomKey;
var
  K: TSdWheelZoomKey;
begin
  Result := wzCtrl;
  for K := Low(TSdWheelZoomKey) to High(TSdWheelZoomKey) do
    if SameText(Key, WheelZoomKeyKeys[K]) then Result := K;
end;

procedure LoadWheelZoomKey;
begin
  if Settings <> nil then WheelZoomKey := WheelZoomKeyOf(Settings.ReadString('UI', 'ZoomKey', ''));
end;

function ZoomLevelStep(const Levels: TSdZoomLevels; Current, Delta: Integer): Integer;
var
  I: Integer;
begin
  Result := Current;
  if Length(Levels) = 0 then Exit;
  while Delta > 0 do
  begin
    I := 0;
    while (I <= High(Levels)) and (Levels[I] <= Result) do Inc(I);
    if I > High(Levels) then Break;
    Result := Levels[I];
    Dec(Delta);
  end;
  while Delta < 0 do
  begin
    I := High(Levels);
    while (I >= 0) and (Levels[I] >= Result) do Dec(I);
    if I < 0 then Break;
    Result := Levels[I];
    Inc(Delta);
  end;
end;

function ZoomPercentStep(Current, Delta, Lowest, Highest: Integer): Integer;
begin
  Result := Current;
  while Delta > 0 do
  begin
    Result := (Result div ZoomStepPercent + 1) * ZoomStepPercent;
    Dec(Delta);
  end;
  while Delta < 0 do
  begin
    Result := ((Result + ZoomStepPercent - 1) div ZoomStepPercent - 1) * ZoomStepPercent;
    Inc(Delta);
  end;
  if Result < Lowest then Result := Lowest;
  if Result > Highest then Result := Highest;
end;

function ZoomText(Percent: Integer): string;
begin
  Result := IntToStr(Percent) + ' %';
end;

{ ---------------------------------------------------------------- the editors' zoom }

type
  { one for every editor: no reference counting (a global object) }
  TSdEditorZoom = class(TObject, IInterface, ISdZoomView)
  private
    function FontSize: Integer;
    function PercentOf(Points: Integer): Integer;
    procedure SetPoints(Points: Integer);
  protected
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    function ZoomPercent: Integer;
    function CanZoom(Delta: Integer): Boolean;
    procedure ZoomStep(Delta: Integer; AtPoint: Boolean; const At: TPoint);
    procedure ZoomTo(Percent: Integer);
    function CanZoomFit: Boolean;
    procedure ZoomFit;
  end;

var
  TheEditorZoom: TSdEditorZoom;

function EditorZoom: ISdZoomView;
begin
  if TheEditorZoom = nil then TheEditorZoom := TSdEditorZoom.Create;
  Result := TheEditorZoom;
end;

function TSdEditorZoom.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then Result := S_OK else Result := E_NOINTERFACE;
end;

function TSdEditorZoom._AddRef: Integer;
begin
  Result := -1;
end;

function TSdEditorZoom._Release: Integer;
begin
  Result := -1;
end;

function TSdEditorZoom.FontSize: Integer;
begin
  Result := EditorOptions.FontSize;
  if Result <= 0 then Result := 10;
end;

{ the font's size with Points added, against the font's size }
function TSdEditorZoom.PercentOf(Points: Integer): Integer;
begin
  Result := Round((FontSize + Points) * 100 / FontSize);
end;

procedure TSdEditorZoom.SetPoints(Points: Integer);
begin
  if Points < EditorZoomMin then Points := EditorZoomMin;
  if Points > EditorZoomMax then Points := EditorZoomMax;
  if Points = EditorOptions.Zoom then Exit;
  EditorOptions.Zoom := Points;
  if Assigned(OnEditorZoom) then OnEditorZoom(nil);
  ZoomChanged(nil);
end;

function TSdEditorZoom.ZoomPercent: Integer;
begin
  Result := PercentOf(EditorOptions.Zoom);
end;

function TSdEditorZoom.CanZoom(Delta: Integer): Boolean;
begin
  Result := CanStepZoom(EditorOptions.Zoom, Delta, EditorZoomMin, EditorZoomMax);
end;

{ a point a step, as Scintilla's own zoom }
procedure TSdEditorZoom.ZoomStep(Delta: Integer; AtPoint: Boolean; const At: TPoint);
begin
  SetPoints(EditorOptions.Zoom + Delta);
end;

procedure TSdEditorZoom.ZoomTo(Percent: Integer);
begin
  SetPoints(Round(FontSize * (Percent - 100) / 100));
end;

function TSdEditorZoom.CanZoomFit: Boolean;
begin
  Result := False;
end;

procedure TSdEditorZoom.ZoomFit;
begin
end;

initialization

finalization
  FreeAndNil(TheEditorZoom);
end.
