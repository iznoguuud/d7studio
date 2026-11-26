{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdVarLists;

{ D7 Studio - the two lists of Delphi 7's environment variable frame: "System variables" and
  "User overrides", with its commands Add Override, New, Edit, Delete. Used by Environment
  Options | Environment Variables and Run | Parameters | Environment Block. }

interface

uses
  SysUtils, Classes, ComCtrls, ActnList;

type
  TSdVarLists = class
  private
    FSystem, FUser: TListView;
    FOverride: TAction;
    procedure Put(List: TListView; const Name, Value: string);
    function Entry(const Caption: string; var Name, Value: string): Boolean;
    procedure OverrideExecute(Sender: TObject);     // the selected system variable, to be changed
    procedure NewExecute(Sender: TObject);
    procedure EditExecute(Sender: TObject);
    procedure DeleteExecute(Sender: TObject);
    procedure SelectedUpdate(Sender: TObject);
  public
    { the two lists and the dialog's actions of the commands: their handlers are set here (both
      dialogs share them; a double click on an override runs the Edit action, in the dialog's .dfm) }
    constructor Create(ASystem, AUser: TListView; AOverride, ANew, AEdit, ADelete: TAction);
    { fills both lists: the system's variables and the overrides (Name=Value) }
    procedure Fill(Overrides: TStrings);
    procedure GetOverrides(List: TStrings);
  end;

implementation

uses
  SdEnvOptions, SdDialogs;

constructor TSdVarLists.Create(ASystem, AUser: TListView; AOverride, ANew, AEdit, ADelete: TAction);
begin
  inherited Create;
  FSystem := ASystem;
  FUser := AUser;
  FOverride := AOverride;
  AOverride.OnExecute := OverrideExecute;
  AOverride.OnUpdate := SelectedUpdate;
  ANew.OnExecute := NewExecute;
  AEdit.OnExecute := EditExecute;
  AEdit.OnUpdate := SelectedUpdate;
  ADelete.OnExecute := DeleteExecute;
  ADelete.OnUpdate := SelectedUpdate;
end;

procedure TSdVarLists.Put(List: TListView; const Name, Value: string);
var
  I: Integer;
  It: TListItem;
begin
  It := nil;
  for I := 0 to List.Items.Count - 1 do
    if SameText(List.Items[I].Caption, Name) then It := List.Items[I];
  if It = nil then
  begin
    It := List.Items.Add;
    It.Caption := Name;
    It.SubItems.Add(Value);
  end
  else
    It.SubItems[0] := Value;
  List.AlphaSort;
  It.Selected := True;
  It.MakeVisible(False);
end;

{ List with the variables of Values (Name=Value), sorted }
procedure FillList(List: TListView; Values: TStrings);
var
  I: Integer;
  It: TListItem;
begin
  List.Items.BeginUpdate;
  try
    List.Items.Clear;
    for I := 0 to Values.Count - 1 do
    begin
      It := List.Items.Add;
      It.Caption := Values.Names[I];
      It.SubItems.Add(Values.ValueFromIndex[I]);
    end;
    List.AlphaSort;
  finally
    List.Items.EndUpdate;
  end;
end;

procedure TSdVarLists.Fill(Overrides: TStrings);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    GetSystemVariables(L);
    FillList(FSystem, L);
  finally
    L.Free;
  end;
  FillList(FUser, Overrides);
end;

procedure TSdVarLists.GetOverrides(List: TStrings);
var
  I: Integer;
begin
  List.Clear;
  for I := 0 to FUser.Items.Count - 1 do
    List.Add(FUser.Items[I].Caption + '=' + FUser.Items[I].SubItems[0]);
end;

{ Add Override needs a system variable, Edit and Delete an override }
procedure TSdVarLists.SelectedUpdate(Sender: TObject);
begin
  if Sender = FOverride then TAction(Sender).Enabled := FSystem.Selected <> nil
  else TAction(Sender).Enabled := FUser.Selected <> nil;
end;

function TSdVarLists.Entry(const Caption: string; var Name, Value: string): Boolean;
begin
  Result := VariableEntryDialog(FUser.Owner, Caption, Name, Value) and (Trim(Name) <> '');
  Name := Trim(Name);
end;

procedure TSdVarLists.OverrideExecute(Sender: TObject);
var
  N, V: string;
begin
  if FSystem.Selected = nil then Exit;
  N := FSystem.Selected.Caption;
  V := FSystem.Selected.SubItems[0];
  if Entry('Override System Variable', N, V) then Put(FUser, N, V);
end;

procedure TSdVarLists.NewExecute(Sender: TObject);
var
  N, V: string;
begin
  N := '';
  V := '';
  if Entry('New User Variable', N, V) then Put(FUser, N, V);
end;

procedure TSdVarLists.EditExecute(Sender: TObject);
var
  N, V: string;
begin
  if FUser.Selected = nil then Exit;
  N := FUser.Selected.Caption;
  V := FUser.Selected.SubItems[0];
  if Entry('Edit User Variable', N, V) then
  begin
    if not SameText(N, FUser.Selected.Caption) then FUser.Selected.Delete;
    Put(FUser, N, V);
  end;
end;

procedure TSdVarLists.DeleteExecute(Sender: TObject);
begin
  if FUser.Selected <> nil then FUser.Selected.Delete;
end;

end.
