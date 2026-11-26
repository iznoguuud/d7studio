{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdTypeLibViewFrame;

{ D7 Studio - the Type Library view (View | Type Library): a type
  library - a project's .tlb, or any file that holds one (.tlb, .olb, .dll, .ocx, .exe) - as
  Delphi 7's Type Library editor shows it, to read: on one side the library and its types
  (interfaces, dispinterfaces, CoClasses, enumerations, records, unions, aliases, modules), each
  with its members when it is opened; on the other the chosen one's kind and name, its
  Attributes (GUID, version, help string, flags, its ancestor or interfaces, a member's dispid
  and kind) and its Text: the Pascal the importer writes for it (SdTypeLib), the whole unit for
  the library. A type's members are added when it is first expanded (MSHTML has thousands of
  types). }

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, ComCtrls, ActiveX, Menus, ActnList,
  SdIcons, SdTabStrip, SdSplitViewFrame, SdSciEdit, SdTypeLib;

type
  { a frame inherited from the split view's (SdTypeLibViewFrame.dfm: the library's tree, the
    attributes and their events), made by the main form (CreatePanes); the text, an editor (not a
    standard VCL control), and the tabs are made in code }
  TSdTypeLibView = class(TSdSplitView)
    LibTree: TTreeView;
    AttrList: TListView;
    MenuActions: TActionList;
    aTlOpen: TAction;
    aTlExport: TAction;
    aTlRefresh: TAction;
    TypeLibPopup: TPopupMenu;
    pmTl1: TMenuItem;
    pmTl2: TMenuItem;
    pmTl3: TMenuItem;
    procedure TreeChange(Sender: TObject; Node: TTreeNode);
    procedure TreeExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
  private
    FTL: ITypeLib;
    FFile: string;
    FTabs: TSdTabStrip;               // Attributes, Text
    FTextWin: TSciWindow;             // the Text tab's editor ...
    FText: TSciEdit;                  // ... and its text
    FUnitText: string;                // the library's unit (made the first time it is shown)
    FTypeTexts: array of string;      // per type: its text (made the first time it is shown) ...
    FTypeMade: array of Boolean;      // ... once it is made
    FTypeImport: TTLBImport;          // ... by this import of the library (made with the first text)
    FShownText: Integer;              // what Text shows: a type's index, -1 the unit, -2 nothing
    FHeaderText: string;
    FHeaderIcon: TSdIcon;
    FFilling: Boolean;
    function NodeType(N: TTreeNode): Integer;     // -1: the library
    function NodeMember(N: TTreeNode): Integer;   // -1: the type itself
    function TypeInfoOf(I: Integer): ITypeInfo;
    procedure AddMembers(N: TTreeNode);
    procedure TabsChange(Sender: TObject);
    procedure ShowNode(N: TTreeNode);
    procedure ShowText(Key: Integer; const S: string);
    function TypeText(Idx: Integer): string;
    procedure Attr(const Name, Value: string);
  protected
    function ShownSecond: TWinControl; override;
    procedure DrawHeader(const R: TRect); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Open(const FileName: string);   // raises EOleSysError when the file has none
    procedure Clear;
    function DebugText: string;      // test mode: file|node|tab|header|attributes|text length
    property TypeLib: ITypeLib read FTL;
    property FileName: string read FFile;
  end;

implementation

{$R *.dfm}

uses
  ComObj, Variants, SdEncoding, SdFileNames;

const
  TabAttributes = 0;
  TabText = 1;

function KindName(K: TTypeKind; Flags: Word): string;
begin
  case K of
    TKIND_ENUM: Result := 'enum';
    TKIND_RECORD: Result := 'record';
    TKIND_MODULE: Result := 'module';
    TKIND_INTERFACE: Result := 'interface';
    TKIND_DISPATCH:
      if Flags and TYPEFLAG_FDUAL <> 0 then Result := 'interface' else Result := 'dispinterface';
    TKIND_COCLASS: Result := 'coclass';
    TKIND_ALIAS: Result := 'alias';
    TKIND_UNION: Result := 'union';
  else
    Result := 'type';
  end;
end;

function KindIcon(K: TTypeKind): TSdIcon;
begin
  case K of
    TKIND_ENUM: Result := iiEnum;
    TKIND_RECORD, TKIND_UNION: Result := iiRecord;
    TKIND_MODULE: Result := iiUnit;
    TKIND_INTERFACE, TKIND_DISPATCH: Result := iiInterface;
    TKIND_COCLASS: Result := iiClass;
  else
    Result := iiType;
  end;
end;

function FlagNames(F: Word): string;
const
  Names: array[0..14] of string = ('AppObject', 'CanCreate', 'Licensed', 'PreDeclId', 'Hidden',
    'Control', 'Dual', 'NonExtensible', 'OleAutomation', 'Restricted', 'Aggregatable', 'Replaceable',
    'Dispatchable', 'ReverseBind', 'Proxy');
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Names) do
    if F and (1 shl I) <> 0 then
    begin
      if Result <> '' then Result := Result + ', ';
      Result := Result + Names[I];
    end;
end;


function DocOf(TI: ITypeInfo; MemID: Integer; out Help: string): string;
var
  N, H: WideString;
begin
  N := '';
  H := '';
  TI.GetDocumentation(MemID, @N, @H, nil, nil);
  Result := WideToIde(N);
  Help := WideToIde(H);
end;

constructor TSdTypeLibView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  AddSide(LibTree, True);
  FTabs := NewTabs(['Attributes', 'Text'], False);
  FTabs.OnChange := TabsChange;
  AddSide(AttrList, False);
  FTextWin := TSciWindow.Create(Self);
  FTextWin.Borderless := True;
  AddSide(FTextWin, False);
  FText := FTextWin.Edit;
  FText.SetLanguage(slPascal);
  FShownText := -2;
end;

destructor TSdTypeLibView.Destroy;
begin
  FTypeImport.Free;
  inherited Destroy;
end;

{ the Text tab: what Key names (a type's index, -1 the unit, -2 nothing) - loaded only when it
  is not shown already: the members of a type share its text, and its place in view stays }
procedure TSdTypeLibView.ShowText(Key: Integer; const S: string);
begin
  if Key = FShownText then Exit;
  FShownText := Key;
  FText.ReadOnly := False;
  FText.LoadFromString(S);
  FText.ReadOnly := True;
end;

{ a type as the unit declares it, made once - by one import of the library for all its types: its
  writer names the library's types once (TypeLibTypeText's import names them at every call, tens
  of milliseconds for a library of thousands of types), and gives each text as a writer of its own
  would (TTLBImport.TypeText) }
function TSdTypeLibView.TypeText(Idx: Integer): string;
begin
  if (Idx < 0) or (Idx >= Length(FTypeTexts)) then
  begin
    Result := TypeLibTypeText(FTL, Idx);
    Exit;
  end;
  if not FTypeMade[Idx] then
  begin
    if FTypeImport = nil then FTypeImport := TypeLibTextImport;
    FTypeTexts[Idx] := FTypeImport.TypeText(FTL, Idx);
    FTypeMade[Idx] := True;
  end;
  Result := FTypeTexts[Idx];
end;

function TSdTypeLibView.ShownSecond: TWinControl;
begin
  if FTabs.TabIndex = TabText then Result := FTextWin else Result := AttrList;
end;

procedure TSdTypeLibView.DrawHeader(const R: TRect);
begin
  if FHeaderText <> '' then DrawHeaderLine(R, IconList, IconIndex(FHeaderIcon), FHeaderText);
end;

{ a node's data: the type's index + 1 in the high word, the member's index + 1 in the low word
  (0 / 0: the library) }
function TSdTypeLibView.NodeType(N: TTreeNode): Integer;
begin
  if N = nil then Result := -1 else Result := (Cardinal(N.Data) shr 16) - 1;
end;

function TSdTypeLibView.NodeMember(N: TTreeNode): Integer;
begin
  if N = nil then Result := -1 else Result := Integer(Cardinal(N.Data) and $FFFF) - 1;
end;

function TSdTypeLibView.TypeInfoOf(I: Integer): ITypeInfo;
var
  K: TTypeKind;
  A: PTypeAttr;
  R: HRefType;
  V: ITypeInfo;
begin
  OleCheck(FTL.GetTypeInfo(I, Result));
  { a dual interface: its v-table part (its own members, not IDispatch's) }
  if Succeeded(FTL.GetTypeInfoType(I, K)) and (K = TKIND_DISPATCH) and Succeeded(Result.GetTypeAttr(A)) then
  begin
    if (A.wTypeFlags and TYPEFLAG_FDUAL <> 0) and Succeeded(Result.GetRefTypeOfImplType(-1, R)) and
      Succeeded(Result.GetRefTypeInfo(R, V)) then
    begin
      Result.ReleaseTypeAttr(A);
      Result := V;
      Exit;
    end;
    Result.ReleaseTypeAttr(A);
  end;
end;

procedure TSdTypeLibView.Clear;
begin
  FFilling := True;
  try
    LibTree.Items.Clear;
    AttrList.Items.Clear;
  finally
    FFilling := False;
  end;
  ShowText(-2, '');
  FreeAndNil(FTypeImport);
  FTL := nil;
  FFile := '';
  FUnitText := '';
  FTypeTexts := nil;
  FTypeMade := nil;
  FHeaderText := '';
  InvalidateHeader;
end;

{ the library and its types (each with a placeholder child until it is opened) }
procedure TSdTypeLibView.Open(const FileName: string);
var
  TL: ITypeLib;
  Root, N: TTreeNode;
  I: Integer;
  K: TTypeKind;
  Doc: WideString;
  Ic: Integer;
begin
  TL := LoadTypeLibrary(FileName);
  Clear;
  FTL := TL;
  FFile := FileName;
  SetLength(FTypeTexts, TL.GetTypeInfoCount);
  SetLength(FTypeMade, TL.GetTypeInfoCount);
  FFilling := True;
  LibTree.Items.BeginUpdate;
  try
    Root := LibTree.Items.AddChildObject(nil, TypeLibName(TL), nil);
    Root.ImageIndex := IconIndex(iiUnit);
    Root.SelectedIndex := Root.ImageIndex;
    for I := 0 to TL.GetTypeInfoCount - 1 do
    begin
      Doc := '';
      TL.GetDocumentation(I, @Doc, nil, nil, nil);
      if Failed(TL.GetTypeInfoType(I, K)) then K := TKIND_ALIAS;
      N := LibTree.Items.AddChildObject(Root, WideToIde(Doc), Pointer((I + 1) shl 16));
      Ic := IconIndex(KindIcon(K));
      N.ImageIndex := Ic;
      N.SelectedIndex := Ic;
      if K in [TKIND_INTERFACE, TKIND_DISPATCH, TKIND_COCLASS, TKIND_ENUM, TKIND_RECORD, TKIND_UNION, TKIND_MODULE] then
        LibTree.Items.AddChildObject(N, '', Pointer(-1));
    end;
    Root.Expand(False);
    LibTree.Selected := Root;
  finally
    LibTree.Items.EndUpdate;
    FFilling := False;
  end;
  ShowNode(Root);
end;

{ the members of a type: functions (a property's get / put as the property), variables, the
  interfaces of a CoClass }
procedure TSdTypeLibView.AddMembers(N: TTreeNode);
var
  I, Idx, F: Integer;
  TI, R: ITypeInfo;
  A: PTypeAttr;
  FD: PFuncDesc;
  VD: PVarDesc;
  Href: HRefType;
  Name, Help, Text: string;
  Seen: TStringList;
  C: TTreeNode;
  Ic: TSdIcon;
begin
  Idx := NodeType(N);
  TI := TypeInfoOf(Idx);
  if Failed(TI.GetTypeAttr(A)) then Exit;
  Seen := TStringList.Create;
  Seen.Sorted := True;                // (MSHTML's interfaces have hundreds of members)
  LibTree.Items.BeginUpdate;
  try
    N.DeleteChildren;
    if A.typekind = TKIND_COCLASS then
      for I := 0 to A.cImplTypes - 1 do
      begin
        if Failed(TI.GetRefTypeOfImplType(I, Href)) or Failed(TI.GetRefTypeInfo(Href, R)) then Continue;
        TI.GetImplTypeFlags(I, F);
        Text := DocOf(R, -1, Help);
        if F and IMPLTYPEFLAG_FDEFAULT <> 0 then Text := Text + ' [default]';
        if F and IMPLTYPEFLAG_FSOURCE <> 0 then Text := Text + ' [source]';
        C := LibTree.Items.AddChildObject(N, Text, Pointer(((Idx + 1) shl 16) or (I + 1)));
        C.ImageIndex := IconIndex(iiInterface);
        C.SelectedIndex := C.ImageIndex;
      end;
    for I := 0 to A.cFuncs - 1 do
    begin
      if Failed(TI.GetFuncDesc(I, FD)) then Continue;
      try
        Name := DocOf(TI, FD.memid, Help);
        Ic := iiProperty;          // (Continue inside try..finally hides from the compiler that every path sets it)
        if FD.invkind = INVOKE_FUNC then
        begin
          if FD.elemdescFunc.tdesc.vt in [VT_VOID, VT_HRESULT] then Ic := iiProcedure else Ic := iiFunction;
        end
        else
        begin
          { a property: once, for its get or its first put }
          if Seen.IndexOf(Name) >= 0 then Continue;
          Seen.Add(Name);
        end;
        C := LibTree.Items.AddChildObject(N, Name, Pointer(((Idx + 1) shl 16) or (I + 1)));
        C.ImageIndex := IconIndex(Ic);
        C.SelectedIndex := C.ImageIndex;
      finally
        TI.ReleaseFuncDesc(FD);
      end;
    end;
    for I := 0 to A.cVars - 1 do
    begin
      if Failed(TI.GetVarDesc(I, VD)) then Continue;
      try
        Name := DocOf(TI, VD.memid, Help);
        if A.typekind in [TKIND_ENUM, TKIND_MODULE] then Ic := iiConst
        else if A.typekind = TKIND_DISPATCH then Ic := iiProperty
        else Ic := iiField;
        C := LibTree.Items.AddChildObject(N, Name, Pointer(((Idx + 1) shl 16) or (A.cFuncs + I + 1)));
        C.ImageIndex := IconIndex(Ic);
        C.SelectedIndex := C.ImageIndex;
      finally
        TI.ReleaseVarDesc(VD);
      end;
    end;
  finally
    LibTree.Items.EndUpdate;
    Seen.Free;
    TI.ReleaseTypeAttr(A);
  end;
end;

procedure TSdTypeLibView.TreeExpanding(Sender: TObject; Node: TTreeNode; var AllowExpansion: Boolean);
begin
  if (Node.Count = 1) and (Integer(Node.GetFirstChild.Data) = -1) then AddMembers(Node);
end;

procedure TSdTypeLibView.TreeChange(Sender: TObject; Node: TTreeNode);
begin
  if not FFilling then ShowNode(Node);
end;

procedure TSdTypeLibView.TabsChange(Sender: TObject);
begin
  Arrange;
  ShowNode(LibTree.Selected);
end;

procedure TSdTypeLibView.Attr(const Name, Value: string);
begin
  with AttrList.Items.Add do
  begin
    Caption := Name;
    SubItems.Add(Value);
  end;
end;

{ the chosen node: the line above, its attributes, its text }
procedure TSdTypeLibView.ShowNode(N: TTreeNode);
var
  Idx, M, Count: Integer;
  TI: ITypeInfo;
  A: PTypeAttr;
  LA: PTLibAttr;
  FD: PFuncDesc;
  VD: PVarDesc;
  Help, Name, S: string;
  Href: HRefType;
  R: ITypeInfo;
  Imp: TTLBImport;
  K: TTypeKind;
  F: Word;
begin
  AttrList.Items.BeginUpdate;
  try
    AttrList.Items.Clear;
    FHeaderText := '';
    S := '';
    if (FTL = nil) or (N = nil) or (Integer(N.Data) = -1) then
    begin
      InvalidateHeader;
      ShowText(-2, '');
      Exit;
    end;
    Idx := NodeType(N);
    M := NodeMember(N);
    if Idx < 0 then
    begin
      { the library }
      FHeaderText := 'library ' + TypeLibName(FTL);
      FHeaderIcon := iiUnit;
      Attr('Name', TypeLibName(FTL));
      if Succeeded(FTL.GetLibAttr(LA)) then
      begin
        Attr('GUID', GUIDToString(LA.guid));
        Attr('Version', Format('%d.%d', [LA.wMajorVerNum, LA.wMinorVerNum]));
        Attr('LCID', IntToStr(LA.lcid));
        FTL.ReleaseTLibAttr(LA);
      end;
      Attr('Help String', TypeLibHelp(FTL));
      Attr('File', WideToIde(DisplayPath(FFile)));
      Attr('Types', IntToStr(FTL.GetTypeInfoCount));
      if FTabs.TabIndex = TabText then
      begin
        if FUnitText = '' then
        begin
          { an import of its own: a writer writes its unit once, with the units it depends on as it
            meets them }
          Imp := TypeLibTextImport;
          try
            Screen.Cursor := crHourGlass;
            try
              Imp.Import(FTL);
              FUnitText := Imp.Source(0);
            finally
              Screen.Cursor := crDefault;
            end;
          finally
            Imp.Free;
          end;
        end;
        S := FUnitText;
      end;
    end
    else
    begin
      TI := TypeInfoOf(Idx);
      if Failed(TI.GetTypeAttr(A)) then Exit;
      try
        K := A.typekind;
        F := A.wTypeFlags;
        FTL.GetTypeInfoType(Idx, K);
        Name := DocOf(TI, -1, Help);
        if M < 0 then
        begin
          FHeaderText := KindName(K, F) + ' ' + Name;
          FHeaderIcon := KindIcon(K);
          Attr('Name', Name);
          if K in [TKIND_INTERFACE, TKIND_DISPATCH, TKIND_COCLASS, TKIND_RECORD, TKIND_UNION] then
            Attr('GUID', GUIDToString(A.guid));
          Attr('Version', Format('%d.%d', [A.wMajorVerNum, A.wMinorVerNum]));
          Attr('Help String', Help);
          Attr('Flags', FlagNames(A.wTypeFlags));
          if (A.typekind in [TKIND_INTERFACE, TKIND_DISPATCH]) and (A.cImplTypes > 0) and
            Succeeded(TI.GetRefTypeOfImplType(0, Href)) and Succeeded(TI.GetRefTypeInfo(Href, R)) then
            Attr('Parent Interface', DocOf(R, -1, Help));
          if A.typekind = TKIND_COCLASS then Attr('Interfaces', IntToStr(A.cImplTypes))
          else if A.typekind = TKIND_ENUM then Attr('Values', IntToStr(A.cVars))
          else if A.typekind in [TKIND_RECORD, TKIND_UNION] then Attr('Fields', IntToStr(A.cVars))
          else Attr('Members', IntToStr(A.cFuncs + A.cVars));
        end
        else if (A.typekind = TKIND_COCLASS) and (M < A.cImplTypes) then
        begin
          if Succeeded(TI.GetRefTypeOfImplType(M, Href)) and Succeeded(TI.GetRefTypeInfo(Href, R)) then
          begin
            FHeaderText := 'implements ' + DocOf(R, -1, Help);
            FHeaderIcon := iiInterface;
            Attr('Interface', DocOf(R, -1, Help));
            Attr('GUID', GUIDToString(GuidOf(R)));
          end;
        end
        else if M < A.cFuncs then
        begin
          if Succeeded(TI.GetFuncDesc(M, FD)) then
          try
            Name := DocOf(TI, FD.memid, Help);
            case FD.invkind of
              INVOKE_PROPERTYGET, INVOKE_PROPERTYPUT, INVOKE_PROPERTYPUTREF:
                begin
                  FHeaderText := 'property ' + Name;
                  FHeaderIcon := iiProperty;
                end;
            else
              FHeaderText := 'method ' + Name;
              if FD.elemdescFunc.tdesc.vt in [VT_VOID, VT_HRESULT] then FHeaderIcon := iiProcedure
              else FHeaderIcon := iiFunction;
            end;
            Attr('Name', Name);
            Attr('ID', IntToStr(FD.memid));
            case FD.invkind of
              INVOKE_PROPERTYGET: Attr('Invoke Kind', 'Property Get');
              INVOKE_PROPERTYPUT: Attr('Invoke Kind', 'Property Put');
              INVOKE_PROPERTYPUTREF: Attr('Invoke Kind', 'Property Put By Reference');
            else
              Attr('Invoke Kind', 'Function');
            end;
            Attr('Parameters', IntToStr(FD.cParams));
            Attr('Help String', Help);
          finally
            TI.ReleaseFuncDesc(FD);
          end;
        end
        else
        begin
          Count := M - A.cFuncs;
          if Succeeded(TI.GetVarDesc(Count, VD)) then
          try
            Name := DocOf(TI, VD.memid, Help);
            FHeaderText := Name;
            FHeaderIcon := iiField;
            Attr('Name', Name);
            Attr('ID', IntToStr(VD.memid));
            if (VD.varkind = VAR_CONST) and (VD.lpvarValue <> nil) then
              try
                if VarType(VD.lpvarValue^) and varTypeMask = varOleStr then
                  Attr('Value', WideToIde(VarToWideStr(VD.lpvarValue^)))
                else
                  Attr('Value', VarToStr(VD.lpvarValue^));
              except
              end;
            Attr('Help String', Help);
          finally
            TI.ReleaseVarDesc(VD);
          end;
        end;
      finally
        TI.ReleaseTypeAttr(A);
      end;
      if FTabs.TabIndex = TabText then S := TypeText(Idx);
    end;
  finally
    AttrList.Items.EndUpdate;
  end;
  InvalidateHeader;
  if FTabs.TabIndex = TabText then
    if Idx < 0 then ShowText(-1, S) else ShowText(Idx, S);
end;

function TSdTypeLibView.DebugText: string;
var
  I: Integer;
begin
  Result := FFile + '|';
  if LibTree.Selected <> nil then Result := Result + LibTree.Selected.Text;
  Result := Result + '|' + FTabs.Tabs[FTabs.TabIndex] + '|' + FHeaderText + '|';
  for I := 0 to AttrList.Items.Count - 1 do
    Result := Result + AttrList.Items[I].Caption + '=' + AttrList.Items[I].SubItems[0] + ';';
  Result := Result + '|' + IntToStr(FText.TextLength) + '|' + IntToStr(LibTree.Items.Count);
end;

end.
