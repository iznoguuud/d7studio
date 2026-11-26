{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaPalette;

{ D7 Studio - Delphi 7's component palette as experts reach it.
  Experts read Delphi's palette through its main form, past the Open Tools API:
  Application.FindComponent('AppBuilder'), then the components TabControl (the pages: Tabs,
  TabIndex, OnChange) and Palette (the tools of the page shown, through the published properties
  of Palettes.TPalette: SelectedIndex, PalToolCount, SelectedToolName, SelectedTool, Selector,
  OnChange). CompBar lists every component so, and drops one by choosing its tool and clicking
  on the form.
  D7 Studio has no palette (the Components view replaced it). TSdIdePalette makes the two with
  Delphi's names, owned by the main form, in a panel that is never shown - an expert that sets
  TabControl.Visible shows nothing -, and fills them from SdDesignHost's palette: the pages and
  tools the Components view shows, hidden ones left out. A tool chosen through them is placed by
  the next left click on the designed form (SdFormDesigner.PaletteToolHook, set by the main
  form), as Delphi's palette does; then the selector is down again (Shift keeps the tool). }

interface

uses
  SysUtils, Classes, Controls, ComCtrls, Buttons, ExtCtrls, SdDesignHost;

type
  { Palettes.TPalette's published face: the tools of the page shown }
  TSdPalette = class(TCustomControl)
  private
    FTools: TList;                     // TPaletteItem of the page shown
    FSelectedIndex: Integer;           // -1: none, the selector is down
    FSelector: TSpeedButton;
    FOnChange: TNotifyEvent;
    procedure SetSelectedIndex(Value: Integer);
    function GetSelectedToolName: string;
    function GetSelectedTool: TPersistent;
    function GetPalToolCount: Integer;
    procedure SelectorClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { the tools of Page, none chosen (nil: no page) }
    procedure ShowPage(Page: TPalettePage);
    { the tool chosen; nil: the selector }
    function SelectedItem: TPaletteItem;
  published
    property Align;
    property AutoSize;
    property SelectedIndex: Integer read FSelectedIndex write SetSelectedIndex;
    { the chosen tool's class name (a component template: its name; the Frames tool: Frames),
      '' for the selector }
    property SelectedToolName: string read GetSelectedToolName;
    { Delphi's is its TPaletteItem: nil here - GetStrProp of it gives '' there as here }
    property SelectedTool: TPersistent read GetSelectedTool;
    { the selector button: its Click chooses no tool }
    property Selector: TSpeedButton read FSelector write FSelector;
    property PalToolCount: Integer read GetPalToolCount;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnMouseWheel;
  end;

  { the main form's hidden palette }
  TSdIdePalette = class
  private
    FHost: TPanel;
    FTabs: TTabControl;
    FPalette: TSdPalette;
    FPages: TList;                     // the TPalettePage of each tab
    procedure TabsChange(Sender: TObject);
  public
    { Form: the main form, the components' owner (their names are Delphi's) and parent }
    constructor Create(Form: TWinControl);
    destructor Destroy; override;
    { SdDesignHost's palette changed: the pages and tools again, the page shown kept }
    procedure Reload;
    function SelectedItem: TPaletteItem;
    { after a tool was placed: the selector down again }
    procedure ClearSelection;
    { test mode: 'pages=n tab=name tools=n selected=name' }
    function DebugText: string;
    property Palette: TSdPalette read FPalette;
    property Tabs: TTabControl read FTabs;
  end;

implementation

{ ---------------------------------------------------------------- TSdPalette }

constructor TSdPalette.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTools := TList.Create;
  FSelectedIndex := -1;
  FSelector := TSpeedButton.Create(Self);
  FSelector.GroupIndex := 1;
  FSelector.AllowAllUp := True;
  FSelector.Down := True;
  FSelector.OnClick := SelectorClick;
  FSelector.Parent := Self;
end;

destructor TSdPalette.Destroy;
begin
  FreeAndNil(FTools);
  inherited;
end;

procedure TSdPalette.ShowPage(Page: TPalettePage);
var
  I: Integer;
begin
  FTools.Clear;
  if Page <> nil then
    for I := 0 to Page.Items.Count - 1 do
      if not TPaletteItem(Page.Items[I]).Hidden then FTools.Add(Page.Items[I]);
  if FSelectedIndex >= 0 then
  begin
    FSelectedIndex := -1;
    FSelector.Down := True;
    if Assigned(FOnChange) then FOnChange(Self);
  end;
end;

function TSdPalette.SelectedItem: TPaletteItem;
begin
  if (FTools <> nil) and (FSelectedIndex >= 0) and (FSelectedIndex < FTools.Count) then
    Result := TPaletteItem(FTools[FSelectedIndex])
  else
    Result := nil;
end;

procedure TSdPalette.SetSelectedIndex(Value: Integer);
begin
  if (Value < 0) or (Value >= FTools.Count) then Value := -1;
  if Value = FSelectedIndex then Exit;
  FSelectedIndex := Value;
  FSelector.Down := Value < 0;
  if Assigned(FOnChange) then FOnChange(Self);
end;

function TSdPalette.GetSelectedToolName: string;
var
  It: TPaletteItem;
begin
  It := SelectedItem;
  if It = nil then Result := ''
  else if It.Caption <> '' then Result := It.Caption       // a template's name; Frames, as Delphi's
  else Result := It.ComponentClass.ClassName;
end;

function TSdPalette.GetSelectedTool: TPersistent;
begin
  Result := nil;
end;

function TSdPalette.GetPalToolCount: Integer;
begin
  Result := FTools.Count;
end;

procedure TSdPalette.SelectorClick(Sender: TObject);
begin
  SetSelectedIndex(-1);
end;

{ ---------------------------------------------------------------- TSdIdePalette }

constructor TSdIdePalette.Create(Form: TWinControl);
begin
  inherited Create;
  FPages := TList.Create;
  FHost := TPanel.Create(Form);
  FHost.Visible := False;
  FHost.Parent := Form;
  FTabs := TTabControl.Create(Form);
  FTabs.Name := 'TabControl';
  FTabs.Parent := FHost;
  FTabs.OnChange := TabsChange;
  FPalette := TSdPalette.Create(Form);
  FPalette.Name := 'Palette';
  FPalette.Parent := FTabs;
  FPalette.Align := alClient;
  Reload;
end;

destructor TSdIdePalette.Destroy;
begin
  FPages.Free;
  inherited;
end;

procedure TSdIdePalette.Reload;
var
  I, J: Integer;
  P: TPalettePage;
  Shown: string;
  Any: Boolean;
begin
  if FTabs.TabIndex >= 0 then Shown := FTabs.Tabs[FTabs.TabIndex] else Shown := '';
  FPages.Clear;
  FTabs.Tabs.BeginUpdate;
  try
    FTabs.Tabs.Clear;
    for I := 0 to DesignHost.PageCount - 1 do
    begin
      P := DesignHost.Pages[I];
      Any := False;
      for J := 0 to P.Items.Count - 1 do
        if not TPaletteItem(P.Items[J]).Hidden then Any := True;
      if not Any then Continue;
      FPages.Add(P);
      FTabs.Tabs.Add(P.Name);
    end;
  finally
    FTabs.Tabs.EndUpdate;
  end;
  I := FTabs.Tabs.IndexOf(Shown);
  if (I < 0) and (FTabs.Tabs.Count > 0) then I := 0;
  FTabs.TabIndex := I;
  TabsChange(FTabs);
end;

{ the tab control's OnChange: experts call it themselves after setting TabIndex, as Delphi's
  palette needs it }
procedure TSdIdePalette.TabsChange(Sender: TObject);
var
  I: Integer;
begin
  I := FTabs.TabIndex;
  if (I >= 0) and (I < FPages.Count) then FPalette.ShowPage(TPalettePage(FPages[I]))
  else FPalette.ShowPage(nil);
end;

function TSdIdePalette.SelectedItem: TPaletteItem;
begin
  Result := FPalette.SelectedItem;
end;

procedure TSdIdePalette.ClearSelection;
begin
  FPalette.SelectedIndex := -1;
end;

function TSdIdePalette.DebugText: string;
var
  Tab: string;
begin
  if FTabs.TabIndex >= 0 then Tab := FTabs.Tabs[FTabs.TabIndex] else Tab := '';
  Result := Format('pages=%d tab=%s tools=%d selected=%s', [FTabs.Tabs.Count, Tab,
    FPalette.PalToolCount, FPalette.SelectedToolName]);
end;

end.
