{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdChangeParamsDlg;

{ D7 Studio - Change Parameters: a routine's parameters to add, remove, reorder and edit - name,
  type, kind (const, var, out), default value, and for a new one the value the calls pass -, the
  heading they make shown as it changes. }

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls;

type
  TChangeParamsDlg = class(TForm)
    lvParams: TListView;
    btnAdd: TButton;
    btnRemove: TButton;
    btnUp: TButton;
    btnDown: TButton;
    lblPName: TLabel;
    edPName: TEdit;
    lblPType: TLabel;
    edPType: TEdit;
    lblPKind: TLabel;
    cbPKind: TComboBox;
    lblPDefault: TLabel;
    edPDefault: TEdit;
    lblPValue: TLabel;
    edPValue: TEdit;
    lblHeading: TLabel;
    edHeading: TEdit;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnAddClick(Sender: TObject);
    procedure btnRemoveClick(Sender: TObject);
    procedure btnUpClick(Sender: TObject);
    procedure btnDownClick(Sender: TObject);
    procedure lvParamsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
    procedure FieldChange(Sender: TObject);
  private
    FParams: TList;                  // TRefParam, owned
    FHead, FResult: string;
    FFilling: Boolean;
    function Current: TObject;
    procedure FillList(Select: Integer);
    procedure FillFields;
    procedure UpdateHeading;
    procedure Move(Delta: Integer);
  public
    { Head: 'procedure Name'; ResultType: a function's ('' none). Params: the parameters (TRefParam)
      in; the new ones out (the caller frees them, both times) }
    class function Execute(AOwner: TComponent; const Head, ResultType: string; Params: TList): Boolean;
  end;

var
  ChangeParamsDlg: TChangeParamsDlg;

implementation

uses
  SdUI, SdDialogs, SdRefactor;

{$R *.dfm}

const
  Kinds: array[0..3] of string = ('', 'const', 'var', 'out');

procedure TChangeParamsDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  FParams := TList.Create;
end;

procedure TChangeParamsDlg.FormDestroy(Sender: TObject);
begin
  FreeObjects(FParams);
  FParams.Free;
end;

function TChangeParamsDlg.Current: TObject;
begin
  if (lvParams.Selected <> nil) and (lvParams.Selected.Index < FParams.Count) then
    Result := TObject(FParams[lvParams.Selected.Index])
  else
    Result := nil;
end;

procedure TChangeParamsDlg.FillList(Select: Integer);
var
  I: Integer;
  P: TRefParam;
  It: TListItem;
begin
  lvParams.Items.BeginUpdate;
  try
    lvParams.Items.Clear;
    for I := 0 to FParams.Count - 1 do
    begin
      P := TRefParam(FParams[I]);
      It := lvParams.Items.Add;
      It.Caption := P.Name;
      It.SubItems.Add(P.TypeText);
      It.SubItems.Add(P.Modifier);
      It.SubItems.Add(P.Default);
      if P.OldIndex < 0 then It.SubItems.Add(P.CallValue) else It.SubItems.Add('');
    end;
  finally
    lvParams.Items.EndUpdate;
  end;
  if Select >= FParams.Count then Select := FParams.Count - 1;
  if Select >= 0 then
  begin
    lvParams.Selected := lvParams.Items[Select];
    lvParams.ItemFocused := lvParams.Selected;
  end;
  FillFields;
  UpdateHeading;
end;

procedure TChangeParamsDlg.FillFields;
var
  P: TRefParam;
  I: Integer;
  On: Boolean;
begin
  P := TRefParam(Current);
  FFilling := True;
  try
    On := P <> nil;
    edPName.Enabled := On;
    edPType.Enabled := On;
    cbPKind.Enabled := On;
    edPDefault.Enabled := On;
    edPValue.Enabled := On and (P.OldIndex < 0);
    btnRemove.Enabled := On;
    btnUp.Enabled := On and (lvParams.Selected.Index > 0);
    btnDown.Enabled := On and (lvParams.Selected.Index < FParams.Count - 1);
    if P = nil then
    begin
      edPName.Text := '';
      edPType.Text := '';
      cbPKind.ItemIndex := 0;
      edPDefault.Text := '';
      edPValue.Text := '';
      Exit;
    end;
    edPName.Text := P.Name;
    edPType.Text := P.TypeText;
    cbPKind.ItemIndex := 0;
    for I := 0 to High(Kinds) do
      if SameText(Kinds[I], P.Modifier) then cbPKind.ItemIndex := I;
    edPDefault.Text := P.Default;
    if P.OldIndex < 0 then edPValue.Text := P.CallValue else edPValue.Text := '';
  finally
    FFilling := False;
  end;
end;

procedure TChangeParamsDlg.UpdateHeading;
var
  S: string;
begin
  S := ParamListText(FParams, True);
  if S <> '' then S := '(' + S + ')';
  S := FHead + S;
  if FResult <> '' then S := S + ': ' + FResult;
  edHeading.Text := S + ';';
end;

{ a field edited: the parameter, its row and the heading follow }
procedure TChangeParamsDlg.FieldChange(Sender: TObject);
var
  P: TRefParam;
  It: TListItem;
begin
  if FFilling then Exit;
  P := TRefParam(Current);
  if P = nil then Exit;
  P.Name := Trim(edPName.Text);
  P.TypeText := Trim(edPType.Text);
  if cbPKind.ItemIndex >= 0 then P.Modifier := Kinds[cbPKind.ItemIndex];
  P.Default := Trim(edPDefault.Text);
  if P.OldIndex < 0 then P.CallValue := Trim(edPValue.Text);
  It := lvParams.Selected;
  It.Caption := P.Name;
  It.SubItems[0] := P.TypeText;
  It.SubItems[1] := P.Modifier;
  It.SubItems[2] := P.Default;
  if P.OldIndex < 0 then It.SubItems[3] := P.CallValue;
  UpdateHeading;
end;

procedure TChangeParamsDlg.lvParamsSelectItem(Sender: TObject; Item: TListItem; Selected: Boolean);
begin
  if Selected then FillFields;
end;

procedure TChangeParamsDlg.btnAddClick(Sender: TObject);
var
  P: TRefParam;
  N: Integer;
begin
  P := TRefParam.Create;
  N := FParams.Count + 1;
  P.Name := 'Value' + IntToStr(N);
  P.TypeText := 'Integer';
  P.OldIndex := -1;
  P.CallValue := '0';
  FParams.Add(P);
  FillList(FParams.Count - 1);
  edPName.SetFocus;
  edPName.SelectAll;
end;

procedure TChangeParamsDlg.btnRemoveClick(Sender: TObject);
var
  I: Integer;
begin
  if lvParams.Selected = nil then Exit;
  I := lvParams.Selected.Index;
  TObject(FParams[I]).Free;
  FParams.Delete(I);
  FillList(I);
end;

procedure TChangeParamsDlg.Move(Delta: Integer);
var
  I: Integer;
begin
  if lvParams.Selected = nil then Exit;
  I := lvParams.Selected.Index;
  if (I + Delta < 0) or (I + Delta >= FParams.Count) then Exit;
  FParams.Exchange(I, I + Delta);
  FillList(I + Delta);
end;

procedure TChangeParamsDlg.btnUpClick(Sender: TObject);
begin
  Move(-1);
end;

procedure TChangeParamsDlg.btnDownClick(Sender: TObject);
begin
  Move(1);
end;

{ OK: the list as Change Parameters takes it - else the parameter at fault shown, its field focused }
procedure TChangeParamsDlg.btnOKClick(Sender: TObject);
var
  Bad: Integer;
  Field: TRefParamField;
  Msg: string;
  Box: TWinControl;
begin
  Msg := CheckParamList(FParams, Bad, Field);
  if Msg <> '' then
  begin
    lvParams.Selected := lvParams.Items[Bad];
    FillFields;
    case Field of
      pfName: Box := edPName;
      pfType: Box := edPType;
    else
      Box := edPValue;
    end;
    DialogValid(Self, Msg, Box);
    Exit;
  end;
  ModalResult := mrOk;
end;

class function TChangeParamsDlg.Execute(AOwner: TComponent; const Head, ResultType: string; Params: TList): Boolean;
var
  D: TChangeParamsDlg;
  I: Integer;
  Q: TRefParam;
begin
  D := TChangeParamsDlg.Create(AOwner);
  try
    D.FHead := Head;
    D.FResult := ResultType;
    D.Caption := 'Change Parameters - ' + Head;
    for I := 0 to Params.Count - 1 do
    begin
      Q := TRefParam.Create;
      Q.Assign(TRefParam(Params[I]));
      D.FParams.Add(Q);
    end;
    D.FillList(0);
    Result := D.ShowModal = mrOk;
    if Result then
    begin
      FreeObjects(Params);
      for I := 0 to D.FParams.Count - 1 do Params.Add(D.FParams[I]);
      D.FParams.Clear;
    end;
  finally
    D.Free;
  end;
end;

end.
