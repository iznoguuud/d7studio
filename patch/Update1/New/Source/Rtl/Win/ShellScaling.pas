{**********************************************************}
{                                                          }
{     Delphi 7 Runtime Library - Modernization             }
{     DPI awareness API (Windows Vista .. 11)              }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit ShellScaling;

{ High-DPI API translation for Delphi 7.

  Everything newer than Windows XP is bound at run time (GetProcAddress on first
  use), so programs that use this unit still start on old Windows. When a
  function is missing it falls back to the closest emulation available on the
  running system; the fallback is described next to each declaration.

  The second half of the interface contains helpers used by the VCL
  (Forms/Controls/Graphics) to implement per-monitor DPI scaling. }

{$WEAKPACKAGEUNIT ON}
{$MINENUMSIZE 4}
{$ALIGN ON}

interface

uses
  Windows, MultiMon;

type
  {$EXTERNALSYM DPI_AWARENESS_CONTEXT}
  DPI_AWARENESS_CONTEXT = THandle;
  TDpiAwarenessContext = DPI_AWARENESS_CONTEXT;

const
  {$EXTERNALSYM USER_DEFAULT_SCREEN_DPI}
  USER_DEFAULT_SCREEN_DPI = 96;

  { Pseudo handles accepted by the *DpiAwarenessContext functions }
  {$EXTERNALSYM DPI_AWARENESS_CONTEXT_UNAWARE}
  DPI_AWARENESS_CONTEXT_UNAWARE              = DPI_AWARENESS_CONTEXT(-1);
  {$EXTERNALSYM DPI_AWARENESS_CONTEXT_SYSTEM_AWARE}
  DPI_AWARENESS_CONTEXT_SYSTEM_AWARE         = DPI_AWARENESS_CONTEXT(-2);
  {$EXTERNALSYM DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE}
  DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE    = DPI_AWARENESS_CONTEXT(-3);
  {$EXTERNALSYM DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2}
  DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = DPI_AWARENESS_CONTEXT(-4);
  {$EXTERNALSYM DPI_AWARENESS_CONTEXT_UNAWARE_GDISCALED}
  DPI_AWARENESS_CONTEXT_UNAWARE_GDISCALED    = DPI_AWARENESS_CONTEXT(-5);

  { DPI_AWARENESS }
  {$EXTERNALSYM DPI_AWARENESS_INVALID}
  DPI_AWARENESS_INVALID           = -1;
  {$EXTERNALSYM DPI_AWARENESS_UNAWARE}
  DPI_AWARENESS_UNAWARE           = 0;
  {$EXTERNALSYM DPI_AWARENESS_SYSTEM_AWARE}
  DPI_AWARENESS_SYSTEM_AWARE      = 1;
  {$EXTERNALSYM DPI_AWARENESS_PER_MONITOR_AWARE}
  DPI_AWARENESS_PER_MONITOR_AWARE = 2;

  { PROCESS_DPI_AWARENESS (shcore, Windows 8.1) }
  {$EXTERNALSYM PROCESS_DPI_UNAWARE}
  PROCESS_DPI_UNAWARE            = 0;
  {$EXTERNALSYM PROCESS_SYSTEM_DPI_AWARE}
  PROCESS_SYSTEM_DPI_AWARE       = 1;
  {$EXTERNALSYM PROCESS_PER_MONITOR_DPI_AWARE}
  PROCESS_PER_MONITOR_DPI_AWARE  = 2;

  { MONITOR_DPI_TYPE }
  {$EXTERNALSYM MDT_EFFECTIVE_DPI}
  MDT_EFFECTIVE_DPI = 0;
  {$EXTERNALSYM MDT_ANGULAR_DPI}
  MDT_ANGULAR_DPI   = 1;
  {$EXTERNALSYM MDT_RAW_DPI}
  MDT_RAW_DPI       = 2;
  {$EXTERNALSYM MDT_DEFAULT}
  MDT_DEFAULT       = MDT_EFFECTIVE_DPI;

  { DPI_HOSTING_BEHAVIOR (Windows 10 1803) }
  {$EXTERNALSYM DPI_HOSTING_BEHAVIOR_INVALID}
  DPI_HOSTING_BEHAVIOR_INVALID = -1;
  {$EXTERNALSYM DPI_HOSTING_BEHAVIOR_DEFAULT}
  DPI_HOSTING_BEHAVIOR_DEFAULT = 0;
  {$EXTERNALSYM DPI_HOSTING_BEHAVIOR_MIXED}
  DPI_HOSTING_BEHAVIOR_MIXED   = 1;

  { DIALOG_DPI_CHANGE_BEHAVIORS / DIALOG_CONTROL_DPI_CHANGE_BEHAVIORS (1703) }
  {$EXTERNALSYM DDC_DEFAULT}
  DDC_DEFAULT                  = $0000;
  {$EXTERNALSYM DDC_DISABLE_ALL}
  DDC_DISABLE_ALL              = $0001;
  {$EXTERNALSYM DDC_DISABLE_RESIZE}
  DDC_DISABLE_RESIZE           = $0002;
  {$EXTERNALSYM DDC_DISABLE_CONTROL_RELAYOUT}
  DDC_DISABLE_CONTROL_RELAYOUT = $0004;
  {$EXTERNALSYM DCDC_DEFAULT}
  DCDC_DEFAULT                 = $0000;
  {$EXTERNALSYM DCDC_DISABLE_FONT_UPDATE}
  DCDC_DISABLE_FONT_UPDATE     = $0001;
  {$EXTERNALSYM DCDC_DISABLE_RELAYOUT}
  DCDC_DISABLE_RELAYOUT        = $0002;

  { DEVICE_SCALE_FACTOR (shcore) }
  {$EXTERNALSYM DEVICE_SCALE_FACTOR_INVALID}
  DEVICE_SCALE_FACTOR_INVALID = 0;
  {$EXTERNALSYM SCALE_100_PERCENT}
  SCALE_100_PERCENT = 100;
  {$EXTERNALSYM SCALE_120_PERCENT}
  SCALE_120_PERCENT = 120;
  {$EXTERNALSYM SCALE_125_PERCENT}
  SCALE_125_PERCENT = 125;
  {$EXTERNALSYM SCALE_140_PERCENT}
  SCALE_140_PERCENT = 140;
  {$EXTERNALSYM SCALE_150_PERCENT}
  SCALE_150_PERCENT = 150;
  {$EXTERNALSYM SCALE_160_PERCENT}
  SCALE_160_PERCENT = 160;
  {$EXTERNALSYM SCALE_175_PERCENT}
  SCALE_175_PERCENT = 175;
  {$EXTERNALSYM SCALE_180_PERCENT}
  SCALE_180_PERCENT = 180;
  {$EXTERNALSYM SCALE_200_PERCENT}
  SCALE_200_PERCENT = 200;
  {$EXTERNALSYM SCALE_225_PERCENT}
  SCALE_225_PERCENT = 225;
  {$EXTERNALSYM SCALE_250_PERCENT}
  SCALE_250_PERCENT = 250;
  {$EXTERNALSYM SCALE_300_PERCENT}
  SCALE_300_PERCENT = 300;
  {$EXTERNALSYM SCALE_350_PERCENT}
  SCALE_350_PERCENT = 350;
  {$EXTERNALSYM SCALE_400_PERCENT}
  SCALE_400_PERCENT = 400;
  {$EXTERNALSYM SCALE_450_PERCENT}
  SCALE_450_PERCENT = 450;
  {$EXTERNALSYM SCALE_500_PERCENT}
  SCALE_500_PERCENT = 500;

  { System metric missing from the Delphi 7 headers (Vista+) }
  {$EXTERNALSYM SM_CXPADDEDBORDER}
  SM_CXPADDEDBORDER = 92;

{ ---- user32: Windows Vista ---- }

{ Fallback: returns False. }
function SetProcessDPIAware: BOOL;
{ Fallback: returns False. }
function IsProcessDPIAware: BOOL;
{ Vista+. Fallback: identity (returns True). }
function LogicalToPhysicalPoint(hWnd: HWND; var lpPoint: TPoint): BOOL;
function PhysicalToLogicalPoint(hWnd: HWND; var lpPoint: TPoint): BOOL;

{ ---- user32: Windows 8.1 ---- }

{ Fallback: LogicalToPhysicalPoint / identity. }
function LogicalToPhysicalPointForPerMonitorDPI(hWnd: HWND; var lpPoint: TPoint): BOOL;
function PhysicalToLogicalPointForPerMonitorDPI(hWnd: HWND; var lpPoint: TPoint): BOOL;

{ ---- user32: Windows 10 (1607 unless noted) ---- }

{ Fallback: per-monitor DPI of the window's monitor when the process is
  per-monitor aware (Windows 8.1), otherwise the system DPI. }
function GetDpiForWindow(hwnd: HWND): UINT;
{ Fallback: LOGPIXELSY of the screen DC. }
function GetDpiForSystem: UINT;
{ 1803. Fallback: GetDpiForSystem (only correct for the current process). }
function GetSystemDpiForProcess(hProcess: THandle): UINT;
{ Fallback: GetSystemMetrics, with DPI-dependent sizes scaled from the system DPI. }
function GetSystemMetricsForDpi(nIndex: Integer; dpi: UINT): Integer;
{ Fallback: AdjustWindowRectEx with the frame scaled from the system DPI. }
function AdjustWindowRectExForDpi(var lpRect: TRect; dwStyle: DWORD; bMenu: BOOL;
  dwExStyle: DWORD; dpi: UINT): BOOL;
{ Raw API. Supports SPI_GETICONTITLELOGFONT, SPI_GETICONMETRICS and
  SPI_GETNONCLIENTMETRICS with the UNICODE structures (TLogFontW,
  TIconMetricsW, TNonClientMetricsW). Fallback: SystemParametersInfoW with the
  DPI-dependent values scaled from the system DPI. }
function SystemParametersInfoForDpi(uiAction, uiParam: UINT; pvParam: Pointer;
  fWinIni, dpi: UINT): BOOL;
{ Fallback: returns False. }
function EnableNonClientDpiScaling(hwnd: HWND): BOOL;
{ 1703. Fallback: SetProcessDpiAwareness (8.1) or SetProcessDPIAware (Vista). }
function SetProcessDpiAwarenessContext(value: DPI_AWARENESS_CONTEXT): BOOL;
{ Fallback: returns 0 (failure); the thread keeps the process awareness. }
function SetThreadDpiAwarenessContext(dpiContext: DPI_AWARENESS_CONTEXT): DPI_AWARENESS_CONTEXT;
{ Fallback: a pseudo handle matching the process awareness. }
function GetThreadDpiAwarenessContext: DPI_AWARENESS_CONTEXT;
function GetWindowDpiAwarenessContext(hwnd: HWND): DPI_AWARENESS_CONTEXT;
{ Fallback: maps the pseudo handles above. }
function GetAwarenessFromDpiAwarenessContext(value: DPI_AWARENESS_CONTEXT): Integer;
{ 1803. Fallback: 96 for unaware, system DPI for system aware, 0 otherwise. }
function GetDpiFromDpiAwarenessContext(value: DPI_AWARENESS_CONTEXT): UINT;
{ Fallback: compares the awareness levels. }
function AreDpiAwarenessContextsEqual(dpiContextA, dpiContextB: DPI_AWARENESS_CONTEXT): BOOL;
function IsValidDpiAwarenessContext(value: DPI_AWARENESS_CONTEXT): BOOL;
{ 1803. Fallback: returns DPI_AWARENESS_CONTEXT of the process. }
function GetDpiAwarenessContextForProcess(hProcess: THandle): DPI_AWARENESS_CONTEXT;
{ 1803. Fallback: DPI_HOSTING_BEHAVIOR_INVALID. }
function SetThreadDpiHostingBehavior(value: Integer): Integer;
function GetThreadDpiHostingBehavior: Integer;
function GetWindowDpiHostingBehavior(hwnd: HWND): Integer;
{ 1703. Fallback: returns False. }
function SetDialogDpiChangeBehavior(hDlg: HWND; mask, values: DWORD): BOOL;
function GetDialogDpiChangeBehavior(hDlg: HWND): DWORD;
function SetDialogControlDpiChangeBehavior(hWnd: HWND; mask, values: DWORD): BOOL;
function GetDialogControlDpiChangeBehavior(hWnd: HWND): DWORD;

{ ---- shcore: Windows 8.1 ---- }

{ Fallback: S_OK with the system DPI. }
function GetDpiForMonitor(hmonitor: HMONITOR; dpiType: Integer; out dpiX, dpiY: UINT): HRESULT;
{ Fallback: SetProcessDPIAware for system/per-monitor values. }
function SetProcessDpiAwareness(value: Integer): HRESULT;
{ Fallback: PROCESS_SYSTEM_DPI_AWARE when IsProcessDPIAware, else PROCESS_DPI_UNAWARE. }
function GetProcessDpiAwareness(hprocess: THandle; out value: Integer): HRESULT;
{ Fallback: derived from the monitor DPI. }
function GetScaleFactorForMonitor(hMon: HMONITOR; out pScale: Integer): HRESULT;
{ Fallback: system DPI. }
function GetDpiForShellUIComponent(component: Integer): UINT;

{ ------------------------------------------------------------------------
  Helpers used by the VCL
  ------------------------------------------------------------------------ }

{ DPI_AWARENESS_* of the calling thread (normally the process awareness). }
function GetCurrentDpiAwareness: Integer;
{ True when windows of the calling thread are per-monitor DPI aware (V1 or V2). }
function IsPerMonitorDpiAware: Boolean;
{ True when the calling thread runs in Per-Monitor V2 mode (Windows 10 1703+). }
function IsPerMonitorV2DpiAware: Boolean;
{ System DPI of this process (cached). }
function SystemDpi: Integer;
{ Effective DPI of a monitor (system DPI when not per-monitor aware). }
function GetDpiForMonitorHandle(Monitor: HMONITOR): Integer;
{ Effective DPI of the monitor that contains (or is nearest to) a point/rect. }
function GetDpiForPoint(const Pt: TPoint): Integer;
function GetDpiForRect(const R: TRect): Integer;
{ GetDpiForWindow that never returns 0. }
function GetWindowDpi(Wnd: HWND): Integer;
{ MulDiv(Value, ToDpi, FromDpi) }
function ScaleByDpi(Value, ToDpi: Integer; FromDpi: Integer = USER_DEFAULT_SCREEN_DPI): Integer;
{ GetSystemMetricsForDpi that falls back to scaling. }
function GetSystemMetricForDpi(Index, Dpi: Integer): Integer;
{ ANSI non-client metrics / icon title font for a DPI (fonts converted from the
  Unicode structures, so non-ASCII face names survive in UTF-8 mode). }
function GetNonClientMetricsForDpi(var Metrics: TNonClientMetricsA; Dpi: Integer): Boolean;
function GetIconTitleFontForDpi(var LogFont: TLogFontA; Dpi: Integer): Boolean;

{ ---- shcore, Windows 8 / 8.1: the scale factor of the display (ShellScalingApi.h) ----
  Bound at run time; where Windows lacks them, GetScaleFactorForDevice returns
  DEVICE_SCALE_FACTOR_INVALID and the others E_NOTIMPL. Per-monitor programs use the DPI
  functions above; these serve the scale factor of the primary display and its change. }
const
  { DISPLAY_DEVICE_TYPE }
  {$EXTERNALSYM DEVICE_PRIMARY}
  DEVICE_PRIMARY   = 0;
  {$EXTERNALSYM DEVICE_IMMERSIVE}
  DEVICE_IMMERSIVE = 1;

{$EXTERNALSYM GetScaleFactorForDevice}
function GetScaleFactorForDevice(deviceType: Integer): Integer; stdcall;
{ uMsgNotify is posted to hwndNotify when the scale factor changes }
{$EXTERNALSYM RegisterScaleChangeNotifications}
function RegisterScaleChangeNotifications(displayDevice: Integer; hwndNotify: HWND;
  uMsgNotify: UINT; out pdwCookie: DWORD): HRESULT; stdcall;
{$EXTERNALSYM RevokeScaleChangeNotifications}
function RevokeScaleChangeNotifications(displayDevice: Integer; dwCookie: DWORD): HRESULT; stdcall;
{ Windows 8.1: hEvent is set when the scale factor changes }
{$EXTERNALSYM RegisterScaleChangeEvent}
function RegisterScaleChangeEvent(hEvent: THandle; out pdwCookie: DWORD): HRESULT; stdcall;
{$EXTERNALSYM UnregisterScaleChangeEvent}
function UnregisterScaleChangeEvent(dwCookie: DWORD): HRESULT; stdcall;

implementation

{ ---- run-time binding ---- }

var
  User32Module: HMODULE;
  ShcoreModule: HMODULE;
  ShcoreLoaded: Boolean;
  CachedSystemDpi: Integer;

function User32Proc(Name: PChar): Pointer;
begin
  if User32Module = 0 then
    User32Module := GetModuleHandle(user32);
  Result := GetProcAddress(User32Module, Name);
end;

function ShcoreProc(Name: PChar): Pointer;
var
  Path: array[0..MAX_PATH] of Char;
  Len: Integer;
begin
  if not ShcoreLoaded then
  begin
    { Load from the system directory only (no DLL search-order planting). }
    Len := GetSystemDirectory(Path, MAX_PATH - 12);
    if (Len > 0) and (Len < MAX_PATH - 12) then
    begin
      lstrcat(Path, '\shcore.dll');
      ShcoreModule := LoadLibrary(Path);
    end;
    ShcoreLoaded := True;
  end;
  if ShcoreModule <> 0 then
    Result := GetProcAddress(ShcoreModule, Name)
  else
    Result := nil;
end;

type
  TProc_BOOL = function: BOOL; stdcall;
  TProc_HWND_PPoint_BOOL = function(hWnd: HWND; var P: TPoint): BOOL; stdcall;
  TProc_HWND_UINT = function(hwnd: HWND): UINT; stdcall;
  TProc_UINT = function: UINT; stdcall;
  TProc_Handle_UINT = function(h: THandle): UINT; stdcall;
  TProc_Int_UINT_Int = function(nIndex: Integer; dpi: UINT): Integer; stdcall;
  TProc_AdjustForDpi = function(var R: TRect; dwStyle: DWORD; bMenu: BOOL; dwExStyle: DWORD; dpi: UINT): BOOL; stdcall;
  TProc_SPIForDpi = function(uiAction, uiParam: UINT; pvParam: Pointer; fWinIni, dpi: UINT): BOOL; stdcall;
  TProc_HWND_BOOL = function(hwnd: HWND): BOOL; stdcall;
  TProc_Ctx_BOOL = function(ctx: DPI_AWARENESS_CONTEXT): BOOL; stdcall;
  TProc_Ctx_Ctx = function(ctx: DPI_AWARENESS_CONTEXT): DPI_AWARENESS_CONTEXT; stdcall;
  TProc_Ctx = function: DPI_AWARENESS_CONTEXT; stdcall;
  TProc_HWND_Ctx = function(hwnd: HWND): DPI_AWARENESS_CONTEXT; stdcall;
  TProc_Ctx_Int = function(ctx: DPI_AWARENESS_CONTEXT): Integer; stdcall;
  TProc_Ctx_UINT = function(ctx: DPI_AWARENESS_CONTEXT): UINT; stdcall;
  TProc_Ctx_Ctx_BOOL = function(a, b: DPI_AWARENESS_CONTEXT): BOOL; stdcall;
  TProc_Handle_Ctx = function(h: THandle): DPI_AWARENESS_CONTEXT; stdcall;
  TProc_Int_Int = function(v: Integer): Integer; stdcall;
  TProc_Int = function: Integer; stdcall;
  TProc_HWND_Int = function(hwnd: HWND): Integer; stdcall;
  TProc_HWND_DW_DW_BOOL = function(h: HWND; mask, values: DWORD): BOOL; stdcall;
  TProc_HWND_DW = function(h: HWND): DWORD; stdcall;
  TProc_GetDpiForMonitor = function(hmonitor: HMONITOR; dpiType: Integer; out dpiX, dpiY: UINT): HRESULT; stdcall;
  TProc_Int_HRESULT = function(value: Integer): HRESULT; stdcall;
  TProc_GetProcessDpiAwareness = function(hprocess: THandle; out value: Integer): HRESULT; stdcall;
  TProc_GetScaleFactorForMonitor = function(hMon: HMONITOR; out pScale: Integer): HRESULT; stdcall;
  TProc_Int_UINT = function(component: Integer): UINT; stdcall;

{ Each API has a cached pointer and a "resolved" flag. Races only resolve the
  same pointer twice, which is harmless. }
var
  pSetProcessDPIAware: TProc_BOOL;                     rSetProcessDPIAware: Boolean;
  pIsProcessDPIAware: TProc_BOOL;                      rIsProcessDPIAware: Boolean;
  pLogicalToPhysicalPoint: TProc_HWND_PPoint_BOOL;     rLogicalToPhysicalPoint: Boolean;
  pPhysicalToLogicalPoint: TProc_HWND_PPoint_BOOL;     rPhysicalToLogicalPoint: Boolean;
  pL2PForPerMonitorDPI: TProc_HWND_PPoint_BOOL;        rL2PForPerMonitorDPI: Boolean;
  pP2LForPerMonitorDPI: TProc_HWND_PPoint_BOOL;        rP2LForPerMonitorDPI: Boolean;
  pGetDpiForWindow: TProc_HWND_UINT;                   rGetDpiForWindow: Boolean;
  pGetDpiForSystem: TProc_UINT;                        rGetDpiForSystem: Boolean;
  pGetSystemDpiForProcess: TProc_Handle_UINT;          rGetSystemDpiForProcess: Boolean;
  pGetSystemMetricsForDpi: TProc_Int_UINT_Int;         rGetSystemMetricsForDpi: Boolean;
  pAdjustWindowRectExForDpi: TProc_AdjustForDpi;       rAdjustWindowRectExForDpi: Boolean;
  pSystemParametersInfoForDpi: TProc_SPIForDpi;        rSystemParametersInfoForDpi: Boolean;
  pEnableNonClientDpiScaling: TProc_HWND_BOOL;         rEnableNonClientDpiScaling: Boolean;
  pSetProcessDpiAwarenessContext: TProc_Ctx_BOOL;      rSetProcessDpiAwarenessContext: Boolean;
  pSetThreadDpiAwarenessContext: TProc_Ctx_Ctx;        rSetThreadDpiAwarenessContext: Boolean;
  pGetThreadDpiAwarenessContext: TProc_Ctx;            rGetThreadDpiAwarenessContext: Boolean;
  pGetWindowDpiAwarenessContext: TProc_HWND_Ctx;       rGetWindowDpiAwarenessContext: Boolean;
  pGetAwarenessFromDpiAwarenessContext: TProc_Ctx_Int; rGetAwarenessFromDpiAwarenessContext: Boolean;
  pGetDpiFromDpiAwarenessContext: TProc_Ctx_UINT;      rGetDpiFromDpiAwarenessContext: Boolean;
  pAreDpiAwarenessContextsEqual: TProc_Ctx_Ctx_BOOL;   rAreDpiAwarenessContextsEqual: Boolean;
  pIsValidDpiAwarenessContext: TProc_Ctx_BOOL;         rIsValidDpiAwarenessContext: Boolean;
  pGetDpiAwarenessContextForProcess: TProc_Handle_Ctx; rGetDpiAwarenessContextForProcess: Boolean;
  pSetThreadDpiHostingBehavior: TProc_Int_Int;         rSetThreadDpiHostingBehavior: Boolean;
  pGetThreadDpiHostingBehavior: TProc_Int;             rGetThreadDpiHostingBehavior: Boolean;
  pGetWindowDpiHostingBehavior: TProc_HWND_Int;        rGetWindowDpiHostingBehavior: Boolean;
  pSetDialogDpiChangeBehavior: TProc_HWND_DW_DW_BOOL;  rSetDialogDpiChangeBehavior: Boolean;
  pGetDialogDpiChangeBehavior: TProc_HWND_DW;          rGetDialogDpiChangeBehavior: Boolean;
  pSetDialogControlDpiChangeBehavior: TProc_HWND_DW_DW_BOOL; rSetDialogControlDpiChangeBehavior: Boolean;
  pGetDialogControlDpiChangeBehavior: TProc_HWND_DW;   rGetDialogControlDpiChangeBehavior: Boolean;
  pGetDpiForMonitor: TProc_GetDpiForMonitor;           rGetDpiForMonitor: Boolean;
  pSetProcessDpiAwareness: TProc_Int_HRESULT;          rSetProcessDpiAwareness: Boolean;
  pGetProcessDpiAwareness: TProc_GetProcessDpiAwareness; rGetProcessDpiAwareness: Boolean;
  pGetScaleFactorForMonitor: TProc_GetScaleFactorForMonitor; rGetScaleFactorForMonitor: Boolean;
  pGetDpiForShellUIComponent: TProc_Int_UINT;          rGetDpiForShellUIComponent: Boolean;

function Bind(var Resolved: Boolean; var Proc; Name: PChar; FromShcore: Boolean): Boolean;
begin
  if not Resolved then
  begin
    if FromShcore then
      Pointer(Proc) := ShcoreProc(Name)
    else
      Pointer(Proc) := User32Proc(Name);
    Resolved := True;
  end;
  Result := Pointer(Proc) <> nil;
end;

{ ---- user32: Vista ---- }

function SetProcessDPIAware: BOOL;
begin
  if Bind(rSetProcessDPIAware, pSetProcessDPIAware, 'SetProcessDPIAware', False) then
    Result := pSetProcessDPIAware()
  else
    Result := False;
end;

function IsProcessDPIAware: BOOL;
begin
  if Bind(rIsProcessDPIAware, pIsProcessDPIAware, 'IsProcessDPIAware', False) then
    Result := pIsProcessDPIAware()
  else
    Result := False;
end;

function LogicalToPhysicalPoint(hWnd: HWND; var lpPoint: TPoint): BOOL;
begin
  if Bind(rLogicalToPhysicalPoint, pLogicalToPhysicalPoint, 'LogicalToPhysicalPoint', False) then
    Result := pLogicalToPhysicalPoint(hWnd, lpPoint)
  else
    Result := True;
end;

function PhysicalToLogicalPoint(hWnd: HWND; var lpPoint: TPoint): BOOL;
begin
  if Bind(rPhysicalToLogicalPoint, pPhysicalToLogicalPoint, 'PhysicalToLogicalPoint', False) then
    Result := pPhysicalToLogicalPoint(hWnd, lpPoint)
  else
    Result := True;
end;

{ ---- user32: 8.1 ---- }

function LogicalToPhysicalPointForPerMonitorDPI(hWnd: HWND; var lpPoint: TPoint): BOOL;
begin
  if Bind(rL2PForPerMonitorDPI, pL2PForPerMonitorDPI, 'LogicalToPhysicalPointForPerMonitorDPI', False) then
    Result := pL2PForPerMonitorDPI(hWnd, lpPoint)
  else
    Result := LogicalToPhysicalPoint(hWnd, lpPoint);
end;

function PhysicalToLogicalPointForPerMonitorDPI(hWnd: HWND; var lpPoint: TPoint): BOOL;
begin
  if Bind(rP2LForPerMonitorDPI, pP2LForPerMonitorDPI, 'PhysicalToLogicalPointForPerMonitorDPI', False) then
    Result := pP2LForPerMonitorDPI(hWnd, lpPoint)
  else
    Result := PhysicalToLogicalPoint(hWnd, lpPoint);
end;

{ ---- user32: Windows 10 ---- }

function ScreenLogPixelsY: Integer;
var
  DC: HDC;
begin
  DC := GetDC(0);
  Result := GetDeviceCaps(DC, LOGPIXELSY);
  ReleaseDC(0, DC);
  if Result <= 0 then
    Result := USER_DEFAULT_SCREEN_DPI;
end;

function GetDpiForSystem: UINT;
begin
  if Bind(rGetDpiForSystem, pGetDpiForSystem, 'GetDpiForSystem', False) then
    Result := pGetDpiForSystem()
  else
    Result := ScreenLogPixelsY;
end;

function GetSystemDpiForProcess(hProcess: THandle): UINT;
begin
  if Bind(rGetSystemDpiForProcess, pGetSystemDpiForProcess, 'GetSystemDpiForProcess', False) then
    Result := pGetSystemDpiForProcess(hProcess)
  else
    Result := GetDpiForSystem;
end;

function GetDpiForWindow(hwnd: HWND): UINT;
var
  X, Y: UINT;
begin
  if Bind(rGetDpiForWindow, pGetDpiForWindow, 'GetDpiForWindow', False) then
    Result := pGetDpiForWindow(hwnd)
  else if (hwnd <> 0) and (GetCurrentDpiAwareness = DPI_AWARENESS_PER_MONITOR_AWARE) and
    Succeeded(GetDpiForMonitor(MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST), MDT_EFFECTIVE_DPI, X, Y)) then
    Result := Y
  else if GetCurrentDpiAwareness = DPI_AWARENESS_UNAWARE then
    Result := USER_DEFAULT_SCREEN_DPI
  else
    Result := SystemDpi;
end;

function IsDpiScaledMetric(Index: Integer): Boolean;
begin
  case Index of
    SM_CXVSCROLL, SM_CYHSCROLL, SM_CYCAPTION, SM_CXBORDER, SM_CYBORDER,
    SM_CXDLGFRAME, SM_CYDLGFRAME, SM_CYVTHUMB, SM_CXHTHUMB, SM_CXICON,
    SM_CYICON, SM_CXCURSOR, SM_CYCURSOR, SM_CYMENU, SM_CYVSCROLL,
    SM_CXHSCROLL, SM_CXMIN, SM_CYMIN, SM_CXSIZE, SM_CYSIZE, SM_CXFRAME,
    SM_CYFRAME, SM_CXMINTRACK, SM_CYMINTRACK, SM_CXDOUBLECLK, SM_CYDOUBLECLK,
    SM_CXICONSPACING, SM_CYICONSPACING, SM_CXEDGE, SM_CYEDGE,
    SM_CXMINSPACING, SM_CYMINSPACING, SM_CXSMICON, SM_CYSMICON,
    SM_CYSMCAPTION, SM_CXSMSIZE, SM_CYSMSIZE, SM_CXMENUSIZE, SM_CYMENUSIZE,
    SM_CXMINIMIZED, SM_CYMINIMIZED, SM_CXDRAG, SM_CYDRAG, SM_CXMENUCHECK,
    SM_CYMENUCHECK, SM_CXFOCUSBORDER, SM_CYFOCUSBORDER, SM_CXPADDEDBORDER:
      Result := True;
  else
    Result := False;
  end;
end;

function GetSystemMetricsForDpi(nIndex: Integer; dpi: UINT): Integer;
begin
  if Bind(rGetSystemMetricsForDpi, pGetSystemMetricsForDpi, 'GetSystemMetricsForDpi', False) then
    Result := pGetSystemMetricsForDpi(nIndex, dpi)
  else
  begin
    Result := GetSystemMetrics(nIndex);
    if (dpi > 0) and (Integer(dpi) <> SystemDpi) and IsDpiScaledMetric(nIndex) then
      Result := MulDiv(Result, dpi, SystemDpi);
  end;
end;

function AdjustWindowRectExForDpi(var lpRect: TRect; dwStyle: DWORD; bMenu: BOOL;
  dwExStyle: DWORD; dpi: UINT): BOOL;
var
  Frame: TRect;
  Sys: Integer;
begin
  if Bind(rAdjustWindowRectExForDpi, pAdjustWindowRectExForDpi, 'AdjustWindowRectExForDpi', False) then
    Result := pAdjustWindowRectExForDpi(lpRect, dwStyle, bMenu, dwExStyle, dpi)
  else
  begin
    FillChar(Frame, SizeOf(Frame), 0);
    Result := AdjustWindowRectEx(Frame, dwStyle, bMenu, dwExStyle);
    if Result then
    begin
      Sys := SystemDpi;
      if (dpi > 0) and (Integer(dpi) <> Sys) then
      begin
        Frame.Left := MulDiv(Frame.Left, dpi, Sys);
        Frame.Top := MulDiv(Frame.Top, dpi, Sys);
        Frame.Right := MulDiv(Frame.Right, dpi, Sys);
        Frame.Bottom := MulDiv(Frame.Bottom, dpi, Sys);
      end;
      Inc(lpRect.Left, Frame.Left);
      Inc(lpRect.Top, Frame.Top);
      Inc(lpRect.Right, Frame.Right);
      Inc(lpRect.Bottom, Frame.Bottom);
    end;
  end;
end;

procedure ScaleLogFontW(var LF: TLogFontW; M, D: Integer);
begin
  LF.lfHeight := MulDiv(LF.lfHeight, M, D);
  LF.lfWidth := MulDiv(LF.lfWidth, M, D);
end;

function SystemParametersInfoForDpi(uiAction, uiParam: UINT; pvParam: Pointer;
  fWinIni, dpi: UINT): BOOL;
var
  Sys: Integer;
  NCM: PNonClientMetricsW;
  IM: PIconMetricsW;
begin
  if Bind(rSystemParametersInfoForDpi, pSystemParametersInfoForDpi, 'SystemParametersInfoForDpi', False) then
    Result := pSystemParametersInfoForDpi(uiAction, uiParam, pvParam, fWinIni, dpi)
  else
  begin
    Result := SystemParametersInfoW(uiAction, uiParam, pvParam, fWinIni);
    Sys := SystemDpi;
    if Result and (pvParam <> nil) and (dpi > 0) and (Integer(dpi) <> Sys) then
      case uiAction of
        SPI_GETICONTITLELOGFONT:
          ScaleLogFontW(PLogFontW(pvParam)^, dpi, Sys);
        SPI_GETICONMETRICS:
          begin
            IM := pvParam;
            IM.iHorzSpacing := MulDiv(IM.iHorzSpacing, dpi, Sys);
            IM.iVertSpacing := MulDiv(IM.iVertSpacing, dpi, Sys);
            ScaleLogFontW(IM.lfFont, dpi, Sys);
          end;
        SPI_GETNONCLIENTMETRICS:
          begin
            NCM := pvParam;
            NCM.iBorderWidth := MulDiv(NCM.iBorderWidth, dpi, Sys);
            NCM.iScrollWidth := MulDiv(NCM.iScrollWidth, dpi, Sys);
            NCM.iScrollHeight := MulDiv(NCM.iScrollHeight, dpi, Sys);
            NCM.iCaptionWidth := MulDiv(NCM.iCaptionWidth, dpi, Sys);
            NCM.iCaptionHeight := MulDiv(NCM.iCaptionHeight, dpi, Sys);
            ScaleLogFontW(NCM.lfCaptionFont, dpi, Sys);
            NCM.iSmCaptionWidth := MulDiv(NCM.iSmCaptionWidth, dpi, Sys);
            NCM.iSmCaptionHeight := MulDiv(NCM.iSmCaptionHeight, dpi, Sys);
            ScaleLogFontW(NCM.lfSmCaptionFont, dpi, Sys);
            NCM.iMenuWidth := MulDiv(NCM.iMenuWidth, dpi, Sys);
            NCM.iMenuHeight := MulDiv(NCM.iMenuHeight, dpi, Sys);
            ScaleLogFontW(NCM.lfMenuFont, dpi, Sys);
            ScaleLogFontW(NCM.lfStatusFont, dpi, Sys);
            ScaleLogFontW(NCM.lfMessageFont, dpi, Sys);
          end;
      end;
  end;
end;

function EnableNonClientDpiScaling(hwnd: HWND): BOOL;
begin
  if Bind(rEnableNonClientDpiScaling, pEnableNonClientDpiScaling, 'EnableNonClientDpiScaling', False) then
    Result := pEnableNonClientDpiScaling(hwnd)
  else
    Result := False;
end;

function SetProcessDpiAwarenessContext(value: DPI_AWARENESS_CONTEXT): BOOL;
begin
  if Bind(rSetProcessDpiAwarenessContext, pSetProcessDpiAwarenessContext, 'SetProcessDpiAwarenessContext', False) then
    Result := pSetProcessDpiAwarenessContext(value)
  else if (value = DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE) or
    (value = DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2) then
    Result := Succeeded(SetProcessDpiAwareness(PROCESS_PER_MONITOR_DPI_AWARE))
  else if value = DPI_AWARENESS_CONTEXT_SYSTEM_AWARE then
    Result := Succeeded(SetProcessDpiAwareness(PROCESS_SYSTEM_DPI_AWARE))
  else
    Result := False;
end;

function SetThreadDpiAwarenessContext(dpiContext: DPI_AWARENESS_CONTEXT): DPI_AWARENESS_CONTEXT;
begin
  if Bind(rSetThreadDpiAwarenessContext, pSetThreadDpiAwarenessContext, 'SetThreadDpiAwarenessContext', False) then
    Result := pSetThreadDpiAwarenessContext(dpiContext)
  else
    Result := 0;
end;

function SynthesizedContext: DPI_AWARENESS_CONTEXT;
var
  A: Integer;
begin
  if Succeeded(GetProcessDpiAwareness(0, A)) then
    case A of
      PROCESS_PER_MONITOR_DPI_AWARE: Result := DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE;
      PROCESS_SYSTEM_DPI_AWARE: Result := DPI_AWARENESS_CONTEXT_SYSTEM_AWARE;
    else
      Result := DPI_AWARENESS_CONTEXT_UNAWARE;
    end
  else
    Result := DPI_AWARENESS_CONTEXT_UNAWARE;
end;

function GetThreadDpiAwarenessContext: DPI_AWARENESS_CONTEXT;
begin
  if Bind(rGetThreadDpiAwarenessContext, pGetThreadDpiAwarenessContext, 'GetThreadDpiAwarenessContext', False) then
    Result := pGetThreadDpiAwarenessContext()
  else
    Result := SynthesizedContext;
end;

function GetWindowDpiAwarenessContext(hwnd: HWND): DPI_AWARENESS_CONTEXT;
begin
  if Bind(rGetWindowDpiAwarenessContext, pGetWindowDpiAwarenessContext, 'GetWindowDpiAwarenessContext', False) then
    Result := pGetWindowDpiAwarenessContext(hwnd)
  else
    Result := SynthesizedContext;
end;

function PseudoAwareness(value: DPI_AWARENESS_CONTEXT): Integer;
begin
  if (value = DPI_AWARENESS_CONTEXT_UNAWARE) or (value = DPI_AWARENESS_CONTEXT_UNAWARE_GDISCALED) then
    Result := DPI_AWARENESS_UNAWARE
  else if value = DPI_AWARENESS_CONTEXT_SYSTEM_AWARE then
    Result := DPI_AWARENESS_SYSTEM_AWARE
  else if (value = DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE) or
    (value = DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2) then
    Result := DPI_AWARENESS_PER_MONITOR_AWARE
  else
    Result := DPI_AWARENESS_INVALID;
end;

function GetAwarenessFromDpiAwarenessContext(value: DPI_AWARENESS_CONTEXT): Integer;
begin
  if Bind(rGetAwarenessFromDpiAwarenessContext, pGetAwarenessFromDpiAwarenessContext,
    'GetAwarenessFromDpiAwarenessContext', False) then
    Result := pGetAwarenessFromDpiAwarenessContext(value)
  else
    Result := PseudoAwareness(value);
end;

function GetDpiFromDpiAwarenessContext(value: DPI_AWARENESS_CONTEXT): UINT;
begin
  if Bind(rGetDpiFromDpiAwarenessContext, pGetDpiFromDpiAwarenessContext, 'GetDpiFromDpiAwarenessContext', False) then
    Result := pGetDpiFromDpiAwarenessContext(value)
  else
    case GetAwarenessFromDpiAwarenessContext(value) of
      DPI_AWARENESS_UNAWARE: Result := USER_DEFAULT_SCREEN_DPI;
      DPI_AWARENESS_SYSTEM_AWARE: Result := SystemDpi;
    else
      Result := 0;
    end;
end;

function AreDpiAwarenessContextsEqual(dpiContextA, dpiContextB: DPI_AWARENESS_CONTEXT): BOOL;
begin
  if Bind(rAreDpiAwarenessContextsEqual, pAreDpiAwarenessContextsEqual, 'AreDpiAwarenessContextsEqual', False) then
    Result := pAreDpiAwarenessContextsEqual(dpiContextA, dpiContextB)
  else
    Result := (dpiContextA = dpiContextB) or
      ((PseudoAwareness(dpiContextA) <> DPI_AWARENESS_INVALID) and
       (PseudoAwareness(dpiContextA) = PseudoAwareness(dpiContextB)) and
       (dpiContextA <> DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2) and
       (dpiContextB <> DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2));
end;

function IsValidDpiAwarenessContext(value: DPI_AWARENESS_CONTEXT): BOOL;
begin
  if Bind(rIsValidDpiAwarenessContext, pIsValidDpiAwarenessContext, 'IsValidDpiAwarenessContext', False) then
    Result := pIsValidDpiAwarenessContext(value)
  else
    Result := PseudoAwareness(value) <> DPI_AWARENESS_INVALID;
end;

function GetDpiAwarenessContextForProcess(hProcess: THandle): DPI_AWARENESS_CONTEXT;
begin
  if Bind(rGetDpiAwarenessContextForProcess, pGetDpiAwarenessContextForProcess,
    'GetDpiAwarenessContextForProcess', False) then
    Result := pGetDpiAwarenessContextForProcess(hProcess)
  else
    Result := SynthesizedContext;
end;

function SetThreadDpiHostingBehavior(value: Integer): Integer;
begin
  if Bind(rSetThreadDpiHostingBehavior, pSetThreadDpiHostingBehavior, 'SetThreadDpiHostingBehavior', False) then
    Result := pSetThreadDpiHostingBehavior(value)
  else
    Result := DPI_HOSTING_BEHAVIOR_INVALID;
end;

function GetThreadDpiHostingBehavior: Integer;
begin
  if Bind(rGetThreadDpiHostingBehavior, pGetThreadDpiHostingBehavior, 'GetThreadDpiHostingBehavior', False) then
    Result := pGetThreadDpiHostingBehavior()
  else
    Result := DPI_HOSTING_BEHAVIOR_INVALID;
end;

function GetWindowDpiHostingBehavior(hwnd: HWND): Integer;
begin
  if Bind(rGetWindowDpiHostingBehavior, pGetWindowDpiHostingBehavior, 'GetWindowDpiHostingBehavior', False) then
    Result := pGetWindowDpiHostingBehavior(hwnd)
  else
    Result := DPI_HOSTING_BEHAVIOR_INVALID;
end;

function SetDialogDpiChangeBehavior(hDlg: HWND; mask, values: DWORD): BOOL;
begin
  if Bind(rSetDialogDpiChangeBehavior, pSetDialogDpiChangeBehavior, 'SetDialogDpiChangeBehavior', False) then
    Result := pSetDialogDpiChangeBehavior(hDlg, mask, values)
  else
    Result := False;
end;

function GetDialogDpiChangeBehavior(hDlg: HWND): DWORD;
begin
  if Bind(rGetDialogDpiChangeBehavior, pGetDialogDpiChangeBehavior, 'GetDialogDpiChangeBehavior', False) then
    Result := pGetDialogDpiChangeBehavior(hDlg)
  else
    Result := DDC_DEFAULT;
end;

function SetDialogControlDpiChangeBehavior(hWnd: HWND; mask, values: DWORD): BOOL;
begin
  if Bind(rSetDialogControlDpiChangeBehavior, pSetDialogControlDpiChangeBehavior,
    'SetDialogControlDpiChangeBehavior', False) then
    Result := pSetDialogControlDpiChangeBehavior(hWnd, mask, values)
  else
    Result := False;
end;

function GetDialogControlDpiChangeBehavior(hWnd: HWND): DWORD;
begin
  if Bind(rGetDialogControlDpiChangeBehavior, pGetDialogControlDpiChangeBehavior,
    'GetDialogControlDpiChangeBehavior', False) then
    Result := pGetDialogControlDpiChangeBehavior(hWnd)
  else
    Result := DCDC_DEFAULT;
end;

{ ---- shcore: 8.1 ---- }

function GetDpiForMonitor(hmonitor: HMONITOR; dpiType: Integer; out dpiX, dpiY: UINT): HRESULT;
begin
  if Bind(rGetDpiForMonitor, pGetDpiForMonitor, 'GetDpiForMonitor', True) then
    Result := pGetDpiForMonitor(hmonitor, dpiType, dpiX, dpiY)
  else
  begin
    dpiX := SystemDpi;
    dpiY := dpiX;
    Result := S_OK;
  end;
end;

function SetProcessDpiAwareness(value: Integer): HRESULT;
begin
  if Bind(rSetProcessDpiAwareness, pSetProcessDpiAwareness, 'SetProcessDpiAwareness', True) then
    Result := pSetProcessDpiAwareness(value)
  else if value = PROCESS_DPI_UNAWARE then
    Result := S_OK
  else if SetProcessDPIAware then
    Result := S_OK
  else
    Result := E_FAIL;
end;

function GetProcessDpiAwareness(hprocess: THandle; out value: Integer): HRESULT;
begin
  if Bind(rGetProcessDpiAwareness, pGetProcessDpiAwareness, 'GetProcessDpiAwareness', True) then
    Result := pGetProcessDpiAwareness(hprocess, value)
  else
  begin
    if IsProcessDPIAware then
      value := PROCESS_SYSTEM_DPI_AWARE
    else
      value := PROCESS_DPI_UNAWARE;
    Result := S_OK;
  end;
end;

function GetScaleFactorForMonitor(hMon: HMONITOR; out pScale: Integer): HRESULT;
var
  X, Y: UINT;
begin
  if Bind(rGetScaleFactorForMonitor, pGetScaleFactorForMonitor, 'GetScaleFactorForMonitor', True) then
    Result := pGetScaleFactorForMonitor(hMon, pScale)
  else
  begin
    Result := GetDpiForMonitor(hMon, MDT_EFFECTIVE_DPI, X, Y);
    if Succeeded(Result) then
      pScale := MulDiv(Y, 100, USER_DEFAULT_SCREEN_DPI)
    else
      pScale := DEVICE_SCALE_FACTOR_INVALID;
  end;
end;

function GetDpiForShellUIComponent(component: Integer): UINT;
begin
  if Bind(rGetDpiForShellUIComponent, pGetDpiForShellUIComponent, 'GetDpiForShellUIComponent', True) then
    Result := pGetDpiForShellUIComponent(component)
  else
    Result := SystemDpi;
end;

{ ---- helpers ---- }

function GetCurrentDpiAwareness: Integer;
var
  A: Integer;
begin
  if Bind(rGetThreadDpiAwarenessContext, pGetThreadDpiAwarenessContext, 'GetThreadDpiAwarenessContext', False) then
    Result := GetAwarenessFromDpiAwarenessContext(pGetThreadDpiAwarenessContext())
  else if Succeeded(GetProcessDpiAwareness(0, A)) then
    Result := A
  else
    Result := DPI_AWARENESS_UNAWARE;
end;

function IsPerMonitorDpiAware: Boolean;
begin
  Result := GetCurrentDpiAwareness = DPI_AWARENESS_PER_MONITOR_AWARE;
end;

function IsPerMonitorV2DpiAware: Boolean;
begin
  Result := Bind(rGetThreadDpiAwarenessContext, pGetThreadDpiAwarenessContext, 'GetThreadDpiAwarenessContext', False) and
    AreDpiAwarenessContextsEqual(pGetThreadDpiAwarenessContext(), DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);
end;

function SystemDpi: Integer;
begin
  if CachedSystemDpi = 0 then
    CachedSystemDpi := GetDpiForSystem;
  Result := CachedSystemDpi;
end;

function GetDpiForMonitorHandle(Monitor: HMONITOR): Integer;
var
  X, Y: UINT;
begin
  if (Monitor <> 0) and IsPerMonitorDpiAware and
    Succeeded(GetDpiForMonitor(Monitor, MDT_EFFECTIVE_DPI, X, Y)) and (Y > 0) then
    Result := Y
  else if GetCurrentDpiAwareness = DPI_AWARENESS_UNAWARE then
    Result := USER_DEFAULT_SCREEN_DPI
  else
    Result := SystemDpi;
end;

function GetDpiForPoint(const Pt: TPoint): Integer;
begin
  Result := GetDpiForMonitorHandle(MonitorFromPoint(Pt, MONITOR_DEFAULTTONEAREST));
end;

function GetDpiForRect(const R: TRect): Integer;
begin
  Result := GetDpiForMonitorHandle(MonitorFromRect(@R, MONITOR_DEFAULTTONEAREST));
end;

function GetWindowDpi(Wnd: HWND): Integer;
begin
  if Wnd <> 0 then
    Result := GetDpiForWindow(Wnd)
  else
    Result := 0;
  if Result <= 0 then
    if GetCurrentDpiAwareness = DPI_AWARENESS_UNAWARE then
      Result := USER_DEFAULT_SCREEN_DPI
    else
      Result := SystemDpi;
end;

function ScaleByDpi(Value, ToDpi: Integer; FromDpi: Integer): Integer;
begin
  if (ToDpi = FromDpi) or (FromDpi = 0) then
    Result := Value
  else
    Result := MulDiv(Value, ToDpi, FromDpi);
end;

function GetSystemMetricForDpi(Index, Dpi: Integer): Integer;
begin
  if Dpi <= 0 then
    Result := GetSystemMetrics(Index)
  else
    Result := GetSystemMetricsForDpi(Index, Dpi);
end;

procedure LogFontWToA(const W: TLogFontW; var A: TLogFontA);
begin
  Move(W, A, SizeOf(TLogFontW) - SizeOf(W.lfFaceName));
  FillChar(A.lfFaceName, SizeOf(A.lfFaceName), 0);
  WideCharToMultiByte(CP_ACP, 0, W.lfFaceName, -1, A.lfFaceName,
    SizeOf(A.lfFaceName) - 1, nil, nil);
end;

function GetNonClientMetricsForDpi(var Metrics: TNonClientMetricsA; Dpi: Integer): Boolean;
var
  W: TNonClientMetricsW;
begin
  FillChar(W, SizeOf(W), 0);
  W.cbSize := SizeOf(W);
  if Dpi <= 0 then
    Dpi := SystemDpi;
  Result := SystemParametersInfoForDpi(SPI_GETNONCLIENTMETRICS, SizeOf(W), @W, 0, Dpi);
  if Result then
  begin
    FillChar(Metrics, SizeOf(Metrics), 0);
    Metrics.cbSize := SizeOf(Metrics);
    Metrics.iBorderWidth := W.iBorderWidth;
    Metrics.iScrollWidth := W.iScrollWidth;
    Metrics.iScrollHeight := W.iScrollHeight;
    Metrics.iCaptionWidth := W.iCaptionWidth;
    Metrics.iCaptionHeight := W.iCaptionHeight;
    LogFontWToA(W.lfCaptionFont, Metrics.lfCaptionFont);
    Metrics.iSmCaptionWidth := W.iSmCaptionWidth;
    Metrics.iSmCaptionHeight := W.iSmCaptionHeight;
    LogFontWToA(W.lfSmCaptionFont, Metrics.lfSmCaptionFont);
    Metrics.iMenuWidth := W.iMenuWidth;
    Metrics.iMenuHeight := W.iMenuHeight;
    LogFontWToA(W.lfMenuFont, Metrics.lfMenuFont);
    LogFontWToA(W.lfStatusFont, Metrics.lfStatusFont);
    LogFontWToA(W.lfMessageFont, Metrics.lfMessageFont);
  end;
end;

function GetIconTitleFontForDpi(var LogFont: TLogFontA; Dpi: Integer): Boolean;
var
  W: TLogFontW;
begin
  if Dpi <= 0 then
    Dpi := SystemDpi;
  Result := SystemParametersInfoForDpi(SPI_GETICONTITLELOGFONT, SizeOf(W), @W, 0, Dpi);
  if Result then
    LogFontWToA(W, LogFont);
end;

{ ---- shcore, Windows 8 / 8.1: the scale factor of the display ---- }

type
  TFnScaleFactor = function(deviceType: Integer): Integer; stdcall;
  TFnRegisterScaleChange = function(displayDevice: Integer; hwndNotify: HWND; uMsgNotify: UINT;
    out pdwCookie: DWORD): HRESULT; stdcall;
  TFnRevokeScaleChange = function(displayDevice: Integer; dwCookie: DWORD): HRESULT; stdcall;
  TFnRegisterScaleEvent = function(hEvent: THandle; out pdwCookie: DWORD): HRESULT; stdcall;
  TFnUnregisterScaleEvent = function(dwCookie: DWORD): HRESULT; stdcall;

var
  pGetScaleFactorForDevice: TFnScaleFactor;                 rGetScaleFactorForDevice: Boolean;
  pRegisterScaleChangeNotifications: TFnRegisterScaleChange; rRegisterScaleChangeNotifications: Boolean;
  pRevokeScaleChangeNotifications: TFnRevokeScaleChange;     rRevokeScaleChangeNotifications: Boolean;
  pRegisterScaleChangeEvent: TFnRegisterScaleEvent;          rRegisterScaleChangeEvent: Boolean;
  pUnregisterScaleChangeEvent: TFnUnregisterScaleEvent;      rUnregisterScaleChangeEvent: Boolean;

function GetScaleFactorForDevice(deviceType: Integer): Integer; stdcall;
begin
  if Bind(rGetScaleFactorForDevice, pGetScaleFactorForDevice, 'GetScaleFactorForDevice', True) then
    Result := pGetScaleFactorForDevice(deviceType)
  else
    Result := DEVICE_SCALE_FACTOR_INVALID;
end;

function RegisterScaleChangeNotifications(displayDevice: Integer; hwndNotify: HWND;
  uMsgNotify: UINT; out pdwCookie: DWORD): HRESULT; stdcall;
begin
  if Bind(rRegisterScaleChangeNotifications, pRegisterScaleChangeNotifications,
    'RegisterScaleChangeNotifications', True) then
    Result := pRegisterScaleChangeNotifications(displayDevice, hwndNotify, uMsgNotify, pdwCookie)
  else
  begin
    pdwCookie := 0;
    Result := E_NOTIMPL;
  end;
end;

function RevokeScaleChangeNotifications(displayDevice: Integer; dwCookie: DWORD): HRESULT; stdcall;
begin
  if Bind(rRevokeScaleChangeNotifications, pRevokeScaleChangeNotifications,
    'RevokeScaleChangeNotifications', True) then
    Result := pRevokeScaleChangeNotifications(displayDevice, dwCookie)
  else
    Result := E_NOTIMPL;
end;

function RegisterScaleChangeEvent(hEvent: THandle; out pdwCookie: DWORD): HRESULT; stdcall;
begin
  if Bind(rRegisterScaleChangeEvent, pRegisterScaleChangeEvent, 'RegisterScaleChangeEvent', True) then
    Result := pRegisterScaleChangeEvent(hEvent, pdwCookie)
  else
  begin
    pdwCookie := 0;
    Result := E_NOTIMPL;
  end;
end;

function UnregisterScaleChangeEvent(dwCookie: DWORD): HRESULT; stdcall;
begin
  if Bind(rUnregisterScaleChangeEvent, pUnregisterScaleChangeEvent, 'UnregisterScaleChangeEvent', True) then
    Result := pUnregisterScaleChangeEvent(dwCookie)
  else
    Result := E_NOTIMPL;
end;

end.
