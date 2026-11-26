{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdImportTypeLibDlg;

{ D7 Studio - Project | Import Type Library and Component | Import ActiveX Control: Delphi 7's
  Import Type Library and Import ActiveX dialogs (their controls, named as Delphi names them,
  laid out on the dialog grid). The
  registered libraries or ActiveX controls; where the chosen one's file is; the wrapper classes
  the import makes; the palette page, the folder of the unit, the search path (for Install),
  Generate Component Wrapper (Import Type Library); Install... or Create Unit. Add... puts a
  library file into the list (kept in the settings: the registry is not written), Remove takes
  such a file off again. }

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ActnList, SdTypeLib;

type
  TImportTLBInfo = record
    Name: string;             // the library's help string
    Guid: TGUID;
    Major, Minor: Word;
    Lcid: Integer;
    FileName: string;
    UnitDir, PalettePage, SearchPath: string;
    Wrappers: Boolean;        // Generate Component Wrapper
    Install: Boolean;         // Install... (else Create Unit)
  end;

  TImportTypeLibDlg = class(TForm)
    Location: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    ControlList: TListBox;
    AddButton: TButton;
    RemoveButton: TButton;
    ClassNames: TMemo;
    PageNames: TComboBox;
    UnitDirName: TEdit;
    BrowseButton: TButton;
    SearchPath: TEdit;
    MakeComponentBox: TCheckBox;
    Actions: TActionList;
    aAdd: TAction;
    aRemove: TAction;
    aBrowse: TAction;
    aInstall: TAction;
    aCreateUnit: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    InstallButton: TButton;
    OkButton: TButton;
    CancelBtn: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure aAddExecute(Sender: TObject);
    procedure aRemoveExecute(Sender: TObject);
    procedure aRemoveUpdate(Sender: TObject);
    procedure aBrowseExecute(Sender: TObject);
    procedure aInstallExecute(Sender: TObject);
    procedure aCreateUnitExecute(Sender: TObject);
    procedure aChosenUpdate(Sender: TObject);
    procedure ListClick(Sender: TObject);
    procedure WrapperClick(Sender: TObject);
  private
    FActiveX: Boolean;
    FAdded: TStringList;      // the files added with Add...
    FInstall: Boolean;
    procedure ShowChosen;
    function Chosen: TTypeLibRef;
    function Options: TTLBOptions;
    procedure Finish(Install: Boolean);
  public
    { ActiveX: Import ActiveX Control (the controls; wrappers for them); Added: the library files
      added with Add... (read and written back) }
    class function Execute(AOwner: TComponent; ActiveX: Boolean; Pages, Added: TStrings;
      var Info: TImportTLBInfo): Boolean;
    { the steps of Execute, also for the package editor's Add, which shows the controls (all but
      the command buttons: MoveBodyTo) on a page of its own: the values to start with; the list
      of libraries or controls (Fill - it reads the registry); OK can be given (a library chosen,
      a unit folder); the values chosen }
    procedure Prepare(ActiveX: Boolean; Pages, Added: TStrings; const Info: TImportTLBInfo);
    procedure Fill;
    function Valid: Boolean;
    procedure Collect(var Info: TImportTLBInfo);
    procedure MoveBodyTo(Host: TWinControl);
    property Added: TStringList read FAdded;
  end;

var
  ImportTypeLibDlg: TImportTypeLibDlg;

implementation

uses
  ActiveX, SdUI, SdDialogs;

{$R *.dfm}

procedure TImportTypeLibDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  FAdded := TStringList.Create;
end;

procedure TImportTypeLibDlg.FormDestroy(Sender: TObject);
begin
  FreeTypeLibRefs(ControlList.Items);
  FAdded.Free;
end;

{ the registered libraries (or controls), then the files added with Add... }
procedure TImportTypeLibDlg.Fill;
var
  L: TStringList;
  I: Integer;
  Ref: TTypeLibRef;
  TL: ITypeLib;
  A: PTLibAttr;
begin
  L := TStringList.Create;
  try
    if FActiveX then ListActiveXControls(L) else ListTypeLibraries(L);
    if not FActiveX then
      for I := 0 to FAdded.Count - 1 do
        try
          TL := LoadTypeLibrary(FAdded[I]);
          Ref := TTypeLibRef.Create;
          Ref.Name := TypeLibHelp(TL);
          if Ref.Name = '' then Ref.Name := TypeLibName(TL);
          if Succeeded(TL.GetLibAttr(A)) then
          begin
            Ref.Guid := A.guid;
            Ref.Major := A.wMajorVerNum;
            Ref.Minor := A.wMinorVerNum;
            Ref.Lcid := A.lcid;
            TL.ReleaseTLibAttr(A);
          end;
          Ref.FileName := FAdded[I];
          Ref.ControlName := #1;      // (one added with Add...)
          L.AddObject(Format('%s (Version %d.%d)', [Ref.Name, Ref.Major, Ref.Minor]), Ref);
        except
          { a file that is no longer a library: left out }
        end;
    ControlList.Items.BeginUpdate;
    try
      FreeTypeLibRefs(ControlList.Items);
      ControlList.Items.Assign(L);
    finally
      ControlList.Items.EndUpdate;
    end;
  finally
    L.Free;
  end;
  if ControlList.Items.Count > 0 then ControlList.ItemIndex := 0;
  ShowChosen;
end;

function TImportTypeLibDlg.Chosen: TTypeLibRef;
begin
  if ControlList.ItemIndex >= 0 then Result := TTypeLibRef(ControlList.Items.Objects[ControlList.ItemIndex])
  else Result := nil;
end;

function TImportTypeLibDlg.Options: TTLBOptions;
begin
  Result.Wrappers := MakeComponentBox.Checked and not FActiveX;
  Result.ControlsOnly := FActiveX;
  Result.PalettePage := Trim(PageNames.Text);
  Result.Safecall := 1;
end;

{ where the chosen library is, the wrapper classes its import makes }
procedure TImportTypeLibDlg.ShowChosen;
var
  Ref: TTypeLibRef;
begin
  Ref := Chosen;
  if Ref = nil then
  begin
    Location.Caption := '';
    ClassNames.Lines.Clear;
    Exit;
  end;
  Location.Caption := Ref.FileName;
  try
    ClassNames.Lines.Text := TypeLibWrapperNames(LoadTypeLibraryRef(Ref), Options);
  except
    on E: Exception do ClassNames.Lines.Text := E.Message;
  end;
end;

procedure TImportTypeLibDlg.ListClick(Sender: TObject);
begin
  ShowChosen;
end;

procedure TImportTypeLibDlg.WrapperClick(Sender: TObject);
begin
  ShowChosen;
end;

procedure TImportTypeLibDlg.aAddExecute(Sender: TObject);
var
  F: string;
  TL: ITypeLib;
begin
  F := '';
  if not BrowseFile('Add Type Library',
    'Type Library (*.tlb;*.olb;*.dll;*.ocx;*.exe)|*.tlb;*.olb;*.dll;*.ocx;*.exe|Any File (*.*)|*.*', F) then Exit;
  try
    TL := LoadTypeLibrary(F);
  except
    MessageBox(Handle, PChar(F + ' has no type library.'), PChar(Caption), MB_OK or MB_ICONERROR);
    Exit;
  end;
  if FAdded.IndexOf(F) < 0 then FAdded.Add(F);
  Fill;
end;

procedure TImportTypeLibDlg.aRemoveExecute(Sender: TObject);
var
  I: Integer;
begin
  if Chosen = nil then Exit;
  I := FAdded.IndexOf(Chosen.FileName);
  if I >= 0 then FAdded.Delete(I);
  Fill;
end;

procedure TImportTypeLibDlg.aRemoveUpdate(Sender: TObject);
begin
  aRemove.Enabled := (Chosen <> nil) and (Chosen.ControlName = #1);
end;

procedure TImportTypeLibDlg.aBrowseExecute(Sender: TObject);
begin
  BrowseFolder(UnitDirName, 'Unit dir name', '');
end;

procedure TImportTypeLibDlg.aChosenUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := Valid;
end;

function TImportTypeLibDlg.Valid: Boolean;
begin
  Result := (Chosen <> nil) and (Trim(UnitDirName.Text) <> '');
end;

procedure TImportTypeLibDlg.Finish(Install: Boolean);
begin
  FInstall := Install;
  ModalResult := mrOk;
end;

procedure TImportTypeLibDlg.aInstallExecute(Sender: TObject);
begin
  Finish(True);
end;

procedure TImportTypeLibDlg.aCreateUnitExecute(Sender: TObject);
begin
  Finish(False);
end;

procedure TImportTypeLibDlg.Prepare(ActiveX: Boolean; Pages, Added: TStrings; const Info: TImportTLBInfo);
begin
  FActiveX := ActiveX;
  if ActiveX then
  begin
    Caption := 'Import ActiveX';
    MakeComponentBox.Visible := False;
    AddButton.Visible := False;
    RemoveButton.Visible := False;
  end;
  FAdded.Assign(Added);
  PageNames.Items.Assign(Pages);
  PageNames.Text := Info.PalettePage;
  UnitDirName.Text := Info.UnitDir;
  SearchPath.Text := Info.SearchPath;
  MakeComponentBox.Checked := Info.Wrappers;
end;

procedure TImportTypeLibDlg.Collect(var Info: TImportTLBInfo);
var
  Ref: TTypeLibRef;
begin
  Ref := Chosen;
  Info.Name := Ref.Name;
  Info.Guid := Ref.Guid;
  Info.Major := Ref.Major;
  Info.Minor := Ref.Minor;
  Info.Lcid := Ref.Lcid;
  Info.FileName := Ref.FileName;
  Info.UnitDir := Trim(UnitDirName.Text);
  Info.PalettePage := Trim(PageNames.Text);
  Info.SearchPath := Trim(SearchPath.Text);
  Info.Wrappers := MakeComponentBox.Checked;
  Info.Install := FInstall;
end;

{ every control but the band of the command buttons, at the same place in Host - the windowed ones in their
  tab order (each joins the end of Host's) }
procedure TImportTypeLibDlg.MoveBodyTo(Host: TWinControl);
begin
  UIMoveBody(Self, pnlFooter, Host, 0, 0);
end;

class function TImportTypeLibDlg.Execute(AOwner: TComponent; ActiveX: Boolean; Pages, Added: TStrings;
  var Info: TImportTLBInfo): Boolean;
var
  D: TImportTypeLibDlg;
begin
  D := TImportTypeLibDlg.Create(AOwner);
  try
    D.Prepare(ActiveX, Pages, Added, Info);
    D.Fill;
    Result := D.ShowModal = mrOk;
    Added.Assign(D.FAdded);
    if Result then D.Collect(Info);
  finally
    D.Free;
  end;
end;

end.
