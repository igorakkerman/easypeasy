# <img src="logo.png" alt="easypeasy logo" width="64" /> easy𝓅ea𝓈y



**Productivity boost for Windows using PowerShell**

The *easypeasy* PowerShell module simplifies and automates common tasks in Windows environments:
- manage locations on the system Path
- manage environment variables
- create, read and change (start menu) shortcuts
- run a PowerShell command as administrator (sudo)
- easily restart Windows Explorer
- output timestamps
- create scheduled tasks
- locate special folders

___
## Examples
🅰️ = elevates the process through a UAC prompt

### System Path
#### List the folders in the system Path

in order of precedence

```powershell
> path   # Get-SystemPath

Scope      Location
-----      --------
Process    C:\Program Files\PowerShell\7
Machine    C:\Program Files\Microsoft VS Code\bin
Machine    C:\Windows\system32    # expanded location
           %SystemRoot%\system32  # actually stored expandable reference
Machine    C:\Windows
User       C:\Users\me\go\bin
...
```

#### Specific scope

```powershell
> path -Machine   # machine scope only
> path -User      # user scope only
> path -Process   # process scope only 

Scope      Location
-----      --------
Machine    C:\Windows\system32
           %SystemRoot%\system32
Machine    C:\Program Files\Git\bin
```

#### Find a folder in the system Path

```powershell
> path -Contains windows         # literal match, case-insentive, no wildcards
> path windows                   # same as -Contains

Scope      Location
-----      --------
Machine    C:\Windows\system32
Machine    C:\Windows
...
```

#### Match a folder in the system Path

```powershell
> path -Location "C:\Program Files\Git\bin" # exact match
> path -Filter "*\Git\*"                    # wildcard match
> path -Match "\\Git\\(cmd|bin)$"           # regex match
```

#### Multiple Criteria

```powershell
> path Git -Filter "*\bin"        # ALL criteria must be met
> path Git Program                # must contain both strings
```

#### Test whether a folder is on the system Path

in a specific scope (machine or user) \
**default**: **effective** in current shell

```powershell
> testpath "C:\Program Files\Git\bin"          # Test-SystemPathLocation, exact match
> testpath "C:\Program Files\Git\bin" -Machine

True
```

The folder is matched exactly, case-insensitively and ignoring a trailing backslash; a substring or a pattern finds nothing.

#### Add or remove a folder to/from the system Path permanently
in a specific scope (machine 🅰️ or user) \
**default**: **user** scope

```powershell
> addpath "C:\Program Files\MyApp"
> addpath -Machine "C:\Program Files\MyApp" # 🅰️
> addpath -First "C:\Program Files\MyApp" # this folder will be searched first
> addpath -Force "%JAVA_HOME%\bin" # adds a location naming no existing folder

> rmpath "C:\Program Files\MyApp" # removes every occurrence of this path
```

A location naming no existing folder is rejected; pass `-Force` to add it anyway. The location is checked expanded, so a `%…%` reference whose variable is not set is rejected too.

`addpath` and `rmpath` are aliases for `Add-SystemPathLocation` and `Remove-SystemPathLocation` respectively, which you should use in scripts.

#### Remove duplicate folders from the system Path

in a specific scope (machine 🅰️ or user), or both combined \
**default**: **both**, keeping a cross-scope duplicate on the machine Path

```powershell
> cleanpath                # both scopes; keeps machine on overlap
> cleanpath -KeepMachine   # both scopes; keeps machine on overlap (explicit)
> cleanpath -KeepUser      # both scopes; keeps user on overlap
> cleanpath -Machine       # machine Path only
> cleanpath -User          # user Path only
```

`cleanpath` is an alias for `Remove-DuplicateSystemPathLocations`, which you should use in scripts. \
Within a scope, the first occurrence of each folder is kept.

#### Move a folder between the machine and user system Path 🅰️

```powershell
> movepath "C:\Program Files\Git\bin" -ToUser     # machine -> user
> movepath "C:\Program Files\Git\bin" -ToMachine  # user -> machine
```

`movepath` is an alias for `Move-SystemPathLocation`, which you should use in scripts. \
The folder is removed from the source Path and added to the target Path.

#### Pick up a system Path change made elsewhere

```powershell
> syncpath
```

`syncpath` is an alias for `Sync-SystemPath`, which you should use in scripts. \
The Path of the current shell is rebuilt from the machine and the user Path, the way a fresh shell is given one, so a change made in the Windows settings, in another shell or by an installer takes effect without opening a new one. Folders only this shell knows, such as those a virtual environment added, are kept. The easypeasy Path functions do this themselves, so this is only for a change easypeasy did not make.

A folder **removed** elsewhere is not picked up: no scope carries it any more, which is exactly what a folder this shell added looks like. Open a new shell for that.

#### Back up the effective system Path environment variable to a file in the temp folder

```powershell
> Backup-SystemPath
```

### Environment Variables

#### Get the value of a variable

in a specific scope (effective, machine or user) \
**default**: **effective** in current shell

```powershell
> getenv JAVA_HOME
> getenv -Machine JAVA_HOME
> getenv -User JAVA_HOME

C:\Java\jdk-21
```

`getenv` is an alias for `Get-EnvironmentVariable`, which you should use in scripts.


#### Set the value of a variable or remove it permanently 
in a specific scope (machine 🅰️ or user) \
**default**: **user** scope
```powershell
> setenv JAVA_HOME "C:\Java\jdk-21"
> setenv -Machine JAVA_HOME "C:\Java\jdk-21" # 🅰️

> rmenv JAVA_HOME
> rmenv -Machine JAVA_HOME # 🅰️
```

`setenv` and `rmenv` are aliases for `Set-EnvironmentVariable` and `Remove-EnvironmentVariable` respectively, which you should use in scripts.

#### List the variables of a scope

both scopes (**default**), or one of them (`-Machine`, `-User`)

```powershell
> Get-Environment

Scope      Name                           Value
-----      ----                           -----
User       GOPATH                         C:\Go\GOPATH
Machine    JAVA_HOME                      C:\Java\jdk-21
...
```

Each record carries its `Scope`, `Name` and `Value`. Records are ordered by name, and where both scopes define a variable the user record comes first, since the user value is the one in effect. `Path` is no exception: each scope carries its own record.

### Shortcuts

#### Read a shortcut

```powershell
> Get-Shortcut "C:\Users\me\Desktop\MyApp.lnk"

Location           : C:\Users\me\Desktop\MyApp.lnk
Target             : C:\Program Files\MyApp\MyApp.exe
Arguments          : --profile Default
RunLocation        : C:\Program Files\MyApp
Description        : My favourite app
Icon               : C:\Program Files\MyApp\MyApp.exe,3
Hotkey             : Alt+Ctrl+M
WindowStyle        : Maximized
Elevated           : False
```

`Icon` splits into its parts, and is `$null` when the shortcut carries no icon:

```powershell
> (Get-Shortcut "C:\Users\me\Desktop\MyApp.lnk").Icon.Location
C:\Program Files\MyApp\MyApp.exe

> (Get-Shortcut "C:\Users\me\Desktop\MyApp.lnk").Icon.Index
3
```

`ToString()` combines them back into the `file,index` source a shortcut stores.

`WindowStyle` is `Normal`, `Maximized` or `Minimized`.

#### Create a shortcut

Only the shortcut location and its target are mandatory; the run location defaults to the folder of the target.
```powershell
> New-Shortcut "C:\Users\me\Desktop\MyApp.lnk" "C:\Program Files\MyApp\MyApp.exe"

> New-Shortcut -Location "C:\Users\me\Desktop\MyApp.lnk" -Target "C:\Program Files\MyApp\MyApp.exe" `
        -Arguments "--profile Default" `
        -RunLocation "C:\Users\me\Documents" `
        -Description "My favourite app" `
        -Icon (New-ShortcutIcon -Location "C:\Program Files\MyApp\MyApp.exe" -Index 3) `
        -Hotkey "Ctrl+Alt+M" `
        -WindowStyle Maximized `
        -Elevated
```

The created shortcut is returned, in the same shape `Get-Shortcut` reads it. \
An existing shortcut is left untouched and a terminating error is reported, unless `-Force` is given to overwrite it completely; omitted optional fields reset to their defaults.

A missing folder is reported as an error, unless `-CreateFolder` is given to create it.
```powershell
> New-Shortcut "C:\Tools\Shortcuts\MyApp.lnk" "C:\Program Files\MyApp\MyApp.exe" -CreateFolder
```

#### Build a shortcut icon

`-Icon` takes a `ShortcutIcon`, built from the icon file and an optional index, or from the combined `file,index` source.
```powershell
> New-ShortcutIcon -Location "C:\Program Files\MyApp\MyApp.exe"
> New-ShortcutIcon -Location "C:\Program Files\MyApp\MyApp.exe" -Index 3
> New-ShortcutIcon "C:\Program Files\MyApp\MyApp.exe,3"
```

`-Index` defaults to `0`. An icon file on its own is only accepted as `-Location`; `-Value` insists on the `file,index` form. \
An icon read off another shortcut goes straight back in:
```powershell
> New-Shortcut "C:\Users\me\Desktop\MyApp.lnk" "C:\Program Files\MyApp\MyApp.exe" `
        -Icon (Get-Shortcut "C:\Users\me\Desktop\Other.lnk").Icon
```

#### Change a shortcut

Any combination of fields, the others stay as they are.
```powershell
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Target "C:\Program Files\MyApp\MyApp.exe" -WindowStyle Maximized
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Elevated
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Elevated:$false
```

`$null` or an empty string clears a field.
```powershell
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Arguments $null -Hotkey '' -Icon $null
```

`-PassThru` returns the shortcut after the change.
```powershell
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -WindowStyle Minimized -PassThru
```

### Start Menu Shortcuts

#### Create a shortcut for MyApp in the Start Menu

for the current user (**default**) or all users (`-AllUsers`, requires administrator) \
The shortcut will be created as `MyApp` in the Start Menu Programs root; pass `-Folder` to place it in a containing folder.
The argument `-Debug` will be passed to the target.
```powershell
> New-StartMenuShortcut `
        -Name MyApp `
        -Target "C:\Program Files\MyApp\MyApp.exe" `
        -Arguments "-Debug" `
        -Icon (New-ShortcutIcon -Location "C:\Program Files\MyApp\MyBeautifulIcon.ico")

> New-StartMenuShortcut -AllUsers -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe"  # all users, needs admin
```

Every field of [`New-Shortcut`](#shortcuts) is available, and the created shortcut is returned as a record.
```powershell
> New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe" `
        -RunLocation "C:\Data" `
        -Description "My favourite app" `
        -Icon (New-ShortcutIcon -Location "C:\Program Files\MyApp\MyApp.exe" -Index 3) `
        -Hotkey "Ctrl+Alt+M" `
        -WindowStyle Maximized `
        -Elevated
```

An existing shortcut is left untouched and a terminating error is reported, unless `-Force` is given to overwrite it.
```powershell
> New-StartMenuShortcut -Force -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe"
```

#### Remove a Start Menu shortcut

in the current user's (**default**) or the all-users (`-AllUsers`, requires administrator) Start Menu
```powershell
> Remove-StartMenuShortcut MyApp
> Remove-StartMenuShortcut -AllUsers MyApp
```

The shortcut's containing folder is removed too when it becomes empty. A terminating error is reported if the shortcut does not exist.

#### Add shortcut to a PowerShell command to the start menu

```powershell
> New-PowershellStartMenuShortcut `
       -Name "Kill Node.js" ` 
       -Command "Stop-Process -Name node -Force"

> New-PowershellStartMenuShortcut -Name "Run System Update" `
       -Script "C:\Scripts\system-update.ps1" `
       -KeepOpen -WindowStyle Maximized -Elevated
```

`-Script` is an alias for `-Command` that can be used for expressiveness. \
`-NoExit` is an alias for `-KeepOpen`, named after the `pwsh` switch it passes. \
The window is minimized unless `-WindowStyle` says otherwise. \
Both accept `-Force` to overwrite an existing shortcut.

### Start an application at logon 

equivalent to checking [Process Explorer](https://learn.microsoft.com/de-de/sysinternals/downloads/process-explorer)'s menu item *Options > Run At Logon* (requires administrator)
```powershell
Register-LogonTask `
    -Name "Process Explorer-${env:USERDOMAIN}-${env:USERNAME}" `
    -Executable "$env:LOCALAPPDATA\Microsoft\WindowsApps\procexp.exe" `
    -Argument "/t" `
    -Force
```

### Utilities

#### Quick timestamp creation

```powershell
> time

2024-01-01_20.15.00

> & .\system-update.ps1 > "$env:TEMP\system-update-$(time).log"
```

`time` is an alias for `Get-Timestamp`, which you should use in scripts.

#### Run a command as administrator

Runs the given command in an elevated PowerShell session, prompting for confirmation through the User Account Control dialog.
```powershell
> sudops New-Item -ItemType Directory "C:\Program Files\MyTool"
> sudops Restart-Service -Name Spooler
```

`sudops` (and the shorter `sups`) is an alias for `Invoke-Elevated`, which you should use in scripts.

#### Verify that the current user is an administrator

```powershell
> Assert-Elevated
Assert-Elevated: Operation requires administrator privileges.
```

`Test-Elevated` returns the same fact as a boolean, for a script that offers an unelevated path instead of failing.

```powershell
> Test-Elevated

False
```

#### Restart Windows Explorer

```powershell
> sx
```

`sx` is an alias for `Stop-Explorer`, which you should use in scripts. \
Stopping Explorer generally triggers a restart, which picks up a shell setting that needs one.

#### Locate a special folder

```powershell
> programs

C:\Program Files

> docs

C:\Users\me\Documents

> desktop

C:\Users\me\Desktop
```

`programs`, `docs` and `desktop` are aliases for `Get-ProgramFilesFolder`, `Get-MyDocumentsFolder` and `Get-DesktopFolder` respectively, which you should use in scripts.

## Installation
### Installation from PowerShell Gallery

To install the *easypeasy* module from the PowerShell Gallery, run the following command in PowerShell:

```powershell
Install-Module easypeasy
```

### Manual Installation

To install the *easypeasy* module, follow these steps:

1. Download the module folder from GitHub to your computer.

1. Open PowerShell and run the following command to check the installation path for PowerShell modules: `$env:PSModulePath`

1. Copy the *easypeasy* module folder to one of the paths listed in the output of the previous command, e.g. the user's module path: `$HOME\Documents\WindowsPowerShell\Modules\`

1. Open a new PowerShell session or reload your profile to make the module available. You can check if the module is available by running: `Get-Module -ListAvailable`

## Upgrading

Version 2 renames commands, parameters and aliases, changes defaults and removes a few components. See [UPGRADING.md](UPGRADING.md) for the v1 → v2 migration guide.

## Contributing
Please contribute to the *easypeasy* module. Issues and pull requests are very welcome. Thank you!

## License
The *easypeasy* module is licensed under the Apache License, Version 2.0. See the `LICENSE.txt` file for details.

   Copyright 2023-2026 Igor Akkerman

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.


## Acknowledgments
Thanks to everyone supporting and contributing to *easypeasy*.
