{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdListDlg;

{ D7 Studio - a list to choose from: View Unit, View Form, Remove From Project, the components
  of a package. OK (or a double click on a row) takes the row chosen. }

interface

uses
  Classes, Controls, Forms, StdCtrls, ExtCtrls, ActnList;

type
  TListDlg = class(TForm)
    lbItems: TListBox;
    Actions: TActionList;
    aOK: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure lbItemsDblClick(Sender: TObject);
    procedure aOKExecute(Sender: TObject);
    procedure aOKUpdate(Sender: TObject);
  public
    class function Execute(AOwner: TComponent; const ACaption: string; Items: TStrings;
      var Index: Integer): Boolean;
  end;

var
  ListDlg: TListDlg;

implementation

uses
  SdUI, SdDialogs;

{$R *.dfm}

procedure TListDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

procedure TListDlg.lbItemsDblClick(Sender: TObject);
begin
  aOK.Execute;
end;

procedure TListDlg.aOKExecute(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TListDlg.aOKUpdate(Sender: TObject);
begin
  aOK.Enabled := lbItems.ItemIndex >= 0;
end;

class function TListDlg.Execute(AOwner: TComponent; const ACaption: string; Items: TStrings;
  var Index: Integer): Boolean;
var
  D: TListDlg;
begin
  D := TListDlg.Create(AOwner);
  D.Caption := ACaption;
  Result := RunListDialog(D, D.lbItems, Items, Index);
end;

end.
