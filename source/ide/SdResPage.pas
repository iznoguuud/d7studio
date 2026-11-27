{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdResPage;

{ D7 Studio - a resource of a project open in the file area: a page
  beside the files' pages, with a file tab of its own, that holds the editor of its kind in a
  frame - the image editor (SdImageEditFrame: a bitmap, an icon, a cursor), the string table
  (SdStringTableFrame), a text (SdResTextFrame: a manifest of the project's own, data that is
  text) or the bytes (SdHexEditFrame: other data, and data or a manifest by Edit as Hex).

  Its edits stay in the page until it is saved: Save writes them into the project's .res through
  TSdResources (the Open Tools API's model of the file, written at once); a compile takes them as
  they are, without saving (ApplyTo a copy of the file's entries, OtaModules.ProjectResourceCopy).

  The editor's keys are its own while the keyboard is in the page: the main form gives them to
  IsShortCut before its menus and its actions. A frame's action lists become its form's as soon
  as it has a parent (TCustomFrame.SetParent), and the form would then dispatch the keys of every
  page - a hidden one's too, and over the code editor's: the page takes them back from the form
  (MakeFrame). Its buttons still run them: the lists stay as they are. }

interface

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, ActnList, SdUI, SdResources, SdPageBar, SdZoom;

type
  { what a page asks of its editor (the four frames implement it) }
  ISdResEditor = interface
    ['{3F6A9D21-5B7C-4E80-A1D4-9C2E6B8F0A57}']
    function EditorModified: Boolean;
    procedure EditorSaved;                       // written: not modified any more
    { what keeps the edits from being written ('' nothing); Show: the place is shown (the caret,
      the row) }
    function EditorCheck(Show: Boolean): string;
    procedure EditorFocus;
    function EditorTestText: string;             // the test instance's state dump
    { its tool bar (or the strip that holds it: it then takes the width the zoom bar leaves) - the
      page puts it on its page bar - and its status line at the bottom, which the page gives the
      look of every page's (UIPageStatus); nil: none }
    function EditorBar: TWinControl;
    function EditorStatus: TWinControl;
  end;

  TSdResEditorKind = (reImage, reStrings, reText, reHex);

  TSdResPage = class(TSdControl)
  private
    FProjectFile: string;
    FKey: string;                 // the item's (TSdResources.FindKey)
    FKind: TSdResKind;
    FTypeOrd: Integer;            // the resource's type and name: it is made again with them when
    FTypeName, FName: string;     // it is not in the file any more when the page is saved
    FLanguage: Integer;
    FTitle: string;               // "Icon MAINICON"
    FEditorKind: TSdResEditorKind;
    FFrame: TCustomFrame;
    FEditor: ISdResEditor;        // FFrame's (a component's interface: no reference counting)
    FPageBar: TSdPageBar;         // the page's tool bar: the zoom bar, then the editor's bar
    FTabMarked: Boolean;
    procedure TakeItem(It: TSdResItem);
    procedure MakeFrame(AClass: TComponentClass);
    procedure ArrangeBar(Zoom: TWinControl);
    procedure PaintGround(DC: HDC);
    procedure WMNCPaint(var Message: TWMNCPaint); message WM_NCPAINT;
  protected
    procedure EraseGround(DC: HDC); override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Paint; override;
  public
    destructor Destroy; override;
    { after the page has its parent: It's editor (Hex: its bytes, whatever it is) with its data
      from R }
    procedure Open(R: TSdResources; It: TSdResItem; Hex: Boolean);
    { the string table of a language that is not in the file yet: an empty one }
    procedure OpenStrings(R: TSdResources; Language: Integer);
    function Modified: Boolean;
    { what keeps the edits from being written ('' nothing); Show: the editor shows the place }
    function CheckSave(Show: Boolean): string;
    { the edits into R's entries - Saving: the project's own (a lifted selection is put down
      first), else a copy for a compile (taken as it lies); the key of the resource afterwards }
    function ApplyTo(R: TSdResources; Saving: Boolean): string;
    procedure Saved(const NewKey: string);       // Save wrote it: its key now
    procedure Renamed(It: TSdResItem);           // Properties gave it another name or language
    function TabCaption: string;                 // the title of its file tab
    function IsShortCut(var Message: TWMKey): Boolean;
    function HasFocus: Boolean;                  // the keyboard is in the page
    { the editor's command named as the main form's (EditUndoCommand, EditCopyCommand ...); nil: it has none, or an
      edit box has the keyboard - it takes the command as its own message }
    function EditAction(const Name: string): TCustomAction;
    function EditEnabled(const Name: string): Boolean;
    procedure FocusEditor;
    function EditorText: string;                 // the editor's state (test instance)
    { the page bar holds the zoom bar (the main form's, lent to the page shown:
      TMainForm.ArrangePageBar) when the editor zooms, then the editor's bar }
    procedure ArrangePageBar;
    property PageBar: TSdPageBar read FPageBar;
    function ZoomView: ISdZoomView;              // the editor's zoom (nil: it does not zoom)
    function ResFile: string;
    property ProjectFile: string read FProjectFile;
    property Key: string read FKey;
    property ResKind: TSdResKind read FKind;
    property EditorKind: TSdResEditorKind read FEditorKind;
    property Title: string read FTitle;
    property TabMarked: Boolean read FTabMarked write FTabMarked;
  end;

{ a resource as the IDE names it: "Icon MAINICON", "String Table Neutral" }
function ResourceTitle(It: TSdResItem): string;
{ the window a frame's message boxes belong to: its form's (the main window) }
function EditorOwnerWnd(Frame: TControl): HWND;

implementation

uses
  Graphics, StdCtrls, ComCtrls, SdResImage, SdEditorPage, SdImageEditFrame, SdStringTableFrame, SdResTextFrame,
  SdHexEditFrame;

type
  TFrameAccess = class(TCustomFrame);

function ResourceTitle(It: TSdResItem): string;
begin
  if It.Kind = rkStrings then Result := 'String Table ' + It.NameText
  else Result := It.TypeText + ' ' + It.NameText;
end;

function EditorOwnerWnd(Frame: TControl): HWND;
var
  F: TCustomForm;
begin
  F := GetParentForm(Frame);
  if F <> nil then Result := F.Handle else Result := Application.Handle;
end;

{ ---------------------------------------------------------------- TSdResPage }

{ resized with the centre and covered by its editor: no CS_HREDRAW / CS_VREDRAW (TSdControl);
  framed by the flat 1 px border, as the editor and the Diagram tab's view are
  }
procedure TSdResPage.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or WS_BORDER or WS_CLIPCHILDREN;
end;

procedure TSdResPage.WMNCPaint(var Message: TWMNCPaint);
begin
  inherited;
  UIPaintFrameBorder(Handle);
end;

{ The editor and the page bar cover the page, and the page clips them out: its own erase never
  shows. But a frame takes its ground from its parent (csParentBackground), and so does what lies
  on the frame with its parent's ground (a panel: DrawThemeParentBackground, WM_ERASEBKGND then
  WM_PRINTCLIENT): the page's ground, clWindow - not what a buffer held before (the main tool
  bar's buttons showed under the editor's). The page bar paints its own }
procedure TSdResPage.PaintGround(DC: HDC);
begin
  UIFill(DC, ClientRect, clWindow);
end;

procedure TSdResPage.EraseGround(DC: HDC);
begin
  PaintGround(DC);
end;

procedure TSdResPage.Paint;
begin
  PaintGround(Canvas.Handle);
end;

destructor TSdResPage.Destroy;
begin
  FEditor := nil;                 // before the frame goes with the page's components
  inherited Destroy;
end;

procedure TSdResPage.TakeItem(It: TSdResItem);
begin
  FKey := It.Key;
  FKind := It.Kind;
  FTypeOrd := It.TypeOrd;
  FTypeName := It.TypeName;
  FName := It.NameText;
  FLanguage := It.Language;
  FTitle := ResourceTitle(It);
end;

procedure TSdResPage.MakeFrame(AClass: TComponentClass);
var
  I: Integer;
begin
  FPageBar := TSdPageBar.Create(Self);
  FPageBar.Visible := False;
  FPageBar.Parent := Self;
  FPageBar.Align := alTop;
  FFrame := TCustomFrame(AClass.Create(Self));
  FFrame.Parent := Self;
  FFrame.Align := alClient;
  for I := 0 to FFrame.ComponentCount - 1 do
    if FFrame.Components[I] is TCustomActionList then
      TFrameAccess(FFrame).Notification(FFrame.Components[I], opRemove);
  UIReduceFlicker(FFrame);
  if not Supports(FFrame, ISdResEditor, FEditor) then Exit;
  { the editor's tool bar on the page bar at once (the zoom bar comes when the page is shown); the
    status line in the look of every page's }
  ArrangeBar(nil);
  if FEditor.EditorStatus <> nil then UIPageStatus(FEditor.EditorStatus);
end;

{ Zoom (nil: none), then the editor's bar }
procedure TSdResPage.ArrangeBar(Zoom: TWinControl);
var
  Bar, Stretch: TWinControl;
begin
  if FEditor = nil then Exit;
  Bar := FEditor.EditorBar;
  { a strip (a find box with its buttons) takes the width the zoom bar leaves; a tool bar is as
    wide as its buttons }
  if (Bar <> nil) and not (Bar is TToolBar) then Stretch := Bar else Stretch := nil;
  FPageBar.Arrange([Zoom, Bar], Stretch);
end;

procedure TSdResPage.ArrangePageBar;
var
  Zoom: TWinControl;
begin
  Zoom := nil;
  if (IDE <> nil) and (ZoomView <> nil) then Zoom := IDE.ZoomBar;
  ArrangeBar(Zoom);
end;

function TSdResPage.ZoomView: ISdZoomView;
begin
  if (FFrame = nil) or not Supports(FFrame, ISdZoomView, Result) then Result := nil;
end;

procedure TSdResPage.Open(R: TSdResources; It: TSdResItem; Hex: Boolean);
var
  Images: TList;
  Items: TSdStringItems;
  Data, Ext: string;
  I: Integer;
begin
  FProjectFile := R.ProjectFile;
  TakeItem(It);
  if Hex then FEditorKind := reHex
  else
    case It.Kind of
      rkBitmap, rkIcon, rkCursor: FEditorKind := reImage;
      rkStrings: FEditorKind := reStrings;
      rkManifest: FEditorKind := reText;
    else
      if IsTextData(R.Data(It)) then FEditorKind := reText else FEditorKind := reHex;
    end;
  case FEditorKind of
    reImage:
      begin
        MakeFrame(TImageEditFrame);
        Images := TList.Create;
        try
          if It.Kind = rkBitmap then Images.Add(R.ReadBitmap(It)) else R.ReadImages(It, Images);
          TImageEditFrame(FFrame).Load(ResImageKind(It.Kind), Images);
        finally
          for I := 0 to Images.Count - 1 do TObject(Images[I]).Free;
          Images.Free;
        end;
      end;
    reStrings:
      begin
        MakeFrame(TStringTableFrame);
        R.ReadStrings(It.Language, Items);
        TStringTableFrame(FFrame).Load(Items);
      end;
    reText:
      begin
        MakeFrame(TResTextFrame);
        TResTextFrame(FFrame).Load(R.Data(It), It.Kind = rkManifest);
      end;
  else
    MakeFrame(THexEditFrame);
    Data := R.ExportData(It, Ext);
    THexEditFrame(FFrame).Load(Data, It.NameText + Ext);
  end;
end;

procedure TSdResPage.OpenStrings(R: TSdResources; Language: Integer);
begin
  FProjectFile := R.ProjectFile;
  FKey := StringTableKey(Language);
  FKind := rkStrings;
  FTypeOrd := RT_STRING_ID;
  FLanguage := Language;
  FTitle := 'String Table ' + LanguageText(Language);
  FEditorKind := reStrings;
  MakeFrame(TStringTableFrame);
  TStringTableFrame(FFrame).Load(nil);
end;

function TSdResPage.Modified: Boolean;
begin
  Result := (FEditor <> nil) and FEditor.EditorModified;
end;

function TSdResPage.CheckSave(Show: Boolean): string;
begin
  if FEditor = nil then Result := '' else Result := FEditor.EditorCheck(Show);
end;

function TSdResPage.ApplyTo(R: TSdResources; Saving: Boolean): string;
var
  It: TSdResItem;
  Images: TList;
  I: Integer;
  Data: string;
begin
  Result := FKey;
  It := R.FindKey(FKey);
  case FEditorKind of
    reImage:
      begin
        Images := TList.Create;
        try
          TImageEditFrame(FFrame).GetImages(Images, Saving);
          if It <> nil then
          begin
            if FKind = rkBitmap then R.WriteBitmap(It, TSdImage(Images[0])) else R.WriteImages(It, Images);
          end
          else if FKind = rkBitmap then Result := R.AddBitmap(FName, TSdImage(Images[0]))
          else Result := R.AddImages(FKind, FName, Images);
        finally
          for I := 0 to Images.Count - 1 do TObject(Images[I]).Free;
          Images.Free;
        end;
      end;
    reStrings:
      begin
        Result := R.WriteStrings(FLanguage, TStringTableFrame(FFrame).Strings);
        if Result = '' then Result := FKey;      // no strings: no table, the page stays its language's
      end;
  else
    if FEditorKind = reText then Data := TResTextFrame(FFrame).Data else Data := THexEditFrame(FFrame).Data;
    if It <> nil then R.WriteData(It, Data)
    else Result := R.AddData(FTypeOrd, FTypeName, FName, Data);
  end;
end;

procedure TSdResPage.Saved(const NewKey: string);
begin
  FKey := NewKey;
  if FEditor <> nil then FEditor.EditorSaved;
end;

procedure TSdResPage.Renamed(It: TSdResItem);
begin
  TakeItem(It);
end;

function TSdResPage.TabCaption: string;
begin
  Result := FTitle;
end;

function TSdResPage.IsShortCut(var Message: TWMKey): Boolean;
var
  I: Integer;
begin
  Result := False;
  if FFrame = nil then Exit;
  for I := 0 to FFrame.ComponentCount - 1 do
    if (FFrame.Components[I] is TCustomActionList) and TCustomActionList(FFrame.Components[I]).IsShortCut(Message) then
    begin
      Result := True;
      Exit;
    end;
end;

function TSdResPage.HasFocus: Boolean;
var
  F: HWND;
begin
  F := GetFocus;
  Result := HandleAllocated and (F <> 0) and ((F = Handle) or IsChild(Handle, F));
end;

function TSdResPage.EditAction(const Name: string): TCustomAction;
var
  C: TComponent;
begin
  Result := nil;
  if (FFrame = nil) or (Screen.ActiveControl is TCustomEdit) then Exit;
  C := FFrame.FindComponent(Name);
  if C is TCustomAction then Result := TCustomAction(C);
end;

function TSdResPage.EditEnabled(const Name: string): Boolean;
var
  A: TCustomAction;
begin
  A := EditAction(Name);
  if A = nil then
    Result := Screen.ActiveControl is TCustomEdit
  else
  begin
    A.Update;
    Result := A.Enabled;
  end;
end;

procedure TSdResPage.FocusEditor;
begin
  if FEditor <> nil then FEditor.EditorFocus;
end;

function TSdResPage.EditorText: string;
begin
  if FEditor = nil then Result := '' else Result := FEditor.EditorTestText;
end;

function TSdResPage.ResFile: string;
begin
  Result := ChangeFileExt(FProjectFile, '.res');
end;

end.
