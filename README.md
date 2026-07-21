# <img src="logo.png" alt="easypeasy logo" width="64" /> easy𝓅ea𝓈y



**Productivity boost for Windows using PowerShell**

The *easypeasy* PowerShell module simplifies and automates common tasks in Windows environments:
- manage locations on the system path
- manage environment variables
- create and remove start menu shortcuts
- create scheduled tasks
- create timestamps
- run a command as administrator (sudo)
- verify administrator privileges

___
## Examples
🅰️ = requires Administrator privileges

### System PATH
#### List the folders in the system PATH

in a specific scope (machine or user) \
**default**: **effective** in current shell

```powershell
> path

Scope      Location
-----      --------
Machine    C:\Program Files\PowerShell\7
Machine    C:\Program Files\Microsoft VS Code\bin
Machine    C:\Windows\system32
Machine    C:\Windows
User       C:\Users\me\go\bin
Process    C:\Program Files\PowerShell\7
...
```

`path` is an alias for `Get-SystemPath`, which you should use in scripts. \
Each location is tagged with its **scope**: `Machine`, `User`, or `Process` — the last for entries present only in the current shell's PATH and not persisted.

#### Find a folder in the system PATH

```powershell
> path Windows

Scope      Location
-----      --------
Machine    C:\Windows\system32
Machine    C:\Windows
...
```

`Windows` is the `-Contains` parameter, which you should name explicitly in scripts. It selects every location containing the string, case-insensitively, and is taken literally — no wildcards.

Three kinds of criteria are available, and a location must satisfy **all** of the criteria given:

```powershell
> path Git Program                # contains both strings
> path -Filter "*\Git\*"          # wildcard match
> path -Match "\\Git\\(cmd|bin)$" # regex match
> path Git -Filter "*\bin"        # contains Git AND matches the wildcard
```

#### Find a folder on the system PATH and the scope it lives in

```powershell
> Get-SystemPathLocation Windows
> Get-SystemPathLocation -Location "C:\Windows"
> Get-SystemPathLocation -Filter "*\Git\*" -User

Scope      Location
-----      --------
Machine    C:\Windows
```

Both commands take the same criteria as `Get-SystemPath` — `-Contains` (positional), `-Filter` and `-Match` — plus an exact `-Location`, and the scope switches `-Machine` and `-User`. At least one criterion is required. Each result carries the scope it was found in: `Machine`, `User`, or `Process`.

#### Test whether a folder is on the system PATH

in a specific scope (machine or user) \
**default**: **effective** in current shell

```powershell
> Test-SystemPathLocation -Location "C:\Program Files\Git\bin"
> Test-SystemPathLocation Git
> Test-SystemPathLocation -Filter "*\Git\*" -Machine

True
```

#### Add or remove a folder to/from the system PATH permanently

in a specific scope (machine 🅰️ or user) \
**default**: **user** scope

```powershell
> addpath "C:\Program Files\MyApp"
> addpath -Machine "C:\Program Files\MyApp" # 🅰️
> addpath -First "C:\Program Files\MyApp" # this folder will be searched first

> rmpath "C:\Program Files\MyApp" # removes every occurrence of this path
```

`addpath` and `rmpath` are aliases for `Add-SystemPathLocation` and `Remove-SystemPathLocation` respectively, which you should use in scripts.

#### Remove duplicate folders from the system PATH

in a specific scope (machine 🅰️ or user), or both combined \
**default**: **both**, keeping a cross-scope duplicate on the machine PATH

```powershell
> cleanpath                # both scopes; keeps machine on overlap
> cleanpath -KeepMachine   # both scopes; keeps machine on overlap (explicit)
> cleanpath -KeepUser      # both scopes; keeps user on overlap
> cleanpath -Machine       # machine PATH only
> cleanpath -User          # user PATH only
```

`cleanpath` is an alias for `Remove-DuplicateSystemPathLocations`, which you should use in scripts. \
Within a scope, the first occurrence of each folder is kept.

#### Move a folder between the machine and user system PATH 🅰️

```powershell
> movepath "C:\Program Files\Git\bin" -ToUser     # machine -> user
> movepath "C:\Program Files\Git\bin" -ToMachine  # user -> machine
```

`movepath` is an alias for `Move-SystemPathLocation`, which you should use in scripts. \
The folder is removed from the source PATH and added to the target PATH.

#### Back up the effective system PATH environment variable to a file in the temp folder

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

### Start Menu Shortcuts

#### Create a shortcut for MyApp in the Start Menu

for the current user (**default**) or all users (`-AllUsers`) 🅰️ \
The shortcut will be created as `MyApp` in the Start Menu Programs root; pass `-Folder` to place it in a containing folder.
The argument `-Debug` will be passed to the executable.
```powershell
> New-StartMenuShortcut `
        -Name MyApp `
        -Executable "C:\Program Files\MyApp\MyApp.exe" `
        -Arguments "-Debug" `
        -IconLocation "C:\Program Files\MyApp\MyBeautifulIcon.ico"

> New-StartMenuShortcut -AllUsers -Name MyApp -Executable "C:\Program Files\MyApp\MyApp.exe"  # all users, needs admin
```

The icon file may hold several icons; `-IconIndex` picks one (**default**: `0`).
Alternatively, `-Icon` takes the combined `file,index` form. `-Icon` and `-IconLocation` / `-IconIndex` are mutually exclusive.
```powershell
> New-StartMenuShortcut -Name MyApp -Executable "C:\Program Files\MyApp\MyApp.exe" `
        -IconLocation "C:\Program Files\MyApp\MyApp.exe" -IconIndex 3

> New-StartMenuShortcut -Name MyApp -Executable "C:\Program Files\MyApp\MyApp.exe" `
        -Icon "C:\Program Files\MyApp\MyApp.exe,3"
```

An existing shortcut is left untouched and a terminating error is reported, unless `-Force` is given to overwrite it.
```powershell
> New-StartMenuShortcut -Force -Name MyApp -Executable "C:\Program Files\MyApp\MyApp.exe"
```

#### Remove a Start Menu shortcut

in the current user's (**default**) or the all-users (`-AllUsers`) 🅰️ Start Menu
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
       -Maximized -KeepOpen -Admin
```

`-Script` is an alias for `-Command` that can be used for expressiveness. \
`-Admin` is an alias for `-RunAsAdministrator` that can be used for conciseness. \
Both accept `-Force` to overwrite an existing shortcut.

### Start an application at logon 

equivalent to checking [Process Explorer](https://learn.microsoft.com/de-de/sysinternals/downloads/process-explorer)'s menu item *Options > Run At Logon* 🅰️
```powershell
Register-LogonTask `
    -Name "Process Explorer-${env:\USERDOMAIN}-${env:USERNAME}" `
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
Assert-Elevated: This operation requires administrator privileges.
```

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
