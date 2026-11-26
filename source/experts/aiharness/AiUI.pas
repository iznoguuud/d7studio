{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiUI;

{ The look of the AI harness's windows, after D7 Studio's views: flat frames and tool bars, the
  IDE's fonts, Visual Studio's images, the view's status line, the transcript's rich text -
  ..\kit\KitUI.inc, shared with the other experts. }

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ComCtrls, ImgList, CommCtrl,
  RichEdit, Menus, ActnList;

{$DEFINE KIT_INTERFACE}
{$I ..\kit\KitUI.inc}
{$UNDEF KIT_INTERFACE}

implementation

uses
  IniFiles, ToolsAPI, AiText;

{$I ..\kit\KitUI.inc}

end.
