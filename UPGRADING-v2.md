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
- **Administrator is no longer required by default.** A `-Machine` **Path or environment** write,
  a Start Menu `-AllUsers` write and `Register-LogonTask -Elevated` auto-elevate through UAC
  (`Invoke-Elevated` → `sudo --inline`), so drop any "run as admin" wrapping and the `Assert-Elevated`
  guard around them. Such writes need the **Windows sudo feature** enabled. A `Register-LogonTask`
  call without `-Elevated` registers a task of the current user and never elevates.

## Renamed commands

| v1 | v2 |
|---|---|
| `Assert-Administrator` | `Assert-Elevated` |
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
| `-IconLocation`, `-IconIndex`, `-IconFile` | shortcut and Start Menu shortcut commands | `-Icon "file,index"`, or `-Icon "file"` for the first icon |
| `-Admin`, `-Elevate` | `New-PowershellStartMenuShortcut` | `-Elevated` (`-Administrator` kept as alias — prefer `-Elevated`) |

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
  takes the icon file, optionally followed by a comma and the index of the icon within it — the
  combined `"file,index"` form v1 `-Icon` took, now with the index optional:

  ```powershell
  New-StartMenuShortcut -Name $Name -Target $exe -Icon "$env:WINDIR\imageres.dll,229"
  New-StartMenuShortcut -Name $Name -Target $exe -Icon $iconLocation
  ```

  The index is read only where digits follow the last comma directly: `"…\imageres.dll, 229"` names
  an icon file called `imageres.dll, 229`. The icon file is taken verbatim, quotes included, so pass
  it unquoted; an icon file whose own name ends in a comma and a number needs `,0` appended. An
  empty or `$null` `-Icon` means no icon, so an optional icon needs no splat guard. An icon read by
  `Get-Shortcut` is accepted as it stands.
- **PowerShell shortcut window.** `-Visible` and `-Maximized` give way to
  `-WindowStyle Normal` / `-WindowStyle Maximized`; the default stays `Minimized`.
- **`Add-SystemPathLocation` rejects a location naming no existing folder** with a terminating
  `PathLocationNotFound`, where v1 persisted whatever string it was given. The location is checked
  expanded. Pass `-Force` where the folder is meant to appear later. The folder has to exist at the
  moment of the call, so a provisioning script putting a folder on the Path before whatever creates it
  has ever run — `%USERPROFILE%\.local\bin`, a package manager's `bin`, a toolchain folder — needs
  `-Force` on every such call. A `%…%` reference whose variable is not set is exempt: it names the
  variable in a warning and is added, the reference staying as indirection.
- **`Test-SystemPathLocation` tests one exact location.** `-Location` is mandatory and positional;
  v1's `-Filter` is gone. A bare call now errors. Reach for `Get-SystemPath -Contains` / `-Filter` /
  `-Match` where a pattern is what the calling code needs.
- **`Register-LogonTask -Name` and `-Executable` are mandatory.** A call omitting either now errors
  instead of registering a task with nothing to run. `-Argument`, `-Path` and `-Force` are as in v1.
- **Scope switches on the Path lookups are parameter sets.** `Get-SystemPath` and
  `Test-SystemPathLocation` take `-Machine`, `-User`, `-Process` or `-Effective` (default); passing two of
  them is a parameter-set error. `Remove-DuplicateSystemPathLocations` likewise rejects `-KeepMachine` / `-KeepUser`
  next to `-Machine` or `-User`, where v2 up to now ignored them.
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
  path. `SystemPathLocation` carries `StoredValue` (the value as persisted) next to `Location`;
  criteria still match on `Location`, but `Get-SystemPath -Join` now returns the stored form.
- **`Location` is the absolute normalized folder.** Repeated and trailing backslashes, `.` and `..`
  segments are resolved, and a relative location is resolved against the current directory, so code
  comparing `Location` against a literal string must compare against the normalized spelling.
  `StoredValue` is where the verbatim value lives.

## Unchanged — leave these call sites alone

- **The location parameter is `-Location`**, mandatory and positional first on `Add-SystemPathLocation`,
  `Remove-SystemPathLocation`, `Move-SystemPathLocation` and `Test-SystemPathLocation`, with `-Folder`
  kept as an alias. All three v1 spellings still bind — `Add-SystemPathLocation "C:\Tools\bin"`,
  `-Location "C:\Tools\bin"`, `-Folder "C:\Tools\bin"` — so only the `-Folder` spelling is worth
  rewriting, to the canonical `-Location`. On `Get-SystemPath` the exact-match parameter is `-Exact`
  (aliases `-Location`, `-Folder`), since its positional argument is `-Contains`.
- **An addition that changes nothing still warns.** `Add-SystemPathLocation` given a location already on
  the Path leaves the Path unchanged and reports `Location is already on the system Path`, as v1 did, so
  `-WarningAction SilentlyContinue` in an idempotent setup script is still doing its job.
  `Remove-SystemPathLocation` and `Move-SystemPathLocation` warn the same way when there is nothing to do.
  The terminating `PathLocationNotFound` is the missing-folder case alone.
- **`Set-EnvironmentVariable` keeps its positional order**: `-Name` first, `-Value` second, so
  `Set-EnvironmentVariable -Machine JAVA_HOME "C:\Java\current"` binds as it did in v1.
  `Get-EnvironmentVariable` and `Remove-EnvironmentVariable` take `-Name` positional first likewise.
- **`Register-LogonTask -Argument`** is unchanged: singular, one string, and passed to the task action
  only when it carries something.

## Removed components — replace entirely

| Removed | Replacement |
|---|---|
| `Get-Theme`, `Set-Theme`, `Switch-Theme`, alias `theme` | none in this module (theme app is separate) |
| `Get-Usage`, alias `du` | `du` from Microsoft [Coreutils for Windows](https://github.com/microsoft/coreutils) |
| `Get-ShortcutIconLocation` | `Get-Shortcut`, then read `.Icon.Location` or `.Icon.Index` |
| `Set-ShortcutTarget` | `Set-Shortcut -Target` |
| `Set-ShortcutRunAsAdministrator` | `Set-Shortcut -Elevated` (and `-Elevated:$false` to clear it) |
| `Get-SystemPathLocation` | `Get-SystemPath -Exact` (alias `-Location`), or `-Contains` / `-Filter` / `-Match` |

## New in v2 — prefer where applicable

- `Get-Shortcut` — every readable field of a shortcut as one record: `Location`, `Target`, `Arguments`,
  `RunLocation`, `Description`, `Icon` (`Location`, `Index`, or `$null` when there is no icon),
  `Hotkey`, `WindowStyle` and `Elevated`.
- `New-Shortcut` — create a shortcut anywhere, not only in the Start Menu, and get it back as a
  record. `-Location` and `-Target` are mandatory; every other field is optional, with the target's
  folder as default run location. `-CreateFolder` creates the folder of the shortcut when it is missing.
- `Set-Shortcut` — set any combination of fields on an existing shortcut; `$null` or an empty string
  clears a field, `-Elevated:$false` clears the "Run as administrator" flag, `-PassThru` returns the
  shortcut. `-Location` names the shortcut, mandatory and positional first, mirroring `New-Shortcut`;
  v1's `-Shortcut` is gone. It takes no pipeline input — `Get-Shortcut … | Set-Shortcut -Elevated` fails
  on the missing mandatory `-Location` — so pass the location:
  `Set-Shortcut "$(Get-StartMenuProgramsLocation)\App.lnk" -Elevated`.
- `Get-Environment` — environment variables as records (scope, name, value); both scopes by default,
  or `-Machine` / `-User`.
- `Test-Elevated` — whether the current session is elevated.
- `Set-EnvironmentVariable -Expandable` — write an expandable (`REG_EXPAND_SZ`) value so a `%…%`
  reference stays as indirection; without it the value is written verbatim as `REG_SZ`.
- `Get-EnvironmentVariable -Expandable` — read the stored expandable value without evaluating its
  `%…%` references.
- `-Contains` / `-Filter` / `-Match` on `Get-SystemPath` — literal substring, wildcard, regular
  expression. `-Exact` (alias `-Location`) matches exactly, `-Process` narrows to the locations local
  to the current shell.
- `Sync-SystemPath` (alias `syncpath`) — rebuild the system Path of the current shell from the
  machine and the user Path, for a change made outside easypeasy.
- **`-Location` from the pipeline** on `Add-SystemPathLocation`, `Remove-SystemPathLocation`,
  `Move-SystemPathLocation` and `Test-SystemPathLocation`, so a read feeds a write directly:
  `Get-SystemPath -Contains Git | Remove-SystemPathLocation`. An entry pipes as the value it
  stores, an unresolved `%…%` reference included. `-Location` takes several locations either way, applied
  in one write per scope and behind one elevation prompt; inside `ForEach-Object` pass `$_` as v1 did.
- **`Remove-SystemPathLocation` takes the scope from a piped entry** through its `-Entry` parameter, so
  `Get-SystemPath -Contains Git | Remove-SystemPathLocation` removes each entry from the scope it lives
  on — from both scopes where an effective read found it on both, and from the current shell's Path alone
  where the entry is process-only. `-Machine` and `-User` then select which entries are removed rather
  than where from. A location given as text is unaffected: it still goes to the scope the switches name,
  the current user by default. Inside `ForEach-Object` pass `-Entry $_` to keep the scope; a bare `$_`
  arrives as the location alone.
