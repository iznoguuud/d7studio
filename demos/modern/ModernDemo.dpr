{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

program ModernDemo;

{ A tour of the modernized Delphi 7 RTL/VCL. Start reading in DemoMain.pas; README.md of this
  folder says what to try.

  ModernManUtf8, first in the uses clause, links the application manifest that turns the new
  features on: Windows' current look (Common Controls 6), per-monitor DPI awareness and UTF-8 as
  the program's code page. Nothing else is needed for them. }

uses
  ModernManUtf8,
  Forms,
  DemoMain in 'DemoMain.pas' {MainForm},
  DemoPanel in 'DemoPanel.pas' {PanelForm},
  DemoFacts in 'DemoFacts.pas' {FactsFrame: TFrame},
  DemoGauge in 'DemoGauge.pas',
  DemoIcons in 'DemoIcons.pas';

begin
  { one taskbar button, the main window's, as Windows 7 and later expect (Forms.MainFormOnTaskbar) }
  MainFormOnTaskbar := True;
  Application.Initialize;
  Application.Title := 'ModernDemo';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
