{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdFormatterPreview;

{ D7 Studio - the Formatter's preview (Tools | Formatter Options | Preview...;
  a live window): a window beside the Options dialog with a sample formatted with the values on the
  Formatter's pages, again at each change while it is open. The Formatter's section
  (SdFormatterFrame) makes it when Preview is first pressed and owns it; its window is owned by
  the Options dialog's (above it, gone with it). }

interface

uses
  Windows, Classes, Controls, Forms, SdFormatter, SdSciEdit;

type
  TFormatterPreview = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    FDialog: TCustomForm;      // the Options dialog: its window owns this one
    FEdit: TSciEdit;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    { AOwner: the Formatter's section; Dialog: the form that shows it }
    constructor CreateFor(AOwner: TComponent; Dialog: TCustomForm);
    { shown at the side of the dialog that has room on its monitor - right, else left, else over
      its right part -, as high as the dialog; brought to the front when it is open }
    procedure ShowBeside;
    { the sample formatted with V (as it is when the formatter refuses it); what the change did
      comes into view }
    procedure ShowValues(const V: TFmtValues);
  end;

implementation

{$R *.dfm}

uses
  MultiMon, SdUI, SdSciDefs;

const
  { what the preview formats: a little of everything the options are about }
  SampleText =
    'unit Sample;' + #13#10 +
    'interface' + #13#10 +
    'uses SysUtils, Classes;' + #13#10 +
    'type' + #13#10 +
    '  TShape = class(TObject)' + #13#10 +
    '  private' + #13#10 +
    '    FName: string;' + #13#10 +
    '    FCount: integer; // how many' + #13#10 +
    '  public' + #13#10 +
    '    constructor Create(const AName: string; ACount: Integer);' + #13#10 +
    '    property Name: string read FName write FName;' + #13#10 +
    '  end;' + #13#10 +
    'const' + #13#10 +
    '  Limit = 10;' + #13#10 +
    '  Names: array[0..2] of string = (''one'', ''two'', ''three'');' + #13#10 +
    'implementation' + #13#10 +
    '{$r *.res}' + #13#10 +
    'constructor TShape.Create(const AName: string; ACount: Integer);' + #13#10 +
    'var I: Integer; Total: Integer;' + #13#10 +
    '  procedure Add(N: Integer);' + #13#10 +
    '  begin' + #13#10 +
    '    Total:=Total+N;' + #13#10 +
    '  end;' + #13#10 +
    'begin' + #13#10 +
    '  FName:=AName; Total := 0;' + #13#10 +
    '  if ACount>Limit then FCount := Limit else FCount := ACount;' + #13#10 +
    '  for I := 0 to FCount-1 do begin Add(I); end;' + #13#10 +
    '  case FCount of' + #13#10 +
    '    0: FName := '''';' + #13#10 +
    '    1, 2: begin Add(-1); end;' + #13#10 +
    '  else Add($ff);' + #13#10 +
    '  end;' + #13#10 +
    '  try' + #13#10 +
    '    Writeln(FName:10, Total);' + #13#10 +
    '  except on E: Exception do raise;' + #13#10 +
    '  end;' + #13#10 +
    'end;' + #13#10 +
    'end.' + #13#10;

constructor TFormatterPreview.CreateFor(AOwner: TComponent; Dialog: TCustomForm);
begin
  FDialog := Dialog;
  inherited Create(AOwner);
end;

procedure TFormatterPreview.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  if (FDialog <> nil) and FDialog.HandleAllocated then Params.WndParent := FDialog.Handle;
end;

{ the editor fills the window (made in code: a control of D7 Studio's) }
procedure TFormatterPreview.FormCreate(Sender: TObject);
var
  W: TSciWindow;
begin
  UIPrepareForm(Self);
  W := TSciWindow.Create(Self);
  W.Parent := Self;
  W.Align := alClient;
  FEdit := W.Edit;
  FEdit.SetLanguageFromFile('Sample.pas');
  FEdit.ReadOnly := True;
end;

{ on the dialog's monitor: right of it when the work area has room, else left of it, else at the
  work area's right edge over the dialog's right part }
procedure TFormatterPreview.ShowBeside;
var
  D, R, A: TRect;
  Info: TMonitorInfo;
begin
  if not Visible and (FDialog <> nil) then
  begin
    GetWindowRect(FDialog.Handle, D);
    Info.cbSize := SizeOf(Info);
    if GetMonitorInfo(MonitorFromWindow(FDialog.Handle, MONITOR_DEFAULTTONEAREST), @Info) then A := Info.rcWork
    else A := D;
    R := Rect(D.Right, D.Top, D.Right + Width, D.Bottom);
    if R.Right > A.Right then
      if D.Left - Width >= A.Left then R := Rect(D.Left - Width, D.Top, D.Left, D.Bottom)
      else OffsetRect(R, A.Right - R.Right, 0);
    BoundsRect := R;
  end;
  Show;
end;

procedure TFormatterPreview.ShowValues(const V: TFmtValues);
var
  R: TFmtResult;
  Err, S, Old: string;
  First, N, Line, Lines: Integer;
begin
  if FormatPascal(SampleText, V, -1, -1, R, Err) then S := R.Output else S := SampleText;
  Old := FEdit.GetText;
  if S = Old then Exit;
  First := FEdit.Sci(SCI_GETFIRSTVISIBLELINE);
  FEdit.ReadOnly := False;
  FEdit.SetText(S);
  FEdit.Sci(SCI_EMPTYUNDOBUFFER);
  FEdit.ReadOnly := True;
  { what the change did is shown: the first line that differs comes into view }
  N := 1;
  while (N <= Length(S)) and (N <= Length(Old)) and (S[N] = Old[N]) do Inc(N);
  Line := FEdit.LineFromPos(N - 1);
  Lines := FEdit.Sci(SCI_LINESONSCREEN);
  if (Old <> '') and ((Line < First) or (Line >= First + Lines)) then First := Line - 2;
  if First < 0 then First := 0;
  FEdit.Sci(SCI_SETFIRSTVISIBLELINE, First);
end;

end.
