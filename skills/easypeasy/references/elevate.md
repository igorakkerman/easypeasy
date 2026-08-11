# Elevation

Elevation runs through Sudo for Windows in inline mode (`sudo --inline`):
the elevated command runs in the current terminal after a User Account Control dialog.
Inline mode has to be allowed in Settings and by group policy: `sudo config --enable normal`.
A command that cannot elevate fails up front with `SudoNotAvailable`,
`SudoInlineNotAllowed` or `SudoModeInvalid`, before it reads or writes anything.

## Test-Elevated

```powershell
Test-Elevated                                  # $true in an elevated session
if (-not (Test-Elevated)) { ... }
```

Returns a boolean, for a script offering an unelevated path.

## Assert-Elevated

```powershell
Assert-Elevated
```

Terminating error `ElevationRequired` where the session is not elevated,
for a command with no unelevated path. Passes silently otherwise.

## Invoke-Elevated (sudops, sups)

```powershell
sudops New-Item -ItemType Directory "C:\Program Files\MyTool"
sups Restart-Service -Name Spooler
Invoke-Elevated Remove-Item -Recurse "C:\Program Files\OldTool"
```

Takes the command and its arguments exactly as typed at the prompt, from position 0 and the
remaining arguments. Waits for the command and reports a terminating error where it fails —
a terminating error or a non-zero exit code.

The command name and anything written as `-Parameter` pass through as typed.
Every other argument is single-quoted, so whitespace, semicolons and quotes stay literal.
A collection argument is quoted element by element and joined with commas,
so it arrives as one array argument.

Do not use it on an easypeasy command that elevates by itself — `-Machine`, `-AllUsers`
and `Register-LogonTask -Elevated` already prompt once and sync the calling process.
`Invoke-Elevated` is for commands outside the module.
