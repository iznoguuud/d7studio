{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdMacroPlayDlg;

{ D7 Studio - Play Macro Repeatedly (Edit | Macros, the Macro Library's Repeat): how many times the
  keystroke macro plays (1 .. MaxMacroTimes), or until the end of the file - until a play leaves the
  caret no nearer the end (SdOtaServices.OtaPlayMacroTimes). }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls;

const
  MaxMacroTimes = 9999;
  { the plays at most until the end of the file }
  MaxMacroPlays = 100000;

type
  TMacroPlayDlg = class(TForm)
    lblTimes: TLabel;
    edTimes: TEdit;
    udTimes: TUpDown;
    cbToEnd: TCheckBox;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure cbToEndClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FTimes: Integer;
  public
    class function Execute(AOwner: TComponent; var Times: Integer; var ToEnd: Boolean): Boolean;
  end;

var
  MacroPlayDlg: TMacroPlayDlg;

implementation

uses
  SdUI, SdDialogs;

{$R *.dfm}

procedure TMacroPlayDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  udTimes.Max := MaxMacroTimes;
end;

{ until the end of the file: the number does not count }
procedure TMacroPlayDlg.cbToEndClick(Sender: TObject);
begin
  edTimes.Enabled := not cbToEnd.Checked;
  udTimes.Enabled := edTimes.Enabled;
  lblTimes.Enabled := edTimes.Enabled;
end;

procedure TMacroPlayDlg.btnOKClick(Sender: TObject);
begin
  if cbToEnd.Checked or DialogValid(Self, CheckNumber(edTimes, 1, MaxMacroTimes,
    Format('The number of times must be between 1 and %d.', [MaxMacroTimes]), FTimes), edTimes) then
    ModalResult := mrOk;
end;

class function TMacroPlayDlg.Execute(AOwner: TComponent; var Times: Integer; var ToEnd: Boolean): Boolean;
var
  D: TMacroPlayDlg;
begin
  D := TMacroPlayDlg.Create(AOwner);
  try
    if (Times < 1) or (Times > MaxMacroTimes) then Times := 1;
    D.udTimes.Position := Times;
    D.FTimes := Times;
    D.cbToEnd.Checked := ToEnd;
    D.cbToEndClick(nil);
    Result := D.ShowModal = mrOk;
    if Result then
    begin
      Times := D.FTimes;
      ToEnd := D.cbToEnd.Checked;
    end;
  finally
    D.Free;
  end;
end;

end.
