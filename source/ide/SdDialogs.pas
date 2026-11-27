{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDialogs;

{ D7 Studio - the modal dialogs, as the rest of the IDE calls them.

  Every dialog is a form of its own - a unit Sd*Dlg.pas with its .dfm, designed in the form
  designer on the dialog grid:

      SdFindDlg, SdReplaceDlg, SdFindInFilesDlg    Search menu
      SdInputDlg, SdListDlg                        one line of text; a list to choose from
      SdOptionsDlg                                 Tools | Environment / Editor / Debugger / Formatter
                                                   Options: one dialog, its sections frames -
        SdEnvOptionsFrame, SdEditorOptionsFrame,   ... a unit + .dfm each, not dialogs of their own;
        SdDebuggerOptionsFrame, SdFormatterFrame   SdFormatterPreview: the Formatter's Preview window;
        SdProjOptionsFrame                         Project | Options: the same dialog with this section
      SdCodeTemplatesDlg, SdAddCodeTemplateDlg     ... Source Options | Edit Code Templates
      SdExceptRangeDlg                             ... OS Exceptions | Add
      SdCustomizeDlg                               View | Toolbars | Customize (modeless: SdMain shows it)
      SdAddTodoDlg                                 the editor's Add To-Do Item (also the To-Do List's Add / Edit)
      SdTodoFilterDlg                              the To-Do List's Filter | Categories, Owners, Item Types
      SdTableOptionsDlg                            the To-Do List's Table Properties (Copy As | HTML Table)
      SdAddModuleDlg                               Run | Add Breakpoint | Module Load Breakpoint
      SdAttachDlg                                  Run | Attach to Process
      SdAddRepositoryDlg, SdRepositoryDlg          Add to Repository, Tools | Repository
      SdCompTemplateDlg                            Component | Create Component Template
      SdImportTypeLibDlg                           Project | Import Type Library, Component | Import ActiveX
      SdPackageAddDlg                              the package editor's Add (with New Component's and Import ActiveX's pages)
      SdAboutDlg, SdCompileDlg                     About, compiler progress (Install Packages is the
                                                   Packages page of Project Options, as in Delphi)
      SdRunParamsDlg, SdListEditDlg, SdVarEntryDlg Run | Parameters; Delphi's path list editor; a variable
      SdEvalDlg                                    Evaluate/Modify (called by SdDebugUI)
      SdAlignDlg, SdSizeDlg, SdScaleDlg,           Edit | Align, Size, Scale, Tab Order
        SdTabOrderDlg
      SdWindowListDlg, SdDesktopDlg,               View | Window List, Desktops (save, debug, delete)
        SdDesktopDeleteDlg, SdDesktopsDlg          ... and the Desktops button (all in one)
      SdTransferDlg, SdTransEditDlg                Tools | Configure Tools
      SdFindErrorDlg, SdBrowseSymbolDlg            Search | Find Error, Browse Symbol
      SdWatchEditDlg                               Watch Properties (the Watch List's Add / Edit Watch)
      SdCompInfoDlg                                Project | Information
      SdNewImageDlg, SdImageSizeDlg,               the Resources view and its editors: new images'
        SdImageTextDlg, SdColorEditDlg,            sizes, the image editor's Resize, its text tool, a
        SdResPropsDlg                              colour, a resource's properties (the editors are
                                                   pages, SdResPage)

  A new dialog: File | New | Form, BorderStyle bsDialog, BorderIcons [biSystemMenu], Position
  poOwnerFormCenter (UIPrepareForm centres it on its owner), font Segoe UI 9; UIPrepareForm(Self)
  in OnCreate; a class function
  Execute that creates, fills, shows and frees it. Its command buttons run their handlers through
  OnClick, unless a command has an enabled state, two controls or a call from code: then the
  dialog's action list (OnUpdate). An OK that checks the values does it in that handler
  (DialogValid; never a check after ShowModal - the dialog is hidden and the main window
  enabled again by then); "Browse..." is BrowseFile / BrowseFolder, a path list
  EditPathListText, Move Up / Down and Delete of a list MoveListRow / DeleteListRow. }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, SdProject, SdRunParamsDlg, SdCompInfoDlg,
  SdSourceBPDlg, SdDbgEngine, SdRepository, SdAddRepositoryDlg, SdImportTypeLibDlg, SdWatchEditDlg, SdTodo,
  SdAddTodoDlg, SdPackageAddDlg, SdInputDlg, SdOptionsDlg, SdResImage, SdResPropsDlg;

type
  { what BrowseFile asks for: an existing file to open; any name to open (one that may not exist
    yet); a name to save under (an existing file is asked about); a name to save under without
    that question (the caller asks itself) }
  TBrowseFileMode = (bfOpen, bfOpenAny, bfSave, bfSaveNoPrompt);

  { a row of a table of combo boxes that hold project options (LoadComboTable): the box (its
    name in the form), the section and key of the option, Delphi's history list of the box }
  TOptionCombo = array[0..3] of string;

  { a row of a table of check boxes that hold project options (LoadCheckTable): the box (its name
    in the form), the section and key of the option (checked: not 0), its value when it is not
    there }
  TOptionCheck = record
    Name, Section, Key: string;
    Default: Integer;
  end;

  TFindOptionsRec = record
    FindText, ReplaceText: string;
    MatchCase, WholeWord, RegExp, Backward, EntireScope, SelectedOnly, ReplaceAll, PromptOnReplace: Boolean;
    History, ReplaceHistory: string;       // CRLF separated
  end;

  TFindInFilesRec = record
    FindText: string;
    MatchCase, WholeWord: Boolean;
    Where: Integer;                        // 0 project files, 1 open files, 2 directory
    Directory, Mask: string;
    Recurse: Boolean;
  end;

  { Component | Install Component: what the dialog was given and gives back }
  TInstallCompInfo = record
    UnitFile: string;          // the component's .pas
    SearchPath: string;        // the package's search path (its .dof)
    PackageFile: string;       // the .dpk
    Description: string;       // of a new package
    NewPackage: Boolean;       // "Into new package"
  end;

  { the Desktops dialog: the saved desktops, and what its commands do (the main form's) }
  TDesktopNamesEvent = procedure(L: TStringList) of object;
  TDesktopEvent = procedure(const Name: string) of object;

const
  { the Packages page of Project Options: Component | Install Packages opens it (as Delphi 7) }
  ProjOptionsPackagesPage = 7;
  { the pages the Resources view opens for the resources Project Options writes: Application (the
    manifest), Version Info }
  ProjOptionsApplicationPage = 1;
  ProjOptionsVersionPage = 6;
  { pages of Environment Options that commands open directly: the Object Inspector's Properties,
    Component | Configure Palette }
  EnvOptionsInspectorPage = 2;
  EnvOptionsPalettePage = 3;
  EnvOptionsExplorerPage = 5;
  EnvOptionsComponentsPage = 8;
  DebuggerOptionsEventLogPage = 1;     { Debugger Options: General, Event Log, ... }
  { Delphi's name for no desktop (Select debug desktop, the Desktops dialog's debug desktop) }
  NoDesktopName = '<None>';

function FindDialog(AOwner: TComponent; var Opts: TFindOptionsRec; Replace: Boolean): Boolean;
function FindInFilesDialog(AOwner: TComponent; var Opts: TFindInFilesRec): Boolean;
function GotoLineDialog(AOwner: TComponent; MaxLine: Integer; var Line: Integer): Boolean;
{ Check: what OK finds wrong with the text ('' nothing; nil: no check) - the dialog stays open then }
function InputDialog(AOwner: TComponent; const ACaption, Prompt: string; var Value: string;
  Check: TInputCheck = nil): Boolean;
{ ... with Unicode text (a WideString property) }
function InputDialogWide(AOwner: TComponent; const ACaption, Prompt: string; var Value: WideString): Boolean;
function ListDialog(AOwner: TComponent; const ACaption: string; Items: TStrings; var Index: Integer): Boolean;
{ Page: the page shown first (TProjOptionsFrame.LoadOptions: 0 Forms ... ProjOptionsPackagesPage).
  DprSource is the project source; the Forms page rewrites its Application.CreateForm lines. }
function ProjectOptionsDialog(AOwner: TComponent; Project: TSdProject; Page: Integer;
  var DprSource: string): Boolean;
{ Tools | Environment Options, Editor Options, Debugger Options, Formatter Options: one dialog,
  opened at a page of a section (Page: an index of its pages - EnvOptionsPalettePage ...); the
  values: SdEnvOptions, SdEditorOptions, SdDebuggerOptions, SdFormatterOptions }
function OptionsDialog(AOwner: TComponent; Section: TOptionsSection; Page: Integer = 0): Boolean;
{ Editor Options | Source Options | Edit Code Templates (SdCodeTemplates); its Add / Edit }
function CodeTemplatesDialog(AOwner: TComponent): Boolean;
function AddCodeTemplateDialog(AOwner: TComponent; const ACaption: string; var AName, ADesc: string): Boolean;
{ Add To-Do Item: the editor's, the To-Do List's Add and Edit (Owners, Categories: those offered) }
function AddTodoDialog(AOwner: TComponent; Mode: TTodoDlgMode; Owners, Categories: TStrings;
  var V: TTodoValues): Boolean;
{ the To-Do List's Filter: Values with Shown (a Boolean per value as a pointer), the unchecked
  values into Hidden }
function TodoFilterDialog(AOwner: TComponent; const Prompt: string; Values: TStrings; Shown: TList;
  Hidden: TStrings): Boolean;
{ the To-Do List's Table Properties: the options of Copy As | HTML Table }
function TableOptionsDialog(AOwner: TComponent; Table: TSdTodoTable): Boolean;
{ Run | Parameters: rpLoad = Load (start under the debugger, stopped at the entry point) }
function RunParamsDialog(AOwner: TComponent; Project: TSdProject): TRunParamsResult;
{ Packages: the .dpk files offered under "Into existing package" }
function InstallComponentDialog(AOwner: TComponent; Packages: TStrings; var Info: TInstallCompInfo): Boolean;
{ Delphi's variable entry: the name and value of an environment variable }
function VariableEntryDialog(AOwner: TComponent; const ACaption: string; var Name, Value: string): Boolean;
{ Delphi's ordered list editor for a ';' separated option (Paths: folders, relative to BaseDir) }
function ListEditDialog(AOwner: TComponent; const ACaption: string; Paths: Boolean; const BaseDir: string;
  var Value: string): Boolean;
procedure AboutDialog(AOwner: TComponent);
{ test support: creates the dialog Which ('project', 'env') - its OnCreate
  lays it out for the UI font - and writes it as .dfm text to FileName }
procedure WriteDialogText(const Which, FileName: string);
{ Runs the compiler behind Delphi's "Compiling" dialog (Environment Options | Preferences |
  Show compiler progress). AutoClose: the dialog closes by itself after a successful compile
  (Run); otherwise it waits for OK. Returns the compiler's result. }
function CompileWithProgress(AOwner: TComponent; Compiler: TSdCompiler; const ProjectFile, Dcc32, Args,
  WorkDir, SearchPath: string; AutoClose: Boolean): Boolean;

{ Delphi 7's dialogs of the main window's commands }
function AlignDialog(AOwner: TComponent; var H, V: Integer): Boolean;
function SizeDialog(AOwner: TComponent; var HMode, VMode, W, H: Integer): Boolean;
function ScaleDialog(AOwner: TComponent; var Percent: Integer): Boolean;
function TabOrderDialog(AOwner: TComponent; Items: TStrings; CreationOrder: Boolean = False): Boolean;
function WindowListDialog(AOwner: TComponent; Items: TStrings; var Index: Integer): Boolean;
function DesktopDialog(AOwner: TComponent; Debug: Boolean; Names: TStrings; var Name: string): Boolean;
{ View | Desktops | Delete: the saved desktops chosen for deletion into Selected }
function DesktopDeleteDialog(AOwner: TComponent; Names, Selected: TStrings): Boolean;
{ the Desktops button: the saved desktops (Names), the current one chosen; Save the current one
  under a name, Load one (and close), Delete one, the debug desktop ('' none) }
procedure DesktopsDialog(AOwner: TComponent; Names: TDesktopNamesEvent; const Current, Debug: string;
  OnSave, OnLoad, OnDelete, OnDebug: TDesktopEvent);
procedure ConfigureToolsDialog(AOwner: TComponent);
function FindErrorDialog(AOwner: TComponent; var Address: string): Boolean;
function BrowseSymbolDialog(AOwner: TComponent; var Symbol: string): Boolean;
procedure CompileInfoDialog(AOwner: TComponent; const ACaption: string; const Info: TCompileInfo);
{ Delphi's breakpoint dialogs: the source, address or data breakpoint BP (its Kind; the settings
  in and out); Groups: the names of the groups there are; KeyChanges False: its place (file and
  line, address, length) cannot be changed }
function BreakpointDialog(AOwner: TComponent; const ACaption: string; BP: TDbgBreakpoint; Groups: TStrings;
  AddrFunc: TAddressFunc; KeyChanges: Boolean = True): Boolean;
{ Watch Properties: the watch W (the settings in and out) }
function WatchDialog(AOwner: TComponent; W: TWatchItem): Boolean;
{ Add Module: the module of a module load breakpoint }
function ModuleBreakpointDialog(AOwner: TComponent; const ACaption: string; var ModuleName: string): Boolean;
{ Run | Attach to Process: the process chosen }
function AttachDialog(AOwner: TComponent; out Pid: Cardinal): Boolean;
{ Add To Repository (Forms: the project's forms, FormIndex the chosen one; nil: a project or an
  item edited), Tools | Repository (on Repo), Create Component Template }
function AddRepositoryDialog(AOwner: TComponent; const ACaption: string; Forms, Pages: TStrings;
  var FormIndex: Integer; var Info: TRepoInfo): Boolean;
function RepositoryDialog(AOwner: TComponent; Repo: TRepository): Boolean;
function CompTemplateDialog(AOwner: TComponent; Pages: TStrings; Icon: TBitmap; var Name, Page, IconFile: string): Boolean;
{ Project | Import Type Library (ActiveX: Component | Import ActiveX Control); Added: the library
  files added with Add... }
function ImportTypeLibDialog(AOwner: TComponent; ActiveX: Boolean; Pages, Added: TStrings;
  var Info: TImportTLBInfo): Boolean;
{ the package editor's Add (SdPackageAddDlg.TPackageAddDlg.Execute) }
function PackageAddDialog(AOwner: TComponent; const Dir: string; Classes, PalettePages, ImportPages,
  Added: TStrings; var Info: TPackageAddInfo): Boolean;
{ the Find and the Replace dialog (D, freed here) - their common part: Opts into the controls
  of the same names in both forms, shown, and back after OK (Replace All: Opts.ReplaceAll) }
function RunFindDialog(D: TForm; var Opts: TFindOptionsRec): Boolean;
{ "..." of a folder option: the folder dialog at Value (macros expanded, a relative folder from
  BaseDir); Value becomes the folder chosen, relative to BaseDir when it is below it }
function BrowseFolder(const ACaption, BaseDir: string; var Value: string): Boolean; overload;
{ ... of the text of Box (an edit or a combo box) }
function BrowseFolder(Box: TControl; const ACaption, BaseDir: string): Boolean; overload;
{ BaseDir with its '\' ('' stays ''); the name of a folder or file option as the dialogs take
  it: macros expanded, a relative name from Base (a BaseFolder) }
function BaseFolder(const BaseDir: string): string;
function FullOptionPath(const Value, Base: string): string;
{ ... and back: a name below Base relative to it, as Delphi gives it; any other as it is }
function OptionPath(const Path, Base: string): string;
{ "Browse..." of a file: the IDE's Open dialog (Mode bfSave, bfSaveNoPrompt: its Save dialog) -
  TSdFileDialog, so names outside the code page come back usable. Value in: the name proposed
  ('' none; macros expanded, a relative name from BaseDir); the dialog starts in its folder, else
  in InitialDir, else in BaseDir. Value out: the file chosen, relative to BaseDir when it is below
  it (as BrowseFolder). DefaultExt ('pas', no dot): added to a name typed without one. }
function BrowseFile(const ACaption, Filter: string; var Value: string; Mode: TBrowseFileMode = bfOpen;
  const DefaultExt: string = ''; const InitialDir: string = ''; const BaseDir: string = ''): Boolean; overload;
{ ... of the text of Box (an edit or a combo box): its text proposed, the file chosen written back }
function BrowseFile(Box: TControl; const ACaption, Filter: string; Mode: TBrowseFileMode = bfOpen;
  const DefaultExt: string = ''; const InitialDir: string = ''; const BaseDir: string = ''): Boolean; overload;
{ Box (an edit or a combo box) holds a file's name (Folder: a folder's): Windows completes the name as it is
  typed, and a file or folder dropped from Explorer on it becomes its text (the first one dropped) }
procedure PathBox(Box: TControl; Folder: Boolean);
{ the files and folders dropped from Explorer on Control go to OnDrop (full, usable names) }
type
  TFilesDropEvent = procedure(Control: TControl; Files: TStrings) of object;
procedure AcceptFileDrops(Control: TWinControl; OnDrop: TFilesDropEvent);
{ several existing files at once: Files gets them (full, usable names) }
function BrowseFiles(const ACaption, Filter: string; Files: TStrings; const InitialDir: string = ''): Boolean;
{ "..." of a ';' separated option in Box (an edit or a combo box): Delphi's ordered list editor
  (ListEditDialog; Paths: folders, relative ones from BaseDir) on its text, the text after OK }
function EditPathListText(Box: TControl; const ACaption: string; Paths: Boolean; const BaseDir: string): Boolean;
{ the combo boxes of Table in Form (a form or a frame: their owner): their history lists (of the project's .dof) and their options
  (Load), and back (Save: the options, and each value into its history list) }
procedure LoadComboTable(Form: TComponent; Project: TSdProject; const Table: array of TOptionCombo);
procedure SaveComboTable(Form: TComponent; Project: TSdProject; const Table: array of TOptionCombo);
{ the check boxes of Table in Form (their owner) from the project's options, and back }
procedure LoadCheckTable(Form: TComponent; Project: TSdProject; const Table: array of TOptionCheck);
procedure SaveCheckTable(Form: TComponent; Project: TSdProject; const Table: array of TOptionCheck);
{ a font of [UI] in a name and a size box (the UI font and the fixed-size font of Environment
  Options | Preferences | User interface). FillFontChoice: the system's fonts and the
  sizes, each list after "(Default)"; LoadFontChoice shows the value ('' and 0 are "(Default)"),
  SaveFontChoice writes the boxes' value }
procedure FillFontChoice(Name, Size: TComboBox);
procedure LoadFontChoice(Name, Size: TComboBox; const NameKey, SizeKey: string);
procedure SaveFontChoice(Name, Size: TComboBox; const NameKey, SizeKey: string);
{ OK of a dialog that checks its values: OK's handler (its OnClick, or the
  dialog's action aOK) checks them and sets ModalResult only when they pass - the dialog stays modal (and the main window disabled)
  while a message is shown. DialogValid: Msg '' passes (True); else Msg in a message box (Title,
  '' the dialog's caption) and False - Bad (when given) gets the focus, with its page of a page
  control shown first and its text selected. The second form: the condition Ok, Msg when it fails. }
function DialogValid(Form: TForm; const Msg: string; Bad: TWinControl; const Title: string = ''): Boolean; overload;
function DialogValid(Form: TForm; Ok: Boolean; const Msg: string; Bad: TWinControl;
  const Title: string = ''): Boolean; overload;
{ the number in E, Low .. High; else the message (the RTL's for no number, as Delphi shows it) -
  Watch Properties, Add / Edit To-Do Item }
function CheckNumber(E: TEdit; Low, High: Integer; const RangeMsg: string; out N: Integer): string;
{ the RTL's message for a text that is no integer ('abc' is not a valid integer value) }
function NotIntegerMsg(const S: string): string;
{ an image's size: the width in EW and the height in EH, each 1 .. MaxSize pixels (DialogValid:
  else the message, the box that is wrong) }
function SizeValid(Form: TForm; EW, EH: TEdit; MaxSize: Integer): Boolean;
{ Move Up / Move Down of a list box (Up: up, else down): CanMoveListRow - the chosen row and the
  place it moves to are both within the rows Lo .. Hi (rows outside them never move: the
  palette's [All], its greyed components); MoveListRow moves it there - with its object and its
  check box - and keeps it chosen; the row's old index (-1: it could not move), its new one is
  List.ItemIndex: the caller moves its own data the same way }
function CanMoveListRow(List: TCustomListBox; Up: Boolean; Lo: Integer = 0; Hi: Integer = MaxInt): Boolean;
function MoveListRow(List: TCustomListBox; Up: Boolean; Lo: Integer = 0; Hi: Integer = MaxInt): Integer;
{ Delete of a list: the row to choose after row Index went from a list that has Count rows now -
  the one in its place, at the end the one before it, -1 when none is left }
function RowAfterDelete(Index, Count: Integer): Integer;
{ ... of a list box: its chosen row goes, the next one is chosen (RowAfterDelete); the deleted
  row's index (-1: none was chosen) - the caller deletes its own data there }
function DeleteListRow(List: TCustomListBox): Integer;
{ Rename / Add of a page (the palette's, the repository's): Name may not be the name of another
  page of Pages than Index (-1: a new page; Index itself may change its case); False and a
  message over Form when it is - What names the kind in it (a version information's key) }
function PageNameFree(Form: TForm; Pages: TStrings; const Name: string; Index: Integer;
  const What: string = 'page'): Boolean;
{ a list to choose from (D, freed here; View Unit ..., Window List): List shows Items with Index
  chosen (else the first row), the row chosen after OK into Index }
function RunListDialog(D: TForm; List: TListBox; Items: TStrings; var Index: Integer): Boolean;
{ a row of a dialog that it does not ask for: Row's controls (nil ones skipped) hidden, the
  controls below the first one's top moved up by Height, the dialog as much lower }
procedure HideDialogRow(Form: TForm; const Row: array of TControl; Height: Integer);
{ the dialogs of the Resources view and its editors. NewImageDialog: the
  sizes and colours of new images (Sizes and Bits shown first; OfferScale: empty or Scale - the
  image shown, scaled); ImageSizeDialog: the image editor's Resize (Mode 0 smooth, 1 pixels, 2 the
  canvas at the top left, 3 centred); ImageTextDialog: the text tool's text, font, smooth edges;
  ColorEditDialog: a colour $AARRGGBB; ResPropsDialog: type, name and language, Check while the
  dialog is open }
function NewImageDialog(AOwner: TComponent; Kind: TSdImageKind; var Sizes: TSdSizes; var Bits: Integer;
  OfferScale: Boolean; var Scale: Boolean): Boolean;
function ImageSizeDialog(AOwner: TComponent; Kind: TSdImageKind; var W, H, Mode: Integer): Boolean;
function ImageTextDialog(AOwner: TComponent; var Text: string; Font: TFont; var Smooth: Boolean): Boolean;
function ColorEditDialog(AOwner: TComponent; const ACaption: string; var Color: Cardinal; Alpha: Boolean): Boolean;
function ResPropsDialog(AOwner: TComponent; const ACaption: string; TypeEditable, NameEditable: Boolean;
  var AType, AName: string; var Language: Integer; Check: TResPropsCheck): Boolean;

implementation

uses
  Messages, ShellAPI, ShLwApi, {$WARN UNIT_PLATFORM OFF} FileCtrl, {$WARN UNIT_PLATFORM ON}
  Dialogs, ComCtrls, SdFileNames,
  SdFindDlg, SdReplaceDlg, SdFindInFilesDlg, SdListDlg,
  SdInstallCompDlg, SdAboutDlg, SdCompileDlg, SdVarEntryDlg, SdListEditDlg, SdUI,
  SdAlignDlg, SdSizeDlg, SdScaleDlg, SdTabOrderDlg, SdWindowListDlg, SdDesktopDlg, SdDesktopDeleteDlg, SdDesktopsDlg,
  SdTransferDlg, SdTransEditDlg, SdFindErrorDlg, SdBrowseSymbolDlg, SdNewCompDlg, SdCompListDlg, SdNewItemsDlg, SdNewThreadDlg, SdPrintDlg,
  SdSettings, SdEnvOptions, SdEditorOptions, SdCodeTemplatesDlg,
  SdAddCodeTemplateDlg, SdExceptRangeDlg, SdCustomizeDlg, SdAddModuleDlg, SdAttachDlg,
  SdRepositoryDlg, SdCompTemplateDlg, SdTodoFilterDlg, SdTableOptionsDlg,
  SdNewImageDlg, SdImageSizeDlg, SdImageTextDlg, SdColorEditDlg;

type
  { the drop of files on a control (AcceptFileDrops: to OnDrop; PathBox: its text) and Windows' completion
    of names in it (Complete: SHAutoComplete's flags, 0 none), given again when its window is made again }
  TFileDropHook = class(TUIWindowHook)
  private
    FComplete: DWORD;
    FOnDrop: TFilesDropEvent;
    procedure Prepare;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

function AlignDialog(AOwner: TComponent; var H, V: Integer): Boolean;
begin
  Result := TAlignDlg.Execute(AOwner, H, V);
end;

function SizeDialog(AOwner: TComponent; var HMode, VMode, W, H: Integer): Boolean;
begin
  Result := TSizeDlg.Execute(AOwner, HMode, VMode, W, H);
end;

function ScaleDialog(AOwner: TComponent; var Percent: Integer): Boolean;
begin
  Result := TScaleDlg.Execute(AOwner, Percent);
end;

function TabOrderDialog(AOwner: TComponent; Items: TStrings; CreationOrder: Boolean): Boolean;
begin
  Result := TTabOrderDlg.Execute(AOwner, Items, CreationOrder);
end;

function WindowListDialog(AOwner: TComponent; Items: TStrings; var Index: Integer): Boolean;
begin
  Result := TWindowListDlg.Execute(AOwner, Items, Index);
end;

function DesktopDialog(AOwner: TComponent; Debug: Boolean; Names: TStrings; var Name: string): Boolean;
begin
  Result := TDesktopDlg.Execute(AOwner, Debug, Names, Name);
end;

function DesktopDeleteDialog(AOwner: TComponent; Names, Selected: TStrings): Boolean;
begin
  Result := TDesktopDeleteDlg.Execute(AOwner, Names, Selected);
end;

procedure DesktopsDialog(AOwner: TComponent; Names: TDesktopNamesEvent; const Current, Debug: string;
  OnSave, OnLoad, OnDelete, OnDebug: TDesktopEvent);
begin
  TDesktopsDlg.Execute(AOwner, Names, Current, Debug, OnSave, OnLoad, OnDelete, OnDebug);
end;

procedure ConfigureToolsDialog(AOwner: TComponent);
begin
  TTransferDlg.Execute(AOwner);
end;

function FindErrorDialog(AOwner: TComponent; var Address: string): Boolean;
begin
  Result := TFindErrorDlg.Execute(AOwner, Address);
end;

function BrowseSymbolDialog(AOwner: TComponent; var Symbol: string): Boolean;
begin
  Result := TBrowseSymbolDlg.Execute(AOwner, Symbol);
end;

procedure CompileInfoDialog(AOwner: TComponent; const ACaption: string; const Info: TCompileInfo);
begin
  TCompInfoDlg.Execute(AOwner, ACaption, Info);
end;

function BreakpointDialog(AOwner: TComponent; const ACaption: string; BP: TDbgBreakpoint; Groups: TStrings;
  AddrFunc: TAddressFunc; KeyChanges: Boolean): Boolean;
begin
  Result := TSourceBPDlg.Execute(AOwner, ACaption, BP, Groups, AddrFunc, KeyChanges);
end;

function WatchDialog(AOwner: TComponent; W: TWatchItem): Boolean;
begin
  Result := TWatchEditDlg.Execute(AOwner, W);
end;

function ModuleBreakpointDialog(AOwner: TComponent; const ACaption: string; var ModuleName: string): Boolean;
begin
  Result := TAddModuleDlg.Execute(AOwner, ACaption, ModuleName);
end;

function AttachDialog(AOwner: TComponent; out Pid: Cardinal): Boolean;
begin
  Result := TAttachDlg.Execute(AOwner, Pid);
end;

function AddRepositoryDialog(AOwner: TComponent; const ACaption: string; Forms, Pages: TStrings;
  var FormIndex: Integer; var Info: TRepoInfo): Boolean;
begin
  Result := TAddRepositoryDlg.Execute(AOwner, ACaption, Forms, Pages, FormIndex, Info);
end;

function RepositoryDialog(AOwner: TComponent; Repo: TRepository): Boolean;
begin
  Result := TRepositoryDlg.Execute(AOwner, Repo);
end;

function CompTemplateDialog(AOwner: TComponent; Pages: TStrings; Icon: TBitmap; var Name, Page, IconFile: string): Boolean;
begin
  Result := TCompTemplateDlg.Execute(AOwner, Pages, Icon, Name, Page, IconFile);
end;

function ImportTypeLibDialog(AOwner: TComponent; ActiveX: Boolean; Pages, Added: TStrings;
  var Info: TImportTLBInfo): Boolean;
begin
  Result := TImportTypeLibDlg.Execute(AOwner, ActiveX, Pages, Added, Info);
end;

function PackageAddDialog(AOwner: TComponent; const Dir: string; Classes, PalettePages, ImportPages,
  Added: TStrings; var Info: TPackageAddInfo): Boolean;
begin
  Result := TPackageAddDlg.Execute(AOwner, Dir, Classes, PalettePages, ImportPages, Added, Info);
end;

function VariableEntryDialog(AOwner: TComponent; const ACaption: string; var Name, Value: string): Boolean;
begin
  Result := TVarEntryDlg.Execute(AOwner, ACaption, Name, Value);
end;

function ListEditDialog(AOwner: TComponent; const ACaption: string; Paths: Boolean; const BaseDir: string;
  var Value: string): Boolean;
begin
  Result := TListEditDlg.Execute(AOwner, ACaption, Paths, BaseDir, Value);
end;

type
  { a dialog the test command writedlg lays out: its name there, its form }
  TDialogForm = record
    Name: string;
    FormClass: TFormClass;
  end;

const
  { the sections of the Options dialog are frames: SdOptionsDlg.LayoutSection }
  DialogForms: array[0..35] of TDialogForm = (
    (Name: 'runparams'; FormClass: TRunParamsDlg), (Name: 'listedit'; FormClass: TListEditDlg),
    (Name: 'varentry'; FormClass: TVarEntryDlg), (Name: 'align'; FormClass: TAlignDlg),
    (Name: 'size'; FormClass: TSizeDlg), (Name: 'scale'; FormClass: TScaleDlg),
    (Name: 'taborder'; FormClass: TTabOrderDlg), (Name: 'windowlist'; FormClass: TWindowListDlg),
    (Name: 'desktop'; FormClass: TDesktopDlg), (Name: 'desktopdelete'; FormClass: TDesktopDeleteDlg),
    (Name: 'transfer'; FormClass: TTransferDlg), (Name: 'transedit'; FormClass: TToolPropertiesDlg),
    (Name: 'finderror'; FormClass: TFindErrorDlg), (Name: 'browsesymbol'; FormClass: TBrowseSymbolDlg),
    (Name: 'compinfo'; FormClass: TCompInfoDlg), (Name: 'newcomp'; FormClass: TNewCompDlg),
    (Name: 'complist'; FormClass: TCompListDlg), (Name: 'sourcebp'; FormClass: TSourceBPDlg),
    (Name: 'newitems'; FormClass: TNewItemsDlg), (Name: 'newthread'; FormClass: TNewThreadDlg),
    (Name: 'print'; FormClass: TPrintDlg), (Name: 'codetemplates'; FormClass: TCodeTemplatesDlg), (Name: 'addcodetemplate'; FormClass: TAddCodeTemplateDlg),
    (Name: 'exceptrange'; FormClass: TExceptRangeDlg), (Name: 'customize'; FormClass: TCustomizeDlg),
    (Name: 'addtodo'; FormClass: TAddTodoDlg), (Name: 'addmodule'; FormClass: TAddModuleDlg),
    (Name: 'attach'; FormClass: TAttachDlg), (Name: 'addrepository'; FormClass: TAddRepositoryDlg),
    (Name: 'repository'; FormClass: TRepositoryDlg), (Name: 'comptemplate'; FormClass: TCompTemplateDlg),
    (Name: 'importtypelib'; FormClass: TImportTypeLibDlg), (Name: 'watchedit'; FormClass: TWatchEditDlg),
    (Name: 'todofilter'; FormClass: TTodoFilterDlg), (Name: 'tableoptions'; FormClass: TTableOptionsDlg),
    (Name: 'packageadd'; FormClass: TPackageAddDlg));

{ a form's or a frame's .dfm text as the VCL writes it (with its windows: aligned controls have
  their real bounds then) }
procedure WriteText(C: TWinControl; const FileName: string);
var
  Bin, Txt: TMemoryStream;
begin
  Bin := TMemoryStream.Create;
  Txt := TMemoryStream.Create;
  try
    C.HandleNeeded;
    Bin.WriteComponent(C);
    Bin.Position := 0;
    ObjectBinaryToText(Bin, Txt);
    Txt.SaveToFile(FileName);
  finally
    Txt.Free;
    Bin.Free;
  end;
end;

procedure WriteDialogText(const Which, FileName: string);
var
  F, Host: TForm;
  Frame: TCustomFrame;
  I: Integer;
begin
  Frame := LayoutSection(Which, Host);
  if Frame <> nil then
  begin
    try
      WriteText(Frame, FileName);
    finally
      Host.Free;
    end;
    Exit;
  end;
  I := High(DialogForms);
  while (I >= 0) and (DialogForms[I].Name <> Which) do Dec(I);
  if I < 0 then Exit;
  UILayoutPass := True;
  try
    F := DialogForms[I].FormClass.Create(nil);
  finally
    UILayoutPass := False;
  end;
  try
    WriteText(F, FileName);
  finally
    F.Free;
  end;
end;

function InstallComponentDialog(AOwner: TComponent; Packages: TStrings; var Info: TInstallCompInfo): Boolean;
begin
  Result := TInstallCompDlg.Execute(AOwner, Packages, Info);
end;

{ a history list (CRLF separated, newest first) with Value as its newest entry }
function WithHistory(const History, Value: string): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := History;
    PushHistory(L, Value);
    Result := L.Text;
  finally
    L.Free;
  end;
end;

function RunFindDialog(D: TForm; var Opts: TFindOptionsRec): Boolean;
var
  Find, Replace: TComboBox;
  Res: Integer;

  function Box(const Name: string): TCheckBox;
  begin
    Result := D.FindComponent(Name) as TCheckBox;
  end;

  function Radio(const Name: string): TRadioButton;
  begin
    Result := D.FindComponent(Name) as TRadioButton;
  end;

begin
  try
    Find := D.FindComponent('cbFind') as TComboBox;
    Replace := D.FindComponent('cbReplace') as TComboBox;     // nil: the Find dialog
    { Editor Options | Auto-complete text to find }
    Find.AutoComplete := EditorOptions.FindAutoComplete;
    if Replace <> nil then Replace.AutoComplete := EditorOptions.FindAutoComplete;
    Find.Items.Text := Opts.History;
    Find.Text := Opts.FindText;
    Box('chkCase').Checked := Opts.MatchCase;
    Box('chkWholeWord').Checked := Opts.WholeWord;
    Box('chkRegExp').Checked := Opts.RegExp;
    if Opts.Backward then Radio('rbBackward').Checked := True else Radio('rbForward').Checked := True;
    if Opts.SelectedOnly then Radio('rbSelected').Checked := True else Radio('rbGlobal').Checked := True;
    if Opts.EntireScope then Radio('rbEntireScope').Checked := True else Radio('rbFromCursor').Checked := True;
    if Replace <> nil then
    begin
      Replace.Items.Text := Opts.ReplaceHistory;
      Replace.Text := Opts.ReplaceText;
      Box('chkPrompt').Checked := Opts.PromptOnReplace;
    end;
    Res := D.ShowModal;
    Result := (Res in [mrOk, mrAll]) and (Find.Text <> '');
    if not Result then Exit;
    Opts.FindText := Find.Text;
    Opts.History := WithHistory(Opts.History, Find.Text);
    Opts.MatchCase := Box('chkCase').Checked;
    Opts.WholeWord := Box('chkWholeWord').Checked;
    Opts.RegExp := Box('chkRegExp').Checked;
    Opts.Backward := Radio('rbBackward').Checked;
    Opts.SelectedOnly := Radio('rbSelected').Checked;
    Opts.EntireScope := Radio('rbEntireScope').Checked;
    Opts.ReplaceAll := Res = mrAll;
    if Replace <> nil then
    begin
      Opts.ReplaceText := Replace.Text;
      Opts.ReplaceHistory := WithHistory(Opts.ReplaceHistory, Replace.Text);
      Opts.PromptOnReplace := Box('chkPrompt').Checked;
    end;
  finally
    D.Free;
  end;
end;

type
  { the text of an edit or a combo box (TControl.Text is protected) }
  TBoxText = class(TControl);

function BaseFolder(const BaseDir: string): string;
begin
  if BaseDir <> '' then Result := IncludeTrailingPathDelimiter(BaseDir) else Result := '';
end;

function FullOptionPath(const Value, Base: string): string;
begin
  Result := ExpandPathMacros(Value);
  if (Result <> '') and (Base <> '') and not IsAbsolutePath(Result) then Result := Base + Result;
end;

{ ... and back: a name below Base relative to it, as Delphi gives it }
function OptionPath(const Path, Base: string): string;
begin
  Result := Path;
  if (Base <> '') and (Length(Path) > Length(Base)) and SameText(Copy(Path, 1, Length(Base)), Base) then
    Result := ExtractRelativePath(Base, Path);
end;

function BrowseFolder(const ACaption, BaseDir: string; var Value: string): Boolean;
var
  Dir, Base: string;
begin
  Base := BaseFolder(BaseDir);
  Dir := FullOptionPath(Value, Base);
  Result := SelectDirectory(ACaption, '', Dir);
  if Result then Value := OptionPath(Dir, Base);
end;

function BrowseFolder(Box: TControl; const ACaption, BaseDir: string): Boolean;
var
  S: string;
begin
  S := Trim(TBoxText(Box).Text);
  Result := BrowseFolder(ACaption, BaseDir, S);
  if Result then TBoxText(Box).Text := S;
end;

const
  BrowseOptions: array[TBrowseFileMode] of TOpenOptions = (
    [ofHideReadOnly, ofPathMustExist, ofFileMustExist, ofEnableSizing],
    [ofHideReadOnly, ofEnableSizing],
    [ofHideReadOnly, ofPathMustExist, ofOverwritePrompt, ofEnableSizing],
    [ofHideReadOnly, ofPathMustExist, ofEnableSizing]);

function NewFileDialog(const ACaption, Filter, InitialDir: string; Options: TOpenOptions): TSdFileDialog;
begin
  Result := TSdFileDialog.Create(nil);
  Result.Title := ACaption;
  Result.Filter := Filter;
  Result.InitialDir := InitialDir;
  Result.Options := Options;
end;

function BrowseFile(const ACaption, Filter: string; var Value: string; Mode: TBrowseFileMode;
  const DefaultExt, InitialDir, BaseDir: string): Boolean;
var
  Dlg: TSdFileDialog;
  Base: string;
begin
  Base := BaseFolder(BaseDir);
  if InitialDir <> '' then Dlg := NewFileDialog(ACaption, Filter, InitialDir, BrowseOptions[Mode])
  else Dlg := NewFileDialog(ACaption, Filter, BaseDir, BrowseOptions[Mode]);
  try
    Dlg.DefaultExt := DefaultExt;
    Dlg.FileName := FullOptionPath(Value, Base);
    if Mode in [bfSave, bfSaveNoPrompt] then Result := Dlg.ExecuteSave else Result := Dlg.Execute;
    if Result then Value := OptionPath(Dlg.FileName, Base);
  finally
    Dlg.Free;
  end;
end;

function BrowseFile(Box: TControl; const ACaption, Filter: string; Mode: TBrowseFileMode;
  const DefaultExt, InitialDir, BaseDir: string): Boolean;
var
  S: string;
begin
  S := Trim(TBoxText(Box).Text);
  Result := BrowseFile(ACaption, Filter, S, Mode, DefaultExt, InitialDir, BaseDir);
  if Result then TBoxText(Box).Text := S;
end;

procedure TFileDropHook.Prepare;
var
  Edit: HWND;
begin
  if not FControl.HandleAllocated then Exit;
  DragAcceptFiles(FControl.Handle, True);
  if FComplete = 0 then Exit;
  { a combo box's own edit window (none: a drop-down list, nothing to complete) }
  Edit := FControl.Handle;
  if FControl is TCustomComboBox then Edit := GetWindow(Edit, GW_CHILD);
  if Edit <> 0 then SHAutoComplete(Edit, FComplete);
end;

procedure TFileDropHook.Hook(var Message: TMessage);
var
  L: TStringList;
begin
  if Message.Msg = WM_DROPFILES then
  begin
    L := TStringList.Create;
    try
      DroppedFiles(HDROP(Message.WParam), L);
      DragFinish(HDROP(Message.WParam));
      if Assigned(FOnDrop) then FOnDrop(FControl, L)
      else if L.Count > 0 then TBoxText(FControl).Text := L[0];
    finally
      L.Free;
    end;
    Message.Result := 0;
    Exit;
  end;
  FOldProc(Message);
  if Message.Msg = WM_CREATE then Prepare;
end;

function FileDropHook(Control: TWinControl): TFileDropHook;
begin
  Result := TFileDropHook(UIFindHook(Control, TFileDropHook));
  if Result = nil then Result := TFileDropHook.Create(Control, True);
end;

procedure PathBox(Box: TControl; Folder: Boolean);
const
  Kinds: array[Boolean] of DWORD = (SHACF_FILESYS_ONLY, SHACF_FILESYS_ONLY or SHACF_FILESYS_DIRS);
var
  H: TFileDropHook;
begin
  if not (Box is TWinControl) then Exit;
  H := FileDropHook(TWinControl(Box));
  H.FComplete := Kinds[Folder] or SHACF_AUTOSUGGEST_FORCE_ON;
  H.Prepare;
end;

procedure AcceptFileDrops(Control: TWinControl; OnDrop: TFilesDropEvent);
var
  H: TFileDropHook;
begin
  H := FileDropHook(Control);
  H.FOnDrop := OnDrop;
  H.Prepare;
end;

function BrowseFiles(const ACaption, Filter: string; Files: TStrings; const InitialDir: string): Boolean;
var
  Dlg: TSdFileDialog;
begin
  Dlg := NewFileDialog(ACaption, Filter, InitialDir, BrowseOptions[bfOpen] + [ofAllowMultiSelect]);
  try
    Result := Dlg.Execute;
    if Result then Files.Assign(Dlg.Files);
  finally
    Dlg.Free;
  end;
end;

function EditPathListText(Box: TControl; const ACaption: string; Paths: Boolean; const BaseDir: string): Boolean;
var
  S: string;
begin
  S := TBoxText(Box).Text;
  Result := ListEditDialog(GetParentForm(Box), ACaption, Paths, BaseDir, S);
  if Result then TBoxText(Box).Text := S;
end;

procedure LoadComboTable(Form: TComponent; Project: TSdProject; const Table: array of TOptionCombo);
var
  I: Integer;
  C: TComboBox;
begin
  for I := Low(Table) to High(Table) do
  begin
    C := Form.FindComponent(Table[I][0]) as TComboBox;
    LoadHistory(Project.Dof, Table[I][3], C.Items);
    C.Text := Project.OptStr(Table[I][1], Table[I][2], '');
  end;
end;

procedure SaveComboTable(Form: TComponent; Project: TSdProject; const Table: array of TOptionCombo);
var
  I: Integer;
  S: string;
begin
  for I := Low(Table) to High(Table) do
  begin
    S := Trim((Form.FindComponent(Table[I][0]) as TComboBox).Text);
    Project.SetOptStr(Table[I][1], Table[I][2], S);
    AddHistory(Project.Dof, Table[I][3], S);
  end;
end;

procedure LoadCheckTable(Form: TComponent; Project: TSdProject; const Table: array of TOptionCheck);
var
  I: Integer;
begin
  for I := Low(Table) to High(Table) do
    (Form.FindComponent(Table[I].Name) as TCheckBox).Checked :=
      Project.OptInt(Table[I].Section, Table[I].Key, Table[I].Default) <> 0;
end;

procedure SaveCheckTable(Form: TComponent; Project: TSdProject; const Table: array of TOptionCheck);
var
  I: Integer;
begin
  for I := Low(Table) to High(Table) do
    Project.SetOptInt(Table[I].Section, Table[I].Key, Ord((Form.FindComponent(Table[I].Name) as TCheckBox).Checked));
end;

procedure FillFontChoice(Name, Size: TComboBox);
var
  I: Integer;
begin
  Name.Items.BeginUpdate;
  try
    Name.Items.Clear;
    Name.Items.Add('(Default)');
    for I := 0 to Screen.Fonts.Count - 1 do        // not the vertical '@' fonts
      if (Screen.Fonts[I] <> '') and (Screen.Fonts[I][1] <> '@') then Name.Items.Add(Screen.Fonts[I]);
  finally
    Name.Items.EndUpdate;
  end;
  Size.Items.Clear;
  Size.Items.Add('(Default)');
  for I := 8 to 12 do Size.Items.Add(IntToStr(I));
end;

procedure LoadFontChoice(Name, Size: TComboBox; const NameKey, SizeKey: string);
begin
  Name.ItemIndex := Name.Items.IndexOf(Settings.ReadString('UI', NameKey, ''));
  if Name.ItemIndex < 0 then Name.ItemIndex := 0;
  Size.ItemIndex := Size.Items.IndexOf(IntToStr(Settings.ReadInteger('UI', SizeKey, 0)));
  if Size.ItemIndex < 0 then Size.ItemIndex := 0;
end;

procedure SaveFontChoice(Name, Size: TComboBox; const NameKey, SizeKey: string);
begin
  if Name.ItemIndex > 0 then Settings.WriteString('UI', NameKey, Name.Items[Name.ItemIndex])
  else Settings.WriteString('UI', NameKey, '');
  if Size.ItemIndex > 0 then Settings.WriteInteger('UI', SizeKey, StrToIntDef(Size.Items[Size.ItemIndex], 0))
  else Settings.WriteInteger('UI', SizeKey, 0);
end;

function DialogValid(Form: TForm; const Msg: string; Bad: TWinControl; const Title: string): Boolean;
var
  C: TWinControl;
  T: string;
begin
  Result := Msg = '';
  if Result then Exit;
  if Title <> '' then T := Title else T := Form.Caption;
  MessageBox(Form.Handle, PChar(Msg), PChar(T), MB_OK or MB_ICONERROR);
  if Bad = nil then Exit;
  { the pages it is on are shown first }
  C := Bad.Parent;
  while C <> nil do
  begin
    if (C is TTabSheet) and (TTabSheet(C).PageControl <> nil) then TTabSheet(C).PageControl.ActivePage := TTabSheet(C);
    C := C.Parent;
  end;
  if Bad.CanFocus then Bad.SetFocus;
  if Bad is TCustomEdit then TCustomEdit(Bad).SelectAll
  else if Bad is TCustomCombo then TCustomCombo(Bad).SelectAll;
end;

function DialogValid(Form: TForm; Ok: Boolean; const Msg: string; Bad: TWinControl; const Title: string): Boolean;
begin
  if Ok then Result := True else Result := DialogValid(Form, Msg, Bad, Title);
end;

function CanMoveListRow(List: TCustomListBox; Up: Boolean; Lo, Hi: Integer): Boolean;
var
  I, J: Integer;
begin
  I := List.ItemIndex;
  if Up then J := I - 1 else J := I + 1;
  if Hi > List.Items.Count - 1 then Hi := List.Items.Count - 1;
  Result := (I >= Lo) and (I <= Hi) and (J >= Lo) and (J <= Hi);
end;

function MoveListRow(List: TCustomListBox; Up: Boolean; Lo, Hi: Integer): Integer;
begin
  Result := -1;
  if not CanMoveListRow(List, Up, Lo, Hi) then Exit;
  Result := List.ItemIndex;
  { Exchange keeps the rows' data (object, check box) with them and the row chosen }
  if Up then List.Items.Exchange(Result, Result - 1) else List.Items.Exchange(Result, Result + 1);
end;

function RowAfterDelete(Index, Count: Integer): Integer;
begin
  Result := Index;
  if Result >= Count then Result := Count - 1;
end;

function DeleteListRow(List: TCustomListBox): Integer;
begin
  Result := List.ItemIndex;
  if Result < 0 then Exit;
  List.Items.Delete(Result);
  List.ItemIndex := RowAfterDelete(Result, List.Items.Count);
end;

function PageNameFree(Form: TForm; Pages: TStrings; const Name: string; Index: Integer;
  const What: string): Boolean;
var
  K: Integer;
begin
  K := Pages.IndexOf(Name);
  Result := (K < 0) or (K = Index);
  if not Result then
    MessageBox(Form.Handle, PChar(SysUtils.Format('A %s named %s exists already.', [What, Name])), PChar(Form.Caption),
      MB_OK or MB_ICONERROR);
end;

function RunListDialog(D: TForm; List: TListBox; Items: TStrings; var Index: Integer): Boolean;
begin
  try
    List.Items.Assign(Items);
    if (Index >= 0) and (Index < List.Items.Count) then List.ItemIndex := Index
    else if List.Items.Count > 0 then List.ItemIndex := 0;
    Result := (D.ShowModal = mrOk) and (List.ItemIndex >= 0);
    if Result then Index := List.ItemIndex;
  finally
    D.Free;
  end;
end;

procedure HideDialogRow(Form: TForm; const Row: array of TControl; Height: Integer);
var
  I, Top: Integer;
begin
  Top := MaxInt;
  for I := 0 to High(Row) do
    if Row[I] <> nil then
    begin
      if Top = MaxInt then Top := Row[I].Top;
      Row[I].Visible := False;
    end;
  if Top = MaxInt then Exit;
  for I := 0 to Form.ControlCount - 1 do
    if Form.Controls[I].Top > Top then Form.Controls[I].Top := Form.Controls[I].Top - Height;
  Form.ClientHeight := Form.ClientHeight - Height;
end;

function FindDialog(AOwner: TComponent; var Opts: TFindOptionsRec; Replace: Boolean): Boolean;
begin
  if Replace then Result := TReplaceDlg.Execute(AOwner, Opts)
  else Result := TFindDlg.Execute(AOwner, Opts);
end;

function FindInFilesDialog(AOwner: TComponent; var Opts: TFindInFilesRec): Boolean;
begin
  Result := TFindInFilesDlg.Execute(AOwner, Opts);
end;

{ Go to Line Number's check: a number (one out of range goes to the first or the last line) }
function CheckLineNumber(const S: string): string;
var
  N: Integer;
begin
  if TryStrToInt(Trim(S), N) then Result := '' else Result := NotIntegerMsg(S);
end;

function GotoLineDialog(AOwner: TComponent; MaxLine: Integer; var Line: Integer): Boolean;
var
  S: string;
begin
  S := IntToStr(Line);
  Result := InputDialog(AOwner, 'Go to Line Number', '&Enter new line number:', S, CheckLineNumber);
  if Result then
  begin
    Line := StrToInt(Trim(S));
    if Line < 1 then Line := 1;
    if Line > MaxLine then Line := MaxLine;
  end;
end;

function InputDialogWide(AOwner: TComponent; const ACaption, Prompt: string; var Value: WideString): Boolean;
begin
  Result := TInputDlg.ExecuteWide(AOwner, ACaption, Prompt, Value);
end;

function InputDialog(AOwner: TComponent; const ACaption, Prompt: string; var Value: string;
  Check: TInputCheck): Boolean;
begin
  Result := TInputDlg.Execute(AOwner, ACaption, Prompt, Value, Check);
end;

function ListDialog(AOwner: TComponent; const ACaption: string; Items: TStrings; var Index: Integer): Boolean;
begin
  Result := TListDlg.Execute(AOwner, ACaption, Items, Index);
end;

function ProjectOptionsDialog(AOwner: TComponent; Project: TSdProject; Page: Integer;
  var DprSource: string): Boolean;
begin
  Result := TOptionsDlg.ExecuteProject(AOwner, Project, Page, DprSource);
end;

function OptionsDialog(AOwner: TComponent; Section: TOptionsSection; Page: Integer): Boolean;
begin
  Result := TOptionsDlg.Execute(AOwner, Section, Page);
end;

function CodeTemplatesDialog(AOwner: TComponent): Boolean;
begin
  Result := TCodeTemplatesDlg.Execute(AOwner);
end;

function AddCodeTemplateDialog(AOwner: TComponent; const ACaption: string; var AName, ADesc: string): Boolean;
begin
  Result := TAddCodeTemplateDlg.Execute(AOwner, ACaption, AName, ADesc);
end;

function AddTodoDialog(AOwner: TComponent; Mode: TTodoDlgMode; Owners, Categories: TStrings;
  var V: TTodoValues): Boolean;
begin
  Result := TAddTodoDlg.Execute(AOwner, Mode, Owners, Categories, V);
end;

function NotIntegerMsg(const S: string): string;
begin
  Result := SysUtils.Format('''%s'' is not a valid integer value', [S]);
end;

function CheckNumber(E: TEdit; Low, High: Integer; const RangeMsg: string; out N: Integer): string;
begin
  Result := '';
  if not TryStrToInt(Trim(E.Text), N) then Result := NotIntegerMsg(E.Text)
  else if (N < Low) or (N > High) then Result := RangeMsg;
end;

function SizeValid(Form: TForm; EW, EH: TEdit; MaxSize: Integer): Boolean;
var
  W, H: Integer;
  Msg: string;
begin
  W := StrToIntDef(Trim(EW.Text), 0);
  H := StrToIntDef(Trim(EH.Text), 0);
  Msg := SysUtils.Format('The size is from 1 to %d pixels.', [MaxSize]);
  Result := DialogValid(Form, (W >= 1) and (W <= MaxSize), Msg, EW) and
    DialogValid(Form, (H >= 1) and (H <= MaxSize), Msg, EH);
end;

function TodoFilterDialog(AOwner: TComponent; const Prompt: string; Values: TStrings; Shown: TList;
  Hidden: TStrings): Boolean;
begin
  Result := TTodoFilterDlg.Execute(AOwner, Prompt, Values, Shown, Hidden);
end;

function TableOptionsDialog(AOwner: TComponent; Table: TSdTodoTable): Boolean;
begin
  Result := TTableOptionsDlg.Execute(AOwner, Table);
end;

function RunParamsDialog(AOwner: TComponent; Project: TSdProject): TRunParamsResult;
begin
  Result := TRunParamsDlg.Execute(AOwner, Project);
end;

procedure AboutDialog(AOwner: TComponent);
begin
  TAboutDlg.Execute(AOwner);
end;

function CompileWithProgress(AOwner: TComponent; Compiler: TSdCompiler; const ProjectFile, Dcc32, Args,
  WorkDir, SearchPath: string; AutoClose: Boolean): Boolean;
begin
  Result := TCompileDlg.Execute(AOwner, Compiler, ProjectFile, Dcc32, Args, WorkDir, SearchPath, AutoClose);
end;


function NewImageDialog(AOwner: TComponent; Kind: TSdImageKind; var Sizes: TSdSizes; var Bits: Integer;
  OfferScale: Boolean; var Scale: Boolean): Boolean;
begin
  Result := TNewImageDlg.Execute(AOwner, Kind, Sizes, Bits, OfferScale, Scale);
end;

function ImageSizeDialog(AOwner: TComponent; Kind: TSdImageKind; var W, H, Mode: Integer): Boolean;
begin
  Result := TImageSizeDlg.Execute(AOwner, Kind, W, H, Mode);
end;

function ImageTextDialog(AOwner: TComponent; var Text: string; Font: TFont; var Smooth: Boolean): Boolean;
begin
  Result := TImageTextDlg.Execute(AOwner, Text, Font, Smooth);
end;

function ColorEditDialog(AOwner: TComponent; const ACaption: string; var Color: Cardinal; Alpha: Boolean): Boolean;
begin
  Result := TColorEditDlg.Execute(AOwner, ACaption, Color, Alpha);
end;

function ResPropsDialog(AOwner: TComponent; const ACaption: string; TypeEditable, NameEditable: Boolean;
  var AType, AName: string; var Language: Integer; Check: TResPropsCheck): Boolean;
begin
  Result := TResPropsDlg.Execute(AOwner, ACaption, TypeEditable, NameEditable, AType, AName, Language, Check);
end;

end.
