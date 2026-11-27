{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoTestForm;

{ The self-test's form area (OtaDemoTest): TestUnit's form through IOTAFormEditor and
  IOTAComponent - components made, renamed and deleted, properties read and written (a short
  string's as a string) - and what the form's notifiers are told:
  ComponentRenamed for a new component (no old name), a rename and a deletion (no new name),
  Modified, FormActivated when its designer comes up again, FormSaving when a compile streams it.

  TOtaDemoProbe is a component class of the demo package for the property checks; the area
  takes its components off the form again, as the program is compiled afterwards.

  TOtaDemoSelectionEditor is a selection editor of the demo (RegisterSelectionEditor, for
  buttons): its four commands in the designer's context menu - a plain one, one prepared checked
  with an item of its own, one disabled, one hidden (PrepareItem) - and what the designer hands
  its ExecuteVerb and the item's handler (step SelectionEditor). }

interface

procedure Register;

implementation

uses
  Windows, SysUtils, Classes, Controls, StdCtrls, Menus, Forms, DesignIntf, DesignEditors,
  DesignMenus, ToolsAPI, OtaDemoTest;

const
  SVerbPlain = 'OTA Demo: Selection';
  SVerbPrepared = 'OTA Demo: Prepared';
  SVerbDisabled = 'OTA Demo: Disabled';
  SVerbHidden = 'OTA Demo: Hidden';
  SVerbSub = 'OTA Demo: Item of Its Own';

type
  TOtaDemoSelectionEditor = class(TSelectionEditor)
  public
    function GetVerbCount: Integer; override;
    function GetVerb(Index: Integer): string; override;
    procedure PrepareItem(Index: Integer; const AItem: IMenuItem); override;
    procedure ExecuteVerb(Index: Integer; const List: IDesignerSelections); override;
    procedure SubItemClick(Sender: TObject);
  end;

var
  { what the selection editor saw: the plain command's runs and the selection it got, the
    sender of its item of its own and whether the editor was still there for it }
  SelectionRuns: Integer;
  SelectionCount: Integer;
  SelectionFirst: Pointer;
  SubItemSender: TObject;
  SubItemEditorAlive: Boolean;

function TOtaDemoSelectionEditor.GetVerbCount: Integer;
begin
  Result := 4;
end;

function TOtaDemoSelectionEditor.GetVerb(Index: Integer): string;
begin
  case Index of
    0: Result := SVerbPlain;
    1: Result := SVerbPrepared;
    2: Result := SVerbDisabled;
  else
    Result := SVerbHidden;
  end;
end;

procedure TOtaDemoSelectionEditor.PrepareItem(Index: Integer; const AItem: IMenuItem);
begin
  case Index of
    1:
      begin
        AItem.Checked := True;
        AItem.AddItem(SVerbSub, 0, False, True, SubItemClick);
      end;
    2: AItem.Enabled := False;
    3: AItem.Visible := False;
  end;
end;

procedure TOtaDemoSelectionEditor.ExecuteVerb(Index: Integer; const List: IDesignerSelections);
begin
  if Index <> 0 then Exit;
  Inc(SelectionRuns);
  SelectionCount := List.Count;
  if List.Count > 0 then SelectionFirst := List[0] else SelectionFirst := nil;
end;

procedure TOtaDemoSelectionEditor.SubItemClick(Sender: TObject);
begin
  SubItemSender := Sender;
  SubItemEditorAlive := Designer <> nil;
end;

procedure Register;
begin
  RegisterSelectionEditor(TButton, TOtaDemoSelectionEditor);
end;

type
  TTinyString = string[5];

  { published properties of the kinds the form editor's components hand over }
  TOtaDemoProbe = class(TComponent)
  private
    FShort: ShortString;
    FTiny: TTinyString;
    FCount: Integer;
  published
    property Short: ShortString read FShort write FShort;
    property Tiny: TTinyString read FTiny write FTiny;
    property Count: Integer read FCount write FCount;
  end;

  TCountingFormNotifier = class(TNotifierObject, IOTANotifier, IOTAFormNotifier)
  public
    Renames: TStringList;       // "old>new", Objects: the component handle
    Modifies, Activations, Savings: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure Modified;
    procedure FormActivated;
    procedure FormSaving;
    procedure ComponentRenamed(ComponentHandle: TOTAHandle; const OldName, NewName: string);
  end;

  TCountingChanges = class(TNotifierObject, IOTANotifier, IOTAModuleNotifier)
  public
    Modifies: Integer;
    procedure Modified;
    function CheckOverwrite: Boolean;
    procedure ModuleRenamed(const NewName: string);
  end;

  TFormTests = class(TOtaTestArea)
  private
    FForm: TCountingFormNotifier;
    FFormIntf: IOTANotifier;
    FFormIndex: Integer;
    FChanges: TCountingChanges;
    FChangesIntf: IOTAModuleNotifier;
    FChangesIndex: Integer;
    FButton: IOTAComponent;
    FButtonHandle: TOTAHandle;
    function Module: IOTAModule;
    function FormEditor: IOTAFormEditor;
    function Renamed(const OldName, NewName: string; Handle: TOTAHandle): Boolean;
    procedure RemoveFromUses(const UnitName: string);
    procedure Open;
    procedure CreateButton;
    procedure SelectionEditor;
    procedure Rename;
    procedure Props;
    procedure Delete;
    procedure DeleteRoot;
    procedure Activated;
    procedure UsesOnCompile;
    procedure Saving;
    function InUses(const UnitName: string): Boolean;
    procedure TakeOff;
  public
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

constructor TCountingFormNotifier.Create;
begin
  inherited Create;
  Renames := TStringList.Create;
end;

destructor TCountingFormNotifier.Destroy;
begin
  Renames.Free;
  inherited;
end;

procedure TCountingFormNotifier.Modified;
begin
  Inc(Modifies);
end;

procedure TCountingFormNotifier.FormActivated;
begin
  Inc(Activations);
end;

procedure TCountingFormNotifier.FormSaving;
begin
  Inc(Savings);
end;

procedure TCountingFormNotifier.ComponentRenamed(ComponentHandle: TOTAHandle; const OldName, NewName: string);
begin
  Renames.AddObject(OldName + '>' + NewName, TObject(ComponentHandle));
end;

procedure TCountingChanges.Modified;
begin
  Inc(Modifies);
end;

function TCountingChanges.CheckOverwrite: Boolean;
begin
  Result := True;
end;

procedure TCountingChanges.ModuleRenamed(const NewName: string);
begin
end;

function TFormTests.Name: string;
begin
  Result := 'Forms';
end;

procedure TFormTests.AddSteps;
begin
  Step('Open', Open);
  Step('Create', CreateButton);
  Step('SelectionEditor', SelectionEditor);
  Step('Rename', Rename);
  Step('Props', Props);
  Step('Delete', Delete);
  Step('DeleteRoot', DeleteRoot);
  Step('Activated', Activated);
  Step('UsesOnCompile', UsesOnCompile);
  Step('Saving', Saving);
  Step('TakeOff', TakeOff);
end;

function TFormTests.Module: IOTAModule;
begin
  Result := (BorlandIDEServices as IOTAModuleServices).FindModule(Test.Values['Unit']);
end;

function TFormTests.FormEditor: IOTAFormEditor;
begin
  Result := FormEditorOf(Module);
end;

{ the notifier was told OldName > NewName (Handle: the component, nil: any) }
function TFormTests.Renamed(const OldName, NewName: string; Handle: TOTAHandle): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FForm.Renames.Count - 1 do
    if (FForm.Renames[I] = OldName + '>' + NewName) and
      ((Handle = nil) or (Pointer(FForm.Renames.Objects[I]) = Handle)) then
      Result := True;
end;

procedure TFormTests.Cleanup;
var
  F: IOTAFormEditor;
  M: IOTAModule;
begin
  F := FormEditor;
  if (F <> nil) and (FFormIntf <> nil) then F.RemoveNotifier(FFormIndex);
  FFormIntf := nil;
  M := Module;
  if (M <> nil) and (FChangesIntf <> nil) then M.RemoveNotifier(FChangesIndex);
  FChangesIntf := nil;
end;

procedure TFormTests.Open;
var
  F: IOTAFormEditor;
begin
  F := FormEditor;
  if not Check(F <> nil, 'TestUnit has a form editor') then Exit;
  F.Show;
  FForm := TCountingFormNotifier.Create;
  FFormIntf := FForm;
  FFormIndex := F.AddNotifier(FFormIntf);
  Check(FFormIndex >= 0, 'IOTAFormEditor.AddNotifier');
  FChanges := TCountingChanges.Create;
  FChangesIntf := FChanges;
  FChangesIndex := Module.AddNotifier(FChangesIntf);
end;

{ a component placed through the form editor: the notifier learns of it as a rename from '' }
procedure TFormTests.CreateButton;
var
  F: IOTAFormEditor;
  Name: string;
begin
  F := FormEditor;
  FButton := F.CreateComponent(F.GetRootComponent, 'TButton', 16, 16, 75, 25);
  if not Check(FButton <> nil, 'CreateComponent(TButton)') then Exit;
  FButtonHandle := FButton.GetComponentHandle;
  FButton.GetPropValueByName('Name', Name);
  Check(Name <> '', 'the new button has a name', Name);
  Check(Renamed('', Name, FButtonHandle), 'ComponentRenamed('''', ' + Name + ') with the component',
    FForm.Renames.CommaText);
  Check(FForm.Modifies > 0, 'the form editor''s notifier was told Modified');
  Check(FChanges.Modifies > 0, 'the module''s notifier was told Modified');
  Check(FButton.IsTControl, 'IsTControl');
  Expect('GetComponentType', FButton.GetComponentType, 'TButton');
end;

{ the demo's selection editor in the designer's context menu: the button selected, D7 Studio's
  menu (DesignPopup of the main window) made as it opens (its OnPopup, as the IDE's test channel
  does): the commands as PrepareItem left them, the plain one and the item of its own run }
procedure TFormTests.SelectionEditor;
var
  C: TComponent;
  Menu: TPopupMenu;
  Plain, Prepared, Disabled, Hidden, Sub: TMenuItem;
begin
  if FButton = nil then Exit;
  Check(FButton.Select(False), 'the button selected (IOTAComponent.Select)');
  { Delphi 7's designer makes its context menu on a right click only }
  if not D7StudioOnly('the selection editor''s commands in the designer''s context menu (DesignPopup)') then Exit;
  Menu := nil;
  if Application.MainForm <> nil then
  begin
    C := Application.MainForm.FindComponent('DesignPopup');
    if C is TPopupMenu then Menu := TPopupMenu(C);
  end;
  if not Check((Menu <> nil) and Assigned(Menu.OnPopup), 'the designer''s context menu (DesignPopup) makes its items as it opens') then
    Exit;
  Menu.OnPopup(Menu);
  Plain := Menu.Items.Find(SVerbPlain);
  Prepared := Menu.Items.Find(SVerbPrepared);
  Disabled := Menu.Items.Find(SVerbDisabled);
  Hidden := Menu.Items.Find(SVerbHidden);
  if not Check((Plain <> nil) and (Prepared <> nil) and (Disabled <> nil) and (Hidden <> nil),
    'the selection editor''s four commands are in the menu') then Exit;
  Check(Plain.Visible and Plain.Enabled and not Plain.Checked, 'the plain command: shown, enabled');
  Check(Prepared.Checked, 'PrepareItem: checked');
  Sub := nil;
  if Prepared.Count = 1 then Sub := Prepared.Items[0];
  if Check(Sub <> nil, 'PrepareItem: an item of its own (AddItem)') then
    Expect('... its caption', StripHotkey(Sub.Caption), SVerbSub);
  Check(not Disabled.Enabled, 'PrepareItem: disabled');
  Check(not Hidden.Visible, 'PrepareItem: hidden');
  SelectionRuns := 0;
  Plain.Click;
  ExpectInt('the plain command ran its ExecuteVerb', SelectionRuns, 1);
  ExpectInt('... with the selection', SelectionCount, 1);
  Check(SelectionFirst = FButtonHandle, '... the button');
  if Sub <> nil then
  begin
    SubItemSender := nil;
    SubItemEditorAlive := False;
    Sub.Click;
    Check(SubItemSender = Sub, 'the item of its own ran its handler with the menu item as Sender');
    Check(SubItemEditorAlive, '... on the editor that made it (kept while the menu''s items are there)');
  end;
end;

procedure TFormTests.Rename;
var
  S, Old: string;
begin
  if FButton = nil then Exit;
  FButton.GetPropValueByName('Name', Old);
  S := 'OkButton';
  Check(FButton.SetPropByName('Name', S), 'SetPropByName(''Name'')');
  Check(Renamed(Old, 'OkButton', FButtonHandle), 'ComponentRenamed(' + Old + ', OkButton) with the component',
    FForm.Renames.CommaText);
  Check(FormEditor.FindComponent('OkButton') <> nil, 'FindComponent finds the new name');
end;

{ a short string property's value goes as a string (AnsiString) both ways, as Delphi 7 has it
  (measured); a string[5] keeps its first five characters. The unit of a component placed goes into
  the uses clause when the module is saved, and stays when the component is deleted (Delphi 7's,
  measured) }
procedure TFormTests.Props;
var
  F: IOTAFormEditor;
  P: IOTAComponent;
  S, S2: string;
  N: Integer;
begin
  F := FormEditor;
  P := F.CreateComponent(F.GetRootComponent, 'TOtaDemoProbe', 0, 0, 0, 0);
  if not Check(P <> nil, 'CreateComponent of a registered class (TOtaDemoProbe)') then Exit;
  Check(not P.IsTControl, 'a non-visual component is no TControl');
  Check(not InUses('OtaDemoTestForm'), 'the probe''s unit is not in the uses clause yet: it goes there on save');
  S := 'short string value';
  Check(P.SetPropByName('Short', S), 'SetPropByName of a ShortString property, from a string');
  S2 := '';
  Check(P.GetPropValueByName('Short', S2), 'GetPropValueByName of a ShortString property, into a string');
  Expect('the ShortString reads back', S2, 'short string value');
  S := 'abcdefgh';
  Check(P.SetPropByName('Tiny', S), 'SetPropByName of a string[5] property');
  S2 := '';
  Check(P.GetPropValueByName('Tiny', S2), 'GetPropValueByName of a string[5] property');
  Expect('the string[5] keeps its first five characters', S2, 'abcde');
  N := 42;
  Check(P.SetPropByName('Count', N), 'SetPropByName of an Integer property');
  N := 0;
  P.GetPropValueByName('Count', N);
  ExpectInt('the Integer reads back', N, 42);
  Check(Module.Save(False, True), 'the module saved');
  Check(InUses('OtaDemoTestForm'), '... the probe''s unit is in the uses clause now');
  Check(P.Delete, 'the probe deleted again');
  Check(InUses('OtaDemoTestForm'), '... its unit stays in the uses clause');
  RemoveFromUses('OtaDemoTestForm');
end;
{ a save put the unit of a new component into the uses clause; the program, compiled later, has
  no such unit: out again (with its comma) }
procedure TFormTests.RemoveFromUses(const UnitName: string);
var
  SE: IOTASourceEditor;
  Text: string;
  P, S, E: Integer;
  W: IOTAEditWriter;
begin
  SE := SourceEditorOf(Module);
  Text := EditorText(SE);
  P := Pos(UpperCase(UnitName), UpperCase(Text));
  if P = 0 then Exit;
  S := P - 1;                          // 0-based start of the name
  E := S + Length(UnitName);
  { ", Name" - or "Name, " when it is the first }
  while (S > 0) and (Text[S] in [' ', #9, #13, #10]) do Dec(S);
  if (S > 0) and (Text[S] = ',') then Dec(S)
  else
  begin
    S := P - 1;
    while (E < Length(Text)) and (Text[E + 1] in [' ', #9, #13, #10]) do Inc(E);
    if (E < Length(Text)) and (Text[E + 1] = ',') then Inc(E);
  end;
  W := SE.CreateUndoableWriter;
  W.CopyTo(S);
  W.DeleteTo(E);
  W := nil;
  Check(Pos(UpperCase(UnitName), UpperCase(EditorText(SE))) = 0, 'the probe''s unit is out of the uses clause again');
end;

procedure TFormTests.Delete;
begin
  if FButton = nil then Exit;
  Check(FButton.Delete, 'IOTAComponent.Delete');
  Check(Renamed('OkButton', '', FButtonHandle), 'ComponentRenamed(OkButton, '''') with the component',
    FForm.Renames.CommaText);
  Check(FormEditor.FindComponent('OkButton') = nil, 'the button is gone');
  FButton := nil;
end;

procedure TFormTests.DeleteRoot;
begin
  Check(not FormEditor.GetRootComponent.Delete, 'the form itself cannot be deleted: Delete is False');
end;

{ F12 to the code and the designer again: FormActivated }
procedure TFormTests.Activated;
var
  B: IOTAEditBuffer;
  A: IOTAEditActions;
  Before: Integer;
begin
  Before := FForm.Activations;
  B := (BorlandIDEServices as IOTAEditorServices).TopBuffer;
  if not Check((B <> nil) and (B.EditViewCount > 0) and Supports(B.EditViews[0], IOTAEditActions, A),
    'the top view has IOTAEditActions') then Exit;
  A.ToggleFormUnit;
  FormEditor.Show;
  Check(FForm.Activations > Before, 'the designer shown again: FormActivated',
    Format('%d before, %d after', [Before, FForm.Activations]));
end;

function CompileOk(const P: IOTAProject): Boolean;
begin
  Result := P.ProjectBuilder.BuildProject(cmOTAMake, True, True);
end;

{ the names in the uses clauses of a unit's text, upper case (comments and strings skipped) }
procedure UsesNames(const Text: string; Names: TStrings);
var
  I, N, Start: Integer;
  Word: string;
  InUses: Boolean;
begin
  N := Length(Text);
  I := 1;
  InUses := False;
  while I <= N do
    case Text[I] of
      '{':
        begin
          while (I <= N) and (Text[I] <> '}') do Inc(I);
          Inc(I);
        end;
      '/':
        if (I < N) and (Text[I + 1] = '/') then
          while (I <= N) and not (Text[I] in [#13, #10]) do Inc(I)
        else
          Inc(I);
      '''':
        begin
          Inc(I);
          while (I <= N) and (Text[I] <> '''') do Inc(I);
          Inc(I);
        end;
      ';':
        begin
          InUses := False;
          Inc(I);
        end;
      'A'..'Z', 'a'..'z', '_':
        begin
          Start := I;
          while (I <= N) and (Text[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.']) do Inc(I);
          Word := UpperCase(Copy(Text, Start, I - Start));
          if Word = 'USES' then InUses := True
          else if InUses and (Word <> 'IN') then Names.Add(Word);
        end;
    else
      Inc(I);
    end;
end;
function TFormTests.InUses(const UnitName: string): Boolean;
var
  Names: TStringList;
begin
  Names := TStringList.Create;
  try
    UsesNames(EditorText(SourceEditorOf(Module)), Names);
    Result := Names.IndexOf(UpperCase(UnitName)) >= 0;
  finally
    Names.Free;
  end;
end;

{ a component placed and the project compiled at once: the compile puts the component's unit into
  the uses clause first, as a save does - the field's type needs it }
procedure TFormTests.UsesOnCompile;
var
  F: IOTAFormEditor;
  C: IOTAComponent;
begin
  F := FormEditor;
  if InUses('ExtCtrls') then RemoveFromUses('ExtCtrls');
  C := F.CreateComponent(F.GetRootComponent, 'TTimer', 0, 0, 0, 0);
  if not Check(C <> nil, 'CreateComponent(TTimer)') then Exit;
  Check(not InUses('ExtCtrls'), 'ExtCtrls is not in the uses clause yet');
  Check(CompileOk(GetActiveProject), 'the project compiles');
  Check(InUses('ExtCtrls'), '... ExtCtrls is in the uses clause now');
  Check(C.Delete, 'the timer deleted again');
end;
procedure TFormTests.Saving;
var
  Before: Integer;
begin
  Before := FForm.Savings;
  Check(CompileOk(GetActiveProject), 'the project compiles');
  Check(FForm.Savings > Before, 'a compile streams the form: FormSaving');
end;

procedure TFormTests.TakeOff;
begin
  Check((BorlandIDEServices as IOTAModuleServices).SaveAll, 'saved');
end;

initialization
  RegisterClass(TOtaDemoProbe);
  RegisterTestArea(TFormTests, 70);

finalization
  UnRegisterClass(TOtaDemoProbe);
end.
