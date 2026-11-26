{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdPageBar;

{ D7 Studio - the tool bar at the top of a page of the file area. A file's page (its Code, Design and
  Diagram views) and a resource's page each have one, inside the page's frame above what the page
  shows, in the look of every page's bar: the tool row's ground, 2 px around what it holds, a flat
  line under it. It holds the zoom bar first when the view zooms, then what the page shows there -
  the navigation boxes over the code, the Diagram tab's buttons, a resource editor's bar: left to
  right, a tool bar separator between two of them; one of them may take the width the others
  leave. It is shown while it holds something.

  The main form's bars (one of each for every page) are lent to the bar of the page shown: the next
  page's bar takes them when that page is shown, and they go back to no parent when the page goes.
  A bar of the page's own (a resource editor's) goes with the page. }

interface

uses
  Windows, Messages, Classes, Controls, SdUI;

type
  TSdPageBar = class(TSdControl)
  private
    FItems: TList;                // what it shows, left to right
    FStretch: TControl;           // ... the one that takes the width the others leave (nil: none)
    FSeps: array of Integer;      // the left edges of the separators between them
    FSepHeight: Integer;          // ... their height: the tallest tool bar's buttons
    FInner: Integer;              // the client area's height (the margins and the line are not)
    function Lent(C: TControl): Boolean;
    function InnerWidth: Integer;
    procedure Layout;
    procedure CMControlListChange(var Message: TCMControlListChange); message CM_CONTROLLISTCHANGE;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure EraseGround(DC: HDC); override;
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the bar shows Items in this order (nil ones left out) and nothing else: what it showed before
      and does not now is hidden (a lent bar stays here, hidden, until a page's bar takes it).
      Stretch, one of the items, takes the width the others leave. Shown while it shows one }
    procedure Arrange(const Items: array of TControl; Stretch: TControl);
    { test mode: shown|class@left,top widthxheight;... (client coordinates) }
    function TestText: string;
  end;

{ the width a bar takes on a page's bar: a tool bar's buttons, another control's own width }
function PageBarItemWidth(C: TControl): Integer;

implementation

uses
  SysUtils, Graphics, ComCtrls;

const
  SepWidth = 8;                   // a tool bar separator's (TToolButton, tbsSeparator)
  Margin = 2;                     // around what the bar holds (UIPageBar's)

type
  TControlAccess = class(TControl);

function PageBarItemWidth(C: TControl): Integer;
var
  I: Integer;
  B: TControl;
begin
  if C is TToolBar then
  begin
    Result := 0;
    for I := 0 to TToolBar(C).ControlCount - 1 do
    begin
      B := TToolBar(C).Controls[I];
      if B.Visible and (B.Left + B.Width > Result) then Result := B.Left + B.Width;
    end;
  end
  else
    Result := C.Width;
end;

{ ---------------------------------------------------------------- TSdPageBar }

constructor TSdPageBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csSetCaption] + [csOpaque];
  FItems := TList.Create;
  Color := UIBarColor;
  ParentShowHint := False;
  ShowHint := True;
  { as high as an edit (the boxes it may hold), the margins and the line around it }
  FInner := UIEditHeight;
  UIBottomBorder(Self, 0, Margin);
  Height := FInner + 2 * Margin + 1;
end;

{ the client area's width - also before the window is made, when ClientWidth does not know the
  margins yet }
function TSdPageBar.InnerWidth: Integer;
begin
  if HandleAllocated then Result := ClientWidth else Result := Width - 2 * Margin;
end;

{ the lent bars go back to no parent: they are the main form's, not the page's }
destructor TSdPageBar.Destroy;
var
  I: Integer;
  C: TControl;
begin
  for I := ControlCount - 1 downto 0 do
  begin
    C := Controls[I];
    if Lent(C) then
    begin
      C.Visible := False;
      C.Parent := nil;
    end;
  end;
  FreeAndNil(FItems);
  inherited Destroy;
end;

{ its children are covered by the bars it holds: no erase under them, no CS_HREDRAW / CS_VREDRAW
  (TSdControl) - the bar is laid out again when its width changes }
procedure TSdPageBar.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

{ a bar the page does not own: the main form's, lent to the page shown }
function TSdPageBar.Lent(C: TControl): Boolean;
var
  O: TComponent;
begin
  O := C.Owner;
  while (O <> nil) and (O <> Owner) do O := O.Owner;
  Result := O = nil;
end;

{ a bar taken by another page's bar, or freed: not one of the bar's any more }
procedure TSdPageBar.CMControlListChange(var Message: TCMControlListChange);
begin
  inherited;
  if not Message.Inserting and (FItems <> nil) and (FItems.IndexOf(Message.Control) >= 0) then
  begin
    FItems.Remove(Message.Control);
    if Message.Control = FStretch then FStretch := nil;
    if not (csDestroying in ComponentState) then
    begin
      Visible := FItems.Count > 0;
      Layout;
    end;
  end;
end;

procedure TSdPageBar.Arrange(const Items: array of TControl; Stretch: TControl);
var
  I: Integer;
  C: TControl;
  Wanted: TList;
begin
  Wanted := TList.Create;
  try
    for I := Low(Items) to High(Items) do
      if (Items[I] <> nil) and (Wanted.IndexOf(Items[I]) < 0) then Wanted.Add(Items[I]);
    { what it shows no more: hidden }
    for I := 0 to ControlCount - 1 do
    begin
      C := Controls[I];
      if Wanted.IndexOf(C) < 0 then C.Visible := False;
    end;
    FItems.Clear;
    for I := 0 to Wanted.Count - 1 do
    begin
      C := TControl(Wanted[I]);
      if C.Parent <> Self then
      begin
        C.Visible := False;
        C.Parent := Self;
      end;
      C.Align := alNone;
      TControlAccess(C).Color := UIBarColor;
      if C is TToolBar then
      begin
        TToolBar(C).AutoSize := False;
        C.Height := TToolBar(C).ButtonHeight;
      end
      else
      begin
        { a strip (a form, a panel) as high as the bar's client area, what it holds in its middle }
        C.Height := FInner;
        if C is TWinControl then UICentreChildren(TWinControl(C), FInner);
      end;
      FItems.Add(C);
    end;
    if (Stretch <> nil) and (FItems.IndexOf(Stretch) >= 0) then FStretch := Stretch else FStretch := nil;
    Layout;
    for I := 0 to FItems.Count - 1 do TControl(FItems[I]).Visible := True;
    Visible := FItems.Count > 0;
  finally
    Wanted.Free;
  end;
end;

{ the items side by side from the left, in the middle of the height, a separator between two; the
  stretching one as wide as the others leave }
procedure TSdPageBar.Layout;
var
  I, X, W, H, Fixed, N: Integer;
  C: TControl;
  Ctls: array of TWinControl;
  Bnds: array of TRect;
begin
  if FItems = nil then Exit;
  Fixed := 0;
  FSepHeight := FInner - 1;
  for I := 0 to FItems.Count - 1 do
  begin
    C := TControl(FItems[I]);
    if C <> FStretch then Inc(Fixed, PageBarItemWidth(C));
    if I > 0 then Inc(Fixed, SepWidth);
    if C is TToolBar then FSepHeight := TToolBar(C).ButtonHeight;
  end;
  SetLength(FSeps, 0);
  SetLength(Ctls, 0);
  SetLength(Bnds, 0);
  X := 0;
  for I := 0 to FItems.Count - 1 do
  begin
    C := TControl(FItems[I]);
    if I > 0 then
    begin
      N := Length(FSeps);
      SetLength(FSeps, N + 1);
      FSeps[N] := X;
      Inc(X, SepWidth);
    end;
    if C = FStretch then W := InnerWidth - Fixed else W := PageBarItemWidth(C);
    if W < 0 then W := 0;
    H := C.Height;                   // Arrange's: a tool bar's buttons, a strip's FInner
    if C is TWinControl then
    begin
      N := Length(Ctls);
      SetLength(Ctls, N + 1);
      SetLength(Bnds, N + 1);
      Ctls[N] := TWinControl(C);
      Bnds[N] := Bounds(X, (FInner - H) div 2, W, H);
    end
    else
      C.SetBounds(X, (FInner - H) div 2, W, H);
    Inc(X, W);
  end;
  if Length(Ctls) > 0 then UIMoveControls(Ctls, Bnds);
  if HandleAllocated then Invalidate;
end;

procedure TSdPageBar.Resize;
begin
  inherited Resize;
  Layout;
end;

{ its ground: also the ground a flat tool bar on it asks for (DrawThemeParentBackground: WM_ERASEBKGND,
  then WM_PRINTCLIENT into the tool bar's DC) }
procedure TSdPageBar.EraseGround(DC: HDC);
begin
  UIFill(DC, ClientRect, Color);
end;

procedure TSdPageBar.Paint;
var
  I, Top: Integer;
begin
  UIFill(Canvas.Handle, ClientRect, Color);
  Top := (FInner - FSepHeight) div 2;
  for I := 0 to High(FSeps) do
    UIDrawToolSeparator(Canvas.Handle, Rect(FSeps[I], Top, FSeps[I] + SepWidth, Top + FSepHeight));
end;

function TSdPageBar.TestText: string;
var
  I: Integer;
  C: TControl;
begin
  Result := IntToStr(Ord(Visible)) + '|';
  if FItems = nil then Exit;
  for I := 0 to FItems.Count - 1 do
  begin
    C := TControl(FItems[I]);
    Result := Result + Format('%s@%d,%d %dx%d;', [C.ClassName, C.Left, C.Top, C.Width, C.Height]);
  end;
end;

end.
