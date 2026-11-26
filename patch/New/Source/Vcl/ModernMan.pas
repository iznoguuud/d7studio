{**********************************************************}
{                                                          }
{     Delphi 7 Visual Component Library                    }
{     Modernization: application manifest                  }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit ModernMan;

{ Add this unit to the uses clause of the .dpr (instead of XPMan) to link a
  modern application manifest:

    - Common Controls 6 (visual styles, task dialogs, modern file dialogs)
    - supportedOS Windows Vista .. Windows 11 (no version lies or
      compatibility shims; Win32MajorVersion reports 10 on Windows 10/11)
    - Per-Monitor V2 DPI awareness with Per-Monitor fallback: the VCL scales
      every form for the DPI of its monitor (see Forms.PerMonitorDpiScaling)
    - long path awareness (Windows 10 1607+, when enabled by policy)
    - requestedExecutionLevel asInvoker

  Do not combine it with XPMan, VistaMan or the IDE's manifest expert: an
  executable can only have one manifest (the linker keeps the first one).

  ModernManUtf8 additionally switches the process code page to UTF-8. }

interface

implementation

{$R ModernMan.res}

end.
