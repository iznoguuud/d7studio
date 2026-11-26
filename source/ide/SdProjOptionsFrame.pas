{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdProjOptionsFrame;

{ D7 Studio - Project | Options: Delphi 7's dialog:
  Forms, Application, Compiler, Compiler Messages, Linker,
  Directories/Conditionals, Version Info, Packages, and Default. The options live in the .dof
  with Delphi's keys (D7 Studio's own ones in its section); the Forms page and the title and help
  file of the Application page edit the project source; the icon and the version information go
  into the project's .res. The Packages page is also Component | Install Packages (as in Delphi):
  its design packages are loaded and unloaded at once. Without a project the dialog edits the
  default options. A frame, shown by the Options dialog as Project Options (SdOptionsDlg:
  TOptionsDlg.ExecuteProject): its pages without tabs, Default in its footer. }

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls,
  CheckLst, Grids, Mask, Buttons, ActnList, Menus, SdProject;

type
  TProjOptionsFrame = class(TFrame)
    PageControl: TPageControl;
    tsForms: TTabSheet;
    fmLabel11: TLabel;
    fmLabel6: TLabel;
    fmLabel12: TLabel;
    AddSelected: TSpeedButton;
    AddAll: TSpeedButton;
    RemoveSelected: TSpeedButton;
    RemoveAll: TSpeedButton;
    AvailableForms: TListBox;
    AutoCreateForms: TListBox;
    cbMainForm: TComboBox;
    tsApplication: TTabSheet;
    apGroupBox13: TGroupBox;
    AppHelpFileLbl: TLabel;
    AppTitleLbl: TLabel;
    AppIconLbl: TLabel;
    IconPanel: TPanel;
    shpIcon: TShape;
    IconImage: TImage;
    LoadIconBtn: TButton;
    bpBrowseHelp: TButton;
    AppHelpFile: TEdit;
    AppTitle: TEdit;
    chkThemes: TCheckBox;
    apGroupBox15: TGroupBox;
    apLabel19: TLabel;
    AppFileExt: TEdit;
    lblPlatform: TLabel;
    cbPlatform: TComboBox;
    lblTargetWindows: TLabel;
    cbTargetWindows: TComboBox;
    lblDpiAwareness: TLabel;
    cbDpiAwareness: TComboBox;
    lblExecLevel: TLabel;
    cbExecLevel: TComboBox;
    tsCompiler: TTabSheet;
    cpGroupBox4: TGroupBox;
    cbDebugInfo: TCheckBox;
    cbLocalSymbols: TCheckBox;
    cbSymbolInfo: TCheckBox;
    cbAssertions: TCheckBox;
    cbDefinitionsOnly: TCheckBox;
    cbDebugDCU: TCheckBox;
    cpGroupBox3: TGroupBox;
    cbVarStrCheck: TCheckBox;
    cbFullBoolEval: TCheckBox;
    cbExtSyntax: TCheckBox;
    cbTypedPointers: TCheckBox;
    cbOpenParameters: TCheckBox;
    cbHugeStrings: TCheckBox;
    cbAssignConst: TCheckBox;
    cpGroupBox2: TGroupBox;
    cbRangeCheck: TCheckBox;
    cbInOutCheck: TCheckBox;
    cbOverflowCheck: TCheckBox;
    cpGroupBox1: TGroupBox;
    cpLabel1: TLabel;
    cbOptimization: TCheckBox;
    cbStackFrames: TCheckBox;
    cbPentiumSafe: TCheckBox;
    cbRecordAlign: TComboBox;
    tsMessages: TTabSheet;
    gbGeneral: TGroupBox;
    cbShowHints: TCheckBox;
    cbShowWarnings: TCheckBox;
    gbWarnings: TGroupBox;
    WarningsList: TCheckListBox;
    tsLinker: TTabSheet;
    lkGroupBox9: TGroupBox;
    lkLabel1: TLabel;
    lkLabel2: TLabel;
    lkLabel13: TLabel;
    ecStackSize: TEdit;
    ecImageBase: TEdit;
    ecMaxStackSize: TEdit;
    lkGroupBox8: TGroupBox;
    cbExtDebug: TCheckBox;
    cbConsoleApp: TCheckBox;
    cbRemoteDebug: TCheckBox;
    chkModernHeader: TCheckBox;
    lkGroupBox7: TGroupBox;
    rbGenerateBPUs: TRadioButton;
    rbGenerateCObjs: TRadioButton;
    rbGenerateCPPObjs: TRadioButton;
    cbIncludeNamespaces: TCheckBox;
    cbExportAllSymbols: TCheckBox;
    lkGroupBox6: TGroupBox;
    rbMapFileOff: TRadioButton;
    rbMapSegOnly: TRadioButton;
    rbMapSegPubs: TRadioButton;
    rbMapDetailed: TRadioButton;
    lkGroupBox14: TGroupBox;
    lkLabel14: TLabel;
    ecExeDescription: TEdit;
    tsDirectories: TTabSheet;
    drGroupBox11: TGroupBox;
    drLabel8: TLabel;
    ddConditionals: TComboBox;
    bConditionals: TButton;
    drGroupBox10: TGroupBox;
    drLabel3: TLabel;
    drLabel4: TLabel;
    drLabel16: TLabel;
    drLabel15: TLabel;
    drLabel1: TLabel;
    drLabel2: TLabel;
    ddOutputDir: TComboBox;
    ddSearchPath: TComboBox;
    ddUnitOutput: TComboBox;
    ddDebugSourcePath: TComboBox;
    ddDPLOutputDir: TComboBox;
    ddDCPOutputDir: TComboBox;
    bDirSearch: TButton;
    bDirDebugSource: TButton;
    bUnitOutputDir: TButton;
    bOutputDir: TButton;
    bDPLOutputDir: TButton;
    bDCPOutputDir: TButton;
    drGroupBox12: TGroupBox;
    drLabel10: TLabel;
    ddUnitAliases: TComboBox;
    bUnitAliases: TButton;
    tsVersionInfo: TTabSheet;
    viPanel1: TPanel;
    ModVerGroup: TGroupBox;
    viLabel1: TLabel;
    viLabel2: TLabel;
    viLabel3: TLabel;
    viLabel4: TLabel;
    MVN1: TMaskEdit;
    MVN2: TMaskEdit;
    MVN3: TMaskEdit;
    MVN4: TMaskEdit;
    UD4: TUpDown;
    UD3: TUpDown;
    UD2: TUpDown;
    UD1: TUpDown;
    cbIncBuildNum: TCheckBox;
    ModAttrGroup: TGroupBox;
    DebugBuild: TCheckBox;
    PreRelease: TCheckBox;
    PrivateBuild: TCheckBox;
    SpecialBuild: TCheckBox;
    DLL: TCheckBox;
    ValueGrid: TStringGrid;
    LangGroup: TGroupBox;
    LangIDLbl: TLabel;
    LocaleLabel: TLabel;
    LangID: TComboBox;
    cbIncludeVerInfo: TCheckBox;
    tsPackages: TTabSheet;
    pkGroupBox1: TGroupBox;
    DesignPackageList: TCheckListBox;
    pkPanel1: TPanel;
    shpPackageFile: TShape;
    LabelPackageFile: TLabel;
    AddButton: TButton;
    RemoveButton: TButton;
    ButtonComponents: TButton;
    EditButton: TButton;
    pkGroupBox2: TGroupBox;
    EditPackages: TEdit;
    ModifyRuntimeButton: TButton;
    RuntimePackages: TCheckBox;
    Footer: TPanel;
    chkDefault: TCheckBox;
    Actions: TActionList;
    aToAuto: TAction;
    aToAvail: TAction;
    aAllToAuto: TAction;
    aAllToAvail: TAction;
    aLoadIcon: TAction;
    aBrowseHelp: TAction;
    aDirOutput: TAction;
    aDirUnitOutput: TAction;
    aDirBpl: TAction;
    aDirDcp: TAction;
    aListSearch: TAction;
    aListDebugSource: TAction;
    aListConditionals: TAction;
    aListAliases: TAction;
    aPkgAdd: TAction;
    aPkgRemove: TAction;
    aPkgEdit: TAction;
    aPkgComponents: TAction;
    aRuntimeAdd: TAction;
    aKeyAdd: TAction;
    aKeyDelete: TAction;
    aKeyRename: TAction;
    KeyPopup: TPopupMenu;
    miKeyAdd: TMenuItem;
    miKeyRename: TMenuItem;
    miKeyDelete: TMenuItem;
    procedure FormsMoveExecute(Sender: TObject);
    procedure FormsMoveUpdate(Sender: TObject);
    procedure aLoadIconExecute(Sender: TObject);
    procedure aBrowseHelpExecute(Sender: TObject);
    procedure BrowseDirExecute(Sender: TObject);
    procedure EditListExecute(Sender: TObject);
    procedure aPkgAddExecute(Sender: TObject);
    procedure aPkgRemoveExecute(Sender: TObject);
    procedure aPkgEditExecute(Sender: TObject);
    procedure aPkgComponentsExecute(Sender: TObject);
    procedure PkgSelectedUpdate(Sender: TObject);
    procedure aRuntimeAddExecute(Sender: TObject);
    procedure RuntimeUpdate(Sender: TObject);
    procedure aKeyAddExecute(Sender: TObject);
    procedure aKeyDeleteExecute(Sender: TObject);
    procedure aKeyRenameExecute(Sender: TObject);
    procedure KeyDeleteUpdate(Sender: TObject);
    procedure ValueGridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure cbPlatformChange(Sender: TObject);
    procedure FormListDblClick(Sender: TObject);
    procedure MainFormChange(Sender: TObject);
    procedure PackageClick(Sender: TObject);
    procedure PackageClickCheck(Sender: TObject);
    procedure PackageDblClick(Sender: TObject);
    procedure IncludeVerInfoClick(Sender: TObject);
    procedure VersionChange(Sender: TObject);
  private
    FProject: TSdProject;
    FIcon: TMemoryStream;             // a new icon (Load Icon), written on OK
    FUpdating: Boolean;
    FTitle: string;
    FVersionNums: string;             // the version numbers FileVersion last followed
    function VersionNums: string;
    function KeyNameFree(const Name: string; Row: Integer): Boolean;
    procedure FillLists;
    procedure SyncMain;
    procedure MoveForm(Src, Dst: TListBox; All: Boolean);
    procedure FillPackages(Select: TObject);
    procedure LayoutDirectories;
    function ProjectBase: string;
    function DirCombo(Sender: TObject): TComboBox;
    procedure LoadValues(const DprSource: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the options of Project (nil: none) with DprSource, the project source, once, when the dialog
      opens - its pages: 0 Forms, 1 Application, 2 Compiler, 3 Compiler Messages, 4 Linker,
      5 Directories/Conditionals, 6 Version Info, 7 Packages; after OK the values into the
      project and DprSource }
    procedure LoadOptions(Project: TSdProject; const DprSource: string);
    procedure SaveOptions(var DprSource: string);
    { the dialog's caption: Project Options for <program>, Default Project Options }
    property Title: string read FTitle;
  end;

var
  { Packages | Edit: the package source to open after the dialog ('' = none) }
  PackageToEdit: string;

implementation

uses
  {$WARN UNIT_PLATFORM OFF} FileCtrl, {$WARN UNIT_PLATFORM ON}
  Graphics, SdUI, SdFormSrc, SdSettings, SdFileNames, SdDesignHost, SdDelphiDir, SdDialogs, SdEnvOptions,
  SdFormDesigner;

{$R *.dfm}

const
  { the switches of the Compiler page: check box, letter of the .dof [Compiler] section }
  SwitchBoxes: array[0..15] of array[0..1] of string = (
    ('cbOptimization', 'O'), ('cbStackFrames', 'W'), ('cbPentiumSafe', 'U'), ('cbRangeCheck', 'R'),
    ('cbInOutCheck', 'I'), ('cbOverflowCheck', 'Q'), ('cbVarStrCheck', 'V'), ('cbFullBoolEval', 'B'),
    ('cbExtSyntax', 'X'), ('cbTypedPointers', 'T'), ('cbOpenParameters', 'P'), ('cbHugeStrings', 'H'),
    ('cbAssignConst', 'J'), ('cbDebugInfo', 'D'), ('cbLocalSymbols', 'L'), ('cbAssertions', 'C'));
  { the other check boxes that are an option each (checked: not 0); the D7 Studio section's in the
    order they are first written into a .dof }
  CheckBoxes: array[0..14] of TOptionCheck = (
    (Name: 'cbDebugDCU'; Section: ThemeSection; Key: 'DebugDCUs'; Default: 0),
    (Name: 'cbShowHints'; Section: 'Compiler'; Key: 'ShowHints'; Default: 1),
    (Name: 'cbShowWarnings'; Section: 'Compiler'; Key: 'ShowWarnings'; Default: 1),
    (Name: 'cbIncludeNamespaces'; Section: ThemeSection; Key: 'ObjNamespaces'; Default: 0),
    (Name: 'cbExportAllSymbols'; Section: ThemeSection; Key: 'ObjExportAll'; Default: 0),
    (Name: 'cbExtDebug'; Section: 'Linker'; Key: 'DebugInfo'; Default: 0),
    (Name: 'cbRemoteDebug'; Section: 'Linker'; Key: 'RemoteSymbols'; Default: 0),
    (Name: 'cbIncludeVerInfo'; Section: 'Version Info'; Key: 'IncludeVerInfo'; Default: 0),
    (Name: 'cbIncBuildNum'; Section: 'Version Info'; Key: 'AutoIncBuild'; Default: 0),
    (Name: 'DebugBuild'; Section: 'Version Info'; Key: 'Debug'; Default: 0),
    (Name: 'PreRelease'; Section: 'Version Info'; Key: 'PreRelease'; Default: 0),
    (Name: 'SpecialBuild'; Section: 'Version Info'; Key: 'Special'; Default: 0),
    (Name: 'PrivateBuild'; Section: 'Version Info'; Key: 'Private'; Default: 0),
    (Name: 'DLL'; Section: 'Version Info'; Key: 'DLL'; Default: 0),
    (Name: 'RuntimePackages'; Section: 'Directories'; Key: 'UsePackages'; Default: 0));
  { the folders and lists of Directories/Conditionals: combo box, .dof section and key, history list }
  DirCombos: array[0..7] of TOptionCombo = (
    ('ddOutputDir', 'Directories', 'OutputDir', 'hlOutputDirectorry'),
    ('ddUnitOutput', 'Directories', 'UnitOutputDir', 'hlUnitOutputDirectory'),
    ('ddSearchPath', 'Directories', 'SearchPath', 'hlSearchPath'),
    ('ddDebugSourcePath', 'Directories', 'DebugSourceDirs', 'hlDebugSourcePath'),
    ('ddDPLOutputDir', 'Directories', 'PackageDLLOutputDir', 'hlBPLOutput'),
    ('ddDCPOutputDir', 'Directories', 'PackageDCPOutputDir', 'hlDCPOutput'),
    ('ddConditionals', 'Directories', 'Conditionals', 'hlConditionals'),
    ('ddUnitAliases', 'Compiler', 'UnitAliases', 'hlUnitAliases'));
  { the keys of the version information that Delphi puts there }
  DefaultVersionKeys: array[0..9] of string = ('CompanyName', 'FileDescription', 'FileVersion',
    'InternalName', 'LegalCopyright', 'LegalTrademarks', 'OriginalFilename', 'ProductName',
    'ProductVersion', 'Comments');

{ ---------------------------------------------------------------- setup }

{ laid out for the UI font only: LoadOptions fills it when the dialog opens }
constructor TProjOptionsFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  UIPrepareFrame(Self);
  FIcon := TMemoryStream.Create;
  { the version keys' grid flat: its frame one line (its title cells have no raised edges, as
    the .dfm leaves the fixed lines out) }
  UIFlatBorder(ValueGrid);
end;

destructor TProjOptionsFrame.Destroy;
begin
  FIcon.Free;
  inherited Destroy;
end;

{ what Delphi fills in when its pages are created }
procedure TProjOptionsFrame.FillLists;
var
  I: Integer;
begin
  for I := Low(CompilerWarnings) to High(CompilerWarnings) do WarningsList.Items.Add(CompilerWarnings[I].Text);
  { the languages of Windows, as in Delphi's Locale ID list }
  for I := 0 to Languages.Count - 1 do LangID.Items.AddObject(Languages.Name[I], TObject(Languages.LocaleID[I]));
  ValueGrid.Cells[0, 0] := 'Key';
  ValueGrid.Cells[1, 0] := 'Value';
end;

{ ---------------------------------------------------------------- Forms }

procedure TProjOptionsFrame.SyncMain;
begin
  cbMainForm.Items.Assign(AutoCreateForms.Items);
  if AutoCreateForms.Items.Count > 0 then cbMainForm.ItemIndex := 0 else cbMainForm.ItemIndex := -1;
end;

{ a form of List chosen (Delphi's lists are multi-select: ItemIndex is only the caret there) }
function AnySelected(List: TListBox): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to List.Items.Count - 1 do
    if List.Selected[I] then
    begin
      Result := True;
      Exit;
    end;
end;

{ the chosen forms, or all, to the other list - chosen there }
procedure TProjOptionsFrame.MoveForm(Src, Dst: TListBox; All: Boolean);
var
  I: Integer;
begin
  Src.Items.BeginUpdate;
  Dst.Items.BeginUpdate;
  try
    Dst.ClearSelection;
    for I := 0 to Src.Items.Count - 1 do
      if All or Src.Selected[I] then Dst.Selected[Dst.Items.Add(Src.Items[I])] := True;
    for I := Src.Items.Count - 1 downto 0 do
      if All or Src.Selected[I] then Src.Items.Delete(I);
  finally
    Dst.Items.EndUpdate;
    Src.Items.EndUpdate;
  end;
  SyncMain;
end;

procedure TProjOptionsFrame.FormsMoveExecute(Sender: TObject);
begin
  if Sender = aToAvail then MoveForm(AutoCreateForms, AvailableForms, False)
  else if Sender = aAllToAvail then MoveForm(AutoCreateForms, AvailableForms, True)
  else if Sender = aToAuto then MoveForm(AvailableForms, AutoCreateForms, False)
  else if Sender = aAllToAuto then MoveForm(AvailableForms, AutoCreateForms, True);
end;

{ a list gives away its chosen forms, or all it has }
procedure TProjOptionsFrame.FormsMoveUpdate(Sender: TObject);
begin
  if Sender = aToAvail then TAction(Sender).Enabled := AnySelected(AutoCreateForms)
  else if Sender = aAllToAvail then TAction(Sender).Enabled := AutoCreateForms.Items.Count > 0
  else if Sender = aToAuto then TAction(Sender).Enabled := AnySelected(AvailableForms)
  else TAction(Sender).Enabled := AvailableForms.Items.Count > 0;
end;

{ a double click moves the form to the other list: the arrow button's action }
procedure TProjOptionsFrame.FormListDblClick(Sender: TObject);
begin
  if Sender = AutoCreateForms then aToAvail.Execute else aToAuto.Execute;
end;

{ the main form is the first form the program creates }
procedure TProjOptionsFrame.MainFormChange(Sender: TObject);
var
  I: Integer;
begin
  I := cbMainForm.ItemIndex;
  if I > 0 then
  begin
    AutoCreateForms.Items.Move(I, 0);
    SyncMain;
  end;
end;

{ ---------------------------------------------------------------- Application }

procedure TProjOptionsFrame.aLoadIconExecute(Sender: TObject);
var
  F: string;
begin
  F := '';
  if not BrowseFile('Application Icon', 'Icons (*.ico)|*.ico', F) then Exit;
  FIcon.Clear;
  FIcon.LoadFromFile(UsablePath(F));
  FIcon.Position := 0;
  IconImage.Picture.Icon.LoadFromStream(FIcon);
end;

{ the project's folder: where the dialog starts, a help file below it relative to it }
procedure TProjOptionsFrame.aBrowseHelpExecute(Sender: TObject);
begin
  BrowseFile(AppHelpFile, 'Application Help File', 'Help files (*.hlp;*.chm)|*.hlp;*.chm|All files (*.*)|*.*',
    bfOpenAny, '', '', ProjectBase);
end;

{ the folder relative names of the project's options start from ('' for the default options) }
function TProjOptionsFrame.ProjectBase: string;
begin
  if (FProject <> nil) and not FProject.IsDefaults then Result := FProject.Dir else Result := '';
end;

{ Target Windows is a Win32 program's: greyed for Win64 (a Win64 program is Unicode already) }
procedure TProjOptionsFrame.cbPlatformChange(Sender: TObject);
begin
  cbTargetWindows.Enabled := cbPlatform.ItemIndex = Ord(spWin32);
  if (cbPlatform.ItemIndex = Ord(spWin64)) and (Dcc64Exe = '') and not FUpdating then
    MessageBox(GetParentForm(Self).Handle, 'No RAD Studio with dcc64.exe (Delphi XE2 or later) is installed: a Win64 build ' +
      'cannot be compiled.', PChar(FTitle), MB_OK or MB_ICONINFORMATION);
end;

{ ---------------------------------------------------------------- Directories/Conditionals }

function TProjOptionsFrame.DirCombo(Sender: TObject): TComboBox;
begin
  if Sender = aDirOutput then Result := ddOutputDir
  else if Sender = aDirUnitOutput then Result := ddUnitOutput
  else if Sender = aDirBpl then Result := ddDPLOutputDir
  else if Sender = aDirDcp then Result := ddDCPOutputDir
  else if Sender = aListSearch then Result := ddSearchPath
  else if Sender = aListDebugSource then Result := ddDebugSourcePath
  else if Sender = aListConditionals then Result := ddConditionals
  else Result := ddUnitAliases;
end;

procedure TProjOptionsFrame.BrowseDirExecute(Sender: TObject);
begin
  BrowseFolder(DirCombo(Sender), 'Directory', ProjectBase);
end;

procedure TProjOptionsFrame.EditListExecute(Sender: TObject);
var
  Title: string;
begin
  if Sender = aListConditionals then Title := 'Conditional defines'
  else if Sender = aListAliases then Title := 'Unit aliases'
  else Title := 'Directories';
  EditPathListText(DirCombo(Sender), Title, (Sender = aListSearch) or (Sender = aListDebugSource), ProjectBase);
end;

{ a package: Delphi's package variant of the page - the BPL output folder takes the place of
  the output folder (a package makes no program) }
procedure TProjOptionsFrame.LayoutDirectories;
var
  DY: Integer;
begin
  if (FProject = nil) or not FProject.IsPackage then Exit;
  DY := ddDCPOutputDir.Top - ddDPLOutputDir.Top;
  ddDCPOutputDir.Top := ddDPLOutputDir.Top;
  bDCPOutputDir.Top := bDPLOutputDir.Top;
  drLabel2.Top := drLabel1.Top;
  ddDPLOutputDir.Top := ddOutputDir.Top;
  bDPLOutputDir.Top := bOutputDir.Top;
  drLabel1.Top := drLabel3.Top;
  ddOutputDir.Visible := False;
  bOutputDir.Visible := False;
  drLabel3.Visible := False;
  drGroupBox10.Height := drGroupBox10.Height - DY;
  drGroupBox11.Top := drGroupBox11.Top - DY;
  drGroupBox12.Top := drGroupBox12.Top - DY;
end;

{ ---------------------------------------------------------------- Version Info }

procedure TProjOptionsFrame.IncludeVerInfoClick(Sender: TObject);
var
  On: Boolean;

  procedure Enable(Parent: TWinControl);
  var
    K: Integer;
  begin
    for K := 0 to Parent.ControlCount - 1 do
    begin
      if Parent.Controls[K] = cbIncludeVerInfo then Continue;
      Parent.Controls[K].Enabled := On;
      if Parent.Controls[K] is TWinControl then Enable(TWinControl(Parent.Controls[K]));
    end;
  end;

begin
  { everything of the page but the check box itself }
  On := cbIncludeVerInfo.Checked;
  Enable(tsVersionInfo);
end;

function TProjOptionsFrame.VersionNums: string;
begin
  Result := Format('%d.%d.%d.%d', [StrToIntDef(Trim(MVN1.Text), 0), StrToIntDef(Trim(MVN2.Text), 0),
    StrToIntDef(Trim(MVN3.Text), 0), StrToIntDef(Trim(MVN4.Text), 0)]);
end;

{ the FileVersion key follows the version numbers, as in Delphi - when they change: the up-down
  controls set their edits' text again when their windows are made, and a FileVersion that differs
  from the numbers (an expert's) stays until the numbers are edited }
procedure TProjOptionsFrame.VersionChange(Sender: TObject);
var
  R: Integer;
  S: string;
begin
  if FUpdating then Exit;
  S := VersionNums;
  if S = FVersionNums then Exit;
  FVersionNums := S;
  for R := 1 to ValueGrid.RowCount - 1 do
    if SameText(ValueGrid.Cells[0, R], 'FileVersion') then
      ValueGrid.Cells[1, R] := S;
end;

{ Rename and Delete: Delete leaves one key (the grid keeps a row below its title) }
procedure TProjOptionsFrame.KeyDeleteUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := cbIncludeVerInfo.Checked and (ValueGrid.Row >= 1) and
    ((Sender = aKeyRename) or (ValueGrid.RowCount > 2));
end;

{ a version information's key no other row (than Row; 0 none) has }
function TProjOptionsFrame.KeyNameFree(const Name: string; Row: Integer): Boolean;
var
  L: TStringList;
  R: Integer;
begin
  L := TStringList.Create;
  try
    for R := 1 to ValueGrid.RowCount - 1 do L.Add(ValueGrid.Cells[0, R]);
    Result := PageNameFree(TForm(GetParentForm(Self)), L, Name, Row - 1, 'key');
  finally
    L.Free;
  end;
end;

procedure TProjOptionsFrame.aKeyAddExecute(Sender: TObject);
var
  S: string;
begin
  S := '';
  if not InputDialog(Self, 'Add Key', 'Key name:', S) or (Trim(S) = '') or not KeyNameFree(Trim(S), 0) then Exit;
  ValueGrid.RowCount := ValueGrid.RowCount + 1;
  ValueGrid.Cells[0, ValueGrid.RowCount - 1] := Trim(S);
  ValueGrid.Cells[1, ValueGrid.RowCount - 1] := '';
  ValueGrid.Row := ValueGrid.RowCount - 1;
end;

procedure TProjOptionsFrame.aKeyRenameExecute(Sender: TObject);
var
  S: string;
begin
  S := ValueGrid.Cells[0, ValueGrid.Row];
  if InputDialog(Self, 'Rename Key', 'Key name:', S) and (Trim(S) <> '') and KeyNameFree(Trim(S), ValueGrid.Row) then
    ValueGrid.Cells[0, ValueGrid.Row] := Trim(S);
end;

procedure TProjOptionsFrame.aKeyDeleteExecute(Sender: TObject);
var
  R, C: Integer;
begin
  for R := ValueGrid.Row to ValueGrid.RowCount - 2 do
    for C := 0 to 1 do ValueGrid.Cells[C, R] := ValueGrid.Cells[C, R + 1];
  ValueGrid.RowCount := ValueGrid.RowCount - 1;
end;

{ the column separators grey, in the title row too, and a grey line under the title row: the
  grid draws its lines in silver (and none around the title cells, whose fixed lines are left
  out), before its cells - the line right of each cell is drawn again over it, down through the
  row line below, and under a title cell the line below it }
procedure TProjOptionsFrame.ValueGridDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect;
  State: TGridDrawState);
var
  DC: HDC;
  W: Integer;
begin
  DC := ValueGrid.Canvas.Handle;
  W := ValueGrid.GridLineWidth;
  UIVLine(DC, Rect.Right, Rect.Top, Rect.Bottom + W, clBtnShadow);
  if ARow < ValueGrid.FixedRows then UIHLine(DC, Rect.Left, Rect.Right + W, Rect.Bottom, clBtnShadow);
end;

{ ---------------------------------------------------------------- Packages }

{ the name of a package without the version suffix of its .bpl (vcl70.bpl -> vcl, dclusr70.bpl
  -> dclusr): the run-time package's name, the name of its source }
function PackageBaseName(const BplFile: string): string;
begin
  Result := ChangeFileExt(ExtractFileName(BplFile), '');
  if (Length(Result) > 2) and (Result[Length(Result)] in ['0'..'9']) and (Result[Length(Result) - 1] in ['0'..'9']) then
    SetLength(Result, Length(Result) - 2);
end;

function PackageCaption(E: TPackageEntry): string;
begin
  Result := E.Description;
  if Result = '' then Result := ExtractFileName(E.FileName);
  if E.Enabled and not E.Loaded and (E.Error <> '') then Result := Result + '  (' + E.Error + ')';
end;

procedure TProjOptionsFrame.FillPackages(Select: TObject);
var
  I, N: Integer;
  E: TPackageEntry;
begin
  DesignPackageList.Items.BeginUpdate;
  try
    DesignPackageList.Items.Clear;
    for I := 0 to DesignHost.PackageCount - 1 do
    begin
      E := DesignHost.Packages[I];
      if E.BuiltIn then Continue;
      N := DesignPackageList.Items.AddObject(PackageCaption(E), E);
      DesignPackageList.Checked[N] := E.Enabled;
    end;
  finally
    DesignPackageList.Items.EndUpdate;
  end;
  N := DesignPackageList.Items.IndexOfObject(Select);
  if (N < 0) and (DesignPackageList.Items.Count > 0) then N := 0;
  DesignPackageList.ItemIndex := N;
  PackageClick(nil);
end;

procedure TProjOptionsFrame.PackageClick(Sender: TObject);
begin
  LabelPackageFile.Canvas.Font := LabelPackageFile.Font;       // measured as it is shown
  if DesignPackageList.ItemIndex >= 0 then
    LabelPackageFile.Caption := MinimizeName(TPackageEntry(DesignPackageList.Items.Objects[DesignPackageList.ItemIndex]).FileName,
      LabelPackageFile.Canvas, LabelPackageFile.Width)
  else
    LabelPackageFile.Caption := '';
end;

{ the check box loads or unloads the package at once; the list keeps it either way }
procedure TProjOptionsFrame.PackageClickCheck(Sender: TObject);
var
  E: TPackageEntry;
  Err: string;
begin
  if DesignPackageList.ItemIndex < 0 then Exit;
  E := TPackageEntry(DesignPackageList.Items.Objects[DesignPackageList.ItemIndex]);
  Screen.Cursor := crHourGlass;
  try
    if not DesignHost.EnablePackage(E, DesignPackageList.Checked[DesignPackageList.ItemIndex], Err) then
    begin
      Screen.Cursor := crDefault;
      MessageBox(GetParentForm(Self).Handle, PChar(Err), PChar(FTitle), MB_OK or MB_ICONERROR);
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  DesignHost.SavePackageList;
  FillPackages(E);
end;

{ a double click edits the package: Edit's action }
procedure TProjOptionsFrame.PackageDblClick(Sender: TObject);
begin
  aPkgEdit.Execute;
end;

{ Enabled is assigned once: a value set and taken back at every update repaints the buttons each
  time the application goes idle (every mouse move) }
procedure TProjOptionsFrame.PkgSelectedUpdate(Sender: TObject);
var
  Enable: Boolean;
begin
  Enable := DesignPackageList.ItemIndex >= 0;
  if Enable and (Sender = aPkgComponents) then
    Enable := TPackageEntry(DesignPackageList.Items.Objects[DesignPackageList.ItemIndex]).Loaded;
  TAction(Sender).Enabled := Enable;
end;

procedure TProjOptionsFrame.aPkgAddExecute(Sender: TObject);
var
  F, Err: string;
  E: TPackageEntry;
begin
  F := '';
  if not BrowseFile('Add Design Package', 'Design packages (*.bpl)|*.bpl|All files (*.*)|*.*', F, bfOpen, '',
    Settings.ReadString('Design Packages', 'LastDir', DelphiRoot + 'Projects\Bpl')) then Exit;
  Settings.WriteString('Design Packages', 'LastDir', ExtractFilePath(F));
  Screen.Cursor := crHourGlass;
  try
    E := DesignHost.InstallPackage(ExpandFileName(F), Err);
  finally
    Screen.Cursor := crDefault;
  end;
  DesignHost.SavePackageList;
  FillPackages(E);
  if (E = nil) or (Err <> '') then
    MessageBox(GetParentForm(Self).Handle, PChar(Format('%s cannot be installed.'#13#10#13#10'%s', [ExtractFileName(F), Err])),
      PChar(FTitle), MB_OK or MB_ICONERROR)
  else
    MessageBox(GetParentForm(Self).Handle, PChar(DesignHost.InstallReport(E)), PChar(FTitle), MB_OK or MB_ICONINFORMATION);
end;

procedure TProjOptionsFrame.aPkgRemoveExecute(Sender: TObject);
var
  E: TPackageEntry;
  Err: string;
begin
  E := TPackageEntry(DesignPackageList.Items.Objects[DesignPackageList.ItemIndex]);
  if MessageBox(GetParentForm(Self).Handle, PChar(Format('Remove %s?', [PackageCaption(E)])), PChar(FTitle),
    MB_YESNO or MB_ICONQUESTION) <> IDYES then Exit;
  Screen.Cursor := crHourGlass;
  try
    if not DesignHost.RemovePackage(E, Err) then
    begin
      Screen.Cursor := crDefault;
      MessageBox(GetParentForm(Self).Handle, PChar(Err), PChar(FTitle), MB_OK or MB_ICONERROR);
      FillPackages(E);
      Exit;
    end;
  finally
    Screen.Cursor := crDefault;
  end;
  DesignHost.SavePackageList;
  FillPackages(nil);
end;

{ Edit: the package's source, when it can be found (next to the .bpl, in the folders of the
  library path, in Delphi's Lib), is opened as the project after the dialog, as in Delphi }
procedure TProjOptionsFrame.aPkgEditExecute(Sender: TObject);
var
  E: TPackageEntry;
  Base, D, Found: string;
  L: TStringList;
  I: Integer;
begin
  if DesignPackageList.ItemIndex < 0 then Exit;
  E := TPackageEntry(DesignPackageList.Items.Objects[DesignPackageList.ItemIndex]);
  Base := PackageBaseName(E.FileName);
  Found := '';
  L := TStringList.Create;
  try
    AddPathList(L, ExtractFilePath(E.FileName) + ';' + EnvOptions.LibraryPath + ';' + DelphiRoot + 'Lib');
    for I := 0 to L.Count - 1 do
    begin
      D := IncludeTrailingPathDelimiter(L[I]) + Base + '.dpk';
      if FileExists(D) then
      begin
        Found := D;
        Break;
      end;
    end;
  finally
    L.Free;
  end;
  if Found = '' then
  begin
    MessageBox(GetParentForm(Self).Handle, PChar(Format('The source of %s (%s.dpk) was not found.', [ExtractFileName(E.FileName), Base])),
      PChar(FTitle), MB_OK or MB_ICONINFORMATION);
    Exit;
  end;
  PackageToEdit := Found;
  GetParentForm(Self).ModalResult := mrCancel;
end;

procedure TProjOptionsFrame.aPkgComponentsExecute(Sender: TObject);
var
  E: TPackageEntry;
  L: TStringList;
  I, Index: Integer;
begin
  E := TPackageEntry(DesignPackageList.Items.Objects[DesignPackageList.ItemIndex]);
  L := TStringList.Create;
  try
    DesignHost.GetPackageComponents(E, L);
    if L.Count = 0 then
    begin
      MessageBox(GetParentForm(Self).Handle, 'This package registers no components.', PChar(FTitle), MB_OK or MB_ICONINFORMATION);
      Exit;
    end;
    for I := 0 to L.Count - 1 do L[I] := L.Names[I] + '   (' + L.ValueFromIndex[I] + ')';
    Index := 0;
    ListDialog(Self, PackageCaption(E) + ' Components', L, Index);
  finally
    L.Free;
  end;
end;

procedure TProjOptionsFrame.RuntimeUpdate(Sender: TObject);
begin
  aRuntimeAdd.Enabled := RuntimePackages.Checked;
  EditPackages.Enabled := RuntimePackages.Checked;
end;

{ Add...: run-time packages by their .dcp (or .bpl) }
procedure TProjOptionsFrame.aRuntimeAddExecute(Sender: TObject);
var
  Files: TStringList;
  I: Integer;
  S, N: string;
begin
  Files := TStringList.Create;
  try
    if not BrowseFiles('Add Runtime Package', 'Packages (*.dcp;*.bpl)|*.dcp;*.bpl', Files, DelphiRoot + 'Lib') then Exit;
    S := Trim(EditPackages.Text);
    for I := 0 to Files.Count - 1 do
    begin
      if SameText(ExtractFileExt(Files[I]), '.bpl') then N := PackageBaseName(Files[I])
      else N := ChangeFileExt(ExtractFileName(Files[I]), '');
      if Pos(';' + LowerCase(N) + ';', ';' + LowerCase(S) + ';') > 0 then Continue;
      if S <> '' then S := S + ';';
      S := S + N;
    end;
    EditPackages.Text := S;
  finally
    Files.Free;
  end;
end;

{ ---------------------------------------------------------------- load and save }

procedure TProjOptionsFrame.LoadOptions(Project: TSdProject; const DprSource: string);
begin
  FProject := Project;
  FillLists;
  LoadValues(DprSource);
end;

{ a part of the version into its edit and up-down: an up-down holds 0 ... 32767 (a SmallInt) and
  writes its position into its edit when it gets its window - a larger part (a build number up to
  65535) keeps its edit to itself }
procedure VersionPart(UD: TUpDown; E: TMaskEdit; V: Integer);
begin
  E.Text := IntToStr(V);
  if (V >= UD.Min) and (V <= UD.Max) then UD.Position := V else UD.Associate := nil;
end;

procedure TProjOptionsFrame.LoadValues(const DprSource: string);
var
  P: TSdProject;
  OldClasses, OldVars, Keys: TStringList;
  I, K, V: Integer;
  HasSource: Boolean;
begin
  P := FProject;
  FUpdating := True;
  OldClasses := TStringList.Create;
  OldVars := TStringList.Create;
  Keys := TStringList.Create;
  try
    HasSource := not P.IsDefaults;
    if HasSource then FTitle := 'Project Options for ' + ExtractFileName(P.ExeName)
    else FTitle := 'Default Project Options';
    { Forms }
    if HasSource then
    begin
      DprGetCreateForms(DprSource, OldClasses, OldVars);
      AutoCreateForms.Items.Assign(OldVars);
      for I := 0 to P.UnitCount - 1 do
        if (P.Units[I].FormName <> '') and (OldVars.IndexOf(P.Units[I].FormName) < 0) and
          (Pos(LowerCase('{' + P.Units[I].FormName + ': tframe}'), LowerCase(DprSource)) = 0) then
          AvailableForms.Items.Add(P.Units[I].FormName);
    end;
    if AutoCreateForms.Items.Count > 0 then AutoCreateForms.Selected[0] := True;     // multi-select lists
    if AvailableForms.Items.Count > 0 then AvailableForms.Selected[0] := True;
    SyncMain;
    { Application }
    if HasSource then
    begin
      AppTitle.Text := DprGetAppProp(DprSource, 'Title');
      AppHelpFile.Text := DprGetAppProp(DprSource, 'HelpFile');
      if ProjectIcon(ChangeFileExt(P.FileName, '.res'), FIcon) then
      begin
        IconImage.Picture.Icon.LoadFromStream(FIcon);
        FIcon.Clear;                    // only a new icon is written back
      end;
    end;
    AppTitle.Enabled := HasSource;
    AppHelpFile.Enabled := HasSource;
    aLoadIcon.Enabled := HasSource;
    aBrowseHelp.Enabled := HasSource;
    AppFileExt.Text := P.OptStr(ThemeSection, 'TargetExt', '');
    cbPlatform.ItemIndex := Ord(P.Platform);
    chkThemes.Checked := P.OptInt(ThemeSection, ThemeKey, 1) <> 0;
    cbTargetWindows.ItemIndex := Ord(P.TargetWindows);
    { a library or a package runs in its host's process, whose manifest decides the DPI awareness
      and the execution level }
    cbDpiAwareness.ItemIndex := Ord(P.DpiAwareness);
    cbDpiAwareness.Enabled := not P.IsLibrary and not P.IsPackage;
    lblDpiAwareness.Enabled := cbDpiAwareness.Enabled;
    cbExecLevel.ItemIndex := Ord(P.ExecutionLevel);
    cbExecLevel.Enabled := cbDpiAwareness.Enabled;
    lblExecLevel.Enabled := cbDpiAwareness.Enabled;
    cbPlatformChange(nil);
    chkModernHeader.Checked := P.OptInt(ThemeSection, ModernHeaderKey, 1) <> 0;
    { Compiler }
    for I := Low(SwitchBoxes) to High(SwitchBoxes) do
      TCheckBox(FindComponent(SwitchBoxes[I][0])).Checked :=
        P.OptInt('Compiler', SwitchBoxes[I][1], CompilerSwitchDefault(SwitchBoxes[I][1][1])) <> 0;
    V := P.OptInt('Compiler', 'Y', CompilerSwitchDefault('Y'));     // 0 off, 1 definitions only, 2 full
    cbSymbolInfo.Checked := V <> 0;
    cbDefinitionsOnly.Checked := V = 1;
    { the check boxes of every page that are an option each }
    LoadCheckTable(Self, P, CheckBoxes);
    cbRecordAlign.ItemIndex := cbRecordAlign.Items.IndexOf(IntToStr(P.OptInt('Compiler', 'A', CompilerSwitchDefault('A'))));
    { Compiler Messages }
    for I := Low(CompilerWarnings) to High(CompilerWarnings) do
      WarningsList.Checked[I] := P.OptInt('Compiler', CompilerWarnings[I].Key, Ord(WarningOnByDefault(CompilerWarnings[I]))) <> 0;
    { Linker }
    case P.OptInt('Linker', 'MapFile', 0) of
      1: rbMapSegOnly.Checked := True;
      2: rbMapSegPubs.Checked := True;
      3: rbMapDetailed.Checked := True;
    else
      rbMapFileOff.Checked := True;
    end;
    case P.OptInt('Linker', 'OutputObjs', 0) of
      1: rbGenerateCObjs.Checked := True;
      2: rbGenerateCPPObjs.Checked := True;
    else
      rbGenerateBPUs.Checked := True;
    end;
    cbConsoleApp.Checked := P.OptInt('Linker', 'ConsoleApp', 1) = 0;
    ecStackSize.Text := IntToStr(P.OptInt('Linker', 'MinStackSize', 16384));
    ecMaxStackSize.Text := IntToStr(P.OptInt('Linker', 'MaxStackSize', 1048576));
    ecImageBase.Text := '$' + IntToHex(P.OptInt('Linker', 'ImageBase', $400000), 8);
    ecExeDescription.Text := P.OptStr('Linker', 'ExeDescription', '');
    { Directories/Conditionals }
    LoadComboTable(Self, P, DirCombos);
    LayoutDirectories;
    { Version Info }
    VersionPart(UD1, MVN1, P.OptInt('Version Info', 'MajorVer', 1));
    VersionPart(UD2, MVN2, P.OptInt('Version Info', 'MinorVer', 0));
    VersionPart(UD3, MVN3, P.OptInt('Version Info', 'Release', 0));
    VersionPart(UD4, MVN4, P.OptInt('Version Info', 'Build', 0));
    FVersionNums := VersionNums;
    K := LangID.Items.IndexOfObject(TObject(P.OptInt('Version Info', 'Locale', 1033)));
    LangID.ItemIndex := K;
    if P.Dof <> nil then P.Dof.ReadSectionValues('Version Info Keys', Keys);
    if Keys.Count = 0 then
      for I := Low(DefaultVersionKeys) to High(DefaultVersionKeys) do
      begin
        if DefaultVersionKeys[I] = 'FileVersion' then Keys.Add('FileVersion=' + VersionString(P))
        else if DefaultVersionKeys[I] = 'ProductVersion' then Keys.Add('ProductVersion=1.0.0.0')
        else Keys.Add(DefaultVersionKeys[I] + '=');
      end;
    ValueGrid.RowCount := Keys.Count + 1;
    for I := 0 to Keys.Count - 1 do
    begin
      ValueGrid.Cells[0, I + 1] := Keys.Names[I];
      ValueGrid.Cells[1, I + 1] := Keys.ValueFromIndex[I];
    end;
    IncludeVerInfoClick(nil);
    { Packages }
    FillPackages(nil);
    EditPackages.Text := P.OptStr('Directories', 'Packages', 'vcl;rtl');
  finally
    Keys.Free;
    OldClasses.Free;
    OldVars.Free;
    FUpdating := False;
  end;
end;

{ the class of P's form FormName as its .dfm declares it; 'T' + the name when the .dfm cannot tell }
function FormClassOf(P: TSdProject; const FormName: string): string;
var
  I: Integer;
  Text, N, C: string;
begin
  Result := 'T' + FormName;
  for I := 0 to P.UnitCount - 1 do
    if SameText(P.Units[I].FormName, FormName) then
    begin
      if ReadFormHeader(P.Units[I].FormFileName, Text, N, C) and (C <> '') then Result := C;
      Exit;
    end;
end;

procedure TProjOptionsFrame.SaveOptions(var DprSource: string);
var
  P: TSdProject;
  OldClasses, OldVars: TStringList;
  I, K, Map, Objs: Integer;
  Src, Cls: string;
begin
  P := FProject;
  { Compiler }
  for I := Low(SwitchBoxes) to High(SwitchBoxes) do
    P.SetOptInt('Compiler', SwitchBoxes[I][1], Ord(TCheckBox(FindComponent(SwitchBoxes[I][0])).Checked));
  if not cbSymbolInfo.Checked then P.SetOptInt('Compiler', 'Y', 0)
  else if cbDefinitionsOnly.Checked then P.SetOptInt('Compiler', 'Y', 1)
  else P.SetOptInt('Compiler', 'Y', 2);
  SaveCheckTable(Self, P, CheckBoxes);
  if cbRecordAlign.ItemIndex >= 0 then P.SetOptInt('Compiler', 'A', StrToInt(cbRecordAlign.Items[cbRecordAlign.ItemIndex]));
  { Compiler Messages }
  for I := Low(CompilerWarnings) to High(CompilerWarnings) do
    P.SetOptInt('Compiler', CompilerWarnings[I].Key, Ord(WarningsList.Checked[I]));
  { Linker }
  if rbMapSegOnly.Checked then Map := 1 else if rbMapSegPubs.Checked then Map := 2
  else if rbMapDetailed.Checked then Map := 3 else Map := 0;
  P.SetOptInt('Linker', 'MapFile', Map);
  if rbGenerateCObjs.Checked then Objs := 1 else if rbGenerateCPPObjs.Checked then Objs := 2 else Objs := 0;
  P.SetOptInt('Linker', 'OutputObjs', Objs);
  P.SetOptInt('Linker', 'ConsoleApp', Ord(not cbConsoleApp.Checked));
  P.SetOptInt('Linker', 'MinStackSize', StrToIntDef(Trim(ecStackSize.Text), 16384));
  P.SetOptInt('Linker', 'MaxStackSize', StrToIntDef(Trim(ecMaxStackSize.Text), 1048576));
  P.SetOptInt('Linker', 'ImageBase', StrToIntDef(Trim(ecImageBase.Text), $400000));
  P.SetOptStr('Linker', 'ExeDescription', Trim(ecExeDescription.Text));
  { Application (D7 Studio's own: themes, target extension, platform, Target Windows) and Linker's
    Modern program header }
  P.SetOptStr(ThemeSection, 'TargetExt', Trim(AppFileExt.Text));
  P.SetPlatform(TSdPlatform(cbPlatform.ItemIndex));
  P.SetOptInt(ThemeSection, ThemeKey, Ord(chkThemes.Checked));
  P.SetTargetWindows(TSdTargetWindows(cbTargetWindows.ItemIndex));
  if cbDpiAwareness.Enabled then
  begin
    P.SetDpiAwareness(TSdDpiAwareness(cbDpiAwareness.ItemIndex));
    P.SetExecutionLevel(TSdExecutionLevel(cbExecLevel.ItemIndex));
  end;
  P.SetOptInt(ThemeSection, ModernHeaderKey, Ord(chkModernHeader.Checked));
  { Directories/Conditionals }
  SaveComboTable(Self, P, DirCombos);
  { Version Info }
  P.SetOptInt('Version Info', 'MajorVer', StrToIntDef(Trim(MVN1.Text), 1));
  P.SetOptInt('Version Info', 'MinorVer', StrToIntDef(Trim(MVN2.Text), 0));
  P.SetOptInt('Version Info', 'Release', StrToIntDef(Trim(MVN3.Text), 0));
  P.SetOptInt('Version Info', 'Build', StrToIntDef(Trim(MVN4.Text), 0));
  if LangID.ItemIndex >= 0 then
  begin
    K := Integer(LangID.Items.Objects[LangID.ItemIndex]);
    P.SetOptInt('Version Info', 'Locale', K);
    { the code page of the language's ANSI texts }
    P.SetOptInt('Version Info', 'CodePage', StrToIntDef(GetLocaleStr(K, LOCALE_IDEFAULTANSICODEPAGE, '1252'), 1252));
  end;
  if P.Dof <> nil then
  begin
    P.Dof.EraseSection('Version Info Keys');
    for I := 1 to ValueGrid.RowCount - 1 do
      if Trim(ValueGrid.Cells[0, I]) <> '' then P.Dof.WriteString('Version Info Keys', Trim(ValueGrid.Cells[0, I]), ValueGrid.Cells[1, I]);
  end;
  { Packages (the design packages took effect at once) }
  P.SetOptStr('Directories', 'Packages', Trim(EditPackages.Text));
  P.SaveOptions;
  if chkDefault.Checked then P.SaveAsDefaults;
  if P.IsDefaults then Exit;
  { the icon (Load Icon) }
  if FIcon.Size > 0 then
    try
      SetProjectIcon(ChangeFileExt(P.FileName, '.res'), FIcon);
    except
      on E: Exception do MessageBox(GetParentForm(Self).Handle, PChar('The icon cannot be used: ' + E.Message), PChar(FTitle), MB_OK or MB_ICONERROR);
    end;
  { the project source: the forms it creates, the title and help file of the application }
  Src := DprSource;
  OldClasses := TStringList.Create;
  OldVars := TStringList.Create;
  try
    DprGetCreateForms(Src, OldClasses, OldVars);
    if AutoCreateForms.Items.Text <> OldVars.Text then
    begin
      for I := 0 to OldVars.Count - 1 do DprRemoveCreateForm(Src, OldVars[I]);
      for I := 0 to AutoCreateForms.Items.Count - 1 do
      begin
        K := OldVars.IndexOf(AutoCreateForms.Items[I]);
        if K >= 0 then Cls := OldClasses[K] else Cls := FormClassOf(P, AutoCreateForms.Items[I]);
        DprAddCreateForm(Src, Cls, AutoCreateForms.Items[I]);
      end;
    end;
  finally
    OldClasses.Free;
    OldVars.Free;
  end;
  if DprGetAppProp(Src, 'Title') <> AppTitle.Text then DprSetAppProp(Src, 'Title', AppTitle.Text);
  if DprGetAppProp(Src, 'HelpFile') <> AppHelpFile.Text then DprSetAppProp(Src, 'HelpFile', AppHelpFile.Text);
  DprSource := Src;
end;

end.
