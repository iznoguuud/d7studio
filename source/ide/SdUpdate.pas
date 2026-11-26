{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdUpdate;

{ D7 Studio - the check for updates: the latest published release of D7 Studio's public repository
  on GitHub (its API's releases/latest: drafts and pre-releases are not offered), compared with the
  running program's file version; the download of the release's setup and of its .sha256 file into
  a folder of %TEMP%, the setup checked against that SHA-256; Setup started once D7 Studio has
  ended (D7Studio.dpr), as it replaces D7 Studio's files and updates an installed D7 Studio in
  place.

  The checks and the download run in worker threads (TSdUpdateCheck, TSdUpdateDownload); the main
  window takes their results in the main thread. }

interface

uses
  Windows, SysUtils, Classes, SdHttp;

const
  UpdateRepository = 'iznoguuud/d7studio';
  UpdateReleasesUrl = 'https://api.github.com/repos/' + UpdateRepository + '/releases?per_page=100';
  UpdateSection = 'Updates';          // D7Studio.ini: LastCheck (the option: [Environment] CheckForUpdates)

type
  TSdRelease = record
    Version: string;      // the tag without its 'v': '1.0.2.0'
    Title: string;        // the release's name, 'D7 Studio 1.0.2.0'
    PageUrl: string;      // the release's page on GitHub
    Notes: string;        // its notes (Markdown), CR LF lines, in the IDE's encoding
    SetupName: string;    // D7Studio-<version>-setup.exe
    SetupUrl: string;
    SetupSize: Integer;
    HashUrl: string;      // the setup's .sha256 file ('' when the release has none)
  end;

  { the latest release, in a worker thread; read its fields in OnTerminate }
  TSdUpdateCheck = class(TThread)
  protected
    procedure Execute; override;
  public
    Manual: Boolean;          // Help | Check for Updates: every result is reported
    HasRelease: Boolean;      // the repository has a published release: Release
    Release: TSdRelease;
    Error: string;            // why the check failed ('' when it did not)
    constructor Create(AManual: Boolean; DoneEvent: TNotifyEvent);
  end;

  { the setup of Release and its SHA-256 into UpdateFolder, the setup checked; Done / Total for a
    progress bar, read from the main thread while it runs }
  TSdUpdateDownload = class(TThread)
  private
    FHttp: TSdHttp;
    procedure Progress(ADone, ATotal: Integer);
  protected
    procedure Execute; override;
  public
    Release: TSdRelease;
    SetupFile: string;        // the checked setup, once it ended without Error
    Error: string;            // '' when it succeeded; 'Cancelled.' after Cancel
    Done, Total: Integer;
    Finished: Boolean;
    constructor Create(const ARelease: TSdRelease);
    destructor Destroy; override;
    { from the main thread: ends the download }
    procedure Cancel;
  end;

{ the running D7 Studio's version, '1.0.1.0' ('0.0.0.0' when it has none) }
function CurrentVersion: string;
{ < 0, 0, > 0 as version A is older than, the same as or newer than B (numbers between the dots) }
function CompareVersions(const A, B: string): Integer;
{ True when Release is newer than the running D7 Studio }
function IsNewerRelease(const Release: TSdRelease): Boolean;
{ the release in the JSON of GitHub's API; False when it is not one with a setup }
function ParseRelease(const Json: string; out R: TSdRelease): Boolean;
{ the releases in the JSON of GitHub's API (an array): Latest is the newest published one with a setup
  (False: none), its Notes those of every published release newer than Since up to it, newest first,
  each under its title and without what follows its rule ('---': the release's files) }
function ParseReleases(const Json, Since: string; out Latest: TSdRelease): Boolean;
{ release notes in Markdown as plain text: the lines of a paragraph or a list item joined, headings
  and items without their marks, no emphasis or code marks, rules as blank lines }
function MarkdownToText(const Notes: string): string;
{ the SHA-256 of the file in lowercase hex; '' when it cannot be read }
function FileSha256(const FileName: string): string;
{ %TEMP%\D7Studio-update\, where the setup is downloaded }
function UpdateFolder: string;
{ the files a former download left there, and the folder (a setup that still runs stays) }
procedure RemoveUpdateFolder;
{ the automatic check: on in Environment Options, not the test instance's, and not done today }
function UpdateCheckDue: Boolean;
{ the automatic check succeeded today }
procedure UpdateCheckDone;
{ starts the setup (it asks for elevation itself); False when it could not be started }
function RunUpdateSetup(const FileName: string): Boolean;

implementation

uses
  ShellAPI, BCrypt, SdSettings, SdEnvOptions, SdFileNames, SdEncoding, SdUI, SdAboutDlg;

function CurrentVersion: string;
begin
  Result := ProgramVersion;
  if Result = '' then Result := '0.0.0.0';
end;

function CompareVersions(const A, B: string): Integer;
var
  PA, PB, NA, NB: Integer;

  { the number from P on to the next dot (P moved past it); 0 at the end }
  function NextPart(const S: string; var P: Integer): Integer;
  var
    Start: Integer;
  begin
    Start := P;
    while (P <= Length(S)) and (S[P] <> '.') do Inc(P);
    Result := StrToIntDef(Trim(Copy(S, Start, P - Start)), 0);
    Inc(P);
  end;

begin
  PA := 1;
  PB := 1;
  Result := 0;
  while (Result = 0) and ((PA <= Length(A)) or (PB <= Length(B))) do
  begin
    NA := NextPart(A, PA);
    NB := NextPart(B, PB);
    if NA < NB then Result := -1
    else if NA > NB then Result := 1;
  end;
end;

function IsNewerRelease(const Release: TSdRelease): Boolean;
begin
  Result := CompareVersions(Release.Version, CurrentVersion) > 0;
end;

{ ---------------------------------------------------------------- JSON }

type
  { just enough of a JSON reader for a release: the values of the keys it needs, the others
    skipped }
  TJsonReader = class
  private
    FText: string;
    FPos: Integer;
    procedure Fail;
    procedure SkipSpace;
    function Peek: Char;
    procedure Expect(C: Char);
    { a string's value, UTF-8 (its \u escapes encoded so) }
    function ReadString: string;
    { a number, true, false or null as its text }
    function ReadLiteral: string;
    procedure SkipValue;
  public
    constructor Create(const Text: string);
    { the members of an object, one by one: False after the last; the reader stands at the value }
    function NextMember(var First: Boolean; out Key: string): Boolean;
    function NextElement(var First: Boolean): Boolean;
    { a string or a literal as text; null, an object or an array (skipped) give '' }
    function ReadScalar: string;
  end;

  EJsonError = class(Exception);

constructor TJsonReader.Create(const Text: string);
begin
  inherited Create;
  FText := Text;
  FPos := 1;
end;

procedure TJsonReader.Fail;
begin
  raise EJsonError.CreateFmt('GitHub''s answer is not valid JSON (at %d).', [FPos]);
end;

procedure TJsonReader.SkipSpace;
begin
  while (FPos <= Length(FText)) and (FText[FPos] in [' ', #9, #10, #13]) do Inc(FPos);
end;

function TJsonReader.Peek: Char;
begin
  SkipSpace;
  if FPos > Length(FText) then Fail;
  Result := FText[FPos];
end;

procedure TJsonReader.Expect(C: Char);
begin
  if Peek <> C then Fail;
  Inc(FPos);
end;

function TJsonReader.ReadString: string;
var
  Start, Code, Low: Integer;

  function Hex4: Integer;
  begin
    if FPos + 3 > Length(FText) then Fail;
    Result := StrToIntDef('$' + Copy(FText, FPos, 4), -1);
    if Result < 0 then Fail;
    Inc(FPos, 4);
  end;

  procedure AddCode(C: Integer);
  begin
    if C < $80 then Result := Result + Chr(C)
    else if C < $800 then Result := Result + Chr($C0 or (C shr 6)) + Chr($80 or (C and $3F))
    else if C < $10000 then
      Result := Result + Chr($E0 or (C shr 12)) + Chr($80 or ((C shr 6) and $3F)) + Chr($80 or (C and $3F))
    else
      Result := Result + Chr($F0 or (C shr 18)) + Chr($80 or ((C shr 12) and $3F)) +
        Chr($80 or ((C shr 6) and $3F)) + Chr($80 or (C and $3F));
  end;

begin
  Expect('"');
  Result := '';
  repeat
    Start := FPos;
    while (FPos <= Length(FText)) and not (FText[FPos] in ['"', '\']) do Inc(FPos);
    if FPos > Length(FText) then Fail;
    Result := Result + Copy(FText, Start, FPos - Start);
    if FText[FPos] = '"' then
    begin
      Inc(FPos);
      Exit;
    end;
    Inc(FPos);    // the backslash
    if FPos > Length(FText) then Fail;
    Inc(FPos);
    case FText[FPos - 1] of
      '"', '\', '/': Result := Result + FText[FPos - 1];
      'b': Result := Result + #8;
      'f': Result := Result + #12;
      'n': Result := Result + #10;
      'r': Result := Result + #13;
      't': Result := Result + #9;
      'u':
        begin
          Code := Hex4;
          { a surrogate pair: one code point }
          if (Code >= $D800) and (Code < $DC00) and (Copy(FText, FPos, 2) = '\u') then
          begin
            Inc(FPos, 2);
            Low := Hex4;
            if (Low >= $DC00) and (Low < $E000) then
              Code := $10000 + ((Code - $D800) shl 10) + (Low - $DC00)
            else
            begin
              AddCode(Code);
              Code := Low;
            end;
          end;
          AddCode(Code);
        end;
    else
      Fail;
    end;
  until False;
end;

function TJsonReader.ReadLiteral: string;
var
  Start: Integer;
begin
  SkipSpace;
  Start := FPos;
  while (FPos <= Length(FText)) and not (FText[FPos] in [',', '}', ']', ' ', #9, #10, #13]) do Inc(FPos);
  if FPos = Start then Fail;
  Result := Copy(FText, Start, FPos - Start);
end;

procedure TJsonReader.SkipValue;
var
  First: Boolean;
  Key: string;
begin
  case Peek of
    '"': ReadString;
    '{':
      begin
        First := True;
        while NextMember(First, Key) do SkipValue;
      end;
    '[':
      begin
        First := True;
        while NextElement(First) do SkipValue;
      end;
  else
    ReadLiteral;
  end;
end;

function TJsonReader.NextMember(var First: Boolean; out Key: string): Boolean;
begin
  if First then
  begin
    Expect('{');
    First := False;
    Result := Peek <> '}';
  end
  else
  begin
    Result := Peek = ',';
    if not Result and (Peek <> '}') then Fail;
  end;
  if not Result then
  begin
    Inc(FPos);    // the '}'
    Exit;
  end;
  if Peek = ',' then Inc(FPos);
  Key := ReadString;
  Expect(':');
end;

function TJsonReader.NextElement(var First: Boolean): Boolean;
begin
  if First then
  begin
    Expect('[');
    First := False;
    Result := Peek <> ']';
  end
  else
  begin
    Result := Peek = ',';
    if not Result and (Peek <> ']') then Fail;
    if Result then Inc(FPos);
  end;
  if not Result then Inc(FPos);    // the ']'
end;

function TJsonReader.ReadScalar: string;
begin
  case Peek of
    '"': Result := ReadString;
    '{', '[':
      begin
        SkipValue;
        Result := '';
      end;
  else
    Result := ReadLiteral;
    if Result = 'null' then Result := '';
  end;
end;

{ UTF-8 text in the IDE's encoding, its lines CR LF }
function Utf8ToIdeText(const S: string): string;
begin
  Result := AdjustLineBreaks(WideToIde(UTF8Decode(S)));
end;

{ the release object J stands at: True for a published one (no draft, no pre-release) with a tag; its
  SetupName '' when it has no setup }
function ReadRelease(J: TJsonReader; out R: TSdRelease): Boolean;
var
  First, AFirst, EFirst: Boolean;
  Key, AKey, Tag, Name, Url, Draft, Pre: string;
  Size: Integer;
  Assets: TStringList;
  I: Integer;
begin
  Result := False;
  R.Version := '';
  R.Title := '';
  R.PageUrl := '';
  R.Notes := '';
  R.SetupName := '';
  R.SetupUrl := '';
  R.SetupSize := 0;
  R.HashUrl := '';
  Tag := '';
  Draft := '';
  Pre := '';
  { the assets' names, each with its URL (Values) and its size (Objects) }
  Assets := TStringList.Create;
  try
    First := True;
    while J.NextMember(First, Key) do
      if Key = 'tag_name' then Tag := J.ReadScalar
      else if Key = 'name' then R.Title := Utf8ToIdeText(J.ReadScalar)
      else if Key = 'html_url' then R.PageUrl := J.ReadScalar
      else if Key = 'body' then R.Notes := Utf8ToIdeText(J.ReadScalar)
      else if Key = 'draft' then Draft := J.ReadScalar
      else if Key = 'prerelease' then Pre := J.ReadScalar
      else if Key = 'assets' then
      begin
        if J.Peek <> '[' then
        begin
          J.SkipValue;
          Continue;
        end;
        AFirst := True;
        while J.NextElement(AFirst) do
        begin
          if J.Peek <> '{' then
          begin
            J.SkipValue;
            Continue;
          end;
          Name := '';
          Url := '';
          Size := 0;
          EFirst := True;
          while J.NextMember(EFirst, AKey) do
            if AKey = 'name' then Name := J.ReadScalar
            else if AKey = 'browser_download_url' then Url := J.ReadScalar
            else if AKey = 'size' then Size := StrToIntDef(J.ReadScalar, 0)
            else J.SkipValue;
          if (Name <> '') and (Url <> '') then Assets.AddObject(Name + '=' + Url, TObject(Size));
        end;
      end
      else J.SkipValue;
    if (Draft = 'true') or (Pre = 'true') or (Tag = '') then Exit;
    if Tag[1] in ['v', 'V'] then R.Version := Copy(Tag, 2, MaxInt) else R.Version := Tag;
    if R.Title = '' then R.Title := 'D7 Studio ' + R.Version;
    for I := 0 to Assets.Count - 1 do
      if SameText(Copy(Assets.Names[I], 1, 9), 'D7Studio-') and
        SameText(Copy(Assets.Names[I], Length(Assets.Names[I]) - 9, 10), '-setup.exe') then
      begin
        R.SetupName := Assets.Names[I];
        R.SetupUrl := Assets.Values[R.SetupName];
        R.SetupSize := Integer(Assets.Objects[I]);
        Break;
      end;
    if R.SetupName <> '' then
    begin
      I := Assets.IndexOfName(R.SetupName + '.sha256');
      if I >= 0 then R.HashUrl := Assets.Values[Assets.Names[I]];
    end;
    Result := True;
  finally
    Assets.Free;
  end;
end;

function ParseRelease(const Json: string; out R: TSdRelease): Boolean;
var
  J: TJsonReader;
begin
  J := TJsonReader.Create(Json);
  try
    Result := ReadRelease(J, R) and (R.SetupName <> '');
  finally
    J.Free;
  end;
end;

{ a release's notes up to its rule: what follows describes the release's files }
function NotesBeforeRule(const Notes: string): string;
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    L.Text := Notes;
    for I := 0 to L.Count - 1 do
      if Trim(L[I]) = '---' then
      begin
        while L.Count > I do L.Delete(L.Count - 1);
        Break;
      end;
    Result := TrimRight(L.Text);
  finally
    L.Free;
  end;
end;

function ParseReleases(const Json, Since: string; out Latest: TSdRelease): Boolean;
var
  J: TJsonReader;
  First: Boolean;
  R: TSdRelease;
  Newer: array of TSdRelease;     // the releases newer than Since, newest first
  I, K: Integer;
  Notes: string;
begin
  Result := False;
  J := TJsonReader.Create(Json);
  try
    First := True;
    while J.NextElement(First) do
      if J.Peek <> '{' then J.SkipValue
      else if ReadRelease(J, R) then
      begin
        if (R.SetupName <> '') and (not Result or (CompareVersions(R.Version, Latest.Version) > 0)) then
        begin
          Latest := R;
          Result := True;
        end;
        if CompareVersions(R.Version, Since) > 0 then
        begin
          K := Length(Newer);
          SetLength(Newer, K + 1);
          while (K > 0) and (CompareVersions(Newer[K - 1].Version, R.Version) < 0) do
          begin
            Newer[K] := Newer[K - 1];
            Dec(K);
          end;
          Newer[K] := R;
        end;
      end;
  finally
    J.Free;
  end;
  if not Result then Exit;
  Notes := '';
  for I := 0 to High(Newer) do
    if CompareVersions(Newer[I].Version, Latest.Version) <= 0 then
      Notes := Notes + '# ' + Newer[I].Title + #13#10#13#10 + NotesBeforeRule(Newer[I].Notes) + #13#10#13#10;
  if Notes <> '' then Latest.Notes := Notes;
end;

{ ---------------------------------------------------------------- notes }

function MarkdownToText(const Notes: string): string;
var
  L, Out: TStringList;
  Para, T: string;
  I: Integer;

  procedure Flush;
  begin
    if Para <> '' then Out.Add(Para);
    Para := '';
  end;

  procedure Blank;
  begin
    Flush;
    if (Out.Count > 0) and (Out[Out.Count - 1] <> '') then Out.Add('');
  end;

begin
  L := TStringList.Create;
  Out := TStringList.Create;
  try
    L.Text := Notes;
    Para := '';
    for I := 0 to L.Count - 1 do
    begin
      T := Trim(L[I]);
      if (T = '') or (T = '---') or (T = '***') or (T = '___') then
        Blank
      else if T[1] = '#' then
      begin
        Flush;
        while (T <> '') and (T[1] = '#') do Delete(T, 1, 1);
        Out.Add(Trim(T));
      end
      else if (Length(T) > 1) and (T[1] in ['-', '*', '+']) and (T[2] = ' ') then
      begin
        Flush;
        Para := '- ' + Trim(Copy(T, 3, MaxInt));
      end
      else if Para <> '' then
        Para := Para + ' ' + T
      else
        Para := T;
    end;
    Flush;
    while (Out.Count > 0) and (Out[Out.Count - 1] = '') do Out.Delete(Out.Count - 1);
    Result := Out.Text;
  finally
    Out.Free;
    L.Free;
  end;
  Result := StringReplace(Result, '**', '', [rfReplaceAll]);
  Result := StringReplace(Result, '`', '', [rfReplaceAll]);
end;

{ ---------------------------------------------------------------- files }

function FileSha256(const FileName: string): string;
const
  Digits: array[0..15] of Char = '0123456789abcdef';
var
  Alg: BCRYPT_ALG_HANDLE;
  Hash: BCRYPT_HASH_HANDLE;
  F: TFileStream;
  Buf: array[0..65535] of Byte;
  Digest: array[0..31] of Byte;
  N, I: Integer;
  OK: Boolean;
begin
  Result := '';
  if not BCRYPT_SUCCESS(BCryptOpenAlgorithmProvider(Alg, BCRYPT_SHA256_ALGORITHM, nil, 0)) then Exit;
  try
    if not BCRYPT_SUCCESS(BCryptCreateHash(Alg, Hash, nil, 0, nil, 0, 0)) then Exit;
    try
      try
        F := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
      except
        Exit;
      end;
      try
        OK := True;
        repeat
          N := F.Read(Buf, SizeOf(Buf));
          if N > 0 then OK := BCRYPT_SUCCESS(BCryptHashData(Hash, @Buf, N, 0));
        until (N <= 0) or not OK;
      finally
        F.Free;
      end;
      if not OK or not BCRYPT_SUCCESS(BCryptFinishHash(Hash, @Digest, SizeOf(Digest), 0)) then Exit;
      SetLength(Result, 64);
      for I := 0 to 31 do
      begin
        Result[I * 2 + 1] := Digits[Digest[I] shr 4];
        Result[I * 2 + 2] := Digits[Digest[I] and 15];
      end;
    finally
      BCryptDestroyHash(Hash);
    end;
  finally
    BCryptCloseAlgorithmProvider(Alg, 0);
  end;
end;

function UpdateFolder: string;
begin
  Result := TempFolder + 'D7Studio-update\';
end;

procedure RemoveUpdateFolder;
begin
  RemoveTree(UpdateFolder);
end;

{ ShellExecuteEx sets the last error when it fails (ERROR_CANCELLED: the elevation was declined) }
function RunUpdateSetup(const FileName: string): Boolean;
var
  Info: TShellExecuteInfo;
  Dir: string;
begin
  Dir := ExtractFilePath(FileName);
  FillChar(Info, SizeOf(Info), 0);
  Info.cbSize := SizeOf(Info);
  Info.fMask := SEE_MASK_FLAG_NO_UI;
  Info.lpVerb := 'open';
  Info.lpFile := PChar(FileName);
  Info.lpDirectory := PChar(Dir);
  Info.nShow := SW_SHOWNORMAL;
  Result := ShellExecuteEx(@Info);
end;

{ ---------------------------------------------------------------- settings }

function Today: string;
begin
  Result := FormatDateTime('yyyy-mm-dd', Date);
end;

function UpdateCheckDue: Boolean;
begin
  Result := EnvOptions.CheckForUpdates and not UITestMode and
    (Settings.ReadString(UpdateSection, 'LastCheck', '') <> Today);
end;

procedure UpdateCheckDone;
begin
  Settings.WriteString(UpdateSection, 'LastCheck', Today);
end;

{ ---------------------------------------------------------------- threads }

function NewHttp: TSdHttp;
begin
  Result := TSdHttp.Create('D7Studio/' + CurrentVersion);
end;

constructor TSdUpdateCheck.Create(AManual: Boolean; DoneEvent: TNotifyEvent);
begin
  inherited Create(True);
  Manual := AManual;
  FreeOnTerminate := True;
  OnTerminate := DoneEvent;
  Resume;
end;

procedure TSdUpdateCheck.Execute;
var
  Http: TSdHttp;
  Headers: TStringList;
begin
  Http := NewHttp;
  Headers := TStringList.Create;
  try
    Headers.Add('Accept: application/vnd.github+json');
    Headers.Add('X-GitHub-Api-Version: 2022-11-28');
    try
      HasRelease := ParseReleases(Http.Get(UpdateReleasesUrl, Headers), CurrentVersion, Release);
    except
      on E: ESdHttpError do
        if E.Status = 404 then HasRelease := False     // no such repository
        else if E.Status = 403 then
          Error := 'GitHub refused the request; its limit for requests without an account may have been ' +
            'reached. Try again later.'
        else Error := E.Message;
      on E: Exception do Error := E.Message;
    end;
  finally
    Headers.Free;
    Http.Free;
  end;
end;

constructor TSdUpdateDownload.Create(const ARelease: TSdRelease);
begin
  inherited Create(True);
  Release := ARelease;
  FHttp := NewHttp;
end;

destructor TSdUpdateDownload.Destroy;
begin
  FHttp.Free;
  inherited Destroy;
end;

procedure TSdUpdateDownload.Cancel;
begin
  FHttp.Cancel;
end;

procedure TSdUpdateDownload.Progress(ADone, ATotal: Integer);
begin
  if ATotal <= 0 then ATotal := Release.SetupSize;
  Total := ATotal;
  Done := ADone;
end;

procedure TSdUpdateDownload.Execute;
var
  Dir, FileName, Expected: string;
  P: Integer;
begin
  try
    try
      if Release.HashUrl = '' then
        raise Exception.Create('The release has no SHA-256 file for its setup, so the download cannot be checked.');
      { "<hash>  <file name>" }
      Expected := Trim(FHttp.Get(Release.HashUrl));
      P := Pos(' ', Expected);
      if P > 0 then Expected := Copy(Expected, 1, P - 1);
      Expected := LowerCase(Expected);
      if Length(Expected) <> 64 then
        raise Exception.Create('The release''s SHA-256 file does not hold a SHA-256.');
      RemoveUpdateFolder;
      Dir := UpdateFolder;
      if not ForceDirectories(Dir) then
        raise Exception.CreateFmt('The folder %s could not be made.', [Dir]);
      FileName := Dir + ExtractFileName(StringReplace(Release.SetupName, '/', '\', [rfReplaceAll]));
      FHttp.Download(Release.SetupUrl, FileName, Progress);
      if FileSha256(FileName) <> Expected then
      begin
        DeleteFile(FileName);
        raise Exception.Create('The downloaded setup does not match the release''s SHA-256: it was deleted. ' +
          'Try again later.');
      end;
      SetupFile := FileName;
    except
      on E: Exception do Error := E.Message;
    end;
  finally
    Finished := True;
  end;
end;

end.
