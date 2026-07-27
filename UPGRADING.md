# Upgrading easypeasy v1 → v2

Instructions for migrating code that **calls** `easypeasy` from v1 to v2.
Apply every rename and behavior change below. When more than one spelling exists, always
write the **canonical** name, never an alias.

## Principles

- **Prefer full command names over aliases** in scripts: `Get-SystemPath`, not `path`;
  `Add-SystemPathLocation`, not `addpath`; `Set-EnvironmentVariable`, not `setenv`.
- **Prefer canonical parameter names over aliases**: `-First` not `-Front`, `-Folder` not the
  removed group aliases, `-Name` not the removed app aliases.
- **User scope is the default now.** Path and environment writes target the current user; pass
  `-Machine` only when a machine-wide change is intended. Do not add `-Machine` by reflex.
- **Administrator is no longer required by default.** A `-Machine` write auto-elevates through
  UAC (`Invoke-Elevated` → `sudo --inline`), so drop any "run as admin" wrapping around user-scope
  calls. Machine-scope writes need the **Windows sudo feature** enabled.

## Renamed commands

| v1 | v2 |
|---|---|
| `Assert-Administrator` | `Assert-Elevation` |
| `Get-StartMenuProgramsPath` | `Get-StartMenuProgramsLocation` |

## Renamed parameters

| Command | v1 parameter | v2 parameter |
|---|---|---|
| `Add-SystemPathLocation` | `-Front` | `-First` (`-Front` kept as alias — prefer `-First`) |
| `New-StartMenuShortcut` | `-Executable` | `-Target` |
| `New-PowershellStartMenuShortcut` | `-RunAsAdministrator` | `-Elevated` |
| `New-PowershellStartMenuShortcut` | `-Visible`, `-Maximized` | `-WindowStyle Normal` / `-WindowStyle Maximized` |

## Removed parameters and aliases → use the canonical name

| Removed | Command(s) | Use instead |
|---|---|---|
| `-App`, `-AppName` | `New-StartMenuShortcut`, `New-PowershellStartMenuShortcut` | `-Name` |
| `-AppName`, `-Folder` (as name aliases) | `New-StartMenuProgramsFolder` | `-Name` |
| `-Group`, `-GroupName` | Start Menu shortcut commands | `-Folder` (or `-Name` on `New-StartMenuProgramsFolder`) |
| `-Prepend`, `-Start` | `Add-SystemPathLocation` | `-First` |
| `removepath` alias | `Remove-SystemPathLocation` | `rmpath`, or the full name |
| `deduppath` alias | `Remove-DuplicateSystemPathLocations` | `cleanpath`, or the full name |
| `-IconLocation`, `-IconIndex`, `-IconFile` | shortcut and Start Menu shortcut commands | `-Icon (New-ShortcutIcon -Location … -Index …)` |
| `-Administrator`, `-Admin`, `-Elevate` | `New-PowershellStartMenuShortcut` | `-Elevated` |

## Changed behavior — review call sites

- **Start Menu scope.** All Start Menu commands target the current user by default. For the old
  All Users behavior pass `-AllUsers` (aliases `-Machine`, `-All`; prefer `-AllUsers`).
- **Start Menu shortcut layout.** `New-StartMenuShortcut` / `Remove-StartMenuShortcut` place the
  shortcut at `<Programs>\<Name>.lnk` when `-Folder` is omitted (v1 nested it as
  `<Programs>\<Name>\<Name>.lnk`). Pass `-Folder` to keep a containing folder.
- **`New-StartMenuShortcut -Name` is mandatory** and is no longer inferred from the target.
- **Start Menu shortcut parameters.** `New-StartMenuShortcut` and `New-PowershellStartMenuShortcut`
  build on `New-Shortcut` and take its parameters: `-Target`, `-Arguments`, `-RunLocation`,
  `-Description`, `-Icon`, `-Hotkey`, `-WindowStyle`, `-Elevated`, `-Force`. Run location defaults to
  the folder of the target.
- **Start Menu shortcut return value.** Both return the `Shortcut` record `New-Shortcut` produces, not
  the `.lnk` path string. Read `.Location` where the path is what the calling code needs.
- **Shortcut icon.** On `New-Shortcut`, `Set-Shortcut` and the Start Menu shortcut commands, `-Icon`
  takes a `ShortcutIcon` and nothing else. Build one with `New-ShortcutIcon`, or pass one read by
  `Get-Shortcut`.
- **PowerShell shortcut window.** `-Visible` and `-Maximized` give way to
  `-WindowStyle Normal` / `-WindowStyle Maximized`; the default stays `Minimized`.
- **`Get-SystemPathLocation` and `Test-SystemPathLocation` require a criterion** — at least one of
  `-Location`, `-Contains`, `-Filter`, `-Match`. A bare call now errors.
- **`Register-LogonTask -Name` and `-Executable` are mandatory.** A call omitting either now errors
  instead of registering a task with nothing to run.
- **Errors carry an error id, a category and a target.** Code discriminating on message text should match
  on `FullyQualifiedErrorId` instead, e.g. `ShortcutNotFound`, `ElevationRequired`, `SudoNotAvailable`.
- **Positional path/query argument is `-Contains`** (literal substring), replacing v1 positional
  `-Filter` / `-Location`: `Get-SystemPath Git`, or `-Filter "*Git*"`, or `-Match ".*Git.*"`.
- **Environment writes apply immediately.** `Set-EnvironmentVariable` / `Remove-EnvironmentVariable`
  update the current process at once; remove any manual `$env:` re-sync that followed them.
- **`Remove-EnvironmentVariable` deletes the registry value** instead of leaving an empty string.
- **`Invoke-Elevated` (aliases `sudops`, `sups`) runs inline** via `sudo --inline` and raises a
  terminating error on failure or when sudo is unavailable.
- **System Path keeps `%…%` references.** A persisted Path is read and written in its stored form and
  saved as `REG_EXPAND_SZ`, so editing it no longer freezes `%SystemRoot%\system32` to its expanded
  path. `SystemPathLocation` carries `ExpandableLocation` (stored) next to `Location` (expanded);
  criteria still match on `Location`, but `Get-SystemPath -Join` now returns the stored form.

## Removed components — replace entirely

| Removed | Replacement |
|---|---|
| `Get-Theme`, `Set-Theme`, `Switch-Theme`, alias `theme` | none in this module (theme app is separate) |
| `Get-Usage`, alias `du` | `du` from Microsoft [Coreutils for Windows](https://github.com/microsoft/coreutils) |
| `Get-ShortcutIconLocation` | `Get-Shortcut`, then read `.Icon.Location` or `.Icon.Index` |
| `Set-ShortcutTarget` | `Set-Shortcut -Target` |
| `Set-ShortcutRunAsAdministrator` | `Set-Shortcut -Elevated` (and `-Elevated:$false` to clear it) |

## New in v2 — prefer where applicable

- `Get-Shortcut` — every readable field of a shortcut as one record: `Location`, `Target`, `Arguments`,
  `RunLocation`, `Description`, `Icon` (`Location`, `Index`, or `$null` when there is no icon),
  `Hotkey`, `WindowStyle` and `Elevated`.
- `New-Shortcut` — create a shortcut anywhere, not only in the Start Menu, and get it back as a
  record. `-Location` and `-Target` are mandatory; every other field is optional, with the target's
  folder as default run location. `-CreateFolder` creates the folder of the shortcut when it is missing.
- `Set-Shortcut` — set any combination of fields on an existing shortcut; `$null` or an empty string
  clears a field, `-Elevated:$false` clears the "Run as administrator" flag, `-PassThru` returns the
  shortcut.
- `New-ShortcutIcon` — build the `ShortcutIcon` that `-Icon` takes, from `-Location` and an optional
  `-Index` (default `0`), or from a combined `-Value` `"file,index"`.
- `Get-Environment` — environment variables as records (scope, name, value); both scopes by default,
  or `-Machine` / `-User`.
- `Test-Elevation` — whether the current session is elevated.
- `Set-EnvironmentVariable -Expandable` — write an expandable (`REG_EXPAND_SZ`) value so a `%…%`
  reference stays as indirection; without it the value is written verbatim as `REG_SZ`.
- `Get-EnvironmentVariable -Expandable` — read the stored expandable value without evaluating its
  `%…%` references.
- `-Contains` / `-Filter` / `-Match` on `Get-SystemPath`, `Get-SystemPathLocation`,
  `Test-SystemPathLocation` — literal substring, wildcard, regular expression.
- `Sync-SystemPath` (alias `syncpath`) — rebuild the system Path of the current shell from the
  machine and the user Path, for a change made outside easypeasy.
