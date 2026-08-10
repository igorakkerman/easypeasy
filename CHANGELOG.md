# Changelog

## 2.0.0 - pending

First major release in years. Streamlined, consistent APIs. Parameters mostly used by scripts are mandatory now, without defaults, making calling code more expressive. 

Dropping legacy parameters and aliases of little use, the theme component and the usage component. Theme app will be rebuilt separately. For the disk usage, use `du` in Microsoft's [Coreutils for Windows](https://github.com/microsoft/coreutils)).

### Start Menu
- **Changed:** All Start Menu functions target the current user; pass `-AllUsers` (aliases `-Machine`, `-All`) for the previous All Users default.
- **Changed:** `New-StartMenuShortcut` and `New-PowershellStartMenuShortcut` build on `New-Shortcut` and take its parameters: `-Target`, `-Arguments`, `-RunLocation`, `-Description`, `-Icon`, `-Hotkey`, `-WindowStyle`, `-Elevated`, `-Force`.
- **Changed:** `New-StartMenuShortcut` and `New-PowershellStartMenuShortcut` return `Shortcut` record instead of path string.
- **Changed:** `-Executable` renamed to `-Target` on `New-StartMenuShortcut`.
- **Changed:** `-Icon` takes icon file, optionally followed by comma and index of icon within it.
- **Changed:** `-RunAsAdministrator` on `New-PowershellStartMenuShortcut` renamed to `-Elevated`.
- **Changed:** `-Visible` and `-Maximized` on `New-PowershellStartMenuShortcut` replaced by `-WindowStyle`: `Normal`, `Maximized` or `Minimized`. Default: `Minimized`.
- **Changed:** `-Name` on `New-StartMenuShortcut` is mandatory, no longer inferred from the target.
- **Changed:** `New-StartMenuShortcut` and `Remove-StartMenuShortcut` use the Programs root when `-Folder` is omitted: `<Programs>\<Name>.lnk`, previously `<Programs>\<Name>\<Name>.lnk`. Pass `-Folder` to keep a containing folder.
- **Added:** `-RunLocation`, `-Description` and `-Hotkey` on `New-StartMenuShortcut` and `New-PowershellStartMenuShortcut`.
- **Added:** `-AllUsers` (aliases `-Machine`, `-All`) and `-User` on `New-PowershellStartMenuShortcut`, matching the other Start Menu functions. Default stays the current user.
- **Removed:** `-IconLocation` (alias `-IconFile`) and `-IconIndex` — pass `-Icon "file,index"`.
- **Removed:** Aliases `-Admin` and `-Elevate` on `New-PowershellStartMenuShortcut` — pass `-Elevated`, or its alias `-Administrator`.
- **Added:** Alias `-Administrator` for `-Elevated` on `New-StartMenuShortcut` and `New-PowershellStartMenuShortcut`, matching `New-Shortcut`.
- **Removed:** Aliases `-Group` and `-GroupName` — pass `-Folder`, or `-Name` on `New-StartMenuProgramsFolder`.
- **Removed:** Aliases `-AppName` and `-Folder` on `New-StartMenuProgramsFolder` — pass `-Name`.
- **Removed:** Aliases `-App` and `-AppName` on the shortcut functions — pass `-Name`.
- **Changed:** `Remove-StartMenuShortcut` reports missing shortcut with error id `ShortcutNotFound`, category and target.
- **Changed:** `-Name` is positional on `New-StartMenuShortcut`, `New-PowershellStartMenuShortcut` and `New-StartMenuProgramsFolder`, matching `Remove-StartMenuShortcut`.
- **Changed:** `-Target` on `New-StartMenuShortcut` and `-Command` on `New-PowershellStartMenuShortcut` are positional.
- **Changed:** Start Menu Programs folder resolved per call, so a folder relocated during session is picked up.
- **Changed:** `Get-StartMenuProgramsPath` renamed to `Get-StartMenuProgramsLocation`.
- **Fixed:** `-AllUsers` write elevates through User Account Control when not administrator, instead of failing with access denied. Folder and shortcut are created in one elevated session.
- **Added:** `-AllUsers` write reports Windows sudo missing, disabled or forbidden in inline mode before creating or removing anything.

### Shortcut
- **Added:** `New-Shortcut` — creates shortcut at any location and returns it; only `-Location` and `-Target` mandatory, run location defaults to folder of target, `-Force` performs complete overwrite.
- **Added:** `Set-Shortcut` — sets any combination of shortcut fields, returns shortcut with `-PassThru`; `$null` or empty string clears a field.
- **Added:** `-CreateFolder` on `New-Shortcut` — creates folder of shortcut when missing; without it, missing folder is reported as error.
- **Added:** `Get-Shortcut` — every readable field of a shortcut as one record: `Location`, `Target`, `Arguments`, `RunLocation`, `Description`, `Icon`, `Hotkey`, `WindowStyle`, `Elevated`; missing shortcut reported as `ShortcutNotFound`.
- **Added:** `Icon` as `ShortcutIcon` record — `Location` and `Index`, combined back by `ToString()`; `$null` when shortcut carries no icon.
- **Added:** `WindowStyle` as `ShortcutWindowStyle` enum — `Normal`, `Maximized`, `Minimized`.
- **Removed:** `Get-ShortcutIconLocation` — read `Get-Shortcut` instead.
- **Removed:** `Set-ShortcutTarget` — pass `-Target` to `Set-Shortcut` instead.
- **Removed:** `Set-ShortcutRunAsAdministrator` — pass `-Elevated` to `Set-Shortcut` instead.

### System PATH and environment variables
- **Changed:** System PATH and environment write functions now default to user scope; pass `-Machine` for machine scope. Administrator privileges no longer required by default.
- **Added:** Table view for system path locations in output of `Get-SystemPath`. 
- **Added:** `-Contains`, `-Filter` and `-Match` on `Get-SystemPath` — literal substring, wildcard pattern, regular expression, each matched against stored value as well as resolved location.
- **Added:** `-Match` on `Get-SystemPath` rejects invalid regular expressions.
- **Added:** `-Exact` (aliases `-Location`, `-Folder`) on `Get-SystemPath` — exact match, case-insensitive, repeated and trailing backslashes ignored.
- **Changed:** Location comparison ignores repeated backslashes anywhere in location, not only trailing ones. Leading `\\` of UNC root kept.
- **Added:** `-Process` on `Get-SystemPath` and `Test-SystemPathLocation` — locations local to current shell, on neither persisted Path.
- **Removed:** `Get-SystemPathLocation` — use `Get-SystemPath -Location`, `-Contains`, `-Filter` or `-Match`.
- **Changed:** positional parameter: `-Contains` replaces `-Filter` / `-Location`, use `path Git`, `-Filter "*Git*"` or `-Match ".*Git.*"`.
- **Changed:** `-Location` on `Test-SystemPathLocation` is mandatory and positional; `-Filter` removed, exact match only.
- **Added:** Alias `testpath` for `Test-SystemPathLocation`.
- **Changed:** `Add-SystemPathLocation`: renamed `-Front` to `-First`. `-Front` stays as an alias.
- **Added:** `Add-SystemPathLocation` reports terminating error `PathLocationNotFound` for location naming no existing folder, checked expanded.
- **Added:** `-Force` on `Add-SystemPathLocation` — adds location naming no existing folder.
- **Removed:** Aliases `-Prepend` and `-Start` on `Add-SystemPathLocation`.
- **Changed:** Warning for location already on or not on system Path names scope.
- **Fixed:** Aliases `addpath` and `rmpath` are exported;
  previously missing from the manifest.
- **Changed:** `Set-EnvironmentVariable` and `Remove-EnvironmentVariable` apply the change to the current process immediately.
- **Added:** `-Expandable` on `Set-EnvironmentVariable` — writes `REG_EXPAND_SZ` so a `%…%` reference stays as indirection; default `REG_SZ`.
- **Added:** `-Expandable` on `Get-EnvironmentVariable` — reads stored expandable value without evaluating `%…%` references.
- **Changed:** System Path operations preserve `%…%` references and persist Path as `REG_EXPAND_SZ`.
- **Added:** `StoredValue` on `SystemPathLocation` — value as persisted, keeping `%…%` references and stray backslashes verbatim.
- **Changed:** `Location` on `SystemPathLocation` holds absolute normalized folder — repeated and trailing backslashes, `.` and `..` segments resolved. Relative location resolved against current directory.
- **Changed:** System Path listing leads with `StoredValue`; resolved `Location` follows on `↳` row where stored value carries `%…%` reference.
- **Added:** Location naming no existing folder rendered in red.
- **Changed:** Process Path carries each location as its scope Path spells it, `%…%` references expanded and nothing else.
- **Changed:** `Add-SystemPathLocation` names resolved location, previously expanded, in `PathLocationNotFound`.
- **Changed:** `Get-SystemPath -Join` returns stored (expandable) locations.
- **Fixed:** Process Path derived from machine and user Path instead of patched, so a location carried by both scopes is listed once per scope and a removal in one scope leaves the other scope's location in place. Locations only the session knows are kept.
- **Added:** `Sync-SystemPath` and alias `syncpath` — rebuild system Path of current shell from persisted Path, for a change made outside easypeasy.
- **Added:** `Get-Environment` — returns environment variables as records carrying scope, name and value; both scopes by default, or `-Machine` / `-User`.
- **Fixed:** `Remove-EnvironmentVariable` deletes registry value instead of leaving empty tombstone.
- **Fixed:** `Get-EnvironmentVariable` takes `-Name` literally in effective scope, no longer matching wildcards or missing names carrying `[` and `]`.
- **Changed:** `-Machine` write operations auto-elevate through User Account Control when not administrator, no longer error. One prompt per command, before either Path is written.
- **Changed:** `Invoke-Elevated` and aliases `sudops`, `sups` force inline execution in the current terminal via `sudo --inline`, and report a terminating error on failure.
- **Added:** `Invoke-Elevated` reports terminating error when sudo not available.
- **Added:** `-Machine` write reports Windows sudo missing, disabled or forbidden in inline mode before reading or writing anything.
- **Changed:** `Add-SystemPathLocation`, `Move-SystemPathLocation` and `Set-EnvironmentVariable -Expandable` name each missing variable of `%...%` reference in warning of its own and use value anyway, keeping reference as indirection. Previously `Add-SystemPathLocation` rejected it as missing folder and reference resolved against current directory.
- **Changed:** Reads and removals stay quiet about `%...%` reference no variable resolves; listing accents it instead.
- **Changed:** Location that does not resolve is matched, selected and deduplicated on its stored value, so `%...%` reference is found, removed and moved by the reference itself.
- **Fixed:** Location carrying unresolved `%...%` reference tagged with its persisted scope on effective read, previously always `Process`.
- **Changed:** `Add-SystemPathLocation` and `Remove-SystemPathLocation` run whole `-Machine` write elevated, so Path is read and written in same session and never crosses elevation boundary.
- **Changed:** `Move-SystemPathLocation` writes target Path before source Path.
- **Fixed:** `Invoke-Elevated` quotes every argument, doubling embedded single quote.
- **Fixed:** `Invoke-Elevated` reports command elevated session cannot resolve, instead of reporting success.
- **Changed:** `Assert-Administrator` renamed to `Assert-Elevated`.
- **Added:** `Test-Elevated` — returns whether the current session is elevated.
- **Added:** Error id, category and target on every reported error.
- **Changed:** `Backup-SystemPath` returns location of backup file.
- **Added:** `-Location` on `Add-`, `Remove-`, `Move-` and `Test-SystemPathLocation` takes locations from pipeline — `path Git | rmpath`.
- **Added:** `-Entry` on `Remove-SystemPathLocation` — takes `SystemPathLocation` from pipeline and removes each from scope it carries, so location on both scopes goes from both.
- **Added:** `-Machine` and `-User` select which piped entries `Remove-SystemPathLocation` removes, rather than where from.
- **Added:** `Remove-SystemPathLocation` drops piped entry of Process scope from Path of current shell, neither persisted scope written.
- **Added:** `-Location` on `Add-`, `Remove-`, `Move-` and `Test-SystemPathLocation` takes several locations, applied in one write per scope and one elevation.
- **Added:** `ToString()` on `SystemPathLocation` returns `StoredValue`, so entry piped to location command names entry itself.
- **Added:** `Invoke-Elevated` passes collection argument on as array argument, quoting each element.
- **Changed:** `Test-SystemPathLocation` takes `-Machine`, `-User` and `-Effective` as parameter sets, matching `Get-SystemPath`.
- **Changed:** `Remove-DuplicateSystemPathLocations` rejects `-KeepMachine` / `-KeepUser` next to a single scope, instead of ignoring them.
- **Fixed:** `Stop-Explorer` treats absent Explorer process as success.

### Scheduled tasks
- **Added:** `-WhatIf` and `-Confirm` on `Register-LogonTask`.
- **Added:** `-Elevated` (alias `-Administrator`) on `Register-LogonTask` — task runs at highest privileges, registration elevates through User Account Control when not administrator; reports Windows sudo missing, disabled or forbidden in inline mode before registering anything.
- **Changed:** `-Name` and `-Executable` on `Register-LogonTask` are mandatory.
- **Fixed:** `Register-LogonTask` registers a task without `-Argument`.

### Theme
- **Removed:** Entire component — `Get-Theme`, `Set-Theme`, `Switch-Theme` and alias `theme`.

### Usage
- **Removed:** Entire component — `Get-Usage` and alias `du`.

### Packaging
- **Changed:** Published package ships only the module files; tests, CI workflows, editor settings and agent instructions staged out.

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
- **`Remove-DuplicateSystemPathLocations`** (alias `cleanpath`) — removes duplicate locations from the system PATH, for the local machine, the current user, or both combined (the default). Within a scope the first occurrence of each location is kept; on a cross-scope duplicate the machine copy is kept by default, or the user copy with `-KeepUser`. Idempotent — no change when there are no duplicates.
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
