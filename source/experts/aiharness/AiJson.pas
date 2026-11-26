{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiJson;

{ JSON for the AI harness (Delphi 7 has no JSON library): a document tree (TJson), a parser and
  a writer. Strings are UTF-8 in the tree and in the text, as on the wire; \u escapes, surrogate
  pairs included, become UTF-8. Numbers keep their literal, so they are written back exactly.
  Object members keep their order. A raw value (NewRaw) is JSON text that is already serialized:
  it is written as it is, so a part that never changes is serialized once. }

interface

uses
  SysUtils, Classes, AiText;

type
  TJsonKind = (jkNull, jkFalse, jkTrue, jkNumber, jkString, jkArray, jkObject, jkRaw);

  EJsonError = class(Exception);

  TJson = class
  private
    FKind: TJsonKind;
    FText: string;            // a string's UTF-8 value, a number's literal, a raw value's JSON
    FItems: TList;            // array items, object values (owned)
    FNames: TStringList;      // object member names, parallel to FItems
    procedure NeedItems;
    procedure WriteTo(B: TKitStringBuilder);
  public
    constructor Create(AKind: TJsonKind);
    destructor Destroy; override;
    class function NewObject: TJson;
    class function NewArray: TJson;
    class function NewString(const Utf8: string): TJson;
    class function NewInt(Value: Int64): TJson;
    class function NewNumber(const Literal: string): TJson;
    class function NewBool(Value: Boolean): TJson;
    class function NewNull: TJson;
    { JSON text written as it is (it must be one valid JSON value) }
    class function NewRaw(const JsonText: string): TJson;
    { raises EJsonError }
    class function Parse(const Utf8: string): TJson;
    { nil when Utf8 is not one JSON value }
    class function TryParse(const Utf8: string): TJson;
    function Clone: TJson;
    { compact JSON text (UTF-8) }
    function ToJson: string;
    property Kind: TJsonKind read FKind;
    function IsNull: Boolean;
    function IsObject: Boolean;
    function IsArray: Boolean;
    function IsString: Boolean;
    { a string's value, a number's literal, 'true' / 'false', '' for null and containers }
    function AsString: string;
    function AsInteger(Default: Integer): Integer;
    function AsInt64(Default: Int64): Int64;
    function AsBoolean(Default: Boolean): Boolean;
    { array items or object members }
    function Count: Integer;
    function Item(Index: Integer): TJson;
    { array: appends V (owned from now on) and returns it }
    function Add(V: TJson): TJson;
    function AddString(const Utf8: string): TJson;
    function AddObject: TJson;
    function AddArray: TJson;
    { object members }
    function Name(Index: Integer): string;
    function IndexOf(const AName: string): Integer;
    function Has(const AName: string): Boolean;
    { the member is there and is not null }
    function HasValue(const AName: string): Boolean;
    function Get(const AName: string): TJson;
    { replaces or appends the member (V owned from now on) and returns V }
    function Put(const AName: string; V: TJson): TJson;
    procedure PutStr(const AName, Utf8: string);
    procedure PutInt(const AName: string; Value: Int64);
    procedure PutBool(const AName: string; Value: Boolean);
    procedure PutNull(const AName: string);
    function PutObject(const AName: string): TJson;
    function PutArray(const AName: string): TJson;
    procedure Remove(const AName: string);
    { a member's value of the kind asked for; the default when it is missing or of another kind }
    function Str(const AName: string; const Default: string = ''): string;
    function Int(const AName: string; Default: Integer): Integer;
    function Bool(const AName: string; Default: Boolean): Boolean;
    function Obj(const AName: string): TJson;
    function Arr(const AName: string): TJson;
  end;

{ S as a JSON string literal, quotes included }
function JsonQuote(const Utf8: string): string;

implementation

const
  MaxDepth = 512;

{ ---------------------------------------------------------------- writer }

procedure WriteQuoted(B: TKitStringBuilder; const S: string);
const
  Hex: array[0..15] of Char = '0123456789abcdef';
var
  I, Start, L: Integer;
  C: Char;
  E: string;
begin
  B.AppendChar('"');
  Start := 1;
  L := Length(S);
  for I := 1 to L do
  begin
    C := S[I];
    if (C < ' ') or (C = '"') or (C = '\') then
    begin
      if I > Start then B.Append(@S[Start], I - Start);
      case C of
        '"': E := '\"';
        '\': E := '\\';
        #8: E := '\b';
        #9: E := '\t';
        #10: E := '\n';
        #12: E := '\f';
        #13: E := '\r';
      else
        E := '\u00' + Hex[Ord(C) shr 4] + Hex[Ord(C) and 15];
      end;
      B.Append(E);
      Start := I + 1;
    end;
  end;
  if L >= Start then B.Append(@S[Start], L - Start + 1);
  B.AppendChar('"');
end;

function JsonQuote(const Utf8: string): string;
var
  B: TKitStringBuilder;
begin
  B := TKitStringBuilder.Create;
  try
    WriteQuoted(B, Utf8);
    Result := B.Text;
  finally
    B.Free;
  end;
end;

{ ---------------------------------------------------------------- parser }

type
  TJsonParser = class
  private
    FText: string;
    FPos: Integer;
    FLen: Integer;
    procedure Error(const Msg: string);
    procedure SkipWhite;
    function ParseValue(Depth: Integer): TJson;
    function ParseString: string;
    function ParseNumber: string;
    procedure Expect(const Word: string);
  public
    constructor Create(const AText: string);
    function ParseDocument: TJson;
  end;

constructor TJsonParser.Create(const AText: string);
begin
  inherited Create;
  FText := AText;
  FPos := 1;
  FLen := Length(AText);
end;

procedure TJsonParser.Error(const Msg: string);
begin
  raise EJsonError.CreateFmt('JSON: %s at offset %d', [Msg, FPos - 1]);
end;

procedure TJsonParser.SkipWhite;
begin
  while (FPos <= FLen) and (FText[FPos] in [' ', #9, #10, #13]) do Inc(FPos);
end;

procedure TJsonParser.Expect(const Word: string);
begin
  if Copy(FText, FPos, Length(Word)) <> Word then Error('unexpected text');
  Inc(FPos, Length(Word));
end;

function TJsonParser.ParseDocument: TJson;
begin
  SkipWhite;
  Result := ParseValue(0);
  try
    SkipWhite;
    if FPos <= FLen then Error('text after the value');
  except
    Result.Free;
    raise;
  end;
end;

{ U as UTF-8 }
function CodePointToUtf8(U: Cardinal): string;
begin
  if U < $80 then Result := Chr(U)
  else if U < $800 then Result := Chr($C0 or (U shr 6)) + Chr($80 or (U and $3F))
  else if U < $10000 then
    Result := Chr($E0 or (U shr 12)) + Chr($80 or ((U shr 6) and $3F)) + Chr($80 or (U and $3F))
  else
    Result := Chr($F0 or (U shr 18)) + Chr($80 or ((U shr 12) and $3F)) +
      Chr($80 or ((U shr 6) and $3F)) + Chr($80 or (U and $3F));
end;

function TJsonParser.ParseString: string;
var
  B: TKitStringBuilder;
  Start: Integer;
  C: Char;
  U, U2: Cardinal;

  function Hex4: Cardinal;
  var
    I: Integer;
    D: Char;
  begin
    Result := 0;
    if FPos + 3 > FLen then Error('short \u escape');
    for I := 0 to 3 do
    begin
      D := FText[FPos + I];
      case D of
        '0'..'9': Result := Result * 16 + Cardinal(Ord(D) - Ord('0'));
        'a'..'f': Result := Result * 16 + Cardinal(Ord(D) - Ord('a') + 10);
        'A'..'F': Result := Result * 16 + Cardinal(Ord(D) - Ord('A') + 10);
      else
        Error('bad \u escape');
      end;
    end;
    Inc(FPos, 4);
  end;

begin
  Inc(FPos);   // the opening quote
  B := TKitStringBuilder.Create;
  try
    Start := FPos;
    while True do
    begin
      if FPos > FLen then Error('unterminated string');
      C := FText[FPos];
      if C = '"' then
      begin
        if FPos > Start then B.Append(@FText[Start], FPos - Start);
        Inc(FPos);
        Break;
      end;
      if C = '\' then
      begin
        if FPos > Start then B.Append(@FText[Start], FPos - Start);
        Inc(FPos);
        if FPos > FLen then Error('unterminated escape');
        C := FText[FPos];
        Inc(FPos);
        case C of
          '"': B.AppendChar('"');
          '\': B.AppendChar('\');
          '/': B.AppendChar('/');
          'b': B.AppendChar(#8);
          'f': B.AppendChar(#12);
          'n': B.AppendChar(#10);
          'r': B.AppendChar(#13);
          't': B.AppendChar(#9);
          'u':
            begin
              U := Hex4;
              if (U >= $D800) and (U <= $DBFF) and (Copy(FText, FPos, 2) = '\u') then
              begin
                Inc(FPos, 2);
                U2 := Hex4;
                if (U2 >= $DC00) and (U2 <= $DFFF) then
                  U := $10000 + ((U - $D800) shl 10) + (U2 - $DC00)
                else
                begin
                  B.Append(CodePointToUtf8($FFFD));
                  U := U2;
                end;
              end;
              if (U >= $D800) and (U <= $DFFF) then U := $FFFD;   // a lone surrogate
              B.Append(CodePointToUtf8(U));
            end;
        else
          Error('bad escape');
        end;
        Start := FPos;
      end
      else
        Inc(FPos);
    end;
    Result := B.Text;
  finally
    B.Free;
  end;
end;

function TJsonParser.ParseNumber: string;
var
  Start: Integer;
begin
  Start := FPos;
  if (FPos <= FLen) and (FText[FPos] = '-') then Inc(FPos);
  if (FPos > FLen) or not (FText[FPos] in ['0'..'9']) then Error('bad number');
  while (FPos <= FLen) and (FText[FPos] in ['0'..'9']) do Inc(FPos);
  if (FPos <= FLen) and (FText[FPos] = '.') then
  begin
    Inc(FPos);
    if (FPos > FLen) or not (FText[FPos] in ['0'..'9']) then Error('bad number');
    while (FPos <= FLen) and (FText[FPos] in ['0'..'9']) do Inc(FPos);
  end;
  if (FPos <= FLen) and (FText[FPos] in ['e', 'E']) then
  begin
    Inc(FPos);
    if (FPos <= FLen) and (FText[FPos] in ['+', '-']) then Inc(FPos);
    if (FPos > FLen) or not (FText[FPos] in ['0'..'9']) then Error('bad number');
    while (FPos <= FLen) and (FText[FPos] in ['0'..'9']) do Inc(FPos);
  end;
  Result := Copy(FText, Start, FPos - Start);
end;

function TJsonParser.ParseValue(Depth: Integer): TJson;
var
  Key: string;
  V: TJson;
begin
  if Depth > MaxDepth then Error('nested too deeply');
  SkipWhite;
  if FPos > FLen then Error('value expected');
  case FText[FPos] of
    '{':
      begin
        Result := TJson.NewObject;
        try
          Inc(FPos);
          SkipWhite;
          if (FPos <= FLen) and (FText[FPos] = '}') then Inc(FPos)
          else
            while True do
            begin
              SkipWhite;
              if (FPos > FLen) or (FText[FPos] <> '"') then Error('member name expected');
              Key := ParseString;
              SkipWhite;
              if (FPos > FLen) or (FText[FPos] <> ':') then Error(''':'' expected');
              Inc(FPos);
              V := ParseValue(Depth + 1);
              Result.Put(Key, V);
              SkipWhite;
              if FPos > FLen then Error('unterminated object');
              if FText[FPos] = ',' then Inc(FPos)
              else if FText[FPos] = '}' then
              begin
                Inc(FPos);
                Break;
              end
              else Error(''','' or ''}'' expected');
            end;
        except
          Result.Free;
          raise;
        end;
      end;
    '[':
      begin
        Result := TJson.NewArray;
        try
          Inc(FPos);
          SkipWhite;
          if (FPos <= FLen) and (FText[FPos] = ']') then Inc(FPos)
          else
            while True do
            begin
              Result.Add(ParseValue(Depth + 1));
              SkipWhite;
              if FPos > FLen then Error('unterminated array');
              if FText[FPos] = ',' then Inc(FPos)
              else if FText[FPos] = ']' then
              begin
                Inc(FPos);
                Break;
              end
              else Error(''','' or '']'' expected');
            end;
        except
          Result.Free;
          raise;
        end;
      end;
    '"': Result := TJson.NewString(ParseString);
    't':
      begin
        Expect('true');
        Result := TJson.NewBool(True);
      end;
    'f':
      begin
        Expect('false');
        Result := TJson.NewBool(False);
      end;
    'n':
      begin
        Expect('null');
        Result := TJson.NewNull;
      end;
    '-', '0'..'9': Result := TJson.NewNumber(ParseNumber);
  else
    Error('unexpected character');
    Result := nil;
  end;
end;

{ ---------------------------------------------------------------- TJson }

constructor TJson.Create(AKind: TJsonKind);
begin
  inherited Create;
  FKind := AKind;
end;

destructor TJson.Destroy;
var
  I: Integer;
begin
  if FItems <> nil then
  begin
    for I := 0 to FItems.Count - 1 do TObject(FItems[I]).Free;
    FItems.Free;
  end;
  FNames.Free;
  inherited;
end;

procedure TJson.NeedItems;
begin
  if FItems = nil then FItems := TList.Create;
  if (FKind = jkObject) and (FNames = nil) then
  begin
    FNames := TStringList.Create;
    FNames.CaseSensitive := True;
  end;
end;

class function TJson.NewObject: TJson;
begin
  Result := TJson.Create(jkObject);
end;

class function TJson.NewArray: TJson;
begin
  Result := TJson.Create(jkArray);
end;

class function TJson.NewString(const Utf8: string): TJson;
begin
  Result := TJson.Create(jkString);
  Result.FText := Utf8;
end;

class function TJson.NewInt(Value: Int64): TJson;
begin
  Result := TJson.Create(jkNumber);
  Result.FText := IntToStr(Value);
end;

class function TJson.NewNumber(const Literal: string): TJson;
begin
  Result := TJson.Create(jkNumber);
  Result.FText := Literal;
end;

class function TJson.NewBool(Value: Boolean): TJson;
begin
  if Value then Result := TJson.Create(jkTrue) else Result := TJson.Create(jkFalse);
end;

class function TJson.NewNull: TJson;
begin
  Result := TJson.Create(jkNull);
end;

class function TJson.NewRaw(const JsonText: string): TJson;
begin
  Result := TJson.Create(jkRaw);
  Result.FText := JsonText;
end;

class function TJson.Parse(const Utf8: string): TJson;
var
  P: TJsonParser;
begin
  P := TJsonParser.Create(Utf8);
  try
    Result := P.ParseDocument;
  finally
    P.Free;
  end;
end;

class function TJson.TryParse(const Utf8: string): TJson;
begin
  try
    Result := Parse(Utf8);
  except
    on EJsonError do Result := nil;
  end;
end;

function TJson.Clone: TJson;
var
  I: Integer;
begin
  Result := TJson.Create(FKind);
  Result.FText := FText;
  case FKind of
    jkArray:
      for I := 0 to Count - 1 do Result.Add(Item(I).Clone);
    jkObject:
      for I := 0 to Count - 1 do Result.Put(Name(I), Item(I).Clone);
  end;
end;

procedure TJson.WriteTo(B: TKitStringBuilder);
var
  I: Integer;
begin
  case FKind of
    jkNull: B.Append('null');
    jkFalse: B.Append('false');
    jkTrue: B.Append('true');
    jkNumber, jkRaw: B.Append(FText);
    jkString: WriteQuoted(B, FText);
    jkArray:
      begin
        B.AppendChar('[');
        for I := 0 to Count - 1 do
        begin
          if I > 0 then B.AppendChar(',');
          Item(I).WriteTo(B);
        end;
        B.AppendChar(']');
      end;
    jkObject:
      begin
        B.AppendChar('{');
        for I := 0 to Count - 1 do
        begin
          if I > 0 then B.AppendChar(',');
          WriteQuoted(B, FNames[I]);
          B.AppendChar(':');
          Item(I).WriteTo(B);
        end;
        B.AppendChar('}');
      end;
  end;
end;

function TJson.ToJson: string;
var
  B: TKitStringBuilder;
begin
  B := TKitStringBuilder.Create;
  try
    WriteTo(B);
    Result := B.Text;
  finally
    B.Free;
  end;
end;

function TJson.IsNull: Boolean;
begin
  Result := FKind = jkNull;
end;

function TJson.IsObject: Boolean;
begin
  Result := FKind = jkObject;
end;

function TJson.IsArray: Boolean;
begin
  Result := FKind = jkArray;
end;

function TJson.IsString: Boolean;
begin
  Result := FKind = jkString;
end;

function TJson.AsString: string;
begin
  case FKind of
    jkString, jkNumber: Result := FText;
    jkTrue: Result := 'true';
    jkFalse: Result := 'false';
  else
    Result := '';
  end;
end;

function TJson.AsInt64(Default: Int64): Int64;
var
  D: Double;
  Code: Integer;
begin
  Result := Default;
  if FKind <> jkNumber then Exit;
  Result := StrToInt64Def(FText, Default);
  if (Result = Default) and (Pos('.', FText) + Pos('e', FText) + Pos('E', FText) > 0) then
  begin
    Val(FText, D, Code);    // Val reads a '.' whatever the locale
    if (Code = 0) and (Abs(D) < 9.2e18) then Result := Round(D);
  end;
end;

function TJson.AsInteger(Default: Integer): Integer;
var
  V: Int64;
begin
  V := AsInt64(Default);
  if (V > MaxInt) or (V < -MaxInt - 1) then Result := Default else Result := V;
end;

function TJson.AsBoolean(Default: Boolean): Boolean;
begin
  case FKind of
    jkTrue: Result := True;
    jkFalse: Result := False;
  else
    Result := Default;
  end;
end;

function TJson.Count: Integer;
begin
  if FItems = nil then Result := 0 else Result := FItems.Count;
end;

function TJson.Item(Index: Integer): TJson;
begin
  Result := TJson(FItems[Index]);
end;

function TJson.Add(V: TJson): TJson;
begin
  if FKind <> jkArray then raise EJsonError.Create('JSON: Add on a value that is not an array');
  NeedItems;
  FItems.Add(V);
  Result := V;
end;

function TJson.AddString(const Utf8: string): TJson;
begin
  Result := Add(TJson.NewString(Utf8));
end;

function TJson.AddObject: TJson;
begin
  Result := Add(TJson.NewObject);
end;

function TJson.AddArray: TJson;
begin
  Result := Add(TJson.NewArray);
end;

function TJson.Name(Index: Integer): string;
begin
  if FNames = nil then Result := '' else Result := FNames[Index];
end;

function TJson.IndexOf(const AName: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  if (FKind <> jkObject) or (FNames = nil) then Exit;
  for I := 0 to FNames.Count - 1 do
    if FNames[I] = AName then
    begin
      Result := I;
      Exit;
    end;
end;

function TJson.Has(const AName: string): Boolean;
begin
  Result := IndexOf(AName) >= 0;
end;

function TJson.HasValue(const AName: string): Boolean;
var
  V: TJson;
begin
  V := Get(AName);
  Result := (V <> nil) and not V.IsNull;
end;

function TJson.Get(const AName: string): TJson;
var
  I: Integer;
begin
  I := IndexOf(AName);
  if I < 0 then Result := nil else Result := TJson(FItems[I]);
end;

function TJson.Put(const AName: string; V: TJson): TJson;
var
  I: Integer;
begin
  if FKind <> jkObject then raise EJsonError.Create('JSON: Put on a value that is not an object');
  NeedItems;
  I := IndexOf(AName);
  if I >= 0 then
  begin
    TObject(FItems[I]).Free;
    FItems[I] := V;
  end
  else
  begin
    FNames.Add(AName);
    FItems.Add(V);
  end;
  Result := V;
end;

procedure TJson.PutStr(const AName, Utf8: string);
begin
  Put(AName, TJson.NewString(Utf8));
end;

procedure TJson.PutInt(const AName: string; Value: Int64);
begin
  Put(AName, TJson.NewInt(Value));
end;

procedure TJson.PutBool(const AName: string; Value: Boolean);
begin
  Put(AName, TJson.NewBool(Value));
end;

procedure TJson.PutNull(const AName: string);
begin
  Put(AName, TJson.NewNull);
end;

function TJson.PutObject(const AName: string): TJson;
begin
  Result := Put(AName, TJson.NewObject);
end;

function TJson.PutArray(const AName: string): TJson;
begin
  Result := Put(AName, TJson.NewArray);
end;

procedure TJson.Remove(const AName: string);
var
  I: Integer;
begin
  I := IndexOf(AName);
  if I < 0 then Exit;
  TObject(FItems[I]).Free;
  FItems.Delete(I);
  FNames.Delete(I);
end;

function TJson.Str(const AName: string; const Default: string): string;
var
  V: TJson;
begin
  V := Get(AName);
  if (V <> nil) and (V.FKind in [jkString, jkNumber]) then Result := V.FText else Result := Default;
end;

function TJson.Int(const AName: string; Default: Integer): Integer;
var
  V: TJson;
begin
  V := Get(AName);
  if V = nil then Result := Default
  else if V.FKind = jkString then Result := StrToIntDef(Trim(V.FText), Default)
  else Result := V.AsInteger(Default);
end;

function TJson.Bool(const AName: string; Default: Boolean): Boolean;
var
  V: TJson;
begin
  V := Get(AName);
  if V = nil then Result := Default
  else if V.FKind = jkString then
  begin
    if SameText(V.FText, 'true') then Result := True
    else if SameText(V.FText, 'false') then Result := False
    else Result := Default;
  end
  else Result := V.AsBoolean(Default);
end;

function TJson.Obj(const AName: string): TJson;
begin
  Result := Get(AName);
  if (Result <> nil) and (Result.FKind <> jkObject) then Result := nil;
end;

function TJson.Arr(const AName: string): TJson;
begin
  Result := Get(AName);
  if (Result <> nil) and (Result.FKind <> jkArray) then Result := nil;
end;

end.
