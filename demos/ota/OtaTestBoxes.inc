{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

{ The self-tests' answers to the IDE's boxes, shared by OtaDemoTest and OtaLegacyTest: each unit
  includes this file in its implementation (their packages are loaded together, so it is no unit of
  its own). Started by a script, a box that waits for an answer nobody gives is answered as the step
  expects, else it is a failure of the step:
  * a message box the IDE shows itself (Delphi's MessageDlg, a TMessageForm - its timer still runs
    in the box's modal loop): the modal result expected, else Yes, else OK, else Cancel;
  * a Windows dialog of the IDE's thread (a message box, a file dialog): the command expected (a
    modal result is the dialog's command: mrYes = IDYES ...), else Cancel. }

type
  { the answer the step expects for a box - Text 'caption: message' -; False: none }
  TBoxExpected = function(const Text: string; var Answer: Integer): Boolean of object;
  { a box answered as expected, or one no step expects (a failure); Dialog: a Windows dialog }
  TBoxTold = procedure(const Text: string; Expected, Dialog: Boolean) of object;

  PBoxCalls = ^TBoxCalls;
  TBoxCalls = record
    Expected: TBoxExpected;
    Told: TBoxTold;
  end;

{ the texts of a Windows dialog's static controls (a message box's text) }
function BoxStaticTexts(Wnd: HWND; Param: LPARAM): BOOL; stdcall;
var
  Cls, Text: array[0..255] of Char;
begin
  GetClassName(Wnd, Cls, SizeOf(Cls));
  if SameText(Cls, 'Static') and (GetWindowText(Wnd, Text, SizeOf(Text)) > 0) then
    PString(Param)^ := PString(Param)^ + ' ' + StrPas(Text);
  Result := True;
end;

function BoxThreadDialog(Wnd: HWND; Param: LPARAM): BOOL; stdcall;
var
  Cls, Caption: array[0..255] of Char;
  S: string;
  Answer: Integer;
  C: PBoxCalls;
begin
  Result := True;
  C := PBoxCalls(Param);
  GetClassName(Wnd, Cls, SizeOf(Cls));
  if not IsWindowVisible(Wnd) or (StrComp(Cls, '#32770') <> 0) then Exit;
  GetWindowText(Wnd, Caption, SizeOf(Caption));
  S := '';
  EnumChildWindows(Wnd, @BoxStaticTexts, LPARAM(@S));
  S := StrPas(Caption) + ':' + S;
  if C.Expected(S, Answer) then
  begin
    C.Told(S, True, True);
    PostMessage(Wnd, WM_COMMAND, Answer, 0);
  end
  else
  begin
    C.Told(S, False, True);
    PostMessage(Wnd, WM_COMMAND, IDCANCEL, 0);
  end;
end;

{ the timer that answers the boxes, every half second }
function NewBoxWatchdog(OnTimer: TNotifyEvent): TTimer;
begin
  Result := TTimer.Create(nil);
  Result.Interval := 500;
  Result.OnTimer := OnTimer;
end;

{ the IDE's boxes shown now answered; Dialogs: its Windows dialogs too (False while a step drives
  them itself) }
procedure AnswerBoxes(Expected: TBoxExpected; Told: TBoxTold; Dialogs: Boolean);
var
  I, Answer: Integer;
  F: TForm;
  L: TComponent;
  S: string;
  C: TBoxCalls;
begin
  for I := Screen.FormCount - 1 downto 0 do
  begin
    F := Screen.Forms[I];
    if not (F.Visible and (fsModal in F.FormState) and (F.ClassName = 'TMessageForm')) then Continue;
    L := F.FindComponent('Message');
    if L is TLabel then S := TLabel(L).Caption else S := '';
    S := F.Caption + ': ' + StringReplace(S, #13#10, ' | ', [rfReplaceAll]);
    if Expected(S, Answer) then
    begin
      Told(S, True, False);
      F.ModalResult := Answer;
    end
    else
    begin
      Told(S, False, False);
      if F.FindComponent('Yes') <> nil then F.ModalResult := mrYes
      else if F.FindComponent('OK') <> nil then F.ModalResult := mrOk
      else F.ModalResult := mrCancel;
    end;
  end;
  if not Dialogs then Exit;
  C.Expected := Expected;
  C.Told := Told;
  EnumThreadWindows(GetCurrentThreadId, @BoxThreadDialog, LPARAM(@C));
end;