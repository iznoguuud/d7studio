{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiSettingsDlg;

{ The harness's settings: the backend (the registered TAiBackend classes) and its values - model,
  effort, what is shown of the model's reasoning, the output limit, the prompt's size at which
  the conversation is summarized (backends that can; 0: never), the server's address (Base URL;
  the backend's own when it is left as it is), the wire protocol (backends that let it be
  chosen; the others show theirs), the API key (kept encrypted for the Windows user; empty: the
  backend's environment variable) - and how many tool rounds a message may take before the
  assistant pauses. In three sections - Model, Limits, Connection - with headings and flat rules,
  on clWindow; the buttons in a footer below a flat line; the IDE's font (AiUI). }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, AiCore;

type
  TAiSettingsDialog = class(TForm)
    ModelHeading: TLabel;
    ModelRule: TShape;
    LimitsHeading: TLabel;
    LimitsRule: TShape;
    KeyHeading: TLabel;
    KeyRule: TShape;
    BackendLabel: TLabel;
    BackendCombo: TComboBox;
    ModelLabel: TLabel;
    ModelCombo: TComboBox;
    EffortLabel: TLabel;
    EffortCombo: TComboBox;
    ReasoningLabel: TLabel;
    ReasoningCombo: TComboBox;
    MaxTokensLabel: TLabel;
    MaxTokensEdit: TEdit;
    RoundsLabel: TLabel;
    RoundsEdit: TEdit;
    CompactLabel: TLabel;
    CompactEdit: TEdit;
    CompactNote: TLabel;
    UrlLabel: TLabel;
    UrlEdit: TEdit;
    ProtocolLabel: TLabel;
    ProtocolCombo: TComboBox;
    KeyLabel: TLabel;
    KeyEdit: TEdit;
    KeyNote: TLabel;
    ForgetKeyCheck: TCheckBox;
    Footer: TPanel;
    FooterLine: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure BackendComboChange(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
  private
    FSettings: TAiSettings;
    function Backend: TAiBackendClass;
    procedure LoadBackend;
  public
    class function Execute(Settings: TAiSettings): Boolean;
  end;

implementation

{$R *.dfm}

uses
  AiHost, AiUI;

class function TAiSettingsDialog.Execute(Settings: TAiSettings): Boolean;
var
  D: TAiSettingsDialog;
  I: Integer;
  Current: TAiBackendClass;
begin
  D := TAiSettingsDialog.Create(Application);
  try
    D.FSettings := Settings;
    KitPrepareDialog(D);
    KitSection(D.ModelHeading, D.ModelRule);
    KitSection(D.LimitsHeading, D.LimitsRule);
    KitSection(D.KeyHeading, D.KeyRule);
    Current := SelectedBackendClass;
    for I := 0 to AiBackendCount - 1 do
    begin
      D.BackendCombo.Items.AddObject(AiBackendClass(I).DisplayName, TObject(AiBackendClass(I)));
      if AiBackendClass(I) = Current then D.BackendCombo.ItemIndex := I;
    end;
    if (D.BackendCombo.ItemIndex < 0) and (D.BackendCombo.Items.Count > 0) then D.BackendCombo.ItemIndex := 0;
    D.RoundsEdit.Text := IntToStr(Settings.ReadInteger('MaxRounds', 60));
    D.LoadBackend;
    Result := D.ShowModal = mrOk;
  finally
    D.Free;
  end;
end;

function TAiSettingsDialog.Backend: TAiBackendClass;
begin
  if BackendCombo.ItemIndex < 0 then Result := nil
  else Result := TAiBackendClass(BackendCombo.Items.Objects[BackendCombo.ItemIndex]);
end;

{ a combo box filled with Choices and showing Value; one that takes typed text stays enabled
  without choices }
procedure FillCombo(C: TComboBox; Choices: TStrings; const Value: string);
begin
  C.Items.Assign(Choices);
  C.Enabled := (Choices.Count > 0) or (C.Style = csDropDown);
  if C.Style = csDropDown then C.Text := Value
  else C.ItemIndex := C.Items.IndexOf(Value);
end;

{ the address the dialog shows: the setting, else the backend's own }
function ShownUrl(Settings: TAiSettings; B: TAiBackendClass): string;
begin
  Result := Trim(Settings.ReadString(B.Id + '.BaseUrl', ''));
  if Result = '' then Result := B.DefaultBaseUrl;
end;

procedure TAiSettingsDialog.LoadBackend;
var
  B: TAiBackendClass;
  L: TStringList;
  P: string;
begin
  B := Backend;
  if B = nil then Exit;
  P := B.Id + '.';
  L := TStringList.Create;
  try
    B.ListModels(L);
    FillCombo(ModelCombo, L, FSettings.ReadString(P + 'Model', B.DefaultModel));
    L.Clear;
    B.ListEfforts(L);
    FillCombo(EffortCombo, L, FSettings.ReadString(P + 'Effort', B.DefaultEffort));
    L.Clear;
    B.ListReasoning(L);
    FillCombo(ReasoningCombo, L, FSettings.ReadString(P + 'Reasoning', B.DefaultReasoning));
    L.Clear;
    B.ListProtocols(L);
    if L.Count > 0 then FillCombo(ProtocolCombo, L, FSettings.ReadString(P + 'Protocol', B.DefaultProtocol))
    else
    begin
      { the backend's one protocol, shown }
      if B.DefaultProtocol <> '' then L.Add(B.DefaultProtocol);
      FillCombo(ProtocolCombo, L, B.DefaultProtocol);
      ProtocolCombo.Enabled := False;
    end;
    ProtocolLabel.Enabled := ProtocolCombo.Enabled;
    { a box without choices is disabled, and so is its label }
    EffortLabel.Enabled := EffortCombo.Enabled;
    ReasoningLabel.Enabled := ReasoningCombo.Enabled;
  finally
    L.Free;
  end;
  UrlEdit.Text := ShownUrl(FSettings, B);
  MaxTokensEdit.Text := FSettings.ReadString(P + 'MaxTokens', IntToStr(B.DefaultMaxTokens));
  CompactEdit.Enabled := B.SupportsCompaction;
  CompactLabel.Enabled := B.SupportsCompaction;
  CompactNote.Enabled := B.SupportsCompaction;
  if B.SupportsCompaction then CompactEdit.Text := FSettings.ReadString(P + 'CompactAt', IntToStr(B.DefaultCompactAt))
  else CompactEdit.Text := '';
  if B.MinCompactAt > 0 then CompactNote.Caption := Format('min. %d; 0: never', [B.MinCompactAt])
  else CompactNote.Caption := '0: never';
  KeyEdit.Text := '';
  ForgetKeyCheck.Checked := False;
  if FSettings.ReadString(P + 'ApiKey', '') <> '' then
  begin
    KeyNote.Caption := 'A key is saved (encrypted for your Windows account). Type a new one to replace it.';
    ForgetKeyCheck.Enabled := True;
  end
  else
  begin
    if not B.KeyRequired and (B.KeyVariable <> '') then
      KeyNote.Caption := 'Not needed. Without a saved key, ' + B.KeyVariable + ' is sent if it is set.'
    else if not B.KeyRequired then
      KeyNote.Caption := 'Not needed, unless the server asks for one.'
    else if B.KeyVariable <> '' then
      KeyNote.Caption := 'No key is saved: the environment variable ' + B.KeyVariable + ' is used.'
    else
      KeyNote.Caption := 'No key is saved.';
    ForgetKeyCheck.Enabled := False;
  end;
end;

procedure TAiSettingsDialog.BackendComboChange(Sender: TObject);
begin
  LoadBackend;
end;

procedure TAiSettingsDialog.OKButtonClick(Sender: TObject);
var
  B: TAiBackendClass;
  P, Url: string;
  MaxTokens, Rounds, CompactAt: Integer;
begin
  B := Backend;
  if B = nil then
  begin
    ModalResult := mrCancel;
    Exit;
  end;
  MaxTokens := StrToIntDef(Trim(MaxTokensEdit.Text), 0);
  if MaxTokens < 1024 then
  begin
    MaxTokensEdit.SetFocus;
    raise Exception.Create('The output limit must be a number of at least 1024 tokens.');
  end;
  Rounds := StrToIntDef(Trim(RoundsEdit.Text), 0);
  if Rounds < 1 then
  begin
    RoundsEdit.SetFocus;
    raise Exception.Create('The tool rounds must be a number of at least 1.');
  end;
  CompactAt := 0;
  if B.SupportsCompaction then
  begin
    CompactAt := StrToIntDef(Trim(CompactEdit.Text), -1);
    if (CompactAt < 0) or ((CompactAt > 0) and (CompactAt < B.MinCompactAt)) then
    begin
      CompactEdit.SetFocus;
      if B.MinCompactAt > 0 then
        raise Exception.CreateFmt('Summarize at: a number of at least %d tokens, or 0 for never.', [B.MinCompactAt])
      else
        raise Exception.Create('Summarize at: a number of tokens, or 0 for never.');
    end;
  end;
  Url := Trim(UrlEdit.Text);
  if ((Url = '') and (B.DefaultBaseUrl = '')) or ((Url <> '') and not SameText(Copy(Url, 1, 7), 'http://') and
    not SameText(Copy(Url, 1, 8), 'https://')) then
  begin
    UrlEdit.SetFocus;
    raise Exception.Create('Base URL: the server''s address, beginning with http:// or https://.');
  end;
  P := B.Id + '.';
  FSettings.WriteString('Backend', B.Id);
  { the backend's own address is not kept: a later version may move it }
  if SameText(Url, B.DefaultBaseUrl) then FSettings.WriteString(P + 'BaseUrl', '')
  else FSettings.WriteString(P + 'BaseUrl', Url);
  if ProtocolCombo.Enabled and (ProtocolCombo.ItemIndex >= 0) then FSettings.WriteString(P + 'Protocol', ProtocolCombo.Text);
  if B.SupportsCompaction then FSettings.WriteInteger(P + 'CompactAt', CompactAt);
  FSettings.WriteString(P + 'Model', Trim(ModelCombo.Text));
  if EffortCombo.ItemIndex >= 0 then FSettings.WriteString(P + 'Effort', EffortCombo.Text);
  if ReasoningCombo.ItemIndex >= 0 then FSettings.WriteString(P + 'Reasoning', ReasoningCombo.Text);
  FSettings.WriteInteger(P + 'MaxTokens', MaxTokens);
  FSettings.WriteInteger('MaxRounds', Rounds);
  if Trim(KeyEdit.Text) <> '' then FSettings.WriteSecret(P + 'ApiKey', Trim(KeyEdit.Text))
  else if ForgetKeyCheck.Checked then FSettings.WriteString(P + 'ApiKey', '');
  ModalResult := mrOk;
end;

end.
