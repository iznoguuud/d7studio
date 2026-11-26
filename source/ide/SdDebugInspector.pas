{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDebugInspector;

{ D7 Studio - Delphi 7's Debug Inspector as a view (Run | Inspect):
  the expression, what it holds, its Data / Methods / Properties. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, Menus, ActnList, SdUI,
  SdDbgEngine, SdTabStrip;

type
  { Delphi's Debug Inspector: the expression (the ones inspected before in its list), its value,
    the tabs Data (fields, elements - or the value itself), Methods (with their signatures) and
    Properties, two columns each, and the type of the chosen row at the bottom. Filled again at
    every stop, empty while the program runs. A double click on a row inspects it (Descend). A
    form made once (its expression box, its rows and their events in the .dfm; the tabs in code),
    docked by the IDE. }
  TSdInspectorView = class(TForm)
    ExprBox: TComboBox;
    RowList: TListBox;
    MenuActions: TActionList;
    aDiChange: TAction;
    aDiSortDecl: TAction;
    aDiSortName: TAction;
    aDiDynamic: TAction;
    aDiInspect: TAction;
    aDiDescend: TAction;
    aDiNewExpr: TAction;
    aDiTypeCast: TAction;
    DebugInspPopup: TPopupMenu;
    pmDi1: TMenuItem;
    pmDi2: TMenuItem;
    pmDi2Decl: TMenuItem;
    pmDi2Name: TMenuItem;
    pmDi3: TMenuItem;
    pmDi4: TMenuItem;
    pmDi5: TMenuItem;
    pmDi6: TMenuItem;
    pmDi7: TMenuItem;
    pmDi8: TMenuItem;
    pmDi9: TMenuItem;
    procedure ExprKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ExprSelect(Sender: TObject);
    procedure ListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure ListClick(Sender: TObject);
    procedure ListDblClick(Sender: TObject);
  private
    FTabs: TSdTabStrip;            // the IDE's own control: made in code
    FDbg: TDebugger;
    FInfo, FInfoType: string;       // the value and type of the expression
    FRows: array[0..2] of TDbgVarArray;
    FShown: TDbgVarArray;           // the rows of the tab, sorted as chosen
    FSortByName: Boolean;
    FDynamic: Boolean;
    FInfoTop, FListTop, FStatusTop, FLineH: Integer;
    FNameW: Integer;                // the widest name of the tab
    FOnDescend: TNotifyEvent;
    procedure TabsChange(Sender: TObject);
    procedure Load;
    procedure Fill;
    procedure SetSortByName(Value: Boolean);
    procedure SetDynamic(Value: Boolean);
    procedure InvalidateText;
  protected
    procedure Resize; override;
    procedure Paint; override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Inspect(Dbg: TDebugger; const Expr: string);   // show Expr (it heads the list)
    procedure Refresh(Dbg: TDebugger);                       // a stop: the expression again
    procedure Clear;                                         // the program runs
    function Expression: string;
    function Selected(out V: TDbgVar): Boolean;              // the chosen row
    function SelectedExpr: string;                           // its expression ('': none, a method)
    function Page: Integer;                                  // 0 Data, 1 Methods, 2 Properties
    procedure FontChanged(F: TFont);
    function DebugText: string;   // the state dump's dinsp=: expr|value|tab|name=value;...|selected
    property SortByName: Boolean read FSortByName write SetSortByName;
    property Dynamic: Boolean read FDynamic write SetDynamic;   // Show Dynamic Properties
    property OnDescend: TNotifyEvent read FOnDescend write FOnDescend;   // a double click on a row
  end;

implementation

{$R *.dfm}

uses
  Math;

{ ---------------------------------------------------------------- TSdInspectorView }

const
  InspectHistory = 20;

constructor TSdInspectorView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form docked as a child keeps its own font }
  UIApplyFont(Self);
  FDynamic := True;
  ExprBox.DoubleBuffered := True;
  RowList.DoubleBuffered := True;
  FTabs := TSdTabStrip.Create(Self);
  FTabs.Parent := Self;
  FTabs.Side := tsTop;
  FTabs.Tabs.Add('Data');
  FTabs.Tabs.Add('Methods');
  FTabs.Tabs.Add('Properties');
  FTabs.TabIndex := 0;
  FTabs.OnChange := TabsChange;
end;

{ Paint fills the whole view: nothing to erase first }
procedure TSdInspectorView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;


{ the value line and the type line: what a new expression or another row changes }
procedure TSdInspectorView.InvalidateText;
var
  R: TRect;
begin
  if not HandleAllocated then Exit;
  R := Rect(0, FInfoTop, ClientWidth, FInfoTop + FLineH);
  InvalidateRect(Handle, @R, False);
  R := Rect(0, FStatusTop, ClientWidth, ClientHeight);
  InvalidateRect(Handle, @R, False);
end;

procedure TSdInspectorView.FontChanged(F: TFont);
begin
  RowList.Font := F;
  RowList.ItemHeight := UIFontHeight(F) + 2;
  if HandleAllocated then Resize;
end;

{ the expression, a line for its value, the tabs, the rows in a flat frame, a line for the type }
procedure TSdInspectorView.Resize;
var
  W, H, Y, TabH: Integer;
begin
  inherited;
  W := ClientWidth;
  H := ClientHeight;
  if (W <= 0) or (H <= 0) then Exit;
  Canvas.Font := Font;
  FLineH := Canvas.TextHeight('Wg') + 4;
  TabH := UIDockTabHeight;
  ExprBox.SetBounds(0, 0, W, ExprBox.Height);
  { the value line 3 px under the box (the box's window height: Height holds it once the box
    comes from the .dfm) }
  FInfoTop := ExprBox.Height + 3;
  Y := FInfoTop + FLineH;
  FTabs.SetBounds(0, Y, W, TabH);
  FListTop := Y + TabH;
  FStatusTop := H - FLineH;
  if FStatusTop < FListTop + 2 then FStatusTop := FListTop + 2;
  RowList.SetBounds(1, FListTop + 1, Max(0, W - 2), Max(0, FStatusTop - FListTop - 2));
  Invalidate;
end;

procedure TSdInspectorView.Paint;
var
  R: TRect;
  V: TDbgVar;
  S: string;
begin
  Canvas.Brush.Color := clBtnFace;
  Canvas.FillRect(ClientRect);
  Canvas.Font := Font;
  Canvas.Brush.Style := bsClear;
  R := Rect(4, FInfoTop, ClientWidth - 4, FInfoTop + FLineH);
  DrawText(Canvas.Handle, PChar(FInfo), Length(FInfo), R, DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS or DT_NOPREFIX);
  if Selected(V) then S := V.TypeName else S := FInfoType;
  R := Rect(4, FStatusTop, ClientWidth - 4, ClientHeight);
  DrawText(Canvas.Handle, PChar(S), Length(S), R, DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS or DT_NOPREFIX);
  Canvas.Brush.Style := bsSolid;
  UIDrawBorder(Canvas.Handle, Rect(0, FListTop, ClientWidth, FStatusTop));
end;

function TSdInspectorView.DebugText: string;
var
  I: Integer;
begin
  Result := Expression + '|' + FInfo + '|' + FTabs.Tabs[FTabs.TabIndex] + '|';
  for I := 0 to High(FShown) do Result := Result + FShown[I].Name + '=' + FShown[I].Value + ';';
  Result := Result + '|' + IntToStr(RowList.ItemIndex);
end;

procedure TSdInspectorView.Inspect(Dbg: TDebugger; const Expr: string);
var
  I: Integer;
begin
  FDbg := Dbg;
  if not SameText(Expr, Expression) then FTabs.TabIndex := 0;   // something else: its data first
  I := ExprBox.Items.IndexOf(Expr);
  if I >= 0 then ExprBox.Items.Delete(I);
  ExprBox.Items.Insert(0, Expr);
  while ExprBox.Items.Count > InspectHistory do ExprBox.Items.Delete(ExprBox.Items.Count - 1);
  ExprBox.Text := Expr;
  Load;
end;

procedure TSdInspectorView.Refresh(Dbg: TDebugger);
begin
  FDbg := Dbg;
  Load;
end;

procedure TSdInspectorView.Clear;
begin
  FDbg := nil;
  Load;
end;

function TSdInspectorView.Expression: string;
begin
  Result := Trim(ExprBox.Text);
end;

function TSdInspectorView.SelectedExpr: string;
var
  V: TDbgVar;
begin
  if Selected(V) then Result := V.Expr else Result := '';
end;

function TSdInspectorView.Page: Integer;
begin
  Result := FTabs.TabIndex;
end;

function TSdInspectorView.Selected(out V: TDbgVar): Boolean;
begin
  Result := (RowList.ItemIndex >= 0) and (RowList.ItemIndex <= High(FShown));
  if Result then V := FShown[RowList.ItemIndex];
end;

{ the expression's value and the rows of the three tabs: one evaluation, with calls (a method on
  the expression's path runs once) }
procedure TSdInspectorView.Load;
var
  V: TDbgVar;
  Err: string;
  I: Integer;
begin
  for I := 0 to High(FRows) do FRows[I] := nil;
  FInfo := '';
  FInfoType := '';
  if (FDbg <> nil) and (FDbg.State = dsPaused) and (Expression <> '') then
    if not FDbg.Inspect(Expression, FDynamic, V, FRows[0], FRows[1], FRows[2], Err) then
      FInfo := Err
    else
    begin
      FInfo := V.Value;
      FInfoType := V.TypeName;
      if not V.Expandable then
      begin
        { a value without parts: the value itself, as Delphi's inspector shows it }
        SetLength(FRows[0], 1);
        FRows[0][0] := V;
        FRows[0][0].Name := Expression;
        FRows[0][0].Expandable := False;
      end;
    end;
  Fill;
end;

procedure TSdInspectorView.Fill;
var
  I, J, Sel: Integer;
  T: TDbgVar;
  Name: string;
begin
  Name := '';
  if (RowList.ItemIndex >= 0) and (RowList.ItemIndex <= High(FShown)) then Name := FShown[RowList.ItemIndex].Name;
  FShown := Copy(FRows[FTabs.TabIndex], 0, MaxInt);
  if FSortByName then
    for I := 1 to High(FShown) do
    begin
      T := FShown[I];
      J := I - 1;
      while (J >= 0) and (CompareText(FShown[J].Name, T.Name) > 0) do
      begin
        FShown[J + 1] := FShown[J];
        Dec(J);
      end;
      FShown[J + 1] := T;
    end;
  Sel := -1;
  FNameW := 0;
  RowList.Canvas.Font := RowList.Font;
  RowList.Items.BeginUpdate;
  try
    RowList.Items.Clear;
    for I := 0 to High(FShown) do
    begin
      FNameW := Max(FNameW, RowList.Canvas.TextWidth(FShown[I].Name));
      RowList.Items.Add(FShown[I].Name);
      if SameText(FShown[I].Name, Name) then Sel := I;
    end;
  finally
    RowList.Items.EndUpdate;
  end;
  if (Sel < 0) and (RowList.Items.Count > 0) then Sel := 0;
  RowList.ItemIndex := Sel;
  InvalidateText;
end;

procedure TSdInspectorView.SetSortByName(Value: Boolean);
begin
  if Value = FSortByName then Exit;
  FSortByName := Value;
  Fill;
end;

procedure TSdInspectorView.SetDynamic(Value: Boolean);
begin
  if Value = FDynamic then Exit;
  FDynamic := Value;
  Load;
end;

procedure TSdInspectorView.ExprKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_RETURN) and not ExprBox.DroppedDown then
  begin
    Key := 0;
    if Expression <> '' then Inspect(FDbg, Expression);
  end;
end;

procedure TSdInspectorView.ExprSelect(Sender: TObject);
begin
  if ExprBox.ItemIndex >= 0 then Inspect(FDbg, ExprBox.Items[ExprBox.ItemIndex]);
end;

procedure TSdInspectorView.TabsChange(Sender: TObject);
begin
  Fill;
end;

procedure TSdInspectorView.ListClick(Sender: TObject);
begin
  InvalidateText;   // the type line
end;

procedure TSdInspectorView.ListDblClick(Sender: TObject);
begin
  if Assigned(FOnDescend) then FOnDescend(Self);
end;

{ name | value: the names in a column as wide as the widest (a third to a half of the row), a line
  after it }
procedure TSdInspectorView.ListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  C: TCanvas;
  NameW: Integer;
  R: TRect;
  S: string;
begin
  C := RowList.Canvas;
  C.Font := RowList.Font;
  if odSelected in State then
  begin
    if RowList.Focused then
    begin
      C.Brush.Color := clHighlight;
      C.Font.Color := clHighlightText;
    end
    else
      C.Brush.Color := UISelectionTint(clWindow);
  end
  else
    C.Brush.Color := clWindow;
  C.FillRect(Rect);
  if Index > High(FShown) then Exit;
  { the split follows the view's width, not the row's (a row is as wide as the scroll range) }
  NameW := Max(RowList.ClientWidth div 3, Min(FNameW + 10, RowList.ClientWidth div 2));
  C.Brush.Style := bsClear;
  R := Classes.Rect(Rect.Left + 4, Rect.Top, Rect.Left + NameW - 4, Rect.Bottom);
  S := FShown[Index].Name;
  DrawText(C.Handle, PChar(S), Length(S), R, DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS or DT_NOPREFIX);
  R := Classes.Rect(Rect.Left + NameW + 4, Rect.Top, Rect.Right - 2, Rect.Bottom);
  S := FShown[Index].Value;
  if not (odSelected in State) or not RowList.Focused then C.Font.Color := clNavy;
  DrawText(C.Handle, PChar(S), Length(S), R, DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS or DT_NOPREFIX);
  UIListRowWidth(RowList, R.Left + C.TextWidth(S));
  C.Brush.Style := bsSolid;
  C.Pen.Color := clBtnFace;
  C.MoveTo(Rect.Left + NameW, Rect.Top);
  C.LineTo(Rect.Left + NameW, Rect.Bottom);
end;

end.
