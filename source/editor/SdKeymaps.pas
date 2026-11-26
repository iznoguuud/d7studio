{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdKeymaps;

{ D7 Studio - the key mappings of Editor Options | Key Mappings:
  Delphi 7's keymapping modules - Default, IDE Classic, BRIEF Emulation, Epsilon, Visual Studio
  Emulation, Visual Basic Emulation, New IDE Emacs - as tables of keystrokes and the editor
  commands they run. A keystroke is one key or a chord of two (Ctrl+K B: WordStar's chords take
  the second key with or without Ctrl, as Delphi does). The keys a table does not name keep their
  meaning: the menus' shortcuts and Scintilla's own keys. A table's keys come before the menus'
  shortcuts while the editor has the keyboard (Emacs' Ctrl+F moves on, it does not search). }

interface

uses
  Windows, SysUtils, Classes;

type
  TEdCmd = (ecNone,
    { the caret }
    ecCharLeft, ecCharRight, ecLineUp, ecLineDown, ecWordLeft, ecWordRight, ecLineStart, ecLineEnd,
    ecPageUp, ecPageDown, ecDocStart, ecDocEnd, ecWindowTop, ecWindowBottom, ecScrollUp, ecScrollDown,
    ecMatchBrace,
    { editing }
    ecDeleteChar, ecDeleteCharLeft, ecDeleteWordRight, ecDeleteWordLeft, ecDeleteLine, ecDeleteToLineEnd,
    ecDeleteToLineStart, ecCutLine, ecInsertLine, ecToggleInsert, ecUndo, ecRedo, ecCut, ecCopy, ecPaste,
    ecUpperCase, ecLowerCase, ecUpperWord, ecLowerWord,
    { the block (WordStar's, Persistent blocks) and the mark (BRIEF's, Emacs') }
    ecBlockBegin, ecBlockEnd, ecBlockLine, ecBlockWord, ecBlockCopy, ecBlockMove, ecBlockDelete,
    ecBlockHide, ecBlockIndent, ecBlockUnindent, ecBlockUpper, ecBlockLower, ecBlockGotoBegin,
    ecBlockGotoEnd, ecMarkToggle, ecSetMark, ecExchangeMark, ecKillLine, ecCancel,
    { the page's }
    ecSetBookmark, ecGotoBookmark,
    { the IDE's (its menu commands) }
    ecBlockRead, ecBlockWrite, ecBlockPrint, ecFind, ecReplace, ecSearchAgain, ecIncSearch, ecGotoLine,
    ecSave, ecSaveAll, ecOpen, ecClose, ecWindowList, ecNextWindow, ecExit, ecFindDecl, ecCompletion,
    { folding (the editor's) }
    ecFoldAll, ecUnfoldAll, ecFold, ecUnfold, ecFoldToggle, ecFoldMethods);

  TKeyBinding = record
    Key1, Key2: TShortCut;          // Key2 0: one key
    Cmd: TEdCmd;
    Arg: Integer;
  end;
  TKeyBindings = array of TKeyBinding;

  TKeymapResult = (kmNone, kmPrefix, kmCommand, kmCancel);

const
  KeymapNames: array[0..6] of string = ('Default', 'IDE Classic', 'BRIEF Emulation', 'Epsilon',
    'Visual Studio Emulation', 'Visual Basic Emulation', 'New IDE Emacs');

{ the bindings of a keymapping by its name (unknown: the Default's), parsed once }
function Keymap(const Name: string): TKeyBindings;
{ a key in the editor (Prefix: the first key of a chord being typed, 0 none; it is kept up to
  date): kmNone - not the map's, the key goes on; kmPrefix - a chord began, the key is eaten;
  kmCommand - Cmd / Arg run; kmCancel - a chord that names nothing (eaten) }
function KeymapLookup(const Map: TKeyBindings; var Prefix: TShortCut; Key: TShortCut;
  out Cmd: TEdCmd; out Arg: Integer): TKeymapResult;
{ "Ctrl+K B" -> the two shortcuts; False when a key has no name }
function ParseKeys(const Text: string; out Key1, Key2: TShortCut): Boolean;
{ an editor command by its name in the tables ('DeleteLine', 'LineEnd' ...; case-insensitive) }
function EdCmdByName(const Name: string; out Cmd: TEdCmd): Boolean;

implementation

const
  CmdNames: array[TEdCmd] of string = ('',
    'CharLeft', 'CharRight', 'LineUp', 'LineDown', 'WordLeft', 'WordRight', 'LineStart', 'LineEnd',
    'PageUp', 'PageDown', 'DocStart', 'DocEnd', 'WindowTop', 'WindowBottom', 'ScrollUp', 'ScrollDown',
    'MatchBrace',
    'DeleteChar', 'DeleteCharLeft', 'DeleteWordRight', 'DeleteWordLeft', 'DeleteLine', 'DeleteToLineEnd',
    'DeleteToLineStart', 'CutLine', 'InsertLine', 'ToggleInsert', 'Undo', 'Redo', 'Cut', 'Copy', 'Paste',
    'UpperCase', 'LowerCase', 'UpperWord', 'LowerWord',
    'BlockBegin', 'BlockEnd', 'BlockLine', 'BlockWord', 'BlockCopy', 'BlockMove', 'BlockDelete',
    'BlockHide', 'BlockIndent', 'BlockUnindent', 'BlockUpper', 'BlockLower', 'BlockGotoBegin',
    'BlockGotoEnd', 'MarkToggle', 'SetMark', 'ExchangeMark', 'KillLine', 'Cancel',
    'SetBookmark', 'GotoBookmark',
    'BlockRead', 'BlockWrite', 'BlockPrint', 'Find', 'Replace', 'SearchAgain', 'IncSearch', 'GotoLine',
    'Save', 'SaveAll', 'Open', 'Close', 'WindowList', 'NextWindow', 'Exit', 'FindDecl', 'Completion',
    'FoldAll', 'UnfoldAll', 'Fold', 'Unfold', 'FoldToggle', 'FoldMethods');

  { the folding chords of every keymapping: RAD Studio's Shift+Ctrl+K A / E / U / T / M, and
    Shift+Ctrl+K F for Fold All }
  FoldMap: array[0..5] of string = (
    'Shift+Ctrl+K A=UnfoldAll', 'Shift+Ctrl+K E=Fold', 'Shift+Ctrl+K U=Unfold',
    'Shift+Ctrl+K T=FoldToggle', 'Shift+Ctrl+K M=FoldMethods', 'Shift+Ctrl+K F=FoldAll');

  { Delphi 7's Default keymapping: what its editor has besides the menus' shortcuts - the
    WordStar block chords, the bookmarks by chord, Ctrl+Y, Ctrl+T and Ctrl+N (its LookupKeyBinding finds
    Ctrl+N: measured) }
  DefaultMap: array[0..41] of string = (
    'Ctrl+Y=DeleteLine', 'Shift+Ctrl+Y=DeleteToLineEnd', 'Ctrl+T=DeleteWordRight', 'Ctrl+BkSp=DeleteWordLeft',
    'Ctrl+N=InsertLine',
    'Ctrl+K B=BlockBegin', 'Ctrl+K K=BlockEnd', 'Ctrl+K L=BlockLine', 'Ctrl+K T=BlockWord',
    'Ctrl+K C=BlockCopy', 'Ctrl+K V=BlockMove', 'Ctrl+K Y=BlockDelete', 'Ctrl+K H=BlockHide',
    'Ctrl+K I=BlockIndent', 'Ctrl+K U=BlockUnindent', 'Ctrl+K N=BlockUpper', 'Ctrl+K O=BlockLower',
    'Ctrl+K E=LowerWord', 'Ctrl+K F=UpperWord', 'Ctrl+K R=BlockRead', 'Ctrl+K W=BlockWrite',
    'Ctrl+K P=BlockPrint', 'Shift+Ctrl+I=BlockIndent', 'Shift+Ctrl+U=BlockUnindent',
    'Ctrl+Q B=BlockGotoBegin', 'Ctrl+Q K=BlockGotoEnd', 'Ctrl+Q F=Find', 'Ctrl+Q A=Replace',
    'Ctrl+L=SearchAgain', 'Ctrl+Q Y=DeleteToLineEnd', 'Ctrl+Q [=MatchBrace', 'Ctrl+Q ]=MatchBrace',
    'Alt+[=MatchBrace', 'Alt+]=MatchBrace', 'Ctrl+Q S=LineStart', 'Ctrl+Q D=LineEnd',
    'Ctrl+Q R=DocStart', 'Ctrl+Q C=DocEnd', 'Ctrl+Q E=WindowTop', 'Ctrl+Q X=WindowBottom',
    'Ctrl+K 0=SetBookmark:*', 'Ctrl+Q 0=GotoBookmark:*');

  { IDE Classic: the Default's and WordStar's cursor diamond (Ctrl+C/X/V are no clipboard keys
    there: Ctrl+Ins, Shift+Del and Shift+Ins are) }
  ClassicMap: array[0..17] of string = (
    'Ctrl+E=LineUp', 'Ctrl+X=LineDown', 'Ctrl+S=CharLeft', 'Ctrl+D=CharRight', 'Ctrl+A=WordLeft',
    'Ctrl+F=WordRight', 'Ctrl+R=PageUp', 'Ctrl+C=PageDown', 'Ctrl+W=ScrollUp', 'Ctrl+Z=ScrollDown',
    'Ctrl+G=DeleteChar', 'Ctrl+H=DeleteCharLeft', 'Ctrl+V=ToggleInsert', 'Ctrl+N=InsertLine',
    'Ctrl+Ins=Copy', 'Shift+Del=Cut', 'Shift+Ins=Paste', 'Ctrl+Q H=DeleteToLineStart');

  { BRIEF: marking with Alt+M / Alt+L, the keypad's + and - copy and cut, Ins pastes }
  BriefMap: array[0..33] of string = (
    'Alt+M=MarkToggle', 'Alt+A=MarkToggle', 'Alt+L=BlockLine', 'Num+=Copy', 'Num-=Cut', 'Ins=Paste',
    'Alt+D=DeleteLine', 'Alt+K=DeleteToLineEnd', 'Ctrl+BkSp=DeleteWordLeft', 'Alt+BkSp=DeleteWordRight',
    'Alt+U=Undo', 'Ctrl+U=Redo', 'Alt+I=ToggleInsert', 'Alt+G=GotoLine', 'Alt+S=Find', 'F5=Find',
    'Alt+T=Replace', 'F6=Replace', 'Shift+F5=SearchAgain', 'Alt+B=WindowList', 'Alt+N=NextWindow',
    'Alt+E=Open', 'Alt+W=Save', 'Alt+X=Exit', 'Alt+0=SetBookmark:*', 'Ctrl+PgUp=DocStart',
    'Ctrl+PgDn=DocEnd', 'Ctrl+Home=WindowTop', 'Ctrl+End=WindowBottom', 'Ctrl+D=ScrollDown',
    'Ctrl+E=ScrollUp', 'Alt+R=BlockRead', 'Alt+P=BlockPrint', 'Ctrl+]=MatchBrace');

  { Epsilon and New IDE Emacs: Emacs' keys }
  EmacsMap: array[0..40] of string = (
    'Ctrl+F=CharRight', 'Ctrl+B=CharLeft', 'Ctrl+N=LineDown', 'Ctrl+P=LineUp', 'Ctrl+A=LineStart',
    'Ctrl+E=LineEnd', 'Alt+F=WordRight', 'Alt+B=WordLeft', 'Ctrl+V=PageDown', 'Alt+V=PageUp',
    'Shift+Alt+,=DocStart', 'Shift+Alt+.=DocEnd', 'Ctrl+D=DeleteChar', 'Alt+D=DeleteWordRight',
    'Alt+BkSp=DeleteWordLeft', 'Ctrl+K=KillLine', 'Ctrl+Y=Paste', 'Ctrl+W=Cut', 'Alt+W=Copy',
    'Ctrl+Space=SetMark', 'Ctrl+X Ctrl+X=ExchangeMark', 'Ctrl+G=Cancel', 'Ctrl+S=IncSearch',
    'Ctrl+R=IncSearch', 'Shift+Alt+5=Replace', 'Ctrl+X Ctrl+S=Save', 'Ctrl+X S=SaveAll',
    'Ctrl+X Ctrl+F=Open', 'Ctrl+X K=Close', 'Ctrl+X B=WindowList', 'Ctrl+X O=NextWindow',
    'Ctrl+X Ctrl+C=Exit', 'Ctrl+X U=Undo', 'Shift+Ctrl+-=Undo', 'Alt+G=GotoLine', 'Alt+U=UpperWord',
    'Alt+L=LowerWord', 'Alt+.=FindDecl', 'Ctrl+X I=BlockRead', 'Ctrl+X H=BlockLine', 'Alt+/=Completion');

  { Visual Studio: line commands, case, its find keys }
  VisualStudioMap: array[0..12] of string = (
    'Ctrl+L=CutLine', 'Shift+Ctrl+L=DeleteLine', 'Shift+Ctrl+U=UpperCase', 'Ctrl+U=LowerCase',
    'Ctrl+Y=Redo', 'Ctrl+F=Find', 'Ctrl+H=Replace', 'F3=SearchAgain', 'Ctrl+G=GotoLine',
    'Ctrl+I=IncSearch', 'Ctrl+]=MatchBrace', 'Ctrl+K Ctrl+K=SetBookmark:0', 'Ctrl+K Ctrl+N=GotoBookmark:0');

  { Visual Basic: its find keys, Ctrl+Y cuts the line }
  VisualBasicMap: array[0..6] of string = (
    'Ctrl+Y=CutLine', 'Ctrl+F=Find', 'Ctrl+H=Replace', 'F3=SearchAgain', 'Shift+F2=FindDecl',
    'Ctrl+Space=Completion', 'Ctrl+Z=Undo');

  { the chords whose second key is also taken with the first key's modifiers still held
    (WordStar's take it with or without Ctrl) }
  HeldPrefixes = 'Ctrl+K Ctrl+Q Ctrl+O Shift+Ctrl+K';

type
  TParsedMap = class
    Name: string;
    Bindings: TKeyBindings;
  end;

var
  Parsed: TList;

{ one key: modifiers, then a letter, a digit, F1..F12, a named key or a character of the keyboard }
function ParseKey(const Text: string; out Key: TShortCut): Boolean;
const
  Names: array[0..17] of string = ('Space', 'Enter', 'Tab', 'Esc', 'BkSp', 'Ins', 'Del', 'Home',
    'End', 'PgUp', 'PgDn', 'Left', 'Right', 'Up', 'Down', 'Num+', 'Num-', 'Num*');
  Keys: array[0..17] of Word = (VK_SPACE, VK_RETURN, VK_TAB, VK_ESCAPE, VK_BACK, VK_INSERT,
    VK_DELETE, VK_HOME, VK_END, VK_PRIOR, VK_NEXT, VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN, VK_ADD,
    VK_SUBTRACT, VK_MULTIPLY);
var
  S, K: string;
  Mods: TShortCut;
  I: Integer;
  V: SHORT;
begin
  Result := False;
  Key := 0;
  S := Text;
  Mods := 0;
  repeat
    if SameText(Copy(S, 1, 5), 'Ctrl+') and (Length(S) > 5) then begin Mods := Mods or scCtrl; Delete(S, 1, 5); end
    else if SameText(Copy(S, 1, 6), 'Shift+') and (Length(S) > 6) then begin Mods := Mods or scShift; Delete(S, 1, 6); end
    else if SameText(Copy(S, 1, 4), 'Alt+') and (Length(S) > 4) then begin Mods := Mods or scAlt; Delete(S, 1, 4); end
    else Break;
  until False;
  K := S;
  if K = '' then Exit;
  for I := 0 to High(Names) do
    if SameText(K, Names[I]) then
    begin
      Key := Keys[I] or Mods;
      Result := True;
      Exit;
    end;
  if (Length(K) >= 2) and (UpCase(K[1]) = 'F') and (StrToIntDef(Copy(K, 2, 2), 0) in [1..12]) then
  begin
    Key := (VK_F1 + StrToInt(Copy(K, 2, 2)) - 1) or Mods;
    Result := True;
    Exit;
  end;
  if Length(K) <> 1 then Exit;
  if K[1] in ['A'..'Z', 'a'..'z', '0'..'9'] then
  begin
    Key := Ord(UpCase(K[1])) or Mods;
    Result := True;
    Exit;
  end;
  { a character of the keyboard: its key there (the layout's), Shift as the layout needs it }
  V := VkKeyScan(K[1]);
  if V = -1 then Exit;
  Key := Word(V and $FF) or Mods;
  if V and $100 <> 0 then Key := Key or scShift;
  Result := True;
end;

function ParseKeys(const Text: string; out Key1, Key2: TShortCut): Boolean;
var
  P: Integer;
begin
  Key2 := 0;
  P := Pos(' ', Text);
  if P = 0 then Result := ParseKey(Text, Key1)
  else Result := ParseKey(Copy(Text, 1, P - 1), Key1) and ParseKey(Trim(Copy(Text, P + 1, MaxInt)), Key2);
end;

function EdCmdByName(const Name: string; out Cmd: TEdCmd): Boolean;
var
  C: TEdCmd;
begin
  Result := False;
  Cmd := ecNone;
  for C := Succ(Low(TEdCmd)) to High(TEdCmd) do
    if SameText(CmdNames[C], Name) then
    begin
      Cmd := C;
      Result := True;
      Exit;
    end;
end;

procedure AddTable(var B: TKeyBindings; const Table: array of string);
var
  I, N, K, ArgFrom, ArgTo, A: Integer;
  Keys, Cmd, Arg, First: string;
  Key1, Key2: TShortCut;
  Found: TEdCmd;

  procedure Add(K1, K2: TShortCut; Arg: Integer);
  begin
    N := Length(B);
    SetLength(B, N + 1);
    B[N].Key1 := K1;
    B[N].Key2 := K2;
    B[N].Cmd := Found;
    B[N].Arg := Arg;
  end;

begin
  for I := 0 to High(Table) do
  begin
    K := Pos('=', Table[I]);
    if K = 0 then Continue;
    Keys := Copy(Table[I], 1, K - 1);
    Cmd := Copy(Table[I], K + 1, MaxInt);
    Arg := '';
    if Pos(':', Cmd) > 0 then
    begin
      Arg := Copy(Cmd, Pos(':', Cmd) + 1, MaxInt);
      Cmd := Copy(Cmd, 1, Pos(':', Cmd) - 1);
    end;
    if not EdCmdByName(Cmd, Found) then Continue;
    { "0=...:*": the ten keys 0..9, each with its digit }
    if Arg = '*' then
    begin
      ArgFrom := 0;
      ArgTo := 9;
    end
    else
    begin
      ArgFrom := StrToIntDef(Arg, 0);
      ArgTo := ArgFrom;
    end;
    for A := ArgFrom to ArgTo do
    begin
      if Arg = '*' then Keys := Copy(Keys, 1, Length(Keys) - 1) + IntToStr(A);
      if not ParseKeys(Keys, Key1, Key2) then Continue;
      Add(Key1, Key2, A);
      { WordStar's chords: the second key with Ctrl as well; Shift+Ctrl+K's also with Shift+Ctrl }
      First := Copy(Keys, 1, Pos(' ', Keys + ' ') - 1);
      if (Key2 <> 0) and (Pos(' ' + LowerCase(First) + ' ', ' ' + LowerCase(HeldPrefixes) + ' ') > 0) then
      begin
        if Key2 and scCtrl = 0 then Add(Key1, Key2 or scCtrl, A);
        if (Key1 and scShift <> 0) and (Key2 and (scCtrl or scShift) = 0) then Add(Key1, Key2 or scCtrl or scShift, A);
      end;
    end;
  end;
end;

function Keymap(const Name: string): TKeyBindings;
var
  I: Integer;
  M: TParsedMap;
  B: TKeyBindings;
begin
  for I := 0 to Parsed.Count - 1 do
    if SameText(TParsedMap(Parsed[I]).Name, Name) then
    begin
      Result := TParsedMap(Parsed[I]).Bindings;
      Exit;
    end;
  SetLength(B, 0);
  if SameText(Name, 'IDE Classic') then
  begin
    AddTable(B, ClassicMap);
    AddTable(B, DefaultMap);
  end
  else if SameText(Name, 'BRIEF Emulation') then AddTable(B, BriefMap)
  else if SameText(Name, 'Epsilon') or SameText(Name, 'New IDE Emacs') then AddTable(B, EmacsMap)
  else if SameText(Name, 'Visual Studio Emulation') then AddTable(B, VisualStudioMap)
  else if SameText(Name, 'Visual Basic Emulation') then AddTable(B, VisualBasicMap)
  else AddTable(B, DefaultMap);
  AddTable(B, FoldMap);
  M := TParsedMap.Create;
  M.Name := Name;
  M.Bindings := B;
  Parsed.Add(M);
  Result := B;
end;

function KeymapLookup(const Map: TKeyBindings; var Prefix: TShortCut; Key: TShortCut;
  out Cmd: TEdCmd; out Arg: Integer): TKeymapResult;
var
  I: Integer;
begin
  Cmd := ecNone;
  Arg := 0;
  if Prefix <> 0 then
  begin
    Result := kmCancel;
    for I := 0 to High(Map) do
      if (Map[I].Key1 = Prefix) and (Map[I].Key2 = Key) then
      begin
        Cmd := Map[I].Cmd;
        Arg := Map[I].Arg;
        Result := kmCommand;
        Break;
      end;
    Prefix := 0;
    Exit;
  end;
  Result := kmNone;
  for I := 0 to High(Map) do
    if Map[I].Key1 = Key then
      if Map[I].Key2 = 0 then
      begin
        Cmd := Map[I].Cmd;
        Arg := Map[I].Arg;
        Result := kmCommand;
        Exit;
      end
      else
        Result := kmPrefix;
  if Result = kmPrefix then Prefix := Key;
end;

procedure FreeParsed;
var
  I: Integer;
begin
  for I := 0 to Parsed.Count - 1 do TParsedMap(Parsed[I]).Free;
  Parsed.Free;
end;

initialization
  Parsed := TList.Create;

finalization
  FreeParsed;

end.
