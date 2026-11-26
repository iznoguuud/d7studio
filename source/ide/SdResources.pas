{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdResources;

{ D7 Studio - the resources of a project as the Resources view shows them: the entries of its
  <project>.res, read and written through the Open Tools API's
  model of that file (SdOtaModules, IOTAProjectResource: an expert and the view see the same
  entries; every change is written at once).

  An item is what the view lists: a bitmap, an icon or a cursor (its group - the images of the
  group are not items of their own), the string table of a language (its blocks of 16 strings),
  the version information, a manifest, any other entry as data. Items are made again by Refresh;
  a Key (type, name, language) finds an item again after it. }

interface

uses
  Windows, SysUtils, Classes, ToolsAPI, SdResImage;

const
  RT_STRING_ID = 6;
  RT_RCDATA_ID = 10;
  RT_VERSION_ID = 16;
  RT_MANIFEST_ID = 24;

type
  TSdResKind = (rkBitmap, rkIcon, rkCursor, rkStrings, rkVersion, rkManifest, rkData);

  TSdResItem = class
  public
    Kind: TSdResKind;
    TypeOrd: Integer;              // -1: the type is a name
    TypeName: string;
    NameOrd: Integer;              // -1: a name (a string table has none: its blocks are numbered)
    Name: string;
    Language: Integer;
    Size: Integer;                 // the bytes of its entries
    Detail: string;                // the view's second column
    IdeManifest: Boolean;          // the manifest D7 Studio writes for Project | Options
    function TypeText: string;     // "Bitmap", "RCDATA", "PNG"
    function NameText: string;     // "MAINICON", "1"
    function Key: string;
  end;

  TSdStringItem = record
    Id: Integer;
    Text: WideString;
  end;
  TSdStringItems = array of TSdStringItem;

  TSdResources = class
  private
    FProjectFile: string;
    FItems: TList;
    FCanWrite: Boolean;
    FRes: IOTAProjectResource;     // CreateOn's model, else nil: the project's (OtaModules)
    function Res: IOTAProjectResource;
    procedure Clear;
    function Find(TypeOrd: Integer; const TypeName: string; NameOrd: Integer; const Name: string;
      Language: Integer): IOTAResourceEntry;
    function Entry(It: TSdResItem): IOTAResourceEntry;
    function NewEntry(TypeOrd: Integer; const TypeName: string; NameOrd: Integer; const Name: string;
      Language: Integer; Flags: Word; const Data: string): IOTAResourceEntry;
    procedure SetData(const E: IOTAResourceEntry; const Data: string);
    { a command's changes: the model writes the file once, at EndWrite (not at each entry);
      CheckWritten after it }
    procedure BeginWrite;
    procedure EndWrite;
    procedure CheckWritten;
    procedure GroupImages(It: TSdResItem; var Entries: TSdIconEntries; var Ids: TSdIds);
    function FindImage(ImgType, Id, Language: Integer): IOTAResourceEntry;
    procedure DeleteGroupImages(It: TSdResItem; var Freed: TSdIds);
    function NextId(TypeOrd: Integer): Integer;
    function UsedByOtherGroup(Group: TSdResItem; Id: Integer): Boolean;
  public
    constructor Create(const AProjectFile: string);
    { the resources of a model of the project's .res other than the project's own (a copy that
      is never written: a compile's, with the unsaved resource pages applied - SdResPage) }
    constructor CreateOn(const AProjectFile: string; const ARes: IOTAProjectResource);
    destructor Destroy; override;
    procedure Refresh;
    function Count: Integer;
    function Item(Index: Integer): TSdResItem;
    function FindKey(const Key: string): TSdResItem;
    function FindKind(Kind: TSdResKind; Language: Integer = -1): TSdResItem;   // -1: any language
    function ResFile: string;
    property ProjectFile: string read FProjectFile;
    { False: the file is no 32-bit resource file - nothing is written into it }
    property CanWrite: Boolean read FCanWrite;
    { the data of an item's entry (a string table: '') }
    function Data(It: TSdResItem): string;
    { images: a bitmap; the images of an icon or a cursor (TSdImage each, the caller frees them) }
    function ReadBitmap(It: TSdResItem): TSdImage;
    procedure ReadImages(It: TSdResItem; Images: TList);
    procedure WriteBitmap(It: TSdResItem; Img: TSdImage);
    procedure WriteImages(It: TSdResItem; Images: TList);
    { a new resource; the key of its item }
    function AddBitmap(const Name: string; Img: TSdImage): string;
    function AddImages(Kind: TSdResKind; const Name: string; Images: TList): string;
    function AddEntries(Kind: TSdResKind; const Name: string; const Entries: TSdIconEntries): string;
    function AddData(TypeOrd: Integer; const TypeName, Name: string; const Data: string): string;
    procedure WriteData(It: TSdResItem; const Data: string);
    { the strings of a language's table / the table written (no strings: no table) }
    procedure ReadStrings(Language: Integer; var Items: TSdStringItems);
    function WriteStrings(Language: Integer; const Items: TSdStringItems): string;
    procedure Delete(It: TSdResItem);
    { a new type (a data item's), name and language; '' when there is one so already }
    function Rename(It: TSdResItem; const NewType, NewName: string; NewLanguage: Integer): string;
    { the resource as a file: its bytes and the file's extension ('.bmp', '.ico' ...) }
    function ExportData(It: TSdResItem; var Ext: string): string;
    { a file into the resources: by its extension a bitmap, an icon, a cursor, a manifest, else
      RCDATA named after the file. Raises EResImage on a file that is not what its name says. }
    function Import(const FileName, Bytes: string): string;
    { a name for a new resource of the kind not used yet (BITMAP1, ICON2 ...) }
    function NewName(Kind: TSdResKind; const Base: string = ''): string;
    { what is wrong with a type or a name ('' nothing): an ordinal 1 ... 65535 or a name of
      letters, digits and _ . - }
    function CheckName(const S, What: string): string;
    { ... with a type: also the name of a standard type ("Message Table", ResTypeText) or #n }
    function CheckType(const S: string): string;
    { is there an entry of the type with the name and the language, other than It's? }
    function Taken(It: TSdResItem; const AType, AName: string; Language: Integer): Boolean;
  end;

function ResTypeText(TypeOrd: Integer; const TypeName: string): string;
function ResKindText(Kind: TSdResKind): string;               // "Bitmap", "String Table" ...
{ an item's Key: its type, name and language; a string table is its language's }
function ResKey(TypeOrd: Integer; const TypeName: string; NameOrd: Integer; const Name: string;
  Language: Integer): string;
function StringTableKey(Language: Integer): string;
{ the image kind of a bitmap, an icon or a cursor (the image editor's) }
function ResImageKind(Kind: TSdResKind): TSdImageKind;
function LanguageText(Language: Integer): string;             // "Neutral", "Greek (Greece)"
procedure GetLanguages(L: TStrings);                          // Neutral first; Objects: the id
function IsTextData(const Data: string): Boolean;             // UTF-8 / ASCII text without NUL

implementation

uses
  SdOtaModules, SdProject, SdEncoding;

const
  FlagsDefault = $1030;              // moveable, pure, discardable
  FlagsImage = $1010;                // an icon's or a cursor's image: moveable, discardable

{ ---------------------------------------------------------------- texts }

function ResTypeText(TypeOrd: Integer; const TypeName: string): string;
begin
  case TypeOrd of
    -1: Result := TypeName;
    RT_CURSOR_ID: Result := 'Cursor Image';
    RT_BITMAP_ID: Result := 'Bitmap';
    RT_ICON_ID: Result := 'Icon Image';
    4: Result := 'Menu';
    5: Result := 'Dialog';
    RT_STRING_ID: Result := 'String Table';
    7: Result := 'Font Directory';
    8: Result := 'Font';
    9: Result := 'Accelerators';
    RT_RCDATA_ID: Result := 'RCDATA';
    11: Result := 'Message Table';
    RT_GROUP_CURSOR_ID: Result := 'Cursor';
    RT_GROUP_ICON_ID: Result := 'Icon';
    RT_VERSION_ID: Result := 'Version';
    17: Result := 'Dialog Include';
    19: Result := 'Plug and Play';
    20: Result := 'VxD';
    21: Result := 'Animated Cursor';
    22: Result := 'Animated Icon';
    23: Result := 'HTML';
    RT_MANIFEST_ID: Result := 'Manifest';
  else
    Result := '#' + IntToStr(TypeOrd);
  end;
end;

function ResKindText(Kind: TSdResKind): string;
const
  Texts: array[TSdResKind] of string = ('Bitmap', 'Icon', 'Cursor', 'String Table', 'Version',
    'Manifest', 'Data');
begin
  Result := Texts[Kind];
end;

{ a locale's name in the IDE's text (GetLocaleInfoA ignores the UTF-8 code page) }
function LocaleName(Lcid: Integer): string;
var
  Buf: array[0..127] of WideChar;
  Lost: Boolean;
begin
  Result := '';
  if GetLocaleInfoW(Lcid, LOCALE_SLANGUAGE, Buf, Length(Buf)) > 0 then
    Result := FromWide(WideString(Buf), CP_ACP, Lost);
end;

function LanguageText(Language: Integer): string;
begin
  if Language = 0 then Result := 'Neutral'
  { the neutral language with a default sublanguage: the locale functions answer the user's or the
    system's language for it }
  else if Language and $3FF = 0 then Result := 'Neutral ($' + IntToHex(Language, 4) + ')'
  else
  begin
    Result := LocaleName(Language);
    if Result = '' then Result := '$' + IntToHex(Language, 4);
  end;
end;

var
  LocaleList: TStringList;

function EnumLocale(S: PChar): BOOL; stdcall;
var
  Id: Integer;
  N: string;
begin
  Id := StrToIntDef('$' + StrPas(S), 0);
  N := LocaleName(Id);
  if (Id <> 0) and (N <> '') and (LocaleList.IndexOf(N) < 0) then LocaleList.AddObject(N, TObject(Id));
  Result := True;
end;

procedure GetLanguages(L: TStrings);
begin
  LocaleList := TStringList.Create;
  try
    EnumSystemLocales(@EnumLocale, LCID_SUPPORTED);
    LocaleList.Sort;
    L.Clear;
    L.AddObject('Neutral', TObject(0));
    L.AddStrings(LocaleList);
  finally
    FreeAndNil(LocaleList);
  end;
end;

function IsTextData(const Data: string): Boolean;
begin
  Result := (Data <> '') and (Pos(#0, Data) = 0) and IsValidUtf8(Data);
end;

function NameText(Ord: Integer; const Name: string): string;
begin
  if Ord >= 0 then Result := IntToStr(Ord) else Result := Name;
end;

{ a type or name typed by the user: digits an ordinal, else a name (in capitals, as resource
  compilers keep them) }
procedure ParseId(const S: string; var Ord: Integer; var Name: string);
var
  V, Code: Integer;
begin
  Val(Trim(S), V, Code);
  if (Code = 0) and (V > 0) and (V <= $FFFF) then
  begin
    Ord := V;
    Name := '';
  end
  else
  begin
    Ord := -1;
    Name := UpperCase(Trim(S));
  end;
end;

{ a type typed by the user: the name of a standard type (as ResTypeText gives it, or as resource
  scripts write it) is its ordinal }
procedure ParseType(const S: string; var Ord: Integer; var Name: string);
const
  Keywords: array[0..5] of string = ('CURSOR', 'BITMAP', 'ICON', 'MENU', 'DIALOG', 'STRINGTABLE');
var
  I, V, Code: Integer;
  T: string;
begin
  T := Trim(S);
  for I := 1 to RT_MANIFEST_ID do
    if SameText(T, ResTypeText(I, '')) or ((I <= 6) and SameText(T, Keywords[I - 1])) then
    begin
      Ord := I;
      Name := '';
      Exit;
    end;
  { an ordinal as ResTypeText writes one without a name: #30 }
  if (Length(T) > 1) and (T[1] = '#') then
  begin
    Val(Copy(T, 2, MaxInt), V, Code);
    if (Code = 0) and (V > 0) and (V <= $FFFF) then
    begin
      Ord := V;
      Name := '';
      Exit;
    end;
  end;
  ParseId(T, Ord, Name);
end;

function EntryLanguage(const E: IOTAResourceEntry): Integer;
begin
  if not E.GetHeaderValue(hvLanguage, Result) then Result := 0;
  Result := Result and $FFFF;
end;

function EntryData(const E: IOTAResourceEntry): string;
begin
  SetString(Result, PChar(E.GetData), E.GetDataSize);
end;

{ the type of a kind's entry (an icon's and a cursor's: the group's) }
function KindType(Kind: TSdResKind): Integer;
begin
  case Kind of
    rkBitmap: Result := RT_BITMAP_ID;
    rkIcon: Result := RT_GROUP_ICON_ID;
    rkCursor: Result := RT_GROUP_CURSOR_ID;
    rkStrings: Result := RT_STRING_ID;
    rkVersion: Result := RT_VERSION_ID;
    rkManifest: Result := RT_MANIFEST_ID;
  else
    Result := RT_RCDATA_ID;
  end;
end;

{ the type of the images of a group of Kind (rkIcon, rkCursor) }
function ImageType(Kind: TSdResKind): Integer;
begin
  if Kind = rkCursor then Result := RT_CURSOR_ID else Result := RT_ICON_ID;
end;

{ ---------------------------------------------------------------- TSdResItem }

function TSdResItem.TypeText: string;
begin
  Result := ResTypeText(TypeOrd, TypeName);
end;

function TSdResItem.NameText: string;
begin
  if Kind = rkStrings then Result := LanguageText(Language)
  else Result := SdResources.NameText(NameOrd, Name);
end;

function ResKey(TypeOrd: Integer; const TypeName: string; NameOrd: Integer; const Name: string;
  Language: Integer): string;
begin
  Result := Format('%d:%s|%d:%s|%d', [TypeOrd, TypeName, NameOrd, Name, Language]);
end;

function StringTableKey(Language: Integer): string;
begin
  Result := ResKey(RT_STRING_ID, '', -1, '', Language);
end;

function ResImageKind(Kind: TSdResKind): TSdImageKind;
begin
  case Kind of
    rkIcon: Result := ikIcon;
    rkCursor: Result := ikCursor;
  else
    Result := ikBitmap;
  end;
end;

function TSdResItem.Key: string;
begin
  Result := ResKey(TypeOrd, TypeName, NameOrd, Name, Language);
end;

{ ---------------------------------------------------------------- TSdResources }

constructor TSdResources.Create(const AProjectFile: string);
begin
  inherited Create;
  FProjectFile := AProjectFile;
  FItems := TList.Create;
end;

constructor TSdResources.CreateOn(const AProjectFile: string; const ARes: IOTAProjectResource);
begin
  Create(AProjectFile);
  FRes := ARes;
end;

destructor TSdResources.Destroy;
begin
  Clear;
  FreeAndNil(FItems);
  inherited Destroy;
end;

procedure TSdResources.Clear;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do TObject(FItems[I]).Free;
  FItems.Clear;
end;

function TSdResources.Res: IOTAProjectResource;
begin
  if FRes <> nil then Result := FRes else Result := OtaModules.ProjectResource(FProjectFile);
end;

function TSdResources.ResFile: string;
begin
  Result := ChangeFileExt(FProjectFile, '.res');
end;

function TSdResources.Count: Integer;
begin
  Result := FItems.Count;
end;

function TSdResources.Item(Index: Integer): TSdResItem;
begin
  Result := TSdResItem(FItems[Index]);
end;

function TSdResources.FindKey(const Key: string): TSdResItem;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
  begin
    Result := Item(I);
    if Result.Key = Key then Exit;
  end;
  Result := nil;
end;

function TSdResources.FindKind(Kind: TSdResKind; Language: Integer): TSdResItem;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
  begin
    Result := Item(I);
    if (Result.Kind = Kind) and ((Language < 0) or (Result.Language = Language)) then Exit;
  end;
  Result := nil;
end;

{ the order of the view: the kinds as Visual Studio's Resource View sorts them, then other types
  by name; in a type the ordinals first }
function CompareItems(A, B: Pointer): Integer;
var
  X, Y: TSdResItem;

  function Rank(It: TSdResItem): Integer;
  begin
    Result := Ord(It.Kind);
    if (It.Kind = rkData) and (It.TypeOrd = RT_RCDATA_ID) then Dec(Result);
  end;

begin
  X := A;
  Y := B;
  Result := Rank(X) - Rank(Y);
  if Result = 0 then Result := CompareText(X.TypeText, Y.TypeText);
  if Result = 0 then
    if (X.NameOrd >= 0) and (Y.NameOrd >= 0) then Result := X.NameOrd - Y.NameOrd
    else if X.NameOrd >= 0 then Result := -1
    else if Y.NameOrd >= 0 then Result := 1
    else Result := CompareText(X.Name, Y.Name);
  if Result = 0 then Result := X.Language - Y.Language;
end;

function VersionDetail(const Data: string): string;
var
  I: Integer;
  MS, LS: Cardinal;
begin
  Result := '';
  for I := 1 to Length(Data) - 15 do          // the signature and the two version words after it
    if (Data[I] = #$BD) and (Copy(Data, I, 4) = #$BD#$04#$EF#$FE) then
    begin
      Move(Data[I + 8], MS, 4);
      Move(Data[I + 12], LS, 4);
      Result := Format('%d.%d.%d.%d', [MS shr 16, MS and $FFFF, LS shr 16, LS and $FFFF]);
      Exit;
    end;
end;

function BytesText(N: Integer): string;
begin
  if N = 1 then Result := '1 byte' else Result := FormatFloat('#,##0', N) + ' bytes';
end;

procedure TSdResources.Refresh;
var
  R: IOTAProjectResource;
  E: IOTAResourceEntry;
  I, J, Lang, TOrd, NOrd: Integer;
  TName, NName, D: string;
  It: TSdResItem;
  Used: TList;
  Entries: TSdIconEntries;
  Ids: TSdIds;
  Strings: TSdStringItems;
  Img: TSdImage;
  Sizes: string;
begin
  Clear;
  { a file that is no 32-bit .res (a 16-bit one): the model reads nothing, and writing would lose
    it }
  FCanWrite := not FileExists(ResFile) or ValidResFile(ResFile);
  if not FCanWrite then Exit;
  R := Res;
  Used := TList.Create;
  try
    { the images the groups use are no items of their own }
    for I := 0 to R.GetEntryCount - 1 do
    begin
      E := R.GetEntry(I);
      SplitResId(E.GetResourceType, TOrd, TName);
      if (TOrd = RT_GROUP_ICON_ID) or (TOrd = RT_GROUP_CURSOR_ID) then
        if ReadGroupDir(EntryData(E), TOrd = RT_GROUP_CURSOR_ID, Entries, Ids) then
          for J := 0 to High(Ids) do
            Used.Add(Pointer((Ord(TOrd = RT_GROUP_CURSOR_ID) shl 16) or Ids[J]));
    end;
    for I := 0 to R.GetEntryCount - 1 do
    begin
      E := R.GetEntry(I);
      SplitResId(E.GetResourceType, TOrd, TName);
      SplitResId(E.GetResourceName, NOrd, NName);
      Lang := EntryLanguage(E);
      if ((TOrd = RT_ICON_ID) and (Used.IndexOf(Pointer(NOrd)) >= 0)) or
        ((TOrd = RT_CURSOR_ID) and (Used.IndexOf(Pointer($10000 or NOrd)) >= 0)) then Continue;
      if TOrd = RT_STRING_ID then
      begin
        { the blocks of a language are one table }
        It := FindKind(rkStrings, Lang);
        if It <> nil then
        begin
          Inc(It.Size, E.GetDataSize);
          Continue;
        end;
      end;
      It := TSdResItem.Create;
      FItems.Add(It);
      It.TypeOrd := TOrd;
      It.TypeName := TName;
      It.NameOrd := NOrd;
      It.Name := NName;
      It.Language := Lang;
      It.Size := E.GetDataSize;
      case TOrd of
        RT_BITMAP_ID: It.Kind := rkBitmap;
        RT_GROUP_ICON_ID: It.Kind := rkIcon;
        RT_GROUP_CURSOR_ID: It.Kind := rkCursor;
        RT_STRING_ID:
          begin
            It.Kind := rkStrings;
            It.NameOrd := -1;
            It.Name := '';
          end;
        RT_VERSION_ID: It.Kind := rkVersion;
        RT_MANIFEST_ID: It.Kind := rkManifest;
      else
        It.Kind := rkData;
      end;
    end;
    FItems.Sort(CompareItems);
    { the second column }
    for I := 0 to Count - 1 do
    begin
      It := Item(I);
      D := '';
      try
        case It.Kind of
          rkBitmap:
            begin
              Img := ReadBitmap(It);
              try
                D := Format('%d x %d, %s', [Img.Width, Img.Height, BitCountText(Img.BitCount)]);
              finally
                Img.Free;
              end;
            end;
          rkIcon, rkCursor:
            begin
              GroupImages(It, Entries, Ids);
              Sizes := '';
              for J := 0 to High(Entries) do
              begin
                if Sizes <> '' then Sizes := Sizes + ', ';
                Sizes := Sizes + IntToStr(Entries[J].Width);
                if Entries[J].Height <> Entries[J].Width then Sizes := Sizes + 'x' + IntToStr(Entries[J].Height);
              end;
              if Length(Entries) = 1 then D := '1 image: ' else D := IntToStr(Length(Entries)) + ' images: ';
              D := D + Sizes;
              for J := 0 to High(Entries) do Inc(It.Size, EntryResSize(Entries[J], It.Kind = rkCursor));
            end;
          rkStrings:
            begin
              ReadStrings(It.Language, Strings);
              if Length(Strings) = 1 then D := '1 string' else D := IntToStr(Length(Strings)) + ' strings';
            end;
          rkVersion:
            D := VersionDetail(Data(It));
          rkManifest:
            begin
              It.IdeManifest := IsIdeManifest(Data(It));
              if It.IdeManifest then D := 'D7 Studio''s (Project | Options | Application)'
              else D := BytesText(It.Size);
            end;
        else
          D := BytesText(It.Size);
        end;
      except
        on Ex: Exception do D := Ex.Message;
      end;
      if (It.Language <> 0) and (It.Kind <> rkStrings) then D := D + ' - ' + LanguageText(It.Language);
      It.Detail := D;
    end;
  finally
    Used.Free;
  end;
end;

function TSdResources.Find(TypeOrd: Integer; const TypeName: string; NameOrd: Integer;
  const Name: string; Language: Integer): IOTAResourceEntry;
var
  R: IOTAProjectResource;
  I, TO2, NO2: Integer;
  TN2, NN2: string;
begin
  R := Res;
  for I := 0 to R.GetEntryCount - 1 do
  begin
    Result := R.GetEntry(I);
    SplitResId(Result.GetResourceType, TO2, TN2);
    SplitResId(Result.GetResourceName, NO2, NN2);
    if (TO2 = TypeOrd) and SameText(TN2, TypeName) and (NO2 = NameOrd) and SameText(NN2, Name) and
      ((Language < 0) or (EntryLanguage(Result) = Language)) then Exit;
  end;
  Result := nil;
end;

function TSdResources.Entry(It: TSdResItem): IOTAResourceEntry;
begin
  Result := Find(It.TypeOrd, It.TypeName, It.NameOrd, It.Name, It.Language);
end;

function TSdResources.Data(It: TSdResItem): string;
var
  E: IOTAResourceEntry;
begin
  Result := '';
  if It.Kind = rkStrings then Exit;
  E := Entry(It);
  if E <> nil then Result := EntryData(E);
end;

{ the model writes the file after each change and says nothing when it cannot (its error goes to
  error.log): a change it still holds was not written }
procedure TSdResources.CheckWritten;
begin
  if Res.GetModified then
    raise EInOutError.CreateFmt('%s cannot be written. The change is kept and written with the next compile.',
      [ExtractFileName(ResFile)]);
end;

procedure TSdResources.BeginWrite;
var
  F: ISdResFile;
begin
  if Supports(Res, ISdResFile, F) then F.BeginUpdate;
end;

procedure TSdResources.EndWrite;
var
  F: ISdResFile;
begin
  if Supports(Res, ISdResFile, F) then F.EndUpdate;
end;

procedure TSdResources.SetData(const E: IOTAResourceEntry; const Data: string);
begin
  E.SetDataSize(Length(Data));
  if Data <> '' then Move(Data[1], E.GetData^, Length(Data));
  Res.MarkModified;
end;

function TSdResources.NewEntry(TypeOrd: Integer; const TypeName: string; NameOrd: Integer;
  const Name: string; Language: Integer; Flags: Word; const Data: string): IOTAResourceEntry;
begin
  { an ordinal is a word (ResId: a larger one would be taken for a pointer) }
  if NameOrd > $FFFF then raise EResImage.Create('There is no free id left for a new entry.');
  Result := Res.CreateEntry(ResIdPtr(TypeOrd, TypeName), ResIdPtr(NameOrd, Name), Flags, Language, 0, 0, 0);
  if Result = nil then
    raise EResImage.CreateFmt('There is a resource %s %s already.',
      [ResTypeText(TypeOrd, TypeName), NameText(NameOrd, Name)]);
  SetData(Result, Data);
end;

function TSdResources.NextId(TypeOrd: Integer): Integer;
var
  R: IOTAProjectResource;
  I, TOrd, NOrd: Integer;
  TName, NName: string;
begin
  Result := 1;
  R := Res;
  for I := 0 to R.GetEntryCount - 1 do
  begin
    SplitResId(R.GetEntry(I).GetResourceType, TOrd, TName);
    SplitResId(R.GetEntry(I).GetResourceName, NOrd, NName);
    if (TOrd = TypeOrd) and (NOrd >= Result) then Result := NOrd + 1;
  end;
end;

{ the entries of a group's images, with their data }
procedure TSdResources.GroupImages(It: TSdResItem; var Entries: TSdIconEntries; var Ids: TSdIds);
var
  Cursor: Boolean;
  ImgType, I: Integer;
  E: IOTAResourceEntry;
begin
  Cursor := It.Kind = rkCursor;
  ImgType := ImageType(It.Kind);
  if not ReadGroupDir(Data(It), Cursor, Entries, Ids) then
    raise EResImage.Create('The directory of the group cannot be read.');
  { a group no image of which is listed (written by another tool): nothing an editor could show }
  if Length(Entries) = 0 then raise EResImage.Create('The group has no images.');
  for I := 0 to High(Entries) do
  begin
    E := FindImage(ImgType, Ids[I], It.Language);
    if E = nil then raise EResImage.CreateFmt('The image %d of the group is missing.', [Ids[I]]);
    SetEntryResData(Entries[I], EntryData(E), Cursor);
  end;
end;

{ an image of a group: the one in the group's language, else one in any }
function TSdResources.FindImage(ImgType, Id, Language: Integer): IOTAResourceEntry;
begin
  Result := Find(ImgType, '', Id, '', Language);
  if Result = nil then Result := Find(ImgType, '', Id, '', -1);
end;

function TSdResources.UsedByOtherGroup(Group: TSdResItem; Id: Integer): Boolean;
var
  I, J: Integer;
  It: TSdResItem;
  Entries: TSdIconEntries;
  Ids: TSdIds;
begin
  Result := False;
  for I := 0 to Count - 1 do
  begin
    It := Item(I);
    if (It = Group) or (It.Kind <> Group.Kind) then Continue;
    if ReadGroupDir(Data(It), It.Kind = rkCursor, Entries, Ids) then
      for J := 0 to High(Ids) do
        if Ids[J] = Id then
        begin
          Result := True;
          Exit;
        end;
  end;
end;

{ the images of a group out, but those another group uses; their ids in Freed }
procedure TSdResources.DeleteGroupImages(It: TSdResItem; var Freed: TSdIds);
var
  Entries: TSdIconEntries;
  Ids: TSdIds;
  ImgType, I: Integer;
  E: IOTAResourceEntry;
begin
  Freed := nil;
  ImgType := ImageType(It.Kind);
  if not ReadGroupDir(Data(It), It.Kind = rkCursor, Entries, Ids) then Exit;
  for I := 0 to High(Ids) do
  begin
    if UsedByOtherGroup(It, Ids[I]) then Continue;
    E := FindImage(ImgType, Ids[I], It.Language);
    if E <> nil then Res.DeleteEntry(E.GetEntryHandle);
    SetLength(Freed, Length(Freed) + 1);
    Freed[High(Freed)] := Ids[I];
  end;
end;

function TSdResources.ReadBitmap(It: TSdResItem): TSdImage;
begin
  Result := DibToImage(Data(It), False);
end;

procedure TSdResources.ReadImages(It: TSdResItem; Images: TList);
var
  Entries: TSdIconEntries;
  Ids: TSdIds;
  I: Integer;
begin
  GroupImages(It, Entries, Ids);
  for I := 0 to High(Entries) do Images.Add(EntryToImage(Entries[I]));
end;

procedure TSdResources.WriteBitmap(It: TSdResItem; Img: TSdImage);
begin
  WriteData(It, ImageToDib(Img, False));
end;

procedure TSdResources.WriteData(It: TSdResItem; const Data: string);
var
  E: IOTAResourceEntry;
begin
  E := Entry(It);
  if E = nil then raise EResImage.Create('The resource is no longer there.');
  BeginWrite;
  try
    SetData(E, Data);
  finally
    EndWrite;
  end;
  CheckWritten;
end;

{ the group's images written: the old ones go (their ids are taken again first), then the new
  ones and the directory - the images are encoded and the ids chosen before anything changes }
procedure TSdResources.WriteImages(It: TSdResItem; Images: TList);
var
  Entries: TSdIconEntries;
  Ids, Freed: TSdIds;
  Cursor: Boolean;
  ImgType, I, Next: Integer;
  E: IOTAResourceEntry;
begin
  E := Entry(It);
  if E = nil then raise EResImage.Create('The resource is no longer there.');
  Cursor := It.Kind = rkCursor;
  ImgType := ImageType(It.Kind);
  SetLength(Entries, Images.Count);
  SetLength(Ids, Images.Count);
  for I := 0 to Images.Count - 1 do Entries[I] := ImageToEntry(TSdImage(Images[I]));
  { the first new id after every one there now, the old images' too: those are taken again first }
  BeginWrite;
  try
    Next := NextId(ImgType);
    DeleteGroupImages(It, Freed);
    for I := 0 to High(Ids) do
    begin
      if I <= High(Freed) then Ids[I] := Freed[I]
      else
      begin
        Ids[I] := Next;
        Inc(Next);
      end;
      NewEntry(ImgType, '', Ids[I], '', It.Language, FlagsImage, EntryResData(Entries[I], Cursor));
    end;
    SetData(E, MakeGroupDir(Entries, Ids, Cursor));
  finally
    EndWrite;
  end;
  CheckWritten;
end;

function TSdResources.AddBitmap(const Name: string; Img: TSdImage): string;
var
  NOrd: Integer;
  NName: string;
begin
  ParseId(Name, NOrd, NName);
  BeginWrite;
  try
    NewEntry(RT_BITMAP_ID, '', NOrd, NName, 0, FlagsDefault, ImageToDib(Img, False));
  finally
    EndWrite;
  end;
  CheckWritten;
  Result := ResKey(RT_BITMAP_ID, '', NOrd, NName, 0);
end;

function TSdResources.AddImages(Kind: TSdResKind; const Name: string; Images: TList): string;
var
  Entries: TSdIconEntries;
  I: Integer;
begin
  SetLength(Entries, Images.Count);
  for I := 0 to Images.Count - 1 do Entries[I] := ImageToEntry(TSdImage(Images[I]));
  Result := AddEntries(Kind, Name, Entries);
end;

{ a new group: its images under new ids, then the directory }
function TSdResources.AddEntries(Kind: TSdResKind; const Name: string; const Entries: TSdIconEntries): string;
var
  Ids: TSdIds;
  Cursor: Boolean;
  GroupType, ImgType, First, I, NOrd: Integer;
  NName: string;
begin
  Cursor := Kind = rkCursor;
  GroupType := KindType(Kind);
  ImgType := ImageType(Kind);
  ParseId(Name, NOrd, NName);
  if Find(GroupType, '', NOrd, NName, 0) <> nil then
    raise EResImage.CreateFmt('There is a resource %s %s already.', [ResKindText(Kind), Name]);
  SetLength(Ids, Length(Entries));
  BeginWrite;
  try
    First := NextId(ImgType);
    for I := 0 to High(Entries) do
    begin
      Ids[I] := First + I;
      NewEntry(ImgType, '', Ids[I], '', 0, FlagsImage, EntryResData(Entries[I], Cursor));
    end;
    NewEntry(GroupType, '', NOrd, NName, 0, FlagsDefault, MakeGroupDir(Entries, Ids, Cursor));
  finally
    EndWrite;
  end;
  CheckWritten;
  Result := ResKey(GroupType, '', NOrd, NName, 0);
end;

function TSdResources.AddData(TypeOrd: Integer; const TypeName, Name: string; const Data: string): string;
var
  NOrd: Integer;
  NName: string;
begin
  ParseId(Name, NOrd, NName);
  BeginWrite;
  try
    NewEntry(TypeOrd, TypeName, NOrd, NName, 0, FlagsDefault, Data);
  finally
    EndWrite;
  end;
  CheckWritten;
  Result := ResKey(TypeOrd, TypeName, NOrd, NName, 0);
end;

{ ---------------------------------------------------------------- string tables }

procedure TSdResources.ReadStrings(Language: Integer; var Items: TSdStringItems);
var
  R: IOTAProjectResource;
  E: IOTAResourceEntry;
  I, J, P, Len, TOrd, NOrd, N: Integer;
  TName, NName, D: string;
  W: WideString;
begin
  Items := nil;
  N := 0;
  R := Res;
  for I := 0 to R.GetEntryCount - 1 do
  begin
    E := R.GetEntry(I);
    SplitResId(E.GetResourceType, TOrd, TName);
    SplitResId(E.GetResourceName, NOrd, NName);
    if (TOrd <> RT_STRING_ID) or (NOrd < 1) or (EntryLanguage(E) <> Language) then Continue;
    D := EntryData(E);
    P := 1;
    for J := 0 to 15 do
    begin
      if P + 1 > Length(D) then Break;
      Len := Ord(D[P]) + Ord(D[P + 1]) shl 8;
      Inc(P, 2);
      if Len > 0 then
      begin
        SetLength(W, Len);
        if P + Len * 2 - 1 <= Length(D) then Move(D[P], W[1], Len * 2) else W := '';
        SetLength(Items, N + 1);
        Items[N].Id := (NOrd - 1) * 16 + J;
        Items[N].Text := W;
        Inc(N);
      end;
      Inc(P, Len * 2);
    end;
  end;
  { by id }
  for I := 1 to N - 1 do
    for J := I downto 1 do
      if Items[J].Id < Items[J - 1].Id then
      begin
        P := Items[J].Id;
        W := Items[J].Text;
        Items[J] := Items[J - 1];
        Items[J - 1].Id := P;
        Items[J - 1].Text := W;
      end
      else
        Break;
end;

function TSdResources.WriteStrings(Language: Integer; const Items: TSdStringItems): string;
var
  R: IOTAProjectResource;
  E: IOTAResourceEntry;
  Blocks: array of string;
  Used: array of Boolean;
  Texts: array of WideString;
  I, J, B, MaxBlock, TOrd, NOrd: Integer;
  TName, NName, D: string;
  W: WideString;
begin
  Result := '';
  MaxBlock := 0;
  for I := 0 to High(Items) do
    if Items[I].Id div 16 + 1 > MaxBlock then MaxBlock := Items[I].Id div 16 + 1;
  { the texts by id, in one pass (of two items of an id the later one's), the blocks from them }
  SetLength(Texts, MaxBlock * 16);
  for I := 0 to High(Items) do
    if (Items[I].Id >= 0) and (Items[I].Id < MaxBlock * 16) then Texts[Items[I].Id] := Items[I].Text;
  SetLength(Blocks, MaxBlock + 1);
  SetLength(Used, MaxBlock + 1);
  for B := 1 to MaxBlock do
  begin
    D := '';
    for J := 0 to 15 do
    begin
      W := Texts[(B - 1) * 16 + J];
      if W <> '' then Used[B] := True;
      D := D + Chr(Length(W) and $FF) + Chr(Length(W) shr 8);
      if W <> '' then
      begin
        SetLength(NName, Length(W) * 2);
        Move(W[1], NName[1], Length(W) * 2);
        D := D + NName;
      end;
    end;
    Blocks[B] := D;
  end;
  R := Res;
  BeginWrite;
  try
    { the blocks of the language there: written again, or out }
    for I := R.GetEntryCount - 1 downto 0 do
    begin
      E := R.GetEntry(I);
      SplitResId(E.GetResourceType, TOrd, TName);
      SplitResId(E.GetResourceName, NOrd, NName);
      if (TOrd <> RT_STRING_ID) or (EntryLanguage(E) <> Language) then Continue;
      if (NOrd >= 1) and (NOrd <= MaxBlock) and Used[NOrd] then
      begin
        SetData(E, Blocks[NOrd]);
        Used[NOrd] := False;
      end
      else
        R.DeleteEntry(E.GetEntryHandle);
    end;
    for B := 1 to MaxBlock do
      if Used[B] then NewEntry(RT_STRING_ID, '', B, '', Language, FlagsDefault, Blocks[B]);
  finally
    EndWrite;
  end;
  CheckWritten;
  if Length(Items) > 0 then Result := StringTableKey(Language);
end;

{ ---------------------------------------------------------------- delete, rename }

procedure TSdResources.Delete(It: TSdResItem);
var
  R: IOTAProjectResource;
  E: IOTAResourceEntry;
  Freed: TSdIds;
  I, TOrd: Integer;
  TName: string;
begin
  R := Res;
  BeginWrite;
  try
    if It.Kind = rkStrings then
    begin
      for I := R.GetEntryCount - 1 downto 0 do
      begin
        E := R.GetEntry(I);
        SplitResId(E.GetResourceType, TOrd, TName);
        if (TOrd = RT_STRING_ID) and (EntryLanguage(E) = It.Language) then R.DeleteEntry(E.GetEntryHandle);
      end;
    end
    else
    begin
      if It.Kind in [rkIcon, rkCursor] then DeleteGroupImages(It, Freed);
      E := Entry(It);
      if E <> nil then R.DeleteEntry(E.GetEntryHandle);
    end;
  finally
    EndWrite;
  end;
  CheckWritten;
end;

function TSdResources.Taken(It: TSdResItem; const AType, AName: string; Language: Integer): Boolean;
var
  TOrd, NOrd: Integer;
  TName, NName: string;
begin
  if (It <> nil) and (It.Kind <> rkData) then
  begin
    TOrd := It.TypeOrd;
    TName := It.TypeName;
  end
  else
    ParseType(AType, TOrd, TName);
  ParseId(AName, NOrd, NName);
  Result := (Find(TOrd, TName, NOrd, NName, Language) <> nil) and
    ((It = nil) or not ((TOrd = It.TypeOrd) and SameText(TName, It.TypeName) and (NOrd = It.NameOrd) and
     SameText(NName, It.Name) and (Language = It.Language)));
end;

function TSdResources.Rename(It: TSdResItem; const NewType, NewName: string; NewLanguage: Integer): string;
var
  R: IOTAProjectResource;
  E: IOTAResourceEntry;
  TOrd, NOrd, I: Integer;
  TName, NName: string;
begin
  Result := '';
  R := Res;
  if It.Kind = rkStrings then
  begin
    { a table: its blocks in the other language }
    if FindKind(rkStrings, NewLanguage) <> nil then Exit;
    BeginWrite;
    try
      for I := 0 to R.GetEntryCount - 1 do
      begin
        E := R.GetEntry(I);
        SplitResId(E.GetResourceType, TOrd, TName);
        if (TOrd = RT_STRING_ID) and (EntryLanguage(E) = It.Language) then E.SetHeaderValue(hvLanguage, NewLanguage);
      end;
    finally
      EndWrite;
    end;
    CheckWritten;
    Result := StringTableKey(NewLanguage);
    Exit;
  end;
  if It.Kind = rkData then ParseType(NewType, TOrd, TName)
  else
  begin
    TOrd := It.TypeOrd;
    TName := It.TypeName;
  end;
  ParseId(NewName, NOrd, NName);
  if Taken(It, NewType, NewName, NewLanguage) then Exit;
  E := Entry(It);
  if E = nil then raise EResImage.Create('The resource is no longer there.');
  BeginWrite;
  try
    E.Change(ResIdPtr(TOrd, TName), ResIdPtr(NOrd, NName));
    if NewLanguage <> It.Language then E.SetHeaderValue(hvLanguage, NewLanguage);
  finally
    EndWrite;
  end;
  CheckWritten;
  Result := ResKey(TOrd, TName, NOrd, NName, NewLanguage);
end;

{ ---------------------------------------------------------------- files }

function TSdResources.ExportData(It: TSdResItem; var Ext: string): string;
var
  Entries: TSdIconEntries;
  Ids: TSdIds;
begin
  case It.Kind of
    rkBitmap:
      begin
        Ext := '.bmp';
        Result := DibToBmpFile(Data(It));
      end;
    rkIcon, rkCursor:
      begin
        if It.Kind = rkCursor then Ext := '.cur' else Ext := '.ico';
        GroupImages(It, Entries, Ids);
        Result := WriteIconFile(Entries, It.Kind = rkCursor);
      end;
    rkManifest:
      begin
        Ext := '.manifest';
        Result := Data(It);
      end;
  else
    begin
      Result := Data(It);
      if IsPng(Result) then Ext := '.png'
      else if IsTextData(Result) then Ext := '.txt'
      else Ext := '.bin';
    end;
  end;
end;

function TSdResources.Import(const FileName, Bytes: string): string;
var
  Ext, Dib: string;
  Cursor: Boolean;
  Entries: TSdIconEntries;
  Kind: TSdResKind;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  if Ext = '.bmp' then
  begin
    Dib := BmpFileToDib(Bytes);
    if Dib = '' then raise EResImage.CreateFmt('%s is not a bitmap.', [ExtractFileName(FileName)]);
    DibToImage(Dib, False).Free;                 // raises when it cannot be read
    Result := AddData(RT_BITMAP_ID, '', NewName(rkBitmap, FileName), Dib);
  end
  else if (Ext = '.ico') or (Ext = '.cur') then
  begin
    if not ReadIconFile(Bytes, Cursor, Entries) or (Cursor <> (Ext = '.cur')) then
      raise EResImage.CreateFmt('%s is not a valid %s file.', [ExtractFileName(FileName), Copy(Ext, 2, 3)]);
    if Cursor then Kind := rkCursor else Kind := rkIcon;
    Result := AddEntries(Kind, NewName(Kind, FileName), Entries);
  end
  else if Ext = '.manifest' then
  begin
    if FindKind(rkManifest) <> nil then
      raise EResImage.Create('The project has a manifest already: edit it, or delete it first.');
    Result := AddData(RT_MANIFEST_ID, '', '1', Bytes);
  end
  else
    Result := AddData(RT_RCDATA_ID, '', NewName(rkData, FileName), Bytes);
end;

function TSdResources.NewName(Kind: TSdResKind; const Base: string): string;
const
  Prefix: array[TSdResKind] of string = ('BITMAP', 'ICON', 'CURSOR', 'STRINGS', 'VERSION', 'MANIFEST', 'DATA');
var
  Stem: string;
  I, N: Integer;
begin
  { a file's name without its folder and extension, in what a name may hold }
  Stem := UpperCase(ChangeFileExt(ExtractFileName(Base), ''));
  for I := 1 to Length(Stem) do
    if not (Stem[I] in ['A'..'Z', '0'..'9', '_']) then Stem[I] := '_';
  if (Stem <> '') and (Stem[1] in ['0'..'9']) then Stem := '_' + Stem;
  if Stem <> '' then
  begin
    Result := Stem;
    N := 2;
    while Find(KindType(Kind), '', -1, Result, -1) <> nil do
    begin
      Result := Stem + '_' + IntToStr(N);
      Inc(N);
    end;
  end
  else
  begin
    N := 1;
    repeat
      Result := Prefix[Kind] + IntToStr(N);
      Inc(N);
    until Find(KindType(Kind), '', -1, Result, -1) = nil;
  end;
end;

function TSdResources.CheckName(const S, What: string): string;
var
  T: string;
  V, Code, I: Integer;
begin
  Result := '';
  T := Trim(S);
  if T = '' then
  begin
    Result := What + ' is empty.';
    Exit;
  end;
  Val(T, V, Code);
  if Code = 0 then
  begin
    if (V < 1) or (V > $FFFF) then Result := What + ' must be a number from 1 to 65535, or a name.';
    Exit;
  end;
  if T[1] in ['0'..'9'] then
  begin
    Result := What + ' is a number from 1 to 65535, or a name that does not begin with a digit.';
    Exit;
  end;
  for I := 1 to Length(T) do
    if not (T[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.', '-']) then
    begin
      Result := What + ' may contain letters, digits and _ . - only.';
      Exit;
    end;
end;

function TSdResources.CheckType(const S: string): string;
var
  Ord: Integer;
  Name: string;
begin
  ParseType(S, Ord, Name);
  if Ord >= 0 then Result := '' else Result := CheckName(S, 'The type');
end;

end.
