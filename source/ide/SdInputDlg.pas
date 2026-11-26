{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdInputDlg;

{ D7 Studio - a prompt and one line of text: Go to Line Number, Watch Properties, the
  condition of a breakpoint; in Unicode (ExecuteWide) for a WideString property of the Object
  Inspector - then a rich edit (RichEdit 2.0 keeps its text in UTF-16) takes the place of the edit. }

interface

uses
  Windows, Messages, Classes, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls;

type
  { what OK finds wrong with the text ('' nothing) - Go to Line Number's number }
  TInputCheck = function(const Value: string): string;

  TInputDlg = class(TForm)
    lblPrompt: TLabel;
    edValue: TEdit;
    reValue: TRichEdit;
    pnlFooter: TPanel;
    lnFooter: TShape;
    btnOK: TButton;
    btnCancel: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
  private
    FCheck: TInputCheck;
    function WideText: WideString;
    procedure SetWideText(const W: WideString);
    { Wide: the rich edit with W, else the edit with S }
    class function Run(AOwner: TComponent; const ACaption, Prompt: string; Wide: Boolean;
      var S: string; var W: WideString; Check: TInputCheck): Boolean;
  public
    { Check: the text's check on OK (nil: none) - the dialog stays open while it finds something }
    class function Execute(AOwner: TComponent; const ACaption, Prompt: string; var Value: string;
      Check: TInputCheck = nil): Boolean;
    class function ExecuteWide(AOwner: TComponent; const ACaption, Prompt: string; var Value: WideString): Boolean;
  end;

var
  InputDlg: TInputDlg;

implementation

uses
  SdUI, SdDialogs;

{$R *.dfm}

procedure TInputDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

procedure TInputDlg.btnOKClick(Sender: TObject);
begin
  if not Assigned(FCheck) or DialogValid(Self, FCheck(edValue.Text), edValue) then ModalResult := mrOk;
end;

const
  EM_GETTEXTEX = WM_USER + 94;
  EM_GETTEXTLENGTHEX = WM_USER + 95;
  EM_SETTEXTEX = WM_USER + 97;
  CP_UTF16 = 1200;

type
  TGetTextEx = record
    cb, flags, codepage: DWORD;
    lpDefaultChar: PChar;
    lpUsedDefChar: PBOOL;
  end;
  TGetTextLengthEx = record
    flags, codepage: DWORD;
  end;
  TSetTextEx = record
    flags, codepage: DWORD;
  end;

{ the rich edit's text in UTF-16, whatever the code page }
function TInputDlg.WideText: WideString;
var
  GL: TGetTextLengthEx;
  GT: TGetTextEx;
  N: Integer;
begin
  GL.flags := 0;
  GL.codepage := CP_UTF16;
  N := SendMessage(reValue.Handle, EM_GETTEXTLENGTHEX, WPARAM(@GL), 0);
  SetLength(Result, N);
  if N = 0 then Exit;
  FillChar(GT, SizeOf(GT), 0);
  GT.cb := (N + 1) * 2;
  GT.codepage := CP_UTF16;
  SendMessage(reValue.Handle, EM_GETTEXTEX, WPARAM(@GT), LPARAM(PWideChar(Result)));
end;

procedure TInputDlg.SetWideText(const W: WideString);
var
  ST: TSetTextEx;
begin
  ST.flags := 0;
  ST.codepage := CP_UTF16;
  SendMessage(reValue.Handle, EM_SETTEXTEX, WPARAM(@ST), LPARAM(PWideChar(W)));
end;

class function TInputDlg.Run(AOwner: TComponent; const ACaption, Prompt: string; Wide: Boolean;
  var S: string; var W: WideString; Check: TInputCheck): Boolean;
var
  D: TInputDlg;
begin
  D := TInputDlg.Create(AOwner);
  try
    D.FCheck := Check;
    D.Caption := ACaption;
    D.lblPrompt.Caption := Prompt;
    if Wide then
    begin
      D.edValue.Visible := False;
      D.reValue.Visible := True;
      D.lblPrompt.FocusControl := D.reValue;
      D.ActiveControl := D.reValue;
      D.SetWideText(W);
    end
    else
      D.edValue.Text := S;
    Result := D.ShowModal = mrOk;
    if Result then
      if Wide then W := D.WideText else S := D.edValue.Text;
  finally
    D.Free;
  end;
end;

class function TInputDlg.Execute(AOwner: TComponent; const ACaption, Prompt: string;
  var Value: string; Check: TInputCheck): Boolean;
var
  Unused: WideString;
begin
  Result := Run(AOwner, ACaption, Prompt, False, Value, Unused, Check);
end;

class function TInputDlg.ExecuteWide(AOwner: TComponent; const ACaption, Prompt: string;
  var Value: WideString): Boolean;
var
  Unused: string;
begin
  Result := Run(AOwner, ACaption, Prompt, True, Unused, Value, nil);
end;

end.
