{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdExceptRangeDlg;

{ D7 Studio - Debugger Options | OS Exceptions | Add: Delphi 7's Add Exception Range:
  the lowest and highest exception code, hexadecimal }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls;

type
  TExceptRangeDlg = class(TForm)
    xPanel1: TPanel;
    LowLabel: TLabel;
    HighLabel: TLabel;
    LowEdit: TEdit;
    HighEdit: TEdit;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
  private
    FLow, FHigh: Cardinal;
    function CodeValid(E: TEdit; L: TLabel; var Code: Cardinal): Boolean;
  public
    class function Execute(AOwner: TComponent; var Low, High: Cardinal): Boolean;
  end;

{ "C0000005", "$C0000005", "0xC0000005" }
function ParseExceptionCode(const S: string; var Code: Cardinal): Boolean;

implementation

{$R *.dfm}

uses
  Menus, SdUI, SdDialogs;

function ParseExceptionCode(const S: string; var Code: Cardinal): Boolean;
var
  T: string;
  V: Int64;
  E: Integer;
begin
  T := Trim(S);
  if (Copy(T, 1, 2) = '0x') or (Copy(T, 1, 2) = '0X') then Delete(T, 1, 2)
  else if Copy(T, 1, 1) = '$' then Delete(T, 1, 1);
  Val('$' + T, V, E);
  Result := (T <> '') and (E = 0) and (V >= 0) and (V <= $FFFFFFFF);
  if Result then Code := Cardinal(V);
end;

class function TExceptRangeDlg.Execute(AOwner: TComponent; var Low, High: Cardinal): Boolean;
var
  D: TExceptRangeDlg;
begin
  D := TExceptRangeDlg.Create(AOwner);
  try
    Result := D.ShowModal = mrOK;
    if Result then
    begin
      Low := D.FLow;
      High := D.FHigh;
    end;
  finally
    D.Free;
  end;
end;

procedure TExceptRangeDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ the code in E, else Delphi's message (Verify.VerifyLongWordInEdit: the label's name) }
function TExceptRangeDlg.CodeValid(E: TEdit; L: TLabel; var Code: Cardinal): Boolean;
var
  N: string;
begin
  N := StripHotkey(L.Caption);
  if Copy(N, Length(N), 1) = ':' then SetLength(N, Length(N) - 1);
  Result := DialogValid(Self, ParseExceptionCode(E.Text, Code),
    Format('%s must be an integer between $0 and $FFFFFFFF', [N]), E, 'Error');
end;

{ Delphi's FormCloseQuery: both codes, the high one not below the low one (an empty high code is
  the low one) }
procedure TExceptRangeDlg.OKButtonClick(Sender: TObject);
begin
  if not CodeValid(LowEdit, LowLabel, FLow) then Exit;
  FHigh := FLow;
  if (Trim(HighEdit.Text) <> '') and not CodeValid(HighEdit, HighLabel, FHigh) then Exit;
  if DialogValid(Self, FHigh >= FLow, 'Range High must be greater than or equal to Range Low', HighEdit, 'Error') then
    ModalResult := mrOk;
end;

end.
