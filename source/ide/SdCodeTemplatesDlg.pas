{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCodeTemplatesDlg;

{ D7 Studio - Editor Options | Source Options | Edit Code Templates: Delphi 7's Code Templates
  dialog: the templates with their shortcut
  names and descriptions, the code of the one chosen in an editor ("|" where the caret goes), Add,
  Edit, Delete, Import and Export of .dci files. The templates: SdCodeTemplates. }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls,
  ActnList, SdCodeTemplates, SdSciEdit;

type
  TCodeTemplatesDlg = class(TForm)
    xLabel1: TLabel;
    CodeLabel: TLabel;
    TemplateBevel: TBevel;
    CodeList: TListView;
    AddTemplateBtn: TButton;
    EditTemplateBtn: TButton;
    DeleteTemplateBtn: TButton;
    btnImport: TButton;
    btnExport: TButton;
    Actions: TActionList;
    aAdd: TAction;
    aEdit: TAction;
    aDelete: TAction;
    aImport: TAction;
    aExport: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOk: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aAddExecute(Sender: TObject);
    procedure aEditExecute(Sender: TObject);
    procedure aDeleteExecute(Sender: TObject);
    procedure SelectedUpdate(Sender: TObject);
    procedure aImportExecute(Sender: TObject);
    procedure aExportExecute(Sender: TObject);
    procedure aExportUpdate(Sender: TObject);
    procedure ListSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
  private
    FList: TCodeTemplates;
    FCode: TSciEdit;
    FShown: Integer;                 // the template whose code the editor shows
    procedure FillList(Select: Integer);
    procedure KeepCode;
  public
    class function Execute(AOwner: TComponent): Boolean;
  end;

implementation

{$R *.dfm}

uses
  SdUI, SdFileNames, SdDialogs;

const
  PascalType = 'Borland.EditOptions.Pascal';
  DciFilter = 'Code templates (*.dci)|*.dci|All files (*.*)|*.*';

class function TCodeTemplatesDlg.Execute(AOwner: TComponent): Boolean;
var
  D: TCodeTemplatesDlg;
begin
  D := TCodeTemplatesDlg.Create(AOwner);
  try
    Result := D.ShowModal = mrOK;
    if Result then
    begin
      D.KeepCode;
      CodeTemplates := D.FList;
      SaveCodeTemplates;
    end;
  finally
    D.Free;
  end;
end;

procedure TCodeTemplatesDlg.FormCreate(Sender: TObject);
var
  W: TSciWindow;
begin
  UIPrepareForm(Self);
  if UILayoutPass then Exit;
  FList := Copy(CodeTemplates, 0, Length(CodeTemplates));
  FShown := -1;
  { the columns share the list's width: a third for the name }
  CodeList.Columns[0].Width := CodeList.ClientWidth div 3;
  CodeList.Columns[1].Width := CodeList.ClientWidth - CodeList.ClientWidth div 3 - 4;
  { the code: an editor where Delphi's bevel lies }
  W := TSciWindow.Create(Self);
  W.Parent := TemplateBevel.Parent;
  W.BoundsRect := TemplateBevel.BoundsRect;
  W.Anchors := TemplateBevel.Anchors;
  CodeLabel.FocusControl := W;
  FCode := W.Edit;
  FCode.SetLanguageFromFile('Template.pas');
  FillList(0);
end;

procedure TCodeTemplatesDlg.FillList(Select: Integer);
var
  I: Integer;
  It: TListItem;
begin
  KeepCode;
  FShown := -1;
  CodeList.Items.BeginUpdate;
  try
    CodeList.Items.Clear;
    for I := 0 to High(FList) do
    begin
      It := CodeList.Items.Add;
      It.Caption := FList[I].Name;
      It.SubItems.Add(FList[I].Description);
    end;
  finally
    CodeList.Items.EndUpdate;
  end;
  if (Select >= 0) and (Select < CodeList.Items.Count) then
  begin
    CodeList.Items[Select].Selected := True;
    CodeList.Items[Select].MakeVisible(False);
  end
  else
    FCode.SetText('');
end;

procedure TCodeTemplatesDlg.KeepCode;
begin
  if (FShown >= 0) and (FShown <= High(FList)) then FList[FShown].Code := FCode.GetText;
end;

procedure TCodeTemplatesDlg.ListSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if not Selected then Exit;
  KeepCode;
  FShown := Item.Index;
  FCode.SetText(FList[FShown].Code);
end;

procedure TCodeTemplatesDlg.aAddExecute(Sender: TObject);
var
  Name, Desc: string;
  N: Integer;
begin
  Name := '';
  Desc := '';
  if not AddCodeTemplateDialog(Self, 'Add Code Template', Name, Desc) then Exit;
  KeepCode;
  N := Length(FList);
  SetLength(FList, N + 1);
  FList[N].Name := Name;
  FList[N].Description := Desc;
  FList[N].FileTypeID := PascalType;
  FList[N].Code := '';
  FillList(N);
  if FCode.CanFocus then FCode.SetFocus;
end;

procedure TCodeTemplatesDlg.aEditExecute(Sender: TObject);
var
  I: Integer;
  Name, Desc: string;
begin
  if CodeList.Selected = nil then Exit;
  I := CodeList.Selected.Index;
  Name := FList[I].Name;
  Desc := FList[I].Description;
  if not AddCodeTemplateDialog(Self, 'Edit Code Template', Name, Desc) then Exit;
  KeepCode;
  FList[I].Name := Name;
  FList[I].Description := Desc;
  FillList(I);
end;

procedure TCodeTemplatesDlg.aDeleteExecute(Sender: TObject);
var
  I, K: Integer;
begin
  if CodeList.Selected = nil then Exit;
  I := CodeList.Selected.Index;
  FShown := -1;
  for K := I to High(FList) - 1 do FList[K] := FList[K + 1];
  SetLength(FList, Length(FList) - 1);
  FillList(RowAfterDelete(I, Length(FList)));
end;

procedure TCodeTemplatesDlg.SelectedUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := CodeList.Selected <> nil;
end;

{ Import: the templates of a .dci file join the list (a name it has already is replaced) }
procedure TCodeTemplatesDlg.aImportExecute(Sender: TObject);
var
  F: string;
  T: TCodeTemplates;
  I, K: Integer;
  Found: Boolean;
begin
  F := '';
  if not BrowseFile('Open code template file', DciFilter, F, bfOpen, 'dci') then Exit;
  T := ParseCodeTemplates(ReadFileU(F));
  KeepCode;
  FShown := -1;                          // kept: FillList must not take the editor's text again
  for I := 0 to High(T) do
  begin
    Found := False;
    for K := 0 to High(FList) do
      if SameText(FList[K].Name, T[I].Name) and SameText(FList[K].FileTypeID, T[I].FileTypeID) then
      begin
        FList[K] := T[I];
        Found := True;
      end;
    if not Found then
    begin
      SetLength(FList, Length(FList) + 1);
      FList[High(FList)] := T[I];
    end;
  end;
  FillList(0);
end;

procedure TCodeTemplatesDlg.aExportExecute(Sender: TObject);
var
  F: string;
begin
  KeepCode;
  F := '';
  if BrowseFile('Export templates as...', DciFilter, F, bfSave, 'dci') then WriteFileU(F, CodeTemplatesText(FList));
end;

procedure TCodeTemplatesDlg.aExportUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := Length(FList) > 0;
end;

end.
