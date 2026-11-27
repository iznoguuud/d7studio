{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdAddModuleDlg;

{ D7 Studio - Run | Add Breakpoint | Module Load Breakpoint: Delphi 7's Add Module dialog.
  The module's name - a path, a file name, or the name
  without its extension - with the names given before in its list; Browse picks a file. }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls;

type
  TAddModuleDlg = class(TForm)
    InputLabel: TLabel;
    ModuleNameCombo: TComboBox;
    BrowseButton: TButton;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure BrowseButtonClick(Sender: TObject);
  public
    { ACaption: '' for Delphi's 'Add Module' }
    class function Execute(AOwner: TComponent; const ACaption: string; var ModuleName: string): Boolean;
  end;

implementation

{$R *.dfm}

uses
  SdUI, SdSettings, SdDialogs;

const
  HistoryName = 'hlAddModule';

procedure TAddModuleDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  PathBox(ModuleNameCombo, False);
end;

procedure TAddModuleDlg.BrowseButtonClick(Sender: TObject);
begin
  BrowseFile(ModuleNameCombo, 'Select Module',
    'Modules (*.dll;*.ocx;*.bpl;*.exe)|*.dll;*.bpl;*.ocx;*.exe|Any File (*.*)|*.*');
end;

class function TAddModuleDlg.Execute(AOwner: TComponent; const ACaption: string; var ModuleName: string): Boolean;
var
  D: TAddModuleDlg;
begin
  D := TAddModuleDlg.Create(AOwner);
  try
    if ACaption <> '' then D.Caption := ACaption;
    LoadHistory(Settings, HistoryName, D.ModuleNameCombo.Items);
    D.ModuleNameCombo.Text := ModuleName;
    Result := (D.ShowModal = mrOk) and (Trim(D.ModuleNameCombo.Text) <> '');
    if Result then
    begin
      ModuleName := Trim(D.ModuleNameCombo.Text);
      AddHistory(Settings, HistoryName, ModuleName);
    end;
  finally
    D.Free;
  end;
end;

end.
