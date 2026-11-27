{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdTransferDlg;

{ D7 Studio - Delphi 7's Tool Options, Tools | Configure Tools:
  the programs of the Tools menu - add, delete, edit (SdTransEditDlg), move, export to a file and import
  from one. The list is kept by
  SdEnvOptions ([Transfer]). }

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, Buttons,
  ActnList, SdEnvOptions;

type
  TTransferDlg = class(TForm)
    xLabel1: TLabel;
    xLabel2: TLabel;
    xLabel3: TLabel;
    ItemList: TListBox;
    DnBtn: TBitBtn;
    UpBtn: TBitBtn;
    AddButton: TButton;
    DelButton: TButton;
    EditButton: TButton;
    ExportButton: TButton;
    ImportButton: TButton;
    Actions: TActionList;
    aAdd: TAction;
    aDelete: TAction;
    aEdit: TAction;
    aUp: TAction;
    aDown: TAction;
    aExport: TAction;
    aImport: TAction;
    pnlFooter: TPanel;
    lnFooter: TShape;
    CloseButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure aAddExecute(Sender: TObject);
    procedure aDeleteExecute(Sender: TObject);
    procedure aEditExecute(Sender: TObject);
    procedure aMoveExecute(Sender: TObject);
    procedure aMoveUpdate(Sender: TObject);
    procedure SelectedUpdate(Sender: TObject);
    procedure ItemDraw(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure ItemDblClick(Sender: TObject);
    procedure aExportExecute(Sender: TObject);
    procedure aExportUpdate(Sender: TObject);
    procedure aImportExecute(Sender: TObject);
  private
    FTools: TTransferTools;
    procedure FillList(Index: Integer);
  public
    { the list is saved when the dialog closes (it has no Cancel, as in Delphi) }
    class procedure Execute(AOwner: TComponent);
  end;

var
  TransferDlg: TTransferDlg;

implementation

uses
  SdUI, SdTransEditDlg, SdDialogs, SdIcons;

{$R *.dfm}

procedure TTransferDlg.FormCreate(Sender: TObject);
var
  I: Integer;
  T: TTransferTool;
begin
  UIPrepareForm(Self);
  if UILayoutPass then Exit;
  IconButton(UpBtn, iiMoveUp);
  IconButton(DnBtn, iiMoveDown);
  I := 0;
  while ReadTransferTool(I, T) do
  begin
    SetLength(FTools, I + 1);
    FTools[I] := T;
    Inc(I);
  end;
  FillList(0);
end;

procedure TTransferDlg.FillList(Index: Integer);
var
  I: Integer;
begin
  ItemList.Items.BeginUpdate;
  try
    ItemList.Items.Clear;
    for I := 0 to High(FTools) do ItemList.Items.Add(FTools[I].Title);
  finally
    ItemList.Items.EndUpdate;
  end;
  if Index >= ItemList.Items.Count then Index := ItemList.Items.Count - 1;
  ItemList.ItemIndex := Index;
end;

{ the title without its '&' (Delphi marks clashing access keys with '*' - none here), a plain row }
procedure TTransferDlg.ItemDraw(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  UIDrawListRow(ItemList, ItemList.Canvas.Handle, Rect, StringReplace(ItemList.Items[Index], '&', '',
    [rfReplaceAll]), odSelected in State);
end;

procedure TTransferDlg.aAddExecute(Sender: TObject);
var
  T: TTransferTool;
begin
  FillChar(T, SizeOf(T), 0);
  if not TToolPropertiesDlg.Execute(Self, '', T) then Exit;
  SetLength(FTools, Length(FTools) + 1);
  FTools[High(FTools)] := T;
  FillList(High(FTools));
end;

{ a double click edits the tool: Edit's action }
procedure TTransferDlg.ItemDblClick(Sender: TObject);
begin
  aEdit.Execute;
end;

procedure TTransferDlg.aDeleteExecute(Sender: TObject);
var
  I, K: Integer;
begin
  K := DeleteListRow(ItemList);
  if K < 0 then Exit;
  for I := K to High(FTools) - 1 do FTools[I] := FTools[I + 1];
  SetLength(FTools, Length(FTools) - 1);
end;

procedure TTransferDlg.aEditExecute(Sender: TObject);
var
  K: Integer;
begin
  K := ItemList.ItemIndex;
  if K < 0 then Exit;
  if TToolPropertiesDlg.Execute(Self, '', FTools[K]) then FillList(K);
end;

procedure TTransferDlg.aMoveExecute(Sender: TObject);
var
  K, J: Integer;
  T: TTransferTool;
begin
  K := MoveListRow(ItemList, Sender = aUp);
  if K < 0 then Exit;
  J := ItemList.ItemIndex;
  T := FTools[K];
  FTools[K] := FTools[J];
  FTools[J] := T;
end;

procedure TTransferDlg.aMoveUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := CanMoveListRow(ItemList, Sender = aUp);
end;

procedure TTransferDlg.SelectedUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := ItemList.ItemIndex >= 0;
end;

const
  ToolFilter = 'Tool lists (*.ini)|*.ini|All files (*.*)|*.*';

procedure TTransferDlg.aExportExecute(Sender: TObject);
var
  S: string;
begin
  S := 'Tools.ini';
  if BrowseFile('Export Tools', ToolFilter, S, bfSave, 'ini') then ExportTransferTools(S, FTools);
end;

procedure TTransferDlg.aExportUpdate(Sender: TObject);
begin
  aExport.Enabled := Length(FTools) > 0;
end;

{ the file's tools go after the list's; those the list holds already are left out }
procedure TTransferDlg.aImportExecute(Sender: TObject);
var
  S: string;
  N, K: Integer;
begin
  S := '';
  if not BrowseFile('Import Tools', ToolFilter, S, bfOpen, 'ini') then Exit;
  K := Length(FTools);
  N := ImportTransferTools(S, FTools);
  if N < 0 then
    MessageBox(Handle, PChar(ExtractFileName(S) + ' holds no tools.'), PChar(Caption), MB_OK or MB_ICONWARNING)
  else if N = 0 then
    MessageBox(Handle, 'The list holds every tool of the file already.', PChar(Caption), MB_OK or MB_ICONINFORMATION)
  else FillList(K);
end;

class procedure TTransferDlg.Execute(AOwner: TComponent);
var
  D: TTransferDlg;
begin
  D := TTransferDlg.Create(AOwner);
  try
    D.ShowModal;
    WriteTransferTools(D.FTools);
  finally
    D.Free;
  end;
end;

end.
