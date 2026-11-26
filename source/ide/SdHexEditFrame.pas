{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdHexEditFrame;

{ D7 Studio - the editor of a resource's bytes in its page of the file area (SdResPage), as Visual
  Studio's binary editor: the bytes as hex and as text, 16 to a
  row after their offset. The caret is in one of the two columns (Tab changes it, a click puts it
  there): hex digits there and characters in the text column type over the bytes, at the end they
  are added; Insert puts a zero byte in, Delete takes the byte at the caret, Backspace the one
  before it. Ctrl+Z / Ctrl+Y undo and redo. Load takes a file's bytes, Save As writes them into a
  file. The view (TSdHexView) is a control of this unit, made in the frame's constructor. It zooms
  its font (SdZoom: the zoom bar on the page bar, the wheel with the zoom key) and scrolls sideways
  when its rows are wider than it. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, ActnList, ComCtrls,
  SdUI, SdUndo, SdResPage, SdZoom;

type
  { one change of the bytes: at Pos, Old became New; the caret before it }
  THexEdit = class
  public
    Pos: Integer;
    Old, New: string;
    Caret: Integer;
    Text: Boolean;
  end;

  TSdHexView = class(TSdControl, ISdZoomView)
  private
    FData: string;
    FCaret: Integer;                 // the byte (Length(FData): after the last one)
    FLow: Boolean;                   // the hex column: on the byte's low digit
    FInText: Boolean;                // the text column
    FTop: Integer;                   // the first row in view
    FLeft: Integer;                  // the pixels of the rows left of the view (scrolled sideways)
    FWheel: Integer;                 // parts of wheel notches (UIWheelSteps)
    FWheelZoom: Integer;             // ... with the zoom key
    FZoom: Integer;                  // per cent of the font's own size (SdZoom)
    FBaseHeight: Integer;            // the font's height at 100 %
    FCharW, FCharH: Integer;
    FSteps: TSdUndoStack;            // THexEdit: applies both ways
    FModified: Boolean;
    FOnChange: TNotifyEvent;
    function Rows: Integer;
    function VisibleRows: Integer;
    function HexX(Col: Integer): Integer;    // where a byte's hex digits begin
    function TextX(Col: Integer): Integer;   // ... its character
    procedure Measure;
    procedure Replace(Pos, Count: Integer; const Put: string);
    procedure Change(Pos: Integer; const Old, New: string; NewCaret: Integer);
    procedure Apply(E: THexEdit; Back: Boolean);
    procedure MoveTo(Pos: Integer);
    procedure ShowCaret;
    procedure UpdateScrollBar;
    function RowWidth: Integer;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMVScroll(var Message: TWMVScroll); message WM_VSCROLL;
    procedure WMHScroll(var Message: TWMHScroll); message WM_HSCROLL;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure PaintBuffer(C: TCanvas); override;
    procedure Resize; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyPress(var Key: Char); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetData(const S: string);    // a new text: no undo
    procedure Undo;
    procedure Redo;
    function CanUndo: Boolean;
    function CanRedo: Boolean;
    { ISdZoomView (the zoom bar, View | Zoom, the wheel with the zoom key): the font at a per cent of
      its size, 50 .. 400 in SdZoom's steps of 5 %; the caret's cell stays in view. No Fit }
    function ZoomPercent: Integer;
    function CanZoom(Delta: Integer): Boolean;
    procedure ZoomStep(Delta: Integer; AtPoint: Boolean; const At: TPoint);
    procedure ZoomTo(Percent: Integer);
    function CanZoomFit: Boolean;
    procedure ZoomFit;
    property Data: string read FData;
    property Caret: Integer read FCaret;
    property InText: Boolean read FInText;
    property Modified: Boolean read FModified;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

  THexEditFrame = class(TFrame, ISdResEditor, ISdZoomView)
    TopBar: TToolBar;
    tbLoad: TToolButton;
    tbSave: TToolButton;
    tbSep1: TToolButton;
    tbUndo: TToolButton;
    tbRedo: TToolButton;
    ViewHost: TPanel;
    StatusPanel: TPanel;
    lblStatus: TLabel;
    Actions: TActionList;
    aLoad: TAction;
    aSave: TAction;
    EditUndoCommand: TAction;
    EditRedoCommand: TAction;
    procedure aLoadExecute(Sender: TObject);
    procedure aSaveExecute(Sender: TObject);
    procedure aUndoExecute(Sender: TObject);
    procedure aUndoUpdate(Sender: TObject);
    procedure aRedoExecute(Sender: TObject);
    procedure aRedoUpdate(Sender: TObject);
  private
    FView: TSdHexView;
    FSaveName: string;
    procedure ViewChange(Sender: TObject);
    function GetZoomView: ISdZoomView;
  public
    { ISdZoomView: the view's }
    property ZoomView: ISdZoomView read GetZoomView implements ISdZoomView;
    constructor Create(AOwner: TComponent); override;
    { Data: the bytes; SaveName: the file Save As proposes }
    procedure Load(const Data, SaveName: string);
    function Data: string;
    { ISdResEditor }
    function EditorModified: Boolean;
    procedure EditorSaved;
    function EditorCheck(Show: Boolean): string;
    procedure EditorFocus;
    function EditorTestText: string;
    function EditorBar: TWinControl;
    function EditorStatus: TWinControl;
  end;

implementation

uses
  Math, SdDialogs, SdFileNames, SdIcons;

{$R *.dfm}

const
  BytesPerRow = 16;
  Margin = 4;
  MinZoom = 50;
  MaxZoom = 400;

{ ---------------------------------------------------------------- TSdHexView }

constructor TSdHexView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque] - [csAcceptsControls];
  TabStop := True;
  Color := clWindow;
  Font.Name := 'Consolas';
  Font.Size := 10;
  FBaseHeight := Font.Height;
  FZoom := 100;
  FSteps := TSdUndoStack.Create;
  Buffered := True;
end;

destructor TSdHexView.Destroy;
begin
  FreeAndNil(FSteps);
  inherited Destroy;
end;

{ scroll bars of its own (the horizontal one while the rows are wider than the view); no border -
  the page around it has the frame (SdResPage) }
procedure TSdHexView.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_VSCROLL or WS_HSCROLL;
end;

procedure TSdHexView.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_WANTARROWS or DLGC_WANTCHARS or DLGC_WANTTAB;
end;

procedure TSdHexView.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  Invalidate;
end;

procedure TSdHexView.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  Invalidate;
end;

procedure TSdHexView.Measure;
var
  DC: HDC;
  Old: HGDIOBJ;
  Size: TSize;
begin
  DC := GetDC(0);
  try
    Old := SelectObject(DC, Font.Handle);
    GetTextExtentPoint32(DC, '0', 1, Size);
    SelectObject(DC, Old);
  finally
    ReleaseDC(0, DC);
  end;
  FCharW := Max(1, Size.cx);
  FCharH := Max(1, Size.cy + 2);
end;

function TSdHexView.Rows: Integer;
begin
  Result := Length(FData) div BytesPerRow + 1;
end;

function TSdHexView.VisibleRows: Integer;
begin
  if FCharH = 0 then Measure;
  Result := Max(1, (ClientHeight - Margin) div FCharH);
end;

{ the offset (8 digits), two spaces, the bytes "XX " with one more space after the eighth, two
  spaces, the characters }
function TSdHexView.HexX(Col: Integer): Integer;
begin
  Result := Margin + (10 + Col * 3 + Ord(Col >= 8)) * FCharW;
end;

function TSdHexView.TextX(Col: Integer): Integer;
begin
  Result := Margin + (10 + BytesPerRow * 3 + 1 + 2 + Col) * FCharW;
end;

{ the rows' width: the characters' column and the margin after it }
function TSdHexView.RowWidth: Integer;
begin
  if FCharW = 0 then Measure;
  Result := TextX(BytesPerRow) + Margin;
end;

procedure TSdHexView.UpdateScrollBar;
begin
  if not HandleAllocated then Exit;
  FTop := Max(0, Min(FTop, Rows - VisibleRows));
  UISetScrollBar(Handle, SB_VERT, Rows, VisibleRows, FTop, True);
  FLeft := Max(0, Min(FLeft, RowWidth - ClientWidth));
  UISetScrollBar(Handle, SB_HORZ, RowWidth, ClientWidth, FLeft);
  { a bar that came or went changed the client }
  FLeft := Max(0, Min(FLeft, RowWidth - ClientWidth));
end;

function TSdHexView.ZoomPercent: Integer;
begin
  Result := FZoom;
end;

function TSdHexView.CanZoom(Delta: Integer): Boolean;
begin
  Result := CanStepZoom(FZoom, Delta, MinZoom, MaxZoom);
end;

procedure TSdHexView.ZoomStep(Delta: Integer; AtPoint: Boolean; const At: TPoint);
begin
  ZoomTo(ZoomPercentStep(FZoom, Delta, MinZoom, MaxZoom));
end;

procedure TSdHexView.ZoomTo(Percent: Integer);
begin
  Percent := Max(MinZoom, Min(Percent, MaxZoom));
  if Percent = FZoom then Exit;
  FZoom := Percent;
  Font.Height := MulDiv(FBaseHeight, FZoom, 100);
  Measure;
  ShowCaret;
  ZoomChanged(Self);
end;

function TSdHexView.CanZoomFit: Boolean;
begin
  Result := False;
end;

procedure TSdHexView.ZoomFit;
begin
end;

procedure TSdHexView.Resize;
begin
  inherited Resize;
  UpdateScrollBar;
  Invalidate;
end;

procedure TSdHexView.SetData(const S: string);
begin
  FData := S;
  FCaret := 0;
  FLow := False;
  FTop := 0;
  FSteps.Clear;
  FModified := False;
  UpdateScrollBar;
  Invalidate;
end;

{ the caret's row in view, and its cell when the rows are wider than the view }
procedure TSdHexView.ShowCaret;
var
  R, X, W: Integer;
begin
  R := FCaret div BytesPerRow;
  if R < FTop then FTop := R
  else if R >= FTop + VisibleRows then FTop := R - VisibleRows + 1;
  if FCharW = 0 then Measure;
  if FInText then
  begin
    X := TextX(FCaret mod BytesPerRow);
    W := FCharW;
  end
  else
  begin
    X := HexX(FCaret mod BytesPerRow);
    W := 2 * FCharW;
  end;
  if X < FLeft + Margin then FLeft := Max(0, X - Margin)
  else if X + W > FLeft + ClientWidth - Margin then FLeft := X + W - ClientWidth + Margin;
  UpdateScrollBar;
  Invalidate;
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TSdHexView.MoveTo(Pos: Integer);
begin
  FCaret := Max(0, Min(Pos, Length(FData)));
  FLow := False;
  ShowCaret;
end;

{ Count bytes at Pos (0-based) become Put: in place when Put is as long (a byte typed over - the
  data is not copied at each key) }
procedure TSdHexView.Replace(Pos, Count: Integer; const Put: string);
begin
  if (Count = Length(Put)) and (Pos >= 0) and (Pos + Count <= Length(FData)) then
  begin
    if Put <> '' then
    begin
      UniqueString(FData);
      Move(Put[1], FData[Pos + 1], Count);
    end;
  end
  else
    FData := Copy(FData, 1, Pos) + Put + Copy(FData, Pos + Count + 1, MaxInt);
end;

{ an edit of the bytes, an undo step (ShowCaret brings the scroll bar up to date) }
procedure TSdHexView.Change(Pos: Integer; const Old, New: string; NewCaret: Integer);
var
  E: THexEdit;
begin
  E := THexEdit.Create;
  E.Pos := Pos;
  E.Old := Old;
  E.New := New;
  E.Caret := FCaret;
  E.Text := FInText;
  FSteps.Done(E);
  Replace(Pos, Length(Old), New);
  FModified := True;
  FCaret := Max(0, Min(NewCaret, Length(FData)));
  ShowCaret;
end;

{ an edit undone (Back) or done again: the bytes as they were before it or after it, the caret
  where it was before it or after what it put in }
procedure TSdHexView.Apply(E: THexEdit; Back: Boolean);
begin
  if Back then
  begin
    Replace(E.Pos, Length(E.New), E.Old);
    FCaret := Min(E.Caret, Length(FData));
  end
  else
  begin
    Replace(E.Pos, Length(E.Old), E.New);
    FCaret := Min(E.Pos + Length(E.New), Length(FData));
  end;
  FModified := True;
  FInText := E.Text;
  FLow := False;
  ShowCaret;
end;

function TSdHexView.CanUndo: Boolean;
begin
  Result := FSteps.UndoCount > 0;
end;

function TSdHexView.CanRedo: Boolean;
begin
  Result := FSteps.RedoCount > 0;
end;

procedure TSdHexView.Undo;
var
  E: THexEdit;
begin
  E := THexEdit(FSteps.TakeUndo);
  if E = nil then Exit;
  FSteps.AddRedo(E);
  Apply(E, True);
end;

procedure TSdHexView.Redo;
var
  E: THexEdit;
begin
  E := THexEdit(FSteps.TakeRedo);
  if E = nil then Exit;
  FSteps.AddUndo(E);
  Apply(E, False);
end;

procedure TSdHexView.WMVScroll(var Message: TWMVScroll);
begin
  FTop := UIScrollPos(Handle, SB_VERT, Message.ScrollCode, FTop, 1, VisibleRows, Rows);
  UpdateScrollBar;
  Invalidate;
end;

procedure TSdHexView.WMHScroll(var Message: TWMHScroll);
begin
  if FCharW = 0 then Measure;
  FLeft := UIScrollPos(Handle, SB_HORZ, Message.ScrollCode, FLeft, FCharW, ClientWidth, RowWidth);
  UpdateScrollBar;
  Invalidate;
end;

{ the wheel scrolls three rows a notch (with Shift: sideways); with the zoom key it zooms (SdZoom) }
function TSdHexView.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := True;
  if ZoomByWheel(Self, FWheelZoom, WheelZooms(Shift), WheelDelta, MousePos) then Exit;
  if FCharW = 0 then Measure;
  if ssShift in Shift then Dec(FLeft, UIWheelSteps(FWheel, WheelDelta, 3 * FCharW))
  else Dec(FTop, UIWheelSteps(FWheel, WheelDelta, 3));
  UpdateScrollBar;
  Invalidate;
end;

procedure TSdHexView.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Row, Col: Integer;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if CanFocus and not Focused then SetFocus;
  if FCharW = 0 then Measure;
  Inc(X, FLeft);                       // the rows' coordinates
  Row := FTop + Max(0, (Y - Margin) div FCharH);
  if X >= TextX(0) - FCharW then
  begin
    FInText := True;
    Col := Min(BytesPerRow - 1, Max(0, (X - TextX(0)) div FCharW));
  end
  else
  begin
    FInText := False;
    Col := 0;
    while (Col < BytesPerRow - 1) and (X >= HexX(Col + 1) - FCharW div 2) do Inc(Col);
  end;
  MoveTo(Row * BytesPerRow + Col);
end;

procedure TSdHexView.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  case Key of
    VK_LEFT: MoveTo(FCaret - 1);
    VK_RIGHT: MoveTo(FCaret + 1);
    VK_UP: MoveTo(FCaret - BytesPerRow);
    VK_DOWN: if FCaret + BytesPerRow <= Length(FData) then MoveTo(FCaret + BytesPerRow);
    VK_PRIOR: MoveTo(FCaret - BytesPerRow * VisibleRows);
    VK_NEXT: MoveTo(Min(FCaret + BytesPerRow * VisibleRows, Length(FData)));
    VK_HOME:
      if ssCtrl in Shift then MoveTo(0) else MoveTo(FCaret - FCaret mod BytesPerRow);
    VK_END:
      if ssCtrl in Shift then MoveTo(Length(FData))
      else MoveTo(Min(FCaret - FCaret mod BytesPerRow + BytesPerRow - 1, Length(FData)));
    VK_TAB:
      begin
        FInText := not FInText;
        FLow := False;
        ShowCaret;
      end;
    VK_INSERT:
      if Shift = [] then Change(FCaret, '', #0, FCaret);
    VK_DELETE:
      if (Shift = []) and (FCaret < Length(FData)) then Change(FCaret, FData[FCaret + 1], '', FCaret);
    VK_BACK:
      if FCaret > 0 then Change(FCaret - 1, FData[FCaret], '', FCaret - 1);
  else
    Exit;
  end;
  Key := 0;
end;

{ typing: a hex digit sets the caret's digit (the high one, then the low one), a character in the
  text column the byte; at the end the byte is added }
procedure TSdHexView.KeyPress(var Key: Char);
var
  V: Integer;
  Old, New: Char;
begin
  inherited KeyPress(Key);
  if FInText then
  begin
    if not (Key in [#32..#126]) then Exit;
    if FCaret < Length(FData) then Change(FCaret, FData[FCaret + 1], Key, FCaret + 1)
    else Change(FCaret, '', Key, FCaret + 1);
    Key := #0;
    Exit;
  end;
  case Key of
    '0'..'9': V := Ord(Key) - Ord('0');
    'a'..'f': V := Ord(Key) - Ord('a') + 10;
    'A'..'F': V := Ord(Key) - Ord('A') + 10;
  else
    Exit;
  end;
  Key := #0;
  if FCaret < Length(FData) then Old := FData[FCaret + 1] else Old := #0;
  if FLow then New := Chr((Ord(Old) and $F0) or V) else New := Chr((Ord(Old) and $0F) or (V shl 4));
  if FCaret < Length(FData) then
  begin
    if FLow then
    begin
      Change(FCaret, Old, New, FCaret + 1);
      FLow := False;
    end
    else
    begin
      Change(FCaret, Old, New, FCaret);
      FLow := True;
      Invalidate;
    end;
  end
  else
  begin
    Change(FCaret, '', Chr(V shl 4), FCaret);
    FLow := True;
    Invalidate;
  end;
end;

procedure TSdHexView.PaintBuffer(C: TCanvas);
var
  DC: HDC;
  R: TRect;
  Row, Col, I, Y: Integer;
  S: string;
  B: Byte;
  Back, Fore, Tint: TColor;

  procedure Cell(X, Y, Chars: Integer; const T: string; Ground, Ink: TColor);
  var
    Box: TRect;
  begin
    Box := Rect(X, Y, X + Chars * FCharW, Y + FCharH);
    if Ground <> Back then UIFill(DC, Box, Ground);
    UIText(DC, T, Box, DT_LEFT or DT_SINGLELINE or DT_NOPREFIX or DT_VCENTER, Ink);
  end;

begin
  if FCharW = 0 then Measure;
  DC := C.Handle;
  Back := clWindow;
  UIFill(DC, ClientRect, Back);
  { the rows from FLeft on (the buffer is kept: its origin goes back at the end) }
  SetWindowOrgEx(DC, FLeft, 0, nil);
  SelectObject(DC, Font.Handle);
  SetBkMode(DC, TRANSPARENT);
  Tint := UISelectionTint(clWindow);
  Fore := clWindowText;
  for Row := FTop to FTop + VisibleRows do
  begin
    if Row > Length(FData) div BytesPerRow then Break;
    Y := Margin + (Row - FTop) * FCharH;
    Cell(Margin, Y, 8, IntToHex(Row * BytesPerRow, 8), Back, clGrayText);
    for Col := 0 to BytesPerRow - 1 do
    begin
      I := Row * BytesPerRow + Col;
      if I > Length(FData) then Break;
      if I = Length(FData) then
      begin
        { after the last byte: where typing adds one }
        if I = FCaret then
        begin
          if FInText then Cell(TextX(Col), Y, 1, ' ', clHighlight, clHighlightText)
          else Cell(HexX(Col), Y, 2, '  ', clHighlight, clHighlightText);
        end;
        Break;
      end;
      B := Ord(FData[I + 1]);
      S := IntToHex(B, 2);
      if I = FCaret then
      begin
        if not FInText and Focused then
        begin
          { the digit typing goes to }
          if FLow then
          begin
            Cell(HexX(Col), Y, 1, S[1], Tint, Fore);
            Cell(HexX(Col) + FCharW, Y, 1, S[2], clHighlight, clHighlightText);
          end
          else
          begin
            Cell(HexX(Col), Y, 1, S[1], clHighlight, clHighlightText);
            Cell(HexX(Col) + FCharW, Y, 1, S[2], Tint, Fore);
          end;
        end
        else
          Cell(HexX(Col), Y, 2, S, Tint, Fore);
      end
      else
        Cell(HexX(Col), Y, 2, S, Back, Fore);
      if B in [32..126] then S := Chr(B) else S := '.';
      if I = FCaret then
      begin
        if FInText and Focused then Cell(TextX(Col), Y, 1, S, clHighlight, clHighlightText)
        else Cell(TextX(Col), Y, 1, S, Tint, Fore);
      end
      else
        Cell(TextX(Col), Y, 1, S, Back, Fore);
    end;
  end;
  { the line between the bytes and the characters }
  R := Rect(TextX(0) - FCharW - FCharW div 2, 0, TextX(0) - FCharW - FCharW div 2 + 1, ClientHeight);
  UIFill(DC, R, clBtnFace);
  SetWindowOrgEx(DC, 0, 0, nil);
end;

{ ---------------------------------------------------------------- THexEditFrame }

constructor THexEditFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the command icons first: UIPrepareFrame gives the bar its look and the disabled images }
  TopBar.Images := IconList;
  UIPrepareFrame(Self);
  FView := TSdHexView.Create(Self);
  FView.Align := alClient;
  FView.Parent := ViewHost;
  FView.OnChange := ViewChange;
end;

procedure THexEditFrame.Load(const Data, SaveName: string);
begin
  FSaveName := SaveName;
  FView.SetData(Data);
  ViewChange(nil);
end;

function THexEditFrame.Data: string;
begin
  Result := FView.Data;
end;

function THexEditFrame.EditorModified: Boolean;
begin
  Result := FView.Modified;
end;

procedure THexEditFrame.EditorSaved;
begin
  FView.FModified := False;
  ViewChange(nil);
end;

function THexEditFrame.EditorCheck(Show: Boolean): string;
begin
  Result := '';
end;

procedure THexEditFrame.EditorFocus;
begin
  if FView.CanFocus then FView.SetFocus;
end;

function THexEditFrame.EditorBar: TWinControl;
begin
  Result := TopBar;
end;

function THexEditFrame.EditorStatus: TWinControl;
begin
  Result := StatusPanel;
end;

function THexEditFrame.GetZoomView: ISdZoomView;
begin
  Result := FView;
end;

procedure THexEditFrame.ViewChange(Sender: TObject);
var
  S: string;
begin
  S := Format('Offset %.8x (%d) of %s bytes', [FView.Caret, FView.Caret, FormatFloat('#,##0', Length(FView.Data))]);
  if FView.InText then S := S + '    text' else S := S + '    hex';
  if FView.Modified then S := S + '    modified';
  lblStatus.Caption := S;
end;

procedure THexEditFrame.aLoadExecute(Sender: TObject);
var
  FileName: string;
begin
  FileName := '';
  if not BrowseFile('Load Data', 'All files (*.*)|*.*', FileName) then Exit;
  FView.Change(0, FView.Data, ReadFileU(FileName), 0);
end;

procedure THexEditFrame.aSaveExecute(Sender: TObject);
var
  FileName: string;
begin
  FileName := FSaveName;
  if not BrowseFile('Save Data As', 'All files (*.*)|*.*', FileName, bfSave) then Exit;
  WriteFileU(FileName, FView.Data);
end;

procedure THexEditFrame.aUndoExecute(Sender: TObject);
begin
  FView.Undo;
end;

procedure THexEditFrame.aUndoUpdate(Sender: TObject);
begin
  EditUndoCommand.Enabled := FView.CanUndo;
end;

procedure THexEditFrame.aRedoExecute(Sender: TObject);
begin
  FView.Redo;
end;

procedure THexEditFrame.aRedoUpdate(Sender: TObject);
begin
  EditRedoCommand.Enabled := FView.CanRedo;
end;

function THexEditFrame.EditorTestText: string;
var
  I: Integer;
begin
  Result := Format('size=%d|caret=%d|text=%d|modified=%d|undo=%d|status=%d,%d,%d,%d/%d|bytes=', [Length(FView.Data),
    FView.Caret, Ord(FView.InText), Ord(FView.Modified), FView.FSteps.UndoCount, lblStatus.Left, lblStatus.Top,
    lblStatus.Width, lblStatus.Height, StatusPanel.ClientWidth]);
  for I := 1 to Min(Length(FView.Data), 64) do Result := Result + IntToHex(Ord(FView.Data[I]), 2);
end;

end.
