# >_  easy𝓅ea𝓈y
*Productivity boost for Windows using PowerShell*

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
🅰️ = requires Administrator privileges

## System PATH
```powershell
# show the full effective system PATH

> path  # or Get-SystemPath

Location
--------
C:\Program Files\PowerShell\7
C:\Program Files\Microsoft VS Code\bin
C:\Python
C:\Windows\system32
C:\Windows
...


# show all occurrences of "Windows" in the system PATH

> path | where Location -like "*Windows*"

Location
--------
C:\Windows\system32
C:\Windows
...


# add MyApp to the machine's system PATH 🅰️

> Add-SystemPathLocation "C:\Program Files\MyApp"
> Add-SystemPathLocation -Machine "C:\Program Files\MyApp"


# add MyApp to the user's system PATH

> Add-SystemPathLocation -User "C:\Program Files\MyApp"


# add MyApp to the front of the machine's system PATH 🅰️

> Add-SystemPathLocation "C:\Program Files\MyApp" -Front


# remove every occurrence of MyApp from the machine's system PATH 🅰️

> Remove-SystemPathLocation "C:\Program Files\MyApp"


# back up the current system PATH environment variable to a file in the temp folder

> Backup-SystemPath
```

## Environment Variables

```powershell
# get the value of JAVA_HOME in the user scope

> getenv -User JAVA_HOME
> Get-EnvironmentVariable -User JAVA_HOME

C:\Java\jdk-21


# permanently set the value of JAVA_HOME in the machine scope 🅰️

> setenv -User JAVA_HOME "C:\Java\jdk-21"
> Set-EnvironmentVariable -User JAVA_HOME "C:\Java\jdk-21"


# permanently remove JAVA_HOME from the machine scope 🅰️

> rmenv -Machine JAVA_HOME
> Remove-EnvironmentVariable -Machine JAVA_HOME
```

## Start Menu Shortcuts

```powershell
# create a shortcut for MyApp in the Start Menu for all users 🅰️
# The shortcut will be created as "MyApp" in the "MyApp" programs folder.
# The argument "-Debug" will be passed to the executable.
# The shortcut will be created with the "Run as administrator" option.

> New-StartMenuShortcut -AppName MyApp -Executable "C:\Program Files\MyApp\MyApp.exe" -Arguments "-Debug" -RunAsAdministrator


# add shortcut to a PowerShell command to start menu

> New-PowershellStartMenuShortcut -AppName "Kill Node.js" -Command "Stop-Process -Name node -Force"

> New-PowershellStartMenuShortcut -AppName "Run System Update" -Command "C:\Scripts\system-update.ps1" -Maximized -KeepOpen -RunAsAdministrator
```

## Start an application at logon 🅰️

```powershell
# Autostart Process Explorer at Logon
# equivalent to checking menu item "Options > Run At Logon"

Register-LogonTask `
    -Name "Process Explorer-${env:\USERDOMAIN}-${env:USERNAME}" `
    -Executable "$env:LOCALAPPDATA\Microsoft\WindowsApps\procexp.exe" `
    -Argument "/t" `
    -Force
```

## Dark Mode

```powershell
# switch between light and dark theme
> theme
> Switch-Theme


# restart Windows Explorer when switching theme
# Windows Explorer windows don't handle the registry change
# https://github.com/igorakkerman/easypeasy/issues/10

> theme -RestartExplorer
> Switch-Theme -RestartExplorer


# switch to dark theme

> theme dark
> Switch-Theme dark
> Set-Theme dark
```

## Utilities

```powershell
# quick timestamp creation

> time
> Get-Timestamp

2024-01-01_20.15.00

> & .\system-update.ps1 > "$env:TEMP\system-update-$(time).log"


# Verify that the current user is an administrator

> Assert-Administrator
Assert-Administrator: This operation requires administrator privileges.


# output the disk usage for the current folder

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

## Installation from PowerShell Gallery

To install the *easypeasy* module from the PowerShell Gallery, run the following command in PowerShell:

```powershell
Install-Module easypeasy
```

## Manual Installation

To install the *easypeasy* module, follow these steps:

1. Download the module folder from GitHub to your computer.

1. Open PowerShell and run the following command to check the installation path for PowerShell modules: `$env:PSModulePath`

1. Copy the *easypeasy* module folder to one of the paths listed in the output of the previous command, e.g. the user's module path: `$HOME\Documents\WindowsPowerShell\Modules\`

1. Add `Import-Module easypeasy` to your profile, e.g. `$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`

1. Open a new PowerShell session or reload your profile to make the module available. You can check if the module is available by running: `Get-Module -ListAvailable`

## Contributing
Please contribute to the *easypeasy* module. Issues and pull requests are very welcome. Thank you!

## License
The *easypeasy* module is licensed under the MIT License. See the LICENSE file for details.

## Acknowledgments
Thanks to everyone supporting and contributing to *easypeasy*.
