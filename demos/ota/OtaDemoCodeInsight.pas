{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoCodeInsight;

{ The OTA demo's code insight (IOTACodeInsightServices): a manager for the files *.otademo whose
  words are colour names. Every call it gets is written into CICalls as "<method>(arguments) ->
  result" - the self-test (OtaDemoTestCodeInsight) reads it, OTA Demo | Code Insight | Call log
  shows it.

  * The list (InvokeCodeCompletion): Red, Green, Blue, Black, White, Navy - constants (class text
    'const', type ': TColor') - and Mix, an abstract function ('(A, B: TColor): TColor'); filtered
    by the start of their names, sorted by name or in this order (soScope). Each row is drawn by
    the manager (INTACustomDrawCodeInsightViewer): a square of its colour, then the default
    drawing. ' ', ';', ',', '.', '(' and Enter accept, Esc closes; Done puts the symbol chosen
    and the key that accepted it in place of the word (InsertText) and asks for the parameters
    after Mix.
  * The parameters (inside "Mix("): Mix's two overloads, delimiter ','; the hint is anchored at the
    '('; the parameter is the number of commas between the '(' and the caret.
  * The hint of a word: "OTA demo hint: <word> at <line>:<col>". Go to the definition of a word:
    the line "<word>:" of the file (False when there is none).
  * DemoMultiSelect: the list lets several rows be chosen (Space). }

interface

uses
  Windows, SysUtils, Classes, Graphics, ToolsAPI;

const
  DemoCIExt = '.otademo';
  DemoCIID = 'OtaDemo.CodeInsight';

type
  TDemoSymbol = record
    Name, ClassText, TypeText: string;
    Flag: TOTAViewerSymbolFlags;
    Abstr: Boolean;
    Color: TColor;
  end;

  TDemoSymbolList = class(TInterfacedObject, IOTACodeInsightSymbolList)
  private
    FShown: TList;                   // indexes into DemoSymbols, filtered, in the sort order
    FSort: TOTASortOrder;
    FFilter: string;
    FCleared: Boolean;
    procedure Refilter;
    function Sym(I: Integer): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function SymbolColor(I: Integer): TColor;
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

  TDemoParamList = class(TInterfacedObject, IOTACodeInsightParameterList)
  public
    procedure GetParameterQuery(ProcIndex: Integer; out ParamQuery: IOTACodeInsightParamQuery);
    function GetParamDelimiter: Char;
    function GetProcedureCount: Integer;
    function GetProcedureParamsText(I: Integer): string;
  end;

  TDemoCIManager = class(TInterfacedObject, IOTACodeInsightManager, INTACustomDrawCodeInsightViewer)
  private
    FEnabled: Boolean;
    FSymbols: IOTACodeInsightSymbolList;
    FSymbolObj: TDemoSymbolList;
    FParams: IOTACodeInsightParameterList;
  public
    ID: string;                      // GetIDString (DemoCIID; the self-test makes a second one)
    constructor Create;
    { IOTACodeInsightManager }
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
    { INTACustomDrawCodeInsightViewer }
    procedure DrawLine(Index: Integer; Canvas: TCanvas; var Rect: TRect; DrawingHintText: Boolean;
      DoDraw: Boolean; var DefaultDraw: Boolean);
  end;

var
  CICalls: TStringList;              // the calls the demo's manager and lists got
  DemoMultiSelect: Boolean;          // the list lets several rows be chosen
  DrawLineCalls: Integer;            // DrawLine (not in the log: it comes with every paint)

procedure CICall(const S: string);
{ the first line of the log that starts with Text, from line From on (-1: none) }
function CICallIndex(const Text: string; From: Integer = 0): Integer;
function CIServices: IOTACodeInsightServices;
function InvokeName(How: TOTAInvokeType): string;
function KeyName(Key: Char): string;

implementation

const
  BoolText: array[Boolean] of string = ('False', 'True');
  SymbolCount = 7;

var
  DemoSymbols: array[0..SymbolCount - 1] of TDemoSymbol;

procedure CICall(const S: string);
begin
  if CICalls = nil then Exit;
  CICalls.Add(S);
  if CICalls.Count > 5000 then CICalls.Delete(0);
end;

function CICallIndex(const Text: string; From: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  if CICalls = nil then Exit;
  if From < 0 then From := 0;
  for I := From to CICalls.Count - 1 do
    if Copy(CICalls[I], 1, Length(Text)) = Text then
    begin
      Result := I;
      Exit;
    end;
end;

function CIServices: IOTACodeInsightServices;
begin
  Result := BorlandIDEServices as IOTACodeInsightServices;
end;

function InvokeName(How: TOTAInvokeType): string;
begin
  case How of
    itAuto: Result := 'itAuto';
    itManual: Result := 'itManual';
  else
    Result := 'itTimer';
  end;
end;

function KeyName(Key: Char): string;
begin
  if Key < ' ' then Result := '#' + IntToStr(Ord(Key)) else Result := Key;
end;

procedure Define(I: Integer; const AName, AClass, AType: string; AFlag: TOTAViewerSymbolFlags; AAbstr: Boolean;
  AColor: TColor);
begin
  with DemoSymbols[I] do
  begin
    Name := AName;
    ClassText := AClass;
    TypeText := AType;
    Flag := AFlag;
    Abstr := AAbstr;
    Color := AColor;
  end;
end;

{ ---------------------------------------------------------------- the editor's text }

{ the text of the view's buffer and its lines }
function ViewLines(const V: IOTAEditView): TStringList;
var
  R: IOTAEditReader;
  Buf: array[0..4095] of Char;
  N, P: Integer;
  S, Part: string;
begin
  Result := TStringList.Create;
  if (V = nil) or (V.Buffer = nil) then Exit;
  R := V.Buffer.CreateReader;
  S := '';
  P := 0;
  repeat
    N := R.GetText(P, Buf, SizeOf(Buf));
    SetString(Part, Buf, N);
    S := S + Part;
    Inc(P, N);
  until N < SizeOf(Buf);
  Result.Text := S;
end;

function ViewLine(const V: IOTAEditView; Line: Integer): string;
var
  L: TStringList;
begin
  L := ViewLines(V);
  try
    if (Line >= 1) and (Line <= L.Count) then Result := L[Line - 1] else Result := '';
  finally
    L.Free;
  end;
end;

function EditView: IOTAEditView;
begin
  CIServices.GetEditView(Result);
end;

{ the word of a line around a column (1-based) }
function WordAt(const S: string; Col: Integer): string;
var
  A, B: Integer;
begin
  A := Col;
  if A > Length(S) + 1 then A := Length(S) + 1;
  while (A > 1) and (S[A - 1] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Dec(A);
  B := A;
  while (B <= Length(S)) and (S[B] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) do Inc(B);
  Result := Copy(S, A, B - A);
end;

{ the '(' of "Mix(" before a column of a line that no ')' closes (0: none) and the commas from it
  to the column }
function OpenMix(const S: string; Col: Integer; out Commas: Integer): Integer;
var
  I, Depth: Integer;
begin
  Result := 0;
  Commas := 0;
  Depth := 0;
  if Col > Length(S) + 1 then Col := Length(S) + 1;
  for I := Col - 1 downto 1 do
    case S[I] of
      ')': Inc(Depth);
      '(':
        if Depth > 0 then Dec(Depth)
        else
        begin
          if SameText(WordAt(S, I), 'Mix') then Result := I;
          Exit;
        end;
      ',': if Depth = 0 then Inc(Commas);
    end;
end;

{ ---------------------------------------------------------------- TDemoSymbolList }

constructor TDemoSymbolList.Create;
begin
  inherited Create;
  FShown := TList.Create;
  FSort := soScope;
  Refilter;
end;

destructor TDemoSymbolList.Destroy;
begin
  FShown.Free;
  inherited;
end;

function CompareNames(A, B: Pointer): Integer;
begin
  Result := CompareText(DemoSymbols[Integer(A)].Name, DemoSymbols[Integer(B)].Name);
end;

procedure TDemoSymbolList.Refilter;
var
  I: Integer;
begin
  FShown.Clear;
  if FCleared then Exit;
  for I := 0 to SymbolCount - 1 do
    if SameText(Copy(DemoSymbols[I].Name, 1, Length(FFilter)), FFilter) then FShown.Add(Pointer(I));
  if FSort = soAlpha then FShown.Sort(CompareNames);
end;

function TDemoSymbolList.Sym(I: Integer): Integer;
begin
  if (I >= 0) and (I < FShown.Count) then Result := Integer(FShown[I]) else Result := -1;
end;

function TDemoSymbolList.SymbolColor(I: Integer): TColor;
begin
  if Sym(I) < 0 then Result := clWindow else Result := DemoSymbols[Sym(I)].Color;
end;

procedure TDemoSymbolList.Clear;
begin
  CICall('SymbolList.Clear');
  FCleared := True;
  FShown.Clear;
end;

function TDemoSymbolList.GetCount: Integer;
begin
  Result := FShown.Count;
  CICall('SymbolList.GetCount -> ' + IntToStr(Result));
end;

function TDemoSymbolList.GetSymbolIsReadWrite(I: Integer): Boolean;
begin
  Result := False;
end;

function TDemoSymbolList.GetSymbolIsAbstract(I: Integer): Boolean;
begin
  Result := (Sym(I) >= 0) and DemoSymbols[Sym(I)].Abstr;
end;

function TDemoSymbolList.GetViewerSymbolFlags(I: Integer): TOTAViewerSymbolFlags;
begin
  if Sym(I) < 0 then Result := vsfUnknown else Result := DemoSymbols[Sym(I)].Flag;
end;

function TDemoSymbolList.GetViewerVisibilityFlags(I: Integer): TOTAViewerVisibilityFlags;
begin
  Result := vvfPublic;
end;

function TDemoSymbolList.GetProcDispatchFlags(I: Integer): TOTAProcDispatchFlags;
begin
  Result := pdfNone;
end;

procedure TDemoSymbolList.SetSortOrder(const Value: TOTASortOrder);
begin
  if Value = soAlpha then CICall('SymbolList.SetSortOrder(soAlpha)') else CICall('SymbolList.SetSortOrder(soScope)');
  FSort := Value;
  Refilter;
end;

function TDemoSymbolList.GetSortOrder: TOTASortOrder;
begin
  Result := FSort;
end;

function TDemoSymbolList.FindIdent(const AnIdent: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FShown.Count - 1 do
    if SameText(Copy(DemoSymbols[Sym(I)].Name, 1, Length(AnIdent)), AnIdent) then
    begin
      Result := I;
      Break;
    end;
  CICall('SymbolList.FindIdent(' + AnIdent + ') -> ' + IntToStr(Result));
end;

function TDemoSymbolList.FindSymIndex(const Ident: string; var Index: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FShown.Count - 1 do
    if SameText(DemoSymbols[Sym(I)].Name, Ident) then
    begin
      Index := I;
      Result := True;
      Break;
    end;
  CICall('SymbolList.FindSymIndex(' + Ident + ') -> ' + BoolText[Result]);
end;

procedure TDemoSymbolList.SetFilter(const FilterText: string);
begin
  CICall('SymbolList.SetFilter(' + FilterText + ')');
  FFilter := FilterText;
  Refilter;
end;

function TDemoSymbolList.GetSymbolText(Index: Integer): string;
begin
  if Sym(Index) < 0 then Result := '' else Result := DemoSymbols[Sym(Index)].Name;
end;

function TDemoSymbolList.GetSymbolTypeText(Index: Integer): string;
begin
  if Sym(Index) < 0 then Result := '' else Result := DemoSymbols[Sym(Index)].TypeText;
end;

function TDemoSymbolList.GetSymbolClassText(I: Integer): string;
begin
  if Sym(I) < 0 then Result := '' else Result := DemoSymbols[Sym(I)].ClassText;
end;

{ ---------------------------------------------------------------- TDemoParamList }

procedure TDemoParamList.GetParameterQuery(ProcIndex: Integer; out ParamQuery: IOTACodeInsightParamQuery);
begin
  CICall('ParamList.GetParameterQuery(' + IntToStr(ProcIndex) + ')');
  ParamQuery := nil;
end;

function TDemoParamList.GetParamDelimiter: Char;
begin
  Result := ',';
  CICall('ParamList.GetParamDelimiter');
end;

function TDemoParamList.GetProcedureCount: Integer;
begin
  Result := 2;
  CICall('ParamList.GetProcedureCount -> 2');
end;

function TDemoParamList.GetProcedureParamsText(I: Integer): string;
begin
  CICall('ParamList.GetProcedureParamsText(' + IntToStr(I) + ')');
  if I = 0 then Result := 'A: TColor' + sLineBreak + 'B: TColor'
  else Result := 'A: TColor' + sLineBreak + 'B: TColor' + sLineBreak + 'Weight: Integer';
end;

{ ---------------------------------------------------------------- TDemoCIManager }

constructor TDemoCIManager.Create;
begin
  inherited Create;
  FEnabled := True;
  ID := DemoCIID;
end;

function TDemoCIManager.GetName: string;
begin
  Result := 'OTA Demo words';
end;

function TDemoCIManager.GetIDString: string;
begin
  Result := ID;
end;

function TDemoCIManager.GetEnabled: Boolean;
begin
  Result := FEnabled;
  CICall('GetEnabled -> ' + BoolText[Result]);
end;

procedure TDemoCIManager.SetEnabled(Value: Boolean);
begin
  CICall('SetEnabled(' + BoolText[Value] + ')');
  FEnabled := Value;
end;

function TDemoCIManager.EditorTokenValidChars(PreValidating: Boolean): TSysCharSet;
begin
  CICall('EditorTokenValidChars(' + BoolText[PreValidating] + ')');
  Result := ['A'..'Z', 'a'..'z', '0'..'9', '_'];
  if PreValidating then Result := Result + ['.'];
end;

procedure TDemoCIManager.AllowCodeInsight(var Allow: Boolean; const Key: Char);
begin
  CICall('AllowCodeInsight(' + KeyName(Key) + ')');
end;

function TDemoCIManager.PreValidateCodeInsight(const Str: string): Boolean;
begin
  Result := Length(Str) >= 1;
  CICall('PreValidateCodeInsight(' + Str + ') -> ' + BoolText[Result]);
end;

function TDemoCIManager.IsViewerBrowsable(Index: Integer): Boolean;
begin
  Result := True;
end;

function TDemoCIManager.GetMultiSelect: Boolean;
begin
  Result := DemoMultiSelect;
  CICall('GetMultiSelect -> ' + BoolText[Result]);
end;

procedure TDemoCIManager.GetSymbolList(out SymbolList: IOTACodeInsightSymbolList);
begin
  CICall('GetSymbolList');
  SymbolList := FSymbols;
end;

procedure TDemoCIManager.OnEditorKey(Key: Char; var CloseViewer: Boolean; var Accept: Boolean);
begin
  Accept := Key in [' ', ';', ',', '.', '(', #13];
  CloseViewer := Key = #27;
  CICall('OnEditorKey(' + KeyName(Key) + ') -> Close ' + BoolText[CloseViewer] + ', Accept ' + BoolText[Accept]);
end;

function TDemoCIManager.HandlesFile(const AFileName: string): Boolean;
begin
  Result := SameText(ExtractFileExt(AFileName), DemoCIExt);
  CICall('HandlesFile(' + ExtractFileName(AFileName) + ') -> ' + BoolText[Result]);
end;

function TDemoCIManager.GetLongestItem: string;
begin
  CICall('GetLongestItem');
  Result := 'function ';
end;

procedure TDemoCIManager.GetParameterList(out ParameterList: IOTACodeInsightParameterList);
begin
  CICall('GetParameterList');
  ParameterList := FParams;
end;

{ ToolsAPI's example }
procedure TDemoCIManager.GetCodeInsightType(AChar: Char; AElement: Integer; out CodeInsightType: TOTACodeInsightType;
  out InvokeType: TOTAInvokeType);
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
  CICall('GetCodeInsightType(' + KeyName(AChar) + ', ' + IntToStr(AElement) + ')');
end;

function TDemoCIManager.InvokeCodeCompletion(HowInvoked: TOTAInvokeType; var Str: string): Boolean;
begin
  CICall('InvokeCodeCompletion(' + InvokeName(HowInvoked) + ', ' + Str + ')');
  FSymbolObj := TDemoSymbolList.Create;
  FSymbols := FSymbolObj;
  Result := True;
end;

{ inside "Mix(": its two overloads, the parameter the commas before the caret say }
function TDemoCIManager.InvokeParameterCodeInsight(HowInvoked: TOTAInvokeType; var SelectedIndex: Integer): Boolean;
var
  V: IOTAEditView;
  Commas: Integer;
begin
  V := EditView;
  Result := (V <> nil) and (OpenMix(ViewLine(V, V.CursorPos.Line), V.CursorPos.Col, Commas) > 0);
  if Result then
  begin
    SelectedIndex := Commas;
    FParams := TDemoParamList.Create;
  end;
  CICall('InvokeParameterCodeInsight(' + InvokeName(HowInvoked) + ') -> ' + BoolText[Result]);
end;

{ the hint at the '(' of "Mix(" }
procedure TDemoCIManager.ParameterCodeInsightAnchorPos(var EdPos: TOTAEditPos);
var
  V: IOTAEditView;
  Commas, P: Integer;
begin
  CICall(Format('ParameterCodeInsightAnchorPos(%d:%d)', [EdPos.Line, EdPos.Col]));
  V := EditView;
  if V = nil then Exit;
  P := OpenMix(ViewLine(V, EdPos.Line), EdPos.Col, Commas);
  if P > 0 then EdPos.Col := P;
end;

function TDemoCIManager.ParameterCodeInsightParamIndex(EdPos: TOTAEditPos): Integer;
var
  V: IOTAEditView;
  Commas: Integer;
begin
  Result := -1;
  V := EditView;
  if (V <> nil) and (OpenMix(ViewLine(V, EdPos.Line), EdPos.Col, Commas) > 0) then Result := Commas;
  CICall(Format('ParameterCodeInsightParamIndex(%d:%d) -> %d', [EdPos.Line, EdPos.Col, Result]));
end;

function TDemoCIManager.GetHintText(HintLine, HintCol: Integer): string;
var
  W: string;
begin
  W := WordAt(ViewLine(EditView, HintLine), HintCol);
  if W = '' then Result := '' else Result := Format('OTA demo hint: %s at %d:%d', [W, HintLine, HintCol]);
  CICall(Format('GetHintText(%d, %d) -> %s', [HintLine, HintCol, Result]));
end;

{ the line "<word>:" of the file: the word at the cursor, or the list's row Index }
function TDemoCIManager.GotoDefinition(out AFileName: string; out ALineNum: Integer; Index: Integer): Boolean;
var
  V: IOTAEditView;
  L: TStringList;
  W: string;
  I: Integer;
begin
  Result := False;
  AFileName := '';
  ALineNum := 0;
  V := EditView;
  if V <> nil then
  begin
    if Index >= 0 then
    begin
      if FSymbols <> nil then W := FSymbols.GetSymbolText(Index);
    end
    else
      W := WordAt(ViewLine(V, V.CursorPos.Line), V.CursorPos.Col);
    L := ViewLines(V);
    try
      for I := 0 to L.Count - 1 do
        if (W <> '') and SameText(Copy(L[I], 1, Length(W) + 1), W + ':') then
        begin
          AFileName := V.Buffer.FileName;
          ALineNum := I + 1;
          Result := True;
          Break;
        end;
    finally
      L.Free;
    end;
  end;
  CICall(Format('GotoDefinition(%d) %s -> %s %d', [Index, W, BoolText[Result], ALineNum]));
end;

{ the symbol chosen and the key that accepted it in place of the word; the rows chosen of a
  multi-select list into the log; Mix asks for its parameters }
procedure TDemoCIManager.Done(Accepted: Boolean; out DisplayParams: Boolean);
var
  V: IOTACodeInsightViewer;
  S, Rows: string;
  K: Char;
  I: Integer;
begin
  DisplayParams := False;
  CIServices.GetViewer(V);
  Rows := '';
  if V <> nil then
    for I := 0 to V.ItemCount - 1 do
      if V.Selected[I] then Rows := Rows + ' ' + IntToStr(I);
  CICall('Done(' + BoolText[Accepted] + ') selected' + Rows);
  if not Accepted or (V = nil) then Exit;
  S := V.SelectedString;
  K := V.CloseKey;
  if S = '' then Exit;
  DisplayParams := SameText(S, 'Mix');
  if K <> #0 then S := S + K;
  CIServices.InsertText(S, True);
end;

procedure TDemoCIManager.DrawLine(Index: Integer; Canvas: TCanvas; var Rect: TRect; DrawingHintText: Boolean;
  DoDraw: Boolean; var DefaultDraw: Boolean);
begin
  Inc(DrawLineCalls);
  DefaultDraw := True;
  if not DoDraw or (FSymbolObj = nil) then Exit;
  Canvas.Brush.Color := FSymbolObj.SymbolColor(Index);
  Canvas.FillRect(Classes.Rect(Rect.Left + 1, Rect.Top + 3, Rect.Left + 11, Rect.Bottom - 3));
  Inc(Rect.Left, 14);
end;

initialization
  CICalls := TStringList.Create;
  Define(0, 'Red', 'const', ': TColor', vsfConstant, False, clRed);
  Define(1, 'Green', 'const', ': TColor', vsfConstant, False, clGreen);
  Define(2, 'Blue', 'const', ': TColor', vsfConstant, False, clBlue);
  Define(3, 'Black', 'const', ': TColor', vsfConstant, False, clBlack);
  Define(4, 'White', 'const', ': TColor', vsfConstant, False, clWhite);
  Define(5, 'Navy', 'const', ': TColor', vsfConstant, False, clNavy);
  Define(6, 'Mix', 'function', '(A, B: TColor): TColor', vsfFunction, True, clPurple);

finalization
  FreeAndNil(CICalls);
end.
