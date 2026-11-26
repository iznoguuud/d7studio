{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdObjInsp;

{ D7 Studio - Object Inspector.

  A Delphi 7 style two-column property grid over the IProperty interface of the Borland
  design-time library: every value, drop-down list, sub-property and dialog comes from the
  property editors registered by the loaded design packages; the properties are arranged by
  name or under the property categories of the IDE (PropertyCategories).

  The layout and every pixel of the rows follow the Delphi 7 inspector:
  instance box, 2 px, a tab control that is only as high as its tabs plus 5 px, and the list
  inside a 1 px lowered bevel. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  TypInfo, DesignIntf, DesignEditors, VCLEditors, PropertyCategories, SdUI, SdTabStrip, SdFormDesigner,
  SdDialogs, SdEncoding, Menus, ActnList;

type
  TPropGrid = class;

  TInspRow = class
  public
    Prop: IProperty;
    Name: string;
    Level: Integer;
    Expanded: Boolean;
    Attrs: TPropertyAttributes;
    IsRef: Boolean;
    InRef: Boolean;
    { a WideString property: shown in Unicode; with
      Borland's plain (ANSI) string editor it is also edited in Unicode by the grid (WideEdit) }
    Wide: Boolean;
    WideEdit: Boolean;
    { a property of the selected components themselves, not a sub-property: at the top, or in
      a category }
    Top: Boolean;
    { a category row (Arrange | by Category): no property of its own
      (Prop is nil), the properties of the category below it }
    Category: TPropertyCategory;
    Props: TInterfaceList;
    destructor Destroy; override;
  end;

  { a drop-down list (SdUI's pop-up list): the item under the pointer chosen, a click takes it }
  TPopupListBox = class(TSdPopupList)
  protected
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure Accept; virtual; abstract;          // an item was clicked
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TPropListBox = class(TPopupListBox)
  private
    FGrid: TPropGrid;
  protected
    procedure Accept; override;
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;
    procedure MeasureItem(Index: Integer; var Height: Integer); override;
  end;

  TPropEdit = class(TCustomEdit)
  private
    FGrid: TPropGrid;
    FClickTime: Integer;      // a click of the grid put the edit under the mouse: when ...
    FClickPos: TPoint;        // ... and where (screen); see WndProc
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
  protected
    procedure WndProc(var Message: TMessage); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: Char); override;
    procedure DblClick; override;
    procedure Change; override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TPropGrid = class(TSdControl)
  private
    FDesigner: TFormDesigner;
    FRows: TList;
    FTopRow: Integer;
    FWheel: Integer;               // parts of wheel notches (UIWheelSteps)
    FSelRow: Integer;
    FSplit: Integer;
    FRowH: Integer;
    FEvents: Boolean;
    FEdit: TPropEdit;
    FList: TPropListBox;
    FListVisible: Boolean;
    FListProp: IProperty;
    FBtnDown: Boolean;
    FSplitDrag: Boolean;
    FSelName: array[Boolean] of string;
    FUpdatingEdit: Boolean;
    FBoldFont: TFont;
    FInSetValue: Boolean;
    FNeedRebuild: Boolean;
    FSearch: string;
    FSearchTick: Cardinal;
    FRowDrag: Boolean;           // the selection follows the mouse (button held on a row)
    FDragY: Integer;
    FDragTimer: TTimer;
    FBtnHot: Boolean;            // the mouse is over the button of the selected row
    FSplitWanted: Integer;       // the divider the user chose; FSplit is what fits right now
    FDblPos: TPoint;             // where the double click happened
    FOnSplitChange: TNotifyEvent;
    FOnDropInstance: TNotifyEvent;
    FHiddenCount: Integer;       // properties left out: read-only ones (Show read only properties
                                 // off) and those of hidden categories
    FRefsOnly: Boolean;          // the Events page's pass for component references
    FByCategory: Boolean;        // Arrange | by Category
    FExpandedCats: TStringList;  // the categories expanded: they stay so when the rows are made again
    procedure SetSplit(Value: Integer);
    procedure ApplySplit;
    procedure UpdateRowHeight;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
    procedure SetBtnHot(Value: Boolean);
    procedure CancelList;
    procedure WMLButtonDblClk(var Message: TWMLButtonDblClk); message WM_LBUTTONDBLCLK;
    function NameLeft(Row: TInspRow): Integer;
    function TextTop(const R: TRect): Integer;
    function ValueRight(Index: Integer): Integer;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure BeginRowDrag(Y: Integer);
    procedure FocusWithoutEdit;
    procedure EndRowDrag;
    procedure TrackRow(Y: Integer);
    procedure DragTimerTick(Sender: TObject);
    procedure WMCaptureChanged(var Message: TMessage); message WM_CAPTURECHANGED;
    function GetRow(Index: Integer): TInspRow;
    procedure ClearRows;
    procedure AddProp(const Prop: IProperty);
    function PlaceInCategories(Row: TInspRow): Boolean;
    function CategoryRow(Cat: TPropertyCategory): TInspRow;
    function RowPath(Index: Integer): string;
    function FindRow(const Path: string): Integer;
    function RowByName(const AName: string; TopOnly: Boolean): Integer;
    function BoldFont: TFont;
    function ValueFont(IsDefault: Boolean): TFont;
    procedure SetByCategory(Value: Boolean);
    function GetHiddenCategories: string;
    procedure SetHiddenCategories(const Value: string);
    procedure AddListValue(const S: string);
    function RowRect(Index: Integer): TRect;
    function VisibleRows: Integer;
    function ButtonWidth(Row: TInspRow): Integer;
    function ButtonRect(Index: Integer): TRect;
    procedure DrawRow(Index: Integer; const R: TRect);
    procedure UpdateScrollBar;
    procedure PlaceEdit;
    function RowValue(Row: TInspRow): string;
    procedure RowShows(Row: TInspRow; Index: Integer; out Value: string; out Sample: TObject);
    function RowValueW(Index: Integer): WideString;
    function RowValueMixed(Row: TInspRow): Boolean;
    function RowSample(Row: TInspRow; Index: Integer = -1): TObject;
    function ValueTextLeft(Index: Integer): Integer;
    function TextLeft(HasGlyph: Boolean): Integer;
    function OnCheckBox(Index, X: Integer): Boolean;
    procedure ApplyValue(const S: string);
    function RowAttrs(Row: TInspRow): TPropertyAttributes;
    function IsModuleProp(const Prop: IProperty): Boolean;
    function TopObject(Row: TInspRow; Index: Integer): TPersistent;
    function RowInstance(Index: Integer): TPersistent;
    function RowIsForeign(Index: Integer): Boolean;
    procedure EditWide(Index: Integer);
    procedure SetRowWide(Index: Integer; const W: WideString);
    function EditText(Index: Integer): string;
    procedure SetRowText(Index: Integer; const S: string; ListValue: Boolean);
    function RowIsDefault(Row: TInspRow): Boolean;
    procedure SetTopRow(Value: Integer);
    procedure ToggleExpand(Index: Integer);
    procedure CollapseRow(Index: Integer);
    procedure ExpandRow(Index: Integer);
    procedure ButtonClick;
    procedure CycleValue;
    procedure EditDialog;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMVScroll(var Message: TWMVScroll); message WM_VSCROLL;
    procedure WMSize(var Message: TWMSize); message WM_SIZE;
    procedure WMSetCursor(var Message: TWMSetCursor); message WM_SETCURSOR;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    procedure CMCancelMode(var Message: TCMCancelMode); message CM_CANCELMODE;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: Char); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetDesigner(ADesigner: TFormDesigner);
    procedure Rebuild;
    procedure RefreshValues;
    procedure SelectRow(Index: Integer; FocusEdit: Boolean = False);
    { the in-place edit's text into the property; ListValue: it is a value of the property
      editor's own list (the drop-down list, a double click cycling) }
    function ApplyEdit(ListValue: Boolean = False): Boolean;
    procedure CancelEdit;
    procedure DropDown;
    procedure CloseUp(Accept: Boolean);
    procedure SelectByName(const AName: string);
    procedure StartEdit(Key: Char);
    function RowCount: Integer;
    function ShowsDying: Boolean;
    function DebugText: string;
    procedure ExpandSelected(Expand: Boolean);   // the inspector's menu: Expand, Collapse
    { the inspector's menu, View and Arrange: the categories of the
      properties shown (sorted, Objects the TPropertyCategory), All / Toggle / None, a click on a
      category (Ctrl: only it, Ctrl+Shift: all but it) }
    procedure ViewCategories(L: TStringList);
    procedure ShowCategories(Mode: TPropertyCategoryVisibleMode);
    procedure ClickCategory(const Name: string; Shift: TShiftState);
    function IsCategoryRow(Index: Integer): Boolean;
    property ByCategory: Boolean read FByCategory write SetByCategory;
    property HiddenCategories: string read GetHiddenCategories write SetHiddenCategories;   // comma text
    property Rows[Index: Integer]: TInspRow read GetRow;
    property SelectedRow: Integer read FSelRow;
    property Events: Boolean read FEvents write FEvents;
    property ListVisible: Boolean read FListVisible;
    property Split: Integer read FSplit write SetSplit;     // x of the column divider
    property SplitWanted: Integer read FSplitWanted;        // ... as chosen, for the settings
    property OnSplitChange: TNotifyEvent read FOnSplitChange write FOnSplitChange;
    property OnDropInstance: TNotifyEvent read FOnDropInstance write FOnDropInstance;   // Ctrl+Down
    property HiddenCount: Integer read FHiddenCount;
  end;


  { Environment Options | Object Inspector (the IDE copies its options here: SdEnvOptions) }
  TOIOptions = record
    ShowInstanceList, ShowClassNames, ShowStatusBar, RenderGrid, ShowReadOnly, BoldNonDefault,
    RefExpand, RefOnEvents: Boolean;
    Background, Gutter, Category, NameColor, ValueColor, NonDefault, Reference, ReadOnlyName: TColor;
  end;

  { The Object Inspector: a form made once, docked by the IDE. Its instance list is
    a drop-down list box of Windows - its border and its button - with the components as "Name:
    Class", the class name grey in the value column (ClassX). A choice counts when the open list
    closes on it (browsing the list selects nothing), or at once while the list is closed (the
    arrows, a letter, the wheel). The box and its events are in the .dfm; the tabs and the
    property grid, D7 Studio's own controls, are made in code. }
  TObjectInspector = class(TForm)
    InstanceBox: TComboBox;
    MenuActions: TActionList;
    aOIViewAll: TAction;
    aOIViewToggle: TAction;
    aOIViewNone: TAction;
    aOIArrangeCategory: TAction;
    aOIArrangeName: TAction;
    aOIRevert: TAction;
    aOIExpand: TAction;
    aOICollapse: TAction;
    aOIProperties: TAction;
    InspPopup: TPopupMenu;
    pmInsp1: TMenuItem;
    pmInspViewBar: TMenuItem;
    pmInsp2: TMenuItem;
    pmInsp3: TMenuItem;
    pmInsp4: TMenuItem;
    pmInsp5: TMenuItem;
    pmInsp6: TMenuItem;
    pmInsp7: TMenuItem;
    pmInsp8: TMenuItem;
    pmInsp9: TMenuItem;
    pmInsp10: TMenuItem;
    pmInsp11: TMenuItem;
    pmInsp13: TMenuItem;
    pmInsp14: TMenuItem;
    pmInsp15: TMenuItem;
    pmInsp16: TMenuItem;
    procedure InstanceDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure InstanceDropDown(Sender: TObject);
    procedure InstanceSelect(Sender: TObject);
    procedure InstanceCloseUp(Sender: TObject);
  private
    FDesigner: TFormDesigner;
    FStatusTop: Integer;              // the status bar (Show status bar), 0 = none
    FShown: Integer;                  // the instance box: the item of the component shown
    FEmptyText: string;               // ... its text while no single component is selected
    FClassX: Integer;                 // ... where the class name starts
    FDropped: Boolean;                // ... the list is open
    FChosen: Boolean;                 // ... and closes on an item (CBN_SELENDOK)
    FTabs: TSdTabStrip;               // Properties / Events: the IDE's tabs (SdTabStrip)
    FGrid: TPropGrid;
    FFrameTop: Integer;
    procedure SetShown(Value: Integer);
    procedure SetEmptyText(const Value: string);
    procedure SetClassX(Value: Integer);
    procedure Pick;
    function InstanceText: string;
    procedure BoxChange;
    procedure BoxAccepted;
    procedure GridDropInstance(Sender: TObject);
    procedure GridSplitChange(Sender: TObject);
    procedure TabsChange(Sender: TObject);
    procedure FillBox;
    procedure SyncBox;
    procedure Layout;
    procedure InvalidateStatus;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Resize; override;
    procedure CreateWnd; override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetDesigner(ADesigner: TFormDesigner);
    procedure SelectionChanged;
    procedure StructureChanged;
    procedure RefreshValues;
    procedure FocusProperty(Key: Char; const PropName: string);
    procedure ShowEvents(Value: Boolean);
    function DebugText: string;           // the rows as text (automated tests)
    property Designer: TFormDesigner read FDesigner;
    property Grid: TPropGrid read FGrid;
    { the options changed: layout, rows and colours again }
    procedure OptionsChanged;
  end;

const
  { Arrange (TPropGrid.ByCategory) as Delphi keeps it: ArrangeBy of [PropertyInspector] }
  ArrangeNames: array[Boolean] of string = ('Name', 'Category');

var
  OIOptions: TOIOptions = (ShowInstanceList: True; ShowClassNames: True; ShowStatusBar: False;
    RenderGrid: True; ShowReadOnly: True; BoldNonDefault: True; RefExpand: True; RefOnEvents: True;
    Background: clBtnFace; Gutter: clBtnFace; Category: clMaroon; NameColor: clBtnText;
    ValueColor: clNavy; NonDefault: clNavy; Reference: clMaroon; ReadOnlyName: clGrayText);

implementation

{$R *.dfm}

uses
  Math, SdDesignHost, SdCrashLog, SdSettings;

const
  DefaultSplit = 109;
  InstanceRows = 16;            // rows of the instance list before it scrolls

{ ---------------------------------------------------------------- drop-down lists }

{ One list can be open at a time. A mouse hook closes it when a button goes down anywhere but
  on the list or on the control that owns it - the owner decides itself (its button toggles). }

var
  PopupHook: HHOOK;
  PopupListWnd, PopupOwnerWnd: HWND;
  PopupCancel: TThreadMethod;

function PopupMouseHook(Code: Integer; W: WPARAM; L: LPARAM): LRESULT; stdcall;
var
  H: HWND;
  Cancel: TThreadMethod;
begin
  if (Code = HC_ACTION) and Assigned(PopupCancel) then
    case W of
      WM_LBUTTONDOWN, WM_RBUTTONDOWN, WM_MBUTTONDOWN, WM_NCLBUTTONDOWN, WM_NCRBUTTONDOWN,
      WM_LBUTTONDBLCLK, WM_NCLBUTTONDBLCLK:
        begin
          H := PMouseHookStruct(L)^.hwnd;
          if (H <> PopupListWnd) and (H <> PopupOwnerWnd) then
          begin
            Cancel := PopupCancel;
            Cancel;
          end;
        end;
    end;
  Result := CallNextHookEx(PopupHook, Code, W, L);
end;

procedure UnhookPopup;
begin
  if PopupHook <> 0 then UnhookWindowsHookEx(PopupHook);
  PopupHook := 0;
  PopupCancel := nil;
  PopupListWnd := 0;
  PopupOwnerWnd := 0;
end;

procedure HookPopup(ListWnd, OwnerWnd: HWND; Cancel: TThreadMethod);
begin
  UnhookPopup;
  PopupListWnd := ListWnd;
  PopupOwnerWnd := OwnerWnd;
  PopupCancel := Cancel;
  PopupHook := SetWindowsHookEx(WH_MOUSE, @PopupMouseHook, 0, GetCurrentThreadId);
end;

procedure CancelOpenPopup;
var
  Cancel: TThreadMethod;
begin
  Cancel := PopupCancel;
  if Assigned(Cancel) then Cancel;
end;

function CompareRows(A, B: Pointer): Integer;
begin
  Result := CompareText(TInspRow(A).Name, TInspRow(B).Name);
end;

destructor TInspRow.Destroy;
begin
  Props.Free;
  inherited;
end;

{ --- the values the inspector draws itself --- }

type
  TValueGlyph = (vgNone, vgCheck, vgAlign, vgAlignment);

{ the name of a property's enumeration type; '' for other kinds }
function EnumTypeName(const Prop: IProperty): string;
var
  T: PTypeInfo;
begin
  Result := '';
  if Prop = nil then Exit;
  T := Prop.GetPropType;
  if (T <> nil) and (T^.Kind = tkEnumeration) then Result := T^.Name;
end;

{ the glyph of a Boolean's, a TAlign's or a TAlignment's values; vgNone for other types }
function TypeGlyph(const Prop: IProperty): TValueGlyph;
var
  T: string;
begin
  Result := vgNone;
  T := EnumTypeName(Prop);
  if T = 'Boolean' then Result := vgCheck
  else if T = 'TAlign' then Result := vgAlign
  else if T = 'TAlignment' then Result := vgAlignment;
end;

{ ... the glyph before the values of a property - none when its editor draws them itself
  (DrawsItself: ICustomPropertyDrawing for the rows, ICustomPropertyListDrawing for the drop-down
  list) }
function ValueGlyph(const Prop: IProperty; const DrawsItself: TGUID): TValueGlyph;
var
  Own: IInterface;
begin
  if (Prop = nil) or Supports(Prop, DrawsItself, Own) then Result := vgNone
  else Result := TypeGlyph(Prop);
end;

{ a value's glyph in the square of UICheckBoxSize at X, Y: a Boolean's check box, where a TAlign
  puts a control in its parent (the accent colour in a frame), the lines of a TAlignment's text
  in LineColor. Values of other names draw nothing.
  The check box is drawn by hand in the colours of the check box bitmaps of Keith Wood's
  enhanced property editors (PropEdsD6, BOOLFALSE / BOOLTRUE): a clGray frame, clWindow inside,
  Windows' classic check mark in clGreen - its 7 columns of 3 px from (3, 5) down to (5, 7) and
  up to (9, 3) in the 13 px box, scaled with the box. An empty Value (several components with
  different values) has the mark in clGray, as Windows' mixed state, and so has a property that
  cannot be changed, its box in clBtnFace. }
procedure DrawValueGlyph(DC: HDC; X, Y: Integer; Glyph: TValueGlyph; const Value: string;
  Enabled: Boolean; LineColor: TColor);
var
  S, B, I, W, L, U, T: Integer;
  R: TRect;
  Mark: TColor;
begin
  S := UICheckBoxSize;
  R := Rect(X, Y, X + S, Y + S);
  case Glyph of
    vgCheck:
      begin
        UIFrame(DC, R, clGray);
        InflateRect(R, -1, -1);
        if Enabled then UIFill(DC, R, clWindow) else UIFill(DC, R, clBtnFace);
        if (Value = '') or not Enabled then Mark := clGray else Mark := clGreen;
        if (Value = '') or SameText(Value, 'True') then
          for I := 0 to MulDiv(7, S, 13) - 1 do
          begin
            U := I * 13 div S;                     // the column of the 13 px design
            if U <= 2 then T := 5 + U else T := 9 - U;
            L := X + MulDiv(3, S, 13) + I;
            UIFill(DC, Rect(L, Y + MulDiv(T, S, 13), L + 1, Y + MulDiv(T, S, 13) + MulDiv(3, S, 13)), Mark);
          end;
      end;
    vgAlign:
      if (Value <> '') and (Copy(Value, 1, 2) = 'al') then
      begin
        UIFrame(DC, R, clGrayText);
        InflateRect(R, -1, -1);
        UIFill(DC, R, clWindow);
        B := S div 4;                      // the band of a docked control: 3 px of 13
        if Value = 'alTop' then R.Bottom := R.Top + B
        else if Value = 'alBottom' then R.Top := R.Bottom - B
        else if Value = 'alLeft' then R.Right := R.Left + B
        else if Value = 'alRight' then R.Left := R.Right - B
        else if Value = 'alCustom' then InflateRect(R, -B, -B)            // placed by its parent
        else if Value = 'alNone' then                                    // where it was put
          R := Rect(R.Left + 1, R.Top + 1, R.Left + 1 + (S + 1) div 3 + 1, R.Top + 1 + (S + 1) div 3)
        else if Value <> 'alClient' then Exit;
        UIFill(DC, R, clHighlight);
      end;
    vgAlignment:
      if Value <> '' then
        { six lines, long and short in turn: 13 and 9 px of 13 }
        for I := 0 to (S - 1) div 2 - 1 do
        begin
          if Odd(I) then W := (S * 2 + 2) div 3 else W := S;
          if Value = 'taRightJustify' then L := X + S - W
          else if Value = 'taCenter' then L := X + (S - W) div 2
          else L := X;
          UIHLine(DC, L, L + W, Y + 1 + 2 * I, LineColor);
        end;
  end;
end;

{ Yes, Y, No and N (any case) as a Boolean property's True and False }
function BoolText(const Prop: IProperty; const S: string): string;
begin
  Result := S;
  if EnumTypeName(Prop) <> 'Boolean' then Exit;
  if SameText(Trim(S), 'Yes') or SameText(Trim(S), 'Y') then Result := 'True'
  else if SameText(Trim(S), 'No') or SameText(Trim(S), 'N') then Result := 'False';
end;

{ the object of an instance's class property; nil when it has none of the name }
function PropObject(Instance: TObject; const Name: string): TObject;
begin
  Result := nil;
  if (Instance <> nil) and (GetPropInfo(Instance, Name) <> nil) and (PropType(Instance, Name) = tkClass) then
    Result := GetObjectProp(Instance, Name);
end;

{ two fonts, or two size constraints, with the same values }
function SameSample(A, B: TObject): Boolean;
begin
  if (A is TFont) and (B is TFont) then
    Result := (TFont(A).Charset = TFont(B).Charset) and (TFont(A).Color = TFont(B).Color) and
      (TFont(A).Height = TFont(B).Height) and (TFont(A).Name = TFont(B).Name) and
      (TFont(A).Pitch = TFont(B).Pitch) and (TFont(A).Style = TFont(B).Style)
  else if (A is TSizeConstraints) and (B is TSizeConstraints) then
    Result := (TSizeConstraints(A).MinWidth = TSizeConstraints(B).MinWidth) and
      (TSizeConstraints(A).MinHeight = TSizeConstraints(B).MinHeight) and
      (TSizeConstraints(A).MaxWidth = TSizeConstraints(B).MaxWidth) and
      (TSizeConstraints(A).MaxHeight = TSizeConstraints(B).MaxHeight)
  else
    Result := A = B;
end;

{ the value shown for a font ("Segoe UI 9") or for size constraints ("(MinWidth,MinHeight,
  MaxWidth,MaxHeight)") }
function SampleText(Obj: TObject): string;
begin
  if Obj is TFont then
    Result := TFont(Obj).Name + ' ' + IntToStr(TFont(Obj).Size)
  else if Obj is TSizeConstraints then
    with TSizeConstraints(Obj) do
      Result := Format('(%d,%d,%d,%d)', [MinWidth, MinHeight, MaxWidth, MaxHeight])
  else
    Result := '';
end;

procedure SplitInstance(const S: string; var AName, AClass: string);
var
  P: Integer;
begin
  P := Pos(': ', S);
  if P > 0 then
  begin
    AName := Copy(S, 1, P - 1);
    AClass := Copy(S, P + 2, MaxInt);
  end
  else
  begin
    AName := S;
    AClass := '';
  end;
end;

{ ---------------------------------------------------------------- TPopupListBox }

constructor TPopupListBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Style := lbOwnerDrawVariable;
end;

procedure TPopupListBox.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  inherited;
  I := ItemAtPos(Point(X, Y), True);
  if (I >= 0) and (I <> ItemIndex) then ItemIndex := I;
end;

procedure TPopupListBox.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if (Button = mbLeft) and PtInRect(ClientRect, Point(X, Y)) then Accept;
end;


{ ---------------------------------------------------------------- TPropListBox }

procedure TPropListBox.Accept;
begin
  if FGrid <> nil then FGrid.CloseUp(True);
end;

procedure TPropListBox.MeasureItem(Index: Integer; var Height: Integer);
var
  Draw: ICustomPropertyListDrawing;
begin
  Canvas.Font := Font;
  Height := Canvas.TextHeight('Wg') + 2;
  if (FGrid <> nil) and (FGrid.FListProp <> nil) and (Index >= 0) and (Index < Items.Count) and
    Supports(FGrid.FListProp, ICustomPropertyListDrawing, Draw) then
    try
      Draw.ListMeasureHeight(Items[Index], Canvas, Height);
    except
    end;
end;

procedure TPropListBox.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  Draw: ICustomPropertyListDrawing;
  Glyph: TValueGlyph;
  G, X: Integer;
  Lines: TColor;
begin
  Canvas.Font := Font;
  if odSelected in State then
  begin
    Canvas.Brush.Color := clHighlight;
    Canvas.Font.Color := clHighlightText;
  end
  else
  begin
    Canvas.Brush.Color := clWindow;
    Canvas.Font.Color := clWindowText;
  end;
  if (FGrid <> nil) and (FGrid.FListProp <> nil) and
    Supports(FGrid.FListProp, ICustomPropertyListDrawing, Draw) then
    try
      Draw.ListDrawValue(Items[Index], Canvas, Rect, odSelected in State);
      Exit;
    except
    end;
  Canvas.FillRect(Rect);
  { a Boolean's, TAlign's or TAlignment's glyph before the value, centred in the item }
  X := Rect.Left + 2;
  Glyph := vgNone;
  if FGrid <> nil then Glyph := ValueGlyph(FGrid.FListProp, ICustomPropertyListDrawing);
  if Glyph <> vgNone then
  begin
    G := UICheckBoxSize;
    if odSelected in State then Lines := clHighlightText else Lines := clGrayText;
    DrawValueGlyph(Canvas.Handle, X, Rect.Top + (Rect.Bottom - Rect.Top - G) div 2, Glyph, Items[Index],
      True, Lines);
    Inc(X, G + 4);
  end;
  Canvas.TextOut(X, Rect.Top + 1, Items[Index]);
end;

{ ---------------------------------------------------------------- TPropEdit }

constructor TPropEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BorderStyle := bsNone;
  Ctl3D := False;
  ParentCtl3D := False;
  AutoSize := False;
  AutoSelect := False;
  TabStop := False;
  ParentFont := True;
  { it moves and changes size with the divider and the list: painted in memory, never erased
    on the screen first }
  DoubleBuffered := True;
end;

procedure TPropEdit.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  inherited;
  Message.Result := Message.Result or DLGC_WANTALLKEYS or DLGC_WANTARROWS or DLGC_WANTTAB;
end;

procedure TPropEdit.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  if (FGrid <> nil) and not (csDestroying in ComponentState) then
  begin
    if FGrid.FListVisible and (Message.FocusedWnd <> FGrid.FList.Handle) then FGrid.CloseUp(False);
    if (Message.FocusedWnd <> FGrid.Handle) and not FGrid.FInSetValue then
      try
        FGrid.ApplyEdit;
      except
        Application.HandleException(Self);
      end;
    FGrid.Invalidate;
  end;
end;

procedure TPropEdit.WMMouseWheel(var Message: TWMMouseWheel);
begin
  if FGrid <> nil then FGrid.Perform(WM_MOUSEWHEEL, TMessage(Message).WParam, TMessage(Message).LParam);
end;

procedure TPropEdit.Change;
var
  Row: TInspRow;
begin
  inherited Change;
  if (FGrid = nil) or FGrid.FUpdatingEdit or (FGrid.FSelRow < 0) or (FGrid.FSelRow >= FGrid.RowCount) then Exit;
  Row := FGrid.Rows[FGrid.FSelRow];
  { paAutoUpdate (Caption, Text): apply while typing - the other values the change moved (an
    AutoSize label's Width) shown at once: the designer's refresh came while FInSetValue held it
    back; a rebuild it asked for waits for the edit's end (ApplyEdit) }
  if (paAutoUpdate in Row.Attrs) and Modified and not FGrid.FInSetValue then
  begin
    FGrid.FInSetValue := True;
    try
      try
        FGrid.SetRowText(FGrid.FSelRow, Text, False);
      except
      end;
    finally
      FGrid.FInSetValue := False;
    end;
    FGrid.RefreshValues;
  end;
end;

{ a double click on the value of another row: its first click selects the row and puts the edit
  under the mouse, so the second goes to the edit - and Windows makes a double click only of two
  clicks on one window. The edit makes it one itself, as Delphi's TInplaceEdit does (without
  this a double click toggled a flag, cycled a value or made an event handler only on the row
  that was already selected). }
procedure TPropEdit.WndProc(var Message: TMessage);
var
  P: TPoint;
begin
  if Message.Msg = WM_LBUTTONDOWN then
  begin
    if FClickTime <> 0 then
    begin
      P := ClientToScreen(Point(TWMMouse(Message).XPos, TWMMouse(Message).YPos));
      if (Cardinal(GetMessageTime - FClickTime) < GetDoubleClickTime) and
        (Abs(P.X - FClickPos.X) <= GetSystemMetrics(SM_CXDOUBLECLK) div 2) and
        (Abs(P.Y - FClickPos.Y) <= GetSystemMetrics(SM_CYDOUBLECLK) div 2) then
        Message.Msg := WM_LBUTTONDBLCLK;
    end;
    FClickTime := 0;
  end;
  inherited WndProc(Message);
end;

procedure TPropEdit.DblClick;
begin
  inherited;
  if FGrid <> nil then
  begin
    FGrid.FDblPos := Point(Left + 1, Top + 1);      // a double click on the value
    FGrid.DblClick;
  end;
end;

procedure TPropEdit.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if FGrid = nil then
  begin
    inherited;
    Exit;
  end;
  case Key of
    VK_UP, VK_DOWN, VK_PRIOR, VK_NEXT:
      begin
        if FGrid.FListVisible then
        begin
          with FGrid.FList do
            case Key of
              VK_UP: if ItemIndex > 0 then ItemIndex := ItemIndex - 1;
              VK_DOWN: if ItemIndex < Items.Count - 1 then ItemIndex := ItemIndex + 1;
              VK_PRIOR: ItemIndex := Max(0, ItemIndex - 7);
              VK_NEXT: ItemIndex := Min(Items.Count - 1, ItemIndex + 7);
            end;
        end
        else if (Key = VK_DOWN) and (ssAlt in Shift) then
          FGrid.DropDown
        else if (Key = VK_DOWN) and (ssCtrl in Shift) then
        begin
          if Assigned(FGrid.FOnDropInstance) then FGrid.FOnDropInstance(FGrid);
        end
        else
          FGrid.KeyDown(Key, Shift);
        Key := 0;
      end;
    VK_RETURN:
      begin
        if FGrid.FListVisible then
          FGrid.CloseUp(True)
        else if ssCtrl in Shift then
          FGrid.EditDialog
        else
        begin
          if FGrid.ApplyEdit then SelectAll;
        end;
        Key := 0;
      end;
    VK_ESCAPE:
      begin
        if FGrid.FListVisible then FGrid.CloseUp(False) else FGrid.CancelEdit;
        Key := 0;
      end;
    VK_TAB:
      begin
        { the value first: the grid's focus keeps a typed value waiting (WMKillFocus) }
        if FGrid.ApplyEdit and FGrid.CanFocus then FGrid.SetFocus;
        Key := 0;
      end;
    VK_F4:
      begin
        if FGrid.FListVisible then FGrid.CloseUp(False) else FGrid.DropDown;
        Key := 0;
      end;
  end;
  if Key <> 0 then inherited KeyDown(Key, Shift);
end;

procedure TPropEdit.KeyPress(var Key: Char);
begin
  if Key in [#13, #27, #9] then
    Key := #0
  else
    inherited KeyPress(Key);
end;

{ ---------------------------------------------------------------- TPropGrid }

constructor TPropGrid.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csDoubleClicks] - [csAcceptsControls];
  FRows := TList.Create;
  FExpandedCats := TStringList.Create;
  FSelRow := -1;
  FSplit := DefaultSplit;
  FSplitWanted := DefaultSplit;
  FRowH := 16;
  TabStop := True;
  ParentColor := False;
  Color := clBtnFace;
  DoubleBuffered := True;
  FBoldFont := TFont.Create;
  { the drop-down list of Font.Name shows each name in its font (TFontNameProperty's switch) }
  FontNamePropertyDisplayFontNames := True;
  FEdit := TPropEdit.Create(Self);
  FEdit.FGrid := Self;
  FEdit.Parent := Self;
  FEdit.Visible := False;
  FList := TPropListBox.Create(Self);
  FList.FGrid := Self;
  FList.Parent := Self;
end;

destructor TPropGrid.Destroy;
begin
  if FListVisible then CloseUp(False);
  ClearRows;
  FRows.Free;
  FExpandedCats.Free;
  FBoldFont.Free;
  inherited;
end;

procedure TPropGrid.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  { no border of its own: the inspector draws Delphi's 1 px lowered bevel around the list }
  Params.Style := Params.Style or WS_VSCROLL or WS_CLIPCHILDREN;
end;

{ The divider leaves at least 30 px to each column. }
procedure TPropGrid.ApplySplit;
var
  V: Integer;
begin
  V := FSplitWanted;
  if HandleAllocated and (V > ClientWidth - 30) then V := ClientWidth - 30;
  if V < 30 then V := 30;
  if V <> FSplit then
  begin
    FSplit := V;
    if Assigned(FOnSplitChange) then FOnSplitChange(Self);
  end;
end;

procedure TPropGrid.SetSplit(Value: Integer);
begin
  if HandleAllocated and (Value > ClientWidth - 30) then Value := ClientWidth - 30;
  if Value < 30 then Value := 30;
  FSplitWanted := Value;
  ApplySplit;
  PlaceEdit;
  Invalidate;
end;

procedure TPropGrid.CancelList;
begin
  CloseUp(False);
end;

{ The name is drawn in a rectangle that starts here; its text starts 1 px further right
  (x = 13 for a top-level property), like DefaultPropertyDrawName does. }
function TPropGrid.NameLeft(Row: TInspRow): Integer;
begin
  Result := 12 + Row.Level * 10;
end;

{ Top of the text line in a row: the text is centred in the row without its separator line
  (1 px down for the 13 px font of a 16 px row). }
function TPropGrid.TextTop(const R: TRect): Integer;
begin
  Canvas.Font := Font;
  Result := R.Top + Max(0, (FRowH - 1 - Canvas.TextHeight('Wg')) div 2);
end;

{ Right end of the value cell of a row while it is selected: its button, or the edge of the
  list. }
function TPropGrid.ValueRight(Index: Integer): Integer;
begin
  Result := ClientWidth - ButtonWidth(Rows[Index]);
end;

function TPropGrid.GetRow(Index: Integer): TInspRow;
begin
  Result := TInspRow(FRows[Index]);
end;

procedure TPropGrid.ExpandSelected(Expand: Boolean);
begin
  { as a click on the box: the rows below move, the scroll range follows, the list is painted }
  if (FSelRow >= 0) and (FSelRow < RowCount) and (Rows[FSelRow].Expanded <> Expand) then ToggleExpand(FSelRow);
end;

function TPropGrid.RowCount: Integer;
begin
  Result := FRows.Count;
end;

{ A row works on a component that is going: the designer reports a removal while the component
  is still among the root's (csDestroying) - an expanded reference to a component deleted
  without being selected. HasInstance compares pointers only. }
function TPropGrid.ShowsDying: Boolean;
var
  I, K: Integer;
  C: TComponent;
  L: TList;
begin
  Result := False;
  if (FDesigner = nil) or (FDesigner.Root = nil) then Exit;
  { the root's components and those of the frames placed on it }
  L := TList.Create;
  try
    FDesigner.GetDesignedComponents(L);
    for K := 0 to L.Count - 1 do
    begin
      C := TComponent(L[K]);
      if csDestroying in C.ComponentState then
        for I := 0 to FRows.Count - 1 do
          if (Rows[I].Prop <> nil) and Rows[I].Prop.HasInstance(C) then
          begin
            Result := True;
            Exit;
          end;
    end;
  finally
    L.Free;
  end;
end;

function TPropGrid.DebugText: string;
var
  I: Integer;
  Row: TInspRow;
  Mark, Flags: string;
begin
  Result := '';
  for I := 0 to FRows.Count - 1 do
  begin
    Row := TInspRow(FRows[I]);
    if I = FSelRow then Mark := '>' else Mark := ' ';
    { a category: its name in brackets }
    if Row.Category <> nil then
    begin
      Result := Result + Mark + StringOfChar(' ', Row.Level * 2) + '[' + Row.Name + ']' + #13#10;
      Continue;
    end;
    { what the property editor offers: d = dialog (ellipsis button), v = value list,
      + = sub-properties }
    Flags := '';
    if paDialog in Row.Attrs then Flags := Flags + 'd';
    if paValueList in Row.Attrs then Flags := Flags + 'v';
    if paSubProperties in Row.Attrs then Flags := Flags + '+';
    if Flags <> '' then Flags := ' {' + Flags + '}';
    Result := Result + Mark + StringOfChar(' ', Row.Level * 2) + Row.Name + '=' + RowValue(Row) + Flags + #13#10;
  end;
end;

procedure TPropGrid.ClearRows;
var
  I: Integer;
begin
  FListProp := nil;
  for I := 0 to FRows.Count - 1 do
  begin
    TInspRow(FRows[I]).Prop := nil;
    TInspRow(FRows[I]).Free;
  end;
  FRows.Clear;
  FSelRow := -1;
end;

procedure TPropGrid.SetDesigner(ADesigner: TFormDesigner);
begin
  if FListVisible then CloseUp(False);
  FDesigner := ADesigner;
  Rebuild;
end;

var
  AddTarget: TList;
  AddLevel: Integer;
  AddInRef: Boolean;
  AddTop: Boolean = True;         // the rows are properties of the components themselves

procedure TPropGrid.AddProp(const Prop: IProperty);
var
  Row: TInspRow;
  Ref: IReferenceProperty;
begin
  { the host form of a data module or frame has properties its guest does not have; the instance
    of a custom module's class (TFormDesigner.Module) has the root's others - not those the host
    shows }
  if (AddLevel = 0) and (FDesigner <> nil) and (FDesigner.HostKind <> hkForm) and
    (FDesigner.SelectionCount = 1) and (FDesigner.Selections[0] = FDesigner.Root) then
    try
      if IsModuleProp(Prop) then
      begin
        if FDesigner.RootPropVisible(Prop.GetName) then Exit;
      end
      else if not FDesigner.RootPropVisible(Prop.GetName) then Exit;
    except
    end;
  Row := TInspRow.Create;
  Row.Prop := Prop;
  Row.IsRef := Supports(Prop, IReferenceProperty, Ref);
  try
    Row.Name := Prop.GetName;
    Row.Wide := (Prop.GetPropType <> nil) and (Prop.GetPropType^.Kind = tkWString);
    Row.WideEdit := Row.Wide and (Prop.GetAttributes * [paDialog, paValueList] = []);
    Row.Attrs := RowAttrs(Row);
  except
    Row.Name := '?';
  end;
  Row.Level := AddLevel;
  Row.Top := AddTop;
  Row.InRef := AddInRef;
  { the Events page's second pass keeps only component references (References | Show on
    events page) }
  if FRefsOnly and not Row.IsRef then
  begin
    Row.Free;
    Exit;
  end;
  { Show read only properties off: a property that can be neither edited nor expanded goes }
  if not OIOptions.ShowReadOnly and (paReadOnly in Row.Attrs) and
    (Row.Attrs * [paSubProperties, paDialog] = []) then
  begin
    Inc(FHiddenCount);
    Row.Free;
    Exit;
  end;
  { View: a property of hidden categories only is left out; Arrange | by Category: it goes into
    the rows of its categories }
  if AddLevel = 0 then
    if not PlaceInCategories(Row) then
    begin
      Inc(FHiddenCount);
      Row.Free;
      Exit;
    end
    else if FByCategory then
    begin
      Row.Free;
      Exit;
    end;
  AddTarget.Add(Row);
end;

{ The categories of a property, as Delphi's InspAddProperty finds them: every category but
  Miscellaneous whose filters match it - its name, the class of the (first) selected component,
  its type -, else Miscellaneous, which matches everything; each match is counted (the View menu
  lists the categories with matches). The property is shown when one of its categories is
  visible: by name once, by category in each visible one. False: it is hidden. }
function TPropGrid.PlaceInCategories(Row: TInspRow): Boolean;
var
  List: TPropertyCategoryList;
  Misc: TPropertyCategory;
  CompClass: TClass;
  PropType: PTypeInfo;
  I: Integer;
  Matched, Shown: Boolean;

  procedure Place(Cat: TPropertyCategory);
  begin
    Matched := True;
    if not Cat.Visible then Exit;
    Shown := True;
    if FByCategory then CategoryRow(Cat).Props.Add(Row.Prop);
  end;

begin
  Matched := False;
  Shown := False;
  List := PropertyCategoryList;
  Misc := List.MiscCategory;
  CompClass := nil;
  if IsModuleProp(Row.Prop) then CompClass := FDesigner.Module.ClassType
  else if FDesigner.SelectionCount > 0 then CompClass := FDesigner.Selections[0].ClassType;
  try
    PropType := Row.Prop.GetPropType;
  except
    PropType := nil;
  end;
  for I := 0 to List.Count - 1 do
    if (List[I] <> Misc) and List[I].Match(Row.Name, CompClass, PropType) then Place(List[I]);
  if not Matched and Misc.Match(Row.Name, CompClass, PropType) then Place(Misc);
  Result := Shown;
end;

{ the row of a category among the rows being made (by category), a new one if it has none yet:
  Delphi's category editor - its name across the whole row, expandable, nothing to edit }
function TPropGrid.CategoryRow(Cat: TPropertyCategory): TInspRow;
var
  I: Integer;
begin
  for I := 0 to FRows.Count - 1 do
  begin
    Result := Rows[I];
    if Result.Category = Cat then Exit;
  end;
  Result := TInspRow.Create;
  Result.Category := Cat;
  Result.Name := Cat.Name;
  Result.Attrs := [paSubProperties, paReadOnly, paFullWidthName];
  Result.Props := TInterfaceList.Create;
  FRows.Add(Result);
end;

function TPropGrid.IsCategoryRow(Index: Integer): Boolean;
begin
  Result := (Index >= 0) and (Index < FRows.Count) and (Rows[Index].Category <> nil);
end;

{ a row as Delphi's GetItemPath names it: the names from the top down, joined by "." }
function TPropGrid.RowPath(Index: Integer): string;
var
  L: Integer;
begin
  Result := Rows[Index].Name;
  L := Rows[Index].Level;
  while (Index > 0) and (L > 0) do
  begin
    Dec(Index);
    if Rows[Index].Level < L then
    begin
      Result := Rows[Index].Name + '.' + Result;
      L := Rows[Index].Level;
    end;
  end;
end;

{ the row of a path; else the property of the components that has the path's last name (the
  same property in the other arrangement); -1: none }
function TPropGrid.FindRow(const Path: string): Integer;
var
  I: Integer;
  N: string;
begin
  for I := 0 to FRows.Count - 1 do
    if SameText(RowPath(I), Path) then
    begin
      Result := I;
      Exit;
    end;
  N := Path;
  while Pos('.', N) > 0 do Delete(N, 1, Pos('.', N));
  Result := RowByName(N, True);
end;

{ the first row of a name: of a property of the components (TopOnly), else of any (an expanded
  set's flag, a category); -1: none }
function TPropGrid.RowByName(const AName: string; TopOnly: Boolean): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FRows.Count - 1 do
    if (Rows[I].Top or not TopOnly) and SameText(Rows[I].Name, AName) then
    begin
      Result := I;
      Exit;
    end;
end;

procedure TPropGrid.SetByCategory(Value: Boolean);
begin
  if Value = FByCategory then Exit;
  FByCategory := Value;
  Rebuild;
end;

function TPropGrid.GetHiddenCategories: string;
begin
  Result := PropertyCategoryList.HiddenCategories;
end;

procedure TPropGrid.SetHiddenCategories(const Value: string);
begin
  PropertyCategoryList.HiddenCategories := Value;
  Rebuild;
end;

{ Delphi's ViewWhatClick: the categories that matched properties shown now, sorted }
procedure TPropGrid.ViewCategories(L: TStringList);
var
  List: TPropertyCategoryList;
  I: Integer;
begin
  L.Clear;
  List := PropertyCategoryList;
  for I := 0 to List.Count - 1 do
    if List[I].MatchCount > 0 then L.AddObject(List[I].Name, List[I]);
  L.Sort;
end;

{ View | All, Toggle, None: every category, also those of no property shown now }
procedure TPropGrid.ShowCategories(Mode: TPropertyCategoryVisibleMode);
begin
  if PropertyCategoryList.ChangeVisibility(Mode) then Rebuild;
end;

{ Delphi's ViewCategoryClick: a category of View shown or hidden; with Ctrl only this one is
  shown, with Ctrl+Shift all but this one }
procedure TPropGrid.ClickCategory(const Name: string; Shift: TShiftState);
var
  List: TPropertyCategoryList;
  I: Integer;
begin
  List := PropertyCategoryList;
  if ssCtrl in Shift then
  begin
    if ssShift in Shift then
    begin
      if not List.ChangeVisibility(pcvNotListed, [Name]) then Exit;
    end
    else if not List.ChangeVisibility(pcvOnlyListed, [Name]) then Exit;
  end
  else
  begin
    I := List.IndexOf(Name);
    if I < 0 then Exit;
    List[I].Visible := not List[I].Visible;
  end;
  Rebuild;
end;

procedure TPropGrid.Rebuild;
var
  Sel: IDesignerSelections;
  Filter: TTypeKinds;
  I, Keep: Integer;
  KeepName: string;

  { the rows of the properties of S; on the Events page its component references too (References
    | Show on events page) }
  procedure AddRows(const S: IDesignerSelections);
  begin
    GetComponentProperties(S, Filter, FDesigner, AddProp);
    if FEvents and OIOptions.RefOnEvents then
    begin
      FRefsOnly := True;
      try
        GetComponentProperties(S, [tkClass], FDesigner, AddProp);
      finally
        FRefsOnly := False;
      end;
    end;
  end;

begin
  if FInSetValue then
  begin
    FNeedRebuild := True;
    Exit;
  end;
  FNeedRebuild := False;
  if FListVisible then CloseUp(False);
  if (FSelRow >= 0) and (FSelRow < FRows.Count) and (Rows[FSelRow].Top or IsCategoryRow(FSelRow)) then
    FSelName[FEvents] := RowPath(FSelRow);
  KeepName := FSelName[FEvents];
  FEdit.Visible := False;
  ClearRows;
  FHiddenCount := 0;
  { the View menu lists the categories of the properties shown now }
  PropertyCategoryList.ClearMatches;
  if (FDesigner <> nil) and (FDesigner.Root <> nil) then
  begin
    Sel := TDesignerSelections.Create;
    FDesigner.GetSelections(Sel);
    if Sel.Count > 0 then
    begin
      if FEvents then Filter := tkMethods else Filter := tkProperties;
      AddTarget := FRows;
      AddLevel := 0;
      AddInRef := False;
      try
        AddRows(Sel);
        { the root of a custom module: the properties of its class's instance as well (AddProp
          keeps one row of a name) }
        if (FDesigner.Module <> nil) and (Sel.Count = 1) and (Sel[0] = FDesigner.Root) then
        begin
          Sel := TDesignerSelections.Create;
          Sel.Add(FDesigner.Module);
          AddRows(Sel);
        end;
      except
        { a package's property editor failed: the rows made so far are shown, the error is
          kept in error.log }
        on E: Exception do LogException(E, 'Object Inspector: the properties of the selection', SettingsDir + 'error.log');
      end;
      FRows.Sort(CompareRows);
      { the categories expanded before open again (from the last: an expansion moves the rows
        below it) }
      for I := FRows.Count - 1 downto 0 do
        if IsCategoryRow(I) and (FExpandedCats.IndexOf(Rows[I].Name) >= 0) then ExpandRow(I);
    end;
  end;
  FTopRow := 0;
  Keep := FindRow(KeepName);
  if (Keep < 0) and (FRows.Count > 0) then Keep := 0;
  UpdateScrollBar;
  SelectRow(Keep);
  Invalidate;
  if Parent is TObjectInspector then TObjectInspector(Parent).InvalidateStatus;   // "n hidden"
end;

{ the attributes of the row's editor; a WideString row opens the Unicode dialog }
function TPropGrid.RowAttrs(Row: TInspRow): TPropertyAttributes;
begin
  if Row.Category <> nil then
  begin
    Result := Row.Attrs;              // a category's (CategoryRow)
    Exit;
  end;
  Result := Row.Prop.GetAttributes;
  if Row.WideEdit then Include(Result, paDialog);
  { References | Expand inline off: a component reference is not expanded - also when its
    attributes are read again (SelectRow) }
  if Row.IsRef and not OIOptions.RefExpand then Exclude(Result, paSubProperties);
end;

{ several components are selected and their values differ: the value cell stays empty }
function TPropGrid.RowValueMixed(Row: TInspRow): Boolean;
begin
  Result := (paMultiSelect in Row.Attrs) and (FDesigner <> nil) and (FDesigner.SelectionCount > 1) and
    not Row.Prop.AllEqual;
end;

function TPropGrid.RowValue(Row: TInspRow): string;
var
  Sample: TObject;
begin
  RowShows(Row, -1, Result, Sample);
end;

{ the value a row shows and its sample (RowSample; Index: the row's, -1 unknown) at once: ''
  for a value the property editor fails to give - the sample found before stays }
procedure TPropGrid.RowShows(Row: TInspRow; Index: Integer; out Value: string; out Sample: TObject);
begin
  Value := '';
  Sample := nil;
  try
    Sample := RowSample(Row, Index);
    if Sample <> nil then Value := SampleText(Sample)
    else if (Row.Prop <> nil) and not RowValueMixed(Row) then Value := Row.Prop.GetValue;
  except
    Value := '';
  end;
end;

{ The font or the size constraints whose values a row shows in place of its editor's class name
  ("(TFont)"): the same in every selected component at the
  top level, the one component's below it. nil for other rows, for an editor that shows a value
  of its own, and when the selected components differ. Index: the row's (-1: looked for) }
function TPropGrid.RowSample(Row: TInspRow; Index: Integer): TObject;
var
  T: PTypeInfo;
  C: TClass;
  I: Integer;
  Obj: TObject;
begin
  Result := nil;
  if (Row.Prop = nil) or (FDesigner = nil) or (FDesigner.SelectionCount = 0) then Exit;
  T := Row.Prop.GetPropType;
  if (T = nil) or (T^.Kind <> tkClass) then Exit;
  C := GetTypeData(T)^.ClassType;
  if not C.InheritsFrom(TFont) and not C.InheritsFrom(TSizeConstraints) then Exit;
  if Row.Prop.GetValue <> '(' + T^.Name + ')' then Exit;
  if Row.Top then
    for I := 0 to FDesigner.SelectionCount - 1 do
    begin
      Obj := PropObject(TopObject(Row, I), Row.Name);
      if (Obj = nil) or ((Result <> nil) and not SameSample(Result, Obj)) then
      begin
        Result := nil;
        Exit;
      end;
      Result := Obj;
    end
  else if FDesigner.SelectionCount = 1 then
  begin
    if Index < 0 then Index := FRows.IndexOf(Row);
    if Index >= 0 then Result := PropObject(RowInstance(Index), Row.Name);
  end;
end;

{ where a value's text starts: after the glyph of a Boolean, TAlign or TAlignment (at the text's
  place, 4 px before the text) }
function TPropGrid.ValueTextLeft(Index: Integer): Integer;
begin
  Result := TextLeft(ValueGlyph(Rows[Index].Prop, ICustomPropertyDrawing) <> vgNone);
end;

function TPropGrid.TextLeft(HasGlyph: Boolean): Integer;
begin
  Result := FSplit + 3;
  if HasGlyph then Inc(Result, UICheckBoxSize + 4);
end;

{ X lies on the check box of a Boolean's row that can be changed (from the divider to the text) }
function TPropGrid.OnCheckBox(Index, X: Integer): Boolean;
begin
  Result := (Index >= 0) and (Index < FRows.Count) and (X > FSplit) and (X < ValueTextLeft(Index) - 2) and
    not (paFullWidthName in Rows[Index].Attrs) and not (paReadOnly in Rows[Index].Attrs) and
    (ValueGlyph(Rows[Index].Prop, ICustomPropertyDrawing) = vgCheck);
end;

{ a value of the editor's list - the drop-down list, a double click cycling, a check box
  clicked - into the selected row's property }
procedure TPropGrid.ApplyValue(const S: string);
begin
  FUpdatingEdit := True;
  try
    FEdit.Text := S;
  finally
    FUpdatingEdit := False;
  end;
  FEdit.Modified := True;
  ApplyEdit(True);
  if FEdit.Visible then FEdit.SelectAll;
end;

{ a property of the instance of a custom module's class (TFormDesigner.Module): one of the root's
  own, shown with the root's }
function TPropGrid.IsModuleProp(const Prop: IProperty): Boolean;
begin
  Result := (FDesigner <> nil) and (FDesigner.Module <> nil) and (Prop <> nil) and
    Prop.HasInstance(FDesigner.Module);
end;

{ the object of a property of the selected components themselves: the Index-th selected one - for
  one of a custom module's root that the instance of its class holds, that instance }
function TPropGrid.TopObject(Row: TInspRow; Index: Integer): TPersistent;
begin
  if IsModuleProp(Row.Prop) then Result := FDesigner.Module
  else Result := TPersistent(FDesigner.Selections[Index]);
end;

{ the object a row's property belongs to: the (first) selected component for a property of the
  components, the object of the class property above it for a sub-property (Font.Name -> the
  Font) }
function TPropGrid.RowInstance(Index: Integer): TPersistent;
var
  P: Integer;
begin
  Result := nil;
  if (FDesigner = nil) or (FDesigner.SelectionCount = 0) then Exit;
  if Rows[Index].Top then
  begin
    Result := TopObject(Rows[Index], 0);
    Exit;
  end;
  P := Index - 1;
  while (P >= 0) and (Rows[P].Level >= Rows[Index].Level) do Dec(P);
  if P >= 0 then Result := TPersistent(PropObject(RowInstance(P), Rows[P].Name));
end;

{ the value in Unicode: a WideString row read from the property itself }
function TPropGrid.RowValueW(Index: Integer): WideString;
var
  Obj: TPersistent;
begin
  Result := '';
  if not Rows[Index].Wide then
    { the system code page, as the in-place edit shows it (an implicit conversion would use the
      user's locale) }
    Result := ToWide(RowValue(Rows[Index]), CP_ACP)
  else if not RowValueMixed(Rows[Index]) then
    try
      Obj := RowInstance(Index);
      if Obj <> nil then Result := GetWideStrProp(Obj, Rows[Index].Name);
    except
    end;
end;

{ a Unicode value the system code page cannot hold: the in-place edit (ANSI) would lose it, so
  the grid shows it and the dialog edits it }
function TPropGrid.RowIsForeign(Index: Integer): Boolean;
var
  W: WideString;
begin
  Result := False;
  if (Index < 0) or (Index >= FRows.Count) or not Rows[Index].Wide then Exit;
  W := RowValueW(Index);
  FromWide(W, CP_ACP, Result);       // the in-place edit shows the system code page
end;

{ the Unicode dialog for a WideString row; at the top level the value goes to every selected
  component that has the property }
procedure TPropGrid.EditWide(Index: Integer);
var
  W: WideString;
begin
  W := RowValueW(Index);
  if InputDialogWide(GetParentForm(Self), Rows[Index].Name, '&' + Rows[Index].Name + ':', W) then
    SetRowWide(Index, W);
end;

{ a WideString row's value in Unicode, past Borland's editor (it converts with the user's locale);
  at the top level to every selected component that has the
  property. Always the PPropInfo overload: Delphi 7's SetWideStrProp by name hands the value to
  SetStrProp - through an AnsiString in the user's locale (e-acute came back as e, Greek stayed) }
procedure TPropGrid.SetRowWide(Index: Integer; const W: WideString);
var
  Row: TInspRow;
  I: Integer;
  Obj: TPersistent;
  P: PPropInfo;
begin
  Row := Rows[Index];
  if Row.Top then
    for I := 0 to FDesigner.SelectionCount - 1 do
    begin
      Obj := TopObject(Row, I);
      P := GetPropInfo(Obj, Row.Name);
      if P <> nil then SetWideStrProp(Obj, P, W);
    end
  else
  begin
    Obj := RowInstance(Index);
    if Obj <> nil then P := GetPropInfo(Obj, Row.Name) else P := nil;
    if P <> nil then SetWideStrProp(Obj, P, W);
  end;
  FDesigner.Modified;
end;

{ what the in-place edit holds for a row: a WideString row's value read in Unicode and given in
  the system code page, as the edit shows text (the editor's own text would come through the
  user's locale - 1253 here, the code page 1252: "Donn" + e-acute was garbled) }
function TPropGrid.EditText(Index: Integer): string;
var
  Lost: Boolean;
begin
  if Rows[Index].Wide then Result := FromWide(RowValueW(Index), CP_ACP, Lost)
  else Result := RowValue(Rows[Index]);
end;

{ text into a row's property: through its editor - except text typed for a WideString row, which
  is the system code page's (EditText); a value of the editor's own list (ListValue) is its own }
procedure TPropGrid.SetRowText(Index: Integer; const S: string; ListValue: Boolean);
var
  P: IProperty;
begin
  if Rows[Index].Wide and not ListValue then
    SetRowWide(Index, ToWide(S, CP_ACP))
  else
  begin
    P := Rows[Index].Prop;      // held while the editor works
    P.SetValue(BoolText(P, S));
  end;
end;

function TPropGrid.RowIsDefault(Row: TInspRow): Boolean;
var
  P70: IProperty70;
begin
  Result := True;
  try
    if Supports(Row.Prop, IProperty70, P70) then Result := P70.IsDefault;
  except
  end;
end;

procedure TPropGrid.RefreshValues;
begin
  if FInSetValue then Exit;
  if (FSelRow >= 0) and (FSelRow < FRows.Count) and FEdit.Visible and not FEdit.Modified then
  begin
    FUpdatingEdit := True;
    try
      FEdit.Text := EditText(FSelRow);
      FEdit.Font := ValueFont(RowIsDefault(Rows[FSelRow]));
    finally
      FUpdatingEdit := False;
    end;
  end;
  Invalidate;
end;

function TPropGrid.VisibleRows: Integer;
begin
  Result := ClientHeight div FRowH;
  if Result < 1 then Result := 1;
end;

function TPropGrid.RowRect(Index: Integer): TRect;
begin
  Result := Rect(0, (Index - FTopRow) * FRowH, ClientWidth, (Index - FTopRow + 1) * FRowH);
end;

{ Delphi's button is a square over the row without its separator line: 15 x 15 in a 16 px row. }
function TPropGrid.ButtonWidth(Row: TInspRow): Integer;
begin
  if ((paValueList in Row.Attrs) or (paDialog in Row.Attrs)) and not (paFullWidthName in Row.Attrs) then
    Result := FRowH - 1
  else
    Result := 0;
end;

{ ... at the right edge of the list }
function TPropGrid.ButtonRect(Index: Integer): TRect;
var
  R: TRect;
  W: Integer;
begin
  R := RowRect(Index);
  W := ButtonWidth(Rows[Index]);
  Result := Rect(R.Right - W, R.Top, R.Right, R.Bottom - 1);
end;

procedure TPropGrid.UpdateScrollBar;
begin
  if not HandleAllocated then Exit;
  if FTopRow > Max(0, FRows.Count - VisibleRows) then FTopRow := Max(0, FRows.Count - VisibleRows);
  UISetScrollBar(Handle, SB_VERT, FRows.Count, VisibleRows, FTopRow, True);
end;

procedure TPropGrid.SetTopRow(Value: Integer);
begin
  if Value > FRows.Count - VisibleRows then Value := FRows.Count - VisibleRows;
  if Value < 0 then Value := 0;
  if Value <> FTopRow then
  begin
    FTopRow := Value;
    UpdateScrollBar;
    PlaceEdit;
    Invalidate;
  end;
end;

{ The in-place edit is exactly the text line of the value: it starts at the text position
  (split + 3, after a value's glyph: ValueTextLeft) and covers neither the row's first pixel
  line nor the light line of the frame below the text (rows 1..13 of the 16 with the 13 px
  font). }
procedure TPropGrid.PlaceEdit;
var
  R: TRect;
  Row: TInspRow;
  Y, H: Integer;
begin
  if (FSelRow < 0) or (FSelRow >= FRows.Count) or not HandleAllocated then
  begin
    FEdit.Visible := False;
    Exit;
  end;
  Row := Rows[FSelRow];
  R := RowRect(FSelRow);
  if (R.Bottom <= 0) or (R.Top >= ClientHeight) or (paFullWidthName in Row.Attrs) or RowIsForeign(FSelRow) then
  begin
    FEdit.Visible := False;
    Exit;
  end;
  Y := TextTop(R);
  H := Min(Canvas.TextHeight('Wg'), R.Bottom - 1 - Y);
  FEdit.SetBounds(ValueTextLeft(FSelRow), Y, Max(4, ValueRight(FSelRow) - ValueTextLeft(FSelRow)), H);
  { EM_SETMARGINS repaints the whole edit even when the margins stay the same: only when a
    font change gave it margins again }
  if FEdit.HandleAllocated and (SendMessage(FEdit.Handle, EM_GETMARGINS, 0, 0) <> 0) then
    SendMessage(FEdit.Handle, EM_SETMARGINS, EC_LEFTMARGIN or EC_RIGHTMARGIN, 0);
  FEdit.Visible := True;
end;

procedure TPropGrid.SelectRow(Index: Integer; FocusEdit: Boolean);
var
  Row: TInspRow;
  P: IProperty;
  Same: Boolean;
begin
  if FListVisible then CloseUp(False);
  { a value typed into the edit goes in first - also when its own row is chosen again (a click
    on its name), which reloads the edit }
  if FEdit.Visible and FEdit.Modified then
  begin
    Same := Index = FSelRow;
    if not ApplyEdit then Exit;
    if Same then Index := FSelRow;         // the row as a rebuild for the new value left it
  end;
  if Index >= FRows.Count then Index := FRows.Count - 1;
  if Index < 0 then
  begin
    FSelRow := -1;
    FEdit.Visible := False;
    Invalidate;
    Exit;
  end;
  FSelRow := Index;
  Row := Rows[Index];
  if Row.Top or (Row.Category <> nil) then FSelName[FEvents] := RowPath(Index);
  P := Row.Prop;
  try
    if P <> nil then P.Activate;
    Row.Attrs := RowAttrs(Row);
  except
  end;
  if Index < FTopRow then
    SetTopRow(Index)
  else if Index >= FTopRow + VisibleRows then
    SetTopRow(Index - VisibleRows + 1);
  FUpdatingEdit := True;
  try
    FEdit.Text := EditText(Index);
    FEdit.Modified := False;
    FEdit.ReadOnly := paReadOnly in Row.Attrs;
    FEdit.MaxLength := 0;
    try
      if P <> nil then FEdit.MaxLength := P.GetEditLimit;
    except
    end;
    FEdit.Font := ValueFont(RowIsDefault(Row));
  finally
    FUpdatingEdit := False;
  end;
  PlaceEdit;
  if FocusEdit and FEdit.Visible and FEdit.CanFocus then
  begin
    FEdit.SetFocus;
    FEdit.SelectAll;
  end;
  Invalidate;
end;

{ a property of the components by name - arranged by category: in the first category that has
  it, expanded if need be -; else any row of the name (an expanded set's flag, a category) }
procedure TPropGrid.SelectByName(const AName: string);
var
  I, K: Integer;

  { a collapsed category with the property }
  function Holds(Index: Integer): Boolean;
  var
    J: Integer;
  begin
    Result := False;
    if IsCategoryRow(Index) and not Rows[Index].Expanded then
      for J := 0 to Rows[Index].Props.Count - 1 do
        if SameText(IProperty(Rows[Index].Props[J]).GetName, AName) then
        begin
          Result := True;
          Exit;
        end;
  end;

begin
  I := RowByName(AName, True);
  K := 0;
  while (I < 0) and (K < FRows.Count) do
  begin
    if Holds(K) then
    begin
      ToggleExpand(K);
      I := RowByName(AName, True);
    end;
    Inc(K);
  end;
  if I < 0 then I := RowByName(AName, False);
  if I >= 0 then SelectRow(I, True);
end;

procedure TPropGrid.StartEdit(Key: Char);
begin
  if RowIsForeign(FSelRow) then
  begin
    EditDialog;
    Exit;
  end;
  if (FSelRow < 0) or not FEdit.Visible or not FEdit.CanFocus then Exit;
  FEdit.SetFocus;
  if (Key >= ' ') and not FEdit.ReadOnly then
  begin
    FEdit.Text := Key;
    FEdit.Modified := True;
    FEdit.SelStart := 1;
  end
  else
    FEdit.SelectAll;
end;

function TPropGrid.ApplyEdit(ListValue: Boolean): Boolean;
var
  S: string;
begin
  Result := True;
  if (FSelRow < 0) or (FSelRow >= FRows.Count) or not FEdit.Visible or not FEdit.Modified or FInSetValue then Exit;
  S := FEdit.Text;
  FEdit.Modified := False;
  FInSetValue := True;
  try
    try
      SetRowText(FSelRow, S, ListValue);
    except
      on E: Exception do
      begin
        Result := False;
        MessageBox(GetParentForm(Self).Handle, PChar(E.Message), 'Error', MB_OK or MB_ICONERROR);
      end;
    end;
  finally
    FInSetValue := False;
  end;
  if FNeedRebuild then
    Rebuild
  else
  begin
    if (FSelRow >= 0) and (FSelRow < FRows.Count) and (paVolatileSubProperties in Rows[FSelRow].Attrs) and
      Rows[FSelRow].Expanded then
    begin
      CollapseRow(FSelRow);
      ExpandRow(FSelRow);
    end;
    RefreshValues;
  end;
  if not Result and FEdit.Visible and FEdit.CanFocus then
  begin
    FEdit.SetFocus;
    FEdit.SelectAll;
  end;
end;

procedure TPropGrid.CancelEdit;
begin
  if (FSelRow < 0) or (FSelRow >= FRows.Count) then Exit;
  FUpdatingEdit := True;
  try
    FEdit.Text := EditText(FSelRow);
    FEdit.Modified := False;
    FEdit.SelectAll;
  finally
    FUpdatingEdit := False;
  end;
end;

procedure TPropGrid.CollapseRow(Index: Integer);
var
  Lvl, K: Integer;
begin
  if not Rows[Index].Expanded then Exit;
  Lvl := Rows[Index].Level;
  while (Index + 1 < FRows.Count) and (Rows[Index + 1].Level > Lvl) do
  begin
    Rows[Index + 1].Prop := nil;
    Rows[Index + 1].Free;
    FRows.Delete(Index + 1);
  end;
  Rows[Index].Expanded := False;
  if IsCategoryRow(Index) then
  begin
    K := FExpandedCats.IndexOf(Rows[Index].Name);
    if K >= 0 then FExpandedCats.Delete(K);
  end;
end;

{ the sub-properties below a row; a category's properties below the category (remembered: it is
  expanded again when the rows are made again) }
procedure TPropGrid.ExpandRow(Index: Integer);
var
  Sub: TList;
  I: Integer;
  Row: TInspRow;
  P: IProperty;
begin
  Row := Rows[Index];
  if Row.Expanded or not (paSubProperties in Row.Attrs) then Exit;
  Sub := TList.Create;
  try
    AddTarget := Sub;
    AddLevel := Row.Level + 1;
    AddInRef := Row.IsRef or Row.InRef;
    AddTop := Row.Category <> nil;
    P := Row.Prop;
    try
      if Row.Category <> nil then
        for I := 0 to Row.Props.Count - 1 do AddProp(IProperty(Row.Props[I]))
      else
        P.GetProperties(AddProp);
    except
    end;
    { the properties of a category or a referenced component are sorted; set elements and class
      members keep their declaration order }
    if Row.IsRef or (Row.Category <> nil) then Sub.Sort(CompareRows);
    for I := 0 to Sub.Count - 1 do FRows.Insert(Index + 1 + I, Sub[I]);
    Row.Expanded := Sub.Count > 0;
    if Row.Expanded and (Row.Category <> nil) and (FExpandedCats.IndexOf(Row.Name) < 0) then
      FExpandedCats.Add(Row.Name);
  finally
    AddTarget := FRows;
    AddLevel := 0;
    AddInRef := False;
    AddTop := True;
    Sub.Free;
  end;
end;

procedure TPropGrid.ToggleExpand(Index: Integer);
begin
  if (Index < 0) or (Index >= FRows.Count) then Exit;
  if not (paSubProperties in Rows[Index].Attrs) then Exit;
  { rows come or go below Index: the selection moves up to it first - unless the value being
    edited is refused (the edit stays on its row, which must not move under it) }
  if FSelRow > Index then
  begin
    SelectRow(Index);
    if FSelRow <> Index then Exit;
  end;
  if Rows[Index].Expanded then CollapseRow(Index) else ExpandRow(Index);
  UpdateScrollBar;
  PlaceEdit;
  Invalidate;
end;

{ --- drop-down list --- }

var
  ListTarget: TStrings;

procedure TPropGrid.AddListValue(const S: string);
begin
  ListTarget.Add(S);
end;

procedure TPropGrid.DropDown;
var
  Row: TInspRow;
  R: TRect;
  P: TPoint;
  I, H, W, ItemH, MaxW, Cnt, GlyphW: Integer;
  Draw: ICustomPropertyListDrawing;
  Cur: string;
  Mon: TRect;
begin
  if FListVisible or (FSelRow < 0) or (FSelRow >= FRows.Count) then Exit;
  Row := Rows[FSelRow];
  if not (paValueList in Row.Attrs) then Exit;
  FListProp := Row.Prop;
  FList.Font := Font;
  FList.Items.BeginUpdate;
  try
    FList.Items.Clear;
    FList.Sorted := paSortList in Row.Attrs;
    ListTarget := FList.Items;
    try
      FListProp.GetValues(AddListValue);
    except
    end;
  finally
    FList.Items.EndUpdate;
  end;
  if FList.Items.Count = 0 then
  begin
    FListProp := nil;
    Exit;
  end;
  Cur := FEdit.Text;
  FList.ItemIndex := FList.Items.IndexOf(Cur);
  { size: at most eight rows, at least the width of the value column }
  FList.Canvas.Font := Font;
  ItemH := FList.Canvas.TextHeight('Wg') + 2;
  MaxW := ClientWidth - FSplit - 1;
  Supports(FListProp, ICustomPropertyListDrawing, Draw);
  { the room of a Boolean's, TAlign's or TAlignment's glyph before each item }
  if ValueGlyph(FListProp, ICustomPropertyListDrawing) <> vgNone then GlyphW := UICheckBoxSize + 4 else GlyphW := 0;
  Cnt := FList.Items.Count;
  for I := 0 to Cnt - 1 do
  begin
    W := FList.Canvas.TextWidth(FList.Items[I]) + 6 + GlyphW;
    if Draw <> nil then
      try
        Draw.ListMeasureWidth(FList.Items[I], FList.Canvas, W);
      except
      end;
    if Cnt > 8 then Inc(W, GetSystemMetrics(SM_CXVSCROLL));
    if W > MaxW then MaxW := W;
  end;
  H := 0;
  for I := 0 to Min(Cnt, 8) - 1 do
  begin
    W := ItemH;
    if Draw <> nil then
      try
        Draw.ListMeasureHeight(FList.Items[I], FList.Canvas, W);
      except
      end;
    Inc(H, W);
  end;
  Inc(H, 2);
  R := RowRect(FSelRow);
  P := ClientToScreen(Point(ClientWidth - MaxW, R.Bottom));
  Mon := UIWorkArea(Handle);             // Screen's monitors can be stale (nil: an access violation)
  if P.Y + H > Mon.Bottom then P.Y := ClientToScreen(Point(0, R.Top)).Y - H;
  if P.X < Mon.Left then P.X := Mon.Left;
  FList.ShowAt(P.X, P.Y, MaxW, H);
  FListVisible := True;
  HookPopup(FList.Handle, Handle, CancelList);
  Invalidate;
end;

procedure TPropGrid.CloseUp(Accept: Boolean);
var
  S: string;
begin
  if not FListVisible then Exit;
  FListVisible := False;
  UnhookPopup;
  FList.HideList;
  Invalidate;
  if Accept and (FList.ItemIndex >= 0) then
  begin
    S := FList.Items[FList.ItemIndex];
    FListProp := nil;
    ApplyValue(S);
  end
  else
    FListProp := nil;
end;

procedure TPropGrid.CycleValue;
var
  Row: TInspRow;
  L: TStringList;
  I: Integer;
  S: string;
begin
  if (FSelRow < 0) or (FSelRow >= FRows.Count) then Exit;
  Row := Rows[FSelRow];
  if not (paValueList in Row.Attrs) or (paReadOnly in Row.Attrs) then Exit;
  L := TStringList.Create;
  try
    L.Sorted := paSortList in Row.Attrs;
    ListTarget := L;
    try
      Row.Prop.GetValues(AddListValue);
    except
    end;
    if L.Count = 0 then Exit;
    I := L.IndexOf(FEdit.Text) + 1;
    if I >= L.Count then I := 0;
    S := L[I];
  finally
    L.Free;
  end;
  ApplyValue(S);
end;

procedure TPropGrid.EditDialog;
var
  P: IProperty;
begin
  if (FSelRow < 0) or (FSelRow >= FRows.Count) or IsCategoryRow(FSelRow) then Exit;
  if FEdit.Modified and not ApplyEdit then Exit;
  P := Rows[FSelRow].Prop;
  FInSetValue := True;
  try
    try
      if Rows[FSelRow].WideEdit then EditWide(FSelRow) else P.Edit;
    except
      on E: EAbort do ;
      on E: Exception do
        MessageBox(GetParentForm(Self).Handle, PChar(E.Message), 'Error', MB_OK or MB_ICONERROR);
    end;
  finally
    FInSetValue := False;
  end;
  { a property editor may have opened a design window (collection editor, menu designer ...) }
  DesignHost.SyncDesignWindows;
  if FNeedRebuild then Rebuild else RefreshValues;
end;

procedure TPropGrid.ButtonClick;
var
  Row: TInspRow;
begin
  if (FSelRow < 0) or (FSelRow >= FRows.Count) then Exit;
  Row := Rows[FSelRow];
  if paValueList in Row.Attrs then
  begin
    if FListVisible then CloseUp(False) else DropDown;
  end
  else if paDialog in Row.Attrs then
    EditDialog;
end;

{ --- painting --- }

{ behind the selected row's name: a tint of the selection colour }
function SelectionTint: TColor;
begin
  Result := UISelectionTint(OIOptions.Background);
end;

{ the list's font in bold: values that are not the default, the names of categories }
{ the font of a value: bold for one that is not its default, with Bold non-default values }
function TPropGrid.ValueFont(IsDefault: Boolean): TFont;
begin
  if IsDefault or not OIOptions.BoldNonDefault then Result := Font else Result := BoldFont;
end;

function TPropGrid.BoldFont: TFont;
begin
  FBoldFont.Assign(Font);
  FBoldFont.Style := [fsBold];
  Result := FBoldFont;
end;

{ One row, laid out as the Delphi 7 inspector's (R is 16 px high), drawn flat - no classic
  ridged edges:

    x = 2 + 10 * level   expand box, 9 x 9, 3 px below the row top
    x = 13 + 10 * level  name text (clipped at the divider)
    x = split            divider: clBtnShadow
    x = split + 3        value text - or the glyph of a Boolean, TAlign or TAlignment, its
                         text 4 px after it (ValueTextLeft)
    last pixel line      dotted clBtnShadow separator on the even x

  The selected row has a tint of the selection colour behind its name; its value cell is white
  up to the button and the text is shown by the in-place edit. }
procedure TPropGrid.DrawRow(Index: Integer; const R: TRect);
var
  DC: HDC;
  Row: TInspRow;
  NR, VR, TR, BR: TRect;
  NameColor, ValueColor: TColor;
  Draw: ICustomPropertyDrawing;
  Selected, FullName, IsDef, Custom, HaveValue: Boolean;
  State: TUIButtonState;
  CW: Integer;
  Glyph: TValueGlyph;
  Sample: TObject;
  Value: string;
  W: WideString;
begin
  Row := Rows[Index];
  Selected := Index = FSelRow;
  FullName := paFullWidthName in Row.Attrs;
  { asked once per row: does the editor draw the name and the value itself, has the value a glyph
    (ValueGlyph); the value is read once (RowShows), when the row shows it or its glyph }
  Custom := Supports(Row.Prop, ICustomPropertyDrawing, Draw);
  if FullName or Custom then Glyph := vgNone else Glyph := TypeGlyph(Row.Prop);
  HaveValue := False;
  CW := ClientWidth;
  DC := Canvas.Handle;
  UIFill(DC, R, OIOptions.Background);
  if (OIOptions.Gutter <> OIOptions.Background) and (Row.Level > 0) then
    UIFill(DC, Rect(0, R.Top, NameLeft(Row) - 1, R.Bottom), OIOptions.Gutter);
  { name - across the whole row for a category - and the tint behind it }
  if FullName then
    NR := Rect(NameLeft(Row), R.Top, CW, R.Bottom - 1)
  else
    NR := Rect(NameLeft(Row), R.Top, FSplit, R.Bottom - 1);
  if Selected then UIFill(DC, Rect(0, R.Top, NR.Right, R.Bottom - 1), SelectionTint);
  { a category in bold, in its colour (Delphi's category editor draws its name so) }
  if Row.Category <> nil then NameColor := OIOptions.Category
  else if Row.InRef then NameColor := clGreen
  else if Row.IsRef then NameColor := OIOptions.Reference
  { a property that cannot be changed at all (a set is edited through its elements) }
  else if (paReadOnly in Row.Attrs) and not (paSubProperties in Row.Attrs) then NameColor := OIOptions.ReadOnlyName
  else NameColor := OIOptions.NameColor;
  if Row.Category <> nil then Canvas.Font := BoldFont else Canvas.Font := Font;
  Canvas.Font.Color := NameColor;
  if Selected then Canvas.Brush.Color := SelectionTint else Canvas.Brush.Color := OIOptions.Background;
  if NR.Left < NR.Right then
    if Custom then
      try
        Draw.PropDrawName(Canvas, NR, Selected);
      except
      end
    else
    begin
      DC := Canvas.Handle;
      SelectObject(DC, Canvas.Font.Handle);
      TR := Rect(NR.Left + 1, NR.Top, NR.Right, NR.Bottom);
      UIText(DC, Row.Name, TR, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX, NameColor);
    end;
  DC := Canvas.Handle;
  if paSubProperties in Row.Attrs then
    UIDrawExpandBox(DC, 2 + Row.Level * 10, R.Top + (FRowH - 1 - 9) div 2, Row.Expanded);
  { value }
  if not FullName then
    if Selected then
    begin
      { the in-place edit shows the text: only its white cell is painted here - unless the
        value is Unicode text the edit cannot hold }
      UIFill(DC, Rect(FSplit + 1, R.Top, ValueRight(Index), R.Bottom - 1), clWindow);
      if RowIsForeign(Index) then
      begin
        TR := Rect(FSplit + 3, R.Top, ValueRight(Index), R.Bottom - 1);
        UITextW(DC, RowValueW(Index), TR, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX, clWindowText);
      end;
    end
    else
    begin
      { the rectangle a property editor draws into; plain text starts 1 px further right }
      VR := Rect(FSplit + 2, R.Top, CW, R.Bottom - 1);
      IsDef := RowIsDefault(Row);              // once: it walks the property (and an inherited form)
      Canvas.Font := ValueFont(IsDef);
      if IsDef then ValueColor := OIOptions.ValueColor else ValueColor := OIOptions.NonDefault;
      Canvas.Font.Color := ValueColor;
      Canvas.Brush.Color := OIOptions.Background;
      if Custom then
        try
          Draw.PropDrawValue(Canvas, VR, False);
        except
        end
      else
      begin
        { a WideString's value in Unicode (no sample: that is a font's or size constraints'); a
          font's value in its face and style, at the list's size }
        if Row.Wide then
        begin
          Sample := nil;
          W := RowValueW(Index);
        end
        else
        begin
          RowShows(Row, Index, Value, Sample);
          HaveValue := True;
          W := ToWide(Value, CP_ACP);         // the system code page, as RowValueW gives it
        end;
        if Sample is TFont then
        begin
          Canvas.Font.Name := TFont(Sample).Name;
          Canvas.Font.Charset := TFont(Sample).Charset;
          Canvas.Font.Pitch := TFont(Sample).Pitch;
          Canvas.Font.Style := TFont(Sample).Style;
        end;
        DC := Canvas.Handle;
        SelectObject(DC, Canvas.Font.Handle);
        TR := Rect(TextLeft(Glyph <> vgNone), VR.Top, VR.Right, VR.Bottom);
        UITextW(DC, W, TR, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX, ValueColor);
      end;
      DC := Canvas.Handle;
    end;
  { the glyph of a Boolean, TAlign or TAlignment before the text, also in the selected row:
    centred in the row without its separator line }
  if Glyph <> vgNone then
  begin
    if not HaveValue then Value := RowValue(Row);
    DrawValueGlyph(DC, FSplit + 3, R.Top + (FRowH - 1 - UICheckBoxSize) div 2, Glyph, Value,
      not (paReadOnly in Row.Attrs), clGrayText);
  end;
  { separator (Render background grid) and divider }
  if OIOptions.RenderGrid then UIDottedHLine(DC, 0, CW, R.Bottom - 1, clBtnShadow);
  if not FullName then UIVLine(DC, FSplit, R.Top, R.Bottom, clBtnShadow);
  if Selected then
  begin
    if ButtonWidth(Row) > 0 then
    begin
      BR := ButtonRect(Index);
      if FBtnDown then State := bsDown
      else if FBtnHot then State := bsHot
      else State := bsNormal;
      if paValueList in Row.Attrs then
        UIDrawGlyphButton(DC, BR, ugDropArrow, State)
      else
        UIDrawGlyphButton(DC, BR, ugEllipsis, State);
    end;
  end;
end;

{ The rows only: below the last property the list is plain clBtnFace. }
procedure TPropGrid.Paint;
var
  I, Last: Integer;
  R: TRect;
begin
  Canvas.Font := Font;
  Last := Min(FRows.Count - 1, FTopRow + VisibleRows);
  for I := FTopRow to Last do DrawRow(I, RowRect(I));
  R := ClientRect;
  if Last >= FTopRow then R.Top := RowRect(Last).Bottom;
  if R.Top < R.Bottom then UIFill(Canvas.Handle, R, OIOptions.Background);
end;

procedure TPropGrid.CreateWnd;
begin
  inherited CreateWnd;
  UpdateRowHeight;
  ApplySplit;
  UpdateScrollBar;
  PlaceEdit;
end;

{ A row is the text line plus 3 px: 1 above, 1 below and the separator (16 px with the 13 px
  font, as in Delphi). }
procedure TPropGrid.UpdateRowHeight;
var
  H: Integer;
begin
  if not HandleAllocated then Exit;
  Canvas.Font := Font;
  H := Max(16, Canvas.TextHeight('Wg') + 3);
  if H <> FRowH then
  begin
    FRowH := H;
    UpdateScrollBar;
    PlaceEdit;
    Invalidate;
  end;
end;

procedure TPropGrid.CMFontChanged(var Message: TMessage);
begin
  inherited;
  UpdateRowHeight;
end;


procedure TPropGrid.WMSize(var Message: TWMSize);
begin
  inherited;
  ApplySplit;
  UpdateScrollBar;
  PlaceEdit;
  Invalidate;
end;

procedure TPropGrid.WMLButtonDblClk(var Message: TWMLButtonDblClk);
begin
  FDblPos := Point(Message.XPos, Message.YPos);       // DblClick itself gets no position
  inherited;
end;

procedure TPropGrid.SetBtnHot(Value: Boolean);
begin
  if Value <> FBtnHot then
  begin
    FBtnHot := Value;
    Invalidate;
  end;
end;

procedure TPropGrid.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  SetBtnHot(False);
end;

procedure TPropGrid.WMVScroll(var Message: TWMVScroll);
begin
  if FListVisible then CloseUp(False);
  SetTopRow(UIScrollPos(Handle, SB_VERT, Message.ScrollCode, FTopRow, 1, VisibleRows - 1, FRows.Count));
end;

{ three rows per notch; a touch pad's parts of a notch add up }
procedure TPropGrid.WMMouseWheel(var Message: TWMMouseWheel);
begin
  if FListVisible then CloseUp(False);
  SetTopRow(FTopRow - UIWheelSteps(FWheel, Message.WheelDelta, 3));
  Message.Result := 1;
end;

procedure TPropGrid.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_WANTARROWS or DLGC_WANTCHARS or DLGC_WANTTAB;
end;

procedure TPropGrid.WMSetCursor(var Message: TWMSetCursor);
var
  P: TPoint;
begin
  if Message.HitTest = HTCLIENT then
  begin
    GetCursorPos(P);
    P := ScreenToClient(P);
    if Abs(P.X - FSplit) <= 2 then
    begin
      Windows.SetCursor(Screen.Cursors[crHSplit]);
      Message.Result := 1;
      Exit;
    end;
  end;
  inherited;
end;

procedure TPropGrid.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  Invalidate;
end;

procedure TPropGrid.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  if FListVisible and (Message.FocusedWnd <> FEdit.Handle) and (Message.FocusedWnd <> FList.Handle) then
    CloseUp(False);
  Invalidate;
end;

procedure TPropGrid.CMCancelMode(var Message: TCMCancelMode);
begin
  inherited;
  if FListVisible and (Message.Sender <> Self) and (Message.Sender <> FEdit) and (Message.Sender <> FList) then
    CloseUp(False);
end;

{ --- mouse / keyboard --- }

procedure TPropGrid.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Index, BoxX, PrevSel, OpenRow: Integer;
  Check: Boolean;
begin
  inherited;
  if Button <> mbLeft then Exit;
  { a click anywhere in the list closes the open drop-down list; when the click is on the
    button that opened it, the list stays closed: the button toggles }
  PrevSel := FSelRow;
  OpenRow := -1;
  if FListVisible then
  begin
    OpenRow := FSelRow;
    CloseUp(False);
  end;
  if Abs(X - FSplit) <= 2 then
  begin
    FSplitDrag := True;
    Exit;
  end;
  Index := FTopRow + Y div FRowH;
  if (Y < 0) or (Index < 0) or (Index >= FRows.Count) then
  begin
    if CanFocus then SetFocus;
    Exit;
  end;
  if X < FSplit then
  begin
    BoxX := 2 + Rows[Index].Level * 10;
    if (paSubProperties in Rows[Index].Attrs) and (X >= BoxX - 2) and (X <= BoxX + 10) then
    begin
      ToggleExpand(Index);
      Exit;
    end;
    SelectRow(Index, True);
    FocusWithoutEdit;
    BeginRowDrag(Y);
  end
  else
  begin
    Check := OnCheckBox(Index, X);
    SelectRow(Index, True);
    FocusWithoutEdit;
    { a Boolean's check box, in any row: the other value - each click of a double click too, as
      a check box of Windows counts them }
    if Check and (FSelRow = Index) and OnCheckBox(Index, X) then
    begin
      if SameText(RowValue(Rows[Index]), 'True') then ApplyValue('False') else ApplyValue('True');
      Exit;
    end;
    { the button exists on the selected row only: a click on that spot of another row just
      selects the row, as in Delphi }
    if (FSelRow = Index) and (PrevSel = Index) and (ButtonWidth(Rows[Index]) > 0) and
      PtInRect(ButtonRect(Index), Point(X, Y)) then
    begin
      FBtnDown := True;
      Invalidate;
      { value list: opens when the button goes down; the dialog opens when it is released }
      if (paValueList in Rows[Index].Attrs) and (Index <> OpenRow) then DropDown;
    end
    else
    begin
      { the edit now lies under the mouse: a second click there completes a double click }
      FEdit.FClickTime := GetMessageTime;
      FEdit.FClickPos := ClientToScreen(Point(X, Y));
      BeginRowDrag(Y);
    end;
  end;
end;

{ --- the selection follows the mouse while the button is held (Delphi's Object Inspector);
      beyond the top or bottom edge the list scrolls on by itself --- }

procedure TPropGrid.BeginRowDrag(Y: Integer);
begin
  FRowDrag := True;
  FDragY := Y;
  if FDragTimer = nil then
  begin
    FDragTimer := TTimer.Create(Self);
    FDragTimer.Enabled := False;
    FDragTimer.Interval := 60;
    FDragTimer.OnTimer := DragTimerTick;
  end;
end;

{ a row without the in-place edit (a category, a value the edit cannot hold): a click gives the
  keyboard to the list }
procedure TPropGrid.FocusWithoutEdit;
begin
  if not FEdit.Visible and not Focused and CanFocus then SetFocus;
end;

procedure TPropGrid.EndRowDrag;
begin
  FRowDrag := False;
  if FDragTimer <> nil then FDragTimer.Enabled := False;
end;

procedure TPropGrid.TrackRow(Y: Integer);
var
  Index: Integer;
begin
  if FRows.Count = 0 then Exit;
  if Y < 0 then
    Index := FTopRow - 1                          // one row per step above the list
  else if Y >= VisibleRows * FRowH then
    Index := FTopRow + VisibleRows                // ... and below it
  else
    Index := FTopRow + Y div FRowH;
  if Index < 0 then Index := 0;
  if Index >= FRows.Count then Index := FRows.Count - 1;
  if Index <> FSelRow then SelectRow(Index, True);
end;

procedure TPropGrid.DragTimerTick(Sender: TObject);
begin
  { the mouse rests outside the list: keep scrolling towards it }
  if FRowDrag and ((FDragY < 0) or (FDragY >= VisibleRows * FRowH)) then
    TrackRow(FDragY)
  else
    FDragTimer.Enabled := False;
end;

procedure TPropGrid.WMCaptureChanged(var Message: TMessage);
begin
  inherited;
  { the button was released somewhere else, or another window took the mouse }
  if HWND(Message.LParam) <> Handle then
  begin
    EndRowDrag;
    FSplitDrag := False;
  end;
end;

procedure TPropGrid.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if FSplitDrag then
    SetSplit(X)
  else if FRowDrag then
  begin
    if not (ssLeft in Shift) then
      EndRowDrag
    else
    begin
      FDragY := Y;
      TrackRow(Y);
      FDragTimer.Enabled := (Y < 0) or (Y >= VisibleRows * FRowH);
    end;
  end
  else
  begin
    if FBtnDown and not (ssLeft in Shift) then
    begin
      FBtnDown := False;                  // the release went to another window
      Invalidate;
    end;
    SetBtnHot((FSelRow >= 0) and (FSelRow < FRows.Count) and (ButtonWidth(Rows[FSelRow]) > 0) and
      PtInRect(ButtonRect(FSelRow), Point(X, Y)));
  end;
end;

procedure TPropGrid.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  WasDown: Boolean;
begin
  inherited;
  FSplitDrag := False;
  EndRowDrag;
  if FBtnDown then
  begin
    WasDown := (FSelRow >= 0) and (FSelRow < FRows.Count) and PtInRect(ButtonRect(FSelRow), Point(X, Y));
    FBtnDown := False;
    Invalidate;
    { the list button did its work when it went down }
    if WasDown and not (paValueList in Rows[FSelRow].Attrs) then ButtonClick;
  end;
end;

procedure TPropGrid.DblClick;
var
  P: TPoint;
  Row: TInspRow;
begin
  inherited;
  if (FSelRow < 0) or (FSelRow >= FRows.Count) then Exit;
  P := FDblPos;
  Row := Rows[FSelRow];
  { two clicks on the button are two clicks on the button, two on a check box two clicks on it
    (MouseDown) }
  if (ButtonWidth(Row) > 0) and PtInRect(ButtonRect(FSelRow), P) then Exit;
  if OnCheckBox(FSelRow, P.X) then Exit;
  { on the name - a category's is the whole row - they expand or collapse }
  if ((P.X < FSplit) or (paFullWidthName in Row.Attrs)) and (paSubProperties in Row.Attrs) then
    ToggleExpand(FSelRow)
  else if (paDialog in Row.Attrs) or FEvents then
    EditDialog
  else if paValueList in Row.Attrs then
    CycleValue
  else if paSubProperties in Row.Attrs then
    ToggleExpand(FSelRow);
end;

procedure TPropGrid.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  case Key of
    VK_UP: SelectRow(Max(0, FSelRow - 1), FEdit.Focused);
    VK_DOWN:
      if ssCtrl in Shift then
      begin
        if Assigned(FOnDropInstance) then FOnDropInstance(Self);    // Delphi: the instance list
      end
      else
        SelectRow(Min(FRows.Count - 1, FSelRow + 1), FEdit.Focused);
    VK_PRIOR: SelectRow(Max(0, FSelRow - VisibleRows + 1), FEdit.Focused);
    VK_NEXT: SelectRow(Min(FRows.Count - 1, FSelRow + VisibleRows - 1), FEdit.Focused);
    VK_HOME: if ssCtrl in Shift then SelectRow(0, FEdit.Focused);
    VK_END: if ssCtrl in Shift then SelectRow(FRows.Count - 1, FEdit.Focused);
    VK_RIGHT, VK_ADD:
      if Focused and (FSelRow >= 0) and not Rows[FSelRow].Expanded then ToggleExpand(FSelRow);
    VK_LEFT, VK_SUBTRACT:
      if Focused and (FSelRow >= 0) and Rows[FSelRow].Expanded then ToggleExpand(FSelRow);
    VK_RETURN, VK_TAB:
      if Focused and FEdit.Visible and FEdit.CanFocus then
      begin
        FEdit.SetFocus;
        FEdit.SelectAll;
      end;
  else
    Exit;
  end;
  Key := 0;
end;

procedure TPropGrid.KeyPress(var Key: Char);
var
  I, N, Start: Integer;
begin
  inherited KeyPress(Key);
  if Key < ' ' then Exit;
  { incremental search in the name column }
  if GetTickCount - FSearchTick > 1000 then FSearch := '';
  FSearchTick := GetTickCount;
  FSearch := FSearch + Key;
  N := FRows.Count;
  if N = 0 then Exit;
  Start := Max(0, FSelRow);
  if Length(FSearch) = 1 then Inc(Start);
  for I := 0 to N - 1 do
    if SameText(Copy(Rows[(Start + I) mod N].Name, 1, Length(FSearch)), FSearch) then
    begin
      SelectRow((Start + I) mod N);
      Break;
    end;
  Key := #0;
end;

{ ---------------------------------------------------------------- TObjectInspector }

{ The form of the Delphi 7 inspector, top to bottom:

    instance box       text height + 8 (21)                        full width
    gap                2
    tab control        its tabs + 5 (25), 1 px in from the left     a standard tab control cut
                                                                    off just below its tabs
    list               in a 1 px lowered bevel, to the bottom       full width

  The pane adds 2 px above the box. }
type
  { the instance box's messages the VCL's combo box leaves to it: a choice in the open list
    (CBN_SELENDOK: it counts when the list closes), the box while no single component is
    selected (the empty text: "3 items selected") }
  TInstanceBoxHook = class(TUIWindowHook)
  private
    FInsp: TObjectInspector;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TInstanceBoxHook.Hook(var Message: TMessage);
var
  Old: HGDIOBJ;
  R: TRect;
begin
  case Message.Msg of
    CN_COMMAND:
      if (TWMCommand(Message).NotifyCode = CBN_SELENDOK) and FInsp.FDropped then FInsp.FChosen := True;
    CN_DRAWITEM:
      with TWMDrawItem(Message).DrawItemStruct^ do
        if Integer(itemID) < 0 then
        begin
          UIFill(hDC, rcItem, clWindow);
          R := Rect(rcItem.Left + 2, rcItem.Top, rcItem.Right, rcItem.Bottom);
          Old := SelectObject(hDC, FInsp.InstanceBox.Font.Handle);
          UIText(hDC, FInsp.FEmptyText, R, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX, clWindowText);
          SelectObject(hDC, Old);
          Message.Result := 1;
          Exit;
        end;
  end;
  FOldProc(Message);
end;

constructor TObjectInspector.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form docked as a child keeps its own font }
  UIApplyFont(Self);
  FShown := -1;
  InstanceBox.ItemHeight := UIEditHeight - 6;          // the box as high as an edit
  UIFlatBorder(InstanceBox);          // the grid's border colour, not the theme's
  TInstanceBoxHook.Create(InstanceBox, True).FInsp := Self;
  FTabs := TSdTabStrip.Create(Self);
  FTabs.Parent := Self;
  FTabs.Side := tsTop;
  FTabs.Tabs.Add('Properties');
  FTabs.Tabs.Add('Events');
  FTabs.TabIndex := 0;
  FTabs.OnChange := TabsChange;
  FGrid := TPropGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.OnSplitChange := GridSplitChange;
  FGrid.OnDropInstance := GridDropInstance;
  FClassX := FGrid.Split + 2;
end;

{ Paint fills the whole view: nothing to erase first }
procedure TObjectInspector.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

function TObjectInspector.InstanceText: string;
begin
  if (InstanceBox.ItemIndex >= 0) and (InstanceBox.ItemIndex < InstanceBox.Items.Count) then
    Result := InstanceBox.Items[InstanceBox.ItemIndex]
  else
    Result := FEmptyText;
end;

procedure TObjectInspector.SetShown(Value: Integer);
begin
  if Value >= InstanceBox.Items.Count then Value := InstanceBox.Items.Count - 1;
  if Value < -1 then Value := -1;
  FShown := Value;
  InstanceBox.ItemIndex := Value;
  InstanceBox.Invalidate;
end;

procedure TObjectInspector.SetClassX(Value: Integer);
begin
  if Value <> FClassX then
  begin
    FClassX := Value;
    InstanceBox.Invalidate;
  end;
end;

procedure TObjectInspector.SetEmptyText(const Value: string);
begin
  if Value <> FEmptyText then
  begin
    FEmptyText := Value;
    InstanceBox.Invalidate;
  end;
end;

procedure TObjectInspector.Pick;
begin
  if (InstanceBox.ItemIndex < 0) or (InstanceBox.ItemIndex = FShown) then Exit;
  FShown := InstanceBox.ItemIndex;
  BoxChange;
end;

{ the grid's value list closes when this one opens }
procedure TObjectInspector.InstanceDropDown(Sender: TObject);
begin
  CancelOpenPopup;
  FDropped := True;
  FChosen := False;
end;

procedure TObjectInspector.InstanceSelect(Sender: TObject);
begin
  if not FDropped then Pick;
end;

procedure TObjectInspector.InstanceCloseUp(Sender: TObject);
begin
  FDropped := False;
  if FChosen then
  begin
    FChosen := False;
    Pick;
    BoxAccepted;
  end
  else if InstanceBox.ItemIndex <> FShown then
    InstanceBox.ItemIndex := FShown;                   // cancelled: the component shown again
end;

{ The name, and the class name in the column of the values below - in the box (its client
  area) and in the list (whose client area starts 1 px further right on the screen). }
procedure TObjectInspector.InstanceDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  N, C: string;
  X, Y: Integer;
  Cv: TCanvas;
begin
  Cv := InstanceBox.Canvas;
  if odSelected in State then
  begin
    Cv.Brush.Color := clHighlight;
    Cv.Font.Color := clHighlightText;
  end
  else
  begin
    Cv.Brush.Color := clWindow;
    Cv.Font.Color := clWindowText;
  end;
  Cv.FillRect(Rect);
  SplitInstance(InstanceBox.Items[Index], N, C);
  if not OIOptions.ShowClassNames then C := '';
  if odComboBoxEdit in State then X := FClassX + 2 else X := Rect.Left + FClassX + 1;
  Y := Rect.Top + (Rect.Bottom - Rect.Top - Cv.TextHeight('Wg')) div 2;
  Cv.TextRect(Classes.Rect(Rect.Left, Rect.Top, Max(Rect.Left, X - 2), Rect.Bottom), Rect.Left + 2, Y, N);
  if not (odSelected in State) then Cv.Font.Color := clGrayText;
  if (C <> '') and (X < Rect.Right) then
    Cv.TextRect(Classes.Rect(X, Rect.Top, Rect.Right, Rect.Bottom), X, Y, C);
end;

procedure TObjectInspector.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

procedure TObjectInspector.CreateWnd;
begin
  inherited CreateWnd;
  Layout;
end;



procedure TObjectInspector.Layout;
var
  H, Y, W, StripH: Integer;
begin
  if (FTabs = nil) or (FGrid = nil) then Exit;
  W := ClientWidth;
  H := UIEditHeight;
  { Show instance list }
  InstanceBox.Visible := OIOptions.ShowInstanceList;
  if InstanceBox.Visible then
  begin
    InstanceBox.SetBounds(0, 0, W, H);        // right under the dock's gap below the caption
    Y := H + 2;
  end
  else
    Y := 2;
  { Show status bar: a line of text below the list }
  if OIOptions.ShowStatusBar then FStatusTop := ClientHeight - (H - 2) else FStatusTop := 0;
  StripH := UIDockTabHeight;
  FTabs.SetBounds(1, Y, Max(0, W - 2), StripH);
  FFrameTop := Y + StripH;
  if FStatusTop > 0 then
    FGrid.SetBounds(1, FFrameTop + 1, Max(0, W - 2), Max(0, FStatusTop - FFrameTop - 2))
  else
    FGrid.SetBounds(1, FFrameTop + 1, Max(0, W - 2), Max(0, ClientHeight - FFrameTop - 2));
  Invalidate;
end;

{ the status bar again: what the list leaves out changed }
procedure TObjectInspector.InvalidateStatus;
var
  R: TRect;
begin
  if not HandleAllocated or (FStatusTop <= 0) then Exit;
  R := Rect(0, FStatusTop, ClientWidth, ClientHeight);
  InvalidateRect(Handle, @R, False);
end;

procedure TObjectInspector.OptionsChanged;
begin
  Layout;
  InstanceBox.Invalidate;
  if FGrid <> nil then
  begin
    FGrid.Rebuild;
    FGrid.Invalidate;
  end;
end;

procedure TObjectInspector.Resize;
begin
  inherited;
  if HandleAllocated then Layout;
end;

procedure TObjectInspector.Paint;
var
  DC: HDC;
  S: string;
  TR: TRect;
begin
  DC := Canvas.Handle;
  UIFill(DC, ClientRect, clBtnFace);
  if FStatusTop > 0 then
  begin
    if FFrameTop < FStatusTop then UIDrawBorder(DC, Rect(0, FFrameTop, ClientWidth, FStatusTop));
    { as Delphi's: what the list leaves out }
    if (FGrid <> nil) and (FGrid.HiddenCount > 0) then S := Format('%d hidden', [FGrid.HiddenCount])
    else S := 'All shown';
    SelectObject(DC, Font.Handle);
    TR := Rect(4, FStatusTop, ClientWidth - 4, ClientHeight);
    UIText(DC, S, TR, DT_LEFT or DT_VCENTER or
      DT_SINGLELINE or DT_NOPREFIX, clBtnText);
  end
  else if FFrameTop < ClientHeight then
    UIDrawBorder(DC, Rect(0, FFrameTop, ClientWidth, ClientHeight));
end;

procedure TObjectInspector.SetDesigner(ADesigner: TFormDesigner);
begin
  if FDesigner = ADesigner then
  begin
    SelectionChanged;
    Exit;
  end;
  FDesigner := ADesigner;
  FGrid.SetDesigner(ADesigner);
  FillBox;
  SyncBox;
end;

procedure TObjectInspector.FillBox;
var
  I: Integer;
  C: TComponent;
  L: TList;
begin
  if InstanceBox.HandleAllocated then InstanceBox.DroppedDown := False;
  InstanceBox.Items.BeginUpdate;
  L := TList.Create;
  try
    InstanceBox.Items.Clear;
    if (FDesigner <> nil) and (FDesigner.Root <> nil) then
    begin
      C := FDesigner.Root;
      InstanceBox.Items.AddObject(C.Name + ': ' + C.ClassName, C);
      { not one that is going: a removal is reported while it is still among the root's; a placed
        frame's components after it by their path (Frame21.Button1) }
      FDesigner.GetDesignedComponents(L);
      for I := 0 to L.Count - 1 do
      begin
        C := TComponent(L[I]);
        if (C.Name <> '') and not (csDestroying in C.ComponentState) then
          InstanceBox.Items.AddObject(FDesigner.GetComponentName(C) + ': ' + C.ClassName, C);
      end;
    end;
  finally
    L.Free;
    InstanceBox.Items.EndUpdate;
  end;
  SetShown(-1);
end;

procedure TObjectInspector.SyncBox;
var
  I, N: Integer;
begin
  I := -1;
  N := 0;
  if FDesigner <> nil then N := FDesigner.SelectionCount;
  if N = 1 then
  begin
    I := InstanceBox.Items.IndexOfObject(FDesigner.Selections[0]);
    if I < 0 then
    begin
      { a component the list does not know yet (a design window just created it) }
      FillBox;
      I := InstanceBox.Items.IndexOfObject(FDesigner.Selections[0]);
    end;
  end;
  if N > 1 then SetEmptyText(Format('%d items selected', [N])) else SetEmptyText('');
  SetShown(I);
end;

procedure TObjectInspector.BoxChange;
begin
  if (FDesigner = nil) or (InstanceBox.ItemIndex < 0) then Exit;
  FDesigner.Select(TPersistent(InstanceBox.Items.Objects[InstanceBox.ItemIndex]));
end;

{ a component was picked from the list: the keyboard goes on in the property list }
procedure TObjectInspector.BoxAccepted;
begin
  if FGrid.CanFocus then FGrid.SetFocus;
end;

{ Ctrl+Down in the property list drops the instance list }
procedure TObjectInspector.GridDropInstance(Sender: TObject);
begin
  if InstanceBox.CanFocus then InstanceBox.SetFocus;
  InstanceBox.DroppedDown := True;
end;

{ the class name of the instance box starts where the values start }
procedure TObjectInspector.GridSplitChange(Sender: TObject);
begin
  SetClassX(FGrid.Split + 2);
end;

procedure TObjectInspector.TabsChange(Sender: TObject);
begin
  if FGrid.ListVisible then FGrid.CloseUp(False);
  FGrid.ApplyEdit;
  FGrid.Events := FTabs.TabIndex = 1;
  FGrid.Rebuild;
end;

procedure TObjectInspector.ShowEvents(Value: Boolean);
begin
  if (FTabs.TabIndex = 1) <> Value then
  begin
    FTabs.TabIndex := Ord(Value);
    TabsChange(FTabs);
  end;
end;

function TObjectInspector.DebugText: string;
begin
  Result := 'instance=' + InstanceText + #13#10 +
    Format('toprow=%d', [FGrid.FTopRow]) + #13#10 +
    Format('droplist=%d instlist=%d split=%d', [Ord(FGrid.ListVisible), Ord(InstanceBox.DroppedDown), FGrid.Split]) + #13#10 +
    { Arrange, the hidden categories, the properties left out, the categories expanded }
    Format('arrange=%s hidden=%s hiddencount=%d expanded=%s',
      [ArrangeNames[FGrid.ByCategory], FGrid.HiddenCategories, FGrid.HiddenCount, FGrid.FExpandedCats.CommaText]) + #13#10 +
    FGrid.DebugText;
end;

procedure TObjectInspector.SelectionChanged;
begin
  SyncBox;
  FGrid.Rebuild;
end;

procedure TObjectInspector.StructureChanged;
begin
  FillBox;
  SyncBox;
  { the rows of a component that is going (not selected: that rebuilds on its own) go now,
    before anything reads their values }
  if FGrid.ShowsDying then FGrid.Rebuild;
end;

procedure TObjectInspector.RefreshValues;
begin
  FGrid.RefreshValues;
end;

procedure TObjectInspector.FocusProperty(Key: Char; const PropName: string);
begin
  if PropName <> '' then
  begin
    ShowEvents(False);
    FGrid.SelectByName(PropName);
  end
  else
    FGrid.StartEdit(Key);
end;

end.
