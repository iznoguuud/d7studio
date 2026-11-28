{**********************************************************}
{                                                          }
{     Delphi 7 Visual Component Library                    }
{     Modernization: manifest with UTF-8 code page         }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit ModernManUtf8;

{ Everything ModernMan does, plus <activeCodePage>UTF-8</activeCodePage>
  (Windows 10 1903 and later; older Windows ignore it and keep the legacy code
  page). With it every AnsiString holds UTF-8 and the whole VCL handles any
  Unicode text: display, editing, keyboard and IME input, clipboard, file names,
  sorting and locale data (see the Utf8Mode unit).

  Migration notes:
    - Forms designed in the Delphi 7 IDE store their strings in the designer's
      code page; they are converted while loading (Utf8Mode.DfmCodePage,
      default = the system's legacy code page, e.g. 1252 or 1253).
    - String literals in source files are compiled as raw bytes of the file's
      code page. Literals with non-ASCII characters must either move to a
      resourcestring section (stored as UTF-16 by the compiler, converted
      correctly), be converted at run time with Utf8Mode.LegacyToAnsi, or the
      source file must be saved as UTF-8 (without BOM).
    - Text files without BOM that are not valid UTF-8 are read as legacy ANSI
      by TStrings.LoadFromFile (Utf8Mode.LegacyTextCodePage). Files are written
      as UTF-8.

  Use either ModernMan or ModernManUtf8, never both, and not together with
  XPMan, VistaMan or the IDE's manifest expert. }

interface

implementation

{$R ModernManUtf8.res}

end.
