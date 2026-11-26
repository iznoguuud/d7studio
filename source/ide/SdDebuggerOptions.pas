{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdDebuggerOptions;

{ D7 Studio - the debugger's options (Tools | Debugger Options): Delphi 7's pages General, Event Log,
  Language Exceptions, OS Exceptions and
  Integrated debugging. Kept in [Debugger] and its sections of the settings; what they lack
  comes from the user's Delphi 7 (HKCU\Software\Borland\Delphi\7.0\Debugging, Delphi's names)
  and else from Delphi 7's defaults. }

interface

uses
  SysUtils, Classes, Graphics, IniFiles;

type
  { the kinds of the Event Log's messages: the Messages check boxes and the colours }
  TEventKind = (ekBreakpoint, ekProcess, ekThread, ekModule, ekOutput, ekWindow, ekComment);

  TEventColor = record
    Fore, Back: TColor;
  end;

  { an exception class of Language Exceptions: ignored while checked }
  TLangException = record
    Name: string;
    Ignored: Boolean;
  end;

  { a range of OS exception codes: who handles it, how the program goes on }
  TOSExceptionRule = record
    Low, High: Cardinal;
    Name: string;
    UserHandles: Boolean;            // Handled by: User program (no stop); else Debugger
    RunHandled: Boolean;             // On resume: Run handled; else Run unhandled
  end;
  TOSExceptionRules = array of TOSExceptionRule;

  TDebuggerOptions = record
    Integrated: Boolean;
    { General }
    TD32Keys, RearrangeMenu, MarkReadOnly, SideEffects, NoMultipleEvaluators,
      DebugSpawned, COMCrossProcess: Boolean;
    SymbolPath, DCUPath: string;
    InspShowInherited, InspQualifiedNames, InspSortByName: Boolean;
    { Event Log }
    LogClearOnRun, LogUnlimited, LogProcessInfo, LogUseColors: Boolean;
    LogLength: Integer;
    LogKinds: array[TEventKind] of Boolean;
    LogColors: array[TEventKind] of TEventColor;
    { Language Exceptions }
    StopOnDelphi, StopOnCpp: Boolean;
    LangExceptions: array of TLangException;
    { OS Exceptions }
    OSExceptions: TOSExceptionRules;
  end;

const
  EventKindNames: array[TEventKind] of string = ('Breakpoint Message', 'Process Message',
    'Thread Message', 'Module Message', 'Output Message', 'Window Message', 'Comment');

var
  DebuggerOptions: TDebuggerOptions;

procedure LoadDebuggerOptions(Ini: TCustomIniFile);
procedure SaveDebuggerOptions(Ini: TCustomIniFile);
{ the rule of an OS exception code; False: none }
function FindOSRule(Code: Cardinal; var Rule: TOSExceptionRule): Boolean;
{ a rule for the codes Lo..Hi at the end of Rules }
procedure AddOSRule(var Rules: TOSExceptionRules; Lo, Hi: Cardinal; const Name: string;
  UserHandles, RunHandled: Boolean);
{ the class names that do not stop the program (Language Exceptions, checked) }
procedure IgnoredExceptionNames(L: TStrings);

implementation

uses
  SdSettings;

const
  SecDebugger = 'Debugger';
  SecLang = 'Debugger Language Exceptions';
  SecOS = 'Debugger OS Exceptions';
  { the one key of an emptied list: a section without keys is no section, and the defaults would
    come back }
  EmptyListKey = '(none)';

{ the OS exceptions of Windows: the faults D7 Studio's debugger names stop (Debugger), the
  others go to the program; all run unhandled }
procedure FactoryOS(var O: TDebuggerOptions);

  procedure Add(Code: Cardinal; const Name: string; User: Boolean);
  begin
    AddOSRule(O.OSExceptions, Code, Code, Name, User, False);
  end;

begin
  SetLength(O.OSExceptions, 0);
  Add($C0000005, 'Access violation', False);
  Add($C000008C, 'Array bounds exceeded', False);
  Add($80000002, 'Datatype misalignment', True);
  Add($C000008D, 'Float denormal operand', False);
  Add($C000008E, 'Float divide by zero', False);
  Add($C000008F, 'Float inexact result', False);
  Add($C0000090, 'Float invalid operation', False);
  Add($C0000091, 'Float overflow', False);
  Add($C0000092, 'Float stack check', False);
  Add($C0000093, 'Float underflow', False);
  Add($80000001, 'Guard page violation', True);
  Add($C000001D, 'Illegal instruction', False);
  Add($C0000006, 'In page error', True);
  Add($C0000094, 'Integer divide by zero', False);
  Add($C0000095, 'Integer overflow', False);
  Add($C0000026, 'Invalid disposition', True);
  Add($C0000008, 'Invalid handle', True);
  Add($C0000025, 'Noncontinuable exception', True);
  Add($C0000096, 'Privileged instruction', False);
  Add($C00000FD, 'Stack overflow', False);
  Add($40010005, 'Control-C', True);
  Add($40010008, 'Control-Break', True);
end;

procedure Factory(var O: TDebuggerOptions);
var
  K: TEventKind;
begin
  O.Integrated := True;
  O.TD32Keys := False;
  O.RearrangeMenu := True;
  O.MarkReadOnly := False;
  O.SideEffects := False;
  O.NoMultipleEvaluators := False;
  O.DebugSpawned := False;
  O.COMCrossProcess := False;
  O.SymbolPath := '';
  O.DCUPath := '$(DELPHI)\Lib\Debug';
  O.InspShowInherited := False;
  O.InspQualifiedNames := False;
  O.InspSortByName := False;
  O.LogClearOnRun := False;
  O.LogUnlimited := False;
  O.LogProcessInfo := True;
  O.LogUseColors := False;
  O.LogLength := 100;
  for K := Low(K) to High(K) do
  begin
    O.LogKinds[K] := True;
    O.LogColors[K].Fore := clWindowText;
    O.LogColors[K].Back := clWindow;
  end;
  O.LogKinds[ekThread] := False;
  O.LogKinds[ekModule] := False;
  O.LogKinds[ekWindow] := False;
  O.StopOnDelphi := True;
  O.StopOnCpp := True;
  SetLength(O.LangExceptions, 1);
  O.LangExceptions[0].Name := 'EAbort';
  O.LangExceptions[0].Ignored := True;
  FactoryOS(O);
end;

{ the values of [Debugger] (Delphi's names): each key once, for reading and writing }
function DebuggerTable(var O: TDebuggerOptions): TSdOptions;
var
  K: TEventKind;
begin
  Result := nil;
  AddOptions(Result, [
    OptBool('Integrated Debugging', O.Integrated),
    OptBool('Map TD32 Keystrokes', O.TD32Keys),
    OptBool('Rearrange Editor Local Menu', O.RearrangeMenu),
    OptBool('Mark Buffers Read Only', O.MarkReadOnly),
    OptBool('Allow Side Effects', O.SideEffects),
    OptBool('Disable Multiple Evaluators', O.NoMultipleEvaluators),
    OptBool('Debug Spawned Processes', O.DebugSpawned),
    OptBool('COM Cross Process', O.COMCrossProcess),
    OptStr('Debug Symbols Search Path', O.SymbolPath),
    OptStr('Debug DCUs Path', O.DCUPath),
    OptBool('Inspector Show Inherited', O.InspShowInherited),
    OptBool('Inspector Qualified Names', O.InspQualifiedNames),
    OptBool('Inspector Sort By Name', O.InspSortByName),
    OptBool('Clear Log On Run', O.LogClearOnRun),
    OptBool('Unlimited Log', O.LogUnlimited),
    OptBool('Log Process Info', O.LogProcessInfo),
    OptBool('Use Log Colors', O.LogUseColors),
    OptInt('Log Length', O.LogLength)]);
  for K := Low(K) to High(K) do
    AddOptions(Result, [
      OptBool('Log ' + EventKindNames[K], O.LogKinds[K]),
      OptColor(EventKindNames[K] + ' Foreground', O.LogColors[K].Fore),
      OptColor(EventKindNames[K] + ' Background', O.LogColors[K].Back)]);
  AddOptions(Result, [
    OptBool('Stop On Delphi Exceptions', O.StopOnDelphi),
    OptBool('Stop On C++ Exceptions', O.StopOnCpp)]);
end;

procedure LoadDebuggerOptions(Ini: TCustomIniFile);
var
  O: TDebuggerOptions;
  S: TDelphiValues;
  L, F: TStringList;
  I: Integer;
begin
  Factory(O);
  { the values of [Debugger] (Delphi's names) }
  S := TDelphiValues.Create(Ini, SecDebugger);
  try
    ReadOptions(DebuggerTable(O), Ini, SecDebugger, [S]);
    O.LogKinds[ekComment] := True;
  finally
    S.Free;
  end;
  if O.LogLength < 1 then O.LogLength := 100;
  L := TStringList.Create;
  F := TStringList.Create;
  try
    if Ini.SectionExists(SecLang) then
    begin
      Ini.ReadSection(SecLang, L);
      if L.IndexOf(EmptyListKey) >= 0 then L.Delete(L.IndexOf(EmptyListKey));
      SetLength(O.LangExceptions, L.Count);
      for I := 0 to L.Count - 1 do
      begin
        O.LangExceptions[I].Name := L[I];
        O.LangExceptions[I].Ignored := Ini.ReadBool(SecLang, L[I], True);
      end;
    end;
    if Ini.SectionExists(SecOS) then
    begin
      Ini.ReadSection(SecOS, L);
      SetLength(O.OSExceptions, 0);
      for I := 0 to L.Count - 1 do
      begin
        { Item=low,high,user,handled,name }
        F.CommaText := Ini.ReadString(SecOS, L[I], '');
        if F.Count < 5 then Continue;
        AddOSRule(O.OSExceptions, Cardinal(StrToInt64Def('$' + F[0], 0)), Cardinal(StrToInt64Def('$' + F[1], 0)),
          F[4], F[2] = '1', F[3] = '1');
      end;
    end;
  finally
    F.Free;
    L.Free;
  end;
  DebuggerOptions := O;
end;

procedure SaveDebuggerOptions(Ini: TCustomIniFile);
var
  I: Integer;
  F: TStringList;
begin
  WriteOptions(DebuggerTable(DebuggerOptions), Ini, SecDebugger);
  with DebuggerOptions do
  begin
    Ini.EraseSection(SecLang);
    for I := 0 to High(LangExceptions) do Ini.WriteBool(SecLang, LangExceptions[I].Name, LangExceptions[I].Ignored);
    if Length(LangExceptions) = 0 then Ini.WriteString(SecLang, EmptyListKey, '');
    Ini.EraseSection(SecOS);
    F := TStringList.Create;
    try
      for I := 0 to High(OSExceptions) do
      begin
        F.Clear;
        F.Add(IntToHex(OSExceptions[I].Low, 8));
        F.Add(IntToHex(OSExceptions[I].High, 8));
        F.Add(IntToStr(Ord(OSExceptions[I].UserHandles)));
        F.Add(IntToStr(Ord(OSExceptions[I].RunHandled)));
        F.Add(OSExceptions[I].Name);
        Ini.WriteString(SecOS, 'Item' + IntToStr(I), F.CommaText);
      end;
      if Length(OSExceptions) = 0 then Ini.WriteString(SecOS, EmptyListKey, '');    // read as no rule
    finally
      F.Free;
    end;
  end;
end;

procedure AddOSRule(var Rules: TOSExceptionRules; Lo, Hi: Cardinal; const Name: string;
  UserHandles, RunHandled: Boolean);
var
  N: Integer;
begin
  N := Length(Rules);
  SetLength(Rules, N + 1);
  Rules[N].Low := Lo;
  Rules[N].High := Hi;
  Rules[N].Name := Name;
  Rules[N].UserHandles := UserHandles;
  Rules[N].RunHandled := RunHandled;
end;

function FindOSRule(Code: Cardinal; var Rule: TOSExceptionRule): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(DebuggerOptions.OSExceptions) do
    if (Code >= DebuggerOptions.OSExceptions[I].Low) and (Code <= DebuggerOptions.OSExceptions[I].High) then
    begin
      Rule := DebuggerOptions.OSExceptions[I];
      Result := True;
      Exit;
    end;
  Result := False;
end;

procedure IgnoredExceptionNames(L: TStrings);
var
  I: Integer;
begin
  L.Clear;
  for I := 0 to High(DebuggerOptions.LangExceptions) do
    if DebuggerOptions.LangExceptions[I].Ignored then L.Add(DebuggerOptions.LangExceptions[I].Name);
end;

initialization
  Factory(DebuggerOptions);

end.
