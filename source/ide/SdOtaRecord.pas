{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaRecord;

{ D7 Studio - keystroke macros of the Open Tools API: IOTARecord, as Delphi 7
  has it. The IDE's own macro - Edit | Record Macro and Play Macro,
  Shift+Ctrl+R and Shift+Ctrl+P - is one of them (SdOtaServices: the keyboard services record into
  them and play them).

  * A record is a list of items: a key - Delphi's key code: the key or the character in the low
    word, in the high word $80 a virtual key, $40 Shift, $20 Alt, $10 Ctrl, $08 an extended key; a
    code without $80 is a typed character - or a command by its name. Append of TShortCuts adds
    keys (ShortCutToKeyCode), of a string its characters (IsKeys) or one command, of a record its
    items - commands as commands (Delphi 7 appends them as characters).
  * WriteToStream / ReadFromStream: Delphi's format - 'TPOR', the items (1 and the key code as a
    32-bit number, 2, the name's length and the name), 0 at the end; ReadFromStream appends. A
    stream that ends early or is of another format raises "Invalid Key macro format"; a write that
    fails "Error writing key macro". Macros Delphi 7 saved load here, and Delphi loads these.
  * The keyboard services recognise their own records (ISdOtaRecord): an expert's own IOTARecord
    is ignored, as Delphi ignores one. }

interface

uses
  Windows, SysUtils, Classes, ActiveX, Menus, ToolsAPI;

const
  { the flags of a key code (its high word) }
  kcVirtual = $00800000;
  kcShift = $00400000;
  kcAlt = $00200000;
  kcCtrl = $00100000;
  kcExtended = $00080000;

type
  TSdMacroItem = record
    IsCommand: Boolean;
    Code: Integer;                   // a key: its key code
    Command: string;                 // a command: its name
  end;

  ISdOtaRecord = interface
    ['{6F1D2C83-4B7A-4E25-9C0B-3A8D5E7F1B42}']
    function RecordObject: TObject;
  end;

  TSdOtaRecord = class(TInterfacedObject, IOTARecord, ISdOtaRecord)
  private
    FItems: array of TSdMacroItem;
    FCount: Integer;
    FPosition: Integer;              // the item played next
    FName: string;
    FRecording, FPaused, FPlaying: Boolean;
    procedure AddItem(IsCommand: Boolean; Code: Integer; const Command: string);
    function GetItem(Index: Integer): TSdMacroItem;
  public
    function RecordObject: TObject;
    procedure AppendKey(Code: Integer);
    procedure AppendCommand(const Name: string);
    { IOTARecord }
    procedure Append(const Keys: array of TShortCut); overload;
    procedure Append(const CmdName: string; IsKeys: Boolean = True); overload;
    procedure Append(const ARecord: IOTARecord); overload;
    procedure Clear;
    function GetIsPaused: Boolean;
    function GetIsPlaying: Boolean;
    function GetIsRecording: Boolean;
    function GetName: string;
    procedure ReadFromStream(const Stream: IStream);
    procedure SetName(const Value: string);
    procedure WriteToStream(const Stream: IStream);
    property Count: Integer read FCount;
    property Items[Index: Integer]: TSdMacroItem read GetItem;
    property Position: Integer read FPosition write FPosition;
    property Recording: Boolean read FRecording write FRecording;
    property Paused: Boolean read FPaused write FPaused;
    property Playing: Boolean read FPlaying write FPlaying;
  end;

{ a key as Delphi's key code and back. Delphi's rules: a key that types a character without Ctrl
  and Alt is the character (a letter, a digit, the space, the punctuation of the US keys), Esc
  $1B, Ctrl+letter its control character; the others virtual keys (Enter $0080000D). Ctrl+H, I
  and M stay virtual keys: their control characters are those of Backspace, Tab and Enter, which
  a code of Delphi's means (KeyCodeToShortCut) }
function ShortCutToKeyCode(SC: TShortCut): Integer;
function KeyCodeToShortCut(Code: Integer): TShortCut;
{ R as D7 Studio's own record; nil: an expert's (or nil) }
function OwnRecord(const R: IOTARecord): TSdOtaRecord;

const
  SInvalidKeyMacro = 'Invalid Key macro format';
  SKeyMacroWrite = 'Error writing key macro';

implementation

const
  { the US keys of punctuation and their characters }
  OemKeys: array[0..10] of Byte = ($BA, $BB, $BC, $BD, $BE, $BF, $C0, $DB, $DC, $DD, $DE);
  OemChars: array[0..10] of Char = (';', '=', ',', '-', '.', '/', '`', '[', '\', ']', '''');

{ the keys of the navigation block: Delphi's extended flag }
function IsExtendedKey(Key: Word): Boolean;
begin
  Result := (Key >= VK_PRIOR) and (Key <= VK_DOWN) or (Key = VK_INSERT) or (Key = VK_DELETE);
end;

function ShortCutToKeyCode(SC: TShortCut): Integer;
var
  Key: Word;
  Shift, Ctrl, Alt: Boolean;
  I: Integer;
begin
  Key := SC and $FF;
  Shift := SC and scShift <> 0;
  Ctrl := SC and scCtrl <> 0;
  Alt := SC and scAlt <> 0;
  if not Ctrl and not Alt then
  begin
    Result := -1;
    if Key in [Ord('A')..Ord('Z')] then
    begin
      if Shift then Result := Key else Result := Key + 32;
    end
    else if (Key in [Ord('0')..Ord('9')]) and not Shift then Result := Key
    else if Key = VK_SPACE then Result := Ord(' ')
    else if (Key = VK_ESCAPE) and not Shift then Result := $1B
    else if not Shift then
      for I := Low(OemKeys) to High(OemKeys) do
        if OemKeys[I] = Key then Result := Ord(OemChars[I]);
    if Result >= 0 then Exit;
  end;
  if Ctrl and not Alt and (Key in [Ord('A')..Ord('Z')]) and not (Key in [Ord('H'), Ord('I'), Ord('M')]) then
  begin
    Result := Key and $3F;
    if Shift then Result := Result or kcShift;
    Exit;
  end;
  Result := kcVirtual or Key;
  if Shift then Result := Result or kcShift;
  if Ctrl then Result := Result or kcCtrl;
  if Alt then Result := Result or kcAlt;
  if IsExtendedKey(Key) then Result := Result or kcExtended;
end;

function KeyCodeToShortCut(Code: Integer): TShortCut;
var
  Key: Word;
  Shift: TShiftState;
  C: Char;
  V: SmallInt;
  I: Integer;
begin
  Shift := [];
  if Code and kcShift <> 0 then Include(Shift, ssShift);
  if Code and kcCtrl <> 0 then Include(Shift, ssCtrl);
  if Code and kcAlt <> 0 then Include(Shift, ssAlt);
  if Code and kcVirtual <> 0 then
  begin
    Result := ShortCut(Code and $FF, Shift);
    Exit;
  end;
  C := Char(Code and $FF);
  Key := 0;
  case C of
    'a'..'z': Key := Ord(UpCase(C));
    'A'..'Z':
      begin
        Key := Ord(C);
        Include(Shift, ssShift);
      end;
    '0'..'9': Key := Ord(C);
    ' ': Key := VK_SPACE;
    #27: Key := VK_ESCAPE;
    #8: Key := VK_BACK;
    #9: Key := VK_TAB;
    #13: Key := VK_RETURN;
    #1..#7, #10..#12, #14..#26:
      begin
        Key := Ord('A') + Ord(C) - 1;
        Include(Shift, ssCtrl);
      end;
  else
    for I := Low(OemChars) to High(OemChars) do
      if OemChars[I] = C then Key := OemKeys[I];
    if Key = 0 then
    begin
      { the key of the keyboard's layout that types it }
      V := VkKeyScan(C);
      if V <> -1 then
      begin
        Key := V and $FF;
        if V and $100 <> 0 then Include(Shift, ssShift);
        if V and $200 <> 0 then Include(Shift, ssCtrl);
        if V and $400 <> 0 then Include(Shift, ssAlt);
      end;
    end;
  end;
  Result := ShortCut(Key, Shift);
end;

function OwnRecord(const R: IOTARecord): TSdOtaRecord;
var
  X: ISdOtaRecord;
begin
  if Supports(R, ISdOtaRecord, X) then Result := TSdOtaRecord(X.RecordObject) else Result := nil;
end;

{ ---------------------------------------------------------------- TSdOtaRecord }

function TSdOtaRecord.RecordObject: TObject;
begin
  Result := Self;
end;

procedure TSdOtaRecord.AddItem(IsCommand: Boolean; Code: Integer; const Command: string);
begin
  if FCount = Length(FItems) then SetLength(FItems, FCount * 2 + 16);
  FItems[FCount].IsCommand := IsCommand;
  FItems[FCount].Code := Code;
  FItems[FCount].Command := Command;
  Inc(FCount);
end;

function TSdOtaRecord.GetItem(Index: Integer): TSdMacroItem;
begin
  Result := FItems[Index];
end;

procedure TSdOtaRecord.AppendKey(Code: Integer);
begin
  AddItem(False, Code, '');
end;

procedure TSdOtaRecord.AppendCommand(const Name: string);
begin
  AddItem(True, 0, Name);
end;

procedure TSdOtaRecord.Append(const Keys: array of TShortCut);
var
  I: Integer;
begin
  for I := Low(Keys) to High(Keys) do AppendKey(ShortCutToKeyCode(Keys[I]));
end;

procedure TSdOtaRecord.Append(const CmdName: string; IsKeys: Boolean);
var
  I: Integer;
begin
  if IsKeys then
    for I := 1 to Length(CmdName) do AppendKey(Ord(CmdName[I]))
  else
    AppendCommand(CmdName);
end;

procedure TSdOtaRecord.Append(const ARecord: IOTARecord);
var
  R: TSdOtaRecord;
  I, N: Integer;
begin
  R := OwnRecord(ARecord);
  if R = nil then Exit;
  N := R.FCount;                     // the record itself appended to itself: its items once
  for I := 0 to N - 1 do AddItem(R.FItems[I].IsCommand, R.FItems[I].Code, R.FItems[I].Command);
end;

procedure TSdOtaRecord.Clear;
begin
  FItems := nil;
  FCount := 0;
  FPosition := 0;
end;

function TSdOtaRecord.GetIsPaused: Boolean;
begin
  Result := FPaused;
end;

function TSdOtaRecord.GetIsPlaying: Boolean;
begin
  Result := FPlaying;
end;

function TSdOtaRecord.GetIsRecording: Boolean;
begin
  Result := FRecording;
end;

function TSdOtaRecord.GetName: string;
begin
  Result := FName;
end;

procedure TSdOtaRecord.SetName(const Value: string);
begin
  FName := Value;
end;

procedure TSdOtaRecord.ReadFromStream(const Stream: IStream);

  procedure Need(var Buf; Size: Integer);
  var
    N: Longint;
  begin
    N := 0;
    if (Stream = nil) or (Stream.Read(@Buf, Size, @N) <> S_OK) or (N <> Size) then
      raise Exception.Create(SInvalidKeyMacro);
  end;

var
  Sig: array[0..3] of Char;
  Tag: Byte;
  Code, Len: Integer;
  S: string;
begin
  Need(Sig, SizeOf(Sig));
  if (Sig[0] <> 'T') or (Sig[1] <> 'P') or (Sig[2] <> 'O') or (Sig[3] <> 'R') then
    raise Exception.Create(SInvalidKeyMacro);
  repeat
    Need(Tag, 1);
    case Tag of
      0: Break;
      1:
        begin
          Need(Code, SizeOf(Code));
          AppendKey(Code);
        end;
      2:
        begin
          Need(Len, SizeOf(Len));
          if (Len < 0) or (Len > $FFFF) then raise Exception.Create(SInvalidKeyMacro);
          SetLength(S, Len);
          if Len > 0 then Need(S[1], Len);
          AppendCommand(S);
        end;
    else
      raise Exception.Create(SInvalidKeyMacro);
    end;
  until False;
end;

procedure TSdOtaRecord.WriteToStream(const Stream: IStream);

  procedure Put(const Buf; Size: Integer);
  var
    N: Longint;
  begin
    N := 0;
    if (Stream = nil) or (Stream.Write(@Buf, Size, @N) <> S_OK) or (N <> Size) then
      raise Exception.Create(SKeyMacroWrite);
  end;

const
  Sig: array[0..3] of Char = 'TPOR';
var
  I, Len: Integer;
  Tag: Byte;
begin
  Put(Sig, SizeOf(Sig));
  for I := 0 to FCount - 1 do
    if FItems[I].IsCommand then
    begin
      Tag := 2;
      Put(Tag, 1);
      Len := Length(FItems[I].Command);
      Put(Len, SizeOf(Len));
      if Len > 0 then Put(FItems[I].Command[1], Len);
    end
    else
    begin
      Tag := 1;
      Put(Tag, 1);
      Put(FItems[I].Code, SizeOf(Integer));
    end;
  Tag := 0;
  Put(Tag, 1);
end;

end.
