{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdColumnTreeFrame;

{ D7 Studio - a tree in two columns under a header: Delphi's Watch List (Watch Name, Value), its
  package editor (Files, Path) and the Resources view. The tree draws its lines, buttons, images
  and check boxes, the view draws the two columns over the rest of each row (custom draw, into the
  tree's own double buffer): the node's text up to the first column's edge (an ellipsis where it
  is cut), the second column (OnCell) from there on. The header's divider moves the edge, the last
  column takes the rest of the width.

  A frame (SdColumnTreeFrame.dfm: the header, the tree and their events), reused: the views are
  frames inherited from it (SdWatchViewFrame, SdPackageViewFrame, SdResourceViewFrame), made by
  the main form (CreatePanes), which wires their trees and tool bars to its commands - a view's
  tool bar is laid out by the dock (TSdDockPanel.ToolBar), not here. A derived view lays out more
  around the rows (LayoutRows: the Watch List's group tabs). }

interface

uses
  Windows, Messages, Classes, Graphics, Controls, ComCtrls, CommCtrl, SdUI, SdBaseFrame;

type
  { the second column of a row and the colour of the row }
  TSdColumnCellEvent = procedure(Sender: TObject; Node: TTreeNode; var Value: string;
    var Color: TColor) of object;

  TSdColumnTree = class(TSdFrame)
    Header: THeaderControl;
    Tree: TTreeView;
    procedure HeaderTrack(HeaderControl: THeaderControl; Section: THeaderSection; Width: Integer;
      State: TSectionTrackState);
    procedure HeaderResize(HeaderControl: THeaderControl; Section: THeaderSection);
  private
    FColWidth: Integer;
    FShowHeaders: Boolean;
    FFrame: TRect;
    FOnCell: TSdColumnCellEvent;
    procedure TreeProc(var Message: TMessage; Pass: TWndMethod);
    procedure DrawRow(const CD: TNMTVCustomDraw);
    procedure SetColWidth(Value: Integer);
    procedure SetShowHeaders(Value: Boolean);
    procedure SizeSections;
    function HeaderHeight: Integer;
  protected
    procedure Paint; override;
    procedure Resize; override;
    { the header (when shown) and the rows in a flat frame at Frame, Others at OtherRects - all
      in one batch }
    procedure LayoutRows(const Frame: TRect; const Others: array of TWinControl;
      const OtherRects: array of TRect);
  public
    constructor Create(AOwner: TComponent); override;
    procedure FontChanged;                                // the tree's font changed
    { the rows for the test instance's state dump: each its text after a '>' per level, "=" and
      the second column (OnCell) when that has a text - DataValues: also an empty one of a row
      with data -, '*' when it is chosen, then ';' }
    function RowsText(DataValues: Boolean): string;
    property ShowHeaders: Boolean read FShowHeaders write SetShowHeaders;
    property ColumnWidth: Integer read FColWidth write SetColWidth;    // the first column
    property OnCell: TSdColumnCellEvent read FOnCell write FOnCell;
  end;

implementation

{$R *.dfm}

uses
  Math;

type
  { the tree's window procedure: the columns are drawn over its rows (TreeProc); owned by the tree }
  TTreeHook = class(TUIWindowHook)
  private
    FView: TSdColumnTree;
  protected
    procedure Hook(var Message: TMessage); override;
  end;

procedure TTreeHook.Hook(var Message: TMessage);
begin
  FView.TreeProc(Message, FOldProc);
end;

constructor TSdColumnTree.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the first column as wide as the .dfm's first section (a view's own width) }
  FColWidth := Header.Sections[0].Width;
  FShowHeaders := True;
  Header.DoubleBuffered := True;
  TTreeHook.Create(Tree, True).FView := Self;
end;

{ the header's height for the font: its text and 4 px above and below. Not the header control's
  own layout (HDM_LAYOUT): a pixel more, and only once the header has a window - which the
  frame's first layout comes before, so the height depended on when the view was laid out }
function TSdColumnTree.HeaderHeight: Integer;
begin
  Result := UIFontHeight(Header.Font) + 8;
end;

{ the rows are in the tree's font (the Watch List's: the debugger views'); the header keeps the
  view's, the UI font - as the Breakpoints view's header }
procedure TSdColumnTree.FontChanged;
begin
  if HandleAllocated then Resize;
end;

function TSdColumnTree.RowsText(DataValues: Boolean): string;
var
  N: TTreeNode;
  V: string;
  C: TColor;
begin
  Result := '';
  N := Tree.Items.GetFirstNode;
  while N <> nil do
  begin
    V := '';
    C := Tree.Font.Color;
    if Assigned(FOnCell) then FOnCell(Self, N, V, C);
    Result := Result + StringOfChar('>', N.Level) + N.Text;
    if (V <> '') or (DataValues and (N.Data <> nil)) then Result := Result + '=' + V;
    if N.Selected then Result := Result + '*';
    Result := Result + ';';
    N := N.GetNext;
  end;
end;

{ the last column takes the rest of the width (Delphi's is AutoSize); not before the view has a
  window (the header's ClientWidth would make one without a parent): LayoutRows sizes them }
procedure TSdColumnTree.SizeSections;
var
  W: Integer;
begin
  if not HandleAllocated then Exit;
  if Header.Sections[0].Width <> FColWidth then Header.Sections[0].Width := FColWidth;
  W := Max(Header.Sections[1].MinWidth, Header.ClientWidth - FColWidth);
  if Header.Sections[1].Width <> W then Header.Sections[1].Width := W;
end;

procedure TSdColumnTree.SetColWidth(Value: Integer);
begin
  if Value < 30 then Value := 30;
  if Value <> FColWidth then
  begin
    FColWidth := Value;
    if Tree.HandleAllocated then InvalidateRect(Tree.Handle, nil, False);
  end;
  SizeSections;
end;

procedure TSdColumnTree.SetShowHeaders(Value: Boolean);
begin
  if Value = FShowHeaders then Exit;
  FShowHeaders := Value;
  Resize;
end;

{ a drag of the header's divider: the rows follow at once (Delphi's list view does); the header
  moves its own divider - its sections are set when the drag ends (HeaderResize) }
procedure TSdColumnTree.HeaderTrack(HeaderControl: THeaderControl; Section: THeaderSection;
  Width: Integer; State: TSectionTrackState);
begin
  if (Section.Index <> 0) or (Width = FColWidth) then Exit;
  FColWidth := Max(30, Width);
  if Tree.HandleAllocated then InvalidateRect(Tree.Handle, nil, False);
end;

procedure TSdColumnTree.HeaderResize(HeaderControl: THeaderControl; Section: THeaderSection);
begin
  if Section.Index = 0 then SetColWidth(Section.Width);
end;

procedure TSdColumnTree.LayoutRows(const Frame: TRect; const Others: array of TWinControl;
  const OtherRects: array of TRect);
var
  HH, Top, I: Integer;
  C: array of TWinControl;
  R: array of TRect;
begin
  FFrame := Frame;
  if FShowHeaders then HH := HeaderHeight else HH := 0;
  Top := Frame.Top + 1 + HH;
  Header.Visible := FShowHeaders;
  SetLength(C, 2 + Length(Others));
  SetLength(R, Length(C));
  C[0] := Header;
  R[0] := Rect(Frame.Left + 1, Frame.Top + 1, Frame.Right - 1, Top);
  C[1] := Tree;
  R[1] := Rect(Frame.Left + 1, Top, Frame.Right - 1, Max(Top, Frame.Bottom - 1));
  for I := 0 to High(Others) do
  begin
    C[2 + I] := Others[I];
    R[2 + I] := OtherRects[I];
  end;
  UIMoveControls(C, R);
  SizeSections;
  Invalidate;
end;

{ the rows in their frame over the whole view; laid out once the view has a window (the header's
  height is measured) }
procedure TSdColumnTree.Resize;
begin
  inherited;
  if HandleAllocated and (ClientWidth > 0) and (ClientHeight > 0) then LayoutRows(ClientRect, [], []);
end;

procedure TSdColumnTree.Paint;
begin
  UIDrawBorder(Canvas.Handle, FFrame);
end;

{ The tree paints a row as it always does (lines, button, image, check box, the label); the two
  columns are drawn over the rest: in the colours of the row, the selection's while the tree has
  the focus. The tree repaints only the label for a new selection, and only what a new size
  uncovers: every change of the selection, the focus or the size repaints it whole (in its
  buffer: nothing flickers). }
procedure TSdColumnTree.TreeProc(var Message: TMessage; Pass: TWndMethod);
begin
  if (Message.Msg = CN_NOTIFY) and (TWMNotify(Message).NMHdr^.code = NM_CUSTOMDRAW) then
  begin
    with PNMTVCustomDraw(TWMNotify(Message).NMHdr)^ do
      case nmcd.dwDrawStage of
        CDDS_PREPAINT: Message.Result := CDRF_NOTIFYITEMDRAW;
        CDDS_ITEMPREPAINT: Message.Result := CDRF_NOTIFYPOSTPAINT;
        CDDS_ITEMPOSTPAINT:
          begin
            DrawRow(PNMTVCustomDraw(TWMNotify(Message).NMHdr)^);
            Message.Result := CDRF_DODEFAULT;
          end;
      else
        Message.Result := CDRF_DODEFAULT;
      end;
    Exit;
  end;
  Pass(Message);
  case Message.Msg of
    { the second column is cut to the row's width (an ellipsis): a new width changes every row,
      while the tree repaints only what the change uncovers - the cut texts of before and after
      were drawn over each other }
    WM_SIZE,
    WM_SETFOCUS, WM_KILLFOCUS, WM_LBUTTONDOWN, WM_LBUTTONUP, WM_RBUTTONDOWN, WM_KEYDOWN:
      if Tree.HandleAllocated then InvalidateRect(Tree.Handle, nil, False);
    CN_NOTIFY:
      if (TWMNotify(Message).NMHdr^.code = TVN_SELCHANGED) and Tree.HandleAllocated then
        InvalidateRect(Tree.Handle, nil, False);
  end;
end;

procedure TSdColumnTree.DrawRow(const CD: TNMTVCustomDraw);
var
  Node: TTreeNode;
  R, TR, NR, VR: TRect;
  DC: HDC;
  Value: string;
  Color, Back: TColor;
  Focused: Boolean;
  OldFont: HGDIOBJ;
begin
  Node := Tree.Items.GetNode(HTreeItem(CD.nmcd.dwItemSpec));
  if Node = nil then Exit;
  if not TreeView_GetItemRect(Tree.Handle, HTreeItem(CD.nmcd.dwItemSpec), TR, True) then Exit;
  DC := CD.nmcd.hdc;
  R := CD.nmcd.rc;
  Value := '';
  Color := Tree.Font.Color;
  if Assigned(FOnCell) then FOnCell(Self, Node, Value, Color);
  Focused := GetFocus = Tree.Handle;
  Back := Tree.Color;
  if Focused and (CD.nmcd.uItemState and CDIS_SELECTED <> 0) then
  begin
    Back := clHighlight;
    Color := clHighlightText;
  end;
  UIFill(DC, Rect(TR.Left, R.Top, R.Right, R.Bottom), Back);
  OldFont := SelectObject(DC, Tree.Font.Handle);
  NR := Rect(TR.Left + 2, R.Top, FColWidth - 4, R.Bottom);
  if NR.Right > NR.Left then
    UIText(DC, Node.Text, NR, DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS or DT_NOPREFIX, Color);
  VR := Rect(Max(FColWidth, TR.Left) + 6, R.Top, R.Right - 2, R.Bottom);
  if VR.Right > VR.Left then
    UIText(DC, Value, VR, DT_SINGLELINE or DT_VCENTER or DT_END_ELLIPSIS or DT_NOPREFIX, Color);
  SelectObject(DC, OldFont);
  if Focused and (CD.nmcd.uItemState and CDIS_FOCUS <> 0) and
    (SendMessage(Tree.Handle, WM_QUERYUISTATE, 0, 0) and UISF_HIDEFOCUS = 0) then
  begin
    SetTextColor(DC, ColorToRGB(clWindowText));
    SetBkColor(DC, ColorToRGB(clWindow));
    DrawFocusRect(DC, Rect(TR.Left, R.Top, R.Right, R.Bottom));
  end;
end;

end.
