# >_  easy𝓅ea𝓈y
**Productivity boost for Windows using PowerShell**

The *easypeasy* PowerShell module simplifies and automates common tasks in Windows environments:
- manage locations on the system path
- manage environment variables
- create start menu shortcuts
- create scheduled tasks
- switch between light and dark themes
- create timestamps
- show disk usage
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

Location
--------
C:\Program Files\PowerShell\7
C:\Program Files\Microsoft VS Code\bin
C:\Python
C:\Windows\system32
C:\Windows
...
```

`path` is an alias for `Get-SystemPath`, which you should use in scripts.

```powershell
> path | where Location -like "*Windows*"

Location
--------
C:\Windows\system32
C:\Windows
...
```

#### Add or remove a folder to/from the system PATH permanently

in a specific scope (machine 🅰️ or user) \
**default**: **machine** scope

```powershell
> Add-SystemPathLocation "C:\Program Files\MyApp"
> Add-SystemPathLocation -User "C:\Program Files\MyApp"
> Add-SystemPathLocation -Front "C:\Program Files\MyApp" # this folder will be searched first

> Remove-SystemPathLocation "C:\Program Files\MyApp" # removes every occurrence of this path
```

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

#### Create a shortcut for MyApp in the Start Menu for all users 🅰️
The shortcut will be created as `MyApp` in the `MyApp` programs folder.
The argument `-Debug` will be passed to the executable.
The shortcut will be created with the "Run as administrator" option.
```powershell
> New-StartMenuShortcut `
        -AppName MyApp `
        -Executable "C:\Program Files\MyApp\MyApp.exe" `
        -Arguments "-Debug" `
        -Icon "C:\Program Files\MyApp\MyBeautifulIcon.ico" `
        -RunAsAdministrator
```

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
`-Admin` is an alias for `-RunAsAdministrator` that can be used for conciseness.

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

`theme` is an alias for `Switch-Theme`, which you should use in scripts.

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

#### Verify that the current user is an administrator

```powershell
> Assert-Administrator
Assert-Administrator: This operation requires administrator privileges.
```

#### Output the disk usage for the current folder

```powershell
> Get-Usage
> du

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
C:\easypeasy\LICENSE           0,001     1070,00
C:\easypeasy\shortcut.ps1      0,001      991,00
C:\easypeasy\volume.ps1        0,001      628,00
C:\easypeasy\timestamp.ps1     0,001      541,00
C:\easypeasy\explorer.ps1      0,000      481,00
C:\easypeasy\.github           0,000      432,00
C:\easypeasy\administrator.ps1 0,000      374,00
C:\easypeasy\easypeasy.psm1    0,000      349,00
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

## Contributing
Please contribute to the *easypeasy* module. Issues and pull requests are very welcome. Thank you!

## License
The *easypeasy* module is licensed under the MIT License. See the LICENSE file for details.

## Acknowledgments
Thanks to everyone supporting and contributing to *easypeasy*.
