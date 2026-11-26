{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdResTextFrame;

{ D7 Studio - the editor of a text resource in its page of the file area (SdResPage): a manifest of the
  project's own, or data that is text, in D7 Studio's
  code editor (Scintilla with the Editor Options and the key mapping, undo, a manifest highlighted
  as XML); the resource's bytes are UTF-8 and the editor holds them as they are. Find (Ctrl+F)
  looks for a text, F3 for the next one. A manifest is checked as XML before it is saved (MSXML):
  one Windows cannot read keeps the program from starting ("the side-by-side configuration is
  incorrect"), so Save says what is wrong where and writes nothing.
  The edit commands (EditUndoCommand ... EditSelectAllCommand) have no keys of their own: the main form's Edit
  commands and their keys come to them through the page. Its zoom is the editors' (SdZoom.EditorZoom:
  one for every editor), with the zoom bar on the page bar. }

interface

uses
  Windows, SysUtils, Classes, Controls, Forms, StdCtrls, ExtCtrls, ActnList,
  ComCtrls, SdSciEdit, SdResPage, SdZoom;

type
  TResTextFrame = class(TFrame, ISdResEditor, ISdZoomView)
    TopPanel: TPanel;
    lblFind: TLabel;
    edFind: TEdit;
    TopBar: TToolBar;
    tbFindNext: TToolButton;
    EditorHost: TPanel;
    StatusPanel: TPanel;
    lblPos: TLabel;
    Actions: TActionList;
    aFind: TAction;
    aFindNext: TAction;
    EditUndoCommand: TAction;
    EditRedoCommand: TAction;
    EditCutCommand: TAction;
    EditCopyCommand: TAction;
    EditPasteCommand: TAction;
    EditDeleteCommand: TAction;
    EditSelectAllCommand: TAction;
    procedure aFindExecute(Sender: TObject);
    procedure aFindNextExecute(Sender: TObject);
    procedure aFindNextUpdate(Sender: TObject);
    procedure EditExecute(Sender: TObject);
    procedure EditUpdate(Sender: TObject);
    procedure edFindKeyPress(Sender: TObject; var Key: Char);
  private
    FEditor: TSciEdit;
    FXml: Boolean;
    procedure EditorUpdateUI(Sender: TObject; Updated: Integer);
    procedure EditorZoomed(Sender: TObject);
    function GetZoomView: ISdZoomView;
  public
    { ISdZoomView: the editors' zoom }
    property ZoomView: ISdZoomView read GetZoomView implements ISdZoomView;
    constructor Create(AOwner: TComponent); override;
    { Data: the resource's UTF-8 bytes; Manifest: checked as XML before it is saved }
    procedure Load(const Data: string; Manifest: Boolean);
    function Data: string;
    { ISdResEditor }
    function EditorModified: Boolean;
    procedure EditorSaved;
    function EditorCheck(Show: Boolean): string;
    procedure EditorFocus;
    function EditorTestText: string;
    function EditorBar: TWinControl;
    function EditorStatus: TWinControl;
  end;

{ what is wrong with a manifest as XML ('' nothing; also when MSXML is not there to tell), and
  where: Line and Col count from 1 }
function ManifestError(const Utf8: string; out Line, Col: Integer): string;

implementation

uses
  Math, ComObj, Variants, SdUI, SdEncoding, SdIcons;

{$R *.dfm}

function ManifestError(const Utf8: string; out Line, Col: Integer): string;
var
  Doc, Err: OleVariant;
  Lost: Boolean;
begin
  Result := '';
  Line := 0;
  Col := 0;
  try
    Doc := CreateOleObject('Msxml2.DOMDocument.6.0');
  except
    try
      Doc := CreateOleObject('Msxml2.DOMDocument.3.0');
    except
      Exit;
    end;
  end;
  Doc.async := False;
  Doc.validateOnParse := False;
  Doc.resolveExternals := False;
  if not Doc.loadXML(ToWide(Utf8, CP_UTF8)) then
  begin
    Err := Doc.parseError;
    Line := Err.line;
    Col := Err.linepos;
    Result := Trim(FromWide(WideString(Err.reason), CP_ACP, Lost));
    if Result = '' then Result := 'The text is not XML.';
  end
  else if VarIsNull(Doc.documentElement) or VarIsEmpty(Doc.documentElement) or
    not SameText(FromWide(WideString(Doc.documentElement.nodeName), CP_ACP, Lost), 'assembly') then
    Result := 'A manifest is an <assembly> element (urn:schemas-microsoft-com:asm.v1).';
end;

constructor TResTextFrame.Create(AOwner: TComponent);
var
  W: TSciWindow;
begin
  inherited Create(AOwner);
  { the command icons first: UIPrepareFrame gives the bar its look and the disabled images }
  TopBar.Images := IconList;
  UIPrepareFrame(Self);
  W := TSciWindow.Create(Self);
  W.Borderless := True;                // the page around it has the frame (SdResPage)
  W.Align := alClient;
  W.Parent := EditorHost;
  FEditor := W.Edit;
  FEditor.OnUpdateUI := EditorUpdateUI;
  FEditor.OnZoom := EditorZoomed;        // the editors' zoom, as a file's editor takes it
end;

{ Scintilla zoomed the window by itself (EditorOptions.Zoom is its zoom now): every editor follows }
procedure TResTextFrame.EditorZoomed(Sender: TObject);
begin
  if Assigned(OnEditorZoom) then OnEditorZoom(Self);
end;

function TResTextFrame.GetZoomView: ISdZoomView;
begin
  Result := EditorZoom;
end;

{ after the frame has its parent: the editor's window comes with the text }
procedure TResTextFrame.Load(const Data: string; Manifest: Boolean);
begin
  FXml := Manifest;
  { the window first (LoadFromStringAs makes it), then its language: a manifest XML, other data
    plain text }
  FEditor.LoadFromStringAs(Data, MakeEncoding(CP_UTF8, False));
  if Manifest then FEditor.SetLanguage(slXml) else FEditor.SetLanguage(slNone);
  EditorUpdateUI(nil, 0);
end;

function TResTextFrame.Data: string;
begin
  Result := FEditor.GetText;
end;

procedure TResTextFrame.EditorUpdateUI(Sender: TObject; Updated: Integer);
begin
  lblPos.Caption := Format('%d: %d', [FEditor.CaretLine + 1, FEditor.CaretCol + 1]);
end;

procedure TResTextFrame.aFindExecute(Sender: TObject);
begin
  if FEditor.SelText <> '' then edFind.Text := FEditor.SelText;
  edFind.SetFocus;
  edFind.SelectAll;
end;

procedure TResTextFrame.aFindNextExecute(Sender: TObject);
begin
  if not FEditor.FindNext(edFind.Text, False, False, False, True, True) then
    MessageBox(EditorOwnerWnd(Self), PChar(Format('"%s" is not in the text.', [edFind.Text])), 'Find',
      MB_OK or MB_ICONINFORMATION)
  else if FEditor.CanFocus then
    FEditor.SetFocus;
end;

procedure TResTextFrame.aFindNextUpdate(Sender: TObject);
begin
  aFindNext.Enabled := edFind.Text <> '';
end;

{ Enter in the find box finds the next one }
procedure TResTextFrame.edFindKeyPress(Sender: TObject; var Key: Char);
begin
  if Key <> #13 then Exit;
  Key := #0;
  if aFindNext.Enabled then aFindNext.Execute;
end;

procedure TResTextFrame.EditExecute(Sender: TObject);
begin
  if Sender = EditUndoCommand then FEditor.Undo
  else if Sender = EditRedoCommand then FEditor.Redo
  else if Sender = EditCutCommand then FEditor.Cut
  else if Sender = EditCopyCommand then FEditor.Copy
  else if Sender = EditPasteCommand then FEditor.Paste
  else if Sender = EditDeleteCommand then FEditor.ReplaceSel('')
  else if Sender = EditSelectAllCommand then FEditor.SelectAll;
end;

{ the OnUpdate of each edit command: its own state only (the main form updates each command it
  shows through the page, and Execute updates a command before it runs) }
procedure TResTextFrame.EditUpdate(Sender: TObject);
var
  Enable: Boolean;
begin
  if Sender = EditUndoCommand then Enable := FEditor.CanUndo
  else if Sender = EditRedoCommand then Enable := FEditor.CanRedo
  else if (Sender = EditCutCommand) or (Sender = EditDeleteCommand) then
    Enable := (FEditor.SelEnd > FEditor.SelStart) and not FEditor.ReadOnly
  else if Sender = EditCopyCommand then Enable := FEditor.SelEnd > FEditor.SelStart
  else if Sender = EditPasteCommand then Enable := FEditor.CanPaste
  else Enable := True;
  TAction(Sender).Enabled := Enable;
end;

function TResTextFrame.EditorModified: Boolean;
begin
  Result := FEditor.Modified;
end;

procedure TResTextFrame.EditorSaved;
begin
  FEditor.SetSavePoint;
end;

{ a manifest that is no XML, or no assembly: what, and where (Show: the caret goes there) }
function TResTextFrame.EditorCheck(Show: Boolean): string;
var
  Line, Col: Integer;
begin
  Result := '';
  if not FXml then Exit;
  Result := ManifestError(FEditor.GetText, Line, Col);
  if (Result = '') or (Line <= 0) then Exit;
  if Show then FEditor.GotoLineCol(Line - 1, Max(Col - 1, 0));
  Result := Format('line %d, column %d: %s', [Line, Col, Result]);
end;

procedure TResTextFrame.EditorFocus;
begin
  if FEditor.CanFocus then FEditor.SetFocus;
end;

{ the strip with the find box and Find Next }
function TResTextFrame.EditorBar: TWinControl;
begin
  Result := TopPanel;
end;

function TResTextFrame.EditorStatus: TWinControl;
begin
  Result := StatusPanel;
end;

function TResTextFrame.EditorTestText: string;
var
  S: string;
begin
  S := Copy(FEditor.GetText, 1, 200);
  S := StringReplace(S, #13#10, '\n', [rfReplaceAll]);
  S := StringReplace(S, #10, '\n', [rfReplaceAll]);
  Result := Format('lines=%d|caret=%d:%d|modified=%d|xml=%d|find=%s|text=%s', [FEditor.LineCount,
    FEditor.CaretLine + 1, FEditor.CaretCol + 1, Ord(FEditor.Modified), Ord(FXml), edFind.Text, S]);
end;

end.
