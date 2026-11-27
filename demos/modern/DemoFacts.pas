{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit DemoFacts;

{ A list of facts - a name and a value on each row - for the Display and System pages.

  It is a frame (DemoFacts.dfm) that the main window makes at run time. The VCL scales a frame made
  at run time from 96 DPI to the DPI of its form when the frame is first put on it
  (Forms.ScaleRuntimeFrames), its list view's columns too: no code here knows about DPI. }

interface

uses
  Classes, Controls, Forms, ComCtrls, CommCtrl;

type
  TFactsFrame = class(TFrame)
    Facts: TListView;
  public
    { Shows Rows - a name, its value, a name, its value ... - in place of the rows before. }
    procedure Show(const Rows: array of string);
    { Adds one more row. }
    procedure Add(const Name, Value: string);
  end;

implementation

{$R *.dfm}

procedure TFactsFrame.Show(const Rows: array of string);
var
  I: Integer;
begin
  Facts.Items.BeginUpdate;
  try
    Facts.Items.Clear;
    I := 0;
    while I < High(Rows) do
    begin
      Add(Rows[I], Rows[I + 1]);
      Inc(I, 2);
    end;
  finally
    Facts.Items.EndUpdate;
  end;
end;

procedure TFactsFrame.Add(const Name, Value: string);
begin
  with Facts.Items.Add do
  begin
    Caption := Name;
    SubItems.Add(Value);
  end;
  { each column as wide as its longest text }
  ListView_SetColumnWidth(Facts.Handle, 0, LVSCW_AUTOSIZE);
  ListView_SetColumnWidth(Facts.Handle, 1, LVSCW_AUTOSIZE);
end;

end.
