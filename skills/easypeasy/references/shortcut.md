# Shortcuts

Shortcut files (`.lnk`) anywhere on disk.
For Start Menu entries use the Start Menu commands, which resolve the location themselves:
see `references/startmenu.md`.

## Get-Shortcut

```powershell
Get-Shortcut "C:\Users\me\Desktop\MyApp.lnk"
```

Returns a record with `Location`, `Target`, `Arguments`, `RunLocation`, `Description`,
`Icon`, `Hotkey`, `WindowStyle` and `Elevated`.

`Icon` splits into `Location` and `Index`, and is `$null` where the shortcut carries none.
Its `ToString()` returns the `file,index` form a shortcut stores.

`WindowStyle` is `Normal`, `Maximized` or `Minimized`.

## New-Shortcut

```powershell
New-Shortcut "C:\Users\me\Desktop\MyApp.lnk" "C:\Program Files\MyApp\MyApp.exe"

New-Shortcut `
    -Location "C:\Users\me\Desktop\MyApp.lnk" `
    -Target "C:\Program Files\MyApp\MyApp.exe" `
    -Arguments "--profile Default" `
    -RunLocation "C:\Users\me\Documents" `
    -Description "My favorite app" `
    -Icon "C:\Windows\imageres.dll,229" `
    -Hotkey "Ctrl+Alt+M" `
    -WindowStyle Maximized `
    -Elevated `
    -CreateFolder `
    -Force
```

`-Location` and `-Target` are mandatory and positional.
`-RunLocation` defaults to the folder of the target executable.
`-Icon` takes a file, or `file,index` to pick an icon within it.
`-Elevated` (alias `-Administrator`) marks the shortcut to run as administrator.
`-CreateFolder` creates a missing parent folder; without it a missing folder fails the command,
under `-WhatIf` as well.
`-Force` overwrites an existing shortcut; without it the command reports `ShortcutAlreadyExists`.

Returns the created shortcut.

## Set-Shortcut

```powershell
Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Target "C:\Program Files\MyApp\MyApp.exe" -WindowStyle Maximized
Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Elevated:$false
Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Arguments $null -Hotkey '' -Icon $null
Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -WindowStyle Minimized -PassThru
```

Changes the fields given, leaving the others as they are.
`$null` or an empty string clears a field.
`-PassThru` returns the shortcut after the change; without it the command returns nothing.
