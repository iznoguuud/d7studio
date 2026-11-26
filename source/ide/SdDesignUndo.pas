{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDesignUndo;

{ D7 Studio - undo and redo of the form designer.
  Every change the designer makes is one step, and the unit's source goes back with the form.
  A step keeps the form as text before and after the change, the edits the
  designer made in the unit's source, and the selection before and after. Undo takes the source
  edits back, last first, and shows the form as it was; redo makes them again and shows the form
  as it became (TEditorPage.DesignUndo / DesignRedo).
  A source edit is looked for where it was made, with the text around it; when the user has
  edited the code since, as the one place in the source with that text around it, then as the
  one place with its text (lines only). When one of a step's edits is not found - the user
  changed that text as well - the step is not taken back at all: the form and its unit would no
  longer agree. }

interface

uses
  Classes, SdUndo;

type
  { one change of the unit's source: at Pos (0-based) Removed made way for Inserted; Before and
    After are the text around it, the same before and after the change }
  TSourceEdit = class
  public
    Pos: Integer;
    Removed, Inserted, Before, After: string;
  end;

  TDesignStep = class
  private
    FEdits: TList;
  public
    FormBefore, FormAfter: string;
    SelBefore, SelAfter: string;     // the selected components' names (comma text)
    constructor Create;
    destructor Destroy; override;
    function EditCount: Integer;
    function Edit(Index: Integer): TSourceEdit;
  end;

  TDesignUndo = class
  private
    FSteps: TSdUndoStack;         // TDesignStep: applies both ways
    FForm, FSel: string;          // the form and the selection as the last step left them
    FStep: TDesignStep;           // the step being made (nil: none)
    function StepSize(Step: TObject): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Reset(const Form, Sel: string);       // a form shown anew: no steps
    procedure SelectionChanged(const Sel: string);
    procedure Changed;                              // the designer changes something: a step begins
    { the designer changed the unit: OldText is the source before the edit }
    procedure SourceEdited(const OldText: string; Pos: Integer; const Removed, Inserted: string);
    function Pending: Boolean;
    procedure Commit(const Form, Sel: string);      // the step ends (dropped when nothing changed)
    function CanUndo: Boolean;
    function CanRedo: Boolean;
    function UndoCount: Integer;
    function RedoCount: Integer;
    function NextUndo: TDesignStep;                 // the step Undo takes back (nil: none)
    function NextRedo: TDesignStep;
    procedure Undone;                               // NextUndo was taken back: it can be redone
    procedure Redone;
  end;

{ Text with the source edits of Step taken back (Back) or made again; False when one of them
  is not found - Text is unchanged then }
function ApplyStep(var Text: string; Step: TDesignStep; Back: Boolean): Boolean;

implementation

uses
  SysUtils, StrUtils;

const
  ContextLen = 40;     // the text kept on each side of a source edit
  MaxSteps = 100;      // the oldest steps go
  MaxBytes = 64 * 1024 * 1024;   // ... also beyond these bytes (forms with large binary properties)

{ ---------------------------------------------------------------- TDesignStep }

constructor TDesignStep.Create;
begin
  inherited Create;
  FEdits := TList.Create;
end;

destructor TDesignStep.Destroy;
var
  I: Integer;
begin
  for I := 0 to FEdits.Count - 1 do TObject(FEdits[I]).Free;
  FEdits.Free;
  inherited;
end;

function TDesignStep.EditCount: Integer;
begin
  Result := FEdits.Count;
end;

function TDesignStep.Edit(Index: Integer): TSourceEdit;
begin
  Result := TSourceEdit(FEdits[Index]);
end;

{ ---------------------------------------------------------------- TDesignUndo }

constructor TDesignUndo.Create;
begin
  inherited Create;
  FSteps := TSdUndoStack.Create(MaxSteps);
  FSteps.SetByteLimit(MaxBytes, StepSize);
end;

{ the bytes a step holds: its form after the change - its form before is the step before's form
  after, one string -, the selections and the source edits }
function TDesignUndo.StepSize(Step: TObject): Integer;
var
  S: TDesignStep;
  I: Integer;
begin
  S := TDesignStep(Step);
  Result := Length(S.FormAfter) + Length(S.SelBefore) + Length(S.SelAfter);
  for I := 0 to S.EditCount - 1 do
    with S.Edit(I) do Inc(Result, Length(Removed) + Length(Inserted) + Length(Before) + Length(After));
end;

destructor TDesignUndo.Destroy;
begin
  Clear;
  FSteps.Free;
  inherited;
end;

procedure TDesignUndo.Clear;
begin
  FSteps.Clear;
  FreeAndNil(FStep);
  FForm := '';
  FSel := '';
end;

procedure TDesignUndo.Reset(const Form, Sel: string);
begin
  Clear;
  FForm := Form;
  FSel := Sel;
end;

procedure TDesignUndo.SelectionChanged(const Sel: string);
begin
  { the selection before a change: not one the change itself makes }
  if FStep = nil then FSel := Sel;
end;

procedure TDesignUndo.Changed;
begin
  if FStep <> nil then Exit;
  FStep := TDesignStep.Create;
  FStep.FormBefore := FForm;
  FStep.SelBefore := FSel;
end;

procedure TDesignUndo.SourceEdited(const OldText: string; Pos: Integer; const Removed, Inserted: string);
var
  E: TSourceEdit;
  S: Integer;
begin
  Changed;
  E := TSourceEdit.Create;
  E.Pos := Pos;
  E.Removed := Removed;
  E.Inserted := Inserted;
  S := Pos - ContextLen;
  if S < 0 then S := 0;
  E.Before := Copy(OldText, S + 1, Pos - S);
  E.After := Copy(OldText, Pos + Length(Removed) + 1, ContextLen);
  FStep.FEdits.Add(E);
end;

function TDesignUndo.Pending: Boolean;
begin
  Result := FStep <> nil;
end;

procedure TDesignUndo.Commit(const Form, Sel: string);
begin
  if FStep = nil then Exit;
  if (Form = FStep.FormBefore) and (FStep.EditCount = 0) then
    FreeAndNil(FStep)
  else
  begin
    FStep.FormAfter := Form;
    FStep.SelAfter := Sel;
    FSteps.Done(FStep);
    FStep := nil;
  end;
  FForm := Form;
  FSel := Sel;
end;

function TDesignUndo.CanUndo: Boolean;
begin
  Result := (FSteps.UndoCount > 0) or (FStep <> nil);
end;

function TDesignUndo.CanRedo: Boolean;
begin
  Result := (FSteps.RedoCount > 0) and (FStep = nil);
end;

function TDesignUndo.UndoCount: Integer;
begin
  Result := FSteps.UndoCount;
end;

function TDesignUndo.RedoCount: Integer;
begin
  Result := FSteps.RedoCount;
end;

function TDesignUndo.NextUndo: TDesignStep;
begin
  Result := TDesignStep(FSteps.NextUndo);
end;

function TDesignUndo.NextRedo: TDesignStep;
begin
  Result := TDesignStep(FSteps.NextRedo);
end;

procedure TDesignUndo.Undone;
var
  S: TDesignStep;
begin
  S := TDesignStep(FSteps.TakeUndo);
  if S = nil then Exit;
  FSteps.AddRedo(S);
  FForm := S.FormBefore;
  FSel := S.SelBefore;
end;

procedure TDesignUndo.Redone;
var
  S: TDesignStep;
begin
  S := TDesignStep(FSteps.TakeRedo);
  if S = nil then Exit;
  FSteps.AddUndo(S);
  FForm := S.FormAfter;
  FSel := S.SelAfter;
end;

{ ---------------------------------------------------------------- source edits }

{ the one place (1-based) where S is in Text; 0 when it is not there or more than once }
function UniquePos(const S, Text: string): Integer;
begin
  Result := 0;
  if S = '' then Exit;
  Result := Pos(S, Text);
  if (Result > 0) and (PosEx(S, Text, Result + 1) > 0) then Result := 0;
end;

{ where Middle - what the edit left there - is in Text (0-based), -1 when it is not found }
function LocateEdit(const Text: string; E: TSourceEdit; const Middle: string): Integer;
var
  Whole: string;
  P: Integer;
begin
  Whole := E.Before + Middle + E.After;
  if Copy(Text, E.Pos - Length(E.Before) + 1, Length(Whole)) = Whole then
  begin
    Result := E.Pos;
    Exit;
  end;
  P := UniquePos(Whole, Text);
  if P > 0 then
  begin
    Result := P - 1 + Length(E.Before);
    Exit;
  end;
  { the text around it was edited too: whole lines alone (a field, a method) are safe to find }
  Result := -1;
  if Pos(#10, Middle) = 0 then Exit;
  P := UniquePos(Middle, Text);
  if P > 0 then Result := P - 1;
end;

function ApplyStep(var Text: string; Step: TDesignStep; Back: Boolean): Boolean;
var
  S, Have, Want: string;
  I, K, P: Integer;
  E: TSourceEdit;
begin
  Result := False;
  S := Text;
  for K := 0 to Step.EditCount - 1 do
  begin
    if Back then I := Step.EditCount - 1 - K else I := K;
    E := Step.Edit(I);
    if Back then
    begin
      Have := E.Inserted;
      Want := E.Removed;
    end
    else
    begin
      Have := E.Removed;
      Want := E.Inserted;
    end;
    P := LocateEdit(S, E, Have);
    if P < 0 then Exit;
    S := Copy(S, 1, P) + Want + Copy(S, P + Length(Have) + 1, MaxInt);
  end;
  Text := S;
  Result := True;
end;

end.
