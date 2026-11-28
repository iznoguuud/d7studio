{ *********************************************************************** }
{                                                                         }
{ Delphi Runtime Library                                                  }
{                                                                         }
{ borlndmm.dll: the shared memory manager of ShareMem (its DelphiMM),     }
{ built from this RTL - its memory manager is System's, FastMM4           }
{                                                                         }
{ *********************************************************************** }

{ The exports are Borland's borlndmm.dll's (ShareMem, DelphiMM.pas and Borland's coreide70.bpl
  import them) and those of FastMM4's replacement borlndmm.dll (SysAllocMem, the registration of
  expected memory leaks). The image base is Borland's. }

library borlndmm;

{$IMAGEBASE $00D20000}

{ ShareMem's GetAllocMemCount / GetAllocMemSize: FastMM4 does not keep System's AllocMemCount and
  AllocMemSize, its state has the numbers }
procedure AllocatedBlocks(var Count, Size: Integer);
var
  S: TMemoryManagerState;
  I: Integer;
begin
  GetMemoryManagerState(S);
  Count := S.AllocatedMediumBlockCount + S.AllocatedLargeBlockCount;
  Size := S.TotalAllocatedMediumBlockSize + S.TotalAllocatedLargeBlockSize;
  for I := Low(S.SmallBlockTypeStates) to High(S.SmallBlockTypeStates) do
    with S.SmallBlockTypeStates[I] do
    begin
      Inc(Count, AllocatedBlockCount);
      Inc(Size, AllocatedBlockCount * UseableBlockSize);
    end;
end;

function GetAllocMemCount: Integer;
var
  Size: Integer;
begin
  AllocatedBlocks(Result, Size);
end;

function GetAllocMemSize: Integer;
var
  Count: Integer;
begin
  AllocatedBlocks(Count, Result);
end;

procedure DumpBlocks;
begin
end;

{ C++Builder's RTL counts its users of the heap; FastMM4's replacement answers 2 as well }
function HeapAddRef: Integer;
begin
  Result := 2;
end;

function HeapRelease: Integer;
begin
  Result := 2;
end;

function SysAllocMem(Size: Integer): Pointer;
begin
  Result := SysGetMem(Size);
  if Result <> nil then
    FillChar(Result^, Size, 0);
end;

function SysRegisterExpectedMemoryLeak(P: Pointer): Boolean;
begin
  Result := RegisterExpectedMemoryLeak(P);
end;

function SysUnregisterExpectedMemoryLeak(P: Pointer): Boolean;
begin
  Result := UnregisterExpectedMemoryLeak(P);
end;

exports
  SysGetMem name '@Borlndmm@SysGetMem$qqri',
  SysFreeMem name '@Borlndmm@SysFreeMem$qqrpv',
  SysReallocMem name '@Borlndmm@SysReallocMem$qqrpvi',
  SysAllocMem name '@Borlndmm@SysAllocMem$qqri',
  SysRegisterExpectedMemoryLeak name '@Borlndmm@SysRegisterExpectedMemoryLeak$qqrpi',
  SysUnregisterExpectedMemoryLeak name '@Borlndmm@SysUnregisterExpectedMemoryLeak$qqrpi',
  HeapAddRef name '@Borlndmm@HeapAddRef$qqrv',
  HeapRelease name '@Borlndmm@HeapRelease$qqrv',
  GetMemory,
  FreeMemory,
  ReallocMemory,
  DumpBlocks,
  GetHeapStatus,
  GetAllocMemCount,
  GetAllocMemSize;

begin
  IsMultiThread := True;
  { the modules of ShareMem use this memory until their own end: when the process ends, Windows may
    unload this DLL before rtl70.bpl, whose finalization still frees and reads such blocks }
  KeepMemoryAtUnload := True;
end.
