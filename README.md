# <img src="logo.png" alt="easypeasy logo" width="64" /> easy𝓅ea𝓈y



**Productivity boost for Windows using PowerShell**

The *easypeasy* PowerShell module simplifies and automates common tasks in Windows environments:
- manage locations on the system path
- manage environment variables
- create and remove start menu shortcuts
- create scheduled tasks
- switch between light and dark themes
- create timestamps
- show disk usage
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

Scope   Location
-----   --------
Machine C:\Program Files\PowerShell\7
Machine C:\Program Files\Microsoft VS Code\bin
Machine C:\Windows\system32
Machine C:\Windows
User    C:\Users\me\go\bin
Process C:\Program Files\PowerShell\7
...
```

`path` is an alias for `Get-SystemPath`, which you should use in scripts. \
Each location is tagged with its **scope**: `Machine`, `User`, or `Process` — the last for entries present only in the current shell's PATH and not persisted.

#### Find a folder in the system PATH

```powershell
> path *Windows*

Scope   Location
-----   --------
Machine C:\Windows\system32
Machine C:\Windows
...
```

`*Windows*` is the `-Filter` parameter, which you should name explicitly in scripts.

#### Find a folder on the system PATH and the scope it lives in

```powershell
> Get-SystemPathLocation "C:\Windows"
> Get-SystemPathLocation -Filter "*\Git\*"
> Get-SystemPathLocation -Filter "*\Git\*" -User

Scope   Location
-----   --------
Machine C:\Windows
```

Both commands accept an exact `-Location` (positional) or a `-Filter` wildcard, and the scope switches `-Machine` and `-User`. Each result carries the scope it was found in: `Machine`, `User`, or `Process`.

#### Test whether a folder is on the system PATH

in a specific scope (machine or user) \
**default**: **effective** in current shell

```powershell
> Test-SystemPathLocation "C:\Program Files\Git\bin"
> Test-SystemPathLocation -Filter "*\Git\*" -Machine

True
```

#### Add or remove a folder to/from the system PATH permanently

in a specific scope (machine 🅰️ or user) \
**default**: **machine** scope

```powershell
> addpath "C:\Program Files\MyApp"
> addpath -User "C:\Program Files\MyApp"
> addpath -Front "C:\Program Files\MyApp" # this folder will be searched first

> rmpath "C:\Program Files\MyApp" # removes every occurrence of this path
```

`addpath` and `rmpath` are aliases for `Add-SystemPathLocation` and `Remove-SystemPathLocation` respectively, which you should use in scripts.

#### Remove duplicate folders from the system PATH

in a specific scope (machine 🅰️ or user), or both combined \
**default**: **both**, keeping a cross-scope duplicate on the machine PATH

```powershell
> deduppath                # both scopes; keeps machine on overlap
> deduppath -KeepMachine   # both scopes; keeps machine on overlap (explicit)
> deduppath -KeepUser      # both scopes; keeps user on overlap
> deduppath -Machine       # machine PATH only
> deduppath -User          # user PATH only
```

`deduppath` is an alias for `Remove-DuplicateSystemPathLocations`, which you should use in scripts. \
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
**default**: **machine** scope
```powershell
> setenv JAVA_HOME "C:\Java\jdk-21"
> setenv -User JAVA_HOME "C:\Java\jdk-21"

> rmenv JAVA_HOME
> rmenv -User JAVA_HOME
```

`setenv` and `rmenv` are aliases for `Set-EnvironmentVariable` and `Remove-EnvironmentVariable` respectively, which you should use in scripts.

### Start Menu Shortcuts

#### Create a shortcut for MyApp in the Start Menu

for all users (**default**) 🅰️ or the current user (`-User`) \
The shortcut will be created as `MyApp` in the `MyApp` programs folder.
The argument `-Debug` will be passed to the executable.
```powershell
> New-StartMenuShortcut `
        -AppName MyApp `
        -Executable "C:\Program Files\MyApp\MyApp.exe" `
        -Arguments "-Debug" `
        -Icon "C:\Program Files\MyApp\MyBeautifulIcon.ico"

> New-StartMenuShortcut -User -AppName MyApp -Executable "C:\Program Files\MyApp\MyApp.exe"  # current user, no admin
```

An existing shortcut is left untouched and a terminating error is reported, unless `-Force` is given to overwrite it.
```powershell
> New-StartMenuShortcut -Force -AppName MyApp -Executable "C:\Program Files\MyApp\MyApp.exe"
```

#### Remove a Start Menu shortcut

in the all-users (**default**) 🅰️ or the current user's (`-User`) Start Menu
```powershell
> Remove-StartMenuShortcut MyApp
> Remove-StartMenuShortcut -User MyApp
```

The shortcut's containing folder is removed too when it becomes empty. A terminating error is reported if the shortcut does not exist.

#### Add shortcut to a PowerShell command to the start menu

```powershell
> New-PowershellStartMenuShortcut `
       -AppName "Kill Node.js" ` 
       -Command "Stop-Process -Name node -Force"

> New-PowershellStartMenuShortcut -AppName "Run System Update" `
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

### Dark Mode

#### Switch between light and dark theme

```powershell
> theme
```

`theme` is an alias for `Switch-Theme`. `Get-Theme`, `Set-Theme`, `Switch-Theme` and `theme` will be removed in v2.

```powershell
> theme dark
> theme light
```

### Utilities

#### Quick timestamp creation

```powershell
> time

2024-01-01_20.15.00

> & .\system-update.ps1 > "$env:TEMP\system-update-$(time).log"
```

`time` is an alias for `Get-Timestamp`, which you should use in scripts.

#### Run a command as administrator (sudo)

Runs the given command in an elevated PowerShell session via the Windows `sudo` command, prompting for confirmation through the User Account Control dialog.
```powershell
> sudops addpath -Machine "C:\Tools"
> sudops setenv -Machine JAVA_HOME "C:\Java\jdk-21"
> sups Set-Theme dark
```

`sudops` (and the shorter `sups`) is an alias for `Invoke-Elevated`, which you should use in scripts. Requires the Windows `sudo` feature to be installed and enabled.

#### Verify that the current user is an administrator

```powershell
> Assert-Administrator
Assert-Administrator: This operation requires administrator privileges.
```

#### Output the disk usage for the current folder

```powershell
> Get-Usage

Name                           Sum (MB)      Sum
----                           --------      ---
C:\easypeasy\systempath.ps1    0,011    11297,00
C:\easypeasy\startmenu.ps1     0,006     5961,00
C:\easypeasy\environment.ps1   0,006     5873,00
C:\easypeasy\easypeasy.psd1    0,005     5748,00
C:\easypeasy\README.md         0,005     5243,00
C:\easypeasy\theme.ps1         0,003     2692,00
C:\easypeasy\task.ps1          0,001     1497,00
C:\easypeasy\specialfolder.ps1 0,001     1299,00
C:\easypeasy\.vscode           0,001     1116,00
C:\easypeasy\LICENSE.txt       0,001     1070,00
C:\easypeasy\shortcut.ps1      0,001      991,00
C:\easypeasy\volume.ps1        0,001      628,00
C:\easypeasy\timestamp.ps1     0,001      541,00
C:\easypeasy\explorer.ps1      0,000      481,00
C:\easypeasy\.github           0,000      432,00
C:\easypeasy\administrator.ps1 0,000      374,00
C:\easypeasy\easypeasy.psm1    0,000      349,00
```

`du` is an alias for `Get-Usage`. Both will be removed in v2.

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
