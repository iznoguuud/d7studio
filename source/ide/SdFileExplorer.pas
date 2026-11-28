{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdFileExplorer;

{ D7 Studio - the File Explorer view: the files and folders under the active project's folder and
  under the folders the user pins, as a tree whose folders are read when they are opened (folders
  first, then the files, by name). What it shows: a filter box over the tree (a text, or a mask with *
  and ?, on the files' names), Show's switches - Delphi's files only, the build output (units,
  programs, packages, maps, backups, __history), hidden files and those whose names begin with a dot.
  The files of the project group's projects are in bold, an open file with unsaved changes has the
  file tabs' green dot. The folders shown are watched (FindFirstChangeNotification): a file made,
  renamed or deleted outside the IDE shows at the next tick of Watch, also the IDE's own.

  A double click or Enter opens a file - in the IDE what it opens (a project as a project), any other
  file with its program in Windows; a file dragged out of the tree goes where Explorer's would (the
  IDE's window opens it, the Project Manager adds it). The menu: Open, Open with Windows, Add to
  Project, New File, New Folder, Rename (a unit through Rename Unit), Delete (to the Recycle Bin),
  Copy Path, Show in Explorer, Command Prompt Here, Find in Files Here, the pinned folders, Locate
  Active File and Follow the Editor (the active file chosen in the tree as the file area changes).
  What reaches beyond the view the IDE does (TFileExplorerHost). A form made once, docked by the IDE:
  its tool bar goes to its panel of the dock (TSdDockPanel.ToolBar), the dock's commands to the end
  of its menu (TMainForm.AddDockItems); its settings in [File Explorer]. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, ComCtrls, CommCtrl, ToolWin, Menus,
  ActnList, StdCtrls, ExtCtrls, IniFiles,
  SdUI, SdIcons, SdDock;

type
  { what the IDE knows of a file: a project or unit of the project group, open in the file area,
    changed there and not saved }
  TFxFileState = (fxInGroup, fxOpen, fxModified);
  TFxFileStates = set of TFxFileState;

  { what the view asks of the IDE }
  TFileExplorerHost = class
  public
    { the active project's folder, with no backslash at its end ('': no project) }
    function ProjectFolder: string; virtual; abstract;
    { the file of the page shown ('': none) }
    function ActiveFile: string; virtual; abstract;
    function FileState(const FileName: string): TFxFileStates; virtual; abstract;
    { an open page's file lies in Folder or below it }
    function HasOpenFiles(const Folder: string): Boolean; virtual; abstract;
    { FileName (a unit, a resource script) can go into the active project, which lacks it }
    function CanAddToProject(const FileName: string): Boolean; virtual; abstract;
    procedure AddToProject(const FileName: string); virtual; abstract;
    { the file opened in the IDE: a project, package or group as a project, any other as a page }
    procedure OpenFile(const FileName: string); virtual; abstract;
    { the unit renamed by the Rename Unit refactoring (it asks for the name) }
    procedure RenameUnit(const FileName: string); virtual; abstract;
    { a file or folder has another name now: the pages of its files follow }
    procedure Renamed(const OldName, NewName: string; Folder: Boolean); virtual; abstract;
    { Search | Find in Files on the folder and the folders below it }
    procedure FindInFolder(const Folder: string); virtual; abstract;
  end;

  TFileExplorerView = class(TForm)
    Bar: TToolBar;
    tbRefresh: TToolButton;
    tbLocate: TToolButton;
    tbPin: TToolButton;
    tbShow: TToolButton;
    FilterEdit: TEdit;
    Tree: TTreeView;
    Watch: TTimer;
    Actions: TActionList;
    aFxOpen: TAction;
    aFxOpenShell: TAction;
    aFxAddToProject: TAction;
    aFxNewFile: TAction;
    aFxNewFolder: TAction;
    aFxRename: TAction;
    aFxDelete: TAction;
    aFxCopyPath: TAction;
    aFxShowInExplorer: TAction;
    aFxCommandPrompt: TAction;
    aFxFindInFiles: TAction;
    aFxPinFolder: TAction;
    aFxPinSelected: TAction;
    aFxUnpin: TAction;
    aFxLocate: TAction;
    aFxFollow: TAction;
    aFxCollapseAll: TAction;
    aFxRefresh: TAction;
    aFxShowMenu: TAction;
    aFxDelphiOnly: TAction;
    aFxShowOutput: TAction;
    aFxShowHidden: TAction;
    FxPopup: TPopupMenu;
    pmOpen: TMenuItem;
    pmOpenShell: TMenuItem;
    pmAddToProject: TMenuItem;
    pmSep1: TMenuItem;
    pmNewFile: TMenuItem;
    pmNewFolder: TMenuItem;
    pmRename: TMenuItem;
    pmDelete: TMenuItem;
    pmSep2: TMenuItem;
    pmCopyPath: TMenuItem;
    pmShowInExplorer: TMenuItem;
    pmCommandPrompt: TMenuItem;
    pmFindInFiles: TMenuItem;
    pmSep3: TMenuItem;
    pmPinSelected: TMenuItem;
    pmPinFolder: TMenuItem;
    pmUnpin: TMenuItem;
    pmSep4: TMenuItem;
    pmLocate: TMenuItem;
    pmFollow: TMenuItem;
    pmCollapseAll: TMenuItem;
    pmRefresh: TMenuItem;
    pmShow: TMenuItem;
    pmShowDelphiOnly: TMenuItem;
    pmShowOutput: TMenuItem;
    pmShowHidden: TMenuItem;
    ShowPopup: TPopupMenu;
    spDelphiOnly: TMenuItem;
    spShowOutput: TMenuItem;
    spShowHidden: TMenuItem;
    procedure ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
    procedure Command(Sender: TObject);
    procedure FilterEditChange(Sender: TObject);
    procedure FilterEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MenuPopup(Sender: TObject);
    procedure TreeChange(Sender: TObject; Node: TTreeNode);
    procedure TreeDblClick(Sender: TObject);
    procedure TreeEdited(Sender: TObject; Node: TTreeNode; var S: string);
    procedure TreeEditing(Sender: TObject; Node: TTreeNode; var AllowEdit: Boolean);
    procedure TreeExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
    procedure TreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure WatchTimer(Sender: TObject);
  private
    FHost: TFileExplorerHost;
    FPanel: TSdDockPanel;
    FPinned: TStringList;            // the pinned folders, in their order
    FProjectDir: string;             // the project's folder the tree shows ('' none)
    FWatches: array of THandle;      // a change notification for every root shown
    FDirty: Boolean;                 // a watched folder changed while the view was hidden
    FEditing: Boolean;               // Rename edits the node's name (no edit by a click)
    FFollow: Boolean;
    FOnMenuPopup: TNotifyEvent;
    procedure CloseWatches;
    procedure DeleteNodes(N: TTreeNode; ChildrenOnly: Boolean);
    procedure OpenWatches;
    { the roots the tree must show: the project's folder, then the pinned ones (not it twice) }
    procedure WantedRoots(Paths: TStrings; Kinds: TList);
    function SameRoots: Boolean;
    procedure RebuildRoots;
    { the entries of a folder node again from the disk, in its order, the nodes kept where they are
      still shown (opened, chosen); its open folders the same way }
    procedure SyncFolder(N: TTreeNode);
    procedure SyncAll;
    function AddNode(Parent, Before: TTreeNode; Item: TObject): TTreeNode;
    procedure MarkNode(N: TTreeNode);
    procedure MarkAll;
    procedure SetNodeIcon(N: TTreeNode);
    { the folders read again from the disk now (Refresh, after a change made here) }
    procedure Resync;
    { the folder of the node chosen - itself, or the folder its file is in ('': none) }
    function SelectedFolder: string;
    function SelectedPath: string;
    function SelectedIsFolder: Boolean;
    function SelectedIsRoot: Boolean;
    function NodePath(N: TTreeNode): string;
    function NodeIsFolder(N: TTreeNode): Boolean;
    { the node of Path among the nodes shown, the folders on its way opened; nil: not shown }
    function FindPath(const Path: string): TTreeNode;
    { Path's node chosen and brought into view; False: it is not shown }
    function Reveal(const Path: string): Boolean;
    { the file with its program in Windows, a message when it has none }
    procedure OpenWithWindows(const Path: string);
    { Name can be a file's or folder's name; False after a message }
    function ValidName(const Name: string): Boolean;
    procedure Choose(N: TTreeNode);
    procedure RunCommand(A: TAction);
    procedure OpenNode(N: TTreeNode);
    procedure NewEntry(Folder: Boolean);
    procedure DeleteSelected;
    procedure PinFolder(const Dir: string);
    procedure Unpin(const Dir: string);
    procedure Say(const Text: string);
    function Ask(const Text: string; Flags: UINT): Integer;
    procedure SetFollow(Value: Boolean);
    procedure StartDrag(N: TTreeNode);
    procedure DrawMark(N: TTreeNode; DC: HDC);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Load(Ini: TCustomIniFile);
    procedure Save(Ini: TCustomIniFile);
    { the active project or the project group changed: the project's root, the files' marks }
    procedure ProjectChanged;
    { a file was opened, closed, changed or saved: its mark }
    procedure FilesChanged;
    { the page shown changed: with Follow the Editor its file is chosen in the tree }
    procedure ActiveFileChanged;
    { the view is shown: what changed while it was hidden }
    procedure Shown;
    { Locate Active File: the file shown in the file area chosen in the tree; Quiet: no message when
      it is not shown there }
    procedure LocateActive(Quiet: Boolean);
    property Host: TFileExplorerHost read FHost write FHost;
    { the dock's panel of the view: its status line shows the chosen node's file }
    property Panel: TSdDockPanel read FPanel write FPanel;
    property Follow: Boolean read FFollow write SetFollow;
    property Pinned: TStringList read FPinned;
    { a menu opens (before the view's states): the dock commands' states }
    property OnMenuPopup: TNotifyEvent read FOnMenuPopup write FOnMenuPopup;
  end;

implementation

uses
  Clipbrd, SdFileNames, SdEncoding, SdDialogs, SdCompBar, SdProject;

{$R *.dfm}

const
  FxSection = 'File Explorer';
  { the extensions of Delphi's files - Show | Delphi Files Only keeps these }
  DelphiExts = '.pas.dpr.dpk.dfm.inc.bpg.rc.res.dof.dcr.tlb.ridl.dci.dro.dmt.todo.';
  { the build output, hidden unless Show | Build Output (and every '.~*': Delphi's backups) }
  OutputExts = '.dcu.dcp.drc.map.tds.obj.exe.dll.bpl.ocx.dsk.ddp.identcache.local.stat.';
  OutputFolders = '__history.__recovery.';
  { what a double click gives to Windows rather than to the IDE's editor }
  ShellExts = '.exe.dll.bpl.ocx.dcu.dcp.obj.lib.res.drc.tds.zip.7z.rar.png.jpg.jpeg.gif.bmp.ico.cur.pdf.chm.' +
    'hlp.doc.docx.xls.xlsx.ppt.pptx.wav.mp3.mp4.avi.ttf.otf.';

type
  { what a root is: the project's folder or a pinned one }
  TFxRootKind = (rkNone, rkProject, rkPinned);

  { a node's file or folder (TTreeNode.Data, freed by DeleteNodes) }
  TFxItem = class
    Name: string;          // the name shown
    Path: string;          // usable full name, no backslash at its end
    Folder: Boolean;
    Loaded: Boolean;       // a folder's entries have been read
    Root: TFxRootKind;
  end;

  { the tree's drag of a file - Windows' own (TVN_BEGINDRAG), not the VCL's -, the mark drawn
    after an item (CDDS_ITEMPOSTPAINT, into the paint's DC: the tree paints double-buffered) and the
    place of the last double click (its message's) }
  TFxTreeHook = class(TUIWindowHook)
  private
    FDblPos: TPoint;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

function HasExt(const List, FileName: string): Boolean;
var
  E: string;
begin
  E := LowerCase(ExtractFileExt(FileName));
  Result := (E <> '') and (Pos(E + '.', List) > 0);
end;

{ folders first, then the names without case, then with it: the order of a folder's nodes }
function CompareItems(A, B: TFxItem): Integer;
begin
  Result := Ord(B.Folder) - Ord(A.Folder);
  if Result = 0 then Result := AnsiCompareText(A.Name, B.Name);
  if Result = 0 then Result := CompareStr(A.Name, B.Name);
end;

function SortItems(List: TStringList; Index1, Index2: Integer): Integer;
begin
  Result := CompareItems(TFxItem(List.Objects[Index1]), TFxItem(List.Objects[Index2]));
end;

{ the icon of a file by its kind }
function FileIcon(const FileName: string): TSdIcon;
var
  E: string;
begin
  E := LowerCase(ExtractFileExt(FileName));
  if (E = '.pas') or (E = '.inc') then Result := iiUnit
  else if E = '.dfm' then Result := iiForm
  else if E = '.dpr' then Result := iiProject
  else if E = '.dpk' then Result := iiPmPackage
  else if E = '.bpg' then Result := iiPmGroup
  else if (E = '.res') or (E = '.rc') or (E = '.dcr') then Result := iiResources
  else if (E = '.tlb') or (E = '.ridl') then Result := iiTypeLibrary
  else if HasExt('.txt.log.ini.dof.cfg.dsk.todo.csv.', FileName) then Result := iiTextFile
  else if E = '.md' then Result := iiMarkdownFile
  else if HasExt('.htm.html.css.js.', FileName) then Result := iiHtmlFile
  else if HasExt('.xml.xsd.manifest.', FileName) then Result := iiXmlBinding
  else if HasExt('.bmp.png.jpg.jpeg.gif.', FileName) then Result := iiResBitmap
  else if E = '.ico' then Result := iiResIcon
  else if E = '.cur' then Result := iiResCursor
  else if HasExt('.bat.cmd.ps1.', FileName) then Result := iiBatchFile
  else if E = '.exe' then Result := iiExeFile
  else if HasExt('.dll.bpl.ocx.dcp.', FileName) then Result := iiLibrary
  else if HasExt('.dcu.obj.drc.map.tds.', FileName) then Result := iiResData
  else if HasExt('.zip.7z.rar.', FileName) then Result := iiArchiveFile
  else if HasExt('.chm.hlp.', FileName) then Result := iiHelp
  else Result := iiFile;
end;

function ItemOf(N: TTreeNode): TFxItem;
begin
  if N <> nil then Result := TFxItem(N.Data) else Result := nil;
end;

{ ---------------------------------------------------------------- TFxTreeHook }

procedure TFxTreeHook.Hook(var Message: TMessage);
var
  Code: Integer;
  N: TTreeNode;
  CD: PNMTVCustomDraw;
begin
  if Message.Msg = WM_LBUTTONDBLCLK then
    FDblPos := Point(SmallInt(LoWord(Message.LParam)), SmallInt(HiWord(Message.LParam)))
  else if Message.Msg = CN_NOTIFY then
  begin
    Code := TWMNotify(Message).NMHdr^.code;
    if Code = NM_CUSTOMDRAW then
    begin
      FOldProc(Message);
      CD := PNMTVCustomDraw(Message.LParam);
      case CD^.nmcd.dwDrawStage of
        CDDS_PREPAINT: Message.Result := Message.Result or CDRF_NOTIFYITEMDRAW;
        CDDS_ITEMPREPAINT: Message.Result := Message.Result or CDRF_NOTIFYPOSTPAINT;
        CDDS_ITEMPOSTPAINT:
          begin
            N := TTreeView(FControl).Items.GetNode(HTREEITEM(CD^.nmcd.dwItemSpec));
            if N <> nil then TFileExplorerView(FControl.Owner).DrawMark(N, CD^.nmcd.hdc);
          end;
      end;
      Exit;
    end;
    if (Code = TVN_BEGINDRAGA) or (Code = TVN_BEGINDRAGW) then
    begin
      N := TTreeView(FControl).Items.GetNode(PNMTreeView(Message.LParam)^.itemNew.hItem);
      if N <> nil then TFileExplorerView(FControl.Owner).StartDrag(N);
      Message.Result := 0;
      Exit;
    end;
  end;
  FOldProc(Message);
end;

{ ---------------------------------------------------------------- TFileExplorerView }

constructor TFileExplorerView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form docked as a child keeps its own font }
  UIApplyFont(Self);
  InitIcons;
  { the IDE's icons: the main form's list, there at run time only }
  Actions.Images := IconList;
  Bar.Images := IconList;
  FxPopup.Images := IconList;
  ShowPopup.Images := IconList;
  Tree.Images := IconList;
  UIOwnerDrawMenus(Self);
  UIFlatBorder(FilterEdit);
  UICueBanner(FilterEdit, UIFilterCue);
  TFxTreeHook.Create(Tree, True);
  FPinned := TStringList.Create;
end;

destructor TFileExplorerView.Destroy;
begin
  CloseWatches;
  Tree.OnChange := nil;
  DeleteNodes(nil, False);
  FPinned.Free;
  inherited;
end;

{ No flicker: the box and the tree fill the view, which the dock resizes with them - the view
  paints nothing over them (WS_CLIPCHILDREN) and, a form, has no CS_HREDRAW / CS_VREDRAW }
procedure TFileExplorerView.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

{ the box, the tree and the gap between them (Paint) cover the whole view: nothing to erase }
procedure TFileExplorerView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

const
  FilterGap = 2;          // between the filter box and the tree, as the Components view's

procedure TFileExplorerView.Paint;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(Rect(0, FilterEdit.Height, ClientWidth, Tree.Top));
end;

procedure TFileExplorerView.Resize;
begin
  inherited;
  UIMoveControls([FilterEdit, Tree], [Rect(0, 0, ClientWidth, FilterEdit.Height),
    Rect(0, FilterEdit.Height + FilterGap, ClientWidth, ClientHeight)]);
end;

procedure TFileExplorerView.Load(Ini: TCustomIniFile);
var
  I, N: Integer;
  S: string;
begin
  aFxDelphiOnly.Checked := Ini.ReadBool(FxSection, 'DelphiFilesOnly', False);
  aFxShowOutput.Checked := Ini.ReadBool(FxSection, 'ShowBuildOutput', False);
  aFxShowHidden.Checked := Ini.ReadBool(FxSection, 'ShowHidden', False);
  FFollow := Ini.ReadBool(FxSection, 'FollowEditor', False);
  aFxFollow.Checked := FFollow;
  FPinned.Clear;
  N := Ini.ReadInteger(FxSection, 'Pinned', 0);
  for I := 1 to N do
  begin
    S := Ini.ReadString(FxSection, 'Pinned' + IntToStr(I), '');
    if S <> '' then FPinned.Add(ExcludeTrailingPathDelimiter(S));
  end;
end;

procedure TFileExplorerView.Save(Ini: TCustomIniFile);
var
  I: Integer;
begin
  Ini.EraseSection(FxSection);
  Ini.WriteBool(FxSection, 'DelphiFilesOnly', aFxDelphiOnly.Checked);
  Ini.WriteBool(FxSection, 'ShowBuildOutput', aFxShowOutput.Checked);
  Ini.WriteBool(FxSection, 'ShowHidden', aFxShowHidden.Checked);
  Ini.WriteBool(FxSection, 'FollowEditor', FFollow);
  Ini.WriteInteger(FxSection, 'Pinned', FPinned.Count);
  for I := 0 to FPinned.Count - 1 do Ini.WriteString(FxSection, 'Pinned' + IntToStr(I + 1), FPinned[I]);
end;

{ --- the roots and the watches --- }

procedure TFileExplorerView.WantedRoots(Paths: TStrings; Kinds: TList);
var
  I: Integer;
begin
  if FProjectDir <> '' then
  begin
    Paths.Add(FProjectDir);
    Kinds.Add(Pointer(rkProject));
  end;
  for I := 0 to FPinned.Count - 1 do
    if (Paths.IndexOf(FPinned[I]) < 0) then
    begin
      Paths.Add(FPinned[I]);
      Kinds.Add(Pointer(rkPinned));
    end;
end;

function TFileExplorerView.SameRoots: Boolean;
var
  Paths: TStringList;
  Kinds: TList;
  N: TTreeNode;
  I: Integer;
begin
  Paths := TStringList.Create;
  Kinds := TList.Create;
  try
    WantedRoots(Paths, Kinds);
    N := Tree.Items.GetFirstNode;
    I := 0;
    while (N <> nil) and (I < Paths.Count) and SameText(ItemOf(N).Path, Paths[I]) and
      (ItemOf(N).Root = TFxRootKind(Kinds[I])) do
    begin
      N := N.GetNextSibling;
      Inc(I);
    end;
    Result := (N = nil) and (I = Paths.Count);
  finally
    Kinds.Free;
    Paths.Free;
  end;
end;

procedure TFileExplorerView.CloseWatches;
var
  I: Integer;
begin
  for I := 0 to High(FWatches) do
    if FWatches[I] <> INVALID_HANDLE_VALUE then FindCloseChangeNotification(FWatches[I]);
  FWatches := nil;
end;

procedure TFileExplorerView.OpenWatches;
var
  N: TTreeNode;
  H: THandle;
begin
  CloseWatches;
  N := Tree.Items.GetFirstNode;
  while N <> nil do
  begin
    H := FindFirstChangeNotificationW(PWideChar(WidePath(IncludeTrailingPathDelimiter(ItemOf(N).Path))), True,
      FILE_NOTIFY_CHANGE_FILE_NAME or FILE_NOTIFY_CHANGE_DIR_NAME);
    if H <> INVALID_HANDLE_VALUE then
    begin
      SetLength(FWatches, Length(FWatches) + 1);
      FWatches[High(FWatches)] := H;
    end;
    N := N.GetNextSibling;
  end;
end;

{ a change in a watched folder: its folders synchronized once the changes have stopped for a tick
  (a build writes many files) - at once while the view shows, else when it is shown }
procedure TFileExplorerView.WatchTimer(Sender: TObject);
var
  I: Integer;
  Changed: Boolean;
begin
  Changed := False;
  for I := 0 to High(FWatches) do
    while WaitForSingleObject(FWatches[I], 0) = WAIT_OBJECT_0 do
    begin
      Changed := True;
      if not FindNextChangeNotification(FWatches[I]) then Break;
    end;
  if Changed then FDirty := True
  else if FDirty and Showing and not Tree.IsEditing then Resync;
end;

{ the roots again; the folders that were open open again and the node chosen is chosen again }
procedure TFileExplorerView.RebuildRoots;
var
  Paths, Opened: TStringList;
  Kinds: TList;
  I: Integer;
  N: TTreeNode;
  It: TFxItem;
  Sel: string;

  procedure Reopen(N: TTreeNode);
  var
    C: TTreeNode;
  begin
    if (N = nil) or (Opened.IndexOf(ItemOf(N).Path) < 0) then Exit;
    N.Expand(False);
    C := N.GetFirstChild;
    while C <> nil do
    begin
      if ItemOf(C).Folder then Reopen(C);
      C := C.GetNextSibling;
    end;
  end;

begin
  Paths := TStringList.Create;
  Kinds := TList.Create;
  Opened := TStringList.Create;
  Opened.Sorted := True;
  Tree.Items.BeginUpdate;
  try
    N := Tree.Items.GetFirstNode;
    while N <> nil do
    begin
      if N.Expanded then Opened.Add(ItemOf(N).Path);
      N := N.GetNext;
    end;
    Sel := SelectedPath;
    DeleteNodes(nil, False);
    WantedRoots(Paths, Kinds);
    for I := 0 to Paths.Count - 1 do
    begin
      It := TFxItem.Create;
      It.Path := Paths[I];
      It.Name := ExtractFileName(Paths[I]);
      if It.Name = '' then It.Name := Paths[I];        // a drive's root
      It.Folder := True;
      It.Root := TFxRootKind(Kinds[I]);
      N := AddNode(nil, nil, It);
      { the project's folder opens the first time it is shown }
      if (It.Root = rkProject) and (Opened.Count = 0) then Opened.Add(It.Path);
      Reopen(N);
    end;
    if Sel <> '' then Reveal(Sel);
  finally
    Tree.Items.EndUpdate;
    Opened.Free;
    Kinds.Free;
    Paths.Free;
  end;
  OpenWatches;
  TreeChange(Tree, Tree.Selected);
end;

function TFileExplorerView.AddNode(Parent, Before: TTreeNode; Item: TObject): TTreeNode;
var
  It: TFxItem;
begin
  It := TFxItem(Item);
  if Before <> nil then Result := Tree.Items.InsertObject(Before, It.Name, It)
  else Result := Tree.Items.AddChildObject(Parent, It.Name, It);
  SetNodeIcon(Result);
  { a folder can be opened until it is read and found empty }
  Result.HasChildren := It.Folder;
  if not It.Folder then MarkNode(Result);
end;

{ --- a folder's entries --- }

procedure TFileExplorerView.SyncFolder(N: TTreeNode);
var
  Dir: TFxItem;
  L: TStringList;
  FD: TWin32FindDataW;
  H: THandle;
  Name: string;
  Lost, IsDir: Boolean;
  It: TFxItem;
  Filter: TSdNameFilter;
  C, Next: TTreeNode;
  I, Cmp: Integer;
begin
  Dir := ItemOf(N);
  if (Dir = nil) or not Dir.Folder then Exit;
  Dir.Loaded := True;
  L := TStringList.Create;
  Filter := TSdNameFilter.Create(FilterEdit.Text);
  try
    H := FindFirstFileW(PWideChar(WidePath(Dir.Path) + '\*'), FD);
    if H <> INVALID_HANDLE_VALUE then
    begin
      repeat
        Name := FromWide(WideString(FD.cFileName), CP_ACP, Lost);
        if (Name = '.') or (Name = '..') then Continue;
        IsDir := FD.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY <> 0;
        { hidden and system entries, and names that begin with a dot (.git) }
        if not aFxShowHidden.Checked and ((FD.dwFileAttributes and (FILE_ATTRIBUTE_HIDDEN or FILE_ATTRIBUTE_SYSTEM) <> 0) or
          (Name[1] = '.')) then
          Continue;
        if not aFxShowOutput.Checked then
          if IsDir then
          begin
            if Pos(LowerCase(Name) + '.', OutputFolders) > 0 then Continue;
          end
          else if HasExt(OutputExts, Name) or (Copy(ExtractFileExt(Name), 1, 2) = '.~') then
            Continue;
        if not IsDir and aFxDelphiOnly.Checked and not HasExt(DelphiExts, Name) then Continue;
        if not IsDir and (Filter.Match(Name) = 0) then Continue;
        It := TFxItem.Create;
        It.Name := Name;
        It.Path := UsablePath(WidePath(Dir.Path) + '\' + WideString(FD.cFileName));
        It.Folder := IsDir;
        L.AddObject(Name, It);
      until not FindNextFileW(H, FD);
      Windows.FindClose(H);
    end;
    L.CustomSort(SortItems);
    { the nodes against the entries, both in their order: a node kept, made, or gone }
    C := N.GetFirstChild;
    I := 0;
    while (I < L.Count) or (C <> nil) do
    begin
      if C = nil then Cmp := -1
      else if I >= L.Count then Cmp := 1
      else Cmp := CompareItems(TFxItem(L.Objects[I]), ItemOf(C));
      if Cmp = 0 then
      begin
        L.Objects[I].Free;
        if ItemOf(C).Folder then
        begin
          if ItemOf(C).Loaded then SyncFolder(C);
        end
        else
          MarkNode(C);
        C := C.GetNextSibling;
        Inc(I);
      end
      else if Cmp < 0 then
      begin
        AddNode(N, C, L.Objects[I]);
        Inc(I);
      end
      else
      begin
        Next := C.GetNextSibling;
        DeleteNodes(C, False);
        C := Next;
      end;
    end;
    N.HasChildren := N.Count > 0;
  finally
    Filter.Free;
    L.Free;
  end;
end;

procedure TFileExplorerView.SyncAll;
var
  N: TTreeNode;
begin
  if not SameRoots then
  begin
    RebuildRoots;
    Exit;
  end;
  Tree.Items.BeginUpdate;
  try
    N := Tree.Items.GetFirstNode;
    while N <> nil do
    begin
      if ItemOf(N).Loaded then SyncFolder(N);
      N := N.GetNextSibling;
    end;
  finally
    Tree.Items.EndUpdate;
  end;
  TreeChange(Tree, Tree.Selected);
end;

{ a root's icon by its kind, a folder's, a file's by its kind }
procedure TFileExplorerView.SetNodeIcon(N: TTreeNode);
var
  It: TFxItem;
begin
  It := ItemOf(N);
  if It.Root = rkProject then N.ImageIndex := IconIndex(iiOpenProject)
  else if It.Root = rkPinned then N.ImageIndex := IconIndex(iiPinnedFolder)
  else if It.Folder then N.ImageIndex := IconIndex(iiFolder)
  else N.ImageIndex := IconIndex(FileIcon(It.Name));
  N.SelectedIndex := N.ImageIndex;
end;

procedure TFileExplorerView.Resync;
begin
  FDirty := False;
  SyncAll;
end;

{ a file of the project group in bold - a state of the item in the tree's window, set again when
  the group changes }
procedure TFileExplorerView.MarkNode(N: TTreeNode);
begin
  if (FHost <> nil) and not ItemOf(N).Folder then UITreeSetBold(N, fxInGroup in FHost.FileState(ItemOf(N).Path));
end;

procedure TFileExplorerView.TreeExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
begin
  if not ItemOf(Node).Loaded then
  begin
    Tree.Items.BeginUpdate;
    try
      SyncFolder(Node);
    finally
      Tree.Items.EndUpdate;
    end;
  end;
  AllowExpansion := Node.Count > 0;
end;

{ nodes deleted with their items: N and every node below it, only the nodes below it (ChildrenOnly), or
  with N = nil every node. OnDeletion cannot free the items: when the tree's window is made again (the
  view docked, floated or moved) TCustomTreeView.DestroyWnd keeps the nodes with their Data, clears
  them - OnDeletion runs for each - and CreateWnd makes them again with the same Data }
procedure TFileExplorerView.DeleteNodes(N: TTreeNode; ChildrenOnly: Boolean);
var
  Items: TList;
  C: TTreeNode;
  I: Integer;
begin
  Items := TList.Create;
  try
    if N = nil then C := Tree.Items.GetFirstNode else C := N.GetFirstChild;
    while (C <> nil) and ((N = nil) or C.HasAsParent(N)) do
    begin
      Items.Add(C.Data);
      C := C.GetNext;
    end;
    if N = nil then
      Tree.Items.Clear
    else if ChildrenOnly then
      N.DeleteChildren
    else
    begin
      Items.Add(N.Data);
      N.Delete;
    end;
    { after the nodes: deleting the chosen one reads its item (OnChange) }
    for I := 0 to Items.Count - 1 do TObject(Items[I]).Free;
  finally
    Items.Free;
  end;
end;

{ an open file with unsaved changes: the file tabs' green dot after its name }
procedure TFileExplorerView.DrawMark(N: TTreeNode; DC: HDC);
var
  R: TRect;
begin
  if (FHost = nil) or (ItemOf(N) = nil) or ItemOf(N).Folder or not (fxModified in FHost.FileState(ItemOf(N).Path)) then
    Exit;
  R := N.DisplayRect(True);
  R.Left := R.Right + 2;
  R.Right := R.Left + R.Bottom - R.Top;
  UIDrawTabDot(DC, R, True);
end;

{ --- the chosen node --- }

function TFileExplorerView.NodePath(N: TTreeNode): string;
begin
  if ItemOf(N) <> nil then Result := ItemOf(N).Path else Result := '';
end;

function TFileExplorerView.NodeIsFolder(N: TTreeNode): Boolean;
begin
  Result := (ItemOf(N) <> nil) and ItemOf(N).Folder;
end;

function TFileExplorerView.SelectedPath: string;
begin
  Result := NodePath(Tree.Selected);
end;

function TFileExplorerView.SelectedIsFolder: Boolean;
begin
  Result := NodeIsFolder(Tree.Selected);
end;

function TFileExplorerView.SelectedIsRoot: Boolean;
begin
  Result := (Tree.Selected <> nil) and (Tree.Selected.Parent = nil);
end;

function TFileExplorerView.SelectedFolder: string;
begin
  Result := SelectedPath;
  if (Result <> '') and not SelectedIsFolder then Result := ExtractFileDir(Result);
end;

procedure TFileExplorerView.Choose(N: TTreeNode);
begin
  if N = nil then Exit;
  N.Selected := True;
  N.Focused := True;
  N.MakeVisible;
end;

function TFileExplorerView.FindPath(const Path: string): TTreeNode;
var
  N, C: TTreeNode;
  Rest, Part: string;
  P: Integer;
begin
  Result := nil;
  { the root it lies under (the longest: a pinned folder inside the project's) }
  C := Tree.Items.GetFirstNode;
  N := nil;
  while C <> nil do
  begin
    if (SameText(Path, ItemOf(C).Path) or PathIsUnder(Path, ItemOf(C).Path)) and
      ((N = nil) or (Length(ItemOf(C).Path) > Length(ItemOf(N).Path))) then
      N := C;
    C := C.GetNextSibling;
  end;
  if N = nil then Exit;
  Rest := Copy(Path, Length(ItemOf(N).Path) + 2, MaxInt);
  Tree.Items.BeginUpdate;
  try
    while Rest <> '' do
    begin
      P := Pos('\', Rest);
      if P = 0 then P := Length(Rest) + 1;
      Part := Copy(Rest, 1, P - 1);
      Delete(Rest, 1, P);
      if not ItemOf(N).Loaded then SyncFolder(N);
      C := N.GetFirstChild;
      while (C <> nil) and not SameText(ItemOf(C).Name, Part) do C := C.GetNextSibling;
      if C = nil then Exit;
      if Rest <> '' then N.Expand(False);
      N := C;
    end;
    if N.Parent <> nil then N.Parent.Expand(False);
  finally
    Tree.Items.EndUpdate;
  end;
  Result := N;
end;

function TFileExplorerView.Reveal(const Path: string): Boolean;
var
  N: TTreeNode;
begin
  N := FindPath(Path);
  Result := N <> nil;
  if Result then Choose(N);
end;

procedure TFileExplorerView.OpenWithWindows(const Path: string);
begin
  if not ShellOpenU(Path) then Say(Format('Windows has no program that opens %s.', [ExtractFileName(Path)]));
end;

function TFileExplorerView.ValidName(const Name: string): Boolean;
begin
  Result := (Name <> '') and (LastDelimiter('\/:*?"<>|', Name) = 0);
  if not Result then Say('A name cannot be empty or contain \ / : * ? " < > |.');
end;

procedure TFileExplorerView.TreeChange(Sender: TObject; Node: TTreeNode);
begin
  if FPanel = nil then Exit;
  if Node <> nil then FPanel.StatusText := NodePath(Node)
  else if Tree.Items.Count = 0 then FPanel.StatusText := 'No project is open: Pin Folder shows a folder.'
  else FPanel.StatusText := '';
end;

{ --- the IDE's news --- }

procedure TFileExplorerView.ProjectChanged;
begin
  if FHost <> nil then FProjectDir := ExcludeTrailingPathDelimiter(FHost.ProjectFolder) else FProjectDir := '';
  if SameRoots then MarkAll else RebuildRoots;
end;

procedure TFileExplorerView.MarkAll;
var
  N: TTreeNode;
begin
  N := Tree.Items.GetFirstNode;
  while N <> nil do
  begin
    MarkNode(N);
    N := N.GetNext;
  end;
end;

procedure TFileExplorerView.FilesChanged;
begin
  if Tree.HandleAllocated and Tree.Showing then Tree.Invalidate;
end;

procedure TFileExplorerView.ActiveFileChanged;
begin
  if FFollow and Showing then LocateActive(True);
end;

procedure TFileExplorerView.Shown;
begin
  if FDirty then Resync;
  { a new window of the tree (its group floated or docked) keeps the nodes, not their bold }
  MarkAll;
  if FFollow then LocateActive(True);
end;

procedure TFileExplorerView.LocateActive(Quiet: Boolean);
var
  F: string;
begin
  if FHost = nil then Exit;
  F := FHost.ActiveFile;
  if F = '' then
  begin
    if not Quiet then Say('No file is shown in the file area.');
    Exit;
  end;
  if not Reveal(F) and not Quiet then
    Say(Format('%s is not shown here: it lies outside the project''s folder and the pinned folders, or Show ' +
      'or the filter leaves it out.', [ExtractFileName(F)]));
end;

procedure TFileExplorerView.SetFollow(Value: Boolean);
begin
  FFollow := Value;
  aFxFollow.Checked := Value;
  if Value then LocateActive(True);
end;

{ --- commands --- }

procedure TFileExplorerView.Say(const Text: string);
begin
  Ask(Text, MB_OK or MB_ICONINFORMATION);
end;

function TFileExplorerView.Ask(const Text: string; Flags: UINT): Integer;
begin
  Result := MessageBox(Application.MainForm.Handle, PChar(Text), 'File Explorer', Flags);
end;

procedure TFileExplorerView.ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
var
  Path: string;
  IsFile: Boolean;
begin
  Handled := True;
  Path := SelectedPath;
  IsFile := (Path <> '') and not SelectedIsFolder;
  aFxOpen.Enabled := IsFile;
  aFxOpenShell.Enabled := Path <> '';
  aFxAddToProject.Enabled := IsFile and (FHost <> nil) and FHost.CanAddToProject(Path);
  aFxNewFile.Enabled := Path <> '';
  aFxNewFolder.Enabled := Path <> '';
  aFxRename.Enabled := (Path <> '') and not SelectedIsRoot;
  aFxDelete.Enabled := aFxRename.Enabled;
  aFxCopyPath.Enabled := Path <> '';
  aFxShowInExplorer.Enabled := Path <> '';
  aFxCommandPrompt.Enabled := Path <> '';
  aFxFindInFiles.Enabled := Path <> '';
  aFxPinSelected.Enabled := SelectedIsFolder and not SelectedIsRoot;
  aFxUnpin.Enabled := SelectedIsRoot and (ItemOf(Tree.Selected).Root = rkPinned);
  aFxLocate.Enabled := (FHost <> nil) and (FHost.ActiveFile <> '');
  aFxCollapseAll.Enabled := Tree.Items.Count > 0;
end;

procedure TFileExplorerView.RunCommand(A: TAction);
var
  Handled: Boolean;
begin
  ActionsUpdate(A, Handled);
  if A.Enabled then A.Execute;
end;

procedure TFileExplorerView.Command(Sender: TObject);
var
  S: string;
  N: TTreeNode;
begin
  if Sender = aFxOpen then OpenNode(Tree.Selected)
  else if Sender = aFxOpenShell then OpenWithWindows(SelectedPath)
  else if Sender = aFxAddToProject then FHost.AddToProject(SelectedPath)
  else if Sender = aFxNewFile then NewEntry(False)
  else if Sender = aFxNewFolder then NewEntry(True)
  else if Sender = aFxRename then
  begin
    { a unit through Rename Unit: its name, its uses clauses and its project with it }
    if not SelectedIsFolder and SameText(ExtractFileExt(SelectedPath), '.pas') then FHost.RenameUnit(SelectedPath)
    else
    begin
      FEditing := True;
      Tree.Selected.EditText;
    end;
  end
  else if Sender = aFxDelete then DeleteSelected
  else if Sender = aFxCopyPath then Clipboard.AsText := SelectedPath
  else if Sender = aFxShowInExplorer then ShowInExplorer(SelectedPath)
  else if Sender = aFxCommandPrompt then CommandPromptAt(SelectedFolder)
  else if Sender = aFxFindInFiles then FHost.FindInFolder(SelectedFolder)
  else if Sender = aFxPinFolder then
  begin
    S := SelectedFolder;
    if S = '' then S := FProjectDir;
    if BrowseFolder('Pin Folder', '', S) then PinFolder(ExcludeTrailingPathDelimiter(ExpandFileName(S)));
  end
  else if Sender = aFxPinSelected then PinFolder(SelectedPath)
  else if Sender = aFxUnpin then Unpin(SelectedPath)
  else if Sender = aFxLocate then LocateActive(False)
  else if Sender = aFxFollow then SetFollow(not FFollow)
  else if Sender = aFxCollapseAll then
  begin
    Tree.Items.BeginUpdate;
    try
      N := Tree.Items.GetFirstNode;
      while N <> nil do
      begin
        N.Collapse(True);
        N := N.GetNextSibling;
      end;
    finally
      Tree.Items.EndUpdate;
    end;
  end
  else if Sender = aFxRefresh then Resync
  else if Sender = aFxShowMenu then UIDropButtonMenu(tbShow)
  else if (Sender = aFxDelphiOnly) or (Sender = aFxShowOutput) or (Sender = aFxShowHidden) then
  begin
    TAction(Sender).Checked := not TAction(Sender).Checked;
    SyncAll;
  end;
end;

{ a file in the IDE, or with its program in Windows when the IDE's editor would only show its bytes }
procedure TFileExplorerView.OpenNode(N: TTreeNode);
begin
  if (N = nil) or NodeIsFolder(N) or (FHost = nil) then Exit;
  if HasExt(ShellExts, NodePath(N)) then OpenWithWindows(NodePath(N)) else FHost.OpenFile(NodePath(N));
end;

{ a double click on a file opens it; on a folder the tree opens or closes it }
procedure TFileExplorerView.TreeDblClick(Sender: TObject);
var
  P: TPoint;
  N: TTreeNode;
begin
  P := TFxTreeHook(UIFindHook(Tree, TFxTreeHook)).FDblPos;
  N := Tree.GetNodeAt(P.X, P.Y);
  if (N <> nil) and (N = Tree.Selected) and not NodeIsFolder(N) then OpenNode(N);
end;

{ the tree's keys: Enter opens, F2 renames, Del deletes (keys of the tree, not shortcuts of the IDE) }
procedure TFileExplorerView.TreeKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Tree.IsEditing or (Shift <> []) then Exit;
  case Key of
    VK_RETURN: RunCommand(aFxOpen);
    VK_F2: RunCommand(aFxRename);
    VK_DELETE: RunCommand(aFxDelete);
  else
    Exit;
  end;
  Key := 0;
end;

procedure TFileExplorerView.TreeEditing(Sender: TObject; Node: TTreeNode; var AllowEdit: Boolean);
begin
  AllowEdit := FEditing;
  FEditing := False;
end;

{ a name edited in the tree: the file or folder renamed on the disk, its open pages after it }
procedure TFileExplorerView.TreeEdited(Sender: TObject; Node: TTreeNode; var S: string);
var
  It: TFxItem;
  NewPath: string;
begin
  It := ItemOf(Node);
  S := Trim(S);
  if (It = nil) or (S = '') or (S = It.Name) then
  begin
    if It <> nil then S := It.Name;
    Exit;
  end;
  if not ValidName(S) then
  begin
    S := It.Name;
    Exit;
  end;
  NewPath := ExtractFileDir(It.Path) + '\' + S;
  if not RenameFileU(It.Path, NewPath) then
  begin
    Say(Format('%s could not be renamed: %s', [It.Name, SysErrorMessage(GetLastError)]));
    S := It.Name;
    Exit;
  end;
  FHost.Renamed(It.Path, NewPath, It.Folder);
  It.Name := S;
  It.Path := NewPath;
  { a folder's nodes below it have their old names: read again when it opens }
  if It.Folder then
  begin
    DeleteNodes(Node, True);
    It.Loaded := False;
    Node.HasChildren := True;
  end
  else
    SetNodeIcon(Node);
  FDirty := True;      // its place among the others: at the next tick
  TreeChange(Tree, Node);
end;

{ New File / New Folder in the folder chosen (a file's folder): a unit gets Delphi's new unit's text,
  any other file is empty; a new file opens in the IDE }
procedure TFileExplorerView.NewEntry(Folder: Boolean);
const
  Captions: array[Boolean] of string = ('New File', 'New Folder');
  Prompts: array[Boolean] of string = ('File name:', 'Folder name:');
  Defaults: array[Boolean] of string = ('Unit1.pas', 'NewFolder');
var
  Dir, Name, Path: string;
  Ok: Boolean;
begin
  Dir := SelectedFolder;
  if Dir = '' then Exit;
  Name := Defaults[Folder];
  if not InputDialog(Self, Captions[Folder], Prompts[Folder], Name) then Exit;
  Name := Trim(Name);
  if not ValidName(Name) then Exit;
  Path := Dir + '\' + Name;
  if FileExistsU(Path) or DirectoryExists(Path) then
  begin
    Say(Format('%s exists already.', [Name]));
    Exit;
  end;
  if Folder then Ok := ForceDirectoriesU(Path)
  else
    try
      if SameText(ExtractFileExt(Name), '.pas') then WriteFileU(Path, NewUnitSource(ChangeFileExt(Name, '')))
      else WriteFileU(Path, '');
      Ok := True;
    except
      Ok := False;
    end;
  if not Ok then
  begin
    Say(Format('%s could not be made: %s', [Name, SysErrorMessage(GetLastError)]));
    Exit;
  end;
  Resync;
  Reveal(Path);
  if not Folder then FHost.OpenFile(Path);
end;

{ Delete: to the Recycle Bin, after a question; not a file open in the IDE (nor a folder with one) }
procedure TFileExplorerView.DeleteSelected;
var
  It: TFxItem;
begin
  It := ItemOf(Tree.Selected);
  if It = nil then Exit;
  if (It.Folder and FHost.HasOpenFiles(It.Path)) or (not It.Folder and (fxOpen in FHost.FileState(It.Path))) then
  begin
    Say(Format('%s is open in the IDE: close it first.', [It.Name]));
    Exit;
  end;
  if Ask(Format('Move %s to the Recycle Bin?', [It.Name]), MB_YESNO or MB_ICONQUESTION) <> IDYES then Exit;
  if not RecycleFileU(It.Path) then
  begin
    Say(Format('%s could not be deleted.', [It.Name]));
    Exit;
  end;
  Resync;
end;

procedure TFileExplorerView.PinFolder(const Dir: string);
begin
  if (Dir = '') or (FPinned.IndexOf(Dir) >= 0) then Exit;
  FPinned.Add(Dir);
  RebuildRoots;
  Reveal(Dir);
end;

procedure TFileExplorerView.Unpin(const Dir: string);
var
  I: Integer;
begin
  I := FPinned.IndexOf(Dir);
  if I < 0 then Exit;
  FPinned.Delete(I);
  RebuildRoots;
end;

{ a file dragged out: Windows' drag of it - the IDE's window opens it, the Project Manager adds it,
  Explorer copies it (a folder is not dragged) }
procedure TFileExplorerView.StartDrag(N: TTreeNode);
var
  L: TStringList;
begin
  if NodeIsFolder(N) then Exit;
  L := TStringList.Create;
  try
    L.Add(NodePath(N));
    DragFilesOut(L);
  finally
    L.Free;
  end;
end;

procedure TFileExplorerView.FilterEditChange(Sender: TObject);
begin
  SyncAll;
end;

{ Esc empties the box; Down goes into the tree }
procedure TFileExplorerView.FilterEditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and (FilterEdit.Text <> '') then
  begin
    FilterEdit.Text := '';
    Key := 0;
  end
  else if Key = VK_DOWN then
  begin
    Tree.SetFocus;
    Key := 0;
  end;
end;

procedure TFileExplorerView.MenuPopup(Sender: TObject);
var
  Handled: Boolean;
begin
  if Assigned(FOnMenuPopup) then FOnMenuPopup(Sender);
  ActionsUpdate(nil, Handled);
end;

end.
