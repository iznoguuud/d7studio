{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCompListDlg;

{ D7 Studio - Delphi 7's Components window, View | Component
  List: every component of the palette by name with its icon, filtered by the start of the name
  typed into "Search by name"; Add to form (or a double click) places it on the form being
  designed. In Delphi a floating tool window; D7 Studio has one window, so it is a dialog that
  closes when the component is placed. }

interface

uses
  Windows, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, ActnList;

type
  TCompListDlg = class(TForm)
    xLabel1: TLabel;
    ComponentList: TListBox;
    SearchText: TEdit;
    Actions: TActionList;
    aOK: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    AddButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aOKExecute(Sender: TObject);
    procedure aOKUpdate(Sender: TObject);
    procedure SearchChange(Sender: TObject);
    procedure SearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ListDraw(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure ListDblClick(Sender: TObject);
  private
    FAll: TStringList;          // Name=index, objects: the classes
    procedure Filter;
  public
    destructor Destroy; override;
    { Classes: the component classes (objects); the one chosen, nil when none }
    class function Execute(AOwner: TComponent; Classes: TStrings): TComponentClass;
  end;

var
  CompListDlg: TCompListDlg;

implementation

uses
  SdUI, SdDesignHost, SdCompBar;

{$R *.dfm}

procedure TCompListDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  if UILayoutPass then Exit;
  FAll := TStringList.Create;
  FAll.Sorted := True;
  FAll.Duplicates := dupIgnore;
end;

destructor TCompListDlg.Destroy;
begin
  FAll.Free;
  inherited;
end;

{ the names that start with what is typed (Delphi's list: the class names without their T; the
  Components view's filter, prefix matches only) }
procedure TCompListDlg.Filter;
begin
  FillFiltered(SearchText.Text, FAll, ComponentList.Items, True);
  if ComponentList.Items.Count > 0 then ComponentList.ItemIndex := 0;
end;

procedure TCompListDlg.SearchChange(Sender: TObject);
begin
  Filter;
end;

{ the arrow keys move in the list while the search box has the focus }
procedure TCompListDlg.SearchKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  ForwardListKey(ComponentList, Key);
end;

procedure TCompListDlg.ListDraw(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var
  C: TCanvas;
  B: TBitmap;
begin
  C := ComponentList.Canvas;
  C.FillRect(Rect);
  B := DesignHost.ComponentBitmap(TClass(ComponentList.Items.Objects[Index]));
  if B <> nil then
  begin
    B.Transparent := True;
    C.StretchDraw(Classes.Rect(Rect.Left + 2, Rect.Top + 2, Rect.Left + 18, Rect.Top + 18), B);
  end;
  C.TextOut(Rect.Left + 22, UIListTextTop(C.Handle, Rect), ComponentList.Items[Index]);
  UIListRowWidth(ComponentList, Rect.Left + 22 + C.TextWidth(ComponentList.Items[Index]));
end;

{ Add to form, Enter, a double click: the component chosen goes onto the form }
procedure TCompListDlg.ListDblClick(Sender: TObject);
begin
  aOK.Execute;
end;

procedure TCompListDlg.aOKExecute(Sender: TObject);
begin
  ModalResult := mrOk;
end;

procedure TCompListDlg.aOKUpdate(Sender: TObject);
begin
  aOK.Enabled := ComponentList.ItemIndex >= 0;
end;

class function TCompListDlg.Execute(AOwner: TComponent; Classes: TStrings): TComponentClass;
var
  D: TCompListDlg;
  I: Integer;
  N: string;
begin
  Result := nil;
  D := TCompListDlg.Create(AOwner);
  try
    for I := 0 to Classes.Count - 1 do
    begin
      N := ComponentDisplayName(Classes[I]);
      D.FAll.AddObject(N, Classes.Objects[I]);
    end;
    D.Filter;
    if (D.ShowModal = mrOk) and (D.ComponentList.ItemIndex >= 0) then
      Result := TComponentClass(D.ComponentList.Items.Objects[D.ComponentList.ItemIndex]);
  finally
    D.Free;
  end;
end;

end.
