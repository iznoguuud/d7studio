{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiChatWin;

{ The harness's window: a dockable tool window of the IDE (DockForm.TDockableForm, registered
  with designide's desktop as the OTA demo's window is), laid out as a view of D7 Studio (AiUI):
  on the view's ground a tool bar - New Chat, Stop, Continue (after an error, a stop or the
  tool-round limit), Copy, Settings - in its own images (AiIcons.bmp:
  IntelliJ's), and at the row's right end the provider
  box (a drop-down list of the registered backends, each with its model: the next turn goes to the
  one chosen, with the whole conversation, and the transcript says so; not while the assistant
  works); the conversation and the input box with Send (Enter; Shift+Enter starts a new line),
  each in a flat frame; all in the IDE's fonts. Esc in the window stops the assistant while it
  works, as Stop. The chat's tokens, its estimated cost and how full the model's context window is
  go into the status line of D7 Studio's view (SdOtaViews' ExpertStatusMessage), or, in an IDE
  without one, into the window's own status line with a meter; at 80% the transcript says so once
  (until it is less full again). The conversation's events are written into the transcript as
  they stream in, in formats: the turns' headings, the answer's Markdown (AiMarkdown), the
  reasoning, the tool calls and their outcome, notes and errors. Changes the assistant asks for
  are approved in TAiApproveDialog. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls,
  ToolWin, ImgList, Menus, ActnList, DockForm, AiCore, AiAgent, AiUI, AiMarkdown;

const
  ChatWindowSection = 'AiHarnessChat';

type
  { the formats of the transcript }
  TChatKind = (ckYou, ckAssistant, ckBody, ckBold, ckInline, ckBlock, ckHeading, ckReasoning,
    ckTool, ckToolName, ckResult, ckOkMark, ckFailMark, ckFailed, ckNote, ckError);

  TAiChatWindow = class(TDockableForm)
    TopBar: TPanel;
    MainBar: TToolBar;
    NewChatButton: TToolButton;
    Sep1: TToolButton;
    StopButton: TToolButton;
    ContinueButton: TToolButton;
    Sep2: TToolButton;
    CopyButton: TToolButton;
    SettingsButton: TToolButton;
    ProviderCombo: TComboBox;
    Splitter: TSplitter;
    InputPanel: TPanel;
    Input: TMemo;
    SendPanel: TPanel;
    SendButton: TButton;
    StatusPanel: TPanel;
    StatusLabel: TLabel;
    ContextMeter: TPaintBox;
    Actions: TActionList;
    aSend: TAction;
    aStop: TAction;
    aContinue: TAction;
    aNewChat: TAction;
    aSettings: TAction;
    aCopy: TAction;
    aSelectAll: TAction;
    Icons: TImageList;
    IconsDisabled: TImageList;
    TranscriptMenu: TPopupMenu;
    miCopy: TMenuItem;
    miSelectAll: TMenuItem;
    miSep1: TMenuItem;
    miNewChat: TMenuItem;
    procedure aSendExecute(Sender: TObject);
    procedure aSendUpdate(Sender: TObject);
    procedure aStopExecute(Sender: TObject);
    procedure aStopUpdate(Sender: TObject);
    procedure aContinueExecute(Sender: TObject);
    procedure aContinueUpdate(Sender: TObject);
    procedure aNewChatExecute(Sender: TObject);
    procedure aNewChatUpdate(Sender: TObject);
    procedure aSettingsExecute(Sender: TObject);
    procedure aCopyExecute(Sender: TObject);
    procedure aCopyUpdate(Sender: TObject);
    procedure aSelectAllExecute(Sender: TObject);
    procedure InputChange(Sender: TObject);
    procedure InputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure InputKeyPress(Sender: TObject; var Key: Char);
    procedure ContextMeterPaint(Sender: TObject);
    procedure TopBarResize(Sender: TObject);
    procedure ProviderComboChange(Sender: TObject);
    procedure ChatKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    FProviderWidth: Integer;      // the widest item of the provider box, in pixels
    FTranscript: TKitRichView;
    FMarkdown: TAiMarkdown;
    FSession: TAiSession;
    FApprover: TAiApprover;
    FAtLineStart: Boolean;
    FEatReturn: Boolean;
    FWorking: Boolean;
    FContextWarned: Boolean;
    FContextPercent: Integer;     // -1: not known
    procedure InitLook;
    procedure LayoutProviderBox;
    procedure InitIcons;
    procedure FillProviders;
    function CurrentBackendClass: TAiBackendClass;
    procedure ProviderChanged;
    procedure TakeSelectedProvider;
    function EscapeStops: Boolean;
    procedure ShowStatus(const S: string);
    procedure CMShowingChanged(var Message: TMessage); message CM_SHOWINGCHANGED;
    procedure CheckContext;
    procedure NeedSession;
    procedure SessionEvent(Sender: TObject; Event: TAiEvent);
    procedure MarkdownRun(const Text: WideString; Style: TAiMdStyle);
    procedure Put(const Text: WideString; Kind: TChatKind);
    procedure PutLine(const Text: WideString; Kind: TChatKind);
    procedure PutUtf8Line(const Utf8: string; Kind: TChatKind);
    procedure EnsureLineStart;
    procedure UpdateInfo;
  protected
    procedure CreateWnd; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { sends Text (an IDE string) as the user's message; False when it was not sent }
    function SendText(const Text: string): Boolean;
    property Session: TAiSession read FSession;
    property Transcript: TKitRichView read FTranscript;
  end;

var
  AiChatWindow: TAiChatWindow;

{ the window's class and variable told to the IDE's desktop }
procedure RegisterChatWindow;
{ the window freed, its variable no longer known to the desktop }
procedure UnregisterChatWindow;
procedure ShowChatWindow;

implementation

{$R *.dfm}

uses
  ToolsAPI, DeskUtil, AiText, AiHost, AiPrompt, AiApproveDlg, AiSettingsDlg;

const
  { the window's images: IntelliJ's, the cells of the resource AiIconsResource (AiIcons.bmp,
    linked by AiHarness.dpk through AiIcons.rc), in the order of the constants ai... below }
  AiIconsResource = 'AIICONS';
  aiNewChat = 0;
  aiStop = 1;
  aiContinue = 2;
  aiSettings = 3;
  aiSend = 4;
  aiCopy = 5;
  aiSelectAll = 6;

  { the commands' images (AiIcons.bmp's cells), in the order of the actions' ImageIndex in the .dfm }
  IconCells: array[0..6] of Integer = (aiNewChat, aiStop, aiContinue, aiSettings, aiSend, aiCopy,
    aiSelectAll);

  MarkOk = WideChar($2713);       // check mark
  MarkFail = WideChar($2715);     // multiplication x
  MarkTool = WideChar($203A);     // single right-pointing angle quotation mark

type
  TChatApprover = class(TAiApprover)
  public
    function Approve(Tool: TAiTool; Change: TAiChangePreview; out Reason: string): TAiApproval; override;
  end;

  { OnKeyDown of the transcript, which TKitRichView does not publish }
  TWinControlAccess = class(TWinControl);

function TChatApprover.Approve(Tool: TAiTool; Change: TAiChangePreview; out Reason: string): TAiApproval;
begin
  Result := TAiApproveDialog.Execute(Tool, Change, Reason);
end;

procedure RegisterChatWindow;
begin
  RegisterDesktopFormClass(TAiChatWindow, ChatWindowSection, ChatWindowSection);
  if Assigned(RegisterFieldAddress) then RegisterFieldAddress(ChatWindowSection, @AiChatWindow);
end;

procedure UnregisterChatWindow;
begin
  { TDesktopForm.FormDestroy sets AiChatWindow to nil through DeskUtil.GetFieldAddress }
  AiChatWindow.Free;
  if Assigned(UnregisterFieldAddress) then UnregisterFieldAddress(@AiChatWindow);
  AiChatWindow := nil;
end;

procedure ShowChatWindow;
begin
  if AiChatWindow = nil then AiChatWindow := TAiChatWindow.Create(nil);
  FocusWindow(AiChatWindow);
  if AiChatWindow.Input.CanFocus then AiChatWindow.Input.SetFocus;
end;

{ UTF-8 as the transcript's text: UTF-16 with #13 line ends (Rich Edit's paragraphs) }
function Wide(const Utf8: string): WideString;
begin
  Result := Utf8ToWide(NormalizeNewLines(Utf8, #13));
end;

function FirstLine(const S: WideString; MaxLen: Integer): WideString;
var
  P: Integer;
begin
  Result := S;
  P := Pos(WideString(#13), Result);
  if P > 0 then Result := TrimRight(Copy(Result, 1, P - 1)) + ' ...';
  if Length(Result) > MaxLen then Result := Copy(Result, 1, MaxLen) + '...';
end;

function Thousands(N: Int64): string;
begin
  Result := FormatFloat('#,##0', N);
end;

{ a middle dot (in the IDE's code page) }
function MiddleDot: string;
begin
  Result := Utf8ToIde(#$C2#$B7);
end;

{ the separator of the status line's parts }
function Dot: string;
begin
  Result := '  ' + MiddleDot + '  ';
end;

{ how full the model's context window is, in percent (the window known) }
function ContextPercent(S: TAiSession): Int64;
begin
  Result := S.ContextTokens * 100 div S.ContextWindow;
end;

function KindFormat(Kind: TChatKind): TKitTextFormat;
const
  Body = 12;         // the turns' text, in from their heading
  Nested = 26;       // code blocks, a tool's outcome
var
  Shade: TColor;
begin
  Result := KitFormat(clDefault);
  Result.Indent := Body;
  Shade := KitBlend(clWindowText, clWindow, 6);
  case Kind of
    ckYou, ckAssistant:
      begin
        Result.Bold := True;
        Result.Indent := 0;
        Result.SpaceBefore := 14;
        if Kind = ckAssistant then Result.Color := KitAccent;
      end;
    ckBold: Result.Bold := True;
    ckInline:
      begin
        { the editor's font a point smaller in a line of the UI font }
        Result.Mono := True;
        Result.SizeDelta := -1;
        Result.Back := Shade;
      end;
    ckBlock:
      begin
        Result.Mono := True;
        Result.Back := Shade;
        Result.Indent := Nested;
      end;
    ckHeading:
      begin
        Result.Bold := True;
        Result.SizeDelta := 1;
        Result.SpaceBefore := 6;
      end;
    ckReasoning:
      begin
        Result.Italic := True;
        Result.Color := clGrayText;
      end;
    ckTool: Result.Color := clGrayText;
    ckToolName:
      begin
        Result.Color := clGrayText;
        Result.Mono := True;
        Result.SizeDelta := -1;
      end;
    ckResult:
      begin
        Result.Color := clGrayText;
        Result.Indent := Nested;
      end;
    ckOkMark:
      begin
        Result.Color := KitBlend(clGreen, clGrayText, 80);
        Result.Indent := Nested;
      end;
    ckFailMark, ckFailed:
      begin
        Result.Color := KitBlend(clRed, clWindowText, 75);
        Result.Indent := Nested;
      end;
    ckNote:
      begin
        Result.Italic := True;
        Result.Color := clGrayText;
      end;
    ckError: Result.Color := KitBlend(clRed, clWindowText, 75);
  end;
end;

{ ---------------------------------------------------------------- TAiChatWindow }

constructor TAiChatWindow.Create(AOwner: TComponent);
begin
  inherited;
  { before OnCreate (OldCreateOrder is False): TDockableForm.FormCreate reads Dockable from this
    section of DeskUtil.IDEIniFile }
  DeskSection := ChatWindowSection;
  AutoSave := True;
  FApprover := TChatApprover.Create;
  FMarkdown := TAiMarkdown.Create;
  FMarkdown.OnRun := MarkdownRun;
  FAtLineStart := True;
  FContextPercent := -1;
  InitLook;
  UpdateInfo;
end;

destructor TAiChatWindow.Destroy;
begin
  FreeAndNil(FSession);
  FreeAndNil(FApprover);
  FreeAndNil(FMarkdown);
  inherited;
end;

{ the IDE's fonts (the form laid out for the UI font), the transcript (not a standard control: made
  here, not in the .dfm), the icons, the tool bars' look, the providers, the input's frame and hint }
procedure TAiChatWindow.InitLook;
var
  CodeName: string;
  CodeSize: Integer;
begin
  KitUseIdeFont(Self);
  FTranscript := TKitRichView.Create(Self);
  FTranscript.Align := alClient;
  FTranscript.PopupMenu := TranscriptMenu;
  KitCodeFont(CodeName, CodeSize);
  FTranscript.CodeFontName := CodeName;
  FTranscript.CodeFontSize := CodeSize;
  FTranscript.NewTextCaption := 'New lines';
  TWinControlAccess(FTranscript).OnKeyDown := ChatKeyDown;
  FTranscript.Parent := Self;
  InitIcons;
  { the bar does not wrap (Wrapable False): laid out for a smaller UI font (Delphi 7's), the form
    makes it narrower than its buttons, which would wrap into rows the top bar hides }
  KitFlatToolBar(MainBar);
  FillProviders;
  KitFlatEdit(ProviderCombo);
  { the row as high as the provider box, whose height follows the font }
  if TopBar.Height < ProviderCombo.Height + 2 then TopBar.Height := ProviderCombo.Height + 2;
  KitFlatFrame(InputPanel);
  KitCueText(Input, 'Ask the assistant about your code');
end;

{ the provider box's item of B: the provider and the model its settings give it }
function ProviderText(B: TAiBackendClass): string;
var
  Model: string;
begin
  Result := B.DisplayName;
  Model := HarnessSettings.ReadString(B.Id + '.Model', B.DefaultModel);
  if Model <> '' then Result := Result + ' ' + MiddleDot + ' ' + Model;
end;

{ the registered backends in the provider box with their models - again after Settings, made anew
  when a text changed (a model) - and the widest item's width }
procedure TAiChatWindow.FillProviders;
var
  I: Integer;
  L: TStringList;
  B: TBitmap;
begin
  L := TStringList.Create;
  try
    for I := 0 to AiBackendCount - 1 do L.AddObject(ProviderText(AiBackendClass(I)), TObject(AiBackendClass(I)));
    if L.Text = ProviderCombo.Items.Text then Exit;
    ProviderCombo.Items.BeginUpdate;
    try
      ProviderCombo.Items.Clear;
      for I := 0 to L.Count - 1 do ProviderCombo.Items.AddObject(L[I], L.Objects[I]);
    finally
      ProviderCombo.Items.EndUpdate;
    end;
    B := TBitmap.Create;
    try
      B.Canvas.Font := ProviderCombo.Font;
      FProviderWidth := 0;
      for I := 0 to L.Count - 1 do
        if B.Canvas.TextWidth(L[I]) > FProviderWidth then FProviderWidth := B.Canvas.TextWidth(L[I]);
    finally
      B.Free;
    end;
  finally
    L.Free;
  end;
end;

{ the provider box at the right end of the tool bar's row, its right edge on the view's edge, in
  line with the conversation's frame below it: as wide as its widest item, but not over the bar (8 px
  after it); its list as wide as the widest item }
procedure TAiChatWindow.LayoutProviderBox;
var
  Full, W, Most, Right: Integer;
begin
  { the text, the drop-down button and the box's margins }
  Full := FProviderWidth + GetSystemMetrics(SM_CXVSCROLL) + 14;
  Right := TopBar.ClientWidth;
  Most := Right - (MainBar.Left + MainBar.Width + 8);
  W := Full;
  if W > Most then W := Most;
  if W < 40 then W := 40;
  ProviderCombo.SetBounds(Right - W, (TopBar.ClientHeight - ProviderCombo.Height) div 2, W, ProviderCombo.Height);
  if ProviderCombo.HandleAllocated then SendMessage(ProviderCombo.Handle, CB_SETDROPPEDWIDTH, Full, 0);
end;

{ the backend of the chat: the session's, else the one the settings name }
function TAiChatWindow.CurrentBackendClass: TAiBackendClass;
begin
  if FSession <> nil then Result := TAiBackendClass(FSession.Backend.ClassType)
  else Result := SelectedBackendClass;
end;

{ the provider the settings name for the next turns: the session's backend made anew, and the
  transcript says which provider and model answer from here on - and what keeps them from it }
procedure TAiChatWindow.ProviderChanged;
var
  B: TAiBackend;
  Problem, S: string;
begin
  { a session at work keeps its backend (the box shows it) until its next turn: TakeSelectedProvider }
  if (FSession <> nil) and FSession.Busy then
  begin
    UpdateInfo;
    Exit;
  end;
  B := NewBackend;
  try
    S := 'Provider: ' + ProviderText(TAiBackendClass(B.ClassType));
    PutLine(Wide(IdeToUtf8(S)), ckNote);
    if not B.Ready(Problem) then PutUtf8Line(Problem, ckNote);
  finally
    { the session owns the backend from here on }
    if FSession <> nil then FSession.SetBackend(B) else B.Free;
  end;
  FTranscript.ScrollToEnd;
  UpdateInfo;
end;

{ a provider that Settings chose while the assistant worked, taken before the session's next turn }
procedure TAiChatWindow.TakeSelectedProvider;
begin
  if (FSession <> nil) and not FSession.Busy and (FSession.Backend.ClassType <> SelectedBackendClass) then
    ProviderChanged;
end;

procedure TAiChatWindow.ProviderComboChange(Sender: TObject);
var
  B: TAiBackendClass;
begin
  if ProviderCombo.ItemIndex < 0 then Exit;
  B := TAiBackendClass(ProviderCombo.Items.Objects[ProviderCombo.ItemIndex]);
  { the box is disabled while the assistant works; a choice that came meanwhile is taken back }
  if FWorking or (B = CurrentBackendClass) then
  begin
    UpdateInfo;
    Exit;
  end;
  HarnessSettings.WriteString('Backend', B.Id);
  ProviderChanged;
end;

{ Esc stops the assistant while it works, as Stop does; True when it did }
function TAiChatWindow.EscapeStops: Boolean;
begin
  aStop.Update;
  Result := aStop.Enabled;
  if Result then aStop.Execute;
end;

{ the keys of the transcript and of Send }
procedure TAiChatWindow.ChatKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and (Shift = []) and EscapeStops then Key := 0;
end;

{ the commands in the window's own images (not the IDE's);
  without the resource, captions }
procedure TAiChatWindow.InitIcons;
begin
  KitBitmapIcons(Actions, [MainBar], [TranscriptMenu], AiIconsResource, IconCells, Icons, IconsDisabled);
end;

procedure TAiChatWindow.NeedSession;
begin
  if FSession <> nil then Exit;
  FSession := NewSession;
  FSession.OnEvent := SessionEvent;
  FSession.Approver := FApprover;
end;

procedure TAiChatWindow.Put(const Text: WideString; Kind: TChatKind);
begin
  if Text = '' then Exit;
  FTranscript.AddText(Text, KindFormat(Kind));
  FAtLineStart := Text[Length(Text)] = #13;
end;

procedure TAiChatWindow.EnsureLineStart;
begin
  if not FAtLineStart and (FTranscript.TextLength > 0) then Put(#13, ckBody);
  FAtLineStart := True;
end;

procedure TAiChatWindow.PutLine(const Text: WideString; Kind: TChatKind);
begin
  EnsureLineStart;
  Put(Text + #13, Kind);
end;

procedure TAiChatWindow.PutUtf8Line(const Utf8: string; Kind: TChatKind);
begin
  PutLine(Wide(Utf8), Kind);
end;

procedure TAiChatWindow.MarkdownRun(const Text: WideString; Style: TAiMdStyle);
const
  Kinds: array[TAiMdStyle] of TChatKind = (ckBody, ckBold, ckInline, ckBlock, ckHeading);
begin
  Put(Text, Kinds[Style]);
end;

procedure TAiChatWindow.UpdateInfo;
var
  S: string;
  U: TAiUsage;
  Cost: Double;
  I: Integer;
begin
  { the provider box shows the chat's backend and model; it cannot change while the assistant works }
  I := ProviderCombo.Items.IndexOfObject(TObject(CurrentBackendClass));
  if ProviderCombo.ItemIndex <> I then ProviderCombo.ItemIndex := I;
  ProviderCombo.Enabled := not FWorking and (ProviderCombo.Items.Count > 0);
  if I >= 0 then
    ProviderCombo.Hint := 'The next message goes to ' + ProviderCombo.Items[I] +
      '. Settings chooses the model and the API key.'
  else
    ProviderCombo.Hint := 'No AI backend is registered.';
  LayoutProviderBox;
  if FWorking then S := 'Working ...' else S := 'Ready';
  FContextPercent := -1;
  if FSession <> nil then
  begin
    U := FSession.TotalUsage;
    if U.InputTokens + U.OutputTokens + U.CacheReadTokens + U.CacheWriteTokens > 0 then
    begin
      S := S + Dot + Format('%s in, %s out, %s cached', [Thousands(U.InputTokens), Thousands(U.OutputTokens),
        Thousands(U.CacheReadTokens + U.CacheWriteTokens)]);
      Cost := FSession.Backend.EstimateCost(U);
      if Cost >= 0 then S := S + Dot + Format('about $%s', [FormatFloat('0.00', Cost)]);
    end;
    StatusLabel.Hint := Format('Tokens of this chat: %s in, %s out, %s read from the cache, %s written to it',
      [Thousands(U.InputTokens), Thousands(U.OutputTokens), Thousands(U.CacheReadTokens), Thousands(U.CacheWriteTokens)]);
    if FSession.ContextTokens > 0 then
    begin
      if FSession.ContextWindow > 0 then
      begin
        FContextPercent := ContextPercent(FSession);
        S := S + Dot + Format('context %d%%', [FContextPercent]);
        ContextMeter.Hint := Format('The model''s context window: %s of %s tokens (%d%%)',
          [Thousands(FSession.ContextTokens), Thousands(FSession.ContextWindow), FContextPercent]);
      end
      else
        S := S + Dot + 'context ' + Thousands(FSession.ContextTokens);
    end;
  end;
  StatusLabel.ShowHint := (FSession <> nil) and (FSession.TotalUsage.InputTokens > 0);
  ContextMeter.Visible := FContextPercent >= 0;
  ContextMeter.Invalidate;
  ShowStatus(S);
end;

{ S in the status line of D7 Studio's view, which the form fills; in another IDE in the window's
  own }
procedure TAiChatWindow.ShowStatus(const S: string);
begin
  StatusLabel.Caption := S;
  StatusPanel.Visible := not KitViewStatus(Self, S);
end;

{ the input box at most a third of the window (a view docked low), the splitter moves it within }
procedure TAiChatWindow.Resize;
var
  Most: Integer;
begin
  inherited;
  if InputPanel = nil then Exit;
  Most := ClientHeight div 3;
  if Most < 48 then Most := 48;
  if InputPanel.Height > Most then InputPanel.Height := Most;
  Splitter.MinSize := 40;
end;

{ a new window: in a new parent, which may show the status line (ShowStatus) }
procedure TAiChatWindow.CreateWnd;
begin
  inherited;
  { not while the .dfm is read (its handle is made for the text height): InitLook comes after }
  if FTranscript <> nil then UpdateInfo;
end;

procedure TAiChatWindow.CMShowingChanged(var Message: TMessage);
begin
  inherited;
  if Showing then UpdateInfo;
end;

procedure TAiChatWindow.TopBarResize(Sender: TObject);
begin
  LayoutProviderBox;
end;

{ a flat bar: a 1 px border, filled as far as the context window is full - in the accent colour,
  orange from 80% }
procedure TAiChatWindow.ContextMeterPaint(Sender: TObject);
var
  C: TCanvas;
  R: TRect;
  W: Integer;
begin
  C := ContextMeter.Canvas;
  R := ContextMeter.ClientRect;
  C.Brush.Color := clBtnShadow;
  C.FrameRect(R);
  InflateRect(R, -1, -1);
  W := (R.Right - R.Left) * FContextPercent div 100;
  if W > R.Right - R.Left then W := R.Right - R.Left;
  if W < 0 then W := 0;
  if FContextPercent >= 80 then C.Brush.Color := $0000A5FF else C.Brush.Color := clHighlight;
  C.FillRect(Rect(R.Left, R.Top, R.Left + W, R.Bottom));
  C.Brush.Color := clWindow;
  C.FillRect(Rect(R.Left + W, R.Top, R.Right, R.Bottom));
end;

{ the transcript says once when the context window is 80% full, and what comes next: a summary
  of the conversation, or New Chat }
procedure TAiChatWindow.CheckContext;
var
  Percent: Int64;
  S: string;
begin
  if (FSession = nil) or (FSession.ContextWindow <= 0) then Exit;
  Percent := ContextPercent(FSession);
  if Percent < 70 then FContextWarned := False;
  if (Percent < 80) or FContextWarned then Exit;
  FContextWarned := True;
  S := Format('The conversation fills %d%% of the model''s context window', [Percent]);
  if (FSession.CompactAt > 0) and (FSession.CompactAt < FSession.ContextWindow) then
    S := S + Format('. It is summarized when the prompt reaches %s tokens; New Chat starts over.',
      [Thousands(FSession.CompactAt)])
  else if FSession.CanCompact then
    S := S + ': start a New Chat soon, or let it be summarized earlier - Settings, Summarize at.'
  else
    S := S + ': start a New Chat soon.';
  PutLine(S, ckNote);
end;

procedure TAiChatWindow.SessionEvent(Sender: TObject; Event: TAiEvent);
begin
  case Event.Kind of
    aeTurnStarted:
      PutLine('Assistant', ckAssistant);
    aeBlockStarted:
      case Event.BlockKind of
        abReasoning: EnsureLineStart;
        abText:
          begin
            EnsureLineStart;
            FMarkdown.Reset;
          end;
        abSummary: PutLine('Summarizing the conversation to fit the context window ...', ckNote);
      end;
    aeDelta:
      if Event.BlockKind = abText then FMarkdown.Add(Wide(Event.Text))
      else if Event.BlockKind = abReasoning then Put(Wide(Event.Text), ckReasoning);
    aeBlockFinished:
      if Event.BlockKind = abText then
      begin
        FMarkdown.Finish;
        EnsureLineStart;
      end
      else if Event.BlockKind = abReasoning then EnsureLineStart
      else if Event.BlockKind = abSummary then
      begin
        if Event.IsError then PutLine('The conversation could not be summarized; it goes on as it is.', ckNote)
        else PutLine('The conversation was summarized: the assistant goes on from the summary.', ckNote);
      end;
    aeToolStarted:
      begin
        EnsureLineStart;
        Put(WideString(MarkTool) + ' ', ckTool);
        Put(Wide(Event.Text), ckToolName);
        if Event.Detail <> '' then Put('  ' + FirstLine(Wide(Event.Detail), 120), ckTool);
        Put(#13, ckTool);
      end;
    aeToolFinished:
      begin
        EnsureLineStart;
        if Event.IsError then
        begin
          Put(WideString(MarkFail) + ' ', ckFailMark);
          Put(FirstLine(Wide(Event.Text), 200) + #13, ckFailed);
        end
        else
        begin
          Put(WideString(MarkOk) + ' ', ckOkMark);
          Put(FirstLine(Wide(Event.Text), 200) + #13, ckResult);
        end;
      end;
    aeStatus:
      PutLine(FirstLine(Wide(Event.Text), 300), ckNote);
    aeUsage:
      begin
        UpdateInfo;
        CheckContext;
      end;
    aeError:
      PutUtf8Line(Event.Text, ckError);
    aeTurnFinished:
      begin
        FWorking := False;
        EnsureLineStart;
        UpdateInfo;
      end;
  end;
end;

function TAiChatWindow.SendText(const Text: string): Boolean;
var
  Problem, Context: string;
begin
  Result := False;
  if Trim(Text) = '' then Exit;
  NeedSession;
  if FSession.Busy then Exit;
  TakeSelectedProvider;
  if not FSession.Backend.Ready(Problem) then
  begin
    PutUtf8Line(Problem, ckError);
    Exit;
  end;
  Context := IdeContext;
  PutLine('You', ckYou);
  Put(Wide(IdeToUtf8(Text)) + #13, ckBody);
  FTranscript.ScrollToEnd;
  FWorking := True;
  UpdateInfo;
  FSession.Send(IdeToUtf8(Text), Context);
  Result := True;
end;

procedure TAiChatWindow.aSendExecute(Sender: TObject);
var
  T: string;
begin
  { the text stays in the box when it could not be sent (no API key ...) }
  T := Input.Text;
  if SendText(T) then Input.Clear;
end;

procedure TAiChatWindow.aSendUpdate(Sender: TObject);
begin
  aSend.Enabled := ((FSession = nil) or not FSession.Busy) and (Input.GetTextLen > 0);
end;

procedure TAiChatWindow.aStopExecute(Sender: TObject);
begin
  if FSession <> nil then FSession.Cancel;
end;

procedure TAiChatWindow.aStopUpdate(Sender: TObject);
begin
  aStop.Enabled := (FSession <> nil) and FSession.Busy;
end;

procedure TAiChatWindow.aContinueExecute(Sender: TObject);
begin
  if (FSession = nil) or not FSession.CanRetry then Exit;
  TakeSelectedProvider;
  FWorking := True;
  UpdateInfo;
  FSession.Retry;
end;

procedure TAiChatWindow.aContinueUpdate(Sender: TObject);
begin
  aContinue.Enabled := (FSession <> nil) and FSession.CanRetry and
    (FSession.LastResult in [atrError, atrCancelled, atrLimit, atrRefused]);
end;

procedure TAiChatWindow.aNewChatExecute(Sender: TObject);
begin
  if (FSession <> nil) and FSession.Busy then Exit;
  if FSession <> nil then FSession.Clear;
  FTranscript.Clear;
  FMarkdown.Reset;
  FAtLineStart := True;
  FContextWarned := False;
  UpdateInfo;
end;

procedure TAiChatWindow.aNewChatUpdate(Sender: TObject);
begin
  aNewChat.Enabled := (FSession = nil) or not FSession.Busy;
end;

procedure TAiChatWindow.aSettingsExecute(Sender: TObject);
var
  Was: TAiBackendClass;
begin
  Was := CurrentBackendClass;
  if not TAiSettingsDialog.Execute(HarnessSettings) then Exit;
  if (FSession <> nil) and not FSession.Busy then
    FSession.MaxRounds := HarnessSettings.ReadInteger('MaxRounds', 60);
  FillProviders;
  if SelectedBackendClass <> Was then ProviderChanged
  else UpdateInfo;
end;

procedure TAiChatWindow.aCopyExecute(Sender: TObject);
begin
  FTranscript.CopyToClipboard;
end;

procedure TAiChatWindow.aCopyUpdate(Sender: TObject);
begin
  aCopy.Enabled := (FTranscript <> nil) and FTranscript.HandleAllocated and FTranscript.HasSelection;
end;

procedure TAiChatWindow.aSelectAllExecute(Sender: TObject);
begin
  FTranscript.SelectAll;
end;

procedure TAiChatWindow.InputChange(Sender: TObject);
begin
  { the hint text of an empty box comes and goes }
  Input.Invalidate;
end;

procedure TAiChatWindow.InputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  FEatReturn := False;
  ChatKeyDown(Sender, Key, Shift);
  if (Key = VK_RETURN) and not (ssShift in Shift) and not (ssCtrl in Shift) then
  begin
    FEatReturn := True;
    Key := 0;
    aSend.Update;
    if aSend.Enabled then aSend.Execute;
  end;
end;

procedure TAiChatWindow.InputKeyPress(Sender: TObject; var Key: Char);
begin
  if (Key = #13) and FEatReturn then Key := #0;
  FEatReturn := False;
end;

end.
