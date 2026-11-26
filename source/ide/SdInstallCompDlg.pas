{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdInstallCompDlg;

{ D7 Studio - Component | Install Component: Delphi 7's dialog. A unit goes into an existing
  package or into a new one; the caller adds it to the package's contains clause, then builds
  and installs the package (TMainForm.ActInstallComponent). }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls, ActnList,
  SdDialogs;

type
  TInstallCompDlg = class(TForm)
    PageControl: TPageControl;
    tsExisting: TTabSheet;
    lblUnitE: TLabel;
    lblSearchE: TLabel;
    lblPackageE: TLabel;
    lblDescE: TLabel;
    edUnitE: TEdit;
    btnBrowseUnitE: TButton;
    edSearchE: TEdit;
    cbPackage: TComboBox;
    btnBrowsePackageE: TButton;
    edDescE: TEdit;
    tsNew: TTabSheet;
    lblUnitN: TLabel;
    lblSearchN: TLabel;
    lblPackageN: TLabel;
    lblDescN: TLabel;
    edUnitN: TEdit;
    btnBrowseUnitN: TButton;
    edSearchN: TEdit;
    edPackageN: TEdit;
    btnBrowsePackageN: TButton;
    edDescN: TEdit;
    Actions: TActionList;
    aBrowseUnit: TAction;
    aBrowsePackage: TAction;
    aOK: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure PageControlChange(Sender: TObject);
    procedure cbPackageChange(Sender: TObject);
    procedure aBrowseUnitExecute(Sender: TObject);
    procedure aBrowsePackageExecute(Sender: TObject);
    procedure aOKExecute(Sender: TObject);
    procedure aOKUpdate(Sender: TObject);
  private
    function IsNew: Boolean;
    function UnitEdit: TEdit;
    function SearchEdit: TEdit;
    function PackageText: string;
  public
    { Packages: the packages offered under "Into existing package"; Info comes in with the
      package to select and goes out with the answer }
    class function Execute(AOwner: TComponent; Packages: TStrings; var Info: TInstallCompInfo): Boolean;
  end;

var
  InstallCompDlg: TInstallCompDlg;

implementation

uses
  SdUI, SdProject;

const
  PackageFilter = 'Delphi package (*.dpk)|*.dpk';

{$R *.dfm}

procedure TInstallCompDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

function TInstallCompDlg.IsNew: Boolean;
begin
  Result := PageControl.ActivePage = tsNew;
end;

function TInstallCompDlg.UnitEdit: TEdit;
begin
  if IsNew then Result := edUnitN else Result := edUnitE;
end;

function TInstallCompDlg.SearchEdit: TEdit;
begin
  if IsNew then Result := edSearchN else Result := edSearchE;
end;

function TInstallCompDlg.PackageText: string;
begin
  if IsNew then Result := Trim(edPackageN.Text) else Result := Trim(cbPackage.Text);
end;

{ the two pages share the unit and its search path, as in Delphi }
procedure TInstallCompDlg.PageControlChange(Sender: TObject);
begin
  if IsNew then
  begin
    edUnitN.Text := edUnitE.Text;
    edSearchN.Text := edSearchE.Text;
  end
  else
  begin
    edUnitE.Text := edUnitN.Text;
    edSearchE.Text := edSearchN.Text;
  end;
end;

{ an existing package shows its description and its search path }
procedure TInstallCompDlg.cbPackageChange(Sender: TObject);
var
  P: TSdProject;
begin
  edDescE.Text := '';
  if not FileExists(Trim(cbPackage.Text)) then Exit;
  P := TSdProject.Create;
  try
    try
      P.Load(Trim(cbPackage.Text));
      edDescE.Text := P.Description;
      edSearchE.Text := P.SearchPathList;
    except
    end;
  finally
    P.Free;
  end;
end;

{ the dialogs start in the folder of the file given (the name is not proposed) }
procedure TInstallCompDlg.aBrowseUnitExecute(Sender: TObject);
var
  F: string;
begin
  F := '';
  if BrowseFile('Unit file name', 'Delphi unit (*.pas)|*.pas', F, bfOpen, '', ExtractFilePath(UnitEdit.Text)) then
    UnitEdit.Text := F;
end;

procedure TInstallCompDlg.aBrowsePackageExecute(Sender: TObject);
var
  F, Dir: string;
begin
  F := '';
  if PackageText <> '' then Dir := ExtractFilePath(PackageText) else Dir := ExtractFilePath(UnitEdit.Text);
  if IsNew then
  begin
    if BrowseFile('Package name', PackageFilter, F, bfSave, 'dpk', Dir) then edPackageN.Text := F;
  end
  else if BrowseFile('Package name', PackageFilter, F, bfOpen, 'dpk', Dir) then
  begin
    cbPackage.Text := F;
    cbPackageChange(cbPackage);
  end;
end;

procedure TInstallCompDlg.aOKUpdate(Sender: TObject);
begin
  aOK.Enabled := (Trim(UnitEdit.Text) <> '') and (PackageText <> '');
end;

procedure TInstallCompDlg.aOKExecute(Sender: TObject);
var
  U, Pkg: string;
  PkgCtl: TWinControl;
begin
  U := ExpandFileName(Trim(UnitEdit.Text));
  Pkg := PackageText;
  if IsNew then PkgCtl := edPackageN else PkgCtl := cbPackage;
  if not DialogValid(Self, FileExists(U) and SameText(ExtractFileExt(U), '.pas'),
    Format('Unit file %s not found.', [U]), UnitEdit) then Exit;
  if ExtractFileExt(Pkg) = '' then Pkg := Pkg + '.dpk';
  Pkg := ExpandFileName(Pkg);
  if not DialogValid(Self, IsPackageFile(Pkg), 'The package must be a .dpk file.', PkgCtl) then Exit;
  if IsNew then
  begin
    if not DialogValid(Self, IsValidIdent(ChangeFileExt(ExtractFileName(Pkg), '')),
      'The package name must be a valid identifier.', PkgCtl) then Exit;
    if not DialogValid(Self, not FileExists(Pkg), Format('Package %s already exists.', [Pkg]), PkgCtl) then Exit;
    if not DialogValid(Self, DirectoryExists(ExtractFilePath(Pkg)), Format('Folder %s not found.',
      [ExtractFilePath(Pkg)]), PkgCtl) then Exit;
  end
  else if not DialogValid(Self, FileExists(Pkg), Format('Package %s not found.', [Pkg]), PkgCtl) then Exit;
  UnitEdit.Text := U;
  if IsNew then edPackageN.Text := Pkg else cbPackage.Text := Pkg;
  ModalResult := mrOk;
end;

class function TInstallCompDlg.Execute(AOwner: TComponent; Packages: TStrings;
  var Info: TInstallCompInfo): Boolean;
var
  D: TInstallCompDlg;
begin
  D := TInstallCompDlg.Create(AOwner);
  try
    D.cbPackage.Items.Assign(Packages);
    D.cbPackage.Text := Info.PackageFile;
    D.cbPackageChange(nil);
    D.edUnitE.Text := Info.UnitFile;
    D.PageControl.ActivePage := D.tsExisting;
    Result := D.ShowModal = mrOk;
    if Result then
    begin
      Info.NewPackage := D.IsNew;
      Info.UnitFile := Trim(D.UnitEdit.Text);
      Info.SearchPath := Trim(D.SearchEdit.Text);
      Info.PackageFile := D.PackageText;
      if D.IsNew then Info.Description := Trim(D.edDescN.Text) else Info.Description := D.edDescE.Text;
    end;
  finally
    D.Free;
  end;
end;

end.
