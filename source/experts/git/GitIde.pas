{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitIde;

{ The Git expert's access to the IDE: projects, open modules, editor buffers, the state of the code
  editor - ..\kit\KitIde.inc, shared with the other experts. Call it in the IDE's main thread. }

interface

uses
  Windows, SysUtils, Classes, Forms, ExtCtrls, ToolsAPI, GitText;

{$DEFINE KIT_INTERFACE}
{$I ..\kit\KitIde.inc}
{$UNDEF KIT_INTERFACE}

implementation

{$I ..\kit\KitIde.inc}

end.
