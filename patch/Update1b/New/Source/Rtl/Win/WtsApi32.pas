{**********************************************************}
{                                                          }
{     Delphi 7 Runtime Library - Modernization             }
{     Remote Desktop Services API (wtsapi32.h)             }
{     Windows XP .. Windows 11                             }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit WtsApi32;

{ Translated from wtsapi32.h, with WTSGetActiveConsoleSessionId (winbase.h),
  WM_WTSSESSION_CHANGE, its WTS_* codes and WTSSESSION_NOTIFICATION
  (winuser.h) (Windows SDK 10.0.26100).

  Binding:
    - functions that exist in Windows XP are bound statically (wtsapi32.dll;
      WTSGetActiveConsoleSessionId: kernel32.dll);
    - functions introduced in Windows Vista or later are bound at run time
      on first use (wtsapi32.dll is loaded from the system directory), so
      programs that use this unit still start on Windows XP. When such a
      function is missing, BOOL functions return False after
      SetLastError(ERROR_CALL_NOT_IMPLEMENTED), HANDLE functions return 0
      after the same SetLastError, and output parameters are cleared;
      WTSOpenServerEx and the WTS(Un)RegisterSessionNotificationEx pair use
      their Windows XP counterparts instead. The fallback is documented next
      to each declaration.
  BOOL arguments of the run-time bound functions are passed to Windows as 0
  or 1 (Delphi stores True as -1).

  Generic names (no A/W suffix) map to the A functions and types, as in
  Windows.pas. Strings and arrays returned by the WTSEnumerate* and
  WTSQuery* functions are freed with WTSFreeMemory (WTSFreeMemoryEx for the
  Ex enumerations); iterate them with Inc() on the typed record pointer.

  Not translated: the listener API (WTSEnumerateListeners, WTSCreateListener,
  WTS*ListenerSecurity, WTSQueryListenerConfig), the license validation
  structures and the cloud authentication API of Windows 11 24H2. }

{$WEAKPACKAGEUNIT ON}
{$MINENUMSIZE 4}

interface

uses
  Windows;

{ ====== Constants ========================================================= }

const
  { the current server (hServer) }
  {$EXTERNALSYM WTS_CURRENT_SERVER}
  WTS_CURRENT_SERVER        = THandle(0);
  {$EXTERNALSYM WTS_CURRENT_SERVER_HANDLE}
  WTS_CURRENT_SERVER_HANDLE = THandle(0);
  {$EXTERNALSYM WTS_CURRENT_SERVER_NAME}
  WTS_CURRENT_SERVER_NAME   = nil;

  { the current session (SessionId) }
  {$EXTERNALSYM WTS_CURRENT_SESSION}
  WTS_CURRENT_SESSION = DWORD($FFFFFFFF);
  { any session (SessionId) }
  {$EXTERNALSYM WTS_ANY_SESSION}
  WTS_ANY_SESSION     = DWORD($FFFFFFFE);

  { additional pResponse values of WTSSendMessage }
  {$EXTERNALSYM IDTIMEOUT}
  IDTIMEOUT = 32000;
  {$EXTERNALSYM IDASYNC}
  IDASYNC   = 32001;

  {$EXTERNALSYM USERNAME_LENGTH}
  USERNAME_LENGTH      = 20;
  {$EXTERNALSYM CLIENTNAME_LENGTH}
  CLIENTNAME_LENGTH    = 20;
  {$EXTERNALSYM CLIENTADDRESS_LENGTH}
  CLIENTADDRESS_LENGTH = 30;

  { WTSShutdownSystem flags }
  {$EXTERNALSYM WTS_WSD_LOGOFF}
  WTS_WSD_LOGOFF     = $00000001;  // log off all users except the current user; deletes WinStations
  {$EXTERNALSYM WTS_WSD_SHUTDOWN}
  WTS_WSD_SHUTDOWN   = $00000002;  // shut down the system
  {$EXTERNALSYM WTS_WSD_REBOOT}
  WTS_WSD_REBOOT     = $00000004;  // shut down and reboot
  {$EXTERNALSYM WTS_WSD_POWEROFF}
  WTS_WSD_POWEROFF   = $00000008;  // shut down and power off
  {$EXTERNALSYM WTS_WSD_FASTREBOOT}
  WTS_WSD_FASTREBOOT = $00000010;  // reboot without logging users off or shutting down

  {$EXTERNALSYM MAX_ELAPSED_TIME_LENGTH}
  MAX_ELAPSED_TIME_LENGTH  = 15;
  {$EXTERNALSYM MAX_DATE_TIME_LENGTH}
  MAX_DATE_TIME_LENGTH     = 56;
  {$EXTERNALSYM WINSTATIONNAME_LENGTH}
  WINSTATIONNAME_LENGTH    = 32;
  {$EXTERNALSYM DOMAIN_LENGTH}
  DOMAIN_LENGTH            = 17;
  {$EXTERNALSYM WTS_DRIVE_LENGTH}
  WTS_DRIVE_LENGTH         = 3;
  {$EXTERNALSYM WTS_LISTENER_NAME_LENGTH}
  WTS_LISTENER_NAME_LENGTH = 32;
  {$EXTERNALSYM WTS_COMMENT_LENGTH}
  WTS_COMMENT_LENGTH       = 60;

  { WTSCreateListener flags }
  {$EXTERNALSYM WTS_LISTENER_CREATE}
  WTS_LISTENER_CREATE = $00000001;
  {$EXTERNALSYM WTS_LISTENER_UPDATE}
  WTS_LISTENER_UPDATE = $00000010;

  { listener access rights }
  {$EXTERNALSYM WTS_SECURITY_QUERY_INFORMATION}
  WTS_SECURITY_QUERY_INFORMATION = $00000001;
  {$EXTERNALSYM WTS_SECURITY_SET_INFORMATION}
  WTS_SECURITY_SET_INFORMATION   = $00000002;
  {$EXTERNALSYM WTS_SECURITY_RESET}
  WTS_SECURITY_RESET             = $00000004;
  {$EXTERNALSYM WTS_SECURITY_VIRTUAL_CHANNELS}
  WTS_SECURITY_VIRTUAL_CHANNELS  = $00000008;
  {$EXTERNALSYM WTS_SECURITY_REMOTE_CONTROL}
  WTS_SECURITY_REMOTE_CONTROL    = $00000010;
  {$EXTERNALSYM WTS_SECURITY_LOGON}
  WTS_SECURITY_LOGON             = $00000020;
  {$EXTERNALSYM WTS_SECURITY_LOGOFF}
  WTS_SECURITY_LOGOFF            = $00000040;
  {$EXTERNALSYM WTS_SECURITY_MESSAGE}
  WTS_SECURITY_MESSAGE           = $00000080;
  {$EXTERNALSYM WTS_SECURITY_CONNECT}
  WTS_SECURITY_CONNECT           = $00000100;
  {$EXTERNALSYM WTS_SECURITY_DISCONNECT}
  WTS_SECURITY_DISCONNECT        = $00000200;
  {$EXTERNALSYM WTS_SECURITY_GUEST_ACCESS}
  WTS_SECURITY_GUEST_ACCESS = WTS_SECURITY_LOGON;
  {$EXTERNALSYM WTS_SECURITY_CURRENT_GUEST_ACCESS}
  WTS_SECURITY_CURRENT_GUEST_ACCESS = WTS_SECURITY_VIRTUAL_CHANNELS or WTS_SECURITY_LOGOFF;
  {$EXTERNALSYM WTS_SECURITY_USER_ACCESS}
  WTS_SECURITY_USER_ACCESS = WTS_SECURITY_CURRENT_GUEST_ACCESS or
    WTS_SECURITY_QUERY_INFORMATION or WTS_SECURITY_CONNECT;
  { WTS_SECURITY_CURRENT_USER_ACCESS is not translated: the SDK macro lacks
    two "|" operators and does not compile. }
  {$EXTERNALSYM WTS_SECURITY_ALL_ACCESS}
  WTS_SECURITY_ALL_ACCESS = STANDARD_RIGHTS_REQUIRED or WTS_SECURITY_QUERY_INFORMATION or
    WTS_SECURITY_SET_INFORMATION or WTS_SECURITY_RESET or WTS_SECURITY_VIRTUAL_CHANNELS or
    WTS_SECURITY_REMOTE_CONTROL or WTS_SECURITY_LOGON or WTS_SECURITY_MESSAGE or
    WTS_SECURITY_CONNECT or WTS_SECURITY_DISCONNECT;

  { WTSClientProtocolType values }
  {$EXTERNALSYM WTS_PROTOCOL_TYPE_CONSOLE}
  WTS_PROTOCOL_TYPE_CONSOLE = 0;  // Console
  {$EXTERNALSYM WTS_PROTOCOL_TYPE_ICA}
  WTS_PROTOCOL_TYPE_ICA     = 1;  // ICA Protocol
  {$EXTERNALSYM WTS_PROTOCOL_TYPE_RDP}
  WTS_PROTOCOL_TYPE_RDP     = 2;  // RDP Protocol

  { WTSINFOEX_LEVEL1.SessionFlags }
  {$EXTERNALSYM WTS_SESSIONSTATE_UNKNOWN}
  WTS_SESSIONSTATE_UNKNOWN = DWORD($FFFFFFFF);
  {$EXTERNALSYM WTS_SESSIONSTATE_LOCK}
  WTS_SESSIONSTATE_LOCK    = $00000000;
  {$EXTERNALSYM WTS_SESSIONSTATE_UNLOCK}
  WTS_SESSIONSTATE_UNLOCK  = $00000001;

  { WTSWaitSystemEvent event flags }
  {$EXTERNALSYM WTS_EVENT_NONE}
  WTS_EVENT_NONE        = $00000000;  // return no event
  {$EXTERNALSYM WTS_EVENT_CREATE}
  WTS_EVENT_CREATE      = $00000001;  // new WinStation created
  {$EXTERNALSYM WTS_EVENT_DELETE}
  WTS_EVENT_DELETE      = $00000002;  // existing WinStation deleted
  {$EXTERNALSYM WTS_EVENT_RENAME}
  WTS_EVENT_RENAME      = $00000004;  // existing WinStation renamed
  {$EXTERNALSYM WTS_EVENT_CONNECT}
  WTS_EVENT_CONNECT     = $00000008;  // WinStation connect to client
  {$EXTERNALSYM WTS_EVENT_DISCONNECT}
  WTS_EVENT_DISCONNECT  = $00000010;  // WinStation logged on without client
  {$EXTERNALSYM WTS_EVENT_LOGON}
  WTS_EVENT_LOGON       = $00000020;  // user logged on to existing WinStation
  {$EXTERNALSYM WTS_EVENT_LOGOFF}
  WTS_EVENT_LOGOFF      = $00000040;  // user logged off from existing WinStation
  {$EXTERNALSYM WTS_EVENT_STATECHANGE}
  WTS_EVENT_STATECHANGE = $00000080;  // WinStation state change
  {$EXTERNALSYM WTS_EVENT_LICENSE}
  WTS_EVENT_LICENSE     = $00000100;  // license state change
  {$EXTERNALSYM WTS_EVENT_ALL}
  WTS_EVENT_ALL         = $7FFFFFFF;  // wait for all event types
  {$EXTERNALSYM WTS_EVENT_FLUSH}
  WTS_EVENT_FLUSH       = DWORD($80000000);  // unblock all waiters

  { HotkeyModifiers of WTSStartRemoteControlSession }
  {$EXTERNALSYM REMOTECONTROL_KBDSHIFT_HOTKEY}
  REMOTECONTROL_KBDSHIFT_HOTKEY = $1;  // Shift key
  {$EXTERNALSYM REMOTECONTROL_KBDCTRL_HOTKEY}
  REMOTECONTROL_KBDCTRL_HOTKEY  = $2;  // Ctrl key
  {$EXTERNALSYM REMOTECONTROL_KBDALT_HOTKEY}
  REMOTECONTROL_KBDALT_HOTKEY   = $4;  // Alt key

  { WTSVirtualChannelOpenEx flags }
  {$EXTERNALSYM WTS_CHANNEL_OPTION_DYNAMIC}
  WTS_CHANNEL_OPTION_DYNAMIC             = $00000001;  // dynamic channel
  {$EXTERNALSYM WTS_CHANNEL_OPTION_DYNAMIC_PRI_LOW}
  WTS_CHANNEL_OPTION_DYNAMIC_PRI_LOW     = $00000000;  // priorities
  {$EXTERNALSYM WTS_CHANNEL_OPTION_DYNAMIC_PRI_MED}
  WTS_CHANNEL_OPTION_DYNAMIC_PRI_MED     = $00000002;
  {$EXTERNALSYM WTS_CHANNEL_OPTION_DYNAMIC_PRI_HIGH}
  WTS_CHANNEL_OPTION_DYNAMIC_PRI_HIGH    = $00000004;
  {$EXTERNALSYM WTS_CHANNEL_OPTION_DYNAMIC_PRI_REAL}
  WTS_CHANNEL_OPTION_DYNAMIC_PRI_REAL    = $00000006;
  {$EXTERNALSYM WTS_CHANNEL_OPTION_DYNAMIC_NO_COMPRESS}
  WTS_CHANNEL_OPTION_DYNAMIC_NO_COMPRESS = $00000008;

  { WTSRegisterSessionNotification(Ex) flags }
  {$EXTERNALSYM NOTIFY_FOR_ALL_SESSIONS}
  NOTIFY_FOR_ALL_SESSIONS = 1;
  {$EXTERNALSYM NOTIFY_FOR_THIS_SESSION}
  NOTIFY_FOR_THIS_SESSION = 0;

  { WTSEnumerateProcessesEx levels }
  {$EXTERNALSYM WTS_PROCESS_INFO_LEVEL_0}
  WTS_PROCESS_INFO_LEVEL_0 = 0;
  {$EXTERNALSYM WTS_PROCESS_INFO_LEVEL_1}
  WTS_PROCESS_INFO_LEVEL_1 = 1;

{ ====== Session change notifications (winuser.h) ========================== }

const
  { Also declared in Messages.pas (same value). }
  {$EXTERNALSYM WM_WTSSESSION_CHANGE}
  WM_WTSSESSION_CHANGE = $02B1;

  { WM_WTSSESSION_CHANGE wParam codes; lParam is the session ID. The first
    eight are also declared in Windows.pas (same values). }
  {$EXTERNALSYM WTS_CONSOLE_CONNECT}
  WTS_CONSOLE_CONNECT        = $1;
  {$EXTERNALSYM WTS_CONSOLE_DISCONNECT}
  WTS_CONSOLE_DISCONNECT     = $2;
  {$EXTERNALSYM WTS_REMOTE_CONNECT}
  WTS_REMOTE_CONNECT         = $3;
  {$EXTERNALSYM WTS_REMOTE_DISCONNECT}
  WTS_REMOTE_DISCONNECT      = $4;
  {$EXTERNALSYM WTS_SESSION_LOGON}
  WTS_SESSION_LOGON          = $5;
  {$EXTERNALSYM WTS_SESSION_LOGOFF}
  WTS_SESSION_LOGOFF         = $6;
  {$EXTERNALSYM WTS_SESSION_LOCK}
  WTS_SESSION_LOCK           = $7;
  {$EXTERNALSYM WTS_SESSION_UNLOCK}
  WTS_SESSION_UNLOCK         = $8;
  {$EXTERNALSYM WTS_SESSION_REMOTE_CONTROL}
  WTS_SESSION_REMOTE_CONTROL = $9;
  {$EXTERNALSYM WTS_SESSION_CREATE}
  WTS_SESSION_CREATE         = $A;
  {$EXTERNALSYM WTS_SESSION_TERMINATE}
  WTS_SESSION_TERMINATE      = $B;
  {$EXTERNALSYM WTS_SESSION_DESKTOP_READY}
  WTS_SESSION_DESKTOP_READY  = $F;

type
  { the data of SERVICE_CONTROL_SESSIONCHANGE (HandlerEx lpEventData) }
  PWtsSessionNotification = ^TWtsSessionNotification;
  {$EXTERNALSYM tagWTSSESSION_NOTIFICATION}
  tagWTSSESSION_NOTIFICATION = record
    cbSize: DWORD;
    dwSessionId: DWORD;
  end;
  TWtsSessionNotification = tagWTSSESSION_NOTIFICATION;
  {$EXTERNALSYM WTSSESSION_NOTIFICATION}
  WTSSESSION_NOTIFICATION = tagWTSSESSION_NOTIFICATION;
  {$EXTERNALSYM PWTSSESSION_NOTIFICATION}
  PWTSSESSION_NOTIFICATION = PWtsSessionNotification;

{ ====== Enumerations (C enums, 4 bytes) =================================== }

type
  { session connect state }
  {$EXTERNALSYM WTS_CONNECTSTATE_CLASS}
  WTS_CONNECTSTATE_CLASS = DWORD;
  TWtsConnectStateClass = WTS_CONNECTSTATE_CLASS;

const
  {$EXTERNALSYM WTSActive}
  WTSActive       = 0;  // User logged on to WinStation
  {$EXTERNALSYM WTSConnected}
  WTSConnected    = 1;  // WinStation connected to client
  {$EXTERNALSYM WTSConnectQuery}
  WTSConnectQuery = 2;  // In the process of connecting to client
  {$EXTERNALSYM WTSShadow}
  WTSShadow       = 3;  // Shadowing another WinStation
  {$EXTERNALSYM WTSDisconnected}
  WTSDisconnected = 4;  // WinStation logged on without client
  {$EXTERNALSYM WTSIdle}
  WTSIdle         = 5;  // Waiting for client to connect
  {$EXTERNALSYM WTSListen}
  WTSListen       = 6;  // WinStation is listening for connection
  {$EXTERNALSYM WTSReset}
  WTSReset        = 7;  // WinStation is being reset
  {$EXTERNALSYM WTSDown}
  WTSDown         = 8;  // WinStation is down due to error
  {$EXTERNALSYM WTSInit}
  WTSInit         = 9;  // WinStation in initialization

type
  { WTSQuerySessionInformation classes }
  {$EXTERNALSYM WTS_INFO_CLASS}
  WTS_INFO_CLASS = DWORD;
  TWtsInfoClass = WTS_INFO_CLASS;

const
  {$EXTERNALSYM WTSInitialProgram}
  WTSInitialProgram     = 0;
  {$EXTERNALSYM WTSApplicationName}
  WTSApplicationName    = 1;
  {$EXTERNALSYM WTSWorkingDirectory}
  WTSWorkingDirectory   = 2;
  {$EXTERNALSYM WTSOEMId}
  WTSOEMId              = 3;
  {$EXTERNALSYM WTSSessionId}
  WTSSessionId          = 4;   // ULONG
  {$EXTERNALSYM WTSUserName}
  WTSUserName           = 5;   // string
  {$EXTERNALSYM WTSWinStationName}
  WTSWinStationName     = 6;   // string
  {$EXTERNALSYM WTSDomainName}
  WTSDomainName         = 7;   // string
  {$EXTERNALSYM WTSConnectState}
  WTSConnectState       = 8;   // WTS_CONNECTSTATE_CLASS
  {$EXTERNALSYM WTSClientBuildNumber}
  WTSClientBuildNumber  = 9;   // ULONG
  {$EXTERNALSYM WTSClientName}
  WTSClientName         = 10;  // string
  {$EXTERNALSYM WTSClientDirectory}
  WTSClientDirectory    = 11;  // string
  {$EXTERNALSYM WTSClientProductId}
  WTSClientProductId    = 12;  // USHORT
  {$EXTERNALSYM WTSClientHardwareId}
  WTSClientHardwareId   = 13;  // ULONG
  {$EXTERNALSYM WTSClientAddress}
  WTSClientAddress      = 14;  // WTS_CLIENT_ADDRESS
  {$EXTERNALSYM WTSClientDisplay}
  WTSClientDisplay      = 15;  // WTS_CLIENT_DISPLAY
  {$EXTERNALSYM WTSClientProtocolType}
  WTSClientProtocolType = 16;  // USHORT, WTS_PROTOCOL_TYPE_*
  {$EXTERNALSYM WTSIdleTime}
  WTSIdleTime           = 17;
  {$EXTERNALSYM WTSLogonTime}
  WTSLogonTime          = 18;
  {$EXTERNALSYM WTSIncomingBytes}
  WTSIncomingBytes      = 19;
  {$EXTERNALSYM WTSOutgoingBytes}
  WTSOutgoingBytes      = 20;
  {$EXTERNALSYM WTSIncomingFrames}
  WTSIncomingFrames     = 21;
  {$EXTERNALSYM WTSOutgoingFrames}
  WTSOutgoingFrames     = 22;
  {$EXTERNALSYM WTSClientInfo}
  WTSClientInfo         = 23;  // WTSCLIENT
  {$EXTERNALSYM WTSSessionInfo}
  WTSSessionInfo        = 24;  // WTSINFO
  {$EXTERNALSYM WTSSessionInfoEx}
  WTSSessionInfoEx      = 25;  // WTSINFOEX
  {$EXTERNALSYM WTSConfigInfo}
  WTSConfigInfo         = 26;  // WTSCONFIGINFO
  {$EXTERNALSYM WTSValidationInfo}
  WTSValidationInfo     = 27;
  {$EXTERNALSYM WTSSessionAddressV4}
  WTSSessionAddressV4   = 28;  // WTS_SESSION_ADDRESS
  {$EXTERNALSYM WTSIsRemoteSession}
  WTSIsRemoteSession    = 29;  // BOOLEAN
  {$EXTERNALSYM WTSSessionActivityId}
  WTSSessionActivityId  = 30;
  {$EXTERNALSYM WTSCapabilityCheck}
  WTSCapabilityCheck    = 31;

type
  { WTSQueryUserConfig / WTSSetUserConfig classes }
  {$EXTERNALSYM WTS_CONFIG_CLASS}
  WTS_CONFIG_CLASS = DWORD;
  TWtsConfigClass = WTS_CONFIG_CLASS;

const
  {$EXTERNALSYM WTSUserConfigInitialProgram}
  WTSUserConfigInitialProgram                = 0;   // string
  {$EXTERNALSYM WTSUserConfigWorkingDirectory}
  WTSUserConfigWorkingDirectory              = 1;   // string
  {$EXTERNALSYM WTSUserConfigfInheritInitialProgram}
  WTSUserConfigfInheritInitialProgram        = 2;   // DWORD
  {$EXTERNALSYM WTSUserConfigfAllowLogonTerminalServer}
  WTSUserConfigfAllowLogonTerminalServer     = 3;   // DWORD
  {$EXTERNALSYM WTSUserConfigTimeoutSettingsConnections}
  WTSUserConfigTimeoutSettingsConnections    = 4;   // DWORD
  {$EXTERNALSYM WTSUserConfigTimeoutSettingsDisconnections}
  WTSUserConfigTimeoutSettingsDisconnections = 5;   // DWORD
  {$EXTERNALSYM WTSUserConfigTimeoutSettingsIdle}
  WTSUserConfigTimeoutSettingsIdle           = 6;   // DWORD
  {$EXTERNALSYM WTSUserConfigfDeviceClientDrives}
  WTSUserConfigfDeviceClientDrives           = 7;   // DWORD
  {$EXTERNALSYM WTSUserConfigfDeviceClientPrinters}
  WTSUserConfigfDeviceClientPrinters         = 8;   // DWORD
  {$EXTERNALSYM WTSUserConfigfDeviceClientDefaultPrinter}
  WTSUserConfigfDeviceClientDefaultPrinter   = 9;   // DWORD
  {$EXTERNALSYM WTSUserConfigBrokenTimeoutSettings}
  WTSUserConfigBrokenTimeoutSettings         = 10;  // DWORD
  {$EXTERNALSYM WTSUserConfigReconnectSettings}
  WTSUserConfigReconnectSettings             = 11;  // DWORD
  {$EXTERNALSYM WTSUserConfigModemCallbackSettings}
  WTSUserConfigModemCallbackSettings         = 12;  // DWORD
  {$EXTERNALSYM WTSUserConfigModemCallbackPhoneNumber}
  WTSUserConfigModemCallbackPhoneNumber      = 13;  // string
  {$EXTERNALSYM WTSUserConfigShadowingSettings}
  WTSUserConfigShadowingSettings             = 14;  // DWORD
  {$EXTERNALSYM WTSUserConfigTerminalServerProfilePath}
  WTSUserConfigTerminalServerProfilePath     = 15;  // string
  {$EXTERNALSYM WTSUserConfigTerminalServerHomeDir}
  WTSUserConfigTerminalServerHomeDir         = 16;  // string
  {$EXTERNALSYM WTSUserConfigTerminalServerHomeDirDrive}
  WTSUserConfigTerminalServerHomeDirDrive    = 17;  // string
  {$EXTERNALSYM WTSUserConfigfTerminalServerRemoteHomeDir}
  WTSUserConfigfTerminalServerRemoteHomeDir  = 18;  // DWORD 0: local, 1: remote
  {$EXTERNALSYM WTSUserConfigUser}
  WTSUserConfigUser                          = 19;  // WTSUSERCONFIG

type
  {$EXTERNALSYM WTS_CONFIG_SOURCE}
  WTS_CONFIG_SOURCE = DWORD;
  TWtsConfigSource = WTS_CONFIG_SOURCE;

const
  {$EXTERNALSYM WTSUserConfigSourceSAM}
  WTSUserConfigSourceSAM = 0;

type
  { WTSVirtualChannelQuery classes }
  {$EXTERNALSYM WTS_VIRTUAL_CLASS}
  WTS_VIRTUAL_CLASS = DWORD;
  TWtsVirtualClass = WTS_VIRTUAL_CLASS;

const
  {$EXTERNALSYM WTSVirtualClientData}
  WTSVirtualClientData = 0;  // Virtual channel client module data (C2H data)
  {$EXTERNALSYM WTSVirtualFileHandle}
  WTSVirtualFileHandle = 1;

type
  { WTSFreeMemoryEx types }
  {$EXTERNALSYM WTS_TYPE_CLASS}
  WTS_TYPE_CLASS = DWORD;
  TWtsTypeClass = WTS_TYPE_CLASS;

const
  {$EXTERNALSYM WTSTypeProcessInfoLevel0}
  WTSTypeProcessInfoLevel0 = 0;
  {$EXTERNALSYM WTSTypeProcessInfoLevel1}
  WTSTypeProcessInfoLevel1 = 1;
  {$EXTERNALSYM WTSTypeSessionInfoLevel1}
  WTSTypeSessionInfoLevel1 = 2;
  { Windows 11 24H2 (cloud authentication) }
  {$EXTERNALSYM WTSTypeCloudAuthServerNonce}
  WTSTypeCloudAuthServerNonce = 3;
  {$EXTERNALSYM WTSTypeSerializedUserCredential}
  WTSTypeSerializedUserCredential = 4;

{ ====== Structures ======================================================== }

type
  { WTSEnumerateServers }
  PWtsServerInfoA = ^TWtsServerInfoA;
  PWtsServerInfoW = ^TWtsServerInfoW;
  PWtsServerInfo = PWtsServerInfoA;
  {$EXTERNALSYM _WTS_SERVER_INFOA}
  _WTS_SERVER_INFOA = record
    pServerName: LPSTR;    // server name
  end;
  {$EXTERNALSYM _WTS_SERVER_INFOW}
  _WTS_SERVER_INFOW = record
    pServerName: LPWSTR;   // server name
  end;
  TWtsServerInfoA = _WTS_SERVER_INFOA;
  TWtsServerInfoW = _WTS_SERVER_INFOW;
  TWtsServerInfo = TWtsServerInfoA;
  {$EXTERNALSYM WTS_SERVER_INFOA}
  WTS_SERVER_INFOA = _WTS_SERVER_INFOA;
  {$EXTERNALSYM WTS_SERVER_INFOW}
  WTS_SERVER_INFOW = _WTS_SERVER_INFOW;
  {$EXTERNALSYM WTS_SERVER_INFO}
  WTS_SERVER_INFO = WTS_SERVER_INFOA;
  {$EXTERNALSYM PWTS_SERVER_INFOA}
  PWTS_SERVER_INFOA = PWtsServerInfoA;
  {$EXTERNALSYM PWTS_SERVER_INFOW}
  PWTS_SERVER_INFOW = PWtsServerInfoW;
  {$EXTERNALSYM PWTS_SERVER_INFO}
  PWTS_SERVER_INFO = PWTS_SERVER_INFOA;

  { WTSEnumerateSessions }
  PWtsSessionInfoA = ^TWtsSessionInfoA;
  PWtsSessionInfoW = ^TWtsSessionInfoW;
  PWtsSessionInfo = PWtsSessionInfoA;
  {$EXTERNALSYM _WTS_SESSION_INFOA}
  _WTS_SESSION_INFOA = record
    SessionId: DWORD;               // session id
    pWinStationName: LPSTR;         // name of WinStation this session is connected to
    State: WTS_CONNECTSTATE_CLASS;  // connection state (WTSActive ...)
  end;
  {$EXTERNALSYM _WTS_SESSION_INFOW}
  _WTS_SESSION_INFOW = record
    SessionId: DWORD;               // session id
    pWinStationName: LPWSTR;        // name of WinStation this session is connected to
    State: WTS_CONNECTSTATE_CLASS;  // connection state (WTSActive ...)
  end;
  TWtsSessionInfoA = _WTS_SESSION_INFOA;
  TWtsSessionInfoW = _WTS_SESSION_INFOW;
  TWtsSessionInfo = TWtsSessionInfoA;
  {$EXTERNALSYM WTS_SESSION_INFOA}
  WTS_SESSION_INFOA = _WTS_SESSION_INFOA;
  {$EXTERNALSYM WTS_SESSION_INFOW}
  WTS_SESSION_INFOW = _WTS_SESSION_INFOW;
  {$EXTERNALSYM WTS_SESSION_INFO}
  WTS_SESSION_INFO = WTS_SESSION_INFOA;
  {$EXTERNALSYM PWTS_SESSION_INFOA}
  PWTS_SESSION_INFOA = PWtsSessionInfoA;
  {$EXTERNALSYM PWTS_SESSION_INFOW}
  PWTS_SESSION_INFOW = PWtsSessionInfoW;
  {$EXTERNALSYM PWTS_SESSION_INFO}
  PWTS_SESSION_INFO = PWTS_SESSION_INFOA;

  { WTSEnumerateSessionsEx, level 1 }
  PWtsSessionInfo1A = ^TWtsSessionInfo1A;
  PWtsSessionInfo1W = ^TWtsSessionInfo1W;
  PWtsSessionInfo1 = PWtsSessionInfo1A;
  {$EXTERNALSYM _WTS_SESSION_INFO_1A}
  _WTS_SESSION_INFO_1A = record
    ExecEnvId: DWORD;
    State: WTS_CONNECTSTATE_CLASS;
    SessionId: DWORD;
    pSessionName: LPSTR;
    pHostName: LPSTR;
    pUserName: LPSTR;
    pDomainName: LPSTR;
    pFarmName: LPSTR;
  end;
  {$EXTERNALSYM _WTS_SESSION_INFO_1W}
  _WTS_SESSION_INFO_1W = record
    ExecEnvId: DWORD;
    State: WTS_CONNECTSTATE_CLASS;
    SessionId: DWORD;
    pSessionName: LPWSTR;
    pHostName: LPWSTR;
    pUserName: LPWSTR;
    pDomainName: LPWSTR;
    pFarmName: LPWSTR;
  end;
  TWtsSessionInfo1A = _WTS_SESSION_INFO_1A;
  TWtsSessionInfo1W = _WTS_SESSION_INFO_1W;
  TWtsSessionInfo1 = TWtsSessionInfo1A;
  {$EXTERNALSYM WTS_SESSION_INFO_1A}
  WTS_SESSION_INFO_1A = _WTS_SESSION_INFO_1A;
  {$EXTERNALSYM WTS_SESSION_INFO_1W}
  WTS_SESSION_INFO_1W = _WTS_SESSION_INFO_1W;
  {$EXTERNALSYM WTS_SESSION_INFO_1}
  WTS_SESSION_INFO_1 = WTS_SESSION_INFO_1A;
  {$EXTERNALSYM PWTS_SESSION_INFO_1A}
  PWTS_SESSION_INFO_1A = PWtsSessionInfo1A;
  {$EXTERNALSYM PWTS_SESSION_INFO_1W}
  PWTS_SESSION_INFO_1W = PWtsSessionInfo1W;
  {$EXTERNALSYM PWTS_SESSION_INFO_1}
  PWTS_SESSION_INFO_1 = PWTS_SESSION_INFO_1A;

  { WTSEnumerateProcesses, and WTSEnumerateProcessesEx level 0 }
  PWtsProcessInfoA = ^TWtsProcessInfoA;
  PWtsProcessInfoW = ^TWtsProcessInfoW;
  PWtsProcessInfo = PWtsProcessInfoA;
  {$EXTERNALSYM _WTS_PROCESS_INFOA}
  _WTS_PROCESS_INFOA = record
    SessionId: DWORD;     // session id
    ProcessId: DWORD;     // process id
    pProcessName: LPSTR;  // name of process
    pUserSid: PSID;       // user's SID
  end;
  {$EXTERNALSYM _WTS_PROCESS_INFOW}
  _WTS_PROCESS_INFOW = record
    SessionId: DWORD;     // session id
    ProcessId: DWORD;     // process id
    pProcessName: LPWSTR; // name of process
    pUserSid: PSID;       // user's SID
  end;
  TWtsProcessInfoA = _WTS_PROCESS_INFOA;
  TWtsProcessInfoW = _WTS_PROCESS_INFOW;
  TWtsProcessInfo = TWtsProcessInfoA;
  {$EXTERNALSYM WTS_PROCESS_INFOA}
  WTS_PROCESS_INFOA = _WTS_PROCESS_INFOA;
  {$EXTERNALSYM WTS_PROCESS_INFOW}
  WTS_PROCESS_INFOW = _WTS_PROCESS_INFOW;
  {$EXTERNALSYM WTS_PROCESS_INFO}
  WTS_PROCESS_INFO = WTS_PROCESS_INFOA;
  {$EXTERNALSYM PWTS_PROCESS_INFOA}
  PWTS_PROCESS_INFOA = PWtsProcessInfoA;
  {$EXTERNALSYM PWTS_PROCESS_INFOW}
  PWTS_PROCESS_INFOW = PWtsProcessInfoW;
  {$EXTERNALSYM PWTS_PROCESS_INFO}
  PWTS_PROCESS_INFO = PWTS_PROCESS_INFOA;

  { WTSEnumerateProcessesEx, level 1 }
  PWtsProcessInfoExA = ^TWtsProcessInfoExA;
  PWtsProcessInfoExW = ^TWtsProcessInfoExW;
  PWtsProcessInfoEx = PWtsProcessInfoExA;
  {$EXTERNALSYM _WTS_PROCESS_INFO_EXA}
  _WTS_PROCESS_INFO_EXA = record
    SessionId: DWORD;
    ProcessId: DWORD;
    pProcessName: LPSTR;
    pUserSid: PSID;
    NumberOfThreads: DWORD;
    HandleCount: DWORD;
    PagefileUsage: DWORD;
    PeakPagefileUsage: DWORD;
    WorkingSetSize: DWORD;
    PeakWorkingSetSize: DWORD;
    UserTime: LARGE_INTEGER;
    KernelTime: LARGE_INTEGER;
  end;
  {$EXTERNALSYM _WTS_PROCESS_INFO_EXW}
  _WTS_PROCESS_INFO_EXW = record
    SessionId: DWORD;
    ProcessId: DWORD;
    pProcessName: LPWSTR;
    pUserSid: PSID;
    NumberOfThreads: DWORD;
    HandleCount: DWORD;
    PagefileUsage: DWORD;
    PeakPagefileUsage: DWORD;
    WorkingSetSize: DWORD;
    PeakWorkingSetSize: DWORD;
    UserTime: LARGE_INTEGER;
    KernelTime: LARGE_INTEGER;
  end;
  TWtsProcessInfoExA = _WTS_PROCESS_INFO_EXA;
  TWtsProcessInfoExW = _WTS_PROCESS_INFO_EXW;
  TWtsProcessInfoEx = TWtsProcessInfoExA;
  {$EXTERNALSYM WTS_PROCESS_INFO_EXA}
  WTS_PROCESS_INFO_EXA = _WTS_PROCESS_INFO_EXA;
  {$EXTERNALSYM WTS_PROCESS_INFO_EXW}
  WTS_PROCESS_INFO_EXW = _WTS_PROCESS_INFO_EXW;
  {$EXTERNALSYM WTS_PROCESS_INFO_EX}
  WTS_PROCESS_INFO_EX = WTS_PROCESS_INFO_EXA;
  {$EXTERNALSYM PWTS_PROCESS_INFO_EXA}
  PWTS_PROCESS_INFO_EXA = PWtsProcessInfoExA;
  {$EXTERNALSYM PWTS_PROCESS_INFO_EXW}
  PWTS_PROCESS_INFO_EXW = PWtsProcessInfoExW;
  {$EXTERNALSYM PWTS_PROCESS_INFO_EX}
  PWTS_PROCESS_INFO_EX = PWTS_PROCESS_INFO_EXA;

  { WTSQuerySessionInformation(WTSConfigInfo) }
  {$EXTERNALSYM PWTSCONFIGINFOA}
  PWTSCONFIGINFOA = ^TWtsConfigInfoA;
  {$EXTERNALSYM PWTSCONFIGINFOW}
  PWTSCONFIGINFOW = ^TWtsConfigInfoW;
  {$EXTERNALSYM PWTSCONFIGINFO}
  PWTSCONFIGINFO = PWTSCONFIGINFOA;
  {$EXTERNALSYM _WTSCONFIGINFOA}
  _WTSCONFIGINFOA = record
    version: ULONG;
    fConnectClientDrivesAtLogon: ULONG;
    fConnectPrinterAtLogon: ULONG;
    fDisablePrinterRedirection: ULONG;
    fDisableDefaultMainClientPrinter: ULONG;
    ShadowSettings: ULONG;
    LogonUserName: array[0..USERNAME_LENGTH] of AnsiChar;
    LogonDomain: array[0..DOMAIN_LENGTH] of AnsiChar;
    WorkDirectory: array[0..MAX_PATH] of AnsiChar;
    InitialProgram: array[0..MAX_PATH] of AnsiChar;
    ApplicationName: array[0..MAX_PATH] of AnsiChar;
  end;
  {$EXTERNALSYM _WTSCONFIGINFOW}
  _WTSCONFIGINFOW = record
    version: ULONG;
    fConnectClientDrivesAtLogon: ULONG;
    fConnectPrinterAtLogon: ULONG;
    fDisablePrinterRedirection: ULONG;
    fDisableDefaultMainClientPrinter: ULONG;
    ShadowSettings: ULONG;
    LogonUserName: array[0..USERNAME_LENGTH] of WideChar;
    LogonDomain: array[0..DOMAIN_LENGTH] of WideChar;
    WorkDirectory: array[0..MAX_PATH] of WideChar;
    InitialProgram: array[0..MAX_PATH] of WideChar;
    ApplicationName: array[0..MAX_PATH] of WideChar;
  end;
  TWtsConfigInfoA = _WTSCONFIGINFOA;
  TWtsConfigInfoW = _WTSCONFIGINFOW;
  TWtsConfigInfo = TWtsConfigInfoA;
  {$EXTERNALSYM WTSCONFIGINFOA}
  WTSCONFIGINFOA = _WTSCONFIGINFOA;
  {$EXTERNALSYM WTSCONFIGINFOW}
  WTSCONFIGINFOW = _WTSCONFIGINFOW;
  { The generic WTSCONFIGINFO is not declared: Pascal identifiers ignore
    case, so it would be the same identifier as WTSConfigInfo (a
    WTS_INFO_CLASS value). Use TWtsConfigInfo. }

  { WTSQuerySessionInformation(WTSSessionInfo) }
  {$EXTERNALSYM PWTSINFOA}
  PWTSINFOA = ^TWtsInfoA;
  {$EXTERNALSYM PWTSINFOW}
  PWTSINFOW = ^TWtsInfoW;
  {$EXTERNALSYM PWTSINFO}
  PWTSINFO = PWTSINFOA;
  {$EXTERNALSYM _WTSINFOA}
  _WTSINFOA = record
    State: WTS_CONNECTSTATE_CLASS;  // connection state (WTSActive ...)
    SessionId: DWORD;               // session id
    IncomingBytes: DWORD;
    OutgoingBytes: DWORD;
    IncomingFrames: DWORD;
    OutgoingFrames: DWORD;
    IncomingCompressedBytes: DWORD;
    OutgoingCompressedBy: DWORD;    // spelled so in wtsapi32.h (OutgoingCompressedBytes in WTSINFOW)
    WinStationName: array[0..WINSTATIONNAME_LENGTH - 1] of AnsiChar;
    Domain: array[0..DOMAIN_LENGTH - 1] of AnsiChar;
    UserName: array[0..USERNAME_LENGTH] of AnsiChar;
    ConnectTime: LARGE_INTEGER;
    DisconnectTime: LARGE_INTEGER;
    LastInputTime: LARGE_INTEGER;
    LogonTime: LARGE_INTEGER;
    CurrentTime: LARGE_INTEGER;
  end;
  {$EXTERNALSYM _WTSINFOW}
  _WTSINFOW = record
    State: WTS_CONNECTSTATE_CLASS;  // connection state (WTSActive ...)
    SessionId: DWORD;               // session id
    IncomingBytes: DWORD;
    OutgoingBytes: DWORD;
    IncomingFrames: DWORD;
    OutgoingFrames: DWORD;
    IncomingCompressedBytes: DWORD;
    OutgoingCompressedBytes: DWORD;
    WinStationName: array[0..WINSTATIONNAME_LENGTH - 1] of WideChar;
    Domain: array[0..DOMAIN_LENGTH - 1] of WideChar;
    UserName: array[0..USERNAME_LENGTH] of WideChar;
    ConnectTime: LARGE_INTEGER;
    DisconnectTime: LARGE_INTEGER;
    LastInputTime: LARGE_INTEGER;
    LogonTime: LARGE_INTEGER;
    CurrentTime: LARGE_INTEGER;
  end;
  TWtsInfoA = _WTSINFOA;
  TWtsInfoW = _WTSINFOW;
  TWtsInfo = TWtsInfoA;
  {$EXTERNALSYM WTSINFOA}
  WTSINFOA = _WTSINFOA;
  {$EXTERNALSYM WTSINFOW}
  WTSINFOW = _WTSINFOW;
  {$EXTERNALSYM WTSINFO}
  WTSINFO = WTSINFOA;

  { WTSQuerySessionInformation(WTSSessionInfoEx), Windows 7 }
  PWtsInfoExLevel1A = ^TWtsInfoExLevel1A;
  PWtsInfoExLevel1W = ^TWtsInfoExLevel1W;
  PWtsInfoExLevel1 = PWtsInfoExLevel1A;
  {$EXTERNALSYM _WTSINFOEX_LEVEL1_A}
  _WTSINFOEX_LEVEL1_A = record
    SessionId: ULONG;
    SessionState: WTS_CONNECTSTATE_CLASS;
    SessionFlags: Longint;          // WTS_SESSIONSTATE_*
    WinStationName: array[0..WINSTATIONNAME_LENGTH] of AnsiChar;
    UserName: array[0..USERNAME_LENGTH] of AnsiChar;
    DomainName: array[0..DOMAIN_LENGTH] of AnsiChar;
    LogonTime: LARGE_INTEGER;
    ConnectTime: LARGE_INTEGER;
    DisconnectTime: LARGE_INTEGER;
    LastInputTime: LARGE_INTEGER;
    CurrentTime: LARGE_INTEGER;
    IncomingBytes: DWORD;
    OutgoingBytes: DWORD;
    IncomingFrames: DWORD;
    OutgoingFrames: DWORD;
    IncomingCompressedBytes: DWORD;
    OutgoingCompressedBytes: DWORD;
  end;
  {$EXTERNALSYM _WTSINFOEX_LEVEL1_W}
  _WTSINFOEX_LEVEL1_W = record
    SessionId: ULONG;
    SessionState: WTS_CONNECTSTATE_CLASS;
    SessionFlags: Longint;          // WTS_SESSIONSTATE_*
    WinStationName: array[0..WINSTATIONNAME_LENGTH] of WideChar;
    UserName: array[0..USERNAME_LENGTH] of WideChar;
    DomainName: array[0..DOMAIN_LENGTH] of WideChar;
    LogonTime: LARGE_INTEGER;
    ConnectTime: LARGE_INTEGER;
    DisconnectTime: LARGE_INTEGER;
    LastInputTime: LARGE_INTEGER;
    CurrentTime: LARGE_INTEGER;
    IncomingBytes: DWORD;
    OutgoingBytes: DWORD;
    IncomingFrames: DWORD;
    OutgoingFrames: DWORD;
    IncomingCompressedBytes: DWORD;
    OutgoingCompressedBytes: DWORD;
  end;
  TWtsInfoExLevel1A = _WTSINFOEX_LEVEL1_A;
  TWtsInfoExLevel1W = _WTSINFOEX_LEVEL1_W;
  TWtsInfoExLevel1 = TWtsInfoExLevel1A;
  {$EXTERNALSYM WTSINFOEX_LEVEL1_A}
  WTSINFOEX_LEVEL1_A = _WTSINFOEX_LEVEL1_A;
  {$EXTERNALSYM WTSINFOEX_LEVEL1_W}
  WTSINFOEX_LEVEL1_W = _WTSINFOEX_LEVEL1_W;
  {$EXTERNALSYM WTSINFOEX_LEVEL1}
  WTSINFOEX_LEVEL1 = WTSINFOEX_LEVEL1_A;
  {$EXTERNALSYM PWTSINFOEX_LEVEL1_A}
  PWTSINFOEX_LEVEL1_A = PWtsInfoExLevel1A;
  {$EXTERNALSYM PWTSINFOEX_LEVEL1_W}
  PWTSINFOEX_LEVEL1_W = PWtsInfoExLevel1W;
  {$EXTERNALSYM PWTSINFOEX_LEVEL1}
  PWTSINFOEX_LEVEL1 = PWTSINFOEX_LEVEL1_A;

  { a union of one member in wtsapi32.h }
  PWtsInfoExLevelA = ^TWtsInfoExLevelA;
  PWtsInfoExLevelW = ^TWtsInfoExLevelW;
  PWtsInfoExLevel = PWtsInfoExLevelA;
  {$EXTERNALSYM _WTSINFOEX_LEVEL_A}
  _WTSINFOEX_LEVEL_A = record
    WTSInfoExLevel1: WTSINFOEX_LEVEL1_A;
  end;
  {$EXTERNALSYM _WTSINFOEX_LEVEL_W}
  _WTSINFOEX_LEVEL_W = record
    WTSInfoExLevel1: WTSINFOEX_LEVEL1_W;
  end;
  TWtsInfoExLevelA = _WTSINFOEX_LEVEL_A;
  TWtsInfoExLevelW = _WTSINFOEX_LEVEL_W;
  TWtsInfoExLevel = TWtsInfoExLevelA;
  {$EXTERNALSYM WTSINFOEX_LEVEL_A}
  WTSINFOEX_LEVEL_A = _WTSINFOEX_LEVEL_A;
  {$EXTERNALSYM WTSINFOEX_LEVEL_W}
  WTSINFOEX_LEVEL_W = _WTSINFOEX_LEVEL_W;
  {$EXTERNALSYM WTSINFOEX_LEVEL}
  WTSINFOEX_LEVEL = WTSINFOEX_LEVEL_A;
  {$EXTERNALSYM PWTSINFOEX_LEVEL_A}
  PWTSINFOEX_LEVEL_A = PWtsInfoExLevelA;
  {$EXTERNALSYM PWTSINFOEX_LEVEL_W}
  PWTSINFOEX_LEVEL_W = PWtsInfoExLevelW;
  {$EXTERNALSYM PWTSINFOEX_LEVEL}
  PWTSINFOEX_LEVEL = PWTSINFOEX_LEVEL_A;

  {$EXTERNALSYM PWTSINFOEXA}
  PWTSINFOEXA = ^TWtsInfoExA;
  {$EXTERNALSYM PWTSINFOEXW}
  PWTSINFOEXW = ^TWtsInfoExW;
  {$EXTERNALSYM PWTSINFOEX}
  PWTSINFOEX = PWTSINFOEXA;
  {$EXTERNALSYM _WTSINFOEXA}
  _WTSINFOEXA = record
    Level: DWORD;                   // 1
    Data: WTSINFOEX_LEVEL_A;
  end;
  {$EXTERNALSYM _WTSINFOEXW}
  _WTSINFOEXW = record
    Level: DWORD;                   // 1
    Data: WTSINFOEX_LEVEL_W;
  end;
  TWtsInfoExA = _WTSINFOEXA;
  TWtsInfoExW = _WTSINFOEXW;
  TWtsInfoEx = TWtsInfoExA;
  {$EXTERNALSYM WTSINFOEXA}
  WTSINFOEXA = _WTSINFOEXA;
  {$EXTERNALSYM WTSINFOEXW}
  WTSINFOEXW = _WTSINFOEXW;
  {$EXTERNALSYM WTSINFOEX}
  WTSINFOEX = WTSINFOEXA;

  { WTSQuerySessionInformation(WTSClientInfo) }
  {$EXTERNALSYM PWTSCLIENTA}
  PWTSCLIENTA = ^TWtsClientA;
  {$EXTERNALSYM PWTSCLIENTW}
  PWTSCLIENTW = ^TWtsClientW;
  {$EXTERNALSYM PWTSCLIENT}
  PWTSCLIENT = PWTSCLIENTA;
  {$EXTERNALSYM _WTSCLIENTA}
  _WTSCLIENTA = record
    ClientName: array[0..CLIENTNAME_LENGTH] of AnsiChar;
    Domain: array[0..DOMAIN_LENGTH] of AnsiChar;
    UserName: array[0..USERNAME_LENGTH] of AnsiChar;
    WorkDirectory: array[0..MAX_PATH] of AnsiChar;
    InitialProgram: array[0..MAX_PATH] of AnsiChar;
    EncryptionLevel: Byte;          // security level of encryption pd
    ClientAddressFamily: ULONG;
    ClientAddress: array[0..CLIENTADDRESS_LENGTH] of Word;
    HRes: Word;
    VRes: Word;
    ColorDepth: Word;
    ClientDirectory: array[0..MAX_PATH] of AnsiChar;
    ClientBuildNumber: ULONG;
    ClientHardwareId: ULONG;        // client software serial number
    ClientProductId: Word;          // client software product id
    OutBufCountHost: Word;          // number of outbufs on host
    OutBufCountClient: Word;        // number of outbufs on client
    OutBufLength: Word;             // length of outbufs in bytes
    DeviceId: array[0..MAX_PATH] of AnsiChar;
  end;
  {$EXTERNALSYM _WTSCLIENTW}
  _WTSCLIENTW = record
    ClientName: array[0..CLIENTNAME_LENGTH] of WideChar;
    Domain: array[0..DOMAIN_LENGTH] of WideChar;
    UserName: array[0..USERNAME_LENGTH] of WideChar;
    WorkDirectory: array[0..MAX_PATH] of WideChar;
    InitialProgram: array[0..MAX_PATH] of WideChar;
    EncryptionLevel: Byte;          // security level of encryption pd
    ClientAddressFamily: ULONG;
    ClientAddress: array[0..CLIENTADDRESS_LENGTH] of Word;
    HRes: Word;
    VRes: Word;
    ColorDepth: Word;
    ClientDirectory: array[0..MAX_PATH] of WideChar;
    ClientBuildNumber: ULONG;
    ClientHardwareId: ULONG;        // client software serial number
    ClientProductId: Word;          // client software product id
    OutBufCountHost: Word;          // number of outbufs on host
    OutBufCountClient: Word;        // number of outbufs on client
    OutBufLength: Word;             // length of outbufs in bytes
    DeviceId: array[0..MAX_PATH] of WideChar;
  end;
  TWtsClientA = _WTSCLIENTA;
  TWtsClientW = _WTSCLIENTW;
  TWtsClient = TWtsClientA;
  {$EXTERNALSYM WTSCLIENTA}
  WTSCLIENTA = _WTSCLIENTA;
  {$EXTERNALSYM WTSCLIENTW}
  WTSCLIENTW = _WTSCLIENTW;
  {$EXTERNALSYM WTSCLIENT}
  WTSCLIENT = WTSCLIENTA;

  { WTSQuerySessionInformation(WTSClientAddress) }
  PWtsClientAddress = ^TWtsClientAddress;
  {$EXTERNALSYM _WTS_CLIENT_ADDRESS}
  _WTS_CLIENT_ADDRESS = record
    AddressFamily: DWORD;               // AF_INET, AF_INET6, AF_IPX, AF_NETBIOS, AF_UNSPEC
    Address: array[0..19] of Byte;      // client network address
  end;
  TWtsClientAddress = _WTS_CLIENT_ADDRESS;
  {$EXTERNALSYM WTS_CLIENT_ADDRESS}
  WTS_CLIENT_ADDRESS = _WTS_CLIENT_ADDRESS;
  {$EXTERNALSYM PWTS_CLIENT_ADDRESS}
  PWTS_CLIENT_ADDRESS = PWtsClientAddress;

  { WTSQuerySessionInformation(WTSClientDisplay) }
  PWtsClientDisplay = ^TWtsClientDisplay;
  {$EXTERNALSYM _WTS_CLIENT_DISPLAY}
  _WTS_CLIENT_DISPLAY = record
    HorizontalResolution: DWORD;  // horizontal dimensions, in pixels
    VerticalResolution: DWORD;    // vertical dimensions, in pixels
    ColorDepth: DWORD;            // 1=16, 2=256, 4=64K, 8=16M
  end;
  TWtsClientDisplay = _WTS_CLIENT_DISPLAY;
  {$EXTERNALSYM WTS_CLIENT_DISPLAY}
  WTS_CLIENT_DISPLAY = _WTS_CLIENT_DISPLAY;
  {$EXTERNALSYM PWTS_CLIENT_DISPLAY}
  PWTS_CLIENT_DISPLAY = PWtsClientDisplay;

  { WTSQuerySessionInformation(WTSSessionAddressV4) }
  PWtsSessionAddress = ^TWtsSessionAddress;
  {$EXTERNALSYM _WTS_SESSION_ADDRESS}
  _WTS_SESSION_ADDRESS = record
    AddressFamily: DWORD;               // AF_INET only
    Address: array[0..19] of Byte;      // client network address
  end;
  TWtsSessionAddress = _WTS_SESSION_ADDRESS;
  {$EXTERNALSYM WTS_SESSION_ADDRESS}
  WTS_SESSION_ADDRESS = _WTS_SESSION_ADDRESS;
  {$EXTERNALSYM PWTS_SESSION_ADDRESS}
  PWTS_SESSION_ADDRESS = PWtsSessionAddress;

  { WTSQueryUserConfig / WTSSetUserConfig(WTSUserConfigUser) }
  {$EXTERNALSYM PWTSUSERCONFIGA}
  PWTSUSERCONFIGA = ^TWtsUserConfigA;
  {$EXTERNALSYM PWTSUSERCONFIGW}
  PWTSUSERCONFIGW = ^TWtsUserConfigW;
  {$EXTERNALSYM PWTSUSERCONFIG}
  PWTSUSERCONFIG = PWTSUSERCONFIGA;
  {$EXTERNALSYM _WTSUSERCONFIGA}
  _WTSUSERCONFIGA = record
    Source: DWORD;                  // WTS_CONFIG_SOURCE
    InheritInitialProgram: DWORD;
    AllowLogonTerminalServer: DWORD;
    TimeoutSettingsConnections: DWORD;
    TimeoutSettingsDisconnections: DWORD;
    TimeoutSettingsIdle: DWORD;
    DeviceClientDrives: DWORD;
    DeviceClientPrinters: DWORD;
    ClientDefaultPrinter: DWORD;
    BrokenTimeoutSettings: DWORD;
    ReconnectSettings: DWORD;
    ShadowingSettings: DWORD;
    TerminalServerRemoteHomeDir: DWORD;
    InitialProgram: array[0..MAX_PATH] of AnsiChar;
    WorkDirectory: array[0..MAX_PATH] of AnsiChar;
    TerminalServerProfilePath: array[0..MAX_PATH] of AnsiChar;
    TerminalServerHomeDir: array[0..MAX_PATH] of AnsiChar;
    TerminalServerHomeDirDrive: array[0..WTS_DRIVE_LENGTH] of AnsiChar;
  end;
  {$EXTERNALSYM _WTSUSERCONFIGW}
  _WTSUSERCONFIGW = record
    Source: DWORD;                  // WTS_CONFIG_SOURCE
    InheritInitialProgram: DWORD;
    AllowLogonTerminalServer: DWORD;
    TimeoutSettingsConnections: DWORD;
    TimeoutSettingsDisconnections: DWORD;
    TimeoutSettingsIdle: DWORD;
    DeviceClientDrives: DWORD;
    DeviceClientPrinters: DWORD;
    ClientDefaultPrinter: DWORD;
    BrokenTimeoutSettings: DWORD;
    ReconnectSettings: DWORD;
    ShadowingSettings: DWORD;
    TerminalServerRemoteHomeDir: DWORD;
    InitialProgram: array[0..MAX_PATH] of WideChar;
    WorkDirectory: array[0..MAX_PATH] of WideChar;
    TerminalServerProfilePath: array[0..MAX_PATH] of WideChar;
    TerminalServerHomeDir: array[0..MAX_PATH] of WideChar;
    TerminalServerHomeDirDrive: array[0..WTS_DRIVE_LENGTH] of WideChar;
  end;
  TWtsUserConfigA = _WTSUSERCONFIGA;
  TWtsUserConfigW = _WTSUSERCONFIGW;
  TWtsUserConfig = TWtsUserConfigA;
  {$EXTERNALSYM WTSUSERCONFIGA}
  WTSUSERCONFIGA = _WTSUSERCONFIGA;
  {$EXTERNALSYM WTSUSERCONFIGW}
  WTSUSERCONFIGW = _WTSUSERCONFIGW;
  {$EXTERNALSYM WTSUSERCONFIG}
  WTSUSERCONFIG = WTSUSERCONFIGA;

{ ====== Functions bound statically (Windows XP) =========================== }

{ kernel32.dll: the session attached to the physical console, or
  $FFFFFFFF while the console session is being attached or detached. }
{$EXTERNALSYM WTSGetActiveConsoleSessionId}
function WTSGetActiveConsoleSessionId: DWORD; stdcall;

{$EXTERNALSYM WTSEnumerateServersA}
function WTSEnumerateServersA(pDomainName: LPSTR; Reserved, Version: DWORD;
  var ppServerInfo: PWTS_SERVER_INFOA; var pCount: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSEnumerateServersW}
function WTSEnumerateServersW(pDomainName: LPWSTR; Reserved, Version: DWORD;
  var ppServerInfo: PWTS_SERVER_INFOW; var pCount: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSEnumerateServers}
function WTSEnumerateServers(pDomainName: LPSTR; Reserved, Version: DWORD;
  var ppServerInfo: PWTS_SERVER_INFOA; var pCount: DWORD): BOOL; stdcall;

{ Close the handle with WTSCloseServer. }
{$EXTERNALSYM WTSOpenServerA}
function WTSOpenServerA(pServerName: LPSTR): THandle; stdcall;
{$EXTERNALSYM WTSOpenServerW}
function WTSOpenServerW(pServerName: LPWSTR): THandle; stdcall;
{$EXTERNALSYM WTSOpenServer}
function WTSOpenServer(pServerName: LPSTR): THandle; stdcall;

{$EXTERNALSYM WTSCloseServer}
procedure WTSCloseServer(hServer: THandle); stdcall;

{ Reserved = 0, Version = 1. }
{$EXTERNALSYM WTSEnumerateSessionsA}
function WTSEnumerateSessionsA(hServer: THandle; Reserved, Version: DWORD;
  var ppSessionInfo: PWTS_SESSION_INFOA; var pCount: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSEnumerateSessionsW}
function WTSEnumerateSessionsW(hServer: THandle; Reserved, Version: DWORD;
  var ppSessionInfo: PWTS_SESSION_INFOW; var pCount: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSEnumerateSessions}
function WTSEnumerateSessions(hServer: THandle; Reserved, Version: DWORD;
  var ppSessionInfo: PWTS_SESSION_INFOA; var pCount: DWORD): BOOL; stdcall;

{ Reserved = 0, Version = 1. }
{$EXTERNALSYM WTSEnumerateProcessesA}
function WTSEnumerateProcessesA(hServer: THandle; Reserved, Version: DWORD;
  var ppProcessInfo: PWTS_PROCESS_INFOA; var pCount: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSEnumerateProcessesW}
function WTSEnumerateProcessesW(hServer: THandle; Reserved, Version: DWORD;
  var ppProcessInfo: PWTS_PROCESS_INFOW; var pCount: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSEnumerateProcesses}
function WTSEnumerateProcesses(hServer: THandle; Reserved, Version: DWORD;
  var ppProcessInfo: PWTS_PROCESS_INFOA; var pCount: DWORD): BOOL; stdcall;

{$EXTERNALSYM WTSTerminateProcess}
function WTSTerminateProcess(hServer: THandle; ProcessId, ExitCode: DWORD): BOOL; stdcall;

{ ppBuffer receives a string or, depending on WTSInfoClass, a structure or
  number (cast it: PDWORD(Buffer)^ for WTSConnectState and WTSSessionId). }
{$EXTERNALSYM WTSQuerySessionInformationA}
function WTSQuerySessionInformationA(hServer: THandle; SessionId: DWORD;
  WTSInfoClass: WTS_INFO_CLASS; var ppBuffer: LPSTR; var pBytesReturned: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSQuerySessionInformationW}
function WTSQuerySessionInformationW(hServer: THandle; SessionId: DWORD;
  WTSInfoClass: WTS_INFO_CLASS; var ppBuffer: LPWSTR; var pBytesReturned: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSQuerySessionInformation}
function WTSQuerySessionInformation(hServer: THandle; SessionId: DWORD;
  WTSInfoClass: WTS_INFO_CLASS; var ppBuffer: LPSTR; var pBytesReturned: DWORD): BOOL; stdcall;

{$EXTERNALSYM WTSQueryUserConfigA}
function WTSQueryUserConfigA(pServerName, pUserName: LPSTR; WTSConfigClass: WTS_CONFIG_CLASS;
  var ppBuffer: LPSTR; var pBytesReturned: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSQueryUserConfigW}
function WTSQueryUserConfigW(pServerName, pUserName: LPWSTR; WTSConfigClass: WTS_CONFIG_CLASS;
  var ppBuffer: LPWSTR; var pBytesReturned: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSQueryUserConfig}
function WTSQueryUserConfig(pServerName, pUserName: LPSTR; WTSConfigClass: WTS_CONFIG_CLASS;
  var ppBuffer: LPSTR; var pBytesReturned: DWORD): BOOL; stdcall;

{$EXTERNALSYM WTSSetUserConfigA}
function WTSSetUserConfigA(pServerName, pUserName: LPSTR; WTSConfigClass: WTS_CONFIG_CLASS;
  pBuffer: LPSTR; DataLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSSetUserConfigW}
function WTSSetUserConfigW(pServerName, pUserName: LPWSTR; WTSConfigClass: WTS_CONFIG_CLASS;
  pBuffer: LPWSTR; DataLength: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSSetUserConfig}
function WTSSetUserConfig(pServerName, pUserName: LPSTR; WTSConfigClass: WTS_CONFIG_CLASS;
  pBuffer: LPSTR; DataLength: DWORD): BOOL; stdcall;

{ TitleLength and MessageLength are in bytes. }
{$EXTERNALSYM WTSSendMessageA}
function WTSSendMessageA(hServer: THandle; SessionId: DWORD; pTitle: LPSTR; TitleLength: DWORD;
  pMessage: LPSTR; MessageLength: DWORD; Style, Timeout: DWORD; var pResponse: DWORD;
  bWait: BOOL): BOOL; stdcall;
{$EXTERNALSYM WTSSendMessageW}
function WTSSendMessageW(hServer: THandle; SessionId: DWORD; pTitle: LPWSTR; TitleLength: DWORD;
  pMessage: LPWSTR; MessageLength: DWORD; Style, Timeout: DWORD; var pResponse: DWORD;
  bWait: BOOL): BOOL; stdcall;
{$EXTERNALSYM WTSSendMessage}
function WTSSendMessage(hServer: THandle; SessionId: DWORD; pTitle: LPSTR; TitleLength: DWORD;
  pMessage: LPSTR; MessageLength: DWORD; Style, Timeout: DWORD; var pResponse: DWORD;
  bWait: BOOL): BOOL; stdcall;

{$EXTERNALSYM WTSDisconnectSession}
function WTSDisconnectSession(hServer: THandle; SessionId: DWORD; bWait: BOOL): BOOL; stdcall;
{$EXTERNALSYM WTSLogoffSession}
function WTSLogoffSession(hServer: THandle; SessionId: DWORD; bWait: BOOL): BOOL; stdcall;
{ ShutdownFlag: WTS_WSD_* }
{$EXTERNALSYM WTSShutdownSystem}
function WTSShutdownSystem(hServer: THandle; ShutdownFlag: DWORD): BOOL; stdcall;
{ EventMask: WTS_EVENT_* }
{$EXTERNALSYM WTSWaitSystemEvent}
function WTSWaitSystemEvent(hServer: THandle; EventMask: DWORD; var pEventFlags: DWORD): BOOL; stdcall;

{ pVirtualName is an ANSI name; close the handle with WTSVirtualChannelClose. }
{$EXTERNALSYM WTSVirtualChannelOpen}
function WTSVirtualChannelOpen(hServer: THandle; SessionId: DWORD;
  pVirtualName: LPSTR): THandle; stdcall;
{$EXTERNALSYM WTSVirtualChannelClose}
function WTSVirtualChannelClose(hChannelHandle: THandle): BOOL; stdcall;
{$EXTERNALSYM WTSVirtualChannelRead}
function WTSVirtualChannelRead(hChannelHandle: THandle; TimeOut: ULONG; Buffer: Pointer;
  BufferSize: ULONG; var pBytesRead: ULONG): BOOL; stdcall;
{$EXTERNALSYM WTSVirtualChannelWrite}
function WTSVirtualChannelWrite(hChannelHandle: THandle; Buffer: Pointer; Length: ULONG;
  var pBytesWritten: ULONG): BOOL; stdcall;
{$EXTERNALSYM WTSVirtualChannelPurgeInput}
function WTSVirtualChannelPurgeInput(hChannelHandle: THandle): BOOL; stdcall;
{$EXTERNALSYM WTSVirtualChannelPurgeOutput}
function WTSVirtualChannelPurgeOutput(hChannelHandle: THandle): BOOL; stdcall;
{$EXTERNALSYM WTSVirtualChannelQuery}
function WTSVirtualChannelQuery(hChannelHandle: THandle; VirtualClass: WTS_VIRTUAL_CLASS;
  var ppBuffer: Pointer; var pBytesReturned: DWORD): BOOL; stdcall;

{$EXTERNALSYM WTSFreeMemory}
procedure WTSFreeMemory(pMemory: Pointer); stdcall;

{ dwFlags: NOTIFY_FOR_THIS_SESSION or NOTIFY_FOR_ALL_SESSIONS; the window
  receives WM_WTSSESSION_CHANGE. }
{$EXTERNALSYM WTSRegisterSessionNotification}
function WTSRegisterSessionNotification(hWnd: HWND; dwFlags: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSUnRegisterSessionNotification}
function WTSUnRegisterSessionNotification(hWnd: HWND): BOOL; stdcall;

{ Needs the SE_TCB_NAME privilege (services running as LocalSystem). }
{$EXTERNALSYM WTSQueryUserToken}
function WTSQueryUserToken(SessionId: ULONG; var phToken: THandle): BOOL; stdcall;

{ ====== Functions bound at run time (Windows Vista and later) ============= }

{ Windows Vista. Fallback: False (SetLastError(ERROR_CALL_NOT_IMPLEMENTED)). }
{$EXTERNALSYM WTSStopRemoteControlSession}
function WTSStopRemoteControlSession(LogonId: ULONG): BOOL; stdcall;
{ Windows Vista. Fallback: False (SetLastError(ERROR_CALL_NOT_IMPLEMENTED)). }
{$EXTERNALSYM WTSStartRemoteControlSessionA}
function WTSStartRemoteControlSessionA(pTargetServerName: LPSTR; TargetLogonId: ULONG;
  HotkeyVk: Byte; HotkeyModifiers: Word): BOOL; stdcall;
{$EXTERNALSYM WTSStartRemoteControlSessionW}
function WTSStartRemoteControlSessionW(pTargetServerName: LPWSTR; TargetLogonId: ULONG;
  HotkeyVk: Byte; HotkeyModifiers: Word): BOOL; stdcall;
{$EXTERNALSYM WTSStartRemoteControlSession}
function WTSStartRemoteControlSession(pTargetServerName: LPSTR; TargetLogonId: ULONG;
  HotkeyVk: Byte; HotkeyModifiers: Word): BOOL; stdcall;

{ Windows Vista. Fallback: False (SetLastError(ERROR_CALL_NOT_IMPLEMENTED)). }
{$EXTERNALSYM WTSConnectSessionA}
function WTSConnectSessionA(LogonId, TargetLogonId: ULONG; pPassword: LPSTR;
  bWait: BOOL): BOOL; stdcall;
{$EXTERNALSYM WTSConnectSessionW}
function WTSConnectSessionW(LogonId, TargetLogonId: ULONG; pPassword: LPWSTR;
  bWait: BOOL): BOOL; stdcall;
{$EXTERNALSYM WTSConnectSession}
function WTSConnectSession(LogonId, TargetLogonId: ULONG; pPassword: LPSTR;
  bWait: BOOL): BOOL; stdcall;

{ Windows 7. Fallback: WTSOpenServerA / WTSOpenServerW (the same call before
  Remote Desktop Virtualization Host servers existed). }
{$EXTERNALSYM WTSOpenServerExA}
function WTSOpenServerExA(pServerName: LPSTR): THandle; stdcall;
{$EXTERNALSYM WTSOpenServerExW}
function WTSOpenServerExW(pServerName: LPWSTR): THandle; stdcall;
{$EXTERNALSYM WTSOpenServerEx}
function WTSOpenServerEx(pServerName: LPSTR): THandle; stdcall;

{ Windows 7. pLevel = 1 (WTS_SESSION_INFO_1), Filter = 0; free the array
  with WTSFreeMemoryEx(WTSTypeSessionInfoLevel1, ...). Fallback: False
  (SetLastError(ERROR_CALL_NOT_IMPLEMENTED)), ppSessionInfo = nil, pCount = 0. }
{$EXTERNALSYM WTSEnumerateSessionsExA}
function WTSEnumerateSessionsExA(hServer: THandle; var pLevel: DWORD; Filter: DWORD;
  var ppSessionInfo: PWTS_SESSION_INFO_1A; var pCount: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSEnumerateSessionsExW}
function WTSEnumerateSessionsExW(hServer: THandle; var pLevel: DWORD; Filter: DWORD;
  var ppSessionInfo: PWTS_SESSION_INFO_1W; var pCount: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSEnumerateSessionsEx}
function WTSEnumerateSessionsEx(hServer: THandle; var pLevel: DWORD; Filter: DWORD;
  var ppSessionInfo: PWTS_SESSION_INFO_1A; var pCount: DWORD): BOOL; stdcall;

{ Windows 7. pLevel: WTS_PROCESS_INFO_LEVEL_0 (ppProcessInfo receives
  WTS_PROCESS_INFO records) or WTS_PROCESS_INFO_LEVEL_1 (WTS_PROCESS_INFO_EX);
  SessionId may be WTS_ANY_SESSION. Free the array with
  WTSFreeMemoryEx(WTSTypeProcessInfoLevel0/1, ...). The A function returns
  each pProcessName cut to half its length ("sysunitstest.exe" becomes
  "sysunits"; measured on Windows 11 26200, the same from C): use
  WTSEnumerateProcessesExW for the names. Fallback: False
  (SetLastError(ERROR_CALL_NOT_IMPLEMENTED)), ppProcessInfo = nil, pCount = 0. }
{$EXTERNALSYM WTSEnumerateProcessesExA}
function WTSEnumerateProcessesExA(hServer: THandle; var pLevel: DWORD; SessionId: DWORD;
  var ppProcessInfo: Pointer; var pCount: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSEnumerateProcessesExW}
function WTSEnumerateProcessesExW(hServer: THandle; var pLevel: DWORD; SessionId: DWORD;
  var ppProcessInfo: Pointer; var pCount: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSEnumerateProcessesEx}
function WTSEnumerateProcessesEx(hServer: THandle; var pLevel: DWORD; SessionId: DWORD;
  var ppProcessInfo: Pointer; var pCount: DWORD): BOOL; stdcall;

{ Windows 7. Fallback: False (SetLastError(ERROR_CALL_NOT_IMPLEMENTED)). }
{$EXTERNALSYM WTSFreeMemoryExA}
function WTSFreeMemoryExA(WTSTypeClass: WTS_TYPE_CLASS; pMemory: Pointer;
  NumberOfEntries: ULONG): BOOL; stdcall;
{$EXTERNALSYM WTSFreeMemoryExW}
function WTSFreeMemoryExW(WTSTypeClass: WTS_TYPE_CLASS; pMemory: Pointer;
  NumberOfEntries: ULONG): BOOL; stdcall;
{$EXTERNALSYM WTSFreeMemoryEx}
function WTSFreeMemoryEx(WTSTypeClass: WTS_TYPE_CLASS; pMemory: Pointer;
  NumberOfEntries: ULONG): BOOL; stdcall;

{ Windows Vista; flags: WTS_CHANNEL_OPTION_*. Fallback: 0
  (SetLastError(ERROR_CALL_NOT_IMPLEMENTED)). }
{$EXTERNALSYM WTSVirtualChannelOpenEx}
function WTSVirtualChannelOpenEx(SessionId: DWORD; pVirtualName: LPSTR;
  flags: DWORD): THandle; stdcall;

{ Windows Vista. Fallback: WTSRegisterSessionNotification /
  WTSUnRegisterSessionNotification when hServer is WTS_CURRENT_SERVER_HANDLE,
  otherwise False (SetLastError(ERROR_CALL_NOT_IMPLEMENTED)). }
{$EXTERNALSYM WTSRegisterSessionNotificationEx}
function WTSRegisterSessionNotificationEx(hServer: THandle; hWnd: HWND;
  dwFlags: DWORD): BOOL; stdcall;
{$EXTERNALSYM WTSUnRegisterSessionNotificationEx}
function WTSUnRegisterSessionNotificationEx(hServer: THandle; hWnd: HWND): BOOL; stdcall;

{ Windows 8. wtsapi32.h declares these three without WINAPI, but
  wtsapi32.dll exports them as stdcall (wtsapi32.lib: _WTSEnableChildSessions@4).
  Fallback: False (SetLastError(ERROR_CALL_NOT_IMPLEMENTED)); the output
  parameter is set to False / 0. }
{$EXTERNALSYM WTSEnableChildSessions}
function WTSEnableChildSessions(bEnable: BOOL): BOOL; stdcall;
{$EXTERNALSYM WTSIsChildSessionsEnabled}
function WTSIsChildSessionsEnabled(var pbEnabled: BOOL): BOOL; stdcall;
{$EXTERNALSYM WTSGetChildSessionId}
function WTSGetChildSessionId(var pSessionId: ULONG): BOOL; stdcall;

implementation

const
  wtsapilib = 'wtsapi32.dll';
  kernel32 = 'kernel32.dll';

{ ---- static bindings ---- }

function WTSGetActiveConsoleSessionId; external kernel32 name 'WTSGetActiveConsoleSessionId';
function WTSEnumerateServersA; external wtsapilib name 'WTSEnumerateServersA';
function WTSEnumerateServersW; external wtsapilib name 'WTSEnumerateServersW';
function WTSEnumerateServers; external wtsapilib name 'WTSEnumerateServersA';
function WTSOpenServerA; external wtsapilib name 'WTSOpenServerA';
function WTSOpenServerW; external wtsapilib name 'WTSOpenServerW';
function WTSOpenServer; external wtsapilib name 'WTSOpenServerA';
procedure WTSCloseServer; external wtsapilib name 'WTSCloseServer';
function WTSEnumerateSessionsA; external wtsapilib name 'WTSEnumerateSessionsA';
function WTSEnumerateSessionsW; external wtsapilib name 'WTSEnumerateSessionsW';
function WTSEnumerateSessions; external wtsapilib name 'WTSEnumerateSessionsA';
function WTSEnumerateProcessesA; external wtsapilib name 'WTSEnumerateProcessesA';
function WTSEnumerateProcessesW; external wtsapilib name 'WTSEnumerateProcessesW';
function WTSEnumerateProcesses; external wtsapilib name 'WTSEnumerateProcessesA';
function WTSTerminateProcess; external wtsapilib name 'WTSTerminateProcess';
function WTSQuerySessionInformationA; external wtsapilib name 'WTSQuerySessionInformationA';
function WTSQuerySessionInformationW; external wtsapilib name 'WTSQuerySessionInformationW';
function WTSQuerySessionInformation; external wtsapilib name 'WTSQuerySessionInformationA';
function WTSQueryUserConfigA; external wtsapilib name 'WTSQueryUserConfigA';
function WTSQueryUserConfigW; external wtsapilib name 'WTSQueryUserConfigW';
function WTSQueryUserConfig; external wtsapilib name 'WTSQueryUserConfigA';
function WTSSetUserConfigA; external wtsapilib name 'WTSSetUserConfigA';
function WTSSetUserConfigW; external wtsapilib name 'WTSSetUserConfigW';
function WTSSetUserConfig; external wtsapilib name 'WTSSetUserConfigA';
function WTSSendMessageA; external wtsapilib name 'WTSSendMessageA';
function WTSSendMessageW; external wtsapilib name 'WTSSendMessageW';
function WTSSendMessage; external wtsapilib name 'WTSSendMessageA';
function WTSDisconnectSession; external wtsapilib name 'WTSDisconnectSession';
function WTSLogoffSession; external wtsapilib name 'WTSLogoffSession';
function WTSShutdownSystem; external wtsapilib name 'WTSShutdownSystem';
function WTSWaitSystemEvent; external wtsapilib name 'WTSWaitSystemEvent';
function WTSVirtualChannelOpen; external wtsapilib name 'WTSVirtualChannelOpen';
function WTSVirtualChannelClose; external wtsapilib name 'WTSVirtualChannelClose';
function WTSVirtualChannelRead; external wtsapilib name 'WTSVirtualChannelRead';
function WTSVirtualChannelWrite; external wtsapilib name 'WTSVirtualChannelWrite';
function WTSVirtualChannelPurgeInput; external wtsapilib name 'WTSVirtualChannelPurgeInput';
function WTSVirtualChannelPurgeOutput; external wtsapilib name 'WTSVirtualChannelPurgeOutput';
function WTSVirtualChannelQuery; external wtsapilib name 'WTSVirtualChannelQuery';
procedure WTSFreeMemory; external wtsapilib name 'WTSFreeMemory';
function WTSRegisterSessionNotification; external wtsapilib name 'WTSRegisterSessionNotification';
function WTSUnRegisterSessionNotification; external wtsapilib name 'WTSUnRegisterSessionNotification';
function WTSQueryUserToken; external wtsapilib name 'WTSQueryUserToken';

{ ---- run-time binding ---- }

var
  WtsModule: HMODULE;
  WtsLoaded: Boolean;
  WTSStopRemoteControlSessionProc: Pointer;
  WTSStartRemoteControlSessionAProc: Pointer;
  WTSStartRemoteControlSessionWProc: Pointer;
  WTSConnectSessionAProc: Pointer;
  WTSConnectSessionWProc: Pointer;
  WTSOpenServerExAProc: Pointer;
  WTSOpenServerExWProc: Pointer;
  WTSEnumerateSessionsExAProc: Pointer;
  WTSEnumerateSessionsExWProc: Pointer;
  WTSEnumerateProcessesExAProc: Pointer;
  WTSEnumerateProcessesExWProc: Pointer;
  WTSFreeMemoryExAProc: Pointer;
  WTSFreeMemoryExWProc: Pointer;
  WTSVirtualChannelOpenExProc: Pointer;
  WTSRegisterSessionNotificationExProc: Pointer;
  WTSUnRegisterSessionNotificationExProc: Pointer;
  WTSEnableChildSessionsProc: Pointer;
  WTSIsChildSessionsEnabledProc: Pointer;
  WTSGetChildSessionIdProc: Pointer;

type
  TWtsULongFn = function(Value: ULONG): BOOL; stdcall;
  TWtsPtrFn = function(P: Pointer): BOOL; stdcall;
  TWtsStartRemoteControlSessionFn = function(pTargetServerName: Pointer; TargetLogonId: ULONG;
    HotkeyVk: Byte; HotkeyModifiers: Word): BOOL; stdcall;
  TWtsConnectSessionFn = function(LogonId, TargetLogonId: ULONG; pPassword: Pointer;
    bWait: Integer): BOOL; stdcall;
  TWtsOpenServerExFn = function(pServerName: Pointer): THandle; stdcall;
  TWtsEnumerateExFn = function(hServer: THandle; var pLevel: DWORD; Filter: DWORD;
    var ppInfo: Pointer; var pCount: DWORD): BOOL; stdcall;
  TWtsFreeMemoryExFn = function(WTSTypeClass: WTS_TYPE_CLASS; pMemory: Pointer;
    NumberOfEntries: ULONG): BOOL; stdcall;
  TWtsVirtualChannelOpenExFn = function(SessionId: DWORD; pVirtualName: LPSTR;
    flags: DWORD): THandle; stdcall;
  TWtsRegisterSessionNotificationExFn = function(hServer: THandle; hWnd: HWND;
    dwFlags: DWORD): BOOL; stdcall;
  TWtsUnRegisterSessionNotificationExFn = function(hServer: THandle; hWnd: HWND): BOOL; stdcall;
  TWtsBoolArgFn = function(Value: Integer): BOOL; stdcall;

{ wtsapi32.dll is loaded once, from the system directory only (it is not a
  known DLL, so this avoids search-order planting), and never released. A
  missing DLL is remembered; a function pointer is cached once found. }
function GetWtsProc(var Proc: Pointer; Name: PChar): Boolean;
var
  Path: array[0..MAX_PATH + 16] of Char;
  Len: UINT;
begin
  if Proc = nil then
  begin
    if not WtsLoaded then
    begin
      Len := GetSystemDirectory(Path, MAX_PATH);
      if (Len > 0) and (Len < MAX_PATH) then
      begin
        lstrcat(Path, '\' + wtsapilib);
        WtsModule := LoadLibrary(Path);
      end;
      WtsLoaded := True;
    end;
    if WtsModule <> 0 then
      Proc := GetProcAddress(WtsModule, Name);
  end;
  Result := Proc <> nil;
end;

{ Delphi passes True as -1 in a BOOL; BOOL arguments are passed as 0 or 1. }
function WtsBoolArg(Value: BOOL): Integer;
begin
  if Value then
    Result := 1
  else
    Result := 0;
end;

function WtsNotImplemented: BOOL;
begin
  SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
  Result := False;
end;

function WTSStopRemoteControlSession(LogonId: ULONG): BOOL; stdcall;
begin
  if GetWtsProc(WTSStopRemoteControlSessionProc, 'WTSStopRemoteControlSession') then
    Result := TWtsULongFn(WTSStopRemoteControlSessionProc)(LogonId)
  else
    Result := WtsNotImplemented;
end;

function WTSStartRemoteControlSessionA(pTargetServerName: LPSTR; TargetLogonId: ULONG;
  HotkeyVk: Byte; HotkeyModifiers: Word): BOOL; stdcall;
begin
  if GetWtsProc(WTSStartRemoteControlSessionAProc, 'WTSStartRemoteControlSessionA') then
    Result := TWtsStartRemoteControlSessionFn(WTSStartRemoteControlSessionAProc)(
      pTargetServerName, TargetLogonId, HotkeyVk, HotkeyModifiers)
  else
    Result := WtsNotImplemented;
end;

function WTSStartRemoteControlSessionW(pTargetServerName: LPWSTR; TargetLogonId: ULONG;
  HotkeyVk: Byte; HotkeyModifiers: Word): BOOL; stdcall;
begin
  if GetWtsProc(WTSStartRemoteControlSessionWProc, 'WTSStartRemoteControlSessionW') then
    Result := TWtsStartRemoteControlSessionFn(WTSStartRemoteControlSessionWProc)(
      pTargetServerName, TargetLogonId, HotkeyVk, HotkeyModifiers)
  else
    Result := WtsNotImplemented;
end;

function WTSStartRemoteControlSession(pTargetServerName: LPSTR; TargetLogonId: ULONG;
  HotkeyVk: Byte; HotkeyModifiers: Word): BOOL; stdcall;
begin
  Result := WTSStartRemoteControlSessionA(pTargetServerName, TargetLogonId, HotkeyVk,
    HotkeyModifiers);
end;

function WTSConnectSessionA(LogonId, TargetLogonId: ULONG; pPassword: LPSTR;
  bWait: BOOL): BOOL; stdcall;
begin
  if GetWtsProc(WTSConnectSessionAProc, 'WTSConnectSessionA') then
    Result := TWtsConnectSessionFn(WTSConnectSessionAProc)(LogonId, TargetLogonId, pPassword,
      WtsBoolArg(bWait))
  else
    Result := WtsNotImplemented;
end;

function WTSConnectSessionW(LogonId, TargetLogonId: ULONG; pPassword: LPWSTR;
  bWait: BOOL): BOOL; stdcall;
begin
  if GetWtsProc(WTSConnectSessionWProc, 'WTSConnectSessionW') then
    Result := TWtsConnectSessionFn(WTSConnectSessionWProc)(LogonId, TargetLogonId, pPassword,
      WtsBoolArg(bWait))
  else
    Result := WtsNotImplemented;
end;

function WTSConnectSession(LogonId, TargetLogonId: ULONG; pPassword: LPSTR;
  bWait: BOOL): BOOL; stdcall;
begin
  Result := WTSConnectSessionA(LogonId, TargetLogonId, pPassword, bWait);
end;

function WTSOpenServerExA(pServerName: LPSTR): THandle; stdcall;
begin
  if GetWtsProc(WTSOpenServerExAProc, 'WTSOpenServerExA') then
    Result := TWtsOpenServerExFn(WTSOpenServerExAProc)(pServerName)
  else
    Result := WTSOpenServerA(pServerName);
end;

function WTSOpenServerExW(pServerName: LPWSTR): THandle; stdcall;
begin
  if GetWtsProc(WTSOpenServerExWProc, 'WTSOpenServerExW') then
    Result := TWtsOpenServerExFn(WTSOpenServerExWProc)(pServerName)
  else
    Result := WTSOpenServerW(pServerName);
end;

function WTSOpenServerEx(pServerName: LPSTR): THandle; stdcall;
begin
  Result := WTSOpenServerExA(pServerName);
end;

function WTSEnumerateSessionsExA(hServer: THandle; var pLevel: DWORD; Filter: DWORD;
  var ppSessionInfo: PWTS_SESSION_INFO_1A; var pCount: DWORD): BOOL; stdcall;
begin
  if GetWtsProc(WTSEnumerateSessionsExAProc, 'WTSEnumerateSessionsExA') then
    Result := TWtsEnumerateExFn(WTSEnumerateSessionsExAProc)(hServer, pLevel, Filter,
      Pointer(ppSessionInfo), pCount)
  else
  begin
    ppSessionInfo := nil;
    pCount := 0;
    Result := WtsNotImplemented;
  end;
end;

function WTSEnumerateSessionsExW(hServer: THandle; var pLevel: DWORD; Filter: DWORD;
  var ppSessionInfo: PWTS_SESSION_INFO_1W; var pCount: DWORD): BOOL; stdcall;
begin
  if GetWtsProc(WTSEnumerateSessionsExWProc, 'WTSEnumerateSessionsExW') then
    Result := TWtsEnumerateExFn(WTSEnumerateSessionsExWProc)(hServer, pLevel, Filter,
      Pointer(ppSessionInfo), pCount)
  else
  begin
    ppSessionInfo := nil;
    pCount := 0;
    Result := WtsNotImplemented;
  end;
end;

function WTSEnumerateSessionsEx(hServer: THandle; var pLevel: DWORD; Filter: DWORD;
  var ppSessionInfo: PWTS_SESSION_INFO_1A; var pCount: DWORD): BOOL; stdcall;
begin
  Result := WTSEnumerateSessionsExA(hServer, pLevel, Filter, ppSessionInfo, pCount);
end;

function WTSEnumerateProcessesExA(hServer: THandle; var pLevel: DWORD; SessionId: DWORD;
  var ppProcessInfo: Pointer; var pCount: DWORD): BOOL; stdcall;
begin
  if GetWtsProc(WTSEnumerateProcessesExAProc, 'WTSEnumerateProcessesExA') then
    Result := TWtsEnumerateExFn(WTSEnumerateProcessesExAProc)(hServer, pLevel, SessionId,
      ppProcessInfo, pCount)
  else
  begin
    ppProcessInfo := nil;
    pCount := 0;
    Result := WtsNotImplemented;
  end;
end;

function WTSEnumerateProcessesExW(hServer: THandle; var pLevel: DWORD; SessionId: DWORD;
  var ppProcessInfo: Pointer; var pCount: DWORD): BOOL; stdcall;
begin
  if GetWtsProc(WTSEnumerateProcessesExWProc, 'WTSEnumerateProcessesExW') then
    Result := TWtsEnumerateExFn(WTSEnumerateProcessesExWProc)(hServer, pLevel, SessionId,
      ppProcessInfo, pCount)
  else
  begin
    ppProcessInfo := nil;
    pCount := 0;
    Result := WtsNotImplemented;
  end;
end;

function WTSEnumerateProcessesEx(hServer: THandle; var pLevel: DWORD; SessionId: DWORD;
  var ppProcessInfo: Pointer; var pCount: DWORD): BOOL; stdcall;
begin
  Result := WTSEnumerateProcessesExA(hServer, pLevel, SessionId, ppProcessInfo, pCount);
end;

function WTSFreeMemoryExA(WTSTypeClass: WTS_TYPE_CLASS; pMemory: Pointer;
  NumberOfEntries: ULONG): BOOL; stdcall;
begin
  if GetWtsProc(WTSFreeMemoryExAProc, 'WTSFreeMemoryExA') then
    Result := TWtsFreeMemoryExFn(WTSFreeMemoryExAProc)(WTSTypeClass, pMemory, NumberOfEntries)
  else
    Result := WtsNotImplemented;
end;

function WTSFreeMemoryExW(WTSTypeClass: WTS_TYPE_CLASS; pMemory: Pointer;
  NumberOfEntries: ULONG): BOOL; stdcall;
begin
  if GetWtsProc(WTSFreeMemoryExWProc, 'WTSFreeMemoryExW') then
    Result := TWtsFreeMemoryExFn(WTSFreeMemoryExWProc)(WTSTypeClass, pMemory, NumberOfEntries)
  else
    Result := WtsNotImplemented;
end;

function WTSFreeMemoryEx(WTSTypeClass: WTS_TYPE_CLASS; pMemory: Pointer;
  NumberOfEntries: ULONG): BOOL; stdcall;
begin
  Result := WTSFreeMemoryExA(WTSTypeClass, pMemory, NumberOfEntries);
end;

function WTSVirtualChannelOpenEx(SessionId: DWORD; pVirtualName: LPSTR;
  flags: DWORD): THandle; stdcall;
begin
  if GetWtsProc(WTSVirtualChannelOpenExProc, 'WTSVirtualChannelOpenEx') then
    Result := TWtsVirtualChannelOpenExFn(WTSVirtualChannelOpenExProc)(SessionId, pVirtualName,
      flags)
  else
  begin
    SetLastError(ERROR_CALL_NOT_IMPLEMENTED);
    Result := 0;
  end;
end;

function WTSRegisterSessionNotificationEx(hServer: THandle; hWnd: HWND;
  dwFlags: DWORD): BOOL; stdcall;
begin
  if GetWtsProc(WTSRegisterSessionNotificationExProc, 'WTSRegisterSessionNotificationEx') then
    Result := TWtsRegisterSessionNotificationExFn(WTSRegisterSessionNotificationExProc)(hServer,
      hWnd, dwFlags)
  else if hServer = WTS_CURRENT_SERVER_HANDLE then
    Result := WTSRegisterSessionNotification(hWnd, dwFlags)
  else
    Result := WtsNotImplemented;
end;

function WTSUnRegisterSessionNotificationEx(hServer: THandle; hWnd: HWND): BOOL; stdcall;
begin
  if GetWtsProc(WTSUnRegisterSessionNotificationExProc, 'WTSUnRegisterSessionNotificationEx') then
    Result := TWtsUnRegisterSessionNotificationExFn(WTSUnRegisterSessionNotificationExProc)(
      hServer, hWnd)
  else if hServer = WTS_CURRENT_SERVER_HANDLE then
    Result := WTSUnRegisterSessionNotification(hWnd)
  else
    Result := WtsNotImplemented;
end;

function WTSEnableChildSessions(bEnable: BOOL): BOOL; stdcall;
begin
  if GetWtsProc(WTSEnableChildSessionsProc, 'WTSEnableChildSessions') then
    Result := TWtsBoolArgFn(WTSEnableChildSessionsProc)(WtsBoolArg(bEnable))
  else
    Result := WtsNotImplemented;
end;

function WTSIsChildSessionsEnabled(var pbEnabled: BOOL): BOOL; stdcall;
begin
  if GetWtsProc(WTSIsChildSessionsEnabledProc, 'WTSIsChildSessionsEnabled') then
    Result := TWtsPtrFn(WTSIsChildSessionsEnabledProc)(@pbEnabled)
  else
  begin
    pbEnabled := False;
    Result := WtsNotImplemented;
  end;
end;

function WTSGetChildSessionId(var pSessionId: ULONG): BOOL; stdcall;
begin
  if GetWtsProc(WTSGetChildSessionIdProc, 'WTSGetChildSessionId') then
    Result := TWtsPtrFn(WTSGetChildSessionIdProc)(@pSessionId)
  else
  begin
    pSessionId := 0;
    Result := WtsNotImplemented;
  end;
end;

end.
