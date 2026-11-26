{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitText;

{ The Git expert's text helpers: UTF-8 and code pages, files with their encodings, lines -
  ..\kit\KitText.inc, shared with the other experts. }

interface

uses
  Windows, SysUtils, Classes;

{$DEFINE KIT_INTERFACE}
{$I ..\kit\KitText.inc}
{$UNDEF KIT_INTERFACE}

implementation

uses
  Registry;

{$I ..\kit\KitText.inc}

end.
