{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdTodo;

{ D7 Studio - the To-Do List (View | To-Do List): Delphi 7's.
  The items are the TODO / DONE comments of the project's
  files, of the open files and of the project's To-Do file (Add puts its items there); the list
  shows those its filters let through, in Delphi's sort order. Kept in [ToDo List] of D7
  Studio's settings under Delphi's names (its desktop's SortOrder, ShowHints, ShowChecked; its
  registry's HiddenCategories, HiddenOwners, HiddenItems - read from the registry, D7 Studio's
  key in Delphi's layout, while the settings have none) and the table options of Copy As | HTML
  Table. }

interface

uses
  Windows, SysUtils, Classes, IniFiles;

type
  { Delphi's TToDoSortOrder: the Sort submenu's items (their Tag) }
  TSdTodoSort = (tsActionItem, tsStatus, tsType, tsPriority, tsModule, tsOwner, tsCategory);
  { the Filter submenu: Categories, Owners, Item Types (Delphi's TFilterType) }
  TSdTodoFilter = (tfCategory, tfOwner, tfKind);

  TSdTodoTable = class;

  { an item: a comment "TODO|DONE [priority] [-oOwner] [-cCategory] : text" (Delphi's
    TSourceToDoItem). Delphi keeps where each part lies in the comment - Edit and Delete change
    those ranges of the source; positions in Comment are 1-based, an end is the index after the
    part, 0 = the part is not there. }
  TSdTodoItem = class
  public
    Comment: string; // with its delimiters (a // one with its line break)
    Pos: Integer; // its 0-based offset in the file's text
    KeyStart, KeyEnd: Integer; // TODO / DONE
    TextStart, TextEnd: Integer;
    PrioStart, PrioEnd: Integer; // the number
    OwnerStart, OwnerEnd: Integer; // "-o" and the name
    CatStart, CatEnd: Integer; // "-c" and the name
    Text: string; // the text as the list shows it (Delphi's TrimText)
    Owner, Category: string; // as written after -o / -c (Delphi does not trim them)
    Priority: Integer; // 0: none
    Done: Boolean;
    FileName: string;
    Line: Integer; // 1-based, of TODO / DONE
    InProject, HasView: Boolean; // a file of the project, a file open in the editor
    InTodoFile: Boolean; // an item of the project's To-Do file (Add puts them there)
    { an expert's item (IOTAToDoServices, SdOtaToDo): its INTAToDoItem, and what it said when it
      was collected - Comment is its GetText (TextStart 1, TextEnd after it); nil: a comment }
    Ext: IInterface;
    ExtKind, ExtModule: string; // its GetKind, GetModuleName
    ExtData: Integer; // its GetData
    ExtValid, ExtEditable: Boolean; // its IsValid, CanEdit
    ExtNoDraw: Boolean; // its DrawImage raised: not called again
    function RawText: string; // the text as it is in the comment (Edit shows it)
    function Module: string; // Delphi's GetModuleName: the file, '' in the To-Do file
    function Kind: string; // Delphi's GetKind (the Type sort)
    { the Module column: the file's name of a comment, an expert's module as it gave it }
    function ModuleCaption: string;
    { what the sort's ties of one source file compare: the comment's place, an expert's GetData }
    function SortData: Integer;
    { a copy that outlives the list (the list's items are made anew at every refresh) }
    function Clone: TSdTodoItem;
  end;

  TSdTodoList = class
  private
    FItems: TList; // every item found
    FShown: TList; // those the filters let through, sorted
    FHidden: array[TSdTodoFilter] of TStringList; // the values not shown
    FValues: array[TSdTodoFilter] of TStringList; // the values the items have
    FSort: TSdTodoSort;
    FDir: array[TSdTodoSort] of Integer; // 1 ascending, -1 descending
    FShowCompleted: Boolean;
    FShowHints: Boolean;
    FHiddenCount, FPending: Integer;
    FTable: TSdTodoTable;
    function GetItem(Index: Integer): TSdTodoItem;
    function GetAscending: Boolean;
    function KindShown(Item: TSdTodoItem): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    { the TODO / DONE comments of a file's text (Todo: the project's To-Do file) }
    procedure Scan(const FileName, Text: string; InProject, HasView, Todo: Boolean);
    { the experts' items (Ext set; the list owns them from then on); taken out and freed - their
      interfaces released - all of them, or one. Collate shows the list as it is then. }
    procedure AddExternal(Item: TSdTodoItem);
    procedure ClearExternal;
    procedure RemoveExternal(Item: TSdTodoItem);
    function ExternalCount: Integer;
    function ExternalItem(Index: Integer): TSdTodoItem;
    { the categories / owners of the items shown (Delphi's ListValues: the Add / Edit dialog) }
    procedure ShownValues(Filter: TSdTodoFilter; Values: TStrings);
    { filters and sorts again (Delphi's Collate) }
    procedure Collate;
    { Delphi's SetSortOrder: another order is taken with its last direction, the same one again
      turns its direction round }
    procedure SetSort(Order: TSdTodoSort);
    procedure SetShowCompleted(Value: Boolean);
    { the filter dialog: the values of the items shown and the hidden ones, Shown: a Boolean each }
    procedure GetFilter(Filter: TSdTodoFilter; Values: TStrings; Shown: TList);
    procedure SetHidden(Filter: TSdTodoFilter; Hidden: TStrings);
    procedure Load(Ini: TCustomIniFile);
    procedure Save(Ini: TCustomIniFile);
    function Count: Integer;
    property Items[Index: Integer]: TSdTodoItem read GetItem; default;
    property SortOrder: TSdTodoSort read FSort;
    property Ascending: Boolean read GetAscending;
    property ShowCompleted: Boolean read FShowCompleted;
    property ShowHints: Boolean read FShowHints write FShowHints;
    property HiddenCount: Integer read FHiddenCount;
    property Pending: Integer read FPending;
    { Copy As | HTML Table's table (Table Properties) }
    property Table: TSdTodoTable read FTable;
  end;

  { Copy As | HTML Table: Delphi's THTMLTable and its six THTMLColumns (Table Properties) }
  TSdTodoColType = (ctActionItem, ctStatus, ctPriority, ctOwner, ctCategory, ctModule);
  TSdTodoVAlign = (vaTop, vaMiddle, vaBottom, vaBaseline);

  TSdTodoColumn = record
    Title: string;
    Align: TAlignment; // taLeftJustify, taRightJustify, taCenter
    VAlign: TSdTodoVAlign;
    Wrap, Visible: Boolean;
    Height: Integer; // pixels, 0: none
    Width: Integer; // percent
    FontSize: Integer; // HTML's 1..7, 3 the default
    FontFace: string; // '' the default
    FontColor: Integer; // a TColor, 0 (black) the default
    Bold, Italic: Boolean;
  end;

  TSdTodoTable = class
  public
    Caption: string; // the project's file name (Delphi sets it with the project)
    Align: TAlignment;
    BorderWidth, CellSpacing, CellPadding, Width: Integer;
    BackgroundColor: Integer; // a TColor
    Columns: array[TSdTodoColType] of TSdTodoColumn;
    constructor Create;
    procedure Assign(Source: TSdTodoTable);
    procedure Reset; // Delphi's defaults
    { Delphi's GenerateTable: the items shown, in their order }
    function Html(List: TSdTodoList): string;
    procedure Load(Ini: TCustomIniFile);
    procedure Save(Ini: TCustomIniFile);
  end;

const
  TodoSection = 'ToDo List';
  { Delphi's Status column (its Status array): pending, completed }
  TodoStatus: array[Boolean] of string = (
    'Pending',
    'Completed'
  );
  TodoColTitles: array[TSdTodoColType] of string = (
    'Action Item',
    'Status',
    'Priority',
    'Owner',
    'Category',
    'Module'
  );
  { Delphi's item kinds (_ikHasView, _ikInProject, _ikProjectItem): the Item Types filter }
  TodoKindOpen = 'Open source files';
  TodoKindProject = 'Current project source files';
  TodoKindFile = 'Project To-Do file';
  TodoFilterNames: array[TSdTodoFilter] of string = (
    'HiddenCategories',
    'HiddenOwners',
    'HiddenItems'
  );
  TodoExt = '.todo'; // the project's To-Do file, "{%ToDo 'Project1.todo'}" in the .dpr

{ Delphi's FormatItem: "TODO 2 -oOwner -cCategory : text" (DONE when done) - the priority, the
  owner and the category only when given, no quotes; the text without blanks at its end, and a
  line break after it when it has several lines }
function TodoText(Done: Boolean; Priority: Integer; const Owner, Category, Text: string): string;
{ Delphi's TrimText: line breaks as blanks, without tabs and blanks at the ends }
function TodoTrimText(const S: string): string;
{ Edit (Delphi's SetText, SetOwner, SetCategory, SetPriority, SetChecked): the comment with the
  parts that changed replaced - a part that is not there is put after TODO / DONE (priority,
  category, owner in that order), an empty one is taken out with its -o / -c }
function TodoEditComment(Item: TSdTodoItem; Done: Boolean; Priority: Integer; const Owner, Category,
  Text: string): string;
{ where the item's comment is now in Text (0-based): at its place, else the nearest copy of it;
  -1 when the text has it no more }
function TodoFindComment(const Text: string; Item: TSdTodoItem): Integer;
{ the project's To-Do file: the full path of the "%ToDo 'X.todo'" entry (in braces) of its source
  (Delphi's entry of a project file that is no unit), '' when there is none }
function TodoFileOf(const ProjectSource, ProjectDir: string): string;
{ the image the To-Do List shows for an item of D7 Studio's own, an index of SdIcons' IconList
  (Delphi's three: a unit of the project, another open file, the project's To-Do file); -1 for an
  expert's item, which draws its own (INTAToDoItem.DrawImage) }
function TodoImageIndex(Item: TSdTodoItem): Integer;

{ (the entry itself is added by SdFormSrc.DprAddTodoFile) }

implementation

uses
  Graphics, StrUtils, SdSettings, SdIcons;

{ --- TSdTodoItem --- }

function TSdTodoItem.RawText: string;
begin
  Result := Copy(Comment, TextStart, TextEnd - TextStart);
end;

function TSdTodoItem.Module: string;
begin
  if Ext <> nil then
    Result := ExtModule
  else if InTodoFile then
    Result := ''
  else
    Result := FileName;
end;

function TSdTodoItem.Kind: string;
begin
  if Ext <> nil then
    Result := ExtKind
  else if InTodoFile then
    Result := TodoKindFile
  else
    Result := '$Source';
end;

function TSdTodoItem.ModuleCaption: string;
begin
  if Ext <> nil then
    Result := ExtModule
  else
    Result := ExtractFileName(Module);
end;

function TSdTodoItem.SortData: Integer;
begin
  if Ext <> nil then
    Result := ExtData
  else
    Result := Pos;
end;

function TSdTodoItem.Clone: TSdTodoItem;
begin
  Result := TSdTodoItem.Create;
  Result.Comment := Comment;
  Result.Pos := Pos;
  Result.KeyStart := KeyStart;
  Result.KeyEnd := KeyEnd;
  Result.TextStart := TextStart;
  Result.TextEnd := TextEnd;
  Result.PrioStart := PrioStart;
  Result.PrioEnd := PrioEnd;
  Result.OwnerStart := OwnerStart;
  Result.OwnerEnd := OwnerEnd;
  Result.CatStart := CatStart;
  Result.CatEnd := CatEnd;
  Result.Text := Text;
  Result.Owner := Owner;
  Result.Category := Category;
  Result.Priority := Priority;
  Result.Done := Done;
  Result.FileName := FileName;
  Result.Line := Line;
  Result.InProject := InProject;
  Result.HasView := HasView;
  Result.InTodoFile := InTodoFile;
  Result.Ext := Ext;
  Result.ExtKind := ExtKind;
  Result.ExtModule := ExtModule;
  Result.ExtData := ExtData;
  Result.ExtValid := ExtValid;
  Result.ExtEditable := ExtEditable;
  Result.ExtNoDraw := ExtNoDraw;
end;

{ --- the comments: Delphi's TCommentScanner and ParseComment --- }

type
  TTodoTok = (ttNone, ttWord, ttNumber, ttDash, ttColon);

{ the next token of a comment from P (1-based): blanks, control characters, parentheses, * / and
  braces start none; a word runs to a blank, -, :, @ or a character above 127; a number is a word
  that starts with a digit }
function NextTodoTok(const S: string; var P: Integer; out TS, TE: Integer): TTodoTok;
begin
  while (P <= Length(S)) and (S[P] in [#0 .. ' ', '(', ')', '*', '/', '{', '}']) do
    Inc(P);
  TS := P;
  TE := P;
  if P > Length(S) then
  begin
    Result := ttNone;
    Exit;
  end;
  case S[P] of
    '-':
      Result := ttDash;
    ':':
      Result := ttColon;
    '0' .. '9':
      Result := ttNumber;
  else
    Result := ttWord;
  end;
  Inc(P);
  if Result in [ttWord, ttNumber] then
    while (P <= Length(S)) and not(S[P] in [#0 .. ' ', '-', ':', '@', #128 .. #255]) do
      Inc(P);
  TE := P;
end;

{ Delphi's ParseComment: "TODO|DONE (words | number | -o... | -c...)* : text" - the first word
  TODO or DONE (any case), a number before the options the priority, -o / -c (any case) an owner /
  category that runs over the words up to the next - or :, the colon required; the text from the
  first token after the colon to the comment's end (without its closing brace or *), a //
  comment's with its line break). Nil when the comment is no item. }
function ParseTodoComment(const S: string): TSdTodoItem;
var
  P, TS, TE, State, Close, V: Integer;
  K: TTodoTok;
  Key: string;
begin
  Result := nil;
  P := 1;
  if NextTodoTok(S, P, TS, TE) <> ttWord then
    Exit;
  Key := Copy(S, TS, TE - TS);
  if not SameText(Key, 'TODO') and not SameText(Key, 'DONE') then
    Exit;
  Result := TSdTodoItem.Create;
  try
    Result.Comment := S;
    Result.KeyStart := TS;
    Result.KeyEnd := TE;
    Result.Done := SameText(Key, 'DONE');
    State := 0; // 0 ignored words, 1 owner, 2 category
    repeat
      K := NextTodoTok(S, P, TS, TE);
      case K of
        ttNone:
          Abort; // no colon: no item
        ttDash:
          if (TS < Length(S)) and (S[TS + 1] in ['o', 'O']) then
          begin
            State := 1;
            Result.OwnerStart := TS;
            Result.OwnerEnd := TE;
          end
          else if (TS < Length(S)) and (S[TS + 1] in ['c', 'C']) then
          begin
            State := 2;
            Result.CatStart := TS;
            Result.CatEnd := TE;
          end
          else
            State := 0;
        ttNumber, ttWord:
          if State = 1 then
            Result.OwnerEnd := TE
          else if State = 2 then
            Result.CatEnd := TE
          else if K = ttNumber then
          begin
            Result.PrioStart := TS;
            Result.PrioEnd := TE;
          end;
      end;
    until K = ttColon;
    { the text: to the closing delimiter; none - at the delimiter (a // comment's: its line break) }
    if Copy(S, 1, 1) = '{' then
      Close := 1
    else if Copy(S, 1, 2) = '(*' then
      Close := 2
    else
      Close := 0;
    Result.TextEnd := Length(S) + 1 - Close;
    if NextTodoTok(S, P, TS, TE) <> ttNone then
      Result.TextStart := TS
    else if Close > 0 then
      Result.TextStart := Result.TextEnd
    else
    begin
      Result.TextStart := Result.TextEnd;
      while (Result.TextStart > 1) and (S[Result.TextStart - 1] in [#10, #13]) do
        Dec(Result.TextStart);
    end;
    if Result.TextStart > Result.TextEnd then
      Result.TextStart := Result.TextEnd;
    Result.Text := TodoTrimText(Result.RawText);
    if Result.OwnerStart > 0 then
      Result.Owner := Copy(S, Result.OwnerStart + 2, Result.OwnerEnd - Result.OwnerStart - 2);
    if Result.CatStart > 0 then
      Result.Category := Copy(S, Result.CatStart + 2, Result.CatEnd - Result.CatStart - 2);
    { Delphi's GetPriority: the number's low byte when it is below 6 }
    if (Result.PrioStart > 0) and TryStrToInt(Copy(S, Result.PrioStart, Result.PrioEnd - Result.PrioStart), V) and
      (V and $FF < 6) then
      Result.Priority := V and $FF;
  except
    FreeAndNil(Result);
  end;
end;

{ each line break of S (CRLF, CR, LF) a blank }
function BreaksToBlanks(const S: string): string;
begin
  Result := StringReplace(StringReplace(StringReplace(S, #13#10, ' ', [rfReplaceAll]), #13, ' ',
    [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
end;

function TodoTrimText(const S: string): string;
begin
  Result := StringReplace(Trim(BreaksToBlanks(S)), #9, '', [rfReplaceAll]);
  Result := Trim(Result);
end;

function TodoText(Done: Boolean; Priority: Integer; const Owner, Category, Text: string): string;
var
  T: string;
begin
  if Done then
    Result := 'DONE '
  else
    Result := 'TODO ';
  if Priority <> 0 then
    Result := Result + IntToStr(Priority) + ' ';
  if Owner <> '' then
    Result := Result + '-o' + Owner + ' ';
  if Category <> '' then
    Result := Result + '-c' + Category + ' ';
  T := TrimRight(Text);
  Result := Result + ': ' + T;
  if Pos(#13, T) > 0 then
    Result := Result + #13#10;
end;

function TodoEditComment(Item: TSdTodoItem; Done: Boolean; Priority: Integer; const Owner, Category,
  Text: string): string;
var
  Starts, Ends: array[0 .. 5] of Integer;
  Repls: array[0 .. 5] of string;
  N, I, J, Best: Integer;
  Ins: string;

  procedure Change(AStart, AEnd: Integer; const Repl: string);
  begin
    Starts[N] := AStart;
    Ends[N] := AEnd;
    Repls[N] := Repl;
    Inc(N);
  end;

  { an owner or category: its range replaced (by nothing when it is cleared), or one put after TODO }
  procedure Option(AStart, AEnd: Integer; const Flag, Old, New: string; var Added: string);
  var
    V: string;
  begin
    if New = Old then
      Exit;
    if New = '' then
      V := ''
    else
      V := Flag + New;
    if AStart > 0 then
      Change(AStart, AEnd, V)
    else if V <> '' then
      Added := ' ' + V;
  end;

  { a text as it can stand in this comment, which must not end inside it: a // comment ends with
    its line - the text's line breaks become blanks, and the comment's own break (Tail: the text's
    end) stays where it was; a brace comment ends at the first closing brace, a parenthesis-star
    comment at the first star-parenthesis }
  function Fit(const S: string; Tail: Boolean): string;
  var
    E: Integer;
    Raw: string;
  begin
    Result := S;
    if Copy(Item.Comment, 1, 2) = '//' then
    begin
      E := Length(Result);
      if Tail then
        while (E > 0) and (Result[E] in [#10, #13]) do Dec(E);
      SetLength(Result, E);
      Result := BreaksToBlanks(Result);
      if Tail then
      begin
        Raw := Item.RawText;
        E := Length(Raw);
        while (E > 0) and (Raw[E] in [#10, #13]) do Dec(E);
        Result := Result + Copy(Raw, E + 1, MaxInt);
      end;
    end
    else if Copy(Item.Comment, 1, 1) = '{' then
      Result := StringReplace(Result, '}', ')', [rfReplaceAll])
    else
      Result := StringReplace(Result, '*)', '* )', [rfReplaceAll]);
  end;

var
  InsOwner, InsCat, InsPrio, T: string;
begin
  N := 0;
  InsOwner := '';
  InsCat := '';
  InsPrio := '';
  T := Fit(Text, True);
  if T <> Item.RawText then
    Change(Item.TextStart, Item.TextEnd, T);
  Option(Item.OwnerStart, Item.OwnerEnd, '-o', Item.Owner, Fit(Owner, False), InsOwner);
  Option(Item.CatStart, Item.CatEnd, '-c', Item.Category, Fit(Category, False), InsCat);
  if Priority <> Item.Priority then
    if Item.PrioStart > 0 then
    begin
      if Priority = 0 then
        Change(Item.PrioStart, Item.PrioEnd, '')
      else
        Change(Item.PrioStart, Item.PrioEnd, IntToStr(Priority));
    end
    else if Priority <> 0 then
      InsPrio := ' ' + IntToStr(Priority);
  if Done <> Item.Done then
    if Done then
      Change(Item.KeyStart, Item.KeyEnd, 'DONE')
    else
      Change(Item.KeyStart, Item.KeyEnd, 'TODO');
  { Delphi inserts each one right after TODO, the owner first: priority, category, owner }
  Ins := InsPrio + InsCat + InsOwner;
  if Ins <> '' then
    Change(Item.KeyEnd, Item.KeyEnd, Ins);
  { from the last part to the first: the positions of the others stay right }
  Result := Item.Comment;
  for I := 0 to N - 1 do
  begin
    Best := -1;
    for J := 0 to N - 1 do
      if (Starts[J] >= 0) and ((Best < 0) or (Starts[J] > Starts[Best])) then
        Best := J;
    Result := Copy(Result, 1, Starts[Best] - 1) + Repls[Best] + Copy(Result, Ends[Best], MaxInt);
    Starts[Best] := -1;
  end;
end;

function TodoFindComment(const Text: string; Item: TSdTodoItem): Integer;
var
  P, Best: Integer;
begin
  if Copy(Text, Item.Pos + 1, Length(Item.Comment)) = Item.Comment then
  begin
    Result := Item.Pos;
    Exit;
  end;
  Result := -1;
  Best := MaxInt;
  P := Pos(Item.Comment, Text);
  while P > 0 do
  begin
    if Abs(P - 1 - Item.Pos) < Best then
    begin
      Best := Abs(P - 1 - Item.Pos);
      Result := P - 1;
    end;
    P := PosEx(Item.Comment, Text, P + 1);
  end;
end;

function TodoFileOf(const ProjectSource, ProjectDir: string): string;
var
  P, E: Integer;
begin
  Result := '';
  P := Pos('{%TODO ', UpperCase(ProjectSource));
  if P = 0 then
    Exit;
  P := P + 7;
  while (P <= Length(ProjectSource)) and (ProjectSource[P] = ' ') do
    Inc(P);
  if (P > Length(ProjectSource)) or (ProjectSource[P] <> '''') then
    Exit;
  E := P + 1;
  while (E <= Length(ProjectSource)) and (ProjectSource[E] <> '''') do
    Inc(E);
  Result := Copy(ProjectSource, P + 1, E - P - 1);
  if Result = '' then
    Exit;
  if not((Copy(Result, 2, 1) = ':') or (Copy(Result, 1, 1) = '\')) then
    Result := IncludeTrailingPathDelimiter(ProjectDir) + Result;
  Result := ExpandFileName(Result);
end;

function TodoImageIndex(Item: TSdTodoItem): Integer;
begin
  if Item.Ext <> nil then
    Result := -1
  else if Item.InTodoFile then
    Result := IconIndex(iiTodoList)
  else if Item.InProject then
    Result := IconIndex(iiUnit)
  else
    Result := IconIndex(iiFile);
end;

{ --- TSdTodoList --- }
constructor TSdTodoList.Create;
var
  F: TSdTodoFilter;
  S: TSdTodoSort;
begin
  inherited Create;
  FItems := TList.Create;
  FShown := TList.Create;
  { Delphi's hash tables of the values compare without case (AnsiCompareText) }
  for F := Low(F) to High(F) do
  begin
    FHidden[F] := TStringList.Create;
    FValues[F] := TStringList.Create;
    FValues[F].Sorted := True;
    FValues[F].Duplicates := dupIgnore;
  end;
  { Delphi's: sorted by module, every order ascending; completed items and hints shown }
  FSort := tsModule;
  for S := Low(S) to High(S) do
    FDir[S] := 1;
  FShowCompleted := True;
  FShowHints := True;
  FTable := TSdTodoTable.Create;
end;

destructor TSdTodoList.Destroy;
var
  F: TSdTodoFilter;
begin
  Clear;
  for F := Low(F) to High(F) do
  begin
    FHidden[F].Free;
    FValues[F].Free;
  end;
  FTable.Free;
  FShown.Free;
  FItems.Free;
  inherited;
end;

procedure TSdTodoList.Clear;
var
  I: Integer;
begin
  FShown.Clear;
  for I := 0 to FItems.Count - 1 do
    TObject(FItems[I]).Free;
  FItems.Clear;
end;

{ the comments of a file's text: braces, (* *) and // (with its line break; to the end of the text
  on its last line), not in strings; comments of 4096 characters or more and unterminated ones
  are none (Delphi's scanner). In the To-Do file every comment counts. }
procedure TSdTodoList.Scan(const FileName, Text: string; InProject, HasView, Todo: Boolean);
var
  I, J, N, Line, LineAt: Integer;
  It: TSdTodoItem;
  K: Integer;
begin
  N := Length(Text);
  I := 1;
  Line := 1;
  LineAt := 1;
  J := 0;
  while I <= N do
  begin
    if (Text[I] = '''') and not Todo then
    begin
      Inc(I);
      while (I <= N) and not(Text[I] in ['''', #10, #13]) do
        Inc(I);
      Inc(I);
      Continue;
    end;
    if Text[I] = '{' then
    begin
      J := I + 1;
      while (J <= N) and (Text[J] <> '}') do
        Inc(J);
      if J > N then
        Break;
      Inc(J);
    end
    else if (Text[I] = '(') and (I < N) and (Text[I + 1] = '*') then
    begin
      J := I + 2;
      while (J < N) and not((Text[J] = '*') and (Text[J + 1] = ')')) do
        Inc(J);
      if J >= N then
        Break;
      Inc(J, 2);
    end
    else if (Text[I] = '/') and (I < N) and (Text[I + 1] = '/') then
    begin
      J := I + 2;
      while (J <= N) and not(Text[J] in [#10, #13]) do
        Inc(J);
      if (J <= N) and (Text[J] = #13) then
        Inc(J);
      if (J <= N) and (Text[J] = #10) then
        Inc(J);
    end
    else
    begin
      Inc(I);
      Continue;
    end;
    if J - I < 4096 then
    begin
      It := ParseTodoComment(Copy(Text, I, J - I));
      if It <> nil then
      begin
        FItems.Add(It);
        It.Pos := I - 1;
        { the line of TODO / DONE: lines end in CRLF, LF or a lone CR (as the lexer counts them) }
        for K := LineAt to I - 1 + It.KeyStart - 1 do
          if (Text[K] = #10) or ((Text[K] = #13) and ((K = N) or (Text[K + 1] <> #10))) then
            Inc(Line);
        LineAt := I + It.KeyStart - 1;
        It.Line := Line;
        It.FileName := FileName;
        It.InProject := InProject;
        It.HasView := HasView;
        It.InTodoFile := Todo;
      end;
    end;
    I := J;
  end;
end;

procedure TSdTodoList.AddExternal(Item: TSdTodoItem);
begin
  FItems.Add(Item);
end;

procedure TSdTodoList.ClearExternal;
var
  I: Integer;
  It: TSdTodoItem;
begin
  for I := FItems.Count - 1 downto 0 do
  begin
    It := TSdTodoItem(FItems[I]);
    if It.Ext <> nil then
    begin
      FItems.Delete(I);
      FShown.Remove(It);
      It.Free;
    end;
  end;
end;

procedure TSdTodoList.RemoveExternal(Item: TSdTodoItem);
begin
  if FItems.Remove(Item) < 0 then
    Exit;
  FShown.Remove(Item);
  Item.Free;
end;

function TSdTodoList.ExternalCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FItems.Count - 1 do
    if TSdTodoItem(FItems[I]).Ext <> nil then
      Inc(Result);
end;

function TSdTodoList.ExternalItem(Index: Integer): TSdTodoItem;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    Result := TSdTodoItem(FItems[I]);
    if Result.Ext <> nil then
    begin
      if Index = 0 then
        Exit;
      Dec(Index);
    end;
  end;
  Result := nil;
end;

procedure TSdTodoList.ShownValues(Filter: TSdTodoFilter; Values: TStrings);
begin
  Values.Assign(FValues[Filter]);
end;

function TSdTodoList.Count: Integer;
begin
  Result := FShown.Count;
end;

function TSdTodoList.GetItem(Index: Integer): TSdTodoItem;
begin
  Result := TSdTodoItem(FShown[Index]);
end;

function TSdTodoList.GetAscending: Boolean;
begin
  Result := FDir[FSort] = 1;
end;

{ Delphi's InternalAdd: a source item is shown when one of its kinds is - open in the editor
  (Open source files) or a file of the project (Current project source files); an expert's
  item while its own kind is }
function TSdTodoList.KindShown(Item: TSdTodoItem): Boolean;
begin
  if Item.Ext <> nil then
    Result := FHidden[tfKind].IndexOf(Item.ExtKind) < 0
  else if Item.InTodoFile then
    Result := FHidden[tfKind].IndexOf(TodoKindFile) < 0
  else
    Result := (Item.HasView and (FHidden[tfKind].IndexOf(TodoKindOpen) < 0)) or
      (Item.InProject and (FHidden[tfKind].IndexOf(TodoKindProject) < 0));
end;

var
  SortList: TSdTodoList; // the list being sorted (TList.Sort takes a plain function)

{ Delphi's SortCompare (the texts as the comments have them): the chosen order in its direction
  (the module: the file's path; the type: source files before the To-Do file); a priority of 0
  (none) after 5; the same module by position when both items are of the kind '$Source' (an
  expert's by its GetData, as Delphi compares them); the same value by the text, in the
  direction of Action Item }
function CompareItems(P1, P2: Pointer): Integer;
var
  A, B: TSdTodoItem;

  function Prio(Item: TSdTodoItem): Integer;
  begin
    Result := Item.Priority;
    if Result = 0 then
      Result := 6;
  end;

begin
  A := TSdTodoItem(P1);
  B := TSdTodoItem(P2);
  with SortList do
  begin
    case FSort of
      tsActionItem:
        Result := AnsiCompareStr(A.RawText, B.RawText);
      tsStatus:
        Result := Ord(A.Done) - Ord(B.Done);
      tsType:
        Result := AnsiCompareStr(A.Kind, B.Kind);
      tsPriority:
        Result := Prio(A) - Prio(B);
      tsModule:
        Result := AnsiCompareStr(A.Module, B.Module);
      tsOwner:
        Result := AnsiCompareStr(A.Owner, B.Owner);
    else
      Result := AnsiCompareStr(A.Category, B.Category);
    end;
    Result := Result * FDir[FSort];
    { the same source file: in the file's order }
    if (Result = 0) and (FSort = tsModule) and (A.Kind = '$Source') and (B.Kind = '$Source') then
      Result := A.SortData - B.SortData;
    if (Result = 0) and (FSort <> tsActionItem) then
      Result := AnsiCompareStr(A.RawText, B.RawText) * FDir[tsActionItem];
  end;
end;

{ Delphi's Collate and InternalAdd: an item is shown unless it is done while completed items are
  not shown, or its category, its owner or all of its kinds are hidden (an empty category or
  owner is never hidden). The filters offer the categories and owners of the items shown (and
  the hidden ones), always the three kinds, and the kinds of the experts' items (Delphi's
  "Origin"). }
procedure TSdTodoList.Collate;
var
  I: Integer;
  It: TSdTodoItem;
begin
  FShown.Clear;
  FValues[tfCategory].Clear;
  FValues[tfOwner].Clear;
  FValues[tfKind].Clear;
  FValues[tfKind].Add(TodoKindOpen);
  FValues[tfKind].Add(TodoKindProject);
  FValues[tfKind].Add(TodoKindFile);
  FHiddenCount := 0;
  FPending := 0;
  for I := 0 to FItems.Count - 1 do
  begin
    It := TSdTodoItem(FItems[I]);
    if (It.Ext <> nil) and (It.ExtKind <> '') then
      FValues[tfKind].Add(It.ExtKind);
    if (It.Done and not FShowCompleted) or
      ((It.Category <> '') and (FHidden[tfCategory].IndexOf(It.Category) >= 0)) or
      ((It.Owner <> '') and (FHidden[tfOwner].IndexOf(It.Owner) >= 0)) or not KindShown(It) then
      Inc(FHiddenCount)
    else
    begin
      FShown.Add(It);
      if It.Category <> '' then
        FValues[tfCategory].Add(It.Category);
      if It.Owner <> '' then
        FValues[tfOwner].Add(It.Owner);
    end;
    if not It.Done then
      Inc(FPending);
  end;
  SortList := Self;
  try
    FShown.Sort(CompareItems);
  finally
    SortList := nil;
  end;
end;

procedure TSdTodoList.SetSort(Order: TSdTodoSort);
begin
  if Order = FSort then
    FDir[Order] := -FDir[Order]
  else
    FSort := Order;
  Collate;
end;

procedure TSdTodoList.SetShowCompleted(Value: Boolean);
begin
  if Value = FShowCompleted then
    Exit;
  FShowCompleted := Value;
  Collate;
end;

procedure TSdTodoList.GetFilter(Filter: TSdTodoFilter; Values: TStrings; Shown: TList);
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    L.Sorted := True;
    L.Duplicates := dupIgnore;
    L.AddStrings(FValues[Filter]);
    L.AddStrings(FHidden[Filter]);
    Values.Assign(L);
    Shown.Clear;
    for I := 0 to L.Count - 1 do
      Shown.Add(Pointer(Ord(FHidden[Filter].IndexOf(L[I]) < 0)));
  finally
    L.Free;
  end;
end;

procedure TSdTodoList.SetHidden(Filter: TSdTodoFilter; Hidden: TStrings);
begin
  FHidden[Filter].Assign(Hidden);
  Collate;
end;

{ the parts of S between the separators Sep into List (KeepEmpty: also the empty ones) - Delphi's
  hidden values (one string, the values joined by commas), the fields of the table's options }
procedure SplitText(const S: string; Sep: Char; List: TStrings; KeepEmpty: Boolean);
var
  Rest: string;
  P: Integer;
begin
  List.Clear;
  if S = '' then
    Exit;
  Rest := S + Sep;
  repeat
    P := Pos(Sep, Rest);
    if KeepEmpty or (P > 1) then
      List.Add(Copy(Rest, 1, P - 1));
    Delete(Rest, 1, P);
  until Rest = '';
end;

procedure TSdTodoList.Load(Ini: TCustomIniFile);
var
  V: TDelphiValues;
  F: TSdTodoFilter;
  N: Integer;
begin
  { the hidden values of the settings }
  V := TDelphiValues.Create(Ini, TodoSection);
  try
    for F := Low(F) to High(F) do
      SplitText(V.ReadString(TodoFilterNames[F], ''), ',', FHidden[F], False);
  finally
    V.Free;
  end;
  N := Ini.ReadInteger(TodoSection, 'SortOrder', Ord(tsModule));
  if (N >= Ord(Low(TSdTodoSort))) and (N <= Ord(High(TSdTodoSort))) then
    FSort := TSdTodoSort(N);
  FShowHints := Ini.ReadBool(TodoSection, 'ShowHints', True);
  FShowCompleted := Ini.ReadBool(TodoSection, 'ShowChecked', True);
  FTable.Load(Ini);
end;

procedure TSdTodoList.Save(Ini: TCustomIniFile);
var
  F: TSdTodoFilter;
  I: Integer;
  S: string;
begin
  { Delphi's WriteFilters: the hidden values joined by commas }
  for F := Low(F) to High(F) do
  begin
    S := '';
    for I := 0 to FHidden[F].Count - 1 do
      S := S + FHidden[F][I] + ',';
    Ini.WriteString(TodoSection, TodoFilterNames[F], Copy(S, 1, Length(S) - 1));
  end;
  Ini.WriteInteger(TodoSection, 'SortOrder', Ord(FSort));
  Ini.WriteBool(TodoSection, 'ShowHints', FShowHints);
  Ini.WriteBool(TodoSection, 'ShowChecked', FShowCompleted);
  FTable.Save(Ini);
end;

{ --- TSdTodoTable: Copy As | HTML Table (Delphi's THTMLTable, IDEToDoTable of proide70) --- }

const
  AlignNames: array[TAlignment] of string = (
    'LEFT',
    'RIGHT',
    'CENTER'
  );
  VAlignNames: array[TSdTodoVAlign] of string = (
    'TOP',
    'MIDDLE',
    'BOTTOM',
    'BASELINE'
  );
  DefColAlign: array[TSdTodoColType] of TAlignment = (
    taLeftJustify,
    taCenter,
    taCenter,
    taCenter,
    taCenter,
    taLeftJustify
  );
  DefColWidth: array[TSdTodoColType] of Integer = (
    45,
    5,
    5,
    15,
    15,
    15
  );

constructor TSdTodoTable.Create;
begin
  inherited Create;
  Reset;
end;

procedure TSdTodoTable.Reset;
var
  C: TSdTodoColType;
begin
  Caption := '';
  Align := taLeftJustify;
  BorderWidth := 1;
  CellSpacing := 2;
  CellPadding := 0;
  Width := 100;
  BackgroundColor := $FFFFFF;
  for C := Low(C) to High(C) do
    with Columns[C] do
    begin
      Title := TodoColTitles[C];
      Align := DefColAlign[C];
      VAlign := vaMiddle;
      Wrap := True;
      Visible := True;
      Height := 0;
      Width := DefColWidth[C];
      FontSize := 3;
      FontFace := '';
      FontColor := 0;
      Bold := False;
      Italic := False;
    end;
end;

procedure TSdTodoTable.Assign(Source: TSdTodoTable);
var
  C: TSdTodoColType;
begin
  Caption := Source.Caption;
  Align := Source.Align;
  BorderWidth := Source.BorderWidth;
  CellSpacing := Source.CellSpacing;
  CellPadding := Source.CellPadding;
  Width := Source.Width;
  BackgroundColor := Source.BackgroundColor;
  for C := Low(C) to High(C) do
    Columns[C] := Source.Columns[C];
end;

{ Delphi's colour: "#RRGGBB" in quotes, a system colour as it is now }
function HtmlColor(Color: Integer): string;
var
  C: Longint;
begin
  C := ColorToRGB(Color);
  Result := Format('"#%.2x%.2x%.2x"', [GetRValue(C), GetGValue(C), GetBValue(C)]);
end;

{ a cell, Delphi's BuildTags + TitleTags / Tags: "  <TD ALIGN=... WIDTH="n%">text</TD>" -
  ALIGN and WIDTH always, the rest when they are not the defaults; the text as it is }
function HtmlCell(const Col: TSdTodoColumn; const Tag, Text: string): string;
begin
  Result := '  <' + Tag + ' ALIGN=' + AlignNames[Col.Align];
  if Col.VAlign <> vaMiddle then
    Result := Result + ' VALIGN=' + VAlignNames[Col.VAlign];
  if not Col.Wrap then
    Result := Result + ' NOWRAP';
  if Col.Height > 0 then
    Result := Result + ' HEIGHT=' + IntToStr(Col.Height);
  Result := Result + ' WIDTH="' + IntToStr(Col.Width) + '%">';
  if (Col.FontSize <> 3) or (Col.FontFace <> '') or (Col.FontColor <> 0) then
  begin
    Result := Result + '<FONT';
    if Col.FontSize <> 3 then
      Result := Result + ' SIZE=' + IntToStr(Col.FontSize);
    if Col.FontFace <> '' then
      Result := Result + ' FACE="' + Col.FontFace + '"';
    if Col.FontColor <> 0 then
      Result := Result + ' COLOR=' + HtmlColor(Col.FontColor);
    Result := Result + '>';
  end;
  if Col.Bold then
    Result := Result + '<B>';
  if Col.Italic then
    Result := Result + '<I>';
  Result := Result + Text;
  if Col.Italic then
    Result := Result + '</I>';
  if Col.Bold then
    Result := Result + '</B>';
  if (Col.FontSize <> 3) or (Col.FontFace <> '') or (Col.FontColor <> 0) then
    Result := Result + '</FONT>';
  Result := Result + '</' + Tag + '>'#13#10;
end;

{ Delphi's GetData: a column's text of an item (the text as the comment has it), '-' for none }
function CellText(Item: TSdTodoItem; Col: TSdTodoColType): string;
begin
  case Col of
    ctActionItem:
      Result := Item.RawText;
    ctStatus:
      Result := TodoStatus[Item.Done];
    ctPriority:
      if Item.Priority = 0 then
        Result := ''
      else
        Result := IntToStr(Item.Priority);
    ctOwner:
      Result := Item.Owner;
    ctCategory:
      Result := Item.Category;
  else
    Result := Item.Module;
  end;
  if Result = '' then
    Result := '-';
end;

function TSdTodoTable.Html(List: TSdTodoList): string;
var
  C: TSdTodoColType;
  I: Integer;
begin
  Result := '<TABLE ';
  if Align <> taLeftJustify then
    Result := Result + ' ALIGN=' + AlignNames[Align];
  Result := Result + ' BGCOLOR=' + HtmlColor(BackgroundColor);
  if BorderWidth > 0 then
    Result := Result + ' BORDER=' + IntToStr(BorderWidth);
  if CellSpacing <> 2 then
    Result := Result + ' CELLSPACING=' + IntToStr(CellSpacing);
  if CellPadding > 0 then
    Result := Result + ' CELLPADDING=' + IntToStr(CellPadding);
  if Width > 0 then
    Result := Result + ' WIDTH="' + IntToStr(Width) + '%"';
  Result := Result + '>'#13#10;
  if Caption <> '' then
    Result := Result + '<CAPTION>' + Caption + '</CAPTION>'#13#10;
  Result := Result + '<TR>'#13#10;
  for C := Low(C) to High(C) do
    if Columns[C].Visible then
      Result := Result + HtmlCell(Columns[C], 'TH', Columns[C].Title);
  Result := Result + '</TR>'#13#10;
  for I := 0 to List.Count - 1 do
  begin
    Result := Result + '<TR>'#13#10;
    for C := Low(C) to High(C) do
      if Columns[C].Visible then
        Result := Result + HtmlCell(Columns[C], 'TD', CellText(List[I], C));
    Result := Result + '</TR>'#13#10;
  end;
  Result := Result + '</TABLE>'#13#10;
end;

{ Delphi means to keep the options in its registry (ToDo List\HTMLTableOptions, the table as a
  component stream) but writes an empty value: here [ToDo List] HTMLTable (alignment, border,
  spacing, padding, width, colour) and HTMLColumn0..5 (title|alignment|vertical alignment|wrap|
  height|width|visible|font size|face|colour|bold|italic). The caption is the project's. }
procedure TSdTodoTable.Load(Ini: TCustomIniFile);
var
  L: TStringList;
  C: TSdTodoColType;

  function Num(I, Default: Integer): Integer;
  begin
    if I < L.Count then
      Result := StrToIntDef(L[I], Default)
    else
      Result := Default;
  end;

  function Str(I: Integer; const Default: string): string;
  begin
    if I < L.Count then
      Result := L[I]
    else
      Result := Default;
  end;

begin
  Reset;
  L := TStringList.Create;
  try
    SplitText(Ini.ReadString(TodoSection, 'HTMLTable', ''), ',', L, True);
    Align := TAlignment(Num(0, Ord(Align)) mod 3);
    BorderWidth := Num(1, BorderWidth);
    CellSpacing := Num(2, CellSpacing);
    CellPadding := Num(3, CellPadding);
    Width := Num(4, Width);
    BackgroundColor := Num(5, BackgroundColor);
    for C := Low(C) to High(C) do
      with Columns[C] do
      begin
        SplitText(Ini.ReadString(TodoSection, 'HTMLColumn' + IntToStr(Ord(C)), ''), '|', L, True);
        { a title with a "|" of its own was split too (it is written as it is): its parts joined
          again - the other eleven fields have none }
        while L.Count > 12 do
        begin
          L[0] := L[0] + '|' + L[1];
          L.Delete(1);
        end;
        Title := Str(0, Title);
        Align := TAlignment(Num(1, Ord(Align)) mod 3);
        VAlign := TSdTodoVAlign(Num(2, Ord(VAlign)) mod 4);
        Wrap := Num(3, Ord(Wrap)) <> 0;
        Height := Num(4, Height);
        Width := Num(5, Width);
        Visible := Num(6, Ord(Visible)) <> 0;
        FontSize := Num(7, FontSize);
        FontFace := Str(8, FontFace);
        FontColor := Num(9, FontColor);
        Bold := Num(10, Ord(Bold)) <> 0;
        Italic := Num(11, Ord(Italic)) <> 0;
      end;
  finally
    L.Free;
  end;
end;

procedure TSdTodoTable.Save(Ini: TCustomIniFile);
var
  C: TSdTodoColType;
begin
  Ini.WriteString(TodoSection, 'HTMLTable', Format('%d,%d,%d,%d,%d,%d',
    [Ord(Align), BorderWidth, CellSpacing, CellPadding, Width, BackgroundColor]));
  for C := Low(C) to High(C) do
    with Columns[C] do
      Ini.WriteString(TodoSection, 'HTMLColumn' + IntToStr(Ord(C)), Format('%s|%d|%d|%d|%d|%d|%d|%d|%s|%d|%d|%d',
        [Title, Ord(Align), Ord(VAlign), Ord(Wrap), Height, Width, Ord(Visible), FontSize, FontFace, FontColor,
        Ord(Bold), Ord(Italic)]));
end;

end.
