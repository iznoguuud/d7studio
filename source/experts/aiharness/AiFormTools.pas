{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiFormTools;

{ The harness's tools for forms, through the form designer (IOTAFormEditor) and the designed
  components themselves (INTAComponent, RTTI):
    reading:  form_list_components, form_get_properties;
    changing: form_set_property, form_add_component, form_delete_component (approved first).
  A form is named by its unit (or .dfm); without a path the form of the current module is used.
  Values are text as the Object Inspector shows them: numbers, True/False, enumeration names
  (alClient), sets ([akLeft,akTop]), colours (clRed or $00FF8000), cursors, shortcuts (Ctrl+S),
  component names for references, the lines of a TStrings. Nested properties are named with a
  dot (Font.Style). Event handlers are not set here: they need code in the unit. }

interface

uses
  AiCore;

procedure AddFormTools(List: TAiToolList);

implementation

uses
  Windows, SysUtils, Classes, TypInfo, Variants, Graphics, Controls, Menus, ToolsAPI, DesignIntf,
  AiJson, AiText, AiIde;

type
  TFormTool = class(TAiTool)
  public
    function Summarize(Input: TJson): string; override;
  end;

  TListComponentsTool = class(TFormTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

  TGetPropertiesTool = class(TFormTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    function Summarize(Input: TJson): string; override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

  TFormChangeTool = class(TFormTool)
  public
    function IsChange: Boolean; override;
  end;

  TSetPropertyTool = class(TFormChangeTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    function Summarize(Input: TJson): string; override;
    function Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean; override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

  TAddComponentTool = class(TFormChangeTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    function Summarize(Input: TJson): string; override;
    function Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean; override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

  TDeleteComponentTool = class(TFormChangeTool)
  public
    function Name: string; override;
    function Description: string; override;
    procedure DefineInput(Schema: TJson); override;
    function Summarize(Input: TJson): string; override;
    function Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean; override;
    procedure Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult); override;
  end;

procedure AddFormTools(List: TAiToolList);
begin
  List.Add(TListComponentsTool.Create);
  List.Add(TGetPropertiesTool.Create);
  List.Add(TSetPropertyTool.Create);
  List.Add(TAddComponentTool.Create);
  List.Add(TDeleteComponentTool.Create);
end;

{ ---------------------------------------------------------------- helpers }


{ the form editor of the input's path (a unit or its .dfm), else of the current module }
function FormEditorFor(Input: TJson; out FE: IOTAFormEditor; out Problem: string): Boolean;
var
  F: string;
  M: IOTAModule;
begin
  Result := False;
  FE := nil;
  Problem := '';
  F := Utf8ToIde(Input.Str('path'));
  if F = '' then
  begin
    M := ModuleServices.CurrentModule;
    if M = nil then
    begin
      Problem := 'No module is open: give the path of the form''s unit.';
      Exit;
    end;
  end
  else
  begin
    F := ResolvePath(F);
    if SameText(ExtractFileExt(F), '.dfm') then F := ChangeFileExt(F, '.pas');
    M := FindModuleOf(F);
    if M = nil then
    begin
      if not FileExists(F) then
      begin
        Problem := 'There is no file ' + IdeToUtf8(F) + '.';
        Exit;
      end;
      KitOpenFile(F);
      M := FindModuleOf(F);
    end;
  end;
  FE := FormEditorOf(M);
  if FE = nil then
  begin
    if M <> nil then Problem := IdeToUtf8(M.FileName) + ' has no form.' else Problem := 'The form could not be opened.';
    Exit;
  end;
  if FE.GetRootComponent = nil then FE.Show;
  if FE.GetRootComponent = nil then
  begin
    Problem := 'The form of ' + IdeToUtf8(M.FileName) + ' could not be loaded in the designer.';
    Exit;
  end;
  Result := True;
end;

function RootOf(FE: IOTAFormEditor): TComponent;
var
  N: INTAComponent;
begin
  Result := nil;
  if Supports(FE.GetRootComponent, INTAComponent, N) then Result := N.GetComponent;
end;

function DesignerOf(FE: IOTAFormEditor): IDesigner;
var
  N: INTAFormEditor;
begin
  Result := nil;
  if Supports(FE, INTAFormEditor, N) then Result := N.FormDesigner;
end;

{ the component called Name on the form ('' and the form's own name: the form) }
function ComponentOf(Root: TComponent; const Name: string): TComponent;
begin
  if (Name = '') or SameText(Name, Root.Name) then Result := Root
  else Result := Root.FindComponent(Name);
end;

{ the object a dotted property path leads to, and the last name in it }
function WalkPath(Instance: TPersistent; const Path: string; out Target: TPersistent; out Last: string;
  out Problem: string): Boolean;
var
  Rest, Part: string;
  P: Integer;
  Info: PPropInfo;
  Obj: TObject;
begin
  Result := False;
  Target := Instance;
  Problem := '';
  Rest := Path;
  repeat
    P := Pos('.', Rest);
    if P = 0 then Break;
    Part := Copy(Rest, 1, P - 1);
    Delete(Rest, 1, P);
    Info := GetPropInfo(Target, Part);
    if (Info = nil) or (Info^.PropType^.Kind <> tkClass) then
    begin
      Problem := Format('%s has no object property %s.', [Target.ClassName, Part]);
      Exit;
    end;
    Obj := GetObjectProp(Target, Info);
    if not (Obj is TPersistent) then
    begin
      Problem := Format('%s.%s is not set.', [Target.ClassName, Part]);
      Exit;
    end;
    Target := TPersistent(Obj);
  until False;
  Last := Rest;
  Result := Last <> '';
  if not Result then Problem := 'The property name is empty.';
end;

{ the published property a dotted path names on Instance: the object that holds it and its RTTI;
  '' or the problem (an IDE string) }
function FindProp(Instance: TPersistent; const Path: string; out Target: TPersistent; out Info: PPropInfo): string;
var
  Last: string;
begin
  Info := nil;
  if not WalkPath(Instance, Path, Target, Last, Result) then Exit;
  Info := GetPropInfo(Target, Last);
  if Info = nil then Result := Format('%s has no published property %s.', [Target.ClassName, Last])
  else Result := '';
end;

function FloatText(X: Extended): string;
begin
  Result := FloatToStr(X);
  if DecimalSeparator <> '.' then Result := StringReplace(Result, DecimalSeparator, '.', []);
end;

function ValueText(Instance: TPersistent; Info: PPropInfo; FE: IOTAFormEditor): string;
var
  T: PTypeInfo;
  Obj: TObject;
  M: TMethod;
  D: IDesigner;
  S: TStrings;
  I: Integer;
begin
  T := Info^.PropType^;
  case T^.Kind of
    tkInteger:
      if T = TypeInfo(TColor) then Result := ColorToString(GetOrdProp(Instance, Info))
      else if T = TypeInfo(TCursor) then Result := CursorToString(GetOrdProp(Instance, Info))
      else if T = TypeInfo(TShortCut) then Result := ShortCutToText(GetOrdProp(Instance, Info))
      else Result := IntToStr(GetOrdProp(Instance, Info));
    tkChar: Result := Chr(GetOrdProp(Instance, Info));
    tkWChar: Result := WideToCodePage(WideChar(GetOrdProp(Instance, Info)), CP_ACP);
    tkEnumeration: Result := GetEnumProp(Instance, Info);
    tkSet: Result := GetSetProp(Instance, Info, True);
    tkFloat: Result := FloatText(GetFloatProp(Instance, Info));
    tkString, tkLString: Result := GetStrProp(Instance, Info);
    tkWString: Result := WideToCodePage(GetWideStrProp(Instance, Info), CP_ACP);
    tkVariant: Result := VarToStr(GetVariantProp(Instance, Info));
    tkInt64: Result := IntToStr(GetInt64Prop(Instance, Info));
    tkClass:
      begin
        Obj := GetObjectProp(Instance, Info);
        if Obj = nil then Result := 'nil'
        else if Obj is TComponent then Result := TComponent(Obj).Name
        else if Obj is TStrings then
        begin
          S := TStrings(Obj);
          Result := '';
          for I := 0 to S.Count - 1 do
          begin
            if I >= 20 then
            begin
              Result := Result + Format(' ... (%d lines)', [S.Count]);
              Break;
            end;
            if I > 0 then Result := Result + '\n';
            Result := Result + S[I];
          end;
          Result := '(' + Obj.ClassName + ') ' + Result;
        end
        else Result := '(' + Obj.ClassName + ': name it as ' + string(Info^.Name) + '.<property>)';
      end;
    tkMethod:
      begin
        M := GetMethodProp(Instance, Info);
        D := DesignerOf(FE);
        if (M.Code = nil) and (M.Data = nil) then Result := ''
        else if D <> nil then Result := D.GetMethodName(M)
        else Result := '(handler)';
      end;
  else
    Result := '(' + GetEnumName(TypeInfo(TTypeKind), Ord(T^.Kind)) + ')';
  end;
end;

{ I within the range of the ordinal type T (a subrange such as TBorderStyle = bsNone..bsSingle, a
  TFontCharset = 0..255); Cardinal has no Longint range to check }
function InRange(T: PTypeInfo; I: Longint): Boolean;
var
  TD: PTypeData;
begin
  TD := GetTypeData(T);
  Result := ((T^.Kind = tkInteger) and (TD^.OrdType = otULong)) or ((I >= TD^.MinValue) and (I <= TD^.MaxValue));
end;

{ Value (IDE string; Utf8 for wide strings) set on Instance.Info; '' or the problem }
function SetValue(Root: TComponent; Instance: TPersistent; Info: PPropInfo; const Value, Utf8: string;
  CheckOnly: Boolean): string;
var
  T: PTypeInfo;
  I: Longint;
  I64: Int64;
  X: Extended;
  Code: Integer;
  V: string;
  Obj: TObject;
  C: TComponent;
  Cls: TClass;
begin
  Result := '';
  T := Info^.PropType^;
  V := Trim(Value);
  if (Info^.SetProc = nil) and (T^.Kind <> tkClass) then
  begin
    Result := string(Info^.Name) + ' is read-only.';
    Exit;
  end;
  try
    case T^.Kind of
      tkInteger:
        begin
          if T = TypeInfo(TColor) then
          begin
            if not IdentToColor(V, I) then I := StrToInt(V);
          end
          else if T = TypeInfo(TCursor) then
          begin
            if not IdentToCursor(V, I) then I := StrToInt(V);
          end
          else if T = TypeInfo(TShortCut) then
          begin
            I := TextToShortCut(V);
            if (I = 0) and (V <> '') and (V <> '0') then I := StrToInt(V);
          end
          else I := StrToInt(V);
          if not InRange(T, I) then
            raise Exception.CreateFmt('%d is outside the range of %s (%d..%d)',
              [I, T^.Name, GetTypeData(T)^.MinValue, GetTypeData(T)^.MaxValue]);
          if not CheckOnly then SetOrdProp(Instance, Info, I);
        end;
      tkChar:
        begin
          if Length(Value) <> 1 then raise Exception.Create('one character expected');
          if not CheckOnly then SetOrdProp(Instance, Info, Ord(Value[1]));
        end;
      tkEnumeration:
        begin
          if (T = TypeInfo(Boolean)) or (GetTypeData(T)^.BaseType^ = TypeInfo(Boolean)) then
          begin
            if SameText(V, 'True') then I := 1
            else if SameText(V, 'False') then I := 0
            else raise Exception.Create('True or False expected');
          end
          else
          begin
            { GetEnumValue knows the names of the base type: a subrange takes fewer }
            I := GetEnumValue(T, V);
            if (I < 0) or not InRange(T, I) then raise Exception.CreateFmt('%s is not a value of %s', [V, T^.Name]);
          end;
          if not CheckOnly then SetOrdProp(Instance, Info, I);
        end;
      tkSet:
        if CheckOnly then StringToSet(Info, V) else SetSetProp(Instance, Info, V);
      tkFloat:
        begin
          Val(V, X, Code);
          if Code <> 0 then raise Exception.Create('a number expected (with a dot)');
          if not CheckOnly then SetFloatProp(Instance, Info, X);
        end;
      tkString, tkLString:
        if not CheckOnly then SetStrProp(Instance, Info, Value);
      tkWString:
        if not CheckOnly then SetWideStrProp(Instance, Info, Utf8ToWide(Utf8));
      tkVariant:
        if not CheckOnly then SetVariantProp(Instance, Info, Value);
      tkInt64:
        begin
          I64 := StrToInt64(V);
          if not CheckOnly then SetInt64Prop(Instance, Info, I64);
        end;
      tkClass:
        begin
          Obj := GetObjectProp(Instance, Info);
          Cls := GetTypeData(T)^.ClassType;
          if (Obj is TStrings) or Cls.InheritsFrom(TStrings) then
          begin
            if Obj = nil then raise Exception.Create('the list is not there');
            if not CheckOnly then
              TStrings(Obj).Text := StringReplace(NormalizeNewLines(Value, #13#10), '\n', #13#10, [rfReplaceAll]);
          end
          else if Cls.InheritsFrom(TComponent) then
          begin
            if Info^.SetProc = nil then raise Exception.Create('read-only');
            if (V = '') or SameText(V, 'nil') then C := nil
            else
            begin
              C := Root.FindComponent(V);
              if C = nil then raise Exception.CreateFmt('the form has no component %s', [V]);
              if not C.InheritsFrom(Cls) then raise Exception.CreateFmt('%s is not a %s', [V, Cls.ClassName]);
            end;
            if not CheckOnly then SetObjectProp(Instance, Info, C);
          end
          else
            raise Exception.CreateFmt('%s is an object: set its properties as %s.<property>', [Info^.Name, Info^.Name]);
        end;
      tkMethod:
        raise Exception.Create('event handlers cannot be set by this tool: write the method in the unit (edit_file), ' +
          'then the user assigns it in the Object Inspector');
    else
      raise Exception.Create('this kind of property cannot be set here');
    end;
  except
    on E: EConvertError do Result := Format('"%s" is not a valid value of %s: %s', [Value, Info^.Name, E.Message]);
    on E: Exception do Result := Format('%s: %s', [Info^.Name, E.Message]);
  end;
end;

procedure Modified(FE: IOTAFormEditor);
var
  D: IDesigner;
begin
  D := DesignerOf(FE);
  if D <> nil then D.Modified;
  FE.MarkModified;
end;

function Bounds(C: TComponent): string;
begin
  if C is TControl then
    Result := Format(' (Left %d, Top %d, Width %d, Height %d)', [TControl(C).Left, TControl(C).Top,
      TControl(C).Width, TControl(C).Height])
  else Result := '';
end;

function ParentName(C: TControl): string;
begin
  if C.Parent <> nil then Result := C.Parent.Name else Result := 'none';
end;

{ a short text the component shows, when it has one }
function Label_(C: TComponent): string;
var
  Info: PPropInfo;
begin
  Result := '';
  Info := GetPropInfo(C, 'Caption');
  if Info = nil then Info := GetPropInfo(C, 'Text');
  if (Info <> nil) and (Info^.PropType^.Kind in [tkString, tkLString]) then
    Result := ' ' + string(Info^.Name) + '=''' + Copy(GetStrProp(C, Info), 1, 60) + '''';
end;

{ ---------------------------------------------------------------- form tools }

function TFormTool.Summarize(Input: TJson): string;
begin
  Result := FileNamePart(Input.Str('path'));
end;

function TFormChangeTool.IsChange: Boolean;
begin
  Result := True;
end;

{ ---------------------------------------------------------------- form_list_components }

function TListComponentsTool.Name: string;
begin
  Result := 'form_list_components';
end;

function TListComponentsTool.Description: string;
begin
  Result := 'Lists the components of a form as a tree: each control under its parent with its class, position, size ' +
    'and caption, then the non-visual components. The form is the one of the unit given (path), else the form of ' +
    'the current module. Call it before you change a form.';
end;

procedure TListComponentsTool.DefineInput(Schema: TJson);
begin
  SchemaProp(Schema, 'path', 'string', 'The form''s unit (or .dfm); default: the current module.', False);
end;

procedure TListComponentsTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  FE: IOTAFormEditor;
  Problem: string;
  Root: TComponent;
  B: TStringList;
  Listed: TList;
  I: Integer;
  C: TComponent;

  procedure AddControls(Parent: TWinControl; const Indent: string);
  var
    K: Integer;
    Ctl: TControl;
  begin
    for K := 0 to Parent.ControlCount - 1 do
    begin
      Ctl := Parent.Controls[K];
      if Ctl.Owner <> Root then Continue;
      B.Add(Indent + Ctl.Name + ': ' + Ctl.ClassName + Bounds(Ctl) + Label_(Ctl));
      Listed.Add(Ctl);
      if Ctl is TWinControl then AddControls(TWinControl(Ctl), Indent + '  ');
    end;
  end;

begin
  if not FormEditorFor(Input, FE, Problem) then
  begin
    Res.Fail(Problem);
    Exit;
  end;
  Root := RootOf(FE);
  B := TStringList.Create;
  Listed := TList.Create;
  try
    B.Add(Format('%s: %s%s, in %s', [Root.Name, Root.ClassName, Bounds(Root), FE.FileName]));
    if Root is TWinControl then AddControls(TWinControl(Root), '  ');
    for I := 0 to Root.ComponentCount - 1 do
    begin
      C := Root.Components[I];
      if (C is TControl) and (Listed.IndexOf(C) < 0) then
        B.Add('  ' + C.Name + ': ' + C.ClassName + Bounds(C) + ' (parent ' + ParentName(TControl(C)) + ')');
    end;
    Listed.Clear;
    for I := 0 to Root.ComponentCount - 1 do
    begin
      C := Root.Components[I];
      if not (C is TControl) then Listed.Add(C);
    end;
    if Listed.Count > 0 then
    begin
      B.Add('Non-visual components:');
      for I := 0 to Listed.Count - 1 do
        B.Add('  ' + TComponent(Listed[I]).Name + ': ' + TComponent(Listed[I]).ClassName);
    end;
    Res.Ok(IdeToUtf8(B.Text), Format('%d components', [Root.ComponentCount]));
  finally
    Listed.Free;
    B.Free;
  end;
end;

{ ---------------------------------------------------------------- form_get_properties }

function TGetPropertiesTool.Name: string;
begin
  Result := 'form_get_properties';
end;

function TGetPropertiesTool.Description: string;
begin
  Result := 'Returns the published properties and events of a component on a form (or of the form itself when no ' +
    'component is given), with their types and values as the Object Inspector shows them (an event: its handler). With object, the properties of a ' +
    'nested object (e.g. "Font"). With filter, only the properties whose names start with it.';
end;

procedure TGetPropertiesTool.DefineInput(Schema: TJson);
begin
  SchemaProp(Schema, 'path', 'string', 'The form''s unit (or .dfm); default: the current module.', False);
  SchemaProp(Schema, 'component', 'string', 'The component''s name (default: the form).', False);
  SchemaProp(Schema, 'object', 'string', 'A nested object property, e.g. "Font" or "Constraints".', False);
  SchemaProp(Schema, 'filter', 'string', 'Only properties whose names start with this.', False);
end;

function TGetPropertiesTool.Summarize(Input: TJson): string;
begin
  Result := Input.Str('component');
  if Input.Str('object') <> '' then Result := Result + '.' + Input.Str('object');
end;

procedure TGetPropertiesTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  FE: IOTAFormEditor;
  Problem, Filter, Obj, Last: string;
  Root, C: TComponent;
  Target: TPersistent;
  List: PPropList;
  N, I: Integer;
  B: TStringList;
  Info: PPropInfo;
begin
  if not FormEditorFor(Input, FE, Problem) then
  begin
    Res.Fail(Problem);
    Exit;
  end;
  Root := RootOf(FE);
  C := ComponentOf(Root, Utf8ToIde(Input.Str('component')));
  if C = nil then
  begin
    Res.Fail('The form has no component ' + Input.Str('component') + '.');
    Exit;
  end;
  Target := C;
  Obj := Utf8ToIde(Input.Str('object'));
  if Obj <> '' then
  begin
    if not WalkPath(C, Obj + '.x', Target, Last, Problem) then
    begin
      Res.Fail(IdeToUtf8(Problem));
      Exit;
    end;
  end;
  Filter := LowerCase(Utf8ToIde(Input.Str('filter')));
  B := TStringList.Create;
  try
    if Obj <> '' then B.Add(Format('%s.%s (%s):', [C.Name, Obj, Target.ClassName]))
    else B.Add(Format('%s (%s):', [C.Name, C.ClassName]));
    N := GetPropList(Target.ClassInfo, tkAny, nil);
    GetMem(List, N * SizeOf(PPropInfo));
    try
      GetPropList(Target.ClassInfo, tkAny, List);
      for I := 0 to N - 1 do
      begin
        Info := List^[I];
        if (Filter <> '') and (Copy(LowerCase(string(Info^.Name)), 1, Length(Filter)) <> Filter) then Continue;
        try
          B.Add(Format('  %s: %s = %s', [Info^.Name, Info^.PropType^^.Name, ValueText(Target, Info, FE)]));
        except
          on E: Exception do B.Add(Format('  %s: %s (cannot be read: %s)', [Info^.Name, Info^.PropType^^.Name, E.Message]));
        end;
      end;
    finally
      FreeMem(List);
    end;
    Res.Ok(IdeToUtf8(B.Text), Format('%d properties', [B.Count - 1]));
  finally
    B.Free;
  end;
end;

{ ---------------------------------------------------------------- form_set_property }

function TSetPropertyTool.Name: string;
begin
  Result := 'form_set_property';
end;

function TSetPropertyTool.Description: string;
begin
  Result := 'Sets a published property of a component on a form (or of the form), as the Object Inspector does. ' +
    'Give the value as text: numbers, True/False, enumeration names (alClient), sets ([akLeft,akTop]), colours ' +
    '(clRed, $00FF8000), cursors (crHandPoint), shortcuts (Ctrl+S), a component''s name for a reference, the lines ' +
    'of a list separated by \n. Name nested properties with a dot (Font.Style). Event handlers cannot be set. ' +
    'The user is asked to approve it.';
end;

procedure TSetPropertyTool.DefineInput(Schema: TJson);
begin
  SchemaProp(Schema, 'path', 'string', 'The form''s unit (or .dfm); default: the current module.', False);
  SchemaProp(Schema, 'component', 'string', 'The component''s name (empty: the form).', False);
  SchemaProp(Schema, 'property', 'string', 'The property, e.g. "Caption" or "Font.Size".', True);
  SchemaProp(Schema, 'value', 'string', 'The new value as text.', True);
end;

function TSetPropertyTool.Summarize(Input: TJson): string;
begin
  Result := Input.Str('component');
  if Result <> '' then Result := Result + '.';
  Result := Result + Input.Str('property') + ' := ' + TruncateUtf8(Input.Str('value'), 60);
end;

{ the property of the input: the form editor, the object, the property; False with Problem }
function PropertyOf(Input: TJson; out FE: IOTAFormEditor; out Root, C: TComponent; out Target: TPersistent;
  out Info: PPropInfo; out Problem: string): Boolean;
begin
  Result := False;
  Info := nil;
  Root := nil;
  C := nil;
  Target := nil;
  if not FormEditorFor(Input, FE, Problem) then Exit;
  Root := RootOf(FE);
  C := ComponentOf(Root, Utf8ToIde(Input.Str('component')));
  if C = nil then
  begin
    Problem := 'The form has no component ' + Input.Str('component') + '.';
    Exit;
  end;
  Problem := FindProp(C, Utf8ToIde(Input.Str('property')), Target, Info);
  if Problem <> '' then
  begin
    Problem := IdeToUtf8(Problem);
    Exit;
  end;
  Result := True;
end;

function TSetPropertyTool.Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean;
var
  FE: IOTAFormEditor;
  Root, C: TComponent;
  Target: TPersistent;
  Info: PPropInfo;
  Problem: string;
begin
  Result := False;
  if not PropertyOf(Input, FE, Root, C, Target, Info, Problem) then
  begin
    Res.Fail(Problem);
    Exit;
  end;
  Problem := SetValue(Root, Target, Info, Utf8ToIde(Input.Str('value')), Input.Str('value'), True);
  if Problem <> '' then
  begin
    Res.Fail(IdeToUtf8(Problem));
    Exit;
  end;
  Change.FileName := FE.FileName;
  Change.Title := Format('Set %s.%s on %s', [C.Name, Utf8ToIde(Input.Str('property')), ExtractFileName(FE.FileName)]);
  Change.Before := ValueText(Target, Info, FE);
  Change.After := Utf8ToIde(Input.Str('value'));
  Result := True;
end;

procedure TSetPropertyTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  FE: IOTAFormEditor;
  Root, C: TComponent;
  Target: TPersistent;
  Info: PPropInfo;
  Problem: string;
begin
  if not PropertyOf(Input, FE, Root, C, Target, Info, Problem) then
  begin
    Res.Fail(Problem);
    Exit;
  end;
  Problem := SetValue(Root, Target, Info, Utf8ToIde(Input.Str('value')), Input.Str('value'), False);
  if Problem <> '' then
  begin
    Res.Fail(IdeToUtf8(Problem));
    Exit;
  end;
  Modified(FE);
  Res.Ok(IdeToUtf8(Format('%s.%s is now %s.', [C.Name, Utf8ToIde(Input.Str('property')), ValueText(Target, Info, FE)])), 'set');
end;

{ ---------------------------------------------------------------- form_add_component }

function TAddComponentTool.Name: string;
begin
  Result := 'form_add_component';
end;

function TAddComponentTool.Description: string;
begin
  Result := 'Adds a component of a registered class (TButton, TLabel, TPanel, TTimer ...) to a form: inside a ' +
    'parent container (default: the form), at a position and size (default: the designer''s), with a name ' +
    '(default: the designer''s, e.g. Button2) and with initial properties as in form_set_property. The user is ' +
    'asked to approve it.';
end;

procedure TAddComponentTool.DefineInput(Schema: TJson);
var
  Props: TJson;
begin
  SchemaProp(Schema, 'path', 'string', 'The form''s unit (or .dfm); default: the current module.', False);
  SchemaProp(Schema, 'class_name', 'string', 'The component''s class, e.g. "TButton".', True);
  SchemaProp(Schema, 'parent', 'string', 'The container control to put it in (default: the form).', False);
  SchemaProp(Schema, 'name', 'string', 'The component''s name.', False);
  SchemaProp(Schema, 'left', 'integer', 'Left, in the parent''s client coordinates (default 8).', False);
  SchemaProp(Schema, 'top', 'integer', 'Top (default 8).', False);
  SchemaProp(Schema, 'width', 'integer', 'Width.', False);
  SchemaProp(Schema, 'height', 'integer', 'Height.', False);
  SchemaProp(Schema, 'properties', 'object', 'Properties to set: {"Caption": "OK", "Anchors": "[akRight,akBottom]"}.', False);
  Props := Schema.Obj('properties').Obj('properties');
  Props.PutObject('additionalProperties').PutStr('type', 'string');
end;

function TAddComponentTool.Summarize(Input: TJson): string;
begin
  Result := Input.Str('class_name');
  if Input.Str('name') <> '' then Result := Input.Str('name') + ': ' + Result;
end;

function TAddComponentTool.Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean;
var
  FE: IOTAFormEditor;
  Problem, ParentName, CompName: string;
  Root, Parent: TComponent;
  Props: TJson;
begin
  Result := False;
  if not FormEditorFor(Input, FE, Problem) then
  begin
    Res.Fail(Problem);
    Exit;
  end;
  Root := RootOf(FE);
  ParentName := Utf8ToIde(Input.Str('parent'));
  Parent := ComponentOf(Root, ParentName);
  { the form or data module itself takes any component; a named parent must hold controls }
  if (Parent = nil) or ((Parent <> Root) and not (Parent is TWinControl)) then
  begin
    Res.Fail('The form has no container ' + Input.Str('parent') + '.');
    Exit;
  end;
  CompName := Utf8ToIde(Input.Str('name'));
  if (CompName <> '') and (Root.FindComponent(CompName) <> nil) then
  begin
    Res.Fail('The form has a component ' + Input.Str('name') + ' already.');
    Exit;
  end;
  if (CompName <> '') and not IsValidIdent(CompName) then
  begin
    Res.Fail(Input.Str('name') + ' is not a valid component name.');
    Exit;
  end;
  Change.FileName := FE.FileName;
  Change.Title := Format('Add a %s to %s', [Utf8ToIde(Input.Str('class_name')), ExtractFileName(FE.FileName)]);
  Change.After := Format('Class: %s'#13#10'Name: %s'#13#10'Parent: %s',
    [Utf8ToIde(Input.Str('class_name')), CompName, Parent.Name]);
  if Input.Has('left') or Input.Has('top') then
    Change.After := Change.After + Format(#13#10'Position: %d, %d', [Input.Int('left', 0), Input.Int('top', 0)]);
  if Input.Has('width') or Input.Has('height') then
    Change.After := Change.After + Format(#13#10'Size: %d x %d', [Input.Int('width', -1), Input.Int('height', -1)]);
  Props := Input.Obj('properties');
  if (Props <> nil) and (Props.Count > 0) then Change.After := Change.After + #13#10'Properties: ' + Utf8ToIde(Props.ToJson);
  Result := True;
end;

procedure TAddComponentTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  FE: IOTAFormEditor;
  Problem, CompName, Errors, V: string;
  Root, Parent, Made: TComponent;
  Container, C: IOTAComponent;
  N: INTAComponent;
  Props: TJson;
  I: Integer;
  Target: TPersistent;
  Info: PPropInfo;
begin
  if not FormEditorFor(Input, FE, Problem) then
  begin
    Res.Fail(Problem);
    Exit;
  end;
  Root := RootOf(FE);
  Parent := ComponentOf(Root, Utf8ToIde(Input.Str('parent')));
  if Parent = Root then Container := FE.GetRootComponent else Container := FE.FindComponent(Parent.Name);
  if Container = nil then
  begin
    Res.Fail('The container was not found.');
    Exit;
  end;
  C := FE.CreateComponent(Container, Utf8ToIde(Input.Str('class_name')), Input.Int('left', 8), Input.Int('top', 8),
    Input.Int('width', -1), Input.Int('height', -1));
  if (C = nil) or not Supports(C, INTAComponent, N) or (N.GetComponent = nil) then
  begin
    Res.Fail('The designer could not make a ' + Input.Str('class_name') + ': is the class registered (its package ' +
      'installed)?');
    Exit;
  end;
  Made := N.GetComponent;
  Errors := '';
  CompName := Utf8ToIde(Input.Str('name'));
  if CompName <> '' then
    try
      Made.Name := CompName;
    except
      on E: Exception do Errors := Errors + 'Name: ' + E.Message + #13#10;
    end;
  Props := Input.Obj('properties');
  if Props <> nil then
    for I := 0 to Props.Count - 1 do
    begin
      Problem := FindProp(Made, Utf8ToIde(Props.Name(I)), Target, Info);
      if Problem <> '' then
      begin
        Errors := Errors + Problem + #13#10;
        Continue;
      end;
      V := Props.Item(I).AsString;
      Problem := SetValue(Root, Target, Info, Utf8ToIde(V), V, False);
      if Problem <> '' then Errors := Errors + Problem + #13#10;
    end;
  Modified(FE);
  C.Select(False);
  if Errors = '' then
    Res.Ok(IdeToUtf8(Format('Added %s: %s to %s%s.', [Made.Name, Made.ClassName, Parent.Name, Bounds(Made)])), 'added ' + IdeToUtf8(Made.Name))
  else
    Res.Ok(IdeToUtf8(Format('Added %s: %s to %s%s, but some properties were not set:'#13#10'%s',
      [Made.Name, Made.ClassName, Parent.Name, Bounds(Made), Errors])), 'added ' + IdeToUtf8(Made.Name) + ' with problems');
end;

{ ---------------------------------------------------------------- form_delete_component }

function TDeleteComponentTool.Name: string;
begin
  Result := 'form_delete_component';
end;

function TDeleteComponentTool.Description: string;
begin
  Result := 'Deletes a component (with the controls inside it) from a form. The user is asked to approve it.';
end;

procedure TDeleteComponentTool.DefineInput(Schema: TJson);
begin
  SchemaProp(Schema, 'path', 'string', 'The form''s unit (or .dfm); default: the current module.', False);
  SchemaProp(Schema, 'component', 'string', 'The component''s name.', True);
end;

function TDeleteComponentTool.Summarize(Input: TJson): string;
begin
  Result := Input.Str('component');
end;

function TDeleteComponentTool.Preview(Input: TJson; Change: TAiChangePreview; Res: TAiToolResult): Boolean;
var
  FE: IOTAFormEditor;
  Problem: string;
  Root, C: TComponent;
begin
  Result := False;
  if not FormEditorFor(Input, FE, Problem) then
  begin
    Res.Fail(Problem);
    Exit;
  end;
  Root := RootOf(FE);
  C := ComponentOf(Root, Utf8ToIde(Input.Str('component')));
  if (C = nil) or (C = Root) then
  begin
    Res.Fail('The form has no component ' + Input.Str('component') + ' that can be deleted.');
    Exit;
  end;
  Change.FileName := FE.FileName;
  Change.Title := Format('Delete %s (%s) from %s', [C.Name, C.ClassName, ExtractFileName(FE.FileName)]);
  Change.Before := C.Name + ': ' + C.ClassName + Bounds(C);
  Result := True;
end;

procedure TDeleteComponentTool.Execute(Context: TAiToolContext; Input: TJson; Res: TAiToolResult);
var
  FE: IOTAFormEditor;
  Problem, CompName: string;
  C: IOTAComponent;
begin
  if not FormEditorFor(Input, FE, Problem) then
  begin
    Res.Fail(Problem);
    Exit;
  end;
  CompName := Utf8ToIde(Input.Str('component'));
  C := FE.FindComponent(CompName);
  if C = nil then
  begin
    Res.Fail('The form has no component ' + Input.Str('component') + '.');
    Exit;
  end;
  if not C.Delete then
  begin
    Res.Fail('The designer did not delete ' + Input.Str('component') + '.');
    Exit;
  end;
  C := nil;
  Modified(FE);
  Res.Ok('Deleted ' + Input.Str('component') + '.', 'deleted');
end;

end.
