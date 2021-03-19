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

unit
  wsUtilReg;

interface

uses
  windows;

const
  HKEY_CURRENT_USER_64 = $80000101;
  HKEY_CURRENT_USER_32 = $80000201;
  HKEY_LOCAL_MACHINE_64 = $80000102;
  HKEY_LOCAL_MACHINE_32 = $80000202;

// NOTE: The RootKey parameter in the below functions can also be
// HKEY_LOCAL_MACHINE_64 (works from 32-bit process) or HKEY_LOCAL_MACHINE_32

// Returns true if the specified registry subkey exists or false otherwise
function RegKeyExists(RootKey: HKEY;
                      const SubKeyName: unicodestring): boolean;

// Returns the ValueName value from the specified key and subkey into
// ResultStr; returns true for success or false for failure
function RegQueryStringValue(RootKey: HKEY;
                             const SubKeyName, ValueName: unicodestring;
                             var ResultStr: unicodestring): boolean;

implementation

// Updates RootKey and AccessFlags appropriately if using _32 or _64 RootKey
procedure UpdateRootKeyAndFlags(var RootKey: HKEY; var AccessFlags: REGSAM);
  begin
  if (RootKey and KEY_WOW64_32KEY) <> 0 then
    begin
    RootKey := RootKey and (not KEY_WOW64_32KEY);
    AccessFlags := AccessFlags or KEY_WOW64_32KEY;
    end
  else if (RootKey and KEY_WOW64_64KEY) <> 0 then
    begin
    RootKey := RootKey and (not KEY_WOW64_64KEY);
    AccessFlags := AccessFlags or KEY_WOW64_64KEY;
    end;
  end;

function RegKeyExists(RootKey: HKEY;
                      const SubKeyName: unicodestring): boolean;
  var
    AccessFlags: REGSAM;
    hkHandle: HANDLE;
  begin
  AccessFlags := KEY_READ;
  UpdateRootKeyAndFlags(RootKey, AccessFlags);
  result := RegOpenKeyExW(RootKey,                // HKEY   hKey
                          pwidechar(SubKeyName),  // LPCSTR lpSubKey
                          0,                      // DWORD  ulOptions
                          AccessFlags,            // REGSAM samDesired
                          hkHandle) = 0;          // PHKEY  phkResult
  if result then
    RegCloseKey(hkHandle);
  end;

function RegQueryStringValue(RootKey: HKEY;
                             const SubKeyName, ValueName: unicodestring;
                             var ResultStr: unicodestring): boolean;
  var
    AccessFlags: REGSAM;
    hkHandle: HKEY;
    ValueType, ValueSize: DWORD;
    pData: pointer;
  begin
  AccessFlags := KEY_READ;
  UpdateRootKeyAndFlags(RootKey, AccessFlags);
  result := RegOpenKeyExW(RootKey,                // HKEY   hKey
                          pwidechar(SubKeyName),  // LPCSTR lpSubKey
                          0,                      // DWORD  ulOptions
                          AccessFlags,            // REGSAM samDesired
                          hkHandle) = 0;          // PHKEY  phkResult
  if result then
    begin
    // First call: Get value size
    result := RegQueryValueExW(hkHandle,              // HKEY    hKey
                               pwidechar(ValueName),  // LPCSTR  lpValueName
                               nil,                   // LPDWORD lpReserved
                               @ValueType,            // LPDWORD lpType
                               nil,                   // LPBYTE  lpData
                               @ValueSize) = 0;       // LPDWORD lpcbData
    if result then
      begin
      // Must be REG_SZ or REG_EXPAND_SZ
      if (ValueType = REG_SZ) or (ValueType = REG_EXPAND_SZ) then
        begin
        GetMem(pData, ValueSize);
        // Second call: Get value data
        result := RegQueryValueExW(hkHandle,              // HKEY    hKey
                                   pwidechar(ValueName),  // LPCSTR  lpValueName
                                   nil,                   // LPDWORD lpReserved
                                   @ValueType,            // LPDWORD lpType
                                   pData,                 // LPBYTE  lpData
                                   @ValueSize) = 0;       // LPDWORD lpcbData
        if result then
          ResultStr := pwidechar(pData);
        FreeMem(pData, ValueSize);
        end
      else
        result := false;
      end;
    RegCloseKey(hkHandle);
    end;
  end;

begin
end.
