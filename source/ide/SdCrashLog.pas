{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdCrashLog;

{ D7 Studio - exception stack log.

  A vectored exception handler copies the top of the stack whenever a Delphi exception or an
  access violation occurs on the main thread. ExceptionStack turns that copy into a list of
  return addresses, resolved against the export tables of the loaded packages and, when the
  detailed map file (bin\D7Studio.map) exists, against the IDE's own procedures and lines (read
  by the debugger's map reader, TTD32Info.LoadFromMap). LogException appends the result to
  <settings>\error.log. }

interface

uses
  Windows, SysUtils, SdDbgTD32, SdDbgDisasm;

procedure InstallCrashLog;
procedure LogException(E: Exception; const Context, LogFile: string);

implementation

const
  cDelphiException = $0EEDFADE;
  MaxRaw = 3072;                 // stack DWORDs kept per capture (12 KB)
  MaxCaptures = 4;
  MaxFrames = 60;

type
  TCapture = record
    Code: Cardinal;
    Addr: Pointer;
    Obj: Pointer;
    Count: Integer;
    Raw: array[0..MaxRaw - 1] of Cardinal;
  end;

  PExceptionPointers = ^TExceptionPointers;

var
  Captures: array[0..MaxCaptures - 1] of TCapture;
  NextCapture: Integer;
  Installed: Boolean;
  MapInfo: TTD32Info;            // the program's map file (MapLookup)
  MapLoaded: Boolean;

function AddVectoredExceptionHandler(First: Cardinal; Handler: Pointer): Pointer; stdcall;
  external kernel32 name 'AddVectoredExceptionHandler';

function VectoredHandler(Info: PExceptionPointers): Longint; stdcall;
var
  C: ^TCapture;
  SP, Top: Cardinal;
  N: Integer;
begin
  Result := 0;                   // EXCEPTION_CONTINUE_SEARCH
  if GetCurrentThreadId <> MainThreadID then Exit;
  case Info^.ExceptionRecord^.ExceptionCode of
    cDelphiException, STATUS_ACCESS_VIOLATION, STATUS_INTEGER_DIVIDE_BY_ZERO,
    STATUS_PRIVILEGED_INSTRUCTION, STATUS_ILLEGAL_INSTRUCTION: ;
  else
    Exit;
  end;
  C := @Captures[NextCapture];
  NextCapture := (NextCapture + 1) mod MaxCaptures;
  C^.Code := Info^.ExceptionRecord^.ExceptionCode;
  C^.Obj := nil;
  if (C^.Code = cDelphiException) and (Info^.ExceptionRecord^.NumberParameters >= 2) then
  begin
    C^.Addr := Pointer(Info^.ExceptionRecord^.ExceptionInformation[0]);
    C^.Obj := Pointer(Info^.ExceptionRecord^.ExceptionInformation[1]);
  end
  else
    C^.Addr := Info^.ExceptionRecord^.ExceptionAddress;
  SP := Info^.ContextRecord^.Esp and not 3;
  asm
    mov eax, fs:[4]
    mov Top, eax
  end;
  C^.Count := 0;
  if (SP = 0) or (Top <= SP) then Exit;
  N := (Top - SP) div 4;
  if N > MaxRaw then N := MaxRaw;
  Move(Pointer(SP)^, C^.Raw[0], N * 4);
  C^.Count := N;
end;

procedure InstallCrashLog;
begin
  if Installed then Exit;
  Installed := True;
  AddVectoredExceptionHandler(1, @VectoredHandler);
end;

{ ---------------------------------------------------------------- address resolution }

function CodeModule(P: Pointer; var Base: Cardinal): Boolean;
var
  MBI: TMemoryBasicInformation;
begin
  Result := False;
  Base := 0;
  if Cardinal(P) < $10000 then Exit;
  if VirtualQuery(P, MBI, SizeOf(MBI)) = 0 then Exit;
  if (MBI.State <> MEM_COMMIT) or (MBI.Type_9 <> MEM_IMAGE) then Exit;
  if MBI.Protect and (PAGE_EXECUTE or PAGE_EXECUTE_READ or PAGE_EXECUTE_READWRITE or PAGE_EXECUTE_WRITECOPY) = 0 then Exit;
  Base := Cardinal(MBI.AllocationBase);
  Result := True;
end;

{ the bytes before a return address are a CALL instruction (the debugger's test, SdDbgDisasm) -
  a relative call into code of a module }
function IsReturnAddress(V: Cardinal): Boolean;
var
  B: TCallBytes;
  T, Base: Cardinal;
begin
  Result := False;
  if (V < $10008) or IsBadReadPtr(Pointer(V - 8), 8) then Exit;
  Move(Pointer(V - 8)^, B, 8);
  Result := (RelCallBefore(B, V, T) and CodeModule(Pointer(T), Base)) or IndirectCallBefore(B, T);
end;

function NearestExport(Base, RVA: Cardinal; var Name: string; var Disp: Cardinal): Boolean;
type
  PCardArray = ^TCardArray;
  TCardArray = array[0..$FFFFFF] of Cardinal;
  PWordArr = ^TWordArr;
  TWordArr = array[0..$FFFFFF] of Word;
var
  NT: PImageNtHeaders;
  Dir: PImageExportDirectory;
  DirRVA, Best, F: Cardinal;
  Names, Funcs: PCardArray;
  Ords: PWordArr;
  I, BestIdx: Integer;
begin
  Result := False;
  try
    if PImageDosHeader(Base)^.e_magic <> IMAGE_DOS_SIGNATURE then Exit;
    NT := PImageNtHeaders(Base + Cardinal(PImageDosHeader(Base)^._lfanew));
    DirRVA := NT^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT].VirtualAddress;
    if DirRVA = 0 then Exit;
    Dir := PImageExportDirectory(Base + DirRVA);
    Names := PCardArray(Base + Cardinal(Dir^.AddressOfNames));
    Funcs := PCardArray(Base + Cardinal(Dir^.AddressOfFunctions));
    Ords := PWordArr(Base + Cardinal(Dir^.AddressOfNameOrdinals));
    Best := 0;
    BestIdx := -1;
    for I := 0 to Integer(Dir^.NumberOfNames) - 1 do
    begin
      F := Funcs^[Ords^[I]];
      if (F <= RVA) and (F > Best) then
      begin
        Best := F;
        BestIdx := I;
      end;
    end;
    if (BestIdx < 0) or (RVA - Best > $4000) then Exit;
    Name := CleanProcName(PChar(Base + Names^[BestIdx]));    // the debugger's demangling
    Disp := RVA - Best;
    Result := True;
  except
    Result := False;
  end;
end;

{ the procedure and the line of an address of the program (RVA), from its detailed map file -
  read by the debugger's reader (SdDbgTD32) the first time it is needed }
function MapLookup(RVA: Cardinal): string;
var
  I: Integer;
  L: TTDLine;
begin
  Result := '';
  if not MapLoaded then
  begin
    MapLoaded := True;
    MapInfo := TTD32Info.Create;
    if not MapInfo.LoadFromMap(ChangeFileExt(ParamStr(0), '.map'), ParamStr(0)) then MapInfo.Clear;
  end;
  I := MapInfo.ProcByAddr(RVA);
  if I >= 0 then Result := MapInfo.ProcShortName(I);    // a map's name: "Unit.TClass.Method"
  if MapInfo.AddrToLine(RVA, L) and (L.Src >= 0) and (L.Src < MapInfo.SrcCount) then
    Result := Result + Format('  (%s:%d)', [ExtractFileName(MapInfo.SrcName[L.Src]), L.Line]);
end;

function Describe(P: Pointer): string;
var
  Base, Disp: Cardinal;
  Buf: array[0..MAX_PATH] of Char;
  ModName, Sym: string;
begin
  Result := '';
  if not CodeModule(P, Base) then Exit;
  ModName := '?';
  if GetModuleFileName(Base, Buf, MAX_PATH) > 0 then ModName := ExtractFileName(Buf);
  Result := Format('%-18s %.8x', [ModName, Cardinal(P) - Base]);
  if Base = HInstance then
  begin
    Sym := MapLookup(Cardinal(P) - Base);
    if Sym <> '' then Result := Result + '  ' + Sym;
  end
  else if NearestExport(Base, Cardinal(P) - Base, Sym, Disp) then
    Result := Result + Format('  %s + %x', [Sym, Disp]);
end;

function ExceptionStack(E: TObject): string;
var
  I, K, Idx, Found, N: Integer;
  C: ^TCapture;
  Base: Cardinal;
  S: string;
begin
  Result := '';
  if not Installed then Exit;
  Found := -1;
  { the capture of this exception object, else the most recent one }
  for K := 1 to MaxCaptures do
  begin
    Idx := (NextCapture - K + MaxCaptures) mod MaxCaptures;
    if (Captures[Idx].Count > 0) and (E <> nil) and (Captures[Idx].Obj = Pointer(E)) then
    begin
      Found := Idx;
      Break;
    end;
  end;
  if Found < 0 then
    for K := 1 to MaxCaptures do
    begin
      Idx := (NextCapture - K + MaxCaptures) mod MaxCaptures;
      if (Captures[Idx].Count > 0) and (Captures[Idx].Code <> cDelphiException) then
      begin
        Found := Idx;
        Break;
      end;
    end;
  if Found < 0 then Exit;
  C := @Captures[Found];
  S := Describe(C^.Addr);
  if S <> '' then Result := '  ' + S + #13#10;
  N := 0;
  for I := 0 to C^.Count - 1 do
  begin
    if (C^.Raw[I] < $10000) or (Pointer(C^.Raw[I]) = C^.Addr) then Continue;
    if not CodeModule(Pointer(C^.Raw[I]), Base) then Continue;
    if not IsReturnAddress(C^.Raw[I]) then Continue;
    S := Describe(Pointer(C^.Raw[I]));
    if S = '' then Continue;
    Result := Result + '  ' + S + #13#10;
    Inc(N);
    if N >= MaxFrames then Break;
  end;
end;

procedure LogException(E: Exception; const Context, LogFile: string);
var
  F: TextFile;
begin
  try
    AssignFile(F, LogFile);
    if FileExists(LogFile) then Append(F) else Rewrite(F);
    try
      Writeln(F, FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), '  ', Context, '  ', E.ClassName, ': ', E.Message);
      Write(F, ExceptionStack(E));
      Writeln(F);
    finally
      CloseFile(F);
    end;
  except
  end;
end;

initialization

finalization
  FreeAndNil(MapInfo);

end.
