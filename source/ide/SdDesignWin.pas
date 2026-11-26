{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDesignWin;

{ D7 Studio - Borland's design-time windows: the action list editor, the collection editor,
  the menu designer, the fields editor ... (descendants of DesignWindows.TDesignWindow).

  They are forms of the design packages and they float, exactly as they do in Delphi. They are
  NOT docked into the main window - the user's explicit decision, and the one exception to the
  single-window model.

  What the shell adds, because D7 Studio is one big window where Delphi is many small ones:

  * The main window owns them (Win32 owner): they stay in front of it - one works in such a
    window and in the Object Inspector at the same time - are minimised with it and have no
    task bar button. Delphi's own owner, the hidden application window, would let them
    disappear behind the main window with the first click on the inspector.
  * A new window opens beside the left column, below the tool bars. Delphi puts it 200 px from
    the left edge of the screen and 2 px below its main window (the bar at the top of the
    screen); that fixed x would be on the wrong monitor, or on top of the inspector. Further
    windows cascade.
  * A window is shown only while its form is (OnShown: the design view of its page). In Delphi the code editor is a window of its own that covers
    them; here, in front of the main window, they stayed over the code, and choosing in one
    brought its form back (IDesigner.Activate: "give focus to the form designer window and bring
    it to the front", Delphi 7's help) - so going to the code left an action list editor open,
    and choosing in it switched back to the design. They are hidden and
    shown again as Delphi hides them while it debugs: their own IDesignWindow.WindowHide /
    WindowShow; they stay open.

  The windows are found through the design notification every TDesignWindow registers while
  it is constructed (TDesignHost.OnDesignWindow). }

interface

uses
  Windows, SysUtils, Classes, Forms, DesignIntf;

type
  TDesignOriginEvent = function: TPoint of object;
  TDesignShownEvent = function(Root: TComponent): Boolean of object;   // the form (root) of a designer

  TDesignWindows = class(TComponent)
  private
    FMain: TCustomForm;
    FForms: TList;               // the design windows that are alive
    FNew: TList;                 // ... that were not shown yet
    FHidden: TList;              // ... hidden while their form is not shown
    FPlaced: Integer;
    FOnGetOrigin: TDesignOriginEvent;
    FOnShown: TDesignShownEvent;
    procedure ShowWithForm(F: TCustomForm);
    procedure Place(F: TCustomForm);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AMain: TCustomForm); reintroduce;
    destructor Destroy; override;
    procedure Add(F: TCustomForm);          // a design window is being constructed
    procedure Remove(F: TCustomForm);       // ... destroyed
    procedure Sync;                         // owner and first position; cheap, call often
    procedure CloseAll;
    function Count: Integer;
    property OnGetOrigin: TDesignOriginEvent read FOnGetOrigin write FOnGetOrigin;
    { this form (a designer's root) is shown (nil: no answer, every window stays as it is) }
    property OnShown: TDesignShownEvent read FOnShown write FOnShown;
  end;

implementation

uses
  DesignWindows, SdUI;

constructor TDesignWindows.Create(AMain: TCustomForm);
begin
  inherited Create(AMain);
  FMain := AMain;
  FForms := TList.Create;
  FNew := TList.Create;
  FHidden := TList.Create;
end;

{ nil once freed: inherited Destroy may still call Notification, which looks at FForms (the
  Customize dialog crashed that way) }
destructor TDesignWindows.Destroy;
begin
  FreeAndNil(FHidden);
  FreeAndNil(FNew);
  FreeAndNil(FForms);
  inherited;
end;

function TDesignWindows.Count: Integer;
begin
  Result := FForms.Count;
end;

procedure TDesignWindows.Add(F: TCustomForm);
begin
  if (F = nil) or (F = FMain) or (FForms.IndexOf(F) >= 0) or (csDestroying in F.ComponentState) then Exit;
  FForms.Add(F);
  FNew.Add(F);
  F.FreeNotification(Self);
end;

procedure TDesignWindows.Remove(F: TCustomForm);
begin
  FForms.Remove(F);
  FNew.Remove(F);
  FHidden.Remove(F);
end;

procedure TDesignWindows.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (FForms <> nil) and (AComponent is TCustomForm) then
    Remove(TCustomForm(AComponent));
end;

{ beside the left column, below the tool bars; the next ones one caption further down-right;
  always inside the work area of the monitor the main window is on }
procedure TDesignWindows.Place(F: TCustomForm);
var
  P: TPoint;
  Area: TRect;
  Step: Integer;
begin
  if Assigned(FOnGetOrigin) then P := FOnGetOrigin
  else P := FMain.ClientToScreen(Point(240, 90));
  Step := GetSystemMetrics(SM_CYCAPTION) + GetSystemMetrics(SM_CYSIZEFRAME);
  Inc(P.X, (FPlaced mod 6) * Step);
  Inc(P.Y, (FPlaced mod 6) * Step);
  Inc(FPlaced);
  Area := UIWorkArea(FMain.Handle);      // Screen's monitors can be stale (nil: an access violation)
  if P.X + F.Width > Area.Right then P.X := Area.Right - F.Width;
  if P.Y + F.Height > Area.Bottom then P.Y := Area.Bottom - F.Height;
  if P.X < Area.Left then P.X := Area.Left;
  if P.Y < Area.Top then P.Y := Area.Top;
  F.SetBounds(P.X, P.Y, F.Width, F.Height);
end;

procedure TDesignWindows.Sync;
var
  I: Integer;
  F: TCustomForm;
begin
  { nothing is showing (every window is new, or none is left): the places start over }
  if FForms.Count = FNew.Count then FPlaced := 0;
  if (FForms.Count = 0) or not FMain.HandleAllocated then Exit;
  for I := FForms.Count - 1 downto 0 do
  begin
    F := TCustomForm(FForms[I]);
    if not F.HandleAllocated then Continue;
    { the window handle can be created again at any time: the owner goes with it }
    if GetWindow(F.Handle, GW_OWNER) <> FMain.Handle then
      SetWindowLong(F.Handle, GWL_HWNDPARENT, Longint(FMain.Handle));
    if F.Visible and (FNew.IndexOf(F) >= 0) then
    begin
      FNew.Remove(F);
      Place(F);
    end;
    ShowWithForm(F);
  end;
end;

{ a design window of a form that is not shown is hidden, and shown again with its form }
procedure TDesignWindows.ShowWithForm(F: TCustomForm);
var
  W: IDesignWindow;
  D: IDesigner;
  Want: Boolean;
begin
  if not Assigned(FOnShown) or not (F is TDesignWindow) or not F.Visible then Exit;
  D := TDesignWindow(F).Designer;
  if (D = nil) or not Supports(F, IDesignWindow, W) then Exit;
  Want := FOnShown(D.Root);
  if not Want and IsWindowVisible(F.Handle) then
  begin
    W.WindowHide;
    if FHidden.IndexOf(F) < 0 then FHidden.Add(F);
  end
  else if Want and (FHidden.IndexOf(F) >= 0) then
  begin
    FHidden.Remove(F);
    W.WindowShow;
  end;
end;

procedure TDesignWindows.CloseAll;
var
  I: Integer;
begin
  for I := FForms.Count - 1 downto 0 do
    if I < FForms.Count then
      try
        TCustomForm(FForms[I]).Free;
      except
      end;
end;

end.
