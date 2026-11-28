{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdRichDoc;

{ D7 Studio - a document of rich text, whatever it was made of: a tree of blocks - paragraphs,
  headings, code, quotes, lists and their items, tables with their rows and cells, rules, literal
  markup - whose text is runs of styled text, with the document's links and images. SdMarkdown makes
  one of Markdown, SdRichView lays one out and shows it; PlainText gives it as plain text. The text is
  UTF-16. }

interface

uses
  Classes;

type
  TSdRunStyle = (rsBold, rsItalic, rsStrike, rsCode);
  TSdRunStyles = set of TSdRunStyle;

  { a piece of a block's text in one style. Link: the document's link it is part of (-1: none);
    Image: the document's image it shows (-1: none; Text is then the image's alternative text);
    LineBreak: the line breaks there (no text) }
  TSdRun = record
    Text: WideString;
    Styles: TSdRunStyles;
    Link: Integer;
    Image: Integer;
    LineBreak: Boolean;
  end;
  TSdRuns = array of TSdRun;

  TSdBlockKind = (bkDocument, bkParagraph, bkHeading, bkCode, bkQuote, bkList, bkItem, bkTable,
    bkRow, bkCell, bkRule, bkMarkup);

  { a block: its own text (Runs, or Text for code and markup) and the blocks inside it - a
    document's, a quote's and an item's any blocks, a list's items, a table's rows, a row's cells }
  TSdBlock = class
  private
    FChildren: TList;
    function GetChild(I: Integer): TSdBlock;
    function GetCount: Integer;
  public
    Kind: TSdBlockKind;
    Runs: TSdRuns;              // a paragraph's, a heading's, a cell's text
    Text: WideString;           // code's and markup's lines, #10 between them
    Language: string;           // code: the name of its language ('' unknown)
    Level: Integer;             // a heading's, 1 .. 6
    Anchor: WideString;         // a heading's name in links (HeadingAnchor; unique in the document)
    Ordered: Boolean;           // a list: its items numbered
    Start: Integer;             // ... from this number
    Loose: Boolean;             // ... its items' paragraphs apart, as paragraphs are
    Task: Integer;              // an item: -1 no task, 0 a task to do, 1 a task done
    Header: Boolean;            // a row: the table's head
    Align: TAlignment;          // a cell's text
    Line: Integer;              // the line of the source it begins on, 0-based (code: its first line of code;
                                // -1: not known)
    constructor Create(AKind: TSdBlockKind);
    destructor Destroy; override;
    function Add(AKind: TSdBlockKind): TSdBlock;
    procedure Remove(Child: TSdBlock);                      // out of the children, not freed
    procedure AddRun(const S: WideString; Styles: TSdRunStyles; Link: Integer = -1; Image: Integer = -1);
    procedure AddBreak;
    function RunsText: WideString;                          // the runs' text, a break as #10
    property Count: Integer read GetCount;
    property Children[I: Integer]: TSdBlock read GetChild; default;
  end;

  TSdRichDoc = class
  private
    FRoot: TSdBlock;
    FLinks: array of WideString;
    FImages: array of WideString;
  public
    constructor Create;
    destructor Destroy; override;
    function AddLink(const Target: WideString): Integer;
    function AddImage(const Source: WideString): Integer;
    function LinkCount: Integer;
    function ImageCount: Integer;
    function LinkTarget(I: Integer): WideString;            // '' for no link
    function ImageSource(I: Integer): WideString;
    { the heading whose Anchor is Name (without '#', any letter case); nil: none }
    function FindAnchor(const Name: WideString): TSdBlock;
    { every heading an Anchor of its own: HeadingAnchor, a second one of the same text '-1', ... }
    procedure MakeAnchors;
    { the document as plain text: the blocks a blank line apart, a paragraph on one line, items
      after "- " or their number, a table's cells a tab apart, code as it is, CR LF line ends }
    function PlainText: WideString;
    property Root: TSdBlock read FRoot;
  end;

{ GitHub's name of a heading in links: its text in lower case, its letters, digits, '-' and '_'
  kept, each blank a '-', the rest left out }
function HeadingAnchor(const Text: WideString): WideString;
{ the value of a hexadecimal digit, -1 for another character }
function HexDigitValue(C: WideChar): Integer;
{ '%xx' escapes of UTF-8 decoded (a link's target) }
function UrlDecodeW(const S: WideString): WideString;

implementation

uses
  Windows, SysUtils;

function HexDigitValue(C: WideChar): Integer;
begin
  case C of
    '0'..'9': Result := Ord(C) - Ord('0');
    'a'..'f': Result := Ord(C) - Ord('a') + 10;
    'A'..'F': Result := Ord(C) - Ord('A') + 10;
  else
    Result := -1;
  end;
end;

function UrlDecodeW(const S: WideString): WideString;
var
  I: Integer;
  Bytes: string;
begin
  if Pos('%', S) = 0 then
  begin
    Result := S;
    Exit;
  end;
  { the text as UTF-8, its escapes as their bytes, read back as UTF-8 }
  Bytes := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] = '%') and (I + 2 <= Length(S)) and (HexDigitValue(S[I + 1]) >= 0) and (HexDigitValue(S[I + 2]) >= 0) then
    begin
      Bytes := Bytes + Char(HexDigitValue(S[I + 1]) * 16 + HexDigitValue(S[I + 2]));
      Inc(I, 3);
    end
    else
    begin
      Bytes := Bytes + UTF8Encode(S[I]);
      Inc(I);
    end;
  end;
  Result := UTF8Decode(Bytes);
  if (Result = '') and (Bytes <> '') then Result := S;
end;

function HeadingAnchor(const Text: WideString): WideString;
var
  L: WideString;
  I: Integer;
  C: WideChar;
begin
  L := WideLowerCase(Text);
  Result := '';
  for I := 1 to Length(L) do
  begin
    C := L[I];
    if C = ' ' then Result := Result + '-'
    else if (Ord(C) >= 128) or (Char(C) in ['a'..'z', '0'..'9', '-', '_']) then Result := Result + C;
  end;
end;

{ ---------------------------------------------------------------- TSdBlock }

constructor TSdBlock.Create(AKind: TSdBlockKind);
begin
  inherited Create;
  Kind := AKind;
  Task := -1;
  Start := 1;
  Align := taLeftJustify;
  Line := -1;
  FChildren := TList.Create;
end;

destructor TSdBlock.Destroy;
var
  I: Integer;
begin
  for I := 0 to FChildren.Count - 1 do TSdBlock(FChildren[I]).Free;
  FChildren.Free;
  inherited Destroy;
end;

function TSdBlock.GetChild(I: Integer): TSdBlock;
begin
  Result := TSdBlock(FChildren[I]);
end;

function TSdBlock.GetCount: Integer;
begin
  Result := FChildren.Count;
end;

function TSdBlock.Add(AKind: TSdBlockKind): TSdBlock;
begin
  Result := TSdBlock.Create(AKind);
  FChildren.Add(Result);
end;

procedure TSdBlock.Remove(Child: TSdBlock);
begin
  FChildren.Remove(Child);
end;

procedure TSdBlock.AddRun(const S: WideString; Styles: TSdRunStyles; Link, Image: Integer);
var
  N: Integer;
begin
  N := Length(Runs);
  { text in the style of the run before it joins that run }
  if (S <> '') and (Image < 0) and (N > 0) and not Runs[N - 1].LineBreak and (Runs[N - 1].Image < 0) and
    (Runs[N - 1].Styles = Styles) and (Runs[N - 1].Link = Link) then
  begin
    Runs[N - 1].Text := Runs[N - 1].Text + S;
    Exit;
  end;
  if (S = '') and (Image < 0) then Exit;
  SetLength(Runs, N + 1);
  Runs[N].Text := S;
  Runs[N].Styles := Styles;
  Runs[N].Link := Link;
  Runs[N].Image := Image;
  Runs[N].LineBreak := False;
end;

procedure TSdBlock.AddBreak;
var
  N: Integer;
begin
  N := Length(Runs);
  SetLength(Runs, N + 1);
  Runs[N].Text := '';
  Runs[N].Styles := [];
  Runs[N].Link := -1;
  Runs[N].Image := -1;
  Runs[N].LineBreak := True;
end;

function TSdBlock.RunsText: WideString;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Runs) do
    if Runs[I].LineBreak then Result := Result + #10 else Result := Result + Runs[I].Text;
end;

{ ---------------------------------------------------------------- TSdRichDoc }

constructor TSdRichDoc.Create;
begin
  inherited Create;
  FRoot := TSdBlock.Create(bkDocument);
end;

destructor TSdRichDoc.Destroy;
begin
  FRoot.Free;
  inherited Destroy;
end;

function TSdRichDoc.AddLink(const Target: WideString): Integer;
begin
  Result := Length(FLinks);
  SetLength(FLinks, Result + 1);
  FLinks[Result] := Target;
end;

function TSdRichDoc.AddImage(const Source: WideString): Integer;
begin
  Result := Length(FImages);
  SetLength(FImages, Result + 1);
  FImages[Result] := Source;
end;

function TSdRichDoc.LinkCount: Integer;
begin
  Result := Length(FLinks);
end;

function TSdRichDoc.ImageCount: Integer;
begin
  Result := Length(FImages);
end;

function TSdRichDoc.LinkTarget(I: Integer): WideString;
begin
  if (I >= 0) and (I < Length(FLinks)) then Result := FLinks[I] else Result := '';
end;

function TSdRichDoc.ImageSource(I: Integer): WideString;
begin
  if (I >= 0) and (I < Length(FImages)) then Result := FImages[I] else Result := '';
end;

function TSdRichDoc.FindAnchor(const Name: WideString): TSdBlock;
var
  Key: WideString;

  function Search(B: TSdBlock): TSdBlock;
  var
    I: Integer;
  begin
    Result := nil;
    if (B.Kind = bkHeading) and (B.Anchor = Key) then
    begin
      Result := B;
      Exit;
    end;
    for I := 0 to B.Count - 1 do
    begin
      Result := Search(B[I]);
      if Result <> nil then Exit;
    end;
  end;

begin
  Key := WideLowerCase(Name);
  Result := Search(FRoot);
end;

procedure TSdRichDoc.MakeAnchors;
var
  Used: TStringList;

  procedure Walk(B: TSdBlock);
  var
    I, N: Integer;
    Base, A: WideString;
  begin
    if B.Kind = bkHeading then
    begin
      Base := HeadingAnchor(B.RunsText);
      A := Base;
      N := 0;
      { the names compared as UTF-8: a string list of ANSI strings keeps them whole }
      while Used.IndexOf(UTF8Encode(A)) >= 0 do
      begin
        Inc(N);
        A := Base + '-' + WideString(IntToStr(N));
      end;
      Used.Add(UTF8Encode(A));
      B.Anchor := A;
    end;
    for I := 0 to B.Count - 1 do Walk(B[I]);
  end;

begin
  Used := TStringList.Create;
  try
    Used.Sorted := True;
    Used.CaseSensitive := True;
    Walk(FRoot);
  finally
    Used.Free;
  end;
end;

function TSdRichDoc.PlainText: WideString;
var
  Out: WideString;

  procedure Line(const S: WideString);
  begin
    Out := Out + S + #13#10;
  end;

  procedure Gap;
  begin
    if (Out <> '') and (Copy(Out, Length(Out) - 3, 4) <> #13#10#13#10) then Out := Out + #13#10;
  end;

  function OneLine(const S: WideString): WideString;
  var
    I: Integer;
  begin
    Result := S;
    for I := 1 to Length(Result) do
      if Result[I] = #10 then Result[I] := ' ';
  end;

  function Lines(const S: WideString): WideString;
  var
    I: Integer;
  begin
    Result := '';
    for I := 1 to Length(S) do
      if S[I] = #10 then Result := Result + #13#10 else Result := Result + S[I];
  end;

  procedure Walk(B: TSdBlock; const Prefix: WideString);
  var
    I, K: Integer;
    P, Row: WideString;
  begin
    case B.Kind of
      bkParagraph, bkHeading:
        begin
          Gap;
          Line(Prefix + OneLine(B.RunsText));
        end;
      bkCode, bkMarkup:
        begin
          Gap;
          Line(Lines(B.Text));
        end;
      bkRule: Gap;
      bkList:
        begin
          Gap;
          for I := 0 to B.Count - 1 do
          begin
            if B.Ordered then P := WideString(IntToStr(B.Start + I)) + '. ' else P := '- ';
            if B[I].Task = 0 then P := P + '[ ] '
            else if B[I].Task = 1 then P := P + '[x] ';
            { the item's first paragraph after its mark, its other blocks after it }
            for K := 0 to B[I].Count - 1 do
              if (K = 0) and (B[I][K].Kind in [bkParagraph, bkHeading]) then
                Line(P + OneLine(B[I][K].RunsText))
              else
              begin
                if K = 0 then Line(P);
                Walk(B[I][K], '');
              end;
            if B[I].Count = 0 then Line(P);
          end;
        end;
      bkTable:
        begin
          Gap;
          for I := 0 to B.Count - 1 do
          begin
            Row := '';
            for K := 0 to B[I].Count - 1 do
            begin
              if K > 0 then Row := Row + #9;
              Row := Row + OneLine(B[I][K].RunsText);
            end;
            Line(Row);
          end;
        end;
    else
      for I := 0 to B.Count - 1 do Walk(B[I], Prefix);
    end;
  end;

begin
  Out := '';
  Walk(FRoot, '');
  { no blank lines at the end }
  while Copy(Out, Length(Out) - 3, 4) = #13#10#13#10 do SetLength(Out, Length(Out) - 2);
  Result := Out;
end;

end.
