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
{$R *.res}

library UninsIS;

uses
  VersionStrings,  // https://github.com/Bill-Stewart/VersionStrings
  ISPackage;

type
  int = Integer;
  TStringMethod = function(): string of object;

// Copies Source to Dest.
procedure CopyString(const Source: string; Dest: PChar);
var
  NumChars: DWORD;
begin
  NumChars := Length(Source);
  Move(Source[1], Dest^, NumChars * SizeOf(Char));
  Dest[NumChars] := #0;
end;

// First parameter is address of string function you want to call. Returns
// number of characters needed for output buffer, not including the terminating
// null character.
function GetString(var StringMethod: TStringMethod; Buffer: PChar; const NumChars: DWORD): DWORD;
var
  OutStr: string;
begin
  OutStr := StringMethod();
  if (Length(OutStr) > 0) and Assigned(Buffer) and (NumChars >= Length(OutStr)) then
    CopyString(OutStr, Buffer);
  result := Length(OutStr);
end;

function IsISPackageInstalled(AppId: PChar; Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD; stdcall;
begin
  InnoSetupPackage.Init(AppId, Is64BitInstallMode <> 0, IsAdminInstallMode <> 0);
  result := InnoSetupPackage.IsInstalled();
end;

function GetISPackageVersion(AppId, Version: PChar; NumChars, Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD; stdcall;
var
  StringMethod: TStringMethod;
begin
  InnoSetupPackage.Init(AppId, Is64BitInstallMode <> 0, IsAdminInstallMode <> 0);
  StringMethod := @InnoSetupPackage.GetVersion;
  result := GetString(StringMethod, Version, NumChars);
end;

function GetISPackageUninstallString(AppId, UninstallString: PChar; NumChars, Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD; stdcall;
var
  StringMethod: TStringMethod;
begin
  InnoSetupPackage.Init(AppId, Is64BitInstallMode <> 0, IsAdminInstallMode <> 0);
  StringMethod := @InnoSetupPackage.GetSilentUninstallCommandLine;
  result := GetString(StringMethod, UninstallString, NumChars);
end;

function CompareISPackageVersion(AppId, InstallingVersion: PChar; Is64BitInstallMode, IsAdminInstallMode: DWORD): int; stdcall;
begin
  InnoSetupPackage.Init(AppId, Is64BitInstallMode <> 0, IsAdminInstallMode <> 0);
  result := InnoSetupPackage.CompareVersion(InstallingVersion);
end;

function TestVersionString(Version: PChar): DWORD; stdcall;
begin
  if VersionStrings.TestVersionString(string(Version)) then
    result := 1
  else
    result := 0;
end;

function CompareVersionStrings(Version1, Version2: PChar): int; stdcall;
begin
  result := VersionStrings.CompareVersionStrings(string(Version1), string(Version2));
end;

function UninstallISPackage(AppId: PChar; Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD; stdcall;
begin
  InnoSetupPackage.Init(AppId, Is64BitInstallMode <> 0, IsAdminInstallMode <> 0);
  result := InnoSetupPackage.Uninstall();
end;

exports
  IsISPackageInstalled,
  GetISPackageVersion,
  GetISPackageUninstallString,
  TestVersionString,
  CompareVersionStrings,
  CompareISPackageVersion,
  UninstallISPackage;

end.
