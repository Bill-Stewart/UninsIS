{ Copyright (C) 2021-2025 by Bill Stewart (bstewart at iname.com)

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the Free
  Software Foundation; either version 3 of the License, or (at your option) any
  later version.

  This program is distributed in the hope that it will be useful, but WITHOUT
  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
  details.

  You should have received a copy of the GNU Lesser General Public License
  along with this program. If not, see https://www.gnu.org/licenses/.

}

{$MODE OBJFPC}
{$MODESWITCH UNICODESTRINGS}

unit ISPackage;

interface

uses
  Windows;

const
  ERROR_UNKNOWN_PRODUCT = 1605;
  ERROR_BAD_CONFIGURATION = 1610;

type
  TInnoSetupPackage = class
  private
    MyIs64Bit, MyIsAdmin: Boolean;
    MyAppId, MySubKeyName: string;
    MyUninstallCommand, MyUninstallArgs: string;
    MyRootKey: HKEY;
  public
    constructor Create();
    procedure Init(const AppId: string;
      const Is64BitInstallMode, IsAdminInstallMode: Boolean);
    function IsInstalled(): DWORD;
    function GetVersion(): string;
    function CompareVersion(const InstallingVersion: string): Integer;
    function GetSilentUninstallCommandLine(): string;
    function Uninstall(): DWORD;
    destructor Destroy(); override;
  end;

var
  InnoSetupPackage: TInnoSetupPackage;

implementation

uses
  VersionStrings,   // https://github.com/Bill-Stewart/VersionStrings
  WindowsRegistry,  // https://github.com/Bill-Stewart/WindowsRegistry
  WindowsString,    // https://github.com/Bill-Stewart/WindowsString
  FileUtils;

// Removes leading and trailing spaces from string
function Trim(const S: string): string;
var
  Len, P: Integer;
begin
  Len := Length(S);
  while (Len > 0) and (S[Len] <= ' ') do
    Dec(Len);
  P := 1;
  while (P <= Len) and (S[P] <= ' ') do
    Inc(P);
  result := Copy(S, P, 1 + Len - P);
end;

// Splits a command line string into command name and arguments
procedure SplitCommandLine(CommandLine: string; out CommandName, Args: string);
var
  P1, P2: Integer;
begin
  CommandLine := Trim(CommandLine);
  // Check if command name is quoted
  P1 := Pos('"', CommandLine);
  if P1 > 0 then
  begin
    // Find end quote (if any)
    P2 := Pos('"', CommandLine, P1 + 1);
    if P2 > 0 then
    begin
      // Copy starting after first quote and up to but not including end quote
      CommandName := Trim(Copy(CommandLine, P1 + 1, P2 - P1 - 1));
      // Args start after end quote
      Args := Trim(Copy(CommandLine, P2 + 1, Length(CommandLine) - P2));
    end
    else
    begin
      // No end quote found; copy rest of string after starting quote
      CommandName := Trim(Copy(CommandLine, P1 + 1, Length(CommandLine) - P1));
      Args := '';
    end;
  end
  else
  begin
    // Command name not quoted; check for space (i.e., args specified)
    P2 := Pos(' ', CommandLine);
    if P2 > 0 then
    begin
      // Copy from start up to but not including space
      CommandName := Trim(Copy(CommandLine, 1, P2 - P1 - 1));
      // Args start after space
      Args := Trim(Copy(CommandLine, P2 + 1, Length(CommandLine) - P2));
    end
    else
    begin
      // No space found; command name is command line
      CommandName := CommandLine;
      Args := '';
    end;
  end;
end;

constructor TInnoSetupPackage.Create();
begin
  MyIs64Bit := false;
  MyIsAdmin := false;
  MyAppId := '';
  MySubKeyName := '';
  MyUninstallCommand := '';
  MyUninstallArgs := '';
  MyRootKey := 0;
end;

procedure TInnoSetupPackage.Init(const AppId: string;
  const Is64BitInstallMode, IsAdminInstallMode: Boolean);
begin
  if AppId = '' then
    exit();
  MyAppId := AppId;
  MyIs64Bit := Is64BitInstallMode;
  MyIsAdmin := IsAdminInstallMode;
  if MyIs64Bit then
  begin
    if MyIsAdmin then
      MyRootKey := HKEY_LOCAL_MACHINE_64
    else
      MyRootKey := HKEY_CURRENT_USER_64;
  end
  else
  begin
    if MyIsAdmin then
      MyRootKey := HKEY_LOCAL_MACHINE_32
    else
      MyRootKey := HKEY_CURRENT_USER_32;
  end;
  MySubKeyName := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' +
    MyAppId + '_is1';
end;

function TInnoSetupPackage.IsInstalled(): DWORD;
begin
  // Must call Init() first
  if MyAppId = '' then
    exit(ERROR_INVALID_PARAMETER)
  else
  begin
    if RegKeyExists('', MyRootKey, MySubKeyName) = 0 then
      result := 1
    else
      result := 0;
  end;
end;

function TInnoSetupPackage.GetVersion(): string;
var
  DisplayVersion: string;
begin
  result := '';
  if myAppId <> '' then
  begin
    if RegGetStringValue('', MyRootKey, MySubKeyName, 'DisplayVersion',
      DisplayVersion) = 0 then
      result := DisplayVersion;
  end;
end;

function TInnoSetupPackage.CompareVersion(const InstallingVersion: string): Integer;
var
  CurrentVersion: string;
begin
  result := 0;
  CurrentVersion := GetVersion();
  if (CurrentVersion <> '') and (InstallingVersion <> '') then
    result := CompareVersionStrings(InstallingVersion, CurrentVersion);
end;

function TInnoSetupPackage.GetSilentUninstallCommandLine(): string;
const
  // Inno Setup command-line parameters required for silent uninstall
  SilentArgs: array[0..2] of string = (
    '/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART'
  );
var
  UninstallString, CommandName, Args: string;
  I: Integer;
begin
  result := '';
  // Must call Init() first
  if MyAppId = '' then
    exit;
  // Uninstall command not cached yet
  if MyUninstallCommand = '' then
  begin
    if RegGetStringValue('', MyRootKey, MySubKeyName, 'UninstallString',
      UninstallString) <> 0 then
      exit;
    if UninstallString = '' then
      exit;
    // Split into command name and args
    SplitCommandLine(UninstallString, CommandName, Args);
    if CommandName = '' then
      exit;
    MyUninstallCommand := CommandName;
    MyUninstallArgs := '';
    // Add silent parameters if not present in UninstallString
    for I := 0 to Length(SilentArgs) - 1 do
    begin
      if Pos(UppercaseString(SilentArgs[I]), UppercaseString(Args)) = 0 then
      begin
        if MyUninstallArgs = '' then
          MyUninstallArgs := SilentArgs[I]
        else
          MyUninstallArgs := MyUninstallArgs + ' ' + SilentArgs[I];
      end;
    end;
    // Append remainder of arguments, if any
    if Args <> '' then
      MyUninstallArgs := MyUninstallArgs + ' ' + Args;
  end;
  result := '"' + MyUninstallCommand + '" ' + MyUninstallArgs;
end;

function TInnoSetupPackage.Uninstall(): DWORD;
var
  UninstallCommandLine: string;
  ProcessExitCode: DWORD;
begin
  // Must call Init() first
  if MyAppId = '' then
    exit(ERROR_INVALID_PARAMETER);
  // Package not detected
  if IsInstalled() <> 1 then
    exit(ERROR_UNKNOWN_PRODUCT);
  UninstallCommandLine := GetSilentUninstallCommandLine();
  if (UninstallCommandLine = '') or (not FileExists(MyUninstallCommand)) then
    exit(ERROR_BAD_CONFIGURATION);
  result := StartProcess(UninstallCommandLine, ProcessExitCode);
  if result = 0 then
  begin
    if ProcessExitCode = 0 then
      // Wait for uninstaller executable to be deleted
      while FileExists(MyUninstallCommand) do
        Sleep(100);
    result := ProcessExitCode;
  end;
end;

destructor TInnoSetupPackage.Destroy();
begin
end;

initialization
  begin
    InnoSetupPackage := TInnoSetupPackage.Create();
  end;

finalization
  begin
    InnoSetupPackage.Destroy();
  end;

end.
