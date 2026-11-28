{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdPrintDlg;

{ D7 Studio - Delphi 7's Print Selection, File | Print: the file,
  the selected block only, header / page number, line numbers, syntax print, colour, wrapped
  lines, left margin (characters); Setup... the printer. The options are kept ([Print Selection],
  Delphi keeps them under the same name). PrintEditor prints with Scintilla's own formatting. }

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, Dialogs, StdCtrls, ExtCtrls,
  SdSciEdit;

type
  TPrintOptions = record
    Header, LineNumbers, SyntaxPrint, Color, WrapLines, Selection: Boolean;
    Margin: Integer;
  end;

  TPrintDlg = class(TForm)
    xGroupBox1: TGroupBox;
    xLabel2: TLabel;
    cbHeader: TCheckBox;
    cbLineNumbers: TCheckBox;
    cbSyntaxPrint: TCheckBox;
    cbColor: TCheckBox;
    cbWrapLines: TCheckBox;
    ebMargin: TEdit;
    xGroupBox2: TGroupBox;
    lbFileName: TLabel;
    cbSelectedText: TCheckBox;
    PrinterSetupDialog1: TPrinterSetupDialog;
    pnlFooter: TPanel;
    lnFooter: TShape;
    SetupBtn: TButton;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure SetupBtnClick(Sender: TObject);
  public
    class function Execute(AOwner: TComponent; const FileName: string; HasSelection: Boolean;
      var Opts: TPrintOptions): Boolean;
  end;

var
  PrintDlg: TPrintDlg;

{ prints the text of an editor (or its selection) as the options say }
procedure PrintEditor(Ed: TSciEdit; const Title: string; const Opts: TPrintOptions);

implementation

uses
  Printers, FileCtrl, SdUI, SdSettings, SdSciDefs;

{$R *.dfm}

const
  Sec = 'Print Selection';

procedure TPrintDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

procedure TPrintDlg.SetupBtnClick(Sender: TObject);
begin
  PrinterSetupDialog1.Execute;
end;

class function TPrintDlg.Execute(AOwner: TComponent; const FileName: string; HasSelection: Boolean;
  var Opts: TPrintOptions): Boolean;
var
  D: TPrintDlg;
begin
  D := TPrintDlg.Create(AOwner);
  try
    { measured in the label's font (its canvas gets it only when it paints), as wide as the label }
    D.lbFileName.Canvas.Font := D.lbFileName.Font;
    D.lbFileName.Caption := MinimizeName(FileName, D.lbFileName.Canvas, D.lbFileName.Width);
    D.cbHeader.Checked := Settings.ReadBool(Sec, 'Header', True);
    D.cbLineNumbers.Checked := Settings.ReadBool(Sec, 'LineNumbers', False);
    D.cbSyntaxPrint.Checked := Settings.ReadBool(Sec, 'SyntaxPrint', True);
    D.cbColor.Checked := Settings.ReadBool(Sec, 'Color', False);
    D.cbWrapLines.Checked := Settings.ReadBool(Sec, 'WrapLines', False);
    D.ebMargin.Text := IntToStr(Settings.ReadInteger(Sec, 'LeftMargin', 0));
    D.cbSelectedText.Enabled := HasSelection;
    D.cbSelectedText.Checked := HasSelection;
    Result := D.ShowModal = mrOk;
    if not Result then Exit;
    Opts.Header := D.cbHeader.Checked;
    Opts.LineNumbers := D.cbLineNumbers.Checked;
    Opts.SyntaxPrint := D.cbSyntaxPrint.Checked;
    Opts.Color := D.cbColor.Checked;
    Opts.WrapLines := D.cbWrapLines.Checked;
    Opts.Margin := StrToIntDef(Trim(D.ebMargin.Text), 0);
    Opts.Selection := D.cbSelectedText.Checked;
    Settings.WriteBool(Sec, 'Header', Opts.Header);
    Settings.WriteBool(Sec, 'LineNumbers', Opts.LineNumbers);
    Settings.WriteBool(Sec, 'SyntaxPrint', Opts.SyntaxPrint);
    Settings.WriteBool(Sec, 'Color', Opts.Color);
    Settings.WriteBool(Sec, 'WrapLines', Opts.WrapLines);
    Settings.WriteInteger(Sec, 'LeftMargin', Opts.Margin);
  finally
    D.Free;
  end;
end;

type
  TSciCharRange = record
    cpMin, cpMax: Integer;
  end;
  TSciRangeToFormat = record
    hdc, hdcTarget: HDC;
    rc, rcPage: TRect;
    chrg: TSciCharRange;
  end;

procedure PrintEditor(Ed: TSciEdit; const Title: string; const Opts: TPrintOptions);
var
  F: TSciRangeToFormat;
  DC: HDC;
  PageW, PageH, DpiX, DpiY, Top, Page, Pos, Last, OldMargin, OldType, S: Integer;
  Header: string;
  ActiveWnd: HWND;
  WindowList: Pointer;
  Faces: array of Integer;       // without syntax print: bold 1, italic 2, underline 4 of each style
  W: TWinControl;                // the window the text is in: the print borrows its styles
begin
  if Ed.Sci(SCI_GETLENGTH) < 0 then Exit;
  W := Ed.Window;
  if W = nil then Exit;
  if Opts.Selection and (Ed.SelEnd > Ed.SelStart) then
  begin
    Pos := Ed.SelStart;
    Last := Ed.SelEnd;
  end
  else
  begin
    Pos := 0;
    Last := Ed.TextLength;
  end;
  { syntax print: the styles of the editor, in colour or black; without it plain black text (the
    colours are syntax colours: Color goes with syntax print) }
  if Opts.SyntaxPrint and Opts.Color then Ed.Sci(SCI_SETPRINTCOLOURMODE, SC_PRINT_COLOURONWHITE, 0)
  else Ed.Sci(SCI_SETPRINTCOLOURMODE, SC_PRINT_BLACKONWHITE, 0);
  if Opts.WrapLines then Ed.Sci(SCI_SETPRINTWRAPMODE, SC_WRAP_WORD, 0)
  else Ed.Sci(SCI_SETPRINTWRAPMODE, SC_WRAP_NONE, 0);
  { the editor lends its margins and styles to the print: given back whatever happens (a printer
    that cannot start raises in BeginDoc) }
  OldMargin := Ed.Sci(SCI_GETMARGINWIDTHN, 0, 0);
  OldType := Ed.Sci(SCI_GETMARGINTYPEN, 0, 0);
  Faces := nil;
  { while the job spools, the printer pumps messages (its abort procedure): the IDE takes no input
    (the page could close under the print) and the editor, whose margins and styles the print
    borrows, is not painted meanwhile }
  ActiveWnd := GetActiveWindow;
  WindowList := DisableTaskWindows(0);
  UIFreezeRedraw(W, True);
  try
    { the line numbers are printed with the line number margin - every line's number: the editor's
      text margin of every 5th line holds only the lines in view }
    Ed.Sci(SCI_SETMARGINTYPEN, 0, SC_MARGIN_NUMBER);
    if not Opts.LineNumbers then Ed.Sci(SCI_SETMARGINWIDTHN, 0, 0);
    if not Opts.SyntaxPrint then
    begin
      SetLength(Faces, STYLE_MAX + 1);
      for S := 0 to STYLE_MAX do
      begin
        Faces[S] := Ord(Ed.Sci(SCI_STYLEGETBOLD, S) <> 0) or Ord(Ed.Sci(SCI_STYLEGETITALIC, S) <> 0) shl 1 or
          Ord(Ed.Sci(SCI_STYLEGETUNDERLINE, S) <> 0) shl 2;
        if Faces[S] <> 0 then
        begin
          Ed.Sci(SCI_STYLESETBOLD, S, 0);
          Ed.Sci(SCI_STYLESETITALIC, S, 0);
          Ed.Sci(SCI_STYLESETUNDERLINE, S, 0);
        end;
      end;
    end;
    Printer.Title := Title;
    Printer.BeginDoc;
    try
      DC := Printer.Canvas.Handle;
      DpiX := GetDeviceCaps(DC, LOGPIXELSX);
      DpiY := GetDeviceCaps(DC, LOGPIXELSY);
      PageW := GetDeviceCaps(DC, HORZRES);
      PageH := GetDeviceCaps(DC, VERTRES);
      Page := 1;
      while Pos < Last do
      begin
        if Page > 1 then Printer.NewPage;
        DC := Printer.Canvas.Handle;
        Top := DpiY div 2;
        if Opts.Header then
        begin
          Printer.Canvas.Font.Name := 'Courier New';
          Printer.Canvas.Font.Size := 9;
          Header := Format('%s    Page %d', [Title, Page]);
          Printer.Canvas.TextOut(DpiX div 2, Top, Header);
          Inc(Top, Printer.Canvas.TextHeight(Header) * 2);
        end;
        FillChar(F, SizeOf(F), 0);
        F.hdc := DC;
        F.hdcTarget := DC;
        F.rc := Rect(DpiX div 2 + Opts.Margin * Printer.Canvas.TextWidth('0'), Top, PageW - DpiX div 2, PageH - DpiY div 2);
        F.rcPage := Rect(0, 0, PageW, PageH);
        F.chrg.cpMin := Pos;
        F.chrg.cpMax := Last;
        Pos := Ed.Sci(SCI_FORMATRANGE, 1, Integer(@F));
        Inc(Page);
      end;
      Ed.Sci(SCI_FORMATRANGE, 0, 0);
    finally
      Printer.EndDoc;
    end;
  finally
    Ed.Sci(SCI_SETMARGINWIDTHN, 0, OldMargin);
    Ed.Sci(SCI_SETMARGINTYPEN, 0, OldType);
    for S := 0 to High(Faces) do
      if Faces[S] <> 0 then
      begin
        Ed.Sci(SCI_STYLESETBOLD, S, Faces[S] and 1);
        Ed.Sci(SCI_STYLESETITALIC, S, (Faces[S] shr 1) and 1);
        Ed.Sci(SCI_STYLESETUNDERLINE, S, (Faces[S] shr 2) and 1);
      end;
    UIFreezeRedraw(W, False);
    EnableTaskWindows(WindowList);
    SetActiveWindow(ActiveWnd);
  end;
end;

end.
