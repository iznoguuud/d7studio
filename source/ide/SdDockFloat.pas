{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDockFloat;

{ D7 Studio - the window of a floating group of the dock (SdDock). A
  tool window owned by the window of the
  dock: above it, minimized with it, without a button on the task bar. Windows gives it no
  caption: the group's own caption (TSdDockCaption) is its title bar and moves it, as a drag of
  a docked caption moves a group. Its frame is the IDE's flat 1 px border (WS_BORDER,
  UIPaintFrameBorder) with a margin inside it where the pointer sizes the window. What is inside
  is the dock's: it lays it out (OnResize). It is shown without taking the activation - a view
  the IDE shows by itself (Messages after a compile, the views of a stop) does not take the
  keyboard from the editor; a View command gives its view the keyboard, which activates the
  window (TSdDock.FocusPanel), and a view that has the keyboard keeps it when its group floats or
  docks (TSdDock.KeepFocusIn). Its .dfm has
  DefaultMonitor = dmDesktop: with the VCL's dmActiveForm, showing it moved it from its monitor
  onto the active form's (the same place relative to that monitor), so a desktop with floating
  groups on other monitors was not restored correctly. }

interface

uses
  Windows, Messages, Classes, Controls, Forms;

const
  FloatMargin = 3;                  // inside the border, around the group: sizes the window

type
  TDockFloatForm = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    FOwnerWnd: HWND;
    FMinWidth, FMinHeight: Integer;
    procedure WMNCHitTest(var Message: TWMNCHitTest); message WM_NCHITTEST;
    procedure WMNCPaint(var Message: TMessage); message WM_NCPAINT;
    procedure WMNCActivate(var Message: TWMNCActivate); message WM_NCACTIVATE;
    procedure WMGetMinMaxInfo(var Message: TWMGetMinMaxInfo); message WM_GETMINMAXINFO;
    procedure CMShowingChanged(var Message: TMessage); message CM_SHOWINGCHANGED;
    procedure WMShowWindow(var Message: TWMShowWindow); message WM_SHOWWINDOW;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    { AOwnerWnd: the window it belongs to (the main window) }
    constructor CreateFor(AOwnerWnd: HWND; AMinWidth, AMinHeight: Integer);
    procedure MoveTo(X, Y: Integer);  // without activation (a drag of its caption)
  end;

implementation

{$R *.dfm}

uses
  SdUI;

constructor TDockFloatForm.CreateFor(AOwnerWnd: HWND; AMinWidth, AMinHeight: Integer);
begin
  FOwnerWnd := AOwnerWnd;
  FMinWidth := AMinWidth;
  FMinHeight := AMinHeight;
  inherited Create(nil);            // the dock frees it (with nil its name is made unique)
end;

procedure TDockFloatForm.FormCreate(Sender: TObject);
begin
  UIApplyFont(Self);
end;

{ a popup with a 1 px frame, owned by the main window (not by the VCL's application window);
  no CS_HREDRAW / CS_VREDRAW: a resize repaints what it uncovers, not the views inside }
procedure TDockFloatForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := WS_POPUP or WS_BORDER or WS_CLIPCHILDREN or WS_CLIPSIBLINGS;
  Params.ExStyle := (Params.ExStyle or WS_EX_TOOLWINDOW) and not WS_EX_APPWINDOW;
  if FOwnerWnd <> 0 then Params.WndParent := FOwnerWnd;
  with Params.WindowClass do style := style and not (CS_HREDRAW or CS_VREDRAW);
end;

{ The VCL shows a form with ShowWindow, which activates it: shown and hidden as any control is,
  without activation (Visible stays the VCL's) }
procedure TDockFloatForm.CMShowingChanged(var Message: TMessage);
const
  ShowHide: array[Boolean] of UINT = (SWP_HIDEWINDOW, SWP_SHOWWINDOW);
begin
  SetWindowPos(Handle, 0, 0, 0, 0, 0, SWP_NOSIZE or SWP_NOMOVE or SWP_NOZORDER or
    SWP_NOACTIVATE or ShowHide[Showing]);
end;

{ The owner window hides its owned windows while the IDE is minimized and shows them again when
  it is restored (ShowOwnedPopups). The VCL's TCustomForm shows the form again whatever its
  Visible is: a group closed in the meantime stays hidden. }
procedure TDockFloatForm.WMShowWindow(var Message: TWMShowWindow);
begin
  if (Message.Status = SW_PARENTOPENING) and not Visible then Exit;
  inherited;
end;

procedure TDockFloatForm.MoveTo(X, Y: Integer);
begin
  if HandleAllocated then
    SetWindowPos(Handle, 0, X, Y, 0, 0, SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE)
  else
    SetBounds(X, Y, Width, Height);
end;

{ the margin inside the border sizes the window: its sides, and 8 px at the corners. The
  position comes from the message. }
procedure TDockFloatForm.WMNCHitTest(var Message: TWMNCHitTest);
const
  Corner = 8;
var
  P: TPoint;
  L, R, T, B: Boolean;
begin
  inherited;
  if Message.Result <> HTCLIENT then Exit;
  P := ScreenToClient(SmallPointToPoint(Message.Pos));
  L := P.X < FloatMargin;
  R := P.X >= ClientWidth - FloatMargin;
  T := P.Y < FloatMargin;
  B := P.Y >= ClientHeight - FloatMargin;
  { near a corner along an edge: the corner }
  if (T or B) and (P.X < Corner) then L := True;
  if (T or B) and (P.X >= ClientWidth - Corner) then R := True;
  if (L or R) and (P.Y < Corner) then T := True;
  if (L or R) and (P.Y >= ClientHeight - Corner) then B := True;
  if T and L then Message.Result := HTTOPLEFT
  else if T and R then Message.Result := HTTOPRIGHT
  else if B and L then Message.Result := HTBOTTOMLEFT
  else if B and R then Message.Result := HTBOTTOMRIGHT
  else if L then Message.Result := HTLEFT
  else if R then Message.Result := HTRIGHT
  else if T then Message.Result := HTTOP
  else if B then Message.Result := HTBOTTOM;
end;

{ the IDE's flat border over the frame Windows draws black (also when it is activated) }
procedure TDockFloatForm.WMNCPaint(var Message: TMessage);
begin
  inherited;
  UIPaintFrameBorder(Handle);
end;

procedure TDockFloatForm.WMNCActivate(var Message: TWMNCActivate);
begin
  inherited;
  UIPaintFrameBorder(Handle);
end;

procedure TDockFloatForm.WMGetMinMaxInfo(var Message: TWMGetMinMaxInfo);
begin
  inherited;
  Message.MinMaxInfo^.ptMinTrackSize := Point(FMinWidth, FMinHeight);
end;

end.
