{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdFormatterOptions;

{ D7 Studio - the values of Tools | Formatter Options: RAD Studio's
  Delphi formatter options in [Formatter] of the settings (RAD Studio's names and values, so a
  line of its Formatter.config reads the same), what D7 Studio adds (format on save, the question
  before Format Project Sources, the form files), the captions of the values, the presets (the
  built-in ones of SdFormatter and the user's own, [Formatter Preset <name>] - only the user's can
  be overwritten and deleted), RAD Studio's profile files (Formatter.config) in and out, and the one
  routine that formats a file's text by its kind (SdFormatter). }

interface

uses
  SysUtils, Classes, IniFiles, SdFormatter;

type
  TFormatterOptions = record
    Values: TFmtValues;
    FormatOnSave: Boolean;      // a Pascal file is formatted each time it is saved
    Confirm: Boolean;           // Format Project Sources asks first (RAD Studio's Formatter.Confirmation)
    FormFiles: Boolean;         // Format Project Sources also writes the text form files in Delphi's layout
  end;

  TFmtFileKind = (ffNone, ffPascal, ffForm);

var
  FormatterOptions: TFormatterOptions;

procedure LoadFormatterOptions(Ini: TCustomIniFile);
procedure SaveFormatterOptions(Ini: TCustomIniFile);
{ the presets: the built-in ones (FmtBuiltinPresets, in their order), then the user's (by name);
  a user preset's Objects is Pointer(1) }
procedure FmtPresetNames(L: TStrings);
function FmtIsBuiltinPreset(const Name: string): Boolean;
function FmtIsUserPreset(const Name: string): Boolean;
{ a preset's values (False: there is none of that name) }
function FmtPresetByName(const Name: string; var V: TFmtValues): Boolean;
{ a user preset written (a new one, or over one of the user's - never over a built-in one: False)
  and deleted; at once in the settings }
function SaveUserPreset(const Name: string; const V: TFmtValues): Boolean;
procedure DeleteUserPreset(const Name: string);
{ RAD Studio's profile files: read into V (False: Error), written from V }
function ImportRadProfile(const FileName: string; var V: TFmtValues; var Error: string): Boolean;
procedure ExportRadProfile(const FileName: string; const V: TFmtValues);
{ the captions of the values of a kind (vkBool and vkInt have none), in the order of the values }
procedure FmtValueCaptions(Kind: TFmtKind; L: TStrings);
{ by the file name: .pas .dpr .dpk .inc are Pascal, .dfm a form }
function FmtFileKind(const FileName: string): TFmtFileKind;
{ Text formatted as Kind with the formatter options (SelStart < 0: the whole text) }
function FormatText(Kind: TFmtFileKind; const Text: string; SelStart, SelEnd: Integer;
  var R: TFmtResult; var Error: string): Boolean;

implementation

uses
  SdSettings, SdFileNames;

const
  Section = 'Formatter';
  PresetPrefix = 'Formatter Preset ';

{ the values of a section ([Formatter] or a preset's): what it does not have stays as in V }
procedure ReadValues(Ini: TCustomIniFile; const Sect: string; var V: TFmtValues);
var
  F: TFmtOption;
  N: Integer;
begin
  for F := Low(F) to High(F) do
    if FmtValueFromText(F, Ini.ReadString(Sect, FmtOptionInfo[F].Key, ''), N) then V[F] := N;
end;

procedure WriteValues(Ini: TCustomIniFile; const Sect: string; const V: TFmtValues);
var
  F: TFmtOption;
begin
  for F := Low(F) to High(F) do Ini.WriteString(Sect, FmtOptionInfo[F].Key, FmtValueToText(F, V[F]));
end;

procedure FmtPresetNames(L: TStrings);
var
  I: Integer;
  S: TStringList;
begin
  L.Clear;
  for I := Low(FmtBuiltinPresets) to High(FmtBuiltinPresets) do L.Add(FmtBuiltinPresets[I].Name);
  S := TStringList.Create;
  try
    Settings.ReadSections(S);
    for I := S.Count - 1 downto 0 do
      if not SameText(Copy(S[I], 1, Length(PresetPrefix)), PresetPrefix) then S.Delete(I)
      else S[I] := Copy(S[I], Length(PresetPrefix) + 1, MaxInt);
    S.Sort;
    for I := 0 to S.Count - 1 do
      if not FmtIsBuiltinPreset(S[I]) then L.AddObject(S[I], Pointer(1));
  finally
    S.Free;
  end;
end;

function BuiltinIndex(const Name: string): Integer;
begin
  for Result := Low(FmtBuiltinPresets) to High(FmtBuiltinPresets) do
    if SameText(FmtBuiltinPresets[Result].Name, Trim(Name)) then Exit;
  Result := -1;
end;

function FmtIsBuiltinPreset(const Name: string): Boolean;
begin
  Result := BuiltinIndex(Name) >= 0;
end;

function FmtIsUserPreset(const Name: string): Boolean;
begin
  Result := (Trim(Name) <> '') and not FmtIsBuiltinPreset(Name) and
    Settings.SectionExists(PresetPrefix + Trim(Name));
end;

function FmtPresetByName(const Name: string; var V: TFmtValues): Boolean;
var
  I: Integer;
begin
  I := BuiltinIndex(Name);
  Result := True;
  if I >= 0 then FmtBuiltinValues(I, V)
  else if FmtIsUserPreset(Name) then
  begin
    { a preset of an older D7 Studio that lacks an option: RAD Studio's default for it }
    FmtPresetValues(fpDefault, V);
    ReadValues(Settings, PresetPrefix + Trim(Name), V);
  end
  else
    Result := False;
end;

function SaveUserPreset(const Name: string; const V: TFmtValues): Boolean;
begin
  Result := (Trim(Name) <> '') and not FmtIsBuiltinPreset(Name);
  if Result then WriteValues(Settings, PresetPrefix + Trim(Name), V);
end;

procedure DeleteUserPreset(const Name: string);
begin
  if FmtIsUserPreset(Name) then Settings.EraseSection(PresetPrefix + Trim(Name));
end;

function ImportRadProfile(const FileName: string; var V: TFmtValues; var Error: string): Boolean;
var
  N: Integer;
  W: TFmtValues;
begin
  Result := False;
  W := V;
  try
    FmtFromRadConfig(ReadFileU(FileName), W, N);
  except
    on E: Exception do
    begin
      Error := E.Message;
      Exit;
    end;
  end;
  if N = 0 then
  begin
    Error := ExtractFileName(FileName) + ' holds no options of RAD Studio''s Delphi formatter.';
    Exit;
  end;
  V := W;
  Result := True;
end;

procedure ExportRadProfile(const FileName: string; const V: TFmtValues);
begin
  WriteFileU(FileName, FmtToRadConfig(V));
end;

{ ... and how RAD Studio's options page shows them }
procedure FmtValueCaptions(Kind: TFmtKind; L: TStrings);
var
  S: string;
begin
  case Kind of
    vkUseSpace: S := 'None|Before only|After only|Before and after|Preserve spacing';
    vkSpaceAfter: S := 'No|Yes|Preserve spacing';
    vkSpaceConflict: S := 'No space|Space|Preserve spacing';
    vkLfCase: S := 'No|Yes|As is';
    vkLfCaseEx: S := 'No|Yes, first name on the same line|Yes, first name on the next line|As is';
    vkArrayCase: S := 'No|Yes|As is|Only first dimension';
    vkUnindent: S := 'To left margin|Decrease one indent|None';
    vkIndentComments: S := 'No|Yes|With additional indent';
    vkInnerOuter: S := 'None|Inner only|Outer only|Inner and outer|Preserve spacing';
    vkCapitalization: S := 'As is|lowercase|UPPERCASE|First character in uppercase|As first occurrence';
  else
    S := '';
  end;
  L.Text := StringReplace(S, '|', #13#10, [rfReplaceAll]);
end;

procedure LoadFormatterOptions(Ini: TCustomIniFile);
var
  O: TFormatterOptions;
begin
  FmtPresetValues(fpDefault, O.Values);
  ReadValues(Ini, Section, O.Values);
  O.FormatOnSave := Ini.ReadBool(Section, 'FormatOnSave', False);
  O.Confirm := Ini.ReadBool(Section, 'Confirm', True);
  O.FormFiles := Ini.ReadBool(Section, 'FormFiles', True);
  FormatterOptions := O;
end;

procedure SaveFormatterOptions(Ini: TCustomIniFile);
begin
  WriteValues(Ini, Section, FormatterOptions.Values);
  Ini.WriteBool(Section, 'FormatOnSave', FormatterOptions.FormatOnSave);
  Ini.WriteBool(Section, 'Confirm', FormatterOptions.Confirm);
  Ini.WriteBool(Section, 'FormFiles', FormatterOptions.FormFiles);
end;

function FmtFileKind(const FileName: string): TFmtFileKind;
var
  E: string;
begin
  E := LowerCase(ExtractFileExt(FileName));
  if (E = '.pas') or (E = '.dpr') or (E = '.dpk') or (E = '.inc') then Result := ffPascal
  else if E = '.dfm' then Result := ffForm
  else Result := ffNone;
end;

function FormatText(Kind: TFmtFileKind; const Text: string; SelStart, SelEnd: Integer;
  var R: TFmtResult; var Error: string): Boolean;
begin
  case Kind of
    ffPascal: Result := FormatPascal(Text, FormatterOptions.Values, SelStart, SelEnd, R, Error);
    ffForm: Result := FormatDfm(Text, R, Error);
  else
    Error := 'The formatter formats Pascal sources and form files.';
    Result := False;
  end;
end;

initialization
  FmtPresetValues(fpDefault, FormatterOptions.Values);
  FormatterOptions.Confirm := True;
  FormatterOptions.FormFiles := True;
end.
