{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdTabOrderDlg;

{ D7 Studio - Delphi 7's Edit Tab Order dialog, Edit | Tab Order:
  the controls of one parent in tab order ("Name: Class"), moved with the arrow buttons. Delphi's
  Creation Order (Edit | Creation Order: the non-visual components) is the same
  form with another caption and label. }

interface

uses
  Classes, Controls, Forms, StdCtrls, ExtCtrls,
  Buttons, ActnList;

type
  TTabOrderDlg = class(TForm)
    xLabel1: TLabel;
    TabList: TListBox;
    UpButton: TBitBtn;
    DownButton: TBitBtn;
    Actions: TActionList;
    aUp: TAction;
    aDown: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aMoveExecute(Sender: TObject);
    procedure aMoveUpdate(Sender: TObject);
  public
    { Items: the controls in their tab order (objects kept); reordered when True }
    class function Execute(AOwner: TComponent; Items: TStrings; CreationOrder: Boolean = False): Boolean;
  end;

var
  TabOrderDlg: TTabOrderDlg;

implementation

uses
  SdUI, SdDialogs, SdIcons;

{$R *.dfm}

procedure TTabOrderDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  if UILayoutPass then Exit;
  IconButton(UpButton, iiMoveUp);
  IconButton(DownButton, iiMoveDown);
end;

procedure TTabOrderDlg.aMoveExecute(Sender: TObject);
begin
  MoveListRow(TabList, Sender = aUp);
end;

procedure TTabOrderDlg.aMoveUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := CanMoveListRow(TabList, Sender = aUp);
end;

class function TTabOrderDlg.Execute(AOwner: TComponent; Items: TStrings; CreationOrder: Boolean): Boolean;
var
  D: TTabOrderDlg;
begin
  D := TTabOrderDlg.Create(AOwner);
  try
    if CreationOrder then
    begin
      D.Caption := 'Creation Order';
      D.xLabel1.Caption := '&Creation order of non-visual components:';
    end;
    D.TabList.Items.Assign(Items);
    if D.TabList.Items.Count > 0 then D.TabList.ItemIndex := 0;
    Result := D.ShowModal = mrOk;
    if Result then Items.Assign(D.TabList.Items);
  finally
    D.Free;
  end;
end;

end.
