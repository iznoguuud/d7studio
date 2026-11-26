{**********************************************************}
{                                                          }
{     D7 Studio                                            }
{                                                          }
{     Copyright (c) 2026 iznoguuud                         }
{     Licensed under the MIT License: see LICENSE.txt      }
{                                                          }
{**********************************************************}

unit SdOtaFileSystems;

{ D7 Studio - an expert's file system (IOTAFileSystem, IOTAModuleServices.AddFileSystem) as the
  file system of a page (SdPageFileSystem): the calls Delphi 7's editor buffer makes.

  * Read: GetFileStream(Name, fmOpenRead or fmShareDenyNone); the bytes, the age the stream's
    modify time (IStreamModifyTime, 0 without). Read-only, the file's age and whether it is there:
    IsReadonly, FileAge, FileExists.
  * Write (Delphi's Editors.WriteEditorStream, in its order): GetTempFileName, GetBackupFileName;
    IsReadonly of the file, then of the backup's name - asked also when no backup is kept, as Delphi
    7 does (measured) -: a read-only file, or the backup when one is kept, raises "'x' is a read-only
    file"; the bytes into GetFileStream(temporary name, fmCreate), the temporary file deleted again
    when that fails; then the backup deleted and the file renamed to it (with a backup), else the
    file deleted; the temporary file renamed to the file. A rename only when its file is there; a
    rename that fails raises "Unable to rename 'x' to 'y'".
  * An exception of the expert's reaches the caller (the page shows it). }

interface

uses
  SysUtils, Classes, ActiveX, ToolsAPI, SdPageFileSystem;

type
  TSdOtaPageFileSystem = class(TSdPageFileSystem)
  private
    FFS: IOTAFileSystem;
  public
    constructor Create(const AFS: IOTAFileSystem);
    procedure Read(const FileName: string; out Bytes: string; out Age: Integer); override;
    procedure Write(const FileName, Bytes: string; Backup: Boolean); override;
    function FileAge(const FileName: string): Integer; override;
    function FileExists(const FileName: string): Boolean; override;
    function IsReadOnly(const FileName: string): Boolean; override;
    function IsFileBased: Boolean; override;
  end;

const
  SReadOnlyFile = '''%s'' is a read-only file';
  SCannotRename = 'Unable to rename ''%s'' to ''%s''';
  SNoFileStream = 'The file system ''%s'' gave no stream for ''%s''';

implementation

uses
  IStreams;

constructor TSdOtaPageFileSystem.Create(const AFS: IOTAFileSystem);
begin
  inherited Create;
  FFS := AFS;
end;

procedure TSdOtaPageFileSystem.Read(const FileName: string; out Bytes: string; out Age: Integer);
var
  S: IStream;
  V: TVirtualStream;
  N: Integer;
begin
  Bytes := '';
  Age := 0;
  S := FFS.GetFileStream(FileName, fmOpenRead or fmShareDenyNone);
  if S = nil then raise Exception.CreateFmt(SNoFileStream, [FFS.GetIDString, FileName]);
  V := TVirtualStream.Create(S);
  try
    Age := V.GetModifyTime;
    N := V.Size;
    if N > 0 then
    begin
      V.Position := 0;
      SetLength(Bytes, N);
      SetLength(Bytes, V.Read(Bytes[1], N));
    end;
  finally
    V.Free;
  end;
end;

procedure TSdOtaPageFileSystem.Write(const FileName, Bytes: string; Backup: Boolean);
var
  Temp, Bak: string;
  S: IStream;
  V: TVirtualStream;

  procedure Rename(const Src, Dest: string);
  begin
    if FFS.FileExists(Src) and not FFS.RenameFile(Src, Dest) then
      raise Exception.CreateFmt(SCannotRename, [Src, Dest]);
  end;

begin
  Temp := FFS.GetTempFileName(FileName);
  Bak := FFS.GetBackupFileName(FileName);
  if FFS.IsReadonly(FileName) then raise Exception.CreateFmt(SReadOnlyFile, [FileName]);
  if FFS.IsReadonly(Bak) and Backup then raise Exception.CreateFmt(SReadOnlyFile, [Bak]);
  try
    S := FFS.GetFileStream(Temp, fmCreate);
    if S = nil then raise Exception.CreateFmt(SNoFileStream, [FFS.GetIDString, Temp]);
    V := TVirtualStream.Create(S);
    try
      if Bytes <> '' then V.WriteBuffer(Bytes[1], Length(Bytes));
    finally
      V.Free;
    end;
    S := nil;                        // the stream released: the file system has the bytes
  except
    FFS.DeleteFile(Temp);
    raise;
  end;
  if Backup then
  begin
    FFS.DeleteFile(Bak);
    Rename(FileName, Bak);
  end
  else
    FFS.DeleteFile(FileName);
  Rename(Temp, FileName);
end;

function TSdOtaPageFileSystem.FileAge(const FileName: string): Integer;
begin
  Result := FFS.FileAge(FileName);
end;

function TSdOtaPageFileSystem.FileExists(const FileName: string): Boolean;
begin
  Result := FFS.FileExists(FileName);
end;

function TSdOtaPageFileSystem.IsReadOnly(const FileName: string): Boolean;
begin
  Result := FFS.IsReadonly(FileName);
end;

function TSdOtaPageFileSystem.IsFileBased: Boolean;
begin
  Result := FFS.IsFileBased;
end;

end.
