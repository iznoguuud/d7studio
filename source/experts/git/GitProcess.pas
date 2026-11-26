{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitProcess;

{ git.exe run by the Git expert, its output captured - ..\kit\KitProcess.inc, shared with the
  other experts. }

interface

uses
  Windows, SysUtils, Classes;

{$DEFINE KIT_INTERFACE}
{$I ..\kit\KitProcess.inc}
{$UNDEF KIT_INTERFACE}

implementation

uses
  GitText;

{$I ..\kit\KitProcess.inc}

end.
