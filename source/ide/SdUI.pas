{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdUI;

{ D7 Studio - appearance core.
  The IDE is drawn with the visual styles of Windows and nothing else:
  the parts the VCL does not draw are painted here through the theme API. Everything is
  expressed in system colours and system/dialog metrics. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ComCtrls, Menus,
  UxTheme, Themes, CommCtrl, ImgList;

type
  TUIButtonState = (bsNormal, bsHot, bsDown, bsChecked, bsDisabled);
  { where a strip of tabs lies next to its view: below it, above it, to its left, to its right }
  TUITabSide = (tsBottom, tsTop, tsLeft, tsRight);
  { glyphs of the Object Inspector's value buttons }
  TUIGlyph = (ugDropArrow,      // the open tree item's chevron (UIDrawTreeGlyph): value list button
              ugEllipsis);      // three 2 x 2 dots, 2 px apart: dialog button

var
  UIFont: TFont;          // UI text
  { The user's choice (Environment Options | Appearance, [UI] FontName / FontSize); set before
    InitAppearance. '' and 0 mean the message font of the system (Segoe UI 9). }
  UIFontOverride: string;
  UIFontSizeOverride: Integer;
  { The body of the dialogs (Environment Options | Preferences | Dialog background, [UI]
    DialogBackground): the system's window colour by default, else its button face. UIPrepareForm
    gives it to a dialog whose .dfm says Color = clWindow; the band of its buttons stays clBtnFace. }
  UIDialogColor: TColor = clWindow;

{ --- start-up ------------------------------------------------------------------------------- }

{ False when this Windows cannot draw the IDE: a version without visual styles (before Windows
  XP), or visual styles that are turned off. Reason says which; the program must not start. }
function UIThemesAvailable(var Reason: string): Boolean;
procedure InitAppearance;                   // call once, before the first window is created
{ the body of the dialogs from the value of [UI] DialogBackground: 0 the window colour, 1 the button face }
procedure UISetDialogBackground(Choice: Integer);
procedure UIApplyFont(AFont: TFont); overload;
procedure UIApplyFont(AForm: TCustomForm); overload;
{ A form from the form designer (.dfm) is laid out for the font it was designed with: Segoe
  UI 9, the UI font. UIPrepareForm gives a dialog the UI font and - when that has other metrics
  (a font the user chose, a system with another message font) - lays its controls out for it.
  A dialog whose .dfm says Position = poOwnerFormCenter is centred on the form it was opened
  from when it is first shown, on that form's monitor (TOwnerCenter); one that says
  poMainFormCenter on the main window, whatever window its command came from. Call it first
  thing in OnCreate. }
{ test support (test command writedlg): a dialog is created only to be laid out for the
  UI font and written back as its .dfm - its OnCreate stops after UIPrepareForm }
var
  UILayoutPass: Boolean = False;

procedure UIPrepareForm(AForm: TCustomForm);
{ ... for a frame (the sections of the Options dialog): the UI font and, when that has other
  metrics, a layout for it, and its menus in D7 Studio's look (a popup of the frame is not the
  dialog's) - frames have no OnCreate: their constructor calls it. Not the flicker
  measures (UIReduceFlicker): a frame made in code has no parent yet; its maker takes them once
  it has one. }
procedure UIPrepareFrame(AFrame: TCustomFrame);
{ test support: Root laid out again with the font it has for a client of Width x Height -
  the sections of the Options dialog for the size of its pages }
procedure UILayoutTo(Root: TWinControl; Width, Height: Integer);
{ a dialog's body - every control but Band, the band of its command buttons - into Host, DX, DY from its
  place: the windowed controls in their tab order (each joins the end of Host's), then the others. For a
  dialog whose body is shown as a page of another (the package editor's Add). }
procedure UIMoveBody(Dialog: TWinControl; Band: TControl; Host: TWinControl; DX, DY: Integer);
{ Double buffering for the controls under Root that flicker when they change (tab controls,
  list boxes, status bars: the VCL's buffer; tool bars: their own, UIModernToolBar - list and
  tree views have theirs from the modernized VCL, ComCtrls.DoubleBufferedViews: the VCL's
  DoubleBuffered breaks their scrolling), and horizontal tracking for the list boxes
  (UITrackListWidth). UIPrepareForm does it for a dialog; call it again for controls created
  later. }
procedure UIReduceFlicker(Root: TWinControl);
procedure UIReduceFlickerOf(C: TControl);         // ... for C and what is inside it
{ Horizontal tracking: as the
  editor's scroll width, the horizontal range of a list box grows to the widest row it has shown
  - a scroll bar only then - and starts again when the list is emptied or gets another font.
  UIReduceFlicker gives it to every list box. A row is measured as its text from the start of its
  item rectangle (+ 2, where the VCL draws it); an owner-drawn row that shows more says where it
  ends with UIListRowWidth while it is drawn. A list whose own code sets its range
  (LB_SETHORIZONTALEXTENT: an expert's list, which measures its rows itself) keeps it: the tracker
  measures that list no more. }
procedure UITrackListWidth(List: TCustomListBox);
procedure UIListRowWidth(List: TCustomListBox; Right: Integer);
{ a header control above the list (in a parent that clips it) scrolls with the list's rows }
procedure UIListHeader(List: TCustomListBox; Header: TWinControl);
{ a list that fits its rows itself (the completion list, the inspector's drop-down) or shortens
  them (the Components view): no tracking }
procedure UINoListTracking(List: TCustomListBox);
{ Padding: a tracked list box's
  rows are at least its text and UIListPadY pixels above and below it - the tracker raises the
  rows' height (WM_MEASUREITEM, LB_SETITEMHEIGHT), and draws the rows of a plain list box
  itself (it becomes lbOwnerDrawFixed: text centred, Windows' colours). An owner-drawn row
  centres its text with UIListTextTop. A list whose rows are dense on purpose (the CPU view)
  opts out with UINoListPadding. }
const
  UIListPadY = 2;
procedure UINoListPadding(List: TCustomListBox);
function UIListTextTop(DC: HDC; const R: TRect): Integer;    // the text of DC's font, centred in R
{ a row of a list box as the tracker draws a plain one - owner drawing that adds to some rows
  draws the others so: the ground and the text colour of a row (the selection's when Selected),
  and the row whole - its ground, Text 2 px in and centred in the list's font, its width
  reported (UIListRowWidth) }
procedure UIListRowColors(List: TCustomListBox; Selected: Boolean; out Back, Fore: TColor);
procedure UIDrawListRow(List: TCustomListBox; DC: HDC; const R: TRect; const Text: string; Selected: Boolean);
{ a control whose painting follows its width all along - an owner-drawn list's rows with text at the
  right, a line across, text cut with an ellipsis; a Scintilla window, whose blank margin at the right
  a wider window kept as a line through the text (one per step of a drag), a narrower one lost: painted
  again whole, without an erase, when its width changes. Without CS_HREDRAW a new size repaints only
  what it uncovers, and Windows copies the rest as it was }
procedure UIRepaintOnWidth(Control: TWinControl);
{ a flat line under a control and Padding pixels of space below the line (the tool bar), Margin
  pixels of space around its client area (above the line too) - in its
  non-client area, so its layout and automatic size stay as they are. (A tool bar's BorderWidth
  is no margin: the VCL counts it twice, TWinControl's and TToolWindow's - the buttons were cut.) }
procedure UIBottomBorder(Control: TWinControl; Padding: Integer; Margin: Integer = 0);
{ ... the line above it, Padding pixels of space above the line (a status line under a page) }
procedure UITopBorder(Control: TWinControl; Padding: Integer; Margin: Integer = 0);
{ the parts of a page of the file area, as the Diagram tab has them: the tool bar at its top - or the
  strip that holds it with what goes with it (a find
  box) - in the main window's tool-row look: its ground (UIBarColor), 2 px around what it holds,
  as high as that, a flat line between it and the page; a status line at its bottom with a flat
  line between the page and it }
procedure UIPageBar(Bar: TWinControl);
procedure UIPageStatus(Status: TWinControl);
{ what a strip holds in the middle of its height H: a tool bar by its buttons' height }
procedure UICentreChildren(Strip: TWinControl; H: Integer);
{ a combo box or an edit framed by the flat border of the views' lists (UIDrawBorder) instead of
  the theme's }
procedure UIFlatBorder(Control: TWinControl);
function UITestOrigin(var X, Y: Integer): Boolean;   // D7S_POS=x,y places windows for automated UI tests
function UITestMode: Boolean;                        // True for the cloaked test instance (D7S_POS set)
procedure UITestYieldForeground;                     // test instance: never keep the user's keyboard
{ Form.Show, but the window appears only when it is laid out at its real size and painted }
procedure UIShowPainted(Form: TCustomForm);
{ windows on the screen: R - a window's place - whole on the work
  area of the monitor nearest to it: no larger than the area (Shrink; else a larger one keeps
  its top left on it), moved inside it }
procedure UIFitWorkArea(var R: TRect; Shrink: Boolean = True);
{ pop-ups (tooltips): R moved inside the work area of the monitor that holds Anchor - the point it
  is shown for, the nearest monitor when the point is on none -, not of the one R lies on most: a
  long tip that starts near a monitor's right edge stays on that monitor; a larger one keeps its
  top left on it }
procedure UIFitWorkAreaAt(var R: TRect; const Anchor: TPoint);
{ a tooltip R that covers the line of text Line (screen coordinates; the text it is shown for stays
  in view, and the pointer resting there is not under a tip that takes the mouse - SdHints' value
  tip): below the line when it fits on the work area of the line's monitor there, else above it,
  else on the side with more room, as far from the line as the area allows - it covers the line
  then. A tip off the line stays where it is }
procedure UITipOffLine(var R: TRect; const Line: TRect);
{ the work area of the monitor nearest to window Wnd (the monitors as they are now) }
function UIWorkArea(Wnd: HWND): TRect;
{ ... of the monitor that holds point P (the nearest one when P is on none) }
function UIWorkAreaAt(const P: TPoint): TRect;
{ some monitor's work area shows enough of the top Height pixels of a window at R - its caption -
  to take it with the mouse: 32 px of them, their whole height }
function UICaptionOnScreen(const R: TRect; Height: Integer): Boolean;
{ test mode, D7S_STARTSHOT=<file.bmp>: the window as UIShowPainted painted it, captured by the
  program itself - the frame that stays on the screen while the start-up project opens (no
  capture from outside gets it: PrintWindow waits for the message loop); the start-up screen
  writes its frames to D7S_SPLASHSHOT the same way }
procedure UITestStartShot(Form: TCustomForm; const Variable: string = 'D7S_STARTSHOT');

var
  UITestErases: Integer;                { WM_ERASEBKGND messages seen in test mode }

{ test mode: background erases (e) and parent-background paints (p) per window class,
  'class=e/p;...'; Reset clears the counts }
function UITestEraseText(Reset: Boolean): string;

{ --- metrics (derived from the UI font) ------------------------------------------------- }

function DluX(X: Integer): Integer;
function UITextHeight: Integer;
function UIEditHeight: Integer;             // text height + 8
function UIPaneCaptionHeight: Integer;      // a docked view's title bar and the margin below it
{ the height of Font's text (tmHeight), measured on the screen: no window is needed for it (a
  list's rows before the list has one) }
function UIFontHeight(Font: TFont): Integer;

type
  TUINonClientFont = (ncCaption, ncSmallCaption, ncMenu, ncStatus, ncMessage);

{ a font of the system's non-client metrics (SPI_GETNONCLIENTMETRICS): of window captions, tool
  window captions, menus, status bars, message boxes - the last is the UI font's origin. False
  when the system does not say. }
function UINonClientFont(Which: TUINonClientFont; var LF: TLogFont): Boolean;

{ --- presses that the IDE's controls track themselves (the dock's captions, tabs and splitters,
  the list of the Components view) ------------------------------------------------------------
  A press becomes a drag once the pointer is more than 4 px away from where it began. It ends
  without a change when another window takes the mouse while the button is still down (letting
  go releases the capture first: that is no loss), or on Esc: the VCL hands a key to the window
  that holds the mouse first, as CN_KEYDOWN (TApplication.IsKeyMsg); answered with Result = 1,
  the key goes no further. Positions come from the mouse messages. }

function UIDragStarted(const From, P: TPoint): Boolean;
function UICaptureLost(C: TWinControl; const Message: TMessage): Boolean;     // WM_CAPTURECHANGED
function UIPressEscape(C: TWinControl; const Message: TWMKey): Boolean;       // CN_KEYDOWN
{ the whole wheel notches of a WM_MOUSEWHEEL delta, times PerNotch; the rest stays in Acc for the
  next message (a touch pad sends parts of a notch); a turn the other way drops it }
function UIWheelSteps(var Acc: Integer; WheelDelta, PerNotch: Integer): Integer;
{ the scroll bars of a control that scrolls its content itself (the hex and image views, the
  diagram, the Object Inspector). UISetScrollBar: Bar's range is the content's Size (in the bar's
  units), Page of it in view, at Pos - a bar not needed goes, or stays disabled (KeepWhenFull).
  UIScrollPos: where a WM_HSCROLL / WM_VSCROLL takes the content from Pos - a line (Line) or a
  page (Page) on, the thumb's track position (all 32 bits), the start, or Last; Pos itself for a
  code that moves nothing (SB_ENDSCROLL) }
procedure UISetScrollBar(Wnd: HWND; Bar, Size, Page, Pos: Integer; KeepWhenFull: Boolean = False);
function UIScrollPos(Wnd: HWND; Bar, Code, Pos, Line, Page, Last: Integer): Integer;
{ UIScrollPos for a view that scrolls by its Origin in pixels and clamps the end itself (the
  diagram, the designer's zoom): the origin after a WM_HSCROLL / WM_VSCROLL of Bar; a line Line
  pixels, a page the view less a line }
function UIScrollOrigin(Control: TWinControl; Bar, Code: Integer; const Origin: TPoint; Line: Integer): TPoint;
{ both in one piece: OnCancel(Control) is called when Control loses the mouse while the button is
  down, or gets Esc while it holds the mouse (the key goes no further). A hook of the control's
  window procedure (TUIWindowHook), one per control; the control's own handlers of the two
  messages run first. }
procedure UIOnPressCancel(Control: TWinControl; OnCancel: TNotifyEvent);

{ --- window procedure hooks -------------------------------------------------------------------
  A hook is owned by its control: it takes the control's window procedure (Active) and gives it
  back when it goes - with the control, or freed before. Hook handles a message and passes it on
  through FOldProc. The appearance's own are hooks (list tracking, flat borders, the look of menus
  and tool bars, UIOnPressCancel); a unit that needs the messages of a control it does not own
  derives one instead of replacing WindowProc itself (the editor's scroll bars, the column tree's
  rows). }
type
  TUIWindowHook = class(TComponent)
  protected
    FControl: TWinControl;
    FOldProc: TWndMethod;  // nil: not hooked
    procedure Hook(var Message: TMessage); virtual; abstract;
  public
    constructor Create(AControl: TWinControl; Active: Boolean); reintroduce;
    destructor Destroy; override;
    property Control: TWinControl read FControl;
  end;
  TUIWindowHookClass = class of TUIWindowHook;

{ Control's hook of the class AClass (or of one derived from it); nil when it has none }
function UIFindHook(Control: TWinControl; AClass: TUIWindowHookClass): TUIWindowHook;

{ --- base classes of D7 Studio's own controls ---------------------------------------------------
  TSdControl: a control that paints itself. Windows never erases it: Paint and
  the children cover the client - what lies under children that do not is EraseGround's. Without
  CS_HREDRAW / CS_VREDRAW a new size repaints only what it uncovers; RedrawWhole keeps them for a
  control whose whole drawing follows its size. Buffered: Paint draws through a bitmap of the
  control's size (PaintBuffer) and copies the region to paint in one piece. Buffered and
  RedrawWhole are set in the constructor, before the window is made. }
type
  TSdControl = class(TCustomControl)
  private
    FBuffer: TBitmap;
    FBuffered: Boolean;
    FRedrawWhole: Boolean;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Paint; override;
    procedure EraseGround(DC: HDC); virtual;         // the erase: nothing
    procedure PaintBuffer(C: TCanvas); virtual;      // Buffered: the drawing, on the buffer's canvas
    property Buffered: Boolean read FBuffered write FBuffered;
    property RedrawWhole: Boolean read FRedrawWhole write FRedrawWhole;
  public
    destructor Destroy; override;
  end;

  { a TSdControl that scrolls its content itself by a pixel origin (the designer's zoom, the
    diagram): the scroll bars show ContentSize in the client and the origin stays inside it; a line
    of the bars is LineSize pixels, a page the client less a line (UIScrollOrigin) }
  TSdScrollControl = class(TSdControl)
  private
    FBarsBusy: Boolean;      // UpdateScrollBars runs (a bar that comes or goes resizes the client)
    procedure WMHScroll(var Message: TWMHScroll); message WM_HSCROLL;
    procedure WMVScroll(var Message: TWMVScroll); message WM_VSCROLL;
  protected
    FOrigin: TPoint;         // the content's point at the client's top left: the scroll positions
    function ContentSize: TPoint; virtual; abstract;
    function LineSize: Integer; virtual; abstract;
    { the bars set to ContentSize and the client, the origin kept inside them }
    procedure UpdateScrollBars;
    { the origin moved to (X, Y): the bars set, the client painted again }
    procedure ScrollTo(X, Y: Integer);
  end;

  { a list that pops up over every window without taking the activation from the one it serves
    (the editor's completion list, the Object Inspector's drop-down): a bordered, topmost tool
    window on the desktop once made (its VCL parent only creates it), CS_SAVEBITS, no
    CS_HREDRAW / CS_VREDRAW; its selection drawn as focused; outside the list tracking - it is as
    wide as its entries }
  TSdPopupList = class(TCustomListBox)
  private
    procedure WMMouseActivate(var Message: TWMMouseActivate); message WM_MOUSEACTIVATE;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ShowAt(X, Y, W, H: Integer);           // there, topmost, not activated
    procedure HideList;
  end;

{ several controls of one parent to new bounds in one DeferWindowPos batch: they repaint once,
  together, and the background never shows between them (flicker) }
procedure UIMoveControls(const Controls: array of TWinControl; const Bounds: array of TRect);
{ Control and its children paint what they have to now, not when the message queue is empty (a
  shown window only): after each step of a drag that lays them out again (a splitter) - the next
  step comes sooner than the paint, and a window moved again with its paint pending cannot have its
  pixels copied: Windows repaints all of it and its children (the form being designed flickered on
  every step), or what the move copied stays on the screen until the drag stops (the History tab's
  editors) }
procedure UIPaintNow(Control: TWinControl);
{ a container and its shown windowed children draw nothing while they change (Freeze True), then
  are drawn once, frame and children too (Freeze False): a tool bar repaints whole for every
  button it gets or loses (the VCL makes all of them again). PaintNow False: drawn at the next
  paint, not at once (the centre's pages: several may be swapped before one is shown) }
procedure UIFreezeRedraw(Container: TWinControl; Freeze: Boolean; PaintNow: Boolean = True);
{ windows of a container replaced by others (the centre's pages): between
  UIBeginSwap and UIEndSwap nothing of the container reaches the screen, the old windows stay
  there whole; after the command the container is drawn, children and all, in one piece (through
  one buffer). Shown window by window, the parts of a new page not drawn yet showed the old page
  for up to 35 ms (the design view: the stage, then the form, then each control) }
procedure UIBeginSwap(Container: TWinControl);
procedure UIEndSwap(Container: TWinControl);
{ a container that shows none of its children (the centre without files) is drawn as an empty
  view: its colour, the views' flat border and the icon IconName of the program in the middle,
  Size px (halved while the container is too small for it), in one paint through a buffer }
procedure UIEmptyView(Container: TWinControl; const IconName: string; Size: Integer);
{ the same with a picture in place of the icon: PictureName, a PNG among the program's RCDATA
  resources, is ink - each pixel's alpha its strength -, drawn in black on a light ground and in
  white on a dark one, at Opacity per cent: a watermark. It is Height px high at 96 DPI (scaled
  with the container's DPI) and at most 70 per cent of the container's height and width - smaller
  with the container -, and not drawn below 100 px (96 DPI) }
procedure UIEmptyPicture(Container: TWinControl; const PictureName: string; Height, Opacity: Integer);
{ the same with a picture in its colours - a photograph, a painting -: PictureName, one among the
  program's RCDATA resources in any format GDI+ reads, over the whole container, without the border
  - as large as that needs, what overflows cut equally at two opposite sides }
procedure UIEmptyPhoto(Container: TWinControl; const PictureName: string);
{ the theme's tool bar separator, centred in R (as a TToolButton separator is drawn) }
procedure UIDrawToolSeparator(DC: HDC; const R: TRect);

{ --- drawing primitives --------------------------------------------------------------------- }

procedure UIFill(DC: HDC; const R: TRect; Color: TColor);
procedure UIFrame(DC: HDC; const R: TRect; Color: TColor);           // a 1 px frame
procedure UIHLine(DC: HDC; X1, X2, Y: Integer; Color: TColor);
procedure UIVLine(DC: HDC; X, Y1, Y2: Integer; Color: TColor);
{ dotted lines, every other pixel from X1 to X2 (from Y1 to Y2), the end excluded: on the even
  coordinates - the dots of neighbouring lines line up wherever they start -, or (FromStart) from
  the line's first pixel on }
procedure UIDottedHLine(DC: HDC; X1, X2, Y: Integer; Color: TColor; FromStart: Boolean = False);
procedure UIDottedVLine(DC: HDC; X, Y1, Y2: Integer; Color: TColor; FromStart: Boolean = False);
procedure UIText(DC: HDC; const S: string; var R: TRect; Flags: Cardinal; Color: TColor);
procedure UITextW(DC: HDC; const W: WideString; var R: TRect; Flags: Cardinal; Color: TColor);
function UITextWidth(DC: HDC; const S: string): Integer;
{ painting through a kept bitmap (no flicker): a control that fills and then draws
  on the screen shows the bare fill for a moment whenever it paints - a resize repaints it whole.
  UIBufferDC gives the DC of Buffer, made and sized to Control when needed (the control keeps it
  and frees it); the control paints there, and UIBufferFlush copies Canvas's clip rectangle to the
  screen in one piece. }
function UIBufferDC(var Buffer: TBitmap; Control: TControl): HDC;
procedure UIBufferFlush(Buffer: TBitmap; Canvas: TCanvas);
{ a 32-bit DIB section, top-down (the first row first), Width x Height; Bits: its pixels row after
  row, a Cardinal $AARRGGBB each. 0 (Bits nil) when it cannot be made; the caller deletes it }
function UICreateDib32(Width, Height: Integer; out Bits: PCardinal): HBITMAP;

{ the docked views' captions and the tabs }
{ the colours of a docked view's caption: Active (the keyboard is in its group) those of
  Windows' title bars, else a quiet grey bar with the face's text }
procedure UITitleColors(out Back, Fore: TColor; Active: Boolean = True);
{ a caption in R: the bar with the title, the pin (Pinned: the group is docked; else it hides at
  the edge) and the close box }
procedure UIDrawPaneCaption(DC: HDC; const R: TRect; const Text: string; Pinned: Boolean;
  PinState, CloseState: TUIButtonState; Active: Boolean; ShowPin: Boolean = True);   // no pin: a floating group
function UIPaneCaptionButton(const R: TRect; Index: Integer): TRect;   // 0 the pin, 1 the close box
procedure UIDrawCloseBox(DC: HDC; const R: TRect; State: TUIButtonState; Solid: Boolean);
function UIBlend(A, B: TColor; Percent: Integer): TColor;           // Percent of A
{ a colour's brightness, 0 .. 255: its luminance (299 R + 587 G + 114 B) div 1000 }
function UILuma(Color: TColor): Integer;
{ a dark colour - white text on it: its luminance below 128 }
function UIIsDark(Color: TColor): Boolean;
{ a tint of the selection colour on Back: the inspector's selected row, a list's selection while
  the list has not the focus }
function UISelectionTint(Back: TColor): TColor;
procedure UIDrawTab(DC: HDC; const R: TRect; const Text: WideString; State: TUIButtonState;
  Side: TUITabSide; CloseBox: Boolean = False; CloseState: TUIButtonState = bsNormal;
  Images: TCustomImageList = nil; ImageIndex: Integer = -1; TextColor: TColor = clNone);
const
  { the title of a tab that tells of something wrong (the Error List while there are errors):
    Windows' error red, readable on the chosen tab's window colour and on the others' face colour }
  UIErrorTabText = TColor($003834D1);
{ what a tab is longer for an icon of Images before its title (0: none) }
function UITabImageRoom(Images: TCustomImageList; ImageIndex: Integer): Integer;
function UITabCloseRect(const R: TRect): TRect;   // the close box of a file tab in R
function UITabCloseRoom: Integer;                   // what a tab is longer for its close box
function UIDockTabHeight: Integer;
procedure UIDrawComponentTile(DC: HDC; const R: TRect; Bmp: TBitmap);              // 28 x 28, Delphi 7's
procedure UIDrawExpandBox(DC: HDC; X, Y: Integer; Expanded: Boolean; Size: Integer = 9);   // Size x Size at X, Y (odd)
{ the visual style's glyph of a tree item - Explorer's trees: a chevron - in R, open or closed, as
  the trees draw it under the pointer (Hot); without the style the expand box. Its side: the
  style's, at least the expand box's 9 px. The theme is opened when first drawn and again after
  UICloseTreeTheme (a theme change). }
procedure UIDrawTreeGlyph(DC: HDC; const R: TRect; Opened: Boolean; Hot: Boolean = False);
function UITreeGlyphSize(DC: HDC): Integer;
procedure UICloseTreeTheme;
function UICheckBoxSize: Integer;          // the visual style's check box (13 at 96 DPI)
procedure UIDrawGlyphButton(DC: HDC; const R: TRect; Glyph: TUIGlyph; State: TUIButtonState);
procedure UIDrawBorder(DC: HDC; const R: TRect);           // the flat 1 px border of the views' lists
procedure UIPaintFrameBorder(Wnd: HWND);                   // ... as the frame of a WS_BORDER window (WM_NCPAINT)
{ a tool button's highlight: a square box in a soft tint of the accent colour with a darker
  edge (bsHot), a stronger tint for bsDown and bsChecked; nothing for the other states }
procedure UIDrawFlatButton(DC: HDC; const R: TRect; State: TUIButtonState; Ground: TColor = clBtnFace);
procedure UIDrawGripper(DC: HDC; const R: TRect);                                 // single raised bar
{ the ground of the menu bar and of the tool row under it, one colour for both: a system colour,
  white }
function UIBarColor: TColor;

{ --- menus and tool bars in D7 Studio's flat style --------------------------------------------
  TMainMenu, TPopupMenu and TToolBar in a modern look: menus with a light ground, an icon
  column, an accent box and separators of their own; tool
  bars with the same box, square. UIModernMenus draws every item
  of Form's menu bar and of every popup menu of the program (the VCL shows them all through its
  PopupList); UIOwnerDrawMenus makes the menus of a form drawn so (UIPrepareForm does it for a
  dialog); UIReduceFlicker gives every tool bar UIModernToolBar. UIMenuTextW: the text of an
  item whose caption cannot hold it (a Reopen entry outside the code page), '' for its caption. }
procedure UIModernMenus(Form: TCustomForm);
procedure UIOwnerDrawMenus(Owner: TComponent);
procedure UIModernToolBar(Bar: TToolBar);
{ The tool bar of a view of the dock (TSdDockPanel.ToolBar gives it): captioned flat buttons in one
  row, the hints shown, as high as its buttons and two pixels more - on a ground of its own (the
  view's colour, painted in the bar's buffer: no parent has to paint under it) }
procedure UIViewToolBar(Bar: TToolBar);
{ The images of Images for disabled commands: Disabled, a list with the same indexes (greyed as
  Visual Studio greys its images) - the menus draw a disabled item's image from it,
  the tool bars that show Images get it as their disabled image list. 0: the menus grey Images'
  image (ILS_SATURATE) and the tool bars grey it themselves. }
procedure UIDisabledImages(Images: TCustomImageList; Disabled: HIMAGELIST);
{ a pixel of a disabled image as Visual Studio greys it (P and the result $AARRGGBB, straight
  alpha): the disabled image lists (SdIcons.DisabledIcons) and a disabled tool button's drop-down
  arrow }
function UIGreyPixel(P: Cardinal): Cardinal;

{ --- a tree's place across a refill ------------------------------------------------------------
  Expanding a node scrolls a tree view to show its children: a tree filled again and opened
  ends at the last folder it opened (the bottom). UISaveTreePlace takes the first row in view
  and the selection (as paths of captions) before the refill, UIRestoreTreePlace finds them
  again after it (else their nearest parent that is still there; the selection only when it is
  in an open branch) and shows that row first - an empty place (Default) shows the tree's top. }
type
  TUITreePlace = record
    TopPath, SelPath: string;
  end;

function UISaveTreePlace(Tree: TTreeView): TUITreePlace;
procedure UIRestoreTreePlace(Tree: TTreeView; const Place: TUITreePlace);
{ A tree whose double click opens or closes no node - its boxes and its keys still do: the Code
  Explorer's, the Project Manager's (Delphi's act on the node). A hook of the tree (TUIWindowHook)
  keeps the tree from toggling the node it double-clicks; the tree's OnDblClick asks
  UITreeDblClickNode for the node the double click hit (by its message's point; nil: none, or the
  node's box) }
procedure UITreeNoDblClickToggle(Tree: TCustomTreeView);
function UITreeDblClickNode(Tree: TCustomTreeView): TTreeNode;
{ a report list's header shows the column it is sorted by (-1 none) with the theme's arrow, up for
  Ascending; only the columns that change repaint }
procedure UIListSortArrow(List: TCustomListView; Column: Integer; Ascending: Boolean);
{ a view that shows Shown in place of Hidden keeps the keyboard: when it is in Hidden (or in one
  of its children) it goes to Shown, which is visible already - once Hidden is hidden, the VCL
  would give it to the form (and an auto-hidden dock group that is out would go in) }
procedure UIPassKeyboard(Hidden, Shown: TWinControl);

{ --- the clipboard ------------------------------------------------------------------------------
  UIOpenClipboard: OpenClipboard for Wnd, tried again for a moment while another program holds
  the clipboard (10 more tries, 10 ms apart). While it is open (and emptied by the caller):
  UIClipboardSet puts Size bytes at Data on it in Format (False: no memory, or Windows refused it);
  UIClipboardGet takes the block of Format (False: none) - all the memory Windows keeps for it
  (GlobalSize: a text ends at its first zero character). CloseClipboard is the caller's. }
function UIOpenClipboard(Wnd: HWND): Boolean;
function UIClipboardSet(Format: UINT; Data: Pointer; Size: Integer): Boolean;
function UIClipboardGet(Format: UINT; out Data: string): Boolean;

var
  UIMenuTextW: function(Item: TMenuItem): WideString = nil;

implementation

uses
  MultiMon, ExtCtrls, CheckLst, SdEncoding, SdResImage;

procedure InstallTestGuard; forward;

var
  BaseX, BaseY, TextH: Integer;
  MetricsValid: Boolean;

function UINonClientFont(Which: TUINonClientFont; var LF: TLogFont): Boolean;
type
  { NONCLIENTMETRICS as it was before Vista (the size dcc32's Windows.pas knows) }
  TNCM = record
    cbSize: UINT;
    iBorderWidth: Integer;
    iScrollWidth: Integer;
    iScrollHeight: Integer;
    iCaptionWidth: Integer;
    iCaptionHeight: Integer;
    lfCaptionFont: TLogFont;
    iSmCaptionWidth: Integer;
    iSmCaptionHeight: Integer;
    lfSmCaptionFont: TLogFont;
    iMenuWidth: Integer;
    iMenuHeight: Integer;
    lfMenuFont: TLogFont;
    lfStatusFont: TLogFont;
    lfMessageFont: TLogFont;
  end;
var
  NCM: TNCM;
begin
  FillChar(NCM, SizeOf(NCM), 0);
  NCM.cbSize := SizeOf(NCM);
  Result := SystemParametersInfo(SPI_GETNONCLIENTMETRICS, SizeOf(NCM), @NCM, 0);
  if Result then
    case Which of
      ncCaption: LF := NCM.lfCaptionFont;
      ncSmallCaption: LF := NCM.lfSmCaptionFont;
      ncMenu: LF := NCM.lfMenuFont;
      ncStatus: LF := NCM.lfStatusFont;
    else
      LF := NCM.lfMessageFont;
    end;
end;

procedure SetupFonts;
var
  LF: TLogFont;
begin
  if UIFont = nil then UIFont := TFont.Create;
  if UINonClientFont(ncMessage, LF) then
  begin
    UIFont.Name := LF.lfFaceName;
    UIFont.Height := LF.lfHeight;
  end
  else
  begin
    UIFont.Name := 'Segoe UI';
    UIFont.Size := 9;
  end;
  UIFont.Charset := DEFAULT_CHARSET;
  if UIFontOverride <> '' then UIFont.Name := UIFontOverride;
  if UIFontSizeOverride > 0 then UIFont.Size := UIFontSizeOverride;
  UIFont.Color := clWindowText;
  UIFont.Style := [];
  MetricsValid := False;
end;

function UIThemesAvailable(var Reason: string): Boolean;
begin
  Result := False;
  InitThemeLibrary;
  if (Win32Platform <> VER_PLATFORM_WIN32_NT) or (Win32MajorVersion < 5) or
    (Win32MajorVersion = 5) and (Win32MinorVersion < 1) then
    Reason := 'This version of Windows has no visual styles. D7 Studio needs Windows XP or later.'
  else if not ThemeServices.ThemesAvailable then
    Reason := 'The visual styles of Windows are not available to this program.'
  else if not ThemeServices.ThemesEnabled then
    Reason := 'The visual styles of Windows are turned off: the "Windows Classic" theme is in use, ' +
      'or visual styles are disabled for this program in its compatibility settings.'
  else
    Result := True;
end;

procedure InitAppearance;
begin
  InitThemeLibrary;
  SetupFonts;
  InstallTestGuard;
end;

{ --- automated UI tests ----------------------------------------------------------------------

  With D7S_POS set, every top-level window of the process is DWM-cloaked before it is shown:
  the windows sit on a real monitor and paint exactly as usual (a window outside the desktop
  never receives a non-empty paint region), yet they are neither displayed nor hit by the
  mouse. PrintWindow reads their content.

  A cloaked window can still become the foreground window - Windows lets a program that was
  just started take that place - and the user would then type into a window nobody can see.
  The test instance therefore hands the foreground back to the window the user was working in
  as soon as it gets it, and discards keyboard and mouse input that arrives meanwhile (the
  messages the test scripts post arrive while it is in the background). }

const
  CloakProp = 'D7SCloaked';
  DWMWA_CLOAK = 13;

var
  TestHook, TestMsgHook: HHOOK;
  TestUserWindow: HWND;         // the foreground window of another program, as last seen
  TestFgLocked: Boolean;        // foreground changes are locked while the instance starts
  DwmSetAttr: function(Wnd: HWND; Attr: DWORD; Value: Pointer; Size: DWORD): HRESULT; stdcall;

const
  LSFW_LOCK = 1;
  LSFW_UNLOCK = 2;

function LockSetForegroundWindow(LockCode: UINT): BOOL; stdcall; external user32 name 'LockSetForegroundWindow';


function OwnWindow(Wnd: HWND): Boolean;
var
  Pid: DWORD;
begin
  Pid := 0;
  Result := (Wnd <> 0) and (GetWindowThreadProcessId(Wnd, @Pid) <> 0) and (Pid = GetCurrentProcessId);
end;

procedure ReleaseForeground;
var
  W: HWND;
begin
  if not OwnWindow(GetForegroundWindow) then Exit;
  W := TestUserWindow;
  if not IsWindow(W) or not IsWindowVisible(W) or OwnWindow(W) then
  begin
    { the topmost visible window of another program }
    W := GetTopWindow(0);
    while (W <> 0) and (not IsWindowVisible(W) or OwnWindow(W) or (GetWindowTextLength(W) = 0)) do
      W := GetWindow(W, GW_HWNDNEXT);
  end;
  if W <> 0 then SetForegroundWindow(W);
end;

function TestMsgProc(Code: Integer; W: WPARAM; L: LPARAM): LRESULT; stdcall;
var
  M: PMsg;
  Fg: HWND;
begin
  if (Code = HC_ACTION) and (W = PM_REMOVE) then
  begin
    M := PMsg(L);
    if TestFgLocked then
    begin
      { the message loop runs: the windows of the start-up are on the screen }
      TestFgLocked := False;
      LockSetForegroundWindow(LSFW_UNLOCK);
    end;
    Fg := GetForegroundWindow;
    if OwnWindow(Fg) then
    begin
      { real input: it was meant for the window the user was working in }
      if (M^.message >= WM_KEYFIRST) and (M^.message <= WM_KEYLAST) or
        (M^.message >= WM_MOUSEFIRST) and (M^.message <= WM_MOUSELAST) then
        M^.message := WM_NULL;
      ReleaseForeground;
    end
    else if Fg <> 0 then
      TestUserWindow := Fg;
  end;
  Result := CallNextHookEx(TestMsgHook, Code, W, L);
end;

var
  EraseCounts: TStringList;      // class name -> erases (low word) and parent paints (high word)

procedure CountErase(const Cls: string; ParentPaint: Boolean);
var
  I, N: Integer;
begin
  if EraseCounts = nil then EraseCounts := TStringList.Create;
  I := EraseCounts.IndexOf(Cls);
  if I < 0 then I := EraseCounts.AddObject(Cls, nil);
  N := Integer(EraseCounts.Objects[I]);
  if ParentPaint then Inc(N, $10000) else Inc(N);
  EraseCounts.Objects[I] := TObject(N);
end;

function UITestEraseText(Reset: Boolean): string;
var
  I, N: Integer;
begin
  Result := '';
  if EraseCounts = nil then Exit;
  for I := 0 to EraseCounts.Count - 1 do
  begin
    N := Integer(EraseCounts.Objects[I]);
    Result := Result + Format('%s=%d/%d;', [EraseCounts[I], N and $FFFF, N shr 16]);
  end;
  if Reset then EraseCounts.Clear;
end;

function TestHookProc(Code: Integer; W: WPARAM; L: LPARAM): LRESULT; stdcall;
var
  Wnd: HWND;
  One: BOOL;
  Cls: array[0..31] of Char;
begin
  if Code = HC_ACTION then
  begin
    Wnd := PCWPStruct(L)^.hwnd;
    case PCWPStruct(L)^.message of
      WM_NCCREATE, WM_CREATE, WM_SHOWWINDOW, WM_WINDOWPOSCHANGING, WM_NCACTIVATE, WM_NCPAINT,
      WM_INITDIALOG, WM_INITMENUPOPUP:
        if (GetProp(Wnd, CloakProp) = 0) and (GetAncestor(Wnd, GA_PARENT) = GetDesktopWindow) then
        begin
          One := True;
          if DwmSetAttr(Wnd, DWMWA_CLOAK, @One, SizeOf(One)) = S_OK then SetProp(Wnd, CloakProp, 1);
        end;
      WM_NCDESTROY:
        RemoveProp(Wnd, CloakProp);
      WM_ACTIVATEAPP:
        { the application is being activated: have the message hook look at the foreground
          window right after this }
        if PCWPStruct(L)^.wParam <> 0 then PostThreadMessage(GetCurrentThreadId, WM_NULL, 0, 0);
      WM_ERASEBKGND, WM_PRINTCLIENT:
        begin
          { repaint statistics: lets a test see whether an idle window keeps redrawing and
            which windows repaint when something small changes (flicker) }
          Cls[0] := #0;
          GetClassName(Wnd, Cls, SizeOf(Cls));
          CountErase(Cls, PCWPStruct(L)^.message = WM_PRINTCLIENT);
          if PCWPStruct(L)^.message = WM_ERASEBKGND then Inc(UITestErases);
        end;
    end;
  end;
  Result := CallNextHookEx(TestHook, Code, W, L);
end;

{ DwmSetWindowAttribute, loaded once (nil without DWM) }
function DwmAvailable: Boolean;
var
  Dwm: HMODULE;
begin
  if not Assigned(DwmSetAttr) then
  begin
    Dwm := LoadLibrary('dwmapi.dll');
    if Dwm <> 0 then @DwmSetAttr := GetProcAddress(Dwm, 'DwmSetWindowAttribute');
  end;
  Result := Assigned(DwmSetAttr);
end;

procedure InstallTestGuard;
var
  X, Y: Integer;
begin
  if (TestHook <> 0) or not UITestOrigin(X, Y) then Exit;
  { never show an uncloaked test window on the user's desktop }
  if not DwmAvailable then ExitProcess(3);
  TestUserWindow := GetForegroundWindow;
  { A program that was just started may take the foreground with its first window. While that
    right is ours, lock foreground changes until the message loop runs: the main window then
    appears without taking the keyboard from the user. (The lock ends by itself with the
    user's next click on another window.) }
  TestFgLocked := LockSetForegroundWindow(LSFW_LOCK);
  TestHook := SetWindowsHookEx(WH_CALLWNDPROC, @TestHookProc, 0, GetCurrentThreadId);
  { never keep the keyboard either }
  TestMsgHook := SetWindowsHookEx(WH_GETMESSAGE, @TestMsgProc, 0, GetCurrentThreadId);
  { no task bar button either }
  ShowWindow(Application.Handle, SW_HIDE);
  SetWindowLong(Application.Handle, GWL_EXSTYLE,
    GetWindowLong(Application.Handle, GWL_EXSTYLE) or WS_EX_TOOLWINDOW);
  ShowWindow(Application.Handle, SW_SHOWNOACTIVATE);
end;

procedure UIApplyFont(AFont: TFont);
begin
  if UIFont = nil then SetupFonts;
  AFont.Name := UIFont.Name;
  AFont.Height := UIFont.Height;
  AFont.Charset := UIFont.Charset;
end;

procedure UIApplyFont(AForm: TCustomForm);
begin
  UIApplyFont(TForm(AForm).Font);
end;

function UITestMode: Boolean;
begin
  Result := TestHook <> 0;
end;

procedure UITestYieldForeground;
begin
  if TestHook <> 0 then ReleaseForeground;
end;

{ Windows shows a window and erases it and its children before the VCL gets its WM_SIZE: a form
  shown maximized from a smaller size was painted with the layout of that size, its dock
  captions in the middle of the window for a split second at start. DWM keeps the window
  cloaked meanwhile; the test
  instance stays cloaked anyway. }
procedure UIShowPainted(Form: TCustomForm);
var
  Cloak: BOOL;
  Cloaked: Boolean;
begin
  Form.HandleNeeded;
  Cloak := True;
  Cloaked := not UITestMode and DwmAvailable and
    (DwmSetAttr(Form.Handle, DWMWA_CLOAK, @Cloak, SizeOf(Cloak)) = S_OK);
  Form.Show;
  RedrawWindow(Form.Handle, nil, 0, RDW_UPDATENOW or RDW_ALLCHILDREN);
  if Cloaked then
  begin
    Cloak := False;
    DwmSetAttr(Form.Handle, DWMWA_CLOAK, @Cloak, SizeOf(Cloak));
  end;
end;

procedure UITestStartShot(Form: TCustomForm; const Variable: string);
var
  FileName: string;
  R: TRect;
  Bmp: TBitmap;
  DC: HDC;
begin
  FileName := GetEnvironmentVariable(Variable);
  if not UITestMode or (FileName = '') then Exit;
  GetWindowRect(Form.Handle, R);
  Bmp := TBitmap.Create;
  DC := GetWindowDC(Form.Handle);    // what the window painted (its DWM surface; also cloaked)
  try
    Bmp.PixelFormat := pf24bit;
    Bmp.Width := R.Right - R.Left;
    Bmp.Height := R.Bottom - R.Top;
    BitBlt(Bmp.Canvas.Handle, 0, 0, Bmp.Width, Bmp.Height, DC, 0, 0, SRCCOPY);
    Bmp.SaveToFile(FileName);
  finally
    ReleaseDC(Form.Handle, DC);
    Bmp.Free;
  end;
end;

function UITestOrigin(var X, Y: Integer): Boolean;
var
  S: string;
  P: Integer;
begin
  Result := False;
  S := GetEnvironmentVariable('D7S_POS');
  P := Pos(',', S);
  if P = 0 then Exit;
  X := StrToIntDef(Trim(Copy(S, 1, P - 1)), 0);
  Y := StrToIntDef(Trim(Copy(S, P + 1, MaxInt)), 0);
  Result := True;
end;

{ --- metrics --- }

{ the dialog base units of a font: average character width and height (4 x 8 dialog units) }
procedure MeasureFont(Font: HFONT; var BX, BY: Integer);
const
  Sample = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
var
  DC: HDC;
  Old: HFONT;
  Sz: TSize;
  TM: TTextMetric;
begin
  DC := GetDC(0);
  Old := SelectObject(DC, Font);
  GetTextMetrics(DC, TM);
  GetTextExtentPoint32(DC, Sample, 52, Sz);
  SelectObject(DC, Old);
  ReleaseDC(0, DC);
  BX := (Sz.cx div 26 + 1) div 2;
  BY := TM.tmHeight;
end;

procedure NeedMetrics;
begin
  if MetricsValid then Exit;
  if UIFont = nil then SetupFonts;
  MeasureFont(UIFont.Handle, BaseX, BaseY);
  TextH := BaseY;
  MetricsValid := True;
end;

function DluX(X: Integer): Integer;
begin
  NeedMetrics;
  Result := MulDiv(X, BaseX, 4);
end;

function UITextHeight: Integer;
begin
  NeedMetrics;
  Result := TextH;
end;

function UIEditHeight: Integer;
begin
  Result := UITextHeight + 8;
end;

function UIFontHeight(Font: TFont): Integer;
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
  finally
    ReleaseDC(0, DC);
  end;
  Result := TM.tmHeight;
end;

{ --- presses tracked by the controls themselves --- }

const
  DragThreshold = 4;      // pixels before a press becomes a drag

function UIDragStarted(const From, P: TPoint): Boolean;
begin
  Result := (Abs(P.X - From.X) > DragThreshold) or (Abs(P.Y - From.Y) > DragThreshold);
end;

function UICaptureLost(C: TWinControl; const Message: TMessage): Boolean;
begin
  Result := (GetKeyState(VK_LBUTTON) < 0) and (HWND(Message.LParam) <> C.Handle);
end;

function UIPressEscape(C: TWinControl; const Message: TWMKey): Boolean;
begin
  Result := (Message.CharCode = VK_ESCAPE) and C.HandleAllocated and (GetCapture = C.Handle);
end;

function UIWheelSteps(var Acc: Integer; WheelDelta, PerNotch: Integer): Integer;
begin
  if (Acc <> 0) and ((Acc > 0) <> (WheelDelta > 0)) then Acc := 0;
  Inc(Acc, WheelDelta * PerNotch);
  Result := Acc div WHEEL_DELTA;
  Dec(Acc, Result * WHEEL_DELTA);
end;

procedure UISetScrollBar(Wnd: HWND; Bar, Size, Page, Pos: Integer; KeepWhenFull: Boolean);
var
  SI: TScrollInfo;
begin
  FillChar(SI, SizeOf(SI), 0);
  SI.cbSize := SizeOf(SI);
  SI.fMask := SIF_RANGE or SIF_PAGE or SIF_POS;
  if KeepWhenFull then SI.fMask := SI.fMask or SIF_DISABLENOSCROLL;
  if Size > 1 then SI.nMax := Size - 1;
  if Page > 0 then SI.nPage := Page;
  SI.nPos := Pos;
  SetScrollInfo(Wnd, Bar, SI, True);
end;

function UIScrollPos(Wnd: HWND; Bar, Code, Pos, Line, Page, Last: Integer): Integer;
var
  SI: TScrollInfo;
begin
  Result := Pos;
  case Code of
    SB_LINEUP: Dec(Result, Line);
    SB_LINEDOWN: Inc(Result, Line);
    SB_PAGEUP: Dec(Result, Page);
    SB_PAGEDOWN: Inc(Result, Page);
    SB_THUMBTRACK, SB_THUMBPOSITION:
      begin
        FillChar(SI, SizeOf(SI), 0);
        SI.cbSize := SizeOf(SI);
        SI.fMask := SIF_TRACKPOS;
        if GetScrollInfo(Wnd, Bar, SI) then Result := SI.nTrackPos;
      end;
    SB_TOP: Result := 0;
    SB_BOTTOM: Result := Last;
  end;
end;

function UIScrollOrigin(Control: TWinControl; Bar, Code: Integer; const Origin: TPoint; Line: Integer): TPoint;
var
  Page: Integer;
begin
  Result := Origin;
  if Bar = SB_HORZ then Page := Control.ClientWidth else Page := Control.ClientHeight;
  Dec(Page, Line);
  if Page < Line then Page := Line;
  if Bar = SB_HORZ then
    Result.X := UIScrollPos(Control.Handle, Bar, Code, Origin.X, Line, Page, MaxInt div 2)
  else
    Result.Y := UIScrollPos(Control.Handle, Bar, Code, Origin.Y, Line, Page, MaxInt div 2);
end;

{ --- forms from the form designer ------------------------------------------------------------

  A .dfm holds pixel positions for the font the form was designed with (MS Sans Serif 8: base
  units 6 x 13). For a UI font with other metrics the controls are laid out again here. The
  VCL's own ScaleBy uses one factor for both directions and scales every edge, which leaves
  controls of one kind with different sizes and rows with different gaps; this keeps a dialog
  as regular as it was drawn. Sizes and gaps are what is scaled - never positions:

  Vertically a dialog flows from the top.
  * A control one text line high (edit, combo box, check box, label, a status cell) grows by
    the difference of the text heights: its height is "text + padding", not dialog units.
    Inside such a control nothing moves. Buttons keep their height in dialog units, other
    controls are scaled, pictures and thin lines stay as they are.
  * Every control hangs below its nearest neighbour above with the scaled gap; a control with
    nothing above it keeps its scaled distance from the top.
  * A group box or panel is as high as its content needs (plus its scaled bottom padding);
    boxes side by side stay equally high. The form is as high as its content needs.
  * A tab sheet has the size the page control gives it: there a control anchored to the
    bottom (Anchors) follows the bottom edge or - anchored to top and bottom - is stretched.
  * A label stays on the text line of its FocusControl.

  Horizontally the form is scaled and
  * an edge keeps its scaled distance from the nearer side of its parent: margins stay
    symmetric, what was aligned stays aligned;
  * a control narrower than half its parent keeps its width in dialog units - two buttons of
    75 px become two of 88 - at the side it is nearer to; a wider one stretches between its
    two edges;
  * a row of equal controls keeps its gaps: chained from the side it is nearer to (buttons),
    or - reaching from side to side - sharing the width between the margins (boxes). }

type
  TLabelCracker = class(TCustomLabel);
  TControlAccess = class(TControl);
  TWinControlAccess = class(TWinControl);

  TLayoutItem = class
    Control: TControl;
    R: TRect;                   // bounds as designed
    N: TRect;                   // new bounds
    CW, CH: Integer;            // client size as designed (containers)
    Kids: TList;                // the items of its controls (containers)
    Follows: TLayoutItem;       // a label: the control whose text line it shares
    Seen: Boolean;
    destructor Destroy; override;
  end;

  TLayoutScaler = class
  private
    FItems: TList;              // every item (owned)
    FBX0, FBY0, FBX1, FBY1: Integer;
    function Find(C: TControl): TLayoutItem;
    function ScaleX(V: Integer): Integer;
    function ScaleY(V: Integer): Integer;
    function SizeX(V: Integer): Integer;
    function SizeY(V: Integer): Integer;
    function MapX(E, P0, P1: Integer): Integer;
    function OneLine(It: TLayoutItem): Boolean;
    function Wraps(It: TLayoutItem): Boolean;
    function Natural(It: TLayoutItem): Integer;
    function HeightOf(It: TLayoutItem): Integer;
    procedure FlowRow(Line: TList; First, Last, PW0: Integer);
    procedure Rows(Kids: TList; PW0: Integer);
    procedure HLayout(Kids: TList; PW0, PW1: Integer);
    function VLayout(Kids: TList; PH0, PH1: Integer; Flat: Boolean): Integer;
  public
    Root: TList;                // the items of the form's controls
    constructor Create(BX0, BY0, BX1, BY1: Integer);
    destructor Destroy; override;
    procedure Capture(Parent: TWinControl; List: TList);
    function Layout(Parent: TWinControl; Kids: TList; PW0, PH0, PW1, PH1: Integer): Integer;
    procedure Reapply(Kids: TList);
  end;

destructor TLayoutItem.Destroy;
begin
  Kids.Free;
  inherited;
end;

constructor TLayoutScaler.Create(BX0, BY0, BX1, BY1: Integer);
begin
  inherited Create;
  FItems := TList.Create;
  Root := TList.Create;
  FBX0 := BX0;
  FBY0 := BY0;
  FBX1 := BX1;
  FBY1 := BY1;
end;

destructor TLayoutScaler.Destroy;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do TObject(FItems[I]).Free;
  FItems.Free;
  Root.Free;
  inherited;
end;

function TLayoutScaler.Find(C: TControl): TLayoutItem;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    Result := TLayoutItem(FItems[I]);
    if Result.Control = C then Exit;
  end;
  Result := nil;
end;

procedure TLayoutScaler.Capture(Parent: TWinControl; List: TList);
var
  I: Integer;
  It: TLayoutItem;
  C: TControl;
begin
  for I := 0 to Parent.ControlCount - 1 do
  begin
    C := Parent.Controls[I];
    It := TLayoutItem.Create;
    It.Control := C;
    It.R := C.BoundsRect;
    It.N := It.R;
    FItems.Add(It);
    List.Add(It);
    if (C is TWinControl) and (TWinControl(C).ControlCount > 0) then
    begin
      It.CW := TWinControl(C).ClientWidth;
      It.CH := TWinControl(C).ClientHeight;
      It.Kids := TList.Create;
      Capture(TWinControl(C), It.Kids);
    end;
  end;
end;

function TLayoutScaler.ScaleX(V: Integer): Integer;
begin
  Result := MulDiv(V, FBX1, FBX0);
end;

function TLayoutScaler.ScaleY(V: Integer): Integer;
begin
  Result := MulDiv(V, FBY1, FBY0);
end;

{ a size in dialog units: 75 px -> 50 units -> 88 px }
function TLayoutScaler.SizeX(V: Integer): Integer;
begin
  Result := MulDiv(MulDiv(V, 4, FBX0), FBX1, 4);
end;

function TLayoutScaler.SizeY(V: Integer): Integer;
begin
  Result := MulDiv(MulDiv(V, 8, FBY0), FBY1, 8);
end;

{ an edge keeps its distance from the nearer side of the parent }
function TLayoutScaler.MapX(E, P0, P1: Integer): Integer;
begin
  if E * 2 <= P0 then Result := ScaleX(E)
  else Result := P1 - ScaleX(P0 - E);
end;

{ one line of text and its padding: edit, combo box, check box, label, status cell }
function TLayoutScaler.OneLine(It: TLayoutItem): Boolean;
begin
  Result := not (It.Control is TButton) and not (It.Control is TImage) and
    (It.R.Bottom - It.R.Top <= 2 * FBY0);
end;

{ a box that is as high as its content needs }
function TLayoutScaler.Wraps(It: TLayoutItem): Boolean;
var
  I: Integer;
begin
  Result := (It.Kids <> nil) and (It.Kids.Count > 0) and (It.Control.Align = alNone) and
    not (It.Control is TPageControl) and not (It.Control is TTabSheet) and not OneLine(It);
  if Result then
    for I := 0 to It.Kids.Count - 1 do
      if TLayoutItem(It.Kids[I]).Control.Align <> alNone then Result := False;
end;

function TLayoutScaler.Natural(It: TLayoutItem): Integer;
begin
  Result := VLayout(It.Kids, It.CH, -1, False) + (It.R.Bottom - It.R.Top - It.CH);
end;

function TLayoutScaler.HeightOf(It: TLayoutItem): Integer;
var
  C: TControl;
  H0: Integer;
begin
  C := It.Control;
  H0 := It.R.Bottom - It.R.Top;
  if (C is TCustomLabel) and TLabelCracker(C).AutoSize then
    Result := C.Height                  // the label has measured itself in the new font
  else if (C is TImage) or (H0 < FBY0) then Result := H0
  else if (C is TCustomLabel) and TLabelCracker(C).WordWrap then Result := ScaleY(H0)
  else if C is TButton then Result := SizeY(H0)
  else if OneLine(It) then Result := H0 + (FBY1 - FBY0)
  else if Wraps(It) then Result := Natural(It)
  else Result := ScaleY(H0);
end;

procedure TLayoutScaler.FlowRow(Line: TList; First, Last, PW0: Integer);
var
  M, X, X1, W, Gaps, Count: Integer;
  A, B: TLayoutItem;
begin
  A := TLayoutItem(Line[First]);
  B := TLayoutItem(Line[Last]);
  Count := Last - First + 1;
  if (A.R.Left * 4 < PW0) and ((PW0 - B.R.Right) * 4 < PW0) then
  begin
    { from side to side: the boxes share what the margins and the gaps leave }
    X := A.N.Left;
    X1 := B.N.Right;
    Gaps := 0;
    for M := First + 1 to Last do
      Inc(Gaps, ScaleX(TLayoutItem(Line[M]).R.Left - TLayoutItem(Line[M - 1]).R.Right));
    W := (X1 - X - Gaps) div Count;
    for M := First to Last do
    begin
      B := TLayoutItem(Line[M]);
      if M > First then Inc(X, ScaleX(B.R.Left - TLayoutItem(Line[M - 1]).R.Right));
      B.N.Left := X;
      if M = Last then B.N.Right := X1 else B.N.Right := X + W;
      X := B.N.Right;
    end;
  end
  else if A.R.Left <= PW0 - B.R.Right then
    { nearer to the left side: chained to the right }
    for M := First + 1 to Last do
    begin
      A := TLayoutItem(Line[M - 1]);
      B := TLayoutItem(Line[M]);
      OffsetRect(B.N, A.N.Right + ScaleX(B.R.Left - A.R.Right) - B.N.Left, 0);
    end
  else
    for M := Last - 1 downto First do
    begin
      A := TLayoutItem(Line[M]);
      B := TLayoutItem(Line[M + 1]);
      OffsetRect(A.N, B.N.Left - ScaleX(B.R.Left - A.R.Right) - A.N.Right, 0);
    end;
end;

{ equal controls of one kind next to each other in one row keep their gaps }
procedure TLayoutScaler.Rows(Kids: TList; PW0: Integer);
var
  I, J, K, Last, Gap: Integer;
  A, B: TLayoutItem;
  Line: TList;
begin
  for I := 0 to Kids.Count - 1 do TLayoutItem(Kids[I]).Seen := False;
  Line := TList.Create;
  try
    for I := 0 to Kids.Count - 1 do
    begin
      A := TLayoutItem(Kids[I]);
      if A.Seen or (A.Control.Align <> alNone) then Continue;
      Line.Clear;
      for J := 0 to Kids.Count - 1 do
      begin
        B := TLayoutItem(Kids[J]);
        if B.Seen or (B.Control.Align <> alNone) or (B.Control.ClassType <> A.Control.ClassType) or
          (B.R.Top <> A.R.Top) or (B.R.Bottom <> A.R.Bottom) or
          (Abs((B.R.Right - B.R.Left) - (A.R.Right - A.R.Left)) > 2) then Continue;
        B.Seen := True;
        K := 0;
        while (K < Line.Count) and (TLayoutItem(Line[K]).R.Left <= B.R.Left) do Inc(K);
        Line.Insert(K, B);
      end;
      K := 0;
      while K < Line.Count do
      begin
        Last := K;
        while Last + 1 < Line.Count do
        begin
          Gap := TLayoutItem(Line[Last + 1]).R.Left - TLayoutItem(Line[Last]).R.Right;
          if (Gap < 0) or (Gap > 2 * FBX0) then Break;
          Inc(Last);
        end;
        if Last > K then FlowRow(Line, K, Last, PW0);
        K := Last + 1;
      end;
    end;
  finally
    Line.Free;
  end;
end;

procedure TLayoutScaler.HLayout(Kids: TList; PW0, PW1: Integer);
var
  I, L, R, W, W0: Integer;
  It: TLayoutItem;
  C: TControl;
begin
  for I := 0 to Kids.Count - 1 do
  begin
    It := TLayoutItem(Kids[I]);
    C := It.Control;
    if C.Align <> alNone then Continue;
    W0 := It.R.Right - It.R.Left;
    L := MapX(It.R.Left, PW0, PW1);
    R := MapX(It.R.Right, PW0, PW1);
    if (C is TCustomLabel) and TLabelCracker(C).AutoSize then
      R := L + C.Width
    else
    begin
      if C is TImage then W := W0
      else if W0 * 2 <= PW0 then W := SizeX(W0)
      else W := R - L;
      if It.R.Left <= PW0 - It.R.Right then R := L + W else L := R - W;
    end;
    It.N.Left := L;
    It.N.Right := R;
  end;
  Rows(Kids, PW0);
end;

{ Lays the controls out vertically; PH1 is the new client height of the parent, or -1 when
  the parent is as high as its content needs. Returns that height. }
function TLayoutScaler.VLayout(Kids: TList; PH0, PH1: Integer; Flat: Boolean): Integer;
var
  I, J, K, H, Gap, Best, Last, RowTop, Low0, Low1: Integer;
  It, P, Up: TLayoutItem;
  Order: TList;
  C: TControl;
begin
  Result := PH1;
  Order := TList.Create;
  try
    { heights; the order from the top }
    for I := 0 to Kids.Count - 1 do
    begin
      It := TLayoutItem(Kids[I]);
      It.Follows := nil;
      C := It.Control;
      if C.Align <> alNone then Continue;
      H := HeightOf(It);
      if Flat then It.N.Top := It.R.Top else It.N.Top := ScaleY(It.R.Top);
      It.N.Bottom := It.N.Top + H;
      if (C is TCustomLabel) and (TLabelCracker(C).FocusControl <> nil) then
      begin
        P := Find(TLabelCracker(C).FocusControl);
        if (P <> nil) and (Kids.IndexOf(P) >= 0) and (Abs(It.R.Top - P.R.Top) <= 6) then It.Follows := P;
      end;
      J := 0;
      while (J < Order.Count) and (TLayoutItem(Order[J]).R.Top <= It.R.Top) do Inc(J);
      Order.Insert(J, It);
    end;
    if not Flat then
    begin
      { boxes side by side stay equally high }
      for I := 0 to Order.Count - 1 do
      begin
        It := TLayoutItem(Order[I]);
        if not Wraps(It) then Continue;
        for J := 0 to Order.Count - 1 do
        begin
          P := TLayoutItem(Order[J]);
          if (P <> It) and Wraps(P) and (P.R.Top = It.R.Top) and (P.R.Bottom = It.R.Bottom) and
            (P.N.Bottom - P.N.Top > It.N.Bottom - It.N.Top) then
            It.N.Bottom := It.N.Top + (P.N.Bottom - P.N.Top);
        end;
      end;
      { every control hangs below its nearest neighbour above; the controls of one row (one
        top in the design) keep one top }
      I := 0;
      while I < Order.Count do
      begin
        Last := I;
        while (Last + 1 < Order.Count) and
          (TLayoutItem(Order[Last + 1]).R.Top = TLayoutItem(Order[I]).R.Top) do Inc(Last);
        RowTop := -MaxInt;
        for K := I to Last do
        begin
          It := TLayoutItem(Order[K]);
          if It.Follows <> nil then Continue;
          Up := nil;
          Best := MaxInt;
          for J := 0 to I - 1 do
          begin
            P := TLayoutItem(Order[J]);
            if P.Follows <> nil then Continue;
            Gap := It.R.Top - P.R.Bottom;
            if (Gap >= 0) and (Gap < Best) and (P.R.Left < It.R.Right) and (It.R.Left < P.R.Right) then
            begin
              Best := Gap;
              Up := P;
            end;
          end;
          if Up <> nil then H := Up.N.Bottom + ScaleY(Best) else H := It.N.Top;
          if H > RowTop then RowTop := H;
        end;
        if RowTop > -MaxInt then
          for K := I to Last do
          begin
            It := TLayoutItem(Order[K]);
            if It.Follows = nil then OffsetRect(It.N, 0, RowTop - It.N.Top);
          end;
        I := Last + 1;
      end;
    end;
    { a label stays on the text line of the control it belongs to }
    for I := 0 to Order.Count - 1 do
    begin
      It := TLayoutItem(Order[I]);
      if It.Follows <> nil then
        OffsetRect(It.N, 0, It.Follows.N.Top + (It.R.Top - It.Follows.R.Top) - It.N.Top);
    end;
    if PH1 >= 0 then
    begin
      { a parent of a given size: what is anchored to its bottom follows it }
      for I := 0 to Order.Count - 1 do
      begin
        It := TLayoutItem(Order[I]);
        if akBottom in It.Control.Anchors then
          if akTop in It.Control.Anchors then
            It.N.Bottom := PH1 - ScaleY(PH0 - It.R.Bottom)
          else
            OffsetRect(It.N, 0, PH1 - ScaleY(PH0 - It.R.Bottom) - It.N.Bottom);
      end;
    end
    else if Order.Count > 0 then
    begin
      { as high as the content needs: the lowest control and the padding below it }
      Low0 := 0;
      Low1 := 0;
      for I := 0 to Order.Count - 1 do
      begin
        It := TLayoutItem(Order[I]);
        if It.R.Bottom > Low0 then Low0 := It.R.Bottom;
        if It.N.Bottom > Low1 then Low1 := It.N.Bottom;
      end;
      { a control of the design may reach below the parent (Delphi's Tool Options): no margin then }
      if Low0 > PH0 then Low0 := PH0;
      if Flat then Result := Low1 + (PH0 - Low0) else Result := Low1 + ScaleY(PH0 - Low0);
    end
    else
      Result := ScaleY(PH0);
  finally
    Order.Free;
  end;
end;

{ Lays out the controls of Parent, whose new client size is PW1 x PH1 (PH1 = -1: as high as
  the content needs), and then what is inside them. Returns the client height. The new size
  is passed down rather than read from the controls: while the form's alignment is disabled,
  aligned controls and tab sheets still have their old size. }
function TLayoutScaler.Layout(Parent: TWinControl; Kids: TList; PW0, PH0, PW1, PH1: Integer): Integer;
var
  I, W, H: Integer;
  It: TLayoutItem;
  C: TControl;
  Flat: Boolean;
begin
  Flat := not (Parent is TCustomForm) and (PH0 <= 2 * FBY0);
  HLayout(Kids, PW0, PW1);
  Result := VLayout(Kids, PH0, PH1, Flat);
  for I := 0 to Kids.Count - 1 do
  begin
    It := TLayoutItem(Kids[I]);
    C := It.Control;
    if (C.Align = alNone) and not (C is TTabSheet) then
      C.SetBounds(It.N.Left, It.N.Top, It.N.Right - It.N.Left, It.N.Bottom - It.N.Top);
  end;
  for I := 0 to Kids.Count - 1 do
  begin
    It := TLayoutItem(Kids[I]);
    if It.Kids = nil then Continue;
    C := It.Control;
    if (C.Align <> alNone) or (C is TTabSheet) then
    begin
      { placed by its parent: it grows with the parent in the directions it is stretched }
      W := It.CW;
      H := It.CH;
      if (C is TTabSheet) or (C.Align in [alClient, alTop, alBottom]) then Inc(W, PW1 - PW0);
      if (C is TTabSheet) or (C.Align in [alClient, alLeft, alRight]) then Inc(H, Result - PH0);
      Layout(TWinControl(C), It.Kids, It.CW, It.CH, W, H);
    end
    else if Wraps(It) then
      Layout(TWinControl(C), It.Kids, It.CW, It.CH,
        It.N.Right - It.N.Left - (It.R.Right - It.R.Left - It.CW), -1)
    else
      Layout(TWinControl(C), It.Kids, It.CW, It.CH,
        It.N.Right - It.N.Left - (It.R.Right - It.R.Left - It.CW),
        It.N.Bottom - It.N.Top - (It.R.Bottom - It.R.Top - It.CH));
  end;
end;

{ The bounds of the layout once more, after the form has its final size: a control anchored to
  the bottom or the right was moved again by the VCL when the form grew (its anchor rules were
  those of the old size); setting its bounds now also gives it the rules of the new size. }
procedure TLayoutScaler.Reapply(Kids: TList);
var
  I: Integer;
  It: TLayoutItem;
  C: TControl;
begin
  for I := 0 to Kids.Count - 1 do
  begin
    It := TLayoutItem(Kids[I]);
    C := It.Control;
    if (C.Align = alNone) and not (C is TTabSheet) and (C.Anchors <> [akLeft, akTop]) then
      C.SetBounds(It.N.Left, It.N.Top, It.N.Right - It.N.Left, It.N.Bottom - It.N.Top);
    if It.Kids <> nil then Reapply(It.Kids);
  end;
end;

{ a control with a font of its own (a bold title) keeps the style and gets the UI font }
procedure ApplyOwnFonts(Parent: TWinControl);
var
  I: Integer;
  C: TControl;
begin
  for I := 0 to Parent.ControlCount - 1 do
  begin
    C := Parent.Controls[I];
    if not TControlAccess(C).ParentFont then UIApplyFont(TControlAccess(C).Font);
    if C is TWinControl then ApplyOwnFonts(TWinControl(C));
  end;
end;

procedure UIReduceFlicker(Root: TWinControl);
var
  I: Integer;
begin
  for I := 0 to Root.ControlCount - 1 do UIReduceFlickerOf(Root.Controls[I]);
end;

{ List and tree views need nothing here: the modernized VCL paints them double-buffered and
  erases nothing first (ComCtrls.DoubleBufferedViews), in Windows Explorer's look
  (ExplorerThemeViews). }
procedure UIReduceFlickerOf(C: TControl);
begin
  if csDesigning in C.ComponentState then Exit;          // a form being designed is the user's
  if (C is TCustomTabControl) or (C is TCustomListBox) or (C is TCustomStatusBar) then
    TWinControl(C).DoubleBuffered := True;
  if C is TCustomListBox then UITrackListWidth(TCustomListBox(C));
  if C is TToolBar then UIModernToolBar(TToolBar(C));
  if C is TWinControl then UIReduceFlicker(TWinControl(C));
end;

{ --- window procedure hooks ------------------------------------------------------------------ }

{ TUIWindowHook (interface): the appearance's hooks are at most one of a class per control
  (UIFindHook) }
constructor TUIWindowHook.Create(AControl: TWinControl; Active: Boolean);
begin
  inherited Create(AControl);
  FControl := AControl;
  if Active then
  begin
    FOldProc := FControl.WindowProc;
    FControl.WindowProc := Hook;
  end;
end;

destructor TUIWindowHook.Destroy;
var
  P: TWndMethod;
  I: Integer;
  H: TUIWindowHook;
begin
  if Assigned(FOldProc) then
  begin
    P := FControl.WindowProc;
    if TMethod(P).Data = Self then
      FControl.WindowProc := FOldProc
    else
      { freed before a hook installed after it: that hook passes the messages on to this one's
        procedure from now on - it would call into the freed object otherwise }
      for I := 0 to FControl.ComponentCount - 1 do
        if (FControl.Components[I] <> Self) and (FControl.Components[I] is TUIWindowHook) then
        begin
          H := TUIWindowHook(FControl.Components[I]);
          if Assigned(H.FOldProc) and (TMethod(H.FOldProc).Data = Self) then H.FOldProc := FOldProc;
        end;
  end;
  inherited Destroy;
end;

function UIFindHook(Control: TWinControl; AClass: TUIWindowHookClass): TUIWindowHook;
var
  I: Integer;
begin
  for I := 0 to Control.ComponentCount - 1 do
    if Control.Components[I] is AClass then
    begin
      Result := TUIWindowHook(Control.Components[I]);
      Exit;
    end;
  Result := nil;
end;

{ --- the end of a press without a change (Esc, the mouse taken away) --------------------------- }

type
  TPressGuard = class(TUIWindowHook)
  private
    FOnCancel: TNotifyEvent;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TPressGuard.Hook(var Message: TMessage);
begin
  case Message.Msg of
    CN_KEYDOWN:
      if UIPressEscape(FControl, TWMKey(Message)) then
      begin
        if Assigned(FOnCancel) then FOnCancel(FControl);
        Message.Result := 1;
        Exit;
      end;
    WM_CAPTURECHANGED:
      begin
        FOldProc(Message);
        if UICaptureLost(FControl, Message) and Assigned(FOnCancel) then FOnCancel(FControl);
        Exit;
      end;
  end;
  FOldProc(Message);
end;

procedure UIOnPressCancel(Control: TWinControl; OnCancel: TNotifyEvent);
var
  G: TPressGuard;
begin
  G := TPressGuard(UIFindHook(Control, TPressGuard));
  if G = nil then G := TPressGuard.Create(Control, True);
  G.FOnCancel := OnCancel;
end;

{ --- a flat line under a control (the tool bar host) or above it (a status line) -------------- }

type
  { in the non-client area: the control's layout and its automatic size stay as they are }
  TEdgeLine = class(TUIWindowHook)
  private
    FTop: Boolean;                 // the line above the client area, else under it
    FPadding: Integer;             // between the line and the window's edge
    FMargin: Integer;              // around the client area (on the line's side too)
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TEdgeLine.Hook(var Message: TMessage);
var
  DC: HDC;
  R: TRect;
  Line: Integer;
begin
  FOldProc(Message);
  case Message.Msg of
    WM_NCCALCSIZE:     { the first rectangle, in both forms of the message: the client area }
      with PRect(Message.LParam)^ do
      begin
        Inc(Left, FMargin);
        Dec(Right, FMargin);
        if FTop then
        begin
          Inc(Top, FMargin + 1 + FPadding);
          Dec(Bottom, FMargin);
        end
        else
        begin
          Inc(Top, FMargin);
          Dec(Bottom, FMargin + 1 + FPadding);
        end;
      end;
    WM_NCPAINT:
      begin
        DC := GetWindowDC(FControl.Handle);
        if DC = 0 then Exit;
        try
          GetWindowRect(FControl.Handle, R);
          OffsetRect(R, -R.Left, -R.Top);
          { the margin around the client area, the line, the padding beyond the line }
          if FTop then Line := FPadding else Line := R.Bottom - 1 - FPadding;
          SaveDC(DC);
          try
            if FTop then ExcludeClipRect(DC, FMargin, Line + 1 + FMargin, R.Right - FMargin, R.Bottom - FMargin)
            else ExcludeClipRect(DC, FMargin, FMargin, R.Right - FMargin, Line - FMargin);
            UIFill(DC, R, TControlAccess(FControl).Color);
            FillRect(DC, Rect(R.Left, Line, R.Right, Line + 1), GetSysColorBrush(COLOR_BTNSHADOW));
          finally
            RestoreDC(DC, -1);
          end;
        finally
          ReleaseDC(FControl.Handle, DC);
        end;
      end;
  end;
end;

procedure EdgeLine(Control: TWinControl; Top: Boolean; Padding, Margin: Integer);
var
  E: TEdgeLine;
begin
  E := TEdgeLine(UIFindHook(Control, TEdgeLine));
  if E = nil then E := TEdgeLine.Create(Control, True);
  E.FTop := Top;
  E.FPadding := Padding;
  E.FMargin := Margin;
  if Control.HandleAllocated then
    SetWindowPos(Control.Handle, 0, 0, 0, 0, 0, SWP_FRAMECHANGED or SWP_NOMOVE or SWP_NOSIZE or
      SWP_NOZORDER or SWP_NOACTIVATE);
end;

procedure UIBottomBorder(Control: TWinControl; Padding: Integer; Margin: Integer);
begin
  EdgeLine(Control, False, Padding, Margin);
end;

procedure UITopBorder(Control: TWinControl; Padding: Integer; Margin: Integer);
begin
  EdgeLine(Control, True, Padding, Margin);
end;

procedure UIPageBar(Bar: TWinControl);
const
  Margin = 2;
var
  I, H, CH: Integer;
  C: TControl;
begin
  { as high as what it holds: a tool bar's buttons, an edit }
  if Bar is TToolBar then H := TToolBar(Bar).ButtonHeight
  else
  begin
    H := 0;
    for I := 0 to Bar.ControlCount - 1 do
    begin
      C := Bar.Controls[I];
      if C is TToolBar then CH := TToolBar(C).ButtonHeight else CH := C.Height;
      if CH > H then H := CH;
    end;
  end;
  TControlAccess(Bar).Color := UIBarColor;
  TControlAccess(Bar).AutoSize := False;
  UIBottomBorder(Bar, 0, Margin);
  Bar.Height := H + 2 * Margin + 1;
  if not (Bar is TToolBar) then UICentreChildren(Bar, H);
end;

procedure UICentreChildren(Strip: TWinControl; H: Integer);
var
  I: Integer;
  C: TControl;
begin
  for I := 0 to Strip.ControlCount - 1 do
  begin
    C := Strip.Controls[I];
    if C is TToolBar then C.Top := (H - TToolBar(C).ButtonHeight) div 2 else C.Top := (H - C.Height) div 2;
  end;
end;

{ Its text changes as one works (the pixel under the mouse, the caret): the strip paints itself
  whole through a buffer, nothing erased on the screen - with its parent's ground (a themed
  panel's) the label's place was erased on the screen at each change, through the page, before
  its text came: it flickered }
procedure UIPageStatus(Status: TWinControl);
begin
  TWinControlAccess(Status).ParentBackground := False;
  Status.DoubleBuffered := True;
  UITopBorder(Status, 0);
  Status.Height := Status.Height + 1;
end;

{ --- horizontal tracking of list boxes ------------------------------------------------------- }

const
  RowMargin = 2;           // before a row's text and after it (TCustomListBox.DrawItem)

type
  TListBoxAccess = class(TCustomListBox);

  { owned by its list: takes the list's window procedure and follows the rows drawn (FOldProc
    nil: the list does not track - UINoListTracking). A list box gives an owner-drawn row the
    whole range (rcItem from 0) and scrolls the drawing, so the rows' painting stays as it is. }
  TListTracker = class(TUIWindowHook)
  private
    FList: TCustomListBox;
    FHeader: TWinControl;
    FWidest: Integer;      // the right end of the widest row drawn since the list was emptied
    FExtent: Integer;      // the range the list has
    FReported: Boolean;    // the row being drawn said where it ends (UIListRowWidth)
    FPosted: Boolean;      // a new range is on its way to the list
    FScrollPos: Integer;   // where the header was placed
    FNoPad: Boolean;       // rows as the list sets them (UINoListPadding)
    FDrawsRows: Boolean;   // a plain list box made owner-drawn: the tracker draws its rows
    FOwnRange: Boolean;    // the list's own code sets its range: not measured any more
    FSetting: Boolean;     // the range being set is the tracker's
    FAnchorPending: Boolean; // the header and the list keep their alignment until the list has its window
    function RowHeight: Integer;
    procedure DrawRow(DIS: PDrawItemStruct);
    function TextRight(DC: HDC; Left, Index: Integer): Integer;
    procedure Grow(Right: Integer);
    procedure SetExtent;
    procedure Restart;
    procedure MeasureShown;
    procedure PaintBuffered;
    procedure PlaceHeader;
    procedure AnchorHeader;
  protected
    procedure Hook(var Message: TMessage); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AList: TCustomListBox; Track: Boolean); reintroduce;
  end;

var
  TrackMsg: Cardinal;      // posted to a list after a wider row was drawn

function FindTracker(List: TCustomListBox): TListTracker;
begin
  Result := TListTracker(UIFindHook(List, TListTracker));
end;

constructor TListTracker.Create(AList: TCustomListBox; Track: Boolean);
begin
  inherited Create(AList, Track);
  FList := AList;
  if Track and (TrackMsg = 0) then TrackMsg := RegisterWindowMessage('D7Studio.ListTracking');
end;

{ the text of the list's font and UIListPadY above and below it }
function TListTracker.RowHeight: Integer;
begin
  Result := UIFontHeight(TListBoxAccess(FList).Font) + 2 * UIListPadY;
end;

{ a row of a plain list box: as Windows draws it, the text centred in the padded row }
procedure TListTracker.DrawRow(DIS: PDrawItemStruct);
begin
  if Integer(DIS^.itemID) < 0 then UIFill(DIS^.hDC, DIS^.rcItem, TListBoxAccess(FList).Color)
  else UIDrawListRow(FList, DIS^.hDC, DIS^.rcItem, FList.Items[DIS^.itemID], DIS^.itemState and ODS_SELECTED <> 0);
end;

procedure UIListRowColors(List: TCustomListBox; Selected: Boolean; out Back, Fore: TColor);
begin
  if Selected then
  begin
    Back := clHighlight;
    Fore := clHighlightText;
  end
  else
  begin
    Back := TListBoxAccess(List).Color;
    if List.Enabled then Fore := TListBoxAccess(List).Font.Color else Fore := clGrayText;
  end;
end;

procedure UIDrawListRow(List: TCustomListBox; DC: HDC; const R: TRect; const Text: string; Selected: Boolean);
var
  T: TRect;
  Back, Fore: TColor;
  Old: HGDIOBJ;
begin
  UIListRowColors(List, Selected, Back, Fore);
  UIFill(DC, R, Back);
  Old := SelectObject(DC, TListBoxAccess(List).Font.Handle);
  try
    T := R;
    Inc(T.Left, 2);
    UIText(DC, Text, T, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX, Fore);
    UIListRowWidth(List, T.Left + UITextWidth(DC, Text));
  finally
    SelectObject(DC, Old);
  end;
end;

procedure TListTracker.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FHeader) then FHeader := nil;
end;

function TListTracker.TextRight(DC: HDC; Left, Index: Integer): Integer;
var
  Old: HFONT;
begin
  Old := SelectObject(DC, TListBoxAccess(FList).Font.Handle);
  Result := Left + RowMargin + UITextWidth(DC, FList.Items[Index]);
  SelectObject(DC, Old);
end;

procedure TListTracker.Grow(Right: Integer);
begin
  if FOwnRange then Exit;
  Inc(Right, RowMargin);
  if Right <= FWidest then Exit;
  FWidest := Right;
  { set after the painting: a new range shows the scroll bar, which paints the list again }
  if not FPosted and FList.HandleAllocated then
  begin
    FPosted := True;
    PostMessage(FList.Handle, TrackMsg, 0, 0);
  end;
end;

procedure TListTracker.SetExtent;
begin
  if FOwnRange or (FWidest = FExtent) or not FList.HandleAllocated then Exit;
  FExtent := FWidest;
  FSetting := True;
  try
    SendMessage(FList.Handle, LB_SETHORIZONTALEXTENT, FExtent, 0);
  finally
    FSetting := False;
  end;
end;

procedure TListTracker.Restart;
begin
  FWidest := 0;
  SetExtent;
end;

{ the rows a list box draws itself (no owner drawing): those in view, after each painting }
procedure TListTracker.MeasureShown;
var
  DC: HDC;
  First, Last, H, I: Integer;
begin
  H := SendMessage(FList.Handle, LB_GETITEMHEIGHT, 0, 0);
  if (FList.Items.Count = 0) or (H <= 0) then Exit;
  First := SendMessage(FList.Handle, LB_GETTOPINDEX, 0, 0);
  Last := First + FList.ClientHeight div H;
  if Last >= FList.Items.Count then Last := FList.Items.Count - 1;
  DC := GetDC(FList.Handle);
  try
    for I := First to Last do Grow(TextRight(DC, 0, I));
  finally
    ReleaseDC(FList.Handle, DC);
  end;
end;

{ The VCL's double buffering (TWinControl.WMPaint), but the rows are painted by the list box:
  the VCL paints them itself into a buffer (TCustomListBox.WMPaint with a DC) - not scrolled
  sideways (old and new text mixed), every row as unselected, and row 0 also of an empty list.
  The list box draws them scrolled, through a window origin moved by the scroll position, and
  leaves the DC so: the origin goes back before the buffer is copied. }
procedure TListTracker.PaintBuffered;
var
  DC, MemDC: HDC;
  Bmp, OldBmp: HBITMAP;
  PS: TPaintStruct;
  R: TRect;
  SaveDpi: Integer;
begin
  { the theme's parts for the monitor of the list, as the VCL's WMPaint (which this takes the place
    of) gives them - a TCheckListBox's check glyphs on a monitor of another DPI }
  SaveDpi := Themes.GetThemePaintDpi;
  Themes.SetThemePaintDpi(GetControlDpi(FList));
  try
  R := FList.ClientRect;
  DC := BeginPaint(FList.Handle, PS);
  MemDC := CreateCompatibleDC(DC);
  Bmp := CreateCompatibleBitmap(DC, R.Right, R.Bottom);
  OldBmp := SelectObject(MemDC, Bmp);
  try
    FList.Perform(WM_ERASEBKGND, MemDC, MemDC);
    CallWindowProc(TListBoxAccess(FList).DefWndProc, FList.Handle, WM_PAINT, MemDC, 0);
    SetWindowOrgEx(MemDC, 0, 0, nil);
    BitBlt(DC, 0, 0, R.Right, R.Bottom, MemDC, 0, 0, SRCCOPY);
  finally
    SelectObject(MemDC, OldBmp);
    DeleteObject(Bmp);
    DeleteDC(MemDC);
    EndPaint(FList.Handle, PS);
  end;
  finally
    Themes.SetThemePaintDpi(SaveDpi);
  end;
end;

procedure TListTracker.PlaceHeader;
begin
  FScrollPos := GetScrollPos(FList.Handle, SB_HORZ);
  FHeader.SetBounds(FList.Left - FScrollPos, FHeader.Top, FList.Width + FScrollPos, FHeader.Height);
end;

{ The header moves left with the rows: neither may be aligned any more - both are anchored to the
  parent instead. Done once the parent has its window: anchors set before take a parent without a
  window at its outer size, so in a bordered parent they would leave both short by its border. A
  list that filled its parent fills its client area under the header, the header its width. }
procedure TListTracker.AnchorHeader;
var
  LR, HR: TRect;
begin
  FAnchorPending := False;
  if FHeader = nil then Exit;
  LR := FList.BoundsRect;
  HR := FHeader.BoundsRect;
  if (FList.Align = alClient) and (FList.Parent <> nil) then
  begin
    LR := FList.Parent.ClientRect;
    if HR.Bottom > LR.Top then LR.Top := HR.Bottom;
    HR.Left := LR.Left;
    HR.Right := LR.Right;
  end;
  FHeader.Align := alNone;
  FList.Align := alNone;
  FHeader.BoundsRect := HR;
  FList.BoundsRect := LR;
  FHeader.Anchors := [akLeft, akTop, akRight];
  FList.Anchors := [akLeft, akTop, akRight, akBottom];
  PlaceHeader;
end;

procedure TListTracker.Hook(var Message: TMessage);
var
  DIS: PDrawItemStruct;
begin
  if Message.Msg = TrackMsg then
  begin
    FPosted := False;
    if FAnchorPending then AnchorHeader;
    SetExtent;
    Exit;
  end;
  case Message.Msg of
    CN_DRAWITEM:
      begin
        DIS := TWMDrawItem(Message).DrawItemStruct;
        { an empty list with the focus asks for row 0 (its focus rectangle): the VCL draws it
          as no row - the lists' own drawing would read a row that is not there }
        if Integer(DIS^.itemID) >= FList.Items.Count then DIS^.itemID := Cardinal(-1);
        { no dotted focus rectangle: the selection shows the row }
        DIS^.itemState := DIS^.itemState and not ODS_FOCUS;
        FReported := False;
        { a plain list box's row; a handler given later (a dialog sets Style and OnDrawItem in
          OnCreate, after UIPrepareForm) draws its own }
        if FDrawsRows and not Assigned(TListBoxAccess(FList).OnDrawItem) then DrawRow(DIS)
        else FOldProc(Message);
        { the VCL has moved rcItem.Left past what it draws first (a check list's box) }
        if not FReported and not FOwnRange and (Integer(DIS^.itemID) >= 0) and
          (Integer(DIS^.itemID) < FList.Items.Count) then
          Grow(TextRight(DIS^.hDC, DIS^.rcItem.Left, DIS^.itemID));
      end;
    WM_PAINT:
      begin
        if (Message.WParam = 0) and FList.DoubleBuffered then PaintBuffered
        else FOldProc(Message);
        if (TListBoxAccess(FList).Style = lbStandard) and not FOwnRange then MeasureShown;
      end;
    LB_SETHORIZONTALEXTENT:
      begin
        { a range the list's own code sets: its rows are measured there (a virtual list's rows
          have no text to measure here) }
        if not FSetting then FOwnRange := True;
        FOldProc(Message);
      end;
    LB_RESETCONTENT, WM_SETFONT:
      begin
        FOldProc(Message);
        Restart;
        { a font chosen later (Debugger views font): the rows of an owner-drawn list follow it -
          Windows measures them once, when the list is made (a plain list box re-measured them
          itself) }
        if (Message.Msg = WM_SETFONT) and not FNoPad and (TListBoxAccess(FList).Style = lbOwnerDrawFixed) then
        begin
          SendMessage(FList.Handle, LB_SETITEMHEIGHT, 0, TListBoxAccess(FList).ItemHeight);
          FList.Invalidate;
        end;
      end;
    CN_MEASUREITEM:
      begin
        FOldProc(Message);
        if not FNoPad then
          with TWMMeasureItem(Message).MeasureItemStruct^ do
            if Integer(itemHeight) < RowHeight then itemHeight := RowHeight;
      end;
    LB_SETITEMHEIGHT:
      begin
        if not FNoPad and (Message.LParam < RowHeight) then Message.LParam := RowHeight;
        FOldProc(Message);
      end;
    WM_SETFOCUS:
      begin
        { a list box that draws its rows itself (lbStandard) hides its focus rectangle by the
          window's UI state: hidden here, and kept so below }
        SendMessage(FList.Handle, WM_UPDATEUISTATE, MakeWParam(UIS_SET, UISF_HIDEFOCUS), 0);
        FOldProc(Message);
      end;
    WM_UPDATEUISTATE, WM_CHANGEUISTATE:
      begin
        if LoWord(Message.WParam) = UIS_CLEAR then
          Message.WParam := MakeWParam(UIS_CLEAR, HiWord(Message.WParam) and not UISF_HIDEFOCUS);
        if HiWord(Message.WParam) <> 0 then FOldProc(Message);
      end;
    LB_DELETESTRING:
      begin
        FOldProc(Message);
        if Message.Result = 0 then Restart;          // the last row went
      end;
    WM_DESTROY:
      begin
        FOldProc(Message);
        FWidest := 0;                                 // the range was the window's
        FExtent := 0;
        FPosted := False;
      end;
  else
    FOldProc(Message);
  end;
  if (FHeader <> nil) and FList.HandleAllocated then
    if FAnchorPending then
    begin
      { the list has its window: the anchoring comes once its making is over (TrackMsg) }
      if not FPosted then
      begin
        FPosted := True;
        PostMessage(FList.Handle, TrackMsg, 0, 0);
      end;
    end
    else if (Message.Msg = WM_WINDOWPOSCHANGED) or (GetScrollPos(FList.Handle, SB_HORZ) <> FScrollPos) then
      PlaceHeader;
end;

procedure UITrackListWidth(List: TCustomListBox);
var
  T: TListTracker;
begin
  if FindTracker(List) <> nil then Exit;
  T := TListTracker.Create(List, True);
  { a plain list box: its rows drawn by the tracker, padded (a check list box draws its own);
    not in a layout pass, which writes the .dfm }
  if not UILayoutPass and (TListBoxAccess(List).Style = lbStandard) and not (List is TCheckListBox) then
  begin
    T.FDrawsRows := True;
    TListBoxAccess(List).Style := lbOwnerDrawFixed;
  end;
end;

procedure UINoListPadding(List: TCustomListBox);
var
  T: TListTracker;
begin
  T := FindTracker(List);
  if T = nil then T := TListTracker.Create(List, True);
  T.FNoPad := True;
end;

function UIListTextTop(DC: HDC; const R: TRect): Integer;
var
  TM: TTextMetric;
begin
  GetTextMetrics(DC, TM);
  Result := R.Top + (R.Bottom - R.Top - TM.tmHeight) div 2;
end;

procedure UIListRowWidth(List: TCustomListBox; Right: Integer);
var
  T: TListTracker;
begin
  T := FindTracker(List);
  if (T = nil) or not Assigned(T.FOldProc) then Exit;
  T.FReported := True;
  T.Grow(Right);
end;

procedure UIListHeader(List: TCustomListBox; Header: TWinControl);
var
  T: TListTracker;
begin
  UITrackListWidth(List);
  T := FindTracker(List);
  if not Assigned(T.FOldProc) then Exit;
  T.FHeader := Header;
  Header.FreeNotification(T);
  { anchored now if the list has its window, else once it has (TListTracker.AnchorHeader) }
  if List.HandleAllocated then T.AnchorHeader else T.FAnchorPending := True;
end;

procedure UINoListTracking(List: TCustomListBox);
var
  T: TListTracker;
begin
  T := FindTracker(List);
  if (T <> nil) and Assigned(T.FOldProc) then FreeAndNil(T);
  if T = nil then TListTracker.Create(List, False);
end;

type
  { UIRepaintOnWidth's: owned by its control }
  TWidthRepaint = class(TUIWindowHook)
  private
    FWidth: Integer;       // the width last painted at
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TWidthRepaint.Hook(var Message: TMessage);
var
  P: PWindowPos;
begin
  FOldProc(Message);
  if Message.Msg <> WM_WINDOWPOSCHANGED then Exit;
  P := TWMWindowPosChanged(Message).WindowPos;
  if (P^.flags and SWP_NOSIZE <> 0) or (P^.cx = FWidth) then Exit;
  FWidth := P^.cx;
  InvalidateRect(FControl.Handle, nil, False);
end;

procedure UIRepaintOnWidth(Control: TWinControl);
begin
  if UIFindHook(Control, TWidthRepaint) = nil then TWidthRepaint.Create(Control, True);
end;

{ --- windows on the screen ------------------------------------------------------------------- }

{ the work area of monitor Mon. The API, not Screen.MonitorFromRect: Delphi 7's Screen keeps the
  monitors it found first and answers nil for one plugged in since }
function MonitorWorkArea(Mon: HMONITOR; var W: TRect): Boolean;
var
  Info: TMonitorInfo;
begin
  Info.cbSize := SizeOf(Info);
  Result := MultiMon.GetMonitorInfo(Mon, @Info);
  if Result then W := Info.rcWork;
end;

{ R inside the work area of monitor Mon: UIFitWorkArea, UIFitWorkAreaAt }
procedure FitMonitorWorkArea(var R: TRect; Mon: HMONITOR; Shrink: Boolean);
var
  W: TRect;
begin
  if not MonitorWorkArea(Mon, W) then Exit;
  if Shrink then
  begin
    if R.Right - R.Left > W.Right - W.Left then R.Right := R.Left + W.Right - W.Left;
    if R.Bottom - R.Top > W.Bottom - W.Top then R.Bottom := R.Top + W.Bottom - W.Top;
  end;
  { right and bottom first: a window larger than the area keeps its caption on it }
  if R.Right > W.Right then OffsetRect(R, W.Right - R.Right, 0);
  if R.Left < W.Left then OffsetRect(R, W.Left - R.Left, 0);
  if R.Bottom > W.Bottom then OffsetRect(R, 0, W.Bottom - R.Bottom);
  if R.Top < W.Top then OffsetRect(R, 0, W.Top - R.Top);
end;

procedure UIFitWorkArea(var R: TRect; Shrink: Boolean);
begin
  FitMonitorWorkArea(R, MultiMon.MonitorFromRect(@R, MONITOR_DEFAULTTONEAREST), Shrink);
end;

procedure UIFitWorkAreaAt(var R: TRect; const Anchor: TPoint);
begin
  FitMonitorWorkArea(R, MultiMon.MonitorFromPoint(Anchor, MONITOR_DEFAULTTONEAREST), False);
end;

procedure UITipOffLine(var R: TRect; const Line: TRect);
var
  W: TRect;
  H, Top: Integer;
begin
  if (R.Top >= Line.Bottom) or (R.Bottom <= Line.Top) then Exit;
  if not MonitorWorkArea(MultiMon.MonitorFromPoint(Line.TopLeft, MONITOR_DEFAULTTONEAREST), W) then Exit;
  H := R.Bottom - R.Top;
  if Line.Bottom + H <= W.Bottom then Top := Line.Bottom
  else if Line.Top - H >= W.Top then Top := Line.Top - H
  else if W.Bottom - Line.Bottom >= Line.Top - W.Top then Top := W.Bottom - H
  else Top := W.Top;
  if Top < W.Top then Top := W.Top;          // taller than the area: its top on it
  OffsetRect(R, 0, Top - R.Top);
end;

function UIWorkArea(Wnd: HWND): TRect;
begin
  if not MonitorWorkArea(MultiMon.MonitorFromWindow(Wnd, MONITOR_DEFAULTTONEAREST), Result) then
    SystemParametersInfo(SPI_GETWORKAREA, 0, @Result, 0);
end;

function UIWorkAreaAt(const P: TPoint): TRect;
begin
  if not MonitorWorkArea(MultiMon.MonitorFromPoint(P, MONITOR_DEFAULTTONEAREST), Result) then
    SystemParametersInfo(SPI_GETWORKAREA, 0, @Result, 0);
end;

type
  PCaptionTest = ^TCaptionTest;
  TCaptionTest = record
    Cap: TRect;
    Found: Boolean;
  end;

function CaptionTestProc(Mon: HMONITOR; DC: HDC; R: PRect; Data: LPARAM): Boolean; stdcall;
var
  Info: TMonitorInfo;
  X: TRect;
begin
  Info.cbSize := SizeOf(Info);
  with PCaptionTest(Data)^ do
    if not Found and MultiMon.GetMonitorInfo(Mon, @Info) and IntersectRect(X, Cap, Info.rcWork) and
      (X.Right - X.Left >= 32) and (X.Bottom - X.Top = Cap.Bottom - Cap.Top) then Found := True;
  Result := True;                      // every monitor: the enumeration goes on
end;

function UICaptionOnScreen(const R: TRect; Height: Integer): Boolean;
var
  T: TCaptionTest;
begin
  { the monitors as they are now, from the API: Delphi 7's Screen keeps the ones it found first
    (one unplugged since stays in its list, one plugged in is not there) }
  T.Cap := Rect(R.Left, R.Top, R.Right, R.Top + Height);
  T.Found := False;
  MultiMon.EnumDisplayMonitors(0, nil, CaptionTestProc, LPARAM(@T));
  Result := T.Found;
end;

{ A dialog centred on the form it was opened from when it is first shown (Position =
  poOwnerFormCenter in its .dfm). The VCL's own centring turns a negative x or y
  into 0 (TCustomForm.CMShowingChanged), and SetWindowToMonitor then puts the dialog at that place
  on the owner's monitor: a dialog of a window on a monitor left of (or above) the primary one
  opened at that monitor's edge. The hook places the window in the
  SetWindowPos that shows it - after the VCL's places, before anything is seen -, once, as the
  VCL does: a modeless dialog shown again stays where it was put. The form it belongs to is
  taken before that, when the VCL starts to show it (CM_SHOWINGCHANGED): ShowWindow activates the
  dialog first, and the dialog is Screen.ActiveCustomForm by the time its window is placed
  (measured) - a floating view's dialog went to the main window. A dialog of the whole IDE
  (Position = poMainFormCenter: the Compiling dialog) is centred on the main window even when its
  command came from a floating view, placed the same way. }
type
  TOwnerCenter = class(TUIWindowHook)
  protected
    FPlaced: Boolean;
    FOwnerForm: TCustomForm;     // what it is centred on, from CM_SHOWINGCHANGED to the placing
    procedure Hook(var Message: TMessage); override;
  end;

{ F can have a dialog centred on it: a shown top-level window, not minimized }
function CentreOn(F, Dialog: TCustomForm): Boolean;
begin
  Result := (F <> nil) and (F <> Dialog) and F.HandleAllocated and IsWindowVisible(F.Handle) and
    not IsIconic(F.Handle) and (GetWindowLong(F.Handle, GWL_STYLE) and WS_CHILD = 0);
end;

{ the form a dialog belongs to: its owner, the form of an owner control; a dialog of the main
  window belongs to the window its command came from when that is another one (a floating
  view's); a poMainFormCenter dialog belongs to the main window; nil: none to centre on }
function DialogOwner(Dialog: TCustomForm): TCustomForm;
begin
  Result := nil;
  if TForm(Dialog).Position = poMainFormCenter then
  begin
    Result := Application.MainForm;
    if not CentreOn(Result, Dialog) then Result := nil;
    Exit;
  end;
  if Dialog.Owner is TCustomForm then Result := TCustomForm(Dialog.Owner)
  else if Dialog.Owner is TControl then Result := GetParentForm(TControl(Dialog.Owner));
  if Result = nil then Result := Application.MainForm;
  if (Result = Application.MainForm) and CentreOn(Screen.ActiveCustomForm, Dialog) then
    Result := Screen.ActiveCustomForm
  else if not CentreOn(Result, Dialog) then Result := nil;
end;

procedure TOwnerCenter.Hook(var Message: TMessage);
var
  P: PWindowPos;
  F: TCustomForm;
  O, R: TRect;
  W, H: Integer;
begin
  if (Message.Msg = CM_SHOWINGCHANGED) and not FPlaced and FControl.Showing then
    FOwnerForm := DialogOwner(TCustomForm(FControl))
  else if (Message.Msg = WM_WINDOWPOSCHANGING) and not FPlaced then
  begin
    P := PWindowPos(Message.LParam);
    if P^.flags and SWP_SHOWWINDOW <> 0 then
    begin
      FPlaced := True;
      F := FOwnerForm;
      FOwnerForm := nil;
      if F <> nil then
      begin
        GetWindowRect(FControl.Handle, R);
        W := R.Right - R.Left;
        H := R.Bottom - R.Top;
        if P^.flags and SWP_NOSIZE = 0 then
        begin
          W := P^.cx;
          H := P^.cy;
        end;
        GetWindowRect(F.Handle, O);
        R := Bounds(O.Left + (O.Right - O.Left - W) div 2, O.Top + (O.Bottom - O.Top - H) div 2, W, H);
        { whole on one monitor - never cut: a dialog larger than the area keeps its caption on it }
        UIFitWorkArea(R, False);
        P^.x := R.Left;
        P^.y := R.Top;
        P^.flags := P^.flags and not SWP_NOMOVE;
      end;
    end;
  end;
  FOldProc(Message);
end;

{ Root's controls laid out by TLayoutScaler from the font metrics BX0 x BY0 to the UI font's, for
  a client CW1 wide and CH1 high (-1: as high as the content needs); Fonts: the UI font given to
  Root and to the controls with a font of their own first }
procedure LayoutRoot(Root: TWinControl; BX0, BY0, CW1, CH1: Integer; Fonts: Boolean);
var
  CW0, CH0: Integer;
  S: TLayoutScaler;
begin
  S := TLayoutScaler.Create(BX0, BY0, BaseX, BaseY);
  try
    CW0 := Root.ClientWidth;
    CH0 := Root.ClientHeight;
    S.Capture(Root, S.Root);
    Root.DisableAlign;
    try
      if Fonts then
      begin
        UIApplyFont(TControlAccess(Root).Font);
        ApplyOwnFonts(Root);
      end;
      Root.ClientWidth := CW1;
      Root.ClientHeight := S.Layout(Root, S.Root, CW0, CH0, Root.ClientWidth, CH1);
    finally
      Root.EnableAlign;
    end;
    S.Reapply(S.Root);
  finally
    S.Free;
  end;
end;

{ a form's or a frame's font of the .dfm as it is on this system: the UI font for it, and a new
  layout when the metrics differ - as wide as scaled, as high as the content needs }
procedure PrepareRoot(Root: TWinControl);
var
  BX0, BY0: Integer;
begin
  MeasureFont(TControlAccess(Root).Font.Handle, BX0, BY0);
  if ((BX0 = BaseX) and (BY0 = BaseY)) or (BX0 <= 0) or (BY0 <= 0) then
  begin
    UIApplyFont(TControlAccess(Root).Font);
    ApplyOwnFonts(Root);
  end
  else
    LayoutRoot(Root, BX0, BY0, MulDiv(Root.ClientWidth, BaseX, BX0), -1, True);
end;

procedure UISetDialogBackground(Choice: Integer);
begin
  if Choice = 1 then UIDialogColor := clBtnFace else UIDialogColor := clWindow;
end;

procedure UIPrepareForm(AForm: TCustomForm);
begin
  NeedMetrics;
  if not UILayoutPass and (TForm(AForm).Color = clWindow) then TForm(AForm).Color := UIDialogColor;
  UIReduceFlicker(AForm);
  { not for a layout pass: OwnerDraw would be written into the .dfm }
  if not UILayoutPass then UIOwnerDrawMenus(AForm);
  { centred on its owner or the main window (not for a layout pass either: the form's own
    components are written) }
  if not UILayoutPass and (TForm(AForm).Position in [poOwnerFormCenter, poMainFormCenter]) and
    (UIFindHook(AForm, TOwnerCenter) = nil) then TOwnerCenter.Create(AForm, True);
  PrepareRoot(AForm);
end;

procedure UIPrepareFrame(AFrame: TCustomFrame);
begin
  NeedMetrics;
  if not UILayoutPass then UIOwnerDrawMenus(AFrame);
  PrepareRoot(AFrame);
end;

procedure UIMoveBody(Dialog: TWinControl; Band: TControl; Host: TWinControl; DX, DY: Integer);

  function Next(Windowed: Boolean): TControl;
  var
    I: Integer;
    C: TControl;
  begin
    Result := nil;
    for I := 0 to Dialog.ControlCount - 1 do
    begin
      C := Dialog.Controls[I];
      if (C = Band) or ((C is TWinControl) <> Windowed) then Continue;
      if (Result = nil) or not Windowed or (TWinControl(C).TabOrder < TWinControl(Result).TabOrder) then Result := C;
      if not Windowed then Exit;
    end;
  end;

  procedure Move(C: TControl);
  begin
    C.Parent := Host;
    if (DX <> 0) or (DY <> 0) then C.SetBounds(C.Left + DX, C.Top + DY, C.Width, C.Height);
  end;

var
  C: TControl;
begin
  C := Next(True);
  while C <> nil do
  begin
    Move(C);
    C := Next(True);
  end;
  C := Next(False);
  while C <> nil do
  begin
    Move(C);
    C := Next(False);
  end;
end;
procedure UILayoutTo(Root: TWinControl; Width, Height: Integer);
begin
  NeedMetrics;
  LayoutRoot(Root, BaseX, BaseY, Width, Height, False);
end;

{ --- primitives --- }

function UISelectionTint(Back: TColor): TColor;
begin
  Result := UIBlend(clHighlight, Back, 22);
end;

procedure UIMoveControls(const Controls: array of TWinControl; const Bounds: array of TRect);
var
  I: Integer;
  DWP: HDWP;
begin
  DWP := BeginDeferWindowPos(Length(Controls));
  for I := 0 to High(Controls) do
    if (DWP <> 0) and Controls[I].HandleAllocated and not EqualRect(Controls[I].BoundsRect, Bounds[I]) then
      DWP := DeferWindowPos(DWP, Controls[I].Handle, 0, Bounds[I].Left, Bounds[I].Top,
        Bounds[I].Right - Bounds[I].Left, Bounds[I].Bottom - Bounds[I].Top,
        SWP_NOZORDER or SWP_NOACTIVATE or SWP_NOOWNERZORDER);
  if DWP <> 0 then EndDeferWindowPos(DWP);
  { the VCL's state, and what the batch could not take (no window yet, a failed batch) }
  for I := 0 to High(Controls) do
    if not EqualRect(Controls[I].BoundsRect, Bounds[I]) then Controls[I].BoundsRect := Bounds[I];
end;

procedure UIPaintNow(Control: TWinControl);
begin
  if Control.HandleAllocated and IsWindowVisible(Control.Handle) then
    RedrawWindow(Control.Handle, nil, 0, RDW_UPDATENOW or RDW_ALLCHILDREN);
end;

{ WM_SETREDRAW: True also makes a window visible (Windows keeps "redraw off" as a hidden
  WS_VISIBLE) - only windows the VCL counts as showing are switched, both ways (a window made
  visible behind the VCL's back stays so when the VCL hides the control later: TSdDock.Apply) }
procedure UIFreezeRedraw(Container: TWinControl; Freeze: Boolean; PaintNow: Boolean = True);
var
  I: Integer;
  C: TControl;
  Flags: Cardinal;
begin
  if not Container.HandleAllocated or not Container.Showing then Exit;
  for I := 0 to Container.ControlCount - 1 do
  begin
    C := Container.Controls[I];
    if (C is TWinControl) and TWinControl(C).Showing and TWinControl(C).HandleAllocated then
      SendMessage(TWinControl(C).Handle, WM_SETREDRAW, Ord(not Freeze), 0);
  end;
  SendMessage(Container.Handle, WM_SETREDRAW, Ord(not Freeze), 0);
  if not Freeze then
  begin
    Flags := RDW_INVALIDATE or RDW_ERASE or RDW_FRAME or RDW_ALLCHILDREN;
    if PaintNow then Flags := Flags or RDW_UPDATENOW;
    RedrawWindow(Container.Handle, nil, 0, Flags);
  end;
end;

{ UIBeginSwap / UIEndSwap: Windows paints a window with WS_EX_COMPOSITED and all its children
  bottom to top through one buffer - when the window itself is painted (RedrawWindow with
  RDW_UPDATENOW; measured: a container covered by its children gets no WM_PAINT of its own, and
  the children painted one by one). The paint is a posted message: it comes after the command that
  swapped (a posted message goes before any WM_PAINT), once for several swaps in one command (the
  files of a desktop), and the style goes again after it. }
const
  WM_SDSWAPPAINT = WM_APP + $1A0;

type
  TSwapPaint = class(TUIWindowHook)
  protected
    FPending: Boolean;
    procedure Hook(var Message: TMessage); override;
  end;

{ the shown windows with a client edge into the TList Param }
function AddClientEdge(Wnd: HWND; Param: LPARAM): BOOL; stdcall;
begin
  if IsWindowVisible(Wnd) and (GetWindowLong(Wnd, GWL_EXSTYLE) and WS_EX_CLIENTEDGE <> 0) then
    TList(Param).Add(Pointer(Wnd));
  Result := True;
end;

{ The themed client edge of comctl32's controls does not survive the paint through the buffer:
  painted in it, through the window's DC, it is covered by the buffer's black when the buffer
  comes to the screen (measured: a list view in report view, which makes its frame invalid when
  it is shown - the user saw the black edge until something repainted it). Those frames are
  painted again at once after it; the windows are listed before, so that only the frames are
  painted then. }
procedure TSwapPaint.Hook(var Message: TMessage);
var
  H: HWND;
  Edges: TList;
  I: Integer;
begin
  if Message.Msg <> WM_SDSWAPPAINT then
  begin
    FOldProc(Message);
    Exit;
  end;
  FPending := False;
  H := FControl.Handle;
  Edges := TList.Create;
  try
    EnumChildWindows(H, @AddClientEdge, LPARAM(Edges));
    RedrawWindow(H, nil, 0, RDW_UPDATENOW or RDW_ALLCHILDREN);
    SetWindowLong(H, GWL_EXSTYLE, GetWindowLong(H, GWL_EXSTYLE) and not WS_EX_COMPOSITED);
    for I := 0 to Edges.Count - 1 do
      if IsWindow(HWND(Edges[I])) then SendMessage(HWND(Edges[I]), WM_NCPAINT, 1, 0);
  finally
    Edges.Free;
  end;
end;

procedure UIBeginSwap(Container: TWinControl);
begin
  if not Container.HandleAllocated or not Container.Showing then Exit;
  if UIFindHook(Container, TSwapPaint) = nil then TSwapPaint.Create(Container, True);
  SetWindowLong(Container.Handle, GWL_EXSTYLE, GetWindowLong(Container.Handle, GWL_EXSTYLE) or WS_EX_COMPOSITED);
  UIFreezeRedraw(Container, True);
end;

procedure UIEndSwap(Container: TWinControl);
var
  S: TSwapPaint;
begin
  if not Container.HandleAllocated or not Container.Showing then Exit;
  UIFreezeRedraw(Container, False, False);
  S := TSwapPaint(UIFindHook(Container, TSwapPaint));
  if (S <> nil) and not S.FPending then
  begin
    S.FPending := True;
    PostMessage(Container.Handle, WM_SDSWAPPAINT, 0, 0);
  end;
end;

{ UIEmptyView, UIEmptyPicture, UIEmptyPhoto: the hook erases nothing while the container is empty -
  the windows that went keep their pixels until the paint replaces them all at once (no bare ground
  in between). A resize repaints the whole container (the VCL's CS_HREDRAW / CS_VREDRAW), so the
  icon or the picture stays centred. }
type
  TEmptyView = class(TUIWindowHook)
  protected
    FIcon: HICON;
    FSize: Integer;
    FPicture: TSdImage;           // UIEmptyPicture's (its alpha the ink) or UIEmptyPhoto's, decoded
    FBase: TSdImage;              // the picture at its full size for the container's DPI
    FHeight, FOpacity: Integer;
    FPhoto: Boolean;              // FPicture is UIEmptyPhoto's: in its colours, over the container
    FInk: HBITMAP;                // FBase at the size and in the colour drawn - UIEmptyPhoto's
    FInkW, FInkH: Integer;        // picture at the size drawn -: premultiplied
    FInkWhite: Boolean;
    function IsEmpty: Boolean;
    procedure Clear;
    procedure DropInk;
    procedure DrawInk(DC: HDC; X, Y, W, H, SrcX, SrcY, Opacity: Integer);
    procedure PaintPicture(DC: HDC; const R: TRect);
    procedure PaintPhoto(DC: HDC; const R: TRect);
    procedure PaintTo(DC: HDC);
    procedure Hook(var Message: TMessage); override;
  public
    destructor Destroy; override;
  end;

destructor TEmptyView.Destroy;
begin
  Clear;
  inherited Destroy;
end;

procedure TEmptyView.Clear;
begin
  if FIcon <> 0 then DestroyIcon(FIcon);
  FIcon := 0;
  FreeAndNil(FPicture);
  FreeAndNil(FBase);
  FPhoto := False;
  DropInk;
end;

procedure TEmptyView.DropInk;
begin
  if FInk <> 0 then DeleteObject(FInk);
  FInk := 0;
end;

{ W x H px of FInk from SrcX, SrcY laid on DC at X, Y at Opacity per cent }
procedure TEmptyView.DrawInk(DC: HDC; X, Y, W, H, SrcX, SrcY, Opacity: Integer);
var
  InkDC: HDC;
  Old: HGDIOBJ;
  Blend: TBlendFunction;
begin
  InkDC := CreateCompatibleDC(DC);
  Old := SelectObject(InkDC, FInk);
  try
    Blend.BlendOp := AC_SRC_OVER;
    Blend.BlendFlags := 0;
    Blend.SourceConstantAlpha := (Opacity * 255 + 50) div 100;
    Blend.AlphaFormat := AC_SRC_ALPHA;
    AlphaBlend(DC, X, Y, W, H, InkDC, SrcX, SrcY, W, H, Blend);
  finally
    SelectObject(InkDC, Old);
    DeleteDC(InkDC);
  end;
end;

function TEmptyView.IsEmpty: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FControl.ControlCount - 1 do
    if FControl.Controls[I].Visible then Exit;
  Result := True;
end;

{ the picture in the middle of R: FHeight px high at 96 DPI - FBase, scaled from the decoded
  picture again when the DPI changes -; where R is small, at most MaxPart per cent of its height
  and width, in steps of Step px (a scaling takes some 10 ms: fewer of them while the container is
  resized), and left out below MinHeight px (96 DPI). FInk keeps it at the size and in the colour
  drawn, premultiplied - made again when one of them or FBase changes, and kept only once it is
  filled (a scaling that fails is tried again at the next paint) -, and AlphaBlend lays it on the
  ground at FOpacity per cent }
procedure TEmptyView.PaintPicture(DC: HDC; const R: TRect);
const
  MaxPart = 70;
  MinHeight = 100;
  Step = 8;
var
  Dpi, W, H, Fit, ByWidth, I: Integer;
  White: Boolean;
  Scaled, Src: TSdImage;
  Ink: HBITMAP;
  Bits: PCardinal;
  A: Cardinal;
begin
  Dpi := GetControlDpi(FControl);
  H := MulDiv(FHeight, Dpi, 96);
  if H <= 0 then Exit;
  if (FBase = nil) or (FBase.Height <> H) then
  begin
    FreeAndNil(FBase);
    DropInk;
    FBase := ScaleImage(FPicture, MulDiv(H, FPicture.Width, FPicture.Height), H, True);
  end;
  W := FBase.Width;
  if W <= 0 then Exit;
  Fit := R.Bottom * MaxPart div 100;
  ByWidth := MulDiv(R.Right * MaxPart div 100, H, W);     // the height that the width allows
  if ByWidth < Fit then Fit := ByWidth;
  if Fit < H then
  begin
    H := Fit - Fit mod Step;
    W := MulDiv(H, FBase.Width, FBase.Height);
  end;
  if (W <= 0) or (H < MulDiv(MinHeight, Dpi, 96)) then Exit;
  White := UIIsDark(TControlAccess(FControl).Color);
  if (FInk = 0) or (W <> FInkW) or (H <> FInkH) or (White <> FInkWhite) then
  begin
    DropInk;
    if (W = FBase.Width) and (H = FBase.Height) then Scaled := nil
    else Scaled := ScaleImage(FBase, W, H, True);
    try
      if Scaled <> nil then Src := Scaled else Src := FBase;
      Ink := UICreateDib32(W, H, Bits);
      if Ink = 0 then Exit;
      for I := 0 to W * H - 1 do
      begin
        A := Src.Pixels[I] shr 24;
        if White then Bits^ := A shl 24 or A shl 16 or A shl 8 or A
        else Bits^ := A shl 24;
        Inc(Bits);
      end;
      FInk := Ink;
      FInkW := W;
      FInkH := H;
      FInkWhite := White;
    finally
      Scaled.Free;
    end;
  end;
  DrawInk(DC, (R.Right - W) div 2, (R.Bottom - H) div 2, W, H, 0, 0, FOpacity);
end;

{ UIEmptyPhoto's picture over the whole of R: as large as covering R needs, what overflows cut
  equally at two opposite sides, in its colours. FInk keeps it at that size, premultiplied - made again when
  R's size changes (a resize, another DPI) }
procedure TEmptyView.PaintPhoto(DC: HDC; const R: TRect);
var
  W, H, I: Integer;
  Scaled: TSdImage;
  Ink: HBITMAP;
  Bits: PCardinal;
  P, A: Cardinal;
begin
  W := R.Right;
  H := MulDiv(W, FPicture.Height, FPicture.Width);
  if H < R.Bottom then
  begin
    H := R.Bottom;
    W := MulDiv(H, FPicture.Width, FPicture.Height);
  end;
  if (W <= 0) or (H <= 0) then Exit;
  if (FInk = 0) or (W <> FInkW) or (H <> FInkH) then
  begin
    DropInk;
    Scaled := ScaleImage(FPicture, W, H, True);
    try
      Ink := UICreateDib32(W, H, Bits);
      if Ink = 0 then Exit;
      for I := 0 to W * H - 1 do
      begin
        P := Scaled.Pixels[I];
        A := P shr 24;
        if A < 255 then
          P := A shl 24 or ((P shr 16 and $FF) * A div 255) shl 16 or
            ((P shr 8 and $FF) * A div 255) shl 8 or (P and $FF) * A div 255;
        Bits^ := P;
        Inc(Bits);
      end;
      FInk := Ink;
      FInkW := W;
      FInkH := H;
    finally
      Scaled.Free;
    end;
  end;
  DrawInk(DC, 0, 0, R.Right, R.Bottom, (W - R.Right) div 2, (H - R.Bottom) div 2, 100);
end;

procedure TEmptyView.PaintTo(DC: HDC);
const
  Margin = 8;
var
  R: TRect;
  MemDC: HDC;
  Bmp, OldBmp: HBITMAP;
  S: Integer;
begin
  Windows.GetClientRect(FControl.Handle, R);
  if (R.Right <= 0) or (R.Bottom <= 0) then Exit;
  MemDC := CreateCompatibleDC(DC);
  Bmp := CreateCompatibleBitmap(DC, R.Right, R.Bottom);
  OldBmp := SelectObject(MemDC, Bmp);
  try
    UIFill(MemDC, R, TControlAccess(FControl).Color);
    if not FPhoto then UIDrawBorder(MemDC, R);
    if FPicture <> nil then
    begin
      if FPhoto then PaintPhoto(MemDC, R) else PaintPicture(MemDC, R);
    end
    else
    begin
      S := FSize;
      while (S > 16) and ((S + 2 * Margin > R.Right) or (S + 2 * Margin > R.Bottom)) do S := S div 2;
      if (FIcon <> 0) and (S + 2 * Margin <= R.Right) and (S + 2 * Margin <= R.Bottom) then
        DrawIconEx(MemDC, (R.Right - S) div 2, (R.Bottom - S) div 2, FIcon, S, S, 0, 0, DI_NORMAL);
    end;
    BitBlt(DC, 0, 0, R.Right, R.Bottom, MemDC, 0, 0, SRCCOPY);
  finally
    SelectObject(MemDC, OldBmp);
    DeleteObject(Bmp);
    DeleteDC(MemDC);
  end;
end;

procedure TEmptyView.Hook(var Message: TMessage);
var
  PS: TPaintStruct;
  DC: HDC;
begin
  if ((Message.Msg = WM_ERASEBKGND) or (Message.Msg = WM_PAINT)) and IsEmpty then
  begin
    Message.Result := 1;
    if Message.Msg = WM_PAINT then
    begin
      Message.Result := 0;
      if Message.WParam <> 0 then
        PaintTo(HDC(Message.WParam))
      else
      begin
        DC := BeginPaint(FControl.Handle, PS);
        try
          PaintTo(DC);
        finally
          EndPaint(FControl.Handle, PS);
        end;
      end;
    end;
    Exit;
  end;
  FOldProc(Message);
end;

{ the container's empty view - made when it has none -, without an icon or a picture }
function EmptyViewOf(Container: TWinControl): TEmptyView;
begin
  Result := TEmptyView(UIFindHook(Container, TEmptyView));
  if Result = nil then Result := TEmptyView.Create(Container, True);
  Result.Clear;
end;

procedure UIEmptyView(Container: TWinControl; const IconName: string; Size: Integer);
var
  V: TEmptyView;
begin
  V := EmptyViewOf(Container);
  V.FSize := Size;
  V.FIcon := LoadImage(HInstance, PChar(IconName), IMAGE_ICON, Size, Size, LR_DEFAULTCOLOR);
  if Container.HandleAllocated then InvalidateRect(Container.Handle, nil, False);
end;

{ the view's picture from the program's RCDATA resource PictureName - none when it is missing, GDI+
  cannot read it or it is empty -, and the container painted again }
procedure LoadEmptyPicture(V: TEmptyView; Container: TWinControl; const PictureName: string);
var
  Res: HRSRC;
  Data: string;
begin
  Res := FindResource(HInstance, PChar(PictureName), RT_RCDATA);
  if Res <> 0 then
  begin
    SetString(Data, PChar(LockResource(LoadResource(HInstance, Res))), SizeofResource(HInstance, Res));
    try
      V.FPicture := PictureToImage(Data);
    except
      on EResImage do ;              // no GDI+, or nothing it reads: the view without its picture
    end;
    if (V.FPicture <> nil) and ((V.FPicture.Width = 0) or (V.FPicture.Height = 0)) then
      FreeAndNil(V.FPicture);
  end;
  if Container.HandleAllocated then InvalidateRect(Container.Handle, nil, False);
end;

procedure UIEmptyPicture(Container: TWinControl; const PictureName: string; Height, Opacity: Integer);
var
  V: TEmptyView;
begin
  V := EmptyViewOf(Container);
  if Opacity < 0 then Opacity := 0
  else if Opacity > 100 then Opacity := 100;
  V.FHeight := Height;
  V.FOpacity := Opacity;
  LoadEmptyPicture(V, Container, PictureName);
end;

procedure UIEmptyPhoto(Container: TWinControl; const PictureName: string);
var
  V: TEmptyView;
begin
  V := EmptyViewOf(Container);
  V.FPhoto := True;
  LoadEmptyPicture(V, Container, PictureName);
end;

procedure UIDrawToolSeparator(DC: HDC; const R: TRect);
const
  SeparatorWidth = 8;               // a TToolButton separator's
var
  S: TRect;
begin
  if not ThemeServices.ThemesEnabled then Exit;
  S := R;
  S.Left := R.Left + (R.Right - R.Left - SeparatorWidth) div 2;
  S.Right := S.Left + SeparatorWidth;
  ThemeServices.DrawElement(DC, ThemeServices.GetElementDetails(ttbSeparatorNormal), S);
end;

procedure UIFill(DC: HDC; const R: TRect; Color: TColor);
var
  Old: COLORREF;
begin
  Old := SetBkColor(DC, ColorToRGB(Color));
  ExtTextOut(DC, 0, 0, ETO_OPAQUE, @R, nil, 0, nil);
  SetBkColor(DC, Old);
end;

{ a 1 px frame (the expand box) }
procedure UIFrame(DC: HDC; const R: TRect; Color: TColor);
begin
  UIFill(DC, Rect(R.Left, R.Top, R.Right, R.Top + 1), Color);
  UIFill(DC, Rect(R.Left, R.Bottom - 1, R.Right, R.Bottom), Color);
  UIFill(DC, Rect(R.Left, R.Top, R.Left + 1, R.Bottom), Color);
  UIFill(DC, Rect(R.Right - 1, R.Top, R.Right, R.Bottom), Color);
end;

procedure UIHLine(DC: HDC; X1, X2, Y: Integer; Color: TColor);
begin
  UIFill(DC, Rect(X1, Y, X2, Y + 1), Color);
end;

procedure UIVLine(DC: HDC; X, Y1, Y2: Integer; Color: TColor);
begin
  UIFill(DC, Rect(X, Y1, X + 1, Y2), Color);
end;

procedure UIDottedHLine(DC: HDC; X1, X2, Y: Integer; Color: TColor; FromStart: Boolean);
var
  X: Integer;
  C: COLORREF;
begin
  C := ColorToRGB(Color);
  X := X1;
  if not FromStart then Inc(X, X1 and 1);
  while X < X2 do
  begin
    SetPixelV(DC, X, Y, C);
    Inc(X, 2);
  end;
end;

procedure UIDottedVLine(DC: HDC; X, Y1, Y2: Integer; Color: TColor; FromStart: Boolean);
var
  Y: Integer;
  C: COLORREF;
begin
  C := ColorToRGB(Color);
  Y := Y1;
  if not FromStart then Inc(Y, Y1 and 1);
  while Y < Y2 do
  begin
    SetPixelV(DC, X, Y, C);
    Inc(Y, 2);
  end;
end;

procedure UIText(DC: HDC; const S: string; var R: TRect; Flags: Cardinal; Color: TColor);
begin
  { explicitly in the system code page: Delphi's own string -> WideString conversion uses the code
    page of the user's locale, which can differ }
  UITextW(DC, ToWide(S, CP_ACP), R, Flags, Color);
end;

procedure UITextW(DC: HDC; const W: WideString; var R: TRect; Flags: Cardinal; Color: TColor);
var
  OldC: COLORREF;
  OldM: Integer;
begin
  OldC := SetTextColor(DC, ColorToRGB(Color));
  OldM := SetBkMode(DC, TRANSPARENT);
  DrawTextW(DC, PWideChar(W), Length(W), R, Flags);
  SetBkMode(DC, OldM);
  SetTextColor(DC, OldC);
end;

function UITextWidth(DC: HDC; const S: string): Integer;
var
  Sz: TSize;
begin
  if S = '' then
    Result := 0
  else
  begin
    GetTextExtentPoint32(DC, PChar(S), Length(S), Sz);
    Result := Sz.cx;
  end;
end;

function UIBufferDC(var Buffer: TBitmap; Control: TControl): HDC;
begin
  if Buffer = nil then Buffer := TBitmap.Create;
  if (Buffer.Width <> Control.Width) or (Buffer.Height <> Control.Height) then
  begin
    Buffer.Width := Control.Width;
    Buffer.Height := Control.Height;
  end;
  Result := Buffer.Canvas.Handle;
end;

procedure UIBufferFlush(Buffer: TBitmap; Canvas: TCanvas);
var
  Clip: TRect;
begin
  Clip := Canvas.ClipRect;
  BitBlt(Canvas.Handle, Clip.Left, Clip.Top, Clip.Right - Clip.Left, Clip.Bottom - Clip.Top,
    Buffer.Canvas.Handle, Clip.Left, Clip.Top, SRCCOPY);
end;

function UICreateDib32(Width, Height: Integer; out Bits: PCardinal): HBITMAP;
var
  BI: TBitmapInfo;
  P: Pointer;
begin
  FillChar(BI, SizeOf(BI), 0);
  BI.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  BI.bmiHeader.biWidth := Width;
  BI.bmiHeader.biHeight := -Height;                 // negative: top-down
  BI.bmiHeader.biPlanes := 1;
  BI.bmiHeader.biBitCount := 32;
  BI.bmiHeader.biCompression := BI_RGB;
  P := nil;
  Result := CreateDIBSection(0, BI, DIB_RGB_COLORS, P, 0, 0);
  if Result = 0 then P := nil;
  Bits := P;
end;

{ --- TSdControl, TSdPopupList --- }

destructor TSdControl.Destroy;
begin
  FBuffer.Free;
  inherited Destroy;
end;

procedure TSdControl.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  if not FRedrawWhole then
    with Params.WindowClass do style := style and not (CS_HREDRAW or CS_VREDRAW);
end;

procedure TSdControl.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  EraseGround(Message.DC);
  Message.Result := 1;
end;

procedure TSdControl.EraseGround(DC: HDC);
begin
end;

procedure TSdControl.Paint;
begin
  if not FBuffered then Exit;
  UIBufferDC(FBuffer, Self);
  PaintBuffer(FBuffer.Canvas);
  UIBufferFlush(FBuffer, Canvas);
end;

procedure TSdControl.PaintBuffer(C: TCanvas);
begin
end;

{ TSdScrollControl }

procedure TSdScrollControl.UpdateScrollBars;
var
  Size: TPoint;

  procedure Clamp;
  begin
    if FOrigin.X > Size.X - ClientWidth then FOrigin.X := Size.X - ClientWidth;
    if FOrigin.X < 0 then FOrigin.X := 0;
    if FOrigin.Y > Size.Y - ClientHeight then FOrigin.Y := Size.Y - ClientHeight;
    if FOrigin.Y < 0 then FOrigin.Y := 0;
  end;

begin
  if not HandleAllocated or FBarsBusy then Exit;
  FBarsBusy := True;
  try
    Size := ContentSize;
    Clamp;
    UISetScrollBar(Handle, SB_HORZ, Size.X, ClientWidth, FOrigin.X);
    UISetScrollBar(Handle, SB_VERT, Size.Y, ClientHeight, FOrigin.Y);
    { a bar that came or went changed the client: the positions again }
    Clamp;
  finally
    FBarsBusy := False;
  end;
end;

procedure TSdScrollControl.ScrollTo(X, Y: Integer);
begin
  if (X = FOrigin.X) and (Y = FOrigin.Y) then Exit;
  FOrigin := Point(X, Y);
  UpdateScrollBars;
  Invalidate;
end;

procedure TSdScrollControl.WMHScroll(var Message: TWMHScroll);
var
  P: TPoint;
begin
  P := UIScrollOrigin(Self, SB_HORZ, Message.ScrollCode, FOrigin, LineSize);
  ScrollTo(P.X, P.Y);
end;

procedure TSdScrollControl.WMVScroll(var Message: TWMVScroll);
var
  P: TPoint;
begin
  P := UIScrollOrigin(Self, SB_VERT, Message.ScrollCode, FOrigin, LineSize);
  ScrollTo(P.X, P.Y);
end;

constructor TSdPopupList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Visible := False;
  Ctl3D := False;
  ParentCtl3D := False;
  TabStop := False;
  IntegralHeight := False;
  BorderStyle := bsNone;
  UINoListTracking(Self);
end;

procedure TSdPopupList.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  with Params do
  begin
    Style := Style or WS_BORDER;
    ExStyle := WS_EX_TOOLWINDOW or WS_EX_TOPMOST;
    { CS_DBLCLKS stays: a double click chooses in the completion list }
    WindowClass.Style := WindowClass.Style and not (CS_HREDRAW or CS_VREDRAW) or CS_SAVEBITS;
  end;
end;

procedure TSdPopupList.CreateWnd;
begin
  inherited CreateWnd;
  Windows.SetParent(Handle, 0);
  CallWindowProc(DefWndProc, Handle, WM_SETFOCUS, 0, 0);
end;

procedure TSdPopupList.WMMouseActivate(var Message: TWMMouseActivate);
begin
  Message.Result := MA_NOACTIVATE;
end;

procedure TSdPopupList.ShowAt(X, Y, W, H: Integer);
begin
  SetWindowPos(Handle, HWND_TOPMOST, X, Y, W, H, SWP_NOACTIVATE or SWP_SHOWWINDOW);
end;

procedure TSdPopupList.HideList;
begin
  if HandleAllocated then
    SetWindowPos(Handle, 0, 0, 0, 0, 0, SWP_NOZORDER or SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or
      SWP_HIDEWINDOW);
end;

var
  { the title bars' colours as UITitleColors last read them from the registry (TitleRead), and
    when: the captions and the chosen tabs paint many times a second while the dock is resized }
  TitleRead: Boolean;
  TitleReadTick: Cardinal;
  TitleBack, TitleFore: TColor;

const
  TitleKeepMs = 500;          // the colours read are used again for so long

{ The colours of the title bars of Windows: the accent colour when Settings show it on title bars
  (DWM ColorPrevalence = 1, AccentColor: $AABBGGRR - a TColor in its low three bytes), else
  white; the text white on a dark bar, black on a light one. Read again when TitleKeepMs have
  passed since the last reading, and at once after a change of the colours (TMenuLook: the main
  window's WM_SETTINGCHANGE, WM_DWMCOLORIZATIONCOLORCHANGED ...): a caption that repaints shows a
  colour the user has just changed. }
procedure UITitleColors(out Back, Fore: TColor; Active: Boolean);
var
  K: HKEY;
  Prevalence, Accent, Size: DWORD;
  Ok: Boolean;
begin
  if not Active then
  begin
    Back := UIBlend(clBtnShadow, clBtnFace, 25);
    Fore := clBtnText;
    Exit;
  end;
  if TitleRead and (GetTickCount - TitleReadTick < TitleKeepMs) then
  begin
    Back := TitleBack;
    Fore := TitleFore;
    Exit;
  end;
  Ok := False;
  if RegOpenKeyEx(HKEY_CURRENT_USER, 'Software\Microsoft\Windows\DWM', 0, KEY_READ, K) = ERROR_SUCCESS then
  try
    Size := SizeOf(DWORD);
    if (RegQueryValueEx(K, 'ColorPrevalence', nil, nil, PByte(@Prevalence), @Size) = ERROR_SUCCESS) and
      (Prevalence <> 0) then
    begin
      Size := SizeOf(DWORD);
      Ok := RegQueryValueEx(K, 'AccentColor', nil, nil, PByte(@Accent), @Size) = ERROR_SUCCESS;
    end;
  finally
    RegCloseKey(K);
  end;
  if Ok then Back := TColor(Accent and $FFFFFF) else Back := clWindow;
  if UIIsDark(Back) then Fore := clWhite else Fore := clBlack;
  TitleBack := Back;
  TitleFore := Fore;
  TitleReadTick := GetTickCount;
  TitleRead := True;
end;

const
  CaptionMargin = 2;          // the face colour between a docked view's title bar and the view
  CloseRed = $005050C7;       // the close button of Windows' tool windows (Delphi 7's floating
  CloseRedHot = $004343E0;    // views show it): #C75050, under the pointer #E04343, pressed
  CloseRedDown = $003D3D99;   // #993D3D
  TabCloseGap = 3;            // between a tab's close box and the tab's end

{ the title bar (the text with 3 px above and below it) and the margin below it }
function UIPaneCaptionHeight: Integer;
begin
  Result := UITextHeight + 6 + CaptionMargin;
end;

{ A close box: on a caption (Solid) always in the red of the close button of a tool window, on a
  tab only while the pointer is over it or it is pressed; in its middle the cross of that button
  - 5 x 5 px, each arm 2 px wide but the centre pixel; a third of the box with a large UI font -
  white on red, else in the text colour. }
procedure UIDrawCloseBox(DC: HDC; const R: TRect; State: TUIButtonState; Solid: Boolean);
var
  N, C, X0, Y0, Y, D: Integer;
  Color: TColor;
begin
  Color := clBtnText;
  if Solid or (State in [bsHot, bsDown]) then
  begin
    case State of
      bsHot: UIFill(DC, R, CloseRedHot);
      bsDown: UIFill(DC, R, CloseRedDown);
    else
      UIFill(DC, R, CloseRed);
    end;
    Color := clWhite;
  end;
  N := (R.Bottom - R.Top) div 3;
  if not Odd(N) then Inc(N);
  if N < 5 then N := 5;
  C := N div 2;
  X0 := R.Left + (R.Right - R.Left - N) div 2;
  Y0 := R.Top + (R.Bottom - R.Top - N) div 2;
  for Y := 0 to N - 1 do
  begin
    D := Abs(Y - C);
    if D = 0 then
      UIFill(DC, Rect(X0 + C, Y0 + Y, X0 + C + 1, Y0 + Y + 1), Color)
    else
    begin
      UIFill(DC, Rect(X0 + C - D, Y0 + Y, X0 + C - D + 2, Y0 + Y + 1), Color);
      UIFill(DC, Rect(X0 + C + D - 1, Y0 + Y, X0 + C + D + 1, Y0 + Y + 1), Color);
    end;
  end;
end;

{ The buttons at the right end of a caption's bar, squares 4 px less than the bar, 2 px from its
  top and right end, 1 px apart: the close box last, the pin before it. }
function UIPaneCaptionButton(const R: TRect; Index: Integer): TRect;
var
  S: Integer;
begin
  S := R.Bottom - CaptionMargin - R.Top - 4;
  Result := Rect(R.Right - S - 2, R.Top + 2, R.Right - 2, R.Top + 2 + S);
  if Index = 0 then OffsetRect(Result, -(S + 1), 0);
end;

{ The pin of a caption, in the bar's text colour (a shade of it behind the glyph under the
  pointer, a deeper one pressed): pinned it stands, the point down; unpinned (the group hides at
  the edge) it lies, the point to the left - as Visual Studio draws it. 9 x 9: a head with a
  thick side, a collar, the needle. }
procedure DrawPin(DC: HDC; const R: TRect; Pinned: Boolean; State: TUIButtonState; Back, Fore: TColor);
var
  X, Y: Integer;
begin
  if State = bsHot then UIFill(DC, R, UIBlend(Fore, Back, 25))
  else if State = bsDown then UIFill(DC, R, UIBlend(Fore, Back, 45));
  X := R.Left + (R.Right - R.Left - 9) div 2;
  Y := R.Top + (R.Bottom - R.Top - 9) div 2;
  if Pinned then
  begin
    UIFill(DC, Rect(X + 2, Y, X + 7, Y + 1), Fore);         // head
    UIFill(DC, Rect(X + 2, Y, X + 3, Y + 4), Fore);
    UIFill(DC, Rect(X + 5, Y, X + 7, Y + 4), Fore);
    UIFill(DC, Rect(X + 1, Y + 4, X + 8, Y + 5), Fore);     // collar
    UIFill(DC, Rect(X + 4, Y + 5, X + 5, Y + 9), Fore);     // needle
  end
  else
  begin
    UIFill(DC, Rect(X + 5, Y + 2, X + 9, Y + 3), Fore);     // head
    UIFill(DC, Rect(X + 8, Y + 2, X + 9, Y + 7), Fore);
    UIFill(DC, Rect(X + 5, Y + 5, X + 9, Y + 7), Fore);
    UIFill(DC, Rect(X + 4, Y + 1, X + 5, Y + 8), Fore);     // collar
    UIFill(DC, Rect(X, Y + 4, X + 4, Y + 5), Fore);         // needle
  end;
end;

{ The caption of a docked view: a bar in the colour of Windows' title bars, the title in the UI
  font 5 px from its left end, the pin and the close box at its right end; the margin below it. }
procedure UIDrawPaneCaption(DC: HDC; const R: TRect; const Text: string; Pinned: Boolean;
  PinState, CloseState: TUIButtonState; Active: Boolean; ShowPin: Boolean);
var
  Bar, TR, PinRect: TRect;
  Old: HFONT;
  Back, Fore: TColor;
begin
  if UIFont = nil then SetupFonts;
  UITitleColors(Back, Fore, Active);
  Bar := Rect(R.Left, R.Top, R.Right, R.Bottom - CaptionMargin);
  UIFill(DC, Bar, Back);
  UIFill(DC, Rect(R.Left, Bar.Bottom, R.Right, R.Bottom), clBtnFace);
  if ShowPin then
  begin
    PinRect := UIPaneCaptionButton(R, 0);
    DrawPin(DC, PinRect, Pinned, PinState, Back, Fore);
  end
  else
    PinRect := UIPaneCaptionButton(R, 1);       // the title runs up to the close box
  UIDrawCloseBox(DC, UIPaneCaptionButton(R, 1), CloseState, True);
  TR := Bar;
  Inc(TR.Left, 5);
  TR.Right := PinRect.Left - 2;
  Old := SelectObject(DC, UIFont.Handle);
  UIText(DC, Text, TR, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX or DT_END_ELLIPSIS, Fore);
  SelectObject(DC, Old);
end;

{ the side of a tab's close box (13 px with Segoe UI 9) }
function TabCloseSize: Integer;
begin
  Result := UITextHeight - 2;
end;

function UITabCloseRoom: Integer;
begin
  Result := TabCloseSize;
end;

{ The close box of a file tab drawn in R (a tab above its pages; the dock's tabs have none):
  TabCloseGap from its right end, centred from top to bottom. }
function UITabCloseRect(const R: TRect): TRect;
var
  S, A, B: Integer;
begin
  S := TabCloseSize;
  A := R.Right - R.Left - TabCloseGap - S;
  B := (R.Bottom - R.Top - S) div 2;
  Result := Rect(R.Left + A, R.Top + B, R.Left + A + S, R.Top + B + S);
end;

{ a colour between A and B: Percent of A }
function UIBlend(A, B: TColor; Percent: Integer): TColor;
var
  CA, CB: COLORREF;
begin
  CA := ColorToRGB(A);
  CB := ColorToRGB(B);
  Result := RGB((GetRValue(CA) * Percent + GetRValue(CB) * (100 - Percent)) div 100,
    (GetGValue(CA) * Percent + GetGValue(CB) * (100 - Percent)) div 100,
    (GetBValue(CA) * Percent + GetBValue(CB) * (100 - Percent)) div 100);
end;

function UILuma(Color: TColor): Integer;
var
  C: COLORREF;
begin
  C := ColorToRGB(Color);
  Result := (GetRValue(C) * 299 + GetGValue(C) * 587 + GetBValue(C) * 114) div 1000;
end;

function UIIsDark(Color: TColor): Boolean;
begin
  Result := UILuma(Color) < 128;
end;

{ The title of a tab beside its view is drawn level and turned: in a bitmap kept between tabs and
  paints (grown to the largest tab; its memory DC with it), in the UI font without ClearType -
  made again when the UI font is another. }
var
  TurnDC: HDC;
  TurnBmp, TurnOldBmp: HBITMAP;
  TurnW, TurnH: Integer;
  TurnFont: HFONT;
  TurnLF: TLogFont;

{ the memory DC with a bitmap of at least W x H, compatible with DC }
function TurnSurface(DC: HDC; W, H: Integer): HDC;
begin
  if (TurnDC = 0) or (W > TurnW) or (H > TurnH) then
  begin
    if W < TurnW then W := TurnW;
    if H < TurnH then H := TurnH;
    if TurnDC = 0 then
      TurnDC := CreateCompatibleDC(DC)
    else
    begin
      SelectObject(TurnDC, TurnOldBmp);
      DeleteObject(TurnBmp);
    end;
    TurnBmp := CreateCompatibleBitmap(DC, W, H);
    TurnOldBmp := SelectObject(TurnDC, TurnBmp);
    TurnW := W;
    TurnH := H;
  end;
  Result := TurnDC;
end;

function TurnedFont: HFONT;
var
  LF: TLogFont;
begin
  FillChar(LF, SizeOf(LF), 0);
  GetObject(UIFont.Handle, SizeOf(LF), @LF);
  LF.lfQuality := ANTIALIASED_QUALITY;
  if (TurnFont = 0) or not CompareMem(@LF, @TurnLF, SizeOf(LF)) then
  begin
    if TurnFont <> 0 then DeleteObject(TurnFont);
    TurnFont := CreateFontIndirect(LF);
    TurnLF := LF;
  end;
  Result := TurnFont;
end;

procedure FreeTurnCache;
begin
  if TurnDC <> 0 then
  begin
    SelectObject(TurnDC, TurnOldBmp);
    DeleteObject(TurnBmp);
    DeleteDC(TurnDC);
    TurnDC := 0;
  end;
  if TurnFont <> 0 then DeleteObject(TurnFont);
  TurnFont := 0;
end;

{ A tab - of the dock's groups, the Code / Design tabs, the inspector's, the file tabs:
  flat. The tab chosen (bsChecked) has the window colour, joining
  its view, and a 2 px bar in the colour of Windows' title bars (as the docked views' captions)
  along its outer edge; the others the face colour - a shade darker under the pointer (bsHot) -
  and a dimmed title. The title in the UI font, centred; on a strip left of its view it reads
  upwards, right of it downwards. CloseBox (the file tabs, above their pages): the tab ends in a
  close box (UITabCloseRect, its own state CloseState) and the title is centred in the rest.
  Images[ImageIndex] (when given): an icon before the title, both centred together and turned
  with it; a tab too short cuts the title (its ellipsis), not the icon. TextColor (when not
  clNone): the title's colour in every state, in place of the state's. }
procedure UIDrawTab(DC: HDC; const R: TRect; const Text: WideString; State: TUIButtonState;
  Side: TUITabSide; CloseBox: Boolean = False; CloseState: TUIButtonState = bsNormal;
  Images: TCustomImageList = nil; ImageIndex: Integer = -1; TextColor: TColor = clNone);
const
  FLAGS = DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX or DT_END_ELLIPSIS;
  BarWidth = 2;
var
  L, T: Integer;                    // the tab along the strip, across it
  TextEnd: Integer;                 // where its title ends along it (as the tab reads)
  Back, Fore, Bar, TitleText: TColor;
  BR, TR: TRect;
  MemDC: HDC;
  Old: HFONT;
  P: array[0..2] of TPoint;

  { the title in Box of D (level), with the icon before it }
  procedure Title(D: HDC; Box: TRect);
  var
    Room, TW, X: Integer;
    Sz: TSize;
  begin
    Room := UITabImageRoom(Images, ImageIndex);
    if Room = 0 then
    begin
      UITextW(D, Text, Box, FLAGS, Fore);
      Exit;
    end;
    TW := 0;
    if (Text <> '') and GetTextExtentPoint32W(D, PWideChar(Text), Length(Text), Sz) then TW := Sz.cx;
    if TW > Box.Right - Box.Left - Room then TW := Box.Right - Box.Left - Room;
    if TW < 0 then TW := 0;
    X := Box.Left + (Box.Right - Box.Left - Room - TW) div 2;
    ImageList_DrawEx(Images.Handle, ImageIndex, D, X, Box.Top + (Box.Bottom - Box.Top - Images.Height) div 2,
      0, 0, CLR_NONE, CLR_NONE, ILD_TRANSPARENT);
    Box := Rect(X + Room, Box.Top, X + Room + TW, Box.Bottom);
    UITextW(D, Text, Box, FLAGS and not DT_CENTER, Fore);
  end;

begin
  if UIFont = nil then SetupFonts;
  if Side in [tsLeft, tsRight] then
  begin
    L := R.Bottom - R.Top;
    T := R.Right - R.Left;
  end
  else
  begin
    L := R.Right - R.Left;
    T := R.Bottom - R.Top;
  end;
  if (L <= 0) or (T <= 0) then Exit;
  TextEnd := L - 4;
  if CloseBox then TextEnd := L - TabCloseGap - TabCloseSize - 2;
  case State of
    bsChecked:
      begin
        Back := clWindow;
        Fore := clWindowText;
      end;
    bsHot:
      begin
        Back := UIBlend(clBtnFace, clBtnShadow, 80);
        Fore := clBtnText;
      end;
  else
    Back := clBtnFace;
    Fore := UIBlend(clBtnText, clBtnFace, 70);
  end;
  if TextColor <> clNone then Fore := TextColor;
  if Side in [tsTop, tsBottom] then
  begin
    UIFill(DC, R, Back);
    TR := Rect(R.Left + 4, R.Top, R.Left + TextEnd, R.Bottom);
    Old := SelectObject(DC, UIFont.Handle);
    Title(DC, TR);
    SelectObject(DC, Old);
  end
  else
  begin
    { the title turned: drawn level in a bitmap of the tab's colour, without ClearType (its
      colour fringes would lie across the turned glyphs), then turned into place }
    MemDC := TurnSurface(DC, L, T);
    UIFill(MemDC, Rect(0, 0, L, T), Back);
    Old := SelectObject(MemDC, TurnedFont);
    TR := Rect(4, 0, TextEnd, T);
    Title(MemDC, TR);
    SelectObject(MemDC, Old);
    if Side = tsLeft then
    begin
      { a quarter turn to the left: the title reads upwards }
      P[0] := Point(R.Left, R.Bottom);
      P[1] := Point(R.Left, R.Top);
      P[2] := Point(R.Right, R.Bottom);
    end
    else
    begin
      P[0] := Point(R.Right, R.Top);
      P[1] := Point(R.Right, R.Bottom);
      P[2] := Point(R.Left, R.Top);
    end;
    PlgBlt(DC, P, MemDC, 0, 0, L, T, 0, 0, 0);
  end;
  if State = bsChecked then
  begin
    UITitleColors(Bar, TitleText);
    if ColorToRGB(Bar) = ColorToRGB(clWindow) then Bar := clHighlight;   // white title bars
    case Side of
      tsTop: BR := Rect(R.Left, R.Top, R.Right, R.Top + BarWidth);
      tsBottom: BR := Rect(R.Left, R.Bottom - BarWidth, R.Right, R.Bottom);
      tsLeft: BR := Rect(R.Left, R.Top, R.Left + BarWidth, R.Bottom);
    else
      BR := Rect(R.Right - BarWidth, R.Top, R.Right, R.Bottom);
    end;
    UIFill(DC, BR, Bar);
  end;
  if CloseBox then UIDrawCloseBox(DC, UITabCloseRect(R), CloseState, False);
end;

{ the icon and a 4 px gap before the title }
function UITabImageRoom(Images: TCustomImageList; ImageIndex: Integer): Integer;
begin
  if (Images <> nil) and (ImageIndex >= 0) and (ImageIndex < Images.Count) then Result := Images.Width + 4
  else Result := 0;
end;

{ a strip of tabs: text height + 6 (21 with Segoe UI 9) }
function UIDockTabHeight: Integer;
begin
  Result := UITextHeight + 6;
end;

{ A component as Delphi 7 shows a non-visual one on a form (measured from a screenshot): a
  clBtnFace tile with a 1 px raised bevel - the top line the full width, the left one stopping
  above the bottom line, the bottom line the full width, the right one starting below the top
  line - and the 24 x 24 bitmap at (2, 2). Also the rows of the Components view's classic look. }
procedure UIDrawComponentTile(DC: HDC; const R: TRect; Bmp: TBitmap);
var
  C: TCanvas;
  Saved: Integer;
begin
  UIFill(DC, R, clBtnFace);
  UIHLine(DC, R.Left, R.Right, R.Top, clBtnHighlight);
  UIVLine(DC, R.Left, R.Top, R.Bottom - 1, clBtnHighlight);
  UIVLine(DC, R.Right - 1, R.Top + 1, R.Bottom, clBtnShadow);
  UIHLine(DC, R.Left, R.Right, R.Bottom - 1, clBtnShadow);
  if Bmp = nil then Exit;
  { a canvas lent the DC selects the stock objects into it when it lets go: the caller's font and
    brush (a list box's canvas) come back with RestoreDC }
  Saved := SaveDC(DC);
  C := TCanvas.Create;
  try
    C.Handle := DC;
    C.Draw(R.Left + 2, R.Top + 2, Bmp);
  finally
    C.Handle := 0;
    C.Free;
    RestoreDC(DC, Saved);
  end;
end;

{ The expand box of the Delphi 7 Object Inspector: a black 9 x 9 frame on white with a 5 px
  plus or minus. Delphi draws it itself: it is not an element of the visual style. }
procedure UIDrawExpandBox(DC: HDC; X, Y: Integer; Expanded: Boolean; Size: Integer);
var
  R: TRect;
  M: Integer;
begin
  Size := Size or 1;               // odd: the glyph has a middle pixel
  M := Size div 2;
  R := Rect(X, Y, X + Size, Y + Size);
  UIFill(DC, R, clWindow);
  UIFrame(DC, R, clBtnText);
  UIHLine(DC, X + 2, X + Size - 2, Y + M, clBtnText);
  if not Expanded then UIVLine(DC, X + M, Y + 2, Y + Size - 2, clBtnText);
end;

const
  { the visual style's glyph of a tree view's item under the pointer (Vista) }
  TVP_HOTGLYPH = 4;
  HGLPS_CLOSED = 1;
  HGLPS_OPENED = 2;

var
  TreeTheme: HTHEME;                 // Explorer's tree view: the glyphs
  TreeThemeOpened: Boolean;
  TreeInk: TRect;                    // where the open glyph's pixels lie in its part ...
  TreeInkSize: Integer;              // ... of this side; 0: not measured

function TreeGlyphTheme: HTHEME;
begin
  if not TreeThemeOpened and Assigned(OpenThemeData) then
  begin
    TreeThemeOpened := True;
    TreeTheme := OpenThemeData(0, 'Explorer::TreeView');
    if TreeTheme = 0 then TreeTheme := OpenThemeData(0, 'TreeView');
  end;
  Result := TreeTheme;
end;

procedure UICloseTreeTheme;
begin
  if (TreeTheme <> 0) and Assigned(CloseThemeData) then CloseThemeData(TreeTheme);
  TreeTheme := 0;
  TreeThemeOpened := False;
  TreeInkSize := 0;
end;

function UITreeGlyphSize(DC: HDC): Integer;
var
  S: TSize;
begin
  Result := 9;
  if (TreeGlyphTheme <> 0) and Assigned(GetThemePartSize) and
    (GetThemePartSize(TreeTheme, DC, TVP_GLYPH, GLPS_CLOSED, nil, TS_DRAW, S) = S_OK) and (S.cx > Result) then
    Result := S.cx;
end;

procedure UIDrawTreeGlyph(DC: HDC; const R: TRect; Opened, Hot: Boolean);
const
  States: array[Boolean] of Integer = (GLPS_CLOSED, GLPS_OPENED);
  HotStates: array[Boolean] of Integer = (HGLPS_CLOSED, HGLPS_OPENED);
begin
  if (TreeGlyphTheme <> 0) and Assigned(DrawThemeBackground) then
  begin
    if Hot and (DrawThemeBackground(TreeTheme, DC, TVP_HOTGLYPH, HotStates[Opened], R, nil) = S_OK) then Exit;
    if DrawThemeBackground(TreeTheme, DC, TVP_GLYPH, States[Opened], R, nil) = S_OK then Exit;
  end;
  UIDrawExpandBox(DC, R.Left + (R.Right - R.Left - 9) div 2, R.Top + (R.Bottom - R.Top - 9) div 2, Opened);
end;

{ The pixels of the open glyph in its S x S part: the visual styles do not centre the chevron in
  the part (Windows 11: columns 3 - 11 and rows 5 - 10 of 16), so a glyph centred on its own is
  centred by its ink. Measured once per side and theme, on white; the whole part if nothing shows. }
function TreeGlyphInk(S: Integer): TRect;
const
  Paper = 245;                       // a channel below this is ink (antialiased edges included)
var
  Bmp: HBITMAP;
  Bits, P: PCardinal;
  MemDC: HDC;
  Old: HGDIOBJ;
  X, Y: Integer;
  C: Cardinal;
  Ink: TRect;
begin
  if TreeInkSize <> S then
  begin
    TreeInkSize := S;
    TreeInk := Rect(0, 0, S, S);
    Bmp := UICreateDib32(S, S, Bits);
    if Bmp <> 0 then
    begin
      MemDC := CreateCompatibleDC(0);
      Old := SelectObject(MemDC, Bmp);
      try
        FillChar(Bits^, S * S * SizeOf(Cardinal), $FF);
        UIDrawTreeGlyph(MemDC, Rect(0, 0, S, S), True);
        GdiFlush;
        Ink := Rect(S, S, 0, 0);
        P := Bits;
        for Y := 0 to S - 1 do
          for X := 0 to S - 1 do
          begin
            C := P^;
            if (C and $FF < Paper) or ((C shr 8) and $FF < Paper) or ((C shr 16) and $FF < Paper) then
            begin
              if X < Ink.Left then Ink.Left := X;
              if Y < Ink.Top then Ink.Top := Y;
              if X >= Ink.Right then Ink.Right := X + 1;
              if Y >= Ink.Bottom then Ink.Bottom := Y + 1;
            end;
            Inc(P);
          end;
        if Ink.Left < Ink.Right then TreeInk := Ink;
      finally
        SelectObject(MemDC, Old);
        DeleteDC(MemDC);
        DeleteObject(Bmp);
      end;
    end;
  end;
  Result := TreeInk;
end;

function UICheckBoxSize: Integer;
var
  S: TSize;
begin
  Result := 13;
  if ThemeServices.ThemesEnabled and
    (GetThemePartSize(ThemeServices.Theme[teButton], 0, BP_CHECKBOX, CBS_UNCHECKEDNORMAL, nil,
    TS_DRAW, S) = S_OK) and (S.cy > 0) then
    Result := S.cy;
end;

{ One flat line in the shadow colour around R - no classic bevel. }
procedure UIDrawBorder(DC: HDC; const R: TRect);
begin
  UIFrame(DC, R, clBtnShadow);
end;

{ A window with WS_BORDER has a 1 px frame that Windows draws black: after its WM_NCPAINT this
  draws the IDE's flat border over it (the scroll bars in the frame stay Windows'). }
procedure UIPaintFrameBorder(Wnd: HWND);
var
  DC: HDC;
  R: TRect;
begin
  DC := GetWindowDC(Wnd);
  if DC = 0 then Exit;
  try
    GetWindowRect(Wnd, R);
    OffsetRect(R, -R.Left, -R.Top);
    UIDrawBorder(DC, R);
  finally
    ReleaseDC(Wnd, DC);
  end;
end;

type
  { paints the flat border over the theme's frame. A combo box draws its frame in its client
    area: after WM_PAINT - into the buffer when it paints double-buffered (the VCL sends
    WM_PAINT again with its memory DC), so the theme's line never reaches the screen. An edit's
    frame is its client edge, 2 px of non-client area: after WM_NCPAINT, the outer line the
    border and the inner one the edit's colour. }
  TFlatBorder = class(TUIWindowHook)
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TFlatBorder.Hook(var Message: TMessage);

  { the frame, and the theme's rounded corners inside it filled as the face next to them }
  procedure PaintCombo(DC: HDC);
  var
    W, H: Integer;
  begin
    W := FControl.Width;
    H := FControl.Height;
    UIDrawBorder(DC, Rect(0, 0, W, H));
    SetPixel(DC, 1, 1, GetPixel(DC, 2, 1));
    SetPixel(DC, W - 2, 1, GetPixel(DC, W - 3, 1));
    SetPixel(DC, 1, H - 2, GetPixel(DC, 2, H - 2));
    SetPixel(DC, W - 2, H - 2, GetPixel(DC, W - 3, H - 2));
  end;

var
  DC: HDC;
  R: TRect;
begin
  FOldProc(Message);
  if not FControl.HandleAllocated then Exit;
  if FControl is TCustomComboBox then
  begin
    if Message.Msg <> WM_PAINT then Exit;
    if Message.WParam <> 0 then
      PaintCombo(HDC(Message.WParam))
    else
    begin
      DC := GetDC(FControl.Handle);
      try
        PaintCombo(DC);
      finally
        ReleaseDC(FControl.Handle, DC);
      end;
    end;
  end
  else if (Message.Msg = WM_NCPAINT) or (Message.Msg = WM_NCACTIVATE) then
  begin
    DC := GetWindowDC(FControl.Handle);
    try
      R := Rect(0, 0, FControl.Width, FControl.Height);
      UIDrawBorder(DC, R);
      InflateRect(R, -1, -1);
      UIFrame(DC, R, TControlAccess(FControl).Color);
    finally
      ReleaseDC(FControl.Handle, DC);
    end;
  end;
end;

procedure UIFlatBorder(Control: TWinControl);
begin
  if UIFindHook(Control, TFlatBorder) = nil then TFlatBorder.Create(Control, True);
  if Control.HandleAllocated then
    RedrawWindow(Control.Handle, nil, 0, RDW_INVALIDATE or RDW_FRAME);
end;

{ A themed push button's face is transparent at the rounded corners: the caller's background
  shows there. }
var
  PushInset: Integer = -1;

{ How many pixels the visual style leaves untouched around a push button: the styles of
  Windows 10 and 11 draw the frame 1 px inside the rectangle, the older ones on its edge. }
function ThemedPushInset: Integer;
const
  Probe = TColor($00FD01FE);
var
  Bmp: TBitmap;
  R: TRect;
begin
  if PushInset < 0 then
  begin
    PushInset := 0;
    Bmp := TBitmap.Create;
    try
      Bmp.PixelFormat := pf24bit;
      Bmp.Width := 32;
      Bmp.Height := 32;
      Bmp.Canvas.Brush.Color := Probe;
      R := Rect(0, 0, 32, 32);
      Bmp.Canvas.FillRect(R);
      ThemeServices.DrawElement(Bmp.Canvas.Handle, ThemeServices.GetElementDetails(tbPushButtonNormal), R);
      while (PushInset < 4) and (Bmp.Canvas.Pixels[PushInset, 16] = Probe) and
        (Bmp.Canvas.Pixels[16, PushInset] = Probe) do
        Inc(PushInset);
      if PushInset = 4 then PushInset := 0;     // nothing was drawn at all
    finally
      Bmp.Free;
    end;
  end;
  Result := PushInset;
end;

{ A glyph centred on the value's clWindow ground, with no frame or box in any state: the open
  tree item's chevron of the visual style (value list) or three 2 x 2 dots 2 px apart (dialog).
  Only bsDisabled shows: the dots in clGrayText. }
procedure UIDrawGlyphButton(DC: HDC; const R: TRect; Glyph: TUIGlyph; State: TUIButtonState);
var
  W, H, X, Y, I, S: Integer;
  C: TColor;
  Ink: TRect;
begin
  UIFill(DC, R, clWindow);
  if State = bsDisabled then C := clGrayText else C := clWindowText;
  W := R.Right - R.Left;
  H := R.Bottom - R.Top;
  case Glyph of
    ugDropArrow:
      begin
        { the chevron's ink centred; an odd remainder goes above it and left of it, as the
          chevron's antialiased point makes its lowest row the faintest }
        S := UITreeGlyphSize(DC);
        Ink := TreeGlyphInk(S);
        X := R.Left + (W - (Ink.Right - Ink.Left) + 1) div 2 - Ink.Left;
        Y := R.Top + (H - (Ink.Bottom - Ink.Top) + 1) div 2 - Ink.Top;
        UIDrawTreeGlyph(DC, Rect(X, Y, X + S, Y + S), True);
      end;
    ugEllipsis:
      begin
        X := R.Left + (W - 10) div 2;
        Y := R.Top + (H - 2) div 2;
        for I := 0 to 2 do UIFill(DC, Rect(X + I * 4, Y, X + I * 4 + 2, Y + 2), C);
      end;
  end;
end;

{ the accent box of tool buttons and menu items (Visual Studio's, square - no round corners): a
  tint of the accent colour on Ground, light
  under the pointer, Strong when pressed, checked or chosen, in a 1 px edge of the accent colour
  darkened }
procedure DrawAccent(DC: HDC; const R: TRect; Ground: TColor; Strong: Boolean);
const
  Tint: array[Boolean] of Integer = (12, 25);
begin
  UIFill(DC, R, UIBlend(clHighlight, clBtnText, 70));
  UIFill(DC, Rect(R.Left + 1, R.Top + 1, R.Right - 1, R.Bottom - 1), UIBlend(clHighlight, Ground, Tint[Strong]));
end;

procedure UIDrawFlatButton(DC: HDC; const R: TRect; State: TUIButtonState; Ground: TColor);
begin
  case State of
    bsHot: DrawAccent(DC, R, Ground, False);
    bsDown, bsChecked: DrawAccent(DC, R, Ground, True);
  end;
end;

function UIBarColor: TColor;
begin
  Result := clWindow;
end;

procedure UIDrawGripper(DC: HDC; const R: TRect);
var
  RR: TRect;
begin
  RR := R;
  ThemeServices.DrawElement(DC, ThemeServices.GetElementDetails(trGripper), RR);
end;

{ --- menus in D7 Studio's flat style -----------------------------------------------------------
  Visual Studio 2019's menus on a white ground: square boxes with a 1 px edge, 22 px items,
  separators from the text column. Every item is drawn in a bitmap and copied in one piece (no
  flicker: ground, box and text went to the screen one after the other). }

const
  ODS_NOACCEL = $0100;              // not in Delphi 7's Windows.pas
  MenuGutter = 26;                  // a popup's icon column (the icon centred in it)
  MenuTextX = 32;                   // where an item's text starts
  MenuSeparatorX = 28;              // where a separator starts
  MenuArrowRoom = 24;               // the submenu arrow at the right end
  MenuShortcutGap = 32;             // between the text and the shortcut
  MenuBarPadX = 10;                 // a menu bar item: room beside its text

function MenuItemHeight: Integer;   // a popup's item; 22 px for Segoe UI 9, as Visual Studio's
begin
  Result := UITextHeight + 7;
end;


{ an item's text; a caption with a tab (a key the editor handles itself, not a menu shortcut:
  '&Code Completion'#9'Ctrl+Space') is text before it and shortcut after it, as Windows' own
  menus show it }
function MenuItemText(Item: TMenuItem): WideString;
var
  P: Integer;
begin
  Result := '';
  if Assigned(UIMenuTextW) then Result := UIMenuTextW(Item);
  if Result = '' then Result := ToWide(Item.Caption, CP_ACP);
  P := Pos(WideChar(#9), Result);
  if P > 0 then Result := Copy(Result, 1, P - 1);
end;

function MenuShortcutText(Item: TMenuItem): string;
var
  P: Integer;
begin
  Result := '';
  if Item.Count > 0 then Exit;
  if Item.ShortCut <> 0 then
    Result := ShortCutToText(Item.ShortCut)
  else
  begin
    P := Pos(#9, Item.Caption);
    if P > 0 then Result := Copy(Item.Caption, P + 1, MaxInt);
  end;
end;

function IsMenuBarItem(Item: TMenuItem): Boolean;
begin
  Result := (Item.Parent <> nil) and (Item.Parent.Parent = nil) and (Item.GetParentMenu is TMainMenu);
end;

procedure MeasureMenuItem(Item: TMenuItem; var W, H: Integer);
var
  DC: HDC;
  Old: HGDIOBJ;
  R: TRect;
  T: WideString;
  S: string;
  TW, SW: Integer;
begin
  if Item.IsLine then
  begin
    W := 16;
    H := 9;
    Exit;
  end;
  if UIFont = nil then SetupFonts;
  DC := GetDC(0);
  Old := SelectObject(DC, UIFont.Handle);
  try
    T := MenuItemText(Item);
    R := Rect(0, 0, 0, 0);
    DrawTextW(DC, PWideChar(T), Length(T), R, DT_CALCRECT or DT_SINGLELINE);
    TW := R.Right;
    S := MenuShortcutText(Item);
    if S <> '' then SW := UITextWidth(DC, S) else SW := 0;
  finally
    SelectObject(DC, Old);
    ReleaseDC(0, DC);
  end;
  if IsMenuBarItem(Item) then
  begin
    { padding beside the text; the bar's height is Windows' own (SM_CYMENU: an owner-drawn item's
      height does not change it) }
    W := TW + 2 * MenuBarPadX;
    H := UITextHeight + 6;
  end
  else
  begin
    W := MenuTextX + TW + MenuArrowRoom;
    if SW > 0 then Inc(W, MenuShortcutGap + SW);
    H := MenuItemHeight;
  end;
  { Windows makes an owner-drawn item wider by its check mark column - also in the menu bar }
  Dec(W, GetSystemMetrics(SM_CXMENUCHECK) - 1);
end;

var
  CheckFont: HFONT;            // the icon font of the menus' check marks (0: not made yet)
  CheckFontMissing: Boolean;   // ... neither of Windows' icon fonts is there

{ Windows' icon font (Windows 11: Segoe Fluent Icons, 10: Segoe MDL2 Assets), 0 without one }
function MenuCheckFont: HFONT;
const
  Faces: array[0..1] of string = ('Segoe Fluent Icons', 'Segoe MDL2 Assets');
  CLEARTYPE_QUALITY = 5;
var
  I: Integer;
  DC: HDC;
  Old: HGDIOBJ;
  Face: array[0..LF_FACESIZE] of Char;
begin
  if (CheckFont = 0) and not CheckFontMissing then
  begin
    DC := GetDC(0);
    try
      for I := Low(Faces) to High(Faces) do
      begin
        CheckFont := CreateFont(-16, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
          CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, DEFAULT_PITCH, PChar(Faces[I]));
        { Windows gives another font when the face is not there }
        Old := SelectObject(DC, CheckFont);
        GetTextFace(DC, SizeOf(Face), Face);
        SelectObject(DC, Old);
        if SameText(Face, Faces[I]) then Break;
        DeleteObject(CheckFont);
        CheckFont := 0;
      end;
    finally
      ReleaseDC(0, DC);
    end;
    CheckFontMissing := CheckFont = 0;
  end;
  Result := CheckFont;
end;

{ the check mark of a menu item (Radio: its bullet) in Color, centred in R: the glyphs of
  Windows' own menus, CheckMark and RadioBullet of its icon font; without that font the visual
  style's MENU_POPUPCHECK }
procedure DrawMenuCheck(DC: HDC; const R: TRect; Radio, Disabled: Boolean; Color: TColor);
const
  MENU_POPUPCHECK = 11;
  MC_CHECKMARKNORMAL = 1;
  MC_BULLETNORMAL = 3;
  Glyphs: array[Boolean] of Word = ($E73E, $E915);
var
  D: TThemedElementDetails;
  Size: TSize;
  G: TRect;
  Old: HGDIOBJ;
  W: WideChar;
begin
  if MenuCheckFont <> 0 then
  begin
    Old := SelectObject(DC, MenuCheckFont);
    try
      W := WideChar(Glyphs[Radio]);
      G := R;
      SetBkMode(DC, TRANSPARENT);
      SetTextColor(DC, ColorToRGB(Color));
      DrawTextW(DC, @W, 1, G, DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
    finally
      SelectObject(DC, Old);
    end;
    Exit;
  end;
  if not ThemeServices.ThemesEnabled then Exit;
  { a part of Windows Vista's MENU class, which Delphi 7's element list does not name: the
    details by number, drawn through the VCL's theme of the class }
  D.Element := teMenu;
  D.Part := MENU_POPUPCHECK;
  if Radio then D.State := MC_BULLETNORMAL else D.State := MC_CHECKMARKNORMAL;
  if Disabled then Inc(D.State);
  if GetThemePartSize(ThemeServices.Theme[teMenu], DC, D.Part, D.State, nil, TS_TRUE, Size) <> S_OK then
  begin
    Size.cx := R.Right - R.Left;
    Size.cy := R.Bottom - R.Top;
  end;
  G.Left := R.Left + (R.Right - R.Left - Size.cx) div 2;
  G.Top := R.Top + (R.Bottom - R.Top - Size.cy) div 2;
  G.Right := G.Left + Size.cx;
  G.Bottom := G.Top + Size.cy;
  ThemeServices.DrawElement(DC, D, G);
end;

var
  DisabledFor: TCustomImageList;    // UIDisabledImages
  DisabledList: HIMAGELIST;

procedure DrawMenuImage(Images: TCustomImageList; Index: Integer; DC: HDC; X, Y: Integer; Disabled: Boolean);
var
  P: TImageListDrawParamsEx;        // comctl32 6's: with fState
begin
  FillChar(P, SizeOf(P), 0);
  P.cbSize := SizeOf(P);
  P.himl := Images.Handle;
  if Disabled and (Images = DisabledFor) and (DisabledList <> 0) then
  begin
    P.himl := DisabledList;
    Disabled := False;
  end;
  P.i := Index;
  P.hdcDst := DC;
  P.x := X;
  P.y := Y;
  P.rgbBk := CLR_NONE;
  P.rgbFg := CLR_NONE;
  P.fStyle := ILD_TRANSPARENT;
  if Disabled then P.fState := ILS_SATURATE;
  ImageList_DrawIndirect(@P);
end;

var
  { a menu of the menu bar is open: its item is drawn open (else under the pointer - in the
    keyboard's menu mode Windows selects an item without opening its menu) }
  MenuBarOpen: Boolean;
  OpenBarItem: TRect;          // ... that item, screen coordinates

{ the colour of Windows' frame around a popup (the open menu bar item continues it) }
function MenuFrameColor: TColor;
begin
  Result := clBtnShadow;
end;

procedure DrawMenuItem(Item: TMenuItem; DC: HDC; const R: TRect; State: UINT);
var
  Selected, Disabled, Checked: Boolean;
  Back, Fore: TColor;
  Old: HGDIOBJ;
  TR, CR: TRect;
  T: WideString;
  S: string;
  Images: TCustomImageList;
  Index, Flags: Integer;
begin
  if UIFont = nil then SetupFonts;
  Selected := State and (ODS_SELECTED or ODS_HOTLIGHT) <> 0;
  Disabled := State and (ODS_DISABLED or ODS_GRAYED) <> 0;
  Checked := State and ODS_CHECKED <> 0;
  if Disabled or (State and ODS_INACTIVE <> 0) then Fore := clGrayText else Fore := clMenuText;
  Flags := DT_SINGLELINE or DT_VCENTER;
  if State and ODS_NOACCEL <> 0 then Flags := Flags or DT_HIDEPREFIX;
  Old := SelectObject(DC, UIFont.Handle);
  try
    if IsMenuBarItem(Item) then Back := UIBarColor else Back := clWindow;
    UIFill(DC, R, Back);
    if IsMenuBarItem(Item) then
    begin
      { the menu bar: a light box under the pointer; while its menu is open a box of the menu's
        frame, open at the bottom towards the menu (OpenMenuGap). Both are as high as the bar
        (the bar's height is Windows' own) }
      if not Disabled then
        if (State and ODS_SELECTED <> 0) and MenuBarOpen then
        begin
          UIFill(DC, R, MenuFrameColor);
          UIFill(DC, Rect(R.Left + 1, R.Top + 1, R.Right - 1, R.Bottom), Back);
        end
        else if State and (ODS_SELECTED or ODS_HOTLIGHT) <> 0 then
          DrawAccent(DC, R, Back, False);
      TR := R;
      UITextW(DC, MenuItemText(Item), TR, Flags or DT_CENTER, Fore);
      Exit;
    end;
    { a popup: the icons in a column of their own (not shaded: the menu's margins above the
      first item and below the last cannot be drawn on, a shade stopped short there) }
    if Item.IsLine then
    begin
      UIHLine(DC, R.Left + MenuSeparatorX, R.Right, (R.Top + R.Bottom) div 2, UIBlend(clBtnShadow, Back, 60));
      Exit;
    end;
    if Selected and not Disabled then DrawAccent(DC, R, Back, True);
    { the icon on a box when checked; a checked item without one has Windows' check mark (a
      bullet for a radio item) }
    CR := Rect(R.Left + 2, R.Top + 2, R.Left + MenuGutter - 2, R.Bottom - 2);
    if Checked then DrawAccent(DC, CR, Back, True);
    Images := Item.GetImageList;
    Index := Item.ImageIndex;
    if (Images <> nil) and (Index >= 0) and (Index < Images.Count) then
      DrawMenuImage(Images, Index, DC, R.Left + (MenuGutter - Images.Width) div 2,
        R.Top + (R.Bottom - R.Top - Images.Height) div 2, Disabled)
    else if Checked then
      DrawMenuCheck(DC, CR, Item.RadioItem, Disabled, Fore);
    { the text, the shortcut at the right, the submenu's arrow }
    TR := Rect(R.Left + MenuTextX, R.Top, R.Right - MenuArrowRoom, R.Bottom);
    T := MenuItemText(Item);
    UITextW(DC, T, TR, Flags or DT_LEFT, Fore);
    S := MenuShortcutText(Item);
    if S <> '' then
    begin
      TR := Rect(R.Left + MenuTextX, R.Top, R.Right - MenuArrowRoom, R.Bottom);
      UIText(DC, S, TR, DT_SINGLELINE or DT_VCENTER or DT_RIGHT or DT_NOPREFIX, Fore);
    end;
    { a submenu's arrow is Windows' own: it draws one after the item in any case }
  finally
    SelectObject(DC, Old);
  end;
end;

{ the menu messages of an owner window: True when an item of Menu (or of the popup menus) was
  measured or drawn. A popup about to open gets the light ground beside its items. }
function HandleMenuMessage(var Message: TMessage; Menu: TMenu; Popups: Boolean): Boolean;
var
  Item: TMenuItem;
  W, H: Integer;
  MemDC: HDC;
  Bmp: HBITMAP;
  OldBmp: HGDIOBJ;
  MI: TMenuInfo;

  function Find(ID: UINT): TMenuItem;
  var
    K: Integer;
  begin
    Result := nil;
    if Menu <> nil then Result := Menu.FindItem(ID, fkCommand);
    if (Result = nil) and Popups then
      for K := 0 to PopupList.Count - 1 do
      begin
        Result := TPopupMenu(PopupList[K]).FindItem(ID, fkCommand);
        if Result <> nil then Exit;
      end;
  end;

begin
  Result := False;
  case Message.Msg of
    WM_INITMENUPOPUP:
      if HiWord(Message.LParam) = 0 then         // not the window menu
      begin
        FillChar(MI, SizeOf(MI), 0);
        MI.cbSize := SizeOf(MI);
        MI.fMask := MIM_BACKGROUND;
        MI.hbrBack := GetSysColorBrush(COLOR_WINDOW);
        SetMenuInfo(HMENU(Message.WParam), MI);
      end;
    WM_MEASUREITEM:
      with PMeasureItemStruct(Message.LParam)^ do
        if CtlType = ODT_MENU then
        begin
          Item := Find(itemID);
          if Item = nil then Exit;
          W := itemWidth;
          H := itemHeight;
          MeasureMenuItem(Item, W, H);
          itemWidth := W;
          itemHeight := H;
          Message.Result := 1;
          Result := True;
        end;
    WM_DRAWITEM:
      with PDrawItemStruct(Message.LParam)^ do
        if CtlType = ODT_MENU then
        begin
          Item := Find(itemID);
          if Item = nil then Exit;
          { drawn in a bitmap, then copied: the screen never shows the ground without the rest }
          W := rcItem.Right - rcItem.Left;
          H := rcItem.Bottom - rcItem.Top;
          MemDC := CreateCompatibleDC(hDC);
          Bmp := CreateCompatibleBitmap(hDC, W, H);
          OldBmp := SelectObject(MemDC, Bmp);
          try
            SetWindowOrgEx(MemDC, rcItem.Left, rcItem.Top, nil);
            DrawMenuItem(Item, MemDC, rcItem, itemState);
            SetWindowOrgEx(MemDC, 0, 0, nil);
            BitBlt(hDC, rcItem.Left, rcItem.Top, W, H, MemDC, 0, 0, SRCCOPY);
          finally
            SelectObject(MemDC, OldBmp);
            DeleteObject(Bmp);
            DeleteDC(MemDC);
          end;
          Message.Result := 1;
          Result := True;
        end;
  end;
end;

{ the menu bar's ground beside its items (UIBarColor), drawn again when it changes. Windows' own
  is COLOR_MENUBAR, and a new menu bar has it: the VCL makes the bar's menu again when its
  top-level items change (TMenuItem.RebuildHandle destroys the emptied menu, CM_MENUCHANGED sets
  the new one) - an expert's menu does that }
procedure SetMenuBarGround(Form: TCustomForm);
var
  MI: TMenuInfo;
  Bar: HMENU;
  Brush: HBRUSH;
begin
  if (TForm(Form).Menu = nil) or (csDestroying in Form.ComponentState) or
    (csDestroying in TForm(Form).Menu.ComponentState) then Exit;
  Bar := TForm(Form).Menu.Handle;
  Brush := GetSysColorBrush(UIBarColor and $FF);   // a system colour: its index is the low byte
  FillChar(MI, SizeOf(MI), 0);
  MI.cbSize := SizeOf(MI);
  MI.fMask := MIM_BACKGROUND;
  if GetMenuInfo(Bar, MI) and (MI.hbrBack = Brush) then Exit;
  MI.fMask := MIM_BACKGROUND;
  MI.hbrBack := Brush;
  SetMenuInfo(Bar, MI);
  if Form.HandleAllocated then DrawMenuBar(Form.Handle);
end;

type
  { the menu bar's items, at the form that has it; the line Windows draws under the bar is left
    as it is: it separates the bar from the client area (the tool row). A change of Windows'
    colours that the main window hears makes UITitleColors read the title bars' colours again,
    a change of the visual style UIDrawTreeGlyph open the style's tree view part again. }
  TMenuLook = class(TUIWindowHook)
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TMenuLook.Hook(var Message: TMessage);

  { M is a menu of the menu bar (not a submenu, not the window menu): True, and its item's
    place on the screen }
  function OfBar(M: HMENU; var R: TRect): Boolean;
  var
    Bar: HMENU;
    I: Integer;
  begin
    Result := False;
    Bar := GetMenu(FControl.Handle);
    if Bar = 0 then Exit;
    for I := 0 to GetMenuItemCount(Bar) - 1 do
      if GetSubMenu(Bar, I) = M then
      begin
        Result := GetMenuItemRect(FControl.Handle, Bar, I, R);
        Exit;
      end;
  end;

var
  R: TRect;
begin
  case Message.Msg of
    WM_SETTINGCHANGE, WM_SYSCOLORCHANGE, WM_THEMECHANGED, WM_DWMCOLORIZATIONCOLORCHANGED:
      TitleRead := False;
  end;
  if Message.Msg = WM_THEMECHANGED then UICloseTreeTheme;
  if ((Message.Msg = WM_INITMENUPOPUP) and (HiWord(Message.LParam) = 0)) or (Message.Msg = WM_UNINITMENUPOPUP) then
    if OfBar(HMENU(Message.WParam), R) then
    begin
      MenuBarOpen := Message.Msg = WM_INITMENUPOPUP;
      OpenBarItem := R;
      DrawMenuBar(FControl.Handle);
    end;
  if not HandleMenuMessage(Message, TForm(FControl).Menu, False) then FOldProc(Message);
  { the form has set its menu again, perhaps a new one }
  if Message.Msg = CM_MENUCHANGED then SetMenuBarGround(TCustomForm(FControl));
end;

var
  PopupProc: Pointer;      // the window procedure of the VCL's PopupList.Window

{ every popup menu's items: at the hidden window of the VCL's PopupList, which owns them all }
function PopupLookProc(Wnd: HWND; Msg: UINT; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
var
  M: TMessage;
begin
  M.Msg := Msg;
  M.WParam := WParam;
  M.LParam := LParam;
  M.Result := 0;
  if HandleMenuMessage(M, nil, True) then Result := M.Result
  else Result := CallWindowProc(PopupProc, Wnd, Msg, WParam, LParam);
end;

{ The menus' own windows (class #32768, made by Windows while a menu opens): the menu of the
  open menu bar item is joined to it - no top edge under the item, as in Visual Studio. Windows
  11's rounded corners and border of its own stay (no DWM call). }
const
  MenuProcProp = 'D7SMenuProc';

var
  MenuCBT: HHOOK;

{ the top edge of a menu's frame under the open menu bar item, in the menu's background (DC: a
  WM_PRINT's, else the window's) }
procedure OpenMenuGap(Wnd: HWND; PrintDC: HDC);
var
  W: TRect;
  L, R: Integer;
  DC: HDC;
begin
  if not MenuBarOpen then Exit;
  GetWindowRect(Wnd, W);
  if Abs(W.Top - OpenBarItem.Bottom) > 1 then Exit;   // a submenu, or a menu elsewhere
  L := OpenBarItem.Left + 1;
  if L < W.Left + 1 then L := W.Left + 1;
  R := OpenBarItem.Right - 1;
  if R > W.Right - 1 then R := W.Right - 1;
  if R <= L then Exit;
  if PrintDC <> 0 then DC := PrintDC else DC := GetWindowDC(Wnd);
  try
    UIFill(DC, Rect(L - W.Left, 0, R - W.Left, 1), clWindow);
  finally
    if PrintDC = 0 then ReleaseDC(Wnd, DC);
  end;
end;

function MenuWndProc(Wnd: HWND; Msg: UINT; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
var
  Old: Pointer;
begin
  Old := Pointer(GetProp(Wnd, MenuProcProp));
  Result := CallWindowProc(Old, Wnd, Msg, WParam, LParam);
  case Msg of
    WM_NCPAINT:
      OpenMenuGap(Wnd, 0);
    WM_PRINT:
      if LParam and PRF_NONCLIENT <> 0 then OpenMenuGap(Wnd, HDC(WParam));
    WM_NCDESTROY:
      begin
        SetWindowLong(Wnd, GWL_WNDPROC, Integer(Old));
        RemoveProp(Wnd, MenuProcProp);
      end;
  end;
end;

function MenuCBTProc(Code: Integer; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
var
  Wnd: HWND;
  Cls: array[0..7] of Char;
begin
  if Code = HCBT_CREATEWND then
  begin
    Wnd := HWND(WParam);
    if (GetClassName(Wnd, Cls, SizeOf(Cls)) = 6) and (StrComp(Cls, '#32768') = 0) and
      (GetProp(Wnd, MenuProcProp) = 0) then
      SetProp(Wnd, MenuProcProp, THandle(SetWindowLong(Wnd, GWL_WNDPROC, Integer(@MenuWndProc))));
  end;
  Result := CallNextHookEx(MenuCBT, Code, WParam, LParam);
end;

type
  TMenuItemAccess = class(TMenuItem);

procedure UIOwnerDrawMenus(Owner: TComponent);
var
  I: Integer;
  M: TMenu;
begin
  for I := 0 to Owner.ComponentCount - 1 do
    if (Owner.Components[I] is TMenu) and not TMenu(Owner.Components[I]).OwnerDraw then
    begin
      M := TMenu(Owner.Components[I]);
      M.OwnerDraw := True;
      { OwnerDraw makes the submenus again, not the menu's own items: a menu bar built before
        its Images were known (they are a reference of the .dfm) kept Windows' items. A change
        of the first item makes them again. }
      if M.Items.Count > 0 then TMenuItemAccess(M.Items[0]).MenuChanged(True);
    end;
end;

procedure UIModernMenus(Form: TCustomForm);
begin
  if (PopupProc = nil) and (PopupList <> nil) and (PopupList.Window <> 0) then
    PopupProc := Pointer(SetWindowLong(PopupList.Window, GWL_WNDPROC, Integer(@PopupLookProc)));
  if MenuCBT = 0 then MenuCBT := SetWindowsHookEx(WH_CBT, @MenuCBTProc, 0, GetCurrentThreadId);
  { the hook first: making the menus owner-drawn measures the menu bar's items again }
  if UIFindHook(Form, TMenuLook) = nil then TMenuLook.Create(Form, True);
  UIOwnerDrawMenus(Form);
  SetMenuBarGround(Form);
end;

{ --- tool bars: a rounded accent highlight ---------------------------------------------------- }

const
  TBCDRF_NOBACKGROUND = $00400000;   // comctl32 6: no button background (not in Delphi 7)
  TB_GETITEMDROPDOWNRECT = WM_USER + 103;   // comctl32 6: the drop-down part of a button

type
  TToolBarLook = class(TUIWindowHook)
  private
    FOwnGround: Boolean;            // its ground its own colour (UIViewToolBar), else its parent's
  protected
    procedure Hook(var Message: TMessage); override;
  end;
  TPixelRow = array[0..MaxInt div 8] of Cardinal;    // a row of a 32-bit DIB: $AARRGGBB
  PPixelRow = ^TPixelRow;

var
  { the greyed arrow of DrawDisabledDropArrow, made for one size, theme DPI (Themes.GetThemePaintDpi)
    and theme handle - made again for others, and after a change of Windows' theme or colours
    (TToolBarLook clears GreyArrowW) }
  GreyArrowW, GreyArrowH, GreyArrowDpi: Integer;
  GreyArrowTheme: HTHEME;
  GreyArrowPix: array of Cardinal;     // each pixel greyed (UIGreyPixel): $AARRGGBB
  GreyArrowOn: array of Boolean;       // ... the arrow covers the pixel: its opacity is above 0

{ the theme's normal drop-down arrow of W x H greyed: its colour and opacity read off two
  renderings, on black and on white, then through UIGreyPixel }
procedure MakeGreyArrow(W, H: Integer);
var
  X, Y, A: Integer;
  OnWhite: Boolean;
  Bmp: array[Boolean] of TBitmap;
  RowB, RowW: PPixelRow;
  D: TThemedElementDetails;

  { a channel of Pix (drawn on black: colour x opacity) as it is, opacity A }
  function Channel(Pix: Cardinal; Shift, A: Integer): Cardinal;
  begin
    Result := ((Pix shr Shift) and $FF) * 255 div Cardinal(A);
    if Result > 255 then Result := 255;
  end;

begin
  GreyArrowW := 0;
  SetLength(GreyArrowPix, W * H);
  SetLength(GreyArrowOn, W * H);
  D := ThemeServices.GetElementDetails(ttbSplitButtonDropDownNormal);
  Bmp[False] := nil;
  Bmp[True] := nil;
  try
    for OnWhite := False to True do
    begin
      Bmp[OnWhite] := TBitmap.Create;
      Bmp[OnWhite].PixelFormat := pf32bit;
      Bmp[OnWhite].Width := W;
      Bmp[OnWhite].Height := H;
      if OnWhite then UIFill(Bmp[OnWhite].Canvas.Handle, Rect(0, 0, W, H), clWhite)
      else UIFill(Bmp[OnWhite].Canvas.Handle, Rect(0, 0, W, H), clBlack);
      ThemeServices.DrawElement(Bmp[OnWhite].Canvas.Handle, D, Rect(0, 0, W, H));
    end;
    for Y := 0 to H - 1 do
    begin
      RowB := Bmp[False].ScanLine[Y];
      RowW := Bmp[True].ScanLine[Y];
      for X := 0 to W - 1 do
      begin
        { drawn on white it is what it is on black plus the white it lets through }
        A := 255 - (Integer((RowW^[X] shr 8) and $FF) - Integer((RowB^[X] shr 8) and $FF));
        GreyArrowOn[Y * W + X] := A > 0;
        if A <= 0 then Continue;
        if A > 255 then A := 255;
        GreyArrowPix[Y * W + X] := UIGreyPixel(Cardinal(A) shl 24 or Channel(RowB^[X], 16, A) shl 16 or
          Channel(RowB^[X], 8, A) shl 8 or Channel(RowB^[X], 0, A));
      end;
    end;
  finally
    Bmp[False].Free;
    Bmp[True].Free;
  end;
  GreyArrowW := W;
  GreyArrowH := H;
end;

{ The drop-down arrow of a disabled tool button, greyed as the disabled images are. Windows draws
  the theme's
  disabled arrow (TP_SPLITBUTTONDROPDOWN: #707276, the enabled one #282828), which looked enabled
  beside images at a quarter of their opacity. Over it the bar's ground again, then the theme's
  normal arrow greyed (MakeGreyArrow, made once for the size and the theme), blended over the
  ground pixel by pixel. }
procedure DrawDisabledDropArrow(Bar: TToolBar; DC: HDC; Command: Integer);
var
  I, X, Y, W, H, K, Dpi: Integer;
  R: TRect;
  Btn: TTBButton;
  Q, QA: Cardinal;
  G: COLORREF;
  Theme: HTHEME;

  function Mix(QC, GC, QA: Cardinal): Cardinal;
  begin
    Result := (QC * QA + GC * (255 - QA)) div 255;
  end;

begin
  I := SendMessage(Bar.Handle, TB_COMMANDTOINDEX, Command, 0);
  if (I < 0) or (SendMessage(Bar.Handle, TB_GETBUTTON, I, Integer(@Btn)) = 0) or
    (Btn.fsStyle and TBSTYLE_DROPDOWN = 0) or
    (SendMessage(Bar.Handle, TB_GETITEMDROPDOWNRECT, I, Integer(@R)) = 0) then Exit;
  W := R.Right - R.Left;
  H := R.Bottom - R.Top;
  if (W <= 0) or (H <= 0) then Exit;
  ThemeServices.DrawParentBackground(Bar.Handle, DC, nil, False, @R);
  Dpi := Themes.GetThemePaintDpi;
  Theme := ThemeServices.Theme[teToolBar];
  if (W <> GreyArrowW) or (H <> GreyArrowH) or (Dpi <> GreyArrowDpi) or (Theme <> GreyArrowTheme) then
  begin
    MakeGreyArrow(W, H);
    GreyArrowDpi := Dpi;
    GreyArrowTheme := Theme;
  end;
  for Y := 0 to H - 1 do
    for X := 0 to W - 1 do
    begin
      K := Y * W + X;
      if not GreyArrowOn[K] then Continue;
      Q := GreyArrowPix[K];
      QA := Q shr 24;
      G := GetPixel(DC, R.Left + X, R.Top + Y);
      if G = CLR_INVALID then G := ColorToRGB(Bar.Color);
      SetPixel(DC, R.Left + X, R.Top + Y, RGB(Mix((Q shr 16) and $FF, GetRValue(G), QA),
        Mix((Q shr 8) and $FF, GetGValue(G), QA), Mix(Q and $FF, GetBValue(G), QA)));
    end;
end;

{ the bar's disabled image list as UIDisabledImages says, before it paints (the VCL sets none
  while the bar has no DisabledImages of its own, so the bar keeps it) }
procedure SyncDisabledImages(Bar: TToolBar);
var
  L: HIMAGELIST;
begin
  if not Bar.HandleAllocated or (Bar.DisabledImages <> nil) or (Bar.Images = nil) then Exit;
  if Bar.Images = DisabledFor then L := DisabledList else L := 0;
  if HIMAGELIST(SendMessage(Bar.Handle, TB_GETDISABLEDIMAGELIST, 0, 0)) <> L then
    SendMessage(Bar.Handle, TB_SETDISABLEDIMAGELIST, 0, L);
end;

{ The bar paints double-buffered (comctl32 6: TBSTYLE_EX_DOUBLEBUFFER - its ground, the parent's,
  comes into the buffer too) and erases nothing on the screen: the VCL's erase painted the ground
  there first and the buttons came after it - a docked view's bar flickered at every step of a
  resize (Windows repaints the children of a window that moves and changes size at once). The
  style is added to whatever the bar is given (TToolBar.CreateWnd sets its own). }
procedure TToolBarLook.Hook(var Message: TMessage);
var
  CD: PNMTBCustomDraw;
  S: UINT;
begin
  case Message.Msg of
    WM_CREATE:
      begin
        FOldProc(Message);
        SyncDisabledImages(TToolBar(FControl));       // a new window of the bar
        Exit;
      end;
    TB_SETEXTENDEDSTYLE:
      Message.LParam := Message.LParam or TBSTYLE_EX_DOUBLEBUFFER;
    WM_ERASEBKGND:
      begin
        Message.Result := 1;
        Exit;
      end;
    WM_THEMECHANGED, WM_SYSCOLORCHANGE:
      GreyArrowW := 0;                                 // the greyed drop-down arrow is made again
  end;
  if (Message.Msg = CN_NOTIFY) and (TWMNotify(Message).NMHdr^.code = NM_CUSTOMDRAW) then
  begin
    CD := PNMTBCustomDraw(TWMNotify(Message).NMHdr);
    case CD^.nmcd.dwDrawStage of
      CDDS_PREPAINT:
        begin
          { a view's bar on its own ground, over the parent's that a flat bar has drawn first }
          if FOwnGround then UIFill(CD^.nmcd.hdc, CD^.nmcd.rc, TToolBar(FControl).Color);
          Message.Result := CDRF_NOTIFYITEMDRAW;
        end;
      CDDS_ITEMPREPAINT:
        begin
          S := CD^.nmcd.uItemState;
          { on the bar's own ground (the tool row's is the menu bar's: UIBarColor) }
          if S and CDIS_DISABLED = 0 then
            if S and CDIS_SELECTED <> 0 then UIDrawFlatButton(CD^.nmcd.hdc, CD^.nmcd.rc, bsDown, TToolBar(FControl).Color)
            else if S and CDIS_CHECKED <> 0 then UIDrawFlatButton(CD^.nmcd.hdc, CD^.nmcd.rc, bsChecked, TToolBar(FControl).Color)
            else if S and CDIS_HOT <> 0 then UIDrawFlatButton(CD^.nmcd.hdc, CD^.nmcd.rc, bsHot, TToolBar(FControl).Color);
          { the tool bar draws the image (and a drop-down arrow) only; a disabled button's arrow
            is greyed afterwards as its image is (DrawDisabledDropArrow) }
          Message.Result := CDRF_DODEFAULT or TBCDRF_NOBACKGROUND or TBCDRF_NOEDGES or TBCDRF_NOOFFSET;
          if S and CDIS_DISABLED <> 0 then Message.Result := Message.Result or CDRF_NOTIFYPOSTPAINT;
        end;
      CDDS_ITEMPOSTPAINT:
        begin
          DrawDisabledDropArrow(TToolBar(FControl), CD^.nmcd.hdc, CD^.nmcd.dwItemSpec);
          Message.Result := CDRF_DODEFAULT;
        end;
    else
      Message.Result := CDRF_DODEFAULT;
    end;
    Exit;
  end;
  FOldProc(Message);
end;

procedure UIModernToolBar(Bar: TToolBar);
begin
  if UIFindHook(Bar, TToolBarLook) = nil then TToolBarLook.Create(Bar, True);
  SyncDisabledImages(Bar);
  if Bar.HandleAllocated then
  begin
    { through the hook: double-buffered from now on }
    Bar.Perform(TB_SETEXTENDEDSTYLE, 0, Bar.Perform(TB_GETEXTENDEDSTYLE, 0, 0));
    Bar.Invalidate;
  end;
end;

procedure UIViewToolBar(Bar: TToolBar);
begin
  Bar.Align := alNone;
  Bar.AutoSize := False;
  Bar.EdgeBorders := [];
  Bar.Flat := True;
  Bar.ShowCaptions := True;
  Bar.Wrapable := False;
  Bar.Transparent := False;
  Bar.ParentShowHint := False;
  Bar.ShowHint := True;
  Bar.Height := Bar.ButtonHeight + 2;
  UIModernToolBar(Bar);
  TToolBarLook(UIFindHook(Bar, TToolBarLook)).FOwnGround := True;
end;

procedure SyncBars(C: TWinControl);
var
  I: Integer;
begin
  if C is TToolBar then SyncDisabledImages(TToolBar(C));
  for I := 0 to C.ControlCount - 1 do
    if C.Controls[I] is TWinControl then SyncBars(TWinControl(C.Controls[I]));
end;

procedure UIDisabledImages(Images: TCustomImageList; Disabled: HIMAGELIST);
var
  I: Integer;
begin
  DisabledFor := Images;
  DisabledList := Disabled;
  for I := 0 to Screen.FormCount - 1 do SyncBars(Screen.Forms[I]);
end;

{ Visual Studio's disabled images: its ImageThemingUtilities.GrayscaleDIBits with its
  ImageLibrary.DefaultGrayscaleBiasColor #40FFFFFF:
  the luminance 0.30 R + 0.59 G + 0.11 B in every channel, the alpha a quarter }
function UIGreyPixel(P: Cardinal): Cardinal;
var
  L: Cardinal;
begin
  L := (30 * ((P shr 16) and $FF) + 59 * ((P shr 8) and $FF) + 11 * (P and $FF)) * 255 div 25600;
  Result := ((P shr 24) div 4) shl 24 or L shl 16 or L shl 8 or L;
end;

{ ---------------------------------------------------------------- a tree's place }

{ a node as its captions from the top level down, each ended by a tab ('' for none) }
function TreeNodePath(N: TTreeNode): string;
begin
  Result := '';
  while N <> nil do
  begin
    Result := N.Text + #9 + Result;
    N := N.Parent;
  end;
end;

{ the node of a TreeNodePath, else the deepest of its parents that is still there }
function FindTreeNodePath(Tree: TTreeView; const Path: string): TTreeNode;
var
  Rest, Part: string;
  N: TTreeNode;
  P: Integer;
begin
  Result := nil;
  Rest := Path;
  N := Tree.Items.GetFirstNode;
  while Rest <> '' do
  begin
    P := Pos(#9, Rest);
    Part := Copy(Rest, 1, P - 1);
    Delete(Rest, 1, P);
    while (N <> nil) and (N.Text <> Part) do N := N.getNextSibling;
    if N = nil then Exit;
    Result := N;
    N := N.getFirstChild;
  end;
end;

function UISaveTreePlace(Tree: TTreeView): TUITreePlace;
begin
  Result.TopPath := TreeNodePath(Tree.TopItem);
  Result.SelPath := TreeNodePath(Tree.Selected);
end;

procedure UIListSortArrow(List: TCustomListView; Column: Integer; Ascending: Boolean);
var
  H: HWND;
  HI: THDItem;
  I, F: Integer;
begin
  if not List.HandleAllocated then Exit;
  H := ListView_GetHeader(List.Handle);
  for I := 0 to Header_GetItemCount(H) - 1 do
  begin
    FillChar(HI, SizeOf(HI), 0);
    HI.Mask := HDI_FORMAT;
    Header_GetItem(H, I, HI);
    F := HI.fmt and not (HDF_SORTUP or HDF_SORTDOWN);
    if I = Column then
      if Ascending then F := F or HDF_SORTUP else F := F or HDF_SORTDOWN;
    if F <> HI.fmt then
    begin
      HI.fmt := F;
      Header_SetItem(H, I, HI);
    end;
  end;
end;

procedure UIPassKeyboard(Hidden, Shown: TWinControl);
var
  A: TWinControl;
begin
  A := Screen.ActiveControl;
  if (Hidden = nil) or (Shown = nil) or (Hidden = Shown) or (A = nil) then Exit;
  if ((A = Hidden) or Hidden.ContainsControl(A)) and Shown.CanFocus then Shown.SetFocus;
end;

procedure UIRestoreTreePlace(Tree: TTreeView; const Place: TUITreePlace);
var
  N, P: TTreeNode;
begin
  N := FindTreeNodePath(Tree, Place.SelPath);
  if N <> nil then
  begin
    P := N.Parent;
    while (P <> nil) and P.Expanded do P := P.Parent;
    if P = nil then Tree.Selected := N;
  end;
  N := FindTreeNodePath(Tree, Place.TopPath);
  if N = nil then N := Tree.Items.GetFirstNode;
  if N <> nil then Tree.TopItem := N;
end;

type
  { UITreeNoDblClickToggle's hook: the tree's NM_DBLCLK is answered "handled", which keeps the
    tree from toggling the node hit (its default processing) - what the double click's OnDblClick
    then does (a tree made anew, its nodes opened) is left alone; the point of the double click }
  TDblClickHook = class(TUIWindowHook)
  private
    FPos: TPoint;                   // the double click's point (client)
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TDblClickHook.Hook(var Message: TMessage);
begin
  if Message.Msg = WM_LBUTTONDBLCLK then
    FPos := Point(SmallInt(LoWord(Message.LParam)), SmallInt(HiWord(Message.LParam)))
  else if (Message.Msg = CN_NOTIFY) and (TWMNotify(Message).NMHdr^.code = NM_DBLCLK) then
  begin
    Message.Result := 1;
    Exit;
  end;
  FOldProc(Message);
end;

procedure UITreeNoDblClickToggle(Tree: TCustomTreeView);
begin
  if UIFindHook(Tree, TDblClickHook) = nil then TDblClickHook.Create(Tree, True);
end;

function UITreeDblClickNode(Tree: TCustomTreeView): TTreeNode;
var
  H: TDblClickHook;
begin
  Result := nil;
  H := TDblClickHook(UIFindHook(Tree, TDblClickHook));
  if (H <> nil) and not (htOnButton in Tree.GetHitTestInfoAt(H.FPos.X, H.FPos.Y)) then
    Result := Tree.GetNodeAt(H.FPos.X, H.FPos.Y);
end;

{ ---------------------------------------------------------------- the clipboard }

function UIOpenClipboard(Wnd: HWND): Boolean;
var
  I: Integer;
begin
  { another program may hold the clipboard a moment }
  Result := OpenClipboard(Wnd);
  I := 0;
  while not Result and (I < 10) do
  begin
    Sleep(10);
    Inc(I);
    Result := OpenClipboard(Wnd);
  end;
end;

function UIClipboardSet(Format: UINT; Data: Pointer; Size: Integer): Boolean;
var
  G: HGLOBAL;
  D: Pointer;
begin
  Result := False;
  G := GlobalAlloc(GMEM_MOVEABLE, Size);
  if G = 0 then Exit;
  D := GlobalLock(G);
  if D = nil then
  begin
    GlobalFree(G);
    Exit;
  end;
  Move(Data^, D^, Size);
  GlobalUnlock(G);
  { the clipboard owns the memory once it took it }
  Result := SetClipboardData(Format, G) <> 0;
  if not Result then GlobalFree(G);
end;

function UIClipboardGet(Format: UINT; out Data: string): Boolean;
var
  H: THandle;
  P: Pointer;
begin
  Data := '';
  Result := False;
  H := GetClipboardData(Format);
  if H = 0 then Exit;
  P := GlobalLock(H);
  if P = nil then Exit;
  try
    SetString(Data, PChar(P), GlobalSize(H));
  finally
    GlobalUnlock(H);
  end;
  Result := True;
end;

initialization

finalization
  if MenuCBT <> 0 then UnhookWindowsHookEx(MenuCBT);
  if CheckFont <> 0 then DeleteObject(CheckFont);
  FreeTurnCache;
  UICloseTreeTheme;
  FreeAndNil(UIFont);
  FreeAndNil(EraseCounts);

end.
