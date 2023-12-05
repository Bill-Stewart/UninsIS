; Copyright (C) 2021-2023 by Bill Stewart (bstewart at iname.com)
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU Lesser General Public License as published by the Free
; Software Foundation; either version 3 of the License, or (at your option) any
; later version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT
; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
; FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
; details.
;
; You should have received a copy of the GNU Lesser General Public License
; along with this program. If not, see https://www.gnu.org/licenses/.

; Sample Inno Setup (https://www.jrsoftware.org/isinfo.php) script
; demonstrating use of UninsIS.dll.

#if Ver < EncodeVer(6,0,0,0)
  #error This script requires Inno Setup 6 or later
#endif

#define AppName "UninsIS-Sample"
#define AppGUID "{9F49B8E7-BAB8-40DB-A106-316CCCCE0823}"
#define AppVersion "1.5.0.0"

[Setup]
AppId={{#AppGUID}
AppName={#AppName}
AppVersion={#AppVersion}
UsePreviousAppDir=false
DefaultDirName={autopf}\{#AppName}
Uninstallable=true
OutputDir=.
OutputBaseFilename={#AppName}
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=none
PrivilegesRequiredOverridesAllowed=dialog

[Files]
; For importing DLL functions at setup
Source: "i386\UninsIS.dll"; DestDir: {app}
Source: "README.md"; DestDir: {app}

[Code]

// Import IsISPackageInstalled() function from UninsIS.dll at setup time
function DLLIsISPackageInstalled(AppId: string; Is64BitInstallMode,
  IsAdminInstallMode: DWORD): DWORD;
  external 'IsISPackageInstalled@files:UninsIS.dll stdcall setuponly';

// Import CompareISPackageVersion() function from UninsIS.dll at setup time
function DLLCompareISPackageVersion(AppId, InstallingVersion: string;
  Is64BitInstallMode, IsAdminInstallMode: DWORD): Integer;
  external 'CompareISPackageVersion@files:UninsIS.dll stdcall setuponly';

// Import GetISPackageVersion() function from UninsIS.dll at setup time
function DLLGetISPackageVersion(AppId, Version: string;
  NumChars, Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD;
  external 'GetISPackageVersion@files:UninsIS.dll stdcall setuponly';

// Import UninstallISPackage() function from UninsIS.dll at setup time
function DLLUninstallISPackage(AppId: string; Is64BitInstallMode,
  IsAdminInstallMode: DWORD): DWORD;
  external 'UninstallISPackage@files:UninsIS.dll stdcall setuponly';

// Wrapper for UninsIS.dll IsISPackageInstalled() function
// Returns true if package is detected as installed, or false otherwise
function IsISPackageInstalled(): Boolean;
begin
  result := DLLIsISPackageInstalled('{#AppGUID}',  // AppId
    DWORD(Is64BitInstallMode()),                   // Is64BitInstallMode
    DWORD(IsAdminInstallMode())) = 1;              // IsAdminInstallMode
  if result then
    Log('UninsIS.dll - Package detected as installed')
  else
    Log('UninsIS.dll - Package not detected as installed');
end;

// Wrapper for UninsIS.dll GetISPackageVersion() function
function GetISPackageVersion(): string;
var
  NumChars: DWORD;
  OutStr: string;
begin
  result := '';
  // First call: Get number of characters needed for version string
  NumChars := DLLGetISPackageVersion('{#AppGUID}',  // AppId
    '',                                             // Version
    0,                                              // NumChars
    DWORD(Is64BitInstallMode()),                    // Is64BitInstallMode
    DWORD(IsAdminInstallMode()));                   // IsAdminInstallMode
  // Allocate string to receive output
  SetLength(OutStr, NumChars);
  // Second call: Get version number string
  if DLLGetISPackageVersion('{#AppGUID}',  // AppID
    OutStr,                                // Version
    NumChars,                              // NumChars
    DWORD(Is64BitInstallMode()),           // Is64BitInstallMode
    DWORD(IsAdminInstallMode())) > 0 then  // IsAdminInstallMode
  begin
    result := OutStr;
  end;
end;

// Wrapper for UninsIS.dll CompareISPackageVersion() function
// Returns:
// < 0 if version we are installing is < installed version
// 0   if version we are installing is = installed version
// > 0 if version we are installing is > installed version
function CompareISPackageVersion(): Integer;
begin
  result := DLLCompareISPackageVersion('{#AppGUID}',  // AppId
    '{#AppVersion}',                                  // InstallingVersion
    DWORD(Is64BitInstallMode()),                      // Is64BitInstallMode
    DWORD(IsAdminInstallMode()));                     // IsAdminInstallMode
  if result < 0 then
    Log('UninsIS.dll - This version {#AppVersion} older than installed version')
  else if result = 0 then
    Log('UninsIS.dll - This version {#AppVersion} same as installed version')
  else
    Log('UninsIS.dll - This version {#AppVersion} newer than installed version');
end;

// Wrapper for UninsIS.dll UninstallISPackage() function
// Returns 0 for success, non-zero for failure
function UninstallISPackage(): DWORD;
begin
  result := DLLUninstallISPackage('{#AppGUID}',  // AppId
    DWORD(Is64BitInstallMode()),                 // Is64BitInstallMode
    DWORD(IsAdminInstallMode()));                // IsAdminInstallMode
  if result = 0 then
    Log('UninsIS.dll - Installed package uninstall completed successfully')
  else
    Log('UninsIS.dll - installed package uninstall did not complete successfully');
end;

function PrepareToInstall(var NeedsRestart: Boolean): string;
var
  Version: string;
begin
  result := '';
  if IsISPackageInstalled() then
  begin
    Version := GetISPackageVersion();
    MsgBox('Package installed; version = ' + Version, mbInformation, MB_OK);
  end;
  // If package installed, uninstall it automatically if the version we are
  // installing does not match the installed version; If you want to
  // automatically uninstall only...
  // ...when downgrading: change <> to <
  // ...when upgrading:   change <> to >
  if IsISPackageInstalled() and (CompareISPackageVersion() <> 0) then
    UninstallISPackage();
end;
