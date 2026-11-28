{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdMetrics;

{ D7 Studio - code metrics of a project: size and complexity, inheritance, coupling and cohesion,
  Halstead's measures and the maintainability index, per routine, class, unit and project.

  The parser (TUnitInfo: the classes, the routines and their bodies), the tokens (TRawToks: lines,
  decisions, Halstead's operators and operands) and the block structure (TPasBlocks: nesting) give
  what one unit shows; code insight gives what crosses units - the ancestors of a class
  (TCodeInsight.Browse) and the symbols the names of a text resolve to (TCodeInsight.NameUses) for
  coupling, response and cohesion. A metric that is not defined at a level shows there what its
  aggregation makes of the values below. No UI: the Metrics view and the tests use it alike. }

{$Q-,R-,B-,H+}

interface

uses
  SysUtils, Classes, Math, SdPasLex, SdPasParser, SdPasBlocks, SdCodeInsight;

type
  TMetricId = (miLOC, miCLOC, miCMT, miCC, miND, miNOP, miNOL, miNOA, miNOM, miNPR, miWMC,
    miDIT, miNOC, miCBO, miRFC, miLCOM, miCE, miCA,
    miHLEN, miHVOC, miHVOL, miHDIF, miHEFF, miMI);
  TMetricIds = set of TMetricId;
  TMetricLevel = (mlRoutine, mlClass, mlUnit, mlProject);
  TMetricLevels = set of TMetricLevel;
  TMetricAggr = (maSum, maAverage, maMaximum, maMinimum);

  { a metric's fixed facts }
  TMetricDef = record
    Id: string;                   // its key in the settings and its column's caption
    Name: string;
    Hint: string;                 // what it counts
    Levels: TMetricLevels;        // where it is defined (elsewhere: its aggregation)
    Aggr: TMetricAggr;            // the default aggregation
    Lower, Upper: Double;         // the default limits; 0 none
    Group: Integer;               // 0 size and complexity, 1 inheritance, 2 coupling and cohesion, 3 Halstead
    Decimals: Integer;            // how its values are written
  end;

  { what the user set for a metric }
  TMetricSetting = record
    On: Boolean;
    Aggr: TMetricAggr;
    Lower, Upper: Double;         // 0 none
  end;
  TMetricSettings = array[TMetricId] of TMetricSetting;

  { the options of a run beside the metrics' own }
  TMetricOptions = record
    FormFields: Boolean;          // a form's components count as its fields (NOA, LCOM, CBO)
    OutsideAncestors: Boolean;    // DIT counts the ancestors in units outside the project
  end;

  { a row of the results: the project, a unit, a class or a routine }
  TMetricNode = class
  public
    Level: TMetricLevel;
    Name: string;                 // 'TForm1.Button1Click', 'TForm1', 'Unit1', the project's name
    FileName: string;
    Line: Integer;                // 1-based; 0 none
    IsMethod: Boolean;            // a routine that is a method of a class
    Hint: string;                 // why it has no values (a unit that could not be read or parsed)
    Values: array[TMetricId] of Double;
    Has: TMetricIds;              // the values that are set
    Parent: TMetricNode;
    Children: TList;              // TMetricNode, owned
    Tag: Integer;                 // free for the view
    constructor Create(AParent: TMetricNode; ALevel: TMetricLevel; const AName: string);
    destructor Destroy; override;
    function Child(I: Integer): TMetricNode;
    function Count: Integer;
    procedure SetValue(Id: TMetricId; V: Double);
  end;

  { Done of Total units analysed, the next one UnitName; Cancel stops the run }
  TMetricProgress = procedure(Done, Total: Integer; const UnitName: string; var Cancel: Boolean) of object;

  TMetricsRun = class
  private
    FCI: TCodeInsight;
    FErrors: Integer;
    FLastError: string;
  public
    constructor Create(CI: TCodeInsight);
    { Files: the project file and its units (the editor's text where they have one); Title: the
      root's name. The result's root is the project (the caller frees it); nil when cancelled }
    function Run(Files: TStrings; const Title: string; const Settings: TMetricSettings;
      const Options: TMetricOptions; OnProgress: TMetricProgress): TMetricNode;
    property Errors: Integer read FErrors;          // the units whose analysis failed
    property LastError: string read FLastError;
  end;

const
  MetricAggrNames: array[TMetricAggr] of string = ('Sum', 'Average', 'Maximum', 'Minimum');
  MetricLevelNames: array[TMetricLevel] of string = ('Routine', 'Class', 'Unit', 'Project');
  MetricGroupNames: array[0..3] of string = ('Size and complexity', 'Inheritance',
    'Coupling and cohesion', 'Halstead');

  MetricDefs: array[TMetricId] of TMetricDef = (
    (Id: 'LOC'; Name: 'Lines of code';
     Hint: 'The lines from the heading to the end of the body; a class: its declaration and its methods; a unit: the file';
     Levels: [mlRoutine, mlClass, mlUnit]; Aggr: maSum; Lower: 0; Upper: 100; Group: 0; Decimals: 0),
    (Id: 'CLOC'; Name: 'Code lines';
     Hint: 'The lines of Lines of code that hold code, not only comments or white space';
     Levels: [mlRoutine, mlClass, mlUnit]; Aggr: maSum; Lower: 0; Upper: 0; Group: 0; Decimals: 0),
    (Id: 'CMT'; Name: 'Comment ratio';
     Hint: 'The lines with a comment for every 100 code lines';
     Levels: [mlRoutine, mlUnit]; Aggr: maAverage; Lower: 0; Upper: 0; Group: 0; Decimals: 1),
    (Id: 'CC'; Name: 'Cyclomatic complexity';
     Hint: '1 + the decisions of the body: if, while, for, repeat, each case arm, each and / or of a condition, each exception handler';
     Levels: [mlRoutine]; Aggr: maMaximum; Lower: 0; Upper: 10; Group: 0; Decimals: 0),
    (Id: 'ND'; Name: 'Nesting depth';
     Hint: 'The deepest nesting of begin, try, case, repeat and asm blocks inside the body';
     Levels: [mlRoutine]; Aggr: maMaximum; Lower: 0; Upper: 5; Group: 0; Decimals: 0),
    (Id: 'NOP'; Name: 'Parameters';
     Hint: 'The parameters of the routine';
     Levels: [mlRoutine]; Aggr: maMaximum; Lower: 0; Upper: 7; Group: 0; Decimals: 0),
    (Id: 'NOL'; Name: 'Local declarations';
     Hint: 'The local variables and constants of the routine';
     Levels: [mlRoutine]; Aggr: maMaximum; Lower: 0; Upper: 0; Group: 0; Decimals: 0),
    (Id: 'NOA'; Name: 'Attributes';
     Hint: 'The fields the class declares (not those it inherits)';
     Levels: [mlClass]; Aggr: maSum; Lower: 0; Upper: 20; Group: 0; Decimals: 0),
    (Id: 'NOM'; Name: 'Methods';
     Hint: 'The methods the class declares; a unit: its routines with a body';
     Levels: [mlClass, mlUnit]; Aggr: maSum; Lower: 0; Upper: 40; Group: 0; Decimals: 0),
    (Id: 'NPR'; Name: 'Properties';
     Hint: 'The properties the class declares';
     Levels: [mlClass]; Aggr: maSum; Lower: 0; Upper: 0; Group: 0; Decimals: 0),
    (Id: 'WMC'; Name: 'Weighted methods per class';
     Hint: 'The sum of the cyclomatic complexity of the class''s methods';
     Levels: [mlClass]; Aggr: maSum; Lower: 0; Upper: 50; Group: 0; Decimals: 0),
    (Id: 'DIT'; Name: 'Depth of inheritance';
     Hint: 'The ancestors of the class up to TObject';
     Levels: [mlClass]; Aggr: maMaximum; Lower: 0; Upper: 10; Group: 1; Decimals: 0),
    (Id: 'NOC'; Name: 'Child classes';
     Hint: 'The classes of the project that derive from the class directly';
     Levels: [mlClass]; Aggr: maSum; Lower: 0; Upper: 0; Group: 1; Decimals: 0),
    (Id: 'CBO'; Name: 'Coupling between objects';
     Hint: 'The other classes and interfaces the class uses or that use it (its ancestors not counted)';
     Levels: [mlClass]; Aggr: maMaximum; Lower: 0; Upper: 14; Group: 2; Decimals: 0),
    (Id: 'RFC'; Name: 'Response for a class';
     Hint: 'The methods of the class and the methods and routines they call';
     Levels: [mlClass]; Aggr: maMaximum; Lower: 0; Upper: 50; Group: 2; Decimals: 0),
    (Id: 'LCOM'; Name: 'Lack of cohesion of methods';
     Hint: 'The pairs of methods that use no field of the class in common, less the pairs that do (at least 0)';
     Levels: [mlClass]; Aggr: maMaximum; Lower: 0; Upper: 0; Group: 2; Decimals: 0),
    (Id: 'CE'; Name: 'Units used';
     Hint: 'The units in the uses clauses of the unit';
     Levels: [mlUnit]; Aggr: maMaximum; Lower: 0; Upper: 0; Group: 2; Decimals: 0),
    (Id: 'CA'; Name: 'Used by';
     Hint: 'The units of the project whose uses clauses name the unit';
     Levels: [mlUnit]; Aggr: maMaximum; Lower: 0; Upper: 0; Group: 2; Decimals: 0),
    (Id: 'HLEN'; Name: 'Halstead length';
     Hint: 'The operators and operands of the body';
     Levels: [mlRoutine]; Aggr: maSum; Lower: 0; Upper: 0; Group: 3; Decimals: 0),
    (Id: 'HVOC'; Name: 'Halstead vocabulary';
     Hint: 'The distinct operators and operands of the body';
     Levels: [mlRoutine]; Aggr: maMaximum; Lower: 0; Upper: 0; Group: 3; Decimals: 0),
    (Id: 'HVOL'; Name: 'Halstead volume';
     Hint: 'Length x log2(vocabulary)';
     Levels: [mlRoutine]; Aggr: maSum; Lower: 0; Upper: 0; Group: 3; Decimals: 1),
    (Id: 'HDIF'; Name: 'Halstead difficulty';
     Hint: '(distinct operators / 2) x (operands / distinct operands)';
     Levels: [mlRoutine]; Aggr: maMaximum; Lower: 0; Upper: 0; Group: 3; Decimals: 1),
    (Id: 'HEFF'; Name: 'Halstead effort';
     Hint: 'Difficulty x volume';
     Levels: [mlRoutine]; Aggr: maSum; Lower: 0; Upper: 0; Group: 3; Decimals: 1),
    (Id: 'MI'; Name: 'Maintainability index';
     Hint: '0 to 100, from the volume, the cyclomatic complexity and the lines: higher is easier to maintain';
     Levels: [mlRoutine]; Aggr: maMinimum; Lower: 20; Upper: 0; Group: 3; Decimals: 0));

  { the metrics that need code insight to resolve names }
  ResolvedMetrics = [miCBO, miRFC, miLCOM];

function MetricDefaults: TMetricSettings;
function MetricDefaultOptions: TMetricOptions;
{ -1 under the lower limit, 1 over the upper one, 0 within them }
function MetricOutside(const S: TMetricSetting; Value: Double): Integer;
{ a value as the view writes it }
function MetricValueText(Id: TMetricId; Value: Double): string;
{ a setting as its settings key keeps it, '1,Maximum,0,10', and back (a text that cannot be read
  leaves S as it was) }
function MetricSettingText(const S: TMetricSetting): string;
procedure ReadMetricSetting(const Text: string; var S: TMetricSetting);
{ a number written with a dot or a comma for its decimals; False: none }
function MetricNumber(const Text: string; out V: Double): Boolean;
function MetricIdOf(const Id: string; out M: TMetricId): Boolean;
{ a node's value of Id against its limits, as MetricOutside: the limits are for the metric's lowest
  level (a routine's lines, not a unit's) and for the aggregates that are one of those values (a
  Maximum, a Minimum: they show where to look); a sum, an average and a higher level's own value are
  not judged (0). 0 too when the node has no value of Id }
function MetricCellOutside(N: TMetricNode; Id: TMetricId; const Settings: TMetricSettings): Integer;
{ a value of a node outside its limits (Ids: the metrics to look at) }
function NodeOutside(N: TMetricNode; const Settings: TMetricSettings; Ids: TMetricIds): Boolean;
{ ... or of a node below it }
function TreeOutside(N: TMetricNode; const Settings: TMetricSettings; Ids: TMetricIds): Boolean;
{ the children of every node by a metric's value (ByName: by their names), Descending the other
  way; a node without the value goes last }
procedure SortMetricTree(N: TMetricNode; Id: TMetricId; ByName, Descending: Boolean);
{ the results as a table: CSV (comma-separated, a dot for decimals) and HTML (the tree indented,
  a value outside its limits in red or blue); Ids: the columns }
function MetricsCsv(Root: TMetricNode; Ids: TMetricIds): string;
function MetricsHtml(Root: TMetricNode; const Settings: TMetricSettings; Ids: TMetricIds;
  const Title: string): string;

implementation

{ ---------------------------------------------------------------------------- }
{ TMetricNode }

constructor TMetricNode.Create(AParent: TMetricNode; ALevel: TMetricLevel; const AName: string);
begin
  inherited Create;
  Parent := AParent;
  Level := ALevel;
  Name := AName;
  Children := TList.Create;
  if AParent <> nil then AParent.Children.Add(Self);
end;

destructor TMetricNode.Destroy;
var
  I: Integer;
begin
  for I := 0 to Children.Count - 1 do TObject(Children[I]).Free;
  Children.Free;
  inherited Destroy;
end;

function TMetricNode.Child(I: Integer): TMetricNode;
begin
  Result := TMetricNode(Children[I]);
end;

function TMetricNode.Count: Integer;
begin
  Result := Children.Count;
end;

procedure TMetricNode.SetValue(Id: TMetricId; V: Double);
begin
  Values[Id] := V;
  Include(Has, Id);
end;

{ ---------------------------------------------------------------------------- }
{ settings }

function MetricDefaults: TMetricSettings;
var
  M: TMetricId;
begin
  for M := Low(TMetricId) to High(TMetricId) do
  begin
    Result[M].On := True;
    Result[M].Aggr := MetricDefs[M].Aggr;
    Result[M].Lower := MetricDefs[M].Lower;
    Result[M].Upper := MetricDefs[M].Upper;
  end;
end;

function MetricDefaultOptions: TMetricOptions;
begin
  Result.FormFields := True;
  Result.OutsideAncestors := True;
end;

function MetricOutside(const S: TMetricSetting; Value: Double): Integer;
begin
  Result := 0;
  if (S.Upper > 0) and (Value > S.Upper + 1E-9) then Result := 1
  else if (S.Lower > 0) and (Value < S.Lower - 1E-9) then Result := -1;
end;

{ a number with a dot for its decimals, whatever the locale }
function DotNumber(V: Double; Decimals: Integer): string;
var
  I: Integer;
begin
  Result := FloatToStrF(V, ffFixed, 15, Decimals);
  for I := 1 to Length(Result) do
    if (Result[I] = ',') or (Result[I] = DecimalSeparator) then Result[I] := '.';
end;

function MetricValueText(Id: TMetricId; Value: Double): string;
begin
  if MetricDefs[Id].Decimals = 0 then Result := IntToStr(Round(Value))
  else Result := FloatToStrF(Value, ffFixed, 15, MetricDefs[Id].Decimals);
end;

function MetricSettingText(const S: TMetricSetting): string;
const
  Bits: array[Boolean] of string = ('0', '1');
begin
  Result := Bits[S.On] + ',' + MetricAggrNames[S.Aggr] + ',' + DotNumber(S.Lower, 2) + ',' +
    DotNumber(S.Upper, 2);
end;

function MetricNumber(const Text: string; out V: Double): Boolean;
var
  T: string;
  I, Code: Integer;
begin
  T := Trim(Text);
  for I := 1 to Length(T) do
    if T[I] = ',' then T[I] := '.';
  Val(T, V, Code);
  Result := (T <> '') and (Code = 0);
end;

procedure ReadMetricSetting(const Text: string; var S: TMetricSetting);
var
  Parts: TStringList;
  A: TMetricAggr;
  V: Double;
begin
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ',';
    Parts.DelimitedText := Text;
    if Parts.Count < 1 then Exit;
    S.On := Trim(Parts[0]) <> '0';
    if Parts.Count > 1 then
      for A := Low(TMetricAggr) to High(TMetricAggr) do
        if SameText(Trim(Parts[1]), MetricAggrNames[A]) then S.Aggr := A;
    if (Parts.Count > 2) and MetricNumber(Parts[2], V) and (V >= 0) then S.Lower := V;
    if (Parts.Count > 3) and MetricNumber(Parts[3], V) and (V >= 0) then S.Upper := V;
  finally
    Parts.Free;
  end;
end;

function MetricIdOf(const Id: string; out M: TMetricId): Boolean;
var
  X: TMetricId;
begin
  Result := False;
  M := miLOC;
  for X := Low(TMetricId) to High(TMetricId) do
    if SameText(MetricDefs[X].Id, Id) then
    begin
      M := X;
      Result := True;
      Exit;
    end;
end;

function MetricCellOutside(N: TMetricNode; Id: TMetricId; const Settings: TMetricSettings): Integer;
var
  Lowest: TMetricLevel;
begin
  Result := 0;
  if not (Id in N.Has) or not Settings[Id].On then Exit;
  Lowest := mlRoutine;
  while not (Lowest in MetricDefs[Id].Levels) do Inc(Lowest);
  if (N.Level = Lowest) or (not (N.Level in MetricDefs[Id].Levels) and (Settings[Id].Aggr in [maMaximum, maMinimum])) then
    Result := MetricOutside(Settings[Id], N.Values[Id]);
end;

function NodeOutside(N: TMetricNode; const Settings: TMetricSettings; Ids: TMetricIds): Boolean;
var
  M: TMetricId;
begin
  Result := False;
  for M := Low(TMetricId) to High(TMetricId) do
    if (M in Ids) and (MetricCellOutside(N, M, Settings) <> 0) then
    begin
      Result := True;
      Exit;
    end;
end;

function TreeOutside(N: TMetricNode; const Settings: TMetricSettings; Ids: TMetricIds): Boolean;
var
  I: Integer;
begin
  Result := NodeOutside(N, Settings, Ids);
  I := 0;
  while not Result and (I < N.Count) do
  begin
    Result := TreeOutside(N.Child(I), Settings, Ids);
    Inc(I);
  end;
end;

{ ---------------------------------------------------------------------------- }
{ sorting }

var
  SortId: TMetricId;
  SortByName, SortDesc: Boolean;

function CompareNodes(A, B: Pointer): Integer;
var
  NA, NB: TMetricNode;
  HA, HB: Boolean;
begin
  NA := TMetricNode(A);
  NB := TMetricNode(B);
  if SortByName then
    Result := AnsiCompareText(NA.Name, NB.Name)
  else
  begin
    HA := SortId in NA.Has;
    HB := SortId in NB.Has;
    if HA <> HB then
    begin
      { the nodes without the value last, either way }
      if HA then Result := -1 else Result := 1;
      Exit;
    end;
    { equal values (or none) by name, A to Z either way }
    if not HA or (NA.Values[SortId] = NB.Values[SortId]) then
    begin
      Result := AnsiCompareText(NA.Name, NB.Name);
      Exit;
    end;
    if NA.Values[SortId] < NB.Values[SortId] then Result := -1
    else Result := 1;
  end;
  if SortDesc then Result := -Result;
end;

procedure SortChildren(N: TMetricNode);
var
  I: Integer;
begin
  N.Children.Sort(CompareNodes);
  for I := 0 to N.Count - 1 do SortChildren(N.Child(I));
end;

procedure SortMetricTree(N: TMetricNode; Id: TMetricId; ByName, Descending: Boolean);
begin
  SortId := Id;
  SortByName := ByName;
  SortDesc := Descending;
  SortChildren(N);
end;

{ ---------------------------------------------------------------------------- }
{ export }

function CsvField(const S: string): string;
begin
  if (Pos(',', S) > 0) or (Pos('"', S) > 0) then
    Result := '"' + StringReplace(S, '"', '""', [rfReplaceAll]) + '"'
  else
    Result := S;
end;

function NodePath(N: TMetricNode): string;
begin
  Result := N.Name;
  N := N.Parent;
  while (N <> nil) and (N.Level <> mlProject) do
  begin
    if N.Level = mlUnit then Result := N.Name + '.' + Result;
    N := N.Parent;
  end;
end;

function MetricsCsv(Root: TMetricNode; Ids: TMetricIds): string;
var
  SL: TStringList;
  M: TMetricId;
  H: string;

  procedure Row(N: TMetricNode);
  var
    I: Integer;
    S: string;
    X: TMetricId;
  begin
    S := MetricLevelNames[N.Level] + ',' + CsvField(NodePath(N)) + ',' + CsvField(N.FileName) + ',';
    if N.Line > 0 then S := S + IntToStr(N.Line);
    for X := Low(TMetricId) to High(TMetricId) do
      if X in Ids then
      begin
        S := S + ',';
        if X in N.Has then S := S + DotNumber(N.Values[X], MetricDefs[X].Decimals);
      end;
    SL.Add(S);
    for I := 0 to N.Count - 1 do Row(N.Child(I));
  end;

begin
  SL := TStringList.Create;
  try
    H := 'Level,Name,File,Line';
    for M := Low(TMetricId) to High(TMetricId) do
      if M in Ids then H := H + ',' + MetricDefs[M].Id;
    SL.Add(H);
    if Root <> nil then Row(Root);
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

function HtmlText(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
end;

function MetricsHtml(Root: TMetricNode; const Settings: TMetricSettings; Ids: TMetricIds;
  const Title: string): string;
var
  SL: TStringList;
  M: TMetricId;
  H: string;

  procedure Row(N: TMetricNode; Depth: Integer);
  var
    I: Integer;
    S, Cls: string;
    X: TMetricId;
  begin
    S := '<tr><td style="padding-left:' + IntToStr(Depth * 16 + 4) + 'px">' + HtmlText(N.Name) + '</td>';
    for X := Low(TMetricId) to High(TMetricId) do
      if X in Ids then
      begin
        Cls := '';
        case MetricCellOutside(N, X, Settings) of
          1: Cls := ' class="over"';
          -1: Cls := ' class="under"';
        end;
        S := S + '<td' + Cls + '>';
        if X in N.Has then S := S + HtmlText(MetricValueText(X, N.Values[X]));
        S := S + '</td>';
      end;
    SL.Add(S + '</tr>');
    for I := 0 to N.Count - 1 do Row(N.Child(I), Depth + 1);
  end;

begin
  SL := TStringList.Create;
  try
    SL.Add('<!DOCTYPE html>');
    SL.Add('<html><head><meta charset="utf-8"><title>' + HtmlText(Title) + '</title>');
    SL.Add('<style>body{font-family:Segoe UI,sans-serif;font-size:9pt}table{border-collapse:collapse}' +
      'th,td{border:1px solid #d0d0d0;padding:2px 6px;text-align:right;white-space:nowrap}' +
      'th:first-child,td:first-child{text-align:left}th{background:#f0f0f0}' +
      '.over{color:#c00000;font-weight:bold}.under{color:#0060c0;font-weight:bold}</style></head><body>');
    SL.Add('<h3>' + HtmlText(Title) + '</h3>');
    H := '<table><tr><th>Name</th>';
    for M := Low(TMetricId) to High(TMetricId) do
      if M in Ids then H := H + '<th title="' + HtmlText(MetricDefs[M].Name) + '">' + MetricDefs[M].Id + '</th>';
    SL.Add(H + '</tr>');
    if Root <> nil then Row(Root, 0);
    SL.Add('</table></body></html>');
    Result := SL.Text;
  finally
    SL.Free;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ the run }

type
  TMClass = class;

  { a routine with a body, while its unit is analysed }
  TMRoutine = class
  public
    Node: TMetricNode;
    Sym: TRoutineSym;
    Cls: TMClass;                 // the class it is a method of (nil: a plain routine)
    UseA, UseB: Integer;          // the text whose names count for it: after its heading to its end
    Fields: TStringList;          // LCOM: the keys of the class's fields it uses
    destructor Destroy; override;
  end;

  { a class of the project }
  TMClass = class
  public
    Node: TMetricNode;
    Name, UName: string;          // UName: upper case
    UnitKey: string;              // its unit's file name, upper case
    Ancestor: string;             // the direct ancestor's name as declared (its unit's prefix cut)
    IsClass: Boolean;             // a class, not an object type
    DeclA, DeclB: Integer;        // its declaration's text
    UsesSet: TStringList;         // CBO: the classes it uses, upper case
    UsedBy: TStringList;          // ... and those that use it
    Calls: TStringList;           // RFC: the keys of the routines its methods call
    OwnKeys: TStringList;         // the keys of its own methods
    FieldKeys: TStringList;       // the keys of its fields that count (LCOM)
    Skip: array of Integer;       // pairs: the declarations of the fields that do not count (CBO)
    AncestorNames: TStringList;   // upper case, for CBO
    Methods: TList;               // TMRoutine
    constructor Create;
    destructor Destroy; override;
    function Skipped(Ofs: Integer): Boolean;
  end;

function NewSet: TStringList;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.Duplicates := dupIgnore;
end;

{ the two sorted sets have an element in common }
function SharesAny(A, B: TStringList): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to A.Count - 1 do
    if B.IndexOf(A[I]) >= 0 then
    begin
      Result := True;
      Exit;
    end;
end;

destructor TMRoutine.Destroy;
begin
  Fields.Free;
  inherited Destroy;
end;

constructor TMClass.Create;
begin
  inherited Create;
  UsesSet := NewSet;
  UsedBy := NewSet;
  Calls := NewSet;
  OwnKeys := NewSet;
  FieldKeys := NewSet;
  AncestorNames := NewSet;
  Methods := TList.Create;
end;

destructor TMClass.Destroy;
begin
  UsesSet.Free;
  UsedBy.Free;
  Calls.Free;
  OwnKeys.Free;
  FieldKeys.Free;
  AncestorNames.Free;
  Methods.Free;
  inherited Destroy;
end;

function TMClass.Skipped(Ofs: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  I := 0;
  while I < High(Skip) do
  begin
    if (Ofs >= Skip[I]) and (Ofs < Skip[I + 1]) then
    begin
      Result := True;
      Exit;
    end;
    Inc(I, 2);
  end;
end;

type
  { the state of one run }
  TRunner = class
  public
    CI: TCodeInsight;
    Settings: TMetricSettings;
    Options: TMetricOptions;
    Root: TMetricNode;
    ClassMap: TStringList;        // UnitKey|UName -> TMClass (owned)
    ByName: TStringList;          // UName -> TMClass (the first of a name)
    UnitNodes: TStringList;       // upper unit name -> TMetricNode
    UnitUses: TStringList;        // upper unit name -> its uses (TStringList, upper case, owned)
    Errors: Integer;
    LastError: string;
    constructor Create;
    destructor Destroy; override;
    procedure DoUnit(const FileName: string);
    procedure Ancestry(Files: TStrings);
    procedure Finish;
  end;

  { one unit's analysis }
  TUnitPass = class
  public
    R: TRunner;
    FileName, UKey, Text: string;
    U: TUnitInfo;
    Toks: TRawToks;
    Blocks: TPasBlocks;
    Code, Cmt: array of Boolean;  // a line (1-based) holds code, a comment
    LineCount: Integer;
    UnitNode: TMetricNode;
    Routines: TList;              // TMRoutine (owned)
    LocalClasses: TStringList;    // UName -> TMClass of this unit
    constructor Create(ARunner: TRunner; const AFileName, AText: string);
    destructor Destroy; override;
    function LineOf(Ofs: Integer): Integer;
    procedure MarkLines;
    procedure LineCounts(A, B: Integer; Holes: TList; out Total, CodeLines, CmtLines: Integer);
    procedure SetLineValues(N: TMetricNode; A, B: Integer; Holes: TList);
    procedure DoClasses;
    procedure DoRoutine(S: TRoutineSym; Outer: TMRoutine);
    procedure Measure(MR: TMRoutine; Holes: TList);
    procedure Couple;
    procedure Run;
  end;

constructor TRunner.Create;
begin
  inherited Create;
  ClassMap := TStringList.Create;
  ClassMap.Sorted := True;
  ClassMap.Duplicates := dupIgnore;
  ByName := TStringList.Create;
  ByName.Sorted := True;
  ByName.Duplicates := dupIgnore;
  UnitNodes := TStringList.Create;
  UnitNodes.Sorted := True;
  UnitNodes.Duplicates := dupIgnore;
  UnitUses := TStringList.Create;
  UnitUses.Sorted := True;
  UnitUses.Duplicates := dupIgnore;
end;

destructor TRunner.Destroy;
var
  I: Integer;
begin
  for I := 0 to ClassMap.Count - 1 do ClassMap.Objects[I].Free;
  ClassMap.Free;
  ByName.Free;
  UnitNodes.Free;
  for I := 0 to UnitUses.Count - 1 do UnitUses.Objects[I].Free;
  UnitUses.Free;
  inherited Destroy;
end;

constructor TUnitPass.Create(ARunner: TRunner; const AFileName, AText: string);
begin
  inherited Create;
  R := ARunner;
  FileName := AFileName;
  UKey := AnsiUpperCase(AFileName);
  Text := AText;
  U := TUnitInfo.Create;
  Routines := TList.Create;
  LocalClasses := TStringList.Create;
  LocalClasses.Sorted := True;
  LocalClasses.Duplicates := dupIgnore;
end;

destructor TUnitPass.Destroy;
var
  I: Integer;
begin
  for I := 0 to Routines.Count - 1 do TObject(Routines[I]).Free;
  Routines.Free;
  LocalClasses.Free;
  Blocks.Free;
  Toks.Free;
  U.Free;
  inherited Destroy;
end;

function TUnitPass.LineOf(Ofs: Integer): Integer;
var
  Col: Integer;
begin
  Result := U.LineOfOffset(Ofs, Col);
end;

{ which lines hold code and which a comment; a compiler directive counts as code }
procedure TUnitPass.MarkLines;
var
  I, L, A, B: Integer;
  T: PToken;
  IsCmt: Boolean;
begin
  LineCount := LineOf(Length(Text));
  if (Text <> '') and (Text[Length(Text)] in [#10, #13]) and (LineCount > 1) then Dec(LineCount);
  SetLength(Code, LineCount + 2);
  SetLength(Cmt, LineCount + 2);
  for I := 0 to Toks.N - 1 do
  begin
    T := @Toks.T[I];
    if T.Len <= 0 then Continue;
    IsCmt := (T.Kind = tkComment) and not ((T.Len >= 2) and (T.Ptr[0] = '{') and (T.Ptr[1] = '$')) and
      not ((T.Len >= 3) and (T.Ptr[0] = '(') and (T.Ptr[1] = '*') and (T.Ptr[2] = '$'));
    A := T.Line;
    if T.Kind = tkComment then B := LineOf(T.Start + T.Len - 1) else B := A;
    for L := A to B do
      if (L >= 1) and (L <= LineCount) then
        if IsCmt then Cmt[L] := True else Code[L] := True;
  end;
end;

{ the lines of A .. B (offsets; B the last one) without those of the ranges in Holes (pairs of
  line numbers): all of them, those with code, those with a comment }
procedure TUnitPass.LineCounts(A, B: Integer; Holes: TList; out Total, CodeLines, CmtLines: Integer);
var
  L, I: Integer;
  Hole: Boolean;
begin
  Total := 0;
  CodeLines := 0;
  CmtLines := 0;
  for L := LineOf(A) to LineOf(B) do
  begin
    Hole := False;
    if Holes <> nil then
    begin
      I := 0;
      while not Hole and (I < Holes.Count - 1) do
      begin
        Hole := (L >= Integer(Holes[I])) and (L <= Integer(Holes[I + 1]));
        Inc(I, 2);
      end;
    end;
    if Hole then Continue;
    Inc(Total);
    if L > LineCount then Continue;
    if Code[L] then Inc(CodeLines);
    if Cmt[L] then Inc(CmtLines);
  end;
end;

{ LOC, CLOC and CMT of a routine or a unit: the lines of A .. B without the Holes }
procedure TUnitPass.SetLineValues(N: TMetricNode; A, B: Integer; Holes: TList);
var
  Total, CodeLines, CmtLines: Integer;
begin
  LineCounts(A, Max(B, A), Holes, Total, CodeLines, CmtLines);
  N.SetValue(miLOC, Total);
  N.SetValue(miCLOC, CodeLines);
  if CodeLines > 0 then N.SetValue(miCMT, CmtLines * 100 / CodeLines) else N.SetValue(miCMT, 0);
end;
{ the classes (and objects) the unit declares, with their members }
procedure TUnitPass.DoClasses;
var
  Pass, I, K: Integer;
  Tab: TSymTable;
  S, M: TSymbol;
  D: TTypeDesc;
  C: TMClass;
  NOA, NOM, NPR: Integer;
  FormField: Boolean;
begin
  for Pass := 0 to 1 do
  begin
    if Pass = 0 then Tab := U.IntfSyms else Tab := U.ImplSyms;
    for I := 0 to Tab.Count - 1 do
    begin
      S := Tab[I];
      if (S.Kind <> skType) or not IsStructDecl(S, [tyClass, tyObject]) then Continue;
      D := S.TypeDesc;
      C := TMClass.Create;
      C.Name := S.Name;
      C.UName := AnsiUpperCase(S.Name);
      C.UnitKey := UKey;
      C.IsClass := D.Kind = tyClass;
      if (D.Ancestors <> nil) and (D.Ancestors.Count > 0) then
      begin
        C.Ancestor := D.Ancestors[0];
        if Pos('.', C.Ancestor) > 0 then C.Ancestor := Copy(C.Ancestor, LastDelimiter('.', C.Ancestor) + 1, MaxInt);
      end;
      C.DeclA := S.DeclStart;
      if D.EndOfs > 0 then C.DeclB := D.EndOfs else C.DeclB := S.FullEnd;
      if R.ClassMap.IndexOf(UKey + '|' + C.UName) >= 0 then
      begin
        C.Free;
        Continue;
      end;
      R.ClassMap.AddObject(UKey + '|' + C.UName, C);
      R.ByName.AddObject(C.UName, C);
      LocalClasses.AddObject(C.UName, C);
      C.Node := TMetricNode.Create(UnitNode, mlClass, S.Name);
      C.Node.FileName := FileName;
      C.Node.Line := S.Line;
      NOA := 0;
      NOM := 0;
      NPR := 0;
      for K := 0 to D.Members.Count - 1 do
      begin
        M := D.Members[K];
        if M.Name = '' then Continue;
        case M.Kind of
          skField:
            begin
              { a component of a form: declared before the first visibility word, or published }
              FormField := (M.Visibility = viPublished) or (M.Visibility = viNone) or
                (D.FirstVisOfs = 0) or (M.DeclStart < D.FirstVisOfs);
              if FormField and not R.Options.FormFields then
              begin
                SetLength(C.Skip, Length(C.Skip) + 2);
                C.Skip[High(C.Skip) - 1] := M.DeclStart;
                C.Skip[High(C.Skip)] := Max(M.FullEnd, M.TypeEnd);
                Continue;
              end;
              Inc(NOA);
              C.FieldKeys.Add(UKey + '#' + IntToStr(M.DeclStart));
            end;
          skRoutine:
            begin
              Inc(NOM);
              C.OwnKeys.Add(UKey + '#' + IntToStr(M.DeclStart));
            end;
          skProperty: Inc(NPR);
        end;
      end;
      C.Node.SetValue(miNOA, NOA);
      C.Node.SetValue(miNOM, NOM);
      C.Node.SetValue(miNPR, NPR);
    end;
  end;
end;

{ a routine with a body, and the routines nested in it }
procedure TUnitPass.DoRoutine(S: TRoutineSym; Outer: TMRoutine);
var
  MR: TMRoutine;
  Parent: TMetricNode;
  I: Integer;
  X: TSymbol;
  Nested, Holes: TList;
  Name: string;
begin
  if not (sfHasBody in S.Flags) or (S.BodyStart <= 0) then Exit;
  MR := TMRoutine.Create;
  Routines.Add(MR);
  MR.Sym := S;
  if Outer <> nil then
  begin
    MR.Cls := Outer.Cls;
    Parent := Outer.Node.Parent;
    Name := Outer.Node.Name + '.' + S.Name;
  end
  else
  begin
    Parent := UnitNode;
    Name := S.Name;
    if S.ClassQual <> '' then
    begin
      Name := S.ClassQual + '.' + S.Name;
      I := LocalClasses.IndexOf(AnsiUpperCase(S.ClassQual));
      if I >= 0 then
      begin
        MR.Cls := TMClass(LocalClasses.Objects[I]);
        MR.Cls.Methods.Add(MR);
        Parent := MR.Cls.Node;
      end;
    end;
  end;
  MR.Node := TMetricNode.Create(Parent, mlRoutine, Name);
  MR.Node.FileName := FileName;
  MR.Node.Line := LineOf(S.HeadStart);
  MR.Node.IsMethod := MR.Cls <> nil;
  if (S.FullEnd > S.HeadStart) and (S.FullEnd <= S.BodyStart) then MR.UseA := S.FullEnd
  else MR.UseA := S.BodyStart;
  MR.UseB := S.BodyEnd;
  MR.Fields := NewSet;
  { the nested routines: rows of their own, their lines not the outer one's }
  Nested := TList.Create;
  Holes := TList.Create;
  try
    if S.Locals <> nil then
      for I := 0 to S.Locals.Count - 1 do
      begin
        X := S.Locals[I];
        if (X is TRoutineSym) and (X.Kind = skRoutine) and (sfImplBody in X.Flags) and
          (sfHasBody in X.Flags) then
        begin
          Nested.Add(X);
          Holes.Add(Pointer(LineOf(TRoutineSym(X).HeadStart)));
          Holes.Add(Pointer(LineOf(Max(TRoutineSym(X).BodyEnd - 1, TRoutineSym(X).HeadStart))));
        end;
      end;
    Measure(MR, Holes);
    for I := 0 to Nested.Count - 1 do DoRoutine(TRoutineSym(Nested[I]), MR);
  finally
    Holes.Free;
    Nested.Free;
  end;
end;

{ the size, complexity and Halstead's measures of a routine }
procedure TUnitPass.Measure(MR: TMRoutine; Holes: TList);
var
  S: TRoutineSym;
  LOC, CC, Depth, MaxDepth, Paren, I, K, W, J, NL: Integer;
  B0, B1: Integer;
  Cond: Boolean;
  T: PToken;
  Stack: array of Integer;
  Ops, Opnds: TStringList;
  N1, N2: Integer;
  n1d, n2d, Vol, Dif, MI: Double;
  X: TSymbol;

  function NextCode(From: Integer): Integer;
  begin
    Result := From + 1;
    while (Result < Toks.N) and (Toks.T[Result].Kind = tkComment) do Inc(Result);
  end;

  procedure Op(const Name: string);
  begin
    Inc(N1);
    Ops.Add(Name);
  end;

  procedure Operand(const Name: string);
  begin
    Inc(N2);
    Opnds.Add(Name);
  end;

begin
  S := MR.Sym;
  B0 := S.BodyStart;
  B1 := S.BodyEnd;
  SetLineValues(MR.Node, S.HeadStart, B1 - 1, Holes);
  LOC := Round(MR.Node.Values[miLOC]);
  EnsureParams(S);
  if S.Params <> nil then MR.Node.SetValue(miNOP, S.Params.Count) else MR.Node.SetValue(miNOP, 0);
  NL := 0;
  if S.Locals <> nil then
    for I := 0 to S.Locals.Count - 1 do
    begin
      X := S.Locals[I];
      if X.Kind in [skLocal, skVar, skConst, skResStr] then Inc(NL);
    end;
  MR.Node.SetValue(miNOL, NL);

  { the decisions and the operators and operands of the body }
  CC := 1;
  Paren := 0;
  Cond := False;
  N1 := 0;
  N2 := 0;
  Ops := NewSet;
  Opnds := NewSet;
  try
    I := Toks.FirstAt(B0);
    while (I >= 0) and (I < Toks.N) and (Toks.T[I].Start < B1) do
    begin
      T := @Toks.T[I];
      if (T.Kind = tkComment) or T.InAsm then
      begin
        Inc(I);
        Continue;
      end;
      case T.Kind of
        tkKeyword:
          begin
            case T.Keyword of
              kwIf, kwWhile:
                begin
                  Inc(CC);
                  Cond := True;
                end;
              kwFor, kwRepeat: Inc(CC);
              kwUntil: Cond := True;
              kwAnd, kwOr:
                if Cond then Inc(CC);
              kwThen, kwDo, kwElse, kwEnd, kwBegin, kwOf, kwFinally: Cond := False;
              kwExcept:
                begin
                  Cond := False;
                  K := NextCode(I);
                  if not ((K < Toks.N) and Toks.IsId(K, 'ON')) then Inc(CC);
                end;
            end;
            if T.Keyword = kwNil then Operand('nil')
            else if T.Keyword <> kwEnd then Op(KeywordNames[T.Keyword]);
          end;
        tkSymbol:
          begin
            case T.Symbol of
              syLParen, syLBracket: Inc(Paren);
              syRParen, syRBracket: if Paren > 0 then Dec(Paren);
              sySemicolon: Cond := False;
              syColon:
                if Paren = 0 then
                begin
                  W := Blocks.EnclosingBlock(T.Start);
                  if (W >= 0) and (Blocks.Words[W].Kind = bkCase) and (Blocks.Words[W].Start >= B0) then Inc(CC);
                end;
            end;
            if not (T.Symbol in [syRParen, syRBracket]) then Op(Toks.Txt(I));
          end;
        tkIdent:
          begin
            K := NextCode(I);
            { an exception handler: on E: EClass do / on EClass do }
            if Toks.IsId(I, 'ON') and (K < Toks.N) and (Toks.T[K].Kind = tkIdent) then
            begin
              J := NextCode(K);
              if (J < Toks.N) and (Toks.IsSy(J, syColon) or Toks.IsKw(J, kwDo)) then Inc(CC);
            end;
            if (K < Toks.N) and Toks.IsSy(K, syLParen) then Op(AnsiUpperCase(Toks.Txt(I)))
            else Operand(AnsiUpperCase(Toks.Txt(I)));
          end;
        tkNumber, tkString: Operand(Toks.Txt(I));
      end;
      Inc(I);
    end;
    MR.Node.SetValue(miCC, CC);
    n1d := Ops.Count;
    n2d := Opnds.Count;
  finally
    Ops.Free;
    Opnds.Free;
  end;

  { the nesting of the blocks inside the body: the body's own begin is level 0 }
  MaxDepth := 0;
  SetLength(Stack, 0);
  for W := 0 to Blocks.WordCount - 1 do
  begin
    if Blocks.Words[W].Start < B0 then Continue;
    if Blocks.Words[W].Start >= B1 then Break;
    case Blocks.Words[W].Role of
      wrOpen:
        if Blocks.Words[W].Kind in [bkBegin, bkCase, bkTry, bkAsm, bkRepeat] then
        begin
          SetLength(Stack, Length(Stack) + 1);
          Stack[High(Stack)] := W;
          if Length(Stack) > MaxDepth then MaxDepth := Length(Stack);
        end;
      wrClose:
        begin
          J := High(Stack);
          while (J >= 0) and (Stack[J] <> Blocks.Words[W].Opener) do Dec(J);
          if J >= 0 then SetLength(Stack, J);
        end;
    end;
  end;
  Depth := MaxDepth - 1;
  if Depth < 0 then Depth := 0;
  MR.Node.SetValue(miND, Depth);

  MR.Node.SetValue(miHLEN, N1 + N2);
  MR.Node.SetValue(miHVOC, n1d + n2d);
  if n1d + n2d > 1 then Vol := (N1 + N2) * Log2(n1d + n2d) else Vol := 0;
  MR.Node.SetValue(miHVOL, Vol);
  if n2d > 0 then Dif := (n1d / 2) * (N2 / n2d) else Dif := 0;
  MR.Node.SetValue(miHDIF, Dif);
  MR.Node.SetValue(miHEFF, Dif * Vol);
  MI := (171 - 5.2 * Ln(Max(Vol, 1)) - 0.23 * CC - 16.2 * Ln(Max(LOC, 1))) * 100 / 171;
  if MI < 0 then MI := 0;
  if MI > 100 then MI := 100;
  MR.Node.SetValue(miMI, MI);
end;

{ coupling and cohesion: the names of the whole text resolved once, each counted for the method
  or the class declaration it lies in }
procedure TUnitPass.Couple;
var
  Cats: TStringList;
  NameList: TList;
  I, K, Cat: Integer;
  NU: TCINameUse;
  MR, Hit: TMRoutine;
  C: TMClass;
  UKeyName, TT: string;

  { is TypeText a class or an interface type, in the scope of Pos }
  function IsClassType(const TypeText: string; Pos: Integer): Boolean;
  var
    J: Integer;
  begin
    J := Cats.IndexOf(AnsiUpperCase(TypeText));
    if J >= 0 then
    begin
      Result := Integer(Cats.Objects[J]) <> 0;
      Exit;
    end;
    Result := R.CI.TypeCategory(FileName, Text, Pos, TypeText) in [tcClass, tcInterface];
    Cats.AddObject(AnsiUpperCase(TypeText), TObject(Ord(Result)));
  end;

begin
  if LocalClasses.Count = 0 then Exit;
  NameList := TList.Create;
  Cats := TStringList.Create;
  Cats.Sorted := True;
  try
    if not R.CI.NameUses(FileName, Text, 0, Length(Text), NameList) then Exit;
    for I := 0 to NameList.Count - 1 do
    begin
      NU := TCINameUse(NameList[I]);
      { the method around it, else the class declaration around it }
      Hit := nil;
      for K := 0 to Routines.Count - 1 do
      begin
        MR := TMRoutine(Routines[K]);
        if (MR.Cls <> nil) and (MR.Node.Parent = MR.Cls.Node) and (MR.Sym.ClassQual <> '') and
          (NU.Start >= MR.UseA) and (NU.Start < MR.UseB) then
        begin
          Hit := MR;
          Break;
        end;
      end;
      C := nil;
      if Hit <> nil then C := Hit.Cls
      else
        for K := 0 to LocalClasses.Count - 1 do
          if (NU.Start >= TMClass(LocalClasses.Objects[K]).DeclA) and
            (NU.Start < TMClass(LocalClasses.Objects[K]).DeclB) then
          begin
            C := TMClass(LocalClasses.Objects[K]);
            Break;
          end;
      if C = nil then Continue;
      if (Hit = nil) and C.Skipped(NU.Start) then Continue;
      UKeyName := AnsiUpperCase(NU.Key);
      { CBO: the classes and interfaces it names, and those of the values it uses }
      if NU.Kind in [ckClass, ckInterface] then
        C.UsesSet.Add(AnsiUpperCase(NU.Name))
      else if (NU.TypeText <> '') and (NU.Kind in [ckVar, ckField, ckParam, ckLocalVar, ckProperty, ckConst]) then
      begin
        TT := Trim(NU.TypeText);
        if (TT <> '') and IsClassType(TT, NU.Start) then C.UsesSet.Add(AnsiUpperCase(TT));
      end;
      if Hit = nil then Continue;
      { RFC: the routines its methods call; LCOM: the fields each method uses }
      { the compiler's own routines (Length, Inc ...) have no source: not counted }
      if (NU.Kind in [ckProcedure, ckFunction, ckConstructor, ckDestructor]) and (UKeyName <> '') and
        (UKeyName[1] <> '#') then
        C.Calls.Add(UKeyName)
      else if (NU.Kind = ckField) and (C.FieldKeys.IndexOf(UKeyName) >= 0) then
        Hit.Fields.Add(UKeyName);
    end;
    { a method's nested routines use the fields for it }
    for K := 0 to Routines.Count - 1 do
    begin
      MR := TMRoutine(Routines[K]);
      if (MR.Cls = nil) or (MR.Node.Parent <> MR.Cls.Node) then Continue;
      if MR.Sym.ClassQual = '' then
      begin
        { a nested routine: its outer method is the method whose range holds it }
        for Cat := 0 to Routines.Count - 1 do
        begin
          Hit := TMRoutine(Routines[Cat]);
          if (Hit <> MR) and (Hit.Sym.ClassQual <> '') and (MR.Sym.HeadStart >= Hit.UseA) and
            (MR.Sym.HeadStart < Hit.UseB) then
          begin
            Hit.Fields.AddStrings(MR.Fields);
            Break;
          end;
        end;
      end;
    end;
  finally
    for I := 0 to NameList.Count - 1 do TObject(NameList[I]).Free;
    NameList.Free;
    Cats.Free;
  end;
end;

procedure TUnitPass.Run;
var
  I, K, P, Q, Common: Integer;
  C: TMClass;
  MR, M2: TMRoutine;
  WMC: Double;
  UsesList: TStringList;
begin
  ParseSource(U, Text, False, R.CI.Defines, nil);
  U.FileName := FileName;
  if U.Name = '' then U.Name := ChangeFileExt(ExtractFileName(FileName), '');
  UnitNode := TMetricNode.Create(R.Root, mlUnit, U.Name);
  UnitNode.FileName := FileName;
  UnitNode.Line := 1;
  R.UnitNodes.AddObject(AnsiUpperCase(U.Name), UnitNode);
  UsesList := NewSet;
  for I := 0 to U.IntfUses.Count - 1 do UsesList.Add(AnsiUpperCase(U.IntfUses[I]));
  for I := 0 to U.ImplUses.Count - 1 do UsesList.Add(AnsiUpperCase(U.ImplUses[I]));
  R.UnitUses.AddObject(AnsiUpperCase(U.Name), UsesList);
  Toks := TRawToks.Create(Text, True);
  Blocks := TPasBlocks.Create(Text);
  MarkLines;

  SetLineValues(UnitNode, 0, Length(Text) - 1, nil);
  UnitNode.SetValue(miCE, UsesList.Count);

  DoClasses;
  for I := 0 to U.ImplRoutines.Count - 1 do DoRoutine(TRoutineSym(U.ImplRoutines[I]), nil);
  UnitNode.SetValue(miNOM, Routines.Count);

  if R.Settings[miCBO].On or R.Settings[miRFC].On or R.Settings[miLCOM].On then Couple;

  { the classes' own measures from their methods }
  for K := 0 to LocalClasses.Count - 1 do
  begin
    C := TMClass(LocalClasses.Objects[K]);
    WMC := 0;
    LineCounts(C.DeclA, Max(C.DeclB - 1, C.DeclA), nil, I, Q, Common);
    for P := 0 to C.Methods.Count - 1 do
    begin
      MR := TMRoutine(C.Methods[P]);
      WMC := WMC + MR.Node.Values[miCC];
      I := I + Round(MR.Node.Values[miLOC]);
      Q := Q + Round(MR.Node.Values[miCLOC]);
    end;
    C.Node.SetValue(miLOC, I);
    C.Node.SetValue(miCLOC, Q);
    C.Node.SetValue(miWMC, WMC);
    if R.Settings[miRFC].On then
    begin
      C.Calls.AddStrings(C.OwnKeys);
      C.Node.SetValue(miRFC, C.Calls.Count);
    end;
    if R.Settings[miLCOM].On then
    begin
      P := 0;
      Q := 0;
      for I := 0 to C.Methods.Count - 1 do
      begin
        MR := TMRoutine(C.Methods[I]);
        for Common := I + 1 to C.Methods.Count - 1 do
        begin
          M2 := TMRoutine(C.Methods[Common]);
          if SharesAny(MR.Fields, M2.Fields) then Inc(Q) else Inc(P);
        end;
      end;
      C.Node.SetValue(miLCOM, Max(P - Q, 0));
    end;
  end;
end;

procedure TRunner.DoUnit(const FileName: string);
var
  Text: string;
  P: TUnitPass;
  N: TMetricNode;
begin
  if not CI.ReadText(FileName, Text) then
  begin
    N := TMetricNode.Create(Root, mlUnit, ChangeFileExt(ExtractFileName(FileName), ''));
    N.FileName := FileName;
    N.Hint := 'could not be read';
    Inc(Errors);
    LastError := FileName + ': could not be read';
    Exit;
  end;
  P := TUnitPass.Create(Self, FileName, Text);
  try
    try
      P.Run;
    except
      on E: Exception do
      begin
        Inc(Errors);
        LastError := FileName + ': ' + E.ClassName + ': ' + E.Message;
        if P.UnitNode <> nil then P.UnitNode.Hint := 'could not be analysed: ' + E.Message;
      end;
    end;
  finally
    P.Free;
  end;
end;

{ DIT, and the ancestors CBO leaves out: code insight's browse model follows each class's
  ancestors through every unit, those outside the project too }
procedure TRunner.Ancestry(Files: TStrings);
var
  Model: TCIBrowseModel;
  I, K, Depth: Integer;
  BU: TCIBrowseUnit;
  BS, A: TCIBrowseSym;
  C: TMClass;
  Names: TStringList;
begin
  Model := CI.Browse(Files, False);
  Names := TStringList.Create;
  try
    for I := 0 to Model.Units.Count - 1 do
    begin
      BU := TCIBrowseUnit(Model.Units[I]);
      if not BU.InProject then Continue;
      for K := 0 to BU.Syms.Count - 1 do
      begin
        BS := TCIBrowseSym(BU.Syms[K]);
        if BS.Kind <> ckClass then Continue;
        Names.AddObject(AnsiUpperCase(BU.FileName) + '|' + AnsiUpperCase(BS.Name), BS);
      end;
    end;
    for I := 0 to ClassMap.Count - 1 do
    begin
      C := TMClass(ClassMap.Objects[I]);
      K := Names.IndexOf(C.UnitKey + '|' + C.UName);
      if K < 0 then Continue;
      BS := TCIBrowseSym(Names.Objects[K]);
      Depth := 0;
      A := BS.Ancestor;
      while A <> nil do
      begin
        if not Options.OutsideAncestors and not A.UnitInfo.InProject then Break;
        Inc(Depth);
        C.AncestorNames.Add(AnsiUpperCase(A.Name));
        if SameText(A.Name, 'TObject') then Break;
        A := A.Ancestor;
      end;
      { TObject itself when the chain ends below it: an ancestor whose source was not found, or a
        class declared without one }
      if Options.OutsideAncestors and ((Depth = 0) or (C.AncestorNames.IndexOf('TOBJECT') < 0)) and
        not SameText(C.Name, 'TObject') and C.IsClass then
      begin
        if (A = nil) or not SameText(A.Name, 'TObject') then Inc(Depth);
      end;
      if C.IsClass then C.Node.SetValue(miDIT, Depth);
    end;
  finally
    Names.Free;
    Model.Free;
  end;
end;

{ what needs every unit: the child classes, the units that use a unit, CBO both ways, then the
  aggregates }
procedure TRunner.Finish;
var
  I, K: Integer;
  C, D: TMClass;
  N: TMetricNode;
  UsesList: TStringList;
  Kids: Integer;
begin
  { NOC: the project's classes whose ancestor it is }
  for I := 0 to ClassMap.Count - 1 do
  begin
    C := TMClass(ClassMap.Objects[I]);
    Kids := 0;
    for K := 0 to ClassMap.Count - 1 do
    begin
      D := TMClass(ClassMap.Objects[K]);
      if (D <> C) and SameText(D.Ancestor, C.Name) then Inc(Kids);
    end;
    C.Node.SetValue(miNOC, Kids);
  end;
  { CA: the project's units that use the unit }
  for I := 0 to UnitNodes.Count - 1 do
  begin
    N := TMetricNode(UnitNodes.Objects[I]);
    Kids := 0;
    for K := 0 to UnitUses.Count - 1 do
    begin
      UsesList := TStringList(UnitUses.Objects[K]);
      if (UnitUses[K] <> UnitNodes[I]) and (UsesList.IndexOf(UnitNodes[I]) >= 0) then Inc(Kids);
    end;
    N.SetValue(miCA, Kids);
  end;
  { CBO: what a class uses and what uses it, without itself and its ancestors }
  if Settings[miCBO].On then
  begin
    for I := 0 to ClassMap.Count - 1 do
    begin
      C := TMClass(ClassMap.Objects[I]);
      if C.Ancestor <> '' then C.AncestorNames.Add(AnsiUpperCase(C.Ancestor));
    end;
    for I := 0 to ClassMap.Count - 1 do
    begin
      C := TMClass(ClassMap.Objects[I]);
      for K := 0 to C.UsesSet.Count - 1 do
      begin
        D := nil;
        if ByName.IndexOf(C.UsesSet[K]) >= 0 then D := TMClass(ByName.Objects[ByName.IndexOf(C.UsesSet[K])]);
        { a descendant naming its ancestor couples neither of them }
        if (D <> nil) and (D <> C) and (C.AncestorNames.IndexOf(D.UName) < 0) then D.UsedBy.Add(C.UName);
      end;
    end;
    for I := 0 to ClassMap.Count - 1 do
    begin
      C := TMClass(ClassMap.Objects[I]);
      C.UsedBy.AddStrings(C.UsesSet);
      K := C.UsedBy.IndexOf(C.UName);
      if K >= 0 then C.UsedBy.Delete(K);
      for Kids := 0 to C.AncestorNames.Count - 1 do
      begin
        K := C.UsedBy.IndexOf(C.AncestorNames[Kids]);
        if K >= 0 then C.UsedBy.Delete(K);
      end;
      C.Node.SetValue(miCBO, C.UsedBy.Count);
    end;
  end;
end;

{ ---------------------------------------------------------------------------- }
{ aggregation }

type
  TValues = array of Double;

{ the values of a node's descendants at the nearest level where the metric is defined }
procedure Gather(N: TMetricNode; Id: TMetricId; var Vals: TValues);
var
  I: Integer;
  X: TMetricNode;
begin
  for I := 0 to N.Count - 1 do
  begin
    X := N.Child(I);
    if X.Level in MetricDefs[Id].Levels then
    begin
      if Id in X.Has then
      begin
        SetLength(Vals, Length(Vals) + 1);
        Vals[High(Vals)] := X.Values[Id];
      end;
    end
    else
      Gather(X, Id, Vals);
  end;
end;

{ a node's value of every metric that is not defined at its level, from those below it }
procedure Aggregate(N: TMetricNode; const Settings: TMetricSettings);
var
  I: Integer;
  M: TMetricId;
  Vals: TValues;
  V: Double;
begin
  for I := 0 to N.Count - 1 do Aggregate(N.Child(I), Settings);
  for M := Low(TMetricId) to High(TMetricId) do
  begin
    if not Settings[M].On or (N.Level in MetricDefs[M].Levels) then Continue;
    SetLength(Vals, 0);
    Gather(N, M, Vals);
    if Length(Vals) = 0 then Continue;
    V := Vals[0];
    for I := 1 to High(Vals) do
      case Settings[M].Aggr of
        maSum, maAverage: V := V + Vals[I];
        maMaximum: if Vals[I] > V then V := Vals[I];
        maMinimum: if Vals[I] < V then V := Vals[I];
      end;
    if Settings[M].Aggr = maAverage then V := V / Length(Vals);
    N.SetValue(M, V);
  end;
end;

{ the values of the metrics that are off are dropped }
procedure DropOff(N: TMetricNode; const Settings: TMetricSettings);
var
  I: Integer;
  M: TMetricId;
begin
  for M := Low(TMetricId) to High(TMetricId) do
    if not Settings[M].On then Exclude(N.Has, M);
  for I := 0 to N.Count - 1 do DropOff(N.Child(I), Settings);
end;

{ ---------------------------------------------------------------------------- }
{ TMetricsRun }

constructor TMetricsRun.Create(CI: TCodeInsight);
begin
  inherited Create;
  FCI := CI;
end;

function TMetricsRun.Run(Files: TStrings; const Title: string; const Settings: TMetricSettings;
  const Options: TMetricOptions; OnProgress: TMetricProgress): TMetricNode;
var
  R: TRunner;
  I: Integer;
  Cancel: Boolean;
begin
  Result := nil;
  FErrors := 0;
  FLastError := '';
  R := TRunner.Create;
  try
    R.CI := FCI;
    R.Settings := Settings;
    R.Options := Options;
    R.Root := TMetricNode.Create(nil, mlProject, Title);
    try
      Cancel := False;
      for I := 0 to Files.Count - 1 do
      begin
        if Assigned(OnProgress) then
        begin
          OnProgress(I, Files.Count, ChangeFileExt(ExtractFileName(Files[I]), ''), Cancel);
          if Cancel then Abort;
        end;
        R.DoUnit(Files[I]);
      end;
      if Settings[miDIT].On or Settings[miCBO].On then
      begin
        if Assigned(OnProgress) then
        begin
          OnProgress(Files.Count, Files.Count, '', Cancel);
          if Cancel then Abort;
        end;
        R.Ancestry(Files);
      end;
      R.Finish;
      Aggregate(R.Root, Settings);
      DropOff(R.Root, Settings);
      FErrors := R.Errors;
      FLastError := R.LastError;
      Result := R.Root;
    except
      R.Root.Free;
      if not (ExceptObject is EAbort) then raise;
    end;
  finally
    R.Free;
  end;
end;

end.
