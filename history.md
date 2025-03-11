# UninsIS.dll Version History

## 1.6.0 (11 Mar 2025)

* Fix: Uninstall didn't work if the uninstall command in the registry included the `/LOG` parameter (or any other parameters). (Thanks to user gioros83 on GitHub for the report.)

* Added the `GetISPackageUninstallString` function.

* Improved code to use other released units.

## 1.5.0 (5 Dec 2023)

* Added the `GetISPackageVersion`, `TestVersionString`, and `CompareVersionStrings` functions.

* Improved version string code.

* Enabled switch to FPC UNICODESTRINGS mode (i.e., string = UnicodeString, PChar = PWideChar, etc.).

## 1.0.1 (10 Jun 2021)

* Update code formatting.

* String-read from registry updated to avoid potential (but very low probability) buffer overflow error.

* Compile using FPC 3.2.2.

* Minor tweaks.

## 1.0.0 (19 Mar 2021)

* Initial version.
