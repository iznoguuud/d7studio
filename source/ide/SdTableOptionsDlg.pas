{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdTableOptionsDlg;

{ D7 Studio - the To-Do List's Table Properties: Delphi 7's,
  for Copy As | HTML Table (SdTodo's TSdTodoTable).
  Table: caption, border width, width in percent, cell spacing and padding, background colour,
  alignment; Columns: the six columns (listed by their own names, as Delphi lists them) with
  title, width, height, wrap, visible, alignment, vertical alignment and font. Delphi's preview
  of the table (a TWebBrowser) and its Apply, which only renews the preview, are left out. A
  number that is no number keeps the dialog open on OK (Delphi's); one of a column is not taken. }

interface

uses
  SysUtils, Classes, Controls, Forms, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, SdTodo;

type
  TTableOptionsDlg = class(TForm)
    ColorDialog: TColorDialog;
    PageControl: TPageControl;
    tsTable: TTabSheet;
    xLabel6: TLabel;
    xLabel7: TLabel;
    xLabel8: TLabel;
    xLabel9: TLabel;
    xLabel10: TLabel;
    xLabel13: TLabel;
    btnColor: TButton;
    eTableCaption: TEdit;
    eTableBorder: TEdit;
    eTableWidth: TEdit;
    eCellSpacing: TEdit;
    eCellPadding: TEdit;
    xUpDown4: TUpDown;
    xUpDown5: TUpDown;
    xUpDown6: TUpDown;
    xUpDown7: TUpDown;
    rgTableAlignment: TRadioGroup;
    pBackColor: TPanel;
    tsColumns: TTabSheet;
    xLabel11: TLabel;
    ColList: TListBox;
    rgAlign: TRadioGroup;
    rgVAlign: TRadioGroup;
    xGroupBox2: TGroupBox;
    xLabel4: TLabel;
    xLabel5: TLabel;
    xLabel12: TLabel;
    btnColColor: TButton;
    eColFontSize: TEdit;
    eFontFace: TEdit;
    cbBold: TCheckBox;
    cbItalic: TCheckBox;
    xUpDown3: TUpDown;
    pFontColor: TPanel;
    xGroupBox4: TGroupBox;
    xLabel1: TLabel;
    xLabel2: TLabel;
    xLabel3: TLabel;
    eColHeight: TEdit;
    eColWidth: TEdit;
    eColTitle: TEdit;
    udColWidth: TUpDown;
    xUpDown2: TUpDown;
    cbWrapText: TCheckBox;
    cbVisible: TCheckBox;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure ColListClick(Sender: TObject);
    procedure btnColorClick(Sender: TObject);
    procedure btnColColorClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    FTable: TSdTodoTable;      // what the dialog edits
    FCur: Integer;             // the column the controls show, -1 none
    procedure StoreColumn;
  public
    destructor Destroy; override;
    class function Execute(AOwner: TComponent; Table: TSdTodoTable): Boolean;
  end;

implementation

{$R *.dfm}

uses
  SdUI, SdDialogs;

procedure TTableOptionsDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  if UILayoutPass then Exit;
  FTable := TSdTodoTable.Create;
  FCur := -1;
end;

destructor TTableOptionsDlg.Destroy;
begin
  FTable.Free;
  inherited;
end;

{ Delphi's ColListClick: the values of the controls into the column shown (a width, height or
  font size that is no number is not taken), then the chosen column into the controls }
procedure TTableOptionsDlg.StoreColumn;
begin
  if FCur < 0 then Exit;
  with FTable.Columns[TSdTodoColType(FCur)] do
  begin
    Title := eColTitle.Text;
    Wrap := cbWrapText.Checked;
    Visible := cbVisible.Checked;
    if rgVAlign.ItemIndex >= 0 then VAlign := TSdTodoVAlign(rgVAlign.ItemIndex);
    if rgAlign.ItemIndex >= 0 then Align := TAlignment(rgAlign.ItemIndex);
    Width := StrToIntDef(eColWidth.Text, Width);
    Height := StrToIntDef(eColHeight.Text, Height);
    FontSize := StrToIntDef(eColFontSize.Text, FontSize);
    FontFace := Copy(eFontFace.Text, 1, 63);
    Bold := cbBold.Checked;
    Italic := cbItalic.Checked;
    FontColor := pFontColor.Color;
  end;
end;

procedure TTableOptionsDlg.ColListClick(Sender: TObject);
begin
  StoreColumn;
  FCur := ColList.ItemIndex;
  if FCur < 0 then Exit;
  with FTable.Columns[TSdTodoColType(FCur)] do
  begin
    eColTitle.Text := Title;
    eColWidth.Text := IntToStr(Width);
    eColHeight.Text := IntToStr(Height);
    rgAlign.ItemIndex := Ord(Align);
    if VAlign <= vaBottom then rgVAlign.ItemIndex := Ord(VAlign) else rgVAlign.ItemIndex := -1;
    cbVisible.Checked := Visible;
    eColFontSize.Text := IntToStr(FontSize);
    eFontFace.Text := FontFace;
    cbBold.Checked := Bold;
    cbItalic.Checked := Italic;
    cbWrapText.Checked := Wrap;
    pFontColor.Color := FontColor;
  end;
end;

procedure TTableOptionsDlg.btnColorClick(Sender: TObject);
begin
  ColorDialog.Color := pBackColor.Color;
  if ColorDialog.Execute then pBackColor.Color := ColorDialog.Color;
end;

procedure TTableOptionsDlg.btnColColorClick(Sender: TObject);
begin
  ColorDialog.Color := pFontColor.Color;
  if ColorDialog.Execute then pFontColor.Color := ColorDialog.Color;
end;

{ OK: Delphi's Apply - the column shown, then the table's values; a number of the table that is
  no number keeps the dialog open (the RTL's message, as Delphi shows its EConvertError, and the
  field on its page) }
procedure TTableOptionsDlg.btnOKClick(Sender: TObject);
var
  Border, W, Spacing, Padding: Integer;
begin
  StoreColumn;
  if not DialogValid(Self, CheckNumber(eTableBorder, Low(Integer), High(Integer), '', Border), eTableBorder, 'Error') or
    not DialogValid(Self, CheckNumber(eTableWidth, Low(Integer), High(Integer), '', W), eTableWidth, 'Error') or
    not DialogValid(Self, CheckNumber(eCellSpacing, Low(Integer), High(Integer), '', Spacing), eCellSpacing, 'Error') or
    not DialogValid(Self, CheckNumber(eCellPadding, Low(Integer), High(Integer), '', Padding), eCellPadding, 'Error') then Exit;
  FTable.Caption := eTableCaption.Text;
  FTable.BorderWidth := Border;
  FTable.Width := W;
  FTable.CellSpacing := Spacing;
  FTable.CellPadding := Padding;
  if rgTableAlignment.ItemIndex >= 0 then FTable.Align := TAlignment(rgTableAlignment.ItemIndex);
  FTable.BackgroundColor := pBackColor.Color;
  ModalResult := mrOk;
end;

{ Delphi's ReadData and FormShow: the values into the controls once their windows are there (an
  up-down sets its edit's text when it gets its window) }
procedure TTableOptionsDlg.FormShow(Sender: TObject);
var
  C: TSdTodoColType;
  I: Integer;
begin
  { the up-downs of the Columns page as well (a page makes its windows when it is first shown) }
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TUpDown then TUpDown(Components[I]).HandleNeeded;
  eTableCaption.Text := FTable.Caption;
  eTableBorder.Text := IntToStr(FTable.BorderWidth);
  eTableWidth.Text := IntToStr(FTable.Width);
  eCellSpacing.Text := IntToStr(FTable.CellSpacing);
  eCellPadding.Text := IntToStr(FTable.CellPadding);
  pBackColor.Color := FTable.BackgroundColor;
  rgTableAlignment.ItemIndex := Ord(FTable.Align);
  for C := Low(C) to High(C) do ColList.Items.Add(TodoColTitles[C]);
  ColList.ItemIndex := 0;
  ColListClick(nil);
  PageControl.ActivePage := tsTable;
  ActiveControl := eTableCaption;
end;

class function TTableOptionsDlg.Execute(AOwner: TComponent; Table: TSdTodoTable): Boolean;
var
  D: TTableOptionsDlg;
begin
  D := TTableOptionsDlg.Create(AOwner);
  try
    D.FTable.Assign(Table);
    Result := D.ShowModal = mrOK;
    if Result then Table.Assign(D.FTable);
  finally
    D.Free;
  end;
end;

end.
