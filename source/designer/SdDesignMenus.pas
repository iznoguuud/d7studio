{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDesignMenus;

{ D7 Studio - Delphi's design-time menu interfaces (DesignMenus: IMenuItems, IMenuItem) over the
  VCL menu items of D7 Studio's menus: what a component or selection editor's PrepareItem gets
  for the item of one of its verbs.

  * A menu item linked to an action shows the action's caption and states, so its states are
    set on the action; an item without one (a line) keeps them itself.
  * The items an editor adds are commands like all others: an action each, in the action list
    the verbs' actions live in (cleared with them). Such an action runs the editor's handler with
    the menu item as Sender, as Delphi's own menu items give it.
  * An item an editor names keeps the name when its owner has no component of that name. }

interface

uses
  Classes, Menus, ActnList, DesignMenus;

{ Item as IMenuItem; the actions of the items an editor adds go into Actions }
function MenuItemIntf(Item: TMenuItem; Actions: TActionList): IMenuItem;

implementation

uses
  SysUtils;

type
  ISdMenuItem = interface
    ['{11B0B171-67E7-418A-966B-38C63D51096E}']
    function MenuItem: TMenuItem;
  end;

  TSdMenuItem = class(TInterfacedObject, IMenuItems, IMenuItem, ISdMenuItem)
  private
    FItem: TMenuItem;
    FActions: TActionList;
    function Action: TCustomAction;
    function Wrap(Item: TMenuItem): IMenuItem;
    function NewItem(Index: Integer; const ACaption: WideString; AShortCut: TShortCut;
      AChecked, AEnabled: Boolean; AOnClick: TNotifyEvent; hCtx: THelpContext;
      const AName: string): IMenuItem;
    function NewActionItem(Index: Integer; AAction: TBasicAction; const AName: string): IMenuItem;
    function NewLine(Index: Integer; const AName: string): IMenuItem;
    function Place(M: TMenuItem; Index: Integer; const AName: string): IMenuItem;
  protected
    { IMenuItems }
    function GetItem(Index: Integer): IMenuItem;
    function SameAs(const AItem: IUnknown): Boolean;
    function Find(const ACaption: WideString): IMenuItem;
    function FindByName(const AName: string): IMenuItem;
    function Count: Integer;
    procedure Clear;
    function AddItem(const ACaption: WideString; AShortCut: TShortCut; AChecked, AEnabled: Boolean;
      AOnClick: TNotifyEvent = nil; hCtx: THelpContext = 0; const AName: string = ''): IMenuItem; overload;
    function AddItem(AAction: TBasicAction; const AName: string = ''): IMenuItem; overload;
    function InsertItem(const ACaption: WideString; AShortCut: TShortCut; AChecked, AEnabled: Boolean;
      AOnClick: TNotifyEvent = nil; hCtx: THelpContext = 0; const AName: string = ''): IMenuItem; overload;
    function InsertItem(Index: Integer; const ACaption: WideString; AShortCut: TShortCut;
      AChecked, AEnabled: Boolean; AOnClick: TNotifyEvent = nil; hCtx: THelpContext = 0;
      const AName: string = ''): IMenuItem; overload;
    function InsertItem(AAction: TBasicAction; const AName: string = ''): IMenuItem; overload;
    function InsertItem(Index: Integer; AAction: TBasicAction; const AName: string = ''): IMenuItem; overload;
    function AddLine(const AName: string = ''): IMenuItem;
    function InsertLine(const AName: string = ''): IMenuItem; overload;
    function InsertLine(Index: Integer; const AName: string = ''): IMenuItem; overload;
    { IMenuItem }
    function GetCaption: WideString;
    procedure SetCaption(const ACaption: WideString);
    function GetChecked: Boolean;
    procedure SetChecked(AChecked: Boolean);
    function GetEnabled: Boolean;
    procedure SetEnabled(AEnabled: Boolean);
    function GetGroupIndex: Byte;
    procedure SetGroupIndex(AGroupIndex: Byte);
    function GetHelpContext: THelpContext;
    procedure SetHelpContext(AHelpContext: THelpContext);
    function GetHint: string;
    procedure SetHint(const AHint: string);
    function GetRadioItem: Boolean;
    procedure SetRadioItem(ARadioItem: Boolean);
    function GetShortCut: TShortCut;
    procedure SetShortCut(AShortCut: TShortCut);
    function GetTag: LongInt;
    procedure SetTag(AValue: LongInt);
    function GetVisible: Boolean;
    procedure SetVisible(AVisible: Boolean);
    function Name: TComponentName;
    function MenuIndex: Integer;
    function Parent: IMenuItem;
    function HasParent: Boolean;
    function IsLine: Boolean;
    { ISdMenuItem }
    function MenuItem: TMenuItem;
  public
    constructor Create(AItem: TMenuItem; AActions: TActionList);
  end;

  { the action of an item an editor added: runs the editor's handler with the menu item }
  TSdClickRelay = class(TComponent)
  private
    FOnClick: TNotifyEvent;
    FItem: TMenuItem;
  public
    procedure Execute(Sender: TObject);
  end;

function MenuItemIntf(Item: TMenuItem; Actions: TActionList): IMenuItem;
begin
  if Item = nil then Result := nil else Result := TSdMenuItem.Create(Item, Actions);
end;

procedure TSdClickRelay.Execute(Sender: TObject);
begin
  if Assigned(FOnClick) then FOnClick(FItem);
end;

constructor TSdMenuItem.Create(AItem: TMenuItem; AActions: TActionList);
begin
  inherited Create;
  FItem := AItem;
  FActions := AActions;
end;

function TSdMenuItem.MenuItem: TMenuItem;
begin
  Result := FItem;
end;

function TSdMenuItem.Action: TCustomAction;
begin
  if FItem.Action is TCustomAction then Result := TCustomAction(FItem.Action) else Result := nil;
end;

function TSdMenuItem.Wrap(Item: TMenuItem): IMenuItem;
begin
  Result := MenuItemIntf(Item, FActions);
end;

{ M into this item at Index (-1: the end), named AName when its owner has no such component }
function TSdMenuItem.Place(M: TMenuItem; Index: Integer; const AName: string): IMenuItem;
begin
  if (AName <> '') and IsValidIdent(AName) and
    ((M.Owner = nil) or (M.Owner.FindComponent(AName) = nil)) then
    M.Name := AName;
  if (Index < 0) or (Index >= FItem.Count) then FItem.Add(M) else FItem.Insert(Index, M);
  Result := Wrap(M);
end;

function TSdMenuItem.NewItem(Index: Integer; const ACaption: WideString; AShortCut: TShortCut;
  AChecked, AEnabled: Boolean; AOnClick: TNotifyEvent; hCtx: THelpContext;
  const AName: string): IMenuItem;
var
  M: TMenuItem;
  A: TAction;
  R: TSdClickRelay;
begin
  M := TMenuItem.Create(FItem.Owner);
  if FActions <> nil then
  begin
    A := TAction.Create(FActions.Owner);
    A.Caption := ACaption;
    A.ShortCut := AShortCut;
    A.Checked := AChecked;
    A.Enabled := AEnabled;
    A.HelpContext := hCtx;
    R := TSdClickRelay.Create(A);
    R.FOnClick := AOnClick;
    R.FItem := M;
    A.OnExecute := R.Execute;
    A.ActionList := FActions;
    M.Action := A;
  end
  else
  begin
    M.Caption := ACaption;
    M.ShortCut := AShortCut;
    M.Checked := AChecked;
    M.Enabled := AEnabled;
    M.HelpContext := hCtx;
    M.OnClick := AOnClick;
  end;
  Result := Place(M, Index, AName);
end;

function TSdMenuItem.NewActionItem(Index: Integer; AAction: TBasicAction; const AName: string): IMenuItem;
var
  M: TMenuItem;
begin
  M := TMenuItem.Create(FItem.Owner);
  M.Action := AAction;
  Result := Place(M, Index, AName);
end;

function TSdMenuItem.NewLine(Index: Integer; const AName: string): IMenuItem;
var
  M: TMenuItem;
begin
  M := TMenuItem.Create(FItem.Owner);
  M.Caption := cLineCaption;
  Result := Place(M, Index, AName);
end;

{ ---------------------------------------------------------------- IMenuItems }

function TSdMenuItem.GetItem(Index: Integer): IMenuItem;
begin
  if (Index >= 0) and (Index < FItem.Count) then Result := Wrap(FItem.Items[Index]) else Result := nil;
end;

function TSdMenuItem.SameAs(const AItem: IUnknown): Boolean;
var
  X: ISdMenuItem;
begin
  Result := Supports(AItem, ISdMenuItem, X) and (X.MenuItem = FItem);
end;

function TSdMenuItem.Find(const ACaption: WideString): IMenuItem;
begin
  Result := Wrap(FItem.Find(ACaption));
end;

function TSdMenuItem.FindByName(const AName: string): IMenuItem;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FItem.Count - 1 do
    if SameText(FItem.Items[I].Name, AName) then
    begin
      Result := Wrap(FItem.Items[I]);
      Exit;
    end;
end;

function TSdMenuItem.Count: Integer;
begin
  Result := FItem.Count;
end;

procedure TSdMenuItem.Clear;
begin
  FItem.Clear;
end;

function TSdMenuItem.AddItem(const ACaption: WideString; AShortCut: TShortCut; AChecked, AEnabled: Boolean;
  AOnClick: TNotifyEvent; hCtx: THelpContext; const AName: string): IMenuItem;
begin
  Result := NewItem(-1, ACaption, AShortCut, AChecked, AEnabled, AOnClick, hCtx, AName);
end;

function TSdMenuItem.AddItem(AAction: TBasicAction; const AName: string): IMenuItem;
begin
  Result := NewActionItem(-1, AAction, AName);
end;

function TSdMenuItem.InsertItem(const ACaption: WideString; AShortCut: TShortCut; AChecked, AEnabled: Boolean;
  AOnClick: TNotifyEvent; hCtx: THelpContext; const AName: string): IMenuItem;
begin
  Result := NewItem(0, ACaption, AShortCut, AChecked, AEnabled, AOnClick, hCtx, AName);
end;

function TSdMenuItem.InsertItem(Index: Integer; const ACaption: WideString; AShortCut: TShortCut;
  AChecked, AEnabled: Boolean; AOnClick: TNotifyEvent; hCtx: THelpContext; const AName: string): IMenuItem;
begin
  Result := NewItem(Index, ACaption, AShortCut, AChecked, AEnabled, AOnClick, hCtx, AName);
end;

function TSdMenuItem.InsertItem(AAction: TBasicAction; const AName: string): IMenuItem;
begin
  Result := NewActionItem(0, AAction, AName);
end;

function TSdMenuItem.InsertItem(Index: Integer; AAction: TBasicAction; const AName: string): IMenuItem;
begin
  Result := NewActionItem(Index, AAction, AName);
end;

function TSdMenuItem.AddLine(const AName: string): IMenuItem;
begin
  Result := NewLine(-1, AName);
end;

function TSdMenuItem.InsertLine(const AName: string): IMenuItem;
begin
  Result := NewLine(0, AName);
end;

function TSdMenuItem.InsertLine(Index: Integer; const AName: string): IMenuItem;
begin
  Result := NewLine(Index, AName);
end;

{ ---------------------------------------------------------------- IMenuItem: the states go to
  the item's action when it has one }

function TSdMenuItem.GetCaption: WideString;
begin
  if Action <> nil then Result := Action.Caption else Result := FItem.Caption;
end;

procedure TSdMenuItem.SetCaption(const ACaption: WideString);
begin
  if Action <> nil then Action.Caption := ACaption else FItem.Caption := ACaption;
end;

function TSdMenuItem.GetChecked: Boolean;
begin
  if Action <> nil then Result := Action.Checked else Result := FItem.Checked;
end;

procedure TSdMenuItem.SetChecked(AChecked: Boolean);
begin
  if Action <> nil then Action.Checked := AChecked else FItem.Checked := AChecked;
end;

function TSdMenuItem.GetEnabled: Boolean;
begin
  if Action <> nil then Result := Action.Enabled else Result := FItem.Enabled;
end;

procedure TSdMenuItem.SetEnabled(AEnabled: Boolean);
begin
  if Action <> nil then Action.Enabled := AEnabled else FItem.Enabled := AEnabled;
end;

function TSdMenuItem.GetGroupIndex: Byte;
begin
  Result := FItem.GroupIndex;
end;

procedure TSdMenuItem.SetGroupIndex(AGroupIndex: Byte);
begin
  FItem.GroupIndex := AGroupIndex;
end;

function TSdMenuItem.GetHelpContext: THelpContext;
begin
  if Action <> nil then Result := Action.HelpContext else Result := FItem.HelpContext;
end;

procedure TSdMenuItem.SetHelpContext(AHelpContext: THelpContext);
begin
  if Action <> nil then Action.HelpContext := AHelpContext else FItem.HelpContext := AHelpContext;
end;

function TSdMenuItem.GetHint: string;
begin
  if Action <> nil then Result := Action.Hint else Result := FItem.Hint;
end;

procedure TSdMenuItem.SetHint(const AHint: string);
begin
  if Action <> nil then Action.Hint := AHint else FItem.Hint := AHint;
end;

function TSdMenuItem.GetRadioItem: Boolean;
begin
  Result := FItem.RadioItem;
end;

procedure TSdMenuItem.SetRadioItem(ARadioItem: Boolean);
begin
  FItem.RadioItem := ARadioItem;
end;

function TSdMenuItem.GetShortCut: TShortCut;
begin
  if Action <> nil then Result := Action.ShortCut else Result := FItem.ShortCut;
end;

procedure TSdMenuItem.SetShortCut(AShortCut: TShortCut);
begin
  if Action <> nil then Action.ShortCut := AShortCut else FItem.ShortCut := AShortCut;
end;

function TSdMenuItem.GetTag: LongInt;
begin
  Result := FItem.Tag;
end;

procedure TSdMenuItem.SetTag(AValue: LongInt);
begin
  FItem.Tag := AValue;
end;

function TSdMenuItem.GetVisible: Boolean;
begin
  if Action <> nil then Result := Action.Visible else Result := FItem.Visible;
end;

procedure TSdMenuItem.SetVisible(AVisible: Boolean);
begin
  if Action <> nil then Action.Visible := AVisible else FItem.Visible := AVisible;
end;

function TSdMenuItem.Name: TComponentName;
begin
  Result := FItem.Name;
end;

function TSdMenuItem.MenuIndex: Integer;
begin
  Result := FItem.MenuIndex;
end;

{ a menu's own items have no parent item: the root of the menu is not one }
function TSdMenuItem.Parent: IMenuItem;
begin
  if (FItem.Parent <> nil) and (FItem.Parent.Parent <> nil) then Result := Wrap(FItem.Parent)
  else Result := nil;
end;

function TSdMenuItem.HasParent: Boolean;
begin
  Result := (FItem.Parent <> nil) and (FItem.Parent.Parent <> nil);
end;

function TSdMenuItem.IsLine: Boolean;
begin
  Result := FItem.IsLine;
end;

end.
