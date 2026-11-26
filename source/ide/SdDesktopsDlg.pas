{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDesktopsDlg;

{ D7 Studio - the Desktops button of the tool bar and View | Desktops | Desktops: what Delphi's
  Desktop tool bar and its three dialogs did, on one form - save the current desktop, choose a
  saved one and the debug desktop.

  * the saved desktops, the current one chosen: Load (a double click, Enter) shows the chosen one
    and closes; Delete removes it (asks first); choosing one puts its name into Save's box;
  * Save current desktop as: the arrangement under the name typed (a saved one is replaced); the
    list shows it chosen and the dialog stays open - Enter in the name saves;
  * Debug desktop: the one shown while the debugger runs, <None> for none - as soon as it is
    chosen.

  Every command is an action of the dialog; what they do is the owner's (the events given to
  Execute). }

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ActnList, SdDialogs;

type
  TDesktopsDlg = class(TForm)
    xLabel1: TLabel;
    xLabel2: TLabel;
    xLabel3: TLabel;
    DesktopList: TListBox;
    btnLoad: TButton;
    btnDelete: TButton;
    edName: TEdit;
    btnSave: TButton;
    cbDebug: TComboBox;
    Actions: TActionList;
    aLoad: TAction;
    aDelete: TAction;
    aSave: TAction;
    aDebug: TAction;
    aClose: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aLoadExecute(Sender: TObject);
    procedure aLoadUpdate(Sender: TObject);
    procedure aDeleteExecute(Sender: TObject);
    procedure aSaveExecute(Sender: TObject);
    procedure aSaveUpdate(Sender: TObject);
    procedure aDebugExecute(Sender: TObject);
    procedure aCloseExecute(Sender: TObject);
    procedure DesktopListClick(Sender: TObject);
    procedure DesktopListDblClick(Sender: TObject);
    procedure cbDebugChange(Sender: TObject);
    procedure edNameEnter(Sender: TObject);
    procedure edNameExit(Sender: TObject);
  private
    FNames: TDesktopNamesEvent;
    FOnSave, FOnLoad, FOnDelete, FOnDebug: TDesktopEvent;
    function Chosen: string;
    procedure Fill(const Current, Debug: string);
  public
    class procedure Execute(AOwner: TComponent; Names: TDesktopNamesEvent; const Current, Debug: string;
      OnSave, OnLoad, OnDelete, OnDebug: TDesktopEvent);
  end;

implementation

{$R *.dfm}

uses
  SdUI;

procedure TDesktopsDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ the saved desktops (Current chosen, and the name to save under) and the debug desktop }
procedure TDesktopsDlg.Fill(const Current, Debug: string);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    FNames(L);
    DesktopList.Items.Assign(L);
    DesktopList.ItemIndex := DesktopList.Items.IndexOf(Current);
    if Current <> '' then edName.Text := Current;
    L.Insert(0, NoDesktopName);
    cbDebug.Items.Assign(L);
    cbDebug.ItemIndex := cbDebug.Items.IndexOf(Debug);
    if cbDebug.ItemIndex < 0 then cbDebug.ItemIndex := 0;
  finally
    L.Free;
  end;
end;

function TDesktopsDlg.Chosen: string;
begin
  if DesktopList.ItemIndex >= 0 then Result := DesktopList.Items[DesktopList.ItemIndex] else Result := '';
end;

procedure TDesktopsDlg.aLoadExecute(Sender: TObject);
begin
  if Chosen = '' then Exit;
  FOnLoad(Chosen);
  ModalResult := mrOk;
end;

procedure TDesktopsDlg.aLoadUpdate(Sender: TObject);
begin
  aLoad.Enabled := Chosen <> '';
  aDelete.Enabled := aLoad.Enabled;
end;

procedure TDesktopsDlg.aDeleteExecute(Sender: TObject);
var
  S, Debug: string;
begin
  S := Chosen;
  if (S = '') or (MessageBox(Handle, PChar(Format('Delete the desktop ''%s''?', [S])), 'Confirm',
    MB_OKCANCEL or MB_ICONQUESTION) <> IDOK) then Exit;
  FOnDelete(S);
  Debug := cbDebug.Text;
  if SameText(Debug, S) then Debug := '';
  Fill('', Debug);
end;

{ the current arrangement under the name typed; it becomes the current desktop, chosen in the
  list, and the dialog stays open }
procedure TDesktopsDlg.aSaveExecute(Sender: TObject);
var
  S: string;
begin
  S := Trim(edName.Text);
  if (S = '') or (Copy(S, 1, 1) = '.') then Exit;     // a leading '.': D7 Studio's own desktops
  FOnSave(S);
  Fill(S, cbDebug.Text);
end;

{ Enter in the name saves (Save is the default button there), elsewhere it loads - one default
  button at a time: with two, the VCL lets the first take Enter }
procedure TDesktopsDlg.edNameEnter(Sender: TObject);
begin
  btnLoad.Default := False;
  btnSave.Default := True;
end;

procedure TDesktopsDlg.edNameExit(Sender: TObject);
begin
  btnSave.Default := False;
  btnLoad.Default := True;
end;

procedure TDesktopsDlg.aSaveUpdate(Sender: TObject);
begin
  aSave.Enabled := (Trim(edName.Text) <> '') and (Copy(Trim(edName.Text), 1, 1) <> '.');
end;

procedure TDesktopsDlg.aDebugExecute(Sender: TObject);
begin
  if cbDebug.ItemIndex <= 0 then FOnDebug('') else FOnDebug(cbDebug.Items[cbDebug.ItemIndex]);
end;

procedure TDesktopsDlg.aCloseExecute(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

{ a desktop chosen (a click, the keys): its name is the one to save under }
procedure TDesktopsDlg.DesktopListClick(Sender: TObject);
begin
  if Chosen <> '' then edName.Text := Chosen;
end;

{ a double click on a desktop: Load }
procedure TDesktopsDlg.DesktopListDblClick(Sender: TObject);
begin
  aLoad.Execute;
end;

{ choosing the debug desktop sets it (its action) }
procedure TDesktopsDlg.cbDebugChange(Sender: TObject);
begin
  aDebug.Execute;
end;

class procedure TDesktopsDlg.Execute(AOwner: TComponent; Names: TDesktopNamesEvent; const Current,
  Debug: string; OnSave, OnLoad, OnDelete, OnDebug: TDesktopEvent);
var
  D: TDesktopsDlg;
begin
  D := TDesktopsDlg.Create(AOwner);
  try
    D.FNames := Names;
    D.FOnSave := OnSave;
    D.FOnLoad := OnLoad;
    D.FOnDelete := OnDelete;
    D.FOnDebug := OnDebug;
    D.Fill(Current, Debug);
    D.aLoad.Update;                   // the states of the commands from the first frame on
    D.aSave.Update;
    D.ShowModal;
  finally
    D.Free;
  end;
end;

end.
