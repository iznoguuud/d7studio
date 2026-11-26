{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaEditWindow;

{ D7 Studio - Delphi 7's edit window as experts find it past the Open Tools API.

  Delphi 7's code editor is a form of its own (class TEditWindow, named EditWindow_0). It holds
  the editor control (class TEditControl, named Editor), the editor's menu EditorLocalMenu, the
  menus BackMenu and ForwardMenu and the file tabs (class TXTabControl, named TabControl).
  Experts such as GExperts and CnWizards find these by class and name: from INTAEditWindow.Form,
  in Screen.Forms, or from the control that has the focus. D7 Studio's editor is the file area's
  one Scintilla window (SdSciEdit's TSciWindow) on the main window, so:
  * Editor is that window: the main window makes it as a TEditControl - Delphi's class name, a
    TCustomControl -, and this form owns it (its parent stays the main window's file area). Its
    menu is the editor's; the published properties experts read by RTTI (LineText, TopLine,
    LinesInWindow, LineCount, CaretX, CaretY, CharXIndex) answer from the file it shows, lines
    with their tabs as spaces, as Delphi's control gives them.
  * The form is hidden and a child of the main window: nothing shows it or brings it to the
    front, and the parent form of its controls is the main window.
  * It owns the editor's menus (moved here from the main form), so that experts find them on
    INTAEditWindow.Form.
  * TabControl is a stand-in for the file tabs; its menu is the file tabs' menu.

  Experts that take Editor for Delphi's control call that control's own routines on it, exported
  by coreide70.bpl and resolved by name: GetTextAtLine, GetAttributeAtPos, MarkLinesDirty and
  EdRefresh (CnWizards does). D7 Studio runs none of coreide70's editor code. CreateEditWindow
  writes a jump to D7 Studio's answer at the entry of each, before any expert is loaded: an expert
  that patches a routine saves the bytes it finds at its entry. }

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, ExtCtrls, ComCtrls, Menus, SdSciEdit;

type
  { Delphi's editor control: the file area's editor window with Delphi's class name. The
    properties experts read by RTTI answer from the file it shows. }
  TEditControl = class(TSciWindow)
  private
    function GetLineText: string;
    function GetTopLine: Integer;
    function GetLinesInWindow: Integer;
    function GetLineCount: Integer;
    function GetCaretX: Integer;
    function GetCaretY: Integer;
    function GetCharXIndex: Integer;
    procedure WMContextMenu(var Message: TWMContextMenu); message WM_CONTEXTMENU;
  public
    procedure SetFocus; override;
  published
    { the caret's line, tabs as spaces }
    property LineText: string read GetLineText;
    { the first line shown, 1-based }
    property TopLine: Integer read GetTopLine;
    property LinesInWindow: Integer read GetLinesInWindow;
    property LineCount: Integer read GetLineCount;
    { the caret's column (tabs to their stops) and line, 1-based }
    property CaretX: Integer read GetCaretX;
    property CaretY: Integer read GetCaretY;
    { the first column shown, 0-based }
    property CharXIndex: Integer read GetCharXIndex;
  end;

  { the stand-in for Delphi's file tabs. An expert may change its style or events, or free it. }
  TXTabControl = class(TTabControl)
  private
    procedure TabsChanging(Sender: TObject; var AllowChange: Boolean);
    procedure TabsChange(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TEditWindow = class(TForm)
    EditorPanel: TPanel;
  end;

{ The edit window, made once the main window is there and before the experts are loaded.
  coreide70.bpl is loaded first from CoreIdeFolder (where the packages and DLLs it needs are)
  and its editor control's routines are answered by D7 Studio. A routine it lacks no expert can
  call either, and without coreide70.bpl no expert can call any. The window is not made when a
  routine could not be answered: an expert would run Delphi's code on the editor. The menus and
  the file area's editor window (SciFileWindow, a TEditControl) become the window's components;
  EditorMenu is the editor's menu, TabMenu the file tabs'. }
procedure CreateEditWindow(Main: TCustomForm; EditorMenu, BackMenu, ForwardMenu, TabMenu: TPopupMenu;
  const CoreIdeFolder: string);
{ The edit window freed, before the experts' DLLs are unloaded, as Delphi closes its edit windows
  before it unloads them: what experts put on it is freed while their code is still loaded
  (GExperts adds a component to it as its wizards end). The menus and the editor go back to their
  old owner. }
procedure DestroyEditWindow;
{ the form INTAEditWindow.Form gives (nil: none made) }
function EditWindowForm: TCustomForm;
{ Editor's font: the code editor's (Editor Options' font) - what experts measure the text with }
procedure EditWindowFontChanged;

implementation

uses
  ToolsAPI, SdSciDefs, SdEditorOptions, SdOtaCore;

{$R *.dfm}

const
  CoreIdeName = 'coreide70.bpl';
  { TCustomEditControl's routines experts call (unit Editors of coreide70) }
  SGetTextAtLine = '@Editors@TCustomEditControl@GetTextAtLine$qqri';
  SGetAttributeAtPos = '@Editors@TCustomEditControl@GetAttributeAtPos$qqrrx9Ek@TEdPosrit2oo';
  SMarkLinesDirty = '@Editors@TCustomEditControl@MarkLinesDirty$qqriusi';
  SEdRefresh = '@Editors@TCustomEditControl@EdRefresh$qqro';

var
  TheWindow: TEditWindow;
  TheEditor: TEditControl;         // the file area's editor window, the window's while it is there
  EditorOwner: TComponent;         // ... its owner before
  Hooked: Boolean;                 // InstallCoreIdeHooks has written its jumps
  TakenMenus: array of TComponent; // the menus the window took ...
  MenusOwner: TComponent;          // ... and their owner before

{ S with its tabs as spaces to their stops, every byte one column (Delphi 7's editor control
  gives its lines so). Experts read lines while the editor paints: the length is counted first,
  and the result made in one piece. }
function ExpandTabs(const S: string; TabWidth: Integer): string;
var
  I, Col, N: Integer;
  P: PChar;
begin
  if Pos(#9, S) = 0 then
  begin
    Result := S;
    Exit;
  end;
  if TabWidth < 1 then TabWidth := 8;
  Col := 0;
  for I := 1 to Length(S) do
    if S[I] = #9 then Inc(Col, TabWidth - Col mod TabWidth) else Inc(Col);
  SetLength(Result, Col);
  P := PChar(Result);
  Col := 0;
  for I := 1 to Length(S) do
    if S[I] = #9 then
    begin
      N := TabWidth - Col mod TabWidth;
      FillChar(P[Col], N, ' ');
      Inc(Col, N);
    end
    else
    begin
      P[Col] := S[I];
      Inc(Col);
    end;
end;

{ line Line (0-based) of E, tabs as spaces }
function EdLine(E: TSciEdit; Line: Integer): string;
begin
  Result := ExpandTabs(E.GetLineText(Line), E.Sci(SCI_GETTABWIDTH));
end;

{ ---------------------------------------------------------------- TEditControl }

function TEditControl.GetLineText: string;
var
  E: TSciEdit;
begin
  E := Edit;
  if E = nil then Result := '' else Result := EdLine(E, E.LineFromPos(E.CaretPos));
end;

function TEditControl.GetTopLine: Integer;
var
  E: TSciEdit;
begin
  E := Edit;
  if E = nil then Result := 1
  else Result := E.Sci(SCI_DOCLINEFROMVISIBLE, E.Sci(SCI_GETFIRSTVISIBLELINE)) + 1;
end;

function TEditControl.GetLinesInWindow: Integer;
var
  E: TSciEdit;
begin
  E := Edit;
  if E = nil then Result := 0 else Result := E.Sci(SCI_LINESONSCREEN);
end;

function TEditControl.GetLineCount: Integer;
var
  E: TSciEdit;
begin
  E := Edit;
  if E = nil then Result := 0 else Result := E.LineCount;
end;

function TEditControl.GetCaretX: Integer;
var
  E: TSciEdit;
begin
  E := Edit;
  if E = nil then Result := 1
  else Result := OffsetColumn(E, E.CaretPos) + E.Sci(SCI_GETSELECTIONNCARETVIRTUALSPACE);
end;

function TEditControl.GetCaretY: Integer;
var
  E: TSciEdit;
begin
  E := Edit;
  if E = nil then Result := 1 else Result := E.LineFromPos(E.CaretPos) + 1;
end;

function TEditControl.GetCharXIndex: Integer;
var
  E: TSciEdit;
  W: Integer;
begin
  Result := 0;
  E := Edit;
  if E = nil then Exit;
  W := E.Sci(SCI_TEXTWIDTH, STYLE_DEFAULT, Integer(PChar('X')));
  if W > 0 then Result := E.Sci(SCI_GETXOFFSET) div W;
end;

{ the code editor's menu is the control's PopupMenu, where experts find it and add their items;
  D7 Studio shows it itself when the right button is released (TMainServices.EditorContextMenu):
  the VCL's own popup would show it a second time }
procedure TEditControl.WMContextMenu(var Message: TWMContextMenu);
begin
  Message.Result := 1;
end;

{ experts give Delphi's editor the keyboard without asking CanFocus first (CnWizards after a jump),
  as Delphi's is shown whenever a file is: while the page shows its form, a resource's page is
  shown or no file is open, the keyboard stays where it is }
procedure TEditControl.SetFocus;
begin
  if CanFocus then inherited SetFocus;
end;

{ ---------------------------------------------------------------- TXTabControl }

constructor TXTabControl.Create(AOwner: TComponent);
begin
  inherited;
  OnChanging := TabsChanging;
  OnChange := TabsChange;
end;

{ events an expert may call without checking them (GExperts' middle click on a tab) }
procedure TXTabControl.TabsChanging(Sender: TObject; var AllowChange: Boolean);
begin
end;

procedure TXTabControl.TabsChange(Sender: TObject);
begin
end;

{ ---------------------------------------------------------------- the window }

function InstallCoreIdeHooks(const Folder: string): Boolean; forward;

procedure CreateEditWindow(Main: TCustomForm; EditorMenu, BackMenu, ForwardMenu, TabMenu: TPopupMenu;
  const CoreIdeFolder: string);
var
  Tabs: TXTabControl;

  { Menu becomes the window's component. Its old owner's field of it - which RemoveComponent
    sets to nil - keeps it. }
  procedure Take(Menu: TPopupMenu);
  var
    Field: ^TComponent;
  begin
    if Menu = nil then Exit;
    Field := nil;
    if Menu.Owner <> nil then
    begin
      MenusOwner := Menu.Owner;
      Field := Menu.Owner.FieldAddress(Menu.Name);
      Menu.Owner.RemoveComponent(Menu);
    end;
    TheWindow.InsertComponent(Menu);
    if Field <> nil then Field^ := Menu;
    SetLength(TakenMenus, Length(TakenMenus) + 1);
    TakenMenus[High(TakenMenus)] := Menu;
  end;

begin
  if TheWindow <> nil then Exit;
  if not InstallCoreIdeHooks(CoreIdeFolder) then Exit;
  TheWindow := TEditWindow.Create(Application);
  TheWindow.Name := 'EditWindow_0';
  TheWindow.Parent := Main;
  Take(EditorMenu);
  Take(BackMenu);
  Take(ForwardMenu);
  { the file area's editor window is Editor: the window's component, named as Delphi's (its
    parent stays where it is) }
  if SciFileWindow is TEditControl then
  begin
    TheEditor := TEditControl(SciFileWindow);
    EditorOwner := TheEditor.Owner;
    if EditorOwner <> nil then EditorOwner.RemoveComponent(TheEditor);
    TheWindow.InsertComponent(TheEditor);
    TheEditor.Name := 'Editor';
    TheEditor.PopupMenu := EditorMenu;
    { a window of its own now: an expert that compares the focused window with it (GExperts'
      focus hook) finds it from the start }
    TheEditor.HandleNeeded;
  end;
  Tabs := TXTabControl.Create(TheWindow);
  Tabs.Name := 'TabControl';
  Tabs.Parent := TheWindow;
  Tabs.Align := alTop;
  Tabs.PopupMenu := TabMenu;
  EditWindowFontChanged;
end;

procedure DestroyEditWindow;
var
  I: Integer;
begin
  if TheWindow = nil then Exit;
  { back to their owner, whose fields of them it sets again }
  for I := High(TakenMenus) downto 0 do
  begin
    TheWindow.RemoveComponent(TakenMenus[I]);
    if MenusOwner <> nil then MenusOwner.InsertComponent(TakenMenus[I]);
  end;
  TakenMenus := nil;
  { the editor stays: back to its owner, without Delphi's name }
  if TheEditor <> nil then
  begin
    TheWindow.RemoveComponent(TheEditor);
    TheEditor.Name := '';
    if EditorOwner <> nil then EditorOwner.InsertComponent(TheEditor);
    TheEditor := nil;
  end;
  FreeAndNil(TheWindow);
end;

function EditWindowForm: TCustomForm;
begin
  Result := TheWindow;
end;

procedure EditWindowFontChanged;
begin
  if TheEditor = nil then Exit;
  if EditorOptions.FontName <> '' then TheEditor.Font.Name := EditorOptions.FontName;
  if EditorOptions.FontSize > 0 then TheEditor.Font.Size := EditorOptions.FontSize;
end;

{ ---------------------------------------------------------------- coreide70's routines }

{ TCustomEditControl.GetTextAtLine: line LineNum (1-based) of the file Editor shows, tabs as
  spaces; for any other object (none here runs Delphi's editor) nothing }
function EditGetTextAtLine(Self: TObject; LineNum: Integer): string;
var
  E: TSciEdit;
begin
  Result := '';
  try
    if (Self = nil) or (Self <> TheEditor) then Exit;
    E := TheEditor.Edit;
    if E <> nil then Result := EdLine(E, LineNum - 1);
  except
    on X: Exception do OtaError(X, 'coreide70 GetTextAtLine');
  end;
end;

{ TCustomEditControl.GetAttributeAtPos: Delphi's attribute of the text at EdPos and its line's
  marks, as the active view gives them (IOTAEditView.GetAttributeAtPos) }
procedure EditGetAttributeAtPos(Self: TObject; const EdPos: TOTAEditPos; var Element, LineFlag: Integer;
  IncludeMargin, Unused: Boolean);
var
  V: IOTAEditView;
begin
  Element := atWhiteSpace;
  LineFlag := 0;
  try
    if (Self = nil) or (Self <> TheEditor) or (BorlandIDEServices = nil) then Exit;
    V := (BorlandIDEServices as IOTAEditorServices).TopView;
    if V <> nil then V.GetAttributeAtPos(EdPos, IncludeMargin, Element, LineFlag);
  except
    on X: Exception do OtaError(X, 'coreide70 GetAttributeAtPos');
  end;
end;

{ TCustomEditControl.MarkLinesDirty and EdRefresh: Editor painted again }
procedure RepaintEditor(Self: TObject);
begin
  if (Self = nil) or (Self <> TheEditor) then Exit;
  TheEditor.Invalidate;
end;

procedure EditMarkLinesDirty(Self: TObject; LineNum: Integer; Count: Word; Flag: Integer);
begin
  RepaintEditor(Self);
end;

procedure EditEdRefresh(Self: TObject; DirtyOnly: Boolean);
begin
  RepaintEditor(Self);
end;

{ a jump to Dest at Target's entry }
function WriteJump(Target, Dest: Pointer): Boolean;
type
  TJump = packed record
    Op: Byte;
    Rel: Integer;
  end;
var
  J: TJump;
  Old: Cardinal;
begin
  Result := False;
  if Target = nil then Exit;
  J.Op := $E9;
  J.Rel := Integer(Dest) - Integer(Target) - SizeOf(J);
  if not VirtualProtect(Target, SizeOf(J), PAGE_EXECUTE_READWRITE, Old) then Exit;
  Move(J, Target^, SizeOf(J));
  VirtualProtect(Target, SizeOf(J), Old, Old);
  FlushInstructionCache(GetCurrentProcess, Target, SizeOf(J));
  Result := True;
end;

{ coreide70.bpl's routines of Delphi's editor control answered by D7 Studio (see CreateEditWindow);
  False: a routine could not be answered }
function InstallCoreIdeHooks(const Folder: string): Boolean;
const
  Count = 4;
  Names: array[0..Count - 1] of string = (SGetTextAtLine, SGetAttributeAtPos, SMarkLinesDirty, SEdRefresh);
var
  H: HMODULE;
  Entry: Pointer;
  Answers: array[0..Count - 1] of Pointer;
  I: Integer;
begin
  Result := True;
  if Hooked then Exit;
  H := GetModuleHandle(CoreIdeName);
  if H = 0 then
    H := LoadLibraryEx(PChar(IncludeTrailingPathDelimiter(Folder) + CoreIdeName), 0,
      LOAD_WITH_ALTERED_SEARCH_PATH);
  if H = 0 then Exit;
  Answers[0] := @EditGetTextAtLine;
  Answers[1] := @EditGetAttributeAtPos;
  Answers[2] := @EditMarkLinesDirty;
  Answers[3] := @EditEdRefresh;
  for I := 0 to Count - 1 do
  begin
    Entry := CodeEntry(GetProcAddress(H, PChar(Names[I])));
    if (Entry <> nil) and not WriteJump(Entry, Answers[I]) then
    begin
      Result := False;
      Exit;
    end;
  end;
  Hooked := True;
end;

end.
