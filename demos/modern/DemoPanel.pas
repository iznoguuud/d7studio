{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit DemoPanel;

{ A form the main form puts on a panel at run time (DemoPanel.dfm), and into a window of its own
  on request (Float). A form put on a host - embedded, or moved to another host - is scaled from its
  own DPI to the host's (TCustomForm.SetParent): its controls, fonts and image lists, and each of
  its controls hears CM_DPICHANGED. Floating, it follows the monitor it is on, as every window does. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ComCtrls, CheckLst;

type
  TLogEvent = procedure(const Text: string) of object;

  TPanelForm = class(TForm)
    DpiLabel: TLabel;
    NameEdit: TEdit;
    Kind: TComboBox;
    Options: TCheckListBox;
    Level: TTrackBar;
    procedure FormCreate(Sender: TObject);
  private
    FOnLog: TLogEvent;
    procedure ShowDpi;
    procedure CMDpiChanged(var Message: TMessage); message CM_DPICHANGED;
  public
    { told when the form was scaled for a new DPI }
    property OnLog: TLogEvent read FOnLog write FOnLog;
  end;

implementation

{$R *.dfm}

procedure TPanelForm.FormCreate(Sender: TObject);
begin
  Kind.ItemIndex := 0;
  Options.Checked[1] := True;
  ShowDpi;
end;

procedure TPanelForm.ShowDpi;
begin
  DpiLabel.Caption := Format('This form is at %d DPI (its PixelsPerInch).', [PixelsPerInch]);
end;

{ the main window was scaled, the form with it, or the form was put on a host of another DPI }
procedure TPanelForm.CMDpiChanged(var Message: TMessage);
begin
  inherited;
  ShowDpi;
  if Assigned(FOnLog) then
    FOnLog(Format('The embedded form was scaled from %d to %d DPI', [Message.WParam, Message.LParam]));
end;

end.
