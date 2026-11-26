{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit AiMarkdown;

{ The Markdown of a model's answer as runs of styled text, while it streams in: fenced code
  blocks (``` lines, not shown), headings (# to ###### and a space: the marks not shown), list
  items "- " / "* " (a bullet), **bold** and `inline code`. The text comes in pieces that may
  end anywhere - inside a mark, inside a fence line -, so a line's start is held back only as
  long as it may still be a fence, a heading or a list mark; the rest goes out at once. Text is
  UTF-16, line ends are #13 (as Rich Edit keeps them). No VCL: the harness's tests run it. }

interface

type
  TAiMdStyle = (msText, msBold, msCode, msBlock, msHeading);

  TAiMdRunEvent = procedure(const Text: WideString; Style: TAiMdStyle) of object;

  TAiMarkdown = class
  private
    FOnRun: TAiMdRunEvent;
    FInBlock: Boolean;       // inside a fenced code block
    FHolding: Boolean;       // the start of a line is held back
    FHold: WideString;
    FHeading: Boolean;       // the line is a heading
    FBold: Boolean;
    FInline: Boolean;
    FStar: Boolean;          // a '*' that may be the first of '**'
    FRun: WideString;        // text of FRunStyle not yet given out
    FRunStyle: TAiMdStyle;
    procedure Emit(const S: WideString; Style: TAiMdStyle);
    procedure FlushRun;
    function CurrentStyle: TAiMdStyle;
    procedure Put(C: WideChar);
    procedure Decide;
    procedure EndLine;
  public
    constructor Create;
    { the next piece of the text }
    procedure Add(const Text: WideString);
    { the text ended: what is held back goes out, the state starts over }
    procedure Finish;
    procedure Reset;
    property OnRun: TAiMdRunEvent read FOnRun write FOnRun;
    property InBlock: Boolean read FInBlock;
  end;

implementation

const
  Fence = '```';
  Bullet = WideChar($2022);

function LeftTrimmed(const S: WideString): WideString;
var
  I: Integer;
begin
  I := 1;
  while (I <= Length(S)) and (S[I] = ' ') do Inc(I);
  Result := Copy(S, I, MaxInt);
end;

{ S is the start of T }
function IsPrefix(const S, T: WideString): Boolean;
begin
  Result := (Length(S) <= Length(T)) and (Copy(T, 1, Length(S)) = S);
end;

constructor TAiMarkdown.Create;
begin
  inherited Create;
  Reset;
end;

procedure TAiMarkdown.Reset;
begin
  FInBlock := False;
  FHolding := True;
  FHold := '';
  FHeading := False;
  FBold := False;
  FInline := False;
  FStar := False;
  FRun := '';
end;

procedure TAiMarkdown.Emit(const S: WideString; Style: TAiMdStyle);
begin
  if S = '' then Exit;
  if (FRun <> '') and (Style <> FRunStyle) then FlushRun;
  FRunStyle := Style;
  FRun := FRun + S;
end;

procedure TAiMarkdown.FlushRun;
var
  S: WideString;
begin
  if FRun = '' then Exit;
  S := FRun;
  FRun := '';
  if Assigned(FOnRun) then FOnRun(S, FRunStyle);
end;

function TAiMarkdown.CurrentStyle: TAiMdStyle;
begin
  if FInBlock then Result := msBlock
  else if FInline then Result := msCode
  else if FHeading then Result := msHeading
  else if FBold then Result := msBold
  else Result := msText;
end;

{ one character of a line that is not held back }
procedure TAiMarkdown.Put(C: WideChar);
begin
  if FInBlock then
  begin
    Emit(C, msBlock);
    Exit;
  end;
  if FStar then
  begin
    FStar := False;
    if (C = '*') and not FInline then
    begin
      FBold := not FBold;
      Exit;
    end;
    Emit('*', CurrentStyle);
  end;
  if (C = '*') and not FInline then FStar := True
  else if C = '`' then FInline := not FInline
  else Emit(C, CurrentStyle);
end;

{ the held start of a line: still possibly a mark, or decided }
procedure TAiMarkdown.Decide;
var
  T, Rest: WideString;
  I, N: Integer;
begin
  T := LeftTrimmed(FHold);
  if T = '' then Exit;                                      // spaces only: wait
  if IsPrefix(T, Fence) or IsPrefix(Fence, T) then Exit;    // a fence line: up to its end
  if not FInBlock then
  begin
    if T[1] = '#' then
    begin
      N := 0;
      while (N < Length(T)) and (T[N + 1] = '#') do Inc(N);
      if N = Length(T) then Exit;                           // only '#' so far
      if (N <= 6) and (T[N + 1] = ' ') then
      begin
        FHolding := False;
        FHold := '';
        FHeading := True;
        Rest := LeftTrimmed(Copy(T, N + 2, MaxInt));
        for I := 1 to Length(Rest) do Put(Rest[I]);
        Exit;
      end;
    end
    else if (T[1] = '-') or (T[1] = '*') then
    begin
      if Length(T) = 1 then Exit;                           // '-' alone: a mark or not
      if T[2] = ' ' then
      begin
        FHolding := False;
        Emit(Copy(FHold, 1, Length(FHold) - Length(T)) + Bullet + ' ', msText);
        FHold := '';
        Rest := Copy(T, 3, MaxInt);
        for I := 1 to Length(Rest) do Put(Rest[I]);
        Exit;
      end;
    end;
  end;
  { plain text: what is held goes out as it is }
  FHolding := False;
  T := FHold;
  FHold := '';
  for I := 1 to Length(T) do Put(T[I]);
end;

procedure TAiMarkdown.EndLine;
var
  T: WideString;
  I: Integer;
begin
  if FHolding then
  begin
    T := LeftTrimmed(FHold);
    if IsPrefix(Fence, T) then
    begin
      { a fence: the block opens or closes; the line itself is not shown }
      FInBlock := not FInBlock;
      FHold := '';
      Exit;
    end;
    T := FHold;
    FHold := '';
    for I := 1 to Length(T) do Put(T[I]);
  end;
  if FStar then
  begin
    FStar := False;
    Emit('*', CurrentStyle);
  end;
  Emit(#13, CurrentStyle);
  FHeading := False;
  FInline := False;
  FBold := False;
  FHolding := True;
end;

procedure TAiMarkdown.Add(const Text: WideString);
var
  I: Integer;
  C: WideChar;
begin
  for I := 1 to Length(Text) do
  begin
    C := Text[I];
    if C = #10 then Continue;
    if C = #13 then EndLine
    else if FHolding then
    begin
      FHold := FHold + C;
      Decide;
    end
    else Put(C);
  end;
  FlushRun;
end;

procedure TAiMarkdown.Finish;
var
  T: WideString;
  I: Integer;
begin
  if FHolding and (FHold <> '') then
  begin
    T := FHold;
    FHold := '';
    if not IsPrefix(Fence, LeftTrimmed(T)) then
    begin
      FHolding := False;
      for I := 1 to Length(T) do Put(T[I]);
    end;
  end;
  if FStar then Emit('*', CurrentStyle);
  FlushRun;
  Reset;
end;

end.
