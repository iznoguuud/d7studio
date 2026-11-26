{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdEnvOptionsFrame;

{ D7 Studio - Tools | Environment Options: Delphi 7's dialog, D7 Studio's additions on its pages
  (Preferences: Auto close on successful compile under Show compiler progress, User interface -
  the UI font, the zoom key; Designer: Show form positioner,
  Snap lines) and its own page Components. The values: SdEnvOptions, the form grid in
  DesignEnv. A frame: the section Environment Options of the Options dialog (SdOptionsDlg), its
  pages without tabs. The editor's options are a section of their own (SdEditorOptionsFrame). }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls,
  CheckLst, ActnList, SdEnvOptions, SdVarLists;

type
  TEnvOptionsFrame = class(TFrame)
    PageControl: TPageControl;
    tsPreferences: TTabSheet;
    AutoSave: TGroupBox;
    cbASEditor: TCheckBox;
    cbASDesktop: TCheckBox;
    Repository: TGroupBox;
    lbReposDir: TLabel;
    ecRepositoryDir: TEdit;
    RepositoryBtn: TButton;
    DockingBox: TGroupBox;
    DockHint: TLabel;
    cbAutoDragDocking: TCheckBox;
    DesktopContents: TRadioGroup;
    CompilingRunning: TGroupBox;
    cbShowProgress: TCheckBox;
    cbAutoCloseProgress: TCheckBox;
    cbWarnPackageRebuild: TCheckBox;
    cbMinimizeOnRun: TCheckBox;
    gbUserInterface: TGroupBox;
    lblUIFont: TLabel;
    cbUIFont: TComboBox;
    lblUIFontSize: TLabel;
    cbUIFontSize: TComboBox;
    lblRestartNote: TLabel;
    lblZoomKey: TLabel;
    cbZoomKey: TComboBox;
    lblDialogBackground: TLabel;
    cbDialogBackground: TComboBox;
    tsDesigner: TTabSheet;
    FormDesigner: TGroupBox;
    cbShowComponentCaptions: TCheckBox;
    cbShowDesignerHints: TCheckBox;
    cbShowExtendedControlHints: TCheckBox;
    cbShowFormPositioner: TCheckBox;
    cbPositionerSnap: TCheckBox;
    cbShowNonVisualComponents: TCheckBox;
    GridOptions: TGroupBox;
    lbGridSizeX: TLabel;
    lbGridSizeY: TLabel;
    lbGridSize: TLabel;
    cbDisplayGrid: TCheckBox;
    cbSnapToGrid: TCheckBox;
    ecGridSizeX: TEdit;
    ecGridSizeY: TEdit;
    udGridSizeX: TUpDown;
    udGridSizeY: TUpDown;
    SnapLineOptions: TGroupBox;
    lbSnapDistance: TLabel;
    lbSnapSpacing: TLabel;
    lbSnapMargin: TLabel;
    cbSnapLines: TCheckBox;
    ecSnapDistance: TEdit;
    udSnapDistance: TUpDown;
    ecSnapSpacing: TEdit;
    udSnapSpacing: TUpDown;
    ecSnapMargin: TEdit;
    udSnapMargin: TUpDown;
    ModuleCreationOptions: TGroupBox;
    cbDFMsAsText: TCheckBox;
    cbAutoCreateForms: TCheckBox;
    tsObjInsp: TTabSheet;
    oiLabel1: TLabel;
    gbOptions: TGroupBox;
    cbShowInstanceList: TCheckBox;
    cbShowClassnames: TCheckBox;
    cbShowStatusBar: TCheckBox;
    cbRenderBackgroundGrid: TCheckBox;
    cbIntegralHeight: TCheckBox;
    cbShowReadOnlyProps: TCheckBox;
    cbBoldNonDefault: TCheckBox;
    gbCompRefs: TGroupBox;
    cbReferenceExpandable: TCheckBox;
    cbReferenceOnEventsPage: TCheckBox;
    gbColors: TGroupBox;
    lbColors: TListBox;
    cbColorPicker: TColorBox;
    cbSpeedSettings: TComboBox;
    tsPalette: TTabSheet;
    PageLabel: TLabel;
    ToolLabel: TLabel;
    PageListBox: TListBox;
    AddButton: TButton;
    DeleteButton: TButton;
    RenameButton: TButton;
    ResetPaletteBtn: TButton;
    ToolListPanel: TPanel;
    ToolListHeader: THeaderControl;
    ToolListBox: TListBox;
    MoveUp: TButton;
    MoveDn: TButton;
    tsLibrary: TTabSheet;
    lbLabel3: TLabel;
    lbLabel16: TLabel;
    lbLabel17: TLabel;
    lbLabel2: TLabel;
    ecDLLOutput: TComboBox;
    ecDCPOutput: TComboBox;
    ecLibraryPath: TComboBox;
    bDirSearch: TButton;
    ecBrowsing: TComboBox;
    bBrowsing: TButton;
    bDPLOutput: TButton;
    bDCPOutput: TButton;
    tsExplorer: TTabSheet;
    exLabel2: TLabel;
    Sorting: TRadioGroup;
    OptionsBox: TGroupBox;
    ShowInEditor: TCheckBox;
    HighlightIncomplete: TCheckBox;
    exPropCheckBox1: TCheckBox;
    SyncEditor: TCheckBox;
    CompletionOptions: TGroupBox;
    CompleteProperties: TCheckBox;
    CategoryList: TCheckListBox;
    exPropRadioGroup1: TRadioGroup;
    exPropRadioGroup2: TRadioGroup;
    tsTypeLibrary: TTabSheet;
    OverridePanel: TGroupBox;
    PreDeclIDOverride: TCheckBox;
    ReservedOverride: TCheckBox;
    HiddenOverride: TCheckBox;
    CanCreateOverride: TCheckBox;
    OverrideCheck: TCheckBox;
    tlPropRadioGroup2: TRadioGroup;
    tsEnvVars: TTabSheet;
    VariableOptionsFrame: TPanel;
    frGroupBox1: TGroupBox;
    bAddOverride: TButton;
    frPanel1: TPanel;
    lvSystemVars: TListView;
    frGroupBox2: TGroupBox;
    bNew: TButton;
    bEdit: TButton;
    bDelete: TButton;
    lvUserVars: TListView;

    tsComponents: TTabSheet;
    gbCompView: TGroupBox;
    chkCompClassic: TCheckBox;
    chkCompCategories: TCheckBox;
    gbCompBar: TGroupBox;
    lblCompSort: TLabel;
    lblCompReset: TLabel;
    lblCompSeconds: TLabel;
    lblCompColor: TLabel;
    lblCompHotkey: TLabel;
    cbCompSort: TComboBox;
    edCompReset: TEdit;
    udCompReset: TUpDown;
    cbCompColor: TColorBox;
    hkComp: THotKey;
    lblCompNote: TLabel;
    Actions: TActionList;
    aBrowseRepository: TAction;
    aPageAdd: TAction;
    aPageDelete: TAction;
    aPageRename: TAction;
    aMoveUp: TAction;
    aMoveDown: TAction;
    aDefaultPages: TAction;
    aListLibrary: TAction;
    aListBrowsing: TAction;
    aDirBpl: TAction;
    aDirDcp: TAction;
    aVarOverride: TAction;
    aVarNew: TAction;
    aVarEdit: TAction;
    aVarDelete: TAction;
    procedure BrowseDirExecute(Sender: TObject);
    procedure EditListExecute(Sender: TObject);
    procedure aPageAddExecute(Sender: TObject);
    procedure aPageDeleteExecute(Sender: TObject);
    procedure aPageRenameExecute(Sender: TObject);
    procedure PaletteMoveExecute(Sender: TObject);
    procedure PaletteUpdate(Sender: TObject);
    procedure aDefaultPagesExecute(Sender: TObject);
    procedure ColorListClick(Sender: TObject);
    procedure ColorPickerChange(Sender: TObject);
    procedure SpeedSettingsChange(Sender: TObject);
    procedure OverrideClick(Sender: TObject);
    procedure ShowProgressClick(Sender: TObject);
    procedure PageListClick(Sender: TObject);
    procedure PaletteListEnter(Sender: TObject);
    procedure PageDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure PageDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure ToolDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure lvUserVarsDblClick(Sender: TObject);
    procedure CategoryListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure CategoryListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure CategoryListDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
    procedure CategoryListDragDrop(Sender, Source: TObject; X, Y: Integer);
    procedure CategoryListEndDrag(Sender, Target: TObject; X, Y: Integer);
    procedure CategoryListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FVars: TSdVarLists;             // the Environment Variables page and its commands (aVar...)
    FColors: array[TOIColor] of TColor;
    FPages: TStringList;            // palette pages; Objects: TStringList of class names
    FHidden: TStringList;           // components taken off the palette: Class=Page
    FPaletteChanged: Boolean;       // OK stores the layout of the page
    FDefaultPages: Boolean;         // ... Default Pages: OK drops the stored layout
    FToolsLast: Boolean;            // the component list was used last (not the pages)
    { Explorer: the categories' arrows (the folder starts open), their glyphs (collapsed,
      expanded: iiNodeCollapsed, iiNodeExpanded over the list's colour), the columns of a row as its drawing placed
      them - the arrow's from the check box's end, the text's - and the row a drag would move to
      (its dotted frame drawn; -1: none) }
    FExpExpand: array[TExpCategory] of Boolean;
    FExpGlyphs: array[Boolean] of TBitmap;
    FExpArrowLeft, FExpTextLeft: Integer;
    FExpDropRow: Integer;
    procedure FillLists;
    function ExpRowCategory(Index: Integer): TExpCategory;
    procedure ExpToggleExpand(Index: Integer);
    procedure ExpDropFrame(Row: Integer);
    function ExpCategoryHint(var Info: THintInfo): Boolean;
    procedure LoadPalette(const Layout: string);
    function PaletteText: string;
    procedure FillPages(Select: Integer);
    procedure FillTools;
    function PageClasses(Index: Integer): TStringList;
    function OnTools: Boolean;
    { component class Cls off the pages that have it; the first one's name ('' none) }
    function TakeClass(const Cls: string): string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the lists filled and the values shown, once, when the section is first shown; the values
      taken after OK }
    procedure LoadOptions;
    procedure SaveOptions;
  end;

implementation

uses
  Messages, SdUI, SdSettings, SdFormDesigner, SdDesignHost, SdDialogs, SdIcons, SdZoom;

{$R *.dfm}

type
  { the hints of the Explorer page's categories: "Visible" / "Hidden" over a row's check box,
    "Expanded" / "Collapsed" over its arrow (Delphi's CategoryListHint) }
  TCategoryHintHook = class(TUIWindowHook)
  private
    FFrame: TEnvOptionsFrame;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TCategoryHintHook.Hook(var Message: TMessage);
begin
  if Message.Msg = CM_HINTSHOW then
  begin
    if FFrame.ExpCategoryHint(PHintInfo(Message.LParam)^) then Message.Result := 0
    else Message.Result := 1;
    Exit;
  end;
  FOldProc(Message);
end;

const
  AllPages = '[All]';
  { the presets of Object Inspector | SpeedSettings: Default colors and settings, Delphi 5
    emulation, Visual Studio emulation (index 0 = custom) }
  PresetColors: array[1..3] of array[TOIColor] of TColor = (
    (clBtnFace, clBtnFace, clMaroon, clBtnText, clNavy, clNavy, clMaroon, clGrayText),
    (clBtnFace, clBtnFace, clBtnText, clBtnText, clNavy, clNavy, clNavy, clGrayText),
    (clWindow, clBtnFace, clBtnText, clWindowText, clWindowText, clWindowText, clWindowText, clGrayText));

{ ---------------------------------------------------------------- setup }

{ laid out for the UI font only: LoadOptions fills it when the section is first shown }
constructor TEnvOptionsFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  UIPrepareFrame(Self);
  { the frame of the palette's components (its header and list) one flat line, not the sunken edge }
  UIFlatBorder(ToolListPanel);
end;

{ a double click on an override edits it (the Edit command) }
procedure TEnvOptionsFrame.lvUserVarsDblClick(Sender: TObject);
begin
  aVarEdit.Execute;
end;

{ what Delphi fills in when its pages are created }
procedure TEnvOptionsFrame.FillLists;
var
  C: TOIColor;
  K: TSdWheelZoomKey;
begin
  FVars := TSdVarLists.Create(lvSystemVars, lvUserVars, aVarOverride, aVarNew, aVarEdit, aVarDelete);
  FPages := TStringList.Create;
  FHidden := TStringList.Create;
  for C := Low(TOIColor) to High(TOIColor) do lbColors.Items.Add(OIColorNames[C]);
  { Explorer: the arrows of the categories' rows; the rows' hints }
  FExpGlyphs[True] := IconBitmap(iiNodeExpanded, CategoryList.Color);
  FExpGlyphs[False] := IconBitmap(iiNodeCollapsed, CategoryList.Color);
  FExpDropRow := -1;
  TCategoryHintHook.Create(CategoryList, True).FFrame := Self;
  UIListHeader(ToolListBox, ToolListHeader);     // the columns scroll with the rows

  { Preferences | User interface: the UI font (default: the message font of the system), the
    keys that make the wheel zoom in the order of TSdWheelZoomKey (SdZoom) }
  FillFontChoice(cbUIFont, cbUIFontSize);
  for K := Low(TSdWheelZoomKey) to High(TSdWheelZoomKey) do cbZoomKey.Items.Add(WheelZoomKeyNames[K]);
end;

destructor TEnvOptionsFrame.Destroy;
var
  I: Integer;
begin
  FVars.Free;
  if FPages <> nil then                     // nil after a layout pass (UILayoutPass)
    for I := 0 to FPages.Count - 1 do FPages.Objects[I].Free;
  FPages.Free;
  FHidden.Free;
  FExpGlyphs[False].Free;
  FExpGlyphs[True].Free;
  inherited Destroy;
end;

{ ---------------------------------------------------------------- load and save }

procedure TEnvOptionsFrame.LoadOptions;
var
  E: TSdEnvOptions;
  I: Integer;
  C: TOIColor;
  Order: TExpCategories;
begin
  FillLists;
  E := EnvOptions;
  { Preferences }
  cbASEditor.Checked := E.AutosaveEditor;
  cbASDesktop.Checked := E.AutosaveDesktop;
  DesktopContents.ItemIndex := Ord(E.DesktopSymbols);
  cbAutoDragDocking.Checked := E.AutoDragDocking;
  cbShowProgress.Checked := E.ShowCompilerProgress;
  cbAutoCloseProgress.Checked := E.AutoCloseCompilerProgress;
  ShowProgressClick(nil);
  cbWarnPackageRebuild.Checked := E.WarnPackageRebuild;
  cbMinimizeOnRun.Checked := E.MinimizeOnRun;
  LoadFontChoice(cbUIFont, cbUIFontSize, 'FontName', 'FontSize');
  cbZoomKey.ItemIndex := Ord(WheelZoomKeyOf(Settings.ReadString('UI', 'ZoomKey', '')));
  if Settings.ReadInteger('UI', 'DialogBackground', 0) = 1 then cbDialogBackground.ItemIndex := 1
  else cbDialogBackground.ItemIndex := 0;
  ecRepositoryDir.Text := E.RepositoryDir;
  { Designer }
  cbDisplayGrid.Checked := DesignEnv.ShowGrid;
  cbSnapToGrid.Checked := DesignEnv.SnapToGrid;
  udGridSizeX.Position := DesignEnv.GridX;
  udGridSizeY.Position := DesignEnv.GridY;
  ecGridSizeX.Text := IntToStr(DesignEnv.GridX);
  ecGridSizeY.Text := IntToStr(DesignEnv.GridY);
  cbSnapLines.Checked := DesignEnv.SnapLines;
  udSnapDistance.Position := DesignEnv.SnapDistance;
  udSnapSpacing.Position := DesignEnv.SnapSpacing;
  udSnapMargin.Position := DesignEnv.SnapMargin;
  ecSnapDistance.Text := IntToStr(DesignEnv.SnapDistance);
  ecSnapSpacing.Text := IntToStr(DesignEnv.SnapSpacing);
  ecSnapMargin.Text := IntToStr(DesignEnv.SnapMargin);
  cbShowComponentCaptions.Checked := DesignEnv.ShowCaptions;
  cbShowDesignerHints.Checked := E.ShowDesignerHints;
  cbShowExtendedControlHints.Checked := E.ShowExtendedHints;
  cbShowFormPositioner.Checked := DesignEnv.ShowPositioner;
  cbPositionerSnap.Checked := DesignEnv.PositionerSnap;
  cbDFMsAsText.Checked := E.NewFormsAsText;
  cbAutoCreateForms.Checked := E.AutoCreateForms;
  { Object Inspector }
  cbShowInstanceList.Checked := E.OIShowInstanceList;
  cbShowClassnames.Checked := E.OIShowClassNames;
  cbShowStatusBar.Checked := E.OIShowStatusBar;
  cbRenderBackgroundGrid.Checked := E.OIRenderGrid;
  cbIntegralHeight.Checked := E.OIIntegralHeight;
  cbShowReadOnlyProps.Checked := E.OIShowReadOnly;
  cbBoldNonDefault.Checked := E.OIBoldNonDefault;
  cbReferenceExpandable.Checked := E.OIRefExpand;
  cbReferenceOnEventsPage.Checked := E.OIRefOnEvents;
  for C := Low(TOIColor) to High(TOIColor) do FColors[C] := E.OIColors[C];
  cbSpeedSettings.ItemIndex := E.OISpeedSetting;
  lbColors.ItemIndex := 0;
  ColorListClick(nil);
  { Palette }
  LoadPalette(DesignHost.PaletteLayout);
  { Library }
  LoadHistory(Settings, 'hlLibraryPath', ecLibraryPath.Items);
  LoadHistory(Settings, 'hlDPLOutput', ecDLLOutput.Items);
  LoadHistory(Settings, 'hlDCPOutput', ecDCPOutput.Items);
  LoadHistory(Settings, 'hIBrowsingPath', ecBrowsing.Items);
  ecLibraryPath.Text := E.LibraryPath;
  ecDLLOutput.Text := E.BplOutputDir;
  ecDCPOutput.Text := E.DcpOutputDir;
  ecBrowsing.Text := E.BrowsingPath;
  { Explorer }
  ShowInEditor.Checked := E.ExAutoShow;
  HighlightIncomplete.Checked := E.ExHighlightIncomplete;
  exPropCheckBox1.Checked := E.ExShowSyntax;
  SyncEditor.Checked := E.ExSyncEditor;
  Sorting.ItemIndex := Ord(not E.ExSortAlpha);
  CompleteProperties.Checked := E.ExFinishProperties;
  exPropRadioGroup1.ItemIndex := E.ExBrowserView;
  exPropRadioGroup2.ItemIndex := E.ExBrowserScope;
  { the categories in their order: checked - a folder; the arrow - the folder starts open }
  Order := ExpSortedCategories(E.ExCategorySort);
  CategoryList.Items.BeginUpdate;
  try
    CategoryList.Items.Clear;
    for I := 0 to High(Order) do
    begin
      CategoryList.Items.AddObject(ExpCategoryLabels[Order[I]], TObject(Ord(Order[I])));
      CategoryList.Checked[I] := E.ExVisible[Order[I]];
      FExpExpand[Order[I]] := E.ExExpand[Order[I]];
    end;
  finally
    CategoryList.Items.EndUpdate;
  end;
  { Type Library }
  tlPropRadioGroup2.ItemIndex := E.TLSafeCall;
  OverrideCheck.Checked := E.TLIgnoreFlags;
  PreDeclIDOverride.Checked := E.TLFlags[0];
  ReservedOverride.Checked := E.TLFlags[1];
  HiddenOverride.Checked := E.TLFlags[2];
  CanCreateOverride.Checked := E.TLFlags[3];
  OverrideClick(nil);
  { Environment Variables }
  FVars.Fill(E.VarOverrides);
  { Components }
  chkCompClassic.Checked := E.CompClassic;
  chkCompCategories.Checked := not E.CompHideCategory;
  cbCompSort.ItemIndex := E.CompSort;
  udCompReset.Position := E.CompResetDelay;
  cbCompColor.Selected := E.CompColor;
  hkComp.HotKey := E.CompHotkey;
end;

procedure TEnvOptionsFrame.SaveOptions;
var
  E: TSdEnvOptions;
  I: Integer;
  C: TOIColor;
  Order: TExpCategories;
  X: TExpCategory;
begin
  E := EnvOptions;
  E.AutosaveEditor := cbASEditor.Checked;
  E.AutosaveDesktop := cbASDesktop.Checked;
  E.DesktopSymbols := DesktopContents.ItemIndex = 1;
  E.AutoDragDocking := cbAutoDragDocking.Checked;
  E.ShowCompilerProgress := cbShowProgress.Checked;
  E.AutoCloseCompilerProgress := cbAutoCloseProgress.Checked;
  E.WarnPackageRebuild := cbWarnPackageRebuild.Checked;
  E.MinimizeOnRun := cbMinimizeOnRun.Checked;
  SaveFontChoice(cbUIFont, cbUIFontSize, 'FontName', 'FontSize');
  if cbZoomKey.ItemIndex >= 0 then
    Settings.WriteString('UI', 'ZoomKey', WheelZoomKeyKeys[TSdWheelZoomKey(cbZoomKey.ItemIndex)]);
  if cbDialogBackground.ItemIndex >= 0 then Settings.WriteInteger('UI', 'DialogBackground', cbDialogBackground.ItemIndex);
  E.RepositoryDir := Trim(ecRepositoryDir.Text);
  DesignEnv.ShowGrid := cbDisplayGrid.Checked;
  DesignEnv.SnapToGrid := cbSnapToGrid.Checked;
  DesignEnv.GridX := StrToIntDef(ecGridSizeX.Text, 8);
  DesignEnv.GridY := StrToIntDef(ecGridSizeY.Text, 8);
  if DesignEnv.GridX < 2 then DesignEnv.GridX := 2;
  if DesignEnv.GridY < 2 then DesignEnv.GridY := 2;
  DesignEnv.SnapLines := cbSnapLines.Checked;
  DesignEnv.SnapDistance := StrToIntDef(ecSnapDistance.Text, DefSnapDistance);
  DesignEnv.SnapSpacing := StrToIntDef(ecSnapSpacing.Text, DefSnapSpacing);
  DesignEnv.SnapMargin := StrToIntDef(ecSnapMargin.Text, DefSnapMargin);
  if DesignEnv.SnapDistance < 1 then DesignEnv.SnapDistance := 1;
  if DesignEnv.SnapSpacing < 0 then DesignEnv.SnapSpacing := 0;
  if DesignEnv.SnapMargin < 0 then DesignEnv.SnapMargin := 0;
  DesignEnv.ShowCaptions := cbShowComponentCaptions.Checked;
  E.ShowDesignerHints := cbShowDesignerHints.Checked;
  E.ShowExtendedHints := cbShowExtendedControlHints.Checked;
  DesignEnv.ShowPositioner := cbShowFormPositioner.Checked;
  DesignEnv.PositionerSnap := cbPositionerSnap.Checked;
  E.NewFormsAsText := cbDFMsAsText.Checked;
  E.AutoCreateForms := cbAutoCreateForms.Checked;
  E.OIShowInstanceList := cbShowInstanceList.Checked;
  E.OIShowClassNames := cbShowClassnames.Checked;
  E.OIShowStatusBar := cbShowStatusBar.Checked;
  E.OIRenderGrid := cbRenderBackgroundGrid.Checked;
  E.OIIntegralHeight := cbIntegralHeight.Checked;
  E.OIShowReadOnly := cbShowReadOnlyProps.Checked;
  E.OIBoldNonDefault := cbBoldNonDefault.Checked;
  E.OIRefExpand := cbReferenceExpandable.Checked;
  E.OIRefOnEvents := cbReferenceOnEventsPage.Checked;
  for C := Low(TOIColor) to High(TOIColor) do E.OIColors[C] := FColors[C];
  E.OISpeedSetting := cbSpeedSettings.ItemIndex;
  if FPaletteChanged then DesignHost.SetPaletteLayout(PaletteText)
  else if FDefaultPages then DesignHost.SetPaletteLayout('');
  E.LibraryPath := Trim(ecLibraryPath.Text);
  E.BplOutputDir := Trim(ecDLLOutput.Text);
  E.DcpOutputDir := Trim(ecDCPOutput.Text);
  E.BrowsingPath := Trim(ecBrowsing.Text);
  AddHistory(Settings, 'hlLibraryPath', E.LibraryPath);
  AddHistory(Settings, 'hlDPLOutput', E.BplOutputDir);
  AddHistory(Settings, 'hlDCPOutput', E.DcpOutputDir);
  AddHistory(Settings, 'hIBrowsingPath', E.BrowsingPath);
  E.ExAutoShow := ShowInEditor.Checked;
  E.ExHighlightIncomplete := HighlightIncomplete.Checked;
  E.ExShowSyntax := exPropCheckBox1.Checked;
  E.ExSyncEditor := SyncEditor.Checked;
  E.ExSortAlpha := Sorting.ItemIndex <> 1;
  E.ExFinishProperties := CompleteProperties.Checked;
  E.ExBrowserView := exPropRadioGroup1.ItemIndex;
  E.ExBrowserScope := exPropRadioGroup2.ItemIndex;
  SetLength(Order, CategoryList.Items.Count);
  for I := 0 to CategoryList.Items.Count - 1 do
  begin
    X := ExpRowCategory(I);
    Order[I] := X;
    E.ExVisible[X] := CategoryList.Checked[I];
    E.ExExpand[X] := FExpExpand[X];
  end;
  E.ExCategorySort := ExpSortText(ExpSortedCategories(ExpSortText(Order)));
  E.TLSafeCall := tlPropRadioGroup2.ItemIndex;
  E.TLIgnoreFlags := OverrideCheck.Checked;
  E.TLFlags[0] := PreDeclIDOverride.Checked;
  E.TLFlags[1] := ReservedOverride.Checked;
  E.TLFlags[2] := HiddenOverride.Checked;
  E.TLFlags[3] := CanCreateOverride.Checked;
  FVars.GetOverrides(E.VarOverrides);
  E.CompClassic := chkCompClassic.Checked;
  E.CompHideCategory := not chkCompCategories.Checked;
  if cbCompSort.ItemIndex >= 0 then E.CompSort := cbCompSort.ItemIndex;
  E.CompResetDelay := udCompReset.Position;
  E.CompColor := cbCompColor.Selected;
  E.CompHotkey := hkComp.HotKey;
  E.Save;
  E.ApplyVariables;
end;

{ ---------------------------------------------------------------- shared commands }

{ "..." of a folder: Browse (Repository), the BPL and DCP output folders }
procedure TEnvOptionsFrame.BrowseDirExecute(Sender: TObject);
var
  Box: TControl;
begin
  if Sender = aBrowseRepository then Box := ecRepositoryDir
  else if Sender = aDirBpl then Box := ecDLLOutput
  else Box := ecDCPOutput;
  BrowseFolder(Box, 'Directory', '');
end;

{ "..." of a path list: Library path, Browsing path }
procedure TEnvOptionsFrame.EditListExecute(Sender: TObject);
begin
  if Sender = aListLibrary then EditPathListText(ecLibraryPath, 'Directories', True, '')
  else EditPathListText(ecBrowsing, 'Directories', True, '');
end;

{ ---------------------------------------------------------------- Object Inspector colours }

procedure TEnvOptionsFrame.ColorListClick(Sender: TObject);
begin
  if lbColors.ItemIndex >= 0 then cbColorPicker.Selected := FColors[TOIColor(lbColors.ItemIndex)];
end;

procedure TEnvOptionsFrame.ColorPickerChange(Sender: TObject);
begin
  if lbColors.ItemIndex < 0 then Exit;
  FColors[TOIColor(lbColors.ItemIndex)] := cbColorPicker.Selected;
  cbSpeedSettings.ItemIndex := 0;           // custom
end;

procedure TEnvOptionsFrame.SpeedSettingsChange(Sender: TObject);
var
  C: TOIColor;
  K: Integer;
begin
  K := cbSpeedSettings.ItemIndex;
  if (K < 1) or (K > 3) then Exit;
  for C := Low(TOIColor) to High(TOIColor) do FColors[C] := PresetColors[K][C];
  cbRenderBackgroundGrid.Checked := K <> 2;
  cbBoldNonDefault.Checked := K = 1;
  ColorListClick(nil);
  cbSpeedSettings.ItemIndex := K;
end;

procedure TEnvOptionsFrame.OverrideClick(Sender: TObject);
begin
  PreDeclIDOverride.Enabled := OverrideCheck.Checked;
  ReservedOverride.Enabled := OverrideCheck.Checked;
  HiddenOverride.Enabled := OverrideCheck.Checked;
  CanCreateOverride.Enabled := OverrideCheck.Checked;
end;

{ Auto close belongs to the Compiling dialog: without compiler progress there is none to close }
procedure TEnvOptionsFrame.ShowProgressClick(Sender: TObject);
begin
  cbAutoCloseProgress.Enabled := cbShowProgress.Checked;
end;

{ ---------------------------------------------------------------- Palette }

procedure TEnvOptionsFrame.LoadPalette(const Layout: string);
var
  L, C: TStringList;
  I, K, J: Integer;
  PageName: string;
begin
  for I := 0 to FPages.Count - 1 do FPages.Objects[I].Free;
  FPages.Clear;
  FHidden.Clear;
  L := TStringList.Create;
  C := TStringList.Create;
  try
    L.Text := Layout;
    C.Text := StringReplace(L.Values['.Order'], ';', #13#10, [rfReplaceAll]);
    for I := 0 to C.Count - 1 do
      if Trim(C[I]) <> '' then FPages.AddObject(Trim(C[I]), TStringList.Create);
    for I := 0 to L.Count - 1 do
    begin
      if (L.Names[I] = '') or (L.Names[I][1] = '.') then Continue;
      C.Text := StringReplace(L.ValueFromIndex[I], ';', #13#10, [rfReplaceAll]);
      K := Pos('.Hidden', L.Names[I]);
      if (K > 0) and (K = Length(L.Names[I]) - 6) then
      begin
        PageName := Copy(L.Names[I], 1, K - 1);
        for J := 0 to C.Count - 1 do
          if Trim(C[J]) <> '' then FHidden.Add(Trim(C[J]) + '=' + PageName);
      end
      else
      begin
        K := FPages.IndexOf(L.Names[I]);
        if K < 0 then K := FPages.AddObject(L.Names[I], TStringList.Create);
        for J := 0 to C.Count - 1 do
          if Trim(C[J]) <> '' then TStringList(FPages.Objects[K]).Add(Trim(C[J]));
      end;
    end;
  finally
    C.Free;
    L.Free;
  end;
  FillPages(0);
end;

function TEnvOptionsFrame.PaletteText: string;
var
  I, J: Integer;
  Order, S, H: string;
begin
  Order := '';
  Result := '';
  for I := 0 to FPages.Count - 1 do
  begin
    Order := Order + FPages[I] + ';';
    S := '';
    for J := 0 to TStringList(FPages.Objects[I]).Count - 1 do S := S + TStringList(FPages.Objects[I])[J] + ';';
    Result := Result + FPages[I] + '=' + S + #13#10;
    H := '';
    for J := 0 to FHidden.Count - 1 do
      if SameText(FHidden.ValueFromIndex[J], FPages[I]) then H := H + FHidden.Names[J] + ';';
    if H <> '' then Result := Result + FPages[I] + '.Hidden=' + H + #13#10;
  end;
  Result := '.Order=' + Order + #13#10 + Result;
end;

{ the pages; [All] first, as in Delphi }
procedure TEnvOptionsFrame.FillPages(Select: Integer);
begin
  PageListBox.Items.BeginUpdate;
  try
    PageListBox.Items.Assign(FPages);
    PageListBox.Items.Insert(0, AllPages);
  finally
    PageListBox.Items.EndUpdate;
  end;
  if Select >= PageListBox.Items.Count then Select := PageListBox.Items.Count - 1;
  PageListBox.ItemIndex := Select;
  FillTools;
end;

{ the classes of a page of the list (Index of PageListBox; [All] = nil) }
function TEnvOptionsFrame.PageClasses(Index: Integer): TStringList;
begin
  if Index <= 0 then Result := nil else Result := TStringList(FPages.Objects[Index - 1]);
end;

procedure TEnvOptionsFrame.FillTools;
var
  I, J: Integer;
  L: TStringList;
begin
  ToolListBox.Items.BeginUpdate;
  try
    ToolListBox.Items.Clear;
    L := PageClasses(PageListBox.ItemIndex);
    if L <> nil then
    begin
      ToolListBox.Items.Assign(L);
      { the components taken off this page, greyed }
      for J := 0 to FHidden.Count - 1 do
        if SameText(FHidden.ValueFromIndex[J], PageListBox.Items[PageListBox.ItemIndex]) then
          ToolListBox.Items.Add(FHidden.Names[J]);
    end
    else
    begin
      for I := 0 to FPages.Count - 1 do ToolListBox.Items.AddStrings(TStringList(FPages.Objects[I]));
      for J := 0 to FHidden.Count - 1 do ToolListBox.Items.Add(FHidden.Names[J]);
    end;
  finally
    ToolListBox.Items.EndUpdate;
  end;
  { [All]: Default Pages instead of the move buttons, as in Delphi }
  ResetPaletteBtn.Visible := PageListBox.ItemIndex <= 0;
  MoveUp.Visible := not ResetPaletteBtn.Visible;
  MoveDn.Visible := not ResetPaletteBtn.Visible;
end;

procedure TEnvOptionsFrame.PageListClick(Sender: TObject);
begin
  FillTools;
end;

procedure TEnvOptionsFrame.ToolDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  C: TCanvas;
  Item: TPaletteItem;
  B: TBitmap;
  X, I, Y, Ofs: Integer;
  Cols: array[0..2] of string;
begin
  C := ToolListBox.Canvas;
  C.FillRect(Rect);
  Item := DesignHost.FindItem(ToolListBox.Items[Index]);
  if Item <> nil then
  begin
    B := DesignHost.ItemBitmap(Item);
    if B <> nil then C.Draw(Rect.Left + 2, Rect.Top + (Rect.Bottom - Rect.Top - B.Height) div 2, B);
  end;
  if FHidden.IndexOfName(ToolListBox.Items[Index]) >= 0 then C.Font.Color := clGrayText;
  Cols[0] := ToolListBox.Items[Index];
  if Item <> nil then Cols[1] := DesignHost.ItemPackageName(Item) else Cols[1] := '';
  if Item <> nil then Cols[2] := Item.Page else Cols[2] := '';
  X := Rect.Left;
  Y := Rect.Top + (Rect.Bottom - Rect.Top - C.TextHeight('Wg')) div 2;
  for I := 0 to 2 do
  begin
    if I = 0 then Ofs := 30 else Ofs := 2;
    C.TextOut(X + Ofs, Y, Cols[I]);
    UIListRowWidth(ToolListBox, X + Ofs + C.TextWidth(Cols[I]));
    if I < ToolListHeader.Sections.Count then Inc(X, ToolListHeader.Sections[I].Width);
  end;
end;

procedure TEnvOptionsFrame.aPageAddExecute(Sender: TObject);
var
  S: string;
  K: Integer;
begin
  S := '';
  if not InputDialog(Self, 'Add Page', 'Page name:', S) or (Trim(S) = '') then Exit;
  if not PageNameFree(TForm(GetParentForm(Self)), FPages, Trim(S), -1) then Exit;
  { after the selected page }
  K := PageListBox.ItemIndex;
  if K < 1 then K := FPages.Count;
  FPages.InsertObject(K, Trim(S), TStringList.Create);
  FPaletteChanged := True;
  FillPages(K + 1);
end;

{ the list the commands act on: the one used last - the buttons take the focus when clicked }
procedure TEnvOptionsFrame.PaletteListEnter(Sender: TObject);
begin
  FToolsLast := Sender = ToolListBox;
end;

{ Delete, Move Up and Move Down act on the component chosen when the component list was used
  last, else on the page }
function TEnvOptionsFrame.OnTools: Boolean;
begin
  Result := FToolsLast and (ToolListBox.ItemIndex >= 0);
end;

{ a component moves among the page's own (the greyed ones it lost stay below them); [All] and
  the components of [All] do not move }
procedure TEnvOptionsFrame.PaletteUpdate(Sender: TObject);
var
  L: TStringList;
begin
  L := PageClasses(PageListBox.ItemIndex);
  if Sender = aPageRename then aPageRename.Enabled := PageListBox.ItemIndex > 0
  else if Sender = aPageDelete then aPageDelete.Enabled := OnTools or (PageListBox.ItemIndex > 0)
  else if OnTools then
    TAction(Sender).Enabled := (L <> nil) and CanMoveListRow(ToolListBox, Sender = aMoveUp, 0, L.Count - 1)
  else
    TAction(Sender).Enabled := CanMoveListRow(PageListBox, Sender = aMoveUp, 1);
end;

{ Delete: the selected component comes off the palette (or back on), an empty page goes }
function TEnvOptionsFrame.TakeClass(const Cls: string): string;
var
  K: Integer;
  L: TStringList;
begin
  Result := '';
  for K := 0 to FPages.Count - 1 do
  begin
    L := TStringList(FPages.Objects[K]);
    if L.IndexOf(Cls) < 0 then Continue;
    L.Delete(L.IndexOf(Cls));
    if Result = '' then Result := FPages[K];
  end;
end;

procedure TEnvOptionsFrame.aPageDeleteExecute(Sender: TObject);
var
  Cls, Page: string;
  K: Integer;
begin
  if OnTools then
  begin
    Cls := ToolListBox.Items[ToolListBox.ItemIndex];
    K := FHidden.IndexOfName(Cls);
    if K >= 0 then
    begin
      { a hidden one comes back onto its page }
      Page := FHidden.ValueFromIndex[K];
      FHidden.Delete(K);
      K := FPages.IndexOf(Page);
      if K < 0 then K := FPages.AddObject(Page, TStringList.Create);
      TStringList(FPages.Objects[K]).Add(Cls);
    end
    else
    begin
      Page := TakeClass(Cls);
      if Page <> '' then FHidden.Add(Cls + '=' + Page);
    end;
    FPaletteChanged := True;
    FillTools;
    Exit;
  end;
  K := PageListBox.ItemIndex - 1;
  if K < 0 then Exit;
  if TStringList(FPages.Objects[K]).Count > 0 then
  begin
    MessageBox(GetParentForm(Self).Handle, 'The page contains components. Move or delete them first.', 'Options',
      MB_OK or MB_ICONINFORMATION);
    Exit;
  end;
  FPages.Objects[K].Free;
  FPages.Delete(K);
  FPaletteChanged := True;
  FillPages(K);
end;

procedure TEnvOptionsFrame.aPageRenameExecute(Sender: TObject);
var
  S: string;
  K, J: Integer;
begin
  K := PageListBox.ItemIndex - 1;
  if K < 0 then Exit;
  S := FPages[K];
  if not InputDialog(Self, 'Rename Page', 'Page name:', S) or (Trim(S) = '') then Exit;
  if not PageNameFree(TForm(GetParentForm(Self)), FPages, Trim(S), K) then Exit;
  for J := 0 to FHidden.Count - 1 do
    if SameText(FHidden.ValueFromIndex[J], FPages[K]) then FHidden[J] := FHidden.Names[J] + '=' + Trim(S);
  FPages[K] := Trim(S);
  FPaletteChanged := True;
  FillPages(K + 1);
end;

procedure TEnvOptionsFrame.PaletteMoveExecute(Sender: TObject);
var
  I: Integer;
  L: TStringList;
begin
  if OnTools then
  begin
    L := PageClasses(PageListBox.ItemIndex);
    if L = nil then Exit;
    I := MoveListRow(ToolListBox, Sender = aMoveUp, 0, L.Count - 1);
    if I < 0 then Exit;
    L.Exchange(I, ToolListBox.ItemIndex);
  end
  else
  begin
    { the list's row 0 is [All]: FPages is one behind it }
    I := MoveListRow(PageListBox, Sender = aMoveUp, 1);
    if I < 0 then Exit;
    FPages.Exchange(I - 1, PageListBox.ItemIndex - 1);
  end;
  FPaletteChanged := True;
end;

{ the pages as the packages register them, shown now; OK drops the stored layout (Cancel keeps
  it). Only DesignHost knows the registered arrangement: it is arranged without the stored
  layout for a moment and gets that back at once. }
{ the registered arrangement in the dialog; OK applies it (Cancel leaves the user's) }
procedure TEnvOptionsFrame.aDefaultPagesExecute(Sender: TObject);
begin
  LoadPalette(DesignHost.DefaultPaletteLayout);
  FPaletteChanged := False;
  FDefaultPages := True;
end;

{ a component dragged onto a page moves there }
procedure TEnvOptionsFrame.PageDragOver(Sender, Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
  Accept := (Source = ToolListBox) and (PageListBox.ItemAtPos(Point(X, Y), True) > 0);
end;

procedure TEnvOptionsFrame.PageDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  Target, I: Integer;
  Cls: string;
begin
  Target := PageListBox.ItemAtPos(Point(X, Y), True);
  if (Target <= 0) or (ToolListBox.ItemIndex < 0) then Exit;
  Cls := ToolListBox.Items[ToolListBox.ItemIndex];
  TakeClass(Cls);
  { a component taken off the palette comes back onto the page it is dropped on }
  I := FHidden.IndexOfName(Cls);
  if I >= 0 then FHidden.Delete(I);
  TStringList(FPages.Objects[Target - 1]).Add(Cls);
  FPaletteChanged := True;
  FillTools;
end;

{ ---------------------------------------------------------------- Explorer: the categories }

{ Delphi 7's list (TModuleExplorerPage): a row's check box makes the category a folder, its arrow
  says whether the folder starts open (a click on it, Left or Right), a drag of its text moves it
  (the order of the folders); the four visibility categories in bold }

function TEnvOptionsFrame.ExpRowCategory(Index: Integer): TExpCategory;
begin
  Result := TExpCategory(Integer(CategoryList.Items.Objects[Index]));
end;

{ after the list's check box: the arrow 1 px on, the text's ground 1 px after the arrow, the text
  2 px into it (at 96 DPI; an integral scale for higher rows) }
procedure TEnvOptionsFrame.CategoryListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  C: TCanvas;
  S, GX, GY: Integer;
  X: TExpCategory;
  G: TBitmap;
  T: TRect;
  Text: string;
begin
  C := CategoryList.Canvas;
  X := ExpRowCategory(Index);
  Text := CategoryList.Items[Index];
  S := (Rect.Bottom - Rect.Top) div 16;
  if S < 1 then S := 1;
  FExpArrowLeft := Rect.Left;
  GX := Rect.Left + S;
  FExpTextLeft := GX + 17 * S;
  C.Brush.Style := bsSolid;
  C.Brush.Color := CategoryList.Color;
  C.FillRect(Classes.Rect(Rect.Left, Rect.Top, FExpTextLeft, Rect.Bottom));
  G := FExpGlyphs[FExpExpand[X]];
  if (G <> nil) and (G.Width > 0) then
  begin
    GY := Rect.Top + (Rect.Bottom - Rect.Top - G.Height * S) div 2;
    C.StretchDraw(Classes.Rect(GX, GY, GX + G.Width * S, GY + G.Height * S), G);
  end;
  T := Classes.Rect(FExpTextLeft, Rect.Top, Rect.Right, Rect.Bottom);
  if odSelected in State then
  begin
    C.Brush.Color := clHighlight;
    C.Font.Color := clHighlightText;
  end
  else
  begin
    C.Brush.Color := CategoryList.Color;
    C.Font.Color := CategoryList.Font.Color;
  end;
  C.FillRect(T);
  if X in ExpBoldCategories then C.Font.Style := [fsBold] else C.Font.Style := [];
  C.Brush.Style := bsClear;
  Inc(T.Left, 2 * S);
  C.TextOut(T.Left, T.Top + (T.Bottom - T.Top - C.TextHeight('Wg')) div 2, Text);
  C.Brush.Style := bsSolid;
  UIListRowWidth(CategoryList, T.Left + C.TextWidth(Text));
end;

{ the arrow: open or closed; the text: a drag begins (once the pointer moved) - the check box is
  the list's }
procedure TEnvOptionsFrame.CategoryListMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  if Button <> mbLeft then Exit;
  I := CategoryList.ItemAtPos(Point(X, Y), True);
  if I < 0 then Exit;
  { the columns are the last painting's: client coordinates, the list's scrolling in them }
  if (X >= FExpArrowLeft) and (X < FExpTextLeft) then ExpToggleExpand(I)
  else if X >= FExpTextLeft then CategoryList.BeginDrag(False);
end;

{ onto any other row; its frame dotted while the drag is over it }
procedure TEnvOptionsFrame.CategoryListDragOver(Sender, Source: TObject; X, Y: Integer;
  State: TDragState; var Accept: Boolean);
var
  I: Integer;
begin
  I := CategoryList.ItemAtPos(Point(X, Y), True);
  Accept := (Source = CategoryList) and (I >= 0) and (I <> CategoryList.ItemIndex);
  if not Accept or (State = dsDragLeave) then I := -1;
  ExpDropFrame(I);
end;

{ the dragged row takes the index of the one it was dropped on (Delphi's Items.Move), with its
  check }
procedure TEnvOptionsFrame.CategoryListDragDrop(Sender, Source: TObject; X, Y: Integer);
var
  Cur, Target: Integer;
  S: string;
  O: TObject;
  Checked: Boolean;
begin
  Cur := CategoryList.ItemIndex;
  Target := CategoryList.ItemAtPos(Point(X, Y), True);
  FExpDropRow := -1;                 // the rows are painted again
  if (Source <> CategoryList) or (Cur < 0) or (Target < 0) or (Target = Cur) then
  begin
    CategoryList.Invalidate;
    Exit;
  end;
  S := CategoryList.Items[Cur];
  O := CategoryList.Items.Objects[Cur];
  Checked := CategoryList.Checked[Cur];
  CategoryList.Items.BeginUpdate;
  try
    CategoryList.Items.Delete(Cur);
    CategoryList.Items.InsertObject(Target, S, O);
    CategoryList.Checked[Target] := Checked;
  finally
    CategoryList.Items.EndUpdate;
  end;
  CategoryList.ItemIndex := Target;
end;

procedure TEnvOptionsFrame.CategoryListEndDrag(Sender, Target: TObject; X, Y: Integer);
begin
  if FExpDropRow < 0 then Exit;
  FExpDropRow := -1;
  CategoryList.Invalidate;
end;

procedure TEnvOptionsFrame.CategoryListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if ((Key = VK_LEFT) or (Key = VK_RIGHT)) and (CategoryList.ItemIndex >= 0) then
  begin
    ExpToggleExpand(CategoryList.ItemIndex);
    Key := 0;
  end;
end;

procedure TEnvOptionsFrame.ExpToggleExpand(Index: Integer);
var
  X: TExpCategory;
  R: TRect;
begin
  X := ExpRowCategory(Index);
  FExpExpand[X] := not FExpExpand[X];
  R := CategoryList.ItemRect(Index);
  InvalidateRect(CategoryList.Handle, @R, False);
end;

{ the dotted frame of a drag's target row (Delphi's: an XOR focus rectangle), moved to Row (-1:
  none) }
procedure TEnvOptionsFrame.ExpDropFrame(Row: Integer);
var
  DC: HDC;
  R: TRect;
begin
  if Row = FExpDropRow then Exit;
  DC := GetDC(CategoryList.Handle);
  try
    if FExpDropRow >= 0 then
    begin
      R := CategoryList.ItemRect(FExpDropRow);
      DrawFocusRect(DC, R);
    end;
    FExpDropRow := Row;
    if Row >= 0 then
    begin
      R := CategoryList.ItemRect(Row);
      DrawFocusRect(DC, R);
    end;
  finally
    ReleaseDC(CategoryList.Handle, DC);
  end;
end;

{ a row's hint: over its check box "Visible" / "Hidden", over its arrow "Expanded" / "Collapsed"
  (Delphi's texts), for as long as the pointer stays there; the text: none }
function TEnvOptionsFrame.ExpCategoryHint(var Info: THintInfo): Boolean;
var
  I: Integer;
  R: TRect;
begin
  Result := False;
  I := CategoryList.ItemAtPos(Info.CursorPos, True);
  if I < 0 then Exit;
  { the row's rectangle and the columns: client coordinates, the list's scrolling in them }
  R := CategoryList.ItemRect(I);
  if Info.CursorPos.X < FExpArrowLeft then
  begin
    if CategoryList.Checked[I] then Info.HintStr := 'Visible' else Info.HintStr := 'Hidden';
    R.Right := FExpArrowLeft;
  end
  else if Info.CursorPos.X < FExpTextLeft then
  begin
    if FExpExpand[ExpRowCategory(I)] then Info.HintStr := 'Expanded' else Info.HintStr := 'Collapsed';
    R.Left := FExpArrowLeft;
    R.Right := FExpTextLeft;
  end
  else
    Exit;
  Info.CursorRect := R;
  Result := True;
end;

end.
