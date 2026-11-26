{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

program D7Studio;

{ D7 Studio - an IDE for Delphi 7 projects.
  D7Studio.exe [project.dpr | file.pas ...]

  The project opens in Delphi 7 as it is: D7Studio.dof holds the options (run-time packages,
  search path, output folders ..\bin and ..\dcu) and every unit is listed below with its file,
  so the Project Manager shows them; a new unit goes into the uses clause here as well.

  ShareMem comes first, before any unit allocates memory: the whole IDE - the run-time packages
  and every design package with it - allocates from borlndmm.dll, as Delphi 7's IDE does, so that
  an expert DLL of Delphi 1-3 built with ShareMem shares its strings with it (SdOtaLegacy).
  borlndmm.dll is Delphi 7's, found through the PATH as its run-time packages.

  The resources are two files. D7Studio.res is the project's own: the program icon MAINICON and
  the version information, which Project | Options of the IDE (Delphi 7, D7 Studio) writes - the
  Version Info page, and its build number at each compile (Auto-increment build number). It is
  linked by its name, not as *.res: D7 Studio puts a manifest of its own into a project's *.res,
  and the program's manifest is D7StudioRes.res's. D7StudioRes.res is made from D7StudioRes.rc
  (the manifest, a new project's icon, the icon set, the start-up screen's picture): the $R names
  both, so the IDE compiles the script with brcc32; dcc32 reads only the .res, so a
  command-line build runs brcc32 itself. }

{$R D7Studio.res}
{$R 'D7StudioRes.res' 'D7StudioRes.rc'}

uses
  ShareMem,
  Windows,
  SysUtils,
  Classes,
  Forms,
  SdMain in 'ide\SdMain.pas' {AppBuilder},
  SdCheckImages in 'ide\SdCheckImages.pas',
  SdUI in 'ide\SdUI.pas',
  SdHints in 'ide\SdHints.pas',
  SdIcons in 'ide\SdIcons.pas',
  SdDelphiDir in 'ide\SdDelphiDir.pas',
  SdSettings in 'ide\SdSettings.pas',
  SdEnvOptions in 'ide\SdEnvOptions.pas',
  SdVarLists in 'ide\SdVarLists.pas',
  SdCrashLog in 'ide\SdCrashLog.pas',
  SdDesignHost in 'designer\SdDesignHost.pas',
  SdFormDesigner in 'designer\SdFormDesigner.pas',
  SdFormPositioner in 'designer\SdFormPositioner.pas',
  SdDesignMenus in 'designer\SdDesignMenus.pas',
  SdCIEngine in 'codeinsight\SdCIEngine.pas',
  SdExplorerEdit in 'codeinsight\SdExplorerEdit.pas',
  SdCodeInsight in 'codeinsight\SdCodeInsight.pas',
  SdFormSrc in 'codeinsight\SdFormSrc.pas',
  SdPasLex in 'codeinsight\SdPasLex.pas',
  SdPasBlocks in 'codeinsight\SdPasBlocks.pas',
  SdPasParser in 'codeinsight\SdPasParser.pas',
  SdPasCheck in 'codeinsight\SdPasCheck.pas',
  SdFormatter in 'codeinsight\SdFormatter.pas',
  SdDbgDisasm in 'debugger\SdDbgDisasm.pas',
  SdDbgEngine in 'debugger\SdDbgEngine.pas',
  SdDbgEval in 'debugger\SdDbgEval.pas',
  SdDbgTD32 in 'debugger\SdDbgTD32.pas',
  SdDesignEnv in 'designer\SdDesignEnv.pas',
  SdObjInsp in 'designer\SdObjInsp.pas' {ObjectInspector},
  SdOsFrame in 'designer\SdOsFrame.pas',
  SdCompletion in 'editor\SdCompletion.pas',
  SdSciDefs in 'editor\SdSciDefs.pas',
  SdSciEdit in 'editor\SdSciEdit.pas',
  SdSciScroll in 'editor\SdSciScroll.pas',
  SdEncoding in 'editor\SdEncoding.pas',
  SdSciLexDefs in 'editor\SdSciLexDefs.pas',
  SdCompBar in 'ide\SdCompBar.pas' {ComponentBar},
  SdTabStrip in 'ide\SdTabStrip.pas',
  SdNavHistory in 'ide\SdNavHistory.pas',
  SdEditorThemes in 'editor\SdEditorThemes.pas',
  SdEditorOptions in 'editor\SdEditorOptions.pas',
  SdKeymaps in 'editor\SdKeymaps.pas',
  SdDebuggerOptions in 'ide\SdDebuggerOptions.pas',
  SdFormatterOptions in 'ide\SdFormatterOptions.pas',
  SdCodeTemplates in 'ide\SdCodeTemplates.pas',
  SdEditorOptionsFrame in 'ide\SdEditorOptionsFrame.pas' {EditorOptionsFrame: TFrame},
  SdDebuggerOptionsFrame in 'ide\SdDebuggerOptionsFrame.pas' {DebuggerOptionsFrame: TFrame},
  SdFormatterFrame in 'ide\SdFormatterFrame.pas' {FormatterFrame: TFrame},
  SdFormatterPreview in 'ide\SdFormatterPreview.pas' {FormatterPreview},
  SdOptionsDlg in 'ide\SdOptionsDlg.pas' {OptionsDlg},
  SdCodeTemplatesDlg in 'ide\SdCodeTemplatesDlg.pas' {CodeTemplatesDlg},
  SdAddCodeTemplateDlg in 'ide\SdAddCodeTemplateDlg.pas' {AddCodeTemplateDlg},
  SdExceptRangeDlg in 'ide\SdExceptRangeDlg.pas' {ExceptRangeDlg},
  SdCustomizeDlg in 'ide\SdCustomizeDlg.pas' {CustomizeDlg},
  SdAddTodoDlg in 'ide\SdAddTodoDlg.pas' {AddTodoDlg},
  SdTodo in 'ide\SdTodo.pas',
  SdTodoFilterDlg in 'ide\SdTodoFilterDlg.pas' {TodoFilterDlg},
  SdTableOptionsDlg in 'ide\SdTableOptionsDlg.pas' {TableOptionsDlg},
  SdAddModuleDlg in 'ide\SdAddModuleDlg.pas' {AddModuleDlg},
  SdAttachDlg in 'ide\SdAttachDlg.pas' {AttachDlg},
  SdProjectGroup in 'ide\SdProjectGroup.pas',
  SdMsgInfo in 'ide\SdMsgInfo.pas',
  SdBaseFrame in 'ide\SdBaseFrame.pas' {SdFrame: TFrame},
  SdSplitViewFrame in 'ide\SdSplitViewFrame.pas' {SdSplitView: TFrame},
  SdDiagram in 'ide\SdDiagram.pas',
  SdTextDiff in 'ide\SdTextDiff.pas',
  SdHistory in 'ide\SdHistory.pas',
  SdHistoryFrame in 'ide\SdHistoryFrame.pas' {SdHistoryView: TFrame},
  SdBrowserFrame in 'ide\SdBrowserFrame.pas' {SdBrowser: TFrame},
  SdTypeLib in 'ide\SdTypeLib.pas',
  SdImportTypeLibDlg in 'ide\SdImportTypeLibDlg.pas' {ImportTypeLibDlg},
  SdTypeLibViewFrame in 'ide\SdTypeLibViewFrame.pas' {SdTypeLibView: TFrame},
  SdRepository in 'ide\SdRepository.pas',
  SdAddRepositoryDlg in 'ide\SdAddRepositoryDlg.pas' {AddRepositoryDlg},
  SdRepositoryDlg in 'ide\SdRepositoryDlg.pas' {RepositoryDlg},
  SdCompTemplateDlg in 'ide\SdCompTemplateDlg.pas' {CompTemplateDlg},
  SdDockFloat in 'ide\SdDockFloat.pas' {DockFloatForm},
  SdDock in 'ide\SdDock.pas',
  SdFileNames in 'ide\SdFileNames.pas',
  SdDebugUI in 'ide\SdDebugUI.pas',
  SdColumnTreeFrame in 'ide\SdColumnTreeFrame.pas' {SdColumnTree: TFrame},
  SdDebugViews in 'ide\SdDebugViews.pas',
  SdCpuView in 'ide\SdCpuView.pas' {CpuView},
  SdDebugInspector in 'ide\SdDebugInspector.pas' {InspectorView},
  SdWatchViewFrame in 'ide\SdWatchViewFrame.pas' {SdWatchView: TFrame},
  SdDesignWin in 'ide\SdDesignWin.pas',
  SdDialogs in 'ide\SdDialogs.pas',
  SdAboutDlg in 'ide\SdAboutDlg.pas' {AboutDlg},
  SdSplash in 'ide\SdSplash.pas' {SplashForm},
  SdCompileDlg in 'ide\SdCompileDlg.pas' {CompileDlg},
  SdEnvOptionsFrame in 'ide\SdEnvOptionsFrame.pas' {EnvOptionsFrame: TFrame},
  SdEvalDlg in 'ide\SdEvalDlg.pas' {EvalDlg},
  SdFindDlg in 'ide\SdFindDlg.pas' {FindDlg},
  SdFindInFilesDlg in 'ide\SdFindInFilesDlg.pas' {FindInFilesDlg},
  SdInputDlg in 'ide\SdInputDlg.pas' {InputDlg},
  SdListDlg in 'ide\SdListDlg.pas' {ListDlg},
  SdInstallCompDlg in 'ide\SdInstallCompDlg.pas' {InstallCompDlg},
  SdAlignDlg in 'ide\SdAlignDlg.pas' {AlignDlg},
  SdSizeDlg in 'ide\SdSizeDlg.pas' {SizeDlg},
  SdScaleDlg in 'ide\SdScaleDlg.pas' {ScaleDlg},
  SdTabOrderDlg in 'ide\SdTabOrderDlg.pas' {TabOrderDlg},
  SdWindowListDlg in 'ide\SdWindowListDlg.pas' {WindowListDlg},
  SdDesktopDlg in 'ide\SdDesktopDlg.pas' {DesktopDlg},
  SdDesktopDeleteDlg in 'ide\SdDesktopDeleteDlg.pas' {DesktopDeleteDlg},
  SdDesktopsDlg in 'ide\SdDesktopsDlg.pas' {DesktopsDlg},
  SdTransferDlg in 'ide\SdTransferDlg.pas' {TransferDlg},
  SdTransEditDlg in 'ide\SdTransEditDlg.pas' {TransEditDlg},
  SdFindErrorDlg in 'ide\SdFindErrorDlg.pas' {FindErrorDlg},
  SdBrowseSymbolDlg in 'ide\SdBrowseSymbolDlg.pas' {BrowseSymbolDlg},
  SdCompInfoDlg in 'ide\SdCompInfoDlg.pas' {CompInfoDlg},
  SdNewCompDlg in 'ide\SdNewCompDlg.pas' {NewCompDlg},
  SdPackageAddDlg in 'ide\SdPackageAddDlg.pas' {PackageAddDlg},
  SdPackageViewFrame in 'ide\SdPackageViewFrame.pas' {SdPackageView: TFrame},
  SdResImage in 'ide\SdResImage.pas',
  SdResources in 'ide\SdResources.pas',
  SdResourceViewFrame in 'ide\SdResourceViewFrame.pas' {SdResourceView: TFrame},
  SdResPage in 'ide\SdResPage.pas',
  SdImageEditFrame in 'ide\SdImageEditFrame.pas' {ImageEditFrame: TFrame},
  SdNewImageDlg in 'ide\SdNewImageDlg.pas' {NewImageDlg},
  SdStringTableFrame in 'ide\SdStringTableFrame.pas' {StringTableFrame: TFrame},
  SdResTextFrame in 'ide\SdResTextFrame.pas' {ResTextFrame: TFrame},
  SdResPropsDlg in 'ide\SdResPropsDlg.pas' {ResPropsDlg},
  SdImageSizeDlg in 'ide\SdImageSizeDlg.pas' {ImageSizeDlg},
  SdImageTextDlg in 'ide\SdImageTextDlg.pas' {ImageTextDlg},
  SdColorEditDlg in 'ide\SdColorEditDlg.pas' {ColorEditDlg},
  SdHexEditFrame in 'ide\SdHexEditFrame.pas' {HexEditFrame: TFrame},
  SdCompListDlg in 'ide\SdCompListDlg.pas' {CompListDlg},
  SdSourceBPDlg in 'ide\SdSourceBPDlg.pas' {SourceBPDlg},
  SdWatchEditDlg in 'ide\SdWatchEditDlg.pas' {WatchEditDlg},
  SdNewItemsDlg in 'ide\SdNewItemsDlg.pas' {NewItemsDlg},
  SdNewThreadDlg in 'ide\SdNewThreadDlg.pas' {NewThreadDlg},
  SdPrintDlg in 'ide\SdPrintDlg.pas' {PrintDlg},
  SdVarEntryDlg in 'ide\SdVarEntryDlg.pas' {VarEntryDlg},
  SdListEditDlg in 'ide\SdListEditDlg.pas' {ListEditDlg},
  SdRunParamsDlg in 'ide\SdRunParamsDlg.pas' {RunParamsDlg},
  SdProjOptionsFrame in 'ide\SdProjOptionsFrame.pas' {ProjOptionsFrame: TFrame},
  SdReplaceDlg in 'ide\SdReplaceDlg.pas' {ReplaceDlg},
  SdDesignUndo in 'ide\SdDesignUndo.pas',
  SdUndo in 'ide\SdUndo.pas',
  SdPageFileSystem in 'ide\SdPageFileSystem.pas',
  SdEditorPage in 'ide\SdEditorPage.pas' {EditorPage: TFrame},
  SdPEHeader in 'ide\SdPEHeader.pas',
  SdProject in 'ide\SdProject.pas',
  SdCodeExplorer in 'ide\SdCodeExplorer.pas' {CodeExplorerView},
  SdObjTreeView in 'ide\SdObjTreeView.pas' {ObjTreeView},
  SdNavBar in 'ide\SdNavBar.pas' {NavigationBar},
  SdPageBar in 'ide\SdPageBar.pas',
  SdZoom in 'ide\SdZoom.pas',
  SdProjectManager in 'ide\SdProjectManager.pas' {ProjectManagerView},
  SdTodoView in 'ide\SdTodoView.pas' {TodoListView},
  SdSearchResults in 'ide\SdSearchResults.pas' {SearchResultsView},
  SdBreakpointsView in 'ide\SdBreakpointsView.pas' {BreakpointsView},
  SdMessageView in 'ide\SdMessageView.pas',
  SdOtaCore in 'ide\SdOtaCore.pas',
  SdOtaEditWindow in 'ide\SdOtaEditWindow.pas' {EditWindow},
  SdOtaModules in 'ide\SdOtaModules.pas',
  SdOtaDebug in 'ide\SdOtaDebug.pas',
  SdOtaDesktop in 'ide\SdOtaDesktop.pas',
  SdOtaPalette in 'ide\SdOtaPalette.pas',
  SdOtaViews in 'ide\SdOtaViews.pas',
  SdOtaToDo in 'ide\SdOtaToDo.pas',
  SdOtaCodeInsight in 'ide\SdOtaCodeInsight.pas',
  SdOtaHighlight in 'ide\SdOtaHighlight.pas',
  SdOtaSpeedSettings in 'ide\SdOtaSpeedSettings.pas',
  SdOtaToolsFilter in 'ide\SdOtaToolsFilter.pas',
  SdOtaRecord in 'ide\SdOtaRecord.pas',
  SdOtaFileSystems in 'ide\SdOtaFileSystems.pas',
  SdOtaLegacyModules in 'ide\SdOtaLegacyModules.pas',
  SdOtaLegacy in 'ide\SdOtaLegacy.pas',
  SdOtaServices in 'ide\SdOtaServices.pas',
  SdHttp in 'ide\SdHttp.pas',
  SdUpdate in 'ide\SdUpdate.pas',
  SdUpdateDlg in 'ide\SdUpdateDlg.pas' {UpdateDlg};

{ The end of the process, without finalization (the design packages are never unloaded) and
  without the unload code of the DLLs that are still loaded. Windows unloads them in the reverse
  order of their initialization, which puts borlndmm.dll before rtl70.bpl here; Borland's
  borlndmm.dll frees all its memory as it is unloaded (the modernizer's keeps it:
  System.KeepMemoryAtUnload), and rtl70.bpl's unload code then reads blocks of it - its list of
  module unload procedures -: an access violation at every exit. }
procedure EndProcess(Code: Cardinal);
begin
  TerminateProcess(GetCurrentProcess, Code);
end;

var
  { the environment block and the current folder D7 Studio was started with, for StartAgain: the
    session changes both (PATH gets Delphi's Bin and Projects\Bpl, the user's overrides of
    Environment Options are applied, the folder is the project's), and a new start must not take
    those for its originals }
  StartEnvironment: WideString;
  StartFolder: WideString;

procedure KeepStartState;
var
  Block, P: PWideChar;
  Len: Integer;
  Dir: array[0..MAX_PATH] of WideChar;
begin
  Block := GetEnvironmentStringsW;
  if Block <> nil then
  try
    { the strings one after the other, each with its #0, the block ending with one more }
    P := Block;
    Len := 0;
    while P^ <> #0 do
    begin
      Inc(Len, lstrlenW(P) + 1);
      Inc(P, lstrlenW(P) + 1);
    end;
    SetString(StartEnvironment, Block, Len + 1);
  finally
    FreeEnvironmentStringsW(Block);
  end;
  if GetCurrentDirectoryW(MAX_PATH, Dir) > 0 then StartFolder := Dir;
end;

{ D7 Studio started again (TMainForm.RestartWanted: a new UI font): its EXE without arguments, in
  the environment and folder it was started with (KeepStartState), so it opens the last project as
  every start does. The settings are saved and the experts shut down; this process ends right
  after, also when the new one could not be started (said in a message box) }
procedure StartAgain;
var
  Exe: array[0..MAX_PATH] of WideChar;
  Cmd: WideString;
  Env, Dir: PWideChar;
  SI: TStartupInfo;
  PI: TProcessInformation;
begin
  if GetModuleFileNameW(0, Exe, MAX_PATH) = 0 then Exit;
  Cmd := '"' + WideString(Exe) + '"';
  Env := nil;
  if StartEnvironment <> '' then Env := PWideChar(StartEnvironment);
  Dir := nil;
  if StartFolder <> '' then Dir := PWideChar(StartFolder);
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  if CreateProcessW(nil, PWideChar(Cmd), nil, nil, False, CREATE_UNICODE_ENVIRONMENT, Env, Dir, SI, PI) then
  begin
    CloseHandle(PI.hThread);
    CloseHandle(PI.hProcess);
  end
  else
    MessageBox(0, PChar('D7 Studio could not start again.'#13#10#13#10 + SysErrorMessage(GetLastError)),
      'D7 Studio', MB_OK or MB_ICONERROR);
end;

procedure StartupError(E: Exception);
begin
  TSplashForm.Finish;
  LogException(E, 'startup', SettingsDir + 'error.log');
  MessageBox(0, PChar('D7 Studio could not start.'#13#10#13#10 + E.ClassName + ': ' + E.Message),
    'D7 Studio', MB_OK or MB_ICONERROR);
end;

{ a file of the command line or the last project, opened once the main window is there: what
  goes wrong is logged and reported, and D7 Studio runs on - a last project that cannot be
  opened is not opened at the next start either }
procedure OpenAtStart(const FileName: string; IsLast: Boolean);
begin
  try
    MainForm.OpenAny(FileName);
  except
    on E: Exception do
    begin
      if IsLast then
        Settings.DeleteKey('Project', 'Last');
      if not(E is EAbort) then
      begin
        LogException(E, 'startup', SettingsDir + 'error.log');
        MessageBox(MainForm.Handle, PChar('D7 Studio could not open ' + FileName + #13#10#13#10 +
          E.ClassName + ': ' + E.Message), 'D7 Studio', MB_OK or MB_ICONERROR);
      end;
    end;
  end;
end;

var
  I: Integer;
  Last, Reason: string;
  Files: TStringList;
begin
  KeepStartState;
  InstallCrashLog;
  try
    { D7 Studio is drawn with the visual styles of Windows: without them it does not start
      (the cloaked test instance leaves without a message) }
    if not UIThemesAvailable(Reason) then
    begin
      if GetEnvironmentVariable('D7S_POS') = '' then
        MessageBox(0, PChar('D7 Studio cannot run on this system.'#13#10#13#10 + Reason), 'D7 Studio',
          MB_OK or MB_ICONERROR);
      EndProcess(2);
    end;
    LoadSettings;
    UIFontOverride := Settings.ReadString('UI', 'FontName', '');
    UIFontSizeOverride := Settings.ReadInteger('UI', 'FontSize', 0);
    UISetDialogBackground(Settings.ReadInteger('UI', 'DialogBackground', 0));
    InitAppearance;
    { every hint in D7 Studio's look, the VCL's too }
    InstallHintWindow;
    Application.Initialize;
    Application.Title := 'D7 Studio';
    { the start-up screen, as Delphi 7's, while the packages load and the main window is made }
    TSplashForm.Start;
    DesignHost.LoadInstalledPackages;
    TSplashForm.Status('Creating the main window...');
    Application.CreateForm(TMainForm, MainForm);
    { Delphi's edit window as experts find it past the Open Tools API, before the first expert is
      loaded (SdOtaEditWindow): the editor's menus move to it }
    CreateEditWindow(MainForm, MainForm.EditorLocalMenu, MainForm.BackMenu, MainForm.ForwardMenu,
      MainForm.TabPopup, DelphiBin);
    { the experts' DLLs once the main window is Application.MainForm, then the IDE experts among
      the packages: they put their menus into the main window as they register (the Open Tools
      API) }
    TSplashForm.Status('Loading experts...');
    { what experts put on the start-up screen, laid out after each (SdSplash) }
    OtaExpertLoaded := SplashExpertsAdded;
    OtaLoadExperts;
    DesignHost.LoadDeferredPackages;
    SplashExpertsAdded;
    OtaExpertLoaded := nil;
    { the experts' windows they made meanwhile: their views placed as the arrangement has them }
    MainForm.ExpertsLoaded;
    { designide's desktop forms hear that the main window was made once the experts are there,
      as in Delphi's start (SdOtaDesktop) }
    DeskMainFormCreated(MainForm);
    { the window first: opening a project may ask questions; it appears laid out and painted,
      in the state it was closed in (maximized: TMainForm.ApplyStartState) }
    MainForm.ApplyStartState;
    UIShowPainted(MainForm);
    TSplashForm.Finish;
    UITestStartShot(MainForm);
    UITestYieldForeground;
    MainForm.ShowFloatingViews; // the floating views' windows after the main window
    DeskMainFormShown(MainForm);
    { the files of the command line, as usable names (SdFileNames: also names outside the code page) }
    Files := TStringList.Create;
    try
      CommandLineFiles(Files);
      for I := Files.Count - 1 downto 0 do
        if IsNoSplashSwitch(Files[I]) then
          Files.Delete(I);
      if Files.Count > 0 then
      begin
        for I := 0 to Files.Count - 1 do
          if FileExistsU(Files[I]) then
            OpenAtStart(ExpandPathU(Files[I]), False);
      end
      else
      begin
        Last := Settings.ReadString('Project', 'Last', '');
        if (Last <> '') and FileExists(Last) and Settings.ReadBool('UI', 'ReopenLast', True) then
          OpenAtStart(Last, True);
      end;
    finally
      Files.Free;
    end;
    { a newer release looked for in the background, when it is due }
    MainForm.CheckForUpdates(False);
  except
    on E: Exception do
    begin
      StartupError(E);
      EndProcess(1);
    end;
  end;
  Application.Run;
  { the experts' wizards are told Destroyed and released, the DLL experts terminated, the experts'
    packages unloaded: the main form, whose destructor would do it, is never freed }
  try
    OtaShutdown;
  except
    on E: Exception do
      OtaError(E, 'shutdown');
  end;
  if MainForm.UpdateSetup <> '' then
  begin
    if not RunUpdateSetup(MainForm.UpdateSetup) then
      MessageBox(0, PChar('The setup of the update could not be started:'#13#10 + MainForm.UpdateSetup +
        #13#10#13#10 + SysErrorMessage(GetLastError)), 'D7 Studio', MB_OK or MB_ICONERROR);
  end
  else if MainForm.RestartWanted then StartAgain;
  EndProcess(0);
end.
