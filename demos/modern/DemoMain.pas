{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit DemoMain;

{ The demo's main window (DemoMain.dfm).

  On the left a sidebar of five areas, on the right the page of the one chosen, each page a few
  white cards on the grey window, and at the bottom the activity - what happened. The table Areas
  below describes the areas: the sidebar, the page titles and the list and tree of the Look page
  are made from it.

  The window is designed at 96 DPI (100 %). The manifest of ModernManUtf8 (ModernDemo.dpr) makes the
  program per-monitor DPI aware, so the VCL scales the window for the monitor it opens on and again
  whenever it moves to a monitor with another scale. Look for "Modernized:" in the comments: each one
  marks where the demo uses something the modernized RTL/VCL adds. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, StdCtrls, ComCtrls,
  ExtCtrls, ToolWin, ImgList, DemoFacts, DemoGauge, DemoPanel;

type
  { The panels of this form whose Tag is 1 are cards: white, with rounded corners and a light grey
    edge. Declaring a class of the same name before the form makes the form's panels of this class
    - a way to change how a control looks without a component package. }
  TPanel = class(ExtCtrls.TPanel)
  protected
    procedure Paint; override;
  end;

  TMainForm = class(TForm)
    ToolBar: TToolBar;
    btnRefresh: TToolButton;
    btnFloat: TToolButton;
    btnClear: TToolButton;
    btnSettings: TToolButton;
    Nav: TListBox;
    Body: TPanel;
    Header: TPanel;
    TitleLabel: TLabel;
    IntroLabel: TLabel;
    InfoLabel: TLabel;
    LogCard: TPanel;
    LogTitle: TLabel;
    LogMemo: TMemo;
    Gap: TPanel;
    DisplayPage: TPanel;
    FactsCard: TPanel;
    FactsTitle: TLabel;
    FactsHost: TPanel;
    PanelCard: TPanel;
    PanelTitle: TLabel;
    HostPanel: TPanel;
    IconsCard: TPanel;
    IconsTitle: TLabel;
    IconsBox: TPaintBox;
    RulerCard: TPanel;
    RulerTitle: TLabel;
    RulerHost: TPanel;
    UnicodePage: TPanel;
    TextCard: TPanel;
    TextTitle: TLabel;
    SampleEdit: TEdit;
    CopyButton: TButton;
    PasteButton: TButton;
    CountButton: TButton;
    FileButton: TButton;
    SortCard: TPanel;
    SortTitle: TLabel;
    Words: TListBox;
    SortButton: TButton;
    DialogsPage: TPanel;
    DialogsCard: TPanel;
    DialogsTitle: TLabel;
    MessageNote: TLabel;
    QuestionNote: TLabel;
    OpenNote: TLabel;
    SaveNote: TLabel;
    FolderNote: TLabel;
    MessageButton: TButton;
    QuestionButton: TButton;
    OpenButton: TButton;
    SaveButton: TButton;
    FolderButton: TButton;
    LookPage: TPanel;
    ViewsCard: TPanel;
    ViewsTitle: TLabel;
    AreaList: TListView;
    AreaTree: TTreeView;
    TitleCard: TPanel;
    DarkTitle: TCheckBox;
    SystemPage: TPanel;
    SystemCard: TPanel;
    SystemTitle: TLabel;
    SystemHost: TPanel;
    SetImages: TImageList;
    Images: TImageList;
    OpenDialog: TOpenDialog;
    SaveDialog: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure NavClick(Sender: TObject);
    procedure NavDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnFloatClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnSettingsClick(Sender: TObject);
    procedure IconsBoxPaint(Sender: TObject);
    procedure CopyButtonClick(Sender: TObject);
    procedure PasteButtonClick(Sender: TObject);
    procedure CountButtonClick(Sender: TObject);
    procedure FileButtonClick(Sender: TObject);
    procedure SortButtonClick(Sender: TObject);
    procedure MessageButtonClick(Sender: TObject);
    procedure QuestionButtonClick(Sender: TObject);
    procedure OpenButtonClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
    procedure FolderButtonClick(Sender: TObject);
    procedure DarkTitleClick(Sender: TObject);
  private
    FDisplayFacts: TFactsFrame;
    FSystemFacts: TFactsFrame;
    FGauge: TDpiGauge;
    FPanel: TPanelForm;
    FDpiChanges: Integer;
    procedure AddArea(Index: Integer);
    procedure ShowArea(Index: Integer);
    function NewFacts(Host: TWinControl): TFactsFrame;
    procedure AddLog(const Text: string);
    procedure ShowFacts;
    procedure CMDpiChanged(var Message: TMessage); message CM_DPICHANGED;
    procedure WMExitSizeMove(var Message: TMessage); message WM_EXITSIZEMOVE;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

uses
  ShellAPI, Clipbrd, Utf8Mode, ShellScaling, WindowsEx, DwmApi, BCrypt, DemoIcons;

const
  { the colours of the design; the window's grey is in DemoMain.dfm (Color = 15987699) }
  CardEdge = $00E5E5E5;         // RGB(229, 229, 229)
  NavChosen = $00E8E8E8;        // the chosen entry of the sidebar
  Accent = $00B85F00;           // RGB(0, 95, 184): Windows' blue

type
  TArea = record
    Title: string;      // its name in the sidebar and above its page
    Units: string;      // the units of the modernized RTL/VCL it shows, separated by commas
    Intro: string;      // what its page shows, under the title
  end;

const
  { the areas, in the order of the sidebar, of the pages (Tag 10, 11 ... in DemoMain.dfm) and of
    their icons }
  Areas: array[0..4] of TArea = (
    (Title: 'Display'; Units: 'Forms,Controls,ImgList,ShellScaling';
     Intro: 'Move the window to a monitor with another scale, or change the scale in Windows'' ' +
       'settings: everything here follows.'),
    (Title: 'Unicode'; Units: 'Utf8Mode,SysUtils,Classes,Clipbrd';
     Intro: 'A string holds UTF-8: any script works in controls, the clipboard, sorting and file ' +
       'names. Type or paste any text.'),
    (Title: 'Dialogs'; Units: 'Dialogs,FileCtrl';
     Intro: 'The VCL''s dialogs are Windows'' current ones: task dialogs, the Open and Save dialogs, ' +
       'the folder picker.'),
    (Title: 'Look'; Units: 'ComCtrls,DwmApi,ModernMan';
     Intro: 'Lists and trees look like Windows Explorer''s and draw without flicker; the title bar ' +
       'can be dark.'),
    (Title: 'System'; Units: 'WindowsEx,BCrypt,System';
     Intro: 'The Windows API up to Windows 11: the real version, every monitor, cryptography, the ' +
       'FastMM4 memory manager.'));

{ ---- the cards ---- }

procedure TPanel.Paint;
var
  Radius: Integer;
begin
  if Tag <> 1 then
  begin
    inherited Paint;
    Exit;
  end;
  { the corners outside the card in the colour of what it lies on, then the card }
  Canvas.Brush.Color := TWinControl(Parent).Brush.Color;
  Canvas.FillRect(ClientRect);
  Canvas.Brush.Color := Color;
  Canvas.Pen.Color := CardEdge;
  Radius := ScaleForDpi(8, Self);
  Canvas.RoundRect(0, 0, Width, Height, Radius, Radius);
end;

{ ---- small helpers ---- }

function Percent(Dpi: Integer): string;
begin
  Result := Format('%d %%', [MulDiv(Dpi, 100, 96)]);
end;

{ Bytes as hexadecimal digits }
function ToHex(const Bytes: array of Byte): string;
var
  I: Integer;
begin
  Result := '';
  for I := Low(Bytes) to High(Bytes) do
    Result := Result + LowerCase(IntToHex(Bytes[I], 2));
end;

function TempFolder: string;
var
  Buffer: array[0..MAX_PATH] of Char;
begin
  SetString(Result, Buffer, GetTempPath(SizeOf(Buffer), Buffer));
end;

{ ---- the window ---- }

procedure TMainForm.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  { 1. The icons: the tool bar's list gets them as Windows draws them at four sizes; the other list,
       shown beside it on the Display page, at 16 x 16 only (DemoIcons) }
  AddIcons(SetImages, [16, 20, 24, 32]);
  AddIcons(Images, [16]);
  { 2. The sidebar, and the list and tree of the Look page, from the table of areas }
  for I := Low(Areas) to High(Areas) do
    AddArea(I);
  AreaTree.TopItem := AreaTree.Items.GetFirstNode;
  { 3. Two lists of facts, frames made at run time (DemoFacts) }
  FDisplayFacts := NewFacts(FactsHost);
  FSystemFacts := NewFacts(SystemHost);
  { 4. A control that paints itself for every DPI (DemoGauge) }
  FGauge := TDpiGauge.Create(Self);
  FGauge.Parent := RulerHost;
  FGauge.Align := alClient;
  { 5. A form embedded in a panel; Float puts it into a window of its own (DemoPanel) }
  FPanel := TPanelForm.Create(Self);
  FPanel.OnLog := AddLog;
  FPanel.Parent := HostPanel;
  FPanel.Align := alClient;
  FPanel.Visible := True;
  Nav.ItemIndex := 0;
  ShowArea(0);
end;

{ The sidebar's entry of Areas[Index], and its rows in the Look page's list and tree. }
procedure TMainForm.AddArea(Index: Integer);
var
  Units: TStringList;
  Root: TTreeNode;
  I: Integer;
begin
  Nav.Items.Add(Areas[Index].Title);
  with AreaList.Items.Add do
  begin
    Caption := Areas[Index].Title;
    ImageIndex := icoDisplay + Index;
    SubItems.Add(StringReplace(Areas[Index].Units, ',', ', ', [rfReplaceAll]));
  end;
  Root := AreaTree.Items.Add(nil, Areas[Index].Title);
  Units := TStringList.Create;
  try
    Units.CommaText := Areas[Index].Units;
    for I := 0 to Units.Count - 1 do
      AreaTree.Items.AddChild(Root, Units[I]);
  finally
    Units.Free;
  end;
  Root.Expand(False);
end;

{ The page of Areas[Index]: the page whose Tag is 10 + Index shows, the others hide. }
procedure TMainForm.ShowArea(Index: Integer);
var
  I: Integer;
begin
  for I := 0 to Body.ControlCount - 1 do
    if Body.Controls[I].Tag >= 10 then
      Body.Controls[I].Visible := Body.Controls[I].Tag = 10 + Index;
  TitleLabel.Caption := Areas[Index].Title;
  IntroLabel.Caption := Areas[Index].Intro;
end;

{ A list of facts filling Host. Modernized: a frame made at run time is scaled from 96 DPI to the
  DPI of its form when it is first put on it. }
function TMainForm.NewFacts(Host: TWinControl): TFactsFrame;
begin
  Result := TFactsFrame.Create(Host);
  Result.Parent := Host;
  Result.Align := alClient;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  AddLog(Format('Shown at %d DPI', [PixelsPerInch]));
  ShowFacts;
end;

procedure TMainForm.AddLog(const Text: string);
begin
  LogMemo.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '   ' + Text);
end;

{ ---- the sidebar ---- }

procedure TMainForm.NavClick(Sender: TObject);
begin
  if Nav.ItemIndex >= 0 then
    ShowArea(Nav.ItemIndex);
end;

{ An entry of the sidebar: its icon and name, and for the chosen one a light grey ground with a
  blue mark at its left, as Windows 11's Settings draw theirs. }
procedure TMainForm.NavDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  C: TCanvas;
  R: TRect;
  Inset, Radius, Y: Integer;
begin
  C := Nav.Canvas;
  C.Brush.Color := Nav.Color;
  C.FillRect(Rect);
  Inset := ScaleForDpi(6, Self);
  R := Classes.Rect(Rect.Left + Inset, Rect.Top + 2, Rect.Right - Inset, Rect.Bottom - 2);
  if odSelected in State then
  begin
    Radius := ScaleForDpi(8, Self);
    C.Brush.Color := NavChosen;
    C.Pen.Color := NavChosen;
    C.RoundRect(R.Left, R.Top, R.Right, R.Bottom, Radius, Radius);
    C.Brush.Color := Accent;
    Y := (R.Top + R.Bottom) div 2;
    C.FillRect(Classes.Rect(R.Left, Y - ScaleForDpi(8, Self), R.Left + ScaleForDpi(3, Self),
      Y + ScaleForDpi(8, Self)));
  end;
  SetImages.Draw(C, R.Left + ScaleForDpi(14, Self), (R.Top + R.Bottom - SetImages.Height) div 2,
    icoDisplay + Index);
  C.Brush.Style := bsClear;
  C.Font := Nav.Font;
  C.TextOut(R.Left + ScaleForDpi(44, Self), (R.Top + R.Bottom - C.TextHeight('Wg')) div 2,
    Nav.Items[Index]);
  { the list box draws a dotted focus frame after this: drawing it here as well takes it away }
  if odFocused in State then
    DrawFocusRect(C.Handle, Rect);
end;

{ ---- what the window measures: the Display and System pages, the header ---- }

procedure TMainForm.ShowFacts;
var
  M: TMonitor;
  Memory: TMemoryManagerState;
  Bytes, Blocks, Major, Minor, Build: Cardinal;
  Hash: array[0..31] of Byte;
  RandomBytes: array[0..7] of Byte;
  Text: string;
  WorkArea: TRect;
  I: Integer;
begin
  M := Monitor;
  FDisplayFacts.Show([
    'This window''s DPI', Format('%d (%s)', [PixelsPerInch, Percent(PixelsPerInch)]),
    'Its monitor', Format('%d of %d, at %d DPI', [M.MonitorNum + 1, Screen.MonitorCount, GetMonitorDpi(M)]),
    'Per-monitor V2 aware', BoolToStr(IsPerMonitorV2DpiAware, True),
    'Font size', Format('%d pt = %d px', [Font.Size, -Font.Height]),
    'ScaleForDpi(100)', IntToStr(ScaleForDpi(100, Self)),
    'Scroll bar width', Format('%d px', [GetSystemMetricForControl(SM_CXVSCROLL, Self)]),
    'CM_DPICHANGED heard', IntToStr(FDpiChanges)]);

  { Modernized: the real version, which GetVersionEx hides from programs (WindowsEx) }
  GetRealWindowsVersion(Major, Minor, Build);
  Text := Format('%d.%d, build %d', [Major, Minor, Build]);
  if IsWindows11OrGreater then
    Text := 'Windows 11, version ' + Text;
  { Modernized: the memory manager is FastMM4, which tells what is in use (System) }
  GetMemoryManagerState(Memory);
  Bytes := Memory.TotalAllocatedMediumBlockSize + Memory.TotalAllocatedLargeBlockSize;
  Blocks := Memory.AllocatedMediumBlockCount + Memory.AllocatedLargeBlockCount;
  for I := Low(Memory.SmallBlockTypeStates) to High(Memory.SmallBlockTypeStates) do
    with Memory.SmallBlockTypeStates[I] do
    begin
      Inc(Bytes, AllocatedBlockCount * UseableBlockSize);
      Inc(Blocks, AllocatedBlockCount);
    end;
  { Modernized: Windows' cryptography (BCrypt) }
  FillChar(Hash, SizeOf(Hash), 0);
  BCryptHash(BCRYPT_SHA256_ALG_HANDLE, nil, 0, PUCHAR(PChar(Caption)), Length(Caption), @Hash, SizeOf(Hash));
  BCryptGenRandom(nil, @RandomBytes, SizeOf(RandomBytes), BCRYPT_USE_SYSTEM_PREFERRED_RNG);
  FSystemFacts.Show([
    'Windows (WindowsEx.GetRealWindowsVersion)', Text,
    'Text in this program (Utf8Mode)', Format('UTF-8: %s; other programs: code page %d',
      [BoolToStr(IsUtf8Mode, True), SystemLegacyCodePage]),
    'Taskbar (Forms.MainFormOnTaskbar)', 'one button, the main window''s',
    'Memory in use (FastMM4)', Format('%.0n KB in %d blocks', [Bytes / 1024, Blocks]),
    'SHA-256 of the window''s caption', ToHex(Hash),
    'Random bytes (BCryptGenRandom)', ToHex(RandomBytes)]);
  { Modernized: monitors anywhere on the desktop, with their work areas (Controls.MonitorWorkAreaAt) }
  for I := 0 to Screen.MonitorCount - 1 do
    with Screen.Monitors[I] do
    begin
      WorkArea := MonitorWorkAreaAt(Point(Left, Top));
      FSystemFacts.Add(Format('Monitor %d', [I + 1]), Format('%d x %d at %d, %d; %d DPI; work area %d x %d',
        [Width, Height, Left, Top, GetMonitorDpi(Screen.Monitors[I]),
         WorkArea.Right - WorkArea.Left, WorkArea.Bottom - WorkArea.Top]));
    end;

  if IsUtf8Mode then
    Text := 'UTF-8'
  else
    Text := Format('code page %d', [GetACP]);
  InfoLabel.Caption := Format('%s   |   %d DPI   |   monitor %d of %d   |   %s',
    [Percent(PixelsPerInch), PixelsPerInch, M.MonitorNum + 1, Screen.MonitorCount, Text]);
  Nav.ItemHeight := ScaleForDpi(36, Self);
end;

{ Modernized: the VCL has scaled the window and everything on it for a new DPI - after a move to a
  monitor with another scale, or a change of the scale in Windows' settings. It tells the form and
  each control with CM_DPICHANGED (WParam the old DPI, LParam the new). }
procedure TMainForm.CMDpiChanged(var Message: TMessage);
begin
  inherited;
  Inc(FDpiChanges);
  AddLog(Format('The window was scaled from %d to %d DPI', [Message.WParam, Message.LParam]));
  ShowFacts;
end;

{ moved to another monitor of the same scale: no new DPI, but other facts }
procedure TMainForm.WMExitSizeMove(var Message: TMessage);
begin
  inherited;
  ShowFacts;
end;

{ ---- the tool bar ---- }

procedure TMainForm.btnRefreshClick(Sender: TObject);
begin
  ShowFacts;
end;

{ The embedded form into a window of its own, or back onto its card. Modernized: floating, it
  follows the monitor it is moved to; put back, it is scaled from its DPI to the panel's. }
procedure TMainForm.btnFloatClick(Sender: TObject);
const
  Captions: array[Boolean] of string = ('Float', 'Dock');
var
  Floating: Boolean;
  P: TPoint;
begin
  Floating := FPanel.Parent <> nil;
  P := HostPanel.ClientToScreen(Point(ScaleForDpi(32, Self), ScaleForDpi(32, Self)));
  FPanel.Hide;
  if Floating then
  begin
    FPanel.Align := alNone;
    FPanel.Parent := nil;
    FPanel.BorderStyle := bsSizeToolWin;
    FPanel.SetBounds(P.X, P.Y, FPanel.Width, FPanel.Height);
  end
  else
  begin
    FPanel.BorderStyle := bsNone;
    FPanel.Parent := HostPanel;
    FPanel.Align := alClient;
  end;
  FPanel.Show;
  btnFloat.Caption := Captions[Floating];
  if Floating then
    AddLog('The embedded form floats: move its window to a monitor with another scale, then dock it')
  else
    AddLog('The embedded form is on its card again');
end;

procedure TMainForm.btnClearClick(Sender: TObject);
begin
  LogMemo.Clear;
end;

procedure TMainForm.btnSettingsClick(Sender: TObject);
begin
  ShellExecute(Handle, 'open', 'ms-settings:display', nil, nil, SW_SHOWNORMAL);
end;

{ ---- Display: the two image lists side by side, at their size for this DPI ---- }

procedure TMainForm.IconsBoxPaint(Sender: TObject);
var
  C: TCanvas;
  Y: Integer;

  procedure DrawRow(List: TCustomImageList; const Title: string);
  var
    I, Space: Integer;
  begin
    Space := ScaleForDpi(10, Self);
    C.TextOut(0, Y + (List.Height - C.TextHeight(Title)) div 2, Title);
    for I := 0 to List.Count - 1 do
      List.Draw(C, ScaleForDpi(140, Self) + I * (List.Width + Space), Y, I);
    Inc(Y, List.Height + Space);
  end;

begin
  C := IconsBox.Canvas;
  C.Font := Font;
  C.Font.Color := clGrayText;
  C.Brush.Style := bsClear;
  Y := 0;
  { Modernized: the first list has the icons drawn for this size; the second only at 16 x 16, so
    above 100 % it enlarges them (ImgList.AddImageListResolution, DemoIcons) }
  DrawRow(SetImages, 'Drawn for this size');
  DrawRow(Images, 'Enlarged from 16 px');
end;

{ ---- Unicode ---- }

{ Modernized: the clipboard holds Unicode text (Clipbrd) }
procedure TMainForm.CopyButtonClick(Sender: TObject);
begin
  Clipboard.AsText := SampleEdit.Text;
  AddLog('Copied: ' + SampleEdit.Text);
end;

procedure TMainForm.PasteButtonClick(Sender: TObject);
begin
  SampleEdit.Text := Clipboard.AsText;
end;

{ Length counts bytes: in UTF-8 a character takes one to four of them. Modernized: Utf8Mode converts
  between the program's code page and UTF-16. }
procedure TMainForm.CountButtonClick(Sender: TObject);
var
  Wide: WideString;
  I, Characters: Integer;
begin
  Wide := CodePageToWide(SampleEdit.Text, CP_ACP);
  Characters := 0;
  for I := 1 to Length(Wide) do
    if (Word(Wide[I]) < $DC00) or (Word(Wide[I]) > $DFFF) then   // not the second half of a pair
      Inc(Characters);
  AddLog(Format('%d characters, %d UTF-16 code units, %d bytes', [Characters, Length(Wide), Length(SampleEdit.Text)]));
end;

{ Modernized: file names take any script, through the same functions as before (SysUtils, Classes) }
procedure TMainForm.FileButtonClick(Sender: TObject);
var
  Name: string;
begin
  Name := TempFolder + SampleEdit.Text + '.txt';
  TFileStream.Create(Name, fmCreate).Free;
  if FileExists(Name) then
    AddLog('Made and found again: ' + Name);
  DeleteFile(Name);
end;

{ Modernized: TStringList.Sort compares as Windows does (CompareString), now for every script }
procedure TMainForm.SortButtonClick(Sender: TObject);
var
  List: TStringList;
begin
  List := TStringList.Create;
  try
    List.Assign(Words.Items);
    List.Sort;
    Words.Items := List;
  finally
    List.Free;
  end;
end;

{ ---- Dialogs: each of them is Windows' current one ---- }

procedure TMainForm.MessageButtonClick(Sender: TObject);
begin
  MessageDlg('MessageDlg shows a task dialog now.', mtInformation, [mbOK], 0);
end;

procedure TMainForm.QuestionButtonClick(Sender: TObject);
const
  Answers: array[mrNone..mrNo] of string = ('none', 'OK', 'Cancel', 'Abort', 'Retry', 'Ignore', 'Yes', 'No');
var
  Answer: Integer;
begin
  Answer := TaskMessageDlg('Save the changes?', 'TaskMessageDlg shows a title in large type and ' +
    'the text below it.', mtConfirmation, mbYesNoCancel, 0);
  if Answer in [mrNone..mrNo] then
    AddLog('Answered: ' + Answers[Answer]);
end;

procedure TMainForm.OpenButtonClick(Sender: TObject);
begin
  if OpenDialog.Execute then
    AddLog('Open: ' + OpenDialog.FileName);
end;

procedure TMainForm.SaveButtonClick(Sender: TObject);
begin
  if SaveDialog.Execute then
    AddLog('Save as: ' + SaveDialog.FileName);
end;

procedure TMainForm.FolderButtonClick(Sender: TObject);
var
  Folder: string;
  Accepted: Boolean;
begin
  Folder := '';
  if ExecuteFolderDialog('Choose a folder', Folder, Accepted) and Accepted then
    AddLog('Folder: ' + Folder);
end;

{ ---- Look ---- }

{ Modernized: the title bar drawn dark or light (DwmApi) }
procedure TMainForm.DarkTitleClick(Sender: TObject);
begin
  SetWindowDarkMode(Handle, DarkTitle.Checked);
end;

end.
