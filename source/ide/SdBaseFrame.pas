{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdBaseFrame;

{ TSdFrame: TSdControl's counterpart for a frame - the base of the views made of a .dfm and reused.
  A frame with a form file of its own, so that a form designer (Delphi 7's, D7
  Studio's) finds the ancestor of the frames derived from it: Windows never erases it
  (EraseGround), no CS_HREDRAW / CS_VREDRAW unless RedrawWhole, Paint on a canvas of its own,
  Buffered: PaintBuffer through a bitmap of its size. The drawing goes through the helpers
  TSdControl uses (UIBufferDC, UIBufferFlush). }

interface

uses
  Windows, Messages, Classes, Graphics, Controls, Forms, SdUI;

type
  TSdFrame = class(TFrame)
  private
    FCanvas: TControlCanvas;
    FBuffer: TBitmap;
    FBuffered: Boolean;
    FRedrawWhole: Boolean;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure PaintWindow(DC: HDC); override;
    procedure Paint; virtual;
    procedure EraseGround(DC: HDC); virtual;         // the erase: nothing
    procedure PaintBuffer(C: TCanvas); virtual;      // Buffered: the drawing, on the buffer's canvas
    property Canvas: TControlCanvas read FCanvas;
    property Buffered: Boolean read FBuffered write FBuffered;
    property RedrawWhole: Boolean read FRedrawWhole write FRedrawWhole;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{$R *.dfm}

constructor TSdFrame.Create(AOwner: TComponent);
begin
  FCanvas := TControlCanvas.Create;
  FCanvas.Control := Self;
  inherited Create(AOwner);
end;

destructor TSdFrame.Destroy;
begin
  inherited Destroy;
  FBuffer.Free;
  FCanvas.Free;
end;

procedure TSdFrame.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  if not FRedrawWhole then
    with Params.WindowClass do style := style and not (CS_HREDRAW or CS_VREDRAW);
end;

procedure TSdFrame.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  EraseGround(Message.DC);
  Message.Result := 1;
end;

{ the frame paints as a custom control does: PaintWindow with its canvas on the paint's DC }
procedure TSdFrame.WMPaint(var Message: TWMPaint);
begin
  ControlState := ControlState + [csCustomPaint];
  inherited;
  ControlState := ControlState - [csCustomPaint];
end;

procedure TSdFrame.PaintWindow(DC: HDC);
begin
  FCanvas.Lock;
  try
    FCanvas.Handle := DC;
    try
      Paint;
    finally
      FCanvas.Handle := 0;
    end;
  finally
    FCanvas.Unlock;
  end;
end;

procedure TSdFrame.EraseGround(DC: HDC);
begin
end;

procedure TSdFrame.Paint;
begin
  if not FBuffered then Exit;
  UIBufferDC(FBuffer, Self);
  PaintBuffer(FBuffer.Canvas);
  UIBufferFlush(FBuffer, FCanvas);
end;

procedure TSdFrame.PaintBuffer(C: TCanvas);
begin
end;

end.
