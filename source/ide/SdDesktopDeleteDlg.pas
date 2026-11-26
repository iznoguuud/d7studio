{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDesktopDeleteDlg;

{ D7 Studio - Delphi 7's Delete Saved Desktop, View |
  Desktops | Delete: the saved desktops, several may be selected; Delete removes the selected
  ones. Its command is an action (Delete enabled while one is selected; the .dfm's button was
  disabled for good, and the list was not the unit's - xListBox1 - which crashed it). }

interface

uses
  Classes, Controls, Forms, StdCtrls, ExtCtrls, ActnList;

type
  TDesktopDeleteDlg = class(TForm)
    xListBox1: TListBox;
    Actions: TActionList;
    aDelete: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnDelete: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aDeleteExecute(Sender: TObject);
    procedure aDeleteUpdate(Sender: TObject);
  public
    { Selected: the desktops chosen for deletion }
    class function Execute(AOwner: TComponent; Names, Selected: TStrings): Boolean;
  end;

var
  DesktopDeleteDlg: TDesktopDeleteDlg;

implementation

uses
  SdUI;

{$R *.dfm}

procedure TDesktopDeleteDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

procedure TDesktopDeleteDlg.aDeleteExecute(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TDesktopDeleteDlg.aDeleteUpdate(Sender: TObject);
begin
  aDelete.Enabled := xListBox1.SelCount > 0;
end;

class function TDesktopDeleteDlg.Execute(AOwner: TComponent; Names, Selected: TStrings): Boolean;
var
  D: TDesktopDeleteDlg;
  I: Integer;
begin
  Selected.Clear;
  D := TDesktopDeleteDlg.Create(AOwner);
  try
    D.xListBox1.Items.Assign(Names);
    if Names.Count > 0 then D.xListBox1.Selected[0] := True;
    D.aDelete.Update;                 // the state of Delete from the first frame on
    if D.ShowModal = mrOk then
      for I := 0 to D.xListBox1.Items.Count - 1 do
        if D.xListBox1.Selected[I] then Selected.Add(D.xListBox1.Items[I]);
    Result := Selected.Count > 0;
  finally
    D.Free;
  end;
end;

end.
