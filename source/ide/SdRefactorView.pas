{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdRefactorView;

{ D7 Studio - the Refactorings view: what a refactoring will change, before it changes it. A row
  per file with its changes below it (the line and what it becomes), what to know about them first;
  beside the tree the chosen file before and after the refactoring, compared in the code editor as the
  History tab compares (SdDiffPane), the chosen change in view. Apply makes the changes, Discard drops
  them. A form made once (its controls in the .dfm), docked by the IDE. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls,
  ToolWin, Menus, ActnList,
  SdUI, SdIcons, SdRefactor, SdDiffPane, SdTextDiff, SdEncoding;

type
  { a change opened: its file and line }
  TRefOpenEvent = procedure(Sender: TObject; const FileName: string; Line: Integer) of object;
  { the encoding of a file's text as the refactoring read it }
  TRefEncodingEvent = function(const FileName: string): TSdEncoding of object;

  TRefactoringsView = class(TForm)
    Bar: TToolBar;
    tbApply: TToolButton;
    tbDiscard: TToolButton;
    Tree: TTreeView;
    Splitter: TSplitter;
    DiffHost: TPanel;
    Actions: TActionList;
    aApply: TAction;
    aDiscard: TAction;
    RefPopup: TPopupMenu;
    pmApply: TMenuItem;
    pmDiscard: TMenuItem;
    procedure aApplyExecute(Sender: TObject);
    procedure aDiscardExecute(Sender: TObject);
    procedure ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
    procedure TreeChange(Sender: TObject; Node: TTreeNode);
    procedure TreeDblClick(Sender: TObject);
    procedure RefPopupPopup(Sender: TObject);
  private
    FPlan: TRefactoring;
    FOnApply: TNotifyEvent;
    FOnDiscard: TNotifyEvent;
    FOnOpen: TRefOpenEvent;
    FOnMenuPopup: TNotifyEvent;
    FOnEncoding: TRefEncodingEvent;
    FOnZoom: TNotifyEvent;
    FPane: TSdDiffPane;
    FShownFile: string;                // the file the pane compares ('': none)
    procedure ShowChange(Node: TTreeNode);
    procedure PaneOpenLine(Sender: TObject);
    procedure PaneZoomed(Sender: TObject);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { a refactoring's changes to show (the view owns it from now on) }
    procedure ShowPlan(R: TRefactoring);
    { no changes any more }
    procedure Clear;
    { the editor's options changed: the comparison takes them }
    procedure OptionsChanged;
    { the changes shown (nil: none) }
    property Plan: TRefactoring read FPlan;
    { a summary for the status line: "n changes in m files" }
    function Summary: string;
    property OnApply: TNotifyEvent read FOnApply write FOnApply;
    property OnDiscard: TNotifyEvent read FOnDiscard write FOnDiscard;
    property OnOpen: TRefOpenEvent read FOnOpen write FOnOpen;
    property OnEncoding: TRefEncodingEvent read FOnEncoding write FOnEncoding;
    { Ctrl+wheel in the comparison: the editors' zoom changed }
    property OnZoom: TNotifyEvent read FOnZoom write FOnZoom;
    { the menu opens (before its own states): the dock commands' states }
    property OnMenuPopup: TNotifyEvent read FOnMenuPopup write FOnMenuPopup;
  end;

implementation

{$R *.dfm}

constructor TRefactoringsView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form docked as a child keeps its own font }
  UIApplyFont(Self);
  InitIcons;
  Tree.Images := IconList;
  Actions.Images := IconList;
  RefPopup.Images := IconList;
  Bar.Images := IconList;
  UIOwnerDrawMenus(Self);
  UITreeNoDblClickToggle(Tree);
  FPane := TSdDiffPane.Create(Self);
  FPane.Parent := DiffHost;
  FPane.Align := alClient;
  FPane.OnOpenLine := PaneOpenLine;
  FPane.OnZoom := PaneZoomed;
  FPane.LeftWindow.PopupMenu := RefPopup;
  FPane.RightWindow.PopupMenu := RefPopup;
end;

destructor TRefactoringsView.Destroy;
begin
  FreeAndNil(FPlan);
  inherited Destroy;
end;

{ No flicker: the tree and the preview fill the view - the view paints nothing over them
  (WS_CLIPCHILDREN) and, a form, has no CS_HREDRAW / CS_VREDRAW }
procedure TRefactoringsView.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

procedure TRefactoringsView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TRefactoringsView.OptionsChanged;
begin
  FPane.ApplyOptions;
end;

{ the first line of a text, trimmed, with how many more lines it has }
function FirstLine(const S: string): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := S;
    if L.Count = 0 then Result := '' else Result := Trim(L[0]);
    if L.Count > 1 then Result := Result + Format('  (+%d lines)', [L.Count - 1]);
  finally
    L.Free;
  end;
end;

procedure TRefactoringsView.ShowPlan(R: TRefactoring);
var
  Files: TStringList;
  I, J, N: Integer;
  FN, NN: TTreeNode;
  L: TRefLine;
  S: string;
begin
  Tree.Items.BeginUpdate;
  try
    Tree.Items.Clear;
    FreeAndNil(FPlan);
    FPlan := R;
    FShownFile := '';
    if R = nil then Exit;
    if R.Notes.Count > 0 then
    begin
      NN := Tree.Items.AddChild(nil, 'Before you apply');
      NN.ImageIndex := Ord(iiWarning) - 1;
      NN.SelectedIndex := NN.ImageIndex;
      for I := 0 to R.Notes.Count - 1 do
        with Tree.Items.AddChild(NN, R.Notes[I]) do
        begin
          ImageIndex := -1;
          SelectedIndex := -1;
        end;
      NN.Expand(True);
    end;
    Files := TStringList.Create;
    try
      R.GetFiles(Files);
      for I := 0 to Files.Count - 1 do
      begin
        N := 0;
        for J := 0 to R.Lines.Count - 1 do
          if SameText(TRefLine(R.Lines[J]).FileName, Files[I]) then Inc(N);
        S := ExtractFileName(Files[I]) + '  ' + ExtractFileDir(Files[I]);
        if N = 1 then S := S + '  (1 change)' else S := S + Format('  (%d changes)', [N]);
        FN := Tree.Items.AddChildObject(nil, S, nil);
        if SameText(ExtractFileExt(Files[I]), '.dfm') then FN.ImageIndex := Ord(iiViewForm) - 1
        else FN.ImageIndex := Ord(iiUnit) - 1;
        FN.SelectedIndex := FN.ImageIndex;
        for J := 0 to R.Lines.Count - 1 do
        begin
          L := TRefLine(R.Lines[J]);
          if not SameText(L.FileName, Files[I]) then Continue;
          with Tree.Items.AddChildObject(FN, Format('%d:  %s', [L.Line, FirstLine(L.After)]), L) do
          begin
            ImageIndex := -1;
            SelectedIndex := -1;
          end;
        end;
        FN.Expand(False);
      end;
    finally
      Files.Free;
    end;
    if Tree.Items.Count > 0 then Tree.Selected := Tree.Items[0];
  finally
    Tree.Items.EndUpdate;
  end;
  ShowChange(Tree.Selected);
end;

procedure TRefactoringsView.Clear;
begin
  Tree.Items.BeginUpdate;
  try
    Tree.Items.Clear;
    FreeAndNil(FPlan);
  finally
    Tree.Items.EndUpdate;
  end;
  FShownFile := '';
  FPane.Clear;
end;

function TRefactoringsView.Summary: string;
var
  Files: TStringList;
begin
  Result := '';
  if FPlan = nil then Exit;
  Files := TStringList.Create;
  try
    FPlan.GetFiles(Files);
    Result := FPlan.Title + ': ';
    if FPlan.Lines.Count = 1 then Result := Result + '1 change' else Result := Result + Format('%d changes', [FPlan.Lines.Count]);
    if Files.Count = 1 then Result := Result + ' in 1 file' else Result := Result + Format(' in %d files', [Files.Count]);
  finally
    Files.Free;
  end;
end;

{ the chosen change's file compared before and after the refactoring, the change in view; a file's row:
  its first change; the notes: nothing compared }
procedure TRefactoringsView.ShowChange(Node: TTreeNode);
var
  L: TRefLine;
  F: string;
begin
  L := nil;
  if (FPlan <> nil) and (Node <> nil) then
    if Node.Data <> nil then L := TRefLine(Node.Data)
    else if (Node.Parent = nil) and (Node.Count > 0) and (Node.Item[0].Data <> nil) then L := TRefLine(Node.Item[0].Data);
  if L = nil then
  begin
    FShownFile := '';
    FPane.Clear;
    Exit;
  end;
  F := L.FileName;
  if not SameText(F, FShownFile) then
  begin
    FPane.FileName := F;
    if Assigned(FOnEncoding) then FPane.Encoding := FOnEncoding(F) else FPane.Encoding := SystemEncoding;
    FPane.Compare(FPlan.Source(F), FPlan.NewText(F), False);
    FShownFile := F;
  end;
  FPane.ShowLine(dsOld, L.Line - 1);
end;

{ a double click, or Enter, in the comparison: that line of the file now }
procedure TRefactoringsView.PaneOpenLine(Sender: TObject);
var
  N: Integer;
begin
  if (FShownFile = '') or not Assigned(FOnOpen) then Exit;
  N := FPane.CaretTextLine(dsOld);
  if N >= 0 then FOnOpen(Self, FShownFile, N + 1);
end;

procedure TRefactoringsView.PaneZoomed(Sender: TObject);
begin
  if Assigned(FOnZoom) then FOnZoom(Self);
end;
procedure TRefactoringsView.TreeChange(Sender: TObject; Node: TTreeNode);
begin
  ShowChange(Node);
end;

procedure TRefactoringsView.TreeDblClick(Sender: TObject);
var
  N: TTreeNode;
begin
  N := Tree.Selected;
  if (N = nil) or (N.Data = nil) or not Assigned(FOnOpen) then Exit;
  FOnOpen(Self, TRefLine(N.Data).FileName, TRefLine(N.Data).Line);
end;

procedure TRefactoringsView.aApplyExecute(Sender: TObject);
begin
  if (FPlan <> nil) and Assigned(FOnApply) then FOnApply(Self);
end;

procedure TRefactoringsView.aDiscardExecute(Sender: TObject);
begin
  if Assigned(FOnDiscard) then FOnDiscard(Self);
end;

procedure TRefactoringsView.ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
begin
  aApply.Enabled := (FPlan <> nil) and (FPlan.EditCount > 0);
  aDiscard.Enabled := FPlan <> nil;
  Handled := True;
end;

procedure TRefactoringsView.RefPopupPopup(Sender: TObject);
begin
  if Assigned(FOnMenuPopup) then FOnMenuPopup(Sender);
end;

end.
