{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdImageTextDlg;

{ D7 Studio - the image editor's text tool: the text (lines), its font
  (the font dialog; kept for the next time) and Smooth edges - an image of 32 bits takes the text
  with its edges blended, other images whole pixels. }

interface

uses
  SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, Dialogs;

type
  TImageTextDlg = class(TForm)
    lblText: TLabel;
    mmText: TMemo;
    lblFontName: TLabel;
    btnFont: TButton;
    cbSmooth: TCheckBox;
    FontDialog: TFontDialog;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnFontClick(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FFont: TFont;
    procedure ShowFont;
  public
    class function Execute(AOwner: TComponent; var Text: string; Font: TFont; var Smooth: Boolean): Boolean;
  end;

var
  ImageTextDlg: TImageTextDlg;

implementation

uses
  SdUI, SdDialogs;

{$R *.dfm}

procedure TImageTextDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

procedure TImageTextDlg.ShowFont;
var
  S: string;
begin
  S := Format('%s, %d pt', [FFont.Name, FFont.Size]);
  if fsBold in FFont.Style then S := S + ', bold';
  if fsItalic in FFont.Style then S := S + ', italic';
  if fsUnderline in FFont.Style then S := S + ', underlined';
  lblFontName.Caption := S;
end;

procedure TImageTextDlg.btnFontClick(Sender: TObject);
begin
  FontDialog.Font.Assign(FFont);
  if not FontDialog.Execute then Exit;
  FFont.Assign(FontDialog.Font);
  ShowFont;
end;

procedure TImageTextDlg.btnOKClick(Sender: TObject);
begin
  if DialogValid(Self, Trim(mmText.Text) <> '', 'Type the text to draw.', mmText) then ModalResult := mrOk;
end;

class function TImageTextDlg.Execute(AOwner: TComponent; var Text: string; Font: TFont; var Smooth: Boolean): Boolean;
var
  D: TImageTextDlg;
begin
  D := TImageTextDlg.Create(AOwner);
  try
    D.FFont := Font;
    D.ShowFont;
    D.mmText.Text := Text;
    D.cbSmooth.Checked := Smooth;
    Result := D.ShowModal = mrOk;
    if Result then
    begin
      { the lines as they were typed, without the line break after the last one }
      Text := D.mmText.Text;
      while (Text <> '') and (Text[Length(Text)] in [#13, #10]) do SetLength(Text, Length(Text) - 1);
      Smooth := D.cbSmooth.Checked;
    end;
  finally
    D.Free;
  end;
end;

end.
