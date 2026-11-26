{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdUndo;

{ D7 Studio - the undo and redo steps of an editor (the form designer, the hex editor, the image
  editor): two stacks of objects the stack owns. A step done goes onto the undo stack and empties
  the redo stack; beyond Limit steps the oldest goes. Undo takes the newest undo step out
  (TakeUndo) and puts on the redo stack what makes it again (AddRedo) - the same step for an
  editor whose steps apply both ways, the state before the undo for one that keeps states; Redo
  the other way round. What a step holds and how it is applied is the editor's. An editor whose
  steps can be large also limits their bytes (SetByteLimit): beyond them the oldest undo steps go
  too, the newest always stays. }

interface

uses
  Classes;

type
  TSdStepSizeFunc = function(Step: TObject): Integer of object;   // the bytes a step holds

  TSdUndoStack = class
  private
    FUndo, FRedo: TList;          // the newest at the end
    FLimit: Integer;              // 0: none
    FMaxBytes: Integer;           // 0: none
    FStepSize: TSdStepSizeFunc;
    function Bytes: Int64;         // the bytes of every step, undo and redo
    procedure DropOldest;          // the oldest undo steps beyond the limits
  public
    constructor Create(ALimit: Integer = 0);
    destructor Destroy; override;
    procedure SetByteLimit(MaxBytes: Integer; StepSize: TSdStepSizeFunc);
    procedure Clear;                       // every step freed
    procedure Done(Step: TObject);         // a new step: the redo steps go
    function TakeUndo: TObject;            // the newest undo step, the caller's now (nil: none)
    function TakeRedo: TObject;
    procedure AddUndo(Step: TObject);      // after a redo: what takes it back (the redo steps stay)
    procedure AddRedo(Step: TObject);      // after an undo: what makes it again
    function NextUndo: TObject;            // the newest undo step, left in place (nil: none)
    function NextRedo: TObject;
    function UndoCount: Integer;
    function RedoCount: Integer;
  end;

implementation

procedure FreeSteps(L: TList);
var
  I: Integer;
begin
  for I := 0 to L.Count - 1 do TObject(L[I]).Free;
  L.Clear;
end;

function TakeLast(L: TList): TObject;
begin
  Result := nil;
  if L.Count = 0 then Exit;
  Result := TObject(L[L.Count - 1]);
  L.Delete(L.Count - 1);
end;

constructor TSdUndoStack.Create(ALimit: Integer);
begin
  inherited Create;
  FUndo := TList.Create;
  FRedo := TList.Create;
  FLimit := ALimit;
end;

destructor TSdUndoStack.Destroy;
begin
  Clear;
  FUndo.Free;
  FRedo.Free;
  inherited Destroy;
end;

procedure TSdUndoStack.Clear;
begin
  FreeSteps(FUndo);
  FreeSteps(FRedo);
end;

procedure TSdUndoStack.SetByteLimit(MaxBytes: Integer; StepSize: TSdStepSizeFunc);
begin
  FMaxBytes := MaxBytes;
  FStepSize := StepSize;
  DropOldest;
end;

function TSdUndoStack.Bytes: Int64;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FUndo.Count - 1 do Inc(Result, FStepSize(TObject(FUndo[I])));
  for I := 0 to FRedo.Count - 1 do Inc(Result, FStepSize(TObject(FRedo[I])));
end;

procedure TSdUndoStack.DropOldest;
begin
  if FLimit > 0 then
    while FUndo.Count > FLimit do
    begin
      TObject(FUndo[0]).Free;
      FUndo.Delete(0);
    end;
  if (FMaxBytes > 0) and Assigned(FStepSize) then
    while (FUndo.Count > 1) and (Bytes > FMaxBytes) do
    begin
      TObject(FUndo[0]).Free;
      FUndo.Delete(0);
    end;
end;

procedure TSdUndoStack.Done(Step: TObject);
begin
  FUndo.Add(Step);
  FreeSteps(FRedo);
  DropOldest;
end;

function TSdUndoStack.TakeUndo: TObject;
begin
  Result := TakeLast(FUndo);
end;

function TSdUndoStack.TakeRedo: TObject;
begin
  Result := TakeLast(FRedo);
end;

procedure TSdUndoStack.AddUndo(Step: TObject);
begin
  FUndo.Add(Step);
  DropOldest;
end;

procedure TSdUndoStack.AddRedo(Step: TObject);
begin
  FRedo.Add(Step);
end;

function TSdUndoStack.NextUndo: TObject;
begin
  if FUndo.Count > 0 then Result := TObject(FUndo[FUndo.Count - 1]) else Result := nil;
end;

function TSdUndoStack.NextRedo: TObject;
begin
  if FRedo.Count > 0 then Result := TObject(FRedo[FRedo.Count - 1]) else Result := nil;
end;

function TSdUndoStack.UndoCount: Integer;
begin
  Result := FUndo.Count;
end;

function TSdUndoStack.RedoCount: Integer;
begin
  Result := FRedo.Count;
end;

end.
