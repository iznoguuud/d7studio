{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit DemoGauge;

{ A control that paints itself, written for every DPI. Its sizes are given for 96 DPI and scaled to
  the DPI of the form it is on (Controls.ScaleForDpi, GetControlDpi): a form's DPI is the one of the
  monitor it is shown on, and it changes when the form moves to a monitor with another scale. The
  sizes it keeps - the ruler's steps, the labels' font - are made again on CM_DPICHANGED, which the
  VCL sends every control of a form once the form has been scaled for a new DPI.

  It shows a ruler of 96-DPI pixels (the same length on every monitor of the same scale) and a bar
  one logical inch long: as many pixels as the DPI. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls;

type
  TDpiGauge = class(TCustomControl)
  private
    FDpi: Integer;              // the DPI the sizes below were made for
    FTick, FMargin, FGap: Integer;
    FLabelFont: TFont;          // the ruler's labels: 7 points at FDpi
    FChanges: Integer;          // CM_DPICHANGED received
    procedure MakeSizes;
    procedure CMDpiChanged(var Message: TMessage); message CM_DPICHANGED;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Changes: Integer read FChanges;
  end;

implementation

const
  { at 96 DPI }
  Tick = 8;             // a step of the ruler; every Major-th one is long and labelled
  Major = 4;
  Margin = 8;
  Gap = 2;              // between a long step and its label

constructor TDpiGauge.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  FLabelFont := TFont.Create;
  Width := 360;
  Height := 76;
end;

destructor TDpiGauge.Destroy;
begin
  FLabelFont.Free;
  inherited Destroy;
end;

{ the sizes at the DPI of the control's form, and the labels' font in points at it: a TFont's
  PixelsPerInch is the DPI its Size is measured at }
procedure TDpiGauge.MakeSizes;
begin
  FDpi := GetControlDpi(Self);
  FTick := ScaleForDpi(Tick, Self);
  FMargin := ScaleForDpi(Margin, Self);
  FGap := ScaleForDpi(Gap, Self);
  FLabelFont.Assign(Font);
  FLabelFont.PixelsPerInch := FDpi;
  FLabelFont.Size := 7;
end;

{ the form was scaled for a new DPI, or the control moved to a form of another DPI }
procedure TDpiGauge.CMDpiChanged(var Message: TMessage);
begin
  inherited;
  Inc(FChanges);
  MakeSizes;
  Invalidate;
end;

procedure TDpiGauge.Paint;
var
  R: TRect;
  X, I, Base, Inch: Integer;
  S: string;
begin
  { sizes made before the control was on its form, or none yet: made at the form's DPI now }
  if FDpi <> GetControlDpi(Self) then MakeSizes;
  R := ClientRect;
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clWindow;
  Canvas.FillRect(R);
  Canvas.Pen.Color := clWindowText;
  Canvas.Pen.Width := 1;
  { one logical inch: FDpi pixels, with what it says }
  Inch := FMargin + FDpi;
  Canvas.Brush.Color := clHighlight;
  Canvas.FillRect(Rect(FMargin, FMargin, Inch, FMargin + FTick));
  Canvas.Brush.Style := bsClear;
  Canvas.Font := Font;
  S := Format('%d px at %d DPI', [FDpi, FDpi]);
  Canvas.TextOut(Inch + FMargin, FMargin + (FTick - Canvas.TextHeight(S)) div 2, S);
  { the ruler: its steps placed from 96-DPI pixels each time, so that no rounding adds up }
  Base := R.Bottom - FMargin;
  Canvas.MoveTo(FMargin, Base);
  Canvas.LineTo(R.Right - FMargin, Base);
  Canvas.Font := FLabelFont;
  I := 0;
  X := FMargin;
  while X <= R.Right - FMargin do
  begin
    Canvas.MoveTo(X, Base);
    if I mod Major = 0 then
    begin
      Canvas.LineTo(X, Base - FTick);
      S := IntToStr(I * Tick);
      Canvas.TextOut(X + FGap, Base - FTick - Canvas.TextHeight(S), S);
    end
    else
      Canvas.LineTo(X, Base - FTick div 2);
    Inc(I);
    X := FMargin + MulDiv(I * Tick, FDpi, 96);
  end;
end;

end.
