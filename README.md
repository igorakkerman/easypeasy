# <img src="logo.png" alt="easypeasy logo" width="64" /> easy𝓅ea𝓈y

**Productivity boost for Windows using PowerShell**

The *easypeasy* PowerShell module simplifies and automates common tasks in Windows environments:
- manage locations on the system Path
- manage environment variables
- create, read and change shortcuts, e.g. in Start Menu
- `sudo` equivalent for PowerShell commands
- easily restart Windows Explorer
- output timestamps
- register tasks that run at logon
- locate special folders

___
## Examples
🅰️ = elevates the process through a UAC prompt, requires `sudo`

### System Path
#### List the folders on the system Path

in order of precedence

```powershell
# Get-SystemPath
> path

Scope      Location
-----      --------
Process    C:\Program Files\PowerShell\7
Machine    C:\Program Files\Microsoft VS Code\bin
Machine    %SystemRoot%\system32   # value as stored
           ↳ C:\Windows\System32   # folder it resolves to
Machine    C:\Windows
User       C:\Users\me\go\bin
User       C:\Users\me\missing     # missing folders shown in red
...
```

#### Specific scope

```powershell
> path              # same as `-Effective`
> path -Effective   # all scopes, default
> path -Machine     # machine scope only
> path -User        # user scope only
> path -Process     # process scope only


Scope      Location
-----      --------
Machine    %SystemRoot%\system32
           ↳ C:\Windows\System32
Machine    C:\Program Files\Git\bin
```

#### Get the system Path as stored

```powershell
> path -Join   # semicolon-separated values

C:\Program Files\PowerShell\7;%SystemRoot%\system32;C:\Windows;C:\Users\me\go\bin
```

#### Find folders by substring on the system Path

```powershell
> path windows             # same as `-Contains`
> path -Contains windows   # literal match, case-insensitive, no wildcards, default

Scope      Location
-----      --------
Machine    C:\Windows\system32
Machine    C:\Windows
...
```

#### Match folders on the system Path

```powershell
> path -Exact "C:\Program Files\Git\bin"   # exact match, case-insensitive, aliases -Location,-Folder
> path -Filter "*\Git\*"                   # wildcard match, case-insensitive
> path -Match "\\Git\\(cmd|bin)$"          # regex match, case-insensitive
```

#### Multiple criteria

```powershell
> path Git -Filter "*\bin"   # ALL criteria must be met
> path Git Program           # must contain both strings
```

#### Test whether a folder is on the system Path

always verifies the exact path, case-insensitive

```powershell
# Test-SystemPathLocation
> testpath "C:\Program Files\Git\bin"                 # same as `-Effective`
> testpath "C:\Program Files\Git\bin" -Effective      # effective in current shell, default
> testpath "C:\Program Files\Git\bin" -Machine        # machine scope only
> testpath "C:\Program Files\Git\bin" -User           # user scope only
> testpath "C:\Program Files\Git\bin" -Process        # process scope only
> "C:\Program Files\Git\bin", "C:\Tools" | testpath   # from the pipeline, one result each

True
```

#### Add or remove a folder to/from the system Path permanently

```powershell
# Add-SystemPathLocation
> addpath "C:\Program Files\MyApp"            # same as `-User`
> addpath -User "C:\Program Files\MyApp"      # user scope, default
> addpath -Machine "C:\Program Files\MyApp"   # machine scope 🅰️
> addpath -First "C:\Program Files\MyApp"     # this folder will be searched first
> addpath "%JAVA_HOME%\bin"                   # expandable reference
> addpath -Force "C:\Tools\NotYet"            # non-existent folder, fails without `-Force`
> "C:\MyApp", "C:\OtherApp" | addpath         # one write per scope, same as `-User`
> "C:\MyApp", "C:\OtherApp" | addpath -User   # user scope, default

# Remove-SystemPathLocation
> rmpath "C:\Program Files\MyApp"             # removes every occurrence of this path
> rmpath "C:\MyApp", "C:\OtherApp"            # several locations, one write
> path MyApp | rmpath                         # each from the scope it lives on 🅰️
> path MyApp | rmpath -User                   # only the ones in user scope
```

A non-existent location is rejected; use `-Force` to add it anyway.

`C:\%MY_APP%\bin` with `MY_APP` unset is added as indirection with a warning.

#### Remove duplicate folders from the system Path

```powershell
# Remove-DuplicateSystemPathLocations
> cleanpath                # same as `-KeepMachine` 🅰️
> cleanpath -KeepMachine   # both scopes, keeps machine on overlap, default 🅰️
> cleanpath -KeepUser      # both scopes, keeps user on overlap 🅰️
> cleanpath -Machine       # machine Path only 🅰️
> cleanpath -User          # user Path only
```

Within a scope, the first occurrence of each folder is kept.

#### Move a folder between the machine and user system Path

```powershell
# Move-SystemPathLocation
> movepath "C:\Program Files\Git\bin" -ToUser         # machine -> user 🅰️
> movepath "C:\Program Files\Git\bin" -ToMachine      # user -> machine 🅰️
> "C:\Tools\bin", "C:\Other\bin" | movepath -ToUser   # from the pipeline, one prompt 🅰️
```

#### Pick up a system Path change made elsewhere

```powershell
# Sync-SystemPath
> syncpath
```

Rebuilds the system Path of the current shell, the same way as in a fresh shell.
A change made elsewhere takes effect without opening a new one,
e.g. a change from the Windows settings, another shell or an installer.
Other system Path functions do this themselves.

A folder **removed** elsewhere is not picked up: it stays as a process-scoped folder.

#### Back up the effective system Path environment variable to a file in the temp folder

```powershell
> Backup-SystemPath
```

### Environment variables

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
> setenv JAVA_HOME "C:\Java\jdk-21"            # same as `-User`
> setenv -User JAVA_HOME "C:\Java\jdk-21"      # user scope, default
> setenv -Machine JAVA_HOME "C:\Java\jdk-21"   # machine scope 🅰️
> setenv TMP "%USERPROFILE%\tmp" -Expandable   # store as expandable reference, expanded on read

# Remove-EnvironmentVariable
> rmenv JAVA_HOME                              # same as `-User`
> rmenv -User JAVA_HOME                        # user scope, default
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

# remove comments before use
> New-Shortcut `
        -Location "C:\Users\me\Desktop\MyApp.lnk" `
        -Target "C:\Program Files\MyApp\MyApp.exe" `
        -Arguments "--profile Default" `
        -RunLocation "C:\Users\me\Documents" `       # default: folder of target executable
        -Description "My favourite app" `
        -Icon "C:\Program Files\MyApp\MyApp.exe,3" ` # icon filename or filename,index
        -Hotkey "Ctrl+Alt+M" `
        -WindowStyle Maximized `                     # Normal, Maximized, Minimized
        -Elevated `                                  # run shortcut as administrator
        -CreateFolder `                              # create parent folder
        -Force                                       # overwrite existing shortcut
```

The created shortcut is returned.

#### Give a shortcut an icon

```powershell
> New-Shortcut "C:\Users\me\Desktop\MyApp.lnk" "C:\Program Files\MyApp\MyApp.exe" -Icon "C:\Program Files\MyApp\MyApp.exe"   # index 0
> New-Shortcut "C:\Users\me\Desktop\MyApp.lnk" "C:\Program Files\MyApp\MyApp.exe" -Icon "C:\Windows\imageres.dll,229"        # icon within the icon file
```

#### Change a shortcut

```powershell
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Target "C:\Program Files\MyApp\MyApp.exe" -WindowStyle Maximized   # any combination of fields, others stay
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Elevated
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Elevated:$false
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -Arguments $null -Hotkey '' -Icon $null                             # $null or empty string clears a field
> Set-Shortcut "C:\Users\me\Desktop\MyApp.lnk" -WindowStyle Minimized -PassThru                                    # return shortcut after the change
```

### Start Menu shortcuts

#### Create a shortcut for MyApp in the Start Menu

```powershell
> New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe"                       # current user, Programs root
> New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe" -Folder MyCompany     # in a containing folder
> New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe" -AllUsers             # all users 🅰️
> New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe" -Force                # overwrite existing shortcut
```

Every field of [`New-Shortcut`](#shortcuts) is available, and the created shortcut is returned as a record.
```powershell
> New-StartMenuShortcut -Name MyApp -Target "C:\Program Files\MyApp\MyApp.exe" `
        -Arguments "-Debug" `
        -RunLocation "C:\Data" `
        -Description "My favourite app" `
        -Icon "C:\Program Files\MyApp\MyApp.exe,3" `
        -Hotkey "Ctrl+Alt+M" `
        -WindowStyle Maximized `
        -Elevated
```

An existing shortcut is left untouched and a terminating error is reported, unless `-Force` overwrites it.

#### Remove a Start Menu shortcut

```powershell
> Remove-StartMenuShortcut MyApp                     # current user, Programs root
> Remove-StartMenuShortcut MyApp -Folder MyCompany   # in a containing folder
> Remove-StartMenuShortcut MyApp -AllUsers           # all users 🅰️
```

The shortcut's containing folder is removed too when it becomes empty.

#### Add shortcut to a PowerShell command to the Start Menu

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

`-Force` overwrites an existing shortcut.

### Start an application at logon

#### Run as the logged-in user

```powershell
# remove comments before use
> Register-LogonTask `
        -Name Syncthing `
        -Path "\Startup" `         # path in task scheduler
        -Executable "$env:LOCALAPPDATA\Programs\Syncthing\syncthing.exe" `
        -Argument "--no-console"   # app-specific argument to the executable
```

#### Run as an administrator 🅰️

`-Elevated` (alias `-Administrator`) runs the task at the highest privileges available to the user.

```powershell
# remove comments before use
> Register-LogonTask `
        -Name "Process Explorer-${env:USERDOMAIN}-${env:USERNAME}" `
        -Executable "$env:LOCALAPPDATA\Microsoft\WindowsApps\procexp.exe" `
        -Argument "/t" `   # app-specific argument to the executable
        -Elevated `        # run as an administrator
        -Force             # overwrite existing task
```

The example is equivalent to checking [Process Explorer](https://learn.microsoft.com/de-de/sysinternals/downloads/process-explorer)'s menu item *Options > Run At Logon*.

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

Stopping Explorer generally triggers a restart.

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

### Manual installation

To install the *easypeasy* module, follow these steps:

1. Download the module folder from GitHub to your computer.

1. Open PowerShell and run the following command to check the installation path for PowerShell modules: `$env:PSModulePath`

1. Copy the *easypeasy* module folder to one of the paths listed in the output of the previous command, e.g. the user's module path: `$HOME\Documents\PowerShell\Modules\`

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
