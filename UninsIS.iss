; Copyright (C) 2021 by Bill Stewart (bstewart at iname.com)
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

#define AppGUID "{9F49B8E7-BAB8-40DB-A106-316CCCCE0823}"
#define AppVersion "1.0.0.0"

[Setup]
AppId={{#AppGUID}
AppName=UninsIS
AppVersion={#AppVersion}
UsePreviousAppDir=false
DefaultDirName={autopf}\UninsIS
Uninstallable=true
OutputDir=.
OutputBaseFilename=UninsIS-Setup
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=none
PrivilegesRequiredOverridesAllowed=dialog

[Files]
; For importing DLL functions at setup
Source: "x86\UninsIS.dll"; Flags: dontcopy
; Other files to install on the target system
Source: "x64\UninsIS.dll"; DestDir: "{app}"; Check: Is64BitInstallMode()
Source: "x86\UninsIS.dll"; DestDir: "{app}"; Check: not Is64BitInstallMode()
Source: "README.md";       DestDir: "{app}"

[Code]

// Import IsISPackageInstalled() function from UninsIS.dll at setup time
function DLLIsISPackageInstalled(AppId: string;
  Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD;
  external 'IsISPackageInstalled@files:UninsIS.dll stdcall setuponly';

// Import CompareISPackageVersion() function from UninsIS.dll at setup time
function DLLCompareISPackageVersion(AppId, InstallingVersion: string;
  Is64BitInstallMode, IsAdminInstallMode: DWORD): longint;
  external 'CompareISPackageVersion@files:UninsIS.dll stdcall setuponly';

// Import UninstallISPackage() function from UninsIS.dll at setup time
function DLLUninstallISPackage(AppId: string;
  Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD;
  external 'UninstallISPackage@files:UninsIS.dll stdcall setuponly';


// Wrapper for UninsIS.dll IsISPackageInstalled() function
// Returns true if package is detected as installed, or false otherwise
function IsISPackageInstalled(): boolean;
  begin
  result := DLLIsISPackageInstalled(
    '{#AppGUID}',                     // AppId
    DWORD(Is64BitInstallMode()),      // Is64BitInstallMode
    DWORD(IsAdminInstallMode())       // IsAdminInstallMode
  ) = 1;
  if result then
    Log('UninsIS.dll - Package detected as installed')
  else
    Log('UninsIS.dll - Package not detected as installed');
  end;

// Wrapper for UninsIS.dll CompareISPackageVersion() function
// Returns:
// < 0 if version we are installing is < installed version
// 0   if version we are installing is = installed version
// > 0 if version we are installing is > installed version
function CompareISPackageVersion(): longint;
  begin
  result := DLLCompareISPackageVersion(
    '{#AppGUID}',                        // AppId
    '{#AppVersion}',                     // InstallingVersion
    DWORD(Is64BitInstallMode()),         // Is64BitInstallMode
    DWORD(IsAdminInstallMode())          // IsAdminInstallMode
  );
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
  result := DLLUninstallISPackage(
    '{#AppGUID}',                   // AppId
    DWORD(Is64BitInstallMode()),    // Is64BitInstallMode
    DWORD(IsAdminInstallMode())     // IsAdminInstallMode
  );
  if result = 0 then
    Log('UninsIS.dll - Installed package uninstall completed successfully')
  else
    Log('UninsIS.dll - installed package uninstall did not complete successfully');
  end;


function PrepareToInstall(var NeedsRestart: boolean): string;
  begin
  result := '';
  // If package installed, uninstall it automatically if the version we are
  // installing does not match the installed version; If you want to
  // automatically uninstall only...
  // ...when downgrading: change <> to <
  // ...when upgrading:   change <> to >
  if IsISPackageInstalled() and (CompareISPackageVersion() <> 0) then
    UninstallISPackage();
  end;
