{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdNewCompDlg;

{ D7 Studio - Delphi 7's New Component,
  Component | New Component: ancestor type, class name, palette page, unit file
  name, search path; OK writes the unit, Install... writes it and installs it into a package
  (Component | Install Component). }

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls,
  ComCtrls, ActnList;

type
  TNewCompInfo = record
    Ancestor, NewClass, Page, UnitFile, SearchPath: string;
    Install: Boolean;           // Install... instead of OK
  end;

  TNewCompDlg = class(TForm)
    ncLabel2: TLabel;
    ncLabel1: TLabel;
    ncLabel3: TLabel;
    ncLabel5: TLabel;
    ncLabel4: TLabel;
    ClassList: TComboBox;
    NewClassName: TEdit;
    PageNames: TComboBox;
    EditFileName: TEdit;
    EditSearchPath: TEdit;
    BrowseButton: TButton;
    SearchPathBtn: TButton;
    Actions: TActionList;
    aBrowseUnit: TAction;
    aSearchPath: TAction;
    aInstall: TAction;
    aOK: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnInstall: TButton;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aBrowseUnitExecute(Sender: TObject);
    procedure aSearchPathExecute(Sender: TObject);
    procedure aInstallExecute(Sender: TObject);
    procedure aOKExecute(Sender: TObject);
    procedure aOKUpdate(Sender: TObject);
    procedure AncestorChange(Sender: TObject);
    procedure ClassNameChange(Sender: TObject);
    procedure FileNameChange(Sender: TObject);
  private
    FDir: string;
    FUserClass, FUserFile: Boolean;
  public
    { Classes: the registered component classes; Pages: the palette pages; Dir: where a new
      unit goes }
    class function Execute(AOwner: TComponent; Classes, Pages: TStrings; const Dir: string;
      var Info: TNewCompInfo): Boolean;
    { the steps of Execute, also for the package editor's Add, which shows the controls (all but
      the command buttons: UIMoveBody) on a page of its own: the lists and the values to start with; OK can be
      given (an ancestor, a class name, a page and a file); a file that exists may be replaced
      (asked, over the window Wnd); the values chosen }
    procedure Prepare(Classes, Pages: TStrings; const Dir: string; const Info: TNewCompInfo);
    function Valid: Boolean;
    function ConfirmFile(Wnd: HWND): Boolean;
    procedure Collect(var Info: TNewCompInfo);
  end;

var
  NewCompDlg: TNewCompDlg;

{ the source of a new component unit, as Delphi 7 writes it (UsesList: ', ' separated) }
function NewComponentSource(const UnitName, NewClass, Ancestor, Page, UsesList: string): string;

implementation

uses
  SdUI, SdDialogs, SdDesignHost;

{$R *.dfm}

function NewComponentSource(const UnitName, NewClass, Ancestor, Page, UsesList: string): string;
begin
  Result :=
    'unit ' + UnitName + ';'#13#10#13#10 +
    'interface'#13#10#13#10 +
    'uses'#13#10 +
    '  ' + UsesList + ';'#13#10#13#10 +
    'type'#13#10 +
    '  ' + NewClass + ' = class(' + Ancestor + ')'#13#10 +
    '  private'#13#10 +
    '    { Private declarations }'#13#10 +
    '  protected'#13#10 +
    '    { Protected declarations }'#13#10 +
    '  public'#13#10 +
    '    { Public declarations }'#13#10 +
    '  published'#13#10 +
    '    { Published declarations }'#13#10 +
    '  end;'#13#10#13#10 +
    'procedure Register;'#13#10#13#10 +
    'implementation'#13#10#13#10 +
    'procedure Register;'#13#10 +
    'begin'#13#10 +
    '  RegisterComponents(' + QuotedStr(Page) + ', [' + NewClass + ']);'#13#10 +
    'end;'#13#10#13#10 +
    'end.'#13#10;
end;

procedure TNewCompDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ as in Delphi: the class name follows the ancestor (TButton -> TButton1), the unit file name the
  class name - until the user types them }
procedure TNewCompDlg.AncestorChange(Sender: TObject);
begin
  if FUserClass or (ClassList.Text = '') then Exit;
  NewClassName.OnChange := nil;
  try
    NewClassName.Text := ClassList.Text + '1';
  finally
    NewClassName.OnChange := ClassNameChange;
  end;
  ClassNameChange(nil);
  FUserClass := False;
end;

procedure TNewCompDlg.ClassNameChange(Sender: TObject);
var
  N: string;
begin
  if Sender <> nil then FUserClass := True;
  if FUserFile then Exit;
  N := ComponentDisplayName(NewClassName.Text);
  EditFileName.OnChange := nil;
  try
    if N <> '' then EditFileName.Text := FDir + N + '.pas' else EditFileName.Text := '';
  finally
    EditFileName.OnChange := FileNameChange;
  end;
end;

procedure TNewCompDlg.FileNameChange(Sender: TObject);
begin
  FUserFile := True;
end;

{ a file that exists is asked about at OK (ConfirmFile), not here }
procedure TNewCompDlg.aBrowseUnitExecute(Sender: TObject);
begin
  BrowseFile(EditFileName, 'Unit File Name', 'Delphi unit (*.pas)|*.pas', bfSaveNoPrompt, 'pas');
end;

procedure TNewCompDlg.aSearchPathExecute(Sender: TObject);
begin
  EditPathListText(EditSearchPath, 'Search Path', True, FDir);
end;

{ Install... and OK: a unit that exists is replaced only when the user says so (the dialog stays
  open otherwise) }
procedure TNewCompDlg.aInstallExecute(Sender: TObject);
begin
  if ConfirmFile(Handle) then ModalResult := mrYes;
end;

procedure TNewCompDlg.aOKExecute(Sender: TObject);
begin
  if ConfirmFile(Handle) then ModalResult := mrOk;
end;

{ OK and Install... need the ancestor, a class name, a page and a file }
procedure TNewCompDlg.aOKUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := Valid;
end;

function TNewCompDlg.Valid: Boolean;
begin
  Result := (ClassList.Text <> '') and IsValidIdent(NewClassName.Text) and
    (Trim(PageNames.Text) <> '') and (Trim(EditFileName.Text) <> '');
end;

procedure TNewCompDlg.Prepare(Classes, Pages: TStrings; const Dir: string; const Info: TNewCompInfo);
begin
  FDir := IncludeTrailingPathDelimiter(Dir);
  ClassList.Items.Assign(Classes);
  PageNames.Items.Assign(Pages);
  PageNames.Text := Info.Page;
  EditSearchPath.Text := Info.SearchPath;
  if Info.Ancestor <> '' then ClassList.Text := Info.Ancestor;
end;

function TNewCompDlg.ConfirmFile(Wnd: HWND): Boolean;
begin
  Result := not FileExists(Trim(EditFileName.Text)) or (MessageBox(Wnd, PChar(Format('%s exists already. ' +
    'Replace it?', [Trim(EditFileName.Text)])), 'New Component', MB_YESNO or MB_ICONQUESTION) = IDYES);
end;

procedure TNewCompDlg.Collect(var Info: TNewCompInfo);
begin
  Info.Ancestor := ClassList.Text;
  Info.NewClass := NewClassName.Text;
  Info.Page := Trim(PageNames.Text);
  Info.UnitFile := Trim(EditFileName.Text);
  Info.SearchPath := Trim(EditSearchPath.Text);
  Info.Install := False;
end;

class function TNewCompDlg.Execute(AOwner: TComponent; Classes, Pages: TStrings; const Dir: string;
  var Info: TNewCompInfo): Boolean;
var
  D: TNewCompDlg;
  R: Integer;
begin
  D := TNewCompDlg.Create(AOwner);
  try
    D.Prepare(Classes, Pages, Dir, Info);
    R := D.ShowModal;
    Result := R in [mrOk, mrYes];
    if not Result then Exit;
    D.Collect(Info);
    Info.Install := R = mrYes;
  finally
    D.Free;
  end;
end;

end.
