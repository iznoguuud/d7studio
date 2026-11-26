{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiProcess;

{ Console programs run by the AI harness (dcc32 of compile_project), their output captured -
  ..\kit\KitProcess.inc, shared with the other experts. }

interface

uses
  Windows, SysUtils, Classes;

{$DEFINE KIT_INTERFACE}
{$I ..\kit\KitProcess.inc}
{$UNDEF KIT_INTERFACE}

implementation

uses
  AiText;

{$I ..\kit\KitProcess.inc}

end.
