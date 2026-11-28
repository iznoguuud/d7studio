{**********************************************************}
{                                                          }
{     Delphi 7 Runtime Library - Modernization             }
{     User profiles and environment (userenv.h)            }
{     Windows XP .. Windows 11                             }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit UserEnv;

{ Translated from userenv.h and profinfo.h (Windows SDK 10.0.26100).

  Binding:
    - functions that exist in Windows XP are bound statically (userenv.dll);
    - CreateProfile (Windows Vista) and the AppContainer functions (Windows
      8 and 8.1) are bound at run time on first use (userenv.dll is loaded
      from the system directory), so programs that use this unit still start
      on Windows XP. When such a function is missing it returns E_NOTIMPL
      and clears its output parameters.

  Generic names (no A/W suffix) map to the A functions and types, as in
  Windows.pas. The AppContainer functions exist only as wide-string
  functions.

  Not translated: the group policy extension API (GetGPOList,
  GetAppliedGPOList, ProcessGroupPolicyCompleted, the RSoP functions and
  their structures) and GenerateGPNotification. }

{$WEAKPACKAGEUNIT ON}
{$MINENUMSIZE 4}

interface

uses
  Windows;

{ ====== Profiles (profinfo.h, userenv.h) ================================== }

type
  { LoadUserProfile }
  PProfileInfoA = ^TProfileInfoA;
  PProfileInfoW = ^TProfileInfoW;
  PProfileInfo = PProfileInfoA;
  {$EXTERNALSYM _PROFILEINFOA}
  _PROFILEINFOA = record
    dwSize: DWORD;          // set to SizeOf(PROFILEINFO) before calling
    dwFlags: DWORD;         // PI_NOUI, PI_APPLYPOLICY
    lpUserName: LPSTR;      // user name (required)
    lpProfilePath: LPSTR;   // roaming profile path (optional, can be nil)
    lpDefaultPath: LPSTR;   // default user profile path (optional, can be nil)
    lpServerName: LPSTR;    // validating domain controller name in NetBIOS format (optional)
    lpPolicyPath: LPSTR;    // path to the NT4 style policy file (optional, can be nil)
    hProfile: THandle;      // filled in by the function: registry key handle open to the root
  end;
  {$EXTERNALSYM _PROFILEINFOW}
  _PROFILEINFOW = record
    dwSize: DWORD;          // set to SizeOf(PROFILEINFO) before calling
    dwFlags: DWORD;         // PI_NOUI, PI_APPLYPOLICY
    lpUserName: LPWSTR;     // user name (required)
    lpProfilePath: LPWSTR;  // roaming profile path (optional, can be nil)
    lpDefaultPath: LPWSTR;  // default user profile path (optional, can be nil)
    lpServerName: LPWSTR;   // validating domain controller name in NetBIOS format (optional)
    lpPolicyPath: LPWSTR;   // path to the NT4 style policy file (optional, can be nil)
    hProfile: THandle;      // filled in by the function: registry key handle open to the root
  end;
  TProfileInfoA = _PROFILEINFOA;
  TProfileInfoW = _PROFILEINFOW;
  TProfileInfo = TProfileInfoA;
  {$EXTERNALSYM PROFILEINFOA}
  PROFILEINFOA = _PROFILEINFOA;
  {$EXTERNALSYM PROFILEINFOW}
  PROFILEINFOW = _PROFILEINFOW;
  {$EXTERNALSYM PROFILEINFO}
  PROFILEINFO = PROFILEINFOA;
  {$EXTERNALSYM LPPROFILEINFOA}
  LPPROFILEINFOA = PProfileInfoA;
  {$EXTERNALSYM LPPROFILEINFOW}
  LPPROFILEINFOW = PProfileInfoW;
  {$EXTERNALSYM LPPROFILEINFO}
  LPPROFILEINFO = LPPROFILEINFOA;

const
  { PROFILEINFO.dwFlags }
  {$EXTERNALSYM PI_NOUI}
  PI_NOUI        = $00000001;  // prevents displaying of messages
  {$EXTERNALSYM PI_APPLYPOLICY}
  PI_APPLYPOLICY = $00000002;  // apply NT4 style policy

  { GetProfileType flags }
  {$EXTERNALSYM PT_TEMPORARY}
  PT_TEMPORARY           = $00000001;  // the profile is deleted at logoff
  {$EXTERNALSYM PT_ROAMING}
  PT_ROAMING             = $00000002;  // the loaded profile is a roaming profile
  {$EXTERNALSYM PT_MANDATORY}
  PT_MANDATORY           = $00000004;  // the loaded profile is mandatory
  {$EXTERNALSYM PT_ROAMING_PREEXISTING}
  PT_ROAMING_PREEXISTING = $00000008;  // the roaming profile was obtained from the roamed location
  {$EXTERNALSYM PT_COMPOSABLE_AGENT}
  PT_COMPOSABLE_AGENT    = $00000010;  // composable isolation-session agent (console only)
  {$EXTERNALSYM PT_SHELL_AGENT}
  PT_SHELL_AGENT         = $00000020;  // isolation-session agent with a shell

  { RefreshPolicyEx options }
  {$EXTERNALSYM RP_FORCE}
  RP_FORCE = 1;  // refresh policies without any optimisations
  {$EXTERNALSYM RP_SYNC}
  RP_SYNC  = 2;  // return only when policy processing is completed

{ ====== Functions bound statically (Windows XP) =========================== }

{ hToken needs TOKEN_QUERY, TOKEN_IMPERSONATE and TOKEN_DUPLICATE; the
  caller needs administrative rights. Unload with UnloadUserProfile. }
{$EXTERNALSYM LoadUserProfileA}
function LoadUserProfileA(hToken: THandle; var lpProfileInfo: PROFILEINFOA): BOOL; stdcall;
{$EXTERNALSYM LoadUserProfileW}
function LoadUserProfileW(hToken: THandle; var lpProfileInfo: PROFILEINFOW): BOOL; stdcall;
{$EXTERNALSYM LoadUserProfile}
function LoadUserProfile(hToken: THandle; var lpProfileInfo: PROFILEINFOA): BOOL; stdcall;
{$EXTERNALSYM UnloadUserProfile}
function UnloadUserProfile(hToken, hProfile: THandle): BOOL; stdcall;

{ lpcchSize: buffer size in characters on input; when the buffer is too
  small the function fails with ERROR_INSUFFICIENT_BUFFER and lpcchSize
  receives the size needed, including the terminating null. lpProfileDir =
  nil queries the size with the W functions only: the A functions fail with
  ERROR_INVALID_PARAMETER and lpcchSize = 0 (measured on Windows 11 26200,
  also for GetAllUsersProfileDirectoryA, GetDefaultUserProfileDirectoryA and
  GetUserProfileDirectoryA). }
{$EXTERNALSYM GetProfilesDirectoryA}
function GetProfilesDirectoryA(lpProfileDir: LPSTR; var lpcchSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetProfilesDirectoryW}
function GetProfilesDirectoryW(lpProfileDir: LPWSTR; var lpcchSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetProfilesDirectory}
function GetProfilesDirectory(lpProfileDir: LPSTR; var lpcchSize: DWORD): BOOL; stdcall;

{ dwFlags receives PT_* flags (0: a local profile). }
{$EXTERNALSYM GetProfileType}
function GetProfileType(var dwFlags: DWORD): BOOL; stdcall;

{$EXTERNALSYM DeleteProfileA}
function DeleteProfileA(lpSidString, lpProfilePath, lpComputerName: LPCSTR): BOOL; stdcall;
{$EXTERNALSYM DeleteProfileW}
function DeleteProfileW(lpSidString, lpProfilePath, lpComputerName: LPCWSTR): BOOL; stdcall;
{$EXTERNALSYM DeleteProfile}
function DeleteProfile(lpSidString, lpProfilePath, lpComputerName: LPCSTR): BOOL; stdcall;

{$EXTERNALSYM GetDefaultUserProfileDirectoryA}
function GetDefaultUserProfileDirectoryA(lpProfileDir: LPSTR; var lpcchSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetDefaultUserProfileDirectoryW}
function GetDefaultUserProfileDirectoryW(lpProfileDir: LPWSTR; var lpcchSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetDefaultUserProfileDirectory}
function GetDefaultUserProfileDirectory(lpProfileDir: LPSTR; var lpcchSize: DWORD): BOOL; stdcall;

{$EXTERNALSYM GetAllUsersProfileDirectoryA}
function GetAllUsersProfileDirectoryA(lpProfileDir: LPSTR; var lpcchSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetAllUsersProfileDirectoryW}
function GetAllUsersProfileDirectoryW(lpProfileDir: LPWSTR; var lpcchSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetAllUsersProfileDirectory}
function GetAllUsersProfileDirectory(lpProfileDir: LPSTR; var lpcchSize: DWORD): BOOL; stdcall;

{ hToken needs TOKEN_QUERY. lpcchSize: as for GetProfilesDirectory. }
{$EXTERNALSYM GetUserProfileDirectoryA}
function GetUserProfileDirectoryA(hToken: THandle; lpProfileDir: LPSTR;
  var lpcchSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetUserProfileDirectoryW}
function GetUserProfileDirectoryW(hToken: THandle; lpProfileDir: LPWSTR;
  var lpcchSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetUserProfileDirectory}
function GetUserProfileDirectory(hToken: THandle; lpProfileDir: LPSTR;
  var lpcchSize: DWORD): BOOL; stdcall;

{ lpEnvironment receives a Unicode environment block (pass
  CREATE_UNICODE_ENVIRONMENT to CreateProcessAsUser); hToken may be 0 for
  the system variables only. Free it with DestroyEnvironmentBlock. }
{$EXTERNALSYM CreateEnvironmentBlock}
function CreateEnvironmentBlock(var lpEnvironment: Pointer; hToken: THandle;
  bInherit: BOOL): BOOL; stdcall;
{$EXTERNALSYM DestroyEnvironmentBlock}
function DestroyEnvironmentBlock(lpEnvironment: Pointer): BOOL; stdcall;

{ dwSize: size of lpDest in characters. }
{$EXTERNALSYM ExpandEnvironmentStringsForUserA}
function ExpandEnvironmentStringsForUserA(hToken: THandle; lpSrc: LPCSTR; lpDest: LPSTR;
  dwSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM ExpandEnvironmentStringsForUserW}
function ExpandEnvironmentStringsForUserW(hToken: THandle; lpSrc: LPCWSTR; lpDest: LPWSTR;
  dwSize: DWORD): BOOL; stdcall;
{$EXTERNALSYM ExpandEnvironmentStringsForUser}
function ExpandEnvironmentStringsForUser(hToken: THandle; lpSrc: LPCSTR; lpDest: LPSTR;
  dwSize: DWORD): BOOL; stdcall;

{ Group policy }
{$EXTERNALSYM RefreshPolicy}
function RefreshPolicy(bMachine: BOOL): BOOL; stdcall;
{ dwOptions: RP_FORCE, RP_SYNC }
{$EXTERNALSYM RefreshPolicyEx}
function RefreshPolicyEx(bMachine: BOOL; dwOptions: DWORD): BOOL; stdcall;
{ Returns 0 on failure; release with LeaveCriticalPolicySection. }
{$EXTERNALSYM EnterCriticalPolicySection}
function EnterCriticalPolicySection(bMachine: BOOL): THandle; stdcall;
{$EXTERNALSYM LeaveCriticalPolicySection}
function LeaveCriticalPolicySection(hSection: THandle): BOOL; stdcall;
{ hEvent is signaled when policy changes. }
{$EXTERNALSYM RegisterGPNotification}
function RegisterGPNotification(hEvent: THandle; bMachine: BOOL): BOOL; stdcall;
{$EXTERNALSYM UnregisterGPNotification}
function UnregisterGPNotification(hEvent: THandle): BOOL; stdcall;

{ ====== Functions bound at run time (Windows Vista and later) ============= }

{ Windows Vista. cchProfilePath: size of pszProfilePath in characters.
  Fallback: E_NOTIMPL. }
{$EXTERNALSYM CreateProfile}
function CreateProfile(pszUserSid, pszUserName: LPCWSTR; pszProfilePath: LPWSTR;
  cchProfilePath: DWORD): HRESULT; stdcall;

{ Windows 8. ppSidAppContainerSid receives a SID to free with FreeSid.
  Fallback: E_NOTIMPL, ppSidAppContainerSid = nil. }
{$EXTERNALSYM CreateAppContainerProfile}
function CreateAppContainerProfile(pszAppContainerName, pszDisplayName,
  pszDescription: LPCWSTR; pCapabilities: PSIDAndAttributes; dwCapabilityCount: DWORD;
  var ppSidAppContainerSid: PSID): HRESULT; stdcall;
{ Windows 8. Fallback: E_NOTIMPL. }
{$EXTERNALSYM DeleteAppContainerProfile}
function DeleteAppContainerProfile(pszAppContainerName: LPCWSTR): HRESULT; stdcall;
{ Windows 8; called from an AppContainer process. Close the key with
  RegCloseKey. Fallback: E_NOTIMPL, phAppContainerKey = 0. }
{$EXTERNALSYM GetAppContainerRegistryLocation}
function GetAppContainerRegistryLocation(desiredAccess: REGSAM;
  var phAppContainerKey: HKEY): HRESULT; stdcall;
{ Windows 8. ppszPath receives a string to free with CoTaskMemFree.
  Fallback: E_NOTIMPL, ppszPath = nil. }
{$EXTERNALSYM GetAppContainerFolderPath}
function GetAppContainerFolderPath(pszAppContainerSid: LPCWSTR;
  var ppszPath: LPWSTR): HRESULT; stdcall;
{ Windows 8. ppsidAppContainerSid receives a SID to free with FreeSid.
  Fallback: E_NOTIMPL, ppsidAppContainerSid = nil. }
{$EXTERNALSYM DeriveAppContainerSidFromAppContainerName}
function DeriveAppContainerSidFromAppContainerName(pszAppContainerName: LPCWSTR;
  var ppsidAppContainerSid: PSID): HRESULT; stdcall;
{ Windows 8.1. ppsidRestrictedAppContainerSid receives a SID to free with
  FreeSid. Fallback: E_NOTIMPL, ppsidRestrictedAppContainerSid = nil. }
{$EXTERNALSYM DeriveRestrictedAppContainerSidFromAppContainerSidAndRestrictedName}
function DeriveRestrictedAppContainerSidFromAppContainerSidAndRestrictedName(
  psidAppContainerSid: PSID; pszRestrictedAppContainerName: LPCWSTR;
  var ppsidRestrictedAppContainerSid: PSID): HRESULT; stdcall;

implementation

const
  userenvlib = 'userenv.dll';

{ ---- static bindings ---- }

function LoadUserProfileA; external userenvlib name 'LoadUserProfileA';
function LoadUserProfileW; external userenvlib name 'LoadUserProfileW';
function LoadUserProfile; external userenvlib name 'LoadUserProfileA';
function UnloadUserProfile; external userenvlib name 'UnloadUserProfile';
function GetProfilesDirectoryA; external userenvlib name 'GetProfilesDirectoryA';
function GetProfilesDirectoryW; external userenvlib name 'GetProfilesDirectoryW';
function GetProfilesDirectory; external userenvlib name 'GetProfilesDirectoryA';
function GetProfileType; external userenvlib name 'GetProfileType';
function DeleteProfileA; external userenvlib name 'DeleteProfileA';
function DeleteProfileW; external userenvlib name 'DeleteProfileW';
function DeleteProfile; external userenvlib name 'DeleteProfileA';
function GetDefaultUserProfileDirectoryA; external userenvlib name 'GetDefaultUserProfileDirectoryA';
function GetDefaultUserProfileDirectoryW; external userenvlib name 'GetDefaultUserProfileDirectoryW';
function GetDefaultUserProfileDirectory; external userenvlib name 'GetDefaultUserProfileDirectoryA';
function GetAllUsersProfileDirectoryA; external userenvlib name 'GetAllUsersProfileDirectoryA';
function GetAllUsersProfileDirectoryW; external userenvlib name 'GetAllUsersProfileDirectoryW';
function GetAllUsersProfileDirectory; external userenvlib name 'GetAllUsersProfileDirectoryA';
function GetUserProfileDirectoryA; external userenvlib name 'GetUserProfileDirectoryA';
function GetUserProfileDirectoryW; external userenvlib name 'GetUserProfileDirectoryW';
function GetUserProfileDirectory; external userenvlib name 'GetUserProfileDirectoryA';
function CreateEnvironmentBlock; external userenvlib name 'CreateEnvironmentBlock';
function DestroyEnvironmentBlock; external userenvlib name 'DestroyEnvironmentBlock';
function ExpandEnvironmentStringsForUserA; external userenvlib name 'ExpandEnvironmentStringsForUserA';
function ExpandEnvironmentStringsForUserW; external userenvlib name 'ExpandEnvironmentStringsForUserW';
function ExpandEnvironmentStringsForUser; external userenvlib name 'ExpandEnvironmentStringsForUserA';
function RefreshPolicy; external userenvlib name 'RefreshPolicy';
function RefreshPolicyEx; external userenvlib name 'RefreshPolicyEx';
function EnterCriticalPolicySection; external userenvlib name 'EnterCriticalPolicySection';
function LeaveCriticalPolicySection; external userenvlib name 'LeaveCriticalPolicySection';
function RegisterGPNotification; external userenvlib name 'RegisterGPNotification';
function UnregisterGPNotification; external userenvlib name 'UnregisterGPNotification';

{ ---- run-time binding ---- }

var
  UserEnvModule: HMODULE;
  UserEnvLoaded: Boolean;
  CreateProfileProc: Pointer;
  CreateAppContainerProfileProc: Pointer;
  DeleteAppContainerProfileProc: Pointer;
  GetAppContainerRegistryLocationProc: Pointer;
  GetAppContainerFolderPathProc: Pointer;
  DeriveAppContainerSidFromAppContainerNameProc: Pointer;
  DeriveRestrictedAppContainerSidProc: Pointer;

type
  TCreateProfileFn = function(pszUserSid, pszUserName: LPCWSTR; pszProfilePath: LPWSTR;
    cchProfilePath: DWORD): HRESULT; stdcall;
  TCreateAppContainerProfileFn = function(pszAppContainerName, pszDisplayName,
    pszDescription: LPCWSTR; pCapabilities: PSIDAndAttributes; dwCapabilityCount: DWORD;
    ppSidAppContainerSid: Pointer): HRESULT; stdcall;
  TUserEnvStrFn = function(Str: LPCWSTR): HRESULT; stdcall;
  TGetAppContainerRegistryLocationFn = function(desiredAccess: REGSAM;
    phAppContainerKey: Pointer): HRESULT; stdcall;
  TUserEnvStrOutFn = function(Str: LPCWSTR; Output: Pointer): HRESULT; stdcall;
  TDeriveRestrictedFn = function(psidAppContainerSid: PSID;
    pszRestrictedAppContainerName: LPCWSTR; Output: Pointer): HRESULT; stdcall;

{ userenv.dll is loaded once, from the system directory only (it is not a
  known DLL, so this avoids search-order planting), and never released. A
  missing DLL is remembered; a function pointer is cached once found. }
function GetUserEnvProc(var Proc: Pointer; Name: PChar): Boolean;
var
  Path: array[0..MAX_PATH + 16] of Char;
  Len: UINT;
begin
  if Proc = nil then
  begin
    if not UserEnvLoaded then
    begin
      Len := GetSystemDirectory(Path, MAX_PATH);
      if (Len > 0) and (Len < MAX_PATH) then
      begin
        lstrcat(Path, '\' + userenvlib);
        UserEnvModule := LoadLibrary(Path);
      end;
      UserEnvLoaded := True;
    end;
    if UserEnvModule <> 0 then
      Proc := GetProcAddress(UserEnvModule, Name);
  end;
  Result := Proc <> nil;
end;

function CreateProfile(pszUserSid, pszUserName: LPCWSTR; pszProfilePath: LPWSTR;
  cchProfilePath: DWORD): HRESULT; stdcall;
begin
  if GetUserEnvProc(CreateProfileProc, 'CreateProfile') then
    Result := TCreateProfileFn(CreateProfileProc)(pszUserSid, pszUserName, pszProfilePath,
      cchProfilePath)
  else
    Result := E_NOTIMPL;
end;

function CreateAppContainerProfile(pszAppContainerName, pszDisplayName,
  pszDescription: LPCWSTR; pCapabilities: PSIDAndAttributes; dwCapabilityCount: DWORD;
  var ppSidAppContainerSid: PSID): HRESULT; stdcall;
begin
  if GetUserEnvProc(CreateAppContainerProfileProc, 'CreateAppContainerProfile') then
    Result := TCreateAppContainerProfileFn(CreateAppContainerProfileProc)(pszAppContainerName,
      pszDisplayName, pszDescription, pCapabilities, dwCapabilityCount, @ppSidAppContainerSid)
  else
  begin
    ppSidAppContainerSid := nil;
    Result := E_NOTIMPL;
  end;
end;

function DeleteAppContainerProfile(pszAppContainerName: LPCWSTR): HRESULT; stdcall;
begin
  if GetUserEnvProc(DeleteAppContainerProfileProc, 'DeleteAppContainerProfile') then
    Result := TUserEnvStrFn(DeleteAppContainerProfileProc)(pszAppContainerName)
  else
    Result := E_NOTIMPL;
end;

function GetAppContainerRegistryLocation(desiredAccess: REGSAM;
  var phAppContainerKey: HKEY): HRESULT; stdcall;
begin
  if GetUserEnvProc(GetAppContainerRegistryLocationProc, 'GetAppContainerRegistryLocation') then
    Result := TGetAppContainerRegistryLocationFn(GetAppContainerRegistryLocationProc)(
      desiredAccess, @phAppContainerKey)
  else
  begin
    phAppContainerKey := 0;
    Result := E_NOTIMPL;
  end;
end;

function GetAppContainerFolderPath(pszAppContainerSid: LPCWSTR;
  var ppszPath: LPWSTR): HRESULT; stdcall;
begin
  if GetUserEnvProc(GetAppContainerFolderPathProc, 'GetAppContainerFolderPath') then
    Result := TUserEnvStrOutFn(GetAppContainerFolderPathProc)(pszAppContainerSid, @ppszPath)
  else
  begin
    ppszPath := nil;
    Result := E_NOTIMPL;
  end;
end;

function DeriveAppContainerSidFromAppContainerName(pszAppContainerName: LPCWSTR;
  var ppsidAppContainerSid: PSID): HRESULT; stdcall;
begin
  if GetUserEnvProc(DeriveAppContainerSidFromAppContainerNameProc,
    'DeriveAppContainerSidFromAppContainerName') then
    Result := TUserEnvStrOutFn(DeriveAppContainerSidFromAppContainerNameProc)(
      pszAppContainerName, @ppsidAppContainerSid)
  else
  begin
    ppsidAppContainerSid := nil;
    Result := E_NOTIMPL;
  end;
end;

function DeriveRestrictedAppContainerSidFromAppContainerSidAndRestrictedName(
  psidAppContainerSid: PSID; pszRestrictedAppContainerName: LPCWSTR;
  var ppsidRestrictedAppContainerSid: PSID): HRESULT; stdcall;
begin
  if GetUserEnvProc(DeriveRestrictedAppContainerSidProc,
    'DeriveRestrictedAppContainerSidFromAppContainerSidAndRestrictedName') then
    Result := TDeriveRestrictedFn(DeriveRestrictedAppContainerSidProc)(psidAppContainerSid,
      pszRestrictedAppContainerName, @ppsidRestrictedAppContainerSid)
  else
  begin
    ppsidRestrictedAppContainerSid := nil;
    Result := E_NOTIMPL;
  end;
end;

end.
