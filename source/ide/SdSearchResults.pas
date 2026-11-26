{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdSearchResults;

{ D7 Studio - the Search Results view (Find in Files): a row per line found, "file(line): text".
  The item keeps the file name as it can be opened (the double click opens it there); the row shows
  the line in Unicode as it was found. A form made once (its list in the .dfm), docked by the IDE -
  a child window then, without a border. Its menu is the Messages view's (TMainForm's MsgPopup, whose
  commands act on either view), given to its list in code. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls,
  SdUI, SdEncoding, SdFileNames;

type
  { a row opened: the file and line it names }
  TSearchOpenEvent = procedure(Sender: TObject; const FileName: string; Line: Integer) of object;

  TSearchResultsView = class(TForm)
    SearchList: TListBox;
    procedure SearchListDblClick(Sender: TObject);
    procedure SearchListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
  private
    FText: array of WideString;        // the rows as shown: real file names, each file's text in Unicode
    FOnOpen: TSearchOpenEvent;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Clear;
    { a new list of results: BeginResults empties the list, AddResult adds a row (Item the text the
      list keeps, Shown the row as it is drawn), EndResults ends the update }
    procedure BeginResults;
    procedure AddResult(const Item: string; const Shown: WideString);
    procedure EndResults;
    property OnOpen: TSearchOpenEvent read FOnOpen write FOnOpen;
  end;

implementation

{$R *.dfm}

constructor TSearchResultsView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  { the UI font, as every form of the IDE: a form docked as a child keeps its own font }
  UIApplyFont(Self);
end;

{ No flicker: the list fills the view, which the dock resizes with it - the view
  paints nothing over it (WS_CLIPCHILDREN) and, a form, has no CS_HREDRAW / CS_VREDRAW }
procedure TSearchResultsView.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_CLIPCHILDREN;
end;

{ the list covers the whole view: nothing of the form shows, nothing to erase }
procedure TSearchResultsView.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TSearchResultsView.Clear;
begin
  SearchList.Items.Clear;
  FText := nil;
end;

procedure TSearchResultsView.BeginResults;
begin
  SearchList.Items.BeginUpdate;
  Clear;
end;

{ the shown rows grow by doubling (trimmed in EndResults) }
procedure TSearchResultsView.AddResult(const Item: string; const Shown: WideString);
var
  N: Integer;
begin
  N := SearchList.Items.Add(Item);
  if N >= Length(FText) then SetLength(FText, 2 * N + 64);
  FText[N] := Shown;
end;

procedure TSearchResultsView.EndResults;
begin
  SetLength(FText, SearchList.Items.Count);
  SearchList.Items.EndUpdate;
end;

{ "C:\path\File.pas(123): text": that file at that line }
procedure TSearchResultsView.SearchListDblClick(Sender: TObject);
var
  S, F: string;
  P, Q, Line: Integer;
begin
  if SearchList.ItemIndex < 0 then Exit;
  S := SearchList.Items[SearchList.ItemIndex];
  P := Pos('): ', S);
  if P = 0 then Exit;
  Q := P - 1;
  while (Q > 0) and (S[Q] in ['0'..'9']) do Dec(Q);
  if (Q = 0) or (S[Q] <> '(') then Exit;
  F := Copy(S, 1, Q - 1);
  Line := StrToIntDef(Copy(S, Q + 1, P - Q - 1), 1);
  if Assigned(FOnOpen) then FOnOpen(Self, F, Line);
end;

{ each row as found, in Unicode (FText); its width for the list's horizontal tracking }
procedure TSearchResultsView.SearchListDrawItem(Control: TWinControl; Index: Integer; Rect: TRect;
  State: TOwnerDrawState);
var
  C: TCanvas;
  W: WideString;
begin
  C := SearchList.Canvas;
  C.FillRect(Rect);
  if Index < Length(FText) then W := FText[Index] else W := ToWide(SearchList.Items[Index], CP_ACP);
  Inc(Rect.Left, 2);
  SetBkMode(C.Handle, TRANSPARENT);
  DrawTextUnicode(C, W, Rect, DT_SINGLELINE or DT_VCENTER or DT_NOPREFIX or DT_END_ELLIPSIS);
  UIListRowWidth(SearchList, Rect.Left + TextWidthUnicode(C, W));   // not the item's ANSI string
end;

end.
