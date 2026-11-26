{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdAddCodeTemplateDlg;

{ D7 Studio - Add / Edit Code Template: Delphi 7's dialog
  with a template's shortcut name and description }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls;

type
  TAddCodeTemplateDlg = class(TForm)
    xLabel1: TLabel;
    xLabel2: TLabel;
    ShortName: TEdit;
    Desc: TEdit;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKBtn: TButton;
    CancelBtn: TButton;
    procedure FormCreate(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
  public
    class function Execute(AOwner: TComponent; const ACaption: string; var AName, ADesc: string): Boolean;
  end;

implementation

{$R *.dfm}

uses
  SdUI, SdDialogs;

class function TAddCodeTemplateDlg.Execute(AOwner: TComponent; const ACaption: string;
  var AName, ADesc: string): Boolean;
var
  D: TAddCodeTemplateDlg;
begin
  D := TAddCodeTemplateDlg.Create(AOwner);
  try
    D.Caption := ACaption;
    D.ShortName.Text := AName;
    D.Desc.Text := ADesc;
    Result := D.ShowModal = mrOK;
    if Result then
    begin
      AName := Trim(D.ShortName.Text);
      ADesc := Trim(D.Desc.Text);
    end;
  finally
    D.Free;
  end;
end;

procedure TAddCodeTemplateDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ a template needs a shortcut name without blanks (Ctrl+J looks it up by the word at the caret) }
procedure TAddCodeTemplateDlg.OKBtnClick(Sender: TObject);
var
  N: string;
begin
  N := Trim(ShortName.Text);
  if DialogValid(Self, (N <> '') and (Pos(' ', N) = 0), 'A code template needs a shortcut name without blanks.',
    ShortName) then ModalResult := mrOk;
end;

end.
