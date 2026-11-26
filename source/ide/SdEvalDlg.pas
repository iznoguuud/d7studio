{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdEvalDlg;

{ D7 Studio - Run | Evaluate/Modify: evaluates an expression in the stopped program and
  assigns a new value to it. }

interface

uses
  SysUtils, Classes, Forms, StdCtrls, ExtCtrls, ActnList, SdDbgEngine;

type
  TEvalDlg = class(TForm)
    lblExpr: TLabel;
    lblResult: TLabel;
    lblNewValue: TLabel;
    edExpr: TEdit;
    mmResult: TMemo;
    edNewValue: TEdit;
    Actions: TActionList;
    aEvaluate: TAction;
    aModify: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnEvaluate: TButton;
    btnModify: TButton;
    btnClose: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aEvaluateExecute(Sender: TObject);
    procedure aModifyExecute(Sender: TObject);
    procedure ExprUpdate(Sender: TObject);
  private
    FDebugger: TDebugger;
    FOnModified: TNotifyEvent;
  public
    { OnModified: a value of the program was changed (the debugger views show old values) }
    class procedure Execute(AOwner: TComponent; Debugger: TDebugger; const InitialExpr: string;
      OnModified: TNotifyEvent);
  end;

var
  EvalDlg: TEvalDlg;

implementation

uses
  SdUI;

{$R *.dfm}

procedure TEvalDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

{ both commands need an expression }
procedure TEvalDlg.ExprUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := Trim(edExpr.Text) <> '';
end;

procedure TEvalDlg.aEvaluateExecute(Sender: TObject);
var
  V: TDbgVar;
  Err: string;
begin
  if Trim(edExpr.Text) = '' then Exit;
  if FDebugger.Evaluate(edExpr.Text, V, Err, True) then
    mmResult.Text := V.Value
  else
    mmResult.Text := Err;
  edExpr.SelectAll;
end;

procedure TEvalDlg.aModifyExecute(Sender: TObject);
var
  Err: string;
begin
  if Trim(edExpr.Text) = '' then Exit;
  { with calls, as Evaluate: the expression is the one evaluated }
  if FDebugger.Modify(edExpr.Text, edNewValue.Text, Err, True) then
  begin
    aEvaluate.Execute;
    if Assigned(FOnModified) then FOnModified(Self);
  end
  else
    mmResult.Text := Err;
end;

class procedure TEvalDlg.Execute(AOwner: TComponent; Debugger: TDebugger; const InitialExpr: string;
  OnModified: TNotifyEvent);
var
  D: TEvalDlg;
begin
  D := TEvalDlg.Create(AOwner);
  try
    D.FDebugger := Debugger;
    D.FOnModified := OnModified;
    D.edExpr.Text := InitialExpr;
    if InitialExpr <> '' then D.aEvaluate.Execute;
    D.ShowModal;
  finally
    D.Free;
  end;
end;

end.
