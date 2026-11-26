{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit MigItems;

{ migrate - what Delphi 7 has installed and its files of the user: the design packages
  ([Design Packages]), the DLL experts ([Experts]) and the settings experts and Borland's design
  windows keep in Delphi 7's key (into D7 Studio's key), and the files of Delphi 7's Bin -
  code templates, Object Repository, default project options, message hints, menu templates.

  Packages and experts stay where they are: D7 Studio's list names them, $(DELPHI)\... when they
  lie in Delphi 7's folder. D7 Studio reads Delphi 7's files of its Bin as long as it has no own
  file in their place (D7Studio.dci, .dro, .dof, .msginfo.ini, .dmt beside D7Studio.ini): only an
  own file gets Delphi 7's values merged in. A copied file never replaces a different one D7
  Studio has, unless -Overwrite.

  The packages, the DLL experts and the keys of experts' settings are items that can be left out
  one by one (MigCore.ItemExcluded); List* gives them to MigCore.ListItems. }

interface

uses
  Classes;

procedure MigratePackages;
procedure MigrateExperts;
procedure MigrateFiles;

{ the items of the parts packages, experts.dll and experts.settings (MigCore.ListItems) }
procedure ListPackages(List: TStrings);
procedure ListExperts(List: TStrings);
procedure ListExpertKeys(List: TStrings);

implementation

uses
  SysUtils, IniFiles, MigCore;

const
  { packages that only extend Borland's IDE itself: D7 Studio never loads them }
  SkipPackages = '|dclsmpedit70|dclemacsedit70|designdgm70|dbx70|dcldbx70x|dclocx70x|';
  { the keys of Delphi 7's own settings under its key: the other parts migrate what D7 Studio
    keeps of them; every other key is an expert's (or Borland's design windows': Property
    Editors, Version Control) and is copied as it is }
  DelphiOwnKeys = '|activex controls|auto save|class completion|closed files|closed projects|' +
    'code explorer|code insight|compiling|corba|debugging|desktop|diagram|direct|' +
    'disabled ide packages|disabled packages|editor|environment variables|experts|explorer|' +
    'form design|globals|help|history lists|ite|known ide packages|known packages|library|' +
    'main window|message view|metaprint|object inspector|openhelp|palette|palette defaults|' +
    'print selection|projectmanager|replace|repository|search|session|todo list|toolbars|' +
    'transfer|translation tools|type library|uninstinfo|wizards|';

function DelphiBin: string;
begin
  Result := DelphiRoot + '\Bin';
end;

{ --- design packages --- }

{ D7 Studio's list ([Design Packages] P<i>=<1|0>|<file>|<description>): the index of the package
  with the file name of File (any folder: two packages of one name cannot both load), -1 none }
function FindPackage(List: TStrings; const FileName: string): Integer;
var
  S: string;
  K: Integer;
begin
  for Result := 0 to List.Count - 1 do
  begin
    S := Copy(List[Result], 3, MaxInt);
    K := Pos('|', S);
    if K > 0 then S := Copy(S, 1, K - 1);
    if SameText(ExtractFileName(ExpandDelphi(S)), ExtractFileName(FileName)) then Exit;
  end;
  Result := -1;
end;

{ Delphi 7's design packages without Borland's IDE's own (SkipPackages): Known as
  <file>=<description>, Disabled the ones it does not load; Result: how many of Borland's IDE's
  own it has }
function DelphiPackages(Known, Disabled: TStrings): Integer;
var
  I: Integer;
begin
  DelphiValueList('Known Packages', Known);
  DelphiValueList('Disabled Packages', Disabled);
  Result := 0;
  for I := Known.Count - 1 downto 0 do
    if Pos('|' + LowerCase(ChangeFileExt(ExtractFileName(Known.Names[I]), '')) + '|', SkipPackages) > 0 then
    begin
      Known.Delete(I);
      Inc(Result);
    end;
end;

function PackageDisabled(Disabled: TStrings; const FileName: string): Boolean;
var
  J: Integer;
begin
  Result := False;
  for J := 0 to Disabled.Count - 1 do
    if SameText(ExpandDelphi(Disabled.Names[J]), ExpandDelphi(FileName)) then Result := True;
end;

{ the full name of a package or expert of Delphi 7's key (by its path, $(DELPHI)\... included) }
function DelphiFile(const F: string): string;
begin
  Result := ExpandDelphi(StudioPath(F));
end;

procedure ListPackages(List: TStrings);
var
  Known, Disabled: TStringList;
  I: Integer;
  F, Caption: string;
begin
  Known := TStringList.Create;
  Disabled := TStringList.Create;
  try
    DelphiPackages(Known, Disabled);
    for I := 0 to Known.Count - 1 do
    begin
      F := Known.Names[I];
      if not FileExists(DelphiFile(F)) then Continue;
      Caption := ExtractFileName(F) + ' (' + Known.ValueFromIndex[I] + ')';
      if PackageDisabled(Disabled, F) then Caption := Caption + ', disabled';
      AddItem(List, 'packages', ExtractFileName(F), Caption);
    end;
  finally
    Disabled.Free;
    Known.Free;
  end;
end;

procedure MigratePackages;
var
  Known, Disabled, Cur, Lines: TStringList;
  I, K, N: Integer;
  F, Desc, Base, P, Flag, Entry, LastDir: string;
  Skipped: Integer;
begin
  Part('Design packages (Component | Install Packages)');
  Known := TStringList.Create;
  Disabled := TStringList.Create;
  Cur := TStringList.Create;
  Lines := TStringList.Create;
  try
    Skipped := DelphiPackages(Known, Disabled);
    if (Known.Count = 0) and (Skipped = 0) then
    begin
      Say('Delphi 7 has no design packages');
      Exit;
    end;
    { D7 Studio's list }
    N := Settings.ReadInteger('Design Packages', 'Count', 0);
    for I := 0 to N - 1 do
    begin
      Entry := Settings.ReadString('Design Packages', 'P' + IntToStr(I), '');
      if Entry <> '' then Cur.Add(Entry);
    end;
    LastDir := Settings.ReadString('Design Packages', 'LastDir', '');
    for I := 0 to Known.Count - 1 do
    begin
      F := Known.Names[I];
      Desc := Known.ValueFromIndex[I];
      Base := LowerCase(ChangeFileExt(ExtractFileName(F), ''));
      if ItemExcluded('packages', ExtractFileName(F)) or IsExcluded(Base) or IsExcluded(Desc) then
      begin
        Say(Format('left out: %s (%s)', [ExtractFileName(F), Desc]));
        Continue;
      end;
      P := StudioPath(F);
      if not FileExists(ExpandDelphi(P)) then
      begin
        Warn(Format('%s (%s) was not found: not installed', [ExpandDelphi(P), Desc]));
        Continue;
      end;
      if PackageDisabled(Disabled, F) then Flag := '0' else Flag := '1';
      Entry := Flag + '|' + P + '|' + Desc;
      K := FindPackage(Cur, P);
      if K < 0 then
      begin
        Cur.Add(Entry);
        if Flag = '1' then Say('+ ' + P + ' (' + Desc + ')')
        else Say('+ ' + P + ' (' + Desc + '), disabled');
      end
      else if Cur[K] <> Entry then
      begin
        Say(Format('~ %s -> %s', [Cur[K], Entry]));
        Cur[K] := Entry;
      end;
    end;
    if Skipped > 0 then Say(Format('%d packages of Borland''s IDE itself left out (D7 Studio never loads them)', [Skipped]));
    if LastDir <> '' then Lines.Add('LastDir=' + LastDir);
    Lines.Add('Count=' + IntToStr(Cur.Count));
    for I := 0 to Cur.Count - 1 do Lines.Add('P' + IntToStr(I) + '=' + Cur[I]);
    if not ReplaceSection('Design Packages', Lines) then Say('the packages are installed in D7 Studio already');
  finally
    Lines.Free;
    Cur.Free;
    Disabled.Free;
    Known.Free;
  end;
end;

{ --- experts --- }

{ the DLLs D7 Studio loads already: its key's Wizards and Experts, its settings' [Wizards] and
  [Experts] (SdOtaServices.ExpertFiles) }
function ExpertRegistered(const FileName: string): string;
var
  L: TStringList;
  Src, I: Integer;
begin
  Result := '';
  L := TStringList.Create;
  try
    for Src := 0 to 3 do
    begin
      case Src of
        0: StudioValueList('Wizards', L);
        1: Settings.ReadSectionValues('Wizards', L);
        2: StudioValueList('Experts', L);
        3: Settings.ReadSectionValues('Experts', L);
      end;
      for I := 0 to L.Count - 1 do
        if SamePath(L.ValueFromIndex[I], FileName) then
        begin
          Result := L.Names[I];
          Exit;
        end;
    end;
  finally
    L.Free;
  end;
end;

{ Delphi 7's DLL experts (its keys Experts and Wizards) as <name>=<file> }
procedure DelphiExperts(List: TStrings);
var
  L: TStringList;
begin
  DelphiValueList('Experts', List);
  L := TStringList.Create;
  try
    DelphiValueList('Wizards', L);
    List.AddStrings(L);
  finally
    L.Free;
  end;
end;

procedure ListExperts(List: TStrings);
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    DelphiExperts(L);
    for I := 0 to L.Count - 1 do
      if FileExists(DelphiFile(L.ValueFromIndex[I])) then
        AddItem(List, 'experts.dll', L.Names[I], L.Names[I] + ' (' + ExtractFileName(L.ValueFromIndex[I]) + ')');
  finally
    L.Free;
  end;
end;

{ the keys of Delphi 7's key that hold the settings of experts and design windows: not Delphi 7's
  own (DelphiOwnKeys) }
procedure ExpertKeys(List: TStrings);
var
  I: Integer;
begin
  DelphiSubKeys('', List);
  for I := List.Count - 1 downto 0 do
    if Pos('|' + LowerCase(List[I]) + '|', DelphiOwnKeys) > 0 then List.Delete(I);
end;

procedure ListExpertKeys(List: TStrings);
var
  Keys: TStringList;
  I: Integer;
begin
  Keys := TStringList.Create;
  try
    ExpertKeys(Keys);
    for I := 0 to Keys.Count - 1 do AddItem(List, 'experts.settings', Keys[I], Keys[I]);
  finally
    Keys.Free;
  end;
end;

procedure MigrateExpertDll(const Name, F: string);
var
  P, Other: string;
begin
  if ItemExcluded('experts.dll', Name) or IsExcluded(ExtractFileName(F)) or
    IsExcluded(ChangeFileExt(ExtractFileName(F), '')) then
  begin
    Say(Format('left out: the expert %s (%s)', [Name, F]));
    Exit;
  end;
  P := StudioPath(F);
  if not FileExists(ExpandDelphi(P)) then
  begin
    Warn(Format('the expert %s (%s) was not found: not installed', [Name, ExpandDelphi(P)]));
    Exit;
  end;
  { the same name in [Experts]: Delphi 7's file; the same file under another name: as it is }
  if not Settings.ValueExists('Experts', Name) then
  begin
    Other := ExpertRegistered(P);
    if Other <> '' then
    begin
      Say(Format('the expert %s is loaded by D7 Studio already (as %s)', [Name, Other]));
      Exit;
    end;
  end;
  SetSetting('Experts', Name, P);
end;

procedure MigrateExpertKeys;
var
  Keys: TStringList;
  I, N: Integer;
begin
  Keys := TStringList.Create;
  try
    ExpertKeys(Keys);
    for I := 0 to Keys.Count - 1 do
    begin
      if ItemExcluded('experts.settings', Keys[I]) then
      begin
        Say(Format('left out: HKEY_CURRENT_USER\%s\%s', [DelphiKey, Keys[I]]));
        Continue;
      end;
      N := CopyKey(Keys[I], Keys[I]);
      Inc(RegistryChanged, N);
      if N > 0 then Say(Format('HKEY_CURRENT_USER\%s\%s: %d values', [StudioKey, Keys[I], N]))
      else Say(Format('HKEY_CURRENT_USER\%s\%s: as in Delphi 7 already', [StudioKey, Keys[I]]));
    end;
  finally
    Keys.Free;
  end;
end;

procedure MigrateExperts;
var
  L: TStringList;
  I: Integer;
begin
  Part('Experts (DLL experts, the settings of experts and design windows)');
  if Wanted('experts.dll') then
  begin
    L := TStringList.Create;
    try
      DelphiExperts(L);
      if L.Count = 0 then Say('Delphi 7 has no DLL experts');
      for I := 0 to L.Count - 1 do MigrateExpertDll(L.Names[I], L.ValueFromIndex[I]);
    finally
      L.Free;
    end;
  end;
  if Wanted('experts.settings') then MigrateExpertKeys;
end;

{ --- files --- }

{ a file or folder of Delphi 7's that -Exclude names: said so }
function Excluded(const Name: string): Boolean;
begin
  Result := IsExcluded(Name);
  if Result then Say('left out: ' + Name);
end;

{ D7 Studio has a file of its own (Own, beside D7Studio.ini) in the place of Delphi 7's
  Bin\DelphiName; when it has none it takes Delphi 7's (said so) and there is nothing to merge }
function HasOwnFile(const Own, DelphiName, Title: string): Boolean;
begin
  Result := FileExists(SettingsDir + '\' + Own);
  if not Result then
    Say(Format('%s: D7 Studio has no %s of its own and takes Delphi 7''s Bin\%s', [Title, Own, DelphiName]));
end;

type
  { a code template of a .dci file: its heading "[name | description | language]" and its lines;
    Key: its name and language (a name has a template for each language) }
  TTemplate = class
  public
    Key, Heading: string;
    Body: TStringList;
    constructor Create;
    destructor Destroy; override;
    function Text: string;
  end;

constructor TTemplate.Create;
begin
  inherited Create;
  Body := TStringList.Create;
end;

destructor TTemplate.Destroy;
begin
  Body.Free;
  inherited Destroy;
end;

function TTemplate.Text: string;
begin
  Result := Heading + #13#10 + Body.Text;
end;

procedure ParseTemplates(const FileName: string; List: TList);
var
  L: TStringList;
  I, K: Integer;
  S: string;
  T: TTemplate;
begin
  T := nil;
  L := TStringList.Create;
  try
    if FileExists(FileName) then L.Text := ReadTextFile(FileName);
    for I := 0 to L.Count - 1 do
    begin
      S := Trim(L[I]);
      K := Pos('|', S);
      if (S <> '') and (S[1] = '[') and (S[Length(S)] = ']') and (K > 0) then
      begin
        T := TTemplate.Create;
        T.Heading := S;
        T.Key := LowerCase(Trim(Copy(S, 2, K - 2)));
        S := Copy(S, K + 1, Length(S) - K - 1);
        K := Pos('|', S);
        if K > 0 then T.Key := T.Key + '|' + LowerCase(Trim(Copy(S, K + 1, MaxInt)));
        List.Add(T);
      end
      else if T <> nil then T.Body.Add(L[I]);
    end;
    { the blank lines between two templates are not theirs }
    for I := 0 to List.Count - 1 do
      with TTemplate(List[I]) do
        while (Body.Count > 0) and (Trim(Body[Body.Count - 1]) = '') do Body.Delete(Body.Count - 1);
  finally
    L.Free;
  end;
end;

procedure FreeList(List: TList);
var
  I: Integer;
begin
  for I := 0 to List.Count - 1 do TObject(List[I]).Free;
  List.Free;
end;

{ Delphi 7's code templates (Bin\delphi32.dci) into D7 Studio's own (D7Studio.dci): a template of
  Delphi 7's replaces D7 Studio's of the same name and language }
procedure MigrateTemplates;
var
  Own, Base: TList;
  I, K: Integer;
  T: TTemplate;
  Changed: Integer;
  Text: string;
begin
  if not FileExists(DelphiBin + '\delphi32.dci') or Excluded('delphi32.dci') then Exit;
  if not HasOwnFile('D7Studio.dci', 'delphi32.dci', 'code templates') then Exit;
  Own := TList.Create;
  Base := TList.Create;
  try
    ParseTemplates(SettingsDir + '\D7Studio.dci', Own);
    ParseTemplates(DelphiBin + '\delphi32.dci', Base);
    Changed := 0;
    for I := 0 to Base.Count - 1 do
    begin
      T := TTemplate(Base[I]);
      K := Own.Count - 1;
      while (K >= 0) and (TTemplate(Own[K]).Key <> T.Key) do Dec(K);
      if K < 0 then
      begin
        Own.Add(T);
        Base[I] := nil;
        Say('+ code template ' + T.Heading);
        Inc(Changed);
      end
      else if TTemplate(Own[K]).Text <> T.Text then
      begin
        TObject(Own[K]).Free;
        Own[K] := T;
        Base[I] := nil;
        Say('~ code template ' + T.Heading);
        Inc(Changed);
      end;
    end;
    if Changed = 0 then
    begin
      Say('code templates: D7 Studio has Delphi 7''s already');
      Exit;
    end;
    Text := '';
    for I := 0 to Own.Count - 1 do Text := Text + TTemplate(Own[I]).Text + #13#10;
    WriteTextFile(SettingsDir + '\D7Studio.dci', Text);
    Inc(SettingsChanged);
    Say(Format('%s\D7Studio.dci: %d code templates of Delphi 7', [SettingsDir, Changed]));
  finally
    FreeList(Base);
    FreeList(Own);
  end;
end;

{ the keys of a repository item that name files (SdRepository.IsPathKey) }
function IsPathKey(const Key: string): Boolean;
begin
  Result := SameText(Key, 'Icon') or SameText(Key, 'Ancestor');
end;

{ Delphi 7's Object Repository (Bin\Delphi32.dro) into D7 Studio's own (D7Studio.dro): Delphi 7's
  items in D7 Studio's layout - files of Delphi 7's folder as $(DELPHI)\... -, an item of both
  with Delphi 7's values, the pages of both }
procedure MigrateRepository;
var
  Own, Src: TMemIniFile;
  Secs, Keys, Pages, L: TStringList;
  I, K, Changed: Integer;
  Sec, Key, V, Old: string;
  IsNew: Boolean;
begin
  if not FileExists(DelphiBin + '\Delphi32.dro') or Excluded('Delphi32.dro') then Exit;
  if not HasOwnFile('D7Studio.dro', 'Delphi32.dro', 'Object Repository') then Exit;
  Own := TMemIniFile.Create(SettingsDir + '\D7Studio.dro');
  Src := TMemIniFile.Create(DelphiBin + '\Delphi32.dro');
  Secs := TStringList.Create;
  Keys := TStringList.Create;
  Pages := TStringList.Create;
  L := TStringList.Create;
  try
    Changed := 0;
    Own.ReadSection('Repository Pages', Pages);
    Src.ReadSection('Repository Pages', Keys);
    for I := 0 to Keys.Count - 1 do
      if Pages.IndexOf(Keys[I]) < 0 then
      begin
        Pages.Add(Keys[I]);
        Say('+ repository page ' + Keys[I]);
        Inc(Changed);
      end;
    Src.ReadSections(Secs);
    for I := 0 to Secs.Count - 1 do
    begin
      if SameText(Secs[I], 'Repository Pages') then Continue;
      Sec := StudioPath(Secs[I]);
      Src.ReadSection(Secs[I], Keys);
      IsNew := not Own.SectionExists(Sec);
      if IsNew then
      begin
        Say('+ repository item ' + Sec);
        Inc(Changed);
      end;
      for K := 0 to Keys.Count - 1 do
      begin
        Key := Keys[K];
        V := Src.ReadString(Secs[I], Key, '');
        if Own.ValueExists(Sec, Key) then
        begin
          Old := Own.ReadString(Sec, Key, '');
          if IsPathKey(Key) then
          begin
            V := StudioPath(V);
            if SamePath(Old, V) then Continue;
          end
          else if Old = V then Continue;
        end
        else if IsPathKey(Key) then V := StudioPath(V);
        if not IsNew then
        begin
          Say(Format('~ repository item %s: %s', [Sec, Key]));
          Inc(Changed);
        end;
        Own.WriteString(Sec, Key, V);
      end;
    end;
    if Changed = 0 then
    begin
      Say('Object Repository: D7 Studio has Delphi 7''s items already');
      Exit;
    end;
    { D7 Studio's layout (TRepository.Save): the pages, then the items }
    L.Add('[Repository Pages]');
    for I := 0 to Pages.Count - 1 do L.Add(Pages[I] + '=');
    Own.ReadSections(Secs);
    for I := 0 to Secs.Count - 1 do
    begin
      if SameText(Secs[I], 'Repository Pages') then Continue;
      L.Add('');
      L.Add('[' + Secs[I] + ']');
      Own.ReadSectionValues(Secs[I], Keys);
      L.AddStrings(Keys);
    end;
    WriteTextFile(SettingsDir + '\D7Studio.dro', L.Text);
    Inc(SettingsChanged);
    Say(Format('%s\D7Studio.dro: %d changes from Delphi 7', [SettingsDir, Changed]));
  finally
    L.Free;
    Pages.Free;
    Keys.Free;
    Secs.Free;
    Src.Free;
    Own.Free;
  end;
end;

{ an ini file of Delphi 7's Bin merged into D7 Studio's own (Own beside D7Studio.ini): Delphi 7's
  values replace D7 Studio's; PathSection: a section whose values are folder lists }
procedure MergeIniFile(const DelphiName, Own, PathSection, Title: string);
var
  Dst, Src: TMemIniFile;
  Secs, Keys, L: TStringList;
  I, K, Changed: Integer;
  V: string;
begin
  if not FileExists(DelphiBin + '\' + DelphiName) or Excluded(DelphiName) then Exit;
  if not HasOwnFile(Own, DelphiName, Title) then Exit;
  Dst := TMemIniFile.Create(SettingsDir + '\' + Own);
  Src := TMemIniFile.Create(DelphiBin + '\' + DelphiName);
  Secs := TStringList.Create;
  Keys := TStringList.Create;
  L := TStringList.Create;
  try
    Changed := 0;
    Src.ReadSections(Secs);
    for I := 0 to Secs.Count - 1 do
    begin
      Src.ReadSection(Secs[I], Keys);
      for K := 0 to Keys.Count - 1 do
      begin
        V := Src.ReadString(Secs[I], Keys[K], '');
        if SameText(Secs[I], PathSection) then V := StudioPathList(V);
        if Dst.ValueExists(Secs[I], Keys[K]) and (Dst.ReadString(Secs[I], Keys[K], '') = V) then Continue;
        Dst.WriteString(Secs[I], Keys[K], V);
        Inc(Changed);
      end;
    end;
    if Changed = 0 then
    begin
      Say(Title + ': D7 Studio has Delphi 7''s already');
      Exit;
    end;
    Dst.GetStrings(L);
    WriteTextFile(SettingsDir + '\' + Own, L.Text);
    Inc(SettingsChanged);
    Say(Format('%s\%s: %d values of Delphi 7 (%s)', [SettingsDir, Own, Changed, Title]));
  finally
    L.Free;
    Keys.Free;
    Secs.Free;
    Src.Free;
    Dst.Free;
  end;
end;

{ Delphi 7's menu templates (Bin\delphi32.dmt, a binary file) as D7 Studio's own D7Studio.dmt
  (without one, D7 Studio copies Delphi 7's when the menu designer first needs it) }
procedure MigrateMenuTemplates;
var
  Src, Own: string;
begin
  Src := DelphiBin + '\delphi32.dmt';
  if not FileExists(Src) or Excluded('delphi32.dmt') then Exit;
  if not HasOwnFile('D7Studio.dmt', 'delphi32.dmt', 'menu templates') then Exit;
  Own := SettingsDir + '\D7Studio.dmt';
  case CopyOneFile(Src, Own) of
    crCopied: Say(Format('%s: Delphi 7''s menu templates', [Own]));
    crSame: Say('menu templates: D7 Studio has Delphi 7''s already');
    crKept: Warn(Format('%s differs from Delphi 7''s menu templates and was kept (-Overwrite replaces it)', [Own]));
  end;
end;

procedure MigrateFiles;
var
  F: TSearchRec;
  Names: string;
  N: Integer;
begin
  Part('Files (code templates, Object Repository, default project options, message hints, menu templates)');
  if (DelphiRoot = '') or not DirectoryExists(DelphiRoot) then
  begin
    Say('Delphi 7''s folder is not there: no files to migrate');
    Exit;
  end;
  if Wanted('files.templates') then MigrateTemplates;
  if Wanted('files.repository') then MigrateRepository;
  if Wanted('files.projectoptions') then
    MergeIniFile('defproj.dof', 'D7Studio.dof', 'Directories', 'default project options');
  if Wanted('files.messagehints') then MergeIniFile('msginfo70.ini', 'D7Studio.msginfo.ini', '', 'message hints');
  if Wanted('files.menutemplates') then MigrateMenuTemplates;
  { what D7 Studio keeps in a form of its own: noted, not converted }
  if FileExists(DelphiBin + '\delphi32.dct') and (FileSizeOf(DelphiBin + '\delphi32.dct') > 40) then
    Warn('Delphi 7''s component templates (Bin\delphi32.dct) are not migrated: D7 Studio keeps them in a format of its own');
  Names := '';
  N := 0;
  if FindFirst(DelphiBin + '\*.dst', faAnyFile, F) = 0 then
  try
    repeat
      if Names <> '' then Names := Names + ', ';
      Names := Names + ChangeFileExt(F.Name, '');
      Inc(N);
    until FindNext(F) <> 0;
  finally
    FindClose(F);
  end;
  if N > 0 then
    Say(Format('Delphi 7''s desktops (%s) are not migrated: D7 Studio lays out its views differently', [Names]));
end;

end.
