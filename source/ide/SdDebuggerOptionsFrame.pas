{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDebuggerOptionsFrame;

{ D7 Studio - Tools | Debugger Options: Delphi 7's dialog,
  its pages as Delphi's: General, Event Log,
  Language Exceptions, OS Exceptions, and Integrated debugging below them (Footer). The values are
  SdDebuggerOptions'; the section edits a copy and gives it back with OK. A frame: the section
  Debugger Options of the Options dialog (SdOptionsDlg), its pages without tabs. }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ComCtrls, ExtCtrls, CheckLst, ActnList,
  SdDebuggerOptions;

type
  TDebuggerOptionsFrame = class(TFrame)
    PageControl: TPageControl;
    tsGeneral: TTabSheet;
    gbDebugging: TGroupBox;
    cbTD32Commands: TCheckBox;
    cbRearrangeMenu: TCheckBox;
    cbDisableEdit: TCheckBox;
    cbAllowSideEffectsInWatches: TCheckBox;
    cbDisableMultipleEvaluators: TCheckBox;
    cbDebugSpawnedProcesses: TCheckBox;
    cbCOMCrossProcess: TCheckBox;
    gbPath: TGroupBox;
    dgLabel1: TLabel;
    lbDebugDcu: TLabel;
    ddDebugSymbolSearchPath: TComboBox;
    bDirDebugSource: TButton;
    ddDebugDCUPath: TComboBox;
    bDirDebugDCU: TButton;
    gbInspectorDefaults: TGroupBox;
    cbShowInherited: TCheckBox;
    cbShowQualNames: TCheckBox;
    cbSortByName: TCheckBox;
    tsEventLog: TTabSheet;
    LogGroupBox: TGroupBox;
    cbProcessMessages: TCheckBox;
    cbBreakpointMessages: TCheckBox;
    cbOutputMessages: TCheckBox;
    cbWindowMessages: TCheckBox;
    cbThreadMessages: TCheckBox;
    cbModuleMessages: TCheckBox;
    GeneralGroupBox: TGroupBox;
    lbLogLength: TLabel;
    ecLogLength: TEdit;
    cbUnlimited: TCheckBox;
    cbClearOnStartup: TCheckBox;
    cbIncludeProcessInfo: TCheckBox;
    LogColorGroupBox: TGroupBox;
    lblForeground: TLabel;
    lblBackground: TLabel;
    lstbxColors: TListBox;
    clrbxForegroundColor: TColorBox;
    clrbxBackgroundColor: TColorBox;
    chkbxUseLogColors: TCheckBox;
    tsLangExceptions: TTabSheet;
    cbDelphiExcept: TCheckBox;
    cbCPPExcept: TCheckBox;
    gbIgnoreExcept: TGroupBox;
    AddButton: TButton;
    RemoveButton: TButton;
    ExceptListBox: TCheckListBox;
    tsOSExceptions: TTabSheet;
    oeLabel1: TLabel;
    ExceptionList: TListBox;
    rgHandledBy: TRadioGroup;
    rgResumeOptions: TRadioGroup;
    AddExButton: TButton;
    RemoveExButton: TButton;
    Footer: TPanel;
    cbIntegratedDebugging: TCheckBox;
    Actions: TActionList;
    aListDebugSource: TAction;
    aListDebugDcu: TAction;
    aLangAdd: TAction;
    aLangRemove: TAction;
    aOSAdd: TAction;
    aOSRemove: TAction;
    procedure EditListExecute(Sender: TObject);
    procedure aLangAddExecute(Sender: TObject);
    procedure aLangRemoveExecute(Sender: TObject);
    procedure LangSelectedUpdate(Sender: TObject);
    procedure aOSAddExecute(Sender: TObject);
    procedure aOSRemoveExecute(Sender: TObject);
    procedure OSSelectedUpdate(Sender: TObject);
    procedure ColorsClick(Sender: TObject);
    procedure ColorsDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure ColorSelect(Sender: TObject);
    procedure UnlimitedClick(Sender: TObject);
    procedure OSListClick(Sender: TObject);
    procedure OSDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure OSRuleClick(Sender: TObject);
  private
    FOpts: TDebuggerOptions;
    FLoading: Boolean;
    procedure LoadControls;
    procedure SaveControls;
    procedure FillLang;
    procedure FillOS;
  public
    constructor Create(AOwner: TComponent); override;
    { the lists filled and the values shown, once, when the section is first shown; the values
      given back after OK }
    procedure LoadOptions;
    procedure SaveOptions;
  end;

implementation

{$R *.dfm}

uses
  SdUI, SdDialogs, SdExceptRangeDlg;

{ laid out for the UI font only: LoadOptions fills it when the section is first shown }
constructor TDebuggerOptionsFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  UIPrepareFrame(Self);
end;

procedure TDebuggerOptionsFrame.LoadOptions;
var
  K: TEventKind;
begin
  FOpts := DebuggerOptions;
  FOpts.LangExceptions := Copy(DebuggerOptions.LangExceptions, 0, Length(DebuggerOptions.LangExceptions));
  FOpts.OSExceptions := Copy(DebuggerOptions.OSExceptions, 0, Length(DebuggerOptions.OSExceptions));
  lstbxColors.Items.Clear;
  for K := Low(K) to High(K) do lstbxColors.Items.Add(EventKindNames[K]);
  LoadControls;
end;

procedure TDebuggerOptionsFrame.SaveOptions;
begin
  SaveControls;
  DebuggerOptions := FOpts;
end;

procedure TDebuggerOptionsFrame.LoadControls;
begin
  FLoading := True;
  try
    cbIntegratedDebugging.Checked := FOpts.Integrated;
    cbTD32Commands.Checked := FOpts.TD32Keys;
    cbRearrangeMenu.Checked := FOpts.RearrangeMenu;
    cbDisableEdit.Checked := FOpts.MarkReadOnly;
    cbAllowSideEffectsInWatches.Checked := FOpts.SideEffects;
    cbDisableMultipleEvaluators.Checked := FOpts.NoMultipleEvaluators;
    cbDebugSpawnedProcesses.Checked := FOpts.DebugSpawned;
    cbCOMCrossProcess.Checked := FOpts.COMCrossProcess;
    ddDebugSymbolSearchPath.Text := FOpts.SymbolPath;
    ddDebugDCUPath.Text := FOpts.DCUPath;
    cbShowInherited.Checked := FOpts.InspShowInherited;
    cbShowQualNames.Checked := FOpts.InspQualifiedNames;
    cbSortByName.Checked := FOpts.InspSortByName;
    cbBreakpointMessages.Checked := FOpts.LogKinds[ekBreakpoint];
    cbProcessMessages.Checked := FOpts.LogKinds[ekProcess];
    cbThreadMessages.Checked := FOpts.LogKinds[ekThread];
    cbModuleMessages.Checked := FOpts.LogKinds[ekModule];
    cbOutputMessages.Checked := FOpts.LogKinds[ekOutput];
    cbWindowMessages.Checked := FOpts.LogKinds[ekWindow];
    cbClearOnStartup.Checked := FOpts.LogClearOnRun;
    cbUnlimited.Checked := FOpts.LogUnlimited;
    ecLogLength.Text := IntToStr(FOpts.LogLength);
    cbIncludeProcessInfo.Checked := FOpts.LogProcessInfo;
    chkbxUseLogColors.Checked := FOpts.LogUseColors;
    cbDelphiExcept.Checked := FOpts.StopOnDelphi;
    cbCPPExcept.Checked := FOpts.StopOnCpp;
  finally
    FLoading := False;
  end;
  UnlimitedClick(nil);
  lstbxColors.ItemIndex := 0;
  ColorsClick(nil);
  FillLang;
  FillOS;
end;

procedure TDebuggerOptionsFrame.SaveControls;
var
  I: Integer;
begin
  FOpts.Integrated := cbIntegratedDebugging.Checked;
  FOpts.TD32Keys := cbTD32Commands.Checked;
  FOpts.RearrangeMenu := cbRearrangeMenu.Checked;
  FOpts.MarkReadOnly := cbDisableEdit.Checked;
  FOpts.SideEffects := cbAllowSideEffectsInWatches.Checked;
  FOpts.NoMultipleEvaluators := cbDisableMultipleEvaluators.Checked;
  FOpts.DebugSpawned := cbDebugSpawnedProcesses.Checked;
  FOpts.COMCrossProcess := cbCOMCrossProcess.Checked;
  FOpts.SymbolPath := Trim(ddDebugSymbolSearchPath.Text);
  FOpts.DCUPath := Trim(ddDebugDCUPath.Text);
  FOpts.InspShowInherited := cbShowInherited.Checked;
  FOpts.InspQualifiedNames := cbShowQualNames.Checked;
  FOpts.InspSortByName := cbSortByName.Checked;
  FOpts.LogKinds[ekBreakpoint] := cbBreakpointMessages.Checked;
  FOpts.LogKinds[ekProcess] := cbProcessMessages.Checked;
  FOpts.LogKinds[ekThread] := cbThreadMessages.Checked;
  FOpts.LogKinds[ekModule] := cbModuleMessages.Checked;
  FOpts.LogKinds[ekOutput] := cbOutputMessages.Checked;
  FOpts.LogKinds[ekWindow] := cbWindowMessages.Checked;
  FOpts.LogClearOnRun := cbClearOnStartup.Checked;
  FOpts.LogUnlimited := cbUnlimited.Checked;
  FOpts.LogLength := StrToIntDef(ecLogLength.Text, FOpts.LogLength);
  if FOpts.LogLength < 1 then FOpts.LogLength := 1;
  FOpts.LogProcessInfo := cbIncludeProcessInfo.Checked;
  FOpts.LogUseColors := chkbxUseLogColors.Checked;
  FOpts.StopOnDelphi := cbDelphiExcept.Checked;
  FOpts.StopOnCpp := cbCPPExcept.Checked;
  for I := 0 to High(FOpts.LangExceptions) do FOpts.LangExceptions[I].Ignored := ExceptListBox.Checked[I];
end;

{ the folder lists of the paths: Delphi's ordered list editor }
procedure TDebuggerOptionsFrame.EditListExecute(Sender: TObject);
begin
  if Sender = aListDebugSource then EditPathListText(ddDebugSymbolSearchPath, 'Directories', True, '')
  else EditPathListText(ddDebugDCUPath, 'Directories', True, '');
end;

procedure TDebuggerOptionsFrame.UnlimitedClick(Sender: TObject);
begin
  ecLogLength.Enabled := not cbUnlimited.Checked;
  lbLogLength.Enabled := ecLogLength.Enabled;
end;

{ --- Event Log colours: a kind at a time, the list shows them --- }

procedure TDebuggerOptionsFrame.ColorsClick(Sender: TObject);
var
  K: TEventKind;
begin
  if lstbxColors.ItemIndex < 0 then Exit;
  K := TEventKind(lstbxColors.ItemIndex);
  FLoading := True;
  try
    clrbxForegroundColor.Selected := FOpts.LogColors[K].Fore;
    clrbxBackgroundColor.Selected := FOpts.LogColors[K].Back;
  finally
    FLoading := False;
  end;
end;

procedure TDebuggerOptionsFrame.ColorSelect(Sender: TObject);
var
  K: TEventKind;
begin
  if FLoading or (lstbxColors.ItemIndex < 0) then Exit;
  K := TEventKind(lstbxColors.ItemIndex);
  FOpts.LogColors[K].Fore := clrbxForegroundColor.Selected;
  FOpts.LogColors[K].Back := clrbxBackgroundColor.Selected;
  lstbxColors.Invalidate;
end;

procedure TDebuggerOptionsFrame.ColorsDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  C: TCanvas;
  K: TEventKind;
begin
  C := lstbxColors.Canvas;
  K := TEventKind(Index);
  C.Brush.Color := FOpts.LogColors[K].Back;
  C.Font.Color := FOpts.LogColors[K].Fore;
  C.FillRect(Rect);
  C.TextOut(Rect.Left + 2, Rect.Top + (Rect.Bottom - Rect.Top - C.TextHeight('Wg')) div 2, lstbxColors.Items[Index]);
  if odFocused in State then C.DrawFocusRect(Rect);
end;

{ --- Language Exceptions: the classes to ignore, checked --- }

procedure TDebuggerOptionsFrame.FillLang;
var
  I: Integer;
begin
  ExceptListBox.Items.BeginUpdate;
  try
    ExceptListBox.Items.Clear;
    for I := 0 to High(FOpts.LangExceptions) do
    begin
      ExceptListBox.Items.Add(FOpts.LangExceptions[I].Name);
      ExceptListBox.Checked[I] := FOpts.LangExceptions[I].Ignored;
    end;
  finally
    ExceptListBox.Items.EndUpdate;
  end;
end;

procedure TDebuggerOptionsFrame.aLangAddExecute(Sender: TObject);
var
  S: string;
  I, N: Integer;
begin
  S := '';
  if not InputDialog(Self, 'Add Language Exception', 'Exception &type:', S) then Exit;
  S := Trim(S);
  if S = '' then Exit;
  for I := 0 to High(FOpts.LangExceptions) do
  begin
    FOpts.LangExceptions[I].Ignored := ExceptListBox.Checked[I];
    if SameText(FOpts.LangExceptions[I].Name, S) then Exit;
  end;
  N := Length(FOpts.LangExceptions);
  SetLength(FOpts.LangExceptions, N + 1);
  FOpts.LangExceptions[N].Name := S;
  FOpts.LangExceptions[N].Ignored := True;
  FillLang;
  ExceptListBox.ItemIndex := N;
end;

{ the row and the exception go; the check boxes of the others stay with their rows }
procedure TDebuggerOptionsFrame.aLangRemoveExecute(Sender: TObject);
var
  I, K: Integer;
begin
  K := DeleteListRow(ExceptListBox);
  if K < 0 then Exit;
  for I := K to High(FOpts.LangExceptions) - 1 do FOpts.LangExceptions[I] := FOpts.LangExceptions[I + 1];
  SetLength(FOpts.LangExceptions, Length(FOpts.LangExceptions) - 1);
end;

procedure TDebuggerOptionsFrame.LangSelectedUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := ExceptListBox.ItemIndex >= 0;
end;

{ --- OS Exceptions: a rule per range of codes; the radio groups show the chosen one's --- }

function RuleText(const R: TOSExceptionRule): string;
begin
  if R.Low = R.High then Result := Format('%s ($%.8X)', [R.Name, R.Low])
  else Result := Format('%s ($%.8X - $%.8X)', [R.Name, R.Low, R.High]);
end;

procedure TDebuggerOptionsFrame.FillOS;
var
  I: Integer;
begin
  ExceptionList.Items.BeginUpdate;
  try
    ExceptionList.Items.Clear;
    for I := 0 to High(FOpts.OSExceptions) do ExceptionList.Items.Add(RuleText(FOpts.OSExceptions[I]));
  finally
    ExceptionList.Items.EndUpdate;
  end;
  if ExceptionList.Items.Count > 0 then ExceptionList.Selected[0] := True;
  OSListClick(nil);
end;

procedure TDebuggerOptionsFrame.OSListClick(Sender: TObject);
var
  I: Integer;
begin
  { a multi-select list answers its caret, 0 also when it is empty }
  I := ExceptionList.ItemIndex;
  if I >= ExceptionList.Items.Count then I := -1;
  FLoading := True;
  try
    rgHandledBy.Enabled := I >= 0;
    rgResumeOptions.Enabled := I >= 0;
    if I < 0 then Exit;
    rgHandledBy.ItemIndex := Ord(FOpts.OSExceptions[I].UserHandles);
    rgResumeOptions.ItemIndex := Ord(not FOpts.OSExceptions[I].RunHandled);
  finally
    FLoading := False;
  end;
end;

{ the choice of the radio groups for every selected rule }
procedure TDebuggerOptionsFrame.OSRuleClick(Sender: TObject);
var
  I: Integer;
begin
  if FLoading then Exit;
  for I := 0 to ExceptionList.Items.Count - 1 do
    if ExceptionList.Selected[I] then
    begin
      FOpts.OSExceptions[I].UserHandles := rgHandledBy.ItemIndex = 1;
      FOpts.OSExceptions[I].RunHandled := rgResumeOptions.ItemIndex = 0;
    end;
  ExceptionList.Invalidate;
end;

{ the rule's name, and who handles it at the right }
procedure TDebuggerOptionsFrame.OSDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
const
  By: array[Boolean] of string = ('Debugger', 'User program');
var
  C: TCanvas;
  R: TRect;
  S: string;
begin
  C := ExceptionList.Canvas;
  C.FillRect(Rect);
  R := Rect;
  Inc(R.Left, 2);
  S := By[FOpts.OSExceptions[Index].UserHandles];
  Dec(R.Right, C.TextWidth(S) + 6);
  C.TextRect(R, R.Left, UIListTextTop(C.Handle, Rect), ExceptionList.Items[Index]);
  C.TextOut(Rect.Right - C.TextWidth(S) - 4, UIListTextTop(C.Handle, Rect), S);
  UIListRowWidth(ExceptionList, R.Left + C.TextWidth(ExceptionList.Items[Index]) + 6 + C.TextWidth(S));
end;

procedure TDebuggerOptionsFrame.aOSAddExecute(Sender: TObject);
var
  Lo, Hi: Cardinal;
  N: Integer;
begin
  Lo := 0;
  Hi := 0;
  if not TExceptRangeDlg.Execute(Self, Lo, Hi) then Exit;
  AddOSRule(FOpts.OSExceptions, Lo, Hi, 'User defined', False, False);
  N := High(FOpts.OSExceptions);
  FillOS;
  ExceptionList.ClearSelection;
  ExceptionList.Selected[N] := True;
  ExceptionList.ItemIndex := N;
  OSListClick(nil);
end;

procedure TDebuggerOptionsFrame.aOSRemoveExecute(Sender: TObject);
var
  I, K: Integer;
begin
  K := 0;
  for I := 0 to High(FOpts.OSExceptions) do
    if not ExceptionList.Selected[I] then
    begin
      FOpts.OSExceptions[K] := FOpts.OSExceptions[I];
      Inc(K);
    end;
  SetLength(FOpts.OSExceptions, K);
  FillOS;
end;

procedure TDebuggerOptionsFrame.OSSelectedUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := ExceptionList.SelCount > 0;
end;

end.