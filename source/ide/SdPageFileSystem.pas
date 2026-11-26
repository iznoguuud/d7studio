{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdPageFileSystem;

{ D7 Studio - a page's file read and written through a file system other than the disk: an
  expert's IOTAFileSystem (the Open Tools API). A page keeps the file system's ID
  (TEditorPage.FileSystem); for each read, write or check an object of the file system is made
  (PageFileSystemOf) and freed again, so that nothing of an expert's is kept past the call. }

interface

type
  TSdPageFileSystem = class
  public
    { the file's bytes and its age (the stream's modify time, 0 without one); an error raises }
    procedure Read(const FileName: string; out Bytes: string; out Age: Integer); virtual; abstract;
    { the bytes written as Delphi 7 writes a buffer through a file system - a temporary file, the
      backup kept (Backup), the file replaced by the temporary one; an error raises with
      Delphi's message }
    procedure Write(const FileName, Bytes: string; Backup: Boolean); virtual; abstract;
    function FileAge(const FileName: string): Integer; virtual; abstract;
    function FileExists(const FileName: string): Boolean; virtual; abstract;
    function IsReadOnly(const FileName: string): Boolean; virtual; abstract;
    { the files are files of a disk: form files are converted between binary and text }
    function IsFileBased: Boolean; virtual; abstract;
  end;

var
  { the file system of an ID - a new object, the caller frees it; nil: none of that ID }
  PageFileSystemOf: function(const ID: string): TSdPageFileSystem = nil;

{ PageFileSystemOf's file system, or an exception with Delphi's message when there is none }
function NeedPageFileSystem(const ID: string): TSdPageFileSystem;

const
  SUnknownFileSystem = 'Unable to locate file system, ''%s''';

implementation

uses
  SysUtils;

function NeedPageFileSystem(const ID: string): TSdPageFileSystem;
begin
  Result := nil;
  if Assigned(PageFileSystemOf) then Result := PageFileSystemOf(ID);
  if Result = nil then raise Exception.CreateFmt(SUnknownFileSystem, [ID]);
end;

end.
