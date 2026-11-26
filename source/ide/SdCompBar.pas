{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCompBar;

{ D7 Studio - the Components view: the components of the installed
  packages as a list that is filtered as one types, after Component Bar (an expert for Delphi
  5 ... 2006). It replaced the component palette.

  * a category box: All Components, or one page of the palette (Delphi's order; Environment
    Options | Palette arranges and hides them);
  * a filter box: the names that contain the text, those that begin with it first; * and ?
    make it a mask. Typing in the list goes to the filter;
  * the list: icon and name of each component (the category below the name unless hidden) -
    Delphi 7's Frames tool among them, first on Standard (the owner inserts a frame for it)
    - in the order of Component Bar's sort modes (by name, last used, most used, the palette's). Two looks: the
    classic one (the default) and the current one (the icon as it is, the UI font). The classic one,
    Component Bar's own (on clBtnFace in clBtnText, the icon on Delphi 7's raised 28 x 28
    tile, the category in Small Fonts, the components added from the view before in bold).

  Enter or a double click chooses the selected component (OnChoose: the owner's Add to Form,
  which calls AddSelected; without it AddSelected itself), AddSelected adds it to the form being
  designed (OnAdd); a
  drag onto the form drops it there (OnCanDrop, OnDrop); Esc during the drag ends it without a
  drop. Otherwise Esc clears the filter (then the category), Shift+Up / Shift+Down choose the
  previous / next category. Positions come from the mouse messages. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, StdCtrls, Forms, Masks, Menus, ActnList,
  SdUI, SdDesignHost;

type
  TSdCompAddEvent = procedure(Sender: TObject; Cls: TComponentClass; var Done: Boolean) of object;
  TSdCompDropEvent = procedure(Sender: TObject; Cls: TComponentClass; const ScreenPt: TPoint;
    var Done: Boolean) of object;
  TSdCompCanDropEvent = procedure(Sender: TObject; const ScreenPt: TPoint; var Accept: Boolean) of object;
  { Component Bar's sort modes: by name, the last used first, the most used first, the palette's order }
  TSdCompSort = (csName, csRecentlyUsed, csMostUsed, csPaletteOrder);

  { A filter of component names, typed in a search box (the Components view, View | Component
    List): the text, or a mask with * and ?. A text that cannot be a mask ("[" without "]", more
    than 30 "*") matches nothing - the box is being typed in, an exception on every key would
    be no help. }
  TSdNameFilter = class
  private
    FText: string;
    FIsMask: Boolean;
    FMask: TMask;
  public
    constructor Create(const Text: string);
    destructor Destroy; override;
    { 1: the name starts with the text (or matches the mask; also for no text); > 1: it holds
      the text further on; 0: no match }
    function Match(const Name: string): Integer;
  end;

  { the view: a form made once (its boxes, its list and their events in the .dfm), docked by
    the IDE - a child window then, without a border }
  TSdComponentBar = class(TForm)
    Category: TComboBox;
    Filter: TEdit;
    List: TListBox;
    MenuActions: TActionList;
    aCompAdd: TAction;
    aCompShowCategory: TAction;
    aCompAll: TAction;
    aCompSortName: TAction;
    aCompSortRecent: TAction;
    aCompSortMost: TAction;
    aCompSortPalette: TAction;
    aCompProperties: TAction;
    CompPopup: TPopupMenu;
    pmComp1: TMenuItem;
    pmComp2: TMenuItem;
    pmComp3: TMenuItem;
    pmComp4: TMenuItem;
    pmCompSort: TMenuItem;
    pmCompSort0: TMenuItem;
    pmCompSort1: TMenuItem;
    pmCompSort2: TMenuItem;
    pmCompSort3: TMenuItem;
    pmComp5: TMenuItem;
    pmComp11: TMenuItem;
    procedure CategoryChange(Sender: TObject);
    procedure FilterChange(Sender: TObject);
    procedure FilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SwallowKeyPress(Sender: TObject; var Key: Char);
    procedure ListClick(Sender: TObject);
    procedure ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ListKeyPress(Sender: TObject; var Key: Char);
    procedure ListDblClick(Sender: TObject);
    procedure ListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure ListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure ListMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure ListMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  private
    FReloadPending: Boolean;          // the palette changed while the view had no window
    FPressed, FDragging: Boolean;
    FDragFrom: TPoint;
    FDragClass: TComponentClass;
    FDragItem: TPaletteItem;         // what is dragged (a component template too)
    FOnAdd: TSdCompAddEvent;
    FOnChoose: TNotifyEvent;
    FOnDrop: TSdCompDropEvent;
    FOnCanDrop: TSdCompCanDropEvent;
    FClassic: Boolean;
    FHideCategory: Boolean;
    FUsed: TStringList;           // the components added from the view: Class=count;last use
    FUsedIndex: TStringList;      // ... their class names, sorted; Objects: the line in FUsed (UsageOf)
    FUsedStale: Boolean;          // ... FUsed changed since FUsedIndex was made
    FSortMode: TSdCompSort;
    FResetDelay: Integer;         // seconds after which typing in the list starts a new filter
    FLastTyped: Cardinal;         // GetTickCount of the last character typed into the list
    FListColor: TColor;           // clDefault: the look's own
    FSmallFont: TFont;            // the classic look's category: Small Fonts 7
    FRowBmp: TBitmap;             // a row is drawn here first
    FListFrame: TRect;            // the bevel around the list (the Object Inspector's)
    FChosenClass: TComponentClass;  // the item chosen (NoteChoice): its class ...
    FChosenCaption: string;         // ... and its caption ('' for a component)
    procedure SetClassic(Value: Boolean);
    procedure SetHideCategory(Value: Boolean);
    procedure UpdateRowHeight;
    procedure MarkUsed(Cls: TComponentClass);
    procedure SetSortMode(Value: TSdCompSort);
    procedure SetListColor(Value: TColor);
    function UsageOf(const ClassName: string; out Count: Integer; out Last: TDateTime): Boolean;
    procedure UsedChanged(Sender: TObject);
    procedure IndexUsed;
    function GetUsed: TStrings;
    procedure Refill;
    procedure NoteChoice;
    procedure StepCategory(Delta: Integer);
    procedure FilterKey(var Key: Word; Shift: TShiftState);
    procedure ListCancel;
    procedure StopDrag;
  protected
    procedure CreateWnd; override;
    procedure Resize; override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Reload;                           // the palette changed (packages, its layout)
    procedure AddSelected;                      // Add to Form
    procedure Choose;                           // Enter, a double click: OnChoose, else AddSelected
    procedure ShowCategory(const Name: string); // '' = All Components
    function SelectedClass: TComponentClass;
    { the item chosen / dragged: a component template has its text (TPaletteItem.Template) }
    function SelectedItem: TPaletteItem;
    property DragItem: TPaletteItem read FDragItem;
    function SelectedCategory: string;
    function DebugText: string;
    property Classic: Boolean read FClassic write SetClassic;              // Component Bar's look (default)
    property HideCategory: Boolean read FHideCategory write SetHideCategory;   // False by default
    property Used: TStrings read GetUsed;      // kept by the owner (the settings): Class=count;last use
    property SortMode: TSdCompSort read FSortMode write SetSortMode;           // csName by default
    property ResetDelay: Integer read FResetDelay write FResetDelay;           // 0: never
    property ListColor: TColor read FListColor write SetListColor;             // clDefault: the look's
    property OnAdd: TSdCompAddEvent read FOnAdd write FOnAdd;
    property OnChoose: TNotifyEvent read FOnChoose write FOnChoose;
    property OnDrop: TSdCompDropEvent read FOnDrop write FOnDrop;
    property OnCanDrop: TSdCompCanDropEvent read FOnCanDrop write FOnCanDrop;
  end;

const
  AllComponents = 'All Components';

{ the keys of a list that the search box above it passes on (Up, Down, Page Up, Page Down): the
  list box moves its own selection; True and Key 0 when it was one of them }
function ForwardListKey(List: TWinControl; var Key: Word): Boolean;

implementation

{$R *.dfm}

uses
  CommCtrl;

function ForwardListKey(List: TWinControl; var Key: Word): Boolean;
begin
  Result := Key in [VK_UP, VK_DOWN, VK_PRIOR, VK_NEXT];
  if not Result then Exit;
  SendMessage(List.Handle, WM_KEYDOWN, Key, 0);
  Key := 0;
end;

{ ---------------------------------------------------------------- TSdNameFilter }

constructor TSdNameFilter.Create(const Text: string);
begin
  inherited Create;
  FText := AnsiUpperCase(Trim(Text));
  FIsMask := (Pos('*', FText) > 0) or (Pos('?', FText) > 0);
  if FIsMask then
    try
      FMask := TMask.Create(FText);
    except
      on EMaskException do FMask := nil;
    end;
end;

destructor TSdNameFilter.Destroy;
begin
  FMask.Free;
  inherited;
end;

function TSdNameFilter.Match(const Name: string): Integer;
begin
  if FText = '' then Result := 1
  else if FIsMask then Result := Ord((FMask <> nil) and FMask.Matches(Name))
  else Result := Pos(FText, AnsiUpperCase(Name));
end;

const
  Gap = 2;                    // between the boxes and the list

var
  { the numbers of the usage list (TSdComponentBar.Used): '.' as the decimal separator, whatever
    the user's locale has }
  UsageFormat: TFormatSettings;


{ ---------------------------------------------------------------- the boxes' hooks }

type
  TListAccess = class(TListBox);

  { the filter box: a hint in it while it is empty, set again with each new window }
  TFilterHook = class(TUIWindowHook)
  protected
    procedure Hook(var Message: TMessage); override;
  end;

  { The list: the left button is handled here, not by the list box. A press chooses the item
    under it and takes the mouse; moving and letting go then belong to the drag alone - the
    list box's own tracking chose the item under the pointer while a component was dragged and
    scrolled at the edges. The press ends without being let go on the list when another window
    takes the mouse, or on Esc (which then goes no further: the filter keeps its text). }
  TCompListHook = class(TUIWindowHook)
  private
    FBar: TSdComponentBar;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TFilterHook.Hook(var Message: TMessage);
const
  Cue: WideString = 'Filter (* and ? for a mask)';
begin
  FOldProc(Message);
  if Message.Msg = WM_CREATE then SendMessage(FControl.Handle, EM_SETCUEBANNER, 0, Integer(PWideChar(Cue)));
end;

procedure TCompListHook.Hook(var Message: TMessage);
var
  L: TListAccess;
  P: TPoint;
  I: Integer;
  Shift: TShiftState;
  R: TRect;
begin
  L := TListAccess(FControl);
  case Message.Msg of
    WM_ERASEBKGND:
      begin
        { the rows paint themselves whole (a bitmap each): only what lies below the last one,
          or a resize shows the bare background over every row first (flicker) }
        R := L.ClientRect;
        if L.Items.Count > 0 then R.Top := L.ItemRect(L.Items.Count - 1).Bottom;
        if R.Top < 0 then R.Top := 0;
        if R.Top < R.Bottom then FillRect(TWMEraseBkgnd(Message).DC, R, L.Brush.Handle);
        Message.Result := 1;
        Exit;
      end;
    WM_SETFOCUS, WM_KILLFOCUS:
      begin
        { the selected row changes its colours with the focus }
        FOldProc(Message);
        if L.HandleAllocated and (L.ItemIndex >= 0) then
        begin
          R := L.ItemRect(L.ItemIndex);
          InvalidateRect(L.Handle, @R, False);
        end;
        Exit;
      end;
    WM_LBUTTONDOWN, WM_LBUTTONDBLCLK:
      begin
        P := SmallPointToPoint(TWMMouse(Message).Pos);
        Shift := KeysToShiftState(TWMMouse(Message).Keys);
        I := L.ItemAtPos(P, True);
        if I >= 0 then L.ItemIndex := I;
        if L.CanFocus and not L.Focused then L.SetFocus;
        L.MouseCapture := True;
        if Message.Msg = WM_LBUTTONDBLCLK then L.DblClick
        else L.MouseDown(mbLeft, Shift, P.X, P.Y);
        Message.Result := 0;
        Exit;
      end;
    WM_MOUSEMOVE:
      if L.MouseCapture then
      begin
        L.MouseMove(KeysToShiftState(TWMMouse(Message).Keys), TWMMouse(Message).XPos, TWMMouse(Message).YPos);
        Message.Result := 0;
        Exit;
      end;
    WM_LBUTTONUP:
      if L.MouseCapture then
      begin
        L.MouseCapture := False;
        L.MouseUp(mbLeft, KeysToShiftState(TWMMouse(Message).Keys), TWMMouse(Message).XPos, TWMMouse(Message).YPos);
        Message.Result := 0;
        Exit;
      end;
    WM_CAPTURECHANGED:
      if UICaptureLost(L, Message) then FBar.ListCancel;
    CN_KEYDOWN:
      { Esc while the button is down ends the press; the list keeps the mouse, so letting go
        still comes here (and drops nothing) }
      if UIPressEscape(L, TWMKey(Message)) then
      begin
        FBar.ListCancel;
        Message.Result := 1;
        Exit;
      end;
  end;
  FOldProc(Message);
end;

{ ---------------------------------------------------------------- TSdComponentBar }

constructor TSdComponentBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form docked as a child keeps its own font }
  UIApplyFont(Self);
  { the boxes paint in one go: a resize repaints them at every step of a splitter drag }
  Category.DoubleBuffered := True;
  Filter.DoubleBuffered := True;
  UIFlatBorder(Category);          // the list's border colour, not the theme's
  UIFlatBorder(Filter);
  TFilterHook.Create(Filter, True);
  TCompListHook.Create(List, True).FBar := Self;
  UINoListTracking(List);           // long names end in "...", as in Component Bar
  FUsed := TStringList.Create;
  FUsed.OnChange := UsedChanged;
  FUsedIndex := TStringList.Create;
  FUsedIndex.Sorted := True;
  FUsedIndex.Duplicates := dupIgnore;
  FUsedStale := True;
  FListColor := clDefault;
  FSmallFont := TFont.Create;
  FSmallFont.Name := 'Small Fonts';
  FSmallFont.Size := 7;
  FSmallFont.Color := clBtnShadow;
  FRowBmp := TBitmap.Create;
  FClassic := True;               // the defaults: Component Bar's look, with the categories
  FHideCategory := False;
  UpdateRowHeight;
end;

destructor TSdComponentBar.Destroy;
begin
  FUsed.Free;
  FUsedIndex.Free;
  FSmallFont.Free;
  FRowBmp.Free;
  inherited;
end;

function TSdComponentBar.GetUsed: TStrings;
begin
  Result := FUsed;
end;

{ a row: the icon (24, or Component Bar's 28 x 28 tile) and the name, with the category two
  lines of text; at least 4 px around the icon }
procedure TSdComponentBar.UpdateRowHeight;
var
  H: Integer;
begin
  if FClassic then H := 28 + 4 else H := 24 + 4;
  if not FHideCategory and not FClassic and (2 * UITextHeight + 4 > H) then H := 2 * UITextHeight + 4;
  if not FHideCategory and FClassic and (UITextHeight + 13 + 4 > H) then H := UITextHeight + 13 + 4;
  if FHideCategory and (UITextHeight + 4 > H) then H := UITextHeight + 4;
  if List.ItemHeight <> H then List.ItemHeight := H;      // the list box makes its window again
  { Component Bar's list takes the colour of its form (ParentColor): clBtnFace }
  if FListColor <> clDefault then List.Color := FListColor
  else if FClassic then List.Color := clBtnFace else List.Color := clWindow;
  List.Invalidate;
end;

procedure TSdComponentBar.SetClassic(Value: Boolean);
begin
  if FClassic = Value then Exit;
  FClassic := Value;
  UpdateRowHeight;
end;

procedure TSdComponentBar.SetHideCategory(Value: Boolean);
begin
  if FHideCategory = Value then Exit;
  FHideCategory := Value;
  UpdateRowHeight;
end;

procedure TSdComponentBar.UsedChanged(Sender: TObject);
begin
  FUsedStale := True;
end;

{ FUsedIndex made again: the class of each entry "Class=count;last use", and after them the names
  alone of earlier versions' lists - the first entry of a class counts, as TStrings.IndexOfName
  then TStrings.IndexOf find it }
procedure TSdComponentBar.IndexUsed;
var
  I, P: Integer;
begin
  FUsedIndex.Clear;
  for I := 0 to FUsed.Count - 1 do
  begin
    P := AnsiPos(FUsed.NameValueSeparator, FUsed[I]);
    if P > 0 then FUsedIndex.AddObject(Copy(FUsed[I], 1, P - 1), TObject(I));
  end;
  for I := 0 to FUsed.Count - 1 do
    if AnsiPos(FUsed.NameValueSeparator, FUsed[I]) = 0 then FUsedIndex.AddObject(FUsed[I], TObject(I));
  FUsedStale := False;
end;

{ Component Bar's usage: how often a component was added from the view and when last }
function TSdComponentBar.UsageOf(const ClassName: string; out Count: Integer; out Last: TDateTime): Boolean;
var
  I, P: Integer;
  V: string;
begin
  Count := 0;
  Last := 0;
  if FUsedStale then IndexUsed;
  Result := FUsedIndex.Find(ClassName, I);
  if not Result then Exit;
  { the entry's value (a name alone has none) }
  V := Copy(FUsed[Integer(FUsedIndex.Objects[I])], Length(ClassName) + 2, MaxInt);
  P := Pos(';', V);
  if P = 0 then
  begin
    Count := 1;
    Exit;
  end;
  Count := StrToIntDef(Copy(V, 1, P - 1), 1);
  Last := StrToFloatDef(Copy(V, P + 1, MaxInt), 0, UsageFormat);
end;

procedure TSdComponentBar.MarkUsed(Cls: TComponentClass);
var
  Count, I: Integer;
  Last: TDateTime;
begin
  if Cls = nil then Exit;
  UsageOf(Cls.ClassName, Count, Last);
  I := FUsed.IndexOf(Cls.ClassName);
  if I >= 0 then FUsed.Delete(I);
  FUsed.Values[Cls.ClassName] := Format('%d;%.6f', [Count + 1, Now], UsageFormat);
  if FSortMode in [csRecentlyUsed, csMostUsed] then Refill;
  if FClassic then List.Invalidate;
end;

{ the gaps between the boxes and the list are the background; the border around the list }
procedure TSdComponentBar.Paint;
begin
  if FListFrame.Bottom > FListFrame.Top then UIDrawBorder(Canvas.Handle, FListFrame);
end;

procedure TSdComponentBar.CreateWnd;
begin
  inherited CreateWnd;
  { the lists kept through a new window may hold items of a package gone meanwhile }
  if (Category.Items.Count = 0) or FReloadPending then Reload;
end;

procedure TSdComponentBar.Resize;
var
  Y, F: Integer;
begin
  inherited;
  Y := Category.Height + Gap;
  F := Y + Filter.Height + Gap;
  { the list has no border of its own: it lies in a flat 1 px border, as the Object Inspector's }
  FListFrame := Rect(0, F, ClientWidth, ClientHeight);
  UIMoveControls([Category, Filter, List], [Rect(0, 0, ClientWidth, Category.Height),
    Rect(0, Y, ClientWidth, Y + Filter.Height), Rect(1, F + 1, ClientWidth - 1, ClientHeight - 1)]);
  { filled while it was small, the list may have scrolled: from the top when the chosen item
    fits there }
  if List.HandleAllocated and (List.ItemIndex >= 0) and
    ((List.ItemIndex + 1) * List.ItemHeight <= List.ClientHeight) then List.TopIndex := 0;
end;

{ the categories as the palette has them; the chosen one stays if it is still there }
procedure TSdComponentBar.Reload;
var
  I: Integer;
  Keep: string;
begin
  if not HandleAllocated or (DesignHost = nil) then
  begin
    FReloadPending := True;           // when the window comes (CreateWnd)
    Exit;
  end;
  FReloadPending := False;
  Keep := Category.Text;
  Category.Items.BeginUpdate;
  try
    Category.Items.Clear;
    Category.Items.Add(AllComponents);
    for I := 0 to DesignHost.PageCount - 1 do
      if DesignHost.Pages[I].Items.Count > 0 then Category.Items.Add(DesignHost.Pages[I].Name);
  finally
    Category.Items.EndUpdate;
  end;
  Category.ItemIndex := Category.Items.IndexOf(Keep);
  if Category.ItemIndex < 0 then Category.ItemIndex := 0;
  Refill;
end;

type
  { an item of the list being made, with its usage read once (not at every comparison of the
    sort: each read searches the usage list and parses its date) }
  TSortEntry = record
    Item: TPaletteItem;
    Count: Integer;
    Last: TDateTime;
  end;

var
  SortEntries: array of TSortEntry;   // what CompareItems sorts: the lists' Objects are indexes
  SortBy: TSdCompSort;

{ Component Bar's orders: by name; the last used first; the most used first (then the last used);
  never used ones after the used, by name }
function CompareItems(List: TStringList; Index1, Index2: Integer): Integer;
var
  A, B: Integer;
begin
  Result := 0;
  if SortBy <> csName then
  begin
    A := Integer(List.Objects[Index1]);
    B := Integer(List.Objects[Index2]);
    if SortBy = csMostUsed then
    begin
      if SortEntries[A].Count > SortEntries[B].Count then Result := -1
      else if SortEntries[A].Count < SortEntries[B].Count then Result := 1;
    end;
    if Result = 0 then
      if SortEntries[A].Last > SortEntries[B].Last then Result := -1
      else if SortEntries[A].Last < SortEntries[B].Last then Result := 1;
  end;
  if Result = 0 then Result := AnsiCompareText(List[Index1], List[Index2]);
end;

procedure TSdComponentBar.SetSortMode(Value: TSdCompSort);
begin
  if FSortMode = Value then Exit;
  FSortMode := Value;
  Refill;
end;

procedure TSdComponentBar.SetListColor(Value: TColor);
begin
  if FListColor = Value then Exit;
  FListColor := Value;
  UpdateRowHeight;
end;

{ the list for the category and the filter: names that begin with the filter first, then those
  that contain it (a mask with * or ?); each part in the sort mode's order (Component Bar's) }
procedure TSdComponentBar.Refill;
var
  I, K, P, N: Integer;
  S, Cat, KeepCaption: string;
  All: Boolean;
  Page: TPalettePage;
  Item: TPaletteItem;
  First, Rest: TStringList;
  Keep: TComponentClass;
  Matcher: TSdNameFilter;

  { the sorted list's items back from the indexes, into the list box }
  procedure Put(L: TStringList);
  var
    J: Integer;
  begin
    for J := 0 to L.Count - 1 do List.Items.AddObject(L[J], SortEntries[Integer(L.Objects[J])].Item);
  end;

begin
  if DesignHost = nil then Exit;
  Keep := FChosenClass;
  KeepCaption := FChosenCaption;
  Matcher := TSdNameFilter.Create(Filter.Text);
  All := Category.ItemIndex <= 0;
  Cat := Category.Text;
  First := TStringList.Create;
  Rest := TStringList.Create;
  try
    N := 0;
    for I := 0 to DesignHost.PageCount - 1 do Inc(N, DesignHost.Pages[I].Items.Count);
    SetLength(SortEntries, N);
    N := 0;
    for I := 0 to DesignHost.PageCount - 1 do
    begin
      Page := DesignHost.Pages[I];
      if not All and not SameText(Page.Name, Cat) then Continue;
      for K := 0 to Page.Items.Count - 1 do
      begin
        Item := TPaletteItem(Page.Items[K]);
        if Item.Hidden or (Item.ComponentClass = nil) then Continue;
        { a template's name, Frames for the Frames tool }
        if Item.Caption <> '' then S := Item.Caption else S := ComponentDisplayName(Item.ComponentClass.ClassName);
        P := Matcher.Match(S);
        if P = 0 then Continue;
        SortEntries[N].Item := Item;
        if FSortMode in [csRecentlyUsed, csMostUsed] then
          UsageOf(Item.ComponentClass.ClassName, SortEntries[N].Count, SortEntries[N].Last);
        if P = 1 then First.AddObject(S, TObject(N)) else Rest.AddObject(S, TObject(N));
        Inc(N);
      end;
    end;
    if FSortMode <> csPaletteOrder then
    begin
      SortBy := FSortMode;
      First.CustomSort(CompareItems);
      Rest.CustomSort(CompareItems);
    end;
    List.Items.BeginUpdate;
    try
      List.Items.Clear;
      Put(First);
      Put(Rest);
    finally
      List.Items.EndUpdate;
    end;
  finally
    SortEntries := nil;
    Rest.Free;
    First.Free;
    Matcher.Free;
  end;
  { the item chosen before stays chosen - a component template of a component's class is not
    that component -, else the first of its class, else the first; from the top (choosing an
    item scrolls it into view) }
  List.TopIndex := 0;
  List.ItemIndex := -1;
  if Keep <> nil then
  begin
    for I := 0 to List.Items.Count - 1 do
    begin
      Item := TPaletteItem(List.Items.Objects[I]);
      if (Item.ComponentClass = Keep) and (Item.Caption = KeepCaption) then
      begin
        List.ItemIndex := I;
        Break;
      end;
    end;
    if List.ItemIndex < 0 then
      for I := 0 to List.Items.Count - 1 do
        if TPaletteItem(List.Items.Objects[I]).ComponentClass = Keep then
        begin
          List.ItemIndex := I;
          Break;
        end;
  end;
  if (List.ItemIndex < 0) and (List.Items.Count > 0) then List.ItemIndex := 0;
  NoteChoice;
end;

{ The item chosen, by its class and its caption (a component template's, '' for a component):
  noted whenever the choice changes, while the item is alive - when the palette changes, the
  list still holds items that are gone (the templates are made again: new items, perhaps at the
  addresses of the old ones), and Refill chooses the same one again from these }
procedure TSdComponentBar.NoteChoice;
var
  Item: TPaletteItem;
begin
  Item := SelectedItem;
  if Item = nil then
  begin
    FChosenClass := nil;
    FChosenCaption := '';
  end
  else
  begin
    FChosenClass := Item.ComponentClass;
    FChosenCaption := Item.Caption;
  end;
end;

{ the keys of the list box changed the choice (LBN_SELCHANGE) }
procedure TSdComponentBar.ListClick(Sender: TObject);
begin
  NoteChoice;
end;

function TSdComponentBar.SelectedItem: TPaletteItem;
begin
  if List.ItemIndex >= 0 then Result := TPaletteItem(List.Items.Objects[List.ItemIndex]) else Result := nil;
end;

function TSdComponentBar.SelectedClass: TComponentClass;
begin
  if (List.ItemIndex >= 0) and (List.ItemIndex < List.Items.Count) then
    Result := TPaletteItem(List.Items.Objects[List.ItemIndex]).ComponentClass
  else
    Result := nil;
end;

function TSdComponentBar.SelectedCategory: string;
begin
  if (List.ItemIndex >= 0) and (List.ItemIndex < List.Items.Count) then
    Result := TPaletteItem(List.Items.Objects[List.ItemIndex]).Page
  else
    Result := '';
end;

procedure TSdComponentBar.ShowCategory(const Name: string);
var
  I: Integer;
begin
  I := Category.Items.IndexOf(Name);
  if I < 0 then I := 0;
  if I <> Category.ItemIndex then
  begin
    Category.ItemIndex := I;
    Refill;
  end;
end;

procedure TSdComponentBar.StepCategory(Delta: Integer);
var
  N: Integer;
begin
  N := Category.Items.Count;
  if N = 0 then Exit;
  Category.ItemIndex := (Category.ItemIndex + Delta + N) mod N;
  Refill;
end;

procedure TSdComponentBar.Choose;
begin
  if Assigned(FOnChoose) then FOnChoose(Self) else AddSelected;
end;

procedure TSdComponentBar.AddSelected;
var
  Done: Boolean;
begin
  if (SelectedClass = nil) or not Assigned(FOnAdd) then Exit;
  Done := False;
  FOnAdd(Self, SelectedClass, Done);
  if Done then MarkUsed(SelectedClass);
end;

procedure TSdComponentBar.CategoryChange(Sender: TObject);
begin
  Refill;
end;

procedure TSdComponentBar.FilterChange(Sender: TObject);
begin
  Refill;
end;

{ the keys of the filter box and of the list: Enter adds, Esc clears the filter and then the
  category, Shift+Up / Shift+Down step through the categories }
procedure TSdComponentBar.FilterKey(var Key: Word; Shift: TShiftState);
begin
  case Key of
    VK_RETURN: Choose;
    VK_ESCAPE:
      if Filter.Text <> '' then Filter.Text := ''
      else ShowCategory('');
    VK_UP, VK_DOWN:
      if ssShift in Shift then
      begin
        if Key = VK_UP then StepCategory(-1) else StepCategory(1);
      end
      else
        Exit;
  else
    Exit;
  end;
  Key := 0;
end;

procedure TSdComponentBar.FilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  FilterKey(Key, Shift);
  { the list's keys work in the filter box as well }
  ForwardListKey(List, Key);
end;

{ Enter and Esc are done in OnKeyDown: no beep from the box }
procedure TSdComponentBar.SwallowKeyPress(Sender: TObject; var Key: Char);
begin
  if Key in [#13, #27] then Key := #0;
end;

procedure TSdComponentBar.ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  FilterKey(Key, Shift);
end;

{ what is typed in the list goes to the filter (Component Bar does so) }
procedure TSdComponentBar.ListKeyPress(Sender: TObject; var Key: Char);
var
  S: string;
begin
  { Component Bar's Mask input reset delay: typed after a pause, it starts a new filter }
  if (Key in ['A'..'Z', 'a'..'z', '0'..'9', '_', '*', '?']) and (FResetDelay > 0) and (FLastTyped <> 0) and
    (GetTickCount - FLastTyped > Cardinal(FResetDelay) * 1000) then Filter.Text := '';
  FLastTyped := GetTickCount;
  if Key in ['A'..'Z', 'a'..'z', '0'..'9', '_', '*', '?'] then
    S := Filter.Text + Key
  else if (Key = #8) and (Filter.Text <> '') then
    S := Copy(Filter.Text, 1, Length(Filter.Text) - 1)
  else
  begin
    if Key in [#13, #27] then Key := #0;
    Exit;
  end;
  Key := #0;
  Filter.Text := S;
end;

procedure TSdComponentBar.ListDblClick(Sender: TObject);
begin
  FPressed := False;
  NoteChoice;
  Choose;
end;

{ A row in the system's colours, drawn into a bitmap and put on the list in one piece: a change
  of the selection draws the rows straight on the screen (not through the list's double
  buffer), and filling the row before drawing the icon made the icon flicker. Current look:
  the icon as it is, the name in the UI font and (unless hidden) the category in grey below
  it. Classic look, Component Bar's: on clBtnFace, the icon on Delphi 7's raised tile, the
  name - bold for a component added from the view before - and the category in Small Fonts. }
procedure TSdComponentBar.ListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  C: TCanvas;
  Item: TPaletteItem;
  Bmp: TBitmap;
  R: TRect;
  W, H, HC, HP, X, Y: Integer;
  Back, Fore, Grey: TColor;
  Used: Boolean;
  UseCount: Integer;
  UseLast: TDateTime;
begin
  W := Rect.Right - Rect.Left;
  H := Rect.Bottom - Rect.Top;
  if (W <= 0) or (H <= 0) then Exit;
  if FRowBmp.Width < W then FRowBmp.Width := W;
  if FRowBmp.Height <> H then FRowBmp.Height := H;
  C := FRowBmp.Canvas;
  C.Font := List.Font;
  Item := TPaletteItem(List.Items.Objects[Index]);
  Bmp := DesignHost.ItemBitmap(Item);
  if FClassic then
  begin
    Back := clBtnFace;
    Fore := clBtnText;
    Grey := clBtnShadow;
  end
  else
  begin
    Back := clWindow;
    Fore := clWindowText;
    Grey := clGrayText;
  end;
  if FListColor <> clDefault then Back := FListColor;      // Component Bar's Panel color
  { the selection in the selection colours while the list has the focus, else a tint of them
    with the text as it is }
  if odSelected in State then
    if List.Focused then
    begin
      Back := clHighlight;
      Fore := clHighlightText;
      Grey := clHighlightText;
    end
    else
      Back := UISelectionTint(Back);
  C.Brush.Color := Back;
  C.Font.Color := Fore;
  C.FillRect(Classes.Rect(0, 0, W, H));
  if FClassic then
  begin
    R := Classes.Rect(2, (H - 28) div 2, 30, (H - 28) div 2 + 28);
    UIDrawComponentTile(C.Handle, R, Bmp);
    { a component added from the view before: in bold (the classic look only) }
    Used := UsageOf(Item.ComponentClass.ClassName, UseCount, UseLast);
    if Used then C.Font.Style := [fsBold];
    HC := C.TextHeight('Wg');
    X := 3 + 28 + 4;
    if FHideCategory then
      C.TextOut(X, (H - HC) div 2, List.Items[Index])
    else
    begin
      FSmallFont.Color := Grey;
      C.Font := FSmallFont;
      HP := C.TextHeight('Wg');
      Y := (H - (2 + HC + HP)) div 2;
      C.TextOut(X - 1, Y + HC + 2, Item.Page);
      C.Font := List.Font;
      if Used then C.Font.Style := [fsBold];
      C.Font.Color := Fore;
      C.TextOut(X, Y, List.Items[Index]);
    end;
  end
  else
  begin
    if Bmp <> nil then C.Draw(4, (H - Bmp.Height) div 2, Bmp);
    SelectObject(C.Handle, C.Font.Handle);
    HC := UITextHeight;
    if FHideCategory then
    begin
      R := Classes.Rect(34, 0, W - 2, H);
      UIText(C.Handle, List.Items[Index], R, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX or DT_END_ELLIPSIS, C.Font.Color);
    end
    else
    begin
      R := Classes.Rect(34, 2, W - 2, 2 + HC);
      UIText(C.Handle, List.Items[Index], R, DT_LEFT or DT_SINGLELINE or DT_NOPREFIX or DT_END_ELLIPSIS, C.Font.Color);
      R := Classes.Rect(34, 2 + HC, W - 2, 2 + 2 * HC);
      UIText(C.Handle, Item.Page, R, DT_LEFT or DT_SINGLELINE or DT_NOPREFIX or DT_END_ELLIPSIS, Grey);
    end;
  end;
  BitBlt(List.Canvas.Handle, Rect.Left, Rect.Top, W, H, C.Handle, 0, 0, SRCCOPY);
end;
{ a press may become a drag onto the form being designed }
procedure TSdComponentBar.ListMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  I: Integer;
begin
  if Button = mbRight then
  begin
    I := List.ItemAtPos(Point(X, Y), True);
    if I >= 0 then List.ItemIndex := I;        // the menu is about the item under the pointer
    NoteChoice;
    Exit;
  end;
  NoteChoice;                                   // the press chose the item under it (TCompListHook)
  if Button <> mbLeft then Exit;
  I := List.ItemAtPos(Point(X, Y), True);
  FPressed := I >= 0;
  FDragging := False;
  FDragFrom := Point(X, Y);
  if FPressed then
  begin
    FDragItem := TPaletteItem(List.Items.Objects[I]);
    FDragClass := FDragItem.ComponentClass;
  end;
end;

procedure TSdComponentBar.ListMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  Accept: Boolean;
begin
  if not FPressed or not (ssLeft in Shift) then Exit;
  if not FDragging and UIDragStarted(FDragFrom, Point(X, Y)) then FDragging := True;
  if not FDragging then Exit;
  Accept := False;
  if Assigned(FOnCanDrop) then FOnCanDrop(Self, List.ClientToScreen(Point(X, Y)), Accept);
  if Accept then Screen.Cursor := crDrag else Screen.Cursor := crNo;
end;

{ The drag ends before the component is dropped: whatever the drop does - creating a component
  of a package can fail with an exception - the cursor is the normal one again. }
procedure TSdComponentBar.ListMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  Done, Drop: Boolean;
begin
  if Button <> mbLeft then Exit;
  Drop := FDragging;
  StopDrag;
  if Drop and Assigned(FOnDrop) then
  begin
    Done := False;
    FOnDrop(Self, FDragClass, List.ClientToScreen(Point(X, Y)), Done);
    if Done then MarkUsed(FDragClass);
  end;
end;

{ Esc, or another window took the mouse: the press (a drag) ends, nothing is dropped }
procedure TSdComponentBar.ListCancel;
begin
  StopDrag;
end;

procedure TSdComponentBar.StopDrag;
begin
  if FDragging then Screen.Cursor := crDefault;
  FPressed := False;
  FDragging := False;
end;

{ test mode: category|filter|count|selected }
function TSdComponentBar.DebugText: string;
var
  S: string;
begin
  if SelectedClass <> nil then S := SelectedClass.ClassName else S := '';
  Result := Format('%s|%s|%d|%s', [Category.Text, Filter.Text, List.Items.Count, S]);
end;

initialization
  GetLocaleFormatSettings(LOCALE_USER_DEFAULT, UsageFormat);
  UsageFormat.DecimalSeparator := '.';

end.
