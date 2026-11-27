{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoCreators;

{ The creators of the OTA demo (IOTAModuleServices.CreateModule): a unit made from a text of its
  own, and the form wizard of File | New | Other (page OTA Demo) with its form creator - its source
  and form text, and a button added when the form is there (FormCreated). The new files are
  untitled pages: nothing is written until the user saves them. }

interface

uses
  Windows, SysUtils, Classes, ToolsAPI;

type
  TDemoUnitCreator = class(TInterfacedObject, IOTACreator, IOTAModuleCreator)
  public
    { IOTACreator }
    function GetCreatorType: string;
    function GetExisting: Boolean;
    function GetFileSystem: string;
    function GetOwner: IOTAModule;
    function GetUnnamed: Boolean;
    { IOTAModuleCreator }
    function GetAncestorName: string;
    function GetImplFileName: string;
    function GetIntfFileName: string;
    function GetFormName: string;
    function GetMainForm: Boolean;
    function GetShowForm: Boolean;
    function GetShowSource: Boolean;
    function NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
    function NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile; virtual;
    function NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
    procedure FormCreated(const FormEditor: IOTAFormEditor); virtual;
  end;

  { a form with a label, a button added through the form editor }
  TDemoFormCreator = class(TDemoUnitCreator, IOTACreator, IOTAModuleCreator)
  public
    function GetCreatorType: string;
    function GetAncestorName: string;
    function GetShowForm: Boolean;
    function NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
    function NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile; override;
    procedure FormCreated(const FormEditor: IOTAFormEditor); override;
  end;

  TDemoFormWizard = class(TNotifierObject, IOTANotifier, IOTAWizard, IOTARepositoryWizard,
    IOTARepositoryWizard60, IOTAFormWizard)
  public
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
    function GetAuthor: string;
    function GetComment: string;
    function GetPage: string;
    function GetGlyph: Cardinal;
    function GetDesigner: string;
  end;

implementation

{ ---------------------------------------------------------------- TDemoUnitCreator }

function TDemoUnitCreator.GetCreatorType: string;
begin
  Result := sUnit;
end;

function TDemoUnitCreator.GetExisting: Boolean;
begin
  Result := False;
end;

function TDemoUnitCreator.GetFileSystem: string;
begin
  Result := '';
end;

function TDemoUnitCreator.GetOwner: IOTAModule;
begin
  Result := GetActiveProject;
end;

function TDemoUnitCreator.GetUnnamed: Boolean;
begin
  Result := True;
end;

function TDemoUnitCreator.GetAncestorName: string;
begin
  Result := '';
end;

function TDemoUnitCreator.GetImplFileName: string;
begin
  Result := '';
end;

function TDemoUnitCreator.GetIntfFileName: string;
begin
  Result := '';
end;

function TDemoUnitCreator.GetFormName: string;
begin
  Result := '';
end;

function TDemoUnitCreator.GetMainForm: Boolean;
begin
  Result := False;
end;

function TDemoUnitCreator.GetShowForm: Boolean;
begin
  Result := False;
end;

function TDemoUnitCreator.GetShowSource: Boolean;
begin
  Result := True;
end;

function TDemoUnitCreator.NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil;
end;

function TDemoUnitCreator.NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := StringToIOTAFile(
    'unit ' + ModuleIdent + ';'#13#10 +
    #13#10 +
    '{ made by the OTA demo''s module creator (IOTAModuleCreator), ' + DateTimeToStr(Now) + ' }'#13#10 +
    #13#10 +
    'interface'#13#10 +
    #13#10 +
    'function DemoGreeting: string;'#13#10 +
    #13#10 +
    'implementation'#13#10 +
    #13#10 +
    'function DemoGreeting: string;'#13#10 +
    'begin'#13#10 +
    '  Result := ''Hello from ' + ModuleIdent + ''';'#13#10 +
    'end;'#13#10 +
    #13#10 +
    'end.'#13#10);
end;

function TDemoUnitCreator.NewIntfSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := nil;
end;

procedure TDemoUnitCreator.FormCreated(const FormEditor: IOTAFormEditor);
begin
end;

{ ---------------------------------------------------------------- TDemoFormCreator }

function TDemoFormCreator.GetCreatorType: string;
begin
  Result := sForm;
end;

function TDemoFormCreator.GetAncestorName: string;
begin
  Result := 'Form';
end;

function TDemoFormCreator.GetShowForm: Boolean;
begin
  Result := True;
end;

function TDemoFormCreator.NewFormFile(const FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := StringToIOTAFile(
    'object ' + FormIdent + ': T' + FormIdent + #13#10 +
    '  Left = 200'#13#10 +
    '  Top = 120'#13#10 +
    '  Width = 360'#13#10 +
    '  Height = 220'#13#10 +
    '  Caption = ''OTA Demo form'''#13#10 +
    '  Font.Name = ''Tahoma'''#13#10 +
    '  PixelsPerInch = 96'#13#10 +
    '  TextHeight = 13'#13#10 +
    '  object Label1: TLabel'#13#10 +
    '    Left = 16'#13#10 +
    '    Top = 60'#13#10 +
    '    Width = 240'#13#10 +
    '    Height = 13'#13#10 +
    '    Caption = ''Made by the OTA demo''''s form wizard'''#13#10 +
    '  end'#13#10 +
    'end'#13#10);
end;

function TDemoFormCreator.NewImplSource(const ModuleIdent, FormIdent, AncestorIdent: string): IOTAFile;
begin
  Result := StringToIOTAFile(
    'unit ' + ModuleIdent + ';'#13#10 +
    #13#10 +
    'interface'#13#10 +
    #13#10 +
    'uses'#13#10 +
    '  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, StdCtrls;'#13#10 +
    #13#10 +
    'type'#13#10 +
    '  T' + FormIdent + ' = class(T' + AncestorIdent + ')'#13#10 +
    '    Label1: TLabel;'#13#10 +
    '  private'#13#10 +
    '  public'#13#10 +
    '  end;'#13#10 +
    #13#10 +
    'var'#13#10 +
    '  ' + FormIdent + ': T' + FormIdent + ';'#13#10 +
    #13#10 +
    'implementation'#13#10 +
    #13#10 +
    '{$R *.dfm}'#13#10 +
    #13#10 +
    'end.'#13#10);
end;

{ the form is in the designer: a button through the form editor (IOTAFormEditor.CreateComponent,
  IOTAComponent.SetPropByName) }
procedure TDemoFormCreator.FormCreated(const FormEditor: IOTAFormEditor);
var
  C: IOTAComponent;
  S: string;
begin
  C := FormEditor.CreateComponent(FormEditor.GetRootComponent, 'TButton', 16, 16, 140, 25);
  if C = nil then Exit;
  S := 'Added in FormCreated';
  C.SetPropByName('Caption', S);
end;

{ ---------------------------------------------------------------- TDemoFormWizard }

function TDemoFormWizard.GetIDString: string;
begin
  Result := 'D7Studio.OtaDemo.FormWizard';
end;

function TDemoFormWizard.GetName: string;
begin
  Result := 'OTA Demo Form';
end;

function TDemoFormWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TDemoFormWizard.Execute;
begin
  (BorlandIDEServices as IOTAModuleServices).CreateModule(TDemoFormCreator.Create);
end;

function TDemoFormWizard.GetAuthor: string;
begin
  Result := 'D7 Studio';
end;

function TDemoFormWizard.GetComment: string;
begin
  Result := 'A form made by an IOTAModuleCreator, with a button added in FormCreated';
end;

function TDemoFormWizard.GetPage: string;
begin
  Result := 'OTA Demo';
end;

{ the application's icon of the IDE: an icon the expert does not have to carry }
function TDemoFormWizard.GetGlyph: Cardinal;
begin
  Result := LoadIcon(0, IDI_APPLICATION);
end;

function TDemoFormWizard.GetDesigner: string;
begin
  Result := dVCL;
end;

end.
