{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCompletion;

{ D7 Studio - code-completion list and parameter-hint window.
  Both are transient popups that never take the keyboard focus from the editor. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, StdCtrls,
  SdUI, SdSciEdit, SdCodeInsight, SdHints;

type
  { an item was chosen: True when the handler put it in (the list then only closes) }
  TCompletionAcceptEvent = function(const Item: TCIItem; PrefixStart: Integer): Boolean of object;

  TCompletionPopup = class;

  { the rows of a list that is not D7 Studio's own: an expert's symbol list of the Open Tools API
    (SdOtaCodeInsight). It draws them and hears the mouse on them; the keys, the text typed and
    the list's end are its owner's }
  TCompletionSource = class
  public
    procedure DrawRow(Popup: TCompletionPopup; Index: Integer; const Rect: TRect; Selected: Boolean);
      virtual; abstract;
    function RowText(Index: Integer): string; virtual; abstract;   // DebugText
    procedure RowDblClick(Index: Integer); virtual; abstract;
    { the pointer over a row: True - the row is a link (the hand); a click on it while it is the
      chosen row browses (RowBrowse) }
    function RowLink(Index: Integer): Boolean; virtual; abstract;
    procedure RowBrowse(Index: Integer); virtual; abstract;
  end;

  TCompletionPopup = class(TSdPopupList)
  private
    FEditor: TSciEdit;
    FOnAcceptItem: TCompletionAcceptEvent;
    FItems: TCIItemList;
    FFiltered: TList;            // of PCIItem
    FPrefixStart: Integer;
    FActive: Boolean;
    FAuto: Boolean;              // opened by itself while typing (not by Ctrl+Space or '.')
    FBold: TFont;
    FAbove: Boolean;             // placed above the line (no room below it): its bottom stays there
    FSource: TCompletionSource;  // an expert's rows (nil: D7 Studio's own list, FItems)
    FTextLeft: Integer;          // ... where a row's text starts (px)
    FLinkRow: Integer;           // ... the row under the pointer that is a link (-1: none)
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMMouseMove(var Message: TWMMouseMove); message WM_MOUSEMOVE;
    procedure WMLButtonDown(var Message: TWMLButtonDown); message WM_LBUTTONDOWN;
    procedure WMSetCursor(var Message: TWMSetCursor); message WM_SETCURSOR;
    procedure ApplyFilter;
    function CurrentPrefix: string;
    function ListHeight: Integer;
    procedure Prepare;
    procedure Place(W: Integer);
    procedure FitHeight;
    function RowAt(Y: Integer): Integer;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); override;
    procedure DblClick; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { takes ownership of AItems; AAuto = the list opened by itself while typing }
    procedure Open(AEditor: TSciEdit; AItems: TCIItemList; APrefixStart: Integer; AAuto: Boolean = False);
    { an expert's list: ASource draws ACount rows (ASelected chosen; -1 none); a row's text starts
      after a column as wide as AColumnText, under the token at APrefixStart }
    procedure OpenSource(AEditor: TSciEdit; ASource: TCompletionSource; APrefixStart, ACount, ASelected: Integer;
      const AColumnText: string);
    { ... its rows again (the typed text filtered them): the height follows }
    procedure SetRows(ACount, ASelected: Integer);
    { ... the list gives its source back (closed first) }
    procedure DetachSource;
    { the chosen row moved by a navigation key: Up, Down, Page Up / Down, Home, End (False: none) }
    function StepSelection(Key: Word): Boolean;
    function FilteredCount: Integer;
    function SelectionIsTyped: Boolean;
    { D7 Studio's own list: the name a row shows (editor text), the row whose name is the text
      typed (-1: none), that text }
    function RowName(Index: Integer): string;
    function ExactRow: Integer;
    function TypedText: string;
    property AutoInvoked: Boolean read FAuto;
    procedure CloseUp;
    procedure Accept;
    procedure TextChanged;                      // editor text or caret changed
    function HandleKey(var Key: Word; Shift: TShiftState): Boolean;
    function HandleChar(Ch: Char): Boolean;     // True = accepted the selection before the char
    function DebugText: string;                 // the visible state as text (automated tests)
    { for the list just opened (Open clears it): code templates insert their code }
    property OnAcceptItem: TCompletionAcceptEvent read FOnAcceptItem write FOnAcceptItem;
    property Active: Boolean read FActive;
    property Editor: TSciEdit read FEditor;
    property Source: TCompletionSource read FSource;
    property TextLeft: Integer read FTextLeft;
    property Font;                              // the rows' fonts (a source draws with them)
    property BoldFont: TFont read FBold;
  end;

  { the parameter hints: a code tip (SdHints) with one line per overload, its
    parameters in the editor's font and colours, the parameter at the caret bold }
  TParamHintWindow = class(TSdCodeTip)
  private
    FHints: TCIParamHintArray;
    FActiveParam: Integer;
    FDelimiter: string;          // between two parameters of a line
    FPoint: TPoint;              // where it was shown last (ShowHints), and the line's space there
    FLineSpace: Integer;
    function GetShowing: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    { at ScreenPt (the caret's x, below its line), its text starting at the caret; above the line
      where the work area ends below it (LineSpace: the line's height and the gap below it);
      ADelimiter between the parameters (an expert's language has its own,
      IOTACodeInsightParameterList.GetParamDelimiter) }
    procedure ShowHints(const ScreenPt: TPoint; const AHints: TCIParamHintArray; AActiveParam: Integer;
      LineSpace: Integer; const ADelimiter: string = '; ');
    { another parameter bold, the hints as they are }
    procedure SetActive(AActiveParam: Integer);
    procedure HideHints;
    property Showing: Boolean read GetShowing;
  end;

function KindWord(Kind: TCIKind): string;
{ a kind's colour in the completion list (the editor theme's Code Insight elements) }
function KindColor(Kind: TCIKind): TColor;
{ A row of the completion list, on Back: the kind's word in KindFore in a column KindWidth px
  wide, the name bold in TextFore, the rest (parameters, type) after it, cut with an ellipsis.
  The list draws its rows with it, the Color page's sample of the list as well. }
procedure DrawCompletionRow(DC: HDC; const Rect: TRect; const Kind, Name, Rest: string;
  KindFore, TextFore, Back: TColor; Font, BoldFont: HFONT; KindWidth: Integer);

const
  KindColWidth = 62;

implementation

uses
  UxTheme, SdSciDefs, SdEditorThemes, SdEditorOptions;

const
  VisibleRows = 8;

function KindWord(Kind: TCIKind): string;
begin
  case Kind of
    ckKeyword: Result := '';
    ckUnit: Result := 'unit';
    ckConst, ckEnumValue, ckResourceString: Result := 'const';
    ckVar, ckField, ckParam, ckLocalVar: Result := 'var';
    ckType, ckRecord, ckEnum: Result := 'type';
    ckClass: Result := 'class';
    ckInterface: Result := 'interface';
    ckProcedure: Result := 'procedure';
    ckFunction: Result := 'function';
    ckConstructor: Result := 'constructor';
    ckDestructor: Result := 'destructor';
    ckProperty: Result := 'property';
    ckLabel: Result := 'label';
    ckTemplate: Result := 'template';
  else
    Result := '';
  end;
end;

function KindColor(Kind: TCIKind): TColor;
var
  E: TEditorElement;
begin
  case Kind of
    ckProcedure, ckConstructor, ckDestructor: E := eeCompProcedure;
    ckFunction: E := eeCompFunction;
    ckProperty: E := eeCompProperty;
    ckVar, ckField, ckParam, ckLocalVar: E := eeCompVariable;
    ckConst, ckEnumValue, ckResourceString: E := eeCompConstant;
    ckType, ckClass, ckInterface, ckRecord, ckEnum: E := eeCompType;
    ckUnit: E := eeCompUnit;
    ckLabel: E := eeCompLabel;
    ckTemplate:
      begin
        { a code template: dimmed, half way to the list's ground }
        Result := UIBlend(ElementFore(EditorOptions.Colors, eeCompletion),
          ElementBack(EditorOptions.Colors, eeCompletion), 55);
        Exit;
      end;
  else
    E := eeCompletion;
  end;
  Result := ElementFore(EditorOptions.Colors, E);
end;

procedure DrawCompletionRow(DC: HDC; const Rect: TRect; const Kind, Name, Rest: string;
  KindFore, TextFore, Back: TColor; Font, BoldFont: HFONT; KindWidth: Integer);
var
  R: TRect;
  X: Integer;
begin
  UIFill(DC, Rect, Back);
  SelectObject(DC, Font);
  R := Classes.Rect(Rect.Left + 3, Rect.Top, Rect.Left + KindWidth, Rect.Bottom);
  UIText(DC, Kind, R, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX, KindFore);
  SelectObject(DC, BoldFont);
  R := Classes.Rect(Rect.Left + KindWidth + 4, Rect.Top, Rect.Right, Rect.Bottom);
  X := R.Left + UITextWidth(DC, Name);
  UIText(DC, Name, R, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX, TextFore);
  SelectObject(DC, Font);
  if Rest <> '' then
  begin
    R.Left := X + 2;
    UIText(DC, Rest, R, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX or DT_END_ELLIPSIS, TextFore);
  end;
end;

{ ---------------------------------------------------------------- TCompletionPopup }

constructor TCompletionPopup.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFiltered := TList.Create;
  FBold := TFont.Create;
  FLinkRow := -1;
end;

destructor TCompletionPopup.Destroy;
begin
  FItems.Free;
  FFiltered.Free;
  FBold.Free;
  inherited;
end;

{ Delphi's code completion list as experts find it: a top-level window of the class
  TCodeCompleteListView named KibitzWindow (CnWizards' input helper looks for it with FindWindow:
  while it is visible, the helper shows no list of its own and leaves the keys to this one) }
procedure TCompletionPopup.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  StrCopy(Params.WinClassName, 'TCodeCompleteListView');
  Params.Caption := 'KibitzWindow';
end;

{ no erase: the rows cover the list (its height is theirs, ListHeight), and each paints its ground }
procedure TCompletionPopup.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

function TCompletionPopup.CurrentPrefix: string;
var
  P: Integer;
begin
  Result := '';
  if FEditor = nil then Exit;
  P := FEditor.CaretPos;
  if P > FPrefixStart then Result := FEditor.GetRange(FPrefixStart, P);
end;

procedure TCompletionPopup.ApplyFilter;
var
  Prefix: string;
  I, L, Exact, CaseHit: Integer;
  It: PCIItem;
begin
  Prefix := CurrentPrefix;
  L := Length(Prefix);
  FFiltered.Clear;
  Exact := -1;
  CaseHit := -1;
  for I := 0 to FItems.Count - 1 do
  begin
    It := FItems[I];
    { the names' starts compared in place (as SameText: ASCII letters in either case) - no copy
      of each name at every key }
    if (L = 0) or (StrLIComp(PChar(It^.Name), PChar(Prefix), L) = 0) then
    begin
      if (Exact < 0) and (L > 0) and (Length(It^.Name) = L) then Exact := FFiltered.Count;
      { "Sho" should rather mean ShowMessage than SHORT }
      if (CaseHit < 0) and (L > 0) and (StrLComp(PChar(It^.Name), PChar(Prefix), L) = 0) then
        CaseHit := FFiltered.Count;
      FFiltered.Add(It);
    end;
  end;
  Count := FFiltered.Count;
  if FFiltered.Count > 0 then
  begin
    if Exact >= 0 then ItemIndex := Exact
    else if CaseHit >= 0 then ItemIndex := CaseHit
    else ItemIndex := 0;
  end;
  Invalidate;
end;

{ the list shows VisibleRows rows, fewer when fewer entries match }
function TCompletionPopup.ListHeight: Integer;
begin
  if Count < VisibleRows then
    Result := ItemHeight * Count + 2
  else
    Result := ItemHeight * VisibleRows + 2;
end;

function TCompletionPopup.FilteredCount: Integer;
begin
  if FActive and (FSource = nil) then Result := FFiltered.Count else Result := 0;
end;

function TCompletionPopup.SelectionIsTyped: Boolean;
begin
  { the selected entry is exactly what stands in the editor already }
  Result := FActive and (FSource = nil) and (ItemIndex >= 0) and (ItemIndex < FFiltered.Count) and
    SameText(PCIItem(FFiltered[ItemIndex])^.Name, CurrentPrefix);
end;

function TCompletionPopup.RowName(Index: Integer): string;
begin
  if (FSource = nil) and (Index >= 0) and (Index < FFiltered.Count) then Result := PCIItem(FFiltered[Index])^.Name
  else Result := '';
end;

function TCompletionPopup.ExactRow: Integer;
var
  P: string;
  I: Integer;
begin
  Result := -1;
  P := CurrentPrefix;
  if (FSource <> nil) or (P = '') then Exit;
  for I := 0 to FFiltered.Count - 1 do
    if SameText(PCIItem(FFiltered[I])^.Name, P) then
    begin
      Result := I;
      Exit;
    end;
end;

function TCompletionPopup.TypedText: string;
begin
  if FSource = nil then Result := CurrentPrefix else Result := '';
end;

{ the window made once (its VCL parent only serves to create it; it must outlive every editor, and
  the virtual style needs a window handle to be set), the fonts and the rows' height }
procedure TCompletionPopup.Prepare;
begin
  if Parent = nil then
  begin
    Parent := Owner as TWinControl;
    Style := lbVirtualOwnerDraw;
  end;
  HandleNeeded;
  { the scroll bar in the light or the dark look of Windows, as the theme's ground of the list }
  if Assigned(SetWindowTheme) then
    if UIIsDark(ElementBack(EditorOptions.Colors, eeCompletion)) then
      SetWindowTheme(Handle, 'DarkMode_Explorer', nil)
    else
      SetWindowTheme(Handle, nil, nil);
  UIApplyFont(Font);
  FBold.Assign(Font);
  FBold.Style := [fsBold];
  Canvas.Font := Font;
  ItemHeight := Canvas.TextHeight('Wg') + 3;
end;

{ W px wide, a row's text (FTextLeft) under the token at FPrefixStart: below its line, above it
  where the work area ends there }
procedure TCompletionPopup.Place(W: Integer);
var
  P: TPoint;
  H, LineH: Integer;
  Mon: TRect;
begin
  H := ListHeight;
  P := FEditor.PointFromPos(FPrefixStart);
  LineH := FEditor.TextHeight;
  P := FEditor.ClientToScreen(Point(P.X - FTextLeft, P.Y + LineH));
  Mon := UIWorkArea(FEditor.Handle);     // Screen's monitors can be stale (nil: an access violation)
  FAbove := P.Y + H > Mon.Bottom;
  if FAbove then P.Y := P.Y - LineH - H;
  if P.X + W > Mon.Right then P.X := Mon.Right - W;
  if P.X < Mon.Left then P.X := Mon.Left;
  ShowAt(P.X, P.Y, W, H);
end;

{ the height for the rows there are now; a list above its line keeps its bottom there }
procedure TCompletionPopup.FitHeight;
var
  H: Integer;
  R: TRect;
begin
  H := ListHeight;
  GetWindowRect(Handle, R);
  if FAbove then R.Top := R.Bottom - H;     // no gap between a shorter list and the line
  SetWindowPos(Handle, 0, R.Left, R.Top, R.Right - R.Left, H, SWP_NOZORDER or SWP_NOACTIVATE);
end;

procedure TCompletionPopup.Open(AEditor: TSciEdit; AItems: TCIItemList; APrefixStart: Integer;
  AAuto: Boolean);
begin
  CloseUp;
  FOnAcceptItem := nil;
  FSource := nil;
  FItems.Free;
  FItems := AItems;
  FEditor := AEditor;
  FPrefixStart := APrefixStart;
  FAuto := AAuto;
  if (FItems = nil) or (FItems.Count = 0) or (FEditor = nil) then Exit;
  Prepare;
  FItems.Sort;
  ApplyFilter;
  if FFiltered.Count = 0 then Exit;
  FTextLeft := KindColWidth + 4;
  Place(420);
  FActive := True;
end;

procedure TCompletionPopup.OpenSource(AEditor: TSciEdit; ASource: TCompletionSource; APrefixStart, ACount,
  ASelected: Integer; const AColumnText: string);
begin
  CloseUp;
  FOnAcceptItem := nil;
  FreeAndNil(FItems);
  FFiltered.Clear;
  FSource := ASource;
  FEditor := AEditor;
  FPrefixStart := APrefixStart;
  FAuto := False;
  if (FSource = nil) or (FEditor = nil) or (ACount <= 0) then Exit;
  Prepare;
  FTextLeft := 3 + Canvas.TextWidth(AColumnText) + 4;
  if FTextLeft < KindColWidth + 4 then FTextLeft := KindColWidth + 4;
  Count := ACount;
  ItemIndex := ASelected;
  Place(FTextLeft + 360);
  FActive := True;
end;

procedure TCompletionPopup.SetRows(ACount, ASelected: Integer);
begin
  if not FActive or (FSource = nil) then Exit;
  Count := ACount;
  ItemIndex := ASelected;
  FitHeight;
  Invalidate;
end;

procedure TCompletionPopup.DetachSource;
begin
  if FSource = nil then Exit;
  CloseUp;
  FSource := nil;
  Count := 0;
end;

function TCompletionPopup.StepSelection(Key: Word): Boolean;
var
  I: Integer;
begin
  Result := False;
  if not FActive then Exit;
  I := ItemIndex;
  case Key of
    VK_UP: Dec(I);
    VK_DOWN: Inc(I);
    VK_PRIOR: Dec(I, VisibleRows - 1);
    VK_NEXT: Inc(I, VisibleRows - 1);
    VK_HOME: I := 0;
    VK_END: I := Count - 1;
  else
    Exit;
  end;
  if I < 0 then I := 0;
  if I >= Count then I := Count - 1;
  ItemIndex := I;
  Result := True;
end;

function TCompletionPopup.DebugText: string;
var
  I: Integer;
begin
  Result := '';
  if not FActive then Exit;
  Result := Format('%d items, selected %d:', [Count, ItemIndex]);
  for I := 0 to Count - 1 do
  begin
    if I >= 12 then Break;
    if FSource <> nil then Result := Result + ' ' + FSource.RowText(I)
    else Result := Result + ' ' + PCIItem(FFiltered[I])^.Name;
  end;
end;

procedure TCompletionPopup.CloseUp;
begin
  FLinkRow := -1;
  if not FActive then Exit;
  FActive := False;
  HideList;
end;

procedure TCompletionPopup.TextChanged;
var
  P: Integer;
begin
  if not FActive or (FSource <> nil) then Exit;
  P := FEditor.CaretPos;
  if (P < FPrefixStart) or ((P > FPrefixStart) and not FEditor.IsIdentChar(FEditor.CharAt(P - 1))) then
  begin
    CloseUp;
    Exit;
  end;
  ApplyFilter;
  if FFiltered.Count = 0 then
  begin
    CloseUp;
    Exit;
  end;
  { a list that opened by itself goes away once a reserved word has been typed out
    ("end" must not linger as the start of EndPaint) }
  if FAuto and IsPascalKeyword(CurrentPrefix) then
  begin
    CloseUp;
    Exit;
  end;
  FitHeight;
end;

procedure TCompletionPopup.Accept;
var
  It: PCIItem;
  P: Integer;
begin
  if not FActive or (FSource <> nil) then Exit;
  if (ItemIndex >= 0) and (ItemIndex < FFiltered.Count) then
  begin
    It := PCIItem(FFiltered[ItemIndex]);
    { a list whose items are not just names (code templates) inserts them itself }
    if Assigned(FOnAcceptItem) and FOnAcceptItem(It^, FPrefixStart) then
    begin
      CloseUp;
      Exit;
    end;
    P := FEditor.CaretPos;
    { also swallow the rest of an identifier the caret sits in }
    while FEditor.IsIdentChar(FEditor.CharAt(P)) do Inc(P);
    FEditor.Sci(SCI_SETTARGETSTART, FPrefixStart);
    FEditor.Sci(SCI_SETTARGETEND, P);
    FEditor.SciS(SCI_REPLACETARGET, Length(It^.Name), It^.Name);
    FEditor.GotoPos(FPrefixStart + Length(It^.Name));
  end;
  CloseUp;
end;

{ D7 Studio's own list (an expert's takes its keys through its owner) }
function TCompletionPopup.HandleKey(var Key: Word; Shift: TShiftState): Boolean;
begin
  Result := False;
  if not FActive or (FSource <> nil) then Exit;
  case Key of
    VK_RETURN, VK_TAB:
      begin
        { Enter on a list that opened by itself, with the word already typed out in full:
          the user wants the new line, not the list }
        if FAuto and (Key = VK_RETURN) and SelectionIsTyped then
        begin
          CloseUp;
          Exit;
        end;
        Accept;
        Key := 0;
        Result := True;
        Exit;
      end;
    VK_ESCAPE:
      begin
        CloseUp;
        Key := 0;
        Result := True;
        Exit;
      end;
    VK_LEFT, VK_RIGHT, VK_HOME, VK_END:
      begin
        CloseUp;
        Exit;
      end;
  end;
  if StepSelection(Key) then
  begin
    Key := 0;
    Result := True;
  end;
end;

function TCompletionPopup.HandleChar(Ch: Char): Boolean;
begin
  Result := False;
  if not FActive or (FSource <> nil) then Exit;
  if Ch in ['.', '(', ';', ',', ')', '[', ']', ' ', ':', '=', '+', '-', '*', '/'] then
  begin
    { a list the user asked for completes the word before the symbol (Delphi 7); a list that
      opened by itself never changes what was typed - only Enter or Tab accept from it }
    if not FAuto and (CurrentPrefix <> '') and (ItemIndex >= 0) then
    begin
      Accept;
      Result := True;
    end
    else
      CloseUp;
  end;
end;

procedure TCompletionPopup.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  It: PCIItem;
  S: string;
  Back, KindFore, TextFore: TColor;
begin
  if FSource <> nil then
  begin
    if (Index >= 0) and (Index < Count) then FSource.DrawRow(Self, Index, Rect, odSelected in State);
    Exit;
  end;
  if (Index < 0) or (Index >= FFiltered.Count) then Exit;
  It := PCIItem(FFiltered[Index]);
  if odSelected in State then
  begin
    Back := clHighlight;
    KindFore := clHighlightText;
    TextFore := clHighlightText;
  end
  else
  begin
    Back := ElementBack(EditorOptions.Colors, eeCompletion);
    KindFore := KindColor(It^.Kind);
    TextFore := ElementFore(EditorOptions.Colors, eeCompletion);
  end;
  S := '';
  if It^.Kind in [ckProcedure, ckFunction, ckConstructor, ckDestructor] then
  begin
    if It^.Params <> '' then S := '(' + It^.Params + ')';
    if It^.TypeName <> '' then S := S + ': ' + It^.TypeName;
    if S = '' then S := ';';
  end
  else if It^.Kind = ckTemplate then
    S := '  ' + It^.TypeName                 // its description
  else if It^.TypeName <> '' then
    S := ': ' + It^.TypeName;
  DrawCompletionRow(Canvas.Handle, Rect, KindWord(It^.Kind), It^.Name, S, KindFore, TextFore, Back,
    Font.Handle, FBold.Handle, KindColWidth);
end;

procedure TCompletionPopup.DblClick;
begin
  inherited;
  if FSource <> nil then
  begin
    if ItemIndex >= 0 then FSource.RowDblClick(ItemIndex);
  end
  else
    Accept;
end;

{ the row at a client Y (-1: below the rows) }
function TCompletionPopup.RowAt(Y: Integer): Integer;
begin
  Result := -1;
  if (ItemHeight <= 0) or (Y < 0) then Exit;
  Result := TopIndex + Y div ItemHeight;
  if Result >= Count then Result := -1;
end;

{ an expert's row may be a link (IOTACodeInsightManager.IsViewerBrowsable): the hand over it }
procedure TCompletionPopup.WMMouseMove(var Message: TWMMouseMove);
var
  Row: Integer;
begin
  inherited;
  Row := -1;
  if FActive and (FSource <> nil) then
  begin
    Row := RowAt(Message.YPos);
    if (Row >= 0) and not FSource.RowLink(Row) then Row := -1;
  end;
  if Row <> FLinkRow then
  begin
    FLinkRow := Row;
    if Row >= 0 then Windows.SetCursor(LoadCursor(0, IDC_HAND))
    else Windows.SetCursor(LoadCursor(0, IDC_ARROW));
  end;
end;

{ a click on the chosen row of an expert's list while it is a link browses (Delphi's viewer) }
procedure TCompletionPopup.WMLButtonDown(var Message: TWMLButtonDown);
var
  Row: Integer;
begin
  if FActive and (FSource <> nil) then
  begin
    Row := RowAt(Message.YPos);
    if (Row >= 0) and (Row = ItemIndex) and FSource.RowLink(Row) then
    begin
      FSource.RowBrowse(Row);
      Exit;
    end;
  end;
  inherited;
end;

procedure TCompletionPopup.WMSetCursor(var Message: TWMSetCursor);
begin
  if FActive and (FSource <> nil) and (FLinkRow >= 0) and (Message.HitTest = HTCLIENT) then
  begin
    Windows.SetCursor(LoadCursor(0, IDC_HAND));
    Message.Result := 1;
  end
  else
    inherited;
end;

{ ---------------------------------------------------------------- TParamHintWindow }

constructor TParamHintWindow.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDelimiter := '; ';
end;

function TParamHintWindow.GetShowing: Boolean;
begin
  Result := TipShown;
end;

procedure TParamHintWindow.ShowHints(const ScreenPt: TPoint; const AHints: TCIParamHintArray;
  AActiveParam, LineSpace: Integer; const ADelimiter: string);
var
  Lines: TTipLines;
  Runs: TTipRuns;
  I, J, N: Integer;
  Style: TFontStyles;
begin
  FHints := AHints;
  FActiveParam := AActiveParam;
  FDelimiter := ADelimiter;
  FPoint := ScreenPt;
  FLineSpace := LineSpace;
  if Length(FHints) = 0 then
  begin
    HideHints;
    Exit;
  end;
  Lines := nil;
  for I := 0 to High(FHints) do
  begin
    Runs := nil;
    N := Length(FHints[I].Params);
    if N = 0 then
      AddTipRun(Runs, '*No parameters expected*', clGrayText, [fsItalic], False)
    else
      for J := 0 to N - 1 do
      begin
        { the parameter at the caret bold on the accent box (bold alone does not show with every
          font: a semi-bold face is drawn the same in bold), the delimiter after it plain }
        if J = FActiveParam then Style := [fsBold] else Style := [];
        AddCodeRuns(Runs, FHints[I].Params[J], True, Style, J = FActiveParam);
        if J < N - 1 then AddCodeRuns(Runs, FDelimiter, True);
      end;
    AddTipLine(Lines, Runs);
  end;
  { the caret's line ends LineSpace above ScreenPt: below it, above it where the work area ends }
  ShowLines(Lines, Rect(ScreenPt.X, ScreenPt.Y - LineSpace, ScreenPt.X + 1, ScreenPt.Y), nil);
end;

{ the size follows the bold parameter's width }
procedure TParamHintWindow.SetActive(AActiveParam: Integer);
begin
  if Showing and (AActiveParam <> FActiveParam) then
    ShowHints(FPoint, FHints, AActiveParam, FLineSpace, FDelimiter);
end;

procedure TParamHintWindow.HideHints;
begin
  if Showing then HideTip;
end;

end.