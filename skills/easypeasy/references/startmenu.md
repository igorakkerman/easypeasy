# Start Menu

Entries under Start Menu > Programs, for the current user (default) or for all users.
`-AllUsers` (aliases `-Machine`, `-All`) writes the machine location and elevates through one
UAC prompt, covering the containing folder and the shortcut.

Every field of `New-Shortcut` is available here; see `references/shortcut.md`.

## New-StartMenuShortcut

```powershell
New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe"
New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe" -Folder MyCompany
New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe" -AllUsers
New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe" `
    -Arguments "-Debug" -RunLocation "C:\Data" -Description "My favorite app" `
    -Icon "C:\Program Files\MyApp\MyApp.exe,3" -Hotkey "Ctrl+Alt+M" `
    -WindowStyle Maximized -Elevated -Force
```

`-Name` and `-Target` are mandatory and positional.
`-Folder` names a containing folder under Programs, created where it is missing.
An existing shortcut reports `ShortcutAlreadyExists` unless `-Force` overwrites it,
and that check runs before the UAC prompt.

Returns the created shortcut, nothing under `-WhatIf`.

## New-PowershellStartMenuShortcut

```powershell
New-PowershellStartMenuShortcut -Name "Kill Node.js" -Command "Stop-Process -Name node -Force"
New-PowershellStartMenuShortcut -Name "Run System Update" -Script "C:\Scripts\system-update.ps1" `
    -KeepOpen -WindowStyle Maximized -Elevated
```

Runs a PowerShell command from the shortcut.
`-Name` and `-Command` are mandatory and positional; `-Script` is an alias of `-Command`.
`-KeepOpen` (alias `-NoExit`) leaves the window open after the command finishes.
`-WindowStyle` defaults to `Minimized` here.
`-Elevated` ticks "Run as administrator" on the shortcut.

Returns the created shortcut, nothing under `-WhatIf`.

## Remove-StartMenuShortcut

```powershell
Remove-StartMenuShortcut MyApp
Remove-StartMenuShortcut MyApp -Folder MyCompany
Remove-StartMenuShortcut MyApp -AllUsers
```

Removes the containing folder too where it becomes empty.

## Get-StartMenuProgramsLocation

```powershell
Get-StartMenuProgramsLocation             # current user
Get-StartMenuProgramsLocation -AllUsers   # all users
```

Returns the Programs folder as a string. Needs no elevation in either scope.

## New-StartMenuProgramsFolder

```powershell
New-StartMenuProgramsFolder MyCompany
New-StartMenuProgramsFolder MyCompany -AllUsers
```

Creates a folder under Programs. The shortcut commands create a missing `-Folder` themselves,
so call this only for a folder wanted on its own.
