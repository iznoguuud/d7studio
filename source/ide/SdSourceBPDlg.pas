{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdSourceBPDlg;

{ D7 Studio - Delphi 7's breakpoint dialogs (Run | Add Breakpoint, the Breakpoints view's Add and
  Properties): Add Source Breakpoint, and in the same form its relatives
  Add Address Breakpoint and Add Data Breakpoint, which have the same rows
  with other labels: Address instead of the file name, no line (address) or Length in its place
  (data). Then condition, pass count, group. Delphi opens it compact; Advanced >> shows the actions
  of a hit: break, ignore / handle the exceptions that follow, log a message, evaluate an
  expression (log its value), enable / disable a group. }

interface

uses
  SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, SdDbgEngine;

type
  { the address an address text names (a number, or an expression of the stopped program) }
  TAddressFunc = function(const S: string; out Addr: Cardinal): Boolean of object;

  TSourceBPDlg = class(TForm)
    xLabel1: TLabel;
    lbLineNumber: TLabel;
    xLabel3: TLabel;
    lbPassCount: TLabel;
    xLabel5: TLabel;
    edFileName: TComboBox;
    edLineNo: TComboBox;
    edCondition: TComboBox;
    edPassCount: TComboBox;
    gbActions: TGroupBox;
    lbLogMessage: TLabel;
    lbEnableGroup: TLabel;
    lbDisableGroup: TLabel;
    lbEvalExpression: TLabel;
    cbBreak: TCheckBox;
    edLogMessage: TComboBox;
    edEnableGroup: TComboBox;
    edDisableGroup: TComboBox;
    edEvalExpression: TComboBox;
    cbLogResult: TCheckBox;
    cbIgnoreExceptions: TCheckBox;
    cbHandleExceptions: TCheckBox;
    edGroupname: TComboBox;
    AdvancedButton: TButton;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure AdvancedButtonClick(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
  private
    FKind: TDbgBPKind;
    FAdvanced: Boolean;
    FMoved: array[0..7] of TControl;    // the rows below the second, Advanced, the actions
    FTops: array[0..7] of Integer;      // their places in the form as designed
    FPitch, FBtnGap: Integer;
    FAddrFunc: TAddressFunc;
    FAddr: Cardinal;                    // the address OK took (address and data breakpoints)
    procedure Arrange;
    function AddressOf(const S: string; out A: Cardinal): Boolean;
    function Check(out Bad: TWinControl): string;
    procedure Take(BP: TDbgBreakpoint);
  public
    { BP holds the settings in and out (its Kind chooses the form); Groups: the groups there are;
      KeyChanges False: the place (file name and line, address and length) is shown, not changed }
    class function Execute(AOwner: TComponent; const ACaption: string; BP: TDbgBreakpoint;
      Groups: TStrings; AddrFunc: TAddressFunc; KeyChanges: Boolean = True): Boolean;
  end;

var
  SourceBPDlg: TSourceBPDlg;

{ what is wrong with a data breakpoint of Len bytes at Addr ('' nothing): the debugger's are the
  processor's - 1, 2 or 4 bytes at an address aligned to them (also the Watch List's Break When
  Changed) }
function DataBreakpointError(Addr: Cardinal; Len: Integer): string;

implementation

uses
  SdUI, SdSettings, SdDialogs;

{$R *.dfm}

function DataBreakpointError(Addr: Cardinal; Len: Integer): string;
begin
  Result := '';
  if not (Len in [1, 2, 4]) then
    Result := 'The length of a data breakpoint is 1, 2 or 4 bytes.'
  else if Addr mod Cardinal(Len) <> 0 then
    Result := Format('The address of %d bytes must be a multiple of %d.', [Len, Len]);
end;

procedure TSourceBPDlg.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  UIPrepareForm(Self);
  if UILayoutPass then Exit;
  { the places as designed (the actions shown), from which Arrange lays out each form }
  FMoved[0] := xLabel3;
  FMoved[1] := edCondition;
  FMoved[2] := lbPassCount;
  FMoved[3] := edPassCount;
  FMoved[4] := xLabel5;
  FMoved[5] := edGroupname;
  FMoved[6] := AdvancedButton;
  FMoved[7] := gbActions;
  for I := 0 to High(FMoved) do FTops[I] := FMoved[I].Top;
  FPitch := edLineNo.Top - edFileName.Top;
  FBtnGap := pnlFooter.Top - (gbActions.Top + gbActions.Height);   // the form shows the actions
end;

{ the rows of the kind (an address breakpoint has no second row: what follows moves up), then the
  band of the buttons below Advanced - or below the actions }
procedure TSourceBPDlg.Arrange;
var
  I, Shift, B: Integer;
begin
  case FKind of
    bkSource:
      begin
        xLabel1.Caption := '&Filename:';
        lbLineNumber.Caption := '&Line number:';
      end;
    bkData:
      begin
        xLabel1.Caption := 'Addre&ss:';
        lbLineNumber.Caption := '&Length:';
      end;
  else
    xLabel1.Caption := 'Addre&ss:';
  end;
  lbLineNumber.Visible := FKind <> bkAddress;
  edLineNo.Visible := FKind <> bkAddress;
  Shift := 0;
  if FKind = bkAddress then Shift := FPitch;
  for I := 0 to High(FMoved) do FMoved[I].Top := FTops[I] - Shift;
  gbActions.Visible := FAdvanced;
  if FAdvanced then
  begin
    AdvancedButton.Caption := '<< &Advanced';
    B := gbActions.Top + gbActions.Height;
  end
  else
  begin
    AdvancedButton.Caption := '&Advanced >>';
    B := AdvancedButton.Top + AdvancedButton.Height;
  end;
  { the band of the buttons below the last control shown }
  ClientHeight := B + FBtnGap + pnlFooter.Height;
  pnlFooter.Top := B + FBtnGap;
end;

procedure TSourceBPDlg.AdvancedButtonClick(Sender: TObject);
begin
  FAdvanced := not FAdvanced;
  Arrange;
end;

{ the address an address text names: the stopped program's (AddrFunc), else a number }
function TSourceBPDlg.AddressOf(const S: string; out A: Cardinal): Boolean;
var
  N: Int64;
begin
  A := 0;
  if Assigned(FAddrFunc) then Result := FAddrFunc(S, A)
  else
  begin
    Result := ((Copy(S, 1, 1) = '$') and TryStrToInt64(S, N)) or TryStrToInt64('$' + S, N);
    if Result then A := Cardinal(N);
  end;
end;

{ '' when the settings are complete, else what is wrong and the box it is about }
function TSourceBPDlg.Check(out Bad: TWinControl): string;
var
  S: string;
  Len: Integer;
begin
  Result := '';
  Bad := nil;
  S := Trim(edFileName.Text);
  case FKind of
    bkSource:
      if (S = '') or (StrToIntDef(Trim(edLineNo.Text), 0) <= 0) then
      begin
        Result := 'A source breakpoint needs a file name and a line number above 0.';
        if S = '' then Bad := edFileName else Bad := edLineNo;
      end;
    bkAddress, bkData:
      if not AddressOf(S, FAddr) then
      begin
        Result := 'Invalid address: ' + S;
        Bad := edFileName;
      end
      else if FKind = bkData then
      begin
        Len := StrToIntDef(Trim(edLineNo.Text), 0);
        Result := DataBreakpointError(FAddr, Len);
        if not (Len in [1, 2, 4]) then Bad := edLineNo else Bad := edFileName;
      end;
  end;
  if (Result = '') and (StrToIntDef(Trim(edPassCount.Text), -1) < 0) then
  begin
    Result := 'The pass count is 0 or more.';
    Bad := edPassCount;
  end;
end;

procedure TSourceBPDlg.OKButtonClick(Sender: TObject);
var
  Err: string;
  Bad: TWinControl;
begin
  Err := Check(Bad);
  if DialogValid(Self, Err, Bad) then ModalResult := mrOk;
end;

{ the settings into BP (after OK: they are complete) }
procedure TSourceBPDlg.Take(BP: TDbgBreakpoint);
begin
  case FKind of
    bkSource:
      begin
        BP.FileName := Trim(edFileName.Text);
        BP.Line := StrToIntDef(Trim(edLineNo.Text), 0);
      end;
    bkAddress, bkData:
      begin
        BP.Address := FAddr;
        if FKind = bkData then BP.DataLength := StrToIntDef(Trim(edLineNo.Text), 0);
      end;
  end;
  BP.Condition := Trim(edCondition.Text);
  BP.PassCount := StrToIntDef(Trim(edPassCount.Text), -1);
  BP.Group := Trim(edGroupname.Text);
  BP.DoBreak := cbBreak.Checked;
  BP.IgnoreExceptions := cbIgnoreExceptions.Checked;
  BP.HandleExceptions := cbHandleExceptions.Checked;
  BP.LogMessage := Trim(edLogMessage.Text);
  BP.EvalExpr := Trim(edEvalExpression.Text);
  BP.LogResult := cbLogResult.Checked;
  BP.EnableGroup := Trim(edEnableGroup.Text);
  BP.DisableGroup := Trim(edDisableGroup.Text);
end;

class function TSourceBPDlg.Execute(AOwner: TComponent; const ACaption: string; BP: TDbgBreakpoint;
  Groups: TStrings; AddrFunc: TAddressFunc; KeyChanges: Boolean): Boolean;
var
  D: TSourceBPDlg;
begin
  D := TSourceBPDlg.Create(AOwner);
  try
    if ACaption <> '' then D.Caption := ACaption;
    D.FKind := BP.Kind;
    D.FAddrFunc := AddrFunc;
    D.edFileName.Enabled := KeyChanges;
    D.edLineNo.Enabled := KeyChanges;
    if not KeyChanges then D.ActiveControl := D.edCondition;
    if BP.Kind = bkSource then
    begin
      LoadHistory(Settings, 'hlBreakFileName', D.edFileName.Items);
      D.edFileName.Text := BP.FileName;
      D.edLineNo.Text := IntToStr(BP.Line);
    end
    else
    begin
      if BP.Address <> 0 then D.edFileName.Text := Format('$%.8x', [BP.Address]);
      D.edLineNo.Items.CommaText := '1,2,4';
      D.edLineNo.Text := IntToStr(BP.DataLength);
    end;
    LoadHistory(Settings, 'hlBreakCondition', D.edCondition.Items);
    D.edCondition.Text := BP.Condition;
    D.edPassCount.Text := IntToStr(BP.PassCount);
    D.edGroupname.Items.Assign(Groups);
    D.edGroupname.Text := BP.Group;
    D.cbBreak.Checked := BP.DoBreak;
    D.cbIgnoreExceptions.Checked := BP.IgnoreExceptions;
    D.cbHandleExceptions.Checked := BP.HandleExceptions;
    D.edLogMessage.Text := BP.LogMessage;
    D.edEvalExpression.Text := BP.EvalExpr;
    D.cbLogResult.Checked := BP.LogResult;
    D.edEnableGroup.Items.Assign(Groups);
    D.edEnableGroup.Text := BP.EnableGroup;
    D.edDisableGroup.Items.Assign(Groups);
    D.edDisableGroup.Text := BP.DisableGroup;
    { opened with its actions when it has some (the properties of such a breakpoint) }
    D.FAdvanced := not BP.DoBreak or BP.IgnoreExceptions or BP.HandleExceptions or (BP.LogMessage <> '') or
      (BP.EvalExpr <> '') or (BP.EnableGroup <> '') or (BP.DisableGroup <> '');
    D.Arrange;
    Result := D.ShowModal = mrOk;
    if not Result then Exit;
    D.Take(BP);
    if BP.Kind = bkSource then AddHistory(Settings, 'hlBreakFileName', BP.FileName);
    if BP.Condition <> '' then AddHistory(Settings, 'hlBreakCondition', BP.Condition);
  finally
    D.Free;
  end;
end;

end.
