{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdTodoFilterDlg;

{ D7 Studio - the To-Do List's Filter | Categories..., Owners..., Item Types...: Delphi 7's
  Filter To-Do List. The
  values the items have, sorted, checked while their items are shown; Show All checks them all.
  Delphi's Add... is never shown (its UpdateButtons hides it): it is left out. }

interface

uses
  Classes, Controls, Forms, StdCtrls, ExtCtrls, CheckLst,
  ActnList;

type
  TTodoFilterDlg = class(TForm)
    xLabel1: TLabel;
    CheckList: TCheckListBox;
    Actions: TActionList;
    aShowAll: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnShowAll: TButton;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aShowAllExecute(Sender: TObject);
    procedure aShowAllUpdate(Sender: TObject);
  public
    { Values with Shown (one Boolean per value); Hidden gets the unchecked values }
    class function Execute(AOwner: TComponent; const Prompt: string; Values: TStrings; Shown: TList;
      Hidden: TStrings): Boolean;
  end;

implementation

{$R *.dfm}

uses
  SdUI;

procedure TTodoFilterDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

procedure TTodoFilterDlg.aShowAllExecute(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to CheckList.Items.Count - 1 do CheckList.Checked[I] := True;
end;

procedure TTodoFilterDlg.aShowAllUpdate(Sender: TObject);
begin
  aShowAll.Enabled := CheckList.Items.Count > 0;
end;

class function TTodoFilterDlg.Execute(AOwner: TComponent; const Prompt: string; Values: TStrings;
  Shown: TList; Hidden: TStrings): Boolean;
var
  D: TTodoFilterDlg;
  I, K: Integer;
begin
  D := TTodoFilterDlg.Create(AOwner);
  try
    D.xLabel1.Caption := Prompt;
    D.CheckList.Items.BeginUpdate;
    try
      for I := 0 to Values.Count - 1 do
      begin
        K := D.CheckList.Items.Add(Values[I]);     // sorted, as Delphi's
        D.CheckList.Checked[K] := Shown[I] <> nil;
      end;
    finally
      D.CheckList.Items.EndUpdate;
    end;
    D.ActiveControl := D.CheckList;
    Result := D.ShowModal = mrOK;
    if Result then
    begin
      Hidden.Clear;
      for I := 0 to D.CheckList.Items.Count - 1 do
        if not D.CheckList.Checked[I] then Hidden.Add(D.CheckList.Items[I]);
    end;
  finally
    D.Free;
  end;
end;

end.
