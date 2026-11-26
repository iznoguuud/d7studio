{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDbgDisasm;

{ D7 Studio debugger - IA-32 instruction decoder.

  DecodeInstr gives the length and control-flow classification of the
  instruction at a code pointer (needed for source stepping); DisasmInstr
  additionally renders it as text in the style of the Delphi CPU view. }

interface

type
  TInstrKind = (ikNormal, ikCall, ikJmp, ikJcc, ikRet, ikInt3, ikInvalid);

  TInstrInfo = record
    Len: Integer;            // total length in bytes (0 when undecodable)
    Kind: TInstrKind;
    HasTarget: Boolean;      // direct branch: Target is valid
    Target: Cardinal;
    Indirect: Boolean;       // call/jmp through register or memory
    RepPrefix: Boolean;      // F2/F3 prefix present
    IsString: Boolean;       // MOVS/CMPS/STOS/LODS/SCAS/INS/OUTS
    ModRM: Byte;
    HasSIB: Boolean;
    SIB: Byte;
    Disp: Integer;
    DispSize: Integer;
  end;

{ Decodes one instruction. Code points to Avail readable bytes located at Addr. }
function DecodeInstr(Code: Pointer; Avail: Integer; Addr: Cardinal; out Info: TInstrInfo): Boolean;

{ Decodes and formats one instruction; returns its length (0 if undecodable). }
function DisasmInstr(Code: Pointer; Avail: Integer; Addr: Cardinal; out Text: string): Integer;

type
  TCallBytes = array[0..7] of Byte;       // the 8 bytes before an address

{ Whether Addr is a return address: the bytes before it end with a CALL (the debugger's call
  stack, the crash log's stack walk). RelCallBefore: call rel32, Target its destination;
  IndirectCallBefore: call r/m32 (FF /2) in its lengths, AbsSlot the address of the pointer for
  call dword ptr [abs32] (an import slot), else 0. }
function RelCallBefore(const B: TCallBytes; Addr: Cardinal; out Target: Cardinal): Boolean;
function IndirectCallBefore(const B: TCallBytes; out AbsSlot: Cardinal): Boolean;

implementation

uses
  SysUtils;

function RelCallBefore(const B: TCallBytes; Addr: Cardinal; out Target: Cardinal): Boolean;
begin
  Result := B[3] = $E8;
  if Result then Target := Addr + Cardinal(PInteger(@B[4])^) else Target := 0;
end;

function IndirectCallBefore(const B: TCallBytes; out AbsSlot: Cardinal): Boolean;
var
  Md, Rm: Byte;
begin
  Result := False;
  AbsSlot := 0;
  if (B[6] = $FF) and ((B[7] and $38) = $10) then
  begin
    Md := B[7] shr 6;
    Rm := B[7] and 7;
    if (Md = 3) or ((Md = 0) and (Rm <> 4) and (Rm <> 5)) then Result := True;
  end;
  if not Result and (B[5] = $FF) and ((B[6] and $38) = $10) then
  begin
    Md := B[6] shr 6;
    Rm := B[6] and 7;
    if ((Md = 1) and (Rm <> 4)) or ((Md = 0) and (Rm = 4) and ((B[7] and 7) <> 5)) then Result := True;
  end;
  if not Result and (B[4] = $FF) and ((B[5] and $38) = $10) then
  begin
    Md := B[5] shr 6;
    Rm := B[5] and 7;
    if (Md = 1) and (Rm = 4) then Result := True;
  end;
  if not Result and (B[2] = $FF) and ((B[3] and $38) = $10) then
  begin
    Md := B[3] shr 6;
    Rm := B[3] and 7;
    if ((Md = 2) and (Rm <> 4)) or ((Md = 0) and (Rm = 5)) then Result := True;
    if Result and (Md = 0) and (Rm = 5) then AbsSlot := PCardinal(@B[4])^;
  end;
  if not Result and (B[1] = $FF) and ((B[2] and $38) = $10) then
  begin
    Md := B[2] shr 6;
    Rm := B[2] and 7;
    if ((Md = 2) and (Rm = 4)) or ((Md = 0) and (Rm = 4) and ((B[3] and 7) = 5)) then Result := True;
  end;
end;

type
  PByteArr = ^TByteArr;
  TByteArr = array[0..65535] of Byte;

const
  Reg32: array[0..7] of string = ('eax', 'ecx', 'edx', 'ebx', 'esp', 'ebp', 'esi', 'edi');
  Reg16: array[0..7] of string = ('ax', 'cx', 'dx', 'bx', 'sp', 'bp', 'si', 'di');
  Reg8: array[0..7] of string = ('al', 'cl', 'dl', 'bl', 'ah', 'ch', 'dh', 'bh');
  SegNames: array[0..7] of string = ('es', 'cs', 'ss', 'ds', 'fs', 'gs', 'seg6', 'seg7');
  Cond: array[0..15] of string = ('o', 'no', 'b', 'nb', 'z', 'nz', 'be', 'nbe', 's', 'ns', 'p', 'np',
    'l', 'nl', 'le', 'nle');
  Arith: array[0..7] of string = ('add', 'or', 'adc', 'sbb', 'and', 'sub', 'xor', 'cmp');
  Shifts: array[0..7] of string = ('rol', 'ror', 'rcl', 'rcr', 'shl', 'shr', 'sal', 'sar');
  Grp3: array[0..7] of string = ('test', 'test', 'not', 'neg', 'mul', 'imul', 'div', 'idiv');
  Addr16: array[0..7] of string = ('bx+si', 'bx+di', 'bp+si', 'bp+di', 'si', 'di', 'bp', 'bx');

type
  TOpSize = (osNone, osByte, osWord, osDword, osFword, osQword, osTbyte);

  TDecoder = class
    Code: PByteArr;
    Avail: Integer;
    Addr: Cardinal;
    P: Integer;
    Fail: Boolean;
    WantText: Boolean;
    OpSize16, AddrSize16: Boolean;
    SegPrefix: string;
    Rep: Byte;
    Lock: Boolean;
    Md, Rg, Rm: Byte;
    Info: TInstrInfo;
    Text: string;
    function Fetch8: Byte;
    function Fetch16: Word;
    function Fetch32: Cardinal;
    procedure ParseModRM;
    function ImmV: Cardinal;
    function HexB(V: Byte): string;
    function HexV(V: Cardinal): string;
    function HexAddr(V: Cardinal): string;
    function RegV(R: Byte): string;
    function RegName(R: Byte; Size: TOpSize): string;
    function MemText(Size: TOpSize): string;
    function RMText(Size: TOpSize): string;
    function VSize: TOpSize;
    procedure Emit(const Mn: string; const Ops: string);
    procedure DecodeFPU(Op: Byte);
    procedure DecodeTwoByte;
    procedure Run;
  end;

function TDecoder.Fetch8: Byte;
begin
  if P < Avail then
  begin
    Result := Code^[P];
    Inc(P);
  end
  else
  begin
    Fail := True;
    Result := 0;
  end;
end;

function TDecoder.Fetch16: Word;
var
  A, B: Byte;
begin
  A := Fetch8;
  B := Fetch8;
  Result := A or (Word(B) shl 8);
end;

function TDecoder.Fetch32: Cardinal;
var
  A, B: Word;
begin
  A := Fetch16;
  B := Fetch16;
  Result := A or (Cardinal(B) shl 16);
end;

procedure TDecoder.ParseModRM;
begin
  Info.ModRM := Fetch8;
  Md := Info.ModRM shr 6;
  Rg := (Info.ModRM shr 3) and 7;
  Rm := Info.ModRM and 7;
  Info.Disp := 0;
  Info.DispSize := 0;
  if Md = 3 then Exit;
  if AddrSize16 then
  begin
    if ((Md = 0) and (Rm = 6)) or (Md = 2) then
    begin
      Info.Disp := SmallInt(Fetch16);
      Info.DispSize := 2;
    end
    else if Md = 1 then
    begin
      Info.Disp := ShortInt(Fetch8);
      Info.DispSize := 1;
    end;
  end
  else
  begin
    if Rm = 4 then
    begin
      Info.SIB := Fetch8;
      Info.HasSIB := True;
    end;
    if Md = 0 then
    begin
      if (Rm = 5) or (Info.HasSIB and ((Info.SIB and 7) = 5)) then
      begin
        Info.Disp := Integer(Fetch32);
        Info.DispSize := 4;
      end;
    end
    else if Md = 1 then
    begin
      Info.Disp := ShortInt(Fetch8);
      Info.DispSize := 1;
    end
    else
    begin
      Info.Disp := Integer(Fetch32);
      Info.DispSize := 4;
    end;
  end;
end;

function TDecoder.ImmV: Cardinal;
begin
  if OpSize16 then
    Result := Fetch16
  else
    Result := Fetch32;
end;

function TDecoder.HexB(V: Byte): string;
begin
  Result := '$' + IntToHex(V, 2);
end;

function TDecoder.HexV(V: Cardinal): string;
begin
  if OpSize16 then
    Result := '$' + IntToHex(V and $FFFF, 4)
  else
    Result := '$' + IntToHex(V, 8);
end;

function TDecoder.HexAddr(V: Cardinal): string;
begin
  Result := '$' + IntToHex(V, 8);
end;

function TDecoder.VSize: TOpSize;
begin
  if OpSize16 then Result := osWord else Result := osDword;
end;

function TDecoder.RegV(R: Byte): string;
begin
  if OpSize16 then Result := Reg16[R and 7] else Result := Reg32[R and 7];
end;

function TDecoder.RegName(R: Byte; Size: TOpSize): string;
begin
  case Size of
    osByte: Result := Reg8[R and 7];
    osWord: Result := Reg16[R and 7];
  else
    Result := Reg32[R and 7];
  end;
end;

function TDecoder.MemText(Size: TOpSize): string;
var
  S: string;
  Base, Index, Scale: Integer;
  HasBase: Boolean;
begin
  S := '';
  if AddrSize16 then
  begin
    if (Md = 0) and (Rm = 6) then
      S := '$' + IntToHex(Info.Disp and $FFFF, 4)
    else
    begin
      S := Addr16[Rm];
      if Info.DispSize > 0 then
      begin
        if Info.Disp < 0 then
          S := S + '-$' + IntToHex(-Info.Disp, 2)
        else
          S := S + '+$' + IntToHex(Info.Disp, 2);
      end;
    end;
  end
  else
  begin
    HasBase := True;
    Index := -1;
    Scale := 1;
    if Info.HasSIB then
    begin
      Base := Info.SIB and 7;
      Index := (Info.SIB shr 3) and 7;
      Scale := 1 shl (Info.SIB shr 6);
      if Index = 4 then Index := -1;
      if (Base = 5) and (Md = 0) then HasBase := False;
    end
    else
    begin
      Base := Rm;
      if (Md = 0) and (Rm = 5) then HasBase := False;
    end;
    if HasBase then S := Reg32[Base];
    if Index >= 0 then
    begin
      if S <> '' then S := S + '+';
      S := S + Reg32[Index];
      if Scale > 1 then S := S + '*' + IntToStr(Scale);
    end;
    if Info.DispSize > 0 then
    begin
      if S = '' then
        S := '$' + IntToHex(Cardinal(Info.Disp), 8)
      else if Info.Disp < 0 then
      begin
        if Info.DispSize = 1 then
          S := S + '-$' + IntToHex(-Info.Disp, 2)
        else
          S := S + '-$' + IntToHex(Cardinal(-Info.Disp), 8);
      end
      else if Info.DispSize = 1 then
        S := S + '+$' + IntToHex(Info.Disp, 2)
      else
        S := S + '+$' + IntToHex(Cardinal(Info.Disp), 8);
    end;
  end;
  S := '[' + S + ']';
  if SegPrefix <> '' then S := SegPrefix + ':' + S;
  case Size of
    osByte: Result := 'byte ptr ' + S;
    osWord: Result := 'word ptr ' + S;
    osDword: Result := 'dword ptr ' + S;
    osFword: Result := 'fword ptr ' + S;
    osQword: Result := 'qword ptr ' + S;
    osTbyte: Result := 'tbyte ptr ' + S;
  else
    Result := S;
  end;
end;

function TDecoder.RMText(Size: TOpSize): string;
begin
  if Md = 3 then
    Result := RegName(Rm, Size)
  else
    Result := MemText(Size);
end;

procedure TDecoder.Emit(const Mn: string; const Ops: string);
begin
  if not WantText then Exit;
  Text := Mn;
  if Lock then Text := 'lock ' + Text;
  if Ops <> '' then Text := Text + ' ' + Ops;
end;

procedure TDecoder.DecodeFPU(Op: Byte);
const
  D8Names: array[0..7] of string = ('fadd', 'fmul', 'fcom', 'fcomp', 'fsub', 'fsubr', 'fdiv', 'fdivr');
  D9Mem: array[0..7] of string = ('fld', '?', 'fst', 'fstp', 'fldenv', 'fldcw', 'fnstenv', 'fnstcw');
  DAMem: array[0..7] of string = ('fiadd', 'fimul', 'ficom', 'ficomp', 'fisub', 'fisubr', 'fidiv', 'fidivr');
  DBMem: array[0..7] of string = ('fild', 'fisttp', 'fist', 'fistp', '?', 'fld', '?', 'fstp');
  DDMem: array[0..7] of string = ('fld', 'fisttp', 'fst', 'fstp', 'frstor', '?', 'fnsave', 'fnstsw');
  DFMem: array[0..7] of string = ('fild', 'fisttp', 'fist', 'fistp', 'fbld', 'fild', 'fbstp', 'fistp');
  D9E0: array[0..31] of string = ('fchs', 'fabs', '?', '?', 'ftst', 'fxam', '?', '?',
    'fld1', 'fldl2t', 'fldl2e', 'fldpi', 'fldlg2', 'fldln2', 'fldz', '?',
    'f2xm1', 'fyl2x', 'fptan', 'fpatan', 'fxtract', 'fprem1', 'fdecstp', 'fincstp',
    'fprem', 'fyl2xp1', 'fsqrt', 'fsincos', 'frndint', 'fscale', 'fsin', 'fcos');
  DEReg: array[0..7] of string = ('faddp', 'fmulp', '?', 'fcompp', 'fsubrp', 'fsubp', 'fdivrp', 'fdivp');
  DCReg: array[0..7] of string = ('fadd', 'fmul', 'fcom', 'fcomp', 'fsubr', 'fsub', 'fdivr', 'fdiv');
  DAReg: array[0..7] of string = ('fcmovb', 'fcmove', 'fcmovbe', 'fcmovu', '?', 'fucompp', '?', '?');
  DBReg: array[0..7] of string = ('fcmovnb', 'fcmovne', 'fcmovnbe', 'fcmovnu', '?', 'fucomi', 'fcomi', '?');
  DDReg: array[0..7] of string = ('ffree', '?', 'fst', 'fstp', 'fucom', 'fucomp', '?', '?');
  DFReg: array[0..7] of string = ('ffreep', '?', '?', '?', 'fnstsw', 'fucomip', 'fcomip', '?');
var
  STi: string;
begin
  ParseModRM;
  if not WantText then Exit;
  STi := 'st(' + IntToStr(Rm) + ')';
  if Md <> 3 then
  begin
    case Op of
      $D8: Emit(D8Names[Rg], MemText(osDword));
      $D9:
        if Rg in [0, 2, 3] then
          Emit(D9Mem[Rg], MemText(osDword))
        else if Rg in [5, 7] then
          Emit(D9Mem[Rg], MemText(osWord))
        else
          Emit(D9Mem[Rg], MemText(osNone));
      $DA: Emit(DAMem[Rg], MemText(osDword));
      $DB:
        if Rg in [5, 7] then
          Emit(DBMem[Rg], MemText(osTbyte))
        else
          Emit(DBMem[Rg], MemText(osDword));
      $DC: Emit(D8Names[Rg], MemText(osQword));
      $DD:
        if Rg in [0, 1, 2, 3] then
          Emit(DDMem[Rg], MemText(osQword))
        else if Rg = 7 then
          Emit(DDMem[Rg], MemText(osWord))
        else
          Emit(DDMem[Rg], MemText(osNone));
      $DE: Emit(DAMem[Rg], MemText(osWord));
      $DF:
        if Rg in [0, 1, 2, 3] then
          Emit(DFMem[Rg], MemText(osWord))
        else if Rg in [5, 7] then
          Emit(DFMem[Rg], MemText(osQword))
        else
          Emit(DFMem[Rg], MemText(osTbyte));
    end;
    Exit;
  end;
  case Op of
    $D8: Emit(D8Names[Rg], 'st,' + STi);
    $D9:
      case Rg of
        0: Emit('fld', STi);
        1: Emit('fxch', STi);
        2: Emit('fnop', '');
        4..7: Emit(D9E0[Info.ModRM - $E0], '');
      else
        Emit('fpu', HexB(Op) + ',' + HexB(Info.ModRM));
      end;
    $DA: Emit(DAReg[Rg], 'st,' + STi);
    $DB:
      if Info.ModRM = $E2 then
        Emit('fnclex', '')
      else if Info.ModRM = $E3 then
        Emit('fninit', '')
      else
        Emit(DBReg[Rg], 'st,' + STi);
    $DC: Emit(DCReg[Rg], STi + ',st');
    $DD: Emit(DDReg[Rg], STi);
    $DE:
      if Info.ModRM = $D9 then
        Emit('fcompp', '')
      else
        Emit(DEReg[Rg], STi + ',st');
    $DF:
      if Info.ModRM = $E0 then
        Emit('fnstsw', 'ax')
      else
        Emit(DFReg[Rg], 'st,' + STi);
  end;
end;

procedure TDecoder.DecodeTwoByte;
var
  Op: Byte;
  Rel: Integer;
  Imm: Byte;
begin
  Op := Fetch8;
  case Op of
    $80..$8F:
      begin
        if OpSize16 then Rel := SmallInt(Fetch16) else Rel := Integer(Fetch32);
        Info.Kind := ikJcc;
        Info.HasTarget := True;
        Info.Target := Addr + Cardinal(P) + Cardinal(Rel);
        Emit('j' + Cond[Op and 15], HexAddr(Info.Target));
      end;
    $05: Emit('syscall', '');
    $06: Emit('clts', '');
    $07: Emit('sysret', '');
    $08: Emit('invd', '');
    $09: Emit('wbinvd', '');
    $0B: Emit('ud2', '');
    $0E: Emit('femms', '');
    $30: Emit('wrmsr', '');
    $31: Emit('rdtsc', '');
    $32: Emit('rdmsr', '');
    $33: Emit('rdpmc', '');
    $34: Emit('sysenter', '');
    $35: Emit('sysexit', '');
    $37: Emit('getsec', '');
    $77: Emit('emms', '');
    $A0: Emit('push', 'fs');
    $A1: Emit('pop', 'fs');
    $A2: Emit('cpuid', '');
    $A8: Emit('push', 'gs');
    $A9: Emit('pop', 'gs');
    $AA: Emit('rsm', '');
    $C8..$CF: Emit('bswap', Reg32[Op and 7]);
    $40..$4F:
      begin
        ParseModRM;
        Emit('cmov' + Cond[Op and 15], RegV(Rg) + ',' + RMText(VSize));
      end;
    $90..$9F:
      begin
        ParseModRM;
        Emit('set' + Cond[Op and 15], RMText(osByte));
      end;
    $A3, $AB, $B3, $BB:
      begin
        ParseModRM;
        case Op of
          $A3: Emit('bt', RMText(VSize) + ',' + RegV(Rg));
          $AB: Emit('bts', RMText(VSize) + ',' + RegV(Rg));
          $B3: Emit('btr', RMText(VSize) + ',' + RegV(Rg));
          $BB: Emit('btc', RMText(VSize) + ',' + RegV(Rg));
        end;
      end;
    $A4, $AC:
      begin
        ParseModRM;
        Imm := Fetch8;
        if Op = $A4 then
          Emit('shld', RMText(VSize) + ',' + RegV(Rg) + ',' + HexB(Imm))
        else
          Emit('shrd', RMText(VSize) + ',' + RegV(Rg) + ',' + HexB(Imm));
      end;
    $A5, $AD:
      begin
        ParseModRM;
        if Op = $A5 then
          Emit('shld', RMText(VSize) + ',' + RegV(Rg) + ',cl')
        else
          Emit('shrd', RMText(VSize) + ',' + RegV(Rg) + ',cl');
      end;
    $AF:
      begin
        ParseModRM;
        Emit('imul', RegV(Rg) + ',' + RMText(VSize));
      end;
    $B0, $B1:
      begin
        ParseModRM;
        if Op = $B0 then
          Emit('cmpxchg', RMText(osByte) + ',' + Reg8[Rg])
        else
          Emit('cmpxchg', RMText(VSize) + ',' + RegV(Rg));
      end;
    $B6, $B7, $BE, $BF:
      begin
        ParseModRM;
        case Op of
          $B6: Emit('movzx', RegV(Rg) + ',' + RMText(osByte));
          $B7: Emit('movzx', Reg32[Rg] + ',' + RMText(osWord));
          $BE: Emit('movsx', RegV(Rg) + ',' + RMText(osByte));
          $BF: Emit('movsx', Reg32[Rg] + ',' + RMText(osWord));
        end;
      end;
    $BA:
      begin
        ParseModRM;
        Imm := Fetch8;
        case Rg of
          4: Emit('bt', RMText(VSize) + ',' + HexB(Imm));
          5: Emit('bts', RMText(VSize) + ',' + HexB(Imm));
          6: Emit('btr', RMText(VSize) + ',' + HexB(Imm));
          7: Emit('btc', RMText(VSize) + ',' + HexB(Imm));
        else
          Emit('db', '$0F,$BA');
        end;
      end;
    $BC, $BD:
      begin
        ParseModRM;
        if Op = $BC then
          Emit('bsf', RegV(Rg) + ',' + RMText(VSize))
        else
          Emit('bsr', RegV(Rg) + ',' + RMText(VSize));
      end;
    $C0, $C1:
      begin
        ParseModRM;
        if Op = $C0 then
          Emit('xadd', RMText(osByte) + ',' + Reg8[Rg])
        else
          Emit('xadd', RMText(VSize) + ',' + RegV(Rg));
      end;
    $70, $71, $72, $73, $C2, $C4, $C5, $C6, $0F:
      begin
        // MMX/SSE forms with ModRM + imm8
        ParseModRM;
        Imm := Fetch8;
        Emit('db', '$0F,' + HexB(Op) + ',...,' + HexB(Imm));
      end;
    $38:
      begin
        Fetch8;
        ParseModRM;
        Emit('db', '$0F,$38,...');
      end;
    $3A:
      begin
        Fetch8;
        ParseModRM;
        Fetch8;
        Emit('db', '$0F,$3A,...');
      end;
  else
    // everything else in the 0F map takes a ModRM byte and no immediate
    ParseModRM;
    if WantText then
    begin
      case Op of
        $00: Emit('grp6', RMText(osWord));
        $01: Emit('grp7', RMText(osNone));
        $1F: Emit('nop', RMText(VSize));
        $C7: Emit('cmpxchg8b', RMText(osQword));
      else
        Emit('db', '$0F,' + HexB(Op) + ',' + HexB(Info.ModRM));
      end;
    end;
  end;
end;

procedure TDecoder.Run;
var
  Op, Imm8: Byte;
  ImmW: Word;
  Imm: Cardinal;
  Rel: Integer;
  Done: Boolean;
  Sz: TOpSize;
  S: string;
begin
  FillChar(Info, SizeOf(Info), 0);
  Text := '';
  P := 0;
  Fail := False;
  OpSize16 := False;
  AddrSize16 := False;
  SegPrefix := '';
  Rep := 0;
  Lock := False;
  // prefixes
  Done := False;
  Op := 0;
  while not Done and not Fail and (P < 15) do
  begin
    Op := Fetch8;
    case Op of
      $F0: Lock := True;
      $F2, $F3:
        begin
          Rep := Op;
          Info.RepPrefix := True;
        end;
      $2E: SegPrefix := 'cs';
      $36: SegPrefix := 'ss';
      $3E: SegPrefix := 'ds';
      $26: SegPrefix := 'es';
      $64: SegPrefix := 'fs';
      $65: SegPrefix := 'gs';
      $66: OpSize16 := True;
      $67: AddrSize16 := True;
    else
      Done := True;
    end;
  end;
  if Fail or not Done then
  begin
    Info.Kind := ikInvalid;
    Exit;
  end;
  case Op of
    $00..$3F:
      if (Op and 7) < 6 then
      begin
        S := Arith[(Op shr 3) and 7];
        case Op and 7 of
          0: begin ParseModRM; Emit(S, RMText(osByte) + ',' + Reg8[Rg]); end;
          1: begin ParseModRM; Emit(S, RMText(VSize) + ',' + RegV(Rg)); end;
          2: begin ParseModRM; Emit(S, Reg8[Rg] + ',' + RMText(osByte)); end;
          3: begin ParseModRM; Emit(S, RegV(Rg) + ',' + RMText(VSize)); end;
          4: begin Imm8 := Fetch8; Emit(S, 'al,' + HexB(Imm8)); end;
          5: begin Imm := ImmV; Emit(S, RegV(0) + ',' + HexV(Imm)); end;
        end;
      end
      else
        case Op of
          $06: Emit('push', 'es');
          $07: Emit('pop', 'es');
          $0E: Emit('push', 'cs');
          $0F: DecodeTwoByte;
          $16: Emit('push', 'ss');
          $17: Emit('pop', 'ss');
          $1E: Emit('push', 'ds');
          $1F: Emit('pop', 'ds');
          $27: Emit('daa', '');
          $2F: Emit('das', '');
          $37: Emit('aaa', '');
          $3F: Emit('aas', '');
        end;
    $40..$47: Emit('inc', RegV(Op));
    $48..$4F: Emit('dec', RegV(Op));
    $50..$57: Emit('push', RegV(Op));
    $58..$5F: Emit('pop', RegV(Op));
    $60: Emit('pushad', '');
    $61: Emit('popad', '');
    $62: begin ParseModRM; Emit('bound', RegV(Rg) + ',' + RMText(osNone)); end;
    $63: begin ParseModRM; Emit('arpl', RMText(osWord) + ',' + Reg16[Rg]); end;
    $68: begin Imm := ImmV; Emit('push', HexV(Imm)); end;
    $69: begin ParseModRM; Imm := ImmV; Emit('imul', RegV(Rg) + ',' + RMText(VSize) + ',' + HexV(Imm)); end;
    $6A: begin Imm8 := Fetch8; Emit('push', HexB(Imm8)); end;
    $6B: begin ParseModRM; Imm8 := Fetch8; Emit('imul', RegV(Rg) + ',' + RMText(VSize) + ',' + HexB(Imm8)); end;
    $6C..$6F:
      begin
        Info.IsString := True;
        case Op of
          $6C: Emit('insb', '');
          $6D: Emit('insd', '');
          $6E: Emit('outsb', '');
          $6F: Emit('outsd', '');
        end;
      end;
    $70..$7F:
      begin
        Rel := ShortInt(Fetch8);
        Info.Kind := ikJcc;
        Info.HasTarget := True;
        Info.Target := Addr + Cardinal(P) + Cardinal(Rel);
        Emit('j' + Cond[Op and 15], HexAddr(Info.Target));
      end;
    $80, $82: begin ParseModRM; Imm8 := Fetch8; Emit(Arith[Rg], RMText(osByte) + ',' + HexB(Imm8)); end;
    $81: begin ParseModRM; Imm := ImmV; Emit(Arith[Rg], RMText(VSize) + ',' + HexV(Imm)); end;
    $83:
      begin
        ParseModRM;
        Imm8 := Fetch8;
        if Imm8 >= $80 then
          Emit(Arith[Rg], RMText(VSize) + ',-$' + IntToHex(256 - Imm8, 2))
        else
          Emit(Arith[Rg], RMText(VSize) + ',' + HexB(Imm8));
      end;
    $84: begin ParseModRM; Emit('test', RMText(osByte) + ',' + Reg8[Rg]); end;
    $85: begin ParseModRM; Emit('test', RMText(VSize) + ',' + RegV(Rg)); end;
    $86: begin ParseModRM; Emit('xchg', RMText(osByte) + ',' + Reg8[Rg]); end;
    $87: begin ParseModRM; Emit('xchg', RMText(VSize) + ',' + RegV(Rg)); end;
    $88: begin ParseModRM; Emit('mov', RMText(osByte) + ',' + Reg8[Rg]); end;
    $89: begin ParseModRM; Emit('mov', RMText(VSize) + ',' + RegV(Rg)); end;
    $8A: begin ParseModRM; Emit('mov', Reg8[Rg] + ',' + RMText(osByte)); end;
    $8B: begin ParseModRM; Emit('mov', RegV(Rg) + ',' + RMText(VSize)); end;
    $8C: begin ParseModRM; Emit('mov', RMText(osWord) + ',' + SegNames[Rg]); end;
    $8D: begin ParseModRM; Emit('lea', RegV(Rg) + ',' + RMText(osNone)); end;
    $8E: begin ParseModRM; Emit('mov', SegNames[Rg] + ',' + RMText(osWord)); end;
    $8F: begin ParseModRM; Emit('pop', RMText(VSize)); end;
    $90: if Rep = $F3 then Emit('pause', '') else Emit('nop', '');
    $91..$97: Emit('xchg', RegV(0) + ',' + RegV(Op));
    $98: if OpSize16 then Emit('cbw', '') else Emit('cwde', '');
    $99: if OpSize16 then Emit('cwd', '') else Emit('cdq', '');
    $9A, $EA:
      begin
        Imm := ImmV;
        ImmW := Fetch16;
        if Op = $9A then Info.Kind := ikCall else Info.Kind := ikJmp;
        Info.Indirect := True;      // far transfer: treat target as unknown
        if Op = $9A then
          Emit('call', IntToHex(ImmW, 4) + ':' + HexV(Imm))
        else
          Emit('jmp', IntToHex(ImmW, 4) + ':' + HexV(Imm));
      end;
    $9B: Emit('wait', '');
    $9C: Emit('pushfd', '');
    $9D: Emit('popfd', '');
    $9E: Emit('sahf', '');
    $9F: Emit('lahf', '');
    $A0..$A3:
      begin
        if AddrSize16 then Imm := Fetch16 else Imm := Fetch32;
        S := '[' + HexAddr(Imm) + ']';
        if SegPrefix <> '' then S := SegPrefix + ':' + S;
        case Op of
          $A0: Emit('mov', 'al,' + S);
          $A1: Emit('mov', RegV(0) + ',' + S);
          $A2: Emit('mov', S + ',al');
          $A3: Emit('mov', S + ',' + RegV(0));
        end;
      end;
    $A4..$A7, $AA..$AF:
      begin
        Info.IsString := True;
        if WantText then
        begin
          case Op of
            $A4: S := 'movsb';
            $A5: if OpSize16 then S := 'movsw' else S := 'movsd';
            $A6: S := 'cmpsb';
            $A7: if OpSize16 then S := 'cmpsw' else S := 'cmpsd';
            $AA: S := 'stosb';
            $AB: if OpSize16 then S := 'stosw' else S := 'stosd';
            $AC: S := 'lodsb';
            $AD: if OpSize16 then S := 'lodsw' else S := 'lodsd';
            $AE: S := 'scasb';
          else
            if OpSize16 then S := 'scasw' else S := 'scasd';
          end;
          if Rep = $F3 then
          begin
            if Op in [$A6, $A7, $AE, $AF] then S := 'repe ' + S else S := 'rep ' + S;
          end
          else if Rep = $F2 then
            S := 'repne ' + S;
          Emit(S, '');
        end;
      end;
    $A8: begin Imm8 := Fetch8; Emit('test', 'al,' + HexB(Imm8)); end;
    $A9: begin Imm := ImmV; Emit('test', RegV(0) + ',' + HexV(Imm)); end;
    $B0..$B7: begin Imm8 := Fetch8; Emit('mov', Reg8[Op and 7] + ',' + HexB(Imm8)); end;
    $B8..$BF: begin Imm := ImmV; Emit('mov', RegV(Op) + ',' + HexV(Imm)); end;
    $C0: begin ParseModRM; Imm8 := Fetch8; Emit(Shifts[Rg], RMText(osByte) + ',' + HexB(Imm8)); end;
    $C1: begin ParseModRM; Imm8 := Fetch8; Emit(Shifts[Rg], RMText(VSize) + ',' + HexB(Imm8)); end;
    $C2, $CA:
      begin
        ImmW := Fetch16;
        Info.Kind := ikRet;
        if Op = $C2 then Emit('ret', '$' + IntToHex(ImmW, 4)) else Emit('retf', '$' + IntToHex(ImmW, 4));
      end;
    $C3, $CB:
      begin
        Info.Kind := ikRet;
        if Op = $C3 then Emit('ret', '') else Emit('retf', '');
      end;
    $C4: begin ParseModRM; Emit('les', RegV(Rg) + ',' + RMText(osNone)); end;
    $C5: begin ParseModRM; Emit('lds', RegV(Rg) + ',' + RMText(osNone)); end;
    $C6: begin ParseModRM; Imm8 := Fetch8; Emit('mov', RMText(osByte) + ',' + HexB(Imm8)); end;
    $C7: begin ParseModRM; Imm := ImmV; Emit('mov', RMText(VSize) + ',' + HexV(Imm)); end;
    $C8:
      begin
        ImmW := Fetch16;
        Imm8 := Fetch8;
        Emit('enter', '$' + IntToHex(ImmW, 4) + ',' + HexB(Imm8));
      end;
    $C9: Emit('leave', '');
    $CC:
      begin
        Info.Kind := ikInt3;
        Emit('int', '3');
      end;
    $CD:
      begin
        Imm8 := Fetch8;
        if Imm8 = 3 then Info.Kind := ikInt3;
        Emit('int', HexB(Imm8));
      end;
    $CE: Emit('into', '');
    $CF:
      begin
        Info.Kind := ikRet;
        Emit('iretd', '');
      end;
    $D0: begin ParseModRM; Emit(Shifts[Rg], RMText(osByte) + ',1'); end;
    $D1: begin ParseModRM; Emit(Shifts[Rg], RMText(VSize) + ',1'); end;
    $D2: begin ParseModRM; Emit(Shifts[Rg], RMText(osByte) + ',cl'); end;
    $D3: begin ParseModRM; Emit(Shifts[Rg], RMText(VSize) + ',cl'); end;
    $D4: begin Imm8 := Fetch8; Emit('aam', HexB(Imm8)); end;
    $D5: begin Imm8 := Fetch8; Emit('aad', HexB(Imm8)); end;
    $D6: Emit('salc', '');
    $D7: Emit('xlat', '');
    $D8..$DF: DecodeFPU(Op);
    $E0..$E3:
      begin
        Rel := ShortInt(Fetch8);
        Info.Kind := ikJcc;
        Info.HasTarget := True;
        Info.Target := Addr + Cardinal(P) + Cardinal(Rel);
        case Op of
          $E0: Emit('loopne', HexAddr(Info.Target));
          $E1: Emit('loope', HexAddr(Info.Target));
          $E2: Emit('loop', HexAddr(Info.Target));
          $E3: Emit('jecxz', HexAddr(Info.Target));
        end;
      end;
    $E4: begin Imm8 := Fetch8; Emit('in', 'al,' + HexB(Imm8)); end;
    $E5: begin Imm8 := Fetch8; Emit('in', RegV(0) + ',' + HexB(Imm8)); end;
    $E6: begin Imm8 := Fetch8; Emit('out', HexB(Imm8) + ',al'); end;
    $E7: begin Imm8 := Fetch8; Emit('out', HexB(Imm8) + ',' + RegV(0)); end;
    $E8, $E9:
      begin
        if OpSize16 then Rel := SmallInt(Fetch16) else Rel := Integer(Fetch32);
        if Op = $E8 then Info.Kind := ikCall else Info.Kind := ikJmp;
        Info.HasTarget := True;
        Info.Target := Addr + Cardinal(P) + Cardinal(Rel);
        if Op = $E8 then Emit('call', HexAddr(Info.Target)) else Emit('jmp', HexAddr(Info.Target));
      end;
    $EB:
      begin
        Rel := ShortInt(Fetch8);
        Info.Kind := ikJmp;
        Info.HasTarget := True;
        Info.Target := Addr + Cardinal(P) + Cardinal(Rel);
        Emit('jmp', HexAddr(Info.Target));
      end;
    $EC: Emit('in', 'al,dx');
    $ED: Emit('in', RegV(0) + ',dx');
    $EE: Emit('out', 'dx,al');
    $EF: Emit('out', 'dx,' + RegV(0));
    $F1: Emit('int1', '');
    $F4: Emit('hlt', '');
    $F5: Emit('cmc', '');
    $F6:
      begin
        ParseModRM;
        if Rg < 2 then
        begin
          Imm8 := Fetch8;
          Emit('test', RMText(osByte) + ',' + HexB(Imm8));
        end
        else
          Emit(Grp3[Rg], RMText(osByte));
      end;
    $F7:
      begin
        ParseModRM;
        if Rg < 2 then
        begin
          Imm := ImmV;
          Emit('test', RMText(VSize) + ',' + HexV(Imm));
        end
        else
          Emit(Grp3[Rg], RMText(VSize));
      end;
    $F8: Emit('clc', '');
    $F9: Emit('stc', '');
    $FA: Emit('cli', '');
    $FB: Emit('sti', '');
    $FC: Emit('cld', '');
    $FD: Emit('std', '');
    $FE:
      begin
        ParseModRM;
        case Rg of
          0: Emit('inc', RMText(osByte));
          1: Emit('dec', RMText(osByte));
        else
          Emit('db', '$FE,' + HexB(Info.ModRM));
        end;
      end;
    $FF:
      begin
        ParseModRM;
        Sz := VSize;
        case Rg of
          0: Emit('inc', RMText(Sz));
          1: Emit('dec', RMText(Sz));
          2, 3:
            begin
              Info.Kind := ikCall;
              Info.Indirect := True;
              if Rg = 2 then Emit('call', RMText(Sz)) else Emit('call far', RMText(osFword));
            end;
          4, 5:
            begin
              Info.Kind := ikJmp;
              Info.Indirect := True;
              if Rg = 4 then Emit('jmp', RMText(Sz)) else Emit('jmp far', RMText(osFword));
            end;
          6: Emit('push', RMText(Sz));
        else
          Emit('db', '$FF,' + HexB(Info.ModRM));
        end;
      end;
  else
    Emit('db', HexB(Op));
  end;
  if Fail then
  begin
    Info.Kind := ikInvalid;
    Info.Len := 0;
    Text := '';
  end
  else
  begin
    Info.Len := P;
    if WantText and (Text = '') then Text := 'db ' + HexB(Op);
  end;
end;

function DecodeInstr(Code: Pointer; Avail: Integer; Addr: Cardinal; out Info: TInstrInfo): Boolean;
var
  D: TDecoder;
begin
  D := TDecoder.Create;
  try
    D.Code := Code;
    D.Avail := Avail;
    D.Addr := Addr;
    D.WantText := False;
    D.Run;
    Info := D.Info;
  finally
    D.Free;
  end;
  Result := Info.Len > 0;
end;

function DisasmInstr(Code: Pointer; Avail: Integer; Addr: Cardinal; out Text: string): Integer;
var
  D: TDecoder;
begin
  D := TDecoder.Create;
  try
    D.Code := Code;
    D.Avail := Avail;
    D.Addr := Addr;
    D.WantText := True;
    D.Run;
    Text := D.Text;
    Result := D.Info.Len;
  finally
    D.Free;
  end;
end;

end.
