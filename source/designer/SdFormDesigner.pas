{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdFormDesigner;

{ D7 Studio - the form designer.

  One TFormDesigner per form unit.  The design root is a real VCL form whose class is a
  Borland proxy class (Proxies.pas in designide70.bpl) named after the user's form class, so
  DFM streaming, event-handler tokens and all registered property/component editors behave
  exactly as in the Delphi IDE.  The form is embedded as a captioned child window in a
  scrolling design surface (single-window interface model). }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, ExtCtrls, Menus,
  Clipbrd, TypInfo, IniFiles, DesignIntf, DesignEditors, DesignMenus, Proxies,
  SdUI, SdDesignHost, SdFormPositioner, SdZoom;

const
  CM_SD_UPDATEHELPERS = WM_USER + 301;
  CM_SD_ZOOMRENDER = WM_USER + 302;   // the zoomed design view paints the stage again (TDesignZoomView)
  { snap lines: by default an edge
    within 5 px of a line goes onto it; the lines are the same edges of the other controls of
    the container, 8 px from a control beside it (related controls 8 apart) and
    8 px inside the container's edges - Environment Options | Designer changes them }
  DefSnapDistance = 5;
  DefSnapSpacing = 8;
  DefSnapMargin = 8;

type
  TFormDesigner = class;

  { Source-code side of a designed module; implemented by the IDE's editor page }
  TSdSourceBridge = class
  public
    function GetUnitName: string; virtual; abstract;
    function GetUnitFileName: string; virtual; abstract;
    function GetFormFileName: string; virtual; abstract;
    function GetProjectExeBase: string; virtual; abstract;
    procedure DesignerModified; virtual; abstract;
    procedure ComponentAdded(C: TComponent); virtual; abstract;
    procedure ComponentRemoved(const AName: string); virtual; abstract;
    procedure ComponentRenamed(const OldName, NewName: string); virtual; abstract;
    procedure RootRenamed(const OldName, NewName, OldClass, NewClass: string); virtual; abstract;
    function MethodExists(const AName: string): Boolean; virtual; abstract;
    procedure GetCompatibleMethods(TypeData: PTypeData; Proc: TGetStrProc); virtual; abstract;
    function CreateMethod(const AName: string; TypeData: PTypeData): Boolean; virtual; abstract;
    procedure RenameMethod(const OldName, NewName: string); virtual; abstract;
    procedure ShowMethod(const AName: string); virtual; abstract;
    procedure ActivateDesigner; virtual; abstract;
    { the selection changed (the designer's undo keeps the selection before a change) }
    procedure SelectionChanged; virtual;
    { a frame of the project: the .dfm texts of frame class AClassName and of its ancestors, the
      first ancestor first (False: no frame of that class) }
    function FrameDfms(const AClassName: string; Dfms: TStrings): Boolean; virtual;
    { the new handler MethodName calls InstanceMethod of the placed frame InstancePath first
      (TFormDesigner.ChainCall) }
    procedure ChainCall(const MethodName, InstancePath, InstanceMethod: string; TypeData: PTypeData); virtual;
  end;

  { IDE-wide design services (inspector, menus); assigned by the main form }
  TDesignerNotify = procedure(Designer: TFormDesigner) of object;
  TFocusInspectorEvent = procedure(Key: Char; const PropName: string) of object;
  TDesignContextMenuEvent = procedure(Designer: TFormDesigner; const ScreenPt: TPoint) of object;

  TDesignEnvironment = class
  public
    GridX, GridY: Integer;
    ShowGrid, SnapToGrid: Boolean;
    { snap lines: on, the distance at which an edge snaps, the space between
      controls side by side, the margin inside a container's edges }
    SnapLines: Boolean;
    SnapDistance, SnapSpacing, SnapMargin: Integer;
    ShowCaptions: Boolean;            // the names under the non-visual components
    ShowHints, ExtendedHints: Boolean; // Show designer hints, Show extended control hints
    ShowPositioner: Boolean;          // Show form positioner
    PositionerSnap: Boolean;          // the positioner snaps a dragged form to edges and centre lines
    Options: TCustomIniFile;
    OnSelectionChanged: TDesignerNotify;
    OnModified: TDesignerNotify;
    OnStructureChanged: TDesignerNotify;
    OnFocusInspector: TFocusInspectorEvent;
    OnContextMenu: TDesignContextMenuEvent;
    constructor Create;
  end;

  { the titles of a design-time menu bar: a rectangle per item of the menu (window coordinates;
    empty for an item that is not shown) }
  TMenuBarRects = array of TRect;

  { The root form being designed.  Left/Top are redeclared so that the streaming system and the
    Object Inspector see the designed position while the window itself stays docked. }
  TSdDesignForm = class(TForm)
  private
    FDesignLeft, FDesignTop: Integer;
    FDsg: TFormDesigner;
    FBarHeight: Integer;                 // height of the design-time menu bar (0 = none)
    FFrameActive: Boolean;
    FHitOrigin: TPoint;                  // the window's screen place at the last hit test (WMNCHitTest)
    function OsFrameWanted: Boolean;
    function StageColor: TColor;
    { the frame - PrintDC: a WM_PRINT's (window coordinates), else the window's own }
    procedure PaintOsFrame(PrintDC: HDC = 0);
    procedure PaintNoFrame(PrintDC: HDC = 0);
    procedure DesignStyle(var Style, ExStyle: DWORD);
    function ClientInWindow: TPoint;     // the client area's origin in window coordinates
    function FramedRect: TRect;          // the client area with its scroll bars, window coordinates
    function ScrollBarRgn(Clip: HRGN): HRGN;
    function BarWanted: Boolean;
    function BarRect: TRect;             // window coordinates
    function FrameDC(PrintDC: HDC): HDC;
    procedure ReleaseFrameDC(DC, PrintDC: HDC);
    function GetBarDC(PrintDC: HDC; out Font, OldFont: HFONT): HDC;
    procedure ReleaseBarDC(DC, PrintDC: HDC; Font, OldFont: HFONT);
    function BarItemRects(DC: HDC; const Bar: TRect): TMenuBarRects;
    function BarItemAt(const ScreenPt: TPoint): TMenuItem;
    procedure PaintBar(PrintDC: HDC = 0);
    procedure PaintFrame(PrintDC: HDC = 0);  // the frame, then the menu bar
    procedure WMNCCalcSize(var Message: TWMNCCalcSize); message WM_NCCALCSIZE;
    procedure WMNCPaint(var Message: TMessage); message WM_NCPAINT;
    procedure WMPrint(var Message: TMessage); message WM_PRINT;
    procedure WMNCActivate(var Message: TMessage); message WM_NCACTIVATE;
    procedure WMNCHitTest(var Message: TWMNCHitTest); message WM_NCHITTEST;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WndProc(var Message: TMessage); override;
  public
    procedure DesignShow;
    procedure UpdateMenuBar;             // after the menu or the selection changed
    procedure UpdateBorder;              // after BorderStyle or BorderIcons changed
  published
    property Left: Integer read FDesignLeft write FDesignLeft;
    property Top: Integer read FDesignTop write FDesignTop;
  end;

  { a window of the designer's own on the designed form: the tile or the name of a non-visual
    component, a grab handle, an outline, a snap line. It paints through a bitmap, in one piece.
    SetVisible(True) puts a hidden one on top of the z-order and leaves a shown one where it is
    (KeepHelpersOnTop keeps them over the designed controls); SetBounds calls nothing when the
    window is there already. }
  TRawWnd = class
  private
    FHandle: HWND;
  protected
    procedure WndProc(var Msg: TMessage); virtual;
    procedure Paint(DC: HDC); virtual;
  public
    constructor Create(AParent: HWND);
    destructor Destroy; override;
    procedure SetBounds(X, Y, W, H: Integer);
    procedure SetVisible(Value: Boolean);
    procedure ToTop;
    procedure Invalidate;
    property Handle: HWND read FHandle;
  end;

  TDesignSurface = class(TScrollBox)
  private
    FDesigner: TFormDesigner;
    FStage: TWinControl;
    { the views' flat 1 px border of its own (WS_BORDER); none inside a frame that has one, the
      file page's (TFormDesigner.Create) }
    FBordered: Boolean;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    procedure CMUpdateHelpers(var Message: TMessage); message CM_SD_UPDATEHELPERS;
    procedure WMNCPaint(var Message: TWMNCPaint); message WM_NCPAINT;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: Char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Stage: TWinControl read FStage;
  end;

  TDesignMouseMode =(mmNone, mmMovePending, mmMove, mmSize, mmRubber, mmFormSize);
  TAlignKind = (akLeftEdges, akRightEdges, akTopEdges, akBottomEdges, akHCenters, akVCenters,
    akCenterInWindowH, akCenterInWindowV, akSpaceEquallyH, akSpaceEquallyV, akSameWidth, akSameHeight);
  { the design form is itself the form, or it hosts a data module or a frame }
  THostKind = (hkForm, hkDataModule, hkFrame);

  TFormDesigner = class(TObject, IInterface, IDesignerNotify, IDesignerHook, IDesigner60, IDesigner, ISdZoomView)
  private
    FRoot: TComponent;
    FForm: TSdDesignForm;
    FAncestorRoot: TSdDesignForm;  // visual form inheritance: the ancestor alone (SaveToText writes the differences)
    FSurface: TDesignSurface;
    FBridge: TSdSourceBridge;
    FFoundMethods: TStringList;    // BeginMethodCache's: method name, Objects <> nil: the unit has it
    FSelection: TList;
    FVerbComp: IComponentEditor;            // the editors the context menu's verbs came from (GetVerbs):
    FVerbSels: array of ISelectionEditor;   // kept while its items may run them (their handlers are theirs)
    FHandles: TList;
    FIcons: TList;
    FLateAdds: TList;            // components an editor created itself (TAction.Create(Form) ...)
    FOutlines: TList;
    FSnapLines: TList;                // the snap lines' windows (TSnapLineWnd), made as needed
    FLineRects: array of TRect;       // ... where the last move or size step put them (root coordinates)
    FMoveSnapX, FMoveSnapY: Boolean;  // mmMove: the selection snapped to a line on that axis ...
    FMoveDelta: TPoint;               // ... by this offset for every control
    FPosWnd: HWND;                    // a designed control about to move (WM_WINDOWPOSCHANGING) ...
    FPosOld: TRect;                   // ... and its window's place before (screen coordinates)
    FDragged: TList;                  // mmMove / mmSize: the controls the drag places, then mmMove's
                                      // non-visual components (their tiles) ...
    FDragFrom: array of TRect;        // ... and their bounds when it began (parent coordinates; a
                                      // tile's in the root's)
    FBuffered: TList;                 // the containers made DoubleBuffered for the drag
    FPressWnd: HWND;                  // the window the press of a drag went to ...
    FPressOrigin: TPoint;             // ... and its client origin on the screen then
    FHelperParent: HWND;
    FMode: TDesignMouseMode;
    FHint: THintWindow;               // Show designer hints
    FHintWnd: HWND;                   // ... the window under the pointer when it came
    FHintSince: Cardinal;             // ... and when (GetTickCount)
    FHintTarget: TComponent;
    FHintTimer: TTimer;
    FHintPt: TPoint;
    FStartPt: TPoint;                 // screen coordinates
    FSizeKind: Integer;
    FSizeTarget: TControl;
    FFormHit: Integer;                // mmFormSize: the edge (HTRIGHT, HTBOTTOM, HTBOTTOMRIGHT) ...
    FFormSize: TPoint;                // ... and the form's size when it began
    FDragContainer: TWinControl;
    FModified: Boolean;
    FLoading: Boolean;
    FDestroying: Boolean;
    FUpdatePosted: Boolean;
    FLoadErrors: TStrings;
    FLocked: Boolean;
    FHostKind: THostKind;
    FModuleClass: TComponentClass;    // a custom module's class (ModuleClass) ...
    FModule: TComponent;              // ... and the instance of it that holds the root's own properties
    FBatch: Integer;                  // > 0: many components go at once, StructureChanged once at the end
    FFrameChains: TStringList;        // frame class -> its form files (TStrings; nil: no frame of the project)
    FAncestorTexts: TStringList;      // the ancestors' form texts the form was loaded with (FramesChanged)
    FPendingFrame: string;            // the frame class the reader asked for last (ReaderFindComponentClass)
    FFrameDepth: Integer;             // frames read inside frames
    FPristine: TStringList;           // frame class -> the frame alone, while a form is written
    FFrameClasses: TStringList;       // frame class -> the class of its instances (Objects: TClass)
    FPositioner: TFormPositioner;     // Show form positioner: over the surface's lower right corner
    FWheel: Integer;                  // parts of wheel notches (UIWheelSteps)
    FWheelZoom: Integer;              // ... with the zoom key (SdZoom)
    FZoom: Integer;                   // per cent (100: the surface shows the stage itself)
    FZoomView: TWinControl;           // TDesignZoomView: the stage at the zoom, over the surface
    procedure PositionerMoved(Sender: TObject; ALeft, ATop: Integer; APosition: TPosition);
    { the wheel over the designed form, the stage, the surface or the zoomed view: with the zoom key
      it zooms at ScreenPt, else it scrolls (Shift: sideways, in the zoomed view) }
    procedure Wheel(Keys, WheelDelta: Integer; const ScreenPt: TPoint);
    { the zoom is not 100 %: the zoomed view is shown over the surface }
    function Zoomed: Boolean;
    { a point of the screen over the zoomed view -> the point of the stage it shows, where the stage
      lies on the screen (under the view); not zoomed: the point itself. A point beside the view
      lies on no window of the stage }
    function LivePoint(const ScreenPt: TPoint): TPoint;
    { ... and back: where the zoomed view shows a point of the stage (hints, menus) }
    function ScreenPoint(const LivePt: TPoint): TPoint;
    { the window that has the mouse: the zoomed view's stage window while the view holds it for
      the stage (TDesignZoomView.FCapture), else Windows' }
    function MouseOwner: HWND;
    function ControlAtLive(const LivePt: TPoint): TControl;
    procedure SetZoom(Value: Integer; AtPoint: Boolean; const At: TPoint);
    { the view at the stage's top left: the zoomed view's scroll positions, else the surface's }
    procedure ScrollHome;
    { the stage changed: the zoomed view paints it again - Now: at once (a step of a drag), else
      when the messages of now are done }
    procedure StageShown(Now: Boolean = False);
    procedure ClearHelpers;
    procedure FlushLateAdds;
    procedure PostUpdateHelpers;
    function RootOrigin: TPoint;
    function ControlRectInRoot(C: TControl): TRect;
    function DesignControlOf(C: TControl): TControl;
    function ContainerFor(C: TControl): TWinControl;
    function OnFrameInstance(C: TControl): Boolean;
    function PasteIntoFrame: Boolean;
    function PristineFrame(const AClassName: string): TComponent;
    function SnapX(V: Integer): Integer;
    function SnapY(V: Integer): Integer;
    procedure ShowOutline(Index: Integer; const R: TRect);
    procedure HideOutlines;
    function SnapAxis(Parent: TWinControl; const R: TRect; Horz, MoveLo, MoveHi: Boolean;
      var Delta: Integer): Boolean;
    procedure AddSnapLines(Parent: TWinControl; const R: TRect; Horz, MoveLo, MoveHi: Boolean);
    procedure MoveSnap(DX, DY: Integer);
    function MovedTo(Index, DX, DY: Integer): TPoint;
    procedure ShowSnapLines;
    procedure PlainOverSiblings(DC: HDC);
    procedure GroundChanged(W: TWinControl; Flags: UINT);
    procedure BeginLive(Mode: TDesignMouseMode);
    procedure PlaceLive(const ScreenPt: TPoint);
    procedure EndLive(Keep: Boolean);
    procedure ForgetDragged(AnObject: TPersistent);
    procedure PaintStep;
    procedure PressAt(Wnd: HWND);
    function MessagePoint(Wnd: HWND; X, Y: Integer): TPoint;
    function HandleMouse(Sender: TControl; var Message: TMessage): Boolean;
    procedure MouseDownOn(Sender: TControl; const ScreenPt: TPoint; Shift: TShiftState);
    procedure MouseMoveTo(const ScreenPt: TPoint);
    procedure MouseUpAt(const ScreenPt: TPoint);
    procedure CancelDrag(CaptureLost: Boolean = False);
    procedure BeginFormSize(Hit: Integer; const ScreenPt: TPoint);
    procedure SizeFormTo(const ScreenPt: TPoint);
    procedure SetFormSize(W, H: Integer);
    procedure TrackDesignHint(C: TComponent; const ScreenPt: TPoint);
    procedure HideDesignHint;
    procedure HintTimerTick(Sender: TObject);
    function SizedBounds(DX, DY: Integer): TRect;
    function RootOwns(C: TComponent): Boolean;
    procedure FinishRubber(const ScreenPt: TPoint);
    function DragRect(const ScreenPt: TPoint): TRect;
    function DropPlace(const LivePt: TPoint; out Cont: TWinControl; out P: TPoint): Boolean;
    function AcceptsClass(AClass: TComponentClass): Boolean;
    procedure ReaderFindMethod(Reader: TReader; const MethodName: string; var Address: Pointer; var Error: Boolean);
    procedure PasteFindMethod(Reader: TReader; const MethodName: string; var Address: Pointer; var Error: Boolean);
    { the unit's answers for one read (PasteFindMethod): name -> found, so that it is parsed once
      per name - components that share a handler; Begin: True when this call made the list }
    function BeginMethodCache: Boolean;
    procedure EndMethodCache(Own: Boolean);
    procedure ReaderError(Reader: TReader; const Message: string; var Handled: Boolean);
    procedure ReaderFindComponentClass(Reader: TReader; const AClassName: string; var ComponentClass: TComponentClass);
    procedure ReaderSetName(Reader: TReader; Component: TComponent; var Name: string);
    procedure ReadStream(Root: TComponent; Bin: TStream; CheckMethods: Boolean);
    procedure ReadText(Root: TComponent; const DfmText: string; CheckMethods: Boolean = False);
    procedure ReadInherited(Root: TComponent; Texts: TStrings; Bins: TList);
    function FrameChain(const AClassName: string): TStrings;
    function NewDesignFrame(const AClassName: string; AOwner: TComponent): TComponent;
    procedure ReaderCreateComponent(Reader: TReader; ComponentClass: TComponentClass; var Component: TComponent);
    procedure WriterFindAncestor(Writer: TWriter; Component: TComponent; const Name: string;
      var Ancestor, RootAncestor: TComponent);
    procedure FreePristine;
    procedure FreeFrameChains;
    function AncestorOf(C: TComponent): TComponent;
    procedure PasteComponentRead(Component: TComponent);
    procedure SelectionChanged;
    procedure StructureChanged;
    procedure IconMouse(Icon: TObject; Msg: Cardinal; const ScreenPt: TPoint; Shift: TShiftState);
    procedure HandleDrag(Handle: TObject; Msg: Cardinal; const ScreenPt: TPoint);
    function IsNonVisual(C: TComponent): Boolean;
    function GetSelection(Index: Integer): TPersistent;
    function NewModule(const AName: string): TComponent;
    function SplitModule(const DfmText: string; Module: TComponent; var ModuleText: string): string;
    function ModuleLines(All: Boolean): string;
    procedure MenuEditors;
    function VerbEditor(Index: Integer; out Comp: IComponentEditor; out Sel: ISelectionEditor;
      out Verb: Integer): Boolean;
  protected
    { IInterface (not reference counted: the IDE owns the designer) }
    function QueryInterface(const IID: TGUID; out Obj): HResult; stdcall;
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    { the design surface in AParent; Bordered: with the views' flat 1 px border of its own }
    constructor Create(AParent: TWinControl; ABridge: TSdSourceBridge; Bordered: Boolean = True);
    destructor Destroy; override;
    { documents }
    procedure NewForm(const AName, AClassName: string);
    { Ancestors: the .dfm texts of an inherited form's ancestors, the first one first (visual form
      inheritance: their components come first, marked as the ancestor's). CheckMethods: an event
      whose method the unit does not have stays empty, as for a paste }
    procedure LoadFromText(const DfmText: string; Errors: TStrings; Ancestors: TStrings = nil;
      CheckMethods: Boolean = False);
    function SaveToText: string;
    { undo and redo (SdDesignUndo): the form as DfmText in place of the one shown, the components
      named in Selected (comma text) selected; what the reader skipped (a property or a class it
      does not know) is written to error.log and added to Errors (nil: not wanted) }
    procedure Reload(const DfmText: string; Ancestors: TStrings; const Selected: string;
      Errors: TStrings = nil);
    function SelectionNames: string;          // the selected components' names, comma text
    { selection }
    procedure Select(Item: TPersistent; Add: Boolean = False);
    procedure SelectList(List: TList);
    procedure SelectAll;
    function IsSelected(Item: TPersistent): Boolean;
    function SelectionCount: Integer;
    property Selections[Index: Integer]: TPersistent read GetSelection;
    { commands }
    procedure DeleteSelected;
    { Revert to Inherited (visual form inheritance): the selected components an ancestor
      introduced (or the form) get the ancestor's values again - all their properties, or
      PropName alone }
    function CanRevert: Boolean;
    procedure RevertToInherited(const PropName: string = '');
    procedure CopySelected;
    function SelectionText: string;
    procedure CutSelected;
    procedure PasteFromClipboard;
    procedure PasteText(const Text: string);
    { a component template dropped at ScreenPt: its components in the container there, from that point }
    function DropText(const Text: string; const ScreenPt: TPoint): Boolean;
    function CanPasteNow: Boolean;
    procedure AlignSelected(Kind: TAlignKind);
    procedure AlignSelectedToGrid;
    procedure BringSelectedToFront;
    procedure SendSelectedToBack;
    procedure EditComponent(C: TComponent);
    { the commands the designer's context menu offers for the selection, as Delphi 7's designer
      does: the verbs of the component editor (one component selected), then those of the
      selection editors registered for the selection's class (RegisterSelectionEditor). Result:
      how many of them (the first) are the component editor's }
    function GetVerbs(List: TStrings): Integer;
    { ... the item of verb Index made ready by its editor (PrepareItem: shown, enabled, checked,
      items of its own) }
    procedure PrepareVerb(Index: Integer; const Item: IMenuItem);
    procedure ExecuteVerb(Index: Integer);
    { ... the editors let go (their package unloads: their verbs' items are gone first) }
    procedure ReleaseVerbs;
    function AddComponent(AClass: TComponentClass; AParent: TComponent; ALeft, ATop, AWidth, AHeight: Integer): TComponent;
    { a component dragged from the Components view: the designed control under a screen point
      (nil: not on the visible form), and the component dropped there }
    function ControlAtScreen(const ScreenPt: TPoint): TControl;
    function DropComponent(AClass: TComponentClass; const ScreenPt: TPoint): Boolean;
    { frame class AClassName of the project placed as Delphi's Frames tool places it: an "inline"
      entry named after its class (Frame21), at ScreenPt in the container there (Drop), else in
      the selected container at 16, 16 as a component is added; its field and its unit come with
      it (ComponentAdded). False: not placed - a data module (a beep), no frame of that class }
    function PlaceFrame(const AClassName: string; Drop: Boolean; const ScreenPt: TPoint): Boolean;
    { PlaceFrame may place a frame so (asked before the frame is chosen): not on a data module (a
      beep), not onto a placed frame - the control at ScreenPt (Drop), else the selected component
      the paste goes by (Delphi's message) }
    function FramePlaceable(Drop: Boolean; const ScreenPt: TPoint): Boolean;
    { the components the designer works on: the root, its components and - at any depth - the
      components of the frames placed on it, which are changed but not added, deleted nor
      renamed }
    function IsDesigned(C: TComponent): Boolean;
    { C is a component of a placed frame: the frame's own, not one of the root's }
    function InFrameInstance(C: TComponent): Boolean;
    { the root's components in their order, a placed frame followed by its own (a frame placed in
      it by its own in turn) - without the root }
    procedure GetDesignedComponents(List: TList);
    { a new component may go into C (a container, a menu ...): not onto a placed frame - Delphi's
      message "New components cannot be added to frame instances." then }
    function MayAddTo(C: TComponent): Boolean;
    { the form files of the frames placed on the form (at any depth, with their ancestors') are no
      longer the ones it was read with: a frame changed since (TEditorPage.FollowAncestors reads
      the form again) }
    function FramesChanged: Boolean;
    { the ancestors' form texts the form was read with (visual form inheritance; empty: none) }
    property AncestorTexts: TStringList read FAncestorTexts;
    procedure KeyDown(var Key: Word; Shift: TShiftState);
    function NeighbourOf(C: TControl; DX, DY: Integer): TControl;
    procedure UpdateHelpers;
    { the form positioner: shown for a form with Show form positioner, the form
      where it opens; PlacePositioner puts it into the lower right corner of the view shown again
      (the surface, or the zoomed view);
      PositionerText: test mode's state - 0 (not shown), else 1|TFormPositioner.TestText|Position }
    procedure UpdatePositioner;
    procedure PlacePositioner;
    function PositionerText: string;
    procedure FocusSurface;
    procedure StageChanged;
    procedure RefreshGrid;
    property Root: TComponent read FRoot;
    property Form: TSdDesignForm read FForm;
    property Surface: TDesignSurface read FSurface;
    property Bridge: TSdSourceBridge read FBridge;
    { what the design form stands for (a form, or the host of a data module / frame) }
    property HostKind: THostKind read FHostKind write FHostKind;
    function RootPropVisible(const AName: string): Boolean;
    { a custom module (RegisterCustomModule: TService ...) designed as a data module: set before
      LoadFromText. Module is an instance of its class that holds the root's own properties - those
      of the class that the host does not represent (HostRootProp). The Object Inspector shows them
      with the root's; the designer's form text has them after the host's (SaveToText), and
      LoadFromText takes them into Module again. nil: no custom module }
    property ModuleClass: TComponentClass read FModuleClass write FModuleClass;
    property Module: TComponent read FModule;
    { the root's properties as Delphi writes a root of ModuleClass - the class's published
      properties in their order, then Left, Top, Height, Width -, with the host's values of those
      it represents; '' without a module }
    function ModuleRootText: string;
    property IsModified: Boolean read FModified write FModified;
    property Locked: Boolean read FLocked write FLocked;
    { IDesignerNotify }
    procedure Modified;
    procedure Notification(AnObject: TPersistent; Operation: TOperation);
    { IDesignerHook }
    function GetCustomForm: TCustomForm;
    procedure SetCustomForm(Value: TCustomForm);
    function GetIsControl: Boolean;
    procedure SetIsControl(Value: Boolean);
    function IsDesignMsg(Sender: TControl; var Message: TMessage): Boolean;
    procedure PaintGrid;
    procedure PaintGridTo(DC: HDC);
    procedure ValidateRename(AComponent: TComponent; const CurName, NewName: string);
    function UniqueName(const BaseName: string): string;
    function GetRoot: TComponent;
    { IDesigner60 }
    procedure Activate;
    function CreateMethod(const Name: string; TypeData: PTypeData): TMethod;
    function GetMethodName(const Method: TMethod): string;
    procedure GetMethods(TypeData: PTypeData; Proc: TGetStrProc);
    function GetPathAndBaseExeName: string;
    function GetPrivateDirectory: string;
    function GetBaseRegKey: string;
    function GetIDEOptions: TCustomIniFile;
    procedure GetSelections(const List: IDesignerSelections);
    function MethodExists(const Name: string): Boolean;
    procedure RenameMethod(const CurName, NewName: string);
    procedure SelectComponent(Instance: TPersistent);
    procedure SetSelections(const List: IDesignerSelections);
    procedure ShowMethod(const Name: string);
    procedure GetComponentNames(TypeData: PTypeData; Proc: TGetStrProc);
    function GetComponent(const Name: string): TComponent;
    function GetComponentName(Component: TComponent): string;
    function GetObject(const Name: string): TPersistent;
    function GetObjectName(Instance: TPersistent): string;
    procedure GetObjectNames(TypeData: PTypeData; Proc: TGetStrProc);
    function MethodFromAncestor(const Method: TMethod): Boolean;
    function CreateComponent(ComponentClass: TComponentClass; Parent: TComponent;
      Left, Top, Width, Height: Integer): TComponent;
    function CreateCurrentComponent(Parent: TComponent; const Rect: TRect): TComponent;
    function IsComponentLinkable(Component: TComponent): Boolean;
    function IsComponentHidden(Component: TComponent): Boolean;
    procedure MakeComponentLinkable(Component: TComponent);
    procedure Revert(Instance: TPersistent; PropInfo: PPropInfo);
    function GetIsDormant: Boolean;
    procedure GetProjectModules(Proc: TGetModuleProc);
    function GetAncestorDesigner: IDesigner;
    function IsSourceReadOnly: Boolean;
    function GetScrollRanges(const ScrollPosition: TPoint): TPoint;
    procedure Edit(const Component: TComponent);
    procedure ChainCall(const MethodName, InstanceName, InstanceMethod: string; TypeData: PTypeData);
    procedure CopySelection;
    procedure CutSelection;
    function CanPaste: Boolean;
    procedure PasteSelection;
    procedure DeleteSelection(ADoAll: Boolean = False);
    procedure ClearSelection;
    procedure NoSelection;
    procedure ModuleFileNames(var ImplFileName, IntfFileName, FormFileName: string);
    function GetRootClassName: string;
    function GetShiftState: TShiftState;
    procedure ModalEdit(EditKey: Char; const ReturnWindow: IActivatable);
    procedure SelectItemName(const PropertyName: string);
    procedure Resurrect;
    { IDesigner }
    function GetActiveClassGroup: TPersistentClass;
    function FindRootAncestor(const AClassName: string): TComponent;
    { ISdZoomView: the design view's zoom - each form's own, 100 % when the designer is made; steps
      of 5 % (SdZoom), Fit the whole stage in view. At another zoom than 100 % the stage is shown
      as a picture (TDesignZoomView) and the mouse goes to its place on the stage }
    function ZoomPercent: Integer;
    function CanZoom(Delta: Integer): Boolean;
    procedure ZoomStep(Delta: Integer; AtPoint: Boolean; const At: TPoint);
    procedure ZoomTo(Percent: Integer);
    function CanZoomFit: Boolean;
    procedure ZoomFit;
    { test mode: zoom|shown|origin x,y|client wxh|stage wxh|capture; at 100 %: zoom|0|surface x,y
      (its scroll positions) }
    function ZoomState: string;
  end;

type
  { a left click on the designed form or a control: True when it placed a tool chosen on
    Delphi's palette (the hidden one experts drive, SdOtaPalette) - the click goes no further }
  TPaletteToolHook = function(Designer: TFormDesigner; const ScreenPt: TPoint;
    Shift: TShiftState): Boolean of object;

var
  DesignEnv: TDesignEnvironment;
  PaletteToolHook: TPaletteToolHook;

function HostRootProp(Kind: THostKind; const AName: string): Boolean;
function DfmObjectHeader(const DfmText: string; var ObjName, ObjClass: string): Boolean;
{ the form text with another name and class in its first line }
function DfmRenameRoot(const DfmText, NewName, NewClass: string): string;
{ form text at its root: the first line, the root's properties (Names: the property's name, Texts:
  its lines - with those of a value that goes on over several lines) and the rest, from the first
  child or the closing end on (its lines joined by line breaks, without one at the end) }
procedure SplitDfmRoot(const Dfm: string; var Header: string; Names, Texts: TStrings; var Rest: string);
{ ... and back: the header, the properties' lines and the rest, each with a line break after it }
function JoinDfmRoot(const Header: string; Texts: TStrings; const Rest: string): string;
function DfmIsBinary(const Data: string): Boolean;
function DfmBinaryToText(const Data: string): string;
{ .dfm data (binary or text) as text, and the name and class of its form }
function DfmTextAndHeader(const Data: string; out Text, FormName, FormClass: string): Boolean;
{ ... of a .dfm file; False: no such file, or no form that can be read in it }
function ReadFormHeader(const DfmFile: string; out Text, FormName, FormClass: string): Boolean;
{ ... the name and class alone, read from the start of the data (a binary form's header) without
  converting the form to text }
function DfmHeader(const Data: string; out FormName, FormClass: string): Boolean;
{ the text of a form as a binary .dfm (Delphi's resource form: what it writes for binary forms) }
function DfmTextToBinary(const Text: string): string;

{ component templates (SdRepository): the components copied from the designer as a template -
  placed at 0, 0 (their top left), their events taken out (a template carries no code); a
  template's components moved by DX, DY (where it is put) }
function MakeTemplateText(const Text: string): string;
function ShiftTemplateText(const Text: string; DX, DY: Integer): string;
implementation

uses
  ComCtrls, Themes, Math, SdOsFrame, SdCrashLog, SdSettings, SdEncoding, SdFileNames;

const
  RawClassName = 'SdDesignHelper';
  HandleSize = 5;
  IconSize = 28;
  StageMargin = 8;
  MaxOutlines = 64;

type
  TComponentCracker = class(TComponent);
  TControlCracker = class(TControl);
  TWinControlCracker = class(TWinControl);

  { a frame of the project placed on the designed form (an "inline" entry of its form file), as
    Delphi's designer makes one: a TFrame given the frame's class name (a subclass, as the root),
    its components read from the frame's own form files (NewDesignFrame). It is one piece on the
    form: nothing is dropped into it, its components are not selected. }
  TSdDesignFrame = class(TFrame)
  public
    constructor Create(AOwner: TComponent); override;
  end;
  TDesignStage = class(TSdControl)
  private
    FDesigner: TFormDesigner;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
  protected
    procedure EraseGround(DC: HDC); override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  end;

  { The design view at another zoom than 100 %: over the surface, which keeps the stage at its own
    size under it, the stage - the designed form, its controls, the designer's helpers - painted
    into a picture at its size (WM_PRINT: the windows paint themselves into it) and shown at the
    zoom, scrolled by scroll bars of its own. Whole multiples are pixels made larger, the other
    zooms are smoothed (HALFTONE). The mouse goes on to the stage's window at the place the picture
    shows, as Windows would send it (its hit test, a non-client message for its frame), and the
    capture a press there takes stays the view's while the stage's window holds it in effect
    (FCapture): the view sends that window the moves and the release. The picture is made again
    after every message it passes on that may change it, when the designer says the stage changed
    (StageShown) and once a second. }
  TDesignZoomView = class(TSdScrollControl)
  private
    FDesigner: TFormDesigner;
    FPicture: HBITMAP;        // the stage at its size (a DIB section)
    FPicDC: HDC;
    FPicW, FPicH: Integer;
    FCapture: HWND;           // the stage's window that has the mouse in effect (0: none)
    FPosted: Boolean;         // CM_SD_ZOOMRENDER is on its way
    FTimer: TTimer;
    function Stage: TWinControl;
    function Zoom: Integer;
    procedure FreePicture;
    procedure Render;
    procedure RenderNow;
    procedure RenderLater;
    function StagePoint(X, Y: Integer): TPoint;   // client -> the stage's client
    function ClientPoint(const S: TPoint): TPoint; // ... and back
    function LiveAt(X, Y: Integer): TPoint;        // client -> the screen point of the stage's place
    function TargetAt(const LivePt: TPoint; out Hit: Integer): HWND;
    procedure PassMouse(var Message: TMessage);
    procedure TimerTick(Sender: TObject);
    procedure WMSetCursor(var Message: TWMSetCursor); message WM_SETCURSOR;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMCaptureChanged(var Message: TMessage); message WM_CAPTURECHANGED;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
    procedure CMZoomRender(var Message: TMessage); message CM_SD_ZOOMRENDER;
  protected
    function ContentSize: TPoint; override;      // the stage at the zoom
    function LineSize: Integer; override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WndProc(var Message: TMessage); override;
    procedure PaintBuffer(C: TCanvas); override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  TLineWnd = class(TRawWnd)
  protected
    procedure Paint(DC: HDC); override;
    procedure WndProc(var Msg: TMessage); override;
  end;

  TFrameRect = class
  private
    FLines: array[0..3] of TLineWnd;
    FVisible: Boolean;
  public
    constructor Create(AParent: HWND);
    destructor Destroy; override;
    procedure SetRect(const R: TRect);
    procedure Hide;
  end;

  { a snap line: 1 px in the highlight colour }
  TSnapLineWnd = class(TLineWnd)
  protected
    procedure Paint(DC: HDC); override;
  end;

  TGrabHandle = class(TRawWnd)
  private
    FDesigner: TFormDesigner;
    FTarget: TPersistent;
    FKind: Integer;           // 0 TL, 1 T, 2 TR, 3 R, 4 BR, 5 B, 6 BL, 7 L
    FActive: Boolean;         // sizing allowed (single selection)
  protected
    procedure Paint(DC: HDC); override;
    procedure WndProc(var Msg: TMessage); override;
  end;

  TCompCaption = class;

  { The tile of a non-visual component, as Delphi 7 draws it: 28 x 28, clBtnFace, a raised
    1 px bevel (clBtnHighlight on the top and left, clBtnShadow on the right and bottom; the
    top-right corner is highlight, the bottom-left one shadow) and the 24 x 24 palette bitmap
    at 2, 2. With "Show component captions" the component name stands under it. }
  TCompIcon = class(TRawWnd)
  private
    FDesigner: TFormDesigner;
    FComponent: TComponent;
    FCaption: TCompCaption;
  protected
    procedure Paint(DC: HDC); override;
    procedure WndProc(var Msg: TMessage); override;
  public
    destructor Destroy; override;
  end;

  { The name of a non-visual component: UI font, centred under the tile, 2 px below it, on
    the colour of the form. It belongs to the tile: the mouse works on it as on the tile. }
  TCompCaption = class(TRawWnd)
  private
    FDesigner: TFormDesigner;
    FIcon: TCompIcon;
    FText: string;
    FFont: HFONT;             // the font FSize was measured with
    FSize: TSize;             // FText's extent
  protected
    procedure Paint(DC: HDC); override;
    procedure WndProc(var Msg: TMessage); override;
  end;

var
  RawClassAtom: ATOM;         // the helpers' window class (0: not registered yet)

{ the place of a non-visual component on the form (DesignInfo: x in the low, y in the high word) }
function DesignPos(C: TComponent): TPoint;
begin
  Result := Point(Smallint(LongRec(C.DesignInfo).Lo), Smallint(LongRec(C.DesignInfo).Hi));
end;

procedure SetDesignPos(C: TComponent; X, Y: Integer);
begin
  C.DesignInfo := MakeLong(Word(X), Word(Y));
end;

{ a problem nobody is shown at once, into error.log (SdCrashLog) with the stack where it was found }
procedure LogDesignError(const Context, Text: string);
begin
  try
    raise EReadError.Create(Text);
  except
    on E: Exception do LogException(E, Context, SettingsDir + 'error.log');
  end;
end;

{ ---------------------------------------------------------------- DFM helpers }

function DfmIsBinary(const Data: string): Boolean;
begin
  Result := (Length(Data) >= 4) and ((Copy(Data, 1, 4) = 'TPF0') or (Data[1] = #$FF));
end;

type
  TFormWriter = class(TWriter);     // its protected WritePrefix and WriteValue

{ a form's binary data (from its signature on) copied from Input to Output with every string that
  has characters beyond ASCII as a WideString. D7 Studio's text is UTF-8 (UTF-8 mode),
  and the VCL writes such a string as its bytes (TWriter.WriteString sees no difference between it
  and its UTF-8); Delphi's writer (ObjectBinaryToText) writes a WideString in Delphi's Unicode
  notation, #954#945... - as Delphi 7 writes a form with characters beyond ASCII. The form file
  stays ASCII; Delphi 7, dcc32 and programs in any
  code page read it. }
procedure StringsToWide(Input, Output: TStream);
var
  R: TReader;
  W: TFormWriter;

  procedure CopyValue; forward;

  { a string as vaWString, always: TWriter.WriteWideString writes the shorter UTF-8 form, and
    as a plain string (vaString, its bytes in the form's text) where the implicit conversion is
    UTF-8 - in UTF-8 mode, for a string with more ASCII than other characters }
  procedure WriteWide(const S: WideString);
  var
    L: Integer;
  begin
    W.WriteValue(vaWString);
    L := Length(S);
    W.Write(L, SizeOf(L));
    if L > 0 then W.Write(Pointer(S)^, L * SizeOf(WideChar));
  end;

  { properties up to the end of their list }
  procedure CopyProperties;
  begin
    while not R.EndOfList do
    begin
      W.WriteStr(R.ReadStr);
      CopyValue;
    end;
    R.ReadListEnd;
    W.WriteListEnd;
  end;

  procedure CopyValue;
  var
    S: string;
    N: Integer;
  begin
    case R.NextValue of
      vaList:
        begin
          R.ReadValue;
          W.WriteValue(vaList);
          while not R.EndOfList do CopyValue;
          R.ReadListEnd;
          W.WriteListEnd;
        end;
      vaInt8, vaInt16, vaInt32: W.WriteInteger(R.ReadInteger);
      vaInt64: W.WriteInteger(R.ReadInt64);
      vaExtended: W.WriteFloat(R.ReadFloat);
      vaSingle: W.WriteSingle(R.ReadSingle);
      vaCurrency: W.WriteCurrency(R.ReadCurrency);
      vaDate: W.WriteDate(R.ReadDate);
      vaString, vaLString:
        begin
          S := R.ReadString;
          if HasHighBytes(S) then WriteWide(IdeTextToWide(S)) else W.WriteString(S);
        end;
      vaWString, vaUTF8String: WriteWide(R.ReadWideString);
      vaIdent, vaFalse, vaTrue, vaNil, vaNull: W.WriteIdent(R.ReadIdent);
      vaBinary:
        begin
          R.ReadValue;
          R.Read(N, SizeOf(N));
          SetLength(S, N);
          if N > 0 then R.Read(S[1], N);
          W.WriteValue(vaBinary);
          W.Write(N, SizeOf(N));
          if N > 0 then W.Write(S[1], N);
        end;
      vaSet:
        begin
          R.ReadValue;
          W.WriteValue(vaSet);
          repeat
            S := R.ReadStr;
            W.WriteStr(S);
          until S = '';
        end;
      vaCollection:
        begin
          R.ReadValue;
          W.WriteValue(vaCollection);
          while not R.EndOfList do
          begin
            if R.NextValue in [vaInt8, vaInt16, vaInt32] then W.WriteInteger(R.ReadInteger);
            R.CheckValue(vaList);
            W.WriteListBegin;
            CopyProperties;
          end;
          R.ReadListEnd;
          W.WriteListEnd;
        end;
    else
      raise EReadError.Create('Invalid form data');
    end;
  end;

  procedure CopyObject;
  var
    Flags: TFilerFlags;
    Pos: Integer;
  begin
    R.ReadPrefix(Flags, Pos);
    W.WritePrefix(Flags, Pos);
    W.WriteStr(R.ReadStr);           // class
    W.WriteStr(R.ReadStr);           // name
    CopyProperties;
    while not R.EndOfList do CopyObject;
    R.ReadListEnd;
    W.WriteListEnd;
  end;

begin
  R := TReader.Create(Input, 4096);
  try
    W := TFormWriter.Create(Output, 4096);
    try
      R.ReadSignature;
      W.WriteSignature;
      CopyObject;
    finally
      W.Free;
    end;
  finally
    R.Free;
  end;
end;

function FormText(Bin: TStream): string;
var
  Wide: TMemoryStream;
  Txt: TStringStream;
begin
  Wide := TMemoryStream.Create;
  Txt := TStringStream.Create('');
  try
    StringsToWide(Bin, Wide);
    Wide.Position := 0;
    ObjectBinaryToText(Wide, Txt);
    Result := Txt.DataString;
  finally
    Txt.Free;
    Wide.Free;
  end;
end;

function DfmBinaryToText(const Data: string): string;
var
  InS: TStringStream;
begin
  InS := TStringStream.Create(Data);
  try
    if (Data <> '') and (Data[1] = #$FF) then InS.ReadResHeader;
    Result := FormText(InS);
  finally
    InS.Free;
  end;
end;

{ a form's text as a binary form file: its strings beyond ASCII as WideStrings (StringsToWide -
  the VCL's ObjectTextToResource would write them as UTF-8 bytes in UTF-8 mode), after the
  resource header that names the root's class, as ObjectTextToResource writes it. Written into a
  memory stream: FixupResourceHeader writes the size back into the header, and a TStringStream
  would cut the form off there (Delphi 7's TStringStream.Write sets the string's length to the
  end of each write) }
function DfmTextToBinary(const Text: string): string;
var
  InS: TStringStream;
  OutS, Bin, Wide: TMemoryStream;
  ObjName, ObjClass: string;
  Fixup: Integer;
begin
  InS := TStringStream.Create(Text);
  OutS := TMemoryStream.Create;
  Bin := TMemoryStream.Create;
  Wide := TMemoryStream.Create;
  try
    ObjectTextToBinary(InS, Bin);
    Bin.Position := 0;
    StringsToWide(Bin, Wide);
    if not DfmObjectHeader(Text, ObjName, ObjClass) then ObjClass := '';
    OutS.WriteResourceHeader(ObjClass, Fixup);
    OutS.CopyFrom(Wide, 0);
    OutS.FixupResourceHeader(Fixup);
    SetString(Result, PChar(OutS.Memory), OutS.Size);
  finally
    InS.Free;
    OutS.Free;
    Bin.Free;
    Wide.Free;
  end;
end;

function DfmTextAndHeader(const Data: string; out Text, FormName, FormClass: string): Boolean;
begin
  if DfmIsBinary(Data) then Text := DfmBinaryToText(Data) else Text := Data;
  FormName := '';
  FormClass := '';
  Result := DfmObjectHeader(Text, FormName, FormClass);
end;

function ReadFormHeader(const DfmFile: string; out Text, FormName, FormClass: string): Boolean;
begin
  Text := '';
  FormName := '';
  FormClass := '';
  Result := False;
  if FileExistsU(DfmFile) then
    try
      Result := DfmTextAndHeader(ReadFileU(DfmFile), Text, FormName, FormClass);
    except
      Result := False;
    end;
end;

{ a binary form: the first line of its text built from its header as Classes' ObjectBinaryToText
  writes it, so that the name and class are DfmTextAndHeader's }
function DfmHeader(const Data: string; out FormName, FormClass: string): Boolean;
var
  S: TStringStream;
  R: TReader;
  Flags: TFilerFlags;
  Position: Integer;
  Cls, Obj, Line: string;
begin
  FormName := '';
  FormClass := '';
  if not DfmIsBinary(Data) then
  begin
    Result := DfmObjectHeader(Data, FormName, FormClass);
    Exit;
  end;
  S := TStringStream.Create(Data);
  try
    if Data[1] = #$FF then S.ReadResHeader;
    R := TReader.Create(S, 4096);
    try
      R.ReadSignature;
      R.ReadPrefix(Flags, Position);
      Cls := R.ReadStr;
      Obj := R.ReadStr;
    finally
      R.Free;
    end;
  finally
    S.Free;
  end;
  if ffInherited in Flags then Line := 'inherited '
  else if ffInline in Flags then Line := 'inline '
  else Line := 'object ';
  if Obj <> '' then Line := Line + Obj + ': ';
  Line := Line + Cls;
  if ffChildPos in Flags then Line := Line + ' [' + IntToStr(Position) + ']';
  Result := DfmObjectHeader(Line, FormName, FormClass);
end;

function DfmObjectHeader(const DfmText: string; var ObjName, ObjClass: string): Boolean;
var
  Line: string;
  P, C: Integer;
begin
  Result := False;
  P := Pos(#10, DfmText);
  if P = 0 then Line := DfmText else Line := Copy(DfmText, 1, P - 1);
  Line := Trim(Line);
  P := Pos(' ', Line);
  if P = 0 then Exit;
  if not (SameText(Copy(Line, 1, P - 1), 'object') or SameText(Copy(Line, 1, P - 1), 'inherited') or
    SameText(Copy(Line, 1, P - 1), 'inline')) then Exit;
  Line := Trim(Copy(Line, P + 1, MaxInt));
  C := Pos(':', Line);
  if C = 0 then Exit;
  ObjName := Trim(Copy(Line, 1, C - 1));
  ObjClass := Trim(Copy(Line, C + 1, MaxInt));
  P := Pos(' ', ObjClass);
  if P > 0 then ObjClass := Copy(ObjClass, 1, P - 1);
  Result := (ObjName <> '') and (ObjClass <> '');
end;

function DfmRenameRoot(const DfmText, NewName, NewClass: string): string;
var
  P, K: Integer;
  Line: string;
begin
  Result := DfmText;
  P := Pos(#10, DfmText);
  if P = 0 then P := Length(DfmText) + 1;
  Line := Copy(DfmText, 1, P - 1);
  { the keyword (object / inherited / inline) and its indentation stay }
  K := 1;
  while (K <= Length(Line)) and (Line[K] in [' ', #9]) do Inc(K);
  while (K <= Length(Line)) and (Line[K] in ['A'..'Z', 'a'..'z']) do Inc(K);
  if K > Length(Line) then Exit;
  Result := Copy(Line, 1, K - 1) + ' ' + NewName + ': ' + NewClass;
  if (Line <> '') and (Line[Length(Line)] = #13) then Result := Result + #13;
  Result := Result + Copy(DfmText, P, MaxInt);
end;

{ The lines as TStrings.Text splits a text - a line ends at CR LF, CR, LF or #0, and #0 ends the
  text -, read one by one from the start of the root's lines: the children (the bulk of a form) are
  not split into lines. The rest is the remaining lines joined by CR LF without one at the end and
  without the empty lines it starts with, as TStrings gave it: one copy for a text whose line
  breaks are all CR LF. }
procedure SplitDfmRoot(const Dfm: string; var Header: string; Names, Texts: TStrings; var Rest: string);
var
  Len, P, Q, E, Eq: Integer;
  S, T, Entry, Line: string;
  CrLfOnly: Boolean;

  { the line at Q, Q after its line break; False at the text's end }
  function ReadLine(var Q: Integer; out Line: string): Boolean;
  var
    Start: Integer;
  begin
    Result := (Q <= Len) and (Dfm[Q] <> #0);
    if not Result then Exit;
    Start := Q;
    while (Q <= Len) and not (Dfm[Q] in [#0, #10, #13]) do Inc(Q);
    Line := Copy(Dfm, Start, Q - Start);
    if (Q <= Len) and (Dfm[Q] = #13) then Inc(Q);
    if (Q <= Len) and (Dfm[Q] = #10) then Inc(Q);
  end;

begin
  Header := '';
  Rest := '';
  Len := Length(Dfm);
  P := 1;
  if not ReadLine(P, Header) then Exit;
  while True do
  begin
    Q := P;
    if not ReadLine(Q, S) then Break;
    T := LowerCase(TrimLeft(S));
    { a root property starts at column 3; children and the closing "end" finish the list }
    if (Copy(S, 1, 2) <> '  ') or (Copy(S, 3, 1) = ' ') or (Copy(T, 1, 7) = 'object ') or
      (Copy(T, 1, 10) = 'inherited ') or (Copy(T, 1, 7) = 'inline ') then Break;
    P := Q;
    Entry := S;
    while ReadLine(Q, Line) and (Copy(Line, 1, 3) = '   ') do
    begin
      Entry := Entry + #13#10 + Line;
      P := Q;
    end;
    Eq := Pos('=', S);
    if Eq = 0 then Eq := Length(S) + 1;
    Names.Add(Trim(Copy(S, 1, Eq - 1)));
    Texts.Add(Entry);
  end;
  { the rest from P: its empty lines first left out }
  while (P <= Len) and (Dfm[P] in [#13, #10]) do
    if (Dfm[P] = #13) and (P < Len) and (Dfm[P + 1] = #10) then Inc(P, 2) else Inc(P);
  CrLfOnly := True;
  E := P;
  while (E <= Len) and (Dfm[E] <> #0) do
  begin
    if Dfm[E] = #13 then
    begin
      if (E < Len) and (Dfm[E + 1] = #10) then Inc(E) else CrLfOnly := False;
    end
    else if Dfm[E] = #10 then
      CrLfOnly := False;
    Inc(E);
  end;
  if CrLfOnly then
  begin
    { E: after its last character; the last line break goes }
    if (E - P >= 2) and (Dfm[E - 2] = #13) and (Dfm[E - 1] = #10) then Dec(E, 2);
    Rest := Copy(Dfm, P, E - P);
  end
  else
    while ReadLine(P, Line) do
    begin
      if Rest <> '' then Rest := Rest + #13#10;
      Rest := Rest + Line;
    end;
end;

function JoinDfmRoot(const Header: string; Texts: TStrings; const Rest: string): string;
var
  I: Integer;
begin
  Result := Header + #13#10;
  for I := 0 to Texts.Count - 1 do Result := Result + Texts[I] + #13#10;
  Result := Result + Rest + #13#10;
end;

{ Dfm with "Position = poDesigned" among the properties of its root when it has no Position line.
  Delphi 7's TForm has poDesigned as the default of Position and its writer leaves the property
  out; RAD Studio's VCL (Delphi 2010 and later: dcc64, Win64) creates a form as poDefaultPosOnly,
  so such a form opens where Windows places it, not at its Left and Top. Delphi 7 reads the line
  as its default. It goes where the writer puts the property: after the root's published
  properties that come before Position, before the later ones (the events) and the defined ones
  (PixelsPerInch, TextHeight - PixelsPerInch is published, but not stored). }
function WithDesignedPosition(const Dfm: string; Root: TPersistent): string;
var
  Names, Texts: TStringList;
  Header, Rest, Base: string;
  Count, PosIndex, At, I, J, P: Integer;
  List: PPropList;

  function PropIndex(const AName: string): Integer;
  begin
    Result := Count - 1;
    while (Result >= 0) and ((List^[Result] = nil) or not SameText(List^[Result]^.Name, AName)) do
      Dec(Result);
  end;

begin
  Result := Dfm;
  Count := GetTypeData(Root.ClassInfo)^.PropCount;
  if Count = 0 then Exit;
  Names := TStringList.Create;
  Texts := TStringList.Create;
  GetMem(List, Count * SizeOf(Pointer));
  try
    SplitDfmRoot(Dfm, Header, Names, Texts, Rest);
    if (Header = '') or (Names.IndexOf('Position') >= 0) then Exit;
    GetPropInfos(Root.ClassInfo, List);
    PosIndex := PropIndex('Position');
    if PosIndex < 0 then Exit;
    At := Names.Count;
    for I := 0 to Names.Count - 1 do
    begin
      Base := Names[I];
      P := Pos('.', Base);
      if P > 0 then Base := Copy(Base, 1, P - 1);
      J := PropIndex(Base);
      if (J < 0) or (J > PosIndex) or not IsStoredProp(Root, List^[J]) then
      begin
        At := I;
        Break;
      end;
    end;
    Texts.Insert(At, '  Position = poDesigned');
    Result := JoinDfmRoot(Header, Texts, Rest);
  finally
    FreeMem(List);
    Texts.Free;
    Names.Free;
  end;
end;

{ ---------------------------------------------------------------- TDesignEnvironment }

constructor TDesignEnvironment.Create;
begin
  inherited Create;
  GridX := 8;
  GridY := 8;
  ShowGrid := True;
  SnapToGrid := True;
  SnapLines := True;
  SnapDistance := DefSnapDistance;
  SnapSpacing := DefSnapSpacing;
  SnapMargin := DefSnapMargin;
  ShowCaptions := True;
  ShowPositioner := True;
  PositionerSnap := True;
end;

{ ---------------------------------------------------------------- TSdDesignForm }

procedure TSdDesignForm.DesignShow;
begin
  HandleNeeded;
  UpdateControlState;
  if HandleAllocated then ShowWindow(Handle, SW_SHOWNA);
end;

{ --- design-time menu bar ---------------------------------------------------------------

  The form being designed is a child window and cannot own a real menu. The bar of its
  TMainMenu is therefore a strip of the non-client area between caption and client area: the
  client area shrinks exactly as it does at run time, and a click on a title selects that
  menu item (its sub-items are edited through the Structure pane). }

function TSdDesignForm.BarWanted: Boolean;
var
  I: Integer;
begin
  Result := False;
  if (Menu = nil) or (FDsg = nil) or (FDsg.HostKind <> hkForm) then Exit;
  for I := 0 to Menu.Items.Count - 1 do
    if Menu.Items[I].Visible then
    begin
      Result := True;
      Exit;
    end;
end;

procedure TSdDesignForm.WMNCCalcSize(var Message: TWMNCCalcSize);
begin
  inherited;
  FBarHeight := 0;
  if BarWanted then
  begin
    FBarHeight := GetSystemMetrics(SM_CYMENU);
    { the first rectangle is the proposed window/client rectangle in both forms of the message }
    Inc(Message.CalcSize_Params^.rgrc[0].Top, FBarHeight);
  end;
end;

function TSdDesignForm.ClientInWindow: TPoint;
var
  WR: TRect;
begin
  GetWindowRect(Handle, WR);
  Result := Point(0, 0);
  Windows.ClientToScreen(Handle, Result);
  Dec(Result.X, WR.Left);
  Dec(Result.Y, WR.Top);
end;

const
  STATE_SYSTEM_INVISIBLE = $00008000;   // oleacc.h: a scroll bar that is not shown

{ the client area together with the scroll bars shown beside it and the box between them, in
  window coordinates: what the frame goes around, as on a top-level window }
function TSdDesignForm.FramedRect: TRect;
const
  Bars: array[0..1] of Longint = (Longint(OBJID_HSCROLL), Longint(OBJID_VSCROLL));
var
  WR, R, T: TRect;
  P: TPoint;
  SI: TScrollBarInfo;
  I: Integer;
begin
  GetWindowRect(Handle, WR);
  P := ClientInWindow;
  Result := Bounds(P.X, P.Y, ClientWidth, ClientHeight);
  for I := Low(Bars) to High(Bars) do
  begin
    FillChar(SI, SizeOf(SI), 0);
    SI.cbSize := SizeOf(SI);
    if GetScrollBarInfo(Handle, Bars[I], SI) and (SI.rgstate[0] and STATE_SYSTEM_INVISIBLE = 0) then
    begin
      R := SI.rcScrollBar;
      OffsetRect(R, -WR.Left, -WR.Top);
      T := Result;
      UnionRect(Result, T, R);
    end;
  end;
end;

{ the scroll bars and the box between them as a region in screen coordinates, the form of
  WM_NCPAINT's region, limited to Clip (WM_NCPAINT's; 1 = the whole frame); 0 = no scroll bar.
  The caller deletes it. }
function TSdDesignForm.ScrollBarRgn(Clip: HRGN): HRGN;
var
  WR, Outer, Inner: TRect;
  P: TPoint;
  R: HRGN;
begin
  Result := 0;
  Outer := FramedRect;
  P := ClientInWindow;
  Inner := Bounds(P.X, P.Y, ClientWidth, ClientHeight);
  if EqualRect(Outer, Inner) then Exit;
  GetWindowRect(Handle, WR);
  OffsetRect(Outer, WR.Left, WR.Top);
  OffsetRect(Inner, WR.Left, WR.Top);
  Result := CreateRectRgnIndirect(Outer);
  R := CreateRectRgnIndirect(Inner);
  CombineRgn(Result, Result, R, RGN_DIFF);
  DeleteObject(R);
  if Clip > 1 then CombineRgn(Result, Result, Clip, RGN_AND);
end;

{ the menu bar spans the client area and its vertical scroll bar, as on a top-level window }
function TSdDesignForm.BarRect: TRect;
var
  R: TRect;
begin
  R := FramedRect;
  Result := Rect(R.Left, R.Top - FBarHeight, R.Right, R.Top);
end;

function MenuBarFont: HFONT;
var
  LF: TLogFont;
begin
  if UINonClientFont(ncMenu, LF) then Result := CreateFontIndirect(LF) else Result := 0;
end;

{ PrintDC (a WM_PRINT's), else the window's DC; ReleaseFrameDC gives back the window's }
function TSdDesignForm.FrameDC(PrintDC: HDC): HDC;
begin
  if PrintDC <> 0 then Result := PrintDC else Result := GetWindowDC(Handle);
end;

procedure TSdDesignForm.ReleaseFrameDC(DC, PrintDC: HDC);
begin
  if PrintDC = 0 then ReleaseDC(Handle, DC);
end;

{ FrameDC with the menu font selected; ReleaseBarDC gives both back }
function TSdDesignForm.GetBarDC(PrintDC: HDC; out Font, OldFont: HFONT): HDC;
begin
  Result := FrameDC(PrintDC);
  Font := MenuBarFont;
  OldFont := 0;
  if Font <> 0 then OldFont := SelectObject(Result, Font);
end;

procedure TSdDesignForm.ReleaseBarDC(DC, PrintDC: HDC; Font, OldFont: HFONT);
begin
  if OldFont <> 0 then SelectObject(DC, OldFont);
  if Font <> 0 then DeleteObject(Font);
  ReleaseFrameDC(DC, PrintDC);
end;

{ the titles side by side from the bar's left end, each its caption in the menu font (DC) + 14 -
  what is painted and what a click hits }
function TSdDesignForm.BarItemRects(DC: HDC; const Bar: TRect): TMenuBarRects;
var
  I, X: Integer;
  S: string;
  R: TRect;
begin
  SetLength(Result, Menu.Items.Count);
  X := Bar.Left;
  for I := 0 to Menu.Items.Count - 1 do
  begin
    Result[I] := Rect(0, 0, 0, 0);
    if not Menu.Items[I].Visible then Continue;
    S := Menu.Items[I].Caption;
    R := Rect(0, 0, 0, 0);
    DrawText(DC, PChar(S), Length(S), R, DT_SINGLELINE or DT_CALCRECT);
    Result[I] := Rect(X, Bar.Top, X + R.Right + 14, Bar.Bottom - 1);
    X := Result[I].Right;
  end;
end;

procedure TSdDesignForm.PaintBar(PrintDC: HDC);
var
  DC: HDC;
  Bar, R: TRect;
  Rects: TMenuBarRects;
  Font, OldFont: HFONT;
  I: Integer;
  S: string;
  Sel: Boolean;
  D: TThemedElementDetails;
begin
  if (FBarHeight = 0) or not HandleAllocated or (Menu = nil) then Exit;
  DC := GetBarDC(PrintDC, Font, OldFont);
  try
    Bar := BarRect;
    { the menu bar of the visual style (white on Windows 10/11, not COLOR_MENUBAR): a part of
      Windows Vista's MENU class, which Delphi 7's element list does not name - by number,
      through the VCL's theme of the class }
    if ThemeServices.ThemesEnabled then
    begin
      D.Element := teMenu;
      D.Part := 7;                  // MENU_BARBACKGROUND
      D.State := 1;                 // MB_ACTIVE
      ThemeServices.DrawElement(DC, D, Bar);
    end
    else
      FillRect(DC, Bar, GetSysColorBrush(COLOR_MENUBAR));
    SetBkMode(DC, TRANSPARENT);
    Rects := BarItemRects(DC, Bar);
    for I := 0 to High(Rects) do
    begin
      R := Rects[I];
      if IsRectEmpty(R) then Continue;
      if R.Left >= Bar.Right then Break;
      S := Menu.Items[I].Caption;
      Sel := (FDsg <> nil) and FDsg.IsSelected(Menu.Items[I]);
      SetTextColor(DC, GetSysColor(COLOR_MENUTEXT));
      if Sel then
      begin
        FillRect(DC, R, GetSysColorBrush(COLOR_MENUHILIGHT));
        FrameRect(DC, R, GetSysColorBrush(COLOR_HIGHLIGHT));
        SetTextColor(DC, GetSysColor(COLOR_HIGHLIGHTTEXT));
      end;
      if not Menu.Items[I].Enabled then SetTextColor(DC, GetSysColor(COLOR_GRAYTEXT));
      DrawText(DC, PChar(S), Length(S), R, DT_SINGLELINE or DT_CENTER or DT_VCENTER);
    end;
  finally
    ReleaseBarDC(DC, PrintDC, Font, OldFont);
  end;
end;

{ --- the frame of a real window ----------------------------------------------------------

  With visual styles the form is framed like a top-level window of this system (SdOsFrame)
  instead of the "basic" frame Windows gives a child window. The designer paints the whole
  non-client area and keeps the default window procedure from painting any of it: no default
  WM_NCPAINT / WM_NCACTIVATE, the caption buttons hit-test as caption (no hot tracking), and
  WM_SETTEXT / WM_SETICON run while the window pretends to be invisible. The scroll bars of a
  form are part of its non-client area: the frame goes around them, and the default WM_NCPAINT
  paints them alone, inside a region of only them (ScrollBarRgn) - it does not paint outside
  the region it is given. }

{ the colour of what lies behind the form: its parent's, else the designer's (its surface's) }
function TSdDesignForm.StageColor: TColor;
begin
  if Parent <> nil then Result := TControlCracker(Parent).Color
  else if FDsg <> nil then Result := FDsg.FSurface.Color
  else Result := Color;
end;

{ No caption (not OsFrameWanted: bsNone, a data module, a custom module, a frame): no title bar -
  the invisible sizing border in the colour of what lies behind the form, and the 1 px border
  line of a framed form around the client area and the menu bar, in its colours, so that the
  module's edges show on the stage }
procedure TSdDesignForm.PaintNoFrame(PrintDC: HDC);
var
  DC: HDC;
  WR, Inner, Line: TRect;
  Br: HBRUSH;
  Saved: Integer;
begin
  GetWindowRect(Handle, WR);
  Inner := FramedRect;
  DC := FrameDC(PrintDC);
  Saved := SaveDC(DC);
  try
    ExcludeClipRect(DC, Inner.Left, Inner.Top, Inner.Right, Inner.Bottom);
    Br := CreateSolidBrush(ColorToRGB(StageColor));
    FillRect(DC, Rect(0, 0, WR.Right - WR.Left, WR.Bottom - WR.Top), Br);
    DeleteObject(Br);
    Line := Rect(Inner.Left - 1, Inner.Top - FBarHeight - 1, Inner.Right + 1, Inner.Bottom + 1);
    Br := CreateSolidBrush(ColorToRGB(OsFrameBorderColor(FFrameActive)));
    Windows.FrameRect(DC, Line, Br);
    DeleteObject(Br);
  finally
    RestoreDC(DC, Saved);
    ReleaseFrameDC(DC, PrintDC);
  end;
end;

function TSdDesignForm.OsFrameWanted: Boolean;
var
  Style: Longint;
begin
  Result := False;
  if not HandleAllocated then Exit;
  Style := GetWindowLong(Handle, GWL_STYLE);
  Result := Style and WS_CAPTION = WS_CAPTION;
end;

procedure TSdDesignForm.PaintOsFrame(PrintDC: HDC);
var
  F: TOsFrame;
  WR, Skip: TRect;
  P: TPoint;
  DC: HDC;
  Style, Ex: Longint;
  Saved: Integer;
begin
  if not OsFrameWanted then Exit;
  GetWindowRect(Handle, WR);
  P := ClientInWindow;
  FillChar(F, SizeOf(F), 0);
  F.Width := WR.Right - WR.Left;
  F.Height := WR.Bottom - WR.Top;
  F.Client := FramedRect;
  F.TitleBottom := P.Y - FBarHeight;
  F.Caption := Caption;
  Style := GetWindowLong(Handle, GWL_STYLE);
  Ex := GetWindowLong(Handle, GWL_EXSTYLE);
  F.SysMenu := Style and WS_SYSMENU <> 0;
  F.MinBox := Style and WS_MINIMIZEBOX <> 0;
  F.MaxBox := Style and WS_MAXIMIZEBOX <> 0;
  F.SmallCaption := Ex and WS_EX_TOOLWINDOW <> 0;
  if F.SysMenu and (Ex and WS_EX_DLGMODALFRAME = 0) then
  begin
    { the small icon Windows shows in a caption: the form sets only its big icon, and Windows
      makes the small one from it - the icon's own 16 x 16 image when the icon comes from a
      resource. Drawing the big icon at 16 x 16 shrinks its 32 x 32 image instead. }
    F.Icon := HICON(SendMessage(Handle, WM_GETICON, ICON_SMALL2, 0));
    if F.Icon = 0 then F.Icon := HICON(GetClassLong(Handle, GCL_HICONSM));
    if F.Icon = 0 then F.Icon := Application.Icon.Handle;
  end;
  F.Active := FFrameActive;
  F.Back := StageColor;
  if FBarHeight > 0 then Skip := BarRect else Skip := Rect(0, 0, 0, 0);
  DC := FrameDC(PrintDC);
  Saved := SaveDC(DC);
  try
    DrawOsFrame(DC, F, Skip);
  finally
    RestoreDC(DC, Saved);
    ReleaseFrameDC(DC, PrintDC);
  end;
end;

{ A resize of the form being designed repaints what it uncovers, not the whole form and every
  control on it (CS_HREDRAW / CS_VREDRAW did: the grid and the controls flickered while the
  form was sized). Nothing of it reaches the .dfm. }
procedure TSdDesignForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  with Params.WindowClass do style := style and not (CS_HREDRAW or CS_VREDRAW);
  DesignStyle(Params.Style, Params.ExStyle);
end;

{ The frame the form will have in the running program, shown in the designer, so that BorderStyle
  and BorderIcons show at once (Delphi 7 itself always shows the sizeable frame with all three
  buttons at design time): the
  caption buttons and the icon of BorderIcons, a tool window's small caption with only the
  close button, a dialog's frame without icon, no frame for bsNone - as TCustomForm.CreateParams
  makes them. The sizing border stays: invisible as on a real window, it still sizes the form
  in the designer. }
procedure TSdDesignForm.DesignStyle(var Style, ExStyle: DWORD);
var
  Icons: TBorderIcons;
  B: TFormBorderStyle;
begin
  Style := Style and not (WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX or WS_MAXIMIZEBOX) or WS_THICKFRAME;
  ExStyle := ExStyle and not (WS_EX_DLGMODALFRAME or WS_EX_TOOLWINDOW or WS_EX_CONTEXTHELP);
  Icons := BorderIcons;
  B := BorderStyle;
  { a data module and a frame have no window of their own: no title bar either }
  if (FDsg <> nil) and (FDsg.HostKind <> hkForm) then B := bsNone;
  case B of
    bsNone: Icons := [];
    bsDialog:
      begin
        ExStyle := ExStyle or WS_EX_DLGMODALFRAME;
        Icons := Icons * [biSystemMenu, biHelp];
      end;
    bsToolWindow, bsSizeToolWin:
      begin
        ExStyle := ExStyle or WS_EX_TOOLWINDOW;
        Icons := Icons * [biSystemMenu];
      end;
  end;
  if B <> bsNone then Style := Style or WS_CAPTION;
  if B in [bsSingle, bsSizeable] then
  begin
    if biMinimize in Icons then Style := Style or WS_MINIMIZEBOX;
    if biMaximize in Icons then Style := Style or WS_MAXIMIZEBOX;
  end;
  if biSystemMenu in Icons then Style := Style or WS_SYSMENU;
  if biHelp in Icons then ExStyle := ExStyle or WS_EX_CONTEXTHELP;
end;

{ BorderStyle and BorderIcons changed in the Object Inspector: the VCL makes the window again
  only at run time, the designer changes its style in place. The client area keeps its size
  (it is what the .dfm stores), the window follows the new frame. }
procedure TSdDesignForm.UpdateBorder;
var
  S, E, S0, E0: DWORD;
  CW, CH: Integer;
  Ico: HICON;
begin
  if not HandleAllocated then Exit;
  S0 := DWORD(GetWindowLong(Handle, GWL_STYLE));
  E0 := DWORD(GetWindowLong(Handle, GWL_EXSTYLE));
  S := S0;
  E := E0;
  DesignStyle(S, E);
  if (S = S0) and (E = E0) then Exit;
  CW := ClientWidth;
  CH := ClientHeight;
  SetWindowLong(Handle, GWL_STYLE, Longint(S));
  SetWindowLong(Handle, GWL_EXSTYLE, Longint(E));
  SetWindowPos(Handle, 0, 0, 0, 0, 0, SWP_FRAMECHANGED or SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE);
  if (ClientWidth <> CW) or (ClientHeight <> CH) then
  begin
    ClientWidth := CW;
    ClientHeight := CH;
  end;
  { a dialog shows no icon (TCustomForm.CreateWnd) }
  if BorderStyle = bsDialog then Ico := 0
  else if Icon.Handle <> 0 then Ico := Icon.Handle
  else Ico := Application.Icon.Handle;
  SendMessage(Handle, WM_SETICON, 1, Ico);
  RedrawWindow(Handle, nil, 0, RDW_FRAME or RDW_INVALIDATE or RDW_ERASE or RDW_ALLCHILDREN);
end;

procedure TSdDesignForm.WndProc(var Message: TMessage);
var
  Style: Longint;
begin
  if OsFrameWanted then
    case Message.Msg of
      $00AE, $00AF:
        begin
          { WM_NCUAHDRAWCAPTION / WM_NCUAHDRAWFRAME: the visual style painting the caption }
          Message.Result := 0;
          Exit;
        end;
      WM_SETTEXT, WM_SETICON:
        begin
          Style := GetWindowLong(Handle, GWL_STYLE);
          SetWindowLong(Handle, GWL_STYLE, Style and not WS_VISIBLE);
          try
            inherited WndProc(Message);
          finally
            SetWindowLong(Handle, GWL_STYLE, Style);
          end;
          PaintOsFrame;
          Exit;
        end;
    end;
  inherited WndProc(Message);
end;

{ the whole frame is the designer's: a top-level window's with a caption, else the ground behind
  the form }
procedure TSdDesignForm.PaintFrame(PrintDC: HDC);
begin
  if OsFrameWanted then PaintOsFrame(PrintDC) else PaintNoFrame(PrintDC);
  PaintBar(PrintDC);
end;

procedure TSdDesignForm.WMNCPaint(var Message: TMessage);
var
  Bars: HRGN;
begin
  PaintFrame;
  { the scroll bars: the default window procedure itself (TWinControl.WMNCPaint would paint
    BorderWidth's frame over the designer's first), the region is the caller's to delete }
  Bars := ScrollBarRgn(HRGN(Message.WParam));
  if Bars <> 0 then
  begin
    CallWindowProc(DefWndProc, Handle, WM_NCPAINT, WPARAM(Bars), 0);
    DeleteObject(Bars);
  end;
  Message.Result := 0;
end;

{ the form painted into a WM_PRINT's DC (the zoomed design view's picture): the default window
  procedure paints a frame of its own, the scroll bars, the client and the controls; the
  designer's frame and menu bar then go over its frame }
procedure TSdDesignForm.WMPrint(var Message: TMessage);
begin
  inherited;
  if Message.LParam and PRF_NONCLIENT <> 0 then PaintFrame(HDC(Message.WParam));
end;

procedure TSdDesignForm.WMNCActivate(var Message: TMessage);
begin
  FFrameActive := Message.WParam <> 0;
  Message.Result := 1;
  PaintFrame;
end;

function TSdDesignForm.BarItemAt(const ScreenPt: TPoint): TMenuItem;
var
  DC: HDC;
  Font, OldFont: HFONT;
  WR, Bar: TRect;
  Rects: TMenuBarRects;
  P: TPoint;
  I: Integer;
begin
  Result := nil;
  if (FBarHeight = 0) or (Menu = nil) then Exit;
  GetWindowRect(Handle, WR);
  P := Point(ScreenPt.X - WR.Left, ScreenPt.Y - WR.Top);
  Bar := BarRect;
  if not PtInRect(Bar, P) then Exit;
  DC := GetBarDC(0, Font, OldFont);
  try
    Rects := BarItemRects(DC, Bar);
  finally
    ReleaseBarDC(DC, 0, Font, OldFont);
  end;
  for I := 0 to High(Rects) do
    if PtInRect(Rects[I], P) then
    begin
      Result := Menu.Items[I];
      Exit;
    end;
end;

procedure TSdDesignForm.WMNCHitTest(var Message: TWMNCHitTest);
var
  WR: TRect;
begin
  { the visual style hit-tests the frame against the screen place the window had at its last
    frame calculation. The form moves on the screen without a move of its own when the designer
    around it does (the file tabs shown, a dock area opened or closed): its sizing edges and
    client area then stayed at the old place, and the mouse found nothing where they are. A new
    frame calculation comes first when the form is somewhere else than at the last hit test. }
  GetWindowRect(Handle, WR);
  if (WR.Left <> FHitOrigin.X) or (WR.Top <> FHitOrigin.Y) then
  begin
    FHitOrigin := WR.TopLeft;
    SetWindowPos(Handle, 0, 0, 0, 0, 0, SWP_FRAMECHANGED or SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or
      SWP_NOACTIVATE);
  end;
  inherited;
  if FBarHeight > 0 then
  begin
    if PtInRect(BarRect, Point(Message.XPos - WR.Left, Message.YPos - WR.Top)) then
      Message.Result := HTMENU;
  end;
  { the caption buttons are painted by the designer and do nothing at design time: without
    a button under the mouse the default window procedure has nothing to track and redraw }
  if OsFrameWanted then
    case Message.Result of
      HTCLOSE, HTMINBUTTON, HTMAXBUTTON, HTSYSMENU, HTHELP: Message.Result := HTCAPTION;
    end;
  { the form sits at the stage's origin: its right and bottom edges size it (the designer does,
    TFormDesigner.BeginFormSize), the left and top ones do not - their corners size it as the
    right or the bottom edge }
  case Message.Result of
    HTLEFT, HTTOP, HTTOPLEFT: Message.Result := HTBORDER;
    HTTOPRIGHT: Message.Result := HTRIGHT;
    HTBOTTOMLEFT: Message.Result := HTBOTTOM;
  end;
end;

procedure TSdDesignForm.UpdateMenuBar;
var
  Want: Integer;
begin
  if not HandleAllocated then Exit;
  if BarWanted then Want := GetSystemMetrics(SM_CYMENU) else Want := 0;
  if Want <> FBarHeight then
    SetWindowPos(Handle, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE or
      SWP_FRAMECHANGED)
  else
    PaintBar;
end;

{ ---------------------------------------------------------------- TRawWnd }

function RawWndProc(Wnd: HWND; Msg: UINT; W: WPARAM; L: LPARAM): LRESULT; stdcall;
var
  Obj: TRawWnd;
  M: TMessage;
begin
  if Msg = WM_NCCREATE then
    SetWindowLong(Wnd, GWL_USERDATA, Longint(PCreateStruct(L)^.lpCreateParams));
  Obj := TRawWnd(GetWindowLong(Wnd, GWL_USERDATA));
  if Obj <> nil then
  begin
    { CreateWindowEx has not returned yet while the first messages arrive }
    if Obj.FHandle = 0 then Obj.FHandle := Wnd;
    M.Msg := Msg;
    M.WParam := W;
    M.LParam := L;
    M.Result := 0;
    try
      Obj.WndProc(M);
    except
      Application.HandleException(Obj);
    end;
    Result := M.Result;
    if Msg = WM_NCDESTROY then
    begin
      SetWindowLong(Wnd, GWL_USERDATA, 0);
      Obj.FHandle := 0;
    end;
  end
  else
    Result := DefWindowProc(Wnd, Msg, W, L);
end;

constructor TRawWnd.Create(AParent: HWND);
var
  WC: TWndClass;
begin
  inherited Create;
  if RawClassAtom = 0 then
  begin
    FillChar(WC, SizeOf(WC), 0);
    WC.style := CS_DBLCLKS;
    WC.lpfnWndProc := @RawWndProc;
    WC.hInstance := HInstance;
    WC.hCursor := LoadCursor(0, IDC_ARROW);
    WC.lpszClassName := RawClassName;
    RawClassAtom := Windows.RegisterClass(WC);
  end;
  FHandle := CreateWindowEx(0, RawClassName, nil, WS_CHILD or WS_CLIPSIBLINGS, 0, 0, 0, 0,
    AParent, 0, HInstance, Self);
end;

destructor TRawWnd.Destroy;
begin
  if (FHandle <> 0) and IsWindow(FHandle) then
  begin
    SetWindowLong(FHandle, GWL_USERDATA, 0);
    DestroyWindow(FHandle);
  end;
  FHandle := 0;
  inherited;
end;

{ WM_PAINT draws on a bitmap first and copies it to the screen in one piece: a tile drawn on the
  screen showed its bare ground before its picture each time it painted (it flickered) }
procedure TRawWnd.WndProc(var Msg: TMessage);
var
  PS: TPaintStruct;
  DC, MemDC: HDC;
  R: TRect;
  Bmp, OldBmp: HBITMAP;
begin
  case Msg.Msg of
    WM_PAINT:
      begin
        DC := BeginPaint(FHandle, PS);
        try
          Windows.GetClientRect(FHandle, R);
          if (R.Right > 0) and (R.Bottom > 0) then
          begin
            MemDC := CreateCompatibleDC(DC);
            Bmp := CreateCompatibleBitmap(DC, R.Right, R.Bottom);
            OldBmp := SelectObject(MemDC, Bmp);
            try
              Paint(MemDC);
              BitBlt(DC, 0, 0, R.Right, R.Bottom, MemDC, 0, 0, SRCCOPY);
            finally
              SelectObject(MemDC, OldBmp);
              DeleteObject(Bmp);
              DeleteDC(MemDC);
            end;
          end;
        finally
          EndPaint(FHandle, PS);
        end;
      end;
    WM_ERASEBKGND:
      Msg.Result := 1;
    WM_PRINTCLIENT:
      Paint(HDC(Msg.WParam));          // into a WM_PRINT's DC (the zoomed design view's picture)
  else
    Msg.Result := DefWindowProc(FHandle, Msg.Msg, Msg.WParam, Msg.LParam);
  end;
end;

procedure TRawWnd.Paint(DC: HDC);
begin
end;

{ a window where it is already is left alone: SetWindowPos goes through the window manager even
  then, and the designer places every helper at each update }
procedure TRawWnd.SetBounds(X, Y, W, H: Integer);
var
  R: TRect;
begin
  if FHandle = 0 then Exit;
  GetWindowRect(FHandle, R);
  MapWindowPoints(0, GetParent(FHandle), R, 2);
  if (R.Left <> X) or (R.Top <> Y) or (R.Right - R.Left <> W) or (R.Bottom - R.Top <> H) then
    SetWindowPos(FHandle, 0, X, Y, W, H, SWP_NOZORDER or SWP_NOACTIVATE);
end;

{ A hidden window is shown on top of the z-order. A shown one keeps its place: raised at each
  update, the tiles and the names, which overlap, changed their order every time, and each
  painted again what it had had under the others - the tiles flickered at every click and at
  every step of a drag. }
procedure TRawWnd.SetVisible(Value: Boolean);
begin
  if (FHandle = 0) or (Value = (GetWindowLong(FHandle, GWL_STYLE) and WS_VISIBLE <> 0)) then Exit;
  if Value then
    SetWindowPos(FHandle, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE or SWP_SHOWWINDOW)
  else
    ShowWindow(FHandle, SW_HIDE);
end;

procedure TRawWnd.ToTop;
begin
  if FHandle <> 0 then
    SetWindowPos(FHandle, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
end;

procedure TRawWnd.Invalidate;
begin
  if FHandle <> 0 then InvalidateRect(FHandle, nil, False);
end;

{ ---------------------------------------------------------------- TLineWnd / TFrameRect }

procedure TLineWnd.Paint(DC: HDC);
var
  R: TRect;
begin
  GetClientRect(FHandle, R);
  UIFill(DC, R, clBtnShadow);
end;

procedure TLineWnd.WndProc(var Msg: TMessage);
begin
  if Msg.Msg = WM_NCHITTEST then
    Msg.Result := HTTRANSPARENT
  else
    inherited WndProc(Msg);
end;

procedure TSnapLineWnd.Paint(DC: HDC);
var
  R: TRect;
begin
  GetClientRect(FHandle, R);
  UIFill(DC, R, clHighlight);
end;

constructor TFrameRect.Create(AParent: HWND);
var
  I: Integer;
begin
  inherited Create;
  for I := 0 to 3 do FLines[I] := TLineWnd.Create(AParent);
end;

destructor TFrameRect.Destroy;
var
  I: Integer;
begin
  for I := 0 to 3 do FLines[I].Free;
  inherited;
end;

procedure TFrameRect.SetRect(const R: TRect);
var
  W, H, I: Integer;
begin
  W := R.Right - R.Left;
  H := R.Bottom - R.Top;
  if W < 1 then W := 1;
  if H < 1 then H := 1;
  FLines[0].SetBounds(R.Left, R.Top, W, 1);
  FLines[1].SetBounds(R.Left, R.Top + H - 1, W, 1);
  FLines[2].SetBounds(R.Left, R.Top, 1, H);
  FLines[3].SetBounds(R.Left + W - 1, R.Top, 1, H);
  if not FVisible then
  begin
    for I := 0 to 3 do FLines[I].SetVisible(True);
    FVisible := True;
  end
  else
    for I := 0 to 3 do FLines[I].ToTop;
end;

procedure TFrameRect.Hide;
var
  I: Integer;
begin
  if FVisible then
  begin
    for I := 0 to 3 do FLines[I].SetVisible(False);
    FVisible := False;
  end;
end;

{ ---------------------------------------------------------------- TGrabHandle }

procedure TGrabHandle.Paint(DC: HDC);
var
  R: TRect;
begin
  GetClientRect(FHandle, R);
  if FActive then UIFill(DC, R, clBtnText) else UIFill(DC, R, clBtnShadow);
end;

procedure TGrabHandle.WndProc(var Msg: TMessage);
const
  Cursors: array[0..7] of PChar = (IDC_SIZENWSE, IDC_SIZENS, IDC_SIZENESW, IDC_SIZEWE,
    IDC_SIZENWSE, IDC_SIZENS, IDC_SIZENESW, IDC_SIZEWE);
var
  P: TPoint;
begin
  case Msg.Msg of
    WM_SETCURSOR:
      begin
        if FActive and not FDesigner.FLocked then
          SetCursor(LoadCursor(0, Cursors[FKind]))
        else
          SetCursor(LoadCursor(0, IDC_ARROW));
        Msg.Result := 1;
      end;
    WM_LBUTTONDOWN, WM_MOUSEMOVE, WM_LBUTTONUP:
      begin
        if Msg.Msg = WM_LBUTTONDOWN then FDesigner.PressAt(FHandle);
        { the position of the message, not of the cursor "now" }
        P := FDesigner.MessagePoint(FHandle, Smallint(LoWord(Msg.LParam)), Smallint(HiWord(Msg.LParam)));
        FDesigner.HandleDrag(Self, Msg.Msg, P);
      end;
  else
    inherited WndProc(Msg);
  end;
end;

{ ---------------------------------------------------------------- TCompIcon }

destructor TCompIcon.Destroy;
begin
  FreeAndNil(FCaption);
  inherited;
end;

procedure TCompIcon.Paint(DC: HDC);
var
  R: TRect;
begin
  GetClientRect(FHandle, R);
  UIDrawComponentTile(DC, R, DesignHost.ComponentBitmap(FComponent.ClassType));
end;

procedure TCompCaption.Paint(DC: HDC);
var
  R: TRect;
  Old: HFONT;
  Back: TColor;
begin
  GetClientRect(FHandle, R);
  Back := clBtnFace;
  if (FDesigner <> nil) and (FDesigner.FForm <> nil) then Back := FDesigner.FForm.Color;
  UIFill(DC, R, Back);
  Old := SelectObject(DC, UIFont.Handle);
  SetBkMode(DC, TRANSPARENT);
  SetTextColor(DC, ColorToRGB(clWindowText));
  TextOut(DC, 0, 0, PChar(FText), Length(FText));
  SelectObject(DC, Old);
end;

{ The mouse on the tile or on its caption (window Wnd) works on the tile; False: not a message
  of the tile }
function TileMessage(Icon: TCompIcon; Wnd: HWND; var Msg: TMessage): Boolean;
var
  P: TPoint;
begin
  Result := True;
  case Msg.Msg of
    WM_LBUTTONDOWN, WM_LBUTTONDBLCLK, WM_MOUSEMOVE, WM_LBUTTONUP, WM_RBUTTONDOWN, WM_RBUTTONUP:
      if (Icon <> nil) and (Icon.FDesigner <> nil) then
      begin
        if Msg.Msg = WM_LBUTTONDOWN then Icon.FDesigner.PressAt(Wnd);
        P := Icon.FDesigner.MessagePoint(Wnd, Smallint(LoWord(Msg.LParam)), Smallint(HiWord(Msg.LParam)));
        Icon.FDesigner.IconMouse(Icon, Msg.Msg, P, KeysToShiftState(Msg.WParam));
      end;
    WM_SETCURSOR:
      begin
        SetCursor(LoadCursor(0, IDC_ARROW));
        Msg.Result := 1;
      end;
  else
    Result := False;
  end;
end;

procedure TCompCaption.WndProc(var Msg: TMessage);
begin
  if not TileMessage(FIcon, FHandle, Msg) then inherited WndProc(Msg);
end;

procedure TCompIcon.WndProc(var Msg: TMessage);
begin
  if not TileMessage(Self, FHandle, Msg) then inherited WndProc(Msg);
end;

{ ---------------------------------------------------------------- TDesignStage / TDesignSurface }

procedure TDesignStage.EraseGround(DC: HDC);
var
  R: TRect;
begin
  Windows.GetClientRect(Handle, R);
  UIFill(DC, R, TControlCracker(Parent).Color);   // the surface's: the designer's colour
end;

{ The stage's background must not be painted over the form it hosts (a child window): that
  made the designer flicker heavily while it was resized. Nor does a change of the stage's
  size (it follows the form while the form is sized) repaint the form and its controls: no
  CS_HREDRAW / CS_VREDRAW (TSdControl), only what the change uncovers is painted. }
procedure TDesignStage.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

procedure TDesignStage.CreateWnd;
begin
  inherited CreateWnd;
  if (FDesigner <> nil) and (FDesigner.FForm <> nil) and not FDesigner.FDestroying then
  begin
    FDesigner.FForm.ParentWindow := Handle;
    FDesigner.FForm.DesignShow;
    FDesigner.PostUpdateHelpers;
  end;
end;

procedure TDesignStage.DestroyWnd;
begin
  if (FDesigner <> nil) and (FDesigner.FForm <> nil) then
  begin
    FDesigner.ClearHelpers;
    FDesigner.FForm.ParentWindow := 0;
  end;
  inherited DestroyWnd;
end;

{ a click beside the form being designed clears the selection (the form is selected, as when
  its empty area is clicked) }
procedure TDesignStage.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if FDesigner = nil then Exit;
  FDesigner.FocusSurface;
  if Button = mbLeft then FDesigner.ClearSelection;
end;

{ the wheel over the stage, the surface or the zoomed picture of a form: the designer's (Wheel) }
procedure WheelToDesigner(D: TFormDesigner; var Message: TWMMouseWheel);
begin
  if D <> nil then D.Wheel(Message.Keys, Message.WheelDelta, Point(Message.XPos, Message.YPos));
  Message.Result := 1;
end;

{ the wheel beside the form scrolls the surface, as over the form (TFormDesigner.Wheel) }
procedure TDesignStage.WMMouseWheel(var Message: TWMMouseWheel);
begin
  WheelToDesigner(FDesigner, Message);
end;

constructor TDesignSurface.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBordered := True;
  TabStop := True;
  ParentColor := True;                 // the designer's colour is the ground it lies on (D7 Studio:
                                       // the centre's, through the page); the stage and the ground of
                                       // the designed form's frame take it (TSdDesignForm.StageColor)
  BorderStyle := bsNone;               // no classic sunken edge: the flat border of CreateParams
  HorzScrollBar.Tracking := True;
  VertScrollBar.Tracking := True;
  FStage := TDesignStage.Create(Self);
  FStage.Parent := Self;
  FStage.SetBounds(0, 0, 100, 100);
end;

{ a flat 1 px border, as the editor's - unless it lies inside a frame }
procedure TDesignSurface.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  if FBordered then Params.Style := Params.Style or WS_BORDER;
end;

procedure TDesignSurface.WMNCPaint(var Message: TWMNCPaint);
begin
  inherited;
  if FBordered then UIPaintFrameBorder(Handle);
end;

procedure TDesignSurface.WMMouseWheel(var Message: TWMMouseWheel);
begin
  WheelToDesigner(FDesigner, Message);
end;

procedure TDesignSurface.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_WANTARROWS or DLGC_WANTTAB or DLGC_WANTCHARS or DLGC_WANTALLKEYS;
end;

procedure TDesignSurface.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  if (FDesigner <> nil) and (FDesigner.FForm <> nil) and FDesigner.FForm.HandleAllocated then
  begin
    SendMessage(FDesigner.FForm.Handle, WM_NCACTIVATE, 1, 0);
    FDesigner.StageShown;              // the active caption in the zoomed view too
  end;
end;

procedure TDesignSurface.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  if (FDesigner <> nil) and (FDesigner.FForm <> nil) and FDesigner.FForm.HandleAllocated then
  begin
    SendMessage(FDesigner.FForm.Handle, WM_NCACTIVATE, 0, 0);
    FDesigner.StageShown;
  end;
end;

procedure TDesignSurface.CMUpdateHelpers(var Message: TMessage);
begin
  if FDesigner <> nil then
  begin
    FDesigner.FUpdatePosted := False;
    FDesigner.StageChanged;
    FDesigner.UpdateHelpers;
  end;
end;

procedure TDesignSurface.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if FDesigner <> nil then FDesigner.KeyDown(Key, Shift);
end;

procedure TDesignSurface.KeyPress(var Key: Char);
begin
  inherited KeyPress(Key);
  if (FDesigner <> nil) and (Key >= ' ') and Assigned(DesignEnv.OnFocusInspector) then
  begin
    DesignEnv.OnFocusInspector(Key, '');
    Key := #0;
  end;
end;

procedure TDesignSurface.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if CanFocus then SetFocus;
  if (Button = mbLeft) and (FDesigner <> nil) then FDesigner.ClearSelection;
end;

{ a new size, or scroll bars that come or go: the form positioner keeps to the corner }
procedure TDesignSurface.Resize;
begin
  inherited Resize;
  if FDesigner <> nil then FDesigner.PlacePositioner;
end;

{ ---------------------------------------------------------------- TDesignZoomView }

const
  ZoomMin = 5;                        // SdZoom's steps of 5 %; a fitted zoom may lie between them
  ZoomMax = 400;
  ZoomLine = 16;                      // a scroll bar's line, in the zoomed view's pixels
  { a mouse message's buttons: MK_LBUTTON, MK_RBUTTON, MK_MBUTTON, MK_XBUTTON1, MK_XBUTTON2 }
  AnyButton = MK_LBUTTON or MK_RBUTTON or MK_MBUTTON or $20 or $40;

{ X div Y rounded down (also below 0) }
function FloorDivide(X, Y: Integer): Integer;
begin
  Result := X div Y;
  if (X mod Y <> 0) and ((X < 0) <> (Y < 0)) then Dec(Result);
end;

constructor TDesignZoomView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle - [csAcceptsControls, csSetCaption] + [csOpaque, csDoubleClicks];
  TabStop := False;
  Buffered := True;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 1000;
  FTimer.OnTimer := TimerTick;
end;

destructor TDesignZoomView.Destroy;
begin
  FreePicture;
  inherited Destroy;
end;

{ scroll bars of its own; its windows class takes double clicks (passed on as the stage's window
  takes them) }
procedure TDesignZoomView.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_HSCROLL or WS_VSCROLL;
end;

function TDesignZoomView.Stage: TWinControl;
begin
  Result := FDesigner.FSurface.FStage;
end;

function TDesignZoomView.Zoom: Integer;
begin
  Result := FDesigner.FZoom;
end;

procedure TDesignZoomView.FreePicture;
begin
  if FPicDC <> 0 then DeleteDC(FPicDC);
  if FPicture <> 0 then DeleteObject(FPicture);
  FPicDC := 0;
  FPicture := 0;
  FPicW := 0;
  FPicH := 0;
end;

{ Wnd and the windows on it into DC, whose origin is Wnd's top left: Wnd itself through WM_PRINT
  (its frame, ground and client), then its shown children from the bottom of the z-order up, each
  inside its parent's client area. The default WM_PRINT paints the children from the top down: the
  form covered the tiles and grab handles that lie over it. }
procedure PrintWindowTree(Wnd: HWND; DC: HDC);
var
  C: HWND;
  WR, R: TRect;
  O, P: TPoint;
  Saved, Inner: Integer;

  { R (Wnd's window coordinates) as the meta region: a window's own painting may select another
    clip region (the default WM_PRINT's frame does) but never paints outside this one }
  procedure ClipTo(const R: TRect);
  begin
    IntersectClipRect(DC, R.Left, R.Top, R.Right, R.Bottom);
    SetMetaRgn(DC);
  end;

begin
  SendMessage(Wnd, WM_PRINT, WPARAM(DC), PRF_NONCLIENT or PRF_CLIENT or PRF_ERASEBKGND);
  GetWindowRect(Wnd, WR);
  { a client edge: WM_PRINT draws Windows' sunken 3D edge, the screen the visual style's border -
    the edit border over the outer 2 px, as the style paints it (TThemeServices.PaintBorder) }
  if ThemeServices.ThemesEnabled and (GetWindowLong(Wnd, GWL_EXSTYLE) and WS_EX_CLIENTEDGE <> 0) then
  begin
    R := Rect(0, 0, WR.Right - WR.Left, WR.Bottom - WR.Top);
    Saved := SaveDC(DC);
    try
      ExcludeClipRect(DC, R.Left + 2, R.Top + 2, R.Right - 2, R.Bottom - 2);
      ThemeServices.DrawElement(DC, ThemeServices.GetElementDetails(teEditTextNormal), R);
    finally
      RestoreDC(DC, Saved);
    end;
  end;
  C := GetWindow(Wnd, GW_CHILD);
  if C = 0 then Exit;
  Saved := SaveDC(DC);
  try
    { the client area, in Wnd's window coordinates }
    Windows.GetClientRect(Wnd, R);
    P := Point(0, 0);
    Windows.ClientToScreen(Wnd, P);
    OffsetRect(R, P.X - WR.Left, P.Y - WR.Top);
    ClipTo(R);
    GetViewportOrgEx(DC, O);
    C := GetWindow(C, GW_HWNDLAST);
    while C <> 0 do
    begin
      if GetWindowLong(C, GWL_STYLE) and WS_VISIBLE <> 0 then
      begin
        GetWindowRect(C, R);
        OffsetRect(R, -WR.Left, -WR.Top);
        Inner := SaveDC(DC);
        try
          ClipTo(R);
          SetViewportOrgEx(DC, O.X + R.Left, O.Y + R.Top, nil);
          PrintWindowTree(C, DC);
        finally
          RestoreDC(DC, Inner);
        end;
      end;
      C := GetWindow(C, GW_HWNDPREV);
    end;
  finally
    RestoreDC(DC, Saved);
  end;
end;

{ the stage into the picture: its windows paint themselves into it (PrintWindowTree) - the whole
  stage, also where it lies outside the main window or the screen (PrintWindow takes those parts
  from the screen's painting, which has none of them: black), and although the view covers it }
procedure TDesignZoomView.Render;
var
  W, H: Integer;
  Bits: PCardinal;
begin
  FPosted := False;
  if (FDesigner = nil) or FDesigner.FDestroying or not Stage.HandleAllocated then Exit;
  { a multiple of 100 px, the rest the ground: a per cent of it is whole pixels, so the picture is
    stretched by exactly the zoom at every size of the stage (PaintBuffer) - a stage sized with the
    form changed the ratio by a rounding, and the controls moved by a pixel as the form was sized }
  W := (Max(1, Stage.Width) + 99) div 100 * 100;
  H := (Max(1, Stage.Height) + 99) div 100 * 100;
  if (W <> FPicW) or (H <> FPicH) or (FPicture = 0) then
  begin
    FreePicture;
    FPicture := UICreateDib32(W, H, Bits);
    if FPicture = 0 then Exit;
    FPicDC := CreateCompatibleDC(0);
    SelectObject(FPicDC, FPicture);
    FPicW := W;
    FPicH := H;
  end;
  UIFill(FPicDC, Rect(0, 0, W, H), TControlCracker(FDesigner.FSurface).Color);
  PrintWindowTree(Stage.Handle, FPicDC);
end;

{ a step of a drag: the picture and the screen at once }
procedure TDesignZoomView.RenderNow;
begin
  if not HandleAllocated or not Visible then Exit;
  Render;
  InvalidateRect(Handle, nil, False);
  UpdateWindow(Handle);
end;

{ the stage changed: the picture again once the messages of now are done (one for many changes) }
procedure TDesignZoomView.RenderLater;
begin
  if FPosted or not HandleAllocated or not Visible then Exit;
  FPosted := True;
  PostMessage(Handle, CM_SD_ZOOMRENDER, 0, 0);
end;

procedure TDesignZoomView.CMZoomRender(var Message: TMessage);
begin
  if not FPosted then Exit;
  Render;
  UpdateScrollBars;
  Invalidate;
end;

{ what changes without the designer (a control's animation, a picture that came late) shows too }
procedure TDesignZoomView.TimerTick(Sender: TObject);
begin
  if Visible and (FCapture = 0) then RenderLater;
end;

function TDesignZoomView.StagePoint(X, Y: Integer): TPoint;
begin
  Result.X := FloorDivide((X + FOrigin.X) * 100, Zoom);
  Result.Y := FloorDivide((Y + FOrigin.Y) * 100, Zoom);
end;

function TDesignZoomView.ClientPoint(const S: TPoint): TPoint;
begin
  Result.X := MulDiv(S.X, Zoom, 100) - FOrigin.X;
  Result.Y := MulDiv(S.Y, Zoom, 100) - FOrigin.Y;
end;

function TDesignZoomView.LiveAt(X, Y: Integer): TPoint;
begin
  Result := StagePoint(X, Y);
  Windows.ClientToScreen(Stage.Handle, Result);
end;

{ the window of the stage that a click at LivePt (the screen point of the stage's own place) goes
  to, as Windows finds it: the topmost shown and enabled child that holds the point and does not let
  the mouse through (HTTRANSPARENT: the snap lines, the outlines), then its own children; Hit its
  hit test (the stage itself: its client area) }
function TDesignZoomView.TargetAt(const LivePt: TPoint; out Hit: Integer): HWND;
var
  W, C, Found: HWND;
  R: TRect;
  Style: Longint;
  H: Integer;
begin
  W := Stage.Handle;
  Hit := HTCLIENT;
  repeat
    Found := 0;
    C := GetWindow(W, GW_CHILD);
    while C <> 0 do
    begin
      Style := GetWindowLong(C, GWL_STYLE);
      if (Style and WS_VISIBLE <> 0) and (Style and WS_DISABLED = 0) then
      begin
        GetWindowRect(C, R);
        if PtInRect(R, LivePt) then
        begin
          H := SendMessage(C, WM_NCHITTEST, 0, MakeLParam(Word(LivePt.X), Word(LivePt.Y)));
          if H <> HTTRANSPARENT then
          begin
            Found := C;
            Hit := H;
            Break;
          end;
        end;
      end;
      C := GetWindow(C, GW_HWNDNEXT);
    end;
    if Found = 0 then Break;
    W := Found;
  until False;
  Result := W;
end;

{ a mouse message of the view to the stage's window at that place (FCapture while it has the
  mouse): its client point, or a non-client message with its hit test and the screen point. A
  stage's window that takes the mouse then (the designer's drag, a control's own press) keeps it in
  effect: the view takes Windows' capture and passes the moves on }
procedure TDesignZoomView.PassMouse(var Message: TMessage);
var
  P, Live: TPoint;
  Target, C: HWND;
  Hit: Integer;
  Msg: Cardinal;
  Down, Up: Boolean;
begin
  Msg := Message.Msg;
  Down := (Msg = WM_LBUTTONDOWN) or (Msg = WM_RBUTTONDOWN) or (Msg = WM_MBUTTONDOWN) or
    (Msg = WM_LBUTTONDBLCLK) or (Msg = WM_RBUTTONDBLCLK) or (Msg = WM_MBUTTONDBLCLK);
  Up := (Msg = WM_LBUTTONUP) or (Msg = WM_RBUTTONUP) or (Msg = WM_MBUTTONUP);
  { the mouse held for a window of the stage with no button down (its release went elsewhere, the
    window went): let go - else every click of the program would come here }
  if (FCapture <> 0) and ((not Down and not Up and (Message.WParam and AnyButton = 0)) or not IsWindow(FCapture)) then
  begin
    FCapture := 0;
    if GetCapture = Handle then ReleaseCapture;
  end;
  Live := LiveAt(SmallInt(Message.LParamLo), SmallInt(Message.LParamHi));
  if FCapture <> 0 then
  begin
    Target := FCapture;
    Hit := HTCLIENT;
  end
  else
    Target := TargetAt(Live, Hit);
  { a double click to a window whose class takes none: a press, as Windows sends it }
  if (GetClassLong(Target, GCL_STYLE) and CS_DBLCLKS = 0) and (Hit = HTCLIENT) then
    case Msg of
      WM_LBUTTONDBLCLK: Msg := WM_LBUTTONDOWN;
      WM_RBUTTONDBLCLK: Msg := WM_RBUTTONDOWN;
      WM_MBUTTONDBLCLK: Msg := WM_MBUTTONDOWN;
    end;
  if Hit = HTCLIENT then
  begin
    P := Live;
    Windows.ScreenToClient(Target, P);
    Message.Result := SendMessage(Target, Msg, Message.WParam, MakeLParam(Word(P.X), Word(P.Y)));
  end
  else
    Message.Result := SendMessage(Target, Msg - WM_MOUSEMOVE + WM_NCMOUSEMOVE, Hit,
      MakeLParam(Word(Live.X), Word(Live.Y)));
  if FDesigner.FDestroying or not HandleAllocated then Exit;
  { the press took the mouse for a window of the stage: the view keeps it for that window }
  C := GetCapture;
  if (C <> 0) and (C <> Handle) and ((C = Stage.Handle) or IsChild(Stage.Handle, C)) then
  begin
    FCapture := C;
    SetCapture(Handle);
  end;
  { a release with no button down any more ends the window's capture, as Windows ends it for the
    window itself: the VCL's own (TControl.MouseCapture: a click beside the form, on the stage)
    lets go only of a capture that is its control's, and the view's is not }
  if Up and (FCapture <> 0) and (Message.WParam and AnyButton = 0) and (GetCapture = Handle) then
    ReleaseCapture;
  { what the press, the release or the step of a drag changed, at once }
  if Down or Up or (FCapture <> 0) then RenderNow;
end;

procedure TDesignZoomView.WndProc(var Message: TMessage);
begin
  if (FDesigner <> nil) and not FDesigner.FDestroying then
    case Message.Msg of
      WM_MOUSEMOVE, WM_LBUTTONDOWN, WM_LBUTTONUP, WM_LBUTTONDBLCLK, WM_RBUTTONDOWN, WM_RBUTTONUP,
      WM_RBUTTONDBLCLK, WM_MBUTTONDOWN, WM_MBUTTONUP, WM_MBUTTONDBLCLK:
        begin
          PassMouse(Message);
          Exit;
        end;
    end;
  inherited WndProc(Message);
end;

{ the pointer of the stage's window under it (a grab handle's arrows, the form's sizing edges) }
procedure TDesignZoomView.WMSetCursor(var Message: TWMSetCursor);
var
  P: TPoint;
  Target: HWND;
  Hit: Integer;
begin
  if (Message.HitTest = HTCLIENT) and (FDesigner <> nil) and GetCursorPos(P) then
  begin
    Windows.ScreenToClient(Handle, P);
    Target := TargetAt(LiveAt(P.X, P.Y), Hit);
    if SendMessage(Target, WM_SETCURSOR, Target, MakeLParam(Word(Hit), Message.MouseMsg)) = 0 then
      Windows.SetCursor(LoadCursor(0, IDC_ARROW));
    Message.Result := 1;
  end
  else
    inherited;
end;

{ the keyboard stays with the surface: the designer's keys }
procedure TDesignZoomView.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  if FDesigner <> nil then FDesigner.FocusSurface;
end;

{ the view lost the mouse it held for a window of the stage: that window hears of it (the designer
  ends a drag another window took the mouse from) }
procedure TDesignZoomView.WMCaptureChanged(var Message: TMessage);
var
  C: HWND;
begin
  inherited;
  if (FCapture = 0) or (HWND(Message.LParam) = Handle) then Exit;
  C := FCapture;
  FCapture := 0;
  if IsWindow(C) then SendMessage(C, WM_CAPTURECHANGED, 0, Message.LParam);
  RenderLater;
end;

procedure TDesignZoomView.WMMouseWheel(var Message: TWMMouseWheel);
begin
  WheelToDesigner(FDesigner, Message);
end;

function TDesignZoomView.ContentSize: TPoint;
begin
  Result := Point(MulDiv(Stage.Width, Zoom, 100), MulDiv(Stage.Height, Zoom, 100));
end;

function TDesignZoomView.LineSize: Integer;
begin
  Result := ZoomLine;
end;

{ a new size, or its scroll bars that come or go: the form positioner keeps to its corner }
procedure TDesignZoomView.Resize;
begin
  inherited Resize;
  UpdateScrollBars;
  Invalidate;
  if (FDesigner <> nil) and Visible then FDesigner.PlacePositioner;
end;

{ the ground, then the part of the picture in view at the zoom: whole multiples pixel by pixel,
  other zooms smoothed }
{ the whole picture at the zoom, the client clipping it: one mapping of the picture's pixels at
  every size of the view and of the stage, and every scroll position (Render sizes the picture so
  that the zoom of it is whole pixels) - a copy of only the part in view stretched it by a ratio
  that changed with the view's size, and the controls moved by a pixel as the view was resized }
procedure TDesignZoomView.PaintBuffer(C: TCanvas);
var
  DC: HDC;
begin
  DC := C.Handle;
  UIFill(DC, ClientRect, TControlCracker(FDesigner.FSurface).Color);
  if FPicture = 0 then Exit;
  if Zoom mod 100 = 0 then
    SetStretchBltMode(DC, COLORONCOLOR)
  else
  begin
    SetStretchBltMode(DC, HALFTONE);
    SetBrushOrgEx(DC, 0, 0, nil);
  end;
  StretchBlt(DC, -FOrigin.X, -FOrigin.Y, MulDiv(FPicW, Zoom, 100), MulDiv(FPicH, Zoom, 100),
    FPicDC, 0, 0, FPicW, FPicH, SRCCOPY);
end;

{ ---------------------------------------------------------------- TFormDesigner: life cycle }

constructor TFormDesigner.Create(AParent: TWinControl; ABridge: TSdSourceBridge; Bordered: Boolean);
begin
  inherited Create;
  FBridge := ABridge;
  FSelection := TList.Create;
  FHandles := TList.Create;
  FIcons := TList.Create;
  FLateAdds := TList.Create;
  FOutlines := TList.Create;
  FSnapLines := TList.Create;
  FDragged := TList.Create;
  FBuffered := TList.Create;
  FAncestorTexts := TStringList.Create;
  FZoom := 100;
  FSurface := TDesignSurface.Create(nil);
  FSurface.FDesigner := Self;
  FSurface.FBordered := Bordered;
  TDesignStage(FSurface.FStage).FDesigner := Self;
  FSurface.Parent := AParent;
  FSurface.Align := alClient;
end;

{ ---------------------------------------------------------------- designer hints }

{ Environment Options | Designer | Show designer hints: resting on a component shows its name and
  class, with Show extended control hints also its position, size and tab order (as Delphi) }
procedure TFormDesigner.TrackDesignHint(C: TComponent; const ScreenPt: TPoint);
begin
  if not DesignEnv.ShowHints or (C = nil) then
  begin
    HideDesignHint;
    Exit;
  end;
  FHintPt := ScreenPoint(ScreenPt);          // where the pointer is (the zoomed view's place)
  if C = FHintTarget then Exit;
  HideDesignHint;
  FHintTarget := C;
  if FHintTimer = nil then
  begin
    FHintTimer := TTimer.Create(nil);
    FHintTimer.OnTimer := HintTimerTick;
  end;
  FHintTimer.Enabled := False;
  FHintTimer.Interval := Application.HintPause;
  FHintTimer.Tag := 0;
  FHintTimer.Enabled := True;
end;

procedure TFormDesigner.HideDesignHint;
begin
  if FHintTimer <> nil then FHintTimer.Enabled := False;
  if (FHint <> nil) and FHint.HandleAllocated then ShowWindow(FHint.Handle, SW_HIDE);
  FHintTarget := nil;
end;

{ The hint comes after Application.HintPause and goes after Delphi's 2.5 s (the VCL's default
  HintHidePause - the IDE's own is longer, for its tool bars), or as soon as the pointer is over
  another window (it left the form; another component of the form changes the hint by itself).
  While it shows, the timer looks every 100 ms: a timer has no message to take the pointer from. }
const
  DesignHintTime = 2500;

procedure TFormDesigner.HintTimerTick(Sender: TObject);
var
  S: string;
  R: TRect;
  C: TControl;
  P: TPoint;
begin
  { 1: the hint shows; 2: its time is over - it does not come back for the same component
    until the pointer has left it }
  if FHintTimer.Tag >= 1 then
  begin
    if not GetCursorPos(P) or (WindowFromPoint(P) <> FHintWnd) then
      HideDesignHint
    else if (FHintTimer.Tag = 1) and (GetTickCount - FHintSince >= DesignHintTime) then
    begin
      if (FHint <> nil) and FHint.HandleAllocated then ShowWindow(FHint.Handle, SW_HIDE);
      FHintTimer.Tag := 2;
    end;
    Exit;
  end;
  FHintTimer.Enabled := False;
  if (FHintTarget = nil) or FDestroying then Exit;
  { the pointer went on to another window during the pause (another program's window over the
    form, a view beside it): the form gets no message for that, and no hint is shown for a place
    the pointer has left }
  if not GetCursorPos(P) or (WindowFromPoint(P) <> WindowFromPoint(FHintPt)) then
  begin
    HideDesignHint;
    Exit;
  end;
  S := FHintTarget.Name + ': ' + FHintTarget.ClassName;
  if DesignEnv.ExtendedHints and (FHintTarget is TControl) and (FHintTarget <> FRoot) then
  begin
    C := TControl(FHintTarget);
    S := S + #13#10 + Format('Origin: %d, %d; Size: %d x %d', [C.Left, C.Top, C.Width, C.Height]);
    if C is TWinControl then
      S := S + #13#10 + Format('Tab Stop: %s; Order: %d', [BoolToStr(TWinControl(C).TabStop, True),
        TWinControl(C).TabOrder]);
  end;
  if FHint = nil then
  begin
    FHint := HintWindowClass.Create(nil);
    FHint.Color := Application.HintColor;
  end;
  R := FHint.CalcHintRect(Screen.Width, S, nil);
  OffsetRect(R, FHintPt.X, FHintPt.Y + 20);
  FHint.ActivateHint(R, S);
  FHintWnd := WindowFromPoint(FHintPt);
  FHintSince := GetTickCount;
  FHintTimer.Interval := 100;
  FHintTimer.Tag := 1;
  FHintTimer.Enabled := True;
end;
destructor TFormDesigner.Destroy;
begin
  FDestroying := True;
  ReleaseVerbs;                  // while their components are there
  FreeAndNil(FHintTimer);
  FreeAndNil(FHint);
  FreeAndNil(FAncestorRoot);
  FreePristine;
  FreeFrameChains;
  FreeAndNil(FFrameClasses);
  FreeAndNil(FAncestorTexts);
  if FRoot <> nil then
    try
      DesignHost.NotifyDesignerClosed(Self);
    except
    end;
  ClearHelpers;
  FSelection.Clear;
  try
    FreeAndNil(FModule);
  except
  end;
  if FForm <> nil then
  begin
    FForm.Designer := nil;
    try
      FForm.ParentWindow := 0;
    except
    end;
  end;
  if FRoot <> nil then
  begin
    try
      FRoot.Free;
    except
    end;
    FRoot := nil;
    FForm := nil;
  end;
  FreeAndNil(FPositioner);
  FreeAndNil(FZoomView);
  FSurface.Free;
  FOutlines.Free;
  FSnapLines.Free;
  FDragged.Free;
  FBuffered.Free;
  FIcons.Free;
  FLateAdds.Free;
  FHandles.Free;
  FSelection.Free;
  inherited;
end;

function TFormDesigner.QueryInterface(const IID: TGUID; out Obj): HResult;
begin
  if GetInterface(IID, Obj) then Result := S_OK else Result := E_NOINTERFACE;
end;

function TFormDesigner._AddRef: Integer;
begin
  Result := -1;
end;

function TFormDesigner._Release: Integer;
begin
  Result := -1;
end;

procedure TFormDesigner.NewForm(const AName, AClassName: string);
var
  F: TSdDesignForm;
begin
  F := TSdDesignForm.CreateNew(nil);
  FForm := F;
  FRoot := F;
  TComponentCracker(F).SetDesigning(True);
  CreateSubClass(F, AClassName, FBridge.GetUnitName, TSdDesignForm);
  F.Name := AName;
  F.Caption := AName;
  F.Left := 192;
  F.Top := 107;
  F.OldCreateOrder := False;
  F.Designer := Self;
  F.FDsg := Self;
  F.ParentWindow := FSurface.FStage.Handle;
  F.SetBounds(StageMargin, StageMargin, 696, 480);
  F.DesignShow;
  StageChanged;
  DesignHost.NotifyDesignerOpened(Self);
  Select(F);
  FModified := False;
end;

{ form text as binary form data (the stream at its start; the caller frees it) }
function DfmTextStream(const DfmText: string): TMemoryStream;
var
  TextStream: TStringStream;
begin
  Result := TMemoryStream.Create;
  TextStream := TStringStream.Create(DfmText);
  try
    try
      ObjectTextToBinary(TextStream, Result);
    except
      Result.Free;
      raise;
    end;
  finally
    TextStream.Free;
  end;
  Result.Position := 0;
end;

{ binary form data into Root (a new root, or one that has its ancestors' components already:
  "inherited" entries change those) }
procedure TFormDesigner.ReadStream(Root: TComponent; Bin: TStream; CheckMethods: Boolean);
var
  Reader: TReader;
  OwnCache: Boolean;
begin
  Reader := TReader.Create(Bin, 4096);
  OwnCache := BeginMethodCache;
  try
    if CheckMethods then Reader.OnFindMethod := PasteFindMethod else Reader.OnFindMethod := ReaderFindMethod;
    Reader.OnError := ReaderError;
    Reader.OnFindComponentClass := ReaderFindComponentClass;
    Reader.OnCreateComponent := ReaderCreateComponent;
    Reader.ReadRootComponent(Root);
  finally
    EndMethodCache(OwnCache);
    Reader.Free;
  end;
end;

{ DfmText into Root (ReadStream) }
procedure TFormDesigner.ReadText(Root: TComponent; const DfmText: string; CheckMethods: Boolean);
var
  Bin: TMemoryStream;
begin
  Bin := DfmTextStream(DfmText);
  try
    ReadStream(Root, Bin, CheckMethods);
  finally
    Bin.Free;
  end;
end;

{ the form texts of a form's ancestors or of a frame (the first ancestor first) into Root, one after
  the other, its components then marked as inherited (csAncestor); Bins (nil: not wanted) gets
  each text's binary data to read it again (the caller frees them) }
procedure TFormDesigner.ReadInherited(Root: TComponent; Texts: TStrings; Bins: TList);
var
  I: Integer;
  Bin: TMemoryStream;
begin
  for I := 0 to Texts.Count - 1 do
  begin
    Bin := DfmTextStream(Texts[I]);
    try
      ReadStream(Root, Bin, False);
    finally
      if Bins <> nil then Bins.Add(Bin) else Bin.Free;
    end;
  end;
  for I := 0 to Root.ComponentCount - 1 do TComponentCracker(Root.Components[I]).SetAncestor(True);
end;

{ Visual form inheritance as Delphi does it: the ancestors' .dfm texts first (their components
  marked csAncestor: they cannot be deleted or renamed here), then the form's own, whose
  "inherited" entries change them. The ancestor is also loaded alone (FAncestorRoot): what the
  form is written as are its differences from it (TWriter's ancestor). A custom module's own
  properties are read into a new instance of its class (FModule), after the root: their events
  name the root's methods. }
procedure TFormDesigner.LoadFromText(const DfmText: string; Errors: TStrings; Ancestors: TStrings;
  CheckMethods: Boolean);
var
  F: TSdDesignForm;
  M: TComponent;
  ObjName, ObjClass, HostText, ModuleText: string;
  W, H, I: Integer;
  Style: TControlStyle;
  Bins: TList;
begin
  if not DfmObjectHeader(DfmText, ObjName, ObjClass) then
    raise Exception.Create('The form file does not start with an object declaration.');
  FLoadErrors := Errors;
  FLoading := True;
  FreeFrameChains;                 // the frames' form files as they are now
  M := nil;
  F := TSdDesignForm.CreateNew(nil);
  try
    FForm := F;
    FRoot := F;
    HostText := DfmText;
    if (FModuleClass <> nil) and FModuleClass.InheritsFrom(TDataModule) then
    begin
      M := NewModule(ObjName);
      HostText := SplitModule(DfmText, M, ModuleText);
    end;
    TComponentCracker(F).SetDesigning(True);
    CreateSubClass(F, ObjClass, FBridge.GetUnitName, TSdDesignForm);
    F.OldCreateOrder := True;      // the default for forms that do not store the property
    F.Designer := Self;
    F.FDsg := Self;
    F.ParentWindow := FSurface.FStage.Handle;
    if (Ancestors <> nil) and (Ancestors.Count > 0) then
    begin
      { each ancestor's text is converted once: the ancestor alone is read from the same data }
      Bins := TList.Create;
      try
        ReadInherited(F, Ancestors, Bins);
        FAncestorRoot := TSdDesignForm.CreateNew(nil);
        TComponentCracker(FAncestorRoot).SetDesigning(True);
        FAncestorRoot.OldCreateOrder := True;
        for I := 0 to Bins.Count - 1 do
        begin
          TStream(Bins[I]).Position := 0;
          ReadStream(FAncestorRoot, TStream(Bins[I]), False);
        end;
      finally
        for I := 0 to Bins.Count - 1 do TObject(Bins[I]).Free;
        Bins.Free;
      end;
    end;
    ReadText(F, HostText, CheckMethods);
    { the name, but not as the caption: csSetCaption would give a form whose text has no Caption
      its name as one (and the next save would write it) }
    Style := F.ControlStyle;
    F.ControlStyle := Style - [csSetCaption];
    F.Name := ObjName;
    F.ControlStyle := Style;
    if M <> nil then ReadText(M, ModuleText, CheckMethods);
  except
    FLoading := False;
    FLoadErrors := nil;
    FForm := nil;
    FRoot := nil;
    F.Designer := nil;
    F.Free;
    FreeAndNil(FAncestorRoot);
    M.Free;
    raise;
  end;
  FModule := M;
  FLoading := False;
  FLoadErrors := nil;
  if Ancestors <> nil then FAncestorTexts.Assign(Ancestors) else FAncestorTexts.Clear;
  { the window was made when it got its parent window, before BorderStyle and BorderIcons were
    read, and the VCL does not make it again for them at design time: its frame now, the client
    size kept (what the .dfm stores) }
  F.UpdateBorder;
  W := F.Width;
  H := F.Height;
  F.SetBounds(StageMargin, StageMargin, W, H);
  F.DesignShow;
  StageChanged;
  DesignHost.NotifyDesignerOpened(Self);
  Select(F);
  FModified := False;
  PostUpdateHelpers;
end;

function TFormDesigner.SaveToText: string;
var
  Bin: TMemoryStream;
  W: TWriter;
  Names, Texts: TStringList;
  Header, Rest: string;
begin
  Result := '';
  if FRoot = nil then Exit;
  Bin := TMemoryStream.Create;
  try
    { an inherited form: what differs from its ancestor ("inherited" entries); an inline frame:
      what differs from its own form files (WriterFindAncestor) }
    W := TWriter.Create(Bin, 4096);
    try
      W.OnFindAncestor := WriterFindAncestor;
      W.WriteDescendent(FRoot, FAncestorRoot);
    finally
      W.Free;
      FreePristine;
    end;
    Bin.Position := 0;
    Result := FormText(Bin);
  finally
    Bin.Free;
  end;
  { a form's poDesigned written although it is Delphi 7's default (WithDesignedPosition); an
    inherited form writes Position only where it differs from its ancestor's, whose text has it }
  if (FHostKind = hkForm) and (FModule = nil) and (FAncestorRoot = nil) and (FForm <> nil) and
    (FForm.Position = poDesigned) and not FForm.IsControl then
    Result := WithDesignedPosition(Result, FForm);
  { a custom module: its own properties after the host's (LoadFromText takes them into the
    module again - undo and redo keep them) }
  if FModule = nil then Exit;
  Names := TStringList.Create;
  Texts := TStringList.Create;
  try
    SplitDfmRoot(Result, Header, Names, Texts, Rest);
    Result := JoinDfmRoot(Header, Texts, ModuleLines(False) + Rest);
  finally
    Texts.Free;
    Names.Free;
  end;
end;

{ Undo and redo, and a frame or an ancestor that changed (TEditorPage.ReadFormAgain): the form
  read again into a new root, in place of the shown one - the same designer and stage, which
  paints once when the new form is there. The packages' editors of the old components close with
  them (designer closed, opened again); an event whose method the unit no longer has stays empty.
  When the text cannot be read, the old form stays. }
procedure TFormDesigner.Reload(const DfmText: string; Ancestors: TStrings; const Selected: string;
  Errors: TStrings);
var
  OldForm, OldAnc: TSdDesignForm;
  OldModule: TComponent;
  Stage: HWND;
  Errs, Names: TStringList;
  C: TComponent;
  I: Integer;
  L: TList;
  OldStage: TRect;
  Gone, Kept: HRGN;
begin
  if FForm = nil then Exit;
  CancelDrag;
  HideDesignHint;
  Stage := FSurface.FStage.Handle;
  OldStage := FSurface.FStage.BoundsRect;
  SendMessage(Stage, WM_SETREDRAW, 0, 0);
  Errs := TStringList.Create;
  Names := TStringList.Create;
  try
    DesignHost.NotifyDesignerClosed(Self);
    ClearHelpers;
    FLateAdds.Clear;
    FSizeTarget := nil;
    FDragContainer := nil;
    { the inspector lets go of the old components first }
    FSelection.Clear;
    SelectionChanged;
    OldForm := FForm;
    OldAnc := FAncestorRoot;
    OldModule := FModule;
    FAncestorRoot := nil;
    FModule := nil;
    try
      LoadFromText(DfmText, Errs, Ancestors, True);
    except
      FForm := OldForm;
      FRoot := OldForm;
      FAncestorRoot := OldAnc;
      FModule := OldModule;
      DesignHost.NotifyDesignerOpened(Self);
      Select(FRoot);
      raise;
    end;
    { the frame as active as the old one (the surface keeps the focus: no WM_NCACTIVATE comes) }
    FForm.FFrameActive := OldForm.FFrameActive;
    OldForm.Designer := nil;
    try
      OldForm.ParentWindow := 0;
    except
    end;
    try
      OldForm.Free;
    except
    end;
    OldAnc.Free;
    try
      OldModule.Free;
    except
    end;
    { the selection again, in one step: the inspector builds its rows once }
    Names.CommaText := Selected;
    L := TList.Create;
    try
      for I := 0 to Names.Count - 1 do
      begin
        C := GetComponent(Names[I]);
        if C <> nil then L.Add(C);
      end;
      if L.Count > 1 then L.Remove(FRoot);        // the root never takes part in a multiple selection
      if L.Count > 0 then SelectList(L);
    finally
      L.Free;
    end;
    StructureChanged;
    FModified := True;
    { a form text that lost something on the way back - a step, a component its frame or ancestor
      no longer has (never silently) }
    if Errs.Count > 0 then
    begin
      LogDesignError('designer, form read again', Format('%s: %d read error(s): %s', [FRoot.Name, Errs.Count,
        StringReplace(Trim(Errs.Text), #13#10, '; ', [rfReplaceAll])]));
      if Errors <> nil then Errors.AddStrings(Errs);
    end;
  finally
    Names.Free;
    Errs.Free;
    SendMessage(Stage, WM_SETREDRAW, 1, 0);
    { a stage made smaller while it did not redraw counted as hidden: Windows did not invalidate
      the part of the surface it gave up, which still shows the old form - that part alone }
    Gone := CreateRectRgnIndirect(OldStage);
    Kept := CreateRectRgnIndirect(FSurface.FStage.BoundsRect);
    try
      if CombineRgn(Gone, Gone, Kept, RGN_DIFF) <> NULLREGION then
        RedrawWindow(FSurface.Handle, nil, Gone, RDW_INVALIDATE or RDW_ERASE);
    finally
      DeleteObject(Kept);
      DeleteObject(Gone);
    end;
    RedrawWindow(Stage, nil, 0, RDW_INVALIDATE or RDW_ERASE or RDW_FRAME or RDW_ALLCHILDREN or RDW_UPDATENOW);
  end;
end;

function TFormDesigner.SelectionNames: string;
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    { a placed frame's component by its path (Frame21.Button1: GetComponent finds it again) }
    for I := 0 to FSelection.Count - 1 do
      if TObject(FSelection[I]) is TComponent then L.Add(GetComponentName(TComponent(FSelection[I])));
    Result := L.CommaText;
  finally
    L.Free;
  end;
end;

{ the root's method of that name, made when it has none - also for the events of a custom module's
  instance (FModule), whose reader looks in the module's class first; a frame's own form files name
  the frame's methods }
procedure TFormDesigner.ReaderFindMethod(Reader: TReader; const MethodName: string;
  var Address: Pointer; var Error: Boolean);
var
  R: TComponent;
begin
  R := FRoot;
  if Reader.Root is TSdDesignFrame then R := Reader.Root;
  if Address = nil then
    Address := R.MethodAddress(MethodName);
  if Address = nil then
    Address := CreateSubClassMethod(R, MethodName);
  Error := Address = nil;
end;

{ A pasted component keeps only the handlers this unit has: one copied from another form (or
  whose method was deleted from the unit) would leave the form file naming a method that does
  not exist - the program fails when it creates the form. The event stays empty instead. }
procedure TFormDesigner.PasteFindMethod(Reader: TReader; const MethodName: string;
  var Address: Pointer; var Error: Boolean);
var
  I: Integer;
  Found: Boolean;
begin
  I := -1;
  if FFoundMethods <> nil then I := FFoundMethods.IndexOf(MethodName);
  if I >= 0 then
    Found := FFoundMethods.Objects[I] <> nil
  else
  begin
    Found := (FBridge <> nil) and FBridge.MethodExists(MethodName);
    if FFoundMethods <> nil then FFoundMethods.AddObject(MethodName, TObject(Ord(Found)));
  end;
  if Found then
    ReaderFindMethod(Reader, MethodName, Address, Error)
  else
  begin
    Address := nil;
    Error := False;
  end;
end;

function TFormDesigner.BeginMethodCache: Boolean;
begin
  Result := FFoundMethods = nil;
  if Result then FFoundMethods := TStringList.Create;
end;

procedure TFormDesigner.EndMethodCache(Own: Boolean);
begin
  if Own then FreeAndNil(FFoundMethods);
end;

procedure TFormDesigner.ReaderError(Reader: TReader; const Message: string; var Handled: Boolean);
begin
  { unknown properties are skipped (Delphi's "Ignore"); the caller reports them }
  if FLoadErrors <> nil then FLoadErrors.Add(Message);
  Handled := True;
end;

procedure TFormDesigner.ReaderFindComponentClass(Reader: TReader; const AClassName: string;
  var ComponentClass: TComponentClass);
var
  C: TComponentClass;
begin
  if ComponentClass = nil then
  begin
    C := DesignHost.FindComponentClass(AClassName);
    if C <> nil then
      ComponentClass := C
    else if FrameChain(AClassName) <> nil then
    begin
      { a frame of the project: ReaderCreateComponent makes it of its form files }
      ComponentClass := TSdDesignFrame;
      FPendingFrame := AClassName;
    end;
  end;
end;

{ ---------------------------------------------------------------- frames of the project }

{ csDesignInstance while TCustomFrame.Create runs: it does not look for a form file of the class
  in the program's resources - the designer reads the frame's own }
constructor TSdDesignFrame.Create(AOwner: TComponent);
begin
  SetDesignInstance(True);
  inherited Create(AOwner);
  SetDesignInstance(False);
  ControlStyle := ControlStyle - [csAcceptsControls];
end;

{ the .dfm texts of frame class AClassName of the project (the first ancestor first), nil: no frame
  of the project - the bridge is asked once per class for each load }
function TFormDesigner.FrameChain(const AClassName: string): TStrings;
var
  I: Integer;
  L: TStringList;
begin
  Result := nil;
  if FBridge = nil then Exit;
  if FFrameChains = nil then FFrameChains := TStringList.Create;
  I := FFrameChains.IndexOf(AClassName);
  if I < 0 then
  begin
    L := TStringList.Create;
    if not FBridge.FrameDfms(AClassName, L) then FreeAndNil(L);
    I := FFrameChains.AddObject(AClassName, L);
  end;
  Result := TStrings(FFrameChains.Objects[I]);
end;

{ every frame class the form was read with, asked again: its form files now (an open page's as
  they are, with what is not saved) against the ones read - also a class that was no frame then
  and is one now, or the reverse }
function TFormDesigner.FramesChanged: Boolean;
var
  I: Integer;
  Cur: TStringList;
  Was: TStrings;
  Found: Boolean;
begin
  Result := False;
  if (FFrameChains = nil) or (FBridge = nil) then Exit;
  Cur := TStringList.Create;
  try
    for I := 0 to FFrameChains.Count - 1 do
    begin
      Cur.Clear;
      Found := FBridge.FrameDfms(FFrameChains[I], Cur);
      Was := TStrings(FFrameChains.Objects[I]);
      if (Found <> (Was <> nil)) or (Found and (Cur.Text <> Was.Text)) then
      begin
        Result := True;
        Exit;
      end;
    end;
  finally
    Cur.Free;
  end;
end;

procedure TFormDesigner.FreeFrameChains;
var
  I: Integer;
begin
  if FFrameChains = nil then Exit;
  for I := 0 to FFrameChains.Count - 1 do FFrameChains.Objects[I].Free;
  FreeAndNil(FFrameChains);
end;

{ an instance of frame class AClassName: its form files read into it, the ancestor's first; its
  components are inherited ones (csAncestor), the form's "inherited" entries change them. AOwner
  nil: the frame alone, which the writer compares a placed one with - parented to the
  application's window, which has no size, for components that need a window while read, and
  with what a placed one takes from the designed form (font, colour, Ctl3D, hints, BiDiMode):
  without a parent it had the VCL's default font and Ctl3D off, and a control that sizes itself
  (an edit: AdjustHeight) was written as changed. All instances of a frame class are of one class
  (the first one's subclass), as in Delphi: the writer compares an instance with its ancestor
  only when it is of the ancestor's class. }
function TFormDesigner.NewDesignFrame(const AClassName: string; AOwner: TComponent): TComponent;
var
  F: TSdDesignFrame;
  Chain: TStrings;
  I: Integer;
begin
  F := TSdDesignFrame.Create(AOwner);
  I := -1;
  if FFrameClasses <> nil then I := FFrameClasses.IndexOf(AClassName);
  if I >= 0 then
    ChangeToProxyClass(F, TClass(FFrameClasses.Objects[I]))   // a proxy class makes no instances itself
  else
  begin
    CreateSubClass(F, AClassName, '', TSdDesignFrame);
    if FFrameClasses = nil then FFrameClasses := TStringList.Create;
    FFrameClasses.AddObject(AClassName, TObject(F.ClassType));
  end;
  TComponentCracker(F).SetInline(True);
  TComponentCracker(F).SetDesigning(True);
  if AOwner = nil then
  begin
    { what a placed frame takes from the form, first - its form files may set its own: the
      Parent... properties stay True, as a placed frame's, with no parent to take them from }
    if FForm <> nil then
    begin
      F.Font := FForm.Font;
      F.Color := FForm.Color;
      F.Ctl3D := FForm.Ctl3D;
      F.ShowHint := FForm.ShowHint;
      F.BiDiMode := FForm.BiDiMode;
      F.ParentFont := True;
      F.ParentColor := True;
      F.ParentCtl3D := True;
      F.ParentShowHint := True;
      F.ParentBiDiMode := True;
    end;
    F.ParentWindow := Application.Handle;
  end;
  Chain := FrameChain(AClassName);
  if (Chain <> nil) and (FFrameDepth < 8) then      // a frame that holds itself ends here
  begin
    Inc(FFrameDepth);
    try
      ReadInherited(F, Chain, nil);
    finally
      Dec(FFrameDepth);
    end;
  end;
  Result := F;
end;

procedure TFormDesigner.ReaderCreateComponent(Reader: TReader; ComponentClass: TComponentClass;
  var Component: TComponent);
var
  Cls: string;
begin
  if (ComponentClass <> TSdDesignFrame) or (FPendingFrame = '') then Exit;
  Cls := FPendingFrame;
  FPendingFrame := '';
  Component := NewDesignFrame(Cls, Reader.Owner);
end;

{ a placed frame is written as Delphi writes it: what differs from the frame alone ("inline", its
  components as "inherited" entries) - one frame alone per class while the form is written }
procedure TFormDesigner.WriterFindAncestor(Writer: TWriter; Component: TComponent; const Name: string;
  var Ancestor, RootAncestor: TComponent);
begin
  if (Ancestor <> nil) or not (Component is TSdDesignFrame) or
    not (csInline in Component.ComponentState) then Exit;
  Ancestor := PristineFrame(Component.ClassName);
  RootAncestor := Ancestor;
end;

{ frame class AClassName alone, as its form files make it: what a placed one is compared with
  (one per class until FreePristine) }
function TFormDesigner.PristineFrame(const AClassName: string): TComponent;
var
  I: Integer;
begin
  if FPristine = nil then FPristine := TStringList.Create;
  I := FPristine.IndexOf(AClassName);
  if I < 0 then I := FPristine.AddObject(AClassName, NewDesignFrame(AClassName, nil));
  Result := TComponent(FPristine.Objects[I]);
end;

procedure TFormDesigner.FreePristine;
var
  I: Integer;
begin
  if FPristine = nil then Exit;
  for I := 0 to FPristine.Count - 1 do FPristine.Objects[I].Free;
  FreeAndNil(FPristine);
end;
{ ---------------------------------------------------------------- geometry helpers }

function TFormDesigner.RootOrigin: TPoint;
begin
  if (FForm <> nil) and FForm.HandleAllocated then
    Result := FForm.ClientToScreen(Point(0, 0))
  else
    Result := Point(0, 0);
end;

function TFormDesigner.ControlRectInRoot(C: TControl): TRect;
var
  P, O: TPoint;
begin
  if (C = FForm) or (C.Parent = nil) then
  begin
    Result := FForm.ClientRect;
    Exit;
  end;
  P := C.Parent.ClientToScreen(Point(C.Left, C.Top));
  O := RootOrigin;
  Result := Bounds(P.X - O.X, P.Y - O.Y, C.Width, C.Height);
end;

{ the designed control a click on C is for: C, or its nearest parent that is designed - a
  component's own windows (a labeled edit's label) give their component, a placed frame's
  components are their own (IsDesigned) }
function TFormDesigner.DesignControlOf(C: TControl): TControl;
begin
  Result := C;
  while (Result <> nil) and (Result <> FForm) and not IsDesigned(Result) do
    Result := Result.Parent;
  if Result = nil then Result := FForm;
end;

function TFormDesigner.IsDesigned(C: TComponent): Boolean;
begin
  Result := False;
  if FRoot = nil then Exit;
  while C <> nil do
  begin
    if (C = FRoot) or (C.Owner = FRoot) then
    begin
      Result := True;
      Exit;
    end;
    { a component of a frame: the frame placed (inline) and itself designed }
    C := C.Owner;
    if not (C is TSdDesignFrame) or not (csInline in C.ComponentState) then Exit;
  end;
end;

function TFormDesigner.InFrameInstance(C: TComponent): Boolean;
begin
  Result := (C <> nil) and (C <> FRoot) and (C.Owner <> FRoot) and IsDesigned(C);
end;

procedure TFormDesigner.GetDesignedComponents(List: TList);

  procedure Add(Owner: TComponent);
  var
    I: Integer;
    C: TComponent;
  begin
    for I := 0 to Owner.ComponentCount - 1 do
    begin
      C := Owner.Components[I];
      List.Add(C);
      if (C is TSdDesignFrame) and (csInline in C.ComponentState) then Add(C);
    end;
  end;

begin
  if FRoot <> nil then Add(FRoot);
end;

{ a control on a placed frame: the frame or anything in it - new components cannot go there }
function TFormDesigner.OnFrameInstance(C: TControl): Boolean;
begin
  Result := False;
  while (C <> nil) and (C <> FForm) do
  begin
    if (C is TSdDesignFrame) and (csInline in C.ComponentState) then
    begin
      Result := True;
      Exit;
    end;
    C := C.Parent;
  end;
end;

{ Delphi 7's refusal of a new component on a placed frame }
procedure RefuseFrameAdd;
begin
  MessageBox(GetActiveWindow, 'New components cannot be added to frame instances.', 'Error',
    MB_OK or MB_ICONERROR);
end;

function TFormDesigner.MayAddTo(C: TComponent): Boolean;
begin
  Result := not (((C is TControl) and OnFrameInstance(TControl(C))) or InFrameInstance(C));
  if not Result then RefuseFrameAdd;
end;

function TFormDesigner.ContainerFor(C: TControl): TWinControl;
begin
  while (C <> nil) and (C <> FForm) and
    not ((C is TWinControl) and (csAcceptsControls in C.ControlStyle) and (C.Owner = FRoot)) do
    C := C.Parent;
  if C = nil then Result := FForm else Result := TWinControl(C);
end;

{ V on the nearest line of a grid of Size }
function GridRound(V, Size: Integer): Integer;
begin
  Result := Round(V / Size) * Size;
end;

{ with Snap to grid, V on the nearest grid line (a grid of 1 snaps nothing) }
function TFormDesigner.SnapX(V: Integer): Integer;
begin
  if DesignEnv.SnapToGrid and (DesignEnv.GridX > 1) then Result := GridRound(V, DesignEnv.GridX) else Result := V;
end;

function TFormDesigner.SnapY(V: Integer): Integer;
begin
  if DesignEnv.SnapToGrid and (DesignEnv.GridY > 1) then Result := GridRound(V, DesignEnv.GridY) else Result := V;
end;

{ a component that is being freed has no tile any more (Notification updates the helpers while
  it is still among the root's components) }
function TFormDesigner.IsNonVisual(C: TComponent): Boolean;
begin
  Result := (C <> nil) and (C <> FRoot) and not (csDestroying in C.ComponentState) and
    not (C is TControl) and not C.HasParent and (C.Owner = FRoot);
end;

{ ---------------------------------------------------------------- helper windows }

procedure TFormDesigner.ClearHelpers;
var
  I: Integer;
begin
  for I := 0 to FHandles.Count - 1 do TObject(FHandles[I]).Free;
  FHandles.Clear;
  for I := 0 to FIcons.Count - 1 do TObject(FIcons[I]).Free;
  FIcons.Clear;
  for I := 0 to FOutlines.Count - 1 do TObject(FOutlines[I]).Free;
  FOutlines.Clear;
  for I := 0 to FSnapLines.Count - 1 do TObject(FSnapLines[I]).Free;
  FSnapLines.Clear;
  FHelperParent := 0;
end;

procedure TFormDesigner.PostUpdateHelpers;
begin
  if FUpdatePosted or FDestroying or (FSurface = nil) or not FSurface.HandleAllocated then Exit;
  FUpdatePosted := True;
  PostMessage(FSurface.Handle, CM_SD_UPDATEHELPERS, 0, 0);
end;

procedure TFormDesigner.StageChanged;
var
  W, H: Integer;
begin
  if (FForm = nil) or FDestroying then Exit;
  { keep the form docked at the stage origin and size the stage around it }
  if FForm.HandleAllocated and ((TControl(FForm).Left <> StageMargin) or (TControl(FForm).Top <> StageMargin)) then
    SetWindowPos(FForm.Handle, 0, StageMargin, StageMargin, 0, 0, SWP_NOSIZE or SWP_NOZORDER or SWP_NOACTIVATE);
  W := FForm.Width + 2 * StageMargin;
  H := FForm.Height + 2 * StageMargin;
  if (FSurface.FStage.Width <> W) or (FSurface.FStage.Height <> H) then
  begin
    FSurface.FStage.SetBounds(FSurface.FStage.Left, FSurface.FStage.Top, W, H);
    StageShown;                         // the zoomed view's picture and its scroll bars
  end;
end;

{ The designed form's window paints its background around its controls, not over them (less
  flicker while it is resized). A window style only: nothing of it reaches the .dfm. }
procedure ClipFormChildren(Form: TCustomForm);
var
  Style: Longint;
begin
  if (Form = nil) or not Form.HandleAllocated then Exit;
  Style := GetWindowLong(Form.Handle, GWL_STYLE);
  if Style and WS_CLIPCHILDREN = 0 then SetWindowLong(Form.Handle, GWL_STYLE, Style or WS_CLIPCHILDREN);
end;

{ The helpers (TRawWnd) lie over the designed controls of the form. A control that is made, or
  brought to the front, lies over them: then the shown helpers under a shown control go up, each
  right under the helpers before it, so that they keep their order among themselves - helpers
  that overlap (tiles and their names) paint again what a change of their order uncovers. Once
  they are on top, nothing moves. }
procedure KeepHelpersOnTop(Parent: HWND);
var
  W, After: HWND;
  Under: array of HWND;
  I, N: Integer;
  Covered: Boolean;
begin
  After := HWND_TOP;
  Covered := False;
  N := 0;
  W := GetWindow(Parent, GW_CHILD);         // the top of the z-order
  while W <> 0 do
  begin
    if Word(GetClassLong(W, GCW_ATOM)) <> RawClassAtom then
      Covered := Covered or (GetWindowLong(W, GWL_STYLE) and WS_VISIBLE <> 0)
    else if not Covered then
      After := W
    else if GetWindowLong(W, GWL_STYLE) and WS_VISIBLE <> 0 then
    begin
      if N = Length(Under) then SetLength(Under, N + 16);
      Under[N] := W;
      Inc(N);
    end;
    W := GetWindow(W, GW_HWNDNEXT);
  end;
  for I := 0 to N - 1 do
  begin
    SetWindowPos(Under[I], After, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
    After := Under[I];
  end;
end;

procedure TFormDesigner.UpdateHelpers;
var
  I, K, N, HIdx, IIdx: Integer;
  Parent: HWND;
  C: TComponent;
  R: TRect;
  H: TGrabHandle;
  Icon: TCompIcon;
  Single: Boolean;
  P: TPersistent;
  X, Y: Integer;
  At: TPoint;
  CapDC: HDC;
  OldFont: HFONT;

  function NextHandle: TGrabHandle;
  begin
    if HIdx < FHandles.Count then
      Result := TGrabHandle(FHandles[HIdx])
    else
    begin
      Result := TGrabHandle.Create(Parent);
      Result.FDesigner := Self;
      FHandles.Add(Result);
    end;
    Inc(HIdx);
  end;

  procedure PlaceHandle(Kind: Integer; Target: TPersistent; const Rc: TRect; Active: Boolean);
  begin
    case Kind of
      0, 6, 7: X := Rc.Left - HandleSize div 2;
      1, 5: X := (Rc.Left + Rc.Right - HandleSize) div 2;
    else
      X := Rc.Right - HandleSize div 2 - 1;
    end;
    case Kind of
      0, 1, 2: Y := Rc.Top - HandleSize div 2;
      3, 7: Y := (Rc.Top + Rc.Bottom - HandleSize) div 2;
    else
      Y := Rc.Bottom - HandleSize div 2 - 1;
    end;
    H := NextHandle;
    H.FTarget := Target;
    H.FKind := Kind;
    H.SetBounds(X, Y, HandleSize, HandleSize);
    { its pixels depend on FActive only: a handle that moves takes them along }
    if H.FActive <> Active then
    begin
      H.FActive := Active;
      H.Invalidate;
    end;
    H.SetVisible(True);
  end;

begin
  if FDestroying or (FForm = nil) or not FForm.HandleAllocated then Exit;
  { a drag that moves or sizes controls leaves the form where it is: the positioner is not
    placed again at each step (EndLive updates it when the drag ends) }
  if not (FMode in [mmMove, mmSize]) then UpdatePositioner;
  ClipFormChildren(FForm);
  Parent := FForm.Handle;
  if Parent <> FHelperParent then
  begin
    ClearHelpers;
    FHelperParent := Parent;
  end;
  { non-visual component tiles }
  IIdx := 0;
  for I := 0 to FRoot.ComponentCount - 1 do
  begin
    C := FRoot.Components[I];
    if not IsNonVisual(C) then Continue;
    if IIdx < FIcons.Count then
      Icon := TCompIcon(FIcons[IIdx])
    else
    begin
      Icon := TCompIcon.Create(Parent);
      Icon.FDesigner := Self;
      FIcons.Add(Icon);
    end;
    Inc(IIdx);
    if Icon.FComponent <> C then
    begin
      Icon.FComponent := C;
      Icon.Invalidate;
    end;
    At := DesignPos(C);
    Icon.SetBounds(At.X, At.Y, IconSize, IconSize);
    Icon.SetVisible(True);
    { the name: centred under the tile, 2 px below it (Delphi 7, "Show component captions") }
    if DesignEnv.ShowCaptions and (C.Name <> '') then
    begin
      if Icon.FCaption = nil then
      begin
        Icon.FCaption := TCompCaption.Create(Parent);
        Icon.FCaption.FDesigner := Self;
        Icon.FCaption.FIcon := Icon;
      end;
      { measured when the name or the font changes, not at each update }
      if (Icon.FCaption.FText <> C.Name) or (Icon.FCaption.FFont <> UIFont.Handle) then
      begin
        Icon.FCaption.FText := C.Name;
        Icon.FCaption.FFont := UIFont.Handle;
        CapDC := GetDC(0);
        OldFont := SelectObject(CapDC, Icon.FCaption.FFont);
        GetTextExtentPoint32(CapDC, PChar(C.Name), Length(C.Name), Icon.FCaption.FSize);
        SelectObject(CapDC, OldFont);
        ReleaseDC(0, CapDC);
        Icon.FCaption.Invalidate;
      end;
      with Icon.FCaption.FSize do
        Icon.FCaption.SetBounds(At.X + (IconSize - cx) div 2, At.Y + IconSize + 2, cx, cy);
      Icon.FCaption.SetVisible(True);
    end
    else if Icon.FCaption <> nil then
      FreeAndNil(Icon.FCaption);
  end;
  while FIcons.Count > IIdx do
  begin
    TObject(FIcons[FIcons.Count - 1]).Free;
    FIcons.Delete(FIcons.Count - 1);
  end;
  { grab handles - hidden while a drag moves or sizes the selection, they come back where the
    drag put it: moved at every step, each showed at its old place too until the form painted }
  if FMode in [mmMove, mmSize] then
  begin
    for I := 0 to FHandles.Count - 1 do TGrabHandle(FHandles[I]).SetVisible(False);
    KeepHelpersOnTop(Parent);
    StageShown;
    Exit;
  end;
  HIdx := 0;
  N := 0;
  for I := 0 to FSelection.Count - 1 do
  begin
    P := TPersistent(FSelection[I]);
    if (P is TControl) and (P <> FForm) then Inc(N)
    else if (P is TComponent) and IsNonVisual(TComponent(P)) then Inc(N);
  end;
  Single := N = 1;
  for I := 0 to FSelection.Count - 1 do
  begin
    P := TPersistent(FSelection[I]);
    if (P is TControl) and (P <> FForm) then
    begin
      R := ControlRectInRoot(TControl(P));
      if Single then
        for K := 0 to 7 do PlaceHandle(K, P, R, True)
      else
        for K := 0 to 3 do PlaceHandle(2 * K, P, R, False);     // the corners
    end
    else if (P is TComponent) and IsNonVisual(TComponent(P)) then
    begin
      At := DesignPos(TComponent(P));
      R := Bounds(At.X, At.Y, IconSize, IconSize);
      for K := 0 to 3 do PlaceHandle(2 * K, P, R, False);
    end;
  end;
  while FHandles.Count > HIdx do
  begin
    TObject(FHandles[FHandles.Count - 1]).Free;
    FHandles.Delete(FHandles.Count - 1);
  end;
  KeepHelpersOnTop(Parent);
  StageShown;
end;

procedure TFormDesigner.ShowOutline(Index: Integer; const R: TRect);
begin
  if Index >= MaxOutlines then Exit;
  while FOutlines.Count <= Index do
    FOutlines.Add(TFrameRect.Create(FForm.Handle));
  TFrameRect(FOutlines[Index]).SetRect(R);
end;

procedure TFormDesigner.HideOutlines;
var
  I: Integer;
begin
  for I := 0 to FOutlines.Count - 1 do TFrameRect(FOutlines[I]).Hide;
  for I := 0 to FSnapLines.Count - 1 do TSnapLineWnd(FSnapLines[I]).SetVisible(False);
end;

{ --- snap lines: R in the container's client coordinates; Horz the x axis (Lo/Hi = left/right),
  else the y axis; MoveLo/MoveHi which of R's edges move (both: the rectangle moves) }

{ the other controls of the container that snap lines come from: the root's, not selected }
function SnapSibling(D: TFormDesigner; Parent: TWinControl; I: Integer; out SR: TRect): Boolean;
var
  S: TControl;
begin
  S := Parent.Controls[I];
  Result := (S.Owner = D.FRoot) and not D.IsSelected(S);
  if Result then SR := S.BoundsRect;
end;

procedure AxisOf(const R: TRect; Horz: Boolean; out Lo, Hi, OLo, OHi: Integer);
begin
  if Horz then
  begin
    Lo := R.Left; Hi := R.Right; OLo := R.Top; OHi := R.Bottom;
  end
  else
  begin
    Lo := R.Top; Hi := R.Bottom; OLo := R.Left; OHi := R.Right;
  end;
end;

function ContainerSize(Parent: TWinControl; Horz: Boolean): Integer;
begin
  if Horz then Result := Parent.ClientWidth else Result := Parent.ClientHeight;
end;

{ the nearest line within DesignEnv.SnapDistance of a moving edge: Delta takes the edge onto it }
function TFormDesigner.SnapAxis(Parent: TWinControl; const R: TRect; Horz, MoveLo, MoveHi: Boolean;
  var Delta: Integer): Boolean;
var
  Lo, Hi, OLo, OHi, SLo, SHi, SOLo, SOHi, I, Best: Integer;
  SR: TRect;

  procedure Consider(Edge, Line: Integer);
  begin
    if Abs(Line - Edge) < Abs(Best) then Best := Line - Edge;
  end;

begin
  Result := False;
  if (Parent = nil) or not DesignEnv.SnapLines then Exit;
  AxisOf(R, Horz, Lo, Hi, OLo, OHi);
  Best := MaxInt;
  if MoveLo then Consider(Lo, DesignEnv.SnapMargin);
  if MoveHi then Consider(Hi, ContainerSize(Parent, Horz) - DesignEnv.SnapMargin);
  for I := 0 to Parent.ControlCount - 1 do
    if SnapSibling(Self, Parent, I, SR) then
    begin
      AxisOf(SR, Horz, SLo, SHi, SOLo, SOHi);
      if MoveLo then Consider(Lo, SLo);
      if MoveHi then Consider(Hi, SHi);
      if (SOLo < OHi) and (OLo < SOHi) then        // beside it: the spacing
      begin
        if MoveLo then Consider(Lo, SHi + DesignEnv.SnapSpacing);
        if MoveHi then Consider(Hi, SLo - DesignEnv.SnapSpacing);
      end;
    end;
  Result := Abs(Best) <= DesignEnv.SnapDistance;
  if Result then Delta := Best;
end;

{ the lines R's moving edges lie on, in root coordinates: an edge shared with another control
  across both, a spacing or a margin across the gap }
procedure TFormDesigner.AddSnapLines(Parent: TWinControl; const R: TRect; Horz, MoveLo, MoveHi: Boolean);
var
  Lo, Hi, OLo, OHi, SLo, SHi, SOLo, SOHi, I, Size: Integer;
  SR: TRect;
  O: TPoint;

  { a line across the axis at Pos from A to B (along the other axis), or along it }
  procedure Add(Across: Boolean; Pos, A, B: Integer);
  var
    L: TRect;
    T: Integer;
  begin
    if B < A then begin T := A; A := B; B := T; end;
    if Across = Horz then L := Rect(Pos, A, Pos + 1, B) else L := Rect(A, Pos, B, Pos + 1);
    OffsetRect(L, O.X, O.Y);
    SetLength(FLineRects, Length(FLineRects) + 1);
    FLineRects[High(FLineRects)] := L;
  end;

  function Mid(A1, B1, A2, B2: Integer): Integer;   // the middle of the overlap
  begin
    Result := (Max(A1, A2) + Min(B1, B2)) div 2;
  end;

begin
  if Parent = nil then Exit;
  if Parent = FForm then O := Point(0, 0)
  else
  begin
    O := Parent.ClientToScreen(Point(0, 0));
    Dec(O.X, RootOrigin.X);
    Dec(O.Y, RootOrigin.Y);
  end;
  AxisOf(R, Horz, Lo, Hi, OLo, OHi);
  Size := ContainerSize(Parent, Horz);
  if MoveLo and (Lo = DesignEnv.SnapMargin) then Add(False, (OLo + OHi) div 2, 0, Lo);
  if MoveHi and (Hi = Size - DesignEnv.SnapMargin) then Add(False, (OLo + OHi) div 2, Hi, Size);
  for I := Parent.ControlCount - 1 downto 0 do
    if SnapSibling(Self, Parent, I, SR) then
    begin
      AxisOf(SR, Horz, SLo, SHi, SOLo, SOHi);
      if MoveLo and (Lo = SLo) then Add(True, Lo, Min(OLo, SOLo), Max(OHi, SOHi));
      if MoveHi and (Hi = SHi) then Add(True, Hi - 1, Min(OLo, SOLo), Max(OHi, SOHi));
      if (SOLo < OHi) and (OLo < SOHi) then
      begin
        if MoveLo and (Lo = SHi + DesignEnv.SnapSpacing) then Add(False, Mid(OLo, OHi, SOLo, SOHi), SHi, Lo);
        if MoveHi and (Hi = SLo - DesignEnv.SnapSpacing) then Add(False, Mid(OLo, OHi, SOLo, SOHi), Hi, SLo);
      end;
    end;
end;

{ mmMove: the dragged controls of one container snap together, by their joint bounds where the
  drag began; where no line is near, each snaps to the grid as before. The tiles of non-visual
  components lie on no snap line: they move by the controls' offset }
procedure TFormDesigner.MoveSnap(DX, DY: Integer);
var
  I, D: Integer;
  C: TControl;
  Parent: TWinControl;
  U, R: TRect;
begin
  FMoveSnapX := False;
  FMoveSnapY := False;
  SetLength(FLineRects, 0);
  Parent := nil;
  for I := 0 to FDragged.Count - 1 do
  begin
    if not (TObject(FDragged[I]) is TControl) then Break;    // the tiles follow the controls
    C := TControl(FDragged[I]);
    if I = 0 then
    begin
      Parent := C.Parent;
      U := FDragFrom[0];
    end
    else if C.Parent <> Parent then
      Exit
    else
      UnionRect(U, U, FDragFrom[I]);
  end;
  if Parent = nil then Exit;
  OffsetRect(U, DX, DY);
  FMoveDelta := Point(DX, DY);
  if SnapAxis(Parent, U, True, True, True, D) then
  begin
    FMoveSnapX := True;
    Inc(FMoveDelta.X, D);
  end;
  if SnapAxis(Parent, U, False, True, True, D) then
  begin
    FMoveSnapY := True;
    Inc(FMoveDelta.Y, D);
  end;
  { the joint bounds where they end up: on the lines, or the grid's place of the first }
  R := U;
  OffsetRect(R, -DX, -DY);
  OffsetRect(R, FMoveDelta.X, FMoveDelta.Y);
  if not FMoveSnapX then OffsetRect(R, SnapX(R.Left) - R.Left, 0);
  if not FMoveSnapY then OffsetRect(R, 0, SnapY(R.Top) - R.Top);
  if FMoveSnapX then AddSnapLines(Parent, R, True, True, True);
  if FMoveSnapY then AddSnapLines(Parent, R, False, True, True);
end;

{ where the dragged control or tile Index goes (MoveSnap first) }
function TFormDesigner.MovedTo(Index, DX, DY: Integer): TPoint;
var
  R: TRect;
begin
  R := FDragFrom[Index];
  if FMoveSnapX then Result.X := R.Left + FMoveDelta.X else Result.X := SnapX(R.Left + DX);
  if FMoveSnapY then Result.Y := R.Top + FMoveDelta.Y else Result.Y := SnapY(R.Top + DY);
end;

{ a mouse message's point on the screen. During a drag the mouse is the form's (SetCapture), so a
  message to another window was posted to it: one to the window that was pressed carries the
  positions of the place that window had at the press - it may have moved with the drag since }
function TFormDesigner.MessagePoint(Wnd: HWND; X, Y: Integer): TPoint;
begin
  if (FMode <> mmNone) and (Wnd = FPressWnd) and (Wnd <> MouseOwner) then
    Result := Point(FPressOrigin.X + X, FPressOrigin.Y + Y)
  else
  begin
    Result := Point(X, Y);
    Windows.ClientToScreen(Wnd, Result);
  end;
end;

procedure TFormDesigner.PressAt(Wnd: HWND);
begin
  FPressWnd := Wnd;
  FPressOrigin := Point(0, 0);
  if Wnd <> 0 then Windows.ClientToScreen(Wnd, FPressOrigin);
end;

{ a dragged control's bounds in its parent, a non-visual component's tile's in the root }
function DraggedBounds(P: Pointer): TRect;
var
  At: TPoint;
begin
  if TObject(P) is TControl then
    Result := TControl(P).BoundsRect
  else
  begin
    At := DesignPos(TComponent(P));
    Result := Bounds(At.X, At.Y, IconSize, IconSize);
  end;
end;

{ a dragged control or tile to R (DraggedBounds' coordinates), when it is not there }
procedure PlaceDragged(P: Pointer; const R: TRect);
begin
  if EqualRect(DraggedBounds(P), R) then Exit;
  if TObject(P) is TControl then
    TControl(P).SetBounds(R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top)
  else
    SetDesignPos(TComponent(P), R.Left, R.Top);
end;

{ The controls themselves move (mmMove: the selected ones, with the tiles of the selected
  non-visual components) or change size (mmSize: FSizeTarget) while the mouse drags them; every
  step places them from their bounds when the drag began. Their containers paint through a
  buffer meanwhile (DoubleBuffered, which the form file does not store): a control moved on a
  themed tab sheet was drawn over the ground the sheet had just painted on the screen, and was
  missing in between }
procedure TFormDesigner.BeginLive(Mode: TDesignMouseMode);
var
  I: Integer;
  C: TControl;

  { the containers the VCL paints itself (TWinControl.WMPaint's buffer works for them); a
    comctl32 control painted through it lost part of its face (a themed button) }
  procedure Buffer(W: TWinControl);
  begin
    if (W <> nil) and ((W is TCustomControl) or (W is TTabSheet) or (W is TScrollingWinControl)) and
      not W.DoubleBuffered and (FBuffered.IndexOf(W) < 0) then
    begin
      W.DoubleBuffered := True;
      FBuffered.Add(W);
    end;
  end;

  { a dragged container and the containers in it: a sized one aligns them again at every step,
    and each repainted whole on the screen - the pages of a page control flickered }
  procedure BufferTree(W: TWinControl);
  var
    K: Integer;
  begin
    Buffer(W);
    for K := 0 to W.ControlCount - 1 do
      if W.Controls[K] is TWinControl then BufferTree(TWinControl(W.Controls[K]));
  end;

begin
  FDragged.Clear;
  if Mode = mmSize then
  begin
    if FSizeTarget <> nil then FDragged.Add(FSizeTarget);
  end
  else
  begin
    { the controls first (MoveSnap takes them), then the tiles }
    for I := 0 to FSelection.Count - 1 do
      if (TObject(FSelection[I]) is TControl) and (FSelection[I] <> FForm) then FDragged.Add(FSelection[I]);
    for I := 0 to FSelection.Count - 1 do
      if (TObject(FSelection[I]) is TComponent) and IsNonVisual(TComponent(FSelection[I])) then
        FDragged.Add(FSelection[I]);
  end;
  SetLength(FDragFrom, FDragged.Count);
  for I := 0 to FDragged.Count - 1 do
  begin
    FDragFrom[I] := DraggedBounds(FDragged[I]);
    if TObject(FDragged[I]) is TControl then
    begin
      C := TControl(FDragged[I]);
      Buffer(C.Parent);
      if C is TWinControl then BufferTree(TWinControl(C));
    end;
  end;
  FMode := Mode;
end;

{ mmMove / mmSize: the dragged controls and tiles where the mouse at ScreenPt puts them,
  snapped; the selection's handles and the snap lines with them, a sized control's box }
procedure TFormDesigner.PlaceLive(const ScreenPt: TPoint);
var
  I, DX, DY: Integer;
  R: TRect;
  P, Back: TPoint;
begin
  if FDragged.Count = 0 then Exit;
  DX := ScreenPt.X - FStartPt.X;
  DY := ScreenPt.Y - FStartPt.Y;
  if FMode = mmSize then
  begin
    { a handle pressed and not moved changes nothing (its edges would go onto the grid) }
    if (DX = 0) and (DY = 0) then
    begin
      SetLength(FLineRects, 0);
      R := FDragFrom[0];
    end
    else
      R := SizedBounds(DX, DY);
    PlaceDragged(FDragged[0], R);
    { a box on the sized control's bounds, the rubber band's frame: a child of the form, so a
      parent that clips the control does not hide it; MouseUpAt / CancelDrag hide it }
    ShowOutline(0, ControlRectInRoot(FSizeTarget));
  end
  else
  begin
    MoveSnap(DX, DY);
    { the tiles never go left of or above the form: they stop there together, keeping their
      arrangement }
    Back := Point(0, 0);
    for I := 0 to FDragged.Count - 1 do
      if not (TObject(FDragged[I]) is TControl) then
      begin
        P := MovedTo(I, DX, DY);
        Back.X := Max(Back.X, -P.X);
        Back.Y := Max(Back.Y, -P.Y);
      end;
    for I := 0 to FDragged.Count - 1 do
    begin
      P := MovedTo(I, DX, DY);
      if not (TObject(FDragged[I]) is TControl) then
      begin
        Inc(P.X, Back.X);
        Inc(P.Y, Back.Y);
      end;
      R := FDragFrom[I];
      OffsetRect(R, P.X - R.Left, P.Y - R.Top);
      PlaceDragged(FDragged[I], R);
    end;
  end;
  UpdateHelpers;
  ShowSnapLines;
  PaintStep;
end;

{ a step of a drag on the screen at once: left to the queue, the places the controls, tiles and
  handles left kept their old pixels until the form's next paint (a handle showed twice) }
procedure TFormDesigner.PaintStep;
begin
  if (FForm <> nil) and FForm.HandleAllocated then
    RedrawWindow(FForm.Handle, nil, 0, RDW_UPDATENOW or RDW_ALLCHILDREN);
  StageShown(True);
end;

{ the end of a move or a sizing. Keep: the controls and tiles stay where the drag put them - one
  change (one undo step); else they go back where they were }
procedure TFormDesigner.EndLive(Keep: Boolean);
var
  I: Integer;
  Changed: Boolean;
begin
  Changed := False;
  for I := 0 to FDragged.Count - 1 do
    if not Keep then PlaceDragged(FDragged[I], FDragFrom[I])
    else if not EqualRect(DraggedBounds(FDragged[I]), FDragFrom[I]) then Changed := True;
  FDragged.Clear;
  SetLength(FDragFrom, 0);
  for I := 0 to FBuffered.Count - 1 do TWinControl(FBuffered[I]).DoubleBuffered := False;
  FBuffered.Clear;
  if Changed then Modified;
  UpdateHelpers;
end;

{ a component that goes during a drag: the drag no longer places it, nor gives it its buffer back }
procedure TFormDesigner.ForgetDragged(AnObject: TPersistent);
var
  I, K: Integer;
begin
  I := FDragged.IndexOf(AnObject);
  if I >= 0 then
  begin
    FDragged.Delete(I);
    for K := I to High(FDragFrom) - 1 do FDragFrom[K] := FDragFrom[K + 1];
    SetLength(FDragFrom, Length(FDragFrom) - 1);
  end;
  FBuffered.Remove(AnObject);
end;

procedure TFormDesigner.ShowSnapLines;
var
  I: Integer;
  W: TSnapLineWnd;
begin
  for I := 0 to High(FLineRects) do
  begin
    if I >= MaxOutlines then Break;
    if FSnapLines.Count <= I then FSnapLines.Add(TSnapLineWnd.Create(FForm.Handle));
    W := TSnapLineWnd(FSnapLines[I]);
    with FLineRects[I] do W.SetBounds(Left, Top, Right - Left, Bottom - Top);
    W.SetVisible(True);
  end;
  for I := Length(FLineRects) to FSnapLines.Count - 1 do TSnapLineWnd(FSnapLines[I]).SetVisible(False);
end;

procedure TFormDesigner.RefreshGrid;
begin
  if (FForm <> nil) and FForm.HandleAllocated then FForm.Invalidate;
  StageShown;
end;

{ ---------------------------------------------------------------- form positioner }

procedure TFormDesigner.UpdatePositioner;
var
  Want: Boolean;
begin
  Want := DesignEnv.ShowPositioner and (FHostKind = hkForm) and (FForm <> nil) and not FDestroying and
    (FSurface <> nil) and (FSurface.Parent <> nil);
  if not Want then
  begin
    if FPositioner <> nil then FPositioner.Visible := False;
    Exit;
  end;
  if FPositioner = nil then
  begin
    FPositioner := TFormPositioner.Create(nil);
    FPositioner.Visible := False;
    FPositioner.OnMoved := PositionerMoved;
    FPositioner.Parent := FSurface.Parent;
  end;
  FPositioner.Snap := DesignEnv.PositionerSnap;
  { the designed position (TSdDesignForm's Left and Top), not the window's place on the stage }
  FPositioner.SetForm(FForm.Left, FForm.Top, FForm.Width, FForm.Height, FForm.Position, FForm.Color);
  PlacePositioner;
end;

{ over the client area of the view shown - inside its border and scroll bars -, at its lower
  right: the surface's, the zoomed view's at another zoom (the surface under it has scroll bars of
  its own for the stage at 100 %); on top of it (a sibling: it does not scroll with the stage) }
procedure TFormDesigner.PlacePositioner;
var
  R: TRect;
  View: TWinControl;
begin
  if (FPositioner = nil) or (FSurface = nil) or not FSurface.HandleAllocated or
    (FSurface.Parent = nil) or not FSurface.Parent.HandleAllocated then Exit;
  if not DesignEnv.ShowPositioner or (FHostKind <> hkForm) or (FForm = nil) then
  begin
    FPositioner.Visible := False;
    Exit;
  end;
  if Zoomed and FZoomView.HandleAllocated then View := FZoomView else View := FSurface;
  Windows.GetClientRect(View.Handle, R);
  MapWindowPoints(View.Handle, FSurface.Parent.Handle, R, 2);
  if FPositioner.PlaceIn(R) then
  begin
    FPositioner.Visible := True;
    if FPositioner.HandleAllocated and (GetWindow(FPositioner.Handle, GW_HWNDPREV) <> 0) then
      FPositioner.BringToFront;
  end
  else
    FPositioner.Visible := False;
end;

{ the form's miniature dropped (or a monitor double-clicked): the form opens there, with the
  Position the positioner chose (poScreenCenter when it was snapped to the primary monitor's
  centre, else poDesigned unless poDefaultSizeOnly keeps Left and Top already); one change, one
  undo step }
procedure TFormDesigner.PositionerMoved(Sender: TObject; ALeft, ATop: Integer; APosition: TPosition);
begin
  if (FForm = nil) or FLoading or FDestroying then Exit;
  FForm.Left := ALeft;
  FForm.Top := ATop;
  if FForm.Position <> APosition then FForm.Position := APosition;
  Modified;
end;

function TFormDesigner.PositionerText: string;
begin
  if (FPositioner = nil) or not FPositioner.Visible then
    Result := '0'
  else
    Result := '1|' + FPositioner.TestText + '|' + GetEnumName(TypeInfo(TPosition), Ord(FForm.Position));
end;

procedure TFormDesigner.FocusSurface;
begin
  if (FSurface <> nil) and FSurface.CanFocus and not FSurface.Focused then
    try
      FSurface.SetFocus;
    except
    end;
end;

{ ---------------------------------------------------------------- selection }

function TFormDesigner.GetSelection(Index: Integer): TPersistent;
begin
  Result := TPersistent(FSelection[Index]);
end;

function TFormDesigner.SelectionCount: Integer;
begin
  Result := FSelection.Count;
end;

function TFormDesigner.IsSelected(Item: TPersistent): Boolean;
begin
  Result := FSelection.IndexOf(Item) >= 0;
end;

procedure TSdSourceBridge.SelectionChanged;
begin
end;

function TSdSourceBridge.FrameDfms(const AClassName: string; Dfms: TStrings): Boolean;
begin
  Result := False;
end;

procedure TSdSourceBridge.ChainCall(const MethodName, InstancePath, InstanceMethod: string;
  TypeData: PTypeData);
begin
end;

procedure TFormDesigner.SelectionChanged;
var
  Sel: IDesignerSelections;
  I: Integer;
begin
  UpdateHelpers;
  if FDestroying then Exit;
  if FForm <> nil then FForm.UpdateMenuBar;
  if Assigned(DesignEnv.OnSelectionChanged) then DesignEnv.OnSelectionChanged(Self);
  if FBridge <> nil then FBridge.SelectionChanged;
  Sel := TDesignerSelections.Create;
  for I := 0 to FSelection.Count - 1 do Sel.Add(TPersistent(FSelection[I]));
  DesignHost.NotifySelectionChanged(Self, Sel);
end;

{ the components changed: the inspector's instance list is made again at once (every removal
  reported on its own made deleting n components take n times n) }
procedure TFormDesigner.StructureChanged;
begin
  if FDestroying or FLoading or (FBatch > 0) then Exit;
  if Assigned(DesignEnv.OnStructureChanged) then DesignEnv.OnStructureChanged(Self);
end;

procedure TFormDesigner.Select(Item: TPersistent; Add: Boolean);
var
  I: Integer;
begin
  { a custom module's instance stands for the root (the collection editor of its Dependencies
    selects it when it closes) }
  if (Item = nil) or (Item = FModule) then Item := FRoot;
  if Add then
  begin
    I := FSelection.IndexOf(Item);
    if I >= 0 then
      FSelection.Delete(I)
    else
    begin
      { the root never takes part in a multiple selection }
      FSelection.Remove(FRoot);
      if Item <> FRoot then FSelection.Add(Item);
    end;
    if FSelection.Count = 0 then FSelection.Add(FRoot);
  end
  else
  begin
    if (FSelection.Count = 1) and (FSelection[0] = Item) then
    begin
      UpdateHelpers;
      Exit;
    end;
    FSelection.Clear;
    FSelection.Add(Item);
  end;
  SelectionChanged;
end;

procedure TFormDesigner.SelectList(List: TList);
var
  I: Integer;
  P: Pointer;
begin
  FSelection.Clear;
  for I := 0 to List.Count - 1 do
  begin
    P := List[I];
    if (P <> nil) and (P = FModule) then P := FRoot;
    if FSelection.IndexOf(P) < 0 then FSelection.Add(P);
  end;
  if FSelection.Count = 0 then FSelection.Add(FRoot);
  SelectionChanged;
end;

procedure TFormDesigner.SelectAll;
var
  I: Integer;
  L: TList;
  C: TComponent;
begin
  L := TList.Create;
  try
    for I := 0 to FRoot.ComponentCount - 1 do
    begin
      C := FRoot.Components[I];
      if ((C is TControl) and (TControl(C).Parent = FForm)) or IsNonVisual(C) then L.Add(C);
    end;
    SelectList(L);
  finally
    L.Free;
  end;
end;

{ ---------------------------------------------------------------- mouse }

function TFormDesigner.DragRect(const ScreenPt: TPoint): TRect;
var
  O: TPoint;
begin
  O := RootOrigin;
  Result.Left := FStartPt.X - O.X;
  Result.Top := FStartPt.Y - O.Y;
  Result.Right := ScreenPt.X - O.X;
  Result.Bottom := ScreenPt.Y - O.Y;
  if Result.Right < Result.Left then
  begin
    O.X := Result.Left; Result.Left := Result.Right; Result.Right := O.X;
  end;
  if Result.Bottom < Result.Top then
  begin
    O.Y := Result.Top; Result.Top := Result.Bottom; Result.Bottom := O.Y;
  end;
end;

procedure TFormDesigner.MouseDownOn(Sender: TControl; const ScreenPt: TPoint; Shift: TShiftState);
var
  C: TControl;
begin
  FocusSurface;
  C := DesignControlOf(Sender);
  FStartPt := ScreenPt;
  if ssShift in Shift then
  begin
    if C <> FForm then Select(C, True);
    FMode := mmNone;
    Exit;
  end
  else if (C = FForm) or (ssCtrl in Shift) then
  begin
    FDragContainer := ContainerFor(C);
    if C = FForm then Select(FForm);
    FMode := mmRubber;
  end
  else
  begin
    if not IsSelected(C) then Select(C);
    if FLocked then
    begin
      FMode := mmNone;
      Exit;
    end;
    FMode := mmMovePending;
  end;
  SetCapture(FForm.Handle);
end;

procedure TFormDesigner.MouseMoveTo(const ScreenPt: TPoint);
begin
  case FMode of
    mmMovePending:
      if (Abs(ScreenPt.X - FStartPt.X) > 3) or (Abs(ScreenPt.Y - FStartPt.Y) > 3) then
      begin
        BeginLive(mmMove);
        MouseMoveTo(ScreenPt);
      end;
    mmMove, mmSize:
      PlaceLive(ScreenPt);
    mmRubber:
      ShowOutline(0, DragRect(ScreenPt));
    mmFormSize:
      SizeFormTo(ScreenPt);
  end;
end;

procedure TFormDesigner.MouseUpAt(const ScreenPt: TPoint);
var
  Mode: TDesignMouseMode;
begin
  { the controls and tiles go where the button went up }
  if FMode in [mmMove, mmSize] then MouseMoveTo(ScreenPt);
  Mode := FMode;
  FMode := mmNone;
  if GetCapture <> 0 then ReleaseCapture;
  HideOutlines;
  case Mode of
    mmMove, mmSize: EndLive(True);
    mmRubber: FinishRubber(ScreenPt);
    mmFormSize:
      begin
        SizeFormTo(ScreenPt);
        if (FForm.Width <> FFormSize.X) or (FForm.Height <> FFormSize.Y) then Modified;
      end;
  end;
end;

{ Esc, another window took the mouse, the object went: the drag ends without a change - moved
  or sized controls, moved tiles and a sized form go back to what they were. CaptureLost: the
  mouse is another window's now (WM_CAPTURECHANGED) - releasing it would take it from that
  window }
procedure TFormDesigner.CancelDrag(CaptureLost: Boolean);
var
  Mode: TDesignMouseMode;
begin
  if FMode <> mmNone then
  begin
    Mode := FMode;
    FMode := mmNone;
    if not CaptureLost and (GetCapture <> 0) then ReleaseCapture;
    HideOutlines;
    case Mode of
      mmFormSize: SetFormSize(FFormSize.X, FFormSize.Y);
      mmMove, mmSize: EndLive(False);
    end;
  end;
end;

{ The right and bottom edges of the form size it - the designer does it, not Windows' sizing
  loop: that keeps the pointer inside the parent's client area, and the stage around the form
  leaves only StageMargin (the form could not grow). The stage grows with the form; positions
  come from the mouse messages. }
procedure TFormDesigner.BeginFormSize(Hit: Integer; const ScreenPt: TPoint);
begin
  if not IsSelected(FForm) then Select(FForm);
  FFormHit := Hit;
  FFormSize := Point(FForm.Width, FForm.Height);
  FStartPt := ScreenPt;
  FMode := mmFormSize;
  SetCapture(FForm.Handle);
end;

{ With Snap to grid the client area grows and shrinks in grid steps - what the .dfm stores and
  where the grid's dots end; the frame (caption, borders, a design-time menu bar) comes on top }
procedure TFormDesigner.SizeFormTo(const ScreenPt: TPoint);
var
  W, H, FW, FH: Integer;
begin
  FW := FForm.Width - FForm.ClientWidth;
  FH := FForm.Height - FForm.ClientHeight;
  W := FFormSize.X;
  H := FFormSize.Y;
  if FFormHit in [HTRIGHT, HTBOTTOMRIGHT] then W := SnapX(W + ScreenPt.X - FStartPt.X - FW) + FW;
  if FFormHit in [HTBOTTOM, HTBOTTOMRIGHT] then H := SnapY(H + ScreenPt.Y - FStartPt.Y - FH) + FH;
  SetFormSize(W, H);
end;

{ the window's size (the designed Left/Top are not the window's place); the stage follows }
procedure TFormDesigner.SetFormSize(W, H: Integer);
begin
  if (FForm = nil) or not FForm.HandleAllocated then Exit;
  if W < GetSystemMetrics(SM_CXMINTRACK) then W := GetSystemMetrics(SM_CXMINTRACK);
  if H < GetSystemMetrics(SM_CYMINTRACK) then H := GetSystemMetrics(SM_CYMINTRACK);
  if (W = FForm.Width) and (H = FForm.Height) then Exit;
  SetWindowPos(FForm.Handle, 0, 0, 0, W, H, SWP_NOMOVE or SWP_NOZORDER or SWP_NOACTIVATE);
  StageChanged;
end;

{ mmSize: the bounds the mouse moved by DX, DY gives FSizeTarget, in its parent's coordinates,
  from its bounds when the sizing began }
function TFormDesigner.SizedBounds(DX, DY: Integer): TRect;
var
  D: Integer;
  C: TControl;
  L, T, R, B: Integer;
  Parent: TWinControl;
  MoveL, MoveR, MoveT, MoveB, SnappedX, SnappedY: Boolean;
begin
  C := FSizeTarget;
  L := FDragFrom[0].Left; T := FDragFrom[0].Top; R := FDragFrom[0].Right; B := FDragFrom[0].Bottom;
  { the moving edges: onto a snap line within reach, else onto the grid }
  MoveL := FSizeKind in [0, 6, 7];
  MoveR := FSizeKind in [2, 3, 4];
  MoveT := FSizeKind in [0, 1, 2];
  MoveB := FSizeKind in [4, 5, 6];
  if MoveL then Inc(L, DX);
  if MoveR then Inc(R, DX);
  if MoveT then Inc(T, DY);
  if MoveB then Inc(B, DY);
  SetLength(FLineRects, 0);
  Parent := nil;
  if C <> FForm then Parent := C.Parent;
  SnappedX := SnapAxis(Parent, Rect(L, T, R, B), True, MoveL, MoveR, D);
  if SnappedX then
    if MoveL then Inc(L, D) else Inc(R, D)
  else
    if MoveL then L := SnapX(L) else if MoveR then R := SnapX(R);
  SnappedY := SnapAxis(Parent, Rect(L, T, R, B), False, MoveT, MoveB, D);
  if SnappedY then
    if MoveT then Inc(T, D) else Inc(B, D)
  else
    if MoveT then T := SnapY(T) else if MoveB then B := SnapY(B);
  if SnappedX then AddSnapLines(Parent, Rect(L, T, R, B), True, MoveL, MoveR);
  if SnappedY then AddSnapLines(Parent, Rect(L, T, R, B), False, MoveT, MoveB);
  if R < L + 1 then
    if FSizeKind in [0, 6, 7] then L := R - 1 else R := L + 1;
  if B < T + 1 then
    if FSizeKind in [0, 1, 2] then T := B - 1 else B := T + 1;
  Result := Rect(L, T, R, B);
end;

{ A handle's press sizes the control; the mouse is the form's while it lasts (the handles move
  with the control's edges) }
procedure TFormDesigner.HandleDrag(Handle: TObject; Msg: Cardinal; const ScreenPt: TPoint);
var
  H: TGrabHandle;
begin
  H := TGrabHandle(Handle);
  case Msg of
    WM_LBUTTONDOWN:
      begin
        FocusSurface;
        if not H.FActive or FLocked or not (H.FTarget is TControl) then Exit;
        FSizeTarget := TControl(H.FTarget);
        FSizeKind := H.FKind;
        FStartPt := ScreenPt;
        SetCapture(FForm.Handle);
        BeginLive(mmSize);
      end;
    WM_MOUSEMOVE:
      if FMode = mmSize then MouseMoveTo(ScreenPt);
    WM_LBUTTONUP:
      if FMode = mmSize then MouseUpAt(ScreenPt);
  end;
end;

procedure TFormDesigner.IconMouse(Icon: TObject; Msg: Cardinal; const ScreenPt: TPoint; Shift: TShiftState);
var
  Ic: TCompIcon;
  C: TComponent;
  O: TPoint;
begin
  Ic := TCompIcon(Icon);
  C := Ic.FComponent;
  case Msg of
    WM_LBUTTONDOWN:
      begin
        FocusSurface;
        if ssShift in Shift then
          Select(C, True)
        else
        begin
          if not IsSelected(C) then Select(C);
          if not FLocked then
          begin
            { the selection - this tile, the other selected tiles and controls - moves with the
              mouse, which is the form's while it lasts (a tile that moves would report its
              positions from its new place) }
            FStartPt := ScreenPt;
            SetCapture(FForm.Handle);
            FMode := mmMovePending;
          end;
        end;
      end;
    WM_MOUSEMOVE:
      if FMode in [mmMovePending, mmMove] then MouseMoveTo(ScreenPt);
    WM_LBUTTONUP:
      if FMode in [mmMovePending, mmMove] then MouseUpAt(ScreenPt);
    WM_LBUTTONDBLCLK:
      begin
        CancelDrag;
        EditComponent(C);
      end;
    WM_RBUTTONDOWN:
      begin
        FocusSurface;
        if not IsSelected(C) then Select(C);
      end;
    WM_RBUTTONUP:
      if Assigned(DesignEnv.OnContextMenu) then
      begin
        O := ScreenPoint(ScreenPt);           // the menu where the pointer is
        DesignEnv.OnContextMenu(Self, O);
      end;
  end;
end;

procedure TFormDesigner.FinishRubber(const ScreenPt: TPoint);
var
  R, CR, X: TRect;
  At: TPoint;
  L: TList;
  I: Integer;
  C: TControl;
begin
  R := DragRect(ScreenPt);
  if (R.Right - R.Left < 3) and (R.Bottom - R.Top < 3) then
  begin
    if FDragContainer <> nil then Select(FDragContainer) else Select(FForm);
    Exit;
  end;
  L := TList.Create;
  try
    if FDragContainer = nil then FDragContainer := FForm;
    for I := 0 to FDragContainer.ControlCount - 1 do
    begin
      C := FDragContainer.Controls[I];
      if C.Owner <> FRoot then Continue;
      CR := ControlRectInRoot(C);
      if IntersectRect(X, CR, R) then L.Add(C);
    end;
    if FDragContainer = FForm then
      for I := 0 to FRoot.ComponentCount - 1 do
        if IsNonVisual(FRoot.Components[I]) then
        begin
          At := DesignPos(FRoot.Components[I]);
          CR := Bounds(At.X, At.Y, IconSize, IconSize);
          if IntersectRect(X, CR, R) then L.Add(FRoot.Components[I]);
        end;
    if L.Count > 0 then SelectList(L) else Select(FDragContainer);
  finally
    L.Free;
  end;
end;

function TFormDesigner.HandleMouse(Sender: TControl; var Message: TMessage): Boolean;
var
  P, SP: TPoint;
  Shift: TShiftState;
  HitTest: Boolean;
  C: TControl;
begin
  Result := True;
  P := SmallPointToPoint(TWMMouse(Message).Pos);
  { a control without a window gets the message of its parent's window, converted to its place
    as it is now: its screen point does not depend on that place }
  if Sender is TWinControl then
  begin
    if Message.Msg = WM_LBUTTONDOWN then PressAt(TWinControl(Sender).Handle);
    SP := MessagePoint(TWinControl(Sender).Handle, P.X, P.Y);
  end
  else
  begin
    if Message.Msg = WM_LBUTTONDOWN then PressAt(0);
    SP := Sender.ClientToScreen(P);
  end;
  Shift := KeysToShiftState(TWMMouse(Message).Keys);
  HitTest := (FMode = mmNone) and (Sender.Perform(CM_DESIGNHITTEST, Message.WParam, Message.LParam) <> 0);
  if Message.Msg <> WM_MOUSEMOVE then HideDesignHint
  else if FMode = mmNone then TrackDesignHint(DesignControlOf(Sender), SP)
  else HideDesignHint;
  case Message.Msg of
    WM_LBUTTONDOWN:
      begin
        { a tool chosen on the palette goes where the click is, as in Delphi - also on a control
          that takes clicks itself }
        if Assigned(PaletteToolHook) and PaletteToolHook(Self, ScreenPoint(SP), Shift) then Exit;
        if HitTest then
        begin
          { the control wants the click itself (page-control tabs, splitters, ...) }
          C := DesignControlOf(Sender);
          if not IsSelected(C) then Select(C);
          Result := False;
          Exit;
        end;
        MouseDownOn(Sender, SP, Shift);
      end;
    WM_LBUTTONDBLCLK:
      begin
        CancelDrag;
        C := DesignControlOf(Sender);
        if not IsSelected(C) then Select(C);
        EditComponent(C);
      end;
    WM_MOUSEMOVE:
      if FMode <> mmNone then
        MouseMoveTo(SP)
      else if HitTest then
        Result := False;
    WM_LBUTTONUP:
      if FMode <> mmNone then
        MouseUpAt(SP)
      else if HitTest then
        Result := False;
    WM_RBUTTONDOWN:
      begin
        CancelDrag;
        FocusSurface;
        C := DesignControlOf(Sender);
        if not IsSelected(C) then Select(C);
      end;
    WM_RBUTTONUP:
      if Assigned(DesignEnv.OnContextMenu) then DesignEnv.OnContextMenu(Self, ScreenPoint(SP));
  end;
end;

{ a wheel turn over the designed form, the stage, the surface or the zoomed view: with the zoom key
  (SdZoom) a step of the zoom a notch, the point under the pointer staying where it is; else the
  surface scrolls three lines a notch - a touch pad's parts of a notch add up (UIWheelSteps) -, by
  WM_VSCROLL messages posted to it (not inside the designed control's message), and the zoomed view
  as many of its lines (Shift: sideways) }
procedure TFormDesigner.Wheel(Keys, WheelDelta: Integer; const ScreenPt: TPoint);
var
  N: Integer;
  Code: Word;
  V: TDesignZoomView;
begin
  if (FSurface = nil) or not FSurface.HandleAllocated then Exit;
  if ZoomByWheel(Self, FWheelZoom, WheelZoomsKeys(Keys), WheelDelta, ScreenPt) then Exit;
  if Zoomed then
  begin
    V := TDesignZoomView(FZoomView);
    N := UIWheelSteps(FWheel, WheelDelta, 3 * ZoomLine);
    if Keys and MK_SHIFT <> 0 then V.ScrollTo(V.FOrigin.X - N, V.FOrigin.Y)
    else V.ScrollTo(V.FOrigin.X, V.FOrigin.Y - N);
    Exit;
  end;
  N := UIWheelSteps(FWheel, WheelDelta, 3);
  if N > 0 then Code := SB_LINEUP else Code := SB_LINEDOWN;
  while N <> 0 do
  begin
    PostMessage(FSurface.Handle, WM_VSCROLL, MakeWParam(Code, 0), 0);
    if N > 0 then Dec(N) else Inc(N);
  end;
end;

{ ---------------------------------------------------------------- the zoom }

function TFormDesigner.Zoomed: Boolean;
begin
  Result := (FZoom <> 100) and (FZoomView <> nil) and FZoomView.Visible;
end;

function TFormDesigner.LivePoint(const ScreenPt: TPoint): TPoint;
var
  V: TDesignZoomView;
  P: TPoint;
begin
  Result := ScreenPt;
  if not Zoomed or not FZoomView.HandleAllocated then Exit;
  V := TDesignZoomView(FZoomView);
  P := V.ScreenToClient(ScreenPt);
  if not PtInRect(V.ClientRect, P) then
  begin
    Result := Point(-32000, -32000);
    Exit;
  end;
  Result := V.LiveAt(P.X, P.Y);
end;

function TFormDesigner.ScreenPoint(const LivePt: TPoint): TPoint;
var
  V: TDesignZoomView;
begin
  Result := LivePt;
  if not Zoomed or not FZoomView.HandleAllocated then Exit;
  V := TDesignZoomView(FZoomView);
  Windows.ScreenToClient(FSurface.FStage.Handle, Result);
  Result := V.ClientToScreen(V.ClientPoint(Result));
end;

function TFormDesigner.MouseOwner: HWND;
begin
  if Zoomed and (TDesignZoomView(FZoomView).FCapture <> 0) then
    Result := TDesignZoomView(FZoomView).FCapture
  else
    Result := GetCapture;
end;

procedure TFormDesigner.StageShown(Now: Boolean);
begin
  if not Zoomed then Exit;
  if Now then TDesignZoomView(FZoomView).RenderNow else TDesignZoomView(FZoomView).RenderLater;
end;

{ Value (ZoomMin .. ZoomMax); the point of the stage at At (the screen; else the middle of the view)
  stays where it is. 100 %: the surface shows the stage again, scrolled so; another zoom: the zoomed
  view over the surface. A drag ends first }
procedure TFormDesigner.SetZoom(Value: Integer; AtPoint: Boolean; const At: TPoint);
var
  V: TDesignZoomView;
  A, S: TPoint;
begin
  if (FSurface = nil) or not FSurface.HandleAllocated or FDestroying or (FForm = nil) then Exit;
  Value := Max(ZoomMin, Min(Value, ZoomMax));
  if Value = FZoom then Exit;
  if AtPoint then A := FSurface.ScreenToClient(At)
  else A := Point(FSurface.ClientWidth div 2, FSurface.ClientHeight div 2);
  if Zoomed then S := TDesignZoomView(FZoomView).StagePoint(A.X, A.Y)
  else S := FSurface.FStage.ScreenToClient(FSurface.ClientToScreen(A));
  CancelDrag;
  HideDesignHint;
  FZoom := Value;
  if Value = 100 then
  begin
    if FZoomView <> nil then
    begin
      { a mouse the view still held for the stage goes with it }
      TDesignZoomView(FZoomView).FCapture := 0;
      if FZoomView.HandleAllocated and (GetCapture = FZoomView.Handle) then ReleaseCapture;
      FZoomView.Visible := False;
    end;
    FSurface.HorzScrollBar.Position := S.X - A.X;
    FSurface.VertScrollBar.Position := S.Y - A.Y;
    PlacePositioner;                 // back over the surface
  end
  else
  begin
    if FZoomView = nil then
    begin
      V := TDesignZoomView.Create(nil);
      V.FDesigner := Self;
      V.Visible := False;
      V.Parent := FSurface.Parent;
      V.Align := alClient;
      FZoomView := V;
    end;
    V := TDesignZoomView(FZoomView);
    V.FOrigin := Point(MulDiv(S.X, Value, 100) - A.X, MulDiv(S.Y, Value, 100) - A.Y);
    if not V.Visible then
    begin
      V.Visible := True;
      V.BringToFront;
    end;
    V.Render;
    V.UpdateScrollBars;
    V.Invalidate;
    PlacePositioner;                 // over the view
  end;
  ZoomChanged(Self);
end;

function TFormDesigner.ZoomPercent: Integer;
begin
  Result := FZoom;
end;

function TFormDesigner.CanZoom(Delta: Integer): Boolean;
begin
  Result := (FForm <> nil) and CanStepZoom(FZoom, Delta, ZoomMin, ZoomMax);
end;

procedure TFormDesigner.ZoomStep(Delta: Integer; AtPoint: Boolean; const At: TPoint);
begin
  SetZoom(ZoomPercentStep(FZoom, Delta, ZoomMin, ZoomMax), AtPoint, At);
end;

{ 100 % (Reset Zoom): the surface back at its top left too }
procedure TFormDesigner.ZoomTo(Percent: Integer);
begin
  SetZoom(Percent, False, Point(0, 0));
  if Percent = 100 then ScrollHome;
end;

procedure TFormDesigner.ScrollHome;
begin
  if Zoomed then TDesignZoomView(FZoomView).ScrollTo(0, 0)
  else if (FSurface <> nil) and FSurface.HandleAllocated then
  begin
    FSurface.HorzScrollBar.Position := 0;
    FSurface.VertScrollBar.Position := 0;
  end;
end;

function TFormDesigner.CanZoomFit: Boolean;
begin
  Result := FForm <> nil;
end;

{ the whole stage - the form and the margin around it - in the view, from its top left }
procedure TFormDesigner.ZoomFit;
var
  W, H, Z: Integer;
begin
  if (FForm = nil) or (FSurface = nil) or not FSurface.HandleAllocated then Exit;
  W := FSurface.Width;
  H := FSurface.Height;
  if FSurface.FBordered then
  begin
    Dec(W, 2);
    Dec(H, 2);
  end;
  if (FSurface.FStage.Width <= 0) or (FSurface.FStage.Height <= 0) or (W <= 0) or (H <= 0) then Exit;
  Z := Min(W * 100 div FSurface.FStage.Width, H * 100 div FSurface.FStage.Height);
  SetZoom(Z, True, FSurface.ClientToScreen(Point(0, 0)));
  ScrollHome;
end;

function TFormDesigner.ZoomState: string;
var
  V: TDesignZoomView;
begin
  Result := Format('%d|%d', [FZoom, Ord(Zoomed)]);
  if not Zoomed then
  begin
    if FSurface <> nil then
      Result := Result + Format('|surface %d,%d', [FSurface.HorzScrollBar.Position, FSurface.VertScrollBar.Position]);
    Exit;
  end;
  V := TDesignZoomView(FZoomView);
  Result := Result + Format('|%d,%d|%dx%d|%dx%d|%d', [V.FOrigin.X, V.FOrigin.Y, V.ClientWidth,
    V.ClientHeight, FSurface.FStage.Width, FSurface.FStage.Height, Ord(V.FCapture <> 0)]);
end;

function TFormDesigner.IsDesignMsg(Sender: TControl; var Message: TMessage): Boolean;
var
  Hit: Integer;
  MenuItem: TMenuItem;
begin
  Result := False;
  if FDestroying or (FForm = nil) or (Sender = nil) then Exit;
  try
    case Message.Msg of
      WM_LBUTTONDOWN, WM_LBUTTONDBLCLK, WM_LBUTTONUP, WM_MOUSEMOVE, WM_RBUTTONDOWN, WM_RBUTTONUP,
      WM_RBUTTONDBLCLK, WM_MBUTTONDOWN, WM_MBUTTONUP, WM_MBUTTONDBLCLK:
        if not FLoading then Result := HandleMouse(Sender, Message);
      WM_KEYDOWN, WM_KEYUP, WM_CHAR, WM_SYSKEYDOWN, WM_SYSKEYUP, WM_SYSCHAR:
        Result := True;
      WM_CONTEXTMENU:
        Result := True;
      WM_SETCURSOR:
        if LoWord(Message.LParam) = HTCLIENT then
        begin
          Windows.SetCursor(LoadCursor(0, IDC_ARROW));
          Message.Result := 1;
          Result := True;
        end;
      WM_SETFOCUS:
        if (Sender is TWinControl) and (FSurface <> nil) and FSurface.HandleAllocated then
        begin
          { designed controls never keep the keyboard focus }
          Windows.SetFocus(FSurface.Handle);
          Result := True;
        end;
      WM_WINDOWPOSCHANGING:
        if (Sender <> FForm) and (Sender is TWinControl) then
        begin
          FPosWnd := TWinControl(Sender).Handle;
          GetWindowRect(FPosWnd, FPosOld);
        end;
      WM_WINDOWPOSCHANGED:
        begin
          PostUpdateHelpers;
          if (Sender <> FForm) and (Sender is TWinControl) then
            GroundChanged(TWinControl(Sender), TWMWindowPosChanged(Message).WindowPos^.flags);
        end;
      WM_ERASEBKGND:
        if Sender = FForm then
        begin
          { PaintGrid paints the background with the grid in one fill. A control drawn on the
            form's background asks with a DC of its own (a transparent tool bar - it was black): it
            gets the grid there, the form's colour where it lies over another control (the form's
            own buffer comes with WParam = LParam: TWinControl.WMPaint) }
          if WindowFromDC(HDC(Message.WParam)) <> FForm.Handle then
          begin
            PaintGridTo(HDC(Message.WParam));
            if Message.WParam <> Message.LParam then PlainOverSiblings(HDC(Message.WParam));
          end;
          Message.Result := 1;
          Result := True;
        end
        else if (Sender is TWinControl) and (FBuffered.IndexOf(Sender) >= 0) and
          (WindowFromDC(HDC(Message.WParam)) = TWinControl(Sender).Handle) then
        begin
          { a container buffered for a drag paints its ground into the buffer (TWinControl.WMPaint):
            a themed one would draw it on the screen first, and a moved control vanished meanwhile }
          Message.Result := 1;
          Result := True;
        end;
      WM_PRINTCLIENT:
        if Sender = FForm then
        begin
          { the second half of a control's request for the form's ground (DrawThemeParentBackground:
            WM_ERASEBKGND, then this): the VCL paints the form into it - grid and graphic
            controls -, then the parts over another control get the form's colour }
          FForm.Dispatch(Message);
          PlainOverSiblings(HDC(Message.WParam));
          Result := True;
        end;
      WM_NCLBUTTONDOWN, WM_NCLBUTTONDBLCLK:
        if Sender = FForm then
        begin
          Hit := Message.WParam;
          FocusSurface;
          if Hit = HTMENU then
          begin
            { a title of the design-time menu bar: select that menu item; a double-click on an
              item without sub-items goes to its OnClick handler }
            MenuItem := FForm.BarItemAt(Point(TWMNCHitMessage(Message).XCursor,
              TWMNCHitMessage(Message).YCursor));
            if MenuItem <> nil then
            begin
              Select(MenuItem);
              if (Message.Msg = WM_NCLBUTTONDBLCLK) and (MenuItem.Count = 0) then EditComponent(MenuItem);
            end
            else if FForm.Menu <> nil then
              Select(FForm.Menu)
            else
              Select(FForm);
            Result := True;
          end
          else if Hit in [HTCAPTION, HTSYSMENU, HTCLOSE, HTMINBUTTON, HTMAXBUTTON, HTHELP] then
          begin
            Select(FForm);
            Result := True;
          end
          else if FLocked then
            Result := True
          else if Hit in [HTRIGHT, HTBOTTOM, HTBOTTOMRIGHT] then
          begin
            if Message.Msg = WM_NCLBUTTONDOWN then
              BeginFormSize(Hit, Point(TWMNCHitMessage(Message).XCursor, TWMNCHitMessage(Message).YCursor));
            Result := True;
          end;
        end;
      WM_CAPTURECHANGED:
        { another window took the mouse during a drag (the designer's own release comes after
          the drag has ended); it keeps it. The zoomed view takes it for the form: the drag goes on }
        if (Sender = FForm) and (FMode <> mmNone) and (HWND(Message.LParam) <> FForm.Handle) and
          not ((FZoomView <> nil) and FZoomView.HandleAllocated and (HWND(Message.LParam) = FZoomView.Handle)) then
          CancelDrag(True);
      WM_NCRBUTTONDOWN:
        if Sender = FForm then
        begin
          { as a right click in the client area: the context menu's edit commands act where the
            keyboard is }
          FocusSurface;
          Select(FForm);
          Result := True;
        end;
      WM_NCRBUTTONUP:
        if Sender = FForm then
        begin
          if Assigned(DesignEnv.OnContextMenu) then
            DesignEnv.OnContextMenu(Self, ScreenPoint(Point(TWMNCHitMessage(Message).XCursor,
              TWMNCHitMessage(Message).YCursor)));
          Result := True;
        end;
      WM_SYSCOMMAND:
        if Sender = FForm then
          case Message.WParam and $FFF0 of
            SC_SIZE: ;
          else
            Result := True;
          end;
      WM_CLOSE:
        if Sender = FForm then Result := True;
      WM_EXITSIZEMOVE:
        if Sender = FForm then
        begin
          StageChanged;
          Modified;
        end;
      WM_MOUSEWHEEL:
        if FSurface.HandleAllocated then
        begin
          with TWMMouseWheel(Message) do Wheel(Keys, WheelDelta, Point(XPos, YPos));
          Result := True;
        end;
    end;
  except
    Application.HandleException(Self);
    Result := True;
  end;
end;

{ The designed control at a screen point (the zoomed view's place at another zoom): found from the
  form's own controls (WindowFromPoint would miss a cloaked test instance), inside the visible part
  of the design surface. }
function TFormDesigner.ControlAtScreen(const ScreenPt: TPoint): TControl;
begin
  Result := ControlAtLive(LivePoint(ScreenPt));
end;

{ ... at the stage's own place on the screen; the zoomed view shows only what is in view of it }
function TFormDesigner.ControlAtLive(const LivePt: TPoint): TControl;
var
  R: TRect;
  W: TWinControl;
  C: TControl;
begin
  Result := nil;
  if (FForm = nil) or not FForm.HandleAllocated or (FSurface = nil) or not FSurface.HandleAllocated then Exit;
  if not Zoomed then
  begin
    GetWindowRect(FSurface.Handle, R);
    if not PtInRect(R, LivePt) then Exit;
  end;
  GetWindowRect(FForm.Handle, R);
  if not PtInRect(R, LivePt) then Exit;
  Result := FForm;
  W := FForm;
  repeat
    C := W.ControlAtPos(W.ScreenToClient(LivePt), True, True);
    if C = nil then Break;
    Result := C;
    if not (C is TWinControl) then Break;
    W := TWinControl(C);
  until False;
end;

{ where a drop at LivePt (the stage's own place) goes: the container of the designed control there,
  and the point in it (not left of or above it); False: no designed control there, or new
  components may not go there (MayAddTo says so) }
function TFormDesigner.DropPlace(const LivePt: TPoint; out Cont: TWinControl; out P: TPoint): Boolean;
var
  T: TControl;
begin
  Result := False;
  T := ControlAtLive(LivePt);
  if (T = nil) or not MayAddTo(T) then Exit;
  Cont := ContainerFor(T);
  P := Cont.ScreenToClient(LivePt);
  if P.X < 0 then P.X := 0;
  if P.Y < 0 then P.Y := 0;
  Result := True;
end;

{ the component in its default size at the point, in the container there (as a click with the
  component chosen in Delphi's palette) }
function TFormDesigner.DropText(const Text: string; const ScreenPt: TPoint): Boolean;
var
  Cont: TWinControl;
  P: TPoint;
begin
  Result := False;
  if not DropPlace(LivePoint(ScreenPt), Cont, P) then Exit;
  Select(Cont);
  PasteText(ShiftTemplateText(Text, SnapX(P.X), SnapY(P.Y)));
  FocusSurface;
  Result := True;
end;

function TFormDesigner.DropComponent(AClass: TComponentClass; const ScreenPt: TPoint): Boolean;
var
  Cont: TWinControl;
  P: TPoint;
  C: TComponent;
begin
  Result := False;
  if (AClass = nil) or not DropPlace(LivePoint(ScreenPt), Cont, P) then Exit;
  C := AddComponent(AClass, Cont, SnapX(P.X), SnapY(P.Y), 0, 0);
  if C = nil then Exit;
  Select(C);
  FocusSurface;
  Result := True;
end;

function TFormDesigner.FramePlaceable(Drop: Boolean; const ScreenPt: TPoint): Boolean;
var
  T: TControl;
begin
  Result := False;
  if (FRoot = nil) or not AcceptsClass(TFrame) then Exit;
  if Drop then
  begin
    T := ControlAtScreen(ScreenPt);
    if (T = nil) or not MayAddTo(T) then Exit;
  end
  else if PasteIntoFrame then
  begin
    RefuseFrameAdd;
    Exit;
  end;
  Result := True;
end;

{ the selected component is a placed frame's: a paste would go into the frame }
function TFormDesigner.PasteIntoFrame: Boolean;
begin
  Result := (FSelection.Count > 0) and (TObject(FSelection[0]) is TComponent) and
    InFrameInstance(TComponent(FSelection[0]));
end;

function TFormDesigner.PlaceFrame(const AClassName: string; Drop: Boolean; const ScreenPt: TPoint): Boolean;
var
  Name, Text: string;
begin
  Result := False;
  if (FRoot = nil) or not AcceptsClass(TFrame) or (FrameChain(AClassName) = nil) then Exit;
  Name := UniqueName(AClassName);
  Text := Format('inline %s: %s'#13#10'  Left = 0'#13#10'  Top = 0'#13#10'end'#13#10, [Name, AClassName]);
  if Drop then
  begin
    if not DropText(Text, ScreenPt) then Exit;
  end
  else
    PasteText(ShiftTemplateText(Text, 16, 16));
  Result := FRoot.FindComponent(Name) <> nil;
end;
{ The form's background and its grid in one fill: a pattern brush of one grid cell (the form's
  colour, the dot at its top left) tiled from the form's origin. The form is not erased first
  (IsDesignMsg answers its WM_ERASEBKGND): erasing and then setting the dots one by one showed
  the bare background on every step of a resize - the grid flickered. The brush origin follows
  the DC's viewport, so a themed control that has the form paint behind its corners gets the
  dots where they are on the form. }
procedure TFormDesigner.PaintGrid;
begin
  if FForm <> nil then PaintGridTo(FForm.Canvas.Handle);
end;

procedure TFormDesigner.PaintGridTo(DC: HDC);
var
  CellDC: HDC;
  R: TRect;
  GX, GY: Integer;
  Cell: HBITMAP;
  Old: HGDIOBJ;
  Br: HBRUSH;
  Org: TPoint;
begin
  if FForm = nil then Exit;
  GetClipBox(DC, R);
  GX := DesignEnv.GridX;
  GY := DesignEnv.GridY;
  if not DesignEnv.ShowGrid or (GX < 2) or (GY < 2) then
  begin
    UIFill(DC, R, FForm.Color);
    Exit;
  end;
  CellDC := CreateCompatibleDC(DC);
  Cell := CreateCompatibleBitmap(DC, GX, GY);
  Old := SelectObject(CellDC, Cell);
  UIFill(CellDC, Rect(0, 0, GX, GY), FForm.Color);
  SetPixelV(CellDC, 0, 0, ColorToRGB(clBtnText));
  SelectObject(CellDC, Old);
  DeleteDC(CellDC);
  Br := CreatePatternBrush(Cell);
  try
    GetViewportOrgEx(DC, Org);
    SetBrushOrgEx(DC, ((Org.X mod GX) + GX) mod GX, ((Org.Y mod GY) + GY) mod GY, nil);
    FillRect(DC, R, Br);
  finally
    DeleteObject(Br);
    DeleteObject(Cell);
  end;
end;

{ the form's own controls (no helper window: handles, tiles, lines), shown }
function IsFormControl(W: HWND): Boolean;
begin
  Result := IsWindowVisible(W) and (FindControl(W) <> nil);
end;

{ A control that asks for the form's ground with a DC of its own (DrawThemeParentBackground moves
  the DC's origin to the form's) gets the grid; where it lies over another control of the form,
  the form's colour instead, as there at run time: the grid's dots showed in the margin of a
  themed button and around a check box lying over a panel or a page control. The asking control
  is the window of the DC, or the form's control that window lies in; a DC of no window (a
  buffered paint) is the topmost control at the DC's origin. }
procedure TFormDesigner.PlainOverSiblings(DC: HDC);
var
  R, X: TRect;
  Asker, Wnd: HWND;
  VpOrg, WinOrg, P: TPoint;

  function RectInForm(W: HWND): TRect;
  begin
    GetWindowRect(W, Result);
    MapWindowPoints(0, FForm.Handle, Result, 2);
  end;

begin
  if (FForm = nil) or not FForm.HandleAllocated then Exit;
  if GetClipBox(DC, R) in [ERROR, NULLREGION] then Exit;     // the form's coordinates
  Asker := WindowFromDC(DC);
  while (Asker <> 0) and (GetParent(Asker) <> FForm.Handle) do Asker := GetParent(Asker);
  if Asker = 0 then
  begin
    GetViewportOrgEx(DC, VpOrg);
    GetWindowOrgEx(DC, WinOrg);
    P := Point(WinOrg.X - VpOrg.X, WinOrg.Y - VpOrg.Y);
    Wnd := GetWindow(FForm.Handle, GW_CHILD);
    while (Wnd <> 0) and (Asker = 0) do
    begin
      if IsFormControl(Wnd) and PtInRect(RectInForm(Wnd), P) then Asker := Wnd;
      Wnd := GetWindow(Wnd, GW_HWNDNEXT);
    end;
    if Asker = 0 then Exit;
  end;
  Wnd := GetWindow(FForm.Handle, GW_CHILD);
  while Wnd <> 0 do
  begin
    if (Wnd <> Asker) and IsFormControl(Wnd) and IntersectRect(X, RectInForm(Wnd), R) then
      UIFill(DC, X, FForm.Color);
    Wnd := GetWindow(Wnd, GW_HWNDNEXT);
  end;
end;

{ A designed control moved, changed its size or its place in the z-order, came or went
  (WM_WINDOWPOSCHANGED). Windows copies a moved window's pixels: the ground a control shows (a
  themed button's margin, a check box, a group box) would still be the one of its old place - it
  paints again, with its controls when its ground is its parent's (csParentBackground). And a
  control of the form lying over its old or its new place shows other ground now
  (PlainOverSiblings): it paints again too. }
procedure TFormDesigner.GroundChanged(W: TWinControl; Flags: UINT);
var
  A, R, Now: TRect;
  S: HWND;
  C: TWinControl;
  Moved: Boolean;

  { a control whose ground is its parent's draws it when it is erased, with its controls; any
    other one draws all of itself when painted - erased first on the screen, a themed button
    showed its ground without its face for a moment while it was dragged }
  procedure Repaint(Ctl: TWinControl);
  begin
    if csParentBackground in Ctl.ControlStyle then
      RedrawWindow(Ctl.Handle, nil, 0, RDW_INVALIDATE or RDW_ERASE or RDW_FRAME or RDW_ALLCHILDREN)
    else
      RedrawWindow(Ctl.Handle, nil, 0, RDW_INVALIDATE or RDW_FRAME);
  end;

begin
  GetWindowRect(W.Handle, Now);
  A := Now;
  { moved: its place changed - the VCL passes the place also when only the size changes (the
    pages of a page control at every step of its sizing: each repainted whole, it flickered) }
  Moved := Flags and SWP_NOMOVE = 0;
  if FPosWnd = W.Handle then
  begin
    Moved := (FPosOld.Left <> Now.Left) or (FPosOld.Top <> Now.Top);
    UnionRect(A, A, FPosOld);
    FPosWnd := 0;
  end;
  if Moved or (Flags and SWP_NOZORDER = 0) then Repaint(W);
  if (W.Parent <> FForm) or ((Flags and (SWP_NOMOVE or SWP_NOSIZE) = SWP_NOMOVE or SWP_NOSIZE) and
    (Flags and SWP_NOZORDER <> 0) and (Flags and (SWP_SHOWWINDOW or SWP_HIDEWINDOW) = 0)) then Exit;
  S := GetWindow(W.Handle, GW_HWNDPREV);
  while S <> 0 do
  begin
    C := FindControl(S);
    if (C <> nil) and IsWindowVisible(S) then
    begin
      GetWindowRect(S, R);
      if IntersectRect(R, R, A) then Repaint(C);
    end;
    S := GetWindow(S, GW_HWNDPREV);
  end;
end;

{ ---------------------------------------------------------------- keyboard }

function TFormDesigner.NeighbourOf(C: TControl; DX, DY: Integer): TControl;
var
  I, Along, Across, Score, Best: Integer;
  P1, P2: TPoint;
  K: TControl;
begin
  Result := nil;
  Best := MaxInt;
  P1 := C.ClientToScreen(Point(C.Width div 2, C.Height div 2));
  for I := 0 to FRoot.ComponentCount - 1 do
    if (FRoot.Components[I] is TControl) and (FRoot.Components[I] <> C) then
    begin
      K := TControl(FRoot.Components[I]);
      if K.Parent = nil then Continue;
      P2 := K.ClientToScreen(Point(K.Width div 2, K.Height div 2));
      Along := (P2.X - P1.X) * DX + (P2.Y - P1.Y) * DY;
      Across := Abs((P2.X - P1.X) * DY) + Abs((P2.Y - P1.Y) * DX);
      if Along <= 0 then Continue;
      Score := Along + 2 * Across;
      if Score < Best then
      begin
        Best := Score;
        Result := K;
      end;
    end;
end;

procedure TFormDesigner.KeyDown(var Key: Word; Shift: TShiftState);
var
  I, DX, DY: Integer;
  C: TControl;
  Any: Boolean;
  P: TPersistent;
  At: TPoint;
begin
  if FRoot = nil then Exit;
  case Key of
    VK_DELETE:
      begin
        DeleteSelected;
        Key := 0;
      end;
    VK_ESCAPE:
      begin
        if FMode <> mmNone then
          CancelDrag
        else if (FSelection.Count > 0) and (TObject(FSelection[0]) is TControl) and
          (TControl(FSelection[0]).Parent <> nil) and (FSelection[0] <> FForm) then
          Select(DesignControlOf(TControl(FSelection[0]).Parent))
        else
          Select(FRoot);
        Key := 0;
      end;
    VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN:
      begin
        DX := 0; DY := 0;
        case Key of
          VK_LEFT: DX := -1;
          VK_RIGHT: DX := 1;
          VK_UP: DY := -1;
          VK_DOWN: DY := 1;
        end;
        if (ssCtrl in Shift) or (ssShift in Shift) then
        begin
          if FLocked then Exit;
          Any := False;
          for I := 0 to FSelection.Count - 1 do
          begin
            P := TPersistent(FSelection[I]);
            if (P is TControl) and (P <> FForm) then
            begin
              C := TControl(P);
              if ssShift in Shift then
                C.SetBounds(C.Left, C.Top, C.Width + DX, C.Height + DY)
              else
                C.SetBounds(C.Left + DX, C.Top + DY, C.Width, C.Height);
              Any := True;
            end
            else if (P is TComponent) and IsNonVisual(TComponent(P)) and (ssCtrl in Shift) then
            begin
              At := DesignPos(TComponent(P));
              SetDesignPos(TComponent(P), At.X + DX, At.Y + DY);
              Any := True;
            end;
          end;
          if Any then
          begin
            Modified;
            UpdateHelpers;
          end;
        end
        else if (FSelection.Count > 0) and (TObject(FSelection[0]) is TControl) and
          (FSelection[0] <> FForm) then
        begin
          { the arrow keys alone select the nearest control in that direction }
          C := NeighbourOf(TControl(FSelection[0]), DX, DY);
          if C <> nil then Select(C);
        end;
        Key := 0;
      end;
    VK_TAB:
      begin
        { cycle through the components in creation order - from a placed frame's component on from
          its frame }
        if FRoot.ComponentCount > 0 then
        begin
          I := -1;
          if (FSelection.Count > 0) and (TObject(FSelection[0]) is TComponent) and (FSelection[0] <> FRoot) then
          begin
            P := TPersistent(FSelection[0]);
            while InFrameInstance(TComponent(P)) do P := TComponent(P).Owner;
            if TComponent(P).Owner = FRoot then I := TComponent(P).ComponentIndex;
          end;
          if ssShift in Shift then
          begin
            Dec(I);
            if I < 0 then I := FRoot.ComponentCount - 1;
          end
          else
          begin
            Inc(I);
            if I >= FRoot.ComponentCount then I := 0;
          end;
          Select(FRoot.Components[I]);
        end;
        Key := 0;
      end;
  end;
end;

{ ---------------------------------------------------------------- data module / frame hosting }

const
  { root properties of a hosted data module / frame that the design form can represent; the
    same lists filter the Object Inspector and the form file (SdEditorPage) }
  DataModuleRootProps: array[0..8] of string = ('Name', 'OldCreateOrder', 'Tag', 'OnCreate',
    'OnDestroy', 'Left', 'Top', 'Height', 'Width');
  FrameRootProps: array[0..27] of string = ('Name', 'Left', 'Top', 'ClientWidth', 'ClientHeight',
    'AutoScroll', 'Color', 'Ctl3D', 'Cursor', 'Enabled', 'Font', 'Hint', 'HorzScrollBar',
    'VertScrollBar', 'ParentFont', 'PopupMenu', 'ShowHint', 'Tag', 'OnClick', 'OnDblClick',
    'OnMouseDown', 'OnMouseMove', 'OnMouseUp', 'OnResize', 'OnContextPopup', 'OnCanResize',
    'OnConstrainedResize', 'OnMouseWheel');

function HostRootProp(Kind: THostKind; const AName: string): Boolean;
var
  I, P: Integer;
  Base: string;
begin
  Result := True;
  if Kind = hkForm then Exit;
  { 'Font.Style' is part of 'Font' }
  Base := AName;
  P := Pos('.', Base);
  if P > 0 then Base := Copy(Base, 1, P - 1);
  if Kind = hkDataModule then
  begin
    for I := Low(DataModuleRootProps) to High(DataModuleRootProps) do
      if SameText(DataModuleRootProps[I], Base) then Exit;
  end
  else
    for I := Low(FrameRootProps) to High(FrameRootProps) do
      if SameText(FrameRootProps[I], Base) then Exit;
  Result := False;
end;

function TFormDesigner.RootPropVisible(const AName: string): Boolean;
begin
  Result := HostRootProp(FHostKind, AName);
  { the place of a data module's design window is not a property of the module }
  if Result and (FHostKind = hkDataModule) then
    Result := not (SameText(AName, 'Left') or SameText(AName, 'Top') or SameText(AName, 'Height') or
      SameText(AName, 'Width'));
end;

{ ---------------------------------------------------------------- custom modules

  A custom module (RegisterCustomModule: dclstd70's TService) is a data module whose class has
  properties of its own. Delphi's designer root is an instance of the class; here the host form
  is the root, and an instance of the class (FModule) holds what the host does not represent: the
  Object Inspector shows its properties with the root's, the form text gets them back as Delphi
  writes a root of the class. }

type
  TModuleClass = class of TDataModule;

  { the names of the properties a component defines itself (DefineProperties: a data module's
    Left, Top, Height, HorizontalOffset ...): a filer that only lists them }
  TDefinedNames = class(TFiler)
  private
    FNames: TStrings;
  public
    procedure DefineProperty(const Name: string; ReadData: TReaderProc; WriteData: TWriterProc;
      HasData: Boolean); override;
    procedure DefineBinaryProperty(const Name: string; ReadData, WriteData: TStreamProc;
      HasData: Boolean); override;
    procedure FlushBuffer; override;
  end;

procedure TDefinedNames.DefineProperty(const Name: string; ReadData: TReaderProc; WriteData: TWriterProc;
  HasData: Boolean);
begin
  FNames.Add(Name);
end;

procedure TDefinedNames.DefineBinaryProperty(const Name: string; ReadData, WriteData: TStreamProc;
  HasData: Boolean);
begin
  FNames.Add(Name);
end;

procedure TDefinedNames.FlushBuffer;
begin
end;

{ an instance of the module class for the root AName: designing, nothing of it runs - and not
  among the Screen's data modules, where TDataModule.CreateNew puts it }
function TFormDesigner.NewModule(const AName: string): TComponent;
begin
  Result := TModuleClass(FModuleClass).CreateNew(nil, -1);
  try
    if Assigned(RemoveDataModule) then RemoveDataModule(TDataModule(Result));
    TComponentCracker(Result).SetDesigning(True);
    Result.Name := AName;
  except
    Result.Free;
    raise;
  end;
end;

{ DfmText without the root's properties that are the module's - its class's, published or
  defined by it, that the host does not represent (HostRootProp) -, which go into ModuleText as
  the form text of Module }
function TFormDesigner.SplitModule(const DfmText: string; Module: TComponent; var ModuleText: string): string;
var
  Names, Texts, Defined: TStringList;
  Filer: TDefinedNames;
  Header, Rest, N: string;
  I, P: Integer;
begin
  Names := TStringList.Create;
  Texts := TStringList.Create;
  Defined := TStringList.Create;
  try
    Filer := TDefinedNames.Create(nil, 0);
    try
      Filer.FNames := Defined;
      TComponentCracker(Module).DefineProperties(Filer);
    finally
      Filer.Free;
    end;
    SplitDfmRoot(DfmText, Header, Names, Texts, Rest);
    Result := Header + #13#10;
    ModuleText := 'object ' + Module.Name + ': ' + Module.ClassName + #13#10;
    for I := 0 to Names.Count - 1 do
    begin
      N := Names[I];
      P := Pos('.', N);
      if P > 0 then N := Copy(N, 1, P - 1);
      if not HostRootProp(FHostKind, N) and ((GetPropInfo(Module, N) <> nil) or (Defined.IndexOf(N) >= 0)) then
        ModuleText := ModuleText + Texts[I] + #13#10
      else
        Result := Result + Texts[I] + #13#10;
    end;
    ModuleText := ModuleText + 'end'#13#10;
    Result := Result + Rest + #13#10;
  finally
    Defined.Free;
    Texts.Free;
    Names.Free;
  end;
end;

{ the lines of the root's properties as the module writes them: all (ModuleRootText), or those the
  host does not write itself (SaveToText). The host's values of what it represents go into the
  module first - its OnCreate and OnDestroy only while it is written: a module that is freed
  calls its OnDestroy. The handlers' names are the root's methods (the writer's lookup root). }
function TFormDesigner.ModuleLines(All: Boolean): string;
var
  M: TDataModule;
  Bin: TMemoryStream;
  W: TWriter;
  Names, Texts: TStringList;
  Header, Rest: string;
  I: Integer;
begin
  Result := '';
  if (FModule = nil) or (FForm = nil) then Exit;
  M := TDataModule(FModule);
  M.Name := FRoot.Name;
  M.Tag := FForm.Tag;
  M.OldCreateOrder := FForm.OldCreateOrder;
  SetDesignPos(M, FForm.Left, FForm.Top);
  M.DesignSize := Point(FForm.Width, FForm.Height);
  Bin := TMemoryStream.Create;
  Names := TStringList.Create;
  Texts := TStringList.Create;
  try
    M.OnCreate := FForm.OnCreate;
    M.OnDestroy := FForm.OnDestroy;
    try
      W := TWriter.Create(Bin, 4096);
      try
        W.Root := FRoot;
        W.WriteSignature;
        W.WriteComponent(M);
      finally
        W.Free;
      end;
    finally
      M.OnCreate := nil;
      M.OnDestroy := nil;
    end;
    Bin.Position := 0;
    SplitDfmRoot(FormText(Bin), Header, Names, Texts, Rest);
    for I := 0 to Names.Count - 1 do
      if All or not HostRootProp(FHostKind, Names[I]) then Result := Result + Texts[I] + #13#10;
  finally
    Texts.Free;
    Names.Free;
    Bin.Free;
  end;
end;

function TFormDesigner.ModuleRootText: string;
begin
  Result := ModuleLines(True);
end;

{ ---------------------------------------------------------------- component management }

function TFormDesigner.UniqueName(const BaseName: string): string;
var
  Base: string;
  I: Integer;
begin
  Base := ComponentDisplayName(BaseName);
  I := 1;
  repeat
    Result := Base + IntToStr(I);
    Inc(I);
  until (FRoot.FindComponent(Result) = nil) and not SameText(Result, FRoot.Name);
end;

{ a data module holds non-visual components only; a refused class beeps }
function TFormDesigner.AcceptsClass(AClass: TComponentClass): Boolean;
begin
  Result := (FHostKind <> hkDataModule) or (AClass = nil) or not AClass.InheritsFrom(TControl);
  if not Result then MessageBeep(MB_ICONASTERISK);
end;

function TFormDesigner.AddComponent(AClass: TComponentClass; AParent: TComponent;
  ALeft, ATop, AWidth, AHeight: Integer): TComponent;
var
  C: TComponent;
  Ctl: TControl;
  ParentCtl: TWinControl;
  P: TPoint;
begin
  Result := nil;
  if (FRoot = nil) or not AcceptsClass(AClass) then Exit;
  if (AParent <> nil) and not MayAddTo(AParent) then Exit;
  C := AClass.Create(FRoot);
  try
    C.Name := UniqueName(AClass.ClassName);
    if C is TControl then
    begin
      Ctl := TControl(C);
      if AParent is TWinControl then ParentCtl := TWinControl(AParent) else ParentCtl := FForm;
      if not (csAcceptsControls in ParentCtl.ControlStyle) and (ParentCtl <> FForm) then
        ParentCtl := ContainerFor(ParentCtl);
      Ctl.Parent := ParentCtl;
      if AWidth <= 0 then AWidth := Ctl.Width;
      if AHeight <= 0 then AHeight := Ctl.Height;
      Ctl.SetBounds(ALeft, ATop, AWidth, AHeight);
    end
    else
    begin
      { the icon lies on the form: a place in a container (a drop onto a panel) in the form's
        coordinates }
      if (AParent is TWinControl) and (AParent <> FForm) and TWinControl(AParent).HandleAllocated and
        FForm.HandleAllocated then
      begin
        P := FForm.ScreenToClient(TWinControl(AParent).ClientToScreen(Point(ALeft, ATop)));
        ALeft := P.X;
        ATop := P.Y;
      end;
      if ALeft < 0 then ALeft := 0;
      if ATop < 0 then ATop := 0;
      SetDesignPos(C, ALeft, ATop);
    end;
  except
    C.Free;
    raise;
  end;
  Result := C;
  FLateAdds.Remove(C);
  if not FLoading then
  begin
    FBridge.ComponentAdded(C);
    DesignHost.NotifyItemInserted(Self, C);
    Modified;
    StructureChanged;
    PostUpdateHelpers;
  end;
end;

{ C (perhaps freed already) is still one of the root's components; compared as a pointer }
function TFormDesigner.RootOwns(C: TComponent): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FRoot.ComponentCount - 1 do
    if FRoot.Components[I] = C then
    begin
      Result := True;
      Exit;
    end;
end;

procedure TFormDesigner.DeleteSelected;
var
  L: TList;
  I: Integer;
  P: TPersistent;
  C: TComponent;
begin
  L := TList.Create;
  try
    for I := 0 to FSelection.Count - 1 do
    begin
      P := TPersistent(FSelection[I]);
      if (P is TComponent) and (P <> FRoot) and IsDesigned(TComponent(P)) then
      begin
        { Delphi's rule: what an ancestor form introduced stays (a message, not an error) - a
          placed frame's components too (inherited from the frame) }
        if csAncestor in TComponent(P).ComponentState then
        begin
          MessageBox(GetActiveWindow, PChar(Format('Selection contains a component, %s, introduced in an ' +
            'ancestor form which cannot be deleted.', [TComponent(P).Name])), 'Delete', MB_OK or MB_ICONERROR);
          Exit;
        end;
        L.Add(P);
      end;
    end;
    if L.Count = 0 then Exit;
    CancelDrag;
    { the Object Inspector and the design windows let go of the components before they are
      freed: Modified below refreshes the inspector's values }
    FSelection.Clear;
    FSelection.Add(FRoot);
    SelectionChanged;
    { a component freed earlier may have taken others along (a panel its controls, a menu its
      items, a dataset its fields): those are no longer the root's - a test by pointer only, it
      never touches a freed object, and it holds for every root (a data module reports no
      Notification). The inspector has the root's rows already: the structure is reported once,
      below }
    Inc(FBatch);
    try
      for I := 0 to L.Count - 1 do
      begin
        C := TComponent(L[I]);
        if RootOwns(C) then C.Free;
      end;
    finally
      Dec(FBatch);
    end;
  finally
    L.Free;
  end;
  Modified;
  StructureChanged;
end;

procedure TFormDesigner.Notification(AnObject: TPersistent; Operation: TOperation);
var
  I: Integer;
  WasSelected: Boolean;
begin
  if FDestroying or (FRoot = nil) then Exit;
  if Operation = opRemove then
  begin
    I := FSelection.IndexOf(AnObject);
    WasSelected := I >= 0;
    if WasSelected then
    begin
      FSelection.Delete(I);
      if FSelection.Count = 0 then FSelection.Add(FRoot);
    end;
    FLateAdds.Remove(AnObject);
    if FHintTarget = AnObject then HideDesignHint;
    ForgetDragged(AnObject);
    { a move, a sizing or a rubber band ends with the object it works on (the others go back) }
    if WasSelected or (FSizeTarget = AnObject) or (FDragContainer = AnObject) then
      CancelDrag;
    if FSizeTarget = AnObject then FSizeTarget := nil;
    if FDragContainer = AnObject then FDragContainer := nil;
    for I := 0 to FHandles.Count - 1 do
      if TGrabHandle(FHandles[I]).FTarget = AnObject then
      begin
        TGrabHandle(FHandles[I]).FTarget := nil;
        TGrabHandle(FHandles[I]).SetVisible(False);
      end;
    for I := FIcons.Count - 1 downto 0 do
      if TCompIcon(FIcons[I]).FComponent = AnObject then
      begin
        TObject(FIcons[I]).Free;
        FIcons.Delete(I);
      end;
    { a component that goes while components are read (a paste that failed) was never
      announced: neither the unit nor the packages hear of it }
    if (AnObject is TComponent) and (TComponent(AnObject).Owner = FRoot) and
      not (csDestroying in FRoot.ComponentState) and not FLoading then
    begin
      if TComponent(AnObject).Name <> '' then
        FBridge.ComponentRemoved(TComponent(AnObject).Name);
      DesignHost.NotifyItemDeleted(Self, AnObject);
      PostUpdateHelpers;
      StructureChanged;
    end;
    { a package's editor deleted it: the Object Inspector must not keep its property editors
      until the next selection (Select would not even see a change: the root is selected) }
    if WasSelected and not FLoading then SelectionChanged;
  end;
end;

{ the ancestor's own component of C (the form: the ancestor form; a placed frame's component: the
  frame's, in the frame alone - PristineFrame -, along the frames it is in), nil: none }
function TFormDesigner.AncestorOf(C: TComponent): TComponent;
var
  Path: TList;
  O: TComponent;
  I: Integer;
begin
  Result := nil;
  if InFrameInstance(C) then
  begin
    Path := TList.Create;
    try
      O := C;
      while O.Owner <> FRoot do
      begin
        Path.Insert(0, O);
        O := O.Owner;
      end;
      { O: the frame placed on the root; the names inside it lead to C's counterpart }
      Result := PristineFrame(O.ClassName);
      for I := 0 to Path.Count - 1 do
        if Result <> nil then Result := Result.FindComponent(TComponent(Path[I]).Name);
    finally
      Path.Free;
    end;
    Exit;
  end;
  if FAncestorRoot = nil then Exit;
  if C = FRoot then Result := FAncestorRoot
  else if csAncestor in C.ComponentState then Result := FAncestorRoot.FindComponent(C.Name);
end;

function TFormDesigner.CanRevert: Boolean;
var
  I: Integer;
  C: TComponent;
begin
  Result := False;
  for I := 0 to FSelection.Count - 1 do
    if TObject(FSelection[I]) is TComponent then
    begin
      C := TComponent(FSelection[I]);
      { a placed frame's component always has its frame's (asked often: the frame alone is not
        made for it) }
      if InFrameInstance(C) or ((FAncestorRoot <> nil) and (AncestorOf(C) <> nil)) then
      begin
        Result := True;
        Exit;
      end;
    end;
end;

{ the published properties of Src into Dst: values, and the objects that are not components
  (a font, a string list) assigned; Name, component references and read-only values stay; an
  event keeps the form's own method of that name }
procedure CopyPublished(Src, Dst: TPersistent; Root: TComponent; const OnlyProp: string);
var
  Count, I: Integer;
  List: PPropList;
  P: PPropInfo;
  Obj, DObj: TObject;
  M: TMethod;
begin
  Count := GetPropList(Src.ClassInfo, tkProperties, nil);
  if Count = 0 then Exit;
  GetMem(List, Count * SizeOf(PPropInfo));
  try
    GetPropList(Src.ClassInfo, tkProperties, List);
    for I := 0 to Count - 1 do
    begin
      P := List[I];
      if (OnlyProp <> '') and not SameText(P.Name, OnlyProp) then Continue;
      if SameText(P.Name, 'Name') then Continue;
      if (P.SetProc = nil) and (P.PropType^.Kind <> tkClass) then Continue;
      try
        case P.PropType^.Kind of
          tkInteger, tkChar, tkWChar, tkEnumeration, tkSet: SetOrdProp(Dst, P, GetOrdProp(Src, P));
          tkFloat: SetFloatProp(Dst, P, GetFloatProp(Src, P));
          tkString, tkLString: SetStrProp(Dst, P, GetStrProp(Src, P));
          tkWString: SetWideStrProp(Dst, P, GetWideStrProp(Src, P));
          tkInt64: SetInt64Prop(Dst, P, GetInt64Prop(Src, P));
          tkVariant: SetVariantProp(Dst, P, GetVariantProp(Src, P));
          tkMethod:
            begin
              M := GetMethodProp(Src, P);
              if M.Code <> nil then M.Data := Root;
              SetMethodProp(Dst, P, M);
            end;
          tkClass:
            begin
              Obj := GetObjectProp(Src, P);
              DObj := GetObjectProp(Dst, P);
              if (Obj is TPersistent) and (DObj is TPersistent) and not (Obj is TComponent) then
                TPersistent(DObj).Assign(TPersistent(Obj));
            end;
        end;
      except
        // a value the component does not take (as Delphi: the others still revert)
      end;
    end;
  finally
    FreeMem(List);
  end;
end;

procedure TFormDesigner.RevertToInherited(const PropName: string);
var
  I: Integer;
  C, A: TComponent;
begin
  try
    for I := 0 to FSelection.Count - 1 do
      if TObject(FSelection[I]) is TComponent then
      begin
        C := TComponent(FSelection[I]);
        A := AncestorOf(C);
        { a placed frame's component gets its frame's handlers back: methods of the frame it is in }
        if A = nil then Continue;
        if InFrameInstance(C) then CopyPublished(A, C, C.Owner, PropName)
        else CopyPublished(A, C, FRoot, PropName);
      end;
  finally
    FreePristine;
  end;
  Modified;
end;

procedure TFormDesigner.ValidateRename(AComponent: TComponent; const CurName, NewName: string);
var
  OldClass, NewClass: string;
begin
  if FLoading or FDestroying or (FRoot = nil) then Exit;
  if (NewName <> '') and not IsValidIdent(NewName) then
    raise EComponentError.CreateFmt('''%s'' is not a valid component name', [NewName]);
  if (AComponent = nil) or (AComponent = FRoot) then
  begin
    { the form itself: Form1 -> MainForm also renames the class TForm1 -> TMainForm }
    if (CurName <> '') and (NewName <> '') and not SameText(CurName, NewName) then
    begin
      if FRoot.FindComponent(NewName) <> nil then
        raise EComponentError.CreateFmt('A component named %s already exists', [NewName]);
      OldClass := FRoot.ClassName;
      NewClass := 'T' + NewName;
      RenameSubClass(FRoot, NewClass, FBridge.GetUnitName);
      { the module's instance has the root's name (a TService without a DisplayName shows it) }
      if FModule <> nil then FModule.Name := NewName;
      FBridge.RootRenamed(CurName, NewName, OldClass, NewClass);
      StructureChanged;
    end;
    Exit;
  end;
  { a placed frame's component asks through its frame (TComponent.ValidateRename): inherited
    from the frame, it keeps its name }
  if not IsDesigned(AComponent) then Exit;
  if (csAncestor in AComponent.ComponentState) and (CurName <> '') and (NewName <> CurName) then
    raise EComponentError.CreateFmt('Cannot rename component %s, component was introduced in an ancestor ' +
      'and may not be renamed', [CurName]);
  if AComponent.Owner <> FRoot then Exit;
  if (NewName <> '') and SameText(NewName, FRoot.Name) then
    raise EComponentError.CreateFmt('A component named %s already exists', [NewName]);
  if (CurName <> '') and (NewName <> '') and (CurName <> NewName) then
  begin
    FBridge.ComponentRenamed(CurName, NewName);
    StructureChanged;
  end
  else if (CurName = '') and (NewName <> '') and (FLateAdds.IndexOf(AComponent) < 0) then
    { A component of the form gets its first name. When the designer itself places or pastes
      it, the declaration follows right away (and takes it out of this list again). Otherwise
      a component or property editor made it - the action list editor and the menu designer
      call TAction.Create(Form) / TMenuItem.Create(Form) and then name it. The name is not
      assigned yet at this point: the declaration is written with the next Modified. }
    FLateAdds.Add(AComponent);
end;

{ the declarations of the components that editors created on their own }
procedure TFormDesigner.FlushLateAdds;
var
  C: TComponent;
  Any: Boolean;
begin
  if (FLateAdds.Count = 0) or FLoading or FDestroying or (FRoot = nil) then Exit;
  Any := False;
  { in the order they were made: a batch an editor makes (Add all fields) is declared in its order }
  while FLateAdds.Count > 0 do
  begin
    C := TComponent(FLateAdds[0]);
    FLateAdds.Delete(0);
    if (C.Owner = FRoot) and (C.Name <> '') and (FRoot.FindComponent(C.Name) = C) then
    begin
      FBridge.ComponentAdded(C);
      DesignHost.NotifyItemInserted(Self, C);
      Any := True;
    end;
  end;
  if Any then StructureChanged;
end;

procedure TFormDesigner.EditComponent(C: TComponent);
var
  Ed: IComponentEditor;
begin
  if C = nil then Exit;
  Ed := GetComponentEditor(C, Self);
  if Ed <> nil then
    try
      Ed.Edit;
    finally
      Ed := nil;
      { the editor may have opened a design window (action list editor, menu designer ...) }
      DesignHost.SyncDesignWindows;
    end;
end;

{ the Delphi object behind an interface it implements: the first entry of a Delphi class's
  interface table is a thunk "add dword ptr [esp+4], -Offset" (byte or long form) that leads from
  the interface back to the object; nil for anything else }
function ImplementingObject(const I: IInterface): TObject;
const
  AddByte = $04244483;           // 83 44 24 04 ib
  AddLong = $04244481;           // 81 44 24 04 id
type
  PThunk = ^TThunk;
  TThunk = packed record
    Op: Cardinal;
    case Integer of
      0: (ByteOffset: ShortInt);
      1: (LongOffset: Integer);
  end;
var
  T: PThunk;
begin
  Result := nil;
  if I = nil then Exit;
  try
    T := PThunk(PPointer(PPointer(Pointer(I))^)^);
    if T^.Op = AddByte then Result := TObject(PChar(Pointer(I)) + T^.ByteOffset)
    else if T^.Op = AddLong then Result := TObject(PChar(Pointer(I)) + T^.LongOffset);
  except
    Result := nil;
  end;
end;

{ designide's TEditActionSelectionEditor: the Edit and Control submenus of Delphi's own designer,
  which drive that designer through its IEditHandler. The context menu of this designer has those
  commands itself, as the IDE's actions (SdMain's DesignPopup). }
function IsEditSubmenus(const Sel: ISelectionEditor): Boolean;
var
  O: TObject;
begin
  try
    O := ImplementingObject(Sel);
    Result := (O <> nil) and (O is TEditActionSelectionEditor);
  except
    Result := False;
  end;
end;

{ the editors whose verbs the context menu shows, made for the selection as Delphi 7's designer
  makes them for its menu: the component editor of the one component selected, and the
  selection editors registered for the selection's class (designide's list) but Delphi's Edit
  and Control submenus }
procedure TFormDesigner.MenuEditors;
var
  All: ISelectionEditorList;
  I, N: Integer;
begin
  ReleaseVerbs;
  if (FSelection.Count = 1) and (TObject(FSelection[0]) is TComponent) then
    FVerbComp := GetComponentEditor(TComponent(FSelection[0]), Self);
  if FSelection.Count = 0 then Exit;
  All := GetSelectionEditors(Self);
  if All = nil then Exit;
  SetLength(FVerbSels, All.Count);
  N := 0;
  for I := 0 to All.Count - 1 do
    if not IsEditSubmenus(All[I]) then
    begin
      FVerbSels[N] := All[I];
      Inc(N);
    end;
  SetLength(FVerbSels, N);
end;

procedure TFormDesigner.ReleaseVerbs;
begin
  FVerbComp := nil;
  FVerbSels := nil;
end;

{ verb Index of GetVerbs: its editor (the component editor's, else a selection editor's in Sel)
  and its index there; the menu's editors, made when there are none }
function TFormDesigner.VerbEditor(Index: Integer; out Comp: IComponentEditor;
  out Sel: ISelectionEditor; out Verb: Integer): Boolean;
var
  I, N: Integer;
begin
  Result := False;
  Comp := nil;
  Sel := nil;
  Verb := Index;
  if Index < 0 then Exit;
  if (FVerbComp = nil) and (FVerbSels = nil) then MenuEditors;
  if FVerbComp <> nil then
  begin
    N := FVerbComp.GetVerbCount;
    if Verb < N then
    begin
      Comp := FVerbComp;
      Result := True;
      Exit;
    end;
    Dec(Verb, N);
  end;
  for I := 0 to High(FVerbSels) do
  begin
    N := FVerbSels[I].GetVerbCount;
    if Verb < N then
    begin
      Sel := FVerbSels[I];
      Result := True;
      Exit;
    end;
    Dec(Verb, N);
  end;
end;

function TFormDesigner.GetVerbs(List: TStrings): Integer;
var
  I, J: Integer;
begin
  List.Clear;
  try
    MenuEditors;
    if FVerbComp <> nil then
      for I := 0 to FVerbComp.GetVerbCount - 1 do List.Add(FVerbComp.GetVerb(I));
    Result := List.Count;
    for I := 0 to High(FVerbSels) do
      for J := 0 to FVerbSels[I].GetVerbCount - 1 do List.Add(FVerbSels[I].GetVerb(J));
  except
    List.Clear;
    Result := 0;
  end;
end;

procedure TFormDesigner.PrepareVerb(Index: Integer; const Item: IMenuItem);
var
  Comp: IComponentEditor;
  Sel: ISelectionEditor;
  Verb: Integer;
begin
  try
    if VerbEditor(Index, Comp, Sel, Verb) then
      if Sel <> nil then Sel.PrepareItem(Verb, Item) else Comp.PrepareItem(Verb, Item);
  except
    { an editor that fails to prepare its item leaves it as GetVerb made it }
  end;
end;

procedure TFormDesigner.ExecuteVerb(Index: Integer);
var
  Comp: IComponentEditor;
  Sel: ISelectionEditor;
  Verb: Integer;
  List: IDesignerSelections;
begin
  if not VerbEditor(Index, Comp, Sel, Verb) then Exit;
  try
    if Sel <> nil then
    begin
      List := CreateSelectionList;
      GetSelections(List);
      Sel.ExecuteVerb(Verb, List);
    end
    else
      Comp.ExecuteVerb(Verb);
  finally
    Comp := nil;
    Sel := nil;
    DesignHost.SyncDesignWindows;
  end;
  PostUpdateHelpers;
end;

{ ---------------------------------------------------------------- clipboard }

procedure TFormDesigner.CopySelected;
var
  S: string;
begin
  S := SelectionText;
  if S <> '' then Clipboard.AsText := S;
end;

{ the selected components as .dfm text (a container's controls with it) }
function TFormDesigner.SelectionText: string;
var
  Bin: TMemoryStream;
  Txt: TStringStream;
  W: TWriter;
  I: Integer;
  C: TComponent;
  Skip: Boolean;
  P: TControl;
begin
  Result := '';
  Bin := TMemoryStream.Create;
  Txt := TStringStream.Create('');
  try
    for I := 0 to FSelection.Count - 1 do
    begin
      if not (TObject(FSelection[I]) is TComponent) or (FSelection[I] = FRoot) then Continue;
      C := TComponent(FSelection[I]);
      { children of a selected container travel with their parent }
      Skip := False;
      if C is TControl then
      begin
        P := TControl(C).Parent;
        while not Skip and (P <> nil) and (P <> FForm) do
        begin
          Skip := IsSelected(P);
          P := P.Parent;
        end;
      end;
      if Skip then Continue;
      Bin.Clear;
      W := TWriter.Create(Bin, 4096);
      try
        W.Root := FRoot;
        W.OnFindAncestor := WriterFindAncestor;
        W.WriteSignature;
        W.WriteComponent(C);
      finally
        W.Free;
      end;
      Bin.Position := 0;
      Txt.WriteString(FormText(Bin));
    end;
    Result := Txt.DataString;
  finally
    FreePristine;                    // the frames alone (WriterFindAncestor) served every component
    Bin.Free;
    Txt.Free;
  end;
end;

procedure TFormDesigner.CutSelected;
begin
  CopySelected;
  DeleteSelected;
end;

{ text of a form file: components that Paste can make - a placed frame first is "inline" }
function IsComponentText(const S: string): Boolean;
var
  T: string;
begin
  T := Copy(TrimLeft(Copy(S, 1, 64)), 1, 7);
  Result := SameText(T, 'object ') or SameText(T, 'inline ');
end;

var
  PasteSeq: DWORD;                   // the clipboard's sequence number PasteOk was found for
  PasteOk: Boolean;

{ asked at every idle while a form is designed: the clipboard is read again only when its
  contents changed (the whole text is copied to look at its start) }
function TFormDesigner.CanPasteNow: Boolean;
var
  Seq: DWORD;
begin
  Seq := GetClipboardSequenceNumber;
  if (Seq <> 0) and (Seq = PasteSeq) then
  begin
    Result := PasteOk;
    Exit;
  end;
  Result := False;
  if Clipboard.HasFormat(CF_TEXT) then
  try
    Result := IsComponentText(Clipboard.AsText);
  except
    Exit;                            // the clipboard was busy: asked again at the next idle
  end;
  PasteSeq := Seq;
  PasteOk := Result;
end;

var
  PasteList: TList;

procedure TFormDesigner.ReaderSetName(Reader: TReader; Component: TComponent; var Name: string);
begin
  if (Reader.Root = FRoot) and ((FRoot.FindComponent(Name) <> nil) or SameText(Name, FRoot.Name)) then
    Name := UniqueName(Component.ClassName);
end;

procedure TFormDesigner.PasteComponentRead(Component: TComponent);
begin
  if (PasteList <> nil) and (Component <> nil) then PasteList.Add(Component);     // nil: skipped by the reader
end;

procedure TFormDesigner.PasteFromClipboard;
begin
  if CanPasteNow then PasteText(Clipboard.AsText);
end;

{ the components of form file text ("object ... end", one or more) into the selected container:
  Paste with the clipboard's text, the test command "paste" with a file's. All of them or none:
  a text that cannot be read is an error that says why, and the form stays as it was (the form's
  own closing "end", copied along with its components, is no error) }
procedure TFormDesigner.PasteText(const Text: string);
var
  Src: TStringStream;
  Bin: TMemoryStream;
  Reader: TReader;
  Parent: TWinControl;
  I, Start: Integer;
  Size: Int64;
  C: TComponent;
  Before: TList;
  Error: string;

  { AddComponent's rule, checked before anything is read: no control onto a data module }
  function Refused: Boolean;
  var
    Lines: TStringList;
    K: Integer;
    ObjName, ObjClass: string;
  begin
    Result := False;
    if FHostKind <> hkDataModule then Exit;
    Lines := TStringList.Create;
    try
      Lines.Text := Text;
      for K := 0 to Lines.Count - 1 do
        if DfmObjectHeader(Lines[K], ObjName, ObjClass) and
          not AcceptsClass(DesignHost.FindComponentClass(ObjClass)) then
        begin
          Result := True;
          Exit;
        end;
    finally
      Lines.Free;
    end;
  end;

  { the text from From (0-based) on holds no object: "end"s only }
  function OnlyEnds(From: Integer): Boolean;
  var
    Lines: TStringList;
    K: Integer;
  begin
    Result := True;
    Lines := TStringList.Create;
    try
      Lines.Text := Copy(Text, From + 1, MaxInt);
      for K := 0 to Lines.Count - 1 do
        if (Trim(Lines[K]) <> '') and not SameText(Trim(Lines[K]), 'end') then
        begin
          Result := False;
          Exit;
        end;
    finally
      Lines.Free;
    end;
  end;

  { the converter's message for the object at From with the lines of the whole text: it counts
    from where it starts, so the object is converted again behind as many line breaks }
  function TextError(From: Integer; const Msg: string): string;
  var
    K, N: Integer;
    S: TStringStream;
    B: TMemoryStream;
  begin
    Result := Msg;
    N := 0;
    for K := 1 to From do
      if Text[K] = #10 then Inc(N);
    if N = 0 then Exit;
    S := TStringStream.Create(StringOfChar(#10, N) + Copy(Text, From + 1, MaxInt));
    B := TMemoryStream.Create;
    try
      try
        ObjectTextToBinary(S, B);
      except
        on E: Exception do Result := E.Message;
      end;
    finally
      B.Free;
      S.Free;
    end;
  end;

  { the components read, made as at a load; '' or the reader's error - then what it had made
    goes again, unannounced: it was never loaded nor had its references fixed (csLoading stays),
    and the unit never declared it }
  function ReadAll: string;
  var
    K: Integer;
    OwnCache: Boolean;
  begin
    Result := '';
    Reader := TReader.Create(Bin, 4096);
    FLoading := True;
    OwnCache := BeginMethodCache;
    try
      try
        try
          Reader.OnFindMethod := PasteFindMethod;
          Reader.OnError := ReaderError;
          Reader.OnFindComponentClass := ReaderFindComponentClass;
          Reader.OnCreateComponent := ReaderCreateComponent;
          Reader.OnSetName := ReaderSetName;
          Reader.ReadComponents(FRoot, Parent, PasteComponentRead);
        finally
          EndMethodCache(OwnCache);
          Reader.Free;
        end;
      except
        on E: Exception do
        begin
          Result := E.Message;
          { the last first: a container takes its controls along }
          K := FRoot.ComponentCount - 1;
          while K >= 0 do
          begin
            if Before.IndexOf(FRoot.Components[K]) < 0 then FRoot.Components[K].Free;
            Dec(K);
            if K >= FRoot.ComponentCount then K := FRoot.ComponentCount - 1;
          end;
        end;
      end;
    finally
      FLoading := False;
    end;
  end;

begin
  if not IsComponentText(Text) or Refused then Exit;
  if PasteIntoFrame then
  begin
    RefuseFrameAdd;
    Exit;
  end;
  Parent := FForm;
  if (FSelection.Count > 0) and (TObject(FSelection[0]) is TControl) then
    Parent := ContainerFor(TControl(FSelection[0]));
  Src := TStringStream.Create(Text);
  Bin := TMemoryStream.Create;
  PasteList := TList.Create;
  Before := TList.Create;
  try
    { the clipboard holds a sequence of objects; convert them one by one. A conversion that
      fails has its writer flush "TPF0" and a part of the object on the way out: cut off again }
    Error := '';
    while Src.Position < Src.Size do
    begin
      Start := Src.Position;
      Size := Bin.Size;
      try
        ObjectTextToBinary(Src, Bin);
      except
        on E: Exception do
        begin
          Bin.Size := Size;
          if not OnlyEnds(Start) then Error := TextError(Start, E.Message);
          Break;
        end;
      end;
      while (Src.Position < Src.Size) and (Text[Src.Position + 1] in [#13, #10, ' ', #9]) do
        Src.Position := Src.Position + 1;
    end;
    if Error <> '' then raise EParserError.Create('The text cannot be pasted: ' + Error);
    if Bin.Size = 0 then Exit;
    I := 0;
    Bin.Write(I, 1);          // list terminator expected by ReadComponents
    Bin.Position := 0;
    { every component the paste makes gets its declaration - also the ones that come along with
      a pasted one (the controls of a panel at any depth, the items of a menu, the actions of an
      action list): what was there before is known }
    for I := 0 to FRoot.ComponentCount - 1 do Before.Add(FRoot.Components[I]);
    Error := ReadAll;
    if Error <> '' then raise EReadError.Create('The components cannot be pasted: ' + Error);
    for I := 0 to FRoot.ComponentCount - 1 do
    begin
      C := FRoot.Components[I];
      if Before.IndexOf(C) >= 0 then Continue;
      FLateAdds.Remove(C);
      FBridge.ComponentAdded(C);
      DesignHost.NotifyItemInserted(Self, C);
    end;
    if PasteList.Count > 0 then
    begin
      Modified;
      StructureChanged;
      SelectList(PasteList);
    end;
  finally
    Before.Free;
    FreeAndNil(PasteList);
    Bin.Free;
    Src.Free;
  end;
end;

{ ---------------------------------------------------------------- alignment }

procedure TFormDesigner.AlignSelected(Kind: TAlignKind);
var
  L: TList;
  I, V, Total, Gap, Pos: Integer;
  C, First: TControl;

  function SortPos(A: TControl): Integer;
  begin
    if Kind = akSpaceEquallyH then Result := A.Left else Result := A.Top;
  end;

  procedure SortList;
  var
    A, B: Integer;
    T: Pointer;
  begin
    for A := 0 to L.Count - 2 do
      for B := A + 1 to L.Count - 1 do
        if SortPos(TControl(L[B])) < SortPos(TControl(L[A])) then
        begin
          T := L[A]; L[A] := L[B]; L[B] := T;
        end;
  end;

begin
  if FLocked then Exit;
  L := TList.Create;
  try
    for I := 0 to FSelection.Count - 1 do
      if (TObject(FSelection[I]) is TControl) and (FSelection[I] <> FForm) then L.Add(FSelection[I]);
    if L.Count = 0 then Exit;
    First := TControl(L[0]);
    case Kind of
      akCenterInWindowH:
        for I := 0 to L.Count - 1 do
        begin
          C := TControl(L[I]);
          if C.Parent <> nil then C.Left := (C.Parent.ClientWidth - C.Width) div 2;
        end;
      akCenterInWindowV:
        for I := 0 to L.Count - 1 do
        begin
          C := TControl(L[I]);
          if C.Parent <> nil then C.Top := (C.Parent.ClientHeight - C.Height) div 2;
        end;
      akSpaceEquallyH, akSpaceEquallyV:
        if L.Count > 2 then
        begin
          SortList;
          Total := 0;
          for I := 0 to L.Count - 1 do
            if Kind = akSpaceEquallyH then Inc(Total, TControl(L[I]).Width) else Inc(Total, TControl(L[I]).Height);
          C := TControl(L[L.Count - 1]);
          First := TControl(L[0]);
          if Kind = akSpaceEquallyH then
            Gap := ((C.Left + C.Width - First.Left) - Total) div (L.Count - 1)
          else
            Gap := ((C.Top + C.Height - First.Top) - Total) div (L.Count - 1);
          if Kind = akSpaceEquallyH then Pos := First.Left else Pos := First.Top;
          for I := 0 to L.Count - 1 do
          begin
            C := TControl(L[I]);
            if Kind = akSpaceEquallyH then
            begin
              C.Left := Pos;
              Inc(Pos, C.Width + Gap);
            end
            else
            begin
              C.Top := Pos;
              Inc(Pos, C.Height + Gap);
            end;
          end;
        end;
    else
      for I := 1 to L.Count - 1 do
      begin
        C := TControl(L[I]);
        case Kind of
          akLeftEdges: C.Left := First.Left;
          akRightEdges: C.Left := First.Left + First.Width - C.Width;
          akTopEdges: C.Top := First.Top;
          akBottomEdges: C.Top := First.Top + First.Height - C.Height;
          akHCenters:
            begin
              V := First.Left + First.Width div 2;
              C.Left := V - C.Width div 2;
            end;
          akVCenters:
            begin
              V := First.Top + First.Height div 2;
              C.Top := V - C.Height div 2;
            end;
          akSameWidth: C.Width := First.Width;
          akSameHeight: C.Height := First.Height;
        end;
      end;
    end;
    Modified;
    UpdateHelpers;
  finally
    L.Free;
  end;
end;

procedure TFormDesigner.AlignSelectedToGrid;
var
  I: Integer;
  C: TControl;
  GX, GY: Integer;
begin
  if FLocked then Exit;
  GX := DesignEnv.GridX;
  GY := DesignEnv.GridY;
  if (GX < 1) or (GY < 1) then Exit;
  for I := 0 to FSelection.Count - 1 do
    if (TObject(FSelection[I]) is TControl) and (FSelection[I] <> FForm) then
    begin
      C := TControl(FSelection[I]);
      C.SetBounds(GridRound(C.Left, GX), GridRound(C.Top, GY), C.Width, C.Height);
    end;
  Modified;
  UpdateHelpers;
end;

procedure TFormDesigner.BringSelectedToFront;
var
  I: Integer;
begin
  for I := 0 to FSelection.Count - 1 do
    if (TObject(FSelection[I]) is TControl) and (FSelection[I] <> FForm) then
      TControl(FSelection[I]).BringToFront;
  Modified;
  UpdateHelpers;
end;

procedure TFormDesigner.SendSelectedToBack;
var
  I: Integer;
begin
  for I := 0 to FSelection.Count - 1 do
    if (TObject(FSelection[I]) is TControl) and (FSelection[I] <> FForm) then
      TControl(FSelection[I]).SendToBack;
  Modified;
  UpdateHelpers;
end;

{ ---------------------------------------------------------------- IDesignerNotify / hook }

procedure TFormDesigner.Modified;
begin
  if FLoading or FDestroying then Exit;
  FlushLateAdds;
  FModified := True;
  if FBridge <> nil then FBridge.DesignerModified;
  if FForm <> nil then
  begin
    FForm.UpdateBorder;
    FForm.UpdateMenuBar;
  end;
  PostUpdateHelpers;
  if Assigned(DesignEnv.OnModified) then DesignEnv.OnModified(Self);
  DesignHost.NotifyItemsModified(Self);
end;

function TFormDesigner.GetCustomForm: TCustomForm;
begin
  Result := FForm;
end;

procedure TFormDesigner.SetCustomForm(Value: TCustomForm);
begin
end;

function TFormDesigner.GetIsControl: Boolean;
begin
  Result := False;
end;

procedure TFormDesigner.SetIsControl(Value: Boolean);
begin
end;

function TFormDesigner.GetRoot: TComponent;
begin
  Result := FRoot;
end;

{ ---------------------------------------------------------------- IDesigner }

procedure TFormDesigner.Activate;
begin
  if FBridge <> nil then FBridge.ActivateDesigner;
end;

function TFormDesigner.CreateMethod(const Name: string; TypeData: PTypeData): TMethod;
begin
  Result.Code := nil;
  Result.Data := nil;
  if (FRoot = nil) or (Name = '') then Exit;
  if not IsValidIdent(Name) then
    raise Exception.CreateFmt('''%s'' is not a valid identifier', [Name]);
  Result.Code := FRoot.MethodAddress(Name);
  if Result.Code = nil then
    Result.Code := CreateSubClassMethod(FRoot, Name);
  Result.Data := FRoot;
  if (FBridge <> nil) and not FBridge.MethodExists(Name) then
    FBridge.CreateMethod(Name, TypeData);
end;

function TFormDesigner.GetMethodName(const Method: TMethod): string;
begin
  if (Method.Code = nil) or (FRoot = nil) then
    Result := ''
  else
    Result := FRoot.MethodName(Method.Code);
end;

procedure TFormDesigner.GetMethods(TypeData: PTypeData; Proc: TGetStrProc);
begin
  if FBridge <> nil then FBridge.GetCompatibleMethods(TypeData, Proc);
end;

function TFormDesigner.GetPathAndBaseExeName: string;
begin
  if FBridge <> nil then Result := FBridge.GetProjectExeBase else Result := '';
end;

function TFormDesigner.GetPrivateDirectory: string;
begin
  Result := ExtractFilePath(ParamStr(0));
end;

function TFormDesigner.GetBaseRegKey: string;
begin
  Result := '\' + SettingsRegKey;
end;

function TFormDesigner.GetIDEOptions: TCustomIniFile;
begin
  Result := DesignEnv.Options;
end;

procedure TFormDesigner.GetSelections(const List: IDesignerSelections);
var
  I: Integer;
begin
  for I := 0 to FSelection.Count - 1 do List.Add(TPersistent(FSelection[I]));
end;

function TFormDesigner.MethodExists(const Name: string): Boolean;
begin
  Result := (FRoot <> nil) and (FRoot.MethodAddress(Name) <> nil);
  if not Result and (FBridge <> nil) then Result := FBridge.MethodExists(Name);
end;

procedure TFormDesigner.RenameMethod(const CurName, NewName: string);
var
  P: Pointer;
begin
  if (FRoot = nil) or (CurName = '') or (NewName = '') or SameText(CurName, NewName) then Exit;
  P := FRoot.MethodAddress(CurName);
  if P <> nil then RenameSubClassMethod(FRoot, P, NewName);
  if FBridge <> nil then FBridge.RenameMethod(CurName, NewName);
end;

procedure TFormDesigner.SelectComponent(Instance: TPersistent);
begin
  Select(Instance);
end;

procedure TFormDesigner.SetSelections(const List: IDesignerSelections);
var
  L: TList;
  I: Integer;
begin
  L := TList.Create;
  try
    if List <> nil then
      for I := 0 to List.Count - 1 do L.Add(List[I]);
    SelectList(L);
  finally
    L.Free;
  end;
end;

procedure TFormDesigner.ShowMethod(const Name: string);
begin
  if FBridge <> nil then FBridge.ShowMethod(Name);
end;

procedure TFormDesigner.GetComponentNames(TypeData: PTypeData; Proc: TGetStrProc);
var
  I: Integer;
  C: TComponent;
begin
  if FRoot = nil then Exit;
  if FRoot is TypeData^.ClassType then Proc(FRoot.Name);
  for I := 0 to FRoot.ComponentCount - 1 do
  begin
    C := FRoot.Components[I];
    if (C.Name <> '') and (C is TypeData^.ClassType) then Proc(C.Name);
  end;
end;

{ a component by its name - a placed frame's by its path, Frame31.Frame21.Button1 }
function TFormDesigner.GetComponent(const Name: string): TComponent;
var
  Rest, Part: string;
  P: Integer;
begin
  Result := nil;
  if (FRoot = nil) or (Name = '') then Exit;
  if SameText(Name, FRoot.Name) then
  begin
    Result := FRoot;
    Exit;
  end;
  Result := FRoot;
  Rest := Name;
  while (Result <> nil) and (Rest <> '') do
  begin
    P := Pos('.', Rest);
    if P = 0 then P := Length(Rest) + 1;
    Part := Copy(Rest, 1, P - 1);
    Delete(Rest, 1, P);
    { a step into a component is a step into a placed frame }
    if (Result <> FRoot) and not ((Result is TSdDesignFrame) and (csInline in Result.ComponentState)) then
      Result := nil
    else
      Result := Result.FindComponent(Part);
  end;
end;

{ its name, and the path to it for a placed frame's component - the frames it is in, the outer
  one first (Frame21.Button1): Borland's method property names its new handler after it without
  the dots (Frame21Button1Click), as Delphi does }
function TFormDesigner.GetComponentName(Component: TComponent): string;
var
  O: TComponent;
begin
  if Component = nil then
  begin
    Result := '';
    Exit;
  end;
  Result := Component.Name;
  if (Component = FRoot) or (Component.Owner = nil) or (Component.Owner = FRoot) then Exit;
  if InFrameInstance(Component) then
  begin
    O := Component.Owner;
    while O <> FRoot do
    begin
      Result := O.Name + '.' + Result;
      O := O.Owner;
    end;
  end
  else
    Result := Component.Owner.Name + '.' + Result;     // another module's component (Form2.Button1)
end;

function TFormDesigner.GetObject(const Name: string): TPersistent;
begin
  Result := GetComponent(Name);
end;

function TFormDesigner.GetObjectName(Instance: TPersistent): string;
begin
  { a custom module's instance holds the root's own events: Borland's TMethodProperty names the
    handler of an event of an instance that is not the root after the instance's name, of the
    root after its class (GetFormMethodName) - the module's are the root's, as in Delphi, whose
    root is the instance: ServiceStart }
  if (Instance <> nil) and (Instance = FModule) then
  begin
    Result := GetRootClassName;
    if (Result <> '') and (Result[1] = 'T') then Delete(Result, 1, 1);
  end
  else if Instance is TComponent then
    Result := GetComponentName(TComponent(Instance))
  else if Instance <> nil then
    Result := Instance.GetNamePath
  else
    Result := '';
end;

procedure TFormDesigner.GetObjectNames(TypeData: PTypeData; Proc: TGetStrProc);
begin
  GetComponentNames(TypeData, Proc);
end;

function TFormDesigner.MethodFromAncestor(const Method: TMethod): Boolean;
begin
  Result := False;
end;

function TFormDesigner.CreateComponent(ComponentClass: TComponentClass; Parent: TComponent;
  Left, Top, Width, Height: Integer): TComponent;
begin
  Result := AddComponent(ComponentClass, Parent, Left, Top, Width, Height);
end;

{ no component is ever chosen for a click on the form (the Components view adds them itself) }
function TFormDesigner.CreateCurrentComponent(Parent: TComponent; const Rect: TRect): TComponent;
begin
  Result := nil;
end;

function TFormDesigner.IsComponentLinkable(Component: TComponent): Boolean;
begin
  Result := False;
end;

function TFormDesigner.IsComponentHidden(Component: TComponent): Boolean;
begin
  Result := False;
end;

procedure TFormDesigner.MakeComponentLinkable(Component: TComponent);
begin
end;

procedure TFormDesigner.Revert(Instance: TPersistent; PropInfo: PPropInfo);
begin
end;

function TFormDesigner.GetIsDormant: Boolean;
begin
  Result := False;
end;

procedure TFormDesigner.GetProjectModules(Proc: TGetModuleProc);
begin
end;

function TFormDesigner.GetAncestorDesigner: IDesigner;
begin
  Result := nil;
end;

function TFormDesigner.IsSourceReadOnly: Boolean;
begin
  Result := False;
end;

function TFormDesigner.GetScrollRanges(const ScrollPosition: TPoint): TPoint;
begin
  Result := ScrollPosition;
end;

procedure TFormDesigner.Edit(const Component: TComponent);
begin
  EditComponent(Component);
end;

{ Borland's method property made a new handler for an event that had a placed frame's own
  handler (InstanceName: the frame - Method.Data -, InstanceMethod: its method): the new one calls
  it first, as Delphi writes it (Frame21.Button1Click(Sender)), so that the frame's code still
  runs. The frame by its path: the one of that name that holds the component whose event it is -
  the selected one (the inspector's, a double click's) or that component itself; a frame placed
  in another frame may have the name of one on the root (Frame31.Frame21 and Frame21). Else a
  component of the root of that name, else the first frame of that name placed in one }
procedure TFormDesigner.ChainCall(const MethodName, InstanceName, InstanceMethod: string; TypeData: PTypeData);
var
  I: Integer;
  L: TList;
  O: TComponent;
  Path: string;
begin
  if (FBridge = nil) or (FRoot = nil) then Exit;
  Path := '';
  if (FSelection.Count = 1) and (TObject(FSelection[0]) is TComponent) then
  begin
    O := TComponent(FSelection[0]);
    while (O <> nil) and (O <> FRoot) do
    begin
      if (O is TSdDesignFrame) and SameText(O.Name, InstanceName) and IsDesigned(O) then
      begin
        Path := GetComponentName(O);
        Break;
      end;
      O := O.Owner;
    end;
  end;
  if (Path = '') and (FRoot.FindComponent(InstanceName) <> nil) then Path := InstanceName;
  if Path = '' then
  begin
    L := TList.Create;
    try
      GetDesignedComponents(L);
      for I := 0 to L.Count - 1 do
        if SameText(TComponent(L[I]).Name, InstanceName) then
        begin
          Path := GetComponentName(TComponent(L[I]));
          Break;
        end;
    finally
      L.Free;
    end;
  end;
  if Path <> '' then FBridge.ChainCall(MethodName, Path, InstanceMethod, TypeData);
end;

procedure TFormDesigner.CopySelection;
begin
  CopySelected;
end;

procedure TFormDesigner.CutSelection;
begin
  CutSelected;
end;

function TFormDesigner.CanPaste: Boolean;
begin
  Result := CanPasteNow;
end;

procedure TFormDesigner.PasteSelection;
begin
  PasteFromClipboard;
end;

procedure TFormDesigner.DeleteSelection(ADoAll: Boolean);
begin
  DeleteSelected;
end;

procedure TFormDesigner.ClearSelection;
begin
  Select(FRoot);
end;

procedure TFormDesigner.NoSelection;
begin
  Select(FRoot);
end;

procedure TFormDesigner.ModuleFileNames(var ImplFileName, IntfFileName, FormFileName: string);
begin
  ImplFileName := '';
  IntfFileName := '';
  FormFileName := '';
  if FBridge <> nil then
  begin
    ImplFileName := FBridge.GetUnitFileName;
    FormFileName := FBridge.GetFormFileName;
  end;
end;

{ As Delphi's designer: the compiled VCL class the designed root derives from, not the designed
  class (TForm1). Borland's TMethodProperty.GetFormMethodName names the root's handlers after
  it - FormCreate, DataModuleCreate, FrameResize, ServiceCreate (a custom module's class), as
  Delphi 7 writes them. }
function TFormDesigner.GetRootClassName: string;
const
  KindClass: array[THostKind] of string = ('TForm', 'TDataModule', 'TFrame');
begin
  if FRoot = nil then Result := ''
  else if FModule <> nil then Result := FModule.ClassName
  else Result := KindClass[FHostKind];
end;

function TFormDesigner.GetShiftState: TShiftState;
begin
  Result := [];
  if GetKeyState(VK_SHIFT) < 0 then Include(Result, ssShift);
  if GetKeyState(VK_CONTROL) < 0 then Include(Result, ssCtrl);
  if GetKeyState(VK_MENU) < 0 then Include(Result, ssAlt);
end;

procedure TFormDesigner.ModalEdit(EditKey: Char; const ReturnWindow: IActivatable);
begin
  if Assigned(DesignEnv.OnFocusInspector) then DesignEnv.OnFocusInspector(EditKey, '');
end;

procedure TFormDesigner.SelectItemName(const PropertyName: string);
begin
  if Assigned(DesignEnv.OnFocusInspector) then DesignEnv.OnFocusInspector(#0, PropertyName);
end;

procedure TFormDesigner.Resurrect;
begin
end;

function TFormDesigner.GetActiveClassGroup: TPersistentClass;
begin
  Result := TControl;
end;

function TFormDesigner.FindRootAncestor(const AClassName: string): TComponent;
begin
  Result := nil;
end;

{ the top-level objects' Left / Top lines (two blanks deep): moved by DX, DY - or (FindMin) their
  smallest values found }
function MapTopLevel(const Text: string; DX, DY: Integer; FindMin: Boolean; var MinX, MinY: Integer): string;
var
  L: TStringList;
  I, V: Integer;
  S: string;
begin
  L := TStringList.Create;
  try
    L.Text := Text;
    for I := 0 to L.Count - 1 do
    begin
      S := L[I];
      if (Copy(S, 1, 2) <> '  ') or (Copy(S, 3, 1) = ' ') then Continue;
      if Copy(S, 3, 7) = 'Left = ' then
      begin
        V := StrToIntDef(Copy(S, 10, MaxInt), 0);
        if FindMin then begin if V < MinX then MinX := V; end
        else L[I] := '  Left = ' + IntToStr(V + DX);
      end
      else if Copy(S, 3, 6) = 'Top = ' then
      begin
        V := StrToIntDef(Copy(S, 9, MaxInt), 0);
        if FindMin then begin if V < MinY then MinY := V; end
        else L[I] := '  Top = ' + IntToStr(V + DY);
      end;
    end;
    Result := L.Text;
  finally
    L.Free;
  end;
end;

function ShiftTemplateText(const Text: string; DX, DY: Integer): string;
var
  X, Y: Integer;
begin
  Result := MapTopLevel(Text, DX, DY, False, X, Y);
end;

function MakeTemplateText(const Text: string): string;
var
  L: TStringList;
  I: Integer;
  MinX, MinY: Integer;
  T: string;
begin
  L := TStringList.Create;
  try
    L.Text := Text;
    for I := L.Count - 1 downto 0 do
    begin
      T := TrimLeft(L[I]);
      if (Copy(T, 1, 2) = 'On') and (Pos(' = ', T) > 0) and (Pos('''', T) = 0) then L.Delete(I);
    end;
    MinX := MaxInt;
    MinY := MaxInt;
    MapTopLevel(L.Text, 0, 0, True, MinX, MinY);
    if MinX = MaxInt then MinX := 0;
    if MinY = MaxInt then MinY := 0;
    Result := ShiftTemplateText(L.Text, -MinX, -MinY);
  finally
    L.Free;
  end;
end;


initialization
  DesignEnv := TDesignEnvironment.Create;

finalization
  FreeAndNil(DesignEnv);

end.
