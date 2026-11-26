{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdSplash;

{ D7 Studio - the start-up screen: shown while the design packages load,
  the main window is made and the experts load, as Delphi 7's splash screen is, and freed when the
  main window is on the screen. Unlike Delphi 7's it names the package being loaded. -ns or /ns on
  the command line starts without it, as in Delphi. The picture is the bitmap resource SPLASH
  (splash.bmp); the status line is drawn over its bottom strip.

  Experts put themselves on Delphi 7's splash screen: they find it by its name, SplashScreen
  (GExperts also wants the class TForm itself), and add their controls to it. So the window shown
  is a plain TForm of that name, which takes the picture and the status line of this form's
  design. What experts add is laid out for this picture (SplashExpertsAdded). }

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, ExtCtrls, StdCtrls;

type
  TSplashForm = class(TForm)
    imgSplash: TImage;
    lblLine: TLabel;
    lblStatus: TLabel;
    procedure FormCreate(Sender: TObject);
  private
    FScreen: TForm;                                // the window shown, named SplashScreen
    FScreenProc: TWndMethod;                       // its window procedure before ScreenWndProc
    procedure PackageLoading(const FileName: string);
    procedure MakeScreen;
    procedure ScreenWndProc(var Message: TMessage);
  public
    destructor Destroy; override;
    class procedure Start;                         // shows it, unless -ns / /ns
    class procedure Status(const Text: string);    // the status line, painted at once
    class procedure Finish;                        // frees it (nothing when it was not shown)
  end;

{ -ns or /ns: the switch that starts without the start-up screen (not a file to open) }
function IsNoSplashSwitch(const Arg: string): Boolean;
{ What experts put on the start-up screen, laid out for its picture: GExperts' rows (PluginLogoN,
  PluginTitleN, PluginVersionN - placed at x 140, y 150 + 32 N, in white, for Delphi 7's dark
  picture) go under the program's name, in the picture's colours. Anything else stays where its
  expert put it (CnWizards' logo in the top right corner). Called after each expert has loaded. }
procedure SplashExpertsAdded;

var
  SplashForm: TSplashForm;

implementation

uses
  SdUI, SdSettings, SdDesignHost;

{$R *.dfm}

const
  StatusBottom = 14;        // the status line's distance from the bottom edge
  { the rows of experts' entries: under the line below the name (lblLine: x 202, y 147, 16 px), in
    its colours - the picture's name's and that line's }
  ExpertRowsLeft = 202;
  ExpertRowsTop = 180;
  ExpertTitleColor = $1E1E1E;
  ExpertVersionColor = $616161;

{ no message loop runs yet: the window painted now, with the windows experts put on it (Update
  paints the window itself only) }
procedure PaintNow(F: TForm);
begin
  RedrawWindow(F.Handle, nil, 0, RDW_INVALIDATE or RDW_UPDATENOW or RDW_ALLCHILDREN);
end;

function IsNoSplashSwitch(const Arg: string): Boolean;
begin
  Result := SameText(Arg, '-ns') or SameText(Arg, '/ns');
end;

procedure TSplashForm.FormCreate(Sender: TObject);
var
  R: TRect;
begin
  UIApplyFont(lblStatus.Font);
  imgSplash.Picture.Bitmap.LoadFromResourceName(HInstance, 'SPLASH');
  ClientWidth := imgSplash.Picture.Width;
  ClientHeight := imgSplash.Picture.Height;
  imgSplash.SetBounds(0, 0, ClientWidth, ClientHeight);
  lblStatus.Top := ClientHeight - StatusBottom - lblStatus.Height;
  { centred on the monitor where the main window opens }
  R := Screen.MonitorFromRect(MainWindowRect, mdNearest).WorkareaRect;
  SetBounds(R.Left + (R.Right - R.Left - Width) div 2, R.Top + (R.Bottom - R.Top - Height) div 2,
    Width, Height);
  MakeScreen;
end;

{ the window shown: a plain TForm named SplashScreen, as Delphi 7's, with this form's bounds,
  picture and status line }
procedure TSplashForm.MakeScreen;
begin
  FScreen := TForm.CreateNew(nil);
  FScreen.Name := 'SplashScreen';
  FScreen.BorderStyle := bsNone;
  FScreen.Caption := Caption;
  FScreen.Color := Color;
  FScreen.Font := Font;
  { the picture and the status line paint at once, without erasing }
  FScreen.DoubleBuffered := True;
  FScreen.SetBounds(Left, Top, Width, Height);
  imgSplash.Parent := FScreen;
  lblLine.Parent := FScreen;
  lblStatus.Parent := FScreen;
  { no task bar button: the main window brings the program's }
  SetWindowLong(FScreen.Handle, GWL_EXSTYLE, GetWindowLong(FScreen.Handle, GWL_EXSTYLE) or WS_EX_TOOLWINDOW);
  FScreenProc := FScreen.WindowProc;
  FScreen.WindowProc := ScreenWndProc;
end;

{ The window shown is Visible for the VCL, so that the windows experts put on it show at once, as
  on Delphi 7's splash screen (the VCL keeps the windows of a form that is not showing hidden).
  It is shown without being activated - the VCL's own showing activates a form: it takes no input,
  and the main window is activated when it appears. }
procedure TSplashForm.ScreenWndProc(var Message: TMessage);
begin
  if (Message.Msg = CM_SHOWINGCHANGED) and FScreen.Showing then
    ShowWindow(FScreen.Handle, SW_SHOWNOACTIVATE)
  else
    FScreenProc(Message);
end;

{ the picture and the status line go first (their parent is the window shown), then the window
  with what experts put on it }
destructor TSplashForm.Destroy;
begin
  inherited;
  if FScreen <> nil then
  begin
    FScreen.WindowProc := FScreenProc;
    FScreen.Free;
  end;
end;

procedure TSplashForm.PackageLoading(const FileName: string);
begin
  Status('Loading ' + ExtractFileName(FileName) + '...');
end;

class procedure TSplashForm.Start;
var
  I: Integer;
begin
  for I := 1 to ParamCount do
    if IsNoSplashSwitch(ParamStr(I)) then Exit;
  SplashForm := TSplashForm.Create(nil);
  SplashForm.FScreen.Visible := True;           // shown without being activated (ScreenWndProc)
  PaintNow(SplashForm.FScreen);
  DesignHost.OnLoading := SplashForm.PackageLoading;
end;

class procedure TSplashForm.Status(const Text: string);
begin
  if SplashForm = nil then Exit;
  SplashForm.lblStatus.Caption := Text;
  PaintNow(SplashForm.FScreen);
  UITestStartShot(SplashForm.FScreen, 'D7S_SPLASHSHOT');
end;

class procedure TSplashForm.Finish;
begin
  if SplashForm = nil then Exit;
  DesignHost.OnLoading := nil;
  FreeAndNil(SplashForm);
end;

procedure SplashExpertsAdded;
var
  F: TForm;
  N, Y, Bottom: Integer;
  Logo, Title, Version: TComponent;
begin
  if (SplashForm = nil) or (SplashForm.FScreen = nil) then Exit;
  F := SplashForm.FScreen;
  Y := ExpertRowsTop;
  N := 0;
  while F.FindComponent('PluginLogo' + IntToStr(N)) is TControl do
  begin
    Logo := F.FindComponent('PluginLogo' + IntToStr(N));
    Title := F.FindComponent('PluginTitle' + IntToStr(N));
    Version := F.FindComponent('PluginVersion' + IntToStr(N));
    TControl(Logo).SetBounds(ExpertRowsLeft, Y, TControl(Logo).Width, TControl(Logo).Height);
    Bottom := Y + TControl(Logo).Height;
    if Title is TLabel then
    begin
      TLabel(Title).Font.Color := ExpertTitleColor;
      TLabel(Title).SetBounds(ExpertRowsLeft + TControl(Logo).Width + 8, Y, TLabel(Title).Width,
        TLabel(Title).Height);
      if Y + TLabel(Title).Height > Bottom then Bottom := Y + TLabel(Title).Height;
      if Version is TLabel then
      begin
        TLabel(Version).Font.Color := ExpertVersionColor;
        TLabel(Version).SetBounds(TLabel(Title).Left, Y + TLabel(Title).Height, TLabel(Version).Width,
          TLabel(Version).Height);
        if TLabel(Version).Top + TLabel(Version).Height > Bottom then
          Bottom := TLabel(Version).Top + TLabel(Version).Height;
      end;
    end;
    Y := Bottom + 6;
    Inc(N);
  end;
  PaintNow(F);
  UITestStartShot(F, 'D7S_SPLASHSHOT');
end;

end.
