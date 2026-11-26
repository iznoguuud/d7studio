{ ********************************************************** }
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{ ********************************************************** }

unit SdRunParamsDlg;

{ D7 Studio - Run | Parameters: Delphi 7's dialog. Local: host
  application, parameters, working directory (launcher application: stored); Remote: stored for
  the .dof (D7 Studio has no remote debugger); Environment Block: the environment of the program
  (system variables or not, and overrides). Load starts the program under the debugger and
  stops at its entry point, as Delphi does. The values live in the .dof ([Parameters], Delphi's
  keys and history lists; the environment block in D7 Studio's own section). }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls,
  ComCtrls, ActnList, SdProject, SdVarLists;

type
  TRunParamsResult = (rpCancel, rpOk, rpLoad);

  TRunParamsDlg = class(TForm)
    PageControl1: TPageControl;
    LocalPage: TTabSheet;
    HostAppGroupBox: TGroupBox;
    HostAppInput: TComboBox;
    BrowseButton: TButton;
    ParametersGroupBox: TGroupBox;
    ParamInput: TComboBox;
    LauncherGroupBox: TGroupBox;
    LauncherInput: TComboBox;
    LauncherCheckBox: TCheckBox;
    CWDGroupBox: TGroupBox;
    CWDInput: TComboBox;
    bCWD: TButton;
    RemotePage: TTabSheet;
    xGroupBox3: TGroupBox;
    xLabel1: TLabel;
    xLabel2: TLabel;
    RemotePath: TComboBox;
    RemoteHost: TComboBox;
    xGroupBox4: TGroupBox;
    RemoteParams: TComboBox;
    RemoteDebug: TCheckBox;
    RemoteLauncherGroupBox: TGroupBox;
    RemoteLauncherInput: TComboBox;
    EnvVarPage: TTabSheet;
    EnvVarOptions: TPanel;
    frGroupBox1: TGroupBox;
    bAddOverride: TButton;
    frPanel1: TPanel;
    lvSystemVars: TListView;
    frGroupBox2: TGroupBox;
    bNew: TButton;
    bEdit: TButton;
    bDelete: TButton;
    lvUserVars: TListView;
    cbIncludeSystem: TCheckBox;
    Actions: TActionList;
    aBrowseHost: TAction;
    aBrowseCWD: TAction;
    aLoad: TAction;
    aVarOverride: TAction;
    aVarNew: TAction;
    aVarEdit: TAction;
    aVarDelete: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    LoadProcButton: TButton;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure aBrowseHostExecute(Sender: TObject);
    procedure aBrowseCWDExecute(Sender: TObject);
    procedure aLoadExecute(Sender: TObject);
    procedure lvUserVarsDblClick(Sender: TObject);
  private
    FVars: TSdVarLists; // the Environment Block page and its commands (aVar...)
  public
    class function Execute(AOwner: TComponent; Project: TSdProject): TRunParamsResult;
  end;

var
  RunParamsDlg: TRunParamsDlg;

{ the environment block of the project's program ('' = the IDE's own environment) }
function ProjectEnvironment(Project: TSdProject): string;

implementation

uses
  SdUI, SdEnvOptions, SdDialogs;

{$R *.dfm}

const
  EnvSection = 'Run Environment';

  { the combo boxes, their .dof keys and Delphi's history lists }
  ComboKeys: array[0 .. 6] of TOptionCombo = (
    (
      'HostAppInput',
      'Parameters',
      'HostApplication',
      'hlHostApplication'
    ),
    (
      'ParamInput',
      'Parameters',
      'RunParams',
      'hlRunParameters'
    ),
    (
      'LauncherInput',
      'Parameters',
      'Launcher',
      'hlLauncherApplication'
    ),
    (
      'CWDInput',
      'Parameters',
      'DebugCWD',
      'hlDebugCWD'
    ),
    (
      'RemotePath',
      'Parameters',
      'RemotePath',
      'hlRemotePath'
    ),
    (
      'RemoteHost',
      'Parameters',
      'RemoteHost',
      'hlRemoteHost'
    ),
    (
      'RemoteParams',
      'Parameters',
      'RemoteParams',
      'hlRunParameters'
    )
  );
  { the check boxes and their .dof keys }
  CheckKeys: array[0 .. 2] of TOptionCheck = (
    (Name: 'LauncherCheckBox'; Section: 'Parameters'; Key: 'UseLauncher'; Default: 0),
    (Name: 'RemoteDebug'; Section: 'Parameters'; Key: 'RemoteDebug'; Default: 0),
    (Name: 'cbIncludeSystem'; Section: ThemeSection; Key: 'IncludeSystemVars'; Default: 1)
  );

function ProjectEnvironment(Project: TSdProject): string;
var
  L, Over: TStringList;
  I, K: Integer;
begin
  Result := '';
  if (Project = nil) or (Project.Dof = nil) then
    Exit;
  Over := TStringList.Create;
  L := TStringList.Create;
  try
    Project.Dof.ReadSectionValues(EnvSection, Over);
    if (Over.Count = 0) and (Project.OptInt(ThemeSection, 'IncludeSystemVars', 1) <> 0) then
      Exit;
    { the IDE's variables (with its own overrides), unless they are left out }
    if Project.OptInt(ThemeSection, 'IncludeSystemVars', 1) <> 0 then
      GetSystemVariables(L);
    for I := 0 to EnvOptions.VarOverrides.Count - 1 do
      if L.Count > 0 then
      begin
        K := L.IndexOfName(EnvOptions.VarOverrides.Names[I]);
        if K >= 0 then
          L[K] := EnvOptions.VarOverrides[I]
        else
          L.Add(EnvOptions.VarOverrides[I]);
      end;
    for I := 0 to Over.Count - 1 do
    begin
      K := L.IndexOfName(Over.Names[I]);
      if K >= 0 then
        L[K] := Over[I]
      else
        L.Add(Over[I]);
    end;
    for I := 0 to L.Count - 1 do
      Result := Result + L[I] + #0;
    Result := Result + #0;
  finally
    L.Free;
    Over.Free;
  end;
end;

procedure TRunParamsDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  if UILayoutPass then
    Exit;
  FVars := TSdVarLists.Create(lvSystemVars, lvUserVars, aVarOverride, aVarNew, aVarEdit, aVarDelete);
end;

{ a double click on an override edits it (the Edit command) }
procedure TRunParamsDlg.lvUserVarsDblClick(Sender: TObject);
begin
  aVarEdit.Execute;
end;

procedure TRunParamsDlg.FormDestroy(Sender: TObject);
begin
  FVars.Free;
end;

{ the dialog starts in the folder of the host given (its name is not proposed) }
procedure TRunParamsDlg.aBrowseHostExecute(Sender: TObject);
var
  F: string;
begin
  F := '';
  if BrowseFile('Host Application', 'Programs (*.exe)|*.exe|All files (*.*)|*.*', F, bfOpen, '',
    ExtractFilePath(HostAppInput.Text)) then
    HostAppInput.Text := F;
end;

procedure TRunParamsDlg.aBrowseCWDExecute(Sender: TObject);
begin
  BrowseFolder(CWDInput, 'Working Directory', '');
end;

procedure TRunParamsDlg.aLoadExecute(Sender: TObject);
begin
  ModalResult := mrYes;
end;

class function TRunParamsDlg.Execute(AOwner: TComponent; Project: TSdProject): TRunParamsResult;
var
  D: TRunParamsDlg;
  I: Integer;
  L: TStringList;
  R: Integer;
begin
  Result := rpCancel;
  if Project = nil then
    Exit;
  D := TRunParamsDlg.Create(AOwner);
  L := TStringList.Create;
  try
    LoadComboTable(D, Project, ComboKeys);
    LoadCheckTable(D, Project, CheckKeys);
    if Project.Dof <> nil then
      Project.Dof.ReadSectionValues(EnvSection, L);
    D.FVars.Fill(L);
    D.PageControl1.ActivePage := D.LocalPage;
    R := D.ShowModal;
    if R in [mrOk, mrYes] then
    begin
      SaveComboTable(D, Project, ComboKeys);
      SaveCheckTable(D, Project, CheckKeys);
      D.FVars.GetOverrides(L);
      if Project.Dof <> nil then
      begin
        Project.Dof.EraseSection(EnvSection);
        for I := 0 to L.Count - 1 do
          Project.Dof.WriteString(EnvSection, L.Names[I], L.ValueFromIndex[I]);
      end;
      Project.SaveOptions;
      if R = mrYes then
        Result := rpLoad
      else
        Result := rpOk;
    end;
  finally
    L.Free;
    D.Free;
  end;
end;

end.
