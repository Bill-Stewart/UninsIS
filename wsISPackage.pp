{ Copyright (C) 2021-2023 by Bill Stewart (bstewart at iname.com)

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
    MyAppId, MySubKeyName: string;
    MyRootKey:             HKEY;
  public
    constructor Create();
    procedure Init(const AppId: string; const Is64BitInstallMode, IsAdminInstallMode: Boolean);
    function IsInstalled(): DWORD;
    function GetVersion(): string;
    function CompareVersion(const InstallingVersion: string): LongInt;
    function Uninstall(): DWORD;
    destructor Destroy(); override;
  end;

var
  InnoSetupPackage: TInnoSetupPackage;

// Returns true if the string is a valid version string, or false otherwise
function wsTestVersionString(const S: string): Boolean;

// Compares two version strings 'a[.b[.c[.d]]]'
// Returns:
// < 0  if V1 < V2
// 0    if V1 = V2
// > 0  if V1 > V2
function wsCompareVersionStrings(const V1, V2: string): LongInt;

implementation

uses
  wsUtilFile,
  wsUtilReg;

type
  TStringArray = array of string;
  TVersionArray = array[0..3] of Word;

// Returns the number of times Substring appears in S
function CountSubstring(const Substring, S: string): LongInt;
var
  P: LongInt;
begin
  result := 0;
  P := Pos(Substring, S, 1);
  while P <> 0 do
  begin
    Inc(result);
    P := Pos(Substring, S, P + Length(Substring));
  end;
end;

// Splits S into the Dest array using Delim as a delimiter
procedure StrSplit(S, Delim: string; var Dest: TStringArray);
var
  I, P: LongInt;
begin
  I := CountSubstring(Delim, S);
  // If no delimiters, Dest is a single-element array
  if I = 0 then
  begin
    SetLength(Dest, 1);
    Dest[0] := S;
    exit;
  end;
  SetLength(Dest, I + 1);
  for I := 0 to Length(Dest) - 1 do
  begin
    P := Pos(Delim, S);
    if P > 0 then
    begin
      Dest[I] := Copy(S, 1, P - 1);
      Delete(S, 1, P + Length(Delim) - 1);
    end
    else
      Dest[I] := S;
  end;
end;

function StrToInt(const S: string; var I: LongInt): Boolean;
var
  Code: Word;
begin
  Val(S, I, Code);
  result := Code = 0;
end;

function StrToWord(const S: string; var W: Word): Boolean;
var
  Code: Word;
begin
  Val(S, W, Code);
  result := Code = 0;
end;

function GetVersionArray(const S: string; var Version: TVersionArray): Boolean;
var
  A: TStringArray;
  ALen, I, Part: LongInt;
begin
  result := false;
  StrSplit(S, '.', A);
  ALen := Length(A);
  if ALen > 4 then
    exit;
  if ALen < 4 then
  begin
    SetLength(A, 4);
    for I := ALen to 3 do
      A[I] := '0';
  end;
  for I := 0 to Length(A) - 1 do
  begin
    result := StrToInt(A[I], Part);
    if not result then
      exit;
    result := (Part >= 0) and (Part <= $FFFF);
    if not result then
      exit;
  end;
  for I := 0 to 3 do
  begin
    result := StrToWord(A[I], Version[I]);
    if not result then
      exit;
  end;
end;

function wsTestVersionString(const S: string): Boolean;
var
  Version: TVersionArray;
begin
  result := GetVersionArray(S, Version);
end;

function wsCompareVersionStrings(const V1, V2: string): LongInt;
var
  Ver1, Ver2: TVersionArray;
  I: LongInt;
  Word1, Word2: Word;
begin
  result := 0;
  if not GetVersionArray(V1, Ver1) then
    exit;
  if not GetVersionArray(V2, Ver2) then
    exit;
  for I := 0 to 3 do
  begin
    Word1 := Ver1[I];
    Word2 := Ver2[I];
    if Word1 > Word2 then
    begin
      result := 1;
      exit;
    end
    else if Word1 < Word2 then
    begin
      result := -1;
      exit;
    end;
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

procedure TInnoSetupPackage.Init(const AppId: string; const Is64BitInstallMode, IsAdminInstallMode: Boolean);
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

function TInnoSetupPackage.GetVersion(): string;
var
  DisplayVersion: string;
begin
  result := '';
  if myAppId <> '' then
  begin
    if RegQueryStringValue(MyRootKey, MySubKeyName, 'DisplayVersion', DisplayVersion) and (DisplayVersion <> '') then
      result := DisplayVersion;
  end;
end;

function TInnoSetupPackage.CompareVersion(const InstallingVersion: string): LongInt;
var
  CurrentVersion: string;
begin
  result := 0;
  CurrentVersion := GetVersion();
  if (CurrentVersion <> '') and (InstallingVersion <> '') then
    result := wsCompareVersionStrings(InstallingVersion, CurrentVersion);
end;

function TInnoSetupPackage.Uninstall(): DWORD;
var
  UninstallString, UninstallerFileName: string;
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
