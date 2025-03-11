{ Copyright (C) 2021-2025 by Bill Stewart (bstewart at iname.com)

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
{$MODESWITCH UNICODESTRINGS}

unit FileUtils;

interface

function FileExists(const FileName: string): Boolean;

function StartProcess(const CommandLine: string; var ProcessExitCode: DWORD): DWORD;

implementation

uses
  Windows;

const
  INVALID_FILE_ATTRIBUTES = DWORD(-1);

var
  PerformWow64FsRedirection: Boolean;
  Wow64FsRedirectionOldValue: Pointer;

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

function IsProcessWoW64(): Boolean;
type
  TIsWow64Process = function(hProcess: HANDLE; var Wow64Process: BOOL): BOOL; stdcall;
var
  Kernel32: HMODULE;
  IsWow64Process: TIsWow64Process;
  ProcessHandle: HANDLE;
  IsWoW64: BOOL;
begin
  result := false;
  Kernel32 := GetModuleHandle('kernel32');  // LPCSTR lpModuleName
  IsWow64Process := TIsWow64Process(GetProcAddress(Kernel32,  // HMODULE hModule
    'IsWow64Process'));                                       // LPCSTR  lpProcName
  if Assigned(IsWow64Process) then
  begin
    ProcessHandle := OpenProcess(PROCESS_QUERY_INFORMATION,  // DWORD dwDesiredAccess
      true,                                                  // BOOL  bInheritHandle
      GetCurrentProcessId());                                // DWORD dwProcessId
    if ProcessHandle <> 0 then
    begin
      if IsWow64Process(ProcessHandle,  // HANDLE hProcess
        IsWoW64) then                   // PBOOL  Wow64Process
        result := IsWoW64;
      CloseHandle(ProcessHandle);  // HANDLE hObject
    end;
  end;
end;

function FileExists(const FileName: string): Boolean;
var
  Attrs: DWORD;
begin
  ToggleWow64FsRedirection();
  Attrs := GetFileAttributesW(PChar(FileName));  // LPCWSTR lpFileName
  ToggleWow64FsRedirection();
  result := (Attrs <> INVALID_FILE_ATTRIBUTES) and ((Attrs and FILE_ATTRIBUTE_DIRECTORY) = 0);
end;

function StartProcess(const CommandLine: string; var ProcessExitCode: DWORD): DWORD;
var
  StartInfo: STARTUPINFOW;
  ProcInfo: PROCESS_INFORMATION;
  OK: Boolean;
begin
  result := 0;
  FillChar(StartInfo, SizeOf(StartInfo), 0);
  StartInfo.cb := SizeOf(StartInfo);
  FillChar(ProcInfo, SizeOf(ProcInfo), 0);
  ToggleWow64FsRedirection();
  OK := CreateProcessW(nil,      // LPCWSTR               lpApplicationName
    PChar(CommandLine),          // LPWSTR                lpCommandLine
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
    if WaitForSingleObject(ProcInfo.hProcess,  // HANDLE hHandle
      INFINITE) <> WAIT_FAILED then            // DWORD  dwMilliseconds
    begin
      if not GetExitCodeProcess(ProcInfo.hProcess,  // HANDLE  hprocess
        ProcessExitCode) then                       // LPDWORD lpexitCode
        result := GetLastError();
    end
    else
      result := GetLastError();
    CloseHandle(ProcInfo.hThread);   // HANDLE hObject
    CloseHandle(ProcInfo.hProcess);  // HANDLE hObject
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
