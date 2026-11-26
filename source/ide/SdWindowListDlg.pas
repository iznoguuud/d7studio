{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdWindowListDlg;

{ D7 Studio - Delphi 7's Window List, View | Window List: the
  open files; the one chosen (OK or a double click) becomes the active page. }

interface

uses
  Classes, Controls, Forms, StdCtrls, ExtCtrls, ActnList;

type
  TWindowListDlg = class(TForm)
    WindowListBox: TListBox;
    Actions: TActionList;
    aOK: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aOKExecute(Sender: TObject);
    procedure aOKUpdate(Sender: TObject);
    procedure ListDblClick(Sender: TObject);
  private
  public
    class function Execute(AOwner: TComponent; Items: TStrings; var Index: Integer): Boolean;
  end;

var
  WindowListDlg: TWindowListDlg;

implementation

uses
  SdUI, SdDialogs;

{$R *.dfm}

procedure TWindowListDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

procedure TWindowListDlg.ListDblClick(Sender: TObject);
begin
  aOK.Execute;
end;

procedure TWindowListDlg.aOKExecute(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TWindowListDlg.aOKUpdate(Sender: TObject);
begin
  aOK.Enabled := WindowListBox.ItemIndex >= 0;
end;

class function TWindowListDlg.Execute(AOwner: TComponent; Items: TStrings; var Index: Integer): Boolean;
var
  D: TWindowListDlg;
begin
  D := TWindowListDlg.Create(AOwner);
  Result := RunListDialog(D, D.WindowListBox, Items, Index);
end;

end.
