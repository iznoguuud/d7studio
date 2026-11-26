{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCompTemplateDlg;

{ D7 Studio - Component | Create Component Template: Delphi 7's Component Template Information.
  The template's
  name, its page (a category of the Components view) and its icon - its first component's, or a
  bitmap chosen with Change. }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls;

type
  TCompTemplateDlg = class(TForm)
    xLabel1: TLabel;
    xLabel2: TLabel;
    xLabel3: TLabel;
    Preview: TPaintBox;
    ComponentName: TEdit;
    PageList: TComboBox;
    ChangeButton: TButton;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure ChangeButtonClick(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
    procedure PreviewPaint(Sender: TObject);
  private
    FIcon: TBitmap;
    FIconFile: string;
  public
    destructor Destroy; override;
    { Icon: the icon of the template's first component (shown until another is chosen) }
    class function Execute(AOwner: TComponent; Pages: TStrings; Icon: TBitmap; var Name, Page,
      IconFile: string): Boolean;
  end;

var
  CompTemplateDlg: TCompTemplateDlg;

implementation

uses
  SdUI, SdDialogs;

{$R *.dfm}

procedure TCompTemplateDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
  FIcon := TBitmap.Create;
end;

destructor TCompTemplateDlg.Destroy;
begin
  FIcon.Free;
  inherited Destroy;
end;

procedure TCompTemplateDlg.PreviewPaint(Sender: TObject);
begin
  Preview.Canvas.Brush.Color := Color;
  Preview.Canvas.FillRect(Preview.ClientRect);
  if not FIcon.Empty then
    Preview.Canvas.Draw((Preview.Width - FIcon.Width) div 2, (Preview.Height - FIcon.Height) div 2, FIcon);
end;

procedure TCompTemplateDlg.ChangeButtonClick(Sender: TObject);
var
  F: string;
begin
  F := '';
  if not BrowseFile('Select Palette Icon', 'Bitmaps (*.bmp)|*.bmp|Any File (*.*)|*.*', F) then Exit;
  try
    FIcon.LoadFromFile(F);
    FIconFile := F;
    Preview.Invalidate;
  except
    MessageBox(Handle, PChar('Not a bitmap: ' + F), PChar(Caption), MB_OK or MB_ICONERROR);
  end;
end;

{ a name (an identifier) and a page }
procedure TCompTemplateDlg.OKButtonClick(Sender: TObject);
const
  Msg = 'A template needs a name (an identifier) and a page.';
begin
  if DialogValid(Self, IsValidIdent(Trim(ComponentName.Text)), Msg, ComponentName) and
    DialogValid(Self, Trim(PageList.Text) <> '', Msg, PageList) then ModalResult := mrOk;
end;

class function TCompTemplateDlg.Execute(AOwner: TComponent; Pages: TStrings; Icon: TBitmap; var Name, Page,
  IconFile: string): Boolean;
var
  D: TCompTemplateDlg;
begin
  D := TCompTemplateDlg.Create(AOwner);
  try
    D.PageList.Items.Assign(Pages);
    D.ComponentName.Text := Name;
    D.PageList.Text := Page;
    if Icon <> nil then D.FIcon.Assign(Icon);
    Result := D.ShowModal = mrOk;
    if not Result then Exit;
    Name := Trim(D.ComponentName.Text);
    Page := Trim(D.PageList.Text);
    IconFile := D.FIconFile;
  finally
    D.Free;
  end;
end;

end.
