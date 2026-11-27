{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaCodeInsight;

{ D7 Studio - code insight of the Open Tools API: IOTACodeInsightServices, Delphi
  7's kibitz manager (coreide70's Codcmplt) over D7 Studio's editor pages.

  * The managers: index 0 is D7 Studio's own code insight as Delphi's Pascal manager
    (TSdPascalCIManager, 'Borland.CodeInsight.Pascal'); experts add theirs. The manager of a file
    is chosen as Delphi chooses it, at each invocation: from the newest down, the first that
    handles the file and is enabled - so an expert's manager for .pas files replaces D7 Studio's
    own, and an expert may switch the built-in one off. The built-in one chosen: D7 Studio's own
    code insight runs as it always does (its triggers, its list, its hints; its methods are
    there for experts that call it); an expert's: a session below; none: nothing. A removed
    manager's index stays taken (GetCodeInsightManager gives an empty manager for it): Delphi
    shifts the later ones, and an expert's index would then name another's manager.
  * A session (one at a time; Delphi's sequence): the key that invoked it (#0 the list, #1 the
    parameters, #2 browse - Ctrl+click, Find Declaration -, #3 the hint of the place under the
    mouse, '.' and '(' typed), AllowCodeInsight, GetCodeInsightType with the syntax element
    there, then
      - the list: InvokeCodeCompletion with the token around the caret (EditorTokenValidChars),
        the symbol list in the completion popup (SetSortOrder(soAlpha), SetFilter as the text
        before the caret changes, FindSymIndex: the row chosen); every key goes to OnEditorKey
        first (Accept or CloseViewer: the key is eaten); Done when the list closes - accepted by
        such a key or a double click, not accepted when the caret leaves the token;
      - the parameter hint: InvokeParameterCodeInsight, GetParameterList (a parameter per line,
        the list's delimiter), ParameterCodeInsightAnchorPos; while it shows,
        ParameterCodeInsightParamIndex at each change (-1: asked again 300 ms later);
      - GotoDefinition (False: "Unable to locate file" in the status bar, and a beep);
        GetHintText (in the editor's code tip, SdHints).
    The list and the parameters wait for Editor Options' Code Insight delay when the manager
    says itAuto / itTimer - only with Code completion / Code parameters on -, and a key, a click
    or a move of the caret meanwhile ends the wait. A session is cancelled - no Done, the symbol
    list cleared - by CancelCodeInsightProcessing, the focus leaving the editor, scrolling,
    another page, its page closing, a compile, its package going.
  * Every call into an expert is guarded: an exception is logged (error.log) and the session
    ends - no message box while the user types.
  * Strings are the IDE's; the editor's text is converted (SdEncoding). A character of the
    editor belongs to a token when every byte of its IDE text is in the manager's set. Places
    are TOTAEditPos. Main thread only (Delphi's too). }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, ToolsAPI, SdOtaCore, SdEditorPage,
  SdCompletion;

type
  TSdCIState = (csIdle, csDelay, csList, csParamDelay, csParams);

  TSdOtaCodeInsightServices = class(TAggregatedObject, IOTACodeInsightServices60, IOTACodeInsightServices)
  private
    FManagers: TSdNotifierList;          // IOTACodeInsightManager by index (a package's that went: a hole)
    FHtml: IOTACodeInsightManager;       // Delphi 7's markup manager (TSdHtmlCIManager), index 0 at the start
    FBuiltIn: IOTACodeInsightManager;    // D7 Studio's own (TSdPascalCIManager), index 1 at the start
    FBuiltInObj: TObject;
    FRemoved: IOTACodeInsightManager;    // what a removed manager's index gives
    FViewer: IOTACodeInsightViewer;
    FQueryView: IOTAEditView;            // SetQueryContext
    FQueryManager: IOTACodeInsightManager;
    FQuery: Boolean;                     // ... both given: no session, no viewer
    FWnd: HWND;                          // the window of the timer and of posted steps
    { the session }
    FState: TSdCIState;
    FPage: TEditorPage;                  // nil: none
    FManager: IOTACodeInsightManager;
    FSerial: Integer;                    // one more at each session's start and end
    FBusy: Integer;                      // a call into the expert runs
    FChars: TSysCharSet;                 // the token's characters (EditorTokenValidChars(False))
    FHaveChars: Boolean;
    FTokenStart: Integer;                // the list's token starts there (an editor offset)
    FTyped: string;                      // the text that filters the list (the IDE's)
    FExact: Integer;                     // the row whose symbol is the typed text (-1: none)
    FSymbols: IOTACodeInsightSymbolList;
    FCustomDraw: INTACustomDrawCodeInsightViewer;
    FMultiSelect: Boolean;
    FMarks: TBits;                       // multi-select: the rows chosen with Space
    FCloseKey: Char;
    FSource: TCompletionSource;          // the list's rows in the completion popup
    FDrawFailed: Boolean;                // a call of the drawing raised: the rows are drawn plain
    FParams: IOTACodeInsightParameterList;
    FParamShown: Boolean;
    FReinvoke: Boolean;                  // the parameters are asked for again after the timer
    FCaret, FVersion: Integer;           // the caret and the text the session saw last
    FViewerMade: Boolean;                // a list has been shown: the viewer is there (Delphi 7's GetViewer)
    FLastCount: Integer;                 // the rows of the list shown last - its viewer keeps them
    function Wnd: HWND;
    procedure WndProc(var Message: TMessage);
    function ManagerFor(Page: TEditorPage): IOTACodeInsightManager;
    function Alive(Serial: Integer): Boolean;
    procedure Seen;
    procedure Start(Page: TEditorPage; const M: IOTACodeInsightManager; Key: Char; Pos: Integer);
    procedure EndSession;
    procedure Failed(const What: string);
    procedure StartTimer(State: TSdCIState; Ms: Integer);
    procedure StopTimer;
    procedure TimerDone;
    procedure DelayDone;
    function TokenChars: TSysCharSet;
    procedure OpenList(How: TOTAInvokeType);
    procedure Filter(const Text: string; out Count, Selected: Integer);
    procedure ListChanged;
    function EditorKey(Key: Char): Boolean;
    procedure CloseList(Accepted: Boolean);
    function ListShown: Boolean;
    function OwnListShown: Boolean;
    function Marked(Index: Integer): Boolean;
    procedure ToggleMark;
    procedure ChooseOnly;
    procedure ShowParams(How: TOTAInvokeType);
    procedure ParamsChanged;
    procedure Browse(Index: Integer);
    procedure Hint(Pos: Integer);
  public
    constructor Create(const Controller: IInterface);
    destructor Destroy; override;
    { the page's code insight (TIDEServices' CI methods, SdEditorPage) }
    function Invoke(Page: TEditorPage; Key: Char; Pos: Integer): Boolean;
    function OwnAllowed(Page: TEditorPage): Boolean;
    function KeyDown(Page: TEditorPage; var Key: Word; Shift: TShiftState): Boolean;
    function KeyPress(Page: TEditorPage; var Key: Char): Boolean;
    procedure Changed(Page: TEditorPage);
    { the session ends without Done (a compile, the page's popups closed) }
    procedure Cancel;
    procedure DropModule(Module: HMODULE);
    procedure AddModules(List: TList);
    { the IDE ends: the session cancelled, the managers released }
    procedure Shutdown;
    function DebugText: string;
    { IOTACodeInsightServices60 }
    procedure GetEditView(out EditView: IOTAEditView);
    procedure GetViewer(out Viewer: IOTACodeInsightViewer);
    procedure GetCurrentCodeInsightManager(out CodeInsightManager: IOTACodeInsightManager);
    procedure CancelCodeInsightProcessing;
    function AddCodeInsightManager(const ACodeInsightManager: IOTACodeInsightManager): Integer;
    procedure RemoveCodeInsightManager(Index: Integer);
    procedure InsertText(const Str: string; Replace: Boolean);
    function GetCodeInsightManagerCount: Integer;
    function GetCodeInsightManager(Index: Integer): IOTACodeInsightManager;
    { IOTACodeInsightServices }
    procedure SetQueryContext(const EditView: IOTAEditView; const CodeInsightManager: IOTACodeInsightManager);
  end;

{ the page's code insight for the main window's TIDEServices (SdEditorPage's CI methods): without
  the services nothing is taken and D7 Studio's own code insight runs }
function OtaCIInvoke(Page: TEditorPage; Key: Char; Pos: Integer): Boolean;
function OtaCIOwnAllowed(Page: TEditorPage): Boolean;
function OtaCIKeyDown(Page: TEditorPage; var Key: Word; Shift: TShiftState): Boolean;
function OtaCIKeyPress(Page: TEditorPage; var Key: Char): Boolean;
procedure OtaCIChanged(Page: TEditorPage);
procedure OtaCICancel(Page: TEditorPage);
{ test mode: 'managers|current manager|state|typed text|exact row|close key' }
function OtaCIDebugText: string;

implementation

uses
  RTLConsts, SdSciDefs, SdSciEdit, SdEncoding, SdEditorThemes, SdEditorOptions, SdCodeInsight, SdUI,
  SdOtaModules, SdHints;

const
  TimerId = 1;
  WM_CICANCEL = WM_APP + 1;              // a call of the list's drawing raised: the session ends after the paint
  IdentChars: TSysCharSet = ['A'..'Z', 'a'..'z', '0'..'9', '_'];
  PascalID = 'Borland.CodeInsight.Pascal';

type
  { the list's rows in the completion popup: the session's symbol list, drawn as Delphi's viewer
    draws it - the class text (GetSymbolClassText) in its column coloured by the symbol's flags
    (Editor Options | Code Insight; an abstract symbol in the Abstract Symbol colour), then the
    manager's own drawing (INTACustomDrawCodeInsightViewer.DrawLine) or the symbol bold and its
    type text }
  TSdOtaSymbolSource = class(TCompletionSource)
  public
    procedure DrawRow(Popup: TCompletionPopup; Index: Integer; const Rect: TRect; Selected: Boolean); override;
    function RowText(Index: Integer): string; override;
    procedure RowDblClick(Index: Integer); override;
    function RowLink(Index: Integer): Boolean; override;
    procedure RowBrowse(Index: Integer); override;
  end;

  { the list shown, as IOTACodeInsightViewer: an expert's (the session's) or D7 Studio's own }
  TSdCIViewer = class(TInterfacedObject, IOTACodeInsightViewer)
  private
    function ChosenRow(out Own: Boolean): Integer;
  public
    function GetSelected(Index: Integer): Boolean;
    function GetItemCount: Integer;
    function GetSelectedString: string;
    function GetSelectedIndex: Integer;
    function GetCloseKey: Char;
    function GetIsValidSelection: Boolean;
  end;

  { a hole of the list (a package's manager that went): nothing, handles no file }
  TSdRemovedCIManager = class(TInterfacedObject, IOTACodeInsightManager)
  public
    function GetName: string;
    function GetIDString: string;
    function GetEnabled: Boolean;
    procedure SetEnabled(Value: Boolean);
    function EditorTokenValidChars(PreValidating: Boolean): TSysCharSet;
    procedure AllowCodeInsight(var Allow: Boolean; const Key: Char);
    function PreValidateCodeInsight(const Str: string): Boolean;
    function IsViewerBrowsable(Index: Integer): Boolean;
    function GetMultiSelect: Boolean;
    procedure GetSymbolList(out SymbolList: IOTACodeInsightSymbolList);
    procedure OnEditorKey(Key: Char; var CloseViewer: Boolean; var Accept: Boolean);
    function HandlesFile(const AFileName: string): Boolean;
    function GetLongestItem: string;
    procedure GetParameterList(out ParameterList: IOTACodeInsightParameterList);
    procedure GetCodeInsightType(AChar: Char; AElement: Integer; out CodeInsightType: TOTACodeInsightType;
      out InvokeType: TOTAInvokeType);
    function InvokeCodeCompletion(HowInvoked: TOTAInvokeType; var Str: string): Boolean;
    function InvokeParameterCodeInsight(HowInvoked: TOTAInvokeType; var SelectedIndex: Integer): Boolean;
    procedure ParameterCodeInsightAnchorPos(var EdPos: TOTAEditPos);
    function ParameterCodeInsightParamIndex(EdPos: TOTAEditPos): Integer;
    function GetHintText(HintLine, HintCol: Integer): string;
    function GotoDefinition(out AFileName: string; out ALineNum: Integer; Index: Integer = -1): Boolean;
    procedure Done(Accepted: Boolean; out DisplayParams: Boolean);
  end;

  { Delphi 7's first manager, for markup files (Borland.CodeInsight.HTML, "Markup Language";
    measured): D7 Studio has no code insight of theirs - it offers nothing }
  TSdHtmlCIManager = class(TSdRemovedCIManager, IOTACodeInsightManager)
  private
    FEnabled: Boolean;
  public
    constructor Create;
    function GetName: string;
    function GetIDString: string;
    function GetEnabled: Boolean;
    procedure SetEnabled(Value: Boolean);
    function HandlesFile(const AFileName: string): Boolean;
  end;

  { D7 Studio's own code insight as Delphi's Pascal manager (delphide70's TPascalKibitzManager):
    its name, its switch, the files it takes and Delphi's answers; its data - the list, the
    parameters, the hint, the declaration - from SdCodeInsight at the caret of the edit view
    (GetEditView: also a query context's) }
  TSdCISymbolList = class;

  TSdPascalCIManager = class(TInterfacedObject, IOTACodeInsightManager)
  private
    FEnabled: Boolean;
    FSymbols: IOTACodeInsightSymbolList;
    FSymbolObj: TSdCISymbolList;       // the object behind FSymbols
    FParams: IOTACodeInsightParameterList;
    function ViewPage: TEditorPage;
  public
    constructor Create;
    function HandlesPage(Page: TEditorPage): Boolean;
    function GetName: string;
    function GetIDString: string;
    function GetEnabled: Boolean;
    procedure SetEnabled(Value: Boolean);
    function EditorTokenValidChars(PreValidating: Boolean): TSysCharSet;
    procedure AllowCodeInsight(var Allow: Boolean; const Key: Char);
    function PreValidateCodeInsight(const Str: string): Boolean;
    function IsViewerBrowsable(Index: Integer): Boolean;
    function GetMultiSelect: Boolean;
    procedure GetSymbolList(out SymbolList: IOTACodeInsightSymbolList);
    procedure OnEditorKey(Key: Char; var CloseViewer: Boolean; var Accept: Boolean);
    function HandlesFile(const AFileName: string): Boolean;
    function GetLongestItem: string;
    procedure GetParameterList(out ParameterList: IOTACodeInsightParameterList);
    procedure GetCodeInsightType(AChar: Char; AElement: Integer; out CodeInsightType: TOTACodeInsightType;
      out InvokeType: TOTAInvokeType);
    function InvokeCodeCompletion(HowInvoked: TOTAInvokeType; var Str: string): Boolean;
    function InvokeParameterCodeInsight(HowInvoked: TOTAInvokeType; var SelectedIndex: Integer): Boolean;
    procedure ParameterCodeInsightAnchorPos(var EdPos: TOTAEditPos);
    function ParameterCodeInsightParamIndex(EdPos: TOTAEditPos): Integer;
    function GetHintText(HintLine, HintCol: Integer): string;
    function GotoDefinition(out AFileName: string; out ALineNum: Integer; Index: Integer = -1): Boolean;
    procedure Done(Accepted: Boolean; out DisplayParams: Boolean);
  end;

  { the built-in manager's list: SdCodeInsight's items, filtered by the start of their names }
  TSdCISymbolList = class(TInterfacedObject, IOTACodeInsightSymbolList)
  private
    FItems: TCIItemList;
    FByName, FByScope: TList;      // the items by name (soAlpha), in the engine's order (soScope)
    FShown: TList;                 // those the filter lets through, in the order chosen
    FSort: TOTASortOrder;
    FFilter: string;
    FEncoding: TSdEncoding;
    procedure Refilter;
    function Item(I: Integer): PCIItem;
    function Txt(const S: string): string;
  public
    constructor Create(AItems: TCIItemList; const AEncoding: TSdEncoding);
    destructor Destroy; override;
    procedure Clear;
    function GetCount: Integer;
    function GetSymbolIsReadWrite(I: Integer): Boolean;
    function GetSymbolIsAbstract(I: Integer): Boolean;
    function GetViewerSymbolFlags(I: Integer): TOTAViewerSymbolFlags;
    function GetViewerVisibilityFlags(I: Integer): TOTAViewerVisibilityFlags;
    function GetProcDispatchFlags(I: Integer): TOTAProcDispatchFlags;
    procedure SetSortOrder(const Value: TOTASortOrder);
    function GetSortOrder: TOTASortOrder;
    function FindIdent(const AnIdent: string): Integer;
    function FindSymIndex(const Ident: string; var Index: Integer): Boolean;
    procedure SetFilter(const FilterText: string);
    function GetSymbolText(Index: Integer): string;
    function GetSymbolTypeText(Index: Integer): string;
    function GetSymbolClassText(I: Integer): string;
  end;

  { the built-in manager's parameters: SdCodeInsight's hints, a parameter per line }
  TSdCIParamList = class(TInterfacedObject, IOTACodeInsightParameterList)
  private
    FHints: TCIParamHintArray;
    FEncoding: TSdEncoding;
  public
    constructor Create(const AHints: TCIParamHintArray; const AEncoding: TSdEncoding);
    procedure GetParameterQuery(ProcIndex: Integer; out ParamQuery: IOTACodeInsightParamQuery);
    function GetParamDelimiter: Char;
    function GetProcedureCount: Integer;
    function GetProcedureParamsText(I: Integer): string;
  end;

  { one procedure's parameters taken apart: "const A: Integer = 0" - 'const', 'A', 'Integer', a
    default }
  TSdCIParamQuery = class(TInterfacedObject, IOTACodeInsightParamQuery)
  private
    FParams: TStringList;
    FRetVal: string;
    function Part(Index, Which: Integer): string;
  public
    constructor Create(const Hint: TCIParamHint; const AEncoding: TSdEncoding);
    destructor Destroy; override;
    function GetQueryParamCount: Integer;
    function GetQueryRetVal: string;
    function GetQueryParamSymText(Index: Integer): string;
    function GetQueryParamTypeText(Index: Integer): string;
    function GetQueryParamHasDefaultVal(Index: Integer): Boolean;
    function GetQueryParamInvokeTypeText(Index: Integer): string;
  end;

var
  CIServices: TSdOtaCodeInsightServices;

{ ---------------------------------------------------------------- helpers }

{ the editor's characters [P, Q): every byte of their IDE text in Chars }
function CharIn(Ed: TSciEdit; P, Q: Integer; const Chars: TSysCharSet; const E: TSdEncoding): Boolean;
var
  S: string;
  I: Integer;
begin
  S := Ed.GetRange(P, Q);
  if (Length(S) = 1) and (S[1] < #128) then
  begin
    Result := S[1] in Chars;
    Exit;
  end;
  S := EditorToAnsi(S, E);
  Result := S <> '';
  for I := 1 to Length(S) do
    if not (S[I] in Chars) then
    begin
      Result := False;
      Exit;
    end;
end;

{ the token around Caret: [A, B), the characters of Chars before and after it }
procedure TokenAround(Ed: TSciEdit; Caret: Integer; const Chars: TSysCharSet; const E: TSdEncoding;
  out A, B: Integer);
var
  P, N: Integer;
begin
  A := Caret;
  while A > 0 do
  begin
    P := Ed.Sci(SCI_POSITIONBEFORE, A);
    if (P >= A) or not CharIn(Ed, P, A, Chars, E) then Break;
    A := P;
  end;
  B := Caret;
  N := Ed.TextLength;
  while B < N do
  begin
    P := Ed.Sci(SCI_POSITIONAFTER, B);
    if (P <= B) or not CharIn(Ed, B, P, Chars, E) then Break;
    B := P;
  end;
end;

{ a procedure's parameters: the lines of a text, a parameter per line }
procedure SplitParams(const S: string; var H: TCIParamHint);
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    L.Text := S;
    SetLength(H.Params, L.Count);
    for I := 0 to L.Count - 1 do H.Params[I] := L[I];
  finally
    L.Free;
  end;
end;

{ the element of an expert's symbol: the editor theme's Code Insight elements }
function FlagElement(Flag: TOTAViewerSymbolFlags): TEditorElement;
begin
  case Flag of
    vsfProcedure, vsfConstructor, vsfDestructor: Result := eeCompProcedure;
    vsfFunction: Result := eeCompFunction;
    vsfProperty, vsfEvent: Result := eeCompProperty;
    vsfVariable: Result := eeCompVariable;
    vsfConstant: Result := eeCompConstant;
    vsfType, vsfInterface: Result := eeCompType;
    vsfUnit: Result := eeCompUnit;
    vsfLabel: Result := eeCompLabel;
  else
    Result := eeCompletion;
  end;
end;

{ ---------------------------------------------------------------- TSdOtaCodeInsightServices }

constructor TSdOtaCodeInsightServices.Create(const Controller: IInterface);
var
  B: TSdPascalCIManager;
begin
  inherited Create(Controller);
  FManagers := TSdNotifierList.Create;
  FMarks := TBits.Create;
  FSource := TSdOtaSymbolSource.Create;
  FViewer := TSdCIViewer.Create;
  FRemoved := TSdRemovedCIManager.Create;
  B := TSdPascalCIManager.Create;
  FBuiltInObj := B;
  FBuiltIn := B;
  FHtml := TSdHtmlCIManager.Create;
  FManagers.Add(FHtml);
  FManagers.Add(FBuiltIn);
  FExact := -1;
  CIServices := Self;
end;

destructor TSdOtaCodeInsightServices.Destroy;
begin
  if CIServices = Self then CIServices := nil;
  if FWnd <> 0 then
  begin
    KillTimer(FWnd, TimerId);
    Classes.DeallocateHWnd(FWnd);
  end;
  if (CompletionPopup <> nil) and (CompletionPopup.Source = FSource) then CompletionPopup.DetachSource;
  FSource.Free;
  FMarks.Free;
  FManagers.Free;
  inherited;
end;

function TSdOtaCodeInsightServices.Wnd: HWND;
begin
  if FWnd = 0 then FWnd := Classes.AllocateHWnd(WndProc);
  Result := FWnd;
end;

procedure TSdOtaCodeInsightServices.WndProc(var Message: TMessage);
begin
  case Message.Msg of
    WM_TIMER:
      if Message.WParam = TimerId then
      begin
        KillTimer(FWnd, TimerId);
        TimerDone;
      end;
    WM_CICANCEL:
      if Message.WParam = FSerial then Cancel;
  else
    Message.Result := DefWindowProc(FWnd, Message.Msg, Message.WParam, Message.LParam);
  end;
end;

{ Delphi's choice: from the newest manager down, the first that handles the file and is enabled }
function TSdOtaCodeInsightServices.ManagerFor(Page: TEditorPage): IOTACodeInsightManager;
var
  I: Integer;
  M: IOTACodeInsightManager;
begin
  Result := nil;
  if (Page = nil) or (FManagers.Count = 0) then Exit;
  { only Delphi's own two (markup, Pascal): no interface call at each key - the markup manager
    offers nothing }
  if (FManagers.Active = 2) and (Pointer(FManagers[0]) = Pointer(FHtml)) and (Pointer(FManagers[1]) = Pointer(FBuiltIn)) then
  begin
    if TSdPascalCIManager(FBuiltInObj).FEnabled and TSdPascalCIManager(FBuiltInObj).HandlesPage(Page) then
      Result := FBuiltIn;
    Exit;
  end;
  for I := FManagers.Count - 1 downto 0 do
    if Supports(FManagers[I], IOTACodeInsightManager, M) then
      try
        if M.HandlesFile(Page.FileName) and M.GetEnabled then
        begin
          Result := M;
          Exit;
        end;
      except
        OtaCaught('IOTACodeInsightManager.HandlesFile', False);
      end;
end;

function TSdOtaCodeInsightServices.Alive(Serial: Integer): Boolean;
begin
  Result := (FSerial = Serial) and (FPage <> nil);
end;

{ the caret and the text as the session sees them now: a change from here on is the user's }
procedure TSdOtaCodeInsightServices.Seen;
begin
  if FPage = nil then Exit;
  FCaret := FPage.Editor.CaretPos;
  FVersion := FPage.TextVersion;
end;

function TSdOtaCodeInsightServices.Invoke(Page: TEditorPage; Key: Char; Pos: Integer): Boolean;
var
  M: IOTACodeInsightManager;
begin
  Result := False;
  if Page = nil then Exit;
  Result := True;
  if FQuery or (FBusy > 0) then Exit;
  M := ManagerFor(Page);
  if M = nil then Exit;
  if Pointer(M) = Pointer(FBuiltIn) then
  begin
    Result := False;
    Exit;
  end;
  { the invocation before ends: its list, its hint, its wait }
  if FPage <> nil then Cancel;
  Start(Page, M, Key, Pos);
end;

function TSdOtaCodeInsightServices.OwnAllowed(Page: TEditorPage): Boolean;
begin
  Result := not FQuery and (FBuiltIn <> nil) and (Pointer(ManagerFor(Page)) = Pointer(FBuiltIn));
end;

{ in an except block: the exception of the expert's code logged, whatever its class, and the
  session ended }
procedure TSdOtaCodeInsightServices.Failed(const What: string);
begin
  OtaCaught('IOTACodeInsightManager.' + What, False);
  Cancel;
end;

{ Delphi's invocation: AllowCodeInsight, then GetCodeInsightType with the key's
  presets - the type of #0..#3, itAuto for them and itManual for a typed key - and the element at
  the place (the character before the caret; the mouse's for #2 / #3) }
procedure TSdOtaCodeInsightServices.Start(Page: TEditorPage; const M: IOTACodeInsightManager; Key: Char;
  Pos: Integer);
var
  Serial, Elem: Integer;
  Allow: Boolean;
  T: TOTACodeInsightType;
  How: TOTAInvokeType;
  Ed: TSciEdit;
begin
  Ed := Page.Editor;
  if not Ed.Ready then Exit;
  Inc(FSerial);
  Serial := FSerial;
  FPage := Page;
  FManager := M;
  FState := csIdle;
  FHaveChars := False;
  FChars := [];
  FCloseKey := #0;
  FExact := -1;
  FTyped := '';
  { Ctrl+click: the caret on the identifier clicked - GetEditView's cursor is the place browsed }
  if (Key = #2) and (Pos >= 0) and (Pos <> Ed.CaretPos) then Ed.Sci(SCI_SETEMPTYSELECTION, Pos);
  Seen;
  case Key of
    #0: T := citCodeInsight;
    #1: T := citParameterCodeInsight;
    #2: T := citBrowseCodeInsight;
    #3: T := citHintCodeInsight;
  else
    T := citNone;
  end;
  if Key in [#0..#3] then How := itAuto else How := itManual;
  if (Key in [#2, #3]) and (Pos >= 0) then Elem := OtaAttributeAt(Ed, Pos)
  else Elem := OtaAttributeAt(Ed, Ed.CaretPos - 1);
  Allow := True;
  Inc(FBusy);
  try
    try
      M.AllowCodeInsight(Allow, Key);
      if not Alive(Serial) then Exit;
      if Allow then M.GetCodeInsightType(Key, Elem, T, How);
    except
      Failed('GetCodeInsightType');
      Exit;
    end;
  finally
    Dec(FBusy);
  end;
  if not Alive(Serial) then Exit;
  if not Allow then
  begin
    EndSession;
    Exit;
  end;
  case T of
    citCodeInsight:
      if How = itManual then OpenList(itManual)
      else if EditorOptions.AutoComplete then StartTimer(csDelay, EditorOptions.CodeDelay * 100)
      else EndSession;
    citParameterCodeInsight:
      if How = itManual then ShowParams(itManual)
      else if EditorOptions.AutoParameters then StartTimer(csParamDelay, 400 + EditorOptions.CodeDelay * 100)
      else EndSession;
    citBrowseCodeInsight: Browse(-1);
    citHintCodeInsight: Hint(Pos);
  else
    EndSession;
  end;
end;

{ nothing of the session is used any more: its list and hint go, its wait ends }
procedure TSdOtaCodeInsightServices.EndSession;
begin
  StopTimer;
  if (CompletionPopup <> nil) and (CompletionPopup.Source = FSource) then CompletionPopup.DetachSource;
  if FParamShown then
  begin
    FParamShown := False;
    if ParamHint <> nil then ParamHint.HideHints;
  end;
  FState := csIdle;
  FPage := nil;
  FManager := nil;
  FSymbols := nil;
  FCustomDraw := nil;
  FParams := nil;
  FMarks.Size := 0;
  FCloseKey := #0;
  FTyped := '';
  FExact := -1;
  FDrawFailed := False;
  Inc(FSerial);
end;

{ Delphi's CancelCodeInsightProcessing: the viewer and the hint hidden, the timers
  stopped - no Done; the symbol list cleared }
procedure TSdOtaCodeInsightServices.Cancel;
var
  SL: IOTACodeInsightSymbolList;
begin
  if FPage = nil then Exit;
  SL := FSymbols;
  EndSession;
  if SL <> nil then
    try
      SL.Clear;
    except
      OtaCaught('IOTACodeInsightSymbolList.Clear', False);
    end;
end;

procedure TSdOtaCodeInsightServices.StartTimer(State: TSdCIState; Ms: Integer);
begin
  FState := State;
  Seen;
  if Ms < 10 then Ms := 10;
  SetTimer(Wnd, TimerId, Ms, nil);
end;

procedure TSdOtaCodeInsightServices.StopTimer;
begin
  if FWnd <> 0 then KillTimer(FWnd, TimerId);
  FReinvoke := False;
end;

procedure TSdOtaCodeInsightServices.TimerDone;
begin
  if FPage = nil then Exit;
  { an expert's call runs (it handles messages): the step waits for its end }
  if FBusy > 0 then
  begin
    SetTimer(Wnd, TimerId, 50, nil);
    Exit;
  end;
  case FState of
    csDelay: DelayDone;
    csParamDelay:
      begin
        FState := csIdle;
        ShowParams(itAuto);
      end;
    csParams:
      if FReinvoke then
      begin
        FReinvoke := False;
        ShowParams(itTimer);
      end;
  end;
end;

{ the completion delay is over (as Delphi's): EditorTokenValidChars(True), the token up
  to the caret, PreValidateCodeInsight - then the list, itAuto }
procedure TSdOtaCodeInsightServices.DelayDone;
var
  Serial, A, B: Integer;
  Chars: TSysCharSet;
  Token: string;
  OK: Boolean;
  Ed: TSciEdit;
begin
  FState := csIdle;
  Serial := FSerial;
  Ed := FPage.Editor;
  Inc(FBusy);
  try
    try
      Chars := FManager.EditorTokenValidChars(True);
      if not Alive(Serial) then Exit;
      TokenAround(Ed, Ed.CaretPos, Chars, FPage.Encoding, A, B);
      Token := EditorToAnsi(Ed.GetRange(A, Ed.CaretPos), FPage.Encoding);
      OK := FManager.PreValidateCodeInsight(Token);
    except
      Failed('PreValidateCodeInsight');
      Exit;
    end;
  finally
    Dec(FBusy);
  end;
  if not Alive(Serial) then Exit;
  if OK then OpenList(itAuto) else EndSession;
end;

{ the manager's token characters: asked for once in a session that has none yet }
function TSdOtaCodeInsightServices.TokenChars: TSysCharSet;
begin
  if not FHaveChars and (FManager <> nil) then
  begin
    FChars := FManager.EditorTokenValidChars(False);
    FHaveChars := True;
  end;
  Result := FChars;
end;

{ Delphi's code completion }
procedure TSdOtaCodeInsightServices.OpenList(How: TOTAInvokeType);
var
  Serial, A, B, N, Sel: Integer;
  Str, Longest: string;
  SL: IOTACodeInsightSymbolList;
  MS, OK: Boolean;
  Ed: TSciEdit;
begin
  Serial := FSerial;
  Ed := FPage.Editor;
  N := 0;
  Sel := -1;
  Inc(FBusy);
  try
    try
      FChars := FManager.EditorTokenValidChars(False);
      FHaveChars := True;
      if not Alive(Serial) then Exit;
      TokenAround(Ed, Ed.CaretPos, FChars, FPage.Encoding, A, B);
      Str := EditorToAnsi(Ed.GetRange(A, B), FPage.Encoding);
      OK := FManager.InvokeCodeCompletion(How, Str);
      if not Alive(Serial) then Exit;
      if OK then
      begin
        SL := nil;
        FManager.GetSymbolList(SL);
        if not Alive(Serial) then Exit;
        OK := (SL <> nil) and (SL.GetCount > 0);
      end;
      if OK then
      begin
        Longest := FManager.GetLongestItem;
        MS := FManager.GetMultiSelect;
        if not Alive(Serial) then Exit;
        FSymbols := SL;
        FMultiSelect := MS;
        Supports(FManager, INTACustomDrawCodeInsightViewer, FCustomDraw);
        FTokenStart := A;
        FTyped := Str;
        Filter(Str, N, Sel);
        if not Alive(Serial) then Exit;
      end;
    except
      Failed('InvokeCodeCompletion');
      Exit;
    end;
  finally
    Dec(FBusy);
  end;
  if not Alive(Serial) then Exit;
  if not OK then
  begin
    EndSession;
    Exit;
  end;
  if (N = 0) or (CompletionPopup = nil) then
  begin
    CloseList(False);
    Exit;
  end;
  FMarks.Size := 0;
  FCloseKey := #0;
  FDrawFailed := False;
  CompletionPopup.OpenSource(Ed, FSource, FTokenStart, N, Sel, Longest);
  FViewerMade := True;
  FState := csList;
  Seen;
end;

{ Delphi's filter: SetFilter, the rows, the row the expert's FindSymIndex finds chosen,
  else none (Delphi 7's, measured: its list then has no row selected) }
procedure TSdOtaCodeInsightServices.Filter(const Text: string; out Count, Selected: Integer);
var
  Idx: Integer;
begin
  FSymbols.SetFilter(Text);
  Count := FSymbols.GetCount;
  FExact := -1;
  if Text <> '' then
  begin
    Idx := 0;
    if FSymbols.FindSymIndex(Text, Idx) and (Idx >= 0) and (Idx < Count) then FExact := Idx;
  end;
  Selected := FExact;
  FLastCount := Count;
  FMarks.Size := 0;
end;

function TSdOtaCodeInsightServices.ListShown: Boolean;
begin
  Result := (CompletionPopup <> nil) and CompletionPopup.Active and (CompletionPopup.Source = FSource);
end;

function TSdOtaCodeInsightServices.OwnListShown: Boolean;
begin
  Result := (CompletionPopup <> nil) and CompletionPopup.Active and (CompletionPopup.Source = nil);
end;

{ the text or the caret changed under the list: the token again, cut at the caret -
  the list filtered by it; the caret out of the token: closed, not accepted }
procedure TSdOtaCodeInsightServices.ListChanged;
var
  Serial, A, B, N, Sel: Integer;
  S: string;
  Ed: TSciEdit;
  Left: Boolean;
begin
  if not ListShown then
  begin
    Cancel;
    Exit;
  end;
  Serial := FSerial;
  Ed := FPage.Editor;
  N := 0;
  Sel := -1;
  Inc(FBusy);
  try
    try
      FChars := FManager.EditorTokenValidChars(False);
      FHaveChars := True;
      if not Alive(Serial) then Exit;
      TokenAround(Ed, Ed.CaretPos, FChars, FPage.Encoding, A, B);
      Left := A <> FTokenStart;
      if not Left then
      begin
        S := EditorToAnsi(Ed.GetRange(A, Ed.CaretPos), FPage.Encoding);
        FTyped := S;
        Filter(S, N, Sel);
      end;
    except
      Failed('SetFilter');
      Exit;
    end;
  finally
    Dec(FBusy);
  end;
  if not Alive(Serial) then Exit;
  if Left or (N = 0) then CloseList(False)
  else CompletionPopup.SetRows(N, Sel);
end;

{ a key for the list: OnEditorKey - accepted (the key is the close key, but Enter)
  or closing: the key is eaten and the list closes }
function TSdOtaCodeInsightServices.EditorKey(Key: Char): Boolean;
var
  Serial: Integer;
  Close, Accept: Boolean;
begin
  Result := False;
  Serial := FSerial;
  Close := False;
  Accept := False;
  Inc(FBusy);
  try
    try
      FManager.OnEditorKey(Key, Close, Accept);
    except
      Failed('OnEditorKey');
      Exit;
    end;
  finally
    Dec(FBusy);
  end;
  if not Alive(Serial) then Exit;
  if Accept and (Key <> #13) then FCloseKey := Key;
  if Accept or Close then
  begin
    Result := True;
    CloseList(Accept);
  end;
end;

{ the list closes: Done - the viewer still answers then, the expert inserts what it
  wants (InsertText, its edit view) -, the symbol list cleared; DisplayParams: the parameters
  asked for next (with Code parameters on) }
procedure TSdOtaCodeInsightServices.CloseList(Accepted: Boolean);
var
  Serial: Integer;
  DisplayParams: Boolean;
  Page: TEditorPage;
begin
  if FPage = nil then Exit;
  Serial := FSerial;
  Page := FPage;
  if ListShown then CompletionPopup.CloseUp;
  FState := csIdle;
  DisplayParams := False;
  Inc(FBusy);
  try
    try
      FManager.Done(Accepted, DisplayParams);
    except
      Failed('Done');
      Exit;
    end;
  finally
    Dec(FBusy);
  end;
  if not Alive(Serial) then Exit;
  Cancel;
  if DisplayParams and EditorOptions.AutoParameters and Page.HandleAllocated then
    PostMessage(Page.Handle, CM_SD_CODEINSIGHT, 1, 0);
end;

function TSdOtaCodeInsightServices.Marked(Index: Integer): Boolean;
begin
  Result := FMultiSelect and (Index >= 0) and (Index < FMarks.Size) and FMarks[Index];
end;

{ the row under the cursor of the list chosen alone (the first when none is) }
procedure TSdOtaCodeInsightServices.ChooseOnly;
begin
  if (CompletionPopup.ItemIndex < 0) and (CompletionPopup.Count > 0) then CompletionPopup.ItemIndex := 0;
  FMarks.Size := 0;
  CompletionPopup.Invalidate;
end;

procedure TSdOtaCodeInsightServices.ToggleMark;
var
  I: Integer;
begin
  I := CompletionPopup.ItemIndex;
  if I < 0 then Exit;
  if FMarks.Size <= I then FMarks.Size := I + 1;
  FMarks[I] := not FMarks[I];
  CompletionPopup.Invalidate;
end;

{ Delphi's parameter insight }
procedure TSdOtaCodeInsightServices.ShowParams(How: TOTAInvokeType);
var
  Serial, Sel, I, N, Anchor: Integer;
  OK: Boolean;
  PL: IOTACodeInsightParameterList;
  Hints: TCIParamHintArray;
  Delim: Char;
  EdPos: TOTAEditPos;
  Ed: TSciEdit;
  P: TPoint;
begin
  Serial := FSerial;
  Ed := FPage.Editor;
  Delim := ',';
  Sel := 0;
  Inc(FBusy);
  try
    try
      OK := FManager.InvokeParameterCodeInsight(How, Sel);
      if not Alive(Serial) then Exit;
      if OK then
      begin
        PL := nil;
        FManager.GetParameterList(PL);
        if not Alive(Serial) then Exit;
        OK := (PL <> nil) and (PL.GetProcedureCount > 0);
      end;
      if OK then
      begin
        Delim := PL.GetParamDelimiter;
        N := PL.GetProcedureCount;
        SetLength(Hints, N);
        for I := 0 to N - 1 do
        begin
          Hints[I].Signature := '';
          SplitParams(PL.GetProcedureParamsText(I), Hints[I]);
        end;
        EdPos := OffsetToEditPos(Ed, Ed.CaretPos);
        FManager.ParameterCodeInsightAnchorPos(EdPos);
      end;
    except
      Failed('InvokeParameterCodeInsight');
      Exit;
    end;
  finally
    Dec(FBusy);
  end;
  if not Alive(Serial) then Exit;
  if not OK or (ParamHint = nil) then
  begin
    EndSession;
    Exit;
  end;
  FParams := PL;
  Anchor := EditPosToOffset(Ed, EdPos);
  P := Ed.PointFromPos(Anchor);
  P := Ed.ClientToScreen(Point(P.X, P.Y + Ed.TextHeight + 2));
  ParamHint.ShowHints(P, Hints, Sel, Ed.TextHeight + 4, Delim + ' ');
  FParamShown := True;
  FState := csParams;
  Seen;
end;

{ the caret moved or the text changed under the hint: ParameterCodeInsightParamIndex - the
  parameter bold, or (-1) the parameters asked for again 300 ms later, itTimer }
procedure TSdOtaCodeInsightServices.ParamsChanged;
var
  Serial, I: Integer;
begin
  if (ParamHint = nil) or not ParamHint.Showing then
  begin
    FParamShown := False;
    Cancel;
    Exit;
  end;
  Serial := FSerial;
  Inc(FBusy);
  try
    try
      I := FManager.ParameterCodeInsightParamIndex(OffsetToEditPos(FPage.Editor, FPage.Editor.CaretPos));
    except
      Failed('ParameterCodeInsightParamIndex');
      Exit;
    end;
  finally
    Dec(FBusy);
  end;
  if not Alive(Serial) then Exit;
  if I >= 0 then
  begin
    StopTimer;
    ParamHint.SetActive(I);
  end
  else
  begin
    SetTimer(Wnd, TimerId, 300, nil);
    FReinvoke := True;
  end;
end;

{ Delphi's browse: GotoDefinition - the file and line shown (a place of the browse
  history), nothing for a file the manager left empty, "Unable to locate file" when it failed;
  from the list (Index >= 0) the list closes, not accepted }
procedure TSdOtaCodeInsightServices.Browse(Index: Integer);
var
  Serial, L: Integer;
  F: string;
  OK: Boolean;
begin
  Serial := FSerial;
  F := '';
  L := 0;
  Inc(FBusy);
  try
    try
      OK := FManager.GotoDefinition(F, L, Index);
    except
      Failed('GotoDefinition');
      Exit;
    end;
  finally
    Dec(FBusy);
  end;
  if not Alive(Serial) then Exit;
  if Index >= 0 then CloseList(False) else EndSession;
  if OK then
  begin
    if (F <> '') and (L > 0) and (OtaHost <> nil) then OtaHost.ShowFileLine(F, L, 1);
  end
  else
  begin
    if IDE <> nil then IDE.ShowStatus(Format('Unable to locate file "%s"', [ExtractFileName(F)]));
    MessageBeep(MB_ICONASTERISK);
  end;
end;

{ the hint of a place: GetHintText of its line and column, the code tip at its word -
  not while a list or the parameters show }
procedure TSdOtaCodeInsightServices.Hint(Pos: Integer);
var
  Serial, S, E: Integer;
  H: string;
  EdPos: TOTAEditPos;
  Page: TEditorPage;
  Ed: TSciEdit;
begin
  Serial := FSerial;
  Page := FPage;
  Ed := Page.Editor;
  H := '';
  if (Pos >= 0) and not ((CompletionPopup <> nil) and CompletionPopup.Active) and
    not ((ParamHint <> nil) and ParamHint.Showing) then
  begin
    EdPos := OffsetToEditPos(Ed, Pos);
    Inc(FBusy);
    try
      try
        H := FManager.GetHintText(EdPos.Line, EdPos.Col);
      except
        Failed('GetHintText');
        Exit;
      end;
    finally
      Dec(FBusy);
    end;
    if not Alive(Serial) then Exit;
  end;
  EndSession;
  if (H = '') or (CodeTip = nil) or not Ed.Shown then Exit;
  if Ed.WordAt(Pos, S, E) = '' then S := Pos;
  { the expert's text (ANSI, the IDE's) in the code tip, as its language is the expert's: not
    coloured }
  CodeTip.ShowLines(TextTipLines(H), Ed.ScreenTextRect(S, S), Ed);
end;

{ a key of the page: the list's and the hint's first; during a wait any key ends it }
function TSdOtaCodeInsightServices.KeyDown(Page: TEditorPage; var Key: Word; Shift: TShiftState): Boolean;
begin
  Result := False;
  if (Page = nil) or (Page <> FPage) or (FBusy > 0) then Exit;
  case FState of
    csDelay, csParamDelay:
      if not (Key in [VK_SHIFT, VK_CONTROL, VK_MENU]) then Cancel;
    csParams:
      if (Key = VK_ESCAPE) and (Shift = []) then
      begin
        Cancel;
        Key := 0;
        Result := True;
      end;
    csList:
      begin
        if not ListShown then
        begin
          Cancel;
          Exit;
        end;
        { a multi-select list is Delphi 7's list box of extended selection (measured): Space and the
          arrows choose one row, Ctrl+Space toggles a row; another list eats Ctrl+Space }
        if (Key = VK_SPACE) and FMultiSelect and (Shift * [ssShift, ssAlt] = []) then
        begin
          if ssCtrl in Shift then ToggleMark else ChooseOnly;
          Result := True;
        end
        else if (Key = VK_SPACE) and (ssCtrl in Shift) then Result := True
        else if Shift * [ssShift, ssCtrl, ssAlt] = [] then
          case Key of
            VK_UP, VK_DOWN, VK_PRIOR, VK_NEXT, VK_HOME, VK_END:
              begin
                Result := CompletionPopup.StepSelection(Key);
                if FMultiSelect then FMarks.Size := 0;
              end;
            VK_RETURN: Result := EditorKey(#13);
            VK_TAB: Result := EditorKey(#9);
            VK_ESCAPE: Result := EditorKey(#27);
          end;
        if Result then Key := 0;
      end;
  end;
end;

{ a character for the list: OnEditorKey first (Enter, Tab and Esc came as keys; the bytes after
  the first of a character of several are no keys of their own) }
function TSdOtaCodeInsightServices.KeyPress(Page: TEditorPage; var Key: Char): Boolean;
begin
  Result := False;
  if (Page = nil) or (Page <> FPage) or (FBusy > 0) then Exit;
  case FState of
    csDelay, csParamDelay: Cancel;
    csList:
      begin
        if Key in [#0, #9, #10, #13, #27] then Exit;
        if (IdeEncoding.CodePage = CP_UTF8) and (Byte(Key) and $C0 = $80) then Exit;
        if not ListShown then
        begin
          Cancel;
          Exit;
        end;
        Result := EditorKey(Key);
        if Result then Key := #0;
      end;
  end;
end;

procedure TSdOtaCodeInsightServices.Changed(Page: TEditorPage);
begin
  if (Page = nil) or (Page <> FPage) or (FBusy > 0) then Exit;
  if (Page.Editor.CaretPos = FCaret) and (Page.TextVersion = FVersion) then Exit;
  Seen;
  case FState of
    csDelay, csParamDelay: Cancel;
    csList: ListChanged;
    csParams: ParamsChanged;
  end;
end;

{ the module's managers leave holes; a session or a query context of its code ends first }
procedure TSdOtaCodeInsightServices.DropModule(Module: HMODULE);
begin
  if Module = 0 then Exit;
  if (FPage <> nil) and ((InterfaceModule(FManager) = Module) or (InterfaceModule(FSymbols) = Module) or
    (InterfaceModule(FParams) = Module) or (InterfaceModule(FCustomDraw) = Module)) then Cancel;
  if (InterfaceModule(FQueryView) = Module) or (InterfaceModule(FQueryManager) = Module) then
  begin
    FQueryView := nil;
    FQueryManager := nil;
    FQuery := False;
  end;
  FManagers.DropModule(Module);
end;

procedure TSdOtaCodeInsightServices.AddModules(List: TList);
begin
  FManagers.AddModules(List);
end;

procedure TSdOtaCodeInsightServices.Shutdown;
begin
  Cancel;
  FQueryView := nil;
  FQueryManager := nil;
  FQuery := False;
  FManagers.Clear;
end;

function TSdOtaCodeInsightServices.DebugText: string;
const
  States: array[TSdCIState] of string = ('idle', 'delay', 'list', 'paramdelay', 'params');
var
  M: IOTACodeInsightManager;
  N: string;
  K: string;
begin
  GetCurrentCodeInsightManager(M);
  N := '';
  if M <> nil then
    try
      N := M.GetName;
    except
      N := '?';
    end;
  if FCloseKey = #0 then K := '' else K := FCloseKey;
  Result := Format('%d|%s|%s|%s|%d|%s', [FManagers.Count, N, States[FState], FTyped, FExact, K]);
end;

{ ---------------------------------------------------------------- IOTACodeInsightServices }

{ a query context's view; else the session's page's; else the active page's - focused or not
  (D7 Studio's editor may not have the focus while an expert works with it) }
procedure TSdOtaCodeInsightServices.GetEditView(out EditView: IOTAEditView);
var
  P: TEditorPage;
  B: IOTAEditBuffer;
begin
  EditView := nil;
  if FQuery then
  begin
    EditView := FQueryView;
    Exit;
  end;
  P := FPage;
  if (P = nil) and OwnListShown then P := OtaPageOfEditor(CompletionPopup.Editor);
  if (P = nil) and (OtaHost <> nil) then P := OtaHost.ActivePage;
  B := OtaPageBuffer(P);
  if B <> nil then EditView := B.GetTopView;
end;

{ none under a query context, and none until a list has been shown (Delphi 7's, measured) }
procedure TSdOtaCodeInsightServices.GetViewer(out Viewer: IOTACodeInsightViewer);
begin
  if OwnListShown then FViewerMade := True;
  if FQuery or not FViewerMade then Viewer := nil else Viewer := FViewer;
end;

procedure TSdOtaCodeInsightServices.GetCurrentCodeInsightManager(out CodeInsightManager: IOTACodeInsightManager);
begin
  if FQueryManager <> nil then CodeInsightManager := FQueryManager
  else if FPage <> nil then CodeInsightManager := FManager
  else if OwnListShown or ((ParamHint <> nil) and ParamHint.Showing and not FParamShown) then
    CodeInsightManager := FBuiltIn
  else
    CodeInsightManager := nil;
end;

{ the session ends without Done, and D7 Studio's own list and hint close }
procedure TSdOtaCodeInsightServices.CancelCodeInsightProcessing;
var
  P: TEditorPage;
begin
  Cancel;
  if OwnListShown then
  begin
    P := OtaPageOfEditor(CompletionPopup.Editor);
    if P <> nil then P.CloseCodePopups else CompletionPopup.CloseUp;
  end;
  if (ParamHint <> nil) and ParamHint.Showing then ParamHint.HideHints;
  if (OtaHost <> nil) and (OtaHost.ActivePage <> nil) then OtaHost.ActivePage.CloseCodePopups;
end;

{ Delphi's: nil -1; a manager whose IDString is one of the managers' already - that one's index,
  nothing added; else the next index }
function TSdOtaCodeInsightServices.AddCodeInsightManager(const ACodeInsightManager: IOTACodeInsightManager): Integer;
var
  I: Integer;
  ID: string;
  M: IOTACodeInsightManager;
begin
  Result := -1;
  if ACodeInsightManager = nil then Exit;
  try
    ID := ACodeInsightManager.GetIDString;
  except
    OtaCaught('IOTACodeInsightManager.GetIDString', False);
    Exit;
  end;
  for I := 0 to FManagers.Count - 1 do
    if Supports(FManagers[I], IOTACodeInsightManager, M) then
      try
        if SameText(M.GetIDString, ID) then
        begin
          Result := I;
          Exit;
        end;
      except
        OtaCaught('IOTACodeInsightManager.GetIDString', False);
      end;
  Result := FManagers.Add(ACodeInsightManager);
end;

{ Delphi 7's (measured): taken out of the list - the later managers one index down; a bad index:
  nothing. The manager's session ends (no Done) }
procedure TSdOtaCodeInsightServices.RemoveCodeInsightManager(Index: Integer);
begin
  if (Index < 0) or (Index >= FManagers.Count) then Exit;
  if (FPage <> nil) and (FManagers[Index] <> nil) and SameInterface(FManager, FManagers[Index]) then Cancel;
  FManagers.Delete(Index);
end;

{ Delphi's: not while a query context is set, nor outside an invocation (its editor is then
  none); Replace: the token at the caret (the manager's characters; D7 Studio's own list: an
  identifier's) - one undo step, the caret after the text }
procedure TSdOtaCodeInsightServices.InsertText(const Str: string; Replace: Boolean);
var
  P: TEditorPage;
  Ed: TSciEdit;
  Chars: TSysCharSet;
  A, B: Integer;
  S: string;
begin
  if FQuery then Exit;
  P := FPage;
  if P <> nil then Chars := TokenChars
  else if OwnListShown then
  begin
    P := OtaPageOfEditor(CompletionPopup.Editor);
    Chars := IdentChars;
  end;
  if P = nil then Exit;
  Ed := P.Editor;
  if not Ed.Ready or Ed.ReadOnly then Exit;
  S := AnsiToEditor(Str, P.Encoding);
  if Replace then TokenAround(Ed, Ed.CaretPos, Chars, P.Encoding, A, B)
  else
  begin
    A := Ed.CaretPos;
    B := A;
  end;
  Ed.BeginUndo;
  try
    Ed.ReplaceRange(A, B - A, S);
  finally
    Ed.EndUndo;
  end;
  Ed.GotoPos(A + Length(S));
end;

function TSdOtaCodeInsightServices.GetCodeInsightManagerCount: Integer;
begin
  Result := FManagers.Count;
end;

function TSdOtaCodeInsightServices.GetCodeInsightManager(Index: Integer): IOTACodeInsightManager;
begin
  if (Index < 0) or (Index >= FManagers.Count) then raise EListError.CreateFmt(SListIndexError, [Index]);
  if not Supports(FManagers[Index], IOTACodeInsightManager, Result) then Result := FRemoved;
end;

{ Delphi's: both given - the context is set (no session, no viewer, no InsertText); (nil, nil)
  clears it; the manager is the current one while it is given }
procedure TSdOtaCodeInsightServices.SetQueryContext(const EditView: IOTAEditView;
  const CodeInsightManager: IOTACodeInsightManager);
begin
  FQueryView := EditView;
  FQueryManager := CodeInsightManager;
  FQuery := (EditView <> nil) and (CodeInsightManager <> nil);
  if FQuery and (FBusy = 0) then Cancel;
end;

{ ---------------------------------------------------------------- the page's calls }

function OtaCIInvoke(Page: TEditorPage; Key: Char; Pos: Integer): Boolean;
begin
  Result := (CIServices <> nil) and CIServices.Invoke(Page, Key, Pos);
end;

function OtaCIOwnAllowed(Page: TEditorPage): Boolean;
begin
  Result := (CIServices = nil) or CIServices.OwnAllowed(Page);
end;

function OtaCIKeyDown(Page: TEditorPage; var Key: Word; Shift: TShiftState): Boolean;
begin
  Result := (CIServices <> nil) and CIServices.KeyDown(Page, Key, Shift);
end;

function OtaCIKeyPress(Page: TEditorPage; var Key: Char): Boolean;
begin
  Result := (CIServices <> nil) and CIServices.KeyPress(Page, Key);
end;

procedure OtaCIChanged(Page: TEditorPage);
begin
  if CIServices <> nil then CIServices.Changed(Page);
end;

procedure OtaCICancel(Page: TEditorPage);
begin
  if (CIServices <> nil) and (Page <> nil) and (CIServices.FPage = Page) then CIServices.Cancel;
end;

function OtaCIDebugText: string;
begin
  if CIServices = nil then Result := '' else Result := CIServices.DebugText;
end;

{ ---------------------------------------------------------------- TSdOtaSymbolSource }

procedure TSdOtaSymbolSource.DrawRow(Popup: TCompletionPopup; Index: Integer; const Rect: TRect;
  Selected: Boolean);
var
  S: TSdOtaCodeInsightServices;
  C: TCanvas;
  DC: HDC;
  R, RC: TRect;
  Sel, Def, Abstr: Boolean;
  Back, Fore: TColor;
  Cls, Txt, Typ: string;
  Flag: TOTAViewerSymbolFlags;
  E: TEditorElement;
  X: Integer;
begin
  S := CIServices;
  C := Popup.Canvas;
  DC := C.Handle;
  Sel := Selected or ((S <> nil) and S.Marked(Index));
  if Sel then Back := clHighlight else Back := ElementBack(EditorOptions.Colors, eeCompletion);
  if Sel then Fore := clHighlightText else Fore := ElementFore(EditorOptions.Colors, eeCompletion);
  UIFill(DC, Rect, Back);
  if (S = nil) or (S.FSymbols = nil) then Exit;
  Cls := '';
  Txt := '';
  Typ := '';
  Flag := vsfUnknown;
  Abstr := False;
  Def := True;
  R := Classes.Rect(Rect.Left + Popup.TextLeft, Rect.Top, Rect.Right, Rect.Bottom);
  try
    if not S.FDrawFailed then
    begin
      Cls := S.FSymbols.GetSymbolClassText(Index);
      Flag := S.FSymbols.GetViewerSymbolFlags(Index);
      Abstr := S.FSymbols.GetSymbolIsAbstract(Index);
      if S.FCustomDraw <> nil then
      begin
        { the expert draws on the list's canvas as it finds it: its fonts, the row's ground }
        C.Refresh;
        C.Font := Popup.Font;
        C.Brush.Color := Back;
        C.Font.Color := Fore;
        S.FCustomDraw.DrawLine(Index, C, R, False, True, Def);
        C.Refresh;
      end;
      if Def then
      begin
        Txt := S.FSymbols.GetSymbolText(Index);
        Typ := S.FSymbols.GetSymbolTypeText(Index);
      end;
    end;
  except
    OtaCaught('IOTACodeInsightSymbolList (drawing)', False);
    S.FDrawFailed := True;
    PostMessage(S.Wnd, WM_CICANCEL, S.FSerial, 0);
    Exit;
  end;
  DC := C.Handle;
  { the symbol's class in its element's colour and font styles (an abstract method's: Abstract
    method's) }
  if Abstr then E := eeCompAbstract else E := FlagElement(Flag);
  SelectObject(DC, StyledFont(Popup.Font, EditorOptions.Colors[E]));
  RC := Classes.Rect(Rect.Left + 3, Rect.Top, Rect.Left + Popup.TextLeft - 4, Rect.Bottom);
  if Sel then
    UIText(DC, Cls, RC, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX or DT_END_ELLIPSIS, clHighlightText)
  else
    UIText(DC, Cls, RC, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX or DT_END_ELLIPSIS,
      ElementFore(EditorOptions.Colors, E));
  if not Def then Exit;
  SelectObject(DC, Popup.BoldFont.Handle);
  X := R.Left + UITextWidth(DC, Txt);
  UIText(DC, Txt, R, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX, Fore);
  SelectObject(DC, Popup.Font.Handle);
  if Typ = '' then Exit;
  R.Left := X + 2;
  UIText(DC, Typ, R, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX or DT_END_ELLIPSIS, Fore);
end;

function TSdOtaSymbolSource.RowText(Index: Integer): string;
begin
  Result := '';
  if (CIServices = nil) or (CIServices.FSymbols = nil) then Exit;
  try
    Result := CIServices.FSymbols.GetSymbolText(Index);
  except
    Result := '';
  end;
end;

{ a double click accepts }
procedure TSdOtaSymbolSource.RowDblClick(Index: Integer);
begin
  if (CIServices <> nil) and (CIServices.FState = csList) and (CIServices.FBusy = 0) then CIServices.CloseList(True);
end;

function TSdOtaSymbolSource.RowLink(Index: Integer): Boolean;
var
  S: TSdOtaCodeInsightServices;
begin
  Result := False;
  S := CIServices;
  if (S = nil) or (S.FState <> csList) or (S.FBusy > 0) then Exit;
  try
    Result := S.FManager.IsViewerBrowsable(Index);
  except
    OtaCaught('IOTACodeInsightManager.IsViewerBrowsable', False);
  end;
end;

procedure TSdOtaSymbolSource.RowBrowse(Index: Integer);
begin
  if (CIServices <> nil) and (CIServices.FState = csList) and (CIServices.FBusy = 0) then CIServices.Browse(Index);
end;

{ ---------------------------------------------------------------- TSdCIViewer }

{ the list shown: an expert's or D7 Studio's own }
function ListUp: Boolean;
begin
  Result := (CIServices <> nil) and (CompletionPopup <> nil) and
    (((CIServices.FPage <> nil) and (CIServices.FSymbols <> nil) and (CompletionPopup.Source = CIServices.FSource)) or
    CIServices.OwnListShown);
end;

{ the rows of the list shown - after it closed those it had last: Delphi 7's viewer keeps them
  (measured) }
function TSdCIViewer.GetItemCount: Integer;
begin
  Result := 0;
  if CIServices = nil then Exit;
  if ListUp then CIServices.FLastCount := CompletionPopup.Count;
  Result := CIServices.FLastCount;
end;

function TSdCIViewer.GetSelectedIndex: Integer;
begin
  if ListUp then Result := CompletionPopup.ItemIndex else Result := -1;
end;

function TSdCIViewer.GetSelected(Index: Integer): Boolean;
begin
  Result := ListUp and ((Index = CompletionPopup.ItemIndex) or CIServices.Marked(Index));
end;

{ the row an expert's viewer sees chosen (Delphi 7's, measured): text typed, its exact match - none
  else -, no text, the row chosen; none of a list whose rows the expert draws
  (INTACustomDrawCodeInsightViewer: Delphi 7's list has no text of theirs). Own: D7 Studio's own list;
  -1: none }
function TSdCIViewer.ChosenRow(out Own: Boolean): Integer;
var
  S: TSdOtaCodeInsightServices;
begin
  Result := -1;
  Own := False;
  if not ListUp then Exit;
  S := CIServices;
  Own := S.OwnListShown;
  if Own then
  begin
    if CompletionPopup.TypedText <> '' then Result := CompletionPopup.ExactRow
    else Result := CompletionPopup.ItemIndex;
  end
  else if S.FCustomDraw <> nil then Result := -1
  else if S.FTyped <> '' then Result := S.FExact
  else Result := CompletionPopup.ItemIndex;
end;

{ as Delphi 7's: the chosen row's text (ChosenRow) - of D7 Studio's own list the typed text's
  row only, as Delphi 7's own list gives none for a part of a name (measured) }
function TSdCIViewer.GetSelectedString: string;
var
  I: Integer;
  Own: Boolean;
  P: TEditorPage;
begin
  Result := '';
  I := ChosenRow(Own);
  if I < 0 then Exit;
  if Own then
  begin
    P := OtaPageOfEditor(CompletionPopup.Editor);
    if P <> nil then Result := EditorToAnsi(CompletionPopup.RowName(I), P.Encoding)
    else Result := CompletionPopup.RowName(I);
    Exit;
  end;
  try
    Result := CIServices.FSymbols.GetSymbolText(I);
  except
    OtaCaught('IOTACodeInsightSymbolList.GetSymbolText', False);
  end;
end;

function TSdCIViewer.GetCloseKey: Char;
begin
  if (CIServices <> nil) and (CIServices.FPage <> nil) then Result := CIServices.FCloseKey else Result := #0;
end;

{ as Delphi 7's: a row chosen (ChosenRow) }
function TSdCIViewer.GetIsValidSelection: Boolean;
var
  Own: Boolean;
begin
  Result := ChosenRow(Own) >= 0;
end;
{ ---------------------------------------------------------------- TSdHtmlCIManager }

constructor TSdHtmlCIManager.Create;
begin
  inherited Create;
  FEnabled := True;
end;

function TSdHtmlCIManager.GetName: string;
begin
  Result := 'Markup Language';
end;

function TSdHtmlCIManager.GetIDString: string;
begin
  Result := 'Borland.CodeInsight.HTML';
end;

function TSdHtmlCIManager.GetEnabled: Boolean;
begin
  Result := FEnabled;
end;

procedure TSdHtmlCIManager.SetEnabled(Value: Boolean);
begin
  FEnabled := Value;
end;

function TSdHtmlCIManager.HandlesFile(const AFileName: string): Boolean;
var
  E: string;
begin
  E := LowerCase(ExtractFileExt(AFileName));
  Result := (E = '.htm') or (E = '.html') or (E = '.xml') or (E = '.xsl');
end;
{ ---------------------------------------------------------------- TSdRemovedCIManager }

function TSdRemovedCIManager.GetName: string;
begin
  Result := '';
end;

function TSdRemovedCIManager.GetIDString: string;
begin
  Result := '';
end;

function TSdRemovedCIManager.GetEnabled: Boolean;
begin
  Result := False;
end;

procedure TSdRemovedCIManager.SetEnabled(Value: Boolean);
begin
end;

function TSdRemovedCIManager.EditorTokenValidChars(PreValidating: Boolean): TSysCharSet;
begin
  Result := [];
end;

procedure TSdRemovedCIManager.AllowCodeInsight(var Allow: Boolean; const Key: Char);
begin
  Allow := False;
end;

function TSdRemovedCIManager.PreValidateCodeInsight(const Str: string): Boolean;
begin
  Result := False;
end;

function TSdRemovedCIManager.IsViewerBrowsable(Index: Integer): Boolean;
begin
  Result := False;
end;

function TSdRemovedCIManager.GetMultiSelect: Boolean;
begin
  Result := False;
end;

procedure TSdRemovedCIManager.GetSymbolList(out SymbolList: IOTACodeInsightSymbolList);
begin
  SymbolList := nil;
end;

procedure TSdRemovedCIManager.OnEditorKey(Key: Char; var CloseViewer: Boolean; var Accept: Boolean);
begin
  CloseViewer := True;
  Accept := False;
end;

function TSdRemovedCIManager.HandlesFile(const AFileName: string): Boolean;
begin
  Result := False;
end;

function TSdRemovedCIManager.GetLongestItem: string;
begin
  Result := '';
end;

procedure TSdRemovedCIManager.GetParameterList(out ParameterList: IOTACodeInsightParameterList);
begin
  ParameterList := nil;
end;

procedure TSdRemovedCIManager.GetCodeInsightType(AChar: Char; AElement: Integer;
  out CodeInsightType: TOTACodeInsightType; out InvokeType: TOTAInvokeType);
begin
  CodeInsightType := citNone;
  InvokeType := itManual;
end;

function TSdRemovedCIManager.InvokeCodeCompletion(HowInvoked: TOTAInvokeType; var Str: string): Boolean;
begin
  Result := False;
end;

function TSdRemovedCIManager.InvokeParameterCodeInsight(HowInvoked: TOTAInvokeType;
  var SelectedIndex: Integer): Boolean;
begin
  Result := False;
end;

procedure TSdRemovedCIManager.ParameterCodeInsightAnchorPos(var EdPos: TOTAEditPos);
begin
end;

function TSdRemovedCIManager.ParameterCodeInsightParamIndex(EdPos: TOTAEditPos): Integer;
begin
  Result := -1;
end;

function TSdRemovedCIManager.GetHintText(HintLine, HintCol: Integer): string;
begin
  Result := '';
end;

function TSdRemovedCIManager.GotoDefinition(out AFileName: string; out ALineNum: Integer; Index: Integer): Boolean;
begin
  AFileName := '';
  ALineNum := 0;
  Result := True;
end;

procedure TSdRemovedCIManager.Done(Accepted: Boolean; out DisplayParams: Boolean);
begin
  DisplayParams := False;
end;

{ ---------------------------------------------------------------- TSdPascalCIManager }

constructor TSdPascalCIManager.Create;
begin
  inherited Create;
  FEnabled := True;
end;

{ the page of the edit view code insight works on (GetEditView) }
function TSdPascalCIManager.ViewPage: TEditorPage;
var
  V: IOTAEditView;
  F: ISdOtaFile;
begin
  Result := nil;
  if (CIServices = nil) or (OtaHost = nil) then Exit;
  CIServices.GetEditView(V);
  if Supports(V, ISdOtaFile, F) then Result := OtaHost.FindPage(F.OtaFileName);
end;

function TSdPascalCIManager.HandlesPage(Page: TEditorPage): Boolean;
begin
  Result := (Page <> nil) and Page.IsPascal;
end;

function TSdPascalCIManager.GetName: string;
begin
  Result := 'Pascal';
end;

function TSdPascalCIManager.GetIDString: string;
begin
  Result := PascalID;
end;

function TSdPascalCIManager.GetEnabled: Boolean;
begin
  Result := FEnabled;
end;

procedure TSdPascalCIManager.SetEnabled(Value: Boolean);
begin
  FEnabled := Value;
end;

{ Delphi's: an identifier's characters; prevalidating also '.', ')' and ']' }
function TSdPascalCIManager.EditorTokenValidChars(PreValidating: Boolean): TSysCharSet;
begin
  Result := IdentChars;
  if PreValidating then Result := Result + ['.', ')', ']'];
end;

{ D7 Studio's engine needs no compiler: allowed as asked }
procedure TSdPascalCIManager.AllowCodeInsight(var Allow: Boolean; const Key: Char);
begin
end;

{ Delphi's: two characters at least, not ending in '..', not a number unless it ends in '].' }
function TSdPascalCIManager.PreValidateCodeInsight(const Str: string): Boolean;
var
  L: Integer;
begin
  L := Length(Str);
  Result := (L >= 2) and (Copy(Str, L - 1, 2) <> '..') and
    (not (Str[1] in ['0'..'9']) or (Copy(Str, L - 1, 2) = '].'));
end;

{ Delphi's: a row browses while Ctrl is held }
function TSdPascalCIManager.IsViewerBrowsable(Index: Integer): Boolean;
begin
  Result := GetKeyState(VK_CONTROL) < 0;
end;

function TSdPascalCIManager.GetMultiSelect: Boolean;
begin
  Result := False;
end;

procedure TSdPascalCIManager.GetSymbolList(out SymbolList: IOTACodeInsightSymbolList);
begin
  SymbolList := FSymbols;
end;

{ Delphi's: a symbol or Enter accepts, Esc closes }
procedure TSdPascalCIManager.OnEditorKey(Key: Char; var CloseViewer: Boolean; var Accept: Boolean);
begin
  Accept := Key in [' ', '(', ')', '*', '+', ',', '-', '.', '/', ':', ';', '[', ']', '{', '}', #13];
  CloseViewer := Accept or (Key = #27);
end;

{ the Pascal files of Editor Options | Source Options; an open page: its editor's language }
function TSdPascalCIManager.HandlesFile(const AFileName: string): Boolean;
var
  P: TEditorPage;
  I: Integer;
begin
  P := nil;
  if OtaHost <> nil then P := OtaHost.FindPage(AFileName);
  if P <> nil then
  begin
    Result := P.IsPascal;
    Exit;
  end;
  I := EditorFileTypeIndex(AFileName);
  Result := (I >= 0) and SameText(EditorOptions.FileTypes[I].ID, 'Borland.EditOptions.Pascal');
end;

function TSdPascalCIManager.GetLongestItem: string;
begin
  Result := 'constructor ';
end;

procedure TSdPascalCIManager.GetParameterList(out ParameterList: IOTACodeInsightParameterList);
begin
  ParameterList := FParams;
end;

{ Delphi's TPascalKibitzManager.GetCodeInsightType: ToolsAPI's example }
procedure TSdPascalCIManager.GetCodeInsightType(AChar: Char; AElement: Integer;
  out CodeInsightType: TOTACodeInsightType; out InvokeType: TOTAInvokeType);
begin
  InvokeType := itManual;
  if not ((AElement = atString) and (AChar <> #1)) and not (AElement = atComment) then
  begin
    case AChar of
      #0: CodeInsightType := citCodeInsight;
      #1: CodeInsightType := citParameterCodeInsight;
      #2: CodeInsightType := citBrowseCodeInsight;
      #3: CodeInsightType := citHintCodeInsight;
      '.':
        begin
          CodeInsightType := citCodeInsight;
          InvokeType := itTimer;
        end;
      '(':
        begin
          CodeInsightType := citParameterCodeInsight;
          InvokeType := itTimer;
        end;
    end;
  end
  else
    CodeInsightType := citNone;
end;

function TSdPascalCIManager.InvokeCodeCompletion(HowInvoked: TOTAInvokeType; var Str: string): Boolean;
var
  P: TEditorPage;
  List: TCIItemList;
  Start: Integer;
begin
  Result := False;
  FSymbols := nil;
  FSymbolObj := nil;
  P := ViewPage;
  if (P = nil) or (IDE = nil) or (IDE.CodeInsight = nil) then Exit;
  List := TCIItemList.Create;
  try
    if IDE.CodeInsight.GetCompletions(P.FileName, P.GetSource, P.Editor.CaretPos, List, Start) and
      (List.Count > 0) then
    begin
      Str := EditorToAnsi(P.Editor.GetRange(Start, P.Editor.CaretPos), P.Encoding);
      FSymbolObj := TSdCISymbolList.Create(List, P.Encoding);
      FSymbols := FSymbolObj;
      List := nil;
      Result := True;
    end;
  finally
    List.Free;
  end;
end;

function TSdPascalCIManager.InvokeParameterCodeInsight(HowInvoked: TOTAInvokeType;
  var SelectedIndex: Integer): Boolean;
var
  P: TEditorPage;
  Hints: TCIParamHintArray;
  Active: Integer;
begin
  Result := False;
  FParams := nil;
  P := ViewPage;
  if (P = nil) or (IDE = nil) or (IDE.CodeInsight = nil) then Exit;
  if IDE.CodeInsight.GetParamHints(P.FileName, P.GetSource, P.Editor.CaretPos, Hints, Active) and
    (Length(Hints) > 0) then
  begin
    FParams := TSdCIParamList.Create(Hints, P.Encoding);
    SelectedIndex := Active;
    Result := True;
  end;
end;

procedure TSdPascalCIManager.ParameterCodeInsightAnchorPos(var EdPos: TOTAEditPos);
begin
end;

{ asked again at each move: D7 Studio's engine is quick }
function TSdPascalCIManager.ParameterCodeInsightParamIndex(EdPos: TOTAEditPos): Integer;
begin
  Result := -1;
end;

function TSdPascalCIManager.GetHintText(HintLine, HintCol: Integer): string;
var
  P: TEditorPage;
  H: string;
begin
  Result := '';
  P := ViewPage;
  if (P = nil) or (IDE = nil) or (IDE.CodeInsight = nil) then Exit;
  if IDE.CodeInsight.GetHint(P.FileName, P.GetSource, EditPosToOffset(P.Editor, OtaEditPos(HintLine, HintCol)), H) then
    Result := EditorToAnsi(H, P.Encoding);
end;

{ the declaration of the identifier at the caret (Index -1), else of the list's row Index }
function TSdPascalCIManager.GotoDefinition(out AFileName: string; out ALineNum: Integer; Index: Integer): Boolean;
var
  P: TEditorPage;
  Item: TCIItem;
begin
  Result := False;
  AFileName := '';
  ALineNum := 0;
  P := ViewPage;
  if P = nil then Exit;
  if Index >= 0 then
  begin
    if (FSymbols = nil) or (FSymbolObj = nil) or (FSymbolObj.Item(Index) = nil) then Exit;
    Item := FSymbolObj.Item(Index)^;
  end
  else if (IDE = nil) or (IDE.CodeInsight = nil) or
    not IDE.CodeInsight.FindDeclaration(P.FileName, P.GetSource, P.Editor.CaretPos, Item) then
    Exit;
  if Item.Line <= 0 then Exit;
  if Item.FileName = '' then Item.FileName := P.FileName;
  AFileName := Item.FileName;
  ALineNum := Item.Line;
  Result := True;
end;

{ Accepted: the viewer's choice in place of the token at the caret }
procedure TSdPascalCIManager.Done(Accepted: Boolean; out DisplayParams: Boolean);
var
  V: IOTACodeInsightViewer;
begin
  DisplayParams := False;
  if not Accepted or (CIServices = nil) then Exit;
  CIServices.GetViewer(V);
  if (V <> nil) and (V.GetSelectedString <> '') then CIServices.InsertText(V.GetSelectedString, True);
end;

{ ---------------------------------------------------------------- TSdCISymbolList }

function CompareByName(A, B: Pointer): Integer;
begin
  Result := AnsiCompareText(PCIItem(A)^.Name, PCIItem(B)^.Name);
  if Result = 0 then Result := Ord(PCIItem(A)^.Kind) - Ord(PCIItem(B)^.Kind);
end;

constructor TSdCISymbolList.Create(AItems: TCIItemList; const AEncoding: TSdEncoding);
var
  I: Integer;
begin
  inherited Create;
  FItems := AItems;
  FEncoding := AEncoding;
  FByScope := TList.Create;
  FByName := TList.Create;
  FShown := TList.Create;
  for I := 0 to FItems.Count - 1 do
  begin
    FByScope.Add(FItems[I]);
    FByName.Add(FItems[I]);
  end;
  FByName.Sort(CompareByName);
  FSort := soAlpha;
  Refilter;
end;

destructor TSdCISymbolList.Destroy;
begin
  FShown.Free;
  FByName.Free;
  FByScope.Free;
  FItems.Free;
  inherited;
end;

{ the popup's rule: the names that start with the filter, in either case }
procedure TSdCISymbolList.Refilter;
var
  Src: TList;
  I, L: Integer;
begin
  FShown.Clear;
  if FSort = soAlpha then Src := FByName else Src := FByScope;
  L := Length(FFilter);
  for I := 0 to Src.Count - 1 do
    if (L = 0) or (StrLIComp(PChar(PCIItem(Src[I])^.Name), PChar(FFilter), L) = 0) then FShown.Add(Src[I]);
end;

function TSdCISymbolList.Item(I: Integer): PCIItem;
begin
  if (I >= 0) and (I < FShown.Count) then Result := PCIItem(FShown[I]) else Result := nil;
end;

function TSdCISymbolList.Txt(const S: string): string;
begin
  Result := EditorToAnsi(S, FEncoding);
end;

procedure TSdCISymbolList.Clear;
begin
  FShown.Clear;
  FByName.Clear;
  FByScope.Clear;
  FItems.Clear;
end;

function TSdCISymbolList.GetCount: Integer;
begin
  Result := FShown.Count;
end;

function TSdCISymbolList.GetSymbolIsReadWrite(I: Integer): Boolean;
begin
  Result := (Item(I) <> nil) and (Item(I)^.Kind in [ckProperty, ckVar, ckField, ckParam, ckLocalVar]);
end;

function TSdCISymbolList.GetSymbolIsAbstract(I: Integer): Boolean;
begin
  Result := False;
end;

function TSdCISymbolList.GetViewerSymbolFlags(I: Integer): TOTAViewerSymbolFlags;
begin
  Result := vsfUnknown;
  if Item(I) = nil then Exit;
  case Item(I)^.Kind of
    ckProcedure: Result := vsfProcedure;
    ckFunction: Result := vsfFunction;
    ckConstructor: Result := vsfConstructor;
    ckDestructor: Result := vsfDestructor;
    ckProperty: Result := vsfProperty;
    ckVar, ckField, ckParam, ckLocalVar: Result := vsfVariable;
    ckConst, ckEnumValue, ckResourceString: Result := vsfConstant;
    ckType, ckClass, ckRecord, ckEnum: Result := vsfType;
    ckInterface: Result := vsfInterface;
    ckUnit: Result := vsfUnit;
    ckLabel: Result := vsfLabel;
  end;
end;

function TSdCISymbolList.GetViewerVisibilityFlags(I: Integer): TOTAViewerVisibilityFlags;
begin
  Result := vvfPublic;
  if Item(I) = nil then Exit;
  case Item(I)^.Visibility of
    cvPrivate: Result := vvfPrivate;
    cvProtected: Result := vvfProtected;
    cvPublished: Result := vvfPublished;
  end;
end;

function TSdCISymbolList.GetProcDispatchFlags(I: Integer): TOTAProcDispatchFlags;
begin
  Result := pdfNone;
end;

procedure TSdCISymbolList.SetSortOrder(const Value: TOTASortOrder);
begin
  if Value = FSort then Exit;
  FSort := Value;
  Refilter;
end;

function TSdCISymbolList.GetSortOrder: TOTASortOrder;
begin
  Result := FSort;
end;

{ the first row that starts with the text }
function TSdCISymbolList.FindIdent(const AnIdent: string): Integer;
var
  I, L: Integer;
begin
  Result := -1;
  L := Length(AnIdent);
  for I := 0 to FShown.Count - 1 do
    if StrLIComp(PChar(PCIItem(FShown[I])^.Name), PChar(AnIdent), L) = 0 then
    begin
      Result := I;
      Exit;
    end;
end;

function TSdCISymbolList.FindSymIndex(const Ident: string; var Index: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FShown.Count - 1 do
    if SameText(Txt(PCIItem(FShown[I])^.Name), Ident) then
    begin
      Index := I;
      Result := True;
      Exit;
    end;
end;

procedure TSdCISymbolList.SetFilter(const FilterText: string);
begin
  FFilter := FilterText;
  Refilter;
end;

function TSdCISymbolList.GetSymbolText(Index: Integer): string;
begin
  if Item(Index) = nil then Result := '' else Result := Txt(Item(Index)^.Name);
end;

{ as D7 Studio's own list shows it: a routine's parameters and result, else ': ' and the type }
function TSdCISymbolList.GetSymbolTypeText(Index: Integer): string;
var
  It: PCIItem;
begin
  Result := '';
  It := Item(Index);
  if It = nil then Exit;
  if It^.Kind in [ckProcedure, ckFunction, ckConstructor, ckDestructor] then
  begin
    if It^.Params <> '' then Result := '(' + It^.Params + ')';
    if It^.TypeName <> '' then Result := Result + ': ' + It^.TypeName;
  end
  else if It^.TypeName <> '' then
    Result := ': ' + It^.TypeName;
  Result := Txt(Result);
end;

function TSdCISymbolList.GetSymbolClassText(I: Integer): string;
begin
  if Item(I) = nil then Result := '' else Result := KindWord(Item(I)^.Kind);
end;

{ ---------------------------------------------------------------- TSdCIParamList }

constructor TSdCIParamList.Create(const AHints: TCIParamHintArray; const AEncoding: TSdEncoding);
begin
  inherited Create;
  FHints := AHints;
  FEncoding := AEncoding;
end;

procedure TSdCIParamList.GetParameterQuery(ProcIndex: Integer; out ParamQuery: IOTACodeInsightParamQuery);
begin
  if (ProcIndex >= 0) and (ProcIndex <= High(FHints)) then
    ParamQuery := TSdCIParamQuery.Create(FHints[ProcIndex], FEncoding)
  else
    ParamQuery := nil;
end;

function TSdCIParamList.GetParamDelimiter: Char;
begin
  Result := ';';
end;

function TSdCIParamList.GetProcedureCount: Integer;
begin
  Result := Length(FHints);
end;

function TSdCIParamList.GetProcedureParamsText(I: Integer): string;
var
  K: Integer;
begin
  Result := '';
  if (I < 0) or (I > High(FHints)) then Exit;
  for K := 0 to High(FHints[I].Params) do
  begin
    if K > 0 then Result := Result + sLineBreak;
    Result := Result + EditorToAnsi(FHints[I].Params[K], FEncoding);
  end;
end;

{ ---------------------------------------------------------------- TSdCIParamQuery }

constructor TSdCIParamQuery.Create(const Hint: TCIParamHint; const AEncoding: TSdEncoding);
var
  I, P: Integer;
  S: string;
begin
  inherited Create;
  FParams := TStringList.Create;
  for I := 0 to High(Hint.Params) do FParams.Add(Trim(EditorToAnsi(Hint.Params[I], AEncoding)));
  { a function's result: after the parameters' closing parenthesis (or the name) and a colon }
  S := Trim(EditorToAnsi(Hint.Signature, AEncoding));
  FRetVal := '';
  if SameText(Copy(S, 1, 8), 'function') then
  begin
    P := LastDelimiter(')', S);
    S := Copy(S, P + 1, MaxInt);
    P := Pos(':', S);
    if P > 0 then FRetVal := Trim(StringReplace(Copy(S, P + 1, MaxInt), ';', '', [rfReplaceAll]));
  end;
end;

destructor TSdCIParamQuery.Destroy;
begin
  FParams.Free;
  inherited;
end;

{ a parameter's part - 0 its kind (const, var, out), 1 its names, 2 its type, 3 its default }
function TSdCIParamQuery.Part(Index, Which: Integer): string;
var
  S, W: string;
  P: Integer;
begin
  Result := '';
  if (Index < 0) or (Index >= FParams.Count) then Exit;
  S := FParams[Index];
  P := Pos(' ', S);
  W := LowerCase(Copy(S, 1, P - 1));
  if (P > 0) and ((W = 'const') or (W = 'var') or (W = 'out')) then
  begin
    if Which = 0 then Result := W;
    S := Trim(Copy(S, P + 1, MaxInt));
  end;
  if Which = 0 then Exit;
  P := Pos('=', S);
  if P > 0 then
  begin
    if Which = 3 then Result := Trim(Copy(S, P + 1, MaxInt));
    S := Trim(Copy(S, 1, P - 1));
  end;
  if Which = 3 then Exit;
  P := Pos(':', S);
  if P = 0 then
  begin
    if Which = 1 then Result := Trim(S);
    Exit;
  end;
  if Which = 1 then Result := Trim(Copy(S, 1, P - 1))
  else Result := Trim(Copy(S, P + 1, MaxInt));
end;

function TSdCIParamQuery.GetQueryParamCount: Integer;
begin
  Result := FParams.Count;
end;

function TSdCIParamQuery.GetQueryRetVal: string;
begin
  Result := FRetVal;
end;

function TSdCIParamQuery.GetQueryParamSymText(Index: Integer): string;
begin
  Result := Part(Index, 1);
end;

function TSdCIParamQuery.GetQueryParamTypeText(Index: Integer): string;
begin
  Result := Part(Index, 2);
end;

function TSdCIParamQuery.GetQueryParamHasDefaultVal(Index: Integer): Boolean;
begin
  Result := Part(Index, 3) <> '';
end;

function TSdCIParamQuery.GetQueryParamInvokeTypeText(Index: Integer): string;
begin
  Result := Part(Index, 0);
end;

end.
