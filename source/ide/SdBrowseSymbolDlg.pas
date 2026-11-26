{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdBrowseSymbolDlg;

{ D7 Studio - Delphi 7's Browse Symbol, Search | Browse
  Symbol: the name of a symbol (Unit, Class, Class.Member) whose declaration is shown. }

interface

uses
  Classes, Forms, StdCtrls, ExtCtrls;

type
  TBrowseSymbolDlg = class(TForm)
    xLabel1: TLabel;
    SearchSymbol: TComboBox;
    pnlFooter: TPanel;
    lnFooter: TShape;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
  public
    class function Execute(AOwner: TComponent; var Symbol: string): Boolean;
  end;

var
  BrowseSymbolDlg: TBrowseSymbolDlg;

implementation

uses
  SdUI, SdFindErrorDlg;

{$R *.dfm}

procedure TBrowseSymbolDlg.FormCreate(Sender: TObject);
begin
  UIPrepareForm(Self);
end;

class function TBrowseSymbolDlg.Execute(AOwner: TComponent; var Symbol: string): Boolean;
var
  D: TBrowseSymbolDlg;
begin
  D := TBrowseSymbolDlg.Create(AOwner);
  try
    Result := ExecuteHistoryCombo(D, D.SearchSymbol, 'hlBrowseSymbol', Symbol);
  finally
    D.Free;
  end;
end;

end.
