{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdIcons;

{ D7 Studio - its icons: JetBrains' IntelliJ Platform icons (Apache License 2.0, see
  THIRD-PARTY-NOTICES.md) and D7 Studio's own drawings in their style, one per TSdIcon, made into two
  resources:
    ICONS      source\icons.bmp: every icon at 16 x 16, in the order of TSdIcon;
    ICONS32    source\icons32.bmp: the icons of LargeIcons at 32 x 32, in that order.
  Both are 32-bit bitmaps with straight alpha, bottom-up, one row of square cells. }

interface

uses
  Windows, SysUtils, Classes, Graphics, Controls, Buttons, CommCtrl;

type
  TSdIcon = (
    iiNone,
    { file / edit }
    iiNew, iiOpen, iiSave, iiSaveAll, iiOpenProject, iiAddFile, iiRemoveFile,
    iiUndo, iiRedo, iiCut, iiCopy, iiPaste, iiDelete, iiFind, iiReplace, iiPrint,
    iiProperties, iiHelp,
    { view }
    iiViewUnit, iiViewForm, iiToggle, iiNewForm, iiNewUnit, iiNewDataModule, iiNewFrame,
    iiViewProject,
    { run / debug }
    iiRun, iiPause, iiStop, iiTraceInto, iiStepOver, iiStepOut, iiRunToCursor,
    iiCompile, iiBuild, iiSyntaxCheck, iiToggleBreak, iiBreakpoint, iiWatch, iiEvaluate,
    { project tree }
    iiProject, iiUnit, iiForm, iiDataModule, iiFolder, iiFile,
    { code structure }
    iiClass, iiInterface, iiRecord, iiEnum, iiType, iiProcedure, iiFunction, iiProperty,
    iiField, iiVar, iiConst, iiUses,
    { component tree }
    iiControl, iiNonVisual, iiCollection, iiItem,
    { messages }
    iiError, iiWarning, iiHint,
    { gutter }
    iiExecArrow, iiCodeDot, iiBreakDisabled, iiBreakInvalid,
    iiBookmark0, iiBookmark1, iiBookmark2, iiBookmark3, iiBookmark4,
    iiBookmark5, iiBookmark6, iiBookmark7, iiBookmark8, iiBookmark9,
    { misc }
    iiArrow,
    { the commands of the menus and tool bars }
    iiNewOther, iiSaveProjectAs, iiSaveAs, iiCloseFile, iiCloseAll, iiExit, iiUseUnit,
    iiBringFront, iiSendBack, iiAlignDlg, iiSizeDlg, iiScaleDlg, iiTabOrder, iiCreationOrder,
    iiLockControls, iiAddToInterface, iiSearchAgain, iiIncSearch, iiGotoLine, iiFindError,
    iiBrowseSymbol, iiObjInspector, iiObjTreeView, iiTodoList, iiAlignPalette, iiBrowser,
    iiCodeExplorer, iiWindowList, iiBreakpointsView, iiCallStack, iiWatchesView, iiLocalVars,
    iiThreads, iiModules, iiEventLog, iiCPU, iiFPU, iiSaveDesktop, iiDebugDesktop,
    iiTypeLibrary, iiImportTypeLib, iiAddToRepository, iiViewSource, iiAddNewProject,
    iiAddExistingProject, iiProjectInfo, iiCompileAll, iiBuildAll, iiDeployOptions, iiDeploy,
    iiAttach, iiRunParams, iiRegisterCom, iiUnregisterCom, iiRunNoDebug, iiTraceToSource,
    iiShowExecPoint, iiDetach, iiInspect, iiSourceBP, iiAddressBP, iiDataBP, iiModuleBP,
    iiNewComponent, iiInstallComponent, iiImportAX, iiInstallPackages, iiEnvOptions,
    iiEditorOptions, iiDebuggerOptions, iiRepository, iiConfigTools, iiWinSDK, iiDelphiTools,
    iiDirect, iiNextWindow, iiFindInFiles,
    { the ten alignments of the designer's page bar }
    iiAlignLeft, iiAlignHCenter, iiAlignHWinCenter, iiAlignHSpace, iiAlignRight, iiAlignTop,
    iiAlignVCenter, iiAlignVWinCenter, iiAlignVSpace, iiAlignBottom,
    { View | Diagram: the Diagram tab of a Pascal page, and its tool bar }
    iiDiagram, iiZoomIn, iiZoomOut, iiZoomReset, iiExpandAll, iiCollapseAll,
    { Back / Forward at the end of the file tabs (the browse history) }
    iiBrowseBack, iiBrowseForward,
    { the Resources view (View | Resources) and its kinds of resource }
    iiResources, iiResBitmap, iiResIcon, iiResCursor, iiResStrings, iiResVersion, iiResManifest,
    iiResData,
    { the image editor of the Resources view: its tools and commands }
    iiDrawSelect, iiDrawLasso, iiDrawZoom, iiDrawPicker, iiDrawEraser, iiDrawFill, iiDrawPencil,
    iiDrawBrush, iiDrawAirbrush, iiDrawText, iiDrawLine, iiDrawRect, iiDrawRoundRect, iiDrawEllipse,
    iiDrawHotspot, iiFlipHorz, iiFlipVert, iiRotate, iiInvert, iiResize, iiColorDepth, iiGrid,
    iiPreview,
    { the Code Explorer's folders (a category) }
    iiExpFolder,
    { the Project Manager's tree: its kinds of node }
    iiPmGroup, iiPmProject, iiPmPackage, iiPmUnitForm, iiPmSource, iiPmFolder,
    { the zoom bar's Zoom to Fit; the Diagram tab's Reset (100 %, every box closed, the top) }
    iiZoomFit, iiDiagramReset,
    { View | History, the History tab's tool bar: the previous / next change, side by side, blanks
      ignored, a version against the one before it, Restore, Restore Change, a label }
    iiHistory, iiHistPrevChange, iiHistNextChange, iiHistSideBySide, iiHistIgnoreBlanks,
    iiHistComparePrev, iiHistRestore, iiHistRestoreChange, iiHistLabel,
    { a list's Move Up / Move Down buttons; an open and a closed row of Environment Options'
      Explorer categories }
    iiMoveUp, iiMoveDown, iiNodeExpanded, iiNodeCollapsed,
    { File | New | Other's kinds of item that have no icon above; the palette's Frames tool }
    iiFrameTool, iiConsole, iiLibrary, iiTextFile, iiThread, iiBatchFile,
    { File | New | Other's wizards of Delphi 7's own packages: Service, Service Application, Web Server
      Application, XML Data Binding, any other }
    iiService, iiServiceApp, iiWebServerApp, iiXmlBinding, iiWizard,
    { Edit | Align to Grid, also on the designer's page bar }
    iiAlignGrid,
    { Edit | Flip Children | Selected (All is iiFlipHorz) }
    iiFlipSelected,
    { Edit | Line: Upper, Lower and Toggle Case, Sort Lines, Surround With - also on the code view's
      page bar -; the button by the selection that opens its menu; Edit | Hide Non-Visual Components,
      also on the designer's page bar }
    iiUpperCase, iiLowerCase, iiToggleCase, iiSortLines, iiSurround, iiSelectionMenu, iiHideNonVisual);

const
  { the icons that also come at 32 x 32 (ICONS32, in this order): File | New | Other's items.
    The generator of ICONS32 reads this list. }
  LargeIcons: array[0..16] of TSdIcon = (iiProject, iiBatchFile, iiNonVisual, iiConsole,
    iiDataModule, iiLibrary, iiForm, iiFrameTool, iiPmPackage, iiTextFile, iiThread, iiUnit,
    iiService, iiServiceApp, iiWebServerApp, iiXmlBinding, iiWizard);

var
  IconList: TImageList;                       // every icon, 16 x 16, 32 bits

{ Makes List IconList - the main form's Icons, whose .dfm holds the icons in the order of TSdIcon
  (written by iconlist.dpr) - and gives it the images of ICONS with their alpha; without
  a list (test hosts) a list of its own is made. The indexes are fixed (IconIndex): the .dfm stores
  them as ImageIndex values, so new icons go at the end of TSdIcon. }
procedure InitIcons(List: TImageList = nil);
function IconIndex(Icon: TSdIcon): Integer;   // image index in IconList (-1 for iiNone)
{ the icon as a 16 x 16 bitmap over the colour Back (the caller frees it) }
function IconBitmap(Icon: TSdIcon; Back: TColor): TBitmap;
{ Button shows the icon, its soft edges over the button's face, and greyed as Visual Studio greys
  it while disabled (two glyphs) }
procedure IconButton(Button: TBitBtn; Icon: TSdIcon);
{ the icon centred in a Size x Size bitmap (Size >= 16) with a transparent colour: its soft edges
  over Ground, the colour it is shown on (a component's palette bitmap; the caller frees it) }
function IconTile(Icon: TSdIcon; Size: Integer; Ground: TColor): TBitmap;
function IconRGBA(Icon: TSdIcon): string;     // 16*16*4 bytes, R G B A, top-down
{ the images for disabled commands (SdUI.UIDisabledImages), greyed as Visual Studio greys them }
function DisabledIcons: HIMAGELIST;
{ an image after the command icons (an expert's, INTAServices.AddMasked): Bmp's 16 x 16 top left,
  MaskColor transparent (clNone: none); greyed for the disabled images too. The image's index in
  IconList (-1: no list). }
function AddExtraIcon(Bmp: TBitmap; MaskColor: TColor): Integer;
{ adds the 32 x 32 image of a LargeIcons icon to List (32 x 32, 32 bits): its index, -1 when the
  icon has none }
function AddLargeIcon(List: HIMAGELIST; Icon: TSdIcon): Integer;

implementation

uses
  SdUI;

type
  { the pixels of a strip of icons: B G R A (straight alpha) per pixel, Size * Size per icon,
    each icon top-down }
  TIconPixels = array of Cardinal;

const
  IconCount = Ord(High(TSdIcon));
  LargeSize = 32;
  TileKey = TColor($00FF00FF);          // IconTile's transparent colour

var
  Pixels: TIconPixels;             // ICONS
  PixelsTried: Boolean;
  LargePixels: TIconPixels;        // ICONS32
  LargeTried: Boolean;

{ Reads the strip ResName: Count cells of Size x Size. False when it is not linked in or does not
  have Count cells (an icon was added and the strip not made again). }
function LoadStrip(const ResName: string; Size, Count: Integer; var Pix: TIconPixels): Boolean;
var
  Res: HRSRC;
  Mem: HGLOBAL;
  P: PChar;
  Info: PBitmapInfoHeader;
  Bits: PCardinal;
  I, X, Y, Stride, Cell: Integer;
begin
  Result := False;
  Res := FindResource(HInstance, PChar(ResName), RT_RCDATA);
  if Res = 0 then Exit;
  Mem := LoadResource(HInstance, Res);
  P := LockResource(Mem);
  if (P = nil) or (SizeofResource(HInstance, Res) <= SizeOf(TBitmapFileHeader) + SizeOf(TBitmapInfoHeader)) then
    Exit;
  Info := PBitmapInfoHeader(P + SizeOf(TBitmapFileHeader));
  if (Info.biBitCount <> 32) or (Info.biCompression <> BI_RGB) or (Info.biHeight <> Size) or
    (Info.biWidth <> Size * Count) or
    (Integer(SizeofResource(HInstance, Res)) < Integer(PBitmapFileHeader(P).bfOffBits) + Size * Size * Count * 4) then
    Exit;
  Cell := Size * Size;
  SetLength(Pix, Cell * Count);
  Stride := Size * Count;
  for Y := 0 to Size - 1 do
  begin
    { bottom-up: the first row of the file is the cells' last }
    Bits := PCardinal(P + PBitmapFileHeader(P).bfOffBits + (Size - 1 - Y) * Stride * 4);
    for I := 0 to Count - 1 do
      for X := 0 to Size - 1 do
      begin
        Pix[I * Cell + Y * Size + X] := Bits^;
        Inc(Bits);
      end;
  end;
  Result := True;
end;

function NeedPixels: Boolean;
begin
  if not PixelsTried then
  begin
    PixelsTried := True;
    LoadStrip('ICONS', 16, IconCount, Pixels);
  end;
  Result := Pixels <> nil;
end;

{ the pixel of an icon (iiNone and a missing set: transparent) }
function IconPixel(Icon: TSdIcon; P: Integer): Cardinal;
begin
  if (Icon = iiNone) or not NeedPixels then Result := 0
  else Result := Pixels[(Ord(Icon) - 1) * 256 + P];
end;

{ a pixel over the colour Back (an RGB colour) }
function BlendPixel(P: Cardinal; Back: TColor): TColor;
var
  A: Cardinal;
begin
  A := P shr 24;
  Result := RGB(
    (((P shr 16) and $FF) * A + Cardinal(GetRValue(Back)) * (255 - A)) div 255,
    (((P shr 8) and $FF) * A + Cardinal(GetGValue(Back)) * (255 - A)) div 255,
    ((P and $FF) * A + Cardinal(GetBValue(Back)) * (255 - A)) div 255);
end;

{ an image list's flags (not declared in Delphi 7) }
const
  ILC_COLORMASK = $00FE;

var
  ListGetFlags: function(himl: HIMAGELIST): UINT; stdcall;
  ListSetFlags: function(himl: HIMAGELIST; Flags: UINT): BOOL; stdcall;

function NeedListFlags: Boolean;
var
  M: HMODULE;
begin
  if not Assigned(ListSetFlags) then
  begin
    M := GetModuleHandle(comctl32);
    if M <> 0 then
    begin
      @ListGetFlags := GetProcAddress(M, 'ImageList_GetFlags');
      @ListSetFlags := GetProcAddress(M, 'ImageList_SetFlags');
    end;
  end;
  Result := Assigned(ListGetFlags) and Assigned(ListSetFlags);
end;

{ images of a list as pixels: each drawn on black for its colours, and its mask for the alpha (an
  expert's images have no partial transparency) }
procedure ReadListPixels(List: HIMAGELIST; var Pix: TIconPixels; First, Count: Integer);
var
  DC: HDC;
  Col, Msk: HBITMAP;
  ColBits, MskBits: PCardinal;
  Old: HGDIOBJ;
  I, J: Integer;
  C: PCardinal;
  M: PCardinal;
begin
  SetLength(Pix, 256 * Count);
  DC := CreateCompatibleDC(0);
  Col := UICreateDib32(16, 16, ColBits);
  Msk := UICreateDib32(16, 16, MskBits);
  try
    for I := 0 to Count - 1 do
    begin
      Old := SelectObject(DC, Col);
      PatBlt(DC, 0, 0, 16, 16, BLACKNESS);
      ImageList_Draw(List, First + I, DC, 0, 0, ILD_NORMAL);
      SelectObject(DC, Msk);
      SetTextColor(DC, RGB(0, 0, 0));               // a mask's 0 bits: the image
      SetBkColor(DC, RGB(255, 255, 255));           // its 1 bits: transparent
      PatBlt(DC, 0, 0, 16, 16, WHITENESS);
      ImageList_Draw(List, First + I, DC, 0, 0, ILD_MASK);
      SelectObject(DC, Old);
      GdiFlush;
      C := ColBits;
      M := MskBits;
      for J := 0 to 255 do
      begin
        if M^ and $FFFFFF = 0 then Pix[I * 256 + J] := (C^ and $FFFFFF) or $FF000000
        else Pix[I * 256 + J] := 0;
        Inc(C);
        Inc(M);
      end;
    end;
  finally
    DeleteObject(Col);
    DeleteObject(Msk);
    DeleteDC(DC);
  end;
end;

{ the list List (32 bits, Size x Size) gets the Count images of Pix from the image First on after
  the ones it has: a strip with their alpha, and a mask (an alpha below one half is transparent)
  for whoever draws the mask alone }
procedure AppendPixels(List: HIMAGELIST; const Pix: TIconPixels; Size: Integer = 16; First: Integer = 0;
  Count: Integer = -1);
var
  Dib, Mask: HBITMAP;
  Bits, D: PCardinal;
  MaskBits: string;
  I, X, Y, RowBytes, Cell: Integer;
  P: Cardinal;
begin
  Cell := Size * Size;
  if Count < 0 then Count := Length(Pix) div Cell - First;
  if Count <= 0 then Exit;
  Dib := UICreateDib32(Size * Count, Size, Bits);
  RowBytes := ((Size * Count + 15) div 16) * 2;  // a monochrome bitmap's rows are words
  SetLength(MaskBits, RowBytes * Size);
  FillChar(MaskBits[1], Length(MaskBits), 0);
  D := Bits;
  for Y := 0 to Size - 1 do
    for I := 0 to Count - 1 do
      for X := 0 to Size - 1 do
      begin
        P := Pix[(First + I) * Cell + Y * Size + X];
        D^ := P;              // straight alpha: the image list multiplies by itself (measured)
        Inc(D);
        if P shr 24 < 128 then
          MaskBits[Y * RowBytes + (I * Size + X) div 8 + 1] :=
            Chr(Ord(MaskBits[Y * RowBytes + (I * Size + X) div 8 + 1]) or ($80 shr ((I * Size + X) mod 8)));
      end;
  Mask := CreateBitmap(Size * Count, Size, 1, 1, PChar(MaskBits));
  try
    ImageList_Add(List, Dib, Mask);
  finally
    DeleteObject(Dib);
    DeleteObject(Mask);
  end;
end;

var
  { images added after the command icons (the Open Tools API's INTAServices.AddMasked): kept as
    pixels, so that the disabled list ends with them too }
  ExtraPixels: TIconPixels;
  Disabled: HIMAGELIST;            // DisabledIcons, made when first asked

{ the images Pix (256 pixels each) after the ones added so far (ExtraPixels); a disabled list made
  already ends with them greyed (SdUI.UIGreyPixel) }
procedure KeepExtraPixels(const Pix: TIconPixels);
var
  N, I: Integer;
  Grey: TIconPixels;
begin
  if Length(Pix) = 0 then Exit;
  N := Length(ExtraPixels);
  SetLength(ExtraPixels, N + Length(Pix));
  Move(Pix[0], ExtraPixels[N], Length(Pix) * SizeOf(Cardinal));
  if Disabled = 0 then Exit;
  SetLength(Grey, Length(Pix));
  for I := 0 to High(Pix) do Grey[I] := UIGreyPixel(Pix[I]);
  AppendPixels(Disabled, Grey);
end;

{ The images an expert added to the list itself (INTAServices.ImageList.AddMasked ...), not through
  AddExtraIcon: taken into ExtraPixels in their places - the disabled list gets them, and the images
  added after them keep their indexes. }
procedure TakeDirectImages;
var
  Count, Known: Integer;
  Pix: TIconPixels;
begin
  if IconList = nil then Exit;
  Count := ImageList_GetImageCount(IconList.Handle);
  Known := IconCount + Length(ExtraPixels) div 256;
  if Count <= Known then Exit;
  ReadListPixels(IconList.Handle, Pix, Known, Count - Known);
  KeepExtraPixels(Pix);
end;

function AddExtraIcon(Bmp: TBitmap; MaskColor: TColor): Integer;
var
  Pix: TIconPixels;
  X, Y: Integer;
  C: TColor;
  Mask: TColor;
begin
  Result := -1;
  if (IconList = nil) or (Bmp = nil) or (Bmp.Width = 0) or (Bmp.Height = 0) then Exit;
  TakeDirectImages;
  SetLength(Pix, 256);
  Mask := ColorToRGB(MaskColor);
  for Y := 0 to 15 do
    for X := 0 to 15 do
    begin
      if (X < Bmp.Width) and (Y < Bmp.Height) then C := Bmp.Canvas.Pixels[X, Y] else C := Mask;
      if (MaskColor <> clNone) and (C = Mask) then Pix[Y * 16 + X] := 0
      else
        Pix[Y * 16 + X] := $FF000000 or Cardinal(GetRValue(C)) shl 16 or Cardinal(GetGValue(C)) shl 8 or
          Cardinal(GetBValue(C));
    end;
  KeepExtraPixels(Pix);                     // the disabled list, if made, ends with it too
  AppendPixels(IconList.Handle, Pix);
  Result := ImageList_GetImageCount(IconList.Handle) - 1;
end;

function DisabledIcons: HIMAGELIST;
var
  Pix: TIconPixels;
  I, N: Integer;
begin
  TakeDirectImages;
  if (Disabled = 0) and NeedPixels then
  begin
    N := Length(Pixels);
    SetLength(Pix, N + Length(ExtraPixels));
    for I := 0 to N - 1 do Pix[I] := UIGreyPixel(Pixels[I]);
    for I := 0 to High(ExtraPixels) do Pix[N + I] := UIGreyPixel(ExtraPixels[I]);
    Disabled := ImageList_Create(16, 16, ILC_COLOR32 or ILC_MASK, IconCount, 0);
    AppendPixels(Disabled, Pix);
  end;
  Result := Disabled;
end;

function IconBitmap(Icon: TSdIcon; Back: TColor): TBitmap;
var
  X, Y: Integer;
begin
  Back := ColorToRGB(Back);
  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.Width := 16;
  Result.Height := 16;
  for Y := 0 to 15 do
    for X := 0 to 15 do
      Result.Canvas.Pixels[X, Y] := BlendPixel(IconPixel(Icon, Y * 16 + X), Back);
end;

{ a W x H bitmap in TileKey, its transparent colour }
function KeyBitmap(W, H: Integer): TBitmap;
begin
  Result := TBitmap.Create;
  Result.PixelFormat := pf24bit;
  Result.Width := W;
  Result.Height := H;
  Result.Canvas.Brush.Color := TileKey;
  Result.Canvas.FillRect(Rect(0, 0, W, H));
  Result.TransparentColor := TileKey;
  Result.Transparent := True;
end;

{ the icon's painted pixels into Bmp at (X0, Y0), over Ground (greyed: SdUI.UIGreyPixel) }
procedure PutIcon(Bmp: TBitmap; X0, Y0: Integer; Icon: TSdIcon; Ground: TColor; Grey: Boolean);
var
  X, Y: Integer;
  P: Cardinal;
begin
  Ground := ColorToRGB(Ground);
  for Y := 0 to 15 do
    for X := 0 to 15 do
    begin
      P := IconPixel(Icon, Y * 16 + X);
      if Grey then P := UIGreyPixel(P);
      if P shr 24 <> 0 then Bmp.Canvas.Pixels[X0 + X, Y0 + Y] := BlendPixel(P, Ground);
    end;
end;

function IconTile(Icon: TSdIcon; Size: Integer; Ground: TColor): TBitmap;
begin
  Result := KeyBitmap(Size, Size);
  PutIcon(Result, (Size - 16) div 2, (Size - 16) div 2, Icon, Ground, False);
end;

procedure IconButton(Button: TBitBtn; Icon: TSdIcon);
var
  Bmp: TBitmap;
begin
  { the glyphs side by side: up, disabled; the button takes the colour of the bottom left pixel,
    which no icon covers, as the transparent one }
  Bmp := KeyBitmap(32, 16);
  try
    PutIcon(Bmp, 0, 0, Icon, clBtnFace, False);
    PutIcon(Bmp, 16, 0, Icon, clBtnFace, True);
    Button.Glyph := Bmp;
    Button.NumGlyphs := 2;
  finally
    Bmp.Free;
  end;
end;

var
  RGBAImages: array[TSdIcon] of string;     // IconRGBA's, made when first asked

{ made once: every editor defines its markers with them at each change of its options
  (SdSciEdit's SetupMarkers) }
function IconRGBA(Icon: TSdIcon): string;
var
  P: Integer;
  V: Cardinal;
begin
  Result := RGBAImages[Icon];
  if Result <> '' then Exit;
  SetLength(Result, 16 * 16 * 4);
  { B G R A -> R G B A }
  for P := 0 to 255 do
  begin
    V := IconPixel(Icon, P);
    Result[P * 4 + 1] := Chr((V shr 16) and $FF);
    Result[P * 4 + 2] := Chr((V shr 8) and $FF);
    Result[P * 4 + 3] := Chr(V and $FF);
    Result[P * 4 + 4] := Chr(V shr 24);
  end;
  RGBAImages[Icon] := Result;
end;

function AddLargeIcon(List: HIMAGELIST; Icon: TSdIcon): Integer;
var
  I: Integer;
begin
  Result := -1;
  if not LargeTried then
  begin
    LargeTried := True;
    LoadStrip('ICONS32', LargeSize, Length(LargeIcons), LargePixels);
  end;
  if LargePixels = nil then Exit;
  for I := Low(LargeIcons) to High(LargeIcons) do
    if LargeIcons[I] = Icon then
    begin
      AppendPixels(List, LargePixels, LargeSize, I, 1);
      Result := ImageList_GetImageCount(List) - 1;
      Exit;
    end;
end;

var
  OwnsIconList: Boolean;     // IconList was made here (no list was handed over)

procedure InitIcons(List: TImageList);
begin
  if IconList <> nil then Exit;
  OwnsIconList := List = nil;
  if OwnsIconList then
  begin
    List := TImageList.Create(nil);
    List.Width := 16;
    List.Height := 16;
    List.Masked := True;
    List.BkColor := clNone;
  end;
  { The .dfm's images are for the form designers; the list gets ICONS's with their alpha, on
    its own handle made one of 32 bits (the controls that show it keep it) }
  if NeedPixels and (List.Width = 16) and (List.Height = 16) and NeedListFlags and
    ((ListGetFlags(List.Handle) and ILC_COLORMASK = ILC_COLOR32) or
     ListSetFlags(List.Handle, ILC_COLOR32 or ILC_MASK)) then
  begin
    ImageList_RemoveAll(List.Handle);
    AppendPixels(List.Handle, Pixels);
  end;
  IconList := List;
end;

function IconIndex(Icon: TSdIcon): Integer;
begin
  Result := Ord(Icon) - 1;
end;

initialization

finalization
  if OwnsIconList then FreeAndNil(IconList) else IconList := nil;
  if Disabled <> 0 then ImageList_Destroy(Disabled);

end.
