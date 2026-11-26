{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdPackageAddDlg;

{ D7 Studio - Add of the package editor (Delphi 7's):
  the pages Add Unit (a unit into the contains clause) and Requires (a
  package into the requires clause), each with the package's search path - Delphi's pages -,
  then New Component and Import ActiveX: the page of
  D7 Studio's New Component dialog and the controls of its Import ActiveX dialog, taken in when
  the dialog opens. Their controls, actions and checks stay those dialogs' (no second copy). OK
  takes what the page shown asks for. }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls,
  ActnList, SdNewCompDlg, SdImportTypeLibDlg;

type
  TPackageAddPage = (paUnit, paRequires, paNewComponent, paActiveX);

  TPackageAddInfo = record
    Page: TPackageAddPage;      // the page OK was given on
    FileName: string;           // Add Unit: the unit; Requires: the package (its name)
    SearchPath: string;         // of Add Unit or Requires
    PackageDir: string;         // Requires: the folder of a .dcp chosen with Browse ('' none)
    NewComp: TNewCompInfo;      // New Component
    Import: TImportTLBInfo;     // Import ActiveX
  end;

  TPackageAddDlg = class(TForm)
    PageControl: TPageControl;
    tsAddUnit: TTabSheet;
    auLabel1: TLabel;
    auLabel2: TLabel;
    auEditFileName: TEdit;
    auEditSearchPath: TEdit;
    auBrowseButton: TButton;
    tsRequires: TTabSheet;
    rqLabel1: TLabel;
    rqLabel2: TLabel;
    rqEditFileName: TEdit;
    rqBrowseButton: TButton;
    rqEditSearchPath: TEdit;
    Actions: TActionList;
    aBrowseUnit: TAction;
    aBrowsePackage: TAction;
    aOK: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure aBrowseUnitExecute(Sender: TObject);
    procedure aBrowsePackageExecute(Sender: TObject);
    procedure aOKExecute(Sender: TObject);
    procedure aOKUpdate(Sender: TObject);
    procedure PageChange(Sender: TObject);
  private
    FDir: string;
    FNewComp: TNewCompDlg;
    FImport: TImportTypeLibDlg;
    FNewCompSheet: TTabSheet;
    FActiveXSheet: TTabSheet;
    FFilled: Boolean;
    function Page: TPackageAddPage;
    procedure TakePages;
  public
    { Dir: the package's folder; Classes, PalettePages: New Component's ancestors and pages;
      ImportPages, Added: Import ActiveX's palette pages and its added files (read and written
      back); Info: the values to start with (search path, New Component's, Import's) }
    class function Execute(AOwner: TComponent; const Dir: string; Classes, PalettePages,
      ImportPages, Added: TStrings; var Info: TPackageAddInfo): Boolean;
  end;

var
  PackageAddDlg: TPackageAddDlg;

{ the package a Requires entry names: "vcl", "vcl.dcp" or the path of the .dcp }
function RequiredPackageName(const S: string): string;

implementation

uses
  Math, SdUI, SdFileNames, SdDelphiDir, SdDialogs;

{$R *.dfm}

function RequiredPackageName(const S: string): string;
begin
  Result := Trim(S);
  if SameText(ExtractFileExt(Result), '.dcp') then Result := ChangeFileExt(Result, '');
  Result := ExtractFileName(Result);
end;

procedure TPackageAddDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ the dialogs whose pages were taken in go first, with their controls: Import's OnDestroy reads
  its list, which the page control would free before them }
procedure TPackageAddDlg.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FImport);
  FreeAndNil(FNewComp);
end;

{ New Component's and Import ActiveX's controls join the page control, each on a page of its own, from
  their dialogs' margin (12) to a page's (9); the dialog grows to its largest page with a page's margin -
  Delphi's property sheet does the same; the band of the buttons follows by itself (anchored to the
  dialog's sides and bottom) }
procedure TPackageAddDlg.TakePages;
var
  I, K, W, H, DW, DH: Integer;
  S: TTabSheet;
begin
  FNewCompSheet := TTabSheet.Create(Self);
  FNewCompSheet.Caption := 'New Component';
  FNewCompSheet.PageControl := PageControl;
  UIMoveBody(FNewComp, FNewComp.pnlFooter, FNewCompSheet, -3, -3);
  FActiveXSheet := TTabSheet.Create(Self);
  FActiveXSheet.Caption := 'Import ActiveX';
  FActiveXSheet.PageControl := PageControl;
  UIMoveBody(FImport, FImport.pnlFooter, FActiveXSheet, -3, -3);
  W := 0;
  H := 0;
  for I := 0 to PageControl.PageCount - 1 do
  begin
    S := PageControl.Pages[I];
    for K := 0 to S.ControlCount - 1 do
      if S.Controls[K].Visible then
      begin
        W := Max(W, S.Controls[K].Left + S.Controls[K].Width + 9);
        H := Max(H, S.Controls[K].Top + S.Controls[K].Height + 9);
      end;
  end;
  DW := Max(0, W - tsAddUnit.ClientWidth);
  DH := Max(0, H - tsAddUnit.ClientHeight);
  ClientWidth := ClientWidth + DW;
  ClientHeight := ClientHeight + DH;
  PageControl.SetBounds(PageControl.Left, PageControl.Top, PageControl.Width + DW, PageControl.Height + DH);
  PageControl.ActivePageIndex := 0;
end;

{ the list of Import ActiveX is read (the registry) when its page is first shown }
procedure TPackageAddDlg.PageChange(Sender: TObject);
begin
  if (Page = paActiveX) and not FFilled then
  begin
    FFilled := True;
    Screen.Cursor := crHourGlass;
    try
      FImport.Fill;
    finally
      Screen.Cursor := crDefault;
    end;
  end;
end;

function TPackageAddDlg.Page: TPackageAddPage;
begin
  if PageControl.ActivePage = tsRequires then Result := paRequires
  else if (FNewCompSheet <> nil) and (PageControl.ActivePage = FNewCompSheet) then Result := paNewComponent
  else if (FActiveXSheet <> nil) and (PageControl.ActivePage = FActiveXSheet) then Result := paActiveX
  else Result := paUnit;
end;

procedure TPackageAddDlg.aBrowseUnitExecute(Sender: TObject);
begin
  BrowseFile(auEditFileName, 'Add Unit', 'Delphi unit (*.pas)|*.pas|Any file (*.*)|*.*', bfOpen, '', FDir);
end;

{ Delphi's Lib (the name in the box is not proposed: a package name, no file) }
procedure TPackageAddDlg.aBrowsePackageExecute(Sender: TObject);
var
  F: string;
begin
  F := '';
  if BrowseFile('Add Required Package', 'Delphi compiled package (*.dcp)|*.dcp', F, bfOpen, '', DelphiRoot + 'Lib') then
    rqEditFileName.Text := F;
end;

procedure TPackageAddDlg.aOKUpdate(Sender: TObject);
begin
  case Page of
    paUnit: aOK.Enabled := Trim(auEditFileName.Text) <> '';
    paRequires: aOK.Enabled := IsValidIdent(RequiredPackageName(rqEditFileName.Text));
    paNewComponent: aOK.Enabled := FNewComp.Valid;
  else
    aOK.Enabled := FImport.Valid;
  end;
end;

{ as Delphi's: a unit that is not there is refused, a component unit that is may be replaced }
procedure TPackageAddDlg.aOKExecute(Sender: TObject);
var
  F: string;
begin
  case Page of
    paUnit:
      begin
        F := ExpandFileName(Trim(auEditFileName.Text));
        if not DialogValid(Self, FileExistsU(F), Format('File %s not found.', [F]), auEditFileName) then Exit;
      end;
    paNewComponent:
      if not FNewComp.ConfirmFile(Handle) then Exit;
  end;
  ModalResult := mrOk;
end;

class function TPackageAddDlg.Execute(AOwner: TComponent; const Dir: string; Classes, PalettePages,
  ImportPages, Added: TStrings; var Info: TPackageAddInfo): Boolean;
var
  D: TPackageAddDlg;
begin
  D := TPackageAddDlg.Create(AOwner);
  try
    D.FDir := Dir;
    D.FNewComp := TNewCompDlg.Create(D);
    D.FNewComp.Prepare(Classes, PalettePages, Dir, Info.NewComp);
    D.FImport := TImportTypeLibDlg.Create(D);
    D.FImport.Prepare(True, ImportPages, Added, Info.Import);
    D.TakePages;
    D.auEditSearchPath.Text := Info.SearchPath;
    D.rqEditSearchPath.Text := Info.SearchPath;
    Result := D.ShowModal = mrOk;
    Added.Assign(D.FImport.Added);
    if not Result then Exit;
    Info.Page := D.Page;
    case Info.Page of
      paUnit:
        begin
          Info.FileName := ExpandFileName(Trim(D.auEditFileName.Text));
          Info.SearchPath := Trim(D.auEditSearchPath.Text);
        end;
      paRequires:
        begin
          Info.FileName := RequiredPackageName(D.rqEditFileName.Text);
          Info.SearchPath := Trim(D.rqEditSearchPath.Text);
          { a .dcp chosen with Browse: its folder is searched (as Delphi adds it to the path) }
          Info.PackageDir := ExcludeTrailingPathDelimiter(ExtractFilePath(Trim(D.rqEditFileName.Text)));
        end;
      paNewComponent: D.FNewComp.Collect(Info.NewComp);
      paActiveX: D.FImport.Collect(Info.Import);
    end;
  finally
    D.Free;
  end;
end;

end.
