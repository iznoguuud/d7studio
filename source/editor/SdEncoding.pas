{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdEncoding;

{ D7 Studio - the encoding of a text file.

  Delphi 7 compiles code-page source only, so the editor keeps a file's text as it is wherever
  it can: a file in a code page (the system's or another one) stays bytes - the editor shows
  them in the character set of that code page. Only UTF-8 and UTF-16 files are held as UTF-8
  (the editor then works in UTF-8) and converted back on save.

  Two code pages: the system's (SystemEncoding) is the one of files that do not say otherwise -
  the one Delphi 7 and dcc32 read; D7 Studio's own text (its windows, dialogs, settings,
  IdeEncoding) is in the process's ANSI code page, UTF-8: D7 Studio runs in UTF-8 mode (its
  manifest).

  "Editor text" below means what the editor holds: the file's bytes for a code page, UTF-8 for
  the Unicode encodings. }

interface

uses
  Windows, SysUtils, Classes;

const
  CP_UTF16LE = 1200;
  CP_UTF16BE = 1201;

type
  TSdEncoding = record
    CodePage: Integer;      // a Windows code page, CP_UTF8, CP_UTF16LE or CP_UTF16BE
    BOM: Boolean;           // UTF-8 written with a byte order mark (UTF-16 always has one)
  end;

{ the system's code page without BOM: Windows' ANSI code page of programs without UTF-8 mode
  (Utf8Mode.SystemLegacyCodePage) - dcc32's, and the one of files that do not say otherwise }
function SystemEncoding: TSdEncoding;
{ the code page of D7 Studio's own text (its windows, dialogs, settings, file names): the
  process's ANSI code page - UTF-8 in UTF-8 mode, else the system's }
function IdeEncoding: TSdEncoding;
function MakeEncoding(CodePage: Integer; BOM: Boolean): TSdEncoding;
function SameEncoding(const A, B: TSdEncoding): Boolean;
{ the editor works in UTF-8 for this encoding }
function IsUnicodeEncoding(const E: TSdEncoding): Boolean;
function EncodingName(const E: TSdEncoding): string;     // 'UTF-8', 'Windows-1253 (Greek)' ...
function EncodingShortName(const E: TSdEncoding): string; // for the status bar
{ The encodings offered by the encoding commands, as "name=code page[,bom]" lines. }
procedure GetEncodingList(L: TStrings);
function EncodingFromListValue(const Value: string): TSdEncoding;
function EncodingToSetting(const E: TSdEncoding): string;  // "1253", "65001,bom"
function EncodingFromSetting(const S: string; var E: TSdEncoding): Boolean;

{ the encoding of a file's bytes: by byte order mark, then valid UTF-8 (with bytes other than
  ASCII), else the system code page }
function DetectEncoding(const Bytes: string): TSdEncoding;
{ the bytes of a file -> editor text; Detect: E found from the bytes (DetectEncoding); else E is
  used as it is }
function DecodeFile(const Bytes: string; var E: TSdEncoding; Detect: Boolean): string;
{ editor text -> the bytes of the file; Lost: a character the code page cannot hold became '?' }
function EncodeFile(const Text: string; const E: TSdEncoding; out Lost: Boolean): string;
{ editor text in encoding A -> editor text in encoding B (Res); False when Windows cannot convert
  between them (Res = '' then: never put it in place of the text); Lost: a character that B
  cannot hold became '?' }
function ConvertText(const Text: string; const A, B: TSdEncoding; out Res: string; out Lost: Boolean): Boolean;
{ text of the programs of the system code page (dcc32's messages ...) -> text of the IDE, and back
  (what dcc32 reads: its .cfg ...; Lost: a character the code page lacks became '?'); the same text
  when D7 Studio is not in UTF-8 mode }
function SystemToIde(const S: string): string;
function IdeToSystem(const S: string; out Lost: Boolean): string;
{ the bytes of a file that Delphi 7 reads too (a project's .dof, Delphi's .dro and .dci) -> IDE
  text: the system code page, or UTF-8 when the bytes are UTF-8 beyond ASCII, as D7 Studio wrote
  such files before (DetectEncoding); and IDE text -> such a file's bytes: the system code page,
  UTF-8 when the code page lacks one of its characters (nothing is lost) }
function SystemFileToIde(const Bytes: string): string;
function IdeToSystemFile(const Text: string): string;
{ text of the IDE (IdeEncoding) <-> editor text of encoding E (search strings, the To-Do List ...) }
function AnsiToEditor(const S: string; const E: TSdEncoding): string;
function EditorToAnsi(const S: string; const E: TSdEncoding): string;
{ editor text of encoding E in UTF-16 (for Unicode display) }
function EditorToWide(const S: string; const E: TSdEncoding): WideString;
{ the GDI character set that shows a code page (Scintilla's SCI_STYLESETCHARACTERSET); Unknown
  for a code page without one of its own }
function CharsetForCodePage(CodePage: Integer; Unknown: Integer = ANSI_CHARSET): Integer;
function IsValidUtf8(const S: string): Boolean;
function HasHighBytes(const S: string): Boolean;           // a byte of 128 or more
{ bytes of a code page <-> UTF-16; Lost: a character the code page cannot hold became '?'.
  OK = False: Windows could not convert in that code page at all (a non-empty text came out
  empty) - the forms without OK cannot tell that from an empty text }
function ToWide(const S: string; CodePage: Integer): WideString; overload;
function ToWide(const S: string; CodePage: Integer; out OK: Boolean): WideString; overload;
function FromWide(const W: WideString; CodePage: Integer; out Lost: Boolean): string; overload;
{ UTF-16 text as IDE text (CP_ACP; what that code page lacks is lost) - never the implicit
  conversion, which takes the code page of the user's locale }
function WideToIde(const W: WideString): string;
{ IDE text in UTF-16 - bytes that are no UTF-8 in UTF-8 mode are the system code page's (a file
  Delphi 7 wrote: a .dof, a form before Delphi 6) }
function IdeTextToWide(const S: string): WideString;
{ a character typed into a window of the IDE: its bytes (IDE text) come one WM_CHAR - one
  KeyPress - each, two to four of them for a character beyond ASCII in UTF-8 mode (measured on
  the editor), two for one of a double-byte code page. Pending collects them; the result is the
  character once its last byte came ('' before) }
function TypedIdeChar(Key: Char; var Pending: string): string;
{ the last character of IDE text taken off: all bytes of a UTF-8 or double-byte one }
procedure DeleteLastIdeChar(var S: string);
function FromWide(const W: WideString; CodePage: Integer; out Lost, OK: Boolean): string; overload;

implementation

uses
  Utf8Mode;

const
  KnownPages: array[0..15] of record CP: Integer; Name: string end = (
    (CP: 1250; Name: 'Central European'), (CP: 1251; Name: 'Cyrillic'),
    (CP: 1252; Name: 'Western European'), (CP: 1253; Name: 'Greek'),
    (CP: 1254; Name: 'Turkish'), (CP: 1255; Name: 'Hebrew'), (CP: 1256; Name: 'Arabic'),
    (CP: 1257; Name: 'Baltic'), (CP: 1258; Name: 'Vietnamese'), (CP: 874; Name: 'Thai'),
    (CP: 932; Name: 'Japanese'), (CP: 936; Name: 'Chinese Simplified'),
    (CP: 949; Name: 'Korean'), (CP: 950; Name: 'Chinese Traditional'),
    (CP: 437; Name: 'OEM United States'), (CP: 850; Name: 'OEM Multilingual Latin 1'));

function MakeEncoding(CodePage: Integer; BOM: Boolean): TSdEncoding;
begin
  Result.CodePage := CodePage;
  Result.BOM := BOM;
end;

function SystemEncoding: TSdEncoding;
begin
  Result := MakeEncoding(SystemLegacyCodePage, False);
end;

function IdeEncoding: TSdEncoding;
begin
  Result := MakeEncoding(GetACP, False);
end;

function SameEncoding(const A, B: TSdEncoding): Boolean;
begin
  Result := (A.CodePage = B.CodePage) and
    ((A.CodePage <> CP_UTF8) or (A.BOM = B.BOM));
end;

function IsUnicodeEncoding(const E: TSdEncoding): Boolean;
begin
  Result := (E.CodePage = CP_UTF8) or (E.CodePage = CP_UTF16LE) or (E.CodePage = CP_UTF16BE);
end;

function PageName(CP: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := Low(KnownPages) to High(KnownPages) do
    if KnownPages[I].CP = CP then Result := KnownPages[I].Name;
end;

function EncodingShortName(const E: TSdEncoding): string;
begin
  case E.CodePage of
    CP_UTF8: if E.BOM then Result := 'UTF-8 BOM' else Result := 'UTF-8';
    CP_UTF16LE: Result := 'UTF-16 LE';
    CP_UTF16BE: Result := 'UTF-16 BE';
  else
    if (E.CodePage >= 1250) and (E.CodePage <= 1258) or (E.CodePage = 874) then
      Result := Format('Windows-%d', [E.CodePage])
    else
      Result := Format('CP %d', [E.CodePage]);
  end;
end;

function EncodingName(const E: TSdEncoding): string;
begin
  case E.CodePage of
    CP_UTF8: if E.BOM then Result := 'UTF-8 with BOM' else Result := 'UTF-8';
    CP_UTF16LE: Result := 'UTF-16 LE (with BOM)';
    CP_UTF16BE: Result := 'UTF-16 BE (with BOM)';
  else
    Result := EncodingShortName(E);
    if PageName(E.CodePage) <> '' then Result := Result + ' (' + PageName(E.CodePage) + ')';
    if E.CodePage = Integer(SystemLegacyCodePage) then Result := Result + ' - system';
  end;
end;

procedure GetEncodingList(L: TStrings);

  procedure Add(const E: TSdEncoding);
  begin
    L.Add(EncodingName(E) + '=' + EncodingToSetting(E));
  end;

var
  I: Integer;
begin
  L.Clear;
  Add(SystemEncoding);
  Add(MakeEncoding(CP_UTF8, False));
  Add(MakeEncoding(CP_UTF8, True));
  Add(MakeEncoding(CP_UTF16LE, True));
  Add(MakeEncoding(CP_UTF16BE, True));
  for I := Low(KnownPages) to High(KnownPages) do
    if KnownPages[I].CP <> Integer(SystemLegacyCodePage) then Add(MakeEncoding(KnownPages[I].CP, False));
end;

function EncodingToSetting(const E: TSdEncoding): string;
begin
  Result := IntToStr(E.CodePage);
  if E.BOM and (E.CodePage = CP_UTF8) then Result := Result + ',bom';
end;

function EncodingFromSetting(const S: string; var E: TSdEncoding): Boolean;
var
  P, CP: Integer;
begin
  P := Pos(',', S);
  if P = 0 then P := Length(S) + 1;
  CP := StrToIntDef(Copy(S, 1, P - 1), 0);
  Result := (CP = CP_UTF16LE) or (CP = CP_UTF16BE) or IsValidCodePage(CP);
  if Result then E := MakeEncoding(CP, SameText(Copy(S, P + 1, MaxInt), 'bom'));
end;

function EncodingFromListValue(const Value: string): TSdEncoding;
begin
  if not EncodingFromSetting(Value, Result) then Result := SystemEncoding;
end;

function CharsetForCodePage(CodePage: Integer; Unknown: Integer): Integer;
begin
  case CodePage of
    1252: Result := ANSI_CHARSET;
    1250: Result := EASTEUROPE_CHARSET;
    1251: Result := RUSSIAN_CHARSET;
    1253: Result := GREEK_CHARSET;
    1254: Result := TURKISH_CHARSET;
    1255: Result := HEBREW_CHARSET;
    1256: Result := ARABIC_CHARSET;
    1257: Result := BALTIC_CHARSET;
    1258: Result := VIETNAMESE_CHARSET;
    874: Result := THAI_CHARSET;
    932: Result := SHIFTJIS_CHARSET;
    936: Result := GB2312_CHARSET;
    949: Result := HANGEUL_CHARSET;
    950: Result := CHINESEBIG5_CHARSET;
    437, 850: Result := OEM_CHARSET;
  else
    Result := Unknown;
  end;
end;

{ --- conversions through UTF-16 --- }

function ToWide(const S: string; CodePage: Integer; out OK: Boolean): WideString;
var
  N: Integer;
begin
  Result := '';
  OK := True;
  if S = '' then Exit;
  N := MultiByteToWideChar(CodePage, 0, PChar(S), Length(S), nil, 0);
  SetLength(Result, N);
  if N > 0 then N := MultiByteToWideChar(CodePage, 0, PChar(S), Length(S), PWideChar(Result), N);
  OK := N > 0;
  if not OK then Result := '';
end;

function ToWide(const S: string; CodePage: Integer): WideString;
var
  OK: Boolean;
begin
  Result := ToWide(S, CodePage, OK);
end;

{ The code pages whose conversion takes neither flags nor the "default character used" flag
  (WideCharToMultiByte fails with ERROR_INVALID_PARAMETER): UTF-7 and UTF-8, the symbol code page,
  the ISO-2022 and EUC pages, GB18030, ISCII. }
function TakesNoFlags(CodePage: Integer): Boolean;
begin
  case CodePage of
    42, 50220..50229, 51932, 52936, 54936, 57002..57011, 65000, CP_UTF8: Result := True;
  else
    Result := False;
  end;
end;

function FromWide(const W: WideString; CodePage: Integer; out Lost, OK: Boolean): string;
const
  WC_NO_BEST_FIT_CHARS = $400;
var
  N: Integer;
  Flags: DWORD;
  Used: BOOL;
  PUsed: PBOOL;
begin
  Result := '';
  Lost := False;
  OK := True;
  if W = '' then Exit;
  if CodePage = CP_ACP then CodePage := GetACP;
  { Windows maps a character the code page lacks to a similar one ("best fit": L for the Polish
    L with stroke, \ and : for their fullwidth forms) and does not call it lost; without best fit
    it becomes the default character, and the flag tells. The pages that take no flags are
    checked by converting back. }
  if TakesNoFlags(CodePage) then
  begin
    Flags := 0;
    PUsed := nil;
  end
  else
  begin
    Flags := WC_NO_BEST_FIT_CHARS;
    PUsed := @Used;
  end;
  Used := False;
  N := WideCharToMultiByte(CodePage, Flags, PWideChar(W), Length(W), nil, 0, nil, PUsed);
  SetLength(Result, N);
  if N > 0 then N := WideCharToMultiByte(CodePage, Flags, PWideChar(W), Length(W), PChar(Result), N, nil, PUsed);
  OK := N > 0;
  if not OK then Result := ''
  else if (PUsed = nil) and (CodePage <> CP_UTF8) then
    Used := ToWide(Result, CodePage) <> W;
  { a failed conversion loses everything }
  Lost := Used or not OK;
end;

function IdeTextToWide(const S: string): WideString;
begin
  if (IdeEncoding.CodePage = CP_UTF8) and not IsValidUtf8(S) then
    Result := ToWide(S, SystemEncoding.CodePage)
  else
    Result := ToWide(S, CP_ACP);
end;

function WideToIde(const W: WideString): string;
var
  Lost: Boolean;
begin
  Result := FromWide(W, CP_ACP, Lost);
end;

function TypedIdeChar(Key: Char; var Pending: string): string;
var
  N: Integer;
begin
  Result := '';
  if IdeEncoding.CodePage = CP_UTF8 then
  begin
    { a byte that cannot go on with the bytes so far starts a character of its own }
    if (Pending <> '') and (Byte(Key) and $C0 <> $80) then Pending := '';
    Pending := Pending + Key;
    case Byte(Pending[1]) of
      $C0..$DF: N := 2;
      $E0..$EF: N := 3;
      $F0..$F7: N := 4;
    else
      N := 1;                  // ASCII; a stray continuation byte stands alone
    end;
  end
  else
  begin
    Pending := Pending + Key;
    if IsDBCSLeadByte(Byte(Pending[1])) then N := 2 else N := 1;
  end;
  if Length(Pending) < N then Exit;
  Result := Pending;
  Pending := '';
end;

procedure DeleteLastIdeChar(var S: string);
var
  L: Integer;
begin
  L := Length(S);
  if L = 0 then Exit;
  if IdeEncoding.CodePage = CP_UTF8 then
    while (L > 1) and (Byte(S[L]) and $C0 = $80) do Dec(L)
  else if (L > 1) and (ByteType(S, L) = mbTrailByte) then
    Dec(L);
  SetLength(S, L - 1);
end;

function FromWide(const W: WideString; CodePage: Integer; out Lost: Boolean): string;
var
  OK: Boolean;
begin
  Result := FromWide(W, CodePage, Lost, OK);
end;

function SwapBytes(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  I := 1;
  while I < Length(Result) do
  begin
    Result[I] := S[I + 1];
    Result[I + 1] := S[I];
    Inc(I, 2);
  end;
end;

{ Utf8Mode's strict test: no overlong forms, no UTF-16 surrogates, nothing above U+10FFFF }
function IsValidUtf8(const S: string): Boolean;
begin
  Result := Utf8Mode.IsValidUtf8(PChar(S), Length(S));
end;

function HasHighBytes(const S: string): Boolean;
begin
  Result := HasNonAscii(PChar(S), Length(S));
end;

{ UTF-16 bytes (no BOM) <-> UTF-8 }
function Utf16BytesToUtf8(const B: string; BigEndian: Boolean): string;
var
  W: WideString;
  S: string;
  Lost: Boolean;
begin
  if BigEndian then S := SwapBytes(B) else S := B;
  SetLength(W, Length(S) div 2);
  if W <> '' then Move(S[1], W[1], Length(W) * 2);
  Result := FromWide(W, CP_UTF8, Lost);
end;

function Utf8ToUtf16Bytes(const U: string; BigEndian: Boolean): string;
var
  W: WideString;
begin
  W := ToWide(U, CP_UTF8);
  SetLength(Result, Length(W) * 2);
  if W <> '' then Move(W[1], Result[1], Length(Result));
  if BigEndian then Result := SwapBytes(Result);
end;

function DetectEncoding(const Bytes: string): TSdEncoding;
begin
  if Copy(Bytes, 1, 3) = #$EF#$BB#$BF then Result := MakeEncoding(CP_UTF8, True)
  else if Copy(Bytes, 1, 2) = #$FF#$FE then Result := MakeEncoding(CP_UTF16LE, True)
  else if Copy(Bytes, 1, 2) = #$FE#$FF then Result := MakeEncoding(CP_UTF16BE, True)
  else if HasHighBytes(Bytes) and IsValidUtf8(Bytes) then Result := MakeEncoding(CP_UTF8, False)
  else Result := SystemEncoding;
end;

function DecodeFile(const Bytes: string; var E: TSdEncoding; Detect: Boolean): string;
begin
  if Detect then E := DetectEncoding(Bytes);
  case E.CodePage of
    CP_UTF8:
      { a byte order mark the file has stays with it when it is saved again (also when UTF-8 was
        given, not detected) }
      if Copy(Bytes, 1, 3) = #$EF#$BB#$BF then
      begin
        E.BOM := True;
        Result := Copy(Bytes, 4, MaxInt);
      end
      else
        Result := Bytes;
    CP_UTF16LE:
      if Copy(Bytes, 1, 2) = #$FF#$FE then Result := Utf16BytesToUtf8(Copy(Bytes, 3, MaxInt), False)
      else Result := Utf16BytesToUtf8(Bytes, False);
    CP_UTF16BE:
      if Copy(Bytes, 1, 2) = #$FE#$FF then Result := Utf16BytesToUtf8(Copy(Bytes, 3, MaxInt), True)
      else Result := Utf16BytesToUtf8(Bytes, True);
  else
    Result := Bytes;      // a code page: the editor keeps the bytes
  end;
end;

function EncodeFile(const Text: string; const E: TSdEncoding; out Lost: Boolean): string;
begin
  Lost := False;
  case E.CodePage of
    CP_UTF8:
      if E.BOM then Result := #$EF#$BB#$BF + Text else Result := Text;
    CP_UTF16LE: Result := #$FF#$FE + Utf8ToUtf16Bytes(Text, False);
    CP_UTF16BE: Result := #$FE#$FF + Utf8ToUtf16Bytes(Text, True);
  else
    Result := Text;
  end;
end;

function ConvertText(const Text: string; const A, B: TSdEncoding; out Res: string; out Lost: Boolean): Boolean;
var
  FromCP, ToCP: Integer;
  W: WideString;
begin
  Lost := False;
  Res := Text;
  Result := True;
  { the editor text of a Unicode encoding is UTF-8 }
  if IsUnicodeEncoding(A) then FromCP := CP_UTF8 else FromCP := A.CodePage;
  if IsUnicodeEncoding(B) then ToCP := CP_UTF8 else ToCP := B.CodePage;
  if FromCP = ToCP then Exit;
  W := ToWide(Text, FromCP, Result);
  if Result then Res := FromWide(W, ToCP, Lost, Result);
  if not Result then Res := '';
end;

function SystemToIde(const S: string): string;
var
  Lost: Boolean;
begin
  if not HasHighBytes(S) or not ConvertText(S, SystemEncoding, IdeEncoding, Result, Lost) then Result := S;
end;

function IdeToSystem(const S: string; out Lost: Boolean): string;
begin
  Lost := False;
  if not HasHighBytes(S) or not ConvertText(S, IdeEncoding, SystemEncoding, Result, Lost) then Result := S;
end;

function SystemFileToIde(const Bytes: string): string;
var
  E: TSdEncoding;
begin
  { ASCII is the same text in every code page }
  if not HasHighBytes(Bytes) then Result := Bytes
  else Result := EditorToAnsi(DecodeFile(Bytes, E, True), E);
end;

function IdeToSystemFile(const Text: string): string;
var
  Lost: Boolean;
begin
  Result := IdeToSystem(Text, Lost);
  if Lost then Result := AnsiToEditor(Text, MakeEncoding(CP_UTF8, False));
end;

{ a search string that cannot be converted is looked for as it was typed }
function AnsiToEditor(const S: string; const E: TSdEncoding): string;
var
  Lost: Boolean;
begin
  if not ConvertText(S, IdeEncoding, E, Result, Lost) then Result := S;
end;

function EditorToAnsi(const S: string; const E: TSdEncoding): string;
var
  Lost: Boolean;
begin
  if not ConvertText(S, E, IdeEncoding, Result, Lost) then Result := S;
end;

function EditorToWide(const S: string; const E: TSdEncoding): WideString;
begin
  if IsUnicodeEncoding(E) then Result := ToWide(S, CP_UTF8) else Result := ToWide(S, E.CodePage);
end;

end.
