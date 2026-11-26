{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdRepository;

{ D7 Studio - the Object Repository and the component templates.

  * The repository (File | New | Other, Add to Repository, Tools | Repository): Delphi 7's
    Delphi32.dro (D7 Studio's folder, SdDelphiDir) is read while D7 Studio has not changed
    anything; the first change writes the whole repository to D7 Studio's own file,
    <settings>\D7Studio.dro, in the same format, and from then on that file is read. Delphi's
    file is never written. An item is a section named after its template's files without the
    extension (a form's unit, a project's project file): Type (FormTemplate, ProjectTemplate),
    Name, Page, Icon, Description, Author, DefaultMainForm, DefaultNewForm, DefaultProject,
    Ancestor - every key of a section is kept as it is, also the ones D7 Studio does not know.
    The files of D7 Studio's folder (its ObjRepos) are $(DELPHI)\... in the files - the section
    names, Icon and Ancestor -, full paths in memory.
  * The component templates (Component | Create Component Template): <settings>\D7Studio.dct, an
    ini file, a section per template - its page, the class of its first component (the icon) and
    the components as .dfm text (one line, line breaks as \n). They are items of the Components
    view; adding one pastes its components. }

interface

uses
  SysUtils, Classes, IniFiles;

type
  TRepoItem = class
  private
    FValues: TStringList;            // the section's keys, as they are
    function GetValue(const Key: string): string;
    procedure SetValue(const Key, Value: string);
    function GetFlag(const Key: string): Boolean;
    procedure SetFlag(const Key: string; Value: Boolean);
  public
    Path: string;                    // the section: the template's files without extension
    constructor Create;
    destructor Destroy; override;
    function IsForm: Boolean;
    function IsProject: Boolean;
    property Values[const Key: string]: string read GetValue write SetValue;
    property Flags[const Key: string]: Boolean read GetFlag write SetFlag;
  end;

  TRepository = class
  private
    FItems: TList;
    FPages: TStringList;
    function GetItem(Index: Integer): TRepoItem;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load;
    procedure Save;
    procedure Clear;
    function Count: Integer;
    property Items[Index: Integer]: TRepoItem read GetItem; default;
    property Pages: TStringList read FPages;           // in their order
    function Find(const Path: string): TRepoItem;
    { a new item (a form or a project template at Path), or the item of Path made new }
    function Add(const Path: string; IsProject: Boolean): TRepoItem;
    procedure Delete(Item: TRepoItem);
    { the item with Key (DefaultNewForm, DefaultMainForm, DefaultProject) set, nil: none }
    function Default(const Key: string): TRepoItem;
    { Key set for Item alone }
    procedure SetDefault(const Key: string; Item: TRepoItem; Value: Boolean);
  end;

  TCompTemplate = class
  public
    Name, Page, ClassName: string;
    IconFile: string;                // a bitmap of its own ('': its first component's icon)
    Text: string;                    // the components as .dfm text
  end;

  TCompTemplates = class
  private
    FItems: TList;
    function GetItem(Index: Integer): TCompTemplate;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load;
    procedure Save;
    function Count: Integer;
    property Items[Index: Integer]: TCompTemplate read GetItem; default;
    function Find(const Name: string): TCompTemplate;
    function Add(const Name: string): TCompTemplate;    // a new one, or the one of that name
    procedure Delete(T: TCompTemplate);
  end;


function DelphiRepositoryFile: string;
function OwnRepositoryFile: string;

implementation

uses
  SdSettings, SdDelphiDir, SdFileNames;

function DelphiRepositoryFile: string;
begin
  Result := DelphiBin + 'Delphi32.dro';
end;

{ the keys of an item that name files: $(DELPHI)\... in the file (a file of D7 Studio's folder,
  SdDelphiDir), full paths in memory }
function IsPathKey(const Key: string): Boolean;
begin
  Result := SameText(Key, 'Icon') or SameText(Key, 'Ancestor');
end;

function OwnRepositoryFile: string;
begin
  Result := SettingsDir + 'D7Studio.dro';
end;

function OwnTemplatesFile: string;
begin
  Result := SettingsDir + 'D7Studio.dct';
end;

{ ---------------------------------------------------------------- TRepoItem }

constructor TRepoItem.Create;
begin
  inherited Create;
  FValues := TStringList.Create;
end;

destructor TRepoItem.Destroy;
begin
  FValues.Free;
  inherited Destroy;
end;

function TRepoItem.GetValue(const Key: string): string;
begin
  Result := FValues.Values[Key];
end;

procedure TRepoItem.SetValue(const Key, Value: string);
var
  I: Integer;
begin
  I := FValues.IndexOfName(Key);
  if I >= 0 then FValues[I] := Key + '=' + Value else FValues.Add(Key + '=' + Value);
end;

function TRepoItem.GetFlag(const Key: string): Boolean;
begin
  Result := (GetValue(Key) <> '') and (GetValue(Key) <> '0');
end;

procedure TRepoItem.SetFlag(const Key: string; Value: Boolean);
begin
  SetValue(Key, IntToStr(Ord(Value)));
end;

function TRepoItem.IsForm: Boolean;
begin
  Result := SameText(GetValue('Type'), 'FormTemplate');
end;

function TRepoItem.IsProject: Boolean;
begin
  Result := SameText(GetValue('Type'), 'ProjectTemplate');
end;

{ ---------------------------------------------------------------- TRepository }

constructor TRepository.Create;
begin
  inherited Create;
  FItems := TList.Create;
  FPages := TStringList.Create;
end;

destructor TRepository.Destroy;
begin
  Clear;
  FItems.Free;
  FPages.Free;
  inherited Destroy;
end;

procedure TRepository.Clear;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do TObject(FItems[I]).Free;
  FItems.Clear;
  FPages.Clear;
end;

function TRepository.Count: Integer;
begin
  Result := FItems.Count;
end;

function TRepository.GetItem(Index: Integer): TRepoItem;
begin
  Result := TRepoItem(FItems[Index]);
end;

{ D7 Studio's file once it exists, else Delphi's: every section of the form and project
  templates, and the pages - [Repository Pages] in its order, then the pages the items name }
procedure TRepository.Load;
var
  Ini: TMemIniFile;
  Sections, Keys: TStringList;
  I, K: Integer;
  It: TRepoItem;
  FileName: string;
begin
  Clear;
  FileName := OwnRepositoryFile;
  if not FileExists(FileName) then FileName := DelphiRepositoryFile;
  if not FileExists(FileName) then Exit;
  { Delphi's file is in the system code page; D7 Studio's own one UTF-8 beyond ASCII }
  Ini := OpenSystemIniFile(FileName);
  Sections := TStringList.Create;
  Keys := TStringList.Create;
  try
    Ini.ReadSection('Repository Pages', FPages);
    Ini.ReadSections(Sections);
    for I := 0 to Sections.Count - 1 do
    begin
      if SameText(Sections[I], 'Repository Pages') then Continue;
      Ini.ReadSectionValues(Sections[I], Keys);
      It := TRepoItem.Create;
      It.Path := ExpandDelphiMacros(Sections[I]);
      It.FValues.Assign(Keys);
      for K := 0 to It.FValues.Count - 1 do
        if IsPathKey(It.FValues.Names[K]) then
          It.FValues[K] := It.FValues.Names[K] + '=' + ExpandDelphiMacros(It.FValues.ValueFromIndex[K]);
      FItems.Add(It);
      if (It.IsForm or It.IsProject) and (It.Values['Page'] <> '') and (FPages.IndexOf(It.Values['Page']) < 0) then
        FPages.Add(It.Values['Page']);
    end;
    for I := 0 to FPages.Count - 1 do
    begin
      K := Pos('=', FPages[I]);
      if K > 0 then FPages[I] := Copy(FPages[I], 1, K - 1);
    end;
  finally
    Keys.Free;
    Sections.Free;
    Ini.Free;
  end;
end;

procedure TRepository.Save;
var
  L: TStringList;
  I, K: Integer;
begin
  L := TStringList.Create;
  try
    L.Add('[Repository Pages]');
    for I := 0 to FPages.Count - 1 do L.Add(FPages[I] + '=');
    for I := 0 to FItems.Count - 1 do
    begin
      L.Add('');
      L.Add('[' + CollapseDelphiMacros(Items[I].Path) + ']');
      for K := 0 to Items[I].FValues.Count - 1 do
        if IsPathKey(Items[I].FValues.Names[K]) then
          L.Add(Items[I].FValues.Names[K] + '=' + CollapseDelphiMacros(Items[I].FValues.ValueFromIndex[K]))
        else
          L.Add(Items[I].FValues[K]);
    end;
    ForceDirectories(ExtractFilePath(OwnRepositoryFile));
    WriteFileU(OwnRepositoryFile, L.Text);       // the safe save: a failure leaves the old file
  finally
    L.Free;
  end;
end;

function TRepository.Find(const Path: string): TRepoItem;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    Result := Items[I];
    if SameText(Result.Path, Path) then Exit;
  end;
  Result := nil;
end;

function TRepository.Add(const Path: string; IsProject: Boolean): TRepoItem;
begin
  Result := Find(Path);
  if Result = nil then
  begin
    Result := TRepoItem.Create;
    Result.Path := Path;
    FItems.Add(Result);
  end;
  if IsProject then Result.Values['Type'] := 'ProjectTemplate' else Result.Values['Type'] := 'FormTemplate';
  if not IsProject and (Result.Values['Designer'] = '') then Result.Values['Designer'] := 'dfm';
end;

procedure TRepository.Delete(Item: TRepoItem);
begin
  if FItems.Remove(Item) >= 0 then Item.Free;
end;

function TRepository.Default(const Key: string): TRepoItem;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    Result := Items[I];
    if Result.Flags[Key] then Exit;
  end;
  Result := nil;
end;

procedure TRepository.SetDefault(const Key: string; Item: TRepoItem; Value: Boolean);
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
    if Items[I].Flags[Key] then Items[I].Flags[Key] := False;
  if Item <> nil then Item.Flags[Key] := Value;
end;

{ ---------------------------------------------------------------- the component templates }

function Escape(const S: string): string;
begin
  Result := StringReplace(S, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, #13#10, '\n', [rfReplaceAll]);
end;

{ Escape backwards; never longer than S ("\n" is two characters as #13#10 is): written into a
  string of S's length, cut at the end (a character at a time, a template's text was copied for
  every character) }
function Unescape(const S: string): string;
var
  I, N: Integer;
begin
  SetLength(Result, Length(S));
  N := 0;
  I := 1;
  while I <= Length(S) do
  begin
    if (S[I] = '\') and (I < Length(S)) then
    begin
      if S[I + 1] = 'n' then
      begin
        Result[N + 1] := #13;
        Result[N + 2] := #10;
        Inc(N, 2);
      end
      else
      begin
        Result[N + 1] := S[I + 1];
        Inc(N);
      end;
      Inc(I, 2);
    end
    else
    begin
      Result[N + 1] := S[I];
      Inc(N);
      Inc(I);
    end;
  end;
  SetLength(Result, N);
end;

constructor TCompTemplates.Create;
begin
  inherited Create;
  FItems := TList.Create;
end;

destructor TCompTemplates.Destroy;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do TObject(FItems[I]).Free;
  FItems.Free;
  inherited Destroy;
end;

function TCompTemplates.Count: Integer;
begin
  Result := FItems.Count;
end;

function TCompTemplates.GetItem(Index: Integer): TCompTemplate;
begin
  Result := TCompTemplate(FItems[Index]);
end;

procedure TCompTemplates.Load;
var
  Ini: TMemIniFile;
  Sections: TStringList;
  I: Integer;
  T: TCompTemplate;
begin
  for I := 0 to FItems.Count - 1 do TObject(FItems[I]).Free;
  FItems.Clear;
  if not FileExists(OwnTemplatesFile) then Exit;
  Ini := TMemIniFile.Create(OwnTemplatesFile);
  Sections := TStringList.Create;
  try
    Ini.ReadSections(Sections);
    for I := 0 to Sections.Count - 1 do
    begin
      T := TCompTemplate.Create;
      T.Name := Sections[I];
      T.Page := Ini.ReadString(Sections[I], 'Page', 'Templates');
      T.ClassName := Ini.ReadString(Sections[I], 'Class', '');
      T.IconFile := Ini.ReadString(Sections[I], 'Icon', '');
      T.Text := Unescape(Ini.ReadString(Sections[I], 'Text', ''));
      FItems.Add(T);
    end;
  finally
    Sections.Free;
    Ini.Free;
  end;
end;

procedure TCompTemplates.Save;
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    for I := 0 to FItems.Count - 1 do
    begin
      if I > 0 then L.Add('');
      L.Add('[' + Items[I].Name + ']');
      L.Add('Page=' + Items[I].Page);
      L.Add('Class=' + Items[I].ClassName);
      L.Add('Icon=' + Items[I].IconFile);
      L.Add('Text=' + Escape(Items[I].Text));
    end;
    ForceDirectories(ExtractFilePath(OwnTemplatesFile));
    WriteFileU(OwnTemplatesFile, L.Text);        // the safe save: a failure leaves the old file
  finally
    L.Free;
  end;
end;

function TCompTemplates.Find(const Name: string): TCompTemplate;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
  begin
    Result := Items[I];
    if SameText(Result.Name, Name) then Exit;
  end;
  Result := nil;
end;

function TCompTemplates.Add(const Name: string): TCompTemplate;
begin
  Result := Find(Name);
  if Result = nil then
  begin
    Result := TCompTemplate.Create;
    Result.Name := Name;
    FItems.Add(Result);
  end;
end;

procedure TCompTemplates.Delete(T: TCompTemplate);
begin
  if FItems.Remove(T) >= 0 then T.Free;
end;

end.
