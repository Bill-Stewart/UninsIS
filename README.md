<!-- omit from toc -->
# UninsIS.dll

UninsIS.dll is a Windows DLL (dynamically linked library) to facilitate detection and uninstallation of applications installed by Inno Setup 6 and later.

- [Author](#author)
- [License](#license)
- [Download](#download)
- [Background](#background)
- [Example Inno Setup Usage](#example-inno-setup-usage)
- [Technical Details](#technical-details)
- [Functions](#functions)
  - [IsISPackageInstalled](#isispackageinstalled)
    - [Syntax](#syntax)
    - [Parameters](#parameters)
    - [Return Value](#return-value)
    - [Remarks](#remarks)
  - [GetISPackageVersion](#getispackageversion)
    - [Syntax](#syntax-1)
    - [Parameters](#parameters-1)
    - [Return Value](#return-value-1)
    - [Remarks](#remarks-1)
  - [TestVersionString](#testversionstring)
    - [Syntax](#syntax-2)
    - [Parameters](#parameters-2)
    - [Return Value](#return-value-2)
    - [Remarks](#remarks-2)
  - [CompareVersionStrings](#compareversionstrings)
    - [Syntax](#syntax-3)
    - [Parameters](#parameters-3)
    - [Return Value](#return-value-3)
    - [Remarks](#remarks-3)
  - [CompareISPackageVersion](#compareispackageversion)
    - [Syntax](#syntax-4)
    - [Parameters](#parameters-4)
    - [Return Value](#return-value-4)
    - [Remarks](#remarks-4)
  - [UninstallISPackage](#uninstallispackage)
    - [Syntax](#syntax-5)
    - [Parameters](#parameters-5)
    - [Return Value](#return-value-5)
    - [Remarks](#remarks-5)


# Author

Bill Stewart - bstewart at iname dot com

# License

UninsIS.dll is covered by the GNU Lesser Public License (LPGL). See the file `LICENSE` for details.

# Download

https://github.com/Bill-Stewart/UninsIS/releases/

# Background

Inno Setup is a powerful, freely available tool for building installers for the Windows OS platform.

The Inno Setup philosophy for upgrading or downgrading software is, put simply, install the new version "on top" of the old version. Files will be overwritten or retained according to version numbering rules (where selected/applicable), etc. However, there are some limitations:

* If a new version of an application makes obsolete any files installed by a previous version, the obsolete files remain on the target system after upgrading. This can be mitigated in simple use cases by using Inno Setup's `[InstallDelete]` section or custom code, but this has the potential to be awkward, unwieldy, and error-prone for larger setup projects.

* The above problem can also apply to registry entries: Suppose an older version of an application stores configuration data using the Windows registry but a newer version uses text-based configuration files. Without custom code, the obsolete registry entries remain on the target system after an upgrade.

* Unless file versioning is handled carefully, downgrading can result in a corrupted application due to mismatched file versions.

Depending on your needs, it may be preferable to uninstall an existing installed version first. UninsIS.dll provides the following capabilities:

* Detect if a package is currently installed

* Get the version of the currently installed package

* Test whether a version string is valid

* Compare two version strings

* Determine if the installed package's version is the same, less than, or greater than the version you are currently installing

* Uninstall the installed package

For example, you can use the UninsIS.dll functions to automatically uninstall an installed version of an application when upgrading or downgrading (or both).

# Example Inno Setup Usage

1.  Add the **UninsIS.dll** file to your Inno Setup script's `[Files]` section:

    ```
    [Files]
    Source: "UninsIS.dll"; Flags: dontcopy
    ```

    You can use the `dontcopy` flag because the DLL is used only during setup (not uninstall).

2.  In the `[Code]` section, import the needed DLL functions for setup only:

    ```
    function DLLIsISPackageInstalled(AppId: string;
      Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD;
      external 'IsISPackageInstalled@files:UninsIS.dll stdcall setuponly';

    function DLLGetISPackageVersion(AppId, Version: string;
      NumChars, Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD;
      external 'GetISPackageVersion@files:UninsIS.dll stdcall setuponly';

    function DLLCompareISPackageVersion(AppId, InstallingVersion: string;
      Is64BitInstallMode, IsAdminInstallMode: DWORD): Integer;
      external 'CompareISPackageVersion@files:UninsIS.dll stdcall setuponly';

    function DLLUninstallISPackage(AppId: string;
      Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD;
      external 'UninstallISPackage@files:UninsIS.dll stdcall setuponly';
    ```

    The imported DLL functions are prefixed with `DLL` to make them easily distinguishable from other functions in the script.

3.  In the `[Code]` section after the imported functions, write "wrapper" functions for the imported DLL functions:

    ```
    // Wrapper for UninsIS.dll IsISPackageInstalled function
    // Returns true if package is detected as installed, or false otherwise
    function IsISPackageInstalled(): Boolean;
    begin
      result := DLLIsISPackageInstalled('Your_Appid_Here',  // AppId
        DWORD(Is64BitInstallMode()),                        // Is64BitInstallMode
        DWORD(IsAdminInstallMode())) = 1;                   // IsAdminInstallMode
    end;

    // Wrapper for UninsIS.dll GetISPackageVersion function
    function GetISPackageVersion(): string;
    var
      NumChars: DWORD;
      OutStr: string;
    begin
      result := '';
      // First call: Get number of characters needed for version string
      NumChars := DLLGetISPackageVersion('Your_Appid_Here',  // AppId
        '',                                                  // Version
        0,                                                   // NumChars
        DWORD(Is64BitInstallMode()),                         // Is64BitInstallMode
        DWORD(IsAdminInstallMode()));                        // IsAdminInstallMode
      SetLength(OutStr, NumChars);
      // Second call: Get version string
      if DLLGetISPackageVersion('{#AppGUID}',  // AppID
        OutStr,                                // Version
        NumChars,                              // NumChars
        DWORD(Is64BitInstallMode()),           // Is64BitInstallMode
        DWORD(IsAdminInstallMode())) > 0 then  // IsAdminInstallMode
      begin
        result := OutStr;
      end;
    end;

    // Wrapper for UninsIS.dll CompareISPackageVersion function
    // Returns:
    // < 0 if version we are installing is < installed version
    // 0   if version we are installing is = installed version
    // > 0 if version we are installing is > installed version
    function CompareISPackageVersion(): Integer;
    begin
      result := DLLCompareISPackageVersion('Your_AppId_Here',  // AppId
        'Your_AppVersion_Here',                                // InstallingVersion
        DWORD(Is64BitInstallMode()),                           // Is64BitInstallMode
        DWORD(IsAdminInstallMode()));                          // IsAdminInstallMode
    end;

    // Wrapper for UninsIS.dll UninstallISPackage function
    // Returns 0 for success, non-zero for failure
    function UninstallISPackage(): DWORD;
    begin
      result := DLLUninstallISPackage('Your_AppId_Here',  // AppId
        DWORD(Is64BitInstallMode()),                      // Is64BitInstallMode
        DWORD(IsAdminInstallMode()));                     // IsAdminInstallMode
    end;
    ```

    In the above code, replace:

    * `Your_AppId_Here` with the `AppId` of your setup project
    * `Your_AppVersion_Here` with the `AppVersion` of your setup project

    It is recommended to use preprocessor values for these (e.g., `{#MyAppId}`) to avoid errors and to simplify changes.

4.  In the `[Code]` section after the wrapper functions, add or update the `PrepareToInstall` event function to use the wrapper functions:

    ```
    function PrepareToInstall(var NeedsRestart: Boolean): string;
    begin
      result := '';
      if IsISPackageInstalled() and (CompareISPackageVersion() <> 0) then
        UninstallISPackage();
    end;
    ```

    Change the comparison with the `CompareISPackageVersion` function to suit your needs:

    * `(CompareIsPackageVersion() < 0)` - uninstall installed version if the version you are installing is less than the installed version (i.e., downgrade)
    * `(CompareIsPackageVersion() <> 0)` - uninstall installed version if the version you are installing is different from the installed version (i.e., either downgrade or upgrade)
    * `(CompareIsPackageVersion() > 0)` - uninstall installed version if version you are installing is greater thanthe installed version (i.e., upgrade)

See the sample UninsIS.iss script for a fully working example that also provides logging using the `Log` function (recommended).

# Technical Details

The following functions detect installed Inno Setup packages and versions by reading from the registry:

`IsISPackageInstalled`  
`GetISPackageVersion`  
`CompareISPackageVersion`  
`UninstallISPackage`

In order to properly detect an installed package, these functions need 3 pieces of information from the running installer:

* _The package's_ `AppId`. Inno Setup uses the `AppId` value (found in the `[Setup]` section of the Inno Setup script) to name the registry subkey that contains a package's installation details. UninsIS.dll, on its own, cannot determine an installer's `AppId`, so you must provide this information to the functions using a parameter.

* _32-bit vs 64-bit install mode._ 32-bit vs. 64-bit install mode determines whether the installer users file system and registry redirection on 64-bit Windows. UninsIS.dll, on its own, cannot determine whether the install is using 32-bit or 64-bit install mode, so you must provide this information to the functions using a parameter.

* _Administrative vs non administrative install mode._ The registry root key for detecting an installed package is `HKEY_LOCAL_MACHINE` if using administrative install mode (per-computer), or `HKEY_CURRENT_USER` if using non-administrative install mode (per-user). UninsIS.dll cannot determine, on its own, whether the install is using administrative or non administrative install mode, so you must provided this information to the functions using a parameter.

For 32-bit vs. 64-bit and administrative vs. non administrative install modes registry data locations, see the following table:

| Install mode        | Administrative       | Non administrative  |            |
| ------------------- | -------------------- | ------------------- | ---------- |
|                     | **Root**             | **Root**            | **Subkey**
| 32-bit on 32-bit OS | `HKEY_LOCAL_MACHINE` | `HKEY_CURRENT_USER` | Software\Microsoft\Windows\CurrentVersion\Uninstall
| 64-bit on 64-bit OS | `HKEY_LOCAL_MACHINE` | `HKEY_CURRENT_USER` | Software\Microsoft\Windows\CurrentVersion\Uninstall
| 32-bit on 64-bit OS | `HKEY_LOCAL_MACHINE` | `HKEY_CURRENT_USER` | Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall

# Functions

This section documents the functions exported by UninsIS.dll.

---

## IsISPackageInstalled


The `IsISPackageInstalled` function detects whether an Inno Setup package is installed.

### Syntax

C/C++:
```
DWORD IsISPackageInstalled(
  LPWSTR AppId,
  DWORD  Is64BitInstallMode,
  DWORD  IsAdminInstallMode
);
```

Pascal:
```
function IsISPackageInstalled(AppId: PWideChar;
  Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD;
```

### Parameters

`AppId`

A Unicode string containing the `AppId` of the Inno Setup package.

`Is64BitInstallMode`

Specify 1 if setup is using 64-bit install mode, or 0 otherwise.

`IsAdminInstallMode`

Specify 1 if setup is running in administrative install mode, or 0 otherwise.

### Return Value

The function returns 0 if the specified package is not detected as installed, or 1 if it is detected as installed.

### Remarks

* The values for the `Is64BitInstallMode` and `IsAdminInstallMode` parameters can be passed to the function in the Inno Setup `[Code]` section by casting the Inno Setup functions of the same names to the `DWORD` type. See [Example Inno Setup Usage](#example-inno-setup-usage) for examples.

* The package is detected as installed using the following table:

  | OS     | `Is64BitInstallMode` | `IsAdminInstallMode` | Root                 | Subkey
  | ------ | -------------------- | -------------------- | -------------------- | ------
  | 32-bit | 0                    | 1                    | `HKEY_LOCAL_MACHINE` | Software\Microsoft\Windows\CurrentVersion\Uninstall
  | 32-bit | 0                    | 0                    | `HKEY_CURRENT_USER`  | Software\Microsoft\Windows\CurrentVersion\Uninstall
  | 64-bit | 0                    | 1                    | `HKEY_LOCAL_MACHINE` | Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall
  | 64-bit | 0                    | 0                    | `HKEY_CURRENT_USER`  | Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall
  | 64-bit | 1                    | 1                    | `HKEY_LOCAL_MACHINE` | Software\Microsoft\Windows\CurrentVersion\Uninstall
  | 64-bit | 1                    | 0                    | `HKEY_CURRENT_USER`  | Software\Microsoft\Windows\CurrentVersion\Uninstall

* The function appends the value of the `AppId` parameter and the string `_is1` to the appropriate registry subkey from the above table. If the registry subkey exists, the function returns 1 (i.e., the package is detected as installed); otherwise, the function returns 0.

---

## GetISPackageVersion

The `GetISPackageVersion` gets the installed package's version as a string.

### Syntax

C/C++:
```
DWORD GetISPackageVersion(
  LPWSTR AppId,
  LPWSTR Version,
  DWORD  NumChars,
  DWORD  Is64BitInstallMode,
  DWORD  IsAdminInstallMode
);
```

Pascal:
```
function GetISPackageVersion(AppId, Version: PWideChar;
  NumChars, Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD;
```

### Parameters

`AppId`

A Unicode string containing the `AppId` of the Inno Setup package.

`Version`

A pointer to a variable that receives a Unicode string that contains the version number string.

`NumChars`

Specifies the number of characters needed to store the version number string, not including the terminating null character.

`Is64BitInstallMode`

Specify 1 if setup is using 64-bit install mode, or 0 otherwise.

`IsAdminInstallMode`

Specify 1 if setup is running in administrative install mode, or 0 otherwise.

### Return Value

The function returns 0 if it failed, or non-zero if it succeeded.

### Remarks

* The values for the `Is64BitInstallMode` and `IsAdminInstallMode` parameters can be passed to the function in the Inno Setup `[Code]` section by casting the Inno Setup functions of the same names to the `DWORD` type. See [Example Inno Setup Usage](#example-inno-setup-usage) for examples.

* To get the version number string, call the function twice. In the first call to the function, specify a null pointer for the `Version` parameter and `0` for the `NumChars` parameter. The function will return with the number of characters required for the buffer. Allocate a buffer of sufficient size (including the terminating null character), then call the function a second time to retrieve the string. See [Example Inno Setup Usage](#example-inno-setup-usage) for an example.

* The function uses the `DisplayVersion` string value in the installed package's registry subkey for comparison purposes.

* The return value of this function is only meaningful if the `IsISPackageInstalled` function's return value is 1 (i.e., the package is currently detected as installed).

---

## TestVersionString

The `TestVersionString` function tests whether a version string is valid.

### Syntax

C/C++:
```
DWORD TestVersionString(
  LPWSTR Version
);
```

Pascal:
```
function TestVersionString(Version: PWideChar): DWORD;
```

### Parameters

`Version`

A Unicode string containing a version number. See the **Remarks** section for the format.

### Return Value

The function returns non-zero if the specified version number string is valid, or zero otherwise.

### Remarks

A version number string uses the format _a_[._b_[._c_[._d_]]]; where _a_, _b_, _c_, and _d_ are 16-bit unsigned integers in the range 0-65535. Any omitted part of the version is counted as a zero; i.e., 1 = 1.0 = 1.0.0 = 1.0.0.0 and 1.1 = 1.1.0 = 1.1.0.0 (etc.).

---

## CompareVersionStrings

The `CompareVersionStrings` functrion compares two version number strings.

### Syntax

C/C++:
```
int CompareVersionStrings(
  LPWSTR Version1,
  LPWSTR Version2
);
```

Pascal:
```
function CompareVersionStrings(Version1, Version2: PWideChar): Integer;
```

### Parameters

`Version1`

A Unicode string containing a version number. See the **Remarks** section for the format.

`Version2`

A Unicode string containing a version number. See the **Remarks** section for the format.

### Return Value

See the following table for return values:

| Return Value | Description
| ------------ | -----------
| < 0          | `Version1` is less than `Version2`
| 0            | `Version1` is equal to `Version2`
| > 0          | `Version1` is greater than `Version2`

The return value is zero if either `Version1` or `Version2` contains an invalid version number string. For this reason, it is recommended to use the `TestVersionString` function to validate the version strings before comparing them with this function.

### Remarks

A version number string uses the format _a_[._b_[._c_[._d_]]]; where _a_, _b_, _c_, and _d_ are 16-bit unsigned integers in the range 0-65535. Any omitted part of the version number is counted as a zero; i.e., 1 = 1.0 = 1.0.0 = 1.0.0.0 and 1.1 = 1.1.0 = 1.1.0.0 (etc.).

---

## CompareISPackageVersion

The `CompareISPackageVersion` function checks whether an installed Inno Setup package's version is less than, equal to, or greater than a specified version.

### Syntax

C/C++:
```
int CompareISPackageVersion(
  LPWSTR AppId,
  LPWSTR InstallingVersion,
  DWORD  Is64BitInstallMode,
  DWORD  IsAdminInstallMode
);
```

Pascal:
```
function CompareISPackageVersion(AppId, InstallingVersion: PWideChar;
  Is64BitInstallMode, IsAdminInstallMode: DWORD): Integer;
```

### Parameters

`AppId`

A Unicode string containing the `AppId` of the Inno Setup package.

`InstallingVersion`

A Unicode string containing the version number of the package being installed.

`Is64BitInstallMode`

Specify 1 if setup is using 64-bit install mode, or 0 otherwise.

`IsAdminInstallMode`

Specify 1 if setup is running in administrative install mode, or 0 otherwise.

### Return Value

See the following table for return values:

| Return Value | Description
| ------------ | -----------
| < 0          | `InstallingVersion` is less than the installed version
| 0            | `InstallingVersion` is equal to the installed version
| > 0          | `InstallingVersion` is greater than the installed version

The return value is zero if `InstallingVersion` contains an invalid version number string.

### Remarks

* The values for the `Is64BitInstallMode` and `IsAdminInstallMode` parameters can be passed to the function in the Inno Setup `[Code]` section by casting the Inno Setup functions of the same names to the `DWORD` type. See [Example Inno Setup Usage](#example-inno-setup-usage) for examples.

* The function uses the `DisplayVersion` string value in the installed package's registry subkey for comparison purposes.

* The return value of this function is only meaningful if the `IsISPackageInstalled` function's return value is 1 (i.e., the package is currently detected as installed).

---

## UninstallISPackage

The `UninstallISPackage` function uninstalls an installed Inno Setup package.
### Syntax

C/C++:
```
DWORD UninstallISPackage(
  LPWSTR AppId,
  DWORD  Is64BitInstallMode,
  DWORD  IsAdminInstallMode
);
```

Pascal:
```
function UninstallISPackage(AppId: PWideChar;
  Is64BitInstallMode, IsAdminInstallMode: DWORD): DWORD;
```

### Parameters

`AppId`

A Unicode string containing the `AppId` of the Inno Setup package.

`Is64BitInstallMode`

Specify 1 if setup is using 64-bit install mode, or 0 otherwise.

`IsAdminInstallMode`

Specify 1 if setup is running in administrative install mode, or 0 otherwise.

### Return Value

The function returns 0 if the specified package uninstall completed successfully, or non-zero otherwise.

### Remarks

* The values for the `Is64BitInstallMode` and `IsAdminInstallMode` parameters can be passed to the function in the Inno Setup `[Code]` section by casting the Inno Setup functions of the same names to the `DWORD` type. See [Example Inno Setup Usage](#example-inno-setup-usage) for examples.

* The function uses the `UninstallString` string value in the package's registry subkey to determine the filename of the uninstaller executable. It then executes the uninstaller executable using the `/SILENT`, `/SUPPRESSMSGBOXES`, and `/NORESTART` command line parameters. If the uninstaller process completes with an exit code of zero (no errors), the function then waits for the uninstaller executable file to be deleted.

* The function will return with an error code if the specified package is not detected as installed, so it is recommended to use this function only when `IsISPackageInstalled` returns 1 (i.e., the package is currently detected as installed).
