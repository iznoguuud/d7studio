{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdNewThreadDlg;

{ D7 Studio - Delphi 7's New Thread Object, File | New |
  Other | Thread Object: the class name, and for a named thread the name the debugger shows. }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls;

type
  TNewThreadDlg = class(TForm)
    xBevel1: TGroupBox;
    xLabel1: TLabel;
    NewClassName: TEdit;
    xBevel2: TGroupBox;
    leThreadName: TLabeledEdit;
    cbNamedThread: TCheckBox;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
    procedure NamedClick(Sender: TObject);
  private
  public
    { ThreadName: '' unless Named Thread is checked }
    class function Execute(AOwner: TComponent; var AClassName, ThreadName: string): Boolean;
  end;

var
  NewThreadDlg: TNewThreadDlg;

{ Delphi 7's unit of a thread object (with SetName for a named thread) }
function NewThreadSource(const UnitName, AClassName, ThreadName: string): string;

implementation

uses
  SdUI, SdDialogs;

{$R *.dfm}

function NewThreadSource(const UnitName, AClassName, ThreadName: string): string;
var
  Named: Boolean;
begin
  Named := ThreadName <> '';
  Result := 'unit ' + UnitName + ';'#13#10#13#10 +
    'interface'#13#10#13#10 +
    'uses'#13#10;
  if Named then Result := Result + '  Classes {$IFDEF MSWINDOWS} , Windows {$ENDIF};'#13#10#13#10
  else Result := Result + '  Classes;'#13#10#13#10;
  Result := Result + 'type'#13#10 +
    '  ' + AClassName + ' = class(TThread)'#13#10 +
    '  private'#13#10;
  if Named then Result := Result + '    procedure SetName;'#13#10;
  Result := Result +
    '  protected'#13#10 +
    '    procedure Execute; override;'#13#10 +
    '  end;'#13#10#13#10 +
    'implementation'#13#10#13#10 +
    '{ Important: Methods and properties of objects in visual components can only be'#13#10 +
    '  used in a method called using Synchronize, for example,'#13#10#13#10 +
    '      Synchronize(UpdateCaption);'#13#10#13#10 +
    '  and UpdateCaption could look like,'#13#10#13#10 +
    '    procedure ' + AClassName + '.UpdateCaption;'#13#10 +
    '    begin'#13#10 +
    '      Form1.Caption := ''Updated in a thread'';'#13#10 +
    '    end; }'#13#10#13#10;
  if Named then
    Result := Result +
      '{$IFDEF MSWINDOWS}'#13#10 +
      'type'#13#10 +
      '  TThreadNameInfo = record'#13#10 +
      '    FType: LongWord;     // must be 0x1000'#13#10 +
      '    FName: PChar;        // pointer to name (in user address space)'#13#10 +
      '    FThreadID: LongWord; // thread ID (-1 indicates caller thread)'#13#10 +
      '    FFlags: LongWord;    // reserved for future use, must be zero'#13#10 +
      '  end;'#13#10 +
      '{$ENDIF}'#13#10#13#10;
  Result := Result + '{ ' + AClassName + ' }'#13#10#13#10;
  if Named then
    Result := Result +
      'procedure ' + AClassName + '.SetName;'#13#10 +
      '{$IFDEF MSWINDOWS}'#13#10 +
      'var'#13#10 +
      '  ThreadNameInfo: TThreadNameInfo;'#13#10 +
      '{$ENDIF}'#13#10 +
      'begin'#13#10 +
      '{$IFDEF MSWINDOWS}'#13#10 +
      '  ThreadNameInfo.FType := $1000;'#13#10 +
      '  ThreadNameInfo.FName := ' + QuotedStr(ThreadName) + ';'#13#10 +
      '  ThreadNameInfo.FThreadID := $FFFFFFFF;'#13#10 +
      '  ThreadNameInfo.FFlags := 0;'#13#10#13#10 +
      '  try'#13#10 +
      '    RaiseException( $406D1388, 0, sizeof(ThreadNameInfo) div sizeof(LongWord), @ThreadNameInfo );'#13#10 +
      '  except'#13#10 +
      '  end;'#13#10 +
      '{$ENDIF}'#13#10 +
      'end;'#13#10#13#10;
  Result := Result +
    'procedure ' + AClassName + '.Execute;'#13#10 +
    'begin'#13#10;
  if Named then Result := Result + '  SetName;'#13#10;
  Result := Result +
    '  { Place thread code here }'#13#10 +
    'end;'#13#10#13#10 +
    'end.'#13#10;
end;

procedure TNewThreadDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  if UILayoutPass then Exit;
  NamedClick(nil);
end;

procedure TNewThreadDlg.NamedClick(Sender: TObject);
begin
  leThreadName.Enabled := cbNamedThread.Checked;
  leThreadName.EditLabel.Enabled := cbNamedThread.Checked;
end;

procedure TNewThreadDlg.OKButtonClick(Sender: TObject);
begin
  if DialogValid(Self, IsValidIdent(Trim(NewClassName.Text)), 'The class name is not a valid identifier.',
    NewClassName) then ModalResult := mrOk;
end;

class function TNewThreadDlg.Execute(AOwner: TComponent; var AClassName, ThreadName: string): Boolean;
var
  D: TNewThreadDlg;
begin
  D := TNewThreadDlg.Create(AOwner);
  try
    Result := D.ShowModal = mrOk;
    if not Result then Exit;
    AClassName := Trim(D.NewClassName.Text);
    if D.cbNamedThread.Checked then ThreadName := Trim(D.leThreadName.Text) else ThreadName := '';
  finally
    D.Free;
  end;
end;

end.
