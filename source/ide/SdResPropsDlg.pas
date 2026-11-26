{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdResPropsDlg;

{ D7 Studio - the Resources view's Properties of a resource: its type
  (data only: RCDATA, a standard type or a name of its own), its name - a number from 1 to 65535
  or a name - and its language. OK asks Check whether the values are right while the dialog is
  still open. }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls;

type
  { what is wrong with the values ('' nothing); Bad: the field to correct - 0 type, 1 name,
    2 language }
  TResPropsCheck = function(const AType, AName: string; Language: Integer; var Bad: Integer): string of object;

  TResPropsDlg = class(TForm)
    lblType: TLabel;
    lblName: TLabel;
    lblLanguage: TLabel;
    cbType: TComboBox;
    edName: TEdit;
    cbLanguage: TComboBox;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FCheck: TResPropsCheck;
    function Language: Integer;
  public
    { TypeEditable: a data resource's type may change; NameEditable: a string table has no name }
    class function Execute(AOwner: TComponent; const ACaption: string; TypeEditable, NameEditable: Boolean;
      var AType, AName: string; var ALanguage: Integer; Check: TResPropsCheck): Boolean;
  end;

var
  ResPropsDlg: TResPropsDlg;

implementation

uses
  SdUI, SdDialogs, SdResources;

{$R *.dfm}

procedure TResPropsDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

function TResPropsDlg.Language: Integer;
begin
  if cbLanguage.ItemIndex < 0 then Result := 0
  else Result := Integer(cbLanguage.Items.Objects[cbLanguage.ItemIndex]);
end;

procedure TResPropsDlg.btnOKClick(Sender: TObject);
var
  Msg: string;
  Bad: Integer;
  C: TWinControl;
begin
  Bad := 1;
  Msg := '';
  if Assigned(FCheck) then Msg := FCheck(Trim(cbType.Text), Trim(edName.Text), Language, Bad);
  case Bad of
    0: C := cbType;
    2: C := cbLanguage;
  else
    C := edName;
  end;
  if DialogValid(Self, Msg, C) then ModalResult := mrOk;
end;

class function TResPropsDlg.Execute(AOwner: TComponent; const ACaption: string;
  TypeEditable, NameEditable: Boolean; var AType, AName: string; var ALanguage: Integer;
  Check: TResPropsCheck): Boolean;
var
  D: TResPropsDlg;
  I: Integer;
begin
  D := TResPropsDlg.Create(AOwner);
  try
    D.Caption := ACaption;
    D.FCheck := Check;
    D.cbType.Text := AType;
    D.cbType.Enabled := TypeEditable;
    D.lblType.Enabled := TypeEditable;
    D.edName.Text := AName;
    D.edName.Enabled := NameEditable;
    D.lblName.Enabled := NameEditable;
    if NameEditable then D.ActiveControl := D.edName
    else if TypeEditable then D.ActiveControl := D.cbType
    else D.ActiveControl := D.cbLanguage;
    GetLanguages(D.cbLanguage.Items);
    D.cbLanguage.ItemIndex := 0;
    for I := 0 to D.cbLanguage.Items.Count - 1 do
      if Integer(D.cbLanguage.Items.Objects[I]) = ALanguage then D.cbLanguage.ItemIndex := I;
    if (D.cbLanguage.ItemIndex = 0) and (ALanguage <> 0) then
    begin
      { a language this system does not list }
      D.cbLanguage.Items.AddObject(LanguageText(ALanguage), TObject(ALanguage));
      D.cbLanguage.ItemIndex := D.cbLanguage.Items.Count - 1;
    end;
    Result := D.ShowModal = mrOk;
    if Result then
    begin
      AType := Trim(D.cbType.Text);
      AName := UpperCase(Trim(D.edName.Text));
      ALanguage := D.Language;
    end;
  finally
    D.Free;
  end;
end;

end.
