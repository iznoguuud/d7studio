{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdAboutDlg;

{ D7 Studio - Help | About, laid out as Delphi 7's About box: a picture on the left - the Tholos of
  Delphi -; beside it the name and its line, the version, the copyright, the license and the source
  repository as a link, and at the picture's foot a line, Windows, Delphi's folder and the code
  pages; under both the licenses of D7 Studio and of the parts made by others in a read-only box; OK
  in the band of the buttons. }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls;

type
  TAboutDlg = class(TForm)
    lblTitle: TLabel;
    lblEdition: TLabel;
    lblVersion: TLabel;
    lblCopyright: TLabel;
    lblLicense: TLabel;
    lblRepo: TLabel;
    shpLine: TShape;
    lblWindows: TLabel;
    lblDelphiCaption: TLabel;
    lblDelphiDir: TLabel;
    lblCodePageCaption: TLabel;
    lblCodePage: TLabel;
    pnlPicture: TPanel;
    mmLicense: TMemo;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    procedure FormCreate(Sender: TObject);
    procedure lblRepoClick(Sender: TObject);
    procedure lblRepoMouseEnter(Sender: TObject);
    procedure lblRepoMouseLeave(Sender: TObject);
  public
    class procedure Execute(AOwner: TComponent);
  end;

var
  AboutDlg: TAboutDlg;

{ the file version of the program's version resource, "1.0.0.0"; '' when it has none }
function ProgramVersion: string;

implementation

uses
  WindowsEx, SdUI, SdDelphiDir, SdEncoding;

{$R *.dfm}

const
  RepositoryURL = 'https://github.com/iznoguuud/d7studio';
  PhotoName = 'ABOUT';                    // the picture, RCDATA ABOUT (about.jpg)
  { the rows of the column beside the picture, from the name down; from FootRow on (the line) they
    end with the picture }
  ColumnRows = 10;
  FootRow = 6;

{ the file version of the program's version resource, "1.0.0.0"; '' when it has none }
function ProgramVersion: string;
var
  Res: HRSRC;
  P: PChar;
  Fixed: PVSFixedFileInfo;
begin
  Result := '';
  Res := FindResource(HInstance, MakeIntResource(1), RT_VERSION);
  if Res = 0 then Exit;
  { VS_VERSIONINFO: length, value length and type (three words), the key 'VS_VERSION_INFO' with its
    #0 (32 bytes), then the VS_FIXEDFILEINFO, DWORD-aligned at 40 }
  if SizeofResource(HInstance, Res) < 40 + SizeOf(TVSFixedFileInfo) then Exit;
  P := LockResource(LoadResource(HInstance, Res));
  if P = nil then Exit;
  Fixed := PVSFixedFileInfo(P + 40);
  if Fixed^.dwSignature <> $FEEF04BD then Exit;
  Result := Format('%d.%d.%d.%d', [HiWord(Fixed^.dwFileVersionMS), LoWord(Fixed^.dwFileVersionMS),
    HiWord(Fixed^.dwFileVersionLS), LoWord(Fixed^.dwFileVersionLS)]);
end;

{ Windows' version key, read in the 64-bit view on 64-bit Windows: its DisplayVersion ("25H2") and
  UBR (the update build revision); '' / -1 when a value is missing (Windows before 10) }
procedure ReadWindowsRelease(out DisplayVersion: string; out Revision: Integer);
var
  Key: HKEY;
  Kind, Size, Value: DWORD;
  Buf: array[0..63] of Char;
begin
  DisplayVersion := '';
  Revision := -1;
  if RegOpenKeyEx(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\Windows NT\CurrentVersion', 0,
    KEY_READ or KEY_WOW64_64KEY, Key) <> ERROR_SUCCESS then Exit;
  try
    Size := SizeOf(Buf) - 1;
    if (RegQueryValueEx(Key, 'DisplayVersion', nil, @Kind, @Buf, @Size) = ERROR_SUCCESS) and
      (Kind = REG_SZ) then
    begin
      Buf[Size] := #0;
      DisplayVersion := Trim(Buf);
    end;
    Size := SizeOf(Value);
    if (RegQueryValueEx(Key, 'UBR', nil, @Kind, @Value, @Size) = ERROR_SUCCESS) and
      (Kind = REG_DWORD) then Revision := Value;
  finally
    RegCloseKey(Key);
  end;
end;

{ "Windows 11 25H2 (build 26200.7171), x64": the real version (no manifest's compatibility
  answer), Windows 11 being 10.0 from build 22000 on, and the machine Windows runs on }
function WindowsDescription: string;
var
  Major, Minor, Build: Cardinal;
  Release, Name: string;
  Revision: Integer;
  ProcessMachine, NativeMachine: Word;
begin
  if not GetRealWindowsVersion(Major, Minor, Build) then
  begin
    Result := 'Windows';
    Exit;
  end;
  if (Major = 10) and (Build >= 22000) then Name := 'Windows 11'
  else if Major = 10 then Name := 'Windows 10'
  else if (Major = 6) and (Minor = 3) then Name := 'Windows 8.1'
  else if (Major = 6) and (Minor = 2) then Name := 'Windows 8'
  else if (Major = 6) and (Minor = 1) then Name := 'Windows 7'
  else if (Major = 6) and (Minor = 0) then Name := 'Windows Vista'
  else Name := Format('Windows %d.%d', [Major, Minor]);
  ReadWindowsRelease(Release, Revision);
  if Release <> '' then Name := Name + ' ' + Release;
  if Revision >= 0 then
    Result := Format('%s (build %d.%d)', [Name, Build, Revision])
  else
    Result := Format('%s (build %d)', [Name, Build]);
  if IsWow64Process2(GetCurrentProcess, ProcessMachine, @NativeMachine) then
    case NativeMachine of
      IMAGE_FILE_MACHINE_AMD64: Result := Result + ', x64';
      IMAGE_FILE_MACHINE_ARM64: Result := Result + ', ARM64';
      IMAGE_FILE_MACHINE_I386: Result := Result + ', x86';
    end;
end;

{ the IDE's own code page and, when it differs, Windows' code page of programs - that of files
  that do not say otherwise, the compiler and the program being debugged }
function CodePageDescription: string;
begin
  Result := EncodingShortName(IdeEncoding);
  if IdeEncoding.CodePage <> SystemEncoding.CodePage then
    Result := Format('%s (system code page: %s)', [Result, EncodingShortName(SystemEncoding)]);
end;

{ The texts, then the layout: the picture at its own size whatever the UI font (scaled with the DPI
  only), the column beside it from the name down to the link with the design's spaces - the name
  and its line grow with their fonts, a missing version leaves no space -, the rows from the line
  down ending with the picture (or, where they would come closer to the link than the space under
  the line, that far under it); the dialog as wide as its widest text (the line, the box of the
  licenses and the band of the button, anchored to its sides, follow), the box under the picture
  and the column, the band under the box. The column's spaces are read before UIPrepareForm, which
  gives the labels with a font of their own the UI font - the name one line of it high, under the
  design's place of its line -, and are scaled from the design font's line height to the UI font's;
  the spaces under the picture and the box are read after it, which scaled them. }
procedure TAboutDlg.FormCreate(Sender: TObject);
var
  Column: array[0..ColumnRows - 1] of TControl;
  Gaps: array[0..ColumnRows - 1] of Integer;
  LineH, ValueGap, ColumnGap, PhotoW, PhotoH, Margin, BoxGap, BandGap, X, W, Y, FootH, I: Integer;
  Version: string;

  procedure Fit(C: TControl);
  begin
    if C.Visible and (C.Left + C.Width + Margin > W) then W := C.Left + C.Width + Margin;
  end;

  { the right edge of the wider caption of the values }
  function CaptionsRight: Integer;
  begin
    Result := lblDelphiCaption.Left + lblDelphiCaption.Width;
    if lblCodePageCaption.Left + lblCodePageCaption.Width > Result then
      Result := lblCodePageCaption.Left + lblCodePageCaption.Width;
  end;

begin
  Column[0] := lblTitle;     Column[1] := lblEdition;  Column[2] := lblVersion;
  Column[3] := lblCopyright; Column[4] := lblLicense;  Column[5] := lblRepo;
  Column[6] := shpLine;      Column[7] := lblWindows;  Column[8] := lblDelphiCaption;
  Column[9] := lblCodePageCaption;
  for I := 1 to ColumnRows - 1 do
    Gaps[I] := Column[I].Top - Column[I - 1].Top - Column[I - 1].Height;
  ValueGap := lblDelphiDir.Left - CaptionsRight;
  ColumnGap := lblTitle.Left - pnlPicture.Left - pnlPicture.Width;
  PhotoW := pnlPicture.Width;
  PhotoH := pnlPicture.Height;
  LineH := lblVersion.Height;
  UIPrepareForm(Self);
  for I := 1 to ColumnRows - 1 do Gaps[I] := MulDiv(Gaps[I], lblVersion.Height, LineH);
  Margin := pnlPicture.Left;
  BoxGap := mmLicense.Top - pnlPicture.Top - pnlPicture.Height;
  BandGap := pnlFooter.Top - mmLicense.Top - mmLicense.Height;
  pnlPicture.SetBounds(pnlPicture.Left, pnlPicture.Top, PhotoW, PhotoH);
  X := pnlPicture.Left + PhotoW + MulDiv(ColumnGap, lblVersion.Height, LineH);
  for I := 0 to ColumnRows - 1 do Column[I].Left := X;
  shpLine.Width := ClientWidth - Margin - X;
  { the values right of the wider caption, as far from it as designed }
  lblDelphiDir.Left := CaptionsRight + MulDiv(ValueGap, lblVersion.Height, LineH);
  lblCodePage.Left := lblDelphiDir.Left;
  { the name three times the UI font's size, in the light face of the start-up screen where the UI
    font has it, and its line a third larger than the UI font }
  lblTitle.Font.Height := 3 * Font.Height;
  if SameText(Font.Name, 'Segoe UI') then lblTitle.Font.Name := 'Segoe UI Semilight';
  lblEdition.Font.Height := MulDiv(Font.Height, 4, 3);
  Version := ProgramVersion;
  lblVersion.Caption := 'Version ' + Version;
  lblVersion.Visible := Version <> '';
  { the copyright sign lies beyond ASCII: made in the IDE's encoding }
  lblCopyright.Caption := 'Copyright ' + WideToIde(WideChar($00A9)) + ' 2026 iznoguuud';
  lblRepo.Hint := RepositoryURL;
  lblWindows.Caption := WindowsDescription;
  { the Delphi the IDE works with: its compiler, run-time library and design packages }
  lblDelphiDir.Caption := ExcludeTrailingPathDelimiter(DelphiRoot);
  lblCodePage.Caption := CodePageDescription;
  Y := lblTitle.Top + lblTitle.Height;
  for I := 1 to FootRow - 1 do
    if Column[I].Visible then
    begin
      Column[I].Top := Y + Gaps[I];
      Y := Column[I].Top + Column[I].Height;
    end;
  FootH := Column[FootRow].Height;
  for I := FootRow + 1 to ColumnRows - 1 do Inc(FootH, Gaps[I] + Column[I].Height);
  Inc(Y, Gaps[FootRow + 1]);
  if Y < pnlPicture.Top + PhotoH - FootH then Y := pnlPicture.Top + PhotoH - FootH;
  for I := FootRow to ColumnRows - 1 do
  begin
    if I > FootRow then Inc(Y, Gaps[I]);
    Column[I].Top := Y;
    Inc(Y, Column[I].Height);
  end;
  lblDelphiDir.Top := lblDelphiCaption.Top;
  lblCodePage.Top := lblCodePageCaption.Top;
  W := ClientWidth;
  for I := 0 to ColumnRows - 1 do
    if Column[I] is TLabel then Fit(Column[I]);
  Fit(lblDelphiDir);
  Fit(lblCodePage);
  ClientWidth := W;
  if Y < pnlPicture.Top + PhotoH then Y := pnlPicture.Top + PhotoH;
  mmLicense.Top := Y + BoxGap;
  ClientHeight := mmLicense.Top + mmLicense.Height + BandGap + pnlFooter.Height;
  UIEmptyPhoto(pnlPicture, PhotoName);
end;

procedure TAboutDlg.lblRepoClick(Sender: TObject);
begin
  UIOpenUrl(RepositoryURL);
end;

procedure TAboutDlg.lblRepoMouseEnter(Sender: TObject);
begin
  lblRepo.Font.Style := [fsUnderline];
end;

procedure TAboutDlg.lblRepoMouseLeave(Sender: TObject);
begin
  lblRepo.Font.Style := [];
end;

class procedure TAboutDlg.Execute(AOwner: TComponent);
var
  D: TAboutDlg;
begin
  D := TAboutDlg.Create(AOwner);
  try
    D.ShowModal;
  finally
    D.Free;
  end;
end;

end.
