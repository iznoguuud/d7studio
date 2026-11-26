{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdMsgInfo;

{ D7 Studio - Additional Message Info (View | Additional Message Info): Delphi 7's
  Message Hints. Every compiler message is matched against the patterns of msginfo70.ini (Delphi's
  Bin\msginfo70.ini; D7 Studio's own copy in its settings folder once the user edits it): a
  section per kind - Hint, Warning, Error, Fatal Error -, a line per pattern,
  <pattern>=<explanation>. The view lists each message that has an explanation with it; an
  explanation that is a URL is blue and a double click opens it.

  The patterns are Delphi's simple regular expressions: "." any character, "*" the one before any
  number of times, "\" the next one as it is, "$" at the end the end of the message; anything
  else stands for itself. A pattern matches anywhere in the message, letter case aside. }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, StdCtrls, SdProject;

type
  TMsgHints = class
  private
    FSections: TStringList;          // section name -> its patterns and explanations (Objects)
    FLoaded: string;                 // the file and its date when it was read
  public
    constructor Create;
    destructor Destroy; override;
    { reads the file when it is another or has changed since (the user edits it) }
    procedure Load;
    function Explain(Kind: TMsgKind; const Text: string): string;    // '' none
  end;

  { the view: a message and its explanation, two lines each - the rows of a list of the main form's
    .dfm (MsgHintsList), which this draws and whose double click opens a link: it sets their events
    (the handlers are no form's) }
  TSdMessageHints = class
  private
    FList: TListBox;
    FHints: TMsgHints;
    procedure DrawHint(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure HintDblClick(Sender: TObject);
  public
    constructor Create(AList: TListBox);
    destructor Destroy; override;
    { the messages of a compile: the ones with an explanation are listed }
    procedure ShowMessages(List: TList);
    function SelectedText: string;   // message and explanation of the chosen row
    function AllText: string;
    procedure FontChanged;
    property List: TListBox read FList;
  end;

{ the file the explanations come from: D7 Studio's copy, else Delphi's }
function MsgInfoFile: string;
{ D7 Studio's copy of the file (made from Delphi's when there is none), for editing }
function EditableMsgInfoFile: string;
function PatternMatches(const Pattern, Text: string): Boolean;

implementation

uses
  SdSettings, SdDelphiDir, SdUI, SdEncoding, SdEditorPage;

type
  { a section of the file: its patterns and their explanations, in the file's order }
  TMsgSection = class
  public
    Patterns, Texts: TStringList;
    constructor Create;
    destructor Destroy; override;
  end;

constructor TMsgSection.Create;
begin
  inherited Create;
  Patterns := TStringList.Create;
  Texts := TStringList.Create;
end;

destructor TMsgSection.Destroy;
begin
  Texts.Free;
  Patterns.Free;
  inherited Destroy;
end;

function OwnFile: string;
begin
  { a name of its own - in Delphi's Bin, msginfo70.ini is Delphi's }
  Result := SettingsDir + 'D7Studio.msginfo.ini';
end;

function MsgInfoFile: string;
begin
  Result := OwnFile;
  if not FileExists(Result) then Result := DelphiBin + 'msginfo70.ini';
end;

function EditableMsgInfoFile: string;
begin
  Result := OwnFile;
  if not FileExists(Result) and FileExists(DelphiBin + 'msginfo70.ini') then
  begin
    ForceDirectories(ExtractFilePath(Result));
    CopyFile(PChar(DelphiBin + 'msginfo70.ini'), PChar(Result), True);
  end;
end;

function MatchAt(const Pat: string; PI: Integer; const S: string; SI: Integer): Boolean;
var
  C: Char;
  Lit: Boolean;
  Next: Integer;

  function Fits(K: Integer): Boolean;
  begin
    Result := (K <= Length(S)) and (((C = '.') and not Lit) or (UpCase(S[K]) = UpCase(C)));
  end;

begin
  if PI > Length(Pat) then
  begin
    Result := True;
    Exit;
  end;
  Lit := (Pat[PI] = '\') and (PI < Length(Pat));
  if Lit then
  begin
    C := Pat[PI + 1];
    Next := PI + 2;
  end
  else
  begin
    C := Pat[PI];
    Next := PI + 1;
  end;
  if (Next <= Length(Pat)) and (Pat[Next] = '*') then
  begin
    { the atom any number of times: as few as will do }
    Inc(Next);
    Result := True;
    if MatchAt(Pat, Next, S, SI) then Exit;
    while Fits(SI) do
    begin
      Inc(SI);
      if MatchAt(Pat, Next, S, SI) then Exit;
    end;
    Result := False;
    Exit;
  end;
  if (C = '$') and not Lit and (Next > Length(Pat)) then
  begin
    Result := SI > Length(S);
    Exit;
  end;
  Result := Fits(SI) and MatchAt(Pat, Next, S, SI + 1);
end;

function PatternMatches(const Pattern, Text: string): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 1 to Length(Text) + 1 do
    if MatchAt(Pattern, 1, Text, I) then Exit;
  Result := False;
end;

{ ---------------------------------------------------------------- TMsgHints }

constructor TMsgHints.Create;
begin
  inherited Create;
  FSections := TStringList.Create;
end;

destructor TMsgHints.Destroy;
var
  I: Integer;
begin
  for I := 0 to FSections.Count - 1 do FSections.Objects[I].Free;
  FSections.Free;
  inherited Destroy;
end;

procedure TMsgHints.Load;
var
  L: TStringList;
  Cur: TMsgSection;
  I, P: Integer;
  F, S: string;
begin
  F := MsgInfoFile;
  S := F + '|' + IntToStr(FileAge(F));
  if S = FLoaded then Exit;
  FLoaded := S;
  for I := 0 to FSections.Count - 1 do FSections.Objects[I].Free;
  FSections.Clear;
  if not FileExists(F) then Exit;
  L := TStringList.Create;
  try
    { read as the editor reads it - D7 Studio's copy is edited there and keeps the encoding it
      has (the system code page, UTF-8 with or without its mark) - into the IDE's text, the
      messages' }
    L.Text := ReadSourceFileAs(F, IdeEncoding);
    Cur := nil;
    for I := 0 to L.Count - 1 do
    begin
      S := Trim(L[I]);
      if (S = '') or (S[1] = ';') then Continue;
      if S[1] = '[' then
      begin
        Cur := TMsgSection.Create;
        FSections.AddObject(Copy(S, 2, Length(S) - 2), Cur);
        Continue;
      end;
      { the pattern ends at the first '=' (the explanation may have its own): split here once, not
        for every message }
      P := Pos('=', S);
      if (Cur <> nil) and (P > 1) then
      begin
        Cur.Patterns.Add(Copy(S, 1, P - 1));
        Cur.Texts.Add(Copy(S, P + 1, MaxInt));
      end;
    end;
  finally
    L.Free;
  end;
end;

function TMsgHints.Explain(Kind: TMsgKind; const Text: string): string;
const
  Names: array[TMsgKind] of string = ('', 'Hint', 'Warning', 'Error', 'Fatal Error');
var
  I, K, P: Integer;
  Sec: TMsgSection;
  M: string;
begin
  Result := '';
  { the message without its "[Error] Unit1.pas(30): " }
  M := Text;
  P := Pos('): ', M);
  if P > 0 then M := Copy(M, P + 3, MaxInt)
  else if Pos('] ', M) > 0 then M := Copy(M, Pos('] ', M) + 2, MaxInt);
  I := FSections.IndexOf(Names[Kind]);
  if I < 0 then Exit;
  Sec := TMsgSection(FSections.Objects[I]);
  for K := 0 to Sec.Patterns.Count - 1 do
    if PatternMatches(Sec.Patterns[K], M) then
    begin
      Result := Sec.Texts[K];
      Exit;
    end;
end;

{ ---------------------------------------------------------------- TSdMessageHints }

constructor TSdMessageHints.Create(AList: TListBox);
begin
  inherited Create;
  FList := AList;
  FHints := TMsgHints.Create;
  FList.DoubleBuffered := True;
  FList.OnDrawItem := DrawHint;
  FList.OnDblClick := HintDblClick;
end;

destructor TSdMessageHints.Destroy;
var
  I: Integer;
begin
  { the list is the main form's: it is still there when the form frees this (and keeps no rows) }
  for I := 0 to FList.Items.Count - 1 do FList.Items.Objects[I].Free;
  FList.Items.Clear;
  FHints.Free;
  inherited Destroy;
end;

procedure TSdMessageHints.FontChanged;
begin
  FList.ItemHeight := 2 * UIFontHeight(FList.Font) + 6;
end;

type
  THintRow = class
  public
    Msg, Hint: string;
  end;

procedure TSdMessageHints.ShowMessages(List: TList);
var
  I: Integer;
  M: TCompilerMessage;
  R: THintRow;
  H: string;
begin
  if List <> nil then FHints.Load;
  FList.Items.BeginUpdate;
  try
    for I := 0 to FList.Items.Count - 1 do FList.Items.Objects[I].Free;
    FList.Items.Clear;
    if List <> nil then
    for I := 0 to List.Count - 1 do
    begin
      M := TCompilerMessage(List[I]);
      if M.Kind = mkInfo then Continue;
      H := FHints.Explain(M.Kind, M.Text);
      if H = '' then Continue;
      R := THintRow.Create;
      R.Msg := M.Text;
      R.Hint := H;
      FList.Items.AddObject(M.Text, R);
    end;
  finally
    FList.Items.EndUpdate;
  end;
end;

procedure TSdMessageHints.DrawHint(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  R: THintRow;
  H: Integer;
  T: TRect;
begin
  R := THintRow(FList.Items.Objects[Index]);
  if odSelected in State then
  begin
    FList.Canvas.Brush.Color := clHighlight;
    FList.Canvas.Font.Color := clHighlightText;
  end
  else
  begin
    FList.Canvas.Brush.Color := clWindow;
    FList.Canvas.Font.Color := clWindowText;
  end;
  FList.Canvas.FillRect(Rect);
  if R = nil then Exit;
  H := (Rect.Bottom - Rect.Top - 6) div 2;
  FList.Canvas.Brush.Style := bsClear;
  FList.Canvas.Font.Style := [fsBold];
  T := Classes.Rect(Rect.Left + 4, Rect.Top + 2, Rect.Right - 4, Rect.Top + 2 + H);
  DrawText(FList.Canvas.Handle, PChar(R.Msg), Length(R.Msg), T, DT_SINGLELINE or DT_END_ELLIPSIS or DT_NOPREFIX);
  UIListRowWidth(FList, T.Left + FList.Canvas.TextWidth(R.Msg) + 2);
  FList.Canvas.Font.Style := [];
  if UIIsUrl(R.Hint) and not (odSelected in State) then
  begin
    FList.Canvas.Font.Color := clBlue;
    FList.Canvas.Font.Style := [fsUnderline];
  end;
  T := Classes.Rect(Rect.Left + 16, Rect.Top + 3 + H, Rect.Right - 4, Rect.Bottom - 2);
  DrawText(FList.Canvas.Handle, PChar(R.Hint), Length(R.Hint), T, DT_SINGLELINE or DT_END_ELLIPSIS or DT_NOPREFIX);
  UIListRowWidth(FList, T.Left + FList.Canvas.TextWidth(R.Hint) + 2);
  FList.Canvas.Brush.Style := bsSolid;
end;

procedure TSdMessageHints.HintDblClick(Sender: TObject);
var
  R: THintRow;
begin
  if FList.ItemIndex < 0 then Exit;
  R := THintRow(FList.Items.Objects[FList.ItemIndex]);
  if R <> nil then UIOpenUrl(R.Hint);
end;

function TSdMessageHints.SelectedText: string;
var
  R: THintRow;
begin
  Result := '';
  if FList.ItemIndex < 0 then Exit;
  R := THintRow(FList.Items.Objects[FList.ItemIndex]);
  if R <> nil then Result := R.Msg + #13#10 + R.Hint;
end;

function TSdMessageHints.AllText: string;
var
  I: Integer;
  R: THintRow;
begin
  Result := '';
  for I := 0 to FList.Items.Count - 1 do
  begin
    R := THintRow(FList.Items.Objects[I]);
    if R <> nil then Result := Result + R.Msg + #13#10 + R.Hint + #13#10;
  end;
end;

end.
