# Git

Git for the Delphi 7 IDE, built as an Open Tools API expert (a design-time package). It shows the
changes of the active project's repository and commits them, switches and makes branches, fetches,
pulls and pushes, stashes, and shows the history, diffs and blame. It runs `git.exe` of Git for
Windows and uses only Delphi 7's standard ToolsAPI, so it loads in D7 Studio and in Delphi 7's own
IDE.

## Installing

1. Install Git for Windows (git 2.26 or later; 2.53 was tested).
2. Build and install the package in Delphi 7's IDE or in D7 Studio: open `GitExpert.dpk` (File | Open)
   and choose **Install** in the package editor. The package requires `rtl`, `vcl` and `designide`, and
   names its images' resource script, `GitIcons.rc`; if the IDE reports `GitIcons.res` missing, run
   `brcc32 GitIcons.rc` in the package's folder first.
3. D7 Studio's Setup does this already: it installs `GitExpert.bpl` into Delphi 7's `Projects\Bpl` and lists
   it in `D7Studio.ini`, where D7 Studio loads it.
4. **View | Git** opens the Git view, **View | Git History** the history.

The expert finds `git.exe` on the PATH, else in Git for Windows' folder (its registry key, the
Program Files folders). **Settings...** in the Git view's menu names another one. The settings are
under the IDE's registry key, in `Git`:
- D7 Studio: `HKEY_CURRENT_USER\Software\D7Studio\Git`;
- Delphi 7: `HKEY_CURRENT_USER\Software\Borland\Delphi\7.0\Git`.

## Using it

The views look like the IDE's own (in D7 Studio: its docked and floating panels): the dock's caption
bar, a tool bar on the view's grey ground with flat buttons, the content in flat 1 px frames, and the
status line at the foot of the view. In Delphi 7 each view has a status line of its own. Every button
shows the image of its command - Fetch, Pull, Push, Branch, Stash ... from JetBrains' IntelliJ
icons, as D7 Studio's icons -, greyed as
Visual Studio greys it when the command is not available. Each button's hint names it.

The repository is the one that holds the active project's folder. With no project open, it is the one
that holds the file in the code editor. Every view follows the active project. So do the code
editor's Git commands and View | Git History while no view is shown: the expert looks for the
repository again when the project's folder changes (Delphi 7 hides the views when it opens another
project).

### The Git view

- **The tool bar**: Refresh, Commit, Fetch, Pull, Push, Branch, Stash and History. The current branch
  is on the right, with its distance to its upstream (`main  ↑2  ↓1`). Its hint names the upstream.
- **The message** for the commit. **Commit** (or **Ctrl+Enter**) commits the staged changes. With
  nothing staged, it asks first whether to commit every change of the tracked files; during a merge
  it concludes the merge with the files as they are. **Amend** changes the last commit and fills in
  its message. The commands that change the repository wait while one of them runs or waits; reading
  the status or the history does not stop them.
- **The changes**, in groups: **Merge Conflicts**, **Staged Changes**, **Changes** (tracked files)
  and **Untracked Files**. A file shows its state's letter (`M` modified, `A` added, `D` deleted,
  `R` renamed, `U` untracked, `!` a conflict), its name and its folder. Click a group's header to
  open or close it; the click does not select it.
- **The commands** act on the selected files. A header selected with the keyboard (or the right
  button) stands for every file of its group; **Open** takes the files' rows only.
  - **Double click** or **Enter**: the file's diff.
  - **Space**: stage, or unstage in Staged Changes.
  - **Delete**: discard.
  - The view's menu also has **Open**, **File History**, **Blame**, **Copy Path**, **Settings**,
    **Stop** (a fetch or a push) and **Abort Merge** (or rebase, cherry-pick, revert) while one is
    going on. A pull is not stopped: stopped while it merges, it could leave the index locked and the
    work tree half changed.
- **Discard** undoes the changes of tracked files and deletes untracked files. It asks first: neither
  can be undone. What the IDE has not saved of those files goes too (the question names them). A
  folder that git lists whole holds a repository of its own and is never deleted.
- **Staging a conflict** (a file in Merge Conflicts) marks it resolved: the view asks first.
- **Branch** lists the local branches; the current one is checked, and choosing another switches to
  it. Its submenus:
  - **Remote Branches**: a local branch that tracks the one chosen is made, or used when there is one.
  - **New Branch...**: the name, what the branch starts from, and whether to switch to it.
  - **Delete Branch**: a branch that is not merged is deleted only after a second question.
- **Stash**: **Stash Changes...** (a message; the untracked files too if you like), **Pop Latest
  Stash**, and every stash to **Apply** or **Drop**.
- **Push** pushes the branch to its upstream. A branch without one is pushed to `origin` (else the
  first remote) after a question, and tracks it from then on.
- Without `git.exe`, or when the project's folder is in no repository, the view says so. Its button
  opens the settings or makes a repository there (**Create Repository**). A repository that git
  refuses to open (a work tree of another Windows user's - "dubious ownership" -, a damaged one)
  shows git's message instead, with **Refresh**.

**Files of the editor.** Before a commit, and before a command that rewrites the work tree (pull,
switch, stash, discard, abort), the files of the repository with unsaved changes in the IDE are
listed: save them, go on without saving, or cancel; a file that cannot be saved stops the command.
After such a command, every open module one of whose files changed on disk - a unit, its form - is
read again. One with unsaved changes keeps them, and a message names it; so does a project whose
options (`.dof`) changed, which the IDE keeps in memory.

**Refresh.** The view reads the status when it is shown and after each command. While it is shown it
also reads it when files of the work tree change (Settings: *Read the status again when files of the
work tree change*) and when the IDE becomes the active program again. A refresh that fails keeps
the list and says why in the status line.

### Git History

- The commits of the current branch (**All Branches**: of every branch and tag), newest first: the
  message with the branch and tag names, the author, the date and the commit. The history of one
  file (its renames followed) comes from **File History** or the editor's menu; **Whole Repository**
  goes back.
- Below the list are the chosen commit's message, its id, author, date and branch names, and its
  files.
- **Double click** a commit for its changes (in a file's history: the file's, under the name it had
  in that commit), or a file for its changes in the commit. The menus also have **Copy Commit Id**,
  **Copy Message**, **New Branch Here...** and **Open File**.
- It reads 200 commits at a time; **More ...** at the end reads the next 200. The history is read
  again when HEAD moves while the view shows (with **All Branches**: when a branch moves).

### Git Diff and blame

- **A diff**, in the code editor's font; in D7 Studio a change of it in Editor Options shows at once,
  with the rows and the line-number columns sized again. Each file has its name, notes (new, deleted,
  renamed, binary) and hunks:
  - a hunk's header is on a shade;
  - each line has its old and its new line number;
  - removed lines are on red with `-`, added lines on green with `+` (as the AI harness's approvals).
- **Blame**: each line with the commit, the author and the date at the start of each run of the same
  commit, its line number and its text. Lines that are not committed are in the accent colour.
- An untracked file shows as new lines; a binary one, one over 4 MB and a folder of its own
  repository are named with a note.
- A line wider than the view scrolls sideways: the horizontal range is the longest line's, kept when
  the view is docked or floated (`KitListRange`).
- **Previous Change** and **Next Change** go from hunk to hunk (blame: from run to run).
  **Double click** or **Enter** opens the file in the editor at that line. **Refresh** reads again;
  a diff or blame of the editor's text takes what the editor holds then.

### The code editor's menu

The code editor's local menu ends with **Git**:
- **Diff with HEAD**: the editor's text against the last commit, unsaved changes included;
- **Blame**: blame of the editor's text, where lines not saved yet are "Not committed";
- **History**: the file's history.

## How it works

| Unit | What it holds |
|---|---|
| `GitText`, `GitProcess`, `GitUI`, `GitIde` | The code shared with the AI harness: text, console programs, the views' look, the Open Tools API (`..\kit\*.inc`, `..\kit\README.md`) |
| `GitCore` | Git without the IDE: finding and running `git.exe`, a repository's commands, git's output read (status, branches, log, a commit's files, diffs, blame, stashes) |
| `GitHost` | The expert in the IDE: its settings, the repository of the active project, the commands run in a worker thread, the watching of the work tree, saving and reading again the editor's files, the questions and messages to the user |
| `GitViews` | What the views share: the branch's text, a changed file drawn in a list, the views' registration and status line, the editor's text of a file as git compares it |
| `GitChanges` | The Git view |
| `GitHistory` | The Git History view |
| `GitDiff` | The Git Diff view: diffs and blame |
| `GitBranchDlg`, `GitStashDlg`, `GitSettingsDlg` | New Branch, Stash Changes, Settings |
| `GitWizard` | The expert: the View menu's items, the editor's Git menu (also in a new edit window), the views registered with the IDE's desktop, the IDE's notifier (projects opened, closed, made active) |
| `GitSelfTest` | The self-test in the IDE (on the kit's `TKitSelfTest`) |
| `GitIcons.bmp`, `GitIcons.rc` | The views' images: JetBrains' IntelliJ icons, a row of 16 x 16 cells (`GitIcons.bmp`) and linked as the resource `GITICONS` (`GitExpert.dpk`). `GitViews` names the cells (`gi...`), and each view maps its actions' images to them |

**Running git.** Every command is a task of `GitHost`. Tasks run one at a time in a worker thread, so
the IDE stays usable during a fetch or a long log.
- The command line goes to Windows as UTF-16, so file names outside the IDE's code page reach git as
  they are.
- git never waits for a terminal or an editor: `GIT_TERMINAL_PROMPT=0`, no stdin, `GIT_EDITOR=true`,
  `GIT_MERGE_AUTOEDIT=no`. A password goes through Git's own credential manager.
- Several files go to git through a file (`--pathspec-from-file`), as literal names.
- The user's configuration cannot change what is read back: `core.quotepath=off`, no colours, no
  signatures in the log, fixed diff prefixes. The status is read with `GIT_OPTIONAL_LOCKS=0`, so it
  never writes the index.
- git runs in a job object: **Stop**, a timeout and the IDE closing end every program it started
  (`cmd\git.exe` starts `mingw64\bin\git.exe`; a fetch starts its transport).
- When the expert is unloaded or the IDE closes, a command that only reads, a fetch, a pull and a push
  are stopped; a command that writes the repository (commit, stage, switch ...) is waited for.
- A view's read that waits (a commit's details, a diff) is dropped when the view asks for another one,
  so going down the history quickly reads only what is shown.

**Images.** `KitBitmapIcons` (`..\kit\KitUI.inc`) makes the image lists from the resource: with alpha
where comctl32 6 blends it (D7 Studio), else blended onto the tool bar's ground with a mask (Delphi 7's
IDE runs on comctl32 5). A disabled command's image is greyed as Visual Studio greys it. The images are
made from the IntelliJ icons (`..\..\THIRD-PARTY-NOTICES.md` has their licence).

**Text.** git's names and messages are UTF-8, and the views draw them as Unicode. The lines of a file
in a diff or blame are UTF-8 when they are valid UTF-8, else in the system code page, as Delphi 7
writes its sources. The editor's text goes to git in the encoding of the file on disk, so a diff or
blame of unsaved text compares the right bytes.

**Refresh.** A thread waits on a change notification of the work tree. A burst of changes is read
once, 0.8 s after the last one, and only while a view shows (else when the next one does). A change
seen before a refresh started is in what that refresh reads, so a command's own writes to `.git` do
not read the status twice. A status that did not change leaves the list as it is.

## In Delphi 7's own IDE

The expert works in Delphi 7's own IDE as well as in D7 Studio (checked on 2026-11-24). Builds from
before that day do not work there:
- the expert crashed with an access violation when it looked at the IDE's open files around a commit
  or a command that rewrites the work tree: Delphi 7 gives no editor for some of a module's files;
- after Delphi 7 opened another project, which hides the views, the editor's Git commands and View |
  Git History still worked on the repository of the project before;
- before 2026-11-23 a file open in Delphi 7's editor read as empty (code shared with the AI harness),
  so the diff and the blame of an open file compared an empty text.

If you use an older `GitExpert.bpl` in Delphi 7, build and install it again.

## Limits

- One repository: the active project's. A file of the editor that lies in another repository is not
  handled.
- No line-by-line staging, no merges or rebases started from the views (a pull may merge or rebase,
  as git's configuration says), no tags, no submodules. A conflict is resolved in the editor, then
  staged.
- The diff is unified (one column), not side by side.
- One command runs at a time: a long fetch holds back a diff until it ends.
- In Delphi 7's IDE, which works in the system code page, names that the code page lacks show as `?`
  in the message box, the history and the dialogs. The lists draw them as they are.
