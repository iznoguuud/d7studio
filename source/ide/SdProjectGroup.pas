{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdProjectGroup;

{ D7 Studio - project groups: Delphi 7's .bpg, a makefile. The
  targets of PROJECTS are the group's projects in their order, each made from its project file:

    PROJECTS = Project1.exe Package1.bpl
    ...
    Project1.exe: Project1.dpr
      $(DCC)

  D7 Studio reads the targets and their project files (relative to the .bpg) and writes the file
  as Delphi does. A group without a file is ProjectGroup1 until it is saved.

  The group owns the projects it has loaded (Delphi's TWorkspace: every project of a group is
  loaded while the group is open): one TSdProject per project file, made when the group opens or
  the project joins it, freed when it leaves the group or the group closes. An entry without one
  is a closed project (IOTAModule.CloseModule: it stays in the group, Activate loads it again).
  Which project is active is the main window's to say (Active).

  The packages open beside the group are loaded and owned here too, in a list of their own
  (Delphi's misc projects: File | Open, Open Project, Reopen and File | New open a package so while
  a group is open - Delphi's package create mode 1). They are no entries of the group - not in its
  file or IOTAProjectGroup; the Project Manager shows them after it -, yet one of them can be the
  active project, and they own their units as the group's projects do (OwnersOf, ProjectForFile). }

interface

uses
  SysUtils, Classes, SdProject;

type
  TSdProjectGroup = class
  private
    FFileName: string;
    FProjects: TStringList;          // full names of the .dpr / .dpk files; Objects: the loaded TSdProject (owned), nil closed
    FBeside: TStringList;            // ... of the packages open beside the group; Objects: the TSdProject (owned)
    FActive: TSdProject;
    FModified: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    { no project, no file: every loaded project of the group freed (the packages beside it stay, and
      so does Active when it is one of them) }
    procedure Clear;
    { the projects of a .bpg, none of them loaded yet (an empty group before) }
    procedure Load(const FileName: string);
    procedure Save(const FileName: string);
    function Add(const ProjectFile: string): Integer;      // nothing twice
    { P joins the group (owned; nothing twice: an entry of its file takes it) }
    function AddLoaded(P: TSdProject): Integer;
    { the entry goes, its project freed (Active nil when it was the active one) }
    procedure Remove(const ProjectFile: string);
    procedure Delete(Index: Integer);
    { the entry goes, its project not freed (nil: it was closed) - it goes beside the group }
    function ExtractProject(Index: Integer): TSdProject;
    function IndexOf(const ProjectFile: string): Integer;
    function IndexOfProject(P: TSdProject): Integer;
    function Count: Integer;
    { the loaded project of an entry / of a project file; nil: closed (or no entry) }
    function Project(Index: Integer): TSdProject;
    function ProjectOf(const ProjectFile: string): TSdProject;
    { an entry's project: a loaded one put in (the entry owns it), or nil - the one there freed }
    procedure SetProject(Index: Integer; P: TSdProject);
    { an entry under another project file (Save Project As) }
    procedure Rename(Index: Integer; const NewFile: string);
    { ... the entry of loaded project P: the group's (it changes) or a package's beside it }
    procedure RenameProject(P: TSdProject; const NewFile: string);
    function LoadedCount: Integer;
    { the packages open beside the group (Delphi's misc projects), in the order they opened }
    function BesideCount: Integer;
    function Beside(Index: Integer): TSdProject;              // nil: no such entry
    function IndexOfBeside(const ProjectFile: string): Integer;
    function IsBeside(P: TSdProject): Boolean;
    procedure AddBeside(P: TSdProject);                       // owned from now on
    function ExtractBeside(Index: Integer): TSdProject;       // out of the list, not freed (it joins the group)
    procedure DeleteBeside(Index: Integer);                   // out of the list, freed (Active nil when it was)
    { the first loaded project: the group's, else the first package beside it; nil: none }
    function FirstLoaded: TSdProject;
    { every project, loaded or listed: the group's entries (nil: closed), then the packages beside
      it - its project and its project file }
    function AllCount: Integer;
    function AllProject(Index: Integer): TSdProject;
    function AllFile(Index: Integer): string;
    { the loaded project of a project file: the group's, else a package beside it; nil: none }
    function LoadedProjectOf(const ProjectFile: string): TSdProject;
    { the loaded projects whose project file or unit FileName is: the group's in its order, then the
      packages beside it }
    procedure OwnersOf(const FileName: string; Owners: TList);
    { ... the first of them; nil: none }
    function FirstOwnerOf(const FileName: string): TSdProject;
    { Delphi's rule for the project of a file (TUnitModule.GetActiveProject, the kibitz compile):
      the active project when it owns the file, else its first owner, else the active project, else
      the first package beside the group (Delphi's GetFirstMiscProject) }
    function ProjectForFile(const FileName: string): TSdProject;
    { the target of entry Index (ProjectTarget): a loaded project's from the source it parsed, a
      closed one's from its file }
    function Target(Index: Integer): string;
    function Name: string;                                 // ProjectGroup1, or the file's name
    property FileName: string read FFileName;
    property Projects: TStringList read FProjects;
    property Active: TSdProject read FActive write FActive;
    property Modified: Boolean read FModified write FModified;
  end;

function IsProjectGroupFile(const FileName: string): Boolean;
{ the target a project file makes: Project1.exe, Library1.dll, Package1.bpl }
function ProjectTarget(const ProjectFile: string): string;

implementation

uses
  SdFileNames;

function IsProjectGroupFile(const FileName: string): Boolean;
begin
  Result := SameText(ExtractFileExt(FileName), '.bpg');
end;

{ the target of a project file as its kind makes it: a package's .bpl, a library's .dll (its source
  starts with "library", comments skipped - as TSdProject decides it), else a program's .exe }
function TargetOfKind(const ProjectFile: string; Package, Lib: Boolean): string;
begin
  if Package then Result := ChangeFileExt(ExtractFileName(ProjectFile), '.bpl')
  else if Lib then Result := ChangeFileExt(ExtractFileName(ProjectFile), '.dll')
  else Result := ChangeFileExt(ExtractFileName(ProjectFile), '.exe');
end;

function ProjectTarget(const ProjectFile: string): string;
var
  Package: Boolean;
begin
  Package := IsPackageFile(ProjectFile);
  Result := TargetOfKind(ProjectFile, Package,
    not Package and FileExistsU(ProjectFile) and SourceIsLibrary(ReadFileU(ProjectFile)));
end;

{ the entry of L whose project file is ProjectFile; -1: none }
function IndexIn(L: TStrings; const ProjectFile: string): Integer;
begin
  for Result := 0 to L.Count - 1 do
    if SameText(L[Result], ProjectFile) then Exit;
  Result := -1;
end;

{ the loaded project of entry Index of L; nil: closed, or no such entry }
function LoadedIn(L: TStrings; Index: Integer): TSdProject;
begin
  if (Index >= 0) and (Index < L.Count) then Result := TSdProject(L.Objects[Index]) else Result := nil;
end;

constructor TSdProjectGroup.Create;
begin
  inherited Create;
  FProjects := TStringList.Create;
  FBeside := TStringList.Create;
end;

destructor TSdProjectGroup.Destroy;
begin
  Clear;
  while FBeside.Count > 0 do DeleteBeside(0);
  FBeside.Free;
  FProjects.Free;
  inherited Destroy;
end;

procedure TSdProjectGroup.Clear;
var
  I: Integer;
begin
  if not IsBeside(FActive) then FActive := nil;
  for I := 0 to FProjects.Count - 1 do
  begin
    FProjects.Objects[I].Free;
    FProjects.Objects[I] := nil;
  end;
  FFileName := '';
  FProjects.Clear;
  FModified := False;
end;

function TSdProjectGroup.Name: string;
begin
  if FFileName <> '' then Result := ChangeFileExt(ExtractFileName(FFileName), '') else Result := 'ProjectGroup1';
end;

function TSdProjectGroup.IndexOf(const ProjectFile: string): Integer;
begin
  Result := IndexIn(FProjects, ProjectFile);
end;

function TSdProjectGroup.IndexOfProject(P: TSdProject): Integer;
begin
  if P = nil then Result := -1 else Result := FProjects.IndexOfObject(P);
end;

function TSdProjectGroup.Count: Integer;
begin
  Result := FProjects.Count;
end;

function TSdProjectGroup.Project(Index: Integer): TSdProject;
begin
  Result := LoadedIn(FProjects, Index);
end;

function TSdProjectGroup.ProjectOf(const ProjectFile: string): TSdProject;
begin
  Result := Project(IndexOf(ProjectFile));
end;

function TSdProjectGroup.LoadedCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FProjects.Count - 1 do
    if FProjects.Objects[I] <> nil then Inc(Result);
end;

function TSdProjectGroup.BesideCount: Integer;
begin
  Result := FBeside.Count;
end;

function TSdProjectGroup.Beside(Index: Integer): TSdProject;
begin
  Result := LoadedIn(FBeside, Index);
end;

function TSdProjectGroup.IndexOfBeside(const ProjectFile: string): Integer;
begin
  Result := IndexIn(FBeside, ProjectFile);
end;

function TSdProjectGroup.IsBeside(P: TSdProject): Boolean;
begin
  Result := (P <> nil) and (FBeside.IndexOfObject(P) >= 0);
end;

procedure TSdProjectGroup.AddBeside(P: TSdProject);
begin
  FBeside.AddObject(P.FileName, P);
end;

function TSdProjectGroup.ExtractBeside(Index: Integer): TSdProject;
begin
  Result := Beside(Index);
  if Result <> nil then FBeside.Delete(Index);
end;

procedure TSdProjectGroup.DeleteBeside(Index: Integer);
var
  P: TSdProject;
begin
  P := ExtractBeside(Index);
  if P = FActive then FActive := nil;
  P.Free;
end;

function TSdProjectGroup.FirstLoaded: TSdProject;
var
  I: Integer;
begin
  for I := 0 to AllCount - 1 do
  begin
    Result := AllProject(I);
    if Result <> nil then Exit;
  end;
  Result := nil;
end;

function TSdProjectGroup.AllCount: Integer;
begin
  Result := FProjects.Count + FBeside.Count;
end;

function TSdProjectGroup.AllProject(Index: Integer): TSdProject;
begin
  if Index < FProjects.Count then Result := Project(Index) else Result := Beside(Index - FProjects.Count);
end;

function TSdProjectGroup.AllFile(Index: Integer): string;
begin
  if Index < FProjects.Count then Result := FProjects[Index] else Result := FBeside[Index - FProjects.Count];
end;

function TSdProjectGroup.LoadedProjectOf(const ProjectFile: string): TSdProject;
begin
  Result := ProjectOf(ProjectFile);
  if Result = nil then Result := Beside(IndexOfBeside(ProjectFile));
end;

function TSdProjectGroup.Add(const ProjectFile: string): Integer;
begin
  Result := IndexOf(ProjectFile);
  if Result >= 0 then Exit;
  Result := FProjects.Add(ProjectFile);
  FModified := True;
end;

function TSdProjectGroup.AddLoaded(P: TSdProject): Integer;
begin
  Result := Add(P.FileName);
  SetProject(Result, P);
end;

procedure TSdProjectGroup.SetProject(Index: Integer; P: TSdProject);
var
  Old: TObject;
begin
  if (Index < 0) or (Index >= FProjects.Count) then Exit;
  Old := FProjects.Objects[Index];
  if Old = P then Exit;
  FProjects.Objects[Index] := P;
  if Old = FActive then FActive := nil;
  Old.Free;
end;

procedure TSdProjectGroup.RenameProject(P: TSdProject; const NewFile: string);
var
  I: Integer;
begin
  I := FBeside.IndexOfObject(P);
  if I >= 0 then FBeside[I] := NewFile else Rename(IndexOfProject(P), NewFile);
end;

procedure TSdProjectGroup.Rename(Index: Integer; const NewFile: string);
begin
  if (Index < 0) or (Index >= FProjects.Count) or (FProjects[Index] = NewFile) then Exit;
  FProjects[Index] := NewFile;
  FModified := True;
end;

procedure TSdProjectGroup.Delete(Index: Integer);
begin
  if (Index < 0) or (Index >= FProjects.Count) then Exit;
  SetProject(Index, nil);
  FProjects.Delete(Index);
  FModified := True;
end;

function TSdProjectGroup.ExtractProject(Index: Integer): TSdProject;
begin
  Result := nil;
  if (Index < 0) or (Index >= FProjects.Count) then Exit;
  Result := TSdProject(FProjects.Objects[Index]);
  FProjects.Delete(Index);
  FModified := True;
end;

procedure TSdProjectGroup.Remove(const ProjectFile: string);
begin
  Delete(IndexOf(ProjectFile));
end;

{ P, a loaded project (nil: none), has FileName as its project file or as one of its units }
function OwnedBy(P: TSdProject; const FileName: string): Boolean;
begin
  Result := (P <> nil) and (FileName <> '') and (SameText(P.FileName, FileName) or (P.FindUnit(FileName) <> nil));
end;

procedure TSdProjectGroup.OwnersOf(const FileName: string; Owners: TList);
var
  I: Integer;
begin
  Owners.Clear;
  for I := 0 to AllCount - 1 do
    if OwnedBy(AllProject(I), FileName) then Owners.Add(AllProject(I));
end;

function TSdProjectGroup.FirstOwnerOf(const FileName: string): TSdProject;
var
  I: Integer;
begin
  for I := 0 to AllCount - 1 do
  begin
    Result := AllProject(I);
    if OwnedBy(Result, FileName) then Exit;
  end;
  Result := nil;
end;

function TSdProjectGroup.ProjectForFile(const FileName: string): TSdProject;
begin
  if OwnedBy(FActive, FileName) then Result := FActive else Result := FirstOwnerOf(FileName);
  if Result = nil then Result := FActive;
  if Result = nil then Result := Beside(0);
end;

function TSdProjectGroup.Target(Index: Integer): string;
var
  P: TSdProject;
begin
  P := Project(Index);
  if P = nil then Result := ProjectTarget(FProjects[Index])
  else Result := TargetOfKind(FProjects[Index], P.IsPackage, P.IsLibrary);
end;

{ the logical lines (a line that ends with \ goes on), the targets of PROJECTS, the rules
  "target: source" }
procedure TSdProjectGroup.Load(const FileName: string);
var
  Raw, Lines, Targets, Sources: TStringList;
  I, P: Integer;
  S, Cur, T: string;
begin
  Clear;
  FFileName := FileName;
  Raw := TStringList.Create;
  Lines := TStringList.Create;
  Targets := TStringList.Create;
  Sources := TStringList.Create;
  try
    Raw.Text := ReadFileU(FileName);
    Cur := '';
    for I := 0 to Raw.Count - 1 do
    begin
      S := TrimRight(Raw[I]);
      if (S <> '') and (S[Length(S)] = '\') then
        Cur := Cur + Copy(S, 1, Length(S) - 1) + ' '
      else
      begin
        Lines.Add(Cur + S);
        Cur := '';
      end;
    end;
    for I := 0 to Lines.Count - 1 do
    begin
      S := Lines[I];
      if (S = '') or (S[1] in ['#', '!', ' ', #9]) then Continue;
      if SameText(Trim(Copy(S, 1, Pos('=', S) - 1)), 'PROJECTS') then
      begin
        Targets.Text := StringReplace(Trim(Copy(S, Pos('=', S) + 1, MaxInt)), ' ', #13#10, [rfReplaceAll]);
        Continue;
      end;
      P := Pos(':', S);
      if (P > 1) and (Pos('=', S) = 0) then
      begin
        T := Trim(Copy(S, 1, P - 1));
        if SameText(T, 'default') then Continue;
        Sources.Values[T] := Trim(Copy(S, P + 1, MaxInt));
      end;
    end;
    for I := 0 to Targets.Count - 1 do
    begin
      T := Trim(Targets[I]);
      if T = '' then Continue;
      S := Sources.Values[T];
      if S = '' then Continue;
      if ExtractFileDrive(S) = '' then S := ExpandFileName(ExtractFilePath(FileName) + S);
      if IndexOf(S) < 0 then FProjects.Add(S);
    end;
  finally
    Sources.Free;
    Targets.Free;
    Lines.Free;
    Raw.Free;
  end;
  FModified := False;
end;

procedure TSdProjectGroup.Save(const FileName: string);
const
  Bar = '#------------------------------------------------------------------------------';
var
  L, Targets: TStringList;
  I: Integer;
  T, Rel: string;
begin
  L := TStringList.Create;
  Targets := TStringList.Create;
  try
    for I := 0 to FProjects.Count - 1 do Targets.Add(Target(I));
    L.Add(Bar);
    L.Add('VERSION = BWS.01');
    L.Add(Bar);
    L.Add('!ifndef ROOT');
    L.Add('ROOT = $(MAKEDIR)\..');
    L.Add('!endif');
    L.Add(Bar);
    L.Add('MAKE = $(ROOT)\bin\make.exe -$(MAKEFLAGS) -f$**');
    L.Add('DCC = $(ROOT)\bin\dcc32.exe $**');
    L.Add('BRCC = $(ROOT)\bin\brcc32.exe $**');
    L.Add(Bar);
    T := '';
    for I := 0 to Targets.Count - 1 do T := T + ' ' + Targets[I];
    L.Add('PROJECTS =' + T);
    L.Add(Bar);
    L.Add('default: $(PROJECTS)');
    L.Add(Bar);
    L.Add('');
    for I := 0 to FProjects.Count - 1 do
    begin
      Rel := ExtractRelativePath(ExtractFilePath(ExpandFileName(FileName)), FProjects[I]);
      L.Add(Targets[I] + ': ' + Rel);
      L.Add('  $(DCC)');
      L.Add('');
    end;
    L.Add('');
    WriteFileU(FileName, L.Text);
  finally
    Targets.Free;
    L.Free;
  end;
  FFileName := FileName;
  FModified := False;
end;

end.
