{**********************************************************}
{                                                          }
{     Delphi 7 Runtime Library - Modernization             }
{     Desktop Window Manager API (dwmapi.h)                }
{     Windows Vista .. Windows 11                          }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit DwmApi;

{ Translated from dwmapi.h (Windows SDK 10.0.26100).

  dwmapi.dll does not exist before Windows Vista, so every function is bound
  at run time on first use (dwmapi.dll is loaded from the system directory)
  and programs that use this unit still start on Windows XP. When the DLL or
  an export is missing:
    - the HRESULT functions return E_NOTIMPL, except DwmIsCompositionEnabled,
      which returns S_OK with pfEnabled = False (there is no composition);
    - DwmDefWindowProc returns False after SetLastError(ERROR_CALL_NOT_IMPLEMENTED).
  BOOL arguments, and the BOOL fields of DWM_BLURBEHIND and
  DWM_THUMBNAIL_PROPERTIES, are passed to Windows as 0 or 1 (Delphi stores
  True as -1, which some Windows code rejects).

  All structures are byte packed, exactly like dwmapi.h (pshpack1.h). On x86
  this only changes DWM_THUMBNAIL_PROPERTIES (45 bytes) and DWM_TIMING_INFO
  (292 bytes); DWM_BLURBEHIND is 16 bytes on x86. }

{$WEAKPACKAGEUNIT ON}
{$MINENUMSIZE 4}

interface

uses
  Windows, UxTheme;

type
  { MARGINS is declared in UxTheme (dwmapi.h includes uxtheme.h); these are
    aliases of the same type, so values can be shared between both units. }
  {$EXTERNALSYM MARGINS}
  MARGINS = UxTheme.MARGINS;
  {$EXTERNALSYM PMARGINS}
  PMARGINS = UxTheme.PMARGINS;
  TMargins = UxTheme.TMargins;

{ ====== Blur behind ======================================================= }

const
  {$EXTERNALSYM DWM_BB_ENABLE}
  DWM_BB_ENABLE                = $00000001;  // fEnable has been specified
  {$EXTERNALSYM DWM_BB_BLURREGION}
  DWM_BB_BLURREGION            = $00000002;  // hRgnBlur has been specified
  {$EXTERNALSYM DWM_BB_TRANSITIONONMAXIMIZED}
  DWM_BB_TRANSITIONONMAXIMIZED = $00000004;  // fTransitionOnMaximized has been specified

type
  {$EXTERNALSYM _DWM_BLURBEHIND}
  _DWM_BLURBEHIND = packed record
    dwFlags: DWORD;
    fEnable: BOOL;
    hRgnBlur: HRGN;
    fTransitionOnMaximized: BOOL;
  end;
  {$EXTERNALSYM DWM_BLURBEHIND}
  DWM_BLURBEHIND = _DWM_BLURBEHIND;
  {$EXTERNALSYM PDWM_BLURBEHIND}
  PDWM_BLURBEHIND = ^_DWM_BLURBEHIND;
  TDwmBlurBehind = _DWM_BLURBEHIND;
  PDwmBlurBehind = PDWM_BLURBEHIND;

{ ====== Window attributes ================================================= }

type
  {$EXTERNALSYM DWMWINDOWATTRIBUTE}
  DWMWINDOWATTRIBUTE = DWORD;

const
  {$EXTERNALSYM DWMWA_NCRENDERING_ENABLED}
  DWMWA_NCRENDERING_ENABLED         = 1;   // [get] Is non-client rendering enabled/disabled
  {$EXTERNALSYM DWMWA_NCRENDERING_POLICY}
  DWMWA_NCRENDERING_POLICY          = 2;   // [set] DWMNCRENDERINGPOLICY - Non-client rendering policy
  {$EXTERNALSYM DWMWA_TRANSITIONS_FORCEDISABLED}
  DWMWA_TRANSITIONS_FORCEDISABLED   = 3;   // [set] Potentially enable/forcibly disable transitions
  {$EXTERNALSYM DWMWA_ALLOW_NCPAINT}
  DWMWA_ALLOW_NCPAINT               = 4;   // [set] Allow contents rendered in the non-client area to be visible on the DWM-drawn frame.
  {$EXTERNALSYM DWMWA_CAPTION_BUTTON_BOUNDS}
  DWMWA_CAPTION_BUTTON_BOUNDS       = 5;   // [get] Bounds of the caption button area in window-relative space.
  {$EXTERNALSYM DWMWA_NONCLIENT_RTL_LAYOUT}
  DWMWA_NONCLIENT_RTL_LAYOUT        = 6;   // [set] Is non-client content RTL mirrored
  {$EXTERNALSYM DWMWA_FORCE_ICONIC_REPRESENTATION}
  DWMWA_FORCE_ICONIC_REPRESENTATION = 7;   // [set] Force this window to display iconic thumbnails.
  {$EXTERNALSYM DWMWA_FLIP3D_POLICY}
  DWMWA_FLIP3D_POLICY               = 8;   // [set] Designates how Flip3D will treat the window.
  {$EXTERNALSYM DWMWA_EXTENDED_FRAME_BOUNDS}
  DWMWA_EXTENDED_FRAME_BOUNDS       = 9;   // [get] Gets the extended frame bounds rectangle in screen space
  {$EXTERNALSYM DWMWA_HAS_ICONIC_BITMAP}
  DWMWA_HAS_ICONIC_BITMAP           = 10;  // [set] Indicates an available bitmap when there is no better thumbnail representation.
  {$EXTERNALSYM DWMWA_DISALLOW_PEEK}
  DWMWA_DISALLOW_PEEK               = 11;  // [set] Don't invoke Peek on the window.
  {$EXTERNALSYM DWMWA_EXCLUDED_FROM_PEEK}
  DWMWA_EXCLUDED_FROM_PEEK          = 12;  // [set] LivePreview exclusion information
  {$EXTERNALSYM DWMWA_CLOAK}
  DWMWA_CLOAK                       = 13;  // [set] Cloak or uncloak the window
  {$EXTERNALSYM DWMWA_CLOAKED}
  DWMWA_CLOAKED                     = 14;  // [get] Gets the cloaked state of the window
  {$EXTERNALSYM DWMWA_FREEZE_REPRESENTATION}
  DWMWA_FREEZE_REPRESENTATION       = 15;  // [set] BOOL, Force this window to freeze the thumbnail without live update
  {$EXTERNALSYM DWMWA_PASSIVE_UPDATE_MODE}
  DWMWA_PASSIVE_UPDATE_MODE         = 16;  // [set] BOOL, Updates the window only when desktop composition runs for other reasons
  {$EXTERNALSYM DWMWA_USE_HOSTBACKDROPBRUSH}
  DWMWA_USE_HOSTBACKDROPBRUSH       = 17;  // [set] BOOL, Allows the use of host backdrop brushes for the window.
  { Not in the SDK: the undocumented value used for the dark title bar by
    Windows 10 1809 .. 1909 (builds 17763 .. 18363). }
  DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1 = 19;
  {$EXTERNALSYM DWMWA_USE_IMMERSIVE_DARK_MODE}
  DWMWA_USE_IMMERSIVE_DARK_MODE     = 20;  // [set] BOOL, Allows a window to either use the accent color, or dark, according to the user Color Mode preferences.
  {$EXTERNALSYM DWMWA_WINDOW_CORNER_PREFERENCE}
  DWMWA_WINDOW_CORNER_PREFERENCE    = 33;  // [set] WINDOW_CORNER_PREFERENCE, Controls the policy that rounds top-level window corners
  {$EXTERNALSYM DWMWA_BORDER_COLOR}
  DWMWA_BORDER_COLOR                = 34;  // [set] COLORREF, The color of the thin border around a top-level window
  {$EXTERNALSYM DWMWA_CAPTION_COLOR}
  DWMWA_CAPTION_COLOR               = 35;  // [set] COLORREF, The color of the caption
  {$EXTERNALSYM DWMWA_TEXT_COLOR}
  DWMWA_TEXT_COLOR                  = 36;  // [set] COLORREF, The color of the caption text
  {$EXTERNALSYM DWMWA_VISIBLE_FRAME_BORDER_THICKNESS}
  DWMWA_VISIBLE_FRAME_BORDER_THICKNESS = 37; // [get] UINT, width of the visible border around a thick frame window
  {$EXTERNALSYM DWMWA_SYSTEMBACKDROP_TYPE}
  DWMWA_SYSTEMBACKDROP_TYPE         = 38;  // [get, set] SYSTEMBACKDROP_TYPE, Controls the system-drawn backdrop material of a window, including behind the non-client area.
  {$EXTERNALSYM DWMWA_REDIRECTIONBITMAP_ALPHA}
  DWMWA_REDIRECTIONBITMAP_ALPHA     = 39;  // [set] BOOL, GDI redirection bitmap contains premultiplied alpha
  {$EXTERNALSYM DWMWA_BORDER_MARGINS}
  DWMWA_BORDER_MARGINS              = 40;  // [set] FRAME_MARGIN, Override location of window border (distance from each edge)
  {$EXTERNALSYM DWMWA_LAST}
  DWMWA_LAST                        = 41;  // value of Windows SDK 10.0.26100

  { DWMWA_BORDER_COLOR, DWMWA_CAPTION_COLOR, DWMWA_TEXT_COLOR special values }
  {$EXTERNALSYM DWMWA_COLOR_DEFAULT}
  DWMWA_COLOR_DEFAULT = $FFFFFFFF;
  {$EXTERNALSYM DWMWA_COLOR_NONE}
  DWMWA_COLOR_NONE    = $FFFFFFFE;

type
  {$EXTERNALSYM DWM_WINDOW_CORNER_PREFERENCE}
  DWM_WINDOW_CORNER_PREFERENCE = DWORD;

const
  {$EXTERNALSYM DWMWCP_DEFAULT}
  DWMWCP_DEFAULT    = 0;  // Let the system decide whether or not to round window corners
  {$EXTERNALSYM DWMWCP_DONOTROUND}
  DWMWCP_DONOTROUND = 1;  // Never round window corners
  {$EXTERNALSYM DWMWCP_ROUND}
  DWMWCP_ROUND      = 2;  // Round the corners if appropriate
  {$EXTERNALSYM DWMWCP_ROUNDSMALL}
  DWMWCP_ROUNDSMALL = 3;  // Round the corners if appropriate, with a small radius

type
  {$EXTERNALSYM DWM_SYSTEMBACKDROP_TYPE}
  DWM_SYSTEMBACKDROP_TYPE = DWORD;

const
  {$EXTERNALSYM DWMSBT_AUTO}
  DWMSBT_AUTO            = 0;  // [Default] Let DWM automatically decide the system-drawn backdrop for this window.
  {$EXTERNALSYM DWMSBT_NONE}
  DWMSBT_NONE            = 1;  // Do not draw any system backdrop.
  {$EXTERNALSYM DWMSBT_MAINWINDOW}
  DWMSBT_MAINWINDOW      = 2;  // Draw the backdrop material effect corresponding to a long-lived window (Mica).
  {$EXTERNALSYM DWMSBT_TRANSIENTWINDOW}
  DWMSBT_TRANSIENTWINDOW = 3;  // Draw the backdrop material effect corresponding to a transient window (Acrylic).
  {$EXTERNALSYM DWMSBT_TABBEDWINDOW}
  DWMSBT_TABBEDWINDOW    = 4;  // Draw the backdrop material effect corresponding to a window with a tabbed title bar.

type
  {$EXTERNALSYM DWMNCRENDERINGPOLICY}
  DWMNCRENDERINGPOLICY = DWORD;

const
  {$EXTERNALSYM DWMNCRP_USEWINDOWSTYLE}
  DWMNCRP_USEWINDOWSTYLE = 0;  // Enable/disable non-client rendering based on window style
  {$EXTERNALSYM DWMNCRP_DISABLED}
  DWMNCRP_DISABLED       = 1;  // Disabled non-client rendering; window style is ignored
  {$EXTERNALSYM DWMNCRP_ENABLED}
  DWMNCRP_ENABLED        = 2;  // Enabled non-client rendering; window style is ignored
  {$EXTERNALSYM DWMNCRP_LAST}
  DWMNCRP_LAST           = 3;

type
  {$EXTERNALSYM DWMFLIP3DWINDOWPOLICY}
  DWMFLIP3DWINDOWPOLICY = DWORD;

const
  {$EXTERNALSYM DWMFLIP3D_DEFAULT}
  DWMFLIP3D_DEFAULT      = 0;  // Hide or include the window in Flip3D based on window style and visibility.
  {$EXTERNALSYM DWMFLIP3D_EXCLUDEBELOW}
  DWMFLIP3D_EXCLUDEBELOW = 1;  // Display the window under Flip3D and disabled.
  {$EXTERNALSYM DWMFLIP3D_EXCLUDEABOVE}
  DWMFLIP3D_EXCLUDEABOVE = 2;  // Display the window above Flip3D and enabled.
  {$EXTERNALSYM DWMFLIP3D_LAST}
  DWMFLIP3D_LAST         = 3;

  { DWMWA_CLOAKED values }
  {$EXTERNALSYM DWM_CLOAKED_APP}
  DWM_CLOAKED_APP       = $00000001;
  {$EXTERNALSYM DWM_CLOAKED_SHELL}
  DWM_CLOAKED_SHELL     = $00000002;
  {$EXTERNALSYM DWM_CLOAKED_INHERITED}
  DWM_CLOAKED_INHERITED = $00000004;

{ ====== Thumbnails ======================================================== }

type
  {$EXTERNALSYM HTHUMBNAIL}
  HTHUMBNAIL = THandle;
  {$EXTERNALSYM PHTHUMBNAIL}
  PHTHUMBNAIL = ^HTHUMBNAIL;

const
  { DWM_THUMBNAIL_PROPERTIES.dwFlags }
  {$EXTERNALSYM DWM_TNP_RECTDESTINATION}
  DWM_TNP_RECTDESTINATION      = $00000001;  // A value for the "rcDestination" member has been specified.
  {$EXTERNALSYM DWM_TNP_RECTSOURCE}
  DWM_TNP_RECTSOURCE           = $00000002;  // A value for the "rcSource" member has been specified.
  {$EXTERNALSYM DWM_TNP_OPACITY}
  DWM_TNP_OPACITY              = $00000004;  // A value for the "opacity" member has been specified.
  {$EXTERNALSYM DWM_TNP_VISIBLE}
  DWM_TNP_VISIBLE              = $00000008;  // A value for the "fVisible" member has been specified.
  {$EXTERNALSYM DWM_TNP_SOURCECLIENTAREAONLY}
  DWM_TNP_SOURCECLIENTAREAONLY = $00000010;  // A value for the "fSourceClientAreaOnly" member has been specified.

type
  {$EXTERNALSYM _DWM_THUMBNAIL_PROPERTIES}
  _DWM_THUMBNAIL_PROPERTIES = packed record
    dwFlags: DWORD;               // Specifies which members of this struct have been specified
    rcDestination: TRect;         // The area in the destination window where the thumbnail will be rendered
    rcSource: TRect;              // The region of the source window to use as the thumbnail.
    opacity: Byte;                // The opacity with which to render the thumbnail. 0 is fully transparent, 255 fully opaque
    fVisible: BOOL;               // Whether the thumbnail should be visible.  The default is FALSE
    fSourceClientAreaOnly: BOOL;  // Whether only the client area of the source window should be included in the thumbnail.
  end;
  {$EXTERNALSYM DWM_THUMBNAIL_PROPERTIES}
  DWM_THUMBNAIL_PROPERTIES = _DWM_THUMBNAIL_PROPERTIES;
  {$EXTERNALSYM PDWM_THUMBNAIL_PROPERTIES}
  PDWM_THUMBNAIL_PROPERTIES = ^_DWM_THUMBNAIL_PROPERTIES;
  TDwmThumbnailProperties = _DWM_THUMBNAIL_PROPERTIES;
  PDwmThumbnailProperties = PDWM_THUMBNAIL_PROPERTIES;

{ ====== Composition timing ================================================ }

type
  { ULONGLONG values are declared as Int64 (Delphi 7 has no usable UInt64). }
  {$EXTERNALSYM DWM_FRAME_COUNT}
  DWM_FRAME_COUNT = Int64;
  {$EXTERNALSYM QPC_TIME}
  QPC_TIME = Int64;

  {$EXTERNALSYM _UNSIGNED_RATIO}
  _UNSIGNED_RATIO = packed record
    uiNumerator: Cardinal;
    uiDenominator: Cardinal;
  end;
  {$EXTERNALSYM UNSIGNED_RATIO}
  UNSIGNED_RATIO = _UNSIGNED_RATIO;
  TUnsignedRatio = _UNSIGNED_RATIO;

  {$EXTERNALSYM _DWM_TIMING_INFO}
  _DWM_TIMING_INFO = packed record
    cbSize: Cardinal;
    rateRefresh: UNSIGNED_RATIO;         // Monitor refresh rate
    qpcRefreshPeriod: QPC_TIME;          // Actual period
    rateCompose: UNSIGNED_RATIO;         // composition rate
    qpcVBlank: QPC_TIME;                 // QPC time at a VSync interupt
    cRefresh: DWM_FRAME_COUNT;           // DWM refresh count of the last vsync
    cDXRefresh: UINT;                    // DX refresh count at the last Vsync Interupt
    qpcCompose: QPC_TIME;                // QPC time at a compose time.
    cFrame: DWM_FRAME_COUNT;             // Frame number that was composed at qpcCompose
    cDXPresent: UINT;                    // The present number DX uses to identify renderer frames
    cRefreshFrame: DWM_FRAME_COUNT;      // Refresh count of the frame that was composed at qpcCompose
    cFrameSubmitted: DWM_FRAME_COUNT;    // DWM frame number that was last submitted
    cDXPresentSubmitted: UINT;           // DX Present number that was last submitted
    cFrameConfirmed: DWM_FRAME_COUNT;    // DWM frame number that was last confirmed presented
    cDXPresentConfirmed: UINT;           // DX Present number that was last confirmed presented
    cRefreshConfirmed: DWM_FRAME_COUNT;  // The target refresh count of the last frame confirmed completed by the GPU
    cDXRefreshConfirmed: UINT;           // DX refresh count when the frame was confirmed presented
    cFramesLate: DWM_FRAME_COUNT;        // Number of frames the DWM presented late
    cFramesOutstanding: UINT;            // the number of composition frames that have been issued but not confirmed completed
    cFrameDisplayed: DWM_FRAME_COUNT;    // Last frame displayed
    qpcFrameDisplayed: QPC_TIME;         // QPC time of the composition pass when the frame was displayed
    cRefreshFrameDisplayed: DWM_FRAME_COUNT; // Count of the VSync when the frame should have become visible
    cFrameComplete: DWM_FRAME_COUNT;     // ID of the the last frame marked complete (starts at 0)
    qpcFrameComplete: QPC_TIME;          // QPC time when the last frame was marked complete
    cFramePending: DWM_FRAME_COUNT;      // ID of the the last frame marked pending (starts at 0)
    qpcFramePending: QPC_TIME;           // QPC time when the last frame was marked pending
    cFramesDisplayed: DWM_FRAME_COUNT;   // number of unique frames displayed
    cFramesComplete: DWM_FRAME_COUNT;    // number of new completed frames that have been received
    cFramesPending: DWM_FRAME_COUNT;     // number of new frames submitted to DX but not yet complete
    cFramesAvailable: DWM_FRAME_COUNT;   // number of frames available but not displayed, used or dropped
    cFramesDropped: DWM_FRAME_COUNT;     // number of rendered frames that were never displayed because composition occured too late
    cFramesMissed: DWM_FRAME_COUNT;      // number of times an old frame was composed when a new frame should have been used but was not available
    cRefreshNextDisplayed: DWM_FRAME_COUNT; // the refresh at which the next frame is scheduled to be displayed
    cRefreshNextPresented: DWM_FRAME_COUNT; // the refresh at which the next DX present is scheduled to be displayed
    cRefreshesDisplayed: DWM_FRAME_COUNT;   // total number of refreshes worth of content for this HWND that have been displayed by the DWM since DwmSetPresentParameters was called
    cRefreshesPresented: DWM_FRAME_COUNT;   // total number of refreshes worth of content that have been presented by the application since DwmSetPresentParameters was called
    cRefreshStarted: DWM_FRAME_COUNT;    // The actual refresh # when content for this window started to be displayed
    cPixelsReceived: Int64;              // Total number of pixels DX redirected to the DWM.
    cPixelsDrawn: Int64;                 // Total number of pixels drawn.
    cBuffersEmpty: DWM_FRAME_COUNT;      // The number of buffers in the flipchain that are empty.
  end;
  {$EXTERNALSYM DWM_TIMING_INFO}
  DWM_TIMING_INFO = _DWM_TIMING_INFO;
  TDwmTimingInfo = _DWM_TIMING_INFO;
  PDwmTimingInfo = ^_DWM_TIMING_INFO;

const
  { DwmEnableComposition }
  {$EXTERNALSYM DWM_EC_DISABLECOMPOSITION}
  DWM_EC_DISABLECOMPOSITION = 0;
  {$EXTERNALSYM DWM_EC_ENABLECOMPOSITION}
  DWM_EC_ENABLECOMPOSITION  = 1;

  { DwmSetIconicThumbnail / DwmSetIconicLivePreviewBitmap }
  {$EXTERNALSYM DWM_SIT_DISPLAYFRAME}
  DWM_SIT_DISPLAYFRAME      = $00000001;  // Display a window frame around the provided bitmap

{ ====== Functions (dwmapi.dll, Windows Vista unless noted) ================= }

{ Fallback: False (SetLastError(ERROR_CALL_NOT_IMPLEMENTED)) and plResult = 0. }
{$EXTERNALSYM DwmDefWindowProc}
function DwmDefWindowProc(hWnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM;
  var plResult: LRESULT): BOOL; stdcall;
{$EXTERNALSYM DwmEnableBlurBehindWindow}
function DwmEnableBlurBehindWindow(hWnd: HWND; const pBlurBehind: TDwmBlurBehind): HRESULT; stdcall;
{ Deprecated since Windows 8 (composition can no longer be disabled). }
{$EXTERNALSYM DwmEnableComposition}
function DwmEnableComposition(uCompositionAction: UINT): HRESULT; stdcall;
{$EXTERNALSYM DwmEnableMMCSS}
function DwmEnableMMCSS(fEnableMMCSS: BOOL): HRESULT; stdcall;
{$EXTERNALSYM DwmExtendFrameIntoClientArea}
function DwmExtendFrameIntoClientArea(hWnd: HWND; const pMarInset: TMargins): HRESULT; stdcall;
{$EXTERNALSYM DwmFlush}
function DwmFlush: HRESULT; stdcall;
{$EXTERNALSYM DwmGetColorizationColor}
function DwmGetColorizationColor(out pcrColorization: DWORD; out pfOpaqueBlend: BOOL): HRESULT; stdcall;
{ Set pTimingInfo.cbSize := SizeOf(TDwmTimingInfo) first. hwnd = 0 for the
  composition timing of the desktop. }
{$EXTERNALSYM DwmGetCompositionTimingInfo}
function DwmGetCompositionTimingInfo(hwnd: HWND; var pTimingInfo: TDwmTimingInfo): HRESULT; stdcall;
{$EXTERNALSYM DwmGetWindowAttribute}
function DwmGetWindowAttribute(hwnd: HWND; dwAttribute: DWORD; pvAttribute: Pointer;
  cbAttribute: DWORD): HRESULT; stdcall;
{ Fallback: S_OK and pfEnabled = False. Always True on Windows 8 and later. }
{$EXTERNALSYM DwmIsCompositionEnabled}
function DwmIsCompositionEnabled(out pfEnabled: BOOL): HRESULT; stdcall;
{$EXTERNALSYM DwmQueryThumbnailSourceSize}
function DwmQueryThumbnailSourceSize(hThumbnail: HTHUMBNAIL; out pSize: TSize): HRESULT; stdcall;
{$EXTERNALSYM DwmRegisterThumbnail}
function DwmRegisterThumbnail(hwndDestination: HWND; hwndSource: HWND;
  out phThumbnailId: HTHUMBNAIL): HRESULT; stdcall;
{$EXTERNALSYM DwmSetWindowAttribute}
function DwmSetWindowAttribute(hwnd: HWND; dwAttribute: DWORD; pvAttribute: Pointer;
  cbAttribute: DWORD): HRESULT; stdcall;
{$EXTERNALSYM DwmUnregisterThumbnail}
function DwmUnregisterThumbnail(hThumbnailId: HTHUMBNAIL): HRESULT; stdcall;
{$EXTERNALSYM DwmUpdateThumbnailProperties}
function DwmUpdateThumbnailProperties(hThumbnailId: HTHUMBNAIL;
  const ptnProperties: TDwmThumbnailProperties): HRESULT; stdcall;
{ Windows 7 }
{$EXTERNALSYM DwmSetIconicThumbnail}
function DwmSetIconicThumbnail(hwnd: HWND; hbmp: HBITMAP; dwSITFlags: DWORD): HRESULT; stdcall;
{ Windows 7; pptClient may be nil }
{$EXTERNALSYM DwmSetIconicLivePreviewBitmap}
function DwmSetIconicLivePreviewBitmap(hwnd: HWND; hbmp: HBITMAP; pptClient: PPoint;
  dwSITFlags: DWORD): HRESULT; stdcall;
{ Windows 7 }
{$EXTERNALSYM DwmInvalidateIconicBitmaps}
function DwmInvalidateIconicBitmaps(hwnd: HWND): HRESULT; stdcall;
{ Windows 7 }
{$EXTERNALSYM DwmGetTransportAttributes}
function DwmGetTransportAttributes(out pfIsRemoting: BOOL; out pfIsConnected: BOOL;
  out pDwGeneration: DWORD): HRESULT; stdcall;

{ ====== Helpers (not in the SDK) ========================================== }

{ True when desktop composition is enabled (always on Windows 8 and later,
  never before Windows Vista). }
function DwmCompositionEnabled: Boolean;

{ Asks DWM to draw the non-client area of Wnd (title bar) dark or light.
  Uses DWMWA_USE_IMMERSIVE_DARK_MODE (20, Windows 10 20H1 and later) and, if
  that fails, the pre-20H1 value 19 (Windows 10 1809 .. 1909). No effect on
  older systems. }
procedure SetWindowDarkMode(Wnd: HWND; Dark: Boolean);

{ Windows 11: rounded corner policy of a top-level window (DWMWCP_*). No
  effect on older systems. }
procedure SetWindowCornerPreference(Wnd: HWND; Pref: Integer);

{ Bounds of the visible window frame in screen coordinates, without the
  invisible resize borders of Windows 10/11 (DWMWA_EXTENDED_FRAME_BOUNDS).
  Falls back to GetWindowRect (no DWM, composition off, or not available).
  Returns False only when both fail. }
function GetWindowExtendedFrameBounds(Wnd: HWND; var R: TRect): Boolean;

{ ---- Windows 8 .. 11 additions (dwmapi.h, Windows SDK 10.0.26100) ----
  Bound at run time as the functions above; when Windows lacks one, an HRESULT function returns
  E_NOTIMPL, a BOOL one False with ERROR_CALL_NOT_IMPLEMENTED. }

const
  { DwmTransitionOwnedWindow target (DWMTRANSITION_OWNEDWINDOW_TARGET) }
  {$EXTERNALSYM DWMTRANSITION_OWNEDWINDOW_NULL}
  DWMTRANSITION_OWNEDWINDOW_NULL       = -1;
  {$EXTERNALSYM DWMTRANSITION_OWNEDWINDOW_REPOSITION}
  DWMTRANSITION_OWNEDWINDOW_REPOSITION = 0;

{ Windows 10. Animates an owned window (a flyout) the way the system animates its own }
{$EXTERNALSYM DwmTransitionOwnedWindow}
function DwmTransitionOwnedWindow(hwnd: HWND; target: Integer): BOOL; stdcall;

const
  { DwmShowContact eShowContact (DWM_SHOWCONTACT) }
  {$EXTERNALSYM DWMSC_DOWN}
  DWMSC_DOWN      = $00000001;
  {$EXTERNALSYM DWMSC_UP}
  DWMSC_UP        = $00000002;
  {$EXTERNALSYM DWMSC_DRAG}
  DWMSC_DRAG      = $00000004;
  {$EXTERNALSYM DWMSC_HOLD}
  DWMSC_HOLD      = $00000008;
  {$EXTERNALSYM DWMSC_PENBARREL}
  DWMSC_PENBARREL = $00000010;
  {$EXTERNALSYM DWMSC_NONE}
  DWMSC_NONE      = $00000000;
  {$EXTERNALSYM DWMSC_ALL}
  DWMSC_ALL       = DWORD($FFFFFFFF);

  { DwmRenderGesture gt (GESTURE_TYPE) }
  {$EXTERNALSYM GT_PEN_TAP}
  GT_PEN_TAP                 = 0;
  {$EXTERNALSYM GT_PEN_DOUBLETAP}
  GT_PEN_DOUBLETAP           = 1;
  {$EXTERNALSYM GT_PEN_RIGHTTAP}
  GT_PEN_RIGHTTAP            = 2;
  {$EXTERNALSYM GT_PEN_PRESSANDHOLD}
  GT_PEN_PRESSANDHOLD        = 3;
  {$EXTERNALSYM GT_PEN_PRESSANDHOLDABORT}
  GT_PEN_PRESSANDHOLDABORT   = 4;
  {$EXTERNALSYM GT_TOUCH_TAP}
  GT_TOUCH_TAP               = 5;
  {$EXTERNALSYM GT_TOUCH_DOUBLETAP}
  GT_TOUCH_DOUBLETAP         = 6;
  {$EXTERNALSYM GT_TOUCH_RIGHTTAP}
  GT_TOUCH_RIGHTTAP          = 7;
  {$EXTERNALSYM GT_TOUCH_PRESSANDHOLD}
  GT_TOUCH_PRESSANDHOLD      = 8;
  {$EXTERNALSYM GT_TOUCH_PRESSANDHOLDABORT}
  GT_TOUCH_PRESSANDHOLDABORT = 9;
  {$EXTERNALSYM GT_TOUCH_PRESSANDTAP}
  GT_TOUCH_PRESSANDTAP       = 10;

{ Windows 8. The visual feedback of a contact the program handles itself }
{$EXTERNALSYM DwmShowContact}
function DwmShowContact(dwPointerID: DWORD; eShowContact: DWORD): HRESULT; stdcall;
{ Windows 8. The feedback of a gesture (pdwPointerID and pPoints: the first of cContacts) }
{$EXTERNALSYM DwmRenderGesture}
function DwmRenderGesture(gt: Integer; cContacts: UINT; const pdwPointerID: DWORD;
  const pPoints: TPoint): HRESULT; stdcall;
{ Windows 8. The contact feedback follows ptTether while fEnable }
{$EXTERNALSYM DwmTetherContact}
function DwmTetherContact(dwPointerID: DWORD; fEnable: BOOL; ptTether: TPoint): HRESULT; stdcall;

const
  { DwmGetUnmetTabRequirements value (DWM_TAB_WINDOW_REQUIREMENTS) }
  {$EXTERNALSYM DWMTWR_NONE}
  DWMTWR_NONE                  = $0000;
  {$EXTERNALSYM DWMTWR_IMPLEMENTED_BY_SYSTEM}
  DWMTWR_IMPLEMENTED_BY_SYSTEM = $0001;
  {$EXTERNALSYM DWMTWR_WINDOW_RELATIONSHIP}
  DWMTWR_WINDOW_RELATIONSHIP   = $0002;
  {$EXTERNALSYM DWMTWR_WINDOW_STYLES}
  DWMTWR_WINDOW_STYLES         = $0004;
  {$EXTERNALSYM DWMTWR_WINDOW_REGION}
  DWMTWR_WINDOW_REGION         = $0008;
  {$EXTERNALSYM DWMTWR_WINDOW_DWM_ATTRIBUTES}
  DWMTWR_WINDOW_DWM_ATTRIBUTES = $0010;
  {$EXTERNALSYM DWMTWR_WINDOW_MARGINS}
  DWMTWR_WINDOW_MARGINS        = $0020;
  {$EXTERNALSYM DWMTWR_TABBING_ENABLED}
  DWMTWR_TABBING_ENABLED       = $0040;
  {$EXTERNALSYM DWMTWR_USER_POLICY}
  DWMTWR_USER_POLICY           = $0080;
  {$EXTERNALSYM DWMTWR_GROUP_POLICY}
  DWMTWR_GROUP_POLICY          = $0100;
  {$EXTERNALSYM DWMTWR_APP_COMPAT}
  DWMTWR_APP_COMPAT            = $0200;

{ Windows 11 22H2. Why a window cannot be a tab of the system's window tabbing (DWMTWR_* flags) }
{$EXTERNALSYM DwmGetUnmetTabRequirements}
function DwmGetUnmetTabRequirements(appWindow: HWND; out value: DWORD): HRESULT; stdcall;

implementation

{ ---- run-time binding ---- }

const
  dwmlib = 'dwmapi.dll';

var
  DwmModule: HMODULE;
  DwmLoaded: Boolean;
  DwmDefWindowProcProc: Pointer;
  DwmEnableBlurBehindWindowProc: Pointer;
  DwmEnableCompositionProc: Pointer;
  DwmEnableMMCSSProc: Pointer;
  DwmExtendFrameIntoClientAreaProc: Pointer;
  DwmFlushProc: Pointer;
  DwmGetColorizationColorProc: Pointer;
  DwmGetCompositionTimingInfoProc: Pointer;
  DwmGetWindowAttributeProc: Pointer;
  DwmIsCompositionEnabledProc: Pointer;
  DwmQueryThumbnailSourceSizeProc: Pointer;
  DwmRegisterThumbnailProc: Pointer;
  DwmSetWindowAttributeProc: Pointer;
  DwmUnregisterThumbnailProc: Pointer;
  DwmUpdateThumbnailPropertiesProc: Pointer;
  DwmSetIconicThumbnailProc: Pointer;
  DwmSetIconicLivePreviewBitmapProc: Pointer;
  DwmInvalidateIconicBitmapsProc: Pointer;
  DwmGetTransportAttributesProc: Pointer;

type
  TDwmDefWindowProcFn = function(hWnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM;
    var plResult: LRESULT): BOOL; stdcall;
  TDwmHwndPtrFn = function(hWnd: HWND; p: Pointer): HRESULT; stdcall;
  TDwmUIntFn = function(Value: UINT): HRESULT; stdcall;
  TDwmVoidFn = function: HRESULT; stdcall;
  TDwmGetColorizationColorFn = function(out pcrColorization: DWORD;
    out pfOpaqueBlend: BOOL): HRESULT; stdcall;
  TDwmAttributeFn = function(hwnd: HWND; dwAttribute: DWORD; pvAttribute: Pointer;
    cbAttribute: DWORD): HRESULT; stdcall;
  TDwmIsCompositionEnabledFn = function(out pfEnabled: BOOL): HRESULT; stdcall;
  TDwmQueryThumbnailSourceSizeFn = function(hThumbnail: HTHUMBNAIL;
    out pSize: TSize): HRESULT; stdcall;
  TDwmRegisterThumbnailFn = function(hwndDestination: HWND; hwndSource: HWND;
    out phThumbnailId: HTHUMBNAIL): HRESULT; stdcall;
  TDwmThumbnailFn = function(hThumbnailId: HTHUMBNAIL): HRESULT; stdcall;
  TDwmUpdateThumbnailPropertiesFn = function(hThumbnailId: HTHUMBNAIL;
    ptnProperties: PDwmThumbnailProperties): HRESULT; stdcall;
  TDwmSetIconicThumbnailFn = function(hwnd: HWND; hbmp: HBITMAP;
    dwSITFlags: DWORD): HRESULT; stdcall;
  TDwmSetIconicLivePreviewBitmapFn = function(hwnd: HWND; hbmp: HBITMAP;
    pptClient: PPoint; dwSITFlags: DWORD): HRESULT; stdcall;
  TDwmHwndFn = function(hwnd: HWND): HRESULT; stdcall;
  TDwmGetTransportAttributesFn = function(out pfIsRemoting: BOOL;
    out pfIsConnected: BOOL; out pDwGeneration: DWORD): HRESULT; stdcall;

{ dwmapi.dll is loaded once, from the system directory only (it is not a
  known DLL, so this avoids search-order planting), and never released. A
  missing DLL is remembered; a function pointer is cached once found. }
function GetDwmProc(var Proc: Pointer; Name: PChar): Boolean;
var
  Path: array[0..MAX_PATH + 16] of Char;
  Len: UINT;
begin
  if Proc = nil then
  begin
    if not DwmLoaded then
    begin
      Len := GetSystemDirectory(Path, MAX_PATH);
      if (Len > 0) and (Len < MAX_PATH) then
      begin
        lstrcat(Path, '\' + dwmlib);
        DwmModule := LoadLibrary(Path);
      end;
      DwmLoaded := True;
    end;
    if DwmModule <> 0 then
      Proc := GetProcAddress(DwmModule, Name);
  end;
  Result := Proc <> nil;
end;

{ Delphi passes True as -1 in a BOOL; some Windows code only accepts TRUE
  (1), so BOOL arguments and BOOL fields of input records are passed as 0/1. }
function DwmBoolArg(Value: BOOL): Integer;
begin
  if Value then
    Result := 1
  else
    Result := 0;
end;

function DwmDefWindowProc(hWnd: HWND; msg: UINT; wParam: WPARAM; lParam: LPARAM;
  var plResult: LRESULT): BOOL; stdcall;
begin
  if GetDwmProc(DwmDefWindowProcProc, 'DwmDefWindowProc') then
    Result := TDwmDefWindowProcFn(DwmDefWindowProcProc)(hWnd, msg, wParam, lParam, plResult)
  else
  begin
    plResult := 0;
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := False;
  end;
end;

function DwmEnableBlurBehindWindow(hWnd: HWND; const pBlurBehind: TDwmBlurBehind): HRESULT; stdcall;
var
  BlurBehind: TDwmBlurBehind;
begin
  if GetDwmProc(DwmEnableBlurBehindWindowProc, 'DwmEnableBlurBehindWindow') then
  begin
    BlurBehind := pBlurBehind;
    Integer(BlurBehind.fEnable) := DwmBoolArg(BlurBehind.fEnable);
    Integer(BlurBehind.fTransitionOnMaximized) := DwmBoolArg(BlurBehind.fTransitionOnMaximized);
    Result := TDwmHwndPtrFn(DwmEnableBlurBehindWindowProc)(hWnd, @BlurBehind);
  end
  else
    Result := E_NOTIMPL;
end;

function DwmEnableComposition(uCompositionAction: UINT): HRESULT; stdcall;
begin
  if GetDwmProc(DwmEnableCompositionProc, 'DwmEnableComposition') then
    Result := TDwmUIntFn(DwmEnableCompositionProc)(uCompositionAction)
  else
    Result := E_NOTIMPL;
end;

function DwmEnableMMCSS(fEnableMMCSS: BOOL): HRESULT; stdcall;
begin
  if GetDwmProc(DwmEnableMMCSSProc, 'DwmEnableMMCSS') then
    Result := TDwmUIntFn(DwmEnableMMCSSProc)(DwmBoolArg(fEnableMMCSS))
  else
    Result := E_NOTIMPL;
end;

function DwmExtendFrameIntoClientArea(hWnd: HWND; const pMarInset: TMargins): HRESULT; stdcall;
begin
  if GetDwmProc(DwmExtendFrameIntoClientAreaProc, 'DwmExtendFrameIntoClientArea') then
    Result := TDwmHwndPtrFn(DwmExtendFrameIntoClientAreaProc)(hWnd, @pMarInset)
  else
    Result := E_NOTIMPL;
end;

function DwmFlush: HRESULT; stdcall;
begin
  if GetDwmProc(DwmFlushProc, 'DwmFlush') then
    Result := TDwmVoidFn(DwmFlushProc)()
  else
    Result := E_NOTIMPL;
end;

function DwmGetColorizationColor(out pcrColorization: DWORD; out pfOpaqueBlend: BOOL): HRESULT; stdcall;
begin
  if GetDwmProc(DwmGetColorizationColorProc, 'DwmGetColorizationColor') then
    Result := TDwmGetColorizationColorFn(DwmGetColorizationColorProc)(pcrColorization,
      pfOpaqueBlend)
  else
  begin
    pcrColorization := 0;
    pfOpaqueBlend := False;
    Result := E_NOTIMPL;
  end;
end;

function DwmGetCompositionTimingInfo(hwnd: HWND; var pTimingInfo: TDwmTimingInfo): HRESULT; stdcall;
begin
  if GetDwmProc(DwmGetCompositionTimingInfoProc, 'DwmGetCompositionTimingInfo') then
    Result := TDwmHwndPtrFn(DwmGetCompositionTimingInfoProc)(hwnd, @pTimingInfo)
  else
    Result := E_NOTIMPL;
end;

function DwmGetWindowAttribute(hwnd: HWND; dwAttribute: DWORD; pvAttribute: Pointer;
  cbAttribute: DWORD): HRESULT; stdcall;
begin
  if GetDwmProc(DwmGetWindowAttributeProc, 'DwmGetWindowAttribute') then
    Result := TDwmAttributeFn(DwmGetWindowAttributeProc)(hwnd, dwAttribute, pvAttribute,
      cbAttribute)
  else
    Result := E_NOTIMPL;
end;

function DwmIsCompositionEnabled(out pfEnabled: BOOL): HRESULT; stdcall;
begin
  if GetDwmProc(DwmIsCompositionEnabledProc, 'DwmIsCompositionEnabled') then
    Result := TDwmIsCompositionEnabledFn(DwmIsCompositionEnabledProc)(pfEnabled)
  else
  begin
    pfEnabled := False;
    Result := S_OK;
  end;
end;

function DwmQueryThumbnailSourceSize(hThumbnail: HTHUMBNAIL; out pSize: TSize): HRESULT; stdcall;
begin
  if GetDwmProc(DwmQueryThumbnailSourceSizeProc, 'DwmQueryThumbnailSourceSize') then
    Result := TDwmQueryThumbnailSourceSizeFn(DwmQueryThumbnailSourceSizeProc)(hThumbnail, pSize)
  else
  begin
    pSize.cx := 0;
    pSize.cy := 0;
    Result := E_NOTIMPL;
  end;
end;

function DwmRegisterThumbnail(hwndDestination: HWND; hwndSource: HWND;
  out phThumbnailId: HTHUMBNAIL): HRESULT; stdcall;
begin
  if GetDwmProc(DwmRegisterThumbnailProc, 'DwmRegisterThumbnail') then
    Result := TDwmRegisterThumbnailFn(DwmRegisterThumbnailProc)(hwndDestination, hwndSource,
      phThumbnailId)
  else
  begin
    phThumbnailId := 0;
    Result := E_NOTIMPL;
  end;
end;

function DwmSetWindowAttribute(hwnd: HWND; dwAttribute: DWORD; pvAttribute: Pointer;
  cbAttribute: DWORD): HRESULT; stdcall;
begin
  if GetDwmProc(DwmSetWindowAttributeProc, 'DwmSetWindowAttribute') then
    Result := TDwmAttributeFn(DwmSetWindowAttributeProc)(hwnd, dwAttribute, pvAttribute,
      cbAttribute)
  else
    Result := E_NOTIMPL;
end;

function DwmUnregisterThumbnail(hThumbnailId: HTHUMBNAIL): HRESULT; stdcall;
begin
  if GetDwmProc(DwmUnregisterThumbnailProc, 'DwmUnregisterThumbnail') then
    Result := TDwmThumbnailFn(DwmUnregisterThumbnailProc)(hThumbnailId)
  else
    Result := E_NOTIMPL;
end;

function DwmUpdateThumbnailProperties(hThumbnailId: HTHUMBNAIL;
  const ptnProperties: TDwmThumbnailProperties): HRESULT; stdcall;
var
  Properties: TDwmThumbnailProperties;
begin
  if GetDwmProc(DwmUpdateThumbnailPropertiesProc, 'DwmUpdateThumbnailProperties') then
  begin
    Properties := ptnProperties;
    Integer(Properties.fVisible) := DwmBoolArg(Properties.fVisible);
    Integer(Properties.fSourceClientAreaOnly) := DwmBoolArg(Properties.fSourceClientAreaOnly);
    Result := TDwmUpdateThumbnailPropertiesFn(DwmUpdateThumbnailPropertiesProc)(hThumbnailId,
      @Properties);
  end
  else
    Result := E_NOTIMPL;
end;

function DwmSetIconicThumbnail(hwnd: HWND; hbmp: HBITMAP; dwSITFlags: DWORD): HRESULT; stdcall;
begin
  if GetDwmProc(DwmSetIconicThumbnailProc, 'DwmSetIconicThumbnail') then
    Result := TDwmSetIconicThumbnailFn(DwmSetIconicThumbnailProc)(hwnd, hbmp, dwSITFlags)
  else
    Result := E_NOTIMPL;
end;

function DwmSetIconicLivePreviewBitmap(hwnd: HWND; hbmp: HBITMAP; pptClient: PPoint;
  dwSITFlags: DWORD): HRESULT; stdcall;
begin
  if GetDwmProc(DwmSetIconicLivePreviewBitmapProc, 'DwmSetIconicLivePreviewBitmap') then
    Result := TDwmSetIconicLivePreviewBitmapFn(DwmSetIconicLivePreviewBitmapProc)(hwnd, hbmp,
      pptClient, dwSITFlags)
  else
    Result := E_NOTIMPL;
end;

function DwmInvalidateIconicBitmaps(hwnd: HWND): HRESULT; stdcall;
begin
  if GetDwmProc(DwmInvalidateIconicBitmapsProc, 'DwmInvalidateIconicBitmaps') then
    Result := TDwmHwndFn(DwmInvalidateIconicBitmapsProc)(hwnd)
  else
    Result := E_NOTIMPL;
end;

function DwmGetTransportAttributes(out pfIsRemoting: BOOL; out pfIsConnected: BOOL;
  out pDwGeneration: DWORD): HRESULT; stdcall;
begin
  if GetDwmProc(DwmGetTransportAttributesProc, 'DwmGetTransportAttributes') then
    Result := TDwmGetTransportAttributesFn(DwmGetTransportAttributesProc)(pfIsRemoting,
      pfIsConnected, pDwGeneration)
  else
  begin
    pfIsRemoting := False;
    pfIsConnected := False;
    pDwGeneration := 0;
    Result := E_NOTIMPL;
  end;
end;

{ ---- Helpers ---- }

function DwmCompositionEnabled: Boolean;
var
  Enabled: BOOL;
begin
  Enabled := False;
  Result := (DwmIsCompositionEnabled(Enabled) = S_OK) and Enabled;
end;

procedure SetWindowDarkMode(Wnd: HWND; Dark: Boolean);
var
  Value: Integer;   { a BOOL holding exactly 0 or 1 }
begin
  Value := Ord(Dark);
  if DwmSetWindowAttribute(Wnd, DWMWA_USE_IMMERSIVE_DARK_MODE, @Value,
    SizeOf(Value)) <> S_OK then
    DwmSetWindowAttribute(Wnd, DWMWA_USE_IMMERSIVE_DARK_MODE_BEFORE_20H1, @Value,
      SizeOf(Value));
end;

procedure SetWindowCornerPreference(Wnd: HWND; Pref: Integer);
begin
  DwmSetWindowAttribute(Wnd, DWMWA_WINDOW_CORNER_PREFERENCE, @Pref, SizeOf(Pref));
end;

function GetWindowExtendedFrameBounds(Wnd: HWND; var R: TRect): Boolean;
begin
  Result := DwmGetWindowAttribute(Wnd, DWMWA_EXTENDED_FRAME_BOUNDS, @R, SizeOf(R)) = S_OK;
  if not Result then
    Result := GetWindowRect(Wnd, R);
end;

{ ---- Windows 8 .. 11 additions ---- }

type
  TDwmTransitionOwnedWindowFn = function(hwnd: HWND; target: Integer): BOOL; stdcall;
  TDwmShowContactFn = function(dwPointerID: DWORD; eShowContact: DWORD): HRESULT; stdcall;
  TDwmRenderGestureFn = function(gt: Integer; cContacts: UINT; pdwPointerID: PDWORD;
    pPoints: PPoint): HRESULT; stdcall;
  TDwmTetherContactFn = function(dwPointerID: DWORD; fEnable: Integer; ptTether: TPoint): HRESULT; stdcall;
  TDwmGetUnmetTabRequirementsFn = function(appWindow: HWND; out value: DWORD): HRESULT; stdcall;

var
  DwmTransitionOwnedWindowProc, DwmShowContactProc, DwmRenderGestureProc, DwmTetherContactProc,
  DwmGetUnmetTabRequirementsProc: Pointer;

function DwmTransitionOwnedWindow(hwnd: HWND; target: Integer): BOOL; stdcall;
begin
  if GetDwmProc(DwmTransitionOwnedWindowProc, 'DwmTransitionOwnedWindow') then
    Result := TDwmTransitionOwnedWindowFn(DwmTransitionOwnedWindowProc)(hwnd, target)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := False;
  end;
end;

function DwmShowContact(dwPointerID: DWORD; eShowContact: DWORD): HRESULT; stdcall;
begin
  if GetDwmProc(DwmShowContactProc, 'DwmShowContact') then
    Result := TDwmShowContactFn(DwmShowContactProc)(dwPointerID, eShowContact)
  else
    Result := E_NOTIMPL;
end;

function DwmRenderGesture(gt: Integer; cContacts: UINT; const pdwPointerID: DWORD;
  const pPoints: TPoint): HRESULT; stdcall;
begin
  if GetDwmProc(DwmRenderGestureProc, 'DwmRenderGesture') then
    Result := TDwmRenderGestureFn(DwmRenderGestureProc)(gt, cContacts, @pdwPointerID, @pPoints)
  else
    Result := E_NOTIMPL;
end;

function DwmTetherContact(dwPointerID: DWORD; fEnable: BOOL; ptTether: TPoint): HRESULT; stdcall;
begin
  if GetDwmProc(DwmTetherContactProc, 'DwmTetherContact') then
    Result := TDwmTetherContactFn(DwmTetherContactProc)(dwPointerID, DwmBoolArg(fEnable), ptTether)
  else
    Result := E_NOTIMPL;
end;

function DwmGetUnmetTabRequirements(appWindow: HWND; out value: DWORD): HRESULT; stdcall;
begin
  if GetDwmProc(DwmGetUnmetTabRequirementsProc, 'DwmGetUnmetTabRequirements') then
    Result := TDwmGetUnmetTabRequirementsFn(DwmGetUnmetTabRequirementsProc)(appWindow, value)
  else
  begin
    value := 0;
    Result := E_NOTIMPL;
  end;
end;

end.
