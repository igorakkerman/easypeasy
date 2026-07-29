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
# Get-SystemPath
> path

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
> path -Machine     # machine scope only
> path -User        # user scope only
> path -Process     # process scope only 
> path -Effective   # all scopes, same as without args


Scope      Location
-----      --------
Machine    C:\Windows\system32
           %SystemRoot%\system32
Machine    C:\Program Files\Git\bin
```

#### Find a folder in the system Path

```powershell
> path windows             # literal match, case-insentive, no wildcards
> path -Contains windows   # same as without args

Scope      Location
-----      --------
Machine    C:\Windows\system32
Machine    C:\Windows
...
```

#### Match a folder in the system Path

```powershell
> path -Location "C:\Program Files\Git\bin"   # exact match
> path -Filter "*\Git\*"                      # wildcard match
> path -Match "\\Git\\(cmd|bin)$"             # regex match
```

#### Multiple Criteria

```powershell
> path Git -Filter "*\bin"   # ALL criteria must be met
> path Git Program           # must contain both strings
```

#### Test whether a folder is on the system Path

in a specific scope (machine or user) \
**default**: **effective** in current shell

```powershell
# Test-SystemPathLocation
> testpath "C:\Program Files\Git\bin"              # exact match, case-insensitve
> testpath "C:\Program Files\Git\bin" -Effective   # same as without args
> testpath "C:\Program Files\Git\bin" -Machine     # machine scope only
> testpath "C:\Program Files\Git\bin" -User        # user scope only
> testpath "C:\Program Files\Git\bin" -Process     # process scope only

True
```

#### Add or remove a folder to/from the system Path permanently

```powershell
# Add-SystemPathLocation
> addpath "C:\Program Files\MyApp"          # user scope
> addpath -User "C:\Program Files\MyApp"    # same as without args
> addpath -Machine "C:\Program Files\MyApp" # machine scope 🅰️
> addpath -First "C:\Program Files\MyApp"   # this folder will be searched first
> addpath "%JAVA_HOME%\bin"                 # expandable reference
> addpath -Force "%JAVA_HOME%\bin"          # non-existent location

# Remove-SystemPathLocation
> rmpath "C:\Program Files\MyApp"           # removes every occurrence of this path
```

A location naming no existing folder is rejected; pass `-Force` to add it anyway. The location is checked expanded, so a `%…%` reference whose variable is not set is rejected too.

#### Remove duplicate folders from the system Path

```powershell
# Remove-DuplicateSystemPathLocations
> cleanpath                # both scopes, keeps machine on overlap
> cleanpath -KeepMachine   # same as without args
> cleanpath -KeepUser      # both scopes; keeps user on overlap 🅰️
> cleanpath -Machine       # machine Path only 🅰️
> cleanpath -User          # user Path only
```

Within a scope, the first occurrence of each folder is kept.

#### Move a folder between the machine and user system Path

```powershell
# Move-SystemPathLocation
> movepath "C:\Program Files\Git\bin" -ToUser     # machine -> user 🅰️ 
> movepath "C:\Program Files\Git\bin" -ToMachine  # user -> machine 🅰️ 
```

#### Pick up a system Path change made elsewhere

```powershell
# Sync-SystemPath
> syncpath
```

Rebuilds the system Path of the current shell, the same way as in a fresh shell.
A change made in the Windows settings, in another shell or by an installer takes effect without opening a new one. 

Keeps this shell's folders, such as those a virtual environment.
Other system Path functions do this themselves.

A folder **removed** elsewhere is not picked up: 
It will stay as a process-scoped folder and can be removed manually.

#### Back up the effective system Path environment variable to a file in the temp folder

```powershell
> Backup-SystemPath
```

### Environment Variables

#### Get the value of a variable

```powershell
# Get-EnvironmentVariable
> getenv JAVA_HOME              # effective scope
> getenv -Machine JAVA_HOME     # machine scope
> getenv -User JAVA_HOME        # user scope
> getenv TMP -Expandable        # stored expandable reference, %...% left unevaluated

C:\Java\jdk-21
```

#### Set the value of a variable or remove it permanently

```powershell
# Set-EnvironmentVariable
> setenv JAVA_HOME "C:\Java\jdk-21"            # user scope
> setenv -User JAVA_HOME "C:\Java\jdk-21"      # same as without args
> setenv -Machine JAVA_HOME "C:\Java\jdk-21"   # machine scope 🅰️
> setenv TMP "%USERPROFILE%\tmp" -Expandable   # store as expandable reference, expanded on read

# Remove-EnvironmentVariable
> rmenv JAVA_HOME                              # user scope
> rmenv -Machine JAVA_HOME                     # machine scope 🅰️
```

#### List the variables of a scope

```powershell
> Get-Environment            # both scopes
> Get-Environment -Machine   # machine scope only
> Get-Environment -User      # user scope only

Scope      Name                           Value
-----      ----                           -----
User       GOPATH                         C:\Go\GOPATH
Machine    JAVA_HOME                      C:\Java\jdk-21
...
```

Each record carries its `Scope`, `Name` and `Value`.

Records are ordered by name; where both scopes define a variable, the user record comes first, since the user value is the one in effect.

`Path` is no exception: each scope carries its own record.

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

```powershell
> New-Shortcut "C:\Users\me\Desktop\MyApp.lnk" "C:\Program Files\MyApp\MyApp.exe"                 # only location and target are mandatory
> New-Shortcut "C:\Tools\Shortcuts\MyApp.lnk" "C:\Program Files\MyApp\MyApp.exe" -CreateFolder    # create missing shortcut folder
> New-Shortcut "C:\Users\me\Desktop\MyApp.lnk" "C:\Program Files\MyApp\MyApp.exe" -Force          # overwrite existing shortcut

> New-Shortcut -Location "C:\Users\me\Desktop\MyApp.lnk" -Target "C:\Program Files\MyApp\MyApp.exe" `
        -Arguments "--profile Default" `
        -RunLocation "C:\Users\me\Documents" `
        -Description "My favourite app" `
        -Icon (New-ShortcutIcon -Location "C:\Program Files\MyApp\MyApp.exe" -Index 3) `
        -Hotkey "Ctrl+Alt+M" `
        -WindowStyle Maximized `
        -Elevated
```

The created shortcut is returned, in the same shape `Get-Shortcut` reads it.

The run location defaults to the folder of the target.

An existing shortcut is left untouched and a terminating error is reported, unless `-Force` overwrites it completely; omitted optional fields reset to their defaults.

A missing shortcut folder is reported as an error, unless `-CreateFolder` creates it.

#### Build a shortcut icon

```powershell
> New-ShortcutIcon -Location "C:\Program Files\MyApp\MyApp.exe"            # index 0
> New-ShortcutIcon -Location "C:\Program Files\MyApp\MyApp.exe" -Index 3   # icon within the icon file
> New-ShortcutIcon "C:\Program Files\MyApp\MyApp.exe,3"                    # combined file,index source
```

`-Icon` takes a `ShortcutIcon`, built from the icon file and an optional index, or from the combined `file,index` source.

An icon file on its own is only accepted as `-Location`; `-Value` insists on the `file,index` form.

An icon read off another shortcut goes straight back in:
```powershell
> New-Shortcut "C:\Users\me\Desktop\MyApp.lnk" "C:\Program Files\MyApp\MyApp.exe" `
        -Icon (Get-Shortcut "C:\Users\me\Desktop\Other.lnk").Icon
```

#### Change a shortcut

```powershell
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Target "C:\Program Files\MyApp\MyApp.exe" -WindowStyle Maximized   # any combination of fields, others stay
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Elevated
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Elevated:$false
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Arguments $null -Hotkey '' -Icon $null                             # $null or empty string clears a field
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -WindowStyle Minimized -PassThru                                    # return shortcut after the change
```

### Start Menu Shortcuts

#### Create a shortcut for MyApp in the Start Menu

```powershell
> New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe"                       # current user, Programs root
> New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe" -Folder MyCompany     # in a containing folder
> New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe" -AllUsers             # all users, needs admin
> New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe" -Force                # overwrite existing shortcut
```

Every field of [`New-Shortcut`](#shortcuts) is available, and the created shortcut is returned as a record.
```powershell
> New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe" `
        -Arguments "-Debug" `
        -RunLocation "C:\Data" `
        -Description "My favourite app" `
        -Icon (New-ShortcutIcon -Location "C:\Program Files\MyApp\MyApp.exe" -Index 3) `
        -Hotkey "Ctrl+Alt+M" `
        -WindowStyle Maximized `
        -Elevated
```

An existing shortcut is left untouched and a terminating error is reported, unless `-Force` overwrites it.

#### Remove a Start Menu shortcut

```powershell
> Remove-StartMenuShortcut MyApp                     # current user, Programs root
> Remove-StartMenuShortcut MyApp -Folder MyCompany   # in a containing folder
> Remove-StartMenuShortcut MyApp -AllUsers           # all users, needs admin
```

The shortcut's containing folder is removed too when it becomes empty.

A terminating error is reported if the shortcut does not exist.

#### Add shortcut to a PowerShell command to the start menu

```powershell
> New-PowershellStartMenuShortcut `
        -Name "Kill Node.js" `
        -Command "Stop-Process -Name node -Force"

> New-PowershellStartMenuShortcut -Name "Run System Update" `
        -Script "C:\Scripts\system-update.ps1" `
        -KeepOpen -WindowStyle Maximized -Elevated
```

`-Script` is an alias for `-Command` that can be used for expressiveness.

`-NoExit` is an alias for `-KeepOpen`, named after the `pwsh` switch it passes.

The window is minimized unless `-WindowStyle` says otherwise.

Both accept `-Force` to overwrite an existing shortcut.

### Start an application at logon 

equivalent to checking [Process Explorer](https://learn.microsoft.com/de-de/sysinternals/downloads/process-explorer)'s menu item *Options > Run At Logon* (requires administrator)
```powershell
> Register-LogonTask `
        -Name "Process Explorer-${env:USERDOMAIN}-${env:USERNAME}" `
        -Executable "$env:LOCALAPPDATA\Microsoft\WindowsApps\procexp.exe" `
        -Argument "/t" `
        -Force
```

### Utilities

#### Quick timestamp creation

```powershell
# Get-Timestamp
> time

2024-01-01_20.15.00

> & .\system-update.ps1 > "$env:TEMP\system-update-$(time).log"
```

#### Run a command as administrator

```powershell
# Invoke-Elevated
> sudops New-Item -ItemType Directory "C:\Program Files\MyTool"
> sups Restart-Service -Name Spooler                              # sups is the shorter alias
```

Runs the given command in an elevated PowerShell session, prompting for confirmation through the User Account Control dialog.

#### Verify that the current user is an administrator

```powershell
> Assert-Elevated

Assert-Elevated: Operation requires administrator privileges.

> Test-Elevated

False
```

`Assert-Elevated` reports a terminating error, ending a command that has no unelevated path.

`Test-Elevated` returns the same fact as a boolean, for a script that offers an unelevated path instead of failing.

#### Restart Windows Explorer

```powershell
# Stop-Explorer
> sx
```

Stopping Explorer generally triggers a restart, which picks up a shell setting that needs one.

#### Locate a special folder

```powershell
# Get-ProgramFilesFolder
> programs

C:\Program Files

# Get-MyDocumentsFolder
> docs

C:\Users\me\Documents

# Get-DesktopFolder
> desktop

C:\Users\me\Desktop
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

Version 2 renames commands, parameters and aliases, changes defaults and removes a few components. See [UPGRADING-v2.md](UPGRADING-v2.md) for the v1 → v2 migration guide.

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
