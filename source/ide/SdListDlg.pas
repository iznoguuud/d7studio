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
  of a package. The filter box above the list keeps the rows that hold its text (or match its
  mask with * and ?), those that start with it first; the arrow keys move in the list while it
  has the focus. OK (or a double click on a row) takes the row chosen. }

interface

uses
  Classes, Controls, Forms, StdCtrls, ExtCtrls, ActnList;

type
  TListDlg = class(TForm)
    edFilter: TEdit;
    lbItems: TListBox;
    Actions: TActionList;
    aOK: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure edFilterChange(Sender: TObject);
    procedure edFilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure lbItemsDblClick(Sender: TObject);
    procedure aOKExecute(Sender: TObject);
    procedure aOKUpdate(Sender: TObject);
  private
    FAll: TStringList;          // every row; objects: the row's index in the caller's list
    procedure Refill(Chosen: Integer);
  public
    destructor Destroy; override;
    class function Execute(AOwner: TComponent; const ACaption: string; Items: TStrings;
      var Index: Integer): Boolean;
  end;

var
  ListDlg: TListDlg;

implementation

uses
  SdUI, SdCompBar;

{$R *.dfm}

procedure TListDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  if UILayoutPass then Exit;
  FAll := TStringList.Create;
  UICueBanner(edFilter, UIFilterCue, True);
end;

destructor TListDlg.Destroy;
begin
  FAll.Free;
  inherited;
end;

{ the rows the filter keeps, those that start with its text before those that hold it further
  on, each in the caller's order; Chosen (an index of the caller's list) is selected when it is
  shown, else the first row }
procedure TListDlg.Refill(Chosen: Integer);
var
  Sel: Integer;
begin
  FillFiltered(edFilter.Text, FAll, lbItems.Items);
  Sel := lbItems.Items.IndexOfObject(TObject(Chosen));
  if (Sel < 0) and (lbItems.Items.Count > 0) then Sel := 0;
  lbItems.ItemIndex := Sel;
end;

procedure TListDlg.edFilterChange(Sender: TObject);
begin
  Refill(-1);
end;

procedure TListDlg.edFilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  ForwardListKey(lbItems, Key);
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
  I: Integer;
begin
  D := TListDlg.Create(AOwner);
  try
    D.Caption := ACaption;
    for I := 0 to Items.Count - 1 do D.FAll.AddObject(Items[I], TObject(I));
    if (Index < 0) or (Index >= Items.Count) then I := 0 else I := Index;
    D.Refill(I);
    Result := (D.ShowModal = mrOk) and (D.lbItems.ItemIndex >= 0);
    if Result then Index := Integer(D.lbItems.Items.Objects[D.lbItems.ItemIndex]);
  finally
    D.Free;
  end;
end;

end.
