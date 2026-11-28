{**********************************************************}
{                                                          }
{     Delphi 7 Runtime Library - Modernization             }
{     Shell Light-weight Utility API (shlwapi.h)           }
{     Windows XP .. Windows 11                             }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit ShLwApi;

{ Translated from shlwapi.h (Windows SDK 10.0.26100), with the PERCEIVED
  types of shtypes.h and the QueryAssociations GUIDs of shlguid.h.

  shlwapi.dll exists on every supported Windows. Functions that the
  shlwapi.dll of Windows XP exports by name are bound statically (external
  shlwapilib; the constant cannot be called shlwapi, which is the name of
  this unit). Functions added later, and functions that Windows XP exported
  by ordinal only, are bound at run time on first use: shlwapi.dll is loaded
  from the system directory and each function pointer is cached, so programs
  that use this unit still start on Windows XP. When such a function is
  missing:
    - HRESULT functions return E_NOTIMPL (out parameters are cleared);
    - BOOL functions return False after SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    - LSTATUS (registry) functions return ERROR_CALL_NOT_IMPLEMENTED;
    - the fallback of every other function is documented next to it.
  BOOL arguments of run-time bound functions are passed to Windows as 0 or 1
  (Delphi stores True as -1).

  Names without the A/W suffix are the ANSI (A) functions, as in Windows.pas.
  LONGLONG and ULONGLONG values are declared as Int64.

  Memory returned by these functions: StrDup -> LocalFree; StrRetToStr,
  SHStrDup, PathCreateFromUrlAlloc, IStream_ReadStr and the type string of
  AssocGetPerceivedType -> CoTaskMemFree; StrRetToBSTR -> a WideString.

  Functions that return an IStream (SHOpenRegStream2, SHCreateMemStream) are
  Pascal wrappers: Delphi returns interfaces through a hidden parameter, so
  the C function is called through a pointer-returning import and its
  reference is handed to Result without an extra AddRef.

  Not declared:
    - the generic StrToInt (it would hide SysUtils.StrToInt; use StrToIntA
      or StrToIntW) and the generic StrCat, StrCmp, StrCmpI, StrCpy, StrCpyN
      (in ANSI they are lstrcatA ... of Windows.pas);
    - the C type URLIS: Pascal identifiers are not case sensitive, so it
      would be the same identifier as the function UrlIs. The enumeration
      type is TUrlIs;
    - SHOpenRegStreamA/W (superseded by SHOpenRegStream2, to which the
      header maps SHOpenRegStream);
    - the COM, thread, shared memory and IsOS helpers (IUnknown_*, QISearch,
      SHCreateThread*, SHAllocShared ...) and SHGetInverseCMAP. }

{$WEAKPACKAGEUNIT ON}
{$MINENUMSIZE 4}

interface

uses
  Windows, ActiveX, ShlObj;

type
  { Win32 error code returned by the registry functions }
  {$EXTERNALSYM LSTATUS}
  LSTATUS = Longint;

{ ====== String functions ================================================== }

const
  { StrToIntEx / StrToInt64Ex }
  {$EXTERNALSYM STIF_DEFAULT}
  STIF_DEFAULT     = $00000000;
  {$EXTERNALSYM STIF_SUPPORT_HEX}
  STIF_SUPPORT_HEX = $00000001;

  { StrFormatByteSizeEx }
  {$EXTERNALSYM SFBS_FLAGS_ROUND_TO_NEAREST_DISPLAYED_DIGIT}
  SFBS_FLAGS_ROUND_TO_NEAREST_DISPLAYED_DIGIT    = $0001;  // round to the nearest displayed digit
  {$EXTERNALSYM SFBS_FLAGS_TRUNCATE_UNDISPLAYED_DECIMAL_DIGITS}
  SFBS_FLAGS_TRUNCATE_UNDISPLAYED_DECIMAL_DIGITS = $0002;  // discard undisplayed digits

  {$EXTERNALSYM SZ_CONTENTTYPE_HTMLA}
  SZ_CONTENTTYPE_HTMLA = 'text/html';
  {$EXTERNALSYM SZ_CONTENTTYPE_HTMLW}
  SZ_CONTENTTYPE_HTMLW = 'text/html';
  {$EXTERNALSYM SZ_CONTENTTYPE_HTML}
  SZ_CONTENTTYPE_HTML  = SZ_CONTENTTYPE_HTMLA;
  {$EXTERNALSYM SZ_CONTENTTYPE_CDFA}
  SZ_CONTENTTYPE_CDFA  = 'application/x-cdf';
  {$EXTERNALSYM SZ_CONTENTTYPE_CDFW}
  SZ_CONTENTTYPE_CDFW  = 'application/x-cdf';
  {$EXTERNALSYM SZ_CONTENTTYPE_CDF}
  SZ_CONTENTTYPE_CDF   = SZ_CONTENTTYPE_CDFA;

type
  {$EXTERNALSYM STIF_FLAGS}
  STIF_FLAGS = Integer;
  {$EXTERNALSYM SFBS_FLAGS}
  SFBS_FLAGS = Integer;

{ The A functions take a WORD character: a single byte character, or a
  double byte character with the lead byte in the high byte. }
{$EXTERNALSYM StrChrA}
function StrChrA(pszStart: PAnsiChar; wMatch: Word): PAnsiChar; stdcall;
{$EXTERNALSYM StrChrW}
function StrChrW(pszStart: PWideChar; wMatch: WideChar): PWideChar; stdcall;
{$EXTERNALSYM StrChr}
function StrChr(pszStart: PChar; wMatch: Word): PChar; stdcall;
{$EXTERNALSYM StrChrIA}
function StrChrIA(pszStart: PAnsiChar; wMatch: Word): PAnsiChar; stdcall;
{$EXTERNALSYM StrChrIW}
function StrChrIW(pszStart: PWideChar; wMatch: WideChar): PWideChar; stdcall;
{$EXTERNALSYM StrChrI}
function StrChrI(pszStart: PChar; wMatch: Word): PChar; stdcall;
{$EXTERNALSYM StrCmpNA}
function StrCmpNA(psz1, psz2: PAnsiChar; nChar: Integer): Integer; stdcall;
{$EXTERNALSYM StrCmpNW}
function StrCmpNW(psz1, psz2: PWideChar; nChar: Integer): Integer; stdcall;
{$EXTERNALSYM StrCmpN}
function StrCmpN(psz1, psz2: PChar; nChar: Integer): Integer; stdcall;
{$EXTERNALSYM StrCmpNIA}
function StrCmpNIA(psz1, psz2: PAnsiChar; nChar: Integer): Integer; stdcall;
{$EXTERNALSYM StrCmpNIW}
function StrCmpNIW(psz1, psz2: PWideChar; nChar: Integer): Integer; stdcall;
{$EXTERNALSYM StrCmpNI}
function StrCmpNI(psz1, psz2: PChar; nChar: Integer): Integer; stdcall;
{$EXTERNALSYM StrCSpnA}
function StrCSpnA(pszStr, pszSet: PAnsiChar): Integer; stdcall;
{$EXTERNALSYM StrCSpnW}
function StrCSpnW(pszStr, pszSet: PWideChar): Integer; stdcall;
{$EXTERNALSYM StrCSpn}
function StrCSpn(pszStr, pszSet: PChar): Integer; stdcall;
{$EXTERNALSYM StrCSpnIA}
function StrCSpnIA(pszStr, pszSet: PAnsiChar): Integer; stdcall;
{$EXTERNALSYM StrCSpnIW}
function StrCSpnIW(pszStr, pszSet: PWideChar): Integer; stdcall;
{$EXTERNALSYM StrCSpnI}
function StrCSpnI(pszStr, pszSet: PChar): Integer; stdcall;
{ The copy is allocated with LocalAlloc: free it with LocalFree. }
{$EXTERNALSYM StrDupA}
function StrDupA(pszSrch: PAnsiChar): PAnsiChar; stdcall;
{$EXTERNALSYM StrDupW}
function StrDupW(pszSrch: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM StrDup}
function StrDup(pszSrch: PChar): PChar; stdcall;
{ StrFormatByteSizeA takes a DWORD; StrFormatByteSize64A and
  StrFormatByteSizeW take a 64-bit size. }
{$EXTERNALSYM StrFormatByteSizeA}
function StrFormatByteSizeA(dw: DWORD; pszBuf: PAnsiChar; cchBuf: UINT): PAnsiChar; stdcall;
{$EXTERNALSYM StrFormatByteSize64A}
function StrFormatByteSize64A(qdw: Int64; pszBuf: PAnsiChar; cchBuf: UINT): PAnsiChar; stdcall;
{$EXTERNALSYM StrFormatByteSizeW}
function StrFormatByteSizeW(qdw: Int64; pszBuf: PWideChar; cchBuf: UINT): PWideChar; stdcall;
{$EXTERNALSYM StrFormatByteSize}
function StrFormatByteSize(dw: DWORD; pszBuf: PChar; cchBuf: UINT): PChar; stdcall;
{$EXTERNALSYM StrFormatByteSize64}
function StrFormatByteSize64(qdw: Int64; pszBuf: PChar; cchBuf: UINT): PChar; stdcall;
{ Windows Vista SP1; run-time bound. Fallback: E_NOTIMPL. }
{$EXTERNALSYM StrFormatByteSizeEx}
function StrFormatByteSizeEx(ull: Int64; flags: SFBS_FLAGS; pszBuf: PWideChar;
  cchBuf: UINT): HRESULT; stdcall;
{$EXTERNALSYM StrFormatKBSizeA}
function StrFormatKBSizeA(qdw: Int64; pszBuf: PAnsiChar; cchBuf: UINT): PAnsiChar; stdcall;
{$EXTERNALSYM StrFormatKBSizeW}
function StrFormatKBSizeW(qdw: Int64; pszBuf: PWideChar; cchBuf: UINT): PWideChar; stdcall;
{$EXTERNALSYM StrFormatKBSize}
function StrFormatKBSize(qdw: Int64; pszBuf: PChar; cchBuf: UINT): PChar; stdcall;
{$EXTERNALSYM StrFromTimeIntervalA}
function StrFromTimeIntervalA(pszOut: PAnsiChar; cchMax: UINT; dwTimeMS: DWORD;
  digits: Integer): Integer; stdcall;
{$EXTERNALSYM StrFromTimeIntervalW}
function StrFromTimeIntervalW(pszOut: PWideChar; cchMax: UINT; dwTimeMS: DWORD;
  digits: Integer): Integer; stdcall;
{$EXTERNALSYM StrFromTimeInterval}
function StrFromTimeInterval(pszOut: PChar; cchMax: UINT; dwTimeMS: DWORD;
  digits: Integer): Integer; stdcall;
{$EXTERNALSYM StrIsIntlEqualA}
function StrIsIntlEqualA(fCaseSens: BOOL; pszString1, pszString2: PAnsiChar;
  nChar: Integer): BOOL; stdcall;
{$EXTERNALSYM StrIsIntlEqualW}
function StrIsIntlEqualW(fCaseSens: BOOL; pszString1, pszString2: PWideChar;
  nChar: Integer): BOOL; stdcall;
{$EXTERNALSYM StrIsIntlEqual}
function StrIsIntlEqual(fCaseSens: BOOL; pszString1, pszString2: PChar;
  nChar: Integer): BOOL; stdcall;
{$EXTERNALSYM StrNCatA}
function StrNCatA(psz1, psz2: PAnsiChar; cchMax: Integer): PAnsiChar; stdcall;
{$EXTERNALSYM StrNCatW}
function StrNCatW(psz1, psz2: PWideChar; cchMax: Integer): PWideChar; stdcall;
{$EXTERNALSYM StrNCat}
function StrNCat(psz1, psz2: PChar; cchMax: Integer): PChar; stdcall;
{$EXTERNALSYM StrPBrkA}
function StrPBrkA(psz, pszSet: PAnsiChar): PAnsiChar; stdcall;
{$EXTERNALSYM StrPBrkW}
function StrPBrkW(psz, pszSet: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM StrPBrk}
function StrPBrk(psz, pszSet: PChar): PChar; stdcall;
{ pszEnd may be nil (search up to the terminating null). }
{$EXTERNALSYM StrRChrA}
function StrRChrA(pszStart, pszEnd: PAnsiChar; wMatch: Word): PAnsiChar; stdcall;
{$EXTERNALSYM StrRChrW}
function StrRChrW(pszStart, pszEnd: PWideChar; wMatch: WideChar): PWideChar; stdcall;
{$EXTERNALSYM StrRChr}
function StrRChr(pszStart, pszEnd: PChar; wMatch: Word): PChar; stdcall;
{$EXTERNALSYM StrRChrIA}
function StrRChrIA(pszStart, pszEnd: PAnsiChar; wMatch: Word): PAnsiChar; stdcall;
{$EXTERNALSYM StrRChrIW}
function StrRChrIW(pszStart, pszEnd: PWideChar; wMatch: WideChar): PWideChar; stdcall;
{$EXTERNALSYM StrRChrI}
function StrRChrI(pszStart, pszEnd: PChar; wMatch: Word): PChar; stdcall;
{$EXTERNALSYM StrRStrIA}
function StrRStrIA(pszSource, pszLast, pszSrch: PAnsiChar): PAnsiChar; stdcall;
{$EXTERNALSYM StrRStrIW}
function StrRStrIW(pszSource, pszLast, pszSrch: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM StrRStrI}
function StrRStrI(pszSource, pszLast, pszSrch: PChar): PChar; stdcall;
{$EXTERNALSYM StrSpnA}
function StrSpnA(psz, pszSet: PAnsiChar): Integer; stdcall;
{$EXTERNALSYM StrSpnW}
function StrSpnW(psz, pszSet: PWideChar): Integer; stdcall;
{$EXTERNALSYM StrSpn}
function StrSpn(psz, pszSet: PChar): Integer; stdcall;
{$EXTERNALSYM StrStrA}
function StrStrA(pszFirst, pszSrch: PAnsiChar): PAnsiChar; stdcall;
{$EXTERNALSYM StrStrW}
function StrStrW(pszFirst, pszSrch: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM StrStr}
function StrStr(pszFirst, pszSrch: PChar): PChar; stdcall;
{$EXTERNALSYM StrStrIA}
function StrStrIA(pszFirst, pszSrch: PAnsiChar): PAnsiChar; stdcall;
{$EXTERNALSYM StrStrIW}
function StrStrIW(pszFirst, pszSrch: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM StrStrI}
function StrStrI(pszFirst, pszSrch: PChar): PChar; stdcall;
{ No generic StrToInt: it would hide SysUtils.StrToInt. }
{$EXTERNALSYM StrToIntA}
function StrToIntA(pszSrc: PAnsiChar): Integer; stdcall;
{$EXTERNALSYM StrToIntW}
function StrToIntW(pszSrc: PWideChar): Integer; stdcall;
{ dwFlags: STIF_DEFAULT or STIF_SUPPORT_HEX ('0x' prefix) }
{$EXTERNALSYM StrToIntExA}
function StrToIntExA(pszString: PAnsiChar; dwFlags: STIF_FLAGS; out piRet: Integer): BOOL; stdcall;
{$EXTERNALSYM StrToIntExW}
function StrToIntExW(pszString: PWideChar; dwFlags: STIF_FLAGS; out piRet: Integer): BOOL; stdcall;
{$EXTERNALSYM StrToIntEx}
function StrToIntEx(pszString: PChar; dwFlags: STIF_FLAGS; out piRet: Integer): BOOL; stdcall;
{$EXTERNALSYM StrToInt64ExA}
function StrToInt64ExA(pszString: PAnsiChar; dwFlags: STIF_FLAGS; out pllRet: Int64): BOOL; stdcall;
{$EXTERNALSYM StrToInt64ExW}
function StrToInt64ExW(pszString: PWideChar; dwFlags: STIF_FLAGS; out pllRet: Int64): BOOL; stdcall;
{$EXTERNALSYM StrToInt64Ex}
function StrToInt64Ex(pszString: PChar; dwFlags: STIF_FLAGS; out pllRet: Int64): BOOL; stdcall;
{$EXTERNALSYM StrTrimA}
function StrTrimA(psz, pszTrimChars: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM StrTrimW}
function StrTrimW(psz, pszTrimChars: PWideChar): BOOL; stdcall;
{$EXTERNALSYM StrTrim}
function StrTrim(psz, pszTrimChars: PChar): BOOL; stdcall;
{ Unicode only; the ANSI names are macros for lstrcatA ... (Windows.pas). }
{$EXTERNALSYM StrCatW}
function StrCatW(psz1, psz2: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM StrCmpW}
function StrCmpW(psz1, psz2: PWideChar): Integer; stdcall;
{$EXTERNALSYM StrCmpIW}
function StrCmpIW(psz1, psz2: PWideChar): Integer; stdcall;
{$EXTERNALSYM StrCpyW}
function StrCpyW(psz1, psz2: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM StrCpyNW}
function StrCpyNW(pszDst, pszSrc: PWideChar; cchMax: Integer): PWideChar; stdcall;
{$EXTERNALSYM StrCatBuffA}
function StrCatBuffA(pszDest, pszSrc: PAnsiChar; cchDestBuffSize: Integer): PAnsiChar; stdcall;
{$EXTERNALSYM StrCatBuffW}
function StrCatBuffW(pszDest, pszSrc: PWideChar; cchDestBuffSize: Integer): PWideChar; stdcall;
{$EXTERNALSYM StrCatBuff}
function StrCatBuff(pszDest, pszSrc: PChar; cchDestBuffSize: Integer): PChar; stdcall;
{ Case-insensitive comparison of two characters: False when equal. }
{$EXTERNALSYM ChrCmpIA}
function ChrCmpIA(w1, w2: Word): BOOL; stdcall;
{$EXTERNALSYM ChrCmpIW}
function ChrCmpIW(w1, w2: WideChar): BOOL; stdcall;
{$EXTERNALSYM ChrCmpI}
function ChrCmpI(w1, w2: Word): BOOL; stdcall;
{ arglist: a C va_list (a pointer to the arguments on the stack). }
{$EXTERNALSYM wvnsprintfA}
function wvnsprintfA(pszDest: PAnsiChar; cchDest: Integer; pszFmt: PAnsiChar;
  arglist: Pointer): Integer; stdcall;
{$EXTERNALSYM wvnsprintfW}
function wvnsprintfW(pszDest: PWideChar; cchDest: Integer; pszFmt: PWideChar;
  arglist: Pointer): Integer; stdcall;
{$EXTERNALSYM wvnsprintf}
function wvnsprintf(pszDest: PChar; cchDest: Integer; pszFmt: PChar;
  arglist: Pointer): Integer; stdcall;
{ C variable argument functions (cdecl). Pass integers as Integer or
  Cardinal and strings as PAnsiChar / PWideChar. }
{$EXTERNALSYM wnsprintfA}
function wnsprintfA(pszDest: PAnsiChar; cchDest: Integer; pszFmt: PAnsiChar): Integer; cdecl; varargs;
{$EXTERNALSYM wnsprintfW}
function wnsprintfW(pszDest: PWideChar; cchDest: Integer; pszFmt: PWideChar): Integer; cdecl; varargs;
{$EXTERNALSYM wnsprintf}
function wnsprintf(pszDest: PChar; cchDest: Integer; pszFmt: PChar): Integer; cdecl; varargs;
{ StrRetToStr/StrRetToBuf free the pOleStr of an STRRET_WSTR. The string of
  StrRetToStr is allocated with CoTaskMemAlloc: free it with CoTaskMemFree. }
{$EXTERNALSYM StrRetToStrA}
function StrRetToStrA(var pstr: TStrRet; pidl: PItemIDList; out ppsz: PAnsiChar): HRESULT; stdcall;
{$EXTERNALSYM StrRetToStrW}
function StrRetToStrW(var pstr: TStrRet; pidl: PItemIDList; out ppsz: PWideChar): HRESULT; stdcall;
{$EXTERNALSYM StrRetToStr}
function StrRetToStr(var pstr: TStrRet; pidl: PItemIDList; out ppsz: PChar): HRESULT; stdcall;
{$EXTERNALSYM StrRetToBufA}
function StrRetToBufA(var pstr: TStrRet; pidl: PItemIDList; pszBuf: PAnsiChar;
  cchBuf: UINT): HRESULT; stdcall;
{$EXTERNALSYM StrRetToBufW}
function StrRetToBufW(var pstr: TStrRet; pidl: PItemIDList; pszBuf: PWideChar;
  cchBuf: UINT): HRESULT; stdcall;
{$EXTERNALSYM StrRetToBuf}
function StrRetToBuf(var pstr: TStrRet; pidl: PItemIDList; pszBuf: PChar;
  cchBuf: UINT): HRESULT; stdcall;
{ Duplicates a string as a Unicode string allocated with CoTaskMemAlloc. }
{$EXTERNALSYM SHStrDupA}
function SHStrDupA(psz: PAnsiChar; out ppwsz: PWideChar): HRESULT; stdcall;
{$EXTERNALSYM SHStrDupW}
function SHStrDupW(psz: PWideChar; out ppwsz: PWideChar): HRESULT; stdcall;
{$EXTERNALSYM SHStrDup}
function SHStrDup(psz: PChar; out ppwsz: PWideChar): HRESULT; stdcall;
{ Compares like Explorer sorts names: digits as numbers ('file2' < 'file10'). }
{$EXTERNALSYM StrCmpLogicalW}
function StrCmpLogicalW(psz1, psz2: PWideChar): Integer; stdcall;
{$EXTERNALSYM StrRetToBSTR}
function StrRetToBSTR(var pstr: TStrRet; pidl: PItemIDList; out pbstr: WideString): HRESULT; stdcall;
{ Resolves an indirect string ('@file,-id', or a resource of a package
  resource index); a string not starting with '@' is copied. ppvReserved
  must be nil. Run-time bound. Fallback: E_NOTIMPL. }
{$EXTERNALSYM SHLoadIndirectString}
function SHLoadIndirectString(pszSource, pszOutBuf: PWideChar; cchOutBuf: UINT;
  ppvReserved: Pointer): HRESULT; stdcall;

{ ====== Path functions ==================================================== }

const
  { PathGetCharType }
  {$EXTERNALSYM GCT_INVALID}
  GCT_INVALID   = $0000;
  {$EXTERNALSYM GCT_LFNCHAR}
  GCT_LFNCHAR   = $0001;
  {$EXTERNALSYM GCT_SHORTCHAR}
  GCT_SHORTCHAR = $0002;
  {$EXTERNALSYM GCT_WILD}
  GCT_WILD      = $0004;
  {$EXTERNALSYM GCT_SEPARATOR}
  GCT_SEPARATOR = $0008;

  { PathMatchSpecEx }
  {$EXTERNALSYM PMSF_NORMAL}
  PMSF_NORMAL            = $00000000;
  {$EXTERNALSYM PMSF_MULTIPLE}
  PMSF_MULTIPLE          = $00000001;
  {$EXTERNALSYM PMSF_DONT_STRIP_SPACES}
  PMSF_DONT_STRIP_SPACES = $00010000;  // modifies either of the above

{ Buffers marked MAX_PATH must hold at least MAX_PATH characters. }
{$EXTERNALSYM PathAddBackslashA}
function PathAddBackslashA(pszPath: PAnsiChar): PAnsiChar; stdcall;
{$EXTERNALSYM PathAddBackslashW}
function PathAddBackslashW(pszPath: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM PathAddBackslash}
function PathAddBackslash(pszPath: PChar): PChar; stdcall;
{$EXTERNALSYM PathAddExtensionA}
function PathAddExtensionA(pszPath, pszExt: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathAddExtensionW}
function PathAddExtensionW(pszPath, pszExt: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathAddExtension}
function PathAddExtension(pszPath, pszExt: PChar): BOOL; stdcall;
{$EXTERNALSYM PathAppendA}
function PathAppendA(pszPath, pszMore: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathAppendW}
function PathAppendW(pszPath, pszMore: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathAppend}
function PathAppend(pszPath, pszMore: PChar): BOOL; stdcall;
{ pszRoot: at least 4 characters; iDrive 0 = A }
{$EXTERNALSYM PathBuildRootA}
function PathBuildRootA(pszRoot: PAnsiChar; iDrive: Integer): PAnsiChar; stdcall;
{$EXTERNALSYM PathBuildRootW}
function PathBuildRootW(pszRoot: PWideChar; iDrive: Integer): PWideChar; stdcall;
{$EXTERNALSYM PathBuildRoot}
function PathBuildRoot(pszRoot: PChar; iDrive: Integer): PChar; stdcall;
{$EXTERNALSYM PathCanonicalizeA}
function PathCanonicalizeA(pszBuf, pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathCanonicalizeW}
function PathCanonicalizeW(pszBuf, pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathCanonicalize}
function PathCanonicalize(pszBuf, pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathCombineA}
function PathCombineA(pszDest, pszDir, pszFile: PAnsiChar): PAnsiChar; stdcall;
{$EXTERNALSYM PathCombineW}
function PathCombineW(pszDest, pszDir, pszFile: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM PathCombine}
function PathCombine(pszDest, pszDir, pszFile: PChar): PChar; stdcall;
{$EXTERNALSYM PathCompactPathA}
function PathCompactPathA(hDC: HDC; pszPath: PAnsiChar; dx: UINT): BOOL; stdcall;
{$EXTERNALSYM PathCompactPathW}
function PathCompactPathW(hDC: HDC; pszPath: PWideChar; dx: UINT): BOOL; stdcall;
{$EXTERNALSYM PathCompactPath}
function PathCompactPath(hDC: HDC; pszPath: PChar; dx: UINT): BOOL; stdcall;
{ cchMax includes the terminating null; dwFlags is reserved (0). }
{$EXTERNALSYM PathCompactPathExA}
function PathCompactPathExA(pszOut, pszSrc: PAnsiChar; cchMax: UINT; dwFlags: DWORD): BOOL; stdcall;
{$EXTERNALSYM PathCompactPathExW}
function PathCompactPathExW(pszOut, pszSrc: PWideChar; cchMax: UINT; dwFlags: DWORD): BOOL; stdcall;
{$EXTERNALSYM PathCompactPathEx}
function PathCompactPathEx(pszOut, pszSrc: PChar; cchMax: UINT; dwFlags: DWORD): BOOL; stdcall;
{ achPath may be nil }
{$EXTERNALSYM PathCommonPrefixA}
function PathCommonPrefixA(pszFile1, pszFile2, achPath: PAnsiChar): Integer; stdcall;
{$EXTERNALSYM PathCommonPrefixW}
function PathCommonPrefixW(pszFile1, pszFile2, achPath: PWideChar): Integer; stdcall;
{$EXTERNALSYM PathCommonPrefix}
function PathCommonPrefix(pszFile1, pszFile2, achPath: PChar): Integer; stdcall;
{$EXTERNALSYM PathFileExistsA}
function PathFileExistsA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathFileExistsW}
function PathFileExistsW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathFileExists}
function PathFileExists(pszPath: PChar): BOOL; stdcall;
{ The result points into pszPath (at the '.', or at the terminating null). }
{$EXTERNALSYM PathFindExtensionA}
function PathFindExtensionA(pszPath: PAnsiChar): PAnsiChar; stdcall;
{$EXTERNALSYM PathFindExtensionW}
function PathFindExtensionW(pszPath: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM PathFindExtension}
function PathFindExtension(pszPath: PChar): PChar; stdcall;
{$EXTERNALSYM PathFindFileNameA}
function PathFindFileNameA(pszPath: PAnsiChar): PAnsiChar; stdcall;
{$EXTERNALSYM PathFindFileNameW}
function PathFindFileNameW(pszPath: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM PathFindFileName}
function PathFindFileName(pszPath: PChar): PChar; stdcall;
{$EXTERNALSYM PathFindNextComponentA}
function PathFindNextComponentA(pszPath: PAnsiChar): PAnsiChar; stdcall;
{$EXTERNALSYM PathFindNextComponentW}
function PathFindNextComponentW(pszPath: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM PathFindNextComponent}
function PathFindNextComponent(pszPath: PChar): PChar; stdcall;
{ ppszOtherDirs: nil, or a nil-terminated array of directories searched first }
{$EXTERNALSYM PathFindOnPathA}
function PathFindOnPathA(pszPath: PAnsiChar; ppszOtherDirs: PPAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathFindOnPathW}
function PathFindOnPathW(pszPath: PWideChar; ppszOtherDirs: PPWideChar): BOOL; stdcall;
{$EXTERNALSYM PathFindOnPath}
function PathFindOnPath(pszPath: PChar; ppszOtherDirs: PPChar): BOOL; stdcall;
{$EXTERNALSYM PathFindSuffixArrayA}
function PathFindSuffixArrayA(pszPath: PAnsiChar; apszSuffix: PPAnsiChar;
  iArraySize: Integer): PAnsiChar; stdcall;
{$EXTERNALSYM PathFindSuffixArrayW}
function PathFindSuffixArrayW(pszPath: PWideChar; apszSuffix: PPWideChar;
  iArraySize: Integer): PWideChar; stdcall;
{$EXTERNALSYM PathFindSuffixArray}
function PathFindSuffixArray(pszPath: PChar; apszSuffix: PPChar;
  iArraySize: Integer): PChar; stdcall;
{$EXTERNALSYM PathGetArgsA}
function PathGetArgsA(pszPath: PAnsiChar): PAnsiChar; stdcall;
{$EXTERNALSYM PathGetArgsW}
function PathGetArgsW(pszPath: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM PathGetArgs}
function PathGetArgs(pszPath: PChar): PChar; stdcall;
{$EXTERNALSYM PathIsLFNFileSpecA}
function PathIsLFNFileSpecA(pszName: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathIsLFNFileSpecW}
function PathIsLFNFileSpecW(pszName: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathIsLFNFileSpec}
function PathIsLFNFileSpec(pszName: PChar): BOOL; stdcall;
{ Returns GCT_* flags }
{$EXTERNALSYM PathGetCharTypeA}
function PathGetCharTypeA(ch: AnsiChar): UINT; stdcall;
{$EXTERNALSYM PathGetCharTypeW}
function PathGetCharTypeW(ch: WideChar): UINT; stdcall;
{$EXTERNALSYM PathGetCharType}
function PathGetCharType(ch: Char): UINT; stdcall;
{ 0 = A .. 25 = Z, -1 when the path has no drive letter }
{$EXTERNALSYM PathGetDriveNumberA}
function PathGetDriveNumberA(pszPath: PAnsiChar): Integer; stdcall;
{$EXTERNALSYM PathGetDriveNumberW}
function PathGetDriveNumberW(pszPath: PWideChar): Integer; stdcall;
{$EXTERNALSYM PathGetDriveNumber}
function PathGetDriveNumber(pszPath: PChar): Integer; stdcall;
{$EXTERNALSYM PathIsDirectoryA}
function PathIsDirectoryA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathIsDirectoryW}
function PathIsDirectoryW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathIsDirectory}
function PathIsDirectory(pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathIsDirectoryEmptyA}
function PathIsDirectoryEmptyA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathIsDirectoryEmptyW}
function PathIsDirectoryEmptyW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathIsDirectoryEmpty}
function PathIsDirectoryEmpty(pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathIsFileSpecA}
function PathIsFileSpecA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathIsFileSpecW}
function PathIsFileSpecW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathIsFileSpec}
function PathIsFileSpec(pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathIsPrefixA}
function PathIsPrefixA(pszPrefix, pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathIsPrefixW}
function PathIsPrefixW(pszPrefix, pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathIsPrefix}
function PathIsPrefix(pszPrefix, pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathIsRelativeA}
function PathIsRelativeA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathIsRelativeW}
function PathIsRelativeW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathIsRelative}
function PathIsRelative(pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathIsRootA}
function PathIsRootA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathIsRootW}
function PathIsRootW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathIsRoot}
function PathIsRoot(pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathIsSameRootA}
function PathIsSameRootA(pszPath1, pszPath2: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathIsSameRootW}
function PathIsSameRootW(pszPath1, pszPath2: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathIsSameRoot}
function PathIsSameRoot(pszPath1, pszPath2: PChar): BOOL; stdcall;
{$EXTERNALSYM PathIsUNCA}
function PathIsUNCA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathIsUNCW}
function PathIsUNCW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathIsUNC}
function PathIsUNC(pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathIsNetworkPathA}
function PathIsNetworkPathA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathIsNetworkPathW}
function PathIsNetworkPathW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathIsNetworkPath}
function PathIsNetworkPath(pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathIsUNCServerA}
function PathIsUNCServerA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathIsUNCServerW}
function PathIsUNCServerW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathIsUNCServer}
function PathIsUNCServer(pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathIsUNCServerShareA}
function PathIsUNCServerShareA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathIsUNCServerShareW}
function PathIsUNCServerShareW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathIsUNCServerShare}
function PathIsUNCServerShare(pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathIsContentTypeA}
function PathIsContentTypeA(pszPath, pszContentType: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathIsContentTypeW}
function PathIsContentTypeW(pszPath, pszContentType: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathIsContentType}
function PathIsContentType(pszPath, pszContentType: PChar): BOOL; stdcall;
{$EXTERNALSYM PathIsURLA}
function PathIsURLA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathIsURLW}
function PathIsURLW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathIsURL}
function PathIsURL(pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathMakePrettyA}
function PathMakePrettyA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathMakePrettyW}
function PathMakePrettyW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathMakePretty}
function PathMakePretty(pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathMatchSpecA}
function PathMatchSpecA(pszFile, pszSpec: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathMatchSpecW}
function PathMatchSpecW(pszFile, pszSpec: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathMatchSpec}
function PathMatchSpec(pszFile, pszSpec: PChar): BOOL; stdcall;
{ Windows Vista; run-time bound. S_OK on a match, S_FALSE otherwise.
  Fallback: E_NOTIMPL. }
{$EXTERNALSYM PathMatchSpecExA}
function PathMatchSpecExA(pszFile, pszSpec: PAnsiChar; dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM PathMatchSpecExW}
function PathMatchSpecExW(pszFile, pszSpec: PWideChar; dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM PathMatchSpecEx}
function PathMatchSpecEx(pszFile, pszSpec: PChar; dwFlags: DWORD): HRESULT; stdcall;
{ Splits 'file,index' in place: returns the index, leaves the file name. }
{$EXTERNALSYM PathParseIconLocationA}
function PathParseIconLocationA(pszIconFile: PAnsiChar): Integer; stdcall;
{$EXTERNALSYM PathParseIconLocationW}
function PathParseIconLocationW(pszIconFile: PWideChar): Integer; stdcall;
{$EXTERNALSYM PathParseIconLocation}
function PathParseIconLocation(pszIconFile: PChar): Integer; stdcall;
{$EXTERNALSYM PathQuoteSpacesA}
function PathQuoteSpacesA(lpsz: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathQuoteSpacesW}
function PathQuoteSpacesW(lpsz: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathQuoteSpaces}
function PathQuoteSpaces(lpsz: PChar): BOOL; stdcall;
{ dwAttrFrom/dwAttrTo: FILE_ATTRIBUTE_DIRECTORY for a directory, else 0 }
{$EXTERNALSYM PathRelativePathToA}
function PathRelativePathToA(pszPath, pszFrom: PAnsiChar; dwAttrFrom: DWORD;
  pszTo: PAnsiChar; dwAttrTo: DWORD): BOOL; stdcall;
{$EXTERNALSYM PathRelativePathToW}
function PathRelativePathToW(pszPath, pszFrom: PWideChar; dwAttrFrom: DWORD;
  pszTo: PWideChar; dwAttrTo: DWORD): BOOL; stdcall;
{$EXTERNALSYM PathRelativePathTo}
function PathRelativePathTo(pszPath, pszFrom: PChar; dwAttrFrom: DWORD;
  pszTo: PChar; dwAttrTo: DWORD): BOOL; stdcall;
{$EXTERNALSYM PathRemoveArgsA}
procedure PathRemoveArgsA(pszPath: PAnsiChar); stdcall;
{$EXTERNALSYM PathRemoveArgsW}
procedure PathRemoveArgsW(pszPath: PWideChar); stdcall;
{$EXTERNALSYM PathRemoveArgs}
procedure PathRemoveArgs(pszPath: PChar); stdcall;
{$EXTERNALSYM PathRemoveBackslashA}
function PathRemoveBackslashA(pszPath: PAnsiChar): PAnsiChar; stdcall;
{$EXTERNALSYM PathRemoveBackslashW}
function PathRemoveBackslashW(pszPath: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM PathRemoveBackslash}
function PathRemoveBackslash(pszPath: PChar): PChar; stdcall;
{$EXTERNALSYM PathRemoveBlanksA}
procedure PathRemoveBlanksA(pszPath: PAnsiChar); stdcall;
{$EXTERNALSYM PathRemoveBlanksW}
procedure PathRemoveBlanksW(pszPath: PWideChar); stdcall;
{$EXTERNALSYM PathRemoveBlanks}
procedure PathRemoveBlanks(pszPath: PChar); stdcall;
{$EXTERNALSYM PathRemoveExtensionA}
procedure PathRemoveExtensionA(pszPath: PAnsiChar); stdcall;
{$EXTERNALSYM PathRemoveExtensionW}
procedure PathRemoveExtensionW(pszPath: PWideChar); stdcall;
{$EXTERNALSYM PathRemoveExtension}
procedure PathRemoveExtension(pszPath: PChar); stdcall;
{$EXTERNALSYM PathRemoveFileSpecA}
function PathRemoveFileSpecA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathRemoveFileSpecW}
function PathRemoveFileSpecW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathRemoveFileSpec}
function PathRemoveFileSpec(pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathRenameExtensionA}
function PathRenameExtensionA(pszPath, pszExt: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathRenameExtensionW}
function PathRenameExtensionW(pszPath, pszExt: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathRenameExtension}
function PathRenameExtension(pszPath, pszExt: PChar): BOOL; stdcall;
{$EXTERNALSYM PathSearchAndQualifyA}
function PathSearchAndQualifyA(pszPath, pszBuf: PAnsiChar; cchBuf: UINT): BOOL; stdcall;
{$EXTERNALSYM PathSearchAndQualifyW}
function PathSearchAndQualifyW(pszPath, pszBuf: PWideChar; cchBuf: UINT): BOOL; stdcall;
{$EXTERNALSYM PathSearchAndQualify}
function PathSearchAndQualify(pszPath, pszBuf: PChar; cchBuf: UINT): BOOL; stdcall;
{$EXTERNALSYM PathSetDlgItemPathA}
procedure PathSetDlgItemPathA(hDlg: HWND; id: Integer; pszPath: PAnsiChar); stdcall;
{$EXTERNALSYM PathSetDlgItemPathW}
procedure PathSetDlgItemPathW(hDlg: HWND; id: Integer; pszPath: PWideChar); stdcall;
{$EXTERNALSYM PathSetDlgItemPath}
procedure PathSetDlgItemPath(hDlg: HWND; id: Integer; pszPath: PChar); stdcall;
{$EXTERNALSYM PathSkipRootA}
function PathSkipRootA(pszPath: PAnsiChar): PAnsiChar; stdcall;
{$EXTERNALSYM PathSkipRootW}
function PathSkipRootW(pszPath: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM PathSkipRoot}
function PathSkipRoot(pszPath: PChar): PChar; stdcall;
{$EXTERNALSYM PathStripPathA}
procedure PathStripPathA(pszPath: PAnsiChar); stdcall;
{$EXTERNALSYM PathStripPathW}
procedure PathStripPathW(pszPath: PWideChar); stdcall;
{$EXTERNALSYM PathStripPath}
procedure PathStripPath(pszPath: PChar); stdcall;
{$EXTERNALSYM PathStripToRootA}
function PathStripToRootA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathStripToRootW}
function PathStripToRootW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathStripToRoot}
function PathStripToRoot(pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathUnquoteSpacesA}
function PathUnquoteSpacesA(lpsz: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathUnquoteSpacesW}
function PathUnquoteSpacesW(lpsz: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathUnquoteSpaces}
function PathUnquoteSpaces(lpsz: PChar): BOOL; stdcall;
{$EXTERNALSYM PathMakeSystemFolderA}
function PathMakeSystemFolderA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathMakeSystemFolderW}
function PathMakeSystemFolderW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathMakeSystemFolder}
function PathMakeSystemFolder(pszPath: PChar): BOOL; stdcall;
{$EXTERNALSYM PathUnmakeSystemFolderA}
function PathUnmakeSystemFolderA(pszPath: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM PathUnmakeSystemFolderW}
function PathUnmakeSystemFolderW(pszPath: PWideChar): BOOL; stdcall;
{$EXTERNALSYM PathUnmakeSystemFolder}
function PathUnmakeSystemFolder(pszPath: PChar): BOOL; stdcall;
{ pszPath may be nil when dwAttrb holds the folder's attributes }
{$EXTERNALSYM PathIsSystemFolderA}
function PathIsSystemFolderA(pszPath: PAnsiChar; dwAttrb: DWORD): BOOL; stdcall;
{$EXTERNALSYM PathIsSystemFolderW}
function PathIsSystemFolderW(pszPath: PWideChar; dwAttrb: DWORD): BOOL; stdcall;
{$EXTERNALSYM PathIsSystemFolder}
function PathIsSystemFolder(pszPath: PChar; dwAttrb: DWORD): BOOL; stdcall;
{$EXTERNALSYM PathUndecorateA}
procedure PathUndecorateA(pszPath: PAnsiChar); stdcall;
{$EXTERNALSYM PathUndecorateW}
procedure PathUndecorateW(pszPath: PWideChar); stdcall;
{$EXTERNALSYM PathUndecorate}
procedure PathUndecorate(pszPath: PChar); stdcall;
{$EXTERNALSYM PathUnExpandEnvStringsA}
function PathUnExpandEnvStringsA(pszPath, pszBuf: PAnsiChar; cchBuf: UINT): BOOL; stdcall;
{$EXTERNALSYM PathUnExpandEnvStringsW}
function PathUnExpandEnvStringsW(pszPath, pszBuf: PWideChar; cchBuf: UINT): BOOL; stdcall;
{$EXTERNALSYM PathUnExpandEnvStrings}
function PathUnExpandEnvStrings(pszPath, pszBuf: PChar; cchBuf: UINT): BOOL; stdcall;

{ PathIsContentType(pszPath, SZ_CONTENTTYPE_HTML) }
{$EXTERNALSYM PathIsHTMLFileA}
function PathIsHTMLFileA(pszPath: PAnsiChar): BOOL;
{$EXTERNALSYM PathIsHTMLFileW}
function PathIsHTMLFileW(pszPath: PWideChar): BOOL;
{$EXTERNALSYM PathIsHTMLFile}
function PathIsHTMLFile(pszPath: PChar): BOOL;

{ ====== URL functions ===================================================== }

type
  { URL_SCHEME values (ParseURL, nScheme) }
  {$EXTERNALSYM URL_SCHEME}
  URL_SCHEME = Integer;

const
  {$EXTERNALSYM URL_SCHEME_INVALID}
  URL_SCHEME_INVALID       = -1;
  {$EXTERNALSYM URL_SCHEME_UNKNOWN}
  URL_SCHEME_UNKNOWN       = 0;
  {$EXTERNALSYM URL_SCHEME_FTP}
  URL_SCHEME_FTP           = 1;
  {$EXTERNALSYM URL_SCHEME_HTTP}
  URL_SCHEME_HTTP          = 2;
  {$EXTERNALSYM URL_SCHEME_GOPHER}
  URL_SCHEME_GOPHER        = 3;
  {$EXTERNALSYM URL_SCHEME_MAILTO}
  URL_SCHEME_MAILTO        = 4;
  {$EXTERNALSYM URL_SCHEME_NEWS}
  URL_SCHEME_NEWS          = 5;
  {$EXTERNALSYM URL_SCHEME_NNTP}
  URL_SCHEME_NNTP          = 6;
  {$EXTERNALSYM URL_SCHEME_TELNET}
  URL_SCHEME_TELNET        = 7;
  {$EXTERNALSYM URL_SCHEME_WAIS}
  URL_SCHEME_WAIS          = 8;
  {$EXTERNALSYM URL_SCHEME_FILE}
  URL_SCHEME_FILE          = 9;
  {$EXTERNALSYM URL_SCHEME_MK}
  URL_SCHEME_MK            = 10;
  {$EXTERNALSYM URL_SCHEME_HTTPS}
  URL_SCHEME_HTTPS         = 11;
  {$EXTERNALSYM URL_SCHEME_SHELL}
  URL_SCHEME_SHELL         = 12;
  {$EXTERNALSYM URL_SCHEME_SNEWS}
  URL_SCHEME_SNEWS         = 13;
  {$EXTERNALSYM URL_SCHEME_LOCAL}
  URL_SCHEME_LOCAL         = 14;
  {$EXTERNALSYM URL_SCHEME_JAVASCRIPT}
  URL_SCHEME_JAVASCRIPT    = 15;
  {$EXTERNALSYM URL_SCHEME_VBSCRIPT}
  URL_SCHEME_VBSCRIPT      = 16;
  {$EXTERNALSYM URL_SCHEME_ABOUT}
  URL_SCHEME_ABOUT         = 17;
  {$EXTERNALSYM URL_SCHEME_RES}
  URL_SCHEME_RES           = 18;
  {$EXTERNALSYM URL_SCHEME_MSSHELLROOTED}
  URL_SCHEME_MSSHELLROOTED = 19;
  {$EXTERNALSYM URL_SCHEME_MSSHELLIDLIST}
  URL_SCHEME_MSSHELLIDLIST = 20;
  {$EXTERNALSYM URL_SCHEME_MSHELP}
  URL_SCHEME_MSHELP        = 21;
  {$EXTERNALSYM URL_SCHEME_MSSHELLDEVICE}
  URL_SCHEME_MSSHELLDEVICE = 22;
  {$EXTERNALSYM URL_SCHEME_WILDCARD}
  URL_SCHEME_WILDCARD      = 23;
  {$EXTERNALSYM URL_SCHEME_SEARCH_MS}
  URL_SCHEME_SEARCH_MS     = 24;   // Windows Vista
  {$EXTERNALSYM URL_SCHEME_SEARCH}
  URL_SCHEME_SEARCH        = 25;   // Windows Vista SP1
  {$EXTERNALSYM URL_SCHEME_KNOWNFOLDER}
  URL_SCHEME_KNOWNFOLDER   = 26;   // Windows 7
  {$EXTERNALSYM URL_SCHEME_MAXVALUE}
  URL_SCHEME_MAXVALUE      = 27;   // value of Windows SDK 10.0.26100

type
  { UrlGetPart dwPart }
  {$EXTERNALSYM URL_PART}
  URL_PART = DWORD;

const
  {$EXTERNALSYM URL_PART_NONE}
  URL_PART_NONE     = 0;
  {$EXTERNALSYM URL_PART_SCHEME}
  URL_PART_SCHEME   = 1;
  {$EXTERNALSYM URL_PART_HOSTNAME}
  URL_PART_HOSTNAME = 2;
  {$EXTERNALSYM URL_PART_USERNAME}
  URL_PART_USERNAME = 3;
  {$EXTERNALSYM URL_PART_PASSWORD}
  URL_PART_PASSWORD = 4;
  {$EXTERNALSYM URL_PART_PORT}
  URL_PART_PORT     = 5;
  {$EXTERNALSYM URL_PART_QUERY}
  URL_PART_QUERY    = 6;

type
  { The C enumeration URLIS (UrlIs); see the unit header for the name. }
  TUrlIs = DWORD;

const
  {$EXTERNALSYM URLIS_URL}
  URLIS_URL       = 0;
  {$EXTERNALSYM URLIS_OPAQUE}
  URLIS_OPAQUE    = 1;
  {$EXTERNALSYM URLIS_NOHISTORY}
  URLIS_NOHISTORY = 2;
  {$EXTERNALSYM URLIS_FILEURL}
  URLIS_FILEURL   = 3;
  {$EXTERNALSYM URLIS_APPLIABLE}
  URLIS_APPLIABLE = 4;
  {$EXTERNALSYM URLIS_DIRECTORY}
  URLIS_DIRECTORY = 5;
  {$EXTERNALSYM URLIS_HASQUERY}
  URLIS_HASQUERY  = 6;

  { dwFlags of UrlEscape, UrlUnescape, UrlCanonicalize, UrlCombine,
    UrlCreateFromPath, PathCreateFromUrl }
  {$EXTERNALSYM URL_UNESCAPE}
  URL_UNESCAPE                   = $10000000;
  {$EXTERNALSYM URL_ESCAPE_UNSAFE}
  URL_ESCAPE_UNSAFE              = $20000000;
  {$EXTERNALSYM URL_PLUGGABLE_PROTOCOL}
  URL_PLUGGABLE_PROTOCOL         = $40000000;
  {$EXTERNALSYM URL_WININET_COMPATIBILITY}
  URL_WININET_COMPATIBILITY      = $80000000;
  {$EXTERNALSYM URL_DONT_ESCAPE_EXTRA_INFO}
  URL_DONT_ESCAPE_EXTRA_INFO     = $02000000;
  {$EXTERNALSYM URL_DONT_UNESCAPE_EXTRA_INFO}
  URL_DONT_UNESCAPE_EXTRA_INFO   = URL_DONT_ESCAPE_EXTRA_INFO;
  {$EXTERNALSYM URL_BROWSER_MODE}
  URL_BROWSER_MODE               = URL_DONT_ESCAPE_EXTRA_INFO;
  {$EXTERNALSYM URL_ESCAPE_SPACES_ONLY}
  URL_ESCAPE_SPACES_ONLY         = $04000000;
  {$EXTERNALSYM URL_DONT_SIMPLIFY}
  URL_DONT_SIMPLIFY              = $08000000;
  {$EXTERNALSYM URL_NO_META}
  URL_NO_META                    = URL_DONT_SIMPLIFY;
  {$EXTERNALSYM URL_UNESCAPE_INPLACE}
  URL_UNESCAPE_INPLACE           = $00100000;
  {$EXTERNALSYM URL_CONVERT_IF_DOSPATH}
  URL_CONVERT_IF_DOSPATH         = $00200000;
  {$EXTERNALSYM URL_UNESCAPE_HIGH_ANSI_ONLY}
  URL_UNESCAPE_HIGH_ANSI_ONLY    = $00400000;
  {$EXTERNALSYM URL_INTERNAL_PATH}
  URL_INTERNAL_PATH              = $00800000;  // Will escape #'s in paths
  {$EXTERNALSYM URL_FILE_USE_PATHURL}
  URL_FILE_USE_PATHURL           = $00010000;
  {$EXTERNALSYM URL_DONT_UNESCAPE}
  URL_DONT_UNESCAPE              = $00020000;  // Do not unescape the path/url at all
  {$EXTERNALSYM URL_ESCAPE_AS_UTF8}
  URL_ESCAPE_AS_UTF8             = $00040000;  // Windows 7: percent-encode all non-ASCII characters as UTF-8
  {$EXTERNALSYM URL_UNESCAPE_AS_UTF8}
  URL_UNESCAPE_AS_UTF8           = URL_ESCAPE_AS_UTF8;  // Windows 8
  {$EXTERNALSYM URL_ESCAPE_ASCII_URI_COMPONENT}
  URL_ESCAPE_ASCII_URI_COMPONENT = $00080000;  // Windows 8: percent-encode all ASCII characters outside the RFC 3986 unreserved set
  {$EXTERNALSYM URL_ESCAPE_URI_COMPONENT}
  URL_ESCAPE_URI_COMPONENT       = URL_ESCAPE_ASCII_URI_COMPONENT or URL_ESCAPE_AS_UTF8;
  {$EXTERNALSYM URL_UNESCAPE_URI_COMPONENT}
  URL_UNESCAPE_URI_COMPONENT     = URL_UNESCAPE_AS_UTF8;
  {$EXTERNALSYM URL_ESCAPE_PERCENT}
  URL_ESCAPE_PERCENT             = $00001000;
  {$EXTERNALSYM URL_ESCAPE_SEGMENT_ONLY}
  URL_ESCAPE_SEGMENT_ONLY        = $00002000;  // Treat the entire URL param as one URL segment.

  { UrlGetPart dwFlags }
  {$EXTERNALSYM URL_PARTFLAG_KEEPSCHEME}
  URL_PARTFLAG_KEEPSCHEME        = $00000001;

  { UrlApplyScheme dwFlags }
  {$EXTERNALSYM URL_APPLY_DEFAULT}
  URL_APPLY_DEFAULT              = $00000001;
  {$EXTERNALSYM URL_APPLY_GUESSSCHEME}
  URL_APPLY_GUESSSCHEME          = $00000002;
  {$EXTERNALSYM URL_APPLY_GUESSFILE}
  URL_APPLY_GUESSFILE            = $00000004;
  {$EXTERNALSYM URL_APPLY_FORCEAPPLY}
  URL_APPLY_FORCEAPPLY           = $00000008;

type
  { ParseURL: set cbSize := SizeOf(TParsedUrl) first. pszProtocol and
    pszSuffix point into the string passed to ParseURL. }
  {$EXTERNALSYM PPARSEDURLA}
  PPARSEDURLA = ^tagPARSEDURLA;
  {$EXTERNALSYM PPARSEDURLW}
  PPARSEDURLW = ^tagPARSEDURLW;
  {$EXTERNALSYM PPARSEDURL}
  PPARSEDURL = PPARSEDURLA;
  {$EXTERNALSYM tagPARSEDURLA}
  tagPARSEDURLA = record
    cbSize: DWORD;
    pszProtocol: PAnsiChar;
    cchProtocol: UINT;
    pszSuffix: PAnsiChar;
    cchSuffix: UINT;
    nScheme: UINT;                // One of URL_SCHEME_*
  end;
  {$EXTERNALSYM tagPARSEDURLW}
  tagPARSEDURLW = record
    cbSize: DWORD;
    pszProtocol: PWideChar;
    cchProtocol: UINT;
    pszSuffix: PWideChar;
    cchSuffix: UINT;
    nScheme: UINT;                // One of URL_SCHEME_*
  end;
  {$EXTERNALSYM PARSEDURLA}
  PARSEDURLA = tagPARSEDURLA;
  {$EXTERNALSYM PARSEDURLW}
  PARSEDURLW = tagPARSEDURLW;
  {$EXTERNALSYM PARSEDURL}
  PARSEDURL = PARSEDURLA;
  TParsedUrlA = tagPARSEDURLA;
  TParsedUrlW = tagPARSEDURLW;
  TParsedUrl = TParsedUrlA;

{ Returns 0 when equal, like lstrcmp }
{$EXTERNALSYM UrlCompareA}
function UrlCompareA(psz1, psz2: PAnsiChar; fIgnoreSlash: BOOL): Integer; stdcall;
{$EXTERNALSYM UrlCompareW}
function UrlCompareW(psz1, psz2: PWideChar; fIgnoreSlash: BOOL): Integer; stdcall;
{$EXTERNALSYM UrlCompare}
function UrlCompare(psz1, psz2: PChar; fIgnoreSlash: BOOL): Integer; stdcall;
{ The character counts (pcch*) are in: the size of the buffer, out: the
  length of the result without the null (or the size needed, with
  E_POINTER). }
{$EXTERNALSYM UrlCombineA}
function UrlCombineA(pszBase, pszRelative, pszCombined: PAnsiChar; var pcchCombined: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlCombineW}
function UrlCombineW(pszBase, pszRelative, pszCombined: PWideChar; var pcchCombined: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlCombine}
function UrlCombine(pszBase, pszRelative, pszCombined: PChar; var pcchCombined: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlCanonicalizeA}
function UrlCanonicalizeA(pszUrl, pszCanonicalized: PAnsiChar; var pcchCanonicalized: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlCanonicalizeW}
function UrlCanonicalizeW(pszUrl, pszCanonicalized: PWideChar; var pcchCanonicalized: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlCanonicalize}
function UrlCanonicalize(pszUrl, pszCanonicalized: PChar; var pcchCanonicalized: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlIsOpaqueA}
function UrlIsOpaqueA(pszURL: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM UrlIsOpaqueW}
function UrlIsOpaqueW(pszURL: PWideChar): BOOL; stdcall;
{$EXTERNALSYM UrlIsOpaque}
function UrlIsOpaque(pszURL: PChar): BOOL; stdcall;
{$EXTERNALSYM UrlIsNoHistoryA}
function UrlIsNoHistoryA(pszURL: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM UrlIsNoHistoryW}
function UrlIsNoHistoryW(pszURL: PWideChar): BOOL; stdcall;
{$EXTERNALSYM UrlIsNoHistory}
function UrlIsNoHistory(pszURL: PChar): BOOL; stdcall;
{ dwUrlIs: URLIS_* }
{$EXTERNALSYM UrlIsA}
function UrlIsA(pszUrl: PAnsiChar; dwUrlIs: TUrlIs): BOOL; stdcall;
{$EXTERNALSYM UrlIsW}
function UrlIsW(pszUrl: PWideChar; dwUrlIs: TUrlIs): BOOL; stdcall;
{$EXTERNALSYM UrlIs}
function UrlIs(pszUrl: PChar; dwUrlIs: TUrlIs): BOOL; stdcall;
{ The result points at the '#' fragment inside pszURL, or is nil. }
{$EXTERNALSYM UrlGetLocationA}
function UrlGetLocationA(pszURL: PAnsiChar): PAnsiChar; stdcall;
{$EXTERNALSYM UrlGetLocationW}
function UrlGetLocationW(pszURL: PWideChar): PWideChar; stdcall;
{$EXTERNALSYM UrlGetLocation}
function UrlGetLocation(pszURL: PChar): PChar; stdcall;
{ With URL_UNESCAPE_INPLACE, pszUnescaped and pcchUnescaped may be nil. }
{$EXTERNALSYM UrlUnescapeA}
function UrlUnescapeA(pszUrl, pszUnescaped: PAnsiChar; pcchUnescaped: PDWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlUnescapeW}
function UrlUnescapeW(pszUrl, pszUnescaped: PWideChar; pcchUnescaped: PDWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlUnescape}
function UrlUnescape(pszUrl, pszUnescaped: PChar; pcchUnescaped: PDWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlEscapeA}
function UrlEscapeA(pszUrl, pszEscaped: PAnsiChar; var pcchEscaped: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlEscapeW}
function UrlEscapeW(pszUrl, pszEscaped: PWideChar; var pcchEscaped: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlEscape}
function UrlEscape(pszUrl, pszEscaped: PChar; var pcchEscaped: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{ 'C:\a b.txt' -> 'file:///C:/a%20b.txt' }
{$EXTERNALSYM UrlCreateFromPathA}
function UrlCreateFromPathA(pszPath, pszUrl: PAnsiChar; var pcchUrl: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlCreateFromPathW}
function UrlCreateFromPathW(pszPath, pszUrl: PWideChar; var pcchUrl: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlCreateFromPath}
function UrlCreateFromPath(pszPath, pszUrl: PChar; var pcchUrl: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM PathCreateFromUrlA}
function PathCreateFromUrlA(pszUrl, pszPath: PAnsiChar; var pcchPath: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM PathCreateFromUrlW}
function PathCreateFromUrlW(pszUrl, pszPath: PWideChar; var pcchPath: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM PathCreateFromUrl}
function PathCreateFromUrl(pszUrl, pszPath: PChar; var pcchPath: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{ Windows Vista; run-time bound. The path is allocated with CoTaskMemAlloc.
  Fallback: E_NOTIMPL and ppszOut = nil. }
{$EXTERNALSYM PathCreateFromUrlAlloc}
function PathCreateFromUrlAlloc(pszIn: PWideChar; out ppszOut: PWideChar;
  dwFlags: DWORD): HRESULT; stdcall;
{ cbHash: 1 .. 256 bytes }
{$EXTERNALSYM UrlHashA}
function UrlHashA(pszUrl: PAnsiChar; pbHash: Pointer; cbHash: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlHashW}
function UrlHashW(pszUrl: PWideChar; pbHash: Pointer; cbHash: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlHash}
function UrlHash(pszUrl: PChar; pbHash: Pointer; cbHash: DWORD): HRESULT; stdcall;
{ dwPart: URL_PART_*; dwFlags: 0 or URL_PARTFLAG_KEEPSCHEME }
{$EXTERNALSYM UrlGetPartA}
function UrlGetPartA(pszIn, pszOut: PAnsiChar; var pcchOut: DWORD; dwPart: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlGetPartW}
function UrlGetPartW(pszIn, pszOut: PWideChar; var pcchOut: DWORD; dwPart: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlGetPart}
function UrlGetPart(pszIn, pszOut: PChar; var pcchOut: DWORD; dwPart: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlApplySchemeA}
function UrlApplySchemeA(pszIn, pszOut: PAnsiChar; var pcchOut: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlApplySchemeW}
function UrlApplySchemeW(pszIn, pszOut: PWideChar; var pcchOut: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UrlApplyScheme}
function UrlApplyScheme(pszIn, pszOut: PChar; var pcchOut: DWORD;
  dwFlags: DWORD): HRESULT; stdcall;
{ A hash of cbData bytes into cbHash bytes (1 .. 256); not cryptographic. }
{$EXTERNALSYM HashData}
function HashData(pbData: Pointer; cbData: DWORD; pbHash: Pointer; cbHash: DWORD): HRESULT; stdcall;
{ Unicode only. Windows Vista; run-time bound. Fallback: E_NOTIMPL. }
{$EXTERNALSYM UrlFixupW}
function UrlFixupW(pcszUrl, pszTranslatedUrl: PWideChar; cchMax: DWORD): HRESULT; stdcall;
{ Windows XP exports ParseURL by ordinal only; run-time bound by name
  (Windows Vista and later). Fallback: E_NOTIMPL. }
{$EXTERNALSYM ParseURLA}
function ParseURLA(pcszURL: PAnsiChar; var ppu: TParsedUrlA): HRESULT; stdcall;
{$EXTERNALSYM ParseURLW}
function ParseURLW(pcszURL: PWideChar; var ppu: TParsedUrlW): HRESULT; stdcall;
{$EXTERNALSYM ParseURL}
function ParseURL(pcszURL: PChar; var ppu: TParsedUrl): HRESULT; stdcall;

{ UrlIs(pszURL, URLIS_FILEURL) }
{$EXTERNALSYM UrlIsFileUrlA}
function UrlIsFileUrlA(pszURL: PAnsiChar): BOOL;
{$EXTERNALSYM UrlIsFileUrlW}
function UrlIsFileUrlW(pszURL: PWideChar): BOOL;
{$EXTERNALSYM UrlIsFileUrl}
function UrlIsFileUrl(pszURL: PChar): BOOL;
{ UrlCanonicalize(pszUrl, pszEscaped, pcchEscaped,
  URL_ESCAPE_SPACES_ONLY or URL_DONT_ESCAPE_EXTRA_INFO) }
{$EXTERNALSYM UrlEscapeSpaces}
function UrlEscapeSpaces(pszUrl, pszEscaped: PChar; var pcchEscaped: DWORD): HRESULT;
{ UrlUnescape(pszUrl, nil, nil, dwFlags or URL_UNESCAPE_INPLACE) }
{$EXTERNALSYM UrlUnescapeInPlace}
function UrlUnescapeInPlace(pszUrl: PChar; dwFlags: DWORD): HRESULT;

{ ====== Registry functions ================================================ }

const
  { SHRegGetValue srrfFlags: at least one type restriction (SRRF_RT_*) }
  {$EXTERNALSYM SRRF_RT_REG_NONE}
  SRRF_RT_REG_NONE      = $00000001;  // restrict type to REG_NONE
  {$EXTERNALSYM SRRF_RT_REG_SZ}
  SRRF_RT_REG_SZ        = $00000002;  // restrict type to REG_SZ (REG_EXPAND_SZ is expanded unless SRRF_NOEXPAND)
  {$EXTERNALSYM SRRF_RT_REG_EXPAND_SZ}
  SRRF_RT_REG_EXPAND_SZ = $00000004;  // restrict type to REG_EXPAND_SZ (requires SRRF_NOEXPAND)
  {$EXTERNALSYM SRRF_RT_REG_BINARY}
  SRRF_RT_REG_BINARY    = $00000008;  // restrict type to REG_BINARY
  {$EXTERNALSYM SRRF_RT_REG_DWORD}
  SRRF_RT_REG_DWORD     = $00000010;  // restrict type to REG_DWORD
  {$EXTERNALSYM SRRF_RT_REG_MULTI_SZ}
  SRRF_RT_REG_MULTI_SZ  = $00000020;  // restrict type to REG_MULTI_SZ
  {$EXTERNALSYM SRRF_RT_REG_QWORD}
  SRRF_RT_REG_QWORD     = $00000040;  // restrict type to REG_QWORD
  {$EXTERNALSYM SRRF_RT_DWORD}
  SRRF_RT_DWORD         = SRRF_RT_REG_BINARY or SRRF_RT_REG_DWORD;  // 32-bit REG_BINARY or REG_DWORD
  {$EXTERNALSYM SRRF_RT_QWORD}
  SRRF_RT_QWORD         = SRRF_RT_REG_BINARY or SRRF_RT_REG_QWORD;  // 64-bit REG_BINARY or REG_QWORD
  {$EXTERNALSYM SRRF_RT_ANY}
  SRRF_RT_ANY           = $0000FFFF;  // no type restriction
  {$EXTERNALSYM SRRF_RM_ANY}
  SRRF_RM_ANY           = $00000000;  // no boot mode restriction
  {$EXTERNALSYM SRRF_RM_NORMAL}
  SRRF_RM_NORMAL        = $00010000;  // normal boot only
  {$EXTERNALSYM SRRF_RM_SAFE}
  SRRF_RM_SAFE          = $00020000;  // safe mode only
  {$EXTERNALSYM SRRF_RM_SAFENETWORK}
  SRRF_RM_SAFENETWORK   = $00040000;  // safe mode with networking only
  {$EXTERNALSYM SRRF_NOEXPAND}
  SRRF_NOEXPAND         = $10000000;  // do not expand REG_EXPAND_SZ
  {$EXTERNALSYM SRRF_ZEROONFAILURE}
  SRRF_ZEROONFAILURE    = $20000000;  // zero pvData on failure
  {$EXTERNALSYM SRRF_NOVIRT}
  SRRF_NOVIRT           = $40000000;  // fail with ERROR_FILE_NOT_FOUND if the key is virtualized

  { SHRegDeleteUSValue / SHRegDeleteEmptyUSKey }
  {$EXTERNALSYM SHREGDEL_DEFAULT}
  SHREGDEL_DEFAULT = $00000000;  // HKCU, or HKLM if HKCU is not found
  {$EXTERNALSYM SHREGDEL_HKCU}
  SHREGDEL_HKCU    = $00000001;  // HKCU only
  {$EXTERNALSYM SHREGDEL_HKLM}
  SHREGDEL_HKLM    = $00000010;  // HKLM only
  {$EXTERNALSYM SHREGDEL_BOTH}
  SHREGDEL_BOTH    = $00000011;  // both HKCU and HKLM

  { SHRegEnumUSKey / SHRegEnumUSValue / SHRegQueryInfoUSKey }
  {$EXTERNALSYM SHREGENUM_DEFAULT}
  SHREGENUM_DEFAULT = $00000000;  // HKCU, or HKLM if not found
  {$EXTERNALSYM SHREGENUM_HKCU}
  SHREGENUM_HKCU    = $00000001;  // HKCU only
  {$EXTERNALSYM SHREGENUM_HKLM}
  SHREGENUM_HKLM    = $00000010;  // HKLM only
  {$EXTERNALSYM SHREGENUM_BOTH}
  SHREGENUM_BOTH    = $00000011;  // both (not implemented by Windows)

  { SHRegCreateUSKey / SHRegWriteUSValue / SHRegSetUSValue dwFlags }
  {$EXTERNALSYM SHREGSET_HKCU}
  SHREGSET_HKCU       = $00000001;  // Write to HKCU if empty.
  {$EXTERNALSYM SHREGSET_FORCE_HKCU}
  SHREGSET_FORCE_HKCU = $00000002;  // Write to HKCU.
  {$EXTERNALSYM SHREGSET_HKLM}
  SHREGSET_HKLM       = $00000004;  // Write to HKLM if empty.
  {$EXTERNALSYM SHREGSET_FORCE_HKLM}
  SHREGSET_FORCE_HKLM = $00000008;  // Write to HKLM.
  {$EXTERNALSYM SHREGSET_DEFAULT}
  SHREGSET_DEFAULT    = SHREGSET_FORCE_HKCU or SHREGSET_HKLM;

type
  {$EXTERNALSYM SRRF}
  SRRF = Integer;
  {$EXTERNALSYM SHREGDEL_FLAGS}
  SHREGDEL_FLAGS = DWORD;
  {$EXTERNALSYM SHREGENUM_FLAGS}
  SHREGENUM_FLAGS = DWORD;
  { a handle to a user specific (HKCU / HKLM) key }
  {$EXTERNALSYM HUSKEY}
  HUSKEY = THandle;
  {$EXTERNALSYM PHUSKEY}
  PHUSKEY = ^HUSKEY;

{ Deletes a key only if it has no subkeys and no values. }
{$EXTERNALSYM SHDeleteEmptyKeyA}
function SHDeleteEmptyKeyA(hkey: HKEY; pszSubKey: PAnsiChar): LSTATUS; stdcall;
{$EXTERNALSYM SHDeleteEmptyKeyW}
function SHDeleteEmptyKeyW(hkey: HKEY; pszSubKey: PWideChar): LSTATUS; stdcall;
{$EXTERNALSYM SHDeleteEmptyKey}
function SHDeleteEmptyKey(hkey: HKEY; pszSubKey: PChar): LSTATUS; stdcall;
{ Deletes a key with all its subkeys and values. }
{$EXTERNALSYM SHDeleteKeyA}
function SHDeleteKeyA(hkey: HKEY; pszSubKey: PAnsiChar): LSTATUS; stdcall;
{$EXTERNALSYM SHDeleteKeyW}
function SHDeleteKeyW(hkey: HKEY; pszSubKey: PWideChar): LSTATUS; stdcall;
{$EXTERNALSYM SHDeleteKey}
function SHDeleteKey(hkey: HKEY; pszSubKey: PChar): LSTATUS; stdcall;
{ The duplicate must be closed with RegCloseKey. Windows XP may export this
  by ordinal only, so it is run-time bound. Fallback: RegOpenKeyEx(hkey,
  nil, 0, MAXIMUM_ALLOWED), which opens a new handle to the same key; 0 when
  that fails. }
{$EXTERNALSYM SHRegDuplicateHKey}
function SHRegDuplicateHKey(hkey: HKEY): HKEY; stdcall;
{$EXTERNALSYM SHDeleteValueA}
function SHDeleteValueA(hkey: HKEY; pszSubKey, pszValue: PAnsiChar): LSTATUS; stdcall;
{$EXTERNALSYM SHDeleteValueW}
function SHDeleteValueW(hkey: HKEY; pszSubKey, pszValue: PWideChar): LSTATUS; stdcall;
{$EXTERNALSYM SHDeleteValue}
function SHDeleteValue(hkey: HKEY; pszSubKey, pszValue: PChar): LSTATUS; stdcall;
{ Opens the subkey, reads the value and closes the key. Strings are null
  terminated, REG_EXPAND_SZ is expanded and reported as REG_SZ. }
{$EXTERNALSYM SHGetValueA}
function SHGetValueA(hkey: HKEY; pszSubKey, pszValue: PAnsiChar; pdwType: PDWORD;
  pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHGetValueW}
function SHGetValueW(hkey: HKEY; pszSubKey, pszValue: PWideChar; pdwType: PDWORD;
  pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHGetValue}
function SHGetValue(hkey: HKEY; pszSubKey, pszValue: PChar; pdwType: PDWORD;
  pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
{ Creates the subkey if needed and writes the value. }
{$EXTERNALSYM SHSetValueA}
function SHSetValueA(hkey: HKEY; pszSubKey, pszValue: PAnsiChar; dwType: DWORD;
  pvData: Pointer; cbData: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHSetValueW}
function SHSetValueW(hkey: HKEY; pszSubKey, pszValue: PWideChar; dwType: DWORD;
  pvData: Pointer; cbData: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHSetValue}
function SHSetValue(hkey: HKEY; pszSubKey, pszValue: PChar; dwType: DWORD;
  pvData: Pointer; cbData: DWORD): LSTATUS; stdcall;
{ Windows XP SP2; run-time bound. srrfFlags: SRRF_*.
  Fallback: ERROR_CALL_NOT_IMPLEMENTED. }
{$EXTERNALSYM SHRegGetValueA}
function SHRegGetValueA(hkey: HKEY; pszSubKey, pszValue: PAnsiChar; srrfFlags: SRRF;
  pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegGetValueW}
function SHRegGetValueW(hkey: HKEY; pszSubKey, pszValue: PWideChar; srrfFlags: SRRF;
  pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegGetValue}
function SHRegGetValue(hkey: HKEY; pszSubKey, pszValue: PChar; srrfFlags: SRRF;
  pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
{ Reads pwszKey from HKCU, then from HKLM. Run-time bound.
  Fallback: ERROR_CALL_NOT_IMPLEMENTED. }
{$EXTERNALSYM SHRegGetValueFromHKCUHKLM}
function SHRegGetValueFromHKCUHKLM(pwszKey, pwszValue: PWideChar; srrfFlags: SRRF;
  pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
{ Run-time bound. Fallback: fDefault. }
{$EXTERNALSYM SHRegGetBoolValueFromHKCUHKLM}
function SHRegGetBoolValueFromHKCUHKLM(pszKey, pszValue: PWideChar; fDefault: BOOL): BOOL; stdcall;
{ Like RegQueryValueEx, with null terminated strings and REG_EXPAND_SZ
  expanded (reported as REG_SZ). pdwReserved must be nil. }
{$EXTERNALSYM SHQueryValueExA}
function SHQueryValueExA(hkey: HKEY; pszValue: PAnsiChar; pdwReserved: PDWORD;
  pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHQueryValueExW}
function SHQueryValueExW(hkey: HKEY; pszValue: PWideChar; pdwReserved: PDWORD;
  pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHQueryValueEx}
function SHQueryValueEx(hkey: HKEY; pszValue: PChar; pdwReserved: PDWORD;
  pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHEnumKeyExA}
function SHEnumKeyExA(hkey: HKEY; dwIndex: DWORD; pszName: PAnsiChar;
  var pcchName: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHEnumKeyExW}
function SHEnumKeyExW(hkey: HKEY; dwIndex: DWORD; pszName: PWideChar;
  var pcchName: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHEnumKeyEx}
function SHEnumKeyEx(hkey: HKEY; dwIndex: DWORD; pszName: PChar;
  var pcchName: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHEnumValueA}
function SHEnumValueA(hkey: HKEY; dwIndex: DWORD; pszValueName: PAnsiChar;
  pcchValueName: PDWORD; pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHEnumValueW}
function SHEnumValueW(hkey: HKEY; dwIndex: DWORD; pszValueName: PWideChar;
  pcchValueName: PDWORD; pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHEnumValue}
function SHEnumValue(hkey: HKEY; dwIndex: DWORD; pszValueName: PChar;
  pcchValueName: PDWORD; pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHQueryInfoKeyA}
function SHQueryInfoKeyA(hkey: HKEY; pcSubKeys, pcchMaxSubKeyLen, pcValues,
  pcchMaxValueNameLen: PDWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHQueryInfoKeyW}
function SHQueryInfoKeyW(hkey: HKEY; pcSubKeys, pcchMaxSubKeyLen, pcValues,
  pcchMaxValueNameLen: PDWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHQueryInfoKey}
function SHQueryInfoKey(hkey: HKEY; pcSubKeys, pcchMaxSubKeyLen, pcValues,
  pcchMaxValueNameLen: PDWORD): LSTATUS; stdcall;
{ Copies the subkey's values and subkeys (recursively) into hkeyDest.
  fReserved must be 0. }
{$EXTERNALSYM SHCopyKeyA}
function SHCopyKeyA(hkeySrc: HKEY; pszSrcSubKey: PAnsiChar; hkeyDest: HKEY;
  fReserved: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHCopyKeyW}
function SHCopyKeyW(hkeySrc: HKEY; pszSrcSubKey: PWideChar; hkeyDest: HKEY;
  fReserved: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHCopyKey}
function SHCopyKey(hkeySrc: HKEY; pszSrcSubKey: PChar; hkeyDest: HKEY;
  fReserved: DWORD): LSTATUS; stdcall;
{ File system paths with environment variables: SHRegSetPath stores the
  path as REG_EXPAND_SZ with %SystemRoot% ... substituted, SHRegGetPath
  expands it. pszPath: MAX_PATH characters. dwFlags: 0. }
{$EXTERNALSYM SHRegGetPathA}
function SHRegGetPathA(hKey: HKEY; pcszSubKey, pcszValue, pszPath: PAnsiChar;
  dwFlags: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegGetPathW}
function SHRegGetPathW(hKey: HKEY; pcszSubKey, pcszValue, pszPath: PWideChar;
  dwFlags: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegGetPath}
function SHRegGetPath(hKey: HKEY; pcszSubKey, pcszValue, pszPath: PChar;
  dwFlags: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegSetPathA}
function SHRegSetPathA(hKey: HKEY; pcszSubKey, pcszValue, pcszPath: PAnsiChar;
  dwFlags: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegSetPathW}
function SHRegSetPathW(hKey: HKEY; pcszSubKey, pcszValue, pcszPath: PWideChar;
  dwFlags: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegSetPath}
function SHRegSetPath(hKey: HKEY; pcszSubKey, pcszValue, pcszPath: PChar;
  dwFlags: DWORD): LSTATUS; stdcall;

{ User specific keys: a path relative to both HKEY_CURRENT_USER and
  HKEY_LOCAL_MACHINE. }
{$EXTERNALSYM SHRegCreateUSKeyA}
function SHRegCreateUSKeyA(pszPath: PAnsiChar; samDesired: REGSAM; hRelativeUSKey: HUSKEY;
  out phNewUSKey: HUSKEY; dwFlags: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegCreateUSKeyW}
function SHRegCreateUSKeyW(pwzPath: PWideChar; samDesired: REGSAM; hRelativeUSKey: HUSKEY;
  out phNewUSKey: HUSKEY; dwFlags: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegCreateUSKey}
function SHRegCreateUSKey(pszPath: PChar; samDesired: REGSAM; hRelativeUSKey: HUSKEY;
  out phNewUSKey: HUSKEY; dwFlags: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegOpenUSKeyA}
function SHRegOpenUSKeyA(pszPath: PAnsiChar; samDesired: REGSAM; hRelativeUSKey: HUSKEY;
  out phNewUSKey: HUSKEY; fIgnoreHKCU: BOOL): LSTATUS; stdcall;
{$EXTERNALSYM SHRegOpenUSKeyW}
function SHRegOpenUSKeyW(pwzPath: PWideChar; samDesired: REGSAM; hRelativeUSKey: HUSKEY;
  out phNewUSKey: HUSKEY; fIgnoreHKCU: BOOL): LSTATUS; stdcall;
{$EXTERNALSYM SHRegOpenUSKey}
function SHRegOpenUSKey(pszPath: PChar; samDesired: REGSAM; hRelativeUSKey: HUSKEY;
  out phNewUSKey: HUSKEY; fIgnoreHKCU: BOOL): LSTATUS; stdcall;
{$EXTERNALSYM SHRegQueryUSValueA}
function SHRegQueryUSValueA(hUSKey: HUSKEY; pszValue: PAnsiChar; pdwType: PDWORD;
  pvData: Pointer; pcbData: PDWORD; fIgnoreHKCU: BOOL; pvDefaultData: Pointer;
  dwDefaultDataSize: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegQueryUSValueW}
function SHRegQueryUSValueW(hUSKey: HUSKEY; pszValue: PWideChar; pdwType: PDWORD;
  pvData: Pointer; pcbData: PDWORD; fIgnoreHKCU: BOOL; pvDefaultData: Pointer;
  dwDefaultDataSize: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegQueryUSValue}
function SHRegQueryUSValue(hUSKey: HUSKEY; pszValue: PChar; pdwType: PDWORD;
  pvData: Pointer; pcbData: PDWORD; fIgnoreHKCU: BOOL; pvDefaultData: Pointer;
  dwDefaultDataSize: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegWriteUSValueA}
function SHRegWriteUSValueA(hUSKey: HUSKEY; pszValue: PAnsiChar; dwType: DWORD;
  pvData: Pointer; cbData: DWORD; dwFlags: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegWriteUSValueW}
function SHRegWriteUSValueW(hUSKey: HUSKEY; pwzValue: PWideChar; dwType: DWORD;
  pvData: Pointer; cbData: DWORD; dwFlags: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegWriteUSValue}
function SHRegWriteUSValue(hUSKey: HUSKEY; pszValue: PChar; dwType: DWORD;
  pvData: Pointer; cbData: DWORD; dwFlags: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegDeleteUSValueA}
function SHRegDeleteUSValueA(hUSKey: HUSKEY; pszValue: PAnsiChar;
  delRegFlags: SHREGDEL_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegDeleteUSValueW}
function SHRegDeleteUSValueW(hUSKey: HUSKEY; pwzValue: PWideChar;
  delRegFlags: SHREGDEL_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegDeleteUSValue}
function SHRegDeleteUSValue(hUSKey: HUSKEY; pszValue: PChar;
  delRegFlags: SHREGDEL_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegDeleteEmptyUSKeyA}
function SHRegDeleteEmptyUSKeyA(hUSKey: HUSKEY; pszSubKey: PAnsiChar;
  delRegFlags: SHREGDEL_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegDeleteEmptyUSKeyW}
function SHRegDeleteEmptyUSKeyW(hUSKey: HUSKEY; pwzSubKey: PWideChar;
  delRegFlags: SHREGDEL_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegDeleteEmptyUSKey}
function SHRegDeleteEmptyUSKey(hUSKey: HUSKEY; pszSubKey: PChar;
  delRegFlags: SHREGDEL_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegEnumUSKeyA}
function SHRegEnumUSKeyA(hUSKey: HUSKEY; dwIndex: DWORD; pszName: PAnsiChar;
  var pcchName: DWORD; enumRegFlags: SHREGENUM_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegEnumUSKeyW}
function SHRegEnumUSKeyW(hUSKey: HUSKEY; dwIndex: DWORD; pwzName: PWideChar;
  var pcchName: DWORD; enumRegFlags: SHREGENUM_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegEnumUSKey}
function SHRegEnumUSKey(hUSKey: HUSKEY; dwIndex: DWORD; pszName: PChar;
  var pcchName: DWORD; enumRegFlags: SHREGENUM_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegEnumUSValueA}
function SHRegEnumUSValueA(hUSkey: HUSKEY; dwIndex: DWORD; pszValueName: PAnsiChar;
  var pcchValueName: DWORD; pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD;
  enumRegFlags: SHREGENUM_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegEnumUSValueW}
function SHRegEnumUSValueW(hUSkey: HUSKEY; dwIndex: DWORD; pszValueName: PWideChar;
  var pcchValueName: DWORD; pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD;
  enumRegFlags: SHREGENUM_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegEnumUSValue}
function SHRegEnumUSValue(hUSkey: HUSKEY; dwIndex: DWORD; pszValueName: PChar;
  var pcchValueName: DWORD; pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD;
  enumRegFlags: SHREGENUM_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegQueryInfoUSKeyA}
function SHRegQueryInfoUSKeyA(hUSKey: HUSKEY; pcSubKeys, pcchMaxSubKeyLen, pcValues,
  pcchMaxValueNameLen: PDWORD; enumRegFlags: SHREGENUM_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegQueryInfoUSKeyW}
function SHRegQueryInfoUSKeyW(hUSKey: HUSKEY; pcSubKeys, pcchMaxSubKeyLen, pcValues,
  pcchMaxValueNameLen: PDWORD; enumRegFlags: SHREGENUM_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegQueryInfoUSKey}
function SHRegQueryInfoUSKey(hUSKey: HUSKEY; pcSubKeys, pcchMaxSubKeyLen, pcValues,
  pcchMaxValueNameLen: PDWORD; enumRegFlags: SHREGENUM_FLAGS): LSTATUS; stdcall;
{$EXTERNALSYM SHRegCloseUSKey}
function SHRegCloseUSKey(hUSKey: HUSKEY): LSTATUS; stdcall;
{ SHRegOpenUSKey + SHRegQueryUSValue + SHRegCloseUSKey }
{$EXTERNALSYM SHRegGetUSValueA}
function SHRegGetUSValueA(pszSubKey, pszValue: PAnsiChar; pdwType: PDWORD; pvData: Pointer;
  pcbData: PDWORD; fIgnoreHKCU: BOOL; pvDefaultData: Pointer;
  dwDefaultDataSize: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegGetUSValueW}
function SHRegGetUSValueW(pszSubKey, pszValue: PWideChar; pdwType: PDWORD; pvData: Pointer;
  pcbData: PDWORD; fIgnoreHKCU: BOOL; pvDefaultData: Pointer;
  dwDefaultDataSize: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegGetUSValue}
function SHRegGetUSValue(pszSubKey, pszValue: PChar; pdwType: PDWORD; pvData: Pointer;
  pcbData: PDWORD; fIgnoreHKCU: BOOL; pvDefaultData: Pointer;
  dwDefaultDataSize: DWORD): LSTATUS; stdcall;
{ dwFlags: SHREGSET_* }
{$EXTERNALSYM SHRegSetUSValueA}
function SHRegSetUSValueA(pszSubKey, pszValue: PAnsiChar; dwType: DWORD; pvData: Pointer;
  cbData: DWORD; dwFlags: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegSetUSValueW}
function SHRegSetUSValueW(pwzSubKey, pwzValue: PWideChar; dwType: DWORD; pvData: Pointer;
  cbData: DWORD; dwFlags: DWORD): LSTATUS; stdcall;
{$EXTERNALSYM SHRegSetUSValue}
function SHRegSetUSValue(pszSubKey, pszValue: PChar; dwType: DWORD; pvData: Pointer;
  cbData: DWORD; dwFlags: DWORD): LSTATUS; stdcall;
{ Reads 'yes'/'no', 'true'/'false', 1/0 ...; fDefault when the value is
  missing or not boolean. }
{$EXTERNALSYM SHRegGetBoolUSValueA}
function SHRegGetBoolUSValueA(pszSubKey, pszValue: PAnsiChar; fIgnoreHKCU,
  fDefault: BOOL): BOOL; stdcall;
{$EXTERNALSYM SHRegGetBoolUSValueW}
function SHRegGetBoolUSValueW(pszSubKey, pszValue: PWideChar; fIgnoreHKCU,
  fDefault: BOOL): BOOL; stdcall;
{$EXTERNALSYM SHRegGetBoolUSValue}
function SHRegGetBoolUSValue(pszSubKey, pszValue: PChar; fIgnoreHKCU,
  fDefault: BOOL): BOOL; stdcall;

{ ====== Associations ====================================================== }

type
  {$EXTERNALSYM ASSOCF}
  ASSOCF = DWORD;
  {$EXTERNALSYM ASSOCSTR}
  ASSOCSTR = DWORD;
  {$EXTERNALSYM ASSOCKEY}
  ASSOCKEY = DWORD;
  {$EXTERNALSYM ASSOCDATA}
  ASSOCDATA = DWORD;
  {$EXTERNALSYM ASSOCENUM}
  ASSOCENUM = DWORD;
  {$EXTERNALSYM FILETYPEATTRIBUTEFLAGS}
  FILETYPEATTRIBUTEFLAGS = DWORD;

const
  {$EXTERNALSYM ASSOCF_NONE}
  ASSOCF_NONE                 = $00000000;
  {$EXTERNALSYM ASSOCF_INIT_NOREMAPCLSID}
  ASSOCF_INIT_NOREMAPCLSID    = $00000001;  // do not remap clsids to progids
  {$EXTERNALSYM ASSOCF_INIT_BYEXENAME}
  ASSOCF_INIT_BYEXENAME       = $00000002;  // executable is being passed in
  {$EXTERNALSYM ASSOCF_OPEN_BYEXENAME}
  ASSOCF_OPEN_BYEXENAME       = $00000002;  // executable is being passed in
  {$EXTERNALSYM ASSOCF_INIT_DEFAULTTOSTAR}
  ASSOCF_INIT_DEFAULTTOSTAR   = $00000004;  // treat "*" as the BaseClass
  {$EXTERNALSYM ASSOCF_INIT_DEFAULTTOFOLDER}
  ASSOCF_INIT_DEFAULTTOFOLDER = $00000008;  // treat "Folder" as the BaseClass
  {$EXTERNALSYM ASSOCF_NOUSERSETTINGS}
  ASSOCF_NOUSERSETTINGS       = $00000010;  // dont use HKCU
  {$EXTERNALSYM ASSOCF_NOTRUNCATE}
  ASSOCF_NOTRUNCATE           = $00000020;  // dont truncate the return string
  {$EXTERNALSYM ASSOCF_VERIFY}
  ASSOCF_VERIFY               = $00000040;  // verify data is accurate (DISK HITS)
  {$EXTERNALSYM ASSOCF_REMAPRUNDLL}
  ASSOCF_REMAPRUNDLL          = $00000080;  // actually gets info about rundlls target if applicable
  {$EXTERNALSYM ASSOCF_NOFIXUPS}
  ASSOCF_NOFIXUPS             = $00000100;  // attempt to fix errors if found
  {$EXTERNALSYM ASSOCF_IGNOREBASECLASS}
  ASSOCF_IGNOREBASECLASS      = $00000200;  // dont recurse into the baseclass
  {$EXTERNALSYM ASSOCF_INIT_IGNOREUNKNOWN}
  ASSOCF_INIT_IGNOREUNKNOWN   = $00000400;  // dont use the "Unknown" progid, instead fail
  {$EXTERNALSYM ASSOCF_INIT_FIXED_PROGID}
  ASSOCF_INIT_FIXED_PROGID    = $00000800;  // Windows 8: pszAssoc is a ProgId not mapped through the user defaults
  {$EXTERNALSYM ASSOCF_IS_PROTOCOL}
  ASSOCF_IS_PROTOCOL          = $00001000;  // Windows 8: pszAssoc is a URI scheme (without the ':')
  {$EXTERNALSYM ASSOCF_INIT_FOR_FILE}
  ASSOCF_INIT_FOR_FILE        = $00002000;  // Windows 8: with ASSOCF_INIT_FIXED_PROGID, a file extension association
  {$EXTERNALSYM ASSOCF_IS_FULL_URI}
  ASSOCF_IS_FULL_URI          = $00004000;  // Windows 10 1607: pszAssoc is a full http/https URI
  {$EXTERNALSYM ASSOCF_PER_MACHINE_ONLY}
  ASSOCF_PER_MACHINE_ONLY     = $00008000;  // Windows 10 1607: per-machine associations only (no HKCU)
  {$EXTERNALSYM ASSOCF_APP_TO_APP}
  ASSOCF_APP_TO_APP           = $00010000;  // Windows 10 1803: http/https use the policy default browser

  {$EXTERNALSYM ASSOCSTR_COMMAND}
  ASSOCSTR_COMMAND                 = 1;   // shell\verb\command string
  {$EXTERNALSYM ASSOCSTR_EXECUTABLE}
  ASSOCSTR_EXECUTABLE              = 2;   // the executable part of command string
  {$EXTERNALSYM ASSOCSTR_FRIENDLYDOCNAME}
  ASSOCSTR_FRIENDLYDOCNAME         = 3;   // friendly name of the document type
  {$EXTERNALSYM ASSOCSTR_FRIENDLYAPPNAME}
  ASSOCSTR_FRIENDLYAPPNAME         = 4;   // friendly name of executable
  {$EXTERNALSYM ASSOCSTR_NOOPEN}
  ASSOCSTR_NOOPEN                  = 5;   // noopen value
  {$EXTERNALSYM ASSOCSTR_SHELLNEWVALUE}
  ASSOCSTR_SHELLNEWVALUE           = 6;   // query values under the shellnew key
  {$EXTERNALSYM ASSOCSTR_DDECOMMAND}
  ASSOCSTR_DDECOMMAND              = 7;   // template for DDE commands
  {$EXTERNALSYM ASSOCSTR_DDEIFEXEC}
  ASSOCSTR_DDEIFEXEC               = 8;   // DDECOMMAND to use if just create a process
  {$EXTERNALSYM ASSOCSTR_DDEAPPLICATION}
  ASSOCSTR_DDEAPPLICATION          = 9;   // Application name in DDE broadcast
  {$EXTERNALSYM ASSOCSTR_DDETOPIC}
  ASSOCSTR_DDETOPIC                = 10;  // Topic Name in DDE broadcast
  {$EXTERNALSYM ASSOCSTR_INFOTIP}
  ASSOCSTR_INFOTIP                 = 11;  // info tip for an item, or list of properties to create info tip from
  {$EXTERNALSYM ASSOCSTR_QUICKTIP}
  ASSOCSTR_QUICKTIP                = 12;  // same as ASSOCSTR_INFOTIP, only quickly retrievable properties
  {$EXTERNALSYM ASSOCSTR_TILEINFO}
  ASSOCSTR_TILEINFO                = 13;  // important properties for tileview
  {$EXTERNALSYM ASSOCSTR_CONTENTTYPE}
  ASSOCSTR_CONTENTTYPE             = 14;  // MIME Content type
  {$EXTERNALSYM ASSOCSTR_DEFAULTICON}
  ASSOCSTR_DEFAULTICON             = 15;  // Default icon source
  {$EXTERNALSYM ASSOCSTR_SHELLEXTENSION}
  ASSOCSTR_SHELLEXTENSION          = 16;  // Guid string pointing to the Shellex\Shellextensionhandler value.
  {$EXTERNALSYM ASSOCSTR_DROPTARGET}
  ASSOCSTR_DROPTARGET              = 17;  // The CLSID of DropTarget
  {$EXTERNALSYM ASSOCSTR_DELEGATEEXECUTE}
  ASSOCSTR_DELEGATEEXECUTE         = 18;  // The CLSID of DelegateExecute
  {$EXTERNALSYM ASSOCSTR_SUPPORTED_URI_PROTOCOLS}
  ASSOCSTR_SUPPORTED_URI_PROTOCOLS = 19;  // the URI schemes supported, for example "http:https:ftp:file:" or "*"
  {$EXTERNALSYM ASSOCSTR_PROGID}
  ASSOCSTR_PROGID                  = 20;  // Windows 10: ProgId of the associated app (user default)
  {$EXTERNALSYM ASSOCSTR_APPID}
  ASSOCSTR_APPID                   = 21;  // Windows 10: AppUserModelID of the associated app
  {$EXTERNALSYM ASSOCSTR_APPPUBLISHER}
  ASSOCSTR_APPPUBLISHER            = 22;  // Windows 10: publisher of the associated app
  {$EXTERNALSYM ASSOCSTR_APPICONREFERENCE}
  ASSOCSTR_APPICONREFERENCE        = 23;  // Windows 10: icon reference of the associated app
  {$EXTERNALSYM ASSOCSTR_MAX}
  ASSOCSTR_MAX                     = 24;  // value of Windows SDK 10.0.26100

  {$EXTERNALSYM ASSOCKEY_SHELLEXECCLASS}
  ASSOCKEY_SHELLEXECCLASS = 1;  // the key that should be passed to ShellExec(hkeyClass)
  {$EXTERNALSYM ASSOCKEY_APP}
  ASSOCKEY_APP            = 2;  // the "Application" key for the association
  {$EXTERNALSYM ASSOCKEY_CLASS}
  ASSOCKEY_CLASS          = 3;  // the progid or class key
  {$EXTERNALSYM ASSOCKEY_BASECLASS}
  ASSOCKEY_BASECLASS      = 4;  // the BaseClass key
  {$EXTERNALSYM ASSOCKEY_MAX}
  ASSOCKEY_MAX            = 5;

  {$EXTERNALSYM ASSOCDATA_MSIDESCRIPTOR}
  ASSOCDATA_MSIDESCRIPTOR     = 1;  // Component Descriptor to pass to MSI APIs
  {$EXTERNALSYM ASSOCDATA_NOACTIVATEHANDLER}
  ASSOCDATA_NOACTIVATEHANDLER = 2;  // restrict attempts to activate window
  {$EXTERNALSYM ASSOCDATA_UNUSED1}
  ASSOCDATA_UNUSED1           = 3;  // removed QUERYCLASSSTORE
  {$EXTERNALSYM ASSOCDATA_HASPERUSERASSOC}
  ASSOCDATA_HASPERUSERASSOC   = 4;  // defaults to user specified association
  {$EXTERNALSYM ASSOCDATA_EDITFLAGS}
  ASSOCDATA_EDITFLAGS         = 5;  // Edit flags (FTA_*)
  {$EXTERNALSYM ASSOCDATA_VALUE}
  ASSOCDATA_VALUE             = 6;  // use pszExtra as the Value name
  {$EXTERNALSYM ASSOCDATA_MAX}
  ASSOCDATA_MAX               = 7;

  {$EXTERNALSYM ASSOCENUM_NONE}
  ASSOCENUM_NONE = 0;

  { EditFlags of HKCR\<ProgId> (IQueryAssociations.GetData(ASSOCDATA_EDITFLAGS)) }
  {$EXTERNALSYM FTA_None}
  FTA_None                  = $00000000;
  {$EXTERNALSYM FTA_Exclude}
  FTA_Exclude               = $00000001;  // used to exclude (hide) types like drvfile
  {$EXTERNALSYM FTA_Show}
  FTA_Show                  = $00000002;  // used to show types like folder that don't have associations
  {$EXTERNALSYM FTA_HasExtension}
  FTA_HasExtension          = $00000004;  // type has a file name extension
  {$EXTERNALSYM FTA_NoEdit}
  FTA_NoEdit                = $00000008;  // no editing of file type
  {$EXTERNALSYM FTA_NoRemove}
  FTA_NoRemove              = $00000010;  // no removing of the file type
  {$EXTERNALSYM FTA_NoNewVerb}
  FTA_NoNewVerb             = $00000020;  // no adding of verbs
  {$EXTERNALSYM FTA_NoEditVerb}
  FTA_NoEditVerb            = $00000040;  // no editing of predefined verbs
  {$EXTERNALSYM FTA_NoRemoveVerb}
  FTA_NoRemoveVerb          = $00000080;  // no removing of predefined verbs
  {$EXTERNALSYM FTA_NoEditDesc}
  FTA_NoEditDesc            = $00000100;  // no editing of file type description
  {$EXTERNALSYM FTA_NoEditIcon}
  FTA_NoEditIcon            = $00000200;  // no editing of doc icon
  {$EXTERNALSYM FTA_NoEditDflt}
  FTA_NoEditDflt            = $00000400;  // no changing of default verb
  {$EXTERNALSYM FTA_NoEditVerbCmd}
  FTA_NoEditVerbCmd         = $00000800;  // no modification of the commands associated with the verbs
  {$EXTERNALSYM FTA_NoEditVerbExe}
  FTA_NoEditVerbExe         = $00001000;  // no editing of the verb's exe
  {$EXTERNALSYM FTA_NoDDE}
  FTA_NoDDE                 = $00002000;  // no editing of the DDE fields
  {$EXTERNALSYM FTA_NoEditMIME}
  FTA_NoEditMIME            = $00008000;  // no editing of the Content Type or Default Extension fields
  {$EXTERNALSYM FTA_OpenIsSafe}
  FTA_OpenIsSafe            = $00010000;  // the open verb should be invoked automaticaly for downloaded files
  {$EXTERNALSYM FTA_AlwaysUnsafe}
  FTA_AlwaysUnsafe          = $00020000;  // don't allow the "Never ask me" checkbox to be enabled
  {$EXTERNALSYM FTA_NoRecentDocs}
  FTA_NoRecentDocs          = $00100000;  // don't add this file type to the Recent Documents folder
  {$EXTERNALSYM FTA_SafeForElevation}
  FTA_SafeForElevation      = $00200000;  // Windows 8: can be launched in medium IL by a process running in AppContainer
  {$EXTERNALSYM FTA_AlwaysUseDirectInvoke}
  FTA_AlwaysUseDirectInvoke = $00400000;  // Windows 8: use direct invoke even without server headers

  { shlguid.h }
  {$EXTERNALSYM IID_IQueryAssociations}
  IID_IQueryAssociations: TGUID = '{C46CA590-3C3F-11D2-BEE6-0000F805CA57}';
  {$EXTERNALSYM CLSID_QueryAssociations}
  CLSID_QueryAssociations: TGUID = '{A07034FD-6CAA-4954-AC3F-97A27216F98A}';

type
  { Create with AssocCreate(CLSID_QueryAssociations, IQueryAssociations, ...),
    then call Init. }
  {$EXTERNALSYM IQueryAssociations}
  IQueryAssociations = interface(IUnknown)
    ['{C46CA590-3C3F-11D2-BEE6-0000F805CA57}']
    function Init(flags: ASSOCF; pszAssoc: PWideChar; hkProgid: HKEY;
      hwnd: HWND): HResult; stdcall;
    function GetString(flags: ASSOCF; str: ASSOCSTR; pszExtra: PWideChar;
      pszOut: PWideChar; var pcchOut: DWORD): HResult; stdcall;
    function GetKey(flags: ASSOCF; key: ASSOCKEY; pszExtra: PWideChar;
      out phkeyOut: HKEY): HResult; stdcall;
    function GetData(flags: ASSOCF; data: ASSOCDATA; pszExtra: PWideChar;
      pvOut: Pointer; pcbOut: PDWORD): HResult; stdcall;
    function GetEnum(flags: ASSOCF; assocenum: ASSOCENUM; pszExtra: PWideChar;
      const riid: TIID; out ppvOut): HResult; stdcall;
  end;

  { shtypes.h: AssocGetPerceivedType }
  {$EXTERNALSYM PERCEIVED}
  PERCEIVED = Integer;
  {$EXTERNALSYM PERCEIVEDFLAG}
  PERCEIVEDFLAG = DWORD;

const
  {$EXTERNALSYM PERCEIVED_TYPE_FIRST}
  PERCEIVED_TYPE_FIRST       = -3;
  {$EXTERNALSYM PERCEIVED_TYPE_CUSTOM}
  PERCEIVED_TYPE_CUSTOM      = -3;
  {$EXTERNALSYM PERCEIVED_TYPE_UNSPECIFIED}
  PERCEIVED_TYPE_UNSPECIFIED = -2;
  {$EXTERNALSYM PERCEIVED_TYPE_FOLDER}
  PERCEIVED_TYPE_FOLDER      = -1;
  {$EXTERNALSYM PERCEIVED_TYPE_UNKNOWN}
  PERCEIVED_TYPE_UNKNOWN     = 0;
  {$EXTERNALSYM PERCEIVED_TYPE_TEXT}
  PERCEIVED_TYPE_TEXT        = 1;
  {$EXTERNALSYM PERCEIVED_TYPE_IMAGE}
  PERCEIVED_TYPE_IMAGE       = 2;
  {$EXTERNALSYM PERCEIVED_TYPE_AUDIO}
  PERCEIVED_TYPE_AUDIO       = 3;
  {$EXTERNALSYM PERCEIVED_TYPE_VIDEO}
  PERCEIVED_TYPE_VIDEO       = 4;
  {$EXTERNALSYM PERCEIVED_TYPE_COMPRESSED}
  PERCEIVED_TYPE_COMPRESSED  = 5;
  {$EXTERNALSYM PERCEIVED_TYPE_DOCUMENT}
  PERCEIVED_TYPE_DOCUMENT    = 6;
  {$EXTERNALSYM PERCEIVED_TYPE_SYSTEM}
  PERCEIVED_TYPE_SYSTEM      = 7;
  {$EXTERNALSYM PERCEIVED_TYPE_APPLICATION}
  PERCEIVED_TYPE_APPLICATION = 8;
  {$EXTERNALSYM PERCEIVED_TYPE_GAMEMEDIA}
  PERCEIVED_TYPE_GAMEMEDIA   = 9;
  {$EXTERNALSYM PERCEIVED_TYPE_CONTACTS}
  PERCEIVED_TYPE_CONTACTS    = 10;
  {$EXTERNALSYM PERCEIVED_TYPE_LAST}
  PERCEIVED_TYPE_LAST        = 10;

  {$EXTERNALSYM PERCEIVEDFLAG_UNDEFINED}
  PERCEIVEDFLAG_UNDEFINED     = $0000;
  {$EXTERNALSYM PERCEIVEDFLAG_SOFTCODED}
  PERCEIVEDFLAG_SOFTCODED     = $0001;
  {$EXTERNALSYM PERCEIVEDFLAG_HARDCODED}
  PERCEIVEDFLAG_HARDCODED     = $0002;
  {$EXTERNALSYM PERCEIVEDFLAG_NATIVESUPPORT}
  PERCEIVEDFLAG_NATIVESUPPORT = $0004;
  {$EXTERNALSYM PERCEIVEDFLAG_GDIPLUS}
  PERCEIVEDFLAG_GDIPLUS       = $0010;
  {$EXTERNALSYM PERCEIVEDFLAG_WMSDK}
  PERCEIVEDFLAG_WMSDK         = $0020;
  {$EXTERNALSYM PERCEIVEDFLAG_ZIPFOLDER}
  PERCEIVEDFLAG_ZIPFOLDER     = $0040;

{ The CLSID is passed by value (16 bytes on the stack), as in the C
  prototype. }
{$EXTERNALSYM AssocCreate}
function AssocCreate(clsid: TCLSID; const riid: TIID; out ppv): HRESULT; stdcall;
{ pszAssoc: an extension ('.txt'), a ProgId, an executable (with
  ASSOCF_INIT_BYEXENAME) ...; pszExtra: the verb ('open') or nil.
  pszOut may be nil to query the size; pcchOut counts the null. }
{$EXTERNALSYM AssocQueryStringA}
function AssocQueryStringA(flags: ASSOCF; str: ASSOCSTR; pszAssoc, pszExtra,
  pszOut: PAnsiChar; var pcchOut: DWORD): HRESULT; stdcall;
{$EXTERNALSYM AssocQueryStringW}
function AssocQueryStringW(flags: ASSOCF; str: ASSOCSTR; pszAssoc, pszExtra,
  pszOut: PWideChar; var pcchOut: DWORD): HRESULT; stdcall;
{$EXTERNALSYM AssocQueryString}
function AssocQueryString(flags: ASSOCF; str: ASSOCSTR; pszAssoc, pszExtra,
  pszOut: PChar; var pcchOut: DWORD): HRESULT; stdcall;
{$EXTERNALSYM AssocQueryStringByKeyA}
function AssocQueryStringByKeyA(flags: ASSOCF; str: ASSOCSTR; hkAssoc: HKEY;
  pszExtra, pszOut: PAnsiChar; var pcchOut: DWORD): HRESULT; stdcall;
{$EXTERNALSYM AssocQueryStringByKeyW}
function AssocQueryStringByKeyW(flags: ASSOCF; str: ASSOCSTR; hkAssoc: HKEY;
  pszExtra, pszOut: PWideChar; var pcchOut: DWORD): HRESULT; stdcall;
{$EXTERNALSYM AssocQueryStringByKey}
function AssocQueryStringByKey(flags: ASSOCF; str: ASSOCSTR; hkAssoc: HKEY;
  pszExtra, pszOut: PChar; var pcchOut: DWORD): HRESULT; stdcall;
{ The key must be closed with RegCloseKey. }
{$EXTERNALSYM AssocQueryKeyA}
function AssocQueryKeyA(flags: ASSOCF; key: ASSOCKEY; pszAssoc, pszExtra: PAnsiChar;
  out phkeyOut: HKEY): HRESULT; stdcall;
{$EXTERNALSYM AssocQueryKeyW}
function AssocQueryKeyW(flags: ASSOCF; key: ASSOCKEY; pszAssoc, pszExtra: PWideChar;
  out phkeyOut: HKEY): HRESULT; stdcall;
{$EXTERNALSYM AssocQueryKey}
function AssocQueryKey(flags: ASSOCF; key: ASSOCKEY; pszAssoc, pszExtra: PChar;
  out phkeyOut: HKEY): HRESULT; stdcall;
{ Windows XP SP1; run-time bound. Fallback: True (dangerous) after
  SetLastError(ERROR_CALL_NOT_IMPLEMENTED): a type that cannot be checked
  is not treated as safe. }
{$EXTERNALSYM AssocIsDangerous}
function AssocIsDangerous(pszAssoc: PWideChar): BOOL; stdcall;
{ Windows XP SP2; run-time bound. ppszType may be nil; the string is
  allocated with CoTaskMemAlloc. Fallback: E_NOTIMPL with
  ptype = PERCEIVED_TYPE_UNSPECIFIED, pflag = PERCEIVEDFLAG_UNDEFINED and
  ppszType^ = nil. }
{$EXTERNALSYM AssocGetPerceivedType}
function AssocGetPerceivedType(pszExt: PWideChar; out ptype: PERCEIVED;
  out pflag: PERCEIVEDFLAG; ppszType: PPWideChar): HRESULT; stdcall;

{ ====== Streams =========================================================== }

{ A stream on a registry value (REG_BINARY); data written is saved when the
  last reference is released. grfMode: STGM_READ, STGM_WRITE or
  STGM_READWRITE. Returns nil on failure. }
{$EXTERNALSYM SHOpenRegStream2A}
function SHOpenRegStream2A(hkey: HKEY; pszSubkey, pszValue: PAnsiChar;
  grfMode: DWORD): IStream; stdcall;
{$EXTERNALSYM SHOpenRegStream2W}
function SHOpenRegStream2W(hkey: HKEY; pszSubkey, pszValue: PWideChar;
  grfMode: DWORD): IStream; stdcall;
{$EXTERNALSYM SHOpenRegStream2}
function SHOpenRegStream2(hkey: HKEY; pszSubkey, pszValue: PChar;
  grfMode: DWORD): IStream; stdcall;
{ shlwapi.h maps SHOpenRegStream to SHOpenRegStream2 (A in ANSI). }
{$EXTERNALSYM SHOpenRegStream}
function SHOpenRegStream(hkey: HKEY; pszSubkey, pszValue: PChar;
  grfMode: DWORD): IStream; stdcall;
{ grfMode: STGM_* (STGM_CREATE or STGM_WRITE to create a file). }
{$EXTERNALSYM SHCreateStreamOnFileA}
function SHCreateStreamOnFileA(pszFile: PAnsiChar; grfMode: DWORD;
  out ppstm: IStream): HRESULT; stdcall;
{$EXTERNALSYM SHCreateStreamOnFileW}
function SHCreateStreamOnFileW(pszFile: PWideChar; grfMode: DWORD;
  out ppstm: IStream): HRESULT; stdcall;
{$EXTERNALSYM SHCreateStreamOnFile}
function SHCreateStreamOnFile(pszFile: PChar; grfMode: DWORD;
  out ppstm: IStream): HRESULT; stdcall;
{ dwAttributes: FILE_ATTRIBUTE_* of a new file; pstmTemplate: nil.
  Run-time bound. Fallback: E_NOTIMPL and ppstm = nil. }
{$EXTERNALSYM SHCreateStreamOnFileEx}
function SHCreateStreamOnFileEx(pszFile: PWideChar; grfMode, dwAttributes: DWORD;
  fCreate: BOOL; pstmTemplate: IStream; out ppstm: IStream): HRESULT; stdcall;
{ A memory stream holding a copy of cbInit bytes at pInit (pInit may be
  nil). Windows XP exports it by ordinal only; run-time bound by name
  (Windows Vista and later). Fallback: nil. }
{$EXTERNALSYM SHCreateMemStream}
function SHCreateMemStream(pInit: Pointer; cbInit: UINT): IStream; stdcall;
{ Stream helpers: Windows XP exports them by ordinal only; run-time bound
  by name (Windows Vista and later). Fallback: E_NOTIMPL.
  IStream_Read fails unless exactly cb bytes are read. }
{$EXTERNALSYM IStream_Read}
function IStream_Read(pstm: IStream; pv: Pointer; cb: ULONG): HRESULT; stdcall;
{$EXTERNALSYM IStream_Write}
function IStream_Write(pstm: IStream; pv: Pointer; cb: ULONG): HRESULT; stdcall;
{ Seeks to the start of the stream. }
{$EXTERNALSYM IStream_Reset}
function IStream_Reset(pstm: IStream): HRESULT; stdcall;
{$EXTERNALSYM IStream_Size}
function IStream_Size(pstm: IStream; out pui: ULARGE_INTEGER): HRESULT; stdcall;
{ Windows Vista. A length-prefixed Unicode string; IStream_ReadStr
  allocates it with CoTaskMemAlloc (fallback: ppsz = nil). }
{$EXTERNALSYM IStream_ReadStr}
function IStream_ReadStr(pstm: IStream; out ppsz: PWideChar): HRESULT; stdcall;
{$EXTERNALSYM IStream_WriteStr}
function IStream_WriteStr(pstm: IStream; psz: PWideChar): HRESULT; stdcall;
{ Windows Vista. Copies cb bytes from the current positions. }
{$EXTERNALSYM IStream_Copy}
function IStream_Copy(pstmFrom, pstmTo: IStream; cb: DWORD): HRESULT; stdcall;

{ ====== User interface helpers ============================================ }

const
  { SHAutoComplete dwFlags }
  {$EXTERNALSYM SHACF_DEFAULT}
  SHACF_DEFAULT              = $00000000;  // currently (SHACF_FILESYSTEM | SHACF_URLALL)
  {$EXTERNALSYM SHACF_FILESYSTEM}
  SHACF_FILESYSTEM           = $00000001;  // the file system and the rest of the shell namespace
  {$EXTERNALSYM SHACF_URLHISTORY}
  SHACF_URLHISTORY           = $00000002;  // URLs in the User's History
  {$EXTERNALSYM SHACF_URLMRU}
  SHACF_URLMRU               = $00000004;  // URLs in the User's Recently Used list.
  {$EXTERNALSYM SHACF_URLALL}
  SHACF_URLALL               = SHACF_URLHISTORY or SHACF_URLMRU;
  {$EXTERNALSYM SHACF_USETAB}
  SHACF_USETAB               = $00000008;  // Tab moves through the suggestions instead of to the next control
  {$EXTERNALSYM SHACF_FILESYS_ONLY}
  SHACF_FILESYS_ONLY         = $00000010;  // the file system only
  {$EXTERNALSYM SHACF_FILESYS_DIRS}
  SHACF_FILESYS_DIRS         = $00000020;  // directories, UNC servers and UNC server shares only
  {$EXTERNALSYM SHACF_VIRTUAL_NAMESPACE}
  SHACF_VIRTUAL_NAMESPACE    = $00000040;  // Windows Vista: also the virtual namespace
  {$EXTERNALSYM SHACF_AUTOSUGGEST_FORCE_ON}
  SHACF_AUTOSUGGEST_FORCE_ON  = $10000000;  // Ignore the registry default and force the feature on.
  {$EXTERNALSYM SHACF_AUTOSUGGEST_FORCE_OFF}
  SHACF_AUTOSUGGEST_FORCE_OFF = $20000000;  // Ignore the registry default and force the feature off.
  {$EXTERNALSYM SHACF_AUTOAPPEND_FORCE_ON}
  SHACF_AUTOAPPEND_FORCE_ON   = $40000000;  // Ignore the registry default and force the feature on.
  {$EXTERNALSYM SHACF_AUTOAPPEND_FORCE_OFF}
  SHACF_AUTOAPPEND_FORCE_OFF  = $80000000;  // Ignore the registry default and force the feature off.

{ Adds auto-completion to an edit control (or the edit of a combo box).
  COM must be initialized on the thread (CoInitialize/OleInitialize) until
  the control is destroyed. }
{$EXTERNALSYM SHAutoComplete}
function SHAutoComplete(hwndEdit: HWND; dwFlags: DWORD): HRESULT; stdcall;
{ A message box with a "Don't show this message again" check box; the
  answer is stored under HKCU\Software\Microsoft\Windows\CurrentVersion\
  Explorer\DontShowMeThisDialogAgain\<pszRegVal>, and iDefault is returned
  without a dialog once the user checked it. Windows XP exports it by
  ordinal only; run-time bound by name (Windows Vista and later).
  Fallback: -1 (the function's error value) after
  SetLastError(ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM SHMessageBoxCheckA}
function SHMessageBoxCheckA(hwnd: HWND; pszText, pszCaption: PAnsiChar; uType: UINT;
  iDefault: Integer; pszRegVal: PAnsiChar): Integer; stdcall;
{$EXTERNALSYM SHMessageBoxCheckW}
function SHMessageBoxCheckW(hwnd: HWND; pszText, pszCaption: PWideChar; uType: UINT;
  iDefault: Integer; pszRegVal: PWideChar): Integer; stdcall;
{$EXTERNALSYM SHMessageBoxCheck}
function SHMessageBoxCheck(hwnd: HWND; pszText, pszCaption: PChar; uType: UINT;
  iDefault: Integer; pszRegVal: PChar): Integer; stdcall;

{ ====== GDI helpers ======================================================= }

{$EXTERNALSYM SHCreateShellPalette}
function SHCreateShellPalette(hdc: HDC): HPALETTE; stdcall;
{ Hue, luminance and saturation in the range 0 .. 240 }
{$EXTERNALSYM ColorRGBToHLS}
procedure ColorRGBToHLS(clrRGB: COLORREF; out pwHue, pwLuminance, pwSaturation: Word); stdcall;
{$EXTERNALSYM ColorHLSToRGB}
function ColorHLSToRGB(wHue, wLuminance, wSaturation: Word): COLORREF; stdcall;
{ n: luminance change in 1/10 of a percent (fScale) or in units of 0..240 }
{$EXTERNALSYM ColorAdjustLuma}
function ColorAdjustLuma(clrRGB: COLORREF; n: Integer; fScale: BOOL): COLORREF; stdcall;

{ ====== DllGetVersion ===================================================== }

type
  PDllVersionInfo = ^TDllVersionInfo;
  {$EXTERNALSYM _DLLVERSIONINFO}
  _DLLVERSIONINFO = record
    cbSize: DWORD;
    dwMajorVersion: DWORD;          // Major version
    dwMinorVersion: DWORD;          // Minor version
    dwBuildNumber: DWORD;           // Build number
    dwPlatformID: DWORD;            // DLLVER_PLATFORM_*
  end;
  {$EXTERNALSYM DLLVERSIONINFO}
  DLLVERSIONINFO = _DLLVERSIONINFO;
  TDllVersionInfo = _DLLVERSIONINFO;

  PDllVersionInfo2 = ^TDllVersionInfo2;
  {$EXTERNALSYM _DLLVERSIONINFO2}
  _DLLVERSIONINFO2 = record
    info1: DLLVERSIONINFO;
    dwFlags: DWORD;                 // No flags currently defined
    ullVersion: Int64;              // Major, minor, build, QFE: 16 bits each (MAKEDLLVERULL)
  end;
  {$EXTERNALSYM DLLVERSIONINFO2}
  DLLVERSIONINFO2 = _DLLVERSIONINFO2;
  TDllVersionInfo2 = _DLLVERSIONINFO2;

  { The DllGetVersion export of a DLL (GetProcAddress(Module, 'DllGetVersion')).
    pdvi points to a TDllVersionInfo or TDllVersionInfo2 whose cbSize is set. }
  {$EXTERNALSYM DLLGETVERSIONPROC}
  DLLGETVERSIONPROC = function(pdvi: PDllVersionInfo): HRESULT; stdcall;
  TDllGetVersionProc = DLLGETVERSIONPROC;

const
  { DLLVERSIONINFO.dwPlatformID }
  {$EXTERNALSYM DLLVER_PLATFORM_WINDOWS}
  DLLVER_PLATFORM_WINDOWS = $00000001;  // Windows 95
  {$EXTERNALSYM DLLVER_PLATFORM_NT}
  DLLVER_PLATFORM_NT      = $00000002;  // Windows NT

  { DLLVERSIONINFO2.ullVersion }
  {$EXTERNALSYM DLLVER_MAJOR_MASK}
  DLLVER_MAJOR_MASK = $FFFF000000000000;
  {$EXTERNALSYM DLLVER_MINOR_MASK}
  DLLVER_MINOR_MASK = $0000FFFF00000000;
  {$EXTERNALSYM DLLVER_BUILD_MASK}
  DLLVER_BUILD_MASK = $00000000FFFF0000;
  {$EXTERNALSYM DLLVER_QFE_MASK}
  DLLVER_QFE_MASK   = $000000000000FFFF;

{$EXTERNALSYM MAKEDLLVERULL}
function MAKEDLLVERULL(Major, Minor, Build, Qfe: Word): Int64;

implementation

{ ---- run-time binding ---- }

const
  shlwapilib = 'shlwapi.dll';

var
  ShlwapiModule: HMODULE;
  ShlwapiLoaded: Boolean;
  StrFormatByteSizeExProc: Pointer;
  SHLoadIndirectStringProc: Pointer;
  PathMatchSpecExAProc: Pointer;
  PathMatchSpecExWProc: Pointer;
  PathCreateFromUrlAllocProc: Pointer;
  UrlFixupWProc: Pointer;
  ParseURLAProc: Pointer;
  ParseURLWProc: Pointer;
  SHRegDuplicateHKeyProc: Pointer;
  SHRegGetValueAProc: Pointer;
  SHRegGetValueWProc: Pointer;
  SHRegGetValueFromHKCUHKLMProc: Pointer;
  SHRegGetBoolValueFromHKCUHKLMProc: Pointer;
  AssocIsDangerousProc: Pointer;
  AssocGetPerceivedTypeProc: Pointer;
  SHCreateStreamOnFileExProc: Pointer;
  SHCreateMemStreamProc: Pointer;
  IStream_ReadProc: Pointer;
  IStream_WriteProc: Pointer;
  IStream_ResetProc: Pointer;
  IStream_SizeProc: Pointer;
  IStream_ReadStrProc: Pointer;
  IStream_WriteStrProc: Pointer;
  IStream_CopyProc: Pointer;
  SHMessageBoxCheckAProc: Pointer;
  SHMessageBoxCheckWProc: Pointer;

{ shlwapi.dll is loaded once, by full path from the system directory (no
  search-order planting), and never released. A missing DLL is remembered;
  a function pointer is cached once found. }
function GetShlwapiProc(var Proc: Pointer; Name: PChar): Boolean;
var
  Path: array[0..MAX_PATH + 16] of Char;
  Len: UINT;
begin
  if Proc = nil then
  begin
    if not ShlwapiLoaded then
    begin
      Len := GetSystemDirectory(Path, MAX_PATH);
      if (Len > 0) and (Len < MAX_PATH) then
      begin
        lstrcat(Path, '\' + shlwapilib);
        ShlwapiModule := LoadLibrary(Path);
      end;
      ShlwapiLoaded := True;
    end;
    if ShlwapiModule <> 0 then
      Proc := GetProcAddress(ShlwapiModule, Name);
  end;
  Result := Proc <> nil;
end;

function NotImplemented: BOOL;
begin
  SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
  Result := False;
end;

{ Delphi passes True as -1 in a BOOL; some Windows code only accepts TRUE
  (1), so BOOL arguments of run-time bound functions are passed as 0 or 1. }
function BoolArg(Value: BOOL): Integer;
begin
  if Value then
    Result := 1
  else
    Result := 0;
end;

type
  TFnStrFormatByteSizeEx = function(ull: Int64; flags: SFBS_FLAGS; pszBuf: PWideChar;
    cchBuf: UINT): HRESULT; stdcall;
  TFnSHLoadIndirectString = function(pszSource, pszOutBuf: PWideChar; cchOutBuf: UINT;
    ppvReserved: Pointer): HRESULT; stdcall;
  TFnPtrPtrDwordHr = function(p1, p2: Pointer; dw: DWORD): HRESULT; stdcall;
  TFnPathCreateFromUrlAlloc = function(pszIn: PWideChar; out ppszOut: PWideChar;
    dwFlags: DWORD): HRESULT; stdcall;
  TFnPtrPtrHr = function(p1, p2: Pointer): HRESULT; stdcall;
  TFnSHRegDuplicateHKey = function(hkey: HKEY): HKEY; stdcall;
  TFnSHRegGetValue = function(hkey: HKEY; pszSubKey, pszValue: Pointer; srrfFlags: SRRF;
    pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
  TFnSHRegGetValueFromHKCUHKLM = function(pwszKey, pwszValue: PWideChar; srrfFlags: SRRF;
    pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
  TFnSHRegGetBoolValueFromHKCUHKLM = function(pszKey, pszValue: PWideChar;
    fDefault: Integer): BOOL; stdcall;
  TFnAssocIsDangerous = function(pszAssoc: PWideChar): BOOL; stdcall;
  TFnAssocGetPerceivedType = function(pszExt: PWideChar; out ptype: PERCEIVED;
    out pflag: PERCEIVEDFLAG; ppszType: PPWideChar): HRESULT; stdcall;
  TFnSHCreateStreamOnFileEx = function(pszFile: PWideChar; grfMode, dwAttributes: DWORD;
    fCreate: Integer; pstmTemplate: IStream; out ppstm: IStream): HRESULT; stdcall;
  TFnSHCreateMemStream = function(pInit: Pointer; cbInit: UINT): Pointer; stdcall;
  TFnIStreamPtrUlong = function(pstm: IStream; pv: Pointer; cb: ULONG): HRESULT; stdcall;
  TFnIStream = function(pstm: IStream): HRESULT; stdcall;
  TFnIStreamSize = function(pstm: IStream; out pui: ULARGE_INTEGER): HRESULT; stdcall;
  TFnIStreamReadStr = function(pstm: IStream; out ppsz: PWideChar): HRESULT; stdcall;
  TFnIStreamWriteStr = function(pstm: IStream; psz: PWideChar): HRESULT; stdcall;
  TFnIStreamCopy = function(pstmFrom, pstmTo: IStream; cb: DWORD): HRESULT; stdcall;
  TFnSHMessageBoxCheck = function(hwnd: HWND; pszText, pszCaption: Pointer; uType: UINT;
    iDefault: Integer; pszRegVal: Pointer): Integer; stdcall;

{ ====== String functions ================================================== }

function StrChrA; external shlwapilib name 'StrChrA';
function StrChrW; external shlwapilib name 'StrChrW';
function StrChr; external shlwapilib name 'StrChrA';
function StrChrIA; external shlwapilib name 'StrChrIA';
function StrChrIW; external shlwapilib name 'StrChrIW';
function StrChrI; external shlwapilib name 'StrChrIA';
function StrCmpNA; external shlwapilib name 'StrCmpNA';
function StrCmpNW; external shlwapilib name 'StrCmpNW';
function StrCmpN; external shlwapilib name 'StrCmpNA';
function StrCmpNIA; external shlwapilib name 'StrCmpNIA';
function StrCmpNIW; external shlwapilib name 'StrCmpNIW';
function StrCmpNI; external shlwapilib name 'StrCmpNIA';
function StrCSpnA; external shlwapilib name 'StrCSpnA';
function StrCSpnW; external shlwapilib name 'StrCSpnW';
function StrCSpn; external shlwapilib name 'StrCSpnA';
function StrCSpnIA; external shlwapilib name 'StrCSpnIA';
function StrCSpnIW; external shlwapilib name 'StrCSpnIW';
function StrCSpnI; external shlwapilib name 'StrCSpnIA';
function StrDupA; external shlwapilib name 'StrDupA';
function StrDupW; external shlwapilib name 'StrDupW';
function StrDup; external shlwapilib name 'StrDupA';
function StrFormatByteSizeA; external shlwapilib name 'StrFormatByteSizeA';
function StrFormatByteSize64A; external shlwapilib name 'StrFormatByteSize64A';
function StrFormatByteSizeW; external shlwapilib name 'StrFormatByteSizeW';
function StrFormatByteSize; external shlwapilib name 'StrFormatByteSizeA';
function StrFormatByteSize64; external shlwapilib name 'StrFormatByteSize64A';
function StrFormatKBSizeA; external shlwapilib name 'StrFormatKBSizeA';
function StrFormatKBSizeW; external shlwapilib name 'StrFormatKBSizeW';
function StrFormatKBSize; external shlwapilib name 'StrFormatKBSizeA';
function StrFromTimeIntervalA; external shlwapilib name 'StrFromTimeIntervalA';
function StrFromTimeIntervalW; external shlwapilib name 'StrFromTimeIntervalW';
function StrFromTimeInterval; external shlwapilib name 'StrFromTimeIntervalA';
function StrIsIntlEqualA; external shlwapilib name 'StrIsIntlEqualA';
function StrIsIntlEqualW; external shlwapilib name 'StrIsIntlEqualW';
function StrIsIntlEqual; external shlwapilib name 'StrIsIntlEqualA';
function StrNCatA; external shlwapilib name 'StrNCatA';
function StrNCatW; external shlwapilib name 'StrNCatW';
function StrNCat; external shlwapilib name 'StrNCatA';
function StrPBrkA; external shlwapilib name 'StrPBrkA';
function StrPBrkW; external shlwapilib name 'StrPBrkW';
function StrPBrk; external shlwapilib name 'StrPBrkA';
function StrRChrA; external shlwapilib name 'StrRChrA';
function StrRChrW; external shlwapilib name 'StrRChrW';
function StrRChr; external shlwapilib name 'StrRChrA';
function StrRChrIA; external shlwapilib name 'StrRChrIA';
function StrRChrIW; external shlwapilib name 'StrRChrIW';
function StrRChrI; external shlwapilib name 'StrRChrIA';
function StrRStrIA; external shlwapilib name 'StrRStrIA';
function StrRStrIW; external shlwapilib name 'StrRStrIW';
function StrRStrI; external shlwapilib name 'StrRStrIA';
function StrSpnA; external shlwapilib name 'StrSpnA';
function StrSpnW; external shlwapilib name 'StrSpnW';
function StrSpn; external shlwapilib name 'StrSpnA';
function StrStrA; external shlwapilib name 'StrStrA';
function StrStrW; external shlwapilib name 'StrStrW';
function StrStr; external shlwapilib name 'StrStrA';
function StrStrIA; external shlwapilib name 'StrStrIA';
function StrStrIW; external shlwapilib name 'StrStrIW';
function StrStrI; external shlwapilib name 'StrStrIA';
function StrToIntA; external shlwapilib name 'StrToIntA';
function StrToIntW; external shlwapilib name 'StrToIntW';
function StrToIntExA; external shlwapilib name 'StrToIntExA';
function StrToIntExW; external shlwapilib name 'StrToIntExW';
function StrToIntEx; external shlwapilib name 'StrToIntExA';
function StrToInt64ExA; external shlwapilib name 'StrToInt64ExA';
function StrToInt64ExW; external shlwapilib name 'StrToInt64ExW';
function StrToInt64Ex; external shlwapilib name 'StrToInt64ExA';
function StrTrimA; external shlwapilib name 'StrTrimA';
function StrTrimW; external shlwapilib name 'StrTrimW';
function StrTrim; external shlwapilib name 'StrTrimA';
function StrCatW; external shlwapilib name 'StrCatW';
function StrCmpW; external shlwapilib name 'StrCmpW';
function StrCmpIW; external shlwapilib name 'StrCmpIW';
function StrCpyW; external shlwapilib name 'StrCpyW';
function StrCpyNW; external shlwapilib name 'StrCpyNW';
function StrCatBuffA; external shlwapilib name 'StrCatBuffA';
function StrCatBuffW; external shlwapilib name 'StrCatBuffW';
function StrCatBuff; external shlwapilib name 'StrCatBuffA';
function ChrCmpIA; external shlwapilib name 'ChrCmpIA';
function ChrCmpIW; external shlwapilib name 'ChrCmpIW';
function ChrCmpI; external shlwapilib name 'ChrCmpIA';
function wvnsprintfA; external shlwapilib name 'wvnsprintfA';
function wvnsprintfW; external shlwapilib name 'wvnsprintfW';
function wvnsprintf; external shlwapilib name 'wvnsprintfA';
function wnsprintfA; external shlwapilib name 'wnsprintfA';
function wnsprintfW; external shlwapilib name 'wnsprintfW';
function wnsprintf; external shlwapilib name 'wnsprintfA';
function StrRetToStrA; external shlwapilib name 'StrRetToStrA';
function StrRetToStrW; external shlwapilib name 'StrRetToStrW';
function StrRetToStr; external shlwapilib name 'StrRetToStrA';
function StrRetToBufA; external shlwapilib name 'StrRetToBufA';
function StrRetToBufW; external shlwapilib name 'StrRetToBufW';
function StrRetToBuf; external shlwapilib name 'StrRetToBufA';
function SHStrDupA; external shlwapilib name 'SHStrDupA';
function SHStrDupW; external shlwapilib name 'SHStrDupW';
function SHStrDup; external shlwapilib name 'SHStrDupA';
function StrCmpLogicalW; external shlwapilib name 'StrCmpLogicalW';
function StrRetToBSTR; external shlwapilib name 'StrRetToBSTR';

function StrFormatByteSizeEx(ull: Int64; flags: SFBS_FLAGS; pszBuf: PWideChar;
  cchBuf: UINT): HRESULT; stdcall;
begin
  if GetShlwapiProc(StrFormatByteSizeExProc, 'StrFormatByteSizeEx') then
    Result := TFnStrFormatByteSizeEx(StrFormatByteSizeExProc)(ull, flags, pszBuf, cchBuf)
  else
    Result := E_NOTIMPL;
end;

function SHLoadIndirectString(pszSource, pszOutBuf: PWideChar; cchOutBuf: UINT;
  ppvReserved: Pointer): HRESULT; stdcall;
begin
  if GetShlwapiProc(SHLoadIndirectStringProc, 'SHLoadIndirectString') then
    Result := TFnSHLoadIndirectString(SHLoadIndirectStringProc)(pszSource, pszOutBuf,
      cchOutBuf, ppvReserved)
  else
    Result := E_NOTIMPL;
end;

{ ====== Path functions ==================================================== }

function PathAddBackslashA; external shlwapilib name 'PathAddBackslashA';
function PathAddBackslashW; external shlwapilib name 'PathAddBackslashW';
function PathAddBackslash; external shlwapilib name 'PathAddBackslashA';
function PathAddExtensionA; external shlwapilib name 'PathAddExtensionA';
function PathAddExtensionW; external shlwapilib name 'PathAddExtensionW';
function PathAddExtension; external shlwapilib name 'PathAddExtensionA';
function PathAppendA; external shlwapilib name 'PathAppendA';
function PathAppendW; external shlwapilib name 'PathAppendW';
function PathAppend; external shlwapilib name 'PathAppendA';
function PathBuildRootA; external shlwapilib name 'PathBuildRootA';
function PathBuildRootW; external shlwapilib name 'PathBuildRootW';
function PathBuildRoot; external shlwapilib name 'PathBuildRootA';
function PathCanonicalizeA; external shlwapilib name 'PathCanonicalizeA';
function PathCanonicalizeW; external shlwapilib name 'PathCanonicalizeW';
function PathCanonicalize; external shlwapilib name 'PathCanonicalizeA';
function PathCombineA; external shlwapilib name 'PathCombineA';
function PathCombineW; external shlwapilib name 'PathCombineW';
function PathCombine; external shlwapilib name 'PathCombineA';
function PathCompactPathA; external shlwapilib name 'PathCompactPathA';
function PathCompactPathW; external shlwapilib name 'PathCompactPathW';
function PathCompactPath; external shlwapilib name 'PathCompactPathA';
function PathCompactPathExA; external shlwapilib name 'PathCompactPathExA';
function PathCompactPathExW; external shlwapilib name 'PathCompactPathExW';
function PathCompactPathEx; external shlwapilib name 'PathCompactPathExA';
function PathCommonPrefixA; external shlwapilib name 'PathCommonPrefixA';
function PathCommonPrefixW; external shlwapilib name 'PathCommonPrefixW';
function PathCommonPrefix; external shlwapilib name 'PathCommonPrefixA';
function PathFileExistsA; external shlwapilib name 'PathFileExistsA';
function PathFileExistsW; external shlwapilib name 'PathFileExistsW';
function PathFileExists; external shlwapilib name 'PathFileExistsA';
function PathFindExtensionA; external shlwapilib name 'PathFindExtensionA';
function PathFindExtensionW; external shlwapilib name 'PathFindExtensionW';
function PathFindExtension; external shlwapilib name 'PathFindExtensionA';
function PathFindFileNameA; external shlwapilib name 'PathFindFileNameA';
function PathFindFileNameW; external shlwapilib name 'PathFindFileNameW';
function PathFindFileName; external shlwapilib name 'PathFindFileNameA';
function PathFindNextComponentA; external shlwapilib name 'PathFindNextComponentA';
function PathFindNextComponentW; external shlwapilib name 'PathFindNextComponentW';
function PathFindNextComponent; external shlwapilib name 'PathFindNextComponentA';
function PathFindOnPathA; external shlwapilib name 'PathFindOnPathA';
function PathFindOnPathW; external shlwapilib name 'PathFindOnPathW';
function PathFindOnPath; external shlwapilib name 'PathFindOnPathA';
function PathFindSuffixArrayA; external shlwapilib name 'PathFindSuffixArrayA';
function PathFindSuffixArrayW; external shlwapilib name 'PathFindSuffixArrayW';
function PathFindSuffixArray; external shlwapilib name 'PathFindSuffixArrayA';
function PathGetArgsA; external shlwapilib name 'PathGetArgsA';
function PathGetArgsW; external shlwapilib name 'PathGetArgsW';
function PathGetArgs; external shlwapilib name 'PathGetArgsA';
function PathIsLFNFileSpecA; external shlwapilib name 'PathIsLFNFileSpecA';
function PathIsLFNFileSpecW; external shlwapilib name 'PathIsLFNFileSpecW';
function PathIsLFNFileSpec; external shlwapilib name 'PathIsLFNFileSpecA';
function PathGetCharTypeA; external shlwapilib name 'PathGetCharTypeA';
function PathGetCharTypeW; external shlwapilib name 'PathGetCharTypeW';
function PathGetCharType; external shlwapilib name 'PathGetCharTypeA';
function PathGetDriveNumberA; external shlwapilib name 'PathGetDriveNumberA';
function PathGetDriveNumberW; external shlwapilib name 'PathGetDriveNumberW';
function PathGetDriveNumber; external shlwapilib name 'PathGetDriveNumberA';
function PathIsDirectoryA; external shlwapilib name 'PathIsDirectoryA';
function PathIsDirectoryW; external shlwapilib name 'PathIsDirectoryW';
function PathIsDirectory; external shlwapilib name 'PathIsDirectoryA';
function PathIsDirectoryEmptyA; external shlwapilib name 'PathIsDirectoryEmptyA';
function PathIsDirectoryEmptyW; external shlwapilib name 'PathIsDirectoryEmptyW';
function PathIsDirectoryEmpty; external shlwapilib name 'PathIsDirectoryEmptyA';
function PathIsFileSpecA; external shlwapilib name 'PathIsFileSpecA';
function PathIsFileSpecW; external shlwapilib name 'PathIsFileSpecW';
function PathIsFileSpec; external shlwapilib name 'PathIsFileSpecA';
function PathIsPrefixA; external shlwapilib name 'PathIsPrefixA';
function PathIsPrefixW; external shlwapilib name 'PathIsPrefixW';
function PathIsPrefix; external shlwapilib name 'PathIsPrefixA';
function PathIsRelativeA; external shlwapilib name 'PathIsRelativeA';
function PathIsRelativeW; external shlwapilib name 'PathIsRelativeW';
function PathIsRelative; external shlwapilib name 'PathIsRelativeA';
function PathIsRootA; external shlwapilib name 'PathIsRootA';
function PathIsRootW; external shlwapilib name 'PathIsRootW';
function PathIsRoot; external shlwapilib name 'PathIsRootA';
function PathIsSameRootA; external shlwapilib name 'PathIsSameRootA';
function PathIsSameRootW; external shlwapilib name 'PathIsSameRootW';
function PathIsSameRoot; external shlwapilib name 'PathIsSameRootA';
function PathIsUNCA; external shlwapilib name 'PathIsUNCA';
function PathIsUNCW; external shlwapilib name 'PathIsUNCW';
function PathIsUNC; external shlwapilib name 'PathIsUNCA';
function PathIsNetworkPathA; external shlwapilib name 'PathIsNetworkPathA';
function PathIsNetworkPathW; external shlwapilib name 'PathIsNetworkPathW';
function PathIsNetworkPath; external shlwapilib name 'PathIsNetworkPathA';
function PathIsUNCServerA; external shlwapilib name 'PathIsUNCServerA';
function PathIsUNCServerW; external shlwapilib name 'PathIsUNCServerW';
function PathIsUNCServer; external shlwapilib name 'PathIsUNCServerA';
function PathIsUNCServerShareA; external shlwapilib name 'PathIsUNCServerShareA';
function PathIsUNCServerShareW; external shlwapilib name 'PathIsUNCServerShareW';
function PathIsUNCServerShare; external shlwapilib name 'PathIsUNCServerShareA';
function PathIsContentTypeA; external shlwapilib name 'PathIsContentTypeA';
function PathIsContentTypeW; external shlwapilib name 'PathIsContentTypeW';
function PathIsContentType; external shlwapilib name 'PathIsContentTypeA';
function PathIsURLA; external shlwapilib name 'PathIsURLA';
function PathIsURLW; external shlwapilib name 'PathIsURLW';
function PathIsURL; external shlwapilib name 'PathIsURLA';
function PathMakePrettyA; external shlwapilib name 'PathMakePrettyA';
function PathMakePrettyW; external shlwapilib name 'PathMakePrettyW';
function PathMakePretty; external shlwapilib name 'PathMakePrettyA';
function PathMatchSpecA; external shlwapilib name 'PathMatchSpecA';
function PathMatchSpecW; external shlwapilib name 'PathMatchSpecW';
function PathMatchSpec; external shlwapilib name 'PathMatchSpecA';
function PathParseIconLocationA; external shlwapilib name 'PathParseIconLocationA';
function PathParseIconLocationW; external shlwapilib name 'PathParseIconLocationW';
function PathParseIconLocation; external shlwapilib name 'PathParseIconLocationA';
function PathQuoteSpacesA; external shlwapilib name 'PathQuoteSpacesA';
function PathQuoteSpacesW; external shlwapilib name 'PathQuoteSpacesW';
function PathQuoteSpaces; external shlwapilib name 'PathQuoteSpacesA';
function PathRelativePathToA; external shlwapilib name 'PathRelativePathToA';
function PathRelativePathToW; external shlwapilib name 'PathRelativePathToW';
function PathRelativePathTo; external shlwapilib name 'PathRelativePathToA';
procedure PathRemoveArgsA; external shlwapilib name 'PathRemoveArgsA';
procedure PathRemoveArgsW; external shlwapilib name 'PathRemoveArgsW';
procedure PathRemoveArgs; external shlwapilib name 'PathRemoveArgsA';
function PathRemoveBackslashA; external shlwapilib name 'PathRemoveBackslashA';
function PathRemoveBackslashW; external shlwapilib name 'PathRemoveBackslashW';
function PathRemoveBackslash; external shlwapilib name 'PathRemoveBackslashA';
procedure PathRemoveBlanksA; external shlwapilib name 'PathRemoveBlanksA';
procedure PathRemoveBlanksW; external shlwapilib name 'PathRemoveBlanksW';
procedure PathRemoveBlanks; external shlwapilib name 'PathRemoveBlanksA';
procedure PathRemoveExtensionA; external shlwapilib name 'PathRemoveExtensionA';
procedure PathRemoveExtensionW; external shlwapilib name 'PathRemoveExtensionW';
procedure PathRemoveExtension; external shlwapilib name 'PathRemoveExtensionA';
function PathRemoveFileSpecA; external shlwapilib name 'PathRemoveFileSpecA';
function PathRemoveFileSpecW; external shlwapilib name 'PathRemoveFileSpecW';
function PathRemoveFileSpec; external shlwapilib name 'PathRemoveFileSpecA';
function PathRenameExtensionA; external shlwapilib name 'PathRenameExtensionA';
function PathRenameExtensionW; external shlwapilib name 'PathRenameExtensionW';
function PathRenameExtension; external shlwapilib name 'PathRenameExtensionA';
function PathSearchAndQualifyA; external shlwapilib name 'PathSearchAndQualifyA';
function PathSearchAndQualifyW; external shlwapilib name 'PathSearchAndQualifyW';
function PathSearchAndQualify; external shlwapilib name 'PathSearchAndQualifyA';
procedure PathSetDlgItemPathA; external shlwapilib name 'PathSetDlgItemPathA';
procedure PathSetDlgItemPathW; external shlwapilib name 'PathSetDlgItemPathW';
procedure PathSetDlgItemPath; external shlwapilib name 'PathSetDlgItemPathA';
function PathSkipRootA; external shlwapilib name 'PathSkipRootA';
function PathSkipRootW; external shlwapilib name 'PathSkipRootW';
function PathSkipRoot; external shlwapilib name 'PathSkipRootA';
procedure PathStripPathA; external shlwapilib name 'PathStripPathA';
procedure PathStripPathW; external shlwapilib name 'PathStripPathW';
procedure PathStripPath; external shlwapilib name 'PathStripPathA';
function PathStripToRootA; external shlwapilib name 'PathStripToRootA';
function PathStripToRootW; external shlwapilib name 'PathStripToRootW';
function PathStripToRoot; external shlwapilib name 'PathStripToRootA';
function PathUnquoteSpacesA; external shlwapilib name 'PathUnquoteSpacesA';
function PathUnquoteSpacesW; external shlwapilib name 'PathUnquoteSpacesW';
function PathUnquoteSpaces; external shlwapilib name 'PathUnquoteSpacesA';
function PathMakeSystemFolderA; external shlwapilib name 'PathMakeSystemFolderA';
function PathMakeSystemFolderW; external shlwapilib name 'PathMakeSystemFolderW';
function PathMakeSystemFolder; external shlwapilib name 'PathMakeSystemFolderA';
function PathUnmakeSystemFolderA; external shlwapilib name 'PathUnmakeSystemFolderA';
function PathUnmakeSystemFolderW; external shlwapilib name 'PathUnmakeSystemFolderW';
function PathUnmakeSystemFolder; external shlwapilib name 'PathUnmakeSystemFolderA';
function PathIsSystemFolderA; external shlwapilib name 'PathIsSystemFolderA';
function PathIsSystemFolderW; external shlwapilib name 'PathIsSystemFolderW';
function PathIsSystemFolder; external shlwapilib name 'PathIsSystemFolderA';
procedure PathUndecorateA; external shlwapilib name 'PathUndecorateA';
procedure PathUndecorateW; external shlwapilib name 'PathUndecorateW';
procedure PathUndecorate; external shlwapilib name 'PathUndecorateA';
function PathUnExpandEnvStringsA; external shlwapilib name 'PathUnExpandEnvStringsA';
function PathUnExpandEnvStringsW; external shlwapilib name 'PathUnExpandEnvStringsW';
function PathUnExpandEnvStrings; external shlwapilib name 'PathUnExpandEnvStringsA';

function PathMatchSpecExA(pszFile, pszSpec: PAnsiChar; dwFlags: DWORD): HRESULT; stdcall;
begin
  if GetShlwapiProc(PathMatchSpecExAProc, 'PathMatchSpecExA') then
    Result := TFnPtrPtrDwordHr(PathMatchSpecExAProc)(pszFile, pszSpec, dwFlags)
  else
    Result := E_NOTIMPL;
end;

function PathMatchSpecExW(pszFile, pszSpec: PWideChar; dwFlags: DWORD): HRESULT; stdcall;
begin
  if GetShlwapiProc(PathMatchSpecExWProc, 'PathMatchSpecExW') then
    Result := TFnPtrPtrDwordHr(PathMatchSpecExWProc)(pszFile, pszSpec, dwFlags)
  else
    Result := E_NOTIMPL;
end;

function PathMatchSpecEx(pszFile, pszSpec: PChar; dwFlags: DWORD): HRESULT; stdcall;
begin
  Result := PathMatchSpecExA(pszFile, pszSpec, dwFlags);
end;

function PathIsHTMLFileA(pszPath: PAnsiChar): BOOL;
begin
  Result := PathIsContentTypeA(pszPath, SZ_CONTENTTYPE_HTMLA);
end;

function PathIsHTMLFileW(pszPath: PWideChar): BOOL;
begin
  Result := PathIsContentTypeW(pszPath, SZ_CONTENTTYPE_HTMLW);
end;

function PathIsHTMLFile(pszPath: PChar): BOOL;
begin
  Result := PathIsContentTypeA(pszPath, SZ_CONTENTTYPE_HTMLA);
end;

{ ====== URL functions ===================================================== }

function UrlCompareA; external shlwapilib name 'UrlCompareA';
function UrlCompareW; external shlwapilib name 'UrlCompareW';
function UrlCompare; external shlwapilib name 'UrlCompareA';
function UrlCombineA; external shlwapilib name 'UrlCombineA';
function UrlCombineW; external shlwapilib name 'UrlCombineW';
function UrlCombine; external shlwapilib name 'UrlCombineA';
function UrlCanonicalizeA; external shlwapilib name 'UrlCanonicalizeA';
function UrlCanonicalizeW; external shlwapilib name 'UrlCanonicalizeW';
function UrlCanonicalize; external shlwapilib name 'UrlCanonicalizeA';
function UrlIsOpaqueA; external shlwapilib name 'UrlIsOpaqueA';
function UrlIsOpaqueW; external shlwapilib name 'UrlIsOpaqueW';
function UrlIsOpaque; external shlwapilib name 'UrlIsOpaqueA';
function UrlIsNoHistoryA; external shlwapilib name 'UrlIsNoHistoryA';
function UrlIsNoHistoryW; external shlwapilib name 'UrlIsNoHistoryW';
function UrlIsNoHistory; external shlwapilib name 'UrlIsNoHistoryA';
function UrlIsA; external shlwapilib name 'UrlIsA';
function UrlIsW; external shlwapilib name 'UrlIsW';
function UrlIs; external shlwapilib name 'UrlIsA';
function UrlGetLocationA; external shlwapilib name 'UrlGetLocationA';
function UrlGetLocationW; external shlwapilib name 'UrlGetLocationW';
function UrlGetLocation; external shlwapilib name 'UrlGetLocationA';
function UrlUnescapeA; external shlwapilib name 'UrlUnescapeA';
function UrlUnescapeW; external shlwapilib name 'UrlUnescapeW';
function UrlUnescape; external shlwapilib name 'UrlUnescapeA';
function UrlEscapeA; external shlwapilib name 'UrlEscapeA';
function UrlEscapeW; external shlwapilib name 'UrlEscapeW';
function UrlEscape; external shlwapilib name 'UrlEscapeA';
function UrlCreateFromPathA; external shlwapilib name 'UrlCreateFromPathA';
function UrlCreateFromPathW; external shlwapilib name 'UrlCreateFromPathW';
function UrlCreateFromPath; external shlwapilib name 'UrlCreateFromPathA';
function PathCreateFromUrlA; external shlwapilib name 'PathCreateFromUrlA';
function PathCreateFromUrlW; external shlwapilib name 'PathCreateFromUrlW';
function PathCreateFromUrl; external shlwapilib name 'PathCreateFromUrlA';
function UrlHashA; external shlwapilib name 'UrlHashA';
function UrlHashW; external shlwapilib name 'UrlHashW';
function UrlHash; external shlwapilib name 'UrlHashA';
function UrlGetPartA; external shlwapilib name 'UrlGetPartA';
function UrlGetPartW; external shlwapilib name 'UrlGetPartW';
function UrlGetPart; external shlwapilib name 'UrlGetPartA';
function UrlApplySchemeA; external shlwapilib name 'UrlApplySchemeA';
function UrlApplySchemeW; external shlwapilib name 'UrlApplySchemeW';
function UrlApplyScheme; external shlwapilib name 'UrlApplySchemeA';
function HashData; external shlwapilib name 'HashData';

function PathCreateFromUrlAlloc(pszIn: PWideChar; out ppszOut: PWideChar;
  dwFlags: DWORD): HRESULT; stdcall;
begin
  if GetShlwapiProc(PathCreateFromUrlAllocProc, 'PathCreateFromUrlAlloc') then
    Result := TFnPathCreateFromUrlAlloc(PathCreateFromUrlAllocProc)(pszIn, ppszOut, dwFlags)
  else
  begin
    ppszOut := nil;
    Result := E_NOTIMPL;
  end;
end;

function UrlFixupW(pcszUrl, pszTranslatedUrl: PWideChar; cchMax: DWORD): HRESULT; stdcall;
begin
  if GetShlwapiProc(UrlFixupWProc, 'UrlFixupW') then
    Result := TFnPtrPtrDwordHr(UrlFixupWProc)(pcszUrl, pszTranslatedUrl, cchMax)
  else
    Result := E_NOTIMPL;
end;

function ParseURLA(pcszURL: PAnsiChar; var ppu: TParsedUrlA): HRESULT; stdcall;
begin
  if GetShlwapiProc(ParseURLAProc, 'ParseURLA') then
    Result := TFnPtrPtrHr(ParseURLAProc)(pcszURL, @ppu)
  else
    Result := E_NOTIMPL;
end;

function ParseURLW(pcszURL: PWideChar; var ppu: TParsedUrlW): HRESULT; stdcall;
begin
  if GetShlwapiProc(ParseURLWProc, 'ParseURLW') then
    Result := TFnPtrPtrHr(ParseURLWProc)(pcszURL, @ppu)
  else
    Result := E_NOTIMPL;
end;

function ParseURL(pcszURL: PChar; var ppu: TParsedUrl): HRESULT; stdcall;
begin
  Result := ParseURLA(pcszURL, ppu);
end;

function UrlIsFileUrlA(pszURL: PAnsiChar): BOOL;
begin
  Result := UrlIsA(pszURL, URLIS_FILEURL);
end;

function UrlIsFileUrlW(pszURL: PWideChar): BOOL;
begin
  Result := UrlIsW(pszURL, URLIS_FILEURL);
end;

function UrlIsFileUrl(pszURL: PChar): BOOL;
begin
  Result := UrlIsA(pszURL, URLIS_FILEURL);
end;

function UrlEscapeSpaces(pszUrl, pszEscaped: PChar; var pcchEscaped: DWORD): HRESULT;
begin
  Result := UrlCanonicalizeA(pszUrl, pszEscaped, pcchEscaped,
    URL_ESCAPE_SPACES_ONLY or URL_DONT_ESCAPE_EXTRA_INFO);
end;

function UrlUnescapeInPlace(pszUrl: PChar; dwFlags: DWORD): HRESULT;
begin
  Result := UrlUnescapeA(pszUrl, nil, nil, dwFlags or URL_UNESCAPE_INPLACE);
end;

{ ====== Registry functions ================================================ }

function SHDeleteEmptyKeyA; external shlwapilib name 'SHDeleteEmptyKeyA';
function SHDeleteEmptyKeyW; external shlwapilib name 'SHDeleteEmptyKeyW';
function SHDeleteEmptyKey; external shlwapilib name 'SHDeleteEmptyKeyA';
function SHDeleteKeyA; external shlwapilib name 'SHDeleteKeyA';
function SHDeleteKeyW; external shlwapilib name 'SHDeleteKeyW';
function SHDeleteKey; external shlwapilib name 'SHDeleteKeyA';
function SHDeleteValueA; external shlwapilib name 'SHDeleteValueA';
function SHDeleteValueW; external shlwapilib name 'SHDeleteValueW';
function SHDeleteValue; external shlwapilib name 'SHDeleteValueA';
function SHGetValueA; external shlwapilib name 'SHGetValueA';
function SHGetValueW; external shlwapilib name 'SHGetValueW';
function SHGetValue; external shlwapilib name 'SHGetValueA';
function SHSetValueA; external shlwapilib name 'SHSetValueA';
function SHSetValueW; external shlwapilib name 'SHSetValueW';
function SHSetValue; external shlwapilib name 'SHSetValueA';
function SHQueryValueExA; external shlwapilib name 'SHQueryValueExA';
function SHQueryValueExW; external shlwapilib name 'SHQueryValueExW';
function SHQueryValueEx; external shlwapilib name 'SHQueryValueExA';
function SHEnumKeyExA; external shlwapilib name 'SHEnumKeyExA';
function SHEnumKeyExW; external shlwapilib name 'SHEnumKeyExW';
function SHEnumKeyEx; external shlwapilib name 'SHEnumKeyExA';
function SHEnumValueA; external shlwapilib name 'SHEnumValueA';
function SHEnumValueW; external shlwapilib name 'SHEnumValueW';
function SHEnumValue; external shlwapilib name 'SHEnumValueA';
function SHQueryInfoKeyA; external shlwapilib name 'SHQueryInfoKeyA';
function SHQueryInfoKeyW; external shlwapilib name 'SHQueryInfoKeyW';
function SHQueryInfoKey; external shlwapilib name 'SHQueryInfoKeyA';
function SHCopyKeyA; external shlwapilib name 'SHCopyKeyA';
function SHCopyKeyW; external shlwapilib name 'SHCopyKeyW';
function SHCopyKey; external shlwapilib name 'SHCopyKeyA';
function SHRegGetPathA; external shlwapilib name 'SHRegGetPathA';
function SHRegGetPathW; external shlwapilib name 'SHRegGetPathW';
function SHRegGetPath; external shlwapilib name 'SHRegGetPathA';
function SHRegSetPathA; external shlwapilib name 'SHRegSetPathA';
function SHRegSetPathW; external shlwapilib name 'SHRegSetPathW';
function SHRegSetPath; external shlwapilib name 'SHRegSetPathA';
function SHRegCreateUSKeyA; external shlwapilib name 'SHRegCreateUSKeyA';
function SHRegCreateUSKeyW; external shlwapilib name 'SHRegCreateUSKeyW';
function SHRegCreateUSKey; external shlwapilib name 'SHRegCreateUSKeyA';
function SHRegOpenUSKeyA; external shlwapilib name 'SHRegOpenUSKeyA';
function SHRegOpenUSKeyW; external shlwapilib name 'SHRegOpenUSKeyW';
function SHRegOpenUSKey; external shlwapilib name 'SHRegOpenUSKeyA';
function SHRegQueryUSValueA; external shlwapilib name 'SHRegQueryUSValueA';
function SHRegQueryUSValueW; external shlwapilib name 'SHRegQueryUSValueW';
function SHRegQueryUSValue; external shlwapilib name 'SHRegQueryUSValueA';
function SHRegWriteUSValueA; external shlwapilib name 'SHRegWriteUSValueA';
function SHRegWriteUSValueW; external shlwapilib name 'SHRegWriteUSValueW';
function SHRegWriteUSValue; external shlwapilib name 'SHRegWriteUSValueA';
function SHRegDeleteUSValueA; external shlwapilib name 'SHRegDeleteUSValueA';
function SHRegDeleteUSValueW; external shlwapilib name 'SHRegDeleteUSValueW';
function SHRegDeleteUSValue; external shlwapilib name 'SHRegDeleteUSValueA';
function SHRegDeleteEmptyUSKeyA; external shlwapilib name 'SHRegDeleteEmptyUSKeyA';
function SHRegDeleteEmptyUSKeyW; external shlwapilib name 'SHRegDeleteEmptyUSKeyW';
function SHRegDeleteEmptyUSKey; external shlwapilib name 'SHRegDeleteEmptyUSKeyA';
function SHRegEnumUSKeyA; external shlwapilib name 'SHRegEnumUSKeyA';
function SHRegEnumUSKeyW; external shlwapilib name 'SHRegEnumUSKeyW';
function SHRegEnumUSKey; external shlwapilib name 'SHRegEnumUSKeyA';
function SHRegEnumUSValueA; external shlwapilib name 'SHRegEnumUSValueA';
function SHRegEnumUSValueW; external shlwapilib name 'SHRegEnumUSValueW';
function SHRegEnumUSValue; external shlwapilib name 'SHRegEnumUSValueA';
function SHRegQueryInfoUSKeyA; external shlwapilib name 'SHRegQueryInfoUSKeyA';
function SHRegQueryInfoUSKeyW; external shlwapilib name 'SHRegQueryInfoUSKeyW';
function SHRegQueryInfoUSKey; external shlwapilib name 'SHRegQueryInfoUSKeyA';
function SHRegCloseUSKey; external shlwapilib name 'SHRegCloseUSKey';
function SHRegGetUSValueA; external shlwapilib name 'SHRegGetUSValueA';
function SHRegGetUSValueW; external shlwapilib name 'SHRegGetUSValueW';
function SHRegGetUSValue; external shlwapilib name 'SHRegGetUSValueA';
function SHRegSetUSValueA; external shlwapilib name 'SHRegSetUSValueA';
function SHRegSetUSValueW; external shlwapilib name 'SHRegSetUSValueW';
function SHRegSetUSValue; external shlwapilib name 'SHRegSetUSValueA';
function SHRegGetBoolUSValueA; external shlwapilib name 'SHRegGetBoolUSValueA';
function SHRegGetBoolUSValueW; external shlwapilib name 'SHRegGetBoolUSValueW';
function SHRegGetBoolUSValue; external shlwapilib name 'SHRegGetBoolUSValueA';

function SHRegDuplicateHKey(hkey: HKEY): HKEY; stdcall;
begin
  if GetShlwapiProc(SHRegDuplicateHKeyProc, 'SHRegDuplicateHKey') then
    Result := TFnSHRegDuplicateHKey(SHRegDuplicateHKeyProc)(hkey)
  else if RegOpenKeyEx(hkey, nil, 0, MAXIMUM_ALLOWED, Result) <> ERROR_SUCCESS then
    Result := 0;
end;

function SHRegGetValueA(hkey: HKEY; pszSubKey, pszValue: PAnsiChar; srrfFlags: SRRF;
  pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
begin
  if GetShlwapiProc(SHRegGetValueAProc, 'SHRegGetValueA') then
    Result := TFnSHRegGetValue(SHRegGetValueAProc)(hkey, pszSubKey, pszValue, srrfFlags,
      pdwType, pvData, pcbData)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function SHRegGetValueW(hkey: HKEY; pszSubKey, pszValue: PWideChar; srrfFlags: SRRF;
  pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
begin
  if GetShlwapiProc(SHRegGetValueWProc, 'SHRegGetValueW') then
    Result := TFnSHRegGetValue(SHRegGetValueWProc)(hkey, pszSubKey, pszValue, srrfFlags,
      pdwType, pvData, pcbData)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function SHRegGetValue(hkey: HKEY; pszSubKey, pszValue: PChar; srrfFlags: SRRF;
  pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
begin
  Result := SHRegGetValueA(hkey, pszSubKey, pszValue, srrfFlags, pdwType, pvData, pcbData);
end;

function SHRegGetValueFromHKCUHKLM(pwszKey, pwszValue: PWideChar; srrfFlags: SRRF;
  pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): LSTATUS; stdcall;
begin
  if GetShlwapiProc(SHRegGetValueFromHKCUHKLMProc, 'SHRegGetValueFromHKCUHKLM') then
    Result := TFnSHRegGetValueFromHKCUHKLM(SHRegGetValueFromHKCUHKLMProc)(pwszKey,
      pwszValue, srrfFlags, pdwType, pvData, pcbData)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function SHRegGetBoolValueFromHKCUHKLM(pszKey, pszValue: PWideChar; fDefault: BOOL): BOOL; stdcall;
begin
  if GetShlwapiProc(SHRegGetBoolValueFromHKCUHKLMProc, 'SHRegGetBoolValueFromHKCUHKLM') then
    Result := TFnSHRegGetBoolValueFromHKCUHKLM(SHRegGetBoolValueFromHKCUHKLMProc)(pszKey,
      pszValue, BoolArg(fDefault))
  else
    Result := fDefault;
end;

{ ====== Associations ====================================================== }

function AssocCreate; external shlwapilib name 'AssocCreate';
function AssocQueryStringA; external shlwapilib name 'AssocQueryStringA';
function AssocQueryStringW; external shlwapilib name 'AssocQueryStringW';
function AssocQueryString; external shlwapilib name 'AssocQueryStringA';
function AssocQueryStringByKeyA; external shlwapilib name 'AssocQueryStringByKeyA';
function AssocQueryStringByKeyW; external shlwapilib name 'AssocQueryStringByKeyW';
function AssocQueryStringByKey; external shlwapilib name 'AssocQueryStringByKeyA';
function AssocQueryKeyA; external shlwapilib name 'AssocQueryKeyA';
function AssocQueryKeyW; external shlwapilib name 'AssocQueryKeyW';
function AssocQueryKey; external shlwapilib name 'AssocQueryKeyA';

function AssocIsDangerous(pszAssoc: PWideChar): BOOL; stdcall;
begin
  if GetShlwapiProc(AssocIsDangerousProc, 'AssocIsDangerous') then
    Result := TFnAssocIsDangerous(AssocIsDangerousProc)(pszAssoc)
  else
  begin
    { a type that cannot be checked is treated as dangerous }
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := True;
  end;
end;

function AssocGetPerceivedType(pszExt: PWideChar; out ptype: PERCEIVED;
  out pflag: PERCEIVEDFLAG; ppszType: PPWideChar): HRESULT; stdcall;
begin
  if GetShlwapiProc(AssocGetPerceivedTypeProc, 'AssocGetPerceivedType') then
    Result := TFnAssocGetPerceivedType(AssocGetPerceivedTypeProc)(pszExt, ptype, pflag,
      ppszType)
  else
  begin
    ptype := PERCEIVED_TYPE_UNSPECIFIED;
    pflag := PERCEIVEDFLAG_UNDEFINED;
    if ppszType <> nil then
      ppszType^ := nil;
    Result := E_NOTIMPL;
  end;
end;

{ ====== Streams =========================================================== }

{ The imports return the IStream pointer in EAX; the public functions hand
  that reference to the interface result. }
function ShlwOpenRegStream2A(hkey: HKEY; pszSubkey, pszValue: PAnsiChar;
  grfMode: DWORD): Pointer; stdcall; external shlwapilib name 'SHOpenRegStream2A';
function ShlwOpenRegStream2W(hkey: HKEY; pszSubkey, pszValue: PWideChar;
  grfMode: DWORD): Pointer; stdcall; external shlwapilib name 'SHOpenRegStream2W';

function SHOpenRegStream2A(hkey: HKEY; pszSubkey, pszValue: PAnsiChar;
  grfMode: DWORD): IStream; stdcall;
begin
  Result := nil;
  Pointer(Result) := ShlwOpenRegStream2A(hkey, pszSubkey, pszValue, grfMode);
end;

function SHOpenRegStream2W(hkey: HKEY; pszSubkey, pszValue: PWideChar;
  grfMode: DWORD): IStream; stdcall;
begin
  Result := nil;
  Pointer(Result) := ShlwOpenRegStream2W(hkey, pszSubkey, pszValue, grfMode);
end;

function SHOpenRegStream2(hkey: HKEY; pszSubkey, pszValue: PChar;
  grfMode: DWORD): IStream; stdcall;
begin
  Result := nil;
  Pointer(Result) := ShlwOpenRegStream2A(hkey, pszSubkey, pszValue, grfMode);
end;

function SHOpenRegStream(hkey: HKEY; pszSubkey, pszValue: PChar;
  grfMode: DWORD): IStream; stdcall;
begin
  Result := nil;
  Pointer(Result) := ShlwOpenRegStream2A(hkey, pszSubkey, pszValue, grfMode);
end;

function SHCreateStreamOnFileA; external shlwapilib name 'SHCreateStreamOnFileA';
function SHCreateStreamOnFileW; external shlwapilib name 'SHCreateStreamOnFileW';
function SHCreateStreamOnFile; external shlwapilib name 'SHCreateStreamOnFileA';

function SHCreateStreamOnFileEx(pszFile: PWideChar; grfMode, dwAttributes: DWORD;
  fCreate: BOOL; pstmTemplate: IStream; out ppstm: IStream): HRESULT; stdcall;
begin
  if GetShlwapiProc(SHCreateStreamOnFileExProc, 'SHCreateStreamOnFileEx') then
    Result := TFnSHCreateStreamOnFileEx(SHCreateStreamOnFileExProc)(pszFile, grfMode,
      dwAttributes, BoolArg(fCreate), pstmTemplate, ppstm)
  else
  begin
    ppstm := nil;
    Result := E_NOTIMPL;
  end;
end;

function SHCreateMemStream(pInit: Pointer; cbInit: UINT): IStream; stdcall;
begin
  Result := nil;
  if GetShlwapiProc(SHCreateMemStreamProc, 'SHCreateMemStream') then
    Pointer(Result) := TFnSHCreateMemStream(SHCreateMemStreamProc)(pInit, cbInit);
end;

function IStream_Read(pstm: IStream; pv: Pointer; cb: ULONG): HRESULT; stdcall;
begin
  if GetShlwapiProc(IStream_ReadProc, 'IStream_Read') then
    Result := TFnIStreamPtrUlong(IStream_ReadProc)(pstm, pv, cb)
  else
    Result := E_NOTIMPL;
end;

function IStream_Write(pstm: IStream; pv: Pointer; cb: ULONG): HRESULT; stdcall;
begin
  if GetShlwapiProc(IStream_WriteProc, 'IStream_Write') then
    Result := TFnIStreamPtrUlong(IStream_WriteProc)(pstm, pv, cb)
  else
    Result := E_NOTIMPL;
end;

function IStream_Reset(pstm: IStream): HRESULT; stdcall;
begin
  if GetShlwapiProc(IStream_ResetProc, 'IStream_Reset') then
    Result := TFnIStream(IStream_ResetProc)(pstm)
  else
    Result := E_NOTIMPL;
end;

function IStream_Size(pstm: IStream; out pui: ULARGE_INTEGER): HRESULT; stdcall;
begin
  if GetShlwapiProc(IStream_SizeProc, 'IStream_Size') then
    Result := TFnIStreamSize(IStream_SizeProc)(pstm, pui)
  else
  begin
    pui.QuadPart := 0;
    Result := E_NOTIMPL;
  end;
end;

function IStream_ReadStr(pstm: IStream; out ppsz: PWideChar): HRESULT; stdcall;
begin
  if GetShlwapiProc(IStream_ReadStrProc, 'IStream_ReadStr') then
    Result := TFnIStreamReadStr(IStream_ReadStrProc)(pstm, ppsz)
  else
  begin
    ppsz := nil;
    Result := E_NOTIMPL;
  end;
end;

function IStream_WriteStr(pstm: IStream; psz: PWideChar): HRESULT; stdcall;
begin
  if GetShlwapiProc(IStream_WriteStrProc, 'IStream_WriteStr') then
    Result := TFnIStreamWriteStr(IStream_WriteStrProc)(pstm, psz)
  else
    Result := E_NOTIMPL;
end;

function IStream_Copy(pstmFrom, pstmTo: IStream; cb: DWORD): HRESULT; stdcall;
begin
  if GetShlwapiProc(IStream_CopyProc, 'IStream_Copy') then
    Result := TFnIStreamCopy(IStream_CopyProc)(pstmFrom, pstmTo, cb)
  else
    Result := E_NOTIMPL;
end;

{ ====== User interface helpers ============================================ }

function SHAutoComplete; external shlwapilib name 'SHAutoComplete';

function SHMessageBoxCheckA(hwnd: HWND; pszText, pszCaption: PAnsiChar; uType: UINT;
  iDefault: Integer; pszRegVal: PAnsiChar): Integer; stdcall;
begin
  if GetShlwapiProc(SHMessageBoxCheckAProc, 'SHMessageBoxCheckA') then
    Result := TFnSHMessageBoxCheck(SHMessageBoxCheckAProc)(hwnd, pszText, pszCaption,
      uType, iDefault, pszRegVal)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := -1;
  end;
end;

function SHMessageBoxCheckW(hwnd: HWND; pszText, pszCaption: PWideChar; uType: UINT;
  iDefault: Integer; pszRegVal: PWideChar): Integer; stdcall;
begin
  if GetShlwapiProc(SHMessageBoxCheckWProc, 'SHMessageBoxCheckW') then
    Result := TFnSHMessageBoxCheck(SHMessageBoxCheckWProc)(hwnd, pszText, pszCaption,
      uType, iDefault, pszRegVal)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := -1;
  end;
end;

function SHMessageBoxCheck(hwnd: HWND; pszText, pszCaption: PChar; uType: UINT;
  iDefault: Integer; pszRegVal: PChar): Integer; stdcall;
begin
  Result := SHMessageBoxCheckA(hwnd, pszText, pszCaption, uType, iDefault, pszRegVal);
end;

{ ====== GDI helpers ======================================================= }

function SHCreateShellPalette; external shlwapilib name 'SHCreateShellPalette';
procedure ColorRGBToHLS; external shlwapilib name 'ColorRGBToHLS';
function ColorHLSToRGB; external shlwapilib name 'ColorHLSToRGB';
function ColorAdjustLuma; external shlwapilib name 'ColorAdjustLuma';

{ ====== DllGetVersion ===================================================== }

function MAKEDLLVERULL(Major, Minor, Build, Qfe: Word): Int64;
begin
  Result := (Int64(Major) shl 48) or (Int64(Minor) shl 32) or (Int64(Build) shl 16) or
    Int64(Qfe);
end;

end.
