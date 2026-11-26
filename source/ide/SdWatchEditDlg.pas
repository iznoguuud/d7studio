{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdWatchEditDlg;

{ D7 Studio - Delphi 7's Watch Properties:
  the Watch List's Add Watch and Edit Watch. The expression, the group the
  watch is in (a name that is no group yet makes one), repeat count, digits, Enabled, Allow
  Function Calls and the display format. OK takes the values as Delphi's does: an expression and a
  group name are needed, the repeat count is 0 - 255, the digits 0 - 18 (else its message, and the
  dialog stays with that box). Also the watch itself (TWatchItem) and its line in the project
  desktop, Delphi's format. }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls;

type
  { Delphi 7's display formats of a watch (ComTypes.TWatchFormat, in its order: the .dsk keeps the
    set as a number, 1 shl Ord - Default is 256); the dialog chooses one }
  TWatchFormat = (wfCharacter, wfDecimal, wfMemoryDump, wfPointer, wfRecord, wfString,
    wfHexadecimal, wfOrdinal, wfDefault, wfNoCalls, wfFloatingPoint);

  { a watch of the Watch List (Delphi's TWatchItem): its expression and the settings of Watch
    Properties; Address and Size are those of its value at the last stop (Break When Changed sets
    a data breakpoint there) }
  TWatchItem = class
  public
    Expr, Group: string;
    Format: TWatchFormat;
    RepeatCount, Digits: Integer;
    Enabled, AllowCalls: Boolean;
    Address, Size: Cardinal;
    constructor Create;
    procedure Assign(Src: TWatchItem);       // the settings (not Address and Size)
    { the watch as a value of the desktop's [Watches]: Delphi 7's
      'expression',format,repeat count,digits,enabled,allow calls,'group' }
    function DesktopText: string;
    { a value of [Watches] into the settings: Delphi's format, or an expression alone (what D7
      Studio wrote before); False for an empty one }
    function ReadDesktop(const S: string; const DefaultGroup: string): Boolean;
  end;

  TWatchEditDlg = class(TForm)
    xBevel1: TBevel;
    xLabel1: TLabel;
    xLabel2: TLabel;
    xLabel3: TLabel;
    xLabel4: TLabel;
    edExpression: TComboBox;
    rbCharacter: TRadioButton;
    rbString: TRadioButton;
    rbDecimal: TRadioButton;
    rbMemoryDump: TRadioButton;
    rbPointer: TRadioButton;
    rbHex: TRadioButton;
    rbFloatingPoint: TRadioButton;
    rbRecordStructureUnion: TRadioButton;
    rbDefault: TRadioButton;
    edRepeatCount: TEdit;
    edDigits: TEdit;
    cbEnabled: TCheckBox;
    cbAllowSideEffects: TCheckBox;
    edTabName: TComboBox;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
  private
    FRepeat, FDigits: Integer;     // the numbers OK took
    function Radio(F: TWatchFormat): TRadioButton;
    function Check(out Bad: TWinControl): string;
    procedure Take(W: TWatchItem);
  public
    { W holds the settings in and out }
    class function Execute(AOwner: TComponent; W: TWatchItem): Boolean;
  end;

var
  WatchEditDlg: TWatchEditDlg;

implementation

uses
  SdUI, SdSettings, SdDialogs;

{$R *.dfm}

{ ---------------------------------------------------------------- TWatchItem }

constructor TWatchItem.Create;
begin
  inherited Create;
  Format := wfDefault;
  Digits := 18;
  Enabled := True;
end;

procedure TWatchItem.Assign(Src: TWatchItem);
begin
  Expr := Src.Expr;
  Group := Src.Group;
  Format := Src.Format;
  RepeatCount := Src.RepeatCount;
  Digits := Src.Digits;
  Enabled := Src.Enabled;
  AllowCalls := Src.AllowCalls;
end;

function TWatchItem.DesktopText: string;
begin
  Result := SysUtils.Format('%s,%d,%d,%d,%d,%d,%s', [QuotedStr(Expr), 1 shl Ord(Format), RepeatCount, Digits,
    Ord(Enabled), Ord(AllowCalls), QuotedStr(Group)]);
end;

{ a quoted string at S[P] (Pascal's: '' is a quote), P after it; False when there is none }
function ReadQuoted(const S: string; var P: Integer; out Value: string): Boolean;
begin
  Result := False;
  Value := '';
  if (P > Length(S)) or (S[P] <> '''') then Exit;
  Inc(P);
  while P <= Length(S) do
  begin
    if S[P] = '''' then
    begin
      if (P < Length(S)) and (S[P + 1] = '''') then Inc(P)
      else
      begin
        Inc(P);
        Result := True;
        Exit;
      end;
    end;
    Value := Value + S[P];
    Inc(P);
  end;
end;

function TWatchItem.ReadDesktop(const S: string; const DefaultGroup: string): Boolean;
var
  P, I, Bits: Integer;
  E, Rest, G: string;
  F: TStringList;
begin
  Format := wfDefault;
  RepeatCount := 0;
  Digits := 18;
  Enabled := True;
  AllowCalls := False;
  Group := DefaultGroup;
  P := 1;
  if ReadQuoted(S, P, E) and (P <= Length(S)) and (S[P] = ',') then
  begin
    { Delphi 7's: the numbers, then the group (also quoted) }
    Rest := Copy(S, P + 1, MaxInt);
    F := TStringList.Create;
    try
      P := Pos(',''', Rest);
      if P > 0 then
      begin
        I := P + 1;
        if ReadQuoted(Rest, I, G) and (G <> '') then Group := G;
        Rest := Copy(Rest, 1, P - 1);
      end;
      F.CommaText := Rest;
      Expr := E;
      if F.Count > 0 then
      begin
        Bits := StrToIntDef(F[0], 1 shl Ord(wfDefault));
        for I := Ord(High(TWatchFormat)) downto Ord(Low(TWatchFormat)) do
          if (Bits shr I) and 1 <> 0 then Format := TWatchFormat(I);
        if Format in [wfOrdinal, wfNoCalls] then Format := wfDefault;
      end;
      if F.Count > 1 then RepeatCount := StrToIntDef(F[1], 0);
      if F.Count > 2 then Digits := StrToIntDef(F[2], 18);
      if F.Count > 3 then Enabled := F[3] <> '0';
      if F.Count > 4 then AllowCalls := F[4] = '1';
    finally
      F.Free;
    end;
  end
  else
    Expr := Trim(S);
  Result := Expr <> '';
end;

{ ---------------------------------------------------------------- TWatchEditDlg }

procedure TWatchEditDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

function TWatchEditDlg.Radio(F: TWatchFormat): TRadioButton;
begin
  case F of
    wfCharacter: Result := rbCharacter;
    wfString: Result := rbString;
    wfDecimal: Result := rbDecimal;
    wfHexadecimal: Result := rbHex;
    wfFloatingPoint: Result := rbFloatingPoint;
    wfPointer: Result := rbPointer;
    wfRecord: Result := rbRecordStructureUnion;
    wfMemoryDump: Result := rbMemoryDump;
  else
    Result := rbDefault;
  end;
end;

{ '' when the values are right, else Delphi's message and the box that is wrong }
function TWatchEditDlg.Check(out Bad: TWinControl): string;
begin
  Result := '';
  Bad := nil;
  if Trim(edExpression.Text) = '' then
  begin
    Result := 'No expression entered.';
    Bad := edExpression;
  end
  else if Trim(edTabName.Text) = '' then
  begin
    Result := 'No group name entered.';
    Bad := edTabName;
  end
  else
  begin
    Result := CheckNumber(edRepeatCount, 0, 255, 'Repeat count must be between 0 - 255.', FRepeat);
    if Result <> '' then Bad := edRepeatCount
    else
    begin
      Result := CheckNumber(edDigits, 0, 18, 'Digits must be between 0 - 18', FDigits);
      if Result <> '' then Bad := edDigits;
    end;
  end;
end;

procedure TWatchEditDlg.OKButtonClick(Sender: TObject);
var
  Err: string;
  Bad: TWinControl;
begin
  Err := Check(Bad);
  if DialogValid(Self, Err, Bad, 'Error') then ModalResult := mrOk;
end;

{ the values into W (after OK: they are right) }
procedure TWatchEditDlg.Take(W: TWatchItem);
var
  F: TWatchFormat;
begin
  W.Expr := Trim(edExpression.Text);
  W.Group := Trim(edTabName.Text);
  W.Format := wfDefault;
  for F := Low(TWatchFormat) to High(TWatchFormat) do
    if Radio(F).Checked and (Radio(F) <> rbDefault) then W.Format := F;
  W.RepeatCount := FRepeat;
  W.Digits := FDigits;
  W.Enabled := cbEnabled.Checked;
  W.AllowCalls := cbAllowSideEffects.Checked;
end;

class function TWatchEditDlg.Execute(AOwner: TComponent; W: TWatchItem): Boolean;
var
  D: TWatchEditDlg;
begin
  D := TWatchEditDlg.Create(AOwner);
  try
    LoadHistory(Settings, 'hlWatchExpression', D.edExpression.Items);
    LoadHistory(Settings, 'hlWatchGroup', D.edTabName.Items);
    D.edExpression.Text := W.Expr;
    D.edTabName.Text := W.Group;
    D.edRepeatCount.Text := IntToStr(W.RepeatCount);
    D.edDigits.Text := IntToStr(W.Digits);
    D.Radio(W.Format).Checked := True;
    D.cbEnabled.Checked := W.Enabled;
    D.cbAllowSideEffects.Checked := W.AllowCalls;
    Result := D.ShowModal = mrOk;
    if not Result then Exit;
    D.Take(W);
    AddHistory(Settings, 'hlWatchExpression', W.Expr);
    AddHistory(Settings, 'hlWatchGroup', W.Group);
  finally
    D.Free;
  end;
end;

end.
