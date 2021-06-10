{ Copyright (C) 2021 by Bill Stewart (bstewart at iname.com)

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
{$H+}

unit wsISPackage;

interface

uses
  Windows;

const
  ERROR_UNKNOWN_PRODUCT   = 1605;
  ERROR_BAD_CONFIGURATION = 1610;

type
  TInnoSetupPackage = class
  private
    MyIs64Bit, MyIsAdmin:  Boolean;
    MyAppId, MySubKeyName: UnicodeString;
    MyRootKey:             HKEY;
  public
    constructor Create();
    procedure Init(const AppId: UnicodeString; const Is64BitInstallMode, IsAdminInstallMode: Boolean);
    function IsInstalled(): DWORD;
    function Version(): UnicodeString;
    function CompareVersion(const InstallingVersion: UnicodeString): LongInt;
    function Uninstall(): DWORD;
    destructor Destroy(); override;
  end; //class

var
  InnoSetupPackage: TInnoSetupPackage;

implementation

uses
  wsUtilFile,
  wsUtilReg;

// Returns S as a longint; if conversion fails, returns Def
function StrToIntDef(const S: UnicodeString; const Def: LongInt): LongInt;
var
  Code: Word;
begin
  Val(S, result, Code);
  if Code > 0 then
    result := Def;
end;

// Compares two version strings 'a[.b[.c[.d]]]'
// Returns:
// < 0  if V1 < V2
// 0    if V1 = V2
// > 0  if V1 > V2
function CompareVersionStrings(V1, V2: UnicodeString): LongInt;
var
  P, N1, N2: LongInt;
begin
  result := 0;
  while (result = 0) and ((V1 <> '') or (V2 <> '')) do
  begin
    P := Pos('.', V1);
    if P > 0 then
    begin
      N1 := StrToIntDef(Copy(V1, 1, P - 1), 0);
      Delete(V1, 1, P);
    end
    else if V1 <> '' then
    begin
      N1 := StrToIntDef(V1, 0);
      V1 := '';
    end
    else
      N1 := 0;
    P := Pos('.', V2);
    if P > 0 then
    begin
      N2 := StrToIntDef(Copy(V2, 1, P - 1), 0);
      Delete(V2, 1, P);
    end
    else if V2 <> '' then
    begin
      N2 := StrToIntDef(V2, 0);
      V2 := '';
    end
    else
      N2 := 0;
    if N1 < N2 then
      result := -1
    else if N1 > N2 then
      result := 1;
  end;
end;

constructor TInnoSetupPackage.Create();
begin
  MyIs64Bit := false;
  MyIsAdmin := false;
  MyAppId := '';
  MySubKeyName := '';
  MyRootKey := 0;
end;

procedure TInnoSetupPackage.Init(const AppId: UnicodeString; const Is64BitInstallMode, IsAdminInstallMode: Boolean);
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
  MySubKeyName := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + MyAppId + '_is1';
end;

function TInnoSetupPackage.IsInstalled(): DWORD;
begin
  // Must call Init() first
  if MyAppId = '' then
    exit(ERROR_INVALID_PARAMETER)
  else
  begin
    if RegKeyExists(MyRootKey, MySubKeyName) then
      result := 1
    else
      result := 0;
  end;
end;

function TInnoSetupPackage.Version(): UnicodeString;
var
  DisplayVersion: UnicodeString;
begin
  result := '';
  if myAppId <> '' then
  begin
    if RegQueryStringValue(MyRootKey, MySubKeyName, 'DisplayVersion', DisplayVersion) and (DisplayVersion <> '') then
      result := DisplayVersion;
  end;
end;

function TInnoSetupPackage.CompareVersion(const InstallingVersion: UnicodeString): LongInt;
var
  CurrentVersion: UnicodeString;
begin
  result := 0;
  CurrentVersion := Version();
  if (CurrentVersion <> '') and (InstallingVersion <> '') then
    result := CompareVersionStrings(InstallingVersion, CurrentVersion);
end;

function TInnoSetupPackage.Uninstall(): DWORD;
var
  UninstallString, UninstallerFileName: UnicodeString;
  P, ProcessExitCode: DWORD;
begin
  // Must call Init() first
  if MyAppId = '' then
    exit(ERROR_INVALID_PARAMETER);
  // Package not detected
  if IsInstalled() <> 1 then
    exit(ERROR_UNKNOWN_PRODUCT);
  if (not RegQueryStringValue(MyRootKey, MySubKeyName, 'UninstallString', UninstallString)) or (UninstallString = '') then
    exit(ERROR_BAD_CONFIGURATION);
  // Get uninstaller file name
  UninstallerFileName := UninstallString;
  // Remove '"' characters
  P := Pos('"', UninstallerFileName);
  while P > 0 do
  begin
    Delete(UninstallerFileName, P, 1);
    P := Pos('"', UninstallerFileName);
  end;
  if not FileExists(UninstallerFileName) then
    exit(ERROR_BAD_CONFIGURATION);
  // Run uninstaller executable and wait until it closes
  UninstallString := '"' + UninstallerFileName + '" /SILENT /SUPPRESSMSGBOXES /NORESTART';
  result := StartProcess(UninstallString, ProcessExitCode);
  if result = 0 then
  begin
    if ProcessExitCode = 0 then
      // Wait for uninstaller executable to be deleted
      while FileExists(UninstallerFileName) do
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
