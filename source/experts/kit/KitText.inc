{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

{ Text helpers of the IDE experts (source\experts\kit: the AI harness's unit AiText, the Git expert's
  GitText). The experts keep text as UTF-8 - the wire format of the model APIs, git's output; the
  IDE's strings are in the process code page (CP_ACP): UTF-8 in D7 Studio's UTF-8 mode, the system
  code page in Delphi 7's IDE. The conversions here go through WideString with explicit code pages,
  so they are right in both. Files on disk are read with their encoding detected (BOM, valid UTF-8,
  else the system code page) and written back in it. Text is built with TKitStringBuilder, which
  doubles its capacity: Delphi 7's TStringStream and repeated concatenation copy the whole text at
  every step.
  Also the experts' settings in the registry (KitReadRegString, KitWriteRegString) and a code
  address as module + offset (KitAddrInfo).
  The unit (interface: uses Windows, SysUtils, Classes; implementation: uses Registry) includes this
  file in its interface with KIT_INTERFACE defined and again in its implementation. }

{$IFDEF KIT_INTERFACE}

type
  TKitFileEncoding = (feAnsi, feUtf8, feUtf8Bom, feUtf16LE, feUtf16BE);

  { a string built piece by piece in amortized linear time }
  TKitStringBuilder = class
  private
    FData: string;
    FLen: Integer;
    procedure Grow(Need: Integer);
  public
    procedure Append(const S: string); overload;
    procedure Append(P: PChar; Count: Integer); overload;
    procedure AppendChar(C: Char);
    procedure Clear;
    { the text built so far }
    function Text: string;
    property Length: Integer read FLen;
  end;

{ ---- code pages }
function CodePageToWide(const S: string; CodePage: Cardinal): WideString;
function WideToCodePage(const W: WideString; CodePage: Cardinal): string;
function Utf8ToWide(const S: string): WideString;
function WideToUtf8(const W: WideString): string;
{ S has a byte of $80 or more }
function HasHighBytes(const S: string): Boolean;
{ IDE string (process code page) <-> UTF-8 }
function IdeToUtf8(const S: string): string;
function Utf8ToIde(const S: string): string;
{ the system's ANSI code page of programs without a UTF-8 manifest (never 65001): the code page
  of source files without a BOM and of dcc32 }
function SystemCodePage: Cardinal;
{ the process runs with UTF-8 as its ANSI code page (D7 Studio's UTF-8 mode) }
function ProcessIsUtf8: Boolean;
{ IDE string <-> the system code page (the compiler's) }
function IdeToSystem(const S: string): string;
function SystemToIde(const S: string): string;
function IsValidUtf8(const S: string): Boolean;
{ S with invalid UTF-8 sequences replaced by U+FFFD }
function SanitizeUtf8(const S: string): string;
{ at most MaxBytes of S, cut at a character boundary }
function TruncateUtf8(const S: string; MaxBytes: Integer): string;
{ S (an IDE string) without its last character: one of several bytes - UTF-8, a double-byte code
  page - goes whole }
function DropLastChar(const S: string): string;

{ ---- files: names in UTF-16 reach Windows as they are; the IDE's names (its code page) go through
  them. A file that cannot be opened raises EFOpenError, one that cannot be made EFCreateError }
function ReadFileW(const Name: WideString): string;
procedure WriteFileW(const Name: WideString; const Bytes: string);
function FileExistsW(const Name: WideString): Boolean;
function DirExistsW(const Name: WideString): Boolean;
function ReadFileBytes(const FileName: string): string;
procedure WriteFileBytes(const FileName, Bytes: string);
{ file bytes -> UTF-8, with the encoding found }
function DecodeText(const Bytes: string; out Encoding: TKitFileEncoding): string;
{ UTF-8 -> file bytes in Encoding }
function EncodeText(const Utf8: string; Encoding: TKitFileEncoding): string;
function ReadTextFile(const FileName: string; out Encoding: TKitFileEncoding): string;
{ the name after the last \ or / of a path (also of a UTF-8 path) }
function FileNamePart(const Path: string): string;

{ ---- lines (1-based lines and character positions) }
{ CR LF, LF and CR as NewLine }
function NormalizeNewLines(const S, NewLine: string): string;
function HasCrLf(const S: string): Boolean;
function CountLines(const S: string): Integer;
{ the position of the first character of Line; Length(S) + 1 for the line after the last; 0
  when the text has fewer lines }
function LineStart(const S: string; Line: Integer): Integer;
{ the line of position P }
function LineOfPos(const S: string; P: Integer): Integer;
{ lines FirstLine .. FirstLine + MaxLines - 1 of S, each as '<number><Tab><text>' (cat -n) }
function NumberedLines(const S: string; FirstLine, MaxLines: Integer; out Shown, Total: Integer): string;
function CountOccurrences(const S, Sub: string): Integer;
{ the position of Sub in S from Offset on (1-based), 0 when not found }
function PosFrom(const Sub, S: string; Offset: Integer): Integer;
{ S begins with Prefix (case-sensitive) }
function KitStartsWith(const S, Prefix: string): Boolean;
{ S without trailing white space }
function TrimRightText(const S: string): string;

{ ---- Base64 and secrets }
function Base64Encode(const S: string): string;
function Base64Decode(const S: string): string;
{ Plain encrypted for the current Windows user (DPAPI), as Base64 }
function ProtectSecret(const Plain: string): string;
{ the secret of ProtectSecret; '' when it cannot be decrypted (another user or machine) }
function UnprotectSecret(const Stored: string): string;

{ ---- settings and diagnostics }
{ the string value Name of HKEY_CURRENT_USER\Key; Default when the key or the value is missing }
function KitReadRegString(const Key, Name, Default: string): string;
{ the string value Name of HKEY_CURRENT_USER\Key written, the key made when it is missing }
procedure KitWriteRegString(const Key, Name, Value: string);
{ a code address as its pointer and module + offset ('00401234 (x.bpl+$1234)'): the module's map
  names the routine }
function KitAddrInfo(P: Pointer): string;

{$ELSE}

const
  LOCALE_IDEFAULTANSICODEPAGE_ = $1004;
  CRYPTPROTECT_UI_FORBIDDEN = 1;

type
  TDataBlob = record
    cbData: DWORD;
    pbData: Pointer;
  end;
  PDataBlob = ^TDataBlob;

function CryptProtectData(pDataIn: PDataBlob; szDataDescr: PWideChar; pOptionalEntropy: PDataBlob;
  pvReserved: Pointer; pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptProtectData';
function CryptUnprotectData(pDataIn: PDataBlob; ppszDataDescr: Pointer; pOptionalEntropy: PDataBlob;
  pvReserved: Pointer; pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptUnprotectData';

var
  FSystemCP: Cardinal;

{ ---------------------------------------------------------------- TKitStringBuilder }

procedure TKitStringBuilder.Grow(Need: Integer);
var
  Cap: Integer;
begin
  Cap := System.Length(FData);
  if FLen + Need <= Cap then Exit;
  Cap := Cap * 2;
  if Cap < FLen + Need then Cap := FLen + Need;
  if Cap < 64 then Cap := 64;
  SetLength(FData, Cap);
end;

procedure TKitStringBuilder.Append(P: PChar; Count: Integer);
begin
  if Count <= 0 then Exit;
  Grow(Count);
  Move(P^, FData[FLen + 1], Count);
  Inc(FLen, Count);
end;

procedure TKitStringBuilder.Append(const S: string);
begin
  if S <> '' then Append(PChar(S), System.Length(S));
end;

procedure TKitStringBuilder.AppendChar(C: Char);
begin
  Grow(1);
  Inc(FLen);
  FData[FLen] := C;
end;

procedure TKitStringBuilder.Clear;
begin
  FLen := 0;
end;

function TKitStringBuilder.Text: string;
begin
  Result := Copy(FData, 1, FLen);
end;

{ ---------------------------------------------------------------- code pages }

function CodePageToWide(const S: string; CodePage: Cardinal): WideString;
var
  N: Integer;
begin
  Result := '';
  if S = '' then Exit;
  N := MultiByteToWideChar(CodePage, 0, PChar(S), Length(S), nil, 0);
  if N <= 0 then Exit;
  SetLength(Result, N);
  MultiByteToWideChar(CodePage, 0, PChar(S), Length(S), PWideChar(Result), N);
end;

function WideToCodePage(const W: WideString; CodePage: Cardinal): string;
var
  N: Integer;
begin
  Result := '';
  if W = '' then Exit;
  N := WideCharToMultiByte(CodePage, 0, PWideChar(W), Length(W), nil, 0, nil, nil);
  if N <= 0 then Exit;
  SetLength(Result, N);
  WideCharToMultiByte(CodePage, 0, PWideChar(W), Length(W), PChar(Result), N, nil, nil);
end;

function Utf8ToWide(const S: string): WideString;
begin
  Result := CodePageToWide(S, CP_UTF8);
end;

function WideToUtf8(const W: WideString): string;
begin
  Result := WideToCodePage(W, CP_UTF8);
end;

function ProcessIsUtf8: Boolean;
begin
  Result := GetACP = CP_UTF8;
end;

function HasHighBytes(const S: string): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 1 to Length(S) do
    if Ord(S[I]) >= $80 then Exit;
  Result := False;
end;

function IdeToUtf8(const S: string): string;
begin
  if not HasHighBytes(S) then Result := S
  else if ProcessIsUtf8 then Result := SanitizeUtf8(S)
  else Result := WideToUtf8(CodePageToWide(S, CP_ACP));
end;

function Utf8ToIde(const S: string): string;
begin
  if ProcessIsUtf8 or not HasHighBytes(S) then Result := S
  else Result := WideToCodePage(Utf8ToWide(S), CP_ACP);
end;

function SystemCodePage: Cardinal;
var
  Buf: array[0..15] of WideChar;
  I: Integer;
  CP: Cardinal;
begin
  if FSystemCP = 0 then
  begin
    { worked out in a local: another thread may ask meanwhile }
    CP := 0;
    if GetLocaleInfoW(LOCALE_SYSTEM_DEFAULT, LOCALE_IDEFAULTANSICODEPAGE_, Buf, 16) > 0 then
    begin
      I := 0;
      while (I < 16) and (Buf[I] >= '0') and (Buf[I] <= '9') do
      begin
        CP := CP * 10 + Cardinal(Ord(Buf[I]) - Ord('0'));
        Inc(I);
      end;
    end;
    if (CP = 0) or (CP = CP_UTF8) then CP := 1252;
    FSystemCP := CP;
  end;
  Result := FSystemCP;
end;

function IdeToSystem(const S: string): string;
begin
  if not ProcessIsUtf8 or not HasHighBytes(S) then Result := S
  else Result := WideToCodePage(CodePageToWide(S, CP_ACP), SystemCodePage);
end;

function SystemToIde(const S: string): string;
begin
  if not ProcessIsUtf8 or not HasHighBytes(S) then Result := S
  else Result := WideToCodePage(CodePageToWide(S, SystemCodePage), CP_ACP);
end;

{ the length of the valid UTF-8 sequence at P (1..4), 0 when it is not one }
function Utf8SeqLen(P: PChar; Left: Integer): Integer;
var
  B0, B1: Byte;
  I: Integer;
begin
  Result := 0;
  B0 := Byte(P[0]);
  case B0 of
    $00..$7F: begin Result := 1; Exit; end;
    $C2..$DF: Result := 2;
    $E0..$EF: Result := 3;
    $F0..$F4: Result := 4;
  else
    Exit;
  end;
  if Result > Left then
  begin
    Result := 0;
    Exit;
  end;
  for I := 1 to Result - 1 do
    if (Byte(P[I]) and $C0) <> $80 then
    begin
      Result := 0;
      Exit;
    end;
  B1 := Byte(P[1]);
  case B0 of
    $E0: if B1 < $A0 then Result := 0;          // overlong
    $ED: if B1 > $9F then Result := 0;          // surrogates
    $F0: if B1 < $90 then Result := 0;          // overlong
    $F4: if B1 > $8F then Result := 0;          // above U+10FFFF
  end;
end;

function IsValidUtf8(const S: string): Boolean;
var
  I, N, L: Integer;
begin
  Result := False;
  I := 1;
  L := Length(S);
  while I <= L do
  begin
    if Ord(S[I]) < $80 then Inc(I)
    else
    begin
      N := Utf8SeqLen(@S[I], L - I + 1);
      if N = 0 then Exit;
      Inc(I, N);
    end;
  end;
  Result := True;
end;

function SanitizeUtf8(const S: string): string;
const
  Replacement = #$EF#$BF#$BD;
var
  I, N, L, Start: Integer;
  B: TKitStringBuilder;
begin
  if IsValidUtf8(S) then
  begin
    Result := S;
    Exit;
  end;
  B := TKitStringBuilder.Create;
  try
    I := 1;
    L := Length(S);
    Start := 1;
    while I <= L do
    begin
      if Ord(S[I]) < $80 then N := 1 else N := Utf8SeqLen(@S[I], L - I + 1);
      if N = 0 then
      begin
        { the valid run before it, then the replacement }
        B.Append(@S[Start], I - Start);
        B.Append(Replacement);
        Inc(I);
        Start := I;
      end
      else Inc(I, N);
    end;
    B.Append(@S[Start], L - Start + 1);
    Result := B.Text;
  finally
    B.Free;
  end;
end;

function TruncateUtf8(const S: string; MaxBytes: Integer): string;
var
  N: Integer;
begin
  if Length(S) <= MaxBytes then
  begin
    Result := S;
    Exit;
  end;
  N := MaxBytes;
  { back to the lead byte of a sequence }
  while (N > 0) and ((Byte(S[N + 1]) and $C0) = $80) do Dec(N);
  Result := Copy(S, 1, N);
end;

function DropLastChar(const S: string): string;
var
  N: Integer;
begin
  N := Length(S);
  if N = 0 then
  begin
    Result := '';
    Exit;
  end;
  if ProcessIsUtf8 then
    while (N > 1) and ((Byte(S[N]) and $C0) = $80) do Dec(N)
  else if (N > 1) and (ByteType(S, N) = mbTrailByte) then Dec(N);
  Result := Copy(S, 1, N - 1);
end;

{ ---------------------------------------------------------------- files }

{ the failure of a file's opening: the name and Windows' reason (read before anything else asks) }
function FileFailure(const Fmt: string; const Name: WideString): string;
var
  Err: DWORD;
begin
  Err := GetLastError;
  Result := Format(Fmt, [WideToCodePage(Name, CP_ACP), SysErrorMessage(Err)]);
end;

function ReadFileW(const Name: WideString): string;
var
  H: THandle;
  Size, Read: DWORD;
begin
  Result := '';
  H := CreateFileW(PWideChar(Name), GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
    nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if H = INVALID_HANDLE_VALUE then raise EFOpenError.CreateFmt('%s', [FileFailure('Cannot open file %s. %s', Name)]);
  try
    Size := GetFileSize(H, nil);
    SetLength(Result, Size);
    if (Size > 0) and (not ReadFile(H, Result[1], Size, Read, nil) or (Read <> Size)) then
      raise EFOpenError.CreateFmt('%s', [FileFailure('Cannot read file %s. %s', Name)]);
  finally
    CloseHandle(H);
  end;
end;

procedure WriteFileW(const Name: WideString; const Bytes: string);
var
  H: THandle;
  Written: DWORD;
begin
  H := CreateFileW(PWideChar(Name), GENERIC_WRITE, 0, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);
  if H = INVALID_HANDLE_VALUE then raise EFCreateError.CreateFmt('%s', [FileFailure('Cannot create file %s. %s', Name)]);
  try
    if (Bytes <> '') and (not WriteFile(H, Bytes[1], Length(Bytes), Written, nil) or
      (Written <> DWORD(Length(Bytes)))) then
      raise EFCreateError.CreateFmt('%s', [FileFailure('Cannot write file %s. %s', Name)]);
  finally
    CloseHandle(H);
  end;
end;

function FileExistsW(const Name: WideString): Boolean;
var
  A: DWORD;
begin
  A := GetFileAttributesW(PWideChar(Name));
  Result := (A <> $FFFFFFFF) and (A and FILE_ATTRIBUTE_DIRECTORY = 0);
end;

function DirExistsW(const Name: WideString): Boolean;
var
  A: DWORD;
begin
  A := GetFileAttributesW(PWideChar(Name));
  Result := (A <> $FFFFFFFF) and (A and FILE_ATTRIBUTE_DIRECTORY <> 0);
end;

function ReadFileBytes(const FileName: string): string;
begin
  Result := ReadFileW(CodePageToWide(FileName, CP_ACP));
end;

procedure WriteFileBytes(const FileName, Bytes: string);
begin
  WriteFileW(CodePageToWide(FileName, CP_ACP), Bytes);
end;

function SwapBytes16(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := S;
  UniqueString(Result);
  I := 1;
  while I < Length(Result) do
  begin
    C := Result[I];
    Result[I] := Result[I + 1];
    Result[I + 1] := C;
    Inc(I, 2);
  end;
end;

function Utf16BytesToUtf8(const Bytes: string): string;
var
  W: WideString;
  N: Integer;
begin
  N := Length(Bytes) div 2;
  SetLength(W, N);
  if N > 0 then Move(Bytes[1], W[1], N * 2);
  Result := WideToUtf8(W);
end;

function DecodeText(const Bytes: string; out Encoding: TKitFileEncoding): string;
begin
  if Copy(Bytes, 1, 3) = #$EF#$BB#$BF then
  begin
    Encoding := feUtf8Bom;
    Result := SanitizeUtf8(Copy(Bytes, 4, MaxInt));
  end
  else if Copy(Bytes, 1, 2) = #$FF#$FE then
  begin
    Encoding := feUtf16LE;
    Result := Utf16BytesToUtf8(Copy(Bytes, 3, MaxInt));
  end
  else if Copy(Bytes, 1, 2) = #$FE#$FF then
  begin
    Encoding := feUtf16BE;
    Result := Utf16BytesToUtf8(SwapBytes16(Copy(Bytes, 3, MaxInt)));
  end
  else if not HasHighBytes(Bytes) then
  begin
    { plain ASCII is ANSI too: such a file is written back in the system code page }
    Encoding := feAnsi;
    Result := Bytes;
  end
  else if IsValidUtf8(Bytes) then
  begin
    Encoding := feUtf8;
    Result := Bytes;
  end
  else
  begin
    Encoding := feAnsi;
    Result := WideToUtf8(CodePageToWide(Bytes, SystemCodePage));
  end;
end;

function EncodeText(const Utf8: string; Encoding: TKitFileEncoding): string;
var
  W: WideString;
  B: string;
begin
  case Encoding of
    feUtf8: Result := Utf8;
    feUtf8Bom: Result := #$EF#$BB#$BF + Utf8;
    feUtf16LE, feUtf16BE:
      begin
        W := Utf8ToWide(Utf8);
        SetLength(B, Length(W) * 2);
        if W <> '' then Move(W[1], B[1], Length(B));
        if Encoding = feUtf16LE then Result := #$FF#$FE + B
        else Result := #$FE#$FF + SwapBytes16(B);
      end;
  else
    if HasHighBytes(Utf8) then Result := WideToCodePage(Utf8ToWide(Utf8), SystemCodePage)
    else Result := Utf8;
  end;
end;

function ReadTextFile(const FileName: string; out Encoding: TKitFileEncoding): string;
begin
  Result := DecodeText(ReadFileBytes(FileName), Encoding);
end;

function FileNamePart(const Path: string): string;
var
  I: Integer;
begin
  for I := Length(Path) downto 1 do
    if Path[I] in ['\', '/'] then
    begin
      Result := Copy(Path, I + 1, MaxInt);
      Exit;
    end;
  Result := Path;
end;

{ ---------------------------------------------------------------- lines }

function NormalizeNewLines(const S, NewLine: string): string;
var
  I, L, Start: Integer;
  B: TKitStringBuilder;
begin
  { nothing to do: no CR, and LF is what is asked for or there is none }
  if (Pos(#13, S) = 0) and ((NewLine = #10) or (Pos(#10, S) = 0)) then
  begin
    Result := S;
    Exit;
  end;
  B := TKitStringBuilder.Create;
  try
    I := 1;
    L := Length(S);
    Start := 1;
    while I <= L do
    begin
      if S[I] in [#13, #10] then
      begin
        B.Append(@S[Start], I - Start);
        B.Append(NewLine);
        if (S[I] = #13) and (I < L) and (S[I + 1] = #10) then Inc(I);
        Start := I + 1;
      end;
      Inc(I);
    end;
    B.Append(@S[Start], L - Start + 1);
    Result := B.Text;
  finally
    B.Free;
  end;
end;

function HasCrLf(const S: string): Boolean;
begin
  Result := Pos(#13#10, S) > 0;
end;

function CountLines(const S: string): Integer;
var
  I: Integer;
begin
  if S = '' then
  begin
    Result := 0;
    Exit;
  end;
  Result := 1;
  for I := 1 to Length(S) do
    if S[I] = #10 then Inc(Result);
  { a final line break ends the last line: no empty line after it }
  if S[Length(S)] = #10 then Dec(Result);
end;

function LineStart(const S: string; Line: Integer): Integer;
var
  I, L: Integer;
begin
  Result := 0;
  if Line < 1 then Exit;
  if Line = 1 then
  begin
    Result := 1;
    Exit;
  end;
  L := 1;
  for I := 1 to Length(S) do
    if S[I] = #10 then
    begin
      Inc(L);
      if L = Line then
      begin
        Result := I + 1;
        Exit;
      end;
    end;
end;

function LineOfPos(const S: string; P: Integer): Integer;
var
  I: Integer;
begin
  Result := 1;
  if P > Length(S) + 1 then P := Length(S) + 1;
  for I := 1 to P - 1 do
    if S[I] = #10 then Inc(Result);
end;

function NumberedLines(const S: string; FirstLine, MaxLines: Integer; out Shown, Total: Integer): string;
var
  B: TKitStringBuilder;
  I, L, Line, Start, Len: Integer;
begin
  Total := CountLines(S);
  Shown := 0;
  if FirstLine < 1 then FirstLine := 1;
  B := TKitStringBuilder.Create;
  try
    Line := 1;
    Start := 1;
    L := Length(S);
    I := 1;
    while (I <= L + 1) and (Line < FirstLine + MaxLines) do
    begin
      if (I > L) or (S[I] = #10) then
      begin
        if (I > L) and (Start > L) then Break;    // no text after the last line break
        if Line >= FirstLine then
        begin
          Len := I - Start;
          if (Len > 0) and (S[Start + Len - 1] = #13) then Dec(Len);
          B.Append(Format('%6d'#9, [Line]));
          B.Append(@S[Start], Len);
          B.AppendChar(#10);
          Inc(Shown);
        end;
        Inc(Line);
        Start := I + 1;
      end;
      Inc(I);
    end;
    Result := B.Text;
  finally
    B.Free;
  end;
end;

function PosFrom(const Sub, S: string; Offset: Integer): Integer;
var
  I, N, Last: Integer;
  First: Char;
begin
  Result := 0;
  N := Length(Sub);
  if (N = 0) or (Offset < 1) then Exit;
  Last := Length(S) - N + 1;
  First := Sub[1];
  for I := Offset to Last do
    if (S[I] = First) and ((N = 1) or CompareMem(@S[I + 1], @Sub[2], N - 1)) then
    begin
      Result := I;
      Exit;
    end;
end;

function KitStartsWith(const S, Prefix: string): Boolean;
begin
  Result := (Length(S) >= Length(Prefix)) and
    ((Prefix = '') or CompareMem(Pointer(S), Pointer(Prefix), Length(Prefix)));
end;

function CountOccurrences(const S, Sub: string): Integer;
var
  P: Integer;
begin
  Result := 0;
  if Sub = '' then Exit;
  P := PosFrom(Sub, S, 1);
  while P > 0 do
  begin
    Inc(Result);
    P := PosFrom(Sub, S, P + Length(Sub));
  end;
end;

function TrimRightText(const S: string): string;
var
  N: Integer;
begin
  N := Length(S);
  while (N > 0) and (S[N] <= ' ') do Dec(N);
  Result := Copy(S, 1, N);
end;

{ ---------------------------------------------------------------- Base64 }

const
  B64: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function Base64Encode(const S: string): string;
var
  I, N, V, O: Integer;
begin
  N := Length(S);
  SetLength(Result, ((N + 2) div 3) * 4);
  I := 1;
  O := 1;
  while I <= N do
  begin
    V := Ord(S[I]) shl 16;
    if I + 1 <= N then V := V or (Ord(S[I + 1]) shl 8);
    if I + 2 <= N then V := V or Ord(S[I + 2]);
    Result[O] := B64[(V shr 18) and 63 + 1];
    Result[O + 1] := B64[(V shr 12) and 63 + 1];
    if I + 1 <= N then Result[O + 2] := B64[(V shr 6) and 63 + 1] else Result[O + 2] := '=';
    if I + 2 <= N then Result[O + 3] := B64[V and 63 + 1] else Result[O + 3] := '=';
    Inc(I, 3);
    Inc(O, 4);
  end;
end;

function Base64Decode(const S: string): string;
var
  I, V, Bits, D, O: Integer;
  C: Char;
begin
  SetLength(Result, (Length(S) * 3) div 4 + 3);
  O := 0;
  V := 0;
  Bits := 0;
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      'A'..'Z': D := Ord(C) - Ord('A');
      'a'..'z': D := Ord(C) - Ord('a') + 26;
      '0'..'9': D := Ord(C) - Ord('0') + 52;
      '+', '-': D := 62;
      '/', '_': D := 63;
    else
      D := -1;       // padding, line breaks
    end;
    if D < 0 then Continue;
    V := ((V shl 6) or D) and $FFFFFF;
    Inc(Bits, 6);
    if Bits >= 8 then
    begin
      Dec(Bits, 8);
      Inc(O);
      Result[O] := Chr((V shr Bits) and $FF);
    end;
  end;
  SetLength(Result, O);
end;

{ ---------------------------------------------------------------- secrets }

function ProtectSecret(const Plain: string): string;
var
  InBlob, OutBlob: TDataBlob;
  Data: string;
begin
  Result := '';
  if Plain = '' then Exit;
  InBlob.cbData := Length(Plain);
  InBlob.pbData := PChar(Plain);
  OutBlob.cbData := 0;
  OutBlob.pbData := nil;
  if not CryptProtectData(@InBlob, nil, nil, nil, nil, CRYPTPROTECT_UI_FORBIDDEN, @OutBlob) then
    RaiseLastOSError;
  try
    SetLength(Data, OutBlob.cbData);
    if OutBlob.cbData > 0 then Move(OutBlob.pbData^, Data[1], OutBlob.cbData);
  finally
    LocalFree(HLOCAL(OutBlob.pbData));
  end;
  Result := Base64Encode(Data);
end;

function UnprotectSecret(const Stored: string): string;
var
  InBlob, OutBlob: TDataBlob;
  Data: string;
begin
  Result := '';
  Data := Base64Decode(Stored);
  if Data = '' then Exit;
  InBlob.cbData := Length(Data);
  InBlob.pbData := PChar(Data);
  OutBlob.cbData := 0;
  OutBlob.pbData := nil;
  if not CryptUnprotectData(@InBlob, nil, nil, nil, nil, CRYPTPROTECT_UI_FORBIDDEN, @OutBlob) then Exit;
  try
    SetLength(Result, OutBlob.cbData);
    if OutBlob.cbData > 0 then Move(OutBlob.pbData^, Result[1], OutBlob.cbData);
  finally
    LocalFree(HLOCAL(OutBlob.pbData));
  end;
end;

{ ---------------------------------------------------------------- settings and diagnostics }

function KitReadRegString(const Key, Name, Default: string): string;
var
  R: TRegistry;
begin
  Result := Default;
  R := TRegistry.Create(KEY_READ);
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKeyReadOnly(Key) then
    begin
      if R.ValueExists(Name) then Result := R.ReadString(Name);
      R.CloseKey;
    end;
  finally
    R.Free;
  end;
end;

procedure KitWriteRegString(const Key, Name, Value: string);
var
  R: TRegistry;
begin
  R := TRegistry.Create;
  try
    R.RootKey := HKEY_CURRENT_USER;
    if R.OpenKey(Key, True) then
    begin
      R.WriteString(Name, Value);
      R.CloseKey;
    end;
  finally
    R.Free;
  end;
end;

function KitAddrInfo(P: Pointer): string;
var
  MBI: TMemoryBasicInformation;
  Name: array[0..MAX_PATH] of Char;
begin
  Result := Format('%p', [P]);
  if (P = nil) or (VirtualQuery(P, MBI, SizeOf(MBI)) = 0) or (MBI.AllocationBase = nil) then Exit;
  Name[0] := #0;
  GetModuleFileName(HMODULE(MBI.AllocationBase), Name, MAX_PATH);
  Result := Result + Format(' (%s+$%x)', [ExtractFileName(Name), Cardinal(P) - Cardinal(MBI.AllocationBase)]);
end;

{$ENDIF}
