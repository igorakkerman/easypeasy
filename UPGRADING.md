# Upgrading easypeasy v1 → v2

Instructions for migrating code that **calls** `easypeasy` from v1 to v2.
Apply every rename and behavior change below. When more than one spelling exists, always
write the **canonical** name, never an alias.

## Principles

- **Prefer full command names over aliases** in scripts: `Get-SystemPath`, not `path`;
  `Add-SystemPathLocation`, not `addpath`; `Set-EnvironmentVariable`, not `setenv`.
- **Prefer canonical parameter names over aliases**: `-First` not `-Front`, `-Folder` not the
  removed group aliases, `-Shortcut` not `-Path`, `-Name` not the removed app aliases.
- **User scope is the default now.** Path and environment writes target the current user; pass
  `-Machine` only when a machine-wide change is intended. Do not add `-Machine` by reflex.
- **Administrator is no longer required by default.** A `-Machine` write auto-elevates through
  UAC (`Invoke-Elevated` → `sudo --inline`), so drop any "run as admin" wrapping around user-scope
  calls. Machine-scope writes need the **Windows sudo feature** enabled.

## Renamed commands

| v1 | v2 |
|---|---|
| `Assert-Administrator` | `Assert-Elevated` |
| `Get-StartMenuProgramsPath` | `Get-StartMenuProgramsLocation` |

## Renamed parameters

| Command | v1 parameter | v2 parameter |
|---|---|---|
| `Set-ShortcutRunAsAdministrator` | `-ShortcutPath` (alias `-Path`) | `-Shortcut` |
| `Add-SystemPathLocation` | `-Front` | `-First` (`-Front` kept as alias — prefer `-First`) |

## Removed parameters and aliases → use the canonical name

| Removed | Command(s) | Use instead |
|---|---|---|
| `-App`, `-AppName` | `New-StartMenuShortcut`, `New-PowershellStartMenuShortcut` | `-Name` |
| `-AppName`, `-Folder` (as name aliases) | `New-StartMenuProgramsFolder` | `-Name` |
| `-Group`, `-GroupName` | Start Menu shortcut commands | `-Folder` (or `-Name` on `New-StartMenuProgramsFolder`) |
| `-Prepend`, `-Start` | `Add-SystemPathLocation` | `-First` |
| `removepath` alias | `Remove-SystemPathLocation` | `rmpath`, or the full name |
| `deduppath` alias | `Remove-DuplicateSystemPathLocations` | `cleanpath`, or the full name |

## Changed behavior — review call sites

- **Start Menu scope.** All Start Menu commands target the current user by default. For the old
  All Users behavior pass `-AllUsers` (aliases `-Machine`, `-All`; prefer `-AllUsers`).
- **Start Menu shortcut layout.** `New-StartMenuShortcut` / `Remove-StartMenuShortcut` place the
  shortcut at `<Programs>\<Name>.lnk` when `-Folder` is omitted (v1 nested it as
  `<Programs>\<Name>\<Name>.lnk`). Pass `-Folder` to keep a containing folder.
- **`New-StartMenuShortcut -Name` is mandatory** and is no longer inferred from `-Executable`.
- **Shortcut icon.** `-Icon` now takes a combined `"file,index"` (e.g. `-Icon "C:\App\App.exe,3"`);
  a plain icon-file path goes to `-IconLocation`. `-Icon` is mutually exclusive with
  `-IconLocation` / `-IconIndex`. Pick the icon index with `-IconIndex` (default `0`).
- **`Get-SystemPathLocation` and `Test-SystemPathLocation` require a criterion** — at least one of
  `-Location`, `-Contains`, `-Filter`, `-Match`. A bare call now errors.
- **Positional path/query argument is `-Contains`** (literal substring), replacing v1 positional
  `-Filter` / `-Location`: `Get-SystemPath Git`, or `-Filter "*Git*"`, or `-Match ".*Git.*"`.
- **Environment writes apply immediately.** `Set-EnvironmentVariable` / `Remove-EnvironmentVariable`
  update the current process at once; remove any manual `$env:` re-sync that followed them.
- **`Remove-EnvironmentVariable` deletes the registry value** instead of leaving an empty string.
- **`Invoke-Elevated` (aliases `sudops`, `sups`) runs inline** via `sudo --inline` and raises a
  terminating error on failure or when sudo is unavailable.

## Removed components — replace entirely

| Removed | Replacement |
|---|---|
| `Get-Theme`, `Set-Theme`, `Switch-Theme`, alias `theme` | none in this module (theme app is separate) |
| `Get-Usage`, alias `du` | `du` from Microsoft [Coreutils for Windows](https://github.com/microsoft/coreutils) |
| `Get-ShortcutIconLocation` | `Get-Shortcut`, then read `.Icon.Value`, `.Icon.Location` or `.Icon.Index` |

## New in v2 — prefer where applicable

- `Get-Shortcut` — every readable field of a shortcut as one record: `Shortcut`, `Target`, `Arguments`,
  `StartIn`, `Description`, `Icon` (`Value`, `Location`, `Index`, or `$null` when there is no icon),
  `Hotkey`, `WindowStyle` and `RunAsAdministrator`.
- `Get-Environment` — environment variables as records (scope, name, value); both scopes by default,
  or `-Machine` / `-User`.
- `Test-Elevated` — whether the current session is elevated.
- `Set-EnvironmentVariable -Expand` — write an expandable (`REG_EXPAND_SZ`) value so a `%…%`
  reference stays as indirection; without it the value is written verbatim as `REG_SZ`.
- `-Contains` / `-Filter` / `-Match` on `Get-SystemPath`, `Get-SystemPathLocation`,
  `Test-SystemPathLocation` — literal substring, wildcard, regular expression.
