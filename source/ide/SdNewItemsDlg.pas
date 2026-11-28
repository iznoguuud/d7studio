{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdNewItemsDlg;

{ D7 Studio - Delphi 7's New Items, File | New | Other: the
  page New with the wizards and the pages of Delphi's Object Repository (Delphi32.dro: forms,
  dialogs, projects, data modules); and the
  page of the open project with its forms; Copy / Inherit / Use for a form of the repository,
  Inherit for a form of the project (visual form inheritance). The main window does what the
  item stands for. }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  ComCtrls, ActnList, ToolsAPI, SdIcons;

type
  TNewItemKind = (nkApplication, nkBatchFile, nkComponent, nkConsole, nkDataModule, nkDll, nkForm,
    nkFrame, nkPackage, nkText, nkThread, nkUnit, nkFormTemplate, nkProjectTemplate, nkProjectForm,
    nkWizard);
  { a form of the repository is copied into the project, inherited from, or used as it is }
  TNewItemMode = (nmCopy, nmInherit, nmUse);

  TNewItem = class
  public
    Kind: TNewItemKind;
    Name, Page, Description: string;
    Path: string;               // a template of the repository, a form of the project: its file without extension
    FormClass: string;          // a form of the project: its class
    { the icon: Glyph, else IconFile (a repository item's own, outside Delphi's folder), else Icon
      (SdIcons.LargeIcons) }
    Icon: TSdIcon;
    IconFile: string;
    { a repository wizard of an expert (IOTARepositoryWizard): it runs; its icon (GetGlyph) }
    Wizard: IOTAWizard;
    Glyph: HICON;
  end;

  TNewItemsDlg = class(TForm)
    TabControl: TTabControl;
    xPanel1: TPanel;
    RReference: TRadioButton;
    RInherit: TRadioButton;
    RCopy: TRadioButton;
    ItemList: TListView;
    Actions: TActionList;
    aOK: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure TabControlChange(Sender: TObject);
    procedure aOKExecute(Sender: TObject);
    procedure aOKUpdate(Sender: TObject);
    procedure ItemDblClick(Sender: TObject);
    procedure ItemSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
  private
    FItems: TList;
    FIcons: TImageList;
    procedure ShowPage;
  public
    destructor Destroy; override;
    { ProjectName, ProjectForms ('Name|Class|unit file without extension'): the open project's page
      ('' none); Mode: what to do with a form }
    class function Execute(AOwner: TComponent; const ProjectName: string; ProjectForms: TStrings;
      var Item: TNewItem; var Mode: TNewItemMode): Boolean;
  end;

var
  NewItemsDlg: TNewItemsDlg;

implementation

uses
  CommCtrl, SdUI, SdDelphiDir, SdFileNames, SdRepository, SdOtaServices, SdOtaLegacy;

{$R *.dfm}

const
  NewPage = 'New';
  WizardsPage = 'Wizards';
  NewItems: array[0..11] of record N: string; K: TNewItemKind; I: TSdIcon end = (
    (N: 'Application'; K: nkApplication; I: iiProject),
    (N: 'Batch File'; K: nkBatchFile; I: iiBatchFile),
    (N: 'Component'; K: nkComponent; I: iiNonVisual),
    (N: 'Console Application'; K: nkConsole; I: iiConsole),
    (N: 'Data Module'; K: nkDataModule; I: iiDataModule),
    (N: 'DLL Wizard'; K: nkDll; I: iiLibrary),
    (N: 'Form'; K: nkForm; I: iiForm),
    (N: 'Frame'; K: nkFrame; I: iiFrameTool),
    (N: 'Package'; K: nkPackage; I: iiPmPackage),
    (N: 'Text'; K: nkText; I: iiTextFile),
    (N: 'Thread Object'; K: nkThread; I: iiThread),
    (N: 'Unit'; K: nkUnit; I: iiUnit));

  { the wizards of Delphi 7's own packages, by name: D7 Studio's icon in place of the package's glyph
    (any other: iiWizard) }
  DelphiWizards: array[0..3] of record N: string; I: TSdIcon end = (
    (N: 'Service'; I: iiService),
    (N: 'Service Application'; I: iiServiceApp),
    (N: 'Web Server Application'; I: iiWebServerApp),
    (N: 'XML Data Binding'; I: iiXmlBinding));

{ the icon for a wizard of one of Delphi 7's own packages (its code in a package of Delphi's Bin - a
  Delphi 1-3 expert's that D7 Studio wraps too); False for any other wizard, which keeps its glyph }
function DelphiWizardIcon(const W: IOTARepositoryWizard; const Name: string; var Icon: TSdIcon): Boolean;
var
  M: HMODULE;
  I: Integer;
begin
  Result := False;
  M := WizardModule(W);
  if (M = MainInstance) or not IsDelphiBinModule(M) then Exit;
  Result := True;
  Icon := iiWizard;
  for I := Low(DelphiWizards) to High(DelphiWizards) do
    if SameText(Name, DelphiWizards[I].N) then Icon := DelphiWizards[I].I;
end;

{ the items: New, then the pages of the repository (owned by the list) }
procedure LoadNewItems(Items: TList);
var
  I, J, AtNew: Integer;
  It: TNewItem;
  Repo: TRepository;
  R: TRepoItem;
  Pages: TStrings;
  Wizards: TInterfaceList;
  W: IOTARepositoryWizard;
begin
  for I := Low(NewItems) to High(NewItems) do
  begin
    It := TNewItem.Create;
    It.Kind := NewItems[I].K;
    It.Name := NewItems[I].N;
    It.Page := NewPage;
    It.Icon := NewItems[I].I;
    Items.Add(It);
  end;
  Repo := TRepository.Create;
  try
    Repo.Load;
    Pages := Repo.Pages;
    for I := 0 to Repo.Count - 1 do
    begin
      R := Repo[I];
      if not (R.IsForm or R.IsProject) then Continue;
      { an inherited template of Delphi's: the template it inherits from is not followed }
      if R.Values['Ancestor'] <> '' then Continue;
      It := TNewItem.Create;
      if R.IsForm then
      begin
        It.Kind := nkFormTemplate;
        It.Icon := iiForm;
      end
      else
      begin
        It.Kind := nkProjectTemplate;
        It.Icon := iiProject;
      end;
      It.Path := R.Path;
      It.Name := R.Values['Name'];
      if It.Name = '' then It.Name := ExtractFileName(R.Path);
      It.Page := R.Values['Page'];
      if It.Page = '' then It.Page := 'Forms';
      It.Description := R.Values['Description'];
      { an icon file of Delphi's folder is Delphi's own: the item gets D7 Studio's }
      It.IconFile := ExpandDelphiMacros(R.Values['Icon']);
      if (It.IconFile <> '') and PathIsUnder(ExpandFileName(It.IconFile), DelphiRoot) then It.IconFile := '';
      if Pages.IndexOf(It.Page) < 0 then Pages.Add(It.Page);
      Items.Add(It);
    end;
    { the experts' repository wizards (Delphi 1-3's form and project experts among them): on
      their page - none: Wizards, as in Delphi 7; New: after Delphi's items there -, without an
      icon of their own the form's; those of Delphi 7's own packages with D7 Studio's icons }
    AtNew := High(NewItems) + 1;
    Wizards := TInterfaceList.Create;
    try
      OtaRepositoryWizards(Wizards);
      for I := 0 to Wizards.Count - 1 do
      begin
        W := IOTARepositoryWizard(Wizards[I]);
        It := TNewItem.Create;
        It.Kind := nkWizard;
        It.Wizard := W;
        try
          It.Name := W.GetName;
          It.Page := W.GetPage;
          It.Description := W.GetComment;
          It.Glyph := W.GetGlyph;
        except
        end;
        if DelphiWizardIcon(W, It.Name, It.Icon) then It.Glyph := 0
        else It.Icon := iiForm;
        if It.Page = '' then It.Page := WizardsPage;
        if SameText(It.Page, NewPage) then
        begin
          It.Page := NewPage;
          Items.Insert(AtNew, It);
          Inc(AtNew);
          Continue;
        end;
        if Pages.IndexOf(It.Page) < 0 then Pages.Add(It.Page);
        Items.Add(It);
      end;
    finally
      Wizards.Free;
    end;
    { the pages in the order of [Repository Pages], after New (a stable insertion sort) }
    for I := AtNew + 1 to Items.Count - 1 do
    begin
      It := TNewItem(Items[I]);
      J := I - 1;
      while (J >= AtNew) and (Pages.IndexOf(TNewItem(Items[J]).Page) > Pages.IndexOf(It.Page)) do
      begin
        Items[J + 1] := Items[J];
        Dec(J);
      end;
      Items[J + 1] := It;
    end;
  finally
    Repo.Free;
  end;
end;

{ an item's own 32 x 32 icon: its wizard's or its icon file's (0: none) }
function LoadItemIcon(It: TNewItem): HICON;
begin
  Result := 0;
  if It.Glyph <> 0 then
    Result := CopyIcon(It.Glyph)
  else if (It.IconFile <> '') and FileExists(It.IconFile) then
    Result := LoadImage(0, PChar(It.IconFile), IMAGE_ICON, 32, 32, LR_LOADFROMFILE);
end;

procedure TNewItemsDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  if UILayoutPass then Exit;
  { the strip of Copy / Inherit / Use is aligned to the bottom, and the layout keeps its height: with a
    larger font its buttons need more }
  if xPanel1.Height < RCopy.Top + RCopy.Height then xPanel1.Height := RCopy.Top + RCopy.Height;
  FItems := TList.Create;
  FIcons := TImageList.CreateSize(32, 32);
  { 32-bit images: the icons have alpha (Delphi 7's TImageList has no ColorDepth) }
  FIcons.Handle := ImageList_Create(32, 32, ILC_COLOR32 or ILC_MASK, 0, 16);
  ItemList.LargeImages := FIcons;
end;

destructor TNewItemsDlg.Destroy;
var
  I: Integer;
begin
  if FItems <> nil then
    for I := 0 to FItems.Count - 1 do TObject(FItems[I]).Free;
  FItems.Free;
  FIcons.Free;
  inherited;
end;

procedure TNewItemsDlg.TabControlChange(Sender: TObject);
begin
  ShowPage;
end;

procedure TNewItemsDlg.ShowPage;
var
  I: Integer;
  It: TNewItem;
  LI: TListItem;
  Page: string;
  H: HICON;
  Ico: TIcon;
  Templates: Boolean;
begin
  if TabControl.TabIndex < 0 then Exit;
  Page := TabControl.Tabs[TabControl.TabIndex];
  ItemList.Items.BeginUpdate;
  try
    ItemList.Items.Clear;
    ImageList_RemoveAll(FIcons.Handle);
    Ico := TIcon.Create;
    try
      for I := 0 to FItems.Count - 1 do
      begin
        It := TNewItem(FItems[I]);
        if It.Page <> Page then Continue;
        LI := ItemList.Items.Add;
        LI.Caption := It.Name;
        LI.Data := It;
        H := LoadItemIcon(It);
        if H <> 0 then
        begin
          Ico.Handle := H;
          LI.ImageIndex := FIcons.AddIcon(Ico);
        end
        else
          LI.ImageIndex := AddLargeIcon(FIcons.Handle, It.Icon);
      end;
    finally
      Ico.Free;
    end;
  finally
    ItemList.Items.EndUpdate;
  end;
  if ItemList.Items.Count > 0 then ItemList.Items[0].Selected := True;
  { Copy / Use apply to the forms of the repository (not to a page of wizards alone) }
  Templates := False;
  for I := 0 to FItems.Count - 1 do
    if (TNewItem(FItems[I]).Page = Page) and (TNewItem(FItems[I]).Kind in [nkFormTemplate, nkProjectTemplate,
      nkProjectForm]) then Templates := True;
  xPanel1.Visible := (Page <> NewPage) and Templates;
end;

procedure TNewItemsDlg.ItemSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if Selected and (Item <> nil) and (Item.Data <> nil) then
  begin
    { Delphi's choices: a form of the repository all three, one of the project only Inherit, a
      project template only Copy }
    RCopy.Enabled := TNewItem(Item.Data).Kind <> nkProjectForm;
    RInherit.Enabled := TNewItem(Item.Data).Kind in [nkFormTemplate, nkProjectForm];
    RReference.Enabled := TNewItem(Item.Data).Kind = nkFormTemplate;
    if TNewItem(Item.Data).Kind = nkProjectForm then RInherit.Checked := True
    else if (RInherit.Checked and not RInherit.Enabled) or (RReference.Checked and not RReference.Enabled) then
      RCopy.Checked := True;
  end;
end;

procedure TNewItemsDlg.ItemDblClick(Sender: TObject);
begin
  aOK.Execute;
end;

procedure TNewItemsDlg.aOKExecute(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TNewItemsDlg.aOKUpdate(Sender: TObject);
begin
  aOK.Enabled := ItemList.Selected <> nil;
end;

class function TNewItemsDlg.Execute(AOwner: TComponent; const ProjectName: string; ProjectForms: TStrings;
  var Item: TNewItem; var Mode: TNewItemMode): Boolean;
var
  D: TNewItemsDlg;
  I, P1, P2, ProjectAt: Integer;
  It: TNewItem;
  S: string;
begin
  Result := False;
  Item := nil;
  D := TNewItemsDlg.Create(AOwner);
  try
    LoadNewItems(D.FItems);
    { the project's page after New (Delphi's items and the wizards there) }
    ProjectAt := 0;
    while (ProjectAt < D.FItems.Count) and (TNewItem(D.FItems[ProjectAt]).Page = NewPage) do Inc(ProjectAt);
    { the project's page after New, as Delphi has it: its forms to inherit from }
    if (ProjectName <> '') and (ProjectForms <> nil) then
      for I := 0 to ProjectForms.Count - 1 do
      begin
        S := ProjectForms[I];
        P1 := Pos('|', S);
        P2 := P1 + Pos('|', Copy(S, P1 + 1, MaxInt));
        if (P1 = 0) or (P2 = P1) then Continue;
        It := TNewItem.Create;
        It.Kind := nkProjectForm;
        It.Name := Copy(S, 1, P1 - 1);
        It.FormClass := Copy(S, P1 + 1, P2 - P1 - 1);
        It.Path := Copy(S, P2 + 1, MaxInt);
        It.Page := ProjectName;
        It.Icon := iiForm;
        D.FItems.Insert(ProjectAt + I, It);
      end;
    D.TabControl.Tabs.Clear;
    for I := 0 to D.FItems.Count - 1 do
      if D.TabControl.Tabs.IndexOf(TNewItem(D.FItems[I]).Page) < 0 then
        D.TabControl.Tabs.Add(TNewItem(D.FItems[I]).Page);
    D.TabControl.TabIndex := 0;
    D.ShowPage;
    if (D.ShowModal <> mrOk) or (D.ItemList.Selected = nil) then Exit;
    { the item outlives the dialog: a copy }
    It := TNewItem(D.ItemList.Selected.Data);
    Item := TNewItem.Create;
    Item.Kind := It.Kind;
    Item.Name := It.Name;
    Item.Page := It.Page;
    Item.Path := It.Path;
    Item.FormClass := It.FormClass;
    Item.Description := It.Description;
    Item.Wizard := It.Wizard;
    Item.Glyph := It.Glyph;
    if D.RInherit.Checked and D.RInherit.Enabled then Mode := nmInherit
    else if D.RReference.Checked and D.RReference.Enabled then Mode := nmUse
    else Mode := nmCopy;
    Result := True;
  finally
    D.Free;
  end;
end;

end.
