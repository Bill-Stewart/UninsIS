{ Copyright (C) 2021 by Bill Stewart (bstewart at iname.com)

  This program is free software: you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free Software
  Foundation, either version 3 of the License, or (at your option) any later
  version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
  details.

  You should have received a copy of the GNU General Public License
  along with this program. If not, see https://www.gnu.org/licenses/.

}

{$MODE OBJFPC}
{$H+}

unit
  wsUtilFile;

interface

function FileExists(const FileName: unicodestring): boolean;

function StartProcess(const CommandLine: unicodestring; var ProcessExitCode: DWORD): DWORD;

implementation

uses
  windows;

const
  INVALID_FILE_ATTRIBUTES = DWORD(-1);

var
  PerformWow64FsRedirection: boolean;
  Wow64FsRedirectionOldValue: pointer;

procedure ToggleWow64FsRedirection();
  begin
  if PerformWow64FsRedirection then
    begin
    if not Assigned(Wow64FsRedirectionOldValue) then
      begin
      if not Wow64DisableWow64FsRedirection(@Wow64FsRedirectionOldValue) then
        Wow64FsRedirectionOldValue := nil;
      end
    else
      begin
      if Wow64RevertWow64FsRedirection(Wow64FsRedirectionOldValue) then
        Wow64FsRedirectionOldValue := nil;
      end;
    end;
  end;

function IsProcessWoW64(): boolean;
  type
    TIsWow64Process = function(hProcess: HANDLE; var Wow64Process: BOOL): BOOL; stdcall;
  var
    Kernel32: HMODULE;
    IsWow64Process: TIsWow64Process;
    ProcessHandle: HANDLE;
    IsWoW64: BOOL;
  begin
  result := false;
  Kernel32 := GetModuleHandle('kernel32');
  IsWow64Process := TIsWow64Process(GetProcAddress(Kernel32, 'IsWow64Process'));
  if Assigned(IsWow64Process) then
    begin
    ProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION,  // DWORD dwDesiredAccess
                                 true,                       // BOOL  bInheritHandle
                                 GetCurrentProcessId());     // DWORD dwProcessId
    if ProcessHandle <> 0 then
      begin
      if IsWow64Process(ProcessHandle, IsWoW64) then
        result := IsWoW64;
      CloseHandle(ProcessHandle);
      end;
    end;
  end;

function FileExists(const FileName: unicodestring): boolean;
  var
    Attrs: DWORD;
  begin
  ToggleWow64FsRedirection();
  Attrs := GetFileAttributesW(pwidechar(FileName));
  ToggleWow64FsRedirection();
  result := (Attrs <> INVALID_FILE_ATTRIBUTES) and
    ((Attrs and FILE_ATTRIBUTE_DIRECTORY) = 0);
  end;

function StartProcess(const CommandLine: unicodestring; var ProcessExitCode: DWORD): DWORD;
  var
    StartInfo: STARTUPINFOW;
    ProcInfo: PROCESS_INFORMATION;
    OK: boolean;
  begin
  result := 0;
  FillChar(StartInfo, SizeOf(StartInfo), 0);
  StartInfo.cb := SizeOf(StartInfo);
  FillChar(ProcInfo, SizeOf(ProcInfo), 0);
  ToggleWow64FsRedirection();
  OK := CreateProcessW(nil,                         // LPCWSTR               lpApplicationName
                       pwidechar(CommandLine),      // LPWSTR                lpCommandLine
                       nil,                         // LPSECURITY_ATTRIBUTES lpProcessAttributes
                       nil,                         // LPSECURITY_ATTRIBUTES lpThreadAttributes
                       true,                        // BOOL                  bInheritHandles
                       CREATE_UNICODE_ENVIRONMENT,  // DWORD                 dwCreationFlags
                       nil,                         // LPVOID                lpEnvironment
                       nil,                         // LPCWSTR               lpCurrentDirectory
                       StartInfo,                   // LPSTARTUPINFOW        lpStartupInfo
                       ProcInfo);                   // LPPROCESS_INFORMATION lpProcessInformation
  ToggleWow64FsRedirection();
  if OK then
    begin
    if WaitForSingleObject(ProcInfo.hProcess, INFINITE) <> WAIT_FAILED then
      begin
      if not GetExitCodeProcess(ProcInfo.hProcess, ProcessExitCode) then
        result := GetLastError();
      end
    else
      result := GetLastError();
    CloseHandle(ProcInfo.hThread);
    CloseHandle(ProcInfo.hProcess);
    end
  else
    result := GetLastError();
  end;

procedure InitializeUnit();
  begin
  PerformWow64FsRedirection := IsProcessWoW64();
  Wow64FsRedirectionOldValue := nil;
  end;

initialization
  InitializeUnit();

end.
