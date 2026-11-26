{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdPEHeader;

{ D7 Studio - the PE header of a program Delphi 7's linker wrote.

  The linker writes a header for Windows NT 4: operating system and subsystem version 4.0, no
  DLL characteristics. Windows treats a program of a subsystem before 6.0 as one of before Vista
  (its frame metrics without the padded border, ...), and Delphi 7 has no directive for the
  version (SetPESubsysVersion came with Delphi XE2). ModernizeProgramHeader gives a program
  what programs of today have (a project
  option, on by default). }

interface

{ the offset of a program's PE header in its bytes (0: not a program) }
function PEOffset(const Data: string): Integer;

{ the checksum of the header made right for the bytes as they are (the image help's
  MapFileAndCheckSum: the file's 16-bit words summed with their carries folded back, the field
  itself counting as 0, plus the file's length) }
procedure SetPEChecksum(var Data: string; PE: Integer);

{ a 32-bit program's header: operating system and subsystem version Major.Minor - 6.0 (Windows
  Vista) by default; 5.1 for a program that must start on Windows XP, whose loader refuses a
  subsystem newer than itself -, NX compatible (DEP), dynamic base (ASLR - only with its
  relocation table, which Delphi 7 keeps), terminal-server aware; its checksum refreshed. Large
  address aware stays as it is. False: not a 32-bit program, or the file cannot be read or
  written. }
function ModernizeProgramHeader(const ExeName: string; Major: Word = 6; Minor: Word = 0): Boolean;

implementation

uses
  Windows, SdFileNames;

const
  IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE_ = $0040;
  IMAGE_DLLCHARACTERISTICS_NX_COMPAT_ = $0100;
  IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE_ = $8000;

function PEOffset(const Data: string): Integer;
begin
  Result := 0;
  if Length(Data) < $40 then Exit;
  Move(Data[$3C + 1], Result, 4);
  if (Result <= 0) or (Result + 24 > Length(Data)) or (Copy(Data, Result + 1, 4) <> 'PE'#0#0) then
    Result := 0;
end;

procedure SetPEChecksum(var Data: string; PE: Integer);
var
  Field, I, N: Integer;
  Sum: Cardinal;
begin
  Field := PE + 24 + 64;                     // OptionalHeader.CheckSum
  if Field + 4 > Length(Data) then Exit;
  FillChar(Data[Field + 1], 4, 0);
  Sum := 0;
  N := Length(Data);
  I := 1;
  while I < N do
  begin
    Inc(Sum, Ord(Data[I]) or (Ord(Data[I + 1]) shl 8));
    Sum := (Sum and $FFFF) + (Sum shr 16);
    Inc(I, 2);
  end;
  if Odd(N) then
  begin
    Inc(Sum, Ord(Data[N]));
    Sum := (Sum and $FFFF) + (Sum shr 16);
  end;
  Sum := (Sum and $FFFF) + (Sum shr 16);
  Inc(Sum, Cardinal(N));
  Move(Sum, Data[Field + 1], 4);
end;

function ModernizeProgramHeader(const ExeName: string; Major: Word = 6; Minor: Word = 0): Boolean;
var
  B: string;
  PE, Opt: Integer;
  Dll: Word;
  Relocs: Cardinal;

  function W(Ofs: Integer): Word;
  begin
    Move(B[Ofs + 1], Result, 2);
  end;

  procedure SetW(Ofs: Integer; V: Word);
  begin
    Move(V, B[Ofs + 1], 2);
  end;

begin
  Result := False;
  try
    B := ReadFileU(ExeName);
    PE := PEOffset(B);
    if PE = 0 then Exit;
    Opt := PE + 24;
    { a 32-bit program with the data directories up to the relocations' }
    if (Length(B) < Opt + 96 + 6 * 8) or (W(Opt) <> $10B) or (W(PE + 22) and IMAGE_FILE_DLL <> 0) then Exit;
    SetW(Opt + 40, Major);                   // operating system version
    SetW(Opt + 42, Minor);
    SetW(Opt + 48, Major);                   // subsystem version
    SetW(Opt + 50, Minor);
    Dll := W(Opt + 70) or IMAGE_DLLCHARACTERISTICS_NX_COMPAT_ or IMAGE_DLLCHARACTERISTICS_TERMINAL_SERVER_AWARE_;
    Move(B[Opt + 96 + 5 * 8 + 4 + 1], Relocs, 4);
    if (Relocs <> 0) and (W(PE + 22) and IMAGE_FILE_RELOCS_STRIPPED = 0) then
      Dll := Dll or IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE_;
    SetW(Opt + 70, Dll);
    SetPEChecksum(B, PE);
    WriteFileU(ExeName, B);
    Result := True;
  except
    Result := False;
  end;
end;

end.
