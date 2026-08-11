---
name: easypeasy
description: Administer Windows from PowerShell with the easypeasy module - read and change the system Path, environment variables, shortcuts, Start Menu entries and logon tasks, and run a command as administrator. Use when a task touches PATH, %Path%, a machine or user environment variable, a .lnk shortcut, a Start Menu program entry, a run-at-logon task, elevation, sudo on Windows, a special folder such as Program Files, Documents or Desktop, or when a command name or alias from this module appears (path, addpath, rmpath, testpath, deduppath, cleanpath, movepath, syncpath, getenv, setenv, rmenv, sudops, sups, programs, docs, desktop, sx, time).
---

# easypeasy

PowerShell 7 module for Windows system administration.
29 exported functions and 18 aliases, grouped by domain.

## Requirements

- PowerShell 7.4 or later, Windows.
- Machine scope writes need Sudo for Windows in inline mode: `sudo config --enable normal`.
  User scope works without it.

## Import

```powershell
Install-Module easypeasy      # from PowerShell Gallery
Import-Module easypeasy
```

Working on the module source itself: `Import-Module .\easypeasy.psd1 -Force`.

## Command index

Read the reference file of a domain before writing a command from it.
Files live in `references/` next to this file.

| Domain | Commands | Reference |
| --- | --- | --- |
| System Path | `Get-SystemPath` `Sync-SystemPath` `Add-SystemPathLocation` `Remove-SystemPathLocation` `Test-SystemPathLocation` `Remove-DuplicateSystemPathLocations` `Optimize-SystemPath` `Move-SystemPathLocation` `Backup-SystemPath` | `references/systempath.md` |
| Environment variables | `Get-EnvironmentVariable` `Set-EnvironmentVariable` `Remove-EnvironmentVariable` `Get-Environment` | `references/environment.md` |
| Shortcuts | `Get-Shortcut` `New-Shortcut` `Set-Shortcut` | `references/shortcut.md` |
| Start Menu | `New-StartMenuShortcut` `Remove-StartMenuShortcut` `New-PowershellStartMenuShortcut` `Get-StartMenuProgramsLocation` `New-StartMenuProgramsFolder` | `references/startmenu.md` |
| Logon tasks | `Register-LogonTask` | `references/task.md` |
| Elevation | `Test-Elevated` `Assert-Elevated` `Invoke-Elevated` | `references/elevate.md` |
| Utilities | `Get-Timestamp` `Get-ProgramFilesFolder` `Get-MyDocumentsFolder` `Get-DesktopFolder` `Stop-Explorer` | `references/utility.md` |

## Aliases

| Alias | Command | Alias | Command |
| --- | --- | --- | --- |
| `path` | `Get-SystemPath` | `getenv` | `Get-EnvironmentVariable` |
| `syncpath` | `Sync-SystemPath` | `setenv` | `Set-EnvironmentVariable` |
| `addpath` | `Add-SystemPathLocation` | `rmenv` | `Remove-EnvironmentVariable` |
| `rmpath` | `Remove-SystemPathLocation` | `sudops` | `Invoke-Elevated` |
| `testpath` | `Test-SystemPathLocation` | `sups` | `Invoke-Elevated` |
| `deduppath` | `Remove-DuplicateSystemPathLocations` | `programs` | `Get-ProgramFilesFolder` |
| `cleanpath` | `Optimize-SystemPath` | `docs` | `Get-MyDocumentsFolder` |
| `movepath` | `Move-SystemPathLocation` | `desktop` | `Get-DesktopFolder` |
| `time` | `Get-Timestamp` | `sx` | `Stop-Explorer` |

Aliases are for the terminal. Write the `Verb-Noun` name in a script.

## Rules across all domains

**Scope.** A read offers `-Machine`, `-User` and a default `-Effective`, the value the current
process sees. A write offers `-Machine` and `-User`, and `-User` is the default.
Start Menu commands name the same split `-AllUsers` and `-User`.
Never assume machine scope: `-User` is what runs without a prompt.

**Elevation.** A `-Machine` or `-AllUsers` write elevates itself through one UAC prompt
and runs inline in the current terminal, then syncs the calling process.
Do not wrap such a command in `Invoke-Elevated` — it prompts twice.
`Invoke-Elevated` is for commands outside this module.

**`-WhatIf` and `-Confirm`.** Every state-changing command supports both.
Offer `-WhatIf` first where a change is wide, e.g. `cleanpath -WhatIf`.

**Pipeline.** Location parameters take arrays and pipeline input, and a command
collects a batch into one write per scope, so one prompt covers the batch.
Pass the whole list rather than looping a command per item.

**Errors.** A failure carries an `-ErrorId`, e.g. `ShortcutAlreadyExists`, and a target object.
Catch on `$_.FullyQualifiedErrorId`, not on message text.
