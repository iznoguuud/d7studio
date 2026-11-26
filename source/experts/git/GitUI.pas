{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit GitUI;

{ The look of the Git expert's views, after D7 Studio's: flat frames and tool bars, the IDE's fonts,
  the icon font's glyphs and Visual Studio's images, the view's status line, diff lines -
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
  IniFiles, ToolsAPI, GitText;

{$I ..\kit\KitUI.inc}

end.
