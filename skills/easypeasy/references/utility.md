# Utilities

## Get-Timestamp (time)

```powershell
time                                                  # 2024-01-01_20.15.00
& .\system-update.ps1 > "$env:TEMP\update-$(time).log"
```

Current date and time as a string safe in a file name.

## Get-ProgramFilesFolder (programs), Get-MyDocumentsFolder (docs), Get-DesktopFolder (desktop)

```powershell
programs      # C:\Program Files
docs          # C:\Users\me\Documents
desktop       # C:\Users\me\Desktop
```

Each returns the folder as a string, resolved for the current user.
Use them instead of composing a path from `$env:USERPROFILE`, which misses a relocated folder.

## Stop-Explorer (sx)

```powershell
sx
```

Stops Windows Explorer, which Windows generally restarts by itself.
Supports `-WhatIf` and `-Confirm`.
