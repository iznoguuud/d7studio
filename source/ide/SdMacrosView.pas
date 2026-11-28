{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdMacrosView;

{ D7 Studio - the Macro Library view: the keystroke macros of SdMacros' library in a list - their
  names, their number of keys, what they do -, the current one (the macro Shift+Ctrl+P plays)
  marked by its icon. A macro chosen in the list becomes the current one (OnChoose); Play plays it
  in the active code editor, Repeat as many times as asked (OnPlay: the IDE does both), also a
  double click and Enter; Record is the IDE's Record Macro (OnRecord). Rename edits the name in
  the list (F2), Delete (Del), Move Up and Move Down change the library, Import and Export read and
  write macro files (*.d7macros; files dropped on the list are imported); OnChange then lets the
  IDE keep the library. A form made once, docked by the IDE: its tool bar goes to its panel of the
  dock (TSdDockPanel.ToolBar), the dock's commands to the end of its menu (TMainForm.AddDockItems). }

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, ComCtrls, ToolWin, Menus, ActnList,
  SdUI, SdIcons, SdMacros;

const
  { the image of Record Macro and of the view's Record: while the IDE's macro records (True) they stop it }
  MacroRecordIcons: array[Boolean] of TSdIcon = (iiMacroRecord, iiStop);

type
  { Repeated: Play Repeatedly (the IDE asks how many times) }
  TMacroPlayEvent = procedure(Sender: TObject; Repeated: Boolean) of object;

  TMacrosView = class(TForm)
    Bar: TToolBar;
    tbRecord: TToolButton;
    tbPlay: TToolButton;
    tbRepeat: TToolButton;
    tbSep1: TToolButton;
    tbRename: TToolButton;
    tbDelete: TToolButton;
    tbUp: TToolButton;
    tbDown: TToolButton;
    tbSep2: TToolButton;
    tbImport: TToolButton;
    tbExport: TToolButton;
    MacroList: TListView;
    Actions: TActionList;
    aMacRecord: TAction;
    aMacPlay: TAction;
    aMacRepeat: TAction;
    aMacRename: TAction;
    aMacDelete: TAction;
    aMacUp: TAction;
    aMacDown: TAction;
    aMacImport: TAction;
    aMacExport: TAction;
    MacroPopup: TPopupMenu;
    pmRecord: TMenuItem;
    pmSep1: TMenuItem;
    pmPlay: TMenuItem;
    pmRepeat: TMenuItem;
    pmSep2: TMenuItem;
    pmRename: TMenuItem;
    pmDelete: TMenuItem;
    pmSep3: TMenuItem;
    pmUp: TMenuItem;
    pmDown: TMenuItem;
    pmSep4: TMenuItem;
    pmImport: TMenuItem;
    pmExport: TMenuItem;
    procedure ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
    procedure Command(Sender: TObject);
    procedure MacroListDblClick(Sender: TObject);
    procedure MacroListEdited(Sender: TObject; Item: TListItem; var S: string);
    procedure MacroListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure MacroListSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure MenuPopup(Sender: TObject);
  private
    FMacros: TSdMacroLibrary;
    FCanRecord, FCanPlay, FRecording: Boolean;
    FFilling: Boolean;
    FOnPlay: TMacroPlayEvent;
    FOnRecord, FOnChoose, FOnChange, FOnMenuPopup: TNotifyEvent;
    procedure Changed;
    procedure UpdateCommands;
    { A, its state made current first, when it is enabled: a double click's and a key's command }
    procedure RunCommand(A: TAction);
    { a message box of the view, its answer }
    function Ask(const Text: string; Flags: UINT): Integer;
    { the macros chosen in the list, in its order }
    procedure SelectedMacros(L: TList);
    procedure ImportFiles(Files: TStrings);
    procedure FilesDropped(Control: TControl; Files: TStrings);
    procedure DeleteSelected;
    procedure ExportSelected;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  public
    constructor Create(AOwner: TComponent); override;
    { the list again from the library; Select: the index chosen then (-1: the one chosen before) }
    procedure Fill(Select: Integer = -1);
    { the current macro's mark (its icon) on its row, none on the others }
    procedure MarkCurrent;
    { the index in the library of the macro chosen (-1: none, or several) }
    function SelectedIndex: Integer;
    { what the IDE allows now: Record (or stop, while Recording), Play in a code editor }
    procedure SetState(CanRecord, CanPlay, Recording: Boolean);
    property Macros: TSdMacroLibrary read FMacros write FMacros;
    property OnPlay: TMacroPlayEvent read FOnPlay write FOnPlay;
    property OnRecord: TNotifyEvent read FOnRecord write FOnRecord;
    property OnChoose: TNotifyEvent read FOnChoose write FOnChoose;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    { a menu opens (before the view's states): the dock commands' states }
    property OnMenuPopup: TNotifyEvent read FOnMenuPopup write FOnMenuPopup;
  end;

implementation

uses
  SdDialogs;

{$R *.dfm}

constructor TMacrosView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form docked as a child keeps its own font }
  UIApplyFont(Self);
  InitIcons;
  { the IDE's icons: the main form's list, there at run time only }
  Actions.Images := IconList;
  Bar.Images := IconList;
  MacroPopup.Images := IconList;
  MacroList.SmallImages := IconList;
  UIOwnerDrawMenus(Self);
  AcceptFileDrops(MacroList, FilesDropped);
end;

{ No flicker: the list fills the view, which the dock resizes with it - the view paints nothing
  over it (WS_CLIPCHILDREN) and, a form, has no CS_HREDRAW / CS_VREDRAW }
procedure TMacrosView.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

{ the list covers the whole view: nothing of the form shows, nothing to erase }
procedure TMacrosView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TMacrosView.Fill(Select: Integer);
var
  I: Integer;
  It: TListItem;
  M: TSdMacro;
begin
  if FMacros = nil then Exit;
  if Select < 0 then Select := SelectedIndex;
  FFilling := True;
  MacroList.Items.BeginUpdate;
  try
    MacroList.Items.Clear;
    for I := 0 to FMacros.Count - 1 do
    begin
      M := FMacros[I];
      It := MacroList.Items.Add;
      It.Caption := M.Name;
      It.Data := M;
      It.SubItems.Add(IntToStr(M.Items.Count));
      It.SubItems.Add(MacroText(M.Items));
    end;
    MarkCurrent;
    if (Select >= 0) and (Select < MacroList.Items.Count) then
    begin
      UIChooseItem(MacroList.Items[Select]);
    end;
  finally
    MacroList.Items.EndUpdate;
    FFilling := False;
  end;
end;

procedure TMacrosView.MarkCurrent;
var
  I, Image: Integer;
begin
  for I := 0 to MacroList.Items.Count - 1 do
  begin
    if I = FMacros.Current then Image := IconIndex(iiMacroPlay) else Image := -1;
    if MacroList.Items[I].ImageIndex <> Image then MacroList.Items[I].ImageIndex := Image;
  end;
end;

function TMacrosView.SelectedIndex: Integer;
begin
  if (MacroList.SelCount = 1) and (MacroList.Selected <> nil) then Result := MacroList.Selected.Index
  else Result := -1;
end;

procedure TMacrosView.SetState(CanRecord, CanPlay, Recording: Boolean);
const
  Captions: array[Boolean] of string = ('Record', 'Stop');
  Hints: array[Boolean] of string = ('Record a macro', 'Stop recording the macro');
begin
  FCanRecord := CanRecord;
  FCanPlay := CanPlay;
  if Recording = FRecording then Exit;
  FRecording := Recording;
  { the button that starts the recording stops it }
  aMacRecord.Caption := Captions[Recording];
  aMacRecord.Hint := Hints[Recording];
  aMacRecord.ImageIndex := IconIndex(MacroRecordIcons[Recording]);
end;

procedure TMacrosView.Changed;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TMacrosView.ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
begin
  UpdateCommands;
  Handled := True;
end;

procedure TMacrosView.UpdateCommands;
var
  I, N: Integer;
begin
  I := SelectedIndex;
  N := MacroList.SelCount;
  aMacRecord.Enabled := FCanRecord;
  aMacPlay.Enabled := FCanPlay and (I >= 0);
  aMacRepeat.Enabled := aMacPlay.Enabled;
  aMacRename.Enabled := I >= 0;
  aMacDelete.Enabled := (N > 0) and not FRecording;
  aMacUp.Enabled := I > 0;
  aMacDown.Enabled := (I >= 0) and (I < MacroList.Items.Count - 1);
  aMacExport.Enabled := N > 0;
end;

procedure TMacrosView.RunCommand(A: TAction);
begin
  UpdateCommands;
  if A.Enabled then A.Execute;
end;

function TMacrosView.Ask(const Text: string; Flags: UINT): Integer;
begin
  Result := MessageBox(Application.MainForm.Handle, PChar(Text), 'Macro Library', Flags);
end;

procedure TMacrosView.SelectedMacros(L: TList);
var
  I: Integer;
begin
  for I := 0 to MacroList.Items.Count - 1 do
    if MacroList.Items[I].Selected then L.Add(MacroList.Items[I].Data);
end;

procedure TMacrosView.Command(Sender: TObject);
var
  I, J: Integer;
  Files: TStringList;
begin
  if Sender = aMacRecord then
  begin
    if Assigned(FOnRecord) then FOnRecord(Self);
  end
  else if (Sender = aMacPlay) or (Sender = aMacRepeat) then
  begin
    if Assigned(FOnPlay) then FOnPlay(Self, Sender = aMacRepeat);
  end
  else if Sender = aMacRename then
  begin
    if MacroList.Selected <> nil then MacroList.Selected.EditCaption;
  end
  else if Sender = aMacDelete then DeleteSelected
  else if (Sender = aMacUp) or (Sender = aMacDown) then
  begin
    I := SelectedIndex;
    if Sender = aMacUp then J := I - 1 else J := I + 1;
    if (I < 0) or (J < 0) or (J >= FMacros.Count) then Exit;
    FMacros.Move(I, J);
    Fill(J);
    Changed;
  end
  else if Sender = aMacImport then
  begin
    Files := TStringList.Create;
    try
      if BrowseFiles('Import Macros', MacroFileFilter, Files) then ImportFiles(Files);
    finally
      Files.Free;
    end;
  end
  else if Sender = aMacExport then ExportSelected;
end;

procedure TMacrosView.DeleteSelected;
var
  L: TList;
  I, First: Integer;
  Msg: string;
begin
  L := TList.Create;
  try
    SelectedMacros(L);
    if L.Count = 0 then Exit;
    if L.Count = 1 then Msg := Format('Delete the macro "%s"?', [TSdMacro(L[0]).Name])
    else Msg := Format('Delete the %d macros chosen?', [L.Count]);
    if Ask(Msg, MB_YESNO or MB_ICONQUESTION) <> IDYES then Exit;
    First := FMacros.IndexOf(L[0]);
    for I := 0 to L.Count - 1 do FMacros.Delete(FMacros.IndexOf(L[I]));
  finally
    L.Free;
  end;
  if First >= FMacros.Count then First := FMacros.Count - 1;
  Fill(First);
  Changed;
end;

procedure TMacrosView.ImportFiles(Files: TStrings);
var
  I, First, N: Integer;
begin
  First := FMacros.Count;
  N := 0;
  for I := 0 to Files.Count - 1 do
    try
      Inc(N, FMacros.ImportFile(Files[I]));
    except
      on E: Exception do Ask(Files[I] + ': ' + E.Message, MB_OK or MB_ICONERROR);
    end;
  if N = 0 then
  begin
    Ask('No macros were found in the files.', MB_OK or MB_ICONINFORMATION);
    Exit;
  end;
  Fill(First);
  Changed;
end;

procedure TMacrosView.FilesDropped(Control: TControl; Files: TStrings);
begin
  ImportFiles(Files);
end;

procedure TMacrosView.ExportSelected;
var
  L: TList;
  FileName: string;
begin
  L := TList.Create;
  try
    SelectedMacros(L);
    if L.Count = 0 then Exit;
    if L.Count = 1 then FileName := TSdMacro(L[0]).Name + MacroFileExt else FileName := 'Macros' + MacroFileExt;
    if not BrowseFile('Export Macros', MacroFileFilter, FileName, bfSave, Copy(MacroFileExt, 2, MaxInt)) then Exit;
    try
      FMacros.ExportFile(FileName, L);
    except
      on E: Exception do Ask(FileName + ': ' + E.Message, MB_OK or MB_ICONERROR);
    end;
  finally
    L.Free;
  end;
end;

{ a double click on a macro: Play, the menu's command }
procedure TMacrosView.MacroListDblClick(Sender: TObject);
begin
  RunCommand(aMacPlay);
end;

{ a name edited in the list: the macro's, made unique; an empty one keeps the old name }
procedure TMacrosView.MacroListEdited(Sender: TObject; Item: TListItem; var S: string);
var
  M: TSdMacro;
begin
  M := TSdMacro(Item.Data);
  if M = nil then Exit;
  if Trim(S) = '' then S := M.Name else S := FMacros.UniqueName(S, M);
  if S = M.Name then Exit;
  M.Name := S;
  Changed;
end;

{ the list's keys: Enter plays, F2 renames, Del deletes (keys of the list, not shortcuts of the
  IDE: the code editor keeps its own) }
procedure TMacrosView.MacroListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if MacroList.IsEditing or (Shift <> []) then Exit;
  case Key of
    VK_RETURN: RunCommand(aMacPlay);
    VK_F2: RunCommand(aMacRename);
    VK_DELETE: RunCommand(aMacDelete);
  else
    Exit;
  end;
  Key := 0;
end;

procedure TMacrosView.MacroListSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if FFilling or not Selected or (SelectedIndex < 0) then Exit;
  if Assigned(FOnChoose) then FOnChoose(Self);
end;

procedure TMacrosView.MenuPopup(Sender: TObject);
begin
  if Assigned(FOnMenuPopup) then FOnMenuPopup(Sender);
  UpdateCommands;
end;

end.
