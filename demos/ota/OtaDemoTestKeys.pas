{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit OtaDemoTestKeys;

{ The self-test's keyboard area (OtaDemoTest): key bindings of IOTAKeyboardServices driven by keys
  the area posts to the code editor and the IDE's message loop takes, as it takes the keyboard's,
  with Ctrl, Shift and Alt in the thread's key state (no key of the real keyboard is involved).

  Checked as Delphi 7 does it (measured in its IDE): an expert's binding takes its key from the IDE's
  key mapping - after krNextProc or krUnhandled Ctrl+Y and Ctrl+T do nothing -, krHandled keeps it;
  a binding goes before a menu's shortcut (Ctrl+Alt+M: View | Debug Windows | Modules); a sequence
  of the experts' does not break the IDE's own chords that begin with the same key (Ctrl+K 1 still
  sets bookmark 1); sequences of three keys; kfImplicitShift binds no Shift form; a binding removed
  while its key is handled; a menu command (AddMenuCommand) taken over by the editor's WM_COPY, not
  the Edit menu's Copy; a pushed keyboard's bindings and its default procedure (SetDefaultKeyProc);
  LookupKeyBinding / GetNextBindingRec / CallKeyBindingProc. }

interface

implementation

uses
  Windows, Messages, SysUtils, Classes, Controls, Forms, Menus, ActnList, ToolsAPI, OtaDemoTest;

const
  TestKeyboard = 'OtaSelfTest.Keyboard';

type
  TKeyTests = class;

  { the area's bindings: one IOTAKeyboardBinding (Main) and a second one that removes itself
    while its key is handled (Remover) }
  TTestBinding = class(TNotifierObject, IOTANotifier, IOTAKeyboardBinding)
  private
    FTests: TKeyTests;
    FRemover: Boolean;
  public
    constructor Create(ATests: TKeyTests; ARemover: Boolean);
    function GetBindingType: TBindingType;
    function GetDisplayName: string;
    function GetName: string;
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
  end;

  TKeyTests = class(TOtaTestArea)
  private
    FFile: string;
    FMain, FRemover: Integer;
    FMainIntf, FRemoverIntf: IOTAKeyboardBinding;
    FNextCalls, FHandledCalls, FSeqCalls, FThreeCalls, FShiftCalls: Integer;
    FOlderCalls, FRemoverCalls, FCopyCalls, FDefaultCalls: Integer;
    FUnhCalls, FMenuKeyCalls, FBoundCalls: Integer;
    function Buffer: IOTAEditBuffer;
    function Line(N: Integer): string;
    function LineCount: Integer;
    function EditorWindow: HWND;
    procedure Key(Code: Word; Shift: TShiftState);
    procedure Open;
    procedure Bind;
    procedure NextProc;
    procedure Handled;
    procedure Chord;
    procedure ThreeKeys;
    procedure ImplicitShift;
    procedure Unhandled;
    procedure BindingFirst;
    procedure RemoveWhileHandled;
    procedure RemovedLater;
    procedure MenuCommand;
    procedure DefaultProc;
    procedure Lookup;
    procedure CloseFile;
  public
    { the bindings' procedures }
    procedure KeyNextProc(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    procedure KeyHandled(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    procedure KeySequence(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    procedure KeyThree(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    procedure KeyShift(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    procedure KeyOlder(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    procedure KeyRemover(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    procedure KeyCopy(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    procedure KeyDefault(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    procedure KeyUnh(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    procedure KeyMenu(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    procedure KeyBound(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    function Name: string; override;
    procedure AddSteps; override;
    procedure Cleanup; override;
  end;

{ ---------------------------------------------------------------- TTestBinding }

constructor TTestBinding.Create(ATests: TKeyTests; ARemover: Boolean);
begin
  inherited Create;
  FTests := ATests;
  FRemover := ARemover;
end;

function TTestBinding.GetBindingType: TBindingType;
begin
  Result := btPartial;
end;

function TTestBinding.GetDisplayName: string;
begin
  if FRemover then Result := 'OTA self-test (removes itself)' else Result := 'OTA self-test keys';
end;

function TTestBinding.GetName: string;
begin
  if FRemover then Result := 'D7Studio.OtaDemo.SelfTest.Remover' else Result := 'D7Studio.OtaDemo.SelfTest.Keys';
end;

procedure TTestBinding.BindKeyboard(const BindingServices: IOTAKeyBindingServices);
begin
  if FRemover then
  begin
    BindingServices.AddKeyBinding([ShortCut(Ord('Q'), [ssCtrl, ssAlt])], FTests.KeyRemover, nil);
    Exit;
  end;
  BindingServices.AddKeyBinding([ShortCut(Ord('Y'), [ssCtrl])], FTests.KeyNextProc, nil);
  BindingServices.AddKeyBinding([ShortCut(Ord('Y'), [ssCtrl, ssShift])], FTests.KeyHandled, nil, 0);
  BindingServices.AddKeyBinding([ShortCut(Ord('K'), [ssCtrl]), ShortCut(Ord('Z'), [ssCtrl])],
    FTests.KeySequence, nil);
  BindingServices.AddKeyBinding([ShortCut(Ord('J'), [ssCtrl, ssAlt]), ShortCut(Ord('K'), [ssCtrl, ssAlt]),
    ShortCut(Ord('L'), [ssCtrl, ssAlt])], FTests.KeyThree, nil);
  BindingServices.AddKeyBinding([ShortCut(Ord('H'), [ssCtrl, ssAlt])], FTests.KeyShift, nil, kfImplicitShift);
  BindingServices.AddKeyBinding([ShortCut(Ord('M'), [ssCtrl, ssAlt])], FTests.KeyMenu, nil);
  BindingServices.AddKeyBinding([ShortCut(Ord('Q'), [ssCtrl, ssAlt])], FTests.KeyOlder, nil);
  BindingServices.AddMenuCommand(mcClipCopy, FTests.KeyCopy, nil);
  BindingServices.SetDefaultKeyProc(FTests.KeyDefault, nil, TestKeyboard);
  BindingServices.AddKeyBinding([ShortCut(Ord('T'), [ssCtrl])], FTests.KeyUnh, nil);
  BindingServices.AddKeyBinding([ShortCut(VK_F12, [])], FTests.KeyBound, nil, 0, TestKeyboard);
end;

{ ---------------------------------------------------------------- the bindings' procedures }

procedure TKeyTests.KeyNextProc(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  Inc(FNextCalls);
  BindingResult := krNextProc;
end;

procedure TKeyTests.KeyHandled(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  Inc(FHandledCalls);
  BindingResult := krHandled;
end;

procedure TKeyTests.KeySequence(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  Inc(FSeqCalls);
  BindingResult := krHandled;
end;

procedure TKeyTests.KeyThree(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  Inc(FThreeCalls);
  BindingResult := krHandled;
end;

procedure TKeyTests.KeyShift(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  Inc(FShiftCalls);
  BindingResult := krHandled;
end;

procedure TKeyTests.KeyOlder(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  Inc(FOlderCalls);
  BindingResult := krHandled;
end;

{ the newer binding of Ctrl+Alt+Q removes its whole keyboard binding while its key is handled }
procedure TKeyTests.KeyRemover(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  Inc(FRemoverCalls);
  if FRemoverIntf <> nil then
  begin
    (BorlandIDEServices as IOTAKeyboardServices).RemoveKeyboardBinding(FRemover);
    FRemoverIntf := nil;
  end;
  BindingResult := krNextProc;
end;

procedure TKeyTests.KeyCopy(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  Inc(FCopyCalls);
  BindingResult := krHandled;
end;

procedure TKeyTests.KeyDefault(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  Inc(FDefaultCalls);
  BindingResult := krHandled;
end;
procedure TKeyTests.KeyUnh(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  Inc(FUnhCalls);
  BindingResult := krUnhandled;
end;

procedure TKeyTests.KeyMenu(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  Inc(FMenuKeyCalls);
  BindingResult := krHandled;
end;

procedure TKeyTests.KeyBound(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  Inc(FBoundCalls);
  BindingResult := krHandled;
end;

{ ---------------------------------------------------------------- TKeyTests }

function TKeyTests.Name: string;
begin
  Result := 'Keys';
end;

procedure TKeyTests.AddSteps;
begin
  Step('Open', Open);
  Step('Bind', Bind);
  Step('NextProc', NextProc);
  Step('Handled', Handled);
  Step('Chord', Chord);
  Step('ThreeKeys', ThreeKeys);
  Step('ImplicitShift', ImplicitShift);
  Step('Unhandled', Unhandled);
  Step('BindingFirst', BindingFirst);
  Step('RemoveWhileHandled', RemoveWhileHandled);
  Step('RemovedLater', RemovedLater);
  Step('MenuCommand', MenuCommand);
  Step('DefaultProc', DefaultProc);
  Step('Lookup', Lookup);
  Step('Close', CloseFile);
end;

procedure TKeyTests.Cleanup;
var
  K: IOTAKeyboardServices;
begin
  K := BorlandIDEServices as IOTAKeyboardServices;
  if FMainIntf <> nil then K.RemoveKeyboardBinding(FMain);
  FMainIntf := nil;
  if FRemoverIntf <> nil then K.RemoveKeyboardBinding(FRemover);
  FRemoverIntf := nil;
end;

function TKeyTests.Buffer: IOTAEditBuffer;
var
  M: IOTAModule;
begin
  Result := nil;
  M := (BorlandIDEServices as IOTAModuleServices).FindModule(FFile);
  if M <> nil then Supports(SourceEditorOf(M), IOTAEditBuffer, Result);
end;

function TKeyTests.Line(N: Integer): string;
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := EditorText(Buffer);
    if (N >= 1) and (N <= L.Count) then Result := L[N - 1] else Result := '';
  finally
    L.Free;
  end;
end;

function TKeyTests.LineCount: Integer;
begin
  Result := Buffer.GetLinesInBuffer;
end;

function TKeyTests.EditorWindow: HWND;
begin
  Result := EditorControlOf(FFile);
end;

{ a key as the keyboard gives it, to the code editor (PostKey) }
procedure TKeyTests.Key(Code: Word; Shift: TShiftState);
begin
  PostKey(EditorWindow, Code, Shift);
end;

procedure TKeyTests.Open;
var
  S: TStringList;
  I: Integer;
begin
  FFile := Dir + 'KeyTest.txt';
  S := TStringList.Create;
  try
    for I := 1 to 10 do S.Add('line ' + IntToStr(I));
    S.SaveToFile(FFile);
  finally
    S.Free;
  end;
  Check((BorlandIDEServices as IOTAActionServices).OpenFile(FFile), 'OpenFile');
  if not Check(Buffer <> nil, 'the file is a buffer') then Exit;
  Check(EditorWindow <> 0, 'its code editor is there');
end;

procedure TKeyTests.Bind;
var
  K: IOTAKeyboardServices;
begin
  K := BorlandIDEServices as IOTAKeyboardServices;
  FMainIntf := TTestBinding.Create(Self, False);
  FMain := K.AddKeyboardBinding(FMainIntf);
  Check(FMain >= 0, 'AddKeyboardBinding');
  FRemoverIntf := TTestBinding.Create(Self, True);
  FRemover := K.AddKeyboardBinding(FRemoverIntf);
  Check(FRemover >= 0, 'AddKeyboardBinding of a second binding');
end;

{ krNextProc after the last binding of the key: the IDE's key mapping does not run - the expert's
  binding took Ctrl+Y from it (Delphi 7's, measured) }
procedure TKeyTests.NextProc;
var
  N: Integer;
begin
  Buffer.TopView.Position.Move(3, 1);
  N := LineCount;
  Key(Ord('Y'), [ssCtrl]);
  ExpectInt('Ctrl+Y reached the expert''s binding', FNextCalls, 1);
  ExpectInt('after krNextProc the IDE''s Ctrl+Y did not run: no line deleted', LineCount, N);
end;

{ krHandled: the key mapping does not get it }
procedure TKeyTests.Handled;
var
  Before: string;
begin
  Buffer.TopView.Position.Move(3, 3);
  Before := Line(3);
  Key(Ord('Y'), [ssCtrl, ssShift]);
  ExpectInt('Shift+Ctrl+Y reached the expert''s binding', FHandledCalls, 1);
  Expect('after krHandled the line is unchanged', Line(3), Before);
end;

{ the expert's Ctrl+K Ctrl+Z does not break the IDE's Ctrl+K chords }
procedure TKeyTests.Chord;
var
  C: TOTACharPos;
begin
  Buffer.TopView.Position.Move(5, 2);
  Key(Ord('K'), [ssCtrl]);
  Key(Ord('1'), []);
  C := Buffer.TopView.BookmarkPos[1];
  ExpectInt('the IDE''s Ctrl+K 1 set bookmark 1 in line 5', C.Line, 5);
  Key(Ord('K'), [ssCtrl]);
  Key(Ord('Z'), [ssCtrl]);
  ExpectInt('the expert''s Ctrl+K Ctrl+Z', FSeqCalls, 1);
end;

procedure TKeyTests.ThreeKeys;
begin
  Key(Ord('J'), [ssCtrl, ssAlt]);
  Key(Ord('K'), [ssCtrl, ssAlt]);
  ExpectInt('two keys of three: not yet', FThreeCalls, 0);
  Key(Ord('L'), [ssCtrl, ssAlt]);
  ExpectInt('a sequence of three keys', FThreeCalls, 1);
  { Delphi 7 eats the key after a sequence of three: it reaches no binding (measured) }
  Key(Ord('H'), [ssCtrl, ssAlt]);
  ExpectInt('the key after it (Delphi 7: eaten)', FShiftCalls, IdeValue(0, 1));
end;

{ kfImplicitShift binds no Shift form of a letter (Delphi 7's: measured) }
procedure TKeyTests.ImplicitShift;
var
  Before: Integer;
begin
  Before := FShiftCalls;
  Key(Ord('H'), [ssCtrl, ssAlt]);
  ExpectInt('Ctrl+Alt+H reached its binding', FShiftCalls, Before + 1);
  Key(Ord('H'), [ssCtrl, ssAlt, ssShift]);
  ExpectInt('kfImplicitShift: Shift+Ctrl+Alt+H did not', FShiftCalls, Before + 1);
end;

{ krUnhandled: Ctrl+T's binding had it, and the IDE's Ctrl+T (delete the word) did not run }
procedure TKeyTests.Unhandled;
var
  Before: string;
begin
  Buffer.TopView.Position.Move(7, 1);
  Before := Line(7);
  Key(Ord('T'), [ssCtrl]);
  { Delphi 7 calls it twice: as the VCL hands the key to the editor and as the window gets it
    (measured); D7 Studio once }
  ExpectInt('Ctrl+T reached the expert''s binding (Delphi 7: twice)', FUnhCalls, IdeValue(2, 1));
  Expect('after krUnhandled the IDE''s Ctrl+T did not run: the line is unchanged', Line(7), Before);
end;

{ a binding goes before the menu's shortcut of its key: Ctrl+Alt+M is View | Debug Windows | Modules;
  krHandled - the menu does not run }
procedure TKeyTests.BindingFirst;
begin
  Key(Ord('M'), [ssCtrl, ssAlt]);
  ExpectInt('Ctrl+Alt+M, a menu''s shortcut, reached the expert''s binding first', FMenuKeyCalls, 1);
end;

{ the newer binding of the key removes its keyboard binding and hands the key on: the older one
  still gets it }
procedure TKeyTests.RemoveWhileHandled;
begin
  Key(Ord('Q'), [ssCtrl, ssAlt]);
  ExpectInt('the newer binding was called', FRemoverCalls, 1);
  ExpectInt('the older binding was called after it', FOlderCalls, 1);
end;

{ the key again, the IDE idle in between: D7 Studio has taken the removed binding's keys away;
  Delphi 7 keeps them until its keyboard is rebuilt (measured) }
procedure TKeyTests.RemovedLater;
begin
  Key(Ord('Q'), [ssCtrl, ssAlt]);
  ExpectInt('the removed binding is gone (Delphi 7: called still)', FRemoverCalls, IdeValue(2, 1));
  ExpectInt('the older binding has the key', FOlderCalls, 2);
end;

{ mcClipCopy: the editor's window's WM_COPY runs the expert's procedure, the Edit menu's Copy and the
  editor's Ctrl+Insert do not (Delphi 7's, measured) }
procedure TKeyTests.MenuCommand;
var
  A: TContainedAction;
begin
  Windows.SetFocus(EditorWindow);
  A := IdeAction('EditCopyCommand');
  if not Check(A <> nil, 'the action EditCopyCommand') then Exit;
  A.Execute;
  ExpectInt('the Edit menu''s Copy: no expert''s procedure', FCopyCalls, 0);
  SendMessage(EditorWindow, WM_COPY, 0, 0);
  ExpectInt('the editor''s WM_COPY: the expert''s procedure (AddMenuCommand(mcClipCopy))', FCopyCalls, 1);
  Key(VK_INSERT, [ssCtrl]);
  ExpectInt('the editor''s Ctrl+Insert: none', FCopyCalls, 1);
end;

{ a pushed keyboard: its binding has its key; a typed character is typed - its default procedure
  gets none (Delphi 7's, measured) }
procedure TKeyTests.DefaultProc;
var
  K: IOTAKeyboardServices;
  Before: string;
begin
  K := BorlandIDEServices as IOTAKeyboardServices;
  Buffer.TopView.Position.Move(6, 1);
  Before := Line(6);
  Expect('PushKeyboard gives the keyboard before', K.PushKeyboard(TestKeyboard), 'Editor');
  try
    Key(VK_F12, []);
    Key(Ord('W'), []);
  finally
    K.PopKeyboard(TestKeyboard);
  end;
  ExpectInt('the pushed keyboard''s binding (F12)', FBoundCalls, 1);
  ExpectInt('SetDefaultKeyProc: no typed character', FDefaultCalls, 0);
  Expect('... the character is typed', Line(6), 'w' + Before);
  Key(VK_F12, []);
  ExpectInt('popped: its binding no longer has F12', FBoundCalls, 1);
end;

{ the chain of a key: the expert's binding alone - the IDE's own command is no binding after it;
  a key no expert binds: the IDE's own }
procedure TKeyTests.Lookup;
var
  K: IOTAKeyboardServices;
  R: TKeyBindingRec;
  N: Integer;
  Mine: TKeyBindingProc;
begin
  K := BorlandIDEServices as IOTAKeyboardServices;
  if not Check(K.LookupKeyBinding([ShortCut(Ord('Y'), [ssCtrl])], R), 'LookupKeyBinding(Ctrl+Y)') then Exit;
  Mine := KeyNextProc;
  Check(TMethod(R.KeyProc).Code = TMethod(Mine).Code, 'the first is the expert''s binding');
  Check(not K.GetNextBindingRec(R), 'GetNextBindingRec: none after it');
  if not Check(K.LookupKeyBinding([ShortCut(Ord('N'), [ssCtrl])], R), 'LookupKeyBinding(Ctrl+N): the IDE''s') then Exit;
  Buffer.TopView.Position.Move(2, 1);
  N := LineCount;
  Check(K.CallKeyBindingProc(R) = krHandled, 'CallKeyBindingProc of the IDE''s command');
  ExpectInt('the IDE''s Ctrl+N inserted a line', LineCount, N + 1);
end;
procedure TKeyTests.CloseFile;
var
  M: IOTAModule;
begin
  Cleanup;
  M := (BorlandIDEServices as IOTAModuleServices).FindModule(FFile);
  if M <> nil then Check(M.CloseModule(True), 'closed');
end;

initialization
  RegisterTestArea(TKeyTests, 60);
end.
