# Changelog

## 2.0.0-rc1 - 2026-07-15

### Start Menu
- **Changed:** The default Start Menu scope changed from All Users to the current user — `Get-StartMenuProgramsPath`, `New-StartMenuProgramsFolder`, `New-StartMenuShortcut`, `Remove-StartMenuShortcut` and `New-PowershellStartMenuShortcut` now target the current user's Start Menu unless `-AllUsers` (alias `-Machine`, `-All`) is given.
- **Changed:** `-Name` on `New-StartMenuShortcut` is now mandatory — it is no longer inferred from the `-Executable` file name.
- **Changed:** `New-StartMenuShortcut` and `Remove-StartMenuShortcut` now use the Start Menu Programs root when `-Folder` is omitted — `-Folder` previously defaulted to `-Name`, so the shortcut went to `<Programs>\<Name>\<Name>.lnk`; it is now `<Programs>\<Name>.lnk`, matching `New-PowershellStartMenuShortcut`. Pass `-Folder` to keep a containing folder.
- **Changed:** `-Icon` on `New-StartMenuShortcut` and `New-PowershellStartMenuShortcut` now takes the combined location in the form `"file,index"`, e.g. `-Icon "C:\Program Files\MyApp\MyApp.exe,3"`. It previously took a plain icon file path and always appended `,0` — pass such a path as `-IconLocation` instead. `-Icon` is mutually exclusive with `-IconLocation` / `-IconIndex`; combining them is a terminating error.
- **Added:** `-IconLocation` (alias `-IconFile`) and `-IconIndex` on `New-StartMenuShortcut` and `New-PowershellStartMenuShortcut` — `-IconIndex` selects the icon within the icon file given by `-IconLocation`, instead of always using index `0`. Default: `0`.
- **Added:** `-AllUsers` (aliases `-Machine`, `-All`) and `-User` on `New-PowershellStartMenuShortcut` — the shortcut can now be created in the All Users Start Menu, matching the other Start Menu functions. The default stays the current user.
- **Removed:** The `-Group` and `-GroupName` parameter aliases on the Start Menu functions — pass `-Folder` on `New-StartMenuShortcut`, `Remove-StartMenuShortcut` and `New-PowershellStartMenuShortcut`, and `-Name` on `New-StartMenuProgramsFolder`.
- **Removed:** The `-AppName` and `-Folder` parameter aliases on `New-StartMenuProgramsFolder` — pass `-Name`.
- **Removed:** The `-App` and `-AppName` parameter aliases on `New-StartMenuShortcut`, `Remove-StartMenuShortcut` and `New-PowershellStartMenuShortcut` — pass `-Name`.

### System PATH and environment variables
- **Changed:** The default scope of the system-path and environment write functions changed from Machine to User — `Add-SystemPathLocation`, `Remove-SystemPathLocation`, `Set-EnvironmentVariable` and `Remove-EnvironmentVariable` now write to the user scope unless `-Machine` is given. Administrator privileges are no longer required by default.

### Theme
- **Removed:** entire component (`Get-Theme`, `Set-Theme`, `Switch-Theme` and alias `theme`)

### Usage
- **Removed:** entire component (`Get-Usage` and alias `du`)

## 1.11.0 - 2026-07-13

### Added
- **Scope on system-path locations** — `Get-SystemPath` and `Get-SystemPathLocation` now tag each location with its scope: `Machine`, `User`, or `Process` (present only on the current shell's path).
- **Current-user Start Menu support** — `Get-StartMenuProgramsPath`, `New-StartMenuProgramsFolder` and `New-StartMenuShortcut` gain a `-User` switch (and `-AllUsers`, aliases `-Machine` / `-All`). The default stays All Users (machine) for backward compatibility (#8).
- **`Remove-StartMenuShortcut`** — removes a Start Menu shortcut, and its containing folder when it becomes empty. Reports a terminating error if the shortcut does not exist (#9).
- **`Invoke-Elevated`** (aliases `sudops`, `sups`) — runs a command as administrator via the Windows `sudo` command, e.g. `sudops addpath -Machine 'C:\Tools'` (#37).

### Changed
- **`New-StartMenuShortcut` and `New-PowershellStartMenuShortcut` no longer overwrite an existing shortcut silently.** They now report a terminating error when the shortcut already exists; pass `-Force` to overwrite. The previous silent overwrite was unintended behavior (#36).
- The default scope of the system-path and environment write functions (and the new Start Menu `-User` switch) will change from Machine to User in v2; a deprecation note now documents this.

### Fixed
- **`New-PowershellStartMenuShortcut -Folder`** now creates the shortcut in the given folder; it was ignored because the code referenced an undefined `$Group` instead of `$Folder`.
- **`Set-Theme`** taskbar-color workaround wrote a scriptblock literal instead of the toggled 0/1 value.

## 1.10.1 - 2026-07-13

### Changed
- **`Remove-SystemPathLocation`** now reports a warning when the location is not on the system PATH (previously a silent no-op), matching the warning `Add-SystemPathLocation` reports for an already-present location.

## 1.10.0 - 2026-07-13

### Added
- **`Remove-DuplicateSystemPathLocations`** (alias `deduppath`) — removes duplicate locations from the system PATH, for the local machine, the current user, or both combined (the default). Within a scope the first occurrence of each location is kept; on a cross-scope duplicate the machine copy is kept by default, or the user copy with `-KeepUser`. Idempotent — no change when there are no duplicates.
- **`Move-SystemPathLocation`** (alias `movepath`) — moves a location from the machine system PATH to the user system PATH (`-ToUser`) or the other way (`-ToMachine`). If there is nothing to move (already on the target, or on neither), a warning is reported.

### Changed
- **`Add-SystemPathLocation`** now reports a warning when the location is already on the system PATH (previously a silent no-op).
- Error handling in the system-path and environment-variable functions no longer rewraps failures in a `try`/`catch`; the original error is reported directly.

## 1.9.1 - 2026-07-12

### Changed
- **`Remove-SystemPathLocation` is now idempotent** — removing a location that is not on the PATH no longer reports an error; the path is left unchanged. This supersedes the not-found-error behavior from 1.8.0 (issue #1), so `-ErrorAction Stop` no longer aborts on an absent location. Mirrors the idempotent `Add-SystemPathLocation` behavior from 1.9.0.

## 1.9.0 - 2026-07-12

### Changed
- **`Add-SystemPathLocation` is now idempotent** — adding a location that is already on the PATH no longer reports an error; the path is left unchanged. This supersedes the duplicate-error behavior from 1.8.0 (issue #1), so `-ErrorAction Stop` no longer aborts on an already-present location.

### Added
- **`-Front` promotes an existing location** — `Add-SystemPathLocation -Front` (alias `-First`) moves an already-present location to the beginning of the PATH instead of leaving it in place.

## 1.8.0 - 2026-07-10

### Added
- **`Get-SystemPathLocation`** — finds a location on the system PATH and reports its scope (machine, user, or effective). Accepts an exact `-Location` (positional) or a `-Filter` wildcard, plus the `-Machine` / `-User` scope switches.
- **`Test-SystemPathLocation`** — returns `$true`/`$false` for whether a location is on the system PATH, with the same `-Location` / `-Filter` and scope options.
- **`-Filter`** parameter on **`Get-SystemPath`** — filters the PATH locations by wildcard. Positional, so `path *Git*` works.

## 1.7.1 - 2026-07-09

- Add a Pester test suite covering every command.
- Run the tests in CI on every push and pull request.

## 1.7.0 - 2026-07-08

### Added
- **`Get-ShortcutIconLocation`** — now a public, exported function returning a shortcut's `.lnk` icon location. Previously defined but internal. Gains `[CmdletBinding()]` (common-parameter support).

## 1.6.2 - 2026-07-07

Documentation and help-quality release. No changes to runtime behavior or the exported command set.

### Improved
- **Comment-based help overhauled** — each function's help now sits at the top of its body, documents every parameter with `.PARAMETER`, and uses only valid `Get-Help` keywords, so help renders correctly across the whole module.
- **Aliases documented** under `.NOTES` (e.g. `path`, `addpath`, `du`, `theme`).
- **`-Effective` default clarified** in the system-path / environment help.

### Added
- Help for `Get-Usage` and `Get-ShortcutIconLocation` (previously undocumented).
- Project logo.

### Fixed
- Wrong parameter name in `New-PowershellStartMenuShortcut` help (`GroupName` → `Folder`).
- Restored help for `Get-Theme` and `Send-ThemeChangeBroadcast` — it was orphaned outside the function body and invisible to `Get-Help`.
- Minor style/casing cleanup.

## 1.6.1 - 2025-06-28

- Workaround hack to change taskbar color on all screens when switching theme.

## 1.6.0 - 2025-06-10

- Notify other processes when switching theme (light / dark).
- Make parameter `-RestartExplorer` obsolete, showing a warning if it is still being used. Usage has no further effect.
- **LICENSE change** from MIT to Apache 2.0, see [LICENSE.txt](https://github.com/igorakkerman/easypeasy/blob/main/LICENSE.txt).

## 1.5.1 - 2024-08-21

- Allow specifying an icon for a PowerShell start menu shortcut with `New-PowershellStartMenuShortcut`.
- Make `Icon` the primary parameter name, make `IconLocation` an alias for `New-StartMenuShortcut`.

## 1.5.0 - 2024-08-21

- Allow specifying an icon for a PowerShell start menu shortcut.
- Make `-Icon` the primary parameter name; `-IconLocation` becomes an alias.

## 1.4.2 - 2024-08-18

- Fix name when creating start menu shortcut.

## 1.4.1 - 2024-07-23

- Fix name when creating PowerShell shortcut.

## 1.4.0 - 2024-07-22

- Add `Get-Theme` function.
- Add `Folder` as optional parameter name for `New-StartMenuShortcut`.
- Unify parameter naming in startmenu, preserving compatibility.

## 1.3.4 - 2024-04-05

- Optimize `ErrorAction` in environment and systempath functions.

## 1.3.3 - 2024-04-05

- Maintenance release (version bump only).

## 1.3.2 - 2024-04-05

- Reset environment variable in the current shell after modification.
- Remove `ErrorAction` from `Get-EnvironmentVariable`.
- CI: publish only created releases, not edited ones.

## 1.3.1 - 2024-04-05

- `Set-EnvironmentVariable` and `Remove-EnvironmentVariable` now take effect in the current shell (#34).
- Rewrite README as examples, with various documentation clarifications.

## 1.3.0 - 2023-12-26

- Add `Get-ProgramFilesFolder` function and `programs` alias.

## 1.2.2 - 2023-12-20

- Fix `desktop` alias.

## 1.2.1 - 2023-12-20

- Prevent errors when creating an already-existing alias.

## 1.2.0 - 2023-12-20

- Add `Get-DesktopFolder` function and `desktop` alias.
- Simplify `Switch-Theme` usage and `theme` alias.
- Change the timestamp format returned by `Get-Timestamp`.

## 1.1.1 - 2023-11-10

- Fix splitting the system path when it contains an empty location (e.g. a trailing semicolon).

## 1.1.0 - 2023-04-01

- Add `Assert-Administrator` function.
- Rename the `-First` parameter to `-Front` (compatibility alias kept).
- Improve error handling and reporting for system path and environment operations.
- Handle unsetting an environment variable gracefully.
- Add GitHub Action to publish to the PowerShell Gallery.

## 1.0.0 - 2023-03-30

- Initial release: PowerShell module wrapping common Windows administration tasks — system PATH, environment variables, Start Menu shortcuts, `Stop-Explorer`, timestamps, and more.
