{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit MigDlg;

{ migrate - Migrate from Delphi 7, the dialog of migrate.exe started without arguments (from
  Explorer, Setup's last page, D7 Studio's Tools menu): what of Delphi 7's configuration to take
  into D7 Studio's, as a tree with check boxes - the groups (MigCore.MigGroups), their parts
  (MigParts) and, below the parts that have them, the items of Delphi 7's configuration (ListItems:
  its design packages, DLL experts, keys of experts' settings, tools and environment variables); a
  node's box is mixed when only some of the nodes below it are checked -, and Migrate. A part is
  taken when its box is checked or mixed; an item whose box is not checked is left out
  (MigCore.Excluded, <part>:<name>).

  Each migration writes its report, whose first lines name the folders and keys (MigCore's
  variables, which Execute sets), to migrate.log beside D7Studio.ini. One that succeeds closes the
  dialog; one that fails shows the report below the tree (mmReport, which then takes the lower part
  of the tree's place) and the dialog stays. Closed before Migrate was clicked, it asks first.

  D7 Studio of the folder may run (its Tools menu starts the dialog): the migration goes on, as D7
  Studio writes only what it changed itself when it closes, and the dialog says that the migrated
  settings count from its next start. }

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, Dialogs, StdCtrls, ExtCtrls, ComCtrls, ImgList;

type
  TMigrateDlg = class(TForm)
    lblNote: TLabel;
    gbParts: TGroupBox;
    tvParts: TTreeView;
    mmReport: TMemo;
    cbOverwrite: TCheckBox;
    Checks: TImageList;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnMigrate: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure btnMigrateClick(Sender: TObject);
    procedure tvPartsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure tvPartsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure tvPartsKeyPress(Sender: TObject; var Key: Char);
  private
    FTried: Boolean;    // Migrate was clicked
    { what each node stands for (its Data is the index): a part's name, <part>:<name> for an item,
      '' for a group of several parts }
    FKeys: TStringList;
    FMenuNode: TTreeNode;   // the part Menu templates
    FReport: TStringList;   // the report of the last migration
    procedure FillTree;
    function AddNode(Parent: TTreeNode; const Text, Key: string): TTreeNode;
    function NodeKey(Node: TTreeNode): string;
    procedure Toggle(Node: TTreeNode);
    procedure Changed;
    procedure AddLine(const Line: string);
    procedure SaveReport;
    procedure ShowReport;
  public
    { from Delphi 7 (its folder - '' its RootDir -, its key under HKEY_CURRENT_USER) into D7 Studio
      (its folder, the folder of its D7Studio.ini, its key); the folders with or without a trailing
      backslash }
    class procedure Execute(AOwner: TComponent; const ADelphiRoot, ADelphiKey, AStudioRoot, ASettingsDir,
      AStudioKey: string);
  end;

var
  MigrateDlg: TMigrateDlg;

implementation

uses
  IniFiles, Graphics, MigCore, SdCheckImages;

{$R *.dfm}

const
  { the part whose box enables Replace D7 Studio's menu templates }
  MenuTemplatesPart = 'files.menutemplates';
  { the report's file, in the folder of D7Studio.ini }
  ReportName = 'migrate.log';

procedure TMigrateDlg.FormCreate(Sender: TObject);
begin
  FKeys := TStringList.Create;
  FReport := TStringList.Create;
  MakeCheckImages(Checks);
  FillTree;
  Changed;
end;

procedure TMigrateDlg.FormDestroy(Sender: TObject);
begin
  FReport.Free;
  FKeys.Free;
end;

{ D7 Studio's [UI] DialogBackground in the D7Studio.ini of SettingsDir: 1 the button face }
function DialogBackgroundGrey: Boolean;
var
  Ini: TIniFile;
begin
  Result := False;
  if not FileExists(IncludeTrailingPathDelimiter(SettingsDir) + 'D7Studio.ini') then Exit;
  Ini := TIniFile.Create(IncludeTrailingPathDelimiter(SettingsDir) + 'D7Studio.ini');
  try
    Result := Ini.ReadInteger('UI', 'DialogBackground', 0) = 1;
  finally
    Ini.Free;
  end;
end;

class procedure TMigrateDlg.Execute(AOwner: TComponent; const ADelphiRoot, ADelphiKey, AStudioRoot,
  ASettingsDir, AStudioKey: string);
var
  F: TMigrateDlg;
begin
  DelphiKey := ExcludeTrailingPathDelimiter(ADelphiKey);
  DelphiRoot := ExcludeTrailingPathDelimiter(ADelphiRoot);
  FindDelphiRoot;
  StudioRoot := ExcludeTrailingPathDelimiter(AStudioRoot);
  SettingsDir := ExcludeTrailingPathDelimiter(ASettingsDir);
  StudioKey := ExcludeTrailingPathDelimiter(AStudioKey);
  F := TMigrateDlg.Create(AOwner);
  try
    { D7 Studio's Dialog background: the body grey when its settings say so }
    if DialogBackgroundGrey then F.Color := clBtnFace;
    F.ShowModal;
  finally
    F.Free;
  end;
end;

function TMigrateDlg.AddNode(Parent: TTreeNode; const Text, Key: string): TTreeNode;
begin
  Result := tvParts.Items.AddChildObject(Parent, Text, Pointer(FKeys.Add(Key)));
  Result.StateIndex := ciChecked;
end;

function TMigrateDlg.NodeKey(Node: TTreeNode): string;
begin
  Result := FKeys[Integer(Node.Data)];
end;

{ the groups with their parts, a part with its items: all checked; the groups open, the lists of
  items closed (a part with items shows their number) }
procedure TMigrateDlg.FillTree;
var
  Items, ItemPart, ItemKey, ItemText: TStringList;
  G, P, I, N: Integer;
  Group, Node: TTreeNode;
  S: string;
begin
  Items := TStringList.Create;
  ItemPart := TStringList.Create;
  ItemKey := TStringList.Create;
  ItemText := TStringList.Create;
  tvParts.Items.BeginUpdate;
  try
    { the items, lines <part> #9 <name> #9 <caption>: their parts, keys and texts }
    ListItems(Items);
    for I := 0 to Items.Count - 1 do
    begin
      S := Items[I];
      ItemPart.Add(Copy(S, 1, Pos(#9, S) - 1));
      Delete(S, 1, Pos(#9, S));
      ItemKey.Add(ItemPart[I] + ':' + Copy(S, 1, Pos(#9, S) - 1));
      ItemText.Add(Copy(S, Pos(#9, S) + 1, MaxInt));
    end;
    tvParts.Items.Clear;
    FKeys.Clear;
    for G := 0 to GroupCount - 1 do
    begin
      Group := nil;
      for P := 0 to PartCount - 1 do
      begin
        if PartGroup(MigParts[P].Name) <> MigGroups[G].Name then Continue;
        N := 0;
        for I := 0 to ItemPart.Count - 1 do
          if ItemPart[I] = MigParts[P].Name then Inc(N);
        S := MigParts[P].Caption;
        if N > 0 then S := Format('%s (%d)', [S, N]);
        if MigParts[P].Name = MigGroups[G].Name then
          Node := AddNode(nil, S, MigParts[P].Name)
        else
        begin
          if Group = nil then Group := AddNode(nil, MigGroups[G].Caption, '');
          Node := AddNode(Group, S, MigParts[P].Name);
        end;
        if MigParts[P].Name = MenuTemplatesPart then FMenuNode := Node;
        if N > 0 then
          for I := 0 to ItemPart.Count - 1 do
            if ItemPart[I] = MigParts[P].Name then AddNode(Node, ItemText[I], ItemKey[I]);
      end;
      if Group <> nil then Group.Expand(False);
    end;
    if tvParts.Items.Count > 0 then tvParts.Selected := tvParts.Items[0];
  finally
    tvParts.Items.EndUpdate;
    ItemText.Free;
    ItemKey.Free;
    ItemPart.Free;
    Items.Free;
  end;
end;

{ Node's box checked, or not when it is checked (SdCheckImages.ToggleCheck) }
procedure TMigrateDlg.Toggle(Node: TTreeNode);
begin
  if Node = nil then Exit;
  ToggleCheck(Node);
  Changed;
end;

{ Migrate with a part to take; Replace ... menu templates with its part }
procedure TMigrateDlg.Changed;
var
  Node: TTreeNode;
begin
  { a node of the first level that is not unchecked: the groups' boxes follow their parts' }
  Node := tvParts.Items.GetFirstNode;
  while (Node <> nil) and (Node.StateIndex = ciUnchecked) do Node := Node.GetNextSibling;
  btnMigrate.Enabled := Node <> nil;
  cbOverwrite.Enabled := (FMenuNode <> nil) and (FMenuNode.StateIndex <> ciUnchecked);
end;

procedure TMigrateDlg.tvPartsMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbLeft) and (htOnStateIcon in tvParts.GetHitTestInfoAt(X, Y)) then
    Toggle(tvParts.GetNodeAt(X, Y));
end;

procedure TMigrateDlg.tvPartsKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_SPACE) and (Shift = []) then
  begin
    Toggle(tvParts.Selected);
    Key := 0;
  end;
end;

{ the Space that toggled a box does not go on to the tree's incremental search (which beeps) }
procedure TMigrateDlg.tvPartsKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = ' ' then Key := #0;
end;

procedure TMigrateDlg.AddLine(const Line: string);
begin
  FReport.Add(Line);
end;

{ the report into migrate.log beside D7Studio.ini; a file that cannot be written is said in the
  report }
procedure TMigrateDlg.SaveReport;
var
  FileName: string;
begin
  FileName := SettingsDir + '\' + ReportName;
  try
    FReport.SaveToFile(FileName);
  except
    on E: Exception do AddLine(Format('The report could not be written to %s: %s', [FileName, E.Message]));
  end;
end;

{ the report below the tree, its end in view (where a failure is said): the group box ends above
  it, as far from it as from the check box below it, and the tree, anchored to the group box,
  follows }
procedure TMigrateDlg.ShowReport;
var
  Gap: Integer;
begin
  if not mmReport.Visible then
  begin
    Gap := cbOverwrite.Top - (gbParts.Top + gbParts.Height);
    gbParts.Height := mmReport.Top - Gap - gbParts.Top;
    mmReport.Visible := True;
  end;
  mmReport.Lines.Text := FReport.Text;
  mmReport.Perform(EM_SETSEL, MaxInt, MaxInt);
  mmReport.Perform(EM_SCROLLCARET, 0, 0);
end;

{ the parts whose boxes are checked or mixed, without the items whose boxes are not checked; the
  dialog closes when the migration succeeds, else shows its report }
procedure TMigrateDlg.btnMigrateClick(Sender: TObject);
var
  Parts: TStringList;
  Node: TTreeNode;
  Key: string;
  Done, Running: Boolean;
begin
  FTried := True;
  Done := False;
  Running := False;
  Parts := TStringList.Create;
  Screen.Cursor := crHourGlass;
  try
    FReport.Clear;
    Excluded.Clear;
    Node := tvParts.Items.GetFirstNode;
    while Node <> nil do
    begin
      Key := NodeKey(Node);
      if Pos(':', Key) > 0 then
      begin
        if Node.StateIndex = ciUnchecked then Excluded.Add(LowerCase(Key));
      end
      else if (Key <> '') and (Node.StateIndex <> ciUnchecked) then
        Parts.Add(Key);
      Node := Node.GetNext;
    end;
    WhatIf := False;
    Overwrite := cbOverwrite.Enabled and cbOverwrite.Checked;
    OnReport := AddLine;
    AddLine(Format('Migrate from Delphi 7, %s', [DateTimeToStr(Now)]));
    try
      if not IsStudioFolder(StudioRoot) then
        AddLine(StudioRoot + ' is not a D7 Studio folder (it has no D7Studio.exe)')
      else
      begin
        Running := StudioRunning;
        Done := RunMigration(Parts, Running);
      end;
    except
      on E: Exception do AddLine('Error: ' + E.Message);
    end;
    OnReport := nil;
    SaveReport;
  finally
    OnReport := nil;
    Screen.Cursor := crDefault;
    Parts.Free;
  end;
  if Done then
  begin
    if Running then
      MessageDlg('The configuration of Delphi 7 is migrated. D7 Studio uses it when it starts again.',
        mtInformation, [mbOK], 0);
    ModalResult := mrOk;
  end
  else
    ShowReport;
end;

{ Cancel, Esc or the close box before Migrate was clicked: asked first }
procedure TMigrateDlg.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  if (ModalResult <> mrOk) and not FTried then
    CanClose := MessageDlg('Close without migrating the configuration of Delphi 7?', mtConfirmation,
      [mbYes, mbNo], 0) = mrYes;
end;

end.
