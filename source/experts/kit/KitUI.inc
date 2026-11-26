{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

{ The look of the IDE experts' windows (source\experts\kit: the AI harness's unit AiUI, the Git expert's
  GitUI), after D7 Studio's views: the view's ground clBtnFace with
  its tool bar on it, the content in a flat 1 px frame in clBtnShadow, tool buttons with a square box
  in a tint of the accent colour, the IDE's fonts and icons, the status line at the foot of D7
  Studio's view. D7 Studio's own routines (SdUI) are in its EXE and the experts also load in Delphi
  7's IDE, so they are written here again for them.
  - TKitWindowHook: a control's window procedure taken over, given back when the hook goes;
  - KitFlatToolBar: a tool bar drawn as D7 Studio's; KitLayoutBarLabel: a label in its row;
    KitCommandIcons: the commands' images - the IDE's, else glyphs of the icon font;
    KitGlyphIcons: the glyphs alone;
  - KitFlatFrame, KitPaintFrame: the flat 1 px frame of a window with WS_BORDER; KitFlatEdit;
  - KitListRange: a list box's horizontal range, kept when the list gets a new window;
  - the IDE's fonts: KitIdeFont, KitCodeFont (the editor's), KitUseIdeFont (a form in them);
  - the IDE's icons: KitIdeImages, KitIdeActionImage (by the names of Delphi's actions);
  - KitGlyphImages: an image list from glyphs of Segoe Fluent Icons / Segoe MDL2 Assets;
  - KitCueText: a hint text in an empty memo;
  - KitViewStatus: a line in the status line of D7 Studio's view;
  - KitDrawDiffLine: a line of a diff, on the ground of its kind;
  - KitFindMenuItem: a menu's item by its name, in any submenu;
  - TKitRichView: Rich Edit 4.1 (Msftedit.dll), read only, Unicode text appended in formats.
  The unit (interface: uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  StdCtrls, ComCtrls, ImgList, CommCtrl, RichEdit, Menus, ActnList; implementation: uses ToolsAPI
  and the expert's text unit of KitText.inc) includes this file in its interface with
  KIT_INTERFACE defined and again in its implementation. }

{$IFDEF KIT_INTERFACE}

const
  { TKitRichView to itself: the end followed once a new size has settled }
  KitFollowEndMessage = WM_APP + $4B1;

type
  TKitWindowHook = class(TComponent)
  private
    FControl: TWinControl;
    FOldProc: TWndMethod;
  protected
    procedure Hook(var Message: TMessage); virtual;
    procedure CallOld(var Message: TMessage);
  public
    constructor Create(AControl: TWinControl); reintroduce;
    destructor Destroy; override;
    property Control: TWinControl read FControl;
  end;

  { how text is appended to a TKitRichView }
  TKitTextFormat = record
    Color: TColor;          // clDefault: clWindowText
    Back: TColor;           // clNone: the view's ground
    Bold, Italic: Boolean;
    Mono: Boolean;          // the code font (Consolas)
    SizeDelta: Integer;     // points more or less than the view's font
    Indent: Integer;        // pixels, the paragraph's left edge
    SpaceBefore: Integer;   // pixels before the paragraph
  end;

  { the box a TKitRichView shows over its foot while text came below the reader's place: the
    tool buttons' accent box (strong under the pointer), a down arrow and the caption in the accent
    colour; the view owns it, its parent is the view's }
  TKitNewTextBox = class(TCustomControl)
  private
    FHot: Boolean;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMMouseWheel(var Message: TMessage); message WM_MOUSEWHEEL;
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    { the size of the caption in the font }
    procedure FitSize;
    property OnClick;
  end;

  { text appended in the code font (Mono): its characters, its size against the code font's }
  TKitCodeRun = record
    Start, Stop: Integer;
    SizeDelta: Integer;
  end;

  TKitRichView = class(TWinControl)
  private
    FPadding: TRect;
    FLastChar: WideChar;      // the last character appended: #13 or #0 start a paragraph
    FCodeFontName: string;
    FCodeFontSize: Integer;
    FCodeRuns: array of TKitCodeRun;
    FCodeRunCount: Integer;
    FCodeRunsStale: Boolean;  // the code font changed without a window: the runs take it in CreateWnd
    FSaved: string;           // the text as RTF while the window is made again
    FSavedBottom: Boolean;    // the reader's place while the text is laid out again (SavePlace): the bottom,
    FSavedTop: Integer;       // else the character at the top of the text rectangle
    FSavedTopY: Integer;      // and its line's top, from the rectangle's top (0 or less)
    FBehind: Boolean;         // text came below the reader's place since the view was last at the bottom
    FChanging: Boolean;       // AddText, Clear, CreateWnd or SetCodeFont change the text and set the place
    FEndPending: Boolean;     // at the end, to be scrolled there once the size settles (WMSize)
    FEndPosted: Boolean;      // ... KM_FOLLOWEND is on its way
    FNewTextCaption: string;
    FNewTextBox: TKitNewTextBox;
    procedure WMSize(var Message: TWMSize); message WM_SIZE;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMNCPaint(var Message: TWMNCPaint); message WM_NCPAINT;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
    procedure WMWindowPosChanged(var Message: TWMWindowPosChanged); message WM_WINDOWPOSCHANGED;
    procedure CMColorChanged(var Message: TMessage); message CM_COLORCHANGED;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
    procedure ApplyPadding;
    procedure ApplyColor;
    function AtBottom: Boolean;
    procedure LayOutAll;
    procedure SavePlace;
    procedure RestorePlace;
    function BeginChange(Freeze: Boolean): Boolean;
    procedure EndChange(Frozen: Boolean; FromY: Integer);
    procedure KMFollowEnd(var Message: TMessage); message KitFollowEndMessage;
    procedure SetBehind(Value: Boolean);
    procedure FitNewTextBox;
    procedure MoveNewTextBox;
    procedure NewTextBoxClick(Sender: TObject);
    procedure AddCodeRun(Start, Stop, SizeDelta: Integer);
    procedure FormatCodeRuns;
    procedure SetCodeFontName(const Value: string);
    procedure SetCodeFontSize(Value: Integer);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure WndProc(var Message: TMessage); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    { Text (UTF-16, line ends #13) at the end, in Fmt; the view stays at the bottom when it was
      there, else where it was, and a selection stays selected }
    procedure AddText(const Text: WideString; const Fmt: TKitTextFormat);
    procedure Clear;
    procedure CopyToClipboard;
    procedure SelectAll;
    function TextLength: Integer;
    function HasSelection: Boolean;
    procedure ScrollToEnd;
    { the font of Mono text, the text there included (its sizes keep their SizeDelta), the reader's
      place kept. The view takes the editor's (KitCodeFont) when D7 Studio's notice comes
      (KitEditorOptionsMessage) and when its window is made (a window that did not exist missed it) }
    procedure SetCodeFont(const Name: string; Size: Integer);
    property CodeFontName: string read FCodeFontName write SetCodeFontName;
    property CodeFontSize: Integer read FCodeFontSize write SetCodeFontSize;
    { text came below the reader's place, and the view has not been at the bottom since }
    property Behind: Boolean read FBehind;
    { the caption of the box (TKitNewTextBox) over the view's foot while Behind; a click on it goes
      to the end, from where the view follows the text again. '': no box }
    property NewTextCaption: string read FNewTextCaption write FNewTextCaption;
  published
    property Align;
    property Anchors;
    property Color default clWindow;
    property Font;
    property ParentFont;
    property PopupMenu;
    property TabOrder;
    property TabStop default True;
    property Visible;
  end;

function KitBlend(A, B: TColor; Percent: Integer): TColor;   // Percent of A, the rest of B
function KitAccent: TColor;                                   // text in the accent colour
function KitFormat(Color: TColor): TKitTextFormat;             // a plain format of that colour

{ Bar drawn in D7 Studio's style: no erase, double-buffered, the box of a button under the
  pointer, pressed or checked; the bar draws the image }
procedure KitFlatToolBar(Bar: TToolBar);

{ Control, a window with WS_BORDER, framed by the flat 1 px line of D7 Studio's views (a TPanel
  has WS_BORDER with BorderStyle bsSingle and Ctl3D False) }
procedure KitFlatFrame(Control: TWinControl);
{ the flat frame over Windows' own black one of a WS_BORDER window, after its WM_NCPAINT }
procedure KitPaintFrame(Wnd: HWND);
{ an edit or a combo box framed by the same flat line instead of the theme's frame (D7 Studio's
  UIFlatBorder) }
procedure KitFlatEdit(Control: TWinControl);

{ List's horizontal range Width pixels (LB_SETHORIZONTALEXTENT), set now and again whenever the list
  gets a new window: the VCL makes a control's window again when the control, or a form that holds
  it, gets another parent (a view docked or floated), and a new list box has no range }
procedure KitListRange(List: TCustomListBox; Width: Integer);

{ the IDE's UI font: its main window's (D7 Studio's UI font, Delphi 7's own) }
procedure KitIdeFont(Font: TFont);
{ the font of the IDE's code editor (IOTAEditOptions); Consolas 10 when it cannot be read }
procedure KitCodeFont(out Name: string; out Size: Integer);
{ the notice D7 Studio sends every window of the IDE when options were applied
  (RegisterWindowMessage('D7Studio.EditorOptionsChanged')); Delphi 7's IDE sends none }
function KitEditorOptionsMessage: UINT;
{ Msg is that notice (never WM_NULL, also when the message could not be registered) }
function KitIsEditorOptionsMessage(Msg: UINT): Boolean;
{ Form, designed in Segoe UI 9 (a text height of DesignTextHeight) with its code in Consolas, in
  the IDE's fonts: laid out again for the UI font's text height (ScaleBy), its controls in Segoe UI
  in the UI font (their sizes in proportion), those in Consolas in the editor's font - again at
  each KitEditorOptionsMessage }
procedure KitUseIdeFont(Form: TCustomForm; DesignTextHeight: Integer = 15);

{ the IDE's image list (INTAServices), nil without one }
function KitIdeImages: TCustomImageList;
{ the image of the IDE's action Name (Delphi's names: 'EditCopyCommand' ...), -1 without one }
function KitIdeActionImage(const Name: string): Integer;

{ the icon font of this Windows ('' when there is none) }
function KitIconFont: string;
{ Images (16 x 16) made of the icon font's glyphs Codes, in Color - for a ground of Ground where
  comctl32 is older than 6 and draws no alpha (Delphi 7's IDE); False without an icon font }
function KitGlyphImages(Images: TCustomImageList; const Codes: array of Word; Color: TColor;
  Ground: TColor = clBtnFace): Boolean;

{ Memo shows Cue in clGrayText while it is empty; its OnChange must repaint it (Invalidate) }
procedure KitCueText(Memo: TCustomMemo; const Cue: string);

{ the width of W in C's font }
function KitTextWidthW(C: TCanvas; const W: WideString): Integer;

{ a dialog in the IDE's font (KitUseIdeFont), its edits and combo boxes flat (KitFlatEdit); a body
  designed in clWindow takes the dialogs' colour of the IDE (KitDialogColor) }
procedure KitPrepareDialog(Form: TCustomForm);
{ the body of the dialogs: D7 Studio's Dialog background ([UI] DialogBackground of its D7Studio.ini,
  beside the IDE's program or in D7S_HOME): the window colour, else the button face; the window
  colour in an IDE without that file (Delphi 7) }
function KitDialogColor: TColor;
{ a section of a dialog: its heading in the accent colour, its flat rule from 8 px after the heading
  to where the rule ends in the .dfm }
procedure KitSection(Heading: TLabel; Rule: TControl);

{ Lbl in the row of Bar (their parent), between the bar's end (8 px after it) and 6 px before the
  row's right edge, as high as the buttons: Full; Short where Full does not fit; then its end cut
  with an ellipsis. Its hint: Hint, else the whole of Full }
procedure KitLayoutBarLabel(Lbl: TLabel; Bar: TToolBar; const Full, Short: string; const Hint: string = '');

{ the commands' images. The actions' ImageIndex in the .dfm index IdeActions and Glyphs: the
  commands show the IDE's own images of its actions IdeActions (Delphi's names, so they follow the
  IDE's icon set; '' a command without an image, '?' before a name the IDE may lack); when the IDE
  lacks one that is needed, every command shows its glyph of the icon font instead (GlyphImages and
  GlyphDisabledImages are filled); without an icon font, Bars show captions. Bars and Menus get the
  images }
procedure KitCommandIcons(Actions: TCustomActionList; const Bars: array of TToolBar;
  const Menus: array of TMenu; const IdeActions: array of string; const Glyphs: array of Word;
  GlyphImages, GlyphDisabledImages: TCustomImageList);
{ the commands' images from the icon font alone: the actions' ImageIndex in the .dfm index Glyphs
  (GlyphImages and GlyphDisabledImages are filled); without an icon font, Bars show captions }
procedure KitGlyphIcons(Actions: TCustomActionList; const Bars: array of TToolBar;
  const Menus: array of TMenu; const Glyphs: array of Word; GlyphImages, GlyphDisabledImages: TCustomImageList);
{ Images (16 x 16) of the cells Cells of the expert's bitmap resource ResName (RCDATA: a 32-bit bitmap
  with straight alpha, one row of 16 x 16 cells - the images in the order of their
  recipes); Grey: greyed as Visual Studio greys a disabled image. With
  alpha where comctl32 6 blends it (D7 Studio), else blended onto clBtnFace and masked (Delphi 7's
  IDE, comctl32 5). False when there is no such resource or it lacks a cell }
function KitBitmapImages(Images: TCustomImageList; const ResName: string; const Cells: array of Integer;
  Grey: Boolean): Boolean;
{ the commands' images from the bitmap resource ResName: the actions' ImageIndex in the .dfm index
  Cells (Images and DisabledImages are filled); without the resource, Bars show captions }
procedure KitBitmapIcons(Actions: TCustomActionList; const Bars: array of TToolBar;
  const Menus: array of TMenu; const ResName: string; const Cells: array of Integer;
  Images, DisabledImages: TCustomImageList);

{ S in the status line of D7 Studio's view that holds Form, whose parent answers the registered
  message D7Studio.ExpertViewStatus (SdOtaViews); '' takes the line away. False where the parent
  does not answer (Delphi 7's dock sites, a floating form): the form shows a line of its own there }
function KitViewStatus(Form: TCustomForm; const S: string): Boolean;

{ a view that shows Shown in place of Hidden keeps the keyboard: when it is in Hidden (or in one of
  its children) it goes to Shown, which is visible already - once Hidden is hidden, the VCL would
  give it to the form }
procedure KitPassKeyboard(Hidden, Shown: TWinControl);

const
  { the kinds of the lines of a diff }
  KitDiffSame = 0;
  KitDiffRemoved = 1;
  KitDiffAdded = 2;

{ the ground of a line of a diff of the kind (context: clWindow) and the colour of its mark }
procedure KitDiffColors(Kind: Integer; out Ground, MarkColor: TColor);
{ a line of a diff in R of C (in its font): the ground of its kind, its mark (' ', '-', '+')
  centred in the first MarkWidth pixels and the text after them - grey when it is context }
procedure KitDrawDiffLine(C: TCanvas; const R: TRect; Kind: Integer; const Text: WideString;
  MarkWidth: Integer);

{ the item of Items called Name, in any submenu (the IDE's main menu: experts find their places by
  Delphi's names); nil when there is none }
function KitFindMenuItem(Items: TMenuItem; const Name: string): TMenuItem;

{$ELSE}

{ ---------------------------------------------------------------- colours }

function KitBlend(A, B: TColor; Percent: Integer): TColor;
var
  CA, CB: COLORREF;
begin
  CA := ColorToRGB(A);
  CB := ColorToRGB(B);
  Result := RGB((GetRValue(CA) * Percent + GetRValue(CB) * (100 - Percent)) div 100,
    (GetGValue(CA) * Percent + GetGValue(CB) * (100 - Percent)) div 100,
    (GetBValue(CA) * Percent + GetBValue(CB) * (100 - Percent)) div 100);
end;

function KitAccent: TColor;
begin
  Result := KitBlend(clHighlight, clWindowText, 80);
end;

function KitFormat(Color: TColor): TKitTextFormat;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Color := Color;
  Result.Back := clNone;
end;

procedure FillRectColor(DC: HDC; const R: TRect; Color: TColor);
var
  B: HBRUSH;
begin
  B := CreateSolidBrush(ColorToRGB(Color));
  Windows.FillRect(DC, R, B);
  DeleteObject(B);
end;

{ ---------------------------------------------------------------- TKitWindowHook }

constructor TKitWindowHook.Create(AControl: TWinControl);
begin
  inherited Create(AControl);
  FControl := AControl;
  FOldProc := FControl.WindowProc;
  FControl.WindowProc := Hook;
end;

destructor TKitWindowHook.Destroy;
begin
  if Assigned(FOldProc) then FControl.WindowProc := FOldProc;
  inherited;
end;

procedure TKitWindowHook.CallOld(var Message: TMessage);
begin
  FOldProc(Message);
end;

procedure TKitWindowHook.Hook(var Message: TMessage);
begin
  FOldProc(Message);
end;

function FindHook(C: TWinControl; HookClass: TClass): TKitWindowHook;
var
  I: Integer;
begin
  for I := 0 to C.ComponentCount - 1 do
    if C.Components[I].ClassType = HookClass then
    begin
      Result := TKitWindowHook(C.Components[I]);
      Exit;
    end;
  Result := nil;
end;

{ ---------------------------------------------------------------- tool bars }

const
  TBSTYLE_EX_DOUBLEBUFFER = $00000080;
  TBCDRF_NOEDGES = $00010000;
  TBCDRF_NOOFFSET = $00020000;
  TBCDRF_NOBACKGROUND = $00400000;

type
  TToolBarLook = class(TKitWindowHook)
  private
    function DrawCaption(DC: HDC; const R: TRect; Command: Integer; State: UINT): Boolean;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

{ the accent box of D7 Studio's tool buttons: square, a tint of the accent colour on Ground (light
  under the pointer, Strong when pressed or checked) in a 1 px edge of the accent colour darkened }
procedure DrawAccent(DC: HDC; const R: TRect; Ground: TColor; Strong: Boolean);
const
  Tint: array[Boolean] of Integer = (12, 25);
begin
  FillRectColor(DC, R, KitBlend(clHighlight, clBtnText, 70));
  FillRectColor(DC, Rect(R.Left + 1, R.Top + 1, R.Right - 1, R.Bottom - 1), KitBlend(clHighlight, Ground, Tint[Strong]));
end;

{ the caption of the button whose command is Command, centred in R in the bar's font: clGrayText
  when disabled; the accelerator underlined only while the keyboard cues show. False: no such button }
function TToolBarLook.DrawCaption(DC: HDC; const R: TRect; Command: Integer; State: UINT): Boolean;
const
  CDIS_SHOWKEYBOARDCUES = $0200;
var
  Bar: TToolBar;
  I: Integer;
  S: string;
  RR: TRect;
  Flags: UINT;
  OldFont: HGDIOBJ;
begin
  Result := False;
  Bar := TToolBar(Control);
  for I := 0 to Bar.ButtonCount - 1 do
    if Bar.Buttons[I].Index = Command then
    begin
      S := Bar.Buttons[I].Caption;
      RR := R;
      { the DC of the item's custom draw has the system font: the bar's own is chosen }
      OldFont := SelectObject(DC, Bar.Font.Handle);
      SetBkMode(DC, TRANSPARENT);
      if State and CDIS_DISABLED <> 0 then SetTextColor(DC, ColorToRGB(clGrayText))
      else SetTextColor(DC, ColorToRGB(clBtnText));
      Flags := DT_CENTER or DT_VCENTER or DT_SINGLELINE;
      if State and CDIS_SHOWKEYBOARDCUES = 0 then Flags := Flags or DT_HIDEPREFIX;
      DrawText(DC, PChar(S), Length(S), RR, Flags);
      SelectObject(DC, OldFont);
      Result := True;
      Exit;
    end;
end;

procedure TToolBarLook.Hook(var Message: TMessage);
var
  CD: PNMTBCustomDraw;
  S: UINT;
  Ground: TColor;
begin
  case Message.Msg of
    TB_SETEXTENDEDSTYLE:
      Message.LParam := Message.LParam or TBSTYLE_EX_DOUBLEBUFFER;
    WM_ERASEBKGND:
      begin
        Message.Result := 1;
        Exit;
      end;
  end;
  if (Message.Msg = CN_NOTIFY) and (TWMNotify(Message).NMHdr^.code = NM_CUSTOMDRAW) then
  begin
    CD := PNMTBCustomDraw(TWMNotify(Message).NMHdr);
    case CD^.nmcd.dwDrawStage of
      CDDS_PREPAINT:
        begin
          FillRectColor(CD^.nmcd.hdc, CD^.nmcd.rc, TToolBar(Control).Color);
          Message.Result := CDRF_NOTIFYITEMDRAW;
        end;
      CDDS_ITEMPREPAINT:
        begin
          S := CD^.nmcd.uItemState;
          Ground := TToolBar(Control).Color;
          if S and CDIS_DISABLED = 0 then
            if S and (CDIS_SELECTED or CDIS_CHECKED) <> 0 then DrawAccent(CD^.nmcd.hdc, CD^.nmcd.rc, Ground, True)
            else if S and CDIS_HOT <> 0 then DrawAccent(CD^.nmcd.hdc, CD^.nmcd.rc, Ground, False);
          Message.Result := CDRF_DODEFAULT or TBCDRF_NOBACKGROUND or TBCDRF_NOEDGES or TBCDRF_NOOFFSET;
          { a caption without an image is drawn here: the tool bar draws a disabled one etched and
            2 px further right and down, so it moved as the button was enabled and disabled }
          if TToolBar(Control).ShowCaptions and (TToolBar(Control).Images = nil) and
            DrawCaption(CD^.nmcd.hdc, CD^.nmcd.rc, Integer(CD^.nmcd.dwItemSpec), S) then
            Message.Result := CDRF_SKIPDEFAULT;
        end;
    else
      Message.Result := CDRF_DODEFAULT;
    end;
    Exit;
  end;
  CallOld(Message);
end;

procedure KitFlatToolBar(Bar: TToolBar);
begin
  if FindHook(Bar, TToolBarLook) = nil then TToolBarLook.Create(Bar);
  if Bar.HandleAllocated then
  begin
    Bar.Perform(TB_SETEXTENDEDSTYLE, 0, Bar.Perform(TB_GETEXTENDEDSTYLE, 0, 0));
    Bar.Invalidate;
  end;
end;

{ ---------------------------------------------------------------- flat frames }

type
  TFrameLook = class(TKitWindowHook)
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure KitPaintFrame(Wnd: HWND);
var
  DC: HDC;
  R: TRect;
  B: HBRUSH;
begin
  DC := GetWindowDC(Wnd);
  try
    GetWindowRect(Wnd, R);
    OffsetRect(R, -R.Left, -R.Top);
    B := CreateSolidBrush(ColorToRGB(clBtnShadow));
    FrameRect(DC, R, B);
    DeleteObject(B);
  finally
    ReleaseDC(Wnd, DC);
  end;
end;

procedure TFrameLook.Hook(var Message: TMessage);
begin
  CallOld(Message);
  if Message.Msg = WM_NCPAINT then KitPaintFrame(Control.Handle);
end;

procedure KitFlatFrame(Control: TWinControl);
begin
  if FindHook(Control, TFrameLook) = nil then TFrameLook.Create(Control);
  if Control.HandleAllocated then
    SetWindowPos(Control.Handle, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or
      SWP_NOACTIVATE or SWP_FRAMECHANGED);
end;

{ ---------------------------------------------------------------- list ranges }

type
  TListRange = class(TKitWindowHook)
  private
    FWidth: Integer;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

{ the list box makes its state in WM_CREATE: the range after it }
procedure TListRange.Hook(var Message: TMessage);
begin
  CallOld(Message);
  if Message.Msg = WM_CREATE then SendMessage(Control.Handle, LB_SETHORIZONTALEXTENT, FWidth, 0);
end;

procedure KitListRange(List: TCustomListBox; Width: Integer);
var
  H: TListRange;
begin
  H := TListRange(FindHook(List, TListRange));
  if H = nil then H := TListRange.Create(List);
  H.FWidth := Width;
  if List.HandleAllocated then SendMessage(List.Handle, LB_SETHORIZONTALEXTENT, Width, 0);
end;

{ the flat line over the theme's frame. A combo box draws its frame in its client area: after
  WM_PAINT, with the theme's rounded corners inside it filled as the face next to them. An edit's
  frame is its client edge, 2 px of non-client area: after WM_NCPAINT, the outer line the border
  and the inner one the edit's colour }
type
  TControlAccess = class(TControl);

  TEditFrameLook = class(TKitWindowHook)
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TEditFrameLook.Hook(var Message: TMessage);

  procedure PaintCombo(DC: HDC);
  var
    W, H: Integer;
    B: HBRUSH;
  begin
    W := Control.Width;
    H := Control.Height;
    B := CreateSolidBrush(ColorToRGB(clBtnShadow));
    FrameRect(DC, Rect(0, 0, W, H), B);
    DeleteObject(B);
    SetPixel(DC, 1, 1, GetPixel(DC, 2, 1));
    SetPixel(DC, W - 2, 1, GetPixel(DC, W - 3, 1));
    SetPixel(DC, 1, H - 2, GetPixel(DC, 2, H - 2));
    SetPixel(DC, W - 2, H - 2, GetPixel(DC, W - 3, H - 2));
  end;

var
  DC: HDC;
  R: TRect;
  B: HBRUSH;
begin
  CallOld(Message);
  if not Control.HandleAllocated then Exit;
  if Control is TCustomComboBox then
  begin
    if Message.Msg <> WM_PAINT then Exit;
    if Message.WParam <> 0 then
      PaintCombo(HDC(Message.WParam))
    else
    begin
      DC := GetDC(Control.Handle);
      try
        PaintCombo(DC);
      finally
        ReleaseDC(Control.Handle, DC);
      end;
    end;
  end
  else if (Message.Msg = WM_NCPAINT) or (Message.Msg = WM_NCACTIVATE) then
  begin
    DC := GetWindowDC(Control.Handle);
    try
      R := Rect(0, 0, Control.Width, Control.Height);
      B := CreateSolidBrush(ColorToRGB(clBtnShadow));
      FrameRect(DC, R, B);
      DeleteObject(B);
      InflateRect(R, -1, -1);
      B := CreateSolidBrush(ColorToRGB(TControlAccess(Control).Color));
      FrameRect(DC, R, B);
      DeleteObject(B);
    finally
      ReleaseDC(Control.Handle, DC);
    end;
  end;
end;

procedure KitFlatEdit(Control: TWinControl);
begin
  if FindHook(Control, TEditFrameLook) = nil then TEditFrameLook.Create(Control);
  if Control.HandleAllocated then
    RedrawWindow(Control.Handle, nil, 0, RDW_INVALIDATE or RDW_FRAME);
end;

{ ---------------------------------------------------------------- the IDE's fonts }

const
  DesignFontName = 'Segoe UI';
  DesignFontHeight = -12;
  DesignCodeFont = 'Consolas';

procedure KitIdeFont(Font: TFont);
begin
  if (Application.MainForm = nil) or (Application.MainForm.Font.Name = '') then Exit;
  Font.Name := Application.MainForm.Font.Name;
  Font.Charset := Application.MainForm.Font.Charset;
  Font.Height := Application.MainForm.Font.Height;
end;

procedure KitCodeFont(out Name: string; out Size: Integer);
var
  ES: IOTAEditorServices;
  EO: IOTAEditOptions;
begin
  Name := DesignCodeFont;
  Size := 10;
  try
    if Supports(BorlandIDEServices, IOTAEditorServices, ES) then
    begin
      EO := ES.EditOptions;
      if (EO <> nil) and (EO.FontName <> '') and (EO.FontSize > 0) then
      begin
        Name := EO.FontName;
        Size := EO.FontSize;
      end;
    end;
  except
    { an IDE without edit options: the default }
  end;
end;

function TextHeightOf(Font: TFont): Integer;
var
  DC: HDC;
  Old: HGDIOBJ;
  TM: TTextMetric;
begin
  DC := GetDC(0);
  try
    Old := SelectObject(DC, Font.Handle);
    GetTextMetrics(DC, TM);
    SelectObject(DC, Old);
    Result := TM.tmHeight;
  finally
    ReleaseDC(0, DC);
  end;
end;

{ a message of D7 Studio's, registered when first needed (Msg keeps it) }
function RegisteredMessage(var Msg: UINT; const Name: string): UINT;
begin
  if Msg = 0 then Msg := RegisterWindowMessage(PChar(Name));
  Result := Msg;
end;

var
  EditorOptionsMessage: UINT;

function KitEditorOptionsMessage: UINT;
begin
  Result := RegisteredMessage(EditorOptionsMessage, 'D7Studio.EditorOptionsChanged');
end;

function KitIsEditorOptionsMessage(Msg: UINT): Boolean;
begin
  Result := (Msg <> 0) and (Msg = KitEditorOptionsMessage);
end;

type
  { a form's controls in the editor's font (KitUseIdeFont), given its font again when D7 Studio's
    notice comes and when the form's window is made (a window that did not exist missed the notice);
    a control that goes leaves the list }
  TCodeFontFollow = class(TKitWindowHook)
  private
    FControls: TList;
    procedure Apply;
  protected
    procedure Hook(var Message: TMessage); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    destructor Destroy; override;
    procedure Add(C: TControl);
  end;

destructor TCodeFontFollow.Destroy;
begin
  FControls.Free;
  inherited;
end;

procedure TCodeFontFollow.Add(C: TControl);
begin
  if FControls = nil then FControls := TList.Create;
  if FControls.IndexOf(C) >= 0 then Exit;
  FControls.Add(C);
  C.FreeNotification(Self);
end;

procedure TCodeFontFollow.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (FControls <> nil) then FControls.Remove(AComponent);
end;

procedure TCodeFontFollow.Apply;
var
  Name: string;
  Size, I: Integer;
  F: TFont;
begin
  if FControls = nil then Exit;
  KitCodeFont(Name, Size);
  for I := 0 to FControls.Count - 1 do
  begin
    F := TControlAccess(FControls[I]).Font;
    if (F.Name <> Name) or (F.Size <> Size) then
    begin
      F.Name := Name;
      F.Size := Size;
    end;
  end;
end;

{ the notice: the fonts before the form's own handling, which may measure with them }
procedure TCodeFontFollow.Hook(var Message: TMessage);
begin
  if KitIsEditorOptionsMessage(Message.Msg) then Apply;
  CallOld(Message);
  if Message.Msg = WM_CREATE then Apply;
end;

procedure KitUseIdeFont(Form: TCustomForm; DesignTextHeight: Integer);
var
  Ide: TFont;
  CodeName: string;
  CodeSize, I, H: Integer;
  C: TComponent;
  F: TFont;
  Heights: TList;
  Follow: TCodeFontFollow;
begin
  Ide := TFont.Create;
  Heights := TList.Create;
  try
    Ide.Assign(TControlAccess(Form).Font);
    KitIdeFont(Ide);
    KitCodeFont(CodeName, CodeSize);
    { the controls' font heights of the design, before ScaleBy changes them }
    for I := 0 to Form.ComponentCount - 1 do
    begin
      C := Form.Components[I];
      if C is TControl then Heights.Add(Pointer(TControlAccess(C).Font.Height)) else Heights.Add(nil);
    end;
    H := TextHeightOf(Ide);
    if (H > 0) and (H <> DesignTextHeight) then Form.ScaleBy(H, DesignTextHeight);
    TControlAccess(Form).Font.Name := Ide.Name;
    TControlAccess(Form).Font.Charset := Ide.Charset;
    TControlAccess(Form).Font.Height := Ide.Height;
    for I := 0 to Form.ComponentCount - 1 do
    begin
      C := Form.Components[I];
      if not (C is TControl) or TControlAccess(C).ParentFont then Continue;
      F := TControlAccess(C).Font;
      if SameText(F.Name, DesignCodeFont) then
      begin
        F.Name := CodeName;
        F.Size := CodeSize;
        Follow := TCodeFontFollow(FindHook(Form, TCodeFontFollow));
        if Follow = nil then Follow := TCodeFontFollow.Create(Form);
        Follow.Add(TControl(C));
      end
      else if SameText(F.Name, DesignFontName) then
      begin
        F.Name := Ide.Name;
        F.Charset := Ide.Charset;
        F.Height := MulDiv(Integer(Heights[I]), Ide.Height, DesignFontHeight);
      end;
    end;
  finally
    Heights.Free;
    Ide.Free;
  end;
end;

{ ---------------------------------------------------------------- the IDE's icons }

function KitIdeImages: TCustomImageList;
var
  S: INTAServices;
begin
  Result := nil;
  try
    if Supports(BorlandIDEServices, INTAServices, S) then Result := S.ImageList;
  except
    Result := nil;
  end;
end;

function KitIdeActionImage(const Name: string): Integer;
var
  S: INTAServices;
  L: TCustomActionList;
  I: Integer;
begin
  Result := -1;
  try
    if not Supports(BorlandIDEServices, INTAServices, S) then Exit;
    L := S.ActionList;
    if L = nil then Exit;
    for I := 0 to L.ActionCount - 1 do
      if SameText(L.Actions[I].Name, Name) and (L.Actions[I] is TCustomAction) then
      begin
        Result := TCustomAction(L.Actions[I]).ImageIndex;
        Exit;
      end;
  except
    Result := -1;
  end;
end;

{ ---------------------------------------------------------------- glyph images }

var
  IconFontName: string;
  IconFontKnown: Boolean;

function KitIconFont: string;
begin
  if not IconFontKnown then
  begin
    IconFontKnown := True;
    if Screen.Fonts.IndexOf('Segoe Fluent Icons') >= 0 then IconFontName := 'Segoe Fluent Icons'
    else if Screen.Fonts.IndexOf('Segoe MDL2 Assets') >= 0 then IconFontName := 'Segoe MDL2 Assets'
    else IconFontName := '';
  end;
  Result := IconFontName;
end;

const
  { an image list without alpha: the pixels of this colour are transparent (ImageList_AddMasked) }
  GlyphKey = $00FF00FF;
  { ... and the pixels a glyph covers less than this (of 255) }
  GlyphKeyCoverage = 48;

{ comctl32 6 (a manifest asks for it: D7 Studio) blends an image list's alpha; Delphi 7's IDE runs on
  comctl32 5, which draws none (transparent pixels came out black) }
function ListAlpha: Boolean;
begin
  Result := GetComCtlVersion >= ComCtlVersionIE6;
end;

{ a 16 x 16 image list for Count images: 32 bits with alpha, else 24 with a mask }
function NewIconList(Count: Integer; Alpha: Boolean): HIMAGELIST;
begin
  if Alpha then Result := ImageList_Create(16, 16, ILC_COLOR32, Count, 1)
  else Result := ImageList_Create(16, 16, ILC_COLOR24 or ILC_MASK, Count, 1);
end;

{ Bmp (of ListPixel's pixels) added to List, then freed }
procedure AddIconBitmap(List: HIMAGELIST; Bmp: HBITMAP; Alpha: Boolean);
begin
  if Alpha then ImageList_Add(List, Bmp, 0) else ImageList_AddMasked(List, Bmp, GlyphKey);
  DeleteObject(Bmp);
end;

{ a 16 x 16 DIB section of 32 bits, top-down, and its pixels }
function NewIconDib(out Bits: PCardinal): HBITMAP;
var
  BI: TBitmapInfo;
begin
  FillChar(BI, SizeOf(BI), 0);
  BI.bmiHeader.biSize := SizeOf(BI.bmiHeader);
  BI.bmiHeader.biWidth := 16;
  BI.bmiHeader.biHeight := -16;
  BI.bmiHeader.biPlanes := 1;
  BI.bmiHeader.biBitCount := 32;
  BI.bmiHeader.biCompression := BI_RGB;
  Result := CreateDIBSection(0, BI, DIB_RGB_COLORS, Pointer(Bits), 0, 0);
end;

{ a pixel of the colour R G B of alpha A (of 255) as an image list takes it: with alpha
  premultiplied, as comctl32 6 blends it; else opaque, blended onto Ground (an RGB colour), and
  GlyphKey where the image hardly covers it (Cover: its alpha before a disabled image's was made
  fainter - the mask keeps its shape) }
function ListPixel(A, Cover, R, G, B, Ground: Cardinal; Alpha: Boolean): Cardinal;
begin
  if Alpha then
    Result := A shl 24 or (R * A div 255) shl 16 or (G * A div 255) shl 8 or (B * A div 255)
  else if Cover < GlyphKeyCoverage then
    Result := GlyphKey
  else
    Result := ((R * A + GetRValue(Ground) * (255 - A)) div 255) shl 16 or
      ((G * A + GetGValue(Ground) * (255 - A)) div 255) shl 8 or
      ((B * A + GetBValue(Ground) * (255 - A)) div 255);
end;

{ a 16 x 16 glyph in Color (ListPixel's pixels for Ground and Alpha), drawn white on black in grey
  anti-aliasing: the green channel is its coverage }
function GlyphBitmap(Font: HFONT; Code: Word; Color, Ground: TColor; Alpha: Boolean): HBITMAP;
var
  Bits, P: PCardinal;
  DC: HDC;
  Old: HGDIOBJ;
  R: TRect;
  W: WideChar;
  I: Integer;
  C, G: Cardinal;
begin
  DC := CreateCompatibleDC(0);
  Result := NewIconDib(Bits);
  Old := SelectObject(DC, Result);
  SelectObject(DC, Font);
  FillChar(Bits^, 16 * 16 * 4, 0);
  SetBkMode(DC, TRANSPARENT);
  SetTextColor(DC, $FFFFFF);
  R := Rect(0, 0, 16, 16);
  W := WideChar(Code);
  DrawTextW(DC, @W, 1, R, DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX or DT_NOCLIP);
  GdiFlush;
  C := ColorToRGB(Color);
  G := ColorToRGB(Ground);
  P := Bits;
  for I := 1 to 16 * 16 do
  begin
    P^ := ListPixel((P^ shr 8) and $FF, (P^ shr 8) and $FF, GetRValue(C), GetGValue(C), GetBValue(C), G, Alpha);
    Inc(P);
  end;
  SelectObject(DC, Old);
  DeleteDC(DC);
end;

function KitGlyphImages(Images: TCustomImageList; const Codes: array of Word; Color, Ground: TColor): Boolean;
var
  Name: string;
  LF: TLogFont;
  Font: HFONT;
  List: HIMAGELIST;
  I: Integer;
  Alpha: Boolean;
begin
  Name := KitIconFont;
  Result := Name <> '';
  if not Result then Exit;
  FillChar(LF, SizeOf(LF), 0);
  LF.lfHeight := -16;
  LF.lfWeight := FW_NORMAL;
  LF.lfCharSet := DEFAULT_CHARSET;
  LF.lfQuality := ANTIALIASED_QUALITY;
  StrPLCopy(LF.lfFaceName, Name, LF_FACESIZE - 1);
  Font := CreateFontIndirect(LF);
  Alpha := ListAlpha;
  List := NewIconList(Length(Codes), Alpha);
  for I := 0 to High(Codes) do AddIconBitmap(List, GlyphBitmap(Font, Codes[I], Color, Ground, Alpha), Alpha);
  DeleteObject(Font);
  Images.Handle := List;
end;

{ ---------------------------------------------------------------- bitmap images }

type
  { pixels of 16 x 16 cells: B G R A (straight alpha) per pixel, 256 per cell, each top-down }
  TKitCellPixels = array of Cardinal;

{ the cells of the module's bitmap resource ResName (RCDATA): their number, 0 when there is no such
  bitmap - 32 bits, BI_RGB, 16 pixels high, a width of whole cells }
function ResourceCells(const ResName: string; out Pixels: TKitCellPixels): Integer;
var
  Res: HRSRC;
  P: PChar;
  Info: PBitmapInfoHeader;
  Row: PCardinal;
  N, X, Y, I: Integer;
begin
  Result := 0;
  Pixels := nil;
  Res := FindResource(HInstance, PChar(ResName), RT_RCDATA);
  if Res = 0 then Exit;
  P := LockResource(LoadResource(HInstance, Res));
  if (P = nil) or (SizeofResource(HInstance, Res) < SizeOf(TBitmapFileHeader) + SizeOf(TBitmapInfoHeader)) then Exit;
  Info := PBitmapInfoHeader(P + SizeOf(TBitmapFileHeader));
  if (Info.biBitCount <> 32) or (Info.biCompression <> BI_RGB) or (Info.biHeight <> 16) or
    (Info.biWidth <= 0) or (Info.biWidth mod 16 <> 0) or
    (Integer(SizeofResource(HInstance, Res)) < Integer(PBitmapFileHeader(P).bfOffBits) + Info.biWidth * 16 * 4) then Exit;
  N := Info.biWidth div 16;
  SetLength(Pixels, 256 * N);
  for Y := 0 to 15 do
  begin
    { bottom-up: the file's first row is the cells' last }
    Row := PCardinal(P + PBitmapFileHeader(P).bfOffBits + (15 - Y) * Info.biWidth * 4);
    for I := 0 to N - 1 do
      for X := 0 to 15 do
      begin
        Pixels[I * 256 + Y * 16 + X] := Row^;
        Inc(Row);
      end;
  end;
  Result := N;
end;

{ a pixel (straight alpha, $AARRGGBB) of a disabled image as Visual Studio greys it - its
  ImageThemingUtilities.GrayscaleDIBits with ImageLibrary.DefaultGrayscaleBiasColor #40FFFFFF, as D7
  Studio's SdUI.UIGreyPixel: the luminance 0.30 R + 0.59 G + 0.11 B in every channel, a quarter of
  the alpha }
function GreyPixel(P: Cardinal): Cardinal;
var
  L: Cardinal;
begin
  L := (30 * ((P shr 16) and $FF) + 59 * ((P shr 8) and $FF) + 11 * (P and $FF)) * 255 div 25600;
  Result := ((P shr 24) div 4) shl 24 or L shl 16 or L shl 8 or L;
end;

function KitBitmapImages(Images: TCustomImageList; const ResName: string; const Cells: array of Integer;
  Grey: Boolean): Boolean;
var
  Pixels: TKitCellPixels;
  N, I, J: Integer;
  Alpha: Boolean;
  List: HIMAGELIST;
  Bmp: HBITMAP;
  Bits: PCardinal;
  P, Cover, Ground: Cardinal;
begin
  N := ResourceCells(ResName, Pixels);
  Result := N > 0;
  for I := 0 to High(Cells) do
    if (Cells[I] < 0) or (Cells[I] >= N) then Result := False;
  if not Result then Exit;
  Alpha := ListAlpha;
  Ground := ColorToRGB(clBtnFace);
  List := NewIconList(Length(Cells), Alpha);
  for I := 0 to High(Cells) do
  begin
    Bmp := NewIconDib(Bits);
    for J := 0 to 255 do
    begin
      P := Pixels[Cells[I] * 256 + J];
      Cover := P shr 24;
      if Grey then P := GreyPixel(P);
      Bits^ := ListPixel(P shr 24, Cover, (P shr 16) and $FF, (P shr 8) and $FF, P and $FF, Ground, Alpha);
      Inc(Bits);
    end;
    AddIconBitmap(List, Bmp, Alpha);
  end;
  Images.Handle := List;
end;

{ ---------------------------------------------------------------- cue text }

type
  TCueHook = class(TKitWindowHook)
  private
    FCue: string;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TCueHook.Hook(var Message: TMessage);
var
  DC: HDC;
  R: TRect;
  OldFont: HGDIOBJ;
begin
  CallOld(Message);
  if (Message.Msg = WM_PAINT) and (GetWindowTextLength(Control.Handle) = 0) then
  begin
    Control.Perform(EM_GETRECT, 0, Integer(@R));
    DC := GetDC(Control.Handle);
    try
      OldFont := SelectObject(DC, TCustomMemo(Control).Perform(WM_GETFONT, 0, 0));
      SetBkMode(DC, TRANSPARENT);
      SetTextColor(DC, ColorToRGB(clGrayText));
      DrawText(DC, PChar(FCue), Length(FCue), R, DT_LEFT or DT_TOP or DT_NOPREFIX or DT_WORDBREAK);
      SelectObject(DC, OldFont);
    finally
      ReleaseDC(Control.Handle, DC);
    end;
  end;
end;

procedure KitCueText(Memo: TCustomMemo; const Cue: string);
var
  H: TCueHook;
begin
  H := TCueHook(FindHook(Memo, TCueHook));
  if H = nil then H := TCueHook.Create(Memo);
  H.FCue := Cue;
  Memo.Invalidate;
end;

{ ---------------------------------------------------------------- TKitNewTextBox }

const
  GlyphDown = $E74B;           // Down of Segoe Fluent Icons and Segoe MDL2 Assets
  ArrowDown = $2193;           // the down arrow of the text fonts, without an icon font

constructor TKitNewTextBox.Create(AOwner: TComponent);
begin
  inherited;
  ControlStyle := [csOpaque, csClickEvents, csCaptureMouse];
  DoubleBuffered := True;
  Cursor := crHandPoint;
  TabStop := False;
  Visible := False;
end;

{ 8 px, the arrow in a square of the text's height, 4 px, the caption, 10 px; the text's height
  and 4 px above and below it }
procedure TKitNewTextBox.FitSize;
var
  H: Integer;
begin
  Canvas.Font := Font;
  H := Canvas.TextHeight('Ag');
  SetBounds(Left, Top, 8 + H + 4 + Canvas.TextWidth(Caption) + 10, H + 8);
end;

procedure TKitNewTextBox.Paint;
var
  R: TRect;
  H, Y: Integer;
  Code: Word;
  W: WideChar;
  Ground: TColor;
begin
  R := ClientRect;
  if Owner is TKitRichView then Ground := TKitRichView(Owner).Color else Ground := clWindow;
  DrawAccent(Canvas.Handle, R, Ground, FHot);
  Canvas.Font := Font;
  H := Canvas.TextHeight('Ag');
  Y := (R.Bottom - H) div 2;
  SetBkMode(Canvas.Handle, TRANSPARENT);
  if KitIconFont <> '' then
  begin
    Canvas.Font.Name := KitIconFont;
    Canvas.Font.Height := -(H * 4 div 5);
    Code := GlyphDown;
  end
  else Code := ArrowDown;
  Canvas.Font.Color := KitAccent;
  W := WideChar(Code);
  R := Rect(8, Y, 8 + H, Y + H);
  DrawTextW(Canvas.Handle, @W, 1, R, DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
  Canvas.Font := Font;
  Canvas.Font.Color := KitAccent;
  R := Rect(8 + H + 4, 0, ClientWidth, ClientHeight);
  DrawText(Canvas.Handle, PChar(Caption), Length(Caption), R, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
end;

procedure TKitNewTextBox.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

{ the wheel over the box scrolls the view under it }
procedure TKitNewTextBox.WMMouseWheel(var Message: TMessage);
begin
  if Owner is TWinControl then
    Message.Result := TWinControl(Owner).Perform(WM_MOUSEWHEEL, Message.WParam, Message.LParam);
end;

procedure TKitNewTextBox.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  FHot := True;
  Invalidate;
end;

procedure TKitNewTextBox.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FHot := False;
  Invalidate;
end;

{ ---------------------------------------------------------------- TKitRichView }

const
  EM_SETTEXTEX = WM_USER + 97;
  ST_KEEPUNDO = 1;
  ST_SELECTION = 2;
  EM_GETSCROLLPOS_ = WM_USER + 221;
  EM_SETSCROLLPOS_ = WM_USER + 222;
  EM_SETTYPOGRAPHYOPTIONS = WM_USER + 202;
  TO_ADVANCEDTYPOGRAPHY = 1;
  CP_UNICODE = 1200;
  TwipsPerPixel = 15;        // 1440 / 96

type
  TSetTextEx = record
    flags: DWORD;
    codepage: UINT;
  end;

var
  MsftEdit: HMODULE;

constructor TKitRichView.Create(AOwner: TComponent);
begin
  inherited;
  ControlStyle := ControlStyle - [csSetCaption] + [csOpaque];
  { its own ground, not its parent's (a view's clBtnFace) }
  ParentColor := False;
  Color := clWindow;
  TabStop := True;
  Width := 200;
  Height := 150;
  FPadding := Rect(10, 6, 6, 6);
  FCodeFontName := DesignCodeFont;
  FCodeFontSize := 10;
end;

procedure TKitRichView.CreateParams(var Params: TCreateParams);
begin
  if MsftEdit = 0 then MsftEdit := LoadLibrary('Msftedit.dll');
  inherited;
  CreateSubClass(Params, 'RICHEDIT50W');
  { WS_BORDER: the flat frame of the views (WMNCPaint) }
  Params.Style := Params.Style or WS_VSCROLL or ES_MULTILINE or ES_READONLY or ES_NOHIDESEL or WS_BORDER;
  Params.ExStyle := Params.ExStyle and not WS_EX_CLIENTEDGE;
  Params.WindowClass.style := Params.WindowClass.style and not (CS_HREDRAW or CS_VREDRAW);
end;

{ the text kept as RTF while the window is made again (the dock moves the view to another parent):
  streamed out before the window goes, in after the new one is made }
type
  PRtfBuffer = ^TRtfBuffer;
  TRtfBuffer = record
    Data: string;
    Pos: Integer;            // read so far (streaming in)
  end;

function RtfOut(dwCookie: Longint; pbBuff: PByte; cb: Longint; var pcb: Longint): Longint; stdcall;
var
  B: PRtfBuffer;
  L: Integer;
begin
  B := PRtfBuffer(dwCookie);
  L := Length(B^.Data);
  SetLength(B^.Data, L + cb);
  if cb > 0 then Move(pbBuff^, B^.Data[L + 1], cb);
  pcb := cb;
  Result := 0;
end;

function RtfIn(dwCookie: Longint; pbBuff: PByte; cb: Longint; var pcb: Longint): Longint; stdcall;
var
  B: PRtfBuffer;
  N: Integer;
begin
  B := PRtfBuffer(dwCookie);
  N := Length(B^.Data) - B^.Pos;
  if N > cb then N := cb;
  if N > 0 then Move(B^.Data[B^.Pos + 1], pbBuff^, N);
  Inc(B^.Pos, N);
  pcb := N;
  Result := 0;
end;

{ the reader's place before the text is laid out again (a new window, another code font): at the
  bottom, else the character at the top of the text rectangle and its line's top from there }
procedure TKitRichView.SavePlace;
var
  R: TRect;
  P: TPoint;
begin
  FSavedBottom := FEndPending or AtBottom;
  Perform(EM_GETRECT, 0, Integer(@R));
  P := R.TopLeft;
  FSavedTop := Perform(EM_CHARFROMPOS, 0, Integer(@P));
  P.X := 0;
  P.Y := 0;
  Perform(EM_POSFROMCHAR, Integer(@P), FSavedTop);
  FSavedTopY := P.Y - R.Top;
end;

{ ... and after: the bottom (the view follows on), else that character at the same height }
procedure TKitRichView.RestorePlace;
var
  R: TRect;
  P, S: TPoint;
begin
  if FSavedBottom then
  begin
    ScrollToEnd;
    Exit;
  end;
  LayOutAll;
  Perform(EM_GETRECT, 0, Integer(@R));
  Perform(EM_GETSCROLLPOS_, 0, Integer(@S));
  P.X := 0;
  P.Y := 0;
  Perform(EM_POSFROMCHAR, Integer(@P), FSavedTop);
  S.X := 0;
  Inc(S.Y, P.Y - R.Top - FSavedTopY);
  Perform(EM_SETSCROLLPOS_, 0, Integer(@S));
end;

{ A change of the text or its layout (AddText, Clear, CreateWnd, SetCodeFont) sets the place itself:
  FChanging keeps WMSize and the Behind check out. With Freeze, a visible window, Rich Edit's drawing
  is off and the caret erased (a caret hidden while the drawing is off leaves its image); EndChange
  then draws the client from FromY down and the frame (the scroll bar). A hidden window is left as
  it is: WM_SETREDRAW would make it visible. }
function TKitRichView.BeginChange(Freeze: Boolean): Boolean;
begin
  FChanging := True;
  Result := Freeze and IsWindowVisible(Handle);
  if Result then
  begin
    HideCaret(Handle);
    Perform(WM_SETREDRAW, 0, 0);
  end;
end;

procedure TKitRichView.EndChange(Frozen: Boolean; FromY: Integer);
var
  R: TRect;
begin
  FChanging := False;
  if not Frozen then Exit;
  Perform(WM_SETREDRAW, 1, 0);
  R := ClientRect;
  if FromY > R.Top then R.Top := FromY;
  if R.Top < R.Bottom then InvalidateRect(Handle, @R, False);
  Perform(WM_NCPAINT, 1, 0);
  ShowCaret(Handle);
end;

{ The reader's place comes back with the text (SavePlace in DestroyWnd), and Behind (the new text
  box) as it was. The code takes the editor's font as it is now: the notice of a change does not
  reach a window that did not exist. The window may be made in another size; WMSize keeps the place
  then. }
procedure TKitRichView.CreateWnd;
var
  B: TRtfBuffer;
  ES: TEditStream;
  Name: string;
  Size: Integer;
begin
  BeginChange(False);
  try
    inherited;
    { Rich Edit adds a sunken client edge to WS_BORDER as it is made (a 3 px frame): the flat 1 px
      border alone stays }
    if GetWindowLong(Handle, GWL_EXSTYLE) and WS_EX_CLIENTEDGE <> 0 then
    begin
      SetWindowLong(Handle, GWL_EXSTYLE, GetWindowLong(Handle, GWL_EXSTYLE) and not WS_EX_CLIENTEDGE);
      SetWindowPos(Handle, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE or
        SWP_FRAMECHANGED);
    end;
    Perform(EM_SETTYPOGRAPHYOPTIONS, TO_ADVANCEDTYPOGRAPHY, TO_ADVANCEDTYPOGRAPHY);
    Perform(EM_SETEVENTMASK, 0, 0);
    Perform(EM_SETUNDOLIMIT, 0, 0);
    ApplyColor;
    ApplyPadding;
    KitCodeFont(Name, Size);
    if (Name <> FCodeFontName) or (Size <> FCodeFontSize) then
    begin
      FCodeFontName := Name;
      FCodeFontSize := Size;
      if FCodeRunCount > 0 then FCodeRunsStale := True;
    end;
    if FSaved <> '' then
    begin
      B.Data := FSaved;
      B.Pos := 0;
      FSaved := '';
      ES.dwCookie := Longint(@B);
      ES.dwError := 0;
      ES.pfnCallback := @RtfIn;
      Perform(EM_STREAMIN, SF_RTF, Longint(@ES));
      if FCodeRunsStale then FormatCodeRuns;
      FCodeRunsStale := False;
      RestorePlace;
    end;
  finally
    EndChange(False, 0);
  end;
end;

procedure TKitRichView.DestroyWnd;
var
  B: TRtfBuffer;
  ES: TEditStream;
begin
  { a KitFollowEndMessage on its way goes with the window (FEndPending stays: SavePlace takes it) }
  FEndPosted := False;
  if TextLength > 0 then
  begin
    SavePlace;
    B.Data := '';
    B.Pos := 0;
    ES.dwCookie := Longint(@B);
    ES.dwError := 0;
    ES.pfnCallback := @RtfOut;
    Perform(EM_STREAMOUT, SF_RTF, Longint(@ES));
    FSaved := B.Data;
  end;
  inherited;
end;

procedure TKitRichView.WMNCPaint(var Message: TWMNCPaint);
begin
  inherited;
  KitPaintFrame(Handle);
end;

{ Rich Edit scrolls and draws again only its own rectangle (EM_GETRECT: the padding's inside, 1 px
  wider than what EM_SETRECT gave on the left, top and right), so after a scroll the padding above
  and below it kept the pixels of the place before; a full repaint draws the line its bottom cuts
  into the padding, in some states a line of another place. The padding is therefore taken out of
  what Rich Edit draws and filled with the view's ground: the text ends at the padding. }
procedure TKitRichView.WMPaint(var Message: TWMPaint);
var
  R: TRect;
  Bands: array[0..1] of TRect;
  Fill: array[0..1] of Boolean;
  Rgn: HRGN;
  DC: HDC;
  Brush: HBRUSH;
  I: Integer;
begin
  Fill[0] := False;
  Fill[1] := False;
  if Message.DC = 0 then
  begin
    Perform(EM_GETRECT, 0, Integer(@R));
    Bands[0] := Rect(0, 0, ClientWidth, R.Top);
    Bands[1] := Rect(0, R.Bottom, ClientWidth, ClientHeight);
    Rgn := CreateRectRgn(0, 0, 0, 0);
    try
      if GetUpdateRgn(Handle, Rgn, False) <> NULLREGION then
        for I := 0 to 1 do
          if not IsRectEmpty(Bands[I]) and RectInRegion(Rgn, Bands[I]) then
          begin
            ValidateRect(Handle, @Bands[I]);
            Fill[I] := True;
          end;
    finally
      DeleteObject(Rgn);
    end;
  end;
  inherited;
  if Fill[0] or Fill[1] then
  begin
    DC := GetDC(Handle);
    Brush := CreateSolidBrush(ColorToRGB(Color));
    try
      for I := 0 to 1 do
        if Fill[I] then FillRect(DC, Bands[I], Brush);
    finally
      DeleteObject(Brush);
      ReleaseDC(Handle, DC);
    end;
  end;
end;

procedure TKitRichView.ApplyColor;
begin
  if HandleAllocated then Perform(EM_SETBKGNDCOLOR, 0, ColorToRGB(Color));
end;

procedure TKitRichView.ApplyPadding;
var
  R: TRect;
begin
  if not HandleAllocated then Exit;
  R := ClientRect;
  Inc(R.Left, FPadding.Left);
  Inc(R.Top, FPadding.Top);
  Dec(R.Right, FPadding.Right);
  Dec(R.Bottom, FPadding.Bottom);
  if R.Right <= R.Left then R.Right := R.Left + 1;
  if R.Bottom <= R.Top then R.Bottom := R.Top + 1;
  Perform(EM_SETRECT, 0, Integer(@R));
end;

{ Rich Edit keeps the top line when a new width wraps the text again: a view at the bottom is taken
  there again once the size has settled (KMFollowEnd, posted once for the sizes of one change). Not
  while AddText, Clear, CreateWnd or SetCodeFont change the text: Rich Edit sends WM_SIZE from inside
  them as its scroll bar comes or goes, and they set the place themselves }
procedure TKitRichView.WMSize(var Message: TWMSize);
begin
  if not FChanging and (TextLength > 0) and (FEndPending or AtBottom) then
  begin
    FEndPending := True;
    if not FEndPosted then FEndPosted := PostMessage(Handle, KitFollowEndMessage, 0, 0);
  end;
  inherited;
  ApplyPadding;
end;

{ The end of a view whose size changed while it was there. A view too small for its padding has no
  room to lay the text out in (ApplyPadding's 1 px rectangle): the end waits for a size with room.
  Going there can bring or take away the scroll bar, which wraps the text again: then once more. }
procedure TKitRichView.KMFollowEnd(var Message: TMessage);
var
  R: TRect;
begin
  FEndPosted := False;
  if not FEndPending then Exit;
  R := ClientRect;
  if (R.Right - R.Left <= FPadding.Left + FPadding.Right) or
    (R.Bottom - R.Top <= FPadding.Top + FPadding.Bottom) then Exit;
  BeginChange(False);
  try
    ScrollToEnd;
    if not AtBottom then ScrollToEnd;
  finally
    EndChange(False, 0);
  end;
end;

procedure TKitRichView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  { Rich Edit paints its whole client area itself }
  Message.Result := 1;
end;

procedure TKitRichView.CMColorChanged(var Message: TMessage);
begin
  inherited;
  ApplyColor;
end;

procedure TKitRichView.CMFontChanged(var Message: TMessage);
begin
  inherited;
  Invalidate;
  { the box is in the view's font }
  if (FNewTextBox <> nil) and FNewTextBox.Visible then
  begin
    FitNewTextBox;
    MoveNewTextBox;
  end;
end;

function TKitRichView.TextLength: Integer;
var
  G: TGetTextLengthEx;
begin
  Result := 0;
  if not HandleAllocated then Exit;
  G.flags := GTL_NUMCHARS or GTL_PRECISE;
  G.codepage := CP_UNICODE;
  Result := Perform(EM_GETTEXTLENGTHEX, Integer(@G), 0);
end;

function TKitRichView.HasSelection: Boolean;
var
  R: TCharRange;
begin
  Perform(EM_EXGETSEL, 0, Integer(@R));
  Result := R.cpMax > R.cpMin;
end;

{ Rich Edit hides its scroll bar when the text fits (WS_VSCROLL goes) and keeps the old range in
  it: no scroll bar is the bottom }
function TKitRichView.AtBottom: Boolean;
var
  SI: TScrollInfo;
begin
  SI.cbSize := SizeOf(SI);
  SI.fMask := SIF_ALL;
  if (GetWindowLong(Handle, GWL_STYLE) and WS_VSCROLL = 0) or not GetScrollInfo(Handle, SB_VERT, SI) or
    (SI.nMax <= 0) or (Integer(SI.nPage) > SI.nMax) then
    Result := True
  else
    Result := SI.nPos + Integer(SI.nPage) >= SI.nMax - 2;
end;

{ Rich Edit lays text out as far as it shows it and the rest later (streamed in, after the width
  changed): the bottom of a view not laid out to its end is short of the end }
procedure TKitRichView.LayOutAll;
begin
  Perform(EM_GETLINECOUNT, 0, 0);
end;

procedure TKitRichView.ScrollToEnd;
begin
  if not HandleAllocated then Exit;
  FEndPending := False;
  LayOutAll;
  Perform(WM_VSCROLL, SB_BOTTOM, 0);
end;

{ text in the code font from Start to Stop, joined to the run before it when they meet in one size }
procedure TKitRichView.AddCodeRun(Start, Stop, SizeDelta: Integer);
begin
  if Stop <= Start then Exit;
  if (FCodeRunCount > 0) and (FCodeRuns[FCodeRunCount - 1].Stop = Start) and
    (FCodeRuns[FCodeRunCount - 1].SizeDelta = SizeDelta) then
  begin
    FCodeRuns[FCodeRunCount - 1].Stop := Stop;
    Exit;
  end;
  if FCodeRunCount = Length(FCodeRuns) then SetLength(FCodeRuns, FCodeRunCount * 2 + 16);
  FCodeRuns[FCodeRunCount].Start := Start;
  FCodeRuns[FCodeRunCount].Stop := Stop;
  FCodeRuns[FCodeRunCount].SizeDelta := SizeDelta;
  Inc(FCodeRunCount);
end;

{ a character format's face and size: Name, Size points (CFM_FACE, CFM_SIZE, CFM_CHARSET in its mask) }
procedure SetCharFace(var CF: TCharFormat2W; const Name: string; Size: Integer);
begin
  StringToWideChar(Name, CF.szFaceName, LF_FACESIZE);
  CF.yHeight := Size * 20;
  CF.bCharSet := DEFAULT_CHARSET;
end;

{ the code runs in the code font, each in its size; the selection kept }
procedure TKitRichView.FormatCodeRuns;
var
  I: Integer;
  Sel, OldSel: TCharRange;
  CF: TCharFormat2W;
begin
  Perform(EM_EXGETSEL, 0, Integer(@OldSel));
  FillChar(CF, SizeOf(CF), 0);
  CF.cbSize := SizeOf(CF);
  CF.dwMask := CFM_FACE or CFM_SIZE or CFM_CHARSET;
  for I := 0 to FCodeRunCount - 1 do
  begin
    Sel.cpMin := FCodeRuns[I].Start;
    Sel.cpMax := FCodeRuns[I].Stop;
    Perform(EM_EXSETSEL, 0, Integer(@Sel));
    SetCharFace(CF, FCodeFontName, FCodeFontSize + FCodeRuns[I].SizeDelta);
    Perform(EM_SETCHARFORMAT, SCF_SELECTION, Integer(@CF));
  end;
  Perform(EM_EXSETSEL, 0, Integer(@OldSel));
end;

{ The text there is laid out again in the new font: with the drawing off, then drawn once at the
  reader's place. Without a window (made again) the runs take the font in CreateWnd }
procedure TKitRichView.SetCodeFont(const Name: string; Size: Integer);
var
  Frozen: Boolean;
begin
  if (Name = FCodeFontName) and (Size = FCodeFontSize) then Exit;
  FCodeFontName := Name;
  FCodeFontSize := Size;
  if FCodeRunCount = 0 then Exit;
  if not HandleAllocated then
  begin
    FCodeRunsStale := True;
    Exit;
  end;
  SavePlace;
  Frozen := BeginChange(True);
  try
    FormatCodeRuns;
    RestorePlace;
  finally
    EndChange(Frozen, 0);
  end;
end;

procedure TKitRichView.SetCodeFontName(const Value: string);
begin
  SetCodeFont(Value, FCodeFontSize);
end;

procedure TKitRichView.SetCodeFontSize(Value: Integer);
begin
  SetCodeFont(FCodeFontName, Value);
end;

procedure TKitRichView.WndProc(var Message: TMessage);
var
  Name: string;
  Size: Integer;
begin
  { D7 Studio applied its options: the code in the editor's font as it is now }
  if KitIsEditorOptionsMessage(Message.Msg) then
  begin
    KitCodeFont(Name, Size);
    SetCodeFont(Name, Size);
  end;
  inherited WndProc(Message);
  { at the bottom again (scrolled there, Ctrl+End, the box clicked, the text cleared): nothing new
    below the reader's place any more. Not while the text and the place change (FChanging), nor while
    the window goes. The check is two calls, while the box shows only }
  if FBehind and not FChanging and (WindowHandle <> 0) and not (csDestroying in ComponentState) and
    (Message.Msg <> WM_DESTROY) and (Message.Msg <> WM_NCDESTROY) and AtBottom then
    SetBehind(False);
end;

procedure TKitRichView.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited;
  if (Operation = opRemove) and (AComponent = FNewTextBox) then FNewTextBox := nil;
end;

procedure TKitRichView.SetBehind(Value: Boolean);
begin
  if FBehind = Value then Exit;
  FBehind := Value;
  if Value then
  begin
    if (FNewTextCaption = '') or (Parent = nil) then Exit;
    if FNewTextBox = nil then
    begin
      FNewTextBox := TKitNewTextBox.Create(Self);
      FNewTextBox.OnClick := NewTextBoxClick;
    end;
    FitNewTextBox;
    MoveNewTextBox;
    FNewTextBox.BringToFront;
    FNewTextBox.Visible := True;
  end
  else if FNewTextBox <> nil then
    FNewTextBox.Visible := False;
end;

{ the box in the view's parent, in the view's font, its size for the caption }
procedure TKitRichView.FitNewTextBox;
begin
  if (FNewTextBox = nil) or (Parent = nil) then Exit;
  if FNewTextBox.Parent <> Parent then FNewTextBox.Parent := Parent;
  FNewTextBox.Font := Font;
  FNewTextBox.Caption := FNewTextCaption;
  FNewTextBox.FitSize;
end;

{ the box centred over the view's text, above its foot by a third of its height and the padding }
procedure TKitRichView.MoveNewTextBox;
var
  P: TPoint;
begin
  if (FNewTextBox = nil) or (FNewTextBox.Parent = nil) or not HandleAllocated or
    (csDestroying in ComponentState) then Exit;
  P := FNewTextBox.Parent.ScreenToClient(ClientOrigin);
  FNewTextBox.SetBounds(P.X + (ClientWidth - FNewTextBox.Width) div 2,
    P.Y + ClientHeight - FPadding.Bottom - FNewTextBox.Height - FNewTextBox.Height div 3,
    FNewTextBox.Width, FNewTextBox.Height);
end;

procedure TKitRichView.NewTextBoxClick(Sender: TObject);
begin
  ScrollToEnd;
end;

{ the box goes with the view (the window's size, the view's place in it) }
procedure TKitRichView.WMWindowPosChanged(var Message: TWMWindowPosChanged);
begin
  inherited;
  if (FNewTextBox <> nil) and FNewTextBox.Visible then MoveNewTextBox;
end;

procedure TKitRichView.AddText(const Text: WideString; const Fmt: TKitTextFormat);
var
  Bottom, Frozen: Boolean;
  OldSel, Sel: TCharRange;
  Pos, EndPos: TPoint;
  CF: TCharFormat2W;
  PF: TParaFormat2;
  ST: TSetTextEx;
  N, Len: Integer;
begin
  if Text = '' then Exit;
  HandleNeeded;
  { at the bottom, or at the end once a new size has settled (WMSize) }
  Bottom := FEndPending or AtBottom;
  N := TextLength;
  { Away from the bottom, Rich Edit scrolls to the insertion point at the end and draws the view
    there, then draws it again where it was when the place is restored: a flash of the end of the
    text for every piece appended. Its drawing is off meanwhile (BeginChange); afterwards only the
    lines from the old end down are drawn again (below the view: none) and the scroll bar.
    EM_POSFROMCHAR gives the top of a character's line, also on a line of mixed sizes. }
  EndPos.X := 0;
  EndPos.Y := 0;
  if not Bottom then Perform(EM_POSFROMCHAR, Integer(@EndPos), N);
  Frozen := BeginChange(not Bottom);
  try
    Perform(EM_GETSCROLLPOS_, 0, Integer(@Pos));
    Perform(EM_EXGETSEL, 0, Integer(@OldSel));
    Sel.cpMin := N;
    Sel.cpMax := N;
    Perform(EM_EXSETSEL, 0, Integer(@Sel));
    { the format of the insertion point: the text inserted takes it }
    FillChar(CF, SizeOf(CF), 0);
    CF.cbSize := SizeOf(CF);
    CF.dwMask := CFM_COLOR or CFM_BACKCOLOR or CFM_BOLD or CFM_ITALIC or CFM_FACE or CFM_SIZE or CFM_CHARSET;
    if Fmt.Color = clDefault then CF.crTextColor := ColorToRGB(Font.Color)
    else CF.crTextColor := ColorToRGB(Fmt.Color);
    if Fmt.Back = clNone then CF.dwEffects := CF.dwEffects or CFE_AUTOBACKCOLOR
    else CF.crBackColor := ColorToRGB(Fmt.Back);
    if Fmt.Bold then CF.dwEffects := CF.dwEffects or CFE_BOLD;
    if Fmt.Italic then CF.dwEffects := CF.dwEffects or CFE_ITALIC;
    if Fmt.Mono then SetCharFace(CF, FCodeFontName, FCodeFontSize + Fmt.SizeDelta)
    else SetCharFace(CF, Font.Name, Font.Size + Fmt.SizeDelta);
    Perform(EM_SETCHARFORMAT, SCF_SELECTION, Integer(@CF));
    { the paragraph's format is its first text's: a mark or inline code later in the line keeps it }
    if (N = 0) or (FLastChar = #13) then
    begin
      FillChar(PF, SizeOf(PF), 0);
      PF.cbSize := SizeOf(PF);
      PF.dwMask := PFM_STARTINDENT or PFM_SPACEBEFORE;
      PF.dxStartIndent := Fmt.Indent * TwipsPerPixel;
      PF.dySpaceBefore := Fmt.SpaceBefore * TwipsPerPixel;
      Perform(EM_SETPARAFORMAT, 0, Integer(@PF));
    end;
    FLastChar := Text[Length(Text)];
    ST.flags := ST_SELECTION;
    ST.codepage := CP_UNICODE;
    Perform(EM_SETTEXTEX, Integer(@ST), Integer(PWideChar(Text)));
    Len := TextLength;
    if Fmt.Mono then AddCodeRun(N, Len, Fmt.SizeDelta);
    { the reader's selection and place }
    if OldSel.cpMax > OldSel.cpMin then Perform(EM_EXSETSEL, 0, Integer(@OldSel))
    else
    begin
      Sel.cpMin := Len;
      Sel.cpMax := Len;
      Perform(EM_EXSETSEL, 0, Integer(@Sel));
    end;
    if Bottom then ScrollToEnd
    else Perform(EM_SETSCROLLPOS_, 0, Integer(@Pos));
  finally
    EndChange(Frozen, EndPos.Y);
  end;
  if not Bottom then SetBehind(True);
end;

procedure TKitRichView.Clear;
var
  ST: TSetTextEx;
  W: WideChar;
begin
  FLastChar := #0;
  FSaved := '';
  FCodeRunCount := 0;
  FCodeRunsStale := False;
  FEndPending := False;
  SetBehind(False);
  if not HandleAllocated then Exit;
  W := #0;
  ST.flags := 0;
  ST.codepage := CP_UNICODE;
  BeginChange(False);
  try
    Perform(EM_SETTEXTEX, Integer(@ST), Integer(@W));
  finally
    EndChange(False, 0);
  end;
end;

procedure TKitRichView.CopyToClipboard;
begin
  if HandleAllocated then Perform(WM_COPY, 0, 0);
end;

procedure TKitRichView.SelectAll;
var
  Sel: TCharRange;
begin
  if not HandleAllocated then Exit;
  Sel.cpMin := 0;
  Sel.cpMax := -1;
  Perform(EM_EXSETSEL, 0, Integer(@Sel));
end;

function KitTextWidthW(C: TCanvas; const W: WideString): Integer;
var
  Size: TSize;
begin
  Result := 0;
  if W = '' then Exit;
  if GetTextExtentPoint32W(C.Handle, PWideChar(W), Length(W), Size) then Result := Size.cx;
end;

function KitDialogColor: TColor;
var
  Dir: string;
  Ini: TIniFile;
begin
  Result := clWindow;
  Dir := GetEnvironmentVariable('D7S_HOME');
  if Dir = '' then Dir := ExtractFilePath(ParamStr(0));
  Dir := IncludeTrailingPathDelimiter(Dir);
  if not FileExists(Dir + 'D7Studio.ini') then Exit;
  Ini := TIniFile.Create(Dir + 'D7Studio.ini');
  try
    if Ini.ReadInteger('UI', 'DialogBackground', 0) = 1 then Result := clBtnFace;
  finally
    Ini.Free;
  end;
end;

procedure KitPrepareDialog(Form: TCustomForm);
var
  I: Integer;
begin
  KitUseIdeFont(Form);
  if TForm(Form).Color = clWindow then TForm(Form).Color := KitDialogColor;
  for I := 0 to Form.ComponentCount - 1 do
    if ((Form.Components[I] is TCustomEdit) and not (Form.Components[I] is TCustomMemo)) or
      (Form.Components[I] is TCustomComboBox) then
      KitFlatEdit(TWinControl(Form.Components[I]));
end;

procedure KitSection(Heading: TLabel; Rule: TControl);
var
  Right: Integer;
begin
  Heading.Font.Color := KitAccent;
  Right := Rule.Left + Rule.Width;
  Rule.Left := Heading.Left + Heading.Width + 8;
  Rule.Width := Right - Rule.Left;
end;

{ ---------------------------------------------------------------- a label in a tool bar's row }

procedure KitLayoutBarLabel(Lbl: TLabel; Bar: TToolBar; const Full, Short: string; const Hint: string);
var
  L, R, W: Integer;
  S: string;
begin
  L := Bar.Left + Bar.Width + 8;
  R := Lbl.Parent.ClientWidth - 6;
  W := R - L;
  if W < 0 then W := 0;
  Lbl.SetBounds(L, Bar.Top, W, Bar.Height);
  Lbl.Canvas.Font := Lbl.Font;
  S := Full;
  if (Lbl.Canvas.TextWidth(S) > W) and (Short <> '') then S := Short;
  if Lbl.Canvas.TextWidth(S) > W then
  begin
    while (S <> '') and (Lbl.Canvas.TextWidth(S + '...') > W) do S := DropLastChar(S);
    if S <> '' then S := S + '...';
  end;
  Lbl.Caption := S;
  if Hint <> '' then Lbl.Hint := Hint else Lbl.Hint := Full;
end;

{ ---------------------------------------------------------------- the commands' images }

{ Bars, Menus and Actions with Images (nil: Bars show captions) }
procedure SetCommandImages(Actions: TCustomActionList; const Bars: array of TToolBar;
  const Menus: array of TMenu; Images, Disabled: TCustomImageList);
var
  I: Integer;
begin
  Actions.Images := Images;
  for I := 0 to High(Bars) do
  begin
    Bars[I].Images := Images;
    Bars[I].DisabledImages := Disabled;
    if Images = nil then
    begin
      Bars[I].ShowCaptions := True;
      Bars[I].List := True;
    end;
  end;
  for I := 0 to High(Menus) do Menus[I].Images := Images;
end;

procedure KitGlyphIcons(Actions: TCustomActionList; const Bars: array of TToolBar;
  const Menus: array of TMenu; const Glyphs: array of Word; GlyphImages, GlyphDisabledImages: TCustomImageList);
begin
  if KitGlyphImages(GlyphImages, Glyphs, KitBlend(clBtnText, clBtnFace, 85)) then
  begin
    KitGlyphImages(GlyphDisabledImages, Glyphs, KitBlend(clGrayText, clBtnFace, 60));
    SetCommandImages(Actions, Bars, Menus, GlyphImages, GlyphDisabledImages);
  end
  else
    SetCommandImages(Actions, Bars, Menus, nil, nil);
end;

procedure KitBitmapIcons(Actions: TCustomActionList; const Bars: array of TToolBar;
  const Menus: array of TMenu; const ResName: string; const Cells: array of Integer;
  Images, DisabledImages: TCustomImageList);
begin
  if KitBitmapImages(Images, ResName, Cells, False) then
  begin
    KitBitmapImages(DisabledImages, ResName, Cells, True);
    SetCommandImages(Actions, Bars, Menus, Images, DisabledImages);
  end
  else
    SetCommandImages(Actions, Bars, Menus, nil, nil);
end;

procedure KitCommandIcons(Actions: TCustomActionList; const Bars: array of TToolBar;
  const Menus: array of TMenu; const IdeActions: array of string; const Glyphs: array of Word;
  GlyphImages, GlyphDisabledImages: TCustomImageList);
var
  Ide: TCustomImageList;
  Map: array of Integer;
  I: Integer;
  Name: string;
  Optional, Found: Boolean;
  A: TContainedAction;
begin
  Ide := KitIdeImages;
  Found := Ide <> nil;
  SetLength(Map, Length(IdeActions));
  for I := 0 to High(IdeActions) do
  begin
    Name := IdeActions[I];
    Optional := (Name <> '') and (Name[1] = '?');
    if Optional then Delete(Name, 1, 1);
    if Name = '' then Map[I] := -1 else Map[I] := KitIdeActionImage(Name);
    if (Map[I] < 0) and (Name <> '') and not Optional then Found := False;
  end;
  if not Found then
  begin
    KitGlyphIcons(Actions, Bars, Menus, Glyphs, GlyphImages, GlyphDisabledImages);
    Exit;
  end;
  for I := 0 to Actions.ActionCount - 1 do
  begin
    A := Actions.Actions[I];
    if (A is TCustomAction) and (TCustomAction(A).ImageIndex >= 0) and (TCustomAction(A).ImageIndex <= High(Map)) then
      TCustomAction(A).ImageIndex := Map[TCustomAction(A).ImageIndex];
  end;
  SetCommandImages(Actions, Bars, Menus, Ide, nil);
end;

{ ---------------------------------------------------------------- the view's status line }

var
  ExpertStatusMessage: UINT;

function KitViewStatus(Form: TCustomForm; const S: string): Boolean;
var
  W: WideString;
begin
  RegisteredMessage(ExpertStatusMessage, 'D7Studio.ExpertViewStatus');
  W := CodePageToWide(S, CP_ACP);
  if W = '' then
    Result := (Form.Parent <> nil) and Form.Parent.HandleAllocated and
      (SendMessage(Form.Parent.Handle, ExpertStatusMessage, 0, 0) <> 0)
  else
    Result := (Form.Parent <> nil) and Form.Parent.HandleAllocated and
      (SendMessage(Form.Parent.Handle, ExpertStatusMessage, 1, Integer(PWideChar(W))) <> 0);
end;

{ ---------------------------------------------------------------- the keyboard }

procedure KitPassKeyboard(Hidden, Shown: TWinControl);
var
  A: TWinControl;
begin
  A := Screen.ActiveControl;
  if (Hidden = nil) or (Shown = nil) or (Hidden = Shown) or (A = nil) then Exit;
  if ((A = Hidden) or Hidden.ContainsControl(A)) and Shown.CanFocus then Shown.SetFocus;
end;

{ ---------------------------------------------------------------- diff lines }

procedure KitDiffColors(Kind: Integer; out Ground, MarkColor: TColor);
begin
  case Kind of
    KitDiffRemoved:
      begin
        Ground := KitBlend(clRed, clWindow, 12);
        MarkColor := KitBlend(clRed, clWindowText, 75);
      end;
    KitDiffAdded:
      begin
        Ground := KitBlend(clGreen, clWindow, 14);
        MarkColor := KitBlend(clGreen, clWindowText, 80);
      end;
  else
    Ground := clWindow;
    MarkColor := clGrayText;
  end;
end;

procedure KitDrawDiffLine(C: TCanvas; const R: TRect; Kind: Integer; const Text: WideString;
  MarkWidth: Integer);
const
  Marks: array[KitDiffSame..KitDiffAdded] of WideChar = (' ', '-', '+');
var
  Ground, MarkColor: TColor;
  Mark: WideChar;
  RR: TRect;
begin
  KitDiffColors(Kind, Ground, MarkColor);
  C.Brush.Color := Ground;
  C.FillRect(R);
  SetBkMode(C.Handle, TRANSPARENT);
  if (Kind >= KitDiffSame) and (Kind <= KitDiffAdded) then Mark := Marks[Kind] else Mark := ' ';
  RR := R;
  RR.Right := RR.Left + MarkWidth;
  C.Font.Color := MarkColor;
  DrawTextW(C.Handle, @Mark, 1, RR, DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
  RR := R;
  Inc(RR.Left, MarkWidth);
  if Kind = KitDiffSame then C.Font.Color := clGrayText else C.Font.Color := clWindowText;
  if Text <> '' then
    DrawTextW(C.Handle, PWideChar(Text), Length(Text), RR, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
end;

{ ---------------------------------------------------------------- menus }

function KitFindMenuItem(Items: TMenuItem; const Name: string): TMenuItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Items.Count - 1 do
  begin
    if SameText(Items[I].Name, Name) then Result := Items[I]
    else Result := KitFindMenuItem(Items[I], Name);
    if Result <> nil then Exit;
  end;
end;

initialization

finalization
  { the windows of the class are gone with the package's forms }
  if MsftEdit <> 0 then FreeLibrary(MsftEdit);

{$ENDIF}
