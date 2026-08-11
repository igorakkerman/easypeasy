# System Path

The system Path is the `PATH` environment variable in three scopes:
`Machine` and `User` are persisted in the registry, `Process` lives in the current shell.
A read returns `SystemPathLocation` records with `Scope`, `StoredValue` and `Location`.
`StoredValue` is the value as persisted, `Location` the folder it resolves to;
for an unresolved `%...%` reference `Location` is empty.

Every write keeps `$env:PATH` of the current process and the registry value in sync.
Comparison of locations ignores repeated and trailing backslashes, and is case-insensitive.

## Get-SystemPath (path)

```powershell
path                                  # -Effective: all scopes, in order of precedence
path -Machine                         # one scope: -Machine, -User, -Process
path -Join                            # semicolon-separated string, as stored
path windows                          # -Contains: literal substring, case-insensitive
path Git Program                      # several criteria, all must be met
path -Exact "C:\Program Files\Git\bin"   # whole location, aliases -Location, -Folder
path -Filter "*\Git\*"                # wildcard
path -Match "\\Git\\(cmd|bin)$"        # regular expression
```

`-Contains` is positional and takes the remaining arguments.
`-Exact` compares locations. `-Contains`, `-Filter` and `-Match` search both forms of an
entry, the stored value and the resolved location, either one satisfying the criterion.

The listing marks folders that do not exist, in red by default.
`EASYPEASY_USE_COLORS` (default `true`) and `EASYPEASY_USE_WARNING_SYMBOL` (default `false`)
switch the marks.

## Test-SystemPathLocation (testpath)

```powershell
testpath "C:\Program Files\Git\bin"             # -Effective, default
testpath "C:\Tools" -Machine                    # -Machine, -User, -Process
"C:\Tools", "C:\Other" | testpath               # one boolean per location
```

Always the whole location, case-insensitive. No substring, no wildcard.

## Add-SystemPathLocation (addpath)

```powershell
addpath "C:\Program Files\MyApp"                # -User, default
addpath "C:\Program Files\MyApp" -Machine       # elevates
addpath "C:\Tools\bin" -First                   # searched first, alias -Front
addpath "%JAVA_HOME%\bin"                       # expandable reference, stored as written
addpath "C:\Tools\NotYet" -Force                # add folder that does not exist
"C:\MyApp", "C:\OtherApp" | addpath             # one write for the batch
```

A location that does not exist is rejected; `-Force` adds it anyway.
A `%...%` reference the process environment does not set is added and raises a warning per
missing variable, naming it.

## Remove-SystemPathLocation (rmpath)

```powershell
rmpath "C:\Program Files\MyApp"                 # every occurrence in -User, default
rmpath "C:\MyApp", "C:\OtherApp"                # one write
rmpath "C:\Program Files\Git\bin" -Machine      # elevates
path MyApp | rmpath                             # -Entry: each from the scope it lives on
path MyApp | rmpath -User                       # only the user scope entries
```

Piping records from `Get-SystemPath` binds `-Entry` and carries each entry's scope,
so a pipeline covering both scopes elevates once for the machine part.

## Remove-DuplicateSystemPathLocations (deduppath)

```powershell
deduppath                # both scopes, machine copy kept on overlap, default
deduppath -KeepUser      # both scopes, user copy kept on overlap
deduppath -Machine       # machine Path only
deduppath -User          # user Path only, no elevation
```

Within a scope the first occurrence is kept.

## Optimize-SystemPath (cleanpath)

```powershell
cleanpath -WhatIf
cleanpath
```

Cleans both scopes. Today it removes duplicates, keeping the machine copy on overlap.
Later versions do more. Call the single-purpose command where the exact steps matter.

## Move-SystemPathLocation (movepath)

```powershell
movepath "C:\Program Files\Git\bin" -ToUser     # machine -> user
movepath "C:\Tools\bin" -ToMachine              # user -> machine
"C:\Tools\bin", "C:\Other\bin" | movepath -ToUser   # one prompt for the batch
```

Both directions touch the machine Path, so both elevate.

## Sync-SystemPath (syncpath)

```powershell
syncpath
```

Rebuilds the Path of the current shell from the persisted scopes, the way a fresh shell does.
Picks up a change made in Windows settings, another shell or an installer.
A location removed elsewhere stays, as a `Process` entry.
The other Path commands sync by themselves.

## Backup-SystemPath

```powershell
Backup-SystemPath
```

Writes the effective Path to a file in the temp folder and returns its path.
