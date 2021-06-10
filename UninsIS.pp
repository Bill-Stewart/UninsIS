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
{$R *.res}

library UninsIS;

uses
  wsISPackage;

function IsISPackageInstalled(AppId: PWideChar; Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD; stdcall;
begin
  InnoSetupPackage.Init(AppId, Is64BitInstallMode <> 0, IsAdminInstallMode <> 0);
  result := InnoSetupPackage.IsInstalled();
end;

function CompareISPackageVersion(AppId, InstallingVersion: PWideChar; Is64BitInstallMode, IsAdminInstallMode: DWORD): LongInt;
stdcall;
begin
  InnoSetupPackage.Init(AppId, Is64BitInstallMode <> 0, IsAdminInstallMode <> 0);
  result := InnoSetupPackage.CompareVersion(InstallingVersion);
end;

function UninstallISPackage(AppId: PWideChar; Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD; stdcall;
begin
  InnoSetupPackage.Init(AppId, Is64BitInstallMode <> 0, IsAdminInstallMode <> 0);
  result := InnoSetupPackage.Uninstall();
end;

exports
  IsISPackageInstalled,
  CompareISPackageVersion,
  UninstallISPackage;

end.
