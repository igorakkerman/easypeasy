# Logon tasks

## Register-LogonTask

```powershell
Register-LogonTask -Name Syncthing `
    -Executable "$env:LOCALAPPDATA\Programs\Syncthing\syncthing.exe" `
    -Argument "--no-console" `
    -Path "\Startup"

Register-LogonTask -Name "Process Explorer" `
    -Executable "$env:LOCALAPPDATA\Microsoft\WindowsApps\procexp.exe" `
    -Argument "/t" `
    -Elevated -Force
```

Registers a scheduled task that runs when the current user logs on.
The task starts when available, runs on batteries and has no execution time limit.

| Parameter | Meaning |
| --- | --- |
| `-Name` | Task name. Mandatory. |
| `-Executable` | Location of the executable. Mandatory. |
| `-Argument` | Single argument string passed to the executable. |
| `-Path` | Folder in the task scheduler. Default `\`. |
| `-Elevated` | Highest privileges available to the user, as "Run with highest privileges". Alias `-Administrator`. |
| `-Force` | Overwrite an existing task. |

A task running with the logon privileges of the current user needs no administrator rights.
`-Elevated` does: it elevates the registration itself through one UAC prompt.

Returns nothing. Supports `-WhatIf` and `-Confirm`.
