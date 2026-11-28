{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDock;

{ D7 Studio - the dock: tool views in tabbed groups, the groups in areas along the edges of a
  centre. Reusable: it knows nothing of the main window.

  TSdDock is a control (fill a panel with it: Align = alClient). It holds
  * the centre (Center): the control between the areas - the editor in D7 Studio;
  * areas (AddArea): strips along an edge. Each area takes its strip from what the areas added
    before it left, so the order of AddArea decides which area spans which (left, right, then
    bottom: the bottom area lies under the centre only). An area without visible groups takes
    no room. A column (AddColumn) is an area beside the areas of an edge, made by a drop and
    gone with its last group: the views side by side. An outer area (AddArea's AOuter) lies
    along the dock's own edge: added before the areas across it, it spans the whole edge (a
    bottom area across the full width, under the left and right areas). A drop on the band at
    that edge of the dock puts views into it while its edge's outer areas take no room, else into
    a new row at the dock's edge: an outer column, before the other outer areas of the edge.
    Centre areas (AddCenterArea) lie inside the centre, under its header (CenterHeader: a control
    the dock places across the top of the centre - the file tabs in D7 Studio), at an edge of what
    the other areas left to it: laid out after all the others, they share the centre with the
    control Center, which gets the rest;
  * groups: stacked in an area (left/right: top to bottom; top/bottom: side by side) with a
    3 px splitter between them; every group but the last has its size, the last the rest. A
    group has a caption (the titles of its visible panels - "Project Manager, Structure" - a
    close box for all of them, the caption menu) and, while more than one of its panels is
    visible, a strip of tabs on the side of the view the user chose (TSdDockTabs, a
    TSdTabStrip). The pin on the caption hides a group at the edge (auto hide):
    its views become tabs of the area's strip along the dock's edge (TSdDockAutoTabs) and the
    group slides out over the centre while it is wanted;
  * panels (AddPanel, AddTab): one tool view each - any control, with a name for the settings
    and a title for the caption.

  No flicker, by construction:
  * every control is a child of the dock and keeps that parent: moving a panel or a group only
    changes bounds. (The VCL destroys the window of a control that changes its parent and
    creates it again - a visible flash, and list and tree views stream their items through it.)
  * Layout positions everything with one DeferWindowPos batch that also shows the views that
    appear and hides the ones that go: a tab switch never uncovers the background;
  * the dock clips its children and paints only the splitter gaps; its window class does not
    repaint everything on a resize; the tab strips paint without erasing first.

  Dragging a caption or the free part of a tab strip moves the group, dragging a tab moves
  that panel. Dock guides (TSdDockGuide, Visual Studio's) show where it can dock, and a drop
  docks only on one of their buttons: the outer guides at the dock's left and right edges put it
  into the area beside the centre there (a new column beside that edge's areas while the edge
  shows another group), the one at the bottom edge into the full-width outer area (a new row at
  the dock's edge while that shows a group); the compass in the middle of what is under the
  pointer makes it a tab of a group or a group of its own before or after it, a tab of a floating
  group, or - over the centre - puts it into the centre area of a side of Center, or into the
  area below the centre. A translucent window marks the target of the button under the pointer.
  Esc, or another window taking the mouse, ends a drag of a caption, a tab or a splitter without
  a change.

  Floating: a group dropped anywhere but on a guide (and not on its own place) floats in a window of its own
  (TDockFloatForm, owned by the dock's form), with its caption, tabs and views; FloatGroup /
  FloatPanel do it without a drag. Its caption moves the window, and over a target docks it
  again; a double click on it, or DockBack, puts it back where it was docked last. Views dropped
  onto it become its tabs. Floating groups belong to an area of their own (Float) that takes no
  room in the dock. Their parts are children of their window - the one exception to "keeps its
  parent", which happens only when a group floats or docks again, while it is hidden. The
  changes a drag ends with are made by a posted message (WM_SDDOCKDROP): they give the caption
  or the tab strip that holds the mouse another parent, which may not happen in its own handler.

  Float-only views (SetFloatOnly): one floats alone in its window and never docks - a drag of
  its caption only moves the window, the menu commands, DockBack and the double click on the
  caption change nothing, no view is dropped into its group, and a saved arrangement that has it
  docked or among other views is taken as floating alone (KeepFloatOnly). }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Menus, IniFiles, ExtCtrls, ComCtrls,
  ImgList, SdUI, SdTabStrip, SdDockFloat;

const
  WM_SDDOCKRELEASE = WM_APP + $101;     // frees the groups that lost their last panel
  WM_SDDOCKSLIDEIN = WM_APP + $102;     // a click outside the group that slid out
  WM_SDDOCKDROP = WM_APP + $103;        // the change a drag ended with (DragStage)
  WM_SDDOCKBACK = WM_APP + $104;        // a double click on a floating caption: WParam the group

type
  TSdDockEdge = (deLeft, deTop, deRight, deBottom);
  { an area beside the centre, along the dock's own edge (AddArea's AOuter, its rows), or inside
    the centre (AddCenterArea) }
  TSdDockAreaKind = (dkBeside, dkOuter, dkCenter);
  TSdDockDragStage = (ddStart, ddMove, ddEnd);

  TSdDock = class;
  TSdDockGroup = class;
  TSdDockCaption = class;
  TSdDockTabs = class;
  TSdDockAutoTabs = class;
  TSdDockStatus = class;

  { one tool view: a control with a name (settings, test commands) and a title (caption) }
  TSdDockPanel = class
  private
    FDock: TSdDock;
    FControl: TControl;
    FName: string;
    FTitle: string;
    FTabText: string;
    FFormerName: string;
    FGroup: TSdDockGroup;
    FVisible: Boolean;
    FPopupMenu: TPopupMenu;
    FFocusControl: TWinControl;
    FShowStatus: Boolean;
    FStatusText: string;
    FToolBar: TToolBar;             // the view's tool bar, laid out by the dock (nil: none)
    FFloatOnly: Boolean;            // floats alone, never docks (SetFloatOnly)
    FFloatHome: TRect;              // ... its window's first place
    FImageIndex: Integer;           // the icon of the dock's Images before its tab's title, -1 none
    FTabTextColor: TColor;          // its tab's title colour, clNone the state's
    procedure SetImageIndex(Value: Integer);
    procedure SetTabTextColor(Value: TColor);
    procedure LooksChanged;
    function GetTabText: string;
    procedure SetTitle(const Value: string);
    procedure SetTabText(const Value: string);
    procedure TextChanged;
    procedure SetShowStatus(Value: Boolean);
    procedure SetStatusText(const Value: string);
    procedure SetToolBar(Value: TToolBar);
  public
    function Showing: Boolean;          // visible, the active panel of its group, and on the screen
    property Control: TControl read FControl;
    property Name: string read FName;
    property Title: string read FTitle write SetTitle;
    property TabText: string read GetTabText write SetTabText;   // default: the title
    { the name a saved arrangement may still give the view (a view that took the place of another):
      FindPanel finds it by that name too }
    property FormerName: string read FFormerName write FFormerName;
    property Group: TSdDockGroup read FGroup;
    property Visible: Boolean read FVisible;
    { the panel's menu, also on its caption and its tab (default: the dock's CaptionMenu) }
    property PopupMenu: TPopupMenu read FPopupMenu write FPopupMenu;
    { the control inside the view that gets the keyboard when the view is focused (default: the
      first control in the view's tab order, or the view itself when it has none) }
    property FocusControl: TWinControl read FFocusControl write FFocusControl;
    { a status line at the foot of the view (the Project Manager's: Delphi 7's Status Bar) and
      what it says }
    property ShowStatus: Boolean read FShowStatus write SetShowStatus;
    property StatusText: string read FStatusText write SetStatusText;
    { the view's tool bar (one of its .dfm): the dock lays it out under the caption (and tabs on
      top), above the view, while the view is shown - in the look of every view's bar
      (UIViewToolBar), on its own ground - and moves it with the view }
    property ToolBar: TToolBar read FToolBar write SetToolBar;
    property FloatOnly: Boolean read FFloatOnly;
    { an icon of the dock's Images before the title on its tabs (the group's and the auto-hide
      strip's): -1 none (the default) }
    property ImageIndex: Integer read FImageIndex write SetImageIndex;
    { the colour of the title on its tabs (the Error List's red while there are errors): clNone
      (the default) the tab state's }
    property TabTextColor: TColor read FTabTextColor write SetTabTextColor;
  end;

  TSdDockArea = class
  private
    FName: string;
    FEdge: TSdDockEdge;
    FSize: Integer;                 // width (left/right) or height (top/bottom) the user gave it
    FGroups: TList;                 // stacking order, hidden groups included
    FBounds, FSplit: TRect;         // where Layout put it and its splitter (empty: no room)
    FStrip: TRect;                  // its auto-hide strip at the dock's edge (empty: none)
    FAutoTabs: TSdDockAutoTabs;     // ... the tabs of its hidden groups' views
    FColumn: Boolean;               // a column beside its edge's areas (AddColumn): goes with its last group
    FBase: TSdDockArea;             // ... the area it is named after, where its groups go home when it goes
    FOuter: Boolean;                // along the dock's own edge (AddArea's AOuter, its rows): its own drop band
    FInCenter: Boolean;             // inside the centre, under its header (AddCenterArea)
    FSpan: TRect;                  // what was left when it took its strip (Layout) ...
    FRoom: TRect;                   // ... and its room: it lies at that rectangle's edge
  public
    destructor Destroy; override;
    function Vertical: Boolean;     // groups stacked top to bottom (left and right areas)
    function Kind: TSdDockAreaKind;
    property Name: string read FName;
    property Edge: TSdDockEdge read FEdge;
    property Outer: Boolean read FOuter;
    property InCenter: Boolean read FInCenter;
  end;

  TSdDockGroup = class
  private
    FDock: TSdDock;
    FArea: TSdDockArea;
    FPanels: TList;                 // tab order, hidden panels included
    FActive: TSdDockPanel;
    FSize: Integer;                 // along its area, as the user gave it
    FCaption: TSdDockCaption;
    FTabs: TSdDockTabs;
    FStatus: TSdDockStatus;         // the status line of the shown panel (ShowStatus)
    FTabSide: TUITabSide;           // where its tabs lie next to its views (the user chooses)
    FAutoHide: Boolean;             // unpinned: hidden at the edge, slides out when wanted
    FBounds, FSplit: TRect;         // in its host: the dock, or its floating window
    FFloat: TDockFloatForm;         // its window while it floats (made when the dock's form has one)
    FFloatRect: TRect;              // the window's place on the screen (also kept while docked)
    FHomeArea: TSdDockArea;         // where it was docked last (DockBack) ...
    FHomeIndex: Integer;            // ... before the Index-th visible group there (-1: last)
    function GetPanel(Index: Integer): TSdDockPanel;
    function GetPanelCount: Integer;
    function NextVisible(From: TSdDockPanel): TSdDockPanel;
    function ShowsTabs: Boolean;
    function TabsRect: TRect;       // in the dock; empty while it shows no tabs (ShowsTabs)
    function ShowsStatus: Boolean;
    function StatusRect: TRect;     // at the foot of the view (empty while it shows none)
    function ContentRect: TRect;    // the active view's with its tool bar
    function BarHeight: Integer;    // ... its tool bar's (0: none)
    function BarRect: TRect;        // ... its tool bar's place, at the top (empty: none)
    function ViewRect: TRect;
  public
    destructor Destroy; override;
    function VisibleCount: Integer;
    function Floating: Boolean;     // in a window of its own (the Float area)
    function FloatOnly: Boolean;    // it holds a float-only view (it never docks)
    property TabSide: TUITabSide read FTabSide;
    property AutoHide: Boolean read FAutoHide;
    property Area: TSdDockArea read FArea;
    property HomeArea: TSdDockArea read FHomeArea;
    property Active: TSdDockPanel read FActive;
    property PanelCount: Integer read GetPanelCount;
    property Panels[Index: Integer]: TSdDockPanel read GetPanel;
  end;

  { the status line at the foot of a view: its panel's StatusText inside the view's flat frame, a
    long path shortened in the middle; painted through a bitmap in one pass, never erased }
  TSdDockStatus = class(TSdControl)
  private
    FText: string;
    procedure SetText(const Value: string);
  protected
    procedure PaintBuffer(C: TCanvas); override;
  public
    constructor Create(AOwner: TComponent); override;
    property Text: string read FText write SetText;
  end;

  { the edge of the group that is out, towards the centre: its area's splitter while the group
    lies over the centre. The dock does the drag (its MouseDown / MouseMove / MouseUp, in its own
    coordinates); painted as the dock's gaps }
  TSdDockSizer = class(TSdControl)
  private
    FDock: TSdDock;
    FEdge: TSdDockEdge;             // the edge of the group's area
    procedure SetEdge(Value: TSdDockEdge);
  protected
    procedure PaintBuffer(C: TCanvas); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    property Edge: TSdDockEdge read FEdge write SetEdge;
  end;

  { the caption of a group: the titles of its visible panels on a bar in the colour of the title
    bars, the pin and the close box; painted through a bitmap, never erased }
  TSdDockCaption = class(TSdControl)
  private
    FGroup: TSdDockGroup;
    FTitle: string;
    FButtons: TSdPressBoxes;        // 0 the pin, 1 the close box
    procedure SetTitle(const Value: string);
    function ButtonOf(Index: Integer; out R: TRect): Boolean;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure WMLButtonDblClk(var Message: TWMLButtonDblClk); message WM_LBUTTONDBLCLK;
  protected
    procedure PaintBuffer(C: TCanvas); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Title: string read FTitle write SetTitle;
    property Group: TSdDockGroup read FGroup;
  end;

  { the dock's strips of tabs: a tab per panel (its tab text; the panel its object, its name in
    the test dump) }
  TSdDockStrip = class(TSdTabStrip)
  protected
    function TabName(Index: Integer): string; override;
    function TabImage(Index: Integer): Integer; override;       // the panel's ImageIndex
    function TabImages: TCustomImageList; override;            // the dock's Images
    function TabTextColor(Index: Integer): TColor; override;    // the panel's TabTextColor
    procedure SetPanels(L: TList);  // the tabs of the panels of L (made again only when they changed)
  public
    function TabPanel(Index: Integer): TSdDockPanel;
  end;

  { The tabs of a group, on the side of its view the user chose (below by default): one per
    visible panel, in the group's order. A click shows
    the panel and gives it the keyboard (no close boxes: Close in its menu); a drag along the strip moves
    the tab (the group's order), a drag out of it docks the panel elsewhere; a drag from the
    strip beside the tabs moves the group, as one of the caption. }
  TSdDockTabs = class(TSdDockStrip)
  private
    FGroup: TSdDockGroup;
  protected
    procedure Choose(Index: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    procedure Changed;              // the group's visible panels, their order, texts or the shown one
    property Group: TSdDockGroup read FGroup;
  end;

  { The auto-hide strip of an area, along the dock's edge: a tab for every visible view of the
    area's hidden groups. A click slides the view's group out and gives the view the keyboard;
    resting the pointer on a tab slides it out without. }
  TSdDockAutoTabs = class(TSdDockStrip)
  private
    FArea: TSdDockArea;
    FDock: TSdDock;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  protected
    procedure Choose(Index: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
  public
    procedure Changed;
    { the panel whose tab the pointer is on now; nil: none, also where another window covers the
      strip }
    function PointerPanel: TSdDockPanel;
  end;
  { The window the dock moves for the centre. It has no CS_HREDRAW / CS_VREDRAW: when it moves
    and changes size, Windows copies the pixels of everything inside it to the new place. A
    window with those class styles (a TPanel) has its pixels - and those of all its children:
    the editor, the design surface, the form being designed - thrown away instead, and all of
    it repaints on every step of a splitter drag. }
  TSdDockHost = class(TCustomControl)
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  { where a dragged panel or group goes }
  TSdDockTarget = record
    Area: TSdDockArea;
    Index: Integer;                 // before the Index-th visible group of Area; -1: last
    Group: TSdDockGroup;            // not nil: as a tab of this group
    Column: Boolean;                // a new column beside the areas of Area's edge (AddColumn; Area its base)
  end;

  { what a dock guide's button shows: the view as a tab, or docked at that side }
  TSdGuideKind = (gkTab, gkLeft, gkTop, gkRight, gkBottom);

  { a button of the dock guides: its place on the screen, what it shows - Edge: beside the centre
    or along the dock's edge, a thin strip at that side, else inside what it is over, a half -,
    and where a drop on it docks (Mark: the drop marker, on the screen) }
  TSdGuideButton = record
    Bounds: TRect;
    Kind: TSdGuideKind;
    Edge: Boolean;
    Target: TSdDockTarget;
    Mark: TRect;
  end;

  { A window of the dock guides while a group or a view is dragged: the compass over what lies
    under the pointer, or an outer guide at an edge of the dock. Visual Studio's guides - the
    buttons on a pale backdrop with a soft shadow, the one under the pointer highlighted - drawn
    with per-pixel alpha (UpdateLayeredWindow); never activated, the mouse passes through it. }
  TSdDockGuide = class(TForm)
  private
    FButtons: array of TSdGuideButton;
    FBacks: array of TRect;         // the backdrop: these rectangles (screen), the buttons on them
    FHot: Integer;                  // the button under the pointer (-1: none)
    FDrawn: string;                 // what the window shows now (Render draws only a change)
    FFailed: Boolean;               // UpdateLayeredWindow refused the last drawing (the test dump's !)
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
  public
    procedure Clear;
    procedure AddBack(const R: TRect);
    procedure AddButton(const R: TRect; Kind: TSdGuideKind; Edge: Boolean; const T: TSdDockTarget;
      const Mark: TRect);
    function ButtonAt(const P: TPoint): Integer;
    function ButtonCount: Integer;
    function Button(Index: Integer): TSdGuideButton;
    { drawn (only a change) and shown above every window when it appears or Lift (hidden without
      buttons), Hot highlighted }
    procedure Render(Hot: Integer; Lift: Boolean = False);
    procedure HideGuide;
  end;

  TSdDockPanelEvent = procedure(Sender: TObject; Panel: TSdDockPanel) of object;

  TSdDock = class(TCustomControl)
  private
    FCenter: TControl;
    FCenterHost: TSdDockHost;
    FCenterHeader: TControl;
    FCenterRect: TRect;             // what the areas left: the header, the centre areas and FPageRect
    FHeaderRect: TRect;             // ... the header's part at its top (empty while it is hidden)
    FPageRect: TRect;               // ... Center's: what the header and the centre areas left
    FAreas: TList;
    FPanels: TList;                 // in the order they were added
    FDead: TList;                   // groups without panels, freed by WM_SDDOCKRELEASE
    FCaptionMenu: TPopupMenu;
    FImages: TCustomImageList;
    FAutoDragDocking: Boolean;
    FOnPanelShow: TSdDockPanelEvent;
    FOnPanelHide: TSdDockPanelEvent;
    FInLayout: Boolean;
    { a drag of a caption (the group) or of a tab (the panel) }
    FDragControl: TControl;
    FDragGroup: TSdDockGroup;
    FDragPanel: TSdDockPanel;
    FDragOrder: Integer;            // the panel's place in its group when the drag began
    FReorderAt: Integer;            // ... the pointer along its strip at the last move (ReorderTab)
    FDragFrom: TPoint;
    FDragging: Boolean;
    FDragWindow: TPoint;            // a floating group's window: where it was when the drag began
    FDragGrab: TPoint;              // the pointer from the top left of the dragged group
    FMarker: TForm;
    { the dock guides of a drag: 0 the compass, 1 - 3 the outer guides (left, right, bottom); what
      the compass lies over (a group, the dock itself for the centre, nil: none), and the button
      under the pointer (window, button; -1: none) }
    FGuides: array[0..3] of TSdDockGuide;
    FGuideHost: TObject;
    FGuideRect: TRect;              // the compass's backdrop on the screen (empty: none)
    FLiftGuides: Boolean;           // the marker has just appeared: the guides go above it (ShowGuides)
    FHotGuide, FHotButton: Integer;
    { floating: the area of the floating groups (not one of Areas: it takes no room), whether
      their windows may be shown (FloatsShown), and the change a drag ended with (WM_SDDOCKDROP) }
    FFloatArea: TSdDockArea;
    FFloatsShown: Boolean;
    FPendGroup: TSdDockGroup;
    FPendPanel: TSdDockPanel;
    FPendTarget: TSdDockTarget;
    FPendFloat: Boolean;            // ... float at FPendRect, else dock at FPendTarget
    FPendRect: TRect;
    { a drag of a splitter: an area's, or the one after a group }
    FSplitArea: TSdDockArea;
    FSplitGroup, FSplitNext: TSdDockGroup;
    FSplitFrom: TPoint;
    FSplitSize, FSplitRoom: Integer;
    FSplitOld, FSplitOldNext: Integer;   // the sizes before it (a cancelled drag)
    { auto hide: the group that slid out, how, and the timers }
    FSlid: TSdDockGroup;
    FSlidByHover: Boolean;          // the pointer rested on its tab (it goes when the pointer does)
    FSlidFocused: Boolean;          // the keyboard has been in it (it goes when the keyboard does)
    FSlideSerial: Cardinal;         // counts the slides out: a posted slide in names the one it ends
    FSlideSizer: TSdDockSizer;      // its edge towards the centre ...
    FSlideSplit: TRect;             // ... where Layout put it (empty: no group out)
    FSlideRoom: Integer;            // ... the most the group may take there (a drag of the edge)
    FAutoTimer: TTimer;
    FHoverTimer: TTimer;
    FHoverPanel: TSdDockPanel;
    FFocusGroup: TSdDockGroup;      // the keyboard is in it: its caption in the active colours
    FKeepFocus: TWinControl;        // had the keyboard when its view went to another window: Layout gives it back
    function GetArea(Index: Integer): TSdDockArea;
    function GetAreaCount: Integer;
    function GetPanel(Index: Integer): TSdDockPanel;
    function GetPanelCount: Integer;
    procedure SetCenter(Value: TControl);
    procedure SetCenterHeader(Value: TControl);
    procedure SetCaptionMenu(Value: TPopupMenu);
    function MenuOf(P: TSdDockPanel): TPopupMenu;
    procedure SetGroupMenus(G: TSdDockGroup);
    procedure Adopt(C: TControl);
    function AllGroups: TList;
    function VisibleGroups(A: TSdDockArea): TList;
    function GroupAt(A: TSdDockArea; Index: Integer): TSdDockGroup;
    function AreaLength(A: TSdDockArea): Integer;
    function NewGroup(A: TSdDockArea; Before: TSdDockGroup): TSdDockGroup;
    function NewPanel(AControl: TControl; const AName, ATitle: string; G: TSdDockGroup): TSdDockPanel;
    procedure PlaceGroup(G: TSdDockGroup; A: TSdDockArea; Before: TSdDockGroup);
    procedure Join(P: TSdDockPanel; G: TSdDockGroup);
    procedure Detach(P: TSdDockPanel);
    procedure ReleaseGroup(G: TSdDockGroup);
    procedure FreeDead;
    procedure MakeRoom(G: TSdDockGroup; Moved: Boolean);
    procedure KeepSize(G: TSdDockGroup);
    procedure LayoutGroups(A: TSdDockArea);
    procedure SyncGroup(G: TSdDockGroup);
    procedure Apply(Fresh: TList);
    procedure ChooseTab(P: TSdDockPanel);
    procedure ReorderTab(T: TSdDockTabs; X: Integer);
    function CanDock: Boolean;
    procedure DragCursor(C: TCursor);
    procedure DragStage(C: TControl; Stage: TSdDockDragStage; X, Y: Integer);
    procedure CancelDrag(Restore: Boolean);
    procedure PressCancelled(Sender: TObject);
    function Guide(Index: Integer): TSdDockGuide;
    procedure BuildGuides(const P: TPoint);
    procedure BuildCompass(const P: TPoint);
    procedure ShowGuides;
    procedure HideGuides;
    function GuideTarget(var T: TSdDockTarget; var R: TRect): Boolean;
    function GroupUnder(const P: TPoint): TSdDockGroup;
    procedure BesideTarget(A: TSdDockArea; var T: TSdDockTarget; var R: TRect);
    procedure OuterTarget(A: TSdDockArea; var T: TSdDockTarget; var R: TRect);
    procedure CenterTarget(A: TSdDockArea; var T: TSdDockTarget; var R: TRect);
    procedure GroupTarget(G: TSdDockGroup; Kind: TSdGuideKind; var T: TSdDockTarget; var R: TRect);
    function FloatAt(const P: TPoint): TSdDockGroup;
    function WouldChange(const T: TSdDockTarget): Boolean;
    function DragSource: TSdDockGroup;
    function SourceRect: TRect;
    function WouldFloat(const P: TPoint): Boolean;
    function FloatRectAt(const P: TPoint): TRect;
    function IsGroup(G: TSdDockGroup): Boolean;
    procedure WMDrop(var Message: TMessage); message WM_SDDOCKDROP;
    procedure WMDockBack(var Message: TMessage); message WM_SDDOCKBACK;
    procedure PutControl(C: TControl; Host: TWinControl);
    function HostOf(G: TSdDockGroup): TWinControl;
    procedure MoveParts(G: TSdDockGroup; Host: TWinControl);
    function EnsureFloat(G: TSdDockGroup): Boolean;
    procedure Unfloat(G: TSdDockGroup);
    procedure KeepFloatOnly;
    function NewArea(const AName: string; AEdge: TSdDockEdge; ASize: Integer): TSdDockArea;
    function EdgeShows(Edge: TSdDockEdge; Kind: TSdDockAreaKind; Moving: TSdDockGroup): Boolean;
    function FirstArea(Edge: TSdDockEdge; Kind: TSdDockAreaKind): TSdDockArea;
    function FirstInnerArea: TSdDockArea;
    function NewColumn(Base: TSdDockArea; const AName: string; Loading: Boolean): TSdDockArea;
    function AddColumn(Base: TSdDockArea): TSdDockArea;
    procedure PlaceColumn(A: TSdDockArea; Loading: Boolean);
    function ColumnRect(A: TSdDockArea): TRect;
    {$HINTS OFF}
    function EdgeBand(const R: TRect; Edge: TSdDockEdge): TRect;
    {$HINTS ON}
    function DragWhole: TSdDockGroup;
    function ColumnNamed(const AName: string): TSdDockArea;
    procedure DropEmptyColumns;
    procedure FloatResize(Sender: TObject);
    procedure ShowFloats;
    procedure SetFloatsShown(Value: Boolean);
    procedure ShowMarker(const R: TRect);
    procedure HideMarker;
    function SplitAt(const P: TPoint; var A: TSdDockArea; var G: TSdDockGroup): Boolean;
    procedure WMRelease(var Message: TMessage); message WM_SDDOCKRELEASE;
    procedure WMSlideIn(var Message: TMessage); message WM_SDDOCKSLIDEIN;
    procedure DropSlide;
    procedure HoverPanel(P: TSdDockPanel);
    procedure HoverTick(Sender: TObject);
    procedure AutoTick(Sender: TObject);
    function FocusInside(G: TSdDockGroup): Boolean;
    procedure KeepFocusIn(C: TControl);
    procedure RestoreFocus;
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure Resize; override;
    procedure AlignControls(AControl: TControl; var Rect: TRect); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { an area along AEdge, ASize wide (left/right) or high (top/bottom); AOuter: along the dock's
      own edge - added before the areas across it, it spans the whole edge (see the unit's header) }
    function AddArea(const AName: string; AEdge: TSdDockEdge; ASize: Integer;
      AOuter: Boolean = False): TSdDockArea;
    { an area inside the centre along AEdge, under the header (see the unit's header): the centre
      areas are laid out after all the others, in the order they were added }
    function AddCenterArea(const AName: string; AEdge: TSdDockEdge; ASize: Integer): TSdDockArea;
    { AControl as a group of its own at the end of AArea (ASize along the area, 0: a third) }
    function AddPanel(AControl: TControl; const AName, ATitle: string; AArea: TSdDockArea;
      ASize: Integer = 0): TSdDockPanel;
    { AControl as another tab of AWith's group }
    function AddTab(AControl: TControl; const AName, ATitle: string; AWith: TSdDockPanel): TSdDockPanel;
    function FindArea(const AName: string): TSdDockArea;
    function FindPanel(const AName: string): TSdDockPanel;
    { the panel of a caption or tab strip (its group's active panel) or of a panel's control }
    function PanelOf(C: TComponent): TSdDockPanel;
    procedure ShowPanel(P: TSdDockPanel);           // visible and active in its group
    procedure FocusPanel(P: TSdDockPanel);          // the keyboard to its view (a click on the caption)
    procedure HidePanel(P: TSdDockPanel);
    procedure HideGroup(G: TSdDockGroup);           // the close box
    procedure MovePanel(P: TSdDockPanel; A: TSdDockArea; Index: Integer = -1);   // a group of its own
    procedure MoveGroup(G: TSdDockGroup; A: TSdDockArea; Index: Integer = -1);
    procedure TabPanel(P: TSdDockPanel; G: TSdDockGroup);                         // a tab of G
    procedure MergeGroup(G, Target: TSdDockGroup);                                // all of G into Target
    { floating: in a window of its own at R (screen; empty: where it floated last, else beside
      its place), and back where it was docked last }
    procedure FloatGroup(G: TSdDockGroup; const R: TRect);
    procedure FloatPanel(P: TSdDockPanel; const R: TRect);                        // a group of its own
    procedure DockBack(G: TSdDockGroup);
    { a floating window for one view of AWidth x AHeight (no tabs, no status line), in the
      middle of the work area }
    function FloatRectFor(AWidth, AHeight: Integer): TRect;
    { P floats alone in a window of its own and never docks (see the unit's header); R: its
      window's first place }
    procedure SetFloatOnly(P: TSdDockPanel; const R: TRect);
    procedure SetTabSide(G: TSdDockGroup; Side: TUITabSide);    // its tabs below, above, left or right
    procedure SetAutoHide(G: TSdDockGroup; Value: Boolean);     // the pin: unpinned it hides at the edge
    procedure SlideOut(P: TSdDockPanel; ByHover: Boolean);      // P's hidden group over the centre
    procedure SlideIn;                                          // ... back to the edge
    function InSlide(Wnd: HWND): Boolean;                       // a window of the group that slid out
    procedure FocusChanged;                                     // Screen.OnActiveControlChange
    property FocusGroup: TSdDockGroup read FFocusGroup;
    procedure Layout;
    procedure Load(Ini: TCustomIniFile; const Section: string);
    procedure Save(Ini: TCustomIniFile; const Section: string);
    function DebugText: string;
    function DebugTabs: string;
    property Center: TControl read FCenter write SetCenter;
    { a control across the top of the centre, above the centre areas and Center, as high as it is
      and only while it is visible; it becomes a child of the dock, and a change of its height or
      its visibility lays the dock out again }
    property CenterHeader: TControl read FCenterHeader write SetCenterHeader;
    property AreaCount: Integer read GetAreaCount;
    property Areas[Index: Integer]: TSdDockArea read GetArea;
    property PanelCount: Integer read GetPanelCount;
    property Panels[Index: Integer]: TSdDockPanel read GetPanel;
    { the menu of the captions and the tab strips of panels without a PopupMenu of their own
      (PopupComponent says which was clicked) }
    property CaptionMenu: TPopupMenu read FCaptionMenu write SetCaptionMenu;
    { the icons of the panels' tabs (TSdDockPanel.ImageIndex) }
    property Images: TCustomImageList read FImages write FImages;
    { False: a drag docks only while Ctrl is held (Delphi's Auto drag docking option) }
    property AutoDragDocking: Boolean read FAutoDragDocking write FAutoDragDocking;
    { a panel's control has just become visible (its tab chosen, or the panel shown) }
    property OnPanelShow: TSdDockPanelEvent read FOnPanelShow write FOnPanelShow;
    { a visible panel has just been hidden by HidePanel or HideGroup (its close box, Close, the
      code's), after the layout; an arrangement applied (Load) does not tell }
    property OnPanelHide: TSdDockPanelEvent read FOnPanelHide write FOnPanelHide;
    property Slid: TSdDockGroup read FSlid;                     // the hidden group shown now
    { the floating groups' windows are shown only from when this is True (the main window sets
      it once it is on the screen: they do not appear before it) }
    property FloatsShown: Boolean read FFloatsShown write SetFloatsShown;
  end;

implementation

const
  Gap = 3;                // splitters
  MinArea = 60;           // what an area splitter leaves to the area and to the centre
  ReorderSlack = 6;       // pixels above and below the strip that still move the tab along it
  EdgeZone = 24;          // pixels at the dock's edge that take a panel into an outer area (EdgeBand)
  DockVersion = 2;        // of the settings; 1 = the panes of SdPanes (only the area sizes carry over)
  NoRect: TRect = (Left: 0; Top: 0; Right: 0; Bottom: 0);
  TabSideNames: array[TUITabSide] of string = ('Bottom', 'Top', 'Left', 'Right');

type
  TWinControlAccess = class(TWinControl);

{ the smallest group: a caption, a strip of tabs and 1 px of the view - they follow the UI font }
function MinGroup: Integer;
begin
  Result := UIPaneCaptionHeight + UIDockTabHeight + 1;
end;

{ the part of R from A to B along its height (Vertical) or its width }
function Along(const R: TRect; Vertical: Boolean; A, B: Integer): TRect;
begin
  if Vertical then Result := Rect(R.Left, A, R.Right, B) else Result := Rect(A, R.Top, B, R.Bottom);
end;

function Extent(const R: TRect; Vertical: Boolean): Integer;
begin
  if Vertical then Result := R.Bottom - R.Top else Result := R.Right - R.Left;
end;

{ the part of R that is S thick at its Edge }
function EdgePart(const R: TRect; Edge: TSdDockEdge; S: Integer): TRect;
begin
  case Edge of
    deLeft: Result := Rect(R.Left, R.Top, R.Left + S, R.Bottom);
    deRight: Result := Rect(R.Right - S, R.Top, R.Right, R.Bottom);
    deTop: Result := Rect(R.Left, R.Top, R.Right, R.Top + S);
  else
    Result := Rect(R.Left, R.Bottom - S, R.Right, R.Bottom);
  end;
end;

{ where A would lie at its edge of R: as thick as its size, leaving at least Leave of R (a drop
  marker) }
function AreaPart(A: TSdDockArea; const R: TRect; Leave: Integer): TRect;
var
  S: Integer;
begin
  S := A.FSize;
  if S > Extent(R, not A.Vertical) - Leave then S := Extent(R, not A.Vertical) - Leave;
  if S < 0 then S := 0;
  Result := EdgePart(R, A.FEdge, S);
end;

{ the part of R that is S thick at its Edge, taken off R (R keeps the rest) }
function TakeEdge(var R: TRect; Edge: TSdDockEdge; S: Integer): TRect;
begin
  Result := EdgePart(R, Edge, S);
  case Edge of
    deLeft: R.Left := Result.Right;
    deRight: R.Right := Result.Left;
    deTop: R.Top := Result.Bottom;
  else
    R.Bottom := Result.Top;
  end;
end;

{ the part S thick next to R on its side away from Edge (what lies beside a strip at that edge) }
function Beside(const R: TRect; Edge: TSdDockEdge; S: Integer): TRect;
begin
  case Edge of
    deLeft: Result := Rect(R.Right, R.Top, R.Right + S, R.Bottom);
    deRight: Result := Rect(R.Left - S, R.Top, R.Left, R.Bottom);
    deTop: Result := Rect(R.Left, R.Bottom, R.Right, R.Bottom + S);
  else
    Result := Rect(R.Left, R.Top - S, R.Right, R.Top);
  end;
end;

{ R in Host's client coordinates on the screen }
function ScreenRect(Host: TControl; const R: TRect): TRect;
begin
  Result.TopLeft := Host.ClientToScreen(R.TopLeft);
  Result.BottomRight := Host.ClientToScreen(R.BottomRight);
end;

{ the window of a group that floats for the first time: as large as the group is at B in Host
  (the window's border and margin around it), a little down and right of that place }
function FirstFloatRect(Host: TControl; const B: TRect): TRect;
begin
  Result := ScreenRect(Host, B);
  InflateRect(Result, FloatMargin + 1, FloatMargin + 1);
  OffsetRect(Result, 24, 24);
end;

function SizeKey(A: TSdDockArea): string;
begin
  if A.Vertical then Result := A.Name + 'Width' else Result := A.Name + 'Height';
end;

{ a floating window's place in the settings: left,top,width,height (empty: none) }
function RectToStr(const R: TRect): string;
begin
  Result := Format('%d,%d,%d,%d', [R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top]);
end;

function StrToRect(const S: string): TRect;
var
  L: TStringList;
begin
  Result := NoRect;
  L := TStringList.Create;
  try
    L.CommaText := S;
    if L.Count = 4 then
      Result := Bounds(StrToIntDef(L[0], 0), StrToIntDef(L[1], 0), StrToIntDef(L[2], 0), StrToIntDef(L[3], 0));
  finally
    L.Free;
  end;
end;

{ ---------------------------------------------------------------- TSdDockPanel }

function TSdDockPanel.GetTabText: string;
begin
  if FTabText <> '' then Result := FTabText else Result := FTitle;
end;

{ The project tree's refresh sets the package editor's title and tab text every time: unchanged,
  nothing happens; else the caption and the tabs that show them say it again - nothing moves, so
  nothing is laid out }
procedure TSdDockPanel.SetTitle(const Value: string);
begin
  if Value = FTitle then Exit;
  FTitle := Value;
  TextChanged;
end;

procedure TSdDockPanel.SetTabText(const Value: string);
begin
  if Value = FTabText then Exit;
  FTabText := Value;
  TextChanged;
end;

procedure TSdDockPanel.TextChanged;
begin
  if FGroup = nil then Exit;
  FDock.SyncGroup(FGroup);
  if (FGroup.FArea <> nil) and (FGroup.FArea.FAutoTabs <> nil) then FGroup.FArea.FAutoTabs.Changed;
end;

procedure TSdDockPanel.SetImageIndex(Value: Integer);
begin
  if Value = FImageIndex then Exit;
  FImageIndex := Value;
  LooksChanged;
end;

procedure TSdDockPanel.SetTabTextColor(Value: TColor);
begin
  if Value = FTabTextColor then Exit;
  FTabTextColor := Value;
  LooksChanged;
end;

{ its tabs measured and painted again: the group's and the auto-hide strip's (the titles are the
  same, so their Changed would do nothing) }
procedure TSdDockPanel.LooksChanged;
begin
  if FGroup = nil then Exit;
  FGroup.FTabs.LooksChanged;
  if (FGroup.FArea <> nil) and (FGroup.FArea.FAutoTabs <> nil) then FGroup.FArea.FAutoTabs.LooksChanged;
end;

procedure TSdDockPanel.SetShowStatus(Value: Boolean);
begin
  if Value = FShowStatus then Exit;
  FShowStatus := Value;
  if (FGroup <> nil) and (FGroup.FActive = Self) then FDock.Layout;
end;

procedure TSdDockPanel.SetStatusText(const Value: string);
begin
  FStatusText := Value;
  if (FGroup <> nil) and (FGroup.FActive = Self) then FGroup.FStatus.Text := Value;
end;

procedure TSdDockPanel.SetToolBar(Value: TToolBar);
begin
  if Value = FToolBar then Exit;
  FToolBar := Value;
  if Value = nil then Exit;
  UIViewToolBar(Value);
  if FGroup <> nil then FDock.PutControl(Value, FDock.HostOf(FGroup));
  FDock.Layout;
end;

function TSdDockPanel.Showing: Boolean;
begin
  { a group hidden at the dock's edge is not seen until it slides out (a compile's error did not
    slide Messages out: it counted as shown) }
  Result := FVisible and (FGroup.FActive = Self) and (not FGroup.FAutoHide or (FDock.FSlid = FGroup));
end;

{ ---------------------------------------------------------------- TSdDockArea }

destructor TSdDockArea.Destroy;
begin
  FGroups.Free;
  inherited;
end;

function TSdDockArea.Vertical: Boolean;
begin
  Result := FEdge in [deLeft, deRight];
end;

function TSdDockArea.Kind: TSdDockAreaKind;
begin
  if FInCenter then Result := dkCenter
  else if FOuter then Result := dkOuter
  else Result := dkBeside;
end;

{ ---------------------------------------------------------------- TSdDockGroup }

destructor TSdDockGroup.Destroy;
begin
  FCaption.Free;
  FTabs.Free;
  FStatus.Free;
  FPanels.Free;
  FFloat.Free;                      // after its parts (a window frees the controls it holds)
  inherited;
end;

function TSdDockGroup.Floating: Boolean;
begin
  Result := (FArea <> nil) and (FArea = FDock.FFloatArea);
end;

function TSdDockGroup.FloatOnly: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FPanels.Count - 1 do
    if Panels[I].FFloatOnly then
    begin
      Result := True;
      Exit;
    end;
end;

function TSdDockGroup.GetPanel(Index: Integer): TSdDockPanel;
begin
  Result := TSdDockPanel(FPanels[Index]);
end;

function TSdDockGroup.GetPanelCount: Integer;
begin
  Result := FPanels.Count;
end;

function TSdDockGroup.VisibleCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FPanels.Count - 1 do
    if Panels[I].FVisible then Inc(Result);
end;

{ the group has a strip of tabs: more than one view is visible, and it is not hidden at its edge -
  then the strip there holds its tabs, also while the group is out (no tabs of its own then) }
function TSdDockGroup.ShowsTabs: Boolean;
begin
  Result := (VisibleCount > 1) and not FAutoHide;
end;

{ The caption at the top of the group, the strip of tabs on its side of the view (below, above,
  left or right, under the caption) while it has one (ShowsTabs), the view in the rest }
function TSdDockGroup.TabsRect: TRect;
var
  B: TRect;
  CapH, TabH: Integer;
begin
  B := FBounds;
  CapH := UIPaneCaptionHeight;
  if ShowsTabs then TabH := UIDockTabHeight else TabH := 0;
  case FTabSide of
    tsTop: Result := Rect(B.Left, B.Top + CapH, B.Right, B.Top + CapH + TabH);
    tsLeft: Result := Rect(B.Left, B.Top + CapH, B.Left + TabH, B.Bottom);
    tsRight: Result := Rect(B.Right - TabH, B.Top + CapH, B.Right, B.Bottom);
  else
    Result := Rect(B.Left, B.Bottom - TabH, B.Right, B.Bottom);
  end;
end;

function TSdDockGroup.ContentRect: TRect;
var
  T: TRect;
begin
  Result := FBounds;
  Inc(Result.Top, UIPaneCaptionHeight);
  T := TabsRect;
  case FTabSide of
    tsTop: Result.Top := T.Bottom;
    tsLeft: Result.Left := T.Right;
    tsRight: Result.Right := T.Left;
  else
    Result.Bottom := T.Top;
  end;
  if ShowsStatus then Dec(Result.Bottom, UIDockTabHeight);
end;

function TSdDockGroup.BarHeight: Integer;
begin
  if (FActive <> nil) and (FActive.FToolBar <> nil) then Result := FActive.FToolBar.Height else Result := 0;
end;

{ within the content: a group made lower than the bar shows only that much of it }
function TSdDockGroup.BarRect: TRect;
begin
  Result := ContentRect;
  if Result.Top + BarHeight < Result.Bottom then Result.Bottom := Result.Top + BarHeight;
end;

function TSdDockGroup.ViewRect: TRect;
begin
  Result := ContentRect;
  Result.Top := BarRect.Bottom;
end;

function TSdDockGroup.ShowsStatus: Boolean;
begin
  Result := (FActive <> nil) and FActive.FVisible and FActive.FShowStatus;
end;

function TSdDockGroup.StatusRect: TRect;
begin
  if ShowsStatus then
  begin
    Result := ViewRect;
    Result.Top := Result.Bottom;
    Inc(Result.Bottom, UIDockTabHeight);
  end
  else
    Result := Rect(0, 0, 0, 0);
end;

{ the visible panel that takes over from From: the next one, else the one before }
function TSdDockGroup.NextVisible(From: TSdDockPanel): TSdDockPanel;
var
  I, K: Integer;
begin
  Result := nil;
  K := FPanels.IndexOf(From);
  for I := K + 1 to FPanels.Count - 1 do
    if Panels[I].FVisible and (Panels[I] <> From) then
    begin
      Result := Panels[I];
      Exit;
    end;
  for I := K - 1 downto 0 do
    if Panels[I].FVisible then
    begin
      Result := Panels[I];
      Exit;
    end;
end;

{ ---------------------------------------------------------------- TSdDockStatus }

constructor TSdDockStatus.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque] - [csAcceptsControls, csSetCaption, csParentBackground];
  Height := UIDockTabHeight;
  Buffered := True;
  RedrawWhole := True;
end;

procedure TSdDockStatus.SetText(const Value: string);
begin
  if Value = FText then Exit;
  FText := Value;
  Invalidate;
end;

procedure TSdDockStatus.PaintBuffer(C: TCanvas);
var
  R: TRect;
  Old: HFONT;
  DC: HDC;
begin
  DC := C.Handle;
  R := ClientRect;
  UIFill(DC, R, clBtnFace);
  { inside the view's flat frame: its sides go on down and close under the line - the view's
    bottom line above parts the two }
  UIVLine(DC, R.Left, R.Top, R.Bottom, clBtnShadow);
  UIVLine(DC, R.Right - 1, R.Top, R.Bottom, clBtnShadow);
  UIHLine(DC, R.Left, R.Right, R.Bottom - 1, clBtnShadow);
  InflateRect(R, -4, 0);
  Old := SelectObject(DC, UIFont.Handle);
  UIText(DC, FText, R, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX or
    DT_PATH_ELLIPSIS, clBtnText);
  SelectObject(DC, Old);
end;

{ ---------------------------------------------------------------- TSdDockSizer }

constructor TSdDockSizer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDock := AOwner as TSdDock;
  ControlStyle := ControlStyle + [csOpaque] - [csAcceptsControls, csSetCaption, csParentBackground];
  Buffered := True;
  Cursor := crHSplit;                             // FEdge deLeft
end;

procedure TSdDockSizer.SetEdge(Value: TSdDockEdge);
begin
  if Value = FEdge then Exit;
  FEdge := Value;
  if FEdge in [deLeft, deRight] then Cursor := crHSplit else Cursor := crVSplit;
  Invalidate;
end;

{ the gap beside the group, then a 1 px line against what the group lies over }
procedure TSdDockSizer.PaintBuffer(C: TCanvas);
var
  Line: TRect;
begin
  Line := ClientRect;
  UIFill(C.Handle, TakeEdge(Line, FEdge, Extent(Line, FEdge in [deTop, deBottom]) - 1), FDock.Color);
  UIFill(C.Handle, Line, clBtnShadow);
end;

procedure TSdDockSizer.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  FDock.MouseDown(Button, Shift, Left + X, Top + Y);
end;

{ (the drag moves the sizer: Left and Top are its place when the message came) }
procedure TSdDockSizer.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if ssLeft in Shift then FDock.MouseMove(Shift, Left + X, Top + Y);
end;

procedure TSdDockSizer.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  FDock.MouseUp(Button, Shift, Left + X, Top + Y);
end;

{ ---------------------------------------------------------------- TSdDockCaption }

constructor TSdDockCaption.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque] - [csAcceptsControls, csSetCaption];
  FButtons := TSdPressBoxes.Create(Self, ButtonOf);
  Buffered := True;
  RedrawWhole := True;
end;

destructor TSdDockCaption.Destroy;
begin
  FreeAndNil(FButtons);
  inherited;
end;

procedure TSdDockCaption.SetTitle(const Value: string);
begin
  if FTitle <> Value then
  begin
    FTitle := Value;
    Invalidate;
  end;
end;

{ 0 the pin, 1 the close box. A floating group's caption has no pin: an empty box (the list of
  boxes ends at the first index without one - TSdPressBoxes.BoxAt) }
function TSdDockCaption.ButtonOf(Index: Integer; out R: TRect): Boolean;
begin
  Result := (Index >= 0) and (Index <= 1);
  if not Result then Exit;
  if (Index = 0) and FGroup.Floating then R := NoRect
  else R := UIPaneCaptionButton(ClientRect, Index);
end;

procedure TSdDockCaption.PaintBuffer(C: TCanvas);
begin
  UIDrawPaneCaption(C.Handle, ClientRect, FTitle, not FGroup.FAutoHide,
    FButtons.State(0), FButtons.State(1), FGroup = FGroup.FDock.FFocusGroup, not FGroup.Floating);
end;

{ a double click on a floating group's caption (not on its close box) docks it where it was
  docked last - posted: the caption gets another parent, which may not happen in its handler }
procedure TSdDockCaption.WMLButtonDblClk(var Message: TWMLButtonDblClk);
begin
  inherited;
  if FGroup.Floating and not PtInRect(UIPaneCaptionButton(ClientRect, 1), Point(Message.XPos, Message.YPos)) then
    PostMessage(FGroup.FDock.Handle, WM_SDDOCKBACK, WPARAM(FGroup), 0);
end;

procedure TSdDockCaption.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if (FButtons <> nil) and not FButtons.Pressed then FButtons.Reset;
end;

{ A press on the pin or the close box acts when it is let go there (it is drawn pressed only
  while the press that began on it is over it: a drag of the caption that passes over it leaves
  it alone); a press anywhere else gives the active panel the focus and may become a drag of the
  group. Positions come from the mouse messages, never from GetCursorPos. }
procedure TSdDockCaption.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button <> mbLeft then Exit;
  if not FButtons.Press(X, Y) then FGroup.FDock.DragStage(Self, ddStart, X, Y);
end;

procedure TSdDockCaption.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if ssLeft in Shift then FGroup.FDock.DragStage(Self, ddMove, X, Y);
  if FButtons.Pressed or not (ssLeft in Shift) then FButtons.Move(X, Y);
end;

procedure TSdDockCaption.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button <> mbLeft then Exit;
  FGroup.FDock.DragStage(Self, ddEnd, X, Y);
  case FButtons.Release(X, Y) of
    0: FGroup.FDock.SetAutoHide(FGroup, not FGroup.FAutoHide);
    1: FGroup.FDock.HideGroup(FGroup);
  end;
end;
{ ---------------------------------------------------------------- TSdDockStrip }

function TSdDockStrip.TabPanel(Index: Integer): TSdDockPanel;
begin
  Result := TSdDockPanel(TabObject(Index));
end;

function TSdDockStrip.TabName(Index: Integer): string;
begin
  Result := TabPanel(Index).FName;
end;

function TSdDockStrip.TabImage(Index: Integer): Integer;
begin
  Result := TabPanel(Index).FImageIndex;
end;

function TSdDockStrip.TabTextColor(Index: Integer): TColor;
begin
  Result := TabPanel(Index).FTabTextColor;
end;

function TSdDockStrip.TabImages: TCustomImageList;
begin
  Result := TSdDock(Owner).FImages;
end;

procedure TSdDockStrip.SetPanels(L: TList);
var
  S: TStringList;
  I: Integer;
begin
  S := TStringList.Create;
  try
    for I := 0 to L.Count - 1 do S.AddObject(TSdDockPanel(L[I]).TabText, L[I]);
    SetItems(S);
  finally
    S.Free;
  end;
end;
{ ---------------------------------------------------------------- TSdDockTabs }

{ the visible panels as tabs (rebuilt only when they changed) and the shown one chosen }
procedure TSdDockTabs.Changed;
var
  I: Integer;
  L: TList;
begin
  L := TList.Create;
  try
    for I := 0 to FGroup.FPanels.Count - 1 do
      if FGroup.Panels[I].FVisible then L.Add(FGroup.Panels[I]);
    SetPanels(L);
  finally
    L.Free;
  end;
  TabIndex := Tabs.IndexOfObject(FGroup.FActive);
end;

{ a click on a tab: the dock shows its panel (and chooses the tab again through Changed) }
procedure TSdDockTabs.Choose(Index: Integer);
begin
  FGroup.FDock.ChooseTab(TabPanel(Index));
end;

{ either button chooses the tab (the right one for the menu that follows); the left one may
  begin a drag - of the tab's panel, or of the group from the strip beside the tabs. Positions
  come from the mouse messages. }
procedure TSdDockTabs.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then FGroup.FDock.DragStage(Self, ddStart, X, Y);
end;

procedure TSdDockTabs.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if ssLeft in Shift then FGroup.FDock.DragStage(Self, ddMove, X, Y);
end;

procedure TSdDockTabs.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button = mbLeft then FGroup.FDock.DragStage(Self, ddEnd, X, Y);
end;
{ ---------------------------------------------------------------- TSdDockAutoTabs }

{ the visible panels of the area's hidden groups, group by group; the one that slid out chosen }
procedure TSdDockAutoTabs.Changed;
var
  I, K: Integer;
  G: TSdDockGroup;
  L: TList;
begin
  L := TList.Create;
  try
    for I := 0 to FArea.FGroups.Count - 1 do
    begin
      G := TSdDockGroup(FArea.FGroups[I]);
      if G.FAutoHide then
        for K := 0 to G.FPanels.Count - 1 do
          if G.Panels[K].FVisible then L.Add(G.Panels[K]);
    end;
    SetPanels(L);
  finally
    L.Free;
  end;
  if (FDock.FSlid <> nil) and (FDock.FSlid.FArea = FArea) then
  begin
    TabIndex := Tabs.IndexOfObject(FDock.FSlid.FActive);
    PopupMenu := FDock.MenuOf(FDock.FSlid.FActive);
  end
  else
  begin
    { no view out: no view for the dock's commands to act on }
    TabIndex := -1;
    PopupMenu := nil;
  end;
end;

{ a click (either button: the right one for the menu that follows) slides the view out - also
  the one that is out already, which then gets the keyboard }
procedure TSdDockAutoTabs.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  I := TabAt(X, Y);
  if (I >= 0) and (Button in [mbLeft, mbRight]) then Choose(I);
end;

procedure TSdDockAutoTabs.Choose(Index: Integer);
var
  P: TSdDockPanel;
begin
  P := TabPanel(Index);
  FDock.HoverPanel(nil);
  FDock.SlideOut(P, False);
  FDock.FocusPanel(P);
end;

{ the pointer resting on a tab slides its view out (HoverTick) }
procedure TSdDockAutoTabs.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  inherited;
  I := TabAt(X, Y);
  if (I >= 0) and not (ssLeft in Shift) then FDock.HoverPanel(TabPanel(I))
  else FDock.HoverPanel(nil);
end;

procedure TSdDockAutoTabs.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if FDock <> nil then FDock.HoverPanel(nil);
end;

function TSdDockAutoTabs.PointerPanel: TSdDockPanel;
var
  P: TPoint;
  I: Integer;
begin
  Result := nil;
  if not HandleAllocated or not GetCursorPos(P) or (WindowFromPoint(P) <> Handle) then Exit;
  P := ScreenToClient(P);
  I := TabAt(P.X, P.Y);
  if I >= 0 then Result := TabPanel(I);
end;

{ ---------------------------------------------------------------- auto hide: clicks elsewhere }

{ While a group is out, a mouse hook of the thread watches the presses: one in a window of the
  dock's form outside the group and its strip slides it in (posted: the click goes on). Popups
  and drop-down lists are windows of their own - the menu of the view, the inspector's lists -
  and leave it out. The message names the slide it ends (FSlideSerial): a click on the strip of
  another area slides that area's group out before the message arrives, and that one stays. }
var
  SlideHook: HHOOK;
  SlideDock: TSdDock;

function SlideMouseHook(Code: Integer; W: WPARAM; L: LPARAM): LRESULT; stdcall;
var
  H: HWND;
begin
  if (Code = HC_ACTION) and (SlideDock <> nil) then
    case W of
      WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN, WM_NCLBUTTONDOWN, WM_NCRBUTTONDOWN,
      WM_LBUTTONDBLCLK, WM_NCLBUTTONDBLCLK:
        begin
          H := PMouseHookStruct(L)^.hwnd;
          if SlideDock.HandleAllocated and (H <> 0) and
            (GetAncestor(H, GA_ROOT) = GetAncestor(SlideDock.Handle, GA_ROOT)) and
            not SlideDock.InSlide(H) then
            PostMessage(SlideDock.Handle, WM_SDDOCKSLIDEIN, WPARAM(SlideDock.FSlideSerial), 0);
        end;
    end;
  Result := CallNextHookEx(SlideHook, Code, W, L);
end;

procedure HookSlide(Dock: TSdDock);
begin
  SlideDock := Dock;
  if SlideHook = 0 then
    SlideHook := SetWindowsHookEx(WH_MOUSE, @SlideMouseHook, 0, GetCurrentThreadId);
end;

procedure UnhookSlide;
begin
  if SlideHook <> 0 then UnhookWindowsHookEx(SlideHook);
  SlideHook := 0;
  SlideDock := nil;
end;

{ ---------------------------------------------------------------- TSdDockHost }

constructor TSdDockHost.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csAcceptsControls, csOpaque] - [csSetCaption, csParentBackground];
  Color := clBtnFace;
end;

procedure TSdDockHost.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  with Params.WindowClass do style := style and not (CS_HREDRAW or CS_VREDRAW);
end;

{ ---------------------------------------------------------------- TSdDock }

constructor TSdDock.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { csAcceptsControls: WS_CLIPCHILDREN - the dock paints the gaps between its children only }
  ControlStyle := ControlStyle + [csAcceptsControls, csOpaque] - [csSetCaption, csParentBackground];
  Color := clBtnFace;
  FAreas := TList.Create;
  FPanels := TList.Create;
  FDead := TList.Create;
  FFloatArea := TSdDockArea.Create;
  FFloatArea.FName := 'Float';
  FFloatArea.FGroups := TList.Create;
  FAutoDragDocking := True;
  FAutoTimer := TTimer.Create(Self);
  FAutoTimer.Enabled := False;
  FAutoTimer.Interval := 250;
  FAutoTimer.OnTimer := AutoTick;
  FHoverTimer := TTimer.Create(Self);
  FHoverTimer.Enabled := False;
  FHoverTimer.Interval := 400;
  FHoverTimer.OnTimer := HoverTick;
  UIOnPressCancel(Self, PressCancelled);          // a splitter drag
  FSlideSizer := TSdDockSizer.Create(Self);
  FSlideSizer.Visible := False;
  FSlideSizer.Parent := Self;
  UIOnPressCancel(FSlideSizer, PressCancelled);   // ... the edge of the group that is out
end;

destructor TSdDock.Destroy;
var
  I: Integer;
  L: TList;
begin
  if SlideDock = Self then UnhookSlide;
  FreeDead;
  L := AllGroups;
  try
    for I := 0 to L.Count - 1 do TSdDockGroup(L[I]).Free;
  finally
    L.Free;
  end;
  for I := 0 to FAreas.Count - 1 do Areas[I].Free;
  FFloatArea.Free;
  for I := 0 to FPanels.Count - 1 do Panels[I].Free;
  FAreas.Free;
  FPanels.Free;
  FDead.Free;
  inherited;
end;

procedure TSdDock.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  { a resize repaints what it uncovers, not the whole dock }
  with Params.WindowClass do style := style and not (CS_HREDRAW or CS_VREDRAW);
end;

procedure TSdDock.CreateWnd;
begin
  inherited CreateWnd;
  if FDead.Count > 0 then PostMessage(Handle, WM_SDDOCKRELEASE, 0, 0);
end;

procedure TSdDock.Resize;
begin
  inherited;
  Layout;
end;

function TSdDock.GetArea(Index: Integer): TSdDockArea;
begin
  Result := TSdDockArea(FAreas[Index]);
end;

function TSdDock.GetAreaCount: Integer;
begin
  Result := FAreas.Count;
end;

function TSdDock.GetPanel(Index: Integer): TSdDockPanel;
begin
  Result := TSdDockPanel(FPanels[Index]);
end;

function TSdDock.GetPanelCount: Integer;
begin
  Result := FPanels.Count;
end;

{ a control becomes a child of the dock, once; the dock positions it from then on }
procedure TSdDock.Adopt(C: TControl);
begin
  C.Align := alNone;
  C.Anchors := [akLeft, akTop];
  C.Parent := Self;
end;

procedure TSdDock.SetCenter(Value: TControl);
begin
  if FCenterHost = nil then
  begin
    FCenterHost := TSdDockHost.Create(Self);
    FCenterHost.Parent := Self;
  end;
  FCenter := Value;
  if Value <> nil then
  begin
    Value.Parent := FCenterHost;
    Value.Align := alClient;
  end;
  Layout;
end;

procedure TSdDock.SetCenterHeader(Value: TControl);
begin
  if FCenterHeader <> nil then FCenterHeader.RemoveFreeNotification(Self);
  FCenterHeader := Value;
  if Value <> nil then
  begin
    Value.FreeNotification(Self);
    Adopt(Value);
  end;
  Layout;
end;

{ The header's SetBounds and SetVisible ask its parent to align it (RequestAlign): its height or
  its visibility changed, and the centre is shared out again. The dock aligns nothing else - its
  children are placed by Layout -, and Layout's own changes come back here while it runs. }
procedure TSdDock.AlignControls(AControl: TControl; var Rect: TRect);
begin
  inherited AlignControls(AControl, Rect);
  if (AControl <> nil) and (AControl = FCenterHeader) and not FInLayout then Layout;
end;

{ the groups whose view shown has a menu of its own keep it }
procedure TSdDock.SetCaptionMenu(Value: TPopupMenu);
var
  I: Integer;
  L: TList;
begin
  FCaptionMenu := Value;
  L := AllGroups;
  try
    for I := 0 to L.Count - 1 do SetGroupMenus(TSdDockGroup(L[I]));
  finally
    L.Free;
  end;
  if FSlid <> nil then FSlid.FArea.FAutoTabs.Changed;
end;

{ the menu of a panel's caption and tabs: its own, else CaptionMenu }
function TSdDock.MenuOf(P: TSdDockPanel): TPopupMenu;
begin
  if (P <> nil) and (P.FPopupMenu <> nil) then Result := P.FPopupMenu
  else Result := FCaptionMenu;
end;

{ G's caption and tabs show the menu of the panel shown (a right click on a tab chooses that tab
  first), each view's tool bar its view's: the bar lies in the dock, not in the view whose menu a
  right click in it found before }
procedure TSdDock.SetGroupMenus(G: TSdDockGroup);
var
  I: Integer;
begin
  G.FCaption.PopupMenu := MenuOf(G.FActive);
  G.FTabs.PopupMenu := G.FCaption.PopupMenu;
  for I := 0 to G.FPanels.Count - 1 do
    if G.Panels[I].FToolBar <> nil then G.Panels[I].FToolBar.PopupMenu := MenuOf(G.Panels[I]);
end;

{ every group, area by area in stacking order, the floating ones last (the caller frees the list) }
function TSdDock.AllGroups: TList;
var
  I, K: Integer;
begin
  Result := TList.Create;
  for I := 0 to FAreas.Count - 1 do
    for K := 0 to Areas[I].FGroups.Count - 1 do Result.Add(Areas[I].FGroups[K]);
  for K := 0 to FFloatArea.FGroups.Count - 1 do Result.Add(FFloatArea.FGroups[K]);
end;

{ G is still one of the dock's groups (a posted message may come after it went) }
function TSdDock.IsGroup(G: TSdDockGroup): Boolean;
var
  L: TList;
begin
  L := AllGroups;
  try
    Result := (G <> nil) and (L.IndexOf(G) >= 0);
  finally
    L.Free;
  end;
end;

function TSdDock.VisibleGroups(A: TSdDockArea): TList;
var
  K: Integer;
begin
  Result := TList.Create;
  for K := 0 to A.FGroups.Count - 1 do
    if (TSdDockGroup(A.FGroups[K]).VisibleCount > 0) and not TSdDockGroup(A.FGroups[K]).FAutoHide then
      Result.Add(A.FGroups[K]);
end;

{ the Index-th visible group of A; nil: past the last }
function TSdDock.GroupAt(A: TSdDockArea; Index: Integer): TSdDockGroup;
var
  L: TList;
begin
  L := VisibleGroups(A);
  try
    if (Index >= 0) and (Index < L.Count) then Result := TSdDockGroup(L[Index]) else Result := nil;
  finally
    L.Free;
  end;
end;

{ the length along which A stacks its groups (the centre's, while A takes no room; an outer
  area's: the dock's edge it lies along) }
function TSdDock.AreaLength(A: TSdDockArea): Integer;
begin
  if not IsRectEmpty(A.FBounds) then Result := Extent(A.FBounds, A.Vertical)
  else if A.FOuter and not IsRectEmpty(A.FRoom) then Result := Extent(A.FRoom, A.Vertical)
  else if A.FInCenter then Result := Extent(FPageRect, A.Vertical)
  else Result := Extent(FCenterRect, A.Vertical);
end;

function TSdDock.AddArea(const AName: string; AEdge: TSdDockEdge; ASize: Integer;
  AOuter: Boolean): TSdDockArea;
begin
  Result := NewArea(AName, AEdge, ASize);
  Result.FOuter := AOuter;
  Layout;
end;

function TSdDock.AddCenterArea(const AName: string; AEdge: TSdDockEdge; ASize: Integer): TSdDockArea;
begin
  Result := NewArea(AName, AEdge, ASize);
  Result.FInCenter := True;
  Layout;
end;

{ an area last in the order (without a layout: a column made for a drop has no group yet) }
function TSdDock.NewArea(const AName: string; AEdge: TSdDockEdge; ASize: Integer): TSdDockArea;
begin
  Result := TSdDockArea.Create;
  Result.FName := AName;
  Result.FEdge := AEdge;
  Result.FSize := ASize;
  Result.FGroups := TList.Create;
  Result.FAutoTabs := TSdDockAutoTabs.Create(Self);
  Result.FAutoTabs.FArea := Result;
  Result.FAutoTabs.FDock := Self;
  Result.FAutoTabs.Visible := False;
  Result.FAutoTabs.Parent := Self;
  case AEdge of
    deLeft: Result.FAutoTabs.Side := tsLeft;
    deRight: Result.FAutoTabs.Side := tsRight;
    deTop: Result.FAutoTabs.Side := tsTop;
  else
    Result.FAutoTabs.Side := tsBottom;
  end;
  FAreas.Add(Result);
end;

{ --- columns: areas beside the areas of an edge, rows along the dock's edge --- }

{ an area of Edge of that Kind shows a group - not counting Moving, the group a drag takes away
  whole }
function TSdDock.EdgeShows(Edge: TSdDockEdge; Kind: TSdDockAreaKind; Moving: TSdDockGroup): Boolean;
var
  I, K: Integer;
  L: TList;
begin
  Result := False;
  for I := 0 to FAreas.Count - 1 do
    if (Areas[I].FEdge = Edge) and (Areas[I].Kind = Kind) then
    begin
      L := VisibleGroups(Areas[I]);
      try
        for K := 0 to L.Count - 1 do
          if TSdDockGroup(L[K]) <> Moving then Result := True;
      finally
        L.Free;
      end;
      if Result then Exit;
    end;
end;

{ the first area of Edge of that Kind in the order (nil: none): the outer one at the dock's edge,
  the centre area of a side of the pages }
function TSdDock.FirstArea(Edge: TSdDockEdge; Kind: TSdDockAreaKind): TSdDockArea;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FAreas.Count - 1 do
    if (Areas[I].FEdge = Edge) and (Areas[I].Kind = Kind) then
    begin
      Result := Areas[I];
      Exit;
    end;
end;

{ A column made by a drop (BesideTarget, OuterTarget), an area of its own named after Base
  ("Left2", "Left3" ..., "BottomFull2") and as wide or high as Base. Beside an inner area - where
  a drop on the guide of that edge goes while the edge shows a group - it comes right after the
  inner areas of its edge in the order of the areas, on the centre's side: a left or right column
  runs from top to bottom as the left and right areas do (the bottom area stays under the
  centre), a bottom column lies above the bottom area, as wide as it. Beside an outer area - a
  drop on the dock's bottom guide while the outer areas of that edge show a group - it is a row at the dock's
  edge: an outer area too, before the outer areas of its edge, so it spans the edge as they do.
  It goes again with its last group (DropEmptyColumns). }
function TSdDock.AddColumn(Base: TSdDockArea): TSdDockArea;
var
  N: Integer;
begin
  N := 2;
  while FindArea(Base.FName + IntToStr(N)) <> nil do Inc(N);
  Result := NewColumn(Base, Base.FName + IntToStr(N), False);
end;

{ a column of Base named AName (AddColumn, ColumnNamed), moved to its place (PlaceColumn) }
function TSdDock.NewColumn(Base: TSdDockArea; const AName: string; Loading: Boolean): TSdDockArea;
begin
  Result := NewArea(AName, Base.FEdge, Base.FSize);
  Result.FColumn := True;
  Result.FBase := Base;
  Result.FOuter := Base.FOuter;
  PlaceColumn(Result, Loading);
end;

{ where a new column beside the inner areas of A's edge would be (the drop marker): along the
  edge as long as the innermost of them that takes room, across as wide as A (at most the centre) }
function TSdDock.ColumnRect(A: TSdDockArea): TRect;
var
  I, S: Integer;
  E, B: TRect;
begin
  E := NoRect;
  for I := 0 to FAreas.Count - 1 do
    if (Areas[I].FEdge = A.FEdge) and (Areas[I].Kind = dkBeside) and not IsRectEmpty(Areas[I].FBounds) then
      E := Areas[I].FBounds;
  if IsRectEmpty(E) then E := FCenterRect;
  S := A.FSize;
  if S > Extent(FCenterRect, not A.Vertical) then S := Extent(FCenterRect, not A.Vertical);
  { across the centre, along the edge as E }
  if A.Vertical then B := Rect(FCenterRect.Left, E.Top, FCenterRect.Right, E.Bottom)
  else B := Rect(E.Left, FCenterRect.Top, E.Right, FCenterRect.Bottom);
  Result := EdgePart(B, A.FEdge, S);
end;

{ The drop band at Edge of R (an outer area's room, client coordinates): EdgeZone thick inside R,
  and from there on to that edge of the dock's window - its status bar and its frame: a pointer
  aimed at the window's edge ends there, outside the dock }
function TSdDock.EdgeBand(const R: TRect; Edge: TSdDockEdge): TRect;
var
  F: TCustomForm;
  W: TRect;
begin
  Result := EdgePart(R, Edge, EdgeZone);
  F := GetParentForm(Self);
  if (F = nil) or not F.HandleAllocated or not HandleAllocated then Exit;
  GetWindowRect(F.Handle, W);
  W.TopLeft := ScreenToClient(W.TopLeft);
  W.BottomRight := ScreenToClient(W.BottomRight);
  case Edge of
    deLeft: if W.Left < Result.Left then Result.Left := W.Left;
    deRight: if W.Right > Result.Right then Result.Right := W.Right;
    deTop: if W.Top < Result.Top then Result.Top := W.Top;
  else
    if W.Bottom > Result.Bottom then Result.Bottom := W.Bottom;
  end;
end;

{ A new column (last in the order) moves to its place: beside inner areas right after the inner
  areas of its edge; a row of an outer area before the outer areas of its edge (the dock's edge) -
  or, made again by Load (Loading), right before its base: the groups are saved area by area,
  so the rows come outermost first and keep their order }
procedure TSdDock.PlaceColumn(A: TSdDockArea; Loading: Boolean);
var
  I, K: Integer;
begin
  FAreas.Remove(A);
  if A.FOuter then
  begin
    K := FAreas.IndexOf(A.FBase);
    if not Loading and (FirstArea(A.FEdge, dkOuter) <> nil) then K := FAreas.IndexOf(FirstArea(A.FEdge, dkOuter));
    if K < 0 then K := 0;
    FAreas.Insert(K, A);
  end
  else
  begin
    K := -1;
    for I := 0 to FAreas.Count - 1 do
      if (Areas[I].FEdge = A.FEdge) and (Areas[I].Kind = dkBeside) then K := I;
    FAreas.Insert(K + 1, A);
  end;
end;

{ the column a saved arrangement names ("Left2": beside the areas of Left's edge; "BottomFull2": a
  row of BottomFull), made again; nil: no such name }
function TSdDock.ColumnNamed(const AName: string): TSdDockArea;
var
  I: Integer;
  B: TSdDockArea;
begin
  Result := nil;
  for I := 0 to FAreas.Count - 1 do
  begin
    B := Areas[I];
    if B.FColumn or B.FInCenter or (Length(AName) <= Length(B.FName)) or
      not SameText(Copy(AName, 1, Length(B.FName)), B.FName) or
      (StrToIntDef(Copy(AName, Length(B.FName) + 1, MaxInt), 0) < 2) then Continue;
    Result := NewColumn(B, AName, True);
    Exit;
  end;
end;
{ a column without groups goes; a floating group that was docked there goes back to the area it
  is named after (DockBack) }
procedure TSdDock.DropEmptyColumns;
var
  I, K: Integer;
  A: TSdDockArea;
  L: TList;
begin
  for I := FAreas.Count - 1 downto 0 do
  begin
    A := Areas[I];
    if not A.FColumn or (A.FGroups.Count > 0) or (A = FSplitArea) then Continue;
    FAreas.Delete(I);
    L := AllGroups;
    try
      for K := 0 to L.Count - 1 do
        if TSdDockGroup(L[K]).FHomeArea = A then
        begin
          TSdDockGroup(L[K]).FHomeArea := A.FBase;
          TSdDockGroup(L[K]).FHomeIndex := -1;
        end;
    finally
      L.Free;
    end;
    A.FAutoTabs.Free;
    A.Free;
  end;
end;

function TSdDock.NewGroup(A: TSdDockArea; Before: TSdDockGroup): TSdDockGroup;
begin
  Result := TSdDockGroup.Create;
  Result.FDock := Self;
  Result.FPanels := TList.Create;
  Result.FCaption := TSdDockCaption.Create(Self);
  Result.FCaption.FGroup := Result;
  Result.FCaption.Visible := False;
  Result.FCaption.Parent := Self;
  Result.FCaption.PopupMenu := FCaptionMenu;
  UIOnPressCancel(Result.FCaption, PressCancelled);
  Result.FTabs := TSdDockTabs.Create(Self);
  Result.FTabs.FGroup := Result;
  UIOnPressCancel(Result.FTabs, PressCancelled);
  { no close boxes on the tabs: Close in the view's menu, the caption's close box }
  Result.FTabs.Visible := False;
  Result.FTabs.Parent := Self;
  Result.FTabs.PopupMenu := FCaptionMenu;
  Result.FStatus := TSdDockStatus.Create(Self);
  Result.FStatus.Visible := False;
  Result.FStatus.Parent := Self;
  PlaceGroup(Result, A, Before);
end;

function TSdDock.NewPanel(AControl: TControl; const AName, ATitle: string; G: TSdDockGroup): TSdDockPanel;
begin
  Result := TSdDockPanel.Create;
  Result.FDock := Self;
  Result.FControl := AControl;
  Result.FName := AName;
  Result.FTitle := ATitle;
  Result.FVisible := True;
  Result.FImageIndex := -1;
  Result.FTabTextColor := clNone;
  AControl.Visible := False;            // Layout shows it where it belongs
  Adopt(AControl);
  FPanels.Add(Result);
  Join(Result, G);
  Layout;
end;

function TSdDock.AddPanel(AControl: TControl; const AName, ATitle: string; AArea: TSdDockArea;
  ASize: Integer): TSdDockPanel;
var
  G: TSdDockGroup;
begin
  G := NewGroup(AArea, nil);
  if ASize > 0 then G.FSize := ASize;
  Result := NewPanel(AControl, AName, ATitle, G);
end;

function TSdDock.AddTab(AControl: TControl; const AName, ATitle: string; AWith: TSdDockPanel): TSdDockPanel;
begin
  Result := NewPanel(AControl, AName, ATitle, AWith.FGroup);
end;

{ G goes into A before Before (nil: last); from another area (or new) it starts with a third of
  the area, at least 120 px. A floating group that docks leaves its window; a docked one that
  floats remembers where it was (DockBack) - its window is made by Layout. }
procedure TSdDock.PlaceGroup(G: TSdDockGroup; A: TSdDockArea; Before: TSdDockGroup);
var
  Moved: Boolean;
  L: TList;
begin
  Moved := G.FArea <> A;
  if Moved and (G.FArea = FFloatArea) then Unfloat(G);
  if Moved and (A = FFloatArea) and (G.FArea <> nil) then
  begin
    G.FHomeArea := G.FArea;
    L := VisibleGroups(G.FArea);
    try
      G.FHomeIndex := L.IndexOf(G);
      if (G.FHomeIndex >= 0) and (G.FHomeIndex = L.Count - 1) then G.FHomeIndex := -1;
    finally
      L.Free;
    end;
  end;
  if G.FArea <> nil then G.FArea.FGroups.Remove(G);
  if (Before <> nil) and (Before <> G) and (A.FGroups.IndexOf(Before) >= 0) then
    A.FGroups.Insert(A.FGroups.IndexOf(Before), G)
  else
    A.FGroups.Add(G);
  G.FArea := A;
  if Moved and (A <> FFloatArea) then
  begin
    G.FSize := AreaLength(A) div 3;
    if G.FSize < 120 then G.FSize := 120;
  end;
end;

{ P's view and tool bar go where its group is: the dock, or the group's floating window }
procedure TSdDock.Join(P: TSdDockPanel; G: TSdDockGroup);
begin
  G.FPanels.Add(P);
  P.FGroup := G;
  if G.FActive = nil then G.FActive := P;
  PutControl(P.FControl, HostOf(G));
  PutControl(P.FToolBar, HostOf(G));
end;

{ the window G's parts lie in: its floating window, else the dock }
function TSdDock.HostOf(G: TSdDockGroup): TWinControl;
begin
  if G.FFloat <> nil then Result := G.FFloat else Result := Self;
end;

{ --- floating --- }

{ C to another parent, hidden first (Layout shows it in its place), with the measures against
  flicker (UIReduceFlicker) - also for a view made after the first idle's }
{ A list view that gets a new window reads itself back from a stream, and the stream renames it
  (TReader.ReadRootComponent: FindUniqueName) - one without a name becomes "_1", and a second
  one of the same owner raised "A component named _1 already exists" (the Browser's lists, when
  the bottom group floated). Those under C get a name of their own first. }
procedure NameListViews(C: TControl);
var
  I, N: Integer;
begin
  if (C is TCustomListView) and (C.Name = '') then
  begin
    N := 1;
    while (C.Owner <> nil) and (C.Owner.FindComponent('SdListView' + IntToStr(N)) <> nil) do Inc(N);
    C.Name := 'SdListView' + IntToStr(N);
  end;
  if C is TWinControl then
    for I := 0 to TWinControl(C).ControlCount - 1 do NameListViews(TWinControl(C).Controls[I]);
end;

procedure TSdDock.PutControl(C: TControl; Host: TWinControl);
begin
  if (C = nil) or (C.Parent = Host) then Exit;
  NameListViews(C);
  KeepFocusIn(C);
  C.Visible := False;
  C.Parent := Host;
  if Host.HandleAllocated then UIReduceFlickerOf(C);
end;

{ the caption, the tabs, the status line, the views and their tool bars of G to Host }
procedure TSdDock.MoveParts(G: TSdDockGroup; Host: TWinControl);
var
  I: Integer;
begin
  PutControl(G.FCaption, Host);
  PutControl(G.FTabs, Host);
  PutControl(G.FStatus, Host);
  for I := 0 to G.FPanels.Count - 1 do
  begin
    PutControl(G.Panels[I].FControl, Host);
    PutControl(G.Panels[I].FToolBar, Host);
  end;
end;

{ A floating group's window, made once the dock's form has a window (it is the owner): exactly
  where the group floated last - also across monitors, also partly off them (it was pushed whole
  onto one monitor) -, unless no monitor shows its caption any
  more (one was unplugged since): then whole on the nearest one }
function TSdDock.EnsureFloat(G: TSdDockGroup): Boolean;
var
  Form: TCustomForm;
  R: TRect;
begin
  Result := G.FFloat <> nil;
  if Result then Exit;
  Form := GetParentForm(Self);
  if (Form = nil) or not Form.HandleAllocated then Exit;
  R := G.FFloatRect;
  if IsRectEmpty(R) then R := Bounds(Form.Left + 80, Form.Top + 80, 240, 320);
  if not UICaptionOnScreen(R, FloatMargin + 1 + UIPaneCaptionHeight) then UIFitWorkArea(R);
  G.FFloatRect := R;
  G.FFloat := TDockFloatForm.CreateFor(Form.Handle, 80, MinGroup + 2 * (FloatMargin + 1));
  G.FFloat.BoundsRect := R;
  G.FFloat.HandleNeeded;
  G.FFloat.OnResize := FloatResize;     // after its window is made (no layout from that)
  MoveParts(G, G.FFloat);
  Result := True;
end;

{ G docks again: its parts back into the dock (hidden; Layout shows them), its window goes. The
  window keeps its place for the next time it floats. }
procedure TSdDock.Unfloat(G: TSdDockGroup);
var
  F: TDockFloatForm;
begin
  F := G.FFloat;
  if F = nil then Exit;
  G.FFloatRect := F.BoundsRect;
  KeepFocusIn(F);                       // before the window goes: hiding it moves the keyboard away
  F.Visible := False;
  MoveParts(G, Self);
  G.FFloat := nil;
  F.Free;
end;

{ the window of a floating group was sized (its edges) or moved: its group laid out in it }
procedure TSdDock.FloatResize(Sender: TObject);
var
  I: Integer;
  G: TSdDockGroup;
begin
  for I := 0 to FFloatArea.FGroups.Count - 1 do
  begin
    G := TSdDockGroup(FFloatArea.FGroups[I]);
    if G.FFloat = Sender then G.FFloatRect := G.FFloat.BoundsRect;
  end;
  Layout;
end;

{ the floating groups' windows: shown while the group has a visible view and the dock's form is
  on the screen (FloatsShown), else hidden }
procedure TSdDock.ShowFloats;
var
  I: Integer;
  G: TSdDockGroup;
  Want: Boolean;
  Form: TCustomForm;
begin
  Form := GetParentForm(Self);
  for I := 0 to FFloatArea.FGroups.Count - 1 do
  begin
    G := TSdDockGroup(FFloatArea.FGroups[I]);
    if G.FFloat = nil then Continue;
    Want := FFloatsShown and (Form <> nil) and Form.Visible and (G.VisibleCount > 0);
    if G.FFloat.Visible <> Want then G.FFloat.Visible := Want;
  end;
end;

procedure TSdDock.SetFloatsShown(Value: Boolean);
begin
  if FFloatsShown = Value then Exit;
  FFloatsShown := Value;
  Layout;
end;

procedure TSdDock.FloatGroup(G: TSdDockGroup; const R: TRect);
begin
  if G = nil then Exit;
  if G = FSlid then DropSlide;
  G.FAutoHide := False;
  if not IsRectEmpty(R) then G.FFloatRect := R
  else if IsRectEmpty(G.FFloatRect) and not IsRectEmpty(G.FBounds) and (G.FArea <> FFloatArea) then
    G.FFloatRect := FirstFloatRect(Self, G.FBounds);   // the first time: beside its docked place
  if G.FArea <> FFloatArea then
  begin
    KeepSize(G);
    PlaceGroup(G, FFloatArea, nil);
  end
  else if G.FFloat <> nil then
    G.FFloat.BoundsRect := G.FFloatRect;
  if G.VisibleCount = 0 then G.FActive.FVisible := True;
  Layout;
end;

procedure TSdDock.FloatPanel(P: TSdDockPanel; const R: TRect);
var
  G, From: TSdDockGroup;
begin
  if P = nil then Exit;
  From := P.FGroup;
  if From.FPanels.Count = 1 then
  begin
    FloatGroup(From, R);
    Exit;
  end;
  G := NewGroup(FFloatArea, nil);
  { it comes back where its group is (or was, for a tab of a floating group) }
  if From.FArea = FFloatArea then
  begin
    G.FHomeArea := From.FHomeArea;
    G.FHomeIndex := From.FHomeIndex;
  end
  else
  begin
    G.FHomeArea := From.FArea;
    G.FHomeIndex := -1;
  end;
  if not IsRectEmpty(R) then G.FFloatRect := R
  else if not IsRectEmpty(From.FBounds) then
  begin
    { beside its group: in the dock, or in the group's floating window }
    G.FFloatRect := FirstFloatRect(HostOf(From), From.FBounds);
  end;
  { the window first: the view goes straight into it (Join) - a tab of a floating group went
    into the dock and then into the new window, a new window of its own twice }
  EnsureFloat(G);
  Detach(P);
  Join(P, G);
  P.FVisible := True;
  Layout;
end;

{ back where it was docked last: its area, before the group it was before (the first area when
  it has no such place) }
{ the first area that is not along the dock's own edge (nil: none) }
function TSdDock.FirstInnerArea: TSdDockArea;
var
  I: Integer;
begin
  for I := 0 to FAreas.Count - 1 do
    if (Areas[I].Kind = dkBeside) and not Areas[I].FColumn and (Areas[I] <> FFloatArea) then
    begin
      Result := Areas[I];
      Exit;
    end;
  Result := nil;
end;

procedure TSdDock.DockBack(G: TSdDockGroup);
var
  A: TSdDockArea;
begin
  if (G = nil) or not G.Floating or G.FloatOnly then Exit;
  A := G.FHomeArea;
  if (A = nil) or (A = FFloatArea) or (FAreas.IndexOf(A) < 0) then
    A := FirstInnerArea;               // not a full-width row (added first): the left area
  if A = nil then Exit;
  MoveGroup(G, A, G.FHomeIndex);
end;

procedure TSdDock.WMDockBack(var Message: TMessage);
begin
  CancelDrag(False);
  if IsGroup(TSdDockGroup(Message.WParam)) then DockBack(TSdDockGroup(Message.WParam));
end;

function TSdDock.FloatRectFor(AWidth, AHeight: Integer): TRect;
var
  W, H: Integer;
  R: TRect;
begin
  W := AWidth + 2 * (FloatMargin + 1);
  H := UIPaneCaptionHeight + AHeight + 2 * (FloatMargin + 1);
  R := Screen.WorkAreaRect;
  Result := Bounds((R.Left + R.Right - W) div 2, (R.Top + R.Bottom - H) div 2, W, H);
end;

procedure TSdDock.SetFloatOnly(P: TSdDockPanel; const R: TRect);
begin
  if P = nil then Exit;
  P.FFloatOnly := True;
  P.FFloatHome := R;
  KeepFloatOnly;
  Layout;
end;

{ every float-only panel alone in a floating group of its own, shown or hidden as it was (a saved
  arrangement can have it docked, or among other views); a group that floats for the first time
  takes the panel's first place }
procedure TSdDock.KeepFloatOnly;
var
  I: Integer;
  P: TSdDockPanel;
  G: TSdDockGroup;
begin
  for I := 0 to FPanels.Count - 1 do
  begin
    P := Panels[I];
    G := P.FGroup;
    if not P.FFloatOnly or (G = nil) or (G.Floating and (G.FPanels.Count = 1)) then Continue;
    if G.FPanels.Count = 1 then
    begin
      if G = FSlid then DropSlide;
      G.FAutoHide := False;
      if IsRectEmpty(G.FFloatRect) then G.FFloatRect := P.FFloatHome;
      PlaceGroup(G, FFloatArea, nil);
    end
    else
    begin
      G := NewGroup(FFloatArea, nil);
      G.FFloatRect := P.FFloatHome;
      { the window first: the view goes straight into it (as FloatPanel) }
      EnsureFloat(G);
      Detach(P);
      Join(P, G);
    end;
  end;
end;

{ P leaves its group; a group without panels goes }
procedure TSdDock.Detach(P: TSdDockPanel);
var
  G: TSdDockGroup;
begin
  G := P.FGroup;
  if G = nil then Exit;
  if G.FActive = P then G.FActive := G.NextVisible(P);
  G.FPanels.Remove(P);
  P.FGroup := nil;
  if (G.FActive = nil) and (G.FPanels.Count > 0) then G.FActive := G.Panels[0];
  if G.FPanels.Count = 0 then ReleaseGroup(G);
end;

{ The group is taken out at once and freed by a posted message: the drag that emptied it may
  still be running in a handler of its own caption. A drag that holds the group (of its caption
  or its tabs, of a splitter next to it - Load replaces the arrangement while the debugger
  stops) ends here, so that nothing keeps a pointer to it. }
procedure TSdDock.ReleaseGroup(G: TSdDockGroup);
begin
  if (G = FDragGroup) or (G = FSplitGroup) or (G = FSplitNext) or (FDragControl = G.FCaption) or
    (FDragControl = G.FTabs) then
    CancelDrag(False);
  if G = FSlid then DropSlide;
  if G = FFocusGroup then FFocusGroup := nil;
  if G.FArea <> nil then G.FArea.FGroups.Remove(G);
  G.FArea := nil;
  G.FCaption.Visible := False;
  G.FTabs.Visible := False;
  G.FStatus.Visible := False;
  if G.FFloat <> nil then
  begin
    KeepFocusIn(G.FFloat);              // its last view, on its way into another group
    G.FFloat.Visible := False;          // freed with the group
  end;
  FDead.Add(G);
  if HandleAllocated then PostMessage(Handle, WM_SDDOCKRELEASE, 0, 0);
end;

procedure TSdDock.FreeDead;
var
  I: Integer;
begin
  for I := 0 to FDead.Count - 1 do TSdDockGroup(FDead[I]).Free;
  FDead.Clear;
end;

procedure TSdDock.WMRelease(var Message: TMessage);
begin
  FreeDead;
end;

{ G has just appeared: as the last visible group of its area it takes its size from the group
  before it, which had the rest of the area until now - at most half when it was moved there,
  its own size when it comes back; both keep MinGroup. A group before it that is too small to
  share keeps everything as it is (G, being last, has the rest; the sizes stay sizes). }
procedure TSdDock.MakeRoom(G: TSdDockGroup; Moved: Boolean);
var
  L: TList;
  Prev: TSdDockGroup;
  Cur: Integer;
begin
  if (G.FArea = nil) or (G.FArea = FFloatArea) then Exit;   // a floating group has its window
  L := VisibleGroups(G.FArea);
  try
    if (L.Count < 2) or (L[L.Count - 1] <> G) then Exit;
    Prev := TSdDockGroup(L[L.Count - 2]);
    if IsRectEmpty(Prev.FBounds) then Exit;
    Cur := Extent(Prev.FBounds, G.FArea.Vertical);
    if Cur - Gap < 2 * MinGroup then Exit;
    if Moved and (G.FSize > Cur div 2) then G.FSize := Cur div 2;
    if G.FSize > Cur - Gap - MinGroup then G.FSize := Cur - Gap - MinGroup;
    if G.FSize < MinGroup then G.FSize := MinGroup;
    Prev.FSize := Cur - G.FSize - Gap;
  finally
    L.Free;
  end;
end;

{ G is about to go: as the last visible group of its area it has the rest, which is not its
  size - it keeps the size it has on the screen and comes back as it was (MakeRoom; the Object
  Inspector, hidden while the debugger runs) }
procedure TSdDock.KeepSize(G: TSdDockGroup);
var
  L: TList;
begin
  if (G.FArea = nil) or (G.FArea = FFloatArea) then Exit;
  L := VisibleGroups(G.FArea);
  try
    if (L.Count > 1) and (L[L.Count - 1] = G) and not IsRectEmpty(G.FBounds) then
      G.FSize := Extent(G.FBounds, G.FArea.Vertical);
  finally
    L.Free;
  end;
end;

function TSdDock.FindArea(const AName: string): TSdDockArea;
var
  I: Integer;
begin
  Result := nil;
  if SameText(AName, FFloatArea.FName) then
  begin
    Result := FFloatArea;
    Exit;
  end;
  for I := 0 to FAreas.Count - 1 do
    if SameText(Areas[I].FName, AName) then
    begin
      Result := Areas[I];
      Exit;
    end;
end;

function TSdDock.FindPanel(const AName: string): TSdDockPanel;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FPanels.Count - 1 do
    if SameText(Panels[I].FName, AName) then
    begin
      Result := Panels[I];
      Exit;
    end;
  for I := 0 to FPanels.Count - 1 do
    if (Panels[I].FFormerName <> '') and SameText(Panels[I].FFormerName, AName) then
    begin
      Result := Panels[I];
      Exit;
    end;
end;

{ The caption of the group the keyboard is in shows the active title colours, the others a
  quiet grey; called when the focused control changes. Not while Layout runs: hiding the view
  that has the keyboard takes it away before the view shown next gets it (a click on a tab), and
  Layout paints at once - the caption would show grey in between. Layout calls it at its end. }
procedure TSdDock.FocusChanged;
var
  P: TSdDockPanel;
  G: TSdDockGroup;
begin
  if FInLayout then Exit;
  G := nil;
  if Screen.ActiveControl <> nil then
  begin
    P := PanelOf(Screen.ActiveControl);
    if P <> nil then G := P.FGroup;
  end;
  if G = FFocusGroup then Exit;
  if FFocusGroup <> nil then FFocusGroup.FCaption.Invalidate;
  FFocusGroup := G;
  if G <> nil then G.FCaption.Invalidate;
end;

function TSdDock.PanelOf(C: TComponent): TSdDockPanel;
var
  I: Integer;
begin
  Result := nil;
  if C is TSdDockCaption then Result := TSdDockCaption(C).FGroup.FActive
  else if C is TSdDockTabs then Result := TSdDockTabs(C).FGroup.FActive
  else if C is TSdDockAutoTabs then
  begin
    if FSlid <> nil then Result := FSlid.FActive;
  end
  else
    { a panel's control or tool bar, or a control inside them }
    while (Result = nil) and (C is TControl) do
    begin
      for I := 0 to FPanels.Count - 1 do
        if (Panels[I].FControl = C) or (Panels[I].FToolBar = C) then Result := Panels[I];
      C := TControl(C).Parent;
    end;
end;

{ --- changes of the arrangement --- }

procedure TSdDock.ShowPanel(P: TSdDockPanel);
var
  WasShown: Boolean;
begin
  if P = nil then Exit;
  { a view of a hidden group slides out (and stays while it is used) }
  if P.FGroup.FAutoHide then
  begin
    SlideOut(P, False);
    Exit;
  end;
  { a floating group's window comes up, also when the view is shown already }
  if (P.FGroup.FFloat <> nil) and P.FGroup.FFloat.HandleAllocated then
    SetWindowPos(P.FGroup.FFloat.Handle, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
  if P.Showing then Exit;
  WasShown := P.FGroup.VisibleCount > 0;
  P.FVisible := True;
  P.FGroup.FActive := P;
  if not WasShown then MakeRoom(P.FGroup, False);
  Layout;
end;

procedure TSdDock.HidePanel(P: TSdDockPanel);
var
  N: TSdDockPanel;
begin
  if (P = nil) or not P.FVisible then Exit;
  if P.FGroup.VisibleCount = 1 then KeepSize(P.FGroup);
  P.FVisible := False;
  if P.FGroup.FActive = P then
  begin
    N := P.FGroup.NextVisible(P);
    if N <> nil then P.FGroup.FActive := N;
  end;
  Layout;
  if Assigned(FOnPanelHide) then FOnPanelHide(Self, P);
end;

procedure TSdDock.HideGroup(G: TSdDockGroup);
var
  I: Integer;
  Hidden: TList;
begin
  if G = nil then Exit;
  KeepSize(G);
  Hidden := TList.Create;
  try
    for I := 0 to G.FPanels.Count - 1 do
      if G.Panels[I].FVisible then
      begin
        G.Panels[I].FVisible := False;
        Hidden.Add(G.Panels[I]);
      end;
    Layout;
    if Assigned(FOnPanelHide) then
      for I := 0 to Hidden.Count - 1 do FOnPanelHide(Self, TSdDockPanel(Hidden[I]));
  finally
    Hidden.Free;
  end;
end;

procedure TSdDock.MovePanel(P: TSdDockPanel; A: TSdDockArea; Index: Integer);
var
  G: TSdDockGroup;
begin
  if (P = nil) or (A = nil) or (P.FFloatOnly and (A <> FFloatArea)) then Exit;
  if A = FFloatArea then
  begin
    FloatPanel(P, NoRect);
    Exit;
  end;
  if P.FGroup.FPanels.Count = 1 then
  begin
    MoveGroup(P.FGroup, A, Index);
    Exit;
  end;
  G := NewGroup(A, GroupAt(A, Index));
  Detach(P);
  Join(P, G);
  P.FVisible := True;
  MakeRoom(G, True);
  Layout;
end;

procedure TSdDock.MoveGroup(G: TSdDockGroup; A: TSdDockArea; Index: Integer);
var
  Before: TSdDockGroup;
  L: TList;
  K: Integer;
  Stays: Boolean;
begin
  if (G = nil) or (A = nil) or (G.FloatOnly and (A <> FFloatArea)) then Exit;
  if A = FFloatArea then
  begin
    FloatGroup(G, NoRect);
    Exit;
  end;
  { a group that is moved is pinned again }
  if G = FSlid then DropSlide;
  G.FAutoHide := False;
  Before := GroupAt(A, Index);
  { the place it has already: before itself, before the group after it, or last of A }
  L := VisibleGroups(A);
  try
    K := L.IndexOf(G);
    Stays := (K >= 0) and ((Before = G) or ((Before = nil) and (K = L.Count - 1)) or
      ((K + 1 < L.Count) and (Before = L[K + 1])));
  finally
    L.Free;
  end;
  if Stays then Exit;
  PlaceGroup(G, A, Before);
  if G.VisibleCount = 0 then G.FActive.FVisible := True;
  MakeRoom(G, True);
  Layout;
end;

procedure TSdDock.TabPanel(P: TSdDockPanel; G: TSdDockGroup);
var
  WasShown: Boolean;
begin
  if (P = nil) or (G = nil) or (P.FGroup = G) or P.FFloatOnly or G.FloatOnly then Exit;
  WasShown := G.VisibleCount > 0;
  Detach(P);
  Join(P, G);
  P.FVisible := True;
  G.FActive := P;
  if not WasShown then MakeRoom(G, False);
  Layout;
end;

{ --- auto hide (the pin on the caption, Auto Hide in the menu of the views) --- }

{ Unpinned, G hides at the edge of the dock: its views become tabs of its area's strip there and
  the rest of the area takes its room (it keeps its size for when it is pinned again); pinned,
  it takes its place in the area again. }
procedure TSdDock.SetAutoHide(G: TSdDockGroup; Value: Boolean);
begin
  if (G = nil) or (G.FAutoHide = Value) or G.Floating then Exit;   // a floating group has no edge
  if Value then
  begin
    KeepSize(G);
    G.FAutoHide := True;
  end
  else
  begin
    if G = FSlid then DropSlide;
    G.FAutoHide := False;
    if G.VisibleCount > 0 then MakeRoom(G, False);
  end;
  Layout;
end;

{ P's hidden group slides out of the strip over the centre, as wide (high) as its area, P shown.
  ByHover: the pointer rests on its tab - it goes again when the pointer leaves it, unless the
  keyboard came into it meanwhile; else it goes when the keyboard leaves it or a click falls
  elsewhere in the window (AutoTick, SlideMouseHook). Another view of the group that is out
  while the keyboard is in it: the keyboard goes along - the view it was in is hidden, and the
  group went in as the keyboard had left it (a click on another tab hid the panel). }
procedure TSdDock.SlideOut(P: TSdDockPanel; ByHover: Boolean);
var
  G: TSdDockGroup;
  Keys: Boolean;
begin
  if (P = nil) or not P.FGroup.FAutoHide then Exit;
  G := P.FGroup;
  Keys := (G = FSlid) and (G.FActive <> P) and FocusInside(G);
  Inc(FSlideSerial);                              // a slide in posted before this one is void
  P.FVisible := True;
  G.FActive := P;
  if G <> FSlid then
  begin
    FSlid := G;
    FSlidByHover := ByHover;
    FSlidFocused := False;
  end
  else if not ByHover then
    FSlidByHover := False;
  HookSlide(Self);
  FAutoTimer.Enabled := True;
  Layout;
  if Keys then FocusPanel(P);
end;

procedure TSdDock.SlideIn;
begin
  if FSlid = nil then Exit;
  DropSlide;
  Layout;
end;

{ no group is out any more (without a layout: the caller makes one) }
procedure TSdDock.DropSlide;
begin
  FSlid := nil;
  FAutoTimer.Enabled := False;
  if SlideDock = Self then UnhookSlide;
end;

procedure TSdDock.WMSlideIn(var Message: TMessage);
begin
  if Cardinal(Message.WParam) = FSlideSerial then SlideIn;
end;

{ the control that has the keyboard when it is C or lies inside C, else nil }
function FocusIn(C: TControl): TWinControl;
begin
  Result := Screen.ActiveControl;
  if (Result <> nil) and (Result <> C) and not ((C is TWinControl) and TWinControl(C).ContainsControl(Result)) then
    Result := nil;
end;

{ the keyboard is in one of G's views }
function TSdDock.FocusInside(G: TSdDockGroup): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to G.FPanels.Count - 1 do
    if FocusIn(G.Panels[I].FControl) <> nil then Exit;
  Result := False;
end;

{ C can take the keyboard now: it and its parents visible and enabled, in a form that is shown (a
  floating group's window is hidden while the dock's form is not up; TCustomForm.SetFocus raises
  for a hidden form) }
function CanTakeFocus(C: TWinControl): Boolean;
var
  F: TCustomForm;
begin
  F := GetParentForm(C);
  Result := (F <> nil) and F.Visible and F.Enabled and C.CanFocus;
end;

{ C goes to another window - the dock's or a floating group's - and hiding it moves the keyboard
  away (the VCL gives it to the form, a hidden window's goes to another window): the control
  inside C that has it is kept for RestoreFocus }
procedure TSdDock.KeepFocusIn(C: TControl);
begin
  if FKeepFocus <> nil then Exit;
  FKeepFocus := FocusIn(C);
  if FKeepFocus <> nil then FKeepFocus.FreeNotification(Self);
end;

{ at the end of Layout: the keyboard back to the control KeepFocusIn kept, in its new window -
  which a floating group's window is activated for; a view that did not have the keyboard leaves
  it where it is }
procedure TSdDock.RestoreFocus;
var
  C: TWinControl;
begin
  C := FKeepFocus;
  if C = nil then Exit;
  FKeepFocus := nil;
  C.RemoveFreeNotification(Self);
  if CanTakeFocus(C) then C.SetFocus;
end;

procedure TSdDock.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FKeepFocus) then FKeepFocus := nil;
  if (Operation = opRemove) and (AComponent = FCenterHeader) then FCenterHeader := nil;
end;

{ Wnd belongs to the group that is out (its caption, tabs, views) or to the strip it came from }
function TSdDock.InSlide(Wnd: HWND): Boolean;
var
  I: Integer;

  function Within(C: TControl): Boolean;
  begin
    Result := (C is TWinControl) and TWinControl(C).HandleAllocated and
      ((TWinControl(C).Handle = Wnd) or IsChild(TWinControl(C).Handle, Wnd));
  end;

begin
  Result := False;
  if FSlid = nil then Exit;
  Result := Within(FSlid.FCaption) or Within(FSlid.FTabs) or Within(FSlid.FStatus) or
    Within(FSlid.FArea.FAutoTabs) or Within(FSlideSizer);
  for I := 0 to FSlid.FPanels.Count - 1 do
    if not Result and (Within(FSlid.Panels[I].FControl) or Within(FSlid.Panels[I].FToolBar)) then Result := True;
end;

procedure TSdDock.AutoTick(Sender: TObject);
var
  P: TPoint;
begin
  if FSlid = nil then
  begin
    FAutoTimer.Enabled := False;
    Exit;
  end;
  if FocusInside(FSlid) then
    FSlidFocused := True
  else if FSlidFocused then
    SlideIn                                       // the keyboard went elsewhere
  else if FSlidByHover and (FSplitArea = nil) and GetCursorPos(P) then
  begin
    { the pointer has left the group, its edge and its strip (a timer has no message to take it
      from); not while the edge is dragged, which the pointer may run ahead of }
    P := ScreenToClient(P);
    if not PtInRect(FSlid.FBounds, P) and not PtInRect(FSlideSplit, P) and
      not PtInRect(FSlid.FArea.FStrip, P) then SlideIn;
  end;
end;

procedure TSdDock.HoverPanel(P: TSdDockPanel);
begin
  if P = FHoverPanel then Exit;
  FHoverPanel := P;
  FHoverTimer.Enabled := False;
  if (P <> nil) and not ((FSlid = P.FGroup) and (FSlid.FActive = P)) then FHoverTimer.Enabled := True;
end;

{ Only while the pointer still rests on the tab (a timer has no message to take it from): one that
  passed over it on its way out of the window leaves no message behind that ends the hover - the
  VCL's mouse leave comes at idle, after a message -, and its group would slide out and at once in
  again. }
procedure TSdDock.HoverTick(Sender: TObject);
var
  P: TSdDockPanel;
begin
  FHoverTimer.Enabled := False;
  P := FHoverPanel;
  if (P <> nil) and P.FGroup.FAutoHide and (P.FGroup.FArea <> nil) and
    (P.FGroup.FArea.FAutoTabs.PointerPanel = P) then
    SlideOut(P, True)
  else
    FHoverPanel := nil;
end;

{ the user's choice per group (the menu of its views: Tabs); kept with the arrangement }
procedure TSdDock.SetTabSide(G: TSdDockGroup; Side: TUITabSide);
begin
  if (G = nil) or (G.FTabSide = Side) then Exit;
  G.FTabSide := Side;
  G.FTabs.Side := Side;
  Layout;
end;

procedure TSdDock.MergeGroup(G, Target: TSdDockGroup);
var
  L: TList;
  Act: TSdDockPanel;
  I: Integer;
  WasShown: Boolean;
begin
  if (G = nil) or (Target = nil) or (G = Target) or G.FloatOnly or Target.FloatOnly then Exit;
  WasShown := Target.VisibleCount > 0;
  Act := G.FActive;
  L := TList.Create;
  try
    L.Assign(G.FPanels);
    for I := 0 to L.Count - 1 do
    begin
      Detach(TSdDockPanel(L[I]));         // the last one releases G
      Join(TSdDockPanel(L[I]), Target);
    end;
  finally
    L.Free;
  end;
  if Act <> nil then
  begin
    Act.FVisible := True;
    Target.FActive := Act;
  end;
  if not WasShown then MakeRoom(Target, False);
  Layout;
end;

{ --- layout --- }

{ the active panel, the caption and the tabs of G as its panels are }
{ the caption's title: the titles of the visible panels in the group's order (Delphi's dock
  hosts name their windows so) }
function GroupTitle(G: TSdDockGroup): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to G.PanelCount - 1 do
    if G.Panels[I].Visible then
    begin
      if Result <> '' then Result := Result + ', ';
      Result := Result + G.Panels[I].Title;
    end;
end;

procedure TSdDock.SyncGroup(G: TSdDockGroup);
begin
  if ((G.FActive = nil) or not G.FActive.FVisible) and (G.NextVisible(nil) <> nil) then
    G.FActive := G.NextVisible(nil);
  if G.FActive <> nil then
  begin
    G.FCaption.Title := GroupTitle(G);
    SetGroupMenus(G);
  end;
  G.FTabs.Changed;
end;

{ every group but the last of A gets its size (as far as A has room now), the last the rest }
procedure TSdDock.LayoutGroups(A: TSdDockArea);
var
  L: TList;
  I, Pos, Stop, Size, After: Integer;
  G: TSdDockGroup;
  V: Boolean;
begin
  V := A.Vertical;
  if V then
  begin
    Pos := A.FBounds.Top;
    Stop := A.FBounds.Bottom;
  end
  else
  begin
    Pos := A.FBounds.Left;
    Stop := A.FBounds.Right;
  end;
  L := VisibleGroups(A);
  try
    for I := 0 to L.Count - 1 do
    begin
      G := TSdDockGroup(L[I]);
      After := L.Count - 1 - I;
      if After = 0 then
        Size := Stop - Pos
      else
      begin
        Size := G.FSize;
        if Size > Stop - Pos - After * (MinGroup + Gap) then Size := Stop - Pos - After * (MinGroup + Gap);
        if Size < MinGroup then Size := MinGroup;
      end;
      if Size < 0 then Size := 0;
      G.FBounds := Along(A.FBounds, V, Pos, Pos + Size);
      if After > 0 then G.FSplit := Along(A.FBounds, V, Pos + Size, Pos + Size + Gap);
      Inc(Pos, Size + Gap);
    end;
  finally
    L.Free;
  end;
end;

{ an area's strip of hidden groups has tabs }
function HasAutoTabs(A: TSdDockArea): Boolean;
var
  K: Integer;
begin
  Result := False;
  for K := 0 to A.FGroups.Count - 1 do
    if TSdDockGroup(A.FGroups[K]).FAutoHide and (TSdDockGroup(A.FGroups[K]).VisibleCount > 0) then
    begin
      Result := True;
      Exit;
    end;
end;

{ The areas, in the order they were added (an outer bottom area, left, right, bottom), each take
  their auto-hide strip at the edge of what is left, then their room next to it; the centre has
  the rest. The bottom strip lies under the editor, between the left and the right areas, as the
  bottom area does (not across the whole window); an outer bottom area and its strip, taken
  first, lie across the whole window; a hidden group that is out lies next to its strip, as long
  as the strip. OnPanelShow runs after the layout is complete (a handler may change it again). }
procedure TSdDock.Layout;
var
  Rest, Strip: TRect;
  I, S, Room: Integer;
  A: TSdDockArea;
  G: TSdDockGroup;
  L, Fresh: TList;

  { A at the edge of what is left (Rest), its splitter next to it; a centre area leaves the page
    the smallest size of an area }
  procedure Place(A: TSdDockArea);
  var
    S, Room: Integer;
  begin
    A.FAutoTabs.Changed;
    A.FStrip := NoRect;
    A.FBounds := NoRect;
    A.FSplit := NoRect;
    A.FSpan := Rest;
    if HasAutoTabs(A) then A.FStrip := TakeEdge(Rest, A.FEdge, UIDockTabHeight);
    A.FRoom := Rest;
    if GroupAt(A, 0) = nil then Exit;                 // no visible group: no room
    Room := Extent(Rest, not A.Vertical);             // across the edge
    if A.FInCenter then Dec(Room, MinArea);
    S := A.FSize;                                     // cut down while the dock is small; FSize stays
    if S > Room - Gap then S := Room - Gap;
    if S < 0 then S := 0;
    A.FBounds := TakeEdge(Rest, A.FEdge, S);
    A.FSplit := TakeEdge(Rest, A.FEdge, Gap);
    LayoutGroups(A);
  end;

begin
  if FInLayout or (csDestroying in ComponentState) then Exit;
  DropEmptyColumns;
  if (FSlid <> nil) and (not FSlid.FAutoHide or (FSlid.VisibleCount = 0)) then DropSlide;
  Fresh := TList.Create;
  try
    FInLayout := True;
    try
      if HandleAllocated then Rest := ClientRect else Rest := Rect(0, 0, Width, Height);
      L := AllGroups;
      try
        for I := 0 to L.Count - 1 do
        begin
          SyncGroup(TSdDockGroup(L[I]));
          TSdDockGroup(L[I]).FBounds := NoRect;
          TSdDockGroup(L[I]).FSplit := NoRect;
        end;
      finally
        L.Free;
      end;
      for I := 0 to FAreas.Count - 1 do
        if not Areas[I].FInCenter then Place(Areas[I]);
      { the centre: its header across the top, then the centre areas, Center the rest. A hidden
        header gets its place too, so that it appears there }
      FCenterRect := Rest;
      FHeaderRect := NoRect;
      if FCenterHeader <> nil then
        if FCenterHeader.Visible then
          FHeaderRect := TakeEdge(Rest, deTop, FCenterHeader.Height)
        else
          FCenterHeader.BoundsRect := EdgePart(Rest, deTop, FCenterHeader.Height);
      for I := 0 to FAreas.Count - 1 do
        if Areas[I].FInCenter then Place(Areas[I]);
      FPageRect := Rest;
      { the group that is out: as wide (left / right) or high as its area, along its strip - a
        centre area's within the centre }
      FSlideSplit := NoRect;
      if FSlid <> nil then
      begin
        A := FSlid.FArea;
        Strip := A.FStrip;
        if A.FInCenter then Room := Extent(A.FSpan, not A.Vertical) - Extent(Strip, not A.Vertical)
        else if A.Vertical then Room := ClientWidth - (Strip.Right - Strip.Left) else Room := ClientHeight - (Strip.Bottom - Strip.Top);
        { its edge (a splitter's Gap) after it: the group as wide as its area's docked groups }
        FSlideRoom := Room - MinArea - Gap;
        if FSlideRoom < MinArea then FSlideRoom := MinArea;
        S := A.FSize;
        if S > FSlideRoom then S := FSlideRoom;
        if S < MinArea then S := MinArea;
        FSlideSplit := Beside(Strip, A.FEdge, S + Gap);
        FSlid.FBounds := TakeEdge(FSlideSplit, A.FEdge, S);
        FSlideSizer.Edge := A.FEdge;
      end;
      { a floating group fills its window inside the margin (one that has no window yet - the
        dock's form has none - takes no place) }
      for I := 0 to FFloatArea.FGroups.Count - 1 do
      begin
        G := TSdDockGroup(FFloatArea.FGroups[I]);
        if EnsureFloat(G) then
        begin
          G.FBounds := G.FFloat.ClientRect;
          InflateRect(G.FBounds, -FloatMargin, -FloatMargin);
        end;
      end;
      Apply(Fresh);
      ShowFloats;
      { what the change uncovered painted now - a splitter drag's next step comes sooner than the
        paint - here and in the floating groups' windows }
      UIPaintNow(Self);
      for I := 0 to FFloatArea.FGroups.Count - 1 do
      begin
        G := TSdDockGroup(FFloatArea.FGroups[I]);
        if G.FFloat <> nil then UIPaintNow(G.FFloat);
      end;
    finally
      FInLayout := False;
    end;
    if Assigned(FOnPanelShow) then
      for I := 0 to Fresh.Count - 1 do FOnPanelShow(Self, TSdDockPanel(Fresh[I]));
    RestoreFocus;
    FocusChanged;
  finally
    Fresh.Free;
  end;
end;

type
  TPlacement = record
    C: TControl;
    R: TRect;
    Show: Boolean;
    Panel: TSdDockPanel;
  end;

{ Puts every child where Layout says, in one DeferWindowPos batch per parent window (the dock,
  each floating window): what moves, what appears (SWP_SHOWWINDOW, already in place) and what
  goes (SWP_HIDEWINDOW) change together, so no background shows in between. Then the VCL's Visible follows (the window is already in that
  state). Controls that stay hidden are not moved: they get their bounds when they appear.
  Fresh receives the panels whose control appeared. }
procedure TSdDock.Apply(Fresh: TList);
var
  Items: array of TPlacement;
  N, I, K, CapH: Integer;
  L: TList;
  G: TSdDockGroup;
  B, V, BR: TRect;
  Vis: Boolean;

  procedure Put(C: TControl; const R: TRect; Show: Boolean; P: TSdDockPanel);
  begin
    if C = nil then Exit;
    if N = Length(Items) then SetLength(Items, N + 16);
    Items[N].C := C;
    Items[N].R := R;
    Items[N].Show := Show;
    Items[N].Panel := P;
    Inc(N);
  end;

  { The batch for the children of Host (the windows of one batch must have one parent: the dock,
    or a floating group's window), only while Host is on the screen. Before (FormCreate: the
    default arrangement, then the saved one) SWP_SHOWWINDOW made windows visible that the VCL
    counts as not showing: a part hidden afterwards (Visible := False - a group the saved
    arrangement replaces) kept its window, and the default groups' captions showed at start
    until they were freed, before the form designer was shown). }
  procedure Batch(Host: TWinControl);
  var
    I: Integer;
    DWP: HDWP;
    Flags: Cardinal;
  begin
    if not Host.HandleAllocated or not Host.Showing then Exit;
    { a view that appears for the first time gets its window now (hidden), to join the batch }
    for I := 0 to N - 1 do
      if Items[I].Show and (Items[I].C.Parent = Host) and (Items[I].C is TWinControl) then
        TWinControl(Items[I].C).HandleNeeded;
    DWP := BeginDeferWindowPos(N);
    for I := 0 to N - 1 do
      with Items[I] do
        if (DWP <> 0) and (C.Parent = Host) and (C is TWinControl) and TWinControl(C).HandleAllocated then
        begin
          Flags := SWP_NOZORDER or SWP_NOACTIVATE or SWP_NOOWNERZORDER;
          if not Show or EqualRect(C.BoundsRect, R) then Flags := Flags or SWP_NOMOVE or SWP_NOSIZE;
          if Show and not C.Visible then Flags := Flags or SWP_SHOWWINDOW;
          if not Show and C.Visible then Flags := Flags or SWP_HIDEWINDOW;
          if Flags and (SWP_NOMOVE or SWP_SHOWWINDOW or SWP_HIDEWINDOW) <> SWP_NOMOVE then
            DWP := DeferWindowPos(DWP, TWinControl(C).Handle, 0, R.Left, R.Top, R.Right - R.Left,
              R.Bottom - R.Top, Flags);
        end;
    if DWP <> 0 then EndDeferWindowPos(DWP);
  end;

begin
  N := 0;
  Put(FCenterHost, FPageRect, True, nil);
  if (FCenterHeader <> nil) and FCenterHeader.Visible then Put(FCenterHeader, FHeaderRect, True, nil);
  CapH := UIPaneCaptionHeight;
  L := AllGroups;
  try
    for I := 0 to L.Count - 1 do
    begin
      G := TSdDockGroup(L[I]);
      B := G.FBounds;
      { a floating group without its window yet shows nothing }
      Vis := (G.VisibleCount > 0) and (not G.FAutoHide or (G = FSlid)) and
        (not G.Floating or (G.FFloat <> nil));
      Put(G.FCaption, Rect(B.Left, B.Top, B.Right, B.Top + CapH), Vis, nil);
      Put(G.FTabs, G.TabsRect, Vis and G.ShowsTabs, nil);
      V := G.ViewRect;
      BR := G.BarRect;
      for K := 0 to G.FPanels.Count - 1 do
      begin
        Put(G.Panels[K].FControl, V, Vis and G.Panels[K].Showing, G.Panels[K]);
        Put(G.Panels[K].FToolBar, BR, Vis and G.Panels[K].Showing, nil);
      end;
      if G.ShowsStatus then G.FStatus.Text := G.FActive.FStatusText;
      Put(G.FStatus, G.StatusRect, Vis and G.ShowsStatus, nil);
    end;
  finally
    L.Free;
  end;
  for I := 0 to FAreas.Count - 1 do
    Put(Areas[I].FAutoTabs, Areas[I].FStrip, not IsRectEmpty(Areas[I].FStrip), nil);
  Put(FSlideSizer, FSlideSplit, not IsRectEmpty(FSlideSplit), nil);
  Batch(Self);
  for I := 0 to FFloatArea.FGroups.Count - 1 do
    if TSdDockGroup(FFloatArea.FGroups[I]).FFloat <> nil then Batch(TSdDockGroup(FFloatArea.FGroups[I]).FFloat);
  { the VCL's state (and everything the batch could not take: no window yet, a failed batch) }
  for I := 0 to N - 1 do
    with Items[I] do
    begin
      if Show and not EqualRect(C.BoundsRect, R) then C.BoundsRect := R;
      if Show <> C.Visible then
      begin
        C.Visible := Show;
        if Show and (Panel <> nil) then Fresh.Add(Panel);
      end;
    end;
  { the group that is out lies over the centre and the areas }
  if FSlid <> nil then
  begin
    FSlid.FCaption.BringToFront;
    if FSlid.FTabs.Visible then FSlid.FTabs.BringToFront;
    if FSlid.FActive <> nil then
    begin
      FSlid.FActive.FControl.BringToFront;
      if FSlid.FActive.FToolBar <> nil then FSlid.FActive.FToolBar.BringToFront;
    end;
    { its status line too: a part of another group made after it would cover it }
    if (FSlid.FStatus <> nil) and FSlid.FStatus.Visible then FSlid.FStatus.BringToFront;
    if FSlideSizer.Visible then FSlideSizer.BringToFront;
  end;
end;

{ The keyboard to P's view: where it already is inside the view, it stays; else to the panel's
  FocusControl, else to the first control in the view's tab order, else to the view itself. A
  view that holds other controls (the Object Inspector, the Code Explorer, the Object TreeView, the
  Components view) would take the focus itself and do nothing with the keys. A view in a floating
  group's window activates that window. }
procedure TSdDock.FocusPanel(P: TSdDockPanel);
var
  V, F, A: TWinControl;
begin
  if (P = nil) or not (P.FControl is TWinControl) then Exit;
  V := TWinControl(P.FControl);
  if not CanTakeFocus(V) then Exit;
  A := FocusIn(V);
  if (A <> nil) and (A <> V) then Exit;
  F := P.FFocusControl;
  if (F = nil) or not F.CanFocus then F := TWinControlAccess(V).FindNextControl(nil, True, True, False);
  if F = nil then F := V;
  F.SetFocus;
end;

{ a click on a tab. The keyboard, when it was in the group, goes along to the view chosen: the
  view it was in is hidden, and the VCL would give it to the form - a group that slid out would
  go in again then (AutoTick: the keyboard left it) }
procedure TSdDock.ChooseTab(P: TSdDockPanel);
var
  Keys: Boolean;
begin
  Keys := (P.FGroup.FActive <> P) and FocusInside(P.FGroup);
  P.FGroup.FActive := P;
  Layout;
  if Keys then FocusPanel(P);
end;

{ A tab dragged along its strip trades places with a neighbour when the pointer has left the
  tab on that side and is where the tab will be after the move - so that tabs of different
  widths do not swap back and forth. The group's order is the order of its panels: it is
  kept with the arrangement. }
procedure TSdDock.ReorderTab(T: TSdDockTabs; X: Integer);
var
  K, N, Dir, Guard, Lo, Hi: Integer;
  Q: TSdDockPanel;
begin
  { X is a position along the strip, as the tabs' spans (a left or right strip runs from top to
    bottom); the tab changes places with the neighbour the pointer reaches, in the direction it
    moves - the file tabs' rule (SdTabStrip.TabReorderStep) }
  Dir := X - FReorderAt;
  FReorderAt := X;
  for Guard := 1 to T.Tabs.Count do
  begin
    K := T.Tabs.IndexOfObject(FDragPanel);
    N := T.Tabs.Count;
    if K < 0 then Exit;
    T.TabSpan(K, Lo, Hi);
    case TabReorderStep(X, Dir, Lo, Hi, K > 0, K < N - 1) of
      1: Q := T.TabPanel(K + 1);
      -1: Q := T.TabPanel(K - 1);
    else
      Q := nil;
    end;
    if Q = nil then Exit;
    T.FGroup.FPanels.Move(T.FGroup.FPanels.IndexOf(FDragPanel), T.FGroup.FPanels.IndexOf(Q));
    T.Changed;
    T.Update;
  end;
end;

{ --- dragging a caption or a tab --- }

{ Environment Options | Preferences | Auto drag docking off: a drag docks only while Ctrl is
  held (Delphi's rule) }
{ The pointer during a drag of a caption or a tab: crDrag where letting go docks, crNo where it does
  nothing, the arrow while a tab moves along its strip and when the drag ends. Only the dock's
  own cursors are taken back (a wait cursor of someone else stays). }
procedure TSdDock.DragCursor(C: TCursor);
begin
  if (C = crDefault) and (Screen.Cursor <> crDrag) and (Screen.Cursor <> crNo) then Exit;
  if Screen.Cursor <> C then Screen.Cursor := C;
end;

function TSdDock.CanDock: Boolean;
begin
  Result := FAutoDragDocking or (GetKeyState(VK_CONTROL) < 0);
end;

{ the group a drag takes away whole: the group it holds, or the group of the panel it holds when
  that is its only visible one (nil: none) - alone at an edge it would only move along it, so it
  does not count as a group the edge shows }
function TSdDock.DragWhole: TSdDockGroup;
begin
  if FDragGroup <> nil then Result := FDragGroup
  else if (FDragPanel <> nil) and (FDragPanel.FGroup.VisibleCount = 1) then Result := FDragPanel.FGroup
  else Result := nil;
end;

{ the group a drag holds, or the group of the panel it holds }
function TSdDock.DragSource: TSdDockGroup;
begin
  if FDragGroup <> nil then Result := FDragGroup
  else if FDragPanel <> nil then Result := FDragPanel.FGroup
  else Result := nil;
end;

{ where the group the drag comes from is on the screen: its place in the dock, or its window }
function TSdDock.SourceRect: TRect;
var
  G: TSdDockGroup;
begin
  Result := NoRect;
  G := DragSource;
  if G = nil then Exit;
  if G.FFloat <> nil then
    Result := G.FFloat.BoundsRect
  else if not IsRectEmpty(G.FBounds) then
    Result := ScreenRect(Self, G.FBounds);
end;

{ letting go at P (screen) floats what is dragged: not over its own group (a short drag there
  changes nothing), and not a floating group's caption (that moves its window) }
function TSdDock.WouldFloat(const P: TPoint): Boolean;
begin
  Result := (DragSource <> nil) and not ((FDragGroup <> nil) and FDragGroup.Floating) and
    not PtInRect(SourceRect, P);
end;

{ the window what is dragged would float in, let go at P: as large as its group is (or its
  window was), the pointer where it took the caption or the tab }
function TSdDock.FloatRectAt(const P: TPoint): TRect;
var
  G: TSdDockGroup;
  W, H: Integer;
begin
  G := DragSource;
  if (G <> nil) and (FDragGroup <> nil) and not IsRectEmpty(G.FFloatRect) then
  begin
    W := G.FFloatRect.Right - G.FFloatRect.Left;
    H := G.FFloatRect.Bottom - G.FFloatRect.Top;
  end
  else if (G <> nil) and not IsRectEmpty(G.FBounds) then
  begin
    W := G.FBounds.Right - G.FBounds.Left + 2 * (FloatMargin + 1);
    H := G.FBounds.Bottom - G.FBounds.Top + 2 * (FloatMargin + 1);
  end
  else
  begin
    W := 240;
    H := 320;
  end;
  if FDragGrab.X > W - 20 then FDragGrab.X := W - 20;
  Result := Bounds(P.X - FDragGrab.X, P.Y - FDragGrab.Y, W, H);
end;

procedure TSdDock.DragStage(C: TControl; Stage: TSdDockDragStage; X, Y: Integer);
var
  P: TPoint;
  T: TSdDockTarget;
  R, Src: TRect;
  Ok, InStrip, Moving, Floats: Boolean;
begin
  P := C.ClientToScreen(Point(X, Y));
  if Stage = ddStart then
  begin
    FDragControl := C;
    FDragFrom := P;
    FDragging := False;
    FDragGroup := nil;
    FDragPanel := nil;
    if C is TSdDockCaption then
      FDragGroup := TSdDockCaption(C).FGroup
    else if TSdDockTabs(C).TabAt(X, Y) < 0 then
      FDragGroup := TSdDockTabs(C).FGroup    // the strip beside the tabs: the group
    else
    begin
      FDragPanel := TSdDockTabs(C).FGroup.FActive;
      FDragOrder := TSdDockTabs(C).FGroup.FPanels.IndexOf(FDragPanel);
      if TSdDockTabs(C).Vertical then FReorderAt := Y else FReorderAt := X;
    end;
    { where the pointer took it, from the top left of the group (a window it floats in keeps
      the pointer there), and where a floating group's window is }
    Src := SourceRect;
    FDragGrab := Point(P.X - Src.Left, P.Y - Src.Top);
    if (DragSource <> nil) and (DragSource.FFloat <> nil) then
      FDragWindow := DragSource.FFloat.BoundsRect.TopLeft
    else
    begin
      { docked: the window adds its border and margin around the group }
      Inc(FDragGrab.X, FloatMargin + 1);
      Inc(FDragGrab.Y, FloatMargin + 1);
    end;
    { from the tabs: the window it floats in has its caption under the pointer }
    if C is TSdDockTabs then FDragGrab.Y := FloatMargin + 1 + UIPaneCaptionHeight div 2;
    { a click on the caption or a tab activates the panel shown }
    if FDragGroup <> nil then FocusPanel(FDragGroup.FActive) else FocusPanel(FDragPanel);
    Exit;
  end;
  if C <> FDragControl then Exit;
  { a tab moved along its own strip changes the order, it does not dock (across the strip: Y
    for a strip below or above the view, X for one at its left or right) }
  if (FDragPanel <> nil) and TSdDockTabs(C).Vertical then
    InStrip := (X >= -ReorderSlack) and (X < C.Width + ReorderSlack)
  else
    InStrip := (FDragPanel <> nil) and (Y >= -ReorderSlack) and (Y < C.Height + ReorderSlack);
  if Stage = ddMove then
  begin
    if InStrip then
    begin
      HideMarker;
      HideGuides;
      DragCursor(crDefault);
      if TSdDockTabs(C).Vertical then ReorderTab(TSdDockTabs(C), Y) else ReorderTab(TSdDockTabs(C), X);
      Exit;
    end;
    if not FDragging and UIDragStarted(FDragFrom, P) then FDragging := True;
    if not FDragging then Exit;
    { a floating group's caption moves its window along }
    Moving := (FDragGroup <> nil) and (FDragGroup.FFloat <> nil);
    if Moving then
      FDragGroup.FFloat.MoveTo(FDragWindow.X + P.X - FDragFrom.X, FDragWindow.Y + P.Y - FDragFrom.Y);
    { the pointer says what letting go does: dock on the guide it is on, float there (the marker
      the window it would float in), or nothing }
    BuildGuides(P);
    if GuideTarget(T, R) then
    begin
      ShowMarker(R);
      DragCursor(crDrag);
    end
    else if Moving then
    begin
      HideMarker;
      DragCursor(crDefault);
    end
    else if WouldFloat(P) then
    begin
      ShowMarker(FloatRectAt(P));
      DragCursor(crDrag);
    end
    else
    begin
      HideMarker;
      DragCursor(crNo);
    end;
    { above the marker }
    ShowGuides;
    Exit;
  end;
  { let go: the change is made by a posted message (it gives the caption or the tab strip that
    holds the mouse another parent when a group floats or docks again) }
  HideMarker;
  DragCursor(crDefault);
  Ok := False;
  if not InStrip and FDragging then
  begin
    BuildGuides(P);
    Ok := GuideTarget(T, R);
  end;
  HideGuides;
  Floats := not Ok and not InStrip and FDragging and WouldFloat(P);
  if (FDragGroup <> nil) and (FDragGroup.FFloat <> nil) then
    FDragGroup.FFloatRect := FDragGroup.FFloat.BoundsRect;      // where its caption took it
  FDragControl := nil;
  FDragging := False;
  if (Ok or Floats) and HandleAllocated then
  begin
    FPendGroup := FDragGroup;
    FPendPanel := FDragPanel;
    FPendTarget := T;
    FPendFloat := Floats;
    if Floats then FPendRect := FloatRectAt(P);
    PostMessage(Handle, WM_SDDOCKDROP, 0, 0);
  end;
  FDragGroup := nil;
  FDragPanel := nil;
end;

{ the change a drag ended with (DragStage), if what it holds is still there }
procedure TSdDock.WMDrop(var Message: TMessage);
var
  G: TSdDockGroup;
  P: TSdDockPanel;
  T: TSdDockTarget;
begin
  G := FPendGroup;
  P := FPendPanel;
  T := FPendTarget;
  FPendGroup := nil;
  FPendPanel := nil;
  if (G <> nil) and not IsGroup(G) then Exit;
  if (P <> nil) and ((FPanels.IndexOf(P) < 0) or not IsGroup(P.FGroup)) then Exit;
  if (T.Group <> nil) and not IsGroup(T.Group) then Exit;
  if (T.Area <> nil) and (T.Area <> FFloatArea) and (FAreas.IndexOf(T.Area) < 0) then Exit;
  if FPendFloat then
  begin
    if G <> nil then FloatGroup(G, FPendRect) else if P <> nil then FloatPanel(P, FPendRect);
    Exit;
  end;
  { a column of its own beside the areas of that edge (a row at the dock's edge beside outer
    ones), as wide or high as the area it is named after }
  if T.Column then
  begin
    T.Area := AddColumn(T.Area);
    T.Index := -1;
  end;
  if G <> nil then
  begin
    if T.Group <> nil then MergeGroup(G, T.Group) else MoveGroup(G, T.Area, T.Index);
  end
  else if P <> nil then
  begin
    if T.Group <> nil then TabPanel(P, T.Group) else MovePanel(P, T.Area, T.Index);
  end;
end;

{ A press on a caption, a tab or a splitter ends without docking anything: Esc, or another
  window took the mouse (Restore: a tab moved along its strip goes back to its place, the sizes
  a splitter changed are the old ones again), or a group it holds is going (Load, a group that
  lost its last panel). Nothing keeps a pointer to the groups afterwards. }
procedure TSdDock.CancelDrag(Restore: Boolean);
var
  G: TSdDockGroup;
  K: Integer;
  Restored: Boolean;
begin
  HideMarker;
  HideGuides;
  DragCursor(crDefault);
  Restored := False;
  if Restore then
  begin
    { a floating group's window goes back where it was }
    if FDragging and (FDragGroup <> nil) and (FDragGroup.FFloat <> nil) then
      FDragGroup.FFloat.MoveTo(FDragWindow.X, FDragWindow.Y);
    if (FDragPanel <> nil) and (FDragControl is TSdDockTabs) then
    begin
      G := TSdDockTabs(FDragControl).FGroup;
      K := G.FPanels.IndexOf(FDragPanel);
      if (K >= 0) and (K <> FDragOrder) and (FDragOrder >= 0) and (FDragOrder < G.FPanels.Count) then
      begin
        G.FPanels.Move(K, FDragOrder);
        Restored := True;
      end;
    end;
    if FSplitArea <> nil then
    begin
      FSplitArea.FSize := FSplitOld;
      Restored := True;
    end
    else if FSplitGroup <> nil then
    begin
      FSplitGroup.FSize := FSplitOld;
      FSplitNext.FSize := FSplitOldNext;
      Restored := True;
    end;
  end;
  FDragControl := nil;
  FDragGroup := nil;
  FDragPanel := nil;
  FDragging := False;
  FSplitArea := nil;
  FSplitGroup := nil;
  FSplitNext := nil;
  if Restored then Layout;
end;

{ --- the dock guides: where a drop docks ---
  While a group or a view is dragged and docking is allowed (CanDock), guides show where it can
  dock; a drop docks only on one of their buttons, anywhere else it floats (a floating group's
  window just moves). The outer guides lie at the dock's left, right and bottom edges: the areas
  beside the centre at its left and right (BesideTarget), the full-width bottom area
  (OuterTarget). The compass lies in the middle of what is under the pointer: a docked group - a
  tab of it, a group of their own before or after it along its area (GroupTarget) -, a floating
  group's window - a tab of it -, or the centre - the centre areas at its four sides
  (CenterTarget) and, further out below, the area under it (BesideTarget). A button whose drop
  would change nothing is left out (WouldChange). }

const
  EdgeGuide: array[TSdDockEdge] of TSdGuideKind = (gkLeft, gkTop, gkRight, gkBottom);
  { a compass cell's direction from the middle, by what its button shows }
  GuideStep: array[TSdGuideKind] of TPoint = ((X: 0; Y: 0), (X: -1; Y: 0), (X: 0; Y: -1), (X: 1; Y: 0), (X: 0; Y: 1));
  GuideKindNames: array[TSdGuideKind] of string = ('tab', 'left', 'top', 'right', 'bottom');

{ the guides' measures, from the UI font (they follow its DPI): a button, the room between the
  buttons and around them on the backdrop, the shadow's reach }
function GuideSize: Integer;
begin
  Result := 2 * UITextHeight + 2;
end;

function GuideSpacing: Integer;
begin
  Result := GuideSize div 8;
end;

function GuideShadow: Integer;
begin
  Result := GuideSize div 4;
end;

function NoTarget: TSdDockTarget;
begin
  Result.Area := nil;
  Result.Index := -1;
  Result.Group := nil;
  Result.Column := False;
end;

function Middle(const R: TRect): TPoint;
begin
  Result := Point((R.Left + R.Right) div 2, (R.Top + R.Bottom) div 2);
end;

function Inflated(const R: TRect; N: Integer): TRect;
begin
  Result := R;
  InflateRect(Result, N, N);
end;

{ the views beside the centre at A's edge: a new column beside the areas of that edge while the
  edge shows another group (AddColumn; ColumnRect marks its place), else last into A; R the
  marker (client) }
procedure TSdDock.BesideTarget(A: TSdDockArea; var T: TSdDockTarget; var R: TRect);
begin
  T.Area := A;
  T.Column := EdgeShows(A.FEdge, dkBeside, DragWhole);
  if T.Column then
    R := ColumnRect(A)
  else
    R := AreaPart(A, FCenterRect, 0);       // the edge's area as wide (high) as it is, at most the centre
end;

{ the views along the dock's edge of the outer area A (the outermost of its edge, its rows lie
  before it): into A while the outer areas of that edge show no other group, else a row of
  their own at the dock's edge (AddColumn); R the marker as Layout will make it (client) }
procedure TSdDock.OuterTarget(A: TSdDockArea; var T: TSdDockTarget; var R: TRect);
begin
  T.Area := A;
  T.Column := EdgeShows(A.FEdge, dkOuter, DragWhole);
  if T.Column then
    R := AreaPart(A, FirstArea(A.FEdge, dkOuter).FSpan, Gap)
  else
    R := AreaPart(A, A.FRoom, Gap);
end;

{ the views last into the centre area A; R the area, or its place as Layout will make it while
  it takes no room (client) }
procedure TSdDock.CenterTarget(A: TSdDockArea; var T: TSdDockTarget; var R: TRect);
begin
  T.Area := A;
  if GroupAt(A, 0) <> nil then R := A.FBounds else R := AreaPart(A, FPageRect, MinArea + Gap);
end;

{ the views onto the docked group G: its tabs (gkTab), or a group of their own before it (the
  arm towards its area's start, gkTop / gkLeft) or after it; R the marker (client) }
procedure TSdDock.GroupTarget(G: TSdDockGroup; Kind: TSdGuideKind; var T: TSdDockTarget; var R: TRect);
var
  L: TList;
  K, N, Lo, Hi: Integer;
  B: TRect;
begin
  B := G.FBounds;
  T.Area := G.FArea;
  if Kind = gkTab then
  begin
    T.Group := G;
    R := B;
    Exit;
  end;
  if G.FArea.Vertical then
  begin
    Lo := B.Top;
    Hi := B.Bottom;
  end
  else
  begin
    Lo := B.Left;
    Hi := B.Right;
  end;
  L := VisibleGroups(G.FArea);
  try
    K := L.IndexOf(G);
    N := L.Count;
  finally
    L.Free;
  end;
  if Kind in [gkLeft, gkTop] then
  begin
    T.Index := K;
    R := Along(B, G.FArea.Vertical, Lo, (Lo + Hi) div 2);
  end
  else
  begin
    if K < N - 1 then T.Index := K + 1;
    R := Along(B, G.FArea.Vertical, (Lo + Hi) div 2, Hi);
  end;
end;

{ the docked group at P (screen): in an area beside the centre, else in a centre area; nil: none }
function TSdDock.GroupUnder(const P: TPoint): TSdDockGroup;
var
  Q: TPoint;
  I, K: Integer;
  InCenter: Boolean;
  L: TList;
begin
  Result := nil;
  Q := ScreenToClient(P);
  for InCenter := False to True do
    for I := 0 to FAreas.Count - 1 do
    begin
      if ((Areas[I].Kind = dkCenter) <> InCenter) or not PtInRect(Areas[I].FBounds, Q) then Continue;
      L := VisibleGroups(Areas[I]);
      try
        for K := 0 to L.Count - 1 do
          if PtInRect(TSdDockGroup(L[K]).FBounds, Q) then
          begin
            Result := TSdDockGroup(L[K]);
            Exit;
          end;
      finally
        L.Free;
      end;
    end;
end;

function TSdDock.Guide(Index: Integer): TSdDockGuide;
begin
  if FGuides[Index] = nil then
  begin
    FGuides[Index] := TSdDockGuide.CreateNew(Self);
    FGuides[Index].Tag := Index;
    FGuides[Index].FHot := -1;
  end;
  Result := FGuides[Index];
end;

{ the guides for the pointer at P (screen) and the button under it (FHotGuide, FHotButton); none
  while docking is not allowed or a float-only view is dragged }
procedure TSdDock.BuildGuides(const P: TPoint);
const
  OuterEdges: array[1..3] of TSdDockEdge = (deLeft, deRight, deBottom);
var
  I, K, S, Pad: Integer;
  A: TSdDockArea;
  T: TSdDockTarget;
  R, B: TRect;
begin
  FHotGuide := -1;
  FHotButton := -1;
  for I := 0 to High(FGuides) do Guide(I).Clear;
  if not CanDock or (DragSource = nil) or DragSource.FloatOnly then
  begin
    FGuideHost := nil;
    FGuideRect := NoRect;
    Exit;
  end;
  S := GuideSize;
  Pad := S div 2;
  for I := 1 to 3 do
  begin
    if OuterEdges[I] = deBottom then
    begin
      { the outer area itself, not one of its rows (they lie before it), while it has its room }
      A := FirstArea(deBottom, dkOuter);
      if (A <> nil) and IsRectEmpty(A.FRoom) then A := nil;
      if (A <> nil) and A.FColumn then A := A.FBase;
    end
    else
      A := FirstArea(OuterEdges[I], dkBeside);
    if A = nil then Continue;
    T := NoTarget;
    if A.FOuter then OuterTarget(A, T, R) else BesideTarget(A, T, R);
    if not WouldChange(T) then Continue;
    case OuterEdges[I] of
      deLeft: B := Bounds(Pad, (ClientHeight - S) div 2, S, S);
      deRight: B := Bounds(ClientWidth - Pad - S, (ClientHeight - S) div 2, S, S);
    else
      B := Bounds((ClientWidth - S) div 2, ClientHeight - Pad - S, S, S);
    end;
    B := ScreenRect(Self, B);
    FGuides[I].AddBack(Inflated(B, GuideSpacing));
    FGuides[I].AddButton(B, EdgeGuide[OuterEdges[I]], True, T, ScreenRect(Self, R));
  end;
  BuildCompass(P);
  { the button under the pointer, the compass's first }
  for I := 0 to High(FGuides) do
  begin
    K := FGuides[I].ButtonAt(P);
    if K >= 0 then
    begin
      FHotGuide := I;
      FHotButton := K;
      Exit;
    end;
  end;
end;

{ The compass over what lies under P (screen) - it stays over what it was over while the pointer
  is on it: a cross of buttons in cells of the guides' size, the centre's cell in the middle of
  the group, of the floating window or of the centre's page; its backdrop the row and the column
  of the cells shown, with the middle one }
procedure TSdDock.BuildCompass(const P: TPoint);
var
  W: TSdDockGuide;
  Host: TObject;
  G: TSdDockGroup;
  C: TPoint;
  S, Pitch, Col0, Col1, Row0, Row1: Integer;
  E: TSdDockEdge;
  A: TSdDockArea;
  T: TSdDockTarget;
  R: TRect;

  function Cell(Col, Row: Integer): TRect;
  begin
    Result := Bounds(C.X - S div 2 + Col * Pitch, C.Y - S div 2 + Row * Pitch, S, S);
  end;

  { a button Steps cells from the middle in the direction of Kind, unless its drop changes
    nothing (2 away, the outer cell docks beside the centre: Edge); Mark on the screen }
  procedure Add(Kind: TSdGuideKind; Steps: Integer; const T: TSdDockTarget; const Mark: TRect);
  var
    Col, Row: Integer;
  begin
    if not WouldChange(T) then Exit;
    Col := GuideStep[Kind].X * Steps;
    Row := GuideStep[Kind].Y * Steps;
    W.AddButton(Cell(Col, Row), Kind, Steps = 2, T, Mark);
    if Col < Col0 then Col0 := Col;
    if Col > Col1 then Col1 := Col;
    if Row < Row0 then Row0 := Row;
    if Row > Row1 then Row1 := Row;
  end;

  { ... for the target T with its marker R in the dock's coordinates }
  procedure AddAt(Kind: TSdGuideKind; Steps: Integer);
  begin
    Add(Kind, Steps, T, ScreenRect(Self, R));
  end;

  procedure AddGroup(Kind: TSdGuideKind);
  begin
    T := NoTarget;
    GroupTarget(G, Kind, T, R);
    AddAt(Kind, 1);
  end;

begin
  W := FGuides[0];
  if (FGuideHost <> nil) and PtInRect(FGuideRect, P) and
    ((FGuideHost = Self) or IsGroup(TSdDockGroup(FGuideHost))) then
    Host := FGuideHost
  else
  begin
    Host := FloatAt(P);
    if Host = nil then Host := GroupUnder(P);
    if (Host = nil) and PtInRect(FCenterRect, ScreenToClient(P)) and not IsRectEmpty(FPageRect) then Host := Self;
  end;
  FGuideHost := Host;
  FGuideRect := NoRect;
  if Host = nil then Exit;
  S := GuideSize;
  Pitch := S + GuideSpacing;
  Col0 := 0;
  Col1 := 0;
  Row0 := 0;
  Row1 := 0;
  if Host = Self then
  begin
    { the centre: its areas at the page's four sides, the area under it further out below }
    C := Middle(ScreenRect(Self, FPageRect));
    for E := Low(TSdDockEdge) to High(TSdDockEdge) do
    begin
      A := FirstArea(E, dkCenter);
      if A = nil then Continue;
      T := NoTarget;
      CenterTarget(A, T, R);
      AddAt(EdgeGuide[E], 1);
    end;
    A := FirstArea(deBottom, dkBeside);
    if A <> nil then
    begin
      T := NoTarget;
      BesideTarget(A, T, R);
      AddAt(gkBottom, 2);
    end;
  end
  else
  begin
    G := TSdDockGroup(Host);
    if G.Floating then
    begin
      C := Middle(G.FFloat.BoundsRect);
      T := NoTarget;
      T.Area := FFloatArea;
      T.Group := G;
      Add(gkTab, 0, T, G.FFloat.BoundsRect);
    end
    else
    begin
      C := Middle(ScreenRect(Self, G.FBounds));
      AddGroup(gkTab);
      if G.FArea.Vertical then
      begin
        AddGroup(gkTop);
        AddGroup(gkBottom);
      end
      else
      begin
        AddGroup(gkLeft);
        AddGroup(gkRight);
      end;
    end;
  end;
  if W.ButtonCount = 0 then Exit;
  W.AddBack(Inflated(Rect(Cell(Col0, 0).Left, Cell(0, 0).Top, Cell(Col1, 0).Right, Cell(0, 0).Bottom), GuideSpacing));
  W.AddBack(Inflated(Rect(Cell(0, 0).Left, Cell(0, Row0).Top, Cell(0, 0).Right, Cell(0, Row1).Bottom), GuideSpacing));
  UnionRect(FGuideRect, W.FBacks[0], W.FBacks[1]);
end;

{ the guides drawn and above the marker, the button under the pointer highlighted }
procedure TSdDock.ShowGuides;
var
  I: Integer;
begin
  for I := 0 to High(FGuides) do
    if FGuides[I] <> nil then
      if I = FHotGuide then FGuides[I].Render(FHotButton, FLiftGuides) else FGuides[I].Render(-1, FLiftGuides);
  FLiftGuides := False;
end;

procedure TSdDock.HideGuides;
var
  I: Integer;
begin
  for I := 0 to High(FGuides) do
    if FGuides[I] <> nil then FGuides[I].HideGuide;
  FGuideHost := nil;
  FGuideRect := NoRect;
  FHotGuide := -1;
  FHotButton := -1;
end;

{ where a drop docks: the target of the button under the pointer, R its marker (screen) }
function TSdDock.GuideTarget(var T: TSdDockTarget; var R: TRect): Boolean;
var
  B: TSdGuideButton;
begin
  Result := FHotGuide >= 0;
  if not Result then
  begin
    T := NoTarget;
    Exit;
  end;
  B := FGuides[FHotGuide].Button(FHotButton);
  T := B.Target;
  R := B.Mark;
end;

{ --- TSdDockGuide --- }

const
  { Visual Studio 2022's guides: the accent, the tint of the docked part, the backdrop and its
    edge, a button's face and edge, the face under the pointer }
  GuideBlue = $00CC7A00;          // #007ACC
  GuideTint = $00F0D7B8;          // #B8D7F0
  GuideBack = $00F5F2F2;          // #F2F2F5
  GuideBackEdge = $00C5C5C5;
  GuideFace = $00FFFFFF;
  GuideEdge = $00B3B3B3;
  GuideHotFace = $00F7E4CC;       // #CCE4F7
  GuideKey = $00FF00FF;           // the ground while drawing: none of the colours above
  GuideShadowAlpha = 72;          // the shadow's alpha at the backdrop's edge
  { a guide window: a layered pop-up that is never activated and lets the mouse through }
  GuideExStyle = WS_EX_LAYERED or WS_EX_TRANSPARENT or WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE;

{ a button in R: its face (the accent's tint under the pointer) and edge, inside it a window in
  the accent with its title bar, the part where the views dock tinted (all of it but a margin:
  as a tab; Edge: a strip a quarter wide at that side, else a half), and towards that side an
  arrow }
procedure DrawGuideButton(C: TCanvas; const R: TRect; Kind: TSdGuideKind; Edge, Hot: Boolean);
var
  S, I, H, M, X, Y, Q: Integer;
  F, Inner, Part: TRect;
  Tip: array[0..2] of TPoint;
begin
  S := R.Right - R.Left;
  if Hot then C.Brush.Color := GuideHotFace else C.Brush.Color := GuideFace;
  C.FillRect(R);
  if Hot then C.Brush.Color := GuideBlue else C.Brush.Color := GuideEdge;
  C.FrameRect(R);
  I := S * 9 div 32;
  F := Inflated(R, -I);
  C.Brush.Color := GuideBlue;
  C.FrameRect(F);
  C.FillRect(Rect(F.Left, F.Top, F.Right, F.Top + 2));
  Inner := Rect(F.Left + 1, F.Top + 2, F.Right - 1, F.Bottom - 1);
  C.Brush.Color := GuideFace;
  C.FillRect(Inner);
  Part := Inner;
  if Edge then Q := 4 else Q := 2;
  case Kind of
    gkTab: InflateRect(Part, -2, -2);
    gkLeft: Part.Right := Inner.Left + (Inner.Right - Inner.Left) div Q;
    gkRight: Part.Left := Inner.Right - (Inner.Right - Inner.Left) div Q;
    gkTop: Part.Bottom := Inner.Top + (Inner.Bottom - Inner.Top) div Q;
    gkBottom: Part.Top := Inner.Bottom - (Inner.Bottom - Inner.Top) div Q;
  end;
  C.Brush.Color := GuideTint;
  C.FillRect(Part);
  { the docked part's edge towards the rest of the window }
  C.Brush.Color := GuideBlue;
  case Kind of
    gkTab: C.FrameRect(Part);
    gkLeft: C.FillRect(Rect(Part.Right - 1, Part.Top, Part.Right, Part.Bottom));
    gkRight: C.FillRect(Rect(Part.Left, Part.Top, Part.Left + 1, Part.Bottom));
    gkTop: C.FillRect(Rect(Part.Left, Part.Bottom - 1, Part.Right, Part.Bottom));
    gkBottom: C.FillRect(Rect(Part.Left, Part.Top, Part.Right, Part.Top + 1));
  end;
  if Kind = gkTab then Exit;
  { the arrow, in the margin between the window and the button's edge on that side }
  H := I div 2;
  if H < 2 then H := 2;
  M := (I - H) div 2;
  X := (R.Left + R.Right) div 2;
  Y := (R.Top + R.Bottom) div 2;
  case Kind of
    gkLeft:
      begin
        Tip[0] := Point(R.Left + M, Y);
        Tip[1] := Point(R.Left + M + H, Y - H);
        Tip[2] := Point(R.Left + M + H, Y + H);
      end;
    gkRight:
      begin
        Tip[0] := Point(R.Right - 1 - M, Y);
        Tip[1] := Point(R.Right - 1 - M - H, Y - H);
        Tip[2] := Point(R.Right - 1 - M - H, Y + H);
      end;
    gkTop:
      begin
        Tip[0] := Point(X, R.Top + M);
        Tip[1] := Point(X - H, R.Top + M + H);
        Tip[2] := Point(X + H, R.Top + M + H);
      end;
  else
    Tip[0] := Point(X, R.Bottom - 1 - M);
    Tip[1] := Point(X - H, R.Bottom - 1 - M - H);
    Tip[2] := Point(X + H, R.Bottom - 1 - M - H);
  end;
  C.Pen.Color := GuideBlue;
  C.Polygon(Tip);
end;

{ test mode with D7S_GUIDES set to a folder: what a guide window shows, as guide<n>.bmp there -
  its pixels as given to UpdateLayeredWindow (32 bits, premultiplied alpha, top-down), so that a
  picture of the guides can be laid over a capture of the main window (a cloaked layered window
  cannot be captured) }
procedure SaveGuideShot(Bits: PCardinal; W, H, Index: Integer);
var
  Folder: string;
  F: TFileStream;
  FH: TBitmapFileHeader;
  IH: TBitmapInfoHeader;
begin
  Folder := GetEnvironmentVariable('D7S_GUIDES');
  if (Folder = '') or not UITestMode then Exit;
  FillChar(FH, SizeOf(FH), 0);
  FillChar(IH, SizeOf(IH), 0);
  FH.bfType := $4D42;                       // 'BM'
  FH.bfOffBits := SizeOf(FH) + SizeOf(IH);
  FH.bfSize := FH.bfOffBits + Cardinal(W * H * 4);
  IH.biSize := SizeOf(IH);
  IH.biWidth := W;
  IH.biHeight := -H;
  IH.biPlanes := 1;
  IH.biBitCount := 32;
  IH.biCompression := BI_RGB;
  F := TFileStream.Create(IncludeTrailingPathDelimiter(Folder) + 'guide' + IntToStr(Index) + '.bmp', fmCreate);
  try
    F.WriteBuffer(FH, SizeOf(FH));
    F.WriteBuffer(IH, SizeOf(IH));
    F.WriteBuffer(Bits^, W * H * 4);
  finally
    F.Free;
  end;
end;

procedure TSdDockGuide.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := WS_POPUP;
  Params.ExStyle := Params.ExStyle or GuideExStyle;
end;

{ TCustomForm.CreateWindowHandle makes the window without WS_EX_LAYERED and takes it away again
  unless AlphaBlend or TransparentColor is set: without it UpdateLayeredWindow fails and the
  window shows nothing }
procedure TSdDockGuide.CreateWnd;
begin
  inherited CreateWnd;
  SetWindowLong(Handle, GWL_EXSTYLE, GetWindowLong(Handle, GWL_EXSTYLE) or GuideExStyle);
end;

procedure TSdDockGuide.Clear;
begin
  SetLength(FButtons, 0);
  SetLength(FBacks, 0);
end;

procedure TSdDockGuide.AddBack(const R: TRect);
begin
  SetLength(FBacks, Length(FBacks) + 1);
  FBacks[High(FBacks)] := R;
end;

procedure TSdDockGuide.AddButton(const R: TRect; Kind: TSdGuideKind; Edge: Boolean; const T: TSdDockTarget;
  const Mark: TRect);
begin
  SetLength(FButtons, Length(FButtons) + 1);
  FButtons[High(FButtons)].Bounds := R;
  FButtons[High(FButtons)].Kind := Kind;
  FButtons[High(FButtons)].Edge := Edge;
  FButtons[High(FButtons)].Target := T;
  FButtons[High(FButtons)].Mark := Mark;
end;

function TSdDockGuide.ButtonAt(const P: TPoint): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FButtons) do
    if PtInRect(FButtons[I].Bounds, P) then
    begin
      Result := I;
      Exit;
    end;
end;

function TSdDockGuide.ButtonCount: Integer;
begin
  Result := Length(FButtons);
end;

function TSdDockGuide.Button(Index: Integer): TSdGuideButton;
begin
  Result := FButtons[Index];
end;

procedure TSdDockGuide.HideGuide;
begin
  if HandleAllocated then ShowWindow(Handle, SW_HIDE);
  FDrawn := '';
end;

{ The window over the backdrop and its shadow: drawn with GDI on a 32-bit DIB whose ground is
  GuideKey, then the drawing made opaque and the ground the shadow - black, its alpha falling off
  with the distance from the backdrop (moved down by a quarter of its reach) -, and given to the
  window whole (UpdateLayeredWindow: no flicker). Drawn again only when what it shows changed. }
procedure TSdDockGuide.Render(Hot: Integer; Lift: Boolean = False);
var
  WasShown: Boolean;
  W, R: TRect;
  I, X, Y, Wd, Ht, Reach, Down, Dx, Dy, D2, Best: Integer;
  Key: string;
  Dib: HBITMAP;
  Bits, Px: PCardinal;
  DC, ScreenDC: HDC;
  Old: HGDIOBJ;
  C: TCanvas;
  Blend: TBlendFunction;
  Dst, Src: TPoint;
  Size: TSize;
  Fall: Double;
  Backs: array of TRect;
begin
  if Length(FButtons) = 0 then
  begin
    HideGuide;
    Exit;
  end;
  Reach := GuideShadow;
  W := FBacks[0];
  for I := 1 to High(FBacks) do UnionRect(W, W, FBacks[I]);
  InflateRect(W, Reach, Reach);
  Key := Format('%d|%d,%d,%d,%d', [Hot, W.Left, W.Top, W.Right, W.Bottom]);
  for I := 0 to High(FButtons) do
    Key := Key + Format('|%d%d:%d,%d', [Ord(FButtons[I].Kind), Ord(FButtons[I].Edge), FButtons[I].Bounds.Left,
      FButtons[I].Bounds.Top]);
  WasShown := IsWindowVisible(Handle);
  if (Key <> FDrawn) or not WasShown then
  begin
    FDrawn := Key;
    FHot := Hot;
    Wd := W.Right - W.Left;
    Ht := W.Bottom - W.Top;
    Dib := UICreateDib32(Wd, Ht, Bits);
    if Dib = 0 then Exit;
    DC := CreateCompatibleDC(0);
    Old := SelectObject(DC, Dib);
    try
      SetLength(Backs, Length(FBacks));
      for I := 0 to High(FBacks) do
      begin
        Backs[I] := FBacks[I];
        OffsetRect(Backs[I], -W.Left, -W.Top);
      end;
      C := TCanvas.Create;
      try
        C.Handle := DC;
        C.Brush.Color := GuideKey;
        C.FillRect(Rect(0, 0, Wd, Ht));
        { the backdrop: the union's outline, each rectangle's frame covered inside the others }
        C.Brush.Color := GuideBackEdge;
        for I := 0 to High(Backs) do C.FrameRect(Backs[I]);
        C.Brush.Color := GuideBack;
        for I := 0 to High(Backs) do C.FillRect(Inflated(Backs[I], -1));
        for I := 0 to High(FButtons) do
        begin
          R := FButtons[I].Bounds;
          OffsetRect(R, -W.Left, -W.Top);
          DrawGuideButton(C, R, FButtons[I].Kind, FButtons[I].Edge, I = Hot);
        end;
      finally
        C.Handle := 0;
        C.Free;
      end;
      GdiFlush;
      Down := Reach div 4;
      Px := Bits;
      for Y := 0 to Ht - 1 do
        for X := 0 to Wd - 1 do
        begin
          if (Px^ and $FFFFFF) = GuideKey then
          begin
            Best := MaxInt;
            for I := 0 to High(Backs) do
            begin
              Dx := Backs[I].Left - X;
              if X - (Backs[I].Right - 1) > Dx then Dx := X - (Backs[I].Right - 1);
              if Dx < 0 then Dx := 0;
              Dy := Backs[I].Top + Down - Y;
              if Y - (Backs[I].Bottom - 1 + Down) > Dy then Dy := Y - (Backs[I].Bottom - 1 + Down);
              if Dy < 0 then Dy := 0;
              D2 := Dx * Dx + Dy * Dy;
              if D2 < Best then Best := D2;
            end;
            if Best >= Reach * Reach then
              Px^ := 0
            else
            begin
              Fall := 1 - Sqrt(Best) / Reach;
              Px^ := Cardinal(Round(GuideShadowAlpha * Fall * Fall)) shl 24;
            end;
          end
          else
            Px^ := Px^ or $FF000000;
          Inc(Px);
        end;
      ScreenDC := GetDC(0);
      try
        Dst := W.TopLeft;
        Size.cx := Wd;
        Size.cy := Ht;
        Src := Point(0, 0);
        Blend.BlendOp := AC_SRC_OVER;
        Blend.BlendFlags := 0;
        Blend.SourceConstantAlpha := 255;
        Blend.AlphaFormat := AC_SRC_ALPHA;
        FFailed := not UpdateLayeredWindow(Handle, ScreenDC, @Dst, @Size, DC, @Src, 0, @Blend, ULW_ALPHA);
      finally
        ReleaseDC(0, ScreenDC);
      end;
      SaveGuideShot(Bits, Wd, Ht, Tag);
    finally
      SelectObject(DC, Old);
      DeleteDC(DC);
      DeleteObject(Dib);
    end;
  end;
  { shown without activation, above the drop marker - only when it appears or the marker has just
    appeared: a change of the z-order at every move of the pointer makes the windows flicker }
  if Lift or not WasShown then
    SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_SHOWWINDOW);
end;

{ The floating window at P (screen) that the pointer is over - not the one being moved, and not
  the window of a float-only view (it takes no other views). Where
  several lie there, the one on top: the windows in their z-order (a window raised by ShowPanel
  keeps its place in the area's list), from the first top-level window down - this works on the
  cloaked test instance too, where WindowFromPoint finds nothing. }
function TSdDock.FloatAt(const P: TPoint): TSdDockGroup;
var
  I, N: Integer;
  W: HWND;

  function Under(G: TSdDockGroup): Boolean;
  begin
    Result := (G <> FDragGroup) and (G.FFloat <> nil) and G.FFloat.Visible and
      G.FFloat.HandleAllocated and PtInRect(G.FFloat.BoundsRect, P) and not G.FloatOnly;
  end;

begin
  Result := nil;
  N := 0;
  for I := 0 to FFloatArea.FGroups.Count - 1 do
    if Under(TSdDockGroup(FFloatArea.FGroups[I])) then
    begin
      Result := TSdDockGroup(FFloatArea.FGroups[I]);
      Inc(N);
    end;
  if N < 2 then Exit;
  W := GetTopWindow(0);
  while W <> 0 do
  begin
    for I := 0 to FFloatArea.FGroups.Count - 1 do
      if Under(TSdDockGroup(FFloatArea.FGroups[I])) and (TSdDockGroup(FFloatArea.FGroups[I]).FFloat.Handle = W) then
      begin
        Result := TSdDockGroup(FFloatArea.FGroups[I]);
        Exit;
      end;
    W := GetWindow(W, GW_HWNDNEXT);
  end;
end;

function TSdDock.WouldChange(const T: TSdDockTarget): Boolean;
var
  G: TSdDockGroup;
  L: TList;
  Pos, Idx: Integer;
begin
  Result := False;
  if FDragGroup <> nil then G := FDragGroup
  else if FDragPanel <> nil then G := FDragPanel.FGroup
  else Exit;
  if T.Group <> nil then
  begin
    Result := T.Group <> G;
    Exit;
  end;
  { a new column (the edge shows another group, BesideTarget): a change, but for the only group of
    the innermost column of that edge, or of the outermost outer area that shows one - the new
    one would take its place }
  if T.Column then
  begin
    Result := True;
    if (G.FArea.FEdge <> T.Area.FEdge) or (G.FArea.FOuter <> T.Area.FOuter) or
      not (G.FArea.FColumn or G.FArea.FOuter) or ((FDragGroup = nil) and (G.VisibleCount > 1)) then Exit;
    L := VisibleGroups(G.FArea);
    try
      if L.Count > 1 then Exit;
    finally
      L.Free;
    end;
    if G.FArea.FOuter then
    begin
      for Idx := 0 to FAreas.IndexOf(G.FArea) - 1 do
        if (Areas[Idx].FEdge = T.Area.FEdge) and Areas[Idx].FOuter and (GroupAt(Areas[Idx], 0) <> nil) then Exit;
    end
    else
      for Idx := FAreas.IndexOf(G.FArea) + 1 to FAreas.Count - 1 do
        if (Areas[Idx].FEdge = T.Area.FEdge) and (Areas[Idx].Kind = dkBeside) and (GroupAt(Areas[Idx], 0) <> nil) then Exit;
    Result := False;
    Exit;
  end;
  { a panel that leaves a group of several makes a group of its own anywhere }
  if (FDragGroup = nil) and (G.FPanels.Count > 1) then
  begin
    Result := True;
    Exit;
  end;
  Result := T.Area <> G.FArea;
  if Result then Exit;
  L := VisibleGroups(T.Area);
  try
    Pos := L.IndexOf(G);
    Idx := T.Index;
    if Idx < 0 then Idx := L.Count;
    Result := (Idx <> Pos) and (Idx <> Pos + 1);
  finally
    L.Free;
  end;
end;

{ The drop marker: a translucent highlight window over the target (a window of its own, so
  nothing is drawn on the screen of other programs; the test guard cloaks it like any window
  of D7 Studio). }
procedure TSdDock.ShowMarker(const R: TRect);
var
  Old: TRect;
begin
  if FMarker = nil then
  begin
    FMarker := TForm.CreateNew(Self);
    FMarker.BorderStyle := bsNone;
    FMarker.Color := clHighlight;
    FMarker.AlphaBlend := True;
    FMarker.AlphaBlendValue := 80;
  end;
  if IsWindowVisible(FMarker.Handle) then
  begin
    { shown already: moved only when its place changed, and kept where it is in the z-order -
      under the dock guides (raising it at every move of the pointer, and the guides above it
      again, made them flicker) }
    GetWindowRect(FMarker.Handle, Old);
    if not EqualRect(Old, R) then
      SetWindowPos(FMarker.Handle, 0, R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top,
        SWP_NOACTIVATE or SWP_NOZORDER);
  end
  else
  begin
    { shown without activation: Visible := True would take the focus from the main window; the
      guides go above it again (ShowGuides) }
    SetWindowPos(FMarker.Handle, HWND_TOPMOST, R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top,
      SWP_NOACTIVATE or SWP_SHOWWINDOW);
    FLiftGuides := True;
  end;
end;

procedure TSdDock.HideMarker;
begin
  if (FMarker <> nil) and FMarker.HandleAllocated then ShowWindow(FMarker.Handle, SW_HIDE);
end;

{ --- splitters: the gaps of the dock itself --- }

function TSdDock.SplitAt(const P: TPoint; var A: TSdDockArea; var G: TSdDockGroup): Boolean;
var
  I: Integer;
  L: TList;
begin
  A := nil;
  G := nil;
  { the edge of the group that is out lies over the others }
  if (FSlid <> nil) and PtInRect(FSlideSplit, P) then
  begin
    A := FSlid.FArea;
    Result := True;
    Exit;
  end;
  for I := 0 to FAreas.Count - 1 do
    if PtInRect(Areas[I].FSplit, P) then A := Areas[I];
  if A = nil then
  begin
    L := AllGroups;
    try
      for I := 0 to L.Count - 1 do
        if PtInRect(TSdDockGroup(L[I]).FSplit, P) then G := TSdDockGroup(L[I]);
    finally
      L.Free;
    end;
  end;
  Result := (A <> nil) or (G <> nil);
end;

procedure TSdDock.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  L: TList;
  V: Boolean;
  I, Least: Integer;
begin
  inherited;
  if (Button <> mbLeft) or not SplitAt(Point(X, Y), FSplitArea, FSplitGroup) then Exit;
  FSplitFrom := Point(X, Y);
  if (FSlid <> nil) and (FSplitArea = FSlid.FArea) and PtInRect(FSlideSplit, FSplitFrom) then
  begin
    { the edge of the group that is out: the area's size is the group's, which may take what
      Layout leaves it beside its strip }
    FSplitOld := FSplitArea.FSize;
    FSplitSize := Extent(FSlid.FBounds, not FSplitArea.Vertical);
    FSplitRoom := FSlideRoom;
  end
  else if FSplitArea <> nil then
  begin
    { the area's width (left/right) or height, and what it may take from the centre }
    V := not FSplitArea.Vertical;
    FSplitOld := FSplitArea.FSize;
    FSplitSize := Extent(FSplitArea.FBounds, V);
    if FSplitArea.FInCenter then FSplitRoom := FSplitSize + Extent(FPageRect, V) - MinArea
    else FSplitRoom := FSplitSize + Extent(FCenterRect, V) - MinArea;
    { an outer area takes its room from the areas across it too (an outer bottom area from the
      left and right areas): each keeps the smallest size of its groups }
    if FSplitArea.FOuter then
      for I := FAreas.IndexOf(FSplitArea) + 1 to FAreas.Count - 1 do
        if (Areas[I].Vertical <> FSplitArea.Vertical) and not IsRectEmpty(Areas[I].FBounds) then
        begin
          L := VisibleGroups(Areas[I]);
          try
            Least := L.Count * MinGroup + (L.Count - 1) * Gap;
          finally
            L.Free;
          end;
          if FSplitSize + Extent(Areas[I].FBounds, V) - Least < FSplitRoom then
            FSplitRoom := FSplitSize + Extent(Areas[I].FBounds, V) - Least;
        end;
  end
  else
  begin
    { The two groups at the splitter share the room they have on the screen (a small window may
      have cut their sizes down). Moving it gives both their sizes; the other groups keep the
      sizes the user gave them. }
    V := FSplitGroup.FArea.Vertical;
    L := VisibleGroups(FSplitGroup.FArea);
    try
      FSplitNext := TSdDockGroup(L[L.IndexOf(FSplitGroup) + 1]);
    finally
      L.Free;
    end;
    FSplitOld := FSplitGroup.FSize;
    FSplitOldNext := FSplitNext.FSize;
    FSplitSize := Extent(FSplitGroup.FBounds, V);
    FSplitRoom := FSplitSize + Extent(FSplitNext.FBounds, V);
  end;
end;

procedure TSdDock.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  A: TSdDockArea;
  G: TSdDockGroup;
  D, S: Integer;
begin
  inherited;
  if (ssLeft in Shift) and ((FSplitArea <> nil) or (FSplitGroup <> nil)) then
  begin
    if FSplitArea <> nil then
    begin
      case FSplitArea.FEdge of
        deLeft: D := X - FSplitFrom.X;
        deRight: D := FSplitFrom.X - X;
        deTop: D := Y - FSplitFrom.Y;
      else
        D := FSplitFrom.Y - Y;
      end;
      S := FSplitSize + D;
      if S > FSplitRoom then S := FSplitRoom;
      if S < MinArea then S := MinArea;
      FSplitArea.FSize := S;
    end
    else
    begin
      if FSplitGroup.FArea.Vertical then D := Y - FSplitFrom.Y else D := X - FSplitFrom.X;
      S := FSplitSize + D;
      if S > FSplitRoom - MinGroup then S := FSplitRoom - MinGroup;
      if S < MinGroup then S := MinGroup;
      { too little room for both at their smallest: the splitter stays }
      if FSplitRoom - S >= MinGroup then
      begin
        FSplitGroup.FSize := S;
        FSplitNext.FSize := FSplitRoom - S;
      end;
    end;
    Layout;
    Exit;
  end;
  { the pointer over a splitter }
  if not SplitAt(Point(X, Y), A, G) then Cursor := crDefault
  else if ((A <> nil) and A.Vertical) or ((G <> nil) and not G.FArea.Vertical) then Cursor := crHSplit
  else Cursor := crVSplit;
end;

procedure TSdDock.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  FSplitArea := nil;
  FSplitGroup := nil;
  FSplitNext := nil;
end;

{ Esc, or another window took the mouse (UIOnPressCancel), while a caption, a tab strip or the
  dock (a splitter) held it: the press ends without closing or moving anything - a tab moved
  along its strip goes back, a splitter's sizes are the old ones again }
procedure TSdDock.PressCancelled(Sender: TObject);
begin
  if (Sender is TSdDockCaption) and (TSdDockCaption(Sender).FButtons <> nil) then
    TSdDockCaption(Sender).FButtons.Reset;
  CancelDrag(True);
end;

{ --- settings: [Section] Version=2, <area>Width / <area>Height, Groups=n and
  Group<i>=area,size,active,panel,-hidden panel,... (area by area, in stacking order) --- }

procedure TSdDock.Load(Ini: TCustomIniFile; const Section: string);
var
  I, K, Act: Integer;
  S: string;
  R: TRect;
  Side: TUITabSide;
  F: TStringList;
  Placed, Home, Made: TList;
  A: TSdDockArea;
  G: TSdDockGroup;
  P: TSdDockPanel;

  { the panel an entry names: "name", or "-name" for a hidden one }
  function EntryPanel(const Entry: string): TSdDockPanel;
  begin
    Result := FindPanel(Copy(Entry, 1 + Ord(Copy(Entry, 1, 1) = '-'), MaxInt));
  end;

begin
  { the arrangement is replaced (also while the debugger stops, with the button down): a drag
    that is running ends here }
  CancelDrag(False);
  for I := 0 to FAreas.Count - 1 do
  begin
    Areas[I].FSize := Ini.ReadInteger(Section, SizeKey(Areas[I]), Areas[I].FSize);
    if Areas[I].FSize < MinArea then Areas[I].FSize := MinArea;
  end;
  if Ini.ReadInteger(Section, 'Version', 1) = DockVersion then
  begin
    F := TStringList.Create;
    Placed := TList.Create;
    Home := TList.Create;
    Made := TList.Create;
    try
      { the group each view was added to: a view the saved arrangement does not name (new in this
        version) joins its companions there, and does not stay behind in a group of its own }
      for I := 0 to FPanels.Count - 1 do Home.Add(Panels[I].FGroup);
      for I := 1 to Ini.ReadInteger(Section, 'Groups', 0) do
      begin
        F.CommaText := Ini.ReadString(Section, 'Group' + IntToStr(I), '');
        if F.Count < 4 then Continue;
        A := FindArea(F[0]);
        { a column (Left2 ..., a row BottomFull2 ...): made again, in the saved order - the
          groups are saved area by area, so an inner column comes after the outer one, a row
          before the rows inside it (PlaceColumn); one of the arrangement replaced moves to its
          place in the same way, as if made again }
        if (A <> nil) and A.FColumn and (Made.IndexOf(A) < 0) then
        begin
          PlaceColumn(A, True);
          Made.Add(A);
        end;
        if A = nil then
        begin
          A := ColumnNamed(F[0]);
          if A <> nil then
          begin
            Made.Add(A);
            A.FSize := Ini.ReadInteger(Section, SizeKey(A), A.FSize);
            if A.FSize < MinArea then A.FSize := MinArea;
          end;
        end;
        if A = nil then Continue;
        G := nil;
        for K := 3 to F.Count - 1 do
        begin
          P := EntryPanel(F[K]);
          if (P = nil) or (Placed.IndexOf(P) >= 0) then Continue;
          Placed.Add(P);
          if G = nil then
          begin
            G := NewGroup(A, nil);
            G.FSize := StrToIntDef(F[1], G.FSize);
            if G.FSize < MinGroup then G.FSize := MinGroup;
          end;
          Detach(P);
          Join(P, G);
          P.FVisible := Copy(F[K], 1, 1) <> '-';
        end;
        { the side of its tabs: Tabs<n>, absent for the default (below the view) }
        if G <> nil then
        begin
          S := Ini.ReadString(Section, 'Tabs' + IntToStr(I), '');
          for Side := Low(TUITabSide) to High(TUITabSide) do
            if SameText(S, TabSideNames[Side]) then G.FTabSide := Side;
          G.FTabs.Side := G.FTabSide;
          G.FAutoHide := Ini.ReadBool(Section, 'AutoHide' + IntToStr(I), False) and (A <> FFloatArea);
          { a floating one: its window (Float<n>=left,top,width,height) and where it docks back
            (Home<n>=area,index) }
          if A = FFloatArea then
          begin
            R := StrToRect(Ini.ReadString(Section, 'Float' + IntToStr(I), ''));
            if not IsRectEmpty(R) then G.FFloatRect := R;
            S := Ini.ReadString(Section, 'Home' + IntToStr(I), '');
            G.FHomeArea := FindArea(Copy(S, 1, Pos(',', S + ',') - 1));
            G.FHomeIndex := StrToIntDef(Copy(S, Pos(',', S + ',') + 1, MaxInt), -1);
          end;
        end;
        { the active panel is the entry at that index; found by its name, as an entry that names
          no panel (a view this version does not have, one named twice) is not in the group }
        Act := StrToIntDef(F[2], -1);
        if (G <> nil) and (Act >= 0) and (Act < F.Count - 3) then
        begin
          P := EntryPanel(F[3 + Act]);
          if (P <> nil) and (P.FGroup = G) then G.FActive := P;
        end;
      end;
      for I := 0 to FPanels.Count - 1 do
        if Placed.IndexOf(Panels[I]) < 0 then
          for K := 0 to FPanels.Count - 1 do
            if (Placed.IndexOf(Panels[K]) >= 0) and (Home[K] = Home[I]) then
            begin
              P := Panels[I];
              G := Panels[K].FGroup;
              Detach(P);
              Join(P, G);
              Break;
            end;
    finally
      Made.Free;
      Home.Free;
      Placed.Free;
      F.Free;
    end;
  end;
  KeepFloatOnly;
  Layout;
end;

procedure TSdDock.Save(Ini: TCustomIniFile; const Section: string);
var
  I, K: Integer;
  L: TList;
  G: TSdDockGroup;
  S: string;
begin
  Ini.EraseSection(Section);
  Ini.WriteInteger(Section, 'Version', DockVersion);
  for I := 0 to FAreas.Count - 1 do Ini.WriteInteger(Section, SizeKey(Areas[I]), Areas[I].FSize);
  L := AllGroups;
  try
    for I := 0 to L.Count - 1 do
    begin
      G := TSdDockGroup(L[I]);
      S := Format('%s,%d,%d', [G.FArea.FName, G.FSize, G.FPanels.IndexOf(G.FActive)]);
      for K := 0 to G.FPanels.Count - 1 do
      begin
        S := S + ',';
        if not G.Panels[K].FVisible then S := S + '-';
        S := S + G.Panels[K].FName;
      end;
      Ini.WriteString(Section, 'Group' + IntToStr(I + 1), S);
      if G.FTabSide <> tsBottom then
        Ini.WriteString(Section, 'Tabs' + IntToStr(I + 1), TabSideNames[G.FTabSide]);
      if G.FAutoHide then Ini.WriteBool(Section, 'AutoHide' + IntToStr(I + 1), True);
      if G.Floating then
      begin
        if G.FFloat <> nil then G.FFloatRect := G.FFloat.BoundsRect;
        Ini.WriteString(Section, 'Float' + IntToStr(I + 1), RectToStr(G.FFloatRect));
        if G.FHomeArea <> nil then
          Ini.WriteString(Section, 'Home' + IntToStr(I + 1), Format('%s,%d', [G.FHomeArea.FName, G.FHomeIndex]));
      end;
    end;
    Ini.WriteInteger(Section, 'Groups', L.Count);
  finally
    L.Free;
  end;
end;

{ test mode: area:panel@left-right,... per group with tabs (positions in its tab strip); then
  area^:panel@top-bottom,... per auto-hide strip (positions along it); during a drag first
  Guide<n>:kind>area[=tab|+column|#index]@left,top,right,bottom[*][!] per guide button shown (n
  0 the compass, 1 - 3 the outer guides; the bounds on the screen, * under the pointer, ! its
  window could not be drawn) }
function TSdDock.DebugTabs: string;
var
  I, K: Integer;
  L: TList;
  T: TSdDockTabs;
  B: TSdGuideButton;
begin
  Result := '';
  for I := 0 to High(FGuides) do
    if (FGuides[I] <> nil) and FGuides[I].HandleAllocated and IsWindowVisible(FGuides[I].Handle) then
      for K := 0 to FGuides[I].ButtonCount - 1 do
      begin
        B := FGuides[I].Button(K);
        Result := Result + Format('Guide%d:%s>%s', [I, GuideKindNames[B.Kind], B.Target.Area.FName]);
        if B.Target.Group <> nil then Result := Result + '=tab'
        else if B.Target.Column then Result := Result + '+column'
        else if B.Target.Index >= 0 then Result := Result + '#' + IntToStr(B.Target.Index);
        Result := Result + Format('@%d,%d,%d,%d', [B.Bounds.Left, B.Bounds.Top, B.Bounds.Right, B.Bounds.Bottom]);
        if (I = FHotGuide) and (K = FHotButton) then Result := Result + '*';
        if FGuides[I].FFailed then Result := Result + '!';
        Result := Result + ';';
      end;
  for I := 0 to FAreas.Count - 1 do
    if Areas[I].FAutoTabs.Visible then
      Result := Result + Areas[I].FName + '^:' + Areas[I].FAutoTabs.DebugPositions + ';';
  L := AllGroups;
  try
    for I := 0 to L.Count - 1 do
    begin
      T := TSdDockGroup(L[I]).FTabs;
      if not T.Visible then Continue;
      Result := Result + TSdDockGroup(L[I]).FArea.FName;
      { a strip that is not below its view: its side; the positions run along the strip }
      if T.Side <> tsBottom then Result := Result + '(' + TabSideNames[T.Side] + ')';
      Result := Result + ':' + T.DebugPositions + ';';
    end;
  finally
    L.Free;
  end;
end;

{ test mode: area:panel*,-hidden WxH; per group (* the active panel; area^: a group hidden at the
  edge, WxH its size while it is out; Float:... WxH@left,top - a floating group, its window on the
  screen, '-' after it while hidden) }
function TSdDock.DebugText: string;
var
  I, K: Integer;
  L: TList;
  G: TSdDockGroup;
  P: TSdDockPanel;
begin
  Result := '';
  L := AllGroups;
  try
    for I := 0 to L.Count - 1 do
    begin
      G := TSdDockGroup(L[I]);
      Result := Result + G.FArea.FName;
      if G.FAutoHide then Result := Result + '^';
      Result := Result + ':';
      for K := 0 to G.FPanels.Count - 1 do
      begin
        P := G.Panels[K];
        if K > 0 then Result := Result + ',';
        if not P.FVisible then Result := Result + '-';
        Result := Result + P.FName;
        if P = G.FActive then Result := Result + '*';
      end;
      Result := Result + Format(' %dx%d', [G.FBounds.Right - G.FBounds.Left, G.FBounds.Bottom - G.FBounds.Top]);
      { a floating group: its window on the screen, '-' after it while the window is hidden }
      if G.Floating then
      begin
        if G.FFloat <> nil then G.FFloatRect := G.FFloat.BoundsRect;
        Result := Result + Format('@%d,%d', [G.FFloatRect.Left, G.FFloatRect.Top]);
        if (G.FFloat = nil) or not G.FFloat.Visible then Result := Result + '-';
      end;
      Result := Result + ';';
    end;
  finally
    L.Free;
  end;
end;

end.
