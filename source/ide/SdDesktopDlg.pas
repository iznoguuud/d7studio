{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDesktopDlg;

{ D7 Studio - Delphi 7's desktop dialogs on one form: Save Desktop (a name,
  typed or chosen) and Select debug desktop (one of the saved desktops or <None>). }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ActnList;

type
  TDesktopDlg = class(TForm)
    xLabel1: TLabel;
    cbDesktopName: TComboBox;
    Actions: TActionList;
    aOK: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aOKExecute(Sender: TObject);
    procedure aOKUpdate(Sender: TObject);
  public
    { Debug: Select debug desktop (a list with <None> = ''), else Save Desktop }
    class function Execute(AOwner: TComponent; Debug: Boolean; Names: TStrings; var Name: string): Boolean;
  end;

var
  DesktopDlg: TDesktopDlg;

implementation

uses
  SdUI, SdDialogs;

{$R *.dfm}

procedure TDesktopDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

procedure TDesktopDlg.aOKExecute(Sender: TObject);
begin
  ModalResult := mrOk;
end;

{ OK needs a name (Delphi enables it the same way) }
procedure TDesktopDlg.aOKUpdate(Sender: TObject);
begin
  aOK.Enabled := Trim(cbDesktopName.Text) <> '';
end;

class function TDesktopDlg.Execute(AOwner: TComponent; Debug: Boolean; Names: TStrings; var Name: string): Boolean;
var
  D: TDesktopDlg;
begin
  D := TDesktopDlg.Create(AOwner);
  try
    D.cbDesktopName.Items.Assign(Names);
    if Debug then
    begin
      D.Caption := 'Select debug desktop';
      D.xLabel1.Caption := '&Debug desktop:';
      D.cbDesktopName.Style := csDropDownList;
      D.cbDesktopName.Items.Insert(0, NoDesktopName);
      D.cbDesktopName.ItemIndex := D.cbDesktopName.Items.IndexOf(Name);
      if D.cbDesktopName.ItemIndex < 0 then D.cbDesktopName.ItemIndex := 0;
    end
    else
      D.cbDesktopName.Text := Name;
    D.xLabel1.FocusControl := D.cbDesktopName;
    D.aOK.Update;                 // the state of OK from the first frame on
    Result := D.ShowModal = mrOk;
    if Result then
    begin
      Name := Trim(D.cbDesktopName.Text);
      if Debug and (Name = NoDesktopName) then Name := '';
      Result := Debug or (Name <> '');
    end;
  finally
    D.Free;
  end;
end;

end.
