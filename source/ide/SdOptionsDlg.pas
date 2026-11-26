{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOptionsDlg;

{ D7 Studio - Tools | Environment Options, Editor Options, Debugger Options, Formatter Options:
  one dialog, as RAD Studio's Tools | Options: a tree of every page on the left, the page on the
  right, OK and Cancel in the band at its foot. Its four
  sections are frames: SdEnvOptionsFrame, SdEditorOptionsFrame, SdDebuggerOptionsFrame,
  SdFormatterFrame - a page control whose pages have no tabs (TPlainPages: no frame either), and
  what belongs to all of a section's pages in a footer below them (Integrated debugging, the
  Formatter's presets and Preview). Every page is laid out on one grid, the size of PageArea
  (LayoutSection). A section is made when it is first needed - shown, or
  opened in the tree -: a frame loads in a few hundred milliseconds (its colour boxes make their
  windows while it loads), so the dialog opens as fast as one section; only a section that was
  made is saved.
  Project | Options is this dialog too, with one section, SdProjOptionsFrame, its pages the
  tree's nodes: ExecuteProject. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls,
  SdProject;

type
  { the sections of Tools | Options, and Project | Options }
  TOptionsSection = (osEnvironment, osEditor, osDebugger, osFormatter, osProject);

  TOptionsDlg = class(TForm)
    pnlTree: TPanel;
    PageTree: TTreeView;
    lnTree: TShape;
    pnlTitle: TPanel;
    lblSection: TLabel;
    lblPage: TLabel;
    lnTitle: TShape;
    PageArea: TPanel;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure PageTreeChange(Sender: TObject; Node: TTreeNode);
    procedure PageTreeExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
  private
    FFrames: array[TOptionsSection] of TCustomFrame;   // nil: the section is not made yet
    FRoots: array[TOptionsSection] of TTreeNode;      // nil: its pages are the tree's top nodes
    FShown: TOptionsSection;
    FAnyShown: Boolean;
    FReady: Boolean;
    FProject: TSdProject;                // Project | Options: the project and its source
    FDprSource: string;
    function Section(S: TOptionsSection): TCustomFrame;
    function NodeSection(Node: TTreeNode): TOptionsSection;
    procedure Grow(W, H: Integer);
    procedure ShowPage(S: TOptionsSection; Sheet: TTabSheet);
    procedure Choose(S: TOptionsSection; Page: Integer);
    procedure SaveSections;
  public
    { Section, Page: the page shown first - an index of the section's pages (SdDialogs'
      EnvOptionsPalettePage ...) }
    class function Execute(AOwner: TComponent; Section: TOptionsSection; Page: Integer = 0): Boolean;
    { Project | Options of Project (nil: the default options), DprSource its source - changed on OK;
      Page: the page shown first (TProjOptionsFrame.LoadOptions). Packages | Edit sets
      SdProjOptionsFrame.PackageToEdit and cancels. }
    class function ExecuteProject(AOwner: TComponent; Project: TSdProject; Page: Integer;
      var DprSource: string): Boolean;
  end;

{ test support (writedlg env | editor | debugger | formatter | project): a section's frame laid out for
  the UI font and for the size of the dialog's pages, in a dialog made for that (UILayoutPass);
  the caller frees Dialog (the frame with it). nil: no section of that name. }
function LayoutSection(const Name: string; out Dialog: TForm): TCustomFrame;

implementation

{$R *.dfm}

uses
  Math, CommCtrl, Menus, SdUI, SdEncoding, SdEnvOptionsFrame, SdEditorOptionsFrame, SdDebuggerOptionsFrame,
  SdFormatterFrame, SdProjOptionsFrame;

const
  SectionCaptions: array[TOptionsSection] of string = ('Environment Options', 'Editor Options',
    'Debugger Options', 'Formatter Options', 'Project Options');
  { the names of the test command writedlg }
  SectionKeys: array[TOptionsSection] of string = ('env', 'editor', 'debugger', 'formatter', 'project');
  SectionClasses: array[TOptionsSection] of TWinControlClass = (TEnvOptionsFrame,
    TEditorOptionsFrame, TDebuggerOptionsFrame, TFormatterFrame, TProjOptionsFrame);

type
  TColorBoxAccess = class(TCustomColorBox);   // PopulateList

  { a section's page control without tabs and frame: its pages fill it, and what they ask their
    parent to paint under their controls - the theme's body of a tab otherwise
    (DrawThemeParentBackground: WM_ERASEBKGND, then WM_PRINTCLIENT) - is the dialogs' body colour (UIDialogColor) }
  TPlainPages = class(TUIWindowHook)
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TPlainPages.Hook(var Message: TMessage);
var
  PS: TPaintStruct;
  DC: HDC;
  R: TRect;
begin
  case Message.Msg of
    TCM_ADJUSTRECT:
      if Message.WParam = 0 then
      begin
        { the pages' area is the whole control: the client rectangle as it came (the VCL adds
          2 px above the pages of a page control with its tabs on top: taken off here) }
        Dec(PRect(Message.LParam)^.Top, 2);
        Exit;
      end;
    WM_ERASEBKGND:
      begin
        Message.Result := 1;          // the page shown covers it
        Exit;
      end;
    WM_PRINTCLIENT:
      begin
        GetClientRect(FControl.Handle, R);
        UIFill(HDC(Message.WParam), R, UIDialogColor);
        Message.Result := 0;
        Exit;
      end;
    WM_PAINT:
      begin
        { what no page covers (nothing while one is shown: the pages are clipped away) }
        DC := HDC(Message.WParam);
        if DC = 0 then DC := BeginPaint(FControl.Handle, PS);
        GetClientRect(FControl.Handle, R);
        UIFill(DC, R, UIDialogColor);
        if Message.WParam = 0 then EndPaint(FControl.Handle, PS);
        Message.Result := 0;
        Exit;
      end;
  end;
  FOldProc(Message);
end;

function PagesOf(F: TCustomFrame): TPageControl;
begin
  Result := F.FindComponent('PageControl') as TPageControl;
end;

{ a section's frame in Host, hidden, its pages plain. A frame loads its .dfm in its constructor,
  before it has a parent, and some of its controls make their windows meanwhile (the colour boxes
  of Editor Options' Color page: in the Application's window, TCustomFrame.CreateParams); when it gets its
  parent, TCustomFrame.SetParent destroys them all. Most controls keep what they had (a combo box
  its items and index, a list view its items) and get their windows again when they are shown. A
  colour box would take back the item it had, not a colour the section sets meanwhile - every
  colour box showed Black -: it is told to fill its list again (PopulateList without a window),
  and that applies the colour set when its window comes. Making their windows again at once cost
  Editor Options a quarter of a second. All (the test command writedlg): every window that was there made
  again - a combo box writes its ItemHeight from its window. Then the flicker measures
  (UIReduceFlicker). }
function MakeFrame(S: TOptionsSection; Host: TWinControl; All: Boolean): TCustomFrame;
var
  Made: TList;
  P: TPageControl;
  I: Integer;

  { the controls in C that have their windows (All) or its colour boxes that have, parents first }
  procedure WithWindows(C: TControl);
  var
    I: Integer;
  begin
    if not (C is TWinControl) or not TWinControl(C).HandleAllocated then Exit;
    if All or (C is TCustomColorBox) then Made.Add(C);
    for I := 0 to TWinControl(C).ControlCount - 1 do WithWindows(TWinControl(C).Controls[I]);
  end;

begin
  Result := TCustomFrame(SectionClasses[S].Create(nil));
  Result.Visible := False;
  Made := TList.Create;
  try
    WithWindows(Result);
    Result.Parent := Host;
    for I := 0 to Made.Count - 1 do
      if All then TWinControl(Made[I]).HandleNeeded
      else TColorBoxAccess(Made[I]).PopulateList;
  finally
    Made.Free;
  end;
  P := PagesOf(Result);
  TPlainPages.Create(P, True);
  P.Realign;
  UIReduceFlicker(Result);
end;

{ Delphi's pages set boxes in two columns; the layout for the wider page (TLayoutScaler) kept a
  box narrower than half the page at its width at the side it is nearer to - a gap opened between
  the columns. Two columns share the width instead: when the page has such boxes (group boxes,
  radio groups, panels) on both sides, each gets half of the width between the page's margins
  (Delphi's gap of 14 between them) and its content is laid out for it - unless a box would cover
  another control then (a third column: OS Exceptions' buttons). A page laid out so stays as it
  is. }
procedure ShareColumns(Page: TWinControl);
const
  Gap = 14;
var
  I, J, Half, L, R, ColW, X: Integer;
  C: TControl;
  Lefts, Rights: Boolean;
  N, T: TRect;

  function Column(C: TControl): Boolean;
  begin
    Result := C.Visible and (C.Width < Half) and
      ((C is TCustomGroupBox) or (C is TCustomPanel));
  end;

  function NewBounds(C: TControl): TRect;
  begin
    if C.Left + C.Width div 2 < Half then X := L else X := R - ColW;
    Result := Bounds(X, C.Top, ColW, C.Height);
  end;

begin
  Half := Page.ClientWidth div 2;
  L := MaxInt;
  R := 0;
  Lefts := False;
  Rights := False;
  for I := 0 to Page.ControlCount - 1 do
  begin
    C := Page.Controls[I];
    if not C.Visible then Continue;
    L := Min(L, C.Left);
    R := Max(R, C.Left + C.Width);
    if Column(C) then
      if C.Left + C.Width div 2 < Half then Lefts := True else Rights := True;
  end;
  if not (Lefts and Rights) then Exit;
  ColW := (R - L - Gap) div 2;
  for I := 0 to Page.ControlCount - 1 do
    if Column(Page.Controls[I]) then
    begin
      N := NewBounds(Page.Controls[I]);
      for J := 0 to Page.ControlCount - 1 do
      begin
        C := Page.Controls[J];
        if C.Visible and not Column(C) and IntersectRect(T, N, C.BoundsRect) then Exit;
      end;
    end;
  for I := 0 to Page.ControlCount - 1 do
  begin
    C := Page.Controls[I];
    if not Column(C) then Continue;
    C.Left := NewBounds(C).Left;
    UILayoutTo(TWinControl(C), ColW - (C.Width - TWinControl(C).ClientWidth), TWinControl(C).ClientHeight);
  end;
end;

function LayoutSection(const Name: string; out Dialog: TForm): TCustomFrame;
var
  S: TOptionsSection;
  D: TOptionsDlg;
  P: TPageControl;
  I: Integer;
begin
  Result := nil;
  Dialog := nil;
  for S := Low(S) to High(S) do
    if SameText(SectionKeys[S], Name) then
    begin
      UILayoutPass := True;
      try
        D := TOptionsDlg.Create(nil);
        Dialog := D;
        Result := MakeFrame(S, D.PageArea, True);
        Result.Visible := True;           // as its .dfm has it
      finally
        UILayoutPass := False;
      end;
      UILayoutTo(Result, D.PageArea.Width, D.PageArea.Height);
      P := PagesOf(Result);
      for I := 0 to P.PageCount - 1 do ShareColumns(P.Pages[I]);
      Exit;
    end;
end;

{ ---------------------------------------------------------------- the dialog }

{ the sections of the Tools menu in the tree, each with its pages to come (made when it is first
  needed) }
class function TOptionsDlg.Execute(AOwner: TComponent; Section: TOptionsSection; Page: Integer): Boolean;
var
  D: TOptionsDlg;
  S: TOptionsSection;
begin
  D := TOptionsDlg.Create(AOwner);
  try
    for S := osEnvironment to osFormatter do
    begin
      D.FRoots[S] := D.PageTree.Items.AddChild(nil, SectionCaptions[S]);
      D.FRoots[S].HasChildren := True;
    end;
    D.FReady := True;
    D.Choose(Section, Page);
    Result := D.ShowModal = mrOK;
    if Result then D.SaveSections;
  finally
    D.Free;
  end;
end;

{ one section: the project's pages are the tree's nodes; the caption names the program }
class function TOptionsDlg.ExecuteProject(AOwner: TComponent; Project: TSdProject; Page: Integer;
  var DprSource: string): Boolean;
var
  D: TOptionsDlg;
  Own: Boolean;
begin
  PackageToEdit := '';
  { without a project: the default options (Delphi does the same) }
  Own := Project = nil;
  if Own then
  begin
    Project := TSdProject.Create;
    Project.LoadDefaults;
  end;
  D := TOptionsDlg.Create(AOwner);
  try
    D.FProject := Project;
    D.FDprSource := DprSource;
    D.PageTree.ShowRoot := False;
    D.FReady := True;
    D.Choose(osProject, Page);
    D.Caption := TProjOptionsFrame(D.FFrames[osProject]).Title;
    Result := D.ShowModal = mrOK;
    if Result then
    begin
      D.SaveSections;
      DprSource := D.FDprSource;
    end;
  finally
    D.Free;
    if Own then Project.Free;
  end;
end;

procedure TOptionsDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  { the title's two parts at 5/3 of the UI font, which UIPrepareForm gives every label }
  lblSection.Font.Height := MulDiv(Font.Height, 5, 3);
  lblPage.Font.Height := lblSection.Font.Height;
end;

{ a section, made when it is first needed: its frame in PageArea (the dialog grows when it is
  larger - another UI font), its pages in the tree, its lists filled and its values shown }
function TOptionsDlg.Section(S: TOptionsSection): TCustomFrame;
var
  P: TPageControl;
  I: Integer;
begin
  Result := FFrames[S];
  if Result <> nil then Exit;
  Screen.Cursor := crHourGlass;
  try
    Result := MakeFrame(S, PageArea, False);
    FFrames[S] := Result;
    Grow(Result.Width, Result.Height);
    Result.Align := alClient;
    P := PagesOf(Result);
    { under the section's node; the project's pages at the top }
    for I := 0 to P.PageCount - 1 do
      PageTree.Items.AddChildObject(FRoots[S], StripHotkey(P.Pages[I].Caption), P.Pages[I]);
    case S of
      osEnvironment: TEnvOptionsFrame(Result).LoadOptions;
      osEditor: TEditorOptionsFrame(Result).LoadOptions;
      osDebugger: TDebuggerOptionsFrame(Result).LoadOptions;
      osFormatter: TFormatterFrame(Result).LoadOptions;
      osProject: TProjOptionsFrame(Result).LoadOptions(FProject, FDprSource);
    end;
  finally
    Screen.Cursor := crDefault;
  end;
end;

{ PageArea at least W x H: the dialog grows by what it lacks, the tree with it; the band of OK and
  Cancel follows by itself (anchored to the dialog's sides and bottom) }
procedure TOptionsDlg.Grow(W, H: Integer);
var
  DW, DH: Integer;
begin
  DW := Max(0, W - PageArea.Width);
  DH := Max(0, H - PageArea.Height);
  if (DW = 0) and (DH = 0) then Exit;
  ClientWidth := ClientWidth + DW;
  ClientHeight := ClientHeight + DH;
  PageArea.SetBounds(PageArea.Left, PageArea.Top, PageArea.Width + DW, PageArea.Height + DH);
  PageTree.Height := PageTree.Height + DH;
end;

{ a page of a section that is made: shown - another section in one repaint }
procedure TOptionsDlg.ShowPage(S: TOptionsSection; Sheet: TTabSheet);
var
  T: TOptionsSection;
  Other: Boolean;
begin
  Other := not FAnyShown or (S <> FShown);
  if Other then UIFreezeRedraw(Self, True);
  try
    PagesOf(FFrames[S]).ActivePage := Sheet;
    { the title above the page, one line: its section in grey, then the page }
    lblSection.Caption := SectionCaptions[S] + ' ' + WideToIde(WideChar($203A));
    lblPage.Caption := StripHotkey(Sheet.Caption);
    lblPage.Left := lblSection.Left + lblSection.Width + lblSection.Canvas.TextWidth(' ');
    if Other then
    begin
      FFrames[S].Visible := True;
      for T := Low(T) to High(T) do
        if (T <> S) and (FFrames[T] <> nil) then FFrames[T].Visible := False;
      FShown := S;
      FAnyShown := True;
    end;
  finally
    if Other then UIFreezeRedraw(Self, False);
  end;
end;

{ the section of a node: a section's node, or a page's (Data: its sheet, owned by the frame) }
function TOptionsDlg.NodeSection(Node: TTreeNode): TOptionsSection;
var
  S: TOptionsSection;
begin
  Result := FShown;
  for S := Low(S) to High(S) do
    if (Node = FRoots[S]) or ((Node.Data <> nil) and (FFrames[S] <> nil) and
      (TTabSheet(Node.Data).Owner = FFrames[S])) then Result := S;
end;

{ a page's node shows it; a section's node opens and shows its first page }
procedure TOptionsDlg.PageTreeChange(Sender: TObject; Node: TTreeNode);
var
  S: TOptionsSection;
begin
  if not FReady or (Node = nil) then Exit;
  S := NodeSection(Node);
  Section(S);
  if Node.Data = nil then
  begin
    Node.Expand(False);
    Node := Node.getFirstChild;
  end;
  if (Node <> nil) and (Node.Data <> nil) then ShowPage(S, TTabSheet(Node.Data));
end;

{ a section opened in the tree is made: its pages are its nodes }
procedure TOptionsDlg.PageTreeExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
begin
  if FReady and (Node.Data = nil) then Section(NodeSection(Node));
end;

procedure TOptionsDlg.Choose(S: TOptionsSection; Page: Integer);
var
  P: TPageControl;
  N: TTreeNode;
  Sheet: TTabSheet;
begin
  P := PagesOf(Section(S));
  if (Page < 0) or (Page >= P.PageCount) then Page := 0;
  Sheet := P.Pages[Page];
  if FRoots[S] <> nil then N := FRoots[S].getFirstChild else N := PageTree.Items.GetFirstNode;
  while (N <> nil) and (N.Data <> Sheet) do N := N.getNextSibling;
  if FRoots[S] <> nil then FRoots[S].Expand(False);
  PageTree.Selected := N;
  ShowPage(S, TTabSheet(N.Data));
end;

procedure TOptionsDlg.SaveSections;
begin
  if FFrames[osEnvironment] <> nil then TEnvOptionsFrame(FFrames[osEnvironment]).SaveOptions;
  if FFrames[osEditor] <> nil then TEditorOptionsFrame(FFrames[osEditor]).SaveOptions;
  if FFrames[osDebugger] <> nil then TDebuggerOptionsFrame(FFrames[osDebugger]).SaveOptions;
  if FFrames[osFormatter] <> nil then TFormatterFrame(FFrames[osFormatter]).SaveOptions;
  if FFrames[osProject] <> nil then TProjOptionsFrame(FFrames[osProject]).SaveOptions(FDprSource);
end;

end.
