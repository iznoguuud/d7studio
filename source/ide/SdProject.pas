{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdProject;

{ D7 Studio - project model (.dpr / .dof / .cfg) and the compiler driver (dcc32 of Delphi 7,
  dcc64 of RAD Studio for the Win64 target). }

interface

uses
  Windows, SysUtils, Classes, IniFiles, Contnrs, Forms, SdEncoding;

type
  { the target platform of a project: Win32 is built by Delphi 7's dcc32, Win64 by the dcc64 of
    an installed RAD Studio }
  TSdPlatform = (spWin32, spWin64);
  { what the manifest of a program declares about the screen's DPI (Project | Options |
    Application | DPI awareness); unaware
    declares nothing - Windows scales the program, as without the option }
  TSdDpiAwareness = (daUnaware, daSystemAware, daPerMonitor, daPerMonitorV2);
  { the rights a program asks Windows for when it starts (Project | Options | Application |
    Execution level): the rights of the user who starts it, the highest that user can have, an
    administrator's - the manifest's requestedExecutionLevel }
  TSdExecutionLevel = (elAsInvoker, elHighestAvailable, elRequireAdministrator);
  { the Windows a Win32 program is built for (Project | Options | Application | Target Windows):
    Windows 10 1903 or later with UTF-8 as its code page, Windows Vista or later in the system
    code page, Windows XP or later in the system code page with a program header of version 5.1 }
  TSdTargetWindows = (twWindows10Utf8, twVista, twWindowsXP);

  TProjectUnit = class
  public
    Name: string;        // unit name
    FileName: string;    // full path of the .pas file
    FormName: string;    // '' when the unit has no form
    function HasForm: Boolean;
    function FormFileName: string;
  end;

  { a resource script of the project source - a $R directive with two names (SdFormSrc.
    DprGetResScripts): the script, FileName, that the IDE compiles with Delphi 7's brcc32 into
    ResFileName, the .res the compiler links. Name is the script's file name, as the Project
    Manager shows it; FormName stays empty }
  TProjectResScript = class(TProjectUnit)
  public
    ResFileName: string;     // full path of the .res
    RelRes, RelRc: string;   // the two names as the directive writes them
  end;

  { the text of a file as the IDE has it (an open editor's, else the file's); raises when there
    is none }
  TSdSourceFunc = function(const FileName: string): string of object;
  { the bytes of a file as Save would write them, when an editor has it with unsaved changes
    (True); False: the file on the disk is the one to take }
  TSdUnsavedFunc = function(const FileName: string; out Bytes: string): Boolean of object;

  TSdProject = class
  private
    FFileName: string;
    FRenamedFrom: string;                    // the file before a Rename the next SaveOptions completes
    FUnits: TObjectList;
    FDof: TMemIniFile;
    FLibPrefix, FLibSuffix: string;          // {$LIBPREFIX}/{$LIBSUFFIX} of a package
    FDescription: string;                    // {$DESCRIPTION} of a package
    FRunOnly: Boolean;                       // {$RUNONLY}
    FLibrary: Boolean;                       // the source starts with "library"
    FRequires: TStringList;                  // the requires clause of a package
    FResScripts: TObjectList;                // TProjectResScript: the resource scripts
    function GetUnit(Index: Integer): TProjectUnit;
    function GetResScript(Index: Integer): TProjectResScript;
    function GetDir: string;
    function GetName: string;
    { a folder option of Directories/Conditionals as the compiler needs it: $(DELPHI), $(NAME)
      ... expanded (Delphi expands them when it writes the .cfg; dcc32 does not know them) }
    function DirOpt(const Key: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load(const AFileName: string);
    { under another name in memory (Delphi 7's IOTAModule.FileName of a project): nothing written - the
      options go to the new .dof with the next SaveOptions, which copies the old .res there as well }
    procedure Rename(const AFileName: string);
    { the default options instead of a project (Project Options without a project, Install
      Packages): saved as D7 Studio's defproj.dof }
    procedure LoadDefaults;
    function IsDefaults: Boolean;
    { Project Options | Default: these options become the default ones of new projects }
    procedure SaveAsDefaults;
    { the units and resource scripts of the project source - Source: the editor's text of it, in
      its encoding E (a code page's text is its bytes); the file names become D7 Studio's text }
    procedure ParseSource(const Source: string; const E: TSdEncoding);
    { the .dof (safely: the old one stays when the write fails) and the .cfg. SaveOptions,
      SaveAsDefaults and WriteCfg raise EInOutError (the file and the reason) when a file cannot
      be written - nothing is lost silently }
    procedure SaveOptions;
    { the options for dcc32 in <project>.cfg; a scratch build (TSdScratchBuild) writes its own
      (CfgFile) with an explicit output folder and ExtraDirs searched for include files and
      resources first. A .cfg that already says this is not written again (it may be read-only).
      Utf8: for the UTF-8 compiler (Dcc32Utf8Exe), which reads it as UTF-8; else it is in the
      system code page }
    procedure WriteCfg(const CfgFile: string = ''; const ExtraDirs: string = ''; Utf8: Boolean = False);
    function UnitCount: Integer;
    function FindUnit(const AFileName: string): TProjectUnit;
    function FindUnitByName(const AName: string): TProjectUnit;
    { the resource scripts of the source last parsed, in their order; the one of a .rc, nil none }
    function ResScriptCount: Integer;
    function FindResScript(const AFileName: string): TProjectResScript;
    function ExeName: string;                // the program, library or package (.bpl) the compiler makes
    function TargetExt: string;              // ... the extension of a program or library (no dot)
    function IsLibrary: Boolean;             // of the source last parsed (Load, ParseSource)
    function IsPackage: Boolean;             // a .dpk
    function IsRunOnly: Boolean;             // a package with {$RUNONLY}: cannot be installed
    { the folders of a package's .bpl and .dcp: the options (Directories), else Delphi 7's
      (Tools | Environment Options | Library: Projects\Bpl) }
    function PackageOutputDir: string;
    function DcpOutputDir: string;
    { the .dcp of a required package where the compiler looks for it (the .dcp folder, the
      project's folder and search path, the library path); '' when it is in none of them }
    function FindDcp(const Package: string): string;
    function UsesThemes: Boolean;            // Project | Options | Application: runtime themes
    { the unit is named in the project source or one of its units; Source gives a file's text -
      the editor's where it has the file (unsaved changes count); nil: the files on disk }
    function UsesUnit(const UnitName: string; Source: TSdSourceFunc = nil): Boolean;
    { the first of Names (in their order) that the project source or one of its units names, each
      file read once (Source as for UsesUnit); -1: none of them }
    function FirstUsedUnit(const Names: array of string; Source: TSdSourceFunc = nil): Integer;
    function Platform: TSdPlatform;          // Project | Options | Compiler: target platform
    procedure SetPlatform(Value: TSdPlatform);
    { Project | Options | Application: DPI awareness, as it is set (a library or a package has
      it set but gets no manifest) }
    function DpiAwareness: TSdDpiAwareness;
    procedure SetDpiAwareness(Value: TSdDpiAwareness);
    { Project | Options | Application: Execution level, as it is set (a library or a package has it
      set but gets none); as invoker by default }
    function ExecutionLevel: TSdExecutionLevel;
    procedure SetExecutionLevel(Value: TSdExecutionLevel);
    { what D7 Studio's manifest for the project asks for (Project | Options | Application): the
      visual styles, the DPI awareness, UTF-8 as the code page, the execution level - a library or
      a package runs in its host's process: none of them }
    procedure ManifestOptions(out Themes: Boolean; out Dpi: TSdDpiAwareness; out Utf8: Boolean;
      out Level: TSdExecutionLevel);
    { the file a $R of the project source names (Name: the editor's text, in E): * the project's
      name, .res when it has no extension, from the project's folder }
    function ResPath(const Name: string; const E: TSdEncoding): string;
    { the program's own manifest: the first manifest D7 Studio did not write in a .res the project
      source links (Source: the editor's text, in E) - its own .res ($R *.res), a resource
      script's, a file of its own -; False when none of them holds one }
    function LinkedManifest(const Source: string; const E: TSdEncoding; out Data: string): Boolean;
    { Project | Options | Application: Target Windows, as it is set (a Win64 program, a library or
      a package has it set, and it does nothing there); Windows 10 1903 or later by default. The
      .dof keeps it as two keys, Utf8CodePage and WindowsXP }
    function TargetWindows: TSdTargetWindows;
    procedure SetTargetWindows(Value: TSdTargetWindows);
    { Project | Options | Application: the program runs with UTF-8 as its code page - its manifest
      says so (Windows 10 1903 on) and dcc32 compiles its sources as UTF-8: Target Windows is
      Windows 10 1903 or later, the default; a Win32 program only (a library or a package runs in
      its host's code page) }
    function Utf8CodePage: Boolean;
    { Project | Options | Linker: the program's PE header as for Windows Vista and later - version
      6.0, DEP, ASLR, terminal-server aware (SdPEHeader); on by default; a Win32 program only }
    function ModernHeader: Boolean;
    { Project | Options | Application: Target Windows is Windows XP or later - the modern header
      gets version 5.1 instead of 6.0; a Win32 program only }
    function WindowsXP: Boolean;
    { the folders of the program and of the units; for Win64 the subfolder Win64 of the options'
      folders (the units of the two compilers must not meet) }
    function OutputDir: string;
    function UnitOutputDir: string;          // '' = each unit next to its source (Win32 only)
    procedure MakeOutputDirs;                // dcc64 does not create them
    function SearchPathList: string;
    { the folders dcc32 looks for units in after the project's folder - the -U of the .cfg: the
      search path, a package's .dcp folder, Use Debug DCUs' folder, the library path (';' between
      them, relative ones from the project's folder) }
    function UnitSearchPath: string;
    { the source files dcc32 may compile for the project beyond its own units: the units its
      sources use - and theirs in turn - found as <name>.pas in the project's folder or along
      UnitSearchPath, dcc32's order (a unit found nowhere is a DCU's: Delphi's Lib). Source gives
      a file's text, the editor's or the file's; Files gets their full names }
    procedure OtherSourceUnits(Source: TSdSourceFunc; Files: TStrings);
    function FullPath(const Path: string): string;   // a path of the options or the source: from the project folder
    { option access (kept in the Delphi 7 .dof layout) }
    function OptStr(const Section, Key, Default: string): string;
    function OptInt(const Section, Key: string; Default: Integer): Integer;
    { the conditional defines of Directories/Conditionals, a line each (trimmed, no empty one) }
    function Conditionals: string;
    procedure SetOptStr(const Section, Key, Value: string);
    procedure SetOptInt(const Section, Key: string; Value: Integer);
    property FileName: string read FFileName;
    property Dir: string read GetDir;
    property Name: string read GetName;
    property Units[Index: Integer]: TProjectUnit read GetUnit;
    property ResScripts[Index: Integer]: TProjectResScript read GetResScript;
    property Dof: TMemIniFile read FDof;               // the options file (history lists ...)
    property Requires: TStringList read FRequires;     // the packages a package requires
    property Description: string read FDescription;    // of a package
  end;

  { a warning of Project Options | Compiler Messages: its key in the .dof [Compiler] section, its
    identifier for the compiler ($WARN, -w-), its text in the list }
  TCompilerWarning = record
    Key, Ident, Text: string;
  end;

  TMsgKind = (mkInfo, mkHint, mkWarning, mkError, mkFatal);

  TCompilerMessage = class
  public
    Kind: TMsgKind;
    FileName: string;
    Line: Integer;
    Column: Integer;    // 0: none (the compiler's); an expert's message may name one
    Text: string;       // the display line, Delphi style
  end;

  TCompileOutputEvent = procedure(const Line: string) of object;
  { the compiler reached Line of FileName; TotalLines = lines compiled so far in all files }
  TCompileProgressEvent = procedure(const FileName: string; Line, TotalLines: Integer) of object;

  TSdCompiler = class
  private
    FMessages: TObjectList;
    FErrors, FWarnings, FHints: Integer;
    FSummary: string;
    FExitCode: Cardinal;
    FOnOutput: TCompileOutputEvent;
    FOnProgress: TCompileProgressEvent;
    FRunning: Boolean;
    FCancelled: Boolean;
    FProcess: THandle;
    FLineCounts: TStringList;      // file name -> highest line reported so far
    FTotalLines: Integer;
    FNotes: TStringList;           // Note
    function GetMessage(Index: Integer): TCompilerMessage;
    procedure ParseLine(const Line, WorkDir, SearchPath: string);
    procedure Progress(const Segment: string);
  public
    constructor Create;
    destructor Destroy; override;
    { without -Q in Args dcc32 reports its position continuously (OnProgress) }
    function Run(const Dcc32, Args, WorkDir, SearchPath: string): Boolean;
    { what D7 Studio found about the sources it gives dcc32: Lines (as dcc32 writes its
      messages, with full file names) are the first messages of the next Run }
    procedure Note(Lines: TStrings);
    { the messages of a compile that failed before the compiler ran (a resource script, say):
      the notes of Note, then Lines - both as dcc32 writes its messages; False }
    function Fail(Lines: TStrings; const WorkDir: string): Boolean;
    procedure Cancel;              // stops a running compilation
    function MessageCount: Integer;
    property Messages[Index: Integer]: TCompilerMessage read GetMessage;
    property Errors: Integer read FErrors;
    property Warnings: Integer read FWarnings;
    property Hints: Integer read FHints;
    property Summary: string read FSummary;
    property Running: Boolean read FRunning;
    property Cancelled: Boolean read FCancelled;
    property TotalLines: Integer read FTotalLines;
    property OnOutput: TCompileOutputEvent read FOnOutput write FOnOutput;
    property OnProgress: TCompileProgressEvent read FOnProgress write FOnProgress;
  end;

  { Delphi compiles what the editor shows, not what is on disk, and does not save first. A
    project with unsaved files is therefore compiled from a scratch folder: the unsaved units
    with their forms, a copy of the project source whose "in" paths point at them and the
    .cfg. dcc32 compiles that copy in the project folder: the scratch folder of the project
    source is searched first, everything else comes from the usual places. }
  TSdScratchBuild = class
  private
    FDir: string;                        // '' until the first file is written
    FScratch, FReal: TStringList;        // a file in the scratch folder -> the real file
    FUtf8Compiler: Boolean;
    function NewName(const RealName: string): string;
    procedure Add(const ScratchName, RealName: string);
    procedure Put(const ScratchName, RealName, Bytes: string);
  public
    constructor Create;
    destructor Destroy; override;
    { an unsaved unit: Bytes = the file as Save would write it, Dfm = its form ('' = none) }
    procedure AddUnit(const RealName, Bytes, Dfm: string);
    { another file the compile reads as the IDE holds it: the project's .res with the unsaved
      resource pages (beside the project source, where dcc32 looks for its $R *.res first) }
    procedure AddFile(const RealName, Bytes: string);
    { writes the project source and the .cfg; the result is the project file to compile }
    function Prepare(Project: TSdProject; const ProjectSource: string): string;
    { S (a file name or a message) with the real names in place of the scratch ones }
    function RealNames(const S: string): string;
    { removes the scratch folder, and from UnitDir the units compiled from scratch files: a
      later make would take them for up to date (dcc32 only checks that a source is not newer
      than its .dcu) }
    procedure Finish(const UnitDir: string);
    { the compile runs the UTF-8 compiler (Dcc32Utf8Exe): Prepare writes the copies' names into
      the project source and the .cfg in UTF-8; Finish sets it back }
    property Utf8Compiler: Boolean read FUtf8Compiler write FUtf8Compiler;
  end;

  { The include files ($I, $INCLUDE) of the sources a compile gives the compiler reach it as
    they are, where a unit goes to it converted (CodePageSource). Check reads a source's includes
    as dcc32 does - its conditional directives applied with Delphi 7's symbols and the project's
    conditionals; a name without extension is a .pas; found in the unit's folder, then in the -I
    folders (UnitSearchPath), then in the project's folder; a nested one from the unit's folder
    too - and one in another encoding than the units go to the compiler in (Utf8: UTF-8 without
    byte order mark, else a code page) is a warning line in Warnings, as dcc32 writes one, at its
    first character beyond ASCII: once per file. HighLiterals: an include file in the units'
    encoding has a string literal beyond ASCII (HasHighLiteral) - asked only with
    FindHighLiterals. }
  TSdIncludeCheck = class
  private
    FUtf8: Boolean;
    FWarnings: TStrings;
    FDefines: TStringList;               // the project's conditionals
    FDirs: TStringList;                  // the -I folders and the project's folder, with '\'
    FFiles, FTexts: TStringList;         // an include file read (full name) and its editor text
    FUnitDir: string;                    // the folder of the source being read ...
    FEncoding: TSdEncoding;              // ... and its encoding, the one of the names it includes
    FFindHighLiterals, FHighLiterals: Boolean;
    function FindInclude(const IncName: string): string;
    function Include(const IncName: string; var Text: string): Boolean;
  public
    constructor Create(Project: TSdProject; Utf8: Boolean; Warnings: TStrings);
    destructor Destroy; override;
    { the includes of the source FileName, Text its editor text of encoding E }
    procedure Check(const FileName, Text: string; const E: TSdEncoding);
    property FindHighLiterals: Boolean read FFindHighLiterals write FFindHighLiterals;
    property HighLiterals: Boolean read FHighLiterals;
  end;

{ Delphi 7 compiles code-page text only: the bytes dcc32 reads for a source held in
  encoding E (Text: its editor text). False: the file's own bytes do - a code page, or UTF-8
  without byte order mark that is all ASCII (or that has to stay UTF-8, below). True: Bytes = the
  text in the system code page - a character the code page lacks becomes '?' in a comment; in a
  string, a directive or anywhere else the file stays its UTF-8 bytes, as Delphi 7 reads it (its
  byte order mark dropped), and its line is added to Warnings as dcc32 writes a warning
  (FileName: the full name). Utf8: a program with UTF-8 as its code page (TSdProject.Utf8CodePage)
  - its literals must be UTF-8: True when the file's bytes are not UTF-8 without byte order mark,
  Bytes = the text in UTF-8 (a code-page file converted; nothing is lost, no warning) }
function CodePageSource(const FileName, Text: string; const E: TSdEncoding; Warnings: TStrings;
  out Bytes: string; Utf8: Boolean = False): Boolean;
{ a string literal of the Pascal text has characters beyond ASCII (comments do not count) }
function HasHighLiteral(const Text: string): Boolean;
{ a text form file has text beyond ASCII: bytes, or character codes from #128 on }
function DfmBeyondAscii(const Dfm: string): Boolean;
function IsProjectFile(const FileName: string): Boolean;  // a program/library (.dpr) or package (.dpk)
function IsPackageFile(const FileName: string): Boolean;  // a package (.dpk)
function IsAbsolutePath(const Path: string): Boolean;     // "C:..." or "\..."
{ a project source that is a library's: its first word, comments skipped, is "library" }
function SourceIsLibrary(const Source: string): Boolean;
{ the project source links the project's resource file ($R *.res) }
function LinksProjectRes(const Source: string): Boolean;
{ Compiles the resource scripts of P (TSdProject.ResScripts) with Brcc32, Delphi 7's resource
  compiler, each one in its own folder - brcc32 takes the names in a script from its current
  folder: one whose .res is not there or is older than the script or than a file the script names
  (ResScriptInputs), every one for a Build, and one that an editor holds with unsaved changes
  (Unsaved: its text, compiled from a copy of the same name). Messages gets brcc32's errors and
  warnings as dcc32 writes its messages (full file names: TSdCompiler.Note, Fail). False: a script
  failed - the others are compiled all the same. }
function CompileResScripts(P: TSdProject; const Brcc32: string; Build: Boolean; Messages: TStrings;
  Unsaved: TSdUnsavedFunc = nil): Boolean;
{ the files a resource script names (icons, bitmaps, a manifest, an included header): every name
  in it, quoted or not, with a dot, that is a file from the script's folder - comments skipped }
procedure ResScriptInputs(const RcFile: string; Files: TStrings);
{ a folder for a list of folders, a compiler argument or a working directory: without its trailing
  backslash - but a drive's root keeps it ("D:" alone is the current folder of drive D) }
function FolderArg(const Dir: string): string;
function NewApplicationSource(const ProjName, UnitName, FormName: string): string;
{ a form's unit; an inherited form (visual form inheritance): the class derives from Ancestor,
  whose unit AncestorUnit joins the uses clause }
function NewFormUnitSource(const UnitName, FormName: string; const Ancestor: string = 'TForm';
  const AncestorUnit: string = ''): string;
function NewFormDfm(const FormName: string): string;
{ the .dfm of an inherited form: what it changes of its ancestor's (Delphi's "inherited") }
function NewInheritedFormDfm(const FormName: string): string;
function NewUnitSource(const UnitName: string): string;
function NewDataModuleSource(const UnitName, ModuleName: string): string;
function NewDataModuleDfm(const ModuleName: string): string;
function NewFrameSource(const UnitName, FrameName: string): string;
function NewFrameDfm(const FrameName: string): string;
{ Delphi 7's console application; LinkRes: with $R *.res after the uses clause, as Delphi 7's
  application has it - the .res that carries the program's icon and D7 Studio's manifest }
function NewConsoleSource(const ProjName: string; LinkRes: Boolean = False): string;
{ Requires: the packages of the requires clause, separated by commas }
function NewPackageSource(const PackageName: string; const Description: string = '';
  const Requires: string = 'rtl'): string;
{ Makes <project>.res ready for the compiler - when the project source links it ($R *.res):
  creates it with the default application icon when it does not exist, and sees that it
  carries the application manifest D7 Studio writes for the options - the visual styles of
  Windows (Themes), the DPI awareness (Dpi), UTF-8 as the code page (Utf8), the execution level
  (Level) -, or none of D7 Studio's when none is asked for (a manifest of the project's own is
  never touched). Note says what was done to the manifest. }
function EnsureProjectRes(const ProjectFile, Source: string; Themes: Boolean; Dpi: TSdDpiAwareness;
  Utf8: Boolean; Level: TSdExecutionLevel; var Note: string): Boolean;
{ the .res of a new project that links it ($R *.res): the default application icon and the visual
  styles' manifest, as for every new project - its first compile gives the manifest its options }
procedure NewProjectRes(const ProjectFile: string);
{ the options ask for a manifest: the visual styles, a DPI awareness other than unaware, UTF-8 or
  an execution level other than as invoker }
function ManifestAsked(Themes: Boolean; Dpi: TSdDpiAwareness; Utf8: Boolean; Level: TSdExecutionLevel): Boolean;
{ what a manifest of these options does, for Messages ("the visual styles of Windows, DPI awareness
  per monitor, UTF-8 code page (Project | Options | Application)"): the DPI awareness unless
  unaware, the execution level unless as invoker }
function ManifestSummary(Themes: Boolean; Dpi: TSdDpiAwareness; Utf8: Boolean; Level: TSdExecutionLevel): string;
{ what a manifest declares about the parts the options set, read from its text: the DPI awareness
  (dpiAwareness's first value, else dpiAware's), UTF-8 as the code page, the execution level - an
  element that is not there: unaware, the system code page, as invoker }
procedure ManifestDeclares(const Text: string; out Dpi: TSdDpiAwareness; out Utf8: Boolean;
  out Level: TSdExecutionLevel);
{ what the options ask for - a DPI awareness other than unaware, UTF-8, an execution level other
  than as invoker - that a manifest declaring HasDpi, HasUtf8 and HasLevel does not give, as
  ManifestSummary says it; '' when it gives all of it }
function ManifestMisses(Dpi: TSdDpiAwareness; Utf8: Boolean; Level: TSdExecutionLevel;
  HasDpi: TSdDpiAwareness; HasUtf8: Boolean; HasLevel: TSdExecutionLevel): string;
{ Run's TD32 debug information is kept apart from the program: Delphi 7's debugger takes it from its
  compiler in memory, so its programs carry
  none, but D7 Studio's debugger reads what the linker writes. The linker puts it into the last
  section, .debug; MoveDebugInfo writes the block into D7 Studio's Debug folder and takes the
  section out of the program, as Borland's tdstrp32 did. DebugInfoFile names the block kept for
  a program exactly as it is now (a hash of its bytes is part of the name: Delphi 7's linker writes
  the same link time into every program), '' when there is none. }
function MoveDebugInfo(const ExeName: string): Boolean;
function DebugInfoFile(const ExeName: string): string;
{ Project Options | Application | Icon: the icon group MAINICON of a project's .res, replaced
  by the images of an .ico stream (other resources stay) / written to Ico as an .ico file }
function SetProjectIcon(const ResFile: string; Ico: TStream): Boolean;
function ProjectIcon(const ResFile: string; Ico: TStream): Boolean;
{ the Resources view: a 32-bit resource file (one the view may write);
  the manifest D7 Studio writes for Project | Options; the text of a new manifest of the project's
  own - what the options would give (at least the visual styles), without D7 Studio's mark }
function ValidResFile(const ResFile: string): Boolean;
function IsIdeManifest(const Data: string): Boolean;
function OwnManifestText(Project: TSdProject): string;
{ Project Options | Version Info: puts the version resource into the project's .res (or takes it
  out when "Include version information" is off). AutoIncrement (a compile): the build number
  goes up first when the option asks for it, and the .dof is written; otherwise a compile keeps
  the version resource the .res has (an expert may have changed it) and only adds one that is
  missing. Raises EInOutError when the .dof or the .res cannot be written. }
function UpdateVersionInfo(Project: TSdProject; AutoIncrement: Boolean): Boolean;
{ the other way: the version resource of the project's .res (as an expert changed it) into the
  options - Version Info's numbers, flags, locale and keys - while the project includes version
  information; the .dof is written when anything differs (True). Raises EInOutError when the
  .dof cannot be written. }
function VersionInfoFromRes(Project: TSdProject): Boolean;
{ the version options as one text: what tells whether Project Options changed them }
function VersionOptionsText(Project: TSdProject): string;
{ "1.0.0.0" of the version numbers of the options }
function VersionString(Project: TSdProject): string;

{ dcc64.exe of the newest installed RAD Studio (Delphi XE2 or later), '' = none }
function Dcc64Exe: string;
{ the UTF-8 compiler: dcc32u8.exe in Delphi 7's Bin - its dcc32.exe under another name, which
  the manifest dcc32u8.exe.manifest beside it starts with UTF-8 as its code page (D7 Studio's
  Setup puts both there) - for the programs that run in UTF-8: it turns their UTF-8 text into
  UTF-16 right (resourcestring, WideString literals), where dcc32 decodes it with the system code
  page. '' = none }
function Dcc32Utf8Exe: string;
{ the folder of its 64-bit run-time packages (rtl290.bpl ...) }
function Win64PackageDir: string;

const
  { the project options of D7 Studio in the .dof (not Delphi 7 keys: a section of their own):
    "Enable runtime themes", the DPI awareness and the target platform }
  ThemeSection = 'D7 Studio';
  ThemeKey = 'ThemeManifest';
  { Target Windows (TSdProject.TargetWindows): Utf8CodePage=1 Windows 10 1903 or later (the
    default), WindowsXP=1 Windows XP or later, neither Windows Vista or later }
  Utf8Key = 'Utf8CodePage';
  Utf8Default = 1;
  WindowsXPKey = 'WindowsXP';
  ModernHeaderKey = 'ModernHeader';
  DpiKey = 'DpiAwareness';
  PlatformKey = 'Platform';
  { the DPI awareness as the .dof keeps it, and as Messages names it }
  DpiAwarenessKeys: array[TSdDpiAwareness] of string = ('Unaware', 'SystemAware', 'PerMonitor', 'PerMonitorV2');
  DpiAwarenessTexts: array[TSdDpiAwareness] of string = ('unaware', 'system aware', 'per monitor', 'per monitor v2');
  { the execution level as the .dof and the manifest's requestedExecutionLevel keep it }
  ExecutionLevelKey = 'ExecutionLevel';
  ExecutionLevelKeys: array[TSdExecutionLevel] of string = ('asInvoker', 'highestAvailable', 'requireAdministrator');
  { Target Windows as Messages names it }
  TargetWindowsTexts: array[TSdTargetWindows] of string = ('Windows 10 1903 or later', 'Windows Vista or later',
    'Windows XP or later');
  { Delphi 7's warnings, in the order of its .dof; on by default but the three "unsafe" ones }
  CompilerWarnings: array[0..47] of TCompilerWarning = (
    (Key: 'SymbolDeprecated'; Ident: 'SYMBOL_DEPRECATED'; Text: 'Deprecated symbol'),
    (Key: 'SymbolLibrary'; Ident: 'SYMBOL_LIBRARY'; Text: 'Library symbol'),
    (Key: 'SymbolPlatform'; Ident: 'SYMBOL_PLATFORM'; Text: 'Platform symbol'),
    (Key: 'UnitLibrary'; Ident: 'UNIT_LIBRARY'; Text: 'Library unit'),
    (Key: 'UnitPlatform'; Ident: 'UNIT_PLATFORM'; Text: 'Platform unit'),
    (Key: 'UnitDeprecated'; Ident: 'UNIT_DEPRECATED'; Text: 'Deprecated unit'),
    (Key: 'HResultCompat'; Ident: 'HRESULT_COMPAT'; Text: 'Integer and HRESULT interchanged'),
    (Key: 'HidingMember'; Ident: 'HIDING_MEMBER'; Text: 'Inherited member hidden'),
    (Key: 'HiddenVirtual'; Ident: 'HIDDEN_VIRTUAL'; Text: 'Inherited virtual method hidden'),
    (Key: 'Garbage'; Ident: 'GARBAGE'; Text: 'Text after final ''END.'''),
    (Key: 'BoundsError'; Ident: 'BOUNDS_ERROR'; Text: 'Constant expression violates subrange bounds'),
    (Key: 'ZeroNilCompat'; Ident: 'ZERO_NIL_COMPAT'; Text: 'Constant 0 converted to NIL'),
    (Key: 'StringConstTruncated'; Ident: 'STRING_CONST_TRUNCED'; Text: 'String constant truncated'),
    (Key: 'ForLoopVarVarPar'; Ident: 'FOR_LOOP_VAR_VARPAR'; Text: 'FOR-loop variable passed as var parameter'),
    (Key: 'TypedConstVarPar'; Ident: 'TYPED_CONST_VARPAR'; Text: 'Typed constant passed as var parameter'),
    (Key: 'AsgToTypedConst'; Ident: 'ASG_TO_TYPED_CONST'; Text: 'Assignment to typed constant'),
    (Key: 'CaseLabelRange'; Ident: 'CASE_LABEL_RANGE'; Text: 'Case label outside of range of case expression'),
    (Key: 'ForVariable'; Ident: 'FOR_VARIABLE'; Text: 'FOR-loop control variable must be a simple local variable'),
    (Key: 'ConstructingAbstract'; Ident: 'CONSTRUCTING_ABSTRACT'; Text: 'Constructing instance containing abstract methods'),
    (Key: 'ComparisonFalse'; Ident: 'COMPARISON_FALSE'; Text: 'Comparison always evaluates to False'),
    (Key: 'ComparisonTrue'; Ident: 'COMPARISON_TRUE'; Text: 'Comparison always evaluates to True'),
    (Key: 'ComparingSignedUnsigned'; Ident: 'COMPARING_SIGNED_UNSIGNED'; Text: 'Comparing signed and unsigned types'),
    (Key: 'CombiningSignedUnsigned'; Ident: 'COMBINING_SIGNED_UNSIGNED'; Text: 'Combining signed and unsigned types'),
    (Key: 'UnsupportedConstruct'; Ident: 'UNSUPPORTED_CONSTRUCT'; Text: 'Unsupported language feature'),
    (Key: 'FileOpen'; Ident: 'FILE_OPEN'; Text: 'File not found'),
    (Key: 'FileOpenUnitSrc'; Ident: 'FILE_OPEN_UNITSRC'; Text: 'Unit source file not found'),
    (Key: 'BadGlobalSymbol'; Ident: 'BAD_GLOBAL_SYMBOL'; Text: 'Bad global symbol definition'),
    (Key: 'DuplicateConstructorDestructor'; Ident: 'DUPLICATE_CTOR_DTOR'; Text: 'Duplicate constructor or destructor'),
    (Key: 'InvalidDirective'; Ident: 'INVALID_DIRECTIVE'; Text: 'Invalid compiler directive'),
    (Key: 'PackageNoLink'; Ident: 'PACKAGE_NO_LINK'; Text: 'Package will not be linked'),
    (Key: 'PackageThreadVar'; Ident: 'PACKAGED_THREADVAR'; Text: 'Packaged thread variable'),
    (Key: 'ImplicitImport'; Ident: 'IMPLICIT_IMPORT'; Text: 'Unit implicitly imported into package'),
    (Key: 'HPPEMITIgnored'; Ident: 'HPPEMIT_IGNORED'; Text: '$HPPEMIT ignored'),
    (Key: 'NoRetVal'; Ident: 'NO_RETVAL'; Text: 'Return value of function might be undefined'),
    (Key: 'UseBeforeDef'; Ident: 'USE_BEFORE_DEF'; Text: 'Variable might not have been initialized'),
    (Key: 'ForLoopVarUndef'; Ident: 'FOR_LOOP_VAR_UNDEF'; Text: 'FOR-loop variable may be undefined after loop'),
    (Key: 'UnitNameMismatch'; Ident: 'UNIT_NAME_MISMATCH'; Text: 'Unit identifier does not match file name'),
    (Key: 'NoCFGFileFound'; Ident: 'NO_CFG_FILE_FOUND'; Text: 'No configuration files found'),
    (Key: 'MessageDirective'; Ident: 'MESSAGE_DIRECTIVE'; Text: 'User-defined warnings'),
    (Key: 'ImplicitVariants'; Ident: 'IMPLICIT_VARIANTS'; Text: 'Variants unit used implicitly'),
    (Key: 'UnicodeToLocale'; Ident: 'UNICODE_TO_LOCALE'; Text: 'Error converting Unicode char to locale charset'),
    (Key: 'LocaleToUnicode'; Ident: 'LOCALE_TO_UNICODE'; Text: 'Error converting locale string to Unicode'),
    (Key: 'ImagebaseMultiple'; Ident: 'IMAGEBASE_MULTIPLE'; Text: 'Image base is not a multiple of 64k'),
    (Key: 'SuspiciousTypecast'; Ident: 'SUSPICIOUS_TYPECAST'; Text: 'Suspicious typecast'),
    (Key: 'PrivatePropAccessor'; Ident: 'PRIVATE_PROPACCESSOR'; Text: 'Property accessor is private'),
    (Key: 'UnsafeType'; Ident: 'UNSAFE_TYPE'; Text: 'Unsafe type'),
    (Key: 'UnsafeCode'; Ident: 'UNSAFE_CODE'; Text: 'Unsafe code'),
    (Key: 'UnsafeCast'; Ident: 'UNSAFE_CAST'; Text: 'Unsafe typecast'));
  PlatformNames: array[TSdPlatform] of string = ('Win32', 'Win64');
  { Delphi 7's unit names are found in the scoped units of the newer RTL and VCL
    (Forms -> Vcl.Forms, Windows -> Winapi.Windows, Registry -> System.Win.Registry ...) }
  Win64UnitScopes = 'System;System.Win;Winapi;Vcl;Vcl.Imaging;Vcl.Samples;Vcl.Shell;Data;Data.Win;' +
    'Bde;Xml;Soap;Web';

function WarningOnByDefault(const W: TCompilerWarning): Boolean;
{ a compiler switch of the .dof's [Compiler] section when neither the project nor the default
  options (defproj.dof) have it: the compiler's own default (A = 8; Y = 1, definitions only) }
function CompilerSwitchDefault(Switch: Char): Integer;
{ runs a console program (CmdLine, in WorkDir) without a window and waits for it: what it wrote
  (its output and its errors) and its exit code; False when it cannot start }
function RunConsoleTool(const CmdLine, WorkDir: string; out Output: string; out Code: Cardinal): Boolean;

implementation

uses
  Registry, StrUtils, SdFormSrc, SdFileNames, SdDelphiDir, SdSettings, SdEnvOptions,
  SdDebuggerOptions, SdPasLex, SdPEHeader, SdResImage;

const
  CRLF = #13#10;

{ ---------------------------------------------------------------- project resource (.res) }

procedure ResPad(Res: TStream);
const
  Zero: Cardinal = 0;
begin
  if Res.Size mod 4 <> 0 then Res.Write(Zero, 4 - Res.Size mod 4);
end;

{ the header of an entry of a 32-bit .res file; the name is a string or an ordinal }
procedure ResHeader(Res: TStream; DataSize: Cardinal; ResType, NameOrd: Word; const NameStr: WideString;
  Flags: Word);
var
  HeaderSize, Z: Cardinal;
  W: Word;
  NameBytes: Integer;
begin
  if NameStr <> '' then NameBytes := (Length(NameStr) + 1) * 2 else NameBytes := 4;
  HeaderSize := 8 + 4 + Cardinal(NameBytes);
  if HeaderSize mod 4 <> 0 then Inc(HeaderSize, 4 - HeaderSize mod 4);
  Inc(HeaderSize, 16);
  Res.Write(DataSize, 4);
  Res.Write(HeaderSize, 4);
  W := $FFFF;
  Res.Write(W, 2);
  Res.Write(ResType, 2);
  if NameStr <> '' then
    Res.Write(PWideChar(NameStr)^, NameBytes)
  else
  begin
    Res.Write(W, 2);
    Res.Write(NameOrd, 2);
  end;
  ResPad(Res);
  Z := 0;
  Res.Write(Z, 4);                 // data version
  Res.Write(Flags, 2);             // memory flags
  W := 0;
  Res.Write(W, 2);                 // language: neutral
  Res.Write(Z, 4);                 // version
  Res.Write(Z, 4);                 // characteristics
end;

{ --- the entries of a 32-bit .res file (icon, version information, manifest) --- }

const
  RT_VERSION_ID = 16;

type
  TResItem = record
    TypeId, NameId: Integer;           // -1: the type / the name is a string
    TypeName, Name: string;            // upper case
    Raw: string;                       // the whole entry: header, data, padding
    Data: string;
  end;
  TResItems = array of TResItem;

{ the ordinal or the (upper-case) name at Data[P] (1-based) of a resource header; P moves on }
procedure ResId(const Data: string; var P: Integer; var Id: Integer; var Name: string);
begin
  ReadResId(Data, P, Id, Name);
  Name := UpperCase(Name);
end;

{ the entries of a 32-bit .res file; False when Data is not such a file (it starts with an
  empty entry). Raw is padded to 4 bytes also when the file's last entry was not. }
function ReadRes(const Data: string; var Items: TResItems): Boolean;
var
  P, DataSize, HeaderSize, Total, Q, N: Integer;
begin
  Items := nil;
  Result := False;
  P := 1;
  N := 0;
  while P + 16 <= Length(Data) + 1 do
  begin
    Move(Data[P], DataSize, 4);
    Move(Data[P + 4], HeaderSize, 4);
    if (HeaderSize < 16) or (DataSize < 0) or (Int64(P) - 1 + HeaderSize + DataSize > Length(Data)) then Exit;
    if (P = 1) and ((DataSize <> 0) or (HeaderSize <> 32)) then Exit;
    Total := HeaderSize + DataSize;
    if Total mod 4 <> 0 then Inc(Total, 4 - Total mod 4);
    SetLength(Items, N + 1);
    Q := P + 8;
    ResId(Data, Q, Items[N].TypeId, Items[N].TypeName);
    ResId(Data, Q, Items[N].NameId, Items[N].Name);
    Items[N].Raw := Copy(Data, P, Total);
    while Length(Items[N].Raw) < Total do Items[N].Raw := Items[N].Raw + #0;
    Items[N].Data := Copy(Data, P + HeaderSize, DataSize);
    Inc(N);
    Inc(P, Total);
  end;
  Result := N > 0;
end;

procedure DeleteResItem(var Items: TResItems; Index: Integer);
var
  I: Integer;
begin
  for I := Index to High(Items) - 1 do Items[I] := Items[I + 1];
  SetLength(Items, Length(Items) - 1);
end;

function JoinRes(const Items: TResItems): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Items) do Result := Result + Items[I].Raw;
end;

function StreamText(S: TMemoryStream): string;
begin
  SetString(Result, PChar(S.Memory), S.Size);
end;

{ one entry, ready to be appended to a .res file }
function ResEntry(ResType, NameOrd: Word; const NameStr: WideString; Flags: Word; const Data: string): string;
var
  S: TMemoryStream;
begin
  S := TMemoryStream.Create;
  try
    ResHeader(S, Length(Data), ResType, NameOrd, NameStr, Flags);
    if Data <> '' then S.Write(Data[1], Length(Data));
    ResPad(S);
    Result := StreamText(S);
  finally
    S.Free;
  end;
end;

function StreamBytes(S: TStream): string;
begin
  SetLength(Result, S.Size);
  S.Position := 0;
  if Result <> '' then S.ReadBuffer(Result[1], Length(Result));
end;

{ the entries of the icon group MAINICON with the images of an .ico stream (RT_ICON ids from
  FirstId on) }
function IconEntries(Ico: TStream; FirstId: Integer): string;
var
  Entries: TSdIconEntries;
  Ids: TSdIds;
  Cursor: Boolean;
  I: Integer;
begin
  if not ReadIconFile(StreamBytes(Ico), Cursor, Entries) or Cursor then raise Exception.Create('Invalid icon data');
  SetLength(Ids, Length(Entries));
  Result := '';
  for I := 0 to High(Entries) do
  begin
    Ids[I] := FirstId + I;
    Result := Result + ResEntry(RT_ICON_ID, Ids[I], '', $1010, EntryResData(Entries[I], False));
  end;
  Result := Result + ResEntry(RT_GROUP_ICON_ID, 0, 'MAINICON', $1030, MakeGroupDir(Entries, Ids, False));
end;

{ Writes a 32-bit .res file with the images of an .ico stream as the icon group MAINICON. }
procedure WriteIconRes(Ico: TStream; const ResFile: string);
begin
  { the empty resource that marks a 32-bit file, then the icon }
  WriteFileU(ResFile, ResEntry(0, 0, '', 0, '') + IconEntries(Ico, 1));
end;

{ the ids of the images of the icon group MAINICON ('' none) }
function MainIconIds(const Items: TResItems; var Entries: TSdIconEntries; var Ids: TSdIds): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(Items) do
    if (Items[I].TypeId = RT_GROUP_ICON_ID) and (Items[I].Name = 'MAINICON') then
      Result := ReadGroupDir(Items[I].Data, False, Entries, Ids);
end;

function SetProjectIcon(const ResFile: string; Ico: TStream): Boolean;
var
  Items: TResItems;
  Entries: TSdIconEntries;
  Ids: TSdIds;
  I, J, MaxId: Integer;
  Data: string;
  Old: Boolean;
begin
  Result := False;
  if FileExists(ResFile) then Data := ReadFileU(ResFile) else Data := '';
  if (Data <> '') and not ReadRes(Data, Items) then Exit;      // not a 32-bit .res: left alone
  if Data = '' then
  begin
    WriteIconRes(Ico, ResFile);
    Result := True;
    Exit;
  end;
  if not MainIconIds(Items, Entries, Ids) then Ids := nil;
  { the old group and its images go; the new images get ids after the others' }
  MaxId := 0;
  for I := High(Items) downto 0 do
  begin
    Old := (Items[I].TypeId = RT_GROUP_ICON_ID) and (Items[I].Name = 'MAINICON');
    if Items[I].TypeId = RT_ICON_ID then
      for J := 0 to High(Ids) do
        if Items[I].NameId = Ids[J] then Old := True;
    if Old then DeleteResItem(Items, I)
    else if (Items[I].TypeId = RT_ICON_ID) and (Items[I].NameId > MaxId) then MaxId := Items[I].NameId;
  end;
  WriteFileU(ResFile, JoinRes(Items) + IconEntries(Ico, MaxId + 1));
  Result := True;
end;

function ProjectIcon(const ResFile: string; Ico: TStream): Boolean;
var
  Items: TResItems;
  Entries: TSdIconEntries;
  Ids: TSdIds;
  I, J: Integer;
  S: string;
begin
  Result := False;
  if not FileExists(ResFile) or not ReadRes(ReadFileU(ResFile), Items) then Exit;
  if not MainIconIds(Items, Entries, Ids) or (Length(Entries) = 0) then Exit;
  for J := 0 to High(Ids) do
    for I := 0 to High(Items) do
      if (Items[I].TypeId = RT_ICON_ID) and (Items[I].NameId = Ids[J]) then
        SetEntryResData(Entries[J], Items[I].Data, False);
  S := WriteIconFile(Entries, False);
  Ico.Write(S[1], Length(S));
  Ico.Position := 0;
  Result := True;
end;

{ --- version information (VS_VERSIONINFO, the layout of the Windows resource compiler) --- }

const
  VersionKeysSection = 'Version Info Keys';

procedure VAlign(S: TStream);
const
  Zero: Cardinal = 0;
begin
  if S.Position mod 4 <> 0 then S.Write(Zero, 4 - S.Position mod 4);
end;

{ the start of a block (wLength is filled in by VEnd): length, value length, type, key }
function VBegin(S: TStream; const Key: WideString; ValueLength, WType: Word): Integer;
var
  W: Word;
begin
  VAlign(S);
  Result := S.Position;
  W := 0;
  S.Write(W, 2);
  S.Write(ValueLength, 2);
  S.Write(WType, 2);
  S.Write(PWideChar(Key)^, (Length(Key) + 1) * 2);
  VAlign(S);
end;

procedure VEnd(S: TStream; Start: Integer);
var
  W: Word;
  P: Integer;
begin
  P := S.Position;
  W := P - Start;
  S.Position := Start;
  S.Write(W, 2);
  S.Position := P;
end;

function VersionString(Project: TSdProject): string;
begin
  Result := Format('%d.%d.%d.%d', [Project.OptInt('Version Info', 'MajorVer', 1),
    Project.OptInt('Version Info', 'MinorVer', 0), Project.OptInt('Version Info', 'Release', 0),
    Project.OptInt('Version Info', 'Build', 0)]);
end;

{ "1.2.3.4" as two DWORDs (MS, LS); False when it is not such a number }
function ParseVersion(const S: string; var MS, LS: Cardinal): Boolean;
var
  Parts: array[0..3] of Integer;
  I, P: Integer;
  R: string;
begin
  R := Trim(S) + '.';
  for I := 0 to 3 do
  begin
    P := Pos('.', R);
    if P = 0 then Parts[I] := 0
    else
    begin
      Parts[I] := StrToIntDef(Copy(R, 1, P - 1), -1);
      Delete(R, 1, P);
    end;
    if Parts[I] < 0 then
    begin
      Result := False;
      Exit;
    end;
  end;
  MS := Cardinal(Parts[0]) shl 16 or Cardinal(Parts[1]);
  LS := Cardinal(Parts[2]) shl 16 or Cardinal(Parts[3]);
  Result := True;
end;

function VersionResource(Project: TSdProject): string;
type
  TFixed = packed record
    Signature, StrucVersion, FileVersionMS, FileVersionLS, ProductVersionMS, ProductVersionLS,
    FileFlagsMask, FileFlags, FileOS, FileType, FileSubtype, FileDateMS, FileDateLS: Cardinal;
  end;
var
  S: TMemoryStream;
  F: TFixed;
  Keys: TStringList;
  Root, SFI, Table, Item, VFI, V, I: Integer;
  Lang, CP: Word;
  Value: WideString;
begin
  Lang := Project.OptInt('Version Info', 'Locale', 1033);
  CP := Project.OptInt('Version Info', 'CodePage', 1252);
  FillChar(F, SizeOf(F), 0);
  F.Signature := $FEEF04BD;
  F.StrucVersion := $00010000;
  ParseVersion(VersionString(Project), F.FileVersionMS, F.FileVersionLS);
  F.ProductVersionMS := F.FileVersionMS;
  F.ProductVersionLS := F.FileVersionLS;
  F.FileFlagsMask := $3F;
  if Project.OptInt('Version Info', 'Debug', 0) <> 0 then F.FileFlags := F.FileFlags or 1;
  if Project.OptInt('Version Info', 'PreRelease', 0) <> 0 then F.FileFlags := F.FileFlags or 2;
  if Project.OptInt('Version Info', 'Private', 0) <> 0 then F.FileFlags := F.FileFlags or 8;
  if Project.OptInt('Version Info', 'Special', 0) <> 0 then F.FileFlags := F.FileFlags or $20;
  F.FileOS := 4;                                         // VOS__WINDOWS32
  if (Project.OptInt('Version Info', 'DLL', 0) <> 0) or Project.IsLibrary or Project.IsPackage then
    F.FileType := 2 else F.FileType := 1;                // VFT_DLL / VFT_APP
  S := TMemoryStream.Create;
  Keys := TStringList.Create;
  try
    if Project.Dof <> nil then Project.Dof.ReadSectionValues(VersionKeysSection, Keys);
    { the product version of the keys, when it is a number }
    ParseVersion(Keys.Values['ProductVersion'], F.ProductVersionMS, F.ProductVersionLS);
    Root := VBegin(S, 'VS_VERSION_INFO', SizeOf(F), 0);
    S.Write(F, SizeOf(F));
    SFI := VBegin(S, 'StringFileInfo', 0, 1);
    Table := VBegin(S, WideString(Format('%.4x%.4x', [Lang, CP])), 0, 1);
    for I := 0 to Keys.Count - 1 do
    begin
      Value := IdeTextToWide(Keys.ValueFromIndex[I]);    // the options' text (the grid's), not the version's code page
      Item := VBegin(S, ToWide(Keys.Names[I], CP_ACP), Length(Value) + 1, 1);
      S.Write(PWideChar(Value)^, (Length(Value) + 1) * 2);
      VEnd(S, Item);
    end;
    VEnd(S, Table);
    VEnd(S, SFI);
    VFI := VBegin(S, 'VarFileInfo', 0, 1);
    V := VBegin(S, 'Translation', 4, 0);
    S.Write(Lang, 2);
    S.Write(CP, 2);
    VEnd(S, V);
    VEnd(S, VFI);
    VEnd(S, Root);
    Result := StreamText(S);
  finally
    Keys.Free;
    S.Free;
  end;
end;

function UpdateVersionInfo(Project: TSdProject; AutoIncrement: Boolean): Boolean;
var
  ResFile, Data: string;
  Items: TResItems;
  I: Integer;
  Include, Bump, Has: Boolean;
begin
  Result := False;
  if (Project = nil) or Project.IsDefaults then Exit;
  Include := Project.OptInt('Version Info', 'IncludeVerInfo', 0) <> 0;
  Bump := Include and AutoIncrement and (Project.OptInt('Version Info', 'AutoIncBuild', 0) <> 0);
  if Bump then
  begin
    { the build number of the file version goes up with each compile, as in Delphi }
    if Project.Dof <> nil then
    begin
      Project.SetOptInt('Version Info', 'Build', Project.OptInt('Version Info', 'Build', 0) + 1);
      if Project.Dof.ValueExists(VersionKeysSection, 'FileVersion') then
        Project.Dof.WriteString(VersionKeysSection, 'FileVersion', VersionString(Project));
      WriteSystemIniFile(Project.Dof);      // raises when the .dof cannot be written
    end;
  end;
  ResFile := ChangeFileExt(Project.FileName, '.res');
  if not FileExists(ResFile) or not ReadRes(ReadFileU(ResFile), Items) then Exit;
  if AutoIncrement and not Bump then
  begin
    { a compile keeps the version resource as the .res has it, as Delphi does: an expert's
      IOTAIDENotifier.BeforeCompile may count builds or stamp the time there; only a .res without
      one gets it, while the project asks for version information }
    Has := False;
    for I := 0 to High(Items) do
      if Items[I].TypeId = RT_VERSION_ID then Has := True;
    if Has or not Include then Exit;
  end;
  for I := High(Items) downto 0 do
    if Items[I].TypeId = RT_VERSION_ID then DeleteResItem(Items, I);
  Data := JoinRes(Items);
  if Include then Data := Data + ResEntry(RT_VERSION_ID, 1, '', $0030, VersionResource(Project));
  WriteFileU(ResFile, Data);
  Result := True;
end;

type
  { a block of a VS_VERSIONINFO: offsets into its data, 0-based }
  TVBlock = record
    Len, ValueLen, WType, ValuePos, ChildPos, EndPos: Integer;
    Key: WideString;
  end;

{ the block at offset P of D; False when it does not fit }
function ReadVBlock(const D: string; P: Integer; var B: TVBlock): Boolean;
var
  Q: Integer;
  W: Word;
begin
  Result := False;
  if (P < 0) or (P + 6 > Length(D)) then Exit;
  Move(D[P + 1], W, 2);
  B.Len := W;
  Move(D[P + 3], W, 2);
  B.ValueLen := W;
  Move(D[P + 5], W, 2);
  B.WType := W;
  if (B.Len < 6) or (P + B.Len > Length(D)) then Exit;
  B.EndPos := P + B.Len;
  B.Key := '';
  Q := P + 6;
  while Q + 2 <= B.EndPos do
  begin
    Move(D[Q + 1], W, 2);
    Inc(Q, 2);
    if W = 0 then Break;
    B.Key := B.Key + WideChar(W);
  end;
  Q := (Q + 3) and not 3;
  B.ValuePos := Q;
  { a text's length counts characters, a binary value's bytes }
  if B.WType = 1 then Inc(Q, B.ValueLen * 2) else Inc(Q, B.ValueLen);
  B.ChildPos := (Q + 3) and not 3;
  Result := B.ValuePos <= B.EndPos;
end;

{ the child block of Parent at offset P; False when P is past Parent's children or the block does
  not end inside Parent (an empty table: P is already its end, and what lies there is the next
  sibling) }
function ReadVChild(const D: string; P: Integer; const Parent: TVBlock; var B: TVBlock): Boolean;
begin
  Result := (P < Parent.EndPos) and ReadVBlock(D, P, B) and (B.EndPos <= Parent.EndPos);
end;

{ the text value of a block: up to its first #0 (writers differ in what wValueLength counts) }
function VBlockText(const D: string; const B: TVBlock): WideString;
var
  Q: Integer;
  W: Word;
begin
  Result := '';
  Q := B.ValuePos;
  while Q + 2 <= B.EndPos do
  begin
    Move(D[Q + 1], W, 2);
    if W = 0 then Break;
    Result := Result + WideChar(W);
    Inc(Q, 2);
  end;
end;

function VersionInfoFromRes(Project: TSdProject): Boolean;
var
  Items: TResItems;
  D, ResFile: string;
  I, P, Q, Lang, CP, Found: Integer;
  Root, B, T, S: TVBlock;
  MS, LS, Flags: Cardinal;
  HasFixed: Boolean;
  Keys, Old: TStringList;
  Lost, Changed: Boolean;

  procedure SetInt(const Name: string; Value: Integer);
  begin
    if Project.OptInt('Version Info', Name, -1) <> Value then
    begin
      Project.SetOptInt('Version Info', Name, Value);
      Changed := True;
    end;
  end;

begin
  Result := False;
  Changed := False;
  if (Project = nil) or Project.IsDefaults or (Project.Dof = nil) or
    (Project.OptInt('Version Info', 'IncludeVerInfo', 0) = 0) then Exit;
  ResFile := ChangeFileExt(Project.FileName, '.res');
  if not FileExists(ResFile) or not ReadRes(ReadFileU(ResFile), Items) then Exit;
  Found := -1;
  for I := 0 to High(Items) do
    if (Items[I].TypeId = RT_VERSION_ID) and ((Found < 0) or (Items[I].NameId = 1)) then Found := I;
  if Found < 0 then Exit;
  D := Items[Found].Data;
  if not ReadVBlock(D, 0, Root) or (Root.Key <> 'VS_VERSION_INFO') then Exit;
  { VS_FIXEDFILEINFO: signature, structure version, the file version's two DWORDs at 8, the
    product version's at 16, the flags' mask at 24 and the flags at 28 }
  HasFixed := (Root.ValueLen >= 52) and (Root.ValuePos + 52 <= Length(D));
  MS := 0;
  LS := 0;
  Flags := 0;
  if HasFixed then
  begin
    Move(D[Root.ValuePos + 1], MS, 4);
    HasFixed := MS = $FEEF04BD;
    Move(D[Root.ValuePos + 9], MS, 4);
    Move(D[Root.ValuePos + 13], LS, 4);
    Move(D[Root.ValuePos + 29], Flags, 4);
    Flags := Flags and $3F;
  end;
  Lang := -1;
  CP := -1;
  Keys := TStringList.Create;
  Old := TStringList.Create;
  try
    P := Root.ChildPos;
    while ReadVChild(D, P, Root, B) do
    begin
      if (B.Key = 'StringFileInfo') and (Keys.Count = 0) then
      begin
        { the first table: its keys, and its name the language and code page ("040904E4") }
        if ReadVChild(D, B.ChildPos, B, T) and (Length(T.Key) = 8) then
        begin
          Lang := StrToIntDef('$' + Copy(string(T.Key), 1, 4), -1);
          CP := StrToIntDef('$' + Copy(string(T.Key), 5, 4), -1);
          Q := T.ChildPos;
          while ReadVChild(D, Q, T, S) do
          begin
            Keys.Add(FromWide(S.Key, CP_ACP, Lost) + '=' + FromWide(VBlockText(D, S), CP_ACP, Lost));    // IDE text
            Q := (S.EndPos + 3) and not 3;
          end;
        end;
      end
      else if B.Key = 'VarFileInfo' then
      begin
        { Translation: language and code page, the ones Windows reads }
        if ReadVChild(D, B.ChildPos, B, T) and (T.Key = 'Translation') and (T.ValuePos + 4 <= T.EndPos) then
        begin
          Lang := Ord(D[T.ValuePos + 1]) or (Ord(D[T.ValuePos + 2]) shl 8);
          CP := Ord(D[T.ValuePos + 3]) or (Ord(D[T.ValuePos + 4]) shl 8);
        end;
      end;
      P := (B.EndPos + 3) and not 3;
    end;
    if HasFixed then
    begin
      SetInt('MajorVer', MS shr 16);
      SetInt('MinorVer', MS and $FFFF);
      SetInt('Release', LS shr 16);
      SetInt('Build', LS and $FFFF);
      SetInt('Debug', Ord(Flags and 1 <> 0));
      SetInt('PreRelease', Ord(Flags and 2 <> 0));
      SetInt('Private', Ord(Flags and 8 <> 0));
      SetInt('Special', Ord(Flags and $20 <> 0));
    end;
    if Lang > 0 then SetInt('Locale', Lang);
    if CP > 0 then SetInt('CodePage', CP);
    Project.Dof.ReadSectionValues(VersionKeysSection, Old);
    if Keys.Text <> Old.Text then
    begin
      Project.Dof.EraseSection(VersionKeysSection);
      for I := 0 to Keys.Count - 1 do
        Project.Dof.WriteString(VersionKeysSection, Keys.Names[I], Keys.ValueFromIndex[I]);
      Changed := True;
    end;
    if Changed then WriteSystemIniFile(Project.Dof);
    Result := Changed;
  finally
    Old.Free;
    Keys.Free;
  end;
end;

function VersionOptionsText(Project: TSdProject): string;
var
  L: TStringList;
begin
  Result := '';
  if (Project = nil) or (Project.Dof = nil) then Exit;
  L := TStringList.Create;
  try
    Project.Dof.ReadSectionValues('Version Info', L);
    Result := L.Text + #0;
    Project.Dof.ReadSectionValues(VersionKeysSection, L);
    Result := Result + L.Text;
  finally
    L.Free;
  end;
end;

{ --- the application manifest: Windows gives a program the visual styles (common controls 6)
      only when its manifest asks for them, and takes its DPI awareness from it. Delphi 7 has
      the XPMan unit for the styles; D7 Studio puts the manifest into the project's resource
      file, like the later Delphi versions do ("Enable runtime themes", "DPI awareness"). --- }

const
  RT_MANIFEST_ID = 24;
  ManifestMark = 'added by D7 Studio';
  ManifestComment = '<!-- ' + ManifestMark + ' (Project | Options | Application) -->';

{ Delphi 7 reads the project's .res itself (coreide70's Resutils.TResEntry.LoadFromStream) and,
  after a resource's data, skips "position mod 4" bytes instead of the padding up to the next
  multiple of 4: a resource whose size is 1 or 3 more than a multiple of 4 makes it misread the
  rest of the file - the last one fails with "Invalid resource file: Error reading file", one in
  the middle shifts the entries after it. The manifest is text: trailing spaces, which XML
  ignores, bring it to a multiple of 4 (spaces it already ends with are counted again). }
function PadManifest(const S: string): string;
var
  N: Integer;
begin
  N := Length(S);
  while (N > 0) and (S[N] = ' ') do Dec(N);
  Result := Copy(S, 1, N);
  if Result <> '' then
    while Length(Result) mod 4 <> 0 do Result := Result + ' ';
end;

const
  { a DPI awareness in the manifest's values: dpiAware's (Windows Vista to 8.1; true/pm is per
    monitor), dpiAwareness's first one (Windows 10 1607 on) }
  DpiAwareValues: array[TSdDpiAwareness] of string = ('', 'true', 'true/pm', 'true/pm');
  DpiAwarenessValues: array[TSdDpiAwareness] of string = ('unaware', 'system', 'permonitor', 'permonitorv2');

{ the index of S among Values, in any case; Missing when it is none of them }
function TextIndex(const S: string; const Values: array of string; Missing: Integer): Integer;
begin
  Result := AnsiIndexText(S, Values);
  if Result < 0 then Result := Missing;
end;

function ManifestAsked(Themes: Boolean; Dpi: TSdDpiAwareness; Utf8: Boolean; Level: TSdExecutionLevel): Boolean;
begin
  Result := Themes or (Dpi <> daUnaware) or Utf8 or (Level <> elAsInvoker);
end;

{ the manifest for the options, '' when they ask for none. Every manifest also carries what a
  current program declares whatever the options say:
  - requestedExecutionLevel, as invoker unless Level says otherwise: without it Windows takes a
    32-bit program for one of before Vista - its writes into Program Files and HKLM go to the
    user's VirtualStore, and a name such as setup or update asks for elevation. In the asm.v2
    namespace, which Vista and later read as asm.v3's: Windows XP before SP3 can fail on the
    element in asm.v3's;
  - supportedOS Vista to 11: without Windows 10's GUID Windows answers the program as Windows 8
    (GetVersionEx 6.2) and keeps the compatibility behaviour of older versions for it;
  - longPathAware: paths beyond MAX_PATH where Windows 10 1607 or later has long paths enabled.
  DPI awareness in Microsoft's values: dpiAware for Windows Vista to 8.1 (true: system aware,
  true/pm: per monitor), dpiAwareness from Windows 10 1607 on, which takes precedence - per monitor
  v2 (Windows 10 1703) falls back to per monitor there. UTF-8: activeCodePage (Windows 10 1903 on;
  older ones ignore it, and the mark next to it makes the modernized RTL end the program there). }
function ManifestText(const AppName: string; Themes: Boolean; Dpi: TSdDpiAwareness; Utf8: Boolean;
  Level: TSdExecutionLevel): string;
const
  Settings2016 = 'http://schemas.microsoft.com/SMI/2016/WindowsSettings';
begin
  Result := '';
  if not ManifestAsked(Themes, Dpi, Utf8, Level) then Exit;
  Result :=
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + CRLF +
    ManifestComment + CRLF +
    '<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">' + CRLF +
    '  <assemblyIdentity type="win32" name="' + AppName + '" version="1.0.0.0" processorArchitecture="*"/>' + CRLF;
  if Themes then
    Result := Result +
      '  <dependency>' + CRLF +
      '    <dependentAssembly>' + CRLF +
      '      <assemblyIdentity type="win32" name="Microsoft.Windows.Common-Controls" version="6.0.0.0" ' +
        'processorArchitecture="*" publicKeyToken="6595b64144ccf1df" language="*"/>' + CRLF +
      '    </dependentAssembly>' + CRLF +
      '  </dependency>' + CRLF;
  Result := Result +
    '  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">' + CRLF +
    '    <security>' + CRLF +
    '      <requestedPrivileges>' + CRLF +
    '        <requestedExecutionLevel level="' + ExecutionLevelKeys[Level] + '" uiAccess="false"/>' + CRLF +
    '      </requestedPrivileges>' + CRLF +
    '    </security>' + CRLF +
    '  </trustInfo>' + CRLF +
    '  <compatibility xmlns="urn:schemas-microsoft-com:compatibility.v1">' + CRLF +
    '    <application>' + CRLF +
    '      <!-- Windows Vista -->' + CRLF +
    '      <supportedOS Id="{e2011457-1546-43c5-a5fe-008deee3d3f0}"/>' + CRLF +
    '      <!-- Windows 7 -->' + CRLF +
    '      <supportedOS Id="{35138b9a-5d96-4fbd-8e2d-a2440225f93a}"/>' + CRLF +
    '      <!-- Windows 8 -->' + CRLF +
    '      <supportedOS Id="{4a2f28e3-53b9-4441-ba9c-d69d4a4a6e38}"/>' + CRLF +
    '      <!-- Windows 8.1 -->' + CRLF +
    '      <supportedOS Id="{1f676c76-80e1-4239-95bb-83d0f6d0da78}"/>' + CRLF +
    '      <!-- Windows 10 and Windows 11 -->' + CRLF +
    '      <supportedOS Id="{8e0f7a12-bfb3-4fe8-b9a5-48fd50a15a9a}"/>' + CRLF +
    '    </application>' + CRLF +
    '  </compatibility>' + CRLF +
    '  <application xmlns="urn:schemas-microsoft-com:asm.v3">' + CRLF +
    '    <windowsSettings>' + CRLF;
  if Dpi <> daUnaware then
    Result := Result +
      '      <dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">' + DpiAwareValues[Dpi] +
        '</dpiAware>' + CRLF;
  if Dpi = daPerMonitorV2 then
    Result := Result +
      '      <dpiAwareness xmlns="' + Settings2016 + '">PerMonitorV2, PerMonitor</dpiAwareness>' + CRLF;
  Result := Result +
    '      <longPathAware xmlns="' + Settings2016 + '">true</longPathAware>' + CRLF;
  { the comment makes the modernized RTL end the program where Windows ignores activeCodePage
    (before Windows 10 1903): its text is compiled as UTF-8 }
  if Utf8 then
    Result := Result +
      '      <!-- requires activeCodePage UTF-8: Windows 10 version 1903 or later -->' + CRLF +
      '      <activeCodePage xmlns="http://schemas.microsoft.com/SMI/2019/WindowsSettings">UTF-8</activeCodePage>' + CRLF;
  Result := PadManifest(Result +
    '    </windowsSettings>' + CRLF +
    '  </application>' + CRLF +
    '</assembly>' + CRLF);
end;

{ a manifest without D7 Studio's comment line: two that differ only there are the same (it named
  the option's page, which was given as Linker before) - no project's .res is written again for
  a comment }
function ManifestBody(const S: string): string;
var
  I, J: Integer;
begin
  Result := S;
  I := Pos('<!-- ' + ManifestMark, Result);
  if I = 0 then Exit;
  J := I;
  while (J < Length(Result)) and (Copy(Result, J, 3) <> '-->') do Inc(J);
  Delete(Result, I, J + 3 - I);
end;

{ what a manifest of the options does, for Messages }
function ManifestSummary(Themes: Boolean; Dpi: TSdDpiAwareness; Utf8: Boolean; Level: TSdExecutionLevel): string;

  procedure Add(const Part: string);
  begin
    if Result <> '' then Result := Result + ', ';
    Result := Result + Part;
  end;

begin
  Result := '';
  if Themes then Add('the visual styles of Windows');
  if Dpi <> daUnaware then Add('DPI awareness ' + DpiAwarenessTexts[Dpi]);
  if Utf8 then Add('UTF-8 code page');
  if Level <> elAsInvoker then Add('execution level ' + ExecutionLevelKeys[Level]);
  Result := Result + ' (Project | Options | Application)';
end;

{ the value of the first element of the local name Element - any namespace prefix - in a manifest
  in lower case: its text, or its attribute Attribute; '' when there is none }
function ManifestValue(const Text, Element, Attribute: string): string;
var
  P, E, Q: Integer;
  Tag: string;
begin
  Result := '';
  P := Pos(Element, Text);
  while P > 0 do
  begin
    E := P + Length(Element);
    if (P > 1) and (Text[P - 1] in ['<', ':']) and (E <= Length(Text)) and
      (Text[E] in [' ', #9, #13, #10, '>', '/']) then
    begin
      while (E <= Length(Text)) and (Text[E] <> '>') do Inc(E);
      if Attribute = '' then
      begin
        Q := E + 1;
        while (Q <= Length(Text)) and (Text[Q] <> '<') do Inc(Q);
        Result := Trim(Copy(Text, E + 1, Q - E - 1));
      end
      else
      begin
        Tag := Copy(Text, P, E - P);
        Q := Pos(Attribute + '=', Tag);
        if Q > 0 then
        begin
          Tag := Copy(Tag, Q + Length(Attribute) + 2, MaxInt);      // after the opening quote
          Q := 1;
          while (Q <= Length(Tag)) and not (Tag[Q] in ['"', '''']) do Inc(Q);
          Result := Copy(Tag, 1, Q - 1);
        end;
      end;
      Exit;
    end;
    P := PosEx(Element, Text, P + 1);
  end;
end;

procedure ManifestDeclares(const Text: string; out Dpi: TSdDpiAwareness; out Utf8: Boolean;
  out Level: TSdExecutionLevel);
var
  T, S, Aware: string;
  I: Integer;
begin
  T := LowerCase(Text);
  { dpiAwareness (Windows 10 1607 on) takes precedence: Windows takes its first value it knows,
    else dpiAware's - "per monitor" is true/pm's other spelling }
  S := ManifestValue(T, 'dpiawareness', '');
  I := Pos(',', S);
  if I > 0 then S := Copy(S, 1, I - 1);
  Aware := ManifestValue(T, 'dpiaware', '');
  if Aware = 'per monitor' then Aware := DpiAwareValues[daPerMonitor];
  Dpi := TSdDpiAwareness(TextIndex(Trim(S), DpiAwarenessValues,
    TextIndex(Aware, DpiAwareValues, Ord(daUnaware))));
  Utf8 := ManifestValue(T, 'activecodepage', '') = 'utf-8';
  Level := TSdExecutionLevel(TextIndex(ManifestValue(T, 'requestedexecutionlevel', 'level'),
    ExecutionLevelKeys, Ord(elAsInvoker)));
end;

function ManifestMisses(Dpi: TSdDpiAwareness; Utf8: Boolean; Level: TSdExecutionLevel;
  HasDpi: TSdDpiAwareness; HasUtf8: Boolean; HasLevel: TSdExecutionLevel): string;
begin
  if Dpi = HasDpi then Dpi := daUnaware;
  if Level = HasLevel then Level := elAsInvoker;
  Utf8 := Utf8 and not HasUtf8;
  if ManifestAsked(False, Dpi, Utf8, Level) then Result := ManifestSummary(False, Dpi, Utf8, Level)
  else Result := '';
end;

{ the index of the (first) manifest - a resource of type 24 - among the entries of a .res, -1 =
  none }
function ManifestIndex(const Items: TResItems): Integer;
begin
  Result := 0;
  while (Result <= High(Items)) and (Items[Result].TypeId <> RT_MANIFEST_ID) do Inc(Result);
  if Result > High(Items) then Result := -1;
end;

function ValidResFile(const ResFile: string): Boolean;
var
  Items: TResItems;
begin
  try
    Result := FileExists(ResFile) and ReadRes(ReadFileU(ResFile), Items);
  except
    Result := False;
  end;
end;

function IsIdeManifest(const Data: string): Boolean;
begin
  Result := Pos(ManifestMark, Data) > 0;
end;

function OwnManifestText(Project: TSdProject): string;
var
  Themes, Utf8: Boolean;
  Dpi: TSdDpiAwareness;
  Level: TSdExecutionLevel;
begin
  Project.ManifestOptions(Themes, Dpi, Utf8, Level);
  Result := ManifestText(ChangeFileExt(ExtractFileName(Project.FileName), ''), True, Dpi, Utf8, Level);
  Result := PadManifest(StringReplace(Result, ManifestComment + CRLF, '', []));
end;

{ ---------------------------------------------------------------- Run's debug information }

const
  TD32Sig09 = $39304246;               // 'FB09'
  TD32Sig0A = $41304246;               // 'FB0A'

function DebugInfoDir: string;
begin
  Result := SettingsDir + 'Debug\';
end;

{ the part of the name that stays for a program: its name and a hash of its full path }
function DebugInfoStem(const ExeName: string): string;
var
  S: string;
  I: Integer;
  H: Cardinal;
begin
  S := AnsiUpperCase(ExpandFileName(ExeName));
  H := 0;
  for I := 1 to Length(S) do H := ((H shl 5) or (H shr 27)) xor Ord(S[I]);
  Result := ChangeFileExt(ExtractFileName(ExeName), '') + '-' + IntToHex(H, 8);
end;

{ the bytes of a program as a number: which build it is }
function ContentHash(const Data: string): Cardinal;
var
  I: Integer;
begin
  Result := Length(Data);
  for I := 1 to Length(Data) do Result := ((Result shl 5) or (Result shr 27)) xor Ord(Data[I]);
end;

function DebugInfoFile(const ExeName: string): string;
var
  B, Stem: string;
  SR: TSearchRec;
begin
  Result := '';
  { only a program that has Run's debug information is read: not every DLL the debugged program
    loads (MoveDebugInfo keeps one file per stem) }
  Stem := DebugInfoDir + DebugInfoStem(ExeName) + '-';
  if FindFirst(Stem + '*.tds', faAnyFile, SR) <> 0 then Exit;
  FindClose(SR);
  if not FileExistsU(ExeName) then Exit;
  try
    B := ReadFileU(ExeName);
  except
    Exit;
  end;
  if PEOffset(B) = 0 then Exit;
  Result := Stem + IntToHex(ContentHash(B), 8) + '.tds';
  if not FileExists(Result) then Result := '';
end;
function MoveDebugInfo(const ExeName: string): Boolean;
var
  B, Stem, Block: string;
  PE, Opt, Sec, N, Last, Raw, Size, Base: Integer;
  Init: Cardinal;
  SR: TSearchRec;

  function D(Ofs: Integer): Cardinal;
  begin
    Move(B[Ofs + 1], Result, 4);
  end;

  function W(Ofs: Integer): Word;
  begin
    Move(B[Ofs + 1], Result, 2);
  end;

  procedure SetD(Ofs: Integer; V: Cardinal);
  begin
    Move(V, B[Ofs + 1], 4);
  end;

begin
  Result := False;
  try
    B := ReadFileU(ExeName);
    Size := Length(B);
    if Size < 1024 then Exit;
    if (D(Size - 8) <> TD32Sig09) and (D(Size - 8) <> TD32Sig0A) then Exit;
    Base := Size - Integer(D(Size - 4));
    if (Base <= 0) or (Base >= Size - 8) or ((D(Base) <> TD32Sig09) and (D(Base) <> TD32Sig0A)) then Exit;
    PE := PEOffset(B);
    if PE = 0 then Exit;
    N := W(PE + 6);
    Opt := PE + 24;
    if (N < 2) or (W(Opt) <> $10B) then Exit;           // a 32-bit program with more than .debug
    Sec := Opt + W(PE + 20);
    Last := Sec + 40 * (N - 1);
    Raw := Integer(D(Last + 20));
    { the block lies in the last section, which runs to the end of the file }
    if (Raw <= 0) or (Raw > Base) or (Raw + Integer(D(Last + 16)) <> Size) then Exit;
    ForceDirectories(DebugInfoDir);
    { only the newest build's block is kept for a program }
    Stem := DebugInfoStem(ExeName) + '-';
    if FindFirst(DebugInfoDir + Stem + '*.tds', faAnyFile, SR) = 0 then
    begin
      repeat
        DeleteFile(DebugInfoDir + SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    Block := Copy(B, Base + 1, Size - Base);
    { the section out of the program: one fewer, the image ends where it began, no debug
      directory, its data no longer counted }
    if D(Last + 36) and $40 <> 0 then
    begin
      Init := D(Opt + 8);
      if Init >= D(Last + 16) then SetD(Opt + 8, Init - D(Last + 16));
    end;
    SetD(Opt + 56, D(Last + 12));
    SetD(Opt + 96 + 6 * 8, 0);
    SetD(Opt + 96 + 6 * 8 + 4, 0);
    FillChar(B[Last + 1], 40, 0);
    B[PE + 6 + 1] := Chr((N - 1) and $FF);
    B[PE + 6 + 2] := Chr((N - 1) shr 8);
    B := Copy(B, 1, Raw);
    { a header that carries a checksum (ModernizeProgramHeader) keeps a right one }
    if D(Opt + 64) <> 0 then SetPEChecksum(B, PE);
    { named after the program as it is from now on }
    WriteFileU(DebugInfoDir + Stem + IntToHex(ContentHash(B), 8) + '.tds', Block);
    WriteFileU(ExeName, B);
    Result := True;
  except
    Result := False;
  end;
end;
function EnsureProjectRes(const ProjectFile, Source: string; Themes: Boolean; Dpi: TSdDpiAwareness;
  Utf8: Boolean; Level: TSdExecutionLevel; var Note: string): Boolean;
var
  ResFile, Text: string;
  RS: TResourceStream;
  Items: TResItems;
  K: Integer;
  Ours: Boolean;
begin
  Result := False;
  Note := '';
  ResFile := ChangeFileExt(ProjectFile, '.res');
  if not LinksProjectRes(Source) then Exit;
  try
    if not FileExists(ResFile) then
    begin
      // the Delphi IDE creates <project>.res (the application icon) when $R *.res asks for it
      RS := TResourceStream.Create(HInstance, 'DEFAULTICON', RT_RCDATA);
      try
        WriteIconRes(RS, ResFile);
        Result := True;
      finally
        RS.Free;
      end;
    end;
    if not ReadRes(ReadFileU(ResFile), Items) then Exit;      // not a 32-bit .res: left alone
    K := ManifestIndex(Items);
    Ours := (K >= 0) and IsIdeManifest(Items[K].Data);
    if (K >= 0) and not Ours then Exit;                         // the project's own manifest stays
    Text := ManifestText(ChangeFileExt(ExtractFileName(ProjectFile), ''), Themes, Dpi, Utf8, Level);
    { D7 Studio's manifest as the options want it: kept; another one (other options, or an
      earlier version's - the first ones were for x86 only, which a 64-bit program cannot load)
      is replaced }
    if Ours and (Text <> '') and (Pos(ManifestBody(Text), ManifestBody(Items[K].Data)) > 0) then Exit;
    if Ours then DeleteResItem(Items, K);
    if Text <> '' then
    begin
      WriteFileU(ResFile, JoinRes(Items) + ResEntry(RT_MANIFEST_ID, 1, '', $1030, Text));
      Result := True;
      if Ours then Note := 'updated' else Note := 'added';
      Note := Format('%s: manifest %s - %s', [ExtractFileName(ResFile), Note, ManifestSummary(Themes, Dpi, Utf8, Level)]);
    end
    else if Ours then
    begin
      WriteFileU(ResFile, JoinRes(Items));
      Result := True;
      Note := ExtractFileName(ResFile) + ': manifest removed (Project | Options | Application)';
    end;
  except
    Result := False;
  end;
end;

procedure NewProjectRes(const ProjectFile: string);
var
  Note: string;
begin
  EnsureProjectRes(ProjectFile, '{$R *.res}', True, daUnaware, False, elAsInvoker, Note);
end;

{ ---------------------------------------------------------------- templates }

function NewApplicationSource(const ProjName, UnitName, FormName: string): string;
begin
  Result :=
    'program ' + ProjName + ';' + CRLF + CRLF +
    'uses' + CRLF +
    '  Forms,' + CRLF +
    '  ' + UnitName + ' in ''' + UnitName + '.pas'' {' + FormName + '};' + CRLF + CRLF +
    '{$R *.res}' + CRLF + CRLF +
    'begin' + CRLF +
    '  Application.Initialize;' + CRLF +
    '  Application.CreateForm(T' + FormName + ', ' + FormName + ');' + CRLF +
    '  Application.Run;' + CRLF +
    'end.' + CRLF;
end;

{ the unit of a new module as Delphi 7 writes it: its uses clause Uses_ (the lines, indented,
  without the semicolon), the class T<Name> of Ancestor, the module's global variable when
  WithVar (a frame has none), its form file linked }
function ModuleUnitSource(const UnitName, Name, Ancestor, Uses_: string; WithVar: Boolean): string;
begin
  Result :=
    'unit ' + UnitName + ';' + CRLF + CRLF +
    'interface' + CRLF + CRLF +
    'uses' + CRLF +
    Uses_ + ';' + CRLF + CRLF +
    'type' + CRLF +
    '  T' + Name + ' = class(' + Ancestor + ')' + CRLF +
    '  private' + CRLF +
    '    { Private declarations }' + CRLF +
    '  public' + CRLF +
    '    { Public declarations }' + CRLF +
    '  end;' + CRLF + CRLF;
  if WithVar then Result := Result + 'var' + CRLF + '  ' + Name + ': T' + Name + ';' + CRLF + CRLF;
  Result := Result + 'implementation' + CRLF + CRLF + '{$R *.dfm}' + CRLF + CRLF + 'end.' + CRLF;
end;

function NewFormUnitSource(const UnitName, FormName: string; const Ancestor: string = 'TForm';
  const AncestorUnit: string = ''): string;
var
  Uses_: string;
begin
  Uses_ := 'Dialogs';
  if AncestorUnit <> '' then Uses_ := Uses_ + ', ' + AncestorUnit;
  Result := ModuleUnitSource(UnitName, FormName, Ancestor,
    '  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,' + CRLF + '  ' + Uses_, True);
end;

function NewFormDfm(const FormName: string): string;
begin
  Result :=
    'object ' + FormName + ': T' + FormName + CRLF +
    '  Left = 192' + CRLF +
    '  Top = 107' + CRLF +
    '  Width = 696' + CRLF +
    '  Height = 480' + CRLF +
    '  Caption = ''' + FormName + '''' + CRLF +
    '  Color = clBtnFace' + CRLF +
    '  Font.Charset = DEFAULT_CHARSET' + CRLF +
    '  Font.Color = clWindowText' + CRLF +
    '  Font.Height = -11' + CRLF +
    '  Font.Name = ''MS Sans Serif''' + CRLF +
    '  Font.Style = []' + CRLF +
    '  OldCreateOrder = False' + CRLF +
    '  Position = poDesigned' + CRLF +
    '  PixelsPerInch = 96' + CRLF +
    '  TextHeight = 13' + CRLF +
    'end' + CRLF;
end;

function NewInheritedFormDfm(const FormName: string): string;
begin
  Result :=
    'inherited ' + FormName + ': T' + FormName + CRLF +
    '  Caption = ''' + FormName + '''' + CRLF +
    '  PixelsPerInch = 96' + CRLF +
    '  TextHeight = 13' + CRLF +
    'end' + CRLF;
end;

function NewUnitSource(const UnitName: string): string;
begin
  Result :=
    'unit ' + UnitName + ';' + CRLF + CRLF +
    'interface' + CRLF + CRLF +
    'implementation' + CRLF + CRLF +
    'end.' + CRLF;
end;

function NewDataModuleSource(const UnitName, ModuleName: string): string;
begin
  Result := ModuleUnitSource(UnitName, ModuleName, 'TDataModule', '  SysUtils, Classes', True);
end;

function NewDataModuleDfm(const ModuleName: string): string;
begin
  Result :=
    'object ' + ModuleName + ': T' + ModuleName + CRLF +
    '  OldCreateOrder = False' + CRLF +
    '  Left = 192' + CRLF +
    '  Top = 107' + CRLF +
    '  Height = 150' + CRLF +
    '  Width = 215' + CRLF +
    'end' + CRLF;
end;

function NewFrameSource(const UnitName, FrameName: string): string;
begin
  Result := ModuleUnitSource(UnitName, FrameName, 'TFrame',
    '  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms, ' + CRLF + '  Dialogs', False);
end;

function NewFrameDfm(const FrameName: string): string;
begin
  Result :=
    'object ' + FrameName + ': T' + FrameName + CRLF +
    '  Left = 0' + CRLF +
    '  Top = 0' + CRLF +
    '  Width = 320' + CRLF +
    '  Height = 240' + CRLF +
    '  TabOrder = 0' + CRLF +
    'end' + CRLF;
end;

function NewConsoleSource(const ProjName: string; LinkRes: Boolean = False): string;
begin
  Result :=
    'program ' + ProjName + ';' + CRLF + CRLF +
    '{$APPTYPE CONSOLE}' + CRLF + CRLF +
    'uses' + CRLF +
    '  SysUtils;' + CRLF + CRLF;
  if LinkRes then Result := Result + '{$R *.res}' + CRLF + CRLF;
  Result := Result +
    'begin' + CRLF +
    '  { TODO -oUser -cConsole Main : Insert code here }' + CRLF +
    'end.' + CRLF;
end;

{ Delphi 7's new package (File | New | Package): its switches written into the source, design
  and run time, requires rtl }
function NewPackageSource(const PackageName: string; const Description: string = '';
  const Requires: string = 'rtl'): string;
var
  Desc, Req: string;
begin
  if Description <> '' then
    Desc := '{$DESCRIPTION ''' + StringReplace(Description, '''', '''''', [rfReplaceAll]) + '''}' + CRLF
  else
    Desc := '';
  Req := '  ' + StringReplace(Requires, ',', ',' + CRLF + '  ', [rfReplaceAll]) + ';';
  Result :=
    'package ' + PackageName + ';' + CRLF + CRLF +
    '{$R *.res}' + CRLF +
    '{$ALIGN 8}' + CRLF +
    '{$ASSERTIONS ON}' + CRLF +
    '{$BOOLEVAL OFF}' + CRLF +
    '{$DEBUGINFO ON}' + CRLF +
    '{$EXTENDEDSYNTAX ON}' + CRLF +
    '{$IMPORTEDDATA ON}' + CRLF +
    '{$IOCHECKS ON}' + CRLF +
    '{$LOCALSYMBOLS ON}' + CRLF +
    '{$LONGSTRINGS ON}' + CRLF +
    '{$OPENSTRINGS ON}' + CRLF +
    '{$OPTIMIZATION ON}' + CRLF +
    '{$OVERFLOWCHECKS OFF}' + CRLF +
    '{$RANGECHECKS OFF}' + CRLF +
    '{$REFERENCEINFO ON}' + CRLF +
    '{$SAFEDIVIDE OFF}' + CRLF +
    '{$STACKFRAMES OFF}' + CRLF +
    '{$TYPEDADDRESS OFF}' + CRLF +
    '{$VARSTRINGCHECKS ON}' + CRLF +
    '{$WRITEABLECONST OFF}' + CRLF +
    '{$MINENUMSIZE 1}' + CRLF +
    '{$IMAGEBASE $400000}' + CRLF +
    Desc +
    '{$IMPLICITBUILD OFF}' + CRLF + CRLF +
    'requires' + CRLF +
    Req + CRLF + CRLF +
    'end.' + CRLF;
end;

// the argument of a compiler directive in a source (LIBSUFFIX '70' -> 70), '' when it is not
// there; Found says whether it is
function SourceDirective(const S, Name: string; var Found: Boolean): string;
var
  P, Q: Integer;
begin
  Result := '';
  Found := False;
  P := Pos('{$' + UpperCase(Name), UpperCase(S));
  if P = 0 then Exit;
  Inc(P, Length(Name) + 2);
  if (P <= Length(S)) and (S[P] in ['A'..'Z', 'a'..'z', '0'..'9', '_']) then Exit;   // a longer name
  Found := True;
  Q := P;
  while (Q <= Length(S)) and (S[Q] <> '}') do Inc(Q);
  Result := Trim(Copy(S, P, Q - P));
  if (Length(Result) >= 2) and (Result[1] = '''') and (Result[Length(Result)] = '''') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

{ ---------------------------------------------------------------- TProjectUnit }

function TProjectUnit.HasForm: Boolean;
begin
  Result := (FormName <> '') or FileExists(FormFileName);
end;

function TProjectUnit.FormFileName: string;
begin
  Result := ChangeFileExt(FileName, '.dfm');
end;

{ ---------------------------------------------------------------- TSdProject }

constructor TSdProject.Create;
begin
  inherited Create;
  FUnits := TObjectList.Create(True);
  FRequires := TStringList.Create;
  FResScripts := TObjectList.Create(True);
end;

destructor TSdProject.Destroy;
begin
  FDof.Free;
  FUnits.Free;
  FRequires.Free;
  FResScripts.Free;
  inherited;
end;

function TSdProject.GetUnit(Index: Integer): TProjectUnit;
begin
  Result := TProjectUnit(FUnits[Index]);
end;

function TSdProject.UnitCount: Integer;
begin
  Result := FUnits.Count;
end;

function TSdProject.GetResScript(Index: Integer): TProjectResScript;
begin
  Result := TProjectResScript(FResScripts[Index]);
end;

function TSdProject.ResScriptCount: Integer;
begin
  Result := FResScripts.Count;
end;

function TSdProject.FindResScript(const AFileName: string): TProjectResScript;
var
  I: Integer;
begin
  for I := 0 to FResScripts.Count - 1 do
  begin
    Result := ResScripts[I];
    if SameText(Result.FileName, AFileName) then Exit;
  end;
  Result := nil;
end;

function TSdProject.GetDir: string;
begin
  Result := ExtractFilePath(FFileName);
end;

function TSdProject.GetName: string;
begin
  Result := ChangeFileExt(ExtractFileName(FFileName), '');
end;

var
  FDefaultOptions: TMemIniFile;

function DefaultOptionsFile: string;
begin
  { a name of its own - in Delphi's Bin, defproj.dof is Delphi's }
  Result := SettingsDir + 'D7Studio.dof';
end;

function DefaultOptions: TMemIniFile;
begin
  if FDefaultOptions = nil then
  begin
    if FileExists(DefaultOptionsFile) then FDefaultOptions := OpenSystemIniFile(DefaultOptionsFile)
    else FDefaultOptions := OpenSystemIniFile(DelphiBin + 'defproj.dof');
  end;
  Result := FDefaultOptions;
end;

{ the options of From (all but the history lists) into To }
procedure CopyOptions(From, ToIni: TCustomIniFile);
var
  Secs, Keys: TStringList;
  I, J: Integer;
begin
  Secs := TStringList.Create;
  Keys := TStringList.Create;
  try
    From.ReadSections(Secs);
    for I := 0 to Secs.Count - 1 do
    begin
      if Pos('HistoryLists', Secs[I]) = 1 then Continue;
      From.ReadSection(Secs[I], Keys);
      for J := 0 to Keys.Count - 1 do ToIni.WriteString(Secs[I], Keys[J], From.ReadString(Secs[I], Keys[J], ''));
    end;
  finally
    Keys.Free;
    Secs.Free;
  end;
end;

procedure TSdProject.Load(const AFileName: string);
var
  New: Boolean;
  Bytes: string;
  E: TSdEncoding;
begin
  FFileName := ExpandFileName(AFileName);
  FRenamedFrom := '';
  FreeAndNil(FDof);
  New := not FileExists(ChangeFileExt(FFileName, '.dof'));
  FDof := OpenSystemIniFile(ChangeFileExt(FFileName, '.dof'));
  { a project without options starts with the default ones (Project Options | Default) }
  if New then CopyOptions(DefaultOptions, FDof);
  { the project source as the editor opens it: the encoding chosen for the file, else the
    detected one }
  Bytes := ReadFileU(FFileName);
  E := FileEncoding(FFileName, Bytes);
  ParseSource(DecodeFile(Bytes, E, False), E);
end;

procedure TSdProject.Rename(const AFileName: string);
begin
  if FRenamedFrom = '' then FRenamedFrom := FFileName;
  FFileName := ExpandFileName(AFileName);
  if FDof <> nil then FDof.Rename(ChangeFileExt(FFileName, '.dof'), False);
end;

procedure TSdProject.LoadDefaults;
begin
  FFileName := '';
  FreeAndNil(FDof);
  FDof := OpenSystemIniFile(DefaultOptionsFile);
  if not FileExists(DefaultOptionsFile) then CopyOptions(DefaultOptions, FDof);
end;

function TSdProject.IsDefaults: Boolean;
begin
  Result := (FFileName = '') and (FDof <> nil);
end;

procedure TSdProject.SaveAsDefaults;
var
  D: TMemIniFile;
begin
  if FDof = nil then Exit;
  D := OpenSystemIniFile(DefaultOptionsFile);
  try
    D.Clear;
    CopyOptions(FDof, D);
    { the run parameters belong to one program }
    D.EraseSection('Parameters');
    ForceDirectories(ExtractFilePath(DefaultOptionsFile));
    WriteSystemIniFile(D);
  finally
    D.Free;
  end;
  FreeAndNil(FDefaultOptions);
end;

procedure TSdProject.ParseSource(const Source: string; const E: TSdEncoding);
var
  Names, Paths, Forms: TStringList;
  RunOnly: string;
  I: Integer;
  U: TProjectUnit;
  R: TProjectResScript;
  Found: Boolean;
begin
  { a library: decided here once, the idle state of the commands asks for it all the time }
  FLibrary := SourceIsLibrary(Source);
  FLibPrefix := SourceDirective(Source, 'LIBPREFIX', Found);
  FLibSuffix := SourceDirective(Source, 'LIBSUFFIX', Found);
  FDescription := SourceDirective(Source, 'DESCRIPTION', Found);
  // the directive RUNONLY alone or with ON makes it run-only, with OFF not
  RunOnly := UpperCase(Trim(SourceDirective(Source, 'RUNONLY', FRunOnly)));
  FRunOnly := FRunOnly and (RunOnly <> 'OFF') and (RunOnly <> '-');
  FRequires.Clear;
  DpkGetRequires(Source, FRequires);
  FUnits.Clear;
  Names := TStringList.Create;
  Paths := TStringList.Create;
  Forms := TStringList.Create;
  try
    DprGetUnits(Source, Names, Paths, Forms);
    { the source is the editor's text: in a code page (Delphi 7's, or one chosen for the file) a
      name's characters are its bytes - a file name is D7 Studio's text (EditorToAnsi) }
    for I := 0 to Names.Count - 1 do
    begin
      if (I >= Paths.Count) or (Paths[I] = '') then Continue;    // library unit, not a project file
      U := TProjectUnit.Create;
      U.Name := Names[I];
      U.FileName := FullPath(EditorToAnsi(Paths[I], E));
      if I < Forms.Count then U.FormName := Forms[I];
      FUnits.Add(U);
    end;
    { the resource scripts: $R 'x.res' 'x.rc' (Names: the .res, Paths: the .rc) }
    FResScripts.Clear;
    Names.Clear;
    Paths.Clear;
    DprGetResScripts(Source, Names, Paths);
    for I := 0 to Paths.Count - 1 do
    begin
      R := TProjectResScript.Create;
      R.RelRes := Names[I];
      R.RelRc := Paths[I];
      R.ResFileName := ResPath(Names[I], E);
      R.FileName := FullPath(EditorToAnsi(Paths[I], E));
      R.Name := ExtractFileName(R.FileName);
      FResScripts.Add(R);
    end;
  finally
    Names.Free;
    Paths.Free;
    Forms.Free;
  end;
end;

function TSdProject.FindUnit(const AFileName: string): TProjectUnit;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FUnits.Count - 1 do
    if SameText(Units[I].FileName, AFileName) then
    begin
      Result := Units[I];
      Exit;
    end;
end;

function TSdProject.FindUnitByName(const AName: string): TProjectUnit;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FUnits.Count - 1 do
    if SameText(Units[I].Name, AName) then
    begin
      Result := Units[I];
      Exit;
    end;
end;

function TSdProject.IsLibrary: Boolean;
begin
  Result := (FFileName <> '') and FLibrary;
end;

function TSdProject.IsPackage: Boolean;
begin
  Result := IsPackageFile(FFileName);
end;

function TSdProject.IsRunOnly: Boolean;
begin
  Result := IsPackage and FRunOnly;
end;

{ a package folder option as the compiler gets it: the project's, else the one of Environment
  Options | Library (Delphi 7's until changed); Win64 builds go to its subfolder Win64 }
function PackageDirOpt(Project: TSdProject; const Key: string; Bpl: Boolean): string;
begin
  Result := Project.DirOpt(Key);
  if Result = '' then
    if Bpl then Result := ExpandPathMacros(EnvOptions.BplOutputDir)
    else Result := ExpandPathMacros(EnvOptions.DcpOutputDir);
  if Result = '' then Result := DelphiRoot + 'Projects\Bpl';
  Result := ExcludeTrailingPathDelimiter(Project.FullPath(Result));
  if Project.Platform = spWin64 then Result := Result + '\' + PlatformNames[spWin64];
end;

function TSdProject.PackageOutputDir: string;
begin
  Result := IncludeTrailingPathDelimiter(PackageDirOpt(Self, 'PackageDLLOutputDir', True));
end;

function TSdProject.DcpOutputDir: string;
begin
  Result := IncludeTrailingPathDelimiter(PackageDirOpt(Self, 'PackageDCPOutputDir', False));
end;

function TSdProject.FindDcp(const Package: string): string;
var
  L: TStringList;
  I: Integer;
begin
  Result := '';
  L := TStringList.Create;
  try
    L.Add(ExcludeTrailingPathDelimiter(DcpOutputDir));
    L.Add(ExcludeTrailingPathDelimiter(Dir));
    AddPathList(L, DirOpt('SearchPath'), Dir);
    AddPathList(L, EnvOptions.LibraryPath);
    for I := 0 to L.Count - 1 do
      if FileExists(L[I] + '\' + Package + '.dcp') then
      begin
        Result := L[I] + '\' + Package + '.dcp';
        Exit;
      end;
  finally
    L.Free;
  end;
end;

function TSdProject.UsesThemes: Boolean;
begin
  Result := (OptInt(ThemeSection, ThemeKey, 1) <> 0) and not IsLibrary and not IsPackage;
end;

{ True when the unit is named in the project source or in one of the project's units (the
  word is looked for, not the uses clauses parsed: good enough to see that a program brings
  its own manifest with XPMan) }
function TSdProject.UsesUnit(const UnitName: string; Source: TSdSourceFunc = nil): Boolean;
begin
  Result := FirstUsedUnit([UnitName], Source) = 0;
end;

{ Word (lower case) stands in S (lower case) as a word of its own, not as a part of a longer
  identifier }
function HasWord(const S, Word: string): Boolean;
var
  P: Integer;
begin
  Result := False;
  if Word = '' then Exit;
  P := PosEx(Word, S, 1);
  while P > 0 do
  begin
    if ((P = 1) or not (S[P - 1] in ['a'..'z', '0'..'9', '_'])) and
      ((P + Length(Word) > Length(S)) or not (S[P + Length(Word)] in ['a'..'z', '0'..'9', '_'])) then
    begin
      Result := True;
      Exit;
    end;
    P := PosEx(Word, S, P + Length(Word));
  end;
end;

{ the project source first, then the units in their order; once a name is found only the names
  before it are looked for, and the first name ends the search }
function TSdProject.FirstUsedUnit(const Names: array of string; Source: TSdSourceFunc = nil): Integer;
var
  I, K: Integer;
  S: string;

  { the text of a file in lower case; '' when it cannot be read (it names nothing) }
  function LowerText(const FileName: string): string;
  begin
    Result := '';
    try
      if Assigned(Source) then Result := Source(FileName)
      else if FileExistsU(FileName) then Result := ReadFileU(FileName);
    except
      Result := '';
    end;
    Result := LowerCase(Result);
  end;

begin
  Result := Length(Names);             // none found yet
  I := -1;                             // -1: the project source
  while (Result > 0) and (I < UnitCount) do
  begin
    if I < 0 then S := LowerText(FFileName) else S := LowerText(Units[I].FileName);
    for K := 0 to Result - 1 do
      if HasWord(S, LowerCase(Names[K])) then
      begin
        Result := K;
        Break;
      end;
    Inc(I);
  end;
  if Result = Length(Names) then Result := -1;
end;

function WarningOnByDefault(const W: TCompilerWarning): Boolean;
begin
  Result := Pos('UNSAFE_', W.Ident) <> 1;
end;

function IsProjectFile(const FileName: string): Boolean;
begin
  Result := SameText(ExtractFileExt(FileName), '.dpr') or IsPackageFile(FileName);
end;

function IsPackageFile(const FileName: string): Boolean;
begin
  Result := SameText(ExtractFileExt(FileName), '.dpk');
end;

function IsAbsolutePath(const Path: string): Boolean;
begin
  Result := (Length(Path) > 1) and ((Path[2] = ':') or (Path[1] = '\'));
end;

function SourceIsLibrary(const Source: string): Boolean;
var
  Lex: TPasLexer;
begin
  Lex := TPasLexer.Create(Source);
  try
    Lex.Next;
    Result := (Lex.Tok.Kind = tkKeyword) and (Lex.Tok.Keyword = kwLibrary);
  finally
    Lex.Free;
  end;
end;

function LinksProjectRes(const Source: string): Boolean;
begin
  Result := Pos('{$r *.res}', LowerCase(Source)) > 0;
end;

function TSdProject.FullPath(const Path: string): string;
begin
  if IsAbsolutePath(Path) then Result := Path else Result := ExpandFileName(Dir + Path);
end;

function TSdProject.Platform: TSdPlatform;
begin
  if SameText(OptStr(ThemeSection, PlatformKey, ''), PlatformNames[spWin64]) then Result := spWin64
  else Result := spWin32;
end;

procedure TSdProject.SetPlatform(Value: TSdPlatform);
begin
  SetOptStr(ThemeSection, PlatformKey, PlatformNames[Value]);
end;

{ per monitor v2 unless the project says otherwise: the modernized VCL scales the forms to the
  DPI of their monitor, where Windows would stretch an unaware program's windows as bitmaps }
function TSdProject.DpiAwareness: TSdDpiAwareness;
begin
  Result := TSdDpiAwareness(TextIndex(OptStr(ThemeSection, DpiKey, DpiAwarenessKeys[daPerMonitorV2]),
    DpiAwarenessKeys, Ord(daUnaware)));
end;

procedure TSdProject.SetDpiAwareness(Value: TSdDpiAwareness);
begin
  SetOptStr(ThemeSection, DpiKey, DpiAwarenessKeys[Value]);
end;

function TSdProject.ExecutionLevel: TSdExecutionLevel;
begin
  Result := TSdExecutionLevel(TextIndex(OptStr(ThemeSection, ExecutionLevelKey, ''), ExecutionLevelKeys,
    Ord(elAsInvoker)));
end;

procedure TSdProject.SetExecutionLevel(Value: TSdExecutionLevel);
begin
  SetOptStr(ThemeSection, ExecutionLevelKey, ExecutionLevelKeys[Value]);
end;

procedure TSdProject.ManifestOptions(out Themes: Boolean; out Dpi: TSdDpiAwareness; out Utf8: Boolean;
  out Level: TSdExecutionLevel);
begin
  Themes := UsesThemes;
  Utf8 := Utf8CodePage;
  Dpi := daUnaware;
  Level := elAsInvoker;
  if IsLibrary or IsPackage then Exit;
  Dpi := DpiAwareness;
  Level := ExecutionLevel;
end;

function TSdProject.ResPath(const Name: string; const E: TSdEncoding): string;
begin
  Result := StringReplace(EditorToAnsi(Name, E), '*', ChangeFileExt(ExtractFileName(FileName), ''), []);
  if ExtractFileExt(Result) = '' then Result := Result + '.res';
  Result := FullPath(Result);
end;

function TSdProject.LinkedManifest(const Source: string; const E: TSdEncoding; out Data: string): Boolean;
var
  Files: TStringList;
  Items: TResItems;
  I, K: Integer;
  F: string;
begin
  Result := False;
  Data := '';
  Files := TStringList.Create;
  try
    DprGetResFiles(Source, Files);
    for I := 0 to Files.Count - 1 do
    begin
      F := ResPath(Files[I], E);
      try
        if FileExists(F) and ReadRes(ReadFileU(F), Items) then
        begin
          K := ManifestIndex(Items);
          if (K >= 0) and not IsIdeManifest(Items[K].Data) then
          begin
            Data := Items[K].Data;
            Result := True;
            Exit;
          end;
        end;
      except
        { a file that cannot be read: taken as holding none }
      end;
    end;
  finally
    Files.Free;
  end;
end;

{ WindowsXP=1 is Windows XP; otherwise Utf8CodePage (Utf8Default unless the project says
  otherwise) chooses between Windows 10 1903 and Vista - a .dof of before Target Windows has
  Utf8CodePage alone }
function TSdProject.TargetWindows: TSdTargetWindows;
begin
  if OptInt(ThemeSection, WindowsXPKey, 0) <> 0 then Result := twWindowsXP
  else if OptInt(ThemeSection, Utf8Key, Utf8Default) <> 0 then Result := twWindows10Utf8
  else Result := twVista;
end;

procedure TSdProject.SetTargetWindows(Value: TSdTargetWindows);
begin
  SetOptInt(ThemeSection, Utf8Key, Ord(Value = twWindows10Utf8));
  SetOptInt(ThemeSection, WindowsXPKey, Ord(Value = twWindowsXP));
end;

function TSdProject.Utf8CodePage: Boolean;
begin
  Result := (TargetWindows = twWindows10Utf8) and (Platform = spWin32) and not IsLibrary and
    not IsPackage;
end;

{ on unless the project says otherwise }
function TSdProject.ModernHeader: Boolean;
begin
  Result := (OptInt(ThemeSection, ModernHeaderKey, 1) <> 0) and (Platform = spWin32) and
    not IsLibrary and not IsPackage;
end;

function TSdProject.WindowsXP: Boolean;
begin
  Result := (TargetWindows = twWindowsXP) and (Platform = spWin32) and not IsLibrary and
    not IsPackage;
end;

{ a folder option as the compiler gets it: Win64 builds go to its subfolder Win64 }
function PlatformDirOpt(Project: TSdProject; const Key: string): string;
begin
  Result := Project.DirOpt(Key);
  if Project.Platform = spWin64 then
    if Result = '' then Result := PlatformNames[spWin64]
    else Result := IncludeTrailingPathDelimiter(Result) + PlatformNames[spWin64];
end;

function TSdProject.OutputDir: string;
begin
  Result := IncludeTrailingPathDelimiter(FullPath(PlatformDirOpt(Self, 'OutputDir')));
end;

function TSdProject.UnitOutputDir: string;
begin
  Result := PlatformDirOpt(Self, 'UnitOutputDir');
  if Result <> '' then Result := IncludeTrailingPathDelimiter(FullPath(Result));
end;

procedure TSdProject.MakeOutputDirs;
begin
  ForceDirectories(OutputDir);
  if UnitOutputDir <> '' then ForceDirectories(UnitOutputDir);
  if IsPackage then
  begin
    ForceDirectories(PackageOutputDir);
    ForceDirectories(DcpOutputDir);
  end;
end;

function TSdProject.ExeName: string;
begin
  if IsPackage then
    // the directives LIBPREFIX and LIBSUFFIX are part of the file name: dclusr + '70' = dclusr70.bpl
    Result := PackageOutputDir + FLibPrefix + Name + FLibSuffix + '.bpl'
  else
    Result := OutputDir + Name + '.' + TargetExt;
end;

{ the extension of the program or library the compiler writes: Application | Target file
  extension (dcc32's -TX), else exe or dll }
function TSdProject.TargetExt: string;
begin
  Result := Trim(OptStr(ThemeSection, 'TargetExt', ''));
  if Copy(Result, 1, 1) = '.' then Delete(Result, 1, 1);
  if Result = '' then
    if IsLibrary then Result := 'dll' else Result := 'exe';
end;

function TSdProject.SearchPathList: string;
begin
  Result := OptStr('Directories', 'SearchPath', '');
end;

function TSdProject.UnitSearchPath: string;
begin
  Result := DirOpt('SearchPath');
  { a package's .dcp folder is searched as well (Delphi's library path has it): packages of one's
    own that this one requires }
  if IsPackage then
  begin
    if Result <> '' then Result := Result + ';';
    Result := Result + FolderArg(DcpOutputDir);
  end;
  if Platform = spWin32 then
  begin
    { Compiler | Use Debug DCUs: Delphi's units with debug information come first - the folder
      of Debugger Options | Debug DCU Path }
    if (OptInt(ThemeSection, 'DebugDCUs', 0) <> 0) and (DebuggerOptions.DCUPath <> '') then
      Result := ExpandPathMacros(DebuggerOptions.DCUPath) + ';' + Result;
    { the library path of Environment Options | Library (Delphi 7's units are for Win32) }
    if EnvOptions.LibraryPath <> '' then
    begin
      if Result <> '' then Result := Result + ';';
      Result := Result + ExpandPathMacros(EnvOptions.LibraryPath);
    end;
  end;
end;

procedure TSdProject.OtherSourceUnits(Source: TSdSourceFunc; Files: TStrings);
var
  Dirs, Names, Seen, Todo: TStringList;
  I, J: Integer;
  F: string;

  { the units a source uses (its uses clauses, read from its tokens: no parse), the ones not seen
    yet for the search }
  procedure Scan(const FileName: string);
  var
    Text: string;
    K: Integer;
  begin
    try
      Text := Source(FileName);
    except
      Exit;                      // neither a page nor a file: it names nothing
    end;
    Names.Clear;
    UsesClauseNames(Text, Names);
    for K := 0 to Names.Count - 1 do
      if Seen.IndexOf(Names[K]) < 0 then
      begin
        Seen.Add(Names[K]);
        Todo.Add(Names[K]);
      end;
  end;

begin
  Dirs := TStringList.Create;
  Names := TStringList.Create;
  Seen := TStringList.Create;
  Todo := TStringList.Create;
  try
    Seen.Sorted := True;
    Dirs.Add(ExcludeTrailingPathDelimiter(Dir));
    AddPathList(Dirs, UnitSearchPath, Dir);
    for I := 0 to Dirs.Count - 1 do Dirs[I] := IncludeTrailingPathDelimiter(Dirs[I]);
    for I := 0 to UnitCount - 1 do Seen.Add(Units[I].Name);
    Scan(FFileName);
    for I := 0 to UnitCount - 1 do Scan(Units[I].FileName);
    { Todo grows while it is gone through: the units of each file found }
    I := 0;
    while I < Todo.Count do
    begin
      for J := 0 to Dirs.Count - 1 do
      begin
        F := Dirs[J] + Todo[I] + '.pas';
        if FileExistsU(F) then
        begin
          Files.Add(F);
          Scan(F);
          Break;
        end;
      end;
      Inc(I);
    end;
  finally
    Dirs.Free;
    Names.Free;
    Seen.Free;
    Todo.Free;
  end;
end;

function TSdProject.DirOpt(const Key: string): string;
begin
  Result := ExpandPathMacros(OptStr('Directories', Key, ''));
end;

{ the project's value, else the default options' (Delphi's defproj.dof or D7 Studio's), else Default }
function TSdProject.OptStr(const Section, Key, Default: string): string;
begin
  { a key that is there answers its value (also an empty one), else the default #1: the
    ini file's ValueExists would read the names of the whole section first (asked at every idle) }
  if FDof <> nil then Result := FDof.ReadString(Section, Key, #1) else Result := #1;
  if Result = #1 then Result := DefaultOptions.ReadString(Section, Key, Default);
end;

function TSdProject.Conditionals: string;
var
  S, D: string;
  I: Integer;
begin
  Result := '';
  S := OptStr('Directories', 'Conditionals', '');
  while S <> '' do
  begin
    I := Pos(';', S);
    if I = 0 then I := Length(S) + 1;
    D := Trim(Copy(S, 1, I - 1));
    Delete(S, 1, I);
    if D <> '' then Result := Result + D + CRLF;
  end;
end;

function TSdProject.OptInt(const Section, Key: string; Default: Integer): Integer;
begin
  Result := StrToIntDef(OptStr(Section, Key, IntToStr(Default)), Default);
end;

procedure TSdProject.SetOptStr(const Section, Key, Value: string);
begin
  if FDof <> nil then FDof.WriteString(Section, Key, Value);
end;

procedure TSdProject.SetOptInt(const Section, Key: string; Value: Integer);
begin
  if FDof <> nil then FDof.WriteInteger(Section, Key, Value);
end;

procedure TSdProject.SaveOptions;
begin
  if FDof = nil then Exit;
  if IsDefaults then
  begin
    ForceDirectories(ExtractFilePath(DefaultOptionsFile));
    WriteSystemIniFile(FDof);
    FreeAndNil(FDefaultOptions);
    Exit;
  end;
  if not FDof.SectionExists('FileVersion') then FDof.WriteString('FileVersion', 'Version', '7.0');
  WriteSystemIniFile(FDof);
  WriteCfg;
  { renamed in memory (Rename): its resources go to the new name too }
  if FRenamedFrom <> '' then
  begin
    if FileExists(ChangeFileExt(FRenamedFrom, '.res')) and not FileExists(ChangeFileExt(FFileName, '.res')) then
      CopyFile(PChar(ChangeFileExt(FRenamedFrom, '.res')), PChar(ChangeFileExt(FFileName, '.res')), True);
    FRenamedFrom := '';
  end;
end;

const
  BoolSwitches = 'BCDEFGHIJKLMNOPQRSTUVWX';
  BoolDefaults: array[1..23] of Integer = (0, 1, 1, 0, 0, 1, 1, 1, 0, 0, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 1, 0, 1);

function CompilerSwitchDefault(Switch: Char): Integer;
var
  I: Integer;
begin
  case Switch of
    'A': Result := 8;
    'Y', 'Z': Result := 1;
  else
    I := Pos(Switch, BoolSwitches);
    if I > 0 then Result := BoolDefaults[I] else Result := 0;
  end;
end;

{ the file is there and holds exactly Text }
function FileHolds(const FileName, Text: string): Boolean;
begin
  try
    Result := FileExistsU(FileName) and (ReadFileU(FileName) = Text);
  except
    Result := False;
  end;
end;

{ a folder for a list of folders or a compiler argument: without its trailing backslash - but a
  drive's root keeps it ("D:" alone is the current folder of drive D, not its root) }
function FolderArg(const Dir: string): string;
begin
  Result := ExcludeTrailingPathDelimiter(Dir);
  if (Length(Result) = 2) and (Result[2] = ':') then Result := Result + '\';
end;

procedure TSdProject.WriteCfg(const CfgFile: string = ''; const ExtraDirs: string = ''; Utf8: Boolean = False);
var
  L: TStringList;
  I, V: Integer;
  S, T: string;
  C: Char;
  Lost: Boolean;

  { dcc64 takes \" as a quote that belongs to the path: a path that ends with
    a backslash gets a "." ("C:\dir\." is the folder, a drive's root too). The compiler reads the
    system code page: a folder with other characters is named by its short name }
  procedure PathOpt(const Flag, Value: string);
  var
    V: string;
  begin
    V := CompilerPaths(Value);
    if (V <> '') and (V[Length(V)] = '\') and (Platform = spWin64) then V := V + '.';
    if V <> '' then L.Add('-' + Flag + '"' + V + '"');
  end;

begin
  if FFileName = '' then Exit;
  L := TStringList.Create;
  try
    L.Add('-$A' + IntToStr(OptInt('Compiler', 'A', CompilerSwitchDefault('A'))));
    for I := 1 to Length(BoolSwitches) do
    begin
      C := BoolSwitches[I];
      V := OptInt('Compiler', C, CompilerSwitchDefault(C));
      if V <> 0 then L.Add('-$' + C + '+') else L.Add('-$' + C + '-');
    end;
    { Delphi's pair defproj.dof / defproj.cfg: Y=1 is -$YD (definitions only), Y=2 -$Y+ }
    case OptInt('Compiler', 'Y', CompilerSwitchDefault('Y')) of
      0: L.Add('-$Y-');
      2: L.Add('-$Y+');
    else
      L.Add('-$YD');
    end;
    L.Add('-$Z' + IntToStr(OptInt('Compiler', 'Z', CompilerSwitchDefault('Z'))));
    if OptInt('Linker', 'ConsoleApp', 1) = 0 then L.Add('-cc') else L.Add('-cg');
    S := OptStr('Compiler', 'UnitAliases', 'WinTypes=Windows;WinProcs=Windows;DbiTypes=BDE;DbiProcs=BDE;DbiErrs=BDE;');
    if S <> '' then L.Add('-A' + S);
    if OptInt('Compiler', 'ShowHints', 1) <> 0 then L.Add('-H+') else L.Add('-H-');
    if OptInt('Compiler', 'ShowWarnings', 1) <> 0 then L.Add('-W+') else L.Add('-W-');
    L.Add('-M');
    L.Add(Format('-$M%d,%d', [OptInt('Linker', 'MinStackSize', 16384), OptInt('Linker', 'MaxStackSize', 1048576)]));
    L.Add('-K$' + IntToHex(OptInt('Linker', 'ImageBase', $400000), 8));
    case OptInt('Linker', 'MapFile', 0) of
      1: L.Add('-GS');
      2: L.Add('-GP');
      3: L.Add('-GD');
    end;
    if OptInt('Linker', 'DebugInfo', 0) <> 0 then L.Add('-V');
    if OptInt('Linker', 'RemoteSymbols', 0) <> 0 then L.Add('-VR');
    { Linker | Linker output: DCUs, C object files (-J) or C++ object files with their headers
      (-JPH, N = namespaces, E = export all symbols) }
    case OptInt('Linker', 'OutputObjs', 0) of
      1: L.Add('-J');
      2:
        begin
          S := '-JPH';
          if OptInt(ThemeSection, 'ObjNamespaces', 0) <> 0 then S := S + 'N';
          if OptInt(ThemeSection, 'ObjExportAll', 0) <> 0 then S := S + 'E';
          L.Add(S);
        end;
    end;
    { Application | Target file extension }
    if Trim(OptStr(ThemeSection, 'TargetExt', '')) <> '' then L.Add('-TX' + TargetExt);
    { Compiler Messages: each warning on or off (-W+IDENT / -W-IDENT: dcc32 and dcc64 alike) }
    for I := Low(CompilerWarnings) to High(CompilerWarnings) do
    begin
      V := OptInt('Compiler', CompilerWarnings[I].Key, Ord(WarningOnByDefault(CompilerWarnings[I])));
      if V <> 0 then L.Add('-W+' + CompilerWarnings[I].Ident) else L.Add('-W-' + CompilerWarnings[I].Ident);
    end;
    { without -E the program would be written next to the scratch copy of the project source }
    if CfgFile <> '' then PathOpt('E', FolderArg(OutputDir))
    else PathOpt('E', PlatformDirOpt(Self, 'OutputDir'));
    if Platform = spWin64 then
    begin
      PathOpt('NU', PlatformDirOpt(Self, 'UnitOutputDir'));
      L.Add('-NS' + Win64UnitScopes);
    end
    else
      PathOpt('N', DirOpt('UnitOutputDir'));
    { the .bpl and .dcp of a package go where the IDE finds them }
    if IsPackage then
    begin
      PathOpt('LE', FolderArg(PackageOutputDir));
      PathOpt('LN', FolderArg(DcpOutputDir));
    end;
    S := UnitSearchPath;
    PathOpt('U', S);
    PathOpt('O', S);
    if (ExtraDirs <> '') and (S <> '') then S := ExtraDirs + ';' + S else S := ExtraDirs + S;
    PathOpt('I', S);
    PathOpt('R', S);
    S := OptStr('Directories', 'Conditionals', '');
    if S <> '' then L.Add('-D' + S);
    if OptInt('Directories', 'UsePackages', 0) <> 0 then
    begin
      S := OptStr('Directories', 'Packages', '');
      if S <> '' then L.Add('-LU' + S);
    end;
    { a .cfg that says this already is left alone (also when it is read-only); one that cannot
      be written raises - the compiler would read stale options. It is in the compiler's code
      page: the system's for dcc32, UTF-8 - D7 Studio's text - for the UTF-8 compiler }
    if CfgFile <> '' then S := CfgFile else S := ChangeFileExt(FFileName, '.cfg');
    if Utf8 then T := L.Text else T := IdeToSystem(L.Text, Lost);
    if not FileHolds(S, T) then WriteFileU(S, T);
  finally
    L.Free;
  end;
end;

{ ---------------------------------------------------------------- RAD Studio (Win64) }

var
  RadRoot: string;
  RadRootDone: Boolean;

{ "23.0" > "9.0": compares the numbers before and after the dot (no StrToFloat: the decimal
  separator of the locale) }
function NewerVersion(const A, B: string): Boolean;
var
  MA, MB: Integer;
begin
  MA := StrToIntDef(Copy(A, 1, Pos('.', A + '.') - 1), -1);
  MB := StrToIntDef(Copy(B, 1, Pos('.', B + '.') - 1), -1);
  if MA <> MB then Result := MA > MB
  else Result := StrToIntDef(Copy(A, Pos('.', A + '.') + 1, 9), 0) > StrToIntDef(Copy(B, Pos('.', B + '.') + 1, 9), 0);
end;

{ the root folder of the newest RAD Studio that has dcc64, from its registration (the user's
  and the machine's: HKLM is read through WOW6432Node by this 32-bit program) }
function RadStudioRoot: string;
const
  Roots: array[0..1] of HKEY = (HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE);
var
  R: TRegistry;
  Keys: TStringList;
  I, J: Integer;
  Best, Dir: string;
begin
  if not RadRootDone then
  begin
    RadRootDone := True;
    Best := '';
    Keys := TStringList.Create;
    R := TRegistry.Create(KEY_READ);
    try
      for I := Low(Roots) to High(Roots) do
      begin
        R.RootKey := Roots[I];
        if not R.OpenKeyReadOnly('Software\Embarcadero\BDS') then Continue;
        R.GetKeyNames(Keys);
        R.CloseKey;
        for J := 0 to Keys.Count - 1 do
          if (Best = '') or NewerVersion(Keys[J], Best) then
            if R.OpenKeyReadOnly('Software\Embarcadero\BDS\' + Keys[J]) then
            begin
              Dir := IncludeTrailingPathDelimiter(R.ReadString('RootDir'));
              R.CloseKey;
              if FileExists(Dir + 'bin\dcc64.exe') then
              begin
                Best := Keys[J];
                RadRoot := Dir;
              end;
            end;
      end;
    finally
      R.Free;
      Keys.Free;
    end;
  end;
  Result := RadRoot;
end;

function Dcc64Exe: string;
begin
  if RadStudioRoot <> '' then Result := RadStudioRoot + 'bin\dcc64.exe' else Result := '';
end;

function Dcc32Utf8Exe: string;
begin
  Result := DelphiBin + 'dcc32u8.exe';
  if not FileExists(Result) or not FileExists(Result + '.manifest') then Result := '';
end;

function Win64PackageDir: string;
begin
  if RadStudioRoot <> '' then Result := RadStudioRoot + 'bin64' else Result := '';
end;

{ ---------------------------------------------------------------- TSdCompiler }

constructor TSdCompiler.Create;
begin
  inherited Create;
  FMessages := TObjectList.Create(True);
  FLineCounts := TStringList.Create;
  FLineCounts.Sorted := True;
  FLineCounts.Duplicates := dupIgnore;
  FNotes := TStringList.Create;
end;

destructor TSdCompiler.Destroy;
begin
  FNotes.Free;
  FLineCounts.Free;
  FMessages.Free;
  inherited;
end;

{ "C:\Program Files (x86)\x\Unit1.pas(123) Error: text" -> file, 123, "Error: text".
  The line number is the first "(digits)" right after a name (not after a blank) that is followed
  by a blank or ends the text - the path itself may contain parentheses ("New folder (2) x"). }
function SplitFileLine(const S: string; var FileName: string; var LineNo: Integer; var Rest: string): Boolean;
var
  I, J: Integer;
begin
  Result := False;
  for I := 2 to Length(S) do
    if S[I] = ')' then
    begin
      J := I - 1;
      while (J > 0) and (S[J] in ['0'..'9']) do Dec(J);
      if (J > 1) and (J < I - 1) and (S[J] = '(') and (S[J - 1] <> ' ') and ((I = Length(S)) or (S[I + 1] = ' ')) then
      begin
        FileName := Copy(S, 1, J - 1);
        LineNo := StrToIntDef(Copy(S, J + 1, I - J - 1), 0);
        Rest := Copy(S, I + 2, MaxInt);
        Result := True;
        Exit;
      end;
    end;
end;

procedure TSdCompiler.Progress(const Segment: string);
var
  F, Rest: string;
  N, I, Old: Integer;
begin
  if not SplitFileLine(Segment, F, N, Rest) then Exit;
  { the compiler comes back to a file after the units it uses: count each file once, up to the
    highest line seen }
  I := FLineCounts.IndexOf(F);
  if I < 0 then I := FLineCounts.AddObject(F, nil);
  Old := Integer(FLineCounts.Objects[I]);
  if N > Old then
  begin
    FLineCounts.Objects[I] := TObject(N);
    Inc(FTotalLines, N - Old);
  end;
  if Assigned(FOnProgress) then FOnProgress(F, N, FTotalLines);
end;

procedure TSdCompiler.Cancel;
begin
  if FRunning and (FProcess <> 0) then
  begin
    FCancelled := True;
    TerminateProcess(FProcess, 1);
  end;
end;

function TSdCompiler.GetMessage(Index: Integer): TCompilerMessage;
begin
  Result := TCompilerMessage(FMessages[Index]);
end;

function TSdCompiler.MessageCount: Integer;
begin
  Result := FMessages.Count;
end;

procedure TSdCompiler.ParseLine(const Line, WorkDir, SearchPath: string);
var
  P, LineNo, I: Integer;
  FileName, Rest, KindStr, Text, Full: string;
  Kind: TMsgKind;
  M: TCompilerMessage;
  Dirs: TStringList;
begin
  if Trim(Line) = '' then Exit;
  { "File.pas(123) Error: text"  /  "Fatal: text"  /  "N lines, 0.05 seconds, ..." }
  Kind := mkInfo;
  FileName := '';
  LineNo := 0;
  Text := Line;
  if SplitFileLine(Line, FileName, LineNo, Rest) then
  begin
    { "Unit1.pas(41) " alone is the progress report of a finished unit, not a message }
    if Trim(Rest) = '' then Exit;
  end
  else
  begin
    FileName := '';
    LineNo := 0;
    Rest := Line;
  end;
  P := Pos(': ', Rest);
  if P > 0 then
  begin
    KindStr := Copy(Rest, 1, P - 1);
    if KindStr = 'Error' then Kind := mkError
    else if KindStr = 'Fatal' then Kind := mkFatal
    else if KindStr = 'Warning' then Kind := mkWarning
    else if KindStr = 'Hint' then Kind := mkHint;
    if Kind <> mkInfo then Text := Copy(Rest, P + 2, MaxInt);
  end;
  if Kind = mkInfo then
  begin
    if (Pos(' lines, ', Line) > 0) and (Pos(' seconds', Line) > 0) then FSummary := Line;
    if (Pos('Borland Delphi', Line) = 1) or (Pos('Embarcadero Delphi', Line) = 1) or
      (Pos('Copyright (c)', Line) = 1) then Exit;
    FileName := '';
    LineNo := 0;
  end;
  M := TCompilerMessage.Create;
  M.Kind := Kind;
  M.Line := LineNo;
  if FileName <> '' then
  begin
    if IsAbsolutePath(FileName) then
      Full := FileName
    else
      Full := ExpandFileName(IncludeTrailingPathDelimiter(WorkDir) + FileName);
    if not FileExists(Full) then
    begin
      { the folders of the search path (relative ones from the project folder) }
      Dirs := TStringList.Create;
      try
        AddPathList(Dirs, SearchPath, WorkDir);
        for I := 0 to Dirs.Count - 1 do
          if FileExists(IncludeTrailingPathDelimiter(Dirs[I]) + ExtractFileName(FileName)) then
          begin
            Full := IncludeTrailingPathDelimiter(Dirs[I]) + ExtractFileName(FileName);
            Break;
          end;
      finally
        Dirs.Free;
      end;
    end;
    M.FileName := Full;
  end;
  case Kind of
    mkError:
      begin
        Inc(FErrors);
        M.Text := Format('[Error] %s(%d): %s', [ExtractFileName(FileName), LineNo, Text]);
      end;
    mkFatal:
      begin
        Inc(FErrors);
        if FileName <> '' then
          M.Text := Format('[Fatal Error] %s(%d): %s', [ExtractFileName(FileName), LineNo, Text])
        else
          M.Text := '[Fatal Error] ' + Text;
      end;
    mkWarning:
      begin
        Inc(FWarnings);
        M.Text := Format('[Warning] %s(%d): %s', [ExtractFileName(FileName), LineNo, Text]);
      end;
    mkHint:
      begin
        Inc(FHints);
        M.Text := Format('[Hint] %s(%d): %s', [ExtractFileName(FileName), LineNo, Text]);
      end;
  else
    M.Text := Line;
  end;
  FMessages.Add(M);
  if Assigned(FOnOutput) then FOnOutput(M.Text);
end;

procedure TSdCompiler.Note(Lines: TStrings);
begin
  FNotes.Assign(Lines);
end;

function TSdCompiler.Fail(Lines: TStrings; const WorkDir: string): Boolean;
var
  I: Integer;
begin
  FMessages.Clear;
  FErrors := 0;
  FWarnings := 0;
  FHints := 0;
  FSummary := '';
  FCancelled := False;
  FLineCounts.Clear;
  FTotalLines := 0;
  FExitCode := 1;
  for I := 0 to FNotes.Count - 1 do ParseLine(FNotes[I], WorkDir, '');
  FNotes.Clear;
  for I := 0 to Lines.Count - 1 do ParseLine(Lines[I], WorkDir, '');
  Result := False;
end;

{ starts the console program CmdLine in WorkDir without a window, what it writes to stdout and
  stderr into one pipe: ReadPipe its reading end, which the program does not inherit. Only the
  program keeps the writing end, so the pipe ends when the program has ended. False when the pipe
  or the program cannot be made: nothing is left open then, GetLastError tells why }
function StartPiped(const CmdLine, WorkDir: string; out ReadPipe: THandle;
  out PI: TProcessInformation): Boolean;
var
  SA: TSecurityAttributes;
  WritePipe: THandle;
  SI: TStartupInfo;
  Cmd: string;
  Error: DWORD;
begin
  Result := False;
  SA.nLength := SizeOf(SA);
  SA.lpSecurityDescriptor := nil;
  SA.bInheritHandle := True;
  if not CreatePipe(ReadPipe, WritePipe, @SA, 65536) then
  begin
    ReadPipe := 0;
    Exit;
  end;
  SetHandleInformation(ReadPipe, HANDLE_FLAG_INHERIT, 0);
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_HIDE;
  SI.hStdOutput := WritePipe;
  SI.hStdError := WritePipe;
  SI.hStdInput := GetStdHandle(STD_INPUT_HANDLE);
  Cmd := CmdLine;
  UniqueString(Cmd);                   // CreateProcess may write into the command line
  Result := CreateProcess(nil, PChar(Cmd), nil, nil, True, CREATE_NO_WINDOW, nil, PChar(WorkDir), SI, PI);
  Error := GetLastError;
  CloseHandle(WritePipe);
  if not Result then
  begin
    CloseHandle(ReadPipe);
    ReadPipe := 0;
    SetLastError(Error);
  end;
end;

function TSdCompiler.Run(const Dcc32, Args, WorkDir, SearchPath: string): Boolean;
var
  ReadPipe: THandle;
  PI: TProcessInformation;
  Cmd, Buf, Pending, Line: string;
  Avail, Got: DWORD;
  P, I: Integer;
  Done: Boolean;

  procedure Drain;
  begin
    while PeekNamedPipe(ReadPipe, nil, 0, nil, @Avail, nil) and (Avail > 0) do
    begin
      SetLength(Buf, Avail);
      if not ReadFile(ReadPipe, Buf[1], Avail, Got, nil) or (Got = 0) then Break;
      Pending := Pending + Copy(Buf, 1, Got);
      repeat
        P := Pos(#10, Pending);
        if P = 0 then Break;
        Line := Copy(Pending, 1, P - 1);
        Delete(Pending, 1, P);
        if (Line <> '') and (Line[Length(Line)] = #13) then SetLength(Line, Length(Line) - 1);
        { the compiler writes in the system code page, D7 Studio's text is UTF-8 (UTF-8 mode) }
        Line := SystemToIde(Line);
        { "file(line) " position reports overwrite each other with carriage returns; the last
          segment of the line is the final position, possibly followed by a message }
        while Pos(#13, Line) > 0 do
        begin
          P := Pos(#13, Line);
          if P > 1 then Progress(Copy(Line, 1, P - 1));
          Delete(Line, 1, P);
        end;
        Progress(Line);
        ParseLine(Line, WorkDir, SearchPath);
      until False;
      { position reports of the unit that is still being compiled (no line end yet); a
        carriage return at the very end may be the first half of a CR LF }
      repeat
        P := Pos(#13, Pending);
        if (P = 0) or (P = Length(Pending)) then Break;
        if P > 1 then Progress(SystemToIde(Copy(Pending, 1, P - 1)));
        Delete(Pending, 1, P);
      until False;
    end;
  end;

begin
  Result := False;
  FMessages.Clear;
  FErrors := 0;
  FWarnings := 0;
  FHints := 0;
  FSummary := '';
  FCancelled := False;
  FLineCounts.Clear;
  FTotalLines := 0;
  FExitCode := Cardinal(-1);
  for I := 0 to FNotes.Count - 1 do ParseLine(FNotes[I], WorkDir, SearchPath);
  FNotes.Clear;
  if not FileExists(Dcc32) then
  begin
    ParseLine('Fatal: Compiler not found: ' + Dcc32, WorkDir, '');
    Exit;
  end;
  Cmd := '"' + Dcc32 + '" ' + Args;
  FRunning := True;
  try
    if not StartPiped(Cmd, WorkDir, ReadPipe, PI) then
    begin
      ParseLine('Fatal: Cannot start the compiler (' + SysErrorMessage(GetLastError) + ')', WorkDir, '');
      Exit;
    end;
    FProcess := PI.hProcess;
    try
      Pending := '';
      repeat
        Done := WaitForSingleObject(PI.hProcess, 30) <> WAIT_TIMEOUT;
        Drain;
        Application.ProcessMessages;
      until Done;
      Drain;
      if Pending <> '' then
      begin
        while Pos(#13, Pending) > 0 do Delete(Pending, 1, Pos(#13, Pending));
        ParseLine(Pending, WorkDir, SearchPath);
      end;
      GetExitCodeProcess(PI.hProcess, FExitCode);
    finally
      { also after an exception (in a handler of OnOutput or OnProgress): no compiler is left
        running, no handle open }
      if WaitForSingleObject(PI.hProcess, 0) = WAIT_TIMEOUT then TerminateProcess(PI.hProcess, 1);
      CloseHandle(PI.hThread);
      CloseHandle(PI.hProcess);
      CloseHandle(ReadPipe);
    end;
  finally
    FProcess := 0;
    FRunning := False;
  end;
  { the "N lines" of the summary is the exact total }
  P := Pos(' lines, ', FSummary);
  if P > 1 then FTotalLines := StrToIntDef(Trim(Copy(FSummary, 1, P - 1)), FTotalLines);
  Result := (FExitCode = 0) and (FErrors = 0) and not FCancelled;
end;

{ ---------------------------------------------------------------- resource scripts }

{ runs a console program (CmdLine, in WorkDir) without a window and waits for it - brcc32 takes
  a moment: what it wrote (its output and its errors) and its exit code; False when it cannot
  start }
function RunConsoleTool(const CmdLine, WorkDir: string; out Output: string; out Code: Cardinal): Boolean;
var
  ReadPipe: THandle;
  PI: TProcessInformation;
  Chunk: string;
  Buf: array[0..4095] of Char;
  Got: DWORD;
begin
  Output := '';
  Code := Cardinal(-1);
  Result := StartPiped(CmdLine, WorkDir, ReadPipe, PI);
  if not Result then Exit;
  try
    try
      while ReadFile(ReadPipe, Buf, SizeOf(Buf), Got, nil) and (Got > 0) do
      begin
        SetString(Chunk, Buf, Got);
        Output := Output + Chunk;
      end;
      WaitForSingleObject(PI.hProcess, INFINITE);
      GetExitCodeProcess(PI.hProcess, Code);
    finally
      CloseHandle(PI.hThread);
      CloseHandle(PI.hProcess);
    end;
  finally
    CloseHandle(ReadPipe);
  end;
end;

{ a line of brcc32's: "Error <file> <line> <column>: <text>" (Warning, Fatal) - False for
  another one (its banner); FileName '' when it names no place ("Error Could not open input file
  x.rc") }
function ParseBrccLine(const Line: string; out Kind, FileName: string; out LineNo: Integer;
  out Text: string): Boolean;
var
  P, Q: Integer;
  Head: string;
begin
  Result := False;
  FileName := '';
  LineNo := 0;
  P := Pos(' ', Line);
  if P = 0 then Exit;
  Kind := Copy(Line, 1, P - 1);
  if (Kind <> 'Error') and (Kind <> 'Warning') and (Kind <> 'Fatal') then Exit;
  Result := True;
  Text := Trim(Copy(Line, P + 1, MaxInt));
  Q := Pos(': ', Text);
  if Q = 0 then Exit;
  Head := Copy(Text, 1, Q - 1);                // "<file> <line> <column>": the file may have blanks
  P := LastDelimiter(' ', Head);
  if (P = 0) or (StrToIntDef(Copy(Head, P + 1, MaxInt), -1) < 0) then Exit;
  Head := Copy(Head, 1, P - 1);
  P := LastDelimiter(' ', Head);
  if (P = 0) or (StrToIntDef(Copy(Head, P + 1, MaxInt), -1) < 0) then Exit;
  LineNo := StrToInt(Copy(Head, P + 1, MaxInt));
  FileName := Copy(Head, 1, P - 1);
  Text := Copy(Text, Q + 2, MaxInt);
end;

{ the last write of a file (FILETIME, UTC); -1 when it is not there }
function StampTime(const FileName: string): Int64;
var
  S: TSdFileStamp;
begin
  S := FileStampU(FileName);
  if S.Exists then Result := Int64(S.Time) else Result := -1;
end;

procedure ResScriptInputs(const RcFile: string; Files: TStrings);
var
  S, Dir, W: string;
  I, J, N: Integer;

  { a name of the script: a file, as written or with its \\ escapes undone }
  procedure Take(const Name: string);
  var
    K: Integer;
    F: string;
  begin
    if Pos('.', Name) = 0 then Exit;
    for K := 0 to 1 do
    begin
      if K = 0 then F := Name
      else
      begin
        F := StringReplace(Name, '\\', '\', [rfReplaceAll]);
        if F = Name then Exit;
      end;
      if not IsAbsolutePath(F) then F := ExpandFileName(Dir + F);
      if not SameText(F, RcFile) and FileExistsU(F) then
      begin
        if Files.IndexOf(F) < 0 then Files.Add(F);
        Exit;
      end;
    end;
  end;

begin
  Files.Clear;
  try
    S := ReadFileU(RcFile);
  except
    Exit;
  end;
  Dir := ExtractFilePath(RcFile);
  N := Length(S);
  I := 1;
  while I <= N do
    if S[I] <= ' ' then Inc(I)
    else if (S[I] = '/') and (I < N) and (S[I + 1] = '*') then
    begin
      J := PosEx('*/', S, I + 2);
      if J = 0 then Break;
      I := J + 2;
    end
    else if (S[I] = '/') and (I < N) and (S[I + 1] = '/') then
    begin
      while (I <= N) and not (S[I] in [#10, #13]) do Inc(I);
    end
    else if S[I] = '"' then
    begin
      { a string: "" is a quote, a backslash takes the next character along }
      W := '';
      Inc(I);
      while (I <= N) and not (S[I] in [#10, #13]) do
        if (S[I] = '\') and (I < N) then
        begin
          W := W + S[I] + S[I + 1];
          Inc(I, 2);
        end
        else if S[I] <> '"' then
        begin
          W := W + S[I];
          Inc(I);
        end
        else if (I < N) and (S[I + 1] = '"') then
        begin
          W := W + '"';
          Inc(I, 2);
        end
        else
        begin
          Inc(I);
          Break;
        end;
      Take(W);
    end
    else
    begin
      J := I;
      while (I <= N) and (S[I] > ' ') and not (S[I] in [',', '"']) do Inc(I);
      if I = J then Inc(I) else Take(Copy(S, J, I - J));
    end;
end;

{ one resource script compiled by brcc32 in its folder - from a copy of Bytes of the same name in
  a temporary folder when Unsaved -, its messages added to Messages }
function CompileResScript(R: TProjectResScript; const Brcc32: string; Messages: TStrings;
  Unsaved: Boolean; const Bytes: string): Boolean;
var
  Dir, Scratch, Input, Cmd, Output, Kind, F, Text, CodeText: string;
  Status: Cardinal;
  Lines: TStringList;
  I, LineNo, Errors: Integer;
begin
  Result := False;
  if not FileExistsU(Brcc32) then
  begin
    Messages.Add('Fatal: Resource compiler not found: ' + Brcc32);
    Exit;
  end;
  Dir := ExtractFilePath(R.FileName);
  ForceDirectories(ExtractFilePath(R.ResFileName));
  Scratch := '';
  if Unsaved then
  begin
    Scratch := TempFolder + 'D7Studio-rc' + IntToStr(GetCurrentProcessId) + '\';
    ForceDirectories(Scratch);
    WriteFileU(Scratch + ExtractFileName(R.FileName), Bytes);
    Input := CompilerPath(Scratch + ExtractFileName(R.FileName));
  end
  else
    Input := ExtractFileName(CompilerPath(R.FileName));
  { brcc32 reads its command line in the system code page: names it takes (CompilerPath) }
  Cmd := '"' + CompilerPath(Brcc32) + '" -fo"' + CompilerPath(ExcludeTrailingPathDelimiter(ExtractFilePath(R.ResFileName))) +
    '\' + ExtractFileName(R.ResFileName) + '" "' + Input + '"';
  try
    if not RunConsoleTool(Cmd, FolderArg(Dir), Output, Status) then
    begin
      Messages.Add('Fatal: Cannot start the resource compiler (' + SysErrorMessage(GetLastError) + ')');
      Exit;
    end;
  finally
    if Scratch <> '' then
    begin
      DeleteFile(Scratch + ExtractFileName(R.FileName));
      RemoveDir(Scratch);
    end;
  end;
  Errors := 0;
  Lines := TStringList.Create;
  try
    Lines.Text := SystemToIde(Output);
    for I := 0 to Lines.Count - 1 do
    begin
      if not ParseBrccLine(Trim(Lines[I]), Kind, F, LineNo, Text) then Continue;
      if Kind <> 'Warning' then Inc(Errors);
      if F = '' then
      begin
        if Kind = 'Warning' then Messages.Add(Format('%s(1) Warning: %s', [R.FileName, Text]))
        else Messages.Add(Format('Fatal: %s: %s', [ExtractFileName(R.FileName), Text]));
        Continue;
      end;
      { the script by the name brcc32 had, else a file it names, from the script's folder }
      if SameText(F, ExtractFileName(Input)) or SameText(F, Input) then F := R.FileName
      else if not IsAbsolutePath(F) then F := ExpandFileName(Dir + F);
      Messages.Add(Format('%s(%d) %s: %s', [F, LineNo, Kind, Text]));
    end;
  finally
    Lines.Free;
  end;
  Result := (Status = 0) and (Errors = 0);
  if not Result and (Errors = 0) then
  begin
    if Status >= $C0000000 then CodeText := '$' + IntToHex(Status, 8) else CodeText := IntToStr(Status);
    Messages.Add(Format('Fatal: %s: brcc32 ended with exit code %s', [ExtractFileName(R.FileName), CodeText]));
  end;
  { brcc32 writes a .res without resources, and says nothing, when its folder lies in a folder
    whose name begins with a dot }
  if Result and (FileStampU(R.ResFileName).Size <= 32) then
    Messages.Add(Format('%s(1) Warning: brcc32 wrote no resources into %s', [R.FileName, ExtractFileName(R.ResFileName)]));
end;

function CompileResScripts(P: TSdProject; const Brcc32: string; Build: Boolean; Messages: TStrings;
  Unsaved: TSdUnsavedFunc): Boolean;
var
  I, K: Integer;
  R: TProjectResScript;
  Inputs: TStringList;
  ResTime: Int64;
  Stale, Modified: Boolean;
  Bytes: string;
begin
  Result := True;
  Inputs := TStringList.Create;
  try
    for I := 0 to P.ResScriptCount - 1 do
    begin
      R := P.ResScripts[I];
      Bytes := '';
      Modified := Assigned(Unsaved) and Unsaved(R.FileName, Bytes);
      if not Modified and not FileExistsU(R.FileName) then
      begin
        Messages.Add(Format('Fatal: File not found: ''%s''', [R.RelRc]));
        Result := False;
        Continue;
      end;
      ResTime := StampTime(R.ResFileName);
      Stale := Build or Modified or (ResTime < 0) or (StampTime(R.FileName) > ResTime);
      if not Stale then
      begin
        ResScriptInputs(R.FileName, Inputs);
        for K := 0 to Inputs.Count - 1 do
          if StampTime(Inputs[K]) > ResTime then
          begin
            Stale := True;
            Break;
          end;
      end;
      if Stale and not CompileResScript(R, Brcc32, Messages, Modified, Bytes) then Result := False;
    end;
  finally
    Inputs.Free;
  end;
end;

{ ---------------------------------------------------------------- code-page sources }

{ a source held in encoding E (Text: its editor text) is not as the compiler must read it - Utf8:
  UTF-8 without byte order mark, for a program in UTF-8; else a code page. The editor text of a
  Unicode encoding is UTF-8: its bytes are dcc32's when the file is UTF-8 without byte order mark
  (Delphi 7 refuses one) and, for a code page, all ASCII }
function SourceNeedsCopy(const Text: string; const E: TSdEncoding; Utf8: Boolean): Boolean;
begin
  if not Utf8 then
    Result := IsUnicodeEncoding(E) and ((E.CodePage <> CP_UTF8) or E.BOM or HasHighBytes(Text))
  else if IsUnicodeEncoding(E) then
    Result := (E.CodePage <> CP_UTF8) or E.BOM
  else
    Result := HasHighBytes(Text);
end;

function CodePageSource(const FileName, Text: string; const E: TSdEncoding; Warnings: TStrings;
  out Bytes: string; Utf8: Boolean = False): Boolean;
var
  Toks: TRawToks;
  Lost, AsIs: Boolean;
  I, Line: Integer;
  S: string;
begin
  Bytes := '';
  Result := SourceNeedsCopy(Text, E, Utf8);
  if not Result then Exit;
  if Utf8 then
  begin
    { a program in UTF-8: the editor text of a Unicode encoding is its UTF-8 already (a byte order
      mark dropped), a code-page file's characters become UTF-8 }
    if IsUnicodeEncoding(E) then Bytes := Text
    else Bytes := FromWide(ToWide(Text, E.CodePage), CP_UTF8, Lost);
    Exit;
  end;
  Bytes := FromWide(ToWide(Text, CP_UTF8), SystemEncoding.CodePage, Lost);
  if not Lost then Exit;
  { where: a comment may lose characters (they mean nothing to the compiler); a string, a
    directive (a file name) or anything else may not - the file is compiled as Delphi 7 compiles
    it, one warning per line }
  AsIs := False;
  Toks := TRawToks.Create(Text);
  try
    Line := 0;
    for I := 0 to Toks.N - 1 do
    begin
      if (Toks.T[I].Line = Line) or ((Toks.T[I].Kind = tkComment) and not Toks.IsDirective(I)) then Continue;
      S := Toks.Txt(I);
      if not HasHighBytes(S) then Continue;
      FromWide(ToWide(S, CP_UTF8), SystemEncoding.CodePage, Lost);
      if not Lost then Continue;
      Line := Toks.T[I].Line;
      AsIs := True;
      Warnings.Add(Format('%s(%d) Warning: Character not in the system code page (%s): the file is ' +
        'compiled as its UTF-8 bytes, as Delphi 7 reads it', [FileName, Line, EncodingShortName(SystemEncoding)]));
    end;
  finally
    Toks.Free;
  end;
  if not AsIs then Exit;
  { UTF-8 without byte order mark: the file's own bytes }
  Result := (E.CodePage <> CP_UTF8) or E.BOM;
  if Result then Bytes := Text else Bytes := '';
end;

function HasHighLiteral(const Text: string): Boolean;
var
  Toks: TRawToks;
  I: Integer;
begin
  Result := False;
  if not HasHighBytes(Text) then Exit;
  Toks := TRawToks.Create(Text);
  try
    for I := 0 to Toks.N - 1 do
      if (Toks.T[I].Kind = tkString) and HasHighBytes(Toks.Txt(I)) then
      begin
        Result := True;
        Exit;
      end;
  finally
    Toks.Free;
  end;
end;

function DfmBeyondAscii(const Dfm: string): Boolean;
var
  I, V: Integer;
begin
  Result := HasHighBytes(Dfm);
  I := 1;
  while not Result and (I <= Length(Dfm)) do
  begin
    if Dfm[I] <> '#' then
    begin
      Inc(I);
      Continue;
    end;
    { #233, #$E9: a character code (only strings have them) }
    Inc(I);
    V := 0;
    if (I <= Length(Dfm)) and (Dfm[I] = '$') then
    begin
      Inc(I);
      while (I <= Length(Dfm)) and (V < $10000) do
      begin
        case Dfm[I] of
          '0'..'9': V := V * 16 + Ord(Dfm[I]) - Ord('0');
          'A'..'F': V := V * 16 + Ord(Dfm[I]) - Ord('A') + 10;
          'a'..'f': V := V * 16 + Ord(Dfm[I]) - Ord('a') + 10;
        else
          Break;
        end;
        Inc(I);
      end;
    end
    else
      while (I <= Length(Dfm)) and (Dfm[I] in ['0'..'9']) and (V < $10000) do
      begin
        V := V * 10 + Ord(Dfm[I]) - Ord('0');
        Inc(I);
      end;
    Result := V >= 128;
  end;
end;

{ ---------------------------------------------------------------- TSdScratchBuild }

constructor TSdScratchBuild.Create;
begin
  inherited Create;
  FScratch := TStringList.Create;
  FReal := TStringList.Create;
end;

destructor TSdScratchBuild.Destroy;
begin
  Finish('');
  FScratch.Free;
  FReal.Free;
  inherited;
end;

procedure TSdScratchBuild.Add(const ScratchName, RealName: string);
begin
  FScratch.Add(ScratchName);
  FReal.Add(RealName);
end;

{ the scratch copy of RealName: in the scratch folder under its own name - files of the same
  name from different folders go to subfolders }
function TSdScratchBuild.NewName(const RealName: string): string;
var
  N: Integer;
begin
  if FDir = '' then
  begin
    { a folder dcc32 can open (it reads the system code page): the short name of a temporary
      folder with other characters - the copies keep that name in the project source and in
      dcc32's messages (RealNames) }
    FDir := IncludeTrailingPathDelimiter(CompilerPath(TempFolder)) + Format('D7Studio-%d\', [GetCurrentProcessId]);
    RemoveTree(FDir);     // left over by an instance that crashed
  end;
  Result := FDir + ExtractFileName(RealName);
  N := 1;
  while FScratch.IndexOf(Result) >= 0 do
  begin
    Inc(N);
    Result := FDir + IntToStr(N) + '\' + ExtractFileName(RealName);
  end;
  ForceDirectories(ExtractFilePath(Result));
end;

procedure TSdScratchBuild.Put(const ScratchName, RealName, Bytes: string);
begin
  WriteFileU(ScratchName, Bytes);
  Add(ScratchName, RealName);
end;

procedure TSdScratchBuild.AddUnit(const RealName, Bytes, Dfm: string);
var
  S: string;
begin
  S := NewName(RealName);
  Put(S, RealName, Bytes);
  if Dfm <> '' then Put(ChangeFileExt(S, '.dfm'), ChangeFileExt(RealName, '.dfm'), Dfm);
end;

procedure TSdScratchBuild.AddFile(const RealName, Bytes: string);
begin
  Put(NewName(RealName), RealName, Bytes);
end;

function TSdScratchBuild.Prepare(Project: TSdProject; const ProjectSource: string): string;
var
  Src, Dirs, D: string;
  I, J: Integer;
  Lost: Boolean;
begin
  Src := ProjectSource;
  { the copies' names as the compiler opens files: dcc32 in the system code page (also in a
    source that goes to it in UTF-8), the UTF-8 compiler in UTF-8 }
  for I := 0 to Project.UnitCount - 1 do
  begin
    J := FReal.IndexOf(Project.Units[I].FileName);
    if J < 0 then Continue;
    if FUtf8Compiler then D := FScratch[J] else D := IdeToSystem(FScratch[J], Lost);
    DprRenameUnit(Src, Project.Units[I].Name, Project.Units[I].Name, D);
  end;
  { include files and resources of the scratch units are found in their real folders }
  Dirs := FolderArg(Project.Dir);
  for J := 0 to FReal.Count - 1 do
  begin
    D := FolderArg(ExtractFilePath(FReal[J]));
    if not PathHasDir(Dirs, D) then Dirs := Dirs + ';' + D;
  end;
  Result := NewName(Project.FileName);
  WriteFileU(Result, Src);
  Add(Result, Project.FileName);
  Project.WriteCfg(ChangeFileExt(Result, '.cfg'), Dirs, FUtf8Compiler);
end;

function TSdScratchBuild.RealNames(const S: string): string;
var
  I: Integer;
begin
  Result := S;
  { every scratch name starts with the scratch folder: a text without it has none (two calls per
    compiler message) }
  if (FDir = '') or (Pos(AnsiUpperCase(ExcludeTrailingPathDelimiter(FDir)), AnsiUpperCase(S)) = 0) then Exit;
  for I := 0 to FScratch.Count - 1 do
    Result := StringReplace(Result, FScratch[I], FReal[I], [rfReplaceAll, rfIgnoreCase]);
end;

procedure TSdScratchBuild.Finish(const UnitDir: string);
var
  I: Integer;
begin
  if UnitDir <> '' then
    for I := 0 to FScratch.Count - 1 do
      if SameText(ExtractFileExt(FScratch[I]), '.pas') then
        DeleteFile(UnitDir + ChangeFileExt(ExtractFileName(FScratch[I]), '.dcu'));
  if FDir <> '' then RemoveTree(FDir);
  FDir := '';
  FScratch.Clear;
  FReal.Clear;
  FUtf8Compiler := False;
end;

{ ---------------------------------------------------------------- TSdIncludeCheck }

constructor TSdIncludeCheck.Create(Project: TSdProject; Utf8: Boolean; Warnings: TStrings);
var
  I: Integer;
begin
  inherited Create;
  FUtf8 := Utf8;
  FWarnings := Warnings;
  FDefines := TStringList.Create;
  FDefines.Text := Project.Conditionals;
  FDirs := TStringList.Create;
  AddPathList(FDirs, Project.UnitSearchPath + ';' + Project.Dir, Project.Dir);
  for I := 0 to FDirs.Count - 1 do FDirs[I] := IncludeTrailingPathDelimiter(FDirs[I]);
  FFiles := TStringList.Create;
  FTexts := TStringList.Create;
end;

destructor TSdIncludeCheck.Destroy;
begin
  FTexts.Free;
  FFiles.Free;
  FDirs.Free;
  FDefines.Free;
  inherited Destroy;
end;

function TSdIncludeCheck.FindInclude(const IncName: string): string;
var
  N: string;
  I: Integer;
begin
  N := IncName;
  if ExtractFileExt(N) = '' then N := N + '.pas';
  if IsAbsolutePath(N) then
  begin
    if FileExistsU(N) then Result := N else Result := '';
    Exit;
  end;
  Result := FUnitDir + N;
  if (FUnitDir <> '') and FileExistsU(Result) then Exit;
  for I := 0 to FDirs.Count - 1 do
  begin
    Result := FDirs[I] + N;
    if FileExistsU(Result) then Exit;
  end;
  Result := '';
end;

{ TPasLexer's OnInclude: the include file's editor text, checked when it is read the first time }
function TSdIncludeCheck.Include(const IncName: string; var Text: string): Boolean;
var
  F, Bytes, Target: string;
  I, K, Line: Integer;
  E: TSdEncoding;
  Wrong: Boolean;
begin
  F := FindInclude(EditorToAnsi(IncName, FEncoding));
  Result := F <> '';
  if not Result then Exit;
  F := ExpandPathU(F);
  I := FFiles.IndexOf(F);
  if I < 0 then
  begin
    Bytes := ReadFileU(F);
    E := FileEncoding(F, Bytes);
    Text := DecodeFile(Bytes, E, False);
    Wrong := SourceNeedsCopy(Text, E, FUtf8);
    if Wrong then
    begin
      { at its first character beyond ASCII; on the first line when it has none (its byte order
        mark is what the compiler misreads) }
      K := 1;
      while (K <= Length(Text)) and (Text[K] < #128) do Inc(K);
      Line := 1;
      if K <= Length(Text) then
        for I := 1 to K - 1 do
          if Text[I] = #10 then Inc(Line);
      if FUtf8 then Target := 'UTF-8' else Target := EncodingShortName(SystemEncoding);
      FWarnings.Add(Format('%s(%d) Warning: Include file in %s, the compiler gets the sources in %s and ' +
        'misreads it - convert it to %3:s (File | Convert to Encoding)', [F, Line, EncodingShortName(E), Target]));
    end
    else if FFindHighLiterals and not FHighLiterals then
      FHighLiterals := HasHighLiteral(Text);
    FFiles.Add(F);
    I := FTexts.Add(Text);
  end;
  Text := FTexts[I];
end;

procedure TSdIncludeCheck.Check(const FileName, Text: string; const E: TSdEncoding);
var
  Lex: TPasLexer;
begin
  { no directive of the text can include a file }
  if (Pos('$I', Text) = 0) and (Pos('$i', Text) = 0) then Exit;
  FUnitDir := ExtractFilePath(FileName);
  FEncoding := E;
  Lex := TPasLexer.Create(Text);
  try
    Lex.AddDefines(FDefines);
    Lex.OnInclude := Include;
    Lex.AutoAsm := True;
    try
      repeat
        Lex.Next;
      until Lex.Tok.Kind = tkEOF;
    except
      { a text the lexer cannot read to its end: the includes found so far are checked }
    end;
  finally
    Lex.Free;
  end;
end;

end.
