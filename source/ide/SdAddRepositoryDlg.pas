{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdAddRepositoryDlg;

{ D7 Studio - Delphi 7's Add To Repository:
  title, description, page, author and icon of a repository item - a form
  (chosen in the list of the project's forms), or with the list hidden a project (Project | Add to
  Repository, Delphi's TSaveProjectTemplate has these fields only) and an item of Tools |
  Repository (Edit Object). OK needs a title. }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ActnList;

type
  TRepoInfo = record
    Title, Description, Page, Author, Icon: string;
  end;

  TAddRepositoryDlg = class(TForm)
    xLabel1: TLabel;
    xLabel3: TLabel;
    Image: TImage;
    xLabel2: TLabel;
    xLabel5: TLabel;
    xLabel4: TLabel;
    xLabel6: TLabel;
    edTitle: TEdit;
    meDesc: TEdit;
    BrowseButton: TButton;
    FormList: TListBox;
    PageCombo: TComboBox;
    edAuthor: TEdit;
    Actions: TActionList;
    aBrowse: TAction;
    aOK: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aBrowseExecute(Sender: TObject);
    procedure aOKExecute(Sender: TObject);
    procedure aOKUpdate(Sender: TObject);
  private
    FIcon: string;
    procedure ShowIcon;
    procedure HideFormList;
  public
    { Forms: the project's forms, FormIndex the chosen one (nil: a project, or an item to edit -
      no list); Pages: the repository's pages }
    class function Execute(AOwner: TComponent; const ACaption: string; Forms, Pages: TStrings;
      var FormIndex: Integer; var Info: TRepoInfo): Boolean;
  end;

var
  AddRepositoryDlg: TAddRepositoryDlg;

implementation

uses
  SdUI, SdDialogs;

{$R *.dfm}

procedure TAddRepositoryDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ without the forms: what is right of the list moves to its place, the dialog narrower }
procedure TAddRepositoryDlg.HideFormList;
var
  I, DX: Integer;
  C: TControl;
begin
  DX := edTitle.Left - FormList.Left;
  FormList.Visible := False;
  xLabel5.Visible := False;
  for I := 0 to ControlCount - 1 do
  begin
    C := Controls[I];
    if (C <> OKButton) and (C <> CancelButton) and (C.Left >= edTitle.Left) then
      C.Left := C.Left - DX;
  end;
  ClientWidth := ClientWidth - DX;     // the band of the buttons follows the dialog's right edge
end;

procedure TAddRepositoryDlg.ShowIcon;
begin
  Image.Picture := nil;
  if (FIcon <> '') and FileExists(FIcon) then
    try
      Image.Picture.LoadFromFile(FIcon);
    except
      Image.Picture := nil;
    end;
end;

procedure TAddRepositoryDlg.aBrowseExecute(Sender: TObject);
begin
  if BrowseFile('Select Icon', 'Icons (*.ico)|*.ico|Any File (*.*)|*.*', FIcon) then ShowIcon;
end;

procedure TAddRepositoryDlg.aOKExecute(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TAddRepositoryDlg.aOKUpdate(Sender: TObject);
begin
  aOK.Enabled := (Trim(edTitle.Text) <> '') and (Trim(PageCombo.Text) <> '') and
    (not FormList.Visible or (FormList.ItemIndex >= 0));
end;

class function TAddRepositoryDlg.Execute(AOwner: TComponent; const ACaption: string; Forms, Pages: TStrings;
  var FormIndex: Integer; var Info: TRepoInfo): Boolean;
var
  D: TAddRepositoryDlg;
begin
  D := TAddRepositoryDlg.Create(AOwner);
  try
    if ACaption <> '' then D.Caption := ACaption;
    if Forms <> nil then
    begin
      D.FormList.Items.Assign(Forms);
      D.FormList.ItemIndex := FormIndex;
    end
    else
      D.HideFormList;
    D.PageCombo.Items.Assign(Pages);
    D.edTitle.Text := Info.Title;
    D.meDesc.Text := Info.Description;
    D.PageCombo.Text := Info.Page;
    D.edAuthor.Text := Info.Author;
    D.FIcon := Info.Icon;
    D.ShowIcon;
    D.ActiveControl := D.edTitle;
    Result := D.ShowModal = mrOk;
    if not Result then Exit;
    FormIndex := D.FormList.ItemIndex;
    Info.Title := Trim(D.edTitle.Text);
    Info.Description := Trim(D.meDesc.Text);
    Info.Page := Trim(D.PageCombo.Text);
    Info.Author := Trim(D.edAuthor.Text);
    Info.Icon := D.FIcon;
  finally
    D.Free;
  end;
end;

end.
