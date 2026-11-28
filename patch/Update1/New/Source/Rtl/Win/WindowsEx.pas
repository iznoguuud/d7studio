{**********************************************************}
{                                                          }
{     Delphi 7 Runtime Library - Modernization             }
{     kernel32 / user32 / gdi32 / advapi32 / ntdll         }
{     additions, Windows Vista .. Windows 11               }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit WindowsEx;

{ Translated from winnt.h, winbase.h, sysinfoapi.h, processthreadsapi.h,
  wow64apiset.h, synchapi.h, libloaderapi.h, heapapi.h, fileapi.h, winnls.h,
  stringapiset.h, winuser.h, threadpoolapiset.h, threadpoollegacyapiset.h,
  fibersapi.h, jobapi2.h, ioapiset.h, namedpipeapi.h, datetimeapi.h,
  timezoneapi.h, errhandlingapi.h, debugapi.h, wingdi.h, winreg.h, sddl.h,
  securitybaseapi.h and wincred.h (Windows SDK 10.0.26100): kernel32,
  user32, gdi32, advapi32 and ntdll functions.

  Every function is bound at run time on first use (also the few that exist
  in Windows XP, for uniformity), so programs that use this unit still start
  on Windows XP. When a function is missing:
    - BOOL functions return False after SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    - functions that return a Win32 error code (the registry functions,
      display configuration) return ERROR_CALL_NOT_IMPLEMENTED, HRESULT
      functions E_NOTIMPL;
    - where a simple, correct emulation exists it is used instead;
    - the fallback of every other function is documented next to it.
  BOOL arguments are passed to Windows as 0 or 1: Delphi stores True as -1,
  which some functions reject (CompareStringOrdinal fails with it).

  Not declared here on purpose: the DPI awareness API (ShellScaling.pas) and
  the window messages WM_TOUCH, WM_GESTURE, WM_GESTURENOTIFY, WM_POINTER*,
  WM_CLIPBOARDUPDATE (Messages.pas), the power scheme functions of
  powrprof.dll (PowrProf.pas) and WTSGetActiveConsoleSessionId (WtsApi32.pas). }

{$WEAKPACKAGEUNIT ON}
{$MINENUMSIZE 4}

interface

uses
  Windows;

type
  {$EXTERNALSYM NTSTATUS}
  NTSTATUS = Longint;

{ ====== Version information (winnt.h, sysinfoapi.h, ntdll) ================ }

type
  POSVersionInfoExA = ^TOSVersionInfoExA;
  POSVersionInfoExW = ^TOSVersionInfoExW;
  POSVersionInfoEx = POSVersionInfoExA;
  {$EXTERNALSYM _OSVERSIONINFOEXA}
  _OSVERSIONINFOEXA = record
    dwOSVersionInfoSize: DWORD;
    dwMajorVersion: DWORD;
    dwMinorVersion: DWORD;
    dwBuildNumber: DWORD;
    dwPlatformId: DWORD;
    szCSDVersion: array[0..127] of AnsiChar;  { Maintenance string for PSS usage }
    wServicePackMajor: Word;
    wServicePackMinor: Word;
    wSuiteMask: Word;
    wProductType: Byte;
    wReserved: Byte;
  end;
  {$EXTERNALSYM _OSVERSIONINFOEXW}
  _OSVERSIONINFOEXW = record
    dwOSVersionInfoSize: DWORD;
    dwMajorVersion: DWORD;
    dwMinorVersion: DWORD;
    dwBuildNumber: DWORD;
    dwPlatformId: DWORD;
    szCSDVersion: array[0..127] of WideChar;  { Maintenance string for PSS usage }
    wServicePackMajor: Word;
    wServicePackMinor: Word;
    wSuiteMask: Word;
    wProductType: Byte;
    wReserved: Byte;
  end;
  {$EXTERNALSYM _OSVERSIONINFOEX}
  _OSVERSIONINFOEX = _OSVERSIONINFOEXA;
  TOSVersionInfoExA = _OSVERSIONINFOEXA;
  TOSVersionInfoExW = _OSVERSIONINFOEXW;
  TOSVersionInfoEx = TOSVersionInfoExA;
  {$EXTERNALSYM OSVERSIONINFOEXA}
  OSVERSIONINFOEXA = _OSVERSIONINFOEXA;
  {$EXTERNALSYM OSVERSIONINFOEXW}
  OSVERSIONINFOEXW = _OSVERSIONINFOEXW;
  {$EXTERNALSYM OSVERSIONINFOEX}
  OSVERSIONINFOEX = OSVERSIONINFOEXA;
  {$EXTERNALSYM LPOSVERSIONINFOEXA}
  LPOSVERSIONINFOEXA = POSVersionInfoExA;
  {$EXTERNALSYM LPOSVERSIONINFOEXW}
  LPOSVERSIONINFOEXW = POSVersionInfoExW;
  {$EXTERNALSYM RTL_OSVERSIONINFOEXW}
  RTL_OSVERSIONINFOEXW = _OSVERSIONINFOEXW;
  {$EXTERNALSYM PRTL_OSVERSIONINFOEXW}
  PRTL_OSVERSIONINFOEXW = POSVersionInfoExW;

const
  { VerSetConditionMask conditions }
  {$EXTERNALSYM VER_EQUAL}
  VER_EQUAL         = 1;
  {$EXTERNALSYM VER_GREATER}
  VER_GREATER       = 2;
  {$EXTERNALSYM VER_GREATER_EQUAL}
  VER_GREATER_EQUAL = 3;
  {$EXTERNALSYM VER_LESS}
  VER_LESS          = 4;
  {$EXTERNALSYM VER_LESS_EQUAL}
  VER_LESS_EQUAL    = 5;
  {$EXTERNALSYM VER_AND}
  VER_AND           = 6;
  {$EXTERNALSYM VER_OR}
  VER_OR            = 7;
  {$EXTERNALSYM VER_CONDITION_MASK}
  VER_CONDITION_MASK = 7;
  {$EXTERNALSYM VER_NUM_BITS_PER_CONDITION_MASK}
  VER_NUM_BITS_PER_CONDITION_MASK = 3;

  { VerifyVersionInfo / VerSetConditionMask type mask }
  {$EXTERNALSYM VER_MINORVERSION}
  VER_MINORVERSION     = $0000001;
  {$EXTERNALSYM VER_MAJORVERSION}
  VER_MAJORVERSION     = $0000002;
  {$EXTERNALSYM VER_BUILDNUMBER}
  VER_BUILDNUMBER      = $0000004;
  {$EXTERNALSYM VER_PLATFORMID}
  VER_PLATFORMID       = $0000008;
  {$EXTERNALSYM VER_SERVICEPACKMINOR}
  VER_SERVICEPACKMINOR = $0000010;
  {$EXTERNALSYM VER_SERVICEPACKMAJOR}
  VER_SERVICEPACKMAJOR = $0000020;
  {$EXTERNALSYM VER_SUITENAME}
  VER_SUITENAME        = $0000040;
  {$EXTERNALSYM VER_PRODUCT_TYPE}
  VER_PRODUCT_TYPE     = $0000080;

  { wProductType }
  {$EXTERNALSYM VER_NT_WORKSTATION}
  VER_NT_WORKSTATION       = $0000001;
  {$EXTERNALSYM VER_NT_DOMAIN_CONTROLLER}
  VER_NT_DOMAIN_CONTROLLER = $0000002;
  {$EXTERNALSYM VER_NT_SERVER}
  VER_NT_SERVER            = $0000003;

  { wSuiteMask }
  {$EXTERNALSYM VER_SUITE_SMALLBUSINESS}
  VER_SUITE_SMALLBUSINESS            = $00000001;
  {$EXTERNALSYM VER_SUITE_ENTERPRISE}
  VER_SUITE_ENTERPRISE               = $00000002;
  {$EXTERNALSYM VER_SUITE_BACKOFFICE}
  VER_SUITE_BACKOFFICE               = $00000004;
  {$EXTERNALSYM VER_SUITE_COMMUNICATIONS}
  VER_SUITE_COMMUNICATIONS           = $00000008;
  {$EXTERNALSYM VER_SUITE_TERMINAL}
  VER_SUITE_TERMINAL                 = $00000010;
  {$EXTERNALSYM VER_SUITE_SMALLBUSINESS_RESTRICTED}
  VER_SUITE_SMALLBUSINESS_RESTRICTED = $00000020;
  {$EXTERNALSYM VER_SUITE_EMBEDDEDNT}
  VER_SUITE_EMBEDDEDNT               = $00000040;
  {$EXTERNALSYM VER_SUITE_DATACENTER}
  VER_SUITE_DATACENTER               = $00000080;
  {$EXTERNALSYM VER_SUITE_SINGLEUSERTS}
  VER_SUITE_SINGLEUSERTS             = $00000100;
  {$EXTERNALSYM VER_SUITE_PERSONAL}
  VER_SUITE_PERSONAL                 = $00000200;
  {$EXTERNALSYM VER_SUITE_BLADE}
  VER_SUITE_BLADE                    = $00000400;
  {$EXTERNALSYM VER_SUITE_EMBEDDED_RESTRICTED}
  VER_SUITE_EMBEDDED_RESTRICTED      = $00000800;
  {$EXTERNALSYM VER_SUITE_SECURITY_APPLIANCE}
  VER_SUITE_SECURITY_APPLIANCE       = $00001000;
  {$EXTERNALSYM VER_SUITE_STORAGE_SERVER}
  VER_SUITE_STORAGE_SERVER           = $00002000;
  {$EXTERNALSYM VER_SUITE_COMPUTE_SERVER}
  VER_SUITE_COMPUTE_SERVER           = $00004000;
  {$EXTERNALSYM VER_SUITE_WH_SERVER}
  VER_SUITE_WH_SERVER                = $00008000;
  {$EXTERNALSYM VER_SUITE_MULTIUSERTS}
  VER_SUITE_MULTIUSERTS              = $00020000;

  { GetProductInfo (common subset of winnt.h) }
  {$EXTERNALSYM PRODUCT_UNDEFINED}
  PRODUCT_UNDEFINED                    = $00000000;
  {$EXTERNALSYM PRODUCT_ULTIMATE}
  PRODUCT_ULTIMATE                     = $00000001;
  {$EXTERNALSYM PRODUCT_HOME_BASIC}
  PRODUCT_HOME_BASIC                   = $00000002;
  {$EXTERNALSYM PRODUCT_HOME_PREMIUM}
  PRODUCT_HOME_PREMIUM                 = $00000003;
  {$EXTERNALSYM PRODUCT_ENTERPRISE}
  PRODUCT_ENTERPRISE                   = $00000004;
  {$EXTERNALSYM PRODUCT_HOME_BASIC_N}
  PRODUCT_HOME_BASIC_N                 = $00000005;
  {$EXTERNALSYM PRODUCT_BUSINESS}
  PRODUCT_BUSINESS                     = $00000006;
  {$EXTERNALSYM PRODUCT_STANDARD_SERVER}
  PRODUCT_STANDARD_SERVER              = $00000007;
  {$EXTERNALSYM PRODUCT_DATACENTER_SERVER}
  PRODUCT_DATACENTER_SERVER            = $00000008;
  {$EXTERNALSYM PRODUCT_SMALLBUSINESS_SERVER}
  PRODUCT_SMALLBUSINESS_SERVER         = $00000009;
  {$EXTERNALSYM PRODUCT_ENTERPRISE_SERVER}
  PRODUCT_ENTERPRISE_SERVER            = $0000000A;
  {$EXTERNALSYM PRODUCT_STARTER}
  PRODUCT_STARTER                      = $0000000B;
  {$EXTERNALSYM PRODUCT_DATACENTER_SERVER_CORE}
  PRODUCT_DATACENTER_SERVER_CORE       = $0000000C;
  {$EXTERNALSYM PRODUCT_STANDARD_SERVER_CORE}
  PRODUCT_STANDARD_SERVER_CORE         = $0000000D;
  {$EXTERNALSYM PRODUCT_ENTERPRISE_SERVER_CORE}
  PRODUCT_ENTERPRISE_SERVER_CORE       = $0000000E;
  {$EXTERNALSYM PRODUCT_BUSINESS_N}
  PRODUCT_BUSINESS_N                   = $00000010;
  {$EXTERNALSYM PRODUCT_WEB_SERVER}
  PRODUCT_WEB_SERVER                   = $00000011;
  {$EXTERNALSYM PRODUCT_HOME_SERVER}
  PRODUCT_HOME_SERVER                  = $00000013;
  {$EXTERNALSYM PRODUCT_HOME_PREMIUM_N}
  PRODUCT_HOME_PREMIUM_N               = $0000001A;
  {$EXTERNALSYM PRODUCT_ENTERPRISE_N}
  PRODUCT_ENTERPRISE_N                 = $0000001B;
  {$EXTERNALSYM PRODUCT_ULTIMATE_N}
  PRODUCT_ULTIMATE_N                   = $0000001C;
  {$EXTERNALSYM PRODUCT_STARTER_N}
  PRODUCT_STARTER_N                    = $0000002F;
  {$EXTERNALSYM PRODUCT_PROFESSIONAL}
  PRODUCT_PROFESSIONAL                 = $00000030;
  {$EXTERNALSYM PRODUCT_PROFESSIONAL_N}
  PRODUCT_PROFESSIONAL_N               = $00000031;
  {$EXTERNALSYM PRODUCT_ENTERPRISE_EVALUATION}
  PRODUCT_ENTERPRISE_EVALUATION        = $00000048;
  {$EXTERNALSYM PRODUCT_STANDARD_EVALUATION_SERVER}
  PRODUCT_STANDARD_EVALUATION_SERVER   = $0000004F;
  {$EXTERNALSYM PRODUCT_DATACENTER_EVALUATION_SERVER}
  PRODUCT_DATACENTER_EVALUATION_SERVER = $00000050;
  {$EXTERNALSYM PRODUCT_CORE_N}
  PRODUCT_CORE_N                       = $00000062;
  {$EXTERNALSYM PRODUCT_CORE_COUNTRYSPECIFIC}
  PRODUCT_CORE_COUNTRYSPECIFIC         = $00000063;
  {$EXTERNALSYM PRODUCT_CORE_SINGLELANGUAGE}
  PRODUCT_CORE_SINGLELANGUAGE          = $00000064;
  {$EXTERNALSYM PRODUCT_CORE}
  PRODUCT_CORE                         = $00000065;
  {$EXTERNALSYM PRODUCT_EDUCATION}
  PRODUCT_EDUCATION                    = $00000079;
  {$EXTERNALSYM PRODUCT_EDUCATION_N}
  PRODUCT_EDUCATION_N                  = $0000007A;
  {$EXTERNALSYM PRODUCT_ENTERPRISE_S}
  PRODUCT_ENTERPRISE_S                 = $0000007D;
  {$EXTERNALSYM PRODUCT_ENTERPRISE_S_N}
  PRODUCT_ENTERPRISE_S_N               = $0000007E;
  {$EXTERNALSYM PRODUCT_PRO_WORKSTATION}
  PRODUCT_PRO_WORKSTATION              = $000000A1;
  {$EXTERNALSYM PRODUCT_PRO_WORKSTATION_N}
  PRODUCT_PRO_WORKSTATION_N            = $000000A2;
  {$EXTERNALSYM PRODUCT_PRO_FOR_EDUCATION}
  PRODUCT_PRO_FOR_EDUCATION            = $000000A4;
  {$EXTERNALSYM PRODUCT_ENTERPRISEG}
  PRODUCT_ENTERPRISEG                  = $000000AB;
  {$EXTERNALSYM PRODUCT_SERVERRDSH}
  PRODUCT_SERVERRDSH                   = $000000AF;
  {$EXTERNALSYM PRODUCT_CLOUD}
  PRODUCT_CLOUD                        = $000000B2;
  {$EXTERNALSYM PRODUCT_IOTENTERPRISE}
  PRODUCT_IOTENTERPRISE                = $000000BC;
  {$EXTERNALSYM PRODUCT_IOTENTERPRISES}
  PRODUCT_IOTENTERPRISES               = $000000BF;
  {$EXTERNALSYM PRODUCT_UNLICENSED}
  PRODUCT_UNLICENSED                   = $ABCDABCD;

{ ntdll (Windows 2000+). Reports the real version: unlike GetVersionEx and
  VerifyVersionInfo it is not affected by the application compatibility
  manifest. Set dwOSVersionInfoSize to SizeOf(TOSVersionInfoExW). Fallback:
  STATUS_NOT_IMPLEMENTED ($C0000002). }
{$EXTERNALSYM RtlGetVersion}
function RtlGetVersion(var lpVersionInformation: TOSVersionInfoExW): NTSTATUS; stdcall;

{ Not an SDK function: real Windows version (RtlGetVersion, so immune to
  manifest version lies); falls back to GetVersionEx on systems without
  RtlGetVersion. Returns False only if both fail. }
function GetRealWindowsVersion(out Major, Minor, Build: Cardinal): Boolean;

{ Windows 2000+. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED).
  Note: subject to the manifest version lie on Windows 8.1 and later; the
  IsWindows*OrGreater functions below use RtlGetVersion instead. }
{$EXTERNALSYM VerifyVersionInfo}
function VerifyVersionInfo(var lpVersionInformation: TOSVersionInfoEx;
  dwTypeMask: DWORD; dwlConditionMask: Int64): BOOL; stdcall;
{$EXTERNALSYM VerifyVersionInfoA}
function VerifyVersionInfoA(var lpVersionInformation: TOSVersionInfoExA;
  dwTypeMask: DWORD; dwlConditionMask: Int64): BOOL; stdcall;
{$EXTERNALSYM VerifyVersionInfoW}
function VerifyVersionInfoW(var lpVersionInformation: TOSVersionInfoExW;
  dwTypeMask: DWORD; dwlConditionMask: Int64): BOOL; stdcall;
{ ULONGLONG result, returned in EDX:EAX. Fallback: exact emulation. }
{$EXTERNALSYM VerSetConditionMask}
function VerSetConditionMask(ConditionMask: Int64; TypeMask: DWORD;
  Condition: Byte): Int64; stdcall;

{ Windows Vista. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED) and
  pdwReturnedProductType = PRODUCT_UNDEFINED. }
{$EXTERNALSYM GetProductInfo}
function GetProductInfo(dwOSMajorVersion, dwOSMinorVersion, dwSpMajorVersion,
  dwSpMinorVersion: DWORD; out pdwReturnedProductType: DWORD): BOOL; stdcall;

{ VersionHelpers.h equivalents. They are based on RtlGetVersion, so they
  report the real version also without a compatibility manifest. }
{$EXTERNALSYM IsWindowsVersionOrGreater}
function IsWindowsVersionOrGreater(wMajorVersion, wMinorVersion,
  wServicePackMajor: Word): Boolean;
{$EXTERNALSYM IsWindowsXPOrGreater}
function IsWindowsXPOrGreater: Boolean;
{$EXTERNALSYM IsWindowsXPSP1OrGreater}
function IsWindowsXPSP1OrGreater: Boolean;
{$EXTERNALSYM IsWindowsXPSP2OrGreater}
function IsWindowsXPSP2OrGreater: Boolean;
{$EXTERNALSYM IsWindowsXPSP3OrGreater}
function IsWindowsXPSP3OrGreater: Boolean;
{$EXTERNALSYM IsWindowsVistaOrGreater}
function IsWindowsVistaOrGreater: Boolean;
{$EXTERNALSYM IsWindowsVistaSP1OrGreater}
function IsWindowsVistaSP1OrGreater: Boolean;
{$EXTERNALSYM IsWindowsVistaSP2OrGreater}
function IsWindowsVistaSP2OrGreater: Boolean;
{$EXTERNALSYM IsWindows7OrGreater}
function IsWindows7OrGreater: Boolean;
{$EXTERNALSYM IsWindows7SP1OrGreater}
function IsWindows7SP1OrGreater: Boolean;
{$EXTERNALSYM IsWindows8OrGreater}
function IsWindows8OrGreater: Boolean;
{$EXTERNALSYM IsWindows8Point1OrGreater}
function IsWindows8Point1OrGreater: Boolean;
{$EXTERNALSYM IsWindowsThresholdOrGreater}
function IsWindowsThresholdOrGreater: Boolean;
{$EXTERNALSYM IsWindows10OrGreater}
function IsWindows10OrGreater: Boolean;
{ Not in VersionHelpers.h: Windows 11 = version 10.0, build 22000 or later. }
function IsWindows11OrGreater: Boolean;
{ True on server editions (wProductType <> VER_NT_WORKSTATION). }
{$EXTERNALSYM IsWindowsServer}
function IsWindowsServer: Boolean;

{ ====== System information ================================================ }

const
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_INTEL}
  PROCESSOR_ARCHITECTURE_INTEL          = 0;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_MIPS}
  PROCESSOR_ARCHITECTURE_MIPS           = 1;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_ALPHA}
  PROCESSOR_ARCHITECTURE_ALPHA          = 2;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_PPC}
  PROCESSOR_ARCHITECTURE_PPC            = 3;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_SHX}
  PROCESSOR_ARCHITECTURE_SHX            = 4;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_ARM}
  PROCESSOR_ARCHITECTURE_ARM            = 5;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_IA64}
  PROCESSOR_ARCHITECTURE_IA64           = 6;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_ALPHA64}
  PROCESSOR_ARCHITECTURE_ALPHA64        = 7;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_MSIL}
  PROCESSOR_ARCHITECTURE_MSIL           = 8;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_AMD64}
  PROCESSOR_ARCHITECTURE_AMD64          = 9;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_IA32_ON_WIN64}
  PROCESSOR_ARCHITECTURE_IA32_ON_WIN64  = 10;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_NEUTRAL}
  PROCESSOR_ARCHITECTURE_NEUTRAL        = 11;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_ARM64}
  PROCESSOR_ARCHITECTURE_ARM64          = 12;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_ARM32_ON_WIN64}
  PROCESSOR_ARCHITECTURE_ARM32_ON_WIN64 = 13;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_IA32_ON_ARM64}
  PROCESSOR_ARCHITECTURE_IA32_ON_ARM64  = 14;
  {$EXTERNALSYM PROCESSOR_ARCHITECTURE_UNKNOWN}
  PROCESSOR_ARCHITECTURE_UNKNOWN        = $FFFF;

{ Windows Vista. Fallback: GetTickCount extended to 64 bits with wrap
  detection (correct as long as it is called at least once every 49.7 days). }
{$EXTERNALSYM GetTickCount64}
function GetTickCount64: Int64; stdcall;
{ Windows XP. Fallback: GetSystemInfo. }
{$EXTERNALSYM GetNativeSystemInfo}
procedure GetNativeSystemInfo(var lpSystemInfo: TSystemInfo); stdcall;
{ Windows XP SP2. Fallback: returns True with Wow64Process = False (a system
  without IsWow64Process cannot run WOW64 processes). }
{$EXTERNALSYM IsWow64Process}
function IsWow64Process(hProcess: THandle; var Wow64Process: BOOL): BOOL; stdcall;
{ Windows 8. Fallback: GetSystemTimeAsFileTime. }
{$EXTERNALSYM GetSystemTimePreciseAsFileTime}
procedure GetSystemTimePreciseAsFileTime(var lpSystemTimeAsFileTime: TFileTime); stdcall;

{ ====== Processes and files =============================================== }

const
  {$EXTERNALSYM PROCESS_QUERY_LIMITED_INFORMATION}
  PROCESS_QUERY_LIMITED_INFORMATION = $1000;  // Windows Vista
  {$EXTERNALSYM PROCESS_NAME_NATIVE}
  PROCESS_NAME_NATIVE = $00000001;

{ Windows Vista. lpdwSize: in = size of lpExeName in characters, out = length
  without the terminating null. Fallback (Windows XP): psapi
  GetModuleFileNameEx (or GetProcessImageFileName for PROCESS_NAME_NATIVE),
  which needs PROCESS_QUERY_INFORMATION or PROCESS_VM_READ access; False when
  that is not available either. }
{$EXTERNALSYM QueryFullProcessImageName}
function QueryFullProcessImageName(hProcess: THandle; dwFlags: DWORD; lpExeName: PChar;
  var lpdwSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM QueryFullProcessImageNameA}
function QueryFullProcessImageNameA(hProcess: THandle; dwFlags: DWORD; lpExeName: PAnsiChar;
  var lpdwSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM QueryFullProcessImageNameW}
function QueryFullProcessImageNameW(hProcess: THandle; dwFlags: DWORD; lpExeName: PWideChar;
  var lpdwSize: DWORD): BOOL; stdcall;

const
  { GetFinalPathNameByHandle dwFlags }
  {$EXTERNALSYM FILE_NAME_NORMALIZED}
  FILE_NAME_NORMALIZED = $0;  // default
  {$EXTERNALSYM FILE_NAME_OPENED}
  FILE_NAME_OPENED     = $8;
  {$EXTERNALSYM VOLUME_NAME_DOS}
  VOLUME_NAME_DOS      = $0;  // default
  {$EXTERNALSYM VOLUME_NAME_GUID}
  VOLUME_NAME_GUID     = $1;
  {$EXTERNALSYM VOLUME_NAME_NT}
  VOLUME_NAME_NT       = $2;
  {$EXTERNALSYM VOLUME_NAME_NONE}
  VOLUME_NAME_NONE     = $4;

{ Windows Vista. Returns the length (without null) or, if the buffer is too
  small, the required size including the null; 0 on error. Fallback: 0
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetFinalPathNameByHandle}
function GetFinalPathNameByHandle(hFile: THandle; lpszFilePath: PChar;
  cchFilePath: DWORD; dwFlags: DWORD): DWORD; stdcall;
{$EXTERNALSYM GetFinalPathNameByHandleA}
function GetFinalPathNameByHandleA(hFile: THandle; lpszFilePath: PAnsiChar;
  cchFilePath: DWORD; dwFlags: DWORD): DWORD; stdcall;
{$EXTERNALSYM GetFinalPathNameByHandleW}
function GetFinalPathNameByHandleW(hFile: THandle; lpszFilePath: PWideChar;
  cchFilePath: DWORD; dwFlags: DWORD): DWORD; stdcall;

const
  {$EXTERNALSYM SYMBOLIC_LINK_FLAG_DIRECTORY}
  SYMBOLIC_LINK_FLAG_DIRECTORY                 = $1;
  {$EXTERNALSYM SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE}
  SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE = $2;  // Windows 10 1703, developer mode

{ Windows Vista. The SDK return type is BOOLEAN (one byte), hence ByteBool.
  Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM CreateSymbolicLink}
function CreateSymbolicLink(lpSymlinkFileName, lpTargetFileName: PChar;
  dwFlags: DWORD): ByteBool; stdcall;
{$EXTERNALSYM CreateSymbolicLinkA}
function CreateSymbolicLinkA(lpSymlinkFileName, lpTargetFileName: PAnsiChar;
  dwFlags: DWORD): ByteBool; stdcall;
{$EXTERNALSYM CreateSymbolicLinkW}
function CreateSymbolicLinkW(lpSymlinkFileName, lpTargetFileName: PWideChar;
  dwFlags: DWORD): ByteBool; stdcall;

{ ====== Slim reader/writer locks and condition variables (synchapi.h) ===== }

type
  { Pointer-sized, initialize with InitializeSRWLock or SRWLOCK_INIT
    (all zero). Never copy or move a lock that is in use. }
  PRTLSRWLock = ^TRTLSRWLock;
  {$EXTERNALSYM _RTL_SRWLOCK}
  _RTL_SRWLOCK = record
    Ptr: Pointer;
  end;
  {$EXTERNALSYM RTL_SRWLOCK}
  RTL_SRWLOCK = _RTL_SRWLOCK;
  TRTLSRWLock = _RTL_SRWLOCK;
  {$EXTERNALSYM SRWLOCK}
  SRWLOCK = _RTL_SRWLOCK;
  {$EXTERNALSYM PSRWLOCK}
  PSRWLOCK = PRTLSRWLock;

  PRTLConditionVariable = ^TRTLConditionVariable;
  {$EXTERNALSYM _RTL_CONDITION_VARIABLE}
  _RTL_CONDITION_VARIABLE = record
    Ptr: Pointer;
  end;
  {$EXTERNALSYM RTL_CONDITION_VARIABLE}
  RTL_CONDITION_VARIABLE = _RTL_CONDITION_VARIABLE;
  TRTLConditionVariable = _RTL_CONDITION_VARIABLE;
  {$EXTERNALSYM CONDITION_VARIABLE}
  CONDITION_VARIABLE = _RTL_CONDITION_VARIABLE;
  {$EXTERNALSYM PCONDITION_VARIABLE}
  PCONDITION_VARIABLE = PRTLConditionVariable;

const
  {$EXTERNALSYM SRWLOCK_INIT}
  SRWLOCK_INIT: TRTLSRWLock = (Ptr: nil);
  {$EXTERNALSYM CONDITION_VARIABLE_INIT}
  CONDITION_VARIABLE_INIT: TRTLConditionVariable = (Ptr: nil);
  {$EXTERNALSYM CONDITION_VARIABLE_LOCKMODE_SHARED}
  CONDITION_VARIABLE_LOCKMODE_SHARED = $1;

{ Windows Vista. Fallback (Windows XP): an emulation with the same contract
  that stores its state in the pointer-sized lock (interlocked operations,
  yields with Sleep while it waits; not fair, no recursion, like the real
  SRW lock). The choice is made once per process, so the emulation is never
  mixed with the real implementation. }
{$EXTERNALSYM InitializeSRWLock}
procedure InitializeSRWLock(var SRWLock: TRTLSRWLock); stdcall;
{$EXTERNALSYM AcquireSRWLockExclusive}
procedure AcquireSRWLockExclusive(var SRWLock: TRTLSRWLock); stdcall;
{$EXTERNALSYM AcquireSRWLockShared}
procedure AcquireSRWLockShared(var SRWLock: TRTLSRWLock); stdcall;
{$EXTERNALSYM ReleaseSRWLockExclusive}
procedure ReleaseSRWLockExclusive(var SRWLock: TRTLSRWLock); stdcall;
{$EXTERNALSYM ReleaseSRWLockShared}
procedure ReleaseSRWLockShared(var SRWLock: TRTLSRWLock); stdcall;
{ Windows 7 (BOOLEAN result). On Windows XP they use the emulation above; on
  Windows Vista (real SRW locks but no TryAcquire*) they return False after
  SetLastError(ERROR_CALL_NOT_IMPLEMENTED), i.e. "not acquired". }
{$EXTERNALSYM TryAcquireSRWLockExclusive}
function TryAcquireSRWLockExclusive(var SRWLock: TRTLSRWLock): ByteBool; stdcall;
{$EXTERNALSYM TryAcquireSRWLockShared}
function TryAcquireSRWLockShared(var SRWLock: TRTLSRWLock): ByteBool; stdcall;

{ Windows Vista. Fallback (Windows XP): a polling emulation that keeps the
  documented contract - the lock is released while waiting and re-acquired
  before returning, a wake is never lost, the timeout is honoured (False
  with ERROR_TIMEOUT), and spurious wake-ups are possible (Wake wakes all
  waiters; waiters notice a wake within about 1-15 ms). }
{$EXTERNALSYM InitializeConditionVariable}
procedure InitializeConditionVariable(var ConditionVariable: TRTLConditionVariable); stdcall;
{$EXTERNALSYM SleepConditionVariableCS}
function SleepConditionVariableCS(var ConditionVariable: TRTLConditionVariable;
  var CriticalSection: TRTLCriticalSection; dwMilliseconds: DWORD): BOOL; stdcall;
{$EXTERNALSYM SleepConditionVariableSRW}
function SleepConditionVariableSRW(var ConditionVariable: TRTLConditionVariable;
  var SRWLock: TRTLSRWLock; dwMilliseconds: DWORD; Flags: ULONG): BOOL; stdcall;
{$EXTERNALSYM WakeConditionVariable}
procedure WakeConditionVariable(var ConditionVariable: TRTLConditionVariable); stdcall;
{$EXTERNALSYM WakeAllConditionVariable}
procedure WakeAllConditionVariable(var ConditionVariable: TRTLConditionVariable); stdcall;

{ ====== DLL search path, DEP, heap (libloaderapi.h, winbase.h) ============ }

type
  {$EXTERNALSYM DLL_DIRECTORY_COOKIE}
  DLL_DIRECTORY_COOKIE = Pointer;
  {$EXTERNALSYM PDLL_DIRECTORY_COOKIE}
  PDLL_DIRECTORY_COOKIE = ^DLL_DIRECTORY_COOKIE;

const
  { LoadLibraryEx flags (the LOAD_LIBRARY_SEARCH_* flags need Windows 8, or
    Windows Vista/7 with KB2533623) }
  {$EXTERNALSYM LOAD_IGNORE_CODE_AUTHZ_LEVEL}
  LOAD_IGNORE_CODE_AUTHZ_LEVEL        = $00000010;
  {$EXTERNALSYM LOAD_LIBRARY_AS_IMAGE_RESOURCE}
  LOAD_LIBRARY_AS_IMAGE_RESOURCE      = $00000020;
  {$EXTERNALSYM LOAD_LIBRARY_AS_DATAFILE_EXCLUSIVE}
  LOAD_LIBRARY_AS_DATAFILE_EXCLUSIVE  = $00000040;
  {$EXTERNALSYM LOAD_LIBRARY_REQUIRE_SIGNED_TARGET}
  LOAD_LIBRARY_REQUIRE_SIGNED_TARGET  = $00000080;
  {$EXTERNALSYM LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR}
  LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR    = $00000100;
  {$EXTERNALSYM LOAD_LIBRARY_SEARCH_APPLICATION_DIR}
  LOAD_LIBRARY_SEARCH_APPLICATION_DIR = $00000200;
  {$EXTERNALSYM LOAD_LIBRARY_SEARCH_USER_DIRS}
  LOAD_LIBRARY_SEARCH_USER_DIRS       = $00000400;
  {$EXTERNALSYM LOAD_LIBRARY_SEARCH_SYSTEM32}
  LOAD_LIBRARY_SEARCH_SYSTEM32        = $00000800;
  {$EXTERNALSYM LOAD_LIBRARY_SEARCH_DEFAULT_DIRS}
  LOAD_LIBRARY_SEARCH_DEFAULT_DIRS    = $00001000;
  {$EXTERNALSYM LOAD_LIBRARY_SAFE_CURRENT_DIRS}
  LOAD_LIBRARY_SAFE_CURRENT_DIRS      = $00002000;  // Windows 10 1607

  { SetSearchPathMode }
  {$EXTERNALSYM BASE_SEARCH_PATH_ENABLE_SAFE_SEARCHMODE}
  BASE_SEARCH_PATH_ENABLE_SAFE_SEARCHMODE  = $00000001;
  {$EXTERNALSYM BASE_SEARCH_PATH_DISABLE_SAFE_SEARCHMODE}
  BASE_SEARCH_PATH_DISABLE_SAFE_SEARCHMODE = $00010000;
  {$EXTERNALSYM BASE_SEARCH_PATH_PERMANENT}
  BASE_SEARCH_PATH_PERMANENT               = $00008000;

  { SetProcessDEPPolicy }
  {$EXTERNALSYM PROCESS_DEP_ENABLE}
  PROCESS_DEP_ENABLE                      = $00000001;
  {$EXTERNALSYM PROCESS_DEP_DISABLE_ATL_THUNK_EMULATION}
  PROCESS_DEP_DISABLE_ATL_THUNK_EMULATION = $00000002;

{ Windows 8 (or Windows 7 / Vista with KB2533623). Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED); AddDllDirectory returns nil. }
{$EXTERNALSYM SetDefaultDllDirectories}
function SetDefaultDllDirectories(DirectoryFlags: DWORD): BOOL; stdcall;
{$EXTERNALSYM AddDllDirectory}
function AddDllDirectory(NewDirectory: PWideChar): DLL_DIRECTORY_COOKIE; stdcall;
{$EXTERNALSYM RemoveDllDirectory}
function RemoveDllDirectory(Cookie: DLL_DIRECTORY_COOKIE): BOOL; stdcall;
{ Windows XP SP1. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED) / 0. }
{$EXTERNALSYM SetDllDirectory}
function SetDllDirectory(lpPathName: PChar): BOOL; stdcall;
{$EXTERNALSYM SetDllDirectoryA}
function SetDllDirectoryA(lpPathName: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM SetDllDirectoryW}
function SetDllDirectoryW(lpPathName: PWideChar): BOOL; stdcall;
{$EXTERNALSYM GetDllDirectory}
function GetDllDirectory(nBufferLength: DWORD; lpBuffer: PChar): DWORD; stdcall;
{$EXTERNALSYM GetDllDirectoryA}
function GetDllDirectoryA(nBufferLength: DWORD; lpBuffer: PAnsiChar): DWORD; stdcall;
{$EXTERNALSYM GetDllDirectoryW}
function GetDllDirectoryW(nBufferLength: DWORD; lpBuffer: PWideChar): DWORD; stdcall;
{ Windows 7 (Vista SP2 with KB959426). Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM SetSearchPathMode}
function SetSearchPathMode(Flags: DWORD): BOOL; stdcall;
{ Windows XP SP3. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM SetProcessDEPPolicy}
function SetProcessDEPPolicy(dwFlags: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetProcessDEPPolicy}
function GetProcessDEPPolicy(hProcess: THandle; out lpFlags: DWORD;
  out lpPermanent: BOOL): BOOL; stdcall;

type
  {$EXTERNALSYM HEAP_INFORMATION_CLASS}
  HEAP_INFORMATION_CLASS = Integer;

const
  {$EXTERNALSYM HeapCompatibilityInformation}
  HeapCompatibilityInformation      = 0;
  {$EXTERNALSYM HeapEnableTerminationOnCorruption}
  HeapEnableTerminationOnCorruption = 1;
  {$EXTERNALSYM HeapOptimizeResources}
  HeapOptimizeResources             = 3;

{ Windows XP (HeapEnableTerminationOnCorruption: Windows Vista; pass
  HeapHandle = 0, HeapInformation = nil, HeapInformationLength = 0).
  Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM HeapSetInformation}
function HeapSetInformation(HeapHandle: THandle; HeapInformationClass: HEAP_INFORMATION_CLASS;
  HeapInformation: Pointer; HeapInformationLength: Cardinal): BOOL; stdcall;

{ ====== Locale names (winnls.h, stringapiset.h) =========================== }

const
  {$EXTERNALSYM LOCALE_NAME_MAX_LENGTH}
  LOCALE_NAME_MAX_LENGTH     = 85;
  {$EXTERNALSYM LOCALE_NAME_USER_DEFAULT}
  LOCALE_NAME_USER_DEFAULT   = nil;
  {$EXTERNALSYM LOCALE_NAME_INVARIANT}
  LOCALE_NAME_INVARIANT: PWideChar = '';   { L"" - not nil! }
  {$EXTERNALSYM LOCALE_NAME_SYSTEM_DEFAULT}
  LOCALE_NAME_SYSTEM_DEFAULT: PWideChar = '!x-sys-default-locale';
  {$EXTERNALSYM LOCALE_ALLOW_NEUTRAL_NAMES}
  LOCALE_ALLOW_NEUTRAL_NAMES = $08000000;  // Flag to allow returning neutral names/lcids for name conversion
  {$EXTERNALSYM LOCALE_SNAME}
  LOCALE_SNAME               = $0000005C;  // locale name (ie: en-us)

  { CompareStringEx flags }
  {$EXTERNALSYM LINGUISTIC_IGNORECASE}
  LINGUISTIC_IGNORECASE      = $00000010;  // linguistically appropriate 'ignore case'
  {$EXTERNALSYM LINGUISTIC_IGNOREDIACRITIC}
  LINGUISTIC_IGNOREDIACRITIC = $00000020;  // linguistically appropriate 'ignore nonspace'
  {$EXTERNALSYM NORM_LINGUISTIC_CASING}
  NORM_LINGUISTIC_CASING     = $08000000;  // use linguistic rules for casing
  {$EXTERNALSYM SORT_DIGITSASNUMBERS}
  SORT_DIGITSASNUMBERS       = $00000008;  // use digits as numbers sort method (Windows 7)

{ Windows Vista. The name based NLS functions have no correct emulation on
  older systems (locale names differ from LCID based ISO codes for several
  locales): fallback 0 (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetUserDefaultLocaleName}
function GetUserDefaultLocaleName(lpLocaleName: PWideChar; cchLocaleName: Integer): Integer; stdcall;
{$EXTERNALSYM LocaleNameToLCID}
function LocaleNameToLCID(lpName: PWideChar; dwFlags: DWORD): LCID; stdcall;
{$EXTERNALSYM LCIDToLocaleName}
function LCIDToLocaleName(Locale: LCID; lpName: PWideChar; cchName: Integer;
  dwFlags: DWORD): Integer; stdcall;
{$EXTERNALSYM GetLocaleInfoEx}
function GetLocaleInfoEx(lpLocaleName: PWideChar; LCType: LCTYPE; lpLCData: PWideChar;
  cchData: Integer): Integer; stdcall;
{ Returns CSTR_LESS_THAN, CSTR_EQUAL, CSTR_GREATER_THAN or 0. }
{$EXTERNALSYM CompareStringEx}
function CompareStringEx(lpLocaleName: PWideChar; dwCmpFlags: DWORD; lpString1: PWideChar;
  cchCount1: Integer; lpString2: PWideChar; cchCount2: Integer;
  lpVersionInformation: Pointer; lpReserved: Pointer; lParam: LPARAM): Integer; stdcall;
{ Windows Vista. Fallback: exact emulation (ordinal UTF-16 comparison, case
  insensitive through the system uppercase table). cchCount = -1: null
  terminated. }
{$EXTERNALSYM CompareStringOrdinal}
function CompareStringOrdinal(lpString1: PWideChar; cchCount1: Integer; lpString2: PWideChar;
  cchCount2: Integer; bIgnoreCase: BOOL): Integer; stdcall;

{ ====== Window helpers (winuser.h) ======================================== }

const
  { User Interface Privilege Isolation message filter }
  {$EXTERNALSYM MSGFLT_ADD}
  MSGFLT_ADD = 1;
  {$EXTERNALSYM MSGFLT_REMOVE}
  MSGFLT_REMOVE = 2;
  {$EXTERNALSYM MSGFLTINFO_NONE}
  MSGFLTINFO_NONE                     = 0;
  {$EXTERNALSYM MSGFLTINFO_ALREADYALLOWED_FORWND}
  MSGFLTINFO_ALREADYALLOWED_FORWND    = 1;
  {$EXTERNALSYM MSGFLTINFO_ALREADYDISALLOWED_FORWND}
  MSGFLTINFO_ALREADYDISALLOWED_FORWND = 2;
  {$EXTERNALSYM MSGFLTINFO_ALLOWED_HIGHER}
  MSGFLTINFO_ALLOWED_HIGHER           = 3;
  {$EXTERNALSYM MSGFLT_RESET}
  MSGFLT_RESET    = 0;
  {$EXTERNALSYM MSGFLT_ALLOW}
  MSGFLT_ALLOW    = 1;
  {$EXTERNALSYM MSGFLT_DISALLOW}
  MSGFLT_DISALLOW = 2;

type
  {$EXTERNALSYM tagCHANGEFILTERSTRUCT}
  tagCHANGEFILTERSTRUCT = record
    cbSize: DWORD;
    ExtStatus: DWORD;
  end;
  {$EXTERNALSYM CHANGEFILTERSTRUCT}
  CHANGEFILTERSTRUCT = tagCHANGEFILTERSTRUCT;
  {$EXTERNALSYM PCHANGEFILTERSTRUCT}
  PCHANGEFILTERSTRUCT = ^tagCHANGEFILTERSTRUCT;
  TChangeFilterStruct = tagCHANGEFILTERSTRUCT;

{ Windows Vista. Fallback: True - systems without these functions have no
  User Interface Privilege Isolation, so every message is already allowed. }
{$EXTERNALSYM ChangeWindowMessageFilter}
function ChangeWindowMessageFilter(message: UINT; dwFlag: DWORD): BOOL; stdcall;
{ Windows 7. Fallback: Windows Vista: ChangeWindowMessageFilter (process
  wide; MSGFLT_RESET does nothing); Windows XP: True as above. ExtStatus is
  set to MSGFLTINFO_NONE by the fallbacks. }
{$EXTERNALSYM ChangeWindowMessageFilterEx}
function ChangeWindowMessageFilterEx(hwnd: HWND; message: UINT; action: DWORD;
  pChangeFilterStruct: PCHANGEFILTERSTRUCT): BOOL; stdcall;

{ Windows Vista. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM ShutdownBlockReasonCreate}
function ShutdownBlockReasonCreate(hWnd: HWND; pwszReason: PWideChar): BOOL; stdcall;
{$EXTERNALSYM ShutdownBlockReasonQuery}
function ShutdownBlockReasonQuery(hWnd: HWND; pwszBuff: PWideChar;
  var pcchBuff: DWORD): BOOL; stdcall;
{$EXTERNALSYM ShutdownBlockReasonDestroy}
function ShutdownBlockReasonDestroy(hWnd: HWND): BOOL; stdcall;

{ Windows Vista (WM_CLIPBOARDUPDATE). Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM AddClipboardFormatListener}
function AddClipboardFormatListener(hwnd: HWND): BOOL; stdcall;
{$EXTERNALSYM RemoveClipboardFormatListener}
function RemoveClipboardFormatListener(hwnd: HWND): BOOL; stdcall;

const
  {$EXTERNALSYM WDA_NONE}
  WDA_NONE               = $00000000;
  {$EXTERNALSYM WDA_MONITOR}
  WDA_MONITOR            = $00000001;
  {$EXTERNALSYM WDA_EXCLUDEFROMCAPTURE}
  WDA_EXCLUDEFROMCAPTURE = $00000011;  // Windows 10 2004

{ Windows 7. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM SetWindowDisplayAffinity}
function SetWindowDisplayAffinity(hWnd: HWND; dwAffinity: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetWindowDisplayAffinity}
function GetWindowDisplayAffinity(hWnd: HWND; out pdwAffinity: DWORD): BOOL; stdcall;

const
  {$EXTERNALSYM TPM_WORKAREA}
  TPM_WORKAREA = $10000;  // Windows 7: restrict to the work area

{ Windows 7. excludeRect may be nil. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM CalculatePopupWindowPosition}
function CalculatePopupWindowPosition(const anchorPoint: TPoint; const windowSize: TSize;
  flags: UINT; excludeRect: PRect; out popupWindowPosition: TRect): BOOL; stdcall;

{ LogicalToPhysicalPoint, PhysicalToLogicalPoint and all other DPI
  functions are declared in ShellScaling.pas. }

const
  {$EXTERNALSYM GWLP_WNDPROC}
  GWLP_WNDPROC       = -4;
  {$EXTERNALSYM GWLP_HINSTANCE}
  GWLP_HINSTANCE     = -6;
  {$EXTERNALSYM GWLP_HWNDPARENT}
  GWLP_HWNDPARENT    = -8;
  {$EXTERNALSYM GWLP_USERDATA}
  GWLP_USERDATA      = -21;
  {$EXTERNALSYM GWLP_ID}
  GWLP_ID            = -12;
  {$EXTERNALSYM GCLP_MENUNAME}
  GCLP_MENUNAME      = -8;
  {$EXTERNALSYM GCLP_HBRBACKGROUND}
  GCLP_HBRBACKGROUND = -10;
  {$EXTERNALSYM GCLP_HCURSOR}
  GCLP_HCURSOR       = -12;
  {$EXTERNALSYM GCLP_HICON}
  GCLP_HICON         = -14;
  {$EXTERNALSYM GCLP_HMODULE}
  GCLP_HMODULE       = -16;
  {$EXTERNALSYM GCLP_WNDPROC}
  GCLP_WNDPROC       = -24;
  {$EXTERNALSYM GCLP_HICONSM}
  GCLP_HICONSM       = -34;
  {$EXTERNALSYM DWLP_MSGRESULT}
  DWLP_MSGRESULT     = 0;   // x86 values
  {$EXTERNALSYM DWLP_DLGPROC}
  DWLP_DLGPROC       = 4;
  {$EXTERNALSYM DWLP_USER}
  DWLP_USER          = 8;

{ 32-bit Windows has no *LongPtr exports (they are macros in the SDK): these
  map to GetWindowLongA/W etc. (static imports present in every version). }
{$EXTERNALSYM GetWindowLongPtr}
function GetWindowLongPtr(hWnd: HWND; nIndex: Integer): LONG_PTR; stdcall;
{$EXTERNALSYM GetWindowLongPtrA}
function GetWindowLongPtrA(hWnd: HWND; nIndex: Integer): LONG_PTR; stdcall;
{$EXTERNALSYM GetWindowLongPtrW}
function GetWindowLongPtrW(hWnd: HWND; nIndex: Integer): LONG_PTR; stdcall;
{$EXTERNALSYM SetWindowLongPtr}
function SetWindowLongPtr(hWnd: HWND; nIndex: Integer; dwNewLong: LONG_PTR): LONG_PTR; stdcall;
{$EXTERNALSYM SetWindowLongPtrA}
function SetWindowLongPtrA(hWnd: HWND; nIndex: Integer; dwNewLong: LONG_PTR): LONG_PTR; stdcall;
{$EXTERNALSYM SetWindowLongPtrW}
function SetWindowLongPtrW(hWnd: HWND; nIndex: Integer; dwNewLong: LONG_PTR): LONG_PTR; stdcall;
{$EXTERNALSYM GetClassLongPtr}
function GetClassLongPtr(hWnd: HWND; nIndex: Integer): ULONG_PTR; stdcall;
{$EXTERNALSYM GetClassLongPtrA}
function GetClassLongPtrA(hWnd: HWND; nIndex: Integer): ULONG_PTR; stdcall;
{$EXTERNALSYM GetClassLongPtrW}
function GetClassLongPtrW(hWnd: HWND; nIndex: Integer): ULONG_PTR; stdcall;
{$EXTERNALSYM SetClassLongPtr}
function SetClassLongPtr(hWnd: HWND; nIndex: Integer; dwNewLong: LONG_PTR): ULONG_PTR; stdcall;
{$EXTERNALSYM SetClassLongPtrA}
function SetClassLongPtrA(hWnd: HWND; nIndex: Integer; dwNewLong: LONG_PTR): ULONG_PTR; stdcall;
{$EXTERNALSYM SetClassLongPtrW}
function SetClassLongPtrW(hWnd: HWND; nIndex: Integer; dwNewLong: LONG_PTR): ULONG_PTR; stdcall;

{ ====== Touch input (Windows 7) =========================================== }

type
  {$EXTERNALSYM HTOUCHINPUT}
  HTOUCHINPUT = THandle;

  {$EXTERNALSYM tagTOUCHINPUT}
  tagTOUCHINPUT = record
    x: Longint;
    y: Longint;
    hSource: THandle;
    dwID: DWORD;
    dwFlags: DWORD;
    dwMask: DWORD;
    dwTime: DWORD;
    dwExtraInfo: ULONG_PTR;
    cxContact: DWORD;
    cyContact: DWORD;
  end;
  {$EXTERNALSYM TOUCHINPUT}
  TOUCHINPUT = tagTOUCHINPUT;
  {$EXTERNALSYM PTOUCHINPUT}
  PTOUCHINPUT = ^tagTOUCHINPUT;
  TTouchInput = tagTOUCHINPUT;

const
  { TOUCHINPUT.dwFlags }
  {$EXTERNALSYM TOUCHEVENTF_MOVE}
  TOUCHEVENTF_MOVE       = $0001;
  {$EXTERNALSYM TOUCHEVENTF_DOWN}
  TOUCHEVENTF_DOWN       = $0002;
  {$EXTERNALSYM TOUCHEVENTF_UP}
  TOUCHEVENTF_UP         = $0004;
  {$EXTERNALSYM TOUCHEVENTF_INRANGE}
  TOUCHEVENTF_INRANGE    = $0008;
  {$EXTERNALSYM TOUCHEVENTF_PRIMARY}
  TOUCHEVENTF_PRIMARY    = $0010;
  {$EXTERNALSYM TOUCHEVENTF_NOCOALESCE}
  TOUCHEVENTF_NOCOALESCE = $0020;
  {$EXTERNALSYM TOUCHEVENTF_PEN}
  TOUCHEVENTF_PEN        = $0040;
  {$EXTERNALSYM TOUCHEVENTF_PALM}
  TOUCHEVENTF_PALM       = $0080;

  { TOUCHINPUT.dwMask }
  {$EXTERNALSYM TOUCHINPUTMASKF_TIMEFROMSYSTEM}
  TOUCHINPUTMASKF_TIMEFROMSYSTEM = $0001;  // the dwTime field contains a system generated value
  {$EXTERNALSYM TOUCHINPUTMASKF_EXTRAINFO}
  TOUCHINPUTMASKF_EXTRAINFO      = $0002;  // the dwExtraInfo field is valid
  {$EXTERNALSYM TOUCHINPUTMASKF_CONTACTAREA}
  TOUCHINPUTMASKF_CONTACTAREA    = $0004;  // the cxContact and cyContact fields are valid

  { RegisterTouchWindow flags }
  {$EXTERNALSYM TWF_FINETOUCH}
  TWF_FINETOUCH = $00000001;
  {$EXTERNALSYM TWF_WANTPALM}
  TWF_WANTPALM  = $00000002;

{ Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM RegisterTouchWindow}
function RegisterTouchWindow(hwnd: HWND; ulFlags: ULONG): BOOL; stdcall;
{$EXTERNALSYM UnregisterTouchWindow}
function UnregisterTouchWindow(hwnd: HWND): BOOL; stdcall;
{ pulFlags may be nil. }
{$EXTERNALSYM IsTouchWindow}
function IsTouchWindow(hwnd: HWND; pulFlags: PULONG): BOOL; stdcall;
{ pInputs: array of cInputs TTouchInput; cbSize = SizeOf(TTouchInput). }
{$EXTERNALSYM GetTouchInputInfo}
function GetTouchInputInfo(hTouchInput: HTOUCHINPUT; cInputs: UINT; pInputs: PTOUCHINPUT;
  cbSize: Integer): BOOL; stdcall;
{$EXTERNALSYM CloseTouchInputHandle}
function CloseTouchInputHandle(hTouchInput: HTOUCHINPUT): BOOL; stdcall;
{ Macro of the SDK: touch coordinates are in hundredths of a pixel. }
{$EXTERNALSYM TOUCH_COORD_TO_PIXEL}
function TOUCH_COORD_TO_PIXEL(l: Longint): Longint;

{ ====== Gestures (Windows 7) ============================================== }

type
  {$EXTERNALSYM HGESTUREINFO}
  HGESTUREINFO = THandle;

  { Natural alignment: ullArguments is at offset 32, 48 bytes on x86. }
  {$EXTERNALSYM tagGESTUREINFO}
  tagGESTUREINFO = record
    cbSize: UINT;               // size, in bytes, of this structure (including variable length Args field)
    dwFlags: DWORD;             // see GF_* flags
    dwID: DWORD;                // gesture ID, see GID_* defines
    hwndTarget: HWND;           // handle to window targeted by this gesture
    ptsLocation: TSmallPoint;   // current location of this gesture (POINTS)
    dwInstanceID: DWORD;        // internally used
    dwSequenceID: DWORD;        // internally used
    ullArguments: Int64;        // arguments for gestures whose arguments fit in 8 BYTES (ULONGLONG)
    cbExtraArgs: UINT;          // size, in bytes, of extra arguments, if any, that accompany this gesture
  end;
  {$EXTERNALSYM GESTUREINFO}
  GESTUREINFO = tagGESTUREINFO;
  {$EXTERNALSYM PGESTUREINFO}
  PGESTUREINFO = ^tagGESTUREINFO;
  TGestureInfo = tagGESTUREINFO;

  {$EXTERNALSYM tagGESTURENOTIFYSTRUCT}
  tagGESTURENOTIFYSTRUCT = record
    cbSize: UINT;               // size, in bytes, of this structure
    dwFlags: DWORD;             // unused
    hwndTarget: HWND;           // handle to window targeted by the gesture
    ptsLocation: TSmallPoint;   // starting location (POINTS)
    dwInstanceID: DWORD;        // internally used
  end;
  {$EXTERNALSYM GESTURENOTIFYSTRUCT}
  GESTURENOTIFYSTRUCT = tagGESTURENOTIFYSTRUCT;
  {$EXTERNALSYM PGESTURENOTIFYSTRUCT}
  PGESTURENOTIFYSTRUCT = ^tagGESTURENOTIFYSTRUCT;
  TGestureNotifyStruct = tagGESTURENOTIFYSTRUCT;

  {$EXTERNALSYM tagGESTURECONFIG}
  tagGESTURECONFIG = record
    dwID: DWORD;                // gesture ID
    dwWant: DWORD;              // settings related to gesture ID that are to be turned on
    dwBlock: DWORD;             // settings related to gesture ID that are to be turned off
  end;
  {$EXTERNALSYM GESTURECONFIG}
  GESTURECONFIG = tagGESTURECONFIG;
  {$EXTERNALSYM PGESTURECONFIG}
  PGESTURECONFIG = ^tagGESTURECONFIG;
  TGestureConfig = tagGESTURECONFIG;

const
  { GESTUREINFO.dwFlags }
  {$EXTERNALSYM GF_BEGIN}
  GF_BEGIN   = $00000001;
  {$EXTERNALSYM GF_INERTIA}
  GF_INERTIA = $00000002;
  {$EXTERNALSYM GF_END}
  GF_END     = $00000004;

  { Gesture IDs }
  {$EXTERNALSYM GID_BEGIN}
  GID_BEGIN        = 1;
  {$EXTERNALSYM GID_END}
  GID_END          = 2;
  {$EXTERNALSYM GID_ZOOM}
  GID_ZOOM         = 3;
  {$EXTERNALSYM GID_PAN}
  GID_PAN          = 4;
  {$EXTERNALSYM GID_ROTATE}
  GID_ROTATE       = 5;
  {$EXTERNALSYM GID_TWOFINGERTAP}
  GID_TWOFINGERTAP = 6;
  {$EXTERNALSYM GID_PRESSANDTAP}
  GID_PRESSANDTAP  = 7;
  {$EXTERNALSYM GID_ROLLOVER}
  GID_ROLLOVER     = GID_PRESSANDTAP;

  { GESTURECONFIG.dwWant / dwBlock }
  {$EXTERNALSYM GC_ALLGESTURES}
  GC_ALLGESTURES                         = $00000001;
  {$EXTERNALSYM GC_ZOOM}
  GC_ZOOM                                = $00000001;
  {$EXTERNALSYM GC_PAN}
  GC_PAN                                 = $00000001;
  {$EXTERNALSYM GC_PAN_WITH_SINGLE_FINGER_VERTICALLY}
  GC_PAN_WITH_SINGLE_FINGER_VERTICALLY   = $00000002;
  {$EXTERNALSYM GC_PAN_WITH_SINGLE_FINGER_HORIZONTALLY}
  GC_PAN_WITH_SINGLE_FINGER_HORIZONTALLY = $00000004;
  {$EXTERNALSYM GC_PAN_WITH_GUTTER}
  GC_PAN_WITH_GUTTER                     = $00000008;
  {$EXTERNALSYM GC_PAN_WITH_INERTIA}
  GC_PAN_WITH_INERTIA                    = $00000010;
  {$EXTERNALSYM GC_ROTATE}
  GC_ROTATE                              = $00000001;
  {$EXTERNALSYM GC_TWOFINGERTAP}
  GC_TWOFINGERTAP                        = $00000001;
  {$EXTERNALSYM GC_PRESSANDTAP}
  GC_PRESSANDTAP                         = $00000001;
  {$EXTERNALSYM GC_ROLLOVER}
  GC_ROLLOVER                            = GC_PRESSANDTAP;

  {$EXTERNALSYM GESTURECONFIGMAXCOUNT}
  GESTURECONFIGMAXCOUNT = 256;  // Maximum number of gestures that can be included in a single call to SetGestureConfig / GetGestureConfig
  {$EXTERNALSYM GCF_INCLUDE_ANCESTORS}
  GCF_INCLUDE_ANCESTORS = $00000001;

{ Set pGestureInfo.cbSize := SizeOf(TGestureInfo) first.
  Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetGestureInfo}
function GetGestureInfo(hGestureInfo: HGESTUREINFO; var pGestureInfo: TGestureInfo): BOOL; stdcall;
{$EXTERNALSYM GetGestureExtraArgs}
function GetGestureExtraArgs(hGestureInfo: HGESTUREINFO; cbExtraArgs: UINT;
  pExtraArgs: PByte): BOOL; stdcall;
{$EXTERNALSYM CloseGestureInfoHandle}
function CloseGestureInfoHandle(hGestureInfo: HGESTUREINFO): BOOL; stdcall;
{ pGestureConfig: array of cIDs TGestureConfig; cbSize = SizeOf(TGestureConfig). }
{$EXTERNALSYM SetGestureConfig}
function SetGestureConfig(hwnd: HWND; dwReserved: DWORD; cIDs: UINT;
  pGestureConfig: PGESTURECONFIG; cbSize: UINT): BOOL; stdcall;
{$EXTERNALSYM GetGestureConfig}
function GetGestureConfig(hwnd: HWND; dwReserved: DWORD; dwFlags: DWORD; pcIDs: PUINT;
  pGestureConfig: PGESTURECONFIG; cbSize: UINT): BOOL; stdcall;
{ Macros of the SDK (rotation angle in radians <-> GESTUREINFO.ullArguments) }
{$EXTERNALSYM GID_ROTATE_ANGLE_TO_ARGUMENT}
function GID_ROTATE_ANGLE_TO_ARGUMENT(Angle: Double): Word;
{$EXTERNALSYM GID_ROTATE_ANGLE_FROM_ARGUMENT}
function GID_ROTATE_ANGLE_FROM_ARGUMENT(Argument: Word): Double;

{ ====== Pointer input (Windows 8) ========================================= }

type
  {$EXTERNALSYM POINTER_INPUT_TYPE}
  POINTER_INPUT_TYPE = DWORD;
  {$EXTERNALSYM POINTER_FLAGS}
  POINTER_FLAGS = Cardinal;
  {$EXTERNALSYM POINTER_BUTTON_CHANGE_TYPE}
  POINTER_BUTTON_CHANGE_TYPE = Integer;
  {$EXTERNALSYM TOUCH_FLAGS}
  TOUCH_FLAGS = Cardinal;
  {$EXTERNALSYM TOUCH_MASK}
  TOUCH_MASK = Cardinal;
  {$EXTERNALSYM PEN_FLAGS}
  PEN_FLAGS = Cardinal;
  {$EXTERNALSYM PEN_MASK}
  PEN_MASK = Cardinal;

const
  { POINTER_INPUT_TYPE }
  {$EXTERNALSYM PT_POINTER}
  PT_POINTER  = 1;  // Generic pointer
  {$EXTERNALSYM PT_TOUCH}
  PT_TOUCH    = 2;  // Touch
  {$EXTERNALSYM PT_PEN}
  PT_PEN      = 3;  // Pen
  {$EXTERNALSYM PT_MOUSE}
  PT_MOUSE    = 4;  // Mouse
  {$EXTERNALSYM PT_TOUCHPAD}
  PT_TOUCHPAD = 5;  // Touchpad (Windows 8.1)

  { POINTER_INFO.pointerFlags }
  {$EXTERNALSYM POINTER_FLAG_NONE}
  POINTER_FLAG_NONE           = $00000000;  // Default
  {$EXTERNALSYM POINTER_FLAG_NEW}
  POINTER_FLAG_NEW            = $00000001;  // New pointer
  {$EXTERNALSYM POINTER_FLAG_INRANGE}
  POINTER_FLAG_INRANGE        = $00000002;  // Pointer has not departed
  {$EXTERNALSYM POINTER_FLAG_INCONTACT}
  POINTER_FLAG_INCONTACT      = $00000004;  // Pointer is in contact
  {$EXTERNALSYM POINTER_FLAG_FIRSTBUTTON}
  POINTER_FLAG_FIRSTBUTTON    = $00000010;  // Primary action
  {$EXTERNALSYM POINTER_FLAG_SECONDBUTTON}
  POINTER_FLAG_SECONDBUTTON   = $00000020;  // Secondary action
  {$EXTERNALSYM POINTER_FLAG_THIRDBUTTON}
  POINTER_FLAG_THIRDBUTTON    = $00000040;  // Third button
  {$EXTERNALSYM POINTER_FLAG_FOURTHBUTTON}
  POINTER_FLAG_FOURTHBUTTON   = $00000080;  // Fourth button
  {$EXTERNALSYM POINTER_FLAG_FIFTHBUTTON}
  POINTER_FLAG_FIFTHBUTTON    = $00000100;  // Fifth button
  {$EXTERNALSYM POINTER_FLAG_PRIMARY}
  POINTER_FLAG_PRIMARY        = $00002000;  // Pointer is primary for system
  {$EXTERNALSYM POINTER_FLAG_CONFIDENCE}
  POINTER_FLAG_CONFIDENCE     = $00004000;  // Pointer is considered unlikely to be accidental
  {$EXTERNALSYM POINTER_FLAG_CANCELED}
  POINTER_FLAG_CANCELED       = $00008000;  // Pointer is departing in an abnormal manner
  {$EXTERNALSYM POINTER_FLAG_DOWN}
  POINTER_FLAG_DOWN           = $00010000;  // Pointer transitioned to down state (made contact)
  {$EXTERNALSYM POINTER_FLAG_UPDATE}
  POINTER_FLAG_UPDATE         = $00020000;  // Pointer update
  {$EXTERNALSYM POINTER_FLAG_UP}
  POINTER_FLAG_UP             = $00040000;  // Pointer transitioned from down state (broke contact)
  {$EXTERNALSYM POINTER_FLAG_WHEEL}
  POINTER_FLAG_WHEEL          = $00080000;  // Vertical wheel
  {$EXTERNALSYM POINTER_FLAG_HWHEEL}
  POINTER_FLAG_HWHEEL         = $00100000;  // Horizontal wheel
  {$EXTERNALSYM POINTER_FLAG_CAPTURECHANGED}
  POINTER_FLAG_CAPTURECHANGED = $00200000;  // Lost capture
  {$EXTERNALSYM POINTER_FLAG_HASTRANSFORM}
  POINTER_FLAG_HASTRANSFORM   = $00400000;  // Input has a transform associated with it

  { POINTER_INFO.dwKeyStates }
  {$EXTERNALSYM POINTER_MOD_SHIFT}
  POINTER_MOD_SHIFT = $0004;  // Shift key is held down.
  {$EXTERNALSYM POINTER_MOD_CTRL}
  POINTER_MOD_CTRL  = $0008;  // Ctrl key is held down.

  { POINTER_BUTTON_CHANGE_TYPE }
  {$EXTERNALSYM POINTER_CHANGE_NONE}
  POINTER_CHANGE_NONE              = 0;
  {$EXTERNALSYM POINTER_CHANGE_FIRSTBUTTON_DOWN}
  POINTER_CHANGE_FIRSTBUTTON_DOWN  = 1;
  {$EXTERNALSYM POINTER_CHANGE_FIRSTBUTTON_UP}
  POINTER_CHANGE_FIRSTBUTTON_UP    = 2;
  {$EXTERNALSYM POINTER_CHANGE_SECONDBUTTON_DOWN}
  POINTER_CHANGE_SECONDBUTTON_DOWN = 3;
  {$EXTERNALSYM POINTER_CHANGE_SECONDBUTTON_UP}
  POINTER_CHANGE_SECONDBUTTON_UP   = 4;
  {$EXTERNALSYM POINTER_CHANGE_THIRDBUTTON_DOWN}
  POINTER_CHANGE_THIRDBUTTON_DOWN  = 5;
  {$EXTERNALSYM POINTER_CHANGE_THIRDBUTTON_UP}
  POINTER_CHANGE_THIRDBUTTON_UP    = 6;
  {$EXTERNALSYM POINTER_CHANGE_FOURTHBUTTON_DOWN}
  POINTER_CHANGE_FOURTHBUTTON_DOWN = 7;
  {$EXTERNALSYM POINTER_CHANGE_FOURTHBUTTON_UP}
  POINTER_CHANGE_FOURTHBUTTON_UP   = 8;
  {$EXTERNALSYM POINTER_CHANGE_FIFTHBUTTON_DOWN}
  POINTER_CHANGE_FIFTHBUTTON_DOWN  = 9;
  {$EXTERNALSYM POINTER_CHANGE_FIFTHBUTTON_UP}
  POINTER_CHANGE_FIFTHBUTTON_UP    = 10;

  { POINTER_TOUCH_INFO }
  {$EXTERNALSYM TOUCH_FLAG_NONE}
  TOUCH_FLAG_NONE        = $00000000;  // Default
  {$EXTERNALSYM TOUCH_MASK_NONE}
  TOUCH_MASK_NONE        = $00000000;  // Default - none of the optional fields are valid
  {$EXTERNALSYM TOUCH_MASK_CONTACTAREA}
  TOUCH_MASK_CONTACTAREA = $00000001;  // The rcContact field is valid
  {$EXTERNALSYM TOUCH_MASK_ORIENTATION}
  TOUCH_MASK_ORIENTATION = $00000002;  // The orientation field is valid
  {$EXTERNALSYM TOUCH_MASK_PRESSURE}
  TOUCH_MASK_PRESSURE    = $00000004;  // The pressure field is valid

  { POINTER_PEN_INFO }
  {$EXTERNALSYM PEN_FLAG_NONE}
  PEN_FLAG_NONE     = $00000000;  // Default
  {$EXTERNALSYM PEN_FLAG_BARREL}
  PEN_FLAG_BARREL   = $00000001;  // The barrel button is pressed
  {$EXTERNALSYM PEN_FLAG_INVERTED}
  PEN_FLAG_INVERTED = $00000002;  // The pen is inverted
  {$EXTERNALSYM PEN_FLAG_ERASER}
  PEN_FLAG_ERASER   = $00000004;  // The eraser button is pressed
  {$EXTERNALSYM PEN_MASK_NONE}
  PEN_MASK_NONE     = $00000000;  // Default - none of the optional fields are valid
  {$EXTERNALSYM PEN_MASK_PRESSURE}
  PEN_MASK_PRESSURE = $00000001;  // The pressure field is valid
  {$EXTERNALSYM PEN_MASK_ROTATION}
  PEN_MASK_ROTATION = $00000002;  // The rotation field is valid
  {$EXTERNALSYM PEN_MASK_TILT_X}
  PEN_MASK_TILT_X   = $00000004;  // The tiltX field is valid
  {$EXTERNALSYM PEN_MASK_TILT_Y}
  PEN_MASK_TILT_Y   = $00000008;  // The tiltY field is valid

  { HIWORD(wParam) flags of the WM_POINTER* messages }
  {$EXTERNALSYM POINTER_MESSAGE_FLAG_NEW}
  POINTER_MESSAGE_FLAG_NEW          = $00000001;  // New pointer
  {$EXTERNALSYM POINTER_MESSAGE_FLAG_INRANGE}
  POINTER_MESSAGE_FLAG_INRANGE      = $00000002;  // Pointer has not departed
  {$EXTERNALSYM POINTER_MESSAGE_FLAG_INCONTACT}
  POINTER_MESSAGE_FLAG_INCONTACT    = $00000004;  // Pointer is in contact
  {$EXTERNALSYM POINTER_MESSAGE_FLAG_FIRSTBUTTON}
  POINTER_MESSAGE_FLAG_FIRSTBUTTON  = $00000010;  // Primary action
  {$EXTERNALSYM POINTER_MESSAGE_FLAG_SECONDBUTTON}
  POINTER_MESSAGE_FLAG_SECONDBUTTON = $00000020;  // Secondary action
  {$EXTERNALSYM POINTER_MESSAGE_FLAG_THIRDBUTTON}
  POINTER_MESSAGE_FLAG_THIRDBUTTON  = $00000040;  // Third button
  {$EXTERNALSYM POINTER_MESSAGE_FLAG_FOURTHBUTTON}
  POINTER_MESSAGE_FLAG_FOURTHBUTTON = $00000080;  // Fourth button
  {$EXTERNALSYM POINTER_MESSAGE_FLAG_FIFTHBUTTON}
  POINTER_MESSAGE_FLAG_FIFTHBUTTON  = $00000100;  // Fifth button
  {$EXTERNALSYM POINTER_MESSAGE_FLAG_PRIMARY}
  POINTER_MESSAGE_FLAG_PRIMARY      = $00002000;  // Pointer is primary
  {$EXTERNALSYM POINTER_MESSAGE_FLAG_CONFIDENCE}
  POINTER_MESSAGE_FLAG_CONFIDENCE   = $00004000;  // Pointer is considered unlikely to be accidental
  {$EXTERNALSYM POINTER_MESSAGE_FLAG_CANCELED}
  POINTER_MESSAGE_FLAG_CANCELED     = $00008000;  // Pointer is departing in an abnormal manner

type
  { Natural alignment: PerformanceCount is at offset 72, 88 bytes on x86
    (96 bytes on x64). }
  {$EXTERNALSYM tagPOINTER_INFO}
  tagPOINTER_INFO = record
    pointerType: POINTER_INPUT_TYPE;
    pointerId: Cardinal;
    frameId: Cardinal;
    pointerFlags: POINTER_FLAGS;
    sourceDevice: THandle;
    hwndTarget: HWND;
    ptPixelLocation: TPoint;
    ptHimetricLocation: TPoint;
    ptPixelLocationRaw: TPoint;
    ptHimetricLocationRaw: TPoint;
    dwTime: DWORD;
    historyCount: Cardinal;
    InputData: Integer;
    dwKeyStates: DWORD;
    PerformanceCount: Int64;    // UINT64
    ButtonChangeType: POINTER_BUTTON_CHANGE_TYPE;
  end;
  {$EXTERNALSYM POINTER_INFO}
  POINTER_INFO = tagPOINTER_INFO;
  {$EXTERNALSYM PPOINTER_INFO}
  PPOINTER_INFO = ^tagPOINTER_INFO;
  TPointerInfo = tagPOINTER_INFO;
  PPointerInfo = PPOINTER_INFO;

  {$EXTERNALSYM tagPOINTER_TOUCH_INFO}
  tagPOINTER_TOUCH_INFO = record
    pointerInfo: POINTER_INFO;
    touchFlags: TOUCH_FLAGS;
    touchMask: TOUCH_MASK;
    rcContact: TRect;
    rcContactRaw: TRect;
    orientation: Cardinal;
    pressure: Cardinal;
  end;
  {$EXTERNALSYM POINTER_TOUCH_INFO}
  POINTER_TOUCH_INFO = tagPOINTER_TOUCH_INFO;
  {$EXTERNALSYM PPOINTER_TOUCH_INFO}
  PPOINTER_TOUCH_INFO = ^tagPOINTER_TOUCH_INFO;
  TPointerTouchInfo = tagPOINTER_TOUCH_INFO;
  PPointerTouchInfo = PPOINTER_TOUCH_INFO;

  {$EXTERNALSYM tagPOINTER_PEN_INFO}
  tagPOINTER_PEN_INFO = record
    pointerInfo: POINTER_INFO;
    penFlags: PEN_FLAGS;
    penMask: PEN_MASK;
    pressure: Cardinal;
    rotation: Cardinal;
    tiltX: Integer;
    tiltY: Integer;
  end;
  {$EXTERNALSYM POINTER_PEN_INFO}
  POINTER_PEN_INFO = tagPOINTER_PEN_INFO;
  {$EXTERNALSYM PPOINTER_PEN_INFO}
  PPOINTER_PEN_INFO = ^tagPOINTER_PEN_INFO;
  TPointerPenInfo = tagPOINTER_PEN_INFO;
  PPointerPenInfo = PPOINTER_PEN_INFO;

{ Windows 8. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM EnableMouseInPointer}
function EnableMouseInPointer(fEnable: BOOL): BOOL; stdcall;
{ Fallback: False (mouse-in-pointer mode does not exist). }
{$EXTERNALSYM IsMouseInPointerEnabled}
function IsMouseInPointerEnabled: BOOL; stdcall;
{$EXTERNALSYM GetPointerType}
function GetPointerType(pointerId: Cardinal; out pointerType: POINTER_INPUT_TYPE): BOOL; stdcall;
{$EXTERNALSYM GetPointerInfo}
function GetPointerInfo(pointerId: Cardinal; out pointerInfo: TPointerInfo): BOOL; stdcall;
{$EXTERNALSYM GetPointerTouchInfo}
function GetPointerTouchInfo(pointerId: Cardinal; out touchInfo: TPointerTouchInfo): BOOL; stdcall;
{$EXTERNALSYM GetPointerPenInfo}
function GetPointerPenInfo(pointerId: Cardinal; out penInfo: TPointerPenInfo): BOOL; stdcall;

{ Macros of the SDK for the wParam of the WM_POINTER* messages }
{$EXTERNALSYM GET_POINTERID_WPARAM}
function GET_POINTERID_WPARAM(wParam: WPARAM): Word;
{$EXTERNALSYM IS_POINTER_FLAG_SET_WPARAM}
function IS_POINTER_FLAG_SET_WPARAM(wParam: WPARAM; Flag: DWORD): Boolean;
{$EXTERNALSYM IS_POINTER_NEW_WPARAM}
function IS_POINTER_NEW_WPARAM(wParam: WPARAM): Boolean;
{$EXTERNALSYM IS_POINTER_INRANGE_WPARAM}
function IS_POINTER_INRANGE_WPARAM(wParam: WPARAM): Boolean;
{$EXTERNALSYM IS_POINTER_INCONTACT_WPARAM}
function IS_POINTER_INCONTACT_WPARAM(wParam: WPARAM): Boolean;
{$EXTERNALSYM IS_POINTER_FIRSTBUTTON_WPARAM}
function IS_POINTER_FIRSTBUTTON_WPARAM(wParam: WPARAM): Boolean;
{$EXTERNALSYM IS_POINTER_SECONDBUTTON_WPARAM}
function IS_POINTER_SECONDBUTTON_WPARAM(wParam: WPARAM): Boolean;
{$EXTERNALSYM IS_POINTER_THIRDBUTTON_WPARAM}
function IS_POINTER_THIRDBUTTON_WPARAM(wParam: WPARAM): Boolean;
{$EXTERNALSYM IS_POINTER_FOURTHBUTTON_WPARAM}
function IS_POINTER_FOURTHBUTTON_WPARAM(wParam: WPARAM): Boolean;
{$EXTERNALSYM IS_POINTER_FIFTHBUTTON_WPARAM}
function IS_POINTER_FIFTHBUTTON_WPARAM(wParam: WPARAM): Boolean;
{$EXTERNALSYM IS_POINTER_PRIMARY_WPARAM}
function IS_POINTER_PRIMARY_WPARAM(wParam: WPARAM): Boolean;
{$EXTERNALSYM HAS_POINTER_CONFIDENCE_WPARAM}
function HAS_POINTER_CONFIDENCE_WPARAM(wParam: WPARAM): Boolean;
{$EXTERNALSYM IS_POINTER_CANCELED_WPARAM}
function IS_POINTER_CANCELED_WPARAM(wParam: WPARAM): Boolean;

{ ====== Common types ====================================================== }

type
  { Locally unique identifier: two 32-bit halves, so 4-byte aligned like the
    SDK's LUID (Windows.pas stores LUIDs as TLargeInteger). }
  PLUID = ^TLUID;
  {$EXTERNALSYM _LUID}
  _LUID = record
    LowPart: DWORD;
    HighPart: Longint;
  end;
  {$EXTERNALSYM LUID}
  LUID = _LUID;
  TLUID = _LUID;

  PExceptionPointers = ^TExceptionPointers;
  {$EXTERNALSYM PEXCEPTION_POINTERS}
  PEXCEPTION_POINTERS = PExceptionPointers;

const
  { Machine types of IsWow64Process2 (winnt.h) }
  {$EXTERNALSYM IMAGE_FILE_MACHINE_ARM}
  IMAGE_FILE_MACHINE_ARM   = $01C0;
  {$EXTERNALSYM IMAGE_FILE_MACHINE_ARMNT}
  IMAGE_FILE_MACHINE_ARMNT = $01C4;
  {$EXTERNALSYM IMAGE_FILE_MACHINE_IA64}
  IMAGE_FILE_MACHINE_IA64  = $0200;
  {$EXTERNALSYM IMAGE_FILE_MACHINE_AMD64}
  IMAGE_FILE_MACHINE_AMD64 = $8664;
  {$EXTERNALSYM IMAGE_FILE_MACHINE_ARM64}
  IMAGE_FILE_MACHINE_ARM64 = $AA64;

{ ====== Power requests and execution state (winnt.h, winbase.h) ========== }

type
  {$EXTERNALSYM EXECUTION_STATE}
  EXECUTION_STATE = DWORD;

const
  {$EXTERNALSYM ES_SYSTEM_REQUIRED}
  ES_SYSTEM_REQUIRED   = DWORD($00000001);
  {$EXTERNALSYM ES_DISPLAY_REQUIRED}
  ES_DISPLAY_REQUIRED  = DWORD($00000002);
  {$EXTERNALSYM ES_USER_PRESENT}
  ES_USER_PRESENT      = DWORD($00000004);
  {$EXTERNALSYM ES_AWAYMODE_REQUIRED}
  ES_AWAYMODE_REQUIRED = DWORD($00000040);
  {$EXTERNALSYM ES_CONTINUOUS}
  ES_CONTINUOUS        = DWORD($80000000);

type
  { The reason of a power request (and of SetWaitableTimerEx's wake). }
  PReasonContext = ^TReasonContext;
  {$EXTERNALSYM _REASON_CONTEXT}
  _REASON_CONTEXT = record
    Version: ULONG;                  // POWER_REQUEST_CONTEXT_VERSION
    Flags: DWORD;                    // POWER_REQUEST_CONTEXT_*
    Reason: record
      case Integer of
        0: (Detailed: record
              LocalizedReasonModule: HMODULE;
              LocalizedReasonId: ULONG;
              ReasonStringCount: ULONG;
              ReasonStrings: PPWideChar;
            end);
        1: (SimpleReasonString: PWideChar);
    end;
  end;
  {$EXTERNALSYM REASON_CONTEXT}
  REASON_CONTEXT = _REASON_CONTEXT;
  {$EXTERNALSYM PREASON_CONTEXT}
  PREASON_CONTEXT = PReasonContext;
  TReasonContext = _REASON_CONTEXT;

  {$EXTERNALSYM POWER_REQUEST_TYPE}
  POWER_REQUEST_TYPE = Integer;

const
  {$EXTERNALSYM POWER_REQUEST_CONTEXT_VERSION}
  POWER_REQUEST_CONTEXT_VERSION         = 0;
  {$EXTERNALSYM POWER_REQUEST_CONTEXT_SIMPLE_STRING}
  POWER_REQUEST_CONTEXT_SIMPLE_STRING   = $00000001;
  {$EXTERNALSYM POWER_REQUEST_CONTEXT_DETAILED_STRING}
  POWER_REQUEST_CONTEXT_DETAILED_STRING = $00000002;

  { POWER_REQUEST_TYPE }
  {$EXTERNALSYM PowerRequestDisplayRequired}
  PowerRequestDisplayRequired   = 0;
  {$EXTERNALSYM PowerRequestSystemRequired}
  PowerRequestSystemRequired    = 1;
  {$EXTERNALSYM PowerRequestAwayModeRequired}
  PowerRequestAwayModeRequired  = 2;
  {$EXTERNALSYM PowerRequestExecutionRequired}
  PowerRequestExecutionRequired = 3;  // Windows 8

{ Windows 2000. Returns the previous state. Fallback: 0
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM SetThreadExecutionState}
function SetThreadExecutionState(esFlags: EXECUTION_STATE): EXECUTION_STATE; stdcall;
{ Windows 2000. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM IsSystemResumeAutomatic}
function IsSystemResumeAutomatic: BOOL; stdcall;
{ Windows 7. Close the request with CloseHandle. Fallback:
  INVALID_HANDLE_VALUE; PowerSetRequest/PowerClearRequest False (both
  ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM PowerCreateRequest}
function PowerCreateRequest(var Context: TReasonContext): THandle; stdcall;
{$EXTERNALSYM PowerSetRequest}
function PowerSetRequest(PowerRequest: THandle; RequestType: POWER_REQUEST_TYPE): BOOL; stdcall;
{$EXTERNALSYM PowerClearRequest}
function PowerClearRequest(PowerRequest: THandle; RequestType: POWER_REQUEST_TYPE): BOOL; stdcall;

{ ====== Thread pool (threadpoolapiset.h, Windows Vista) =================== }

type
  {$EXTERNALSYM PTP_CALLBACK_INSTANCE}
  PTP_CALLBACK_INSTANCE = Pointer;
  { Callback environment: these declarations always pass nil, the process's
    default pool. }
  {$EXTERNALSYM PTP_CALLBACK_ENVIRON}
  PTP_CALLBACK_ENVIRON = Pointer;
  {$EXTERNALSYM PTP_WORK}
  PTP_WORK = Pointer;
  {$EXTERNALSYM PTP_TIMER}
  PTP_TIMER = Pointer;
  {$EXTERNALSYM PTP_WAIT}
  PTP_WAIT = Pointer;
  {$EXTERNALSYM TP_WAIT_RESULT}
  TP_WAIT_RESULT = DWORD;

  {$EXTERNALSYM PTP_SIMPLE_CALLBACK}
  PTP_SIMPLE_CALLBACK = procedure(Instance: PTP_CALLBACK_INSTANCE; Context: Pointer); stdcall;
  {$EXTERNALSYM PTP_WORK_CALLBACK}
  PTP_WORK_CALLBACK = procedure(Instance: PTP_CALLBACK_INSTANCE; Context: Pointer;
    Work: PTP_WORK); stdcall;
  {$EXTERNALSYM PTP_TIMER_CALLBACK}
  PTP_TIMER_CALLBACK = procedure(Instance: PTP_CALLBACK_INSTANCE; Context: Pointer;
    Timer: PTP_TIMER); stdcall;
  {$EXTERNALSYM PTP_WAIT_CALLBACK}
  PTP_WAIT_CALLBACK = procedure(Instance: PTP_CALLBACK_INSTANCE; Context: Pointer;
    Wait: PTP_WAIT; WaitResult: TP_WAIT_RESULT); stdcall;

{ Windows Vista. pcbe = nil uses the process's default pool. Fallback: the
  Create functions return nil and TrySubmitThreadpoolCallback, IsThreadpoolTimerSet
  and CallbackMayRunLong return False, all with ERROR_CALL_NOT_IMPLEMENTED; the
  procedures only take objects a Create function returned, so they do nothing. }
{$EXTERNALSYM CreateThreadpoolWork}
function CreateThreadpoolWork(pfnwk: PTP_WORK_CALLBACK; pv: Pointer;
  pcbe: PTP_CALLBACK_ENVIRON): PTP_WORK; stdcall;
{$EXTERNALSYM SubmitThreadpoolWork}
procedure SubmitThreadpoolWork(pwk: PTP_WORK); stdcall;
{$EXTERNALSYM WaitForThreadpoolWorkCallbacks}
procedure WaitForThreadpoolWorkCallbacks(pwk: PTP_WORK; fCancelPendingCallbacks: BOOL); stdcall;
{$EXTERNALSYM CloseThreadpoolWork}
procedure CloseThreadpoolWork(pwk: PTP_WORK); stdcall;
{$EXTERNALSYM TrySubmitThreadpoolCallback}
function TrySubmitThreadpoolCallback(pfns: PTP_SIMPLE_CALLBACK; pv: Pointer;
  pcbe: PTP_CALLBACK_ENVIRON): BOOL; stdcall;
{$EXTERNALSYM CreateThreadpoolTimer}
function CreateThreadpoolTimer(pfnti: PTP_TIMER_CALLBACK; pv: Pointer;
  pcbe: PTP_CALLBACK_ENVIRON): PTP_TIMER; stdcall;
{ pftDueTime: absolute (UTC) or, if negative, relative time in 100 ns
  units; nil stops the timer. }
{$EXTERNALSYM SetThreadpoolTimer}
procedure SetThreadpoolTimer(pti: PTP_TIMER; pftDueTime: PFileTime;
  msPeriod, msWindowLength: DWORD); stdcall;
{ Windows 8: True if a pending timer was canceled. Fallback (Windows
  Vista/7): SetThreadpoolTimer, result False. }
{$EXTERNALSYM SetThreadpoolTimerEx}
function SetThreadpoolTimerEx(pti: PTP_TIMER; pftDueTime: PFileTime;
  msPeriod, msWindowLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM IsThreadpoolTimerSet}
function IsThreadpoolTimerSet(pti: PTP_TIMER): BOOL; stdcall;
{$EXTERNALSYM WaitForThreadpoolTimerCallbacks}
procedure WaitForThreadpoolTimerCallbacks(pti: PTP_TIMER; fCancelPendingCallbacks: BOOL); stdcall;
{$EXTERNALSYM CloseThreadpoolTimer}
procedure CloseThreadpoolTimer(pti: PTP_TIMER); stdcall;
{$EXTERNALSYM CreateThreadpoolWait}
function CreateThreadpoolWait(pfnwa: PTP_WAIT_CALLBACK; pv: Pointer;
  pcbe: PTP_CALLBACK_ENVIRON): PTP_WAIT; stdcall;
{ pftTimeout as pftDueTime above; nil waits forever. }
{$EXTERNALSYM SetThreadpoolWait}
procedure SetThreadpoolWait(pwa: PTP_WAIT; h: THandle; pftTimeout: PFileTime); stdcall;
{ Windows 8: True if a pending wait was canceled. Fallback (Windows
  Vista/7): SetThreadpoolWait, result False. }
{$EXTERNALSYM SetThreadpoolWaitEx}
function SetThreadpoolWaitEx(pwa: PTP_WAIT; h: THandle; pftTimeout: PFileTime;
  Reserved: Pointer): BOOL; stdcall;
{$EXTERNALSYM WaitForThreadpoolWaitCallbacks}
procedure WaitForThreadpoolWaitCallbacks(pwa: PTP_WAIT; fCancelPendingCallbacks: BOOL); stdcall;
{$EXTERNALSYM CloseThreadpoolWait}
procedure CloseThreadpoolWait(pwa: PTP_WAIT); stdcall;

{ Called from a callback with its Instance. }
{$EXTERNALSYM SetEventWhenCallbackReturns}
procedure SetEventWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE; evt: THandle); stdcall;
{$EXTERNALSYM ReleaseSemaphoreWhenCallbackReturns}
procedure ReleaseSemaphoreWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE; sem: THandle;
  crel: DWORD); stdcall;
{$EXTERNALSYM ReleaseMutexWhenCallbackReturns}
procedure ReleaseMutexWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE; mut: THandle); stdcall;
{$EXTERNALSYM LeaveCriticalSectionWhenCallbackReturns}
procedure LeaveCriticalSectionWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE;
  var pcs: TRTLCriticalSection); stdcall;
{$EXTERNALSYM FreeLibraryWhenCallbackReturns}
procedure FreeLibraryWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE; module: HMODULE); stdcall;
{$EXTERNALSYM CallbackMayRunLong}
function CallbackMayRunLong(pci: PTP_CALLBACK_INSTANCE): BOOL; stdcall;
{$EXTERNALSYM DisassociateCurrentThreadFromCallback}
procedure DisassociateCurrentThreadFromCallback(pci: PTP_CALLBACK_INSTANCE); stdcall;

{ ====== Legacy thread pool and timer queues (threadpoollegacyapiset.h) ==== }

type
  { TimerOrWaitFired is a BOOLEAN: True = the timer or wait timed out. }
  {$EXTERNALSYM WAITORTIMERCALLBACK}
  WAITORTIMERCALLBACK = procedure(lpParameter: Pointer; TimerOrWaitFired: ByteBool); stdcall;
  TWaitOrTimerCallback = WAITORTIMERCALLBACK;

const
  {$EXTERNALSYM WT_EXECUTEDEFAULT}
  WT_EXECUTEDEFAULT              = $00000000;
  {$EXTERNALSYM WT_EXECUTEINIOTHREAD}
  WT_EXECUTEINIOTHREAD           = $00000001;
  {$EXTERNALSYM WT_EXECUTEINUITHREAD}
  WT_EXECUTEINUITHREAD           = $00000002;
  {$EXTERNALSYM WT_EXECUTEINWAITTHREAD}
  WT_EXECUTEINWAITTHREAD         = $00000004;
  {$EXTERNALSYM WT_EXECUTEONLYONCE}
  WT_EXECUTEONLYONCE             = $00000008;
  {$EXTERNALSYM WT_EXECUTELONGFUNCTION}
  WT_EXECUTELONGFUNCTION         = $00000010;
  {$EXTERNALSYM WT_EXECUTEINTIMERTHREAD}
  WT_EXECUTEINTIMERTHREAD        = $00000020;
  {$EXTERNALSYM WT_EXECUTEINPERSISTENTIOTHREAD}
  WT_EXECUTEINPERSISTENTIOTHREAD = $00000040;
  {$EXTERNALSYM WT_EXECUTEINPERSISTENTTHREAD}
  WT_EXECUTEINPERSISTENTTHREAD   = $00000080;
  {$EXTERNALSYM WT_TRANSFER_IMPERSONATION}
  WT_TRANSFER_IMPERSONATION      = $00000100;

{ Windows 2000. Func: function(lpThreadParameter: Pointer): DWORD; stdcall.
  Fallback: False (ERROR_CALL_NOT_IMPLEMENTED); CreateTimerQueue 0. }
{$EXTERNALSYM QueueUserWorkItem}
function QueueUserWorkItem(Func: TFNThreadStartRoutine; Context: Pointer;
  Flags: ULONG): BOOL; stdcall;
{$EXTERNALSYM RegisterWaitForSingleObject}
function RegisterWaitForSingleObject(out phNewWaitObject: THandle; hObject: THandle;
  Callback: WAITORTIMERCALLBACK; Context: Pointer; dwMilliseconds: ULONG;
  dwFlags: ULONG): BOOL; stdcall;
{$EXTERNALSYM UnregisterWait}
function UnregisterWait(WaitHandle: THandle): BOOL; stdcall;
{ CompletionEvent: 0 = do not wait, INVALID_HANDLE_VALUE = wait for running
  callbacks, else an event that is signaled when they have finished. }
{$EXTERNALSYM UnregisterWaitEx}
function UnregisterWaitEx(WaitHandle: THandle; CompletionEvent: THandle): BOOL; stdcall;
{ TimerQueue = 0 in the functions below: the default timer queue. }
{$EXTERNALSYM CreateTimerQueue}
function CreateTimerQueue: THandle; stdcall;
{$EXTERNALSYM CreateTimerQueueTimer}
function CreateTimerQueueTimer(out phNewTimer: THandle; TimerQueue: THandle;
  Callback: WAITORTIMERCALLBACK; Parameter: Pointer; DueTime, Period: DWORD;
  Flags: ULONG): BOOL; stdcall;
{$EXTERNALSYM ChangeTimerQueueTimer}
function ChangeTimerQueueTimer(TimerQueue, Timer: THandle; DueTime, Period: ULONG): BOOL; stdcall;
{$EXTERNALSYM DeleteTimerQueueTimer}
function DeleteTimerQueueTimer(TimerQueue, Timer, CompletionEvent: THandle): BOOL; stdcall;
{$EXTERNALSYM DeleteTimerQueueEx}
function DeleteTimerQueueEx(TimerQueue, CompletionEvent: THandle): BOOL; stdcall;

{ ====== One-time initialization and synchronization objects (synchapi.h) == }

type
  PInitOnce = ^TInitOnce;
  { Pointer-sized, initialize with InitOnceInitialize or INIT_ONCE_STATIC_INIT
    (all zero). }
  {$EXTERNALSYM _RTL_RUN_ONCE}
  _RTL_RUN_ONCE = record
    Ptr: Pointer;
  end;
  {$EXTERNALSYM RTL_RUN_ONCE}
  RTL_RUN_ONCE = _RTL_RUN_ONCE;
  {$EXTERNALSYM INIT_ONCE}
  INIT_ONCE = _RTL_RUN_ONCE;
  {$EXTERNALSYM PINIT_ONCE}
  PINIT_ONCE = PInitOnce;
  {$EXTERNALSYM LPINIT_ONCE}
  LPINIT_ONCE = PInitOnce;
  TInitOnce = _RTL_RUN_ONCE;

  { Returns True on success; may store a context (low 2 bits zero) in
    Context^. }
  {$EXTERNALSYM PINIT_ONCE_FN}
  PINIT_ONCE_FN = function(InitOnce: PInitOnce; Parameter: Pointer;
    Context: PPointer): BOOL; stdcall;
  TInitOnceFn = PINIT_ONCE_FN;

const
  {$EXTERNALSYM INIT_ONCE_STATIC_INIT}
  INIT_ONCE_STATIC_INIT: TInitOnce = (Ptr: nil);
  {$EXTERNALSYM INIT_ONCE_CHECK_ONLY}
  INIT_ONCE_CHECK_ONLY        = $00000001;
  {$EXTERNALSYM INIT_ONCE_ASYNC}
  INIT_ONCE_ASYNC             = $00000002;
  {$EXTERNALSYM INIT_ONCE_INIT_FAILED}
  INIT_ONCE_INIT_FAILED       = $00000004;
  {$EXTERNALSYM INIT_ONCE_CTX_RESERVED_BITS}
  INIT_ONCE_CTX_RESERVED_BITS = 2;

{ Windows Vista. Fallback (Windows XP), decided once per process: an
  emulation of the synchronous mode that keeps its state in the pointer-sized
  INIT_ONCE (concurrent callers yield with Sleep until the first one has
  finished; a failed callback lets the next caller try again; the context
  is stored with its low 2 bits cleared). InitOnceBeginInitialize and
  InitOnceComplete return False (ERROR_CALL_NOT_IMPLEMENTED) there. }
{$EXTERNALSYM InitOnceInitialize}
procedure InitOnceInitialize(var InitOnce: TInitOnce); stdcall;
{ Context may be nil. }
{$EXTERNALSYM InitOnceExecuteOnce}
function InitOnceExecuteOnce(var InitOnce: TInitOnce; InitFn: PINIT_ONCE_FN;
  Parameter: Pointer; Context: PPointer): BOOL; stdcall;
{$EXTERNALSYM InitOnceBeginInitialize}
function InitOnceBeginInitialize(var lpInitOnce: TInitOnce; dwFlags: DWORD;
  out fPending: BOOL; lpContext: PPointer): BOOL; stdcall;
{$EXTERNALSYM InitOnceComplete}
function InitOnceComplete(var lpInitOnce: TInitOnce; dwFlags: DWORD;
  lpContext: Pointer): BOOL; stdcall;

const
  {$EXTERNALSYM CRITICAL_SECTION_NO_DEBUG_INFO}
  CRITICAL_SECTION_NO_DEBUG_INFO = $01000000;

  {$EXTERNALSYM CREATE_EVENT_MANUAL_RESET}
  CREATE_EVENT_MANUAL_RESET             = $00000001;
  {$EXTERNALSYM CREATE_EVENT_INITIAL_SET}
  CREATE_EVENT_INITIAL_SET              = $00000002;
  {$EXTERNALSYM CREATE_MUTEX_INITIAL_OWNER}
  CREATE_MUTEX_INITIAL_OWNER            = $00000001;
  {$EXTERNALSYM CREATE_WAITABLE_TIMER_MANUAL_RESET}
  CREATE_WAITABLE_TIMER_MANUAL_RESET    = $00000001;
  {$EXTERNALSYM CREATE_WAITABLE_TIMER_HIGH_RESOLUTION}
  CREATE_WAITABLE_TIMER_HIGH_RESOLUTION = $00000002;  // Windows 10 1803

  {$EXTERNALSYM SEMAPHORE_MODIFY_STATE}
  SEMAPHORE_MODIFY_STATE = $0002;
  {$EXTERNALSYM SEMAPHORE_ALL_ACCESS}
  SEMAPHORE_ALL_ACCESS   = STANDARD_RIGHTS_REQUIRED or SYNCHRONIZE or $3;
  {$EXTERNALSYM TIMER_QUERY_STATE}
  TIMER_QUERY_STATE      = $0001;
  {$EXTERNALSYM TIMER_MODIFY_STATE}
  TIMER_MODIFY_STATE     = $0002;
  {$EXTERNALSYM TIMER_ALL_ACCESS}
  TIMER_ALL_ACCESS       = STANDARD_RIGHTS_REQUIRED or SYNCHRONIZE or TIMER_QUERY_STATE or
    TIMER_MODIFY_STATE;

{ Windows Vista. Fallback: InitializeCriticalSectionAndSpinCount (Flags are
  ignored). }
{$EXTERNALSYM InitializeCriticalSectionEx}
function InitializeCriticalSectionEx(var lpCriticalSection: TRTLCriticalSection;
  dwSpinCount: DWORD; Flags: DWORD): BOOL; stdcall;

{ Windows Vista. Fallback: CreateEvent/CreateMutex/CreateSemaphore/
  CreateWaitableTimer with the dwFlags translated; the object then has full
  access (dwDesiredAccess is ignored). CREATE_WAITABLE_TIMER_HIGH_RESOLUTION
  gives 0 with ERROR_INVALID_PARAMETER, as on Windows versions before 1803. }
{$EXTERNALSYM CreateEventEx}
function CreateEventEx(lpEventAttributes: PSecurityAttributes; lpName: PChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
{$EXTERNALSYM CreateEventExA}
function CreateEventExA(lpEventAttributes: PSecurityAttributes; lpName: PAnsiChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
{$EXTERNALSYM CreateEventExW}
function CreateEventExW(lpEventAttributes: PSecurityAttributes; lpName: PWideChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
{$EXTERNALSYM CreateMutexEx}
function CreateMutexEx(lpMutexAttributes: PSecurityAttributes; lpName: PChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
{$EXTERNALSYM CreateMutexExA}
function CreateMutexExA(lpMutexAttributes: PSecurityAttributes; lpName: PAnsiChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
{$EXTERNALSYM CreateMutexExW}
function CreateMutexExW(lpMutexAttributes: PSecurityAttributes; lpName: PWideChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
{ dwFlags is reserved (0). }
{$EXTERNALSYM CreateSemaphoreEx}
function CreateSemaphoreEx(lpSemaphoreAttributes: PSecurityAttributes;
  lInitialCount, lMaximumCount: Longint; lpName: PChar; dwFlags: DWORD;
  dwDesiredAccess: DWORD): THandle; stdcall;
{$EXTERNALSYM CreateSemaphoreExA}
function CreateSemaphoreExA(lpSemaphoreAttributes: PSecurityAttributes;
  lInitialCount, lMaximumCount: Longint; lpName: PAnsiChar; dwFlags: DWORD;
  dwDesiredAccess: DWORD): THandle; stdcall;
{$EXTERNALSYM CreateSemaphoreExW}
function CreateSemaphoreExW(lpSemaphoreAttributes: PSecurityAttributes;
  lInitialCount, lMaximumCount: Longint; lpName: PWideChar; dwFlags: DWORD;
  dwDesiredAccess: DWORD): THandle; stdcall;
{$EXTERNALSYM CreateWaitableTimerEx}
function CreateWaitableTimerEx(lpTimerAttributes: PSecurityAttributes; lpTimerName: PChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
{$EXTERNALSYM CreateWaitableTimerExA}
function CreateWaitableTimerExA(lpTimerAttributes: PSecurityAttributes; lpTimerName: PAnsiChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
{$EXTERNALSYM CreateWaitableTimerExW}
function CreateWaitableTimerExW(lpTimerAttributes: PSecurityAttributes; lpTimerName: PWideChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
{ Windows 7. lpDueTime: absolute (UTC) or, if negative, relative time in
  100 ns units. WakeContext may be nil. Fallback: SetWaitableTimer with
  fResume = (WakeContext <> nil); TolerableDelay is ignored. }
{$EXTERNALSYM SetWaitableTimerEx}
function SetWaitableTimerEx(hTimer: THandle; const lpDueTime: Int64; lPeriod: Longint;
  pfnCompletionRoutine: TFNTimerAPCRoutine; lpArgToCompletionRoutine: Pointer;
  WakeContext: PReasonContext; TolerableDelay: ULONG): BOOL; stdcall;

{ ====== Fiber local storage (fibersapi.h) ================================= }

const
  {$EXTERNALSYM FLS_OUT_OF_INDEXES}
  FLS_OUT_OF_INDEXES = DWORD($FFFFFFFF);

type
  {$EXTERNALSYM PFLS_CALLBACK_FUNCTION}
  PFLS_CALLBACK_FUNCTION = procedure(lpFlsData: Pointer); stdcall;

{ Windows Vista (Server 2003). On threads that are not fibers FLS works like
  TLS, with a callback when the thread ends. Fallback (Windows XP), decided
  once per process: thread local storage (TlsAlloc etc.) - FlsAlloc with a
  callback then returns FLS_OUT_OF_INDEXES (ERROR_CALL_NOT_IMPLEMENTED),
  because TLS cannot call it. }
{$EXTERNALSYM FlsAlloc}
function FlsAlloc(lpCallback: PFLS_CALLBACK_FUNCTION): DWORD; stdcall;
{$EXTERNALSYM FlsGetValue}
function FlsGetValue(dwFlsIndex: DWORD): Pointer; stdcall;
{$EXTERNALSYM FlsSetValue}
function FlsSetValue(dwFlsIndex: DWORD; lpFlsData: Pointer): BOOL; stdcall;
{$EXTERNALSYM FlsFree}
function FlsFree(dwFlsIndex: DWORD): BOOL; stdcall;

{ ====== Threads and processes (processthreadsapi.h, winbase.h) ============ }

const
  { Thread access rights }
  {$EXTERNALSYM THREAD_TERMINATE}
  THREAD_TERMINATE                 = $0001;
  {$EXTERNALSYM THREAD_SUSPEND_RESUME}
  THREAD_SUSPEND_RESUME            = $0002;
  {$EXTERNALSYM THREAD_GET_CONTEXT}
  THREAD_GET_CONTEXT               = $0008;
  {$EXTERNALSYM THREAD_SET_CONTEXT}
  THREAD_SET_CONTEXT               = $0010;
  {$EXTERNALSYM THREAD_SET_INFORMATION}
  THREAD_SET_INFORMATION           = $0020;
  {$EXTERNALSYM THREAD_QUERY_INFORMATION}
  THREAD_QUERY_INFORMATION         = $0040;
  {$EXTERNALSYM THREAD_SET_THREAD_TOKEN}
  THREAD_SET_THREAD_TOKEN          = $0080;
  {$EXTERNALSYM THREAD_IMPERSONATE}
  THREAD_IMPERSONATE               = $0100;
  {$EXTERNALSYM THREAD_DIRECT_IMPERSONATION}
  THREAD_DIRECT_IMPERSONATION      = $0200;
  {$EXTERNALSYM THREAD_SET_LIMITED_INFORMATION}
  THREAD_SET_LIMITED_INFORMATION   = $0400;  // Windows Vista
  {$EXTERNALSYM THREAD_QUERY_LIMITED_INFORMATION}
  THREAD_QUERY_LIMITED_INFORMATION = $0800;  // Windows Vista
  {$EXTERNALSYM THREAD_RESUME}
  THREAD_RESUME                    = $1000;
  {$EXTERNALSYM THREAD_ALL_ACCESS}
  THREAD_ALL_ACCESS = STANDARD_RIGHTS_REQUIRED or SYNCHRONIZE or $FFFF;  // Windows Vista value

  {$EXTERNALSYM PROCESS_SET_LIMITED_INFORMATION}
  PROCESS_SET_LIMITED_INFORMATION = $2000;

{ Windows 2000. Fallback: 0 (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM OpenThread}
function OpenThread(dwDesiredAccess: DWORD; bInheritHandle: BOOL;
  dwThreadId: DWORD): THandle; stdcall;
{ Windows Vista (GetProcessId: Windows XP SP1). Fallback: 0
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetThreadId}
function GetThreadId(Thread: THandle): DWORD; stdcall;
{$EXTERNALSYM GetProcessId}
function GetProcessId(Process: THandle): DWORD; stdcall;
{$EXTERNALSYM GetProcessIdOfThread}
function GetProcessIdOfThread(Thread: THandle): DWORD; stdcall;

{ Windows 10 1607. The thread needs THREAD_SET_LIMITED_INFORMATION;
  GetThreadDescription allocates the string, free it with LocalFree.
  Fallback: E_NOTIMPL (GetThreadDescription sets ppszThreadDescription to
  nil). }
{$EXTERNALSYM SetThreadDescription}
function SetThreadDescription(hThread: THandle; lpThreadDescription: PWideChar): HRESULT; stdcall;
{$EXTERNALSYM GetThreadDescription}
function GetThreadDescription(hThread: THandle;
  out ppszThreadDescription: PWideChar): HRESULT; stdcall;

type
  PProcessorNumber = ^TProcessorNumber;
  {$EXTERNALSYM _PROCESSOR_NUMBER}
  _PROCESSOR_NUMBER = record
    Group: Word;
    Number: Byte;
    Reserved: Byte;
  end;
  {$EXTERNALSYM PROCESSOR_NUMBER}
  PROCESSOR_NUMBER = _PROCESSOR_NUMBER;
  {$EXTERNALSYM PPROCESSOR_NUMBER}
  PPROCESSOR_NUMBER = PProcessorNumber;
  TProcessorNumber = _PROCESSOR_NUMBER;

{ Windows Vista. Fallback: 0. }
{$EXTERNALSYM GetCurrentProcessorNumber}
function GetCurrentProcessorNumber: DWORD; stdcall;
{ Windows 7. Fallback: GetCurrentProcessorNumber in group 0. }
{$EXTERNALSYM GetCurrentProcessorNumberEx}
procedure GetCurrentProcessorNumberEx(out ProcNumber: TProcessorNumber); stdcall;

{ Windows Vista (QueryUnbiasedInterruptTime: Windows 7). Cycle times are CPU
  cycles; the interrupt time is in 100 ns units without the time spent in
  sleep or hibernation. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM QueryThreadCycleTime}
function QueryThreadCycleTime(ThreadHandle: THandle; out CycleTime: UInt64): BOOL; stdcall;
{$EXTERNALSYM QueryProcessCycleTime}
function QueryProcessCycleTime(ProcessHandle: THandle; out CycleTime: UInt64): BOOL; stdcall;
{ ProcessorIdleCycleTime: array of one UInt64 per processor; BufferLength in
  bytes. }
{$EXTERNALSYM QueryIdleProcessorCycleTime}
function QueryIdleProcessorCycleTime(var BufferLength: ULONG;
  ProcessorIdleCycleTime: PInt64): BOOL; stdcall;
{$EXTERNALSYM QueryUnbiasedInterruptTime}
function QueryUnbiasedInterruptTime(out UnbiasedTime: UInt64): BOOL; stdcall;

type
  {$EXTERNALSYM THREAD_INFORMATION_CLASS}
  THREAD_INFORMATION_CLASS = Integer;
  {$EXTERNALSYM PROCESS_INFORMATION_CLASS}
  PROCESS_INFORMATION_CLASS = Integer;

const
  { THREAD_INFORMATION_CLASS }
  {$EXTERNALSYM ThreadMemoryPriority}
  ThreadMemoryPriority      = 0;
  {$EXTERNALSYM ThreadAbsoluteCpuPriority}
  ThreadAbsoluteCpuPriority = 1;
  {$EXTERNALSYM ThreadDynamicCodePolicy}
  ThreadDynamicCodePolicy   = 2;
  {$EXTERNALSYM ThreadPowerThrottling}
  ThreadPowerThrottling     = 3;
  {$EXTERNALSYM ThreadInformationClassMax}
  ThreadInformationClassMax = 4;

  { PROCESS_INFORMATION_CLASS }
  {$EXTERNALSYM ProcessMemoryPriority}
  ProcessMemoryPriority       = 0;
  {$EXTERNALSYM ProcessMemoryExhaustionInfo}
  ProcessMemoryExhaustionInfo = 1;
  {$EXTERNALSYM ProcessAppMemoryInfo}
  ProcessAppMemoryInfo        = 2;
  {$EXTERNALSYM ProcessInPrivateInfo}
  ProcessInPrivateInfo        = 3;
  {$EXTERNALSYM ProcessPowerThrottling}
  ProcessPowerThrottling      = 4;
  {$EXTERNALSYM ProcessReservedValue1}
  ProcessReservedValue1       = 5;
  {$EXTERNALSYM ProcessTelemetryCoverageInfo}
  ProcessTelemetryCoverageInfo = 6;
  {$EXTERNALSYM ProcessProtectionLevelInfo}
  ProcessProtectionLevelInfo  = 7;
  {$EXTERNALSYM ProcessLeapSecondInfo}
  ProcessLeapSecondInfo       = 8;
  {$EXTERNALSYM ProcessMachineTypeInfo}
  ProcessMachineTypeInfo      = 9;

  { MEMORY_PRIORITY_INFORMATION.MemoryPriority }
  {$EXTERNALSYM MEMORY_PRIORITY_VERY_LOW}
  MEMORY_PRIORITY_VERY_LOW     = 1;
  {$EXTERNALSYM MEMORY_PRIORITY_LOW}
  MEMORY_PRIORITY_LOW          = 2;
  {$EXTERNALSYM MEMORY_PRIORITY_MEDIUM}
  MEMORY_PRIORITY_MEDIUM       = 3;
  {$EXTERNALSYM MEMORY_PRIORITY_BELOW_NORMAL}
  MEMORY_PRIORITY_BELOW_NORMAL = 4;
  {$EXTERNALSYM MEMORY_PRIORITY_NORMAL}
  MEMORY_PRIORITY_NORMAL       = 5;

  {$EXTERNALSYM THREAD_POWER_THROTTLING_CURRENT_VERSION}
  THREAD_POWER_THROTTLING_CURRENT_VERSION  = 1;
  {$EXTERNALSYM THREAD_POWER_THROTTLING_EXECUTION_SPEED}
  THREAD_POWER_THROTTLING_EXECUTION_SPEED  = $1;
  {$EXTERNALSYM THREAD_POWER_THROTTLING_VALID_FLAGS}
  THREAD_POWER_THROTTLING_VALID_FLAGS      = THREAD_POWER_THROTTLING_EXECUTION_SPEED;
  {$EXTERNALSYM PROCESS_POWER_THROTTLING_CURRENT_VERSION}
  PROCESS_POWER_THROTTLING_CURRENT_VERSION = 1;
  {$EXTERNALSYM PROCESS_POWER_THROTTLING_EXECUTION_SPEED}
  PROCESS_POWER_THROTTLING_EXECUTION_SPEED = $1;
  {$EXTERNALSYM PROCESS_POWER_THROTTLING_IGNORE_TIMER_RESOLUTION}
  PROCESS_POWER_THROTTLING_IGNORE_TIMER_RESOLUTION = $4;

type
  PMemoryPriorityInformation = ^TMemoryPriorityInformation;
  {$EXTERNALSYM _MEMORY_PRIORITY_INFORMATION}
  _MEMORY_PRIORITY_INFORMATION = record
    MemoryPriority: ULONG;
  end;
  {$EXTERNALSYM MEMORY_PRIORITY_INFORMATION}
  MEMORY_PRIORITY_INFORMATION = _MEMORY_PRIORITY_INFORMATION;
  {$EXTERNALSYM PMEMORY_PRIORITY_INFORMATION}
  PMEMORY_PRIORITY_INFORMATION = PMemoryPriorityInformation;
  TMemoryPriorityInformation = _MEMORY_PRIORITY_INFORMATION;

  PThreadPowerThrottlingState = ^TThreadPowerThrottlingState;
  {$EXTERNALSYM _THREAD_POWER_THROTTLING_STATE}
  _THREAD_POWER_THROTTLING_STATE = record
    Version: ULONG;
    ControlMask: ULONG;
    StateMask: ULONG;
  end;
  {$EXTERNALSYM THREAD_POWER_THROTTLING_STATE}
  THREAD_POWER_THROTTLING_STATE = _THREAD_POWER_THROTTLING_STATE;
  TThreadPowerThrottlingState = _THREAD_POWER_THROTTLING_STATE;

  PProcessPowerThrottlingState = ^TProcessPowerThrottlingState;
  {$EXTERNALSYM _PROCESS_POWER_THROTTLING_STATE}
  _PROCESS_POWER_THROTTLING_STATE = record
    Version: ULONG;
    ControlMask: ULONG;
    StateMask: ULONG;
  end;
  {$EXTERNALSYM PROCESS_POWER_THROTTLING_STATE}
  PROCESS_POWER_THROTTLING_STATE = _PROCESS_POWER_THROTTLING_STATE;
  {$EXTERNALSYM PPROCESS_POWER_THROTTLING_STATE}
  PPROCESS_POWER_THROTTLING_STATE = PProcessPowerThrottlingState;
  TProcessPowerThrottlingState = _PROCESS_POWER_THROTTLING_STATE;

{ Windows 8 (ThreadPowerThrottling, ProcessPowerThrottling: Windows 10 1709).
  Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetThreadInformation}
function GetThreadInformation(hThread: THandle; ThreadInformationClass: THREAD_INFORMATION_CLASS;
  ThreadInformation: Pointer; ThreadInformationSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM SetThreadInformation}
function SetThreadInformation(hThread: THandle; ThreadInformationClass: THREAD_INFORMATION_CLASS;
  ThreadInformation: Pointer; ThreadInformationSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetProcessInformation}
function GetProcessInformation(hProcess: THandle;
  ProcessInformationClass: PROCESS_INFORMATION_CLASS; ProcessInformation: Pointer;
  ProcessInformationSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM SetProcessInformation}
function SetProcessInformation(hProcess: THandle;
  ProcessInformationClass: PROCESS_INFORMATION_CLASS; ProcessInformation: Pointer;
  ProcessInformationSize: DWORD): BOOL; stdcall;

{ Windows Vista. Fallback: SetErrorMode twice (read and restore). }
{$EXTERNALSYM GetErrorMode}
function GetErrorMode: UINT; stdcall;
{ Windows 7. Fallback: GetThreadErrorMode returns GetErrorMode;
  SetThreadErrorMode False (ERROR_CALL_NOT_IMPLEMENTED). lpOldMode may be
  nil. }
{$EXTERNALSYM GetThreadErrorMode}
function GetThreadErrorMode: DWORD; stdcall;
{$EXTERNALSYM SetThreadErrorMode}
function SetThreadErrorMode(dwNewMode: DWORD; lpOldMode: LPDWORD): BOOL; stdcall;
{ Windows Vista (Server 2003 SP1). StackSizeInBytes: in = new guarantee,
  out = the previous one. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM SetThreadStackGuarantee}
function SetThreadStackGuarantee(var StackSizeInBytes: ULONG): BOOL; stdcall;
{ Windows 8. Fallback: the limits from the thread information block
  (StackLimit, StackBase), which give the committed part only. }
{$EXTERNALSYM GetCurrentThreadStackLimits}
procedure GetCurrentThreadStackLimits(out LowLimit, HighLimit: ULONG_PTR); stdcall;
{ Windows XP SP1. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetProcessHandleCount}
function GetProcessHandleCount(hProcess: THandle; out pdwHandleCount: DWORD): BOOL; stdcall;
{ Windows 2000. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM ProcessIdToSessionId}
function ProcessIdToSessionId(dwProcessId: DWORD; out pSessionId: DWORD): BOOL; stdcall;

{ ====== Job objects (jobapi2.h, winnt.h) ================================== }

type
  {$EXTERNALSYM JOBOBJECTINFOCLASS}
  JOBOBJECTINFOCLASS = Integer;

const
  { JOBOBJECTINFOCLASS }
  {$EXTERNALSYM JobObjectBasicAccountingInformation}
  JobObjectBasicAccountingInformation       = 1;
  {$EXTERNALSYM JobObjectBasicLimitInformation}
  JobObjectBasicLimitInformation            = 2;
  {$EXTERNALSYM JobObjectBasicProcessIdList}
  JobObjectBasicProcessIdList               = 3;
  {$EXTERNALSYM JobObjectBasicUIRestrictions}
  JobObjectBasicUIRestrictions              = 4;
  {$EXTERNALSYM JobObjectSecurityLimitInformation}
  JobObjectSecurityLimitInformation         = 5;
  {$EXTERNALSYM JobObjectEndOfJobTimeInformation}
  JobObjectEndOfJobTimeInformation          = 6;
  {$EXTERNALSYM JobObjectAssociateCompletionPortInformation}
  JobObjectAssociateCompletionPortInformation = 7;
  {$EXTERNALSYM JobObjectBasicAndIoAccountingInformation}
  JobObjectBasicAndIoAccountingInformation  = 8;
  {$EXTERNALSYM JobObjectExtendedLimitInformation}
  JobObjectExtendedLimitInformation         = 9;
  {$EXTERNALSYM JobObjectGroupInformation}
  JobObjectGroupInformation                 = 11;
  {$EXTERNALSYM JobObjectNotificationLimitInformation}
  JobObjectNotificationLimitInformation     = 12;
  {$EXTERNALSYM JobObjectLimitViolationInformation}
  JobObjectLimitViolationInformation        = 13;
  {$EXTERNALSYM JobObjectGroupInformationEx}
  JobObjectGroupInformationEx               = 14;
  {$EXTERNALSYM JobObjectCpuRateControlInformation}
  JobObjectCpuRateControlInformation        = 15;
  {$EXTERNALSYM JobObjectCompletionFilter}
  JobObjectCompletionFilter                 = 16;
  {$EXTERNALSYM JobObjectCompletionCounter}
  JobObjectCompletionCounter                = 17;

  { Job access rights }
  {$EXTERNALSYM JOB_OBJECT_ASSIGN_PROCESS}
  JOB_OBJECT_ASSIGN_PROCESS          = $0001;
  {$EXTERNALSYM JOB_OBJECT_SET_ATTRIBUTES}
  JOB_OBJECT_SET_ATTRIBUTES          = $0002;
  {$EXTERNALSYM JOB_OBJECT_QUERY}
  JOB_OBJECT_QUERY                   = $0004;
  {$EXTERNALSYM JOB_OBJECT_TERMINATE}
  JOB_OBJECT_TERMINATE               = $0008;
  {$EXTERNALSYM JOB_OBJECT_SET_SECURITY_ATTRIBUTES}
  JOB_OBJECT_SET_SECURITY_ATTRIBUTES = $0010;
  {$EXTERNALSYM JOB_OBJECT_IMPERSONATE}
  JOB_OBJECT_IMPERSONATE             = $0020;
  {$EXTERNALSYM JOB_OBJECT_ALL_ACCESS}
  JOB_OBJECT_ALL_ACCESS = STANDARD_RIGHTS_REQUIRED or SYNCHRONIZE or $3F;

  { JOBOBJECT_BASIC_LIMIT_INFORMATION.LimitFlags }
  {$EXTERNALSYM JOB_OBJECT_LIMIT_WORKINGSET}
  JOB_OBJECT_LIMIT_WORKINGSET                 = $00000001;
  {$EXTERNALSYM JOB_OBJECT_LIMIT_PROCESS_TIME}
  JOB_OBJECT_LIMIT_PROCESS_TIME               = $00000002;
  {$EXTERNALSYM JOB_OBJECT_LIMIT_JOB_TIME}
  JOB_OBJECT_LIMIT_JOB_TIME                   = $00000004;
  {$EXTERNALSYM JOB_OBJECT_LIMIT_ACTIVE_PROCESS}
  JOB_OBJECT_LIMIT_ACTIVE_PROCESS             = $00000008;
  {$EXTERNALSYM JOB_OBJECT_LIMIT_AFFINITY}
  JOB_OBJECT_LIMIT_AFFINITY                   = $00000010;
  {$EXTERNALSYM JOB_OBJECT_LIMIT_PRIORITY_CLASS}
  JOB_OBJECT_LIMIT_PRIORITY_CLASS             = $00000020;
  {$EXTERNALSYM JOB_OBJECT_LIMIT_PRESERVE_JOB_TIME}
  JOB_OBJECT_LIMIT_PRESERVE_JOB_TIME          = $00000040;
  {$EXTERNALSYM JOB_OBJECT_LIMIT_SCHEDULING_CLASS}
  JOB_OBJECT_LIMIT_SCHEDULING_CLASS           = $00000080;
  {$EXTERNALSYM JOB_OBJECT_LIMIT_PROCESS_MEMORY}
  JOB_OBJECT_LIMIT_PROCESS_MEMORY             = $00000100;
  {$EXTERNALSYM JOB_OBJECT_LIMIT_JOB_MEMORY}
  JOB_OBJECT_LIMIT_JOB_MEMORY                 = $00000200;
  {$EXTERNALSYM JOB_OBJECT_LIMIT_DIE_ON_UNHANDLED_EXCEPTION}
  JOB_OBJECT_LIMIT_DIE_ON_UNHANDLED_EXCEPTION = $00000400;
  {$EXTERNALSYM JOB_OBJECT_LIMIT_BREAKAWAY_OK}
  JOB_OBJECT_LIMIT_BREAKAWAY_OK               = $00000800;
  {$EXTERNALSYM JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK}
  JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK        = $00001000;
  {$EXTERNALSYM JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE}
  JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE          = $00002000;
  {$EXTERNALSYM JOB_OBJECT_LIMIT_SUBSET_AFFINITY}
  JOB_OBJECT_LIMIT_SUBSET_AFFINITY            = $00004000;  // Windows 7

  { JOBOBJECT_BASIC_UI_RESTRICTIONS.UIRestrictionsClass }
  {$EXTERNALSYM JOB_OBJECT_UILIMIT_NONE}
  JOB_OBJECT_UILIMIT_NONE             = $00000000;
  {$EXTERNALSYM JOB_OBJECT_UILIMIT_HANDLES}
  JOB_OBJECT_UILIMIT_HANDLES          = $00000001;
  {$EXTERNALSYM JOB_OBJECT_UILIMIT_READCLIPBOARD}
  JOB_OBJECT_UILIMIT_READCLIPBOARD    = $00000002;
  {$EXTERNALSYM JOB_OBJECT_UILIMIT_WRITECLIPBOARD}
  JOB_OBJECT_UILIMIT_WRITECLIPBOARD   = $00000004;
  {$EXTERNALSYM JOB_OBJECT_UILIMIT_SYSTEMPARAMETERS}
  JOB_OBJECT_UILIMIT_SYSTEMPARAMETERS = $00000008;
  {$EXTERNALSYM JOB_OBJECT_UILIMIT_DISPLAYSETTINGS}
  JOB_OBJECT_UILIMIT_DISPLAYSETTINGS  = $00000010;
  {$EXTERNALSYM JOB_OBJECT_UILIMIT_GLOBALATOMS}
  JOB_OBJECT_UILIMIT_GLOBALATOMS      = $00000020;
  {$EXTERNALSYM JOB_OBJECT_UILIMIT_DESKTOP}
  JOB_OBJECT_UILIMIT_DESKTOP          = $00000040;
  {$EXTERNALSYM JOB_OBJECT_UILIMIT_EXITWINDOWS}
  JOB_OBJECT_UILIMIT_EXITWINDOWS      = $00000080;

  { Completion port messages (lpNumberOfBytesTransferred of
    GetQueuedCompletionStatus) }
  {$EXTERNALSYM JOB_OBJECT_MSG_END_OF_JOB_TIME}
  JOB_OBJECT_MSG_END_OF_JOB_TIME       = 1;
  {$EXTERNALSYM JOB_OBJECT_MSG_END_OF_PROCESS_TIME}
  JOB_OBJECT_MSG_END_OF_PROCESS_TIME   = 2;
  {$EXTERNALSYM JOB_OBJECT_MSG_ACTIVE_PROCESS_LIMIT}
  JOB_OBJECT_MSG_ACTIVE_PROCESS_LIMIT  = 3;
  {$EXTERNALSYM JOB_OBJECT_MSG_ACTIVE_PROCESS_ZERO}
  JOB_OBJECT_MSG_ACTIVE_PROCESS_ZERO   = 4;
  {$EXTERNALSYM JOB_OBJECT_MSG_NEW_PROCESS}
  JOB_OBJECT_MSG_NEW_PROCESS           = 6;
  {$EXTERNALSYM JOB_OBJECT_MSG_EXIT_PROCESS}
  JOB_OBJECT_MSG_EXIT_PROCESS          = 7;
  {$EXTERNALSYM JOB_OBJECT_MSG_ABNORMAL_EXIT_PROCESS}
  JOB_OBJECT_MSG_ABNORMAL_EXIT_PROCESS = 8;
  {$EXTERNALSYM JOB_OBJECT_MSG_PROCESS_MEMORY_LIMIT}
  JOB_OBJECT_MSG_PROCESS_MEMORY_LIMIT  = 9;
  {$EXTERNALSYM JOB_OBJECT_MSG_JOB_MEMORY_LIMIT}
  JOB_OBJECT_MSG_JOB_MEMORY_LIMIT      = 10;

  { CreateProcess creation flags }
  {$EXTERNALSYM INHERIT_PARENT_AFFINITY}
  INHERIT_PARENT_AFFINITY      = $00010000;
  {$EXTERNALSYM EXTENDED_STARTUPINFO_PRESENT}
  EXTENDED_STARTUPINFO_PRESENT = $00080000;  // Windows Vista
  {$EXTERNALSYM CREATE_BREAKAWAY_FROM_JOB}
  CREATE_BREAKAWAY_FROM_JOB    = $01000000;

type
  PIoCounters = ^TIoCounters;
  {$EXTERNALSYM _IO_COUNTERS}
  _IO_COUNTERS = record
    ReadOperationCount: UInt64;
    WriteOperationCount: UInt64;
    OtherOperationCount: UInt64;
    ReadTransferCount: UInt64;
    WriteTransferCount: UInt64;
    OtherTransferCount: UInt64;
  end;
  {$EXTERNALSYM IO_COUNTERS}
  IO_COUNTERS = _IO_COUNTERS;
  {$EXTERNALSYM PIO_COUNTERS}
  PIO_COUNTERS = PIoCounters;
  TIoCounters = _IO_COUNTERS;

  PJobObjectBasicAccountingInformation = ^TJobObjectBasicAccountingInformation;
  {$EXTERNALSYM _JOBOBJECT_BASIC_ACCOUNTING_INFORMATION}
  _JOBOBJECT_BASIC_ACCOUNTING_INFORMATION = record
    TotalUserTime: Int64;                  // 100 ns units
    TotalKernelTime: Int64;
    ThisPeriodTotalUserTime: Int64;
    ThisPeriodTotalKernelTime: Int64;
    TotalPageFaultCount: DWORD;
    TotalProcesses: DWORD;
    ActiveProcesses: DWORD;
    TotalTerminatedProcesses: DWORD;
  end;
  {$EXTERNALSYM JOBOBJECT_BASIC_ACCOUNTING_INFORMATION}
  JOBOBJECT_BASIC_ACCOUNTING_INFORMATION = _JOBOBJECT_BASIC_ACCOUNTING_INFORMATION;
  {$EXTERNALSYM PJOBOBJECT_BASIC_ACCOUNTING_INFORMATION}
  PJOBOBJECT_BASIC_ACCOUNTING_INFORMATION = PJobObjectBasicAccountingInformation;
  TJobObjectBasicAccountingInformation = _JOBOBJECT_BASIC_ACCOUNTING_INFORMATION;

  PJobObjectBasicLimitInformation = ^TJobObjectBasicLimitInformation;
  {$EXTERNALSYM _JOBOBJECT_BASIC_LIMIT_INFORMATION}
  _JOBOBJECT_BASIC_LIMIT_INFORMATION = record
    PerProcessUserTimeLimit: Int64;        // 100 ns units
    PerJobUserTimeLimit: Int64;
    LimitFlags: DWORD;                     // JOB_OBJECT_LIMIT_*
    MinimumWorkingSetSize: ULONG_PTR;      // SIZE_T
    MaximumWorkingSetSize: ULONG_PTR;      // SIZE_T
    ActiveProcessLimit: DWORD;
    Affinity: ULONG_PTR;
    PriorityClass: DWORD;
    SchedulingClass: DWORD;
  end;
  {$EXTERNALSYM JOBOBJECT_BASIC_LIMIT_INFORMATION}
  JOBOBJECT_BASIC_LIMIT_INFORMATION = _JOBOBJECT_BASIC_LIMIT_INFORMATION;
  {$EXTERNALSYM PJOBOBJECT_BASIC_LIMIT_INFORMATION}
  PJOBOBJECT_BASIC_LIMIT_INFORMATION = PJobObjectBasicLimitInformation;
  TJobObjectBasicLimitInformation = _JOBOBJECT_BASIC_LIMIT_INFORMATION;

  PJobObjectExtendedLimitInformation = ^TJobObjectExtendedLimitInformation;
  {$EXTERNALSYM _JOBOBJECT_EXTENDED_LIMIT_INFORMATION}
  _JOBOBJECT_EXTENDED_LIMIT_INFORMATION = record
    BasicLimitInformation: TJobObjectBasicLimitInformation;
    IoInfo: TIoCounters;
    ProcessMemoryLimit: ULONG_PTR;         // SIZE_T
    JobMemoryLimit: ULONG_PTR;
    PeakProcessMemoryUsed: ULONG_PTR;
    PeakJobMemoryUsed: ULONG_PTR;
  end;
  {$EXTERNALSYM JOBOBJECT_EXTENDED_LIMIT_INFORMATION}
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION = _JOBOBJECT_EXTENDED_LIMIT_INFORMATION;
  {$EXTERNALSYM PJOBOBJECT_EXTENDED_LIMIT_INFORMATION}
  PJOBOBJECT_EXTENDED_LIMIT_INFORMATION = PJobObjectExtendedLimitInformation;
  TJobObjectExtendedLimitInformation = _JOBOBJECT_EXTENDED_LIMIT_INFORMATION;

  PJobObjectBasicProcessIdList = ^TJobObjectBasicProcessIdList;
  {$EXTERNALSYM _JOBOBJECT_BASIC_PROCESS_ID_LIST}
  _JOBOBJECT_BASIC_PROCESS_ID_LIST = record
    NumberOfAssignedProcesses: DWORD;
    NumberOfProcessIdsInList: DWORD;
    ProcessIdList: array[0..0] of ULONG_PTR;   // NumberOfProcessIdsInList entries
  end;
  {$EXTERNALSYM JOBOBJECT_BASIC_PROCESS_ID_LIST}
  JOBOBJECT_BASIC_PROCESS_ID_LIST = _JOBOBJECT_BASIC_PROCESS_ID_LIST;
  {$EXTERNALSYM PJOBOBJECT_BASIC_PROCESS_ID_LIST}
  PJOBOBJECT_BASIC_PROCESS_ID_LIST = PJobObjectBasicProcessIdList;
  TJobObjectBasicProcessIdList = _JOBOBJECT_BASIC_PROCESS_ID_LIST;

  PJobObjectBasicUIRestrictions = ^TJobObjectBasicUIRestrictions;
  {$EXTERNALSYM _JOBOBJECT_BASIC_UI_RESTRICTIONS}
  _JOBOBJECT_BASIC_UI_RESTRICTIONS = record
    UIRestrictionsClass: DWORD;            // JOB_OBJECT_UILIMIT_*
  end;
  {$EXTERNALSYM JOBOBJECT_BASIC_UI_RESTRICTIONS}
  JOBOBJECT_BASIC_UI_RESTRICTIONS = _JOBOBJECT_BASIC_UI_RESTRICTIONS;
  {$EXTERNALSYM PJOBOBJECT_BASIC_UI_RESTRICTIONS}
  PJOBOBJECT_BASIC_UI_RESTRICTIONS = PJobObjectBasicUIRestrictions;
  TJobObjectBasicUIRestrictions = _JOBOBJECT_BASIC_UI_RESTRICTIONS;

  PJobObjectAssociateCompletionPort = ^TJobObjectAssociateCompletionPort;
  {$EXTERNALSYM _JOBOBJECT_ASSOCIATE_COMPLETION_PORT}
  _JOBOBJECT_ASSOCIATE_COMPLETION_PORT = record
    CompletionKey: Pointer;
    CompletionPort: THandle;
  end;
  {$EXTERNALSYM JOBOBJECT_ASSOCIATE_COMPLETION_PORT}
  JOBOBJECT_ASSOCIATE_COMPLETION_PORT = _JOBOBJECT_ASSOCIATE_COMPLETION_PORT;
  {$EXTERNALSYM PJOBOBJECT_ASSOCIATE_COMPLETION_PORT}
  PJOBOBJECT_ASSOCIATE_COMPLETION_PORT = PJobObjectAssociateCompletionPort;
  TJobObjectAssociateCompletionPort = _JOBOBJECT_ASSOCIATE_COMPLETION_PORT;

{ Windows 2000 (IsProcessInJob: Windows XP). Fallback: CreateJobObject and
  OpenJobObject return 0, the BOOL functions False, all with
  ERROR_CALL_NOT_IMPLEMENTED. }
{$EXTERNALSYM CreateJobObject}
function CreateJobObject(lpJobAttributes: PSecurityAttributes; lpName: PChar): THandle; stdcall;
{$EXTERNALSYM CreateJobObjectA}
function CreateJobObjectA(lpJobAttributes: PSecurityAttributes; lpName: PAnsiChar): THandle; stdcall;
{$EXTERNALSYM CreateJobObjectW}
function CreateJobObjectW(lpJobAttributes: PSecurityAttributes; lpName: PWideChar): THandle; stdcall;
{$EXTERNALSYM OpenJobObject}
function OpenJobObject(dwDesiredAccess: DWORD; bInheritHandle: BOOL; lpName: PChar): THandle; stdcall;
{$EXTERNALSYM OpenJobObjectA}
function OpenJobObjectA(dwDesiredAccess: DWORD; bInheritHandle: BOOL; lpName: PAnsiChar): THandle; stdcall;
{$EXTERNALSYM OpenJobObjectW}
function OpenJobObjectW(dwDesiredAccess: DWORD; bInheritHandle: BOOL; lpName: PWideChar): THandle; stdcall;
{$EXTERNALSYM AssignProcessToJobObject}
function AssignProcessToJobObject(hJob, hProcess: THandle): BOOL; stdcall;
{$EXTERNALSYM TerminateJobObject}
function TerminateJobObject(hJob: THandle; uExitCode: UINT): BOOL; stdcall;
{ lpReturnLength may be nil. }
{$EXTERNALSYM QueryInformationJobObject}
function QueryInformationJobObject(hJob: THandle; JobObjectInformationClass: JOBOBJECTINFOCLASS;
  lpJobObjectInformation: Pointer; cbJobObjectInformationLength: DWORD;
  lpReturnLength: LPDWORD): BOOL; stdcall;
{$EXTERNALSYM SetInformationJobObject}
function SetInformationJobObject(hJob: THandle; JobObjectInformationClass: JOBOBJECTINFOCLASS;
  lpJobObjectInformation: Pointer; cbJobObjectInformationLength: DWORD): BOOL; stdcall;
{ JobHandle = 0: any job. }
{$EXTERNALSYM IsProcessInJob}
function IsProcessInJob(ProcessHandle, JobHandle: THandle; out Result_: BOOL): BOOL; stdcall;
{ Windows 2000. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetProcessIoCounters}
function GetProcessIoCounters(hProcess: THandle; out lpIoCounters: TIoCounters): BOOL; stdcall;

{ ====== Process and thread attribute lists (processthreadsapi.h) ========== }

type
  { Opaque; allocate the size InitializeProcThreadAttributeList reports. }
  {$EXTERNALSYM LPPROC_THREAD_ATTRIBUTE_LIST}
  LPPROC_THREAD_ATTRIBUTE_LIST = Pointer;
  {$EXTERNALSYM PPROC_THREAD_ATTRIBUTE_LIST}
  PPROC_THREAD_ATTRIBUTE_LIST = Pointer;

  { CreateProcess with EXTENDED_STARTUPINFO_PRESENT; StartupInfo.cb =
    SizeOf(TStartupInfoEx*). Windows.pas has one STARTUPINFO record
    (TStartupInfo, also used by CreateProcessW): in TStartupInfoExW its
    lpReserved, lpDesktop and lpTitle point to WideChar strings. }
  PStartupInfoExA = ^TStartupInfoExA;
  PStartupInfoExW = ^TStartupInfoExW;
  PStartupInfoEx = PStartupInfoExA;
  {$EXTERNALSYM _STARTUPINFOEXA}
  _STARTUPINFOEXA = record
    StartupInfo: TStartupInfo;
    lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST;
  end;
  {$EXTERNALSYM _STARTUPINFOEXW}
  _STARTUPINFOEXW = record
    StartupInfo: TStartupInfo;
    lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST;
  end;
  {$EXTERNALSYM _STARTUPINFOEX}
  _STARTUPINFOEX = _STARTUPINFOEXA;
  {$EXTERNALSYM STARTUPINFOEXA}
  STARTUPINFOEXA = _STARTUPINFOEXA;
  {$EXTERNALSYM STARTUPINFOEXW}
  STARTUPINFOEXW = _STARTUPINFOEXW;
  {$EXTERNALSYM STARTUPINFOEX}
  STARTUPINFOEX = STARTUPINFOEXA;
  {$EXTERNALSYM LPSTARTUPINFOEXA}
  LPSTARTUPINFOEXA = PStartupInfoExA;
  {$EXTERNALSYM LPSTARTUPINFOEXW}
  LPSTARTUPINFOEXW = PStartupInfoExW;
  TStartupInfoExA = _STARTUPINFOEXA;
  TStartupInfoExW = _STARTUPINFOEXW;
  TStartupInfoEx = TStartupInfoExA;

const
  {$EXTERNALSYM PROC_THREAD_ATTRIBUTE_PARENT_PROCESS}
  PROC_THREAD_ATTRIBUTE_PARENT_PROCESS    = $00020000;  // HANDLE
  {$EXTERNALSYM PROC_THREAD_ATTRIBUTE_HANDLE_LIST}
  PROC_THREAD_ATTRIBUTE_HANDLE_LIST       = $00020002;  // array of HANDLE
  {$EXTERNALSYM PROC_THREAD_ATTRIBUTE_GROUP_AFFINITY}
  PROC_THREAD_ATTRIBUTE_GROUP_AFFINITY    = $00030003;  // GROUP_AFFINITY (Windows 7)
  {$EXTERNALSYM PROC_THREAD_ATTRIBUTE_PREFERRED_NODE}
  PROC_THREAD_ATTRIBUTE_PREFERRED_NODE    = $00020004;  // USHORT (Windows 7)
  {$EXTERNALSYM PROC_THREAD_ATTRIBUTE_IDEAL_PROCESSOR}
  PROC_THREAD_ATTRIBUTE_IDEAL_PROCESSOR   = $00030005;  // PROCESSOR_NUMBER (Windows 7)
  {$EXTERNALSYM PROC_THREAD_ATTRIBUTE_MITIGATION_POLICY}
  PROC_THREAD_ATTRIBUTE_MITIGATION_POLICY = $00020007;  // DWORD or DWORD64 (Windows 7)
  {$EXTERNALSYM PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES}
  PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES = $00020009;  // Windows 8
  {$EXTERNALSYM PROC_THREAD_ATTRIBUTE_PROTECTION_LEVEL}
  PROC_THREAD_ATTRIBUTE_PROTECTION_LEVEL  = $0002000B;  // Windows 8.1
  {$EXTERNALSYM PROC_THREAD_ATTRIBUTE_JOB_LIST}
  PROC_THREAD_ATTRIBUTE_JOB_LIST          = $0002000D;  // array of HANDLE (Windows 10)
  {$EXTERNALSYM PROC_THREAD_ATTRIBUTE_CHILD_PROCESS_POLICY}
  PROC_THREAD_ATTRIBUTE_CHILD_PROCESS_POLICY = $0002000E;  // DWORD (Windows 10 1511)
  {$EXTERNALSYM PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE}
  PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE     = $00020016;  // HPCON (Windows 10 1809)
  {$EXTERNALSYM PROC_THREAD_ATTRIBUTE_MACHINE_TYPE}
  PROC_THREAD_ATTRIBUTE_MACHINE_TYPE      = $00020019;  // USHORT (Windows 11)

{ Windows Vista. lpAttributeList = nil asks for the size. Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED); DeleteProcThreadAttributeList does nothing. }
{$EXTERNALSYM InitializeProcThreadAttributeList}
function InitializeProcThreadAttributeList(lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST;
  dwAttributeCount: DWORD; dwFlags: DWORD; var lpSize: ULONG_PTR): BOOL; stdcall;
{ lpValue must stay valid until DeleteProcThreadAttributeList. }
{$EXTERNALSYM UpdateProcThreadAttribute}
function UpdateProcThreadAttribute(lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST;
  dwFlags: DWORD; Attribute: DWORD_PTR; lpValue: Pointer; cbSize: ULONG_PTR;
  lpPreviousValue: Pointer; lpReturnSize: PULONG): BOOL; stdcall;
{$EXTERNALSYM DeleteProcThreadAttributeList}
procedure DeleteProcThreadAttributeList(lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST); stdcall;

{ ====== Files and volumes (fileapi.h, winbase.h) ========================== }

type
  {$EXTERNALSYM FILE_INFO_BY_HANDLE_CLASS}
  FILE_INFO_BY_HANDLE_CLASS = Integer;

const
  { FILE_INFO_BY_HANDLE_CLASS }
  {$EXTERNALSYM FileBasicInfo}
  FileBasicInfo                  = 0;
  {$EXTERNALSYM FileStandardInfo}
  FileStandardInfo               = 1;
  {$EXTERNALSYM FileNameInfo}
  FileNameInfo                   = 2;
  {$EXTERNALSYM FileRenameInfo}
  FileRenameInfo                 = 3;
  {$EXTERNALSYM FileDispositionInfo}
  FileDispositionInfo            = 4;
  {$EXTERNALSYM FileAllocationInfo}
  FileAllocationInfo             = 5;
  {$EXTERNALSYM FileEndOfFileInfo}
  FileEndOfFileInfo              = 6;
  {$EXTERNALSYM FileStreamInfo}
  FileStreamInfo                 = 7;
  {$EXTERNALSYM FileCompressionInfo}
  FileCompressionInfo            = 8;
  {$EXTERNALSYM FileAttributeTagInfo}
  FileAttributeTagInfo           = 9;
  {$EXTERNALSYM FileIdBothDirectoryInfo}
  FileIdBothDirectoryInfo        = 10;
  {$EXTERNALSYM FileIdBothDirectoryRestartInfo}
  FileIdBothDirectoryRestartInfo = 11;
  {$EXTERNALSYM FileIoPriorityHintInfo}
  FileIoPriorityHintInfo         = 12;
  {$EXTERNALSYM FileRemoteProtocolInfo}
  FileRemoteProtocolInfo         = 13;
  {$EXTERNALSYM FileFullDirectoryInfo}
  FileFullDirectoryInfo          = 14;
  {$EXTERNALSYM FileFullDirectoryRestartInfo}
  FileFullDirectoryRestartInfo   = 15;
  {$EXTERNALSYM FileStorageInfo}
  FileStorageInfo                = 16;  // Windows 8
  {$EXTERNALSYM FileAlignmentInfo}
  FileAlignmentInfo              = 17;  // Windows 8
  {$EXTERNALSYM FileIdInfo}
  FileIdInfo                     = 18;  // Windows 8
  {$EXTERNALSYM FileIdExtdDirectoryInfo}
  FileIdExtdDirectoryInfo        = 19;  // Windows 8
  {$EXTERNALSYM FileIdExtdDirectoryRestartInfo}
  FileIdExtdDirectoryRestartInfo = 20;  // Windows 8
  {$EXTERNALSYM FileDispositionInfoEx}
  FileDispositionInfoEx          = 21;  // Windows 10 1607
  {$EXTERNALSYM FileRenameInfoEx}
  FileRenameInfoEx               = 22;  // Windows 10 1607
  {$EXTERNALSYM FileCaseSensitiveInfo}
  FileCaseSensitiveInfo          = 23;  // Windows 10 1703
  {$EXTERNALSYM FileNormalizedNameInfo}
  FileNormalizedNameInfo         = 24;  // Windows 10 1703

  { FILE_DISPOSITION_INFO_EX.Flags }
  {$EXTERNALSYM FILE_DISPOSITION_FLAG_DO_NOT_DELETE}
  FILE_DISPOSITION_FLAG_DO_NOT_DELETE              = $00000000;
  {$EXTERNALSYM FILE_DISPOSITION_FLAG_DELETE}
  FILE_DISPOSITION_FLAG_DELETE                     = $00000001;
  {$EXTERNALSYM FILE_DISPOSITION_FLAG_POSIX_SEMANTICS}
  FILE_DISPOSITION_FLAG_POSIX_SEMANTICS            = $00000002;
  {$EXTERNALSYM FILE_DISPOSITION_FLAG_FORCE_IMAGE_SECTION_CHECK}
  FILE_DISPOSITION_FLAG_FORCE_IMAGE_SECTION_CHECK  = $00000004;
  {$EXTERNALSYM FILE_DISPOSITION_FLAG_ON_CLOSE}
  FILE_DISPOSITION_FLAG_ON_CLOSE                   = $00000008;
  {$EXTERNALSYM FILE_DISPOSITION_FLAG_IGNORE_READONLY_ATTRIBUTE}
  FILE_DISPOSITION_FLAG_IGNORE_READONLY_ATTRIBUTE  = $00000010;

  { FILE_RENAME_INFO.Flags (FileRenameInfoEx) }
  {$EXTERNALSYM FILE_RENAME_FLAG_REPLACE_IF_EXISTS}
  FILE_RENAME_FLAG_REPLACE_IF_EXISTS = $00000001;
  {$EXTERNALSYM FILE_RENAME_FLAG_POSIX_SEMANTICS}
  FILE_RENAME_FLAG_POSIX_SEMANTICS   = $00000002;

  { FILE_IO_PRIORITY_HINT_INFO.PriorityHint }
  {$EXTERNALSYM IoPriorityHintVeryLow}
  IoPriorityHintVeryLow = 0;
  {$EXTERNALSYM IoPriorityHintLow}
  IoPriorityHintLow     = 1;
  {$EXTERNALSYM IoPriorityHintNormal}
  IoPriorityHintNormal  = 2;

type
  PFileBasicInfo = ^TFileBasicInfo;
  {$EXTERNALSYM _FILE_BASIC_INFO}
  _FILE_BASIC_INFO = record
    CreationTime: Int64;                   // FILETIME values as LARGE_INTEGER
    LastAccessTime: Int64;
    LastWriteTime: Int64;
    ChangeTime: Int64;
    FileAttributes: DWORD;
  end;
  {$EXTERNALSYM FILE_BASIC_INFO}
  FILE_BASIC_INFO = _FILE_BASIC_INFO;
  {$EXTERNALSYM PFILE_BASIC_INFO}
  PFILE_BASIC_INFO = PFileBasicInfo;
  TFileBasicInfo = _FILE_BASIC_INFO;

  PFileStandardInfo = ^TFileStandardInfo;
  {$EXTERNALSYM _FILE_STANDARD_INFO}
  _FILE_STANDARD_INFO = record
    AllocationSize: Int64;
    EndOfFile: Int64;
    NumberOfLinks: DWORD;
    DeletePending: ByteBool;               // BOOLEAN
    Directory: ByteBool;                   // BOOLEAN
  end;
  {$EXTERNALSYM FILE_STANDARD_INFO}
  FILE_STANDARD_INFO = _FILE_STANDARD_INFO;
  {$EXTERNALSYM PFILE_STANDARD_INFO}
  PFILE_STANDARD_INFO = PFileStandardInfo;
  TFileStandardInfo = _FILE_STANDARD_INFO;

  { Variable size: FileNameLength bytes of FileName, not null terminated. }
  PFileNameInfo = ^TFileNameInfo;
  {$EXTERNALSYM _FILE_NAME_INFO}
  _FILE_NAME_INFO = record
    FileNameLength: DWORD;
    FileName: array[0..0] of WideChar;
  end;
  {$EXTERNALSYM FILE_NAME_INFO}
  FILE_NAME_INFO = _FILE_NAME_INFO;
  {$EXTERNALSYM PFILE_NAME_INFO}
  PFILE_NAME_INFO = PFileNameInfo;
  TFileNameInfo = _FILE_NAME_INFO;

  { Variable size. The first DWORD is the BOOLEAN ReplaceIfExists
    (FileRenameInfo) or Flags (FILE_RENAME_FLAG_*, FileRenameInfoEx). }
  PFileRenameInfo = ^TFileRenameInfo;
  {$EXTERNALSYM _FILE_RENAME_INFO}
  _FILE_RENAME_INFO = record
    case Integer of
      0: (ReplaceIfExists: ByteBool);
      1: (Flags: DWORD;
          RootDirectory: THandle;
          FileNameLength: DWORD;
          FileName: array[0..0] of WideChar);
  end;
  {$EXTERNALSYM FILE_RENAME_INFO}
  FILE_RENAME_INFO = _FILE_RENAME_INFO;
  {$EXTERNALSYM PFILE_RENAME_INFO}
  PFILE_RENAME_INFO = PFileRenameInfo;
  TFileRenameInfo = _FILE_RENAME_INFO;

  PFileDispositionInfo = ^TFileDispositionInfo;
  {$EXTERNALSYM _FILE_DISPOSITION_INFO}
  _FILE_DISPOSITION_INFO = record
    DeleteFile: ByteBool;                  // BOOLEAN
  end;
  {$EXTERNALSYM FILE_DISPOSITION_INFO}
  FILE_DISPOSITION_INFO = _FILE_DISPOSITION_INFO;
  {$EXTERNALSYM PFILE_DISPOSITION_INFO}
  PFILE_DISPOSITION_INFO = PFileDispositionInfo;
  TFileDispositionInfo = _FILE_DISPOSITION_INFO;

  PFileDispositionInfoEx = ^TFileDispositionInfoEx;
  {$EXTERNALSYM _FILE_DISPOSITION_INFO_EX}
  _FILE_DISPOSITION_INFO_EX = record
    Flags: DWORD;                          // FILE_DISPOSITION_FLAG_*
  end;
  {$EXTERNALSYM FILE_DISPOSITION_INFO_EX}
  FILE_DISPOSITION_INFO_EX = _FILE_DISPOSITION_INFO_EX;
  {$EXTERNALSYM PFILE_DISPOSITION_INFO_EX}
  PFILE_DISPOSITION_INFO_EX = PFileDispositionInfoEx;
  TFileDispositionInfoEx = _FILE_DISPOSITION_INFO_EX;

  PFileAllocationInfo = ^TFileAllocationInfo;
  {$EXTERNALSYM _FILE_ALLOCATION_INFO}
  _FILE_ALLOCATION_INFO = record
    AllocationSize: Int64;
  end;
  {$EXTERNALSYM FILE_ALLOCATION_INFO}
  FILE_ALLOCATION_INFO = _FILE_ALLOCATION_INFO;
  {$EXTERNALSYM PFILE_ALLOCATION_INFO}
  PFILE_ALLOCATION_INFO = PFileAllocationInfo;
  TFileAllocationInfo = _FILE_ALLOCATION_INFO;

  PFileEndOfFileInfo = ^TFileEndOfFileInfo;
  {$EXTERNALSYM _FILE_END_OF_FILE_INFO}
  _FILE_END_OF_FILE_INFO = record
    EndOfFile: Int64;
  end;
  {$EXTERNALSYM FILE_END_OF_FILE_INFO}
  FILE_END_OF_FILE_INFO = _FILE_END_OF_FILE_INFO;
  {$EXTERNALSYM PFILE_END_OF_FILE_INFO}
  PFILE_END_OF_FILE_INFO = PFileEndOfFileInfo;
  TFileEndOfFileInfo = _FILE_END_OF_FILE_INFO;

  { Variable size, chained by NextEntryOffset (0 = last entry). }
  PFileStreamInfo = ^TFileStreamInfo;
  {$EXTERNALSYM _FILE_STREAM_INFO}
  _FILE_STREAM_INFO = record
    NextEntryOffset: DWORD;
    StreamNameLength: DWORD;               // bytes
    StreamSize: Int64;
    StreamAllocationSize: Int64;
    StreamName: array[0..0] of WideChar;
  end;
  {$EXTERNALSYM FILE_STREAM_INFO}
  FILE_STREAM_INFO = _FILE_STREAM_INFO;
  {$EXTERNALSYM PFILE_STREAM_INFO}
  PFILE_STREAM_INFO = PFileStreamInfo;
  TFileStreamInfo = _FILE_STREAM_INFO;

  PFileCompressionInfo = ^TFileCompressionInfo;
  {$EXTERNALSYM _FILE_COMPRESSION_INFO}
  _FILE_COMPRESSION_INFO = record
    CompressedFileSize: Int64;
    CompressionFormat: Word;
    CompressionUnitShift: Byte;
    ChunkShift: Byte;
    ClusterShift: Byte;
    Reserved: array[0..2] of Byte;
  end;
  {$EXTERNALSYM FILE_COMPRESSION_INFO}
  FILE_COMPRESSION_INFO = _FILE_COMPRESSION_INFO;
  {$EXTERNALSYM PFILE_COMPRESSION_INFO}
  PFILE_COMPRESSION_INFO = PFileCompressionInfo;
  TFileCompressionInfo = _FILE_COMPRESSION_INFO;

  PFileAttributeTagInfo = ^TFileAttributeTagInfo;
  {$EXTERNALSYM _FILE_ATTRIBUTE_TAG_INFO}
  _FILE_ATTRIBUTE_TAG_INFO = record
    FileAttributes: DWORD;
    ReparseTag: DWORD;
  end;
  {$EXTERNALSYM FILE_ATTRIBUTE_TAG_INFO}
  FILE_ATTRIBUTE_TAG_INFO = _FILE_ATTRIBUTE_TAG_INFO;
  {$EXTERNALSYM PFILE_ATTRIBUTE_TAG_INFO}
  PFILE_ATTRIBUTE_TAG_INFO = PFileAttributeTagInfo;
  TFileAttributeTagInfo = _FILE_ATTRIBUTE_TAG_INFO;

  { Variable size, chained by NextEntryOffset (0 = last entry). }
  PFileIdBothDirInfo = ^TFileIdBothDirInfo;
  {$EXTERNALSYM _FILE_ID_BOTH_DIR_INFO}
  _FILE_ID_BOTH_DIR_INFO = record
    NextEntryOffset: DWORD;
    FileIndex: DWORD;
    CreationTime: Int64;
    LastAccessTime: Int64;
    LastWriteTime: Int64;
    ChangeTime: Int64;
    EndOfFile: Int64;
    AllocationSize: Int64;
    FileAttributes: DWORD;
    FileNameLength: DWORD;                 // bytes
    EaSize: DWORD;
    ShortNameLength: Byte;                 // CCHAR, bytes
    ShortName: array[0..11] of WideChar;
    FileId: Int64;
    FileName: array[0..0] of WideChar;
  end;
  {$EXTERNALSYM FILE_ID_BOTH_DIR_INFO}
  FILE_ID_BOTH_DIR_INFO = _FILE_ID_BOTH_DIR_INFO;
  {$EXTERNALSYM PFILE_ID_BOTH_DIR_INFO}
  PFILE_ID_BOTH_DIR_INFO = PFileIdBothDirInfo;
  TFileIdBothDirInfo = _FILE_ID_BOTH_DIR_INFO;

  PFileIoPriorityHintInfo = ^TFileIoPriorityHintInfo;
  {$EXTERNALSYM _FILE_IO_PRIORITY_HINT_INFO}
  _FILE_IO_PRIORITY_HINT_INFO = record
    PriorityHint: Integer;                 // IoPriorityHint*
  end;
  {$EXTERNALSYM FILE_IO_PRIORITY_HINT_INFO}
  FILE_IO_PRIORITY_HINT_INFO = _FILE_IO_PRIORITY_HINT_INFO;
  {$EXTERNALSYM PFILE_IO_PRIORITY_HINT_INFO}
  PFILE_IO_PRIORITY_HINT_INFO = PFileIoPriorityHintInfo;
  TFileIoPriorityHintInfo = _FILE_IO_PRIORITY_HINT_INFO;

  PFileStorageInfo = ^TFileStorageInfo;
  {$EXTERNALSYM _FILE_STORAGE_INFO}
  _FILE_STORAGE_INFO = record
    LogicalBytesPerSector: ULONG;
    PhysicalBytesPerSectorForAtomicity: ULONG;
    PhysicalBytesPerSectorForPerformance: ULONG;
    FileSystemEffectivePhysicalBytesPerSectorForAtomicity: ULONG;
    Flags: ULONG;
    ByteOffsetForSectorAlignment: ULONG;
    ByteOffsetForPartitionAlignment: ULONG;
  end;
  {$EXTERNALSYM FILE_STORAGE_INFO}
  FILE_STORAGE_INFO = _FILE_STORAGE_INFO;
  {$EXTERNALSYM PFILE_STORAGE_INFO}
  PFILE_STORAGE_INFO = PFileStorageInfo;
  TFileStorageInfo = _FILE_STORAGE_INFO;

  PFileId128 = ^TFileId128;
  {$EXTERNALSYM _FILE_ID_128}
  _FILE_ID_128 = record
    Identifier: array[0..15] of Byte;
  end;
  {$EXTERNALSYM FILE_ID_128}
  FILE_ID_128 = _FILE_ID_128;
  {$EXTERNALSYM PFILE_ID_128}
  PFILE_ID_128 = PFileId128;
  TFileId128 = _FILE_ID_128;

  PFileIdInfo = ^TFileIdInfo;
  {$EXTERNALSYM _FILE_ID_INFO}
  _FILE_ID_INFO = record
    VolumeSerialNumber: UInt64;
    FileId: TFileId128;
  end;
  {$EXTERNALSYM FILE_ID_INFO}
  FILE_ID_INFO = _FILE_ID_INFO;
  {$EXTERNALSYM PFILE_ID_INFO}
  PFILE_ID_INFO = PFileIdInfo;
  TFileIdInfo = _FILE_ID_INFO;

  {$EXTERNALSYM FILE_ID_TYPE}
  FILE_ID_TYPE = Integer;

const
  { FILE_ID_TYPE }
  {$EXTERNALSYM FileIdType}
  FileIdType         = 0;
  {$EXTERNALSYM ObjectIdType}
  ObjectIdType       = 1;
  {$EXTERNALSYM ExtendedFileIdType}
  ExtendedFileIdType = 2;  // Windows 8

type
  PFileIdDescriptor = ^TFileIdDescriptor;
  {$EXTERNALSYM FILE_ID_DESCRIPTOR}
  FILE_ID_DESCRIPTOR = record
    dwSize: DWORD;                         // SizeOf(TFileIdDescriptor)
    Type_: FILE_ID_TYPE;                   // C name: Type
    case Integer of
      0: (FileId: Int64);
      1: (ObjectId: TGUID);
      2: (ExtendedFileId: TFileId128);
  end;
  {$EXTERNALSYM LPFILE_ID_DESCRIPTOR}
  LPFILE_ID_DESCRIPTOR = PFileIdDescriptor;
  TFileIdDescriptor = FILE_ID_DESCRIPTOR;

  {$EXTERNALSYM STREAM_INFO_LEVELS}
  STREAM_INFO_LEVELS = Integer;

const
  {$EXTERNALSYM FindStreamInfoStandard}
  FindStreamInfoStandard = 0;

type
  PWin32FindStreamData = ^TWin32FindStreamData;
  {$EXTERNALSYM _WIN32_FIND_STREAM_DATA}
  _WIN32_FIND_STREAM_DATA = record
    StreamSize: Int64;
    cStreamName: array[0..MAX_PATH + 36 - 1] of WideChar;   // ":name:$DATA"
  end;
  {$EXTERNALSYM WIN32_FIND_STREAM_DATA}
  WIN32_FIND_STREAM_DATA = _WIN32_FIND_STREAM_DATA;
  {$EXTERNALSYM PWIN32_FIND_STREAM_DATA}
  PWIN32_FIND_STREAM_DATA = PWin32FindStreamData;
  TWin32FindStreamData = _WIN32_FIND_STREAM_DATA;

const
  { ReplaceFile }
  {$EXTERNALSYM REPLACEFILE_WRITE_THROUGH}
  REPLACEFILE_WRITE_THROUGH       = $00000001;
  {$EXTERNALSYM REPLACEFILE_IGNORE_MERGE_ERRORS}
  REPLACEFILE_IGNORE_MERGE_ERRORS = $00000002;
  {$EXTERNALSYM REPLACEFILE_IGNORE_ACL_ERRORS}
  REPLACEFILE_IGNORE_ACL_ERRORS   = $00000004;

  { CopyFile2 / CopyFileEx flags not in Windows.pas }
  {$EXTERNALSYM COPY_FILE_ALLOW_DECRYPTED_DESTINATION}
  COPY_FILE_ALLOW_DECRYPTED_DESTINATION = $00000008;
  {$EXTERNALSYM COPY_FILE_COPY_SYMLINK}
  COPY_FILE_COPY_SYMLINK                = $00000800;
  {$EXTERNALSYM COPY_FILE_NO_BUFFERING}
  COPY_FILE_NO_BUFFERING                = $00001000;
  {$EXTERNALSYM COPY_FILE_REQUEST_SECURITY_PRIVILEGES}
  COPY_FILE_REQUEST_SECURITY_PRIVILEGES = $00002000;
  {$EXTERNALSYM COPY_FILE_RESUME_FROM_PAUSE}
  COPY_FILE_RESUME_FROM_PAUSE           = $00004000;
  {$EXTERNALSYM COPY_FILE_NO_OFFLOAD}
  COPY_FILE_NO_OFFLOAD                  = $00040000;

  { COPYFILE2_MESSAGE_TYPE }
  {$EXTERNALSYM COPYFILE2_CALLBACK_NONE}
  COPYFILE2_CALLBACK_NONE            = 0;
  {$EXTERNALSYM COPYFILE2_CALLBACK_CHUNK_STARTED}
  COPYFILE2_CALLBACK_CHUNK_STARTED   = 1;
  {$EXTERNALSYM COPYFILE2_CALLBACK_CHUNK_FINISHED}
  COPYFILE2_CALLBACK_CHUNK_FINISHED  = 2;
  {$EXTERNALSYM COPYFILE2_CALLBACK_STREAM_STARTED}
  COPYFILE2_CALLBACK_STREAM_STARTED  = 3;
  {$EXTERNALSYM COPYFILE2_CALLBACK_STREAM_FINISHED}
  COPYFILE2_CALLBACK_STREAM_FINISHED = 4;
  {$EXTERNALSYM COPYFILE2_CALLBACK_POLL_CONTINUE}
  COPYFILE2_CALLBACK_POLL_CONTINUE   = 5;
  {$EXTERNALSYM COPYFILE2_CALLBACK_ERROR}
  COPYFILE2_CALLBACK_ERROR           = 6;

  { COPYFILE2_MESSAGE_ACTION }
  {$EXTERNALSYM COPYFILE2_PROGRESS_CONTINUE}
  COPYFILE2_PROGRESS_CONTINUE = 0;
  {$EXTERNALSYM COPYFILE2_PROGRESS_CANCEL}
  COPYFILE2_PROGRESS_CANCEL   = 1;
  {$EXTERNALSYM COPYFILE2_PROGRESS_STOP}
  COPYFILE2_PROGRESS_STOP     = 2;
  {$EXTERNALSYM COPYFILE2_PROGRESS_QUIET}
  COPYFILE2_PROGRESS_QUIET    = 3;
  {$EXTERNALSYM COPYFILE2_PROGRESS_PAUSE}
  COPYFILE2_PROGRESS_PAUSE    = 4;

  { COPYFILE2_COPY_PHASE }
  {$EXTERNALSYM COPYFILE2_PHASE_NONE}
  COPYFILE2_PHASE_NONE              = 0;
  {$EXTERNALSYM COPYFILE2_PHASE_PREPARE_SOURCE}
  COPYFILE2_PHASE_PREPARE_SOURCE    = 1;
  {$EXTERNALSYM COPYFILE2_PHASE_PREPARE_DEST}
  COPYFILE2_PHASE_PREPARE_DEST      = 2;
  {$EXTERNALSYM COPYFILE2_PHASE_READ_SOURCE}
  COPYFILE2_PHASE_READ_SOURCE       = 3;
  {$EXTERNALSYM COPYFILE2_PHASE_WRITE_DESTINATION}
  COPYFILE2_PHASE_WRITE_DESTINATION = 4;
  {$EXTERNALSYM COPYFILE2_PHASE_SERVER_COPY}
  COPYFILE2_PHASE_SERVER_COPY       = 5;
  {$EXTERNALSYM COPYFILE2_PHASE_NAMEGRAFT_COPY}
  COPYFILE2_PHASE_NAMEGRAFT_COPY    = 6;

type
  {$EXTERNALSYM COPYFILE2_MESSAGE_TYPE}
  COPYFILE2_MESSAGE_TYPE = Integer;
  {$EXTERNALSYM COPYFILE2_MESSAGE_ACTION}
  COPYFILE2_MESSAGE_ACTION = Integer;
  {$EXTERNALSYM COPYFILE2_COPY_PHASE}
  COPYFILE2_COPY_PHASE = Integer;

  { The message of a CopyFile2 progress callback; Info is selected by Type_. }
  PCopyFile2Message = ^TCopyFile2Message;
  {$EXTERNALSYM COPYFILE2_MESSAGE}
  COPYFILE2_MESSAGE = record
    Type_: COPYFILE2_MESSAGE_TYPE;         // C name: Type
    dwPadding: DWORD;
    Info: record
      case Integer of
        0: (ChunkStarted: record
              dwStreamNumber: DWORD;
              dwReserved: DWORD;
              hSourceFile: THandle;
              hDestinationFile: THandle;
              uliChunkNumber: UInt64;
              uliChunkSize: UInt64;
              uliStreamSize: UInt64;
              uliTotalFileSize: UInt64;
            end);
        1: (ChunkFinished: record
              dwStreamNumber: DWORD;
              dwFlags: DWORD;
              hSourceFile: THandle;
              hDestinationFile: THandle;
              uliChunkNumber: UInt64;
              uliChunkSize: UInt64;
              uliStreamSize: UInt64;
              uliStreamBytesTransferred: UInt64;
              uliTotalFileSize: UInt64;
              uliTotalBytesTransferred: UInt64;
            end);
        2: (StreamStarted: record
              dwStreamNumber: DWORD;
              dwReserved: DWORD;
              hSourceFile: THandle;
              hDestinationFile: THandle;
              uliStreamSize: UInt64;
              uliTotalFileSize: UInt64;
            end);
        3: (StreamFinished: record
              dwStreamNumber: DWORD;
              dwReserved: DWORD;
              hSourceFile: THandle;
              hDestinationFile: THandle;
              uliStreamSize: UInt64;
              uliStreamBytesTransferred: UInt64;
              uliTotalFileSize: UInt64;
              uliTotalBytesTransferred: UInt64;
            end);
        4: (PollContinue: record
              dwReserved: DWORD;
            end);
        5: (Error: record
              CopyPhase: COPYFILE2_COPY_PHASE;
              dwStreamNumber: DWORD;
              hrFailure: HRESULT;
              dwReserved: DWORD;
              uliChunkNumber: UInt64;
              uliStreamSize: UInt64;
              uliStreamBytesTransferred: UInt64;
              uliTotalFileSize: UInt64;
              uliTotalBytesTransferred: UInt64;
            end);
    end;
  end;
  TCopyFile2Message = COPYFILE2_MESSAGE;

  {$EXTERNALSYM PCOPYFILE2_PROGRESS_ROUTINE}
  PCOPYFILE2_PROGRESS_ROUTINE = function(pMessage: PCopyFile2Message;
    pvCallbackContext: Pointer): COPYFILE2_MESSAGE_ACTION; stdcall;

  PCopyFile2ExtendedParameters = ^TCopyFile2ExtendedParameters;
  {$EXTERNALSYM COPYFILE2_EXTENDED_PARAMETERS}
  COPYFILE2_EXTENDED_PARAMETERS = record
    dwSize: DWORD;                         // SizeOf(TCopyFile2ExtendedParameters)
    dwCopyFlags: DWORD;                    // COPY_FILE_*
    pfCancel: PBOOL;
    pProgressRoutine: PCOPYFILE2_PROGRESS_ROUTINE;
    pvCallbackContext: Pointer;
  end;
  TCopyFile2ExtendedParameters = COPYFILE2_EXTENDED_PARAMETERS;

{ Windows 2000. Fallback: exact emulation with GetFileSize / SetFilePointer
  (lpNewFilePointer may be nil). }
{$EXTERNALSYM GetFileSizeEx}
function GetFileSizeEx(hFile: THandle; out lpFileSize: Int64): BOOL; stdcall;
{$EXTERNALSYM SetFilePointerEx}
function SetFilePointerEx(hFile: THandle; liDistanceToMove: Int64; lpNewFilePointer: PInt64;
  dwMoveMethod: DWORD): BOOL; stdcall;

{ Windows Vista. lpFileInformation: the record of FileInformationClass.
  Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetFileInformationByHandleEx}
function GetFileInformationByHandleEx(hFile: THandle;
  FileInformationClass: FILE_INFO_BY_HANDLE_CLASS; lpFileInformation: Pointer;
  dwBufferSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM SetFileInformationByHandle}
function SetFileInformationByHandle(hFile: THandle;
  FileInformationClass: FILE_INFO_BY_HANDLE_CLASS; lpFileInformation: Pointer;
  dwBufferSize: DWORD): BOOL; stdcall;

{ Windows 2000. lpBackupFileName may be nil. Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM ReplaceFile}
function ReplaceFile(lpReplacedFileName, lpReplacementFileName, lpBackupFileName: PChar;
  dwReplaceFlags: DWORD; lpExclude, lpReserved: Pointer): BOOL; stdcall;
{$EXTERNALSYM ReplaceFileA}
function ReplaceFileA(lpReplacedFileName, lpReplacementFileName, lpBackupFileName: PAnsiChar;
  dwReplaceFlags: DWORD; lpExclude, lpReserved: Pointer): BOOL; stdcall;
{$EXTERNALSYM ReplaceFileW}
function ReplaceFileW(lpReplacedFileName, lpReplacementFileName, lpBackupFileName: PWideChar;
  dwReplaceFlags: DWORD; lpExclude, lpReserved: Pointer): BOOL; stdcall;

{ Windows 2000. Returns the length (without null) or, if the buffer is too
  small, the required size; 0 on error. Fallback: 0
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetLongPathName}
function GetLongPathName(lpszShortPath, lpszLongPath: PChar; cchBuffer: DWORD): DWORD; stdcall;
{$EXTERNALSYM GetLongPathNameA}
function GetLongPathNameA(lpszShortPath, lpszLongPath: PAnsiChar; cchBuffer: DWORD): DWORD; stdcall;
{$EXTERNALSYM GetLongPathNameW}
function GetLongPathNameW(lpszShortPath, lpszLongPath: PWideChar; cchBuffer: DWORD): DWORD; stdcall;

{ Windows 2000 (GetVolumeInformationByHandleW: Windows Vista). Volume names
  have the form "\\?\Volume<GUID>\". Fallback: False / 0, FindFirstVolume
  INVALID_HANDLE_VALUE (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetVolumePathName}
function GetVolumePathName(lpszFileName, lpszVolumePathName: PChar;
  cchBufferLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetVolumePathNameA}
function GetVolumePathNameA(lpszFileName, lpszVolumePathName: PAnsiChar;
  cchBufferLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetVolumePathNameW}
function GetVolumePathNameW(lpszFileName, lpszVolumePathName: PWideChar;
  cchBufferLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetVolumeNameForVolumeMountPoint}
function GetVolumeNameForVolumeMountPoint(lpszVolumeMountPoint, lpszVolumeName: PChar;
  cchBufferLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetVolumeNameForVolumeMountPointA}
function GetVolumeNameForVolumeMountPointA(lpszVolumeMountPoint, lpszVolumeName: PAnsiChar;
  cchBufferLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetVolumeNameForVolumeMountPointW}
function GetVolumeNameForVolumeMountPointW(lpszVolumeMountPoint, lpszVolumeName: PWideChar;
  cchBufferLength: DWORD): BOOL; stdcall;
{ Windows XP. lpszVolumePathNames receives a double-null terminated list. }
{$EXTERNALSYM GetVolumePathNamesForVolumeName}
function GetVolumePathNamesForVolumeName(lpszVolumeName, lpszVolumePathNames: PChar;
  cchBufferLength: DWORD; out lpcchReturnLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetVolumePathNamesForVolumeNameA}
function GetVolumePathNamesForVolumeNameA(lpszVolumeName, lpszVolumePathNames: PAnsiChar;
  cchBufferLength: DWORD; out lpcchReturnLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetVolumePathNamesForVolumeNameW}
function GetVolumePathNamesForVolumeNameW(lpszVolumeName, lpszVolumePathNames: PWideChar;
  cchBufferLength: DWORD; out lpcchReturnLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM FindFirstVolume}
function FindFirstVolume(lpszVolumeName: PChar; cchBufferLength: DWORD): THandle; stdcall;
{$EXTERNALSYM FindFirstVolumeA}
function FindFirstVolumeA(lpszVolumeName: PAnsiChar; cchBufferLength: DWORD): THandle; stdcall;
{$EXTERNALSYM FindFirstVolumeW}
function FindFirstVolumeW(lpszVolumeName: PWideChar; cchBufferLength: DWORD): THandle; stdcall;
{$EXTERNALSYM FindNextVolume}
function FindNextVolume(hFindVolume: THandle; lpszVolumeName: PChar;
  cchBufferLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM FindNextVolumeA}
function FindNextVolumeA(hFindVolume: THandle; lpszVolumeName: PAnsiChar;
  cchBufferLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM FindNextVolumeW}
function FindNextVolumeW(hFindVolume: THandle; lpszVolumeName: PWideChar;
  cchBufferLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM FindVolumeClose}
function FindVolumeClose(hFindVolume: THandle): BOOL; stdcall;
{ Every pointer may be nil. }
{$EXTERNALSYM GetVolumeInformationByHandleW}
function GetVolumeInformationByHandleW(hFile: THandle; lpVolumeNameBuffer: PWideChar;
  nVolumeNameSize: DWORD; lpVolumeSerialNumber, lpMaximumComponentLength,
  lpFileSystemFlags: LPDWORD; lpFileSystemNameBuffer: PWideChar;
  nFileSystemNameSize: DWORD): BOOL; stdcall;

{ Windows 8. pExtendedParameters may be nil. Fallback: E_NOTIMPL. }
{$EXTERNALSYM CopyFile2}
function CopyFile2(pwszExistingFileName, pwszNewFileName: PWideChar;
  pExtendedParameters: PCopyFile2ExtendedParameters): HRESULT; stdcall;

{ Windows 11 (Windows 10 with the 2022 updates). Same as GetTempPath, but
  processes running as SYSTEM get a private folder. Fallback: GetTempPath. }
{$EXTERNALSYM GetTempPath2}
function GetTempPath2(BufferLength: DWORD; Buffer: PChar): DWORD; stdcall;
{$EXTERNALSYM GetTempPath2A}
function GetTempPath2A(BufferLength: DWORD; Buffer: PAnsiChar): DWORD; stdcall;
{$EXTERNALSYM GetTempPath2W}
function GetTempPath2W(BufferLength: DWORD; Buffer: PWideChar): DWORD; stdcall;

{ Windows Vista. lpFindStreamData: TWin32FindStreamData. Fallback:
  INVALID_HANDLE_VALUE / False (ERROR_CALL_NOT_IMPLEMENTED); close the
  handles with FindClose. }
{$EXTERNALSYM FindFirstStreamW}
function FindFirstStreamW(lpFileName: PWideChar; InfoLevel: STREAM_INFO_LEVELS;
  lpFindStreamData: Pointer; dwFlags: DWORD): THandle; stdcall;
{$EXTERNALSYM FindNextStreamW}
function FindNextStreamW(hFindStream: THandle; lpFindStreamData: Pointer): BOOL; stdcall;
{ Windows Vista: the hard links of a file. StringLength: in = size of
  LinkName in characters, out = the length needed. }
{$EXTERNALSYM FindFirstFileNameW}
function FindFirstFileNameW(lpFileName: PWideChar; dwFlags: DWORD; var StringLength: DWORD;
  LinkName: PWideChar): THandle; stdcall;
{$EXTERNALSYM FindNextFileNameW}
function FindNextFileNameW(hFindStream: THandle; var StringLength: DWORD;
  LinkName: PWideChar): BOOL; stdcall;
{ Windows Vista. Fallback: INVALID_HANDLE_VALUE (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM OpenFileById}
function OpenFileById(hVolumeHint: THandle; const lpFileId: TFileIdDescriptor;
  dwDesiredAccess, dwShareMode: DWORD; lpSecurityAttributes: PSecurityAttributes;
  dwFlagsAndAttributes: DWORD): THandle; stdcall;
{$EXTERNALSYM ReOpenFile}
function ReOpenFile(hOriginalFile: THandle; dwDesiredAccess, dwShareMode,
  dwFlagsAndAttributes: DWORD): THandle; stdcall;

{ ====== Asynchronous I/O (ioapiset.h, winbase.h) ========================== }

type
  POverlappedEntry = ^TOverlappedEntry;
  {$EXTERNALSYM _OVERLAPPED_ENTRY}
  _OVERLAPPED_ENTRY = record
    lpCompletionKey: ULONG_PTR;
    lpOverlapped: POverlapped;
    Internal: ULONG_PTR;
    dwNumberOfBytesTransferred: DWORD;
  end;
  {$EXTERNALSYM OVERLAPPED_ENTRY}
  OVERLAPPED_ENTRY = _OVERLAPPED_ENTRY;
  {$EXTERNALSYM LPOVERLAPPED_ENTRY}
  LPOVERLAPPED_ENTRY = POverlappedEntry;
  TOverlappedEntry = _OVERLAPPED_ENTRY;

const
  { SetFileCompletionNotificationModes }
  {$EXTERNALSYM FILE_SKIP_COMPLETION_PORT_ON_SUCCESS}
  FILE_SKIP_COMPLETION_PORT_ON_SUCCESS = $1;
  {$EXTERNALSYM FILE_SKIP_SET_EVENT_ON_HANDLE}
  FILE_SKIP_SET_EVENT_ON_HANDLE        = $2;

{ Windows Vista (GetOverlappedResultEx: Windows 8). lpOverlapped = nil
  cancels all I/O of the handle in the process. Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM CancelIoEx}
function CancelIoEx(hFile: THandle; lpOverlapped: POverlapped): BOOL; stdcall;
{$EXTERNALSYM CancelSynchronousIo}
function CancelSynchronousIo(hThread: THandle): BOOL; stdcall;
{$EXTERNALSYM GetQueuedCompletionStatusEx}
function GetQueuedCompletionStatusEx(CompletionPort: THandle;
  lpCompletionPortEntries: POverlappedEntry; ulCount: ULONG; out ulNumEntriesRemoved: ULONG;
  dwMilliseconds: DWORD; fAlertable: BOOL): BOOL; stdcall;
{$EXTERNALSYM SetFileCompletionNotificationModes}
function SetFileCompletionNotificationModes(FileHandle: THandle; Flags: UCHAR): BOOL; stdcall;
{$EXTERNALSYM GetOverlappedResultEx}
function GetOverlappedResultEx(hFile: THandle; const lpOverlapped: TOverlapped;
  out lpNumberOfBytesTransferred: DWORD; dwMilliseconds: DWORD; bAlertable: BOOL): BOOL; stdcall;

{ ====== Named pipes (winbase.h, Windows Vista) ============================ }

{ Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetNamedPipeClientProcessId}
function GetNamedPipeClientProcessId(Pipe: THandle; out ClientProcessId: ULONG): BOOL; stdcall;
{$EXTERNALSYM GetNamedPipeClientSessionId}
function GetNamedPipeClientSessionId(Pipe: THandle; out ClientSessionId: ULONG): BOOL; stdcall;
{$EXTERNALSYM GetNamedPipeServerProcessId}
function GetNamedPipeServerProcessId(Pipe: THandle; out ServerProcessId: ULONG): BOOL; stdcall;
{$EXTERNALSYM GetNamedPipeServerSessionId}
function GetNamedPipeServerSessionId(Pipe: THandle; out ServerSessionId: ULONG): BOOL; stdcall;

{ ====== Memory and processors (sysinfoapi.h, winnt.h) ===================== }

type
  PMemoryStatusEx = ^TMemoryStatusEx;
  {$EXTERNALSYM _MEMORYSTATUSEX}
  _MEMORYSTATUSEX = record
    dwLength: DWORD;                       // SizeOf(TMemoryStatusEx)
    dwMemoryLoad: DWORD;
    ullTotalPhys: UInt64;
    ullAvailPhys: UInt64;
    ullTotalPageFile: UInt64;
    ullAvailPageFile: UInt64;
    ullTotalVirtual: UInt64;
    ullAvailVirtual: UInt64;
    ullAvailExtendedVirtual: UInt64;
  end;
  {$EXTERNALSYM MEMORYSTATUSEX}
  MEMORYSTATUSEX = _MEMORYSTATUSEX;
  {$EXTERNALSYM LPMEMORYSTATUSEX}
  LPMEMORYSTATUSEX = PMemoryStatusEx;
  TMemoryStatusEx = _MEMORYSTATUSEX;

{ Windows 2000. Set lpBuffer.dwLength first. Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GlobalMemoryStatusEx}
function GlobalMemoryStatusEx(var lpBuffer: TMemoryStatusEx): BOOL; stdcall;
{ Windows Vista SP1. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetPhysicallyInstalledSystemMemory}
function GetPhysicallyInstalledSystemMemory(out TotalMemoryInKilobytes: UInt64): BOOL; stdcall;

type
  {$EXTERNALSYM LOGICAL_PROCESSOR_RELATIONSHIP}
  LOGICAL_PROCESSOR_RELATIONSHIP = Integer;
  {$EXTERNALSYM PROCESSOR_CACHE_TYPE}
  PROCESSOR_CACHE_TYPE = Integer;
  {$EXTERNALSYM KAFFINITY}
  KAFFINITY = ULONG_PTR;

const
  { LOGICAL_PROCESSOR_RELATIONSHIP }
  {$EXTERNALSYM RelationProcessorCore}
  RelationProcessorCore    = 0;
  {$EXTERNALSYM RelationNumaNode}
  RelationNumaNode         = 1;
  {$EXTERNALSYM RelationCache}
  RelationCache            = 2;
  {$EXTERNALSYM RelationProcessorPackage}
  RelationProcessorPackage = 3;
  {$EXTERNALSYM RelationGroup}
  RelationGroup            = 4;
  {$EXTERNALSYM RelationProcessorDie}
  RelationProcessorDie     = 5;
  {$EXTERNALSYM RelationNumaNodeEx}
  RelationNumaNodeEx       = 6;
  {$EXTERNALSYM RelationProcessorModule}
  RelationProcessorModule  = 7;
  {$EXTERNALSYM RelationAll}
  RelationAll              = $FFFF;

  { PROCESSOR_CACHE_TYPE }
  {$EXTERNALSYM CacheUnified}
  CacheUnified     = 0;
  {$EXTERNALSYM CacheInstruction}
  CacheInstruction = 1;
  {$EXTERNALSYM CacheData}
  CacheData        = 2;
  {$EXTERNALSYM CacheTrace}
  CacheTrace       = 3;

  { SYSTEM_LOGICAL_PROCESSOR_INFORMATION.ProcessorCore.Flags,
    PROCESSOR_RELATIONSHIP.Flags }
  {$EXTERNALSYM LTP_PC_SMT}
  LTP_PC_SMT = $1;

  {$EXTERNALSYM ALL_PROCESSOR_GROUPS}
  ALL_PROCESSOR_GROUPS = $FFFF;

type
  PCacheDescriptor = ^TCacheDescriptor;
  {$EXTERNALSYM _CACHE_DESCRIPTOR}
  _CACHE_DESCRIPTOR = record
    Level: Byte;
    Associativity: Byte;
    LineSize: Word;
    Size: DWORD;
    Type_: PROCESSOR_CACHE_TYPE;           // C name: Type
  end;
  {$EXTERNALSYM CACHE_DESCRIPTOR}
  CACHE_DESCRIPTOR = _CACHE_DESCRIPTOR;
  {$EXTERNALSYM PCACHE_DESCRIPTOR}
  PCACHE_DESCRIPTOR = PCacheDescriptor;
  TCacheDescriptor = _CACHE_DESCRIPTOR;

  PSystemLogicalProcessorInformation = ^TSystemLogicalProcessorInformation;
  {$EXTERNALSYM _SYSTEM_LOGICAL_PROCESSOR_INFORMATION}
  _SYSTEM_LOGICAL_PROCESSOR_INFORMATION = record
    ProcessorMask: ULONG_PTR;
    Relationship: LOGICAL_PROCESSOR_RELATIONSHIP;
    case Integer of
      0: (ProcessorCore: record
            Flags: Byte;
          end);
      1: (NumaNode: record
            NodeNumber: DWORD;
          end);
      2: (Cache: TCacheDescriptor);
      3: (Reserved: array[0..1] of UInt64);
  end;
  {$EXTERNALSYM SYSTEM_LOGICAL_PROCESSOR_INFORMATION}
  SYSTEM_LOGICAL_PROCESSOR_INFORMATION = _SYSTEM_LOGICAL_PROCESSOR_INFORMATION;
  {$EXTERNALSYM PSYSTEM_LOGICAL_PROCESSOR_INFORMATION}
  PSYSTEM_LOGICAL_PROCESSOR_INFORMATION = PSystemLogicalProcessorInformation;
  TSystemLogicalProcessorInformation = _SYSTEM_LOGICAL_PROCESSOR_INFORMATION;

  PGroupAffinity = ^TGroupAffinity;
  {$EXTERNALSYM _GROUP_AFFINITY}
  _GROUP_AFFINITY = record
    Mask: KAFFINITY;
    Group: Word;
    Reserved: array[0..2] of Word;
  end;
  {$EXTERNALSYM GROUP_AFFINITY}
  GROUP_AFFINITY = _GROUP_AFFINITY;
  {$EXTERNALSYM PGROUP_AFFINITY}
  PGROUP_AFFINITY = PGroupAffinity;
  TGroupAffinity = _GROUP_AFFINITY;

  PProcessorRelationship = ^TProcessorRelationship;
  {$EXTERNALSYM _PROCESSOR_RELATIONSHIP}
  _PROCESSOR_RELATIONSHIP = record
    Flags: Byte;                           // LTP_PC_SMT
    EfficiencyClass: Byte;                 // Windows 10
    Reserved: array[0..19] of Byte;
    GroupCount: Word;
    GroupMask: array[0..0] of TGroupAffinity;   // GroupCount entries
  end;
  {$EXTERNALSYM PROCESSOR_RELATIONSHIP}
  PROCESSOR_RELATIONSHIP = _PROCESSOR_RELATIONSHIP;
  {$EXTERNALSYM PPROCESSOR_RELATIONSHIP}
  PPROCESSOR_RELATIONSHIP = PProcessorRelationship;
  TProcessorRelationship = _PROCESSOR_RELATIONSHIP;

  PNumaNodeRelationship = ^TNumaNodeRelationship;
  {$EXTERNALSYM _NUMA_NODE_RELATIONSHIP}
  _NUMA_NODE_RELATIONSHIP = record
    NodeNumber: DWORD;
    Reserved: array[0..17] of Byte;
    GroupCount: Word;                      // Windows 11 / Server 2022; 0 before
    case Integer of
      0: (GroupMask: TGroupAffinity);
      1: (GroupMasks: array[0..0] of TGroupAffinity);
  end;
  {$EXTERNALSYM NUMA_NODE_RELATIONSHIP}
  NUMA_NODE_RELATIONSHIP = _NUMA_NODE_RELATIONSHIP;
  {$EXTERNALSYM PNUMA_NODE_RELATIONSHIP}
  PNUMA_NODE_RELATIONSHIP = PNumaNodeRelationship;
  TNumaNodeRelationship = _NUMA_NODE_RELATIONSHIP;

  PCacheRelationship = ^TCacheRelationship;
  {$EXTERNALSYM _CACHE_RELATIONSHIP}
  _CACHE_RELATIONSHIP = record
    Level: Byte;
    Associativity: Byte;
    LineSize: Word;
    CacheSize: DWORD;
    Type_: PROCESSOR_CACHE_TYPE;           // C name: Type
    Reserved: array[0..17] of Byte;
    GroupCount: Word;                      // Windows 11 / Server 2022; 0 before
    case Integer of
      0: (GroupMask: TGroupAffinity);
      1: (GroupMasks: array[0..0] of TGroupAffinity);
  end;
  {$EXTERNALSYM CACHE_RELATIONSHIP}
  CACHE_RELATIONSHIP = _CACHE_RELATIONSHIP;
  {$EXTERNALSYM PCACHE_RELATIONSHIP}
  PCACHE_RELATIONSHIP = PCacheRelationship;
  TCacheRelationship = _CACHE_RELATIONSHIP;

  PProcessorGroupInfo = ^TProcessorGroupInfo;
  {$EXTERNALSYM _PROCESSOR_GROUP_INFO}
  _PROCESSOR_GROUP_INFO = record
    MaximumProcessorCount: Byte;
    ActiveProcessorCount: Byte;
    Reserved: array[0..37] of Byte;
    ActiveProcessorMask: KAFFINITY;
  end;
  {$EXTERNALSYM PROCESSOR_GROUP_INFO}
  PROCESSOR_GROUP_INFO = _PROCESSOR_GROUP_INFO;
  {$EXTERNALSYM PPROCESSOR_GROUP_INFO}
  PPROCESSOR_GROUP_INFO = PProcessorGroupInfo;
  TProcessorGroupInfo = _PROCESSOR_GROUP_INFO;

  PGroupRelationship = ^TGroupRelationship;
  {$EXTERNALSYM _GROUP_RELATIONSHIP}
  _GROUP_RELATIONSHIP = record
    MaximumGroupCount: Word;
    ActiveGroupCount: Word;
    Reserved: array[0..19] of Byte;
    GroupInfo: array[0..0] of TProcessorGroupInfo;   // ActiveGroupCount entries
  end;
  {$EXTERNALSYM GROUP_RELATIONSHIP}
  GROUP_RELATIONSHIP = _GROUP_RELATIONSHIP;
  {$EXTERNALSYM PGROUP_RELATIONSHIP}
  PGROUP_RELATIONSHIP = PGroupRelationship;
  TGroupRelationship = _GROUP_RELATIONSHIP;

  { Variable size: the next entry follows after Size bytes. }
  PSystemLogicalProcessorInformationEx = ^TSystemLogicalProcessorInformationEx;
  {$EXTERNALSYM _SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX}
  _SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX = record
    Relationship: LOGICAL_PROCESSOR_RELATIONSHIP;
    Size: DWORD;
    case Integer of
      0: (Processor: TProcessorRelationship);
      1: (NumaNode: TNumaNodeRelationship);
      2: (Cache: TCacheRelationship);
      3: (Group: TGroupRelationship);
  end;
  {$EXTERNALSYM SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX}
  SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX = _SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX;
  {$EXTERNALSYM PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX}
  PSYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX = PSystemLogicalProcessorInformationEx;
  TSystemLogicalProcessorInformationEx = _SYSTEM_LOGICAL_PROCESSOR_INFORMATION_EX;

{ Windows XP SP3 (Ex: Windows 7). Buffer = nil with ReturnedLength = 0 asks
  for the size (ERROR_INSUFFICIENT_BUFFER). Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetLogicalProcessorInformation}
function GetLogicalProcessorInformation(Buffer: PSystemLogicalProcessorInformation;
  var ReturnedLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetLogicalProcessorInformationEx}
function GetLogicalProcessorInformationEx(RelationshipType: LOGICAL_PROCESSOR_RELATIONSHIP;
  Buffer: PSystemLogicalProcessorInformationEx; var ReturnedLength: DWORD): BOOL; stdcall;
{ Windows 7. Fallback (one processor group): the processor count of
  GetSystemInfo for group 0 and ALL_PROCESSOR_GROUPS, else 0; the group
  counts are 1. }
{$EXTERNALSYM GetActiveProcessorCount}
function GetActiveProcessorCount(GroupNumber: Word): DWORD; stdcall;
{$EXTERNALSYM GetMaximumProcessorCount}
function GetMaximumProcessorCount(GroupNumber: Word): DWORD; stdcall;
{$EXTERNALSYM GetActiveProcessorGroupCount}
function GetActiveProcessorGroupCount: Word; stdcall;
{$EXTERNALSYM GetMaximumProcessorGroupCount}
function GetMaximumProcessorGroupCount: Word; stdcall;

{ Windows XP SP1. Pointers may be nil. Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetSystemTimes}
function GetSystemTimes(lpIdleTime, lpKernelTime, lpUserTime: PFileTime): BOOL; stdcall;

{ ====== WOW64, firmware, computer name (wow64apiset.h, winbase.h) ======== }

{ Windows 10 1511. pProcessMachine receives IMAGE_FILE_MACHINE_UNKNOWN when
  the process does not run under WOW64; pNativeMachine may be nil.
  Fallback: emulated with IsWow64Process and GetNativeSystemInfo. }
{$EXTERNALSYM IsWow64Process2}
function IsWow64Process2(hProcess: THandle; out pProcessMachine: Word;
  pNativeMachine: PWord): BOOL; stdcall;
{ Windows XP. Returns 0 with ERROR_CALL_NOT_IMPLEMENTED on 32-bit Windows;
  the fallback does the same. }
{$EXTERNALSYM GetSystemWow64Directory}
function GetSystemWow64Directory(lpBuffer: PChar; uSize: UINT): UINT; stdcall;
{$EXTERNALSYM GetSystemWow64DirectoryA}
function GetSystemWow64DirectoryA(lpBuffer: PAnsiChar; uSize: UINT): UINT; stdcall;
{$EXTERNALSYM GetSystemWow64DirectoryW}
function GetSystemWow64DirectoryW(lpBuffer: PWideChar; uSize: UINT): UINT; stdcall;
{ Windows XP x64 / Vista; for the calling thread. Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED): such systems do not redirect. }
{$EXTERNALSYM Wow64DisableWow64FsRedirection}
function Wow64DisableWow64FsRedirection(out OldValue: Pointer): BOOL; stdcall;
{$EXTERNALSYM Wow64RevertWow64FsRedirection}
function Wow64RevertWow64FsRedirection(OlValue: Pointer): BOOL; stdcall;

type
  {$EXTERNALSYM FIRMWARE_TYPE}
  FIRMWARE_TYPE = Integer;

const
  {$EXTERNALSYM FirmwareTypeUnknown}
  FirmwareTypeUnknown = 0;
  {$EXTERNALSYM FirmwareTypeBios}
  FirmwareTypeBios    = 1;
  {$EXTERNALSYM FirmwareTypeUefi}
  FirmwareTypeUefi    = 2;
  {$EXTERNALSYM FirmwareTypeMax}
  FirmwareTypeMax     = 3;

{ Windows 8. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED), FirmwareType =
  FirmwareTypeUnknown. }
{$EXTERNALSYM GetFirmwareType}
function GetFirmwareType(out FirmwareType: FIRMWARE_TYPE): BOOL; stdcall;

type
  {$EXTERNALSYM COMPUTER_NAME_FORMAT}
  COMPUTER_NAME_FORMAT = Integer;

const
  {$EXTERNALSYM ComputerNameNetBIOS}
  ComputerNameNetBIOS                   = 0;
  {$EXTERNALSYM ComputerNameDnsHostname}
  ComputerNameDnsHostname               = 1;
  {$EXTERNALSYM ComputerNameDnsDomain}
  ComputerNameDnsDomain                 = 2;
  {$EXTERNALSYM ComputerNameDnsFullyQualified}
  ComputerNameDnsFullyQualified         = 3;
  {$EXTERNALSYM ComputerNamePhysicalNetBIOS}
  ComputerNamePhysicalNetBIOS           = 4;
  {$EXTERNALSYM ComputerNamePhysicalDnsHostname}
  ComputerNamePhysicalDnsHostname       = 5;
  {$EXTERNALSYM ComputerNamePhysicalDnsDomain}
  ComputerNamePhysicalDnsDomain         = 6;
  {$EXTERNALSYM ComputerNamePhysicalDnsFullyQualified}
  ComputerNamePhysicalDnsFullyQualified = 7;

{ Windows 2000. nSize: in = size of lpBuffer in characters including the
  null, out = length without it (or the size needed). Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetComputerNameEx}
function GetComputerNameEx(NameType: COMPUTER_NAME_FORMAT; lpBuffer: PChar;
  var nSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetComputerNameExA}
function GetComputerNameExA(NameType: COMPUTER_NAME_FORMAT; lpBuffer: PAnsiChar;
  var nSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetComputerNameExW}
function GetComputerNameExW(NameType: COMPUTER_NAME_FORMAT; lpBuffer: PWideChar;
  var nSize: DWORD): BOOL; stdcall;

{ ====== UI languages, locale names, formats (winnls.h, datetimeapi.h) ===== }

const
  { Language list flags (Get/Set*PreferredUILanguages) }
  {$EXTERNALSYM MUI_LANGUAGE_ID}
  MUI_LANGUAGE_ID                     = $4;
  {$EXTERNALSYM MUI_LANGUAGE_NAME}
  MUI_LANGUAGE_NAME                   = $8;
  {$EXTERNALSYM MUI_MERGE_SYSTEM_FALLBACK}
  MUI_MERGE_SYSTEM_FALLBACK           = $10;
  {$EXTERNALSYM MUI_MERGE_USER_FALLBACK}
  MUI_MERGE_USER_FALLBACK             = $20;
  {$EXTERNALSYM MUI_UI_FALLBACK}
  MUI_UI_FALLBACK                     = MUI_MERGE_SYSTEM_FALLBACK or MUI_MERGE_USER_FALLBACK;
  {$EXTERNALSYM MUI_THREAD_LANGUAGES}
  MUI_THREAD_LANGUAGES                = $40;
  {$EXTERNALSYM MUI_CONSOLE_FILTER}
  MUI_CONSOLE_FILTER                  = $100;
  {$EXTERNALSYM MUI_COMPLEX_SCRIPT_FILTER}
  MUI_COMPLEX_SCRIPT_FILTER           = $200;
  {$EXTERNALSYM MUI_RESET_FILTERS}
  MUI_RESET_FILTERS                   = $001;
  {$EXTERNALSYM MUI_MACHINE_LANGUAGE_SETTINGS}
  MUI_MACHINE_LANGUAGE_SETTINGS       = $400;

  { EnumSystemLocalesEx dwFlags }
  {$EXTERNALSYM LOCALE_ALL}
  LOCALE_ALL                  = 0;
  {$EXTERNALSYM LOCALE_WINDOWS}
  LOCALE_WINDOWS              = $00000001;
  {$EXTERNALSYM LOCALE_SUPPLEMENTAL}
  LOCALE_SUPPLEMENTAL         = $00000002;
  {$EXTERNALSYM LOCALE_ALTERNATE_SORTS}
  LOCALE_ALTERNATE_SORTS      = $00000004;
  {$EXTERNALSYM LOCALE_REPLACEMENT}
  LOCALE_REPLACEMENT          = $00000008;
  {$EXTERNALSYM LOCALE_NEUTRALDATA}
  LOCALE_NEUTRALDATA          = $00000010;
  {$EXTERNALSYM LOCALE_SPECIFICDATA}
  LOCALE_SPECIFICDATA         = $00000020;

  { FindStringOrdinal flags }
  {$EXTERNALSYM FIND_STARTSWITH}
  FIND_STARTSWITH = $00100000;
  {$EXTERNALSYM FIND_ENDSWITH}
  FIND_ENDSWITH   = $00200000;
  {$EXTERNALSYM FIND_FROMSTART}
  FIND_FROMSTART  = $00400000;
  {$EXTERNALSYM FIND_FROMEND}
  FIND_FROMEND    = $00800000;

  { GetDateFormatEx flags not in Windows.pas }
  {$EXTERNALSYM DATE_YEARMONTH}
  DATE_YEARMONTH      = $00000008;
  {$EXTERNALSYM DATE_LTRREADING}
  DATE_LTRREADING     = $00000010;
  {$EXTERNALSYM DATE_RTLREADING}
  DATE_RTLREADING     = $00000020;
  {$EXTERNALSYM DATE_AUTOLAYOUT}
  DATE_AUTOLAYOUT     = $00000040;
  {$EXTERNALSYM DATE_MONTHDAY}
  DATE_MONTHDAY       = $00000080;

type
  {$EXTERNALSYM NORM_FORM}
  NORM_FORM = Integer;

const
  {$EXTERNALSYM NormalizationOther}
  NormalizationOther = 0;
  {$EXTERNALSYM NormalizationC}
  NormalizationC     = $1;
  {$EXTERNALSYM NormalizationD}
  NormalizationD     = $2;
  {$EXTERNALSYM NormalizationKC}
  NormalizationKC    = $5;
  {$EXTERNALSYM NormalizationKD}
  NormalizationKD    = $6;

type
  { Return True to continue the enumeration. }
  {$EXTERNALSYM LOCALE_ENUMPROCEX}
  LOCALE_ENUMPROCEX = function(lpLocaleString: PWideChar; dwFlags: DWORD;
    lParam: LPARAM): BOOL; stdcall;
  TLocaleEnumProcEx = LOCALE_ENUMPROCEX;

{ Windows 2000. Fallback: GetUserDefaultLangID / GetSystemDefaultLangID. }
{$EXTERNALSYM GetUserDefaultUILanguage}
function GetUserDefaultUILanguage: LANGID; stdcall;
{$EXTERNALSYM GetSystemDefaultUILanguage}
function GetSystemDefaultUILanguage: LANGID; stdcall;
{ Windows Vista. Fallback: GetThreadUILanguage returns GetUserDefaultUILanguage;
  SetThreadUILanguage returns 0 (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetThreadUILanguage}
function GetThreadUILanguage: LANGID; stdcall;
{$EXTERNALSYM SetThreadUILanguage}
function SetThreadUILanguage(LangId: LANGID): LANGID; stdcall;

{ Windows Vista (SetProcessPreferredUILanguages: Windows 7). The language
  lists are double-null terminated; pcchLanguagesBuffer: in = size in
  characters, out = size used (0 in = ask for the size). Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetUserPreferredUILanguages}
function GetUserPreferredUILanguages(dwFlags: DWORD; out pulNumLanguages: ULONG;
  pwszLanguagesBuffer: PWideChar; var pcchLanguagesBuffer: ULONG): BOOL; stdcall;
{$EXTERNALSYM GetSystemPreferredUILanguages}
function GetSystemPreferredUILanguages(dwFlags: DWORD; out pulNumLanguages: ULONG;
  pwszLanguagesBuffer: PWideChar; var pcchLanguagesBuffer: ULONG): BOOL; stdcall;
{$EXTERNALSYM GetThreadPreferredUILanguages}
function GetThreadPreferredUILanguages(dwFlags: DWORD; out pulNumLanguages: ULONG;
  pwszLanguagesBuffer: PWideChar; var pcchLanguagesBuffer: ULONG): BOOL; stdcall;
{$EXTERNALSYM GetProcessPreferredUILanguages}
function GetProcessPreferredUILanguages(dwFlags: DWORD; out pulNumLanguages: ULONG;
  pwszLanguagesBuffer: PWideChar; var pcchLanguagesBuffer: ULONG): BOOL; stdcall;
{ pwszLanguagesBuffer = nil resets the list; pulNumLanguages may be nil. }
{$EXTERNALSYM SetThreadPreferredUILanguages}
function SetThreadPreferredUILanguages(dwFlags: DWORD; pwszLanguagesBuffer: PWideChar;
  pulNumLanguages: PULONG): BOOL; stdcall;
{$EXTERNALSYM SetProcessPreferredUILanguages}
function SetProcessPreferredUILanguages(dwFlags: DWORD; pwszLanguagesBuffer: PWideChar;
  pulNumLanguages: PULONG): BOOL; stdcall;

{ Windows Vista (ResolveLocaleName: Windows 7). The name based NLS functions
  have no correct emulation (see GetUserDefaultLocaleName): fallback 0 or
  False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetSystemDefaultLocaleName}
function GetSystemDefaultLocaleName(lpLocaleName: PWideChar; cchLocaleName: Integer): Integer; stdcall;
{$EXTERNALSYM IsValidLocaleName}
function IsValidLocaleName(lpLocaleName: PWideChar): BOOL; stdcall;
{$EXTERNALSYM ResolveLocaleName}
function ResolveLocaleName(lpNameToResolve, lpLocaleName: PWideChar;
  cchLocaleName: Integer): Integer; stdcall;
{ EnumSystemLocalesEx itself continues only while the callback returns TRUE
  (1), and Delphi returns True as -1: the callback is called through a
  bridge that passes its result on as 0 or 1, so it may return True. }
{$EXTERNALSYM EnumSystemLocalesEx}
function EnumSystemLocalesEx(lpLocaleEnumProcEx: LOCALE_ENUMPROCEX; dwFlags: DWORD;
  lParam: LPARAM; lpReserved: Pointer): BOOL; stdcall;
{ lpVersionInformation, lpReserved and sortHandle must be nil / 0. }
{$EXTERNALSYM LCMapStringEx}
function LCMapStringEx(lpLocaleName: PWideChar; dwMapFlags: DWORD; lpSrcStr: PWideChar;
  cchSrc: Integer; lpDestStr: PWideChar; cchDest: Integer; lpVersionInformation: Pointer;
  lpReserved: Pointer; sortHandle: LPARAM): Integer; stdcall;
{ lpDate / lpTime = nil: the current time; lpFormat = nil: the locale's
  format; lpCalendar must be nil. Return the length including the null. }
{$EXTERNALSYM GetDateFormatEx}
function GetDateFormatEx(lpLocaleName: PWideChar; dwFlags: DWORD; lpDate: PSystemTime;
  lpFormat: PWideChar; lpDateStr: PWideChar; cchDate: Integer;
  lpCalendar: PWideChar): Integer; stdcall;
{$EXTERNALSYM GetTimeFormatEx}
function GetTimeFormatEx(lpLocaleName: PWideChar; dwFlags: DWORD; lpTime: PSystemTime;
  lpFormat: PWideChar; lpTimeStr: PWideChar; cchTime: Integer): Integer; stdcall;
{ lpValue: digits with an optional leading '-' and one '.'. }
{$EXTERNALSYM GetNumberFormatEx}
function GetNumberFormatEx(lpLocaleName: PWideChar; dwFlags: DWORD; lpValue: PWideChar;
  lpFormat: PNumberFmtW; lpNumberStr: PWideChar; cchNumber: Integer): Integer; stdcall;
{$EXTERNALSYM GetCurrencyFormatEx}
function GetCurrencyFormatEx(lpLocaleName: PWideChar; dwFlags: DWORD; lpValue: PWideChar;
  lpFormat: PCurrencyFmtW; lpCurrencyStr: PWideChar; cchCurrency: Integer): Integer; stdcall;
{ The duration is lpDuration (if not nil) or ullDuration in 100 ns units;
  lpFormat e.g. 'hh:mm:ss'. GetDurationFormat: Windows Vista, by LCID. }
{$EXTERNALSYM GetDurationFormatEx}
function GetDurationFormatEx(lpLocaleName: PWideChar; dwFlags: DWORD; lpDuration: PSystemTime;
  ullDuration: UInt64; lpFormat: PWideChar; lpDurationStr: PWideChar;
  cchDuration: Integer): Integer; stdcall;
{$EXTERNALSYM GetDurationFormat}
function GetDurationFormat(Locale: LCID; dwFlags: DWORD; lpDuration: PSystemTime;
  ullDuration: UInt64; lpFormat: PWideChar; lpDurationStr: PWideChar;
  cchDuration: Integer): Integer; stdcall;

{ Windows 7. Returns the 0-based index of the match or -1 (GetLastError =
  ERROR_SUCCESS if not found). Fallback: -1 (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM FindStringOrdinal}
function FindStringOrdinal(dwFindStringOrdinalFlags: DWORD; lpStringSource: PWideChar;
  cchSource: Integer; lpStringValue: PWideChar; cchValue: Integer;
  bIgnoreCase: BOOL): Integer; stdcall;
{ Windows Vista (normaliz.dll), kernel32 since Windows 7. Returns the length
  written or, with cwDstLength = 0, an estimate of the size needed.
  Fallback: 0 / False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM NormalizeString}
function NormalizeString(NormForm: NORM_FORM; lpSrcString: PWideChar; cwSrcLength: Integer;
  lpDstString: PWideChar; cwDstLength: Integer): Integer; stdcall;
{$EXTERNALSYM IsNormalizedString}
function IsNormalizedString(NormForm: NORM_FORM; lpString: PWideChar;
  cwLength: Integer): BOOL; stdcall;

{ ====== Time zones (timezoneapi.h) ======================================== }

type
  PDynamicTimeZoneInformation = ^TDynamicTimeZoneInformation;
  {$EXTERNALSYM _TIME_DYNAMIC_ZONE_INFORMATION}
  _TIME_DYNAMIC_ZONE_INFORMATION = record
    Bias: Longint;
    StandardName: array[0..31] of WideChar;
    StandardDate: TSystemTime;
    StandardBias: Longint;
    DaylightName: array[0..31] of WideChar;
    DaylightDate: TSystemTime;
    DaylightBias: Longint;
    TimeZoneKeyName: array[0..127] of WideChar;
    DynamicDaylightTimeDisabled: ByteBool;   // BOOLEAN
  end;
  {$EXTERNALSYM DYNAMIC_TIME_ZONE_INFORMATION}
  DYNAMIC_TIME_ZONE_INFORMATION = _TIME_DYNAMIC_ZONE_INFORMATION;
  {$EXTERNALSYM PDYNAMIC_TIME_ZONE_INFORMATION}
  PDYNAMIC_TIME_ZONE_INFORMATION = PDynamicTimeZoneInformation;
  TDynamicTimeZoneInformation = _TIME_DYNAMIC_ZONE_INFORMATION;

{ Windows Vista. Returns TIME_ZONE_ID_UNKNOWN/STANDARD/DAYLIGHT or
  TIME_ZONE_ID_INVALID. Fallback: GetTimeZoneInformation, TimeZoneKeyName
  empty and DynamicDaylightTimeDisabled False. }
{$EXTERNALSYM GetDynamicTimeZoneInformation}
function GetDynamicTimeZoneInformation(
  out pTimeZoneInformation: TDynamicTimeZoneInformation): DWORD; stdcall;
{ Windows Vista SP1. pdtzi = nil: the current time zone. Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetTimeZoneInformationForYear}
function GetTimeZoneInformationForYear(wYear: Word; pdtzi: PDynamicTimeZoneInformation;
  out ptzi: TTimeZoneInformation): BOOL; stdcall;
{ Windows XP (the Ex functions: Windows 7). lpTimeZoneInformation = nil:
  the current time zone. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM TzSpecificLocalTimeToSystemTime}
function TzSpecificLocalTimeToSystemTime(lpTimeZoneInformation: PTimeZoneInformation;
  const lpLocalTime: TSystemTime; out lpUniversalTime: TSystemTime): BOOL; stdcall;
{$EXTERNALSYM TzSpecificLocalTimeToSystemTimeEx}
function TzSpecificLocalTimeToSystemTimeEx(lpTimeZoneInformation: PDynamicTimeZoneInformation;
  const lpLocalTime: TSystemTime; out lpUniversalTime: TSystemTime): BOOL; stdcall;
{$EXTERNALSYM SystemTimeToTzSpecificLocalTimeEx}
function SystemTimeToTzSpecificLocalTimeEx(lpTimeZoneInformation: PDynamicTimeZoneInformation;
  const lpUniversalTime: TSystemTime; out lpLocalTime: TSystemTime): BOOL; stdcall;
{ advapi32, Windows 8. Return ERROR_SUCCESS or an error code
  (ERROR_NO_MORE_ITEMS after the last zone). Fallback:
  ERROR_CALL_NOT_IMPLEMENTED. }
{$EXTERNALSYM EnumDynamicTimeZoneInformation}
function EnumDynamicTimeZoneInformation(dwIndex: DWORD;
  out lpTimeZoneInformation: TDynamicTimeZoneInformation): DWORD; stdcall;
{$EXTERNALSYM GetDynamicTimeZoneInformationEffectiveYears}
function GetDynamicTimeZoneInformationEffectiveYears(
  const lpTimeZoneInformation: TDynamicTimeZoneInformation;
  out FirstYear, LastYear: DWORD): DWORD; stdcall;

{ ====== Application restart and recovery (winbase.h, Windows Vista) ====== }

const
  {$EXTERNALSYM RESTART_MAX_CMD_LINE}
  RESTART_MAX_CMD_LINE = 1024;
  {$EXTERNALSYM RESTART_NO_CRASH}
  RESTART_NO_CRASH     = 1;
  {$EXTERNALSYM RESTART_NO_HANG}
  RESTART_NO_HANG      = 2;
  {$EXTERNALSYM RESTART_NO_PATCH}
  RESTART_NO_PATCH     = 4;
  {$EXTERNALSYM RESTART_NO_REBOOT}
  RESTART_NO_REBOOT    = 8;
  {$EXTERNALSYM RECOVERY_DEFAULT_PING_INTERVAL}
  RECOVERY_DEFAULT_PING_INTERVAL = 5000;
  {$EXTERNALSYM RECOVERY_MAX_PING_INTERVAL}
  RECOVERY_MAX_PING_INTERVAL     = 5 * 60 * 1000;

type
  {$EXTERNALSYM APPLICATION_RECOVERY_CALLBACK}
  APPLICATION_RECOVERY_CALLBACK = function(pvParameter: Pointer): DWORD; stdcall;
  TApplicationRecoveryCallback = APPLICATION_RECOVERY_CALLBACK;

{ Fallback: E_NOTIMPL; ApplicationRecoveryFinished does nothing. }
{$EXTERNALSYM RegisterApplicationRestart}
function RegisterApplicationRestart(pwzCommandline: PWideChar; dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UnregisterApplicationRestart}
function UnregisterApplicationRestart: HRESULT; stdcall;
{ pcchSize: in = size of pwzCommandline in characters; pdwFlags may be nil. }
{$EXTERNALSYM GetApplicationRestartSettings}
function GetApplicationRestartSettings(hProcess: THandle; pwzCommandline: PWideChar;
  var pcchSize: DWORD; pdwFlags: PDWORD): HRESULT; stdcall;
{$EXTERNALSYM RegisterApplicationRecoveryCallback}
function RegisterApplicationRecoveryCallback(pRecoveyCallback: APPLICATION_RECOVERY_CALLBACK;
  pvParameter: Pointer; dwPingInterval: DWORD; dwFlags: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UnregisterApplicationRecoveryCallback}
function UnregisterApplicationRecoveryCallback: HRESULT; stdcall;
{$EXTERNALSYM ApplicationRecoveryInProgress}
function ApplicationRecoveryInProgress(out pbCancelled: BOOL): HRESULT; stdcall;
{$EXTERNALSYM ApplicationRecoveryFinished}
procedure ApplicationRecoveryFinished(bSuccess: BOOL); stdcall;

{ ====== Debugging, exceptions, modules (debugapi.h, errhandlingapi.h) ===== }

const
  { Return values of exception filters and vectored handlers }
  {$EXTERNALSYM EXCEPTION_EXECUTE_HANDLER}
  EXCEPTION_EXECUTE_HANDLER    = 1;
  {$EXTERNALSYM EXCEPTION_CONTINUE_SEARCH}
  EXCEPTION_CONTINUE_SEARCH    = 0;
  {$EXTERNALSYM EXCEPTION_CONTINUE_EXECUTION}
  EXCEPTION_CONTINUE_EXECUTION = -1;

  {$EXTERNALSYM GET_MODULE_HANDLE_EX_FLAG_PIN}
  GET_MODULE_HANDLE_EX_FLAG_PIN                = $00000001;
  {$EXTERNALSYM GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT}
  GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT = $00000002;
  {$EXTERNALSYM GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS}
  GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS       = $00000004;

type
  {$EXTERNALSYM PVECTORED_EXCEPTION_HANDLER}
  PVECTORED_EXCEPTION_HANDLER = function(ExceptionInfo: PExceptionPointers): Longint; stdcall;
  TVectoredExceptionHandler = PVECTORED_EXCEPTION_HANDLER;

{ Windows XP (the continue handlers: Windows Vista). First <> 0: called
  first. Return a handle for Remove*. Fallback: nil / 0
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM AddVectoredExceptionHandler}
function AddVectoredExceptionHandler(First: ULONG; Handler: PVECTORED_EXCEPTION_HANDLER): Pointer; stdcall;
{$EXTERNALSYM RemoveVectoredExceptionHandler}
function RemoveVectoredExceptionHandler(Handle: Pointer): ULONG; stdcall;
{$EXTERNALSYM AddVectoredContinueHandler}
function AddVectoredContinueHandler(First: ULONG; Handler: PVECTORED_EXCEPTION_HANDLER): Pointer; stdcall;
{$EXTERNALSYM RemoveVectoredContinueHandler}
function RemoveVectoredContinueHandler(Handle: Pointer): ULONG; stdcall;

{ Windows NT 4 / XP. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM IsDebuggerPresent}
function IsDebuggerPresent: BOOL; stdcall;
{$EXTERNALSYM CheckRemoteDebuggerPresent}
function CheckRemoteDebuggerPresent(hProcess: THandle; out pbDebuggerPresent: BOOL): BOOL; stdcall;
{$EXTERNALSYM DebugBreakProcess}
function DebugBreakProcess(Process: THandle): BOOL; stdcall;
{$EXTERNALSYM DebugActiveProcessStop}
function DebugActiveProcessStop(dwProcessId: DWORD): BOOL; stdcall;
{$EXTERNALSYM DebugSetProcessKillOnExit}
function DebugSetProcessKillOnExit(KillOnExit: BOOL): BOOL; stdcall;

{ Windows XP. BackTrace: array of FramesToCapture pointers; BackTraceHash may
  be nil. Returns the number of frames captured; the first one is the
  caller's (the frame of this unit's wrapper is skipped). Fallback: 0. }
{$EXTERNALSYM RtlCaptureStackBackTrace}
function RtlCaptureStackBackTrace(FramesToSkip, FramesToCapture: DWORD; BackTrace: PPointer;
  BackTraceHash: PDWORD): Word; stdcall;
{ Windows XP SP2. Fallback: the pointer unchanged (DecodePointer(EncodePointer(P))
  = P holds). }
{$EXTERNALSYM EncodePointer}
function EncodePointer(Ptr: Pointer): Pointer; stdcall;
{$EXTERNALSYM DecodePointer}
function DecodePointer(Ptr: Pointer): Pointer; stdcall;

{ Windows XP. With GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS lpModuleName is an
  address inside the module. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED),
  phModule = 0. }
{$EXTERNALSYM GetModuleHandleEx}
function GetModuleHandleEx(dwFlags: DWORD; lpModuleName: PChar; out phModule: HMODULE): BOOL; stdcall;
{$EXTERNALSYM GetModuleHandleExA}
function GetModuleHandleExA(dwFlags: DWORD; lpModuleName: PAnsiChar; out phModule: HMODULE): BOOL; stdcall;
{$EXTERNALSYM GetModuleHandleExW}
function GetModuleHandleExW(dwFlags: DWORD; lpModuleName: PWideChar; out phModule: HMODULE): BOOL; stdcall;

{ ====== Power notifications (winuser.h) =================================== }

type
  {$EXTERNALSYM HPOWERNOTIFY}
  HPOWERNOTIFY = Pointer;

  { lParam of WM_POWERBROADCAST with PBT_POWERSETTINGCHANGE }
  PPowerBroadcastSetting = ^TPowerBroadcastSetting;
  {$EXTERNALSYM POWERBROADCAST_SETTING}
  POWERBROADCAST_SETTING = record
    PowerSetting: TGUID;
    DataLength: DWORD;
    Data: array[0..0] of Byte;
  end;
  {$EXTERNALSYM PPOWERBROADCAST_SETTING}
  PPOWERBROADCAST_SETTING = PPowerBroadcastSetting;
  TPowerBroadcastSetting = POWERBROADCAST_SETTING;

const
  { WM_POWERBROADCAST wParam }
  {$EXTERNALSYM PBT_APMQUERYSUSPEND}
  PBT_APMQUERYSUSPEND       = $0000;
  {$EXTERNALSYM PBT_APMQUERYSTANDBY}
  PBT_APMQUERYSTANDBY       = $0001;
  {$EXTERNALSYM PBT_APMQUERYSUSPENDFAILED}
  PBT_APMQUERYSUSPENDFAILED = $0002;
  {$EXTERNALSYM PBT_APMQUERYSTANDBYFAILED}
  PBT_APMQUERYSTANDBYFAILED = $0003;
  {$EXTERNALSYM PBT_APMSUSPEND}
  PBT_APMSUSPEND            = $0004;
  {$EXTERNALSYM PBT_APMSTANDBY}
  PBT_APMSTANDBY            = $0005;
  {$EXTERNALSYM PBT_APMRESUMECRITICAL}
  PBT_APMRESUMECRITICAL     = $0006;
  {$EXTERNALSYM PBT_APMRESUMESUSPEND}
  PBT_APMRESUMESUSPEND      = $0007;
  {$EXTERNALSYM PBT_APMRESUMESTANDBY}
  PBT_APMRESUMESTANDBY      = $0008;
  {$EXTERNALSYM PBT_APMBATTERYLOW}
  PBT_APMBATTERYLOW         = $0009;
  {$EXTERNALSYM PBT_APMPOWERSTATUSCHANGE}
  PBT_APMPOWERSTATUSCHANGE  = $000A;
  {$EXTERNALSYM PBT_APMOEMEVENT}
  PBT_APMOEMEVENT           = $000B;
  {$EXTERNALSYM PBT_APMRESUMEAUTOMATIC}
  PBT_APMRESUMEAUTOMATIC    = $0012;
  {$EXTERNALSYM PBT_POWERSETTINGCHANGE}
  PBT_POWERSETTINGCHANGE    = $8013;

  { RegisterPowerSettingNotification Flags (DEVICE_NOTIFY_WINDOW_HANDLE is in
    Windows.pas; DEVICE_NOTIFY_CALLBACK belongs to powrprof.h) }
  {$EXTERNALSYM DEVICE_NOTIFY_SERVICE_HANDLE}
  DEVICE_NOTIFY_SERVICE_HANDLE = $00000001;

  { Power settings for RegisterPowerSettingNotification (winnt.h). The data
    of each is a DWORD unless noted. }
  {$EXTERNALSYM GUID_ACDC_POWER_SOURCE}
  GUID_ACDC_POWER_SOURCE: TGUID = '{5D3E9A59-E9D5-4B00-A6BD-FF34FF516548}';           // 0 AC, 1 DC, 2 short term
  {$EXTERNALSYM GUID_BATTERY_PERCENTAGE_REMAINING}
  GUID_BATTERY_PERCENTAGE_REMAINING: TGUID = '{A7AD8041-B45A-4CAE-87A3-EECBB468A9E1}';
  {$EXTERNALSYM GUID_CONSOLE_DISPLAY_STATE}
  GUID_CONSOLE_DISPLAY_STATE: TGUID = '{6FE69556-704A-47A0-8F24-C28D936FDA47}';       // 0 off, 1 on, 2 dimmed
  {$EXTERNALSYM GUID_MONITOR_POWER_ON}
  GUID_MONITOR_POWER_ON: TGUID = '{02731015-4510-4526-99E6-E5A17EBD1AEA}';
  {$EXTERNALSYM GUID_SESSION_DISPLAY_STATUS}
  GUID_SESSION_DISPLAY_STATUS: TGUID = '{2B84C20E-AD23-4DDF-93DB-05FFBD7EFCA5}';
  {$EXTERNALSYM GUID_SESSION_USER_PRESENCE}
  GUID_SESSION_USER_PRESENCE: TGUID = '{3C0F4548-C03F-4C4D-B9F2-237EDE686376}';
  {$EXTERNALSYM GUID_SYSTEM_AWAYMODE}
  GUID_SYSTEM_AWAYMODE: TGUID = '{98A7F580-01F7-48AA-9C0F-44352C29E5C0}';
  {$EXTERNALSYM GUID_LIDSWITCH_STATE_CHANGE}
  GUID_LIDSWITCH_STATE_CHANGE: TGUID = '{BA3E0F4D-B817-4094-A2D1-D56379E6A0F3}';
  {$EXTERNALSYM GUID_POWERSCHEME_PERSONALITY}
  GUID_POWERSCHEME_PERSONALITY: TGUID = '{245D8541-3943-4422-B025-13A784F679B7}';     // data: a GUID
  {$EXTERNALSYM GUID_ACTIVE_POWERSCHEME}
  GUID_ACTIVE_POWERSCHEME: TGUID = '{31F9F286-5084-42FE-B720-2B0264993763}';          // data: a GUID
  {$EXTERNALSYM GUID_IDLE_BACKGROUND_TASK}
  GUID_IDLE_BACKGROUND_TASK: TGUID = '{515C31D8-F734-163D-A0FD-11A08C91E8F1}';        // no data
  {$EXTERNALSYM GUID_POWER_SAVING_STATUS}
  GUID_POWER_SAVING_STATUS: TGUID = '{E00958C0-C213-4ACE-AC77-FECCED2EEEA5}';         // battery saver

{ Windows Vista. Flags: DEVICE_NOTIFY_WINDOW_HANDLE or
  DEVICE_NOTIFY_SERVICE_HANDLE. Fallback: nil / False
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM RegisterPowerSettingNotification}
function RegisterPowerSettingNotification(hRecipient: THandle; const PowerSettingGuid: TGUID;
  Flags: DWORD): HPOWERNOTIFY; stdcall;
{$EXTERNALSYM UnregisterPowerSettingNotification}
function UnregisterPowerSettingNotification(Handle: HPOWERNOTIFY): BOOL; stdcall;
{ Windows 8 (suspend and resume for processes on connected standby).
  Fallback: nil / False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM RegisterSuspendResumeNotification}
function RegisterSuspendResumeNotification(hRecipient: THandle; Flags: DWORD): HPOWERNOTIFY; stdcall;
{$EXTERNALSYM UnregisterSuspendResumeNotification}
function UnregisterSuspendResumeNotification(Handle: HPOWERNOTIFY): BOOL; stdcall;

{ ====== Raw input (winuser.h, Windows XP) ================================= }

type
  {$EXTERNALSYM HRAWINPUT}
  HRAWINPUT = THandle;

  {$EXTERNALSYM PRAWINPUTHEADER}
  PRawInputHeader = ^TRawInputHeader;
  {$EXTERNALSYM tagRAWINPUTHEADER}
  tagRAWINPUTHEADER = record
    dwType: DWORD;                         // RIM_TYPE*
    dwSize: DWORD;
    hDevice: THandle;
    wParam: WPARAM;                        // RIM_INPUT or RIM_INPUTSINK
  end;
  {$EXTERNALSYM RAWINPUTHEADER}
  RAWINPUTHEADER = tagRAWINPUTHEADER;
  TRawInputHeader = tagRAWINPUTHEADER;

  {$EXTERNALSYM PRAWMOUSE}
  PRawMouse = ^TRawMouse;
  {$EXTERNALSYM tagRAWMOUSE}
  tagRAWMOUSE = record
    usFlags: Word;                         // MOUSE_MOVE_*
    case Integer of
      0: (ulButtons: ULONG);
      1: (usButtonFlags: Word;             // RI_MOUSE_*
          usButtonData: Word;              // wheel delta (SHORT)
          ulRawButtons: ULONG;
          lLastX: Longint;
          lLastY: Longint;
          ulExtraInformation: ULONG);
  end;
  {$EXTERNALSYM RAWMOUSE}
  RAWMOUSE = tagRAWMOUSE;
  TRawMouse = tagRAWMOUSE;

  {$EXTERNALSYM PRAWKEYBOARD}
  PRawKeyboard = ^TRawKeyboard;
  {$EXTERNALSYM tagRAWKEYBOARD}
  tagRAWKEYBOARD = record
    MakeCode: Word;
    Flags: Word;                           // RI_KEY_*
    Reserved: Word;
    VKey: Word;
    Message: UINT;
    ExtraInformation: ULONG;
  end;
  {$EXTERNALSYM RAWKEYBOARD}
  RAWKEYBOARD = tagRAWKEYBOARD;
  TRawKeyboard = tagRAWKEYBOARD;

  { Variable size: dwCount reports of dwSizeHid bytes in bRawData. }
  {$EXTERNALSYM PRAWHID}
  PRawHid = ^TRawHid;
  {$EXTERNALSYM tagRAWHID}
  tagRAWHID = record
    dwSizeHid: DWORD;
    dwCount: DWORD;
    bRawData: array[0..0] of Byte;
  end;
  {$EXTERNALSYM RAWHID}
  RAWHID = tagRAWHID;
  TRawHid = tagRAWHID;

  {$EXTERNALSYM PRAWINPUT}
  PRawInput = ^TRawInput;
  {$EXTERNALSYM tagRAWINPUT}
  tagRAWINPUT = record
    header: TRawInputHeader;
    data: record
      case Integer of
        0: (mouse: TRawMouse);
        1: (keyboard: TRawKeyboard);
        2: (hid: TRawHid);
    end;
  end;
  {$EXTERNALSYM RAWINPUT}
  RAWINPUT = tagRAWINPUT;
  {$EXTERNALSYM LPRAWINPUT}
  LPRAWINPUT = PRawInput;
  TRawInput = tagRAWINPUT;
  PPRawInput = ^PRawInput;

  {$EXTERNALSYM PRAWINPUTDEVICE}
  PRawInputDevice = ^TRawInputDevice;
  {$EXTERNALSYM tagRAWINPUTDEVICE}
  tagRAWINPUTDEVICE = record
    usUsagePage: Word;
    usUsage: Word;
    dwFlags: DWORD;                        // RIDEV_*
    hwndTarget: HWND;
  end;
  {$EXTERNALSYM RAWINPUTDEVICE}
  RAWINPUTDEVICE = tagRAWINPUTDEVICE;
  {$EXTERNALSYM LPRAWINPUTDEVICE}
  LPRAWINPUTDEVICE = PRawInputDevice;
  TRawInputDevice = tagRAWINPUTDEVICE;

  {$EXTERNALSYM PRAWINPUTDEVICELIST}
  PRawInputDeviceList = ^TRawInputDeviceList;
  {$EXTERNALSYM tagRAWINPUTDEVICELIST}
  tagRAWINPUTDEVICELIST = record
    hDevice: THandle;
    dwType: DWORD;                         // RIM_TYPE*
  end;
  {$EXTERNALSYM RAWINPUTDEVICELIST}
  RAWINPUTDEVICELIST = tagRAWINPUTDEVICELIST;
  TRawInputDeviceList = tagRAWINPUTDEVICELIST;

  PRidDeviceInfoMouse = ^TRidDeviceInfoMouse;
  {$EXTERNALSYM tagRID_DEVICE_INFO_MOUSE}
  tagRID_DEVICE_INFO_MOUSE = record
    dwId: DWORD;
    dwNumberOfButtons: DWORD;
    dwSampleRate: DWORD;
    fHasHorizontalWheel: BOOL;
  end;
  {$EXTERNALSYM RID_DEVICE_INFO_MOUSE}
  RID_DEVICE_INFO_MOUSE = tagRID_DEVICE_INFO_MOUSE;
  {$EXTERNALSYM PRID_DEVICE_INFO_MOUSE}
  PRID_DEVICE_INFO_MOUSE = PRidDeviceInfoMouse;
  TRidDeviceInfoMouse = tagRID_DEVICE_INFO_MOUSE;

  PRidDeviceInfoKeyboard = ^TRidDeviceInfoKeyboard;
  {$EXTERNALSYM tagRID_DEVICE_INFO_KEYBOARD}
  tagRID_DEVICE_INFO_KEYBOARD = record
    dwType: DWORD;
    dwSubType: DWORD;
    dwKeyboardMode: DWORD;
    dwNumberOfFunctionKeys: DWORD;
    dwNumberOfIndicators: DWORD;
    dwNumberOfKeysTotal: DWORD;
  end;
  {$EXTERNALSYM RID_DEVICE_INFO_KEYBOARD}
  RID_DEVICE_INFO_KEYBOARD = tagRID_DEVICE_INFO_KEYBOARD;
  {$EXTERNALSYM PRID_DEVICE_INFO_KEYBOARD}
  PRID_DEVICE_INFO_KEYBOARD = PRidDeviceInfoKeyboard;
  TRidDeviceInfoKeyboard = tagRID_DEVICE_INFO_KEYBOARD;

  PRidDeviceInfoHid = ^TRidDeviceInfoHid;
  {$EXTERNALSYM tagRID_DEVICE_INFO_HID}
  tagRID_DEVICE_INFO_HID = record
    dwVendorId: DWORD;
    dwProductId: DWORD;
    dwVersionNumber: DWORD;
    usUsagePage: Word;
    usUsage: Word;
  end;
  {$EXTERNALSYM RID_DEVICE_INFO_HID}
  RID_DEVICE_INFO_HID = tagRID_DEVICE_INFO_HID;
  {$EXTERNALSYM PRID_DEVICE_INFO_HID}
  PRID_DEVICE_INFO_HID = PRidDeviceInfoHid;
  TRidDeviceInfoHid = tagRID_DEVICE_INFO_HID;

  PRidDeviceInfo = ^TRidDeviceInfo;
  {$EXTERNALSYM tagRID_DEVICE_INFO}
  tagRID_DEVICE_INFO = record
    cbSize: DWORD;                         // SizeOf(TRidDeviceInfo)
    dwType: DWORD;                         // RIM_TYPE*
    case Integer of
      0: (mouse: TRidDeviceInfoMouse);
      1: (keyboard: TRidDeviceInfoKeyboard);
      2: (hid: TRidDeviceInfoHid);
  end;
  {$EXTERNALSYM RID_DEVICE_INFO}
  RID_DEVICE_INFO = tagRID_DEVICE_INFO;
  {$EXTERNALSYM PRID_DEVICE_INFO}
  PRID_DEVICE_INFO = PRidDeviceInfo;
  {$EXTERNALSYM LPRID_DEVICE_INFO}
  LPRID_DEVICE_INFO = PRidDeviceInfo;
  TRidDeviceInfo = tagRID_DEVICE_INFO;

const
  { WM_INPUT wParam (GET_RAWINPUT_CODE_WPARAM) }
  {$EXTERNALSYM RIM_INPUT}
  RIM_INPUT     = 0;
  {$EXTERNALSYM RIM_INPUTSINK}
  RIM_INPUTSINK = 1;

  { WM_INPUT_DEVICE_CHANGE wParam }
  {$EXTERNALSYM GIDC_ARRIVAL}
  GIDC_ARRIVAL = 1;
  {$EXTERNALSYM GIDC_REMOVAL}
  GIDC_REMOVAL = 2;

  { RAWINPUTHEADER.dwType }
  {$EXTERNALSYM RIM_TYPEMOUSE}
  RIM_TYPEMOUSE    = 0;
  {$EXTERNALSYM RIM_TYPEKEYBOARD}
  RIM_TYPEKEYBOARD = 1;
  {$EXTERNALSYM RIM_TYPEHID}
  RIM_TYPEHID      = 2;
  {$EXTERNALSYM RIM_TYPEMAX}
  RIM_TYPEMAX      = 2;

  { RAWMOUSE.usButtonFlags }
  {$EXTERNALSYM RI_MOUSE_LEFT_BUTTON_DOWN}
  RI_MOUSE_LEFT_BUTTON_DOWN   = $0001;
  {$EXTERNALSYM RI_MOUSE_LEFT_BUTTON_UP}
  RI_MOUSE_LEFT_BUTTON_UP     = $0002;
  {$EXTERNALSYM RI_MOUSE_RIGHT_BUTTON_DOWN}
  RI_MOUSE_RIGHT_BUTTON_DOWN  = $0004;
  {$EXTERNALSYM RI_MOUSE_RIGHT_BUTTON_UP}
  RI_MOUSE_RIGHT_BUTTON_UP    = $0008;
  {$EXTERNALSYM RI_MOUSE_MIDDLE_BUTTON_DOWN}
  RI_MOUSE_MIDDLE_BUTTON_DOWN = $0010;
  {$EXTERNALSYM RI_MOUSE_MIDDLE_BUTTON_UP}
  RI_MOUSE_MIDDLE_BUTTON_UP   = $0020;
  {$EXTERNALSYM RI_MOUSE_BUTTON_1_DOWN}
  RI_MOUSE_BUTTON_1_DOWN      = RI_MOUSE_LEFT_BUTTON_DOWN;
  {$EXTERNALSYM RI_MOUSE_BUTTON_1_UP}
  RI_MOUSE_BUTTON_1_UP        = RI_MOUSE_LEFT_BUTTON_UP;
  {$EXTERNALSYM RI_MOUSE_BUTTON_2_DOWN}
  RI_MOUSE_BUTTON_2_DOWN      = RI_MOUSE_RIGHT_BUTTON_DOWN;
  {$EXTERNALSYM RI_MOUSE_BUTTON_2_UP}
  RI_MOUSE_BUTTON_2_UP        = RI_MOUSE_RIGHT_BUTTON_UP;
  {$EXTERNALSYM RI_MOUSE_BUTTON_3_DOWN}
  RI_MOUSE_BUTTON_3_DOWN      = RI_MOUSE_MIDDLE_BUTTON_DOWN;
  {$EXTERNALSYM RI_MOUSE_BUTTON_3_UP}
  RI_MOUSE_BUTTON_3_UP        = RI_MOUSE_MIDDLE_BUTTON_UP;
  {$EXTERNALSYM RI_MOUSE_BUTTON_4_DOWN}
  RI_MOUSE_BUTTON_4_DOWN      = $0040;
  {$EXTERNALSYM RI_MOUSE_BUTTON_4_UP}
  RI_MOUSE_BUTTON_4_UP        = $0080;
  {$EXTERNALSYM RI_MOUSE_BUTTON_5_DOWN}
  RI_MOUSE_BUTTON_5_DOWN      = $0100;
  {$EXTERNALSYM RI_MOUSE_BUTTON_5_UP}
  RI_MOUSE_BUTTON_5_UP        = $0200;
  {$EXTERNALSYM RI_MOUSE_WHEEL}
  RI_MOUSE_WHEEL              = $0400;
  {$EXTERNALSYM RI_MOUSE_HWHEEL}
  RI_MOUSE_HWHEEL             = $0800;  // Windows Vista

  { RAWMOUSE.usFlags }
  {$EXTERNALSYM MOUSE_MOVE_RELATIVE}
  MOUSE_MOVE_RELATIVE      = 0;
  {$EXTERNALSYM MOUSE_MOVE_ABSOLUTE}
  MOUSE_MOVE_ABSOLUTE      = 1;
  {$EXTERNALSYM MOUSE_VIRTUAL_DESKTOP}
  MOUSE_VIRTUAL_DESKTOP    = $02;
  {$EXTERNALSYM MOUSE_ATTRIBUTES_CHANGED}
  MOUSE_ATTRIBUTES_CHANGED = $04;
  {$EXTERNALSYM MOUSE_MOVE_NOCOALESCE}
  MOUSE_MOVE_NOCOALESCE    = $08;  // Windows Vista

  { RAWKEYBOARD }
  {$EXTERNALSYM KEYBOARD_OVERRUN_MAKE_CODE}
  KEYBOARD_OVERRUN_MAKE_CODE = $FF;
  {$EXTERNALSYM RI_KEY_MAKE}
  RI_KEY_MAKE              = 0;
  {$EXTERNALSYM RI_KEY_BREAK}
  RI_KEY_BREAK             = 1;
  {$EXTERNALSYM RI_KEY_E0}
  RI_KEY_E0                = 2;
  {$EXTERNALSYM RI_KEY_E1}
  RI_KEY_E1                = 4;
  {$EXTERNALSYM RI_KEY_TERMSRV_SET_LED}
  RI_KEY_TERMSRV_SET_LED   = 8;
  {$EXTERNALSYM RI_KEY_TERMSRV_SHADOW}
  RI_KEY_TERMSRV_SHADOW    = $10;

  { GetRawInputData uiCommand }
  {$EXTERNALSYM RID_INPUT}
  RID_INPUT  = $10000003;
  {$EXTERNALSYM RID_HEADER}
  RID_HEADER = $10000005;

  { GetRawInputDeviceInfo uiCommand }
  {$EXTERNALSYM RIDI_PREPARSEDDATA}
  RIDI_PREPARSEDDATA = $20000005;
  {$EXTERNALSYM RIDI_DEVICENAME}
  RIDI_DEVICENAME    = $20000007;  // pcbSize in characters
  {$EXTERNALSYM RIDI_DEVICEINFO}
  RIDI_DEVICEINFO    = $2000000B;

  { RAWINPUTDEVICE.dwFlags }
  {$EXTERNALSYM RIDEV_REMOVE}
  RIDEV_REMOVE       = $00000001;
  {$EXTERNALSYM RIDEV_EXCLUDE}
  RIDEV_EXCLUDE      = $00000010;
  {$EXTERNALSYM RIDEV_PAGEONLY}
  RIDEV_PAGEONLY     = $00000020;
  {$EXTERNALSYM RIDEV_NOLEGACY}
  RIDEV_NOLEGACY     = $00000030;
  {$EXTERNALSYM RIDEV_INPUTSINK}
  RIDEV_INPUTSINK    = $00000100;
  {$EXTERNALSYM RIDEV_CAPTUREMOUSE}
  RIDEV_CAPTUREMOUSE = $00000200;
  {$EXTERNALSYM RIDEV_NOHOTKEYS}
  RIDEV_NOHOTKEYS    = $00000200;
  {$EXTERNALSYM RIDEV_APPKEYS}
  RIDEV_APPKEYS      = $00000400;
  {$EXTERNALSYM RIDEV_EXINPUTSINK}
  RIDEV_EXINPUTSINK  = $00001000;  // Windows Vista
  {$EXTERNALSYM RIDEV_DEVNOTIFY}
  RIDEV_DEVNOTIFY    = $00002000;  // Windows Vista
  {$EXTERNALSYM RIDEV_EXMODEMASK}
  RIDEV_EXMODEMASK   = $000000F0;

{ Windows XP. Fallback: False / UINT(-1) (ERROR_CALL_NOT_IMPLEMENTED);
  DefRawInputProc returns 0. cbSize / cbSizeHeader: SizeOf of the record. }
{$EXTERNALSYM RegisterRawInputDevices}
function RegisterRawInputDevices(pRawInputDevices: PRawInputDevice; uiNumDevices: UINT;
  cbSize: UINT): BOOL; stdcall;
{ pData = nil asks for the size in pcbSize. }
{$EXTERNALSYM GetRawInputData}
function GetRawInputData(hRawInput: HRAWINPUT; uiCommand: UINT; pData: Pointer;
  var pcbSize: UINT; cbSizeHeader: UINT): UINT; stdcall;
{$EXTERNALSYM GetRawInputDeviceList}
function GetRawInputDeviceList(pRawInputDeviceList: PRawInputDeviceList;
  var puiNumDevices: UINT; cbSize: UINT): UINT; stdcall;
{$EXTERNALSYM GetRawInputDeviceInfo}
function GetRawInputDeviceInfo(hDevice: THandle; uiCommand: UINT; pData: Pointer;
  var pcbSize: UINT): UINT; stdcall;
{$EXTERNALSYM GetRawInputDeviceInfoA}
function GetRawInputDeviceInfoA(hDevice: THandle; uiCommand: UINT; pData: Pointer;
  var pcbSize: UINT): UINT; stdcall;
{$EXTERNALSYM GetRawInputDeviceInfoW}
function GetRawInputDeviceInfoW(hDevice: THandle; uiCommand: UINT; pData: Pointer;
  var pcbSize: UINT): UINT; stdcall;
{$EXTERNALSYM GetRegisteredRawInputDevices}
function GetRegisteredRawInputDevices(pRawInputDevices: PRawInputDevice;
  var puiNumDevices: UINT; cbSize: UINT): UINT; stdcall;
{$EXTERNALSYM GetRawInputBuffer}
function GetRawInputBuffer(pData: PRawInput; var pcbSize: UINT; cbSizeHeader: UINT): UINT; stdcall;
{$EXTERNALSYM DefRawInputProc}
function DefRawInputProc(paRawInput: PPRawInput; nInput: Integer;
  cbSizeHeader: UINT): LRESULT; stdcall;
{ Macros of the SDK: the wParam code of WM_INPUT, and the next RAWINPUT of
  a GetRawInputBuffer block (DWORD aligned in 32-bit code). }
{$EXTERNALSYM GET_RAWINPUT_CODE_WPARAM}
function GET_RAWINPUT_CODE_WPARAM(wParam: WPARAM): DWORD;
{$EXTERNALSYM NEXTRAWINPUTBLOCK}
function NEXTRAWINPUTBLOCK(ptr: PRawInput): PRawInput;

{ ====== Windows, layered windows, printing (winuser.h) ==================== }

const
  { PrintWindow }
  {$EXTERNALSYM PW_CLIENTONLY}
  PW_CLIENTONLY        = $00000001;
  {$EXTERNALSYM PW_RENDERFULLCONTENT}
  PW_RENDERFULLCONTENT = $00000002;  // Windows 8.1

  {$EXTERNALSYM ULW_EX_NORESIZE}
  ULW_EX_NORESIZE = $00000008;

  {$EXTERNALSYM ASFW_ANY}
  ASFW_ANY    = DWORD(-1);
  {$EXTERNALSYM LSFW_LOCK}
  LSFW_LOCK   = 1;
  {$EXTERNALSYM LSFW_UNLOCK}
  LSFW_UNLOCK = 2;

  { GetLayout / SetLayout (wingdi.h), SetProcessDefaultLayout }
  {$EXTERNALSYM LAYOUT_RTL}
  LAYOUT_RTL                        = $00000001;
  {$EXTERNALSYM LAYOUT_BTT}
  LAYOUT_BTT                        = $00000002;
  {$EXTERNALSYM LAYOUT_VBH}
  LAYOUT_VBH                        = $00000004;
  {$EXTERNALSYM LAYOUT_ORIENTATIONMASK}
  LAYOUT_ORIENTATIONMASK            = LAYOUT_RTL or LAYOUT_BTT or LAYOUT_VBH;
  {$EXTERNALSYM LAYOUT_BITMAPORIENTATIONPRESERVED}
  LAYOUT_BITMAPORIENTATIONPRESERVED = $00000008;
  {$EXTERNALSYM NOMIRRORBITMAP}
  NOMIRRORBITMAP                    = DWORD($80000000);

  { GetRandomRgn }
  {$EXTERNALSYM SYSRGN}
  SYSRGN = 4;

type
  {$EXTERNALSYM PUPDATELAYEREDWINDOWINFO}
  PUpdateLayeredWindowInfo = ^TUpdateLayeredWindowInfo;
  {$EXTERNALSYM tagUPDATELAYEREDWINDOWINFO}
  tagUPDATELAYEREDWINDOWINFO = record
    cbSize: DWORD;                         // SizeOf(TUpdateLayeredWindowInfo)
    hdcDst: HDC;
    pptDst: PPoint;
    psize: PSize;
    hdcSrc: HDC;
    pptSrc: PPoint;
    crKey: COLORREF;
    pblend: PBlendFunction;
    dwFlags: DWORD;                        // ULW_*
    prcDirty: PRect;
  end;
  {$EXTERNALSYM UPDATELAYEREDWINDOWINFO}
  UPDATELAYEREDWINDOWINFO = tagUPDATELAYEREDWINDOWINFO;
  TUpdateLayeredWindowInfo = tagUPDATELAYEREDWINDOWINFO;

  {$EXTERNALSYM PICONINFOEXA}
  PIconInfoExA = ^TIconInfoExA;
  {$EXTERNALSYM PICONINFOEXW}
  PIconInfoExW = ^TIconInfoExW;
  PIconInfoEx = PIconInfoExA;
  {$EXTERNALSYM _ICONINFOEXA}
  _ICONINFOEXA = record
    cbSize: DWORD;                         // SizeOf(TIconInfoEx*)
    fIcon: BOOL;
    xHotspot: DWORD;
    yHotspot: DWORD;
    hbmMask: HBITMAP;
    hbmColor: HBITMAP;
    wResID: Word;
    szModName: array[0..MAX_PATH - 1] of AnsiChar;
    szResName: array[0..MAX_PATH - 1] of AnsiChar;
  end;
  {$EXTERNALSYM _ICONINFOEXW}
  _ICONINFOEXW = record
    cbSize: DWORD;
    fIcon: BOOL;
    xHotspot: DWORD;
    yHotspot: DWORD;
    hbmMask: HBITMAP;
    hbmColor: HBITMAP;
    wResID: Word;
    szModName: array[0..MAX_PATH - 1] of WideChar;
    szResName: array[0..MAX_PATH - 1] of WideChar;
  end;
  {$EXTERNALSYM ICONINFOEXA}
  ICONINFOEXA = _ICONINFOEXA;
  {$EXTERNALSYM ICONINFOEXW}
  ICONINFOEXW = _ICONINFOEXW;
  {$EXTERNALSYM ICONINFOEX}
  ICONINFOEX = ICONINFOEXA;
  TIconInfoExA = _ICONINFOEXA;
  TIconInfoExW = _ICONINFOEXW;
  TIconInfoEx = TIconInfoExA;

{ Windows XP (PW_RENDERFULLCONTENT: Windows 8.1). Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM PrintWindow}
function PrintWindow(hwnd: HWND; hdcBlt: HDC; nFlags: UINT): BOOL; stdcall;
{ Windows Vista. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM UpdateLayeredWindowIndirect}
function UpdateLayeredWindowIndirect(hWnd: HWND;
  const pULWInfo: TUpdateLayeredWindowInfo): BOOL; stdcall;
{ Windows XP. Pointers may be nil. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetLayeredWindowAttributes}
function GetLayeredWindowAttributes(hwnd: HWND; pcrKey: PDWORD; pbAlpha: PByte;
  pdwFlags: PDWORD): BOOL; stdcall;
{ Windows 2000. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM AllowSetForegroundWindow}
function AllowSetForegroundWindow(dwProcessId: DWORD): BOOL; stdcall;
{$EXTERNALSYM LockSetForegroundWindow}
function LockSetForegroundWindow(uLockCode: UINT): BOOL; stdcall;
{ Needs a process with administrator rights (UIPI). }
{$EXTERNALSYM BlockInput}
function BlockInput(fBlockIt: BOOL): BOOL; stdcall;
{ Windows 2000. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM IsHungAppWindow}
function IsHungAppWindow(hwnd: HWND): BOOL; stdcall;
{ Windows NT 4. Fallback: 0. }
{$EXTERNALSYM GetShellWindow}
function GetShellWindow: HWND; stdcall;
{ Windows 2000. The window gets the registered message
  RegisterWindowMessage('SHELLHOOK') with HSHELL_* codes. Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM RegisterShellHookWindow}
function RegisterShellHookWindow(hwnd: HWND): BOOL; stdcall;
{$EXTERNALSYM DeregisterShellHookWindow}
function DeregisterShellHookWindow(hwnd: HWND): BOOL; stdcall;
{ Windows XP. Fallback: does nothing. }
{$EXTERNALSYM DisableProcessWindowsGhosting}
procedure DisableProcessWindowsGhosting; stdcall;
{ Windows XP. bConvert: make the thread a GUI thread. Fallback: False. }
{$EXTERNALSYM IsGUIThread}
function IsGUIThread(bConvert: BOOL): BOOL; stdcall;
{ Windows Vista. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED),
  pcFormatsOut = 0. }
{$EXTERNALSYM GetUpdatedClipboardFormats}
function GetUpdatedClipboardFormats(lpuiFormats: PUINT; cFormats: UINT;
  out pcFormatsOut: UINT): BOOL; stdcall;
{ Windows 2000. Returns the region type (NULLREGION, SIMPLEREGION,
  COMPLEXREGION) or ERROR. Fallback: ERROR. }
{$EXTERNALSYM GetWindowRgnBox}
function GetWindowRgnBox(hWnd: HWND; out lprc: TRect): Integer; stdcall;
{ Windows Vista. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetIconInfoEx}
function GetIconInfoEx(hicon: HICON; var piconinfo: TIconInfoEx): BOOL; stdcall;
{$EXTERNALSYM GetIconInfoExA}
function GetIconInfoExA(hicon: HICON; var piconinfo: TIconInfoExA): BOOL; stdcall;
{$EXTERNALSYM GetIconInfoExW}
function GetIconInfoExW(hicon: HICON; var piconinfo: TIconInfoExW): BOOL; stdcall;
{ Windows 2000: default layout (LAYOUT_RTL) of the process's new windows.
  Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM GetProcessDefaultLayout}
function GetProcessDefaultLayout(out pdwDefaultLayout: DWORD): BOOL; stdcall;
{$EXTERNALSYM SetProcessDefaultLayout}
function SetProcessDefaultLayout(dwDefaultLayout: DWORD): BOOL; stdcall;

{ gdi32, Windows 2000. Return the previous layout (SetLayout) or GDI_ERROR.
  Fallback: GDI_ERROR. }
{$EXTERNALSYM GetLayout}
function GetLayout(hdc: HDC): DWORD; stdcall;
{$EXTERNALSYM SetLayout}
function SetLayout(hdc: HDC; l: DWORD): DWORD; stdcall;
{ gdi32: i = SYSRGN copies the visible region of the DC (screen
  coordinates) into hrgn. Returns 1 / 0 / -1. Fallback: -1. }
{$EXTERNALSYM GetRandomRgn}
function GetRandomRgn(hdc: HDC; hrgn: HRGN; i: Integer): Integer; stdcall;

const
  { EnumDisplaySettings(Ex) iModeNum }
  {$EXTERNALSYM ENUM_CURRENT_SETTINGS}
  ENUM_CURRENT_SETTINGS  = DWORD(-1);
  {$EXTERNALSYM ENUM_REGISTRY_SETTINGS}
  ENUM_REGISTRY_SETTINGS = DWORD(-2);
  { EnumDisplaySettingsEx dwFlags }
  {$EXTERNALSYM EDS_RAWMODE}
  EDS_RAWMODE     = $00000002;
  {$EXTERNALSYM EDS_ROTATEDMODE}
  EDS_ROTATEDMODE = $00000004;

{ Windows 2000. Set lpDevMode.dmSize first. Fallback: EnumDisplaySettings
  (dwFlags is ignored). }
{$EXTERNALSYM EnumDisplaySettingsEx}
function EnumDisplaySettingsEx(lpszDeviceName: PChar; iModeNum: DWORD;
  var lpDevMode: TDeviceMode; dwFlags: DWORD): BOOL; stdcall;
{$EXTERNALSYM EnumDisplaySettingsExA}
function EnumDisplaySettingsExA(lpszDeviceName: PAnsiChar; iModeNum: DWORD;
  var lpDevMode: TDeviceModeA; dwFlags: DWORD): BOOL; stdcall;
{$EXTERNALSYM EnumDisplaySettingsExW}
function EnumDisplaySettingsExW(lpszDeviceName: PWideChar; iModeNum: DWORD;
  var lpDevMode: TDeviceModeW; dwFlags: DWORD): BOOL; stdcall;

{ ====== Display configuration (wingdi.h, winuser.h, Windows 7) ============ }

type
  {$EXTERNALSYM DISPLAYCONFIG_TOPOLOGY_ID}
  DISPLAYCONFIG_TOPOLOGY_ID = Integer;
  {$EXTERNALSYM DISPLAYCONFIG_MODE_INFO_TYPE}
  DISPLAYCONFIG_MODE_INFO_TYPE = Integer;
  {$EXTERNALSYM DISPLAYCONFIG_PIXELFORMAT}
  DISPLAYCONFIG_PIXELFORMAT = Integer;
  {$EXTERNALSYM DISPLAYCONFIG_SCANLINE_ORDERING}
  DISPLAYCONFIG_SCANLINE_ORDERING = Integer;
  {$EXTERNALSYM DISPLAYCONFIG_VIDEO_OUTPUT_TECHNOLOGY}
  DISPLAYCONFIG_VIDEO_OUTPUT_TECHNOLOGY = Integer;
  {$EXTERNALSYM DISPLAYCONFIG_ROTATION}
  DISPLAYCONFIG_ROTATION = Integer;
  {$EXTERNALSYM DISPLAYCONFIG_SCALING}
  DISPLAYCONFIG_SCALING = Integer;
  {$EXTERNALSYM DISPLAYCONFIG_DEVICE_INFO_TYPE}
  DISPLAYCONFIG_DEVICE_INFO_TYPE = Integer;
  {$EXTERNALSYM DISPLAYCONFIG_COLOR_ENCODING}
  DISPLAYCONFIG_COLOR_ENCODING = Integer;

const
  { QueryDisplayConfig / GetDisplayConfigBufferSizes flags }
  {$EXTERNALSYM QDC_ALL_PATHS}
  QDC_ALL_PATHS                  = $00000001;
  {$EXTERNALSYM QDC_ONLY_ACTIVE_PATHS}
  QDC_ONLY_ACTIVE_PATHS          = $00000002;
  {$EXTERNALSYM QDC_DATABASE_CURRENT}
  QDC_DATABASE_CURRENT           = $00000004;
  {$EXTERNALSYM QDC_VIRTUAL_MODE_AWARE}
  QDC_VIRTUAL_MODE_AWARE         = $00000010;  // Windows 10
  {$EXTERNALSYM QDC_INCLUDE_HMD}
  QDC_INCLUDE_HMD                = $00000020;
  {$EXTERNALSYM QDC_VIRTUAL_REFRESH_RATE_AWARE}
  QDC_VIRTUAL_REFRESH_RATE_AWARE = $00000040;  // Windows 11

  { SetDisplayConfig flags }
  {$EXTERNALSYM SDC_TOPOLOGY_INTERNAL}
  SDC_TOPOLOGY_INTERNAL            = $00000001;
  {$EXTERNALSYM SDC_TOPOLOGY_CLONE}
  SDC_TOPOLOGY_CLONE               = $00000002;
  {$EXTERNALSYM SDC_TOPOLOGY_EXTEND}
  SDC_TOPOLOGY_EXTEND              = $00000004;
  {$EXTERNALSYM SDC_TOPOLOGY_EXTERNAL}
  SDC_TOPOLOGY_EXTERNAL            = $00000008;
  {$EXTERNALSYM SDC_TOPOLOGY_SUPPLIED}
  SDC_TOPOLOGY_SUPPLIED            = $00000010;
  {$EXTERNALSYM SDC_USE_DATABASE_CURRENT}
  SDC_USE_DATABASE_CURRENT         = SDC_TOPOLOGY_INTERNAL or SDC_TOPOLOGY_CLONE or
    SDC_TOPOLOGY_EXTEND or SDC_TOPOLOGY_EXTERNAL;
  {$EXTERNALSYM SDC_USE_SUPPLIED_DISPLAY_CONFIG}
  SDC_USE_SUPPLIED_DISPLAY_CONFIG  = $00000020;
  {$EXTERNALSYM SDC_VALIDATE}
  SDC_VALIDATE                     = $00000040;
  {$EXTERNALSYM SDC_APPLY}
  SDC_APPLY                        = $00000080;
  {$EXTERNALSYM SDC_NO_OPTIMIZATION}
  SDC_NO_OPTIMIZATION              = $00000100;
  {$EXTERNALSYM SDC_SAVE_TO_DATABASE}
  SDC_SAVE_TO_DATABASE             = $00000200;
  {$EXTERNALSYM SDC_ALLOW_CHANGES}
  SDC_ALLOW_CHANGES                = $00000400;
  {$EXTERNALSYM SDC_PATH_PERSIST_IF_REQUIRED}
  SDC_PATH_PERSIST_IF_REQUIRED     = $00000800;
  {$EXTERNALSYM SDC_FORCE_MODE_ENUMERATION}
  SDC_FORCE_MODE_ENUMERATION       = $00001000;
  {$EXTERNALSYM SDC_ALLOW_PATH_ORDER_CHANGES}
  SDC_ALLOW_PATH_ORDER_CHANGES     = $00002000;
  {$EXTERNALSYM SDC_VIRTUAL_MODE_AWARE}
  SDC_VIRTUAL_MODE_AWARE           = $00008000;

  { DISPLAYCONFIG_TOPOLOGY_ID }
  {$EXTERNALSYM DISPLAYCONFIG_TOPOLOGY_INTERNAL}
  DISPLAYCONFIG_TOPOLOGY_INTERNAL = $00000001;
  {$EXTERNALSYM DISPLAYCONFIG_TOPOLOGY_CLONE}
  DISPLAYCONFIG_TOPOLOGY_CLONE    = $00000002;
  {$EXTERNALSYM DISPLAYCONFIG_TOPOLOGY_EXTEND}
  DISPLAYCONFIG_TOPOLOGY_EXTEND   = $00000004;
  {$EXTERNALSYM DISPLAYCONFIG_TOPOLOGY_EXTERNAL}
  DISPLAYCONFIG_TOPOLOGY_EXTERNAL = $00000008;

  { DISPLAYCONFIG_MODE_INFO_TYPE }
  {$EXTERNALSYM DISPLAYCONFIG_MODE_INFO_TYPE_SOURCE}
  DISPLAYCONFIG_MODE_INFO_TYPE_SOURCE        = 1;
  {$EXTERNALSYM DISPLAYCONFIG_MODE_INFO_TYPE_TARGET}
  DISPLAYCONFIG_MODE_INFO_TYPE_TARGET        = 2;
  {$EXTERNALSYM DISPLAYCONFIG_MODE_INFO_TYPE_DESKTOP_IMAGE}
  DISPLAYCONFIG_MODE_INFO_TYPE_DESKTOP_IMAGE = 3;

  { DISPLAYCONFIG_PIXELFORMAT }
  {$EXTERNALSYM DISPLAYCONFIG_PIXELFORMAT_8BPP}
  DISPLAYCONFIG_PIXELFORMAT_8BPP   = 1;
  {$EXTERNALSYM DISPLAYCONFIG_PIXELFORMAT_16BPP}
  DISPLAYCONFIG_PIXELFORMAT_16BPP  = 2;
  {$EXTERNALSYM DISPLAYCONFIG_PIXELFORMAT_24BPP}
  DISPLAYCONFIG_PIXELFORMAT_24BPP  = 3;
  {$EXTERNALSYM DISPLAYCONFIG_PIXELFORMAT_32BPP}
  DISPLAYCONFIG_PIXELFORMAT_32BPP  = 4;
  {$EXTERNALSYM DISPLAYCONFIG_PIXELFORMAT_NONGDI}
  DISPLAYCONFIG_PIXELFORMAT_NONGDI = 5;

  { DISPLAYCONFIG_SCANLINE_ORDERING }
  {$EXTERNALSYM DISPLAYCONFIG_SCANLINE_ORDERING_UNSPECIFIED}
  DISPLAYCONFIG_SCANLINE_ORDERING_UNSPECIFIED                = 0;
  {$EXTERNALSYM DISPLAYCONFIG_SCANLINE_ORDERING_PROGRESSIVE}
  DISPLAYCONFIG_SCANLINE_ORDERING_PROGRESSIVE                = 1;
  {$EXTERNALSYM DISPLAYCONFIG_SCANLINE_ORDERING_INTERLACED}
  DISPLAYCONFIG_SCANLINE_ORDERING_INTERLACED                 = 2;
  {$EXTERNALSYM DISPLAYCONFIG_SCANLINE_ORDERING_INTERLACED_UPPERFIELDFIRST}
  DISPLAYCONFIG_SCANLINE_ORDERING_INTERLACED_UPPERFIELDFIRST = 2;
  {$EXTERNALSYM DISPLAYCONFIG_SCANLINE_ORDERING_INTERLACED_LOWERFIELDFIRST}
  DISPLAYCONFIG_SCANLINE_ORDERING_INTERLACED_LOWERFIELDFIRST = 3;

  { DISPLAYCONFIG_VIDEO_OUTPUT_TECHNOLOGY }
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_OTHER}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_OTHER                = -1;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_HD15}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_HD15                 = 0;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_SVIDEO}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_SVIDEO               = 1;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_COMPOSITE_VIDEO}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_COMPOSITE_VIDEO      = 2;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_COMPONENT_VIDEO}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_COMPONENT_VIDEO      = 3;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_DVI}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_DVI                  = 4;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_HDMI}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_HDMI                 = 5;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_LVDS}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_LVDS                 = 6;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_D_JPN}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_D_JPN                = 8;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_SDI}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_SDI                  = 9;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_DISPLAYPORT_EXTERNAL}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_DISPLAYPORT_EXTERNAL = 10;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_DISPLAYPORT_EMBEDDED}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_DISPLAYPORT_EMBEDDED = 11;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_UDI_EXTERNAL}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_UDI_EXTERNAL         = 12;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_UDI_EMBEDDED}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_UDI_EMBEDDED         = 13;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_SDTVDONGLE}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_SDTVDONGLE           = 14;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_MIRACAST}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_MIRACAST             = 15;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_INDIRECT_WIRED}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_INDIRECT_WIRED       = 16;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_INDIRECT_VIRTUAL}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_INDIRECT_VIRTUAL     = 17;
  {$EXTERNALSYM DISPLAYCONFIG_OUTPUT_TECHNOLOGY_INTERNAL}
  DISPLAYCONFIG_OUTPUT_TECHNOLOGY_INTERNAL             = Integer($80000000);

  { DISPLAYCONFIG_ROTATION }
  {$EXTERNALSYM DISPLAYCONFIG_ROTATION_IDENTITY}
  DISPLAYCONFIG_ROTATION_IDENTITY  = 1;
  {$EXTERNALSYM DISPLAYCONFIG_ROTATION_ROTATE90}
  DISPLAYCONFIG_ROTATION_ROTATE90  = 2;
  {$EXTERNALSYM DISPLAYCONFIG_ROTATION_ROTATE180}
  DISPLAYCONFIG_ROTATION_ROTATE180 = 3;
  {$EXTERNALSYM DISPLAYCONFIG_ROTATION_ROTATE270}
  DISPLAYCONFIG_ROTATION_ROTATE270 = 4;

  { DISPLAYCONFIG_SCALING }
  {$EXTERNALSYM DISPLAYCONFIG_SCALING_IDENTITY}
  DISPLAYCONFIG_SCALING_IDENTITY               = 1;
  {$EXTERNALSYM DISPLAYCONFIG_SCALING_CENTERED}
  DISPLAYCONFIG_SCALING_CENTERED               = 2;
  {$EXTERNALSYM DISPLAYCONFIG_SCALING_STRETCHED}
  DISPLAYCONFIG_SCALING_STRETCHED              = 3;
  {$EXTERNALSYM DISPLAYCONFIG_SCALING_ASPECTRATIOCENTEREDMAX}
  DISPLAYCONFIG_SCALING_ASPECTRATIOCENTEREDMAX = 4;
  {$EXTERNALSYM DISPLAYCONFIG_SCALING_CUSTOM}
  DISPLAYCONFIG_SCALING_CUSTOM                 = 5;
  {$EXTERNALSYM DISPLAYCONFIG_SCALING_PREFERRED}
  DISPLAYCONFIG_SCALING_PREFERRED              = 128;

  { DISPLAYCONFIG_DEVICE_INFO_TYPE }
  {$EXTERNALSYM DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME}
  DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME           = 1;
  {$EXTERNALSYM DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME}
  DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME           = 2;
  {$EXTERNALSYM DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_PREFERRED_MODE}
  DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_PREFERRED_MODE = 3;
  {$EXTERNALSYM DISPLAYCONFIG_DEVICE_INFO_GET_ADAPTER_NAME}
  DISPLAYCONFIG_DEVICE_INFO_GET_ADAPTER_NAME          = 4;
  {$EXTERNALSYM DISPLAYCONFIG_DEVICE_INFO_SET_TARGET_PERSISTENCE}
  DISPLAYCONFIG_DEVICE_INFO_SET_TARGET_PERSISTENCE    = 5;
  {$EXTERNALSYM DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_BASE_TYPE}
  DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_BASE_TYPE      = 6;
  {$EXTERNALSYM DISPLAYCONFIG_DEVICE_INFO_GET_ADVANCED_COLOR_INFO}
  DISPLAYCONFIG_DEVICE_INFO_GET_ADVANCED_COLOR_INFO   = 9;   // Windows 10 1709
  {$EXTERNALSYM DISPLAYCONFIG_DEVICE_INFO_SET_ADVANCED_COLOR_STATE}
  DISPLAYCONFIG_DEVICE_INFO_SET_ADVANCED_COLOR_STATE  = 10;
  {$EXTERNALSYM DISPLAYCONFIG_DEVICE_INFO_GET_SDR_WHITE_LEVEL}
  DISPLAYCONFIG_DEVICE_INFO_GET_SDR_WHITE_LEVEL       = 11;  // Windows 10 1709

  { DISPLAYCONFIG_COLOR_ENCODING }
  {$EXTERNALSYM DISPLAYCONFIG_COLOR_ENCODING_RGB}
  DISPLAYCONFIG_COLOR_ENCODING_RGB       = 0;
  {$EXTERNALSYM DISPLAYCONFIG_COLOR_ENCODING_YCBCR444}
  DISPLAYCONFIG_COLOR_ENCODING_YCBCR444  = 1;
  {$EXTERNALSYM DISPLAYCONFIG_COLOR_ENCODING_YCBCR422}
  DISPLAYCONFIG_COLOR_ENCODING_YCBCR422  = 2;
  {$EXTERNALSYM DISPLAYCONFIG_COLOR_ENCODING_YCBCR420}
  DISPLAYCONFIG_COLOR_ENCODING_YCBCR420  = 3;
  {$EXTERNALSYM DISPLAYCONFIG_COLOR_ENCODING_INTENSITY}
  DISPLAYCONFIG_COLOR_ENCODING_INTENSITY = 4;

  { Path and mode flags }
  {$EXTERNALSYM DISPLAYCONFIG_PATH_ACTIVE}
  DISPLAYCONFIG_PATH_ACTIVE              = $00000001;
  {$EXTERNALSYM DISPLAYCONFIG_PATH_MODE_IDX_INVALID}
  DISPLAYCONFIG_PATH_MODE_IDX_INVALID    = DWORD($FFFFFFFF);
  {$EXTERNALSYM DISPLAYCONFIG_SOURCE_IN_USE}
  DISPLAYCONFIG_SOURCE_IN_USE            = $00000001;
  {$EXTERNALSYM DISPLAYCONFIG_TARGET_IN_USE}
  DISPLAYCONFIG_TARGET_IN_USE            = $00000001;
  {$EXTERNALSYM DISPLAYCONFIG_TARGET_FORCIBLE}
  DISPLAYCONFIG_TARGET_FORCIBLE          = $00000002;
  {$EXTERNALSYM DISPLAYCONFIG_TARGET_FORCED_AVAILABILITY_BOOT}
  DISPLAYCONFIG_TARGET_FORCED_AVAILABILITY_BOOT   = $00000004;
  {$EXTERNALSYM DISPLAYCONFIG_TARGET_FORCED_AVAILABILITY_PATH}
  DISPLAYCONFIG_TARGET_FORCED_AVAILABILITY_PATH   = $00000008;
  {$EXTERNALSYM DISPLAYCONFIG_TARGET_FORCED_AVAILABILITY_SYSTEM}
  DISPLAYCONFIG_TARGET_FORCED_AVAILABILITY_SYSTEM = $00000010;

type
  PDisplayConfigRational = ^TDisplayConfigRational;
  {$EXTERNALSYM DISPLAYCONFIG_RATIONAL}
  DISPLAYCONFIG_RATIONAL = record
    Numerator: Cardinal;
    Denominator: Cardinal;
  end;
  TDisplayConfigRational = DISPLAYCONFIG_RATIONAL;

  PDisplayConfig2DRegion = ^TDisplayConfig2DRegion;
  {$EXTERNALSYM DISPLAYCONFIG_2DREGION}
  DISPLAYCONFIG_2DREGION = record
    cx: Cardinal;
    cy: Cardinal;
  end;
  TDisplayConfig2DRegion = DISPLAYCONFIG_2DREGION;

  PDisplayConfigVideoSignalInfo = ^TDisplayConfigVideoSignalInfo;
  {$EXTERNALSYM DISPLAYCONFIG_VIDEO_SIGNAL_INFO}
  DISPLAYCONFIG_VIDEO_SIGNAL_INFO = record
    pixelRate: UInt64;
    hSyncFreq: TDisplayConfigRational;
    vSyncFreq: TDisplayConfigRational;
    activeSize: TDisplayConfig2DRegion;
    totalSize: TDisplayConfig2DRegion;
    case Integer of
      { bits 0-15 videoStandard (D3DKMDT_VIDEO_SIGNAL_STANDARD), 16-21
        vSyncFreqDivider (Windows 8.1), 22-31 reserved }
      0: (AdditionalSignalInfo: Cardinal);
      1: (videoStandard: Cardinal;
          scanLineOrdering: DISPLAYCONFIG_SCANLINE_ORDERING);
  end;
  TDisplayConfigVideoSignalInfo = DISPLAYCONFIG_VIDEO_SIGNAL_INFO;

  PDisplayConfigSourceMode = ^TDisplayConfigSourceMode;
  {$EXTERNALSYM DISPLAYCONFIG_SOURCE_MODE}
  DISPLAYCONFIG_SOURCE_MODE = record
    width: Cardinal;
    height: Cardinal;
    pixelFormat: DISPLAYCONFIG_PIXELFORMAT;
    position: TPoint;                      // POINTL
  end;
  TDisplayConfigSourceMode = DISPLAYCONFIG_SOURCE_MODE;

  PDisplayConfigTargetMode = ^TDisplayConfigTargetMode;
  {$EXTERNALSYM DISPLAYCONFIG_TARGET_MODE}
  DISPLAYCONFIG_TARGET_MODE = record
    targetVideoSignalInfo: TDisplayConfigVideoSignalInfo;
  end;
  TDisplayConfigTargetMode = DISPLAYCONFIG_TARGET_MODE;

  PDisplayConfigDesktopImageInfo = ^TDisplayConfigDesktopImageInfo;
  {$EXTERNALSYM DISPLAYCONFIG_DESKTOP_IMAGE_INFO}
  DISPLAYCONFIG_DESKTOP_IMAGE_INFO = record
    PathSourceSize: TPoint;                // POINTL
    DesktopImageRegion: TRect;             // RECTL
    DesktopImageClip: TRect;               // RECTL
  end;
  TDisplayConfigDesktopImageInfo = DISPLAYCONFIG_DESKTOP_IMAGE_INFO;

  PDisplayConfigModeInfo = ^TDisplayConfigModeInfo;
  {$EXTERNALSYM DISPLAYCONFIG_MODE_INFO}
  DISPLAYCONFIG_MODE_INFO = record
    infoType: DISPLAYCONFIG_MODE_INFO_TYPE;
    id: Cardinal;
    adapterId: TLUID;
    case Integer of
      0: (targetMode: TDisplayConfigTargetMode);
      1: (sourceMode: TDisplayConfigSourceMode);
      2: (desktopImageInfo: TDisplayConfigDesktopImageInfo);  // Windows 10
  end;
  TDisplayConfigModeInfo = DISPLAYCONFIG_MODE_INFO;

  PDisplayConfigPathSourceInfo = ^TDisplayConfigPathSourceInfo;
  {$EXTERNALSYM DISPLAYCONFIG_PATH_SOURCE_INFO}
  DISPLAYCONFIG_PATH_SOURCE_INFO = record
    adapterId: TLUID;
    id: Cardinal;
    { or (QDC_VIRTUAL_MODE_AWARE) bits 0-15 cloneGroupId, 16-31
      sourceModeInfoIdx }
    modeInfoIdx: Cardinal;
    statusFlags: Cardinal;                 // DISPLAYCONFIG_SOURCE_*
  end;
  TDisplayConfigPathSourceInfo = DISPLAYCONFIG_PATH_SOURCE_INFO;

  PDisplayConfigPathTargetInfo = ^TDisplayConfigPathTargetInfo;
  {$EXTERNALSYM DISPLAYCONFIG_PATH_TARGET_INFO}
  DISPLAYCONFIG_PATH_TARGET_INFO = record
    adapterId: TLUID;
    id: Cardinal;
    { or (QDC_VIRTUAL_MODE_AWARE) bits 0-15 desktopModeInfoIdx, 16-31
      targetModeInfoIdx }
    modeInfoIdx: Cardinal;
    outputTechnology: DISPLAYCONFIG_VIDEO_OUTPUT_TECHNOLOGY;
    rotation: DISPLAYCONFIG_ROTATION;
    scaling: DISPLAYCONFIG_SCALING;
    refreshRate: TDisplayConfigRational;
    scanLineOrdering: DISPLAYCONFIG_SCANLINE_ORDERING;
    targetAvailable: BOOL;
    statusFlags: Cardinal;                 // DISPLAYCONFIG_TARGET_*
  end;
  TDisplayConfigPathTargetInfo = DISPLAYCONFIG_PATH_TARGET_INFO;

  PDisplayConfigPathInfo = ^TDisplayConfigPathInfo;
  {$EXTERNALSYM DISPLAYCONFIG_PATH_INFO}
  DISPLAYCONFIG_PATH_INFO = record
    sourceInfo: TDisplayConfigPathSourceInfo;
    targetInfo: TDisplayConfigPathTargetInfo;
    flags: Cardinal;                       // DISPLAYCONFIG_PATH_ACTIVE
  end;
  TDisplayConfigPathInfo = DISPLAYCONFIG_PATH_INFO;

  { The request of DisplayConfigGetDeviceInfo: type_, size = SizeOf of the
    whole request record, adapterId and id from a path. }
  PDisplayConfigDeviceInfoHeader = ^TDisplayConfigDeviceInfoHeader;
  {$EXTERNALSYM DISPLAYCONFIG_DEVICE_INFO_HEADER}
  DISPLAYCONFIG_DEVICE_INFO_HEADER = record
    type_: DISPLAYCONFIG_DEVICE_INFO_TYPE; // C name: type
    size: Cardinal;
    adapterId: TLUID;
    id: Cardinal;
  end;
  TDisplayConfigDeviceInfoHeader = DISPLAYCONFIG_DEVICE_INFO_HEADER;

  PDisplayConfigSourceDeviceName = ^TDisplayConfigSourceDeviceName;
  {$EXTERNALSYM DISPLAYCONFIG_SOURCE_DEVICE_NAME}
  DISPLAYCONFIG_SOURCE_DEVICE_NAME = record
    header: TDisplayConfigDeviceInfoHeader;
    viewGdiDeviceName: array[0..CCHDEVICENAME - 1] of WideChar;   // '\\.\DISPLAY1'
  end;
  TDisplayConfigSourceDeviceName = DISPLAYCONFIG_SOURCE_DEVICE_NAME;

  PDisplayConfigTargetDeviceName = ^TDisplayConfigTargetDeviceName;
  {$EXTERNALSYM DISPLAYCONFIG_TARGET_DEVICE_NAME}
  DISPLAYCONFIG_TARGET_DEVICE_NAME = record
    header: TDisplayConfigDeviceInfoHeader;
    { DISPLAYCONFIG_TARGET_DEVICE_NAME_FLAGS: bit 0 friendlyNameFromEdid,
      1 friendlyNameForced, 2 edidIdsValid }
    flags: Cardinal;
    outputTechnology: DISPLAYCONFIG_VIDEO_OUTPUT_TECHNOLOGY;
    edidManufactureId: Word;
    edidProductCodeId: Word;
    connectorInstance: Cardinal;
    monitorFriendlyDeviceName: array[0..63] of WideChar;
    monitorDevicePath: array[0..127] of WideChar;
  end;
  TDisplayConfigTargetDeviceName = DISPLAYCONFIG_TARGET_DEVICE_NAME;

  PDisplayConfigTargetPreferredMode = ^TDisplayConfigTargetPreferredMode;
  {$EXTERNALSYM DISPLAYCONFIG_TARGET_PREFERRED_MODE}
  DISPLAYCONFIG_TARGET_PREFERRED_MODE = record
    header: TDisplayConfigDeviceInfoHeader;
    width: Cardinal;
    height: Cardinal;
    targetMode: TDisplayConfigTargetMode;
  end;
  TDisplayConfigTargetPreferredMode = DISPLAYCONFIG_TARGET_PREFERRED_MODE;

  PDisplayConfigAdapterName = ^TDisplayConfigAdapterName;
  {$EXTERNALSYM DISPLAYCONFIG_ADAPTER_NAME}
  DISPLAYCONFIG_ADAPTER_NAME = record
    header: TDisplayConfigDeviceInfoHeader;
    adapterDevicePath: array[0..127] of WideChar;
  end;
  TDisplayConfigAdapterName = DISPLAYCONFIG_ADAPTER_NAME;

  PDisplayConfigGetAdvancedColorInfo = ^TDisplayConfigGetAdvancedColorInfo;
  {$EXTERNALSYM _DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO}
  _DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO = record
    header: TDisplayConfigDeviceInfoHeader;
    { bit 0 advancedColorSupported, 1 advancedColorEnabled, 2
      wideColorEnforced, 3 advancedColorForceDisabled }
    value: Cardinal;
    colorEncoding: DISPLAYCONFIG_COLOR_ENCODING;
    bitsPerColorChannel: Cardinal;
  end;
  {$EXTERNALSYM DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO}
  DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO = _DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO;
  TDisplayConfigGetAdvancedColorInfo = _DISPLAYCONFIG_GET_ADVANCED_COLOR_INFO;

  PDisplayConfigSdrWhiteLevel = ^TDisplayConfigSdrWhiteLevel;
  {$EXTERNALSYM _DISPLAYCONFIG_SDR_WHITE_LEVEL}
  _DISPLAYCONFIG_SDR_WHITE_LEVEL = record
    header: TDisplayConfigDeviceInfoHeader;
    SDRWhiteLevel: ULONG;                  // 1000 = 80 nits
  end;
  {$EXTERNALSYM DISPLAYCONFIG_SDR_WHITE_LEVEL}
  DISPLAYCONFIG_SDR_WHITE_LEVEL = _DISPLAYCONFIG_SDR_WHITE_LEVEL;
  TDisplayConfigSdrWhiteLevel = _DISPLAYCONFIG_SDR_WHITE_LEVEL;

{ Windows 7. Return ERROR_SUCCESS or a Win32 error code. Fallback:
  ERROR_CALL_NOT_IMPLEMENTED (as the result; the element counts are set to
  0). currentTopologyId may be nil (it must be nil except with
  QDC_DATABASE_CURRENT). }
{$EXTERNALSYM GetDisplayConfigBufferSizes}
function GetDisplayConfigBufferSizes(flags: Cardinal; out numPathArrayElements: Cardinal;
  out numModeInfoArrayElements: Cardinal): Longint; stdcall;
{$EXTERNALSYM QueryDisplayConfig}
function QueryDisplayConfig(flags: Cardinal; var numPathArrayElements: Cardinal;
  pathArray: PDisplayConfigPathInfo; var numModeInfoArrayElements: Cardinal;
  modeInfoArray: PDisplayConfigModeInfo;
  currentTopologyId: PInteger): Longint; stdcall;
{$EXTERNALSYM DisplayConfigGetDeviceInfo}
function DisplayConfigGetDeviceInfo(requestPacket: PDisplayConfigDeviceInfoHeader): Longint; stdcall;
{ Changes the display configuration (with SDC_APPLY). }
{$EXTERNALSYM SetDisplayConfig}
function SetDisplayConfig(numPathArrayElements: Cardinal; pathArray: PDisplayConfigPathInfo;
  numModeInfoArrayElements: Cardinal; modeInfoArray: PDisplayConfigModeInfo;
  flags: Cardinal): Longint; stdcall;

{ ====== Registry (winreg.h) =============================================== }

const
  {$EXTERNALSYM REG_QWORD}
  REG_QWORD               = 11;
  {$EXTERNALSYM REG_QWORD_LITTLE_ENDIAN}
  REG_QWORD_LITTLE_ENDIAN = 11;

  { Registry view (samDesired of RegOpenKeyEx, RegCreateKeyEx, RegDeleteKeyEx) }
  {$EXTERNALSYM KEY_WOW64_64KEY}
  KEY_WOW64_64KEY = $0100;
  {$EXTERNALSYM KEY_WOW64_32KEY}
  KEY_WOW64_32KEY = $0200;
  {$EXTERNALSYM KEY_WOW64_RES}
  KEY_WOW64_RES   = $0300;

  { RegGetValue dwFlags }
  {$EXTERNALSYM RRF_RT_REG_NONE}
  RRF_RT_REG_NONE        = $00000001;
  {$EXTERNALSYM RRF_RT_REG_SZ}
  RRF_RT_REG_SZ          = $00000002;
  {$EXTERNALSYM RRF_RT_REG_EXPAND_SZ}
  RRF_RT_REG_EXPAND_SZ   = $00000004;
  {$EXTERNALSYM RRF_RT_REG_BINARY}
  RRF_RT_REG_BINARY      = $00000008;
  {$EXTERNALSYM RRF_RT_REG_DWORD}
  RRF_RT_REG_DWORD       = $00000010;
  {$EXTERNALSYM RRF_RT_REG_MULTI_SZ}
  RRF_RT_REG_MULTI_SZ    = $00000020;
  {$EXTERNALSYM RRF_RT_REG_QWORD}
  RRF_RT_REG_QWORD       = $00000040;
  {$EXTERNALSYM RRF_RT_DWORD}
  RRF_RT_DWORD           = RRF_RT_REG_BINARY or RRF_RT_REG_DWORD;
  {$EXTERNALSYM RRF_RT_QWORD}
  RRF_RT_QWORD           = RRF_RT_REG_BINARY or RRF_RT_REG_QWORD;
  {$EXTERNALSYM RRF_RT_ANY}
  RRF_RT_ANY             = $0000FFFF;
  {$EXTERNALSYM RRF_SUBKEY_WOW6464KEY}
  RRF_SUBKEY_WOW6464KEY  = $00010000;
  {$EXTERNALSYM RRF_SUBKEY_WOW6432KEY}
  RRF_SUBKEY_WOW6432KEY  = $00020000;
  {$EXTERNALSYM RRF_WOW64_MASK}
  RRF_WOW64_MASK         = $00030000;
  {$EXTERNALSYM RRF_NOEXPAND}
  RRF_NOEXPAND           = $10000000;
  {$EXTERNALSYM RRF_ZEROONFAILURE}
  RRF_ZEROONFAILURE      = $20000000;

  { RegLoadMUIString Flags }
  {$EXTERNALSYM REG_MUI_STRING_TRUNCATE}
  REG_MUI_STRING_TRUNCATE = $00000001;

  { RegLoadAppKey dwOptions }
  {$EXTERNALSYM REG_PROCESS_APPKEY}
  REG_PROCESS_APPKEY = $00000001;

{ The registry functions return ERROR_SUCCESS or a Win32 error code; the
  fallback returns ERROR_CALL_NOT_IMPLEMENTED unless noted. Availability:
  RegOpenCurrentUser, RegOverridePredefKey, RegOpenUserClassesRoot: Windows
  2000; RegDeleteKeyEx: Windows XP x64 / Vista; the others Windows Vista
  (RegRenameKey: documented since Windows 10). }

{ Reads a value of hkey\lpSubKey (lpSubKey may be nil), restricted to the
  RRF_RT_* types, REG_EXPAND_SZ expanded unless RRF_NOEXPAND, strings always
  null terminated. pvData = nil asks for the size in pcbData. pdwType may be
  nil. }
{$EXTERNALSYM RegGetValue}
function RegGetValue(hkey: HKEY; lpSubKey, lpValue: PChar; dwFlags: DWORD; pdwType: PDWORD;
  pvData: Pointer; pcbData: PDWORD): Longint; stdcall;
{$EXTERNALSYM RegGetValueA}
function RegGetValueA(hkey: HKEY; lpSubKey, lpValue: PAnsiChar; dwFlags: DWORD; pdwType: PDWORD;
  pvData: Pointer; pcbData: PDWORD): Longint; stdcall;
{$EXTERNALSYM RegGetValueW}
function RegGetValueW(hkey: HKEY; lpSubKey, lpValue: PWideChar; dwFlags: DWORD; pdwType: PDWORD;
  pvData: Pointer; pcbData: PDWORD): Longint; stdcall;
{ Sets a value of hKey\lpSubKey, creating the subkey if needed. }
{$EXTERNALSYM RegSetKeyValue}
function RegSetKeyValue(hKey: HKEY; lpSubKey, lpValueName: PChar; dwType: DWORD;
  lpData: Pointer; cbData: DWORD): Longint; stdcall;
{$EXTERNALSYM RegSetKeyValueA}
function RegSetKeyValueA(hKey: HKEY; lpSubKey, lpValueName: PAnsiChar; dwType: DWORD;
  lpData: Pointer; cbData: DWORD): Longint; stdcall;
{$EXTERNALSYM RegSetKeyValueW}
function RegSetKeyValueW(hKey: HKEY; lpSubKey, lpValueName: PWideChar; dwType: DWORD;
  lpData: Pointer; cbData: DWORD): Longint; stdcall;
{$EXTERNALSYM RegDeleteKeyValue}
function RegDeleteKeyValue(hKey: HKEY; lpSubKey, lpValueName: PChar): Longint; stdcall;
{$EXTERNALSYM RegDeleteKeyValueA}
function RegDeleteKeyValueA(hKey: HKEY; lpSubKey, lpValueName: PAnsiChar): Longint; stdcall;
{$EXTERNALSYM RegDeleteKeyValueW}
function RegDeleteKeyValueW(hKey: HKEY; lpSubKey, lpValueName: PWideChar): Longint; stdcall;
{ Deletes hKey\lpSubKey with all its subkeys and values; lpSubKey = nil
  deletes the contents of hKey only. }
{$EXTERNALSYM RegDeleteTree}
function RegDeleteTree(hKey: HKEY; lpSubKey: PChar): Longint; stdcall;
{$EXTERNALSYM RegDeleteTreeA}
function RegDeleteTreeA(hKey: HKEY; lpSubKey: PAnsiChar): Longint; stdcall;
{$EXTERNALSYM RegDeleteTreeW}
function RegDeleteTreeW(hKey: HKEY; lpSubKey: PWideChar): Longint; stdcall;
{ Copies the subkeys and values of hKeySrc\lpSubKey into hKeyDest. }
{$EXTERNALSYM RegCopyTree}
function RegCopyTree(hKeySrc: HKEY; lpSubKey: PChar; hKeyDest: HKEY): Longint; stdcall;
{$EXTERNALSYM RegCopyTreeA}
function RegCopyTreeA(hKeySrc: HKEY; lpSubKey: PAnsiChar; hKeyDest: HKEY): Longint; stdcall;
{$EXTERNALSYM RegCopyTreeW}
function RegCopyTreeW(hKeySrc: HKEY; lpSubKey: PWideChar; hKeyDest: HKEY): Longint; stdcall;
{ samDesired: KEY_WOW64_32KEY or KEY_WOW64_64KEY selects the view. Fallback:
  RegDeleteKey (systems without RegDeleteKeyEx have one view). }
{$EXTERNALSYM RegDeleteKeyEx}
function RegDeleteKeyEx(hKey: HKEY; lpSubKey: PChar; samDesired: REGSAM;
  Reserved: DWORD): Longint; stdcall;
{$EXTERNALSYM RegDeleteKeyExA}
function RegDeleteKeyExA(hKey: HKEY; lpSubKey: PAnsiChar; samDesired: REGSAM;
  Reserved: DWORD): Longint; stdcall;
{$EXTERNALSYM RegDeleteKeyExW}
function RegDeleteKeyExW(hKey: HKEY; lpSubKey: PWideChar; samDesired: REGSAM;
  Reserved: DWORD): Longint; stdcall;
{ Loads a MUI string ("@file.dll,-id" values). cbOutBuf and pcbData are in
  bytes; pszDirectory may be nil. RegLoadMUIStringA always returns
  ERROR_CALL_NOT_IMPLEMENTED (documented). }
{$EXTERNALSYM RegLoadMUIString}
function RegLoadMUIString(hKey: HKEY; pszValue: PChar; pszOutBuf: PChar; cbOutBuf: DWORD;
  pcbData: LPDWORD; Flags: DWORD; pszDirectory: PChar): Longint; stdcall;
{$EXTERNALSYM RegLoadMUIStringA}
function RegLoadMUIStringA(hKey: HKEY; pszValue: PAnsiChar; pszOutBuf: PAnsiChar; cbOutBuf: DWORD;
  pcbData: LPDWORD; Flags: DWORD; pszDirectory: PAnsiChar): Longint; stdcall;
{$EXTERNALSYM RegLoadMUIStringW}
function RegLoadMUIStringW(hKey: HKEY; pszValue: PWideChar; pszOutBuf: PWideChar; cbOutBuf: DWORD;
  pcbData: LPDWORD; Flags: DWORD; pszDirectory: PWideChar): Longint; stdcall;
{ Loads a private hive file (no administrator rights needed); close the key
  to unload it. }
{$EXTERNALSYM RegLoadAppKey}
function RegLoadAppKey(lpFile: PChar; out phkResult: HKEY; samDesired: REGSAM;
  dwOptions: DWORD; Reserved: DWORD): Longint; stdcall;
{$EXTERNALSYM RegLoadAppKeyA}
function RegLoadAppKeyA(lpFile: PAnsiChar; out phkResult: HKEY; samDesired: REGSAM;
  dwOptions: DWORD; Reserved: DWORD): Longint; stdcall;
{$EXTERNALSYM RegLoadAppKeyW}
function RegLoadAppKeyW(lpFile: PWideChar; out phkResult: HKEY; samDesired: REGSAM;
  dwOptions: DWORD; Reserved: DWORD): Longint; stdcall;
{$EXTERNALSYM RegRenameKey}
function RegRenameKey(hKey: HKEY; lpSubKeyName, lpNewKeyName: PWideChar): Longint; stdcall;
{ HKEY_CURRENT_USER of the user the thread impersonates. }
{$EXTERNALSYM RegOpenCurrentUser}
function RegOpenCurrentUser(samDesired: REGSAM; out phkResult: HKEY): Longint; stdcall;
{$EXTERNALSYM RegOpenUserClassesRoot}
function RegOpenUserClassesRoot(hToken: THandle; dwOptions: DWORD; samDesired: REGSAM;
  out phkResult: HKEY): Longint; stdcall;
{ Maps a predefined key (HKEY_CURRENT_USER ...) to hNewHKey for this
  process; hNewHKey = 0 restores it. }
{$EXTERNALSYM RegOverridePredefKey}
function RegOverridePredefKey(hKey: HKEY; hNewHKey: HKEY): Longint; stdcall;

{ ====== Security identifiers, descriptors, tokens (winnt.h, sddl.h) ====== }

type
  {$EXTERNALSYM WELL_KNOWN_SID_TYPE}
  WELL_KNOWN_SID_TYPE = Integer;
  {$EXTERNALSYM TOKEN_ELEVATION_TYPE}
  TOKEN_ELEVATION_TYPE = Integer;

const
  {$EXTERNALSYM SECURITY_MAX_SID_SIZE}
  SECURITY_MAX_SID_SIZE = 68;
  {$EXTERNALSYM SDDL_REVISION_1}
  SDDL_REVISION_1 = 1;
  {$EXTERNALSYM SDDL_REVISION}
  SDDL_REVISION   = SDDL_REVISION_1;

  { Identifier authorities }
  {$EXTERNALSYM SECURITY_NULL_SID_AUTHORITY}
  SECURITY_NULL_SID_AUTHORITY: TSIDIdentifierAuthority = (Value: (0, 0, 0, 0, 0, 0));
  {$EXTERNALSYM SECURITY_WORLD_SID_AUTHORITY}
  SECURITY_WORLD_SID_AUTHORITY: TSIDIdentifierAuthority = (Value: (0, 0, 0, 0, 0, 1));
  {$EXTERNALSYM SECURITY_LOCAL_SID_AUTHORITY}
  SECURITY_LOCAL_SID_AUTHORITY: TSIDIdentifierAuthority = (Value: (0, 0, 0, 0, 0, 2));
  {$EXTERNALSYM SECURITY_CREATOR_SID_AUTHORITY}
  SECURITY_CREATOR_SID_AUTHORITY: TSIDIdentifierAuthority = (Value: (0, 0, 0, 0, 0, 3));
  {$EXTERNALSYM SECURITY_NT_AUTHORITY}
  SECURITY_NT_AUTHORITY: TSIDIdentifierAuthority = (Value: (0, 0, 0, 0, 0, 5));
  {$EXTERNALSYM SECURITY_MANDATORY_LABEL_AUTHORITY}
  SECURITY_MANDATORY_LABEL_AUTHORITY: TSIDIdentifierAuthority = (Value: (0, 0, 0, 0, 0, 16));
  {$EXTERNALSYM SECURITY_APP_PACKAGE_AUTHORITY}
  SECURITY_APP_PACKAGE_AUTHORITY: TSIDIdentifierAuthority = (Value: (0, 0, 0, 0, 0, 15));

  { Relative identifiers }
  {$EXTERNALSYM SECURITY_INTERACTIVE_RID}
  SECURITY_INTERACTIVE_RID         = $00000004;
  {$EXTERNALSYM SECURITY_SERVICE_RID}
  SECURITY_SERVICE_RID             = $00000006;
  {$EXTERNALSYM SECURITY_AUTHENTICATED_USER_RID}
  SECURITY_AUTHENTICATED_USER_RID  = $0000000B;
  {$EXTERNALSYM SECURITY_LOCAL_SYSTEM_RID}
  SECURITY_LOCAL_SYSTEM_RID        = $00000012;
  {$EXTERNALSYM SECURITY_LOCAL_SERVICE_RID}
  SECURITY_LOCAL_SERVICE_RID       = $00000013;
  {$EXTERNALSYM SECURITY_NETWORK_SERVICE_RID}
  SECURITY_NETWORK_SERVICE_RID     = $00000014;
  {$EXTERNALSYM SECURITY_BUILTIN_DOMAIN_RID}
  SECURITY_BUILTIN_DOMAIN_RID      = $00000020;
  {$EXTERNALSYM DOMAIN_USER_RID_ADMIN}
  DOMAIN_USER_RID_ADMIN            = $000001F4;
  {$EXTERNALSYM DOMAIN_USER_RID_GUEST}
  DOMAIN_USER_RID_GUEST            = $000001F5;
  {$EXTERNALSYM DOMAIN_ALIAS_RID_ADMINS}
  DOMAIN_ALIAS_RID_ADMINS          = $00000220;
  {$EXTERNALSYM DOMAIN_ALIAS_RID_USERS}
  DOMAIN_ALIAS_RID_USERS           = $00000221;
  {$EXTERNALSYM DOMAIN_ALIAS_RID_GUESTS}
  DOMAIN_ALIAS_RID_GUESTS          = $00000222;
  {$EXTERNALSYM DOMAIN_ALIAS_RID_POWER_USERS}
  DOMAIN_ALIAS_RID_POWER_USERS     = $00000223;

  { Integrity levels (RIDs under SECURITY_MANDATORY_LABEL_AUTHORITY) }
  {$EXTERNALSYM SECURITY_MANDATORY_UNTRUSTED_RID}
  SECURITY_MANDATORY_UNTRUSTED_RID         = $00000000;
  {$EXTERNALSYM SECURITY_MANDATORY_LOW_RID}
  SECURITY_MANDATORY_LOW_RID               = $00001000;
  {$EXTERNALSYM SECURITY_MANDATORY_MEDIUM_RID}
  SECURITY_MANDATORY_MEDIUM_RID            = $00002000;
  {$EXTERNALSYM SECURITY_MANDATORY_MEDIUM_PLUS_RID}
  SECURITY_MANDATORY_MEDIUM_PLUS_RID       = SECURITY_MANDATORY_MEDIUM_RID + $100;
  {$EXTERNALSYM SECURITY_MANDATORY_HIGH_RID}
  SECURITY_MANDATORY_HIGH_RID              = $00003000;
  {$EXTERNALSYM SECURITY_MANDATORY_SYSTEM_RID}
  SECURITY_MANDATORY_SYSTEM_RID            = $00004000;
  {$EXTERNALSYM SECURITY_MANDATORY_PROTECTED_PROCESS_RID}
  SECURITY_MANDATORY_PROTECTED_PROCESS_RID = $00005000;

  { SID_AND_ATTRIBUTES.Attributes of token groups }
  {$EXTERNALSYM SE_GROUP_MANDATORY}
  SE_GROUP_MANDATORY          = $00000001;
  {$EXTERNALSYM SE_GROUP_ENABLED_BY_DEFAULT}
  SE_GROUP_ENABLED_BY_DEFAULT = $00000002;
  {$EXTERNALSYM SE_GROUP_ENABLED}
  SE_GROUP_ENABLED            = $00000004;
  {$EXTERNALSYM SE_GROUP_OWNER}
  SE_GROUP_OWNER              = $00000008;
  {$EXTERNALSYM SE_GROUP_USE_FOR_DENY_ONLY}
  SE_GROUP_USE_FOR_DENY_ONLY  = $00000010;
  {$EXTERNALSYM SE_GROUP_INTEGRITY}
  SE_GROUP_INTEGRITY          = $00000020;
  {$EXTERNALSYM SE_GROUP_INTEGRITY_ENABLED}
  SE_GROUP_INTEGRITY_ENABLED  = $00000040;
  {$EXTERNALSYM SE_GROUP_RESOURCE}
  SE_GROUP_RESOURCE           = $20000000;
  {$EXTERNALSYM SE_GROUP_LOGON_ID}
  SE_GROUP_LOGON_ID           = DWORD($C0000000);

  { TOKEN_ELEVATION_TYPE }
  {$EXTERNALSYM TokenElevationTypeDefault}
  TokenElevationTypeDefault = 1;
  {$EXTERNALSYM TokenElevationTypeFull}
  TokenElevationTypeFull    = 2;
  {$EXTERNALSYM TokenElevationTypeLimited}
  TokenElevationTypeLimited = 3;

  { Token information classes after TokenStatistics, typed for
    Windows.GetTokenInformation / SetTokenInformation (TTokenInformationClass
    stores the full DWORD). }
  {$EXTERNALSYM TokenRestrictedSids}
  TokenRestrictedSids = TTokenInformationClass(11);
  {$EXTERNALSYM TokenSessionId}
  TokenSessionId = TTokenInformationClass(12);
  {$EXTERNALSYM TokenGroupsAndPrivileges}
  TokenGroupsAndPrivileges = TTokenInformationClass(13);
  {$EXTERNALSYM TokenSessionReference}
  TokenSessionReference = TTokenInformationClass(14);
  {$EXTERNALSYM TokenSandBoxInert}
  TokenSandBoxInert = TTokenInformationClass(15);
  {$EXTERNALSYM TokenAuditPolicy}
  TokenAuditPolicy = TTokenInformationClass(16);
  {$EXTERNALSYM TokenOrigin}
  TokenOrigin = TTokenInformationClass(17);
  {$EXTERNALSYM TokenElevationType}
  TokenElevationType = TTokenInformationClass(18);
  {$EXTERNALSYM TokenLinkedToken}
  TokenLinkedToken = TTokenInformationClass(19);
  {$EXTERNALSYM TokenElevation}
  TokenElevation = TTokenInformationClass(20);
  {$EXTERNALSYM TokenHasRestrictions}
  TokenHasRestrictions = TTokenInformationClass(21);
  {$EXTERNALSYM TokenAccessInformation}
  TokenAccessInformation = TTokenInformationClass(22);
  {$EXTERNALSYM TokenVirtualizationAllowed}
  TokenVirtualizationAllowed = TTokenInformationClass(23);
  {$EXTERNALSYM TokenVirtualizationEnabled}
  TokenVirtualizationEnabled = TTokenInformationClass(24);
  {$EXTERNALSYM TokenIntegrityLevel}
  TokenIntegrityLevel = TTokenInformationClass(25);
  {$EXTERNALSYM TokenUIAccess}
  TokenUIAccess = TTokenInformationClass(26);
  {$EXTERNALSYM TokenMandatoryPolicy}
  TokenMandatoryPolicy = TTokenInformationClass(27);
  {$EXTERNALSYM TokenLogonSid}
  TokenLogonSid = TTokenInformationClass(28);
  {$EXTERNALSYM TokenIsAppContainer}
  TokenIsAppContainer = TTokenInformationClass(29);
  {$EXTERNALSYM TokenCapabilities}
  TokenCapabilities = TTokenInformationClass(30);
  {$EXTERNALSYM TokenAppContainerSid}
  TokenAppContainerSid = TTokenInformationClass(31);
  {$EXTERNALSYM TokenAppContainerNumber}
  TokenAppContainerNumber = TTokenInformationClass(32);
  {$EXTERNALSYM TokenUserClaimAttributes}
  TokenUserClaimAttributes = TTokenInformationClass(33);
  {$EXTERNALSYM TokenDeviceClaimAttributes}
  TokenDeviceClaimAttributes = TTokenInformationClass(34);
  {$EXTERNALSYM TokenRestrictedUserClaimAttributes}
  TokenRestrictedUserClaimAttributes = TTokenInformationClass(35);
  {$EXTERNALSYM TokenRestrictedDeviceClaimAttributes}
  TokenRestrictedDeviceClaimAttributes = TTokenInformationClass(36);
  {$EXTERNALSYM TokenDeviceGroups}
  TokenDeviceGroups = TTokenInformationClass(37);
  {$EXTERNALSYM TokenRestrictedDeviceGroups}
  TokenRestrictedDeviceGroups = TTokenInformationClass(38);
  {$EXTERNALSYM TokenSecurityAttributes}
  TokenSecurityAttributes = TTokenInformationClass(39);
  {$EXTERNALSYM TokenIsRestricted}
  TokenIsRestricted = TTokenInformationClass(40);
  {$EXTERNALSYM TokenProcessTrustLevel}
  TokenProcessTrustLevel = TTokenInformationClass(41);
  {$EXTERNALSYM TokenPrivateNameSpace}
  TokenPrivateNameSpace = TTokenInformationClass(42);
  {$EXTERNALSYM TokenSingletonAttributes}
  TokenSingletonAttributes = TTokenInformationClass(43);
  {$EXTERNALSYM TokenBnoIsolation}
  TokenBnoIsolation = TTokenInformationClass(44);
  {$EXTERNALSYM TokenChildProcessFlags}
  TokenChildProcessFlags = TTokenInformationClass(45);
  {$EXTERNALSYM TokenIsLessPrivilegedAppContainer}
  TokenIsLessPrivilegedAppContainer = TTokenInformationClass(46);

  { WELL_KNOWN_SID_TYPE }
  {$EXTERNALSYM WinNullSid}
  WinNullSid = 0;
  {$EXTERNALSYM WinWorldSid}
  WinWorldSid = 1;
  {$EXTERNALSYM WinLocalSid}
  WinLocalSid = 2;
  {$EXTERNALSYM WinCreatorOwnerSid}
  WinCreatorOwnerSid = 3;
  {$EXTERNALSYM WinCreatorGroupSid}
  WinCreatorGroupSid = 4;
  {$EXTERNALSYM WinCreatorOwnerServerSid}
  WinCreatorOwnerServerSid = 5;
  {$EXTERNALSYM WinCreatorGroupServerSid}
  WinCreatorGroupServerSid = 6;
  {$EXTERNALSYM WinNtAuthoritySid}
  WinNtAuthoritySid = 7;
  {$EXTERNALSYM WinDialupSid}
  WinDialupSid = 8;
  {$EXTERNALSYM WinNetworkSid}
  WinNetworkSid = 9;
  {$EXTERNALSYM WinBatchSid}
  WinBatchSid = 10;
  {$EXTERNALSYM WinInteractiveSid}
  WinInteractiveSid = 11;
  {$EXTERNALSYM WinServiceSid}
  WinServiceSid = 12;
  {$EXTERNALSYM WinAnonymousSid}
  WinAnonymousSid = 13;
  {$EXTERNALSYM WinProxySid}
  WinProxySid = 14;
  {$EXTERNALSYM WinEnterpriseControllersSid}
  WinEnterpriseControllersSid = 15;
  {$EXTERNALSYM WinSelfSid}
  WinSelfSid = 16;
  {$EXTERNALSYM WinAuthenticatedUserSid}
  WinAuthenticatedUserSid = 17;
  {$EXTERNALSYM WinRestrictedCodeSid}
  WinRestrictedCodeSid = 18;
  {$EXTERNALSYM WinTerminalServerSid}
  WinTerminalServerSid = 19;
  {$EXTERNALSYM WinRemoteLogonIdSid}
  WinRemoteLogonIdSid = 20;
  {$EXTERNALSYM WinLogonIdsSid}
  WinLogonIdsSid = 21;
  {$EXTERNALSYM WinLocalSystemSid}
  WinLocalSystemSid = 22;
  {$EXTERNALSYM WinLocalServiceSid}
  WinLocalServiceSid = 23;
  {$EXTERNALSYM WinNetworkServiceSid}
  WinNetworkServiceSid = 24;
  {$EXTERNALSYM WinBuiltinDomainSid}
  WinBuiltinDomainSid = 25;
  {$EXTERNALSYM WinBuiltinAdministratorsSid}
  WinBuiltinAdministratorsSid = 26;
  {$EXTERNALSYM WinBuiltinUsersSid}
  WinBuiltinUsersSid = 27;
  {$EXTERNALSYM WinBuiltinGuestsSid}
  WinBuiltinGuestsSid = 28;
  {$EXTERNALSYM WinBuiltinPowerUsersSid}
  WinBuiltinPowerUsersSid = 29;
  {$EXTERNALSYM WinBuiltinAccountOperatorsSid}
  WinBuiltinAccountOperatorsSid = 30;
  {$EXTERNALSYM WinBuiltinSystemOperatorsSid}
  WinBuiltinSystemOperatorsSid = 31;
  {$EXTERNALSYM WinBuiltinPrintOperatorsSid}
  WinBuiltinPrintOperatorsSid = 32;
  {$EXTERNALSYM WinBuiltinBackupOperatorsSid}
  WinBuiltinBackupOperatorsSid = 33;
  {$EXTERNALSYM WinBuiltinReplicatorSid}
  WinBuiltinReplicatorSid = 34;
  {$EXTERNALSYM WinBuiltinPreWindows2000CompatibleAccessSid}
  WinBuiltinPreWindows2000CompatibleAccessSid = 35;
  {$EXTERNALSYM WinBuiltinRemoteDesktopUsersSid}
  WinBuiltinRemoteDesktopUsersSid = 36;
  {$EXTERNALSYM WinBuiltinNetworkConfigurationOperatorsSid}
  WinBuiltinNetworkConfigurationOperatorsSid = 37;
  {$EXTERNALSYM WinAccountAdministratorSid}
  WinAccountAdministratorSid = 38;
  {$EXTERNALSYM WinAccountGuestSid}
  WinAccountGuestSid = 39;
  {$EXTERNALSYM WinAccountKrbtgtSid}
  WinAccountKrbtgtSid = 40;
  {$EXTERNALSYM WinAccountDomainAdminsSid}
  WinAccountDomainAdminsSid = 41;
  {$EXTERNALSYM WinAccountDomainUsersSid}
  WinAccountDomainUsersSid = 42;
  {$EXTERNALSYM WinAccountDomainGuestsSid}
  WinAccountDomainGuestsSid = 43;
  {$EXTERNALSYM WinAccountComputersSid}
  WinAccountComputersSid = 44;
  {$EXTERNALSYM WinAccountControllersSid}
  WinAccountControllersSid = 45;
  {$EXTERNALSYM WinAccountCertAdminsSid}
  WinAccountCertAdminsSid = 46;
  {$EXTERNALSYM WinAccountSchemaAdminsSid}
  WinAccountSchemaAdminsSid = 47;
  {$EXTERNALSYM WinAccountEnterpriseAdminsSid}
  WinAccountEnterpriseAdminsSid = 48;
  {$EXTERNALSYM WinAccountPolicyAdminsSid}
  WinAccountPolicyAdminsSid = 49;
  {$EXTERNALSYM WinAccountRasAndIasServersSid}
  WinAccountRasAndIasServersSid = 50;
  {$EXTERNALSYM WinNTLMAuthenticationSid}
  WinNTLMAuthenticationSid = 51;
  {$EXTERNALSYM WinDigestAuthenticationSid}
  WinDigestAuthenticationSid = 52;
  {$EXTERNALSYM WinSChannelAuthenticationSid}
  WinSChannelAuthenticationSid = 53;
  {$EXTERNALSYM WinThisOrganizationSid}
  WinThisOrganizationSid = 54;
  {$EXTERNALSYM WinOtherOrganizationSid}
  WinOtherOrganizationSid = 55;
  {$EXTERNALSYM WinBuiltinIncomingForestTrustBuildersSid}
  WinBuiltinIncomingForestTrustBuildersSid = 56;
  {$EXTERNALSYM WinBuiltinPerfMonitoringUsersSid}
  WinBuiltinPerfMonitoringUsersSid = 57;
  {$EXTERNALSYM WinBuiltinPerfLoggingUsersSid}
  WinBuiltinPerfLoggingUsersSid = 58;
  {$EXTERNALSYM WinBuiltinAuthorizationAccessSid}
  WinBuiltinAuthorizationAccessSid = 59;
  {$EXTERNALSYM WinBuiltinTerminalServerLicenseServersSid}
  WinBuiltinTerminalServerLicenseServersSid = 60;
  {$EXTERNALSYM WinBuiltinDCOMUsersSid}
  WinBuiltinDCOMUsersSid = 61;
  {$EXTERNALSYM WinBuiltinIUsersSid}
  WinBuiltinIUsersSid = 62;
  {$EXTERNALSYM WinIUserSid}
  WinIUserSid = 63;
  {$EXTERNALSYM WinBuiltinCryptoOperatorsSid}
  WinBuiltinCryptoOperatorsSid = 64;
  {$EXTERNALSYM WinUntrustedLabelSid}
  WinUntrustedLabelSid = 65;
  {$EXTERNALSYM WinLowLabelSid}
  WinLowLabelSid = 66;
  {$EXTERNALSYM WinMediumLabelSid}
  WinMediumLabelSid = 67;
  {$EXTERNALSYM WinHighLabelSid}
  WinHighLabelSid = 68;
  {$EXTERNALSYM WinSystemLabelSid}
  WinSystemLabelSid = 69;
  {$EXTERNALSYM WinWriteRestrictedCodeSid}
  WinWriteRestrictedCodeSid = 70;
  {$EXTERNALSYM WinCreatorOwnerRightsSid}
  WinCreatorOwnerRightsSid = 71;
  {$EXTERNALSYM WinCacheablePrincipalsGroupSid}
  WinCacheablePrincipalsGroupSid = 72;
  {$EXTERNALSYM WinNonCacheablePrincipalsGroupSid}
  WinNonCacheablePrincipalsGroupSid = 73;
  {$EXTERNALSYM WinEnterpriseReadonlyControllersSid}
  WinEnterpriseReadonlyControllersSid = 74;
  {$EXTERNALSYM WinAccountReadonlyControllersSid}
  WinAccountReadonlyControllersSid = 75;
  {$EXTERNALSYM WinBuiltinEventLogReadersGroup}
  WinBuiltinEventLogReadersGroup = 76;
  {$EXTERNALSYM WinNewEnterpriseReadonlyControllersSid}
  WinNewEnterpriseReadonlyControllersSid = 77;
  {$EXTERNALSYM WinBuiltinCertSvcDComAccessGroup}
  WinBuiltinCertSvcDComAccessGroup = 78;
  {$EXTERNALSYM WinMediumPlusLabelSid}
  WinMediumPlusLabelSid = 79;
  {$EXTERNALSYM WinLocalLogonSid}
  WinLocalLogonSid = 80;
  {$EXTERNALSYM WinConsoleLogonSid}
  WinConsoleLogonSid = 81;
  {$EXTERNALSYM WinThisOrganizationCertificateSid}
  WinThisOrganizationCertificateSid = 82;
  {$EXTERNALSYM WinApplicationPackageAuthoritySid}
  WinApplicationPackageAuthoritySid = 83;
  {$EXTERNALSYM WinBuiltinAnyPackageSid}
  WinBuiltinAnyPackageSid = 84;
  {$EXTERNALSYM WinCapabilityInternetClientSid}
  WinCapabilityInternetClientSid = 85;
  {$EXTERNALSYM WinCapabilityInternetClientServerSid}
  WinCapabilityInternetClientServerSid = 86;
  {$EXTERNALSYM WinCapabilityPrivateNetworkClientServerSid}
  WinCapabilityPrivateNetworkClientServerSid = 87;
  {$EXTERNALSYM WinCapabilityPicturesLibrarySid}
  WinCapabilityPicturesLibrarySid = 88;
  {$EXTERNALSYM WinCapabilityVideosLibrarySid}
  WinCapabilityVideosLibrarySid = 89;
  {$EXTERNALSYM WinCapabilityMusicLibrarySid}
  WinCapabilityMusicLibrarySid = 90;
  {$EXTERNALSYM WinCapabilityDocumentsLibrarySid}
  WinCapabilityDocumentsLibrarySid = 91;
  {$EXTERNALSYM WinCapabilitySharedUserCertificatesSid}
  WinCapabilitySharedUserCertificatesSid = 92;
  {$EXTERNALSYM WinCapabilityEnterpriseAuthenticationSid}
  WinCapabilityEnterpriseAuthenticationSid = 93;
  {$EXTERNALSYM WinCapabilityRemovableStorageSid}
  WinCapabilityRemovableStorageSid = 94;
  {$EXTERNALSYM WinBuiltinRDSRemoteAccessServersSid}
  WinBuiltinRDSRemoteAccessServersSid = 95;
  {$EXTERNALSYM WinBuiltinRDSEndpointServersSid}
  WinBuiltinRDSEndpointServersSid = 96;
  {$EXTERNALSYM WinBuiltinRDSManagementServersSid}
  WinBuiltinRDSManagementServersSid = 97;
  {$EXTERNALSYM WinUserModeDriversSid}
  WinUserModeDriversSid = 98;
  {$EXTERNALSYM WinBuiltinHyperVAdminsSid}
  WinBuiltinHyperVAdminsSid = 99;
  {$EXTERNALSYM WinAccountCloneableControllersSid}
  WinAccountCloneableControllersSid = 100;
  {$EXTERNALSYM WinBuiltinAccessControlAssistanceOperatorsSid}
  WinBuiltinAccessControlAssistanceOperatorsSid = 101;
  {$EXTERNALSYM WinBuiltinRemoteManagementUsersSid}
  WinBuiltinRemoteManagementUsersSid = 102;
  {$EXTERNALSYM WinAuthenticationAuthorityAssertedSid}
  WinAuthenticationAuthorityAssertedSid = 103;
  {$EXTERNALSYM WinAuthenticationServiceAssertedSid}
  WinAuthenticationServiceAssertedSid = 104;
  {$EXTERNALSYM WinLocalAccountSid}
  WinLocalAccountSid = 105;
  {$EXTERNALSYM WinLocalAccountAndAdministratorSid}
  WinLocalAccountAndAdministratorSid = 106;
  {$EXTERNALSYM WinAccountProtectedUsersSid}
  WinAccountProtectedUsersSid = 107;
  {$EXTERNALSYM WinCapabilityAppointmentsSid}
  WinCapabilityAppointmentsSid = 108;
  {$EXTERNALSYM WinCapabilityContactsSid}
  WinCapabilityContactsSid = 109;
  {$EXTERNALSYM WinAccountDefaultSystemManagedSid}
  WinAccountDefaultSystemManagedSid = 110;
  {$EXTERNALSYM WinBuiltinDefaultSystemManagedGroupSid}
  WinBuiltinDefaultSystemManagedGroupSid = 111;
  {$EXTERNALSYM WinBuiltinStorageReplicaAdminsSid}
  WinBuiltinStorageReplicaAdminsSid = 112;
  {$EXTERNALSYM WinAccountKeyAdminsSid}
  WinAccountKeyAdminsSid = 113;
  {$EXTERNALSYM WinAccountEnterpriseKeyAdminsSid}
  WinAccountEnterpriseKeyAdminsSid = 114;
  {$EXTERNALSYM WinAuthenticationKeyTrustSid}
  WinAuthenticationKeyTrustSid = 115;
  {$EXTERNALSYM WinAuthenticationKeyPropertyMFASid}
  WinAuthenticationKeyPropertyMFASid = 116;
  {$EXTERNALSYM WinAuthenticationKeyPropertyAttestationSid}
  WinAuthenticationKeyPropertyAttestationSid = 117;
  {$EXTERNALSYM WinAuthenticationFreshKeyAuthSid}
  WinAuthenticationFreshKeyAuthSid = 118;
  {$EXTERNALSYM WinBuiltinDeviceOwnersSid}
  WinBuiltinDeviceOwnersSid = 119;
  {$EXTERNALSYM WinBuiltinUserModeHardwareOperatorsSid}
  WinBuiltinUserModeHardwareOperatorsSid = 120;
  {$EXTERNALSYM WinBuiltinOpenSSHUsersSid}
  WinBuiltinOpenSSHUsersSid = 121;

type
  PTokenElevation = ^TTokenElevation;
  {$EXTERNALSYM _TOKEN_ELEVATION}
  _TOKEN_ELEVATION = record
    TokenIsElevated: DWORD;
  end;
  {$EXTERNALSYM TOKEN_ELEVATION}
  TOKEN_ELEVATION = _TOKEN_ELEVATION;
  {$EXTERNALSYM PTOKEN_ELEVATION}
  PTOKEN_ELEVATION = PTokenElevation;
  TTokenElevation = _TOKEN_ELEVATION;

  PTokenLinkedToken = ^TTokenLinkedToken;
  {$EXTERNALSYM _TOKEN_LINKED_TOKEN}
  _TOKEN_LINKED_TOKEN = record
    LinkedToken: THandle;                  // close it with CloseHandle
  end;
  {$EXTERNALSYM TOKEN_LINKED_TOKEN}
  TOKEN_LINKED_TOKEN = _TOKEN_LINKED_TOKEN;
  {$EXTERNALSYM PTOKEN_LINKED_TOKEN}
  PTOKEN_LINKED_TOKEN = PTokenLinkedToken;
  TTokenLinkedToken = _TOKEN_LINKED_TOKEN;

  PTokenMandatoryLabel = ^TTokenMandatoryLabel;
  {$EXTERNALSYM _TOKEN_MANDATORY_LABEL}
  _TOKEN_MANDATORY_LABEL = record
    Label_: TSIDAndAttributes;             // C name: Label
  end;
  {$EXTERNALSYM TOKEN_MANDATORY_LABEL}
  TOKEN_MANDATORY_LABEL = _TOKEN_MANDATORY_LABEL;
  {$EXTERNALSYM PTOKEN_MANDATORY_LABEL}
  PTOKEN_MANDATORY_LABEL = PTokenMandatoryLabel;
  TTokenMandatoryLabel = _TOKEN_MANDATORY_LABEL;

  PTokenUser = ^TTokenUser;
  {$EXTERNALSYM _TOKEN_USER}
  _TOKEN_USER = record
    User: TSIDAndAttributes;
  end;
  {$EXTERNALSYM TOKEN_USER}
  TOKEN_USER = _TOKEN_USER;
  {$EXTERNALSYM PTOKEN_USER}
  PTOKEN_USER = PTokenUser;
  TTokenUser = _TOKEN_USER;

{ Windows 2000. The strings and SIDs returned are allocated with LocalAlloc:
  free them with LocalFree. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM ConvertSidToStringSid}
function ConvertSidToStringSid(Sid: PSID; out StringSid: PChar): BOOL; stdcall;
{$EXTERNALSYM ConvertSidToStringSidA}
function ConvertSidToStringSidA(Sid: PSID; out StringSid: PAnsiChar): BOOL; stdcall;
{$EXTERNALSYM ConvertSidToStringSidW}
function ConvertSidToStringSidW(Sid: PSID; out StringSid: PWideChar): BOOL; stdcall;
{$EXTERNALSYM ConvertStringSidToSid}
function ConvertStringSidToSid(StringSid: PChar; out Sid: PSID): BOOL; stdcall;
{$EXTERNALSYM ConvertStringSidToSidA}
function ConvertStringSidToSidA(StringSid: PAnsiChar; out Sid: PSID): BOOL; stdcall;
{$EXTERNALSYM ConvertStringSidToSidW}
function ConvertStringSidToSidW(StringSid: PWideChar; out Sid: PSID): BOOL; stdcall;
{ StringSDRevision: SDDL_REVISION_1; SecurityDescriptorSize may be nil. }
{$EXTERNALSYM ConvertStringSecurityDescriptorToSecurityDescriptor}
function ConvertStringSecurityDescriptorToSecurityDescriptor(StringSecurityDescriptor: PChar;
  StringSDRevision: DWORD; out SecurityDescriptor: PSECURITY_DESCRIPTOR;
  SecurityDescriptorSize: PULONG): BOOL; stdcall;
{$EXTERNALSYM ConvertStringSecurityDescriptorToSecurityDescriptorA}
function ConvertStringSecurityDescriptorToSecurityDescriptorA(StringSecurityDescriptor: PAnsiChar;
  StringSDRevision: DWORD; out SecurityDescriptor: PSECURITY_DESCRIPTOR;
  SecurityDescriptorSize: PULONG): BOOL; stdcall;
{$EXTERNALSYM ConvertStringSecurityDescriptorToSecurityDescriptorW}
function ConvertStringSecurityDescriptorToSecurityDescriptorW(StringSecurityDescriptor: PWideChar;
  StringSDRevision: DWORD; out SecurityDescriptor: PSECURITY_DESCRIPTOR;
  SecurityDescriptorSize: PULONG): BOOL; stdcall;
{ StringSecurityDescriptorLen may be nil. }
{$EXTERNALSYM ConvertSecurityDescriptorToStringSecurityDescriptor}
function ConvertSecurityDescriptorToStringSecurityDescriptor(SecurityDescriptor: PSECURITY_DESCRIPTOR;
  RequestedStringSDRevision: DWORD; SecurityInformation: SECURITY_INFORMATION;
  out StringSecurityDescriptor: PChar; StringSecurityDescriptorLen: PULONG): BOOL; stdcall;
{$EXTERNALSYM ConvertSecurityDescriptorToStringSecurityDescriptorA}
function ConvertSecurityDescriptorToStringSecurityDescriptorA(SecurityDescriptor: PSECURITY_DESCRIPTOR;
  RequestedStringSDRevision: DWORD; SecurityInformation: SECURITY_INFORMATION;
  out StringSecurityDescriptor: PAnsiChar; StringSecurityDescriptorLen: PULONG): BOOL; stdcall;
{$EXTERNALSYM ConvertSecurityDescriptorToStringSecurityDescriptorW}
function ConvertSecurityDescriptorToStringSecurityDescriptorW(SecurityDescriptor: PSECURITY_DESCRIPTOR;
  RequestedStringSDRevision: DWORD; SecurityInformation: SECURITY_INFORMATION;
  out StringSecurityDescriptor: PWideChar; StringSecurityDescriptorLen: PULONG): BOOL; stdcall;

{ Windows XP. pSid: a buffer of cbSid bytes (SECURITY_MAX_SID_SIZE is
  enough); DomainSid may be nil for SIDs without a domain. Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM CreateWellKnownSid}
function CreateWellKnownSid(WellKnownSidType: WELL_KNOWN_SID_TYPE; DomainSid: PSID; pSid: PSID;
  var cbSid: DWORD): BOOL; stdcall;
{$EXTERNALSYM IsWellKnownSid}
function IsWellKnownSid(pSid: PSID; WellKnownSidType: WELL_KNOWN_SID_TYPE): BOOL; stdcall;
{ Windows 2000. TokenHandle = 0: the impersonation token of the thread, or
  the primary token of the process. Fallback: False
  (ERROR_CALL_NOT_IMPLEMENTED). }
{$EXTERNALSYM CheckTokenMembership}
function CheckTokenMembership(TokenHandle: THandle; SidToCheck: PSID;
  out IsMember: BOOL): BOOL; stdcall;

{ ====== Credentials (wincred.h, Windows XP) =============================== }

const
  { CREDENTIAL.Type_ }
  {$EXTERNALSYM CRED_TYPE_GENERIC}
  CRED_TYPE_GENERIC                 = 1;
  {$EXTERNALSYM CRED_TYPE_DOMAIN_PASSWORD}
  CRED_TYPE_DOMAIN_PASSWORD         = 2;
  {$EXTERNALSYM CRED_TYPE_DOMAIN_CERTIFICATE}
  CRED_TYPE_DOMAIN_CERTIFICATE      = 3;
  {$EXTERNALSYM CRED_TYPE_DOMAIN_VISIBLE_PASSWORD}
  CRED_TYPE_DOMAIN_VISIBLE_PASSWORD = 4;
  {$EXTERNALSYM CRED_TYPE_GENERIC_CERTIFICATE}
  CRED_TYPE_GENERIC_CERTIFICATE     = 5;
  {$EXTERNALSYM CRED_TYPE_DOMAIN_EXTENDED}
  CRED_TYPE_DOMAIN_EXTENDED         = 6;
  {$EXTERNALSYM CRED_TYPE_MAXIMUM}
  CRED_TYPE_MAXIMUM                 = 7;
  {$EXTERNALSYM CRED_TYPE_MAXIMUM_EX}
  CRED_TYPE_MAXIMUM_EX              = CRED_TYPE_MAXIMUM + 1000;

  { CREDENTIAL.Persist }
  {$EXTERNALSYM CRED_PERSIST_NONE}
  CRED_PERSIST_NONE          = 0;
  {$EXTERNALSYM CRED_PERSIST_SESSION}
  CRED_PERSIST_SESSION       = 1;
  {$EXTERNALSYM CRED_PERSIST_LOCAL_MACHINE}
  CRED_PERSIST_LOCAL_MACHINE = 2;
  {$EXTERNALSYM CRED_PERSIST_ENTERPRISE}
  CRED_PERSIST_ENTERPRISE    = 3;

  { CREDENTIAL.Flags }
  {$EXTERNALSYM CRED_FLAGS_PASSWORD_FOR_CERT}
  CRED_FLAGS_PASSWORD_FOR_CERT  = $0001;
  {$EXTERNALSYM CRED_FLAGS_PROMPT_NOW}
  CRED_FLAGS_PROMPT_NOW         = $0002;
  {$EXTERNALSYM CRED_FLAGS_USERNAME_TARGET}
  CRED_FLAGS_USERNAME_TARGET    = $0004;
  {$EXTERNALSYM CRED_FLAGS_OWF_CRED_BLOB}
  CRED_FLAGS_OWF_CRED_BLOB      = $0008;
  {$EXTERNALSYM CRED_FLAGS_REQUIRE_CONFIRMATION}
  CRED_FLAGS_REQUIRE_CONFIRMATION = $0010;
  {$EXTERNALSYM CRED_FLAGS_WILDCARD_MATCH}
  CRED_FLAGS_WILDCARD_MATCH     = $0020;
  {$EXTERNALSYM CRED_FLAGS_VSM_PROTECTED}
  CRED_FLAGS_VSM_PROTECTED      = $0040;
  {$EXTERNALSYM CRED_FLAGS_NGC_CERT}
  CRED_FLAGS_NGC_CERT           = $0080;
  {$EXTERNALSYM CRED_FLAGS_VALID_FLAGS}
  CRED_FLAGS_VALID_FLAGS        = $F0FF;
  {$EXTERNALSYM CRED_FLAGS_VALID_INPUT_FLAGS}
  CRED_FLAGS_VALID_INPUT_FLAGS  = $F09F;

  { Limits }
  {$EXTERNALSYM CRED_MAX_STRING_LENGTH}
  CRED_MAX_STRING_LENGTH              = 256;
  {$EXTERNALSYM CRED_MAX_USERNAME_LENGTH}
  CRED_MAX_USERNAME_LENGTH            = 256 + 1 + 256;
  {$EXTERNALSYM CRED_MAX_GENERIC_TARGET_NAME_LENGTH}
  CRED_MAX_GENERIC_TARGET_NAME_LENGTH = 32767;
  {$EXTERNALSYM CRED_MAX_DOMAIN_TARGET_NAME_LENGTH}
  CRED_MAX_DOMAIN_TARGET_NAME_LENGTH  = 256 + 1 + 80;
  {$EXTERNALSYM CRED_MAX_CREDENTIAL_BLOB_SIZE}
  CRED_MAX_CREDENTIAL_BLOB_SIZE       = 5 * 512;
  {$EXTERNALSYM CRED_MAX_ATTRIBUTES}
  CRED_MAX_ATTRIBUTES                 = 64;
  {$EXTERNALSYM CRED_MAX_VALUE_SIZE}
  CRED_MAX_VALUE_SIZE                 = 256;

  { CredEnumerate Flags }
  {$EXTERNALSYM CRED_ENUMERATE_ALL_CREDENTIALS}
  CRED_ENUMERATE_ALL_CREDENTIALS = $1;
  { CredWrite Flags }
  {$EXTERNALSYM CRED_PRESERVE_CREDENTIAL_BLOB}
  CRED_PRESERVE_CREDENTIAL_BLOB  = $1;

type
  PCredentialAttributeA = ^TCredentialAttributeA;
  PCredentialAttributeW = ^TCredentialAttributeW;
  PCredentialAttribute = PCredentialAttributeA;
  {$EXTERNALSYM _CREDENTIAL_ATTRIBUTEA}
  _CREDENTIAL_ATTRIBUTEA = record
    Keyword: PAnsiChar;
    Flags: DWORD;
    ValueSize: DWORD;
    Value: PByte;
  end;
  {$EXTERNALSYM _CREDENTIAL_ATTRIBUTEW}
  _CREDENTIAL_ATTRIBUTEW = record
    Keyword: PWideChar;
    Flags: DWORD;
    ValueSize: DWORD;
    Value: PByte;
  end;
  {$EXTERNALSYM CREDENTIAL_ATTRIBUTEA}
  CREDENTIAL_ATTRIBUTEA = _CREDENTIAL_ATTRIBUTEA;
  {$EXTERNALSYM CREDENTIAL_ATTRIBUTEW}
  CREDENTIAL_ATTRIBUTEW = _CREDENTIAL_ATTRIBUTEW;
  {$EXTERNALSYM CREDENTIAL_ATTRIBUTE}
  CREDENTIAL_ATTRIBUTE = CREDENTIAL_ATTRIBUTEA;
  {$EXTERNALSYM PCREDENTIAL_ATTRIBUTEA}
  PCREDENTIAL_ATTRIBUTEA = PCredentialAttributeA;
  {$EXTERNALSYM PCREDENTIAL_ATTRIBUTEW}
  PCREDENTIAL_ATTRIBUTEW = PCredentialAttributeW;
  TCredentialAttributeA = _CREDENTIAL_ATTRIBUTEA;
  TCredentialAttributeW = _CREDENTIAL_ATTRIBUTEW;
  TCredentialAttribute = TCredentialAttributeA;

  {$EXTERNALSYM PCREDENTIALA}
  PCredentialA = ^TCredentialA;
  {$EXTERNALSYM PCREDENTIALW}
  PCredentialW = ^TCredentialW;
  PCredential = PCredentialA;
  {$EXTERNALSYM _CREDENTIALA}
  _CREDENTIALA = record
    Flags: DWORD;                          // CRED_FLAGS_*
    Type_: DWORD;                          // C name: Type; CRED_TYPE_*
    TargetName: PAnsiChar;
    Comment: PAnsiChar;
    LastWritten: TFileTime;
    CredentialBlobSize: DWORD;
    CredentialBlob: PByte;
    Persist: DWORD;                        // CRED_PERSIST_*
    AttributeCount: DWORD;
    Attributes: PCredentialAttributeA;
    TargetAlias: PAnsiChar;
    UserName: PAnsiChar;
  end;
  {$EXTERNALSYM _CREDENTIALW}
  _CREDENTIALW = record
    Flags: DWORD;
    Type_: DWORD;
    TargetName: PWideChar;
    Comment: PWideChar;
    LastWritten: TFileTime;
    CredentialBlobSize: DWORD;
    CredentialBlob: PByte;
    Persist: DWORD;
    AttributeCount: DWORD;
    Attributes: PCredentialAttributeW;
    TargetAlias: PWideChar;
    UserName: PWideChar;
  end;
  {$EXTERNALSYM CREDENTIALA}
  CREDENTIALA = _CREDENTIALA;
  {$EXTERNALSYM CREDENTIALW}
  CREDENTIALW = _CREDENTIALW;
  {$EXTERNALSYM CREDENTIAL}
  CREDENTIAL = CREDENTIALA;
  TCredentialA = _CREDENTIALA;
  TCredentialW = _CREDENTIALW;
  TCredential = TCredentialA;
  { CredEnumerate returns an array of credential pointers. }
  PPCredentialA = ^PCredentialA;
  PPCredentialW = ^PCredentialW;
  PPCredential = PPCredentialA;

{ Windows XP. Credentials returned by CredRead and CredEnumerate are freed
  with CredFree. Fallback: False (ERROR_CALL_NOT_IMPLEMENTED); CredFree does
  nothing. }
{$EXTERNALSYM CredRead}
function CredRead(TargetName: PChar; Type_: DWORD; Flags: DWORD;
  out Credential: PCredential): BOOL; stdcall;
{$EXTERNALSYM CredReadA}
function CredReadA(TargetName: PAnsiChar; Type_: DWORD; Flags: DWORD;
  out Credential: PCredentialA): BOOL; stdcall;
{$EXTERNALSYM CredReadW}
function CredReadW(TargetName: PWideChar; Type_: DWORD; Flags: DWORD;
  out Credential: PCredentialW): BOOL; stdcall;
{$EXTERNALSYM CredWrite}
function CredWrite(const Credential: TCredential; Flags: DWORD): BOOL; stdcall;
{$EXTERNALSYM CredWriteA}
function CredWriteA(const Credential: TCredentialA; Flags: DWORD): BOOL; stdcall;
{$EXTERNALSYM CredWriteW}
function CredWriteW(const Credential: TCredentialW; Flags: DWORD): BOOL; stdcall;
{$EXTERNALSYM CredDelete}
function CredDelete(TargetName: PChar; Type_: DWORD; Flags: DWORD): BOOL; stdcall;
{$EXTERNALSYM CredDeleteA}
function CredDeleteA(TargetName: PAnsiChar; Type_: DWORD; Flags: DWORD): BOOL; stdcall;
{$EXTERNALSYM CredDeleteW}
function CredDeleteW(TargetName: PWideChar; Type_: DWORD; Flags: DWORD): BOOL; stdcall;
{ Filter: nil or a target name prefix ending with '*'. }
{$EXTERNALSYM CredEnumerate}
function CredEnumerate(Filter: PChar; Flags: DWORD; out Count: DWORD;
  out Credential: PPCredential): BOOL; stdcall;
{$EXTERNALSYM CredEnumerateA}
function CredEnumerateA(Filter: PAnsiChar; Flags: DWORD; out Count: DWORD;
  out Credential: PPCredentialA): BOOL; stdcall;
{$EXTERNALSYM CredEnumerateW}
function CredEnumerateW(Filter: PWideChar; Flags: DWORD; out Count: DWORD;
  out Credential: PPCredentialW): BOOL; stdcall;
{$EXTERNALSYM CredFree}
procedure CredFree(Buffer: Pointer); stdcall;

{$IFDEF WINDOWSEX_TESTFALLBACKS}
{ Test builds only (compile with -DWINDOWSEX_TESTFALLBACKS): set to True
  before the first call into this unit to make every kernel32, user32,
  gdi32, advapi32 and ntdll function behave as if its export were missing (psapi, used by a
  fallback, stays available), so that the fallbacks can be exercised on a
  current system. }
var
  WindowsExSimulateMissing: Boolean;
{$ENDIF}

implementation

{ ---- run-time binding ---- }

type
  TModuleSlot = record
    Name: PChar;
    Handle: HMODULE;
    Tried: Boolean;
  end;

const
  ntdlllib = 'ntdll.dll';
  psapilib = 'psapi.dll';

var
  Kernel32Slot: TModuleSlot = (Name: kernel32; Handle: 0; Tried: False);
  User32Slot: TModuleSlot = (Name: user32; Handle: 0; Tried: False);
  NtdllSlot: TModuleSlot = (Name: ntdlllib; Handle: 0; Tried: False);
  PsapiSlot: TModuleSlot = (Name: psapilib; Handle: 0; Tried: False);

{ Loads a system DLL once, by full path from the system directory (no
  search-order planting), keeps the reference for the life of the process
  and looks up an export. A missing DLL is remembered; a function pointer is
  cached once found. }
function GetSlotProc(var Slot: TModuleSlot; var Proc: Pointer; Name: PChar): Boolean;
var
  Path: array[0..MAX_PATH + 16] of Char;
  Len: UINT;
begin
  {$IFDEF WINDOWSEX_TESTFALLBACKS}
  if WindowsExSimulateMissing and (@Slot <> @PsapiSlot) then
  begin
    Result := False;               { psapi stays available: it is a fallback }
    Exit;
  end;
  {$ENDIF}
  if Proc = nil then
  begin
    if not Slot.Tried then
    begin
      Len := GetSystemDirectory(Path, MAX_PATH);
      if (Len > 0) and (Len < MAX_PATH) then
      begin
        lstrcat(Path, '\');
        lstrcat(Path, Slot.Name);
        Slot.Handle := LoadLibrary(Path);
      end;
      if Slot.Handle = 0 then
        Slot.Handle := GetModuleHandle(Slot.Name);
      Slot.Tried := True;
    end;
    if Slot.Handle <> 0 then
      Proc := GetProcAddress(Slot.Handle, Name);
  end;
  Result := Proc <> nil;
end;

function GetKernel32Proc(var Proc: Pointer; Name: PChar): Boolean;
begin
  Result := GetSlotProc(Kernel32Slot, Proc, Name);
end;

function GetUser32Proc(var Proc: Pointer; Name: PChar): Boolean;
begin
  Result := GetSlotProc(User32Slot, Proc, Name);
end;

function NotImplemented: BOOL;
begin
  SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
  Result := False;
end;

{ Delphi passes True as -1 in a BOOL; some Windows functions only accept
  TRUE (1) - CompareStringOrdinal fails with -1. BOOL arguments are passed
  to Windows as 0 or 1. }
function BoolArg(Value: BOOL): Integer;
begin
  if Value then
    Result := 1
  else
    Result := 0;
end;

type
  TFnBool = function: BOOL; stdcall;
  TFnHwndBool = function(hWnd: HWND): BOOL; stdcall;
  TFnHandleBool = function(h: THandle): BOOL; stdcall;
  TFnDwordBool = function(dw: DWORD): BOOL; stdcall;
  TFnPtrBool = function(p: Pointer): BOOL; stdcall;
  TFnPtrPtrDwordByteBool = function(p1, p2: Pointer; dw: DWORD): ByteBool; stdcall;
  TFnHandlePtrDwordDword = function(h: THandle; p: Pointer; d1, d2: DWORD): DWORD; stdcall;
  TFnHandleDwordPtrVarBool = function(h: THandle; dw: DWORD; p: Pointer;
    var Size: DWORD): BOOL; stdcall;
  TFnDwordPtrDword = function(dw: DWORD; p: Pointer): DWORD; stdcall;
  TFnSRWLock = procedure(var SRWLock: TRTLSRWLock); stdcall;
  TFnSRWLockTry = function(var SRWLock: TRTLSRWLock): ByteBool; stdcall;
  TFnCondVar = procedure(var ConditionVariable: TRTLConditionVariable); stdcall;
  TFnSleepCS = function(var ConditionVariable: TRTLConditionVariable;
    var CriticalSection: TRTLCriticalSection; dwMilliseconds: DWORD): BOOL; stdcall;
  TFnSleepSRW = function(var ConditionVariable: TRTLConditionVariable;
    var SRWLock: TRTLSRWLock; dwMilliseconds: DWORD; Flags: ULONG): BOOL; stdcall;

{ ====== Version information ============================================== }

type
  TFnRtlGetVersion = function(var lpVersionInformation: TOSVersionInfoExW): NTSTATUS; stdcall;
  TFnVerifyVersionInfo = function(lpVersionInformation: Pointer; dwTypeMask: DWORD;
    dwlConditionMask: Int64): BOOL; stdcall;
  TFnVerSetConditionMask = function(ConditionMask: Int64; TypeMask: DWORD;
    Condition: Byte): Int64; stdcall;
  TFnGetProductInfo = function(dwOSMajorVersion, dwOSMinorVersion, dwSpMajorVersion,
    dwSpMinorVersion: DWORD; out pdwReturnedProductType: DWORD): BOOL; stdcall;

var
  RtlGetVersionProc: Pointer;
  VerifyVersionInfoAProc: Pointer;
  VerifyVersionInfoWProc: Pointer;
  VerSetConditionMaskProc: Pointer;
  GetProductInfoProc: Pointer;
  RealVersionKnown: Boolean;
  RealVersion: TOSVersionInfoExW;

function RtlGetVersion(var lpVersionInformation: TOSVersionInfoExW): NTSTATUS; stdcall;
begin
  if GetSlotProc(NtdllSlot, RtlGetVersionProc, 'RtlGetVersion') then
    Result := TFnRtlGetVersion(RtlGetVersionProc)(lpVersionInformation)
  else
    Result := NTSTATUS($C0000002);   { STATUS_NOT_IMPLEMENTED }
end;

{ Fills RealVersion once: RtlGetVersion, else GetVersionExA. }
function QueryRealVersion: Boolean;
var
  Info: TOSVersionInfoExW;
  InfoA: TOSVersionInfoExA;
begin
  if not RealVersionKnown then
  begin
    FillChar(Info, SizeOf(Info), 0);
    Info.dwOSVersionInfoSize := SizeOf(Info);
    if RtlGetVersion(Info) <> 0 then
    begin
      FillChar(Info, SizeOf(Info), 0);
      FillChar(InfoA, SizeOf(InfoA), 0);
      InfoA.dwOSVersionInfoSize := SizeOf(InfoA);
      if not GetVersionExA(POSVersionInfoA(@InfoA)^) then
      begin
        { Windows 9x / NT 4 before SP6: only the basic structure }
        InfoA.dwOSVersionInfoSize := SizeOf(TOSVersionInfoA);
        if not GetVersionExA(POSVersionInfoA(@InfoA)^) then
        begin
          Result := False;
          Exit;
        end;
        InfoA.wProductType := VER_NT_WORKSTATION;
      end;
      Info.dwOSVersionInfoSize := SizeOf(Info);
      Info.dwMajorVersion := InfoA.dwMajorVersion;
      Info.dwMinorVersion := InfoA.dwMinorVersion;
      Info.dwBuildNumber := InfoA.dwBuildNumber;
      Info.dwPlatformId := InfoA.dwPlatformId;
      MultiByteToWideChar(CP_ACP, 0, InfoA.szCSDVersion, -1, Info.szCSDVersion,
        Length(Info.szCSDVersion));
      Info.wServicePackMajor := InfoA.wServicePackMajor;
      Info.wServicePackMinor := InfoA.wServicePackMinor;
      Info.wSuiteMask := InfoA.wSuiteMask;
      Info.wProductType := InfoA.wProductType;
    end;
    RealVersion := Info;
    RealVersionKnown := True;
  end;
  Result := True;
end;

function GetRealWindowsVersion(out Major, Minor, Build: Cardinal): Boolean;
begin
  Result := QueryRealVersion;
  if Result then
  begin
    Major := RealVersion.dwMajorVersion;
    Minor := RealVersion.dwMinorVersion;
    Build := RealVersion.dwBuildNumber;
  end
  else
  begin
    Major := 0;
    Minor := 0;
    Build := 0;
  end;
end;

function VerifyVersionInfo(var lpVersionInformation: TOSVersionInfoEx;
  dwTypeMask: DWORD; dwlConditionMask: Int64): BOOL; stdcall;
begin
  Result := VerifyVersionInfoA(lpVersionInformation, dwTypeMask, dwlConditionMask);
end;

function VerifyVersionInfoA(var lpVersionInformation: TOSVersionInfoExA;
  dwTypeMask: DWORD; dwlConditionMask: Int64): BOOL; stdcall;
begin
  if GetKernel32Proc(VerifyVersionInfoAProc, 'VerifyVersionInfoA') then
    Result := TFnVerifyVersionInfo(VerifyVersionInfoAProc)(@lpVersionInformation,
      dwTypeMask, dwlConditionMask)
  else
    Result := NotImplemented;
end;

function VerifyVersionInfoW(var lpVersionInformation: TOSVersionInfoExW;
  dwTypeMask: DWORD; dwlConditionMask: Int64): BOOL; stdcall;
begin
  if GetKernel32Proc(VerifyVersionInfoWProc, 'VerifyVersionInfoW') then
    Result := TFnVerifyVersionInfo(VerifyVersionInfoWProc)(@lpVersionInformation,
      dwTypeMask, dwlConditionMask)
  else
    Result := NotImplemented;
end;

function VerSetConditionMask(ConditionMask: Int64; TypeMask: DWORD;
  Condition: Byte): Int64; stdcall;
var
  Index: Integer;
begin
  if GetKernel32Proc(VerSetConditionMaskProc, 'VerSetConditionMask') then
  begin
    Result := TFnVerSetConditionMask(VerSetConditionMaskProc)(ConditionMask, TypeMask,
      Condition);
    Exit;
  end;
  { Same results as ntdll (verified against Windows 11 for every type bit):
    TypeMask = 0 gives 0; otherwise the highest set type bit selects the
    3-bit slot of the condition (slots beyond bit 63 are dropped) and bit 63
    marks the mask as set. }
  Result := 0;
  if TypeMask = 0 then
    Exit;
  Index := 31;
  while TypeMask and (DWORD(1) shl Index) = 0 do
    Dec(Index);
  Result := ConditionMask or (Int64(1) shl 63);
  if Index * VER_NUM_BITS_PER_CONDITION_MASK < 64 then
    Result := Result or (Int64(Condition and VER_CONDITION_MASK) shl
      (Index * VER_NUM_BITS_PER_CONDITION_MASK));
end;

function GetProductInfo(dwOSMajorVersion, dwOSMinorVersion, dwSpMajorVersion,
  dwSpMinorVersion: DWORD; out pdwReturnedProductType: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetProductInfoProc, 'GetProductInfo') then
    Result := TFnGetProductInfo(GetProductInfoProc)(dwOSMajorVersion, dwOSMinorVersion,
      dwSpMajorVersion, dwSpMinorVersion, pdwReturnedProductType)
  else
  begin
    pdwReturnedProductType := PRODUCT_UNDEFINED;
    Result := NotImplemented;
  end;
end;

function IsWindowsVersionOrGreater(wMajorVersion, wMinorVersion,
  wServicePackMajor: Word): Boolean;
begin
  Result := QueryRealVersion;
  if Result then
    if RealVersion.dwMajorVersion <> wMajorVersion then
      Result := RealVersion.dwMajorVersion > wMajorVersion
    else if RealVersion.dwMinorVersion <> wMinorVersion then
      Result := RealVersion.dwMinorVersion > wMinorVersion
    else
      Result := RealVersion.wServicePackMajor >= wServicePackMajor;
end;

function IsWindowsXPOrGreater: Boolean;
begin
  Result := IsWindowsVersionOrGreater(5, 1, 0);
end;

function IsWindowsXPSP1OrGreater: Boolean;
begin
  Result := IsWindowsVersionOrGreater(5, 1, 1);
end;

function IsWindowsXPSP2OrGreater: Boolean;
begin
  Result := IsWindowsVersionOrGreater(5, 1, 2);
end;

function IsWindowsXPSP3OrGreater: Boolean;
begin
  Result := IsWindowsVersionOrGreater(5, 1, 3);
end;

function IsWindowsVistaOrGreater: Boolean;
begin
  Result := IsWindowsVersionOrGreater(6, 0, 0);
end;

function IsWindowsVistaSP1OrGreater: Boolean;
begin
  Result := IsWindowsVersionOrGreater(6, 0, 1);
end;

function IsWindowsVistaSP2OrGreater: Boolean;
begin
  Result := IsWindowsVersionOrGreater(6, 0, 2);
end;

function IsWindows7OrGreater: Boolean;
begin
  Result := IsWindowsVersionOrGreater(6, 1, 0);
end;

function IsWindows7SP1OrGreater: Boolean;
begin
  Result := IsWindowsVersionOrGreater(6, 1, 1);
end;

function IsWindows8OrGreater: Boolean;
begin
  Result := IsWindowsVersionOrGreater(6, 2, 0);
end;

function IsWindows8Point1OrGreater: Boolean;
begin
  Result := IsWindowsVersionOrGreater(6, 3, 0);
end;

function IsWindowsThresholdOrGreater: Boolean;
begin
  Result := IsWindowsVersionOrGreater(10, 0, 0);
end;

function IsWindows10OrGreater: Boolean;
begin
  Result := IsWindowsVersionOrGreater(10, 0, 0);
end;

function IsWindows11OrGreater: Boolean;
begin
  Result := QueryRealVersion and ((RealVersion.dwMajorVersion > 10) or
    ((RealVersion.dwMajorVersion = 10) and (RealVersion.dwBuildNumber >= 22000)));
end;

function IsWindowsServer: Boolean;
begin
  Result := QueryRealVersion and (RealVersion.wProductType <> VER_NT_WORKSTATION);
end;

{ ====== System information =============================================== }

type
  TFnTickCount64 = function: Int64; stdcall;
  TFnSystemInfo = procedure(var lpSystemInfo: TSystemInfo); stdcall;
  TFnIsWow64Process = function(hProcess: THandle; var Wow64Process: BOOL): BOOL; stdcall;
  TFnFileTime = procedure(var lpSystemTimeAsFileTime: TFileTime); stdcall;

var
  GetTickCount64Proc: Pointer;
  GetNativeSystemInfoProc: Pointer;
  IsWow64ProcessProc: Pointer;
  GetSystemTimePreciseAsFileTimeProc: Pointer;
  TickLock: Integer;
  TickLast: DWORD;
  TickHigh: DWORD;

function GetTickCount64: Int64; stdcall;
var
  Ticks: DWORD;
begin
  if GetKernel32Proc(GetTickCount64Proc, 'GetTickCount64') then
  begin
    Result := TFnTickCount64(GetTickCount64Proc)();
    Exit;
  end;
  while InterlockedExchange(TickLock, 1) <> 0 do
    Sleep(0);
  Ticks := GetTickCount;
  if Ticks < TickLast then
    Inc(TickHigh);                     { 32-bit counter wrapped }
  TickLast := Ticks;
  Result := (Int64(TickHigh) shl 32) or Ticks;
  InterlockedExchange(TickLock, 0);
end;

procedure GetNativeSystemInfo(var lpSystemInfo: TSystemInfo); stdcall;
begin
  if GetKernel32Proc(GetNativeSystemInfoProc, 'GetNativeSystemInfo') then
    TFnSystemInfo(GetNativeSystemInfoProc)(lpSystemInfo)
  else
    GetSystemInfo(lpSystemInfo);
end;

function IsWow64Process(hProcess: THandle; var Wow64Process: BOOL): BOOL; stdcall;
begin
  if GetKernel32Proc(IsWow64ProcessProc, 'IsWow64Process') then
    Result := TFnIsWow64Process(IsWow64ProcessProc)(hProcess, Wow64Process)
  else
  begin
    Wow64Process := False;
    Result := True;
  end;
end;

procedure GetSystemTimePreciseAsFileTime(var lpSystemTimeAsFileTime: TFileTime); stdcall;
begin
  if GetKernel32Proc(GetSystemTimePreciseAsFileTimeProc, 'GetSystemTimePreciseAsFileTime') then
    TFnFileTime(GetSystemTimePreciseAsFileTimeProc)(lpSystemTimeAsFileTime)
  else
    GetSystemTimeAsFileTime(lpSystemTimeAsFileTime);
end;

{ ====== Processes and files ============================================== }

var
  QueryFullProcessImageNameAProc: Pointer;
  QueryFullProcessImageNameWProc: Pointer;
  GetModuleFileNameExAProc: Pointer;
  GetModuleFileNameExWProc: Pointer;
  GetProcessImageFileNameAProc: Pointer;
  GetProcessImageFileNameWProc: Pointer;
  GetFinalPathNameByHandleAProc: Pointer;
  GetFinalPathNameByHandleWProc: Pointer;
  CreateSymbolicLinkAProc: Pointer;
  CreateSymbolicLinkWProc: Pointer;

type
  TFnGetModuleFileNameEx = function(hProcess: THandle; hModule: HMODULE; lpFilename: Pointer;
    nSize: DWORD): DWORD; stdcall;
  TFnGetProcessImageFileName = function(hProcess: THandle; lpImageFileName: Pointer;
    nSize: DWORD): DWORD; stdcall;

{ psapi fallback of QueryFullProcessImageNameA/W. psapi silently truncates a
  name that does not fit, so the name is read into a buffer of the maximum
  path length first; like QueryFullProcessImageName, a too small lpExeName
  gives ERROR_INSUFFICIENT_BUFFER. }
function QueryImageNamePsapi(hProcess: THandle; dwFlags: DWORD; lpExeName: Pointer;
  var lpdwSize: DWORD; Wide: Boolean): BOOL;
const
  MaxChars = 32768;
var
  Len, CharSize, Error: DWORD;
  Found: Boolean;
  Temp: Pointer;
begin
  if dwFlags and PROCESS_NAME_NATIVE <> 0 then
  begin
    if Wide then
      Found := GetSlotProc(PsapiSlot, GetProcessImageFileNameWProc, 'GetProcessImageFileNameW')
    else
      Found := GetSlotProc(PsapiSlot, GetProcessImageFileNameAProc, 'GetProcessImageFileNameA');
  end
  else
  begin
    if Wide then
      Found := GetSlotProc(PsapiSlot, GetModuleFileNameExWProc, 'GetModuleFileNameExW')
    else
      Found := GetSlotProc(PsapiSlot, GetModuleFileNameExAProc, 'GetModuleFileNameExA');
  end;
  if not Found then
  begin
    Result := NotImplemented;
    Exit;
  end;
  if Wide then
    CharSize := SizeOf(WideChar)
  else
    CharSize := SizeOf(AnsiChar);
  GetMem(Temp, MaxChars * CharSize);
  if dwFlags and PROCESS_NAME_NATIVE <> 0 then
    if Wide then
      Len := TFnGetProcessImageFileName(GetProcessImageFileNameWProc)(hProcess, Temp, MaxChars)
    else
      Len := TFnGetProcessImageFileName(GetProcessImageFileNameAProc)(hProcess, Temp, MaxChars)
  else
    if Wide then
      Len := TFnGetModuleFileNameEx(GetModuleFileNameExWProc)(hProcess, 0, Temp, MaxChars)
    else
      Len := TFnGetModuleFileNameEx(GetModuleFileNameExAProc)(hProcess, 0, Temp, MaxChars);
  Error := GetLastError;
  Result := False;
  if Len = 0 then
    { keep the error of psapi }
  else if Len >= lpdwSize then
    Error := ERROR_INSUFFICIENT_BUFFER
  else
  begin
    Move(Temp^, lpExeName^, (Len + 1) * CharSize);
    lpdwSize := Len;
    Result := True;
  end;
  FreeMem(Temp);
  if not Result then
    SetLastError(Error);
end;

function QueryFullProcessImageName(hProcess: THandle; dwFlags: DWORD; lpExeName: PChar;
  var lpdwSize: DWORD): BOOL; stdcall;
begin
  Result := QueryFullProcessImageNameA(hProcess, dwFlags, lpExeName, lpdwSize);
end;

function QueryFullProcessImageNameA(hProcess: THandle; dwFlags: DWORD; lpExeName: PAnsiChar;
  var lpdwSize: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(QueryFullProcessImageNameAProc, 'QueryFullProcessImageNameA') then
    Result := TFnHandleDwordPtrVarBool(QueryFullProcessImageNameAProc)(hProcess, dwFlags,
      lpExeName, lpdwSize)
  else
    Result := QueryImageNamePsapi(hProcess, dwFlags, lpExeName, lpdwSize, False);
end;

function QueryFullProcessImageNameW(hProcess: THandle; dwFlags: DWORD; lpExeName: PWideChar;
  var lpdwSize: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(QueryFullProcessImageNameWProc, 'QueryFullProcessImageNameW') then
    Result := TFnHandleDwordPtrVarBool(QueryFullProcessImageNameWProc)(hProcess, dwFlags,
      lpExeName, lpdwSize)
  else
    Result := QueryImageNamePsapi(hProcess, dwFlags, lpExeName, lpdwSize, True);
end;

function GetFinalPathNameByHandle(hFile: THandle; lpszFilePath: PChar;
  cchFilePath: DWORD; dwFlags: DWORD): DWORD; stdcall;
begin
  Result := GetFinalPathNameByHandleA(hFile, lpszFilePath, cchFilePath, dwFlags);
end;

function GetFinalPathNameByHandleA(hFile: THandle; lpszFilePath: PAnsiChar;
  cchFilePath: DWORD; dwFlags: DWORD): DWORD; stdcall;
begin
  if GetKernel32Proc(GetFinalPathNameByHandleAProc, 'GetFinalPathNameByHandleA') then
    Result := TFnHandlePtrDwordDword(GetFinalPathNameByHandleAProc)(hFile, lpszFilePath,
      cchFilePath, dwFlags)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := 0;
  end;
end;

function GetFinalPathNameByHandleW(hFile: THandle; lpszFilePath: PWideChar;
  cchFilePath: DWORD; dwFlags: DWORD): DWORD; stdcall;
begin
  if GetKernel32Proc(GetFinalPathNameByHandleWProc, 'GetFinalPathNameByHandleW') then
    Result := TFnHandlePtrDwordDword(GetFinalPathNameByHandleWProc)(hFile, lpszFilePath,
      cchFilePath, dwFlags)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := 0;
  end;
end;

function CreateSymbolicLink(lpSymlinkFileName, lpTargetFileName: PChar;
  dwFlags: DWORD): ByteBool; stdcall;
begin
  Result := CreateSymbolicLinkA(lpSymlinkFileName, lpTargetFileName, dwFlags);
end;

function CreateSymbolicLinkA(lpSymlinkFileName, lpTargetFileName: PAnsiChar;
  dwFlags: DWORD): ByteBool; stdcall;
begin
  if GetKernel32Proc(CreateSymbolicLinkAProc, 'CreateSymbolicLinkA') then
    Result := TFnPtrPtrDwordByteBool(CreateSymbolicLinkAProc)(lpSymlinkFileName,
      lpTargetFileName, dwFlags)
  else
    Result := NotImplemented;
end;

function CreateSymbolicLinkW(lpSymlinkFileName, lpTargetFileName: PWideChar;
  dwFlags: DWORD): ByteBool; stdcall;
begin
  if GetKernel32Proc(CreateSymbolicLinkWProc, 'CreateSymbolicLinkW') then
    Result := TFnPtrPtrDwordByteBool(CreateSymbolicLinkWProc)(lpSymlinkFileName,
      lpTargetFileName, dwFlags)
  else
    Result := NotImplemented;
end;

{ ====== SRW locks and condition variables ================================= }

var
  SRWMode: Integer;                    { 0 = not decided, 1 = native, 2 = emulated }
  InitializeSRWLockProc: Pointer;
  AcquireSRWLockExclusiveProc: Pointer;
  AcquireSRWLockSharedProc: Pointer;
  ReleaseSRWLockExclusiveProc: Pointer;
  ReleaseSRWLockSharedProc: Pointer;
  TryAcquireSRWLockExclusiveProc: Pointer;
  TryAcquireSRWLockSharedProc: Pointer;
  InitializeConditionVariableProc: Pointer;
  SleepConditionVariableCSProc: Pointer;
  SleepConditionVariableSRWProc: Pointer;
  WakeConditionVariableProc: Pointer;
  WakeAllConditionVariableProc: Pointer;

{ All SRW lock and condition variable functions are used natively or all are
  emulated (they all exist since Windows Vista), decided once. }
function NativeSRW: Boolean;
begin
  if SRWMode = 0 then
  begin
    if GetKernel32Proc(InitializeSRWLockProc, 'InitializeSRWLock') and
      GetKernel32Proc(AcquireSRWLockExclusiveProc, 'AcquireSRWLockExclusive') and
      GetKernel32Proc(AcquireSRWLockSharedProc, 'AcquireSRWLockShared') and
      GetKernel32Proc(ReleaseSRWLockExclusiveProc, 'ReleaseSRWLockExclusive') and
      GetKernel32Proc(ReleaseSRWLockSharedProc, 'ReleaseSRWLockShared') and
      GetKernel32Proc(InitializeConditionVariableProc, 'InitializeConditionVariable') and
      GetKernel32Proc(SleepConditionVariableCSProc, 'SleepConditionVariableCS') and
      GetKernel32Proc(SleepConditionVariableSRWProc, 'SleepConditionVariableSRW') and
      GetKernel32Proc(WakeConditionVariableProc, 'WakeConditionVariable') and
      GetKernel32Proc(WakeAllConditionVariableProc, 'WakeAllConditionVariable') then
      SRWMode := 1
    else
      SRWMode := 2;
  end;
  Result := SRWMode = 1;
end;

{ Emulated lock word: 0 = free, -1 = owned exclusively, n > 0 = n shared owners. }

procedure SRWBackOff(var Spins: Integer);
begin
  Inc(Spins);
  if Spins < 16 then
    Sleep(0)
  else
    Sleep(1);
end;

function SRWEmuTryExclusive(var SRWLock: TRTLSRWLock): Boolean;
begin
  Result := InterlockedCompareExchange(SRWLock.Ptr, Pointer(-1), nil) = nil;
end;

function SRWEmuTryShared(var SRWLock: TRTLSRWLock): Boolean;
var
  Current: Integer;
begin
  Current := Integer(SRWLock.Ptr);
  Result := (Current >= 0) and (InterlockedCompareExchange(SRWLock.Ptr,
    Pointer(Current + 1), Pointer(Current)) = Pointer(Current));
end;

procedure InitializeSRWLock(var SRWLock: TRTLSRWLock); stdcall;
begin
  if NativeSRW then
    TFnSRWLock(InitializeSRWLockProc)(SRWLock)
  else
    SRWLock.Ptr := nil;
end;

procedure AcquireSRWLockExclusive(var SRWLock: TRTLSRWLock); stdcall;
var
  Spins: Integer;
begin
  if NativeSRW then
    TFnSRWLock(AcquireSRWLockExclusiveProc)(SRWLock)
  else
  begin
    Spins := 0;
    while not SRWEmuTryExclusive(SRWLock) do
      SRWBackOff(Spins);
  end;
end;

procedure AcquireSRWLockShared(var SRWLock: TRTLSRWLock); stdcall;
var
  Spins: Integer;
begin
  if NativeSRW then
    TFnSRWLock(AcquireSRWLockSharedProc)(SRWLock)
  else
  begin
    Spins := 0;
    while not SRWEmuTryShared(SRWLock) do
      SRWBackOff(Spins);
  end;
end;

procedure ReleaseSRWLockExclusive(var SRWLock: TRTLSRWLock); stdcall;
begin
  if NativeSRW then
    TFnSRWLock(ReleaseSRWLockExclusiveProc)(SRWLock)
  else
    InterlockedExchange(Integer(SRWLock.Ptr), 0);
end;

procedure ReleaseSRWLockShared(var SRWLock: TRTLSRWLock); stdcall;
begin
  if NativeSRW then
    TFnSRWLock(ReleaseSRWLockSharedProc)(SRWLock)
  else
    InterlockedDecrement(Integer(SRWLock.Ptr));
end;

function TryAcquireSRWLockExclusive(var SRWLock: TRTLSRWLock): ByteBool; stdcall;
begin
  if not NativeSRW then
    Result := SRWEmuTryExclusive(SRWLock)
  else if GetKernel32Proc(TryAcquireSRWLockExclusiveProc, 'TryAcquireSRWLockExclusive') then
    Result := TFnSRWLockTry(TryAcquireSRWLockExclusiveProc)(SRWLock)
  else
    Result := NotImplemented;
end;

function TryAcquireSRWLockShared(var SRWLock: TRTLSRWLock): ByteBool; stdcall;
begin
  if not NativeSRW then
    Result := SRWEmuTryShared(SRWLock)
  else if GetKernel32Proc(TryAcquireSRWLockSharedProc, 'TryAcquireSRWLockShared') then
    Result := TFnSRWLockTry(TryAcquireSRWLockSharedProc)(SRWLock)
  else
    Result := NotImplemented;
end;

{ Emulated condition variable: Ptr is a wake generation counter. A waiter
  samples it while it still holds the lock, so a wake that happens after the
  lock is released is always seen. }
function CondVarEmuWait(var ConditionVariable: TRTLConditionVariable; Generation: Integer;
  dwMilliseconds: DWORD): BOOL;
var
  Start: DWORD;
begin
  Start := GetTickCount;
  repeat
    if Integer(ConditionVariable.Ptr) <> Generation then
    begin
      Result := True;
      Exit;
    end;
    if (dwMilliseconds <> INFINITE) and (GetTickCount - Start >= dwMilliseconds) then
    begin
      SetLastError(ERROR_TIMEOUT);
      Result := False;
      Exit;
    end;
    if dwMilliseconds = 0 then
      Sleep(0)
    else
      Sleep(1);
  until False;
end;

procedure InitializeConditionVariable(var ConditionVariable: TRTLConditionVariable); stdcall;
begin
  if NativeSRW then
    TFnCondVar(InitializeConditionVariableProc)(ConditionVariable)
  else
    ConditionVariable.Ptr := nil;
end;

function SleepConditionVariableCS(var ConditionVariable: TRTLConditionVariable;
  var CriticalSection: TRTLCriticalSection; dwMilliseconds: DWORD): BOOL; stdcall;
var
  Generation: Integer;
  LastError: DWORD;
begin
  if NativeSRW then
    Result := TFnSleepCS(SleepConditionVariableCSProc)(ConditionVariable, CriticalSection,
      dwMilliseconds)
  else
  begin
    Generation := Integer(ConditionVariable.Ptr);
    LeaveCriticalSection(CriticalSection);
    Result := CondVarEmuWait(ConditionVariable, Generation, dwMilliseconds);
    LastError := GetLastError;
    EnterCriticalSection(CriticalSection);
    SetLastError(LastError);
  end;
end;

function SleepConditionVariableSRW(var ConditionVariable: TRTLConditionVariable;
  var SRWLock: TRTLSRWLock; dwMilliseconds: DWORD; Flags: ULONG): BOOL; stdcall;
var
  Generation: Integer;
  LastError: DWORD;
begin
  if NativeSRW then
    Result := TFnSleepSRW(SleepConditionVariableSRWProc)(ConditionVariable, SRWLock,
      dwMilliseconds, Flags)
  else
  begin
    Generation := Integer(ConditionVariable.Ptr);
    if Flags and CONDITION_VARIABLE_LOCKMODE_SHARED <> 0 then
      ReleaseSRWLockShared(SRWLock)
    else
      ReleaseSRWLockExclusive(SRWLock);
    Result := CondVarEmuWait(ConditionVariable, Generation, dwMilliseconds);
    LastError := GetLastError;
    if Flags and CONDITION_VARIABLE_LOCKMODE_SHARED <> 0 then
      AcquireSRWLockShared(SRWLock)
    else
      AcquireSRWLockExclusive(SRWLock);
    SetLastError(LastError);
  end;
end;

procedure WakeConditionVariable(var ConditionVariable: TRTLConditionVariable); stdcall;
begin
  if NativeSRW then
    TFnCondVar(WakeConditionVariableProc)(ConditionVariable)
  else
    InterlockedIncrement(Integer(ConditionVariable.Ptr));  { wakes all: allowed }
end;

procedure WakeAllConditionVariable(var ConditionVariable: TRTLConditionVariable); stdcall;
begin
  if NativeSRW then
    TFnCondVar(WakeAllConditionVariableProc)(ConditionVariable)
  else
    InterlockedIncrement(Integer(ConditionVariable.Ptr));
end;

{ ====== DLL search path, DEP, heap ======================================== }

type
  TFnAddDllDirectory = function(NewDirectory: PWideChar): DLL_DIRECTORY_COOKIE; stdcall;
  TFnGetProcessDEPPolicy = function(hProcess: THandle; out lpFlags: DWORD;
    out lpPermanent: BOOL): BOOL; stdcall;
  TFnHeapSetInformation = function(HeapHandle: THandle; HeapInformationClass: Integer;
    HeapInformation: Pointer; HeapInformationLength: Cardinal): BOOL; stdcall;

var
  SetDefaultDllDirectoriesProc: Pointer;
  AddDllDirectoryProc: Pointer;
  RemoveDllDirectoryProc: Pointer;
  SetDllDirectoryAProc: Pointer;
  SetDllDirectoryWProc: Pointer;
  GetDllDirectoryAProc: Pointer;
  GetDllDirectoryWProc: Pointer;
  SetSearchPathModeProc: Pointer;
  SetProcessDEPPolicyProc: Pointer;
  GetProcessDEPPolicyProc: Pointer;
  HeapSetInformationProc: Pointer;

function SetDefaultDllDirectories(DirectoryFlags: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(SetDefaultDllDirectoriesProc, 'SetDefaultDllDirectories') then
    Result := TFnDwordBool(SetDefaultDllDirectoriesProc)(DirectoryFlags)
  else
    Result := NotImplemented;
end;

function AddDllDirectory(NewDirectory: PWideChar): DLL_DIRECTORY_COOKIE; stdcall;
begin
  if GetKernel32Proc(AddDllDirectoryProc, 'AddDllDirectory') then
    Result := TFnAddDllDirectory(AddDllDirectoryProc)(NewDirectory)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := nil;
  end;
end;

function RemoveDllDirectory(Cookie: DLL_DIRECTORY_COOKIE): BOOL; stdcall;
begin
  if GetKernel32Proc(RemoveDllDirectoryProc, 'RemoveDllDirectory') then
    Result := TFnPtrBool(RemoveDllDirectoryProc)(Cookie)
  else
    Result := NotImplemented;
end;

function SetDllDirectory(lpPathName: PChar): BOOL; stdcall;
begin
  Result := SetDllDirectoryA(lpPathName);
end;

function SetDllDirectoryA(lpPathName: PAnsiChar): BOOL; stdcall;
begin
  if GetKernel32Proc(SetDllDirectoryAProc, 'SetDllDirectoryA') then
    Result := TFnPtrBool(SetDllDirectoryAProc)(lpPathName)
  else
    Result := NotImplemented;
end;

function SetDllDirectoryW(lpPathName: PWideChar): BOOL; stdcall;
begin
  if GetKernel32Proc(SetDllDirectoryWProc, 'SetDllDirectoryW') then
    Result := TFnPtrBool(SetDllDirectoryWProc)(lpPathName)
  else
    Result := NotImplemented;
end;

function GetDllDirectory(nBufferLength: DWORD; lpBuffer: PChar): DWORD; stdcall;
begin
  Result := GetDllDirectoryA(nBufferLength, lpBuffer);
end;

function GetDllDirectoryA(nBufferLength: DWORD; lpBuffer: PAnsiChar): DWORD; stdcall;
begin
  if GetKernel32Proc(GetDllDirectoryAProc, 'GetDllDirectoryA') then
    Result := TFnDwordPtrDword(GetDllDirectoryAProc)(nBufferLength, lpBuffer)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := 0;
  end;
end;

function GetDllDirectoryW(nBufferLength: DWORD; lpBuffer: PWideChar): DWORD; stdcall;
begin
  if GetKernel32Proc(GetDllDirectoryWProc, 'GetDllDirectoryW') then
    Result := TFnDwordPtrDword(GetDllDirectoryWProc)(nBufferLength, lpBuffer)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := 0;
  end;
end;

function SetSearchPathMode(Flags: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(SetSearchPathModeProc, 'SetSearchPathMode') then
    Result := TFnDwordBool(SetSearchPathModeProc)(Flags)
  else
    Result := NotImplemented;
end;

function SetProcessDEPPolicy(dwFlags: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(SetProcessDEPPolicyProc, 'SetProcessDEPPolicy') then
    Result := TFnDwordBool(SetProcessDEPPolicyProc)(dwFlags)
  else
    Result := NotImplemented;
end;

function GetProcessDEPPolicy(hProcess: THandle; out lpFlags: DWORD;
  out lpPermanent: BOOL): BOOL; stdcall;
begin
  if GetKernel32Proc(GetProcessDEPPolicyProc, 'GetProcessDEPPolicy') then
    Result := TFnGetProcessDEPPolicy(GetProcessDEPPolicyProc)(hProcess, lpFlags, lpPermanent)
  else
  begin
    lpFlags := 0;
    lpPermanent := False;
    Result := NotImplemented;
  end;
end;

function HeapSetInformation(HeapHandle: THandle; HeapInformationClass: HEAP_INFORMATION_CLASS;
  HeapInformation: Pointer; HeapInformationLength: Cardinal): BOOL; stdcall;
begin
  if GetKernel32Proc(HeapSetInformationProc, 'HeapSetInformation') then
    Result := TFnHeapSetInformation(HeapSetInformationProc)(HeapHandle, HeapInformationClass,
      HeapInformation, HeapInformationLength)
  else
    Result := NotImplemented;
end;

{ ====== Locale names ====================================================== }

type
  TFnGetUserDefaultLocaleName = function(lpLocaleName: PWideChar;
    cchLocaleName: Integer): Integer; stdcall;
  TFnLocaleNameToLCID = function(lpName: PWideChar; dwFlags: DWORD): LCID; stdcall;
  TFnLCIDToLocaleName = function(Locale: LCID; lpName: PWideChar; cchName: Integer;
    dwFlags: DWORD): Integer; stdcall;
  TFnGetLocaleInfoEx = function(lpLocaleName: PWideChar; LCType: LCTYPE; lpLCData: PWideChar;
    cchData: Integer): Integer; stdcall;
  TFnCompareStringEx = function(lpLocaleName: PWideChar; dwCmpFlags: DWORD;
    lpString1: PWideChar; cchCount1: Integer; lpString2: PWideChar; cchCount2: Integer;
    lpVersionInformation: Pointer; lpReserved: Pointer; lParam: LPARAM): Integer; stdcall;
  TFnCompareStringOrdinal = function(lpString1: PWideChar; cchCount1: Integer;
    lpString2: PWideChar; cchCount2: Integer; bIgnoreCase: Integer): Integer; stdcall;

var
  GetUserDefaultLocaleNameProc: Pointer;
  LocaleNameToLCIDProc: Pointer;
  LCIDToLocaleNameProc: Pointer;
  GetLocaleInfoExProc: Pointer;
  CompareStringExProc: Pointer;
  CompareStringOrdinalProc: Pointer;

function GetUserDefaultLocaleName(lpLocaleName: PWideChar; cchLocaleName: Integer): Integer; stdcall;
begin
  if GetKernel32Proc(GetUserDefaultLocaleNameProc, 'GetUserDefaultLocaleName') then
    Result := TFnGetUserDefaultLocaleName(GetUserDefaultLocaleNameProc)(lpLocaleName,
      cchLocaleName)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := 0;
  end;
end;

function LocaleNameToLCID(lpName: PWideChar; dwFlags: DWORD): LCID; stdcall;
begin
  if GetKernel32Proc(LocaleNameToLCIDProc, 'LocaleNameToLCID') then
    Result := TFnLocaleNameToLCID(LocaleNameToLCIDProc)(lpName, dwFlags)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := 0;
  end;
end;

function LCIDToLocaleName(Locale: LCID; lpName: PWideChar; cchName: Integer;
  dwFlags: DWORD): Integer; stdcall;
begin
  if GetKernel32Proc(LCIDToLocaleNameProc, 'LCIDToLocaleName') then
    Result := TFnLCIDToLocaleName(LCIDToLocaleNameProc)(Locale, lpName, cchName, dwFlags)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := 0;
  end;
end;

function GetLocaleInfoEx(lpLocaleName: PWideChar; LCType: LCTYPE; lpLCData: PWideChar;
  cchData: Integer): Integer; stdcall;
begin
  if GetKernel32Proc(GetLocaleInfoExProc, 'GetLocaleInfoEx') then
    Result := TFnGetLocaleInfoEx(GetLocaleInfoExProc)(lpLocaleName, LCType, lpLCData, cchData)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := 0;
  end;
end;

function CompareStringEx(lpLocaleName: PWideChar; dwCmpFlags: DWORD; lpString1: PWideChar;
  cchCount1: Integer; lpString2: PWideChar; cchCount2: Integer;
  lpVersionInformation: Pointer; lpReserved: Pointer; lParam: LPARAM): Integer; stdcall;
begin
  if GetKernel32Proc(CompareStringExProc, 'CompareStringEx') then
    Result := TFnCompareStringEx(CompareStringExProc)(lpLocaleName, dwCmpFlags, lpString1,
      cchCount1, lpString2, cchCount2, lpVersionInformation, lpReserved, lParam)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := 0;
  end;
end;

{ Upper case through the system table, locale independent. }
function OrdinalUpCase(C: WideChar): Word;
var
  Source, Dest: WideChar;
begin
  Source := C;
  Dest := C;
  if LCMapStringW($007F { LOCALE_INVARIANT }, LCMAP_UPPERCASE, @Source, 1, @Dest, 1) = 0 then
    LCMapStringW(LOCALE_SYSTEM_DEFAULT, LCMAP_UPPERCASE, @Source, 1, @Dest, 1);
  Result := Word(Dest);
end;

function CompareStringOrdinal(lpString1: PWideChar; cchCount1: Integer; lpString2: PWideChar;
  cchCount2: Integer; bIgnoreCase: BOOL): Integer; stdcall;
var
  I, Count: Integer;
  C1, C2: Word;
begin
  if GetKernel32Proc(CompareStringOrdinalProc, 'CompareStringOrdinal') then
  begin
    Result := TFnCompareStringOrdinal(CompareStringOrdinalProc)(lpString1, cchCount1,
      lpString2, cchCount2, BoolArg(bIgnoreCase));
    Exit;
  end;
  if (lpString1 = nil) or (lpString2 = nil) then
  begin
    SetLastError(ERROR_INVALID_PARAMETER);
    Result := 0;
    Exit;
  end;
  if cchCount1 < 0 then
    cchCount1 := lstrlenW(lpString1);
  if cchCount2 < 0 then
    cchCount2 := lstrlenW(lpString2);
  Count := cchCount1;
  if cchCount2 < Count then
    Count := cchCount2;
  for I := 0 to Count - 1 do
  begin
    C1 := Word(lpString1[I]);
    C2 := Word(lpString2[I]);
    if (C1 <> C2) and bIgnoreCase then
    begin
      C1 := OrdinalUpCase(WideChar(C1));
      C2 := OrdinalUpCase(WideChar(C2));
    end;
    if C1 <> C2 then
    begin
      if C1 < C2 then
        Result := CSTR_LESS_THAN
      else
        Result := CSTR_GREATER_THAN;
      Exit;
    end;
  end;
  if cchCount1 < cchCount2 then
    Result := CSTR_LESS_THAN
  else if cchCount1 > cchCount2 then
    Result := CSTR_GREATER_THAN
  else
    Result := CSTR_EQUAL;
end;

{ ====== Window helpers ==================================================== }

type
  TFnChangeWindowMessageFilter = function(message: UINT; dwFlag: DWORD): BOOL; stdcall;
  TFnChangeWindowMessageFilterEx = function(hwnd: HWND; message: UINT; action: DWORD;
    pChangeFilterStruct: PCHANGEFILTERSTRUCT): BOOL; stdcall;
  TFnHwndPtrBool = function(hWnd: HWND; p: Pointer): BOOL; stdcall;
  TFnShutdownBlockReasonQuery = function(hWnd: HWND; pwszBuff: PWideChar;
    var pcchBuff: DWORD): BOOL; stdcall;
  TFnHwndDwordBool = function(hWnd: HWND; dw: DWORD): BOOL; stdcall;
  TFnGetWindowDisplayAffinity = function(hWnd: HWND; out pdwAffinity: DWORD): BOOL; stdcall;
  TFnCalculatePopupWindowPosition = function(anchorPoint: PPoint; windowSize: PSize;
    flags: UINT; excludeRect: PRect; out popupWindowPosition: TRect): BOOL; stdcall;

var
  ChangeWindowMessageFilterProc: Pointer;
  ChangeWindowMessageFilterExProc: Pointer;
  ShutdownBlockReasonCreateProc: Pointer;
  ShutdownBlockReasonQueryProc: Pointer;
  ShutdownBlockReasonDestroyProc: Pointer;
  AddClipboardFormatListenerProc: Pointer;
  RemoveClipboardFormatListenerProc: Pointer;
  SetWindowDisplayAffinityProc: Pointer;
  GetWindowDisplayAffinityProc: Pointer;
  CalculatePopupWindowPositionProc: Pointer;

function ChangeWindowMessageFilter(message: UINT; dwFlag: DWORD): BOOL; stdcall;
begin
  if GetUser32Proc(ChangeWindowMessageFilterProc, 'ChangeWindowMessageFilter') then
    Result := TFnChangeWindowMessageFilter(ChangeWindowMessageFilterProc)(message, dwFlag)
  else
    Result := True;                    { no UIPI before Windows Vista }
end;

function ChangeWindowMessageFilterEx(hwnd: HWND; message: UINT; action: DWORD;
  pChangeFilterStruct: PCHANGEFILTERSTRUCT): BOOL; stdcall;
begin
  if GetUser32Proc(ChangeWindowMessageFilterExProc, 'ChangeWindowMessageFilterEx') then
  begin
    Result := TFnChangeWindowMessageFilterEx(ChangeWindowMessageFilterExProc)(hwnd, message,
      action, pChangeFilterStruct);
    Exit;
  end;
  if pChangeFilterStruct <> nil then
    pChangeFilterStruct^.ExtStatus := MSGFLTINFO_NONE;
  if GetUser32Proc(ChangeWindowMessageFilterProc, 'ChangeWindowMessageFilter') then
  begin
    { Windows Vista: only a process wide filter exists }
    case action of
      MSGFLT_ALLOW:
        Result := TFnChangeWindowMessageFilter(ChangeWindowMessageFilterProc)(message, MSGFLT_ADD);
      MSGFLT_DISALLOW:
        Result := TFnChangeWindowMessageFilter(ChangeWindowMessageFilterProc)(message, MSGFLT_REMOVE);
      MSGFLT_RESET:
        Result := True;
    else
      SetLastError(ERROR_INVALID_PARAMETER);
      Result := False;
    end;
  end
  else
    Result := True;                    { no UIPI before Windows Vista }
end;

function ShutdownBlockReasonCreate(hWnd: HWND; pwszReason: PWideChar): BOOL; stdcall;
begin
  if GetUser32Proc(ShutdownBlockReasonCreateProc, 'ShutdownBlockReasonCreate') then
    Result := TFnHwndPtrBool(ShutdownBlockReasonCreateProc)(hWnd, pwszReason)
  else
    Result := NotImplemented;
end;

function ShutdownBlockReasonQuery(hWnd: HWND; pwszBuff: PWideChar;
  var pcchBuff: DWORD): BOOL; stdcall;
begin
  if GetUser32Proc(ShutdownBlockReasonQueryProc, 'ShutdownBlockReasonQuery') then
    Result := TFnShutdownBlockReasonQuery(ShutdownBlockReasonQueryProc)(hWnd, pwszBuff,
      pcchBuff)
  else
    Result := NotImplemented;
end;

function ShutdownBlockReasonDestroy(hWnd: HWND): BOOL; stdcall;
begin
  if GetUser32Proc(ShutdownBlockReasonDestroyProc, 'ShutdownBlockReasonDestroy') then
    Result := TFnHwndBool(ShutdownBlockReasonDestroyProc)(hWnd)
  else
    Result := NotImplemented;
end;

function AddClipboardFormatListener(hwnd: HWND): BOOL; stdcall;
begin
  if GetUser32Proc(AddClipboardFormatListenerProc, 'AddClipboardFormatListener') then
    Result := TFnHwndBool(AddClipboardFormatListenerProc)(hwnd)
  else
    Result := NotImplemented;
end;

function RemoveClipboardFormatListener(hwnd: HWND): BOOL; stdcall;
begin
  if GetUser32Proc(RemoveClipboardFormatListenerProc, 'RemoveClipboardFormatListener') then
    Result := TFnHwndBool(RemoveClipboardFormatListenerProc)(hwnd)
  else
    Result := NotImplemented;
end;

function SetWindowDisplayAffinity(hWnd: HWND; dwAffinity: DWORD): BOOL; stdcall;
begin
  if GetUser32Proc(SetWindowDisplayAffinityProc, 'SetWindowDisplayAffinity') then
    Result := TFnHwndDwordBool(SetWindowDisplayAffinityProc)(hWnd, dwAffinity)
  else
    Result := NotImplemented;
end;

function GetWindowDisplayAffinity(hWnd: HWND; out pdwAffinity: DWORD): BOOL; stdcall;
begin
  if GetUser32Proc(GetWindowDisplayAffinityProc, 'GetWindowDisplayAffinity') then
    Result := TFnGetWindowDisplayAffinity(GetWindowDisplayAffinityProc)(hWnd, pdwAffinity)
  else
  begin
    pdwAffinity := WDA_NONE;
    Result := NotImplemented;
  end;
end;

function CalculatePopupWindowPosition(const anchorPoint: TPoint; const windowSize: TSize;
  flags: UINT; excludeRect: PRect; out popupWindowPosition: TRect): BOOL; stdcall;
begin
  if GetUser32Proc(CalculatePopupWindowPositionProc, 'CalculatePopupWindowPosition') then
    Result := TFnCalculatePopupWindowPosition(CalculatePopupWindowPositionProc)(@anchorPoint,
      @windowSize, flags, excludeRect, popupWindowPosition)
  else
    Result := NotImplemented;
end;

{ 32-bit Windows: the *LongPtr functions are the plain *Long exports }
function GetWindowLongPtr;  external user32 name 'GetWindowLongA';
function GetWindowLongPtrA; external user32 name 'GetWindowLongA';
function GetWindowLongPtrW; external user32 name 'GetWindowLongW';
function SetWindowLongPtr;  external user32 name 'SetWindowLongA';
function SetWindowLongPtrA; external user32 name 'SetWindowLongA';
function SetWindowLongPtrW; external user32 name 'SetWindowLongW';
function GetClassLongPtr;   external user32 name 'GetClassLongA';
function GetClassLongPtrA;  external user32 name 'GetClassLongA';
function GetClassLongPtrW;  external user32 name 'GetClassLongW';
function SetClassLongPtr;   external user32 name 'SetClassLongA';
function SetClassLongPtrA;  external user32 name 'SetClassLongA';
function SetClassLongPtrW;  external user32 name 'SetClassLongW';

{ ====== Touch input ======================================================= }

type
  TFnRegisterTouchWindow = function(hwnd: HWND; ulFlags: ULONG): BOOL; stdcall;
  TFnIsTouchWindow = function(hwnd: HWND; pulFlags: PULONG): BOOL; stdcall;
  TFnGetTouchInputInfo = function(hTouchInput: HTOUCHINPUT; cInputs: UINT;
    pInputs: PTOUCHINPUT; cbSize: Integer): BOOL; stdcall;

var
  RegisterTouchWindowProc: Pointer;
  UnregisterTouchWindowProc: Pointer;
  IsTouchWindowProc: Pointer;
  GetTouchInputInfoProc: Pointer;
  CloseTouchInputHandleProc: Pointer;

function RegisterTouchWindow(hwnd: HWND; ulFlags: ULONG): BOOL; stdcall;
begin
  if GetUser32Proc(RegisterTouchWindowProc, 'RegisterTouchWindow') then
    Result := TFnRegisterTouchWindow(RegisterTouchWindowProc)(hwnd, ulFlags)
  else
    Result := NotImplemented;
end;

function UnregisterTouchWindow(hwnd: HWND): BOOL; stdcall;
begin
  if GetUser32Proc(UnregisterTouchWindowProc, 'UnregisterTouchWindow') then
    Result := TFnHwndBool(UnregisterTouchWindowProc)(hwnd)
  else
    Result := NotImplemented;
end;

function IsTouchWindow(hwnd: HWND; pulFlags: PULONG): BOOL; stdcall;
begin
  if GetUser32Proc(IsTouchWindowProc, 'IsTouchWindow') then
    Result := TFnIsTouchWindow(IsTouchWindowProc)(hwnd, pulFlags)
  else
  begin
    if pulFlags <> nil then
      pulFlags^ := 0;
    Result := NotImplemented;
  end;
end;

function GetTouchInputInfo(hTouchInput: HTOUCHINPUT; cInputs: UINT; pInputs: PTOUCHINPUT;
  cbSize: Integer): BOOL; stdcall;
begin
  if GetUser32Proc(GetTouchInputInfoProc, 'GetTouchInputInfo') then
    Result := TFnGetTouchInputInfo(GetTouchInputInfoProc)(hTouchInput, cInputs, pInputs, cbSize)
  else
    Result := NotImplemented;
end;

function CloseTouchInputHandle(hTouchInput: HTOUCHINPUT): BOOL; stdcall;
begin
  if GetUser32Proc(CloseTouchInputHandleProc, 'CloseTouchInputHandle') then
    Result := TFnHandleBool(CloseTouchInputHandleProc)(hTouchInput)
  else
    Result := NotImplemented;
end;

function TOUCH_COORD_TO_PIXEL(l: Longint): Longint;
begin
  Result := l div 100;
end;

{ ====== Gestures ========================================================== }

type
  TFnGetGestureInfo = function(hGestureInfo: HGESTUREINFO;
    var pGestureInfo: TGestureInfo): BOOL; stdcall;
  TFnGetGestureExtraArgs = function(hGestureInfo: HGESTUREINFO; cbExtraArgs: UINT;
    pExtraArgs: PByte): BOOL; stdcall;
  TFnSetGestureConfig = function(hwnd: HWND; dwReserved: DWORD; cIDs: UINT;
    pGestureConfig: PGESTURECONFIG; cbSize: UINT): BOOL; stdcall;
  TFnGetGestureConfig = function(hwnd: HWND; dwReserved: DWORD; dwFlags: DWORD; pcIDs: PUINT;
    pGestureConfig: PGESTURECONFIG; cbSize: UINT): BOOL; stdcall;

var
  GetGestureInfoProc: Pointer;
  GetGestureExtraArgsProc: Pointer;
  CloseGestureInfoHandleProc: Pointer;
  SetGestureConfigProc: Pointer;
  GetGestureConfigProc: Pointer;

function GetGestureInfo(hGestureInfo: HGESTUREINFO; var pGestureInfo: TGestureInfo): BOOL; stdcall;
begin
  if GetUser32Proc(GetGestureInfoProc, 'GetGestureInfo') then
    Result := TFnGetGestureInfo(GetGestureInfoProc)(hGestureInfo, pGestureInfo)
  else
    Result := NotImplemented;
end;

function GetGestureExtraArgs(hGestureInfo: HGESTUREINFO; cbExtraArgs: UINT;
  pExtraArgs: PByte): BOOL; stdcall;
begin
  if GetUser32Proc(GetGestureExtraArgsProc, 'GetGestureExtraArgs') then
    Result := TFnGetGestureExtraArgs(GetGestureExtraArgsProc)(hGestureInfo, cbExtraArgs,
      pExtraArgs)
  else
    Result := NotImplemented;
end;

function CloseGestureInfoHandle(hGestureInfo: HGESTUREINFO): BOOL; stdcall;
begin
  if GetUser32Proc(CloseGestureInfoHandleProc, 'CloseGestureInfoHandle') then
    Result := TFnHandleBool(CloseGestureInfoHandleProc)(hGestureInfo)
  else
    Result := NotImplemented;
end;

function SetGestureConfig(hwnd: HWND; dwReserved: DWORD; cIDs: UINT;
  pGestureConfig: PGESTURECONFIG; cbSize: UINT): BOOL; stdcall;
begin
  if GetUser32Proc(SetGestureConfigProc, 'SetGestureConfig') then
    Result := TFnSetGestureConfig(SetGestureConfigProc)(hwnd, dwReserved, cIDs,
      pGestureConfig, cbSize)
  else
    Result := NotImplemented;
end;

function GetGestureConfig(hwnd: HWND; dwReserved: DWORD; dwFlags: DWORD; pcIDs: PUINT;
  pGestureConfig: PGESTURECONFIG; cbSize: UINT): BOOL; stdcall;
begin
  if GetUser32Proc(GetGestureConfigProc, 'GetGestureConfig') then
    Result := TFnGetGestureConfig(GetGestureConfigProc)(hwnd, dwReserved, dwFlags, pcIDs,
      pGestureConfig, cbSize)
  else
    Result := NotImplemented;
end;

function GID_ROTATE_ANGLE_TO_ARGUMENT(Angle: Double): Word;
begin
  Result := Word(Trunc(((Angle + 2.0 * 3.14159265) / (4.0 * 3.14159265)) * 65535.0));
end;

function GID_ROTATE_ANGLE_FROM_ARGUMENT(Argument: Word): Double;
begin
  Result := ((Argument / 65535.0) * 4.0 * 3.14159265) - 2.0 * 3.14159265;
end;

{ ====== Pointer input ===================================================== }

type
  TFnGetPointerType = function(pointerId: Cardinal;
    out pointerType: POINTER_INPUT_TYPE): BOOL; stdcall;
  TFnGetPointerStruct = function(pointerId: Cardinal; Info: Pointer): BOOL; stdcall;

var
  EnableMouseInPointerProc: Pointer;
  IsMouseInPointerEnabledProc: Pointer;
  GetPointerTypeProc: Pointer;
  GetPointerInfoProc: Pointer;
  GetPointerTouchInfoProc: Pointer;
  GetPointerPenInfoProc: Pointer;

function EnableMouseInPointer(fEnable: BOOL): BOOL; stdcall;
begin
  if GetUser32Proc(EnableMouseInPointerProc, 'EnableMouseInPointer') then
    Result := TFnDwordBool(EnableMouseInPointerProc)(BoolArg(fEnable))
  else
    Result := NotImplemented;
end;

function IsMouseInPointerEnabled: BOOL; stdcall;
begin
  if GetUser32Proc(IsMouseInPointerEnabledProc, 'IsMouseInPointerEnabled') then
    Result := TFnBool(IsMouseInPointerEnabledProc)()
  else
    Result := NotImplemented;
end;

function GetPointerType(pointerId: Cardinal; out pointerType: POINTER_INPUT_TYPE): BOOL; stdcall;
begin
  if GetUser32Proc(GetPointerTypeProc, 'GetPointerType') then
    Result := TFnGetPointerType(GetPointerTypeProc)(pointerId, pointerType)
  else
  begin
    pointerType := 0;
    Result := NotImplemented;
  end;
end;

function GetPointerInfo(pointerId: Cardinal; out pointerInfo: TPointerInfo): BOOL; stdcall;
begin
  if GetUser32Proc(GetPointerInfoProc, 'GetPointerInfo') then
    Result := TFnGetPointerStruct(GetPointerInfoProc)(pointerId, @pointerInfo)
  else
    Result := NotImplemented;
end;

function GetPointerTouchInfo(pointerId: Cardinal; out touchInfo: TPointerTouchInfo): BOOL; stdcall;
begin
  if GetUser32Proc(GetPointerTouchInfoProc, 'GetPointerTouchInfo') then
    Result := TFnGetPointerStruct(GetPointerTouchInfoProc)(pointerId, @touchInfo)
  else
    Result := NotImplemented;
end;

function GetPointerPenInfo(pointerId: Cardinal; out penInfo: TPointerPenInfo): BOOL; stdcall;
begin
  if GetUser32Proc(GetPointerPenInfoProc, 'GetPointerPenInfo') then
    Result := TFnGetPointerStruct(GetPointerPenInfoProc)(pointerId, @penInfo)
  else
    Result := NotImplemented;
end;

function GET_POINTERID_WPARAM(wParam: WPARAM): Word;
begin
  Result := LoWord(wParam);
end;

function IS_POINTER_FLAG_SET_WPARAM(wParam: WPARAM; Flag: DWORD): Boolean;
begin
  Result := (DWORD(HiWord(wParam)) and Flag) = Flag;
end;

function IS_POINTER_NEW_WPARAM(wParam: WPARAM): Boolean;
begin
  Result := IS_POINTER_FLAG_SET_WPARAM(wParam, POINTER_MESSAGE_FLAG_NEW);
end;

function IS_POINTER_INRANGE_WPARAM(wParam: WPARAM): Boolean;
begin
  Result := IS_POINTER_FLAG_SET_WPARAM(wParam, POINTER_MESSAGE_FLAG_INRANGE);
end;

function IS_POINTER_INCONTACT_WPARAM(wParam: WPARAM): Boolean;
begin
  Result := IS_POINTER_FLAG_SET_WPARAM(wParam, POINTER_MESSAGE_FLAG_INCONTACT);
end;

function IS_POINTER_FIRSTBUTTON_WPARAM(wParam: WPARAM): Boolean;
begin
  Result := IS_POINTER_FLAG_SET_WPARAM(wParam, POINTER_MESSAGE_FLAG_FIRSTBUTTON);
end;

function IS_POINTER_SECONDBUTTON_WPARAM(wParam: WPARAM): Boolean;
begin
  Result := IS_POINTER_FLAG_SET_WPARAM(wParam, POINTER_MESSAGE_FLAG_SECONDBUTTON);
end;

function IS_POINTER_THIRDBUTTON_WPARAM(wParam: WPARAM): Boolean;
begin
  Result := IS_POINTER_FLAG_SET_WPARAM(wParam, POINTER_MESSAGE_FLAG_THIRDBUTTON);
end;

function IS_POINTER_FOURTHBUTTON_WPARAM(wParam: WPARAM): Boolean;
begin
  Result := IS_POINTER_FLAG_SET_WPARAM(wParam, POINTER_MESSAGE_FLAG_FOURTHBUTTON);
end;

function IS_POINTER_FIFTHBUTTON_WPARAM(wParam: WPARAM): Boolean;
begin
  Result := IS_POINTER_FLAG_SET_WPARAM(wParam, POINTER_MESSAGE_FLAG_FIFTHBUTTON);
end;

function IS_POINTER_PRIMARY_WPARAM(wParam: WPARAM): Boolean;
begin
  Result := IS_POINTER_FLAG_SET_WPARAM(wParam, POINTER_MESSAGE_FLAG_PRIMARY);
end;

function HAS_POINTER_CONFIDENCE_WPARAM(wParam: WPARAM): Boolean;
begin
  Result := IS_POINTER_FLAG_SET_WPARAM(wParam, POINTER_MESSAGE_FLAG_CONFIDENCE);
end;

function IS_POINTER_CANCELED_WPARAM(wParam: WPARAM): Boolean;
begin
  Result := IS_POINTER_FLAG_SET_WPARAM(wParam, POINTER_MESSAGE_FLAG_CANCELED);
end;

{ ====== Run-time binding of gdi32 and advapi32, common fallbacks ========== }

var
  Gdi32Slot: TModuleSlot = (Name: gdi32; Handle: 0; Tried: False);
  Advapi32Slot: TModuleSlot = (Name: advapi32; Handle: 0; Tried: False);

function GetGdi32Proc(var Proc: Pointer; Name: PChar): Boolean;
begin
  Result := GetSlotProc(Gdi32Slot, Proc, Name);
end;

function GetAdvapi32Proc(var Proc: Pointer; Name: PChar): Boolean;
begin
  Result := GetSlotProc(Advapi32Slot, Proc, Name);
end;

{ 0 (also nil or a zero handle) after SetLastError(ERROR_CALL_NOT_IMPLEMENTED). }
function NotImplementedZero: DWORD;
begin
  SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
  Result := 0;
end;

{ INVALID_HANDLE_VALUE after SetLastError(ERROR_CALL_NOT_IMPLEMENTED). }
function NotImplementedInvalid: THandle;
begin
  SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
  Result := INVALID_HANDLE_VALUE;
end;

type
  TFnVoid = procedure; stdcall;
  TFnDword = function: DWORD; stdcall;
  TFnDwordDword = function(dw: DWORD): DWORD; stdcall;
  TFnPtrDword = function(p: Pointer): DWORD; stdcall;
  TFnPtrProc = procedure(p: Pointer); stdcall;
  TFnPtrPtr = function(p: Pointer): Pointer; stdcall;
  TFnPtrPtrProc = procedure(p1, p2: Pointer); stdcall;
  TFnPtrIntProc = procedure(p: Pointer; i: Integer); stdcall;
  TFnPtrPtrPtrPtr = function(p1, p2, p3: Pointer): Pointer; stdcall;
  TFnPtrPtrPtrBool = function(p1, p2, p3: Pointer): BOOL; stdcall;
  TFnHandleDwordBool = function(h: THandle; dw: DWORD): BOOL; stdcall;
  TFnHandleHandleBool = function(h1, h2: THandle): BOOL; stdcall;
  TFnHandleVarDwordBool = function(h: THandle; out dw: DWORD): BOOL; stdcall;
  TFnDwordVarDwordBool = function(dw: DWORD; out dw2: DWORD): BOOL; stdcall;
  TFnHandleVarUInt64Bool = function(h: THandle; out Value: UInt64): BOOL; stdcall;
  TFnVarUInt64Bool = function(out Value: UInt64): BOOL; stdcall;
  TFnHandleIntPtrDwordBool = function(h: THandle; i: Integer; p: Pointer; dw: DWORD): BOOL; stdcall;
  TFnHResult = function: HRESULT; stdcall;
  TFnWord = function: Word; stdcall;
  TFnWordDword = function(w: Word): DWORD; stdcall;

{ ====== Power requests and execution state ================================ }

var
  SetThreadExecutionStateProc: Pointer;
  IsSystemResumeAutomaticProc: Pointer;
  PowerCreateRequestProc: Pointer;
  PowerSetRequestProc: Pointer;
  PowerClearRequestProc: Pointer;

function SetThreadExecutionState(esFlags: EXECUTION_STATE): EXECUTION_STATE; stdcall;
begin
  if GetKernel32Proc(SetThreadExecutionStateProc, 'SetThreadExecutionState') then
    Result := TFnDwordDword(SetThreadExecutionStateProc)(esFlags)
  else
    Result := NotImplementedZero;
end;

function IsSystemResumeAutomatic: BOOL; stdcall;
begin
  if GetKernel32Proc(IsSystemResumeAutomaticProc, 'IsSystemResumeAutomatic') then
    Result := TFnBool(IsSystemResumeAutomaticProc)()
  else
    Result := NotImplemented;
end;

function PowerCreateRequest(var Context: TReasonContext): THandle; stdcall;
begin
  if GetKernel32Proc(PowerCreateRequestProc, 'PowerCreateRequest') then
    Result := THandle(TFnPtrPtr(PowerCreateRequestProc)(@Context))
  else
    Result := NotImplementedInvalid;
end;

function PowerSetRequest(PowerRequest: THandle; RequestType: POWER_REQUEST_TYPE): BOOL; stdcall;
begin
  if GetKernel32Proc(PowerSetRequestProc, 'PowerSetRequest') then
    Result := TFnHandleDwordBool(PowerSetRequestProc)(PowerRequest, RequestType)
  else
    Result := NotImplemented;
end;

function PowerClearRequest(PowerRequest: THandle; RequestType: POWER_REQUEST_TYPE): BOOL; stdcall;
begin
  if GetKernel32Proc(PowerClearRequestProc, 'PowerClearRequest') then
    Result := TFnHandleDwordBool(PowerClearRequestProc)(PowerRequest, RequestType)
  else
    Result := NotImplemented;
end;

{ ====== Thread pool ======================================================= }

type
  TFnCreateThreadpoolObject = function(pfn: Pointer; pv: Pointer;
    pcbe: PTP_CALLBACK_ENVIRON): Pointer; stdcall;
  TFnPtrBoolArgProc = procedure(p: Pointer; b: Integer); stdcall;
  TFnSetThreadpoolTimer = procedure(pti: PTP_TIMER; pftDueTime: PFileTime;
    msPeriod, msWindowLength: DWORD); stdcall;
  TFnSetThreadpoolTimerEx = function(pti: PTP_TIMER; pftDueTime: PFileTime;
    msPeriod, msWindowLength: DWORD): BOOL; stdcall;
  TFnSetThreadpoolWait = procedure(pwa: PTP_WAIT; h: THandle; pftTimeout: PFileTime); stdcall;
  TFnSetThreadpoolWaitEx = function(pwa: PTP_WAIT; h: THandle; pftTimeout: PFileTime;
    Reserved: Pointer): BOOL; stdcall;
  TFnReleaseSemaphoreWhenCallbackReturns = procedure(pci: PTP_CALLBACK_INSTANCE; sem: THandle;
    crel: DWORD); stdcall;

var
  CreateThreadpoolWorkProc: Pointer;
  SubmitThreadpoolWorkProc: Pointer;
  WaitForThreadpoolWorkCallbacksProc: Pointer;
  CloseThreadpoolWorkProc: Pointer;
  TrySubmitThreadpoolCallbackProc: Pointer;
  CreateThreadpoolTimerProc: Pointer;
  SetThreadpoolTimerProc: Pointer;
  SetThreadpoolTimerExProc: Pointer;
  IsThreadpoolTimerSetProc: Pointer;
  WaitForThreadpoolTimerCallbacksProc: Pointer;
  CloseThreadpoolTimerProc: Pointer;
  CreateThreadpoolWaitProc: Pointer;
  SetThreadpoolWaitProc: Pointer;
  SetThreadpoolWaitExProc: Pointer;
  WaitForThreadpoolWaitCallbacksProc: Pointer;
  CloseThreadpoolWaitProc: Pointer;
  SetEventWhenCallbackReturnsProc: Pointer;
  ReleaseSemaphoreWhenCallbackReturnsProc: Pointer;
  ReleaseMutexWhenCallbackReturnsProc: Pointer;
  LeaveCriticalSectionWhenCallbackReturnsProc: Pointer;
  FreeLibraryWhenCallbackReturnsProc: Pointer;
  CallbackMayRunLongProc: Pointer;
  DisassociateCurrentThreadFromCallbackProc: Pointer;

function CreateThreadpoolWork(pfnwk: PTP_WORK_CALLBACK; pv: Pointer;
  pcbe: PTP_CALLBACK_ENVIRON): PTP_WORK; stdcall;
begin
  if GetKernel32Proc(CreateThreadpoolWorkProc, 'CreateThreadpoolWork') then
    Result := TFnCreateThreadpoolObject(CreateThreadpoolWorkProc)(@pfnwk, pv, pcbe)
  else
    Result := Pointer(NotImplementedZero);
end;

procedure SubmitThreadpoolWork(pwk: PTP_WORK); stdcall;
begin
  if GetKernel32Proc(SubmitThreadpoolWorkProc, 'SubmitThreadpoolWork') then
    TFnPtrProc(SubmitThreadpoolWorkProc)(pwk);
end;

procedure WaitForThreadpoolWorkCallbacks(pwk: PTP_WORK; fCancelPendingCallbacks: BOOL); stdcall;
begin
  if GetKernel32Proc(WaitForThreadpoolWorkCallbacksProc, 'WaitForThreadpoolWorkCallbacks') then
    TFnPtrBoolArgProc(WaitForThreadpoolWorkCallbacksProc)(pwk, BoolArg(fCancelPendingCallbacks));
end;

procedure CloseThreadpoolWork(pwk: PTP_WORK); stdcall;
begin
  if GetKernel32Proc(CloseThreadpoolWorkProc, 'CloseThreadpoolWork') then
    TFnPtrProc(CloseThreadpoolWorkProc)(pwk);
end;

function TrySubmitThreadpoolCallback(pfns: PTP_SIMPLE_CALLBACK; pv: Pointer;
  pcbe: PTP_CALLBACK_ENVIRON): BOOL; stdcall;
begin
  if GetKernel32Proc(TrySubmitThreadpoolCallbackProc, 'TrySubmitThreadpoolCallback') then
    Result := TFnPtrPtrPtrBool(TrySubmitThreadpoolCallbackProc)(@pfns, pv, pcbe)
  else
    Result := NotImplemented;
end;

function CreateThreadpoolTimer(pfnti: PTP_TIMER_CALLBACK; pv: Pointer;
  pcbe: PTP_CALLBACK_ENVIRON): PTP_TIMER; stdcall;
begin
  if GetKernel32Proc(CreateThreadpoolTimerProc, 'CreateThreadpoolTimer') then
    Result := TFnCreateThreadpoolObject(CreateThreadpoolTimerProc)(@pfnti, pv, pcbe)
  else
    Result := Pointer(NotImplementedZero);
end;

procedure SetThreadpoolTimer(pti: PTP_TIMER; pftDueTime: PFileTime;
  msPeriod, msWindowLength: DWORD); stdcall;
begin
  if GetKernel32Proc(SetThreadpoolTimerProc, 'SetThreadpoolTimer') then
    TFnSetThreadpoolTimer(SetThreadpoolTimerProc)(pti, pftDueTime, msPeriod, msWindowLength);
end;

function SetThreadpoolTimerEx(pti: PTP_TIMER; pftDueTime: PFileTime;
  msPeriod, msWindowLength: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(SetThreadpoolTimerExProc, 'SetThreadpoolTimerEx') then
    Result := TFnSetThreadpoolTimerEx(SetThreadpoolTimerExProc)(pti, pftDueTime, msPeriod,
      msWindowLength)
  else if GetKernel32Proc(SetThreadpoolTimerProc, 'SetThreadpoolTimer') then
  begin
    TFnSetThreadpoolTimer(SetThreadpoolTimerProc)(pti, pftDueTime, msPeriod, msWindowLength);
    Result := False;
  end
  else
    Result := NotImplemented;
end;

function IsThreadpoolTimerSet(pti: PTP_TIMER): BOOL; stdcall;
begin
  if GetKernel32Proc(IsThreadpoolTimerSetProc, 'IsThreadpoolTimerSet') then
    Result := TFnPtrBool(IsThreadpoolTimerSetProc)(pti)
  else
    Result := NotImplemented;
end;

procedure WaitForThreadpoolTimerCallbacks(pti: PTP_TIMER; fCancelPendingCallbacks: BOOL); stdcall;
begin
  if GetKernel32Proc(WaitForThreadpoolTimerCallbacksProc, 'WaitForThreadpoolTimerCallbacks') then
    TFnPtrBoolArgProc(WaitForThreadpoolTimerCallbacksProc)(pti, BoolArg(fCancelPendingCallbacks));
end;

procedure CloseThreadpoolTimer(pti: PTP_TIMER); stdcall;
begin
  if GetKernel32Proc(CloseThreadpoolTimerProc, 'CloseThreadpoolTimer') then
    TFnPtrProc(CloseThreadpoolTimerProc)(pti);
end;

function CreateThreadpoolWait(pfnwa: PTP_WAIT_CALLBACK; pv: Pointer;
  pcbe: PTP_CALLBACK_ENVIRON): PTP_WAIT; stdcall;
begin
  if GetKernel32Proc(CreateThreadpoolWaitProc, 'CreateThreadpoolWait') then
    Result := TFnCreateThreadpoolObject(CreateThreadpoolWaitProc)(@pfnwa, pv, pcbe)
  else
    Result := Pointer(NotImplementedZero);
end;

procedure SetThreadpoolWait(pwa: PTP_WAIT; h: THandle; pftTimeout: PFileTime); stdcall;
begin
  if GetKernel32Proc(SetThreadpoolWaitProc, 'SetThreadpoolWait') then
    TFnSetThreadpoolWait(SetThreadpoolWaitProc)(pwa, h, pftTimeout);
end;

function SetThreadpoolWaitEx(pwa: PTP_WAIT; h: THandle; pftTimeout: PFileTime;
  Reserved: Pointer): BOOL; stdcall;
begin
  if GetKernel32Proc(SetThreadpoolWaitExProc, 'SetThreadpoolWaitEx') then
    Result := TFnSetThreadpoolWaitEx(SetThreadpoolWaitExProc)(pwa, h, pftTimeout, Reserved)
  else if GetKernel32Proc(SetThreadpoolWaitProc, 'SetThreadpoolWait') then
  begin
    TFnSetThreadpoolWait(SetThreadpoolWaitProc)(pwa, h, pftTimeout);
    Result := False;
  end
  else
    Result := NotImplemented;
end;

procedure WaitForThreadpoolWaitCallbacks(pwa: PTP_WAIT; fCancelPendingCallbacks: BOOL); stdcall;
begin
  if GetKernel32Proc(WaitForThreadpoolWaitCallbacksProc, 'WaitForThreadpoolWaitCallbacks') then
    TFnPtrBoolArgProc(WaitForThreadpoolWaitCallbacksProc)(pwa, BoolArg(fCancelPendingCallbacks));
end;

procedure CloseThreadpoolWait(pwa: PTP_WAIT); stdcall;
begin
  if GetKernel32Proc(CloseThreadpoolWaitProc, 'CloseThreadpoolWait') then
    TFnPtrProc(CloseThreadpoolWaitProc)(pwa);
end;

procedure SetEventWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE; evt: THandle); stdcall;
begin
  if GetKernel32Proc(SetEventWhenCallbackReturnsProc, 'SetEventWhenCallbackReturns') then
    TFnPtrPtrProc(SetEventWhenCallbackReturnsProc)(pci, Pointer(evt));
end;

procedure ReleaseSemaphoreWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE; sem: THandle;
  crel: DWORD); stdcall;
begin
  if GetKernel32Proc(ReleaseSemaphoreWhenCallbackReturnsProc,
    'ReleaseSemaphoreWhenCallbackReturns') then
    TFnReleaseSemaphoreWhenCallbackReturns(ReleaseSemaphoreWhenCallbackReturnsProc)(pci, sem, crel);
end;

procedure ReleaseMutexWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE; mut: THandle); stdcall;
begin
  if GetKernel32Proc(ReleaseMutexWhenCallbackReturnsProc, 'ReleaseMutexWhenCallbackReturns') then
    TFnPtrPtrProc(ReleaseMutexWhenCallbackReturnsProc)(pci, Pointer(mut));
end;

procedure LeaveCriticalSectionWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE;
  var pcs: TRTLCriticalSection); stdcall;
begin
  if GetKernel32Proc(LeaveCriticalSectionWhenCallbackReturnsProc,
    'LeaveCriticalSectionWhenCallbackReturns') then
    TFnPtrPtrProc(LeaveCriticalSectionWhenCallbackReturnsProc)(pci, @pcs);
end;

procedure FreeLibraryWhenCallbackReturns(pci: PTP_CALLBACK_INSTANCE; module: HMODULE); stdcall;
begin
  if GetKernel32Proc(FreeLibraryWhenCallbackReturnsProc, 'FreeLibraryWhenCallbackReturns') then
    TFnPtrPtrProc(FreeLibraryWhenCallbackReturnsProc)(pci, Pointer(module));
end;

function CallbackMayRunLong(pci: PTP_CALLBACK_INSTANCE): BOOL; stdcall;
begin
  if GetKernel32Proc(CallbackMayRunLongProc, 'CallbackMayRunLong') then
    Result := TFnPtrBool(CallbackMayRunLongProc)(pci)
  else
    Result := NotImplemented;
end;

procedure DisassociateCurrentThreadFromCallback(pci: PTP_CALLBACK_INSTANCE); stdcall;
begin
  if GetKernel32Proc(DisassociateCurrentThreadFromCallbackProc,
    'DisassociateCurrentThreadFromCallback') then
    TFnPtrProc(DisassociateCurrentThreadFromCallbackProc)(pci);
end;

{ ====== Legacy thread pool and timer queues =============================== }

type
  TFnQueueUserWorkItem = function(Func: TFNThreadStartRoutine; Context: Pointer;
    Flags: ULONG): BOOL; stdcall;
  TFnRegisterWaitForSingleObject = function(out phNewWaitObject: THandle; hObject: THandle;
    Callback: WAITORTIMERCALLBACK; Context: Pointer; dwMilliseconds: ULONG;
    dwFlags: ULONG): BOOL; stdcall;
  TFnCreateTimerQueue = function: THandle; stdcall;
  TFnCreateTimerQueueTimer = function(out phNewTimer: THandle; TimerQueue: THandle;
    Callback: WAITORTIMERCALLBACK; Parameter: Pointer; DueTime, Period: DWORD;
    Flags: ULONG): BOOL; stdcall;
  TFnChangeTimerQueueTimer = function(TimerQueue, Timer: THandle;
    DueTime, Period: ULONG): BOOL; stdcall;
  TFnDeleteTimerQueueTimer = function(TimerQueue, Timer, CompletionEvent: THandle): BOOL; stdcall;

var
  QueueUserWorkItemProc: Pointer;
  RegisterWaitForSingleObjectProc: Pointer;
  UnregisterWaitProc: Pointer;
  UnregisterWaitExProc: Pointer;
  CreateTimerQueueProc: Pointer;
  CreateTimerQueueTimerProc: Pointer;
  ChangeTimerQueueTimerProc: Pointer;
  DeleteTimerQueueTimerProc: Pointer;
  DeleteTimerQueueExProc: Pointer;

function QueueUserWorkItem(Func: TFNThreadStartRoutine; Context: Pointer;
  Flags: ULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(QueueUserWorkItemProc, 'QueueUserWorkItem') then
    Result := TFnQueueUserWorkItem(QueueUserWorkItemProc)(Func, Context, Flags)
  else
    Result := NotImplemented;
end;

function RegisterWaitForSingleObject(out phNewWaitObject: THandle; hObject: THandle;
  Callback: WAITORTIMERCALLBACK; Context: Pointer; dwMilliseconds: ULONG;
  dwFlags: ULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(RegisterWaitForSingleObjectProc, 'RegisterWaitForSingleObject') then
    Result := TFnRegisterWaitForSingleObject(RegisterWaitForSingleObjectProc)(phNewWaitObject,
      hObject, Callback, Context, dwMilliseconds, dwFlags)
  else
  begin
    phNewWaitObject := 0;
    Result := NotImplemented;
  end;
end;

function UnregisterWait(WaitHandle: THandle): BOOL; stdcall;
begin
  if GetKernel32Proc(UnregisterWaitProc, 'UnregisterWait') then
    Result := TFnHandleBool(UnregisterWaitProc)(WaitHandle)
  else
    Result := NotImplemented;
end;

function UnregisterWaitEx(WaitHandle: THandle; CompletionEvent: THandle): BOOL; stdcall;
begin
  if GetKernel32Proc(UnregisterWaitExProc, 'UnregisterWaitEx') then
    Result := TFnHandleHandleBool(UnregisterWaitExProc)(WaitHandle, CompletionEvent)
  else
    Result := NotImplemented;
end;

function CreateTimerQueue: THandle; stdcall;
begin
  if GetKernel32Proc(CreateTimerQueueProc, 'CreateTimerQueue') then
    Result := TFnCreateTimerQueue(CreateTimerQueueProc)()
  else
    Result := NotImplementedZero;
end;

function CreateTimerQueueTimer(out phNewTimer: THandle; TimerQueue: THandle;
  Callback: WAITORTIMERCALLBACK; Parameter: Pointer; DueTime, Period: DWORD;
  Flags: ULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(CreateTimerQueueTimerProc, 'CreateTimerQueueTimer') then
    Result := TFnCreateTimerQueueTimer(CreateTimerQueueTimerProc)(phNewTimer, TimerQueue,
      Callback, Parameter, DueTime, Period, Flags)
  else
  begin
    phNewTimer := 0;
    Result := NotImplemented;
  end;
end;

function ChangeTimerQueueTimer(TimerQueue, Timer: THandle; DueTime, Period: ULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(ChangeTimerQueueTimerProc, 'ChangeTimerQueueTimer') then
    Result := TFnChangeTimerQueueTimer(ChangeTimerQueueTimerProc)(TimerQueue, Timer, DueTime,
      Period)
  else
    Result := NotImplemented;
end;

function DeleteTimerQueueTimer(TimerQueue, Timer, CompletionEvent: THandle): BOOL; stdcall;
begin
  if GetKernel32Proc(DeleteTimerQueueTimerProc, 'DeleteTimerQueueTimer') then
    Result := TFnDeleteTimerQueueTimer(DeleteTimerQueueTimerProc)(TimerQueue, Timer,
      CompletionEvent)
  else
    Result := NotImplemented;
end;

function DeleteTimerQueueEx(TimerQueue, CompletionEvent: THandle): BOOL; stdcall;
begin
  if GetKernel32Proc(DeleteTimerQueueExProc, 'DeleteTimerQueueEx') then
    Result := TFnHandleHandleBool(DeleteTimerQueueExProc)(TimerQueue, CompletionEvent)
  else
    Result := NotImplemented;
end;

{ ====== One-time initialization and synchronization objects ============== }

type
  TFnInitOnceExecuteOnce = function(InitOnce: PInitOnce; InitFn: PINIT_ONCE_FN;
    Parameter: Pointer; Context: PPointer): BOOL; stdcall;
  TFnInitOnceBeginInitialize = function(lpInitOnce: PInitOnce; dwFlags: DWORD;
    out fPending: BOOL; lpContext: PPointer): BOOL; stdcall;
  TFnInitOnceComplete = function(lpInitOnce: PInitOnce; dwFlags: DWORD;
    lpContext: Pointer): BOOL; stdcall;
  TFnInitializeCriticalSectionEx = function(var lpCriticalSection: TRTLCriticalSection;
    dwSpinCount: DWORD; Flags: DWORD): BOOL; stdcall;
  TFnCreateSyncEx = function(lpAttributes: PSecurityAttributes; lpName: Pointer;
    dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
  TFnCreateSemaphoreEx = function(lpSemaphoreAttributes: PSecurityAttributes;
    lInitialCount, lMaximumCount: Longint; lpName: Pointer; dwFlags: DWORD;
    dwDesiredAccess: DWORD): THandle; stdcall;
  TFnSetWaitableTimerEx = function(hTimer: THandle; lpDueTime: PInt64; lPeriod: Longint;
    pfnCompletionRoutine: TFNTimerAPCRoutine; lpArgToCompletionRoutine: Pointer;
    WakeContext: PReasonContext; TolerableDelay: ULONG): BOOL; stdcall;

var
  InitOnceMode: Integer;               { 0 = not decided, 1 = native, 2 = emulated }
  InitOnceInitializeProc: Pointer;
  InitOnceExecuteOnceProc: Pointer;
  InitOnceBeginInitializeProc: Pointer;
  InitOnceCompleteProc: Pointer;
  InitializeCriticalSectionExProc: Pointer;
  CreateEventExAProc: Pointer;
  CreateEventExWProc: Pointer;
  CreateMutexExAProc: Pointer;
  CreateMutexExWProc: Pointer;
  CreateSemaphoreExAProc: Pointer;
  CreateSemaphoreExWProc: Pointer;
  CreateWaitableTimerExAProc: Pointer;
  CreateWaitableTimerExWProc: Pointer;
  SetWaitableTimerExProc: Pointer;

{ InitOnceInitialize and InitOnceExecuteOnce are used natively or both are
  emulated (they exist since Windows Vista), decided once. }
function NativeInitOnce: Boolean;
begin
  if InitOnceMode = 0 then
  begin
    if GetKernel32Proc(InitOnceInitializeProc, 'InitOnceInitialize') and
      GetKernel32Proc(InitOnceExecuteOnceProc, 'InitOnceExecuteOnce') then
      InitOnceMode := 1
    else
      InitOnceMode := 2;
  end;
  Result := InitOnceMode = 1;
end;

procedure InitOnceInitialize(var InitOnce: TInitOnce); stdcall;
begin
  if NativeInitOnce then
    TFnPtrProc(InitOnceInitializeProc)(@InitOnce)
  else
    InitOnce.Ptr := nil;
end;

{ Emulated INIT_ONCE: Ptr = nil: not run; 1: the callback is running;
  otherwise done, the context with bit 1 set (bits 0-1 are free in a
  context, INIT_ONCE_CTX_RESERVED_BITS). }
function InitOnceExecuteOnce(var InitOnce: TInitOnce; InitFn: PINIT_ONCE_FN;
  Parameter: Pointer; Context: PPointer): BOOL; stdcall;
var
  State: Cardinal;
  Ctx: Pointer;
  Spins: Integer;
  Ok: Boolean;
begin
  if NativeInitOnce then
  begin
    Result := TFnInitOnceExecuteOnce(InitOnceExecuteOnceProc)(@InitOnce, InitFn, Parameter,
      Context);
    Exit;
  end;
  Spins := 0;
  repeat
    State := Cardinal(InitOnce.Ptr);
    if State and 3 = 2 then
    begin
      if Context <> nil then
        Context^ := Pointer(State and not Cardinal(3));
      Result := True;
      Exit;
    end;
    if (State = 0) and (InterlockedCompareExchange(InitOnce.Ptr, Pointer(1), nil) = nil) then
    begin
      Ctx := nil;
      try
        Ok := InitFn(@InitOnce, Parameter, @Ctx);
      except
        InterlockedExchange(Integer(InitOnce.Ptr), 0);
        raise;
      end;
      if Ok then
      begin
        Ctx := Pointer(Cardinal(Ctx) and not Cardinal(3));
        InterlockedExchange(Integer(InitOnce.Ptr), Integer(Cardinal(Ctx) or 2));
        if Context <> nil then
          Context^ := Ctx;
        Result := True;
      end
      else
      begin
        InterlockedExchange(Integer(InitOnce.Ptr), 0);    { the next caller tries again }
        Result := False;
      end;
      Exit;
    end;
    SRWBackOff(Spins);                 { another thread runs the callback }
  until False;
end;

function InitOnceBeginInitialize(var lpInitOnce: TInitOnce; dwFlags: DWORD;
  out fPending: BOOL; lpContext: PPointer): BOOL; stdcall;
begin
  if NativeInitOnce and
    GetKernel32Proc(InitOnceBeginInitializeProc, 'InitOnceBeginInitialize') then
    Result := TFnInitOnceBeginInitialize(InitOnceBeginInitializeProc)(@lpInitOnce, dwFlags,
      fPending, lpContext)
  else
  begin
    fPending := False;
    Result := NotImplemented;
  end;
end;

function InitOnceComplete(var lpInitOnce: TInitOnce; dwFlags: DWORD;
  lpContext: Pointer): BOOL; stdcall;
begin
  if NativeInitOnce and GetKernel32Proc(InitOnceCompleteProc, 'InitOnceComplete') then
    Result := TFnInitOnceComplete(InitOnceCompleteProc)(@lpInitOnce, dwFlags, lpContext)
  else
    Result := NotImplemented;
end;

function InitializeCriticalSectionEx(var lpCriticalSection: TRTLCriticalSection;
  dwSpinCount: DWORD; Flags: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(InitializeCriticalSectionExProc, 'InitializeCriticalSectionEx') then
    Result := TFnInitializeCriticalSectionEx(InitializeCriticalSectionExProc)(lpCriticalSection,
      dwSpinCount, Flags)
  else
    Result := InitializeCriticalSectionAndSpinCount(lpCriticalSection, dwSpinCount);
end;

function CreateEventEx(lpEventAttributes: PSecurityAttributes; lpName: PChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
begin
  Result := CreateEventExA(lpEventAttributes, lpName, dwFlags, dwDesiredAccess);
end;

function CreateEventExA(lpEventAttributes: PSecurityAttributes; lpName: PAnsiChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
begin
  if GetKernel32Proc(CreateEventExAProc, 'CreateEventExA') then
    Result := TFnCreateSyncEx(CreateEventExAProc)(lpEventAttributes, lpName, dwFlags,
      dwDesiredAccess)
  else
    Result := CreateEventA(lpEventAttributes, dwFlags and CREATE_EVENT_MANUAL_RESET <> 0,
      dwFlags and CREATE_EVENT_INITIAL_SET <> 0, lpName);
end;

function CreateEventExW(lpEventAttributes: PSecurityAttributes; lpName: PWideChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
begin
  if GetKernel32Proc(CreateEventExWProc, 'CreateEventExW') then
    Result := TFnCreateSyncEx(CreateEventExWProc)(lpEventAttributes, lpName, dwFlags,
      dwDesiredAccess)
  else
    Result := CreateEventW(lpEventAttributes, dwFlags and CREATE_EVENT_MANUAL_RESET <> 0,
      dwFlags and CREATE_EVENT_INITIAL_SET <> 0, lpName);
end;

function CreateMutexEx(lpMutexAttributes: PSecurityAttributes; lpName: PChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
begin
  Result := CreateMutexExA(lpMutexAttributes, lpName, dwFlags, dwDesiredAccess);
end;

function CreateMutexExA(lpMutexAttributes: PSecurityAttributes; lpName: PAnsiChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
begin
  if GetKernel32Proc(CreateMutexExAProc, 'CreateMutexExA') then
    Result := TFnCreateSyncEx(CreateMutexExAProc)(lpMutexAttributes, lpName, dwFlags,
      dwDesiredAccess)
  else
    Result := CreateMutexA(lpMutexAttributes, dwFlags and CREATE_MUTEX_INITIAL_OWNER <> 0, lpName);
end;

function CreateMutexExW(lpMutexAttributes: PSecurityAttributes; lpName: PWideChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
begin
  if GetKernel32Proc(CreateMutexExWProc, 'CreateMutexExW') then
    Result := TFnCreateSyncEx(CreateMutexExWProc)(lpMutexAttributes, lpName, dwFlags,
      dwDesiredAccess)
  else
    Result := CreateMutexW(lpMutexAttributes, dwFlags and CREATE_MUTEX_INITIAL_OWNER <> 0, lpName);
end;

function CreateSemaphoreEx(lpSemaphoreAttributes: PSecurityAttributes;
  lInitialCount, lMaximumCount: Longint; lpName: PChar; dwFlags: DWORD;
  dwDesiredAccess: DWORD): THandle; stdcall;
begin
  Result := CreateSemaphoreExA(lpSemaphoreAttributes, lInitialCount, lMaximumCount, lpName,
    dwFlags, dwDesiredAccess);
end;

function CreateSemaphoreExA(lpSemaphoreAttributes: PSecurityAttributes;
  lInitialCount, lMaximumCount: Longint; lpName: PAnsiChar; dwFlags: DWORD;
  dwDesiredAccess: DWORD): THandle; stdcall;
begin
  if GetKernel32Proc(CreateSemaphoreExAProc, 'CreateSemaphoreExA') then
    Result := TFnCreateSemaphoreEx(CreateSemaphoreExAProc)(lpSemaphoreAttributes, lInitialCount,
      lMaximumCount, lpName, dwFlags, dwDesiredAccess)
  else
    Result := CreateSemaphoreA(lpSemaphoreAttributes, lInitialCount, lMaximumCount, lpName);
end;

function CreateSemaphoreExW(lpSemaphoreAttributes: PSecurityAttributes;
  lInitialCount, lMaximumCount: Longint; lpName: PWideChar; dwFlags: DWORD;
  dwDesiredAccess: DWORD): THandle; stdcall;
begin
  if GetKernel32Proc(CreateSemaphoreExWProc, 'CreateSemaphoreExW') then
    Result := TFnCreateSemaphoreEx(CreateSemaphoreExWProc)(lpSemaphoreAttributes, lInitialCount,
      lMaximumCount, lpName, dwFlags, dwDesiredAccess)
  else
    Result := CreateSemaphoreW(lpSemaphoreAttributes, lInitialCount, lMaximumCount, lpName);
end;

function CreateWaitableTimerEx(lpTimerAttributes: PSecurityAttributes; lpTimerName: PChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
begin
  Result := CreateWaitableTimerExA(lpTimerAttributes, lpTimerName, dwFlags, dwDesiredAccess);
end;

function CreateWaitableTimerExA(lpTimerAttributes: PSecurityAttributes; lpTimerName: PAnsiChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
begin
  if GetKernel32Proc(CreateWaitableTimerExAProc, 'CreateWaitableTimerExA') then
    Result := TFnCreateSyncEx(CreateWaitableTimerExAProc)(lpTimerAttributes, lpTimerName,
      dwFlags, dwDesiredAccess)
  else if dwFlags and CREATE_WAITABLE_TIMER_HIGH_RESOLUTION <> 0 then
  begin
    SetLastError(ERROR_INVALID_PARAMETER);
    Result := 0;
  end
  else
    Result := CreateWaitableTimerA(lpTimerAttributes,
      dwFlags and CREATE_WAITABLE_TIMER_MANUAL_RESET <> 0, lpTimerName);
end;

function CreateWaitableTimerExW(lpTimerAttributes: PSecurityAttributes; lpTimerName: PWideChar;
  dwFlags: DWORD; dwDesiredAccess: DWORD): THandle; stdcall;
begin
  if GetKernel32Proc(CreateWaitableTimerExWProc, 'CreateWaitableTimerExW') then
    Result := TFnCreateSyncEx(CreateWaitableTimerExWProc)(lpTimerAttributes, lpTimerName,
      dwFlags, dwDesiredAccess)
  else if dwFlags and CREATE_WAITABLE_TIMER_HIGH_RESOLUTION <> 0 then
  begin
    SetLastError(ERROR_INVALID_PARAMETER);
    Result := 0;
  end
  else
    Result := CreateWaitableTimerW(lpTimerAttributes,
      dwFlags and CREATE_WAITABLE_TIMER_MANUAL_RESET <> 0, lpTimerName);
end;

function SetWaitableTimerEx(hTimer: THandle; const lpDueTime: Int64; lPeriod: Longint;
  pfnCompletionRoutine: TFNTimerAPCRoutine; lpArgToCompletionRoutine: Pointer;
  WakeContext: PReasonContext; TolerableDelay: ULONG): BOOL; stdcall;
var
  DueTime: TLargeInteger;
begin
  if GetKernel32Proc(SetWaitableTimerExProc, 'SetWaitableTimerEx') then
    Result := TFnSetWaitableTimerEx(SetWaitableTimerExProc)(hTimer, @lpDueTime, lPeriod,
      pfnCompletionRoutine, lpArgToCompletionRoutine, WakeContext, TolerableDelay)
  else
  begin
    DueTime := lpDueTime;
    Result := SetWaitableTimer(hTimer, DueTime, lPeriod, pfnCompletionRoutine,
      lpArgToCompletionRoutine, WakeContext <> nil);
  end;
end;

{ ====== Fiber local storage =============================================== }

type
  TFnFlsAlloc = function(lpCallback: PFLS_CALLBACK_FUNCTION): DWORD; stdcall;
  TFnDwordPtr = function(dw: DWORD): Pointer; stdcall;
  TFnDwordPtrBool = function(dw: DWORD; p: Pointer): BOOL; stdcall;

var
  FlsMode: Integer;                    { 0 = not decided, 1 = native, 2 = TLS }
  FlsAllocProc: Pointer;
  FlsGetValueProc: Pointer;
  FlsSetValueProc: Pointer;
  FlsFreeProc: Pointer;

function NativeFls: Boolean;
begin
  if FlsMode = 0 then
  begin
    if GetKernel32Proc(FlsAllocProc, 'FlsAlloc') and
      GetKernel32Proc(FlsGetValueProc, 'FlsGetValue') and
      GetKernel32Proc(FlsSetValueProc, 'FlsSetValue') and
      GetKernel32Proc(FlsFreeProc, 'FlsFree') then
      FlsMode := 1
    else
      FlsMode := 2;
  end;
  Result := FlsMode = 1;
end;

function FlsAlloc(lpCallback: PFLS_CALLBACK_FUNCTION): DWORD; stdcall;
begin
  if NativeFls then
    Result := TFnFlsAlloc(FlsAllocProc)(lpCallback)
  else if Assigned(lpCallback) then
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := FLS_OUT_OF_INDEXES;
  end
  else
    Result := TlsAlloc;                { TLS_OUT_OF_INDEXES = FLS_OUT_OF_INDEXES }
end;

function FlsGetValue(dwFlsIndex: DWORD): Pointer; stdcall;
begin
  if NativeFls then
    Result := TFnDwordPtr(FlsGetValueProc)(dwFlsIndex)
  else
    Result := TlsGetValue(dwFlsIndex);
end;

function FlsSetValue(dwFlsIndex: DWORD; lpFlsData: Pointer): BOOL; stdcall;
begin
  if NativeFls then
    Result := TFnDwordPtrBool(FlsSetValueProc)(dwFlsIndex, lpFlsData)
  else
    Result := TlsSetValue(dwFlsIndex, lpFlsData);
end;

function FlsFree(dwFlsIndex: DWORD): BOOL; stdcall;
begin
  if NativeFls then
    Result := TFnDwordBool(FlsFreeProc)(dwFlsIndex)
  else
    Result := TlsFree(dwFlsIndex);
end;

{ ====== Threads and processes ============================================= }

type
  TFnOpenThread = function(dwDesiredAccess: DWORD; bInheritHandle: Integer;
    dwThreadId: DWORD): THandle; stdcall;
  TFnHandleDword = function(h: THandle): DWORD; stdcall;
  TFnHandlePtrHResult = function(h: THandle; p: Pointer): HRESULT; stdcall;
  TFnGetThreadDescription = function(hThread: THandle;
    out ppszThreadDescription: PWideChar): HRESULT; stdcall;
  TFnQueryIdleProcessorCycleTime = function(var BufferLength: ULONG;
    ProcessorIdleCycleTime: PInt64): BOOL; stdcall;
  TFnSetThreadErrorMode = function(dwNewMode: DWORD; lpOldMode: LPDWORD): BOOL; stdcall;
  TFnVarUlongBool = function(var Value: ULONG): BOOL; stdcall;
  TFnGetCurrentThreadStackLimits = procedure(out LowLimit, HighLimit: ULONG_PTR); stdcall;

var
  OpenThreadProc: Pointer;
  GetThreadIdProc: Pointer;
  GetProcessIdProc: Pointer;
  GetProcessIdOfThreadProc: Pointer;
  SetThreadDescriptionProc: Pointer;
  GetThreadDescriptionProc: Pointer;
  GetCurrentProcessorNumberProc: Pointer;
  GetCurrentProcessorNumberExProc: Pointer;
  QueryThreadCycleTimeProc: Pointer;
  QueryProcessCycleTimeProc: Pointer;
  QueryIdleProcessorCycleTimeProc: Pointer;
  QueryUnbiasedInterruptTimeProc: Pointer;
  GetThreadInformationProc: Pointer;
  SetThreadInformationProc: Pointer;
  GetProcessInformationProc: Pointer;
  SetProcessInformationProc: Pointer;
  GetErrorModeProc: Pointer;
  GetThreadErrorModeProc: Pointer;
  SetThreadErrorModeProc: Pointer;
  SetThreadStackGuaranteeProc: Pointer;
  GetCurrentThreadStackLimitsProc: Pointer;
  GetProcessHandleCountProc: Pointer;
  ProcessIdToSessionIdProc: Pointer;

function OpenThread(dwDesiredAccess: DWORD; bInheritHandle: BOOL;
  dwThreadId: DWORD): THandle; stdcall;
begin
  if GetKernel32Proc(OpenThreadProc, 'OpenThread') then
    Result := TFnOpenThread(OpenThreadProc)(dwDesiredAccess, BoolArg(bInheritHandle), dwThreadId)
  else
    Result := NotImplementedZero;
end;

function GetThreadId(Thread: THandle): DWORD; stdcall;
begin
  if GetKernel32Proc(GetThreadIdProc, 'GetThreadId') then
    Result := TFnHandleDword(GetThreadIdProc)(Thread)
  else
    Result := NotImplementedZero;
end;

function GetProcessId(Process: THandle): DWORD; stdcall;
begin
  if GetKernel32Proc(GetProcessIdProc, 'GetProcessId') then
    Result := TFnHandleDword(GetProcessIdProc)(Process)
  else
    Result := NotImplementedZero;
end;

function GetProcessIdOfThread(Thread: THandle): DWORD; stdcall;
begin
  if GetKernel32Proc(GetProcessIdOfThreadProc, 'GetProcessIdOfThread') then
    Result := TFnHandleDword(GetProcessIdOfThreadProc)(Thread)
  else
    Result := NotImplementedZero;
end;

function SetThreadDescription(hThread: THandle; lpThreadDescription: PWideChar): HRESULT; stdcall;
begin
  if GetKernel32Proc(SetThreadDescriptionProc, 'SetThreadDescription') then
    Result := TFnHandlePtrHResult(SetThreadDescriptionProc)(hThread, lpThreadDescription)
  else
    Result := E_NOTIMPL;
end;

function GetThreadDescription(hThread: THandle;
  out ppszThreadDescription: PWideChar): HRESULT; stdcall;
begin
  if GetKernel32Proc(GetThreadDescriptionProc, 'GetThreadDescription') then
    Result := TFnGetThreadDescription(GetThreadDescriptionProc)(hThread, ppszThreadDescription)
  else
  begin
    ppszThreadDescription := nil;
    Result := E_NOTIMPL;
  end;
end;

function GetCurrentProcessorNumber: DWORD; stdcall;
begin
  if GetKernel32Proc(GetCurrentProcessorNumberProc, 'GetCurrentProcessorNumber') then
    Result := TFnDword(GetCurrentProcessorNumberProc)()
  else
    Result := 0;
end;

procedure GetCurrentProcessorNumberEx(out ProcNumber: TProcessorNumber); stdcall;
begin
  if GetKernel32Proc(GetCurrentProcessorNumberExProc, 'GetCurrentProcessorNumberEx') then
    TFnPtrProc(GetCurrentProcessorNumberExProc)(@ProcNumber)
  else
  begin
    ProcNumber.Group := 0;
    ProcNumber.Number := Byte(GetCurrentProcessorNumber);
    ProcNumber.Reserved := 0;
  end;
end;

function QueryThreadCycleTime(ThreadHandle: THandle; out CycleTime: UInt64): BOOL; stdcall;
begin
  if GetKernel32Proc(QueryThreadCycleTimeProc, 'QueryThreadCycleTime') then
    Result := TFnHandleVarUInt64Bool(QueryThreadCycleTimeProc)(ThreadHandle, CycleTime)
  else
  begin
    CycleTime := 0;
    Result := NotImplemented;
  end;
end;

function QueryProcessCycleTime(ProcessHandle: THandle; out CycleTime: UInt64): BOOL; stdcall;
begin
  if GetKernel32Proc(QueryProcessCycleTimeProc, 'QueryProcessCycleTime') then
    Result := TFnHandleVarUInt64Bool(QueryProcessCycleTimeProc)(ProcessHandle, CycleTime)
  else
  begin
    CycleTime := 0;
    Result := NotImplemented;
  end;
end;

function QueryIdleProcessorCycleTime(var BufferLength: ULONG;
  ProcessorIdleCycleTime: PInt64): BOOL; stdcall;
begin
  if GetKernel32Proc(QueryIdleProcessorCycleTimeProc, 'QueryIdleProcessorCycleTime') then
    Result := TFnQueryIdleProcessorCycleTime(QueryIdleProcessorCycleTimeProc)(BufferLength,
      ProcessorIdleCycleTime)
  else
    Result := NotImplemented;
end;

function QueryUnbiasedInterruptTime(out UnbiasedTime: UInt64): BOOL; stdcall;
begin
  if GetKernel32Proc(QueryUnbiasedInterruptTimeProc, 'QueryUnbiasedInterruptTime') then
    Result := TFnVarUInt64Bool(QueryUnbiasedInterruptTimeProc)(UnbiasedTime)
  else
  begin
    UnbiasedTime := 0;
    Result := NotImplemented;
  end;
end;

function GetThreadInformation(hThread: THandle; ThreadInformationClass: THREAD_INFORMATION_CLASS;
  ThreadInformation: Pointer; ThreadInformationSize: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetThreadInformationProc, 'GetThreadInformation') then
    Result := TFnHandleIntPtrDwordBool(GetThreadInformationProc)(hThread, ThreadInformationClass,
      ThreadInformation, ThreadInformationSize)
  else
    Result := NotImplemented;
end;

function SetThreadInformation(hThread: THandle; ThreadInformationClass: THREAD_INFORMATION_CLASS;
  ThreadInformation: Pointer; ThreadInformationSize: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(SetThreadInformationProc, 'SetThreadInformation') then
    Result := TFnHandleIntPtrDwordBool(SetThreadInformationProc)(hThread, ThreadInformationClass,
      ThreadInformation, ThreadInformationSize)
  else
    Result := NotImplemented;
end;

function GetProcessInformation(hProcess: THandle;
  ProcessInformationClass: PROCESS_INFORMATION_CLASS; ProcessInformation: Pointer;
  ProcessInformationSize: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetProcessInformationProc, 'GetProcessInformation') then
    Result := TFnHandleIntPtrDwordBool(GetProcessInformationProc)(hProcess,
      ProcessInformationClass, ProcessInformation, ProcessInformationSize)
  else
    Result := NotImplemented;
end;

function SetProcessInformation(hProcess: THandle;
  ProcessInformationClass: PROCESS_INFORMATION_CLASS; ProcessInformation: Pointer;
  ProcessInformationSize: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(SetProcessInformationProc, 'SetProcessInformation') then
    Result := TFnHandleIntPtrDwordBool(SetProcessInformationProc)(hProcess,
      ProcessInformationClass, ProcessInformation, ProcessInformationSize)
  else
    Result := NotImplemented;
end;

function GetErrorMode: UINT; stdcall;
begin
  if GetKernel32Proc(GetErrorModeProc, 'GetErrorMode') then
    Result := TFnDword(GetErrorModeProc)()
  else
  begin
    Result := SetErrorMode(0);
    SetErrorMode(Result);
  end;
end;

function GetThreadErrorMode: DWORD; stdcall;
begin
  if GetKernel32Proc(GetThreadErrorModeProc, 'GetThreadErrorMode') then
    Result := TFnDword(GetThreadErrorModeProc)()
  else
    Result := GetErrorMode;
end;

function SetThreadErrorMode(dwNewMode: DWORD; lpOldMode: LPDWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(SetThreadErrorModeProc, 'SetThreadErrorMode') then
    Result := TFnSetThreadErrorMode(SetThreadErrorModeProc)(dwNewMode, lpOldMode)
  else
    Result := NotImplemented;
end;

function SetThreadStackGuarantee(var StackSizeInBytes: ULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(SetThreadStackGuaranteeProc, 'SetThreadStackGuarantee') then
    Result := TFnVarUlongBool(SetThreadStackGuaranteeProc)(StackSizeInBytes)
  else
    Result := NotImplemented;
end;

{ The stack base of the current thread: NT_TIB.StackBase at FS:[4]. }
function CurrentStackBase: ULONG_PTR;
asm
        MOV     EAX,FS:[4]
end;

procedure GetCurrentThreadStackLimits(out LowLimit, HighLimit: ULONG_PTR); stdcall;
var
  Info: TMemoryBasicInformation;
begin
  if GetKernel32Proc(GetCurrentThreadStackLimitsProc, 'GetCurrentThreadStackLimits') then
    TFnGetCurrentThreadStackLimits(GetCurrentThreadStackLimitsProc)(LowLimit, HighLimit)
  else
  begin
    { the stack is one reservation: its allocation base is the low limit }
    FillChar(Info, SizeOf(Info), 0);
    VirtualQuery(@Info, Info, SizeOf(Info));
    LowLimit := ULONG_PTR(Info.AllocationBase);
    HighLimit := CurrentStackBase;
  end;
end;

function GetProcessHandleCount(hProcess: THandle; out pdwHandleCount: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetProcessHandleCountProc, 'GetProcessHandleCount') then
    Result := TFnHandleVarDwordBool(GetProcessHandleCountProc)(hProcess, pdwHandleCount)
  else
  begin
    pdwHandleCount := 0;
    Result := NotImplemented;
  end;
end;

function ProcessIdToSessionId(dwProcessId: DWORD; out pSessionId: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(ProcessIdToSessionIdProc, 'ProcessIdToSessionId') then
    Result := TFnDwordVarDwordBool(ProcessIdToSessionIdProc)(dwProcessId, pSessionId)
  else
  begin
    pSessionId := 0;
    Result := NotImplemented;
  end;
end;

{ ====== Job objects ======================================================= }

type
  TFnCreateJobObject = function(lpJobAttributes: PSecurityAttributes;
    lpName: Pointer): THandle; stdcall;
  TFnOpenJobObject = function(dwDesiredAccess: DWORD; bInheritHandle: Integer;
    lpName: Pointer): THandle; stdcall;
  TFnQueryInformationJobObject = function(hJob: THandle; JobObjectInformationClass: Integer;
    lpJobObjectInformation: Pointer; cbJobObjectInformationLength: DWORD;
    lpReturnLength: LPDWORD): BOOL; stdcall;
  TFnSetInformationJobObject = function(hJob: THandle; JobObjectInformationClass: Integer;
    lpJobObjectInformation: Pointer; cbJobObjectInformationLength: DWORD): BOOL; stdcall;
  TFnIsProcessInJob = function(ProcessHandle, JobHandle: THandle; out Result_: BOOL): BOOL; stdcall;
  TFnGetProcessIoCounters = function(hProcess: THandle; out lpIoCounters: TIoCounters): BOOL; stdcall;

var
  CreateJobObjectAProc: Pointer;
  CreateJobObjectWProc: Pointer;
  OpenJobObjectAProc: Pointer;
  OpenJobObjectWProc: Pointer;
  AssignProcessToJobObjectProc: Pointer;
  TerminateJobObjectProc: Pointer;
  QueryInformationJobObjectProc: Pointer;
  SetInformationJobObjectProc: Pointer;
  IsProcessInJobProc: Pointer;
  GetProcessIoCountersProc: Pointer;

function CreateJobObject(lpJobAttributes: PSecurityAttributes; lpName: PChar): THandle; stdcall;
begin
  Result := CreateJobObjectA(lpJobAttributes, lpName);
end;

function CreateJobObjectA(lpJobAttributes: PSecurityAttributes; lpName: PAnsiChar): THandle; stdcall;
begin
  if GetKernel32Proc(CreateJobObjectAProc, 'CreateJobObjectA') then
    Result := TFnCreateJobObject(CreateJobObjectAProc)(lpJobAttributes, lpName)
  else
    Result := NotImplementedZero;
end;

function CreateJobObjectW(lpJobAttributes: PSecurityAttributes; lpName: PWideChar): THandle; stdcall;
begin
  if GetKernel32Proc(CreateJobObjectWProc, 'CreateJobObjectW') then
    Result := TFnCreateJobObject(CreateJobObjectWProc)(lpJobAttributes, lpName)
  else
    Result := NotImplementedZero;
end;

function OpenJobObject(dwDesiredAccess: DWORD; bInheritHandle: BOOL; lpName: PChar): THandle; stdcall;
begin
  Result := OpenJobObjectA(dwDesiredAccess, bInheritHandle, lpName);
end;

function OpenJobObjectA(dwDesiredAccess: DWORD; bInheritHandle: BOOL; lpName: PAnsiChar): THandle; stdcall;
begin
  if GetKernel32Proc(OpenJobObjectAProc, 'OpenJobObjectA') then
    Result := TFnOpenJobObject(OpenJobObjectAProc)(dwDesiredAccess, BoolArg(bInheritHandle), lpName)
  else
    Result := NotImplementedZero;
end;

function OpenJobObjectW(dwDesiredAccess: DWORD; bInheritHandle: BOOL; lpName: PWideChar): THandle; stdcall;
begin
  if GetKernel32Proc(OpenJobObjectWProc, 'OpenJobObjectW') then
    Result := TFnOpenJobObject(OpenJobObjectWProc)(dwDesiredAccess, BoolArg(bInheritHandle), lpName)
  else
    Result := NotImplementedZero;
end;

function AssignProcessToJobObject(hJob, hProcess: THandle): BOOL; stdcall;
begin
  if GetKernel32Proc(AssignProcessToJobObjectProc, 'AssignProcessToJobObject') then
    Result := TFnHandleHandleBool(AssignProcessToJobObjectProc)(hJob, hProcess)
  else
    Result := NotImplemented;
end;

function TerminateJobObject(hJob: THandle; uExitCode: UINT): BOOL; stdcall;
begin
  if GetKernel32Proc(TerminateJobObjectProc, 'TerminateJobObject') then
    Result := TFnHandleDwordBool(TerminateJobObjectProc)(hJob, uExitCode)
  else
    Result := NotImplemented;
end;

function QueryInformationJobObject(hJob: THandle; JobObjectInformationClass: JOBOBJECTINFOCLASS;
  lpJobObjectInformation: Pointer; cbJobObjectInformationLength: DWORD;
  lpReturnLength: LPDWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(QueryInformationJobObjectProc, 'QueryInformationJobObject') then
    Result := TFnQueryInformationJobObject(QueryInformationJobObjectProc)(hJob,
      JobObjectInformationClass, lpJobObjectInformation, cbJobObjectInformationLength,
      lpReturnLength)
  else
    Result := NotImplemented;
end;

function SetInformationJobObject(hJob: THandle; JobObjectInformationClass: JOBOBJECTINFOCLASS;
  lpJobObjectInformation: Pointer; cbJobObjectInformationLength: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(SetInformationJobObjectProc, 'SetInformationJobObject') then
    Result := TFnSetInformationJobObject(SetInformationJobObjectProc)(hJob,
      JobObjectInformationClass, lpJobObjectInformation, cbJobObjectInformationLength)
  else
    Result := NotImplemented;
end;

function IsProcessInJob(ProcessHandle, JobHandle: THandle; out Result_: BOOL): BOOL; stdcall;
begin
  if GetKernel32Proc(IsProcessInJobProc, 'IsProcessInJob') then
    Result := TFnIsProcessInJob(IsProcessInJobProc)(ProcessHandle, JobHandle, Result_)
  else
  begin
    Result_ := False;
    Result := NotImplemented;
  end;
end;

function GetProcessIoCounters(hProcess: THandle; out lpIoCounters: TIoCounters): BOOL; stdcall;
begin
  if GetKernel32Proc(GetProcessIoCountersProc, 'GetProcessIoCounters') then
    Result := TFnGetProcessIoCounters(GetProcessIoCountersProc)(hProcess, lpIoCounters)
  else
    Result := NotImplemented;
end;

{ ====== Process and thread attribute lists ================================ }

type
  TFnInitializeProcThreadAttributeList = function(lpAttributeList: Pointer;
    dwAttributeCount: DWORD; dwFlags: DWORD; var lpSize: ULONG_PTR): BOOL; stdcall;
  TFnUpdateProcThreadAttribute = function(lpAttributeList: Pointer; dwFlags: DWORD;
    Attribute: DWORD_PTR; lpValue: Pointer; cbSize: ULONG_PTR; lpPreviousValue: Pointer;
    lpReturnSize: PULONG): BOOL; stdcall;

var
  InitializeProcThreadAttributeListProc: Pointer;
  UpdateProcThreadAttributeProc: Pointer;
  DeleteProcThreadAttributeListProc: Pointer;

function InitializeProcThreadAttributeList(lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST;
  dwAttributeCount: DWORD; dwFlags: DWORD; var lpSize: ULONG_PTR): BOOL; stdcall;
begin
  if GetKernel32Proc(InitializeProcThreadAttributeListProc,
    'InitializeProcThreadAttributeList') then
    Result := TFnInitializeProcThreadAttributeList(InitializeProcThreadAttributeListProc)(
      lpAttributeList, dwAttributeCount, dwFlags, lpSize)
  else
    Result := NotImplemented;
end;

function UpdateProcThreadAttribute(lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST;
  dwFlags: DWORD; Attribute: DWORD_PTR; lpValue: Pointer; cbSize: ULONG_PTR;
  lpPreviousValue: Pointer; lpReturnSize: PULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(UpdateProcThreadAttributeProc, 'UpdateProcThreadAttribute') then
    Result := TFnUpdateProcThreadAttribute(UpdateProcThreadAttributeProc)(lpAttributeList,
      dwFlags, Attribute, lpValue, cbSize, lpPreviousValue, lpReturnSize)
  else
    Result := NotImplemented;
end;

procedure DeleteProcThreadAttributeList(lpAttributeList: LPPROC_THREAD_ATTRIBUTE_LIST); stdcall;
begin
  if GetKernel32Proc(DeleteProcThreadAttributeListProc, 'DeleteProcThreadAttributeList') then
    TFnPtrProc(DeleteProcThreadAttributeListProc)(lpAttributeList);
end;

{ ====== Files and volumes ================================================= }

type
  TFnGetFileSizeEx = function(hFile: THandle; out lpFileSize: Int64): BOOL; stdcall;
  TFnSetFilePointerEx = function(hFile: THandle; liDistanceToMove: Int64;
    lpNewFilePointer: PInt64; dwMoveMethod: DWORD): BOOL; stdcall;
  TFnReplaceFile = function(lpReplacedFileName, lpReplacementFileName,
    lpBackupFileName: Pointer; dwReplaceFlags: DWORD; lpExclude, lpReserved: Pointer): BOOL; stdcall;
  TFnPtrPtrDword = function(p1, p2: Pointer; dw: DWORD): DWORD; stdcall;
  TFnPtrPtrDwordBool = function(p1, p2: Pointer; dw: DWORD): BOOL; stdcall;
  TFnGetVolumePathNamesForVolumeName = function(lpszVolumeName, lpszVolumePathNames: Pointer;
    cchBufferLength: DWORD; out lpcchReturnLength: DWORD): BOOL; stdcall;
  TFnPtrDwordHandle = function(p: Pointer; dw: DWORD): THandle; stdcall;
  TFnHandlePtrDwordBool = function(h: THandle; p: Pointer; dw: DWORD): BOOL; stdcall;
  TFnGetVolumeInformationByHandleW = function(hFile: THandle; lpVolumeNameBuffer: PWideChar;
    nVolumeNameSize: DWORD; lpVolumeSerialNumber, lpMaximumComponentLength,
    lpFileSystemFlags: LPDWORD; lpFileSystemNameBuffer: PWideChar;
    nFileSystemNameSize: DWORD): BOOL; stdcall;
  TFnCopyFile2 = function(pwszExistingFileName, pwszNewFileName: PWideChar;
    pExtendedParameters: PCopyFile2ExtendedParameters): HRESULT; stdcall;
  TFnFindFirstStreamW = function(lpFileName: PWideChar; InfoLevel: Integer;
    lpFindStreamData: Pointer; dwFlags: DWORD): THandle; stdcall;
  TFnHandlePtrBool = function(h: THandle; p: Pointer): BOOL; stdcall;
  TFnFindFirstFileNameW = function(lpFileName: PWideChar; dwFlags: DWORD;
    var StringLength: DWORD; LinkName: PWideChar): THandle; stdcall;
  TFnFindNextFileNameW = function(hFindStream: THandle; var StringLength: DWORD;
    LinkName: PWideChar): BOOL; stdcall;
  TFnOpenFileById = function(hVolumeHint: THandle; lpFileId: PFileIdDescriptor;
    dwDesiredAccess, dwShareMode: DWORD; lpSecurityAttributes: PSecurityAttributes;
    dwFlagsAndAttributes: DWORD): THandle; stdcall;
  TFnReOpenFile = function(hOriginalFile: THandle; dwDesiredAccess, dwShareMode,
    dwFlagsAndAttributes: DWORD): THandle; stdcall;

var
  GetFileSizeExProc: Pointer;
  SetFilePointerExProc: Pointer;
  GetFileInformationByHandleExProc: Pointer;
  SetFileInformationByHandleProc: Pointer;
  ReplaceFileAProc: Pointer;
  ReplaceFileWProc: Pointer;
  GetLongPathNameAProc: Pointer;
  GetLongPathNameWProc: Pointer;
  GetVolumePathNameAProc: Pointer;
  GetVolumePathNameWProc: Pointer;
  GetVolumeNameForVolumeMountPointAProc: Pointer;
  GetVolumeNameForVolumeMountPointWProc: Pointer;
  GetVolumePathNamesForVolumeNameAProc: Pointer;
  GetVolumePathNamesForVolumeNameWProc: Pointer;
  FindFirstVolumeAProc: Pointer;
  FindFirstVolumeWProc: Pointer;
  FindNextVolumeAProc: Pointer;
  FindNextVolumeWProc: Pointer;
  FindVolumeCloseProc: Pointer;
  GetVolumeInformationByHandleWProc: Pointer;
  CopyFile2Proc: Pointer;
  GetTempPath2AProc: Pointer;
  GetTempPath2WProc: Pointer;
  FindFirstStreamWProc: Pointer;
  FindNextStreamWProc: Pointer;
  FindFirstFileNameWProc: Pointer;
  FindNextFileNameWProc: Pointer;
  OpenFileByIdProc: Pointer;
  ReOpenFileProc: Pointer;

function GetFileSizeEx(hFile: THandle; out lpFileSize: Int64): BOOL; stdcall;
var
  Low, High: DWORD;
begin
  if GetKernel32Proc(GetFileSizeExProc, 'GetFileSizeEx') then
  begin
    Result := TFnGetFileSizeEx(GetFileSizeExProc)(hFile, lpFileSize);
    Exit;
  end;
  SetLastError(NO_ERROR);
  High := 0;
  Low := GetFileSize(hFile, @High);
  Result := (Low <> DWORD($FFFFFFFF)) or (GetLastError = NO_ERROR);
  if Result then
    lpFileSize := (Int64(High) shl 32) or Low
  else
    lpFileSize := 0;
end;

function SetFilePointerEx(hFile: THandle; liDistanceToMove: Int64; lpNewFilePointer: PInt64;
  dwMoveMethod: DWORD): BOOL; stdcall;
var
  Low: DWORD;
  High: Longint;
begin
  if GetKernel32Proc(SetFilePointerExProc, 'SetFilePointerEx') then
  begin
    Result := TFnSetFilePointerEx(SetFilePointerExProc)(hFile, liDistanceToMove,
      lpNewFilePointer, dwMoveMethod);
    Exit;
  end;
  SetLastError(NO_ERROR);
  High := Longint(liDistanceToMove shr 32);
  Low := SetFilePointer(hFile, Longint(liDistanceToMove), @High, dwMoveMethod);
  Result := (Low <> DWORD($FFFFFFFF)) or (GetLastError = NO_ERROR);
  if Result and (lpNewFilePointer <> nil) then
    lpNewFilePointer^ := (Int64(High) shl 32) or Low;
end;

function GetFileInformationByHandleEx(hFile: THandle;
  FileInformationClass: FILE_INFO_BY_HANDLE_CLASS; lpFileInformation: Pointer;
  dwBufferSize: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetFileInformationByHandleExProc, 'GetFileInformationByHandleEx') then
    Result := TFnHandleIntPtrDwordBool(GetFileInformationByHandleExProc)(hFile,
      FileInformationClass, lpFileInformation, dwBufferSize)
  else
    Result := NotImplemented;
end;

function SetFileInformationByHandle(hFile: THandle;
  FileInformationClass: FILE_INFO_BY_HANDLE_CLASS; lpFileInformation: Pointer;
  dwBufferSize: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(SetFileInformationByHandleProc, 'SetFileInformationByHandle') then
    Result := TFnHandleIntPtrDwordBool(SetFileInformationByHandleProc)(hFile,
      FileInformationClass, lpFileInformation, dwBufferSize)
  else
    Result := NotImplemented;
end;

function ReplaceFile(lpReplacedFileName, lpReplacementFileName, lpBackupFileName: PChar;
  dwReplaceFlags: DWORD; lpExclude, lpReserved: Pointer): BOOL; stdcall;
begin
  Result := ReplaceFileA(lpReplacedFileName, lpReplacementFileName, lpBackupFileName,
    dwReplaceFlags, lpExclude, lpReserved);
end;

function ReplaceFileA(lpReplacedFileName, lpReplacementFileName, lpBackupFileName: PAnsiChar;
  dwReplaceFlags: DWORD; lpExclude, lpReserved: Pointer): BOOL; stdcall;
begin
  if GetKernel32Proc(ReplaceFileAProc, 'ReplaceFileA') then
    Result := TFnReplaceFile(ReplaceFileAProc)(lpReplacedFileName, lpReplacementFileName,
      lpBackupFileName, dwReplaceFlags, lpExclude, lpReserved)
  else
    Result := NotImplemented;
end;

function ReplaceFileW(lpReplacedFileName, lpReplacementFileName, lpBackupFileName: PWideChar;
  dwReplaceFlags: DWORD; lpExclude, lpReserved: Pointer): BOOL; stdcall;
begin
  if GetKernel32Proc(ReplaceFileWProc, 'ReplaceFileW') then
    Result := TFnReplaceFile(ReplaceFileWProc)(lpReplacedFileName, lpReplacementFileName,
      lpBackupFileName, dwReplaceFlags, lpExclude, lpReserved)
  else
    Result := NotImplemented;
end;

function GetLongPathName(lpszShortPath, lpszLongPath: PChar; cchBuffer: DWORD): DWORD; stdcall;
begin
  Result := GetLongPathNameA(lpszShortPath, lpszLongPath, cchBuffer);
end;

function GetLongPathNameA(lpszShortPath, lpszLongPath: PAnsiChar; cchBuffer: DWORD): DWORD; stdcall;
begin
  if GetKernel32Proc(GetLongPathNameAProc, 'GetLongPathNameA') then
    Result := TFnPtrPtrDword(GetLongPathNameAProc)(lpszShortPath, lpszLongPath, cchBuffer)
  else
    Result := NotImplementedZero;
end;

function GetLongPathNameW(lpszShortPath, lpszLongPath: PWideChar; cchBuffer: DWORD): DWORD; stdcall;
begin
  if GetKernel32Proc(GetLongPathNameWProc, 'GetLongPathNameW') then
    Result := TFnPtrPtrDword(GetLongPathNameWProc)(lpszShortPath, lpszLongPath, cchBuffer)
  else
    Result := NotImplementedZero;
end;

function GetVolumePathName(lpszFileName, lpszVolumePathName: PChar;
  cchBufferLength: DWORD): BOOL; stdcall;
begin
  Result := GetVolumePathNameA(lpszFileName, lpszVolumePathName, cchBufferLength);
end;

function GetVolumePathNameA(lpszFileName, lpszVolumePathName: PAnsiChar;
  cchBufferLength: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetVolumePathNameAProc, 'GetVolumePathNameA') then
    Result := TFnPtrPtrDwordBool(GetVolumePathNameAProc)(lpszFileName, lpszVolumePathName,
      cchBufferLength)
  else
    Result := NotImplemented;
end;

function GetVolumePathNameW(lpszFileName, lpszVolumePathName: PWideChar;
  cchBufferLength: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetVolumePathNameWProc, 'GetVolumePathNameW') then
    Result := TFnPtrPtrDwordBool(GetVolumePathNameWProc)(lpszFileName, lpszVolumePathName,
      cchBufferLength)
  else
    Result := NotImplemented;
end;

function GetVolumeNameForVolumeMountPoint(lpszVolumeMountPoint, lpszVolumeName: PChar;
  cchBufferLength: DWORD): BOOL; stdcall;
begin
  Result := GetVolumeNameForVolumeMountPointA(lpszVolumeMountPoint, lpszVolumeName,
    cchBufferLength);
end;

function GetVolumeNameForVolumeMountPointA(lpszVolumeMountPoint, lpszVolumeName: PAnsiChar;
  cchBufferLength: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetVolumeNameForVolumeMountPointAProc,
    'GetVolumeNameForVolumeMountPointA') then
    Result := TFnPtrPtrDwordBool(GetVolumeNameForVolumeMountPointAProc)(lpszVolumeMountPoint,
      lpszVolumeName, cchBufferLength)
  else
    Result := NotImplemented;
end;

function GetVolumeNameForVolumeMountPointW(lpszVolumeMountPoint, lpszVolumeName: PWideChar;
  cchBufferLength: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetVolumeNameForVolumeMountPointWProc,
    'GetVolumeNameForVolumeMountPointW') then
    Result := TFnPtrPtrDwordBool(GetVolumeNameForVolumeMountPointWProc)(lpszVolumeMountPoint,
      lpszVolumeName, cchBufferLength)
  else
    Result := NotImplemented;
end;

function GetVolumePathNamesForVolumeName(lpszVolumeName, lpszVolumePathNames: PChar;
  cchBufferLength: DWORD; out lpcchReturnLength: DWORD): BOOL; stdcall;
begin
  Result := GetVolumePathNamesForVolumeNameA(lpszVolumeName, lpszVolumePathNames,
    cchBufferLength, lpcchReturnLength);
end;

function GetVolumePathNamesForVolumeNameA(lpszVolumeName, lpszVolumePathNames: PAnsiChar;
  cchBufferLength: DWORD; out lpcchReturnLength: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetVolumePathNamesForVolumeNameAProc,
    'GetVolumePathNamesForVolumeNameA') then
    Result := TFnGetVolumePathNamesForVolumeName(GetVolumePathNamesForVolumeNameAProc)(
      lpszVolumeName, lpszVolumePathNames, cchBufferLength, lpcchReturnLength)
  else
  begin
    lpcchReturnLength := 0;
    Result := NotImplemented;
  end;
end;

function GetVolumePathNamesForVolumeNameW(lpszVolumeName, lpszVolumePathNames: PWideChar;
  cchBufferLength: DWORD; out lpcchReturnLength: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetVolumePathNamesForVolumeNameWProc,
    'GetVolumePathNamesForVolumeNameW') then
    Result := TFnGetVolumePathNamesForVolumeName(GetVolumePathNamesForVolumeNameWProc)(
      lpszVolumeName, lpszVolumePathNames, cchBufferLength, lpcchReturnLength)
  else
  begin
    lpcchReturnLength := 0;
    Result := NotImplemented;
  end;
end;

function FindFirstVolume(lpszVolumeName: PChar; cchBufferLength: DWORD): THandle; stdcall;
begin
  Result := FindFirstVolumeA(lpszVolumeName, cchBufferLength);
end;

function FindFirstVolumeA(lpszVolumeName: PAnsiChar; cchBufferLength: DWORD): THandle; stdcall;
begin
  if GetKernel32Proc(FindFirstVolumeAProc, 'FindFirstVolumeA') then
    Result := TFnPtrDwordHandle(FindFirstVolumeAProc)(lpszVolumeName, cchBufferLength)
  else
    Result := NotImplementedInvalid;
end;

function FindFirstVolumeW(lpszVolumeName: PWideChar; cchBufferLength: DWORD): THandle; stdcall;
begin
  if GetKernel32Proc(FindFirstVolumeWProc, 'FindFirstVolumeW') then
    Result := TFnPtrDwordHandle(FindFirstVolumeWProc)(lpszVolumeName, cchBufferLength)
  else
    Result := NotImplementedInvalid;
end;

function FindNextVolume(hFindVolume: THandle; lpszVolumeName: PChar;
  cchBufferLength: DWORD): BOOL; stdcall;
begin
  Result := FindNextVolumeA(hFindVolume, lpszVolumeName, cchBufferLength);
end;

function FindNextVolumeA(hFindVolume: THandle; lpszVolumeName: PAnsiChar;
  cchBufferLength: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(FindNextVolumeAProc, 'FindNextVolumeA') then
    Result := TFnHandlePtrDwordBool(FindNextVolumeAProc)(hFindVolume, lpszVolumeName,
      cchBufferLength)
  else
    Result := NotImplemented;
end;

function FindNextVolumeW(hFindVolume: THandle; lpszVolumeName: PWideChar;
  cchBufferLength: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(FindNextVolumeWProc, 'FindNextVolumeW') then
    Result := TFnHandlePtrDwordBool(FindNextVolumeWProc)(hFindVolume, lpszVolumeName,
      cchBufferLength)
  else
    Result := NotImplemented;
end;

function FindVolumeClose(hFindVolume: THandle): BOOL; stdcall;
begin
  if GetKernel32Proc(FindVolumeCloseProc, 'FindVolumeClose') then
    Result := TFnHandleBool(FindVolumeCloseProc)(hFindVolume)
  else
    Result := NotImplemented;
end;

function GetVolumeInformationByHandleW(hFile: THandle; lpVolumeNameBuffer: PWideChar;
  nVolumeNameSize: DWORD; lpVolumeSerialNumber, lpMaximumComponentLength,
  lpFileSystemFlags: LPDWORD; lpFileSystemNameBuffer: PWideChar;
  nFileSystemNameSize: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetVolumeInformationByHandleWProc, 'GetVolumeInformationByHandleW') then
    Result := TFnGetVolumeInformationByHandleW(GetVolumeInformationByHandleWProc)(hFile,
      lpVolumeNameBuffer, nVolumeNameSize, lpVolumeSerialNumber, lpMaximumComponentLength,
      lpFileSystemFlags, lpFileSystemNameBuffer, nFileSystemNameSize)
  else
    Result := NotImplemented;
end;

function CopyFile2(pwszExistingFileName, pwszNewFileName: PWideChar;
  pExtendedParameters: PCopyFile2ExtendedParameters): HRESULT; stdcall;
begin
  if GetKernel32Proc(CopyFile2Proc, 'CopyFile2') then
    Result := TFnCopyFile2(CopyFile2Proc)(pwszExistingFileName, pwszNewFileName,
      pExtendedParameters)
  else
    Result := E_NOTIMPL;
end;

function GetTempPath2(BufferLength: DWORD; Buffer: PChar): DWORD; stdcall;
begin
  Result := GetTempPath2A(BufferLength, Buffer);
end;

function GetTempPath2A(BufferLength: DWORD; Buffer: PAnsiChar): DWORD; stdcall;
begin
  if GetKernel32Proc(GetTempPath2AProc, 'GetTempPath2A') then
    Result := TFnDwordPtrDword(GetTempPath2AProc)(BufferLength, Buffer)
  else
    Result := GetTempPathA(BufferLength, Buffer);
end;

function GetTempPath2W(BufferLength: DWORD; Buffer: PWideChar): DWORD; stdcall;
begin
  if GetKernel32Proc(GetTempPath2WProc, 'GetTempPath2W') then
    Result := TFnDwordPtrDword(GetTempPath2WProc)(BufferLength, Buffer)
  else
    Result := GetTempPathW(BufferLength, Buffer);
end;

function FindFirstStreamW(lpFileName: PWideChar; InfoLevel: STREAM_INFO_LEVELS;
  lpFindStreamData: Pointer; dwFlags: DWORD): THandle; stdcall;
begin
  if GetKernel32Proc(FindFirstStreamWProc, 'FindFirstStreamW') then
    Result := TFnFindFirstStreamW(FindFirstStreamWProc)(lpFileName, InfoLevel, lpFindStreamData,
      dwFlags)
  else
    Result := NotImplementedInvalid;
end;

function FindNextStreamW(hFindStream: THandle; lpFindStreamData: Pointer): BOOL; stdcall;
begin
  if GetKernel32Proc(FindNextStreamWProc, 'FindNextStreamW') then
    Result := TFnHandlePtrBool(FindNextStreamWProc)(hFindStream, lpFindStreamData)
  else
    Result := NotImplemented;
end;

function FindFirstFileNameW(lpFileName: PWideChar; dwFlags: DWORD; var StringLength: DWORD;
  LinkName: PWideChar): THandle; stdcall;
begin
  if GetKernel32Proc(FindFirstFileNameWProc, 'FindFirstFileNameW') then
    Result := TFnFindFirstFileNameW(FindFirstFileNameWProc)(lpFileName, dwFlags, StringLength,
      LinkName)
  else
    Result := NotImplementedInvalid;
end;

function FindNextFileNameW(hFindStream: THandle; var StringLength: DWORD;
  LinkName: PWideChar): BOOL; stdcall;
begin
  if GetKernel32Proc(FindNextFileNameWProc, 'FindNextFileNameW') then
    Result := TFnFindNextFileNameW(FindNextFileNameWProc)(hFindStream, StringLength, LinkName)
  else
    Result := NotImplemented;
end;

function OpenFileById(hVolumeHint: THandle; const lpFileId: TFileIdDescriptor;
  dwDesiredAccess, dwShareMode: DWORD; lpSecurityAttributes: PSecurityAttributes;
  dwFlagsAndAttributes: DWORD): THandle; stdcall;
begin
  if GetKernel32Proc(OpenFileByIdProc, 'OpenFileById') then
    Result := TFnOpenFileById(OpenFileByIdProc)(hVolumeHint, @lpFileId, dwDesiredAccess,
      dwShareMode, lpSecurityAttributes, dwFlagsAndAttributes)
  else
    Result := NotImplementedInvalid;
end;

function ReOpenFile(hOriginalFile: THandle; dwDesiredAccess, dwShareMode,
  dwFlagsAndAttributes: DWORD): THandle; stdcall;
begin
  if GetKernel32Proc(ReOpenFileProc, 'ReOpenFile') then
    Result := TFnReOpenFile(ReOpenFileProc)(hOriginalFile, dwDesiredAccess, dwShareMode,
      dwFlagsAndAttributes)
  else
    Result := NotImplementedInvalid;
end;

{ ====== Asynchronous I/O ================================================== }

type
  TFnGetQueuedCompletionStatusEx = function(CompletionPort: THandle;
    lpCompletionPortEntries: POverlappedEntry; ulCount: ULONG; out ulNumEntriesRemoved: ULONG;
    dwMilliseconds: DWORD; fAlertable: Integer): BOOL; stdcall;
  TFnGetOverlappedResultEx = function(hFile: THandle; lpOverlapped: POverlapped;
    out lpNumberOfBytesTransferred: DWORD; dwMilliseconds: DWORD;
    bAlertable: Integer): BOOL; stdcall;

var
  CancelIoExProc: Pointer;
  CancelSynchronousIoProc: Pointer;
  GetQueuedCompletionStatusExProc: Pointer;
  SetFileCompletionNotificationModesProc: Pointer;
  GetOverlappedResultExProc: Pointer;

function CancelIoEx(hFile: THandle; lpOverlapped: POverlapped): BOOL; stdcall;
begin
  if GetKernel32Proc(CancelIoExProc, 'CancelIoEx') then
    Result := TFnHandlePtrBool(CancelIoExProc)(hFile, lpOverlapped)
  else
    Result := NotImplemented;
end;

function CancelSynchronousIo(hThread: THandle): BOOL; stdcall;
begin
  if GetKernel32Proc(CancelSynchronousIoProc, 'CancelSynchronousIo') then
    Result := TFnHandleBool(CancelSynchronousIoProc)(hThread)
  else
    Result := NotImplemented;
end;

function GetQueuedCompletionStatusEx(CompletionPort: THandle;
  lpCompletionPortEntries: POverlappedEntry; ulCount: ULONG; out ulNumEntriesRemoved: ULONG;
  dwMilliseconds: DWORD; fAlertable: BOOL): BOOL; stdcall;
begin
  if GetKernel32Proc(GetQueuedCompletionStatusExProc, 'GetQueuedCompletionStatusEx') then
    Result := TFnGetQueuedCompletionStatusEx(GetQueuedCompletionStatusExProc)(CompletionPort,
      lpCompletionPortEntries, ulCount, ulNumEntriesRemoved, dwMilliseconds, BoolArg(fAlertable))
  else
  begin
    ulNumEntriesRemoved := 0;
    Result := NotImplemented;
  end;
end;

function SetFileCompletionNotificationModes(FileHandle: THandle; Flags: UCHAR): BOOL; stdcall;
begin
  if GetKernel32Proc(SetFileCompletionNotificationModesProc,
    'SetFileCompletionNotificationModes') then
    Result := TFnHandleDwordBool(SetFileCompletionNotificationModesProc)(FileHandle, Flags)
  else
    Result := NotImplemented;
end;

function GetOverlappedResultEx(hFile: THandle; const lpOverlapped: TOverlapped;
  out lpNumberOfBytesTransferred: DWORD; dwMilliseconds: DWORD; bAlertable: BOOL): BOOL; stdcall;
begin
  if GetKernel32Proc(GetOverlappedResultExProc, 'GetOverlappedResultEx') then
    Result := TFnGetOverlappedResultEx(GetOverlappedResultExProc)(hFile, @lpOverlapped,
      lpNumberOfBytesTransferred, dwMilliseconds, BoolArg(bAlertable))
  else
  begin
    lpNumberOfBytesTransferred := 0;
    Result := NotImplemented;
  end;
end;

{ ====== Named pipes ======================================================= }

var
  GetNamedPipeClientProcessIdProc: Pointer;
  GetNamedPipeClientSessionIdProc: Pointer;
  GetNamedPipeServerProcessIdProc: Pointer;
  GetNamedPipeServerSessionIdProc: Pointer;

function GetNamedPipeClientProcessId(Pipe: THandle; out ClientProcessId: ULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(GetNamedPipeClientProcessIdProc, 'GetNamedPipeClientProcessId') then
    Result := TFnHandleVarDwordBool(GetNamedPipeClientProcessIdProc)(Pipe, ClientProcessId)
  else
  begin
    ClientProcessId := 0;
    Result := NotImplemented;
  end;
end;

function GetNamedPipeClientSessionId(Pipe: THandle; out ClientSessionId: ULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(GetNamedPipeClientSessionIdProc, 'GetNamedPipeClientSessionId') then
    Result := TFnHandleVarDwordBool(GetNamedPipeClientSessionIdProc)(Pipe, ClientSessionId)
  else
  begin
    ClientSessionId := 0;
    Result := NotImplemented;
  end;
end;

function GetNamedPipeServerProcessId(Pipe: THandle; out ServerProcessId: ULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(GetNamedPipeServerProcessIdProc, 'GetNamedPipeServerProcessId') then
    Result := TFnHandleVarDwordBool(GetNamedPipeServerProcessIdProc)(Pipe, ServerProcessId)
  else
  begin
    ServerProcessId := 0;
    Result := NotImplemented;
  end;
end;

function GetNamedPipeServerSessionId(Pipe: THandle; out ServerSessionId: ULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(GetNamedPipeServerSessionIdProc, 'GetNamedPipeServerSessionId') then
    Result := TFnHandleVarDwordBool(GetNamedPipeServerSessionIdProc)(Pipe, ServerSessionId)
  else
  begin
    ServerSessionId := 0;
    Result := NotImplemented;
  end;
end;

{ ====== Memory and processors ============================================= }

type
  TFnGetLogicalProcessorInformation = function(Buffer: Pointer;
    var ReturnedLength: DWORD): BOOL; stdcall;
  TFnGetLogicalProcessorInformationEx = function(RelationshipType: Integer; Buffer: Pointer;
    var ReturnedLength: DWORD): BOOL; stdcall;

var
  GlobalMemoryStatusExProc: Pointer;
  GetPhysicallyInstalledSystemMemoryProc: Pointer;
  GetLogicalProcessorInformationProc: Pointer;
  GetLogicalProcessorInformationExProc: Pointer;
  GetActiveProcessorCountProc: Pointer;
  GetMaximumProcessorCountProc: Pointer;
  GetActiveProcessorGroupCountProc: Pointer;
  GetMaximumProcessorGroupCountProc: Pointer;
  GetSystemTimesProc: Pointer;

function GlobalMemoryStatusEx(var lpBuffer: TMemoryStatusEx): BOOL; stdcall;
begin
  if GetKernel32Proc(GlobalMemoryStatusExProc, 'GlobalMemoryStatusEx') then
    Result := TFnPtrBool(GlobalMemoryStatusExProc)(@lpBuffer)
  else
    Result := NotImplemented;
end;

function GetPhysicallyInstalledSystemMemory(out TotalMemoryInKilobytes: UInt64): BOOL; stdcall;
begin
  if GetKernel32Proc(GetPhysicallyInstalledSystemMemoryProc,
    'GetPhysicallyInstalledSystemMemory') then
    Result := TFnVarUInt64Bool(GetPhysicallyInstalledSystemMemoryProc)(TotalMemoryInKilobytes)
  else
  begin
    TotalMemoryInKilobytes := 0;
    Result := NotImplemented;
  end;
end;

function GetLogicalProcessorInformation(Buffer: PSystemLogicalProcessorInformation;
  var ReturnedLength: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetLogicalProcessorInformationProc, 'GetLogicalProcessorInformation') then
    Result := TFnGetLogicalProcessorInformation(GetLogicalProcessorInformationProc)(Buffer,
      ReturnedLength)
  else
    Result := NotImplemented;
end;

function GetLogicalProcessorInformationEx(RelationshipType: LOGICAL_PROCESSOR_RELATIONSHIP;
  Buffer: PSystemLogicalProcessorInformationEx; var ReturnedLength: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetLogicalProcessorInformationExProc, 'GetLogicalProcessorInformationEx') then
    Result := TFnGetLogicalProcessorInformationEx(GetLogicalProcessorInformationExProc)(
      RelationshipType, Buffer, ReturnedLength)
  else
    Result := NotImplemented;
end;

{ Processor count of a system with a single processor group. }
function SingleGroupProcessorCount(GroupNumber: Word): DWORD;
var
  Info: TSystemInfo;
begin
  if (GroupNumber = 0) or (GroupNumber = ALL_PROCESSOR_GROUPS) then
  begin
    GetSystemInfo(Info);
    Result := Info.dwNumberOfProcessors;
  end
  else
    Result := 0;
end;

function GetActiveProcessorCount(GroupNumber: Word): DWORD; stdcall;
begin
  if GetKernel32Proc(GetActiveProcessorCountProc, 'GetActiveProcessorCount') then
    Result := TFnWordDword(GetActiveProcessorCountProc)(GroupNumber)
  else
    Result := SingleGroupProcessorCount(GroupNumber);
end;

function GetMaximumProcessorCount(GroupNumber: Word): DWORD; stdcall;
begin
  if GetKernel32Proc(GetMaximumProcessorCountProc, 'GetMaximumProcessorCount') then
    Result := TFnWordDword(GetMaximumProcessorCountProc)(GroupNumber)
  else
    Result := SingleGroupProcessorCount(GroupNumber);
end;

function GetActiveProcessorGroupCount: Word; stdcall;
begin
  if GetKernel32Proc(GetActiveProcessorGroupCountProc, 'GetActiveProcessorGroupCount') then
    Result := TFnWord(GetActiveProcessorGroupCountProc)()
  else
    Result := 1;
end;

function GetMaximumProcessorGroupCount: Word; stdcall;
begin
  if GetKernel32Proc(GetMaximumProcessorGroupCountProc, 'GetMaximumProcessorGroupCount') then
    Result := TFnWord(GetMaximumProcessorGroupCountProc)()
  else
    Result := 1;
end;

function GetSystemTimes(lpIdleTime, lpKernelTime, lpUserTime: PFileTime): BOOL; stdcall;
begin
  if GetKernel32Proc(GetSystemTimesProc, 'GetSystemTimes') then
    Result := TFnPtrPtrPtrBool(GetSystemTimesProc)(lpIdleTime, lpKernelTime, lpUserTime)
  else
    Result := NotImplemented;
end;

{ ====== WOW64, firmware, computer name ==================================== }

type
  TFnIsWow64Process2 = function(hProcess: THandle; out pProcessMachine: Word;
    pNativeMachine: PWord): BOOL; stdcall;
  TFnPtrUintUint = function(p: Pointer; u: UINT): UINT; stdcall;
  TFnVarPtrBool = function(out p: Pointer): BOOL; stdcall;
  TFnGetFirmwareType = function(out FirmwareType: FIRMWARE_TYPE): BOOL; stdcall;
  TFnGetComputerNameEx = function(NameType: Integer; lpBuffer: Pointer;
    var nSize: DWORD): BOOL; stdcall;

var
  IsWow64Process2Proc: Pointer;
  GetSystemWow64DirectoryAProc: Pointer;
  GetSystemWow64DirectoryWProc: Pointer;
  Wow64DisableWow64FsRedirectionProc: Pointer;
  Wow64RevertWow64FsRedirectionProc: Pointer;
  GetFirmwareTypeProc: Pointer;
  GetComputerNameExAProc: Pointer;
  GetComputerNameExWProc: Pointer;

function IsWow64Process2(hProcess: THandle; out pProcessMachine: Word;
  pNativeMachine: PWord): BOOL; stdcall;
var
  Wow64: BOOL;
  Info: TSystemInfo;
begin
  if GetKernel32Proc(IsWow64Process2Proc, 'IsWow64Process2') then
  begin
    Result := TFnIsWow64Process2(IsWow64Process2Proc)(hProcess, pProcessMachine, pNativeMachine);
    Exit;
  end;
  { Before Windows 10 1511 only x86 code ran under WOW64. }
  Wow64 := False;
  Result := IsWow64Process(hProcess, Wow64);
  if not Result then
  begin
    pProcessMachine := IMAGE_FILE_MACHINE_UNKNOWN;
    Exit;
  end;
  if Wow64 then
    pProcessMachine := IMAGE_FILE_MACHINE_I386
  else
    pProcessMachine := IMAGE_FILE_MACHINE_UNKNOWN;
  if pNativeMachine <> nil then
  begin
    GetNativeSystemInfo(Info);
    case Info.wProcessorArchitecture of
      PROCESSOR_ARCHITECTURE_AMD64: pNativeMachine^ := IMAGE_FILE_MACHINE_AMD64;
      PROCESSOR_ARCHITECTURE_IA64: pNativeMachine^ := IMAGE_FILE_MACHINE_IA64;
      PROCESSOR_ARCHITECTURE_ARM64: pNativeMachine^ := IMAGE_FILE_MACHINE_ARM64;
      PROCESSOR_ARCHITECTURE_ARM: pNativeMachine^ := IMAGE_FILE_MACHINE_ARMNT;
    else
      pNativeMachine^ := IMAGE_FILE_MACHINE_I386;
    end;
  end;
end;

function GetSystemWow64Directory(lpBuffer: PChar; uSize: UINT): UINT; stdcall;
begin
  Result := GetSystemWow64DirectoryA(lpBuffer, uSize);
end;

function GetSystemWow64DirectoryA(lpBuffer: PAnsiChar; uSize: UINT): UINT; stdcall;
begin
  if GetKernel32Proc(GetSystemWow64DirectoryAProc, 'GetSystemWow64DirectoryA') then
    Result := TFnPtrUintUint(GetSystemWow64DirectoryAProc)(lpBuffer, uSize)
  else
    Result := NotImplementedZero;
end;

function GetSystemWow64DirectoryW(lpBuffer: PWideChar; uSize: UINT): UINT; stdcall;
begin
  if GetKernel32Proc(GetSystemWow64DirectoryWProc, 'GetSystemWow64DirectoryW') then
    Result := TFnPtrUintUint(GetSystemWow64DirectoryWProc)(lpBuffer, uSize)
  else
    Result := NotImplementedZero;
end;

function Wow64DisableWow64FsRedirection(out OldValue: Pointer): BOOL; stdcall;
begin
  if GetKernel32Proc(Wow64DisableWow64FsRedirectionProc, 'Wow64DisableWow64FsRedirection') then
    Result := TFnVarPtrBool(Wow64DisableWow64FsRedirectionProc)(OldValue)
  else
  begin
    OldValue := nil;
    Result := NotImplemented;
  end;
end;

function Wow64RevertWow64FsRedirection(OlValue: Pointer): BOOL; stdcall;
begin
  if GetKernel32Proc(Wow64RevertWow64FsRedirectionProc, 'Wow64RevertWow64FsRedirection') then
    Result := TFnPtrBool(Wow64RevertWow64FsRedirectionProc)(OlValue)
  else
    Result := NotImplemented;
end;

function GetFirmwareType(out FirmwareType: FIRMWARE_TYPE): BOOL; stdcall;
begin
  if GetKernel32Proc(GetFirmwareTypeProc, 'GetFirmwareType') then
    Result := TFnGetFirmwareType(GetFirmwareTypeProc)(FirmwareType)
  else
  begin
    FirmwareType := FirmwareTypeUnknown;
    Result := NotImplemented;
  end;
end;

function GetComputerNameEx(NameType: COMPUTER_NAME_FORMAT; lpBuffer: PChar;
  var nSize: DWORD): BOOL; stdcall;
begin
  Result := GetComputerNameExA(NameType, lpBuffer, nSize);
end;

function GetComputerNameExA(NameType: COMPUTER_NAME_FORMAT; lpBuffer: PAnsiChar;
  var nSize: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetComputerNameExAProc, 'GetComputerNameExA') then
    Result := TFnGetComputerNameEx(GetComputerNameExAProc)(NameType, lpBuffer, nSize)
  else
    Result := NotImplemented;
end;

function GetComputerNameExW(NameType: COMPUTER_NAME_FORMAT; lpBuffer: PWideChar;
  var nSize: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(GetComputerNameExWProc, 'GetComputerNameExW') then
    Result := TFnGetComputerNameEx(GetComputerNameExWProc)(NameType, lpBuffer, nSize)
  else
    Result := NotImplemented;
end;

{ ====== UI languages, locale names, formats =============================== }

type
  TFnLangId = function: LANGID; stdcall;
  TFnLangIdLangId = function(LangId: LANGID): LANGID; stdcall;
  TFnGetPreferredUILanguages = function(dwFlags: DWORD; out pulNumLanguages: ULONG;
    pwszLanguagesBuffer: PWideChar; var pcchLanguagesBuffer: ULONG): BOOL; stdcall;
  TFnSetPreferredUILanguages = function(dwFlags: DWORD; pwszLanguagesBuffer: PWideChar;
    pulNumLanguages: PULONG): BOOL; stdcall;
  TFnPtrIntInt = function(p: Pointer; i: Integer): Integer; stdcall;
  TFnPtrPtrIntInt = function(p1, p2: Pointer; i: Integer): Integer; stdcall;
  TFnEnumSystemLocalesEx = function(lpLocaleEnumProcEx: Pointer; dwFlags: DWORD;
    lParam: LPARAM; lpReserved: Pointer): BOOL; stdcall;
  PLocaleEnumBridge = ^TLocaleEnumBridge;
  TLocaleEnumBridge = record
    Proc: LOCALE_ENUMPROCEX;
    Param: LPARAM;
  end;
  TFnLCMapStringEx = function(lpLocaleName: PWideChar; dwMapFlags: DWORD; lpSrcStr: PWideChar;
    cchSrc: Integer; lpDestStr: PWideChar; cchDest: Integer; lpVersionInformation: Pointer;
    lpReserved: Pointer; sortHandle: LPARAM): Integer; stdcall;
  TFnGetDateFormatEx = function(lpLocaleName: PWideChar; dwFlags: DWORD; lpDate: PSystemTime;
    lpFormat: PWideChar; lpDateStr: PWideChar; cchDate: Integer;
    lpCalendar: PWideChar): Integer; stdcall;
  TFnGetTimeFormatEx = function(lpLocaleName: PWideChar; dwFlags: DWORD; lpTime: PSystemTime;
    lpFormat: PWideChar; lpTimeStr: PWideChar; cchTime: Integer): Integer; stdcall;
  TFnGetNumberFormatEx = function(lpLocaleName: PWideChar; dwFlags: DWORD; lpValue: PWideChar;
    lpFormat: Pointer; lpNumberStr: PWideChar; cchNumber: Integer): Integer; stdcall;
  TFnGetDurationFormatEx = function(lpLocaleName: Pointer; dwFlags: DWORD; lpDuration: PSystemTime;
    ullDuration: UInt64; lpFormat: PWideChar; lpDurationStr: PWideChar;
    cchDuration: Integer): Integer; stdcall;
  TFnFindStringOrdinal = function(dwFindStringOrdinalFlags: DWORD; lpStringSource: PWideChar;
    cchSource: Integer; lpStringValue: PWideChar; cchValue: Integer;
    bIgnoreCase: Integer): Integer; stdcall;
  TFnNormalizeString = function(NormForm: Integer; lpSrcString: PWideChar; cwSrcLength: Integer;
    lpDstString: PWideChar; cwDstLength: Integer): Integer; stdcall;
  TFnIsNormalizedString = function(NormForm: Integer; lpString: PWideChar;
    cwLength: Integer): BOOL; stdcall;

var
  GetUserDefaultUILanguageProc: Pointer;
  GetSystemDefaultUILanguageProc: Pointer;
  GetThreadUILanguageProc: Pointer;
  SetThreadUILanguageProc: Pointer;
  GetUserPreferredUILanguagesProc: Pointer;
  GetSystemPreferredUILanguagesProc: Pointer;
  GetThreadPreferredUILanguagesProc: Pointer;
  GetProcessPreferredUILanguagesProc: Pointer;
  SetThreadPreferredUILanguagesProc: Pointer;
  SetProcessPreferredUILanguagesProc: Pointer;
  GetSystemDefaultLocaleNameProc: Pointer;
  IsValidLocaleNameProc: Pointer;
  ResolveLocaleNameProc: Pointer;
  EnumSystemLocalesExProc: Pointer;
  LCMapStringExProc: Pointer;
  GetDateFormatExProc: Pointer;
  GetTimeFormatExProc: Pointer;
  GetNumberFormatExProc: Pointer;
  GetCurrencyFormatExProc: Pointer;
  GetDurationFormatExProc: Pointer;
  GetDurationFormatProc: Pointer;
  FindStringOrdinalProc: Pointer;
  NormalizeStringProc: Pointer;
  IsNormalizedStringProc: Pointer;

function GetUserDefaultUILanguage: LANGID; stdcall;
begin
  if GetKernel32Proc(GetUserDefaultUILanguageProc, 'GetUserDefaultUILanguage') then
    Result := TFnLangId(GetUserDefaultUILanguageProc)()
  else
    Result := GetUserDefaultLangID;
end;

function GetSystemDefaultUILanguage: LANGID; stdcall;
begin
  if GetKernel32Proc(GetSystemDefaultUILanguageProc, 'GetSystemDefaultUILanguage') then
    Result := TFnLangId(GetSystemDefaultUILanguageProc)()
  else
    Result := GetSystemDefaultLangID;
end;

function GetThreadUILanguage: LANGID; stdcall;
begin
  if GetKernel32Proc(GetThreadUILanguageProc, 'GetThreadUILanguage') then
    Result := TFnLangId(GetThreadUILanguageProc)()
  else
    Result := GetUserDefaultUILanguage;
end;

function SetThreadUILanguage(LangId: LANGID): LANGID; stdcall;
begin
  if GetKernel32Proc(SetThreadUILanguageProc, 'SetThreadUILanguage') then
    Result := TFnLangIdLangId(SetThreadUILanguageProc)(LangId)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := 0;
  end;
end;

function GetUserPreferredUILanguages(dwFlags: DWORD; out pulNumLanguages: ULONG;
  pwszLanguagesBuffer: PWideChar; var pcchLanguagesBuffer: ULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(GetUserPreferredUILanguagesProc, 'GetUserPreferredUILanguages') then
    Result := TFnGetPreferredUILanguages(GetUserPreferredUILanguagesProc)(dwFlags,
      pulNumLanguages, pwszLanguagesBuffer, pcchLanguagesBuffer)
  else
  begin
    pulNumLanguages := 0;
    Result := NotImplemented;
  end;
end;

function GetSystemPreferredUILanguages(dwFlags: DWORD; out pulNumLanguages: ULONG;
  pwszLanguagesBuffer: PWideChar; var pcchLanguagesBuffer: ULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(GetSystemPreferredUILanguagesProc, 'GetSystemPreferredUILanguages') then
    Result := TFnGetPreferredUILanguages(GetSystemPreferredUILanguagesProc)(dwFlags,
      pulNumLanguages, pwszLanguagesBuffer, pcchLanguagesBuffer)
  else
  begin
    pulNumLanguages := 0;
    Result := NotImplemented;
  end;
end;

function GetThreadPreferredUILanguages(dwFlags: DWORD; out pulNumLanguages: ULONG;
  pwszLanguagesBuffer: PWideChar; var pcchLanguagesBuffer: ULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(GetThreadPreferredUILanguagesProc, 'GetThreadPreferredUILanguages') then
    Result := TFnGetPreferredUILanguages(GetThreadPreferredUILanguagesProc)(dwFlags,
      pulNumLanguages, pwszLanguagesBuffer, pcchLanguagesBuffer)
  else
  begin
    pulNumLanguages := 0;
    Result := NotImplemented;
  end;
end;

function GetProcessPreferredUILanguages(dwFlags: DWORD; out pulNumLanguages: ULONG;
  pwszLanguagesBuffer: PWideChar; var pcchLanguagesBuffer: ULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(GetProcessPreferredUILanguagesProc, 'GetProcessPreferredUILanguages') then
    Result := TFnGetPreferredUILanguages(GetProcessPreferredUILanguagesProc)(dwFlags,
      pulNumLanguages, pwszLanguagesBuffer, pcchLanguagesBuffer)
  else
  begin
    pulNumLanguages := 0;
    Result := NotImplemented;
  end;
end;

function SetThreadPreferredUILanguages(dwFlags: DWORD; pwszLanguagesBuffer: PWideChar;
  pulNumLanguages: PULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(SetThreadPreferredUILanguagesProc, 'SetThreadPreferredUILanguages') then
    Result := TFnSetPreferredUILanguages(SetThreadPreferredUILanguagesProc)(dwFlags,
      pwszLanguagesBuffer, pulNumLanguages)
  else
    Result := NotImplemented;
end;

function SetProcessPreferredUILanguages(dwFlags: DWORD; pwszLanguagesBuffer: PWideChar;
  pulNumLanguages: PULONG): BOOL; stdcall;
begin
  if GetKernel32Proc(SetProcessPreferredUILanguagesProc, 'SetProcessPreferredUILanguages') then
    Result := TFnSetPreferredUILanguages(SetProcessPreferredUILanguagesProc)(dwFlags,
      pwszLanguagesBuffer, pulNumLanguages)
  else
    Result := NotImplemented;
end;

function GetSystemDefaultLocaleName(lpLocaleName: PWideChar; cchLocaleName: Integer): Integer; stdcall;
begin
  if GetKernel32Proc(GetSystemDefaultLocaleNameProc, 'GetSystemDefaultLocaleName') then
    Result := TFnPtrIntInt(GetSystemDefaultLocaleNameProc)(lpLocaleName, cchLocaleName)
  else
    Result := NotImplementedZero;
end;

function IsValidLocaleName(lpLocaleName: PWideChar): BOOL; stdcall;
begin
  if GetKernel32Proc(IsValidLocaleNameProc, 'IsValidLocaleName') then
    Result := TFnPtrBool(IsValidLocaleNameProc)(lpLocaleName)
  else
    Result := NotImplemented;
end;

function ResolveLocaleName(lpNameToResolve, lpLocaleName: PWideChar;
  cchLocaleName: Integer): Integer; stdcall;
begin
  if GetKernel32Proc(ResolveLocaleNameProc, 'ResolveLocaleName') then
    Result := TFnPtrPtrIntInt(ResolveLocaleNameProc)(lpNameToResolve, lpLocaleName, cchLocaleName)
  else
    Result := NotImplementedZero;
end;

{ Calls the caller's callback (lParam: a TLocaleEnumBridge) and returns its
  result as 0 or 1: EnumSystemLocalesEx stops on any value but TRUE (1). }
function LocaleEnumBridge(lpLocaleString: PWideChar; dwFlags: DWORD; lParam: LPARAM): Integer; stdcall;
begin
  Result := BoolArg(PLocaleEnumBridge(lParam)^.Proc(lpLocaleString, dwFlags,
    PLocaleEnumBridge(lParam)^.Param));
end;

function EnumSystemLocalesEx(lpLocaleEnumProcEx: LOCALE_ENUMPROCEX; dwFlags: DWORD;
  lParam: LPARAM; lpReserved: Pointer): BOOL; stdcall;
var
  Bridge: TLocaleEnumBridge;
begin
  if GetKernel32Proc(EnumSystemLocalesExProc, 'EnumSystemLocalesEx') then
  begin
    Bridge.Proc := lpLocaleEnumProcEx;
    Bridge.Param := lParam;
    Result := TFnEnumSystemLocalesEx(EnumSystemLocalesExProc)(@LocaleEnumBridge, dwFlags,
      Windows.LPARAM(@Bridge), lpReserved);
  end
  else
    Result := NotImplemented;
end;

function LCMapStringEx(lpLocaleName: PWideChar; dwMapFlags: DWORD; lpSrcStr: PWideChar;
  cchSrc: Integer; lpDestStr: PWideChar; cchDest: Integer; lpVersionInformation: Pointer;
  lpReserved: Pointer; sortHandle: LPARAM): Integer; stdcall;
begin
  if GetKernel32Proc(LCMapStringExProc, 'LCMapStringEx') then
    Result := TFnLCMapStringEx(LCMapStringExProc)(lpLocaleName, dwMapFlags, lpSrcStr, cchSrc,
      lpDestStr, cchDest, lpVersionInformation, lpReserved, sortHandle)
  else
    Result := NotImplementedZero;
end;

function GetDateFormatEx(lpLocaleName: PWideChar; dwFlags: DWORD; lpDate: PSystemTime;
  lpFormat: PWideChar; lpDateStr: PWideChar; cchDate: Integer;
  lpCalendar: PWideChar): Integer; stdcall;
begin
  if GetKernel32Proc(GetDateFormatExProc, 'GetDateFormatEx') then
    Result := TFnGetDateFormatEx(GetDateFormatExProc)(lpLocaleName, dwFlags, lpDate, lpFormat,
      lpDateStr, cchDate, lpCalendar)
  else
    Result := NotImplementedZero;
end;

function GetTimeFormatEx(lpLocaleName: PWideChar; dwFlags: DWORD; lpTime: PSystemTime;
  lpFormat: PWideChar; lpTimeStr: PWideChar; cchTime: Integer): Integer; stdcall;
begin
  if GetKernel32Proc(GetTimeFormatExProc, 'GetTimeFormatEx') then
    Result := TFnGetTimeFormatEx(GetTimeFormatExProc)(lpLocaleName, dwFlags, lpTime, lpFormat,
      lpTimeStr, cchTime)
  else
    Result := NotImplementedZero;
end;

function GetNumberFormatEx(lpLocaleName: PWideChar; dwFlags: DWORD; lpValue: PWideChar;
  lpFormat: PNumberFmtW; lpNumberStr: PWideChar; cchNumber: Integer): Integer; stdcall;
begin
  if GetKernel32Proc(GetNumberFormatExProc, 'GetNumberFormatEx') then
    Result := TFnGetNumberFormatEx(GetNumberFormatExProc)(lpLocaleName, dwFlags, lpValue,
      lpFormat, lpNumberStr, cchNumber)
  else
    Result := NotImplementedZero;
end;

function GetCurrencyFormatEx(lpLocaleName: PWideChar; dwFlags: DWORD; lpValue: PWideChar;
  lpFormat: PCurrencyFmtW; lpCurrencyStr: PWideChar; cchCurrency: Integer): Integer; stdcall;
begin
  if GetKernel32Proc(GetCurrencyFormatExProc, 'GetCurrencyFormatEx') then
    Result := TFnGetNumberFormatEx(GetCurrencyFormatExProc)(lpLocaleName, dwFlags, lpValue,
      lpFormat, lpCurrencyStr, cchCurrency)
  else
    Result := NotImplementedZero;
end;

function GetDurationFormatEx(lpLocaleName: PWideChar; dwFlags: DWORD; lpDuration: PSystemTime;
  ullDuration: UInt64; lpFormat: PWideChar; lpDurationStr: PWideChar;
  cchDuration: Integer): Integer; stdcall;
begin
  if GetKernel32Proc(GetDurationFormatExProc, 'GetDurationFormatEx') then
    Result := TFnGetDurationFormatEx(GetDurationFormatExProc)(lpLocaleName, dwFlags, lpDuration,
      ullDuration, lpFormat, lpDurationStr, cchDuration)
  else
    Result := NotImplementedZero;
end;

function GetDurationFormat(Locale: LCID; dwFlags: DWORD; lpDuration: PSystemTime;
  ullDuration: UInt64; lpFormat: PWideChar; lpDurationStr: PWideChar;
  cchDuration: Integer): Integer; stdcall;
begin
  if GetKernel32Proc(GetDurationFormatProc, 'GetDurationFormat') then
    Result := TFnGetDurationFormatEx(GetDurationFormatProc)(Pointer(Locale), dwFlags, lpDuration,
      ullDuration, lpFormat, lpDurationStr, cchDuration)
  else
    Result := NotImplementedZero;
end;

function FindStringOrdinal(dwFindStringOrdinalFlags: DWORD; lpStringSource: PWideChar;
  cchSource: Integer; lpStringValue: PWideChar; cchValue: Integer;
  bIgnoreCase: BOOL): Integer; stdcall;
begin
  if GetKernel32Proc(FindStringOrdinalProc, 'FindStringOrdinal') then
    Result := TFnFindStringOrdinal(FindStringOrdinalProc)(dwFindStringOrdinalFlags,
      lpStringSource, cchSource, lpStringValue, cchValue, BoolArg(bIgnoreCase))
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := -1;
  end;
end;

function NormalizeString(NormForm: NORM_FORM; lpSrcString: PWideChar; cwSrcLength: Integer;
  lpDstString: PWideChar; cwDstLength: Integer): Integer; stdcall;
begin
  if GetKernel32Proc(NormalizeStringProc, 'NormalizeString') then
    Result := TFnNormalizeString(NormalizeStringProc)(NormForm, lpSrcString, cwSrcLength,
      lpDstString, cwDstLength)
  else
    Result := NotImplementedZero;
end;

function IsNormalizedString(NormForm: NORM_FORM; lpString: PWideChar;
  cwLength: Integer): BOOL; stdcall;
begin
  if GetKernel32Proc(IsNormalizedStringProc, 'IsNormalizedString') then
    Result := TFnIsNormalizedString(IsNormalizedStringProc)(NormForm, lpString, cwLength)
  else
    Result := NotImplemented;
end;

{ ====== Time zones ======================================================== }

type
  TFnGetDynamicTimeZoneInformation = function(
    out pTimeZoneInformation: TDynamicTimeZoneInformation): DWORD; stdcall;
  TFnGetTimeZoneInformationForYear = function(wYear: Word; pdtzi: PDynamicTimeZoneInformation;
    out ptzi: TTimeZoneInformation): BOOL; stdcall;
  TFnTzConvert = function(lpTimeZoneInformation: Pointer; lpTime: PSystemTime;
    out lpResult: TSystemTime): BOOL; stdcall;
  TFnEnumDynamicTimeZoneInformation = function(dwIndex: DWORD;
    out lpTimeZoneInformation: TDynamicTimeZoneInformation): DWORD; stdcall;
  TFnGetDynamicTimeZoneInformationEffectiveYears = function(
    lpTimeZoneInformation: PDynamicTimeZoneInformation; out FirstYear, LastYear: DWORD): DWORD; stdcall;

var
  GetDynamicTimeZoneInformationProc: Pointer;
  GetTimeZoneInformationForYearProc: Pointer;
  TzSpecificLocalTimeToSystemTimeProc: Pointer;
  TzSpecificLocalTimeToSystemTimeExProc: Pointer;
  SystemTimeToTzSpecificLocalTimeExProc: Pointer;
  EnumDynamicTimeZoneInformationProc: Pointer;
  GetDynamicTimeZoneInformationEffectiveYearsProc: Pointer;

function GetDynamicTimeZoneInformation(
  out pTimeZoneInformation: TDynamicTimeZoneInformation): DWORD; stdcall;
var
  Info: TTimeZoneInformation;
begin
  if GetKernel32Proc(GetDynamicTimeZoneInformationProc, 'GetDynamicTimeZoneInformation') then
    Result := TFnGetDynamicTimeZoneInformation(GetDynamicTimeZoneInformationProc)(
      pTimeZoneInformation)
  else
  begin
    { TIME_ZONE_INFORMATION is the first part of DYNAMIC_TIME_ZONE_INFORMATION }
    FillChar(pTimeZoneInformation, SizeOf(pTimeZoneInformation), 0);
    Result := GetTimeZoneInformation(Info);
    Move(Info, pTimeZoneInformation, SizeOf(Info));
  end;
end;

function GetTimeZoneInformationForYear(wYear: Word; pdtzi: PDynamicTimeZoneInformation;
  out ptzi: TTimeZoneInformation): BOOL; stdcall;
begin
  if GetKernel32Proc(GetTimeZoneInformationForYearProc, 'GetTimeZoneInformationForYear') then
    Result := TFnGetTimeZoneInformationForYear(GetTimeZoneInformationForYearProc)(wYear, pdtzi,
      ptzi)
  else
    Result := NotImplemented;
end;

function TzSpecificLocalTimeToSystemTime(lpTimeZoneInformation: PTimeZoneInformation;
  const lpLocalTime: TSystemTime; out lpUniversalTime: TSystemTime): BOOL; stdcall;
begin
  if GetKernel32Proc(TzSpecificLocalTimeToSystemTimeProc, 'TzSpecificLocalTimeToSystemTime') then
    Result := TFnTzConvert(TzSpecificLocalTimeToSystemTimeProc)(lpTimeZoneInformation,
      @lpLocalTime, lpUniversalTime)
  else
    Result := NotImplemented;
end;

function TzSpecificLocalTimeToSystemTimeEx(lpTimeZoneInformation: PDynamicTimeZoneInformation;
  const lpLocalTime: TSystemTime; out lpUniversalTime: TSystemTime): BOOL; stdcall;
begin
  if GetKernel32Proc(TzSpecificLocalTimeToSystemTimeExProc,
    'TzSpecificLocalTimeToSystemTimeEx') then
    Result := TFnTzConvert(TzSpecificLocalTimeToSystemTimeExProc)(lpTimeZoneInformation,
      @lpLocalTime, lpUniversalTime)
  else
    Result := NotImplemented;
end;

function SystemTimeToTzSpecificLocalTimeEx(lpTimeZoneInformation: PDynamicTimeZoneInformation;
  const lpUniversalTime: TSystemTime; out lpLocalTime: TSystemTime): BOOL; stdcall;
begin
  if GetKernel32Proc(SystemTimeToTzSpecificLocalTimeExProc,
    'SystemTimeToTzSpecificLocalTimeEx') then
    Result := TFnTzConvert(SystemTimeToTzSpecificLocalTimeExProc)(lpTimeZoneInformation,
      @lpUniversalTime, lpLocalTime)
  else
    Result := NotImplemented;
end;

function EnumDynamicTimeZoneInformation(dwIndex: DWORD;
  out lpTimeZoneInformation: TDynamicTimeZoneInformation): DWORD; stdcall;
begin
  if GetAdvapi32Proc(EnumDynamicTimeZoneInformationProc, 'EnumDynamicTimeZoneInformation') then
    Result := TFnEnumDynamicTimeZoneInformation(EnumDynamicTimeZoneInformationProc)(dwIndex,
      lpTimeZoneInformation)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function GetDynamicTimeZoneInformationEffectiveYears(
  const lpTimeZoneInformation: TDynamicTimeZoneInformation;
  out FirstYear, LastYear: DWORD): DWORD; stdcall;
begin
  if GetAdvapi32Proc(GetDynamicTimeZoneInformationEffectiveYearsProc,
    'GetDynamicTimeZoneInformationEffectiveYears') then
    Result := TFnGetDynamicTimeZoneInformationEffectiveYears(
      GetDynamicTimeZoneInformationEffectiveYearsProc)(@lpTimeZoneInformation, FirstYear, LastYear)
  else
  begin
    FirstYear := 0;
    LastYear := 0;
    Result := ERROR_CALL_NOT_IMPLEMENTED;
  end;
end;

{ ====== Application restart and recovery ================================== }

type
  TFnPtrDwordHResult = function(p: Pointer; dw: DWORD): HRESULT; stdcall;
  TFnGetApplicationRestartSettings = function(hProcess: THandle; pwzCommandline: PWideChar;
    var pcchSize: DWORD; pdwFlags: PDWORD): HRESULT; stdcall;
  TFnRegisterApplicationRecoveryCallback = function(pRecoveyCallback: Pointer;
    pvParameter: Pointer; dwPingInterval: DWORD; dwFlags: DWORD): HRESULT; stdcall;
  TFnApplicationRecoveryInProgress = function(out pbCancelled: BOOL): HRESULT; stdcall;
  TFnIntProc = procedure(i: Integer); stdcall;

var
  RegisterApplicationRestartProc: Pointer;
  UnregisterApplicationRestartProc: Pointer;
  GetApplicationRestartSettingsProc: Pointer;
  RegisterApplicationRecoveryCallbackProc: Pointer;
  UnregisterApplicationRecoveryCallbackProc: Pointer;
  ApplicationRecoveryInProgressProc: Pointer;
  ApplicationRecoveryFinishedProc: Pointer;

function RegisterApplicationRestart(pwzCommandline: PWideChar; dwFlags: DWORD): HRESULT; stdcall;
begin
  if GetKernel32Proc(RegisterApplicationRestartProc, 'RegisterApplicationRestart') then
    Result := TFnPtrDwordHResult(RegisterApplicationRestartProc)(pwzCommandline, dwFlags)
  else
    Result := E_NOTIMPL;
end;

function UnregisterApplicationRestart: HRESULT; stdcall;
begin
  if GetKernel32Proc(UnregisterApplicationRestartProc, 'UnregisterApplicationRestart') then
    Result := TFnHResult(UnregisterApplicationRestartProc)()
  else
    Result := E_NOTIMPL;
end;

function GetApplicationRestartSettings(hProcess: THandle; pwzCommandline: PWideChar;
  var pcchSize: DWORD; pdwFlags: PDWORD): HRESULT; stdcall;
begin
  if GetKernel32Proc(GetApplicationRestartSettingsProc, 'GetApplicationRestartSettings') then
    Result := TFnGetApplicationRestartSettings(GetApplicationRestartSettingsProc)(hProcess,
      pwzCommandline, pcchSize, pdwFlags)
  else
    Result := E_NOTIMPL;
end;

function RegisterApplicationRecoveryCallback(pRecoveyCallback: APPLICATION_RECOVERY_CALLBACK;
  pvParameter: Pointer; dwPingInterval: DWORD; dwFlags: DWORD): HRESULT; stdcall;
begin
  if GetKernel32Proc(RegisterApplicationRecoveryCallbackProc,
    'RegisterApplicationRecoveryCallback') then
    Result := TFnRegisterApplicationRecoveryCallback(RegisterApplicationRecoveryCallbackProc)(
      @pRecoveyCallback, pvParameter, dwPingInterval, dwFlags)
  else
    Result := E_NOTIMPL;
end;

function UnregisterApplicationRecoveryCallback: HRESULT; stdcall;
begin
  if GetKernel32Proc(UnregisterApplicationRecoveryCallbackProc,
    'UnregisterApplicationRecoveryCallback') then
    Result := TFnHResult(UnregisterApplicationRecoveryCallbackProc)()
  else
    Result := E_NOTIMPL;
end;

function ApplicationRecoveryInProgress(out pbCancelled: BOOL): HRESULT; stdcall;
begin
  if GetKernel32Proc(ApplicationRecoveryInProgressProc, 'ApplicationRecoveryInProgress') then
    Result := TFnApplicationRecoveryInProgress(ApplicationRecoveryInProgressProc)(pbCancelled)
  else
  begin
    pbCancelled := False;
    Result := E_NOTIMPL;
  end;
end;

procedure ApplicationRecoveryFinished(bSuccess: BOOL); stdcall;
begin
  if GetKernel32Proc(ApplicationRecoveryFinishedProc, 'ApplicationRecoveryFinished') then
    TFnIntProc(ApplicationRecoveryFinishedProc)(BoolArg(bSuccess));
end;

{ ====== Debugging, exceptions, modules ==================================== }

type
  TFnAddVectoredHandler = function(First: ULONG; Handler: Pointer): Pointer; stdcall;
  TFnCheckRemoteDebuggerPresent = function(hProcess: THandle;
    out pbDebuggerPresent: BOOL): BOOL; stdcall;
  TFnIntBool = function(i: Integer): BOOL; stdcall;
  TFnRtlCaptureStackBackTrace = function(FramesToSkip, FramesToCapture: DWORD;
    BackTrace: PPointer; BackTraceHash: PDWORD): Word; stdcall;
  TFnGetModuleHandleEx = function(dwFlags: DWORD; lpModuleName: Pointer;
    out phModule: HMODULE): BOOL; stdcall;

var
  AddVectoredExceptionHandlerProc: Pointer;
  RemoveVectoredExceptionHandlerProc: Pointer;
  AddVectoredContinueHandlerProc: Pointer;
  RemoveVectoredContinueHandlerProc: Pointer;
  IsDebuggerPresentProc: Pointer;
  CheckRemoteDebuggerPresentProc: Pointer;
  DebugBreakProcessProc: Pointer;
  DebugActiveProcessStopProc: Pointer;
  DebugSetProcessKillOnExitProc: Pointer;
  RtlCaptureStackBackTraceProc: Pointer;
  EncodePointerProc: Pointer;
  DecodePointerProc: Pointer;
  GetModuleHandleExAProc: Pointer;
  GetModuleHandleExWProc: Pointer;

function AddVectoredExceptionHandler(First: ULONG; Handler: PVECTORED_EXCEPTION_HANDLER): Pointer; stdcall;
begin
  if GetKernel32Proc(AddVectoredExceptionHandlerProc, 'AddVectoredExceptionHandler') then
    Result := TFnAddVectoredHandler(AddVectoredExceptionHandlerProc)(First, @Handler)
  else
    Result := Pointer(NotImplementedZero);
end;

function RemoveVectoredExceptionHandler(Handle: Pointer): ULONG; stdcall;
begin
  if GetKernel32Proc(RemoveVectoredExceptionHandlerProc, 'RemoveVectoredExceptionHandler') then
    Result := TFnPtrDword(RemoveVectoredExceptionHandlerProc)(Handle)
  else
    Result := NotImplementedZero;
end;

function AddVectoredContinueHandler(First: ULONG; Handler: PVECTORED_EXCEPTION_HANDLER): Pointer; stdcall;
begin
  if GetKernel32Proc(AddVectoredContinueHandlerProc, 'AddVectoredContinueHandler') then
    Result := TFnAddVectoredHandler(AddVectoredContinueHandlerProc)(First, @Handler)
  else
    Result := Pointer(NotImplementedZero);
end;

function RemoveVectoredContinueHandler(Handle: Pointer): ULONG; stdcall;
begin
  if GetKernel32Proc(RemoveVectoredContinueHandlerProc, 'RemoveVectoredContinueHandler') then
    Result := TFnPtrDword(RemoveVectoredContinueHandlerProc)(Handle)
  else
    Result := NotImplementedZero;
end;

function IsDebuggerPresent: BOOL; stdcall;
begin
  if GetKernel32Proc(IsDebuggerPresentProc, 'IsDebuggerPresent') then
    Result := TFnBool(IsDebuggerPresentProc)()
  else
    Result := NotImplemented;
end;

function CheckRemoteDebuggerPresent(hProcess: THandle; out pbDebuggerPresent: BOOL): BOOL; stdcall;
begin
  if GetKernel32Proc(CheckRemoteDebuggerPresentProc, 'CheckRemoteDebuggerPresent') then
    Result := TFnCheckRemoteDebuggerPresent(CheckRemoteDebuggerPresentProc)(hProcess,
      pbDebuggerPresent)
  else
  begin
    pbDebuggerPresent := False;
    Result := NotImplemented;
  end;
end;

function DebugBreakProcess(Process: THandle): BOOL; stdcall;
begin
  if GetKernel32Proc(DebugBreakProcessProc, 'DebugBreakProcess') then
    Result := TFnHandleBool(DebugBreakProcessProc)(Process)
  else
    Result := NotImplemented;
end;

function DebugActiveProcessStop(dwProcessId: DWORD): BOOL; stdcall;
begin
  if GetKernel32Proc(DebugActiveProcessStopProc, 'DebugActiveProcessStop') then
    Result := TFnDwordBool(DebugActiveProcessStopProc)(dwProcessId)
  else
    Result := NotImplemented;
end;

function DebugSetProcessKillOnExit(KillOnExit: BOOL): BOOL; stdcall;
begin
  if GetKernel32Proc(DebugSetProcessKillOnExitProc, 'DebugSetProcessKillOnExit') then
    Result := TFnIntBool(DebugSetProcessKillOnExitProc)(BoolArg(KillOnExit))
  else
    Result := NotImplemented;
end;

function RtlCaptureStackBackTrace(FramesToSkip, FramesToCapture: DWORD; BackTrace: PPointer;
  BackTraceHash: PDWORD): Word; stdcall;
begin
  if GetKernel32Proc(RtlCaptureStackBackTraceProc, 'RtlCaptureStackBackTrace') then
    Result := TFnRtlCaptureStackBackTrace(RtlCaptureStackBackTraceProc)(FramesToSkip + 1,
      FramesToCapture, BackTrace, BackTraceHash)
  else
    Result := 0;
end;

function EncodePointer(Ptr: Pointer): Pointer; stdcall;
begin
  if GetKernel32Proc(EncodePointerProc, 'EncodePointer') then
    Result := TFnPtrPtr(EncodePointerProc)(Ptr)
  else
    Result := Ptr;
end;

function DecodePointer(Ptr: Pointer): Pointer; stdcall;
begin
  if GetKernel32Proc(DecodePointerProc, 'DecodePointer') then
    Result := TFnPtrPtr(DecodePointerProc)(Ptr)
  else
    Result := Ptr;
end;

function GetModuleHandleEx(dwFlags: DWORD; lpModuleName: PChar; out phModule: HMODULE): BOOL; stdcall;
begin
  Result := GetModuleHandleExA(dwFlags, lpModuleName, phModule);
end;

function GetModuleHandleExA(dwFlags: DWORD; lpModuleName: PAnsiChar; out phModule: HMODULE): BOOL; stdcall;
begin
  if GetKernel32Proc(GetModuleHandleExAProc, 'GetModuleHandleExA') then
    Result := TFnGetModuleHandleEx(GetModuleHandleExAProc)(dwFlags, lpModuleName, phModule)
  else
  begin
    phModule := 0;
    Result := NotImplemented;
  end;
end;

function GetModuleHandleExW(dwFlags: DWORD; lpModuleName: PWideChar; out phModule: HMODULE): BOOL; stdcall;
begin
  if GetKernel32Proc(GetModuleHandleExWProc, 'GetModuleHandleExW') then
    Result := TFnGetModuleHandleEx(GetModuleHandleExWProc)(dwFlags, lpModuleName, phModule)
  else
  begin
    phModule := 0;
    Result := NotImplemented;
  end;
end;

{ ====== Power notifications =============================================== }

type
  TFnRegisterPowerSettingNotification = function(hRecipient: THandle; PowerSettingGuid: PGUID;
    Flags: DWORD): HPOWERNOTIFY; stdcall;
  TFnRegisterSuspendResumeNotification = function(hRecipient: THandle;
    Flags: DWORD): HPOWERNOTIFY; stdcall;

var
  RegisterPowerSettingNotificationProc: Pointer;
  UnregisterPowerSettingNotificationProc: Pointer;
  RegisterSuspendResumeNotificationProc: Pointer;
  UnregisterSuspendResumeNotificationProc: Pointer;

function RegisterPowerSettingNotification(hRecipient: THandle; const PowerSettingGuid: TGUID;
  Flags: DWORD): HPOWERNOTIFY; stdcall;
begin
  if GetUser32Proc(RegisterPowerSettingNotificationProc, 'RegisterPowerSettingNotification') then
    Result := TFnRegisterPowerSettingNotification(RegisterPowerSettingNotificationProc)(
      hRecipient, @PowerSettingGuid, Flags)
  else
    Result := Pointer(NotImplementedZero);
end;

function UnregisterPowerSettingNotification(Handle: HPOWERNOTIFY): BOOL; stdcall;
begin
  if GetUser32Proc(UnregisterPowerSettingNotificationProc,
    'UnregisterPowerSettingNotification') then
    Result := TFnPtrBool(UnregisterPowerSettingNotificationProc)(Handle)
  else
    Result := NotImplemented;
end;

function RegisterSuspendResumeNotification(hRecipient: THandle; Flags: DWORD): HPOWERNOTIFY; stdcall;
begin
  if GetUser32Proc(RegisterSuspendResumeNotificationProc, 'RegisterSuspendResumeNotification') then
    Result := TFnRegisterSuspendResumeNotification(RegisterSuspendResumeNotificationProc)(
      hRecipient, Flags)
  else
    Result := Pointer(NotImplementedZero);
end;

function UnregisterSuspendResumeNotification(Handle: HPOWERNOTIFY): BOOL; stdcall;
begin
  if GetUser32Proc(UnregisterSuspendResumeNotificationProc,
    'UnregisterSuspendResumeNotification') then
    Result := TFnPtrBool(UnregisterSuspendResumeNotificationProc)(Handle)
  else
    Result := NotImplemented;
end;

{ ====== Raw input ========================================================= }

type
  TFnRegisterRawInputDevices = function(pRawInputDevices: PRawInputDevice; uiNumDevices: UINT;
    cbSize: UINT): BOOL; stdcall;
  TFnGetRawInputData = function(hRawInput: HRAWINPUT; uiCommand: UINT; pData: Pointer;
    var pcbSize: UINT; cbSizeHeader: UINT): UINT; stdcall;
  TFnGetRawInputList = function(pList: Pointer; var puiNum: UINT; cbSize: UINT): UINT; stdcall;
  TFnGetRawInputDeviceInfo = function(hDevice: THandle; uiCommand: UINT; pData: Pointer;
    var pcbSize: UINT): UINT; stdcall;
  TFnDefRawInputProc = function(paRawInput: PPRawInput; nInput: Integer;
    cbSizeHeader: UINT): LRESULT; stdcall;

var
  RegisterRawInputDevicesProc: Pointer;
  GetRawInputDataProc: Pointer;
  GetRawInputDeviceListProc: Pointer;
  GetRawInputDeviceInfoAProc: Pointer;
  GetRawInputDeviceInfoWProc: Pointer;
  GetRegisteredRawInputDevicesProc: Pointer;
  GetRawInputBufferProc: Pointer;
  DefRawInputProcProc: Pointer;

{ UINT(-1) after SetLastError(ERROR_CALL_NOT_IMPLEMENTED): the error result
  of the raw input functions. }
function RawInputNotImplemented: UINT;
begin
  SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
  Result := UINT(-1);
end;

function RegisterRawInputDevices(pRawInputDevices: PRawInputDevice; uiNumDevices: UINT;
  cbSize: UINT): BOOL; stdcall;
begin
  if GetUser32Proc(RegisterRawInputDevicesProc, 'RegisterRawInputDevices') then
    Result := TFnRegisterRawInputDevices(RegisterRawInputDevicesProc)(pRawInputDevices,
      uiNumDevices, cbSize)
  else
    Result := NotImplemented;
end;

function GetRawInputData(hRawInput: HRAWINPUT; uiCommand: UINT; pData: Pointer;
  var pcbSize: UINT; cbSizeHeader: UINT): UINT; stdcall;
begin
  if GetUser32Proc(GetRawInputDataProc, 'GetRawInputData') then
    Result := TFnGetRawInputData(GetRawInputDataProc)(hRawInput, uiCommand, pData, pcbSize,
      cbSizeHeader)
  else
    Result := RawInputNotImplemented;
end;

function GetRawInputDeviceList(pRawInputDeviceList: PRawInputDeviceList;
  var puiNumDevices: UINT; cbSize: UINT): UINT; stdcall;
begin
  if GetUser32Proc(GetRawInputDeviceListProc, 'GetRawInputDeviceList') then
    Result := TFnGetRawInputList(GetRawInputDeviceListProc)(pRawInputDeviceList, puiNumDevices,
      cbSize)
  else
    Result := RawInputNotImplemented;
end;

function GetRawInputDeviceInfo(hDevice: THandle; uiCommand: UINT; pData: Pointer;
  var pcbSize: UINT): UINT; stdcall;
begin
  Result := GetRawInputDeviceInfoA(hDevice, uiCommand, pData, pcbSize);
end;

function GetRawInputDeviceInfoA(hDevice: THandle; uiCommand: UINT; pData: Pointer;
  var pcbSize: UINT): UINT; stdcall;
begin
  if GetUser32Proc(GetRawInputDeviceInfoAProc, 'GetRawInputDeviceInfoA') then
    Result := TFnGetRawInputDeviceInfo(GetRawInputDeviceInfoAProc)(hDevice, uiCommand, pData,
      pcbSize)
  else
    Result := RawInputNotImplemented;
end;

function GetRawInputDeviceInfoW(hDevice: THandle; uiCommand: UINT; pData: Pointer;
  var pcbSize: UINT): UINT; stdcall;
begin
  if GetUser32Proc(GetRawInputDeviceInfoWProc, 'GetRawInputDeviceInfoW') then
    Result := TFnGetRawInputDeviceInfo(GetRawInputDeviceInfoWProc)(hDevice, uiCommand, pData,
      pcbSize)
  else
    Result := RawInputNotImplemented;
end;

function GetRegisteredRawInputDevices(pRawInputDevices: PRawInputDevice;
  var puiNumDevices: UINT; cbSize: UINT): UINT; stdcall;
begin
  if GetUser32Proc(GetRegisteredRawInputDevicesProc, 'GetRegisteredRawInputDevices') then
    Result := TFnGetRawInputList(GetRegisteredRawInputDevicesProc)(pRawInputDevices,
      puiNumDevices, cbSize)
  else
    Result := RawInputNotImplemented;
end;

function GetRawInputBuffer(pData: PRawInput; var pcbSize: UINT; cbSizeHeader: UINT): UINT; stdcall;
begin
  if GetUser32Proc(GetRawInputBufferProc, 'GetRawInputBuffer') then
    Result := TFnGetRawInputList(GetRawInputBufferProc)(pData, pcbSize, cbSizeHeader)
  else
    Result := RawInputNotImplemented;
end;

function DefRawInputProc(paRawInput: PPRawInput; nInput: Integer;
  cbSizeHeader: UINT): LRESULT; stdcall;
begin
  if GetUser32Proc(DefRawInputProcProc, 'DefRawInputProc') then
    Result := TFnDefRawInputProc(DefRawInputProcProc)(paRawInput, nInput, cbSizeHeader)
  else
    Result := 0;
end;

function GET_RAWINPUT_CODE_WPARAM(wParam: WPARAM): DWORD;
begin
  Result := DWORD(wParam) and $FF;
end;

function NEXTRAWINPUTBLOCK(ptr: PRawInput): PRawInput;
begin
  Result := PRawInput((Cardinal(ptr) + ptr^.header.dwSize + SizeOf(DWORD) - 1) and
    not Cardinal(SizeOf(DWORD) - 1));
end;

{ ====== Windows, layered windows, printing ================================ }

type
  TFnHwndHdcUintBool = function(hwnd: HWND; dc: HDC; n: UINT): BOOL; stdcall;
  TFnGetLayeredWindowAttributes = function(hwnd: HWND; pcrKey: PDWORD; pbAlpha: PByte;
    pdwFlags: PDWORD): BOOL; stdcall;
  TFnHwnd = function: HWND; stdcall;
  TFnGetUpdatedClipboardFormats = function(lpuiFormats: PUINT; cFormats: UINT;
    out pcFormatsOut: UINT): BOOL; stdcall;
  TFnGetWindowRgnBox = function(hWnd: HWND; out lprc: TRect): Integer; stdcall;
  TFnGetIconInfoEx = function(hicon: HICON; piconinfo: Pointer): BOOL; stdcall;
  TFnVarDwordBool = function(out dw: DWORD): BOOL; stdcall;
  TFnHdcDword = function(dc: HDC): DWORD; stdcall;
  TFnHdcDwordDword = function(dc: HDC; dw: DWORD): DWORD; stdcall;
  TFnGetRandomRgn = function(dc: HDC; rgn: HRGN; i: Integer): Integer; stdcall;
  TFnEnumDisplaySettingsEx = function(lpszDeviceName: Pointer; iModeNum: DWORD;
    lpDevMode: Pointer; dwFlags: DWORD): BOOL; stdcall;

var
  PrintWindowProc: Pointer;
  UpdateLayeredWindowIndirectProc: Pointer;
  GetLayeredWindowAttributesProc: Pointer;
  AllowSetForegroundWindowProc: Pointer;
  LockSetForegroundWindowProc: Pointer;
  BlockInputProc: Pointer;
  IsHungAppWindowProc: Pointer;
  GetShellWindowProc: Pointer;
  RegisterShellHookWindowProc: Pointer;
  DeregisterShellHookWindowProc: Pointer;
  DisableProcessWindowsGhostingProc: Pointer;
  IsGUIThreadProc: Pointer;
  GetUpdatedClipboardFormatsProc: Pointer;
  GetWindowRgnBoxProc: Pointer;
  GetIconInfoExAProc: Pointer;
  GetIconInfoExWProc: Pointer;
  GetProcessDefaultLayoutProc: Pointer;
  SetProcessDefaultLayoutProc: Pointer;
  GetLayoutProc: Pointer;
  SetLayoutProc: Pointer;
  GetRandomRgnProc: Pointer;
  EnumDisplaySettingsExAProc: Pointer;
  EnumDisplaySettingsExWProc: Pointer;

function PrintWindow(hwnd: HWND; hdcBlt: HDC; nFlags: UINT): BOOL; stdcall;
begin
  if GetUser32Proc(PrintWindowProc, 'PrintWindow') then
    Result := TFnHwndHdcUintBool(PrintWindowProc)(hwnd, hdcBlt, nFlags)
  else
    Result := NotImplemented;
end;

function UpdateLayeredWindowIndirect(hWnd: HWND;
  const pULWInfo: TUpdateLayeredWindowInfo): BOOL; stdcall;
begin
  if GetUser32Proc(UpdateLayeredWindowIndirectProc, 'UpdateLayeredWindowIndirect') then
    Result := TFnHwndPtrBool(UpdateLayeredWindowIndirectProc)(hWnd, @pULWInfo)
  else
    Result := NotImplemented;
end;

function GetLayeredWindowAttributes(hwnd: HWND; pcrKey: PDWORD; pbAlpha: PByte;
  pdwFlags: PDWORD): BOOL; stdcall;
begin
  if GetUser32Proc(GetLayeredWindowAttributesProc, 'GetLayeredWindowAttributes') then
    Result := TFnGetLayeredWindowAttributes(GetLayeredWindowAttributesProc)(hwnd, pcrKey, pbAlpha,
      pdwFlags)
  else
    Result := NotImplemented;
end;

function AllowSetForegroundWindow(dwProcessId: DWORD): BOOL; stdcall;
begin
  if GetUser32Proc(AllowSetForegroundWindowProc, 'AllowSetForegroundWindow') then
    Result := TFnDwordBool(AllowSetForegroundWindowProc)(dwProcessId)
  else
    Result := NotImplemented;
end;

function LockSetForegroundWindow(uLockCode: UINT): BOOL; stdcall;
begin
  if GetUser32Proc(LockSetForegroundWindowProc, 'LockSetForegroundWindow') then
    Result := TFnDwordBool(LockSetForegroundWindowProc)(uLockCode)
  else
    Result := NotImplemented;
end;

function BlockInput(fBlockIt: BOOL): BOOL; stdcall;
begin
  if GetUser32Proc(BlockInputProc, 'BlockInput') then
    Result := TFnDwordBool(BlockInputProc)(BoolArg(fBlockIt))
  else
    Result := NotImplemented;
end;

function IsHungAppWindow(hwnd: HWND): BOOL; stdcall;
begin
  if GetUser32Proc(IsHungAppWindowProc, 'IsHungAppWindow') then
    Result := TFnHwndBool(IsHungAppWindowProc)(hwnd)
  else
    Result := NotImplemented;
end;

function GetShellWindow: HWND; stdcall;
begin
  if GetUser32Proc(GetShellWindowProc, 'GetShellWindow') then
    Result := TFnHwnd(GetShellWindowProc)()
  else
    Result := 0;
end;

function RegisterShellHookWindow(hwnd: HWND): BOOL; stdcall;
begin
  if GetUser32Proc(RegisterShellHookWindowProc, 'RegisterShellHookWindow') then
    Result := TFnHwndBool(RegisterShellHookWindowProc)(hwnd)
  else
    Result := NotImplemented;
end;

function DeregisterShellHookWindow(hwnd: HWND): BOOL; stdcall;
begin
  if GetUser32Proc(DeregisterShellHookWindowProc, 'DeregisterShellHookWindow') then
    Result := TFnHwndBool(DeregisterShellHookWindowProc)(hwnd)
  else
    Result := NotImplemented;
end;

procedure DisableProcessWindowsGhosting; stdcall;
begin
  if GetUser32Proc(DisableProcessWindowsGhostingProc, 'DisableProcessWindowsGhosting') then
    TFnVoid(DisableProcessWindowsGhostingProc)();
end;

function IsGUIThread(bConvert: BOOL): BOOL; stdcall;
begin
  if GetUser32Proc(IsGUIThreadProc, 'IsGUIThread') then
    Result := TFnDwordBool(IsGUIThreadProc)(BoolArg(bConvert))
  else
    Result := NotImplemented;
end;

function GetUpdatedClipboardFormats(lpuiFormats: PUINT; cFormats: UINT;
  out pcFormatsOut: UINT): BOOL; stdcall;
begin
  if GetUser32Proc(GetUpdatedClipboardFormatsProc, 'GetUpdatedClipboardFormats') then
    Result := TFnGetUpdatedClipboardFormats(GetUpdatedClipboardFormatsProc)(lpuiFormats,
      cFormats, pcFormatsOut)
  else
  begin
    pcFormatsOut := 0;
    Result := NotImplemented;
  end;
end;

function GetWindowRgnBox(hWnd: HWND; out lprc: TRect): Integer; stdcall;
begin
  if GetUser32Proc(GetWindowRgnBoxProc, 'GetWindowRgnBox') then
    Result := TFnGetWindowRgnBox(GetWindowRgnBoxProc)(hWnd, lprc)
  else
  begin
    FillChar(lprc, SizeOf(lprc), 0);
    Result := 0;                       { ERROR }
  end;
end;

function GetIconInfoEx(hicon: HICON; var piconinfo: TIconInfoEx): BOOL; stdcall;
begin
  Result := GetIconInfoExA(hicon, piconinfo);
end;

function GetIconInfoExA(hicon: HICON; var piconinfo: TIconInfoExA): BOOL; stdcall;
begin
  if GetUser32Proc(GetIconInfoExAProc, 'GetIconInfoExA') then
    Result := TFnGetIconInfoEx(GetIconInfoExAProc)(hicon, @piconinfo)
  else
    Result := NotImplemented;
end;

function GetIconInfoExW(hicon: HICON; var piconinfo: TIconInfoExW): BOOL; stdcall;
begin
  if GetUser32Proc(GetIconInfoExWProc, 'GetIconInfoExW') then
    Result := TFnGetIconInfoEx(GetIconInfoExWProc)(hicon, @piconinfo)
  else
    Result := NotImplemented;
end;

function GetProcessDefaultLayout(out pdwDefaultLayout: DWORD): BOOL; stdcall;
begin
  if GetUser32Proc(GetProcessDefaultLayoutProc, 'GetProcessDefaultLayout') then
    Result := TFnVarDwordBool(GetProcessDefaultLayoutProc)(pdwDefaultLayout)
  else
  begin
    pdwDefaultLayout := 0;
    Result := NotImplemented;
  end;
end;

function SetProcessDefaultLayout(dwDefaultLayout: DWORD): BOOL; stdcall;
begin
  if GetUser32Proc(SetProcessDefaultLayoutProc, 'SetProcessDefaultLayout') then
    Result := TFnDwordBool(SetProcessDefaultLayoutProc)(dwDefaultLayout)
  else
    Result := NotImplemented;
end;

function GetLayout(hdc: HDC): DWORD; stdcall;
begin
  if GetGdi32Proc(GetLayoutProc, 'GetLayout') then
    Result := TFnHdcDword(GetLayoutProc)(hdc)
  else
    Result := GDI_ERROR;
end;

function SetLayout(hdc: HDC; l: DWORD): DWORD; stdcall;
begin
  if GetGdi32Proc(SetLayoutProc, 'SetLayout') then
    Result := TFnHdcDwordDword(SetLayoutProc)(hdc, l)
  else
    Result := GDI_ERROR;
end;

function GetRandomRgn(hdc: HDC; hrgn: HRGN; i: Integer): Integer; stdcall;
begin
  if GetGdi32Proc(GetRandomRgnProc, 'GetRandomRgn') then
    Result := TFnGetRandomRgn(GetRandomRgnProc)(hdc, hrgn, i)
  else
    Result := -1;
end;

function EnumDisplaySettingsEx(lpszDeviceName: PChar; iModeNum: DWORD;
  var lpDevMode: TDeviceMode; dwFlags: DWORD): BOOL; stdcall;
begin
  Result := EnumDisplaySettingsExA(lpszDeviceName, iModeNum, lpDevMode, dwFlags);
end;

function EnumDisplaySettingsExA(lpszDeviceName: PAnsiChar; iModeNum: DWORD;
  var lpDevMode: TDeviceModeA; dwFlags: DWORD): BOOL; stdcall;
begin
  if GetUser32Proc(EnumDisplaySettingsExAProc, 'EnumDisplaySettingsExA') then
    Result := TFnEnumDisplaySettingsEx(EnumDisplaySettingsExAProc)(lpszDeviceName, iModeNum,
      @lpDevMode, dwFlags)
  else
    Result := EnumDisplaySettingsA(lpszDeviceName, iModeNum, lpDevMode);
end;

function EnumDisplaySettingsExW(lpszDeviceName: PWideChar; iModeNum: DWORD;
  var lpDevMode: TDeviceModeW; dwFlags: DWORD): BOOL; stdcall;
begin
  if GetUser32Proc(EnumDisplaySettingsExWProc, 'EnumDisplaySettingsExW') then
    Result := TFnEnumDisplaySettingsEx(EnumDisplaySettingsExWProc)(lpszDeviceName, iModeNum,
      @lpDevMode, dwFlags)
  else
    Result := EnumDisplaySettingsW(lpszDeviceName, iModeNum, lpDevMode);
end;

{ ====== Display configuration ============================================= }

type
  TFnGetDisplayConfigBufferSizes = function(flags: Cardinal; out numPathArrayElements: Cardinal;
    out numModeInfoArrayElements: Cardinal): Longint; stdcall;
  TFnQueryDisplayConfig = function(flags: Cardinal; var numPathArrayElements: Cardinal;
    pathArray: PDisplayConfigPathInfo; var numModeInfoArrayElements: Cardinal;
    modeInfoArray: PDisplayConfigModeInfo; currentTopologyId: PInteger): Longint; stdcall;
  TFnDisplayConfigGetDeviceInfo = function(
    requestPacket: PDisplayConfigDeviceInfoHeader): Longint; stdcall;
  TFnSetDisplayConfig = function(numPathArrayElements: Cardinal;
    pathArray: PDisplayConfigPathInfo; numModeInfoArrayElements: Cardinal;
    modeInfoArray: PDisplayConfigModeInfo; flags: Cardinal): Longint; stdcall;

var
  GetDisplayConfigBufferSizesProc: Pointer;
  QueryDisplayConfigProc: Pointer;
  DisplayConfigGetDeviceInfoProc: Pointer;
  SetDisplayConfigProc: Pointer;

function GetDisplayConfigBufferSizes(flags: Cardinal; out numPathArrayElements: Cardinal;
  out numModeInfoArrayElements: Cardinal): Longint; stdcall;
begin
  if GetUser32Proc(GetDisplayConfigBufferSizesProc, 'GetDisplayConfigBufferSizes') then
    Result := TFnGetDisplayConfigBufferSizes(GetDisplayConfigBufferSizesProc)(flags,
      numPathArrayElements, numModeInfoArrayElements)
  else
  begin
    numPathArrayElements := 0;
    numModeInfoArrayElements := 0;
    Result := ERROR_CALL_NOT_IMPLEMENTED;
  end;
end;

function QueryDisplayConfig(flags: Cardinal; var numPathArrayElements: Cardinal;
  pathArray: PDisplayConfigPathInfo; var numModeInfoArrayElements: Cardinal;
  modeInfoArray: PDisplayConfigModeInfo;
  currentTopologyId: PInteger): Longint; stdcall;
begin
  if GetUser32Proc(QueryDisplayConfigProc, 'QueryDisplayConfig') then
    Result := TFnQueryDisplayConfig(QueryDisplayConfigProc)(flags, numPathArrayElements,
      pathArray, numModeInfoArrayElements, modeInfoArray, currentTopologyId)
  else
  begin
    numPathArrayElements := 0;
    numModeInfoArrayElements := 0;
    Result := ERROR_CALL_NOT_IMPLEMENTED;
  end;
end;

function DisplayConfigGetDeviceInfo(requestPacket: PDisplayConfigDeviceInfoHeader): Longint; stdcall;
begin
  if GetUser32Proc(DisplayConfigGetDeviceInfoProc, 'DisplayConfigGetDeviceInfo') then
    Result := TFnDisplayConfigGetDeviceInfo(DisplayConfigGetDeviceInfoProc)(requestPacket)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function SetDisplayConfig(numPathArrayElements: Cardinal; pathArray: PDisplayConfigPathInfo;
  numModeInfoArrayElements: Cardinal; modeInfoArray: PDisplayConfigModeInfo;
  flags: Cardinal): Longint; stdcall;
begin
  if GetUser32Proc(SetDisplayConfigProc, 'SetDisplayConfig') then
    Result := TFnSetDisplayConfig(SetDisplayConfigProc)(numPathArrayElements, pathArray,
      numModeInfoArrayElements, modeInfoArray, flags)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

{ ====== Registry ========================================================== }

type
  TFnRegGetValue = function(hkey: HKEY; lpSubKey, lpValue: Pointer; dwFlags: DWORD;
    pdwType: PDWORD; pvData: Pointer; pcbData: PDWORD): Longint; stdcall;
  TFnRegSetKeyValue = function(hKey: HKEY; lpSubKey, lpValueName: Pointer; dwType: DWORD;
    lpData: Pointer; cbData: DWORD): Longint; stdcall;
  TFnRegKeyPtrPtr = function(hKey: HKEY; p1, p2: Pointer): Longint; stdcall;
  TFnRegKeyPtr = function(hKey: HKEY; p: Pointer): Longint; stdcall;
  TFnRegCopyTree = function(hKeySrc: HKEY; lpSubKey: Pointer; hKeyDest: HKEY): Longint; stdcall;
  TFnRegDeleteKeyEx = function(hKey: HKEY; lpSubKey: Pointer; samDesired: REGSAM;
    Reserved: DWORD): Longint; stdcall;
  TFnRegLoadMUIString = function(hKey: HKEY; pszValue: Pointer; pszOutBuf: Pointer;
    cbOutBuf: DWORD; pcbData: LPDWORD; Flags: DWORD; pszDirectory: Pointer): Longint; stdcall;
  TFnRegLoadAppKey = function(lpFile: Pointer; out phkResult: HKEY; samDesired: REGSAM;
    dwOptions: DWORD; Reserved: DWORD): Longint; stdcall;
  TFnRegOpenCurrentUser = function(samDesired: REGSAM; out phkResult: HKEY): Longint; stdcall;
  TFnRegOpenUserClassesRoot = function(hToken: THandle; dwOptions: DWORD; samDesired: REGSAM;
    out phkResult: HKEY): Longint; stdcall;
  TFnRegOverridePredefKey = function(hKey: HKEY; hNewHKey: HKEY): Longint; stdcall;

var
  RegGetValueAProc: Pointer;
  RegGetValueWProc: Pointer;
  RegSetKeyValueAProc: Pointer;
  RegSetKeyValueWProc: Pointer;
  RegDeleteKeyValueAProc: Pointer;
  RegDeleteKeyValueWProc: Pointer;
  RegDeleteTreeAProc: Pointer;
  RegDeleteTreeWProc: Pointer;
  RegCopyTreeAProc: Pointer;
  RegCopyTreeWProc: Pointer;
  RegDeleteKeyExAProc: Pointer;
  RegDeleteKeyExWProc: Pointer;
  RegLoadMUIStringAProc: Pointer;
  RegLoadMUIStringWProc: Pointer;
  RegLoadAppKeyAProc: Pointer;
  RegLoadAppKeyWProc: Pointer;
  RegRenameKeyProc: Pointer;
  RegOpenCurrentUserProc: Pointer;
  RegOpenUserClassesRootProc: Pointer;
  RegOverridePredefKeyProc: Pointer;

function RegGetValue(hkey: HKEY; lpSubKey, lpValue: PChar; dwFlags: DWORD; pdwType: PDWORD;
  pvData: Pointer; pcbData: PDWORD): Longint; stdcall;
begin
  Result := RegGetValueA(hkey, lpSubKey, lpValue, dwFlags, pdwType, pvData, pcbData);
end;

function RegGetValueA(hkey: HKEY; lpSubKey, lpValue: PAnsiChar; dwFlags: DWORD; pdwType: PDWORD;
  pvData: Pointer; pcbData: PDWORD): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegGetValueAProc, 'RegGetValueA') then
    Result := TFnRegGetValue(RegGetValueAProc)(hkey, lpSubKey, lpValue, dwFlags, pdwType,
      pvData, pcbData)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function RegGetValueW(hkey: HKEY; lpSubKey, lpValue: PWideChar; dwFlags: DWORD; pdwType: PDWORD;
  pvData: Pointer; pcbData: PDWORD): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegGetValueWProc, 'RegGetValueW') then
    Result := TFnRegGetValue(RegGetValueWProc)(hkey, lpSubKey, lpValue, dwFlags, pdwType,
      pvData, pcbData)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function RegSetKeyValue(hKey: HKEY; lpSubKey, lpValueName: PChar; dwType: DWORD;
  lpData: Pointer; cbData: DWORD): Longint; stdcall;
begin
  Result := RegSetKeyValueA(hKey, lpSubKey, lpValueName, dwType, lpData, cbData);
end;

function RegSetKeyValueA(hKey: HKEY; lpSubKey, lpValueName: PAnsiChar; dwType: DWORD;
  lpData: Pointer; cbData: DWORD): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegSetKeyValueAProc, 'RegSetKeyValueA') then
    Result := TFnRegSetKeyValue(RegSetKeyValueAProc)(hKey, lpSubKey, lpValueName, dwType,
      lpData, cbData)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function RegSetKeyValueW(hKey: HKEY; lpSubKey, lpValueName: PWideChar; dwType: DWORD;
  lpData: Pointer; cbData: DWORD): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegSetKeyValueWProc, 'RegSetKeyValueW') then
    Result := TFnRegSetKeyValue(RegSetKeyValueWProc)(hKey, lpSubKey, lpValueName, dwType,
      lpData, cbData)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function RegDeleteKeyValue(hKey: HKEY; lpSubKey, lpValueName: PChar): Longint; stdcall;
begin
  Result := RegDeleteKeyValueA(hKey, lpSubKey, lpValueName);
end;

function RegDeleteKeyValueA(hKey: HKEY; lpSubKey, lpValueName: PAnsiChar): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegDeleteKeyValueAProc, 'RegDeleteKeyValueA') then
    Result := TFnRegKeyPtrPtr(RegDeleteKeyValueAProc)(hKey, lpSubKey, lpValueName)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function RegDeleteKeyValueW(hKey: HKEY; lpSubKey, lpValueName: PWideChar): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegDeleteKeyValueWProc, 'RegDeleteKeyValueW') then
    Result := TFnRegKeyPtrPtr(RegDeleteKeyValueWProc)(hKey, lpSubKey, lpValueName)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function RegDeleteTree(hKey: HKEY; lpSubKey: PChar): Longint; stdcall;
begin
  Result := RegDeleteTreeA(hKey, lpSubKey);
end;

function RegDeleteTreeA(hKey: HKEY; lpSubKey: PAnsiChar): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegDeleteTreeAProc, 'RegDeleteTreeA') then
    Result := TFnRegKeyPtr(RegDeleteTreeAProc)(hKey, lpSubKey)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function RegDeleteTreeW(hKey: HKEY; lpSubKey: PWideChar): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegDeleteTreeWProc, 'RegDeleteTreeW') then
    Result := TFnRegKeyPtr(RegDeleteTreeWProc)(hKey, lpSubKey)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function RegCopyTree(hKeySrc: HKEY; lpSubKey: PChar; hKeyDest: HKEY): Longint; stdcall;
begin
  Result := RegCopyTreeA(hKeySrc, lpSubKey, hKeyDest);
end;

function RegCopyTreeA(hKeySrc: HKEY; lpSubKey: PAnsiChar; hKeyDest: HKEY): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegCopyTreeAProc, 'RegCopyTreeA') then
    Result := TFnRegCopyTree(RegCopyTreeAProc)(hKeySrc, lpSubKey, hKeyDest)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function RegCopyTreeW(hKeySrc: HKEY; lpSubKey: PWideChar; hKeyDest: HKEY): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegCopyTreeWProc, 'RegCopyTreeW') then
    Result := TFnRegCopyTree(RegCopyTreeWProc)(hKeySrc, lpSubKey, hKeyDest)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function RegDeleteKeyEx(hKey: HKEY; lpSubKey: PChar; samDesired: REGSAM;
  Reserved: DWORD): Longint; stdcall;
begin
  Result := RegDeleteKeyExA(hKey, lpSubKey, samDesired, Reserved);
end;

function RegDeleteKeyExA(hKey: HKEY; lpSubKey: PAnsiChar; samDesired: REGSAM;
  Reserved: DWORD): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegDeleteKeyExAProc, 'RegDeleteKeyExA') then
    Result := TFnRegDeleteKeyEx(RegDeleteKeyExAProc)(hKey, lpSubKey, samDesired, Reserved)
  else
    Result := RegDeleteKeyA(hKey, lpSubKey);
end;

function RegDeleteKeyExW(hKey: HKEY; lpSubKey: PWideChar; samDesired: REGSAM;
  Reserved: DWORD): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegDeleteKeyExWProc, 'RegDeleteKeyExW') then
    Result := TFnRegDeleteKeyEx(RegDeleteKeyExWProc)(hKey, lpSubKey, samDesired, Reserved)
  else
    Result := RegDeleteKeyW(hKey, lpSubKey);
end;

function RegLoadMUIString(hKey: HKEY; pszValue: PChar; pszOutBuf: PChar; cbOutBuf: DWORD;
  pcbData: LPDWORD; Flags: DWORD; pszDirectory: PChar): Longint; stdcall;
begin
  Result := RegLoadMUIStringA(hKey, pszValue, pszOutBuf, cbOutBuf, pcbData, Flags, pszDirectory);
end;

function RegLoadMUIStringA(hKey: HKEY; pszValue: PAnsiChar; pszOutBuf: PAnsiChar; cbOutBuf: DWORD;
  pcbData: LPDWORD; Flags: DWORD; pszDirectory: PAnsiChar): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegLoadMUIStringAProc, 'RegLoadMUIStringA') then
    Result := TFnRegLoadMUIString(RegLoadMUIStringAProc)(hKey, pszValue, pszOutBuf, cbOutBuf,
      pcbData, Flags, pszDirectory)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function RegLoadMUIStringW(hKey: HKEY; pszValue: PWideChar; pszOutBuf: PWideChar; cbOutBuf: DWORD;
  pcbData: LPDWORD; Flags: DWORD; pszDirectory: PWideChar): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegLoadMUIStringWProc, 'RegLoadMUIStringW') then
    Result := TFnRegLoadMUIString(RegLoadMUIStringWProc)(hKey, pszValue, pszOutBuf, cbOutBuf,
      pcbData, Flags, pszDirectory)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function RegLoadAppKey(lpFile: PChar; out phkResult: HKEY; samDesired: REGSAM;
  dwOptions: DWORD; Reserved: DWORD): Longint; stdcall;
begin
  Result := RegLoadAppKeyA(lpFile, phkResult, samDesired, dwOptions, Reserved);
end;

function RegLoadAppKeyA(lpFile: PAnsiChar; out phkResult: HKEY; samDesired: REGSAM;
  dwOptions: DWORD; Reserved: DWORD): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegLoadAppKeyAProc, 'RegLoadAppKeyA') then
    Result := TFnRegLoadAppKey(RegLoadAppKeyAProc)(lpFile, phkResult, samDesired, dwOptions,
      Reserved)
  else
  begin
    phkResult := 0;
    Result := ERROR_CALL_NOT_IMPLEMENTED;
  end;
end;

function RegLoadAppKeyW(lpFile: PWideChar; out phkResult: HKEY; samDesired: REGSAM;
  dwOptions: DWORD; Reserved: DWORD): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegLoadAppKeyWProc, 'RegLoadAppKeyW') then
    Result := TFnRegLoadAppKey(RegLoadAppKeyWProc)(lpFile, phkResult, samDesired, dwOptions,
      Reserved)
  else
  begin
    phkResult := 0;
    Result := ERROR_CALL_NOT_IMPLEMENTED;
  end;
end;

function RegRenameKey(hKey: HKEY; lpSubKeyName, lpNewKeyName: PWideChar): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegRenameKeyProc, 'RegRenameKey') then
    Result := TFnRegKeyPtrPtr(RegRenameKeyProc)(hKey, lpSubKeyName, lpNewKeyName)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

function RegOpenCurrentUser(samDesired: REGSAM; out phkResult: HKEY): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegOpenCurrentUserProc, 'RegOpenCurrentUser') then
    Result := TFnRegOpenCurrentUser(RegOpenCurrentUserProc)(samDesired, phkResult)
  else
  begin
    phkResult := 0;
    Result := ERROR_CALL_NOT_IMPLEMENTED;
  end;
end;

function RegOpenUserClassesRoot(hToken: THandle; dwOptions: DWORD; samDesired: REGSAM;
  out phkResult: HKEY): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegOpenUserClassesRootProc, 'RegOpenUserClassesRoot') then
    Result := TFnRegOpenUserClassesRoot(RegOpenUserClassesRootProc)(hToken, dwOptions,
      samDesired, phkResult)
  else
  begin
    phkResult := 0;
    Result := ERROR_CALL_NOT_IMPLEMENTED;
  end;
end;

function RegOverridePredefKey(hKey: HKEY; hNewHKey: HKEY): Longint; stdcall;
begin
  if GetAdvapi32Proc(RegOverridePredefKeyProc, 'RegOverridePredefKey') then
    Result := TFnRegOverridePredefKey(RegOverridePredefKeyProc)(hKey, hNewHKey)
  else
    Result := ERROR_CALL_NOT_IMPLEMENTED;
end;

{ ====== Security identifiers, descriptors, tokens ========================= }

type
  TFnConvertSidToStringSid = function(Sid: PSID; out StringSid: Pointer): BOOL; stdcall;
  TFnConvertStringSidToSid = function(StringSid: Pointer; out Sid: PSID): BOOL; stdcall;
  TFnConvertStringSDToSD = function(StringSecurityDescriptor: Pointer; StringSDRevision: DWORD;
    out SecurityDescriptor: PSECURITY_DESCRIPTOR; SecurityDescriptorSize: PULONG): BOOL; stdcall;
  TFnConvertSDToStringSD = function(SecurityDescriptor: PSECURITY_DESCRIPTOR;
    RequestedStringSDRevision: DWORD; SecurityInformation: SECURITY_INFORMATION;
    out StringSecurityDescriptor: Pointer; StringSecurityDescriptorLen: PULONG): BOOL; stdcall;
  TFnCreateWellKnownSid = function(WellKnownSidType: Integer; DomainSid: PSID; pSid: PSID;
    var cbSid: DWORD): BOOL; stdcall;
  TFnIsWellKnownSid = function(pSid: PSID; WellKnownSidType: Integer): BOOL; stdcall;
  TFnCheckTokenMembership = function(TokenHandle: THandle; SidToCheck: PSID;
    out IsMember: BOOL): BOOL; stdcall;

var
  ConvertSidToStringSidAProc: Pointer;
  ConvertSidToStringSidWProc: Pointer;
  ConvertStringSidToSidAProc: Pointer;
  ConvertStringSidToSidWProc: Pointer;
  ConvertStringSDToSDAProc: Pointer;
  ConvertStringSDToSDWProc: Pointer;
  ConvertSDToStringSDAProc: Pointer;
  ConvertSDToStringSDWProc: Pointer;
  CreateWellKnownSidProc: Pointer;
  IsWellKnownSidProc: Pointer;
  CheckTokenMembershipProc: Pointer;

function ConvertSidToStringSid(Sid: PSID; out StringSid: PChar): BOOL; stdcall;
begin
  Result := ConvertSidToStringSidA(Sid, StringSid);
end;

function ConvertSidToStringSidA(Sid: PSID; out StringSid: PAnsiChar): BOOL; stdcall;
begin
  if GetAdvapi32Proc(ConvertSidToStringSidAProc, 'ConvertSidToStringSidA') then
    Result := TFnConvertSidToStringSid(ConvertSidToStringSidAProc)(Sid, Pointer(StringSid))
  else
  begin
    StringSid := nil;
    Result := NotImplemented;
  end;
end;

function ConvertSidToStringSidW(Sid: PSID; out StringSid: PWideChar): BOOL; stdcall;
begin
  if GetAdvapi32Proc(ConvertSidToStringSidWProc, 'ConvertSidToStringSidW') then
    Result := TFnConvertSidToStringSid(ConvertSidToStringSidWProc)(Sid, Pointer(StringSid))
  else
  begin
    StringSid := nil;
    Result := NotImplemented;
  end;
end;

function ConvertStringSidToSid(StringSid: PChar; out Sid: PSID): BOOL; stdcall;
begin
  Result := ConvertStringSidToSidA(StringSid, Sid);
end;

function ConvertStringSidToSidA(StringSid: PAnsiChar; out Sid: PSID): BOOL; stdcall;
begin
  if GetAdvapi32Proc(ConvertStringSidToSidAProc, 'ConvertStringSidToSidA') then
    Result := TFnConvertStringSidToSid(ConvertStringSidToSidAProc)(StringSid, Sid)
  else
  begin
    Sid := nil;
    Result := NotImplemented;
  end;
end;

function ConvertStringSidToSidW(StringSid: PWideChar; out Sid: PSID): BOOL; stdcall;
begin
  if GetAdvapi32Proc(ConvertStringSidToSidWProc, 'ConvertStringSidToSidW') then
    Result := TFnConvertStringSidToSid(ConvertStringSidToSidWProc)(StringSid, Sid)
  else
  begin
    Sid := nil;
    Result := NotImplemented;
  end;
end;

function ConvertStringSecurityDescriptorToSecurityDescriptor(StringSecurityDescriptor: PChar;
  StringSDRevision: DWORD; out SecurityDescriptor: PSECURITY_DESCRIPTOR;
  SecurityDescriptorSize: PULONG): BOOL; stdcall;
begin
  Result := ConvertStringSecurityDescriptorToSecurityDescriptorA(StringSecurityDescriptor,
    StringSDRevision, SecurityDescriptor, SecurityDescriptorSize);
end;

function ConvertStringSecurityDescriptorToSecurityDescriptorA(StringSecurityDescriptor: PAnsiChar;
  StringSDRevision: DWORD; out SecurityDescriptor: PSECURITY_DESCRIPTOR;
  SecurityDescriptorSize: PULONG): BOOL; stdcall;
begin
  if GetAdvapi32Proc(ConvertStringSDToSDAProc,
    'ConvertStringSecurityDescriptorToSecurityDescriptorA') then
    Result := TFnConvertStringSDToSD(ConvertStringSDToSDAProc)(StringSecurityDescriptor,
      StringSDRevision, SecurityDescriptor, SecurityDescriptorSize)
  else
  begin
    SecurityDescriptor := nil;
    Result := NotImplemented;
  end;
end;

function ConvertStringSecurityDescriptorToSecurityDescriptorW(StringSecurityDescriptor: PWideChar;
  StringSDRevision: DWORD; out SecurityDescriptor: PSECURITY_DESCRIPTOR;
  SecurityDescriptorSize: PULONG): BOOL; stdcall;
begin
  if GetAdvapi32Proc(ConvertStringSDToSDWProc,
    'ConvertStringSecurityDescriptorToSecurityDescriptorW') then
    Result := TFnConvertStringSDToSD(ConvertStringSDToSDWProc)(StringSecurityDescriptor,
      StringSDRevision, SecurityDescriptor, SecurityDescriptorSize)
  else
  begin
    SecurityDescriptor := nil;
    Result := NotImplemented;
  end;
end;

function ConvertSecurityDescriptorToStringSecurityDescriptor(SecurityDescriptor: PSECURITY_DESCRIPTOR;
  RequestedStringSDRevision: DWORD; SecurityInformation: SECURITY_INFORMATION;
  out StringSecurityDescriptor: PChar; StringSecurityDescriptorLen: PULONG): BOOL; stdcall;
begin
  Result := ConvertSecurityDescriptorToStringSecurityDescriptorA(SecurityDescriptor,
    RequestedStringSDRevision, SecurityInformation, StringSecurityDescriptor,
    StringSecurityDescriptorLen);
end;

function ConvertSecurityDescriptorToStringSecurityDescriptorA(SecurityDescriptor: PSECURITY_DESCRIPTOR;
  RequestedStringSDRevision: DWORD; SecurityInformation: SECURITY_INFORMATION;
  out StringSecurityDescriptor: PAnsiChar; StringSecurityDescriptorLen: PULONG): BOOL; stdcall;
begin
  if GetAdvapi32Proc(ConvertSDToStringSDAProc,
    'ConvertSecurityDescriptorToStringSecurityDescriptorA') then
    Result := TFnConvertSDToStringSD(ConvertSDToStringSDAProc)(SecurityDescriptor,
      RequestedStringSDRevision, SecurityInformation, Pointer(StringSecurityDescriptor),
      StringSecurityDescriptorLen)
  else
  begin
    StringSecurityDescriptor := nil;
    Result := NotImplemented;
  end;
end;

function ConvertSecurityDescriptorToStringSecurityDescriptorW(SecurityDescriptor: PSECURITY_DESCRIPTOR;
  RequestedStringSDRevision: DWORD; SecurityInformation: SECURITY_INFORMATION;
  out StringSecurityDescriptor: PWideChar; StringSecurityDescriptorLen: PULONG): BOOL; stdcall;
begin
  if GetAdvapi32Proc(ConvertSDToStringSDWProc,
    'ConvertSecurityDescriptorToStringSecurityDescriptorW') then
    Result := TFnConvertSDToStringSD(ConvertSDToStringSDWProc)(SecurityDescriptor,
      RequestedStringSDRevision, SecurityInformation, Pointer(StringSecurityDescriptor),
      StringSecurityDescriptorLen)
  else
  begin
    StringSecurityDescriptor := nil;
    Result := NotImplemented;
  end;
end;

function CreateWellKnownSid(WellKnownSidType: WELL_KNOWN_SID_TYPE; DomainSid: PSID; pSid: PSID;
  var cbSid: DWORD): BOOL; stdcall;
begin
  if GetAdvapi32Proc(CreateWellKnownSidProc, 'CreateWellKnownSid') then
    Result := TFnCreateWellKnownSid(CreateWellKnownSidProc)(WellKnownSidType, DomainSid, pSid,
      cbSid)
  else
    Result := NotImplemented;
end;

function IsWellKnownSid(pSid: PSID; WellKnownSidType: WELL_KNOWN_SID_TYPE): BOOL; stdcall;
begin
  if GetAdvapi32Proc(IsWellKnownSidProc, 'IsWellKnownSid') then
    Result := TFnIsWellKnownSid(IsWellKnownSidProc)(pSid, WellKnownSidType)
  else
    Result := NotImplemented;
end;

function CheckTokenMembership(TokenHandle: THandle; SidToCheck: PSID;
  out IsMember: BOOL): BOOL; stdcall;
begin
  if GetAdvapi32Proc(CheckTokenMembershipProc, 'CheckTokenMembership') then
    Result := TFnCheckTokenMembership(CheckTokenMembershipProc)(TokenHandle, SidToCheck, IsMember)
  else
  begin
    IsMember := False;
    Result := NotImplemented;
  end;
end;

{ ====== Credentials ======================================================= }

type
  TFnCredRead = function(TargetName: Pointer; Type_: DWORD; Flags: DWORD;
    out Credential: Pointer): BOOL; stdcall;
  TFnCredWrite = function(Credential: Pointer; Flags: DWORD): BOOL; stdcall;
  TFnCredDelete = function(TargetName: Pointer; Type_: DWORD; Flags: DWORD): BOOL; stdcall;
  TFnCredEnumerate = function(Filter: Pointer; Flags: DWORD; out Count: DWORD;
    out Credential: Pointer): BOOL; stdcall;

var
  CredReadAProc: Pointer;
  CredReadWProc: Pointer;
  CredWriteAProc: Pointer;
  CredWriteWProc: Pointer;
  CredDeleteAProc: Pointer;
  CredDeleteWProc: Pointer;
  CredEnumerateAProc: Pointer;
  CredEnumerateWProc: Pointer;
  CredFreeProc: Pointer;

function CredRead(TargetName: PChar; Type_: DWORD; Flags: DWORD;
  out Credential: PCredential): BOOL; stdcall;
begin
  Result := CredReadA(TargetName, Type_, Flags, Credential);
end;

function CredReadA(TargetName: PAnsiChar; Type_: DWORD; Flags: DWORD;
  out Credential: PCredentialA): BOOL; stdcall;
begin
  if GetAdvapi32Proc(CredReadAProc, 'CredReadA') then
    Result := TFnCredRead(CredReadAProc)(TargetName, Type_, Flags, Pointer(Credential))
  else
  begin
    Credential := nil;
    Result := NotImplemented;
  end;
end;

function CredReadW(TargetName: PWideChar; Type_: DWORD; Flags: DWORD;
  out Credential: PCredentialW): BOOL; stdcall;
begin
  if GetAdvapi32Proc(CredReadWProc, 'CredReadW') then
    Result := TFnCredRead(CredReadWProc)(TargetName, Type_, Flags, Pointer(Credential))
  else
  begin
    Credential := nil;
    Result := NotImplemented;
  end;
end;

function CredWrite(const Credential: TCredential; Flags: DWORD): BOOL; stdcall;
begin
  Result := CredWriteA(Credential, Flags);
end;

function CredWriteA(const Credential: TCredentialA; Flags: DWORD): BOOL; stdcall;
begin
  if GetAdvapi32Proc(CredWriteAProc, 'CredWriteA') then
    Result := TFnCredWrite(CredWriteAProc)(@Credential, Flags)
  else
    Result := NotImplemented;
end;

function CredWriteW(const Credential: TCredentialW; Flags: DWORD): BOOL; stdcall;
begin
  if GetAdvapi32Proc(CredWriteWProc, 'CredWriteW') then
    Result := TFnCredWrite(CredWriteWProc)(@Credential, Flags)
  else
    Result := NotImplemented;
end;

function CredDelete(TargetName: PChar; Type_: DWORD; Flags: DWORD): BOOL; stdcall;
begin
  Result := CredDeleteA(TargetName, Type_, Flags);
end;

function CredDeleteA(TargetName: PAnsiChar; Type_: DWORD; Flags: DWORD): BOOL; stdcall;
begin
  if GetAdvapi32Proc(CredDeleteAProc, 'CredDeleteA') then
    Result := TFnCredDelete(CredDeleteAProc)(TargetName, Type_, Flags)
  else
    Result := NotImplemented;
end;

function CredDeleteW(TargetName: PWideChar; Type_: DWORD; Flags: DWORD): BOOL; stdcall;
begin
  if GetAdvapi32Proc(CredDeleteWProc, 'CredDeleteW') then
    Result := TFnCredDelete(CredDeleteWProc)(TargetName, Type_, Flags)
  else
    Result := NotImplemented;
end;

function CredEnumerate(Filter: PChar; Flags: DWORD; out Count: DWORD;
  out Credential: PPCredential): BOOL; stdcall;
begin
  Result := CredEnumerateA(Filter, Flags, Count, Credential);
end;

function CredEnumerateA(Filter: PAnsiChar; Flags: DWORD; out Count: DWORD;
  out Credential: PPCredentialA): BOOL; stdcall;
begin
  if GetAdvapi32Proc(CredEnumerateAProc, 'CredEnumerateA') then
    Result := TFnCredEnumerate(CredEnumerateAProc)(Filter, Flags, Count, Pointer(Credential))
  else
  begin
    Count := 0;
    Credential := nil;
    Result := NotImplemented;
  end;
end;

function CredEnumerateW(Filter: PWideChar; Flags: DWORD; out Count: DWORD;
  out Credential: PPCredentialW): BOOL; stdcall;
begin
  if GetAdvapi32Proc(CredEnumerateWProc, 'CredEnumerateW') then
    Result := TFnCredEnumerate(CredEnumerateWProc)(Filter, Flags, Count, Pointer(Credential))
  else
  begin
    Count := 0;
    Credential := nil;
    Result := NotImplemented;
  end;
end;

procedure CredFree(Buffer: Pointer); stdcall;
begin
  if GetAdvapi32Proc(CredFreeProc, 'CredFree') then
    TFnPtrProc(CredFreeProc)(Buffer);
end;

end.
