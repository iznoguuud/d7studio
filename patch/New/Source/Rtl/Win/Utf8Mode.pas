{**********************************************************}
{                                                          }
{     Delphi 7 Runtime Library - Modernization             }
{     UTF-8 process code page support                      }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit Utf8Mode;

{ "Native Unicode" for Delphi 7.

  The Delphi 7 compiler fixes `string` to AnsiString. Windows 10 1903+ lets a
  program declare UTF-8 as its ANSI code page (manifest element
  <activeCodePage>UTF-8</activeCodePage>, see the ModernMan* units). In that
  mode every AnsiString holds UTF-8 and most -A APIs convert UTF-8 <-> UTF-16, so
  the whole RTL/VCL can display, edit, store and pass any Unicode text.

  A number of -A APIs do NOT honour the UTF-8 process code page (measured on
  Windows 11 26200): GDI/user32 text output and measurement (they use the code
  page of the font charset), CompareStringA and the locale functions (they use
  the locale's code page), and the WM_CHAR conversion done by PeekMessageA,
  GetMessageA, DispatchMessageW and CallWindowProcA (keyboard code page).
  When the process runs in UTF-8 mode this unit redirects those imports of the
  module that contains it (the EXE when linked statically) to small shims
  that convert UTF-8 <-> UTF-16 and call the -W function. A shim only takes
  the Unicode path for strings that contain non-ASCII bytes AND are valid
  UTF-8; ASCII and legacy (invalid UTF-8) text keeps going to the original -A
  function, so behaviour can only improve.

  Keyboard input: non-ASCII characters are delivered to ANSI (VCL) windows as
  a sequence of WM_CHAR messages carrying the UTF-8 bytes, so OnKeyPress sees
  the same bytes that end up in Text. The bytes are reassembled before they
  reach a Unicode window procedure (CallWindowProcA/DefWindowProcA/
  DispatchMessageA shims), so native controls receive the real character.

  Nothing in this unit does anything unless GetACP = CP_UTF8. Set the
  environment variable D7_UTF8_SHIMS=0 to disable the import redirection. }

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  Windows;

{ True when the process ANSI code page is UTF-8. }
function IsUtf8Mode: Boolean;

{ The system's legacy ANSI code page (e.g. 1252, 1253), independent of the
  UTF-8 process code page. }
function SystemLegacyCodePage: Cardinal;

var
  { Code page of ANSI string properties stored in DFM resources. The Delphi 7
    IDE writes them in the code page of the machine the form was designed on.
    0 = SystemLegacyCodePage. Only used in UTF-8 mode, and only for strings
    that are not valid UTF-8. Set it early (e.g. in the .dpr before
    Application.Initialize) when your forms were designed with another code
    page, e.g. DfmCodePage := 1253 for Greek. }
  DfmCodePage: Cardinal = 0;

  { Code page assumed by TStrings.LoadFromFile/LoadFromStream for text files
    without a BOM that are not valid UTF-8 (legacy ANSI files). 0 =
    SystemLegacyCodePage. Only used in UTF-8 mode. }
  LegacyTextCodePage: Cardinal = 0;

{ ---- UTF-8 helpers (work in every mode) ---- }

{ Byte length of the UTF-8 sequence that starts with Lead (1..4), 0 if Lead
  is not a valid lead byte. }
function Utf8SequenceLength(Lead: Char): Integer;
{ Strict UTF-8 validation (no overlong forms, no surrogates, max U+10FFFF). }
function IsValidUtf8(P: PChar; Len: Integer): Boolean; overload;
function IsValidUtf8(const S: string): Boolean; overload;
{ True when the buffer contains a byte >= $80. }
function HasNonAscii(P: PChar; Len: Integer): Boolean;

{ Code page conversions (CodePage 0 = CP_ACP). }
function CodePageToWide(const S: string; CodePage: Cardinal): WideString;
function WideToCodePage(const W: WideString; CodePage: Cardinal): string;
{ Converts text stored in a legacy code page to the process code page. In
  UTF-8 mode, valid UTF-8 input is returned unchanged; outside UTF-8 mode the
  input is returned unchanged. CodePage 0 = SystemLegacyCodePage. }
function LegacyToAnsi(const S: string; CodePage: Cardinal = 0): string;

{ Position mapping between UTF-8 byte offsets and UTF-16 code unit offsets
  (used for edit-control selections in UTF-8 mode). Offsets are 0-based. }
function Utf8OffsetToUtf16(const S: string; ByteOffset: Integer): Integer;
function Utf16OffsetToUtf8(const S: string; Utf16Offset: Integer): Integer;
{ Same mapping for a UTF-16 string (the text as Windows stores it). }
function WideOffsetToUtf8(const W: WideString; Utf16Offset: Integer): Integer;
function Utf8OffsetToWide(const W: WideString; ByteOffset: Integer): Integer;

{ Redirects the -A imports of Module (see above). Called automatically for
  the module that contains this unit; call it for other modules (packages,
  DLLs) that need it. Does nothing outside UTF-8 mode. }
procedure InstallUtf8Shims(Module: HMODULE);

{ Number of import slots redirected so far (diagnostics). }
function Utf8ShimsInstalled: Integer;

{ Redirects the -A imports of every Delphi module in the process: the
  program, the runtime packages and Delphi DLLs (System.LibModuleList). With
  runtime packages each package calls the -A functions through its own
  imports (the VCL draws text from vcl70.bpl). Called automatically at
  start-up and by SysUtils.LoadPackage, before the new package initializes;
  call it after loading Delphi DLLs in other ways. Modules already handled
  are left as they are. Does nothing outside UTF-8 mode or when
  D7_UTF8_SHIMS=0. }
procedure InstallUtf8ShimsForModules;

{ Detects UTF-8 mode and installs the shims, once. Runs in the initialization
  of this unit and, earlier, at the start of SysUtils' initialization: a
  program compiled against Borland's original rtl.dcp but running on the
  modernized rtl70.bpl does not list this unit in its initialization table
  (the original SysUtils does not use it), so this unit's initialization
  would not run there. IsUtf8Mode also calls it on first use. }
procedure InitializeUtf8Mode;

{ CreateWindowExA - or, in UTF-8 mode, CreateWindowExW (the class and window names converted from
  UTF-8) when DefWndProc, the window procedure the control passes its messages on to, is user32's
  own EDIT or COMBOBOX (no visual styles: comctl32 6's are not affected). Made by CreateWindowExA,
  user32's edit keeps its text as ANSI bytes and draws them through the code page of the font's
  charset: UTF-8 showed as Latin-1, and its positions counted bytes. Made by CreateWindowExW -
  with the same ANSI class and window procedure - it keeps Unicode text, draws it, answers the
  ANSI messages in exact UTF-8, and counts positions in UTF-16 units, as comctl32 6's edit does.
  A classic combo box makes its edit child the way it was made itself. TWinControl and TCustomMemo
  create their windows through this. }
function CreateWindowUtf8(ExStyle: DWORD; ClassName, WindowName: PChar; Style: DWORD;
  X, Y, Width, Height: Integer; Parent: HWND; Menu: HMENU; Instance: HINST; Param: Pointer;
  DefWndProc: Pointer): HWND;

implementation

uses
  Messages;

const
  CP_UTF8_ = 65001;
  LOCALE_RETURN_NUMBER_ = $20000000;
  LOCALE_IDEFAULTANSICODEPAGE_ = $00001004;

var
  FUtf8Mode: Boolean;
  FLegacyCP: Cardinal;
  FShimCount: Integer;
  FInitialized: Boolean;

function IsUtf8Mode: Boolean;
begin
  if not FInitialized then
    InitializeUtf8Mode;
  Result := FUtf8Mode;
end;

function SystemLegacyCodePage: Cardinal;
var
  Buf: array[0..15] of WideChar;
  I: Integer;
begin
  if FLegacyCP = 0 then
  begin
    FLegacyCP := 1252;
    if GetLocaleInfoW(LOCALE_SYSTEM_DEFAULT, LOCALE_IDEFAULTANSICODEPAGE_, Buf, 16) > 0 then
    begin
      I := 0;
      FLegacyCP := 0;
      while (I < 16) and (Buf[I] >= '0') and (Buf[I] <= '9') do
      begin
        FLegacyCP := FLegacyCP * 10 + Cardinal(Ord(Buf[I]) - Ord('0'));
        Inc(I);
      end;
      if (FLegacyCP = 0) or (FLegacyCP = CP_UTF8_) then
        FLegacyCP := 1252;
    end;
  end;
  Result := FLegacyCP;
end;

{ ---- UTF-8 helpers ---- }

function Utf8SequenceLength(Lead: Char): Integer;
begin
  case Byte(Lead) of
    $00..$7F: Result := 1;
    $C2..$DF: Result := 2;
    $E0..$EF: Result := 3;
    $F0..$F4: Result := 4;
  else
    Result := 0;
  end;
end;

function IsValidUtf8(P: PChar; Len: Integer): Boolean;
var
  I, N, K: Integer;
  B, B2: Byte;
begin
  Result := False;
  if P = nil then
  begin
    Result := Len <= 0;
    Exit;
  end;
  if Len < 0 then
    Len := lstrlenA(P);
  I := 0;
  while I < Len do
  begin
    B := Byte(P[I]);
    if B < $80 then
    begin
      Inc(I);
      Continue;
    end;
    N := Utf8SequenceLength(Char(B));
    if (N = 0) or (I + N > Len) then Exit;
    B2 := Byte(P[I + 1]);
    case B of
      $E0: if B2 < $A0 then Exit;              // overlong
      $ED: if B2 > $9F then Exit;              // UTF-16 surrogate
      $F0: if B2 < $90 then Exit;              // overlong
      $F4: if B2 > $8F then Exit;              // > U+10FFFF
    end;
    for K := 1 to N - 1 do
      if (Byte(P[I + K]) and $C0) <> $80 then Exit;
    Inc(I, N);
  end;
  Result := True;
end;

function IsValidUtf8(const S: string): Boolean;
begin
  Result := IsValidUtf8(PChar(S), Length(S));
end;

function HasNonAscii(P: PChar; Len: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  if P = nil then Exit;
  if Len < 0 then
  begin
    while P^ <> #0 do
    begin
      if Byte(P^) >= $80 then
      begin
        Result := True;
        Exit;
      end;
      Inc(P);
    end;
    Exit;
  end;
  for I := 0 to Len - 1 do
    if Byte(P[I]) >= $80 then
    begin
      Result := True;
      Exit;
    end;
end;

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

function LegacyToAnsi(const S: string; CodePage: Cardinal): string;
begin
  if not IsUtf8Mode or not HasNonAscii(PChar(S), Length(S)) or IsValidUtf8(S) then
  begin
    Result := S;
    Exit;
  end;
  if CodePage = 0 then
    CodePage := SystemLegacyCodePage;
  Result := WideToCodePage(CodePageToWide(S, CodePage), CP_UTF8_);
end;

function Utf8OffsetToUtf16(const S: string; ByteOffset: Integer): Integer;
var
  I, N: Integer;
begin
  Result := 0;
  I := 1;
  while (I <= Length(S)) and (I <= ByteOffset) do
  begin
    N := Utf8SequenceLength(S[I]);
    if N = 0 then N := 1;
    if N = 4 then Inc(Result, 2) else Inc(Result);
    Inc(I, N);
  end;
end;

function Utf16OffsetToUtf8(const S: string; Utf16Offset: Integer): Integer;
var
  I, N, U: Integer;
begin
  I := 1;
  U := 0;
  while (I <= Length(S)) and (U < Utf16Offset) do
  begin
    N := Utf8SequenceLength(S[I]);
    if N = 0 then N := 1;
    if N = 4 then Inc(U, 2) else Inc(U);
    Inc(I, N);
  end;
  if I > Length(S) + 1 then
    I := Length(S) + 1;
  Result := I - 1;
end;

function WideOffsetToUtf8(const W: WideString; Utf16Offset: Integer): Integer;
var
  I: Integer;
  C: Word;
begin
  Result := 0;
  if Utf16Offset > Length(W) then
    Utf16Offset := Length(W);
  I := 1;
  while I <= Utf16Offset do
  begin
    C := Word(W[I]);
    if C < $80 then Inc(Result)
    else if C < $800 then Inc(Result, 2)
    else if (C >= $D800) and (C <= $DBFF) and (I < Length(W)) then
    begin
      Inc(Result, 4);
      Inc(I);
    end
    else Inc(Result, 3);
    Inc(I);
  end;
end;

function Utf8OffsetToWide(const W: WideString; ByteOffset: Integer): Integer;
var
  I, B, Step: Integer;
  C: Word;
begin
  I := 1;
  B := 0;
  while (I <= Length(W)) and (B < ByteOffset) do
  begin
    C := Word(W[I]);
    if C < $80 then Step := 1
    else if C < $800 then Step := 2
    else if (C >= $D800) and (C <= $DBFF) and (I < Length(W)) then
    begin
      Step := 4;
      Inc(I);
    end
    else Step := 3;
    Inc(B, Step);
    Inc(I);
  end;
  Result := I - 1;
end;

{ ---- conversion buffers for the shims (no heap use for short strings) ---- }

type
  TWideBuf = record
    P: PWideChar;
    Len: Integer;
    Heap: Boolean;
    Stack: array[0..511] of WideChar;
  end;

{ Converts Count UTF-8 bytes (-1 = zero terminated, terminator excluded). }
procedure ToWide(var B: TWideBuf; Src: PChar; Count: Integer);
var
  N: Integer;
begin
  B.Heap := False;
  B.P := @B.Stack[0];
  B.Len := 0;
  if Count < 0 then
    Count := lstrlenA(Src);
  if Count = 0 then
  begin
    B.Stack[0] := #0;
    Exit;
  end;
  N := MultiByteToWideChar(CP_UTF8_, 0, Src, Count, nil, 0);
  if N + 1 > Length(B.Stack) then
  begin
    GetMem(B.P, (N + 1) * SizeOf(WideChar));
    B.Heap := True;
  end;
  B.Len := MultiByteToWideChar(CP_UTF8_, 0, Src, Count, B.P, N);
  B.P[B.Len] := #0;
end;

procedure FreeWide(var B: TWideBuf);
begin
  if B.Heap then
    FreeMem(B.P);
  B.Heap := False;
end;

{ True when the text should take the Unicode path. }
function WantsWide(Src: PChar; Count: Integer): Boolean;
begin
  Result := (Src <> nil) and (Count <> 0) and HasNonAscii(Src, Count) and IsValidUtf8(Src, Count);
end;

{ Number of UTF-8 bytes used by the first Units UTF-16 code units of W. }
function BytesForUnits(W: PWideChar; Units: Integer): Integer;
var
  I: Integer;
  C: Word;
begin
  Result := 0;
  I := 0;
  while I < Units do
  begin
    C := Word(W[I]);
    if C < $80 then Inc(Result)
    else if C < $800 then Inc(Result, 2)
    else if (C >= $D800) and (C <= $DBFF) and (I + 1 < Units) then
    begin
      Inc(Result, 4);
      Inc(I);
    end
    else Inc(Result, 3);
    Inc(I);
  end;
end;

{ Copies UTF-16 text to an ANSI (UTF-8) output buffer of Size bytes, always
  zero terminated when Size > 0. Returns bytes written (without terminator). }
function WideToBuffer(W: PWideChar; Units: Integer; Dest: PChar; Size: Integer): Integer;
begin
  Result := 0;
  if (Dest = nil) or (Size <= 0) then Exit;
  if Units > 0 then
    Result := WideCharToMultiByte(CP_UTF8_, 0, W, Units, Dest, Size - 1, nil, nil);
  Dest[Result] := #0;
end;

{ ---- original entry points ---- }

type
  TTextOutA = function(DC: HDC; X, Y: Integer; Str: PChar; Count: Integer): BOOL; stdcall;
  TExtTextOutA = function(DC: HDC; X, Y: Integer; Options: Longint; Rect: PRect; Str: PChar;
    Count: Longint; Dx: PInteger): BOOL; stdcall;
  TGetTextExtentPointA = function(DC: HDC; Str: PChar; Count: Integer; var Size: TSize): BOOL; stdcall;
  TGetTextExtentExPointA = function(DC: HDC; Str: PChar; Count, MaxExtent: Integer;
    Fit, Dx: PInteger; var Size: TSize): BOOL; stdcall;
  TDrawTextA = function(DC: HDC; Str: PChar; Count: Integer; var Rect: TRect; Format: UINT): Integer; stdcall;
  TDrawTextExA = function(DC: HDC; Str: PChar; Count: Integer; var Rect: TRect; Format: UINT;
    Params: PDrawTextParams): Integer; stdcall;
  TTabbedTextOutA = function(DC: HDC; X, Y: Integer; Str: PChar; Count, nTabPositions: Integer;
    TabStops: PInteger; nTabOrigin: Integer): Longint; stdcall;
  TGetTabbedTextExtentA = function(DC: HDC; Str: PChar; Count, nTabPositions: Integer;
    TabStops: PInteger): DWORD; stdcall;
  TGrayStringA = function(DC: HDC; Brush: HBRUSH; OutputFunc: Pointer; Data: LPARAM;
    Count, X, Y, Width, Height: Integer): BOOL; stdcall;
  TCreateFontIndirectA = function(const LogFont: TLogFontA): HFONT; stdcall;
  TCreateFontA = function(nHeight, nWidth, nEscapement, nOrientaion, fnWeight: Integer;
    fdwItalic, fdwUnderline, fdwStrikeOut, fdwCharSet, fdwOutputPrecision, fdwClipPrecision,
    fdwQuality, fdwPitchAndFamily: DWORD; lpszFace: PChar): HFONT; stdcall;
  TCompareStringA = function(Locale: LCID; Flags: DWORD; S1: PChar; C1: Integer; S2: PChar;
    C2: Integer): Integer; stdcall;
  TGetLocaleInfoA = function(Locale: LCID; LCType: DWORD; Data: PChar; cchData: Integer): Integer; stdcall;
  TGetDateTimeFormatA = function(Locale: LCID; Flags: DWORD; Time: PSystemTime; Format: PChar;
    Dest: PChar; cchDest: Integer): Integer; stdcall;
  TPeekMessageA = function(var Msg: TMsg; Wnd: HWND; FilterMin, FilterMax, RemoveMsg: UINT): BOOL; stdcall;
  TGetMessageA = function(var Msg: TMsg; Wnd: HWND; FilterMin, FilterMax: UINT): BOOL; stdcall;
  TDispatchMessageA = function(const Msg: TMsg): Longint; stdcall;
  TIsDialogMessageA = function(Dlg: HWND; var Msg: TMsg): BOOL; stdcall;
  TCallWindowProcA = function(PrevProc: Pointer; Wnd: HWND; Msg: UINT; WParam: WPARAM;
    LParam: LPARAM): LRESULT; stdcall;
  TDefWindowProcA = function(Wnd: HWND; Msg: UINT; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
  TDefFrameProcA = function(Wnd, MDIClient: HWND; Msg: UINT; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;

var
  Orig_TextOutA: TTextOutA;
  Orig_ExtTextOutA: TExtTextOutA;
  Orig_GetTextExtentPoint32A: TGetTextExtentPointA;
  Orig_GetTextExtentPointA: TGetTextExtentPointA;
  Orig_GetTextExtentExPointA: TGetTextExtentExPointA;
  Orig_DrawTextA: TDrawTextA;
  Orig_DrawTextExA: TDrawTextExA;
  Orig_TabbedTextOutA: TTabbedTextOutA;
  Orig_GetTabbedTextExtentA: TGetTabbedTextExtentA;
  Orig_GrayStringA: TGrayStringA;
  Orig_CreateFontIndirectA: TCreateFontIndirectA;
  Orig_CreateFontA: TCreateFontA;
  Orig_CompareStringA: TCompareStringA;
  Orig_GetLocaleInfoA: TGetLocaleInfoA;
  Orig_GetDateFormatA: TGetDateTimeFormatA;
  Orig_GetTimeFormatA: TGetDateTimeFormatA;
  Orig_PeekMessageA: TPeekMessageA;
  Orig_GetMessageA: TGetMessageA;
  Orig_DispatchMessageA: TDispatchMessageA;
  Orig_IsDialogMessageA: TIsDialogMessageA;
  Orig_CallWindowProcA: TCallWindowProcA;
  Orig_DefWindowProcA: TDefWindowProcA;
  Orig_DefDlgProcA: TDefWindowProcA;
  Orig_DefMDIChildProcA: TDefWindowProcA;
  Orig_DefFrameProcA: TDefFrameProcA;

{ ---- text output / measurement shims ---- }

function Shim_TextOutA(DC: HDC; X, Y: Integer; Str: PChar; Count: Integer): BOOL; stdcall;
var
  B: TWideBuf;
begin
  if WantsWide(Str, Count) then
  begin
    ToWide(B, Str, Count);
    try
      Result := TextOutW(DC, X, Y, B.P, B.Len);
    finally
      FreeWide(B);
    end;
  end
  else
    Result := Orig_TextOutA(DC, X, Y, Str, Count);
end;

function Shim_ExtTextOutA(DC: HDC; X, Y: Integer; Options: Longint; Rect: PRect; Str: PChar;
  Count: Longint; Dx: PInteger): BOOL; stdcall;
type
  TIntArray = array[0..MaxInt div 8] of Integer;
  PIntArray = ^TIntArray;
var
  B: TWideBuf;
  WDx: PIntArray;
  I, U, N, Sum, K: Integer;
begin
  if ((Options and ETO_GLYPH_INDEX) = 0) and ((Options and $2000 {ETO_PDY}) = 0) and
    WantsWide(Str, Count) then
  begin
    ToWide(B, Str, Count);
    WDx := nil;
    try
      if Dx <> nil then
      begin
        { One advance per UTF-16 unit: the sum of the advances of the bytes of
          the character (the second half of a surrogate pair gets 0). }
        GetMem(WDx, (B.Len + 1) * SizeOf(Integer));
        I := 0;
        U := 0;
        while (I < Count) and (U < B.Len) do
        begin
          N := Utf8SequenceLength(Str[I]);
          if N = 0 then N := 1;
          Sum := 0;
          for K := 0 to N - 1 do
            if I + K < Count then
              Inc(Sum, PIntArray(Dx)[I + K]);
          WDx[U] := Sum;
          Inc(U);
          if (N = 4) and (U < B.Len) then
          begin
            WDx[U] := 0;
            Inc(U);
          end;
          Inc(I, N);
        end;
        while U < B.Len do
        begin
          WDx[U] := 0;
          Inc(U);
        end;
      end;
      Result := ExtTextOutW(DC, X, Y, Options, Rect, B.P, B.Len, PInteger(WDx));
    finally
      if WDx <> nil then FreeMem(WDx);
      FreeWide(B);
    end;
  end
  else
    Result := Orig_ExtTextOutA(DC, X, Y, Options, Rect, Str, Count, Dx);
end;

function Shim_GetTextExtentPoint32A(DC: HDC; Str: PChar; Count: Integer; var Size: TSize): BOOL; stdcall;
var
  B: TWideBuf;
begin
  if WantsWide(Str, Count) then
  begin
    ToWide(B, Str, Count);
    try
      Result := GetTextExtentPoint32W(DC, B.P, B.Len, Size);
    finally
      FreeWide(B);
    end;
  end
  else
    Result := Orig_GetTextExtentPoint32A(DC, Str, Count, Size);
end;

function Shim_GetTextExtentPointA(DC: HDC; Str: PChar; Count: Integer; var Size: TSize): BOOL; stdcall;
var
  B: TWideBuf;
begin
  if WantsWide(Str, Count) then
  begin
    ToWide(B, Str, Count);
    try
      Result := GetTextExtentPoint32W(DC, B.P, B.Len, Size);
    finally
      FreeWide(B);
    end;
  end
  else
    Result := Orig_GetTextExtentPointA(DC, Str, Count, Size);
end;

function Shim_GetTextExtentExPointA(DC: HDC; Str: PChar; Count, MaxExtent: Integer;
  Fit, Dx: PInteger; var Size: TSize): BOOL; stdcall;
type
  TIntArray = array[0..MaxInt div 8] of Integer;
  PIntArray = ^TIntArray;
var
  B: TWideBuf;
  WDx: PIntArray;
  WFit, I, U, N, K: Integer;
begin
  if WantsWide(Str, Count) then
  begin
    ToWide(B, Str, Count);
    WDx := nil;
    try
      if Dx <> nil then
        GetMem(WDx, (B.Len + 1) * SizeOf(Integer));
      WFit := 0;
      Result := GetTextExtentExPointW(DC, B.P, B.Len, MaxExtent, @WFit, PInteger(WDx), Size);
      if Result then
      begin
        if Fit <> nil then
          Fit^ := BytesForUnits(B.P, WFit);
        if Dx <> nil then
        begin
          { Every byte of a character gets the extent at the end of that character. }
          I := 0;
          U := 0;
          while (I < Count) and (U < B.Len) do
          begin
            N := Utf8SequenceLength(Str[I]);
            if N = 0 then N := 1;
            if N = 4 then Inc(U, 2) else Inc(U);
            if U > B.Len then U := B.Len;
            for K := 0 to N - 1 do
              if I + K < Count then
                PIntArray(Dx)[I + K] := WDx[U - 1];
            Inc(I, N);
          end;
        end;
      end;
    finally
      if WDx <> nil then FreeMem(WDx);
      FreeWide(B);
    end;
  end
  else
    Result := Orig_GetTextExtentExPointA(DC, Str, Count, MaxExtent, Fit, Dx, Size);
end;

function Shim_DrawTextA(DC: HDC; Str: PChar; Count: Integer; var Rect: TRect; Format: UINT): Integer; stdcall;
var
  B: TWideBuf;
  Work: PWideChar;
  Bytes: Integer;
begin
  if WantsWide(Str, Count) then
  begin
    ToWide(B, Str, Count);
    try
      if (Format and DT_MODIFYSTRING) <> 0 then
      begin
        { DrawText may append up to 4 characters ("..."); work on a copy and
          write the result back into the caller's buffer (Count + 4 bytes). }
        GetMem(Work, (B.Len + 5) * SizeOf(WideChar));
        try
          Move(B.P^, Work^, (B.Len + 1) * SizeOf(WideChar));
          Result := DrawTextW(DC, Work, B.Len, Rect, Format);
          if Count < 0 then Bytes := lstrlenA(Str) else Bytes := Count;
          WideToBuffer(Work, lstrlenW(Work), Str, Bytes + 5);
        finally
          FreeMem(Work);
        end;
      end
      else
        Result := DrawTextW(DC, B.P, B.Len, Rect, Format);
    finally
      FreeWide(B);
    end;
  end
  else
    Result := Orig_DrawTextA(DC, Str, Count, Rect, Format);
end;

function Shim_DrawTextExA(DC: HDC; Str: PChar; Count: Integer; var Rect: TRect; Format: UINT;
  Params: PDrawTextParams): Integer; stdcall;
var
  B: TWideBuf;
  Work: PWideChar;
  Bytes: Integer;
begin
  if WantsWide(Str, Count) then
  begin
    ToWide(B, Str, Count);
    try
      GetMem(Work, (B.Len + 5) * SizeOf(WideChar));
      try
        Move(B.P^, Work^, (B.Len + 1) * SizeOf(WideChar));
        Result := DrawTextExW(DC, Work, B.Len, Rect, Format, Params);
        if (Params <> nil) and (Params.cbSize >= SizeOf(TDrawTextParams)) then
          Params.uiLengthDrawn := BytesForUnits(Work, Params.uiLengthDrawn);
        if (Format and DT_MODIFYSTRING) <> 0 then
        begin
          if Count < 0 then Bytes := lstrlenA(Str) else Bytes := Count;
          WideToBuffer(Work, lstrlenW(Work), Str, Bytes + 5);
        end;
      finally
        FreeMem(Work);
      end;
    finally
      FreeWide(B);
    end;
  end
  else
    Result := Orig_DrawTextExA(DC, Str, Count, Rect, Format, Params);
end;

function Shim_TabbedTextOutA(DC: HDC; X, Y: Integer; Str: PChar; Count, nTabPositions: Integer;
  TabStops: PInteger; nTabOrigin: Integer): Longint; stdcall;
var
  B: TWideBuf;
begin
  if WantsWide(Str, Count) then
  begin
    ToWide(B, Str, Count);
    try
      Result := TabbedTextOutW(DC, X, Y, B.P, B.Len, nTabPositions, TabStops^, nTabOrigin);
    finally
      FreeWide(B);
    end;
  end
  else
    Result := Orig_TabbedTextOutA(DC, X, Y, Str, Count, nTabPositions, TabStops, nTabOrigin);
end;

function Shim_GetTabbedTextExtentA(DC: HDC; Str: PChar; Count, nTabPositions: Integer;
  TabStops: PInteger): DWORD; stdcall;
var
  B: TWideBuf;
begin
  if WantsWide(Str, Count) then
  begin
    ToWide(B, Str, Count);
    try
      Result := GetTabbedTextExtentW(DC, B.P, B.Len, nTabPositions, TabStops^);
    finally
      FreeWide(B);
    end;
  end
  else
    Result := Orig_GetTabbedTextExtentA(DC, Str, Count, nTabPositions, TabStops);
end;

function Shim_GrayStringA(DC: HDC; Brush: HBRUSH; OutputFunc: Pointer; Data: LPARAM;
  Count, X, Y, Width, Height: Integer): BOOL; stdcall;
var
  B: TWideBuf;
begin
  if (OutputFunc = nil) and WantsWide(PChar(Data), Count) then
  begin
    ToWide(B, PChar(Data), Count);
    try
      Result := GrayStringW(DC, Brush, nil, LPARAM(B.P), B.Len, X, Y, Width, Height);
    finally
      FreeWide(B);
    end;
  end
  else
    Result := Orig_GrayStringA(DC, Brush, OutputFunc, Data, Count, X, Y, Width, Height);
end;

{ "MS Sans Serif" (Delphi 7's default font of a form) is a bitmap font with the characters of the
  Western code pages only. Text beyond them is drawn from a font that Windows links in, and user32's
  classic controls measure it in MS Sans Serif's widths: a button centred a Greek caption wrongly
  and pushed it past its right edge. Microsoft Sans Serif is its TrueType version: the same design
  and, measured, the same metrics (height, ascent and the width of the alphabet at 8, 10 and 12
  points), with Greek, Cyrillic and more. In UTF-8 mode it takes MS Sans Serif's place. }
const
  LegacySansSerif = 'MS Sans Serif';
  TrueTypeSansSerif = 'Microsoft Sans Serif';

function IsLegacySansSerif(Face: PChar): Boolean;
begin
  Result := (Face <> nil) and (lstrcmpiA(Face, LegacySansSerif) = 0);
end;

function Shim_CreateFontIndirectA(const LogFont: TLogFontA): HFONT; stdcall;
var
  W: TLogFontW;
  L: TLogFontA;
begin
  if IsLegacySansSerif(LogFont.lfFaceName) then
  begin
    L := LogFont;
    FillChar(L.lfFaceName, SizeOf(L.lfFaceName), 0);
    lstrcpyA(L.lfFaceName, TrueTypeSansSerif);
    Result := Orig_CreateFontIndirectA(L);
  end
  else if WantsWide(LogFont.lfFaceName, lstrlenA(LogFont.lfFaceName)) then
  begin
    Move(LogFont, W, SizeOf(TLogFontA) - SizeOf(LogFont.lfFaceName));
    FillChar(W.lfFaceName, SizeOf(W.lfFaceName), 0);
    MultiByteToWideChar(CP_UTF8_, 0, LogFont.lfFaceName, -1, W.lfFaceName, LF_FACESIZE - 1);
    Result := CreateFontIndirectW(W);
  end
  else
    Result := Orig_CreateFontIndirectA(LogFont);
end;

function Shim_CreateFontA(nHeight, nWidth, nEscapement, nOrientaion, fnWeight: Integer;
  fdwItalic, fdwUnderline, fdwStrikeOut, fdwCharSet, fdwOutputPrecision, fdwClipPrecision,
  fdwQuality, fdwPitchAndFamily: DWORD; lpszFace: PChar): HFONT; stdcall;
var
  B: TWideBuf;
begin
  if IsLegacySansSerif(lpszFace) then lpszFace := TrueTypeSansSerif;
  if WantsWide(lpszFace, -1) then
  begin
    ToWide(B, lpszFace, -1);
    try
      Result := CreateFontW(nHeight, nWidth, nEscapement, nOrientaion, fnWeight, fdwItalic,
        fdwUnderline, fdwStrikeOut, fdwCharSet, fdwOutputPrecision, fdwClipPrecision,
        fdwQuality, fdwPitchAndFamily, B.P);
    finally
      FreeWide(B);
    end;
  end
  else
    Result := Orig_CreateFontA(nHeight, nWidth, nEscapement, nOrientaion, fnWeight, fdwItalic,
      fdwUnderline, fdwStrikeOut, fdwCharSet, fdwOutputPrecision, fdwClipPrecision,
      fdwQuality, fdwPitchAndFamily, lpszFace);
end;

{ ---- locale shims ---- }

function Shim_CompareStringA(Locale: LCID; Flags: DWORD; S1: PChar; C1: Integer; S2: PChar;
  C2: Integer): Integer; stdcall;
var
  B1, B2: TWideBuf;
  L1, L2: Integer;
begin
  if S1 = nil then L1 := 0 else if C1 < 0 then L1 := lstrlenA(S1) else L1 := C1;
  if S2 = nil then L2 := 0 else if C2 < 0 then L2 := lstrlenA(S2) else L2 := C2;
  if (HasNonAscii(S1, L1) or HasNonAscii(S2, L2)) and IsValidUtf8(S1, L1) and IsValidUtf8(S2, L2) then
  begin
    ToWide(B1, S1, L1);
    ToWide(B2, S2, L2);
    try
      Result := CompareStringW(Locale, Flags, B1.P, B1.Len, B2.P, B2.Len);
    finally
      FreeWide(B2);
      FreeWide(B1);
    end;
  end
  else
    Result := Orig_CompareStringA(Locale, Flags, S1, C1, S2, C2);
end;

{ Shared tail of the -A locale functions: W result (Units incl. terminator)
  -> UTF-8 with the usual "size query when cch = 0" semantics. }
function ReturnUtf8(W: PWideChar; Units: Integer; Dest: PChar; cchDest: Integer): Integer;
var
  Need: Integer;
begin
  Need := WideCharToMultiByte(CP_UTF8_, 0, W, Units, nil, 0, nil, nil);
  if cchDest = 0 then
    Result := Need
  else if cchDest < Need then
  begin
    SetLastError(ERROR_INSUFFICIENT_BUFFER);
    Result := 0;
  end
  else
    Result := WideCharToMultiByte(CP_UTF8_, 0, W, Units, Dest, cchDest, nil, nil);
end;

function Shim_GetLocaleInfoA(Locale: LCID; LCType: DWORD; Data: PChar; cchData: Integer): Integer; stdcall;
var
  N: Integer;
  W: array[0..255] of WideChar;
  P: PWideChar;
begin
  if (LCType and LOCALE_RETURN_NUMBER_) <> 0 then
  begin
    Result := Orig_GetLocaleInfoA(Locale, LCType, Data, cchData);
    Exit;
  end;
  N := GetLocaleInfoW(Locale, LCType, nil, 0);
  if N <= 0 then
  begin
    Result := 0;
    Exit;
  end;
  if N <= Length(W) then P := @W[0] else GetMem(P, N * SizeOf(WideChar));
  try
    N := GetLocaleInfoW(Locale, LCType, P, N);
    if N <= 0 then
      Result := 0
    else
      Result := ReturnUtf8(P, N, Data, cchData);
  finally
    if P <> @W[0] then FreeMem(P);
  end;
end;

function DateTimeFormatShim(IsDate: Boolean; Locale: LCID; Flags: DWORD; Time: PSystemTime;
  Format: PChar; Dest: PChar; cchDest: Integer): Integer;
var
  F: TWideBuf;
  FP: PWideChar;
  N: Integer;
  P: PWideChar;
begin
  F.Heap := False;
  FP := nil;
  if Format <> nil then
  begin
    ToWide(F, Format, -1);
    FP := F.P;
  end;
  try
    if IsDate then
      N := GetDateFormatW(Locale, Flags, Time, FP, nil, 0)
    else
      N := GetTimeFormatW(Locale, Flags, Time, FP, nil, 0);
    if N <= 0 then
    begin
      Result := 0;
      Exit;
    end;
    GetMem(P, N * SizeOf(WideChar));
    try
      if IsDate then
        N := GetDateFormatW(Locale, Flags, Time, FP, P, N)
      else
        N := GetTimeFormatW(Locale, Flags, Time, FP, P, N);
      if N <= 0 then
        Result := 0
      else
        Result := ReturnUtf8(P, N, Dest, cchDest);
    finally
      FreeMem(P);
    end;
  finally
    if Format <> nil then FreeWide(F);
  end;
end;

function Shim_GetDateFormatA(Locale: LCID; Flags: DWORD; Time: PSystemTime; Format: PChar;
  Dest: PChar; cchDest: Integer): Integer; stdcall;
begin
  Result := DateTimeFormatShim(True, Locale, Flags, Time, Format, Dest, cchDest);
end;

function Shim_GetTimeFormatA(Locale: LCID; Flags: DWORD; Time: PSystemTime; Format: PChar;
  Dest: PChar; cchDest: Integer): Integer; stdcall;
begin
  Result := DateTimeFormatShim(False, Locale, Flags, Time, Format, Dest, cchDest);
end;

{ ---- keyboard: UTF-8 delivery of WM_CHAR to ANSI windows ---- }

type
  { Remaining UTF-8 bytes of a character taken from the queue. }
  TPendingChar = record
    Count: Integer;
    Index: Integer;
    Bytes: array[0..3] of Byte;
    Msg: TMsg;
  end;

  { Reassembly of UTF-8 bytes into UTF-16 for a Unicode window procedure. }
  TUtf8Assembler = record
    Wnd: HWND;
    Msg: UINT;
    Need: Integer;
    Have: Integer;
    Buf: array[0..3] of Byte;
  end;

threadvar
  Pending: TPendingChar;
  AsmCall: TUtf8Assembler;
  AsmDef: TUtf8Assembler;
  AsmDispatch: TUtf8Assembler;
  AsmDialog: TUtf8Assembler;

function IsCharMessage(Msg: UINT): Boolean;
begin
  Result := (Msg = WM_CHAR) or (Msg = WM_SYSCHAR) or (Msg = WM_DEADCHAR) or (Msg = WM_SYSDEADCHAR);
end;

function EncodeCodePoint(CP: Cardinal; var Bytes: array of Byte): Integer;
begin
  if CP < $80 then
  begin
    Bytes[0] := CP;
    Result := 1;
  end
  else if CP < $800 then
  begin
    Bytes[0] := $C0 or (CP shr 6);
    Bytes[1] := $80 or (CP and $3F);
    Result := 2;
  end
  else if CP < $10000 then
  begin
    Bytes[0] := $E0 or (CP shr 12);
    Bytes[1] := $80 or ((CP shr 6) and $3F);
    Bytes[2] := $80 or (CP and $3F);
    Result := 3;
  end
  else
  begin
    Bytes[0] := $F0 or (CP shr 18);
    Bytes[1] := $80 or ((CP shr 12) and $3F);
    Bytes[2] := $80 or ((CP shr 6) and $3F);
    Bytes[3] := $80 or (CP and $3F);
    Result := 4;
  end;
end;

function PendingMatches(Wnd: HWND; FilterMin, FilterMax: UINT): Boolean;
begin
  Result := False;
  if Pending.Index >= Pending.Count then Exit;
  if (Wnd = HWND(-1)) then Exit;
  if (Wnd <> 0) and (Wnd <> Pending.Msg.hwnd) and not IsChild(Wnd, Pending.Msg.hwnd) then Exit;
  if ((FilterMin <> 0) or (FilterMax <> 0)) and
    ((Pending.Msg.message < FilterMin) or (Pending.Msg.message > FilterMax)) then Exit;
  Result := True;
end;

procedure TakePending(var Msg: TMsg; Remove: Boolean);
begin
  Msg := Pending.Msg;
  Msg.wParam := Pending.Bytes[Pending.Index];
  if Remove then
    Inc(Pending.Index);
end;

{ Msg was just retrieved with the -W function. Turns a non-ASCII character
  into its first UTF-8 byte and, when the message was removed, queues the
  remaining bytes. }
procedure ConvertCharMessage(var Msg: TMsg; Removed: Boolean);
var
  CP, Lo: Cardinal;
  Next: TMsg;
  N: Integer;
  Bytes: array[0..3] of Byte;
begin
  if not IsCharMessage(Msg.message) or (Msg.wParam < $80) then Exit;
  CP := Msg.wParam and $FFFF;
  if (CP >= $D800) and (CP <= $DBFF) then
  begin
    { High surrogate: the low surrogate is the next WM_CHAR of the window. }
    if Removed and PeekMessageW(Next, Msg.hwnd, Msg.message, Msg.message, PM_REMOVE) and
      (Next.wParam >= $DC00) and (Next.wParam <= $DFFF) then
    begin
      Lo := Next.wParam;
      CP := ((CP - $D800) shl 10) + (Lo - $DC00) + $10000;
    end
    else if not Removed then
      CP := ((CP - $D800) shl 10) + $10000      // lead byte only depends on the high half
    else
      CP := $FFFD;
  end
  else if (CP >= $DC00) and (CP <= $DFFF) then
    CP := $FFFD;
  N := EncodeCodePoint(CP, Bytes);
  if Removed then
  begin
    Pending.Msg := Msg;
    Move(Bytes, Pending.Bytes, SizeOf(Bytes));
    Pending.Count := N;
    Pending.Index := 1;
  end;
  Msg.wParam := Bytes[0];
end;

function Shim_PeekMessageA(var Msg: TMsg; Wnd: HWND; FilterMin, FilterMax, RemoveMsg: UINT): BOOL; stdcall;
begin
  if PendingMatches(Wnd, FilterMin, FilterMax) then
  begin
    TakePending(Msg, (RemoveMsg and PM_REMOVE) <> 0);
    Result := True;
    Exit;
  end;
  Result := PeekMessageW(Msg, Wnd, FilterMin, FilterMax, RemoveMsg);
  if Result then
    ConvertCharMessage(Msg, (RemoveMsg and PM_REMOVE) <> 0);
end;

function Shim_GetMessageA(var Msg: TMsg; Wnd: HWND; FilterMin, FilterMax: UINT): BOOL; stdcall;
begin
  if PendingMatches(Wnd, FilterMin, FilterMax) then
  begin
    TakePending(Msg, True);
    Result := True;
    Exit;
  end;
  Result := GetMessageW(Msg, Wnd, FilterMin, FilterMax);
  if LongInt(Result) > 0 then
    ConvertCharMessage(Msg, True);
end;

{ Collects UTF-8 bytes; returns True with the UTF-16 units once complete. }
function Assemble(var A: TUtf8Assembler; Wnd: HWND; Msg: UINT; B: Byte;
  var U1, U2: WideChar; var Units: Integer): Boolean;
var
  CP: Cardinal;
  I: Integer;
begin
  Result := False;
  Units := 0;
  if (B >= $C2) and (B <= $F4) then
  begin
    A.Wnd := Wnd;
    A.Msg := Msg;
    A.Need := Utf8SequenceLength(Char(B));
    A.Have := 1;
    A.Buf[0] := B;
    Exit;
  end;
  if (B >= $80) and (B <= $BF) and (A.Have > 0) and (A.Wnd = Wnd) and (A.Msg = Msg) then
  begin
    A.Buf[A.Have] := B;
    Inc(A.Have);
    if A.Have < A.Need then Exit;
    case A.Need of
      2: CP := A.Buf[0] and $1F;
      3: CP := A.Buf[0] and $0F;
    else
      CP := A.Buf[0] and $07;
    end;
    for I := 1 to A.Need - 1 do
      CP := (CP shl 6) or (A.Buf[I] and $3F);
    A.Have := 0;
    if CP >= $10000 then
    begin
      U1 := WideChar($D7C0 + (CP shr 10));
      U2 := WideChar($DC00 or (CP and $3FF));
      Units := 2;
    end
    else
    begin
      U1 := WideChar(CP);
      Units := 1;
    end;
    Result := True;
    Exit;
  end;
  A.Have := 0;   // stray byte: drop it
end;

{ True when PrevProc expects Unicode messages (system window procedures and the
  call-procedure handles user32 hands out for them). Delphi code in this module
  and dynamically generated VCL object instances are ANSI. }
function TargetIsUnicode(PrevProc: Pointer): Boolean;
var
  MBI: TMemoryBasicInformation;
begin
  if (PrevProc = nil) or (VirtualQuery(PrevProc, MBI, SizeOf(MBI)) = 0) or
    (MBI.State <> MEM_COMMIT) then
    Result := True
  else
    Result := not ((MBI.Type_9 = MEM_PRIVATE) or (HMODULE(MBI.AllocationBase) = HInstance));
end;

function Shim_CallWindowProcA(PrevProc: Pointer; Wnd: HWND; Msg: UINT; WParam: WPARAM;
  LParam: LPARAM): LRESULT; stdcall;
var
  U1, U2: WideChar;
  N: Integer;
begin
  if IsCharMessage(Msg) and (WParam >= $80) and (WParam <= $FF) and
    (Pointer(@Orig_DefWindowProcA) <> PrevProc) and TargetIsUnicode(PrevProc) then
  begin
    Result := 0;
    if Assemble(AsmCall, Wnd, Msg, WParam, U1, U2, N) then
    begin
      Result := CallWindowProcW(PrevProc, Wnd, Msg, Ord(U1), LParam);
      if N = 2 then
        Result := CallWindowProcW(PrevProc, Wnd, Msg, Ord(U2), LParam);
    end;
  end
  else if IsCharMessage(Msg) and (WParam >= $80) and (WParam <= $FF) and
    (Pointer(@Orig_DefWindowProcA) = PrevProc) then
  begin
    Result := 0;
    if Assemble(AsmCall, Wnd, Msg, WParam, U1, U2, N) then
    begin
      Result := DefWindowProcW(Wnd, Msg, Ord(U1), LParam);
      if N = 2 then
        Result := DefWindowProcW(Wnd, Msg, Ord(U2), LParam);
    end;
  end
  else
    Result := Orig_CallWindowProcA(PrevProc, Wnd, Msg, WParam, LParam);
end;

function Shim_DefWindowProcA(Wnd: HWND; Msg: UINT; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
var
  U1, U2: WideChar;
  N: Integer;
begin
  if IsCharMessage(Msg) and (WParam >= $80) and (WParam <= $FF) then
  begin
    Result := 0;
    if Assemble(AsmDef, Wnd, Msg, WParam, U1, U2, N) then
    begin
      Result := DefWindowProcW(Wnd, Msg, Ord(U1), LParam);
      if N = 2 then
        Result := DefWindowProcW(Wnd, Msg, Ord(U2), LParam);
    end;
  end
  else
    Result := Orig_DefWindowProcA(Wnd, Msg, WParam, LParam);
end;

function Shim_DefDlgProcA(Wnd: HWND; Msg: UINT; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
var
  U1, U2: WideChar;
  N: Integer;
begin
  if IsCharMessage(Msg) and (WParam >= $80) and (WParam <= $FF) then
  begin
    Result := 0;
    if Assemble(AsmDef, Wnd, Msg, WParam, U1, U2, N) then
    begin
      Result := DefDlgProcW(Wnd, Msg, Ord(U1), LParam);
      if N = 2 then
        Result := DefDlgProcW(Wnd, Msg, Ord(U2), LParam);
    end;
  end
  else
    Result := Orig_DefDlgProcA(Wnd, Msg, WParam, LParam);
end;

function Shim_DefMDIChildProcA(Wnd: HWND; Msg: UINT; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
var
  U1, U2: WideChar;
  N: Integer;
begin
  if IsCharMessage(Msg) and (WParam >= $80) and (WParam <= $FF) then
  begin
    Result := 0;
    if Assemble(AsmDef, Wnd, Msg, WParam, U1, U2, N) then
    begin
      Result := DefMDIChildProcW(Wnd, Msg, Ord(U1), LParam);
      if N = 2 then
        Result := DefMDIChildProcW(Wnd, Msg, Ord(U2), LParam);
    end;
  end
  else
    Result := Orig_DefMDIChildProcA(Wnd, Msg, WParam, LParam);
end;

function Shim_DefFrameProcA(Wnd, MDIClient: HWND; Msg: UINT; WParam: WPARAM; LParam: LPARAM): LRESULT; stdcall;
var
  U1, U2: WideChar;
  N: Integer;
begin
  if IsCharMessage(Msg) and (WParam >= $80) and (WParam <= $FF) then
  begin
    Result := 0;
    if Assemble(AsmDef, Wnd, Msg, WParam, U1, U2, N) then
    begin
      Result := DefFrameProcW(Wnd, MDIClient, Msg, Ord(U1), LParam);
      if N = 2 then
        Result := DefFrameProcW(Wnd, MDIClient, Msg, Ord(U2), LParam);
    end;
  end
  else
    Result := Orig_DefFrameProcA(Wnd, MDIClient, Msg, WParam, LParam);
end;

function Shim_DispatchMessageA(const Msg: TMsg): Longint; stdcall;
var
  M: TMsg;
  U1, U2: WideChar;
  N: Integer;
begin
  if IsCharMessage(Msg.message) and (Msg.wParam >= $80) and (Msg.wParam <= $FF) and
    (Msg.hwnd <> 0) and IsWindowUnicode(Msg.hwnd) then
  begin
    Result := 0;
    if Assemble(AsmDispatch, Msg.hwnd, Msg.message, Msg.wParam, U1, U2, N) then
    begin
      M := Msg;
      M.wParam := Ord(U1);
      Result := DispatchMessageW(M);
      if N = 2 then
      begin
        M.wParam := Ord(U2);
        Result := DispatchMessageW(M);
      end;
    end;
  end
  else
    Result := Orig_DispatchMessageA(Msg);
end;

function Shim_IsDialogMessageA(Dlg: HWND; var Msg: TMsg): BOOL; stdcall;
var
  M: TMsg;
  U1, U2: WideChar;
  N: Integer;
begin
  if IsCharMessage(Msg.message) and (Msg.wParam >= $80) and (Msg.wParam <= $FF) and
    (Dlg <> 0) and IsWindowUnicode(Dlg) and ((Msg.hwnd = Dlg) or IsChild(Dlg, Msg.hwnd)) then
  begin
    Result := True;   // intermediate bytes are consumed by the dialog
    if Assemble(AsmDialog, Msg.hwnd, Msg.message, Msg.wParam, U1, U2, N) then
    begin
      M := Msg;
      M.wParam := Ord(U1);
      Result := IsDialogMessageW(Dlg, M);
      if N = 2 then
      begin
        M.wParam := Ord(U2);
        Result := IsDialogMessageW(Dlg, M);
      end;
    end;
  end
  else
    Result := Orig_IsDialogMessageA(Dlg, Msg);
end;

{ ---- import redirection ---- }

type
  PImportDescriptor = ^TImportDescriptor;
  TImportDescriptor = packed record
    OriginalFirstThunk: DWORD;
    TimeDateStamp: DWORD;
    ForwarderChain: DWORD;
    Name: DWORD;
    FirstThunk: DWORD;
  end;

function RedirectSlots(Module: HMODULE; Target, Replacement: Pointer): Integer;
var
  Dos: PImageDosHeader;
  Nt: PImageNtHeaders;
  Dir: TImageDataDirectory;
  Desc: PImportDescriptor;
  Slot: ^Pointer;
  OldProtect: DWORD;
begin
  Result := 0;
  if (Module = 0) or (Target = nil) then Exit;
  Dos := PImageDosHeader(Module);
  if Dos.e_magic <> IMAGE_DOS_SIGNATURE then Exit;
  Nt := PImageNtHeaders(Cardinal(Module) + Cardinal(Dos._lfanew));
  if Nt.Signature <> IMAGE_NT_SIGNATURE then Exit;
  Dir := Nt.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
  if (Dir.VirtualAddress = 0) or (Dir.Size = 0) then Exit;
  Desc := PImportDescriptor(Cardinal(Module) + Dir.VirtualAddress);
  while Desc.Name <> 0 do
  begin
    if Desc.FirstThunk <> 0 then
    begin
      Slot := Pointer(Cardinal(Module) + Desc.FirstThunk);
      while Slot^ <> nil do
      begin
        if Slot^ = Target then
          if VirtualProtect(Slot, SizeOf(Pointer), PAGE_READWRITE, OldProtect) then
          begin
            Slot^ := Replacement;
            VirtualProtect(Slot, SizeOf(Pointer), OldProtect, OldProtect);
            Inc(Result);
          end;
        Inc(Slot);
      end;
    end;
    Inc(Desc);
  end;
end;

procedure Redirect(Module: HMODULE; Dll: HMODULE; Name: PChar; Shim: Pointer; var Orig);
var
  Target: Pointer;
begin
  if Dll = 0 then Exit;
  Target := GetProcAddress(Dll, Name);
  if Target = nil then Exit;
  if Pointer(Orig) = nil then
    Pointer(Orig) := Target;
  Inc(FShimCount, RedirectSlots(Module, Target, Shim));
end;

procedure InstallUtf8Shims(Module: HMODULE);
var
  Gdi, User, Kernel: HMODULE;
begin
  if not FUtf8Mode or (Module = 0) then Exit;
  Gdi := GetModuleHandle(gdi32);
  User := GetModuleHandle(user32);
  Kernel := GetModuleHandle(kernel32);
  Redirect(Module, Gdi, 'TextOutA', @Shim_TextOutA, Orig_TextOutA);
  Redirect(Module, Gdi, 'ExtTextOutA', @Shim_ExtTextOutA, Orig_ExtTextOutA);
  Redirect(Module, Gdi, 'GetTextExtentPoint32A', @Shim_GetTextExtentPoint32A, Orig_GetTextExtentPoint32A);
  Redirect(Module, Gdi, 'GetTextExtentPointA', @Shim_GetTextExtentPointA, Orig_GetTextExtentPointA);
  Redirect(Module, Gdi, 'GetTextExtentExPointA', @Shim_GetTextExtentExPointA, Orig_GetTextExtentExPointA);
  Redirect(Module, Gdi, 'CreateFontIndirectA', @Shim_CreateFontIndirectA, Orig_CreateFontIndirectA);
  Redirect(Module, Gdi, 'CreateFontA', @Shim_CreateFontA, Orig_CreateFontA);
  Redirect(Module, User, 'DrawTextA', @Shim_DrawTextA, Orig_DrawTextA);
  Redirect(Module, User, 'DrawTextExA', @Shim_DrawTextExA, Orig_DrawTextExA);
  Redirect(Module, User, 'TabbedTextOutA', @Shim_TabbedTextOutA, Orig_TabbedTextOutA);
  Redirect(Module, User, 'GetTabbedTextExtentA', @Shim_GetTabbedTextExtentA, Orig_GetTabbedTextExtentA);
  Redirect(Module, User, 'GrayStringA', @Shim_GrayStringA, Orig_GrayStringA);
  Redirect(Module, User, 'PeekMessageA', @Shim_PeekMessageA, Orig_PeekMessageA);
  Redirect(Module, User, 'GetMessageA', @Shim_GetMessageA, Orig_GetMessageA);
  Redirect(Module, User, 'DispatchMessageA', @Shim_DispatchMessageA, Orig_DispatchMessageA);
  Redirect(Module, User, 'IsDialogMessageA', @Shim_IsDialogMessageA, Orig_IsDialogMessageA);
  Redirect(Module, User, 'CallWindowProcA', @Shim_CallWindowProcA, Orig_CallWindowProcA);
  Redirect(Module, User, 'DefWindowProcA', @Shim_DefWindowProcA, Orig_DefWindowProcA);
  Redirect(Module, User, 'DefDlgProcA', @Shim_DefDlgProcA, Orig_DefDlgProcA);
  Redirect(Module, User, 'DefMDIChildProcA', @Shim_DefMDIChildProcA, Orig_DefMDIChildProcA);
  Redirect(Module, User, 'DefFrameProcA', @Shim_DefFrameProcA, Orig_DefFrameProcA);
  Redirect(Module, Kernel, 'CompareStringA', @Shim_CompareStringA, Orig_CompareStringA);
  Redirect(Module, Kernel, 'GetLocaleInfoA', @Shim_GetLocaleInfoA, Orig_GetLocaleInfoA);
  Redirect(Module, Kernel, 'GetDateFormatA', @Shim_GetDateFormatA, Orig_GetDateFormatA);
  Redirect(Module, Kernel, 'GetTimeFormatA', @Shim_GetTimeFormatA, Orig_GetTimeFormatA);
end;

function Utf8ShimsInstalled: Integer;
begin
  Result := FShimCount;
end;

function ShimsDisabledByEnvironment: Boolean;
var
  Buf: array[0..7] of Char;
begin
  Result := (GetEnvironmentVariable('D7_UTF8_SHIMS', Buf, SizeOf(Buf)) > 0) and (Buf[0] = '0');
end;

var
  FShimsAllowed: Boolean;

procedure InstallUtf8ShimsForModules;
var
  M: PLibModule;
begin
  if not FInitialized then
    InitializeUtf8Mode;
  if not FUtf8Mode or not FShimsAllowed then Exit;
  { the program itself, also before it is in LibModuleList }
  InstallUtf8Shims(GetModuleHandle(nil));
  M := LibModuleList;
  while M <> nil do
  begin
    InstallUtf8Shims(M.Instance);
    M := M.Next;
  end;
end;

{ CreateWindowUtf8 (interface): DefWndProc is user32's own EDIT or COMBOBOX procedure - the one
  GetClassInfoA gives for the class, in user32 or in ntdll (user32 forwards the ANSI procedures of
  its controls there: measured, Windows 11). With the visual styles the classes are comctl32 6's,
  in comctl32, and are left alone. }
function IsClassicEditProc(DefWndProc: Pointer): Boolean;
var
  MBI: TMemoryBasicInformation;
  WC: TWndClassA;
  Module: HMODULE;
begin
  Result := False;
  if (DefWndProc = nil) or not IsUtf8Mode then Exit;
  if VirtualQuery(DefWndProc, MBI, SizeOf(MBI)) = 0 then Exit;
  Module := HMODULE(MBI.AllocationBase);
  if (Module <> GetModuleHandle(user32)) and (Module <> GetModuleHandle('ntdll.dll')) then Exit;
  Result := (GetClassInfoA(0, 'EDIT', WC) and (WC.lpfnWndProc = DefWndProc)) or
    (GetClassInfoA(0, 'COMBOBOX', WC) and (WC.lpfnWndProc = DefWndProc));
end;

function CreateWindowUtf8(ExStyle: DWORD; ClassName, WindowName: PChar; Style: DWORD;
  X, Y, Width, Height: Integer; Parent: HWND; Menu: HMENU; Instance: HINST; Param: Pointer;
  DefWndProc: Pointer): HWND;
var
  WClass, WName: WideString;
begin
  if IsClassicEditProc(DefWndProc) then
  begin
    WClass := CodePageToWide(ClassName, CP_UTF8_);
    WName := CodePageToWide(WindowName, CP_UTF8_);
    Result := CreateWindowExW(ExStyle, PWideChar(WClass), PWideChar(WName), Style, X, Y, Width,
      Height, Parent, Menu, Instance, Param);
  end
  else
    Result := CreateWindowExA(ExStyle, ClassName, WindowName, Style, X, Y, Width, Height, Parent,
      Menu, Instance, Param);
end;

const
  { a comment in the program's manifest: the program needs the UTF-8 code page that its
    activeCodePage asks for, and must not run in a legacy code page }
  RequiresUtf8Mark = 'requires activeCodePage UTF-8';
  ERROR_OLD_WIN_VERSION_ = 1150;
  IMAGE_SUBSYSTEM_WINDOWS_CUI_ = 3;

{ True when the program's manifest (RT_MANIFEST 1 of the EXE) holds RequiresUtf8Mark }
function ManifestRequiresUtf8: Boolean;
var
  Res: HRSRC;
  P: PChar;
  Size, I, J, N: Integer;
begin
  Result := False;
  Res := FindResource(MainInstance, MakeIntResource(1), MakeIntResource(24));
  if Res = 0 then Exit;
  Size := SizeofResource(MainInstance, Res);
  P := LockResource(LoadResource(MainInstance, Res));
  if P = nil then Exit;
  N := Length(RequiresUtf8Mark);
  for I := 0 to Size - N do
  begin
    J := 0;
    while (J < N) and (P[I + J] = RequiresUtf8Mark[J + 1]) do Inc(J);
    if J = N then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

{ True when the EXE is a console program (its PE header's subsystem) }
function IsConsoleProgram: Boolean;
var
  Dos: PImageDosHeader;
  Nt: PImageNtHeaders;
begin
  Dos := PImageDosHeader(MainInstance);
  Nt := PImageNtHeaders(Cardinal(Dos) + Cardinal(Dos._lfanew));
  Result := Nt.OptionalHeader.Subsystem = IMAGE_SUBSYSTEM_WINDOWS_CUI_;
end;

{ A program whose manifest requires the UTF-8 code page ends at once where Windows did not give
  it one (Windows before 10 version 1903 ignores activeCodePage): its text was compiled as UTF-8
  and would show garbled in a legacy code page. Only the EXE's own start is checked (MainInstance
  is 0 in a library), so a DLL never ends its host. }
procedure CheckRequiredCodePage;
const
  Msg = 'This program requires Windows 10 version 1903 or later.';
var
  Title: array[0..MAX_PATH] of Char;
  Line: string;
  Err: THandle;
  Written: DWORD;
  I, Start: Integer;
begin
  if (MainInstance = 0) or not ManifestRequiresUtf8 then Exit;
  Err := GetStdHandle(STD_ERROR_HANDLE);
  if IsConsoleProgram and (Err <> 0) and (Err <> INVALID_HANDLE_VALUE) then
  begin
    Line := Msg + #13#10;
    WriteFile(Err, Line[1], Length(Line), Written, nil);
  end
  else
  begin
    I := GetModuleFileName(MainInstance, Title, MAX_PATH);
    Title[I] := #0;
    Start := 0;
    while I > 0 do
    begin
      Dec(I);
      if Title[I] = '\' then
      begin
        Start := I + 1;
        Break;
      end;
    end;
    MessageBox(0, Msg, @Title[Start], MB_OK or MB_ICONERROR or MB_TASKMODAL);
  end;
  ExitProcess(ERROR_OLD_WIN_VERSION_);
end;

procedure InitializeUtf8Mode;
begin
  if FInitialized then Exit;
  FInitialized := True;
  FUtf8Mode := GetACP = CP_UTF8_;
  if not FUtf8Mode then CheckRequiredCodePage;
  FShimsAllowed := not ShimsDisabledByEnvironment;
  if FUtf8Mode and FShimsAllowed then
  begin
    InstallUtf8Shims(HInstance);
    { With runtime packages: the program and the packages loaded with it }
    InstallUtf8ShimsForModules;
  end;
end;

initialization
  InitializeUtf8Mode;
end.
